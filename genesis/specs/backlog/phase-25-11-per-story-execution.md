# 25-11 — Per-Story Execution & WorkflowRun Linkage

- **Status:** 🅱️ BACKLOG (moved out of the active Phase 25 on 2026-08-18) · **Review items:** §F (parallel story execution), §17, §26 · **Repos:** genesis (+ possible **m0015**), web · **Depends on:** 25-01 (Story/Stage entities), 25-08 (optimistic locking)
- **Why backlog:** this is **new product capability**, not code-review remediation. It executes concepts that **do not exist in the app today**: (a) a **Breakdown artifact that produces Stories**, and (b) **per-stage agent workflows** (Design/Implement/Review/Deploy/Verify) to attach to each story stage — both are placeholders (ADR-044). 25-01 pre-defines the `Story`/`Stage`/`Artifact` types so this becomes a clean pickup, but end-to-end story execution is **not acceptance-testable** until those product pieces land. Building the tables/service/supervisor speculatively now would be "building ahead of the product" (review §36). **Unblock trigger:** the Breakdown step (Feature → Stories) + at least one per-stage workflow exist.

## 1. Goal
Make the **Story** a real, persisted, independently-executable unit: a Feature decomposes into Stories, each Story has its own stage lifecycle (Design→Implementation→Code-Review→Deployment→Verification→Done), and **multiple stories progress concurrently** without corrupting Feature state — linking each story stage to the workflow runs that drive it.

## 2. Why (review evidence)
- **§F "Parallel story execution":** rated **Very Hard today** — no `Story` entity, no per-story workflow-run linkage, no concurrency model.
- **§17:** the explicit product scenario (Story A/B/C under different developers) must progress independently.
- **§26 UX:** the frontend must support stories progressing independently — *not* a single linear Feature-stage pipeline after Breakdown.

## 3. Current state (cited)
- **No Story concept** (`grep story` = 0). Features have a single Spec + placeholder Design/Breakdown (ADR-044).
- `chat_run_links` (m0004) links a chat session to workflow runs (copilot) — a precedent for entity↔run linkage, but nothing links a *story stage* to a run.
- `RunManager` runs are standalone; the supervisor observes gates/terminal for chat-linked runs.

## 4. Design (builds strictly on 25-01)
### 4.1 Persistence (m0015 — additive)
- `kb_stories` (FK → `kb_features ON DELETE CASCADE`, intrinsic-to-feature like Phase-20 features), `kb_story_stages` (per-story stage rows with `LifecycleState` + `ArtifactKind`), and `story_stage_runs` (links a story stage to `run_events`' `run_id`, mirroring `chat_run_links`).
- Row-version columns from 25-08 on the new tables. `current_version` → 15 (bump version tests).

### 4.2 Domain + service
- `Story`/`StoryStage` entities (defined in 25-01) become live; a `StoryService` (in `genesis/services/`) owns decompose-feature-into-stories, start-a-stage (launches the stage's workflow via `RunManager`, records `story_stage_runs`), and advance-on-completion (the supervisor signals stage terminal → `LifecycleService.transition`).
- **Concurrency:** each story stage transition is a CAS (25-08); the Feature's aggregate view is *derived* from its stories (never a mutable shared field), so parallel story progress can't corrupt Feature state (§17). Stage starts get an idempotency key (25-08) to prevent double-launch (§17 double-submission).

### 4.3 Execution model
- A story stage that is agent-driven starts a workflow run (ADR-001 preserved — LangGraph still owns the run); the `ChatRunSupervisor` pattern is generalized to a `StageRunSupervisor` that, on `run.final`, calls `LifecycleService.transition(story_stage, "complete")`. No new orchestration engine — reuses `RunManager` + the event bus.

### 4.4 API (review §9 — job-returning async ops)
```
POST /api/features/{id}/breakdown            → creates stories (from the Breakdown artifact)
GET  /api/features/{id}/stories              → stories + per-stage state (derived aggregate)
POST /api/stories/{id}/stages/{stage}/start  → 202 {run_id}   (idempotent)
GET  /api/stories/{id}                       → story + stages + linked run ids
```

### 4.5 Web (review §26)
- Feature page renders **Story A/B/C rows, each an independent Design→Implement→Review→Deploy→Verify pipeline** — *not* a single linear feature-stage bar. Each stage shows its `LifecycleState` + a link to its run(s). Polling/streaming reuses the existing run SSE.

## 5. Files touched
- **New:** `db/migrations/m0015_stories.py`, `genesis/services/story_service.py`, `runs/stage_supervisor.py`, `api/stories.py` (`register_stories_routes`), `web/src/features/features/StoriesPanel/**`, tests.
- **Edit:** `domain/entities.py` + `domain/transitions.py` (activate Story/StoryStage tables), `api/features.py` (breakdown→stories), the feature page.

## 6. Tests
- Domain: story-stage transition table (Design→…→Done); illegal transitions rejected.
- Concurrency: two stages of two stories advance in parallel; Feature aggregate stays consistent; no lost update (25-08).
- Linkage: starting a stage records a `story_stage_runs` row; run terminal advances the stage exactly once (idempotent supervisor).
- Web: multiple story pipelines render + advance independently (RTL + jest-axe).

## 7. Risks & mitigations
- **Risk:** biggest sub-phase; depends on 25-01 + 25-08 being solid. **Mitigation:** sequence last in Phase 3; gate on those two shipping.
- **Risk:** re-introducing a mutable Feature status. **Mitigation:** Feature aggregate is **derived** from stories, never stored as a branchy field.
- **Risk:** supervisor double-advance. **Mitigation:** idempotent transition keyed by `(story_stage, run_id)`.

## 8. Out of scope
Authoring the Breakdown artifact's *content* + the per-stage agent workflows themselves (that's later product work — this builds the execution substrate); cross-story dependency ordering (a follow-up).

## 9. Definition of Done
Stories persisted + typed; per-story stage lifecycle enforced via `LifecycleService`; stages launch + auto-advance via `RunManager`/supervisor; parallel stories proven non-corrupting under test; web renders independent story pipelines; m0015 + version tests bumped; genesis release CI-green; bible/tracker/progress updated.
