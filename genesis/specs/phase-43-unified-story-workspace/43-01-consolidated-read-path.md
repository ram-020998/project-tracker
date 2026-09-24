# 43-01 — Consolidated, board-independent read path

> **Phase 43 · sub-phase 01** — the backend data path the Story Workspace reads. genesis-only, **no migration**.
> Read the umbrella (`specs/phase-43-unified-story-workspace.md`) + the current `genesis/api/workbench.py`
> (`design/artifact`, `implementation/report`) + `genesis/kb/story_stages.py` (`StoryStageStore`) + `genesis/kb/stories.py`
> (`StoryStore`) before building.

## Goal

One read that returns **everything the Story Workspace needs for a story, regardless of board membership** (Q9),
plus relaxing the two artifact reads so the unified page can render whatever documents exist (Q8/Q10).

## What exists

- `StoryStore` — the story record (`get_story` / `list_for_feature`).
- `StoryStageStore.get_for_story(story_id, stage)` — the per-`(story, stage)` artifact row (`design`, `implementation`);
  **board-independent** (keyed on `story_id`, not a board card).
- `genesis/api/workbench.py`:
  - `GET …/cards/{id}/design/artifact` — serves `design.html` (themed; Lavish when `annotate=1`) — reads the story-stage row but sits under the board path.
  - `GET …/cards/{id}/implementation/report` — `{report_html, rollback_md, objects[], run_id, run_status, story_stage_id}` — **board-card-scoped** (`boards.get_card`) and **lane-gated** to implementation/code-review (the Phase-42 Q16 gate).
- The `runs` table gives each stage row's `run_status` (durable, authoritative).

## Build

1. **A consolidated endpoint** (final path TBD in build — proposed `GET /api/applications/{app_uuid}/stories/{story_id}/workspace`), returning:
   ```jsonc
   {
     "story":   { /* full kb_stories record via StoryStore.get_story */ },
     "context": { "feature_id": 12, "feature_name": "…", "app_uuid": "…",
                  "lane": "code-review", "status": "code-review", "on_board": true },
     "design":  { "story_stage_id": 34, "status": "in-review", "chat_session_id": "…",
                  "run_id": "r-…", "run_status": "done", "has_artifact": true },
     "implementation": { "story_stage_id": 35, "run_id": "r-…", "run_status": "done",
                  "has_report": true, "has_rollback": true, "objects": [ /* ImplObject[] */ ] }
   }
   ```
   - `design`/`implementation` are **null** when the story has never had that stage (a To-Do or feature-side story → both null → Overview-only page).
   - `lane`/`status`/`on_board` derive from `kb_stories.status` + `on_board`; `feature_name` from the feature.
   - Reads `StoryStageStore.get_for_story` **directly** — no board-card requirement (the fix for the feature side, Q9).
   - `run_status` joined from the `runs` table (authoritative — mirror how the board DTO does it).
   - `has_artifact`/`has_report`/`has_rollback` = the artifact files exist on disk under `story_stage_artifacts_dir/<id>/`.
   - `objects` parsed from `implementation.json` (as the current report endpoint does).
   - 404 only when the **story** doesn't exist; a story with no stages returns `design:null, implementation:null` (not an error).

2. **Relax the artifact reads to story-scoped** (drop the board-card requirement + the Q16 lane gate):
   - Keep serving the **design HTML** (themed/annotatable) and the **implementation report HTML** by `story_id` (read the story-stage row directly). The page renders a document tab **only when the artifact exists**, so the lane gate is redundant.
   - Preserve read-only + the existing themeing/sandboxing. No behavioural change to the bytes served.
   - Decide during build whether to (a) keep the routes under `/workbench/boards/{app_uuid}/cards/{id}/…` but stop requiring `get_card`, or (b) add story-scoped route aliases; prefer the smallest, non-duplicating change. Keep the existing paths working (the board card views + the design chat still use them).

3. **Web client + types + hooks:** add `storyWorkspace(appUuid, storyId)` to the api client; a `StoryWorkspace` type (story + context + design + implementation); a `useStoryWorkspace` query with a sensible refetch (align with the board's 10s while a run is active).

## Tests

- Backend pytest: the endpoint for (a) a story with no stages (both null, 200), (b) a story with a design only, (c) a story with design + implementation, (d) a story **not on any board** (still resolves — the Q9 fix), (e) a missing story → 404.
- Assert the report/objects/rollback flags reflect on-disk artifact presence; assert no lane gate rejects a valid read.
- Keep the existing board-card design/report tests green (don't regress the board views / design chat).

## Done when

The consolidated endpoint returns correct, board-independent data for all stage combinations; the artifact reads work story-scoped without the lane gate; web types/hooks compile; backend pytest + ruff green. No migration.
