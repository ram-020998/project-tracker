# Review 54-04 — base b09b08e, head 41d4d0e (genesis-review, 2026-11-18)

What this change does: m0030 (DB v29 → v30) adds the schedule columns, `schedule_runs`, `runs.trigger_json`,
`notifications` and `custom_agents`, marks every existing row `system` with a default policy, turns each on
`regression-run` entry into its own user row and deletes the dispatcher. A pure schedule model
(`runtime/schedule_model.py`: monthly, once, `days`, DST-safe slots, `due` with grace) replaces the same-day rule. The
rewritten `Scheduler` follows every open `schedule_runs` row to its terminal state (gate wait, run time limit, failure
count and auto-pause, end date and max runs, Run now) and fires user rows through per-target handlers
(`schedule_targets.py`). `NotificationStore` backs the bell.

Inputs: the spec 54-04, 54-01 §8 D1–D29 and §9 F1–F12, ADR-087 draft, and this session's decisions Q1 = B and Q2 = A
plus the ten defaults the user accepted. Commit `41d4d0e` resolved; the tree is clean at HEAD.

## Checklist

### ADRs
- [N/A] ADR-001 — the scheduler starts runs, LangGraph owns their control flow; no agent orchestrates.
- [N/A] ADR-008 — no UI change.
- [OK] ADR-009 — the gate rule cancels only through `RunManager.cancel` after the wait (`scheduler.py` `_follow`/`_stop`); a person can still answer or fork before then (`test_gate_wait_cancels_at_the_max_wait_and_an_answered_gate_continues`).
- [OK] ADR-010 — `trigger_json` is a 3-key pointer `{source, schedule_id, slot}` (`manager.py:291-326`); nothing bulk in state.
- [N/A] ADR-011 — no agent node added.
- [OK] ADR-012 — the app process reads `workflow.yaml` only (`loader.meta_of`, `dist/loader.py:57-59`, used by `schedule_targets.workflow`); no workflow Python imported.
- [N/A] ADR-018, ADR-019, ADR-022, ADR-023 — untouched.
- [OK] ADR-021 — a scheduled run's gate is never auto-approved; it waits, then is cancelled (D8). No new mutating node.
- [OK] ADR-024 — engine stays async; blocking DB work in `asyncio.to_thread` (`tick`, `run_now`, `Fire.note_run`, handlers).
- [N/A] ADR-025 — fork untouched.
- [N/A] ADR-026 — no bind change; no auth added.
- [OK] ADR-028 — the only route touched stays `/api/system/sync-settings/run-now` (`api/schedules.py:155`).
- [N/A] ADR-029 — no trust change; agent-prompt handler is a skip stub until 54-05.
- [OK] ADR-030 — SQLite only; store signatures are plain Python types.
- [N/A] ADR-031, ADR-033, ADR-034 — chat untouched.
- [N/A] ADR-032 — no credit figures in this sub-spec (F9 is 54-06/07).
- [OK] ADR-035 — a workflow with a `format: "file"` input is skipped, never fed a stored file (`schedule_targets.py:33-38, 78-80`; see n2).
- [N/A] ADR-036, ADR-037, ADR-038, ADR-039, ADR-041, ADR-042, ADR-043, ADR-045, ADR-046, ADR-049, ADR-050 — untouched.
- [OK] ADR-047 (amended by the ADR-087 draft) — system rows stay backend-defined and seeded by `ensure_defaults`; their schedule, on/off, options and policy are user-editable and `user_modified` is respected (`schedule_store.py` `ensure_defaults`/`update`; `test_ensure_defaults_adopts_the_new_default_once_then_respects_user_edits`). The app sync stays one serial task.
- [N/A] ADR-053, ADR-054 — memory jobs only change how their run is followed; `memory.db` untouched.
- [N/A] ADR-060, ADR-061, ADR-062, ADR-064, ADR-065, ADR-066, ADR-068, ADR-069, ADR-070, ADR-071, ADR-072, ADR-073, ADR-075, ADR-076, ADR-078, ADR-079, ADR-084, ADR-085, ADR-086 — untouched.
- [OK] ADR-063 / F11 — user schedules are local rows; nothing is published to the Hub; the designated-machine rule stays app-sync only (`sync_jobs.app_sync_skip_reason`).
- [OK] ADR-074 — app sync still starts `sync-application` with mode auto and the stored thresholds (`sync_jobs.py` `application_sync`).
- [N/A] ADR-077 — agent-system untouched.
- [OK] ADR-080 — one repo, no new dependency (stdlib `zoneinfo`, `calendar`).
- [OK] ADR-081, ADR-082, ADR-083 — a scheduled regression still goes through `TestExecutionService.start_regression` (program-only, QA, committed code); only the trigger gains `schedule_id`.

