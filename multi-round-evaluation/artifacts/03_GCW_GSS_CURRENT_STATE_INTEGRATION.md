# 03 — GCW ↔ GSS Integration: Current-State Mapping (Phase 1)

> **Purpose:** complete current-state map of how **Government Contract Writing (GCW)** and **GSS** integrate — the APPREF→ENTRYPOINT mechanism, every flow both directions, triggers, and what data changes/returns. Multi-round impact is Phase 2 (`04_…`); §8 lists the seams as a bridge only.
>
> **Verified** (2026-08-27) via `lcp` MCP against both apps. GSS = `AS GSS Full Application` (`_a-0000e5bc-…_930416`); GCW = **`AS GCW Full Application`** (`_a-0000e85f-3e2e-8000-9bfd-011c48011c48_2767135`, prefix `AS_GCW`). Evidence UUIDs cited inline.

---

## 1. The integration mechanism — APPREF → ENTRYPOINT (this is NOT like VM)

Unlike VM (HTTP integrations ↔ Web APIs, cross-environment, API-key auth), GCW↔GSS is a **same-environment, in-JVM, name-resolved rule reference** pattern:

- The **caller app** defines an **APPREF** wrapper rule, e.g. `AS_GSS_APPREF_GCW_STARTPROCESS_syncEvalStatusInGcw`. Its body is uniformly:
  ```
  a!localVariables(
    local!rule: a!refreshVariable(
      value: rule!AS_FRM_getRuleReferenceOrNoOp(ruleName: "<TARGET ENTRYPOINT RULE NAME>"),
      refreshAlways: true),
    local!rule(ifNull_default: {}, <entrypoint-specific inputs>))
  ```
- The **target app** defines the **ENTRYPOINT** rule (referenced *by name string*), e.g. `AS_GCW_GSS_ENTRYPOINT_STARTPROCESS_syncEvaluationStatusListRecord`.
- `AS_FRM_getRuleReferenceOrNoOp` resolves the entrypoint **at runtime by name**; if the target app isn't installed, it returns a **no-op** yielding `ifNull_default` (`{}`). So the integration is **loosely coupled** and degrades gracefully to "do nothing."

**Implications (vs VM):** no connected system, no API key, no network hop, no `noticeId`-style HTTP payload. Calls are **synchronous rule evaluations** in the same environment; both apps must be co-installed. There are three entrypoint flavors:
- **GETDATA** — synchronous read; returns data to the caller.
- **DISPLAY** — returns a UI/interface fragment to embed in the caller.
- **RECORDACTION** — returns a record-action config/link the caller renders.
- **STARTPROCESS** — returns `{processModel, processParameters}` so the caller starts a process in the target app (this is how one app writes data into the other).

> **Coexisting HTTP path (status sync):** GSS *also* has an HTTP Web API `evaluationList` (`AS GSS WA GET Evaluation Status List`, backing rule `AS_GSS_WA_GET_EvaluationStatusList` `_…17688586`) and an integration `AS_GSS_INT_POST_SyncEvaluationStatusList` (`4a8a979c-…`, wired into PM `0006ef1c` "Sync Eval Status in GCW"), alongside the APPREF `syncEvalStatusInGcw`. See §5 for how these relate (and an open wiring question).

---

## 2. Full flow inventory

