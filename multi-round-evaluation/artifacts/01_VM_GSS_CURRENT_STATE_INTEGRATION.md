# 01 — VM ↔ GSS Integration: Current-State Mapping (Phase 1)

> **Purpose:** a complete, evidence-based description of how **Government Source Selection (GSS)** and **Vendor Management (VM)** integrate today — every endpoint in both directions, what triggers each flow and when, the exact data exchanged, and what changes in the receiving application. This is the *current state* (pre-multi-round-awareness). Multi-round impact is Phase 2 (`02_…`); §9 here lists the seams as a bridge only.
>
> **Verified** against live objects in **both** applications via the `lcp` MCP server (2026-08-27). GSS = `AS GSS Full Application` (`_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`); VM = `AS VM Full Application` (`_a-0000e79a-fc04-8000-9bf4-011c48011c48_2088050`).

---

## 1. Executive summary

GSS and VM are two separate Appian applications that exchange **opportunity, vendor, proposal-document, and vendor-action** data over HTTP (Appian integrations → Appian Web APIs), in **both directions**. The relationship is:

- **VM owns** the opportunity/solicitation, the vendors, and their submitted proposals + proposal documents.
- **GSS owns** the evaluation. When a Contracting Officer (CO) runs an evaluation, GSS **pulls** the opportunity + vendors + proposal documents from VM into its own `Evaluation*` records, and **pushes back** to VM which vendors it has added/removed. VM, in turn, **pushes** proposal submission/withdrawal events to GSS and **pulls** the GSS evaluation status/link to show on its opportunity summary.

**The join key between the two systems is the solicitation identifier**, called **`noticeId`** in VM (`AS_VM_Opportunity.noticeId`) and **`evaluationNumber`** in GSS (`AS_GSS_Evaluation.evaluationNumber`). Vendor identity is correlated by VM's internal **`vendorId`** (stored in GSS as `externalVendorId`) and by **`uniqueEntityId` (UEI)**.

**Two master toggles** gate the entire integration:
- GSS side: `cons!AS_GSS_BOL_VENDOR_MANAGEMENT_INTEGRATION_TOGGLE`
- VM side: `cons!AS_VM_BOL_SOURCE_SELECTION_INTEGRATION_TOGGLE`

If either is off, the corresponding outbound calls are skipped.

---

## 2. Connection topology (connected systems)

| Direction | Caller app | Connected system (in caller) | UUID | Auth |
| :--- | :--- | :--- | :--- | :--- |
| GSS → VM | GSS | **AS GSS CS Vendor Management** | `_a-0000ed77-8e71-8000-9df8-011c48011c48_15308175` | API Key, header `Appian-API-Key` |
| VM → GSS | VM | **AS VM CS Source Selection** ("Holds connection to GSS") | `_a-0001ed6e-54f1-8000-9df6-011c48011c48_15245177` | (HTTP; API key/service acct) |

Each app calls the **other app's Web APIs** through its connected system. All Web APIs on both sides are `isPublic:false`.

```
        ┌─────────────────────────────┐         ┌─────────────────────────────┐
        │            GSS              │          │             VM              │
        │  (Evaluation is the owner)  │          │ (Opportunity/Vendor/Proposal│
        │                             │          │        are the owner)       │
        │  Integrations ─────────────┼── GSS→VM ─┼──▶ Web APIs                 │
        │  (AS GSS CS Vendor Mgmt)    │          │   (getOppDetailsForEval,    │
        │                             │          │    getVendorDetailsForEval, │
        │                             │          │    getVendorIdentifier,     │
        │                             │          │    downloadVmDocument,      │
        │                             │          │    updateProposalVendorAction)
        │                             │          │                             │
        │  Web APIs ◀─────────────────┼── VM→GSS ─┼── Integrations              │
        │  (getEvaluationDetailsForVm,│          │   (AS VM CS Source Selection)│
        │   vendor-proposal-action)   │          │                             │
        └─────────────────────────────┘         └─────────────────────────────┘
```

---

## 3. Integration surface (index)

