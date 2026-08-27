# 07 — Cross-Application Impact Research (Multi-Round Evaluations)

> **Purpose of this doc:** the kickoff + working notes for assessing how **Multi-Round Evaluations** affects GSS's integrations with other applications. A fresh agent should be able to start the research from this doc alone. Read §1 (why), §2 (what multi-round changed that matters to integrations), §3 (integration inventory — verified), §4 (per-integration impact hypotheses + questions), §5 (how to research), §6 (open questions / findings log).
>
> Status: **research not started.** Build phases WI-1 (Start Evaluation as Round 1), WI-2 (Start Round), WI-3 (Complete Round + Setup New Round gating) are done on the MCP side (see `03_AGENT_ONBOARDING.md` §10.45–10.49 and `02_PROGRESS_TRACKER.md`). This phase is **analysis/impact only** — do not change integrations until impact is understood and the team confirms scope.

---

## 1. Why this research
Multi-round changed the **shape and lifecycle of the Evaluation record**. GSS exchanges evaluation/vendor/proposal/status data with several external systems. Those integrations were designed when **one solicitation = one evaluation**. Multi-round makes **one solicitation = one anchor evaluation + N round-clone evaluations**, each with its own `evaluationId`, its own status lifecycle, and its own vendors/factors/documents. Every integration that keys on "the evaluation" or "the solicitation" must be re-examined for correctness under this new model.

**Goal:** for each integration (inbound and outbound), determine whether multi-round breaks assumptions, duplicates data, or needs round-awareness — and record concrete findings + recommended changes.

---

## 2. What multi-round changed (the mechanics integrations must cope with)
Anchor these against every integration in §3.

1. **N evaluations per solicitation.** A round = a full clone of `AS_GSS_Evaluation_SYNCEDRECORD` (`e6bc8561…`). Root keeps `parentEvalId = null`; each round clone sets `parentEvalId = anchor` (= `coalesce(source.parentEvalId, source.evaluationId)`). Family resolves via `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation`.
   - ⇒ Any integration that assumes a single `evaluationId` per solicitation/PIID now sees **multiple**.
2. **New `AS_GSS_EvaluationRound_SYNCEDRECORD` (`931e8145…`)** — one row per round (evaluationId, sequence, roundName, start/end, isOnSpotConsensus). Sequence 1 = root/Round 1.
3. **Per-round status lifecycle:** each round eval goes `SETTING_UP → INPROGRESS (Start Round) → COMPLETE (Complete Round)`. The solicitation is "active" across several evals over time; **multiple evals share one solicitation PIID**.
4. **New actions/flows:** Start Evaluation (BV) creates Round 1 on the root; **Start Round** (reuses `0002ecdd…`) starts a child round; **Complete Round** (reuses `0004e60d…` Mark Complete) completes a round; **Setup New Round** clones the next round (gated: only when all existing rounds COMPLETE).
5. **Vendors/documents carried per round.** `AS_GSS_UT_duplicateEvaluationForNewRound` (v9) copies down-selected vendors + their documents into the new round clone (each round has its **own** EvaluationVendor / EvaluationDocument rows, new `vendorId`s per round). Vendors correlate across rounds by **`uniqueEntityId`** (NOT `vendorId`, which changes each round; `vendorRefId` is null).
6. **Factors scoped per round.** Only carried factors exist as Criteria on a round clone.

**Key risk themes:** (a) solicitation-PIID→evaluation is now 1→N; (b) status sync now emits N evals per solicitation; (c) vendor identity differs per round (`vendorId` reused/re-minted); (d) proposal-document actions target a specific round's vendor rows.

---

## 3. Integration inventory (verified via MCP, 2026-08-27)
App UUID `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`. 7 connected systems, 15 integrations, 5 Web APIs.

