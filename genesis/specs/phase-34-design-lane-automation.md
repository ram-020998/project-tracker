# Phase 34 — Design Lane Automation (the Workbench Design + Design Review lanes)

> **Status:** ✅ **SHIPPED — PHASE 34 COMPLETE (2026-09-05)** · genesis v0.62.0 + genesis-workflows v0.16.0, CI green. ADR-062 **Accepted**. As-built: `progress/phase-34-design-lane-automation.md`. Umbrella + `phase-34-design-lane-automation/34-01..34-07`. · **Author:** Genesis agent
> **Type:** multi-repo — **genesis** (backend + web + one migration **m0018**) + **genesis-workflows** (the new `story-design-analysis` workflow; remove `design-doc`). genesis-core / kiro-agent-sdk / genesis-appian-parser **unchanged** (reuse `kiro_node` + `attach_reliability`). · **Depends on:** Phase 33 (the Workbench board — `BoardStore` + `/api/workbench` + `kb_stories.status` lanes + `@dnd-kit` board; ADR-061), Phase 32 (finalized `kb_stories`/`kb_epics`; ADR-060), Phase 30 (the grounded, workstream-decomposed `technical-design-analysis` workflow + the generalized `StageFinalizer` `_BINDINGS` registry + `_current_stage_html`/`_launch_td`; ADR-058), Phase 29 (the per-`(feature,stage)` artifact model **m0015** `StageStore` + the annotatable stage workspace `StageArtifactWorkspace`/`AnnotatablePreviewDialog`/`StageBuilderPage` + `ChatModeProfile`; ADR-057), Phase 20/21 (spec authoring + the vendored Lavish review + `feature_spec` chat; ADR-042/043/045), Phase 25-01/08 (`LifecycleService` + `STORY_STAGE_TRANSITIONS` + m0013 audit + `row_version` CAS; ADR-050).

---

## 1. Why this phase exists

Phase 33 shipped **the Workbench** — a per-application Kanban board over finalized stories with eight lanes —
but every lane is inert: a drag just persists `kb_stories.status`. ADR-061 explicitly deferred the **per-lane
automation** ("dragging into Design kicks off the design workflow… gated moves + m0013 audit arrive with the
per-lane automation") to a future phase.

**This phase is that future phase, for the first two lanes: Design and Design Review.** Moving a ticket into
**Design** offers to run an automated, grounded **ticket-level design workflow** that writes an object-level,
code-level design document for that one story; on success the card advances to **Design Review**, where the
user opens a full-page workspace (the same chat + annotatable-preview experience as the Spec / Technical Design
stages) to review, comment, and have the agent revise the design.

This is the pattern every later lane (Implementation, Code Review, Verification, Deployment) will follow, so
this phase also lays the reusable seam: a **per-story artifact model** (m0018, mirroring the per-feature-stage
m0015) and a **story run→artifact finalizer** (mirroring the `StageFinalizer`).

---

## 2. Goal

1. **Remove the old `design-doc` workflow** from the library (genesis-workflows) **and** from the running app's
   local library — it is superseded by the ticket-level design workflow and will not be used.
2. **A ticket-level design workflow — `story-design-analysis` ("Appian Ticket Design").** Given one story and
   its feature's finalized **Spec + UX Implementation Analysis + Technical Design**, it (a) **gathers** the
   ticket-relevant research from those three documents into a file, then (b) **grounds against the live Appian
   app** (structure via `@genesis-kb`, the ACTUAL code via `@appian-dev`, read-only) and writes an **object-level
   design HTML**: one section per object to be created/updated, each tagged **NEW** or **UPDATE**, with granular
   change detail **and the actual code** to be written/added — including, for process models, a **per-node**
   explanation with the code for any node that needs it. Every agent node wears the ADR-011 reliability trio;
   a **grounded verification critic** re-checks the design (bounded → escalate). Decomposed object-by-object +
   **deterministically assembled** (the Phase-30 "don't emit a huge doc in one turn" lesson).
3. **Drag-into-Design automation.** Dragging a card into the **Design** lane (from ANY lane) opens a confirm
   dialog: **"Start the automated design generation for this ticket?"** **Yes** → move to Design + launch (or
   **re-run**, updating the same design) the workflow; **No** → just move to Design, no run.
4. **Card run states on the board.** While the design run is active the card shows **"Design generation
   running"** + a **link to the run** and is **locked** (non-draggable). On **success** the card **auto-advances
   to Design Review**. On **failure** the card shows a **light-red background** + "Workflow failed" + the run
   link (and is draggable again — the user can re-drag into Design to re-run, or move it back).
5. **The Design Review workspace.** Clicking a card in **Design Review** opens a **full-page** workspace —
   reusing the Spec/TD experience: a **chat** bound to the design + an **annotatable preview** (the vendored
   Lavish SDK). The user's annotations flow to the agent, which **updates the design HTML**. (Leaving Design
   Review — advancing to Implementation — is **out of scope**, a later phase; the user drags it manually.)
