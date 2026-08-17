# 23-02 — Scheduler foundation + schedule table (m0012)

> **Status:** ✅ CODE-COMPLETE (2026-08-17; genesis code **held for the v0.48.0 release** at 23-03) · **Phase:** 23 ·
> **Repo:** genesis (+ project-tracker) · **Depends on:** 23-01 (the refresh path the app-sync job will call)
>
> **As-built:** **m0012** `genesis/db/migrations/m0012_scheduled_jobs.py` (`scheduled_jobs` table; `current_version` 11→12;
> registered in `migrations/__init__.py`). `genesis/runtime/schedule_store.py` — `ScheduleStore` (`list_jobs`/`get`/
> `ensure_defaults` [seeds/refreshes definitions, never clobbers `enabled`/last-run]/`mark_fired`/`set_enabled`/
> `update_schedule`) + `ScheduledJob` dataclass. `genesis/runtime/scheduler.py` — the pure `due_slot(schedule, now_local,
> last_fired_slot)` (daily_times, weekdays-only, latest-passed-slot, within-day catch-up, no cross-day re-fire) + `Scheduler`
> (60s tick loop; handler-gated **skip-without-marking** when no handler; **mark-before-work** overlap guard; async-or-sync
> handlers; error captured to `last_run_*`; `start()` defensive against a missing/locked table). `genesis/runtime/sync_jobs.py`
> — `DEFAULT_JOBS` (application-sync 07:00 IST weekdays; document-library-sync 08/12/16/20 IST weekdays). Wired in
> `api/app.py` create_app: `ScheduleStore`+`Scheduler(defaults=DEFAULT_JOBS)` on `app.state`; started in a `startup` event,
> stopped in `shutdown`. **No jobs fire yet** — 23-03 registers the handlers. **Tests:** `tests/test_scheduler.py` (13:
> due_slot matrix incl. weekend/before-first/catch-up/no-cross-day/multi-time; `ScheduleStore` round-trip + `ensure_defaults`
> idempotency preserving enabled/last-run; Scheduler fires-once/skip-no-handler/skip-disabled/error-capture/async-handler) →
> backend **454** green; ruff clean (genesis + new files). The v11→v12 schema bump updated the hardcoded version assertions in
> `test_db`/`test_chat_store`/`test_document_store`/`test_feature_store`/`test_kb_store` (+ a `scheduled_jobs` row assertion;
> the synthetic "next migration" test bumped to v13). Boot-smoke verified: scheduler task runs, both jobs seeded, clean stop.

## Goal

Add a lightweight, restart-safe, TZ-aware **backend scheduler** and the **DB table** that holds its schedule + last-run
bookkeeping — with **no jobs firing yet** (the two concrete jobs land in 23-03). Establishes the seam for later user config.

## Data model — migration m0012 `scheduled_jobs`

Forward-only migration (`current_version` 11 → 12) adding one table (see the umbrella §4 for columns):
`id, job_key (UNIQUE), name, enabled, schedule_json, last_fired_slot, last_run_at, last_run_status, last_run_detail,
created_at, updated_at`. Schema owned by `genesis/db/migrations/m0012_scheduled_jobs.py` (never hand-write DDL elsewhere).

`ScheduleStore` (`genesis/runtime/schedule_store.py` or `genesis/db/`-adjacent, DB-agnostic signatures — ADR-030):
- `list_jobs()`, `get(job_key)`, `ensure_defaults(defaults: list[dict])` (idempotent upsert of *definitions* only — never
  clobbers `enabled` / `last_fired_slot` / `last_run_*` for an existing row), `mark_fired(job_key, slot, status, detail, at)`,
  and `set_enabled` / `update_schedule` (for the future config UI; unused this phase).

## Scheduler engine — `genesis/runtime/scheduler.py`

- **`Scheduler`** built in `create_app()` with `run_manager`, `kb_store`, `config`, `ScheduleStore`, and a **job registry**
  (`{job_key: callable}` — populated in 23-03). Exposes `start()` / `stop()`.
- **Start/stop:** started in `@app.on_event("startup")` (`self._task = asyncio.create_task(self.run())`) after
  `ensure_defaults(...)`; cancelled in `@app.on_event("shutdown")`. Boot must never block — the whole loop is in the task and
  every tick is wrapped in try/except + logged.
- **Tick loop (`run()`):** `while True:` → `await asyncio.sleep(60)` → for each enabled job compute the **due slot** and fire if
  due (see below). One tick evaluates all jobs; a firing job runs as its **own task** so a long job never blocks the tick.
- **Due-slot logic (pure, unit-tested):** `due_slot(schedule, now_local, last_fired_slot) -> str | None`:
  - resolve `now_local` in `schedule.timezone` (stdlib `zoneinfo`);
  - if `weekdays_only` and it's Sat/Sun → `None`;
  - among today's `times`, take the **latest** `t ≤ now_local`; slot key = `"<YYYY-MM-DD>T<HH:MM>"` (local date + time);
  - return the slot **iff** `slot != last_fired_slot` (restart catch-up **within the day**; the embedded date prevents a
    cross-day re-fire). Return `None` if no time has passed yet today.
- **Overlap guard:** an in-memory `_running: set[job_key]` + `mark_fired(...)` recorded **before** the async work starts, so the
  next 60 s tick sees the slot already fired.
- **Fire:** look up the job callable, `_running.add(job_key)`, `mark_fired(job_key, slot, 'ok'|…, detail, now_utc)` on
  completion (status/detail from the job's return), `_running.discard` in `finally`. Exceptions → `status='error'` + logged,
  never propagated to the tick loop.

## Acceptance

- `genesis db upgrade` creates `scheduled_jobs`; `current_version == 12`.
- On boot, `ensure_defaults([...])` inserts the two job definitions (23-03 wires the callables); the scheduler task starts and
  stops cleanly with the app; no job fires until its callable is registered + a slot is due.
- `due_slot` returns the right slot for weekday daytime times, `None` on weekends / before the first time, and never re-fires a
  slot already in `last_fired_slot` (incl. after a simulated restart mid-day; a next-day tick yields a new slot).

## Tests

- `ScheduleStore` round-trip + `ensure_defaults` idempotency (re-run preserves `enabled`/last-run).
- `due_slot` fake-clock matrix: weekday vs weekend; before-first-time vs mid-day vs after-last-time; catch-up within a day;
  no cross-day re-fire; multi-time (08/12/16/20) picks the latest passed slot.
- A migration round-trip test (m0012 up → schema shape).

## Notes

- **No new dependency** — `asyncio` + stdlib `zoneinfo`. (APScheduler is the documented fallback if cron strings are ever
  wanted.) Keep the engine transport-agnostic of *which* jobs exist — 23-03 only registers callables + seeds rows.
