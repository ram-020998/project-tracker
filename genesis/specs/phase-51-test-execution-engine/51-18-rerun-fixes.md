# 51-18 — Fixes from the 51-12 re-run

> **Status:** **DONE 2026-11-08** (SHIP, first pass + delta; see As built). SPEC-DRAFTED 2026-11-05. Repos: **genesis** (backend + web), **genesis-workflows** (`action-capture`,
> `setup-composer`: shared checks only), **playwright-appian** (one test). Parent:
> `specs/phase-51-test-execution-engine.md`. Decision: 51-01 **D37**. Evidence for every item (file:line, repro, the
> reviewer's fix): `reviews/51-12-review.md` → **Re-run** section — read it first. Built after 51-17; then the
> reviewer re-reviews and runs live steps 1–27.

## 1. Goal

Close the re-run's major, minors, nits and the playwright-appian timeout, so 51-12 can SHIP once the live steps pass.

## 2. R-MJ1 — one reader for roles

- The generator reads a **setup's extra roles** and a **case's role** from `lib/scan-refs.mjs`'s output for the
  committed files (the scanner already reports `roles`; `RecordingService.library_snapshot` reads it that way). Remove
  `setup_extra_roles` and the regex `case_script_role` / `_CALLBACK_RE` path; every consumer (generator, Replay,
  readiness, verification scope, compose's m-3 check) goes through the one reader. A file the scanner cannot read keeps
  today's rule: its scenarios are not automated, with the reason.
- If the scanner does not yet report a case's role, extend it (the template's `scan-refs.mjs`, synced by `lib/`).
- Tests: setup names containing `async`, `function`, `=>`; a comment inside the roles array; a case with options in any
  order; a **parity test**: the generator's reading equals the scanner's on every setup and case fixture of both repos
  (cross-repo, run locally as in 51-16).

## 3. Minors

- **R-m1** — `RunManager.reconcile_status` leaves a `paused` record unchanged (as `fail_orphaned_runs` does). Tests: the
  reviewer's repro (`/tmp/genesis-review/51-12-rerun/probe_paused_reconcile.py`) as a regression test; pause → restart
  (fresh `RunManager`) → resume continues from the checkpoint.
- **R-m2** — before `replay` in `action-capture` and `setup-composer`, compare every library file (`actions/`,
  `setups/`, `cases/`, `lib/`) in the run's checkout with the export commit; any difference outside the proposals'
  own `proposed/` overlay fails the replay with the paths named (healing cannot override it). Test: an agent-modified
  transitive action leaves the setup Draft and the run reports why.
- **R-m3** — (a) the workspace template's `tsconfig.json` gains `noUnusedLocals: true` (an existing workspace gets it
  through "Update testing runtime"; the save typecheck then refuses an unused import). (b) `defineAction` wraps each
  call in `test.step('<ACT-key> <name>', …)`; the results parser records each action step's status; every proof
  (`promote_proven_actions`, the capture replay's per-proposal results, compose apply) promotes **only** the actions
  whose step ran and passed in that run, at the same code. Tests: an imported-but-uncalled action and an action in a
  branch not taken stay Draft; a called one is promoted.
- **R-m4** — `LIBRARY_TRANSITIONS` gains `(RETIRED, "restore") → DRAFT` for **actions** (audited, no precondition
  beyond the retire rules); setups keep restore → Ready with a passing Replay at the current hash. The item page's
  Restore says "Restored to Draft — Run dependents to make it Ready". Tests for both kinds.
- **R-m5** — `DELETE …/test-cases/{case_key}/script` (51-10 table + fixture) and **Remove script** on the case page
  (confirm dialog): one commit removing `cases/<TC>.ts`, `TestScriptStore.delete`, the refs for that file removed, the
  case `not-automated`; refused (409, naming them) while the case's own scenarios are mid-execution. Tests: route,
  page, jest-axe.

## 4. Nits and the playwright-appian test

- **R-n1** — `on_event` drops the killed worker's late events for any intended stop (pause or cancel), not only
  cancel. Test.
- **R-n2** — the finalizer runs `_promote_actions` through `self._defer` (off the run reader thread). Test.
- **R-O1** — playwright-appian `tests/cli/agent-act.test.ts` ("a ref without an address acts on the element…"):
  find why it slows under a full parallel run; if the cause is not quick to fix, give that test an explicit timeout
  with a comment naming the measured times. Its gates green in **three** consecutive full `npm test` runs. Recorded in
  its `DECISIONS.md` only if behaviour changes (D19). No version bump here: 51-13 releases 0.3.0 with it.

## 5. Gates

genesis pytest + ruff; the cross-repo tests locally; genesis-workflows `validate_library`, `validate_skills`, pytest;
web lint, tsc, vitest + jest-axe; `npm run build`, wait for the output to settle, commit `web/static` separately, then a
rebuild and an empty `git status` in its own call (L-089); playwright-appian lint, typecheck, `npm test` × 3.

## Context manifest

```toml
areas    = ["runs-worker", "workflows-library", "stories-workbench", "browser-testing"]
adrs     = ["ADR-009", "ADR-011", "ADR-050", "ADR-067"]
lessons  = ["L-011", "L-039", "L-058", "L-083", "L-089", "L-091", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/reviews/51-12-review.md", "tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-17-setup-composer.md", "tracker:specs/phase-51-test-execution-engine/adr-drafts.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/runs/manager.py", "genesis/genesis/domain/transitions.py", "genesis/genesis/api/testing.py", "genesis/genesis/kb/testexec_store.py", "genesis/web/src/features/testing/**", "genesis/web/src/features/test-design/**", "genesis-workflows/workflows/action-capture/**", "genesis-workflows/workflows/setup-composer/**", "playwright-appian/tests/cli/**"]
upstream = ["51-15", "51-16", "51-17"]
```

## As built (2026-11-07 → 11-09, genesis-dev, two sessions)

**Task restated.** Close the 51-12 re-run's findings (`reviews/51-12-review.md` → Re-run; 51-01 D37): R-MJ1 one roles
reader (the scanner) for setup and case roles; R-m1 a paused run stays paused on a read in a new process; R-m2 a replay
refuses a checkout whose library files differ from the export commit; R-m3 `noUnusedLocals` + per-action `test.step`
proofs; R-m4 a retired action restores to Draft; R-m5 Remove script (route + page); R-n1 drop a stopped worker's late
events; R-n2 promotion off the reader thread; R-O1 the playwright-appian `agent-act` timeout. Rules: ADR-009, ADR-011,
ADR-012 (workflow copies pinned by parity tests), ADR-050, ADR-067; lessons L-011/L-083 (real shapes), L-039, L-058,
L-089, L-091, L-093, L-094. No ADR deviation.

### Commits

Base: genesis `2b2cf9d`, genesis-workflows `69bface`, playwright-appian `5d7ae2d`. Local only, not pushed or tagged.

| Repo | Commit | What |
|---|---|---|
| genesis | `51e55f9` | R-m1 + R-n1 (`runs/manager.py`) and tests |
| genesis | `e75a668` | R-MJ1 (`testexec/roles.py`, every consumer), R-n2, R-m4 backend, R-m5 backend, fixture `case-script-remove` |
| genesis | `2d1adb7` | R-m3 (tsconfig, lib `test.step`, `action_steps`, proofs), R-m2 (`library_drift`), workflow version gates, `genesis/testing/scan_recording.py`, web (Remove script, restore message), fixtures |
| genesis | `96354a8` | `web/static` for `2d1adb7` (see Decisions 9: proven by a rebuild, then an empty status in its own call) |
| genesis | `0a5d342` | review m1 (queued executions refuse Remove script), m2 (runtime-update refusal names the files), m4 (test), n3, n5 |
| genesis | `346f885` | delta review m5 (a running story verification refuses Remove script) |
| genesis-workflows | `6218803` | R-m2 + R-m3 in action-capture 0.2.2, setup-composer 0.1.1, test-execution 0.1.1; story-verification tests on the recorded scanner |
| playwright-appian | `0950798` | R-O1: `agent-act` "a ref without an address…" explicit 30 s timeout, measured times in a comment |
| playwright-appian | `f00cebb` | review m3: `agent-do` "a new Appian error is a WARN…" explicit 30 s timeout |
| project-tracker | `28369ca` + this commit | As built, the 51-10 row for DELETE `…/script`, `reviews/51-18-review.md` |

### Changed (genesis)

- **R-m1** `RunManager.reconcile_status` returns a `paused` record unchanged (as `fail_orphaned_runs` already did).
- **R-n1** `_spawn.on_event` returns at once for ANY intended stop (`seen["stop"]`, set by `pause` / `cancel` before the
  kill); per worker, so the resumed worker's events count. A late terminal `final` of a paused worker is dropped too
  (Decisions 4).
- **R-n2** `TestExecutionFinalizer.finalize_run` hands `_promote_actions` to `self._defer`.
- **R-m4** `ACTION_TRANSITIONS` (`(retired, restore) → draft`), `ACTION_PRECONDITIONS` / `_REASONS` (no restore
  precondition), used only for `TEST_ACTION` (`domain/lifecycle.py`). Setups keep restore → Ready after a passing Replay.
  Web: `logic.transitionMessage` → "Restored to Draft — Run dependents to make it Ready".
- **R-m5** `DELETE /applications/{app}/test-cases/{case_key}/script` → `TestLibraryService.remove_case_script`: one
  commit "Remove the script of TC-…" (its own typecheck ignores `suites/` errors), then `TestScriptStore.delete` (binding
  + refs, `not-automated`). 404 without a script; 409 `problems` = every queued or running execution that uses the case
  (`_executions_running`: a plan's steps, `scenario_ids` through `kb_test_scenario_steps`, a verification's
  `case_keys`), checked at once and again inside the workspace lock (L-091). Web: **Remove script** in
  `AutomationBadge.CaseScriptView` (the case page's Automation script section) with `ConfirmDialog` (now exported from
  `LibraryItemPage`); a refusal shows in place. Type `CaseScriptRemoved`, client `testingApi.removeCaseScript`.
- **R-MJ1** `testexec/roles.py`: `case_role_of` / `setup_roles_of` (pure, on the scanner's `defines`), `scan_texts`
  (texts into a scratch folder with a copy of `templates/lib/scan-refs.mjs` and a `node_modules` link → one `node` run),
  `read_defines` (cache by sha256), `RoleReader(node_modules)`. `build_catalog(role_reader=)` is required. Consumers:
  execution catalog, `VerificationTools.catalog`, `story_context(role_reader=)`, the save warning (`case_role_of` on
  the save's own scan), library Replay `_setup_roles`, compose `_extra_roles`, GET case script. The regex readers are
  gone. Scanner: a non-string literal `role` is listed in `dynamic`. An unreadable file → its scenarios not automated
  with "Genesis could not read <path>: <reason>".
- **R-m3** `templates/tsconfig.json` `noUnusedLocals`; "Update testing runtime" (`TestWorkspace.update_runtime`) now
  also brings an old workspace's `tsconfig.json` to the template in its own commit, typechecked first
  (`needs_runtime_update` is true while it differs; a refusal is `RuntimeUpdateRefused` naming every `file:line`).
  `templates/lib/index.ts` `defineAction` runs each call inside `test.step('<key> <name>')`. `replay.action_steps`
  (nested steps, any depth; failed if any call failed) and `passed_action_keys`; `replay_outcome` returns `actions`.
  `promote_proven_actions(passed_actions=)` (required) promotes only reached Draft actions whose own step passed. The
  execution finalizer takes them from `results.json` `actions` of passed scenarios and setup projects (none → nothing
  proven, logged); capture and compose apply from the capture document's `replay.actions`.
- **R-m2** `TestWorkspace.library_drift(commit, checkout)` (git blob ids of `actions/ setups/ cases/ lib/` vs the
  workspace repository: changed, added, removed) and `ApwtFactory.library_drift(app, checkout, commit)` for the workers.
- **Version gates (L-053).** `recording.PROOF_WORKFLOW_VERSION = (0, 2, 2)`: every recording needs action-capture ≥
  0.2.2 (Start and Stop); `COMPOSE_WORKFLOW_VERSION = (0, 1, 1)`.
- **Test support.** `genesis/testing/scan_recording.py` (recorded REAL scanner output per text hash; record with
  `GENESIS_WRITE_SCAN_FIXTURES=1`), used by genesis `tests/scan_fixtures.py` and the genesis-workflows story-verification
  tests.

### Changed (genesis-workflows)

- **test-execution 0.1.1** `action_steps` (copy) and `actions` per scenario and per setup project in `results.json`.
- **action-capture 0.2.2** `library_drift` before every replay (refusal names the paths, `replay.drift`; the heal
  cannot get past it: the check repeats on every replay); `action_steps` + `replay.actions`; setup mode: each action
  proposal's status is its OWN step (`action_proposal_status`: reuse/update by key, a new one by `ACT-NEW <name>` with
  the name read by the scanner, a shared name proves neither); `result.replay.actions`.
- **setup-composer 0.1.1** the same drift refusal; `action_steps`; `result.replay.actions`.
- `META` / `workflow.yaml` / `registry.json` bumped together. story-verification: unchanged code; its tests read roles
  from `tests/fixtures/scan-recorded.json` and its normalize parity test ignores test-execution's new `actions`.
- Fixtures: action-capture's `setup-scan/scan-refs-0.1.json` re-recorded with the real scanner, now with the action
  files (the setup entries are byte-identical); test-execution's `execution-report-actions-1.59.1.json` (copied from
  genesis).

### Tests

- **genesis**: full pytest **1829 passed, 1 failed, 1 deselected** at `0a5d342`, then the affected suites at
  `346f885` (127 passed + the same 1). The failure is `test_regression_job_handler_starts_due_apps_and_skips_busy_ones`,
  a pre-existing time-of-day flake (fails 00:00–02:00 IST; review O2). The deselected test is
  `tests/test_config.py::test_server_readiness_probe`, which hangs on this machine at the base revision too (Docker is
  installed, so it attempts a real handshake; review O1). `ruff check genesis` + every changed test file clean.
  - R-m1/R-n1/m4: `test_runs.py` +4 (the reviewer's probe; pause → fresh RunManager → resume from the checkpoint with
    a real worker; a paused worker's late node event; its late terminal final). The probe and the late-node tests
    fail on `2b2cf9d`.
  - R-MJ1: `test_testexec_roles.py` (27): the five tricky setups (`async`, `function`, `=>` in the name, a block and a
    line comment in `roles`; the old regex reader returns `[]` for all five) through the reader, the generator +
    readiness, Replay and compose; 8 case-option shapes; a scanner failure; both repos' recordings equal a fresh real
    scan; the cross-repo parity check (scratch scan == in-place scan of a real workspace == the workflows' recorded
    scans) over every setup/case fixture.
  - R-m3: real tsc refuses an imported-but-unused action; the real-Playwright test now asserts lib's nested
    `ACT-000001 Open vendor` step passed in the scenario and the setup (and recorded
    `fixtures/testexec/execution-report-actions-1.59.1.json`); the three workflow copies of `action_steps` equal
    Genesis's on that real report; execution: a called action is promoted, an imported-but-not-run one / another
    action / an older workflow / a failed step caught by the case stay Draft; capture and compose apply: an action the
    replay did not run stays Draft.
  - R-m2: `library_drift` on a real export (changed, added, removed, lib/; `suites/` ignored).
  - Runtime update: the tsconfig commit, the refusal naming `file:line`.
  - R-m5: route (every-route test, fixture), running, queued and running-verification refusals (both selection
    shapes; fail on `0a5d342`), one commit, binding gone, scenario not automated, second remove 404.
  - Gates: a plain recording on action-capture 0.2.1 is refused at Start and failed at Stop.
- **web**: tsc clean; eslint 0 errors (the 20 base warnings, none in a changed file); vitest **726 passed (62 files)**.
  New: Remove script (confirm, one DELETE, refetch, jest-axe on the dialog), its 409 in place (jest-axe), no button
  without a script; the restore toast; `transitionMessage`; the `case-script-remove` contract check.
- **Bundle**: `96354a8` is `web/static` only; a rebuild followed and `git status --short --untracked-files=all` was
  empty in its own call; the reviewer's out-of-tree build was identical.
- **genesis-workflows**: `validate_library` PASSED (18), `validate_skills` PASSED (4), pytest **428 passed**; ruff clean
  on the four testing workflows + `ci`.
- **playwright-appian**: lint and typecheck clean; three consecutive sequential full `npm test` runs at `f00cebb`:
  **1399/1399** each (`agent-act` 4.72 / 4.61 / 4.51 s, `agent-do` 4.68 / 4.59 / 4.58 s). No behaviour changed, so no
  `DECISIONS.md` row (D19); no version bump (51-13 releases 0.3.0).

### Review

`reviews/51-18-review.md`. First pass **SHIP** (no blocker or major) with m1–m4 and n1–n7; decisions (a)–(h) agreed.
Fixed in `0a5d342` / `f00cebb`: m1 (queued executions), m2 (named files), m3 (`agent-do` timeout), m4 (test), n3, n5.
Delta re-review **SHIP**, with one new minor, m5 (a running story verification was not refused; older than the delta),
fixed in `346f885` with tests that fail on `0a5d342` (not re-reviewed: the 51-12 live re-run reviews the range again).
Left as they are: n1 (drift reference commit read from `library.json`; outside the threat model), n2 (a proposal could
write a fake `ACT-` step title; strictly better than "imported"), n4 (`story_context` scans per case; cached after the
first read). For others: **n6** and **n7** below; O2 and O4 (`agent-idle` under load average ~25) for the backlog.

### Decisions / deviations

No ADR deviation.

1. **(a)** The scanner runs over texts in a scratch folder with Genesis's template scanner: the generator reads
   committed text, which the working tree may not hold, and the template is the scanner `sync_lib` converges on. No
   `sync_lib` commit on a read path.
2. **(b)** Tests without node read a recording of the real scanner (keyed by text hash, re-checked against a fresh scan
   locally), never a Python imitation (L-083).
3. **(c)** Remove script runs the full typecheck and refuses only errors outside `suites/` (regenerated before every
   execution).
4. **(d)** A paused worker's late terminal `final` is dropped: the pause wins (ADR-009); Resume finishes a thread that
   is already at END (tested).
5. **(e)** The drift reference commit is the export commit in `library.json`; the comparison runs against the
   workspace repository outside the run folder.
6. **(f)** An older test-execution (no `results.actions`) proves no action (logged); no execution-start gate.
7. **(g)** action-capture matches a new action proposal by `ACT-NEW <name>` (name read with the scanner); a shared name
   proves neither.
8. **(h)** Recordings need action-capture ≥ 0.2.2 and compose setup-composer ≥ 0.1.1, because an older workflow could
   prove code its replay never ran.
9. **L-089 slips (process, no harm).** The `web/static` commit was issued in one tool batch with the build; the
   post-commit rebuild left the tree clean and the reviewer's out-of-tree build was identical. Three playwright-appian
   full runs were once issued in one batch and ran at the same time (many timeouts); they were discarded and the three
   runs above were each issued alone.

### Lesson candidates

- **A second reader of a contract breaks on inputs the first one handles.** The regex roles reader stopped at the first
  callback-looking word; the TypeScript scanner did not. Route every consumer through one reader, and make tests that
  cannot run it read its recorded output, re-checked against it, never an imitation.
- **"Used" must mean "ran", not "imported".** A proof that walks the import graph promotes code that never executed;
  record a per-unit step in the run itself (`test.step` per action) and prove only what passed there.
- **A selection's shape differs by status and kind.** A queued execution keeps only `scenario_ids`, and a running
  verification never gets a plan; a check written against one shape silently misses the others (review m1, m5).
- **L-089 recurrence:** the tool runs calls of one message in parallel even when they are separate calls; a sequence
  of full test runs or a build and its commit must be one call per message.

### Code-map changes

- `genesis/testexec/roles.py` (new): `case_role_of`, `setup_roles_of`, `scan_texts`, `read_defines`, `RoleReader`.
- `genesis/testing/scan_recording.py` (new, test support): `use_recorded_scanner`, `recorded_scan_for`, `real_node_modules`.
- `genesis/testexec/generator.py`: `Roles` protocol, `build_catalog(role_reader=)`; regex readers removed.
- `genesis/testexec/replay.py`: `action_steps`, `passed_action_keys`; `replay_outcome` returns `actions`.
- `genesis/testexec/library_service.py`: `remove_case_script`, `CaseScriptInUse`, `_executions_running`;
  `promote_proven_actions(passed_actions=)`.
- `genesis/testexec/workspace.py`: `library_drift`, `LIBRARY_DIRS`, `RuntimeUpdateRefused`, `_update_tsconfig`.
- `genesis/integrations/apwt/factory.py`: `ApwtFactory.library_drift`.
- `genesis/testexec/recording.py`: `PROOF_WORKFLOW_VERSION`; `compose.py`: `COMPOSE_WORKFLOW_VERSION` 0.1.1.
- `genesis/domain/transitions.py`: `ACTION_TRANSITIONS`, `ACTION_PRECONDITIONS`, `ACTION_PRECONDITION_REASONS`.
- `genesis/api/testing.py`: DELETE `…/test-cases/{case_key}/script`.
- web: `AutomationBadge.CaseScriptView` Remove script; `logic.transitionMessage`; `testingApi.removeCaseScript`;
  `CaseScriptRemoved`.
- templates: `tsconfig.json` `noUnusedLocals`; `lib/index.ts` `defineAction` → `test.step`; `lib/scan-refs.mjs` case role.
- genesis-workflows: `action_steps` in test-execution, action-capture, setup-composer; `library_drift` / `drift_error`
  and `action_proposal_status` in action-capture; versions 0.1.1 / 0.2.2 / 0.1.1.

### For 51-13 and the 51-12 live re-run

- **51-13 (n6, L-057):** genesis-workflows' pins (`genesis.git@v0.80.0`) must move to the Genesis tag that has
  `genesis.testing.scan_recording` and `ApwtFactory.library_drift`. Without it, story-verification's tests fail in CI,
  and action-capture 0.2.2 / setup-composer 0.1.1 refuse every replay (fail-safe: "update Genesis"). Release
  test-execution 0.1.1, action-capture 0.2.2 and setup-composer 0.1.1 together with Genesis; with older workflows,
  Record and Compose refuse (409) and an execution proves no action.
- **genesis-docs (n7):** `genesis-ctx` maps `genesis/genesis/testexec/**`, `genesis/web/src/features/testing/**` and
  `genesis/genesis/testing/**` to no area; add them to browser-testing (or a testing area).
- **Live steps:**
  - `genesis install` test-execution 0.1.1, action-capture 0.2.2, setup-composer 0.1.1; restart `serve` with no run
    active (L-061). No migration (DB stays v28).
  - Existing workspaces: Settings shows "Update testing runtime" (the new `tsconfig.json`). If existing code has unused
    imports, the update names them and stops before that commit. The first save or compose after this change adds an
    "Update Genesis's lib/ helpers" commit (the new `lib/index.ts` and scanner).
  - Expect: a passing execution, recording or compose promotes only the actions whose `ACT-… <name>` step appears and
    passed in its report (visible in the Playwright HTML report as a nested step); Remove script on a case page; a
    restored action reads Draft; a paused run stays paused across a `serve` restart (step 22).
  - Not verified here: a real Kiro turn, a QA replay, the nested step in a real QA run, the dialogs in a real browser.
