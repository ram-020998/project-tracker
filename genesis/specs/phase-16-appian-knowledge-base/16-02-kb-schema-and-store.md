# Phase 16-02 — KB schema (m0007) + `KbStore`

> **Status:** DRAFT (planning) · **Repo:** genesis · **Depends on:** 16-01 (`KbParseResult` shape)
> **Goal:** Add the `kb_*` tables to `genesis.db` via migration **m0007** and a `KbStore` repository that applies a
> `KbParseResult` into the **temporal (SCD-2) model**, answers **current + point-in-time + cross-app** queries,
> maintains **current bundles** (recompute-on-sync) + **release-snapshot bundles**, and supports a **table-scoped**
> rebuild/untrack. No source code is ever stored. After 16-02, the KB is a fully-tested persistence layer independent of
> any environment.

---

## 1. Current state (grounded)
- DB infra: `genesis/genesis/db/database.py` (`Database(path)` → WAL + busy_timeout=30000 + foreign_keys=ON +
  `row_factory=sqlite3.Row` + `tx()` ctx mgr). `db/runner.py` (`Migration(version,name,up)`, `migrate(db, MIGRATIONS)`
  applies each pending migration in its own tx + records `schema_migrations`; contiguity guard; `current_version`).
- Migrations `db/migrations/` are `m0001_baseline … m0006_copilot_actions`; `current_version = 6`. Each file:
  a docstring, `from ..runner import Migration`, a `def _up(conn): conn.execute("CREATE TABLE IF NOT EXISTS …")` +
  indexes, and a module-level `Migration(version=N, name=…, up=_up)`. `db/migrations/__init__.py` imports each + appends
  to the ordered `MIGRATIONS` list; `db/__init__.py` re-exports.
- `migrate()` is called idempotently at boot by `RunManager.__init__` and `ChatManager` (and `genesis db upgrade`).
- Store/repository pattern (`chat/store.py`, `runs/eventlog.py`): a class taking a `Database` (or path → wraps),
  **never** opens ad-hoc connections, **never** creates tables (schema owned by migrations), uses `self._db.tx()` for
  writes + `self._db.connect()` for reads (try/finally close), `@dataclass` records with `_from_row` that tolerate
  missing columns via `r.keys()` (forward-compat), JSON columns via `json.dumps/loads`, aggregates via `json_extract`.

## 2. Design

