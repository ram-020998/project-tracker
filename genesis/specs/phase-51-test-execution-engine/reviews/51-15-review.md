# Review 51-15 — base genesis `cca8ff8`, genesis-workflows `93e6e35` (genesis-review, 2026-11-05)

Scope: the whole sub-spec across both dev sessions. genesis `d8c1fc8`, `e001b30`, `6fe9e71`, `f68c7ca`, `4412645`,
`f6d86ff`, `750f0d1` (HEAD `750f0d1`, every sha resolved); genesis-workflows `daf3612`; the session-1 As built at
project-tracker `2c2b6f5`. Nothing pushed or tagged. Inputs: `genesis-ctx pack 51-15`, `genesis-ctx check --since` per
repo (genesis: 130 files, 11 areas; genesis-workflows: 4 files), the diff, `reviews/51-12-review.md` §Findings,
51-01 D26–D32.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/ruff check genesis` | All checks passed |
| genesis `pytest -q -p no:warnings` (full) | **1725 passed** in 524 s |
| genesis targeted (reports_origin, runs, story_verification, testexec_*, testing_api) | 229 passed |
| web `npm run lint` | 0 errors, 20 warnings (all in files 51-15 does not touch) |
| web `npm run typecheck` | clean |
| web `npx vitest run` | **694 passed (61 files)** |
| stale bundle: `npx vite build --outDir /tmp/51-15-static` then `diff -r /tmp/51-15-static web/static` | identical, so `750f0d1` is fresh |
| genesis-workflows `ci/validate_library.py` | PASSED (17) |
| genesis-workflows `ci/validate_skills.py` | PASSED (4) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **363 passed** |
| B2 probe re-run: `node scripts/probes/reports-origin-isolation.mjs --out /tmp/genesis-probes/51-15-review/reports-origin-isolation.json` against :8760 (reports :8860) | **12/12 PASS** (same-origin `/api` 404 9 bytes, cross-origin fetch + XHR blocked, no-cors opaque 0 bytes, nosniff, `no-cache, must-revalidate`, 4 refusals 404, POST 405) |
| L-090 width probe | **not re-run** (it starts Vite); the dev's run6 numbers were accepted from the brief |
| Extra real-browser check (read-only GETs): `/tmp/genesis-probes/51-15-review/own-scenario.mjs`, `own-crumbs.mjs` | gave finding MJ-1 (screenshot `own-TS-000024.png`) |

## Checklist

### ADRs — genesis
- [OK] ADR-001 — no agent orchestration added. Run control stays in `RunManager` (`runs/manager.py`); D28 promotion is program code (`library_service.promote_proven_actions`).
- [N/A] ADR-002, ADR-004, ADR-005, ADR-020, ADR-029 — no ACP/MCP/registry change.
- [OK] ADR-003, ADR-008 — still one local app. The reports listener is part of `genesis serve` (`cli/main.py:150-167`).
- [N/A] ADR-006, ADR-007, ADR-013, ADR-016, ADR-017 — not touched (Python only).
- [OK] ADR-009 — mode 2 restored: `pause` stores `paused` before the kill, and resume continues from the checkpoint (`test_pause_of_a_running_worker_pauses_and_resume_continues_from_the_checkpoint`: `first.count == "1"`, one `run.final{done}`).
- [OK] ADR-010, ADR-018, ADR-022 — reports and replay evidence stay files under the artifacts root. State holds only paths (`last_replay.report`/`screenshot`).
- [OK] ADR-011 — no agent node added or changed. `validate_library` passes (reliability lint).
- [OK] ADR-012 — pause = kill, resume = fresh worker. The intended stop is per worker (`manager.py:209-213`), so a late exit of the killed worker cannot touch the resumed run (`test_a_late_worker_exit_of_a_paused_worker_cannot_fail_the_resumed_run`).
- [N/A] ADR-019, ADR-024, ADR-025 — no compat, engine or fork change.
- [OK] ADR-021 — no gate semantics changed. The capture panel now reports a run that waits at its escalation gate (`CapturesPanel.tsx:75-80`).
- [OK] ADR-023 — the backend is still FastAPI. The second listener is a stdlib static server with no API (`reports_origin.py`).
- [OK] ADR-026 — the reports listener binds the same host after the bind guard. The non-loopback refusal opens no port (`tests/test_reports_origin.py`). `Host` is checked (421). The D26 note on body-less cross-origin POSTs is carried to backlog §20 as decided.
- [OK] ADR-027, ADR-055 — existing primitives only (`Card`, `CardHeader`, `Badge`, `Select`, `buttonVariants`) and design tokens. No new dependency or token.
- [OK] ADR-028 — the new web code builds no `/api` URL. `testingApi.reportUrl` is removed (`lib/api/testing.ts`), and report links are absolute reports-origin URLs from the API.
- [OK] ADR-030 — SQLite. `claim_status`/`note_progress` are single SQL statements.
- [OK] ADR-031, ADR-033, ADR-034, ADR-045 — chat is not touched. `story_verification_finalizer.py` is a program finalizer.
- [N/A] ADR-032, ADR-035 through ADR-049, ADR-051, ADR-053, ADR-054, ADR-057 through ADR-060, ADR-063 through ADR-066, ADR-069 through ADR-076 — not in this diff's behaviour.
- [OK] ADR-050 — D28's Draft → Ready goes through `LifecycleService.transition(..., "approve", actor=execution_key)` (`library_service.py` `promote_proven_actions`). The action refusal text is in `domain/transitions.py:198-207`.
- [OK] ADR-056, ADR-078 — stage model unchanged. `CasesTable` widths only (m8).
- [OK] ADR-061, ADR-062, ADR-068 — board lanes untouched. Run-control tests for the Design/Implementation lanes pass in the full suite.
- [OK] ADR-067 — healing untouched (m4 timeout only).
- [OK] ADR-077 — review run with L0 + pack + check, no bulk docs read whole.
- [OK] ADR-079 — no link-model change.
- [OK] ADR-080 — no package metadata change.

### ADRs — genesis-workflows (its own check list)
- [OK] ADR-001, ADR-011, ADR-012, ADR-067 — `typecheck` is still a program step. `validate_library` PASSED.
- [OK] ADR-010, ADR-018, ADR-022 — `.pids` records go in the run folder (`ctx.workspace.root`).
- [OK] ADR-006, ADR-014, ADR-017, ADR-019 — `graph.py` stays self-contained. The platform helper is reached only through `ctx.extras['apwt']`, with a local `_own_group` fallback (`action-capture/graph.py:274-310`; `story-verification/graph.py:545-582`).
- [N/A] all other ADRs on that list — no registry, skill, MCP, credential or stage change.

### Lessons
- [OK] L-003 — a pause keeps the bus open (`assert not mgr.cbus(run_id)._closed`). Cancel closes it once.
- [OK] L-005 — canonical kinds only. Exactly one `run.final{cancelled}` (`test_cancel_of_a_running_worker_ends_cancelled_with_exactly_one_run_final`).
- [OK] L-008 — `worker_exit` still does not clobber a specific `error`. An unexpected death still fails the run (`test_an_unexpected_worker_death_still_fails_the_run`).
- [OK] L-009, L-020, L-026 — no change to the graph or async writes.
- [OK] L-010, L-028 — see ADR-028.
- [VIOLATION, minor] L-011 / L-083 — the recorded `library-setup-item.json` carries `report_url: null, screenshot_url: null`, so the web test hand-writes the URLs. See mi-1.
- [OK] L-014, L-015 — jest-axe on the changed views. `PassRateChart` is still lazy.
- [OK] L-025, L-027 — ruff pinned, clean.
- [OK] L-030, L-089 — the `web/static` commit is separate (`750f0d1`) and the reviewer's rebuild diff is empty.
- [OK] L-039 — the list and detail both carry `report_url` (`_summary` is shared by list and detail, `execution_service.py`).
- [OK] L-058, L-061, L-093 — the capture #2 finding is evidenced (a gate wait, not a lost finalize). `_finalize` stores before it announces, and the observer sees `cancelled` stored on `run.final` (`seen == [("cancelled", S.CANCELLED)]`).
- [OK] L-065 — the gate → terminal path is untouched (full suite green).
- [OK] L-068 — `index.html` on the reports origin gets `no-cache, must-revalidate` (probe + `test_reports_origin.py`).
- [OK] L-069 — no `<Button asChild>`. Links use `buttonVariants` on `<Link>`/`<a>`.
- [OK] L-090 — the widths come from `scripts/probes/testing-widths.mjs` (dev run6, 1280/1440/1920 × both themes). Not re-run by the reviewer.
- [OK] L-091 — the terminal write is the CAS (`store.py` `claim_status`: `UPDATE … WHERE status NOT IN (terminal)`, `rowcount == 1`). The 8-thread race test announces once.
- [OK] L-092 — `__test__ = False` on `TestExecutionState` (verified: `TestExecutionState.__test__ is False`, still a `_TypedDictMeta`).
- [OK] L-094 — no new run status (`cancelling` rejected for this reason, session-1 decision 1).
- [OK] L-096 — the 410 report route and the setup-only `DELETE …/replay/{job_id}` add no ordering conflict.
- [N/A] L-001, L-002, L-004, L-007, L-012, L-016–L-019, L-021, L-023, L-024, L-029, L-031, L-033, L-034, L-041–L-057, L-059, L-060, L-062–L-064, L-066, L-070–L-076, L-081, L-082, L-084–L-088, L-095, L-097–L-100 — areas or mechanisms not in this diff. No agent called glab or a CI-variables API (L-100).

### Gates (from both checks)
- [OK] every gate listed in both checks (see the Gates table above).

## Sub-spec items

| Item | Verdict | Evidence |
|---|---|---|
| B1 | OK | `hooks.ts` keeps an `ended` set, nulls `replay_job` in the cache, and uses `cancelRefetch: false`. Two poll-count tests in `item.test.tsx`. |
| B2 / D26 | OK | `reports_origin.py`, `cli/main.py:150-167`, 26 socket tests, 410 route, probe 12/12. m2 sandbox flags accepted (recorded in D26). |
| B3 + MJ3 | OK | `manager.py` / `store.py`, 6 new real-worker tests. |
| MJ1 + m6 | OK | `_follow_script` is the one writer (`kb/testexec_store.py`). Tests cover the execution, verification overlay and rollback paths. |
| MJ2 / D27 | OK | `_check_code` refuses a non-literal contract, a `contract` field is a 400, `changed` is returned, and the page shows `ContractTable`. |
| m1, m4, n1 | OK | `daf3612`; group-kill test parametrised over the platform helper and the fallback. |
| m3 | OK | `_drop_debug_trace` + template `.gitignore`. |
| D28 (m5) | OK | `_promote_actions` / `promote_proven_actions`. Tests: promote, stale hash, failing dependent, verification never promotes. |
| D29 (m10) | OK with mi-1 | ANSI strip and storage are tested. The replay → API URL glue is not. |
| D30 / m11c | OK | `?kind=` via `kindFromUrl` (`LibraryView.tsx`). |
| D31 / m7 / m11b | **MJ-1** | grid pattern OK; m7's target page breaks for the suite's own scenarios |
| D32 / m9 / m11d | OK | `ExecutionPage.tsx`, `executions.test.tsx`. |
| m8 | OK | `CasesTable.tsx` `min-w-[980px]`, Type 96, Review 112. |
| n2 | OK | `db/runner.py:75-77`. |
| Capture #2 | OK | Root cause evidenced (escalate gate). `run_status` + panel message, test `library.test.tsx:298`. |

## Findings

### Blockers
None.

### Majors

- **MJ-1 — m7 sends the regression suite's own scenarios to a page that only handles feature scenarios.**
  `RegressionView.tsx:244` opens `scenarioPath(appUuid, r.scenario.id)` for every member, including the suite's own
  regression scenarios (`ref === null`). For those, `GET /api/test-scenarios/{id}` answers
  `feature: {id: null, name: null, app_uuid: null}`, because the regression suite has no feature (D9,
  `kb/testdesign.py:221-229`). `TestScenarioPage` treats that object as a real feature:
  - the breadcrumbs become "Application › Feature › Tests", linking `/applications/<app>/features/null` and
    `…/features/null/tests` (`TestScenarioPage.tsx:44-45`; real browser on :8760, TS-000024, `own-crumbs.mjs` output);
  - Automation reads **Not automated** for TS-000024 (`TestScenarioPage.tsx:326-334`: `useTestSuite(null)` → no cases →
    `scenarioAutomation([])`). The suite read for the same scenario says `automated: true`, last result passed TE-000007
    (screenshot `/tmp/genesis-probes/51-15-review/own-TS-000024.png`);
  - Delete of a Draft own scenario navigates to `testsTabPath(appUuid, null)` (`TestScenarioPage.tsx:158`).

  The page is pre-existing, but nothing linked an own regression scenario to it before 51-15 (`git grep scenarioPath
  cca8ff8 -- web/src/features/testing` finds none). m7 now makes it the click target. The m7 tests
  (`regression.test.tsx`, "m7: a member row opens its scenario page") assert only the pathname, so the null-feature
  page is untested. **Fix:** make `TestScenarioPage` handle a feature-less (regression) scenario. Its crumbs should read
  Application › Testing › Regression (`?tab=testing&view=regression`). Automation should come from the scenario's own
  case statuses (a read that does not need the feature suite, or the regression read's `automated`). Delete should
  return to the Regression view. Add a page test with the recorded own-scenario shape (`feature.id === null`). The
  other option is to send own scenarios somewhere else on purpose; either way the user must not land on `features/null`.

### Minors

- **mi-1 — D29's backend glue has no test, and the recorded contract fixture hides it (L-011, L-083).**
  `test_testing_api.py:624-626` records `library-setup-item.json` after a replay with `FakeRunner`. That runner writes
  no `report/html/index.html` and no screenshot, and `settings.reports_url` is unset, so the fixture carries
  `report_url: null, screenshot_url: null`. `item.test.tsx:374-377` then hand-writes both URLs. Three steps are never
  exercised: the replay's discovery of `report/html/index.html` and the first `test-results/**/*.png` on a failure
  (`library_service.py`, the `record_replay(report=…, screenshot=…)` call); the item read's pop-and-map to the reports
  origin (`api/testing.py:633-639`); and the replay-root regex against a real `replay_dir` name. **Fix:** in one API
  test, make the fake runner write both files and fail, set `reports_url`, and assert the two URLs (and that a passing
  replay has no `screenshot_url`). Re-record the fixture so it carries real URLs.
- **mi-2 — `resume`/`respond` of a terminal run is not guarded (pre-existing, next to B3).** `manager.py:399-402`
  and `:416` call `set_status(RUNNING, enforce=False)` and spawn a worker for any run. A resume POST on a `cancelled`
  or `done` run would overwrite the terminal status, which the new CAS exists to prevent. 51-15 guarded `pause`/`cancel`
  against terminal runs but not these two. **Fix:** refuse (409) a terminal run in `resume`/`respond`, with a test, or
  record it in the backlog.
- **mi-3 — `_worker_state` is never pruned** (`manager.py:85, 213`). There is one dict per spawned run for the life of
  `serve`. This is small, but the map is unbounded on a long-running server. **Fix:** pop it in `_announce_final`
  (or in `on_exit` when the run is terminal).

### Nits

- **n-1** `api/testing.py:781` reads `recordings._rm`, a private attribute, from the route layer. Pass the run manager
  in or add a public accessor.
- **n-2** IPv6 loopback: `serve --host ::1` gives `GENESIS_REPORTS_URL=http://::1:8860` (`cli/main.py:162`, no
  brackets), and the `Host` allow-list holds `::1:8860`, not `[::1]:8860` (`reports_origin.py:148-158`). The same
  pattern already exists for `GENESIS_API_BASE`. Bracket IPv6 hosts in both places.
