# Artifacts — GSS Multi-Round: Integration Research + Feature Implementation Plan

Research artifacts for how **Vendor Management (VM)** and **Government Source Selection (GSS)** integrate, and (Phase 2) how **Multi-Round Evaluations** affects that integration — plus the **Feature Implementation Plan** (doc 05) that turns the verified POC into a build blueprint.

| Doc | Contents | Status |
| :--- | :--- | :--- |
| `01_VM_GSS_CURRENT_STATE_INTEGRATION.md` | **Phase 1** — complete current-state mapping of the GSS↔VM integration: every endpoint both directions, triggers (what fires each flow and when), field-level data exchanged, and what changes in the other app. Verified against live objects in both apps via MCP. | ✅ Ready for review |
| `02_VM_GSS_MULTIROUND_IMPACT.md` | **Phase 2 (VM)** — what multi-round breaks / preserves per flow, with root cause, severity, and prioritized fixes. | ✅ Complete |
| `03_GCW_GSS_CURRENT_STATE_INTEGRATION.md` | **Phase 1 (GCW)** — current-state map of the GCW↔GSS integration via the APPREF→ENTRYPOINT mechanism: full bidirectional flow inventory, triggers, what changes/returns. | ✅ Ready for review |
| `04_GCW_GSS_MULTIROUND_IMPACT.md` | **Phase 2 (GCW)** — what multi-round breaks / preserves per flow, with root cause, severity, and prioritized fixes. | ✅ Complete |
| `05_FEATURE_IMPLEMENTATION_PLAN.md` | **Feature Implementation Plan** — the authoritative, code-free blueprint to implement Multi-Round Evaluations from a clean baseline: what/where/why for every change, state transitions, build sequence, verification, and a full inventory of all 63 POC package objects (Appendix A). Built from the package object list + live inspection + design/build records. | ✅ Ready for review |
| `06_FEATURE_TECHNICAL_DESIGN.md` | **Feature Technical Design** — object-by-object build spec (purpose, usage, real optimized SAIL / node-by-node PMs, test cases), conforming to the design best-practices doc. 8 batches: data model, family/round helpers, Start Evaluation, round-aware tabs (consolidated wrapper), Setup New Round + clone, Start/Complete round + Rounds panel, Summary + Vendors, integration touchpoints. | ✅ Complete |
| `07_APPLICATION_IMPACT_ANALYSIS.md` | **Feature Impact Analysis** — grounds the feature into the whole GSS app: every place a hidden **child-round** evaluation can leak (task grids, ~32 email rules, **both** evaluation lists, consensus, documents) or distort an aggregation (task/rating counts, Process-HQ mining). Major-surface sweep read from SAIL; evidence-graded findings (CONFIRMED / LIKELY / VERIFY) + a consolidated PO/team question register (Q1–Q15). | 🟡 Major-surface sweep complete; minor residuals in §12 |

## Phase status
- **Phase 1 (current-state): COMPLETE** for VM and GCW.
- **Phase 2 (multi-round impact): COMPLETE** for VM and GCW, **reassessed under the PO-confirmed parent-only model** (see each doc's §1b). Net result: multi-round is integration-safe; only **1 minor VM change (Flow G)** and **1 optional GCW hygiene item (Flow 10)** remain. The authoritative workflow + hidden-child principle is in `../01_FEATURE_AND_TECHNICAL_DESIGN.md` §1a.

## Scope note
This research covers **VM ↔ GSS** (docs 01/02) and **GCW ↔ GSS** (docs 03/04). GSS also integrates with GSM/DRM, SAM.gov, SharePoint and Azure OpenAI — inventoried in `../07_CROSS_APP_IMPACT_RESEARCH.md` but not yet deep-mapped here.

## Method / evidence
All findings were traced from live design objects via the `lcp` MCP tools (integration definitions, Web API metadata, and the expression rules behind each Web API — Web API expression bodies are not exposed by MCP, so the backing `AS_*_WA_*` / `AS_*_BL_*` rules were read instead). Object UUIDs are cited inline so any claim can be re-verified with `getExpressionRule` / `getIntegration` / `getProcessModel`.
