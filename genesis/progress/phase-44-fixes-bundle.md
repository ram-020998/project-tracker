# Phase 44 — Workbench, SDLC & Workspace Fixes (12-issue bundle) — as-built

> ✅ **SHIPPED 2026-09-25 — genesis v0.75.0, CI green. PHASE 44 COMPLETE.** genesis-only; **one migration**
> (`m0022`, `current_version` 21 → 22) for the story-identifier sequence — every other fix is code-only; **no
> Genesis Hub change.** **ADR-072 Accepted.** Release: master `19b733fe`, tag `v0.75.0`. Spec:
> `specs/phase-44-fixes-bundle.md`.

## What shipped (the 12 fixes)

1. **App Features tab next to Overview** — `ApplicationDetail.tsx` tab reorder (default stays Business Map).
2. **Delete a feature** — a `Trash2` icon + confirm dialog in `FeaturePage.tsx` header actions, using the
   pre-existing `useDeleteFeature` → `DELETE /api/features/{id}`; on success navigates back to the app.
3. **Global human-readable story ids `GNS_000001`** (ADR-072) — `m0022` adds a `kb_sequences` counter;
   `kb/stories.py::_next_story_key` allocates a global monotonic id inside the write tx (`UPDATE … RETURNING`)
   in both `finalize()` and `create_story()`, stored in the already-synced `kb_stories.key` (no Hub change;
   existing stories untouched). Displayed in the Stories grid (new ID column) + board card + workspace header.
4 & 5. **Workbench system lane moves publish to the Hub** — `StoryDesignFinalizer` +
   `StoryImplementationFinalizer` now take the `CollaborationService` (wired in `api/app.py`) and call
   `publish_board_move` after each audited lane transition (best-effort, `is_enabled()`-gated, never raises).
   This propagates system moves (fix 4) AND — because the move is now on the Hub — the always-on backend
   auto-pull no longer re-mirrors the stale Hub status back over an unpublished `design→design-review`, which
   was why the design card "didn't advance" on collaboration-enabled instances (fix 5, same root cause).
6. **Real-time run node "View Details"** — `runs/steps.py::fold_iterations` extends a running turn's `seq_end`
   to the latest in-turn event (so the conversation slice includes streamed events); a new scoped
   `useRunNodeStream` (run-detail/hooks.ts) tails the run SSE for the open node while it's active, and the
   dialog renders the running turn's `Conversation` **live** (open-ended slice; jsdom-guarded).
7. **Chat list hides stage chats** — `api/chat.py::list_sessions` excludes all `STAGE_CHAT_MODES` (a shared
   constant in `chat/store.py`: feature_spec / ux_design / technical_design / feature_breakdown / story_design),
   so `/chat` shows only `read_only` + `copilot`.
8. **Runs server-side pagination** — `RunStore.list(*, limit, offset, q)` + `count()` + a shared `_filter_sql`
   (with an `active` = non-terminal filter); `RunManager` passthrough; `/api/runs` returns `{runs, total,
   limit, offset}` (default 20) with a page-scoped orphan-reconcile; `RunsPage` is a single paginated table
   (Prev/Next + total) with server-side status/workflow/search filters + `keepPreviousData`.
9. **Catalog hides internal MCPs** — `catalog_routes.py` `_INTERNAL_MCP` (`genesis-kb`, `genesis-memory`,
   `genesis-introspection`, `genesis-control`, `appian-dev`, `appian-devops`, **`appian-dev-write`**) is
   stripped from `required_mcp` in `/catalog` + `/catalog/available`, so internal/managed components are never
   shown or validated as prerequisites and write-capable workflows (e.g. Ticket Implementation) launch.
10. **Documents grid** — removed the "Linked apps" column from `DocumentTable.tsx` (the Remove action stays).
11. **CLI connector banners** — the gws + sail connector cards moved from the top of the CLI tab into each
    CLI's detail (`CliTab.tsx` → `CliDetail.tsx`), shown only when that CLI is selected.
12. **Settings General** — first tab + the default (`SettingsPage.tsx`).

## Live fixes folded in (fleet testing, before release)

- **Workflow-detail crash** (`/catalog/story-implementation`): a regression from fix 8 — `catalogApi.runsFor`
  still typed `GET /runs` as an array, but it now returns `{runs,total,…}`, so `(runs.data ?? []).map` threw
  (captured via headless Chrome). Fixed `runsFor` to request one page and unwrap `.runs`.
- **Ticket Implementation not launchable**: `appian-dev-write` (the Phase-42 write MCP) wasn't in
  `_INTERNAL_MCP`; added it → `required_mcp` filters to `[]` → launchable.

## Migration

- **`m0022_story_sequence`** — `kb_sequences (name TEXT PK, next_val INTEGER)`, seeded `('story', 1)`;
  `current_version` 21 → **22**. Additive + idempotent. All `current_version == 21` head assertions bumped to
  22 across the suite (+ the synthetic "next migration" test bumped to version 23).

## Gates at release

genesis pytest **851** + ruff clean; web tsc + eslint (0 errors) + **vitest 288** + build; fresh DB → **v22**.
Independent sub-agent audit = **SHIP** (no MUST-FIX). Both fleet instances restarted on v0.75.0.

## New / changed files (highlights)

- **Backend:** `db/migrations/m0022_story_sequence.py` (+`__init__`), `kb/stories.py`, `chat/store.py`,
  `api/chat.py`, `api/catalog_routes.py`, `chat/story_design_finalizer.py`,
  `chat/story_implementation_finalizer.py`, `api/app.py`, `runs/store.py`, `runs/manager.py`,
  `api/run_routes.py`, `runs/steps.py`.
- **Web:** `features/applications/ApplicationDetail.tsx`, `features/features/{FeaturePage,StoriesTab}.tsx`,
  `features/library/DocumentTable.tsx`, `features/settings/{SettingsPage, components/cli/{CliTab,CliDetail}}.tsx`,
  `features/runs/{RunsPage,hooks}.tsx`, `features/run-detail/{hooks.ts, components/{Inspector,NodeIterationsDialog}}.tsx`,
  `lib/api/{runs,catalog,index}.ts`.
- **Tests:** new `tests/test_phase44.py`; finalizer-publish tests + a feature-delete web test; the runs test
  rewritten for pagination; settings/library tests updated; head-version assertions bumped to 22.

## Notes / out of scope

- Existing stories are **not** backfilled with `GNS_` ids (decision). No Genesis Hub contract change.
- The runs Active/History split was replaced by the status filter + a single paginated table.
- ADR-072 recorded in `reference/decision-log.md` (the authoritative ADR mirror; consistent with ADR-068..071).
