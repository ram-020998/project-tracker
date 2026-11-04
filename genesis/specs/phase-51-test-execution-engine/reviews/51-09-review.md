# Review 51-09 — base genesis d701ea9 · genesis-workflows 966c022 (genesis-review, 2026-11-03, first pass)

Scope: the UNCOMMITTED working trees. genesis: 16 modified + 5 untracked files (`git status --short`); genesis-workflows:
`registry.json` + untracked `workflows/story-verification/`. Both bases resolve (`d701ea9` = 51-08, `966c022` = 51-07).
Read: the diff and the new files, sub-spec 51-09, 51-01 D6/D7/D8/D22/D24, ADR-021/050/061/068 full text.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1651 passed** (443.9 s) |
| genesis `.venv/bin/ruff check genesis` | All checks passed |
| `packages/kiro-agent-sdk` pytest | 79 passed |
| web `npx tsc --noEmit` | clean |
| web `npx eslint .` | 0 errors (20 warnings, all pre-existing files) |
| web `npx vitest run` | 467 passed (50 files) |
| stale bundle: `npx vite build --outDir /tmp/51-09-static` + `diff -r /tmp/51-09-static static` | identical |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (17 workflows; reliability lint, parity) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **355 passed** |
| ruff on `workflows/story-verification` | All checks passed |

The author's claims hold.

## Checklist

### ADRs
- [OK] ADR-001: control flow is the LangGraph graph (`graph.py` `build`, conditional edges); agents only write artifacts.
- [OK] ADR-002/004/020: no MCP (`required_mcp: []`); agents are ordinary `kiro_node` turns; no global config written. D3d (global Kiro MCP servers load anyway) is the accepted Phase-51 risk (ADR-083, 51-13).
- [N/A] ADR-003, 005, 007, 013–017, 023, 026, 029, 034, 035, 037, 039, 041–049, 051–055, 057–060, 063–065, 070, 072–076, 080: not touched by this diff (no MCP/CLI registry, auth/bind, chat, KB, documents, Hub contract, packaging change).
- [OK] ADR-006: self-contained folder (`workflow.yaml` + `graph.py` + `__init__.py` + tests) plus a `registry.json` entry.
- [OK] ADR-010/018/022: state holds pointers and small decisions (`decisions.sessions` are names/prefixes; errors capped at 500 chars); bulk lives in the run folder (`plan.json`, `results.json`, report).
- [OK] ADR-011: explore/author/propose wear `attach_reliability` (validator + retry 2 + `escalate`); triage/heal wear the trio through `attach_healing` (`verify_check`/`heal_check`, gate `escalate_blocked`). `validate_library` gate 3 and `test_meta_mirrors_the_yaml_and_every_agent_wears_the_trio` pass.
- [OK] ADR-012: `graph.py` imports only `genesis_core`/LangGraph; Genesis code is reached through `ctx.extras['apwt'].verification()` (`integrations/apwt/factory.py:77`). The app never imports the workflow.
- [OK] ADR-019: no core change; workflow needs no new core symbol beyond those 51-07 already uses.
- [OK, deviation approved] ADR-021: no `pre_mutation` gate though the run writes QA data. User decision D22 (2026-11-03); ADR-082 amends ADR-021 in 51-13. `test_meta_…` asserts `pre_mutation` is absent on purpose.
- [OK] ADR-009/025: gates are `interrupt()`-based `hitl_gate`s; nothing auto-answers them.
- [OK] ADR-024 / L-026: every blocking step (sign-ins, generate, tsc, `--list`, Playwright, cleanup) runs in `asyncio.to_thread` (`_open_sessions`, `_v_author`, `_execute`, `_reexecute`, `_cleanup`).
- [OK] ADR-027/055: web change is types and a test only; no UI.
- [OK] ADR-028 / L-010: new routes are on the `/api` router; the report URL is built server-side.
- [OK] ADR-030: SQLite through the existing stores; no migration (choice 4).
- [OK] ADR-031/033: chat untouched; gate answers are the human's.
- [OK] ADR-032: no credit figures added.
- [OK, mostly] ADR-050: the lane moves are the audited `verify`/`reject` edges through `build_story_lifecycle_service` (`story_verification_finalizer.py:264`); the direct `set_status` fallback (`:275`) copies the StoryImplementationFinalizer pattern. Stage status writes use `StoryStageStore.set_status` as the other story finalizers do.
- [OK] ADR-056/078/079: test cases/scenarios are read, not restructured; Ready-only scope.
- [OK, deviation approved] ADR-061: the lane order changes (Deployment before Verification), against the ADR's "Verification → Deployment". User decision D6 (2026-11-02); ADR-084 amends ADR-061 in 51-13. Lane values are unchanged, so stored statuses and Hub data need no migration.
- [OK] ADR-062: the drag-confirm → bound run → finalizer → audited edge pattern is reused.
- [OK] ADR-067: `attach_healing(... max_heal=1, max_restart=1)` from `META.healing`, gate on exhaustion.
- [OK, deviation approved] ADR-068 ("Implementation is the only env-mutating lane"): Verification writes QA application data through the UI only, as test users; no design objects and no MCP write tools. D8/D22; ADR-082 amends ADR-068 in 51-13.
- [OK] ADR-069: every `kiro_node` declares `skills=SKILLS`; the graph test asserts both SKILL.md files are provisioned into the run's `.kiro/skills/`.
- [OK] ADR-071: the Verification read and report hang off `/applications/{app}/stories/{id}/…`; no new story surface.
- [OK] ADR-077: no agent-system change.

