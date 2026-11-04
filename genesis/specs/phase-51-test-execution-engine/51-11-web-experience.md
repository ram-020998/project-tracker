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
     Stop" bar while the capture is `recording`); a "Proposals to review" panel per capture (new / reused / updates,
     code diff, replay result, accept/reject per item, Accept all).
   - **Item page** (`/applications/:appUuid/testing/actions/:key`, `/setups/:key`): contract form; **CodeMirror 6**
     editor, lazy-loaded on this route only (L-015); Save shows typecheck errors inline; breaking-change refusal offers
     Save as new action; where used; history with Revert; lifecycle buttons (Approve/Retire/Restore/Delete with refusal
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
     `refetchInterval`, about 2 s, stopped on a terminal status), then refreshes the setup read; a failure shows the
     job's error; a 404 (server restarted) just refreshes the setup read. The Settings → CLI card's Install uses the
     same job.
2. **Settings → Environments** (`web/src/features/settings/components/EnvironmentsSection.tsx`): the dev switch becomes
   a **Type** select (Dev, QA, UAT, Production, Other); the single-Dev and single-QA rules and the host-collision refusal
   shown as field errors; a type badge in the list (F3). The form sends `type` only and never `is_dev` (51-05 As built
   3: the backend still honours an explicit `is_dev: false` from older clients).
3. **Settings → CLI:** an "Appian browser testing" card beside `GwsConnectorCard`/`SailConnectorCard` (Node, npm,
   Chromium, vendored `playwright-appian` version, problems with fixes).
4. **Workbench:** lanes in the API's new order (D6); dragging Deployment → Verification opens a confirm dialog ("The
   story's changes are deployed to QA?" + readiness problems); with no QA environment the dialog is the F2 warning and
   the card stays; card states while queued/running/failed/passed (the Design/Implementation patterns).
5. **Story page** (ADR-071 canonical page): a **Verification** section — status, the report (iframe of the served
   HTML), defects when sent back, proposals review (as the Library panel).
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
