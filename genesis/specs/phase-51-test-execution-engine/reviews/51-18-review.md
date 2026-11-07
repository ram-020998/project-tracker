# Review 51-18 — the 51-12 re-run fixes (genesis-review, 2026-11-08)

Bases: genesis `2b2cf9d`, genesis-workflows `69bface`, playwright-appian `5d7ae2d`.
Heads reviewed (local, unpushed, all resolve): genesis `96354a8` (`51e55f9`, `e75a668`, `2d1adb7`, `96354a8` = web/static),
genesis-workflows `6218803`, playwright-appian `0950798`. Intent read from the session-1 As built + Resume note
(project-tracker `28369ca`), the 51-12 review's Re-run section and 51-01 D37. Code-level review only: no live step was
run, the fleet was not touched.

## Summary

Every re-run finding is fixed in code, and each fix has a test that would have caught the original bug. R-MJ1 is done
properly: one reader (`genesis/testexec/roles.py`) over Genesis's own scanner, the regex readers are gone (grep: no
`setup_extra_roles`, `case_script_role`, `_CALLBACK_RE` left in `genesis/`), and the recorded-real-scanner fixtures are
re-checked against a fresh scan (`test_testexec_roles.py`, 27 passed, 0 skipped here). R-m3's per-action
`test.step` proof is pinned by a real Playwright 1.59.1 report and a cross-repo parity test of the three workflow copies.
R-m2's drift check runs on every replay, before the typecheck, against git objects outside the run folder.

There are no blockers and no majors. The minors below are small: a "queued" refusal that cannot fire, a runtime-update
error that does not name the files, the sibling playwright-appian test that still times out under load, and a behaviour
change (d) with no direct test. Two gate reds are from tests outside the range: an environmental hang and a
time-of-day flake.

## Gates (run by the reviewer)

| Repo | Gate | Result |
|---|---|---|
| genesis | `pytest -q -p no:warnings --deselect tests/test_config.py::test_server_readiness_probe` | **1827 passed, 1 failed, 1 deselected** (656 s). The failure is `test_testexec_execution.py::test_regression_job_handler_starts_due_apps_and_skips_busy_ones`, a pre-existing time-of-day flake (O2). It fails again alone at 00:06 IST; neither the test nor `regression_job.py` changed in the range. |
| genesis | `test_server_readiness_probe` | Not re-run. Confirmed environmental (O1): Docker is installed (`/opt/homebrew/bin/docker`), so the probe attempts a real MCP handshake, and nothing under `genesis/config`, `genesis/integrations/mcp*` or `tests/test_config.py` changed in the range. |
| genesis | `ruff check genesis` + every changed test file | All checks passed |
| genesis | `test_testexec_roles.py -rs` | 27 passed, **0 skipped** (the real-scanner and cross-repo parity tests ran) |
| genesis web | `npm run lint` | 0 errors, 20 warnings. None of them is in a changed file: `npx eslint` on the 9 changed web files is clean. So the warnings are pre-existing, and the base count is unchanged as claimed. |
| genesis web | `npm run typecheck` | clean |
| genesis web | `npx vitest run` | 62 files, **726 passed** |
| genesis web | stale bundle: `npx vite build --outDir /tmp/51-18-static-a`, then `diff -r … static` | **IDENTICAL**; `git status` empty; `git diff 2d1adb7 96354a8` outside `web/static` is empty. The L-089 slip did no harm: `96354a8` holds the bundle of `2d1adb7`. |
| genesis-workflows | `ci/validate_library.py` / `ci/validate_skills.py` | PASSED (18) / PASSED (4) |
| genesis-workflows | `pytest -q workflows --ignore=workflows/_fixtures` | **428 passed** |
| genesis-workflows | `ruff check` on action-capture, setup-composer, test-execution, story-verification and ci | All checks passed |
| playwright-appian | `npm run lint`, `npm run typecheck` | clean |
| playwright-appian | `npm test` ×3 | Run 1, under load (genesis pytest and a vite build running): **1 failed / 1399**, `agent-do.test.ts` "a new Appian error is a WARN…" at 5006 ms (m3). Runs 2 and 3, idle: 1399/1399. Measured: `agent-act` "a ref without an address…" 5.4 / 4.6 / 5.3 s (now inside its 30 s timeout); `agent-do` "a new Appian error…" 5.0+ / 4.6 / 4.8 s against the 5 s default. |

## Findings

### Blockers
None.

### Majors
None.

### Minors

- **m1 (R-m5): the "queued" half of Remove script's refusal can never fire.** `TestLibraryService._executions_running`
  (`genesis/testexec/library_service.py:798-809`) looks for the case in `selection.scenarios[].steps[]`. A queued
  execution stores only `{"scenario_ids", "not_automated"}` (`execution_service.py:155`); the steps are added at launch
  (`execution_service.py:278`, `set_running`). So a queued execution of the case is never named. The script is removed,
  and when that execution launches it silently drops the scenario as not automated, or fails with "none of its scenarios
  is automated any more". The docstring, the 409 text ("queued or running"), the 51-10 row and the web dialog all promise
  the queued case. The test only covers a running execution (`test_a_case_script_cannot_be_removed_while_its_scenario_runs_…`).
  A launch in progress also does not hold the workspace lock between its catalog read and `write_generated`, so the
  "checked again inside the lock" (L-091) only covers the running state.
  **Fix:** for a queued execution, resolve `scenario_ids` to their steps from `kb_test_scenario_steps` (or store the plan
  at queue time), and add a regression test with a queued execution.