### 3.1 Connected systems
| Name | UUID | Type | Purpose |
| :--- | :--- | :--- | :--- |
| AS GSS CS Vendor Management (**VM**) | `_a-0000ed77-8e71-8000-9df8-011c48011c48_15308175` | system.http (API Key hdr `Appian-API-Key`) | Connection to Vendor Management |
| AS GSS CS Source Selection | `_a-0000ed80-c90f-8000-9dfa-011c48011c48_15369835` | system.http | Connection to source selection system (external doc fetch) |
| AS GSS CS Contract Writing (**GCW**) | `_a-0000ef29-4c7b-8000-9e6a-011c48011c48_18163326` | system.http | Connection to contract writing system |
| AS GSS DRM CS GAM Suite Management (**GSM/DRM**) | `_a-0000ee30-1118-8000-9e27-011c48011c48_16420589` | system.http | Start vendor data reconciliation in GSM |
| AS GAM CS Search API for SAM gov | `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_939151` | system.http | SAM.gov vendor lookup |
| AS GAM CS Microsoft Graph | `_a-0000e49f-7b90-8000-9bac-011c48011c48_188179` | system.http | Office 365 / SharePoint |
| AS GSS Azure OpenAI | `_a-0000eb28-f476-8000-9d09-011c48011c48_9647900` | plugin (Azure OpenAI) | GenAI (consensus summarization) |

### 3.2 Integrations (GSS → external)
**VM (all inherit VM base URL; `Version` header):**
| Integration | UUID | Endpoint / method | Data |
| :--- | :--- | :--- | :--- |
| `AS_GSS_INT_GET_OpportunityDetailsFromVM` | `d31a006f-71bc-43c1-bfce-ede5b3b47db5` | GET `getOppDetailsForEval?noticeId=` | in: solicitation PIID → out: opportunity details |
| `AS_GSS_INT_GET_VendorIdentifierDetails` | `_a-0001eda5-a49c-8000-9e01-011c48011c48_15657984` | GET `getVendorIdentifierDetails?noticeId=&isVendorLinked=` | in: PIID + isVendorLinked(1/0) → out: vendor identifiers |
| `AS_GSS_INT_GET_getVendorsAndDocuments` | `03362418-ac0f-464c-b0ac-648fdb0765af` | GET `getVendorDetailsForEvaluation?solicitationNumber=&startIndex=&batchSize=&vendorId=` | out: vendors + documents |
| `AS_GSS_INT_GET_getProposalDocumentFromVendorManagement` | `d837ec92-7122-4071-b0f9-890127f35676` | GET `downloadVmDocument?appianDocId=` (binary) | out: proposal document bytes |
| `AS_GSS_INT_POST_updatePropsalForVendorActionToVm` | `_a-0000ed93-2faa-8000-9dfe-011c48011c48_15527747` | POST `updateProposalVendorAction` | body `{solicitationPiid, vendorId:[…], actionType}` |
| `AS_GSS_INT_GET_getVendorsAndDocuments` uses paging (startIndex/batchSize). | | | |

**GCW (Contract Writing):**
| `AS_GSS_INT_POST_SyncEvaluationStatusList` | `4a8a979c-cc4f-4f18-846b-4593bb774cca` | POST → GCW | triggers GCW to sync the evaluation **status list** |

**Source Selection CS:**
| `AS_GSS_INT_POST_fetchDocumentFromExternalSource` | `d63f6101-7f12-4154-ab88-4ed3517509b0` | POST | converts fetched external doc → Appian value (pairs with the Web APIs below) |

**GSM / DRM (vendor data reconciliation):**
| `AS_GSS_DRM_INT_GET_DataReconciliationStatus` | `_a-0000ee30-1118-8000-9e27-011c48011c48_16420608` | GET | reconciliation status from GSM |
| `AS_GSS_DRM_INT_POST_DataReconciliation` | `_a-0000ee30-1118-8000-9e27-011c48011c48_16421193` | POST | start reconciliation in GSM |

**GenAI / SAM / SharePoint (adjacent, likely low multi-round impact):** `AS_GSS_INT_summarize_ConsensusResponsesOrFinalComment` (Azure OpenAI); `AS_GAM_GetVendorDetailsFromSAMGov`; `AS_GAM_CreateFolderInSharepoint` / `…UploadDocumentToSharepoint` / `…DownloadDocumentFromSharepoint` / `…GetDocumentLinkFromSharepoint` (MS Graph).

