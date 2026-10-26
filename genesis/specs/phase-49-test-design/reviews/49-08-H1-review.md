# Review 49-08 H1 — base 73b3bd3 (genesis-review, 2026-10-22)

Scope: **only** hardening item H1 of 49-08 (§1.1, decision 49-01 D17): store the stop status before announcing
`run.final`. Not covered here: 49-08 §1 items 1–13 and §3 live acceptance (later). No live acceptance is needed for H1:
it is a backend ordering fix with offline tests.

Repo `genesis`, base `73b3bd3` (= HEAD, verified). The change is **uncommitted** in the working tree. I reviewed
`git diff 73b3bd3`, 7 files: `genesis/runs/manager.py`, `genesis/services/testdesign_stage.py` (docstring only),
`tests/test_runs.py`, `tests/test_features_api.py`, `tests/test_test_design_stage.py`, `tests/test_story_design.py`,
`tests/test_story_implementation.py`.

## What I verified myself

- **Gates.** `.venv/bin/python -m pytest -q -p no:warnings` → **1353 passed** in 206 s. `.venv/bin/ruff check genesis`
  → `All checks passed!` (ruff 0.15.20, pinned).
- **The tests fail before the fix.** I copied the working tree to `/tmp/h1-base2` and replaced `genesis/runs/manager.py`
  with `git show 73b3bd3:genesis/runs/manager.py`. Then I ran the 5 touched test files with `PYTHONPATH=/tmp/h1-base2`
  (tracebacks confirm the old `manager.py:140` was loaded). Result: **11 failed, 142 passed**. The failures are all 5
  new `test_runs.py` tests, the 3 `test_features_api.py` UX/TD/FB finalizer tests,
  `test_test_design_stage.py::test_finalizer_binds_a_design_run_and_ignores_a_topup_run`,
  `test_story_design.py::test_finalizer_live_run_final_moves_to_review` and
  `test_story_implementation.py::test_finalizer_live_run_final_advances_to_code_review`. Example:
  `assert [('failed', 'running')] == [('failed', 'failed')]`. With the fixed `manager.py` restored in the same copy:
  **153 passed, 4 skipped**. This matches the developer's claim.
- **The observer list is complete.** `grep add_event_observer|_observers|cbus(` over `genesis/genesis/**` finds 6
  registrations, all wired in `api/app.py`:
  `ChatRunSupervisor` (:101-102), `StageFinalizer` (:106-107), `SyncLinkObserver` (:142), `TopupRunObserver` (:149),
  `StoryDesignFinalizer` (:164-165) and `StoryImplementationFinalizer` (:168-170). `api/features.py:349` builds a second
  `StageFinalizer` for on-read recovery only; it never calls `attach()`. The only bus subscriber is
  `api/run_routes.py:335` (`events_stream`), which reads only the bus and the durable log. The list in the brief is
  correct and complete for the **live** paths. One level-triggered path interacts with the new order (Minor M1 below).

## Checklist (`genesis-ctx check --since 73b3bd3 --repo genesis`)

### H1 sub-items (49-08 §1.1)
- [OK] H1.1 — status stored before `run.final` in `_finalize`; guard unchanged. `manager.py:139-141` guard (unchanged),
  `:142-143` optional `error` first, `:146` `_store_status`, `:147` `run.final`, `:148` bus close.
  If `set_status` fails, `run.final` is still emitted and the bus is still closed, with an ERROR log: `manager.py:151-160`.
  Tested by `test_runs.py:535` (`test_a_failed_status_write_still_announces_run_final_and_closes_the_bus`).
- [OK] H1.2 — non-terminal `final` branch: `_store_status` (`manager.py:213`) runs before the marker (`:214`), and the
  bus stays open. Tested by `test_runs.py:526`, which asserts `not mgr.cbus(run_id)._closed`.