### Lessons
- [OK] L-003/L-018: no SSE change.
- [OK] L-004: everything durable is in SQLite rows (execution, results, capture, stage); files are artifacts.
- [OK] L-006/L-013: `workflow.yaml` `graph:` node ids equal the compiled graph's nodes (asserted in `test_meta_…`).
- [OK] L-009/L-020: async nodes, checkpointer-compiled; `execution.recursion_limit: 200`.
- [OK] L-011: `web/src/types/workbench.ts` gains the four `verification_*` card fields and the new `Lane` order.
- [OK] L-017/L-041/L-045: no trust change; the author writes in the run's checkout. The shell is the D3c accepted risk.
- [OK] L-021/L-023: Playwright and apwt outputs are parsed defensively (`_load`, `normalize_report` copy, `list_tests` JSON slice).
- [OK] L-022: no custom reducer keys, so `from __future__ import annotations` is safe (stated in the docstring).
- [OK] L-024: skills arrive through the filesystem.
- [OK] L-025/L-027: ruff is the repo's pinned one.
- [N/A] L-001, L-007, L-016, L-019, L-028–L-032, L-034–L-040, L-043, L-044, L-046–L-055, L-063, L-068 (the report response sets `no-cache` anyway), L-069, L-071–L-075, L-077–L-082, L-084–L-087, L-089 (no commit yet), L-090, L-095–L-100.
- [OK] L-033: `check()` refuses `not_installed` via `RunManager._meta` (`test_start_refusals`).
- [OK] L-039: the board list and the single-card query both gained the same `sv`/`rv` join (`boards.py:150,343`).
- [OK] L-042: inputs are written as files (`inputs/story.json`, `cases.json`, …) and the prompts name the paths.
- [OK] L-056/L-057: nothing released yet; the release must stage the five untracked genesis files and the untracked workflow folder. Flagged for 51-13.
- [OK] L-058/L-061/L-062: live observer + startup `reconcile()` + on-read recovery (board and story view); the bound-run guard (`finalize_run`: `row.run_id == run_id`); start gates on the run lifecycle (`busy`).
- [OK] L-064/F10: `turn_timeout` 900 s on explore and author. The write-flow re-measure is deferred to 51-12 (choice 8); it must be recorded there.
- [OK] L-065: `present` sets `status: done`; the blocked-gate path pauses (`test_a_blocked_run_stops_at_the_blocked_gate`).
- [OK] L-066/L-067: no run-graph UI change.
- [OK] L-076: one `author` turn writes every script of the story, so the scripts stay consistent.
- [OK] L-083: tests use real shapes (`TS-`/`TC-` keys from the real stores, a real 1.59.1 report for parity).
- [OK] L-085: the finalizer calls `publish_board_move` after a move (opt-in).
- [OK] L-086: no agent HTML touched.
- [OK] L-088: the secret check covers the run's whole folder in the graph test (no password in any file, state, checkpoint or event), and `scrub_session_artifacts` has its own test. No new shell guard.
- [OK] L-091: decisions and apply use CAS (`set_decisions` row_version, `set_status(expected_status="ready")` inside the commit lock); the start's `busy` check is advisory, and the card move's CAS backs it.
- [OK] L-092: no `tests/__init__.py`; `StoryVerificationService.__test__ = False`.
- [OK] L-093: the finalizer tests drive the real `RunManager._finalize` (`RecordingRM` only records the spawn), and the stage is bound inside `prepare` before the spawn (`test_start_queues_…_bound_before_the_spawn`).
- [OK] L-094: `VALID_STAGES += verification`. Consumers checked: `run_states_for_feature` now filters to design + implementation (`story_stages.py:86`); `services/testimpact.py` reads the implementation stage by name; collab does not sync story stages; web `IMPL_LANES` is a set and `lanes.ts` holds labels only. The spec also asks the build to "list every hit in the As built", and that is not done yet (see m4).
- [OK] L-096: the new routes have distinct literal paths; no ordering conflict.

