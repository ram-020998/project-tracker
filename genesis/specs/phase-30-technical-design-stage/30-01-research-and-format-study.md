# 30-01 — Research & format study (Technical Design stage)

> **Status:** ✅ DONE (2026-09-03) — executed; deliverable in `30-01-findings.md`. Phase 30 SHIPPED (genesis v0.57.0 + genesis-workflows v0.13.0). · Part of Phase 30 (`../phase-30-technical-design-stage.md`).

## Purpose

Two grounding activities before design: (1) study the **five real example TDs** as the authority for the
output construction, and (2) collect the research that justifies the workflow shape (decomposition + grounded
critic). Output: the locked reader-first output template + the finalized workflow node graph feeding 30-02.

## A. Example-doc study — the authority for the output construction

Source: **`/Users/ramaswamy.u/Documents/GSS/technical-design-examples`** (re-read verbatim as ground truth):

- `SOLUTIONS TEMPLATES - Feature Technical Design 2.md` — the formal A–L template (Overview, Development Plan,
  Configuration/Customization, **Data Model**, Core Components, **Complex Designs**, Interaction-points,
  Document Management, Integrations, Plugins, Test Harnesses, Metrics). The template's own note: *the most
  important sections are Development Plan, Data Model, and Complex Designs.*
- `GSS 2.1 Vendor Revamp`, `GSS 2.0 Mask Evaluators`, `GSS 2.2 VM Integration` — the **real, filled** docs.
  Construction observed (this is what we reproduce): **Scope** → **DB Changes** (bulleted, with a **data-model
  table** for new tables: column / data type / comments) → **Record Changes** → **Process (Model) Changes** →
  **UI Changes** (per-object bullets: `AS_GSS_FM_addVendors` → *what changes*) → **Expression Rule Changes**
  (per-rule: name → purpose) → **Complex Designs** (a short Q&A checklist: configs/customizations, APPREF/
  ENTRYPOINT interaction points, technical tickets/spikes, integrations, plugins, testing, metrics) →
  **Questions?** (numbered; the dev's open questions, later answered inline).
- `PSC_PSP GWAC Search FIP` — a lighter "Feature Implementation Plan" variant (Feature Overview → Key Features
  → Design → Release Gates: Security/Performance/Accessibility). Shows the format flexes by feature size.

**Findings that shape our output (locked in §3 of the umbrella):**
- The **real** docs are **change-oriented + object-level + code-grounded** — the opposite of the UX artifact
  (ADR-057, intent-level, no object names). The TD names real objects and states precisely what changes.
- The dev's **Questions?** section is central — it is exactly the "surface blind spots, don't assume, answer
  in the completion chat" loop we automate.
- **Reader-first (user decision):** we organize by **functional workstream** (each workstream carries its own
  DB/Record/Process/UI/Expression-rule changes + complex designs + open questions), then a global Complex
  Designs + Open Questions — so the reader follows the feature area by area rather than scanning an object dump.
  Data-model tables reproduced for new tables. **No Resources/links section** (artifacts live in the app).

### Locked output template (the `technical-design.html` skeleton)

```
<h1>{Feature} — Technical Design</h1>
<h2>Overview</h2>                     · 3–6 sentences: what this feature changes, technically, at a glance.
<h2>{Workstream 1}</h2>               · one per functional workstream, in a sensible build order
  <h3>Objective</h3>                  · what this workstream delivers (from Spec + UX)
  <h3>What exists today</h3>          · grounded as-is: the relevant tables/records/processes/interfaces/rules
  <h3>What changes</h3>               · grouped, each item names a real object OR marked NEW:
     DB Changes (with data-model table for new tables) · Record Changes · Process Changes ·
     UI Changes · Expression Rule Changes · Integrations
  <h3>Complex designs</h3>            · non-trivial decisions/options for this workstream (may be "None")
  <h3>Open questions</h3>             · numbered, tagged [Gap]/[Assumption]/[Decision]/[Cross-Feature]
<h2>…more workstreams…</h2>
<h2>Complex Designs</h2>              · cross-cutting: configs/customizations, APPREF/ENTRYPOINT interaction
                                        points, technical tickets/spikes, integrations, plugins, testing, metrics
<h2>Open Questions</h2>               · consolidated numbered list (the completion chat walks these)
```

## B. Research — why this shape (cited)

- **Hierarchical decomposition beats monolithic on grounded structured generation.** A Planner→Manager→Worker
  pipeline measured **95.7% vs 80.9%** exact-match over a monolithic LLM on a comparable extraction task
  (MDPI, *Hierarchical Multi-Agent … Structured Knowledge Extraction*, 2026). → split BOTH the existing-state
  analysis and the design drafting **per workstream**.
- **Map-reduce fan-out + critic-refiner is the documented topology for long grounded documents** (multi-agent
  design-pattern surveys; DocAgent's Reader/Searcher/Writer/Verifier for code documentation, arXiv 2504.08725).
- **Context-isolate each iteration.** The "four-step per-unit pattern (generate/evaluate/verify/summarize)
  executed perfectly for the first unit then eroded" failure of long single-agent runs (dev.to, *Engineering
  Reliability into AI Agent Code Generation, Part II*) → each per-workstream turn sees only its own inputs.
- **Ground the critic externally** (the "progress mirage" — reflection reduces hallucination only when grounded
  in external truth; also the basis of ADR-057's `verify`). Our `verify` re-checks against Spec + UX +
  existing-state + a live spot-check, not its own prior output.
- **Grounding hooks + validation hooks per stage** (Spec-Kit-Agents context-grounded agentic workflows,
  arXiv 2604.05278) — mirrors our genesis-kb/appian-dev grounding + per-node validators + the reliability trio.

## C. Current-code audit (reuse surface) — confirm, don't rebuild

Confirmed present and stage-generic (see the umbrella §4): m0015 `StageStore`; `stages.ts` `design` row
(reserved, `available:false`); `stage-registry.tsx`/`StageWorkspacePage.tsx`; `StageArtifactWorkspace`/
`AnnotatablePreviewDialog`/`StageBuilderPage`; `StageFinalizer` (hard-coded to UX — to generalize); the
`ux-design-analysis` workflow (skeleton to clone); the `ux_design` chat mode (`_STEERING_UX` — TD gets a
sibling `_STEERING_TD`); the generalized stage API (UX uses multipart upload — TD needs JSON start).

## Deliverable / gate

The locked output template + the finalized workflow node graph + the confirmed reuse map, reviewed by the
user → 30-02 (ADR + finalize).
