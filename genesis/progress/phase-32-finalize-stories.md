# Phase 32 — Finalize Stories — AS-BUILT

> **✅ SHIPPED 2026-09-04 — genesis v0.60.0 (single repo + m0016), CI green.** ADR-060 **Accepted**.
> Specs: `specs/phase-32-finalize-stories.md` + `phase-32-finalize-stories/32-01..32-05`.
> Commits: `00cf1dc` (32-02 backend) · `f799e5f` (32-03 web) · `fce7622` + `6c2c8bb` (Stories UX pass + sort/row) · `38d6fc8` (themed Select) · `f4ca84a` (run-graph UX fixes) · `0de9b61` (release, tag **v0.60.0**).
> Gates at release: genesis pytest **684** + ruff clean; web tsc + eslint (0 errors) + **vitest 232** + build; `web/static` committed.

## What shipped

Turns the Feature Breakdown's file-only backlog into **first-class, editable Genesis data**.

**Finalize (one-time, irreversible).** Once the **Feature Breakdown stage is `completed`**, a **Finalize
Stories** control in the feature header (replacing the "Back to application" link; disabled with a tooltip
until then; a warning confirm dialog; a "Stories finalized ✓" badge afterwards) calls
`POST /features/{id}/stages/breakdown/finalize`. It parses the canonical `backlog.json` embedded in the
finalized `breakdown.html` (reusing `_parse_embedded_backlog` + `_current_stage_html`, with the run's
`backlog.json` as a fallback — the same lossless source as the Jira export) and, in **one transaction**,
inserts every epic + story/task and stamps `kb_features.stories_finalized_at`. **409** if the breakdown
isn't completed or is already finalized (the marker gates re-finalize independent of the story count — no
un-finalize, no re-sync); **422** on a missing/empty embedded backlog.

**Data model (m0016; `current_version` 15→16).**
- `kb_epics` — `feature_id` FK→`kb_features` CASCADE, `key`, `title`, `description`, `workstream`, `position`.
  Created at finalize; fixed thereafter (no epic CRUD this phase).
- `kb_stories` — `feature_id` FK CASCADE, `epic_id` FK→`kb_epics` **SET NULL** (parent), `key`, `title`,
  `story_type` (Story|Task), `category` (core|nice-to-have), `appian_part`, `description`,
  `acceptance_criteria`/`questions`/`labels` (JSON), `dev_note_ref`, `status` (default **`design`** — a
  forward-compat seam, **not surfaced**), `position`, `row_version`.
- `kb_features.stories_finalized_at` — the one-time marker.

**Backend.** `genesis/kb/stories.py::StoryStore` (finalize + list/epics + get/create/update/delete;
`row_version` CAS → `StaleWriteError`; `epic_id` validated to the feature). `domain/entities.py` promotes
`Story` to live + adds `Epic`; `domain/errors.py` + `AlreadyFinalizedError` (→409). API story CRUD:
`GET/POST /features/{id}/stories`, `GET/PATCH/DELETE /features/{id}/stories/{story_id}`. Feature detail
exposes `stories_finalized_at` (already `SELECT *`). Tests (`tests/test_features_api.py`): finalize persists
+ counts; 409 (not completed) / 409 (re-finalize, survives delete-all) / 422 (no embedded JSON); full CRUD
(add/edit/reparent/stale-409/bad-epic-400/delete); cascade. `current_version==15` tests bumped to 16.

**Web.** `StoriesTab` (`FinalizeStoriesControl` + `StoriesGrid` + `AddStoryDialog`) — the reserved Stories tab
becomes a **grid** (columns **Epic · Type · Title**; per-epic **colored tags**; Story/Task **colored tags**;
**search + Type/Epic Select filters**; **grouped by epic**; **client pagination** 10/page; **whole-row**
click, keyboard-accessible). `StoryForm` (shared add/edit form; parent-epic dropdown). `StoryDetailPage`
(routed `…/stories/:storyId` — modern two-column read [Description + numbered AC cards + a Details sidebar]
+ Edit + Delete). `FeaturePage` header control + Stories tab live + tab seeded from the URL (a new
`…/features/:id/stories` route opens the grid). Breadcrumbs register the Stories + story-detail routes
(trail: App / Feature / Stories, the Stories crumb links back to the grid). types/api/hooks/query-keys added.

**Also in v0.60.0.**
- **Themed `Select` primitive** (`web/src/shared/ui/select.tsx`, Radix DropdownMenu — accessible, portaled,
  app-styled) replacing native `<select>` in the Stories filters, the StoryForm, and the **Runs page**
  filters (Workflow + Sort). No new dependency (Radix dropdown-menu already installed).
- **Run-detail graph UX fixes** — the executed green path refreshes live (`useRunStream` also invalidates
  `/transitions`) + a manual reload control; the ×N traversal count no longer hides behind the edge (dropped
  the per-edge `zIndex`, sort edges for paint order); standard lucide node icons (Wrench/MessagesSquare/
  RefreshCw); a path-color legend (green = executed ×N · purple = running · dashed = not taken).

## Decisions (locked with the user, 2026-09-04)
Name "Finalize Stories"; epics first-class but **story-only CRUD**; **one-time + irreversible + no re-sync**;
a forward-compat `status` default `design` (not surfaced); a **routed** story detail page; grid sorted by
epic with a whole-row click target and the themed dropdowns.

## Parked / deferred
- **Normalizing** `acceptance_criteria`/`questions`/`labels` into child tables — a considered option; kept
  **JSON** for v1 (ordered free-text owned by one story, always read/written whole, no cross-story queries;
  consistent with the codebase's JSON-in-TEXT precedent under ADR-030; the store seam lets us normalize later
  without an API change). Revisit if we need to filter/report by label or search across AC.
- Per-story **execution** (the `STORY_STAGE_TRANSITIONS` machine — 25-11+); **epic** CRUD; re-sync; bulk
  import; push-to-Jira; story points. Migrating the remaining native `<select>`s (catalog/chat/library/fork)
  to the new `Select`.

## Live acceptance (user-driven)
Finalize a completed-breakdown feature → confirm the dialog → land on the Stories grid → filter/paginate →
open a story → edit (incl. reparent from the epic dropdown) → add → delete → reload (persists) → re-open the
header (Finalize gone; "Stories finalized ✓") → re-finalize blocked.
