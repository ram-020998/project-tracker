# 54-04 — Schedule model, storage (m0030) and the scheduler engine

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis (`genesis/runtime/`, `genesis/db/`, `genesis/testexec/`,
> `genesis/runs/`). Parent: `specs/phase-54-schedules-and-fixes.md`. Built by **genesis-dev**. Decisions: D8–D12, D14,
> D15, F1, F2, F8, F11 (`54-01-findings.md` §8–§9). ADR draft: `adr-drafts.md` (ADR-087).

## 1. Migration m0030 (DB v29 → v30)

Forward-only, through the migration runner (L-102 if any table is rebuilt; prefer `ALTER TABLE … ADD COLUMN`):

1. `scheduled_jobs` + `kind TEXT NOT NULL DEFAULT 'system'`, `target_json TEXT`, `policy_json TEXT`,
   `failure_count INTEGER NOT NULL DEFAULT 0`, `pause_reason TEXT` (`user`|`failing`|`completed`, NULL = active),
   `runs_count INTEGER NOT NULL DEFAULT 0`. `enabled` stays as the on/off switch the user sees; `pause_reason` says why
   an enabled-but-not-firing row is paused (keep one source of truth: define in As built whether "off" = `enabled=0`
   or `pause_reason='user'`, and use only that one).
2. `schedule_runs` (`id` PK, `schedule_id` → `scheduled_jobs.id` ON DELETE CASCADE, `slot` TEXT, `outcome` TEXT,
   `run_id` TEXT NULL, `execution_key` TEXT NULL, `reason` TEXT NULL, `started_at`, `finished_at`; index
   `(schedule_id, slot)`). Deleting a schedule deletes its rows in the same transaction (L-103).
3. `runs` + `trigger_json TEXT` (NULL for every non-scheduled start).
4. `notifications` (`id` PK, `source` TEXT, `kind` TEXT, `title`, `body`, `link`, `ref` TEXT (e.g. `schedule:<id>`),
   `created_at`, `read_at` NULL; index on `read_at`) (D11).
