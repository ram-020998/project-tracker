# Progress: P0 01 — Persistence Layer & Migration Framework

**Spec:** `specs/phase-07-code-review-fixes/01-p0-persistence-and-migrations.md`
**Delivered in:** genesis v0.12.0 (commit `a9aac7f`, tag `v0.12.0`)
**CI:** pipelines #6328341 (master) + #6328342 (tag) — both SUCCESS
**Date:** 2026-07-11

---

## Summary

Introduced the `genesis/db/` package — a centralized persistence layer that replaces
the duplicated hand-written DDL + connection logic previously scattered across
`EventLog._conn/_init` and `RunStore._conn/_init`. Schema evolution is now managed
by a forward-only migration runner with recorded versions, validated contiguity,
and per-migration transactional commits.

---

## Deliverables

### 1. New `genesis/db/` package

| File | Purpose |
|------|---------|
| `__init__.py` | Re-exports `Database`, `Migration`, `migrate`, `current_version`, `pending`, `MIGRATIONS` |
| `database.py` | `Database` class: connection factory + PRAGMA policy (WAL, busy_timeout=30000, foreign_keys=ON, row_factory=Row) + `tx()` transactional context manager |
| `runner.py` | `Migration` dataclass + `migrate()` runner + `current_version()`/`pending()` helpers + contiguity validation |
| `migrations/__init__.py` | Ordered `MIGRATIONS` list |
| `migrations/m0001_baseline.py` | Adopts existing `runs` + `run_events` tables (idempotent `CREATE TABLE IF NOT EXISTS`) |

### 2. Repository refactor

- `genesis/runs/eventlog.py` — accepts `Database` (or raw path for backward-compat); no DDL, no `import sqlite3`.
- `genesis/runs/store.py` — same pattern; `RunRecord._from_row` uses `Any` type (DB-agnostic signature).
- `genesis/runs/manager.py` — builds one `Database(settings.db_path)`, calls `migrate(db, MIGRATIONS)` once, injects into both stores.

### 3. CLI

- `genesis db upgrade` — applies pending migrations, prints applied versions.
- `genesis db status` — prints current schema version + pending list.

### 4. Tests (`tests/test_db.py` — 21 tests)

- Fresh DB migration (tables + index + schema_migrations recorded)
- **Data-safety adoption** (pre-create old DDL + insert data → migrate → data survives)
- Idempotency (second/third call applies nothing)
- Contiguity guard (gap/dupe/zero raises RuntimeError)
- Sequential migrations (synthetic m0002 on top of adopted DB)
- `Database.tx()` commit/rollback semantics
- `current_version`/`pending` helpers
- Refactored store CRUD + event log operations through Database

---

## Evidence

```
$ pytest -q -p no:warnings
75 passed in 14.96s

$ ruff check genesis
All checks passed!

$ genesis db status
schema version: 1
pending: (none)

$ grep -rn "import sqlite3" genesis/ --include="*.py" | grep -v "/db/" | grep -v __pycache__
(empty — no sqlite3 imports outside genesis/db/)

# Real DB data-safety check:
runs: 13, events: 224, schema_migrations: [(1, 'baseline')]
```

---

## Decisions / Deviations

- **File structure:** The spec proposed `genesis/db/migrations.py` alongside `genesis/db/migrations/`.
  Python doesn't allow a module and package with the same name at the same level. Resolved by
  placing the runner in `genesis/db/runner.py` and keeping `migrations/` as the package.
- **`foreign_keys=ON`** added to the PRAGMA policy (was missing from the old `RunStore._conn()`).
  This is additive (no FK constraints are declared yet) and positions for future integrity.
- **Backward-compat:** `EventLog` and `RunStore` constructors accept either a `Database` instance
  or a raw path (str/Path). The path form constructs a `Database` internally. This keeps existing
  tests that pass a raw path working (e.g. `test_dataplane.py` was updated to use `Database` + `migrate`).
- **No behavioral change:** all public APIs on EventLog/RunStore/RunManager are unchanged; all 54
  pre-existing tests pass unmodified (except `test_dataplane.py` which needed the explicit migrate call
  since the store no longer self-initializes DDL).

---

## What's NOT verified (honest disclosure)

- **Live `genesis serve` + browser verification:** not performed headlessly (requires running the
  full FastAPI app + SPA). However, since `RunManager.__init__` calls `migrate()` and all API behavior
  is routed through the same stores, and the existing `test_api.py` (which constructs a `RunManager`)
  passes, the live path is structurally covered.
- **Concurrent writers:** not tested (single-user local app; WAL + busy_timeout handle any CLI-vs-server
  contention in practice).

---

## Next

P0 02 — Overview Dashboard (`02-p0-overview-dashboard.md`): extend `GET /home` with live metrics
and wire the static `Overview.tsx` placeholder to call the API.