### 2.1 GSS → GCW (13 APPREF wrappers → GCW entrypoints)
| # | GSS APPREF wrapper (UUID) | Target GCW entrypoint | Type | Purpose |
| :-- | :--- | :--- | :-- | :--- |
| 1 | `…_GCW_APPVERSION_UT_VersionTrackerWrapper_exists` (`_…13542797`) | `AS_GCW_ENTRYPOINT_APPVERSION_UT_VersionTrackerWrapper` | GETDATA | Is GCW installed / version probe |
| 2 | `…_GCW_GETDATA_getSolicitationDataForDraftingEvaluation` (`_…13570114`) | `AS_GCW_ENTRYPOINT_GETDATA_getSolicitationDataForDraftingEvaluation` | GETDATA | Pull solicitation data to seed a new evaluation |
| 3 | `…_GCW_LOGIC_displayRelatedEvaluationVisibilty` (`_…13612285`) | `AS_GCW_ENTRYPOINT_LOGIC_isExposeGssIntegration` | GETDATA | Whether GCW exposes the GSS integration |
| 4 | `…_GCW_STARTPROCESS_updateEvalSolicMapping` (`_…13637461`) | `AS_GCW_GSS_ENTRYPOINT_STARTPROCESS_updateEvalSolicMapping` | STARTPROCESS | Persist the evaluation↔solicitation link in GCW |
| 5 | `…_GCW_DISPLAY_relatedProcurementDetailsForEvalSummary` (`_…13704418`) | `AS_GCW_ENTRYPOINT_DISPLAY_relatedProcurementDetailsForEvalSummary` | DISPLAY | Embed GCW procurement details on the GSS eval summary |
| 6 | `…_GCW_GETDATA_getLatestOrBaseSolicitationDetails` (`_…13706341`) | `AS_GCW_ENTRYPOINT_GETDATA_getLatestOrBaseSolicitationDetails` | GETDATA | Latest/base solicitation details |
| 7 | `…_GCW_STARTPROCESS_updateSolicPublicFolderSecurityOnCreateEval` (`_…13754759`) | `AS_GCW_GSS_ENTRYPOINT_STARTPROCESS_updateSolicPublicFolderSecurityOnCreateEval` | STARTPROCESS | Grant GCW solicitation folder security on eval create |
| 8 | `…_GCW_RECORDACTION_createSingleAwardFromEvaluation` (`_…17994540`) | `AS_GCW_ENTRYPOINT_GSS_RECORDACTION_createSingleAwardFromEvaluation` | RECORDACTION | Create a single Award in GCW from the evaluation |
| 9 | `…_GCW_GETDATA_getAwardLinksForEvaluation` (`_…17999179`) | `AS_GCW_ENTRYPOINT_GSS_GETDATA_getAwardLinksForEvaluation` | GETDATA | Award record links for given evaluation id(s) |
| 10 | `…_GCW_STARTPROCESS_syncEvalStatusInGcw` (`_…18001846`) | `AS_GCW_GSS_ENTRYPOINT_STARTPROCESS_syncEvaluationStatusListRecord` | STARTPROCESS | Sync GSS evaluation status into GCW |
| 11 | `…_GCW_RECORDACTION_createMutlipleAwardsFromEvaluation` (`_…18006984`) | `AS_GCW_ENTRYPOINT_GSS_RECORDACTION_createMutlipleAwardsFromEvaluation` | RECORDACTION | Create multiple Awards in GCW from the evaluation |
| 12 | `…_GCW_GETDATA_getRefIdConstants` (`_…18095155`) | `AS_GCW_ENTRYPOINT_GSS_GETDATA_getRefIdConstants` | GETDATA | GCW ref-id constants |
| 13 | `…_GCW_GETDATA_solicitationContractText` (`_…18457582`) | `AS_GCW_ENTRYPOINT_GETDATA_solicitationContractText` | GETDATA | Solicitation contract text |

### 2.2 GCW → GSS (9 APPREF wrappers → GSS entrypoints)
| # | GCW APPREF wrapper (UUID) | Target GSS entrypoint (UUID) | Type | Purpose |
| :-- | :--- | :--- | :-- | :--- |
| A | `AS_GCW_APPREF_GSS_APPVERSION_…_exists` (`_…13610958`) | `AS_GSS_ENTRYPOINT_APPVERSION_UT_VersionTrackerWrapper` | GETDATA | Is GSS installed / version |
| B | `AS_GCW_APPREF_GSS_RECORDACTION_createEvaluationFromSolicitation` (`_…13622295`) | `AS_GSS_ENTRYPOINT_RECORDACTION_createEvaluationFromSolicitation` (`_…13573188`) | RECORDACTION | **Create a GSS evaluation from a GCW solicitation** |
| C | `AS_GCW_APPREF_GSS_DISPLAY_relatedEvaluationDetails` (`_…13622854`) | `AS_GSS_ENTRYPOINT_DISPLAY_relatedEvaluationDetails` (`_…13612988`) | DISPLAY | Embed GSS eval details on GCW record |
| D | `AS_GCW_APPREF_GSS_LOGIC_displayRelatedProcurementVisibilty` (`_…13726775`) | `AS_GSS_ENTRYPOINT_LOGIC_isExposeGcwIntegration` (`_…13723090`) | GETDATA | Whether GSS exposes the GCW integration |
| E | `AS_GCW_APPREF_GSS_GETDATA_getEvaluationStatusRefData` (`_…17688724`) | `AS_GSS_ENTRYPOINT_GETDATA_getEvaluationStatusRefData` (`_…17688620`) | GETDATA | Eval status ref data (for the synced status list) |
| F | `AS_GCW_APPREF_GSS_GETDATA_getEvaluationandVendordetails` (`_…17694858`) | `AS_GSS_ENTRYPOINT_GETDATA_getEvaluationandVendordetails` (`_…17983502`) | GETDATA | Evaluation + vendor + document details for a solicitation |
| G | `AS_GCW_APPREF_GSS_GETDATA_getSlgToggleValue` (`_…17765998`) | `AS_GSS_ENTRYPOINT_GETDATA_getSlgToggleValue` (`_…17712295`) | GETDATA | State-&-Local toggle value |
| H | `AS_GCW_APPREF_GSS_GETDATA_getWinningVendorAndBasicInformation` (`_…18102345`) | `AS_GSS_ENTRYPOINT_GETDATA_getWinningVendorAndBasicInformation` (`_…18080306`) | GETDATA | **Winning vendors + docs for award creation** |
| I | `AS_GCW_APPREF_GSS_GETDATA_getRefIdConstants` (`_…18143021`) | `AS_GSS_ENTRYPOINT_GCW_GETDATA_getRefIdConstants` (`_…18096129`) | GETDATA | GSS ref-id constants |