- **m2 (R-m3a): an "Update testing runtime" refused by unused locals does not say which files, or that the runtime part
  succeeded.** `_update_tsconfig` raises `TypecheckError(errors)` (`workspace.py:295`). The job stores only `str(e)`
  (`jobs.py:212`), which is "the workspace does not typecheck: <first message>", with no path. The playwright-appian
  commit before it stays, yet the job reads as failed. The As built and the commit message both say it "refuses with the
  files". **Fix:** raise a `WorkspaceError` whose message lists `file:line` for each unused local and says "playwright-appian
  updated; tsconfig.json not updated", and assert that text in
  `test_update_runtime_brings_tsconfig_up_and_refuses_unused_locals_with_the_files`.

- **m3 (R-O1): the sibling slow CLI test is still at the edge of vitest's 5 s timeout.** The 51-12 review's run 1 named
  two timeouts: `agent-act` "a ref without an address…" and `agent-do` "a new Appian error is a WARN…"
  (`playwright-appian/tests/cli/agent-do.test.ts:149`). Only `agent-act` got the explicit timeout (`agent-act.test.ts:83`).
  `agent-do`'s test failed at 5006 ms in this review's loaded run and took 4.6–4.8 s idle. 51-13's release gate runs this
  suite. **Fix:** give that test the same explicit `30_000` with a comment of the measured times, then three green full
  runs.

- **m4 (decision d): a paused worker's late terminal `final` is now dropped, with no test.** Before 51-18, a `final: done`
  that arrived after `pause()` stored PAUSED went on to `_finalize`. Now `on_event` returns at once
  (`runs/manager.py:220`). The run stays paused, and Resume must finish a thread that is already at END. I agree with the
  rule (ADR-009: an intended pause wins). But it is a behaviour change, and the R-n1 test only feeds `node` and `error`
  events (`test_a_late_node_event_of_a_paused_worker_is_dropped`). **Fix:** a test where a scripted worker emits
  `final: done` after `pause()`: the run stays PAUSED and logs no `run.final`, then a Resume with a real worker on a
  completed checkpoint reaches DONE exactly once.

### Nits

- **n1 (decision e):** the drift reference commit is read from `library.json` in the agent-writable run folder
  (`action-capture/graph.py:703-716`, `setup-composer/graph.py:567-580`). I agree that this is outside the threat model:
  the comparison runs against the workspace git, and only an existing workspace commit could be substituted. If it is
  ever hardened, `ApwtFactory.library_drift` could take the commit from Genesis's own capture record (`request.commit`)
  instead of from the workflow.
- **n2 (R-m3, residual, not a regression):** a proof is a `test.step` title. Agent-authored proposal code could write
  `test.step('ACT-000005 Open vendor', …)` and "prove" a reused action it never called. Before 51-18, an import was
  enough, so this is strictly better. If wanted, the scanner could flag `ACT-` step titles outside `lib/`.
- **n3:** `genesis/testing/scan_recording.py:99` writes `"typescript": "5.9.3"` as a literal. Take it from the scanner
  output's `typescript` field, so the recording cannot misstate the version.
- **n4:** `story_context` (`verification.py:405`) reads each case's role with its own `read_defines` call and no
  prefetch, so one `node` run per uncached case text. It is cached by hash after that. A `prefetch` of the case and
  setup texts would make the first read one run.
- **n5:** `remove_case_script` calls `before_commit()` once outside the lock, then `ws.change` calls it again inside.
  That is two full `tsc` runs per remove. The outer call could do only the execution check.
- **n6 (decision h, L-057/L-099):** `story-verification`'s tests import `genesis.testing.scan_recording`. genesis-workflows
  pins `genesis.git@v0.80.0` (`pyproject.toml:17-25`), which lacks that module. Locally the tests pass only because the
  dev venv is editable. 51-13 has no line saying this. Add one to 51-13: "genesis-workflows' pins move to the Genesis
  tag that has `genesis.testing.scan_recording` and `ApwtFactory.library_drift`; without it action-capture 0.2.2 and
  setup-composer 0.1.1 refuse every replay (fail-safe) and the story-verification tests fail in CI."
- **n7 (docs, genesis-ctx):** `genesis-ctx check` maps every `genesis/genesis/testexec/**`,
  `genesis/web/src/features/testing/**` and `genesis/testing/**` file to no area ("—"). The browser-testing area's globs
  cover only `playwright-appian/**` (`genesis-ctx area browser-testing`), so no Phase 51 Genesis file pulls that area's
  rules or gates. For genesis-docs: add those globs.

### Observations (outside the range)

- **O1:** `tests/test_config.py::test_server_readiness_probe` hangs on this machine because Docker is installed and the
  probe attempts a real handshake (`svc.test_server("appian-atlas", which=…)` passes the docker check). This is
  environmental and pre-existing; no related file changed in the range.
- **O2:** `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` (51-06, `ee1b77c`) fakes the clock to 03:00
  today, but the executions carry real timestamps. Between 00:00 and 02:00 IST a finished execution predates today's
  02:00 slot, so a second regression starts and the test fails (reproduced at 00:06 IST). This is a determinism bug in
  the test (coding-standards §4). Fix it in the backlog by injecting the timestamps or pinning the date.
- **O3:** playwright-appian has an uncommitted `.gitignore` line (`playwright-appian.code-workspace`). It is not in any
  reviewed commit; keep it out of the 51-13 release commit unless the user wants it.

## The fixes against the spec and D37

