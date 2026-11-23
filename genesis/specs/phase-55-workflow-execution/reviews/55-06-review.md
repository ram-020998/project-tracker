# Review 55-06 — base 3c3e38ae, head 6c6f93a5 (genesis-review, 2026-11-23)

What this change does: genesis-core gains `escalation_gate`, one interrupt gate that several agents (via
`attach_reliability`) and the healing ladder (via `attach_healing`) escalate to. Its payload uses the F6 mockup names,
and it answers retry / accept / stop / extra options (with legacy approve / reject / feedback mapped). The reliability
lint now requires that gate (F8), and the scaffolder uses it. `RunManager` enriches the payload (history, files,
run-level actions), refuses answers that `allowed` forbids, and adds `fix_and_accept`, `relaunch(instructions)` and
`restart_from` behind a binding registry that the feature and story APIs fill.

Reviewed `git diff 3c3e38ae..6c6f93a5` in genesis (one local commit, HEAD = 6c6f93a5 confirmed, tree clean). Nothing
live was run against the fleet. All probes ran in pytest `tmp_path` state dirs (scripts in `/tmp/55-06-probe/`).

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| genesis-core `pytest -q` | **149 passed** |
| genesis-core `ruff check genesis_core` | clean |
| genesis `pytest -q -p no:warnings` (full) | **2293 passed, 4 skipped** (748 s) |
| genesis `ruff check genesis` | clean |
| web `npm run typecheck` | clean |
| web `npx vitest run src/test` | 26 passed (3 files) |
| web eslint on `src/test/fixtures/events.ts` | clean |
| web `npm run build` / stale bundle | N/A: the only web change is a test fixture under `src/test/`, which is not in the bundle |
| genesis-workflows `ci/validate_library.py` | exit 1: **56 violations, all the F8 message**, across 16 workflows (action-capture 2, agent-prompt 1, code-review 8, erd-generation 2, feature-breakdown-analysis 4, generate-business-map 2, hello-appian 1, memory-consolidation 2, memory-maintenance 2, setup-composer 2, story-design-analysis 3, story-implementation 6, story-verification 5, technical-design-analysis 6, test-design-analysis 4, ux-design-analysis 6). 0 other violations. The non-compliant fixture check passes |
| genesis-workflows `pytest workflows --ignore=workflows/_fixtures` | **456 passed, 7 failed**: `_template`, action-capture, agent-prompt, code-review, hello-appian, setup-composer and story-verification. All 7 are the tests that call `check_reliability`, and all fail on the F8 rule |
| playwright-appian gates | N/A (repo untouched) |

The author's claims match what I measured. The only difference is 2293 passed against the author's 2292, which the race
test added with the lock commit explains.

## Checklist