- [OK] H1.3 — observer audit complete (see above). The As built entry is not written yet (Minor M2).
- [OK] H1.4 — tests: a real RunManager driven by a scripted event stream (`test_runs.py:472-549`), a real-subprocess
  variant (`:552`), and a live-path test per finalizer family. Stage: `test_features_api.py:363,560,656` and
  `test_test_design_stage.py:310,315`. Story design: `test_story_design.py:168`. Story implementation:
  `test_story_implementation.py:129`. Each one creates the run `running` and ends it through `rm._finalize`. All fail
  on the old order (verified).
- [OK] H1.5 — level-triggered recoveries are untouched. The diff does not touch `RunManager.reconcile_status`
  (`manager.py:341+`), `StageFinalizer.reconcile`/`reconcile_stage` (`chat/stage_finalizer.py:58-91`) or
  `ChatRunSupervisor.reconcile` (`chat/supervisor.py:123-148`). The reconcile/self-heal tests that use a `done` run were
  kept on purpose.
- [OPEN] H1.6 — own genesis commit + As built + lesson candidate. Not done yet; the tree is uncommitted (Minor M2).

### ADRs
- [OK] ADR-012 — subprocess worker unchanged; the app still imports no workflow Python. `test_runs.py:552` runs the real
  worker through `Supervisor`.
- [OK] ADR-009 — gate/pause HITL keeps the bus open and stores `awaiting_input:gate` (`test_runs.py:526` also asserts
  `pending_gate(...)["prompt"] == "ok?"`).
- [OK] ADR-030 / L-004 — SQLite store, no schema change.
- [N/A] ADR-001, 008, 010, 011, 018, 021, 022, 023, 024, 025, 026, 028, 031, 032, 033, 034, 035, 037, 041, 045, 047, 054,
  063, 065, 066, 068, 069, 073, 074, 076 — the diff touches only the stop-status ordering inside `RunManager` and tests.
  It adds no endpoint, state field, agent node, chat or config surface.
- [OK] ADR-077 — review run with `genesis-ctx`, no bulk docs read, no `--trust-all-tools`.

### Lessons
- [OK] L-003 — the bus closes only at a terminal status (`manager.py:148`). The gate branch leaves it open (`:213-214`).
  Both are asserted in `test_runs.py:510,526,535`.
- [OK] L-005 — no new event kinds; still `error` → `run.final` (asserted in `test_runs.py:518`:
  `kinds.index("error") < kinds.index("run.final")`).
- [OK] L-008 — the `worker_exit` no-clobber logic is unchanged (`manager.py:223-228`, `seen["err"]`).
- [OK] L-058 — the live bridge now works on the event itself; the level-triggered recovery stays as the safety net; the
  new failure path is loud (`log.error(..., exc_info=True)`, `manager.py:158-160`, asserted via `caplog`).
- [OK] L-061 / L-062 — finalizer scoping is unchanged: the bound-run guard and binding registry are untouched, and
  `test_finalizer_bound_run_guard` is kept. The topup-skip path runs through the live chokepoint
  (`test_test_design_stage.py:310`).
- [OK] L-065 — the gate→END terminal path still goes through `_finalize` (unchanged).
- [OK] L-011 / coding-standards §4 (stubs mirror reality) — the tests that hid the bug by hand-setting `done` are fixed.
  The scripted supervisor uses the real worker event shapes (`final{status,next,interrupts}`, `error{error,traceback}`).
  The real worker variant backs it up.
- [N/A] L-009, L-016, L-017, L-018, L-020, L-021, L-023, L-026, L-033, L-045, L-050, L-059, L-060, L-066, L-081 — the
  diff does not touch these areas.
