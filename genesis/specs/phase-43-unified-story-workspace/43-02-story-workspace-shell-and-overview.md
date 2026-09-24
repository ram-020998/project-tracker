# 43-02 — Story Workspace shell + Overview + routing (remove the drawer + the split routes)

> **Phase 43 · sub-phase 02** — the single canonical page + Overview + the navigation unification.
> Depends on 43-01 (the consolidated read). Read the umbrella + `StoryDetailPage.tsx`, `BoardPage.tsx`,
> `BoardCardDrawer.tsx`, `StoriesTab.tsx`, `router.tsx`, `shared/layout/breadcrumbs.ts`.

## Goal

The **`StoryWorkspacePage`** shell (header + tabs) with the **Overview** tab fully working (read + inline
Edit/Delete), the **canonical route**, redirects from the two legacy routes, and every entry point repointed
here — so a story opens the **same page** from anywhere (Q1/Q2/Q4).

## Build

1. **Route (Q1):** add `applications/:appUuid/stories/:storyId` → `StoryWorkspacePage`.
   - **Redirects** so old links resolve: `applications/:appUuid/features/:featureId/stories/:storyId` → the canonical route; `workbench/:appUuid/cards/:storyId` → the canonical route (a story resolves its feature from the consolidated read, so `featureId` isn't needed in the URL).
   - Keep a dedicated **design-chat** route for the "Edit / chat" new-tab target (43-03) — either retain `/workbench/:appUuid/cards/:storyId` mapped to a design-chat-only page, or add `applications/:appUuid/stories/:storyId/design-chat`. Decide in build; the new tab must land directly on the chat workspace.
   - Breadcrumbs: App / Feature / Story (reuse `useSetCrumb`; the feature crumb from the consolidated `context`).

2. **`StoryWorkspacePage`** (`web/src/features/workbench/` or a shared `features/stories/` folder — decide in build; it's used by both feature + board contexts, so a neutral home is cleaner):
   - Loads `useStoryWorkspace(appUuid, storyId)`; Loading/Error states (reuse `feedback/states`).
   - **Header:** key + title; badges (type / epic / lane-status); `Edit` + `Delete`; a back affordance (to the board if arrived from the board, else the feature Stories tab — infer from history/referrer or default to the feature).
   - **Tabs** (reuse the `shared/ui` Tabs primitive): render **Overview** always; **Design**/**Implementation** are added in 43-03 (stub the tab list to accept them). Default tab helper stubbed here, finished in 43-03.

3. **Overview tab (Q4):** port the `StoryDetailPage` read layout (description / AC / open questions / details sidebar) + inline **Edit** (reuse `StoryForm` + `useUpdateStory` with `row_version` CAS → 409 toast) + **Delete** (`useDeleteStory` → back to Stories). This replaces `StoryDetailPage` (which becomes a thin redirect or is removed).

4. **Repoint entry points + remove the drawer (Q2):**
   - `StoriesTab` row click → the canonical route.
   - `BoardPage.openCardView(c)` → `navigate('/applications/${appUuid}/stories/${c.id}')` for **every** card (delete the lane-based branching).
   - **Delete `BoardCardDrawer`** and its wiring in `BoardPage`. Relocate **Remove-from-board** to the Story Workspace header (an action shown when the story is on a board) — reuse `useRemoveCard`.
   - The old drawer's "Open full detail" link is gone (the page itself is the detail).

## Tests

- Web (vitest + jest-axe): the page renders Overview from a mocked consolidated read; Edit round-trips via the mocked mutation; Delete navigates away; the header shows the right badges; a story with no stages shows **only** Overview. jest-axe clean.
- A redirect test: hitting a legacy route lands on the canonical page.
- Board test: clicking any card navigates to the canonical route (no drawer); Remove-from-board still works from the new header.

## Done when

Opening a story from the Stories tab or any board lane lands on the identical `StoryWorkspacePage`; Overview read/edit/delete work; the drawer + lane-routing split are gone; legacy routes redirect; tsc/eslint/vitest(+axe) green; `web/static` rebuilt + committed.