### GSS → VM (5 GSS integrations → 5 VM Web APIs)
| # | GSS integration (UUID) | HTTP + VM path | VM Web API (UUID) | VM handler rule (UUID) |
| :-- | :--- | :--- | :--- | :--- |
| A | `AS_GSS_INT_GET_OpportunityDetailsFromVM` (`d31a006f-71bc-43c1-bfce-ede5b3b47db5`) | GET `getOppDetailsForEval?noticeId` | `AS VM WA GET Send Opportunity Details to Evaluation in GSS` (`930b95af-…`) | `AS_VM_WA_getOpportunityDetailsForSSEval_v1` (`_…15267530`) |
| B | `AS_GSS_INT_GET_VendorIdentifierDetails` (`_a-0001eda5-a49c-8000-9e01-011c48011c48_15657984`) | GET `getVendorIdentifierDetails?noticeId&isVendorLinked` | `AS VM WA GET Send Vendor Identifier Details To GSS` (`4f6d587c-…`) | `AS_VM_WA_getVendorIdentifierForGSS_v1` (`_…15590403`) |
| C | `AS_GSS_INT_GET_getVendorsAndDocuments` (`03362418-ac0f-464c-b0ac-648fdb0765af`) | GET `getVendorDetailsForEvaluation?solicitationNumber&startIndex&batchSize&vendorId` (+`Version` hdr) | `AS VM WA GET Send Vendor Details To GSS` (`86c7f59b-…`) | `AS_VM_WA_getVendorDetailsAndDocumentMetadataForGSS_v1` (`_…15304288`) |
| D | `AS_GSS_INT_GET_getProposalDocumentFromVendorManagement` (`d837ec92-…`) | GET `downloadVmDocument?appianDocId` (binary) | `AS VM WA GET Download Proposal Document` (`8477e05d-…`) | (returns document bytes) |
| E | `AS_GSS_INT_POST_updatePropsalForVendorActionToVm` (`_a-0000ed93-2faa-8000-9dfe-011c48011c48_15527747`) | POST `updateProposalVendorAction` | `AS VM WA POST Update Proposal For Vendor Action From GSS` (`8806363a-…`) | `AS_VM_UT_updateProposalDetailsForGSSVendorAction` (`b82baa58-…`) |

### VM → GSS (2 VM integrations → 2 GSS Web APIs)
| # | VM integration (UUID) | HTTP + GSS path | GSS Web API (UUID) | GSS handler rule (UUID) |
| :-- | :--- | :--- | :--- | :--- |
| F | `AS_VM_INT_GET_EvaluationDetailsForOpportunitySummarySS` (`_a-0000ed80-c90f-8000-9dfa-011c48011c48_15369445`) | GET `getEvaluationDetailsForVm?…` | `AS GSS WA GET Send Evaluation Details for VM` (`16008ad4-…`) | `AS_GSS_BL_getEvaluationDetailsForVM_v1` (`_…15278632`) |
| G | `AS_VM_INT_POST_vendorProposalActionToGss` (`b43a77b5-117c-4d0b-8060-f0ab314887eb`) | POST `vendor-proposal-action` | `AS GSS WA POST Vendor Proposal Action` (`f12130d6-…`) | `AS_GSS_mapVendorUpdatesToRecord` (`_…15443462`) |

---

## 4. GSS → VM flows (detailed)

### Flow A — Get Opportunity Details from VM  *(read / display)*
- **Trigger:** GSS UI. Consumed by 3 GSS interfaces (e.g. evaluation summary / create-evaluation screens — dependents `_a-…15003193`, `_a-…14412361`, `_a-…15321422`). Read-only display; no writes.
- **Request:** `GET getOppDetailsForEval?noticeId={evaluation.evaluationNumber}`, header `Version:1`.
- **VM does:** `AS_VM_WA_getOpportunityDetailsForSSEval_v1` queries `AS_VM_Opportunity` by `noticeId` (isActive=true).
- **VM returns (200):**
  `{ opportunityId, noticeId, opportunityTitle, opporStatusRefId, opporStatusRefLabel, opporStage (computed by AS_VM_BL_getOpportunityStageByDueDates), isSealedBid, sealedBidDetails:{statusRefId, statusRefLabel}, opportunityUrl }`. 400 if `noticeId` blank; 204 `NO_DATA` if no opportunity.
