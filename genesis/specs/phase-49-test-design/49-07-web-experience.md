# 49-07 — Web experience

> **Status:** SPEC-DRAFTED 2026-10-26. Repo: **genesis** (`web/`). Parent: `specs/phase-49-test-design.md`.
> Decisions: 49-01 D1–D3, D8–D11, D13, D15, D16; F2, F7, F8. Consumes 49-06 exactly (types mirror its DTOs, L-011).

## 1. Goal

The seven screens of D13, built only from existing primitives, layouts and tokens (ADR-027/055), accessible
(jest-axe), consistent with the Breakdown stage, the Stories tab, the canonical story page and the Object Wiki.

## 2. Plumbing

- Types `web/src/types/testdesign.ts` mirroring 49-06 (`SuiteTree`, `CaseDto`, `ScenarioDto`, `TopupDto`,
  `ImpactResult`, …) + golden fixtures in real shapes (`TC-000001`, `GNS_000123`, Gherkin arrays; L-083).
- `web/src/lib/api/testdesign.ts` (the client prepends `/api` centrally — ADR-028); hooks + query keys in
  `web/src/features/test-design/hooks.ts` (TanStack Query; invalidate the suite tree, case, scenario, story and
  object queries on every mutation).
- `ArtifactKind` += `"test_design"` (`web/src/types/features.ts:202`).
- Routes (`web/src/app/router.tsx`): `applications/:appUuid/features/:featureId/tests` (FeaturePage, Tests tab —
  static segment, so it wins over `…/:stage`), `applications/:appUuid/test-cases/:caseId`,
  `applications/:appUuid/test-scenarios/:scenarioId`. App tab id `test-impact` (`?tab=test-impact`).
- Never `<Button asChild>` (L-069). New feature folder `web/src/features/test-design/`.

Added after the 49-06 build (49-06 As built — the API as shipped in genesis `73b3bd3`):
- **Contract fixtures:** type against the nine fixtures in `web/src/test/fixtures/testdesign/`; the API tests already
  compare live responses to them, so web types that mirror them can't drift silently (L-011).
- **Allowed actions:** case and scenario reads and both transition responses return the allowed lifecycle actions.
  Render the header's action buttons from that list; don't compute them in the web.
- **Refusals:** a refused transition is 409 with the stage-actions body and a reason naming the blocking scenarios — show
  that reason as-is. A stale write is 409 `{error: "stale_write", expected, actual}` → "changed elsewhere — reload".
  A refused upload is **400**.
- **Lists:** story and object test-case lists include retired cases, last; show them muted with their status.
- **Scenario steps** carry `case_title` and `case_status`, so the steps list needs no extra case fetch.
- **Impact** responses include `hop` on suites and `object_removed` on cases and path entries (49-05 As built).

## 3. Screen 1 — the Test Design stage

- `STAGE_DEFS` row (`web/src/features/features/stages.ts:47`): `{key: "test-design", name: "Test Design", icon:
  FlaskConical (lucide), artifactKind: "test_design", available: true, requires: ["breakdown"], gate: storiesFinalized,
  blurb: "Test suite: scenarios and reusable test cases traced to stories and objects."}`. Add an optional
  `gate?: (detail) => string | null` to `StageDescriptor`, evaluated by `deriveAvailability` after `requires` (F2:
  "Stories must be finalized"); no `if key ===` in callers.
- `STAGE_REGISTRY["test-design"] = {Workspace: StageBuilderPage, CardActions: TestDesignCardActions}`
  (`stage-registry.tsx:32`). Card actions: Locked (with the reason) · Start · View · Re-run (hidden after Finalize) ·
  Export CSV (after Finalize) — model on `BreakdownCardActions.tsx`.
- `StageBuilderPage` empty state for `test-design`: the notes + ≤ 3 files dropzone reused from Breakdown (F1).
- Workspace = the shared `StageArtifactWorkspace` (preview + completion chat + milestones). Header adds:
  - **Finalize tests** when the stage is `completed` and the suite isn't finalized — confirm dialog modelled on
    Finalize Stories: "Creates TC-/TS- records… one-time… the document stays as history". Success → toast with
    counts + any dropped story keys/steps, navigate to the Tests tab.
  - After Finalize: a banner "Finalized on <date> — records live in the Tests tab" and **Generate tests for uncovered
    stories** (screen 2 item 4 dialog).

## 4. Screen 2 — Feature → Tests tab

Tab beside Stories in `FeaturePage.tsx` (visible once the suite is finalized; before that it shows a pointer to the
stage).

1. **Summary bar:** cases (ready/draft/retired), scenarios, stories covered / uncovered, cases needing review, Export
   CSV.