### 3.3 Web APIs (external → GSS)
| Web API | UUID | Method / alias | Purpose |
| :--- | :--- | :--- | :--- |
| AS GSS WA GET Send Evaluation Details for VM | `16008ad4-d3d4-438b-b507-ad596b378993` | GET `getEvaluationDetailsForVm` | GSS → VM: evaluation details + GSS site URL |
| AS GSS WA POST Vendor Proposal Action | `f12130d6-9046-4cd1-bdb3-ec4ae84bcd64` | POST `vendor-proposal-action` | VM → GSS: vendor proposal action |
| AS GSS WA GET Evaluation Status List | `433d67e2-26f5-4212-9ced-1e408aa9fddf` | GET `evaluationList` | GCW → GSS: eval list + status (feeds GCW sync) |
| AS GSS WA POST Fetch Document From External Source | `b4a8eaa9-aec8-4bd1-8921-96c3fea735b0` | POST `fetchDocumentFromExtSource` | single-click external doc download (support) |
| AS GSS WA GET Browser Download Link From External Source | `776f4231-2d11-4f9a-9f72-91e1138da763` | GET `fetchDocumentFromExtSource` | returns fetched doc as HTTP response (support) |

> **Tooling limitation:** `getWebApi` returns `expression: null` via MCP in this env — Web API bodies can't be read directly. To see payload construction, trace the **expression rules** the Web API calls (search `AS_GSS_…` rules by the alias/topic, or use `getObjectDependents` on the record types/rules involved).

---

## 4. Per-integration impact hypotheses (to confirm/deny in research)
Priority ordered by likely multi-round impact.

### 4.1 GCW — Evaluation Status Sync ⚠️ HIGH
- `evaluationList` Web API + `…POST_SyncEvaluationStatusList` push evaluation statuses to GCW.
- **Hypothesis:** GCW expected one evaluation per solicitation; now the status list contains the anchor **and every round clone** (each with SETTING_UP/INPROGRESS/COMPLETE). GCW may show duplicate/confusing evaluations per solicitation, or mis-track "the" evaluation status.
- **Questions:** Does `evaluationList` filter to anchors only, latest round, or emit all? Should GCW see per-round status or a single rolled-up status? Does GCW key on `evaluationId` or solicitation PIID?
- **Where to look:** the rule behind `evaluationList` (Web API expression is null — find via dependents of `AS_GSS_Evaluation` record / search rules referencing "EvaluationStatusList" / "GCW"); `AS_GSS_INT_POST_SyncEvaluationStatusList` request body.

### 4.2 VM — Vendors / Proposals ⚠️ HIGH
- VM integrations key on **solicitation PIID / solicitationNumber** and **vendorId**.
- **Hypotheses:**
  - `getVendorsAndDocuments` / `VendorIdentifierDetails` fetch by PIID — fine, but the **`isVendorLinked` filter** ("vendors yet to be added to the evaluation") must be interpreted per **which** round/evaluation now.
  - `updatePropsalForVendorActionToVm` posts `{solicitationPiid, vendorId[], actionType}` when vendors are added/removed. Under multi-round, add/remove happens per round (down-select). Does VM need to know **which round**? The payload has no round/evaluationId — only PIID + vendorId. Vendor add/remove between rounds may be mis-signaled to VM.
  - `vendorId` differs per round (correlate by `uniqueEntityId`). The VM `vendorId` is the **external** id — confirm whether the VM vendorId is stable across rounds while the GSS EvaluationVendor.vendorId is per-round.
  - Inbound `vendor-proposal-action` (VM→GSS): when VM pushes a proposal action, **which round eval** does GSS apply it to? Likely the active (INPROGRESS) round — confirm the handler resolves the right round.
  - `getEvaluationDetailsForVm` returns "evaluation details + site URL" — with N round evals, which evaluation/site URL is returned for a PIID?
- **Where to look:** rules that call each VM integration + build the `vendor-proposal-action` / `getEvaluationDetailsForVm` responses; how they resolve evaluationId from PIID.

