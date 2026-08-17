# 23-01 — Full-package ("Refresh") application sync

> **Status:** ✅ CODE-COMPLETE (2026-08-17; genesis code **held for the v0.48.0 release** at 23-03) · **Phase:** 23 ·
> **Repo:** genesis (+ project-tracker) · **Depends on:** — (the `sync-application` delta mode already ships in
> genesis-workflows v0.2.2)
>
> **As-built:** `api/applications.py` — `_start_sync` now resolves the mode (`_resolve_mode`: none/""/"auto" → baseline if
> no `baseline_sync_id` else delta; `refresh`→`delta`; baseline/delta pass through; unknown → 400) and rejects a second sync
> while one is non-terminal (`_sync_running` via `run_manager.list`+`reconcile_status` → **409**). `SyncBody.mode` is now
> `str | None = None` (omitted → auto-pick). Web: the app-detail action is relabeled **"Refresh"**, disabled while a sync
> runs, and posts **no mode** (auto-pick) — `applicationsApi.sync` omits `mode` when unset; `useSyncApplication` passes an
> optional mode. **Tests:** backend +4 (delta/refresh unblock, unknown-mode 400, auto-pick baseline↔delta, 409 guard) →
> **441** green; web +1 (Refresh → mode-less POST) → **161** green; ruff/eslint/tsc clean; `web/static` rebuilt. No
> genesis-workflows/schema change.

## Goal

Make the application sync **re-runnable as a full-package refresh** by exposing the already-built `mode=delta` path (full
re-export → parse → diff against the DB → write only the changes) that today is blocked at the API. No new engine, no workflow
change, no schema change.

## Background (verified)

- `sync-application` `mode=delta` (16-07 Option A) does a **full re-export** + `KbStore.apply(mode='delta')` →
  `_apply_delta`: diff current rows (`valid_to_sync IS NULL`) by `diff_hash` → open new / close+reopen modified / **close
  removed (inferred from the re-parse)** / diff edges by `(source,target,dep_type)` / recompute bundles / mark the Business Map
  stale. This **is** "full package, compare, write changes."
- `POST /api/applications/{uuid}/sync` already accepts `body.mode` and forwards it. The blocker is `_start_sync`:
  `if mode != "baseline": raise HTTPException(400, "delta not supported yet")`, and re-running baseline errors "already has a
  baseline."

## Behavior

- **Unblock delta.** In `api/applications.py._start_sync`, remove the non-baseline `400` guard and pass the resolved mode to
  `run_manager.start("sync-application", {"app_uuid", "app_name", "mode"})`.
- **Mode resolution.** Accept `mode ∈ {baseline, delta, refresh}`; map **`refresh` → `delta`**. When `mode` is **omitted**,
  auto-pick: `baseline` if the app has no `baseline_sync_id`, else `delta`. (The workflow's `resolve_inputs` still fails fast on
  a wrong explicit mode, so auto-pick is the safe default.)
- **Already-running guard.** If a `sync-application` run for this `app_uuid` is non-terminal (`run_manager.list(workflow_id=
  "sync-application")` filtered to this app + `status ∉ TERMINAL`, reconciled), return **409** with a clear message instead of
  starting a second export (the Appian Deployment API rejects concurrent exports).
- **(Optional) Web Refresh action.** A **Refresh** button on the app detail page (Overview and/or Syncs tab) → `POST …/sync`
  (no body → auto-pick) → toast + the existing sync-status bar; disabled while a sync is running. If it lands, `npm run build` +
  commit `web/static`.

## Acceptance

- `POST /api/applications/{uuid}/sync` on a **baselined** app starts a **delta** run that completes; the KB reflects
  added/modified/removed objects (SCD-2), bundles recomputed, Business Map marked stale.
- `POST …/sync` with no body auto-picks baseline (un-baselined) vs delta (baselined).
- A second `POST …/sync` while one is running returns **409**, not a duplicate export.
- (Optional) the Refresh button triggers the above and reflects progress.

## Tests

- API: delta unblock (mode=delta and mode=refresh both start a delta run — mocked `RunManager`); omitted-mode auto-pick
  (baseline vs delta by `baseline_sync_id`); the **409** already-running guard (mocked non-terminal run). Assert the returned
  `{sync_run_id}` shape is unchanged.
- (Optional) a Vitest test for the Refresh action's enabled/disabled states.

## Notes

- **Naming:** users see **"Refresh"**; the internal `KbStore` mode stays `delta` (it accurately names the merge). This directly
  addresses the "delta = environment patch" confusion — the refresh is a **full re-export + local diff**, needing nothing new
  from the environment.
- No genesis-workflows release (the workflow is unchanged). genesis-only, **no schema** change in 23-01.
