# Review 55-10 — genesis base a09c5fbe → 6185c905, genesis-workflows base 9066541 → 60c12f3 (genesis-review, 2026-11-24)

What this change does: every library workflow with an agent node now escalates to one standard `escalation_gate`.
Each workflow's own answers are `extra_options`, and `stop_to="cleanup"` is set where cleanup must run on a stop.
`META.artifacts` and `workflow.yaml` move to the role map; every workflow declares `relaunchable` (plus a
`relaunch_hint` where it is false); the two memory jobs opt out of the memory brief; versions are bumped. genesis
adds `escalation_gate(stop_to=)`, the `prompt_fn` `""` fallback, the `_genesis_mcp` marker on `kiro_node`, the D26
lint `check_required_mcp` (run by `validate_library` and `genesis test-workflow`), the scaffolder's map form, and the
route-test harness `genesis/testing/escalation.py`.

Both shas exist (`git rev-parse` on 6185c905 and 60c12f3). Both trees are clean, and the commits are local only.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `genesis-workflows: ci/validate_library.py` | `LIBRARY VALIDATION PASSED (19 workflow(s) validated)`, exit 0 |
| `genesis-workflows: pytest -q workflows --ignore=workflows/_fixtures` | **668 passed** in 41.98 s; `find workflows -path '*tests*' -name __init__.py` finds nothing (L-092) |
| `genesis-workflows: ci/validate_skills.py` | `SKILLS VALIDATION PASSED (5 skill(s) validated)` |
| `genesis: pytest -q -p no:warnings` (`GENESIS_STATE_DIR=/tmp/rv-55-10/state`) | **2387 passed, 4 skipped** in 856 s |
| `genesis: ruff check genesis` | All checks passed |
| `genesis-core: pytest -q` / `ruff check genesis_core` | **157 passed** / All checks passed |
| web lint/typecheck/vitest/build, playwright-appian | N/A: the diff touches no `web/**` and no playwright-appian file |
| CI image (L-112), dev's run in `/tmp/colima/gr-55-10/ci-image.txt` | library gates and pytest 668 green; genesis-core 157 green; genesis: **only 5 suites ran** (`run.sh`: test_lint, test_gate_harness, test_dist, test_run_actions, test_phase55_api), 91 passed + 1 failed (see m1, m2). colima is not running now, so I did not re-run it. |

## The pre-existing failure the dev asked about

`tests/test_phase55_api.py::test_the_file_routes_refuse_system_paths` is **pre-existing, from 55-08**. The test came
in with bd9873c6 / 1f8fd8b5. `git diff --stat a09c5fbe 6185c905 -- tests/test_phase55_api.py genesis/api genesis/runs`
is empty, so 55-10 changes neither the test nor the code it calls.

Mechanism: `_artifact_path` (`genesis/api/run_routes.py:322-327`) returns 404 when the resolved target `is_file()` is
false, before the System-path check. On case-insensitive APFS, `_KIRO/settings/cli.json` resolves to the real
`_kiro/settings/cli.json`, so the route gets as far as the 403. On Linux (the CI image) no such file exists, so the
route answers 404. Nothing is served either way, so the route is safe; the test is the part that is wrong. Carry it
as m1 below.

## Checklist

