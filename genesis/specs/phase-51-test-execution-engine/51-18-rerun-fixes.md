# 51-18 — Fixes from the 51-12 re-run

> **Status:** SPEC-DRAFTED 2026-11-05. Repos: **genesis** (backend + web), **genesis-workflows** (`action-capture`,
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

## As built (session 1, 2026-11-07, genesis-dev) — IN PROGRESS, see the Resume note

**Task restated.** Close the 51-12 re-run's findings (review `reviews/51-12-review.md` → Re-run): R-MJ1 one roles
reader (the scanner) for setup and case roles, R-m1 a paused run stays paused on a read in a new process, R-m2 a
replay refuses a checkout whose library files differ from the export commit, R-m3 `noUnusedLocals` + per-action
`test.step` proofs, R-m4 a retired action restores to Draft, R-m5 Remove script (route + page), R-n1 drop a paused
worker's late events, R-n2 promotion off the reader thread, R-O1 the playwright-appian `agent-act` timeout. Rules:
ADR-009 (pause/resume), ADR-011 (the trio stays on every agent node), ADR-050 (status only through
`LifecycleService`), ADR-067 (healing unchanged), ADR-012 (workflow `graph.py` standalone: copies pinned by parity
tests); lessons L-011/L-083 (fixtures from real responses and real scans), L-039, L-058, L-089, L-091 (lock before
validate), L-093, L-094. No ADR deviation so far.

### Commits (session 1)

Base: genesis `2b2cf9d`, genesis-workflows `69bface`, playwright-appian `5d7ae2d`. Local only.

| Repo | Commit | What |
|---|---|---|
| genesis | `51e55f9` | R-m1 + R-n1 (`runs/manager.py`) and their tests |
| genesis | `e75a668` | R-MJ1 (`testexec/roles.py`, every consumer), R-n2, R-m4 (backend), R-m5 (backend route + service), contract fixture `case-script-remove` |
| project-tracker | this commit | this section; the 51-10 table row for DELETE `…/script` |

### Changed so far (genesis)

- **R-m1** `RunManager.reconcile_status` returns a `paused` record unchanged (as `fail_orphaned_runs` already did).
- **R-n1** `_spawn.on_event` returns at once for ANY intended stop (`seen["stop"]` set by `pause` or `cancel`); the
  per-branch checks it replaced are gone. Per worker, so the resumed worker's events still count.
- **R-n2** `TestExecutionFinalizer.finalize_run` hands `_promote_actions` to `self._defer`.
- **R-m4** `domain/transitions.py`: `ACTION_TRANSITIONS` (`LIBRARY_TRANSITIONS` + `(retired, restore) → draft`),
  `ACTION_PRECONDITIONS` / `_REASONS` (no restore precondition; retire rules kept). `build_library_lifecycle` uses them
  for `TEST_ACTION` only; setups keep restore → ready after a passing Replay. Exported from `genesis.domain`.
- **R-m5** `TestLibraryService.remove_case_script` + `CaseScriptInUse`: one commit "Remove the script of TC-…"
  (`ws.change({path: None}, typecheck=False)` with its own typecheck that ignores `suites/` errors — only the
  generated suites import a case file, and they are regenerated before every execution), then
  `TestScriptStore.delete` (binding + refs, `not-automated`). Refused while a queued/running execution's plan has a
  step of the case; the check runs again inside the workspace lock (L-091). Route `DELETE
  /applications/{app}/test-cases/{case_key}/script` → 200 `{case_key, removed, commit, automation_status}` / 404 /
  409 `problems`.
- **R-MJ1** new `testexec/roles.py`: `case_role_of` / `setup_roles_of` (pure, on the scanner's `defines`),
  `scan_texts` (texts into a scratch folder with a copy of `templates/lib/scan-refs.mjs` and a `node_modules` link →
  one `node` run), `read_defines` (cache by text sha256, 4096 entries), `RoleReader(node_modules)`
  (`prefetch` / `case_role` / `setup_roles`). `generator.build_catalog(role_reader=)` is required; the regex readers
  (`case_script_role`, `case_role_unreadable`, `setup_extra_roles`, `_CALLBACK_RE` …) are removed. Consumers:
  execution catalog (`ws/node_modules`), `VerificationTools.catalog` (`checkout/node_modules`), `story_context(role_reader=)`,
  library save warning (`case_role_of` on the save's own scan entry), library Replay `_setup_roles`, compose
  `_extra_roles`, GET case script. An unreadable file → its scenarios are not automated with "Genesis could not read
  <path>: <reason>". The template scanner now lists a non-string literal `role` (e.g. `role: 5`) in a case's
  `dynamic` (as the old regex treated it); existing workspaces get the new `lib/` through `sync_lib` (an
  "Update Genesis's lib/ helpers" commit).

### Tests so far

- `tests/test_runs.py` +3: the reviewer's probe (`test_a_read_in_a_new_process_leaves_a_paused_run_paused`), a paused
  worker's late node event, pause → fresh RunManager → resume from the checkpoint (real worker). The first two fail
  on `2b2cf9d` (checked with the fix stashed).
- `tests/test_testexec_roles.py` (new, 27): the 5 tricky setups (`async`, `function`, `=>` in the name, a block and a
  line comment in `roles`) through the reader, the generator + readiness (`Catalog.roles`, `setup:` depends on
  `auth:approver`), the library Replay and compose; 8 case-option shapes; a scanner failure → not automated with the
  reason; the recording equals a fresh real scan; the parity check (generator's scratch-folder reading == the
  in-place scan of a real workspace == the workflows' recorded scans) over every setup/case fixture of genesis-workflows'
  action-capture and setup-composer and every recorded Genesis fixture. The old regex reader returns `[]` for all 5
  tricky setups (checked by loading `2b2cf9d`'s `generator.py`).
- `tests/scan_fixtures.py` (helper, not a test module) + `tests/fixtures/testexec/scan-recorded.json`: the REAL
  scanner's `defines` per text (TypeScript 5.9.3) for the suites that stub npm (execution, regression, story
  verification, the API, generator, compose catalogs). A new text fails with "run with GENESIS_WRITE_SCAN_FIXTURES=1".
  The genesis CI python image has no node, so this keeps those suites running there.
- `test_testexec_execution.py`: R-n2 (the promotion waits for the deferred call), R-m5 (409 naming the running
  execution, then one commit, binding gone, scenario not automated, second remove 404).
- `test_testexec_store.py`: an action restores to Draft (audit row `retired → draft restore`); a setup still needs a
  passing replay at the current hash to restore to Ready.
- `test_testing_api.py`: DELETE script in the every-route test (fixture recorded; value-only fixture churn reverted).
- Run: `pytest tests/test_testexec_*.py tests/test_story_verification*.py tests/test_testing_api.py tests/test_runs.py`
  **377 passed**; `ruff check genesis` clean. The full suite, web, workflows and playwright-appian gates are NOT run yet.

### Resume note (what is next, in order)

1. **R-m3 (both repos).**
   - genesis `templates/tsconfig.json`: `"noUnusedLocals": true` (reaches old workspaces through "Update testing
     runtime" — check which job rewrites `tsconfig.json`; if none does, add it to `sync_lib`'s file set or the update
     job). Test: a save importing an unused action is refused by tsc.
   - `templates/lib/index.ts` `defineAction`: `import { test } from '@playwright/test'`; the action body runs inside
     `test.step(\`${meta.key} ${meta.name}\`, () => fn(withAppian(ctx), input))`.
   - One pure parser `action_steps(result)` (walk nested `steps` of the final attempt; titles `^(ACT-(\d{6}|NEW)) (.*)$`;
     an action passed only if every occurrence passed) in `genesis/testexec/replay.py`, copied into
     `test-execution`, `action-capture` and `setup-composer` `graph.py` with a cross-repo parity test (as
     `replay_outcome`).
   - test-execution `normalize_report`: per scenario and per setup project `actions: [{key, name, status}]`; bump
     test-execution 0.1.0 → 0.1.1 (META + `workflow.yaml` + `registry.json`).
   - Genesis `promote_proven_actions(..., passed_actions: set[str])` (required): promote only reached Draft actions
     whose key is in it (intersection with today's closure/hash rule). Finalizer: the set = actions passed inside passed
     scenarios and passed setup projects; no `actions` key (older test-execution) → promote nothing, logged.
   - action-capture setup mode: each action proposal's replay status = its own action step (title `<key> <name>` from
     the scanner reading of the proposal file; ambiguous titles → not-run); `result.replay.actions` carries the passed
     library keys for reuses. setup-composer: `result.replay.actions`. `ProposalService._prove_used_actions` passes
     those keys (missing → none). Bump action-capture 0.2.1 → 0.2.2, setup-composer 0.1.0 → 0.1.1; Genesis's version
     gates (`SETUP_WORKFLOW_VERSION`, `COMPOSE_WORKFLOW_VERSION`) stay (an older workflow proves nothing new: fail-safe).
   - Tests: an imported-but-uncalled action and one in a branch not taken stay Draft; a called one is promoted (execution
     finalizer, capture apply, compose apply). Update `_results_for` in `test_testexec_execution.py` to carry actions.
2. **R-m2 (workflows).** In `action-capture` and `setup-composer` `replay` (before Playwright): compare every file under
   `actions/ setups/ cases/ lib/` of `<run>/checkout` with the export commit's bytes — Genesis gives the run a manifest
   at prepare (`<run>/library-manifest.json` = `{path: sha256}` of the export; written by `RecordingService` /
   `ComposeService` `prepare`, outside the checkout so the agent's edits cannot change it); any difference outside
   `proposed/` fails the replay with the paths named (`status: error`, healing does not run: route straight to the
   gate). Test: an agent-modified transitive action leaves the setup Draft and the run says why.
3. **Web (R-m4, R-m5).** `LibraryItemPage` transition success: action `retired → draft` → "Restored to Draft — Run
   dependents to make it Ready". Case page (`features/test-design/**`, the case script panel): **Remove script** button →
   confirm dialog → `testingApi.removeCaseScript` (`lib/api/testing.ts`, type in `types/testing.ts`, fixture
   `case-script-remove` in `contract.test.ts`); 409 shows the executions. Tests + jest-axe. Then the L-089 bundle
   sequence (build, wait, commit `web/static` alone, rebuild, `git status` in its own call).
4. **R-O1** playwright-appian `tests/cli/agent-act.test.ts` "a ref without an address…": measure alone vs full run;
   fix the cause or give it an explicit timeout with the measured times in a comment; `npm run lint`, `typecheck`,
   `build`, `npm test` ×3 green. `DECISIONS.md` only if behaviour changes.
5. Gates: full genesis pytest + ruff; workflows `validate_library`, `validate_skills`, pytest; web lint/tsc/vitest;
   the cross-repo tests locally. Then genesis-review (base genesis `2b2cf9d`, genesis-workflows `69bface`,
   playwright-appian `5d7ae2d`), fix to SHIP, finish this As built.

### Decisions so far

1. **(a) The scanner runs over texts in a scratch folder** with Genesis's template scanner (not the workspace's copy):
   the generator reads committed text (`git show`), which the working tree may not hold, and the template is the
   scanner every workspace converges on (`sync_lib`). No `sync_lib` commit is needed on a read path.
2. **(b) Tests without node read a recording of the real scanner** (keyed by text hash, re-checked against a fresh
   scan locally) instead of a Python imitation of it (L-083).
3. **(c) Remove script skips the save's full typecheck** and refuses only type errors outside `suites/`.
4. **(d) A paused worker's late terminal `final`** is now dropped too (it was processed before): the run stays paused
   and Resume finishes it from the last checkpoint (ADR-009).

### Lesson candidates (so far)

- **A second reader of a contract breaks on inputs the first one handles.** The regex roles reader stopped at the first
  callback-looking word; the TypeScript scanner did not. Route every consumer through the scanner, and make the tests
  that cannot run it read its recorded output, checked against it, not an imitation.