2. **Two views (segmented control):** *Scenarios* — each scenario a collapsible row (`TS-` key · title · status · N
   steps) expanding to its ordered steps (position · `TC-` key · title · type · priority); *Cases* — a table (Key ·
   Title · Type · Priority · Status · Stories · Scenarios · Review) with search + filters (type, priority, status,
   needs review, story) and sortable headers (`aria-sort`). Rows open the case page; scenario rows open the scenario
   page. Add case / Add scenario buttons (create Draft).
3. **Coverage panel:** stories list with state chips covered · uncovered · task (D14) · needs review; each story links to
   its canonical page (ADR-071).
4. **Top-up dialog (D11, R4):** story picker (uncovered pre-checked; stories with Needs-review cases listed unchecked),
   optional notes → start. While running: an inline progress row linking the run. When `ready`: a **proposals review**
   list (new case / new scenario / add step; each with Accept / Reject; dependants auto-rejected with the reason shown)
   → Apply / Discard.

## 5. Screen 3 — Test case page (`TC-`)

Header: key, title, status badge, type, priority, automation status, lifecycle actions from the allowed set (Approve ·
Retire · Restore; refused retire shows the blocking scenarios), Edit, Delete (Draft + unreferenced only), **Mark
reviewed** when any flag is on (F7). Sections: **Given / When / Then** (rendered lines; Edit = textarea per block, one
line per row); **Stories** (chips to the canonical story page with *Needs review*; edit = multi-select of the feature's
stories); **Objects** (table Name · Type · State · Origin; states resolved · unresolved · suspect "changed since linked"
· removed; names link to the Object Wiki page when one exists; Add object = KB object search + free name/type for a
planned object; Remove); **Used in scenarios** (links). Breadcrumb: Application › Feature › Tests › `TC-…`. Edits send
`row_version`; a 409 shows "changed elsewhere — reload".

## 6. Screen 4 — Test scenario page (`TS-`)