### 4.3 Proposal / external document download — MEDIUM
- `downloadVmDocument?appianDocId=` + `fetchDocumentFromExtSource` pair. Each round carries its **own** EvaluationDocument rows (copied, same underlying `appianDocId`). Likely OK (doc id stable), but confirm carried-doc `appianDocId` still resolves in VM after round copy.

### 4.4 GSM / DRM — vendor data reconciliation — MEDIUM/LOW
- Reconciliation keyed on vendor data; confirm whether it runs per evaluation or per solicitation, and whether round clones trigger redundant reconciliation.

### 4.5 SAM.gov / SharePoint / Azure OpenAI — LOW
- SAM vendor lookup and GenAI consensus summarization operate on data already in a given evaluation; per-round they should just operate on that round's data. SharePoint folder/doc ops — confirm folder keying isn't per-solicitation in a way that collides across rounds.

---

## 5. How to research (method + starting points)
1. **Find the rule behind each integration/Web API.** Web API expressions are null via MCP → use `listExpressionRules(appUuid, query: <topic>)` and `getObjectDependents` on the integration UUID and on `AS_GSS_Evaluation_SYNCEDRECORD` / `AS_GSS_EvaluationVendor_SYNCEDRECORD`. Dump rules to `/tmp` and read.
2. **Trace PIID→evaluation resolution.** For each inbound flow (vendor-proposal-action, getEvaluationDetailsForVm, evaluationList), find how GSS maps a solicitation PIID to an evaluationId, and whether it now returns anchor-only / latest-round / all.
3. **Inspect the sync/status rule for filtering.** Determine if `evaluationList` already excludes round clones (e.g., filters `parentEvalId` null) — if not, that's a likely defect.
4. **Confirm vendor identity mapping.** Verify `uniqueEntityId` is the cross-round/cross-app stable key and that VM's external vendorId ≠ GSS per-round `EvaluationVendor.vendorId`.
5. **Use the test family.** Root **6** → rounds **10/11/12**; another family **13/14/15**. Solicitation PIIDs on these evals let you probe PIID→eval resolution.
6. **Record findings in §6** with: integration, assumption, whether multi-round breaks it, severity, recommended change (and whether GSS-side or VM/GCW-side).

**Useful field UUIDs:** Evaluation `evaluationId 7f7c2d3b`, `parentEvalId 6889c500`, `evaluationStatusId 4e467ee1`, solicitation/PIID fields TBD (find on Evaluation record — search fields for "solicitation"/"piid"/"noticeId"). EvaluationVendor `vendorId 757685e2`, `uniqueEntityId` (confirm UUID), `documents f017ee11`. EvaluationRound `evaluationId 1756683f`, `sequence d20a1017`.

---

## 6. Findings log (fill during research)
_(empty — record one entry per integration: assumption → impact → severity → recommendation)_

- [ ] GCW `evaluationList` — does it emit round clones?
- [ ] GCW `SyncEvaluationStatusList` body — per-eval or rolled-up?
- [ ] VM `updateProposalVendorAction` — does VM need round context?
- [ ] VM `vendor-proposal-action` (inbound) — which round eval does it target?
- [ ] VM `getEvaluationDetailsForVm` — which eval/site URL per PIID?
- [ ] VM `isVendorLinked` semantics under multi-round.
- [ ] Vendor identity: `uniqueEntityId` vs per-round `vendorId` vs VM external id.
- [ ] Proposal doc `appianDocId` stability across round copies.
- [ ] GSM DRM — per-round redundant reconciliation?
- [ ] SharePoint folder keying collisions across rounds.

---

## 7. Cross-references
- Build status of multi-round objects: `03_AGENT_ONBOARDING.md` §10.45–10.49; live log `02_PROGRESS_TRACKER.md`.
- Multi-round mechanics/anchor convention: `01_FEATURE_AND_TECHNICAL_DESIGN.md`.
- Utility to resolve family/latest round: `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (`…42289`), `AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation` (`…43812`).
