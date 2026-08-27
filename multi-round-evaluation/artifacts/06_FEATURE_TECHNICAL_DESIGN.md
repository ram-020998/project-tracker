# 06 — Feature Technical Design: GSS Multi-Round Evaluations

Object-by-object technical design to build the feature: for each object, its **purpose, where it's used, the implementation, and test cases**. Read alongside `05_FEATURE_IMPLEMENTATION_PLAN.md` (the *what/where/why*). **Governing standard:** `SOLUTIONS - Design Best Practices & Guidance 3.md` — §1 below distills the parts most relevant here; that doc wins in any conflict.

**Status: COMPLETE** — all 8 batches specified (§2–§9). Filled in build order; see the batch tracker at the end. Open PO confirmations are flagged inline and summarized at the end.

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

## 4. Start Evaluation as Round 1

Starting a Best Value evaluation registers the parent as **Round 1** and generates tasks/ratings/consensus scoped to the selected factors. Three objects: the modal (4.1), the process (4.2), and the record actions (4.3).

### 4.1 `AS_GSS_FM_startEvaluationBestValue` (form/modal)
**Purpose:** confirm Round 1 details (name, dates) and choose the factors for the round; on submit, set the evaluation In Progress and register it as Round 1.
**Used by:** the `startEvaluationBestValue` record action (4.3) as its start form.
**Inputs:** `evaluation` (`AS_GSS_Evaluation_SYNCEDRECORD`, Required), `userAction` (Text — set to Start/Cancel on submit), `selectedFactorIds` (List of Integer — output: the factors chosen for the round).
**Behaviour:**
- Load parent factors (active, `parentCriteriaId` null); default **all** selected; show a live "N of N selected" count.
- Round Name defaults to the "Initial Evaluation" label; Start Date + Duration keep Due Date in sync; validate Due ≥ Start **and** that round dates fall within the evaluation's dates.
- On **Start**: output `selectedFactorIds` and `userAction = START`; set the evaluation to In Progress with the chosen dates + modified audit, and populate its `round` relationship with one `EvaluationRound` (`sequence = 1`, `parentEvalId = null`, `isOnSpotConsensus` from the evaluation) so the row cascades on the process write. On **Cancel**: `userAction = CANCEL`.
- All display text via the app i18n bundle (`AS_GSS_CO_UT_loadBundleFromFolder` + `AS_GAM_CO_I18N_UT_displayLabel`); no hard-coded strings.

**Implementation:**
```
a!localVariables(
  local!i18nData: rule!AS_GSS_CO_UT_loadBundleFromFolder(langISOCode: null),
  /* Active parent factors for this evaluation (subfactors excluded from the picker). */
  local!factors: rule!AS_GSS_QR_getCriteria(
    returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_OBJECT_ARRAY,
    evaluationId: ri!evaluation['recordType!{e6bc8561}...{7f7c2d3b}evaluationId'],
    isActive: true(),
    parentCriteriaId: null   /* filter to parents; see getCriteria filter inputs */
  ),
  /* Default selection = all factors (mockup shows "N of N selected"). */
  local!selectedFactorIds: a!defaultValue(
    ri!selectedFactorIds,
    local!factors['recordType!{11dcc745}...{6ecea02c}criteriaId']
  ),
  /* Round-1 record being built in the form. */
  local!round: 'recordType!{931e8145}AS_GSS_EvaluationRound_SYNCEDRECORD'(
    'recordType!{931e8145}...{31c08880}roundName': rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_InitialEvaluation"),
    'recordType!{931e8145}...{7abbf0d2}startDate': ri!evaluation['recordType!{e6bc8561}...{5e919546}evaluationStartDate'],
    'recordType!{931e8145}...{c3f17341}endDate': ri!evaluation['recordType!{e6bc8561}...{46715106}evaluationDueDate']
  ),
  a!formLayout(
    label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_StartEvaluation"),
    instructions: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "ins_StartEvaluationConfirm"),
    contents: {
      /* Round details: Name | Start | Duration | Due — Start+Duration keep Due in sync. */
      a!columnsLayout(columns: {
        a!columnLayout(contents: a!textField(
          label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_RoundName"),
          required: true(),
          value: local!round['recordType!{931e8145}...{31c08880}roundName'],
          saveInto: local!round['recordType!{931e8145}...{31c08880}roundName']
        )),
        a!columnLayout(contents: a!dateField(
          label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_StartDate"),
          required: true(),
          value: local!round['recordType!{931e8145}...{7abbf0d2}startDate'],
          saveInto: {
            local!round['recordType!{931e8145}...{7abbf0d2}startDate'],
            a!save(local!round['recordType!{931e8145}...{c3f17341}endDate'],
              if(rule!AS_CO_UT_isNotBlank(local!round['recordType!{931e8145}...{ecb1038d}duration']),
                 save!value + local!round['recordType!{931e8145}...{ecb1038d}duration'],
                 local!round['recordType!{931e8145}...{c3f17341}endDate']))
          }
        )),
        a!columnLayout(contents: a!integerField(
          label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_DurationDays"),
          value: local!round['recordType!{931e8145}...{ecb1038d}duration'],
          saveInto: {
            local!round['recordType!{931e8145}...{ecb1038d}duration'],
            a!save(local!round['recordType!{931e8145}...{c3f17341}endDate'],
              if(rule!AS_CO_UT_isNotBlank(local!round['recordType!{931e8145}...{7abbf0d2}startDate']),
                 local!round['recordType!{931e8145}...{7abbf0d2}startDate'] + save!value,
                 local!round['recordType!{931e8145}...{c3f17341}endDate']))
          }
        )),
        a!columnLayout(contents: a!dateField(
          label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_DueDate"),
          required: true(),
          value: local!round['recordType!{931e8145}...{c3f17341}endDate'],
          saveInto: local!round['recordType!{931e8145}...{c3f17341}endDate'],
          validations: a!validationMessage(
            validateAfter: "SUBMIT",
            message: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "vld_RoundDatesWithinEvaluation"),
            /* Due ≥ Start, and round window within the evaluation window. */
            showWhen: or(
              local!round['recordType!{931e8145}...{c3f17341}endDate'] < local!round['recordType!{931e8145}...{7abbf0d2}startDate'],
              local!round['recordType!{931e8145}...{7abbf0d2}startDate'] < ri!evaluation['recordType!{e6bc8561}...{5e919546}evaluationStartDate'],
              local!round['recordType!{931e8145}...{c3f17341}endDate'] > ri!evaluation['recordType!{e6bc8561}...{46715106}evaluationDueDate']
            )
          )
        ))
      }),
      /* Factor selector: header with live count + one selectable card per factor. */
      a!sectionLayout(
        label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_Factors"),
        contents: {
          a!richTextDisplayField(
            labelPosition: "COLLAPSED",
            value: a!richTextItem(
              text: rule!AS_GAM_CO_I18N_UT_displayLabel(
                bundle: local!i18nData, bundleKey: "txt_NOfMSelected",
                arguments: { count(local!selectedFactorIds), count(local!factors) }
              ),
              style: "STRONG"
            )
          ),
          a!forEach(
            items: local!factors,
            expression: a!cardLayout(
              padding: "STANDARD",
              marginBelow: "STANDARD",
              contents: a!sideBySideLayout(
                alignVertical: "MIDDLE",
                items: {
                  a!sideBySideItem(width: "MINIMIZE", item: a!checkboxField(
                    labelPosition: "COLLAPSED",
                    choiceLabels: { "" },
                    choiceValues: { fv!item['recordType!{11dcc745}...{6ecea02c}criteriaId'] },
                    value: if(contains(local!selectedFactorIds, fv!item['recordType!{11dcc745}...{6ecea02c}criteriaId']),
                              fv!item['recordType!{11dcc745}...{6ecea02c}criteriaId'], null),
                    saveInto: a!save(local!selectedFactorIds,
                      if(contains(local!selectedFactorIds, fv!item['recordType!{11dcc745}...{6ecea02c}criteriaId']),
                         remove(local!selectedFactorIds, wherecontains(fv!item['recordType!{11dcc745}...{6ecea02c}criteriaId'], local!selectedFactorIds)),
                         append(local!selectedFactorIds, fv!item['recordType!{11dcc745}...{6ecea02c}criteriaId'])))
                  )),
                  a!sideBySideItem(item: a!richTextDisplayField(
                    labelPosition: "COLLAPSED",
                    value: a!richTextItem(text: fv!item['recordType!{11dcc745}...{7bfcd928}criteriaName'], style: "STRONG")
                  ))
                }
              )
            )
          )
        }
      )
    },
    buttons: a!buttonLayout(
      primaryButtons: a!buttonWidget(
        label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "btn_StartEvaluation"),
        submit: true(), validate: true(), style: "SOLID", loadingIndicator: true(),
        saveInto: {
          a!save(ri!selectedFactorIds, local!selectedFactorIds),
          a!save(ri!userAction, cons!AS_GSS_ENUM_USER_ACTION_START),
          a!save(ri!evaluation, rule!AS_GSS_UT_updateRecordsByModelRecord(
            records: ri!evaluation,
            modelRecord: 'recordType!{e6bc8561}AS_GSS_Evaluation_SYNCEDRECORD'(
              'recordType!{e6bc8561}...{4e467ee1}evaluationStatusId': cons!AS_GSS_REF_ID_EVALUATION_STATUS_INPROGRESS,
              'recordType!{e6bc8561}...{5e919546}evaluationStartDate': local!round['recordType!{931e8145}...{7abbf0d2}startDate'],
              'recordType!{e6bc8561}...{46715106}evaluationDueDate': local!round['recordType!{931e8145}...{c3f17341}endDate'],
              'recordType!{e6bc8561}...{fa99070d}modifiedBy': loggedInUser(),
              'recordType!{e6bc8561}...{c795b29e}modifiedDatetime': now(),
              /* Cascade Round 1: parentEvalId null (root), sequence 1. */
              'recordType!{e6bc8561}...{ffe492a5}round': rule!AS_GSS_UT_updateRecordsByModelRecord(
                records: local!round,
                modelRecord: 'recordType!{931e8145}AS_GSS_EvaluationRound_SYNCEDRECORD'(
                  'recordType!{931e8145}...{1756683f}evaluationId': ri!evaluation['recordType!{e6bc8561}...{7f7c2d3b}evaluationId'],
                  'recordType!{931e8145}...{parentEvalId}parentEvalId': null,
                  'recordType!{931e8145}...{d20a1017}sequence': 1,
                  'recordType!{931e8145}...{85812d35}isOnSpotConsensus': a!defaultValue(ri!evaluation['recordType!{e6bc8561}...{8962d2c5}isOnSpotConsensus'], false()),
                  'recordType!{931e8145}...{1929b250}createdBy': loggedInUser(),
                  'recordType!{931e8145}...{bd6df6db}createdOn': now()
                )
              )
            )
          ))
        }
      ),
      secondaryButtons: a!buttonWidget(
        label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "btn_Cancel"),
        submit: true(), validate: false(), style: "GHOST",
        saveInto: a!save(ri!userAction, cons!AS_CO_ENUM_USER_ACTION_CANCEL)
      )
    )
  )
)
```
**Notes:** if `AS_GSS_QR_getCriteria` has no `parentCriteriaId` filter input, filter parents in a local instead. New i18n keys: `lbl_InitialEvaluation`, `ins_StartEvaluationConfirm`, `lbl_RoundName/StartDate/DurationDays/DueDate/Factors`, `txt_NOfMSelected`, `vld_RoundDatesWithinEvaluation`, `btn_StartEvaluation`.
**Test cases (interface):** default inputs = a Set-Up Best Value evaluation with ≥2 factors → renders, all selected, count correct; toggling a factor updates the count.

