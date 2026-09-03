# 30-01 — Findings (Technical Design stage): example-doc format study + finalized design

> **Status:** ✅ EXECUTED (2026-09-03) — the docs-only deliverable of 30-01. Feeds 30-02 (ADR & finalize).
> Example authority re-read verbatim: **`/Users/ramaswamy.u/Documents/GSS/technical-design-examples`** (5 docs).

## 1. Example-doc construction study (the output authority)

| Example | Shape as-written |
|---|---|
| `SOLUTIONS TEMPLATES - Feature Technical Design 2.md` | The **formal A–L template** (Overview · Development Plan · Configuration/Customization · **Data Model** · Core Components · **Complex Designs** · Interaction-points · Document Management · Integrations · Plugins · Test Harnesses · Metrics). Self-note: *most important = Development Plan, Data Model, Complex Designs.* Blank-question format (the dev fills answers). |
| `GSS 2.1 Vendor Revamp` | **Real filled doc.** DB Changes → Process Changes → **UI Changes** (per-object bullets: `AS_GSS_FM_addVendors` → what changes) → **Expression Rules** (per-rule name → purpose) → **Complex Designs** (short checklist) → **Questions?** |
| `GSS 2.0 Mask Evaluators` | Dev Lead/Architect → DB Changes → **Record Changes** → Expression Rule Changes → **UI Changes** → **Process Model changes** → Complex Designs → **Questions?** (13 numbered, each with the answer appended inline). |
| `GSS 2.2 VM Integration` | Scope (numbered) → **DB Changes** (incl. a full **data-model table**: column/type/comments for a new table) → per-feature narrative (Add/Update/Delete/Download) → Complex Designs → **Questions?** |
| `PSC_PSP GWAC Search FIP` | A lighter **Feature Implementation Plan**: Feature Overview → Key Features → Design → **Release Gates** (Security/Performance/Accessibility). Shows the format flexes by feature size. |

**Observations that drive our output:**
- The real docs are **change-oriented, object-level, code-grounded** — the *inverse* of the UX artifact (ADR-057: intent-level, no object names). The TD **names real objects** and states exactly what changes on each; new tables get a **data-model table**.
- The **Questions?** section is central and is exactly the "surface blind spots, don't assume, answer in the completion chat" loop we automate. In the filled examples the answers were appended inline — which maps to our completion-chat "walk the questions, fold the answer into the doc" flow.
- Section ordering varies by author (some lead with DB, some with Records) but the **change-group vocabulary is stable**: DB · Records · Process Models · UI (Interfaces) · Expression Rules · Integrations · Complex Designs · Questions.
- **User's readability directive** → we organize by **functional workstream** (the reader follows the feature area-by-area), each workstream carrying its own change-groups + complex designs + questions, then a global Complex Designs + Open Questions. **No Resources/links section** (the Spec/UX artifacts live in the app).

## 2. Locked output template (`technical-design.html`)

```
<h1>{Feature} — Technical Design</h1>
<h2>Overview</h2>                       3–6 sentences: the technical shape of the change, at a glance.
<h2>{Workstream N}</h2>                 one per functional workstream, in a sensible build order
  <h3>Objective</h3>                    what this workstream delivers (from Spec + UX)
  <h3>What exists today</h3>            grounded as-is: the real tables/records/processes/interfaces/rules + how configured
  <h3>What changes</h3>                 grouped; each item names a real object OR is marked NEW:
       • DB Changes         (data-model table for new/changed tables: column · type · comments)
       • Record Changes
       • Process (Model) Changes
       • UI Changes         (per-interface: what changes)
       • Expression Rule Changes  (per-rule: purpose)
       • Integrations       (inbound/outbound · method · auth · opt-out)
  <h3>Complex designs</h3>              non-trivial options/decisions for this workstream (may be "None")
  <h3>Open questions</h3>               numbered, tagged [Gap]/[Assumption]/[Decision]/[Cross-Feature]
<h2>Complex Designs</h2>                cross-cutting: configs/customizations · APPREF/ENTRYPOINT interaction
                                        points · technical tickets/spikes · integrations · plugins · testing · metrics
<h2>Open Questions</h2>                 consolidated numbered list (the completion chat walks these)
```
Reader-first: clean headings/lists/tables, a document (not a web app); object names are welcome (this is the
technical stage) but the *organizing principle is the workstream narrative*, not an object dump.

## 3. Research applied (why the shape)

- **Hierarchical decomposition > monolithic** on grounded structured generation — a Planner→Manager→Worker
  pipeline measured **95.7% vs 80.9%** exact-match vs a monolithic LLM (MDPI 2026, hierarchical multi-agent
  structured extraction). → split BOTH the existing-state analysis and the design drafting **per workstream**.
- **Map-reduce fan-out + critic-refiner** is the documented topology for long grounded documents (multi-agent
  design-pattern surveys; DocAgent Reader/Searcher/Writer/Verifier, arXiv 2504.08725).
- **Context-isolate each iteration** — the "four-step per-unit pattern executed perfectly for the first unit
  then eroded" failure of long single-agent runs (dev.to, *Engineering Reliability… Part II*). → each
  per-workstream turn sees only its own inputs + grounding.
- **Ground the critic externally** (the "progress mirage" — reflection helps only when grounded; also
  ADR-057's `verify`). Our `verify` re-checks against Spec + UX + existing-state + a live spot-check.
- **Grounding + validation hooks per stage** (Spec-Kit-Agents, arXiv 2604.05278) ≡ our genesis-kb/appian-dev
  grounding + per-node validators + the reliability trio.

## 4. Finalized node graph (assemble = agent, per user 2026-09-03)

```
START → resolve_inputs → load_inputs → plan_sections →[v_plan]→
        analyze_section →[v_analysis]→ (loop next workstream) …→ draft_section →[v_design]→
        (loop next workstream) …→ assemble (AGENT coherence pass) →[v_doc]→
        verify →[v_verify]→ route_verify →(ok) present → END
        route_verify →(revise, bounded) draft_section/assemble ; →(exhausted) escalate → END
```
`assemble` is a **Kiro agent** node (reliability trio) that stitches the per-workstream HTML blocks into one
coherent, reader-first document (dedup, consistent headings/ordering, the global Complex Designs + Open
Questions roll-up) — not a mechanical concatenation. The start **comment is optional** (empty is accepted).

## 5. Reuse map (confirmed present; do not rebuild)

m0015 `StageStore` (per-`(feature,stage)`, `get_or_create`/`set_html`/`set_source`/`reset_for_reupload`); the
`design` row in `stages.ts` (reserved, `available:false`); `stage-registry.tsx`/`StageWorkspacePage.tsx`;
`StageArtifactWorkspace`/`AnnotatablePreviewDialog`/`StageBuilderPage`; the `ux-design-analysis` skeleton;
`StageFinalizer` (UX-hardcoded → generalize to a workflow→stage binding registry); the `ux_design` chat mode
(`_STEERING_UX` → sibling `_STEERING_TD`); the generalized stage API (UX multipart upload → add a **JSON
start-with-comment** path). **No migration, no genesis-core/SDK change.**

## 6. Gate

Reviewed by the user → 30-02 locks the ADRs (ADR-058 + the ADR-056 prerequisite amendment) and the exact
contracts, then build (30-03).