> Additional GSS-owned entrypoints exist for the GAM suite / AM (e.g. `getEvaluationDetailsBySolicPiid` `_…16906534`, `getEvaluationStatusRefData`, folder-security `_…18006197`) — several are shared across GCW/AM. `getEvaluationDetailsBySolicPiid` is analyzed in §4 because it drives the GCW/AM summary display.

---

## 3. The GCW↔GSS lifecycle (how the flows connect)

```
GCW Solicitation ──[B createEvaluationFromSolicitation]──▶ GSS creates Evaluation (evaluationNumber = solicitation PIID, sourceApplication = AM)
     │                                                              │
     │◀─[4 updateEvalSolicMapping]── GSS persists eval↔solic link in GCW (during create)
     │◀─[7 updateSolicPublicFolderSecurity]── folder security granted
     │                                                              │
     │   GSS runs the evaluation (rounds) ... status changes ──[10 syncEvalStatusInGcw]──▶ GCW keeps a synced copy of eval status
     │                                                              │
GCW summary ◀─[C relatedEvaluationDetails / getEvaluationDetailsBySolicPiid]── GSS status + deep link
     │                                                              │
     │   Evaluation completes → award decision                     │
     │◀─[H getWinningVendorAndBasicInformation]── GSS returns winning vendors + docs
GSS action ──[8/11 create(Single|Multiple)AwardsFromEvaluation]──▶ GCW creates Award(s)
GSS summary ◀─[5 relatedProcurementDetailsForEvalSummary / 9 getAwardLinksForEvaluation]── GCW procurement + award links
```

---

## 4. Detailed flows (verified handlers)

### B — Create Evaluation from Solicitation (GCW → GSS) ⭐
- **Trigger:** a record action on the GCW **solicitation** ("Create Evaluation"), which invokes GSS entrypoint `AS_GSS_ENTRYPOINT_RECORDACTION_createEvaluationFromSolicitation` (`_…13573188`) → delegates to `rule!AS_GSS_RA_createEvaluationFromSolicitationRecordAction(context, showWhen)`.
- **Effect:** GSS creates a new **Evaluation** seeded from the solicitation. The evaluation's **`evaluationNumber` = the solicitation PIID** and **`sourceApplicationId = AM`** (Award Management / procurement origin) — this is the identity that all later GCW reads key on.
- During/after creation GSS calls back **[4] updateEvalSolicMapping** (persist the eval↔solic link in GCW) and **[7] folder security**. The eval↔solic map push is wired via GSS PM `0002ec9e-6500-…` node **"Construct Eval Solic Map"** → APPREF `_…13637461`.

