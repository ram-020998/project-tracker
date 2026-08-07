# Phase 17-01 — Business Model contract + persistence (m0008 + KbStore)

> **Status:** ✅ SHIPPED (genesis v0.35.0) · **Repos:** genesis · **Depends on:** Phase 16-02 (`KbStore` + `kb_*` schema)
> **Goal:** Lay the foundation for the Business Application Map: freeze the **`BusinessModel v1`** contract, add the
> `genesis.db` migration **m0008** (`kb_business_maps`), and give `KbStore` the read/write + stale-marking surface the
> workflow (17-03) and API (17-04) build on. No agent, no UI here — just the durable spine.

---

## 1. Current state (grounded)
- Schema is owned by `genesis/db/` — a forward-only migration runner (`schema_migrations`, contiguity guard); current
  `current_version=7` (m0007 added `kb_*`). Never hand-write DDL in repositories — add a migration (bible §7).
- `genesis/kb/store.py` `KbStore` wraps `kb_*` with a `Database` connection factory (WAL + busy_timeout). It already
  overwrites-per-sync for bundles and marks current-state via `valid_to_sync IS NULL`.
- `kb_syncs` records each sync (`sync_id`, `finished_at`, counts); `KbStore.latest_sync`/`list_syncs` exist (16-04).
- The `BusinessModel v1` shape is fully specified in `business-model-contract.md` (this phase makes it real in storage).

## 2. Design
1. **Migration `m0008_business_map`** — create `kb_business_maps` exactly as in the umbrella §6 / contract (id, app_uuid FK
   → `kb_applications` ON DELETE CASCADE, `schema_version`, `source_sync_id`, `model_json`, `summary`, `domain`,
   `coverage_json`, `status`, `run_id`, `credits`, `generated_at`, `release_label`, `UNIQUE(app_uuid, release_label)`).
   Additive + `CREATE TABLE IF NOT EXISTS`; bump `current_version=8`. Index `ix_kb_bmap_app` on `(app_uuid, release_label)`.
   **Code-free** (business metadata only — ADR-037). Table lives in the `kb_*` namespace so untrack (16-02) cascades to it.
2. **`KbStore` methods** (blocking; the workflow calls the writer via `asyncio.to_thread` per the 16-03 lesson):
   - `upsert_business_map(app, *, schema_version, source_sync_id, model_json, summary, domain, coverage, status, run_id,
     credits)` — insert/replace the **current** row (`release_label IS NULL`) for the app.
   - `get_business_map(app, *, release_label=None) -> dict | None` — returns the row + parsed `model` (or `None`).
   - `set_business_map_status(app, status)` / `business_map_status(app) -> dict` — lightweight status (`generating`/`ready`/
     `failed`/`stale`/`absent`) for the API without shipping the whole model.
   - **Stale hook:** extend the sync-finish path (`finish_sync`/apply) so a completed sync sets the app's current map
     `status='stale'` (if one exists). The map is not deleted — the UI offers "regenerate".
3. **Untrack:** confirm `untrack_application` (table-scoped) removes `kb_business_maps` rows (FK cascade covers it; add to
   the explicit table list if untrack enumerates tables).

## 3. Definition of Done
- `genesis db upgrade` takes a fresh + an existing DB to `current_version=8`; `db status` shows m0008; re-run is idempotent.
- Unit tests: upsert→get round-trips a `BusinessModel` JSON; status transitions; a completed sync flips a `ready` map to
  `stale`; untrack removes the row. `ruff` clean; genesis pytest green.
- No API/UI yet (17-04/17-05). Ships in the genesis release that carries the Phase-17 backend (with 17-02/17-04).
