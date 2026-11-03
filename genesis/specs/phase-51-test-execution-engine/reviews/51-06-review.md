# Review 51-06 — base genesis c18d1a7 + genesis-workflows a365e60, working tree, uncommitted (genesis-review, 2026-11-03)

Scope: code review only. There is no QA environment, so no live acceptance. The author's §9 live evidence
(`scripts/spikes/51-06/`) was read, and one claim in it was re-checked with a real Playwright 1.59.1 run (B1).
Both base revisions exist (`git log -1 c18d1a7`, `a365e60`). The change is the working tree: 18 modified and 21
untracked files in genesis, 1 modified and 5 untracked files in genesis-workflows. The sub-spec has no **As built**
section yet.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1560 passed** in 270 s |
| genesis `.venv/bin/ruff check genesis` (ruff 0.15.20) | All checks passed |
| web `npm run lint` | 0 errors, 20 warnings (pre-existing) |
| web `npm run typecheck` | clean |
| web `npx vitest run` | 50 files, **467 passed** |
| stale bundle: `npx vite build --outDir /tmp/51-06-static` then `diff -r /tmp/51-06-static web/static` | identical (no web/static change needed) |
| genesis-workflows `ci/validate_library.py` | PASSED (15 workflows; the reliability and internal-pin self-proofs OK) |
| genesis-workflows `ci/validate_skills.py` | PASSED (3 skills) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **322 passed** |
| `ruff check workflows/test-execution` | All checks passed |

Every gate the author reported is confirmed green.

## Reviewer probe for decision (4): does the HTML report hold the password?