### ADRs
- [OK] ADR-001 — The gate and router are LangGraph nodes. Every answer is a route the program chooses (`escalation.py:257-292`), and the agent decides nothing.
- [N/A] ADR-002 — The ACP turn path is unchanged; `kiro_node` only adds prompt lines (`agent.py:413-416`).
- [N/A] ADR-003, ADR-004, ADR-005, ADR-006, ADR-007, ADR-008 — Not touched.
- [OK] ADR-009 — All three HITL modes are intact. The plain fork is unchanged apart from the optional inherited-instructions trigger (`test_restart_from_refuses_a_done_run_and_the_plain_fork_is_unchanged`).
- [OK] ADR-010 — State gets only small decisions: guidance capped at 4,000 chars (`escalation.py:262`), the stop reason at 2,000 chars, and scalar extra answers.
- [OK] ADR-011 — The trio is kept and the lint is stricter (`lint/reliability.py:98-107`; `test_a_direct_escalate_to_end_fails`, `test_a_hitl_gate_escalation_fails_the_f8_rule`).
- [OK] ADR-012 — The app imports only `genesis_core.nodes.escalation.normalize_answer` (core, not workflow Python). The run instructions reach the worker through the job (`worker.py:281-283`).
- [OK] ADR-014 — The scaffolder template uses `escalation_gate` (`create_workflow.py:63-72`). Reviewer probe `test_probe_scaffold.py`: the scaffolded graph passes `check_reliability`. No genesis test pins this; see n2.
- [N/A] ADR-015, ADR-017 — Not touched.
- [OK] ADR-018 — `context_refs` are pointers, and the files list holds paths and sizes only.
- [OK] ADR-019 — `CORE_MAJOR` is unchanged. The change is additive: `attach_healing(gate=str)` and `attach_reliability(on_exhaust_gate=str)` still work, and the `NodeKind` literal gains one value.
- [N/A] ADR-020 — Not touched.
- [OK] ADR-021 — The gate pauses as kind `escalation`, which is sanctioned. `check_hitl_posture` does not inspect kinds (`lint/contract.py:100-102`).
- [OK] ADR-022 — The fork copy lands under `artifacts_dir/<wf>/<new>` (`manager.py:1182-1195`).
- [N/A] ADR-023 — Not touched.
- [OK] ADR-024 — Async nodes; no sync saver.
- [OK] ADR-025 — `restart_from` seeds a new thread. The original's checkpoint count is unchanged (`test_restart_from_forks_running_…`).
- [N/A] ADR-026, ADR-027, ADR-028 — No route or UI is added; the API comes in 55-08.
- [N/A] ADR-029, ADR-030 — Not touched. The audit uses the existing tables.
- [OK] ADR-031, ADR-033 — No chat tool is added. `source="resolve"` is only a label; the confirm path is 55-07.
- [N/A] ADR-032 — Not touched.
- [VIOLATION → M2] ADR-034 (sandbox boundary, security area) — `fix_and_accept` resolves "the session's sandbox" from an unchecked `session_id`. `".."` escapes it (probe below).
- [OK] ADR-035 — Uploads are re-provisioned through `start(files=…)` (`test_relaunch_reprovisions_the_uploads`).
- [N/A] ADR-036 to ADR-049 (except 034/035 above) — Not touched.
- [OK, note] ADR-050 — The rebind writes the stage status through `reset_for_reupload` / `reset_for_rerun`, as the existing re-run endpoints do (`features.py:1160,1197,1459`; `workbench.py:297,419`). The spec asks for exactly that path. This adds no new class of bypass, but it is one more direct caller.
- [N/A] ADR-051 to ADR-055 — Not touched.
- [OK] ADR-056 to ADR-060 — Stage bindings come from `StageFinalizer._BINDINGS` (`features.py:283-313`). Test-design top-ups are refused.
- [OK] ADR-061, ADR-062, ADR-068 — Story bindings cover only design and implementation, and the lane is not moved (`workbench.py:70-98`). On a relaunch of a done `story-implementation`, see "Dev decisions" 1.
- [N/A] ADR-063 to ADR-067 — No collaboration or healing contract change beyond `attach_healing`'s gate parameter.
- [OK] ADR-067 — Healing exhaustion goes to the standard gate. Retry resets heals and restarts and carries the user's guidance (`test_healing_retry_restarts_with_the_budget_reset_and_the_users_guidance`).
- [N/A] ADR-069 to ADR-080 — Not touched.
- [OK] ADR-081, ADR-082, ADR-084 — The queue-managed workflows (test-execution, story-verification, setup-composer, action-capture) are refused for relaunch and restart (`testexec/*.py`; `test_queue_managed_workflows_are_refused`).
- [N/A] ADR-083, ADR-085, ADR-086, ADR-087 — Not touched. For the scheduler interaction, see m2.

