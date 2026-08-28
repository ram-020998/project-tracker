# Progress — Phase 29: UX Design Stage (Mockup → grounded implementation analysis)

> As-built record for Phase 29. **Specs:** `specs/phase-29-ux-design-stage.md` (umbrella) +
> `phase-29-ux-design-stage/29-01..29-06`. **ADR-057** (Proposed) — the grounded UX Design stage (refines
> ADR-056). Multi-repo: genesis-core (additive `kiro_node` images) + genesis (PDF render + `m0015` per-stage
> artifact model + `ux_design` lifecycle machine + `ux_design` chat mode + API + web UX stage) +
> genesis-workflows (the `ux-design-analysis` workflow). PDF-only v1; read-only against Appian.

## Status

📋 **SPEC DRAFT — umbrella + 29-01..29-06 authored; awaiting user review, then 29-01 (research).**

## Sub-phase ledger

| # | Sub-phase | Status |
|---|---|---|
| 29-01 | Research & analysis | 📋 PLANNED — **NEXT** (on go-ahead) |
| 29-02 | Wireframes & hi-fi mockups (`/dev/mockups`) | 📋 PLANNED |
| 29-03 | Brainstorm & finalize (+ lock ADR-057) | 📋 PLANNED |
| 29-04 | Build (core → genesis → genesis-workflows) | 📋 PLANNED |
| 29-05 | Code review & hardening | 📋 PLANNED |
| 29-06 | Release | 📋 PLANNED |

## Decisions locked with the user (2026-08-28)

- **PDF-only v1** — PyMuPDF (fitz) render, zero system deps; **PPTX deferred** (no pure-Python renderer).
- **Re-upload replaces + re-runs** — deletes prior page images + supersedes the artifact; one active analysis
  per feature.
- **Grounding split** — **genesis-kb = structure/dependency/impact only**; **appian-dev MCP = the actual
  code** (heavy reliance).
- **Intent-level output** — screen/interaction intent + affected-objects list; NOT object-level SAIL design
  (that's the later Technical Design stage).
- **Artifact = "UX Implementation Analysis"** — HTML in the agent sandbox, reviewed in the annotatable Lavish
  iframe (reuse Phase 20/21).
- **Generalize the per-stage artifact model now (`m0015`)** — per-`(feature, stage)`; not UX-only.
- **Handoff** — upload → supervised `ux-design-analysis` run (verification escalation gate) → draft doc +
  completion chat; UX stage reuses the Spec lifecycle states (draft→in-progress→in-review→completed).
- **Read-only against Appian** (ADR-036/037) — analysis only; no write/deploy.

## Improvements baked in (research-backed)

- Per-screen decomposition (multimodal models are weak at holistic UI reasoning, stronger per-screen).
- A **grounded** verification/critic pass (re-check vs images + spec + live notes — avoids the
  "progress mirage" of self-graded critics), bounded → escalation gate.
- KB-backed blind-spot / ripple-effect analysis (dependency/impact query on affected objects).

## As-built (filled in as sub-phases complete)

_(nothing built yet — spec drafting only)_
