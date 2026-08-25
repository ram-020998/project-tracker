# 28-04 — Feature-Workspace Architecture Build

> **Status:** 📋 **PLANNED** (after 28-03 sign-off). · **Type:** genesis frontend + thin backend lifecycle/model layer (ships in the 28-06 release) · **Phase:** 28 (Feature Revamp) · **Gate:** independent review = SHIP.

---

## Goal

Build the **finalized** feature-workspace **framework** (per `28-03-final-design.md`) in production genesis —
the durable, plug-in shell into which future stage capabilities drop — with **Spec** wired in as the one live
stage and the others present as first-class **"not yet available"** plug-points. **Accept ADR-056.**

## Scope

**In:**
- **Web shell** (`web/features/features/**`): replace the linear `ArtifactPipeline` with the finalized
  workspace (landing/command-center + the parallel stage representation + Artifacts + Activity + reserved
  Stories slot). Reuse `shared/ui` + tokens (ADR-055/027); a11y (jest-axe) + dark parity + no hardcoded hex.
- **Stage-container pattern**: a reusable component contract (status · artifact+version/provenance ·
  AI-assist entry · completion action · per-stage activity) so a future phase implements only a stage's inner
  surface. Ship the **Spec** stage against it (behavior preserved: create → build → in-review → complete;
  annotatable preview) + **UX Design / Technical Design / Feature Breakdown** as first-class **not-yet-
  available** containers (parallel, not gated).
- **Feature-stage lifecycle**: compose `LifecycleService`/`domain/` into **parallel, independent** per-stage
  state machines (extend `transitions.py`/`enums.py` as data rows — no `if/elif`); m0013 audit for every
  transition; allowed-actions drive the UI; keep the spec machine's live behavior. Feature-level overall
  status per the 28-03 decision (derived vs explicit).
- **Generalized feature-artifact + version/provenance** surface reusing existing revisions/versioning +
  document-provenance patterns; a feature-wide **Activity** feed over m0013 (+ existing activity API).
- **Backend** (`genesis/api/features.py`, `kb/features.py`, `domain/`): the minimal additions to serve the
  above. **A small *additive* migration ONLY if** the generalized multi-stage artifact model needs one
  (decided in 28-03/here; additive per ADR-030; bump every `current_version==N` test if so — §7 lesson).
- **ADR-056 → Accepted**; `bible/04` + `reference/decision-log.md` updated.

**Out:** any stage's inner capability (UX mockup upload/AI authoring, tech-design/breakdown generation);
Stories entities + story workspace; any Appian write/deploy; multi-user/assignment.

## Approach / constraints

- Smallest correct change to reach the locked design; preserve Spec behavior + prop/API stability where
  practical. No sequential gating anywhere.
- Reuse-first: `LifecycleService` (never re-implement transition logic), existing versioning/activity,
  `feature_spec` chat path, Phase-27 primitives.
- Per the dev loop (§6): `cd genesis/web && npx tsc --noEmit && npx eslint . && npx vitest run && npm run
  build` → **commit `web/static`** (stale-bundle guard); genesis `pytest` + `ruff`. New/updated tests for the
  lifecycle rows + the workspace + a11y on every mountable surface + contract fixtures if shapes change.
- Commit **LOCAL** on master; **no tag/push until 28-06**.

## Deliverables

- The built framework (web + thin backend) + tests green; ADR-056 Accepted; `progress/phase-28-feature-
  revamp.md` updated with the as-built (files, decisions, migration-or-not).

## Acceptance / DoD

- The feature workspace matches `28-03-final-design.md`; stages are parallel + independently advanceable;
  UX/Tech-Design/Breakdown render as first-class not-yet-available plug-points (no gating); Spec fully works.
- Artifacts show version/provenance; Activity audits every transition; reserved Stories slot present, nothing
  built for it.
- All gates green (web tsc/eslint/vitest incl. jest-axe/build + committed `web/static`; genesis pytest+ruff);
  both themes; no hardcoded brand hex. If a migration was added, it's additive + version tests bumped.
- An independent review (subagent, READ-ONLY) returns **SHIP**; SHOULD-FIX applied.

## Gate

Independent review = **SHIP** → 28-05.
