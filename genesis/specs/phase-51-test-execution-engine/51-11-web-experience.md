# 51-11 — Web experience

> **Status:** SPEC-DRAFTED 2026-11-02. Repo: **genesis** (`web/`). Parent: `specs/phase-51-test-execution-engine.md`.
> Decisions: 51-01 D5, D6, D7, D12, D13, D14, D15, D16, D21, D23; F2, F3.

## 1. Goal

Every screen of the phase on the existing design system (ADR-027/055): the **Testing** tab and its four views, item
and execution pages, the Settings changes, the Workbench Verification flow and the additions to Phase 49 pages.

## 2. Screens

1. **Application → Testing** (`web/src/features/applications/ApplicationDetail.tsx:32`: add `testing` after
   `test-impact` to `APP_TABS`, one trigger, one content; sub-view in `?view=library|regression|executions|setup`).
   Feature code in `web/src/features/testing/**`.
   - **Library:** actions and data setups table (key, name, area, role, status, used by, last result), filters, search;
     **New action**, **Record workflow** (dialog: role, name + intent, start page; then a fixed "Recording as <role>…
     Stop" bar while the capture is `recording`; start answers 409 for a conflict such as a recording already running,
     400 for a bad request); a "Proposals to review" panel per recording capture (`/testing/captures`, recording
     captures only; verification proposals stay on the story routes) with new / reused / updates, code diff, replay
     result, accept/reject per item, Accept all, and Discard only while the capture is `recording` or `ready` (else 409).
   - **Item page** (`/applications/:appUuid/testing/actions/:key`, `/setups/:key`): contract form; **CodeMirror 6**
     editor, lazy-loaded on this route only (L-015); Save shows typecheck errors inline (422 `{detail, typecheck}`);
     breaking-change refusal offers Save as new action (`POST …/{key}/save-as-new`, 51-10); where used; history with Revert; lifecycle buttons (Approve/Retire/Restore/Delete with refusal
     reasons); **Replay** (a `library-replay` job: spinner + Cancel, then the result; 51-10); every save sends the
     page's `expected_row_version` and a 409 stale reloads the item; Run dependents; "changed outside Genesis" banner
     with diff + Adopt.
   - **Record workflow readiness:** when recording start returns problems (no QA, no test user for the role, the
     `genesis-test-authoring` skill or the `action-capture` workflow not installed), the dialog lists them, each with
     its fix (a link to Settings → Skills / the Catalog install).
   - **Regression:** members grouped by data setup (shared and private instances), referenced feature scenarios with
     their feature, own regression scenarios, non-automated flagged; add reference (scenario picker), new regression
     scenario, reorder; latest result + pass-rate trend (lazy chart, L-015; pass rate = (passed + flaky) / scenarios,
     cancelled executions skipped, 51-08 As built 6); **Run now** (shows the returned `not_run` list). Retired
     references show **Retired, not run** with **Remove reference**; undismissed suite change notes show above the list
     with Dismiss (D21). Causes are `feature-deleted` (including a feature removed by a collaboration pull),
     `case-deleted` and `scenario-deleted`; one delete can write two notes (one per kind), so group notes by cause +
     `cause_key` + time into one entry. The Phase 49 scenario retire confirmation adds "used by the
     regression suite" when `referenced_by_regression` is true.
   - **Executions:** table (key, kind, trigger, status incl. Queued, totals, duration, started); → **execution page**
     (`/applications/:appUuid/testing/executions/:key`): summary, scenarios → cases with status, flaky/blocked badges,
     failure detail (error, screenshot), **Open Playwright report** (served route, new tab), Cancel when queued/running.
     Built in 51-06: the report folder is `<run>/report/{report.json, junit.xml, playwright.log, html/index.html,
     test-results/…}`, result attachments are paths relative to it, and the report route serves any file under it.
   - **Setup:** QA environment (name + host, or the "no QA environment" warning linking to Settings → Environments);
     site URL; test users table (role key, label, username, password set/unset, set password field, admin-account
     warning); regression schedule (off / daily / weekly, days, time); runtime status (Node, Chromium + Install,
     workspace path + "Open folder", Update testing runtime). Install Chromium, Create workspace and Update testing
     runtime start a setup job (D23): the button shows a spinner and polls `GET /testing/jobs/{id}` (TanStack Query
     `refetchInterval`, about 2 s, stopped on `succeeded`, `failed` or `cancelled`, 51-10 As built), then refreshes the
     setup read; a failure shows the job's error; a 404 (server restarted) just refreshes the setup read. The Settings →
     CLI card's Install uses the same job.
2. **Settings → Environments** (`web/src/features/settings/components/EnvironmentsSection.tsx`): the dev switch becomes
   a **Type** select (Dev, QA, UAT, Production, Other); the single-Dev and single-QA rules and the host-collision refusal
   shown as field errors; a type badge in the list (F3). The form sends `type` only and never `is_dev` (51-05 As built
   3: the backend still honours an explicit `is_dev: false` from older clients).