### 10 — Sync Evaluation Status into GCW (GSS → GCW) ⭐
- **Wrapper:** `AS_GSS_APPREF_GCW_STARTPROCESS_syncEvalStatusInGcw(evaluationIdToSync)` → GCW entrypoint `AS_GCW_GSS_ENTRYPOINT_STARTPROCESS_syncEvaluationStatusListRecord` (`_…17809602`), which returns `{processModel: cons!AS_GCW_GSS_PM_SYNC_EVALUATION_STATUS_LIST_RECORD, processParameters:{evaluationIdToSync}}`.
- **Effect:** GCW starts its **Sync Evaluation Status List Record** process for that `evaluationId`; GCW maintains its **own synced copy of the GSS evaluation status** (keyed by `evaluationId`), used to show source-selection status on GCW screens.
- **How GCW gets the data:** GSS exposes the status list via the `evaluationList` Web API (`AS_GSS_WA_GET_EvaluationStatusList` `_…17688620`/`_17688586`), which returns, per `evaluationId` (or all `isActive=true` evals): `{evaluationId, evaluationStatusId, evaluationNumber, evaluationTitle}`. **This rule has no `parentEvalId` filter** (relevant to Phase 2).
- **⚠️ Open wiring question:** two status-sync mechanisms coexist — the APPREF `syncEvalStatusInGcw` (no GSS object dependents found) and the HTTP integration `AS_GSS_INT_POST_SyncEvaluationStatusList` (`4a8a979c`, wired into PM `0006ef1c` "Sync Eval Status in GCW", reused by Start/Complete/Mark-Complete). Need to confirm which is the active path in this build (possibly APPREF is the new same-env replacement for the HTTP one). Flagged for Phase 2 / team confirmation.

### C / getEvaluationDetailsBySolicPiid — GCW displays GSS eval status (GCW → GSS) ⭐
- GSS entrypoint `getEvaluationDetailsBySolicPiid` (`_…16906534`) → `AS_GSS_AM_getEvaluationDetailsBySolicPiid_V1` (`_…16904747`). Queries `AS_GSS_Evaluation_RECORD` by **`evaluationNumber = solicitationPiid` AND `sourceApplication.refDataId = AM` AND `isActive = true`** (SINGLE_OBJECT). Returns `{evaluationId, solicitationPiid, title, status(refLabel), statusBranding, createdOn, evaluationLink}` (a deep link to the evaluation record).
- The `relatedEvaluationDetails` DISPLAY entrypoint (`_…13612988`) embeds this on GCW records.

### H — Winning Vendors for Award (GCW → GSS) ⭐
- GSS entrypoint `getWinningVendorAndBasicInformation` (`_…18080306`) → `AS_GSS_GCW_getWinningVendorAndBasicInformation_V1` (`_…18080158`). Input: **`evaluationIds` (list)**. Calls `AS_GSS_UT_constructEvalVendorAndDocsForMultipleEvalIds(evaluationIds, includeAllVendors:true, …)` and returns, per eval: `{evalId, evaluationNumber, vendors:[{gsmVendorRefId, vendorLegalName, isWinningVendor (=decisionType SELECT), appianDocumentIds}]}`.
- Feeds the **award creation** flows [8]/[11] (`create(Single|Multiple)AwardsFromEvaluation`), where GCW creates Award records from the winning vendors + their documents. `appianDocumentIds` carry the proposal/eval documents into the award.

### Reads / display (characterized; handlers not deep-read)
- **2 getSolicitationDataForDraftingEvaluation, 6 getLatestOrBaseSolicitationDetails, 13 solicitationContractText:** GSS pulls solicitation content from GCW to seed/inform the evaluation.
- **5 relatedProcurementDetailsForEvalSummary:** GCW procurement panel embedded on the GSS eval summary.
- **9 getAwardLinksForEvaluation:** award record links for the eval (GSS shows links to GCW awards).
- **F getEvaluationandVendordetails:** GCW pulls eval + vendor + document details for a solicitation (`AS_GSS_ENTRYPOINT_GETDATA_getEvaluationandVendordetails` `_…17983502`).
- **E getEvaluationStatusRefData, G getSlgToggleValue, 12/I getRefIdConstants:** ref-data / toggle exchange for consistent enums across apps.
- **3/D isExpose{Gss|Gcw}Integration:** mutual visibility toggles gating whether each app shows the other's integration UI (analogous to VM's master toggles).

---