- **n-3** `reports_origin.py:116` `read_bytes()` loads a whole file (for example `trace.zip`) into memory per request.
  Streaming with `shutil.copyfileobj` would be gentler. Loopback, single user: optional.
- **n-4** Executions "N of M" (`ExecutionsView.tsx:21, 82`): M is capped at `LIMIT = 200`, so an app with more than
  200 executions reads "… of 200". Show "200+" when the cap is hit, or take M from a count.
- **n-5** `report_url` (`reports_origin.py:171-184`) does not check that the file exists. After the 20-per-app replay
  retention, a setup's `last_replay.report_url` and its inline screenshot 404. Consider `is_file()` before linking.
- **n-6** D32 names the crumb trail "Application › Testing › Executions › `TE-…`". The built trail stops at Executions,
  and the key is the page title. That is consistent with the other Testing pages, so record it in the As built.

## Decisions and deviations

Session 2:
1. **Rows with their own controls are not `role="button"`.** Accepted. A `<button>` inside `role="button"` is a real
   axe `nested-interactive` failure. The keyboard path exists: "Open …" for Regression, Edit for Setup users, tested in
   `regression.test.tsx` ("m7: the title button opens the scenario with Enter").
2. **Page size 20.** Accepted. D31 fixes no size, and these lists are longer per screen than Stories.
3. **"N of M" from a second unfiltered query.** Accepted. Both calls share a query key when no filter is set
   (`qk.testing.executions(app, {...f})`, and undefined keys drop out of the hash). See n-4 for the cap.