3. **Settings → CLI:** an "Appian browser testing" card beside `GwsConnectorCard`/`SailConnectorCard` (Node, npm,
   Chromium, vendored `playwright-appian` version, problems with fixes).
4. **Workbench:** lanes in the API's new order (D6); dragging Deployment → Verification opens a confirm dialog ("The
   story's changes are deployed to QA?" + readiness problems); with no QA environment the dialog is the F2 warning and
   the card stays; a start refusal is a 409 with top-level `{detail, problems, code}` — show `problems` and a message
   per `code` (`no_qa`, `no_cases`, `no_scenario`, `not_installed`, `not_ready`, `busy`); card states while
   queued/running/failed/passed (the Design/Implementation patterns; queued = `active.status == "queued"`).
5. **Story page** (ADR-071 canonical page): a **Verification** section built on 51-09's read (stage, run status,
   execution, active, report, defects, result, proposals; after a failed launch, the newest verification execution with
   its problems) — status, the report (iframe of the served HTML), defects when sent back (from the read's `defects`,
   with each failed result's triage class), and the proposals review (as the Library panel) for the item kinds
   action/setup (new or update), case, scenario_setup, regression and regression_scenario, each with code and hash.
   After a 400 on apply, refetch before retrying (the decisions were stored, so `row_version` moved). A run waiting at a
   gate shows the gate's own options, not hard-coded buttons: `escalate_blocked` offers Retry / Send back / Accept as
   passed, `escalate` offers Send back / Accept as passed / Stop; Stop leaves the card in Verification.
6. **Phase 49 pages:** case page — automation status, case script (read-only view + "Edit script" to an editor page),
   last results; scenario page — data setup picker + "changes shared data", automated flag, last results, Run; feature
   Tests tab — automation badges; **Test Impact** tab — **Run impacted tests** + the "not covered by automation" list,
   the new **Regression suite** group (51-06: `regression` in the impact result; referenced scenarios marked), and a
   "nothing automated is affected" message when the run returns `execution: null`.
7. **Application header:** "Last regression: N failed" badge linking to the execution.

## 3. Rules

Existing primitives and tokens only (ADR-027/055); no `<Button asChild>` (L-069); `/api` prefix only in the central
client (ADR-028); types in `web/src/types/testing.ts` mirror the 51-10 fixtures (L-011); jest-axe on every new
interactive component; sortable headers expose `aria-sort`; column widths from a real-browser probe (L-090);
`npm run build` and commit `web/static/` as separate steps, then prove it with a rebuild and a clean `git status`
(L-089).

## 4. Tests

Vitest + RTL + MSW per screen (happy paths, refusals, recording bar, proposals review, editor save errors, environment
type rules, Verification dialog incl. no-QA warning, lane order), jest-axe, type/fixture parity.

## Context manifest

```toml
areas    = ["web-shell", "stories-workbench"]
adrs     = ["ADR-027", "ADR-028", "ADR-049", "ADR-055", "ADR-071"]
lessons  = ["L-011", "L-014", "L-015", "L-069", "L-089", "L-090"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-10-api.md"]
code     = ["genesis/web/src/features/testing/**", "genesis/web/src/features/applications/**", "genesis/web/src/features/settings/**", "genesis/web/src/features/workbench/**", "genesis/web/src/features/test-design/**", "genesis/web/src/types/**"]
upstream = ["51-10"]
```

## As built (2026-11-04, genesis-dev)

**Task restated.** Build every Phase 51 screen in `genesis/web` on the existing design system, against the 51-10
contract (§2 table, `web/src/types/testing.ts`, the 42 fixtures): the application Testing tab and its four views, the
item, case-script and execution pages, the D23 / library-replay job polling, the Settings changes, the Workbench
Verification flow, the story page Verification section, the Phase 49 page additions and the header badge. Web only;
change a backend shape only for a wrong fixture (none was wrong); don't change any working workflow.

**Applicable rules.** ADR-027/055 (existing primitives and tokens), ADR-028/L-010 (`/api` only in the client),
ADR-049 (one more application tab), ADR-061/062/068 (lane order only; Design/Implementation untouched), ADR-071 (one
story page), ADR-036/048 (single Dev), ADR-026 (passwords write-only). Lessons L-011/L-083 (fixtures = contract, real
shapes), L-014, L-015 (CodeMirror lazy), L-069 (no `<Button asChild>`), L-089 (build and bundle commit as separate
steps, proven by a rebuild + empty status), L-090 (widths left to 51-12's probe), L-094 (lane consumers grepped).

### Commits (genesis, base `83fa255`, local, not pushed or tagged)

- `8f013be` feat(web,51-11): all source, tests, `package.json` + lockfile (73 files, +6702 / −52).
- `0170834` build(web,51-11): the rebuilt `web/static` (68 files).
- Proof (L-089): `npm run build` after the bundle commit, then `git status --short --untracked-files=all` in its own
  call: empty.
- genesis-workflows: no change. project-tracker: this As built, `reviews/51-11-review.md`, backlog
  `phase-51-follow-ups.md` §16–§19.

### Changed (genesis/web)

- **Dependency:** `@codemirror/lang-javascript` 6.2.5 (the one new dependency; CodeMirror 6 itself,
  `@uiw/react-codemirror`, was already used by `JsonEditor`). Installed from registry.npmjs.org, which the lockfile
  already uses everywhere (the configured Artifactory host did not resolve). Its own 85 kB `CodeEditor` chunk;
  `LazyCodeEditor` is the only importer.
- **Shared:** `lib/api/client.ts` `ApiError.body` = the whole error body (additive; 51-10 §1 puts `problems`,
  `typecheck`, `code` beside `detail`, which the client used to drop). `lib/api/testing.ts` `testingApi` (every §2
  route; `reportUrl` is the one absolute `/api` URL, for a new tab or `<img>`). `qk.testing.*`,
  `qk.workbench.verificationGate`. Breadcrumbs for `…/testing/:section/:key`. Routes `…/testing/actions/:key`,
  `…/testing/setups/:key`, `…/testing/case-scripts/:caseKey`, `…/testing/executions/:key`.
- **`features/testing/`:** `hooks.ts` (queries; `useTestingMutation` invalidates testing + testDesign; `useJobRunner`:
  polls `GET /testing/jobs/{id}` every 2 s, stops on succeeded/failed/cancelled, a 404 just refreshes), `logic.ts`
  (error-body readers, `VERIFICATION_CODE_MESSAGES`, tones, durations, `groupNotes`, `lineDiff`), `paths.ts`,
  `TestingTab` (`?view=`), `LibraryView` + `NewItemDialog` + `RecordDialog` + `RecordingBar` + `CapturesPanel`,
  `ProposalsReview` (shared with the story page), `LibraryItemPage` + `ContractForm` + `CodeEditor`/`LazyCodeEditor`,
  `CaseScriptPage`, `RegressionView` + `ScenarioPicker` + lazy `PassRateChart`, `ExecutionsView`, `ExecutionPage`,
  `SetupView` + `setup/*`, `AutomationBadge`, `RegressionBadge`.
- **Settings:** `EnvironmentsSection` Type select (Dev, QA, UAT, Production, Other; sends `type` only, never
  `is_dev`; refusals as field errors; the row "Set as dev" kept). `cli/TestingRuntimeCard` at the top of `CliTab`.
- **Workbench:** `lanes.ts` order (D6), `BoardPage` Deployment → Verification opens `VerificationDialog` (per-code
  messages, `no_qa` = the F2 warning, the card stays), `StoryCard` verification states, `VerificationSection` on
  `StoryWorkspacePage`, `types/workbench.ts` helpers.
- **Phase 49 pages:** case page (automation, read-only script + Edit script, last result), scenario page (data setup
  picker + changes shared data with the CAS `row_version`, Run, retire confirm "used by the regression suite"),
  `CasesTable` Automation column, `TestsTab` badges, `TestImpactTab` Run impacted tests + Regression suite group.
- `types/testing.ts`: `PlanScenario.steps` is `number` (the server sends `len(s.steps)`; the fixture had `2`). The
  only type correction; a value-shape test now pins it.

### Tests

- Web: vitest **647 passed, 61 files** (510 at 51-10 + 137). New files: `testing/{logic,library,item,regression,
  executions,setup,phase49,testingTab}.test.ts(x)`, `workbench/verification.test.tsx`,
  `settings/environments-type.test.tsx`; additions to `contract.test.ts`, `breadcrumbs.test.tsx`, and MSW handlers in
  `settings`, `applications`, `objectWiki`, `testDesign` tests. Every handler answers with the 51-10 fixtures.
  jest-axe on every new view and dialog (two popper-menu runs disable only axe's page-level `region` rule).
- Gates (final, after the review fixes): `tsc --noEmit` clean; `npm run lint` 0 errors (20 warnings, all in files
  that existed before); `npm run build` OK. No Python changed, so no pytest/ruff run.
- **Not run:** a real browser, real QA, a real recording, replay, verification run or gate; jsdom computes no layout
  (L-090). These are 51-12's.

### Review

`reviews/51-11-review.md`. First pass **NEEDS_CHANGES**: major 1 (a queued Verification card showed nothing and was
not locked; the test used a shape the backend never sends, L-083), minors 2–8, nits 9–14. Fixed 1–6, 8, 9–13 with
tests; 7 and 14 deferred (below). Re-review **NEEDS_CHANGES**: R1 major (the lock from fix 1 locked a never-launched
card for good, because the board read can't tell queued from never launched), R3 nit (sort). Fixed with the
reviewer's option (b), web-only. Second re-review **SHIP** (647 passed, fresh build identical to `web/static`).

### Decisions / deviations

No ADR deviation. **Bold = for 51-12 / 51-13.**
1. **Verification card "Not started" does not lock** (review R1, option b). Queued and never-launched look the same
   on the board read, so the card shows a neutral "Not started" with an either-way tooltip and stays movable; it
   locks only while a run is pending/running/at a gate. Backlog §16 (needs a board-read field).
2. **CLI card placement.** apwt is vendored in genesis, not a registry CLI, so it has no CLI detail page beside
   gws/SAIL; the card sits at the top of the CLI tab. The spec's "beside `GwsConnectorCard`" needs a docs amendment.
3. **No "Open folder".** The contract has no such route; the Setup view shows the workspace path with Copy (§19).
4. **Scenario page:** `ScenarioDto` has no automated flag or last results; automation is derived from the cases'
   `automation_status`, last results are not shown (§18). The setup picker maps `setup_id` → key via the setups list.
5. **Verification read:** no launch problems in the contract; the section says the execution did not complete and
   links it (§17).
6. **Record dialog:** the server takes `intent` only, so the name is sent as `"<name> — <intent>"`.
7. **Report iframe** uses `sandbox="allow-scripts allow-same-origin"`, which on a same-origin URL is no real sandbox
   (review 7). **51-12: check whether the Playwright HTML report works without `allow-same-origin`; drop it if so.**
8. A library item's role can be changed but not cleared (`ItemSave.role_key` has no null; review 14).
9. Library filters and sort run client-side over the two list reads (the API's `area/role/status/q` are unused).
10. The scenario/case pickers go feature → suite (`testDesignApi.suite`), since no all-scenarios-of-an-app route
    exists.

**For 51-12 live acceptance (real browser, real QA):** a recording end to end (dialog problems + fix links, the bar
over the page, Stop → analysing → ready via the 3 s poll, proposals apply); a replay and a cancel on the item page;
Create workspace / Update runtime / Install Chromium jobs (spinner, error, a server restart mid-job → 404 → refresh);
the real CodeMirror editor (lazy load, both themes, aria-label), a typecheck 422, Save as new, Adopt after an outside
edit, Revert; Deployment → Verification with no QA, Testing not ready, a busy story, then a real run: "Not started"
while queued, Verifying…, a real `escalate` / `escalate_blocked` gate (buttons = the gate's options; Stop leaves the
card in Verification), the report iframe (decision 7), proposals apply incl. a 400 → refetch; Run impacted tests;
the header badge after a failed regression; the Settings Type select against the real single-Dev / single-QA /
host refusals (the field mapping was built from the backend source, not a live 400).
**For the L-090 width probe (several widths, both themes):** `LibraryView` (7 columns in `overflow-x-auto`),
`ExecutionsView` (`table-fixed`, `min-w-[900px]`, fixed 110/110/130/110/100/130 px, Totals flexible),
`CasesTable` (now `min-w-[1072px]`, Automation `w-[116px]`, set by eye), the Setup users table (password input
`w-44`), the Regression member rows (wrapping badges), the execution page (screenshots, long error `<pre>`), the
CLI tab with the card above the list, and the dialogs (Record, New item, environment, Verification).

### Lesson candidates

- **A fetch client that keeps only `detail` silently drops every reason a richer error body carries.** 51-10 put
  `problems`, `typecheck` and `code` beside `detail`; the client's `ApiError` kept `detail` alone, so no screen could
  have shown them. Keep the whole body on the error, and test a refusal through the real client.
- **A state derived from "no run yet" is two states.** "Stage, no run" meant both queued and never launched; locking
  on it trapped a failed launch in the lane with no way out (51-11 R1). Before locking or hiding a control on a
  derived state, list every backend path that produces the shape; when the read cannot tell them apart, show it
  neutrally and leave the user a way out.

### Code-map changes

For bible/03 in the "Phase 51" block (genesis-docs): `web/src/lib/api/testing.ts` (`testingApi`),
`ApiError.body`, `qk.testing` + `qk.workbench.verificationGate`, `web/src/features/testing/**` (the files listed
under Changed; `useJobRunner`, `ProposalsReview`, `LazyCodeEditor`), `settings/components/cli/TestingRuntimeCard.tsx`,
`workbench/VerificationDialog.tsx` + `VerificationSection.tsx`, `types/workbench.ts`
`isVerificationNotStarted`/`isVerifying`/`verificationFailed`/`verificationPassed`, the four new routes and the
Testing breadcrumb.