## 5. Identity, provenance & keys
- **Join key:** GSS `Evaluation.evaluationNumber` = solicitation **PIID** (same string GCW/AM uses). GCW→GSS reads additionally filter **`sourceApplication = AM`** to select the procurement-originated evaluation.
- **Evaluation id:** status sync, award links, and winning-vendor reads key on **`evaluationId`** (numeric), passed explicitly by the caller (esp. `evaluationIds` list for winning vendors).
- **Documents:** winning-vendor payload carries `appianDocumentIds` (the same Appian doc ids used across GSS/VM) into GCW awards.
- **Provenance:** evaluations created from a procurement carry `sourceApplicationId = AM`; GSS-internal round clones carry `sourceApplicationId = GSS` (see Phase 2).
- **Coupling:** name-resolved, no-op-if-absent (`AS_FRM_getRuleReferenceOrNoOp`), gated by mutual `isExpose…Integration` toggles.

---

## 6. What changes where (summary)
| Flow | Writes in… | What |
| :-- | :-- | :-- |
| B createEvaluationFromSolicitation | **GSS** | New Evaluation (evaluationNumber=PIID, sourceApplication=AM) |
| 4 updateEvalSolicMapping | **GCW** | eval↔solicitation link record |
| 7 updateSolicPublicFolderSecurity | **GCW** | folder security for eval groups |
| 10 syncEvalStatusInGcw | **GCW** | synced copy of eval status (by evaluationId) |
| 8/11 create(Single/Multiple)AwardsFromEvaluation | **GCW** | Award record(s) from winning vendors + docs |
| All GETDATA/DISPLAY (2,3,5,6,9,12,13,C,E,F,G,H,I) | (reads) | no writes; return data/UI |

---

## 7. Objects not deep-read (for full transparency)
Handlers characterized by name/description/entrypoint but not line-read this pass: the GCW-side implementations of `getSolicitationDataForDraftingEvaluation`, `getLatestOrBaseSolicitationDetails`, `solicitationContractText`, `relatedProcurementDetailsForEvalSummary`, `getAwardLinksForEvaluation`, the GCW award-creation processes, the GCW `updateEvalSolicMapping`/folder-security processes, and GSS `getEvaluationandVendordetails`. All are enumerated with UUIDs above; any can be expanded on request. The **data-changing and multi-round-critical** flows (B, 10, C, H) were verified in full.

---

## 8. Bridge to Phase 2 — multi-round seams (NOT analysis)
*Scoping only; impact analysis deferred to `04_…`.*
1. **Status display keys root-only:** `getEvaluationDetailsBySolicPiid_V1` matches `evaluationNumber=PIID` **AND `sourceApplication=AM`** → only the **root (Round 1)** matches (clones are `"PIID Round N"` + `sourceApplication=GSS`). GCW/AM summary likely shows Round-1 status regardless of the active round (same pattern as VM Flow F).
2. **Status sync by evaluationId:** flow 10 syncs a single `evaluationIdToSync`; `evaluationList` has no `parentEvalId` filter. Which round(s) get synced to GCW, and does GCW represent multiple round evals per solicitation?
3. **Winning vendors / award creation:** `getWinningVendorAndBasicInformation(evaluationIds[])` — winners must come from the **final round**; confirm which `evaluationIds` GCW passes and whether award docs (`appianDocumentIds`) resolve to the final round's carried docs.
4. **eval↔solic mapping:** created once for the root; do later rounds need re-mapping in GCW?
5. **Two sync mechanisms** (APPREF vs HTTP) — resolve which is active before assessing multi-round behavior.

## 9. Verification appendix
- Mechanism: `AS_GSS_APPREF_GCW_STARTPROCESS_syncEvalStatusInGcw` (`_…18001846`) — `AS_FRM_getRuleReferenceOrNoOp` pattern.
- GCW sync entrypoint: `_…17809602` → `cons!AS_GCW_GSS_PM_SYNC_EVALUATION_STATUS_LIST_RECORD`.
- Eval-details display: `_…16906534` → `_…16904747` (match evaluationNumber=PIID + sourceApplication=AM + isActive, SINGLE).
- Winning vendors: `_…18080306` → `_…18080158` (`evaluationIds` list; isWinningVendor = decisionType SELECT).
- Status list Web API: `AS_GSS_WA_GET_EvaluationStatusList` `_…17688586` (no parentEvalId filter).
- Triggers: eval↔solic map from PM `0002ec9e-6500` node "Construct Eval Solic Map"; HTTP sync from PM `0006ef1c` "Sync Eval Status in GCW".
- Inventories: `listExpressionRules(GSS, "APPREF_GCW")` (13), `listExpressionRules(GCW, "APPREF_GSS")` (9), `listExpressionRules(GCW, "ENTRYPOINT_GSS")`.
