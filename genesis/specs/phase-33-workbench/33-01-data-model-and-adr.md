# 33-01 — Data model & ADR (lock the schema, the lane model + contracts)

> **Status:** 🟡 DRAFTED — docs only; gate = user sign-off → build. · Part of Phase 33. Repo: **genesis** (planning). · **Depends on:** ADR-060 (`kb_stories`/`StoryStore` + the `status` seam), ADR-050/25-11 (the `Story`/`Stage` domain + `STORY_STAGE_TRANSITIONS`), m0014 (`row_version`), ADR-042 (app→feature cascade), ADR-049 (nav).

## Purpose

Lock the exact persistence schema, the lane model + the `LifecycleState`/`STORY_STAGE` reconciliation, the API
contract, and the card/board DTO shapes so 33-02/33-03 build without re-deciding. Draft **ADR-061**. **No code.**

## Migration m0017 (`workbench`)

`genesis/db/migrations/m0017_workbench.py` — `CREATE TABLE IF NOT EXISTS` (idempotent, forward-only);
`current_version` 16 → **17**. (No `kb_stories` change — the `status` column exists since m0016.)

```sql
CREATE TABLE workbench_boards (            -- the curated set of apps added to the Workbench (1 board/app)
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  app_uuid    TEXT NOT NULL UNIQUE REFERENCES kb_applications(app_uuid) ON DELETE CASCADE,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE kb_board_cards (              -- which stories are on a board + per-lane order (lane = story.status)
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  board_id       INTEGER NOT NULL REFERENCES workbench_boards(id) ON DELETE CASCADE,
  story_id       INTEGER NOT NULL REFERENCES kb_stories(id) ON DELETE CASCADE,
  board_position INTEGER NOT NULL DEFAULT 0,
  added_at       TEXT NOT NULL,
  UNIQUE(board_id, story_id)
);
CREATE INDEX ix_kb_board_cards_board ON kb_board_cards(board_id);
CREATE INDEX ix_kb_board_cards_story ON kb_board_cards(story_id);
```

> **FK note (33-02 to confirm against the live schema):** `kb_applications` is keyed by its Appian `app_uuid`
> (the same key `kb_features` links to). 33-02 confirms the exact column/PK name; if `kb_applications` has no
> usable PK/UNIQUE on `app_uuid` for a FK, fall back to an **unconstrained `app_uuid TEXT`** + an
> application-exists check in `BoardStore.add_board` and an explicit board-cleanup in `KbStore.untrack_application`
> (mirroring how `kb_features` is cleaned up). Either way: **untracking an app removes its board + cards.**

**No lane column** on `kb_board_cards` — a card's lane is read from `kb_stories.status` (the locked "lane =
status" decision). `board_position` orders cards **within** a lane (the frontend groups by status, orders by
`board_position`).

## The lane model

Eight lanes, fixed order (the locked decision):

| # | Lane (UI) | `status` value |
|---|---|---|
| 1 | To Do | `to-do` |
| 2 | Design | `design` |
| 3 | Design Review | `design-review` |
| 4 | Implementation | `implementation` |
| 5 | Code Review | `code-review` |
| 6 | Verification | `verification` |
| 7 | Deployment | `deployment` |
| 8 | Done | `done` |

- **`domain/enums.py::LifecycleState`** gains `TO_DO = "to-do"` and `DESIGN_REVIEW = "design-review"` (the other
  six already exist).
- A canonical **`LANES`** ordering (list of the 8 status values, in order) is the single source of truth for
  order + validation. Define it once in the domain (`domain/` — e.g. `STORY_LANES`) and **mirror** it in a web
  constant (`features/workbench/lanes.ts`) with the display labels + lane tone. A move's target lane is
  validated ∈ `LANES` (else 400).
