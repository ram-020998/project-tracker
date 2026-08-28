# 29-01 — Research & Analysis

> **Status:** ✅ **DELIVERED — FOR REVIEW (2026-08-28)** — findings: `29-01-findings.md`. · **Type:** research / docs-only (no code, no release) · **Phase:** 29 (UX Design Stage) · **Gate:** ⭐ user review of the findings + finalized design before 29-02.

---

## Goal

Produce the evidence base + the finalized technical design for the UX Design stage: the `ux-design-analysis`
workflow node graph, the grounding strategy, the `m0015` artifact model, and the completion-chat model —
grounded in real research + a real current-code audit. Draft **ADR-057**.

## Scope

**In:** desk research + a written analysis + a recommended/finalized design + open-question list + the
ADR-057 draft. **Out:** any code; any mockup (29-02); native PPTX; object-level design.

## Work

1. **External research (cite sources).** What is the standard, reliable way to:
   - Use a **multimodal LLM to analyze UI mockups** and reconcile them against a spec + a live
     implementation — and, critically, its **failure modes** (models reproduce layout but miss data-binding /
     interaction / structural consistency; fine-grained per-screen reasoning is weak). → justify **per-screen
     decomposition** + heavy grounding, not one-shot vision.
   - Build a **generator→grounded-critic** loop that raises document quality without the "progress mirage"
     (self-evaluation bias) — the critic must be **externally grounded** (re-check against the images + spec +
     live notes), bounded, then escalate.
   - Render **PDF → per-page PNG** in Python — confirm **PyMuPDF (fitz)** (pure wheel, no system deps) over
     pdf2image (needs poppler); pick a default **DPI** + a page-count guard.
2. **Current-code audit.** Read + summarize the exact surfaces this phase touches/reuses:
   - Stage framework: `web/src/features/features/{stages.ts, stage-registry.tsx, StageWorkspacePage.tsx,
     FeaturePage.tsx}` — the precise seam to make `ux` live (STAGE_DEFS row + registry entry + inner
     workspace, no shell edits).
   - Spec authoring as the template: `chat/mode_profile.py` (`feature_spec` profile — cwd=sandbox,
     `fs_read`/`fs_write` trusted), `api/features.py` (spec create-opens-chat + artifact endpoints),
     `kb/features.py` (`FeatureStore`, m0010, m0014 CAS), the Lavish annotation bridge (`web/features/features`).
   - Workflow exemplar: `genesis-workflows/workflows/design-doc/graph.py` (program/agent/validator/
     reliability/HITL/open-questions/save-by-reference; the mockup-file input, ADR-035).
   - The render/multimodal gaps: `genesis/kb/doc_parsing.py` (text-only), `genesis-core/nodes/agent.py`
     (`kiro_node` — no image path), `kiro_agent_sdk/client.py` (`_build_content` image parts, gated on
     `promptCapabilities.image`), `chat/manager.py` (`stream_turn(images=…)`).
   - Grounding sources: the `genesis-kb` MCP tool surface (structure + dependency/impact tools) and the
     `appian-dev` MCP read allowlist (actual code reads).
   - Domain: `genesis/domain/` (`ArtifactKind.UX_DESIGN`, `LifecycleService`, transitions), m0013 audit,
     m0010/m0014 — what the `m0015` generalized stage model must add.
3. **Finalize the design** (a single coherent recommendation, not just options):
   - The `ux-design-analysis` **node graph** (§5 of the umbrella) + the deterministic **validators**.
   - The **grounding contract**: genesis-kb (structure/impact) vs appian-dev (actual code); how per-screen
     changes cite object refs; the KB-backed blind-spot query.
   - The **doc template**: the exact HTML section skeleton (per-screen blocks + Blind spots/ripple + Open
     Questions) + the intent-level (not object-level) boundary.
   - The **`m0015`** artifact/lifecycle model (candidate shape + why) + the `ux_design` machine.
   - The **completion chat** model (`ux_design` profile: seed, tools = genesis-kb + appian-dev read +
     fs_read/fs_write sandbox; walk-open-questions → edit HTML live; completion → `completed`).
   - The **image-in-`kiro_node`** additive design (how blackboard page images reach the agent turn).
   - Render **DPI/page-cap** defaults.
4. **ADR-057 draft** — the grounded UX Design stage (refines ADR-056).
5. **Open questions** for the user (feed the umbrella §13).

## Deliverables

- `specs/phase-29-ux-design-stage/29-01-findings.md` — sourced research + the current-code audit + the
  finalized workflow/artifact/chat design + open questions.
- ADR-057 draft (appended to `reference/decision-log.md` as **Proposed** + mirrored in `bible/04`).

## Acceptance / DoD

- Findings cite real external sources and real Genesis code paths (no hand-waving).
- The multimodal failure modes are acknowledged and the design mitigates them (per-screen + grounding +
  grounded critic).
- A single coherent finalized design is stated (workflow graph + validators + grounding contract + doc
  template + m0015 + chat + image-node + DPI). ADR-057 drafted. Progress + tracker updated. **No code changed.**

## Gate

⭐ **User reviews the findings + finalized design (+ resolves the §13 open questions where possible) before
29-02 mockups begin.**
