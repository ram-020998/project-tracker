# Review 51-11 — base 83fa255 (genesis-review, 2026-11-04)

Scope: the uncommitted working tree of `genesis` against `83fa255` (51-10): 27 modified files under `web/` plus 44
untracked source/test files (`web/src/features/testing/**`, `web/src/features/workbench/Verification{Dialog,Section}.tsx`
+ `verification.test.tsx`, `web/src/lib/api/testing.ts`, `settings/components/cli/TestingRuntimeCard.tsx`,
`settings/environments-type.test.tsx`) and the rebuilt `web/static/` (to be committed separately after this verdict,
so not flagged). `git diff 83fa255 --stat -- genesis packages scripts tests` is empty: no backend change.
Contract: 51-10 §2, `web/src/types/testing.ts`, `web/src/test/fixtures/testing/*.json`.

**Live acceptance and the real-browser width probe: not run** (51-12's, per the brief).

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `npx tsc --noEmit` | clean (exit 0) |
| `npm run lint` | 0 errors, 20 warnings (all `react-refresh/only-export-components` in pre-existing files) |
| `npx vitest run` | **60 files / 636 tests passed** (22.9 s) |
| stale bundle: `npx vite build --outDir /tmp/51-11-static` then `diff -rq /tmp/51-11-static web/static` | **identical** |
| new dep: `npm ls @codemirror/lang-javascript` | 6.2.5; lockfile `resolved` registry.npmjs.org (the base lockfile already had 561 such entries, so no new registry mix) |
| bundle split: `web/static/assets/CodeEditor-*.js` 84.9 kB own chunk; main `index-*.js` 4 084 767 B vs 3 961 455 B at base (+123 kB for all the new screens) | OK |
| backend `pytest` / `ruff` | N/A: no Python file changed |

## Checklist

`genesis-ctx check --since 83fa255 --repo genesis` mapped the files to web-shell, features-stages, stories-workbench,
config-secrets (settings) and the always-on release-ci/security. Every line it listed is answered below.

### ADRs
- [OK] ADR-027 — established stack + existing primitives/tokens — every new screen composes `@/shared/ui` (Button,
  Badge, Dialog, Select, SegmentedControl, Switch, Field, Card, RelativeTime) and `@/shared/feedback/states`; grep for
  raw palette classes (`bg-red-`, `text-gray-`, …), `lucide-react` and `@mui` over the new/changed feature folders:
  no match. CodeMirror reuses the existing `@uiw/react-codemirror` (already used by `JsonEditor`).
- [OK] ADR-028 — `/api` only in the central client — the only `/api` literal outside tests is
  `lib/api/testing.ts` `reportUrl` (an iframe / new tab bypasses the client; inside `src/lib/api/`). Components use
  `testingApi.*`; `VerificationSection` uses the server-built `report_url`. No `fetch(` in components.
- [OK] ADR-049 — Applications-first IA — the Testing tab is one more application tab (`ApplicationDetail.tsx` APP_TABS
  after `test-impact`); no nav change.
- [OK] ADR-055 — light-first design language on the existing tokens — `bg-danger-subtle`, `border-warning/40`,
  `text-fg-muted` etc.; no new design system.
- [OK] ADR-071 — one canonical story page — Verification renders inside `StoryWorkspacePage` (`StoryWorkspacePage.tsx`
  +`VerificationSection`); no new story route; card "View run" goes to `/runs/:id`.
- [OK] ADR-061 — eight fixed lanes; the board renders the API's `lanes`; `lanes.ts` only reorders label/tone maps and
  `LANE_ORDER` (test "orders Deployment before Verification (D6)").
- [OK] ADR-062 / ADR-068 — Design and Implementation confirms untouched: `BoardPage.tsx` adds one branch
  (`to === "verification" && from deployment`) before the reorder; the design/impl branches and dialogs are unchanged
  (diff), and the existing workbench tests pass.
- [OK] ADR-036 / ADR-048 — single dev env — the Type select still makes exactly one Dev (server moves the tag); the form
  no longer sends `is_dev` (test "sends `type` and never `is_dev`"); a new env defaults to Dev only when none exists
  (`openAdd`, as before with `is_dev: !hasDev`).
- [OK] ADR-026 / security — no auth surface added; no secret in the client: `UsersSection` sends a password once via
  `PUT …/password` and renders only set/unset (test "renders users without any password text").
- [OK] ADR-078 / ADR-079 — Phase 49 pages only gain automation badges, script view, last result, setup picker, Run and
  the regression-aware retire confirm; no lifecycle change (Draft → Ready → Retired still via `LifecycleActions`).
- [OK] ADR-050 — status changes still go to the server (`transitionItem`, `/transition`); the web derives no lifecycle.
- [N/A] ADR-001, 002, 004, 005, 011, 013, 019, 020, 021, 022, 029, 030, 031, 033, 034, 035, 037, 038, 040, 041, 042,
  043, 044, 045, 046, 047, 056–060, 063–065, 067, 070, 072–077, 080 — web-only change; no engine, workflow, chat, KB,
  Hub, registry, persistence or release behaviour touched (the check maps them via the settings/features-stages areas).
- [OK] ADR-003 / 007 / 008 — local app UI; nothing role-gated.

### Lessons
- [OK] L-010 — client prepends `/api` centrally; `ApiError` gains `body` additively (`client.ts:10-19`), `detail` and
  `message` unchanged, so existing callers are unaffected.
- [VIOLATION → minor, finding 3] L-011 — the `PlanScenario.steps` correction (`number[]` → `number`) is right
  (`regression_service.py:249` sends `len(s.steps)`, fixture `regression-plan.json:19` has `2`), but no test fails
  on that drift: `contract.test.ts` checks key sets only, and `regression.test.tsx:51` casts the fixture through
  `clone<RegressionPlan>` (unknown).
- [VIOLATION → major, finding 1] L-011 / L-083 (real shapes in fixtures) — the card-state test feeds a queued card as
  `verification_run_status: "pending"` with a run id (`verification.test.tsx:179-190`); the backend never produces that
  for a queued verification (see finding 1).
- [OK] L-014 — no new ambient `.d.ts`; `git diff --stat` over `web/src/**/*.d.ts` and `test-setup.ts` is empty; new
  tests use `toHaveNoViolations` from the global setup.
- [OK] L-015 — `CodeEditor` is a default export imported only by `LazyCodeEditor` (`lazy(() => import("./CodeEditor"))`);
  grep: no other importer; its own 84.9 kB chunk in the build. `PassRateChart` is lazy too (see nit 12: Recharts is
  already in the main bundle through the `@/shared/ui` barrel, pre-existing).
- [OK] L-069 — no `asChild` in any new/changed file (grep); links styled with `buttonVariants(...)`.
- [OK] L-089 — the bundle commit is a separate step after this verdict; a fresh build equals the tree's `web/static`
  (identical diff above). The post-commit rebuild + clean `git status` proof is still owed after that commit.
- [N/A, deferred to 51-12] L-090 — new widths were set by eye: `CasesTable.tsx` `min-w-[1072px]` + Automation
  `w-[116px]`, `ExecutionsView.tsx` fixed columns; the probe is 51-12's (brief). 51-12 must probe CasesTable,
  ExecutionsView and LibraryView at several widths.
- [OK] L-094 — `verification` lane consumers: `lanes.ts`, `StoryCard`, `BoardPage` updated; no other lane registry in
  web (grep `LANE_LABEL|LANE_TONE`).
- [OK] L-012 — CLI tab keeps merged cards + custom entries; the testing card is added above `ResourceManager`
  (`CliTab.tsx:44-46`), the CLI list is unchanged (settings tests pass).
- [N/A] L-001, 002, 017, 019, 023, 025, 027–031, 034, 041–043, 045, 048, 049, 051, 053–058, 061–064, 068, 070–076, 081,
  082, 084–088, 091–093, 095, 096, 098–100 — no backend/engine/release/Hub code in this change.

### Gates
- [OK] `npm run lint && npm run typecheck && npm test` — see the table.
- [OK] `npm run build` — fresh build identical to `web/static/`.
- [N/A] `pytest` / `ruff check genesis` — no Python changed.

### Brief-specific checks
- [OK] aria-sort on sortable headers — `LibraryView.tsx` `SortTh` and `ExecutionsView.tsx` `SortHeader` set
  `ascending|descending|none`; the non-sortable "Totals" and the new CasesTable "Automation" `<th>` carry none (correct).
  Tests: library "lists actions and data setups with sortable headers…", executions "renders the fixture rows with
  aria-sort headers…".
- [Partial → minor, finding 4] jest-axe on every new interactive view — covered: Library table, Record dialog,
  proposals review, item page, case-script page, Setup view, CLI card, Executions view, execution page, Regression
  view, Verification dialog (start + no-QA), Verification section (3 states), environment dialog, Phase 49 case and
  scenario pages. Not covered: `NewItemDialog`, Regression `AddReferenceDialog` + `ScenarioPicker`,
  `NewScenarioDialog`, `RecordingBar`, the item page's Save-as-new block and Delete/Revert confirm dialogs, the
  scenario page's retire-confirm dialog, the Test Impact run/regression cards, `TestingTab` itself.
- [OK] no regression of existing behaviour — Design/Implementation board flows unchanged (diff + existing workbench tests
  pass); Phase 49 suite `testDesign.test.tsx` passes (one assertion re-scoped to the table because the new regression
  group also lists TS-000001; the original intent is kept); settings suite passes with the runtime handler added.

### Known deviations (judged)
- Workspace "Open folder" → Copy button (`WorkspaceSection.tsx`): **accepted**; no route exists in the 51-10 contract.
- Scenario page derives automation from its cases and shows no last results (`TestScenarioPage.tsx` AutomationSection):
  **accepted** as a contract gap; spec §2.6 asks for last results, so this needs a backlog line (ScenarioDto has no
  `last_result`).
- Verification read carries no launch problems: **accepted** as a contract gap; the section shows "This execution did
  not complete — open it" (`VerificationSection.tsx`). Backlog line needed (spec §2.5).
- Record dialog sends `"<name> — <intent>"`: **accepted**; the server has no name field and the intent is required.
- CLI card at the top of the CLI tab: **accepted**; gws/sail cards sit on their CLI's detail page and apwt has no
  registry CLI entry. The spec text ("beside GwsConnectorCard") should be amended by the docs agent.

## Findings

### Blockers
None.

### Majors
1. **The Verification card never shows "Queued", and a really queued card is not locked.**
   `types/workbench.ts:77-86` derives queued/verifying from `verification_run_status` (`pending`/`running`/
   `awaiting_input*`) and `StoryCard.tsx:118` renders the state only when `card.verification_run_id` is set. For a
   verification queued behind another execution the backend has no run yet: `StoryVerificationService.start` creates
   the stage (`status 'draft'`, `story_stages.py:108`) or resets it (`reset_for_rerun` sets `run_id=NULL`,
   `story_stages.py:210-212`), moves the card, then queues; `run_id` is bound only in `_launch`'s `prepare`
   (`verification_service.py:236`). So a queued card has `lane=verification`, `verification_run_id=null`,
   `verification_run_status=null`: it shows no state at all and `isVerifying` is false, so the card is draggable (e.g.
   to Done) while its execution waits. `pending` itself lasts only between two lines in `RunManager.start`
   (`manager.py:297-298`), so "Queued" is effectively unreachable. Spec §2.4 says "queued = `active.status ==
   "queued"`". The test hid it with a non-real shape (`verification.test.tsx:179-190`: `pending` + a run id; L-083).
   **Fix:** derive queued from the board card as "lane `verification`, a `verification_story_stage_id`, no
   `verification_run_id`, stage status `draft`/`in-progress`" (the board read carries no `active`), show "Queued"
   without the View run link, include it in `isVerifying` so the card locks; replace the `pending` test row with the
   real queued shape (`verification_run_id: null, verification_run_status: null, verification_status: "draft"`) plus
   a lock assertion.

### Minors
2. **The card shows nothing after a failed launch.** Same derivation: when `_launch` fails (`_fail`, problems in the
   execution totals) the stage is never bound, so the card sits in Verification with no state. Once finding 1's
   derivation lands, consider "Queued" vs a failed newest execution; at least note it with the launch-problems
   contract gap in the backlog.
3. **No drift test for the `PlanScenario.steps` correction (L-011).** Add a value-shape assertion in
   `contract.test.ts` (e.g. `typeof plan.groups[0].scenarios[0].steps === "number"`), or type-check the fixture by
   assignment instead of the `unknown` cast, so a revert to `number[]` fails.
4. **jest-axe gaps** (list in the checklist): add axe runs for `NewItemDialog`, `AddReferenceDialog`/`ScenarioPicker`,
   `NewScenarioDialog`, `RecordingBar`, the item page's breaking/Save-as-new state and confirm dialogs, the scenario
   retire confirm and the Test Impact run/regression cards. Spec §3: "jest-axe on every new interactive component".
5. **`TestingTab` has no test.** Nothing renders `?tab=testing&view=…` through `ApplicationDetail`/`TestingTab` (grep:
   no test imports `TestingTab`; existing view tests mount the views directly). Add one test: each `view` value opens
   its view, an unknown value falls back to Library, the SegmentedControl writes `view` to the URL.
6. **Inline query key.** `VerificationSection.tsx` `useGateRun` uses `["workbench", "verification-gate", runId]` and
   invalidates the same literal; coding standards §3 require the `qk` factory (add `qk.workbench.verificationGate` or
   reuse the runs key).
7. **Report iframe sandbox is effectively off.** `sandbox="allow-scripts allow-same-origin"` on a same-origin URL lets
   the framed page script the parent and call `/api`. The report is Genesis-generated and the app is local
   single-user, so this is low risk, but 51-12 should check whether the Playwright HTML report renders without
   `allow-same-origin` and drop it if so; otherwise keep the comment and record the decision.
8. **"Run impacted tests" errors only toast.** `TestImpactTab.tsx` `runTests` uses the default `useTestingMutation`
   (toast `detail`), so a 409 `not_ready` drops its `problems`; every other run button in this change renders
   `detail` + `problems` in place. Use `toastError: false` and render them like the scenario page's Run.

### Nits
9. `applications.test.tsx:59-60` registers the same `/testing/summary` handler twice.
10. `CasesTable.tsx:84-88` comment still says "fixed columns 700px + 256px"; it is now 816 + 256 = 1072.
11. `CapturesPanel.tsx` imports from `@/shared/ui` on two lines (`Badge, Loader2` and `Button`).
12. `PassRateChart.tsx:1-3` says it is "the only module that imports the shared Recharts `TrendChart`", but
    `shared/ui/index.ts:22` re-exports it and `OverviewPage`/`KitchenSink` import it, so Recharts is already in the
    main bundle (pre-existing); the lazy chunk is 264 B. Fix the comment.
13. `ExecutionsView` default sort "started desc" puts queued executions (null `started_at` → 0) at the bottom; sort
    nulls first for that column.
14. `LibraryItemPage` save sends `role_key: draft.role_key || undefined`, so a role cannot be cleared from the form;
    confirm that is intended.

## Verdict: NEEDS_CHANGES

One major (finding 1): the Verification card's queued state, a spec §2.4 requirement, does not work for a queued
execution, and the card is unlocked while queued; the test used a shape the backend never sends. Fix 1 with the
real-shape test; 3–5 are small test additions worth doing in the same pass. All gates are green and the bundle is
fresh. After the fix, re-review only `types/workbench.ts`, `StoryCard.tsx` and `verification.test.tsx` (plus any of
3–8 taken).

---

# Re-review 51-11 — same base 83fa255, fixed working tree (genesis-review, 2026-11-04)

Scope: the same uncommitted web-only tree after the developer's fixes for findings 1–6, 8 and nits 9–13. `web/static/`
is rebuilt and will be committed separately after this verdict (not flagged). Findings 7 and 14 were left unchanged on
purpose (see below).

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `npx tsc --noEmit` | clean (exit 0) |
| `npm run lint` | 0 errors, 20 warnings (the same pre-existing `react-refresh/only-export-components`) |
| `npx vitest run` | **61 files / 646 tests passed** (22.4 s), matching the developer's count |
| stale bundle: `npx vite build --outDir /tmp/51-11-static-rr --emptyOutDir` then `diff -rq /tmp/51-11-static-rr web/static` | **identical** |

## The fixes, checked

1. **Queued state (was major).** `types/workbench.ts` `isVerificationQueued` = lane `verification` + a
   `verification_story_stage_id` + no `verification_run_id` + `verification_status` `draft`/`in-progress`;
   `isVerifying` includes it; `StoryCard` shows "Queued" and renders the View run link only with a run id; the card's
   `locked` adds `isVerifying`. The derivation matches the backend for a really queued verification:
   `StoryVerificationService.start` creates the stage `draft` (`kb/story_stages.py:109`) or resets it to `in-progress`
   with `run_id=NULL` (`story_stages.py:209-212`), and `_launch`'s `prepare` binds the run
   (`testexec/verification_service.py:236-237`). Test "a queued card (stage bound, no run yet) shows Queued with no View
   run link and is locked" (`verification.test.tsx:193-203`) uses that shape; "a running card is locked too" covers
   the running card. **Fixed as specified, but the lock introduces a new major (R1 below).**
2. Queued title — present (`StoryCard.tsx`), and the failed-launch gap is deferred to the backlog. See R1: the same
   title is shown, wrongly, for a launch that failed.
3. `contract.test.ts:287-288` asserts `typeof …steps === "number"`; a revert of `PlanScenario.steps` to an array
   fails there. **Fixed.**
4. jest-axe: 43 `axe(`/`toHaveNoViolations` lines across `features/testing/*.test.tsx` + `testDesign.test.tsx`,
   now including NewItemDialog, RecordingBar, AddReferenceDialog + ScenarioPicker, NewScenarioDialog, the item page's
   breaking/Save-as-new state and confirms, the scenario retire confirm and the Test Impact regression group.
   The two `NO_PAGE_LANDMARK` runs (`regression.test.tsx:71`, used at `:168` and `:184`) disable only axe's `region`
   rule, for a `document.body` scan of a fragment render whose Radix popper menu portals outside any landmark; the
   page shell supplies the landmarks in the app and every other rule still runs. **Accepted** (scoped to two calls,
   commented). **Fixed.**
5. `testingTab.test.tsx` added (3 `it` blocks, table-driven to 7 tests per the vitest count: 636 → 646 overall).
   **Fixed.**
6. `qk.workbench.verificationGate` (`lib/query/keys.ts`) is used for the query and its invalidation
   (`VerificationSection.tsx:50,63`); no inline key left (grep `verification-gate` outside `keys.ts`: none). **Fixed.**
7. Iframe `allow-same-origin`: unchanged, recorded for 51-12 to test without it. **Accepted** as a deferral (the
   report is Genesis-generated; local single-user).
8. "Run impacted tests" uses `useTestingMutation(…, { toastError: false })` and renders `detailOf` + `problemsOf` in a
   `role="alert"` block (`TestImpactTab.tsx`); test "a 409 on Run impacted tests shows its detail and problems in
   place" (`phase49.test.tsx:282`). **Fixed.**
9. One `/testing/summary` handler in `applications.test.tsx` (grep count 1). **Fixed.**
10. `CasesTable.tsx:84-86` comment now says 816 + 256 = 1072. **Fixed.**
11. `CapturesPanel.tsx:7` one `@/shared/ui` import. **Fixed.**
12. `PassRateChart.tsx:1-2` comment now states Recharts is already in the main bundle. **Fixed.**
13. `ExecutionsView.tsx:45` sorts a null `started_at` as +∞, so queued rows come first under "started desc";
    `executions.test.tsx` updated. **Fixed** (see R3).
14. Role cannot be cleared: unchanged, recorded as a known limit (`ItemSave` has no null role). **Accepted.**

## New findings

### Majors

R1. **A verification that never launched now leaves its card locked in Verification, showing "Queued", with no way
    out.** The board read cannot tell "queued" from "never launched": both have the stage, no `run_id`, and status
    `draft`/`in-progress`. A queued verification that cannot launch ends `error` in `ExecutionService.pump` → `_fail`
    (`testexec/execution_service.py:212-238`: readiness at launch, missing workspace, no commit, an export error); a
    queued one cancelled from Executions ends `cancelled` (`execution_service.py:195-200`); a server restart can lose
    it. None of these paths touches the stage (`_fail` and `cancel` write only the execution), and the backend's own
    read names the case (`verification_service.py` `view`: "never launched (a launch failure, cancelled while queued,
    lost across a restart)"). Before this fix such a card showed nothing but could still be dragged. Now
    `isVerificationQueued` is true for good, so the card shows a spinner with "Queued" and the title "Waiting in the
    test queue", and `useSortable({ disabled: locked })` (`StoryCard.tsx`) removes the drag handle. Dragging is the
    only way to move a card (`BoardPage.tsx` `reorder.mutate`), the story page's Verification section offers no
    re-run or move (`VerificationSection.tsx`), and a new verification starts only from Deployment
    (`BoardPage.tsx:160`). The user cannot recover the card without editing the database. No test covers the
    failed-launch shape.
    *Reviewer's note:* the first-pass fix text asked for exactly this lock and treated the failed-launch display only
    as minor 2. That recommendation was incomplete; the developer implemented it as written.
    **Fix (pick one):**
    (a) Backend, the correct fix: make the board read say whether the story has an active verification (for example
    annotate cards in `api/workbench.py` with `verification_active: "queued" | "running" | null` from
    `StoryVerificationService.active`, or have `_fail` / queued-cancel move the stage to `failed` for a verification
    execution). Derive "Queued" and the lock from that. This leaves the web-only scope of 51-11, so it needs your
    decision (a 51-10 contract addition plus fixture).
    (b) Web-only, the minimum: do not lock on the derived state (keep the lock for `pending`/`running`/
    `awaiting_input*`), and word the derived state so it is true in both cases (for example "Not started — open the
    story", without the queue title). Record the queued-vs-failed gap in the backlog with the launch-problems gap.
    Either way, add a test with the never-launched shape (stage `draft`, no run id) that asserts the card can still
    be dragged (b) or shows the failure (a).

### Nits

R3. Under "started desc" a never-started execution that ended `error` or `cancelled` also has a null `started_at`, so
    it sorts above every real run, alongside the queued ones. Sort only `queued` rows to the top (or fall back to
    `created_at` for the others).

## Verdict: NEEDS_CHANGES

All gates are green, the bundle equals a fresh build, and findings 1–6, 8–13 are fixed as asked; 7 and 14 are
accepted deferrals. One new major (R1): the queued-state lock, applied as the first pass recommended, permanently locks
any card whose verification never launched (launch failure, cancelled while queued, lost across a restart), with no UI
path to move it. Choose fix (a) (backend contract addition, needs the user's approval) or (b) (web-only: no lock on the
derived state, neutral wording, backlog line), add the never-launched test, and re-review only `types/workbench.ts`,
`StoryCard.tsx`, `verification.test.tsx` (plus the backend files if (a)).

---

# Second re-review 51-11 — same base 83fa255, R1 + R3 fixes (genesis-review, 2026-11-04)

Scope: only `web/src/types/workbench.ts`, `web/src/features/workbench/StoryCard.tsx`,
`web/src/features/workbench/verification.test.tsx`, `web/src/features/testing/ExecutionsView.tsx`,
`web/src/features/testing/executions.test.tsx`, plus a fresh build against `web/static/` (rebuilt, to be committed
separately after this verdict). The developer took fix (b), web-only, in line with the user's 51-11 instruction to
change a backend shape only when a fixture is wrong.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `npx tsc --noEmit` | clean (exit 0) |
| `npm run lint` | 0 errors, 20 warnings (the same pre-existing ones) |
| `npx vitest run` | **61 files / 647 tests passed** (24.4 s), matching the developer's count (646 + 1 net) |
| stale bundle: `npx vite build --outDir /tmp/51-11-static-rr2 --emptyOutDir` then `diff -rq /tmp/51-11-static-rr2 web/static` | **identical** |

## The fixes, checked

R1 (was major). **Fixed.**
- `types/workbench.ts`: `isVerificationNotStarted` keeps the same derivation (lane `verification` + a
  `verification_story_stage_id` + no `verification_run_id` + stage `draft`/`in-progress`), and its docstring states
  that it covers both queued and never-launched and does not lock. `isVerifying` is now only run status `pending`,
  `running` or `awaiting_input*`; it no longer includes the derived state.
- `StoryCard.tsx`: `locked = isDesignRunning || isImplementationRunning || isVerifying`, so a card with no run keeps
  its drag handle. The not-started state renders a plain `text-fg-muted` "Not started" (no `Loader2`) with the title
  "Queued behind another execution, or its launch failed — open the story to see the execution", which is true in
  both cases. The View run link renders only when `verification_run_id` is set, and `isVerificationNotStarted`
  requires it unset, so no link appears.
- `verification.test.tsx:193-207`: `it.each` over stage `draft` and `in-progress` with the real shape (stage id 1,
  `verification_run_id: null`, `verification_run_status: null`) asserts "Not started", the exact title, no View run
  link, and the "Drag Score" button present. Reverting the lock (adding the derived state back to `isVerifying` or
  `locked`) fails the drag assertion. "a running card is locked too" (`:209-214`) still asserts the handle is gone
  for a running card.

R3 (was nit). **Fixed.** `ExecutionsView.tsx:45-48`: with no `started_at`, only `status === "queued"` maps to +∞; any
other status uses `Date.parse(created_at)` (`created_at` is a required string on the list item type).
`executions.test.tsx:85` adds an `error` row with no `started_at` and `created_at` 2026-10-01; started desc expects
`["TE-000002", "TE-000001", "TE-000003"]`. The previous code would have put TE-000003 next to the queued row, so the
test catches a regression. The key-sort assertions were extended to the three rows.

## Remaining note

- Nit: the queued-vs-never-launched gap (the board read has no `active` signal) is not yet written anywhere outside
  this review (grep of `specs/` outside `reviews/` for it: no match). Record it in the 51-11 As built and in the
  backlog with the launch-problems gap, as the developer intends. Not blocking.

## Verdict: SHIP

All gates are green and the bundle equals a fresh build. R1 is fixed by option (b): the derived state no longer locks
the card, its wording holds for both queued and failed launches, and a regression test proves the card stays movable.
R3 is fixed and tested. Commit the source changes together with the rebuilt `web/static/`, then confirm an empty
`git status` in a separate call (L-089).
