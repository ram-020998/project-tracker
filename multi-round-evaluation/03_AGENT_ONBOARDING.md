# Agent Onboarding — GSS Multi-Round Evaluations

> Read this first if you are a new agent picking up this work. It tells you **what we're building, where everything lives, how to interact with it, and the conventions to follow.**

---

## 1. The 60-second summary

We are adding **Multi-Round Evaluations** to Appian **Government Source Selection (GSS)**. A Contracting Officer can run one Best Value evaluation as **multiple sequential rounds** (down-selects), narrowing the vendor pool each round, instead of creating a new evaluation per phase.

**The central design idea:** *a round is a full clone of the Evaluation record.* Each clone links back to the round‑1 root via `parentEvalId`, and a new `AS_GSS_EvaluationRound_SYNCEDRECORD` table stores round metadata + sequence. This gives per-round Ratings/Consensus/Teams/Factors for free.

Full details: **`01_FEATURE_AND_TECHNICAL_DESIGN.md`**. Live status: **`02_PROGRESS_TRACKER.md`**.

---

## 2. Where everything lives

| Thing | Location |
| :--- | :--- |
| Spec (research + requirements + Q&A) | `GSS_ Multi Round Evaluations.md` (this folder) |
| Mockups | `GSS - Multiround Evaluation (1).pdf` (this folder) · [Figma](https://www.figma.com/deck/U9rGBTKVtpnxLOTNjQmvi8) |
| Design doc | `01_FEATURE_AND_TECHNICAL_DESIGN.md` |
| Progress tracker | `02_PROGRESS_TRACKER.md` |
| This onboarding | `03_AGENT_ONBOARDING.md` |
| **Tabs implementation plan** | `04_TABS_IMPLEMENTATION_PLAN.md` — per-tab treatment, id-vs-record input shapes, record-view urlStubs, work items WI-1..9, sequencing |
| **WI-1 analysis** | `05_START_EVALUATION_WI1_ANALYSIS.md` — current-state analysis of Start Evaluation |
| **WI-1 implementation plan** | `06_START_EVALUATION_WI1_IMPLEMENTATION_PLAN.md` — authoritative build spec for Best Value Start Evaluation as Round 1 (WI-1, shipped) |
| **Cross-app impact research** (ACTIVE phase) | `07_CROSS_APP_IMPACT_RESEARCH.md` — **start here for the current phase**: how multi-round affects GSS↔VM/GCW/GSM/etc. integrations. Integration inventory + impact hypotheses + research method. |
| **Docs git repo** | `/Users/ramaswamy.u/repo/project-tracker` (branch `main`). These docs live under `multi-round-evaluation/`. Commit + push after every session. |
| **The actual code (Appian objects)** | Appian **AS GSS Full Application**, accessed via the **`lcp` MCP server** — there is **no local git repo** for these objects |

**Environment:** `gam-gss-32-innovate.appianpreview.com`
**Application:** AS GSS Full Application · UUID `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`
**Custom-objects app** (for customizations that deploy to higher envs): GSS Custom Objects · UUID `_a-0000f044-2075-8000-9ba6-011c48011c48_41633` (currently empty)

---

## 3. How to interact with the code (lcp MCP)

You do **not** edit local `.sail` files for these objects. You read/modify Appian design objects through the `lcp` MCP tools. Common ones:

- **Discover:** `listApplicationObjects`, `listInterfaces`, `listExpressionRules`, `listRecordTypes` (all take `appUuid`; support a `query` filter).
- **Read:** `getInterface` / `getExpressionRule` (pass `expressionFilePath` to dump the SAIL to a local temp file for reading), `getRecordType`, `listRecordTypeFields`, `listRecordTypeRelationships`.
- **Write:** `updateInterface` / `updateExpressionRule` (edit the temp `.sail` file, then pass the same `expressionFilePath` back), `createInterface`, `createExpressionRule`, `addRecordTypeField`, `addRecordTypeRelationship`, etc.
- **Verify:** `validateDesignObject`, `validateExpression`, `testInterface`, `testRule`, `getObjectDependents`.

**Workflow tip:** when reading a rule/interface, dump it to `/tmp/gss_review/<name>.sail`, read it, and delete the temp dir when done. Always `validateDesignObject` after a change.

---

## 4. Naming conventions (follow these)

GSS objects use prefixes that signal type/layer:
- `AS_GSS_` — GSS solution namespace. `AS_CO_` / `AS_GSS_CO_` — shared/common utilities.
- `_FM_` form/modal interface · `_SEC_` section interface · `_CP_`/`_CPS_` component/component-service interface · `_GRD_` grid.
- `_QR_` query rule · `_UT_` utility rule · `_BL_` business-logic rule.
- `_SYNCEDRECORD` — a synced record type (DB-backed). `_RECORD` — the record object exposing actions/views.
- `cons!AS_GSS_…` constants (status ids, hex colors, enums).

When creating new objects, **match the existing pattern** rather than inventing a new one.

---

## 5. Key objects & UUIDs (quick reference)

**New (this feature):**
| Object | UUID |
| :--- | :--- |
| `AS_GSS_EvaluationRound_SYNCEDRECORD` | `931e8145-3f77-4270-a52a-b51de6e76983` |
| `AS_GSS_FM_startNewRound` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42072` |
| `AS_GSS_SEC_rounds` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42270` |
| `AS_GSS_CP_evaluationSummaryStampField` | `_a-0000e5da-a251-8000-9bbe-011c48011c48_1007655` |
| `AS_GSS_UT_duplicateEvaluationForNewRound` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42160` |
| `AS_GSS_QR_getEvaluationRoundDetails` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42276` |
| `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42289` |
| `AS_GSS_UT_returnIdentifiersForEvaluationRounds` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42301` |
| `AS_GSS_UT_returnViewRenderingConfigFor_Factors` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42412` |
| `AS_GSS_UT_returnLastParticipatedRoundForVendors` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42461` |
| `AS_GSS_CPS_viewEvaluatorTeam_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42490` |
| `AS_GSS_CPS_consensusReportView_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42504` |
| `AS_GSS_FM_evaluationDocumentsTab_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42514` |
| `AS_GSS_TMG_FM_taskAuditActionHistory_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42524` |
| `AS_GSS_CPS_evaluationRatingsTab_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42562` |
| `AS_GSS_TMG_CPS_viewRecordTasks_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42542` |
| `AS_GSS_FM_evaluationAuditHistory_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42552` |
| `AS_GSS_FM_startEvaluationBestValue` (WI-1 modal) | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42569` |
| `AS GSS Start Evaluation Best Value` (WI-1 PM) | `0000f04b-68ab-8000-fbf5-7f0000014e7a` |
| `AS_GSS_FM_startRound` (WI-2 modal) | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42738` |
| `AS GSS Start Round` (WI-2 wrapper PM) | `0000f04b-9451-8000-fc0b-7f0000014e7a` |
| `AS GSS Complete Round` (WI-3 wrapper PM) | `0000f04b-add3-8000-fc11-7f0000014e7a` |
| `AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_43812` |

**Existing core (read-only context):**
| Object | UUID |
| :--- | :--- |
| `AS_GSS_Evaluation_SYNCEDRECORD` | `e6bc8561-d3a6-4679-b7af-6e279910468e` |
| `AS_GSS_Evaluation_RECORD` | `4db4a62e-d099-4e54-be19-41498c17b9cc` |
| `AS_GSS_Criteria_SYNCEDRECORD` | `11dcc745-3c81-49f9-9cb2-6427680e4b41` |
| `AS_GSS_EvaluatorTeam_SYNCEDRECORD` | `791d954b-beae-4171-808f-876583d707fa` |
| `AS_GSS_EvaluatorTeamMembership_SYNCEDRECORD` | `7ac70e31-adcc-4145-a566-fcfe1f55146d` |
| `AS_GSS_CriteriaAssignment_SYNCEDRECORD` | `518a0b4d-1389-4483-8e39-dd103429c2b8` |
| `AS_GSS_EvaluationPhase_SYNCEDRECORD` | `bf3ef3fe-9671-40df-a195-bd71ab8deed8` |
| `AS_GSS_EvaluationVendor_SYNCEDRECORD` | `b6081510-0d11-4d51-8eba-966610b168db` |
| `AS_GSS_EvaluationVendorBusinessType_SYNCEDRECORD` | `28b193af-cca3-4ce3-9837-836838923e60` |
| `AS_GSS_EvaluationDocument_SYNCEDRECORD` | `9c497e08-f4c6-4fbd-bf14-5638dc226230` |

**Evaluation status constants (seen in code):** `AS_GSS_REF_ID_EVALUATION_STATUS_SETTING_UP`, `…_INPROGRESS`, `…_AWARDEES_SELECTED`, `…_COMPLETE`.

**WI-1 / Start Evaluation objects (verified — for the build):**
| Thing | UUID / value |
| :--- | :--- |
| Existing action `startEvaluation` (keep for non-Best-Value) | key `startEvaluation`, PM `0002ecdd-8ec4-8000-bf9c-7f0000014e7a` |
| Existing form `AS_GSS_FM_startEvaluation` (confirm-only; clone from it) | `_a-0000ecda-a664-8000-9dc8-011c48011c48_14286788` |
| Existing visibility rule | `AS_GSS_BL_getRelatedActionVisibilityForStartEvaluation(statusId, evaluationId)` |
| Setup New Round wizard (reuse round-detail + factor-picker components) | `AS_GSS_FM_startNewRound` `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42072` |
| Sub-proc: Generate Evaluation Tasks | `0002edab-48b7-8000-cee8-7f0000014e7a` |
| Sub-proc: Generate Evaluation Tasks Per Assignee (MNI) | `000aedab-3243-8000-cedd-7f0000014e7a` |
| Leaf rule: factor×vendor task builder | `AS_GSS_generateEvaluationTasksForAssignee` `_a-0000edaa-0a95-8000-9e03-011c48011c48_15676146` |
| Rule: assignee→factors grouping | `AS_GSS_UT_constructAssigneeWithMappedCriteria` |
| Rule: transactional ratings (factor-scoped) | `AS_GSS_BL_createTransactionalRatings` `_a-0000ecda-a664-8000-9dc8-011c48011c48_14296322` |
| Sub-proc: Create Consensus Reports | `0003ece5-8031-8000-bff8-7f0000014e7a` |
| Sub-proc: Generate LPTA Task (EXCLUDE from Best Value PM) | `0002ee10-7d81-8000-d4cf-7f0000014e7a` |
| Sub-proc: Sync Eval Status in GCW | `0006ef1c-885e-8000-e8da-7f0000014e7a` |
| Sub-proc: Trigger Reqt Extraction (behind `cons!AS_GSS_TOGGLE_VENDOR_ANALYSIS_ENABLED`) | `0005ef63-71ba-8000-ebfe-7f0000014e7a` |
| Sub-proc: Capture Audit (`AS_GSS_UT_constructStartEvaluationAudit`) | `0007e5df-28c1-8000-0dd7-7f0000014e7a` |
| Duplicate-for-new-round rule (round-creation reference) | `AS_GSS_UT_duplicateEvaluationForNewRound` `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42160` |
| Method const: Best Value = 5 · LPTA = 67 | `cons!AS_GSS_REF_ID_EVALUATION_METHOD_BEST_VALUE` / `…_LPTA` |
| Task record type | `AS_GSS_TMG_Task_SYNCEDRECORD` `9a04b944-b726-41f5-9b37-8ec71b6cc370` |
| Rating record type | `AS_GSS_Rating_SYNCEDRECORD` `49daf634-1b3a-4396-99e9-f95bff85ff03` |

**Field UUID cheat-sheet (for SAIL field refs):**
- **Evaluation** (`e6bc8561-…`): `evaluationId` `7f7c2d3b-1410-4650-a5c8-afd218753011` · `evaluationStatusId` `4e467ee1-e9e1-4350-9df9-ec1266418014` · `evaluationMethodId` `b363eb20-ab64-4c30-8b65-8ca9fc976109` · `parentEvalId` `6889c500-986b-4df6-93c2-6aa8a890cbd7` · `isOnSpotConsensus` `8962d2c5-f856-4959-9b99-b790b5c22e4b` · `evaluationStartDate` `5e919546-839d-478a-9310-11a10b61c377` · `evaluationDueDate` `46715106-5a77-40eb-86d7-52bb59f5eb33` · `evaluationNumber` `b8cdd695-bc67-4c28-9f7e-90de99810528` · `evaluationTitle` `1aabcd17-e034-4b85-b375-2bb63146a122` · **rel `round`** `ffe492a5-ac35-47c4-93e3-8655da20b9fa`.
- **EvaluationRound** (`931e8145-…`): `evaluationId` `1756683f-efcf-4edb-8ed1-aa9d83468af7` · `roundName` `31c08880-eb84-47ee-b92b-9f3c41a446fb` · `sequence` `d20a1017-98de-4b58-abaa-f8a119687931` · `startDate` `7abbf0d2-90d9-4342-9b6a-034ba226298d` · `endDate` `c3f17341-a436-4024-a184-6a70957ca7fd` · `duration` `ecb1038d-6c8d-4249-905b-e030e48e9201` · `isOnSpotConsensus` `85812d35-fe1f-4ccc-b7b0-c61f0e2757d0`.
- **Criteria** (`11dcc745-…`): `criteriaId` `6ecea02c-1a1f-45ad-b9ae-fc21ab2ca79b` · `parentCriteriaId` `4a3dfb5e-6c0f-4c1e-b9c1-ebf1c1c7492e` · `dueDate` `5aa75ff7-f7ff-460a-965c-885fea7c4e0a` · `factorNumber` `a37cdba7-beef-42ae-829a-dc4fa25067cd` · `criteriaChair` `81325af3-81d6-48d0-866b-caf987f4ebfe` · `evaluatorTeamId` `863f75e7-0222-4461-9c82-9d32fdc62638` · `isActive` `27d31368-c230-4cda-92c9-5fa08da680e1` · rel `SubCriteria` `d5f2eb9d-e929-49fd-8d7d-11e29285293d`.

---

## 6. The must-know business rules

- Best Value only. Max **5** rounds. Round 1 can have up to ~400 vendors.
- Must down-select **≥1** vendor to advance; no max. Vendors eliminated **only between rounds**.
- Previous rounds are **read-only** for CO; **no round deletion**; **no skipping/early completion**.
- CO can **re-include** a previously excluded vendor in a new round.
- Evaluators see a round **only if on that round's team**; Factor Chairs see cross-round consensus with visual round indicators.
- On-the-spot consensus and evaluator masking are **per-round**.
- Round dates must sit **within** the overall evaluation dates; block save if a round exceeds its due date.
- Carry-forward docs/pricing are **editable**; factor→doc mapping resets if a factor is removed.
- **Combined** audit trail.

(Full table in `01_FEATURE_AND_TECHNICAL_DESIGN.md` §2.)

---

## 7. Current state in one line

**All 8 round sub-tabs are shipped and verified** (Factors, Teams, Consensus Reports, Documents, Task History, Ratings, Checklist Items/Tasks, Evaluation History), plus Vendors → "Last Participated Round". 

**Start/rounds workflow — WI-1, WI-2, WI-3 BUILT + verified via MCP:**
- **WI-1 Start Evaluation as Round 1 (Best Value):** interface `AS_GSS_FM_startEvaluationBestValue` `…42569`, PM `AS GSS Start Evaluation Best Value` `0000f04b-68ab…`, anchor rule `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` `…42289` v4, vendor-docs copy in `AS_GSS_UT_duplicateEvaluationForNewRound` `…42160` v9. Action `startEvaluationBestValue` (CO-created, root-only via `isBlank(parentEvalId)`). (§10.45–10.47)
- **WI-2 Start Round** (start an already-created child round, no new round): form `AS_GSS_FM_startRound` `…42738`, wrapper PM `AS GSS Start Round` `0000f04b-9451…` (reuses `0002ecdd…` as subprocess), action `startRound` (CO-created). Shown in the rounds card only on the **latest Set Up** round. (§10.48)
- **WI-3 Complete Round + Setup New Round gating:** wrapper PM `AS GSS Complete Round` `0000f04b-add3…` (no start form; reuses `0004e60d…` Mark-Complete, sets COMPLETE in backend), action `completeRound` (CO-created); rounds card shows it on the **In Progress** round. `setupNewRound` visibility gated to "all existing rounds COMPLETE". (§10.49)
- **Rounds card** `AS_GSS_SEC_rounds` `…42270` v9 = `a!flatten({ startRound (latest+SetUp), completeRound (INPROGRESS), edit })`. Helper `AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation` `…43812`.
- **Lifecycle:** root SETTING_UP → Start Evaluation (BV) → Round 1 INPROGRESS → Complete Round → COMPLETE → Setup New Round → next round SETTING_UP → Start Round → INPROGRESS → … Remaining across these: end-to-end UI walkthrough on a live family.

**ACTIVE phase — Cross-application impact research:** assess how multi-round affects GSS's integrations with **VM (Vendor Management), GCW (Contract Writing), GSM/DRM, Source Selection, SAM.gov, SharePoint**. **Read `07_CROSS_APP_IMPACT_RESEARCH.md` first** — it has the verified integration inventory, the multi-round mechanics that break single-evaluation assumptions, per-integration impact hypotheses (GCW status sync and VM vendor/proposal flows are the HIGH-impact areas), and the research method. This is analysis-only; don't change integrations until impact is confirmed. See `02_PROGRESS_TRACKER.md` for the live checklist.

## 7b. Continuing the current phase — round sub-tabs (read `04_…` first)

**Goal:** give each Evaluation record tab per-round sub-tabs (like Factors ✅ and Teams ✅). Remaining: **Consensus, Documents, Task History** (ID-based), then **Ratings, Tasks, Evaluation History** (RECORD-based — need a per-round loader that queries the record(s) first). Full input-shape table + interface UUIDs + record-view urlStubs are in `04_TABS_IMPLEMENTATION_PLAN.md` §2/§8.

**Reference implementations to copy:** Factors (`AS_GSS_CPS_viewFactors` + `_Parent`, view `_n_87YA`) and Teams (`AS_GSS_CPS_viewEvaluatorTeam` + `_Parent`, view `_j9bz9g`).

**Per-tab recipe** (from `01_…` §6.6):
1. `getInterface` the tab's content interface + `getObjectDependents` to confirm scope.
2. If it self-wraps in `AS_GSS_HCL_displayWrapperContents`/`headerContentLayout`, strip that frame → embeddable; `updateInterface`.
3. Create `AS_GSS_CPS_<tab>_Parent(evaluationId)` = `headerContentLayout` + `tabLayout` + `a!forEach(rule!AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation)` → `tabItem(label:"Round "&sequence, contents: <content>(roundEvalId))`. RECORD-based tabs: wrap the content call in a per-round loader interface that runs the same queries the current view does.
4. `testInterface` the `_Parent` on **eval 12** (known multi-round test family: evals 6→10,11,12).
5. Hand the CO the one-line view repoint (MCP can't update `AS_GSS_Evaluation_RECORD` views).

**Resolved blocker (WI-1 anchor):** `returnEvaluationRoundsForGivenEvaluation` previously filtered `parentEvalId = id` (children only), so Round 1 (root) didn't appear and opening a *child* round yielded no tabs. **Fixed (v4):** resolves `anchor = a!defaultValue(getEvaluationByIdentifier(id).parentEvalId, id)` and returns rounds for the anchor **+** its children (verified via `testRule` on eval 6 → 3 rounds, `error: null`). Note: a root eval's own Round-1 (`sequence=1`) row only exists once the new Start Evaluation action runs; legacy in-flight evals are not backfilled (§10.4).

## 7a. Gotchas you MUST know before coding (details in `01_…` §6.6–6.7)
- **Tab content must be embeddable** — a `tabItem` rejects `HeaderContentLayout`. Strip a tab interface's outer `AS_GSS_HCL_displayWrapperContents`/`headerContentLayout` before nesting it per round (the `_Parent` supplies one frame). Multi-branch interfaces may have **several** frames to strip (Consensus had 3).
- **Null-harden embedded content** — a per-round evaluationId may resolve to a null evaluation; guard `status = cons!X` comparisons with `a!defaultValue(field, -1)` (`and()` does not short-circuit). Pass `testInputs` to `updateInterface` so it validates against real data, not nulls.
- **`returnEvaluationRoundsForGivenEvaluation` needs a non-empty `additionalFields`** (empty → `[""]` error). Copy the Teams/Consensus parent's field ref.
- **Record-based tabs (Ratings/Tasks/Eval History):** the content takes queried objects, so the parent runs the view's query per round inside the `tabItem`. Use the **current-eval fallback** (`if(isNullOrEmpty(roundsRaw), {a!map(evalId: ri!evaluationId, seq: null)}, forEach → a!map(...))`) — a leaf eval returns `[]` rounds and a null evalId crashes Ratings/Eval-History.
- **`a!paneLayout` is rejected inside `a!tabItem`** — convert panes to `columnsLayout`.
- **Single-typed record inputs:** use SINGLE_OBJECT test values; an OBJECT_ARRAY testInput makes `ri!x.field` a list and breaks `=` filters.
- **Round-listing goes inside the `_Parent` interface**, not a standalone expression rule (per-round content uses `env!features`, which fails expression-rule validation).
- **Repoint Evaluation record views manually in Appian Designer** — `updateRecordTypeView`/`getRecordType` fail on `AS_GSS_Evaluation_RECORD` (`None is not a valid RecordTypeSourceType`). MCP creates the `_Parent`; a human swaps the one-line view reference.
- Run **`getObjectDependents`** before refactoring a shared interface to confirm blast radius.
- **Correlate vendors across rounds by `uniqueEntityId`** — `vendorRefId` is null and `vendorId` changes every round.
- **Resolve the anchor** with `coalesce(parentEvalId, evaluationId)`, then family = `append(anchor, children where parentEvalId = anchor)`.
- **`union()` is type-strict**; **`indexWhere` returns all matches** (use `index(...,1,null)`).
- **Trust `testInterface`/`testRule` over `validateDesignObject`** for i18n-bundle-dependent grids (false-positive `lbl_…` index errors under null stubs).
- **Keep it backward-compatible:** round helpers return empty for non-round evals so new UI stays hidden.

---

## 8. Working agreements

1. **Update `02_PROGRESS_TRACKER.md`** at the end of every session (statuses + append a Session Log entry), then **`git add` + commit + push** the `multi-round-evaluation/` docs from `/Users/ramaswamy.u/repo/project-tracker` (branch `main`). Do NOT stage the unrelated `genesis/` folder.
2. **Validate** every changed object (`validateDesignObject`) and, where possible, `testInterface` / `testRule` before considering work done.
3. **Confirm priority** with the team before starting a work item — the plan is to pick items *after* documentation is in place.
4. **Match existing conventions** (naming, helper rules, constants) — don't introduce new patterns without reason.
5. **Don't guess UUIDs.** Always resolve them from `list*`/`get*` responses.
6. Treat the design doc as the source of truth for intent; treat the tracker as the source of truth for status.
7. Clean up any temp files (e.g., `/tmp/gss_review`) created while reading objects.

---

## 9. Handy first commands for a fresh agent

```
listApplicationObjects(appUuid: "_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416",
                       objectTypes: ["recordTypes","interfaces","expressionRules"])
listInterfaces(appUuid: <above>, query: "round")
listExpressionRules(appUuid: <above>, query: "round")
getRecordType(uuid: "931e8145-3f77-4270-a52a-b51de6e76983")
```
Then dump the round interfaces/rules to `/tmp/gss_review/*.sail` with `getInterface`/`getExpressionRule` and read them.

**Known test data:** evaluation **12** is part of a multi-round test family (root **6** → child rounds **10, 11, 12**; vendors keyed by UEI `123456789123`, `123456789122`). Use eval 12 with `testInterface`/`testRule` to verify round-aware behavior. (Round records exist for evals 7,8,9,10,11,12; some have null `sequence` — a known data gap.)

---

## 10. WI-1 build guide — Start Evaluation as Round 1 (Best Value)

> **Read `06_START_EVALUATION_WI1_IMPLEMENTATION_PLAN.md` first — it is the authoritative spec.** This section is the quick-start for the agent doing the build. All decisions are locked (no open questions).

### 10.1 What we're building & why
Today **Start Evaluation** is a confirm-only dialog and the parent evaluation never becomes a round, so Round 1 never appears in the round sub-tabs and the anchor family can't resolve. WI-1 makes clicking Start Evaluation (on a **Best Value** eval) collect **round info + selected factors**, register the **parent eval as Round 1** (`EvaluationRound` row, `sequence=1`, `parentEvalId=null`), and generate **tasks/ratings/consensus only for the selected factors × the eval's vendors**.

### 10.2 The three verified mechanisms you rely on
1. **Task/rating/consensus generation is factor-list driven.** Everything flows from `pv!evaluationFactorsAndSubFactors`. The leaf `AS_GSS_generateEvaluationTasksForAssignee` is literally `forEach(factors) × forEach(vendors)`. ⇒ **Scope that list to the selected factors (+ their subfactors) and generation is scoped automatically.** No subprocess edits needed.
2. **Rounds are created by the Evaluation→`round` relationship cascade.** Populate `evaluation['…round']` with one `EvaluationRound` and the eval Write Records node persists it (as `AS_GSS_UT_duplicateEvaluationForNewRound` does). **No separate EvaluationRound write.**
3. **Anchor = `coalesce(parentEvalId, evaluationId)`; root keeps `parentEvalId = null`.**

### 10.3 Build steps (in order)
> ⚠️ **This subsection is the ORIGINAL plan. For what was actually built (and where it deviated), read §10.45 — it supersedes §10.3.** Notably: step 3's record action **cannot** be created via MCP (it's manual in Designer — see §10.45 MANUAL), and step 5 (retire fallback) was intentionally **skipped**.
1. **New interface `AS_GSS_FM_startEvaluationBestValue`** — single-screen modal per mockup p3 (`GSS - Multiround Evaluation (1).pdf`; render with the pymupdf snippet in §10.5). Fields: Round Name* (default "Initial Evaluation"), Start Date, Duration (days), Due Date; a **factor multi-select** (parent factors, showing Team/Evaluators/factor due date; default all selected; "N of N selected"). **No vendor step, no on-spot toggle.** Reuse the round-detail + factor-picker components from `AS_GSS_FM_startNewRound`. On Start: set `userAction=START`; update the eval (status→INPROGRESS, start/due dates, modified*) **and populate `evaluation['…round']`** = one EvaluationRound (`evaluationId`=this eval, `sequence`=1, roundName/startDate/endDate=dueDate/duration, `isOnSpotConsensus`=eval's); output `selectedFactorIds`. `testInterface` on a SETTING_UP Best Value eval.
2. **New process model** — clone `0002ecdd-8ec4-8000-bf9c` **minus the LPTA branch**. Add PV `selectedFactorIds`; add a script node computing `pv!scopedFactors` = rows of `pv!evaluationFactorsAndSubFactors` where `criteriaId ∈ selectedFactorIds` **OR** `parentCriteriaId ∈ selectedFactorIds`. On the eval Write node, write `pv!evaluation` **with the populated `round` relationship** (cascade → Round 1). Feed `pv!scopedFactors` into ratings (`createTransactionalRatings`), the factor write, `Generate Evaluation Tasks` (`0002edab`) and `Create Consensus Reports` (`0003ece5`), and the audit. Keep Sync-GCW, vendor-analysis toggle, and on-spot vs default XOR. Reuse all subprocess UUIDs from §5.
3. **New record action `startEvaluationBestValue`** on `AS_GSS_Evaluation_RECORD` (`4db4a62e-…`) → new PM. Visibility = `and(getRelatedActionVisibilityForStartEvaluation(...), method = BEST_VALUE(5))`. **Also add `method <> BEST_VALUE` to the existing action's visibility** so exactly one shows. (Record-action changes via `addRecordTypeAction`/`updateRecordTypeAction`; recall `updateRecordTypeView` fails on this RT, but **actions** are fine — verify.)
4. **Anchor** — edit `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (`_a-…42289`) to resolve the family: `anchor=coalesce(parentEvalId,evaluationId)`, return EvaluationRound rows for anchor + children (`parentEvalId=anchor`), sorted by `sequence`. `testRule` on root **6** and a child.
5. **Retire the current-eval fallback** in the 3 record-based tab parents (`AS_GSS_CPS_evaluationRatingsTab_Parent` `_…42562`, `AS_GSS_TMG_CPS_viewRecordTasks_Parent` `_…42542`, `AS_GSS_FM_evaluationAuditHistory_Parent` `_…42552`); keep an empty-safe render. Re-verify all 8 parents on eval 6.
6. **Test end-to-end** (see plan §5): Round-1 row created; tasks count = selectedFactors×vendors; ratings/consensus scoped; on-spot variant (no tasks); LPTA/non-Best-Value unaffected; Round 1 shows in the tabs/rounds panel.
7. **Docs + commit/push** (working agreements §8): update `02_PROGRESS_TRACKER.md` (mark WI-1 items, add session log), then commit + push.

### 10.4 WI-1-specific gotchas
- **Only one action visible at a time** — remember to add the `<> BEST_VALUE` guard to the *existing* action (the single edit to an existing object).
- **Include subfactors** of selected parents in `scopedFactors` (selection is at parent-factor level in the modal).
- **On-spot Best Value** = no evaluation tasks, only consensus reports — keep that XOR branch.
- **Round-1 dates:** also set the eval's `evaluationStartDate`/`evaluationDueDate` from the modal (mirrors `duplicateEvaluationForNewRound`).
- **Legacy in-flight evals** (already INPROGRESS, no Round-1 row) are **not** backfilled — anchor query returns only their children; acceptable, flag to PO.
- **Process-model editing** is done via the `lcp` PM tools (`createProcessModel`, `createProcessModelNode`, `getProcessModelNodeTypeSchema`, `updateProcessModelNode`). Use `getProcessModelNodeTypeSchema` for each node type; serialize per-node edits.

### 10.45 BUILD STATUS (as of 2026-08-26) — what exists, what's manual
**Built + verified via MCP:**
- **Interface** `AS_GSS_FM_startEvaluationBestValue` = `_a-0000f04b-38cd-8000-9baa-011c48011c48_42569` — single-screen modal; `testInterface` on eval 12 renders clean (Round Name default "Initial Evaluation", start/duration/due auto-calc, factor multi-select all-checked, live "N of N selected"). **PO-verified in UI.** (v1 factor card shows factor name + factor number + due date; Team/Evaluators display deferred — the `EvaluatorTeam` relationship join returned empty in the harness.)
- **Process model** `AS GSS Start Evaluation Best Value` = **`0000f04b-68ab-8000-fbf5-7f0000014e7a`** — 16 nodes, `validateDesignObject` = no errors. Clone of `0002ecdd…` minus LPTA, plus a **Scope Selected Factors** UMQ node (filters `evaluationFactorsAndSubFactors` to `criteriaId ∈ selectedFactorIds OR parentCriteriaId ∈ selectedFactorIds`). PVs: evaluation, originalEvaluation, evaluationFactorsAndSubFactors, originalEvaluationFactorsAndSubFactors, vendors, userAction, **selectedFactorIds** (List of Integer), evaluationRatings. Start form = the interface above (inputMap evaluation/userAction/selectedFactorIds).
  - **Tooling deviation:** MCP could **not** create `start-process-4` (Start Process) nodes — platform NPE `acSchemaId is null`. The two Start Process steps (Sync GCW `0006ef1c`, Reqt Extraction `0005ef63`) were replaced with **async `SUB_PROC` (internal.38)** nodes calling the same PMs (both accept `evaluationId`) — equivalent fire-and-forget. Review these two in Designer.
  - **Tooling deviation:** bulk `updateProcessModel(nodes=…)` also hit that NPE; the graph was built **incrementally** with `createProcessModelNode` (backward from End) — all validated.
- **Anchor rule** `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (`_a-…42289`, v4) — rewritten to resolve `anchor = a!defaultValue(getEvaluationByIdentifier(id).parentEvalId, id)` then return rounds for the anchor **+** its children (two queries appended). Verified in-context: Teams parent renders round tabs on eval 6, `diagnostics.error: null`. (Round 1 tab appears once the new action runs and creates the sequence-1 row.)

**Step 5 (tab-parent fallback):** left **as-is** — the current-eval fallback in the 3 record-based parents is compatible with the anchor change and still handles non-round evals gracefully. No change needed.

**New PM node map** (`0000f04b-68ab-8000-fbf5-7f0000014e7a`): 1 Start → 3 XOR *Is cancel?* (cancel→2 End, else→4) → 4 Write *Update Evaluation Record* (writes `pv!evaluation` incl. `round` rel → cascades Round 1) → 5 *Sync Eval Status in GCW* (async SUB_PROC `0006ef1c`) → 6 UMQ *Scope Selected Factors* (`internal.16`; filters `evaluationFactorsAndSubFactors` to `criteriaId ∈ selectedFactorIds OR parentCriteriaId ∈ selectedFactorIds`) → 7 UMQ *Populate Parent And Child Ratings* (`createTransactionalRatings`) → 8 Write *Write Rating Records* (+ `updateRatingDetailsToCriteriaRecords`) → 9 Write *Update Factors And SubFactors With Ratings* → 10 XOR *Toggle* (`AS_GSS_TOGGLE_VENDOR_ANALYSIS_ENABLED`: on→11, else→12) → 11 *Trigger Reqt Extraction* (async SUB_PROC `0005ef63`) → 12 UMQ *Dummy* → 13 XOR *Identify Workflow* (on-spot→15, else→14) → 14 SUB_PROC *Generate Evaluation Tasks* (`0002edab`) → 15 SUB_PROC *Create Consensus Reports* (`0003ece5`) → 16 SUB_PROC *Capture Audit* (`0007e5df`, `AS_GSS_UT_constructStartEvaluationAudit`) → 2 End. All SUB_PROC/Gen-Tasks/Consensus receive `pv!evaluationFactorsAndSubFactors` (already scoped by node 6). **No LPTA branch.**

### 10.46 Vendor documents carried to new round (`AS_GSS_UT_duplicateEvaluationForNewRound`, v9)
Independent enhancement (not WI-1). The duplicate rule copies each carried vendor's **documents** into the new round. It **queries the source evaluation's vendor documents once** and maps them per vendor by `vendorId` (does NOT rely on the template vendor loading the `documents` relationship):
- `local!sourceVendorDocuments: rule!AS_CO_UT_queryRecord(recordType: EvaluationDocument `9c497e08`, returnType "OBJECT_ARRAY", fields:{vendorId, appianDocId, documentName, documentDescription, fileType, docType, documentTemplate, documentSubType, version, isPriceExtractionSelected, sourceApplicationId, isDeleted}, filters:{ evaluationId `f1f3c4f7` = source eval id, isDeleted `f0a0bf35` = false, vendorId `7771b188` operator "not null" })`.
- Inside the vendor `updateRecordsByModelRecord`, the **`documents`** relationship (`f017ee11-aaec-48c1-bef6-ba4e201c4017`) = `a!forEach(items: index(local!sourceVendorDocuments, wherecontains(tointeger(fv!item[…{757685e2}vendorId]), tointeger(a!defaultValue(local!sourceVendorDocuments[…{7771b188}vendorId], {}))), {}), expression: updateRecordsByModelRecord(records: fv!item, modelRecord: EvaluationDocument(nulled keys…)))`. `fv!item[757685e2]` is the source vendor's original vendorId (the modelRecord nulls it for the NEW vendor).
- **Nulled per doc:** `evaluationDocumentId`(PK) `f7ef236a`, `vendorId` `7771b188` (cascade), `evaluationId` `f1f3c4f7`, `consensusId` `5f719599`, `criteriaId` `93fca4ae`, `taskId` `41c000b4`. **Preserved:** `appianDocId` `fb650755` (same file), `documentName` `0c3871d9`, `documentDescription` `e74cd04a`, `fileType` `ff24466b`, `docType` `41df7759`, `documentTemplate` `711e2d00`, `documentSubType` `df9a6bdb`, `version` `fd74ffc6`, `isPriceExtractionSelected` `3bf77819`, `sourceApplicationId` `61cfca97`, `isDeleted` `f0a0bf35`. **Reset:** createdBy/modifiedBy=initiator, timestamps=now().
- copied docs' `evaluationId` is null; they attach to the eval via the new `vendorId` (vendor→documents). Fine for per-vendor access.



**MANUAL (MCP blocked — `addRecordTypeAction`/`updateRecordTypeView`/`getRecordType` all fail on `AS_GSS_Evaluation_RECORD` with `None is not a valid RecordTypeSourceType`):**
1. **Create action** `startEvaluationBestValue` on `AS_GSS_Evaluation_RECORD` → PM `0000f04b-68ab-8000-fbf5-7f0000014e7a`; icon `f251`; dialog `MEDIUM_PLUS`/`TALL`; label `rule!AS_GSS_UT_displayDynamicLabel(bundleKey: "lbl_StartEvaluation")`.
   - **Visibility** (SETTING_UP AND Best Value):
     ```
     and(
       rule!AS_GSS_BL_getRelatedActionVisibilityForStartEvaluation(
         statusId: rv!record['recordType!{4db4a62e-d099-4e54-be19-41498c17b9cc}AS_GSS_Evaluation_RECORD.fields.{evaluationStatus}evaluationStatus.{refDataId}refDataId'],
         evaluationId: rv!record['recordType!{4db4a62e-d099-4e54-be19-41498c17b9cc}AS_GSS_Evaluation_RECORD.fields.{evaluationId}evaluationId']),
       tointeger(rule!AS_GSS_QR_getEvaluationByIdentifier(
         evaluationId: rv!record['recordType!{4db4a62e-d099-4e54-be19-41498c17b9cc}AS_GSS_Evaluation_RECORD.fields.{evaluationId}evaluationId'])['recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD.fields.{b363eb20-ab64-4c30-8b65-8ca9fc976109}evaluationMethodId'])
         = cons!AS_GSS_REF_ID_EVALUATION_METHOD_BEST_VALUE)
     ```
   - **contextExpr:** copy the existing `startEvaluation` action's contextExpr verbatim, and add `selectedFactorIds: {}` to the returned map (keys must match PV names: evaluation, originalEvaluation, evaluationFactorsAndSubFactors, originalEvaluationFactorsAndSubFactors, vendors, selectedFactorIds, userAction).
2. **Guard the existing `startEvaluation` action** — wrap its visibility with the Best Value **exclusion** (`… <> cons!AS_GSS_REF_ID_EVALUATION_METHOD_BEST_VALUE`) so only one Start Evaluation shows.
3. **End-to-end UI test** on a fresh SETTING_UP **Best Value** eval: action visible (LPTA: not visible, old action shows); submit with a factor subset → Round-1 row (`sequence=1`, `parentEvalId` null), status INPROGRESS, tasks/ratings/consensus only for selected factors × vendors; Round 1 tab appears across round-aware tabs.

### 10.47 Appian / MCP tooling limitations (this environment) — READ BEFORE BUILDING
- **`AS_GSS_Evaluation_RECORD` (`4db4a62e`) mutations fail** via MCP: `getRecordType`, `updateRecordTypeView`, **and `addRecordTypeAction`/`updateRecordTypeAction`** all return `None is not a valid RecordTypeSourceType`. `listRecordTypeActions` works (read-only). ⇒ record actions + view repoints on this RT are **manual in Designer**.
- **`start-process-4` (Start Process) nodes cannot be created** via `createProcessModelNode`/`updateProcessModel` — platform NPE `Cannot invoke "java.lang.Long.intValue()" because "acSchemaId" is null` (even with no params). Workaround: use async `SUB_PROC` (`internal.38`) to the same PM if it exposes the needed params as process parameters.
- **Bulk `updateProcessModel(nodes=[...])`** with many activity nodes also hit the `acSchemaId` NPE. Workaround: create the PM shell → set `processVariables`+`startForm` first (separate call) → add nodes one-by-one with `createProcessModelNode` (backward from End so targets exist) → rewire Start last.
- **PVs must exist before nodes reference them** — set `processVariables` before adding nodes with `pv!` refs (else `Variable(s) not found`).
- **`a!formLayout` rejects `skipAutoFocus`** (only the `_25r1` variant accepts it).
- **XOR conditions must be null-safe** at validation: `field = true()` fails "Cannot compare Null and Boolean" — wrap with `a!defaultValue(field, false())`.
- **`AS_CO_UT_filterCdtByField(field:"parentCriteriaId")` returns empty against `AS_GSS_QR_getCriteria` output** (UUID-keyed record maps, not named CDT). Use a UUID-based `wherecontains(true, a!forEach(... isnull(...parentCriteriaId)))` filter. (`filterCdtByField` works on `AS_GSS_QE_getEvaluationCriteria` output, which is named CDT — as `continueSetup` contexts do.)
- **`testInterface`/`testRule` `inputs` maps pass values literally** (a record-typed value passed as a string errors `Could not cast from Text`). Prefer saved default test inputs (set via create/update `testInputs`) and call with no `inputs`.
- **Expression-rule `additionalFields` empty test value → `[""]`** invalid-fields error. Pass a real field-ref test value when validating rules that spread `additionalFields` into query `fields`.
- **Read-tool display quirk:** node/rule expressions come back with a spurious `pv!`/`=` prefix (e.g. `pv!rule!...`, `pv!pv!evaluation`) — cosmetic; the stored expression is correct.
- **`getWebApi` returns `expression: null`** in this env — Web API expression bodies aren't exposed via MCP. To understand a Web API's logic/payload, trace the expression rules it calls (via `listExpressionRules` by topic + `getObjectDependents`). Relevant to the cross-app research (`07_…`).

### 10.48 Start Round (WI-2) — start an already-created round (reuses Start Evaluation)
Goal: after **Setup New Round** creates a child round eval (SETTING_UP), the CO clicks **Start Round** in the Rounds card to run the full Start-Evaluation generation (INPROGRESS + ratings/tasks/consensus + on-spot XOR) **without creating a new round**. Factors/vendors are already scoped on the clone, so no factor-selection step.

**Key constraint that shaped the design:** a record action's dialog *is* its PM's start form, and one PM binds exactly one start form. To show a new Start Round confirm form while reusing the existing Start Evaluation process, we use a **thin wrapper PM** whose start form is the new form and which calls the existing PM as a subprocess (max reuse, no duplication, and avoids recreating the un-createable start-process-4 nodes — §10.47).

Built objects:
- **Interface `AS_GSS_FM_startRound`** = `_a-0000f04b-38cd-8000-9baa-011c48011c48_42738` — p8 confirm dialog. Dynamic **round number** (queries `AS_GSS_EvaluationRound` by `evaluationId` → `sequence`) and **included-vendor count** (active `EvaluationVendor` for the eval). On Start: `userAction=START`, eval → INPROGRESS + modifiedBy/modifiedDatetime + weighted/on-spot metrics; on Cancel: `userAction=CANCEL`. Inputs `evaluation`, `userAction`. NOTE: `testInterface` can't inject a typed record, so `ri!evaluation` is null in-harness and `AS_CO_UT_queryRecord` (which uses `ignoreFiltersWithEmptyValues:true`) drops the eval filter → shows generic values; verified the query logic with a throwaway integer-input probe (eval 12→Round 3/1 vendor, eval 13→Round 1/2 vendors).
- **Wrapper PM `AS GSS Start Round`** = `0000f04b-9451-8000-fc0b-7f0000014e7a` — Start (start form = the new form) → SUB_PROC `internal.38` calling **`0002ecdd…`** (synchronous, chained, forwards evaluation/userAction/vendors/evaluationFactorsAndSubFactors/originalEvaluation/originalEvaluationFactorsAndSubFactors) → End. PVs match those 6 params. `validateDesignObject` clean. (The reused `0002ecdd…` writes `pv!evaluation` with **no** `round` relationship → no new round; its cancel XOR handles `userAction=CANCEL`.)
- **Record action `startRound`** (CO-created) = `84ac0b39-bf4e-43ba-bbb3-050dd2e5d9f4` on `4db4a62e` → wrapper PM. Visibility = `and(getRelatedActionVisibilityForStartEvaluation(status,id), method = BEST_VALUE, isNotBlank(parentEvalId))`. contextExpr = the existing `startEvaluation` contextExpr (no `selectedFactorIds`).
- **"Start Evaluation (BV)" guard** (CO): added `isBlank(parentEvalId)` so it fires only on the **root** (Round 1). Net: root→Start Evaluation (BV, creates Round 1); child round→Start Round (reuses `0002ecdd…`, no new round); LPTA/non-BV→original Start Evaluation.
- **Rounds card button:** `AS_GSS_SEC_rounds` (`…42270`, v8) — added a `startRound` `a!recordActionItem` (keyed by the round's `evaluationId` `1756683f`) alongside the existing `edit` in each card's `a!recordActionField`. The item is included **only on the latest round** (its `sequence` = `local!maxSequence`, the max over the family) **and** only when that round is SETTING_UP, so older set-up rounds never show it; the action's own visibility (start-readiness) still gates the final render. Verified on eval 6 (rounds seq 2/2/3): only the seq-3 card includes the Start Round slot.

### 10.49 Complete Round + Setup New Round gating (WI-3)
**Complete Round** — backend-only completion of the active round, reusing Mark-Complete without a form.
- **`AS GSS Complete Round`** PM = `0000f04b-add3-8000-fc11-7f0000014e7a` — **no start form**; Start → SUB_PROC `internal.38` → **`0004e60d…` (AS GSS Mark Evaluation as Complete)** with `evaluation` pre-set to COMPLETE (`updateRecordsByModelRecord`: evaluationStatusId=`cons!…_COMPLETE`, modifiedBy=`pp!initiator`, modifiedDatetime=now()) and `userAction = cons!AS_CO_ENUM_USER_ACTION_SUBMIT` → End. Reuses the original's write + GCW sync + audit; original untouched. Because the PM has no start form, clicking the action runs it directly (no dialog). `validateDesignObject` clean.
- **`completeRound` action** (CO-created) = `853cb2b7-5587-48fa-8af4-15d6206a7421` → the wrapper PM; contextExpr passes `evaluation` (= existing `completeEvaluation` contextExpr). Suggested visibility = `AS_GSS_BL_getRelatedActionVisibilityForMarkEvaluationAsComplete(evaluationId)`.
- **Rounds card** (`…42270`, v9): actions are now `a!flatten({ if(latest+SetUp → startRound, {}), if(INPROGRESS → completeRound, {}), edit })`. Complete Round shows only on the **INPROGRESS** round; Start Round only on the latest **Set Up** round; Edit always.

**Setup New Round gating** (MANUAL, `setupNewRound` visibility — CO applied): visible only when the family has ≥1 round and **no round is SETTING_UP or INPROGRESS** (i.e., all rounds COMPLETE) — so a new round can be set up only after the current/latest round is completed. Expression uses `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (additionalFields = round→evaluation→evaluationStatusId) then `not(or(contains(statuses, SETTING_UP), contains(statuses, INPROGRESS)))` AND `isNotBlank(roundId)`. (Earlier "any round complete" was rejected — it would show while a later round is still active.) Optional cap: `count(local!rounds) < 5`.

### 10.5 Render the mockup (for the modal layout)
```
cd /Users/ramaswamy.u/repo/project-tracker/multi-round-evaluation && mkdir -p /tmp/gss_mock && python3 -c "
import fitz; d=fitz.open('GSS - Multiround Evaluation (1).pdf')
[p.get_pixmap(dpi=110).save(f'/tmp/gss_mock/p{i+1:02d}.png') for i,p in enumerate(d)]"
```
Then read images. **p3** = the Start Evaluation modal (target). p2 = Rounds empty state ("Start the evaluation to begin Round 1."). p4–p8 = Setup New Round (separate flow, for component reuse). p9 = Rounds-panel states. p14 = Summary-vs-Factors-tab note (a small follow-up: Summary shows current round's factors, Factors tab shows all).
