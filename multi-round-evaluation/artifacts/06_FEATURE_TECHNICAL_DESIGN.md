# 06 — Feature Technical Design: GSS Multi-Round Evaluations

Object-by-object technical design to build the feature: for each object, its **purpose, where it's used, the implementation, and test cases**. Read alongside `05_FEATURE_IMPLEMENTATION_PLAN.md` (the *what/where/why*). **Governing standard:** `SOLUTIONS - Design Best Practices & Guidance 3.md` — §1 below distills the parts most relevant here; that doc wins in any conflict.

**Status: IN PROGRESS** — filled in batches, in build order (see the batch tracker at the end). Done: §1 conventions, §2 data model, §3 family & round helpers.

---

## 1. Conventions applied throughout

- **Querying:** use **`AS_CO_UT_queryRecord`** with a `returnType` (`cons!AS_CO_ENUM_QE_RETURN_TYPE_*`); it exposes `filters`, `logicalExpression`, `sort`, `pagingInfo`, `relatedRecordData`, `executeWhen`, and sets `ignoreFiltersWithEmptyValues: true`. One round-trip per need; filter on related-record fields; select only used fields; **sort in the query**.
- **Naming:** `_QR_` query-record · `_UT_` utility · `_BL_` business logic · `_CPS_`/`_CP_` component · `_SCT_` section · `_FM_` form/modal · `_GRD_` grid · `_UI_` standalone-error UI rule · `_VD_` validation · `_CONS_` constant list. Names state intent. Record types keep the GSS-prevailing `_SYNCEDRECORD` suffix for intra-app consistency.
- **Scope & reuse:** one responsibility per object; compose small rules; store repeated logic in locals; ≤~5 behavioral params.
- **Parameters:** keyword syntax; pass full objects (except when called from a record type); no behavior-changing flag args; behavioral booleans use `is`/`show`/`allow`, default when null, and carry `(Required)`-style rule-input descriptions.
- **Variables/typing:** affirmative names; plural for arrays; strong-typed locals; booleans always `true`/`false`; bracket-notation + `a!defaultValue` for record fields; guard all null-exposed comparisons.
- **Return:** consistent return type by contract.
- **Test cases:** cover each outcome incl. all-null; rules that contain DB queries use **"Case with No Assertions" / "Test Case Completes without Error"** with a top comment `/*This rule cannot have assertion*/`; no hard-coded i18n labels or environment-specific data.
- **Interfaces:** embeddable content (no outer header when meant to nest); no `paneLayout` in `a!tabItem`; logic lives in rules, not forms; `i18nData` loaded at top and passed down.
- **Process models:** headless start forms; wrapper process to chain into a form; entry-point PMs each get a `… PM Access` group, backend PMs' viewer = app Security Groups; lane = initiator; archive user-facing after 3 days, delete backend after 1 day; reuse via subprocess.
- **Record actions:** list vs related decided deliberately; never hardcode ids into related actions; don't pass `rv!record` into the process; drive visibility via relationships.

---

## 2. Data model

### 2.1 `AS_GSS_EvaluationRound_SYNCEDRECORD`
Per-round metadata, one row per round.

| Field | Type | Notes |
| :--- | :--- | :--- |
| `roundId` | Integer, PK | |
| `evaluationId` | Integer, FK → `Evaluation` | the round's own evaluation clone |
| `parentEvalId` | Integer, FK → `Evaluation` | **family key**: `null` for the root's Round-1 row, `= root evaluationId` for every child round. Indexed. |
| `roundName` | Text | |
| `sequence` | Integer | 1-based round order |
| `startDate` / `endDate` | Date | |
| `duration` | Integer | days |
| `isOnSpotConsensus` | Boolean | per-round |
| audit columns | | `createdBy/On`, `modifiedBy/On` |

Relationship: many-to-one **`evaluation`** (`evaluationId` → `Evaluation.evaluationId`). Column/table naming per best-practices §2.E (UPPERCASE, ≤30 chars, no `VARCHAR length`; add `parentEvalId` `AFTER` the business columns, before audit columns). Populate `parentEvalId` on the same write that creates the round row (§ Start Evaluation / Setup New Round batches).

### 2.2 `AS_GSS_Evaluation_SYNCEDRECORD`
Adds `parentEvalId` (`null` root / root-id child) and a cascading **`round`** relationship so writing an Evaluation with a populated `round` persists its `EvaluationRound` row atomically. No further core-schema change — family resolution rides on the rounds table (2.1).

---

## 3. Family & round helpers

> Minimal template per object: **Purpose · Used by · Inputs · Implementation · Test cases.**
> Field refs abbreviated after first use; use full `recordType!{uuid}…{fieldUuid}fieldName` refs when building. `{parentEvalId}` = the new column from §2.1.