### Gates
- [OK] all of the gate commands above, run by the reviewer.

## The eight choices

1. **OK.** A `verification` TE row through `launchers[kind]` keeps one queue (F7); `BUSY_WORKFLOWS` already includes `story-verification`. `prepare` exports HEAD, restores the stored overlay, sets the TE running and binds the stage before the spawn, and the tests prove it.
2. **OK.** Running cleanup before render_report is required so the report can link the scrubbed session logs. Nothing reaches the story-stage dir before the scrub. Record the order change against the spec table in the As built.
3. **OK on routing, but there is one defect:** see M2. The escalate prompt offers choices that a passed run then ignores.
4. **OK as a deviation.** §5 says the defect list is "stored on the stage row". It now lives in `defects.json` in the stage dir plus `classification` on each result row, served by `view()`. The As built must record this.
5. **OK.** The apply test runs real tsc and scan-refs and asserts one commit, keys allocated, the case bound, the scenario setup set, a Draft regression scenario built from scripted case ids only, and a refused apply that commits nothing.
6. **OK.** `no_scenario` is a sensible refusal. Record it in the As built as an addition to §3's list.
7. **OK.** `test_normalize_parity_with_test_execution_on_the_real_report` keeps the copy equal.
8. **Accepted.** The live QA run and the F10 re-measure are 51-12's.

## Findings

### Blockers
None.

### Majors