- **What changes:** nothing (GSS displays it).

### Flow B — Get Vendor Identifier Details  *(read / lightweight identifiers)*
- **Trigger:** GSS rule `_a-0000ed9c-6a3c-8000-9e00-011c48011c48_15617141`.
- **Request:** `GET getVendorIdentifierDetails?noticeId={PIID}&isVendorLinked={1|0}` (GSS maps boolean `isVendorLinked` → 1/0), header `Version:1`.
- **VM does:** `AS_VM_WA_getVendorIdentifierForGSS_v1` queries `AS_VM_Vendor` joined to `proposals`, filtered `opportunity.opportunityId = (by noticeId)`, `proposal.proposalStatusId = SUBMITTED`, and `Proposal.isEvaluationLinked` = `true` when the flag is set, else (`false OR null`). Sealed-bid gating applies.
- **VM returns:** `{ isSealed, vendorDetails:[ { uniqueEntityId, cage, fein, tin, legalName } ] }`.
- **What changes:** nothing (identifier lookup).

### Flow C — Get Vendors + Proposal-Document Metadata  ⭐ *(the main vendor sync — writes GSS records)*
- **Trigger:** the **Add-Vendors-to-Evaluation** flow. GSS rule `AS_GSS_mapDataFromVMToEvalVendorRecord` (`_…15371691`) calls the integration and maps the result into GSS records; used by rule `AS_GSS_…_15522665` and interface `_a-…14828222` (Add Vendors screen). A sibling rule `AS_GSS_mapDataFromVMToEvaluationDocumentRecord` (`_…15485501`) maps just the documents for one vendor (doc refresh).
- **Request:** `GET getVendorDetailsForEvaluation?solicitationNumber={PIID}&startIndex&batchSize&vendorId={externalVendorId?}`, header `Version:1`.
- **VM does:** `AS_VM_WA_getVendorDetailsAndDocumentMetadataForGSS_v1`:
  - Resolves opportunity by `solicitationNumber`; checks sealed-bid status.
  - Queries `AS_VM_Proposal` (join vendor + vendorPrimaryAddress), filtered: `opportunityId`, `proposalStatusId = SUBMITTED`, `proposalResubmissionId is null`, and — **when no explicit `vendorId`** — `Proposal.isEvaluationLinked = false OR null` (**"available to add"**). Optional `searchText` searches vendor legalName/UEI/CAGE (or legalName/TIN/FEIN under the State-&-Local toggle).
  - Aggregates document counts across proposal versions; pulls proposal documents from `AS_VM_ProposalDocument`.
- **VM returns:** `{ isSealed, totalCount, vendorDetails:[ { basicDetails:{ vendorId, solicitationPiid, legalName, businessName, businessTypeCodes[], addressLine1/2, city, state, country, zipCode, foreignPostalCode, cage, uei(=uniqueEntityId), tin, fein, samGovStatus(null), samGovExpirationDate(=vendor.expirationDate), submittedDate, noOfSubmittedDocuments }, proposalDocuments:[ { appianDocID(=internalAppianDocId), documentName, documentType(=required-proposal-doc name), documentDescription, documentExtension, proposalVersion } ] } ] }`. If sealed-not-unsealed → `{isSealed:true, vendorDetails:null}`.
- **What changes in GSS** (via `AS_GSS_mapDataFromVMToEvalVendorRecord`, on Add Vendors): writes, per returned vendor —
  - **`AS_GSS_EvaluationVendor_SYNCEDRECORD`** (`b6081510`): `evaluationId`(GSS), `legalName`, `businessName`, `cageCode`, `uniqueEntityId`(=uei), `tin`, `fein`, `status`(=samGovStatus), `expirationDate`, `isActive=true`, `isUpdateRequired=false`, **`sourceApplicationId = VM`**, **`externalVendorId = VM vendorId`**, `submittedDate`, `federalIdentifier = UPPER(uei)|UPPER(cage)`, `stateAndLocalIdentifier = UPPER(tin)`.
  - **`AS_GSS_EvaluationVendorAddress_SYNCEDRECORD`** (`c4e07a80`): two rows (Physical + Mailing) with address lines, city (≤100), state, country (+ref lookups), zip (≤5), foreign postal (≤20).
  - **`AS_GSS_EvaluationVendorBusinessType_SYNCEDRECORD`** (`28b193af`): one `typeCode` row per business-type code.
  - **`AS_GSS_EvaluationDocument_SYNCEDRECORD`** (`9c497e08`) per proposal doc: `appianDocId`(=VM internalAppianDocId), `documentName`, `version`(=proposalVersion), `fileType`(=extension), `evaluationId`, `docType = VENDOR`, `documentSubType`(=documentType), `documentDescription`, `isDeleted=false`, **`sourceApplicationId = VM`**, and (if a default factor is passed) a `FactorDocumentMapping` (`acd503e1`) row.