### Lessons
- [N/A] L-001, L-002 (the options build is unchanged), L-003, L-004, L-006, L-008, L-009, L-010, L-013, L-016 to L-019, L-021 to L-025, L-027, L-029 to L-031, L-033, L-039, L-041 to L-045, L-048 to L-051, L-053, L-056, L-057, L-059, L-060, L-063 (see decisions), L-064, L-066, L-068, L-069, L-071 to L-074, L-076, L-081 to L-090, L-092, L-095 to L-101, L-103 to L-105, L-107, L-109, L-111 to L-119, L-123 to L-125 — Not in the changed paths, or nothing in the diff touches them.
- [OK] L-005 — The only new kind is `run.relaunched`, and it is canonical.
- [OK] L-020 — No loop limit change. A retry goes through the existing `retries` channel.
- [OK] L-026 — The gate node does no blocking DB writes.
- [OK] L-058, L-062 — Bindings live in one registry; finalizers are unchanged.
- [OK] L-061 — The rebind happens after the new record exists and before the run or resume worker spawns. Spy tests: `test_relaunch_of_a_stage_bound_run_moves_the_stage_before_the_new_worker_spawns`, the story variant, and restart_from. A run whose stage moved on is refused (`test_a_run_whose_stage_moved_on_cannot_be_relaunched`).
- [OK] L-065 — `<gate>_stop` sets `status=failed` and ends the graph (`test_stop_ends_failed_with_the_reason_and_one_run_final`).
- [OK] L-075 — Retry heals in place (healing budget reset), not a whole rerun.
- [OK] L-091 — Replacing a run is serialized by `_replace_lock` (`test_two_relaunches_at_once_replace_the_run_once`); one process owns the runs (L-097).
- [OK] L-093 — Terminal states go through the real `_finalize` with an observer that reads the stored status at `run.final` (fixture `env`).
- [OK, with gaps] L-094 — I traced the consumers of `cancel()`, `start()`, `respond()` (`api/run_routes.py:216` is the only external caller), `_genesis_kind` (lint, `contract.py`, `memory/brief.py`), the gate payload (chat supervisor `chat/supervisor.py:105-117` reads `options` and `prompt` and is still compatible) and the scheduler (`runtime/scheduler.py:390`). The gaps: the scheduler (m2) and the run's environment (m1).
- [OK] L-102 — No migration.
- [OK] L-106 — `allowed` and `options` are built from state. A legacy approve is refused when accept is unavailable (`test_an_action_the_state_does_not_allow_is_refused`). An unknown answer stops the run instead of ending it `done`.
- [OK] L-108 — The old run is cancelled through `cancel()` (stop intent + CAS, now with `detail`). Exactly one terminal `run.final` (`_terminal_finals == ["cancelled"]`).
- [OK] L-110 — Gates re-run by the reviewer at 6c6f93a5 (table above).
- [OK] L-120 — `relaunch` and `restart_from` return the new id. No handler exists yet (55-08).
- [OK] L-121 — The fork op's worker writes only the new run's status (`event_run_id=new_id`).
- [OK] L-122 — `run.relaunched` is in `CANONICAL_KINDS`, `CANONICAL_EVENT_KINDS` (web) and `canonical-kinds.json`. The full pytest and vitest runs are green.

### Gates
- [OK] genesis pytest (api, browser-testing, features-stages, runs-worker, stories-workbench, workflows-library rows) — 2293 passed, 4 skipped.
- [OK] genesis ruff (all rows) — clean.
- [OK] genesis-core pytest + ruff — 149 passed; clean.
- [OK] web lint + typecheck + test — clean / clean / 26 passed (src/test). I did not run the full vitest suite; only a fixture changed.
- [N/A] web build / commit `web/static` — No bundled file changed.
- [EXPECTED FAIL, recorded] genesis-workflows `validate_library` — 56 violations, all F8 (spec §5 expects this until 55-10).
- [EXPECTED FAIL, recorded] genesis-workflows pytest — 7 lint-calling tests fail on F8 and the other 456 pass. Spec §4 ("every existing workflow test still passes") conflicts with §5. I accept the author's reading; 55-10 must turn these green before the 55-12 pin move.
- [N/A] playwright-appian lint/typecheck/test/build — Not touched.

