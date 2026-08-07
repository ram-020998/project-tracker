# Phase 17-04 — Business Map API

> **Status:** ✅ SHIPPED (genesis v0.35.0) · **Repos:** genesis · **Depends on:** 17-01 (persistence), 17-03 (the workflow)
> **Goal:** The thin HTTP surface the web uses to read, generate, and poll an application's business map — mirroring the
> existing sync surface, all under `/api` (ADR-028).

---

## 1. Current state (grounded)
- `genesis/api/applications.py` already registers the Applications routes over `KbStore` + `RunManager` (list/add/detail/
  sync/sync-status/objects/bundles). `add`/`sync` launch a workflow via `run_manager.start(workflow_id, inputs,
  environment=…)` and `sync-status` merges the run status with the KB row. `_err` maps `{error}` reads → 404.
- The `generate-business-map` workflow (17-03) reads the **local KB only**, so a launch does **not** require a dev
  environment (unlike `sync-application`) — it just needs the app synced.

## 2. Design
Add three routes in `applications.py`:
- `GET /api/applications/{uuid}/business-map` → `KbStore.get_business_map(uuid)`; returns
  `{status, model?, source_sync_id?, generated_at?, credits?, coverage?, stale?}`; `{status:"absent"}` when none. 404 if the
  app isn't tracked.
- `POST /api/applications/{uuid}/business-map/generate` → 404 if untracked; 409/400 if no completed sync yet (guide the user
  to sync first); else `run_manager.start("generate-business-map", {"app_uuid": uuid, "app_name": …})` and mark the map row
  `status='generating'`; return `{run_id}`.
- `GET /api/applications/{uuid}/business-map/status` → merge the latest `generate-business-map` run status (reconciled, like
  `_latest_sync_run`/`sync-status`) with `KbStore.business_map_status(uuid)` → `{run: {run_id,status,detail,…}|null,
  map_status: "generating|ready|failed|stale|absent"}`.
- Add typed frontend contracts in `web/src/types/applications.ts`: `BusinessModel` (mirrors the contract) + `BusinessMapEnvelope`
  + `BusinessMapStatus`, kept in sync by the MSW fixtures (like the existing applications types).

**No new env dependency**; launch is KB-only. Reuse the `_latest_*_run(workflow_id=…)` helper generalized for
`generate-business-map`.

## 3. Definition of Done
- Endpoints return correct shapes; generate 404s untracked, 400/409s an unsynced app, and returns a `run_id` otherwise;
  status merges run + row; get returns `absent`/`ready`/`stale` correctly.
- API tests (like the 8 applications-API tests) cover: absent → generate → generating → (stubbed workflow) ready → get;
  stale after a new sync. `ruff` + genesis pytest green. Ships in the Phase-17 backend genesis release.
