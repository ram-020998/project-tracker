# 01 — P0: Persistence Layer & Migration Framework

**Priority:** P0 (foundation) · **Layer:** `genesis` · **Depends on:** none · **Blocks:** every
future data feature; softly precedes `03`, `04`, `05`.

> Goal: turn the already-real SQLite persistence into a **solid, evolvable foundation** — one
> connection policy, one schema owner, versioned migrations, and repositories with DB-agnostic
> signatures — **without changing behavior or the local single-user posture.**

---

## 1. Problem (current state, verified)

Persistence is functional but under-abstracted:

- **`genesis/runs/eventlog.py`** (`EventLog`) opens its own `sqlite3.connect(db_path, timeout=30)`,
  sets `PRAGMA journal_mode=WAL` + `PRAGMA busy_timeout=30000` in `_conn()`, and creates
  `run_events` + `ix_run_events_run` via hand-written `CREATE TABLE IF NOT EXISTS` in `_init()`.
- **`genesis/runs/store.py`** (`RunStore`) does the same pattern for the `runs` table.
- **`genesis/runtime/checkpoint.py`** builds LangGraph's `AsyncSqliteSaver` on the **same**
  `genesis.db` (ADR-024); it manages its **own** tables (`checkpoints`, `writes`, …).
- **No migration framework** (`alembic`/`sqlalchemy` absent from `pyproject.toml`), **no schema
  version table**, **no single connection policy** (PRAGMA logic duplicated).

**Consequences:** schema evolution = ad-hoc `ALTER TABLE` with no ordering/rollback/record;
three copies of connection setup; no clean seam for a future Postgres move (`05`).

---

## 2. Goals / Non-goals

**Goals**
1. A single `genesis/db/` package owning: the connection factory (PRAGMA policy in one place),
   a minimal **forward-only migration runner** (versioned, ordered, recorded, idempotent), and a
   thin repository base.
2. Refactor `EventLog` and `RunStore` into **repositories** that receive a connection/engine and
   carry **no DDL** (DDL lives in migrations).
3. A **baseline migration (0001)** that *adopts* the existing `run_events`/`runs` tables **without
   data loss** on existing installs (idempotent `CREATE TABLE IF NOT EXISTS` + index).
4. Migrations run automatically on app/manager startup (and via a `genesis db upgrade` CLI).
5. Keep repository method **signatures DB-agnostic** (no SQLite-only types leaking) so `05`'s
   Postgres option is a driver swap, not a rewrite.

**Non-goals**
- No ORM. No SQLAlchemy in this doc (evaluated in §7; deferred to `05`).
- Do **not** manage the LangGraph checkpointer's tables — it owns them. We only *document* them
  and ensure our migrator never touches them.
- No Postgres. No schema/behavior change to what's stored.

---

## 3. Design

### 3.1 New package `genesis/genesis/db/`

```
genesis/db/
  __init__.py            # exports: Database, migrate, MIGRATIONS
  database.py            # Database: connection factory + PRAGMA policy + tx helper
  migrations.py          # migration runner + schema_migrations bookkeeping
  migrations/
    __init__.py          # ordered MIGRATIONS list
    m0001_baseline.py    # adopt existing run_events + runs (idempotent)
```

### 3.2 `database.py` — one connection policy

```python
# genesis/db/database.py
from __future__ import annotations
import sqlite3
from contextlib import contextmanager
from pathlib import Path

class Database:
    """Owns the sqlite connection policy for genesis.db (WAL, busy_timeout, row factory).

    All app-side persistence (EventLog, RunStore, future stores) goes through here.
    The LangGraph checkpointer keeps its OWN aiosqlite connection (ADR-024) and is
    intentionally out of scope — this class must never DROP/ALTER its tables.
    """
    def __init__(self, db_path: str | Path):
        self.db_path = str(db_path)
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=30000")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    @contextmanager
    def tx(self):
        """Transactional connection context (commit on success, rollback on error)."""
        conn = self.connect()
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
```

> This centralizes the exact PRAGMA behavior currently duplicated in `eventlog.py::_conn` and
> `store.py::_conn`. Per-connection PRAGMA is retained (WAL is a DB-level setting, but WAL +
> `busy_timeout` set per connection is the current working behavior — keep it identical to avoid
> regressions).

### 3.3 `migrations.py` — minimal, forward-only runner