### 3.1 `AS_GSS_QR_getEvaluationRoundDetails` (base query rule)
**Purpose:** single query-record getter for `EvaluationRound`, with optional filters. All round reads go through it.
**Used by:** `AS_GSS_QR_getRoundsForEvaluation` and any screen needing round rows.
**Inputs:** `returnType` (Required), `evaluationId` (List of Integer, optional — filters `evaluationId in`), `fields`, `logicalExpression`, `additionalFilters`, `sort`, `pagingInfo`, `aggregationFields`, `relatedRecordData`, `executeWhen`, `triggerRefresh`.
**Implementation:**
```
rule!AS_CO_UT_queryRecord(
  recordType: 'recordType!{931e8145-3f77-4270-a52a-b51de6e76983}AS_GSS_EvaluationRound_SYNCEDRECORD',
  returnType: ri!returnType,
  executeWhen: ri!executeWhen,
  triggerRefresh: ri!triggerRefresh,
  fields: ri!fields,
  logicalExpression: ri!logicalExpression,
  aggregationFields: ri!aggregationFields,
  relatedRecordData: ri!relatedRecordData,
  pagingInfo: ri!pagingInfo,
  sort: ri!sort,
  filters: {
    a!queryFilter(
      field: 'recordType!{931e8145}...{1756683f}evaluationId',
      operator: "in",
      value: ri!evaluationId,
      applyWhen: rule!AS_CO_UT_isNotBlank(ri!evaluationId)
    ),
    ri!additionalFilters
  }
)
```
**Test cases:** contains DB query ⇒ "Case with No Assertions". (1) all-null; (2) `evaluationId` populated + `returnType` OBJECT_ARRAY.

### 3.2 `AS_GSS_QR_getRoundsForEvaluation` (family resolver)
**Purpose:** return every round in an evaluation's family, in `sequence` order, each with its evaluation status — resolvable from any member (root or child).
**Used by:** `AS_GSS_SEC_rounds`, the round-aware tab wrapper(s), and the helpers in 3.3–3.4.
**Inputs:** `evaluationId` (Integer) — *"(Required) Any evaluation in the family (root or child round)."*
**Implementation:**
```
a!localVariables(
  /* Round row for the passed evaluation — read only its family linkage. */
  local!currentRound: rule!AS_GSS_QR_getEvaluationRoundDetails(
    returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_SINGLE_OBJECT,
    evaluationId: ri!evaluationId,
    fields: {
      'recordType!{931e8145}...{1756683f}evaluationId',
      'recordType!{931e8145}...{parentEvalId}parentEvalId'
    }
  ),
  /* Family anchor: a child round carries the root in parentEvalId; the root's round carries null. */
  local!familyRootId: a!defaultValue(
    local!currentRound['recordType!{931e8145}...{parentEvalId}parentEvalId'],
    ri!evaluationId
  ),
  /* Whole family — root's own round OR any child of the root — sequence order, with status joined in. */
  rule!AS_GSS_QR_getEvaluationRoundDetails(
    returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_OBJECT_ARRAY,
    fields: {
      'recordType!{931e8145}...{3a4b03be}roundId',
      'recordType!{931e8145}...{1756683f}evaluationId',
      'recordType!{931e8145}...{31c08880}roundName',
      'recordType!{931e8145}...{d20a1017}sequence',
      'recordType!{931e8145}...{7abbf0d2}startDate',
      'recordType!{931e8145}...{c3f17341}endDate',
      'recordType!{931e8145}...{85812d35}isOnSpotConsensus',
      'recordType!{931e8145}...relationships.{029ebc2e}evaluation.fields.{4e467ee1}evaluationStatusId'
    },
    logicalExpression: a!queryLogicalExpression(
      operator: "OR",
      filters: {
        a!queryFilter(field: 'recordType!{931e8145}...{1756683f}evaluationId', operator: "=", value: local!familyRootId),
        a!queryFilter(field: 'recordType!{931e8145}...{parentEvalId}parentEvalId', operator: "=", value: local!familyRootId)
      }
    ),
    sort: a!sortInfo(field: 'recordType!{931e8145}...{d20a1017}sequence', ascending: true)
  )
)
```
**Notes:** empty-safe — a non-round evaluation has no round row, so `familyRootId` = itself and the query returns `{}`.
**Test cases:** "Case with No Assertions". (1) null; (2) root id; (3) child id.