### 2.1 Migration `db/migrations/m0007_kb.py`
- `def _up(conn)` creates the seven `kb_*` tables + indexes exactly as specified in the umbrella §5 (all
  `CREATE TABLE IF NOT EXISTS`, additive-only, FK `ON DELETE CASCADE` where child rows belong to an app). Export
  `kb = Migration(version=7, name="kb", up=_up)`; append to `MIGRATIONS`; `current_version` becomes **7** (update the
  onboarding bible's `current_version=7` note).
- **Iteration-1 scope (2026-08-04 decision):** the full schema (incl. the SCD-2 `valid_from_sync`/`valid_to_sync`
  columns, `kb_releases`, and `kb_bundles.release_label`) is created now so **versioning lands later as code-only, no
  migration** — but iteration 1 implements **current-state only**: every write sets `valid_to_sync = NULL` (and a
  baseline/delta close+reopen keeps "current" correct), no release tagging, no point-in-time reads. The version-tools +
  release logic are **backlog (16-06, gated on AP-62096)**. `kb_bundles.flow_json`/`key_objects_json` are populated now
  (needed by `get_bundle`/`get_app_overview` — see `genesis-kb-tool-contracts.md`).
- Additive only — no changes to existing tables (ADR-030 discipline; forward-only).

### 2.2 `genesis/genesis/kb/store.py` — `KbStore`
Constructed with a `Database` (mirrors `ChatStore`). Records as dataclasses with `_from_row`. Key methods:

**Write / apply (used by the sync workflow, 16-03):**
- `begin_sync(app_uuid, kind, window=None, run_id=None) -> sync_id` — insert a `kb_syncs` row `status='running'`.
- `apply(sync_id, result: KbParseResult, *, mode: 'baseline'|'delta') -> SyncCounts` — the core SCD-2 merge, in one
  `tx()`:
  - **baseline:** open a `kb_objects` row (`valid_from_sync=sync_id`, `valid_to_sync=NULL`) for every object; open all
    `kb_dependencies` rows; set `kb_applications.baseline_sync_id` if unset.
  - **delta:** for each result object, compare `diff_hash` to the current row (`valid_to_sync IS NULL`): unchanged →
    leave; changed → close the current row (`valid_to_sync=sync_id`) + open a new one; new → open a row. For objects the
    delta reports **removed** → close the current row. Diff edges similarly (close removed, open added). Counts →
    `objects_added/modified/removed`.
  - **bundles:** delete the current bundle set (`release_label IS NULL`) and re-insert the full recomputed set with
    `snapshot_sync=sync_id` (recompute-all; §umbrella R8). Insert `kb_bundle_members`.
- `finish_sync(sync_id, status, counts)` — set `kb_syncs.status/finished_at/counts`.

**Read (used by `genesis-kb` MCP 16-05 + Applications API 16-04):**
- `list_applications() -> [AppSummary]` (cross-app; counts + current release + last sync).
- `get_app_overview(app_uuid, at_release=None)` — counts by type, bundle index, dependency summary, coverage.
- `search_objects(app_uuid|None, query, type=None, at_release=None)` — name/description search (index; FTS5 later);
  `app_uuid=None` ⇒ **cross-app**.
- `get_object(app_uuid, object_uuid, at_release=None)` — metadata (no code).
- `get_dependencies(app_uuid, object_uuid, at_release=None)` — calls / called_by / bundles.
- `search_bundles(app_uuid, query, type=None)` / `get_bundle(app_uuid, bundle_id, at_release=None)`.
- `list_orphans(app_uuid, at_release=None)`.
- `get_changelog(app_uuid, from_release, to_release)` — added/modified/removed objects + affected bundles, derived from
  SCD-2 validity ranges between the two releases' `sync_id`s.

**Point-in-time helper:** `_snapshot_sync_for(app_uuid, at_release) -> sync_id` resolves a release label to its
`sync_id`; every read applies the validity predicate `valid_from_sync <= sid AND (valid_to_sync IS NULL OR valid_to_sync > sid)`
(current = `at_release=None` ⇒ `valid_to_sync IS NULL`).

**Releases (used by 16-06):**
- `tag_release(app_uuid, version_label, env_version_ref=None, notes=None)` — insert `kb_releases` at the latest
  succeeded `sync_id`; snapshot the current bundle set into a `release_label`-stamped copy; update
  `kb_applications.current_release`.
- `list_releases(app_uuid)`.

**Lifecycle:**
- `register_application(app_uuid, name, env_label, version_constant=None)` / `get_application` / `archive_application`.
- `untrack_application(app_uuid)` — **table-scoped** delete of all `kb_*` rows for the app (FK cascade), never touching
  runs/chat/copilot tables (§umbrella R9).

### 2.3 DB-agnostic signatures (ADR-030)
Keep method signatures storage-neutral (no SQLite types leaking) so a future Postgres/pgvector move (semantic search
over parsed content — the only real trigger) is a re-home behind `KbStore`, not a caller change.

## 3. Files & tests
- New: `db/migrations/m0007_kb.py` (+ register in `migrations/__init__.py`), `genesis/kb/__init__.py`,
  `genesis/kb/store.py`, `genesis/kb/models.py` (records).
- Tests `tests/test_kb_store.py`:
  - migration applies on a fresh + on an existing (m0006) db; `current_version==7`; idempotent re-run.
  - **baseline apply** from a synthetic `KbParseResult` → current rows opened; counts correct; bundles stored.
  - **delta apply**: unchanged/modified/added/removed each produce the right SCD-2 transitions; bundle set recomputed;
    counts reconcile.
  - **point-in-time**: tag v1.0, mutate (delta), tag v2.0 → `get_app_overview(at_release='1.0')` reflects v1 state;
    `get_object(at_release='1.0')` returns v1 metadata; changelog(1.0→2.0) lists the changes.
  - **cross-app** search returns objects across two apps; `app_uuid` filter scopes correctly.
  - `untrack_application` removes only that app's `kb_*` rows and leaves other apps + non-kb tables intact.
  - a guard test: no store method returns SAIL/code.
- No environment needed — feed `KbStore` synthetic `KbParseResult`s built in-test (and one real result from 16-01's
  fixture if convenient).

## 4. Acceptance criteria
1. m0007 creates the `kb_*` tables additively; `migrate()` at boot applies it; `current_version==7`.
2. `KbStore.apply` implements the SCD-2 model correctly for baseline + delta (verified by transition tests).
3. Point-in-time reads reconstruct the metadata graph at a tagged release; changelog derives from validity ranges.
4. Cross-app queries work; `untrack_application` is table-scoped and safe.
5. Full genesis pytest + ruff green; `KbStore` never persists or returns code.

## 5. Out of scope
- The sync workflow that calls `begin_sync/apply/finish_sync` (16-03).
- The MCP server that reads `KbStore` (16-05) and the Applications API/page (16-04).
- Release-tagging UI (16-06) — the `tag_release` store method lands here; the UX is 16-06.
- Retention/pruning automation (see umbrella Q5) — optional, post-16-07.
