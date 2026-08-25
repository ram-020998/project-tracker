# Implementation Plan — Round-Aware Tabs (Evaluation Record)

> **Goal:** Extend the round-sub-tab pattern already built for the **Factors** tab to the other Evaluation record tabs — **Ratings, Consensus Reports, Teams, Documents, Tasks, Task History, and Evaluation History** — correctly handling the differing input shapes (some tab interfaces take an `evaluationId`, some take one or more queried Evaluation record collections).
>
> **Record:** `AS_GSS_Evaluation_RECORD` (`4db4a62e-d099-4e54-be19-41498c17b9cc`)
> **Companion docs:** `01_FEATURE_AND_TECHNICAL_DESIGN.md`, `02_PROGRESS_TRACKER.md`, `03_AGENT_ONBOARDING.md`
> **Status:** DRAFT plan — confirm the open design decisions in §4 before building.

---

## 1. The established pattern (Factors) — reference implementation

The Factors tab was made round-aware using **three layers**:

**Layer A — Record view `uiExpr`** (on `AS_GSS_Evaluation_RECORD`, Factors view `_n_87YA`):
```
rule!AS_GSS_CPS_viewFactors_Parent(
  evaluationId: rv!record[...AS_GSS_Evaluation_RECORD.fields.{evaluationId}evaluationId]
)
```

**Layer B — `_Parent` wrapper interface** (`AS_GSS_CPS_viewFactors_Parent`, input `evaluationId`):
```
a!localVariables(
  local!data: rule!AS_GSS_UT_returnViewRenderingConfigFor_Factors(evaluationId: ri!evaluationId),
  a!headerContentLayout(
    contents: a!tabLayout(
      tabs: a!forEach(
        items: local!data,
        expression: a!tabItem(label: fv!item.tabName, contents: fv!item.ui)
      )
    )
  )
)
```

**Layer C — Config rule** (`AS_GSS_UT_returnViewRenderingConfigFor_Factors`, input `evaluationId`):
```
a!localVariables(
  local!rounds: AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation(
    evaluationId: ri!evaluationId,
    additionalFields: { round.evaluation.evaluationStatusId }
  ),
  a!forEach(
    items: local!rounds,
    expression: a!map(
      tabName: "Round " & fv!item[...sequence],
      ui: rule!AS_GSS_CPS_viewFactors(
        evaluationId: fv!item[...evaluationId],   /* each round's CLONE eval id */
        loggedInUser: loggedInUser()
      )
    )
  )
)
```

Each round is a **cloned Evaluation** (see design doc §6.1). The config rule lists rounds, and for each one renders the **existing** per-tab interface pointed at that round's clone `evaluationId`. The original tab interfaces need **no changes** — only a wrapper + config rule per tab.

---

## 2. The key nuance — input shape per tab interface

Tab interfaces do **not** share one input contract. Confirmed signatures for **every tab that will get round sub-tabs**:

| Tab | Interface | Input contract | Shape | Internally re-queries? |
| :--- | :--- | :--- | :--- | :--- |
| Factors ✅ | `AS_GSS_CPS_viewFactors` | `evaluationId` (Integer), `loggedInUser` (User) | **ID** | Yes (queries criteria by id) |
| Ratings | `AS_GSS_CPS_evaluationRatingsTab` | `evaluation` (Evaluation RECORD) | **RECORD** | No — reads fields off the passed record (evaluationId, isEvaluatorMasked, …) |
| Consensus Reports | `AS_GSS_CPS_consensusReportView` | `evaluationId` (Integer), `loggedInUser` (User) | **ID** | Yes (`AS_GSS_QR_getEvaluation` by id) |
| Teams | `AS_GSS_CPS_viewEvaluatorTeam` | `evaluationId` (Integer) | **ID** | Yes (queries teams/criteria by id) |
| Documents | `AS_GSS_FM_evaluationDocumentsTab` | `evaluationId` (Integer) | **ID** | Yes. ⚠️ Has its **own internal sub-tabs** (Documents/Drafts when AIDB+CO) → round tabs would **nest** |
| Tasks / Checklist Items | `AS_GSS_TMG_CPS_viewRecordTasks` | `evaluation` (Evaluation RECORD, single) | **RECORD** | No — reads `ri!evaluation.evaluationId`, `.isEvaluatorMasked` |
| Task History | `AS_GSS_TMG_FM_taskAuditActionHistory` | `evaluationId` (Integer) | **ID** | Yes (`getEvaluationByIdentifier` by id) |
| Evaluation History | `AS_GSS_FM_evaluationAuditHistory` | `evaluation` (record) + `evaluationPhases[]` + `evaluationVendors[]` + `evaluationCriterias[]` + `evaluatorTeams[]` + `evaluationDocs[]` | **RECORD (heavy)** | No — all 6 collections must be queried and passed in |
| Vendors *(columns only, not sub-tabs)* | `AS_GSS_FM_evaluationVendorsTab` | `evaluationId` (Integer) | ID | Yes |