### 4.2 `AS GSS Start Evaluation Best Value` (process model)
**Trigger:** the `startEvaluationBestValue` record action. **Start form:** 4.1 (headless-capable). **Lane/assignment:** initiator, unattended. **Security:** own group `AS GSS Start Evaluation Best Value PM Access` (viewers), business groups (Contracting Officer) as direct members. **Archiving:** delete after 1 day (backend). **PVs:** `evaluation`, `originalEvaluation`, `evaluationFactorsAndSubFactors`, `originalEvaluationFactorsAndSubFactors`, `vendors`, `selectedFactorIds` (List of Integer), `userAction`, `evaluationRatings`.

Node-by-node (no LPTA branch):

| # | Node | Type | Purpose / data |
| :-- | :--- | :--- | :--- |
| 1 | Start | Start | Start form = 4.1. |
| 2 | Cancelled? | XOR | `userAction = CANCEL` → End; else node 3. |
| 3 | Update Evaluation Record | Write Records | Write `pv!evaluation` (incl. `round` rel → cascades Round 1). |
| 4 | Sync Eval Status in GCW | Subprocess (`0006ef1c…`) | async; pass `evaluationId`. |
| 5 | Scope Selected Factors | Script (UMQ) | `pv!evaluationFactorsAndSubFactors` ← factors whose `criteriaId ∈ selectedFactorIds` **or** `parentCriteriaId ∈ selectedFactorIds`. |
| 6 | Create Ratings | Script | `pv!evaluationRatings ← rule!AS_GSS_BL_createTransactionalRatings(initiator, evaluationFactorsAndSubFactors, evaluation)`. |
| 7 | Write Rating Records | Write Records | write `pv!evaluationRatings`; then `pv!evaluationFactorsAndSubFactors ← rule!AS_GSS_BL_updateRatingDetailsToCriteriaRecords(...)`. |
| 8 | Update Factors With Ratings | Write Records | write `pv!evaluationFactorsAndSubFactors` (Criteria). |
| 9 | Vendor Analysis enabled? | XOR | `cons!AS_GSS_TOGGLE_VENDOR_ANALYSIS_ENABLED` → node 10; else node 11. |
| 10 | Trigger Reqt Extraction | Subprocess (`0005ef63…`) | async; pass `evaluationId`. |
| 11 | On-the-spot consensus? | XOR | `a!defaultValue(evaluation.isOnSpotConsensus, false)` → node 13 (consensus only); else node 12. |
| 12 | Generate Evaluation Tasks | Subprocess (`0002edab…`) | pass scoped factors + vendors. |
| 13 | Create Consensus Reports | Subprocess (`0003ece5…`) | pass scoped factors + vendors. |
| 14 | Capture Audit | Subprocess (`0007e5df…`) | `AS_GSS_UT_constructStartEvaluationAudit(...)`. |
| 15 | End | End | |

**Notes:** all generation (nodes 12–13) receives the scoped `pv!evaluationFactorsAndSubFactors` from node 5, so tasks/ratings/consensus are automatically limited to the selected factors × vendors. Build the two async subprocess calls (4, 10) as **Start Process / subprocess** nodes per §7; no placeholder/"dummy" nodes.

### 4.3 Record actions on `AS_GSS_Evaluation_RECORD`
Both **related actions**. Visibility reads record **relationship/field values** (no re-query) for performance (§3.E.4); context passes specific objects, never `rv!record`.

| Action | Key | Process | Visibility (plain English) | Context |
| :--- | :--- | :--- | :--- | :--- |
| **Start Evaluation (BV)** *(new)* | `startEvaluationBestValue` | 4.2 | Set-Up **and** method = Best Value **and** `parentEvalId` is blank (root only). | build `evaluation`, `originalEvaluation`, `evaluationFactorsAndSubFactors` (active criteria), `originalEvaluationFactorsAndSubFactors`, `vendors`, `selectedFactorIds: {}`, `userAction: null`. |
| **Start Evaluation** *(existing — guard)* | `startEvaluation` | `0002ecdd…` | existing Start-Evaluation visibility **and** method **≠** Best Value. | unchanged. |

Visibility for the new action (relationship-based):
```
and(
  rule!AS_GSS_BL_getRelatedActionVisibilityForStartEvaluation(
    statusId: rv!record['recordType!{4db4a62e}...{evaluationStatus}evaluationStatus.{refDataId}refDataId'],
    evaluationId: rv!record['recordType!{4db4a62e}...{evaluationId}evaluationId']
  ),
  rv!record['recordType!{4db4a62e}...{evaluationMethod}evaluationMethod.{refDataId}refDataId'] = cons!AS_GSS_REF_ID_EVALUATION_METHOD_BEST_VALUE,
  rule!AS_CO_UT_isBlank(rv!record['recordType!{4db4a62e}...{parentEvalId}parentEvalId'])
)
```
**Notes:** confirm the record exposes `evaluationMethod` (relationship → `refDataId`) and `parentEvalId` as record fields; if not, add them. Net effect: root Best-Value → Start Evaluation (BV); child round → Start Round (§6 batch); other methods → the original Start Evaluation.