### Flow D — Download Proposal Document  *(binary passthrough)*
- **Trigger:** CO opens/downloads a vendor's proposal document in GSS (the EvaluationDocument stores VM's `appianDocId`).
- **Request:** `GET downloadVmDocument?appianDocId={appianDocId}`, header `Version:1`, `usage:MODIFY`, `responseBodyParsing:CONVERT_BINARY`.
- **VM does / returns:** `AS VM WA GET Download Proposal Document` streams the proposal document bytes for that Appian doc id.
- **What changes:** nothing persistent (document fetched for viewing/download).

### Flow E — Update Vendor Action to VM  ⭐ *(GSS pushes add/remove → writes VM)*
- **Trigger:** GSS process model **`AS GSS Update Vendor Action to VM`** (`0002ed96-24ce-8000-cdcd-7f0000014e7a`).
  - **Params:** `evaluation` (Evaluation record), `evaluationVendors[]` (EvaluationVendor records), `isAddAction` (Boolean).
  - **Guard (XOR "Is Req Info Available?"):** proceeds only if `isAddAction` and `evaluationVendors.externalVendorId` are non-null **and** `cons!AS_GSS_BOL_VENDOR_MANAGEMENT_INTEGRATION_TOGGLE` is on; else ends.
  - **"Notify VM" node:** calls integration E with body = `rule!AS_GSS_BL_constructVendorActionDetailsForVM(evaluation, evaluationVendors, isAddAction)`. On failure → Send Alert Email.
- **Request:** `POST updateProposalVendorAction`, JSON body `{ solicitationPiid, vendorId:[…externalVendorId…], actionType }` (`actionType` = add vs remove), header `Version:1`.
- **VM does (`AS_VM_UT_updateProposalDetailsForGSSVendorAction`):** resolves opportunity by `solicitationPiid = noticeId`; queries `AS_VM_Proposal` by `opportunityId + vendorId`; then:
  - `actionType = AS_VM_ACTION_TYPE_ADD_VENDOR_FROM_GSS` → set **`Proposal.isEvaluationLinked = 1`**.
  - `actionType = AS_VM_ACTION_TYPE_REMOVE_VENDOR_FROM_GSS` → set **`Proposal.isEvaluationLinked = 0`**.
- **What changes in VM:** the vendor's `Proposal.isEvaluationLinked` flag. **This is the dedup mechanism** — once linked (added to a GSS evaluation), the vendor is excluded from Flow B/C "available to add" results.

---

## 5. VM → GSS flows (detailed)

