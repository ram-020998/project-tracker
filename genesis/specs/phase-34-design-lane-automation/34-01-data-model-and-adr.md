# 34-01 — Data model & ADR (per-story artifact store, the automation model, ADR-062)

> **Status:** ✅ SHIPPED (genesis v0.62.0 + genesis-workflows v0.16.0). · Part of Phase 34. Repo: **genesis** (planning). · **Depends on:** ADR-061 (the Workbench board + `kb_stories.status` lanes), ADR-057 (m0015 `kb_feature_stages`/`StageStore` — the model this mirrors), ADR-050/25-08 (`LifecycleService` + m0013 audit + `row_version`), ADR-058 (the grounded design workflow shape).

## Purpose

Lock the exact per-story artifact schema (m0018), the `StoryStageStore` contract, the board-card design-run
DTO additions, the design-start / finalize / audited-transition model, and the `story-design-analysis` I/O
contract — so 34-03/34-04/34-05 build without re-deciding. Draft **ADR-062**. **No code.**

## Migration m0018 (`story_stages`)

`genesis/db/migrations/m0018_story_stages.py` — `CREATE TABLE IF NOT EXISTS` (idempotent, forward-only);
`current_version` 17 → **18**. Mirrors m0015 `kb_feature_stages` at the story grain.

```sql
CREATE TABLE kb_story_stages (              -- per-(story, stage) artifact row; this phase: stage='design'
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  story_id        INTEGER NOT NULL REFERENCES kb_stories(id) ON DELETE CASCADE,
  stage           TEXT NOT NULL,            -- 'design' (future: 'implementation', 'code_review', …)
  status          TEXT NOT NULL DEFAULT 'draft',  -- draft → in-progress → in-review → completed
  html_path       TEXT,                     -- last saved milestone artifact on disk
  content_hash    TEXT,
  chat_session_id TEXT,                      -- the bound completion chat (design review)
  run_id          TEXT,                      -- the design run currently bound to this stage
  source_doc_path TEXT,                      -- unused this phase (parity with StageStore)
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL,
  row_version     INTEGER NOT NULL DEFAULT 0,
  UNIQUE(story_id, stage)
);
CREATE INDEX ix_kb_story_stages_story ON kb_story_stages(story_id);

CREATE TABLE kb_story_stage_revisions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  story_stage_id INTEGER NOT NULL REFERENCES kb_story_stages(id) ON DELETE CASCADE,
  n              INTEGER NOT NULL,
  html_path      TEXT,
  content_hash   TEXT,
  created_at     TEXT NOT NULL
);
CREATE INDEX ix_kb_story_stage_revs_stage ON kb_story_stage_revisions(story_stage_id);
```

- **No `kb_stories` change** — the card lane stays `kb_stories.status`; the design run/artifact live here.
- **Cascade:** a story deleted (or its app untracked → feature cascade → story cascade, ADR-042) removes its
  story-stages + revisions. Removing a card from the board (Phase 33 `remove_card`) does **not** touch
  `kb_story_stages` (membership only) — 34-04 decides whether remove-from-board also clears a design run (see
  Open items).

## `StoryStageStore` contract (`genesis/kb/story_stages.py`)

Mirrors `StageStore` (m0015), at the story grain. Injected a `Database`; never opens ad-hoc write connections;
never creates tables.

| Method | Purpose |
|---|---|
| `get_or_create(story_id, stage, *, ...) -> dict` | idempotent row for `(story_id, stage)` |
| `get(story_stage_id) -> dict\|None` · `get_for_story(story_id, stage) -> dict\|None` | reads |
| `set_status(id, status)` | draft→in-progress→in-review→completed |
| `set_source(id, *, source_doc_path=None, run_id=...)` | bind the run at launch |
| `set_html(id, *, html_path, content_hash)` | point at the artifact |
| `set_chat_session(id, session_id)` | bind the completion chat |
| `add_revision(id, ...)` · `list_revisions(id)` | milestones |
| `reset_for_reupload(id)` | clear chat/run/html/source (+ status→in-progress) for a **re-run** (updates in place — decision Q9) |

`set_html`/`set_chat_session`/`set_status` use the **`row_version` CAS** → `StaleWriteError` (409), like
`StageStore`.