## Findings

### Blockers
None.

### Majors

- M1 **`restart_from` carries the exhausted retry budget (and the healing ladder's spent budget) into the fork, so the
  restarted run escalates on its first failed check** (`genesis/runs/manager.py:1185-1196`, the `seed` only rewrites
  `artifacts`; `worker.py:320-327` merges all of `src.values`). What: the fork copies the escalated state whole,
  including `retries[<agent>] = retry_max + 1`, `_healing.{heals_used, restarts_used}` at their maxima, and
  `decisions["_escalation.stopped"]` / `status="failed"` when restarting a stopped run. Problem: the reviewer probe
  `/tmp/55-06-probe/test_probe_restart_budget.py` takes `esc` (retry_max 1) to the gate, giving `retries {'draft': 2}`,
  then calls `restart_from(old, "plan", {"inputs": {"fails": 10}})`. The restarted run is back at the gate after **one**
  draft turn, with `retries {'draft': 3}` and **0** `retry.scheduled` events. For every healing-wrapped design workflow,
  the first unconfirmed verify after a restart escalates at once (`heal_route` sees the ladder spent). The existing
  test `test_restart_from_forks_running_…` passes only because the copied `draft.turns` makes the restarted turn pass.
  For a restart from a stopped run, a later non-gate `failed` gets the stale detail "stopped at the gate: <old
  reason>" (`_stop_detail`, `manager.py:120-126`). Fix: in `_restart_from`, seed `retries` with every key set to 0
  (the `_inc_merge` reducer takes the last value), seed `_healing` with `{"heals_used": 0, "restarts_used": 0}`, and
  clear `decisions["_escalation.stopped"]` / `["_escalation.from"]` and `status`. Add a regression test where the
  restarted agent fails once and must retry before it escalates. If skipped: "Restart from an earlier step" gives the
  user zero retries, which is a worse first attempt than "Retry with guidance", whose hint promises that "its retry
  budget starts again".

- M2 **`fix_and_accept` trusts `session_id` to name the sandbox, so `".."` (or `"a/../b"`) reads files outside any
  Resolve sandbox** (`genesis/runs/manager.py:1066-1070`). What: `sandbox = (skill_output_dir / session_id).resolve()`,
  then `source_file` must only be inside *that*. Problem: the reviewer probe
  `/tmp/55-06-probe/test_probe_fix_session.py` calls `fix_and_accept(run, path="draft.json",
  source_file="not-a-sandbox.json", session_id="..")` with the file placed beside the sandboxes root. The run's
  `draft.json` became that file and the run ended `done`. With the real layout, `skill_output_dir/..` is the state dir,
  so a caller could copy a file such as the secrets store into a run output that Documents then serves. The spec's
  trust rule ("`source_file` must resolve inside the Resolve session's sandbox") is not enforced at the method that
  owns it. No HTTP route reaches it yet (55-07/55-08), which is why this is a major and not a blocker. Fix: refuse a
  `session_id` that is not a single plain path segment (`Path(session_id).name != session_id or session_id in ("",
  ".", "..")` → `RunActionError`), and preferably require that the chat session exists (`ChatStore.get`). Add both
  cases to `test_fix_and_accept_checks_its_paths_…`. If skipped: the 55-08 route inherits a sandbox escape.

- M3 **No test fails when one gate routes an answer to the wrong agent** (`escalation.py:209-213` `target_for`;
  `reliability.py:78-79` record `FROM_KEY`). What: one gate serves several agents, and `decisions["_escalation.from"]`
  picks which agent retry and accept go to. Problem: a reviewer mutation (`/tmp/55-06-probe/conftest_mut.py`) makes
  `target_for` ignore `FROM_KEY` and always return the first registered target. All core escalation tests still pass
  (19 passed with the mutation). In `test_run_actions.py` the fixture has two agents on one gate (`draft`, `polish`),
  but only `draft` ever fails. With that mutation, an escalation at `polish` would show `failed_node: "draft"` and
  retry the wrong step, and the healing ladder's retry would go to the verify agent instead of `restart_target`. This
  is the shared-gate path every library workflow adopts in 55-10. Fix: add a core test with two agents on one gate,
  where the second exhausts. Assert `failed_node`, `validator_messages`, that `retry` re-runs the second agent with
  its guidance (and the first never gets it), and that `accept` goes to the second agent's `nxt`. Add a healing test
  where the ladder's retry goes to `restart_target` while a verify-trio retry goes to `verify`. If skipped: a
  regression in target selection ships silently into every workflow.

### Minors

- m1 **Relaunch drops the run's environment** (`manager.py:1141` calls `start(...)` without `environment`; it is
  passed only to the first `op: run` worker, `manager.py:498`, and never stored). Case: a run started via
  `POST /runs {environment: "<non-default>"}` escalates. The relaunch targets the default active environment, which
  contradicts D13's "every input reused unchanged". Resume has the same gap already (pre-existing), so this does not
  block. Fix: store the launch `environment` in `trigger_json` (no new column) or on the record, and pass it to
  `start` in `relaunch` (and to every `_spawn`). If skipped, at least record the limit in the As built.

