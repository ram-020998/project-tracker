# 54-04 — Schedule model, storage (m0030) and the scheduler engine

> **Status:** BUILT 2026-11-18 (genesis `b09b08e..9a365c0`, local; review SHIP, `reviews/54-04-review.md`). Repo: genesis (`genesis/runtime/`, `genesis/db/`, `genesis/testexec/`,
> `genesis/runs/`). Parent: `specs/phase-54-schedules-and-fixes.md`. Built by **genesis-dev**. Decisions: D8–D12, D14,
> D15, F1, F2, F8, F11 (`54-01-findings.md` §8–§9). ADR draft: `adr-drafts.md` (ADR-087).

## 1. Migration m0030 (DB v29 → v30)

Forward-only, through the migration runner (L-102 if any table is rebuilt; prefer `ALTER TABLE … ADD COLUMN`):

1. `scheduled_jobs` + `kind TEXT NOT NULL DEFAULT 'system'`, `target_json TEXT`, `policy_json TEXT`,
   `failure_count INTEGER NOT NULL DEFAULT 0`, `pause_reason TEXT` (`user`|`failing`|`completed`, NULL = active),
   `runs_count INTEGER NOT NULL DEFAULT 0`. `enabled` is the on/off switch; `pause_reason` says why an enabled row is
   paused. They stay separate (D23): off = `enabled = 0`; Pause = `pause_reason = 'user'`; an off schedule never fires,
   and Run now / Pause / Resume on it are refused.
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
   - **No repair of old runs** stored `running` by a pre-fix state edit (D21): m0030 does not touch `runs.status`, and
     `reconcile_status` is unchanged.

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

**Status:** BUILT 2026-11-18, review **SHIP** (re-run 2). Repo genesis, branch master, base `b09b08e`, head `9a365c0`,
4 local commits (not pushed, not tagged). 34 files, +3109/−886. Backend only; no web file changed.

### Commits (genesis)

| sha | what |
|---|---|
| `41d4d0e` | m0030, schedule model, store, notifications store, engine, target handlers, `runs.trigger_json`; the regression dispatcher retired; tests |
| `e45a042` | review round 1: B1 (idle time stored on the row), m1, m2, n2, n3 |
| `f03066d` | review re-run 1: M1 (a failed close is recovered by the next tick), n5 |
| `9a365c0` | review re-run 2 m3: a past one-time schedule cannot be turned on |

### Changed

- **m0030** (`db/migrations/m0030_schedules.py`, DB v29 → v30). Additive and guarded, with no table rebuild.
  - `scheduled_jobs` gains `kind`, `target_json`, `policy_json`, `failure_count`, `pause_reason` and `runs_count`.
  - New table `schedule_runs`: the §1.2 columns plus `gate_opened_at`, `idle_since` and `idle_s`. It has
    `ON DELETE CASCADE` and the indexes `(schedule_id, slot)` and `outcome='fired'`.
  - New tables `notifications` (indexes `read_at` and `(ref, kind)`) and `custom_agents` (the F3 columns; no store yet).
  - `runs` gains `trigger_json`.
  - Data step, in the migration's own transaction:
    - Every existing row becomes `kind='system'` with the default policy. `application-sync` gets
      `timeout_min: null`, which means "auto". `schedule_json`, `options_json`, `enabled` and `user_modified` are
      untouched.
    - Each `regression-run` entry that is `daily` or `weekly` and valid becomes a user row "Regression: <KB name, or
      the uuid>". It gets the job's zone and the old job's `enabled`. Its `last_fired_slot` is the later of `since`
      and the app's newest regression execution, so it catches up exactly as the dispatcher did. `since` is not kept.
    - The `regression-run` row is then deleted.
    - `runs.status` is not touched (D21).