5. `custom_agents` (F3): created here so one migration carries the phase; its store and rules are 54-05.
6. **Data migration (once, L-081):**
   - every existing row gets `kind='system'`, a `policy_json` with the defaults of §3 and the system caps of §4, and
     its `schedule_json` unchanged (old kinds stay valid);
   - each `regression-run` `options.apps[<uuid>]` entry with cadence ≠ `off` becomes a `kind='user'` row: name
     "Regression: <app name>" (from the KB; the uuid if the app is gone), `target_json {type:"regression", app_uuid}`,
     schedule from the entry (`daily` → daily at `time`; `weekly` → weekly on `days` at `time`), zone = the job's zone,
     enabled; its `since` value is kept in `target_json` if the regression code reads it;
   - the `regression-run` row is deleted after the copy. Test the migration from real stored rows (a copy of the
     user's `scheduled_jobs` shape, L-083), including an app-sync row with `user_modified=1`.

## 2. Schedule model (`runtime/scheduler.py`)

Keep `daily_times` and `interval_window`; validate `days` (0–6, Mon = 0) instead of dropping it (today
`validate_schedule` returns only known keys, `:70-98`); add `monthly` (`day_of_month` 1–31, `times[]`; a day past the
month's end fires on the last day) and `once` (`at` local datetime). The web's five forms (D9) map to: every N hours in
a window → `interval_window`; daily → `daily_times`; weekly → `daily_times` + `days`; monthly → `monthly`; once → `once`.
Every schedule carries an IANA `timezone` (user default: the machine's zone; system rows keep `Asia/Kolkata`).

Pure functions, unit-tested across DST changes and month ends:
- `slots_between(schedule, start, end)` → ordered local slot keys;
- `next_runs(schedule, now, n=5)` → the preview (F7);
- `due(schedule, now, last_slot, grace)` → `(fire_slot | None, missed_slots[])` (§3.1).

## 3. Engine rules (the tick, every 60 s; system and user rows alike)

1. **Missed (D10):** after a gap, the latest missed slot fires if `now - slot < grace` (default 12 h, `policy.grace_h`);
   every other slot since `last_fired_slot` gets a `schedule_runs` row `missed` (one bell notice per gap per
   schedule). At most one catch-up per schedule per gap. A `once` schedule past grace → `missed` and
   `pause_reason='completed'`. Mark the slot before the work (today's mark-before-work, `:202`).
2. **Overlap (D10):** a due slot whose schedule has a run in flight (including at a gate) records `skipped` with
   reason "previous run still active" and does not fire. In flight is decided from stored state (the open
   `schedule_runs` row and its run's status), not only the in-memory `_running` set, so a restart does not double-fire.
3. **Readiness skips (D12.3):** a handler that cannot start (no Dev, Kiro not signed in, workflow missing or not
   `schedulable`, collaboration off, designated machine) records `skipped` with the reason; not a failure.
4. **Follow the run (D12.1):** every handler waits for its run (or `TE-` execution) to reach a terminal state, off the
   event loop's blocking paths (L-026), and the `schedule_runs` row gets `ok`/`failed`/`cancelled` from it. The
   `document-library-sync` handler stops recording `ok` at start. Reach a terminal row on every error path (a
   `finally`, L-107).
5. **Max run duration (D12.2):** `policy.timeout_min` (user default 120); past it, cancel the run through
   `RunManager.cancel` (stop intent recorded first, CAS terminal write, L-108) and record `failed` "timed out".
6. **Gate wait (D8):** when the schedule's run reaches `awaiting_gate`, raise a bell notice "needs you" once; cancel the
   run (L-108) at the earlier of the schedule's next due slot and `policy.gate_max_wait_h` (default 24) after the gate
   opened; record `failed` "gate not answered". A gate answered in time continues normally.
7. **Failures (D12.4):** `failed` increments `failure_count`; `ok` resets it; at `policy.max_failures` (default 3, 0 =
   never) set `pause_reason='failing'` and raise "auto-paused". Resume clears both.
8. **End date / max runs (F8):** past `policy.end_at` or at `policy.max_runs` fired runs, `pause_reason='completed'`.
9. **Run now (F8):** fires the target immediately, records a `schedule_runs` row with slot `manual:<utc>`, does not move
   `last_fired_slot`, refused while in flight; counts toward failures like any run.
10. **Trigger:** every run a schedule starts gets `runs.trigger_json = {source:"schedule", schedule_id, slot}` (set by
    `RunManager.start(..., trigger=…)`, a new optional parameter; other callers unchanged). Regression executions keep
    `kb_test_executions.trigger_json` and add `schedule_id`.
11. **Single owner:** the tick runs only while this process holds the run-owner lock (`holds_run_owner_lock()`,
    L-097), so two `genesis serve` on one data dir do not both fire.

## 4. Handlers per target and system row

- **System rows** keep their handlers and skip rules (`runtime/sync_jobs.py`, `runtime/memory_jobs.py`): app sync stays
  serial with its per-app wait (L-050); its default `timeout_min` = per-app cap × tracked apps, so the 2 h user default
  never cuts a long sync (record the formula in As built). `kb-hub-pull` is in-process: its result is the call's
  outcome. Options stay in `options_json` and are edited through the schedule API (D15).
- **`workflow`:** `RunManager.start(workflow_id, inputs, trigger=…)`; refuse (skip, reason) if the installed META lacks
  `schedulable: true` (D7); file inputs (`format:"file"`) are not allowed in a schedule's stored inputs this phase
  (54-05 §5).
- **`agent_prompt`:** builds the `agent-prompt` inputs (54-05 §4) from `target_json`, with the custom agent snapshot
  taken at fire time; re-checks the read-only server rule (D3) before start.
- **`regression`:** `TestExecutionService.start_regression(app_uuid, trigger={"source":"schedule","schedule_id":…,
  "slot":…})`; follows the execution to terminal; skip if the app is gone or busy (today's rules,
  `testexec/regression_job.py:103-141`). `regression_job.py`'s dispatcher is retired (its file and registration
  removed once nothing imports them, L-094).

## 5. Store API (`runtime/schedule_store.py`)

Add: `list(kind=None)`, `get(id)`, `create_user(name, target, schedule, policy)`, `update(id, …)` (system rows: only
schedule, enabled, options and policy; sets `user_modified`), `delete_user(id)` (refuses system rows),
`reset_system(job_key)` (restores defaults, clears `user_modified`), `duplicate(id)`, `record_slot(...)`,
`history(id, limit, offset)`, `set_pause(id, reason|None)`. Writes that validate then write take the write lock first
(L-091). `ensure_defaults` keeps respecting `user_modified` and never re-creates `regression-run` (L-081).

## 6. Notifications store (`genesis/notifications/` or `runtime/notifications.py`)

`add(source, kind, title, body, link, ref)`, `list(unread_only, limit, offset)`, `unread_count()`, `mark_read(id)`,
`mark_all_read()`. A notice for the same `ref` + `kind` while an unread one exists is not duplicated. Blocking writes off
the event loop (L-026).

## 7. Tests

Pure schedule functions (DST, month ends, `once`, window crossing midnight not allowed unless the current code allows
it); engine with a fake clock: gap → one catch-up + `missed` rows; overlap skip; gate wait → cancel at next slot and at
max wait; timeout cancel; three failures → paused failing; readiness skip not counted; run now refused while in flight;
restart mid-run does not double-fire (stored in-flight state); migration from real rows; `trigger_json` on started runs
through the real `RunManager` (L-093). The faked clock must not mix with real stored timestamps (the Phase 53 D27 flake
pattern, `test_regression_job_handler_starts_due_apps_and_skips_busy_ones`): rewrite that test for the new handler with
one clock.

## 8. Gates

`cd genesis && .venv/bin/python -m pytest -q -p no:warnings`, `.venv/bin/ruff check genesis`.

## As built

_(genesis-dev fills in: commits, changes, tests, review verdict, decisions/deviations, lesson candidates, code-map
changes, Resume note.)_

## Context manifest

```toml
areas    = ["runs-worker", "db", "config-secrets", "browser-testing"]
adrs     = ["ADR-009", "ADR-012", "ADR-021", "ADR-030", "ADR-047", "ADR-063", "ADR-074"]
lessons  = ["L-026", "L-050", "L-081", "L-083", "L-091", "L-093", "L-094", "L-097", "L-102", "L-103", "L-107", "L-108"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md", "tracker:specs/phase-45-incremental-delta-sync.md"]
code     = ["genesis/genesis/runtime/scheduler.py", "genesis/genesis/runtime/schedule_store.py", "genesis/genesis/runtime/sync_jobs.py", "genesis/genesis/runtime/memory_jobs.py", "genesis/genesis/testexec/regression_job.py", "genesis/genesis/db/migrations/**", "genesis/genesis/runs/manager.py", "genesis/genesis/runs/store.py", "genesis/genesis/api/app.py"]
upstream = ["54-02"]
```