In `/tmp/51-06-htmlcheck`, `node_modules` was linked to `~/.genesis/testing/spike-51-03-template` (Playwright
1.59.1). The probe ran one passing setup test in an `auth:buyer` project with `trace: 'off', screenshot: 'off'`
(the generator's settings). The test did `getByLabel('Password').fill(process.env.GENESIS_TEST_PASSWORD_BUYER)`,
which is what the shim `loginAs` does and what 51-07's `login(page, {username, password})` will do. Both the `json`
and the `html` reporters were on. Result (`scan.py`):

```
report.json contains secret: False
index.html plain text contains secret: False
embedded report hits: [('17e3fe6f4d9d8bd79c6b.json', '..."title":"Fill \"pw-REVIEW-51-06\" getByLa')]
```

Playwright 1.59.1 names the fill action `Fill "{value}"` (`playwright-core/lib/utils/isomorphic/protocolMetainfo.js:179`,
`["Frame.fill", { title: 'Fill "{value}"', … }]`). The HTML reporter keeps every step of every test, including
`pw:api` steps of passing setup tests (`playwright/lib/reporters/html.js:490`). It stores them in a base64 zip inside
`index.html`. The JSON reporter keeps only `test.step` steps, so `report.json` stays clean, which is why the live
spike's two assertions (report.json and playwright.log only) passed.

## Checklist — genesis (39 files; areas api, features-stages, kb-sync, release-ci, runs-worker, security, stories-workbench)

### ADRs
- [OK] ADR-001 — LangGraph owns control flow. `test-execution` is a fixed four-node program graph (`graph.py` `build`); the queue and finalizer are app-side program code with no agent.
- [N/A] ADR-008 — no change to the app/UI bundling.
- [OK] ADR-009 — no gates (`hitl_points: []`). Ad-hoc pause/cancel still work: the Playwright group is recorded in `<run>/.pids` (`runner.py` `start_long_lived(... pid_dir=self.run_dir / PIDS_DIR)`) and reaped by the 51-05 RunManager path. Resume re-runs `run_playwright` from the checkpoint after `prepare_env`.
- [VIOLATION] ADR-010 — state and checkpoints are clean (`decisions.env` holds only `SITE_URL`, folders, timeout and roles; asserted by `test_graph_runs_playwright_and_writes_results_without_leaking_credentials`, which dumps the DB, state and events). But the runner says credentials are "never in state, checkpoints, events **or files**" (`runner.py` docstring), and that is false for `report/html/` → **B1**.
- [OK] ADR-011 — no agent node. validate_library PASSED (reliability lint).
- [OK] ADR-012 — the app process never imports `graph.py`. The workflow reaches the platform only through `ctx.extras['apwt'].playwright(...)` (`graph.py` `_runner`, `factory.py` `playwright()`).
- [OK] ADR-018 — bulk data (report, results.json, checkout) lives in the run folder. State carries paths only (`_run_playwright_sync` relativises `report`/`log`).
- [N/A] ADR-019 — no change to the core major or the loader.
- [OK] ADR-021 — no `pre_mutation` gate on a workflow that writes QA data through the UI. This is the user's D22 decision (51-01 findings D22; `adr-drafts.md` ADR-082 `--amends ADR-068,ADR-021`), to be recorded by 51-13. `graph.py`'s docstring cites "ADR-082, proposed", which is correct for now. `auto_approve: true`.
- [OK] ADR-022 — reports under `$GENESIS_ARTIFACTS_DIR/test-execution/<run>/report`. F11 retention prunes the report and checkout folders beyond the newest 20 per app (`finalizer.py` `_prune`, guarded to the artifacts root; `test_retention_prunes_files_beyond_the_newest_twenty`).
- [OK] ADR-023 — the routes are FastAPI (`api/testing.py` `register_execution_routes`).
- [OK] ADR-024 — the blocking Playwright wait runs in `asyncio.to_thread` (`graph.py` `_run_playwright`). The scheduler handler uses `asyncio.to_thread(run_once)` (`regression_job.py`).
- [N/A] ADR-025 — no fork change.
- [N/A] ADR-026 — no bind or auth change.
- [N/A] ADR-027 — the web change is types plus a contract test only.
- [OK] ADR-028 — every new route is under the `api` router: `/applications/{app}/testing/executions…` and `/applications/{app}/test-impact/run` (`api/testing.py:192-239`).
- [OK] ADR-030 — SQLite only. The new store methods are `by_status` and `list(status=)` (`kb/testexec_store.py`).
- [N/A] ADR-031 — no chat change.
- [N/A] ADR-032 — no agent turns, so no credits.
- [N/A] ADR-033 — the copilot gets no new tools.
- [N/A] ADR-034 — no skills.
- [N/A] ADR-035 — no file inputs. `prepare` writes the checkout, not an upload.
- [N/A] ADR-036 / ADR-037 / ADR-038 / ADR-039 / ADR-041 — KB sources and documents are untouched. `testimpact.py` only reads `kb_regression_items` and suites.
- [N/A] ADR-042 / ADR-043 / ADR-044 / ADR-045 — no spec, Lavish or chat change.
- [N/A] ADR-046 — no install change. `@types/node` is a workspace npm devDependency, not a Genesis package.
- [OK] ADR-047 — one fixed, backend-defined job: `REGRESSION_JOB` in `DEFAULT_JOBS` (`sync_jobs.py`). Per-app cadence lives in its `options_json`, as D11 decided. 51-13 must add the ADR-047 note (spec §8).
- [N/A] ADR-049 — no navigation change.
- [OK] ADR-050 — execution status is a run-like CAS status in `ExecutionStore` (the 51-04 design, reviewed SHIP), not an SDLC lifecycle. `automation_status` uses the 51-04 `TestScriptStore.set_automation_status` and never overwrites `broken` (`test_broken_automation_status_is_left_alone`).
- [N/A] ADR-054 / ADR-055.
- [OK] ADR-056 — the Test Design stage is not touched. The regression group is an additive impact field.
- [N/A] ADR-057 / 058 / 059 / 060 / 061 / 062 / 063 / 064 / 065.
- [N/A] ADR-066 — no agent iterations to capture.
- [N/A] ADR-067 — no agent, so no healing.
- [OK] ADR-068 — no Appian object writes and no MCP. QA data writes come under the D22/ADR-082 amendment (see ADR-021).
- [N/A] ADR-069 — no skills.
- [N/A] ADR-070 / 071 / 072 / 073 / 074 / 075 / 076.
- [N/A] ADR-077 — no agent-system change.
- [OK] ADR-078 — retired scenarios are excluded from the catalog (`build_catalog` `sc.status != 'retired'`) and from the regression run (`regression_scenario_ids`). No record is deleted.
- [OK] ADR-079 — impact is still computed on demand and stores nothing. `start_impact` stores an execution with a trigger capped at 200 uuids, not an impact result. The regression group comes from the same walk (`testimpact.py` `_regression_group`).
- [OK] ADR-080 — no internal dependency entries added. One repo.

### Lessons
- [N/A] L-003 / L-018 — no SSE change.
- [OK] L-004 — executions, results and the queue are in `genesis.db`. Only report files are on disk.
- [OK] L-005 — only canonical events. The finalizer observes `run.final` (`finalizer.py` `_observe`). No new event kinds.
- [OK] L-008 — a failed run's own `detail` becomes the execution error (`finalize_run`, `test_failed_run_is_error_and_cancel_is_cancelled`).
- [N/A] L-009 — no checkpointer change. The graph compiles with `ctx.checkpointer`.
- [OK] L-010 — routes are under `/api`, and a missing app gives 404 (`test_execution_routes`).
- [N/A] L-016 — no credits.
- [N/A] L-017 — no chat trust change.
- [OK] L-019 — no secret writes. Reads go through `TestCredentialResolver` only.
- [OK] L-020 — four nodes, no loop.
- [N/A] L-021 — no MCP.
- [OK] L-023 — `normalize_report` tolerates odd shapes (`test_normalize_is_defensive_about_odd_shapes`), and `result_rows` matches steps by order and then by key.
- [N/A] L-025 / L-027 — ruff pin unchanged (0.15.20).
- [OK] L-026 — Playwright waits off the loop (`asyncio.to_thread`). The app-side launch runs in sync route handlers (threadpool) and deferred threads (`finalizer._thread`). No DB write sits on the worker loop.
- [OK] L-030 — no `web/**` bundle change is needed (bundle identical). The web type change is in `web/src`, so CI's frontend job will run.
- [N/A] L-031 / L-032 / L-034 / L-035 / L-037 / L-040.
- [OK] L-039 — `list` and `detail` both go through `_summary` (`files_available`, `scenario_count`, `not_automated`).
- [N/A] L-041 / L-042 / L-043 / L-045.
- [N/A] L-048 — no SPA packaging change.
- [N/A] L-050 / L-051.
- [OK] L-056 — not yet committed. The commit must include the 21 genesis and 5 genesis-workflows untracked files listed by `git status --untracked-files=all` (see n6).
- [N/A] L-057 — no tag or pin bump in this sub-spec.
- [OK] L-058 — live observer, plus a startup `reconcile()` (`app.py` startup hook, after the orphan sweep), plus an on-read `reconcile_execution` (GET detail, `test_get_reconciles_a_finished_run_on_read`). Failures are logged at ERROR with the key. The on-read path reads first and writes only when the run is terminal.
- [OK] L-061 — bound-run guard (`ex["run_id"] == run_id` and status `running`; `test_bound_run_guard`).
- [N/A] L-062 / L-063 — not a stage finalizer.
- [N/A] L-064 — no agent output.
- [OK] L-065 — `present` sets `status: done`. There is no gate-to-END path.
- [N/A] L-066 / L-059 / L-060 — no run-graph UI change.
- [OK] L-068 — `index.html` of the report is served with `Cache-Control: no-cache` (`api/testing.py:229-237`).
- [N/A] L-069 / L-071 / L-072 / L-073 / L-074.
- [N/A] L-075 / L-076 — no agent loop.
- [N/A] L-077 / L-078 / L-079 / L-080.
- [OK] L-081 — the job is enabled but does nothing until an app has a cadence. The default carries no `options`, so `ensure_defaults` keeps per-app options (`COALESCE(?, options_json)` / `user_modified` branch, `schedule_store.py:76-118`). Every app is off by default. `test_sync_jobs_default_includes_regression_run` covers it.
- [N/A] L-082 / L-084 / L-085 / L-086.
- [VIOLATION] L-083 — the impact fixture now carries a real regression group (good), and the workflow stub replays a real 1.59.1 JSON report. But the stub writes no HTML report, so the test that claims "nothing of the run holds a credential" (`test_test_execution_workflow.py:185`) cannot see the one file that does → part of **B1**.
- [N/A] L-087 / L-088 / L-089 / L-090.
- [N/A] L-091 — the new store methods are reads. `set_running`/`finish` are CAS-first (51-04).
- [OK] L-092 — `TestExecutionService`, `TestExecutionFinalizer` and `PlaywrightRunner` set `__test__ = False`. There is no `tests/__init__.py` in the new workflow.
- [OK] L-093 — RunManager stores before it announces. Live-path tests end runs through the real `RunManager._finalize` (`_end_run`, `test_live_finalize_through_the_real_run_manager_and_the_queue`).
- [N/A] L-094 / L-095.
- [OK] L-096 — `/test-impact/run` is a POST and the only other routes are `POST /test-impact` and `GET /test-impact/syncs`, so no path-param route matches it. Tested by behaviour (`test_impact_run_route_validates_its_body`).
- [VIOLATION (minor)] L-097 — the startup reconcile fails a `running` execution whose run record does not exist, without holding the run-owner lock (`finalizer.py:156`). The window runs from `set_running` (inside `prepare`) to `store.create`, and it includes the git export → **m2**.
- [N/A] L-098 / L-099 / L-100.

### Gates
- [OK] `pytest` (api, features-stages, kb-sync, runs-worker, stories-workbench): 1560 passed.
- [OK] `ruff check genesis`: clean.
- [OK] web `lint && typecheck && test`: 0 errors / clean / 467 passed.
- [OK] web `build`: `/tmp` build identical to `web/static`.

## Checklist — genesis-workflows (6 files; areas release-ci, security, workflows-library)

- [OK] ADR-001 — program nodes only.
- [OK] ADR-003 / ADR-006 — self-contained folder (`workflow.yaml` + `graph.py`) plus a `registry.json` entry whose fields mirror META.
- [N/A] ADR-005 / ADR-029 — no registry MCP/CLI entries (`required_mcp: []`, `required_cli: []`).
- [OK] ADR-007 — roles `developer, tester` are tags only.
- [VIOLATION] ADR-010 — the files part, as in the genesis list → **B1**.
- [OK] ADR-011 — no agent node. Reliability lint PASSED.
- [OK] ADR-012 — imports only `genesis_core`, langgraph and stdlib.
- [N/A] ADR-014 / ADR-015 — not scaffolded, which is acceptable for a program-only workflow (it follows the existing workflows' layout).
- [OK] ADR-017 — Python.
- [OK] ADR-018 — pointers in state, bulk in the run folder.
- [OK] ADR-019 — no core-major change. validate_library compat passed.
- [N/A] ADR-020 — no Kiro config.
- [OK] ADR-021 — D22 (see above).
- [OK] ADR-022 — run folder under the artifacts root.
- [N/A] ADR-026 / ADR-030 / ADR-031 / ADR-033 / ADR-034 / ADR-035 / ADR-036 / ADR-037 / ADR-038 / ADR-039 / ADR-041 / ADR-045 / ADR-046.
- [N/A] ADR-048 — QA test users, not core Appian credentials. They resolve through `TestCredentialResolver` (F12 scope), not `ctx.secrets`.
- [N/A] ADR-056 / 057 / 058 / 059 / 061 / 062 / 063 / 065 / 067 / 069 / 073 / 074 / 075 / 076 / 077.
- [OK] ADR-068 — no Appian object writes.
- [OK] ADR-078 — the results carry scenario and case keys only.
- [OK] ADR-080 — no pins touched.
- [OK] L-006 / L-013 — the `graph:` topology node ids match the LangGraph names (`prepare_env`, `run_playwright`, `parse_results`, `present`). Parity lint passed.
- [N/A] L-009 — compiled with `ctx.checkpointer`. No `Command(resume)`.
- [OK] L-017 — no trust surface.
- [OK] L-020 — no loop.
- [N/A] L-021 — no MCP.
- [OK] L-022 — `from __future__ import annotations` with no custom-reducer keys (`TestExecutionState` adds no keys).
- [OK] L-023 — defensive parse, tested on the real report and on odd shapes.
- [N/A] L-024 — no skills.
- [OK] L-026 — `to_thread`.
- [N/A] L-029 / L-042 / L-049 / L-053 / L-064 / L-075 / L-076.
- [OK] L-033 — if the library lacks the workflow, `rm.start` raises inside `pump`. The execution ends `error` with the reason, and the route still returns 200 (`pump` `except` → `_fail`), never a 500.
- [VIOLATION] L-083 — the stub writes no HTML report (B1).
- [OK] L-092 — no `tests/__init__.py`. The test module name `test_test_execution_workflow.py` is unique.
- [N/A] L-025 / L-027 / L-030 / L-045 / L-051 / L-056 (commit pending) / L-057 / L-087 / L-088 / L-089 / L-098 / L-099 / L-100.
- [OK] Gates: validate_library PASSED, pytest 322 passed, genesis pytest/ruff green.

## The ten decisions the author asked to be checked

1. **Case/setup contract** (default export taking `CaseContext {page, data, as(role)}`; `setupData`/`RolePages`/`authFile` in generated `suites/_support.ts`; role from `defineCase(…, { role: '…' })`). The design works and the live run typechecked it. It differs from the 51-07 spec §2 as written: there, `setupData` is in `lib/`, the `defineSetup({key, name, role, outputs}, fn)` role is declared in the file (the generator uses `kb_test_setups.role_key`), and a default export is never mentioned. → **m6**. The role regex reads only a literal role, so anything else silently falls back to the setup role → **m5**.
2. **Whole catalog generated and committed; selection by `--project scn:*` plus an anchored `--grep`.** OK. The anchor `(?=\s|$)` and the escaped `.` make `@setup-DS-000001` miss `@setup-DS-000001.TS-000002` (`test_grep_selects_exactly…`). The live run excluded TS-000006. Commit scope → **m4**.
3. **`RunManager.start(prepare=)`.** OK and tested (`test_run_manager_prepare_runs_before_the_record_and_can_refuse`). The docstring's "If it raises, nothing was created" is not quite true → **m3**.
4. **Credentials resolved at spawn; text reports scrubbed; traces and HTML not scrubbed.** The HTML report **does** hold every role's password → **B1**.
5. **Busy = a test-execution or story-verification run pending/running.** OK (`busy()`, `test_queue_waits_for_a_story_verification_run`). A paused execution frees the queue, and its later resume can overlap the next one → **n4** (accept and document).
6. **regression-run job.** OK. Hourly `interval_window` 00:00–23:00. A slot is due when later than both the newest regression execution's `created_at` and `since`. It catches up once and is skipped while that app's regression is queued or running (`test_regression_slots_daily_weekly_off_and_catch_up_once`, `test_regression_job_handler_starts_due_apps_and_skips_busy_ones`). A 23:30 slot fires at 00:00, which is fine.
7. **`start_impact` returns 200 with `execution: null` when nothing automated is affected.** OK, and it lists `not_covered` and `not_automated`.
8. **Impact `regression` group; `totals.scenarios` stays feature-only.** OK. Web types plus contract fixture (`ImpactRegression`, `ImpactRegressionScenario`) recorded from a real API read (L-083 satisfied for the fixture). The 51-04 guard is removed with a regression test (`test_impact_includes_regression_scenarios_as_their_own_group`).
9. **Per-scenario timeout 10 min.** Reasonable (`SCENARIO_TIMEOUT_MS = 600_000`). It is not in F6, so record it in As built. Behaviour on Playwright's own `globalTimeout` → **m1**.
10. **`@types/node` 20.19.43 in the workspace template.** OK (`runtime.py` `TYPES_NODE_VERSION`, template and test updated). No released workspaces exist, so no migration is needed.

## Findings

### Blockers

- **B1 — The Playwright HTML report stores every test user's password in clear, keeps it for 20 executions per app, and serves it over the API.** The `html` reporter (`generator.py:442`) keeps the `pw:api` steps of the passing `auth:<role>` setup tests. Playwright 1.59.1 titles a fill `Fill "{value}"`, so `loginAs` typing the password leaves `Fill "<password>" getByLabel('Password')` in the report's embedded zip. The reviewer reproduced this with the generator's own project settings (`trace: 'off', screenshot: 'off'` do not affect step titles). `PlaywrightRunner._scrub` (`runner.py:139`) only rewrites `report.json`, `junit.xml`, `playwright.log` and `test-results/**/*.md`. `GET …/executions/{key}/report/html/index.html` (`api/testing.py:229`) serves the file, and F11 keeps it for the newest 20 executions. This breaks D5 ("password in the SecretProvider, never in a file") and F12, and the module's own claim (ADR-010 framing). The tests could not see it: the workflow stub writes no HTML, and the live spike asserted only `report.json` and `playwright.log` (L-083).
  **Fix (pick one, then add the regression test):**
  - (a) After the run, scrub the HTML report: decode the `data:application/zip;base64,…` payload in `html/index.html`, replace each secret in every entry, re-encode it, and also scan any `html/data/*` files. This keeps the HTML report.
  - (b) Drop the `html` reporter and build the report view from `report.json` plus the `test-results/` attachments.
  - (c) Sign in outside the Playwright test run (for example with the runner or apwt writing `.auth/<role>.json` before `npx playwright test`). Then no reported test types a password, but the blocked-by-auth mapping must move with it.

  Whichever you pick, the stub `npx` in `test_test_execution_workflow.py` must also write an HTML report in the real shape (an `index.html` with the embedded zip holding the password in a step title), and the "no credential in any file" scan must decode it. Re-run `scripts/spikes/51-06/live_report.py` with an assertion over the decoded HTML report as the live proof.

### Majors

None besides B1.

### Minors

- **m1 — Playwright's own `globalTimeout` is not reflected in the result.** Tests that never started are left with `results: []` and become `skipped` (`graph.py:217`), not `not-run`. The report-level `errors` (the "Timed out waiting …" message), collected at `graph.py:241`, are written to results.json but ignored by `finalizer.outcome` (`finalizer.py:91`). The finalizer sets `timed_out` only for the hard timeout (`finalizer.py:182`). An execution whose scenarios are all `skipped` ends `passed`. Usually the scenario that is running when the timeout hits is `interrupted` → failed, so the overall status is right, but the remaining rows say "skipped" and the reason is lost. **Fix:** when `results.errors` is non-empty, map result-less, non-blocked scenarios to `not-run` and copy the first error into `totals`. Treat an execution where no scenario passed or failed as `error`. Add a test with a report fixture whose `errors` holds a global timeout.
- **m2 — L-097: the startup reconcile writes a terminal state without the run-owner lock.** `finalizer.py:156` fails any `running` execution whose run record is missing. A second `genesis serve` on the same home that starts during another server's launch (set_running → git export → `store.create`, seconds long) fails that live execution. **Fix:** do the ghost-fail only when this process holds `run/runs.lock` (the `fail_orphaned_runs` rule), or only for executions whose `started_at` is older than a few minutes.
- **m3 — `prepare` failure leaves files.** If `prepare` or `validate_inputs` raises, `<artifacts>/test-execution/<run>/checkout` stays on disk with no run record, so retention never reaches it (`manager.py:284`). The docstring says "nothing was created". **Fix:** remove `artifacts_dir` when `prepare`/`validate_inputs` raises, or correct the docstring and let `_fail` clean the checkout.
- **m4 — Regeneration commits the whole index.** `write_generated` stages only `suites/` and `playwright.config.ts`, then checks `git diff --cached --quiet` over the whole index and commits everything staged (`workspace.py:412`; same pattern as the 51-05 `commit()` at `:320`). If someone `git add`-ed an edit by hand in the workspace, it is committed under "Regenerate the scenario specs for TE-…" and then executed. This bypasses D16.7's "un-adopted changes are never executed". **Fix:** `git commit -- <paths>` (or `diff --cached --quiet -- <paths>`), with a test that a staged, non-generated file stays uncommitted.
- **m5 — A non-literal case role silently runs as the wrong user.** `_CASE_ROLE_RE` (`generator.py:47`) matches only `defineCase('<TC>', { …role: '<literal>'…`. `{ role: ROLE }`, a nested object before `role`, or a template literal all fall back to the setup role or the only user, with no notice. **Fix:** when a script contains `defineCase(` for the key but no literal role is parsed while `role` appears in its options, list the scenario as not automated with the reason. Alternatively fix the literal-only rule in 51-07 §2 and its typecheck.
- **m6 — The 51-07 contract needs updating before 51-07 starts (decision 1).** 51-07 §2 must say:
  - `cases/*.ts` and `setups/*.ts` must `export default` the value `defineCase`/`defineSetup` returns, a function `(ctx: CaseContext) => Promise<…>`;
  - `CaseContext` is `{page, data, as(role): Promise<Page>}` from the generated `suites/_support.ts`, and the action ctx's `appian` is built from `page`;
  - `setupData` moves from `lib/` to the generated support file;
  - the data setup's role comes from `kb_test_setups.role_key`, not from `defineSetup({role})`, so they must agree (or the generator should check that they do).

  Record this in 51-06's As built and hand it to genesis-spec/genesis-docs.

### Nits

- **n1** — Each start reads the catalog two or three times (`start_impact`, then `start` → `plan`, then `pump` → `_launch`), and each read runs one `git show` per script. Pass the catalog through, or cache it per HEAD.
- **n2** — `regression_job.py:37` repeats `"Asia/Kolkata"` because importing `_TZ` from `sync_jobs` would be circular. Move `_TZ` to a small shared module, or add a comment that they must match.
- **n3** — `run_impacted_tests` repeats the body-to-`changed` mapping of `POST /test-impact` (`api/testdesign.py:446`). Extract one helper so the two endpoints cannot drift.
- **n4** — Decision 5: a paused `test-execution` does not block the queue, and its resume can run beside the next execution. Accept and document it in As built, or count `paused` as busy.
- **n5** — Contexts for a second role (`RolePages.page`, `browser.newContext`) do not inherit `use.trace`/`screenshot`, so a failure as the second role has no trace. Pass the same options, or note the limit.
- **n6** — The sub-spec has no **As built** yet. When committing, check L-056: the 21 untracked genesis files (5 modules, 2 tests, 11 golden files plus the report fixture, the spike and 2 evidence files) and the 5 untracked genesis-workflows files must all be in the commits.

## Verdict: NEEDS_CHANGES

B1 must be fixed, with a regression test that decodes a real-shape HTML report and a re-run of the live spike that asserts on it. The minors m1–m6 should be fixed in the same pass, or recorded with a reason in As built (m6 needs a 51-07 spec update either way). Everything else is sound: all gates are green and match the author's figures, the finalizer follows L-058/L-061/L-093 and is tested through the real `RunManager._finalize`, the queue, the regression schedule and the impact regression group behave as specified, and the reap evidence closes 51-05 minor 7 and nit 12.

---

# Re-review (genesis-review, 2026-11-03) — same bases, working tree still uncommitted

Scope: the fixes for B1 and m1–m5, the As built (decisions 1–12), and every gate again. Code review only (no QA
environment). The base revisions are unchanged (genesis c18d1a7, genesis-workflows a365e60). The As built exists
(`51-06-execution-engine.md` §As built): m6 is decision 1, n4 is decision 5, and n1/n3/n5 are accepted in decision 12.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -v -p no:warnings` | **1565 passed** in 267 s |
| genesis `.venv/bin/ruff check genesis` | All checks passed |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (15 workflows; reliability and internal-pin self-proofs OK) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **323 passed** |
| `ruff check workflows/test-execution` | All checks passed |
| web | not re-run: no `web/**` file changed since the first pass (`git status` lists the same three web files) |

All figures match the author's. One earlier pytest attempt stalled at about 14 % in `tests/test_collab_*`. It ran
while a run from a timed-out call was still alive. A clean re-run passed, so this is not a finding.

## The fixes

- **B1 — fixed for passwords made of ordinary characters, with a regression test and live proof.**
  `PlaywrightRunner._scrub` (`runner.py`) now walks the whole `report/` folder. It rewrites text files, the HTML
  report's `data:application/zip;base64,…` payload (`scrub_html`) and every `.zip`, including nested zips
  (`scrub_zip`). The genesis test `test_scrub_reaches_the_html_reports_embedded_zip_and_trace_zips` builds the real
  shapes: an embedded zip with a `Fill "<pw>"` step, a trace with `"value":"<pw>"`, a nested `resources/x.zip` and a
  binary PNG. The workflow stub now writes `html/index.html` and a `trace.zip`, and its scan decodes them
  (`_file_text`; `test_graph_runs_playwright_and_writes_results_without_leaking_credentials` asserts
  `Fill \"***\"`). The live evidence `scripts/spikes/51-06/evidence/scrub.json` shows 46 files scanned, 0 hits,
  `html_has_scrubbed_fill_step: true`, and lists the eight zips it opened. Playwright's `outputDir` is
  `<report>/test-results` (`generator.py:452`), so traces are inside the scrubbed folder. **But see R1:** the scrub
  matches only the raw password, and Playwright writes it JSON-escaped.
- **m1 — fixed.** `graph.py` marks a scenario with no results, not blocked, as `not-run` when `report.errors` is
  non-empty, and gives it the first global error. `execution_status` (graph) and `outcome` (`finalizer.py:91`) return
  `error` when nothing passed, failed, was flaky or was blocked. `finalize_run` copies the first error to
  `totals.run_error` (`finalizer.py:186`). Tested by `test_a_global_timeout_marks_unstarted_scenarios_not_run`.
- **m2 — fixed.** `_reconcile` ghost-fails only when `startup` is true AND `self.rm._hold_run_owner_lock()` is true
  (`finalizer.py:156`), the same rule as `fail_orphaned_runs` (`manager.py:424`). Tested by
  `test_startup_reconcile_leaves_a_ghost_alone_while_a_peer_holds_the_run_lock`. The earlier tests still cover the
  case where this process holds the lock.
- **m3 — fixed.** `RunManager.start` removes the run folder when `prepare` or the validation after it raises, but
  only if the folder did not exist before the call. The docstring now says exactly that. Tested by
  `test_run_manager_removes_the_run_folder_when_prepare_fails`.
- **m4 — fixed.** `write_generated` runs `diff --cached --quiet -- <paths>` and then `commit … -- <paths>`
  (`_commit_staged(paths=)`). Tested by `test_regeneration_commits_only_the_generated_paths`: the hand-staged file
  stays staged, is absent from the commit, and the checkout has the committed content.
- **m5 — fixed for the cases the first pass named, apart from one (R2).** `case_role_unreadable` makes the scenario
  not automated when the `defineCase` options mention `role` but no literal role was parsed. That covers a constant,
  a template string, shorthand `{ role }` and an upper-case literal. Tested by
  `test_a_role_genesis_cannot_read_makes_the_scenario_not_automated`.
- **m6 / n1–n5 — recorded.** As built decision 1 states the 51-07 §2 changes (default export, `CaseContext` in the
  generated `suites/_support.ts`, `setupData` moved, setup role from `kb_test_setups.role_key`). n2 has its comment.
  n4 is accepted and documented in the module docstring and decision 5. n1, n3 and n5 are accepted in decision 12.
  These are reasonable. m6 still needs genesis-spec/genesis-docs to edit 51-07 §2 before 51-07 starts.

## Checklist changes since the first pass (every other line stands as written above)

- [VIOLATION] ADR-010 (genesis and genesis-workflows) — narrowed to passwords that contain `"` or `\` → **R1**.
- [OK] L-083 — the stub writes the real HTML and trace shapes, and the fixture was refreshed from the live run.
  The fixture passwords (`Pw-buyer-7c1e`, `Pw-vendor-91aa`, `test_test_execution_workflow.py:43-44`) contain no
  character that JSON escapes, which is why R1 is not caught.
- [OK] L-097 — the ghost-fail is gated on the run-owner lock (`finalizer.py:156`).
- [OK] L-056 — still uncommitted. The untracked file list is the same as in the first pass, minus the removed genesis
  copy of the report fixture, plus `scripts/spikes/51-06/evidence/scrub.json`. Every one must be in the commits.

## New findings

### Majors

- **R1 — The scrub misses a password that contains `"` or `\`, so the B1 leak remains for those passwords.**
  Playwright builds the step title from the raw value (`protocolFormatter.js` `renderTitleForCall` →
  `formatProtocolParam`, which only rewrites `\n`). The HTML reporter and the trace store the title as JSON, so
  `"` becomes `\"` and `\` becomes `\\`. `_replace` and `scrub_zip` search only the raw string (`runner.py`
  `_replace`, `needles = [s.encode()]`). Reviewer probe with the shipped `scrub_zip` on a zip entry
  `json.dumps({"title": 'Fill "<pw>" getByLabel'})`:
  ```
  'Plain-pw1' scrubbed      Fill "***" getByLabel
  'Ab"c9!x'   NOT scrubbed  Fill "Ab"c9!x" getByLabel
  'Ab\c9!x'   NOT scrubbed  Fill "Ab\c9!x" getByLabel
  'A&b<9'     scrubbed      Fill "***" getByLabel
  ```
  The same applies to a trace's `"params":{"value":"…"}` and to `report.json`. The file is then kept for 20
  executions and served by `GET …/report/html/index.html`. Appian password policies often require a special
  character, and nothing stops a test user's password from using `"` or `\`. The module docstring's claim ("every
  test-user password anywhere in the report folder … is replaced") is therefore false for those passwords. This is
  rated major, not blocker, only because the common case is fixed. It must be fixed before SHIP.
  **Fix:** for each secret, also replace its JSON-escaped form (`json.dumps(s)[1:-1]`, plus the
  `ensure_ascii=True` form for non-ASCII passwords) and its XML-escaped form (`xml.sax.saxutils.escape(s,
  {'"': '&quot;', "'": '&apos;'})`, for `junit.xml`). Apply them in text files and in zip entries, longest form
  first. Add a genesis test that uses a password containing `"`, `\` and `&`, in the embedded-zip, trace and
  junit shapes.

### Minors

- **R2 — m5 residual: a nested object before `role` still falls back silently.** `_CASE_ROLE_RE` stops at the first
  inner `{` (`[^{}]*?`), and `_CASE_OPTS_RE` captures only up to the first `}` (`(?P<opts>[^}]*)`,
  `generator.py:128`). For `defineCase('TC-000001', { data: { a: 1 }, role: 'vendor' }, …)` the probe returns
  `case_script_role → None` and `case_role_unreadable → False`, so the case runs as the setup role or the only
  user, with no notice. **Fix:** search for `\brole\b` in the text from `defineCase('<key>',` up to the callback
  (`async` / `=>`), not up to the first `}`. Or state the "flat options object, literal role" rule in 51-07 §2 and
  have 51-07's typecheck enforce it. Add the nested case to the m5 test.

### Nits

- **R3** — `finalizer.py:156` calls the private `RunManager._hold_run_owner_lock()` from another class. Expose a
  public `holds_run_owner_lock()` (or similar), or leave a comment saying the coupling is deliberate.
- **R4** — `manager.py` `start` imports `shutil` inside the `except` block. Move it to the module imports.

## Verdict: NEEDS_CHANGES

B1's fix covers the real report shape, and its tests and live evidence are solid. m1–m5 are fixed with tests, and
every gate is green with the author's figures (genesis 1565, genesis-workflows 323, ruff clean, validate_library
PASSED). One credential path is still open (R1): a password containing `"` or `\` stays in clear in the HTML
report and the traces. Fix R1 with its test, and preferably R2. R3 and R4 are optional. A third pass needs only
the R1/R2 diff and the gates.

---

# Third pass (genesis-review, 2026-11-03) — same bases, working tree still uncommitted

Scope: only the R1–R4 diff and the gates. The bases are unchanged (genesis c18d1a7, genesis-workflows a365e60).
genesis-workflows is unchanged since the re-review: no file in `registry.json` or `workflows/test-execution/` is
newer than this report, so its earlier gate results stand (validate_library PASSED, 323 passed).

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/ruff check genesis` | All checks passed |
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1570 passed** in 360 s (re-review: 1565; +5 = the four R1 parameters and the R2 test) |
| targeted `-k "scrub or role or reconcile or lock"` (execution + generator tests) | 14 passed |
| genesis-workflows | not re-run: unchanged since the re-review (see above) |

The figures match the author's.

## The fixes

- **R1 — fixed.** `_forms(secrets)` (`runner.py:178`) returns, for each secret, the raw string,
  `json.dumps(s)[1:-1]`, the `ensure_ascii=False` variant, `html.escape` with `quote=True` and with `quote=False`, and
  the XML-entity form (`&quot;` / `&apos;`). Empty forms are dropped and the list is sorted longest first.
  `_replace` (text files and the HTML plain text) and `scrub_zip` (every entry, nested zips, and through
  `scrub_html` the embedded report zip) both use it. Reviewer probe with the shipped functions, password in a JSON
  step title plus an `ensure_ascii=True` JSON value inside a zip, and in a junit attribute in Playwright's
  `&quot;`/`&apos;` form:
  ```
  'Plain-pw1'   zip: {"title": "Fill \"***\" x"}{"v": "***"}   junit: <testcase name="***"/>
  'Ab"c9!x'     zip: {"title": "Fill \"***\" x"}{"v": "***"}   junit: <testcase name="***"/>
  'Ab\c9!x'     zip: {"title": "Fill \"***\" x"}{"v": "***"}   junit: <testcase name="***"/>
  "A&b<9'q"     zip: {"title": "Fill \"***\" x"}{"v": "***"}   junit: <testcase name="***"/>
  'Ünï-cødé9'   zip: {"title": "Fill \"***\" x"}{"v": "***"}   junit: <testcase name="***"/>
  'x\u2028y\tz' zip: {"title": "Fill \"***\" x"}{"v": "***"}   junit: <testcase name="***"/>
  ```
  `test_scrub_catches_json_and_xml_escaped_passwords` (`tests/test_testexec_execution.py:705`), parametrized over the
  four passwords named in the request, checks report.json (both JSON variants), junit.xml (`html.escape(quote=True)`),
  a trace zip and the embedded HTML zip. It asserts the absence of every written form. That is sufficient. The
  login POST body (form-urlencoded) is not a further path: the `auth:<role>` projects run with
  `trace: 'off', screenshot: 'off'` (`generator.py:439`), so no network record of the sign-in is written.
- **R2 — fixed.** `_define_case_options` (`generator.py:118`) takes the text from `defineCase('<TC>',` to the first
  `async` / `function` / `=>`, nested objects included. `case_script_role` and `case_role_unreadable` read the literal
  `role:` only in that window. `_CASE_ROLE_RE` and `_CASE_OPTS_RE` are gone (grep finds no reference outside stale
  `.pyc` files). `test_a_role_after_a_nested_option_is_still_read` (`:736`) covers the nested-then-literal case, the
  nested-then-`role: ROLE` case (unreadable) and a `role` inside the callback (ignored). Probe: nested → `vendor`;
  `{ asyncMode: true, role: 'vendor' }` → `vendor` (the `\b` guard holds); `function () { const role = 'x' }` callback →
  only the option is read.
- **R3 — fixed.** `RunManager.holds_run_owner_lock()` (`manager.py:457`) is public, documented with L-097, and
  delegates to `_hold_run_owner_lock`. `finalizer.py:156` calls it, and the peer-lock test patches the public name
  (`tests/test_testexec_execution.py:660`).
- **R4 — fixed.** `import shutil` is at the top of `runs/manager.py` (`:17`) and the `except` block in `start` uses
  it. The older local `import shutil` at `manager.py:189` is pre-existing at c18d1a7 (another method) and now
  redundant. It is harmless and out of scope.

## Checklist changes since the re-review (every other line stands)

- [OK] ADR-010 (genesis and genesis-workflows) — every written form of a test-user password is scrubbed from the
  report folder, its zips and the embedded HTML zip (R1 above).
- [OK] L-083 — the R1 test uses passwords with `"`, `\`, `&`, `<`, `'` and non-ASCII, which are the shapes that hid
  R1.
- [OK] L-097 — unchanged, now through the public `holds_run_owner_lock()`.
- [OK, pending commit] L-056 — still uncommitted. The untracked list is unchanged from the re-review. Every file must be
  in the commits (n6).

## New findings

No blocker, major or minor findings.

### Nits

- **T1 — R2's callback stop can fire early.** `_CALLBACK_RE` stops at the first `async` / `function` / `=>` anywhere,
  including inside an option value. Probe: `{ data: (x) => x, role: 'vendor' }` and `{ note: 'a => b', role:
  'vendor' }` both give `case_script_role → None`, `case_role_unreadable → False`, so the case falls back silently.
  These are unlikely in a case's options (data and a role), so this is a nit. Add one line to the 51-07 §2 contract
  handed over in decision 1: "`defineCase` options hold no functions; put `role` first". Or have the 51-07 typecheck
  reject a function-valued option.
- **T2 — the R1 test does not exercise the `&apos;` form.** The junit fixture uses `html.escape(quote=True)` (`&#x27;`).
  Playwright's JUnit reporter writes `&apos;`. `_forms` covers it (probe above), but the test does not pin it. Add the
  `&apos;`/`&quot;` form to the junit fixture.

## Verdict: SHIP

R1 closes the last credential path: JSON-escaped, `\u`-escaped and XML/HTML-escaped passwords are scrubbed in text
files, every zip entry and the embedded HTML report, with a parametrized regression test over the shapes that hid it.
R2 reads a literal role after nested options and fails closed on a non-literal one. R3 and R4 are done. All gates
are green and match the author's figures (genesis 1570 passed, ruff clean; genesis-workflows unchanged, 323 passed
and validate_library PASSED). Before release: commit every untracked file (L-056, n6), and have genesis-spec or
genesis-docs apply the 51-07 §2 contract changes (decision 1, plus T1's line) before 51-07 starts. T1 and T2 are
optional.
