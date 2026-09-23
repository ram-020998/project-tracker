# 42-05 — Platform backend (migration, endpoint, finalizer, review surface)

> **Status:** 🟡 DRAFTED. Repo: **genesis**. Implements **ADR-068** (backend) + the m0021 half of **ADR-070**. Mirrors the Phase-34 `start_design` + `StoryDesignFinalizer` backend. Parent: `specs/phase-42-code-implementation.md`.

## 1. Migration m0021 (`current_version` 20 → 21)

- `wiki_object_pages` + `wiki_object_entries` (umbrella §5). Additive; every hardcoded `current_version == 20` test bumps with it; the `clean-install` CI job migrates a fresh DB to **v21**.
- `StoryStageStore.VALID_STAGES` gains `'implementation'` (no schema change — `stage` is TEXT).

## 2. `ObjectWikiStore` (`genesis/kb/object_wiki.py`)

- `upsert_page(app_uuid, object_uuid, object_type, object_name) -> page` (idempotent; creates `sync_uuid`/`row_version`).
- `append_entry(page_id, change_kind, business_description, technical_description, story_key, story_sync_uuid, is_bugfix, change_reason, object_version, author_username) -> entry` — **append-only**; updates the page's `latest_entry_id` + `current_summary` + `updated_at` in one tx.
- `list_for_app(app_uuid)`, `get_page(app_uuid, object_uuid)`, `list_entries(page_id)`, `get_object_history(app_uuid, object_uuid)`. Exported from `genesis/kb/__init__`.

## 3. Implementation-start endpoint (`genesis/api/workbench.py`)

- **`POST /api/workbench/boards/{app_uuid}/cards/{story_id}/implementation/start`** — mirrors `start_design`:
  1. `boards.get_card` (on-board + story fields + feature); **fail-fast 409** on: no dev-tagged env; app not synced into the KB; **no completed design** (`story_stages.get_for_story(story_id, 'design')` not `completed`/`in-review`); **no feature Technical Design** artifact; workflow not installed.
  2. `story_stages.get_or_create(story_id, 'implementation', label)`; snapshot the **design.html** (from the design story-stage, sandbox-preferred via the `_current_stage_html` pattern) + the **feature Technical Design** HTML to the run-stage dir.
  3. Move the card to the `implementation` lane (`boards.move_card`, `row_version` CAS → 409 on drift).
  4. `run_manager.start("story-implementation", {story_id, feature_id, app_uuid, story_stage_id, design_path, techdesign_path, story})`; `story_stages.set_source(story_stage_id, run_id=…)`; `set_status('in-progress')`. Friendly 409 on `FileNotFoundError` (workflow not installed) / bad env.
- Re-run: if the story-stage already has a `run_id`, `reset_for_rerun` first (a re-drag re-runs — same story-stage).

## 4. `StoryImplementationFinalizer` (`genesis/chat/story_implementation_finalizer.py`)

- A `RunManager` event observer bound to `story-implementation` (mirrors `StoryDesignFinalizer`): on `run.final{done}` →
  - bind the artifacts (`implementation-report.html` + `rollback.md` paths + `implementation.json`) to the `kb_story_stages(stage='implementation')` row; set it `completed`;
  - **advance the lane `implementation → code-review`** via `LifecycleService.transition(EntityKind.STORY, story_id, "submit-review", actor=canonical_username(settings))` (audited m0013).
  - **No completion chat** (implementation is unattended — unlike design's review chat).
  - **Send-back path:** a run that ends on the reverify `SEND_BACK` branch (a `done` run whose `reverify.json.decision == "send_back"`, or an explicit terminal signal) → move the lane back to `design-review` instead. (42-04 emits a clear terminal marker the finalizer reads.)
- Bound-run guard + idempotency + on-read `reconcile_story_stage` recovery (the §7 orphaned-worker lesson). A `failed`/`escalate`-without-report run leaves the card in Implementation (light-red + run link from the durable `runs` status).

## 5. Board card DTO + review surface

- `BoardStore.get_board`/`get_card` LEFT JOIN `kb_story_stages(stage='implementation')` + the `runs` table → `implementation_story_stage_id`, `implementation_run_id`, `implementation_run_status` (authoritative from durable state → card lock/failed derivation).
- **`GET /api/workbench/boards/{app_uuid}/cards/{story_id}/implementation/report`** → `{report_html, rollback_md, run_id, run_status, objects:[…]}` (read from the story-stage's bound artifacts). Served for a card in **Implementation** or **Code Review** (read-only; no chat, no Lavish).

## 6. Wiring + tests

- Construct the finalizer in `api/app.py` (attach as an observer + a recovery-only instance for on-read reconcile, like `StoryDesignFinalizer`). The `author_wiki` program path uses `ObjectWikiStore` + `CollaborationService` (42-06).
- Tests: the start endpoint (fail-fast matrix incl. no-design/no-TD; move+launch+bind); the finalizer (done → code-review audited; send-back → design-review; bound-run guard; on-read recovery); `ObjectWikiStore` (upsert idempotent; append-only; history); the review-surface API; +bump every `current_version == 20` test.

## 7. Out of scope

The web (42-07); the collab bindings + Hub record type (42-06); the workflow (42-04).
