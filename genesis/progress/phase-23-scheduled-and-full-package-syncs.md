# Phase 23 — Scheduled & Full-Package Syncs — as-built

> **Status:** ✅ SHIPPED + COMPLETE (23-01..23-03). **genesis v0.48.0** (`3fb8f08`, tag `v0.48.0`), CI green — pipeline
> **#6588951** (genesis + frontend + clean-install). **ADR-047** Accepted. genesis-only + **m0012**; genesis-core /
> kiro-agent-sdk / genesis-appian-parser / genesis-workflows unchanged.

## What shipped
Keep the local Appian KB + Document Library fresh automatically — without a human clicking sync.

- **23-01 — full-package refresh app sync.** The application sync is re-runnable: `api/applications.py` unblocks the
  already-built `sync-application` **`mode=delta`** (16-07 Option A) — a **full re-export → parse → diff the DB by `diff_hash`
  → write only the changes** (open new / close+reopen modified / close removed / diff edges / recompute bundles / mark the
  Business Map stale). `_resolve_mode` auto-picks (none/""/"auto" → baseline if no `baseline_sync_id`, else delta; `refresh`
  alias; unknown → 400); `_sync_running`+`_start_sync` return **409** if a sync for that app is non-terminal (the Appian
  Deployment export is one-at-a-time). `SyncBody.mode` is now optional. Web: the app-detail action is relabeled **Refresh**,
  posts **no mode** (auto-pick), disabled while a sync runs. **It is not an environment delta-patch** — true incremental
  (needs the Appian changed-objects API) stays deferred and is unnecessary for daily freshness.
- **23-02 — scheduler foundation.** **m0012 `scheduled_jobs`** (`current_version` 11→12) + `runtime/schedule_store.py`
  (`ScheduleStore`: `list_jobs`/`get`/`ensure_defaults` [seeds/refreshes definitions, never clobbers enabled/last-run]/
  `mark_fired`/`set_enabled`/`update_schedule`) + `runtime/scheduler.py` — the pure `due_slot(schedule, now_local,
  last_fired_slot)` (daily_times, weekdays-only, latest-passed-slot, within-day catch-up, no cross-day re-fire) + a `Scheduler`
  (60s tick; **jobs run as background tasks** so a long job never blocks the loop; **mark-before-work** overlap guard;
  async-or-sync handlers; errors captured; `start()` defensive against a missing table; `wait_idle`/`stop`). Wired in
  `api/app.py` create_app (startup/shutdown). `runtime/sync_jobs.py` holds `DEFAULT_JOBS`.
- **23-03 — jobs + endpoint + release.** `register_sync_jobs` wires two handlers: **`application-sync`** (preflight-skip if no
  dev env / workflow uninstalled; iterate `kb_store.list_applications()` **serially** — start → poll `run_manager.get(...)
  .status ∈ TERMINAL` [20-min cap] → next; per-app mode-pick via `get_application().baseline_sync_id`; skip an app already
  syncing; tally `N apps: X ok, Y skipped, Z error`) and **`document-library-sync`** (preflight-skip if `gws` down / workflow
  uninstalled; one `sync-documents` `scope=library` run). Seeded schedule: app-sync **07:00 IST weekdays**; doc-sync **08:00/
  12:00/16:00/20:00 IST weekdays**. Read-only `GET /api/system/schedules` (`api/schedules.py`) exposes definitions + last-run +
  an advisory `next_due`; **no write/config surface this phase**. Released **genesis v0.48.0**.

## Verification
- **Gate:** backend **464** pytest + ruff (genesis + new files clean); web **161** Vitest + eslint (0 errors) + tsc + build.
- CI pipeline **#6588951** green across genesis + frontend + **clean-install** (the clean-install `genesis db upgrade`
  exercises the m0012 forward migration on a fresh non-editable install).
- New tests: `tests/test_scheduler.py` (13 — due_slot matrix + `ScheduleStore` round-trip/idempotency + tick/fire engine),
  `tests/test_sync_jobs.py` (10 — app-sync serialization/mode-pick/skips/tally, doc-sync single-run/skips, `/system/schedules`),
  `tests/test_applications_api.py` (+4 — delta/refresh unblock, unknown-mode 400, auto-pick, 409 guard). The v11→v12 bump
  updated the hardcoded version assertions in `test_db`/`test_chat_store`/`test_document_store`/`test_feature_store`/
  `test_kb_store` (+ a `scheduled_jobs` row assertion; the synthetic "next migration" test bumped to v13).
- Boot smoke: `create_app` startup runs the scheduler, seeds both jobs (correct IST times/weekday flags), registers both
  handlers, and shuts down cleanly.

## Manual / deferred
- **Live acceptance is user-observed** (schedule-driven): leave `genesis serve` up across a slot (or temporarily seed a
  near-future time) → the app-sync job fires once, runs apps serially, records `last_run_*`; the doc job fires on its
  4-hour slots and skips overnight/weekends. **Requires a `genesis serve` restart to load v0.48.0.**
- **Deferred:** true incremental delta (Appian changed-objects API — backlog §1.3); a user-facing schedule config UI (the
  read-only `GET /api/system/schedules` + the `scheduled_jobs` table are the seam); a `scheduled_job_runs` history table
  (each sync is already a `sync-application` run in `run_events`); per-app document scheduling; retries/backoff at the
  scheduler layer.
