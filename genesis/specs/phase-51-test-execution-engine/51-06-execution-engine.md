# 51-06 — Execution engine: generated specs, data setups, runs, results, queue, impact runs, schedule

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: **genesis** (backend), **genesis-workflows** (`test-execution` v0.1.0).
> Parent: `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D1, D2, D5, D8, D10, D11, D14, D16.7; F6, F7,
> F8, F9, F11, F13.

## 1. Goal

Turn a selection of scenarios into one **test execution** that runs the **committed** workspace on QA with no agent,
builds each data setup once, and stores per-scenario and per-case results. Three entry points share it: ad-hoc
("Run" on a scenario/suite), **Run impacted tests**, and the **`regression-run`** schedule job. Story verification
(51-09) calls the same runner inside its own workflow.

## 2. Spec generator (`genesis/genesis/testexec/generator.py`, deterministic, program only)

Input: the selected scenario ids. Output files in the workspace (committed, F5) — never hand-edited:
- `suites/auth/<role>.setup.ts` — one Playwright **setup project** per role used: logs in with `loginAs(role)` and saves
  `storageState` to `.auth/<role>.json` (Playwright's authentication recipe); `.auth/` is git-ignored.
- `suites/setups/<DS-key>[.<TS-key>].setup.ts` — one setup project per **data setup instance** (D10): runs the setup's
  `defineSetup` function and writes its outputs to `$GENESIS_RUN_DATA/<instance>.json`. A scenario flagged
  `changes_shared_data` gets its own instance `<DS-key>.<TS-key>` (D10.4).
- `suites/<instance or "none">/<NNN>-<TS-key>.spec.ts` — one file per scenario, numbered for order (read-only first, then
  regression/feature position, D10.5). Body: `test('<TS-key> <title>', { tag: ['@<TS-key>', '@<instance>'] }, async
  ({ … }) => { const data = setupData('<instance>'); await test.step('<TC-key> <title>', () => <case fn>(ctx)); … })`
  — one `test.step` per scenario step, so results map back to cases (D2). A step's role (the case script's declared
  role, else the scenario's setup role) selects the browser context with that role's `storageState`.
- `playwright.config.ts` — projects: `auth:<role>`, `setup:<instance>` (depends on the roles it uses), `scn:<instance>`
  (depends on its `setup:` project), `scn:none`; F6 settings (`workers: 1`, `retries: 1`, `globalTimeout`,
  `actionTimeout: 15_000`, reporters `json` + `junit` + `html` into `$GENESIS_REPORT_DIR`, `trace:
  'retain-on-failure'`, `screenshot: 'only-on-failure'`, headless, `use.channel` from the browser setting).
- A scenario is **automated** only when every step's case has a case script; non-automated scenarios are never
  generated (the caller lists them, F9).
- Golden-file tests pin the generated text for fixed DB fixtures.

## 3. Preparing an execution (`genesis/genesis/testexec/execution_service.py`, app process)

1. `readiness(app_uuid)` (51-05 §6) → 409 with the list when blocked; QA host checks (D8.1).
2. Resolve the selection → automated scenarios + setup instances + roles; create the `kb_test_executions` row
   (`queued`, `TE-` key, trigger, selection).
3. When it is this machine's turn (F7, §6): regenerate `suites/` + config; commit if changed (message names the `TE-`
   key); record `workspace_commit`; `TestWorkspace.export(commit, <run folder>/checkout)`; start the run.

## 4. `test-execution` workflow (genesis-workflows `workflows/test-execution/`, program nodes only)

Inputs: `execution_key`, `app_uuid`, `checkout_dir`, `qa_url`, `site_path`, `roles[]`, `projects[]`, `grep`,
`global_timeout_s`. No agent node, so the reliability lint has nothing to wrap; `required_cli: []`
(the runner is reached through `ctx.extras['apwt']`, 51-05 §4).
- `prepare_env` — builds the child environment: `SITE_URL`, `GENESIS_RUN_DATA`, `GENESIS_REPORT_DIR`,
  `GENESIS_TEST_USER_<ROLE>`/`GENESIS_TEST_PASSWORD_<ROLE>` from `TestCredentialResolver` — in memory only, never in
  state/checkpoints/events (ADR-010).
- `run_playwright` — `npx playwright test --project … --grep …` in `checkout_dir`, started through
  `procs.start_long_lived(argv, cwd=checkout_dir, env=…, pid_dir=<run>/.pids, markers=[checkout_dir,
  settings.testing_browsers_dir])` (51-05 As built 7), so the RunManager's reap on cancel, pause and the startup sweep
  stops it; timeout =
  `global_timeout_s` + 120 s (Playwright stops first and still writes its reports, per its CI guidance); off the event
  loop (L-026).
- `parse_results` — the JSON report → `results.json` (normalized: per scenario status passed/failed/flaky/skipped,
  attempts, duration, error; per step the `TC-` key from the step title, status, error; attachments as paths relative to
  the report dir). A scenario skipped because its `setup:` project failed → **blocked** (D10.6); steps after a failed
  step → **not-run**. Parse defensively (L-023).
- `present` — `result.json` `{status, totals}`.

## 5. `TestExecutionFinalizer` (`genesis/genesis/testexec/finalizer.py`, app process)

The finalizer pattern (`genesis/genesis/chat/story_implementation_finalizer.py`): observe `run.final` for
`test-execution` (and, for 51-09, the verification workflow's execution step output), guard by the bound run, idempotent,
startup + on-read reconcile (L-058, L-061), status stored before any announcement (L-093). It writes all results in one
transaction, sets the execution status (passed = no failed/blocked; failed = any failed; blocked = blocked without
failures; error = no report), sets `automation_status = automated` for every case that has a script and ran (`broken`
is set only by verification triage, 51-09), applies file retention (F11: executions beyond the newest 20 per app lose
their report files; `files_pruned_at` set), then starts the next queued execution (§6). Failures are loud (logged with
the execution key), never silent.

## 6. Queue (F7)

One execution at a time per machine: `start()` marks `queued` when a `test-execution` or `story-verification` run is
active; the finalizer starts the oldest queued one; startup reconcile starts queued work and finalizes runs that ended
while the app was down. Cancel a queued execution = status `cancelled`, no run.

## 7. Run impacted tests (F9)

`start_impact(app_uuid, source)` reuses `TestImpactService.impact` (`genesis/genesis/services/testimpact.py`) → the
affected case ids → every automated scenario (feature or regression) containing one → one execution (kind `impact`,
trigger = the impact source). The response also lists affected cases with no automated scenario ("not covered by
automation").

**From 51-04 (deviation 7):** `TestImpactService._scenario_steps` currently returns **feature** scenarios only, because
`_assemble` keys suites by feature and a regression scenario (no feature) raised `KeyError` on `suites[None]`. This
sub-spec removes that guard and adds the app's regression suite to the impact result as its own group (scenarios →
cases, direct and indirect), with a test that an impact read covering a regression scenario returns it and does not
raise.

## 8. `regression-run` schedule job (D11, F13)

A new `DEFAULT_JOBS` entry (`genesis/genesis/runtime/sync_jobs.py:37`) with handler registration like
`register_sync_jobs`. Job cadence: every hour (`interval_window`, 1 h, all day); the handler reads per-app settings from
the job's `options_json` (`{apps: {<app_uuid>: {cadence: off|daily|weekly, days: [0-6], time: "HH:MM"}}}`, default off
for every app, L-081) and starts a `regression` execution for each app whose own slot fell since its last regression
execution (at most one catch-up per app after downtime). It never starts a second one while the app's previous
regression is queued or running. ADR-047's fixed-job rule holds (one backend-defined job); 51-13 records the per-app
cadence inside its options as an ADR-047 note.

## 9. Tests

Generator golden files (setups, private instances, roles, ordering, non-automated exclusion); execution prepare →
commit → export (temp git repo); the workflow's nodes with a stub `npx playwright` that writes a real-format JSON report
(copied from a real 1.59.1 run, L-083); setup-failure → blocked mapping; flaky mapping; finalizer idempotency + bound
run + reconcile through the real `RunManager._finalize` (L-093); queue ordering; impact selection; schedule slot
computation (daily/weekly, catch-up once, off); no credential in checkpoints/events (assert on the stored rows);
process group killed on timeout.

**Carried from 51-05 (review minor 7), checked live on this machine (no QA needed):** start one real `npx playwright
test` run from an export whose `node_modules` is a symlink (`TestWorkspace.export` → `linked`), then show that
`procs.reap(<run>/.pids)` recognises a process in its group by the export path or the browsers folder and that `ps`
shows nothing of that run afterwards. Fix the marker check if it does not.

## Context manifest

```toml
areas    = ["runs-worker", "workflows-library"]
adrs     = ["ADR-001", "ADR-010", "ADR-011", "ADR-012", "ADR-018", "ADR-022", "ADR-047", "ADR-079"]
lessons  = ["L-005", "L-020", "L-023", "L-026", "L-033", "L-058", "L-061", "L-062", "L-081", "L-083", "L-093", "L-097"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/runtime/sync_jobs.py", "genesis/genesis/runtime/scheduler.py", "genesis/genesis/services/testimpact.py", "genesis/genesis/runs/manager.py", "genesis-workflows/workflows/test-execution/**"]
upstream = ["51-04", "51-05"]
```

## As built (2026-11-03, genesis-dev)

**Task restated.** Turn a selection of scenarios into one test execution that runs the committed workspace on QA with
no agent: a deterministic generator writes `suites/**` + `playwright.config.ts`; the app process regenerates,
commits and exports that commit into `<run>/checkout`; the program-only `test-execution` workflow runs `npx
playwright test` through `procs.start_long_lived` and normalizes the JSON report; the `TestExecutionFinalizer`
writes the results through the real `RunManager._finalize` path; one execution at a time per machine; Run impacted
tests (with the regression suite now in the impact result); the `regression-run` job, every app off by default.

**Applicable rules.** ADR-001/011 (program nodes only; nothing for the trio to wrap), ADR-010/018 (no credential in
state, checkpoints, events or files; bulk in the run folder), ADR-012 (the worker reaches Playwright through
`ctx.extras['apwt']`; the app never imports `graph.py`), ADR-022 (run folder; F11 retention), ADR-047 (one fixed
job, per-app cadence in options), ADR-079 (impact on demand, stores nothing), ADR-021 via the user's D22 (no
`pre_mutation` gate; ADR-082 amends it at 51-13). Lessons L-005, L-020, L-023, L-026, L-033, L-058, L-061, L-062,
L-081, L-083, L-093, L-097, plus L-011 (web contract), L-056/L-089 (commit check, bundle proof), L-092, L-096.

### Commits

- **genesis** (base `c18d1a7`, local, not pushed or tagged): `ee1b77c` feat(testexec,51-06) — the whole change incl.
  all review fixes; a separate `git status --untracked-files=all` afterwards was empty (L-056/L-089).
- **genesis-workflows** (base `a365e60`, local): `5a24d17` feat(test-execution,51-06) — `test-execution` 0.1.0;
  `git status` afterwards empty.
- **project-tracker:** this As built and `reviews/51-06-review.md` (first pass, re-review, third pass).

### Changed (genesis)

- `testexec/generator.py` (new) — `build_catalog(conn, app, script_text=…)` reads the app's non-retired scenarios
  (feature + regression), case scripts at the workspace HEAD, setups and test users; `generate(catalog)` → `{path:
  text}`; `projects_for`, `grep_for` (tags anchored with `(?=\s|$)`, only `.` escaped). Layout and file text as §2,
  plus a generated `suites/_support.ts` (`RolePages`, `setupData`, `saveSetupData`, `authFile`, `CaseContext`).
  Order in a folder: changes-shared-data last, then regression references (item order), regression-owned, other
  feature scenarios. Role: the script's literal `defineCase('<TC>', { role: '…' })` → the setup's `role_key` → the
  app's only test user; a role written any other way, a missing / uncommitted script, a retired or uncommitted
  setup, or no role → not automated with a reason.
- `testexec/runner.py` (new) — `PlaywrightRunner` (`env_plan`, `argv`, `run`): credentials resolved at spawn into
  the child env only (`GENESIS_TEST_USER_<ROLE>` / `GENESIS_TEST_PASSWORD_<ROLE>`, role upper-cased, `-`→`_`);
  `start_long_lived(pid_dir=<run>/.pids, markers=[checkout, browsers], log_path=<run>/report/playwright.log)`; hard
  timeout `global_timeout_s + 120`; `_scrub` replaces every password in the whole report folder — text files, the
  HTML report's embedded base64 zip, every zip incl. nested ones (traces) — review B1.
- `testexec/execution_service.py` (new) — `TestExecutionService`: `catalog`, `plan`, `start` (readiness 409 /
  nothing automated 400), `start_impact`, `regression_scenario_ids`, `start_regression`, `cancel`, `busy`, `pump`
  (process lock; a launch failure ends that execution `error` and the next is tried), `_launch` (regenerate +
  commit naming the `TE-` key, `RunManager.start(prepare=…)` → export + `set_running` with the plan and the
  reproducibility columns before the worker spawns), `list`, `detail` (results tree), `report_file` (traversal
  guarded).
- `testexec/finalizer.py` (new) — `TestExecutionFinalizer` (live `run.final` for done/failed/cancelled, bound run,
  CAS-idempotent, `reconcile` at startup, `reconcile_execution` on read; the ghost-fail of a running execution with
  no run record only at startup and only under the run-owner lock, review m2); `result_rows`, `outcome`;
  after-steps: `automation_status` (never over `broken`), delete `checkout/.auth`, F11 prune (report + checkout,
  only under the artifacts root), pump (deferred thread).
- `testexec/regression_job.py` (new) — `REGRESSION_JOB` (hourly `interval_window` 00:00–23:00, IST, enabled, no
  default options), `latest_slot`, `is_due`, `register_regression_job` (handler off the loop).
- `testexec/workspace.py` — `write_generated` (remove stale generated files, write, commit ONLY the generated paths —
  review m4; `_commit_staged(paths=)`); `@types/node` substitution.
- `testexec/runtime.py` + `templates/package.json` — `TYPES_NODE_VERSION = "20.19.43"` (the generated config and
  support file use Node's types; found by the live typecheck).
- `testexec/procs.py` — `start_long_lived(log_path=)`.
- `integrations/apwt/factory.py` — `ApwtFactory.playwright(app, run_dir)`.
- `runs/manager.py` — `start(prepare=…)`: called with `(run_id, run_dir)` before validation, the record and the
  spawn; on failure the run folder it created is removed (review m3).
- `kb/testexec_store.py` — `set_running(selection=)`, `by_status`, `list(status=)`.
- `services/testimpact.py` — the 51-04 feature-only guard is gone; `_scenario_steps` returns regression scenarios
  (`suite_kind`), `_assemble` adds `regression: {hop, scenarios: [{id, key, title, hop, cases, referenced}]} | null`
  (references first in suite order, then owned); `totals.scenarios` stays feature-only.
- `runtime/sync_jobs.py` — `REGRESSION_JOB` in `DEFAULT_JOBS`.
- `api/testing.py` — `register_execution_routes`: `GET/POST /applications/{app}/testing/executions`, `GET
  …/{key}` (on-read reconcile), `POST …/{key}/cancel`, `GET …/{key}/report/{path}` (`no-cache` on `index.html`,
  L-068), `POST /applications/{app}/test-impact/run`. `ImpactBody` imported at module level (a local import made
  FastAPI read the body as a query parameter).
- `api/app.py` — service + finalizer wiring, routes, regression job, startup reconcile after the orphan sweep.
- Web (types/tests only): `ImpactResult.regression`, `ImpactRegression`, `ImpactRegressionScenario`; contract test;
  `impact-result.json` regenerated from a real API read with a regression reference and an owned scenario.
  `npm run build` then `git status`: `web/static` unchanged (no bundle commit).
- `scripts/spikes/51-06/live_report.py` + `evidence/{report-1.59.1.json, reap.json, scrub.json}`.

### Changed (genesis-workflows)

- `workflows/test-execution/` (new, 0.1.0): `graph.py` (`prepare_env → run_playwright → parse_results → present`;
  `normalize_report`, `totals_of`, `execution_status`), `workflow.yaml` (META parity + `graph:`), tests, a copy of
  the recorded report; `registry.json` entry.

### Tests

- genesis `tests/test_testexec_generator.py` (7): catalog decisions, golden files
  (`tests/fixtures/testexec/generated/**`, `GENESIS_WRITE_GOLDEN=1`), layout/order/config, grep anchoring, role
  parse, unsafe path/role refusal, string escaping.
- genesis `tests/test_testexec_execution.py` (29): prepare → commit → export (real git, `node_modules` linked, no
  `.git` in the checkout, no password in the job or the row); uncommitted script; readiness refusal; live finalize
  through the real `RunManager._finalize` + the queue + `.auth` deletion + idempotency; `broken` kept; bound run;
  failed → error, cancel → cancelled; cancel queued; done without results; startup and on-read reconcile (ghost
  only at startup); queue waits for `story-verification`; a queued execution that cannot launch; result-row
  mapping; impact selection + not covered; F11 retention (incl. outside-root guard); routes (404/400/409, no-cache,
  traversal `..`/encoded/absent, no secret in any response); on-read reconcile via GET; impact-run body; runner
  timeout kills the group and a grandchild + scrub; role without credentials; `start(prepare=)`; regression slots
  (daily/weekly/off/invalid/catch-up once/since) and the handler (off by default, user options survive
  `ensure_defaults`, skip while running, slot covered); review fixes B1 (embedded HTML zip, trace and nested zips),
  m2, m3, m4, m5.
- Updated: `test_testexec_store.py` (regression group replaces the 51-04 "skip for now" test), `test_test_design_api.py`
  (fixture with a regression suite), `test_sync_jobs.py`, `test_testexec_workspace.py` (`@types/node`).
- genesis-workflows `workflows/test-execution/tests/test_test_execution_workflow.py` (6): `normalize_report` on the
  real 1.59.1 report (passed / failed step + unreached step / blocked by setup / flaky / two roles), defensive
  shapes, global timeout → not-run, the whole graph with the real runner and a stub `npx` that replays the report
  and writes a real-shape HTML report + trace (credential scan decodes zips; DB dump incl. checkpoints, state,
  events), no report → fails (and an unrelated env var never reaches the child), role without password.
- Gates before the review: genesis ruff clean, pytest 1560; web lint 0 errors (20 old warnings), typecheck clean,
  vitest 467, build → `web/static` unchanged; genesis-workflows validate_library PASSED (15), validate_skills
  PASSED, pytest 322. **Final (after every fix):** genesis `ruff check genesis` clean, pytest **1570 passed** (1529
  at 51-05 + 41); genesis-workflows validate_library PASSED (15 workflows), pytest **323 passed**, ruff clean on
  `workflows/test-execution`; web unchanged since the first gates (vitest 467, bundle identical).
- **Live, this machine (no QA)** — `scripts/spikes/51-06/live_report.py`, through the product code: real
  `TestWorkspace` create + `npm install` (352–422 s on this network), generator output + a shim `lib/index.ts`,
  `tsc` clean (after adding `@types/node`), export `linked`, a real `@playwright/test` 1.59.1 run against a local
  HTTP site (9 s): the report recorded as `evidence/report-1.59.1.json` (the stub's fixture, L-083); `--grep`
  excluded the unselected scenario while the setup and auth projects still ran. **§9 reap check:** a second run in
  flight, `procs.reap(<run>/.pids)` matched the group by the export path (`node …/checkout/node_modules/.bin/playwright
  test …`, 51-05 minor 7); Chromium ran in its **own** process group yet `ps` showed nothing of the run 1 s after the
  reap (51-05 nit 12) — `evidence/reap.json`. **Scrub (after B1):** a decoded scan of the whole report folder (46
  files, the embedded HTML zip and 8 trace zips) found no password, and the HTML zip held `Fill "***"` — the leak was
  real and is gone (`evidence/scrub.json`).

### Review

`reviews/51-06-review.md`, first pass **NEEDS_CHANGES**: B1 (the HTML report's embedded zip held every test user's
password — Playwright titles fills `Fill "<value>"` and the HTML reporter keeps passing auth tests' steps); minors
m1 (global timeout → skipped / passed), m2 (L-097 ghost-fail without the lock), m3 (prepare failure left files), m4
(regeneration committed the whole index), m5 (non-literal role silently fell back), m6 (51-07 contract); nits n1–n6.
Fixed: B1, m1–m5 with tests; m6 and the nits are recorded below. **Re-review NEEDS_CHANGES:** R1 (major — a
password containing `"`, `\` or `&` was written JSON/XML-escaped and escaped the scrub), R2 (a nested option before
`role` hid the role), R3/R4 nits. Fixed with tests (`_forms` replaces raw, JSON, `\u`-JSON and XML/HTML forms;
`_define_case_options` reads up to the callback). **Third pass: SHIP** (genesis 1570 passed). Its optional nits: T2
(pin the `&apos;` junit form) fixed in the test before the commit; T1 recorded in decision 1.

### Decisions / deviations

No ADR deviation (ADR-021's `pre_mutation` rule is covered by the user's D22 → ADR-082 at 51-13). Choices, **bold =
affects 51-07..51-11**:
1. **The generated specs depend on `lib/` only for `loginAs(page, role)`.** `setupData`, `saveSetupData`,
   `RolePages`, `authFile` and the `CaseContext` type live in the GENERATED `suites/_support.ts`. **51-07 §2 must
   change (review m6):** `cases/*.ts` and `setups/*.ts` `export default` what `defineCase`/`defineSetup` return — a
   function `(ctx: CaseContext) => Promise<…>` with `CaseContext = {page, data, as(role): Promise<Page>}` imported
   from `suites/_support`; the action ctx's `appian` is built from `ctx.page`; `setupData` is not in `lib/`; a case's
   role is the literal `role: '<role>'` in `defineCase`'s options, which hold no functions (put `role` first —
   review T1: the reader stops at the first `async`/`function`/`=>`); a role written any other way makes the
   scenario not automated; a data setup's role is `kb_test_setups.role_key`
   (the generator does not read `defineSetup({role})`; 51-07 should keep them equal). `loginAs` reads
   `GENESIS_TEST_USER_<ROLE>`/`GENESIS_TEST_PASSWORD_<ROLE>` (upper-case, `-`→`_`) and does not navigate (the auth
   setup opens `SITE_URL` first). → genesis-spec / genesis-docs.
2. The whole automated catalog is generated and committed (F5: the repo runs alone); an execution selects with
   `--project scn:<instance>` + an anchored `--grep` of `@TS-`, `@setup-<instance>`, `@auth-<role>` tags.
3. **`RunManager.start(prepare=…)`** is the seam for "export into `<run>/checkout` before the run starts" (§3.3);
   51-09 can reuse it or call the runner inside its own workflow.
4. Credentials reach only the Playwright child; the report folder is scrubbed whole (B1). Auth projects also run with
   trace and screenshots off. Residual: a password typed by a scenario's own case step is also scrubbed (exact
   value match), but a screenshot of a visible password cannot be (passwords are masked inputs in Appian).
5. Busy = a `test-execution` or `story-verification` run pending or running. **A paused or gated run does not
   hold the queue**; resuming it while another execution runs can overlap them (review n4, accepted).
6. **`regression-run`** is enabled, hourly, with no default options; per-app `{cadence: off|daily|weekly, days,
   time, since?}` under `options.apps`. **51-08's schedule writer must store through
   `ScheduleStore.update_settings` (sets `user_modified`) and should write `since` when a schedule is turned on**;
   otherwise a newly enabled schedule runs its latest past slot at the next hourly tick. Slots fire up to an hour
   late (hourly tick). 51-13: ADR-047 note.
7. `POST …/test-impact/run` returns 200 with `execution: null` when no automated scenario is affected, plus
   `not_covered` and `not_automated`.
8. **Impact result:** `regression` group added (web type + fixture); `totals.scenarios` is feature-only.
9. Per-scenario Playwright `timeout` 10 min (F6 is silent); `globalTimeout` from `GENESIS_GLOBAL_TIMEOUT_MS` (2 h
   regression, 1 h otherwise); an execution where no scenario passed, failed or was blocked ends `error`.
10. `@types/node` 20.19.43 added to the 51-05 workspace template (no released workspaces exist).
11. **Report folder layout (51-11's execution page):** `<run>/report/{report.json, junit.xml, playwright.log,
    html/index.html, test-results/…}`; result attachments are report-relative (`test-results/…`); the route serves
    any file under the report folder.
12. Accepted nits: n1 (the catalog is read 2–3 times per start; fine at today's sizes), n3 (the impact body
    parsing is duplicated from `POST /test-impact` — 51-10 may extract a helper), n5 (a second role's browser
    context has no trace/screenshot), n2 (comment added).

### Lesson candidates

- **The HTML reporter keeps what the JSON reporter drops.** Playwright 1.59 titles a fill step `Fill "<value>"`, and
  the HTML report stores every step — even of a passing setup test with tracing off — in a base64 zip inside
  `index.html`. Scrub the whole report folder (decoded zips) in every form the value is written (raw, JSON-escaped,
  XML-escaped), and make a stub write the real HTML shape with a password that needs escaping (51-06 B1, R1).
- **With postponed annotations, a FastAPI body model imported inside the registering function is read as a query
  parameter** (`loc: ["query", "body"]`). Import body models at module level.
- **An allow-listed child environment also drops your test's switches** — use a marker file, not an env var, to
  steer a stub child (51-06 tests).

### Code-map changes

For bible/03 in the "Phase 51" block: `testexec/generator.py`, `runner.py`, `execution_service.py`, `finalizer.py`,
`regression_job.py`; `workspace.write_generated`; `procs.start_long_lived(log_path=)`; `ApwtFactory.playwright`;
`RunManager.start(prepare=)`; `ExecutionStore.by_status`/`set_running(selection=)`; `testimpact` regression group;
`DEFAULT_JOBS` `regression-run`; `api/testing.register_execution_routes`; genesis-workflows `test-execution` 0.1.0.
