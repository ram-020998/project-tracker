# 30-04 — Platform build (genesis)

> **Status:** ✅ BUILT LOCALLY (2026-09-03; genesis master, unreleased) — gates green: genesis pytest 664 + ruff; web tsc + eslint(0) + vitest 223 + build; web/static committed. Gate: independent review = SHIP (30-06). · Part of Phase 30. Repo: **genesis** (backend + web; **no migration**).

## Purpose

Wire the Technical Design stage into the platform, reusing the Phase-29 surface. The only genuinely new
backend pieces are the **JSON start-with-comment** path, the **prerequisite gate**, and the **StageFinalizer
generalization**; the rest is a new chat mode + web wiring.

## Backend (genesis/)

1. **JSON start + re-run (`api/features.py`).** Add `POST /features/{id}/stages/technical_design/start`
   (body `{comment?}`) and `POST /features/{id}/stages/technical_design/rerun` (body `{comment?}`), alongside
   the existing UX multipart upload/reupload. Behavior:
   - Resolve the feature's Spec + UX Design stage artifacts; **409** if either is missing or below
     `in-review` (the prerequisite — defense in depth).
   - `StageStore.get_or_create(feature_id, "technical_design", …)`; `set_source(run_id, comment)`; launch the
     `technical-design-analysis` run with `{feature_id, app_uuid, stage_id, spec_path, uxdesign_path, comment}`.
     Friendly **409** if the workflow isn't installed (the §7 lesson).
   - `rerun` = `reset_for_reupload(stage_id)` + relaunch (discards the prior artifact + chat binding).
   - Feature detail already returns `stages`; the `technical_design` row flows through unchanged.
2. **Prerequisite helper** — a small `_stage_artifact_ready(detail, kind)` used by both the start endpoint and
   (exposed) the `allowed`/stage GET so the web can render the locked state from one source of truth.
3. **Generalize `StageFinalizer` (`chat/stage_finalizer.py`).** Replace the module constants with a
   `_BINDINGS: dict[workflow_id → StageBinding]` (`stage_kind`, `artifact_filename`, `chat_mode`, `seed_fn`).
   `_observe`/`reconcile`/`reconcile_stage`/`_finalize` resolve the binding from `rec.workflow_id` (skip
   unknown workflows). Preserve the v0.55.2 logging + reconcile-stage recovery + the v0.56.2 currently-bound-run
   guard. One finalizer instance now serves both `ux-design-analysis` and `technical-design-analysis`.
4. **`technical_design` chat mode (`chat/mode_profile.py`).** Add a `ChatModeProfile` cloned from `ux_design`
   (`mcp_mode="read_only"`, `permission_mode="auto_deny"`, `cwd_sandbox=True`, `extra_trust=("fs_read",
   "fs_write")`) with a new `_STEERING_TD` (30-02 §G). Add `"technical_design"` to the `chat/store.py` mode
   whitelist. The finalizer's `technical_design` seed points the agent at `technical-design.html`.
5. **Tests (`tests/`)** — start endpoint launches + 409s without prerequisites / without the workflow;
   re-run resets + relaunches; StageFinalizer binding-registry finalizes a `technical-design-analysis` run
   into the `technical_design` stage (+ the superseded-run guard still holds for both workflows);
   `test_chat_mode_profile` asserts the `technical_design` posture.

## Web (genesis/web/)

6. **`stages.ts`** — flip `design` to `available:true`; real `deriveStatus` (read the `technical_design` stage
   row, like `ux`); add `requires: StageKey[]` to `StageDescriptor` (+ `design.requires=["spec","ux"]`) and a
   pure `deriveAvailability(detail)` (both prerequisites at `in-review`/`completed`). Update `stages.test.ts`.
7. **`stage-registry.tsx`** — add a `design` entry `{ Workspace: StageBuilderPage, CardActions: <TechnicalDesignCardActions> }`.
8. **Entry state (`StageBuilderPage.tsx` / a `TechnicalDesignEntry`).** When prerequisites are met and no run
   yet: the "both artifacts are ready" panel + an optional **comment** textarea + **Start** (→ the JSON start
   hook) → the **same animated in-progress screen** as UX while running → the completion chat + annotatable
   preview on finalize. When prerequisites are unmet: a **blocked** state ("Complete Spec & UX Design first").
9. **`TechnicalDesignCardActions.tsx`** — Overview-card actions: **Re-run** (confirm → the rerun hook) + (via
   the openable-artifact change) **View**; no standalone Open (Change A makes the card clickable).
10. **Hooks/api (`hooks.ts`, `lib/api`)** — `useStartTechnicalDesign`/`useRerunTechnicalDesign` (JSON POST);
    stage-scoped artifact fetch reuses the generalized `/stages/{stage}/artifact`. `npm run build` + commit
    `web/static`.

## Reused as-is (no change)

`StageArtifactWorkspace`, `AnnotatablePreviewDialog`, the annotation→chat bridge, the in-progress animation,
the escalation-gate rendering in Runs, StageStore/m0015, `StageWorkspacePage`.

## Gate

Gates green (genesis pytest + ruff; web tsc/eslint/vitest/build; `web/static` committed); independent review =
SHIP. Read-only posture intact; prerequisite enforced UI + backend; no migration (`current_version` still 15).