| Item | Verdict | Evidence |
|---|---|---|
| R-MJ1 | **Fixed** | `roles.py` (scratch-folder scan with Genesis's template scanner + the workspace `node_modules/typescript`, cache by sha256, an unreadable file gets an error reason); consumers: `generator.build_catalog(role_reader=)` required (`generator.py:178`), `execution_service.py:120`, `verification.py:254`, `story_context(role_reader=)`, library save `case_role_of` on its own scan entry, `_setup_roles`, `compose._extra_roles`, GET case script (`api/testing.py:756`). Scanner: `role: 5` → `dynamic` (`scan-refs.mjs:112-113`). Tests: tricky names and comments, 8 option shapes, a scanner failure → not automated with the reason, recording = fresh scan, and parity over both repos' fixtures (all ran). |
| R-m1 | **Fixed** | `manager.py:445`; `test_a_read_in_a_new_process_leaves_a_paused_run_paused` (the reviewer's probe), `test_pause_then_restart_then_resume_continues_from_the_checkpoint` (real worker, `first.count == 1`). |
| R-m2 | **Fixed** | `workspace.py:499-524` (git blob ids against the export commit; changed, added and removed files; symlinks); refusal before the typecheck on every replay (`action-capture/graph.py:955`, `setup-composer/graph.py:773`); a Genesis without `library_drift` → refused. End-to-end tests in both workflows (`replay["drift"] == [...]`). |
| R-m3 | **Fixed** | `templates/tsconfig.json` `noUnusedLocals` (real tsc test `test_an_imported_but_unused_action_is_refused_by_the_save_typecheck`); `defineAction` → `test.step` (`templates/lib/index.ts:73-74`); `action_steps` + parity of three copies on the real report; `promote_proven_actions(passed_actions=)` required; finalizer reads `results.actions` (`finalizer.py:228-239`); capture/compose apply use `replay.actions` (`proposals.py:335`); action-capture setup mode gives each action proposal its own step's result (`action_proposal_status`, `graph.py:662`). Tests: not called, another action, an old workflow, a failed step caught by the case, a called one promoted. |
| R-m4 | **Fixed** | `ACTION_TRANSITIONS` / `ACTION_PRECONDITIONS` (`transitions.py:252-259`), used only for `TEST_ACTION` (`lifecycle.py:379-394`); audited (`test_testexec_store.py`: `retired → draft restore`); setups unchanged (`test_a_retired_setup_still_restores_to_ready_only_after_a_passing_replay`); web toast (`logic.ts` `transitionMessage`, `item.test.tsx`). |
| R-m5 | **Fixed, with m1** | Route `DELETE …/test-cases/{case_key}/script` (`api/testing.py:769-785`), service `remove_case_script` (one commit, `after_commit_on_noop`, binding and refs deleted), web Remove script with confirm + 409 in place + jest-axe (`phase49.test.tsx`), fixture `case-script-remove`, 51-10 row. |
| R-n1 | **Fixed** | `manager.py:220-225`; `test_a_late_node_event_of_a_paused_worker_is_dropped` (before and after the resume; the resumed worker's events still count). |
| R-n2 | **Fixed** | `finalizer.py:201-207`; `test_action_promotion_runs_through_the_defer_off_the_reader_thread`. |
| R-O1 | **Fixed for the named test, with m3** | `agent-act.test.ts:66-83` (comment with measured times, `30_000`). |

## Decisions (a)–(h)

- **(a) Agree.** The generator reads committed text, which the working tree may not hold, so scanning the texts in a
  scratch folder is right. The template is the scanner `sync_lib` converges every workspace on before saves, replays
  and compose (`library_service.py:471,698,776`, `compose.py:209`).
- **(b) Agree.** A recording keyed by text hash and re-checked against the real scanner follows L-083. A Python
  imitation would repeat R-MJ1's bug.
- **(c) Agree.** It still runs the full `tsc` and drops only the `suites/` errors, which are regenerated before every
  execution. See n5 for the duplicate run.
- **(d) Agree with the rule**, but add the test (m4).
- **(e) Agree** that it is outside the threat model (n1).
- **(f) Agree.** Proving nothing is the fail-safe. The log line is the only signal, so a person may wonder why an action
  stays Draft after a passing run on an old workflow. The Start gates for recording and compose cover the agent paths.
- **(g) Agree.** A name read with the scanner, and a shared name proving neither proposal, is conservative and correct.
- **(h) Agree**, but write it into 51-13 (n6).

## Checklist — genesis (since `2b2cf9d`)

### ADRs
- [OK] ADR-001 — no agent orchestrates. 51-18 adds only program code (readers, checks, routes); `finalizer.py` and `proposals.py` are program steps.
- [OK] ADR-008 — the UI changes are in the product SPA (`web/src/features/testing/**`).
- [OK] ADR-009 — pause/resume keeps all three HITL modes: R-m1 keeps a paused run paused across a restart, and resume continues from the checkpoint (`test_pause_then_restart_then_resume_continues_from_the_checkpoint`). See m4.
- [OK] ADR-010 — no bulk data in state; roles are read from files, the scan cache is in memory.
- [N/A] ADR-011 — no agent node in genesis changed.
- [OK] ADR-012 — the app imports no workflow Python. `ApwtFactory.library_drift` is called from the worker; the parity tests load `graph.py` by file only in tests.
- [OK] ADR-018 — replay results stay in the blackboard artifacts (`replay.actions`), state unchanged.
- [N/A] ADR-019 — no `CORE_MAJOR` or packages change.
- [OK] ADR-021 — no new mutating MCP node. Remove script is a human action in the workspace git, behind a confirm dialog.
- [OK] ADR-022 — the scratch scan folder is a `TemporaryDirectory`; run artifacts are unchanged.
- [OK] ADR-023 — the new route is a FastAPI route in the embedded app.
- [OK] ADR-024 — sync handlers run in FastAPI's threadpool; the blocking promotion moved off the reader thread (R-n2).
- [N/A] ADR-025 — fork untouched.
- [OK] ADR-026 — no new network surface; the route sits on the same loopback app.
- [OK] ADR-027 — existing primitives (`Button`, `Badge`, `ConfirmDialog`, `Trash2` from `@/shared/ui`), no new dependency.
- [OK] ADR-028 — the route is under `/api` (`api/testing.py:769`); the client uses `api.del` (`lib/api/testing.ts:100`), no hard-coded prefix.
- [OK] ADR-030 — SQLite only; no schema change.
- [N/A] ADR-031 — chat untouched.
- [N/A] ADR-032 — credits untouched.
- [N/A] ADR-033 — copilot untouched.
- [N/A] ADR-034 — skills untouched.
- [N/A] ADR-035 — run input files untouched.
- [N/A] ADR-037 — KB untouched.
- [N/A] ADR-041 — documents untouched.
- [N/A] ADR-042 — features/specs untouched.
- [N/A] ADR-043 — Lavish untouched.
- [N/A] ADR-044 — superseded; feature stages untouched.
- [N/A] ADR-045 — chat surface untouched.
- [N/A] ADR-046 — install untouched.
- [N/A] ADR-047 — maintenance syncs untouched.
- [N/A] ADR-049 — navigation untouched.
- [OK] ADR-050 — R-m4 goes through `LifecycleService` (audited, `test_testexec_store.py`). Promotion uses `lifecycle.transition(... "approve")`. Remove script changes the derived `automation_status`, not a lifecycle state.
- [N/A] ADR-054 — memory untouched.
- [OK] ADR-055 — token classes (`text-danger`, `bg-surface-2`), no MUI.
- [N/A] ADR-056 — no stage change.
- [N/A] ADR-057 — no stage change.
- [N/A] ADR-058 — no stage change.
- [N/A] ADR-059 — no stage change.
- [N/A] ADR-060 — finalize stories untouched.
- [N/A] ADR-061 — boards untouched.
- [N/A] ADR-062 — design lane untouched.
- [N/A] ADR-063 — collaboration untouched (Phase 51 is local).
- [N/A] ADR-064 — Hub untouched.
- [N/A] ADR-065 — collaboration gates untouched.
- [N/A] ADR-066 — capture of agent I/O untouched.
- [OK] ADR-067 — healing is unchanged; the drift refusal runs on every replay, so a heal cannot get past it.
- [OK] ADR-068 — nothing deleted in Appian. Remove script deletes a workspace file in one git commit, and its history stays in the workspace.
- [N/A] ADR-069 — no `kiro_node(skills=)` change.
- [N/A] ADR-070 — Object Wiki untouched.
- [N/A] ADR-071 — story page untouched.
- [N/A] ADR-072 — GNS ids untouched.
- [N/A] ADR-073 — package tools untouched.
- [N/A] ADR-074 — KB sync untouched.
- [N/A] ADR-075 — clause ids untouched.
- [N/A] ADR-076 — spec CRs untouched.
- [OK] ADR-077 — reviewed with `genesis-ctx check`, no bulk docs read; no `--trust-all-tools`.
- [OK] ADR-078 — case and scenario lifecycles untouched; removing a script leaves the case record and its status.
- [N/A] ADR-079 — case↔object links untouched.
- [OK] ADR-080 — app-only change; no internal dependency entry added (`genesis/testing/` is inside the app package).

### Lessons
- [OK] L-003 — SSE untouched; a paused run's bus stays open.
- [N/A] L-004 — no JSON data plane added.
- [OK] L-005 — no new event kinds; dropped late events are simply not logged.
- [OK] L-008 — the `worker_exit` vs `error` ordering is unchanged for unintended deaths (`manager.py:261-268`).
- [N/A] L-009 — no checkpointer change.
- [OK] L-010 — `/api` prefix (ADR-028 line).
- [N/A] L-016 — credits untouched.
- [N/A] L-017 — trust untouched.
- [N/A] L-018 — SSE parser untouched.
- [N/A] L-019 — no secret write.
- [N/A] L-020 — no new loop.
- [N/A] L-021 — no MCP output.
- [OK] L-023 — `action_steps` and `passed_action_keys` are defensive (non-list, non-dict, bad titles; the parity edge case `[…, 7]`).
- [OK] L-025 — ruff pinned; clean.
- [OK] L-026 — the blocking promotion is deferred (R-n2); routes are sync handlers in the threadpool.
- [OK] L-027 — as L-025.
- [OK] L-030 — the bundle commit `96354a8` touches `web/**`.
- [N/A] L-031 — Appian export untouched.
- [N/A] L-033 — no new workflow.
- [OK] L-039 — the DELETE returns `automation_status` from the same store the GET reads.
- [N/A] L-041 — no agent authoring change.
- [N/A] L-042 — no agent context change.
- [N/A] L-043 — no SDK embedding.
- [N/A] L-045 — chat untouched.
- [OK] L-048 — the bundle is in `web/static` (package data), identical to a fresh build.
- [N/A] L-050 — sync untouched.
- [N/A] L-051 — shipping untouched.
- [N/A] L-056 — not a release; but `96354a8` vs `2d1adb7` holds only `web/static` (checked).
- [OK, with n6] L-057 — no pin moved here. genesis-workflows will need the new Genesis tag (n6).
- [OK] L-058 — the finalizer's level-triggered recovery is unchanged; the deferred promotion logs loudly on failure (`finalizer.py:203-206`).
- [N/A] L-059 — run graph untouched.
- [N/A] L-060 — run graph untouched.
- [N/A] L-061 — stage finalizers untouched.
- [N/A] L-062 — binding registry untouched.
- [N/A] L-063 — no prerequisite stage.
- [N/A] L-064 — no agent turn.
- [N/A] L-065 — no gate→END path.
- [N/A] L-066 — no event-log fold.
- [OK] L-068 — `index.html` serving untouched; bundle fresh.
- [OK] L-069 — no `<Button asChild>`; the Edit link uses `buttonVariants` on a `Link` (`AutomationBadge.tsx:75`).
- [N/A] L-071 — Hub untouched.
- [N/A] L-072 — Hub untouched.
- [N/A] L-073 — stage HTML untouched.
- [N/A] L-074 — boards untouched.
- [OK] L-075 — no whole-workflow re-run added.
- [N/A] L-076 — no fan-out.
- [N/A] L-081 — no new default job.
- [N/A] L-082 — no pull.
- [OK] L-083 — real shapes: the recorded real scanner, the real Playwright 1.59.1 report (`execution-report-actions-1.59.1.json`, recorded by a real-Playwright test).
- [N/A] L-084 — Hub untouched.
- [N/A] L-085 — Hub untouched.
- [N/A] L-086 — clause ids untouched.
- [N/A] L-087 — no doc migration.
- [N/A] L-088 — no hook change.
- [OK, slip harmless] L-089 — the build and the commit were batched (As built). Independently verified: an out-of-tree build is identical to `web/static`, and `git status` is empty in its own call.
- [N/A] L-090 — no table columns.
- [VIOLATION → m1] L-091 — `remove_case_script` re-checks inside the workspace lock, but the check cannot see queued executions, and a launch does not hold that lock between its catalog read and `write_generated`.
- [OK] L-092 — `tests/scan_fixtures.py` and `genesis/testing/scan_recording.py` are not `test_*`; no `tests/__init__.py` added.
- [OK] L-093 — the execution's status is stored before the deferred promotion (`test_action_promotion_runs_through_the_defer_off_the_reader_thread` asserts `passed` before the deferred call).
- [OK] L-094 — `ACTION_TRANSITIONS` is used only for `TEST_ACTION`; `LIBRARY_TRANSITIONS` is unchanged for setups (grep: only `lifecycle.py:390-394` reads it).
- [N/A] L-095 — object links untouched.
- [OK] L-096 — DELETE `…/script` and the GET/PUT share one path; no generic route shadows it (`test_testing_api.py` every-route test).
- [OK] L-097 — the startup sweep (`fail_orphaned_runs`) is unchanged and keeps paused runs (asserted in the R-m1 tests).
- [N/A] L-098 — packaging untouched.
- [OK, see n6] L-099 — no version-keyed behaviour; the editable venv hides n6 locally.
- [OK] L-100 — no CI-variables API used.

### Gates
- [VIOLATION, outside the range] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` — 1827 passed, 1 failed (O2, a pre-existing time-of-day flake), 1 deselected (O1, environmental).
- [OK] `cd genesis && .venv/bin/ruff check genesis` — clean.
- [OK] `cd genesis/web && npm run lint && npm run typecheck && npm test` — 0 errors (20 pre-existing warnings), tsc clean, 726 passed.
- [OK] `cd genesis/web && npm run build # then commit web/static/` — out-of-tree build identical to the committed `web/static`.

## Checklist — genesis-workflows (since `69bface`)

### ADRs
- [OK] ADR-001 — the drift and action-step checks are program steps in the graph.
- [N/A] ADR-003 — distribution model untouched.
- [N/A] ADR-005 — registries untouched.
- [OK] ADR-006 — versions bumped in `META`, `workflow.yaml` and `registry.json` together (test-execution 0.1.1, action-capture 0.2.2, setup-composer 0.1.1); validate_library passed.
- [N/A] ADR-007 — roles tags unchanged.
- [OK] ADR-010 — `replay.actions` and `drift` are small lists in the replay artifact.
- [OK] ADR-011 — no agent node added or unwrapped; validate_library (reliability gate) passed.
- [OK] ADR-012 — `graph.py` stays standalone; the Genesis helpers are copies pinned by the parity test (`test_the_three_workflow_copies_of_action_steps_match_the_app_on_a_real_report`).
- [N/A] ADR-014 — no new workflow.
- [N/A] ADR-015 — build order unaffected.
- [OK] ADR-017 — Python only.
- [OK] ADR-018 — results are handed over by artifact.
- [OK] ADR-019 — `genesis_core_major` unchanged; the change is additive.
- [N/A] ADR-020 — no MCP config.
- [OK] ADR-021 — no new mutating node.
- [OK] ADR-022 — writes only under the run folder.
- [N/A] ADR-026 — no network surface.
- [N/A] ADR-029 — no registry tier change.
- [N/A] ADR-030 — no persistence.
- [N/A] ADR-031 — chat untouched.
- [N/A] ADR-033 — copilot untouched.
- [N/A] ADR-034 — skills untouched (validate_skills passed).
- [N/A] ADR-035 — no file inputs.
- [N/A] ADR-036 — KB untouched.
- [N/A] ADR-037 — no SAIL.
- [N/A] ADR-038 — managed MCP untouched.
- [N/A] ADR-039 — business map untouched.
- [N/A] ADR-041 — documents untouched.
- [N/A] ADR-045 — chat untouched.
- [N/A] ADR-046 — install untouched.
- [N/A] ADR-048 — no Appian credential read.
- [N/A] ADR-056 — stages untouched.
- [N/A] ADR-057 — stages untouched.
- [N/A] ADR-058 — stages untouched.
- [N/A] ADR-059 — stages untouched.
- [N/A] ADR-061 — boards untouched.
- [N/A] ADR-062 — design lane untouched.
- [N/A] ADR-063 — collaboration untouched.
- [N/A] ADR-065 — collaboration untouched.
- [OK] ADR-067 — healing bounds unchanged; the drift refusal repeats on every replay, so healing cannot override it (spec §3 R-m2).
- [N/A] ADR-068 — no Appian mutation.
- [N/A] ADR-069 — no skill declaration change.
- [N/A] ADR-073 — package tools untouched.
- [N/A] ADR-074 — sync untouched.
- [N/A] ADR-075 — clause ids untouched.
- [N/A] ADR-076 — CRs untouched.
- [OK] ADR-077 — reviewed through genesis-ctx.
- [N/A] ADR-078 — test design untouched.
- [OK, see n6] ADR-080 — pins unchanged here (`genesis.git@v0.80.0`); 51-13 must move them.

### Lessons
- [OK] L-006 — `graph:` topologies unchanged (no new node).
- [N/A] L-009 — no checkpointer change.
- [OK] L-013 — parity lint passed.
- [N/A] L-017 — no trust change.
- [N/A] L-020 — loop bounds unchanged.
- [N/A] L-021 — no MCP output.
- [N/A] L-022 — no `from __future__` added to these graphs.
- [OK] L-023 — the copies of `action_steps` are defensive (parity edge case).
- [N/A] L-024 — skills untouched.
- [OK] L-025 — ruff clean.
- [N/A] L-026 — no DB write in a node.
- [OK] L-027 — ruff clean.
- [N/A] L-029 — no managed-native change.
- [N/A] L-030 — no web.
- [N/A] L-033 — no new workflow.
- [N/A] L-042 — no agent context change.
- [N/A] L-045 — chat untouched.
- [N/A] L-049 — no managed MCP bundle.
- [N/A] L-051 — shipping untouched.
- [OK] L-053 — no credential read.
- [N/A] L-056 — not a release.
- [VIOLATION → n6 (pending at 51-13)] L-057 — `story-verification`'s tests now need a Genesis tag with `genesis.testing.scan_recording`; the pin is still `v0.80.0`. It is fine at this local, unpushed stage, but it must be written into 51-13.
- [N/A] L-064 — no large agent artifact.
- [OK] L-075 — no whole-workflow re-run added.
- [N/A] L-076 — no fan-out.
- [N/A] L-087 — no doc migration.
- [N/A] L-088 — no hook.
- [N/A] L-089 — no bundle here.
- [OK] L-092 — no `tests/__init__.py` added; pytest collected 428.
- [N/A] L-098 — packaging untouched.
- [OK, see n6] L-099 — the editable venv makes the import pass locally.
- [OK] L-100 — no CI-variables API used.

### Gates
- [OK] `ci/validate_library.py` — PASSED (18).
- [OK] `pytest -q workflows --ignore=workflows/_fixtures` — 428 passed.
- [VIOLATION, outside the range] `cd genesis && pytest` — see the genesis gates (O2).
- [OK] `cd genesis && ruff check genesis` — clean.

## Checklist — playwright-appian (since `5d7ae2d`)

### ADRs
- [N/A] ADR-011 — no agent node.
- [N/A] ADR-019 — no Genesis library.
- [N/A] ADR-026 — no network surface.
- [N/A] ADR-046 — install untouched.
- [N/A] ADR-063 — collaboration untouched.
- [N/A] ADR-065 — collaboration untouched.
- [N/A] ADR-074 — sync untouched.
- [OK] ADR-077 — reviewed through genesis-ctx.
- [N/A] ADR-080 — not the platform repo.

### Lessons
- [N/A] L-017 — no trust change.
- [N/A] L-025 — no ruff in this repo.
- [N/A] L-027 — no ruff in this repo.
- [N/A] L-030 — no Genesis web.
- [N/A] L-045 — no chat.
- [N/A] L-051 — not a release.
- [OK] L-056 — the one commit holds the one test change; the dirty `.gitignore` is not in it (O3).
- [N/A] L-057 — no pin.
- [N/A] L-087 — no doc migration.
- [N/A] L-088 — no hook.
- [N/A] L-089 — no bundle.
- [N/A] L-092 — vitest.
- [N/A] L-098 — no Python packaging.
- [N/A] L-099 — no version bump (51-13 releases 0.3.0).
- [OK] L-100 — no CI-variables API used.

### Gates
- [VIOLATION → m3] `npm run lint && npm run typecheck && npm test` — lint and typecheck clean; `npm test` 1 failed / 1399 under load (`agent-do.test.ts:149`, 5006 ms), 1399/1399 in two idle runs.
- [N/A] `npm run build` — release only.

## Verdict: SHIP

No blockers and no majors. Every re-run finding (R-MJ1, R-m1..R-m5, R-n1, R-n2, R-O1) is fixed in code, with a regression
test that fails on the old code where one was claimed. The two red gate lines come from tests outside the range: O2 is
a pre-existing time-of-day flake, and m3 is the sibling slow test the 51-12 evidence also named. Fix m1–m4 before
51-13 tags; m3 must be fixed before 51-13 runs its release gate. Write n6 into 51-13. The next step is §3 steps 1–27
live once QA/Dev are back.

---

## Delta re-review (genesis-review, 2026-11-09, code-level only)

Range: genesis `96354a8..0a5d342` (one commit), playwright-appian `0950798..f00cebb` (one commit). genesis-workflows
(`6218803`) and genesis `web/static/` are unchanged. No live steps and no fleet were used.

### Gates (run by the reviewer)

- genesis, the affected files: `pytest tests/test_testexec_execution.py tests/test_testexec_workspace.py
  tests/test_runs.py tests/test_testexec_library.py` gave **151 passed, 1 failed**. The failure is
  `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` (`assert 2 == 1` at
  `test_testexec_execution.py:696`), run at 00:57 IST. That is O2 from the first pass, the time-of-day flake. No file
  it touches changed in the delta.
- genesis: `ruff check genesis tests/test_runs.py tests/test_testexec_execution.py tests/test_testexec_workspace.py`
  passes. `ruff check tests` as a whole has 26 errors, all in older test files outside the range
  (`test_chat_api.py`, `test_smoke.py`, …). CI lints `genesis`, so this is not a finding.
- Regression proof: I exported `96354a8` to `/tmp/g51-old` and added the new tests to it.
  `test_a_queued_execution_of_its_scenarios_also_refuses_remove_script` fails there with
  `DID NOT RAISE CaseScriptInUse` (`test_testexec_execution.py:985`) and passes on `0a5d342`.
  `test_a_paused_workers_late_terminal_final_is_dropped_…` passes on both. That is expected, because the m4 behaviour
  was already in `96354a8` and m4 asked only for its test.
- playwright-appian: `npm run lint && npm run typecheck` is clean. One full `npm test`, run on its own (load average
  5.3): **95 files, 1399/1399**. `agent-do` "a new Appian error is a WARN…" took 4615 ms and `agent-act` "a ref
  without an address…" took 4581 ms.

### The delta against the first-pass findings

| Item | Verdict | Evidence |
|---|---|---|
| m1 (queued executions) | **Fixed** | `library_service.py:798-825`: a queued execution's `scenario_ids`, plus any `scenarios[].id`, are checked against `SELECT DISTINCT scenario_id FROM kb_test_scenario_steps WHERE case_id=?`. A launch in progress is covered. `_launch` reads the catalog (`execution_service.py:264`), then runs `write_generated` under `path_lock`. The execution stays `queued` until `set_running` in `prepare` (`:283`), so the in-lock check sees it as queued, or as running with its plan. The new test asserts that only the queued execution is named (`problems == [queued key]`) and that the script row survives. See m5 for the one kind of execution this still misses. |
| n5 (two typechecks) | **Fixed** | `remove_case_script` calls `refuse_if_busy()` once, before the lock and without a typecheck (`:856`). Inside the lock, `before_commit` runs the check again and then the typecheck (`:847-851`). |
| m2 (tsconfig refusal message) | **Fixed** | `workspace.py:64-70` adds `RuntimeUpdateRefused(WorkspaceError)` with `errors`. Its message lists up to 20 errors as `file:line message`, plus "and N more", and ends "Everything else in the runtime update is done." (`:304-309`). The job stores `str(e)` (`jobs.py:212`). The workspace test asserts both the `actions/a.ts:1 …` text and the closing sentence. No caller catches `TypecheckError` around `update_runtime`; the only caller is the job (`api/testing.py:222-223`). |
| m3 (agent-do timeout) | **Fixed** | `tests/cli/agent-do.test.ts:149-163` sets an explicit `30_000` with a comment of the measured times; the test body is unchanged. My run: 4615 ms, green. |
| m4 (late terminal final) | **Fixed** | `tests/test_runs.py:849-876`. A scripted worker's `final: done` after `pause()` leaves the run PAUSED with no `run.final`. Then a real worker's thread at END, set to PAUSED and resumed, ends DONE with exactly one more `run.final` (`[before:] == ["done"]`). The two halves use two runs, because the scripted run has no real checkpoint. This is acceptable: each half proves its own claim. |
| n3 (TypeScript version) | **Fixed** | `scan_recording.py:99-100` reads `version` from `<node_modules>/typescript/package.json`, i.e. the node_modules the scanner ran with. ruff passes (no undefined name). |
| n6, n7 | Deferred, as stated | These are for the 51-13 As built and genesis-docs. They are not code in this delta. |

### On the earlier red playwright-appian runs

Neither earlier red run counts against the delta.
- **Three suites at once.** CPU contention from overlapping runs is enough to push the cold-start CLI tests over their
  limits. That is the operator's batching slip (L-089), not a product or test defect. Three sequential runs on their
  own, plus mine, are the valid evidence.
- **One `agent-idle` failure at load average ~25.** `agent-idle.test.ts:55-67` opens a session with a 3 s idle timeout
  and sends a cold `apwt status` every 1 s. Under heavy load, one cold start plus the 1 s sleep can exceed 3 s, so the
  session closes as designed. That is wall-clock sensitivity inherent to an idle-timeout test. The test predates 51-18,
  and no 51-18 file is involved. I record it as **O4** (below) and do not count it as a finding. Do not run the 51-13
  release gate on a machine that loaded.

### New findings

- **m5 (minor; it predates this delta, but the delta's docstring repeats the wrong claim): Remove script does not
  refuse while a story *verification* execution is running.** The running branch of `_executions_running`
  (`library_service.py:807-810`) still looks only in `selection.scenarios[].steps[]`. A verification execution never
  has that key. Its running selection is `{**queued_selection, "resumed": …}` (`verification_service.py:279-281`):
  `scenario_ids`, `case_keys` and `scenario_keys`, with no plan. So a verification is refused while it is queued, and
  the refusal stops as soon as it starts running. The new docstring says "A running execution's plan names its
  steps", which is true only for adhoc, impact and regression executions.
  Reviewer probe `/tmp/g51-new/tests/test_probe_51_18_delta.py`, run on `0a5d342`: a queued verification of the
  flow scenario gives `['TE-000001']`; the same execution after `set_running` gives `[]`.
  The running verification's checkout is a copy exported at `prepare`, so its own files are not broken. But the
  promise in the 409 text, the docstring and the dialog ("queued or running") is not kept for that kind, and the
  verification still treats the case as automated.
  **Fix:** apply the `scenario_ids` resolution (and `case_keys` membership) to running executions as well, then
  extend the new test with a verification-kind execution moved to running.
  I rate it minor and not a blocker: no data is lost, and the gap is one kind of execution in one status.

### New observation

- **O4:** `playwright-appian/tests/cli/agent-idle.test.ts` "requests keep it open…" has about 2 s of wall-clock
  margin per request and can fail under extreme load (seen once by the developer at load average ~25). This is
  pre-existing and outside the range. If it recurs, give the test a longer `--idle-timeout`, keeping the request gap
  well under it.

### Checklist — genesis (since `96354a8`)

`genesis-ctx check --since 96354a8` maps all six files to no area ("—"; this is n7), so it lists only release-ci and
security. I also answered the lessons the code actually touches.

ADRs
- [N/A] ADR-011: no agent node changed.
- [N/A] ADR-019 / ADR-080 / ADR-046: no version, pin, package layout or install change.
- [N/A] ADR-026 / ADR-063 / ADR-065 / ADR-074: no bind, auth, collaboration or KB sync change.
- [OK] ADR-077: the review used genesis-ctx and one-call retrieval, and did not run with `--trust-all-tools`.
- [OK] ADR-009 (relevant, not listed): m4's test pins the rule that an intended pause beats a late terminal `final`.

Lessons
- [N/A] L-017, L-045 (chat trust) — no chat change.
- [OK] L-025 / L-027: the ruff pin is unchanged, and the pinned ruff passes on `genesis` and the changed tests.
- [N/A] L-030: no `web/**` change, so the stale-bundle guard is not affected. `web/static/` is untouched since `96354a8`.
- [N/A] L-051, L-087, L-088, L-098, L-100: none apply to this code.
- [OK] L-056: the one commit holds both the implementation and its tests. `git status` is clean at `0a5d342`.
- [N/A] L-057 / L-099: no pin moves in this delta. n6 carries the pin move to 51-13.
- [OK] L-089: the developer's valid evidence is three sequential runs, each issued on its own. The batched attempt
  was correctly thrown out.
- [OK] L-092: the new tests are uniquely named `test_*` functions. No new module and no `tests/__init__.py`.
- [OK] L-091 (relevant, not listed): the busy check runs again inside the workspace `path_lock`, the same lock
  `write_generated` takes. The m1 analysis above shows that the queued → running handoff leaves no window for
  adhoc, impact or regression executions. Verification executions are m5.
- [OK] L-083 (relevant, not listed): the new m1 test uses real `env.svc.start` executions, so the queued selection has
  its real shape (it asserts `"scenarios" not in selection`).

Gates
- [OK] `pytest` (affected files): 151 passed, 1 failed. The failure is O2, time of day, outside the range.
- [OK] `ruff check genesis`: clean.
- [N/A] web lint / tsc / vitest / build: no web change.

### Checklist — playwright-appian (since `0950798`)

ADRs: [N/A] ADR-011, ADR-019, ADR-026, ADR-046, ADR-063, ADR-065, ADR-074, ADR-080: this is a test-timeout change only.
[OK] ADR-077, as above.

Lessons
- [N/A] L-017, L-025, L-027, L-030, L-045, L-051, L-057, L-087, L-088, L-092, L-098, L-099, L-100: none apply to one
  test's timeout.
- [OK] L-056: `f00cebb` holds the one test change. The uncommitted `.gitignore` line (O3) is still outside every
  commit, so keep it out of the 51-13 release commit.
- [OK] L-089: see "On the earlier red playwright-appian runs".

Gates
- [OK] `npm run lint && npm run typecheck && npm test`: clean, clean, 1399/1399 in my run on its own, and the
  developer reports three sequential 1399/1399 runs.
- [N/A] `npm run build`: release only.

### Delta verdict: SHIP

m1, m2, m3, m4, n3 and n5 are fixed. Each fix has a test that asserts the behaviour the finding named, and the m1 test
fails on the old code. One new minor, m5, remains: Remove script does not refuse while a story verification is
running. It predates this delta and loses no data, so it does not block. Fix it, with its test, before 51-13 tags, as
the first pass required for m1–m4. O2 (time-of-day flake) and O4 (idle test under extreme load) are outside the range;
keep them in the backlog. n6 and n7 go to the 51-13 As built and genesis-docs, as the developer stated.
