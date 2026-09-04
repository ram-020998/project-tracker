# 34-04 — Backend: per-story store, design-start, the finalizer

> **Status:** 🟡 DRAFTED. · Part of Phase 34. Repo: **genesis**. · **Depends on:** 34-01 (m0018 + contracts), 34-03 (the workflow), ADR-057/058 (`StageFinalizer` + `_launch_td`/`_current_stage_html`), ADR-050 (`LifecycleService` + m0013).

## Purpose

The backend that turns a drag-into-Design into a running, grounded design run and, on success, an
auto-advanced Design-Review card carrying the artifact + a completion chat. Mirrors the Phase-29/30 stage
machinery at the story grain.

## Build

1. **m0018** (`genesis/db/migrations/m0018_story_stages.py`) — the two tables from 34-01; register in
   `migrations/__init__`; `current_version` 17 → **18**. Bump every `current_version == 17` test + the test_db
   baseline/rows assertions (the §7 lesson).
2. **`genesis/kb/story_stages.py::StoryStageStore`** — the 34-01 contract (mirror `StageStore`); export from
   `kb/__init__`. `KbStore.untrack_application` already cascades via the FK chain (story→feature→app); confirm.
3. **Domain:** a **story lifecycle** for the automated transition — reuse the `STORY_STAGE` machine via a
   `build_story_lifecycle_service(...)` (parallel to `build_stage_lifecycle_service`) so the finalizer can call
   `LifecycleService.transition(EntityKind.STORY, story_id, <design→design-review action>)` audited to m0013.
   The action name is finalized here against the reconciled `STORY_STAGE_TRANSITIONS` (Phase 33 added the
   8-lane order; this phase wires the `design → design-review` edge as the FIRST enforced/audited one). The
   store accessor reads/writes `kb_stories.status` with `row_version` CAS.
4. **Design-start endpoint** (`genesis/api/workbench.py`):
   `POST /workbench/boards/{app_uuid}/cards/{story_id}/design/start` →
   - 404 if the card isn't on the board; move the story to `design` (BoardStore — free move);
   - `StoryStageStore.get_or_create(story_id,'design')`; if it already has a `run_id`/`chat_session_id`,
     `reset_for_reupload` (Q9 — re-run updates in place);
   - snapshot the feature's current Spec/UX/TD HTML to files (reuse a `_current_stage_html`-style helper over
     `StageStore`); **fail-fast 409** if any is missing, no dev env, app not synced, or the workflow isn't
     installed (mirror `_launch_td`'s guards + friendly messages);
   - `run_manager.start("story-design-analysis", {story_id, feature_id, app_uuid, story_stage_id, spec_path,
     uxdesign_path, techdesign_path, story})`; `set_source(run_id=...)`; `set_status('in-progress')`;
   - return the updated card.
5. **`genesis/chat/story_design_finalizer.py::StoryDesignFinalizer`** — mirror `StageFinalizer`:
   - a story-scoped `_BINDINGS = {"story-design-analysis": _Binding(stage='design', artifact='design.html',
     chat_mode='story_design', seed=_seed_story_design)}`;
   - on `run.final{done}`: bound-run guard (`kb_story_stages.run_id == run_id`) + idempotency
     (`chat_session_id` set → skip) + stage-match; open the `story_design` chat (seed = the ticket + "design.html
     is the source of truth; walk the Open Questions; keep it grounded, show code"); copy `design.html` →
     sandbox; `set_html` + `set_chat_session`; `set_status('in-review')`; **`LifecycleService.transition`
     design→design-review** (audited);
   - **on-read recovery** `reconcile_story_stage(story_stage_id)` called best-effort from the board/card GET
     (the orphaned-worker §7 lesson) + a startup `reconcile()`; register a recovery-only instance in the
     workbench routes (NOT double-`attach()`).
6. **`story_design` ChatModeProfile** (`genesis/chat/mode_profile.py` + the store mode whitelist) — a clone of
   `technical_design` (read-only `@genesis-kb`+`@appian-dev`, sandboxed fs-write) + `_STEERING_STORY_DESIGN`.
7. **Board card DTO** (`BoardStore.get_board`/`get_card`) — LEFT JOIN `kb_story_stages`(stage='design') + the
   `runs` table → `design_run_id`, `design_run_status`, `design_chat_session_id`, `design_status` (34-01).
8. **Register** the finalizer + endpoint in `api/app.py`/`register_workbench_routes` (after features).

## Tests (`tests/test_workbench_api.py` + `tests/test_story_stages.py`)

design-start moves the story to `design` + binds a run (stub `run_manager`); fail-fast 409 on no dev env / not
synced / not installed; re-run resets in place (one design per story); the finalizer moves done→design-review +
opens the chat + binds the artifact + is idempotent + bound-run-guarded + recovers on read; the card DTO
surfaces `design_run_status` from the runs table; lane-automation transition audited to m0013. Bump the
`current_version` tests.

## Gate

genesis pytest + ruff green; independent review = SHIP → proceed to 34-05.
