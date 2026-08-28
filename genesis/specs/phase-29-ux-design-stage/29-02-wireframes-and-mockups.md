# 29-02 — Wireframes & Hi-Fi Mockups

> **Status:** 📋 **PLANNED** (after 29-01). · **Type:** dev-only web mockups (coded at `/dev/mockups`; no production wiring, no release) · **Phase:** 29 (UX Design Stage) · **Gate:** ⭐ user review of the mockups before 29-03.

---

## Goal

Render the finalized 29-01 UX Design stage design as **coded hi-fi mockups** so the user can see + steer the
inner stage experience before it is built for real — in the light-first Phase-27 language (ADR-055), reusing
tokens/primitives (no hardcoded brand hex).

## Scope

**In:** lo-fi wireframes → coded hi-fi mockups at **`/dev/mockups`** (dev-only route), of the UX Design stage
container across its states. **Out:** any production wiring (no real upload/run/chat/API); backend; the
workflow.

## Work — mock the UX stage container states

1. **Empty / upload state** — the stage before any mockup: a clear "Upload the mockup PDF" affordance +
   an explanation of what the analysis will do; the (disabled) note that re-upload replaces + re-runs.
2. **Running state** — after upload: the supervised `ux-design-analysis` run in progress (a compact progress
   view echoing Runs: rendering pages → per-screen analysis → grounding → synthesize → verify), with a link
   to the full Run detail.
3. **Draft-with-open-questions state** — the produced **UX Implementation Analysis** shown in the annotatable
   review pane (per-screen blocks + Blind spots/ripple + Open Questions), status `in-review`, with the
   completion chat beside it.
4. **Completion chat** — the bound `ux_design` chat walking the open questions, editing the doc live
   (mock the "answer → section fills in"), an "extra check" affordance, and the **Mark complete** action →
   `completed` state.
5. **Full-bleed + Expand→immersive** — consistent with the Phase-28 stage workspace shell (`StageWorkspaceHeader`).
6. Show the **stage card** on the feature Overview for UX in each status (not-started / in-progress /
   in-review / completed) so the card-actions design is settled.

## Deliverables

- `specs/phase-29-ux-design-stage/29-02-wireframes.md` — lo-fi wireframes + notes.
- Coded hi-fi mockup at **`/dev/mockups`** (a `web/src/dev/mockups/*` component, dev-only; committed
  `web/static` per the build rule). Layout/light-dark toggles as with prior mockups.

## Acceptance / DoD

- Every state in §Work is rendered and navigable in the mockup; light + dark both clean; jest-axe clean on the
  mocked pages; **no hardcoded brand hex** (tokens only). tsc/eslint/vitest/build green; `web/static` committed.
- No production code path is wired (dev-only). Progress + tracker updated.

## Gate

⭐ **User reviews the mockups; feedback feeds 29-03 (brainstorm & finalize).**
