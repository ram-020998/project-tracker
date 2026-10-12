# 45-06 — `sync-application` v0.3.0: the incremental path

> **Status:** 🟡 DRAFTED. Repos: **genesis-workflows** (workflow) + **genesis** (`ApplicationSyncService`).
> Implements **ADR-074** (workflow). Parent: `specs/phase-45-incremental-delta-sync.md`.

## 1. Inputs (`inputs_schema`)

`mode`: `baseline | full | incremental | auto` (default `auto`; legacy `delta` = `full`). New optional `options`
`{full_every_days: 7, max_changed: 500, max_changed_pct: 25}` (the scheduler/API pass the configured values).

## 2. Graph (program-only; no agent → no reliability trio; ADR-001)

```
resolve_inputs → plan_sync ─┬─(baseline|full)──► export_app ─────────────┐
                            ├─(incremental)───► build_delta_package ──► export_package ─┤
                            └─(no changes)────► record_empty_sync ──► present          ▼
                                                     parse_package → v_parse → write_kb → v_kb → publish_hub → present
```

- **`resolve_inputs`**: as today + reads `last_successful_sync` (any kind) and the last **full** sync
  (`baseline|full|delta`). `auto` → `baseline` if no baseline; `full` if the last full is ≥ `full_every_days` old;
  else `incremental`.
- **`plan_sync`** (incremental only; async, `to_thread`):
  1. `sweep_leftovers(app_uuid)`.
  2. `covered_until` = last successful sync's `details.covered_until` or `started_at`; `since_date` =
     (covered_until UTC date − 1 day); `after` = covered_until − 5 min.
  3. `run_started_at` captured **before** listing → becomes this sync's `covered_until` on success.
  4. `changed = list_changed(app_uuid, since_date, after)`.
  5. No changes → `record_empty_sync` (an `incremental` kb_syncs row with zero counts + `covered_until`).
  6. Fallback → `full` when `len(changed) > max_changed` or `> max_changed_pct` of the app's current object count;
     records `fallback_reason`.
- **`build_delta_package`**: `create_delta_package` → `add_objects(changed + all current entry-point roots)` → record
  `failed` as `skipped_objects` (warning, D6) → export via the existing Deployment REST seam with
  `exportType=package` → zip to the blackboard → **`finally: delete_delta_package`**.
- **`export_app`**: today's full export (unchanged).
- **`parse_package`**: incremental → `parse(zip, known_objects, known_edges)` from `kb_store.known_context`; full →
  `parse(zip)` as today. `COMPLETED_WITH_EXPORT_ERRORS` → `export_warnings` (warning, D6).
- **`write_kb`**: `apply(mode='incremental'|'full'|'baseline')` + `finish_sync(details=…)`. Still a raw async node
  using `to_thread`.
- **`publish_hub`** (45-08): best-effort; failure is logged + recorded, never fails the run.
- **`present`**: `report.json` gains `sync_kind`, `fallback_reason`, `changed_count`, `skipped_objects`,
  `export_warnings`, `published_version`.

## 3. Validators

- `check_kb` incremental: `objects_removed == 0`; `0 ≤ added + modified ≤ package objects`.
- `check_parse` incremental: the package's object set ⊇ the changed objects that were added (minus `failed`).

## 4. Errors

- Dev MCP `version_mismatch` / `auth` → terminal error with the 45-02 message.
- Export 409 busy / 5xx / timeout → existing transient retry.
- Any failure after `create_delta_package` still deletes the package (`finally`) and leaves `covered_until` unchanged.

## 5. `ApplicationSyncService` (genesis)

- `resolve_mode(app, requested)`: `auto`/`""` → **`auto`** (decided in-run); `refresh` → `auto`; `full`/`delta` →
  `full`; `incremental` / `baseline` pass through.
- `start_sync(app, name, mode, options)` passes the configured options (from the schedule row, 45-07).
- `POST /applications/{uuid}/sync {mode}` accepts the new modes.

## 6. Tests (genesis-workflows `sync-application/tests`)

Monkeypatch the Dev MCP + export seams: incremental happy path; empty change set; size fallback; 7-day fallback;
package deleted on export failure; `failed` objects recorded but the run succeeds; version-mismatch terminal error;
`covered_until` advances only on success; the legacy `delta` mode still means full. Version **0.3.0**.