- m2 **A relaunched or restarted scheduled run leaves its schedule's history on the cancelled run.** The scheduler
  follows its fire's `run_id` (`runtime/scheduler.py:390-403`). Case: a scheduled `agent-prompt` run escalates and the
  user relaunches it. The schedule row closes `cancelled` and the new run's outcome and credits are never attributed
  to the slot (L-120's intent). Fix: have the scheduler follow `run.relaunched.to_run` when it closes a fire, or
  record the limit in the As built as a 55-08 follow-up.

- m3 **History wording differs from the approved mockup** (`manager.py:937-950`). The mockup's entries read "Verify
  round 2: not confirmed, 2 fixes", "Heal 1 of 1: …" and "Restart 1 of 1: …" (`fixtures.ts:305-311`). The code emits
  "Verify: not confirmed, 2 fixes", "Heal 1: …" and "Restart: pass 3 …". The field names match (D12 item 10); the
  text was approved with the page. Fix: number verify rounds by counting `verify.result` events, and print `of
  <max>` from the healing budget when the event carries it. Otherwise 55-09 should note the change.

### Nits

- n1 `restart_from`'s `w.wait(timeout=60)` ignores the return value. A fork worker that has not finished in 60 s is
  treated as forked (status PENDING is not terminal), and the old run is cancelled while the seed may not exist yet.
  `fork()` has the same pre-existing pattern. Refuse when the worker is still alive after the wait.
- n2 No genesis test lints the scaffolder's output. The library's `_template` test catches it, but that test runs in
  the other repo and is red until 55-10. The reviewer probe `test_probe_scaffold.py` passes, so a 10-line test in
  `tests/test_lint.py` would pin it.

## Dev decisions not in the spec

1. **Relaunch rebinds instead of calling the HTTP re-run entry points. Agree.** Those entry points `rmtree` the stage
   or story-stage dir that the old inputs point at, and they re-snapshot the upstream artifacts, which would break
   D13's "inputs unchanged". Side effects to record in the As built and for 55-08's confirm copy: (a) a relaunch skips
   the re-run's prerequisite checks (`_td_prereqs_ready`, `_fb_prereqs_ready`, the story's completed design). Because
   the inputs are the old snapshots, that is consistent with D13, but the new run can use upstream content the user
   has since replaced. (b) A relaunch of a **done** `story-implementation` re-applies object writes under ADR-068.
   The original drag-confirm covered the first run, so 55-08's relaunch confirm must say that it writes to Dev again.
   (c) Story-stage snapshot files are reused in place, so a later re-drag of the same story overwrites the file a
   relaunched run reads.
