# WI-1 Implementation Plan — Best Value "Start Evaluation" as Round 1 (anchor) + factor-scoped generation

**Status:** Ready to build (no open questions). Verified end-to-end against live objects + the 14-page mockup deck.
**Date:** 2026-08-26
**Scope decision (PO):** Build a **brand-new** Start Evaluation interface + process model used **only for Best Value** evaluations (`evaluationMethodId = cons!AS_GSS_REF_ID_EVALUATION_METHOD_BEST_VALUE` = 5). The **existing** Start Evaluation action/PM/form stays unchanged and continues to serve non-Best-Value (LPTA, etc.). Reuse existing subprocess/rule components.

---

## 0. Decisions locked with PO
1. **Anchor:** the root (parent) evaluation keeps `parentEvalId = null`. Family resolution = `coalesce(parentEvalId, evaluationId)`.
2. **New objects** for Best Value Start Evaluation (interface + PM). Do **not** modify the existing action.
3. **Unselected factors:** leave as-is (remain active on the eval; simply excluded from Round-1 generation). No deactivation.
4. **Sequence:** Round 1 = `sequence = 1`. Setup New Round already assigns subsequent sequences.
5. **Round row** is created by **passing the `round` relationship on the evaluation write** (cascade) — no separate write node.
6. Mockup is authoritative for UX (single-screen modal; round name defaults "Initial Evaluation"; factors selectable; **no vendor step, no on-spot toggle**).

---

## 1. Verified current-state architecture (evidence)

### 1.1 Existing Start Evaluation (to be cloned, not modified)
- Action `startEvaluation` on `AS_GSS_Evaluation_RECORD` (`4db4a62e-…`), PM **`0002ecdd-8ec4-8000-bf9c-7f0000014e7a`**, form `AS_GSS_FM_startEvaluation` (`_a-0000ecda-a664-8000-9dc8-011c48011c48_14286788` — confirmation-only), visibility `AS_GSS_BL_getRelatedActionVisibilityForStartEvaluation(statusId, evaluationId)`.
- Action `contextExpr` pre-loads: `evaluation`, `evaluationFactorsAndSubFactors` = `AS_GSS_QR_getCriteria(evaluationId, isActive:true)` (ALL active factors+subfactors), `vendors` = `AS_GSS_QR_getEvaluationVendors(evaluationId)`, plus `originalEvaluation`, `originalEvaluationFactorsAndSubFactors`, `userAction`.
- PM flow (PVs: `evaluation`, `originalEvaluation`, `evaluationFactorsAndSubFactors`, `originalEvaluationFactorsAndSubFactors`, `vendors`, `userAction`, `evaluationRatings`):
  1. XOR `Is cancel?` (userAction = `cons!AS_CO_ENUM_USER_ACTION_CANCEL` → End).
  2. **Write Records** eval (status→INPROGRESS). `Version=6`, RT `AS_GSS_Evaluation_SYNCEDRECORD`.
  3. **Start Process** `Sync Eval Status in GCW` (`0006ef1c-885e-8000-e8da`).
  4. **Populate Parent And Child Ratings** → `rule!AS_GSS_BL_createTransactionalRatings(initiator, evaluationFactorsAndSubFactors, evaluationRecord)` → `pv!evaluationRatings`.
  5. **Write Rating Records** (`AS_GSS_Rating_SYNCEDRECORD`) + `AS_GSS_BL_updateRatingDetailsToCriteriaRecords`.
  6. **Write** `Update Factors And SubFactors With Ratings` (`AS_GSS_Criteria_SYNCEDRECORD`).
  7. XOR `Toggle` (`cons!AS_GSS_TOGGLE_VENDOR_ANALYSIS_ENABLED`) → `Trigger Reqt Extraction` (`0005ef63-71ba-8000`) → Dummy.
  8. XOR **Identify Workflow**:
     - LPTA (`= cons!AS_GSS_REF_ID_EVALUATION_METHOD_LPTA`) → `Generate LPTA Task` (`0002ee10-7d81-8000-d4cf`) → Audit. **(excluded from Best Value action)**
     - On-spot (`isOnSpotConsensus = true`) → `Create Consensus Reports` (`0003ece5-8031-8000-bff8`) → Audit.
     - default (Best Value, team consensus) → `Generate Evaluation Tasks` (`0002edab-48b7-8000-cee8`) → `Create Consensus Reports` → Audit.
  9. **Capture Audit** (`0007e5df-28c1-8000`) via `AS_GSS_UT_constructStartEvaluationAudit(originalEvaluation, evaluation, originalEvaluationFactorsAndSubFactors, evaluationFactorsAndSubFactors, initiator)`.