**Consequence — two wrapper flavors:**

- **ID-based tabs** (Factors, Consensus, Teams, Documents, Task History): config rule passes each round's `evaluationId` directly. Cheap.
- **RECORD-based tabs** (Ratings, Tasks, Evaluation History): the interface needs one or more **queried record collections** per round. Two ways to supply them:
  1. **Inline in the config rule** — query per round (or batched) and pass records in. Simple but couples the config rule to each tab's query set.
  2. **Thin per-round "loader" interface** (recommended) — a small wrapper that takes `evaluationId`, runs the **same queries the current record view uses**, and calls the underlying tab interface. The generic config rule then **always passes just `evaluationId`**, uniform across all tabs. Encapsulates each tab's query set and keeps the config rule clean.

  Example loader for Evaluation History (mirrors today's view `uiExpr`):
  ```
  /* AS_GSS_CPS_evaluationAuditHistory_ByEvaluationId(evaluationId) */
  rule!AS_GSS_FM_evaluationAuditHistory(
    evaluation:        rule!AS_GSS_QE_getEvaluation(evaluationId: ri!evaluationId, returnType: SINGLE_OBJECT),
    evaluationPhases:  rule!AS_GSS_QE_getEvaluationPhases(evaluationId: ri!evaluationId, returnType: OBJECT_ARRAY, getActiveAndInactive: true),
    evaluationVendors: rule!AS_GSS_QE_getEvaluationVendor(evaluationId: ri!evaluationId, returnType: OBJECT_ARRAY, getActiveAndInactive: true),
    evaluationCriterias: rule!AS_GSS_QE_getEvaluationCriteria(evaluationId: ri!evaluationId, returnType: OBJECT_ARRAY, getActiveAndInactive: true),
    evaluatorTeams:    rule!AS_GSS_QE_getEvaluatorTeam(evaluationId: ri!evaluationId, returnType: OBJECT_ARRAY, getActiveAndInactive: true),
    evaluationDocs:    rule!AS_GSS_QE_getEvaluationDocuments(evaluationId: ri!evaluationId, returnType: OBJECT_ARRAY, fetchAll: true())
  )
  ```

**⚠️ Performance / laziness:** `a!forEach` over rounds builds **all** round tab contents when the config rule evaluates (Appian tab contents are not lazy by default). With up to 5 rounds, Evaluation History (6 queries/round) = up to 30 queries; Tasks/Ratings add more. Mitigate by driving the tab body with a **selected-round local + `showWhen`** so only the active round's queries run, OR batch queries with `… in {roundIds}` and index per round. Decide per tab (heavy tabs = Evaluation History, Tasks, Ratings).

---

## 3. Per-tab treatment (what each tab should become)

Derived from spec §4 + Decisions/Open-Questions in `GSS_ Multi Round Evaluations.md`, **updated per stakeholder request (2026-08-25) to also round-sub-tab Documents, Tasks, Task History, and Evaluation History**:

| Tab | Treatment | Shape | Build? |
| :--- | :--- | :--- | :--- |
| **Summary** | Show **current round only** (current-round factors). No sub-tabs. | — | Light change |
| **Factors** | ✅ Round sub-tabs (done). Also add **"Rounds" column** to the flat factor grid. | ID | Enhance |
| **Ratings** | **Round sub-tabs** | RECORD | **Build** |
| **Consensus Reports** | **Round sub-tabs** | ID | **Build** |
| **Teams** | **Round sub-tabs** | ID | **Build** |
| **Documents** | **Round sub-tabs** (outer round tabs wrap existing inner Documents/Drafts tabs) | ID | **Build** |
| **Tasks / Checklist Items** | **Round sub-tabs** | RECORD | **Build** |
| **Task History** | **Round sub-tabs** | ID | **Build** |
| **Evaluation History** | **Round sub-tabs** (heavy — 6 queried collections per round) | RECORD | **Build** |
| **Vendors** | **No sub-tabs** + new columns: **Last participated round**, **Decision (Selected/Rejected)** | ID | Enhance (different work) |
| **Vendor Analysis** | Stretch; unchanged for now | — | No change |

> **Note / spec divergence:** the earlier spec designated Documents / Tasks / Task History / Evaluation History as "common/unified" (no round split). Per the 2026-08-25 request these now get **per-round sub-tabs** like the others. Evaluation History being combined-audit is superseded by this request (each round tab shows that round's audit).

**Tabs getting the round-sub-tab wrapper:** Factors ✅, Ratings, Consensus, Teams, Documents, Tasks, Task History, Evaluation History (8 total).
**ID-based (5):** Factors, Consensus, Teams, Documents, Task History.
**RECORD-based (3):** Ratings, Tasks, Evaluation History.

---

## 4. Critical design decisions to CONFIRM before building

These affect every wrapper and must be settled first.

### 4.1 What is the "record anchor" — root eval or active round?
The Factors config rule calls `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation(evaluationId)`, which queries Evaluations where **`parentEvalId = evaluationId`**. That returns **child** rounds only.

- If a user opens the **root** evaluation (id = 100), it returns rounds 2,3,… (evals with parentEvalId=100) but **NOT round 1 itself** (root's own parentEvalId is null).
- If a user opens a **child** round record (id = 101), `parentEvalId = 101` matches nothing → **empty tab list**.

**Implication:** every `_Parent` must first **resolve the root/parent evaluation id** from the viewed record, then list rounds. Options:
- (a) Root's `parentEvalId` is set to **its own id** at Start Evaluation, and the rounds query uses `parentEvalId = rootId` (root included). — cleanest, but depends on the Start Evaluation path (not yet reviewed).
- (b) Rounds query uses `parentEvalId = anchor OR evaluationId = anchor` and resolve `anchor = coalesce(record.parentEvalId, record.evaluationId)`.

**➜ ACTION:** Verify the Start Evaluation path (tracker §4) — does round 1 get an `EvaluationRound` row, and what is root's `parentEvalId`? Then confirm whether **round 1 currently shows** as a tab on Factors. If not, this is a shared bug to fix in `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (fixes Factors too).

### 4.2 Round ordering
`AS_GSS_SEC_rounds` and the config rules don't pass an explicit sort. Tabs should be ordered by **`sequence` ascending**. Add `sort` to the rounds query used by the config rules.

### 4.3 Single generic config rule vs one per tab
The three config rules would be near-identical to `…For_Factors` except for the interface they call and its input shape. **Recommendation:** create **one generic** config rule and refactor Factors to use it (see §6).

---

## 5. Recommended approach — a generic, shape-aware config rule

Create **`AS_GSS_UT_returnRoundTabRenderingConfig`**:

**Inputs:**
- `evaluationId` (Integer) — the viewed record's id (anchor).
- `tabKey` (Text) — enum: `"FACTORS" | "RATINGS" | "CONSENSUS" | "TEAMS" | "DOCUMENTS" | "TASKS" | "TASK_HISTORY" | "EVAL_HISTORY"`.

**Logic:**
1. Resolve `anchorId = coalesce(record.parentEvalId, evaluationId)` (per §4.1 decision).
2. Query rounds under the anchor, **sorted by sequence asc**, including root (per §4.1).
3. `a!forEach` round → `a!map(tabName: "Round " & sequence, ui: <dispatch by tabKey>)`:
   - **ID-based** (pass round `evaluationId` directly):
     - `FACTORS` → `AS_GSS_CPS_viewFactors(evaluationId: roundEvalId, loggedInUser())`
     - `CONSENSUS` → `AS_GSS_CPS_consensusReportView(evaluationId: roundEvalId, loggedInUser())`
     - `TEAMS` → `AS_GSS_CPS_viewEvaluatorTeam(evaluationId: roundEvalId)`
     - `DOCUMENTS` → `AS_GSS_FM_evaluationDocumentsTab(evaluationId: roundEvalId)`
     - `TASK_HISTORY` → `AS_GSS_TMG_FM_taskAuditActionHistory(evaluationId: roundEvalId)`
   - **RECORD-based** (call the per-round **loader** that queries + delegates — see §2):
     - `RATINGS` → `AS_GSS_CPS_ratingsTab_ByEvaluationId(evaluationId: roundEvalId)`
     - `TASKS` → `AS_GSS_TMG_CPS_viewRecordTasks_ByEvaluationId(evaluationId: roundEvalId)`
     - `EVAL_HISTORY` → `AS_GSS_CPS_evaluationAuditHistory_ByEvaluationId(evaluationId: roundEvalId)`

Using loaders keeps the config rule uniform (always `evaluationId` in) and encapsulates each record-based tab's query set. For the heavy tabs, add a **selected-round `showWhen`** in the parent so only the active round's queries evaluate (see performance note in §2).

Then create **one generic `_Parent`** interface `AS_GSS_CPS_roundTabs_Parent(evaluationId, tabKey)` rendering the `a!tabLayout` (identical structure to `viewFactors_Parent`), and point each record view's `uiExpr` at it with the right `tabKey`.

> **Fallback (per-tab clones):** if the team prefers minimal churn over consolidation, clone Factors' pattern per tab: `AS_GSS_UT_returnViewRenderingConfigFor_<Tab>` + `AS_GSS_CPS_<tab>_Parent`. The generic route is preferred given 8 tabs now share the pattern. Decide in §4.3.

---

## 6. Detailed work items

### WI-1 — Confirm anchor & round-1 inclusion (blocker)
- Review Start Evaluation path; confirm root `parentEvalId` and round-1 `EvaluationRound` creation.
- Fix `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` to include the anchor/root and sort by `sequence` if needed.
- Re-verify Factors shows Round 1.

### WI-2 — Generic config rule `AS_GSS_UT_returnRoundTabRenderingConfig`
- Inputs `evaluationId`, `tabKey`; batched record query for RATINGS; dispatch per §5.
- Unit-test via `testRule` for a multi-round eval (expect N maps with correct `ui`).

### WI-3 — Generic parent `AS_GSS_CPS_roundTabs_Parent(evaluationId, tabKey)`
- Mirror `AS_GSS_CPS_viewFactors_Parent` `a!tabLayout`.

### WI-4 — Ratings tab → round sub-tabs
- Change Ratings view `uiExpr` (`_30fhDw`) to `rule!AS_GSS_CPS_roundTabs_Parent(evaluationId: rv!record…evaluationId, tabKey: "RATINGS")`.
- Preserve the existing `visibilityExpr` (`AS_GSS_getVisibilityForRatingsTab`).
- **Record-based**: ensure the batched query returns every field `AS_GSS_CPS_evaluationRatingsTab` reads (evaluationId, isEvaluatorMasked, evaluationStatusId, method, …).

### WI-5 — Consensus Reports tab → round sub-tabs
- Change Consensus view `uiExpr` (`_KJy-Pg`) to `roundTabs_Parent(evaluationId, tabKey: "CONSENSUS")`.
- Preserve `visibilityExpr` (`AS_GSS_getVisibilityForConsensusReportTab`).
- Note: consensus tab shows per-round consensus; spec wants **visual round indicators** for Factor Chairs — the sub-tab label satisfies the primary need; confirm any in-form indicator.

### WI-6 — Teams tab → round sub-tabs
- Change Teams view `uiExpr` (`_j9bz9g`) to `roundTabs_Parent(evaluationId, tabKey: "TEAMS")`.
- Preserve `visibilityExpr`.

### WI-6a — Documents tab → round sub-tabs (ID-based)
- Change Documents view `uiExpr` (`_wHo-OA`) to `roundTabs_Parent(evaluationId, tabKey: "DOCUMENTS")`.
- ⚠️ `AS_GSS_FM_evaluationDocumentsTab` has its **own inner tabs** (Documents/Drafts). Result = round tabs (outer) → Documents/Drafts (inner). Verify the nested `a!tabLayout` renders acceptably; adjust styling/margins if cramped.
- Preserve visibility (`=true()`).

### WI-6b — Task History tab → round sub-tabs (ID-based)
- Change Task History view `uiExpr` (`_YpCKng`) to `roundTabs_Parent(evaluationId, tabKey: "TASK_HISTORY")`.
- Preserve `visibilityExpr` (`AS_GSS_getVisibilityForEvaluatorsInEvalRecordViews`).

### WI-6c — Tasks tab → round sub-tabs (RECORD-based)
- Create loader `AS_GSS_TMG_CPS_viewRecordTasks_ByEvaluationId(evaluationId)` → queries the evaluation record (as today's view does) and calls `AS_GSS_TMG_CPS_viewRecordTasks(evaluation: …)`.
- Change Tasks view `uiExpr` (`_WTzSLQ`) to `roundTabs_Parent(evaluationId, tabKey: "TASKS")`.
- Preserve `visibilityExpr`.

### WI-6d — Evaluation History tab → round sub-tabs (RECORD-based, heavy)
- Create loader `AS_GSS_CPS_evaluationAuditHistory_ByEvaluationId(evaluationId)` → runs the 6 queries (evaluation, phases, vendors, criterias, teams, docs) exactly as today's view and calls `AS_GSS_FM_evaluationAuditHistory(...)`.
- Change Evaluation History view `uiExpr` (`_JJzYag`) to `roundTabs_Parent(evaluationId, tabKey: "EVAL_HISTORY")`.
- **Apply the selected-round `showWhen`/lazy pattern** here first — 6 queries × N rounds is the heaviest.
- Preserve `visibilityExpr`.

### WI-6e — Ratings loader (RECORD-based)
- Create loader `AS_GSS_CPS_ratingsTab_ByEvaluationId(evaluationId)` → `AS_GSS_QR_getEvaluationByIdentifier(evaluationId, fields: {the fields ratings reads})` → `AS_GSS_CPS_evaluationRatingsTab(evaluation: …)`. (Used by WI-4.)

### WI-7 — Factors refactor (optional consolidation)
- Repoint `AS_GSS_CPS_viewFactors_Parent` to the generic config rule with `tabKey: "FACTORS"` (or repoint the view directly at `roundTabs_Parent`).
- Deprecate `AS_GSS_UT_returnViewRenderingConfigFor_Factors` once migrated. Keep if team prefers per-tab.
- Add the **"Rounds" column** to the flat factors grid (`AS_GSS_GRD_ViewFactorsAndSubfactors`) per mockup pg 14 (separate sub-task).

### WI-8 — Vendors tab enhancements (NOT sub-tabs)
- Add **Last participated round** (e.g. "Round 3 | Negotiations") and **Decision (Selected/Rejected)** columns to `AS_GSS_FM_evaluationVendorsTab`. Derive from round membership across clones. Separate design.

### WI-9 — Summary current-round scoping
- Ensure Summary shows only the **current round's** factors (active child), not all. Confirm which eval the Summary view resolves.

---

## 7. Tabs requiring NO round-tab change
- **Summary** (`summary`) — scope to current round instead (WI-9).
- **Vendors** (`_aHLxfA`) — columns only (WI-8), not sub-tabs.
- **Vendor Analysis** (`_bo-GTw`) — stretch; unchanged for now.

*(Documents, Tasks, Task History, and Evaluation History previously listed here have moved to the round-sub-tab set per the 2026-08-25 request — see §3 and WI-6a–6d.)*

---

## 8. Object inventory for this plan

**Reused tab interfaces (no change to their internals):**
| Interface | UUID | Input | Shape |
| :--- | :--- | :--- | :--- |
| `AS_GSS_CPS_viewFactors` | `_a-0000e5da-a251-8000-9bbe-011c48011c48_1069114` | evaluationId, loggedInUser | ID |
| `AS_GSS_CPS_evaluationRatingsTab` | `_a-0000efa1-370d-8000-9ea1-011c48011c48_19633560` | evaluation (record) | RECORD |
| `AS_GSS_CPS_consensusReportView` | `_a-0000e721-640b-8000-9ba8-011c48011c48_40123` | evaluationId, loggedInUser | ID |
| `AS_GSS_CPS_viewEvaluatorTeam` | `_a-0000e5da-a251-8000-9bbe-011c48011c48_1061788` | evaluationId | ID |
| `AS_GSS_FM_evaluationDocumentsTab` | `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_951806` | evaluationId | ID (inner tabs) |
| `AS_GSS_TMG_CPS_viewRecordTasks` | `_a-0000e2cd-bc96-8000-9ba2-011c48011c48_57203-tmg-am-am` | evaluation (record) | RECORD |
| `AS_GSS_TMG_FM_taskAuditActionHistory` | `_a-0000e2cd-bc96-8000-9ba2-011c48011c48_137309-tmg-am-am` | evaluationId | ID |
| `AS_GSS_FM_evaluationAuditHistory` | `_a-0000e5da-a251-8000-9bbe-011c48011c48_998301` | evaluation + 5 collections | RECORD (heavy) |
| `AS_GSS_FM_evaluationVendorsTab` *(columns only)* | `_a-0000e5da-a251-8000-9bbe-011c48011c48_1082379` | evaluationId | ID |

**Existing round infra (reuse):**
| Object | UUID |
| :--- | :--- |
| `AS_GSS_CPS_viewFactors_Parent` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42424` |
| `AS_GSS_UT_returnViewRenderingConfigFor_Factors` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42412` |
| `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42289` |
| `AS_GSS_UT_returnIdentifiersForEvaluationRounds` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42301` |
| `AS_GSS_EvaluationRound_SYNCEDRECORD` | `931e8145-3f77-4270-a52a-b51de6e76983` |
| `AS_GSS_Evaluation_SYNCEDRECORD` | `e6bc8561-d3a6-4679-b7af-6e279910468e` |

**Query rule for record-based wrapper:** `AS_GSS_QR_getEvaluationByIdentifier` (used today by the Ratings/Summary views) or `AS_GSS_QR_getEvaluation`.

**New objects to create:**
- `AS_GSS_UT_returnRoundTabRenderingConfig` (rule) — generic, dispatches by `tabKey`.
- `AS_GSS_CPS_roundTabs_Parent` (interface) — generic tab-layout wrapper.
- Record-based loaders (3): `AS_GSS_CPS_ratingsTab_ByEvaluationId`, `AS_GSS_TMG_CPS_viewRecordTasks_ByEvaluationId`, `AS_GSS_CPS_evaluationAuditHistory_ByEvaluationId`.
*(or per-tab config/parent equivalents if §4.3 chooses that route)*

---

## 9. Validation & testing checklist
For each round-sub-tabbed tab (Factors, Ratings, Consensus, Teams, Documents, Tasks, Task History, Evaluation History):
- [ ] `validateDesignObject` on the config rule, parent interface, any loader, and the record type after view edits.
- [ ] `testRule` on the config rule per `tabKey` for a multi-round eval → N ordered maps, correct `ui` per round.
- [ ] `testInterface` on `roundTabs_Parent` with a real multi-round `evaluationId` + `tabKey` → renders N tabs, no diagnostics error.
- [ ] Round 1 tab present and first; ordering by sequence.
- [ ] Opening a **child round** record still shows the full tab set (anchor resolution works).
- [ ] Ratings & Tasks: masked-evaluator path works per round (record carries `isEvaluatorMasked`).
- [ ] Documents: nested inner tabs (Documents/Drafts) render correctly inside a round tab.
- [ ] Evaluation History: lazy/`showWhen` gating confirmed; queries only fire for the active round.
- [ ] Visibility expressions preserved on every view (Ratings/Consensus gating, evaluator-only gating on Tasks/Task History/Eval History).
- [ ] Single-round eval still renders exactly one tab and matches pre-change behavior.
- [ ] `getObjectDependents` on any refactored/deprecated rule before removal.

---

## 10. Suggested sequencing
1. **WI-1** (anchor / round-1 inclusion) — blocker; also validates the Factors baseline.
2. **WI-2 + WI-3** (generic config rule + parent).
3. **WI-6 Teams** (simplest, id-based) → prove the generic path end-to-end.
4. **WI-5 Consensus**, **WI-6b Task History** (id-based).
5. **WI-6a Documents** (id-based, watch nested tabs).
6. **WI-4 Ratings** + **WI-6e loader** (record-based, single record).
7. **WI-6c Tasks** (record-based, single record).
8. **WI-6d Evaluation History** (record-based, heavy — do the lazy pattern here).
9. **WI-7 Factors** consolidation + Rounds column.
10. **WI-8 Vendors** columns, **WI-9 Summary** scoping (separate, can parallelize).

*(Confirm the §4 decisions with the team before starting WI-2 onward.)*