```python
# genesis/db/migrations.py
from __future__ import annotations
from dataclasses import dataclass
from typing import Callable
import sqlite3
from datetime import datetime, timezone

@dataclass(frozen=True)
class Migration:
    version: int            # 1, 2, 3 … strictly increasing, gap-free
    name: str               # human label, e.g. "baseline"
    up: Callable[[sqlite3.Connection], None]  # idempotent-friendly DDL

_SCHEMA = """
CREATE TABLE IF NOT EXISTS schema_migrations (
    version    INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    applied_at TEXT NOT NULL
)
"""

def _applied(conn) -> set[int]:
    conn.execute(_SCHEMA)
    return {r[0] for r in conn.execute("SELECT version FROM schema_migrations")}

def migrate(db, migrations) -> list[int]:
    """Apply all pending migrations in order, each in its own transaction.
    Returns the list of versions applied this call. Safe to call on every startup."""
    applied_versions = []
    with db.connect() as conn:  # note: manual tx per migration below
        done = _applied(conn)
    ordered = sorted(migrations, key=lambda m: m.version)
    # validate contiguous, unique versions (fail fast on authoring mistakes)
    for i, m in enumerate(ordered, start=1):
        if m.version != i:
            raise RuntimeError(f"migration versions must be contiguous from 1; got {m.version} at position {i}")
    for m in ordered:
        if m.version in done:
            continue
        conn = db.connect()
        try:
            m.up(conn)
            conn.execute(
                "INSERT INTO schema_migrations (version, name, applied_at) VALUES (?,?,?)",
                (m.version, m.name, datetime.now(timezone.utc).isoformat()),
            )
            conn.commit()
            applied_versions.append(m.version)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    return applied_versions
```

Design choices (rationale):
- **Forward-only + Python callables** (not raw `.sql` files) so a migration can do data
  backfills, conditional logic, and is testable. `down()` deliberately omitted (YAGNI for a
  local single-user append-mostly store; a bad migration is fixed forward).
