# 32-02 — Backend: migration + StoryStore + finalize + CRUD

> **Status:** ✅ SHIPPED (genesis v0.60.0). · Part of Phase 32. Repo: **genesis** (backend + **m0016**). · Gate: independent review = SHIP.

## Purpose

Persist stories: the migration, a `StoryStore`, the one-time **finalize** endpoint, and story CRUD — all
`row_version`-safe, reusing the existing Feature Breakdown parse helpers.

## Migration (`genesis/db/migrations/m0016_stories.py`)

Per 32-01: `kb_epics` + `kb_stories` (`CREATE TABLE IF NOT EXISTS`) + guarded
`ALTER TABLE kb_features ADD COLUMN stories_finalized_at TEXT`; `Migration(version=16, name="stories", up=_up)`;
`current_version` → **16**. Register in the migrations package. **Bump every hardcoded `current_version == 15`
assertion** to 16 (the §7 schema-bump lesson) — grep the tests first.

## `StoryStore` (`genesis/kb/stories.py`)

Mirrors `FeatureStore`/`StageStore` (a `Database` + row→dict boundary):
- `finalize(feature_id, backlog: dict) -> dict` — in one `tx()`: insert epics + stories (order-preserving
  `position`; `status='design'`), set `kb_features.stories_finalized_at`. Returns counts. Raises
  `AlreadyFinalizedError` if the marker is set. (Parsing/precondition live in the API layer; the store takes a
  parsed backlog.)
- `list_for_feature(feature_id)` → `{finalized_at, epics, stories}` (stories joined with `epic_title`).
- `list_epics(feature_id)` (for the dropdown).
- `get_story(feature_id, story_id)` / `create_story(feature_id, data)` / `update_story(feature_id, story_id,
  data, row_version)` (**`_cas_update`** → `StaleWriteError` like `FeatureStore`) / `delete_story(...)`.
- `epic_id` on create/update is validated to belong to `feature_id` (or NULL) → else a 400.
- JSON columns (de)serialized here; `updated_at` + `row_version += 1` on every write.

## API (`genesis/api/features.py`)

- **Finalize:** `POST /features/{id}/stages/breakdown/finalize` — resolve the feature + its `breakdown` stage
  (`StageStore`); **409** if the stage is absent / not `completed`, or if `stories_finalized_at` is set;
  read `_current_stage_html(breakdown_row)` → `_parse_embedded_backlog` → **422** if None/empty; call
  `StoryStore.finalize`; record a lifecycle/activity event (m0013); return the summary.
- **CRUD:** the six routes from 32-01 (`GET/POST /features/{id}/stories`, `GET/PATCH/DELETE
  /features/{id}/stories/{story_id}`). `PATCH` threads `row_version` → 409 on `StaleWriteError`. Pydantic
  `StoryCreate`/`StoryUpdate` request models (partial for PATCH). Reject `DELETE`/CRUD writes are allowed even
  when finalized (stories are the live source of truth) — only **finalize** is one-time.
- **Feature detail:** include `stories_finalized_at` in the `GET /features/{id}` response (thread it through
  `FeatureStore`/the detail serializer).

## Domain (`genesis/domain/entities.py`)

Promote `Story` to the real fields + add `Epic` + `from_row` mappers (32-01). No transition wiring (status is a
plain default this phase).

## Tests (`tests/test_features_api.py` + a store test)

- Migration: fresh DB upgrades to **v16**; `kb_epics`/`kb_stories` exist; `kb_features.stories_finalized_at`
  present; re-run idempotent. Update `current_version` assertions 15→16.
- Finalize: a completed breakdown with an embedded backlog → epics/stories persisted (counts + a sample row's
  fields incl. `status='design'`, JSON round-trip of AC/labels); **409** when breakdown not completed; **409**
  on re-finalize; **422** on a stage whose HTML has no embedded JSON.
- CRUD: create/get/list (grid shape incl. `epic_title`); PATCH edits fields incl. reassigning `epic_id`
  (+ a cross-feature epic_id → 400); PATCH with a stale `row_version` → **409**; delete; list reflects deletes.
- Cascade: deleting the feature (or untracking the app) cascades epics + stories.

## Gates

genesis pytest + `ruff check genesis`. No web change here.

## Gate

Independent review = SHIP: one-time marker correct (survives delete-all); parse-from-canonical-JSON fidelity;
`row_version` CAS; epic_id validation; cascade; `current_version` tests bumped.
