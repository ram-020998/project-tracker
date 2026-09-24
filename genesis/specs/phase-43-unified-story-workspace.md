# Phase 43 — The Unified Story Workspace (one consistent, consolidated story view)

> **Status:** 🟡 **DRAFTED — specs only; awaiting build go-ahead.** · **Author:** Genesis agent · Created 2026-09-24.
> Umbrella + `phase-43-unified-story-workspace/43-01..43-05`. **New ADR:** **ADR-071** (the unified Story Workspace) — **amends the story-view surfaces** established by ADR-060 (StoryDetailPage), ADR-061 (the board card drawer), ADR-062 (the Design Review workspace routing) and ADR-068 (the implementation review surface).
> **Type:** genesis-only — **web** (a single Story Workspace page + a documents-viewer chrome; removes the board drawer + the split routes) + a **thin backend** (one consolidated, board-independent read endpoint + relaxing the board/lane scoping on the artifact reads). **No migration.** genesis-core / genesis-workflows / kiro-agent-sdk / genesis-appian-parser **unchanged**.
> **Depends on:** Phase 32 (Finalize Stories — `kb_epics`/`kb_stories`, `StoryStore`, the Stories tab + `StoryDetailPage`; ADR-060), Phase 33 (the Workbench board + `BoardCard` DTO + the drawer; ADR-061), Phase 34 (the Design/Design-Review automation — `kb_story_stages`/`StoryStageStore`, `design.html`, the bound `story_design` chat, `StoryDesignWorkspace`; ADR-062), Phase 42 (the Implementation lane — the `implementation` story-stage, the report/rollback/objects artifacts, `ImplementationReviewWorkspace`, the `implementation/report` endpoint; ADR-068).

---

## 1. Why this phase exists

Opening a story today gives a **different screen depending on where you click and what lane the card is in** — a fragmented, inconsistent experience:

- From the **feature's Stories tab** (or the drawer's "Open full detail") → **`StoryDetailPage`** (`…/features/:featureId/stories/:storyId`): the story's description, acceptance criteria, open questions, and a details sidebar — but **no generated documents at all**.
- From a **To-Do (or any non-routed) board card** → the **`BoardCardDrawer`** right sheet: feature name, description, AC, labels — again **no documents**.
- From a **Design-Review board card** → **`StoryCardPage` → `StoryDesignWorkspace`**: a chat + an annotatable preview of `design.html` — but **none of the story's core details**.
- From an **Implementation / Code-Review board card** → **`StoryCardPage` → `ImplementationReviewWorkspace`**: the objects-modified table + the implementation report + the rollback document — but **no core details, and no design document** (which is still relevant in Code Review).

So a story's information is scattered across three disjoint surfaces, each showing only a slice, and which one you get is decided by lane-based routing (`BoardPage.openCardView`). A user cannot see "everything about this story" in one place, and the look-and-feel changes under them as the card advances.

**This phase makes the story view consistent and consolidated:** clicking a story from *anywhere* opens **one** page that always shows the story's core details **and** progressively surfaces **all documents generated for that story so far** — each clearly identified by type, presented in tabs (not dumped), reusing the existing renderers, and consistent with how documents are shown elsewhere in the app.

---

## 2. Goal

