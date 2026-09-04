# 33-02 — Backend: the board store + the Workbench API

> **Status:** 🟡 DRAFTED. · Part of Phase 33. Repo: **genesis** (backend + m0017). · **Depends on:** 33-01 (locked schema/contract), ADR-060 (`StoryStore`), ADR-050 (`LifecycleState`/domain), m0014 (`row_version`).

## Purpose

Build the persistence + API for the Workbench: the m0017 migration, a `BoardStore`, the `/api/workbench` routes,
and the two new `LifecycleState` members + the reconciled (unwired) `STORY_STAGE` table. Fully tested. **No web.**

## Migration

- `genesis/db/migrations/m0017_workbench.py` — the two tables from 33-01 (`CREATE TABLE IF NOT EXISTS` +
  indexes); `Migration(version=17, name="workbench", up=_up)`; register in `migrations/__init__.py`;
  `current_version` → **17**.
- **Bump every `current_version == 16` test to 17** (test_db + the store suites; the §7 lesson) and add the
  `workbench_boards`/`kb_board_cards` row assertions to `test_db`. `test_db`'s synthetic next-migration bumps
  17 → 18.

## Domain

- `domain/enums.py::LifecycleState` += `TO_DO = "to-do"`, `DESIGN_REVIEW = "design-review"`.
- A canonical **`STORY_LANES`** list (the 8 status values, in order) in `domain/` — the single source for lane
  order + validation; exported from `domain/__init__.py`.
- `domain/transitions.py::STORY_STAGE_TRANSITIONS` reconciled to the 33-01 table (forward-compat only; not
  called by the board). Update `test_transitions`.

## `BoardStore` (`genesis/kb/boards.py`, exported from `kb/__init__.py`)

Mirrors `StoryStore`'s shape (a `Database` + `tx()`; ISO timestamps; tolerant JSON at the boundary via the
reused story mappers). Methods:

- `list_boards() -> [Board]` — every `workbench_boards` row joined to the app name (via `KbStore`) + per-lane
  counts (`GROUP BY kb_stories.status` over the board's cards) + total.
- `available_applications() -> [{app_uuid, name}]` — tracked apps (from `KbStore.list_applications`) **minus**
  those already in `workbench_boards`.
- `add_board(app_uuid) -> Board` — validate the app is tracked (else `UnknownEntityError`/400-mapped);
  **409 `AlreadyExistsError`** if a board exists (UNIQUE); insert; return the (empty) board.
- `remove_board(app_uuid)` — delete the `workbench_boards` row (cascade removes cards). 404 if absent.
- `get_board(app_uuid) -> {app, lanes, cards}` — the board's cards = a JOIN `kb_board_cards ⋈ kb_stories ⋈
  kb_epics(title)` scoped to the app's features, each carrying `lane`(=status), `board_position`, `row_version`,
  `epic_title`, `feature_id` + `feature_name`; lanes = `STORY_LANES` with counts.
- `importable(app_uuid) -> grouped` — all `kb_stories` whose `feature.app_uuid == app_uuid` **and**
  `feature.stories_finalized_at is not null` **and** the story has **no** `kb_board_cards` row on this board,
  grouped by feature → epic.
- `import_stories(app_uuid, story_ids) -> {added, skipped, cards}` — **one tx**: for each id, verify it belongs
  to the app (via feature→app) + is finalized; skip if already carded; else insert a card (append
  `board_position` within its current lane) + set `kb_stories.status='to-do'` (bump `row_version`). Return
  counts + the new cards. Ignore unknown/foreign ids (report as skipped) — never partial-fail the batch.
- `move_card(app_uuid, story_id, lane, position, expected_version) -> Card` — validate `lane ∈ STORY_LANES`
  (else `ValueError`→400); set `kb_stories.status=lane` via the **`row_version` CAS** primitive (reuse
  `StoryStore._cas_update` pattern → `StaleWriteError`→409) + set `board_position`. Free movement (no
  transition check).
- `remove_card(app_uuid, story_id)` — delete the card row (404 if absent); story untouched.

`_validate_app_story(app_uuid, story_id)` guards ownership (story→feature→app). Reuse `StoryStore` for the
canonical story row → DTO.

## API (`genesis/api/workbench.py`, `register_workbench_routes(app, settings, ...)`)

- Instantiate `boards = BoardStore(settings.db_path)` (+ the `KbStore`/`StoryStore` it needs); register in
  `api/app.py` alongside the features router. All routes on the `/api` router (ADR-028).
- Routes = the 33-01 contract. Pydantic models: `AddBoard {app_uuid}`, `ImportCards {story_ids: list[int]}`,
  `MoveCard {lane: str, position: int | None, row_version: int}`. Map store errors → HTTP (`AlreadyExistsError`
  →409, `StaleWriteError`→409, `UnknownEntity`/missing→404, bad lane/untracked→400).
- Lane list surfaced to the client via `GET /workbench/boards/{app_uuid}` `lanes` (so the web renders columns
  from the backend order — no client/server drift).

## Cascade on untrack

Ensure **untracking an application removes its board + cards.** If the m0017 FK (`workbench_boards.app_uuid →
kb_applications ON DELETE CASCADE`) is viable (33-01 FK note), the DB does it; otherwise add an explicit
`DELETE FROM workbench_boards WHERE app_uuid=?` to `KbStore.untrack_application` (which already cleans up
`kb_features`). A regression test asserts board+cards vanish on untrack.

## Tests (`tests/test_workbench_api.py` + `tests/test_board_store.py`)

- migration: fresh DB → v17; the two tables exist; `test_db` assertions + count bump.
- add/remove board (409 on dup; 404 on remove-absent; available-apps excludes added; untracked app → 400).
- importable: only finalized, app-scoped, not-already-carded stories; grouped by feature/epic.
- import batch: sets `status='to-do'` + creates cards; skips on-board + foreign ids (reports skipped); one tx.
- move: persists `status`; **409 on `row_version` mismatch**; **400 on a bad lane**; free movement across
  non-adjacent lanes works.
- remove card: deletes membership, story + status preserved; still in `StoryStore.list_for_feature`.
- untrack app → board + cards cascade-deleted.
- counts: `GET /workbench/boards` per-lane counts match.

## Gates

`cd genesis && .venv/bin/python -m pytest -q -p no:warnings` + `ruff check genesis`. Local commit (no push).

## Gate

Independent review = SHIP → 33-03.