### 1.2 Task generation is fully factor-list driven (verified 3 levels deep)
- `Generate Evaluation Tasks` (`0002edab-48b7`): node `Get Assignees And Mapped Factors` = `AS_GSS_UT_constructAssigneeWithMappedCriteria(evaluationFactorsAndSubFactors)` → `assigneeAndRelatedFactorsMap`; XOR (empty → End); MNI **Start Process** `Generate Evaluation Tasks Per Assignee` (`000aedab-3243-8000-cedd`) over the map, passing `assignedFactorsAndSubfactors`, `assignee`, `evaluationRecord`, `initiator`, `vendors`.
- Per-assignee (`000aedab-3243`): node `Generate Evaluation Tasks For Assignee` = `rule!AS_GSS_generateEvaluationTasksForAssignee(initiator, vendors, evaluation, assignedFactorsAndSubfactors, assignee)` → `taskRecords`; XOR; `Add assignee to Evaluators Group` (`cons!AS_GSS_GRP_EVALUATORS`); **Write Tasks** (`AS_GSS_TMG_Task_SYNCEDRECORD` `9a04b944-…`); Send Email; Audit sub-proc.
- Leaf `AS_GSS_generateEvaluationTasksForAssignee` (`_a-0000edaa-0a95-8000-9e03-011c48011c48_15676146`): `a!forEach(assignedFactorsAndSubfactors) × a!forEach(vendors)` → one Task per (factor, vendor). Task fields: `evaluationId`, `vendorId`, `criteriaId`, `taskName = evalNumber - factorNumber - vendorLegalName`, `dueDate = factor.dueDate`, `userAssignee = assignee`, `groupAssignee = Evaluators`, `taskStatusId = ASSIGNED`. **No re-query of "all factors."**
- ⇒ **Scoping `pv!evaluationFactorsAndSubFactors` to the selected factors (+ their subfactors) scopes tasks to (selected factors × vendors) exactly.**

### 1.3 Ratings + Consensus are also factor-list driven
- `AS_GSS_BL_createTransactionalRatings` (`_a-0000ecda-a664-8000-9dc8-011c48011c48_14296322`): derives distinct `refRatingTypeId`s from the passed (active) factors and builds `AS_GSS_Rating_SYNCEDRECORD` rows. Passing the selected subset scopes ratings.
- `Create Consensus Reports` (`0003ece5-8031`) is invoked with `evaluation`, `vendors`, `evaluationFactorsAndSubFactors` (verified from the Start-Eval PM node wiring) → scoped by the same list.

### 1.4 Round creation mechanism (from `AS_GSS_UT_duplicateEvaluationForNewRound`, `_a-…42160`)
- Setup New Round builds `newEvaluation` and populates the **Evaluation→`round` relationship** (`ffe492a5-ac35-47c4-93e3-8655da20b9fa`); the Write Records node cascades it to create the `AS_GSS_EvaluationRound_SYNCEDRECORD` row. It reads `round.startDate/endDate/isOnSpotConsensus` to set the eval's `evaluationStartDate`/`evaluationDueDate`/`isOnSpotConsensus`, and sets `parentEvalId = coalesce(source.parentEvalId, source.evaluationId)`.
- ⇒ For Round 1 we do the same on the **existing** eval: set `evaluation['…round']` = one new EvaluationRound and let the eval write cascade.

### 1.5 EvaluationRound record (`931e8145-…`)
Fields: `roundId`(PK), `evaluationId`(`1756683f`), `roundName`(`31c08880`), `sequence`(`d20a1017`), `startDate`(`7abbf0d2`), `endDate`(`c3f17341`), `duration`(`ecb1038d`), `isOnSpotConsensus`(`85812d35`), created/modified. Rel `evaluation`(`029ebc2e`) → Evaluation.