- [N/A] L-025/L-027 (ruff is pinned, unchanged), L-030, L-051, L-056, L-057, L-087, L-088, L-089 — release/agent-system
  lessons; no release in this item. L-056 applies at commit time (M2).

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → 1353 passed.
- [OK] `cd genesis && .venv/bin/ruff check genesis` → All checks passed!

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **M1 — a narrow duplicate-notification race in `ChatRunSupervisor.reconcile`, opened by the new order.**
  `chat/supervisor.py:145-148` fires when `rec.status` is terminal. It keys the dedup on
  `eventlog.latest(run_id, RUN_FINAL).seq`, or `0` if there is none. The status is now stored (`manager.py:146`) one
  SQLite write before `run.final` is appended (`:147`). If a chat notification stream connects in that gap
  (`api/chat.py:171` calls `reconcile(session_id)` on every connect), reconcile sees a terminal record but either no
  `run.final` (seq 0) or the run's earlier non-terminal gate marker. That produces a dedup key different from the live
  one, so the copilot posts "finished" twice. Under the old order this could not happen: reconcile saw a non-terminal
  record until after `run.final` was logged. The impact is a cosmetic duplicate nudge in a microsecond window, with no
  data loss. **Fix (small, follow-up acceptable):** in `reconcile`, skip the terminal branch unless the latest `run.final`
  exists and `payload.status == rec.status`. The live observer delivers it in that case. Add a unit test that sets the
  status terminal with no `run.final` yet and asserts no note. Record it in the H1 As built either way, because the brief
  states that no observer relies on the old order, and this level-triggered path does.
- **M2 — H1.6 is not done yet.** The change is uncommitted, and 49-08 has no As built entry for H1. Before you move on,
  make one genesis commit containing all 7 files (L-056: check `git status` is clean afterwards). Then write the As built
  entry: the observer list above plus M1, the evidence (11 fail on the old order, 1353 pass), and the lesson candidate
  "announce a terminal event only after the state it describes is stored".
- **M3 (existing, narrowed, not introduced) — `_finalize`'s idempotency guard is check-then-act with no lock.**
  `manager.py:139-146`: a `cancel()` on the HTTP thread and an `on_exit`/`worker_exit` finalize on the reader thread can
  both pass `rec.status in TERMINAL` before either writes. The old window included the whole synchronous observer
  fan-out of `run.final`, which could be slow (stage finalize copies HTML and opens a chat). The new window is a single
  `set_status`, so H1 makes this race much less likely. The same is true if `set_status` fails: the record stays
  `running`, and a later `cancel` could emit a second `run.final`. I don't count this against H1. A per-run lock or a CAS
  `UPDATE … WHERE status NOT IN (terminal)` would close it; suggest a backlog item.

### Nits
- **N1 — stale comment.** `tests/test_test_design_stage.py:447` still says "the real chokepoint: run.final fires before
  the status write". That is no longer true; reword it to "stores the status, then announces run.final (49-08 H1)".
- **N2 —** the new tests assert on the private `EventBus._closed` (`test_runs.py:514,531,549`). That is consistent with
  the existing `test_runs.py` style, but a public `closed` property would be sturdier. Optional.
- **N3 —** `_ScriptedSupervisor` (`test_runs.py:480-491`) does not emit the real supervisor's trailing `worker_exit`
  after a non-zero exit (`runs/supervisor.py:87`). The failed-path test therefore does not exercise
  `error` + `worker_exit` together. L-008 is covered by existing tests, so this is optional fidelity: append
  `{"kind": "worker_exit", ...}` in `test_failed_status_is_stored_before_run_final_is_announced`.

## Verdict: **SHIP** (H1 code)

The ordering is correct in both paths. A failed status write still produces exactly one `run.final` and closes the bus,
and it is logged at ERROR. The level-triggered recoveries are untouched, and the regression tests fail on the old order
and pass on the new one. Both gates are green. No blockers or majors.

Conditions to close H1: do M2 (commit + As built). M1 is a small follow-up; fixing it in the same H1 commit is
preferred but not blocking. N1 can go in the same commit.

## Re-review (genesis-review, 2026-10-22)