### Flow F — Get Evaluation Details for VM  *(VM reads GSS eval status + deep link)*
- **Trigger:** VM rule `AS_VM_BL_getEvaluationStatusFromGssBasedOnNoticeId` (`_…15476791`), used by VM interface `_a-0000ed80-c90f-8000-9dfa-011c48011c48_15369850` (the VM **opportunity summary** shows the linked GSS evaluation's status + a link). VM integration `AS_VM_INT_GET_EvaluationDetailsForOpportunitySummarySS` (`_…15369445`).
- **Request:** `GET getEvaluationDetailsForVm` with the solicitation PIID.
- **GSS does (`AS_GSS_BL_getEvaluationDetailsForVM_v1`):** queries `AS_GSS_Evaluation` by `evaluationNumber = solicitationPiid` (isActive=true), SINGLE_OBJECT.
- **GSS returns (200):** `{ solicitationPiid(=evaluationNumber), evaluationTitle, evaluationStatus(=status refLabel), evaluationStatusRefId, evaluationUrl }`, where `evaluationUrl = a!urlForRecord(AS_GSS_Evaluation_RECORD, Source Selection site → evaluations page, evaluationId)`. 400 if PIID blank; 204 if none.
- **What changes:** nothing in GSS (VM displays it).

### Flow G — Vendor Proposal Action to GSS  ⭐ *(VM pushes submit/withdraw → writes GSS)*
- **Trigger:** VM process model **`AS VM Update Vendor Action to GSS`** (`0002ed86-72ca-8000-cc5a-7f0000014e7a`).
  - **Params:** `opportunityId`, `proposalAction`, `proposalId`.
  - **Guards:** XOR "Check GSS Toggle" (`cons!AS_VM_BOL_SOURCE_SELECTION_INTEGRATION_TOGGLE`) → "Is Opportunity Sealed" (`AS_VM_UT_checkIfOpportunityIsSealedByOpportunityId`) → XOR **"Opportunity Sealed": YES ⇒ end (do NOT notify GSS)**, NO ⇒ Notify GSS. So a sealed-but-not-unsealed opportunity **withholds** proposal actions from GSS.
  - **"Notify GSS" node:** calls integration G with body = `rule!AS_VM_BL_constructVendorAndProposalDetailsForGSS(proposalId, proposalAction)`. On failure → Send Error Email.
- **Request:** `POST vendor-proposal-action`, header `version:1`, JSON body =
  `{ noticeId, opportunityTitle, vendorId, legalName, uei(=vendor.uniqueEntityId), cage, tin, fein, proposalId, proposalVersion(=version), proposalAction, proposalActionTimestamp(=proposal.submittedDate) }`.
- **GSS does (`AS_GSS_mapVendorUpdatesToRecord`):**
  1. Matches `AS_GSS_Evaluation` by `evaluationNumber = trim(noticeId)` (isActive=true, SINGLE_OBJECT).
  2. Matches `AS_GSS_EvaluationVendor` by **(sourceApplicationId=GSS AND federalIdentifier/stateAndLocalIdentifier composite) OR (sourceApplicationId=VM AND externalVendorId = vendorId)**.
  3. Deactivates prior vendor-update rows (`AS_GSS_deActivatePreviousExternalVendorUpdates` by externalVendorId + evaluationNumber).
  4. Writes a new **`AS_GSS_VendorUpdates_SYNCEDRECORD`** (`8a8be667`) row: `externalVendorId`, `evaluationId`, `evalVendorId`(=matched EvaluationVendor.vendorId), `evaluationNumber`, `legalName`, `uei`, `cage`, `tin`, `fein`, `proposalId`, `proposalVersion`, `proposalActionId` (mapped from `proposalAction` via `AS_GSS_UT_mapProposalActionToReferenceData`), `proposalActionDatetime`, **`sourceApplicationId = VM`**, `isActive=true`.
- **What changes in GSS:** a `VendorUpdates` record is created (and previous ones for that vendor+notice deactivated) — GSS's record that a vendor submitted/withdrew/updated a proposal in VM (surfaced to the CO as a vendor-update notification). It does **not** mutate the EvaluationVendor itself.

---

## 6. Data dictionary — record types touched

### GSS (owner of the evaluation)
| Record type | UUID | Role in integration |
| :--- | :--- | :--- |
| `AS_GSS_Evaluation_SYNCEDRECORD` | `e6bc8561-…` | `evaluationNumber` (`b8cdd695`) = solicitation PIID = **join key**; `evaluationStatusId` (`4e467ee1`); `isActive` (`058baf74`); `parentEvalId` (`6889c500`, multi-round); `evaluationTitle` (`1aabcd17`). |
| `AS_GSS_EvaluationVendor_SYNCEDRECORD` | `b6081510-…` | Vendor copied from VM. PK `vendorId` (`757685e2`); `externalVendorId` (`8c8bf891`) = VM vendorId; `sourceApplicationId` (`a66e9a7a`); `uniqueEntityId` (`1b15a370`); `federalIdentifier` (`e1a1e205`)=UEI\|CAGE; `stateAndLocalIdentifier` (`614f816b`)=TIN; `evaluationId` (`f99475b5`). |
| `AS_GSS_EvaluationVendorAddress_SYNCEDRECORD` | `c4e07a80-…` | Physical + Mailing address rows. |
| `AS_GSS_EvaluationVendorBusinessType_SYNCEDRECORD` | `28b193af-…` | `typeCode` per business type. |
| `AS_GSS_EvaluationDocument_SYNCEDRECORD` | `9c497e08-…` | Proposal doc copied from VM. `appianDocId` (`fb650755`)=VM internalAppianDocId; `evaluationId` (`f1f3c4f7`); `vendorId` (`7771b188`); `docType`=VENDOR; `sourceApplicationId` (`61cfca97`). |
| `AS_GSS_VendorUpdates_SYNCEDRECORD` | `8a8be667-…` | Proposal-action notifications from VM (Flow G). |
| `AS_GSS_FactorDocumentMapping_SYNCEDRECORD` | `acd503e1-…` | Optional factor↔doc link on import. |

### VM (owner of opportunity/vendor/proposal)
| Record type | UUID | Role in integration |
| :--- | :--- | :--- |
| `AS_VM_Opportunity_SYNCEDRECORD` | `97bd7235-…` | `noticeId` (`bc20c251`) = **join key**; `opportunityId` (`9e70089f`); `opportunityTitle` (`5424409a`); `isSealedBid` (`69c51c45`); `sealedBid` rel (`c29cfa06`). |
| `AS_VM_Proposal_SYNCEDRECORD` | `99278686-…` | `proposalId` (`e75f735a`); `version` (`39ded9cc`); `submittedDate` (`a5807327`); `documentCount` (`5f61f933`); `proposalStatusId` (`ef6ad2a8`); **`isEvaluationLinked` (`07d880b9`)** = dedup flag; `opportunityId` (`17966d68`); `vendorId` (`d5662a75`); `proposalResubmissionId` (`4a9d7a96`); `vendor` rel (`5b9603c7`); `opportunity` rel (`0bf5405c`). |
| `AS_VM_Vendor_SYNCEDRECORD` | `2a81070d-…` | `vendorId` (`34a5a943`); `legalName` (`2ede2f17`); `uniqueEntityId` (`528a403f`); `cage` (`88bb5c38`); `tin` (`0df41fc9`); `fein` (`0afa6cc3`); `expirationDate` (`525fa3f1`); `proposals` rel (`b49da6e4`); `vendorPrimaryAddress` rel (`2e813432`). |
| `AS_VM_ProposalDocument_SYNCEDRECORD` | `cff60c1b-…` | `mappingId` (`88d626d5`); `internalAppianDocId` (`02da7fbd`); `documentName` (`f9e08ea1`). |
| `AS_VM_VendorBusinessTypes_SYNCEDRECORD` | `cce87cf7-…` | Vendor business-type codes. |

---

## 7. Identity & provenance model (important)

- **Solicitation join key:** VM `Opportunity.noticeId` == GSS `Evaluation.evaluationNumber`. Every cross-app call keys on this string.
- **Vendor identity across the boundary:**
  - GSS `EvaluationVendor.externalVendorId` = VM `Vendor.vendorId` (VM's internal PK).
  - GSS `EvaluationVendor.uniqueEntityId` = VM `Vendor.uniqueEntityId` (UEI).
  - GSS also builds composite identifiers: `federalIdentifier = UEI|CAGE`, `stateAndLocalIdentifier = TIN` — used to re-match a vendor on the inbound proposal-action (Flow G) for GSS-sourced vendors.
- **Provenance tag:** every imported vendor/doc carries `sourceApplicationId = VM` (`cons!AS_GSS_REF_ID_SOURCE_APPLICATION_VM`); GSS-native records carry `…_GSS`. Flow G matches on this to distinguish VM-origin vs GSS-origin vendors.
- **Document identity:** the actual file lives in VM; GSS stores only the VM `appianDocId` and fetches bytes on demand (Flow D). No file copy occurs at import — only metadata.

---

## 8. Cross-cutting behaviors

- **Master toggles:** Flow E is gated by `AS_GSS_BOL_VENDOR_MANAGEMENT_INTEGRATION_TOGGLE`; Flow G by `AS_VM_BOL_SOURCE_SELECTION_INTEGRATION_TOGGLE`. Both push flows no-op if their toggle is off.
- **Sealed-bid gating:** VM withholds vendor data while an opportunity is a sealed bid **not yet unsealed** — Flows B & C return `{isSealed:true, vendorDetails:null}`, and Flow G is skipped entirely (VM PM ends on "Opportunity Sealed = YES"). Once unsealed, data flows normally.
- **Dedup ("available to add"):** VM's vendor lists (B, C) default to `Proposal.isEvaluationLinked = false OR null`; adding a vendor in GSS flips it to `1` via Flow E, removing flips it to `0`. So VM only offers vendors not currently linked to a GSS evaluation.
- **Submitted-only:** VM only exposes proposals with `proposalStatusId = SUBMITTED` and `proposalResubmissionId is null` (latest, non-superseded submissions); document counts sum across versions.
- **Error handling:** both push PMs route integration failures to a "Send (Alert/Error) Email" branch; GET handlers return structured `{error, message}` bodies (`INVALID_INPUT`, `NO_OPPORTUNITY`, `NO_PROPOSAL`, `NO_DATA`).
- **Tooling note:** Web API expression bodies are not exposed by MCP (`getWebApi` → `expression:null`); all handler logic above was read from the backing `AS_*_WA_*` / `AS_*_BL_*` / `AS_*_UT_*` expression rules, which are cited by UUID.

---

## 9. Bridge to Phase 2 — seams where multi-round may interact (NOT analysis)

*Listed here only to scope Phase 2; the actual impact assessment is deferred until this doc is reviewed.*

1. **Solicitation-PIID → evaluation is assumed 1:1.** Multi-round makes it 1:N (anchor + round clones share `evaluationNumber`). Both inbound handlers (F: `getEvaluationDetailsForVM`; G: `mapVendorUpdatesToRecord`) query `AS_GSS_Evaluation` **SINGLE_OBJECT by `evaluationNumber` + `isActive` with no `parentEvalId` filter** — behavior with multiple active round clones is the first thing to examine.
2. **Dedup flag `isEvaluationLinked` is per-opportunity, not per-round.** Adding a vendor in any round flips it globally; re-including a vendor in a later round (a core multi-round requirement) may conflict with VM's "available to add" filter.
3. **Vendor-action push (Flow E)** sends only `{solicitationPiid, vendorId[], actionType}` — no round/evaluationId context; VM can't tell which round acted.
4. **Vendor identity per round:** GSS `EvaluationVendor.vendorId` is a per-round PK, while `externalVendorId`/UEI are stable across rounds — Flow G's matching (externalVendorId OR federal/state identifier) needs checking against round clones.
5. **Sealed-bid + rounds** interaction.

---

## 10. Evidence appendix (re-verification pointers)
- GSS integrations: `getIntegration <uuid>` for A–E.
- VM Web APIs → read backing rules: `getExpressionRule` on `_…15267530` (A), `_…15590403` (B), `_…15304288` (C), `b82baa58` (E-VM), plus `8477e05d` Web API (D).
- GSS handlers/consumers: `_…15278632` (F), `_…15443462` (G), `_…15371691` + `_…15485501` (C-consumers), `_…15454302` (proposal-action ref-data mapper).
- VM→GSS payload: `_…15400091`; VM eval-status consumer: `_…15476791`.
- Triggers: `getProcessModel 0002ed96` (GSS→VM), `getProcessModel 0002ed86` (VM→GSS).
