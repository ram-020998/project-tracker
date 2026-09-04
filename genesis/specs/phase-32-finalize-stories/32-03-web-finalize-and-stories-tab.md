# 32-03 — Web: Finalize Stories + Stories tab grid + routed detail/edit

> **Status:** ✅ SHIPPED (genesis v0.60.0). · Part of Phase 32. Repo: **genesis** (web). · Gate: independent review = SHIP.

## Purpose

Surface the finalized backlog: the header **Finalize Stories** action + warning dialog, the **Stories grid**,
and the routed **story detail + Edit** page with **story-level CRUD**. Layered data access (component → hook →
`lib/api` → typed client), tokens not raw colors, jest-axe on the new surfaces (ADR-026/027). No shell edits
(the ADR-056 plug-in invariant — Stories is an existing reserved tab).

## Types + api + hooks

- `types/features.ts`: `Epic`, `Story` (fields per 32-01), `StoriesResponse { finalized_at, epics, stories }`;
  `FeatureDetail` gains `stories_finalized_at`.
- `lib/api/features.ts`: `finalizeStories(id)`, `listStories(id)`, `getStory(id, storyId)`, `createStory(id,
  body)`, `updateStory(id, storyId, body)` (sends `row_version`), `deleteStory(id, storyId)`.
- `features/features/hooks.ts` + `lib/query/keys.ts`: `useStories(id)`, `useStory(id, storyId)`,
  `useFinalizeStories(id)`, `useCreateStory`/`useUpdateStory`/`useDeleteStory` (invalidate stories + feature on
  success; surface a 409 stale-write as a friendly "reload — it changed" toast).

## Feature header (`FeaturePage.tsx`)

Replace the `Page` `actions` `<Link>Back to application</Link>` with a **Finalize Stories** control (derive
`breakdownCompleted` from `detail.stages` where `stage==='breakdown' && status==='completed'`;
`finalized = !!detail.feature.stories_finalized_at`):
- `finalized` → a subtle **"Stories finalized ✓"** badge.
- `!finalized && breakdownCompleted` → an enabled **Finalize Stories** button → a **warning `Dialog`**: title
  "Finalize stories?", body "All stories from the Feature Breakdown will be moved into the application and
  become editable here. **This is a one-time action and cannot be reverted.** Are you sure?", a **Finalize**
  (danger/primary) + Cancel. Confirm → `useFinalizeStories` → on success set the tab to **stories** + toast
  "N stories finalized".
- else → a **disabled** Finalize Stories button + tooltip "Complete Feature Breakdown to finalize stories".

(Breadcrumbs remain the navigation, so dropping the back link is fine.)

## Stories tab (`StoriesTab`, replaces `StoriesReserved`)

- Not finalized → an empty state ("Stories arrive when you finalize the Feature Breakdown" + the Finalize
  button when eligible, else the disabled/tooltip form).
- Finalized → a **formatted grid** (a `Card` + `<table>`, mirroring the Artifacts-tab table): columns
  **Title · Type · Epic · Category · Appian part**. Type → a `Badge` (Story=primary / Task=neutral); Category →
  a chip (nice-to-have highlighted). Rows grouped or sorted by epic then `position`. Row click (and a focusable
  title button — a11y) → the detail route. An **Add story** button (top-right) → the create form (a `Dialog` or
  the detail page in "new" mode). Empty-after-finalize (all deleted) → a gentle empty state + Add.

## Story detail (routed `…/features/:id/stories/:storyId`)

- A `StoryDetailPage` + a route in the features router; a breadcrumb crumb (`story:<id>` → title).
- **Read mode:** all fields — title, type, epic (parent), category, appian part, description, acceptance
  criteria (rendered list), dev note, questions, labels.
- **Edit mode** (a toggle): a form — title (input), description (textarea), **type** (`Story`/`Task` select),
  **category** select, **parent** = an **epic `<select>`** listing the feature's epics (+ a "— none —" option),
  an **acceptance-criteria list editor** (add/remove lines), dev note (input), labels (chips/comma input),
  questions (list). **Save** → `useUpdateStory` (sends `row_version`; 409 → "reload") ; **Cancel**; **Delete**
  → a confirm `Dialog` → `useDeleteStory` → back to the Stories tab.
- `status` is **not** shown/edited (forward-compat only).

## Gates

`cd web && npx tsc --noEmit && npx eslint . && npx vitest run && npm run build`; **commit `web/static`**
(stale-bundle guard). Tests: the grid renders finalized stories with the right columns/badges; the Finalize
button's three states (disabled / enabled+dialog / finalized-badge); the detail Edit form saves a change
(incl. changing the parent from the epic dropdown) and deletes; jest-axe on the grid + detail. MSW handlers for
the new endpoints.

## Gate

Independent review = SHIP: three Finalize states correct; grid columns/formatting; parent dropdown lists the
feature's epics; edit/add/delete wired with `row_version`; a11y/dark-parity/no-hardcoded-hex; no shell edits.
