# 27-07 — Runs & Run Detail

> **Phase 27 (UI/UX Revamp) · sub-phase 07 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-04, 27-05**.
> **Status:** ✅ **BUILT (unreleased) — 2026-08-24** (genesis `1000af0`, LOCAL/untagged; independent review = SHIP).

## Objective
Redesign run observability to the approved mockups, behaviour-preserving: the **Runs** list and the **Run Detail** surface — the process graph canvas, node inspector, HITL prompts, conversation view, and run documents.

## Scope (components)
`runs/{RunsPage,components/*}`, `run-detail/{RunDetailPage,graph/*,components/*,node-states,conversation,hitl-hooks}`, `documents/{DocumentPreview,renderers/*}` as used by run docs.

## Deliverables
- Runs list: modern table (status, timing, credits) with filter/sort + empty/loading/error states.
- Run Detail: restyled graph canvas (React Flow → tokens, light + dark parity), node inspector, **HITL** prompt UX, conversation timeline, and document panels — to the new language.
- Consistent status/health semantics (`health-dot`, badges) from the modernized primitives.

## Acceptance / gates
- Live run monitoring, node inspection, HITL respond/approve, and doc viewing all work; run-detail + HITL + documents tests updated + green.
- Light default + dark parity; jest-axe green; graph canvas legible at density; responsive.
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5.

## Out of scope
No change to run execution, node-state semantics, or HITL protocol (presentation only).