2. **Queue-managed workflows are refused. Agree.** ADR-081/082 make executions program-only through their service;
   the refusal reasons tell the user where to restart.
3. **Manual actions are not in `copilot_actions`. Agree as a deferral.** I confirmed m0006 has `session_id TEXT NOT
   NULL REFERENCES chat_sessions(id) ON DELETE CASCADE`. However, D6 (a user decision) says "every action is audited
   in `copilot_actions`", so the spec agent must record a ruling: either amend D6 or schedule the m0031 change in
   55-08. Note also that deleting the Resolve chat cascades away its audit rows.
4. **Seven genesis-workflows lint tests fail on F8. Agree.** They are the same rule as `validate_library`, and nothing
   else fails. 55-10 must make them green before the 55-12 pin move.

## Not checked
- Live behaviour on a real workflow (a healing-wrapped stage run through gate → each action) is deferred to 55-10/55-12 live acceptance; no fleet or credit runs were used, as instructed.
- The full web vitest suite (only `src/test` ran; the web change is one fixture).
- How the existing Run Detail renders the new `<gate>_stop` node and the enriched payload, which needs a library workflow that adopts the gate (55-10).
- The behaviour of a relaunch whose `before_spawn` rebind raises after the old run was cancelled. By reading: the old run stays cancelled with no `run.relaunched`, and the stage may be left `in-progress` with `run_id` NULL. There is no test.

## Verdict: NEEDS_CHANGES

