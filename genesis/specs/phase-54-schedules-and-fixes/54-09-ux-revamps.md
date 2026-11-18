# 54-09 — UX revamps: story Design and Implementation, feature Overview and Activity

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis (`web/src/features/workbench/`, `web/src/features/features/`,
> `web/src/shared/`, `genesis/api/features.py`). Parent: `specs/phase-54-schedules-and-fixes.md`. Built by
> **genesis-dev** after 54-03's approval; **the approved mockup is the layout** (`web/src/dev/mockups/phase54/story.tsx`
> and `feature.tsx` at genesis `b09b08e`; D27, D28). Current state: `54-01-findings.md` §4. Decisions: D17, D18, D27,
> D28.

## 1. Shared pieces

`SectionCard`, `DefinitionList`, `StatusHeader` and `Timeline` already exist in `web/src/shared/ui/` (built in 54-03,
exported from `shared/ui/index.ts`). Replace the page-local duplicates with them: `InfoCard` and `Row` in
`StoryWorkspacePage.tsx`, `Shell` in `StoryTraceCards.tsx:29`, the heading markup in `VerificationSection.tsx`. For
the Implementation counts and Verification totals, promote the mockup's compact `StatGrid` (local to
`web/src/dev/mockups/phase54/story.tsx`) to `shared/ui`, or give `MetricCard` a compact size; do not add a third grid
(54-03 decision 3). Tokens only (ADR-027, ADR-055), and no opacity modifiers on token colours (`bg-primary/10` and the
like generate no CSS, 54-03 As built); no `Button asChild` (L-069): link-styled actions use a link with button classes.

## 2. Story page (`StoryWorkspacePage.tsx`, ADR-071: still the one canonical page)

- **Overview** keeps its content; it adopts the shared pieces and a StatusHeader (lane, design and implementation
  stage status) so all tabs share one header. Type and epic shown once (sidebar).
- **Design:** as approved (54-03 §2 item 7). The design frame follows the theme live (no reload) and has a surface that
  matches dark mode; run states, empty state and the re-run action use SectionCard + EmptyState; "Edit / chat" and
  "Re-run design" are real buttons; the stage status (draft, in review, completed) is shown.
- **Implementation:** as approved (item 8): stat tiles and the **Objects changed** table from `report.objects[]`
  (`useImplementationReport`), the report and the rollback document as **tabs inside one card** (D27), run and
  code-review state in the header.
  Size the table's columns from a real-browser probe (L-090).
- **Verification:** its own tab (item 9), shown when a verification exists; `defaultStoryTab` (`story-view.ts:21`)
  opens it for the verification lane.
- No API change for the story page: everything comes from `GET …/stories/:id/workspace` and the existing report call.

## 3. Feature page (`FeaturePage.tsx`)

- Shared `Tabs` instead of the hand-rolled tablist (`:94-106`).
- **Overview** as approved (item 10). **Needs attention** aggregates across stages from data the page already loads
  (`useFeature`: stages, spec, CR state) plus story and test counts; if a count needs a new field, add it to
  `GET /features/{id}` (54-06 contract table, additive). Remove the stale texts ("arriving in later phases",
  "status derived from stages", "no stage gates another"); show a stage's prerequisite as text (ADR-058, L-063).
- **Activity** (D18) as approved (item 11), over the extended endpoint below.

## 4. Feature activity endpoint (`genesis/api/features.py:667`)

`GET /features/{id}/activity?stage=&limit=50&offset=` returns `{items: ActivityItem[], total}` newest first (54-06
shape), merged from:
1. lifecycle transitions of **every** stage of the feature (`audit.list_for("stage", <stage id>)` for each row of
   `kb_feature_stages`), with today's CR labelling kept (`:675-690`);
2. stage runs: each stage's bound run(s) (`kb_feature_stages.run_id`, m0015, plus any run history the stage keeps) as
   `run` items with status and link to `/runs/<id>`;
3. change requests opened, applied, discarded (from the CR store);
4. story finalization (from the stories store / its audit).
Labels are human text built by program code (no raw state names in the web). List every source and writer of these
events before building (L-094); a source with no timestamp is left out and recorded in As built. A list method returns
the same derived fields as any single-item read (L-039).

## 5. Tests

Web tests for each tab with fixtures in the real shapes (L-083); jest-axe for every changed view (L-014); backend tests
for the activity merge (ordering, paging, stage filter, CR labels unchanged).

## 6. Gates

genesis pytest + ruff; web lint, typecheck, test; build + commit `web/static/` separately (L-089).

## As built

_(genesis-dev fills in: commits, screenshots at 1280/1440/1920 light and dark, tests, review verdict,
decisions/deviations, lesson candidates, code-map changes, Resume note.)_

## Context manifest

```toml
areas    = ["stories-workbench", "features-stages", "web-shell", "api"]
adrs     = ["ADR-027", "ADR-050", "ADR-055", "ADR-056", "ADR-058", "ADR-068", "ADR-071", "ADR-076", "ADR-084"]
lessons  = ["L-014", "L-039", "L-063", "L-069", "L-073", "L-083", "L-089", "L-090", "L-094"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-43-unified-story-workspace.md"]
code     = ["genesis/web/src/features/workbench/**", "genesis/web/src/features/features/**", "genesis/web/src/shared/**", "genesis/genesis/api/features.py"]
upstream = ["54-03", "54-06"]
```