- **M1. After a heal pass, the attachment links of every scenario that was not re-run point at moved files, so the product-defect evidence 404s.**
  `graph.py:833-841` `_run` renames the previous `<run>/report` to `report-pass<n>` before the re-execution. `merge_results` (`:409`) keeps the old entries of the scenarios that were not re-run, and their `attachments` are still relative to `report/`. The execution's `report_dir` stays `<run>/report` (`verification_service.py` `set_running`), and `execution_report_file` serves only that folder (`execution_service.py:324-337`). So both the verification report's screenshot links and the result rows' attachments for those scenarios now resolve to missing files.
  The realistic case: TS-A fails with a **product** defect, TS-B with a **script** defect. One heal re-runs TS-B, `decide` returns `failed`, and the card goes back to Implementation with the screenshots of the very defect it reports unreachable. No test covers it: the heal test ends with every scenario passed and no attachments.
  **Fix (author's choice):** after the re-run, copy each kept scenario's attachment files from `report-pass<n>/<rel>` into `report/<rel>` (Playwright `data/` names are content hashes, so they don't collide), or rewrite the kept entries' paths to a form the route serves. Add a graph test: one product failure with an attachment plus one healed script failure, then assert the merged `results.json` attachments exist under `<run>/report`.

- **M2. The `escalate` gate's answer is silently ignored when `propose` exhausts its retries on a passed or accepted run.**
  The gate prompt is static (`graph.py:1138`): "Send back moves the card to Implementation; Accept as passed moves it to Done; Stop leaves it in Verification." `_escalate_route` (`:1034-1039`) keeps `decision = passed` whatever the person picked, so a user who chooses **Send back** or **Stop** sees the card move to **Done**. The outcome is choice 3's intent, but the person is asked a question and their answer is then overridden without notice (ADR-009: designed gates are the human's decision). `test_gate_routes` asserts the override but not what the user is told.
  **Fix:** make the prompt depend on state. For example, when `decisions.decision ∈ {passed, accepted}`, say "The story passed; only the library proposals could not be produced. Continue moves the card to Done without proposals", and either offer options that match or honour `send_back`/`stop`. Add a test that the prompt matches the routing for the propose-exhausted case.

### Minors

- **m1. A verification whose launch fails (or is cancelled while queued) leaves the card in Verification with nothing on the story to say why.**
  `pump()` catches the launcher's exception and `_fail`s the TE row (`execution_service.py:219-224`); `_launch` itself `_fail`s on a launch-time readiness problem (`verification_service.py:197`). The card was already moved in `start()`, and the stage row is unbound: `reset_for_rerun` cleared the old run, and `set_source` runs only inside `prepare`. `view()` finds the execution only through `row.run_id` (`:255`) and `active()` only through queued/running rows. So the Verification section and the board show no run and no error. The startup sweep's "its run no longer exists" failure has the same effect.
  **Fix:** in `view()`, fall back to the newest `verification` execution whose `trigger.story_id` matches when the stage has no run, and surface its `totals.error`/`problems`. Add a test that queues behind a running execution, then makes readiness fail at launch.

- **m2. Spec §7 lists "healing bounds" tests; there is no test of healing exhaustion → `escalate_blocked`, of trio exhaustion → `escalate`, or of a failed sign-in reaching the blocked gate through the graph.**
  `attach_healing`'s bounds are tested in genesis-core, but this workflow's wiring (`gate="escalate_blocked"` at `graph.py:1167`, the `open_sessions` conditional edge) is only checked as routing functions. A graph test with a triage that keeps returning a script defect (patch, re-triage, restart, re-triage, gate) would pin it at low cost.

- **m3. Proposal apply is partial on post-commit errors.**
  After the commit, `_apply_regression` calls `_case_id` (`verification_service.py:415`), which raises `VerificationError` for an unknown `case_keys` entry. The library commit and the capture's `applied` status have already happened, yet the endpoint returns 400. `v_propose` keeps unknown keys out in practice, but the apply runs on stored data and should not rely on that. Report the bad key in the regression result's skipped list instead of raising, as `_apply_scenario_setups` already does.

- **m4. The As built is not written yet.** It must record:
  - the L-094 consumer list (§2 asks for every grep hit);
  - the deviations: defects in `defects.json` (choice 4), node order (choice 2), the `no_scenario` refusal (choice 6);
  - that `story_context` scopes to `status = 'ready'` cases only;
  - the F10 hand-off to 51-12;
  - the ADR-082/084 amendments owed by 51-13 (ADR-021, ADR-061, ADR-068 text).

### Nits
- **n1.** In apply, `cases.append({... "code": p.get("code")})` (`verification_service.py:336`) turns into the literal text `None` in `create_many` (`str(cs["code"])`) when the proposal has no embedded code: `complete_proposals` skips missing or >200 KB files. The typecheck then refuses it with an unclear TS error. Refuse such a proposal by name ("P3 has no code; re-run the verification").
- **n2.** `_launch` calls `_fail` and then raises, so `pump` logs the same failure a second time (its own `_fail` is a no-op). Raising alone is enough.
- **n3.** `heal` patches written by `reexecute` skip `v_author`'s secret and `lib/`/`suites/` checks. `apply_heal_patches` does keep them out of `lib/`/`suites/`, and the apply path re-checks the code. A healed library file that the overlay does not name is also not copied by `copy_overlay`, so a re-run does not resume it. Worth one line in the As built.

## Verdict: NEEDS_CHANGES

Fix **M1** (heal pass breaks the kept scenarios' attachment links; add the regression test) and **M2** (the escalate prompt must match what the routing does on a passed run; add a test). The minors should be fixed or answered in the As built; m2 and m4 are expected before SHIP. All gates are green and the design otherwise follows the spec, the approved D6/D8/D22/D24 decisions and the lessons.

---

# Re-review 51-09 (second pass): base genesis d701ea9 · genesis-workflows 966c022 (genesis-review, 2026-11-04)

Scope: the same UNCOMMITTED working trees. genesis: 16 modified + 5 untracked files (unchanged set); genesis-workflows:
`registry.json` + untracked `workflows/story-verification/`. Read: the fix sites in `graph.py` (`_run`,
`carry_attachments`, `_reexecute_sync`, `_escalate_prompt`, `_escalate_route`, `build`), `workflow.yaml:136`,
`verification_service.py` (`latest_execution`, `_launch`, `view`, `apply`, `_apply_regression`), the
`execution_service.py` diff, the new tests, and the sub-spec's As built.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1653 passed** (465.6 s) |
| genesis `.venv/bin/ruff check genesis` | All checks passed |
| web `npx tsc --noEmit` | clean |
| web `npx vitest run src/features/workbench` | 28 passed (web diff is still the same two files: `types/workbench.ts`, `workbench.test.tsx`; full vitest/eslint/bundle not re-run, first pass stands) |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (17) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **360 passed** |
| ruff on `workflows/story-verification` | All checks passed |

The author's gate claims hold.

## First-pass findings

- **M1: FIXED.** `_run` (`graph.py:833-851`) returns the archived `report-pass<n>`; `_reexecute_sync` (`:964-966`)
  calls `carry_attachments(results, set(rerun), previous, root / REPORT_DIR)` after `merge_results`.
  `carry_attachments` (`:854-873`) skips re-run scenarios, refuses absolute and `..` paths, and does not overwrite.
  A second heal pass also works: pass 2's archive already holds the carried copies, so they are carried again.
  `test_a_product_defect_keeps_its_evidence_after_a_heal_of_another_scenario` uses the `mix` npx mode (TS-000001 is
  a product failure with `shot-1.png`, TS-000002 a script failure healed by one patch). It asserts decision `failed`,
  one heal, and that every attachment of the product scenario is a file under `<run>/report`. Without the fix,
  pass 2 writes no screenshot for TS-000001, so the test would fail. It is a real regression test.
  `test_carry_attachments_…` covers the unit, including `../escape` and `previous=None`.
- **M2: FIXED.** `_escalate_prompt` (`:1059-1067`) states what each answer does when `decision ∈ {passed,
  accepted}`. `_escalate_route` (`:1070-1083`) always honours the choice: accept keeps `passed`, send_back gives
  `failed` with a "sent back at the gate" defect when there are none, stop or no answer gives `stopped`, and
  `proposals_refused` is set on a passed run. The gate's `prompt_fn(state, ctx)` signature matches
  `genesis_core/nodes/gate.py:31`. `test_gate_routes` asserts both prompts and all three answers on a passed run.
  The `workflow.yaml:136` description was updated.
- **m1: FIXED.** `view()` (`verification_service.py:270-274`) falls back to `latest_execution(story_id)`, which reads
  `ExecutionStore.list` (`ORDER BY id DESC`, `testexec_store.py:1045`) filtered by `trigger.story_id`. `pump` passes
  `getattr(e, "problems", None)` to `_fail` (`execution_service.py:224`), and `_fail` stores it in `totals.problems`.
  `test_a_launch_failure_shows_on_the_story_page_with_its_problems` queues behind a running ad-hoc execution and
  removes the password. It asserts the TE ends `error` with the "no password" problem, the story view shows it with
  `active is None`, and no verification run spawned.
- **m2: FIXED.** `test_healing_bounds_one_patch_one_restart_then_the_blocked_gate` (`heals_used == 1`,
  `restarts_used == 1`, a second author prompt carrying the guidance, paused with no result),
  `test_a_failed_sign_in_reaches_the_blocked_gate_without_agents` (no agent prompt, `blocked_at == "sessions"`,
  Retry routes to `retry_sessions`) and `test_an_exploration_refused_three_times_escalates` (3 explore turns, no
  author turn, paused).
- **m3: FIXED.** `_apply_regression` (`:430-436`) catches `VerificationError` from `_case_id` and lists it in
  `skipped_proposals`. The apply test asserts the TC-999999 entry and the capture `applied`.
- **m4: FIXED.** The As built has the L-094 consumer list (lane order and `VALID_STAGES`, backend and web, plus the
  collab grep). It also records decisions 2 (node order), 4 (`defects.json`), 6 (`no_scenario`), 7 (Ready-only
  scope) and 9 (n3), the F10 re-measure as 51-12's under "Not run", and the ADR-082/084 debt for 51-13.
- **n1: FIXED.** `apply` refuses an `action`/`setup`/`case` proposal with no string `code` by id
  (`verification_service.py:330-332`) before `create_many`. Tested ("P3 has no code"; the capture is still `ready`).
- **n2: FIXED.** `_launch` raises `VerificationError(problems=…)` only (`:206-207`), and `pump` records it once.
- **n3: ANSWERED** in decision 9.

## Checklist delta

Everything in the first-pass checklist still holds; the fixes touch no new ADR or lesson area. Re-checked:
ADR-009 (the gate's answer is now always the human's: OK), ADR-011 (`validate_library` gate 3 green: OK), ADR-012
(`carry_attachments` is pure stdlib in `graph.py`: OK), L-093 (the m1 test drives the real `RunManager._finalize`:
OK), L-094 (consumer list now in the As built: OK), L-056 (still uncommitted; the commit must stage the five untracked
genesis files and the untracked workflow folder: flagged again for the dev commit and 51-13).

## New findings

### Blockers / Majors / Minors
None.

### Nits
- **n4.** `test_healing_bounds_…` accepts `cursor in ("heal_route", "escalate_blocked")` and only checks "not done".
  The bound counters pin the behaviour, but an assertion that the pending interrupt is `escalate_blocked` (the gate
  descriptor's `node`) would also pin the wiring m2 asked about. The same applies to the sign-in and explore tests
  (`escalate`).
- **n5.** n1's refusal happens after `apply` has stored the decisions through `decide()` (CAS). So the capture's
  `row_version` moves even though nothing is committed, and the test re-reads it. That is harmless, but "refused
  before anything is written" applies to the library only. 51-10/51-11 must refetch the capture after a 400 before
  retrying.
- **n6.** The F10 write-flow re-measure of the 900 s bounds is recorded as 51-12's only in this As built. The 51-12
  sub-spec §7 says "healing bounds (F10)" but does not name the turn-timeout re-measure. Ask genesis-spec/docs to add
  that line to 51-12 so it is not lost.

## Verdict: SHIP

Both majors are fixed and each has a regression test that fails without its fix. Every minor and nit from the first
pass is fixed or recorded. All gates are green on the reviewer's re-run (genesis 1653, genesis-workflows 360 +
`validate_library` 17, ruff clean). The new nits n4–n6 are optional. Live acceptance (a real QA verification and the
F10 re-measure) remains 51-12's.
