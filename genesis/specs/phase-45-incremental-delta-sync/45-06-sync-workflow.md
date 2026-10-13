# 45-06 — `sync-application` v0.3.0: the incremental path

> **Status:** ✅ SHIPPED 2026-10-13 (see the as-built section). Repos: **genesis-workflows** (workflow) + **genesis** (`ApplicationSyncService`).
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

## 7. As built (2026-10-13; genesis-workflows `f05ea97`, genesis `3714215`, local) — deviations from §1–§5

- **Graph:** `resolve_inputs → plan_sync →{full: export_package | incremental: build_delta_package | empty:
  record_empty_sync}`; `build_delta_package →{validate: v_export | full: export_package}` (falls back when no changed
  object could be added); `v_export →{retry: export_package | retry_delta: build_delta_package}` (an export retry
  REBUILDS the delta package, so every attempt creates + deletes its own package). `publish_hub` is added in 45-08.
- **Mode decision in `resolve_inputs`** (not `plan_sync`): `auto` → baseline if none; else incremental unless
  `full_sync_reason` says full — no successful full sync; **`details.parser_version` missing or an older minor**
  (both explicit `incremental` and `auto`); last full ≥ `full_every_days` old (**`auto` only** — an explicit
  `incremental` request skips the age rule). Also full when the platform lacks `ctx.extras['devmcp_packages']` or the
  KB store lacks `last_successful_sync`, or the parser has no `delta_roots` (version skew safety).
  `package_uuid` given → full. Legacy `delta` = `full`; `refresh` = `auto`.
- **`covered_until`:** full/baseline = the instant `resolve_inputs` ran (before the export); incremental/empty = the
  instant before `list_changed`. The listing starts at the last successful sync's `covered_until` (else `started_at`)
  − 5 min; `list_changed` itself widens the date filter by a day (45-05 §5). A failed write records no details.
- **Fallbacks in `plan_sync`:** size (`max_changed`, `max_changed_pct` of the KB's current object count); Dev MCP
  **unreachable/other** → full ("could not list changed objects"); **`version_mismatch` / `auth` → terminal error**
  (not hidden by a fallback). Leftover sweep failures are logged, never fatal.
- **`skipped_objects`** = add errors + non-packageable types (capped at 20 in state/details; the full list is in
  `delta/plan.json`). `check_parse` requires every *added* changed object in the parse unless the export reported
  `COMPLETED_WITH_EXPORT_ERRORS` (then `export_warnings`).
- **genesis `ApplicationSyncService`:** `resolve_mode` returns `auto|baseline|full|incremental` and **adapts to the
  installed workflow's `mode` enum** — a library with sync-application 0.2.x (only `baseline|delta`) gets `delta` for
  every refresh, so the fleet (still on library v0.20.0) keeps working until it is re-provisioned at 45-10.
  `start_sync(..., options=)` passes options only when the installed schema declares them.

**Evidence:** workflows pytest **233** (+14: `tests/test_incremental_sync.py`) + validate_library 13; genesis pytest
**896** + ruff. Offline end-to-end with the REAL parser (vendored export, temp state dir): baseline 2,620 objects /
10,617 edges / 174 bundles → incremental (25 changed → 176-object delta package incl. 151 roots; package deleted) →
KB unchanged 2,620 / 10,617 / 174, details `{sync_kind: incremental, parser_version: 0.3.0, changed_count: 25}`.
Host check: with the installed v0.2.3 library, every refresh mode resolves to `delta`.
