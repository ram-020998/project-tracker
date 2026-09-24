# Phase 43 — The Unified Story Workspace — as-built

> ✅ **SHIPPED 2026-09-24 — genesis v0.74.0, CI green. PHASE 43 COMPLETE.** genesis-only (web + a thin,
> board-independent read endpoint); **no migration** (DB stays v21). **ADR-071 Accepted.**
> Release: master `d939fa71`, tag `v0.74.0`. Specs: `specs/phase-43-unified-story-workspace.md` +
> `phase-43-unified-story-workspace/43-01..43-05`.

## What shipped

One **canonical, consolidated Story Workspace** — `/applications/:appUuid/stories/:storyId` — reached from
**every** entry point (the feature Stories tab, every board lane, legacy-route redirects), replacing the three
disjoint surfaces (`StoryDetailPage`, the board `BoardCardDrawer`, the lane-routed `StoryCardPage` →
`StoryDesignWorkspace` | `ImplementationReviewWorkspace`).

- **Tabs**, rendered only when the stage exists, landing on the **stage-relevant** tab (`defaultStoryTab`):
  - **Overview** (always) — description / acceptance criteria / **dev note** (in the main column, wraps) /
    open questions + a Details sidebar; **inline Edit** (reuses `StoryForm`, `row_version` CAS).
  - **Design** — the design document **read-only** (themed iframe, `annotate=0`); an **"Edit / chat"** action
    opens the existing design chat **in a new browser tab**, gated to **Design/Design-Review** (read-only
    afterward). Running/failed panels from the durable run status.
  - **Implementation** — a **master-detail document viewer** (left rail of documents + the selected one on
    the right, via `SplitPane`, mirroring the run Documents tab): **Implementation report** + **Rollback
    document**. (The objects-modified table is NOT a separate doc — the report already renders it.)
- **One documents-viewer chrome** (`StoryDocument`) — a type label + the appropriate renderer (themed iframe /
  sandboxed report iframe / `MarkdownView`).
- **Origin-aware breadcrumb** — `?from=board` → *Workbench / Board*; `?from=feature&feature=<id>` → *Home /
  App / Feature / Stories*. The breadcrumb is the back navigation (no in-page back button).

## Backend (thin, no migration)

- `GET /api/applications/{app_uuid}/stories/{story_id}/workspace` — the consolidated, **board-independent**
  read (`StoryStore.get_by_id` + `StoryStageStore.get_for_story` + run status via `RunStore`): the story +
  feature/app context + design/implementation stage state (status, chat, run, which artifacts exist). Resolves
  a story with no board (Overview-only) — Q9.
- The **implementation-report** read relaxed to **story-scoped**, dropping the Phase-42 **Q16 lane gate**
  (the tab only renders when the artifact exists). The design-artifact read was already story-scoped; added an
  `annotate` flag for the read-only render.
- `StoryStore.get_by_id`; a `designArtifactUrl(annotate)` option. **No migration.**

## Sub-phases (each independently reviewed = SHIP; local commits, released at 43-05)

- **43-01** consolidated read path + Q16 lane-gate drop — `281407a` (+ review MUST-FIX `e07e554`: route run
  status through `RunStore`, not raw API-layer SQL). Backend pytest incl. board-independent + no-lane-gate cases.
- **43-02** `StoryWorkspacePage` shell + Overview + one canonical route + legacy redirects + `BoardCardDrawer`
  removed + `openCardView` collapsed — `fdbc40a`.
- **43-03** `StoryDocument` chrome + Design (read-only + Edit-chat new tab) + Implementation tabs +
  `defaultStoryTab` + a dedicated design-chat route/page — `ff31dd5`.
- **43-04** legacy cleanup (deleted `StoryDetailPage`/`StoryCardPage`/`ImplementationReviewWorkspace` + its
  test) — `4b56eff`.
- **Live-feedback refinement pass** (from testing on the running fleet) — `a317315`: origin-aware breadcrumb;
  Dev note moved to the main column (it overflowed the sidebar); Edit moved into Overview; removed the in-page
  Board/Stories back link, Remove-from-board, and Delete; Implementation tab rebuilt as the master-detail
  viewer. Then `b6ebf4d`: dropped the redundant Objects-modified doc (the report already lists them).
- **43-05** release — bump genesis → **v0.74.0** (pyproject + FastAPI + `web/src/version.ts`; pins unchanged),
  commit `d939fa71`, tag `v0.74.0`, push; CI green; ADR-071 → Accepted; docs; fleet restart.

## Gates at release

genesis pytest **844** + ruff; web tsc + eslint (0 errors) + **vitest 286** + build (stale-bundle guard clean);
fresh DB → **v21** (no migration). Three independent sub-phase audits returned **SHIP**.

## New / changed files

- **New:** `web/src/features/workbench/{StoryWorkspacePage,StoryDocument,StoryDesignChatPage}.tsx` +
  `story-view.ts` (+ tests) ; `web/src/shared/layout/breadcrumbs.test.tsx`.
- **Changed:** `genesis/api/workbench.py` (workspace endpoint + relaxed report), `genesis/kb/stories.py`
  (`get_by_id`), `web/src/{app/router.tsx, shared/layout/breadcrumbs.ts, lib/api/workbench.ts,
  lib/query/keys.ts, types/workbench.ts, features/workbench/{hooks.ts,BoardPage.tsx},
  features/features/StoriesTab.tsx}`.
- **Removed:** `StoryDetailPage.tsx`, `StoryCardPage.tsx`, `ImplementationReviewWorkspace.tsx` (+ its test),
  `BoardCardDrawer.tsx`.

## Notes / follow-ups

- **Live acceptance** was done on the running fleet (both instances restarted on v0.74.0) — the enhancement is
  UI + a read path, so it is browser-verifiable (unlike the headless-undrivable workflow phases).
- A pre-existing gap noted during review (out of scope): the `design/artifact` serve does not validate the
  story belongs to `app_uuid` — a minor cross-app read follow-up.