4. **"Not run" = not-run + skipped; no Back button.** Accepted. D32 lists no Skipped tile, and the breadcrumb is D32's
   way back. Testing → `?tab=testing` opens the tab's default view.
5. **Regression Source as plain text, the reason under the badge.** Accepted. This came from the probe (wrapped pills).

Session 1 (As built §Decisions):
1. **Cancel claims `cancelled` before the kill; no `cancelling` status.** Accepted (L-094). Covered by the CAS and
   race tests.
2. **m2 sandbox `allow-popups allow-popups-to-escape-sandbox`.** Accepted. The page is served with
   `script-src 'none'` + nosniff, the frame has no `allow-scripts` and no `allow-same-origin`, and D26 already records
   it.
3. **HTML reporter only for library replays.** Accepted. The parity copy stays byte-equal
   (`test_the_replay_generators_match_the_platform_copy`).
4. **Action replay POST → 400; no DELETE route.** Accepted.
5. **A verification overlay on actions or setups promotes no case.** Accepted (D24). See
   `story_verification_finalizer.py:202-213`.
6. **`Host` check on the reports origin.** Accepted (DNS-rebinding guard).

## Not verified here

- The L-090 width probe was not re-run. Its numbers come from the dev's run6.
- Live pause → resume and cancel against a real `test-execution` run, a live setup replay showing Open report and
  the screenshot, and the 51-12 steps 18/22 belong to the later 51-12 re-run. :8760 still runs session-1 backend code
  and was not restarted.

