# 32-01 — Data model & ADR (lock the schema + contracts)

> **Status:** 🟡 DRAFTED — docs only; gate = user sign-off → build. · Part of Phase 32. Repo: **genesis** (planning). · **Depends on:** ADR-059 (the canonical backlog), ADR-050/25-11 (the `Story`/`Stage` domain), m0014 (`row_version`).

## Purpose

Lock the exact persistence schema, the finalize marker, the backlog→rows mapping, the API contract, and the
domain entities so 32-02/32-03 build without re-deciding. Draft **ADR-060**. **No code.**

## Migration m0016 (`stories`)

`genesis/db/migrations/m0016_stories.py` — `CREATE TABLE IF NOT EXISTS` (idempotent, forward-only) +
`ALTER TABLE kb_features ADD COLUMN` guarded by a column-existence check; `current_version` 15 → **16**.

```sql
CREATE TABLE kb_epics (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  feature_id  INTEGER NOT NULL REFERENCES kb_features(id) ON DELETE CASCADE,
  key         TEXT,                    -- backlog epic id (e.g. "epic-1"), provenance
  title       TEXT NOT NULL,
  description TEXT,
  workstream  TEXT,                    -- the TD functional workstream (nullable)
  position    INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX ix_kb_epics_feature ON kb_epics(feature_id);

CREATE TABLE kb_stories (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  feature_id          INTEGER NOT NULL REFERENCES kb_features(id) ON DELETE CASCADE,
  epic_id             INTEGER REFERENCES kb_epics(id) ON DELETE SET NULL,   -- parent (nullable)
  key                 TEXT,            -- backlog story id, provenance
  title               TEXT NOT NULL,
  story_type          TEXT NOT NULL DEFAULT 'Story',   -- 'Story' | 'Task'
  category            TEXT NOT NULL DEFAULT 'core',     -- 'core' | 'nice-to-have'
  appian_part         TEXT,
  description         TEXT,
  acceptance_criteria TEXT,            -- JSON array (Gherkin lines / criteria)
  dev_note_ref        TEXT,
  questions           TEXT,            -- JSON array
  labels              TEXT,            -- JSON array
  status              TEXT NOT NULL DEFAULT 'design',   -- forward-compat (STORY_STAGE start); NOT surfaced
  position            INTEGER NOT NULL DEFAULT 0,
  row_version         INTEGER NOT NULL DEFAULT 0,
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL
);
CREATE INDEX ix_kb_stories_feature ON kb_stories(feature_id);
CREATE INDEX ix_kb_stories_epic ON kb_stories(epic_id);

ALTER TABLE kb_features ADD COLUMN stories_finalized_at TEXT;   -- one-time marker (guard the add)
```

**JSON columns** (`acceptance_criteria`/`questions`/`labels`) store `json.dumps([...])`; the store
serializes/deserializes at the boundary (tolerant of NULL → `[]`). Rationale: preserves list structure
losslessly + matches the backlog shape; no relational over-modeling for v1.

## Backlog → rows mapping (finalize)

Source = `_parse_embedded_backlog(_current_stage_html(breakdown_row))` (the finalized, chat-edited sandbox
`breakdown.html`; the same lossless source the Jira export uses). For each `epic` (in order) → a `kb_epics`
row (`key=epic.id`, `title`, `description`, `workstream=epic.workstream`, `position=i`); for each `story` in
`epic.stories` (in order) → a `kb_stories` row: `key=story.id`, `title`, `story_type=story.storyType`
(default 'Story' if absent/invalid), `category=story.category` (default 'core'), `appian_part=story.appianPart`,
`description`, `acceptance_criteria=json(story.acceptanceCriteria or [])`, `dev_note_ref=story.devNoteRef`,
`questions=json(...)`, `labels=json(...)`, `status='design'`, `position=j`. Empty/garbled backlog → **422**
(do not finalize an empty set).

## `stories_finalized_at` — the one-time marker

Set to the ISO timestamp inside the finalize transaction. Finalize is **409** if it is already set (even if a
user later deletes all stories — the marker, not the row count, gates re-finalize). No un-finalize path.

## API contract

| Method & path | Body / result | Notes |
|---|---|---|
| `POST /features/{id}/stages/breakdown/finalize` | → `{ finalized_at, epics: n, stories: n, tasks: n }` | 409 if breakdown not `completed` or already finalized; 422 if the embedded backlog is missing/garbled |
| `GET /features/{id}/stories` | → `{ finalized_at, epics: Epic[], stories: Story[] }` | stories carry `epic_title`; epics for the parent dropdown |
| `POST /features/{id}/stories` | `StoryCreate` → `Story` | appended `position`; `status='design'` |
| `GET /features/{id}/stories/{story_id}` | → `Story` | 404 if not in this feature |
| `PATCH /features/{id}/stories/{story_id}` | `StoryUpdate` (+ `row_version`) → `Story` | **409** `StaleWriteError` on CAS mismatch; may set `epic_id` (validated to belong to the feature or null) |
| `DELETE /features/{id}/stories/{story_id}` | → 204 | |

`GET /features/{id}` (feature detail) additionally returns `stories_finalized_at`. No epic write routes this
phase.

## Domain entities (promote to live)

`genesis/domain/entities.py` — extend `Story` to the real fields (id, feature_id, epic_id, key, title,
story_type, category, appian_part, description, acceptance_criteria, dev_note_ref, questions, labels, status,
position, row_version, created_at, updated_at) + add an `Epic` dataclass + `from_row` mappers (tolerant of
extra keys, never mutate input). Keep the `STORY_STAGE_TRANSITIONS` machine reserved (unused UI this phase).

## Deliverable

This spec (the locked schema/contract above) + **ADR-060 drafted (Proposed)** in `reference/decision-log.md`.
No implementation.

## Gate

⭐ User sign-off on the schema + contract → proceed to 32-02.