6. **The reusable seams:** a per-story artifact store (**m0018** `kb_story_stages`) + a `StoryDesignFinalizer`
   (run→story-artifact bridge), so Implementation / Code Review / etc. plug in the same way later.

**Success = a lead drags a groomed ticket into Design, confirms, watches the card run (with a run link), sees
it auto-advance to Design Review carrying a grounded, object-level, code-level design document, opens the card
full-page, annotates it, and the agent revises the design — the same polished loop as the Spec and Technical
Design stages, now per ticket.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-04)

Firm inputs, not open questions (answers to the 10 planning questions).

1. **Workflow id `story-design-analysis`**, surfaced as **"Appian Ticket Design"**.
2. **Entering Design from ANY lane** shows the confirm pop-up. **Yes** → move to Design + start/**re-run** the
   design; **No** → move to Design only (no run). Re-running from any state is allowed.
3. A card with a **running** design run is **locked** (non-draggable).
4. **Leaving Design Review is out of scope** this phase (a later phase; manual drag for now — no "approve/
   complete" control built).
5. The workflow **grounds against the live app**, so it **fails fast + blocks the launch** with a clear message
   if there is no dev-tagged environment or the app is not synced into the KB (same prerequisite as Technical
   Design).
6. **Code is mandatory wherever there is a code-level change or addition.** **Process models are NOT
   summarized** — for each **node** of a process model, explain what happens, and show the code for any node
   that needs code.
7. Build a **per-story artifact store** (m0018) — a needed, reusable seam.
8. **Uninstall** the `design-doc` workflow from the running app's local library too (not just the repo).
9. **One design per story.** A re-run **updates the same** design (does not create a second).
10. **Failure display:** light-red card + "Workflow failed" + run link.

---

## 4. Current state (what we build on) — code-grounded

- **The Workbench board exists (Phase 33, ADR-061).** `genesis/kb/boards.py::BoardStore` (`get_board` returns
  `cards` where `lane == kb_stories.status`; `move_card`/`reorder_lane` persist the lane with `row_version`
  CAS); `genesis/api/workbench.py` (`register_workbench_routes`); web `features/workbench/` (`BoardPage`
  `@dnd-kit` multiple-containers — `onDragEnd` persists via `useReorderLane`; `StoryCard`/`StoryCardFace`;
  `BoardCardDrawer`; `hooks.ts`). Lanes come from `domain.STORY_LANES` (`to-do · design · design-review ·
  implementation · code-review · verification · deployment · done`).
- **The closest workflow template = `technical-design-analysis` (Phase 30).** Object/workstream map-reduce:
  `resolve_inputs → load_inputs → plan_sections →[v_plan]→ (per-unit ground loop) → (per-unit draft loop) →
  synthesize →[v_synth]→ assemble (DETERMINISTIC) → verify (grounded critic) →[v_verify]→ route_verify →(ok)
  present → cleanup`; reliability trio per agent; `resolve_inputs` fail-fast (dev env + app synced);
  read-only `@genesis-kb` (structure) + `@appian-dev` (real code) allowlists; `recursion_limit` raised;
  `cleanup` deletes tool scratch, preserves artifacts. **This is the shape to mirror, scoped to one story with
  object-level code.**
- **The run→artifact bridge = `StageFinalizer` (Phase 29/30).** `genesis/chat/stage_finalizer.py`: a
  `RunManager` event observer keyed by a `_BINDINGS: {workflow_id → _Binding{stage, artifact, chat_mode, seed}}`
  registry; on `run.final{done}` it opens the completion chat, copies the artifact into the session sandbox,
  binds it to the stage row, and moves the stage to in-review — with a **bound-run guard**, **idempotency**, and
  **on-read `reconcile_stage`** recovery (the §7 orphaned-worker lesson). **Mirror this per story.**
- **The launch/bind pattern = `_launch_td` + `_current_stage_html` (api/features.py).** Snapshots the feature's
  current Spec/UX/TD HTML to files, calls `run_manager.start("technical-design-analysis", {feature_id, app_uuid,
  stage_id, spec_path, uxdesign_path, comment})`, binds `run_id` to the stage row (`stages.set_source`); friendly
  409 when the workflow isn't installed / bad env. **Reuse for the design launch (per story).**
- **The stage artifact model = m0015 `kb_feature_stages` + `StageStore` (Phase 29).** `get_or_create/get/
  set_html/set_status/set_source/set_chat_session/add_revision/reset_for_reupload`; a `ux_design`/
  `technical_design` `ChatModeProfile` + `_STEERING_*`. **m0018 `kb_story_stages` mirrors this per story;** a
  `story_design` chat mode mirrors the completion chats.
- **The review workspace = `StageArtifactWorkspace` + `AnnotatablePreviewDialog` + `StageBuilderPage` (Phase
  29, generalized D0).** Reused `ChatThread` + the vendored Lavish annotate iframe + the postMessage
  annotation→chat bridge. **Reuse for the Design Review full page, bound to the story artifact.**
- **The `design-doc` workflow to remove:** `genesis-workflows/workflows/design-doc/` + its `registry.json`
  entry (functional); doc-only mentions in `genesis/mcp/kb_server.py:14` + `genesis-core/.../reliable.py:4` +
  `web/src/dev/mockups/Mockups.tsx` (non-functional). Nothing pins it at runtime.

**Takeaway:** this phase = remove one workflow + add one workflow (`story-design-analysis`, TD-shaped, object +
code + per-node process-model detail) + one migration (m0018, 2 tables) + a `StoryStageStore` + a
`StoryDesignFinalizer` + a `/api/workbench` design-start endpoint + board-card run-state fields + a web
drag-confirm + card run/lock/failed states + a reused Design-Review full page. genesis-core / SDK / parser
unchanged.

---

## 5. Data model (m0018) — finalized in 34-01

- **`kb_story_stages`** — the per-`(story, stage)` artifact row (mirrors m0015 `kb_feature_stages`): `id PK ·
  story_id FK→kb_stories(id) ON DELETE CASCADE · stage TEXT (this phase: 'design') · status TEXT · html_path ·
  content_hash · chat_session_id · run_id · source_doc_path · created_at · updated_at · row_version ·
  UNIQUE(story_id, stage)`.
- **`kb_story_stage_revisions`** — milestone snapshots (mirrors `kb_feature_stage_revisions`): `id PK ·
  story_stage_id FK ON DELETE CASCADE · n · html_path · content_hash · created_at`.
- `current_version` 17 → **18**. Every `current_version == 17` test bumps with the migration (the §7 lesson).
- **No `kb_stories` change** — the card's lane stays `kb_stories.status`; the design run/artifact live in
  `kb_story_stages` (surfaced on the board card DTO by a LEFT JOIN).

---

## 6. The workflow `story-design-analysis` — finalized in 34-03

Object-level, code-grounded, decomposed + deterministically assembled (mirrors `technical-design-analysis`):

```
START → resolve_inputs → load_inputs
  → gather_context   (agent: read Spec + UX + Technical Design + the story fields; extract ONLY what THIS
                      ticket needs → research.json)                        [v_context]
  → plan_objects     (agent: the objects to touch, each {object, kind, change_type: NEW|UPDATE, why})  [v_plan]
  → start_objects → next_object
       ├─(object) design_object  (agent: ground the object's ACTUAL code via @appian-dev + structure via
       │            @genesis-kb [read-only]; write the object's design block — NEW/UPDATE tag + granular change
       │            + the CODE; for a process model: per-node explanation + code per node)   [v_object]
       │          → advance_object → next_object
       └─(all done) → synthesize (bounded: cross-cutting overview + sequencing/risks only)   [v_synth]
  → assemble  (DETERMINISTIC program: stitch each object block verbatim/once → ONE Lavish-safe HTML doc)
  → verify    (GROUNDED critic: each object's change + code vs the live app + research; bounded → revise/escalate) [v_verify]
  → route_verify →(ok) present → cleanup → END ; →(revise ≤2) synthesize ; →(exhausted) escalate → cleanup → END
```

Inputs: `story_id, feature_id, app_uuid, story_stage_id, spec_path, uxdesign_path, techdesign_path, story` (the
ticket fields). Output artifact: **`design.html`** (Lavish-safe — `<section>` per object, NEW/UPDATE tag,
`<pre><code>` code blocks; no JS). Read-only against Appian. `resolve_inputs` fail-fast on no dev env / app not
synced. `recursion_limit` raised for the object loop.

---

## 7. Backend — finalized in 34-04

- **m0018** + `genesis/kb/story_stages.py::StoryStageStore` (mirrors `StageStore`).
- **`POST /api/workbench/boards/{app_uuid}/cards/{story_id}/design/start`** — validates the card is on the
  board; **moves the story to the `design` lane**; snapshots the feature's current Spec/UX/TD HTML (reusing the
  `_current_stage_html` pattern); launches (or **re-runs** — same story-stage row, `reset` first) the
  `story-design-analysis` run; binds `run_id` to the story-stage row. **Fail-fast 409** with a clear message on
  no dev env / app not synced / workflow not installed.
- **`StoryDesignFinalizer`** — a `StageFinalizer`-style observer bound to `story-design-analysis`: on
  `run.final{done}` → open a **`story_design` completion chat** (seeded with the ticket + artifact), copy
  `design.html` into the sandbox, bind chat + artifact to the story-stage row, set the story-stage to
  **in-review**, and **advance the story lane `design → design-review`** via `LifecycleService.transition`
  (audited, m0013 — the first *gated + audited* Workbench transition, per ADR-061's promise). Bound-run guard +
  idempotency + **on-read `reconcile`** recovery (the orphaned-worker lesson).
- **Board card DTO** gains `design_run_id`, `design_run_status` (derived from the `runs` table via `run_id` —
  authoritative even if a live event was missed), and `design_chat_session_id` (for the workspace) via a LEFT
  JOIN to `kb_story_stages(stage='design')`. **Card lock** = `design_run_status` is non-terminal.

---

## 8. Web — finalized in 34-05

- **Drag confirm:** `BoardPage.onDragEnd` special-cases a card **entering the `design` lane** — instead of
  persisting, open a confirm dialog. **Yes** → `POST …/cards/{id}/design/start`; **No** → the normal lane
  persist. A **locked** card (running design) is not draggable.
- **Card states** (`StoryCard`/`StoryCardFace` + `lanes.ts`): running → a "Design generation running" indicator
  + `Link` to `/runs/{run_id}`; failed → **light-red** card + "Workflow failed" + the run link.
- **Design Review full page:** a new route `/workbench/:appUuid/cards/:storyId` mounting a **reused**
  `StageArtifactWorkspace` (chat + `AnnotatablePreviewDialog`) bound to the story's `design` artifact +
  `story_design` chat; a card in Design Review opens it on click (other lanes keep the drawer). Breadcrumbs +
  types + api + hooks + query keys. jest-axe on the new page + dialog.

---

## 9. ADR

- **ADR-062 (PROPOSED — this phase): Workbench lane automation — the Design & Design Review lanes.** Dragging a
  ticket into **Design** offers (confirm dialog) to run the grounded, object-level, code-level
  **`story-design-analysis`** workflow for that story; on success the card auto-advances to **Design Review**
  (an **audited** `LifecycleService` transition — m0013 — the first per-lane automation ADR-061 promised); the
  Design Review card opens a full-page reused stage workspace (chat + annotatable Lavish preview) that revises
  the design. Adds a **per-story artifact model (m0018 `kb_story_stages`)** + a `StoryDesignFinalizer`
  (run→story-artifact bridge). **Removes** the superseded `design-doc` workflow. **Amends ADR-061** (per-lane
  automation begins; entering Design is a confirmed automated transition + design→design-review is
  workflow-driven & audited; free drag remains for the other, not-yet-automated lanes). Reuses ADR-058
  (grounded workstream-decomposed design + deterministic assemble + grounded critic), ADR-057 (m0015 pattern +
  the stage workspace + StageFinalizer), ADR-050/25-08 (LifecycleService + audit + `row_version`), ADR-011
  (reliability trio), ADR-036/037 (read-only grounding). Multi-repo (genesis + genesis-workflows); genesis-core
  / SDK / parser unchanged. Mirror in `bible/04` on Accept.

---

## 10. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **34-01** | Data model & ADR | Lock m0018 (`kb_story_stages` + revisions) + the `StoryStageStore` contract + the board-card design-run DTO fields + the design-start / finalize / lifecycle-audit model + the workflow I/O contract; **draft ADR-062.** **Docs only.** | ⭐ user sign-off → build |
| **34-02** | Remove `design-doc` | Delete `workflows/design-doc/` + its `registry.json` entry (genesis-workflows; `validate_library` count −1); **uninstall it from the running app's local library**; scrub the doc-only mentions (kb_server.py / reliable.py / Mockups.tsx); bump affected counts/tests. | review clean |
| **34-03** | Workflow `story-design-analysis` | The object-level, code-grounded, per-node-process-model design workflow (map-reduce + reliability trio + grounded verify + deterministic assemble + cleanup) + `workflow.yaml` + `registry.json` entry + tests. | independent review = SHIP |
| **34-04** | Backend automation + finalizer | m0018 (`current_version`→18); `StoryStageStore`; `POST …/cards/{id}/design/start` (move+launch/re-run, fail-fast); `StoryDesignFinalizer` (done→design-review audited + completion chat + on-read recovery); board-card design-run DTO fields + lock derivation; tests (+ bump `current_version` tests). | independent review = SHIP |
| **34-05** | Web: drag / card states / review | Drag-into-Design confirm dialog; card running/locked/failed + run link; the Design Review full-page reused workspace (chat + annotatable preview) + route/breadcrumbs; types/api/hooks; jest-axe. Gates green; `web/static` committed. | independent review = SHIP |
| **34-06** | Code review & hardening | Independent review (finalizer bound-run guard + on-read recovery + audited transition; fail-fast prereqs; re-run updates-in-place; card lock/failed derivation from durable run status; workflow reliability trio + grounded critic + deterministic assemble + process-model per-node code; Lavish-safe HTML; a11y/dark-parity/no-hardcoded-hex; only-nav shell edit); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **34-07** | Release | genesis vX.Y.0 + genesis-workflows vX.Y.0 (coordinated; ADR-019 order); tags; CI green (incl. clean-install DB upgrade to **v18** + `validate_library`); docs (bible §2/§3/§4/§8 + tracker + progress + ADR-062 → Accepted) updated; report. | CI green |

**Suggested order:** 34-01 → 34-02 → 34-03 → 34-04 → 34-05 → 34-06 → 34-07 (linear; each gated on the prior).

---

## 11. Release plan

**Multi-repo:** genesis (m0018 + backend + web) + genesis-workflows (add `story-design-analysis`, remove
`design-doc`). Per ADR-019 no core/SDK pins move (neither changes). Per sub-phase: build → gates (genesis
pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`; genesis-workflows `validate_library` +
pytest) → local commit → independent review → docs; **no tag/push until 34-07 on the user's go-ahead.** The
`clean-install` CI job must migrate a fresh DB to **v18** and serve. A schema bump breaks every hardcoded
`current_version == 17` test — bump them with the migration (the §7 lesson). After releasing the workflow,
`genesis install` picks it up (a running serve loads it at run-start; a *server-code* change needs a restart —
and never restart serve with an active run, the §7 lesson).

---

## 12. Scope

**In scope:** remove `design-doc`; the `story-design-analysis` workflow (object-level + code + per-node
process-model detail, grounded, reliability trio, grounded critic, deterministic assemble, cleanup); m0018
(`kb_story_stages` + revisions) + `StoryStageStore`; the design-start endpoint (move + launch/re-run,
fail-fast); the `StoryDesignFinalizer` (done → design-review, audited; completion chat; on-read recovery); the
board-card design-run fields + card lock/failed display + run link; the drag-into-Design confirm dialog; the
Design Review full-page reused workspace (chat + annotatable preview → agent revises the design); a
`story_design` chat mode.

**Out of scope (future phases):** leaving Design Review / advancing to Implementation (and every later lane's
automation — Implementation / Code Review / Verification / Deployment); an explicit "approve/complete" control;
enforcing the full `STORY_STAGE` transition table on *manual* drags (free drag stays for the not-yet-automated
lanes — only the design→design-review completion transition is audited this phase); writing/deploying anything
into Appian (the design is read-only, proposal-only); WIP limits; multi-board-per-app; multi-user.

---

## 13. Open questions

None blocking — all resolved with the user (2026-09-04, the 10 planning answers in §3). Note the one
implementation choice deferred to 34-01/34-03: the exact `story-design-analysis` node/queue names + the
`gather_context`/`plan_objects` output schemas (locked in 34-01 before the 34-03 build).
