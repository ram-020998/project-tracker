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
