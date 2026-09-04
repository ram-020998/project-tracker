# 31-04 — Platform build (genesis backend + web)

> **Status:** ✅ SHIPPED (2026-09-04; genesis v0.59.0 + genesis-workflows v0.15.0, CI green). · Part of Phase 31. Repo: **genesis** (backend + web; no migration — reuses m0015).

## Purpose

Wire the Feature Breakdown stage into the platform: launch the workflow, gate on the three prerequisites,
finalize the run into the stage, add the completion chat mode, and flip the web stage live with a
notes-and-dropzone entry surface. Maximum reuse of the Phase-29/30 generalized surface.

## Backend (`genesis/`)

- **`api/features.py`:**
  - `_STAGE_ARTIFACT_FILE["feature_breakdown"] = "breakdown.html"`.
  - `_fb_prereqs_ready(feature_id)` — the three-way analog of `_td_prereqs_ready`: Spec + UX Design +
    Technical Design each at `in-review`/`completed` with readable HTML → else a specific 409 reason.
  - `_launch_breakdown(row, feat, notes, files)` — snapshot the 3 finalized artifacts to files
    (`_current_stage_html` → `spec_snapshot.html` / `ux_snapshot.html` / `td_snapshot.html`), then
    `run_manager.start("feature-breakdown-analysis", {feature_id, app_uuid, stage_id, spec_path, uxdesign_path,
    techdesign_path, notes}, files={"doc1":…, "doc2":…, "doc3":…})` (only the provided files). Friendly 409 on
    `FileNotFoundError` (workflow not installed) / bad env.
  - `POST /features/{id}/stages/{stage}/start` — extend so `feature_breakdown` is a **multipart** start
    (`notes: str = Form("")` + `files: list[UploadFile] = File([])`, ≤3; validate count + per-file
    extension/size via the ADR-035 limits) gated on `_fb_prereqs_ready`; 409 if already finalized
    (chat bound) OR in progress (run set) — the Phase-30 lifecycle-guard lesson. A matching `/rerun`
    (reset → relaunch). (TD's JSON start path stays; the router dispatches by stage.)
  - The `export.csv` route is 31-05.
- **`chat/stage_finalizer.py`:** add `_BINDINGS["feature-breakdown-analysis"] = _Binding(stage=
  "feature_breakdown", artifact="breakdown.html", chat_mode="feature_breakdown",
  title_default="Feature Breakdown", seed=_seed_fb)` + a `_seed_fb(app_uuid, feature_id)` (walk-the-backlog
  steering that also tells the agent the embedded `<script id="genesis-backlog">` JSON MUST be kept in sync
  with the visible cards/table on every edit). No structural change (the registry already serves 2 workflows).
- **`chat/mode_profile.py`:** a `feature_breakdown` `ChatModeProfile` (read-only genesis-kb + appian-dev +
  sandboxed fs-write — a near-clone of `technical_design`) + `_STEERING_FB`; `chat/store.py` mode whitelist
  gains `feature_breakdown`.

## Web (`genesis/web/src/features/features/`)

- **`stages.ts`:** flip `STAGE_DEFS.breakdown` to `available:true`; add a real `deriveStatus` +
  `requires: ["spec","ux","technical_design"]` (the Phase-30 `deriveAvailability` renders the locked card +
  blocked workspace until all three are ready).
- **`stage-registry.tsx`:** a `feature_breakdown` entry → `{ Workspace: StageArtifactWorkspace (reused),
  CardActions: BreakdownCardActions }`.
- **Entry state:** the start surface = a **notes textarea + a `FileDropList` (≤3)** + a **Start** button →
  the multipart start; reuse the in-progress screen + the annotatable review wholesale. A `RerunBreakdownButton`
  (confirm → reset → relaunch) in the stage header + the Overview card (mirror TD's re-run).
- **Export button:** an **Export** action (stage workspace header + the Artifacts tab) → downloads
  `export.csv` (31-05).
- `lib/api/features.ts` + hooks: a `startBreakdown(featureId, notes, files)` multipart call + a
  `useStartBreakdown`/`useRerunBreakdown`; reuse the stage GET/artifact hooks.

## Gates

genesis pytest + ruff; web tsc + eslint(0) + vitest (+ jest-axe on the new entry surface) + `npm run build`
and **commit `web/static`** (stale-bundle guard). Backend tests: `_fb_prereqs_ready` (3-way), the multipart
start (count/type/size guards + 409 lifecycle guards), the StageFinalizer binding finalizes a `done`
`feature-breakdown-analysis` run into the stage.

## Gate

Independent review = SHIP: three-way gating agrees frontend↔backend; multipart start guards correct; the
finalizer binding + chat mode wired; reuse clean (no shell edits — the ADR-056 invariant); a11y/dark-parity/
no-hardcoded-hex; contract fixtures.