ADRs (the union of `genesis-ctx check` for both repos)
- [OK] ADR-001 — control flow stays in LangGraph. Every gate route is a compiled conditional edge (`EscalationGate.attach`, `escalation.py:195-200`), and no agent decides a route.
- [OK] ADR-006 — each workflow stays a folder package with `workflow.yaml` mirroring `META`; parity holds in `validate_library` (contract step) for all 19.
- [OK] ADR-009 — designed gates are kept: `kb_gate` and `verdict_gate` are approval gates, `escalate` is an escalation gate, and `generate-business-map`'s review gate is kept. Pause/resume and state edits are untouched.
- [OK] ADR-010 / ADR-018 / ADR-022 — state gains only small markers (`_escalation.from`, `*.accepted_unverified`, `proposals_refused`); bulk stays in files (e.g. the reverify gaps are read from `reverify.json` by `_gap_messages`).
- [OK] ADR-011 — every agent node keeps validator + retry + escalation to the standard gate. `validate_library` reliability step passes, and its non-compliant fixture still fails.
- [OK] ADR-012 — the app does not import workflow Python. `check_required_mcp` runs only in the lint/CI process (`validate_library`, `genesis test-workflow`), and the harness is test-only (`genesis/testing/escalation.py` docstring; nothing in `genesis/` imports it: grep).
- [OK] ADR-014 — the scaffolder emits the standard gate, the role map and `relaunchable: false`: `tests/test_lint.py::test_the_scaffolded_workflow_declares_roles_and_is_not_relaunchable`.
- [OK] ADR-019 — `CORE_MAJOR` unchanged; `stop_to=` and `_genesis_mcp` are additive (default `None` keeps `stop_node → END`, `escalation.py:198`).
- [OK] ADR-021 — `auto_approve` unchanged; the only gate kinds are approval and escalation. story-implementation's writes still follow the lane confirm (ADR-068), and Accept / PROCEED_ANYWAY at a reverify gap lead to the same writes PROCEED_ANYWAY led to before.
- [OK] ADR-029 — tool trust lists are unchanged. The D26 lint keeps every static `kiro_node(mcp=)` server inside `required_mcp`, so the Dev-write guard sees it (`contract.py:111-131`, `test_required_mcp_lint_fails_a_node_server_missing_from_required_mcp`).
- [OK] ADR-047 / ADR-087 — the memory and sync jobs are `relaunchable: false` with "Use Run now on the Schedules page".
- [OK] ADR-053 / ADR-054 — `memory_brief: false` on memory-consolidation and memory-maintenance (META + yaml, schema-validated); nothing touches memory.db's schema.
- [OK] ADR-056 / 057 / 058 / 059 / 078 — the four stage outputs equal the StageFinalizer bindings (`test_*` in ux/td/fb/test-design: `outputs == [_BINDINGS[id].artifact]`); `StageFinalizer._finalize` still skips a run that is not done or has no artifact (`stage_finalizer.py:99-124`).
- [OK] ADR-062 / ADR-068 — story-implementation: no delete tool was added, and nothing writes on stop (`test_stop_and_any_ambiguous_answer_end_failed_after_cleanup_never_in_writes`). `relaunchable: false` because it writes to Dev.
- [OK] ADR-067 — `attach_healing(gate=escalate, artifact=…)` everywhere except test-design-analysis, which passes no `artifact=` on purpose (`graph.py:1818`; judged below).
- [OK] ADR-069 / ADR-086 — skills and the Kiro launch are unchanged.
- [OK] ADR-073 — no package tool reaches an agent.
- [OK] ADR-080 — one repo; no new internal dependency entry. `jsonschema>=4` is already a main dependency of genesis (`pyproject.toml:47`), so the library CI has it.
- [OK] ADR-081 / ADR-082 / ADR-083 — action-capture, setup-composer and story-verification still write QA data only through the replay or execute paths; credentials stay out of agents; on a stop, story-verification still goes through `cleanup` (close-all, reap, scrub): `test_stop_runs_cleanup_ends_failed_and_records_stopped`.
- [OK] ADR-084 — story-verification: pass/accepted → Done, failed/send_back → Implementation, stop → stays in Verification (`_final_decision` "stopped"; the finalizer moves only on `MOVES`, `story_verification_finalizer.py:54,234`; a failed run records the execution as `error`, `:184-185`).
- [N/A] ADR-002, 003, 004, 005, 007, 008, 013, 015, 017, 020, 023, 024, 025, 026, 027, 028, 030, 031, 032, 033, 034, 035, 036, 037, 038, 039, 041, 042, 045, 046, 048, 049, 050, 051, 054 (beyond the opt-out), 055, 060, 061, 063, 064, 065, 066, 070, 071, 072, 074, 075, 076, 077, 079, 085 — the diff touches no ACP launch, MCP injection, chat, KB, collaboration, UI, DB, credits, docs store, distribution or report-origin code. ADR-020/004: no global Kiro config was touched.

