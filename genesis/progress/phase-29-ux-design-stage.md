# Progress — Phase 29: UX Design Stage (Mockup → grounded implementation analysis)

> As-built record for Phase 29. **Specs:** `specs/phase-29-ux-design-stage.md` (umbrella) +
> `phase-29-ux-design-stage/29-01..29-06`. **ADR-057** (Proposed) — the grounded UX Design stage (refines
> ADR-056). Multi-repo: genesis-core (additive `kiro_node` images) + genesis (PDF render + `m0015` per-stage
> artifact model + `ux_design` lifecycle machine + `ux_design` chat mode + API + web UX stage) +
> genesis-workflows (the `ux-design-analysis` workflow). PDF-only v1; read-only against Appian.

## Status

🎨 **29-02 (hi-fi mockup) DELIVERED — FOR REVIEW.** Coded at `/dev/ux-design` (genesis LOCAL `3ffb3ac`, no tag/push). 29-01 research delivered; ADR-057 (Proposed).

## Sub-phase ledger

| # | Sub-phase | Status |
|---|---|---|
| 29-01 | Research & analysis | ✅ **DELIVERED — FOR REVIEW** (`29-01-findings.md`) |
| 29-02 | Wireframes & hi-fi mockups (`/dev/ux-design`) | ✅ **DELIVERED — FOR REVIEW** (genesis LOCAL `3ffb3ac`) |
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
- **(resolved 2026-08-28, "your call")** render DPI ~150 / ~40-page cap; `m0015` = option A (migrate Spec onto `kb_feature_stages`); completion = explicit "Mark complete".

## Improvements baked in (research-backed)

- Per-screen decomposition (multimodal models are weak at holistic UI reasoning, stronger per-screen).
- A **grounded** verification/critic pass (re-check vs images + spec + live notes — avoids the
  "progress mirage" of self-graded critics), bounded → escalation gate.
- KB-backed blind-spot / ripple-effect analysis (dependency/impact query on affected objects).

## As-built (filled in as sub-phases complete)

_(nothing built yet — spec drafting only)_

## 29-01 — Research & analysis (delivered 2026-08-28)

`specs/phase-29-ux-design-stage/29-01-findings.md`. Cited external research — multimodal UI-vs-implementation
analysis **failure modes** (models reproduce layout but miss data-binding/interaction/structure; weak
fine-grained UI reasoning → **per-screen decomposition + grounding**, not one-shot vision), **generator→
grounded-critic** loops (reflection reduces hallucination only when externally grounded — the "progress
mirage" of self-graded critics → a **grounded** `verify` pass), and **PyMuPDF** as the pure-wheel PDF→PNG
renderer (pdf2image needs poppler; PPTX has no pure-Python renderer → PDF-only v1). Current-code audit
confirmed the exact seams: the Phase-28 stage plug-in point (STAGE_DEFS `ux` row + registry, no shell edits);
`feature_spec` `ChatModeProfile` as the template + `chat/mcp.py` already wiring genesis-kb + appian-dev;
`FeatureStore`/m0010 as the shape `m0015` generalizes; `ArtifactKind.UX_DESIGN` + `SPEC_TRANSITIONS` already
present (the `ux_design` machine reuses them); the two gaps — `kiro_node` has no image path (SDK does) +
`doc_parsing` is text-only. **Finalized design:** the 9-node `ux-design-analysis` graph + validators; the
grounding contract (genesis-kb structure/impact via get_dependents/transitive/path/hub; appian-dev actual
code; per-change object-ref citation); the intent-level HTML doc template; the `m0015` `kb_feature_stages`
model (recommend migrating Spec onto it); the `ux_design` lifecycle machine (reuse SPEC_TRANSITIONS) + chat
profile; the additive `kiro_node` image seam; DPI ~150 / ~40-page cap. **3 open questions** (DPI/cap; spec
migration A/B; completion criteria) — none blocking. **No code changed.** NEXT = 29-02 mockups on review.

## 29-02 — Wireframes & hi-fi mockup (delivered 2026-08-28)

Coded hi-fi mockup at **`/dev/ux-design`** (`web/src/dev/mockups/UxDesignStageMockups.tsx`, dev-only) +
`29-02-wireframes.md`. Committed **LOCAL** on genesis master (`3ffb3ac`, **no tag/push**). A State control
cycles the UX Design stage states — empty/upload (PDF dropzone + "what happens next" pipeline), running
(supervised run progress), review (the "UX Implementation Analysis" annotatable doc pane — per-screen blocks +
blind-spot/ripple callout + open questions — beside the completion chat), completed (finalized doc + artifact
strip), and the stage card in all 4 statuses. Full-bleed + Expand→immersive; light/dark. Added
Upload/Image/Sparkles/HelpCircle/FileSearch to the curated `shared/ui/icons.ts` re-export. **Tokens/primitives
only — no hardcoded brand hex.** Gates: tsc clean, eslint 0 errors (18 pre-existing warnings elsewhere),
**vitest 210**, build OK; `web/static` rebuilt+committed. Dev-only mockup carries no dedicated vitest test
(Phase-28 `FeatureWorkspaceMockups` precedent). **NEXT = user review of `/dev/ux-design` → 29-03 finalize +
lock ADR-057.**