Header like the case page. **Steps**: ordered list with drag-to-reorder (the existing dnd primitives used by the
Workbench board) **and** keyboard Move up / Move down buttons; Add step (picker over the suite's non-retired cases);
Remove step. **Objects** (derived, read-only: union of its cases' links with the contributing case keys).

## 7. Screens 5 and 6 — sections on existing pages

- Canonical story page (`StoryWorkspacePage.tsx`): a **Tests** section — the story's cases (key · title · status ·
  Needs review) or "No test cases yet" with a link to the feature's Tests tab.
- Object Wiki page (`web/src/features/object-wiki/ObjectWikiPage.tsx`): a **Tests** section listing the cases linked to
  the object (`GET …/objects/{uuid}/test-cases`) + a link "Check test impact" that opens screen 7 with this object
  pre-picked.

## 8. Screen 7 — Application → Test Impact tab

Tab in `ApplicationDetail.tsx` (`?tab=test-impact`). Controls: **Source** segmented control — *Objects* (KB object
search, multi-select chips), *Story* (story picker over the app's finalized stories), *KB sync* (picker from
`…/test-impact/syncs` showing added/modified/removed counts); **Depth** select 1–5 (default 2); **Analyze**. Result:
totals strip (suites · scenarios · cases · direct · indirect); the changed objects list (with change kind); a grouped
table **Feature › Scenario › Case** (Key · Title · Priority · Hop "Direct" / "Indirect · N hops" · Via) — "Via" opens a
popover with the path (changed object → … → linked object); cases with *object removed* get that label (R1). Empty
states for "no tests linked to these objects" and "no test suites in this application yet". Not stored (D9).

## 9. Tests

Vitest + RTL + jest-axe for every screen; `deriveAvailability` with the new `gate` (locked until finalized); stage
card actions per state; Finalize confirm flow; top-up proposals with dependency auto-reject; case edit CAS 409 path;
scenario reorder by keyboard; impact tab per source incl. empty states; fixtures from the 49-06 contract fixtures (L-011).
Gates: `npm run lint && npm run typecheck && npm test`, `npm run build`, commit `web/static/` in a separate sequential
step (L-089).

## Context manifest

```toml
areas    = ["web-shell", "features-stages"]
adrs     = ["ADR-027", "ADR-028", "ADR-043", "ADR-049", "ADR-055", "ADR-056", "ADR-058", "ADR-071"]
lessons  = ["L-011", "L-014", "L-069", "L-083", "L-089", "L-090"]
code     = ["genesis/web/src/features/test-design/**", "genesis/web/src/features/features/**", "genesis/web/src/features/object-wiki/**",
            "genesis/web/src/features/workbench/StoryWorkspacePage.tsx", "genesis/web/src/features/applications/ApplicationDetail.tsx",
            "genesis/web/src/app/router.tsx", "genesis/web/src/types/**", "genesis/web/src/lib/api/**"]
docs     = ["tracker:specs/phase-49-test-design/49-06-api.md"]
upstream = ["49-06"]
```

## As built (genesis-dev, 2026-10-30)

**Commits** (genesis, base `d62ae03`; local only, nothing pushed or tagged; no other code repo changed):
- `8a7ca96` feat(web): the seven screens, types, client, hooks, tests, rebuilt `web/static`.
- `5d69eb7` fix(web): review round 1 m1–m3, n4.
- `66d7dce` fix(web): review round 2 nits n8, n10 (source only — see Decisions 9).
- `45be579` build(web): the `web/static` for `66d7dce`.

**Changed** (all under `genesis/web/src`)
- New `types/testdesign.ts`: every 49-06 DTO (`SuiteTree`, `CaseDto`, `ScenarioDto`, `CaseDetail`, `ScenarioDetail`,
  `TopupDto` with the three `ProposalItem` kinds, `FinalizeTestsResult`, `TopupApplyResult`, `ImpactResult`,
  `ImpactSync`, request bodies). `types/features.ts`: `ArtifactKind` += `"test_design"`.
- New `lib/api/testdesign.ts` (`testDesignApi`, relative paths; only `exportCsvUrlFor` is absolute, for `<a download>`,
  as `featuresApi.exportCsvUrlFor`). `lib/query/keys.ts`: `qk.testDesign.*`; every mutation invalidates
  `qk.testDesign.all` (+ the feature detail where the stage row can change).
- New `features/test-design/`: `hooks.ts`, `logic.ts` (labels/tones, `serverMessage`/`isStaleWrite`, Gherkin
  lines, Cases filters/sort, `suiteSummary`, `previewDecisions` = a mirror of `expand_topup_decisions`,
  `groupImpact`, `hopLabel`, `moveItem`, `finalizeSummary`), `paths.ts`, `badges.tsx`, `format.ts`,
  `NotesAndFiles.tsx`, `StageControls.tsx` (Re-run, Finalize tests, finalized banner, Generate tests),
  `TestDesignCardActions.tsx`, `TestDesignEntry.tsx`, `TopupDialog.tsx`, `TopupPanel.tsx`, `TestsTab.tsx`,
  `CasesTable.tsx`, `LifecycleActions.tsx`, `ObjectPicker.tsx`, `TestCasePage.tsx`, `TestScenarioPage.tsx`,
  `TestsSections.tsx`, `TestImpactTab.tsx`.
- New `shared/ui/popover.tsx` (over the already-installed `@radix-ui/react-popover`; the impact "Via" path).
  `shared/ui/icons.ts` += `ArrowDown`.
- `features/features/stages.ts`: `StageKey` += `"test-design"`; optional `StageDescriptor.gate(detail) → reason | null`
  evaluated by `deriveAvailability` after `requires`, which now also returns `reason`; `storiesFinalized` gate; the
  Test Design `STAGE_DEFS` row (`requires: ["breakdown"]`, FlaskConical). `stage-registry.tsx`: the `test-design`
  entry. `StageBuilderPage.tsx`: the test-design entry state, header Finalize tests / Re-run (hidden after Finalize),
  the finalized banner. `FeaturePage.tsx`: Tests tab (+ `/tests` route opens it), stage grid
  `sm:2 · lg:3 · xl:5` columns, `test_design` artifact label.
- `app/router.tsx`: `…/features/:featureId/tests`, `…/test-cases/:caseId`, `…/test-scenarios/:scenarioId`.
  `shared/layout/breadcrumbs.ts`: the case/scenario trail (Home › Application › Feature › Tests) from the
  `tc-feature:<id>` / `ts-feature:<id>` labels the pages register; a "Tests" crumb.
- `applications/ApplicationDetail.tsx`: `?tab=test-impact`. `workbench/StoryWorkspacePage.tsx` (Overview) and
  `object-wiki/ObjectWikiPage.tsx`: the Tests sections.

**Tests:** new `test-design/contract.test.ts` (9: the nine fixtures ↔ `Exact<T>` key maps, value domains, real key
shapes), `logic.test.ts` (18), `testDesign.test.tsx` (31, jest-axe on every screen); `stages.test.ts` (+4 gate tests,
roll-up includes Test Design), `breadcrumbs.test.tsx` (+3), `features.test.tsx` (3 Locked stages),
`objectWiki.test.tsx` and `StoryWorkspacePage.test.tsx` (handlers/mocks for the new reads). Web: **49 files / 445
tests** (was 46 / 380); `npm run lint` 0 errors (20 pre-existing warnings); `npm run typecheck` clean. Backend
untouched: `pytest -q` 1355 passed. After the last commit a fresh `npm run build` left `git status
--short --untracked-files=all` empty.

**Review:** genesis-review, `reviews/49-07-review.md`. Round 1 (8a7ca96): **SHIP**, m1–m4 + n1–n7. Round 2 (delta
5d69eb7): **SHIP**, m1–m3 + n4 resolved, nits n8–n10. n8 and n10 were fixed after round 2 (`66d7dce`, not
re-reviewed).

**Decisions / deviations** (no ADR deviation):
1. Lifecycle buttons render only from the server's `allowed`. A refusal shows `detail.reason` as-is in a
   `role="alert"` notice; an illegal action lists `detail.allowed`; a CAS 409 `stale_write` reads "This record changed
   elsewhere — reload and try again." with Reload; a refused upload (400) toasts the server text.
2. The top-up review previews dependency auto-rejects with `previewDecisions`; the server stays authoritative and its
   `rejected` list is in the apply toast. Every proposal defaults to Accept.
3. No app-wide stories endpoint exists, so the impact Story source is a two-step picker: a feature with finalized
   stories, then one of its stories. "No test suites in this application yet" reads each finalized-stories feature's
   suite (one request per feature, cached; review n2).
4. The top-up picker lists every Story-type story (Tasks excluded — the server 422s them); uncovered pre-checked,
   needs-review ones unchecked with a count.
5. A case object's name links to the Object Wiki page only when the app's wiki list holds that object.
6. **Two review flags (review m1, 49-01 R2):** "Needs review" (story changed, the server's `needs_review`) and
   "Object changed" (a suspect link) are separate badges and filters; the "Needs review" filter equals the summary's
   `coverage.needs_review`. Mark reviewed shows for either (F7 clears both).
7. **Tasks-only feature (review m2, L-063):** the descriptor gate stays pure on `FeatureDetail`
   (`stories_finalized_at`); the entry page reads the stories and shows "The feature has no Story-type stories"
   instead of Start. **Remaining difference:** the Overview card still offers Start for a Tasks-only feature; it opens
   the locked entry page. Start also stays offered while the stories read is loading or failed (the server's 409 toast
   then explains, review n9).
8. The breadcrumb ends at "Tests"; the current page (`TC-…`) is dropped as on every other route (review n5).
9. **L-089 recurrence:** the build for `66d7dce` had not finished writing when the commit ran (the build log's mtime is
   20 s after the commit), so `66d7dce` holds source only. The post-commit fresh rebuild caught it; `45be579` commits
   the matching bundle and a second rebuild left `git status` empty.
10. Accepted as-is: the Breakdown entry keeps its inline notes+files copy (n1, fold it into `NotesAndFiles` when next
    touched); the roll-up of a pre-Phase-49 feature with four completed stages is now "Draft" (n6, a product call).

**Hand-offs**
- **genesis-spec → 49-08 (review m4):** add to the L-090 real-browser width probe the 5-card stage grid
  (`FeaturePage.tsx`, `xl:grid-cols-5`) and the case page's Objects table (`TestCasePage.tsx`, `min-w-[520px]` in a
  2/3 column), beside the Cases and Test Impact tables (1280/1440/1920 and 768, both themes).
- **49-08 live checks:** a scenario with a retired-case step cannot be reordered until that step is removed (the server
  422s a retired case in `set_steps`, review n3); the Tasks-only card → locked entry path; both review badges in a real
  table; drag-to-reorder by pointer; the CSV download; the top-up run → proposals → apply loop.
- **genesis-docs:** ADR-056's "stage MAY declare prerequisites" now has a second form, the descriptor `gate`.

**Lesson candidates**
- Even one-call-per-step sequencing did not guarantee the build finished before the commit (Decisions 9). The
  post-commit rebuild + empty `git status` check (L-089) is what caught it; keep it mandatory, after every bundle
  commit.
- A web "needs review" helper that ORs two server flags made the table disagree with the server's count. Mirror each
  server flag one-to-one and combine them only where the server's own action (Mark reviewed) combines them.

**Code-map changes:** `web/src/features/test-design/` (the Test Design screens, hooks, pure logic); `web/src/types/
testdesign.ts`; `web/src/lib/api/testdesign.ts`; `web/src/shared/ui/popover.tsx`; `StageDescriptor.gate` in
`features/features/stages.ts`; routes `…/features/:id/tests`, `…/test-cases/:caseId`, `…/test-scenarios/:scenarioId`;
app tab `test-impact`.
