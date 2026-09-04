# 33-03 — Web: the Workbench nav, landing, board (dnd-kit), import & drawer

> **Status:** ✅ SHIPPED (genesis v0.61.0). · Part of Phase 33. Repo: **genesis/web**. · **Depends on:** 33-02 (the `/api/workbench` API), ADR-060 (the Phase-32 story detail + `Select` + epic-tone/badges), ADR-049/27 (nav + app shell).

## Purpose

Build the Workbench UI: the nav item + routes, the landing (curated boards + add/remove applications), the
per-application Kanban board with `@dnd-kit` drag, the batched import dialog, and the card drawer. Reuse
Phase-32 primitives. Gates green + `web/static` committed. **No backend.**

## Dependency

Add **`@dnd-kit/core` + `@dnd-kit/sortable`** (pinned exact versions) via
`npm i --registry=https://registry.npmjs.org/ @dnd-kit/core@<x> @dnd-kit/sortable@<x>` (the §6 npmrc rule).
No other new dep.

## Nav + routes + breadcrumbs

- `shared/layout/nav.ts::PRIMARY_NAV` — insert **`{ to: "/workbench", label: "Workbench", icon: SquareKanban }`**
  after Home (so it reads Home · **Workbench** · Chat · Runs · Catalog · Documents · Memory). Add `SquareKanban`
  (or `KanbanSquare`) to `shared/ui/icons.ts`.
- `app/router.tsx` — `{ path: "workbench", element: <WorkbenchPage/> }` + `{ path: "workbench/:appUuid",
  element: <WorkbenchPage/> }` (one page; the `:appUuid` selects the active board sub-tab).
- `shared/layout/breadcrumbs.ts` — register `/workbench` → "Workbench" and `/workbench/:appUuid` → the app name
  (`useSetCrumb("app:"+uuid, name)` reusing the existing app-crumb registration).

## `features/workbench/`

- **`WorkbenchPage.tsx`** — the shell:
  - **Empty state** (no boards added): a centered card "No boards yet" + **"Add applications"** button →
    `AddApplicationsDialog`.
  - **With boards:** a **sub-tab strip** of added boards (application names; `:appUuid` = active; overflow →
    horizontal scroll) + an **"+ Add"** affordance + a per-board overflow menu with **"Remove board"** (confirm;
    detaches only). Selecting a tab renders `<BoardPage appUuid=…/>` (route-synced).
- **`AddApplicationsDialog.tsx`** — lists `GET /workbench/applications/available` (multi-select checkboxes,
  searchable via the shared search input) → "Add N" → `POST /workbench/boards` per selection (or a batch) →
  invalidate boards → select the first added.
- **`BoardPage.tsx`** — the Kanban for one app:
  - **Toolbar:** board search (title/key), **Epic / Type / Label** filters (the themed `Select`), a **"Import
    stories"** button, and a card count. (Filters narrow the visible cards client-side.)
  - **Lanes:** render the 8 `lanes` (from the API — no client order drift) as `BoardColumn`s, each a header with
    the label + a **count badge** and a scrollable card list.
- **`BoardColumn.tsx`** — a `@dnd-kit` **droppable**; renders its lane's cards (filtered) as sortable
  `StoryCard`s; empty-lane placeholder.
- **`StoryCard.tsx`** — a `@dnd-kit` **sortable** card: **type icon (Story/Task) + key**, **title**, a **colored
  epic chip** (reuse the Phase-32 epic-tone palette), **category + labels** badges. No assignee/points. Click →
  `BoardCardDrawer`. Keyboard-draggable (dnd-kit keyboard sensor) with an accessible drag handle + `aria-label`.
- **`ImportStoriesDialog.tsx`** — `GET …/importable` grouped by **feature → epic**; a collapsible tree with
  **multi-select** (select-all per group) + a running "N selected"; **"Add N to board"** → `POST …/cards` →
  invalidate the board → toast ("Added N stories to To Do"). Empty state if nothing importable ("Finalize a
  feature's stories to import them" with a link to the app's features).
- **`BoardCardDrawer.tsx`** — the shared `Drawer`, rendering the **Phase-32 story detail content read-only**
  (extract the read view from `StoryDetailPage` into a shared `StoryDetailView` both consume) + a **"Open full
  detail"** link to `…/features/:featureId/stories/:storyId` (edit there) + a **"Remove from board"** action
  (confirm → `DELETE …/cards/{id}`).
- **`lanes.ts`** — the display labels + lane tone keyed by status (mirrors the backend `STORY_LANES` order;
  order still comes from the API `lanes` — this only supplies labels/tone).
- **`hooks.ts` / `lib/api/workbench.ts` / `types/workbench.ts` / query keys** — `useBoards`,
  `useAvailableApplications`, `useAddBoard`, `useRemoveBoard`, `useBoard(appUuid)`, `useImportable(appUuid)`,
  `useImportCards`, `useMoveCard`, `useRemoveCard`; keys `workbench.boards()`, `workbench.board(appUuid)`,
  `workbench.importable(appUuid)`, `workbench.available()`.

## Drag-and-drop (`@dnd-kit`)

- `BoardPage` wraps the lanes in a `DndContext` (Pointer + **Keyboard** sensors). On `onDragEnd`: compute the
  target lane + index → **optimistically** move the card in the query cache → `useMoveCard`
  (`PATCH …/cards/{id}` with `{lane, position, row_version}`). On error (409/other): **roll back** the cache +
  a toast ("Card changed elsewhere — refresh"). Update the moved card's `row_version` from the response.
- Accessible: a visible drag handle, `aria-roledescription`, keyboard move (space to lift, arrows to move,
  space to drop), and a screen-reader announcement of the lane change.

## Reuse (no re-rolling)

The themed `Select` (toolbar filters), the epic-tone palette + Story/Task + category badges (`StoryCard`), the
`Drawer` + `Dialog` primitives, the shared search input, and the extracted `StoryDetailView` (drawer). No new
shell components beyond the nav row.

## Tests (`features/workbench/workbench.test.tsx`)

- landing empty state → Add-applications dialog → adding renders a board tab.
- board renders 8 lanes with counts from a mocked `useBoard`; cards show type/key/title/epic/labels.
- import dialog lists grouped importable stories, multi-select + "Add N" calls the mutation.
- a move mutation is fired with the right `{lane, row_version}` (dnd-kit interaction or a direct handler unit
  test — dnd in jsdom is limited, so unit-test the `onDragEnd` → payload mapping as a pure function).
- card drawer opens the detail + "Remove from board" fires the mutation.
- **jest-axe** on the landing, board, import dialog, add-apps dialog, and drawer.

## Gates

`cd genesis/web && npx tsc --noEmit && npx eslint . && npx vitest run && npm run build`; **commit `web/static`**
(stale-bundle guard). Local commit (no push).

## Gate

Independent review = SHIP → 33-04.
