# Artifacts — VM ↔ GSS Integration Research

Research artifacts for how **Vendor Management (VM)** and **Government Source Selection (GSS)** integrate, and (Phase 2) how **Multi-Round Evaluations** affects that integration.

| Doc | Contents | Status |
| :--- | :--- | :--- |
| `01_VM_GSS_CURRENT_STATE_INTEGRATION.md` | **Phase 1** — complete current-state mapping of the GSS↔VM integration: every endpoint both directions, triggers (what fires each flow and when), field-level data exchanged, and what changes in the other app. Verified against live objects in both apps via MCP. | ✅ Ready for review |
| `02_VM_GSS_MULTIROUND_IMPACT.md` | **Phase 2 (VM)** — what multi-round breaks / preserves per flow, with root cause, severity, and prioritized fixes. | ✅ Complete |
| `03_GCW_GSS_CURRENT_STATE_INTEGRATION.md` | **Phase 1 (GCW)** — current-state map of the GCW↔GSS integration via the APPREF→ENTRYPOINT mechanism: full bidirectional flow inventory, triggers, what changes/returns. | ✅ Ready for review |
| `04_GCW_GSS_MULTIROUND_IMPACT.md` | **Phase 2 (GCW)** — what multi-round breaks / preserves per flow. | ⏸️ Not started — begins after Phase 1 (GCW) review |

## Phase status
- **Phase 1 (current-state): COMPLETE, awaiting user review.** Both the GSS side and the VM side were read directly (VM = `AS VM Full Application`, deployed in this env).
- **Phase 2 (multi-round impact): pending Phase 1 sign-off.** Candidate seams are listed at the end of doc 01 (§9) as a bridge, but the impact analysis itself is deferred until review.

## Scope note
This research covers **VM ↔ GSS** (docs 01/02) and **GCW ↔ GSS** (docs 03/04). GSS also integrates with GSM/DRM, SAM.gov, SharePoint and Azure OpenAI — inventoried in `../07_CROSS_APP_IMPACT_RESEARCH.md` but not yet deep-mapped here.

## Method / evidence
All findings were traced from live design objects via the `lcp` MCP tools (integration definitions, Web API metadata, and the expression rules behind each Web API — Web API expression bodies are not exposed by MCP, so the backing `AS_*_WA_*` / `AS_*_BL_*` rules were read instead). Object UUIDs are cited inline so any claim can be re-verified with `getExpressionRule` / `getIntegration` / `getProcessModel`.