- **Contiguous integer versions** validated at runtime → prevents accidental gaps/dupes when
  multiple agents add migrations in parallel (a real risk in this project's workflow).
- **Each migration in its own transaction**; `schema_migrations` row written in the same tx.

### 3.4 `migrations/m0001_baseline.py` — adopt existing tables (no data loss)

```python
# genesis/db/migrations/m0001_baseline.py
from ..migrations import Migration

def _up(conn):
    # Idempotent: on an existing install these already exist → no-op; on a fresh
    # install they are created here (removed from EventLog/RunStore _init()).
    conn.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            run_id TEXT PRIMARY KEY, workflow_id TEXT NOT NULL, version TEXT NOT NULL,
            inputs TEXT NOT NULL, status TEXT NOT NULL, cursor TEXT NOT NULL DEFAULT '',
            artifacts_dir TEXT NOT NULL DEFAULT '', detail TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )""")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS run_events (
            seq INTEGER PRIMARY KEY AUTOINCREMENT, run_id TEXT NOT NULL, node TEXT,
            kind TEXT NOT NULL, payload TEXT NOT NULL, ts TEXT NOT NULL
        )""")
    conn.execute("CREATE INDEX IF NOT EXISTS ix_run_events_run ON run_events(run_id, seq)")

baseline = Migration(version=1, name="baseline", up=_up)
```

```python
# genesis/db/migrations/__init__.py
from .m0001_baseline import baseline
MIGRATIONS = [baseline]
```

**Critical safety property:** because 0001 uses `CREATE TABLE IF NOT EXISTS` with the *exact*
current schema, applying it to an existing `genesis.db` is a no-op that simply records
`version=1` in `schema_migrations` — **zero data loss, zero downtime.** Verified against the DDL
in `eventlog.py`/`store.py`.

### 3.5 Refactor `EventLog` / `RunStore` into repositories

- Both accept a `Database` (or a `db_path`, constructing a `Database`) instead of owning
  `_conn()` + `_init()`.
- **Remove `_init()` DDL** from both (now owned by migration 0001).
- Replace `with self._conn() as c:` with `with self._db.tx() as c:` (writes) / `self._db.connect()`
  (reads). Keep every public method + return dataclass identical (`EventRecord`, `RunRecord`).
- Keep `EventLog.purge(run_id)` (used by `04`).

Example (EventLog.append, unchanged behavior):
```python
def append(self, run_id, kind, payload=None, node=None) -> int:
    with self._db.tx() as c:
        cur = c.execute(
            "INSERT INTO run_events (run_id, node, kind, payload, ts) VALUES (?,?,?,?,?)",
            (run_id, node, kind, json.dumps(payload or {}, default=str), _now()))
        return int(cur.lastrowid)
```

### 3.6 Wiring: run migrations on startup

- **`RunManager.__init__`** (`genesis/runs/manager.py`): build one `Database(settings.db_path)`,
  call `migrate(db, MIGRATIONS)` **once**, then pass `db` to `RunStore(db)` and `EventLog(db)`
  (replacing the two `*_path` constructions). This guarantees the schema exists before any read/write.
- **`create_app`** already builds a `RunManager` → migrations run at server start. Also run at
  `RunManager` construction so the CLI/tests get a migrated DB.
- **Idempotent + fast:** on a migrated DB, `migrate` reads `schema_migrations` and applies nothing.

### 3.7 New CLI: `genesis db`
Add to `genesis/cli/main.py`:
- `genesis db upgrade` → `migrate(Database(Settings.load().db_path), MIGRATIONS)`, prints applied versions.
- `genesis db status` → prints applied vs pending versions + current schema version.
(Thin wrappers; useful for support + CI.)

---

## 4. Files touched

| File | Change |
|------|--------|
| `genesis/db/__init__.py` | **new** — exports `Database`, `migrate`, `MIGRATIONS` |
| `genesis/db/database.py` | **new** — connection factory + PRAGMA policy + `tx()` |
| `genesis/db/migrations.py` | **new** — `Migration`, `migrate`, `schema_migrations` |
| `genesis/db/migrations/__init__.py` | **new** — ordered `MIGRATIONS` |
| `genesis/db/migrations/m0001_baseline.py` | **new** — adopt `runs` + `run_events` |
| `genesis/runs/eventlog.py` | refactor onto `Database`; drop `_init()`/`_conn()` DDL |
| `genesis/runs/store.py` | refactor onto `Database`; drop `_init()`/`_conn()` DDL |
| `genesis/runs/manager.py` | build `Database`, run `migrate`, inject into stores |
| `genesis/cli/main.py` | add `genesis db upgrade|status` |
| `tests/test_db.py` | **new** — migrator + baseline + adoption tests |
| `tests/test_dataplane.py` | keep green (behavior unchanged) |

---

## 5. Testing / Definition of Done

**New unit tests (`tests/test_db.py`):**
1. Fresh DB → `migrate` applies `[1]`; `schema_migrations` has one row; `runs` + `run_events` +
   index exist.
2. **Adoption test (data-safety):** pre-create a DB with the *old* hand-written DDL + insert a
   `runs` row and a `run_events` row → run `migrate` → the rows survive, `schema_migrations`
   records `version=1`.
3. Idempotency: calling `migrate` twice applies nothing the second time.
4. Contiguity guard: a `MIGRATIONS` list with a gap/dupe raises.
5. A synthetic `m0002` (add a nullable column) applies on top of an adopted DB and is recorded.

**Regression:** `tests/test_dataplane.py`, `test_runs.py`, `test_api.py` stay green (public
behavior of `EventLog`/`RunStore`/`RunManager` unchanged).

**DoD**
- `pytest` + `ruff` green (backend CI).
- Existing dev `genesis.db` opens, migrates to v1 with **no data loss** (manual check: run count
  + event count identical before/after).
- No SQL/DDL remains in `eventlog.py`/`store.py` (grep clean).
- `genesis db status` reports `applied=[1] pending=[]`.

---

## 6. Risks & deviations
- **Risk:** WAL PRAGMA-per-connection behavior differs subtly if centralized wrong → mitigated by
  keeping the exact PRAGMA sequence identical and covering with the adoption test.
- **Risk:** two agents author `m0002` simultaneously → the contiguity guard fails fast; resolve by
  renumbering (documented in the migration file header convention).
- **Deviation from "just add Alembic":** we deliberately hand-roll a ~40-line migrator (see §7).

---

## 7. Considered alternative — SQLAlchemy Core + Alembic
- **Pros:** industry-standard migrations (autogenerate, downgrade), DB portability (the clean
  Postgres path for `05`), typed query building.
- **Cons:** a heavy dependency + conceptual surface for a local single-user app with **two tables**;
  Alembic autogenerate doesn't understand the externally-owned checkpointer tables (needs
  `include_object` filters); more moving parts in CI.
- **Recommendation:** **hand-rolled now** (this doc). Adopt **SQLAlchemy Core + Alembic** *only*
  if/when `05` selects Postgres — at which point repositories (already DB-agnostic in signature)
  are re-homed onto Core with modest effort. This keeps YAGNI now and a clean upgrade later.

---

## 8. Estimate
~0.5–1 day: package + migrator + baseline (2–3h), repository refactor (2–3h), tests + CLI +
manual data-safety check (2–3h). Single backend release; no frontend impact.