Fix M1 (reset the retry and healing budgets and the stale stop markers in `restart_from`, with a regression test), M2
(validate `session_id` in `fix_and_accept`, with tests) and M3 (a test for one gate serving two agents, and for the
healing ladder's retry target). The minors can be fixed or recorded in the As built.

---

# Re-run (round 1 fixes) — base 6c6f93a5, head a9a1cce8 (genesis-review, 2026-11-23)

Reviewed `git diff 6c6f93a5..a9a1cce8` (one commit, 4 files: `genesis/runs/manager.py`,
`packages/genesis-core/tests/test_escalation_gate.py`, `tests/test_lint.py`, `tests/test_run_actions.py`). HEAD =
a9a1cce8 confirmed, tree clean. genesis-workflows has no new commit since round 1, so its round 1 gate results stand.
No fleet restart, no Appian or credit runs. Every probe ran in a pytest `tmp_path` with a scratch `GENESIS_STATE_DIR`
under `/tmp/55-06-rerun/`; the probe files and mutation plugins are there.

## Gates (run by the reviewer at a9a1cce8)

| Gate | Result |
|---|---|
| genesis `pytest -q -p no:warnings -x` (full) | **2295 passed, 4 skipped** (743 s); matches the author's claim |
| genesis `ruff check genesis` (ruff 0.15.20) | clean |
| genesis-core `pytest -q` | **152 passed** (149 + the 3 new M3 tests) |
| genesis-core `ruff check genesis_core` | clean |
| web, playwright-appian | N/A: untouched by the fix commit |
| `genesis-ctx check --since 6c6f93a5` | maps the 4 files to no area, so only the always-on release-ci and security rows are listed; answered below |

## Round 1 findings, re-checked

- **M1: fixed.** `_restart_from` (`manager.py:1205-1219`) seeds `status: running`, every existing `retries` key at 0,
  `_healing {heals_used: 0, restarts_used: 0, guidance: ""}` when present, and clears `_escalation.from/.stopped`.
  The user's `values` are merged over these resets. The reducers make this work: `retries` is `_inc_merge` and
  `_healing`/`decisions` are `_merge`, both last-writer per key (`genesis_core/state.py:13-25,57-65`). The `binding`
  key is still the one `rebind` uses (`manager.py:1190,1249`), with the loop variable renamed to `chan`.
  Evidence:
  - My round 1 probe `test_probe_restart_budget.py` now shows `retries {'draft': 2}` and **1** `retry.scheduled` on
    the restarted run. In round 1 it was `{'draft': 3}` and 0.
  - New test `test_restart_from_starts_with_a_fresh_retry_budget_and_no_stale_stop_marker` passes.
  - Mutation plugin `mut_m1.py` strips all reset channels from the fork op's seed: the new test fails ("the fork from
    plan failed: stopped at the gate: first try").
  - Mutation `mut_only_retries.py` strips only `retries`: the new test fails. The retry-budget assertion is load-bearing
    on its own.
  - Mutation `mut_only_healing.py` strips only `_healing`: all 24 restart, relaunch and run-action tests still pass.
    See m4.
- **M2: fixed.** `fix_and_accept` refuses a session id that is empty, `.`/`..`, contains a backslash or is not
  `Path(sid).name`, and one with no `ChatStore` row (`manager.py:1069-1074`). Building the sandbox as
  `skill_output_dir / session.id` matches the chat finalizers (`chat/stage_finalizer.py:134`,
  `chat/story_design_finalizer.py:143`). My round 1 escape probe `test_probe_fix_session.py` (`session_id=".."`) now
  raises "a fixed file comes from a Resolve session's sandbox; give its session id". The new cases in
  `test_fix_and_accept_checks_its_paths_then_copies_and_records_the_fix` cover `..`, `.`, `""`, `sess-1/../sess-1`,
  `a/b` and an unknown session.
- **M3: fixed.** My round 1 mutation (`conftest_mut.py`: `target_for` always returns the first target) now gives
  **3 failed, 19 passed**: `test_a_shared_gate_answers_for_the_agent_that_escalated`,
  `test_a_shared_gate_accepts_into_the_escalated_agents_successor` and
  `test_a_verify_trio_retry_goes_to_verify_and_a_ladder_retry_to_the_restart_target`. The first test asserts
  `failed_node`, `validator_messages` and that only `second` gets the guidance. The second asserts that accept goes to
  `second`'s `nxt`. The third asserts that a verify-trio retry re-runs verify and leaves `plan` at 1 turn. The
  ladder → `restart_target` half is the existing healing retry test, as the author says. (To run the mutation, I
  copied the plugin into `packages/genesis-core/tests/` for one pytest call and deleted it straight after;
  `git status` is clean.)
- **m1, m2: not fixed. Accepted as limits** that the As built must record: the launch environment is never stored,
  and resume has the same gap; the scheduler follows the cancelled run, which is a 55-08 follow-up.
- **m3: fixed in wording, with a regression.** The text now reads "Verify round N: …", "Heal N: patch k items in
  place, then re-assemble" and "Restart N: the whole run again from the start, with the critic's guidance"
  (`manager.py:941-955`). See n3.
- **n1: fixed.** `TimeoutExpired` is caught. A still-alive fork worker is killed and the new run is finalized
  `failed`, so the original is never cancelled (`manager.py:1231-1238`). `_finalize` is a compare-and-set, so the
  killed worker's own exit cannot announce a second `run.final` (`manager.py:233-241`). No test; see n4.
- **n2: fixed.** `tests/test_lint.py::test_the_scaffolded_workflow_passes_the_lint` passes in the full run.
- **Dev decisions 1 and 3:** the author will record them in the As built, as round 1 asked: decision 1's (a)–(c), and
  the D6 ruling for the spec agent.

## Checklist for the fix delta (always-on rows from `genesis-ctx check`)

The round 1 checklist still covers the whole change 3c3e38ae..a9a1cce8. For this delta:

- [OK] ADR-011: there is no lint or trio change. The scaffolded workflow now has a genesis test that it passes F8
  (`test_lint.py:117`).
- [OK] ADR-019: no core API change. The delta adds core tests only, and `CORE_MAJOR` is untouched.
- [OK] ADR-021: gate kinds are unchanged.
- [OK] ADR-025: a restart still seeds a new thread. The resets go into the fork's seed only, and the original's state
  is read and never written (`manager.py:1209`).
- [OK] ADR-031, ADR-033, ADR-034: M2 closes the sandbox escape, so a fixed file can come only from a real session's
  `skill_output_dir/<id>` (`manager.py:1069-1078`).
- [N/A] ADR-026, ADR-028, ADR-029, ADR-032, ADR-045 to ADR-087 (the other listed rows): not touched. No route, UI,
  trust, credit, schedule, test-execution or Kiro launch change.
- [OK] L-108: the n1 kill path finalizes through the CAS `_finalize`, giving exactly one terminal write.
- [OK] L-110: I ran the gates myself at a9a1cce8 (table above).
- [OK] L-092: the new tests have unique module and function names. My temporary probe plugin was named
  `conftest_mut_probe`, not `test*`, and was removed.
- [N/A] L-017, L-025, L-027 (ruff is pinned; 0.15.20 ran clean), L-030 (no web change), L-044, L-045, L-051, L-056,
  L-057, L-087 to L-089, L-098 to L-101, L-104, L-105, L-111 to L-113, L-116, L-117, L-119, L-125: no release,
  pin, web, shell-guard, Kiro or report change in the delta.

## New findings

### Blockers / Majors
None.

### Minors

- m4 **No test covers the healing-budget half of the M1 reset** (`manager.py:1213-1214`). Case: mutation
  `/tmp/55-06-rerun/mut_only_healing.py` drops `_healing` from the fork seed, and every restart, relaunch and
  run-action test still passes. This is the case round 1 named for every healing-wrapped design workflow: after a
  restart, the first unconfirmed verify must heal and not escalate at once. By reading, the reset works, through the
  same `_merge` mechanism the retries test proves. Smallest fix: one test in `test_run_actions.py` that restarts a run
  whose state has `_healing` at its maxima and asserts the fork's state reads `{heals_used: 0, restarts_used: 0}`. A
  state-only assertion after `restart_from` returns is enough. Alternatively, 55-10 adds it when the first library
  workflow adopts the gate. Either way, record it in the As built.

### Nits

- n3 The verify history line no longer includes the critic's `summary`. `verify.result` still carries it
  (`healing.py:120-121`), and the approved mockup shows exactly that detail in parentheses ("…, 3 fixes (sections 4,
  6, 7)", `web/src/dev/mockups/phase55/fixtures.ts:307`). The m3 fix removed the `(summary)` suffix the round 1 code
  had. No test pins the verify, heal or restart wording; `test_the_gate_payload_is_enriched_…` checks only the retry
  lines. Fix: append `f" ({summary})"` when it is present, and add one history assertion when a healing fixture
  exists (55-10).
- n4 The n1 path has no test. There is also a narrow race: `Worker.wait` joins the reader thread with the timeout and
  then waits on the process. If the process has exited but the reader thread has not yet applied the fork's final
  event, `is_alive()` is False and the store still reads PENDING, which is treated as success. The fork op normally
  writes its result before exiting, so this is unlikely. Recording it is enough.
- n5 `_iteration.pass` is not reset in the fork seed. The ADR-066 iteration capture of a restarted healing run keeps
  counting passes from the escalated run. This is cosmetic, and the D12 history counts from events, not from this
  field.

## Not checked (re-run)
- Live behaviour, as in round 1 (deferred to 55-10/55-12 live acceptance).
- A manager-level healing-wrapped restart (m4); I verified it by reading the reducer only.
- The full web suite; the fix commit has no web change.

## Verdict (re-run): **SHIP**

M1, M2 and M3 are fixed, and their tests fail under the round 1 mutations. n1 and n2 are fixed. m3 is fixed apart
from n3. The As built must record m1, m2, m4, dev decisions 1 (a)–(c) and 3 (the D6 ruling), and must say that
genesis-workflows' F8 failures (56 `validate_library` violations, 7 pytest) stay red until 55-10.
