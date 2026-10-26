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