### 1.6 Mockup facts (deck, 14 pages)
- **p3 Start Evaluation modal (target):** single screen. Header copy: *"Confirm the Evaluation round name and the factors that will be included in this round. Once started, the evaluation factors and assignments cannot be modified."* Fields: **Round Name*** (default **"Initial Evaluation"**), **Start Date**, **Duration (days)**, **Due Date**; **Factors** list with "N of N selected", each card = checkbox + factor name + Team + Evaluators + factor due date. Buttons **CANCEL / START EVALUATION**. No vendors, no on-spot toggle.
- **p2:** Rounds panel empty state *"Start the evaluation to begin Round 1."* (whole eval in setup).
- **p9/p4:** After start, Round 1 card = title = round name ("Initial Evaluation"), subtitle "Round 1", status badge, date range. (Setup New Round is a separate 3-step wizard + separate "Start Round N" confirm — not part of WI-1.)
- **p14:** Summary shows the **current round's** factors; the **Factors tab shows all** factors (with a Rounds column). (Informs a later Summary tweak, not core WI-1.)

### 1.7 Constants
- `cons!AS_GSS_REF_ID_EVALUATION_METHOD_BEST_VALUE` = 5; `…_LPTA` = 67.
- `cons!AS_GSS_REF_ID_EVALUATION_STATUS_SETTING_UP`, `…_INPROGRESS`.
- `cons!AS_GSS_GRP_EVALUATORS`, `cons!AS_GSS_TOGGLE_VENDOR_ANALYSIS_ENABLED`.

---

## 2. Target design

### 2.1 New record action (Best Value only)
- **Key:** `startEvaluationBestValue` (new) on `AS_GSS_Evaluation_RECORD`.
- **Process model:** new (see §2.3).
- **dialogWidth/Height:** `MEDIUM_PLUS` / `TALL` (form is taller than the old confirm).
- **Visibility expr** — show only when BOTH: status = SETTING_UP AND method = Best Value:
  ```
  and(
    rule!AS_GSS_BL_getRelatedActionVisibilityForStartEvaluation(
      statusId: rv!record['…evaluationStatus.refDataId'],
      evaluationId: rv!record['…evaluationId']
    ),
    tointeger(rv!record['…evaluationMethod.refDataId']) = cons!AS_GSS_REF_ID_EVALUATION_METHOD_BEST_VALUE
  )
  ```
  And **update the existing action's** visibility to add `<> BEST_VALUE` so exactly one Start Evaluation action shows. *(This is the only edit to an existing object — a visibility guard, not behavior.)*
- **contextExpr:** same loads as today (`evaluation`, all active `evaluationFactorsAndSubFactors`, `vendors`, `originalEvaluation`, `originalEvaluationFactorsAndSubFactors`, `userAction`) — the wizard needs the full factor list to present the selectable set, plus a new `selectedFactorIds` seeded to all factor (parent) ids by default (3-of-3 selected).