- **`domain/transitions.py::STORY_STAGE_TRANSITIONS`** is reconciled to the new order (forward-compat, **NOT
  enforced on drag** this phase — recorded in ADR-061 as a deliberate relaxation):

  ```
  to-do        --start-design-->    design
  design       --submit-->          design-review
  design-review--approve-->         implementation
  design-review--request-changes--> design
  implementation--submit-review-->  code-review
  code-review  --approve-->         verification
  code-review  --request-changes--> implementation
  verification --verify-->          deployment
  verification --reject-->          implementation
  deployment   --deployed-->        done
  ```

  > The exact action names + rework edges will be **finalized when the per-lane automation is built** (a future
  > phase); this table is the forward-compat target, not wired to the board this phase. Bump the
  > `test_transitions` fixtures accordingly (the states change).

## Import & move semantics

- **Import** (`POST …/cards`): for each `story_id` (validated to belong to the board's app, and finalized),
  create a `kb_board_cards` row (append `board_position`) and set `kb_stories.status='to-do'` — in **one
  transaction**; already-on-board ids are **skipped** (idempotent). Un-imported stories keep their m0016
  default (`design`).
- **Move** (`PATCH …/cards/{story_id}`): set `kb_stories.status = lane` (validated ∈ `LANES`) via `StoryStore`'s
  **`row_version` CAS** (→ 409 `StaleWriteError` on a concurrent edit) + update `board_position`. **Free
  movement** — no transition-table check this phase.
- **Remove** (`DELETE …/cards/{story_id}`): delete the `kb_board_cards` row only; `kb_stories` untouched (the
  story keeps its status + stays in the Stories tab).

## API contract

| Method & path | Body / result | Notes |
|---|---|---|
| `GET /workbench/boards` | → `Board[]` `{app_uuid, app_name, counts:{lane→n}, total}` | powers the landing sub-tabs |
| `GET /workbench/applications/available` | → `{app_uuid, name}[]` | tracked apps not yet added |
| `POST /workbench/boards` | `{app_uuid}` → `Board` | **409** if already added; **404/400** if the app isn't tracked |
| `DELETE /workbench/boards/{app_uuid}` | → 204 | cascade removes cards; stories untouched |
| `GET /workbench/boards/{app_uuid}` | → `{app_uuid, app_name, lanes: LaneMeta[], cards: Card[]}` | `Card` = story fields + `epic_title` + `feature_id`/`feature_name` + `lane`(=status) + `board_position` + `row_version` |
| `GET /workbench/boards/{app_uuid}/importable` | → `{ features: [{feature_id, feature_name, epics:[{epic_title, stories: Story[]}]}] }` | finalized stories not on the board, grouped |
| `POST /workbench/boards/{app_uuid}/cards` | `{story_ids:[]}` → `{added:n, skipped:n, cards:Card[]}` | one tx; skip on-board; validate app ownership; set `status='to-do'` |
| `PATCH /workbench/boards/{app_uuid}/cards/{story_id}` | `{lane, position?, row_version}` → `Card` | lane ∈ `LANES` (else 400); **409** CAS mismatch |
| `DELETE /workbench/boards/{app_uuid}/cards/{story_id}` | → 204 | membership only |

All under the `/api` prefix (ADR-028). Errors: 400 (bad lane / untracked app), 404 (no board / card / app),
409 (already added / CAS), 422 (empty body where required).

## DTO shapes (web `types/workbench.ts`)

`Board {app_uuid, app_name, counts, total}` · `LaneMeta {key, label, count}` · `Card { …Story fields, epic_title?, feature_id, feature_name, lane, board_position, row_version }` · `ImportableGroup {feature_id, feature_name, epics:[{epic_title, stories: Story[]}]}`. `Story` reuses the Phase-32 type.

## Deliverable

This spec (the locked schema / lane model / contract above) + **ADR-061 drafted (Proposed)** in
`reference/decision-log.md`. No implementation.

## Gate

⭐ User sign-off on the schema + lane model + contract → proceed to 33-02.
