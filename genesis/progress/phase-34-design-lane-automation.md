# Phase 34 — Design Lane Automation (Workbench Design + Design Review) — AS-BUILT

> **✅ SHIPPED 2026-09-05 — genesis v0.62.0 + genesis-workflows v0.16.0, CI green.** ADR-062 **Accepted** (amends ADR-061).
> Specs: `specs/phase-34-design-lane-automation.md` + `phase-34-design-lane-automation/34-01..34-07`.
> Commits: genesis-workflows `9a9d3ab` (34-02 remove design-doc) · `245d769` (34-03 workflow) · `006d5b4` (release, tag **v0.16.0**);
> genesis `6d987a7` (34-04 backend) · `ef9d3db` (34-05 web) · `db2a719` (pointer-first collision fix) · `66b4585` (release, tag **v0.62.0**).
> Gates at release: genesis pytest **710** + ruff; genesis-workflows validate_library **12** + pytest **179**; web tsc + eslint (0 errors) + **vitest 239** + build; clean-install migrates a fresh DB to **v18**.

## What shipped

The **first per-lane automation** on the Workbench (the work ADR-061 deferred), for the **Design** and
**Design Review** lanes.

**Drag into Design → confirm.** Dragging a ticket into the **Design** lane (from any lane) opens a confirm
dialog: **Start design generation** moves the card to Design **and** launches (or **re-runs, updating the same
design in place**) a grounded `story-design-analysis` run; **Just move** places it in Design with no run.

**The workflow — `story-design-analysis` ("Appian Ticket Design")** (genesis-workflows, modeled on the Phase-30
technical-design-analysis, scoped to ONE ticket):
`resolve_inputs` (fail-fast: a dev-tagged env + the app synced into the KB) → `load_inputs` (the feature's
finalized Spec + UX + Technical Design + the story fields) → `gather_context` (extract ONLY this ticket's
research from the three docs) → `plan_objects` (the objects to create/modify, each NEW/UPDATE) → a per-object
**grounded design loop** (`design_object` — `@genesis-kb` structure + `@appian-dev` the ACTUAL code, read-only;
writes the object's block: NEW/UPDATE tag + granular change + **the actual code**; **process models are
described node-by-node with the code for each node**, never summarized) → `synthesize` (cross-cutting overview
+ sequencing) → **deterministic `assemble`** (one Lavish-safe `design.html`) → **grounded `verify`** critic
(bounded → escalate) → `present` → `cleanup`. Reliability trio on every agent node; `recursion_limit` 250.
Read-only against Appian (proposal-only — it shows code, never writes it).

**Card run states.** While the design run is active the card is **locked** (non-draggable) and shows "Design
generation running" + a link to the run; on **success** the card **auto-advances to Design Review**; on
**failure** the card is painted **light-red** with "Design workflow failed" + the run link (re-dragging into
Design re-runs). Running/failed are derived from the **durable `runs.status`** (authoritative even if a live
`run.final` was missed).

**Design Review workspace.** Clicking a Design Review card opens a **full page** (`/workbench/:appUuid/cards/
:storyId`) that reuses the Spec/Technical-Design experience — a bound **`story_design`** completion chat
(`ChatThread`) + an **annotatable Lavish preview** of `design.html` (`AnnotatablePreviewDialog`). The user's
annotations flow to the agent, which revises the design.

**The audited transition.** The `design → design-review` advance is the **first gated + audited** Workbench
lifecycle transition — the `StoryDesignFinalizer` drives it through `LifecycleService.transition(STORY, …,
"submit")`, recorded to the m0013 audit. Manual drags on the other, not-yet-automated lanes stay free
(the ADR-061 relaxation persists).

**Persistence (m0018; `current_version` 17→18).** `kb_story_stages` (per-`(story, stage)` artifact — the
story-grain analog of m0015 `kb_feature_stages`; `story_id` FK→`kb_stories` ON DELETE CASCADE; stage='design';
status; html_path; content_hash; chat_session_id; run_id; row_version; `UNIQUE(story_id, stage)`) +
`kb_story_stage_revisions`. `StoryStageStore` mirrors `StageStore`.

**Backend.** `POST /api/workbench/boards/{app}/cards/{story_id}/design/start` (move + snapshot the feature's
Spec/UX/TD + launch/re-run + bind the run; **fail-fast 409** on no dev env / app not synced / workflow not
installed); `StoryDesignFinalizer` (a RunManager observer bound to `story-design-analysis` — opens the
completion chat, copies `design.html` into the sandbox, binds it, sets in-review, advances the lane; bound-run
guard + idempotency + `reconcile_story_stage` on-read recovery + startup reconcile); a `story_design`
`ChatModeProfile` + steering; the board card DTO gains `design_run_id`/`design_run_status`/
`design_chat_session_id`/`design_status`/`design_story_stage_id`; `GET .../design/artifact` (themed +
Lavish-injected) + `GET /workbench/design-sdk.js`.

**Removed.** The superseded Phase-15 `design-doc` workflow — from the library (genesis-workflows registry +
directory) and the running app's local library.

## Locked decisions (with the user, 2026-09-04) — the 10 planning answers
id `story-design-analysis` / "Appian Ticket Design"; confirm-on-entry-to-Design from ANY lane (Yes runs/
re-runs, No just moves); a running card is locked; fail-fast if no dev env / app not synced; **code mandatory**
wherever there's a code-level change (process models per-node with code, not summarized); a **per-story
artifact store** (m0018); **one design per story** (re-run updates in place); leaving Design Review deferred;
failure = light-red card + run link; uninstall `design-doc` from the running app too.

## Post-build fix (live-testing)
`closestCorners` favored the tall To Do lane, so drops onto adjacent short/empty lanes (Design, Design Review)
snapped back and the hover-highlight stopped — while a far lane still worked. Root cause was the collision
strategy (a direct `PATCH …/lanes/{design,design-review}` returned 200). Switched the board to a **pointer-first**
`collisionDetection` (`pointerWithin` → `rectIntersection` fallback) so the lane/card under the cursor is the
drop target — every lane accepts a drop and highlights on hover; cross-lane + intra-lane both intact
(`db2a719`).

## Verification
Backend + workflow: unit-tested (StoryStageStore CRUD + reset-in-place; the STORY lifecycle audited
design→design-review; StoryDesignFinalizer done→review + idempotency + bound-run guard + no-artifact skip;
design-start fail-fast; the workflow's validators + deterministic-assembly invariants + bounded verify +
cleanup). Web: pure-fn tests for the run-state helpers (dnd + the annotatable iframe can't be exercised in
jsdom). **Live acceptance** (a real drag → confirm → grounded run against the live app → Design Review →
annotate → the agent revises; the failure path) is user-driven / headless-undrivable — it needs a dev-tagged
environment + a synced app + a real Kiro.

## Out of scope (future phases)
Leaving Design Review / advancing to Implementation, and every later lane's automation (Implementation / Code
Review / Verification / Deployment); an explicit "approve/complete" control; enforcing the full
`STORY_STAGE` transition table on *manual* drags; writing/deploying into Appian; WIP limits; multi-board-per-app.