- **Schedule model** (`runtime/schedule_model.py`, new; re-exported by `runtime/scheduler.py`).
  - `validate_schedule` keeps `days` and adds `monthly` (`day_of_month` 1–31, clamped to the month's last day) and
    `once` (`at`). A window that crosses midnight is still refused.
  - Pure functions: `slots_between`, `next_runs` and `due` (D10 grace), plus `validate_policy`, `default_policy`,
    `machine_timezone()` and `slot_key`/`slot_instant`/`parse_instant`.
  - Slots compare by instant with `fold=0`. A slot in a skipped hour fires at the shifted time; a slot in a repeated
    hour fires once.
  - `due_slot` and the same-day rule are gone.
- **ScheduleStore** (`runtime/schedule_store.py`, rewritten): see "For 54-05 / 54-06" for the API.
  - Every read-validate-write starts with `BEGIN IMMEDIATE` (L-091).
  - `ensure_defaults` keeps its L-081 rules, fills a missing policy, and never creates a key in
    `RETIRED_JOB_KEYS = {"regression-run"}`.
  - "Covered up to now": create, a frequency change, turning on and resume all set `last_fired_slot` to the current
    minute.
  - A `once` must be in the future when it is saved, changed or turned on.
- **NotificationStore** (`runtime/notifications.py`, new): `add`, `list`, `unread_count`, `mark_read`,
  `mark_all_read`. While an unread notice with the same `ref` and `kind` exists, `add` returns it instead of adding
  another (decided under the write lock).
- **Engine** (`runtime/scheduler.py`, rewritten). It uses one injectable clock and ticks only while
  `holds_run_owner_lock()` is true (L-097). All blocking work runs in `asyncio.to_thread`. Each tick runs two phases.
  1. Follow every open `schedule_runs` row, level-triggered:
     - a terminal run or `TE-` execution closes the row;
     - a gate raises a "needs you" notice once and is cancelled at the earlier of the next slot and `gate_max_wait_h`;
     - the run time limit counts only running time; the idle time is stored on the row, so it survives a restart;
     - a run paused by hand is never auto-cancelled;
     - every cancel goes through `RunManager.cancel` or `TestExecutionService.cancel` (L-108).
  2. Evaluate each row: end date and max runs, then `due`, then missed rows (at most 200 per gap, one notice), then
     the overlap skip or a `fired` row plus the handler task. `Fire` carries `trigger`, `note_run()` and `stopped`;
     a handler returns `(status, detail)` or `Started(run_id | execution_key)`.
  - Failures: `ok` resets `failure_count` and `failed` increments it, with one exception. A regression execution whose
    tests ran and ended `failed` or `blocked` is recorded `failed` with a notice, but does not count (Q1 = B). At
    `max_failures` the schedule is paused `failing` with an "auto-paused" notice.
  - Completion: past the end date, at max runs, or after a `once`, the schedule gets `pause_reason='completed'`.
  - Run now (`async run_now(id)`) opens a `manual:<utc>` row. It is refused while the schedule is off, while a run is
    in flight, or without the owner lock.
- **Handlers.**
  - `sync_jobs`:
    - `document-library-sync` returns `Started`, so the result is now the run's final status.
    - `application-sync` stays one serial task (L-050). It records each app's run on the fire, stops when the engine
      cancelled it, and passes the trigger through `ApplicationSyncService.start_sync(trigger=)`.
    - The per-app cap counts only running time.
    - The default limit is `app_sync_timeout_min(n) = 20 × max(1, tracked apps)` minutes.
    - `regression-run` is removed from `DEFAULT_JOBS`.
  - `memory_jobs`: return `Started`; the 30-minute poll is gone.
  - `schedule_targets.py` (new):
    - `workflow`: skipped when the workflow is not installed, when `schedulable` is not `true`, when a required or
      stored file input exists, or when Kiro is signed out and the `graph:` topology has an agent node.
    - `agent_prompt`: **stubbed, always skipped "agent-prompt schedules are not available in this build yet" until
      54-05 passes `agent_prompt_inputs`**.
    - `regression`: skipped when the app is gone, when the app is busy, or on `ExecutionNotReady`; `failed` on
      `ExecutionError`.
- **`runs.trigger_json`**: `RunManager.start(..., trigger=None)`, `RunRecord.trigger`, `RunStore.create`. A scheduled
  `TE-`'s run gets it too (`execution_service._schedule_trigger`).
- **Retired:** `testexec/regression_job.py` (deleted).
  - Consumers updated: `api/app.py`, `sync_jobs`, `regression_service`, and the tests.
  - Grep checked: `genesis/`, `tests/`, `scripts/`, `web/src`, `genesis-fleet`, `genesis-workflows`.
- **Kept working on the new store, with the same response shapes** (until 54-07 and 54-06):
  - `GET /system/schedules` now also lists user rows.
  - `GET/PUT /system/sync-settings`.
  - `POST …/run-now` returns 409 while the schedule is off (D23) and without the owner lock.
  - `PUT /applications/{uuid}/testing/schedule` and the setup GET's `schedule` now read and write the app's own
    regression row.
    - Turning it off disables the row and keeps its history; a new row uses the machine's zone.
    - `since` is the row's `updated_at` while it is on; an unchanged save writes nothing.
    - The note text now says "within a minute".

**Rule from §4 recorded here:** application-sync's default `timeout_min` is `20 min (per-app cap) × max(1, tracked
apps)`, computed at each tick.

### Tests

- `tests/test_scheduler.py` (rewritten, 56 tests):
  - Model:
    - validation (`days`, monthly, once, the policy);
    - month ends and leap years;
    - DST spring-forward and fall-back in `America/New_York`;
    - `due` grace, overlap and midnight.
  - Store:
    - L-081 adoption and user edits;
    - `regression-run` never re-created;
    - the system-row limits;
    - reset and duplicate;
    - covered-up-to-now;
    - delete together with its history (L-103);
    - pause and on/off (D23);
    - the atomic open row.
  - Engine, with one fake clock:
    - a gap gives one catch-up, missed rows and one notice;
    - past grace, every slot is missed;
    - overlap and a restart mid-run (stored state);
    - gate wait to the next slot and to the max wait, and an answered gate;
    - the timeout, with gate and paused time excluded;
    - three failures pause the schedule `failing`, and resume clears it;
    - readiness skips are not counted;
    - the agent-prompt stub;
    - Run now (refused while off or in flight, cadence unmoved, counted);
    - end date, max runs and once;
    - the owner lock;
    - handler errors always reach a terminal row;
    - a live multi-run handler is told to stop;
    - document-library-sync follows its run;
    - Q1 for regressions;
    - the review cases B1 ×2, m1, m2/n2, n3, M1, n5 and m3.
- `tests/test_schedule_engine_real.py`: real `RunManager` and subprocess workers (L-093).
  - `trigger_json` on a scheduled start, NULL on any other start.
  - A real gate is cancelled through `cancel`: exactly one `run.final{cancelled}` and no `failed`.
  - A real SIGTERM-killed run past its limit is cancelled once.
  - A restart while the run is in flight does not double-fire.
- `tests/test_schedule_migration.py`: m0030 from a copy of the real `scheduled_jobs` rows (2026-11-18, read
  immutably), plus regression entries in the 51-08 shape. Covers:
  - the schema;
  - every system row kept;
  - the policies;
  - `runs.status` untouched;
  - the per-app rows and their floors;
  - a boot after the migration;
  - a fresh DB.
- `tests/test_notifications.py`: the API, no duplicates, and 8 threads adding at once.
- **D27 flake rewritten:** `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` is now
  `test_regression_schedule_starts_the_due_app_follows_it_and_skips_busy_ones` (`tests/test_testexec_execution.py`). It
  uses one clock and the real `TestExecutionService` and `RunManager._finalize`. It also checks the TE's trigger and
  `runs.trigger_json`, the gone-app skip, the overlap skip, the close as `ok`, and the busy skip.
- Rewritten for the new store: `test_testexec_regression.py` (schedule round trip; the past slot is not run),
  `test_sync_jobs.py`, `test_memory_jobs.py`, and the hard-coded schema version (29 → 30) in 9 test files.
- **Fail-first and mutation evidence.** Each of these mutations makes its test fail:
  - paused time counted toward the limit;
  - red regression tests counted (Q1);
  - overlap decided from memory only;
  - the `_mine` check removed (m1);
  - idle forced to 0 (B1; the reviewer's probes also failed at `41d4d0e`);
  - the Kiro check removed (m2);
  - the `_mine` discard removed (M1, also checked by the reviewer on an archive copy).
- **Gates at `9a365c0`:** `.venv/bin/python -m pytest -q -p no:warnings` gave **2005 passed** (20:18–20:29 IST,
  outside the D27 window, with no deselect). `.venv/bin/ruff check genesis` is clean. genesis-core was not touched.
- **Migration on a copy of the real DB** (`/tmp/m0030-copy`, a `cp` of `~/.genesis/genesis.db`; the original was not
  written):
  - v29 → v30;
  - the five system rows were kept, and app sync still has `user_modified=1` and `run_on_this_machine: true`;
  - `regression-run` was removed (its only entry was off, so no user row was created);
  - run status counts are unchanged (cancelled 19, done 334, failed 134);
  - `foreign_key_check` is empty.
  The reviewer repeated this on their own copy, and also checked that both fleet DBs are still at v29, so editing the
  unreleased m0030 was safe.

### Review

`specs/phase-54-schedules-and-fixes/reviews/54-04-review.md`.
- **Round 1, NEEDS_CHANGES:**
  - B1: gate and paused time was lost on a restart;
  - m1: a Run now row could be closed as "interrupted" by a tick running in parallel;
  - m2: no Kiro readiness skip for agent workflows;
  - nits n1–n3.
- **Re-run 1, NEEDS_CHANGES:** M1, a failed close stayed open because of the m1 fix (an L-107 regression); nits n4
  and n5.
- **Re-run 2, SHIP.** Minor m3 (a past `once` turned on stays active) was fixed after SHIP in `9a365c0`, with a test.
- **Not taken:**
  - n1: a third copy of the `_installed` / `_kiro_ready` helpers.
  - n4: a window of a few bytecodes between the open row's commit and `_mine.add`; accepted.

### Decisions / deviations

No ADR deviation. ADR-047 is amended by the ADR-087 draft as planned.
- **Decided by the user in this session:**
  - Q1 = B: red regression tests are recorded `failed` with a notice, but not counted toward auto-pause.
  - Q2 = A: gate and paused time does not count toward `timeout_min`; a hand-paused run is never auto-cancelled.
- **Defaults the user accepted** (each one checked by the reviewer):
  1. Covered up to now on create, a frequency change, turning on and resume.
  2. The migrated floor = the later of `since` and the newest regression execution; `enabled` from the old job;
     `since` dropped.
  3. `gate_opened_at` added, and after review B1 also `idle_since` and `idle_s`. This adds 3 columns to §1.2.
  4. `runs_count` counts `ok`, `failed` and `cancelled`, including Run now; a human cancel is not a failure; `partial`
     maps to `failed`.
  5. At most 200 missed rows per gap.
  6. `ExecutionNotReady` is a skip; `ExecutionError` is `failed`.
  7. The regression time limit counts from the fire.
  8. The old run-now answers 409 while the schedule is off or without the owner lock.
  9. A scheduled TE's run gets `trigger_json` too.
  10. The app-sync time limit is automatic.
- **Mine:**
  - The pure model lives in `schedule_model.py` (an import cycle with the store). `scheduler.py` re-exports it, so §2's
    "`runtime/scheduler.py`" names still resolve.
  - `due_slot` is removed.
  - `ScheduleStore.get` now takes an id; `get_by_key(job_key)` is the old lookup (L-094, every caller updated).
  - Old store methods removed: `list_jobs`, `mark_fired`, `set_enabled`, `update_schedule`, `update_option_entry`.
  - The old testing-schedule view maps a schedule its form cannot show to the nearest daily or weekly form.
  - A recovered stale row reads "interrupted before its result was recorded" and does not count toward failures.
  - The engine sees a resume or a gate answer at its next tick, so up to 60 s of running time can count as idle.

### Found, not fixed (for follow-up)

- **Docs hand-off (genesis-docs):**
  - `docs/architecture/modules/scheduler-and-jobs.md` still names `regression_job.py`, the dispatcher and the old job
    keys.
  - `api.md:539`, `data-and-migrations.md` (no m0030; the `scheduled_jobs` columns; the `:296` mention) and
    `knowledge-base.md:532/573/762` need the same update.
  - `context/state/current.md` should say DB **v30** at the release.
- Pre-existing, unchanged: `memory_jobs._kiro_ready` and `_installed`, and `start_sync` inside the serial app sync, run
  on the event loop (they were blocking reads there before 54-04).
- The fall-back hour: `slot_key` drops `fold`, so a schedule edited inside the repeated hour could re-fire a slot from
  that hour's first pass. Reasoned by the reviewer; it can happen one hour a year.

### For 54-05 / 54-06

- **Wiring** (`api/app.py`): `app.state.scheduler`, `app.state.schedule_store`, `app.state.notifications`.
  `register_target_handlers(scheduler, run_manager=, executions=, kb_store=, agent_prompt_inputs=None,
  kiro_ready=None)`.
- **For 54-05:** pass `agent_prompt_inputs=fn(target: dict) -> dict`, the `agent-prompt` inputs with the custom-agent
  snapshot taken now.
  - Raise `LookupError` or `ValueError` (agent gone, a server no longer pickable, D3) and the row becomes `failed` with
    that message.
  - The handler already checks that `agent-prompt` is installed and that Kiro is signed in, then starts it with the
    trigger.
  - The workflow handler reads `meta.get("schedulable") is True`; 54-05 adds the key to the loader, the parity lint
    and the library.
  - `custom_agents` exists with the F3 columns: `name` is UNIQUE, `skills_json` and `mcp_servers_json` default
    `'[]'`, and `model` is nullable.
  - A one-off Run leaves `trigger` None.
- **`ScheduleStore`** (all blocking; call it off the loop):
  - Reads: `list(kind=None)`, `get(id)`, `get_by_key(job_key)`, `regression_for(app_uuid)`.
  - `create_user(name, target, schedule, policy=None, *, enabled=True, now=None)`.
  - `update(id, *, name, target, schedule, enabled, options, policy, now)`: a system row accepts only schedule,
    enabled, options and policy, and the edit sets `user_modified`.
  - `delete_user(id)`, `duplicate(id)` (off, "<name> (copy)"), `reset_system(job_key)`.
  - `set_pause(id, "user" | None)`: None resumes and clears the failure count.
  - `history(id, limit, offset) -> (rows, total)`.
  - `open_fire_for(id)`: the in-flight row, or None.
  - Errors map to HTTP as `ScheduleError` 400, `ScheduleNotFound` 404, `ScheduleForbidden` 403 and
    `ScheduleConflict` 409. The 409 messages are "schedule is off", "a run of this schedule is still active", "another
    Genesis process on this machine runs the schedules" and "this schedule has nothing to run in this build".
- **`ScheduledJob`**: `id`, `job_key`, `kind`, `name`, `enabled`, `state` (`active` | `paused` | `failing` |
  `completed`), `pause_reason`, `target`, `schedule`, `policy` (effective), `options`, `failure_count`, `runs_count`,
  `last_fired_slot`, `last_run_*`, `user_modified`, `created_at`, `updated_at`.
- **History rows**: `{id, schedule_id, slot ("YYYY-MM-DDTHH:MM" | "manual:<utc>Z"), outcome, run_id, execution_key,
  reason, started_at, finished_at, gate_opened_at, idle_since, idle_s}`.
- **Run now, preview and gate time:**
  - Run now is `await scheduler.run_now(id) -> row_id`; the run id is set on the row once the handler starts it.
  - The preview is `next_runs(schedule, now, 5)` (aware datetimes in the schedule's zone).
  - `gate_cancel_at` is `Scheduler._gate_cancel_at(job, gate_opened_at)`. Make it public in 54-06 if a route needs it.
- **Notifications:**
  - `NotificationStore(db).add/list/unread_count/mark_read(id) -> bool/mark_all_read() -> int`.
  - Source `schedules`.
  - Kinds `needs_you`, `failed`, `auto_paused`, `missed`.
  - Links `/runs/<id>` or `/schedules/<id>`.
  - `ref` is `schedule:<id>`.
- **Runs:** `RunRecord.trigger` is `{source: "schedule", schedule_id, slot}` or None. 54-06 adds it to
  `api/_shared.py`'s run dict; it is not exposed yet.
- **54-06 removals, the consumers known today:**
  - `api/schedules.py`: all 3 routes and `_next_due`.
  - `api/testing.py:101-104`: the setup's `schedule` key.
  - `testexec/regression_service.py`: `schedule_view`, `save_schedule`, `_cadence_of`, `get/set_schedule`,
    `SCHEDULE_NOTE`, `CADENCES`.
  - `PUT …/testing/schedule`.
  - The web callers.
  - Review nit n5: the PUT may resend an unchanged `schedule`. The store accepts an unchanged past `once`, but refuses
    to turn one on.

### Lesson candidates

1. **State a level-triggered loop decides from must live on the durable row.** B1: the idle time was kept in an
   in-memory dict beside the `schedule_runs` row, and a restart turned a resumed run into "timed out". If a restart
   must not change a decision, everything the decision reads is stored.
2. **A guard that protects a row "just opened" must be lifted on every exit path of its owner.** M1: the guard set
   added for m1 was cleared only by a successful close, so a failed write wedged the recovery that L-107 relies on. A
   corollary of L-107: a protection added to stop one race needs the same `finally` as the work it protects.
3. **Give a scheduler one clock and let it stamp everything it later compares** (the D27 flake). The old test mixed a
   fake 03:00 clock with executions' real `created_at`. The new engine writes `started_at`, `finished_at`,
   `gate_opened_at` and `idle_since` with its own clock and never reads a run's timestamps.
4. **When you migrate a dispatcher's per-item cadence into first-class rows, carry its "already covered" floor**
   (`since` together with the newest execution) into the new row's watermark. A related rule: a new or turned-on
   schedule marks "covered up to now", so nothing from the past fires (L-080).

### Code-map changes (for genesis-docs, bible/03)

- `genesis/db/migrations/m0030_schedules.py` (new): the schema above and the one-time data step. `current_version` is 30.
- `genesis/runtime/schedule_model.py` (new): `validate_schedule`, `validate_policy`, `default_policy`,
  `POLICY_DEFAULTS`, `SYSTEM_POLICY`, `slots_between`, `next_runs`, `due`, `schedule_times`, `slot_key`,
  `slot_instant`, `parse_instant`, `machine_timezone`.
- `genesis/runtime/scheduler.py` (rewritten): `Scheduler` (`register(…, timeout_min=)`, `register_target`, `tick`,
  `run_now`, `is_running`), `Fire`, `Started`, `MAX_MISSED_ROWS`.
- `genesis/runtime/schedule_store.py` (rewritten): `ScheduleStore`, `ScheduledJob`, `validate_target`, the four error
  classes and `RETIRED_JOB_KEYS`.
- `genesis/runtime/schedule_targets.py` (new): `register_target_handlers`, `file_inputs`, `has_agent_node`.
- `genesis/runtime/notifications.py` (new): `NotificationStore`.
- `genesis/runtime/sync_jobs.py`: `app_sync_timeout_min`. The handlers take a `Fire`, `document-library-sync` returns
  `Started`, and `regression-run` is gone from `DEFAULT_JOBS`. `genesis/runtime/memory_jobs.py`: returns `Started`.
- `genesis/runs/manager.py` `start(trigger=)`; `genesis/runs/store.py` `RunRecord.trigger` and `trigger_json`;
  `genesis/services/application_sync.py` `start_sync(trigger=)`; `genesis/testexec/execution_service.py`
  `_schedule_trigger`.
- `genesis/testexec/regression_service.py`: the schedule view and save now work over the app's regression row.
  `genesis/testexec/regression_job.py` is **deleted**.
- `genesis/api/app.py`: the scheduler gets `run_manager`, `executions`, `notifications` and `owner_lock`, and
  `app.state.notifications` is added. `genesis/api/schedules.py` runs on the new store.

## Context manifest

```toml
areas    = ["runs-worker", "db", "config-secrets", "browser-testing"]
adrs     = ["ADR-009", "ADR-012", "ADR-021", "ADR-030", "ADR-047", "ADR-063", "ADR-074"]
lessons  = ["L-026", "L-050", "L-081", "L-083", "L-091", "L-093", "L-094", "L-097", "L-102", "L-103", "L-107", "L-108"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md", "tracker:specs/phase-45-incremental-delta-sync.md"]
code     = ["genesis/genesis/runtime/scheduler.py", "genesis/genesis/runtime/schedule_store.py", "genesis/genesis/runtime/sync_jobs.py", "genesis/genesis/runtime/memory_jobs.py", "genesis/genesis/testexec/regression_job.py", "genesis/genesis/db/migrations/**", "genesis/genesis/runs/manager.py", "genesis/genesis/runs/store.py", "genesis/genesis/api/app.py"]
upstream = ["54-02"]
```