## Verdict: NEEDS_CHANGES

All gates are green and every blocker, major and decision from the 51-12 review is closed with tests. One new major
remains: **MJ-1**. m7 makes the suite's own regression scenarios open a page that links `features/null`, misreports
their automation and has a broken Delete return. Fix MJ-1 with a test, and preferably mi-1 (the D29 glue test plus a
re-recorded fixture). mi-2, mi-3 and the nits may go to the backlog if the user prefers. A re-review of MJ-1 needs only
the web diff, vitest/tsc/lint, the bundle check, and one browser look at TS-000024.

---

# Re-review 51-15 — delta base genesis `750f0d1` (genesis-review, 2026-11-05)

Scope: genesis `b4265da` (fixes) and `521910b` (web/static), HEAD `521910b`, both shas resolved. genesis-workflows and
project-tracker are unchanged since the review above. Inputs: `genesis-ctx check --since 750f0d1 --repo genesis`
(94 files incl. the bundle; areas api, runs-worker, features-stages, web-shell plus the always-on ones), and the
non-bundle diff (31 files).

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis` | All checks passed |
| `pytest -q -p no:warnings tests/test_runs.py tests/test_testing_api.py` | 68 passed (the full 1727 is the dev's claim, not re-run: the delta's backend change is these two files' subjects) |
| web `npm run lint` | 0 errors, 20 warnings. `npx eslint` on the touched files (`TestScenarioPage.tsx`, `features/testing`, `shared/layout`, `types/testdesign.ts`) is clean |
| web `npm run typecheck` | clean |
| web `npx vitest run` | **698 passed (61 files)** |
| stale bundle: `npx vite build --outDir /tmp/51-15-rr-static` then `diff -r /tmp/51-15-rr-static web/static` | identical. `git status --short --untracked-files=all` afterwards is empty |
| Real browser, read-only: `/tmp/genesis-probes/51-15-review/rr-TS-000024.mjs` on :8760 (not restarted) | see MJ-1 below. Screenshot `rr-TS-000024.png`. The served bundle `assets/index-CyK02tVH.js` is the one in `web/static` at `521910b` |

Probe note: the first probe run recorded one non-GET, `POST /api/collab/pull`. It comes from the app shell's collab
pull on load, not from the scenario page. The second run aborted every non-GET. No scenario, case or run was written.

## Checklist (delta)

- [OK] ADR-009, ADR-012 — `resume`/`respond` still spawn a fresh worker from the checkpoint for a non-terminal run.
  Only a missing or terminal run is refused (`manager.py` `_resumable`).
- [OK] ADR-023, ADR-028 — the 409 mapping is in `run_routes.py`. The web change builds no `/api` URL: crumbs and
  Delete use `testingViewPath` and literal SPA routes.
- [OK] ADR-027, ADR-055 — the feature-less Add step reuses the Regression view's `CasePicker`. No new primitive or token.
- [OK] ADR-050 — no lifecycle path changed. The D28 refusal text in the re-recorded `error-lifecycle.json` is the text
  from `domain/transitions.py`.
- [OK] ADR-078 — a regression scenario is not given a feature. The page now reads the D9 shape as it is.
- [N/A] every other ADR on the check list — the delta does not touch its behaviour.
- [OK] L-003, L-005, L-093 — `_announce_final` still stores, logs `run.final` and then closes the bus. The
  `_worker_state` pop comes after the close. The cancel test still asserts `seen == [("cancelled", S.CANCELLED)]` and
  `run_id not in mgr._worker_state`.
- [OK] L-008 — worker-exit handling is unchanged. The killed worker's handlers keep `seen` by closure, so popping the map
  cannot turn a late exit into a failure.
- [OK] L-011, L-083 — closes mi-1. The fixtures are re-recorded from real responses. `library-setup-item.json:40` carries
  a real reports-origin `report_url`. `error-lifecycle.json` now carries the D28 words, and `item.test.tsx` asserts them
  in the alert. `ScenarioDetail.feature: FeatureRef | NoFeatureRef` mirrors the backend (`api/testdesign.py:388-389`).
- [OK] L-014 — jest-axe on the new own-scenario page test.
- [OK] L-030, L-089 — the bundle commit is separate, a fresh rebuild is identical, and the status check ran as its own call.
- [OK] L-069 — no `<Button asChild>` added.
- [OK] L-091 — the guard is a plain read before a status write. Its job is to refuse a terminal run, not to win a race.
  A concurrent cancel still goes through the terminal CAS (`claim_status`).
- [N/A] the remaining lessons on the check list — not in this delta.
- [OK] gates — the table above.

## Prior findings

| Finding | Verdict | Evidence |
|---|---|---|
| **MJ-1** | **Closed** | `featureOf()` guard (`TestScenarioPage.tsx:41-42`). The crumb key `ts-regression:<id>` gives Application › Testing › Regression (`breadcrumbs.ts:156-160`). Automation comes from `data.cases`. `cases_for_scenario` builds `case_dto` with `automation_status` for every step case whatever its suite (`kb/testdesign.py:257`, `:308-311`). Add step uses `CasePicker`. Delete returns to `?tab=testing&view=regression`. Tests: `phase49.test.tsx` "Scenario page — a regression-owned scenario (51-15 review MJ-1)" (2 tests) and `breadcrumbs.test.tsx` "a regression-owned scenario reads Application › Testing › Regression…". **Live check on TS-000024:** the API answers `feature: {id: null, …}` and TC-000007 is `automated`. Crumbs are Application › Testing (`?tab=testing`) › Regression (`?tab=testing&view=regression`), no `features/null` anywhere in the DOM, the badge reads **Automated** (it read Not automated before), and the Feature → Test case → Add case picker is present. |
| mi-1 | Closed | `test_a_setup_replay_links_its_report_and_failure_screenshot_on_the_reports_origin` drives the real replay, then the store, then the item read. A failure gives both URLs on `:8860/library-replays/<app>/<key>-…`, with ANSI stripped and no `report`/`screenshot` path keys. A pass gives `screenshot_url is None`. |
| mi-2 | Closed | `test_resume_or_respond_of_a_terminal_run_is_refused_and_changes_nothing` covers done/cancelled/failed × resume/respond, plus a missing run. The status is kept, and no worker or event appears. |
| mi-3 | Closed | The pop is in `_announce_final`. Asserted in the real-worker cancel test. |
| n-4 | Closed | `ExecutionsView.tsx` shows `200+` at `LIMIT`. Test "at the 200-row cap the count says 200+". |
| n-1, n-2, n-3, n-5 | Backlog, accepted | Carry to `specs/backlog/phase-51-follow-ups.md` as proposed. |
| n-6 | Decision, accepted | The trail stops at Executions, and the page title is the key. Record it in the As built. |

## New findings

### Blockers / Majors
None.

### Minors
None.

### Nits
- **rn-1** `types/testdesign.ts:198-205`: `NoFeatureRef` was inserted between the `GET /test-scenarios/{sid}` JSDoc and
  `ScenarioDetail`, so that comment now sits above `NoFeatureRef`'s own JSDoc and `ScenarioDetail` has no doc. Move the
  comment back above `ScenarioDetail`.
- **rn-2** The 409 for resume/respond of a terminal run is tested at the manager only. No route test POSTs
  `/api/runs/{id}/resume` on a done run. The mapping is two lines and visibly right. Add a route test with the next
  change, or put it in the backlog.
- **rn-3** The page test proves there is no `features/null` in the page body, and the crumb test drives the crumb
  store directly. No single test renders the page inside the layout and checks the trail. The live probe covers that
  gap, so this is optional.

## Not verified here

- The full pytest suite was not re-run (the dev reports 1727 passed). Only the two touched test modules were run.
- No live setup replay with Open report and a screenshot, and no live resume of a terminal run. Those belong to the
  51-12 re-run. :8760's backend still runs pre-`b4265da` Python, because serve was not restarted as instructed.
  The browser look exercised only the bundle, which is served from disk at HEAD.

## Re-review verdict: SHIP

MJ-1 is fixed, tested, and correct in a real browser on TS-000024: Regression crumbs, no `features/null`, and an
Automated badge from the scenario's own cases. mi-1, mi-2, mi-3 and n-4 are closed with tests. Every gate is green and
the bundle is fresh. rn-1 to rn-3 are optional polish.