### 3.3 `AS_GSS_UT_returnIdentifiersForEvaluationRounds`
**Purpose:** convenience accessor returning the family's derived identifiers.
**Used by:** Setup-New-Round context and rounds-card logic needing the next sequence / latest round.
**Inputs:** `evaluationId` (Integer) — *"(Required) Any evaluation in the family."*
**Implementation:**
```
a!localVariables(
  /* Rounds are returned in ascending sequence, so the last element is the latest round. */
  local!rounds: rule!AS_GSS_QR_getRoundsForEvaluation(evaluationId: ri!evaluationId),
  local!latestRound: index(local!rounds, count(local!rounds), null),
  a!map(
    childEvalIds: local!rounds['recordType!{931e8145}...{1756683f}evaluationId'],
    latestRoundEvalId: local!latestRound['recordType!{931e8145}...{1756683f}evaluationId'],
    latestRoundStatusId: local!latestRound['recordType!{931e8145}...relationships.{029ebc2e}evaluation.fields.{4e467ee1}evaluationStatusId'],
    nextSequence: count(local!rounds) + 1
  )
)
```
**Notes:** latest round is derived by `sequence` (the sorted last element), not by max id.
**Test cases:** "Case with No Assertions". (1) null; (2) family id → map populated.

### 3.4 `AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation`
**Purpose:** evaluationId of the highest-`sequence` round currently in **Set Up** status; `null` if none. Drives where the rounds card shows **Start Round**.
**Used by:** `AS_GSS_SEC_rounds`.
**Inputs:** `evaluationId` (Integer) — *"(Required) Any evaluation in the family."*
**Implementation:**
```
a!localVariables(
  local!rounds: rule!AS_GSS_QR_getRoundsForEvaluation(evaluationId: ri!evaluationId),
  /* indexes of rounds whose evaluation is in Set Up (rounds are already sequence-ascending) */
  local!setupIndexes: wherecontains(
    cons!AS_GSS_REF_ID_EVALUATION_STATUS_SETTING_UP,
    tointeger(a!defaultValue(
      local!rounds['recordType!{931e8145}...relationships.{029ebc2e}evaluation.fields.{4e467ee1}evaluationStatusId'],
      {}
    ))
  ),
  if(
    a!isNullOrEmpty(local!setupIndexes),
    null,
    /* last matching index = highest sequence in Set Up */
    index(
      local!rounds,
      index(local!setupIndexes, count(local!setupIndexes), 0),
      {}
    )['recordType!{931e8145}...{1756683f}evaluationId']
  )
)
```
**Test cases:** "Case with No Assertions". (1) null; (2) family with a Set-Up round → its child id; (3) family with none in Set Up → null.

### 3.5 `AS_GSS_UT_hasOpenCompleteEvaluationTask`
**Purpose:** boolean — does the evaluation still have an open (incomplete) *Complete Evaluation* task? Used to gate round completion (finalize before advancing).
**Used by:** `completeRound` action visibility / Complete-Round guard.
**Inputs:** `evaluationId` (Integer) — *"(Required) The evaluation (round) to check."*
**Implementation:**
```
a!localVariables(
  local!openCount: rule!AS_GSS_TMG_QR_getTasks(
    returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_TOTAL_COUNT,
    executeWhen: rule!AS_CO_UT_isNotBlank(ri!evaluationId),
    evaluationId: ri!evaluationId,
    fields: 'recordType!{9a04b944-b726-41f5-9b37-8ec71b6cc370}AS_GSS_TMG_Task_SYNCEDRECORD.fields.{1fabfb92-f90c-4989-9893-ec25aad2a246}taskId',
    additionalFilters: {
      a!queryFilter(
        field: 'recordType!{9a04b944}...{d722d6e1}taskRefId',
        operator: "=",
        value: cons!AS_GSS_TMG_TASK_REF_ID_COMPLETE_EVALUATION
      ),
      a!queryFilter(
        field: 'recordType!{9a04b944}...{5f21703e}taskStatusId',
        operator: "not in",
        value: {
          cons!AS_GSS_TMG_REF_ID_TASK_STATUS_COMPLETE,
          cons!AS_GSS_TMG_REF_ID_TASK_STATUS_NOT_NEEDED,
          cons!AS_GSS_TMG_REF_ID_TASK_STATUS_CANCELLED
        }
      )
    }
  ),
  a!defaultValue(local!openCount, 0) > 0
)
```
**Notes:** affirmative return (`true` = an open task exists); callers gate with `not(...)`.
**Test cases:** "Case with No Assertions". (1) null; (2) evaluation with an open Complete-Evaluation task → true; (3) none open → false.

---

## Batch tracker (build order)
1. **Data model** — §2 ✅
2. **Family & round helpers** — §3 ✅ (`getEvaluationRoundDetails`, `getRoundsForEvaluation`, `returnIdentifiersForEvaluationRounds`, `returnLatestChildEvaluationInSetupForGivenEvaluation`, `hasOpenCompleteEvaluationTask`)
3. **Start Evaluation as Round 1** — modal, PM (node-by-node), record actions + visibility — *next*
4. **Round-aware tabs** — embeddable content + wrapper(s)
5. **Setup New Round + clone** — wizard, duplicate, team-mapping, factor-doc-mapping
6. **Start / Complete round + Rounds panel**
7. **Summary recomposition + Vendors**
8. **Integration touchpoints** (VM, GCW)