Lessons
- [OK] L-006 / L-013 — every adopted workflow has a `topology_gaps(app, yml["graph"]) == []` test (two hits per test file, all 16). `graph:` stays YAML-only.
- [OK] L-020 — `execution.recursion_limit` is kept where it was set; retries are still keyed by node name (`exhausted()` seeds `retries[agent]`).
- [OK] L-022 — no changed graph.py gained `from __future__ import annotations`. code-review (the only file with `Annotated[` keys) still has none.
- [OK] L-057 — the pins move at 55-12 (spec §4); nothing is pinned to v0.84.0 yet, which is correct for local commits.
- [OK] L-065 — every stop path ends `failed`: `escalate_stop` sets it (`escalation.py:336-338`). Cleanup nodes set no `status`, and story-verification's `present` keeps `failed` (`graph.py:1226`, `test_present_keeps_a_failed_status_and_a_done_one`). Core test: `test_stop_to_runs_the_cleanup_and_the_run_still_ends_failed_with_the_reason`.
- [OK] L-092 — no `tests/__init__.py`; 668 = one collection run.
- [OK] L-094 — consumers of the changed outcomes were read: StageFinalizer, StoryDesignFinalizer and StoryImplementationFinalizer act on `done` only (`stage_finalizer.py:99`, `story_design_finalizer.py:116`, `story_implementation_finalizer.py:118`); StoryVerificationFinalizer handles failed (`:184`); Capture/ComposeFinalizer fail the capture on a failed run (`capture_finalizer.py:174-199`) and keep a `not-run` replay as Draft.
- [OK] L-106 — every workflow's `_escalate_prompt` is built from `FROM_KEY` and the state, and each prompt variant has a route test per action: action → route → stored outcome → run status (e.g. story-verification `test_every_prompt_variant_names_what_each_answer_does`, the `answer_gate` tests in all 16).
- [OK] L-107 — a stop leaves no capture or verification non-terminal (the finalizers above).
- [OK] L-109 — cleanups read `set(META["artifacts"])` (the map's keys, exact names). Globs are declared only where no root-deleting cleanup exists (ux `pages/*`, code-review `obj/*`, action-capture/setup-composer `proposed/**`, `report/**`). `cleanup_losses` tests in the five workflows with a cleanup prove every declared file is kept.
- [OK] L-110 — gates verified by what ran here (table above).
- [VIOLATION — minor, m2] L-112 — the CI-image run covered the library and genesis-core fully but only 5 genesis suites (92 tests), not the 2387-test suite.
- [OK] L-120 / L-121 — no handler or side worker changed.
- [OK] L-122 — no new event kind.
- [N/A] L-001, 002, 003, 004, 005, 008, 009, 016, 017, 018, 021, 023, 024, 025, 026, 027, 029, 030, 033, 041, 042, 044, 045, 049, 050, 051, 053, 056, 058, 059, 060, 061, 062, 064, 066, 069, 072, 074, 075, 076, 081, 083, 085, 087, 088, 089, 090, 091, 093, 095, 096, 097, 098, 099, 100, 101, 103, 104, 105, 108, 111, 113, 114, 115, 116, 117, 119, 123, 124, 125 — no SDK/ACP, SSE, DB, credit, release, web, Hub, KB, skill front matter, reap or report-scrub code in the diff. L-026: no new blocking DB write in an async node. L-056: release-time only.

D-decisions
- [OK] D4 / D18 — `memory_brief: false` on both memory workflows, schema-accepted.
- [OK] D6 / D21 — one gate per workflow; `stop_to="cleanup"` on story-implementation, story-verification, story-design, technical-design, feature-breakdown and test-design. Workflows without a cleanup node have no `stop_to`.
- [OK] D8 / F11 — role map in all 19; schema accepts it and rejects a bad role (`validate_library.py:79-84`).
- [OK] D23 — every workflow declares `relaunchable`. erd-generation is `false` against the spec's starting list (judged below); the As built must record it.
- [OK] D26 — `check_required_mcp` runs in `validate_library` and `genesis test-workflow`, with negative tests.
- [OK] D19 — I compared the 68 memory texts in `~/.genesis/memory.db` (read-only) with both diffs and both commit messages: **0 hits**.

## Choices the spec left open (judged)

- **story-implementation, the reverify gap as a registered target**: sound. A gap gives retry → `reverify_design`, accept / PROCEED_ANYWAY → `prepare_rollback`, SEND_BACK → `present_sendback`. A bare `reject` now stops (cleanup → failed) where it used to send back. That is still fail-safe (no writes) and matches the D21 "unknown answer stops" ruling. The finalizer acts on `done` only, so a stopped run leaves the card in Implementation. Accept and PROCEED_ANYWAY both lead to the same writes; that is accepted because old clients answer with the bare option string.
- **story-verification, both gates merged**: sound. The registered targets `open_sessions` / `decide` accept to `accept_as_passed` → propose. Re-registering `propose` with `output=None` keeps Accept available after a pass, and `propose.accepted_unverified` drops the proposals (`_proposals_kept`). `_decide` maps blocked → accepted after a ladder accept, so the run never loops back to the gate. A product defect still wins. `proposals.json` as a second output is right: the Proposals review reads it.
- **code-review**: sound. `verdict_gate` became an approval gate reached by `set_verdict`; skip/abort are offered only for `review_object`. `_next_object` clearing `object_review.md` stops Accept from recording the previous object's text (`test_a_stale_object_scratch_is_cleared_when_the_next_object_starts`).
- **story-design-analysis `verify_route` + `verify.accepted_unverified` → present**: sound. The flag is only reachable right before `verify_route`.
- **test-design-analysis without `attach_healing(artifact=)`**: accepted. The ladder is reached only after `verify` has read the assembled deliverable, so Accept without a file check is not a real risk. See n3 for the role label.
- **action-capture / setup-composer without `stop_to`**: the claim holds on the gate path. Both replays remove `.auth` before they return (`action-capture/graph.py:995`; setup-composer in a `finally`, `:818-824`), and the gate is raised only after the replay node has returned. The processes are in `.pids` for the platform's reap. action-capture still lacks the `finally` that setup-composer got in 51 review m-2: if `runner.run` raises, the run fails with `.auth` left in the checkout (a System path, not served). That is pre-existing; I suggest a backlog line.
- **erd-generation `relaunchable: false`**: agree. A rerun without `document_id` publishes a second Lucidchart diagram, and the hint says how to update instead.
- **memory workflows losing "approve with no output = skip this pass"**: consistent with the spec table, but see m4.
- **globs only where no root-deleting cleanup exists**: correct, and proven by `cleanup_losses`, which reports any glob it is given.
- **registry erd-generation 1.0.0 → 1.2.0**: right. The drift shows the catalog gate does not compare versions (m3).

## Findings

### Blockers
none

### Majors
- M1 **The spec-required healing history assertion is missing** (spec §1: "Add a healing-wrapped history assertion (55-06 review n3)").
  - What: the 55-06 n3 fix is in place: `RunManager._gate_history` adds the critic's `(summary)` to the verify line (`genesis/runs/manager.py:1012-1014`) and writes "Heal N: …" and "Restart N: …" lines (`:1015-1023`).
  - Problem: no test pins them. The only history assertion is `tests/test_run_actions.py:211-213`, which covers retry lines only. A grep of both repos' tests for "Heal 1", "Restart 1", `kind == "verify"` and `heal.applied` finds nothing. If the `(summary)` suffix is dropped again (as happened between 55-06 rounds), every gate still passes.
  - Fix: one test in `tests/test_run_actions.py` (or the harness suite). Drive a healing-wrapped fixture, or log `verify.result {ok: false, summary: "3 fixes (sections 4, 6, 7)"}`, then `heal.applied {patch_count: 2}` and `workflow.restart` before a `gate.awaiting`. Assert `history` kinds `[verify, heal, verify, restart, …]`, the verify text ending in `(3 fixes (sections 4, 6, 7))`, and "Heal 1: patch 2 items in place…".
  - If skipped: the escalation history (the mockup's main evidence line) can regress silently.

### Minors
- m1 **Pre-existing (55-08): `test_the_file_routes_refuse_system_paths` fails on a case-sensitive filesystem** (`tests/test_phase55_api.py:427`).
  - What: the test expects 403 for `_KIRO/settings/cli.json`. On Linux that path is not a file, so the route answers 404 first (`run_routes.py:324-325`).
  - Problem: genesis CI (Linux) goes red at the 55-12 tag.
  - Fix: test only. Move `_KIRO/…` out of `refused`, then assert `client.get(...).status_code == (403 if (root / "_KIRO/settings/cli.json").is_file() else 404)` and that `"secret" not in res.text`, for both suffixes. `test_is_system_path` already covers the case folding.
  - How to carry it: a separate `fix(55-08)` genesis commit before 55-11's acceptance build. Record it in 55-10's As built ("pre-existing, outside this diff") and in 55-12's pre-tag checklist, so the L-112 CI-image re-run proves it.
- m2 **The CI-image run did not run the full genesis suite** (`/tmp/colima/gr-55-10/run.sh`, "genesis touched suites").
  - Problem: "one genesis failure" covers 92 of 2387 tests. Phase 55 has 41 local genesis commits, and other Linux-only assumptions like m1 would show only at the tag (L-112).
  - Fix: after m1, run `pytest -q` for the whole genesis suite once in the same `python:3.13` image and record the count in the As built. It can be 55-11's or 55-12's step, but name the owner.
- m3 **The catalog gate compares ids only** (`ci/validate_library.py:141-144`).
  - Problem: registry.json's `erd-generation` sat at 1.0.0 while META said 1.1.0, and the gate passed. This sub-spec bumps 19 versions by hand, so the next drift will pass the same way.
  - Fix: in step 5, also compare each entry's `version` (and `name`, `required_mcp`, `required_cli`) with its `workflow.yaml`, plus one known-bad case like the schema check. I checked by script that all 19 match today.
- m4 **A memory job can no longer skip a window with no usable output** (`memory-consolidation/graph.py:481`, `memory-maintenance/graph.py:451`).
  - Case: the extract agent writes no `memories.json` (for example, it times out on a large window) and exhausts its retries. Accept is refused, and Stop fails the run without moving the cursor. The next scheduled run reads the same window, fails the same way, and the schedule auto-pauses (ADR-087). The old gate's approve skipped the pass.
  - The escape exists (55-09 Fix then accept with `{"memories": []}`), but the prompt only says "Accept is not offered".
  - Fix: when the output is missing, add one sentence to the prompt: "To skip this window, use Fix then accept with an empty result ({"memories": []} / {"operations": []})". No route change is needed.

### Nits
- n1 `escalation.py:265`: `if prompt: pass` followed by `elif …`. Use `if not prompt:` with the default-wording chain nested under it.
- n2 `registry.json`: nine `summary`/`name` strings changed from `\u2014` / `\u2192` escapes to literal characters. This is harmless churn unrelated to the change; keep it or revert it, but write the file the same way each time.
- n3 test-design-analysis: in top-up mode the deliverable `topup.html` is labelled `intermediate`, because the role map is static and the binding test requires `outputs == ["test-design.html"]`. A top-up run's Documents tab therefore shows no output. Record this in the As built as a known limit, or accept a per-mode role later.

## Not checked
- The 55-10 **As built** is not written yet. It must record the D23 confirmations per workflow (including the erd-generation deviation), the open choices above, m1 as pre-existing, and the CI-image scope.
- A live run of any adopted workflow, and one adopted plus one legacy run in Resolve: out of scope here (55-11 live acceptance; no fleet restart, no Appian or credit runs, per the brief).
- The genesis CI-image re-run (colima is not running; m2).

## Verdict: NEEDS_CHANGES

Fix M1 (the healing history test). Fix m1 in a separate 55-08 commit, or record it with an owner before the 55-12 tag. m2–m4 and the nits may be fixed now or recorded in the As built. A re-review after M1 needs only the new test, `pytest tests/test_run_actions.py`, and the As built.

---

## Re-run 1 — genesis 6185c905 → 75d89b00, genesis-workflows 60c12f3 → 1d3b9ea (genesis-review, 2026-11-24)

New commits: genesis `4b54b737` (M1, n1) and `75d89b00` (m1, test only); genesis-workflows `1d3b9ea` (m3, m4, n2).
Both trees are clean and the commits are local only.

### Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `pytest -q tests/test_run_actions.py tests/test_phase55_api.py tests/test_lint.py tests/test_gate_harness.py` (`GENESIS_STATE_DIR=/tmp/rv-55-10r1/state`) | **85 passed** in 56.7 s |
| genesis `ruff check genesis tests/test_run_actions.py tests/test_phase55_api.py` | All checks passed |
| genesis-core `pytest -q` / `ruff check genesis_core` | **157 passed** / All checks passed |
| genesis-workflows `ci/validate_library.py` | `LIBRARY VALIDATION PASSED (19 workflow(s) validated)` |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **672 passed** in 39.9 s |
| CI image `/tmp/colima/gr-55-10b/ci-image.txt` (dev's run; `run.sh` archives genesis `75d89b00` + workflows `1d3b9ea`, full genesis `pytest -q`) | library 672, genesis-core 157, genesis **2331 passed, 58 skipped, 3 failed** (judged under m2 below). I did not re-run it (colima is stopped). |

### Round-1 findings

- **M1: fixed.** `tests/test_run_actions.py::test_a_healing_escalation_history_lists_each_verify_round_heal_and_restart_in_order`
  drives the `HEALWF` fixture (`attach_healing` with a critic that never confirms: patch, then restart) through a real
  subprocess worker to the standard gate. It asserts the exact `history` list: three verify lines, each ending in
  `(3 fixes (sections 4, 6, 7))`, plus "Heal 1: patch 1 items in place, then re-assemble" and "Restart 1: the whole run
  again from the start, with the critic's guidance", in order. It also asserts `at` on each entry, `ok is False` on the
  verify entries, Accept available (the assembled `design.html` exists), and that Stop ends the run failed. The text is
  matched exactly, so dropping the summary suffix in `RunManager._gate_history` fails it. I did not repeat the dev's
  mutation, because writes to the code tree are denied to me. The test passed in the 85 above.
- **m1: fixed** (`75d89b00`, test only). `_KIRO/settings/cli.json` moved out of `refused`. The test now expects 403
  where the name resolves to the real file and 404 otherwise, asserts "secret" is absent for both suffixes, and leaves
  the name rule to `test_is_system_path`. It is green on macOS here and was not among the three CI-image failures.
- **m2: done, judged below.** The full genesis suite ran in the image at `75d89b00`.
- **m3: fixed.** In `ci/validate_library.py` step 5, `_catalog_drift` compares `version`, `name`, `required_mcp` and
  `required_cli` for every registry entry against its `workflow.yaml`, and a known-bad pair (1.0.0 vs 1.1.0) must be
  flagged or the gate fails. The gate passes on all 19 today.
- **m4: the fix names a route that the same gate refuses. New major M2 below.**
- **n1: fixed** (`escalation.py:265-270`, `if not prompt:` with the default chain nested under it; core 157 green).
- **n2: fixed.** `git diff --no-index` of `registry.json` at base `9066541` against the new file: 19 insertions, 19
  deletions, and every changed line is a `"version"` line. The `\u2014` / `\u2192` escapes are back.
- **n3: recorded** (As built decision 6 and the For 55-11+ backlog line). Accepted as a known limit.

### Findings

#### Blockers
none

#### Majors
- M2 **The memory jobs' escalation prompt tells the user to use Fix then accept exactly when the gate refuses it**
  (`memory-consolidation/graph.py:480-489`, `memory-maintenance/graph.py:451-460`; L-106).
  - Case: the extract agent writes no `memories.json` and exhausts its retries. The prompt adds its new sentence only
    when `usable` is false. But `EscalationGate.allowed` (`escalation.py:234-238`) gives `fix_accept` the same reason as
    `accept` whenever the failed node's output is missing or empty (`_output_reason`, `:219-232`). Separately,
    `RunManager.fix_and_accept` refuses a target that is not an existing run file (`manager.py:1157-1158`, plus the
    `allowed.fix_accept` check at `:1149-1151`). Reviewer probe `/tmp/rv-55-10r1/probe_m4.py` builds the real gate as
    `attach_reliability` registers it (`reliability.py:92-94`), with `artifacts: {}`:
    ```
    memory-consolidation allowed: {'retry': None, 'accept': 'memories.json was not produced: …', 'fix_accept': 'memories.json was not produced: …', 'stop': None}
    memory-consolidation prompt: … Accept is not offered (no usable output was written) — to skip this window, use Fix then accept with the empty result {"memories": []} in memories.json; …
    ```
    memory-maintenance shows the same for `curate` / `operations.json`. So the payload names an action and refuses it
    in the same breath. The scheduled job is still stuck at Stop → the same window → auto-pause (ADR-087).
  - Why the tests missed it: the new tests call `_prompt_escalate` / `_escalate_prompt` directly and check that
    `{"memories": []}` passes `check_extract`. They never ask the gate whether the named action is available. My round-1
    m4 text was wrong too: it claimed "the escape exists (55-09 Fix then accept)" without checking `allowed`. The dev
    followed my wording, and I own that error.
  - Smallest fix, either of:
    (a) Name an action that is available. Retry is always available, so the sentence could read: "to skip this
    window, Retry with the guidance: write `{"memories": []}` to memories.json". This costs one agent turn.
    (b) Add an `ExtraOption("skip", to=<a program node that writes the step's empty result>)`, available only when the
    output is missing or empty, whose successor is the agent's `nxt`. This costs no credits and also covers an empty
    file.
    Either way, change the test to read the real gate's `payload()` (as the probe does) and assert that the action the
    prompt names has `allowed[...] is None`. Then correct As built decision 10, the Tests bullet and the 55-12
    release-note line ("the memory skip route").
  - If skipped: a scheduled memory job's only recovery text points at a disabled button, against L-106. The release
    notes would also advertise a route that does not work.

#### Minors
- m5 **The CI-image failure in `test_document_records` is called a flake, but its mechanism is not shown.**
  - What: the image logged only `pytest -q | tail -6`, and `one.sh`'s 2/2 re-run output was not saved, so no assertion
    message exists anywhere.
  - Problem: the test asserts that `draft.html` is recorded twice (`tests/test_document_records.py:324`). The worker's
    change snapshot keys on `(st_size, st_mtime_ns)` (`genesis/runs/writes.py:87`). If a same-size rewrite lands within
    one kernel timestamp tick on the image's Linux filesystem, the second write would not be seen, and that would be a
    real recording gap. "Passed on a re-run" does not rule this out (L-110).
  - Judgement for 55-10: acceptable to carry. 55-10 changes nothing under `genesis/runs/` and does not touch the test
    (`git diff --stat a09c5fbe 75d89b00 -- genesis/runs tests/test_document_records.py` is empty).
  - Required for 55-12: the As built line "treat as a known flake only if it passes on a re-run" is not enough. 55-12
    must capture the failing assertion (`pytest -q … -x` with the `E ` lines kept) at the release commit, and either
    name a timing mechanism in the test or open a 55-05 follow-up if it is the same-size, same-tick case. Record the
    owner in the 55-12 sub-spec.

#### Nits
- n4 `test_phase55_api.py`: the upper-case branch dropped the `"System file" in detail` check for the 403 case. Add it
  back where `want == 403`. Optional.

### As built (read)

The per-workflow table, the D23 confirmations, decisions 1–9 and 11–13, Live effect, the lesson candidates, the
code-map list and For 55-11+ match the code and round 1's judgements. Spot checks: erd-generation 1.2.0 `false` with
its hint; test-design `no artifact=`; story-implementation `reject` now stops; the scratch dirs are listed for deletion.
Decision 10, the Tests bullet "the memory skip route's empty results pass their checks" and the 55-12 release-note item
describe the route M2 shows to be unavailable, so they must change with M2. The m2 paragraph should also carry m5's
point: the failure message was not captured.

### Not checked
- I did not repeat the M1 mutation (dropping the summary suffix) or the m3 mutation (erd-generation's registry version
  back to 1.0.0), because the code tree is read-only to me. I judged them from the exact-match assertions and from
  `_catalog_drift` being called per entry plus its self-check.
- The CI-image run itself; colima is stopped.
- Live runs: out of scope (55-11), with no fleet restart, no Appian and no credits.

### Verdict: NEEDS_CHANGES

Fix M2: either name an available action or add a `skip` extra, test it through the real gate payload, and correct
decision 10 and the 55-12 note. Record m5's requirement in 55-12. Everything else from round 1 is resolved. A
re-review needs only the two memory workflows' diff, their tests, `validate_library`, the library pytest and the
corrected As built lines.

---

## Re-run 2 (2026-11-24)

Scope as set at re-run 1: the two memory workflows' diff and tests, `validate_library`, the library pytest and the
corrected As built lines. Commits: genesis-workflows `1d3b9ea..4bc7168` (M2), genesis `75d89b00..361c99a6` (n4, test
only). Both trees clean. `genesis-ctx check --since 1d3b9ea` on genesis-workflows: 6 files, areas release-ci + security
(always-on), no area gates.

### Gates (re-run by the reviewer, `GENESIS_STATE_DIR=/tmp/rv-55-10r2/state`)

| Gate | Result |
|---|---|
| genesis-workflows `ci/validate_library.py` | `LIBRARY VALIDATION PASSED (19 workflow(s) validated)` |
| genesis-workflows `pytest -q workflows/memory-consolidation workflows/memory-maintenance` | **48 passed** |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **678 passed** in 40.2 s |
| `ruff check` on both `graph.py` | clean. The two test folders show one F841 (`res1`, `memory-consolidation/tests/test_workflow.py:167`) from `8cb06e32` (2026-08-20), pre-existing; the library CI runs no ruff |
| genesis `pytest -q tests/test_phase55_api.py -k refuse_system_paths` + `ruff check tests/test_phase55_api.py` | 1 passed / All checks passed |

### M2: fixed

- **The route exists and is the one the prompt names.** Both graphs register
  `ExtraOption("skip", to=advance_cursor | recompute_communities, available=_skip_available)`
  (`memory-consolidation/graph.py:533-536`, `memory-maintenance/graph.py:490-493`). `_failed_output_usable` applies the
  gate's own rule (`escalation.py:220-232`: the failed target's output in `artifacts`, a file, size > 0) to the same
  file name, and `test_one_shared_gate_*` asserts that `_AGENT_OUTPUT` and `gate.targets[*].output` agree. The prompt
  names Skip only when the output is not usable and drops "Fix then accept". `_EMPTY_RESULT` is gone from both files.
- **The tests read the real gate.** `test_without_a_usable_output_the_prompt_names_skip_and_the_gate_offers_it`
  (2 params per workflow) raises the compiled graph's gate through `answer_gate`. It asserts the payload prompt names
  Skip, `allowed["skip"] is None` while `accept` and `fix_accept` carry reasons, and that the answer routes straight to
  the program node. `test_with_a_usable_output_skip_is_refused_and_accept_is_offered` checks the other side.
  `test_skip_ends_the_window_done_*` / `test_skip_runs_the_program_upkeep_to_done_*` run on to `done`, with no `apply`.
  The consolidation one uses migrated DBs and asserts no memories; the maintenance one asserts `report.json`.
- **Mutation confirmed.** I copied both folders to `/tmp/rv-55-10r2/wf` and made `_skip_available` always return None.
  Exactly the two `test_with_a_usable_output_*` params fail in each workflow (`AttributeError: 'NoneType' object has no
  attribute 'startswith'`). The scratch copy also has 5 / 4 harness-run failures that are independent of the mutation:
  they occur in the unmutated copy too and come from running outside the library tree. In the real tree all 48 pass.
- **The platform enforces it.** The gate node routes any extra id it is given (`EscalationGate.apply`, `:309-311`), so
  refusal is the platform's job. `RunManager._check_answer` (`manager.py:663-665`) refuses any action whose `allowed`
  value is a reason, extras included. I probed it with the real payloads
  (`test_rv_platform_refuses_skip_when_output_usable` in the scratch copy). With a usable `memories.json`, `skip` raises
  `GateResponseError: 'skip' is not available: Only when the step wrote no usable output (use Accept)`. Without the
  file, `skip` passes and `accept` is refused. `fix_accept` is refused as a run operation, and `fix_and_accept` has its
  own `allowed.fix_accept` check (re-run 1).
- **The cursor does move. The shipped test does not show it** (see m6). A reviewer probe seeded the window's
  `last_session`, which `_resolve_window` sets before any agent runs (`graph.py:252`), then answered `skip` from
  `v_extract` and from `v_reconcile`. Both runs reached `done` with `cursor_advanced: True`.
  `MemoryStore.consolidation_cursor()` returned `last_processed_session_id: 'sess-9'` with the seeded `created_at`, and
  no memories were written.
- **yaml:** the `escalate → advance_cursor` / `escalate → recompute_communities` `skip` edges are present, and
  `topology_gaps == []` passes in both.

### n4: fixed

`361c99a6` puts the "System file" detail check back for the 403 case only (`test_phase55_api.py:441`). It passes here.

### Checklist (re-run 2 diff)

- ADR-011 **OK**: both agents keep validator + retry + the one gate. `validate_library` step 3's reliability lint passes
  on 19.
- ADR-021 **OK**: skip is an escalation-gate answer that routes to program nodes. No new write/MCP node, so no
  pre_mutation is needed.
- ADR-087 **OK**: this removes the stuck-schedule loop (Stop → the same window → auto-pause), because a scheduled job
  now has a credit-free way past a bad window.
- ADR-019 **OK**: no genesis-core change in this re-run, so `CORE_MAJOR` stays 1.
- L-106 (not listed by the check; it is the rule behind M2) **OK**: the prompt is built from the same state that decides
  `allowed`, and the tests assert that the named action is open.
- L-092 **OK**: no `tests/__init__.py` in either folder, and 678 = the folder sum.
- L-110 **OK**: the claims rest on the gates I re-ran and on my own mutation run.
- L-057, L-056, L-112 **N/A** here: no tag and no pins. The library at `4bc7168` has not been run in the CI image, and
  As built says so. 55-12 owns that run.
- ADR-026, 028, 029, 031–034, 045–047, 049, 061–063, 065, 068, 069, 074, 076, 077, 080–086; L-017, 025, 027, 030, 044,
  045, 051, 087–089, 098–101, 104, 105, 111, 113, 116, 117, 119, 125 **N/A**. The diff touches two memory workflows'
  graph, yaml and tests, plus one genesis test line. It has no chat, web, API, trust, MCP, browser, release or DB
  surface.

### As built (read)

All the corrections are present and match the code: the commits table (`361c99a6`, `4bc7168`, and `1d3b9ea` marked
superseded for m4), decision 10, the Tests bullet, the m5 paragraph ("not proven a flake", the `(st_size, st_mtime_ns)`
mechanism, owner 55-12), Review, and the 55-12 items (capture the `E ` lines with `-x`; release note "memory jobs'
Skip"). The mutation claim "fails 2 tests" holds per workflow.

### Findings

#### Blockers
none

#### Majors
none

#### Minors
- m6 **The consolidation skip test does not assert the behaviour decision 10 promises: "the cursor moves on".**
  (`memory-consolidation/tests/test_workflow.py`, `test_skip_ends_the_window_done_through_the_empty_day_path_writing_nothing`)
  - What: the seeded state has no `decisions.last_session`, so `_advance_cursor_sync` takes its "nothing to process"
    branch (only `last_run_at`, `cursor_advanced: False`). The assertion `run.values["cursor"] == "present"` checks the
    graph's node pointer, not the consolidation cursor.
  - Problem: the store cursor moving past the window is the property that stops a scheduled job meeting the same window
    every night. Today nothing fails if a later change makes skip skip `advance_cursor` or drop `last_session`.
    The code is right: the reviewer probe above shows `last_processed_session_id` moves on from both agents.
  - Fix: add `"last_session": {"id": "s-1", "created_at": "…"}` to the seeded decisions, then assert
    `run.values["decisions"]["cursor_advanced"] is True` and
    `MemoryStore(...).consolidation_cursor()["last_processed_session_id"] == "s-1"`. This can ride with the next library
    commit (55-11 or 55-12) and does not block.

#### Nits
- n5 For a later phase, outside this sub-spec: no genesis test covers `RunManager._check_answer` refusing an
  *extra* option whose `allowed` value is a reason. Today only `accept` is tested (`test_run_actions.py:347`,
  `test_phase55_api.py:170`). Every `available=` extra (memory skip, story-implementation's gap extras) depends on that
  line. One parametrized case in `test_run_actions.py` would cover it.

### Not checked
- The library at `4bc7168` in the CI image (colima stopped). As built records this, and 55-12 owns the run.
- The maintenance skip with real memory rows. Its test asserts `done` + `report.json` + no `apply`, and I read
  `recompute_communities` / `decay_forget` / `embed_new` as not reading the agent passes' decisions. I did not seed a
  populated memory.db.
- The UI rendering of the `skip` extra's label and hint (55-09 Resolve tab, 55-11 live).
- Live runs: out of scope. No fleet restart, no Appian, no credits.

### Verdict: SHIP

M2 and n4 are fixed and verified through the real compiled gate, the platform's answer check, and a reviewer mutation
and probe. The gates are green: validate_library 19, library 678, memory 48. m5 stays recorded for 55-12. m6 and n5 are
non-blocking follow-ups for the next library or genesis commit.
