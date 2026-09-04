# Phase 33 — The Workbench (per-application Kanban execution board) — AS-BUILT

> **✅ SHIPPED 2026-09-04 — genesis v0.61.0 (single repo + m0017 + `@dnd-kit`), CI green.** ADR-061 **Accepted** (amends ADR-049).
> Specs: `specs/phase-33-workbench.md` + `phase-33-workbench/33-01..33-05`.
> Commits: `5c81284` (33-02 backend) · `b6bb79f` (33-03 web) · `c84cda9` (33-04 hardening) · `8f45d9a` (UX: sidebar sub-tabs / slim page / truncation / lane contrast) · `8932177` (cross-lane drag) · `4de0d47` (intra-lane reorder + reorder endpoint) · `2992be8` (release, tag **v0.61.0**).
> Gates at release: genesis pytest **701** (+17) + ruff clean; web tsc + eslint (0 errors) + **vitest 237** + build; `web/static` committed; CI clean-install migrates a fresh DB to **v17**.

## What shipped

A new top-level **Workbench** — the place where the actual SDLC work happens — holding one **Jira-style Kanban
board per application** over the app's **finalized** stories (ADR-060), aggregated across all of the app's
features.

**Navigation (left sidebar).** Under the **Workbench** primary-nav item, each added application is a **sub-tab**
(→ `/workbench/:appUuid`) with its card count; a **`+`** beside the "Workbench" label opens **Add applications**
(pick any tracked app → each becomes a board). Boards are a **curated** set (add/remove). The Workbench *page*
renders only the selected board — the app name + Remove-board + the board — with no page-level header/add (an
empty Workbench shows an add prompt). *(The Workbench nav item is the one sanctioned shell edit — ADR-049 amendment.)*

**Eight fixed lanes**, in order: **To Do → Design → Design Review → Implementation → Code Review →
Verification → Deployment → Done**. A card's **lane IS its `kb_stories.status`** (single source of truth).

**Import (batched, on demand).** An **Import stories** dialog lists the app's finalized stories **not yet on the
board**, grouped feature → epic, multi-select → **Add N** → they land in **To Do**. Never auto-loaded.

**Drag: across lanes AND reorder within a lane** (`@dnd-kit` multiple-containers — cards are `useSortable`,
lanes are droppable `SortableContext`s; a local per-lane id mirror synced from the server [never mid-drag], an
`onDragOver` that relocates a card between lanes, an `onDragEnd` that finalizes the intra-lane index). A drop is
persisted via a **bulk `PATCH /workbench/boards/{app}/lanes/{lane}`** reorder endpoint that sets each listed
card's `board_position=index` + `status=lane` in one transaction (handles both intra-lane order and a
cross-lane status flip). A **DragOverlay** keeps the dragged card visible across the horizontally-scrolling
board. **Free movement** (any lane → any lane) this phase.

**Card detail drawer + remove.** Clicking a card opens a right-side **drawer** (type/epic/lane badges +
feature + description + AC + labels) with **Open full detail** (→ the feature's Stories tab page) and **Remove
from board** (clears board membership only — the story stays in the Stories tab).

**Data model (m0017; `current_version` 16→17).**
- `workbench_boards` — the curated app→board registry; `app_uuid` UNIQUE, FK→`kb_applications` **ON DELETE
  CASCADE** (untracking an app drops its board; `KbStore.untrack_application` also deletes it explicitly).
- `kb_board_cards` — story membership + `board_position`; FK→`workbench_boards(id)` + `kb_stories(id)`, both
  CASCADE; `UNIQUE(board_id, story_id)`. **No lane column** — lane = `kb_stories.status`.

**Backend.** `genesis/kb/boards.py::BoardStore` (list/available/add[409 dup, 400 untracked]/remove boards;
`get_board` [lanes=`STORY_LANES` + counts]; `importable`; `import_stories` [batch → To Do, idempotent skips,
one tx]; `move_card` [`row_version` CAS]; `reorder_lane` [bulk]; `remove_card`). `api/workbench.py` routes
registered in `api/app.py`. `domain`: `LifecycleState` += `TO_DO`/`DESIGN_REVIEW`; a `STORY_LANES` constant;
`STORY_STAGE_TRANSITIONS` reconciled to the 8-lane order (deployment after verification) — **forward-compat,
NOT enforced on a board drag** (see below). Tests: `test_board_store` + `test_workbench_api` (boards CRUD, 409
dup / 404, importable scoping, batched import, move CAS→409 + 400 bad lane, reorder [order + cross-lane], remove,
untrack cascade); every `current_version==16` test bumped to 17.

**Web.** `features/workbench/` — `WorkbenchPage`, `BoardPage` (dnd-kit), `BoardColumn`, `StoryCard`(+`StoryCardFace`
for the overlay), `ImportStoriesDialog`, `AddApplicationsDialog`, `BoardCardDrawer`, `lanes.ts`, `epic-tone.ts`,
`hooks/api/types`; `Sidebar.tsx` `WorkbenchNav` (board sub-tabs + `+`); nav/routes/breadcrumbs. **`@dnd-kit`**
pinned (core 6.3.1 / sortable 10.0.0 / utilities 3.2.2). jest-axe on the landing/board/import/drawer.

## Decisions (locked with the user, 2026-09-04)
Eight lanes with **Deployment after Verification**; lane = status; imported cards → To Do; **free drag**; one
**curated** board per app (add/remove applications); remove-from-board keeps the story; `@dnd-kit`; card-click
drawer; **flat lanes**; genesis-only + m0017. **Recorded ADR-050 relaxation:** a board move is a lane assignment
(writes `status` directly), **not** a gated `LifecycleService.transition` this phase — gated moves + m0013 audit
arrive with the per-lane automation.

## Iterative UX (applied on user feedback, same day)
1. Boards moved from a page-level tab strip to **left-sidebar sub-tabs** (+ the `+` in the sidebar); the board
   page slimmed to just the board. 2. **Card titles truncate** (`line-clamp-2`). 3. **Lanes given contrast**
   (bordered panels + white cards + a primary-tinted drop highlight). 4. **Cross-lane drag** fixed (draggable/
   droppable, then) 5. **intra-lane reorder** added (the full multiple-containers pattern + the reorder endpoint).

## Out of scope (future phases)
The **per-lane automation** (dragging into Design kicks off the design workflow, Implementation the build,
Code Review the review, etc. — the whole point of the later phases); **gated** transitions + m0013 audit on
moves; WIP limits; swimlanes; multiple boards per app; card ordering beyond a single `board_position`;
assignees / story points / sprints (single-user, ADR-026); push-to-Jira; real-time multi-tab sync.

## Live acceptance (user-driven)
Add an application (sidebar `+`) → Import a batch of finalized stories (→ To Do) → drag cards across the 8
lanes and reorder them up/down within a lane (persists across reload) → open a card (drawer) → remove from
board / remove the board.