### 2.2 New interface `AS_GSS_FM_startEvaluationBestValue`
Single-screen `a!formLayout` mirroring mockup p3. Inputs: `evaluation` (record), `evaluationFactorsAndSubFactors` (list), `userAction` (text), and it maintains local/round fields.
- Header instruction (i18n `ins_StartEvaluationRoundConfirm`).
- **Round detail row:** Round Name* (default `"Initial Evaluation"`, i18n `lbl_InitialEvaluation`), Start Date, Duration (days), Due Date. Reuse the round-detail component/validation from `AS_GSS_FM_startNewRound` (dates within eval window; Start + Duration ⇒ Due, mutually consistent — mirror Setup New Round's date logic). **No on-spot toggle** (inherit `evaluation.isOnSpotConsensus`).
- **Factors selector:** reuse the factor-picker pattern from `AS_GSS_FM_startNewRound` step 1 (parent factors only, each card shows Team + Evaluators + factor due date). Multi-select; header "N of N selected"; default all selected. Read-only team/evaluators (assignments locked). Bind selection to `selectedFactorIds`.
- **Buttons:** Cancel (`userAction = CANCEL`) / Start Evaluation. On Start:
  - `userAction = cons!AS_GSS_ENUM_USER_ACTION_START`.
  - Update `evaluation`: `evaluationStatusId → INPROGRESS`, modifiedBy/modifiedDatetime, `evaluationStartDate = startDate`, `evaluationDueDate = dueDate`, and **populate `evaluation['…round']`** with one `AS_GSS_EvaluationRound`(`evaluationId = evaluation.evaluationId`, `sequence = 1`, `roundName`, `startDate`, `endDate = dueDate`, `duration`, `isOnSpotConsensus = evaluation.isOnSpotConsensus`, created/modified). Keep `parentEvalId = null` (root).
  - Preserve the existing metric saves (signature/weighted/duplicated/on-spot) from the old form.
- Validation: Round Name required; dates valid & within eval window; ≥1 factor selected.

### 2.3 New process model `AS GSS Start Evaluation (Best Value)`
Clone of `0002ecdd…` **minus the LPTA branch**, plus factor scoping and round persistence. PVs: same as today + **`selectedFactorIds`** (List of Integer) and reuse `evaluationFactorsAndSubFactors`.
- Node A **XOR Is cancel?** → End on CANCEL.
- Node B **Compute selected factors** (Script/Unattended): `pv!scopedFactors = ` filter `pv!evaluationFactorsAndSubFactors` to rows whose `criteriaId ∈ pv!selectedFactorIds` **OR** whose `parentCriteriaId ∈ pv!selectedFactorIds` (selected parents + their subfactors). Use this everywhere below.
- Node C **Write Records — Update Evaluation** (`AS_GSS_Evaluation_SYNCEDRECORD`, `Version=6`): write `pv!evaluation` **including its populated `round` relationship** → cascade creates the Round-1 `EvaluationRound` row. (Confirmed the record write cascades relationships as Setup New Round relies on the same.)
- Node D **Sync Eval Status in GCW** (`0006ef1c-885e-8000-e8da`) — unchanged.
- Node E **Populate Ratings**: `AS_GSS_BL_createTransactionalRatings(initiator, evaluationFactorsAndSubFactors: pv!scopedFactors, evaluationRecord: pv!evaluation)` → `pv!evaluationRatings`.
- Node F **Write Rating Records** + `AS_GSS_BL_updateRatingDetailsToCriteriaRecords(criteria: pv!scopedFactors, parentRating: ac!RecordsUpdated)`.
- Node G **Write Factors And SubFactors With Ratings** (`AS_GSS_Criteria_SYNCEDRECORD`) — write `pv!scopedFactors`.
- Node H **XOR Toggle** (`cons!AS_GSS_TOGGLE_VENDOR_ANALYSIS_ENABLED`) → `Trigger Reqt Extraction` (`0005ef63-71ba-8000`) → merge.
- Node I **XOR Identify Workflow (Best Value only)**:
  - `isOnSpotConsensus = true` → **Create Consensus Reports** (`0003ece5-8031`) with `evaluation`, `vendors`, `evaluationFactorsAndSubFactors: pv!scopedFactors`.
  - default → **Generate Evaluation Tasks** (`0002edab-48b7`) with `evaluation`, `evaluationFactorsAndSubFactors: pv!scopedFactors`, `vendors` → then **Create Consensus Reports** (scoped) .
  - *(No LPTA branch.)*
- Node J **Capture Audit** (`0007e5df-28c1`) via `AS_GSS_UT_constructStartEvaluationAudit(originalEvaluation, evaluation, originalEvaluationFactorsAndSubFactors, evaluationFactorsAndSubFactors: pv!scopedFactors, initiator)` → End.
- Reuse all existing subprocess UUIDs above unchanged (pass scoped factors).

### 2.4 Anchor / rounds resolution (makes Round 1 appear in every tab)
- Update `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (`_a-…42289`) to resolve the **family** for any member:
  - `anchor = a!defaultValue(eval.parentEvalId, eval.evaluationId)` (root has parentEvalId null → anchor = self).
  - Return EvaluationRound rows for the anchor **and** all evals with `parentEvalId = anchor` (i.e., the whole family), sorted by `sequence`.
- Because Round 1 now exists as an `EvaluationRound` on the root, it appears as the first tab, and opening any child shows all rounds.
- **Retire the per-parent "current-eval fallback"** added to the 3 record-based tab parents; keep an empty-safe guard (non-round / not-yet-started eval → still render). Re-verify the 8 tab parents.

### 2.5 Summary vs Factors tab (per p14) — follow-up, not core
- Summary should show the **current round's** factors (scope by current round eval); Factors tab shows all. Track as a small follow-up after WI-1 core lands.

---

## 3. Object inventory

| # | Object | Type | Action |
| :-- | :-- | :-- | :-- |
| 1 | `AS_GSS_FM_startEvaluationBestValue` | Interface | **New** — single-screen wizard (round details + factor select), mirrors mockup p3, reuses `startNewRound` components |
| 2 | `AS GSS Start Evaluation (Best Value)` | Process Model | **New** — clone of `0002ecdd…` minus LPTA, + factor scoping + Round-1 write |
| 3 | Record action `startEvaluationBestValue` | Record action | **New** on `AS_GSS_Evaluation_RECORD`; visibility = SETTING_UP & Best Value |
| 4 | Existing `startEvaluation` action visibility | Edit (guard only) | Add `method <> BEST_VALUE` so only one shows |
| 5 | `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` | Expr rule | **Edit** — family/anchor resolution (`coalesce(parentEvalId, evaluationId)`) |
| 6 | 3 record-based tab parents (+ optionally the 4 ID-based) | Interfaces | **Edit** — drop current-eval fallback once anchor works; re-verify |
| 7 | i18n bundle | — | New keys: `ins_StartEvaluationRoundConfirm`, `lbl_InitialEvaluation`, factor-select labels |
| 8 | (Reused, unchanged) subprocesses `0002edab`, `000aedab`, `0003ece5`, `0006ef1c`, `0005ef63`, `0007e5df`; rules `generateEvaluationTasksForAssignee`, `constructAssigneeWithMappedCriteria`, `createTransactionalRatings`, `updateRatingDetailsToCriteriaRecords`, `constructStartEvaluationAudit` | — | No change |

---

## 4. Build order
1. **Interface** `AS_GSS_FM_startEvaluationBestValue` — build + `testInterface` on a SETTING_UP Best Value eval (round fields + factor list render; selection state; validations).
2. **Process model** clone — create PVs, nodes A–J; wire reused subprocesses; set `scopedFactors`; round write on node C.
3. **Record action** `startEvaluationBestValue` + contextExpr; set visibility; add the guard to the existing action.
4. **Anchor** update to `returnEvaluationRoundsForGivenEvaluation`; `testRule` on root **6** (expect rounds incl. Round 1 once created) and a child.
5. **Tab parents**: remove fallback; re-verify all 8 on root 6.
6. End-to-end test (see §5), then docs + commit.

## 5. Test plan (evidence to capture)
- **Fresh Best Value eval in SETTING_UP:** action visible (LPTA eval: not visible; existing action visible instead).
- Start with a **subset** of factors → verify: Round-1 `EvaluationRound` row created (`sequence=1`, `parentEvalId` null); eval status INPROGRESS; **tasks only for selected factors × vendors** (`AS_GSS_TMG_Task` rows count = selectedFactors×vendors, taskName pattern); ratings only for selected; consensus reports only for selected; audit entry present.
- **On-spot Best Value:** no eval tasks; consensus reports created (scoped); Round-1 row created.
- **Rounds panel/tabs:** Round 1 ("Initial Evaluation") appears; round sub-tabs show Round 1 + later rounds; opening a child round record shows the full family.
- **Regression:** existing LPTA/non-Best-Value Start Evaluation unchanged (uses old action/PM).
- Verify via `testProcessModel` (unattended parts) where possible, `listRecordData` on EvaluationRound + Task, and `testInterface` for the form.

## 6. Risks / mitigations
- **Relationship-cascade on eval write:** Setup New Round proves the pattern; use the same `Version` and full record write. If a scoped field-write ever blocks the relationship, fall back to writing `evaluation` with the `round` relationship explicitly (still one node, no separate EvaluationRound write).
- **Selected-subfactor inclusion:** always include subfactors of selected parents in `scopedFactors` (filter on `criteriaId ∈ sel` OR `parentCriteriaId ∈ sel`).
- **Two Start actions:** the visibility guard on the existing action prevents both showing.
- **Anchor change affecting shipped tabs:** re-verify the 8 parents after §2.4 (retire fallback carefully; keep empty-safe render for legacy in-flight evals with no Round-1 row — those simply show no round tab until started, acceptable).
- **Legacy in-flight evals** (already INPROGRESS, no Round-1 row): not backfilled; anchor query returns their children only. Acceptable; note for PO.
