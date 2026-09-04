# 34-05 — Web: drag-into-Design confirm, card run states, the Design Review workspace

> **Status:** ✅ SHIPPED (genesis v0.62.0 + genesis-workflows v0.16.0). · Part of Phase 34. Repo: **genesis/web**. · **Depends on:** 34-04 (endpoints + card DTO), ADR-057 (`StageArtifactWorkspace`/`AnnotatablePreviewDialog`/`StageBuilderPage` — reused), ADR-061 (the Workbench board).

## Purpose

The board UX for the Design + Design Review lanes: a confirm dialog on drag-into-Design, running/locked/failed
card states with a run link, and a full-page Design-Review workspace reusing the Spec/TD chat + annotatable
preview.

## Build

1. **Drag-into-Design confirm** (`features/workbench/BoardPage.tsx`) — `onDragEnd` currently persists every
   drop via `useReorderLane`. Special-case a card **entering the `design` lane** (from any other lane): don't
   persist yet — open a **`StartDesignDialog`** ("Start the automated design generation for this ticket? — Yes
   runs the design and moves the card to Design; No just moves it."). **Yes** → `useStartDesign(appUuid)`
   (`POST …/cards/{storyId}/design/start`); **No** → the normal lane persist. A **locked** card (running design)
   is not draggable — filter it out of the sortable ids / set `disabled` on its `useSortable`.
   - Re-running: entering `design` from `design-review` (rework) shows the same dialog; Yes re-runs
     (updates in place). (Q2.)
2. **Card run states** (`StoryCard.tsx`/`StoryCardFace` + `lanes.ts`):
   - **running** (`design_run_status ∈ {pending, running, awaiting_input:*}`) → a small "Design generation
     running" row with a spinner + a `Link to={/runs/${design_run_id}}` ("View run"); card `cursor-not-allowed`,
     no grip.
   - **failed** (`design_run_status ∈ {failed, cancelled}` && lane===design) → a **light-red** card background
     (a `bg-danger/…` token — no hardcoded hex) + "Design workflow failed" + the run link.
   - otherwise unchanged.
3. **Design Review full page** — a new route `/workbench/:appUuid/cards/:storyId` (router + breadcrumbs:
   App-board / ticket). A card in the **Design Review** lane opens it on click (other lanes keep
   `BoardCardDrawer`). Mount a **reused** `StageArtifactWorkspace` (or a thin `StoryDesignWorkspace` wrapper)
   bound to the story's `design` artifact + the `story_design` chat: the reused `ChatThread` + the
   `AnnotatablePreviewDialog` (Lavish) — Preview shows `design.html`, annotations flow to the agent, the agent
   rewrites the artifact (exactly the Spec/TD loop). Reuse the stage hooks with a story-scoped API
   (`GET/artifact` + chat wiring) pointed at `kb_story_stages`.
4. **API + hooks + types** (`lib/api/workbench.ts`, `features/workbench/hooks.ts`, `types/workbench.ts`,
   query keys) — `startDesign(appUuid, storyId)` + `useStartDesign` (invalidate board + boards; toast on
   error/409); the card type gains `design_run_id`/`design_run_status`/`design_chat_session_id`/`design_status`;
   a story-design artifact/chat read for the workspace.
5. **a11y + gates** — jest-axe on the dialog + the Design-Review page; keyboard: the locked card is not a drag
   target; the confirm dialog is focus-trapped. `npm run build` + commit `web/static` (the stale-bundle guard).

## Reuse (no re-rolling)

`StageArtifactWorkspace` / `AnnotatablePreviewDialog` / `ChatThread` (Phase 29 D0 generalization) — the Design
Review page is the same component tree the Spec/UX/TD stages use, only the artifact source (a story-stage) +
chat mode (`story_design`) differ. The confirm dialog uses the shared `Dialog` primitive; the run link uses the
existing runs route.

## Gate

tsc/eslint/vitest/build green; `web/static` committed; independent review = SHIP → proceed to 34-06.