### Lessons
- [N/A] L-003, L-018, L-118 — SSE untouched.
- [OK] L-004 — schedule history and notices in `genesis.db`.
- [OK] L-005 — no new event kinds; cancel emits the one `run.final{cancelled}` (`test_an_unanswered_real_gate_is_cancelled_through_the_cancel_path`).
- [OK] L-008 — no change to error/worker_exit handling.
- [N/A] L-009, L-020, L-021, L-023, L-031, L-032, L-034, L-035, L-037, L-040, L-044, L-045, L-048, L-068, L-077, L-078, L-079, L-082, L-087, L-088, L-090, L-095, L-099, L-100, L-101, L-104, L-105, L-106, L-113, L-115, L-116, L-117, L-119 — areas not touched by this diff.
- [OK] L-010 — no new route outside `/api`.
- [N/A] L-016 — no credit figures.
- [N/A] L-017, L-019 — no trust or secret writes.
- [OK] L-025, L-027 — `ruff check genesis` clean with the pinned ruff.
- [OK] L-026 — the tick's evaluation (`_evaluate`), Run now, notices and every handler's blocking start run in `asyncio.to_thread`; `sync_jobs._wait_terminal` now polls off the loop. (Pre-existing on-loop reads in `memory_jobs._kiro_ready/_installed` and `application_sync`'s `start_sync` are unchanged.)
- [N/A] L-030 — no web change.
- [OK] L-033 — a missing workflow is a `skipped` row, never an exception (`test_readiness_skips_are_recorded_and_never_counted`).
- [OK] L-039 — `schedule_view` keeps the 51-08 shape for GET and PUT.
- [OK] L-050 — app sync stays serial with its per-app wait.
- [N/A] L-051, L-056, L-057, L-098, L-111, L-112 — release concerns (54-11).
- [OK] L-058 — the engine is level-triggered: every tick re-reads open rows from the DB (`_evaluate` → `open_fires`).
- [N/A] L-059, L-060, L-066 — run-graph rendering untouched.
- [OK] L-061, L-062 — each open row follows only its own `run_id`/`execution_key`.
- [OK] L-065 — not affected; a gate-cancel goes through `cancel`'s terminal write.
- [OK] L-080 — "covered up to now" is written at create/edit/resume, before any fire (`schedule_store.py` `create_user`/`update`/`set_pause`).
- [OK] L-081 — `ensure_defaults` keeps `user_modified` rows and never re-creates `regression-run` (`RETIRED_JOB_KEYS`; `test_ensure_defaults_never_recreates_the_retired_regression_dispatcher`, `test_after_m0030_a_boot_keeps_the_users_app_sync_and_never_brings_the_dispatcher_back`); m0030 copies regression entries once.
- [OK] L-083 — the migration test uses a copy of the real `scheduled_jobs` rows (`test_schedule_migration.py:20-50`), including the app-sync row with `user_modified=1`.
- [OK] L-089 — gates run one per message here.
- [OK] L-091 — every validate-then-write takes `BEGIN IMMEDIATE` first: `_locked`, `reset_system`, `open_fire`, `close_fire`, `NotificationStore.add` (`test_open_fire_is_one_at_a_time`, `test_two_producers_at_once_add_one_notice`). `ensure_defaults` keeps its old unlocked pattern (not new).
- [OK] L-092 — no `tests/__init__.py`; `TestExecutionService.__test__ = False` kept.
- [OK] L-093 — terminal state is stored (`close_fire`) before the notice; `trigger_json` and cancel proven through the real `RunManager` (`test_schedule_engine_real.py`).
- [OK] L-094 — consumers of `regression_job`, `REGRESSION_JOB`, `ScheduleStore.get(job_key)`, `list_jobs`, `update_option_entry`, `Scheduler.run_now`: grepped `genesis/`, `tests/`, `scripts/`, `web/src`, `genesis-fleet`, `genesis-workflows`; all updated (the web's `regression-run.json` fixture is a run object, unrelated). docs/architecture mentions are a docs hand-off.
- [OK] L-096 — no route added.
- [OK] L-097 — the tick and Run now act only while `holds_run_owner_lock()` is true (`scheduler.py` `tick`, `run_now`; `test_the_tick_does_nothing_without_the_run_owner_lock`).
- [OK] L-102 — no table rebuild; additive `ALTER TABLE ... ADD COLUMN` only; `foreign_key_check` empty on a copy of the real DB (below).
- [OK] L-103 — `delete_user` deletes `schedule_runs` in the same transaction (`test_delete_user_removes_its_slot_history_in_the_same_transaction`).
- [OK] L-107 — every handler path reaches a terminal row: `_fire`'s `finally` with a shielded close (`test_a_handler_error_or_result_always_reaches_a_terminal_row`); an opened-but-never-started row is closed by the next tick after a restart. Related race, not a lesson regression: m1.
- [OK] L-108 — timeout and gate cancels go through `RunManager.cancel` / `TestExecutionService.cancel` (stop intent, CAS); a restart does not cancel twice (`test_a_run_past_its_time_limit_is_cancelled_once_and_a_restart_does_not_double_fire`).
- [OK] L-109 — one schedule model; the old view (`schedule_view`) reads the new row instead of a second store.
- [OK] L-110 — counts below are from runs at `41d4d0e`.

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` — **1997 passed in 645.49 s** (19:08–19:19 IST, outside the D27 window), matching the author's figure.
- [OK] `cd genesis && .venv/bin/ruff check genesis` — "All checks passed!".
- [OK] Targeted: `tests/test_scheduler.py test_schedule_engine_real.py test_schedule_migration.py test_notifications.py test_sync_jobs.py test_memory_jobs.py test_testexec_regression.py test_db.py` — 128 passed.
- [N/A] playwright-appian, genesis web (lint/typecheck/vitest/build), genesis-workflows gates — no file in those repos or under `web/` changed.
- [OK] m0030 on a fresh copy of the real `~/.genesis/genesis.db` (read with `mode=ro` + the sqlite backup API into `/tmp/probe_54_04/dbcopy/`; the original untouched): v29 → v30; five system rows kept with their `enabled`, `user_modified` and `last_fired_slot` (app sync `user_modified=1`, `run_on_this_machine: true`); `application-sync` policy `timeout_min: null`, the others 120; `regression-run` deleted (its one entry was `off`, so no user row); `runs` status counts unchanged (cancelled 19, done 334, failed 134); `foreign_key_check` empty; `integrity_check` ok.

### The accepted defaults and session decisions, checked against the code
- Q1 = B — OK: `_EXECUTION_OUTCOME` maps `failed`/`blocked` to `("failed", False)`; `close_fire(counts=False)` leaves `failure_count`; `_close` still raises the "failed" notice (`test_regression_failed_tests_are_recorded_failed_but_not_counted`).
- Q2 = A — **VIOLATION across a restart** (B1). Within one process: OK (`test_timeout_cancels_through_the_cancel_path_but_never_a_run_paused_by_hand`); a paused run returns before the timeout check and is never auto-cancelled.
- 1 OK (`create_user`, `update`, `set_pause`, `reset_system` write `slot_key(now)`). 2 OK (m0030 `_migrate_regression_entries`: floor = max(since, newest regression `created_at`), in the job's zone; `enabled` copied; `since` dropped). 3 OK (`gate_opened_at` column, `set_gate`). 4 OK (`close_fire` counts ok/failed/cancelled incl. `manual:` rows; `cancelled` does not touch `failure_count`; `partial` → failed via `_STATUS_OUTCOME`). 5 OK (`MAX_MISSED_ROWS = 200`, one `missed` notice, deduped by ref + kind). 6 OK (`ExecutionNotReady` → skipped, `ExecutionError` → failed). 7 OK (the row's `started_at` is the fire time; a queued TE has no run, so no idle credit). 8 OK (`api/schedules.py:155-170`; `Scheduler.run_now` refuses off and no-lock). 9 OK (`_schedule_trigger` in `execution_service.py`; asserted in `test_regression_schedule_starts_the_due_app_follows_it_and_skips_busy_ones`). 10 OK (`app_sync_timeout_min` = 20 × max(1, apps); memory and document sync use 120).

## Findings

### Blockers
- B1 **Gate and paused time is forgotten across a restart, so a resumed run is cancelled "timed out" at once**
  (`genesis/runtime/scheduler.py:110-111, 336-341, 360`). What: the time a run spends at a gate or paused by hand is
  kept only in the engine's memory (`_credit`, `_idle_since`); the timeout check is `now - started_at - credit`.
  Problem: Q2 = A says that time never counts, and §3.2 says in-flight state must come from stored state so a restart
  changes nothing. Case (probe `/tmp/probe_54_04/test_probe_restart_idle.py`, both tests fail at `41d4d0e`): a user
  schedule with `timeout_min: 30` fires at 09:00; at 09:10 the run is paused by hand; Genesis restarts at 12:10; the
  person resumes at 14:10. The next tick computes 5 h 1 min − 2 h of credit seen since the restart ≥ 30 min, cancels
  the run and records `failed` "timed out" (counted toward auto-pause): `[('2026-08-17T09:00', 'failed', 'timed out')]`.
  The gate case is the same: a gate open across a restart and answered within the D8 wait is cancelled "timed out" on
  the first running tick after the answer. Pause surviving a restart is a shipped feature, and a gate may wait 24 h,
  so a restart in that time is ordinary. Fix: store the credit on the row. Smallest form: add `idle_s INTEGER NOT NULL
  DEFAULT 0` and `idle_since TEXT` to `schedule_runs` in m0030 (not yet released, so editing it is safe), write
  `idle_since` when the engine first sees the run idle and add the elapsed seconds to `idle_s` when it leaves idle
  (the gate branch can reuse `gate_opened_at` for the gate part), and drop the two dicts. Add the probe's two cases
  as tests (a fresh `Scheduler` over the same store = the restart). If skipped: users who pause a scheduled run or
  leave a gate open over a laptop restart lose the run when they continue it, and three such runs auto-pause the
  schedule.

### Majors
None.

### Minors
- m1 **A Run now row can be closed "interrupted" by a concurrent tick** (`scheduler.py:189-209, 325-330`). What:
  `run_now` opens the row in a worker thread, then calls `_launch` (which registers `_live[row_id]`) back on the loop;
  the tick's `_evaluate` runs in another thread at the same time and closes any open row that has no `run_id` and no
  `_live` entry as `failed` "interrupted before it started (Genesis stopped)". Case: Run now committed between the
  tick thread's `open_fires()` read and its `_follow` of that row, with `_launch` not yet run → the row closes
  failed; the handler still starts the run, `note_run` writes its id onto the closed row, and nothing follows it (no
  overlap protection, no timeout, no gate rule, the result is never recorded). The window is milliseconds, so this is
  rare. Fix: in `_follow`'s no-run branch close only rows opened before this engine started (keep `self._started_at`
  from `start()`/first tick and compare with the row's `started_at`), since a row this process opened is never
  "interrupted by a stop". If skipped: a rare untracked Run now run.
- m2 **A workflow target does not skip when Kiro is signed out** (`schedule_targets.py:67-81`). What: the workflow
  handler checks installed, `schedulable` and file inputs; the agent-prompt and memory handlers also check
  `_kiro_ready`. Problem: §3.3/D12.3 list "Kiro not signed in" as a readiness skip that is not a failure. Case: a
  schedule of `hello-appian` (agent nodes, a D7 candidate) while Kiro is signed out runs, fails at its first agent
  node, counts a failure, and after three days is paused `failing`, instead of three `skipped` rows. A program-only
  workflow (e.g. `sync-documents`) must not be skipped for this, so the check needs to know whether the workflow has
  agent nodes. Fix: either skip when `not _kiro_ready()` and the installed META declares any agent step (the
  `steps`/`graph` the reliability lint already reads), or record this as a 54-05/54-06 follow-up in As built. If
  skipped: signed-out machines auto-pause agent workflow schedules.

### Nits
- n1 **Third copy of `_installed` / `_kiro_ready`** (`schedule_targets.py:44-56`, `memory_jobs.py:50-60`,
  `sync_jobs.py:126`). The new module adds a third near-identical pair. Optional: one shared helper in
  `runtime/` used by all three.
- n2 **Any file input, even optional, blocks the whole workflow** (`schedule_targets.py:33-38, 78-80`). §4 says a
  schedule's stored inputs may not hold a file; the handler refuses every workflow that declares a `format: "file"`
  property, even an optional one with `default: null`. No schedulable workflow has one today, so there is no effect
  now; if one appears, check only the stored inputs (or required file inputs) instead.
- n3 **A `once` created in the past never completes** (`schedule_store.py` `create_user`). Creation writes "covered
  up to now", so an `at` earlier than now is neither fired nor recorded `missed`, and the row stays `active` with no
  next run. 54-06's create validation could refuse a past `at`.

## Not checked
- Live behaviour on a real `genesis serve` (a real gate, a real pause across a restart, the bell): out of scope here,
  54-10 does it.
- Fall-back-hour edge of "covered up to now": `slot_key` drops `fold`, so a schedule edited during the repeated hour
  could re-fire a slot from the first pass of that hour. Reasoned from the code, not probed; one hour a year.
- Whether 54-05's `agent_prompt_inputs` will satisfy the handler's contract (it is not wired yet).

## Verdict: NEEDS_CHANGES

Fix B1 (store the idle credit on the `schedule_runs` row, with the two restart tests). m1 and m2 should be fixed or
recorded in As built; the nits are optional. Everything else checks out: gates green (1997 passed, ruff clean), the
migration is correct on a copy of the real DB, and Q1 and defaults 1–10 match the code.

---

# Re-run 1 — delta 41d4d0e..e45a042 (genesis-review, 2026-11-18)

**Revision note:** the hand-off named the fix commit `96931a6`. That object does not exist in the repo
(`git cat-file -t 96931a6` → "Not a valid object name"). HEAD of `master` is `e45a042` ("fix(54-04): review round 1 -
B1 idle time stored on the row, m1, m2, n2, n3", 19:35 IST), the only commit after `41d4d0e`, and its content matches
the hand-off. The tree is clean. This re-run reviews `e45a042`; the As built should cite that sha.

Delta: 6 files, +171/−31 (`m0030_schedules.py`, `schedule_store.py`, `schedule_targets.py`, `scheduler.py`,
`test_schedule_migration.py`, `test_scheduler.py`). `genesis-ctx check --since 41d4d0e` lists areas db, runs-worker,
release-ci, security; the checklist lines are the same set as round 1.

## Round-1 findings

- **B1 — fixed.** `schedule_runs` gains `idle_since TEXT` and `idle_s INTEGER NOT NULL DEFAULT 0` (m0030 `_up`).
  `_follow` writes `idle_since` the first tick the run is at a gate or paused and adds the elapsed seconds to `idle_s`
  when it leaves (`scheduler.py:342-349`, `ScheduleStore.set_idle`). The limit check is now
  `now - started - idle_s` (`scheduler.py:367-370`). The `_credit` and `_idle_since` dicts are gone. My round-1
  probes (`/tmp/probe_54_04/test_probe_restart_idle.py`, both failed at `41d4d0e`) pass at `e45a042`. The new tests
  `test_review_b1_paused_time_across_a_restart_is_not_counted` and `..._gate_time_...` use a second `Scheduler` over
  the same store as the restart; the paused test also proves the limit still fires after 29 + 1 min of running
  time. A gate's open interval is never needed for the limit, because the gate branch returns before the check. The
  "up to one tick of running time counts as idle" trade-off is bounded by `TICK_SECONDS = 60` and is acceptable.
- **m1 — fixed, but the fix breaks a recovery path. See M1 below.** `_open` adds the row id to `_mine` in the thread
  that opened it, and `_follow` skips "interrupted" for ids in `_mine`
  (`test_review_m1_a_tick_in_parallel_never_closes_a_row_this_process_just_opened`). A window of a few bytecodes
  remains between `open_fire`'s commit and `_mine.add`. That is far smaller than the round-1 window, so I accept it
  (n4).
- **m2 — fixed.** `has_agent_node(meta)` reads the `graph:` topology from `workflow.yaml` through `loader.meta_of`, so
  no workflow Python is imported (ADR-012). `_kiro_ready` runs in `to_thread` (L-026). Library check: every
  `genesis-workflows` workflow whose `graph.py` uses `kiro_node` declares `graph:` with at least one `kind: agent`
  node, and the three program-only ones (`sync-application`, `sync-documents`, `test-execution`) declare none. Only
  `_template` has no `graph:`, and it is never installed. A workflow with no topology runs, as documented. Test:
  `test_review_m2_an_agent_workflow_skips_while_kiro_is_signed_out_a_program_one_runs`.
- **n1 — not taken.** To be recorded in As built, as agreed.
- **n2 — fixed.** `file_inputs(meta, stored)` counts required file fields plus file fields the stored inputs set. The
  same m2 test covers an optional file input (fires) and a stored one (skipped).
- **n3 — fixed.** `_future_once` is used by `create_user` and `update` (`test_review_n3_...`). A side effect for
  54-06 is noted as n5.

## New findings

### Majors
- M1 **When a handler's close fails, its row stays open until a restart, and the schedule is blocked**
  (`scheduler.py:209-215, 333, 441-444`). What happens: `_fire`'s `finally` catches a failed `_close` and logs "the
  next tick's follow closes a stale row" (`scheduler.py:258`). Since this commit, that never happens. `_close` raises
  inside `close_fire` before it reaches `self._mine.discard(row_id)`, so the row stays in `_mine`, and `_follow`'s
  no-run branch now skips every row in `_mine`. Case (probe `/tmp/probe_54_04/test_probe_close_fail.py`): a schedule
  whose handler returns `skipped`, and `close_fire` raises once (`database is locked`). At `41d4d0e` the next tick
  closes the row `failed` "interrupted before it started" (control copy of the probe, run against
  `git archive 41d4d0e`: passed). At `e45a042` the row is still `fired` after the next tick (`mine: {1}`,
  `[('2026-08-17T09:00', 'fired', None)]`: failed). From then on, every slot is recorded `skipped` "previous run
  still active" and Run now answers "a run of this schedule is still active", until Genesis restarts. This regresses
  L-107: every error path must reach a terminal state, and a check added before a protected call needs the same
  protection. Fix: in `_fire`'s inner `finally`, add `self._mine.discard(fire.row_id)` next to
  `self._live.pop(fire.row_id, None)`. Once the handler is done, the row is no longer "just opened", and a row that
  started a run is followed by its `run_id` anyway. The m1 test still holds, because it never reaches `_fire`. Add
  the probe as a regression test.

### Nits
- n4 **A small m1 window remains.** A tick thread can read the newly committed row from `open_fires()` and test
  `_mine` before `_open` adds the id. This needs a thread switch inside about two bytecodes. Closing it fully means
  adding the id inside `open_fire`'s transaction, for example with a callback. Optional.
- n5 **`update(schedule=…)` refuses an unchanged past `once`.** `_future_once` runs whenever `schedule` is passed, so
  renaming a once schedule whose `at` has passed is refused if the client resends the whole schedule. 54-06's PUT
  should send `schedule` only when it changed, or `update` should skip the check when the new schedule equals
  `job.schedule`.

## Gates (re-run at e45a042)
- [OK] `.venv/bin/python -m pytest -q -p no:warnings` — **2002 passed in 637.40 s** (19:38–19:49 IST), matching the
  author's figure (1997 + 5 new tests).
- [OK] `.venv/bin/ruff check genesis` — "All checks passed!".
- [OK] Targeted schedule, migration, notification, sync, memory, regression and db tests — 133 passed.
- [OK] Edited m0030 on a fresh copy of the real `~/.genesis/genesis.db` (opened `mode=ro`, sqlite backup API, then
  `/tmp/probe_54_04/dbcopy/rerun1.db`; the original was not modified): v29 → v30. `schedule_runs` has `idle_since`
  (nullable) and `idle_s` (NOT NULL, default 0). Five system rows; `application-sync` keeps `user_modified=1`.
  `foreign_key_check` is empty and `integrity_check` is ok.
- [OK] Editing m0030 in place is safe. It has never been released, and both fleet databases are still at v29 (read
  `mode=ro`: `~/.genesis/genesis.db` and `~/.genesis-fleet/instances/userb/state/genesis.db`), so no database holds
  the old v30 schema.

## Checklist delta
The round-1 checklist answers hold. Lines this delta touches:
- [OK] ADR-012 — the m2 check reads META from `workflow.yaml` and imports no workflow Python.
- [OK] ADR-035 — file inputs are still never stored; only a required file input, or a stored value for one, blocks
  the schedule.
- [OK] ADR-009, Q2 = A — gate and pause time is excluded from the run time limit, and the exclusion survives a
  restart (B1 tests). A paused run is still never auto-cancelled.
- [OK] L-026 — `_kiro_ready` and `set_idle` run off the loop (`to_thread`, or inside `_evaluate`'s thread).
- [OK] L-091 — `set_idle` is a single `UPDATE` (`idle_s = idle_s + ?`) with no read-then-write.
- [OK] L-102 — still no table rebuild; the two columns are part of the `CREATE TABLE`.
- **[VIOLATION] L-107** — M1.
- [OK] L-110 — the counts above are from runs at `e45a042`.

## Not checked
- I did not re-run the author's mutation probes (removing `_mine`, forcing idle to 0, removing the Kiro check). The
  B1 tests are covered by my round-1 probes, which failed at `41d4d0e` and pass now. The m1 test cannot run at
  `41d4d0e` because it calls `_open`.
- Live behaviour on a real `genesis serve`: still 54-10.

## Verdict (Re-run 1): NEEDS_CHANGES

B1, m2, n2 and n3 are fixed, with tests. The gates are green (2002 passed, ruff clean), and the edited m0030 is
correct on a copy of the real database. One change is needed before SHIP: M1. Discard the row from `_mine` in
`_fire`'s `finally`, and add `/tmp/probe_54_04/test_probe_close_fail.py` as a regression test. n4 and n5 are
optional; n5 can go to 54-06.

# Re-run 2 — delta e45a042..f03066d (genesis-review, 2026-11-18)

`git log --oneline -4`: `f03066d` (fix: re-run 1 M1, n5) → `e45a042` (round-1 fix) → `41d4d0e` → base `b09b08e`. The
tree is clean. Delta: 3 files, +45/−5 (`schedule_store.py`, `scheduler.py`, `test_scheduler.py`).
`genesis-ctx check --since e45a042` lists area runs-worker (plus always-on release-ci, security); the checklist is a
subset of round 1's.

## Re-run 1 findings

- **M1 — fixed.** `_fire`'s inner `finally` now calls `self._mine.discard(fire.row_id)` next to
  `self._live.pop(fire.row_id, None)` (`scheduler.py:264-265`). Once the handler is done, the row is no longer
  protected, so `_follow`'s no-run branch (`scheduler.py:336-338`) closes a row whose own close failed. Paths checked:
  - Handler returned `Started` and `note_run` stored the run id: the finally does not close the row, and the next tick
    follows it by `run_id` / `execution_key`, never by the no-run branch. Unchanged.
  - `note_run` raised: `started` stays False, so the row is closed in the finally, as before.
  - The round-1 m1 race (a tick in parallel with a freshly opened row): `_mine.add` still happens in `_open`, and the
    discard only runs after the handler ends, so `test_review_m1_...` still holds.
  - The new reason text "interrupted before its result was recorded" has no other user: no test, fixture or web
    string matched the old text (grep over `genesis/`, `tests/`, `web/src/`).
  Evidence: my re-run-1 probe `/tmp/probe_54_04/test_probe_close_fail.py` now passes (1 passed, run with
  `-o asyncio_mode=auto`). The author's regression test `test_review_rerun1_m1_a_failed_close_is_recovered_by_the_next_tick`
  is that probe. Mutation check, done independently on a `git archive f03066d` copy
  (`/tmp/probe_54_04/mut_rerun2`, imports resolved from that copy): with the discard line replaced by `pass`, the
  test fails (`1 failed, 2 passed`), so the test pins the fix.
  A recovered row is recorded `failed`, sends a "failed" notice, and has `counts=False`, so it never counts toward
  auto-pause. That is honest (the result really was not recorded) and acceptable.
- **n5 — fixed.** `update` validates the schedule, then calls `_future_once` only when the result differs from
  `job.schedule` (`schedule_store.py:342-344`). `validate_schedule` normalizes before the compare, so a resent equal
  schedule compares equal. `last_fired_slot` is still reset only on a real change. Test
  `test_review_rerun1_n5_an_unchanged_past_once_can_be_resent` covers both a resent unchanged past `once` (accepted)
  and a changed past `once` (refused).
- **n4, n1 — not taken**, to be recorded in As built as accepted risk. Agreed.

## New findings

### Minors
- m3 **A one-time schedule that was off when its time passed, and is turned on later, stays "active" forever without
  firing or completing** (`schedule_store.py:351-356`, `scheduler.py:309-316`). This was already true at `41d4d0e`,
  so this delta did not cause it (I missed it in round 1). n5 makes it slightly easier to reach, because a resent
  unchanged schedule plus `enabled=True` is now accepted. What happens: `update(enabled=True)` sets
  `last_fired_slot` to now, so `due()` returns neither a fire nor a missed slot, and `mark_completed` is only reached
  through a missed slot. Case (probe appended to a clean `git archive f03066d` copy,
  `/tmp/probe_54_04/clean_rerun2/tests/test_scheduler.py::test_probe_rerun2_a_past_once_turned_on_never_fires_nor_completes`):
  a `once` at 09:00 IST created off at 07:00, turned on at 10:00, then 3 ticks: `enabled=True`,
  `pause_reason=None`, `state='active'`, no history rows (failed). Smallest fix: in `update`, when the change turns a
  `once` on and its `at` is past, refuse it with the same "a one-time schedule must be in the future" error (or set
  `pause_reason='completed'`), and add the probe as a test. This does not block SHIP. It can land here or in 54-06,
  whose UI is where a person would turn a schedule on.

## Gates (re-run at f03066d)
- [OK] `.venv/bin/python -m pytest -q -p no:warnings` — **2004 passed in 655.58 s** (about 20:05–20:16 IST), matching the
  author's figure (2002 + 2 new tests). Log: `/tmp/probe_54_04/rerun2_full.log`.
- [OK] `.venv/bin/ruff check genesis` — "All checks passed!" (after the reworded comment).
- [OK] Targeted: `tests/test_scheduler.py -k "rerun1 or review_m1 or n3"` — 4 passed.
- No migration changed in this delta. The real `~/.genesis/genesis.db` was not opened.

## Checklist delta
The round-1 and re-run-1 answers hold. Lines this delta touches:
- [OK] L-107 — every error path of `_fire` now ends in a terminal row: the handler's own close, or the next tick's
  follow when that close fails (M1 test plus mutation check). This clears re-run 1's VIOLATION.
- [OK] L-026 — the recovery close runs inside `_evaluate`, which runs in `to_thread`.
- [OK] L-097 — the recovery runs only after `tick` takes `_owner_lock`, so a second process never closes this
  process's rows.
- [OK] L-081 — `update` still sets `user_modified` on a system row, and the n5 change does not touch it.
- [OK] L-091 — `update` still validates inside `self._db.tx()` after `_locked` takes the row.
- [OK] L-110 — all counts above come from runs at `f03066d`, and the mutation check ran on a copy of that commit.
- [N/A] Every other line from the check (ADRs 001–086, the remaining lessons): this delta touches only the scheduler's
  ownership set, a reason string, and one validation branch in `update`. Round-1 answers stand.

## Not checked
- Live behaviour on a real `genesis serve` (a real `database is locked` during a close): 54-10.
- I did not re-run the round-1 restart probes. Neither the idle code nor the migration changed in this delta.

## Verdict (Re-run 2): SHIP

M1 is fixed, with a regression test that fails when the fix is removed (checked independently). n5 is fixed with a
test. The gates are green: 2004 passed, ruff clean. m3 is a pre-existing minor (a past `once` turned on stays
"active" with nothing to fire). It does not block; fix it here or carry it to 54-06, and record the choice in As
built together with n1 and n4.