Scope: only the fixes for M1, N1 and N3 on top of H1. The tree is still uncommitted against base `73b3bd3`. `git status`
lists 9 modified files: the 7 from the first review plus `genesis/chat/supervisor.py` and `tests/test_supervisor.py`.

### Gates (run by me)
- `.venv/bin/python -m pytest -q -p no:warnings` → **1355 passed** in 191 s (1353 + the 2 new supervisor tests).
- `.venv/bin/ruff check genesis` → `All checks passed!`
- The 6 H1 test files on their own → 167 passed.
- **The new test fails on the old code.** In a copy at `/tmp/h1-rr2` with `git show 73b3bd3:genesis/chat/supervisor.py`
  restored, `tests/test_supervisor.py` gives **1 failed, 9 passed**:
  `test_reconcile_in_the_status_stored_run_final_pending_gap_does_not_double_notify` fails at `test_supervisor.py:205`
  with "Left contains 2 more items". That means two duplicate "finished" notes under the old code, which matches the
  developer's claim.

### M1: resolved
- `chat/supervisor.py:145-155`: the terminal branch `continue`s unless `eventlog.latest(run_id, RUN_FINAL)` exists and
  its `payload.status == rec.status`. The dedup seq now comes from that event only (`:155`). The seq-0 fallback is gone.
- Why this matches the live key: `RunManager._log` appends to the durable log first and fans out after
  (`runs/manager.py:115-120`), and both paths pass the same `seq`. So when reconcile can see the `run.final`, the live
  observer's key `run_id:run.final:<seq>` is identical, and `notes.create` dedups any interleaving of the two.
- Tests: `test_supervisor.py:184` checks that reconcile back-fills and the live event then dedups. `:196` covers both
  gap shapes: no `run.final` yet, and only the earlier gate marker.
- **The behaviour change is acceptable.** A terminal record can exist without a matching durable `run.final` in only
  three ways:
  1. **Retention reclaimed the events.** The live note for such a run was delivered long ago under key `seq N`. The old
     seq-0 fallback built a *different* key, so on the next stream connect it would have posted a second, stale
     "finished" note for every reclaimed run. The new code removes that latent duplicate.
  2. **Legacy pre-07-02 runs.** A "finished" nudge for a months-old run would be noise. Skipping it loses nothing.
  3. **`eventlog.append` raised inside `_log`.** The live observers then never run either (`manager.py:115` comes before
     the fan-out), so this run now gets no note at all, where the old code would have back-filled one. This is a
     narrow failure case, and the run record is still correct.

  Every normal terminal write produces a `run.final` with the same status, so no normal path loses a notification:
  `_finalize` (`manager.py:146-147`) appends it even when the store write fails, and `reconcile_status`
  (`manager.py:353-360`) adopts a terminal status only *from* a `run.final`. Please record this trade-off in the
  As built (M2).

### N1: resolved
`tests/test_test_design_stage.py:447` now reads "stores the status, then announces run.final".

### N3: resolved
`_ScriptedSupervisor.spawn` (`tests/test_runs.py:486-487`) emits `worker_exit` on a non-zero exit, as
`runs/supervisor.py` does. `test_failed_status_is_stored_before_run_final_is_announced` now drives `error` and
`worker_exit` together. Its `detail == "boom"` assertion therefore checks the L-008 rule (the generic `worker_exit` does
not overwrite the specific `error`), and the test passes.

### Still open (unchanged, as agreed)
- **M2:** one genesis commit with all **9** files, then confirm `git status` is clean (L-056). Then write the As built:
  the observer list, the M1 fix and its trade-off above, the evidence (old code fails 11 + 1 tests, new code passes
  1355), and the lesson candidate.
- **M3:** move to the backlog, as proposed.
- **N2:** left as-is.

### Verdict: **SHIP**
M1, N1 and N3 are fixed. The tests show the fix works: they fail on the old code and pass on the new. Both gates are
green, and nothing new was found. H1 closes once M2 is done.