## 5. Round-aware content tabs

Each Evaluation content tab shows **one sub-tab per round**, rendering that tab's existing content for the round's evaluation clone. The scaffolding (resolve family → tab per round → render content) is identical for every tab, so it lives in **one** wrapper; the per-tab content interfaces stay separate but must be **embeddable**.

**Consolidation:** the eight prototype `_Parent` wrappers and the `returnViewRenderingConfigFor_Factors` rule are replaced by a **single** wrapper `AS_GSS_CPS_roundContentTabs`, selected per view by a `tabType`. (SAIL can't invoke a rule passed as a parameter, so the wrapper routes to the right content with `a!match` — one router, not eight copies.)

### 5.1 Embeddable-content contract (applies to all 8 content interfaces)
Each content interface (`AS_GSS_CPS_viewFactors`, `AS_GSS_CPS_viewEvaluatorTeam`, `AS_GSS_CPS_consensusReportView`, `AS_GSS_FM_evaluationDocumentsTab`, `AS_GSS_TMG_FM_taskAuditActionHistory`, `AS_GSS_CPS_evaluationRatingsTab`, `AS_GSS_TMG_CPS_viewRecordTasks`, `AS_GSS_FM_evaluationAuditHistory`) must:
- render **without** an outer `headerContentLayout`/wrapper (the wrapper supplies the one frame) — a `tabItem` rejects a header layout; strip **all** such frames (some interfaces have several branches);
- use `columnsLayout`, not `paneLayout`, at the top level (panes are rejected inside `tabItem`);
- null-harden against a per-round evaluationId that resolves to nothing (guard status comparisons with `a!defaultValue(..., -1)`);
- take a single per-round input — either the round's `evaluationId` or its queried `evaluation` (see 5.4).

### 5.2 `AS_GSS_CPS_roundContentTabs` (the one wrapper — replaces all 8 `_Parent`)
**Purpose:** render a record's content as one sub-tab per round of the family.
**Used by:** all eight Evaluation record views (each passes its own `tabType`).
**Inputs:** `evaluationId` (Integer — *"(Required) the record's evaluationId"*), `tabType` (Text — *"(Required) which content to render; one of `cons!AS_GSS_ENUM_ROUND_TAB_*`"*).
**Implementation:**
```
a!localVariables(
  local!i18nData: rule!AS_GSS_CO_UT_loadBundleFromFolder(langISOCode: null),
  local!rounds: rule!AS_GSS_QR_getRoundsForEvaluation(evaluationId: ri!evaluationId),
  /* Fallback to the current evaluation when there are no round rows (non-round / leaf record),
     so content never receives a null evaluationId. */
  local!tabs: if(
    a!isNullOrEmpty(local!rounds),
    { a!map(evaluationId: ri!evaluationId, sequence: null) },
    a!forEach(
      items: local!rounds,
      expression: a!map(
        evaluationId: fv!item['recordType!{931e8145}...{1756683f}evaluationId'],
        sequence: fv!item['recordType!{931e8145}...{d20a1017}sequence']
      )
    )
  ),
  a!headerContentLayout(
    contentsPadding: "NONE",
    backgroundColor: rule!AS_GSS_BrandingValueByKey(brandingKey: "DefaultBackground", useSuiteBranding: true),
    contents: a!tabLayout(
      /* lazy-loads inactive tabs, so only the open round's content/query runs */
      tabs: a!forEach(
        items: local!tabs,
        expression: a!tabItem(
          label: rule!AS_GAM_CO_I18N_UT_displayLabel(
            bundle: local!i18nData, bundleKey: "lbl_RoundN", arguments: fv!item.sequence
          ),
          contents: a!match(
            value: ri!tabType,
            equals: cons!AS_GSS_ENUM_ROUND_TAB_FACTORS,      then: rule!AS_GSS_CPS_viewFactors(evaluationId: fv!item.evaluationId, loggedInUser: loggedInUser()),
            equals: cons!AS_GSS_ENUM_ROUND_TAB_TEAMS,        then: rule!AS_GSS_CPS_viewEvaluatorTeam(evaluationId: fv!item.evaluationId),
            equals: cons!AS_GSS_ENUM_ROUND_TAB_CONSENSUS,    then: rule!AS_GSS_CPS_consensusReportView(evaluationId: fv!item.evaluationId),
            equals: cons!AS_GSS_ENUM_ROUND_TAB_DOCUMENTS,    then: rule!AS_GSS_FM_evaluationDocumentsTab(evaluationId: fv!item.evaluationId),
            equals: cons!AS_GSS_ENUM_ROUND_TAB_TASK_HISTORY, then: rule!AS_GSS_TMG_FM_taskAuditActionHistory(evaluationId: fv!item.evaluationId),
            equals: cons!AS_GSS_ENUM_ROUND_TAB_RATINGS,      then: rule!AS_GSS_CPS_evaluationRatingsTab(evaluation: rule!AS_GSS_QR_getEvaluationByIdentifier(evaluationId: fv!item.evaluationId)),
            equals: cons!AS_GSS_ENUM_ROUND_TAB_TASKS,        then: rule!AS_GSS_TMG_CPS_viewRecordTasks(evaluation: rule!AS_GSS_QR_getEvaluationByIdentifier(evaluationId: fv!item.evaluationId)),
            equals: cons!AS_GSS_ENUM_ROUND_TAB_EVAL_HISTORY, then: rule!AS_GSS_FM_evaluationAuditHistory(evaluation: rule!AS_GSS_QR_getEvaluationByIdentifier(evaluationId: fv!item.evaluationId)),
            default: {}
          )
        )
      )
    )
  )
)
```
**Notes:** `lbl_RoundN` takes the sequence as an argument; when `sequence` is null (fallback tab) it should render a plain "Round"/current label. Confirm each content interface's exact input name (5.4).
**Test cases (interface):** default inputs = a multi-round family + each `tabType` → renders one tab per round; a non-round evaluation → single fallback tab.

### 5.3 Tab-type constants
Group as `cons!AS_GSS_ENUM_ROUND_TAB_*` (one text/int constant each): `FACTORS`, `TEAMS`, `CONSENSUS`, `DOCUMENTS`, `TASK_HISTORY`, `RATINGS`, `TASKS`, `EVAL_HISTORY`. (Constants so views are dependency-checkable; per best-practices §4.)

### 5.4 Content-interface input map
| Tab | Content interface (embeddable) | tabType | Per-round input |
| :--- | :--- | :--- | :--- |
| Factors | `AS_GSS_CPS_viewFactors` | `FACTORS` | `evaluationId` (+ `loggedInUser`) |
| Teams | `AS_GSS_CPS_viewEvaluatorTeam` | `TEAMS` | `evaluationId` |
| Consensus | `AS_GSS_CPS_consensusReportView` | `CONSENSUS` | `evaluationId` |
| Documents | `AS_GSS_FM_evaluationDocumentsTab` | `DOCUMENTS` | `evaluationId` |
| Task History | `AS_GSS_TMG_FM_taskAuditActionHistory` | `TASK_HISTORY` | `evaluationId` |
| Ratings | `AS_GSS_CPS_evaluationRatingsTab` | `RATINGS` | `evaluation` (queried) |
| Checklist / Tasks | `AS_GSS_TMG_CPS_viewRecordTasks` | `TASKS` | `evaluation` (queried) |
| Evaluation History | `AS_GSS_FM_evaluationAuditHistory` | `EVAL_HISTORY` | `evaluation` (queried) |

The three "queried" tabs take a full `evaluation` object, so the wrapper queries it per round via `AS_GSS_QR_getEvaluationByIdentifier` inside the branch (the tab layout lazy-loads, so only the open round queries).

### 5.5 Record-view wiring (manual in Designer)
Each of the eight Evaluation record views points its interface expression at the one wrapper with its `tabType`, e.g. the Teams view:
```
rule!AS_GSS_CPS_roundContentTabs(
  evaluationId: rv!record['recordType!{4db4a62e}...{evaluationId}evaluationId'],
  tabType: cons!AS_GSS_ENUM_ROUND_TAB_TEAMS
)
```
Eliminated by this batch: the eight `*_Parent` wrappers and `AS_GSS_UT_returnViewRenderingConfigFor_Factors` (their behaviour is subsumed by `AS_GSS_CPS_roundContentTabs`).

## 6. Setup New Round + clone

Rounds 2–5 are created by cloning the current round. The wizard (6.1) gathers round details, factors, and the advancing vendors; the process (6.6) copies reference documents, builds and writes the clone, then carries the factor→team and factor→document mappings; the record action (6.7) gates availability.

### 6.1 `AS_GSS_FM_startNewRound` (wizard)
**Purpose:** collect the new round's details, its factors, and its down-selected vendors, and hand a fully-formed new-evaluation shell to the process.
**Used by:** the `setupNewRound` record action as its start form.
**Inputs:** `parentEvaluationId` (Integer, Required), `duplicatedFromEvaluation` (`AS_GSS_Evaluation_SYNCEDRECORD` — the round being cloned from), `newEvaluation` (`AS_GSS_Evaluation_SYNCEDRECORD` — output shell), `evaluators` (List of Text), `templateEvaluation` (`AS_GSS_Evaluation_SYNCEDRECORD`), `userAction` (Text).
**Behaviour (wizard steps):**
- **Step 1 — Round details + factors:** Round Name, Start/Duration/Due (kept in sync; validated within the parent evaluation's window), the per-round **On-the-Spot Consensus** toggle, and a factor checklist (Team/Evaluators shown; carried from the previous round, editable). "N of N selected".
- **Step 2 — Vendor down-select:** the vendor grid (6.2); must advance **≥1**; previously-excluded vendors can be re-included.
- **Step 3 (optional) — Resubmission request:** *Send as Update / Email* + Title/Description (include only if in scope — confirm with PO).
- On submit, populate `newEvaluation` as a shell carrying the chosen dates, `parentEvalId` = the family root, selected factors, and the advancing vendors, plus the round row (`sequence` = previous + 1, `isOnSpotConsensus` from step 1); set `userAction = CREATE`. The heavy cloning of related data is done by the rule in the process (6.3), not in the form.
- All display text via i18n; logic in rules, not the form (§ standard).

**Notes:** the form stays light — it captures selections and defers cloning to `AS_GSS_UT_duplicateEvaluationForNewRound`. Step count (2 vs 3) is a PO decision.

### 6.2 `AS_GSS_GRD_vendorListForSelection` (grid)
**Purpose:** selectable list of the source round's vendors for down-selection (Name + UEI), with a running "N selected".
**Inputs:** `evaluationId` (Integer — the source round), `selectedVendorIds` (List of Integer — in/out), `readOnly` (Boolean).
**Implementation:** `a!gridField` over `AS_GSS_QR_getEvaluationVendors(returnType: OBJECT_ARRAY, evaluationId, isActive: true)`, with a selection column bound to `selectedVendorIds`; columns Name (`legalName`) and UEI (`uniqueEntityId`). Selection correlates vendors across rounds by **`uniqueEntityId`** (not `vendorId`, which changes each round). Empty-selection validation is enforced by the wizard.

### 6.3 `AS_GSS_UT_duplicateEvaluationForNewRound` (clone builder)
**Purpose:** build (not write) the new round's evaluation graph from the source round + the wizard's shell.
**Inputs:** `sourceEvaluation`, `newEvaluation` (shell from the form), `newReferenceDocIds` (List of Integer — copies made in the process), `initiator` (User), `templateEvaluation`.
**Output:** a map `{ newEvaluation, criteriaTeamMap }` — `newEvaluation` is the full graph to write; `criteriaTeamMap` is a list of `{criteriaNumber, teamName}` used later to re-point teams (6.4).
**What the graph carries — copy / null / reset:**
| Entity | Copy (preserve) | Null (new PK / re-link on write) | Reset |
| :--- | :--- | :--- | :--- |
| Evaluation | title, method, instrument, settings; **`parentEvalId` = family root**; status = SETTING_UP; start/due from form | `evaluationId` | created/modified = initiator/now |
| `round` (EvaluationRound) | `roundName`, dates, `isOnSpotConsensus` from form; **`parentEvalId` = root**; `sequence` = source max + 1 | `roundId` | created/modified |
| Criteria (+ SubCriteria) | name, description, weight, rating type, `factorNumber`, assignments | `criteriaId`, `parentCriteriaId` (re-linked on cascade); `evaluatorTeamId` set later (6.4) | — |
| Vendors (down-selected) | business fields; correlate across rounds by `uniqueEntityId` | `vendorId`, `evaluationId` | — |
| Vendor documents | `appianDocId` (same file; reference docs use `newReferenceDocIds`), name/type/version/flags | `evaluationDocumentId`, `vendorId`, `evaluationId`, `consensusId`, `criteriaId`, `taskId` | created/modified |
**Notes:** full field-by-field construction is mechanical from this table; keep it a **builder only** (no writes/queries beyond what's needed to shape the graph) so the process controls persistence. `FactorDocumentMapping` is **not** built here (its FKs are DB-generated) — handled in 6.5.

### 6.4 `AS_GSS_UT_updateFactorTeamMappingForDuplicatedEvaluation`
**Purpose:** after the clone is written (teams now have new ids), set each criterion's `evaluatorTeamId` to the new round's team whose name matches the carried factor→team mapping.
**Inputs:** `newEvaluation` (with `criteria` + `team` relationships loaded), `criteriaTeamMap` (List of Map `{criteriaNumber, teamName}`).
**Implementation** (merge semantics — only `evaluatorTeamId` is overridden; all other criteria fields are preserved by `updateRecordsByModelRecord`):
```
a!localVariables(
  /* New round's teams: parallel name/id arrays for lookup. */
  local!teamNames: upper(a!flatten(ri!newEvaluation['recordType!{e6bc8561}...{fc1817be}team.fields.{be5bfc13}teamName'])),
  local!teamIds: a!flatten(ri!newEvaluation['recordType!{e6bc8561}...{fc1817be}team.fields.{35b9691a}teamId']),
  if(
    rule!AS_CO_UT_isBlank(ri!criteriaTeamMap),
    ri!newEvaluation,
    rule!AS_GSS_UT_updateRecordsByModelRecord(
      records: ri!newEvaluation,
      modelRecord: 'recordType!{e6bc8561}AS_GSS_Evaluation_SYNCEDRECORD'(
        'recordType!{e6bc8561}...{82cb0b32}criteria': a!forEach(
          items: ri!newEvaluation['recordType!{e6bc8561}...{82cb0b32}criteria'],
          expression: rule!AS_GSS_UT_updateRecordsByModelRecord(
            records: fv!item,
            modelRecord: 'recordType!{11dcc745}AS_GSS_Criteria_SYNCEDRECORD'(
              /* factorNumber -> teamName (carried) -> new teamId */
              'recordType!{11dcc745}...{863f75e7}evaluatorTeamId': index(
                local!teamIds,
                wherecontains(
                  upper(index(ri!criteriaTeamMap.teamName,
                    wherecontains(upper(fv!item['recordType!{11dcc745}...{a37cdba7}factorNumber']), upper(ri!criteriaTeamMap.criteriaNumber)), null)),
                  local!teamNames
                ),
                null
              ),
              /* Same re-point for subfactors. */
              'recordType!{11dcc745}...{d5f2eb9d}SubCriteria': a!forEach(
                items: fv!item['recordType!{11dcc745}...{d5f2eb9d}SubCriteria'],
                expression: rule!AS_GSS_UT_updateRecordsByModelRecord(
                  records: fv!item,
                  modelRecord: 'recordType!{11dcc745}AS_GSS_Criteria_SYNCEDRECORD'(
                    'recordType!{11dcc745}...{863f75e7}evaluatorTeamId': index(
                      local!teamIds,
                      wherecontains(
                        upper(index(ri!criteriaTeamMap.teamName,
                          wherecontains(upper(fv!item['recordType!{11dcc745}...{a37cdba7}factorNumber']), upper(ri!criteriaTeamMap.criteriaNumber)), null)),
                        local!teamNames
                      ),
                      null
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)
```
**Test cases:** contains no DB query → assertable. (1) null map → returns input unchanged; (2) a criterion whose factorNumber maps to a team name present on the new round → `evaluatorTeamId` set to that team's id.

### 6.5 `AS_GSS_UT_constructFactorDocumentMappingsForNewRound`
**Purpose:** after the round is written, produce the new `FactorDocumentMapping` rows by correlating **factor by `factorNumber`** and **document by `appianDocId`**; a source mapping is copied only when both its factor and document exist on the new round (so dropped factors/docs drop their mappings).
**Inputs:** `newEvaluationId`, `sourceEvaluationId`, `initiator`.
**Implementation** (query both sides once, then translate each source mapping through the stable business keys):
```
a!localVariables(
  /* SOURCE: mapping FKs -> business keys */
  local!sourceCriteria: rule!AS_CO_UT_queryRecord(recordType: 'recordType!{11dcc745}…', returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_OBJECT_ARRAY,
    fields: { criteriaId, factorNumber }, filters: { evaluationId = ri!sourceEvaluationId, isActive = true }),
  local!sourceDocs: rule!AS_CO_UT_queryRecord(recordType: 'recordType!{9c497e08}…', returnType: OBJECT_ARRAY,
    fields: { evaluationDocumentId, appianDocId }, filters: { vendorId in <source vendors>, isDeleted = false }),
  local!sourceMappings: rule!AS_CO_UT_queryRecord(recordType: 'recordType!{acd503e1}…', returnType: OBJECT_ARRAY,
    fields: { documentId, factorId }, filters: { documentId in local!sourceDocs.evaluationDocumentId, isActive = true }),
  /* NEW: business keys -> new FKs */
  local!newCriteria: rule!AS_CO_UT_queryRecord(recordType: 'recordType!{11dcc745}…', returnType: OBJECT_ARRAY,
    fields: { criteriaId, factorNumber }, filters: { evaluationId = ri!newEvaluationId, isActive = true }),
  local!newDocs: rule!AS_CO_UT_queryRecord(recordType: 'recordType!{9c497e08}…', returnType: OBJECT_ARRAY,
    fields: { evaluationDocumentId, appianDocId }, filters: { vendorId in <new vendors>, isDeleted = false }),
  a!flatten(a!forEach(
    items: local!sourceMappings,
    expression: a!localVariables(
      /* source factorId -> factorNumber -> new criteriaId */
      local!factorNumber: index(local!sourceCriteria.factorNumber, wherecontains(fv!item.factorId, local!sourceCriteria.criteriaId), null),
      local!newFactorId: index(local!newCriteria.criteriaId, wherecontains(local!factorNumber, local!newCriteria.factorNumber), null),
      /* source documentId -> appianDocId -> new documentId */
      local!appianDocId: index(local!sourceDocs.appianDocId, wherecontains(fv!item.documentId, local!sourceDocs.evaluationDocumentId), null),
      local!newDocumentId: index(local!newDocs.evaluationDocumentId, wherecontains(local!appianDocId, local!newDocs.appianDocId), null),
      if(
        or(a!isNullOrEmpty(local!newFactorId), a!isNullOrEmpty(local!newDocumentId)),
        {},
        'recordType!{acd503e1}AS_GSS_FactorDocumentMapping_SYNCEDRECORD'(
          factorId: local!newFactorId, documentId: local!newDocumentId, isActive: true,
          createdBy: ri!initiator, createdDatetime: now()
        )
      )
    )
  ))
)
```
*(Field refs shown by name for brevity; use full UUID refs. Wrap index lookups' comparands with `tointeger(...)` where the keys are integer, and guard nulls as shown.)*
**Test cases:** contains DB queries → "Case with No Assertions". (1) null ids; (2) source with mappings whose factor+doc carried → returns mappings; (3) a factor dropped from the new round → its mapping is not returned.

### 6.6 `AS GSS Setup New Round` (process model)
**Trigger:** `setupNewRound` action. **Start form:** 6.1. **Lane:** initiator, System lane for writes. **Security:** own `… PM Access` group. **Archive:** delete after 1 day (backend). **PVs:** `duplicatedFromEvaluation`, `newEvaluation`, `newReferenceDocIds` (List of Integer), `criteriaTeamMap` (List of Map), `evaluators`, `templateEvaluation`, `userAction`.

| # | Node | Type | Purpose |
| :-- | :--- | :--- | :--- |
| 1 | Start | Start | form = 6.1 |
| 2 | Cancelled? | XOR | `userAction = CANCEL` → End |
| 3 | Get Source Reference Docs | Script | query source round's reference documents |
| 4 | Any reference docs? | XOR | none → skip node 5 |
| 5 | Copy Reference Docs | Copy Document (MNI) | copy each → collect `newReferenceDocIds` |
| 6 | Construct Clone Graph | Script | `AS_GSS_UT_duplicateEvaluationForNewRound(...)` → `{newEvaluation, criteriaTeamMap}` |
| 7 | Write Evaluation | Write Records | persist `newEvaluation` graph (criteria/vendors/docs/round) → new PKs |
| 8 | Carry Factor→Team Mapping | Script + Write | `AS_GSS_UT_updateFactorTeamMappingForDuplicatedEvaluation(...)` → write updated criteria |
| 9 | Write Factor→Document Mappings | Write Records | `AS_GSS_UT_constructFactorDocumentMappingsForNewRound(...)` |
| 10 | Evaluation Setup | Subprocess (Create Evaluation, `0002ecdd…`) | folder/permission setup for the new round; synchronous |
| 11 | End | End | |

**Notes:** nodes 8–9 run **after** the write (they need the DB-generated criteria/document/team PKs). The new round is left **SETTING_UP** — generation happens later via **Start Round**.

### 6.7 `setupNewRound` record action
Related action on `AS_GSS_Evaluation_RECORD` → 6.6.
- **Visibility (gate):** the family has ≥1 round, **no round is SETTING_UP or INPROGRESS** (all complete), and round count < 5:
```
a!localVariables(
  local!rounds: rule!AS_GSS_QR_getRoundsForEvaluation(evaluationId: rv!record['recordType!{4db4a62e}...{evaluationId}evaluationId']),
  local!statuses: tointeger(local!rounds['recordType!{931e8145}...relationships.{029ebc2e}evaluation.fields.{4e467ee1}evaluationStatusId']),
  and(
    a!isNotNullOrEmpty(local!rounds),
    count(local!rounds) < 5,
    not(or(
      contains(local!statuses, cons!AS_GSS_REF_ID_EVALUATION_STATUS_SETTING_UP),
      contains(local!statuses, cons!AS_GSS_REF_ID_EVALUATION_STATUS_INPROGRESS)
    ))
  )
)
```
- **Context:** `parentEvaluationId: rv!identifier`, `duplicatedFromEvaluation: null`, `newEvaluation: null`, `templateEvaluation: null`, `evaluators: null`, `userAction: null` (the form loads the source round and builds the shell).

## 7. Start / Complete round + Rounds panel

Starting a round runs the same generation as Start Evaluation (without creating a round); completing a round marks its factors and the evaluation complete. The Rounds panel shows the family and hosts these actions.

### 7.1 `AS_GSS_FM_startRound` (confirm dialog)
**Purpose:** confirm that revised proposals are in and lock the round, then set it In Progress.
**Used by:** the `startRound` record action as its start form.
**Inputs:** `evaluation` (`AS_GSS_Evaluation_SYNCEDRECORD`, Required), `userAction` (Text).
**Behaviour:** show the round number and the count of **included (active) vendors**; warn that the action is irreversible (factors + vendor assignments lock). On **Start**: `userAction = START` and set the evaluation In Progress (+ modified audit); capture the weighted-factors / on-the-spot metrics. On **Cancel**: `userAction = CANCEL`. All text i18n.
**Implementation:**
```
a!localVariables(
  local!i18nData: rule!AS_GSS_CO_UT_loadBundleFromFolder(langISOCode: null),
  local!evaluationId: ri!evaluation['recordType!{e6bc8561}...{7f7c2d3b}evaluationId'],
  /* this round's sequence + included-vendor count */
  local!roundSequence: rule!AS_GSS_QR_getEvaluationRoundDetails(
    returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_SINGLE_OBJECT,
    evaluationId: local!evaluationId,
    fields: 'recordType!{931e8145}...{d20a1017}sequence'
  )['recordType!{931e8145}...{d20a1017}sequence'],
  local!includedVendorCount: rule!AS_GSS_QR_getEvaluationVendors(
    returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_TOTAL_COUNT,
    evaluationId: local!evaluationId,
    isActive: true()
  ),
  a!formLayout_25r1(
    label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_StartRoundN", arguments: local!roundSequence),
    contents: {
      a!richTextDisplayField(
        labelPosition: "COLLAPSED",
        value: rule!AS_GAM_CO_I18N_UT_displayLabel(
          bundle: local!i18nData, bundleKey: "ins_StartRoundConfirm", arguments: local!includedVendorCount
        )
      ),
      a!cardLayout(
        style: "WARN", showBorder: false(), padding: "LESS",
        contents: a!richTextDisplayField(
          labelPosition: "COLLAPSED",
          value: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "txt_StartRoundIrreversible")
        )
      )
    },
    buttons: a!buttonLayout(
      primaryButtons: a!buttonWidget(
        label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "btn_StartRound"),
        submit: true(), style: "SOLID", loadingIndicator: true(),
        saveInto: {
          a!save(ri!userAction, cons!AS_GSS_ENUM_USER_ACTION_START),
          a!save(ri!evaluation, rule!AS_GSS_UT_updateRecordsByModelRecord(
            records: ri!evaluation,
            modelRecord: 'recordType!{e6bc8561}AS_GSS_Evaluation_SYNCEDRECORD'(
              'recordType!{e6bc8561}...{4e467ee1}evaluationStatusId': cons!AS_GSS_REF_ID_EVALUATION_STATUS_INPROGRESS,
              'recordType!{e6bc8561}...{fa99070d}modifiedBy': loggedInUser(),
              'recordType!{e6bc8561}...{c795b29e}modifiedDatetime': now()
            )
          )),
          if(a!defaultValue(ri!evaluation['recordType!{e6bc8561}...{59157834}isWeightedFactorsRequired'], false()),
             rule!AS_GSS_MTR_SAVE_weightedFactorsRequiredForEvaluation(),
             rule!AS_GSS_MTR_SAVE_weightedFactorsNotRequiredForEvaluation()),
          if(a!defaultValue(ri!evaluation['recordType!{e6bc8561}...{8962d2c5}isOnSpotConsensus'], false()),
             rule!AS_GSS_MTR_SAVE_onSpotConsensusForEvaluation(), {})
        }
      ),
      secondaryButtons: a!buttonWidget(
        label: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "btn_Cancel"),
        submit: true(), validate: false(), style: "GHOST",
        saveInto: a!save(ri!userAction, cons!AS_CO_ENUM_USER_ACTION_CANCEL)
      )
    ),
    skipAutoFocus: true()
  )
)
```
**Notes:** `formLayout_25r1` is required for `skipAutoFocus`. New i18n keys: `lbl_StartRoundN`, `ins_StartRoundConfirm`, `txt_StartRoundIrreversible`, `btn_StartRound`.

### 7.2 `AS GSS Start Round` (wrapper process)
**Trigger:** `startRound` action. **Start form:** 7.1. **Lane:** initiator. **Security:** `… PM Access` group. **Archive:** delete after 1 day. **PVs:** `evaluation`, `originalEvaluation`, `evaluationFactorsAndSubFactors`, `originalEvaluationFactorsAndSubFactors`, `vendors`, `userAction`.

| # | Node | Type | Purpose |
| :-- | :--- | :--- | :--- |
| 1 | Start | Start | form = 7.1 |
| 2 | Run Start Evaluation Generation | Subprocess (`0002ecdd…`, synchronous, chained) | runs the shared generation (ratings/tasks/consensus, on-the-spot XOR) writing the evaluation **without** a `round` relationship → no new round. Forwards all six PVs. |
| 3 | End | End | |

**Notes:** reuse of the generation process (no duplicated node graph); the round already carries its factors/vendors, so no factor/vendor step.

### 7.3 `AS GSS Complete Round` (wrapper process)
**Trigger:** `completeRound` action (no dialog — runs on click). **Lane:** initiator/System. **Security:** `… PM Access` group. **Archive:** delete after 1 day. **PVs:** `evaluation`.

| # | Node | Type | Purpose |
| :-- | :--- | :--- | :--- |
| 1 | Start | Start | no form |
| 2 | Complete Factors | Write Records | mark every factor of the round `completedOn = now()`, `completedBy = initiator` (via `AS_GSS_UT_updateEvaluationRecordWithAllFactors` → merge). |
| 3 | Run Mark Evaluation As Complete | Subprocess (`0004e60d-dbd6…`) | evaluation → Complete (`evaluationStatusId` = COMPLETE, `evaluationCompletionDate = today()`, modified audit); reuses the standard mark-complete write + GCW sync + audit. |
| 4 | End | End | |

### 7.4 `AS_GSS_UT_returnRoundStatusDisplayConfig` (new helper)
**Purpose:** map a status id to its round-card display config, so the panel doesn't repeat the same `a!match` four times.
**Inputs:** `statusId` (Integer, Required).
**Implementation:**
```
a!match(
  value: ri!statusId,
  equals: cons!AS_GSS_REF_ID_EVALUATION_STATUS_SETTING_UP,
  then: a!map(labelKey: "tag_SetUp",     barColor: cons!AS_GSS_HEX_YELLOW_4, cardStyle: cons!AS_GSS_HEX_YELLOW_0, tagBg: cons!AS_GSM_HEX_YELLOW_1, tagText: cons!AS_GSS_HEX_YELLOW_4),
  equals: cons!AS_GSS_REF_ID_EVALUATION_STATUS_INPROGRESS,
  then: a!map(labelKey: "tag_InProgress", barColor: cons!AS_GSM_HEX_PURPLE_5, cardStyle: cons!AS_GSM_HEX_PURPLE_0, tagBg: cons!AS_GSM_HEX_PURPLE_1, tagText: cons!AS_GSM_HEX_PURPLE_5),
  equals: cons!AS_GSS_REF_ID_EVALUATION_STATUS_COMPLETE,
  then: a!map(labelKey: "tag_Complete",  barColor: cons!AS_GSS_HEX_GREEN_4,  cardStyle: cons!AS_GSS_HEX_GREEN_0,  tagBg: cons!AS_GSS_HEX_GREEN_1,  tagText: cons!AS_GSS_HEX_GREEN_4),
  default: a!map(labelKey: "", barColor: {}, cardStyle: {}, tagBg: {}, tagText: {})
)
```
**Test cases:** assertable (no query). one per status + default.

### 7.5 `AS_GSS_SEC_rounds` (Rounds panel)
**Purpose:** show one card per round (name, status tag, date range) with the state-appropriate actions.
**Used by:** the Summary layout (right column).
**Inputs:** `evaluationId` (Integer, Required).
**Implementation:**
```
a!localVariables(
  local!i18nData: rule!AS_GSS_CO_UT_loadBundleFromFolder(langISOCode: null),
  local!rounds: rule!AS_GSS_QR_getRoundsForEvaluation(evaluationId: ri!evaluationId),
  /* latest sequence — Start Round shows only on this round when it is in Set Up */
  local!maxSequence: max(a!defaultValue(tointeger(local!rounds['recordType!{931e8145}...{d20a1017}sequence']), { 0 })),
  a!sectionLayout(
    showWhen: a!isNotNullOrEmpty(local!rounds),
    contents: {
      a!headingField(text: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_Rounds"), size: "SMALL", fontWeight: "SEMI_BOLD"),
      a!forEach(
        items: local!rounds,
        expression: a!localVariables(
          local!statusId: fv!item['recordType!{931e8145}...relationships.{029ebc2e}evaluation.fields.{4e467ee1}evaluationStatusId'],
          local!sequence: a!defaultValue(tointeger(fv!item['recordType!{931e8145}...{d20a1017}sequence']), 0),
          local!cfg: rule!AS_GSS_UT_returnRoundStatusDisplayConfig(statusId: local!statusId),
          a!cardLayout(
            shape: "ROUNDED", marginBelow: "STANDARD", showBorder: false(),
            decorativeBarPosition: "START", decorativeBarColor: local!cfg.barColor, style: local!cfg.cardStyle,
            contents: a!sideBySideLayout(
              alignVertical: "TOP",
              items: {
                a!sideBySideItem(item: {
                  a!sideBySideLayout(alignVertical: "MIDDLE", items: {
                    a!sideBySideItem(width: "MINIMIZE", item: a!headingField(
                      text: fv!item['recordType!{931e8145}...{31c08880}roundName'], size: "EXTRA_SMALL", fontWeight: "BOLD", marginBelow: "NONE"
                    )),
                    a!sideBySideItem(item: a!tagField(
                      labelPosition: "COLLAPSED",
                      tags: a!tagItem(
                        text: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: local!cfg.labelKey),
                        backgroundColor: local!cfg.tagBg, textColor: local!cfg.tagText
                      )
                    ))
                  }),
                  a!richTextDisplayField(labelPosition: "COLLAPSED", value: {
                    a!richTextItem(text: rule!AS_GAM_CO_I18N_UT_displayLabel(bundle: local!i18nData, bundleKey: "lbl_RoundN", arguments: local!sequence)),
                    char(10),
                    a!richTextItem(text: text(fv!item['recordType!{931e8145}...{7abbf0d2}startDate'], "MMM d, yyyy") & " - " & text(fv!item['recordType!{931e8145}...{c3f17341}endDate'], "MMM d, yyyy"), color: "SECONDARY")
                  })
                }),
                a!sideBySideItem(width: "MINIMIZE", item: a!recordActionField(
                  align: "END", style: "MENU_ICON",
                  actions: a!flatten({
                    /* Start Round — only on the latest round when it is in Set Up */
                    if(and(local!sequence = local!maxSequence, a!defaultValue(local!statusId, -1) = cons!AS_GSS_REF_ID_EVALUATION_STATUS_SETTING_UP),
                       a!recordActionItem(action: 'recordType!{4db4a62e}...actions.{84ac0b39-...}startRound', identifier: fv!item['recordType!{931e8145}...{1756683f}evaluationId']), {}),
                    /* Complete Round — only on the In Progress round */
                    if(a!defaultValue(local!statusId, -1) = cons!AS_GSS_REF_ID_EVALUATION_STATUS_INPROGRESS,
                       a!recordActionItem(action: 'recordType!{4db4a62e}...actions.{853cb2b7-...}completeRound', identifier: fv!item['recordType!{931e8145}...{1756683f}evaluationId']), {}),
                    /* Edit — always */
                    a!recordActionItem(action: 'recordType!{4db4a62e}...actions.{dbb4697d-...}edit', identifier: fv!item['recordType!{931e8145}...{1756683f}evaluationId'])
                  })
                ))
              }
            )
          )
        )
      )
    }
  )
)
```
**Notes:** the richer mockup card (per-round "N vendors advanced", completed date, chevron into completed rounds, "Setup New Round" link) is part of the deferred UI redesign (`08_…`) and layers on top of this structure.
**Test cases (interface):** default = a multi-round family → one card per round, correct status tag; Start Round appears only on the latest Set-Up round, Complete Round only on the In-Progress round.

### 7.6 Record actions
Both related actions on `AS_GSS_Evaluation_RECORD`; both surfaced from the Rounds panel keyed to each round's `evaluationId`.

| Action | Key | Process | Visibility | Context |
| :--- | :--- | :--- | :--- | :--- |
| **Start Round** | `startRound` | 7.2 | method = Best Value **and** `parentEvalId` not blank (a child round). (Panel further restricts to latest + Set Up.) | `evaluation`, `originalEvaluation`, `evaluationFactorsAndSubFactors` (active criteria), `originalEvaluationFactorsAndSubFactors`, `vendors`, `userAction: null`. |
| **Complete Round** | `completeRound` | 7.3 | `not(rule!AS_GSS_UT_hasOpenCompleteEvaluationTask(evaluationId: rv!identifier))` — no open Complete-Evaluation task. (Panel restricts to In Progress.) | `evaluation` (single object). |

## 8. Summary recomposition + Vendors

The Summary drives the whole lifecycle from the parent workspace: the left column shows the **active round's** vendors + factors + tasks; the right column shows the **Rounds panel** plus settings/description/personnel. The Vendors tab gains a **Last Participated Round** column.

### 8.1 `AS_GSS_CPS_evaluationInformationForLeftPanelOfSummary`
**Purpose:** left column of Summary — vendors, factor details, and evaluation-approach tasks for the current/active round.
**Inputs:** `evaluationRecord` (the parent), `i18nData`, factor/selection inputs, `loggedInUser`, `isStateOrLocal`, refresh triggers.
**Round-aware behaviour (the only change from single-round):** the **Vendors** block branches:
1. awardees selected / complete with decisions → winning-vendors grid;
2. **else a child round is active** (`AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation(evaluationId)` is non-null) → render `AS_GSS_SEC_DisplayActiveRoundVendorsInSummary` (8.3) for that round;
3. else → the parent evaluation's vendor cards.
Factor details and evaluation-approach tasks are rendered by their existing component rules unchanged.
**Notes:** keep this interface a thin composition of the vendor/factor/task component rules; the round branch is a single `if` on the active-round helper.

### 8.2 `AS_GSS_CPS_evaluationInformationForRightPanelOfSummary`
**Purpose:** right column of Summary.
**Inputs:** `evaluationRecord`, `i18nData`, `loggedInUser`, factor records, `triggerRefresh`.
**Composition (top to bottom):** **Rounds panel** `AS_GSS_SEC_rounds(evaluationId)` (7.5) → Settings → Description (with show-more + edit action) → Factor weights (when weighted + status in progress/awardees/complete) → Related Procurements → Related Opportunity → Personnel (Contracting Officer/Specialist/Chief, mask-evaluators) → Phases.
**Round-aware change:** only the addition of the Rounds panel at the top; the remaining sections read the parent evaluation as before.

### 8.3 `AS_GSS_SEC_DisplayActiveRoundVendorsInSummary`
**Purpose:** render the **active round's** vendor cards inside the parent Summary.
**Inputs:** `evaluationId` (parent), `i18nData`, `isStateOrLocal`.
**Implementation (shape):**
```
a!localVariables(
  local!triggerRefresh: now(),
  /* the round currently being worked */
  local!activeRoundEvalId: rule!AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation(evaluationId: ri!evaluationId),
  local!activeRoundEval: rule!AS_GSS_UT_updateEvaluationRecordWithAllVendors(evaluation: local!activeRoundEvalId, triggerRefresh: local!triggerRefresh, executeWhen: true()),
  local!vendorPagingInfo: <same sort as the summary vendor cards>,
  rule!AS_GSS_CPS_vendorsInfoForEvaluationSummary(
    i18nData: ri!i18nData,
    pagingInfo: local!vendorPagingInfo,
    vendorInfo: rule!AS_GSS_formatVendorInfoForCards(evaluationRecord: local!activeRoundEval, pagingInfo: local!vendorPagingInfo),
    evaluation: local!activeRoundEval,
    isSetUpPending: <status in {TEMP, SETTING_UP}>,
    factorCount: local!activeRoundEval['recordType!{e6bc8561}...{59f64a3b}factorCount'],
    isStateOrLocal: ri!isStateOrLocal
  )
)
```
**Notes:** reuses the shared vendor-cards component (`AS_GSS_CPS_vendorsInfoForEvaluationSummary`) — this interface only resolves the active round and hands it that component. Confirm the "active round" definition with the PO (latest not-complete round); align the helper accordingly if it should include In-Progress.

### 8.4 `AS_GSS_UT_returnLastParticipatedRoundForVendors`
**Purpose:** per vendor (keyed by **`uniqueEntityId`**), the highest-sequence round they took part in across the family — for the Vendors tab column.
**Inputs:** `evaluationId` (Integer, any family member).
**Implementation** (reuses the family resolver, so no manual anchor/children queries):
```
a!localVariables(
  /* family rounds: evaluationId + sequence + roundName, sequence-ordered */
  local!rounds: rule!AS_GSS_QR_getRoundsForEvaluation(evaluationId: ri!evaluationId),
  local!familyEvalIds: local!rounds['recordType!{931e8145}...{1756683f}evaluationId'],
  /* active vendor rows across the family; uniqueEntityId is the stable cross-round identity */
  local!vendorRows: rule!AS_CO_UT_queryRecord(
    recordType: 'recordType!{b6081510}AS_GSS_EvaluationVendor_SYNCEDRECORD',
    returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_OBJECT_ARRAY,
    executeWhen: a!isNotNullOrEmpty(local!familyEvalIds),
    fields: { '…{1b15a370}uniqueEntityId', '…{f99475b5}evaluationId' },
    filters: {
      a!queryFilter(field: '…{f99475b5}evaluationId', operator: "in", value: local!familyEvalIds),
      a!queryFilter(field: '…{47c7340f}isActive', operator: "=", value: true())
    }
  ),
  a!forEach(
    items: rule!AS_CO_UT_distinct(rule!AS_CO_UT_rejectNullValuesFromArray(local!vendorRows['…{1b15a370}uniqueEntityId'])),
    expression: a!localVariables(
      /* rounds this vendor appears in → their sequences */
      local!vendorEvalIds: index(local!vendorRows['…{f99475b5}evaluationId'],
        wherecontains(fv!item, local!vendorRows['…{1b15a370}uniqueEntityId']), {}),
      local!seqs: index(local!rounds['recordType!{931e8145}...{d20a1017}sequence'],
        wherecontains(tointeger(local!vendorEvalIds), tointeger(local!rounds['recordType!{931e8145}...{1756683f}evaluationId'])), {}),
      local!maxSeq: if(a!isNullOrEmpty(local!seqs), null, tointeger(max(local!seqs))),
      a!map(
        uniqueEntityId: fv!item,
        sequence: local!maxSeq,
        roundName: index(local!rounds['recordType!{931e8145}...{31c08880}roundName'],
          wherecontains(local!maxSeq, tointeger(local!rounds['recordType!{931e8145}...{d20a1017}sequence'])), null)
      )
    )
  )
)
```
**Notes:** returns `{uniqueEntityId, sequence, roundName}`; the Vendors grid composes the display label (i18n "Round N | name") — data assembly and label formatting are kept separate.
**Test cases:** "Case with No Assertions". (1) null; (2) family where a vendor is dropped after round 1 → that vendor's `sequence` = 1.

### 8.5 `AS_GSS_UT_returnEvaluationTaskProgressForGivenCriteria`
**Purpose:** per-vendor task completion (total + completed) for one factor of one evaluation — drives the Summary factor progress %.
**Inputs:** `evaluationId`, `factorId` (both Integer).
**Implementation:** a single aggregation query on Tasks grouped by `vendorId` + `taskStatusId` (filters: `taskRefId = COMPLETE_EVALUATION`, active statuses, this `evaluationId` + `criteriaId`), then per distinct `vendorId` a `{vendorId, totalTasks, completedTasks}` map (completed = the COMPLETE-status count). Return `a!map(vendorId: 0, totalTasks: 0, completedTasks: 0)` when inputs are blank. Use `AS_CO_UT_distinct(local!groupedData.vendorId)` for the vendor loop (not `union(x, x)`).
**Test cases:** "Case with No Assertions". (1) null inputs → zero map; (2) a factor with some complete + some open tasks → correct totals.

### 8.6 Vendors tab — `AS_GSS_FM_evaluationVendorsTab` + `AS_GSS_GRD_EvaluationVendors`
**Purpose:** the Vendors tab and its grid, on the parent evaluation.
**Round-aware change:** add a **Last Participated Round** column. The tab loads `rule!AS_GSS_UT_returnLastParticipatedRoundForVendors(evaluationId)` once and passes it to the grid; the grid, per vendor row, looks up the entry by **`uniqueEntityId`** and renders "Round {sequence} | {roundName}" (i18n). No other columns change.
**Notes:** correlate strictly by `uniqueEntityId` (not `vendorId`, which differs per round). Column is empty for vendors with no round participation.

## 9. Integration touchpoints (VM & GCW)

Under the parent-only model, external systems key off the **parent** evaluation (`evaluationNumber` = solicitation PIID). Two touchpoints need round-awareness.

### 9.1 `AS_GSS_mapVendorUpdatesToRecord` (VM → GSS vendor proposal updates)
**Purpose:** map an inbound VM vendor-proposal update (Web API body) onto the correct GSS vendor + write a `VendorUpdates` record.
**Trigger:** the VM vendor-update Web API.
**Inputs:** `requestBody` (Map — includes `noticeId` = solicitation PIID, `vendorId`, identifiers, proposal fields).
**Round-aware behaviour:** `noticeId` resolves the **parent** (its `evaluationNumber`); the update must be applied to the vendor in the **latest round's** child evaluation, falling back to the parent when there are no rounds (legacy/single-round).
**Clean latest-round resolution** (replaces the max-sequence/`wherecontains` block — `getRoundsForEvaluation` already returns rounds sequence-ascending, so the latest is the last element):
```
a!localVariables(
  /* parent resolved from the solicitation PIID */
  local!parentEvaluationId: index(local!matchingEvaluation, 'recordType!{e6bc8561}...{7f7c2d3b}evaluationId', null),
  local!familyRounds: if(
    a!isNullOrEmpty(local!parentEvaluationId),
    {},
    rule!AS_GSS_QR_getRoundsForEvaluation(evaluationId: local!parentEvaluationId)
  ),
  /* latest round = last element (sequence-ascending); fall back to the parent */
  local!latestRoundEvaluationId: a!defaultValue(
    index(local!familyRounds, count(local!familyRounds), {})['recordType!{931e8145}...{1756683f}evaluationId'],
    local!parentEvaluationId
  ),
  /* … resolve the matching vendor on local!latestRoundEvaluationId (GSS-source by federal/state
        identifier, or VM-source by externalVendorId), deactivate prior updates for this
        externalVendorId + noticeId, and build the current VendorUpdates record with
        evaluationId = local!latestRoundEvaluationId … */
  ...
)
```
**Rest of the rule (unchanged in shape):** the vendor match (GSS-source by federal/state identifier OR VM-source by `externalVendorId`), the de-activation of prior updates, and the `VendorUpdates` record construction all run against `local!latestRoundEvaluationId`. Return `{ matchingEvaluation, matchingEvaluationVendor, allVendorProposalUpdates }`.
**Notes:** confirm with the PO whether "latest round" should be the max-sequence round regardless of status, or the latest **non-complete** round; align the selection accordingly (filter `familyRounds` by status before taking the last).
**Test cases:** "Case with No Assertions". (1) blank `noticeId`; (2) a PIID whose family has 2+ rounds → the update's `evaluationId` = the latest round's; (3) a single-round PIID → `evaluationId` = the parent's.

### 9.2 GCW status sync — suppress for child rounds
**What:** the GCW status-sync process (`0006ef1c…`, "Sync Eval Status in GCW") runs from Start Evaluation (§4.2), Start Round (via the reused generation), and Complete Round (via Mark-Complete). It must sync **only the parent** — a child round moving to Complete/In Progress mid-competition must not tell GCW the whole evaluation changed state.
**How (single guard, all callers covered):** at the **entry of the GCW sync process**, short-circuit when the evaluation is a child. First node = an XOR on `a!isNotBlank(parentEvalId)`:
- child (`parentEvalId` populated) → go straight to End (no sync);
- root (`parentEvalId` blank) → proceed with the existing sync.

Resolve `parentEvalId` from the passed `evaluationId` (`AS_GSS_QR_getEvaluationByIdentifier`) if the process only receives the id.
**Why guard inside the sync process (not each call site):** one change covers every current and future caller; call sites stay unchanged.
**Notes:** this is the deferred GCW hygiene item — schedule with the GCW integration work; no other GCW flow changes are needed under the parent-only model.

### 9.3 General rule for any other integration
Any outbound reference to evaluation identity (GSM/DRM, SAM.gov, SharePoint, etc.) must resolve to the **anchor/parent** (`coalesce(parentEvalId, evaluationId)`) before reading or writing, so external systems always see the single, stable parent evaluation.

## Batch tracker (build order)
1. **Data model** — §2 ✅
2. **Family & round helpers** — §3 ✅
3. **Start Evaluation as Round 1** — §4 ✅
4. **Round-aware tabs** — §5 ✅
5. **Setup New Round + clone** — §6 ✅
6. **Start / Complete round + Rounds panel** — §7 ✅
7. **Summary recomposition + Vendors** — §8 ✅
8. **Integration touchpoints (VM & GCW)** — §9 ✅

**All batches complete.** This document specifies the full feature build. Open PO confirmations flagged inline: Setup-New-Round step count (2 vs 3), Phases tab in/out, "active round" definition for Summary/VM latest-round selection, and record-type suffix convention (`_SYNCEDRECORD` vs `_RecordType`).
4. **Round-aware tabs** — embeddable content + wrapper(s)
5. **Setup New Round + clone** — wizard, duplicate, team-mapping, factor-doc-mapping
6. **Start / Complete round + Rounds panel**
7. **Summary recomposition + Vendors**
8. **Integration touchpoints** (VM, GCW)