## Board-card design-run DTO additions (34-04)

`BoardStore.get_board`/`get_card` `Card` gains (via LEFT JOIN `kb_story_stages` on `stage='design'` + the
`runs` table on `run_id`):

- `design_run_id: str | null` — the bound design run (for the card's run link).
- `design_run_status: str | null` — the run's status from the `runs` table (`pending`/`running`/
  `awaiting_input:*`/`done`/`failed`/`cancelled`) — **authoritative from durable state** (not a live observer),
  so the card renders running/failed correctly even if a `run.final` was missed (the §7 orphaned-worker lesson).
- `design_chat_session_id: str | null` — the bound completion chat (opens the Design Review workspace).
- `design_status: str | null` — the `kb_story_stages.status` (draft/in-progress/in-review/completed).

**Card lock** (frontend) = `design_run_status ∈ {pending, running, awaiting_input:*}`. **Card failed** =
`design_run_status ∈ {failed, cancelled}` **and** the story is still in the `design` lane.

## Automation model (design-start → finalize → audited transition)

- **Start** (`POST …/cards/{story_id}/design/start`): move the story to `design` (BoardStore, free — no gate),
  `StoryStageStore.get_or_create(story_id,'design')`, **`reset_for_reupload`** if it already has a run/chat
  (Q9 update-in-place), snapshot the feature's current Spec/UX/TD HTML, `run_manager.start("story-design-
  analysis", {...})`, `set_source(run_id=...)`, `set_status('in-progress')`. **Fail-fast 409** on no dev env /
  app not synced / workflow not installed (mirrors `_launch_td`).
- **Finalize** (`StoryDesignFinalizer`, on `run.final{done}`): bound-run guard + idempotency; open the
  `story_design` chat; copy `design.html` → sandbox; `set_html` + `set_chat_session`; `set_status('in-review')`;
  **advance the story lane `design → design-review` via `LifecycleService.transition`** (EntityKind.STORY,
  audited to m0013 — the first audited Workbench transition). On-read `reconcile` recovery.
- **Manual drags stay free** (ADR-061 relaxation persists) — only the automated design→design-review completion
  transition is audited this phase. The confirm-dialog "No" path is a plain free move to `design`.

## `story-design-analysis` I/O contract (for 34-03)

**Inputs:** `{story_id, feature_id, app_uuid, story_stage_id, spec_path, uxdesign_path, techdesign_path,
story}` where `story` = `{key, title, description, acceptance_criteria[], dev_note_ref, appian_part, epic_title,
story_type}` (from `kb_stories`, passed inline; also written to `story.json` in the blackboard).
**Output artifact:** `design.html` (Lavish-safe; `<section>` per object with a NEW/UPDATE tag + granular change
+ `<pre><code>` code; for process models, per-node explanation + code per node) + `result.json`
`{artifact:'design.html', story_id, story_stage_id, status:'in-review', object_count, verify_verdict}`.
**Finalizer binding:** `story-design-analysis → _Binding(stage='design', artifact='design.html',
chat_mode='story_design', seed=_seed_story_design)` (a story-scoped binding registry, parallel to the
feature-stage `_BINDINGS`). The run inputs carry `story_stage_id` (the bind key), mirroring TD's `stage_id`.

## ADR-062 (draft — Proposed)

Write the ADR-062 block (Proposed) into `reference/decision-log.md` per §9 of the umbrella (decision +
context + alternatives + consequences), amending ADR-061 (per-lane automation begins). Mirror to `bible/04` on
Accept.

## Open items for 34-04 to decide (recorded, not blocking)

1. **Remove-from-board while a design run is bound** — reject with a clear message, or allow + orphan the
   run? (Lean: reject if `design_run_status` is non-terminal.)
2. **A card dragged back to To Do after a failed design** — leave the `kb_story_stages` row (so a later re-run
   updates it) — confirmed by Q9 (one design per story, re-run updates in place).

## Deliverable

This spec (locked m0018 / `StoryStageStore` / DTO / automation model / workflow I/O) + **ADR-062 drafted
(Proposed)**. No implementation.

## Gate

⭐ User sign-off on the schema + automation model + contract → proceed to 34-02.