1. **One canonical Story Workspace page**, reached from every entry point (the feature Stories tab, every board lane, the old drawer's "open detail"), at a single route: **`/applications/:appUuid/stories/:storyId`**. The board's To-Do drawer and the lane-based routing split are **removed** — every story click lands here.
2. **A consistent page anatomy:** a persistent header (key · title · type · epic · lane/status) + a **tabbed body**:
   - **Overview** (always) — description, acceptance criteria, open questions, details; **inline Edit/Delete** of the story (reusing `StoryForm`).
   - **Design** (when a design stage exists) — the rendered design document **read-only**, with an **"Edit / chat"** button that opens the existing design chat workspace **in a new browser tab** — enabled only while the story is in **Design / Design Review**; view-only afterward.
   - **Implementation** (when an implementation stage exists) — the **implementation report**, the **objects-modified** table, and the **rollback document**, read-only.
3. **Stage-aware default tab:** the page lands on the most advanced tab that has content (code-review/verification/deployment/done → Implementation; design/design-review → Design; to-do or no docs → Overview). Tabs render **only** when their artifacts exist — a To-Do story shows Overview alone; documents light up as the story progresses through the board.
4. **A single documents-viewer chrome** — one wrapper giving every document tab the same chrome (a **type label** — "Design document" / "Implementation report" / "Objects modified" / "Rollback document" — consistent header/spacing) that dispatches to the **right existing renderer per type** (annotatable/themed HTML for the design, sandboxed iframe for the report, `MarkdownView` for the rollback, the table for objects).
5. **A consolidated, board-independent read path** — one endpoint returning everything the page needs for a story (core fields + design-stage state + implementation-stage state + which documents exist), working **whether or not the story is on a board** (a feature-side story with no board still shows Overview).

**Success = from the Stories tab or any board lane, clicking a story opens the same page; the user sees the story's details plus every document produced for it so far, each labelled by type, on stage-appropriate tabs; the design is chat-editable (in a new tab) while in Design/Design-Review and read-only after; and no information or affordance depends on which door they came through.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-24)

1. **Single canonical story route** (not two). Q1.
2. **Fully consistent — always the same page.** The board To-Do drawer is **removed**; every board card click navigates to the Story Workspace. Q2.
3. **Tabs**, and the page **lands on the stage-relevant tab** by default. Q3.
4. **Editing is done from this page** (the Overview tab; reuse `StoryForm` + the existing update/delete hooks with `row_version` CAS). Q4.
5. **The design "Edit / chat" affordance opens the design chat in a NEW BROWSER TAB** (the existing `StoryDesignWorkspace`, unchanged), not an inline panel. Q5.
6. **The design document is read-only after implementation** (Code Review and later) — chat-edit only in Design / Design Review. Q6.
7. **The document set is: Design document · Implementation report · Objects modified · Rollback document** — sufficient for now. Q7.
8. **Converge on a single documents-viewer chrome** for the story page (tabs + type labels + the appropriate renderer per type). Q8.
9. **The page is reachable for a story not yet on a board** (Overview only); **documents light up once it has been through the board.** Q9.
10. **Scope = a consolidated read path + UI only.** No change to how artifacts are stored; **no migration.** Q10.
11. **genesis-only** (web + a thin API). No genesis-core / genesis-workflows changes. Q11.

(The "few issues to fix" the user mentioned for this iteration are **a later phase** — not in scope here.)

---

## 4. Current state (code-grounded — read before building)

**Routes (`web/src/app/router.tsx`):**
- `applications/:appUuid/features/:featureId/stories/:storyId` → `StoryDetailPage`.
- `workbench/:appUuid/cards/:storyId` → `StoryCardPage`.

**Web surfaces (all under `web/src/features/`):**
- `features/StoryDetailPage.tsx` — two-column read + Edit (`StoryForm`) + Delete; uses `useStory`/`useStories` (feature hooks); **no documents**.
- `features/StoriesTab.tsx` — the grid; row click → `StoryDetailPage`.
- `workbench/BoardPage.tsx` — `openCardView(c)` branches: implementation/code-review → `StoryCardPage`; design-review or `design_chat_session_id` → `StoryCardPage`; else → `BoardCardDrawer`.
- `workbench/BoardCardDrawer.tsx` — right sheet (feature/desc/AC/labels + Remove + "Open full detail" link to `StoryDetailPage`).
- `workbench/StoryCardPage.tsx` — routes a board card to `ImplementationReviewWorkspace` (impl/code-review) or `StoryDesignWorkspace` (has design chat) or running/failed/none panels.
- `workbench/StoryDesignWorkspace.tsx` — reused `ChatThread` (the `story_design` chat) + `AnnotatablePreviewDialog` over `design.html`.
- `workbench/ImplementationReviewWorkspace.tsx` — objects table + report iframe (`sandbox=""`) + rollback `MarkdownView`; from `useImplementationReport`.

**Types / API (`web/src/types/workbench.ts`, `web/src/lib/api/workbench.ts`):** `BoardCard extends Story` carries `design_*` + `implementation_*` run/stage fields; `ImplementationReport` = `{report_html, rollback_md, run_id, run_status, story_stage_id, objects[]}`. `designArtifactUrl(...)` serves the themed/Lavish design HTML; `implementationReport(...)` fetches the report.

**Backend (`genesis/api/workbench.py`):**
- `GET …/cards/{id}/design/artifact` — serves the ticket's `design.html` (Genesis-themed; Lavish injected when `annotate=1`). Reads `StoryStageStore.get_for_story(story_id, "design")` — but the route is under the board path.
- `GET …/cards/{id}/implementation/report` — `report_html` + `rollback_md` + `objects[]` + run info; reads `StoryStageStore.get_for_story(story_id, "implementation")` — but is **board-card-scoped** (`boards.get_card`) and **gated to the implementation/code-review lanes** (Q16 from Phase 42).
- The feature side (`genesis/api/features.py`) exposes the story record via `StoryStore`; it has **no** design/impl surface.

**Key facts for the design:**
- `StoryStageStore.get_for_story(story_id, stage)` is **board-independent** — the consolidated endpoint can read design/impl stages for any story without a board card.
- The design/impl artifacts live on disk under `settings.story_stage_artifacts_dir/<story_stage_id>/` (`design.html`, `implementation-report.html`, `rollback.md`, `implementation.json`) — served by the existing artifact routes.
- Reusable renderers already exist: `AnnotatablePreviewDialog`, `MarkdownView`, the sandboxed report iframe, `ChatThread`; the library `DocumentDetailPage` is the app's other document viewer (uploaded docs) — the convergence target for a consistent doc chrome.

---

## 5. The design (UX + component model)

**Route:** `/applications/:appUuid/stories/:storyId` → a new **`StoryWorkspacePage`**. The two legacy routes redirect here (`…/features/:featureId/stories/:storyId` and `/workbench/:appUuid/cards/:storyId`) so existing links/bookmarks resolve. Breadcrumbs: App / (Feature) / Story.

**Anatomy:**
- **Header** — key + title; badges for type, epic, lane/status; `Edit` + `Delete` actions (Overview edit toggles inline). A "Back to board / Back to stories" affordance derived from where the user came from (or always to the feature's Stories tab).
- **Tabs** (a shared `Tabs` primitive):
  - **Overview** — the current `StoryDetailPage` read layout (description / AC / open questions / details sidebar) + inline Edit (reuse `StoryForm`, `useUpdateStory`, `useDeleteStory`).
  - **Design** — a `StoryDocumentTab` rendering `design.html` **read-only** via the themed artifact (annotatable **off** by default here — it's the read view); an **"Edit / chat"** button (visible only when `lane ∈ {design, design-review}` and a design chat exists) that opens the existing design workspace in a **new browser tab** (`window.open`/`<a target="_blank">` to `/workbench/:appUuid/cards/:storyId` — kept as the dedicated chat route, or a new dedicated design-chat route; see 43-02).
  - **Implementation** — the objects-modified table + the report (sandboxed iframe) + the rollback (`MarkdownView`), read-only — the `ImplementationReviewWorkspace` content, re-homed into the tab.
- **Default tab:** a pure helper `defaultStoryTab(story)` → most-advanced-with-content (implementation if an impl artifact exists / the lane is code-review+; else design if a design artifact exists / the lane is design+; else overview). Unit-tested.
- **Tab visibility:** a tab renders only if its stage/artifact exists (`has_design`, `has_implementation`). To-Do → Overview only.

**The documents-viewer chrome (Q8):** a small `StoryDocument` wrapper = a labelled header (document type + optional actions like "Open in full screen" / "Edit / chat") + a body that dispatches by type: `design` → themed HTML (reuse the annotatable preview in read mode, or a plain themed iframe) ; `report` → sandboxed iframe; `rollback` → `MarkdownView`; `objects` → the table. This gives the three document tabs one consistent chrome and clear type identity, wrapping the existing renderers (not a re-implementation).

**Navigation changes:**
- `BoardPage.openCardView` collapses to `navigate('/applications/:appUuid/stories/:id')` for **every** card (no lane branching); `BoardCardDrawer` is deleted (Remove-from-board moves to the Story Workspace header or stays a board-card affordance — see 43-02).
- `StoriesTab` row click → the same route.
- `StoryCardPage` becomes a thin redirect to the canonical route (or is removed and its route redirects); `StoryDesignWorkspace` stays as the **chat** target opened in the new tab; `ImplementationReviewWorkspace` content is absorbed into the Implementation tab (component reused/relocated).

---

## 6. Data / backend (thin, no migration)

- **New consolidated read endpoint** (board-independent), e.g. `GET /api/applications/{app_uuid}/stories/{story_id}/workspace` (final path decided in 43-01), returning:
  - `story` — the full `kb_stories` record (via `StoryStore`),
  - `context` — `feature_id`/`feature_name`, `app_uuid`, `lane`/`status`, whether it's on a board,
  - `design` — `{status, chat_session_id, run_id, run_status, has_artifact}` (from `StoryStageStore.get_for_story(id,"design")` + the runs table),
  - `implementation` — `{run_id, run_status, has_report, has_rollback, objects[]}` (from the `"implementation"` stage).
  It reads the story-stage rows **directly** (no board-card requirement), so a feature-side story with no board still resolves (Q9).
- **Relax scoping/gating on the artifact reads** so the unified page can render whatever exists: the design-artifact + implementation-report reads become **story-scoped** (not board-card-scoped) and **drop the Q16 lane gate** (the page only renders a tab when the artifact is present, so the gate is redundant). Kept read-only.
- Reuse the existing artifact-serving endpoints for the actual bytes (design HTML, report HTML); the rollback markdown + objects come through the consolidated payload (or a small artifact read).
- **No new migration; genesis-only.** The `BoardCard` DTO already carries the design/impl fields for the board's own card rendering — unchanged.

**Security note:** all reads are local, read-only; the "Edit / chat" affordance reuses the existing (already-gated) design chat. No new write surface, no new auth.

---

## 7. Out of scope (this phase)

- The "few issues to fix" for this iteration (a later phase).
- Any change to how artifacts are generated or stored; any migration.
- Inline chat inside the Design tab (the user chose a new-browser-tab hand-off).
- New document types beyond the four (Design / Implementation report / Objects modified / Rollback).
- genesis-core / genesis-workflows changes.

---

## 8. Sub-phases (each per the bible §8 loop: verify → smallest change → test → gates green)

- **43-01 — Consolidated read path.** The board-independent `…/stories/{id}/workspace` endpoint + relax the design-artifact/implementation-report reads to story-scoped (drop the Q16 lane gate); web api client + types + hooks + a `useStoryWorkspace` query; backend pytest.
- **43-02 — Story Workspace shell + Overview + routing.** `StoryWorkspacePage` (header + `Tabs` + Overview with inline Edit/Delete); the canonical route + redirects from the two legacy routes; repoint `StoriesTab` + `BoardPage.openCardView`; **remove `BoardCardDrawer`** (relocate Remove-from-board); breadcrumbs.
- **43-03 — Documents-viewer chrome + Design & Implementation tabs + default-tab logic.** The `StoryDocument` chrome + type labels; the Design tab (read-only render + "Edit / chat" new-tab button gated to design/design-review) + the Implementation tab (report + objects + rollback, re-homing `ImplementationReviewWorkspace`); `defaultStoryTab` pure helper + tests.
- **43-04 — Review & hardening.** Independent review; jest-axe on the new page; consistency pass (tokens, reused primitives, doc-type labels); tidy/redirect the legacy components; regression tests.
- **43-05 — Release.** genesis vX.Y.0 (frontend + thin backend; committed `web/static`); CI green; ADR-071 → Accepted; bible/tracker/progress updated.

---

## 9. ADR-071 (Proposed) — the unified Story Workspace

A single canonical story page + a consolidated, board-independent read path replace the drawer + the split lane-based routes; a documents-viewer chrome renders the story's stage artifacts (Design / Implementation report / Objects modified / Rollback) by type on stage-aware tabs; the design is chat-editable (in a new browser tab) only in Design/Design-Review, read-only afterward. Amends ADR-060/061/062/068's story-view surfaces (their data/artifacts are unchanged; only the *presentation* is unified). Mirrored in `reference/decision-log.md`; full text into `bible/04` on Accept.

---

## 10. Reuse map (consistency — don't re-roll)

| Need | Reuse |
|---|---|
| Tabs | `shared/ui` Tabs primitive (as FeaturePage uses) |
| Story read + edit | `StoryDetailPage` layout + `StoryForm` + `useStory`/`useUpdateStory`/`useDeleteStory` |
| Design doc (read) | the themed artifact render (`designArtifactUrl`) + `AnnotatablePreviewDialog` in read mode |
| Design chat (edit) | the existing `StoryDesignWorkspace` (opened in a new tab) — unchanged |
| Implementation report | the sandboxed iframe pattern from `ImplementationReviewWorkspace` |
| Rollback | `MarkdownView` (documents renderer) |
| Objects modified | the existing per-object table |
| Doc chrome consistency | a new thin `StoryDocument` wrapper (label + renderer dispatch) — the one net-new component |
