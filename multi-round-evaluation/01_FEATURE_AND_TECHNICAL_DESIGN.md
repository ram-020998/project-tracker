# GSS: Multi-Round Evaluations — Feature & Technical Design

> **Status:** In active development (started 2026-08-25)
> **Application:** AS GSS Full Application (`_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`)
> **Environment:** `gam-gss-32-innovate.appianpreview.com`
> **Target Release:** Source Selection 3.3
> **PO:** Subash Narayana B · **UX:** Vedant Khaire · **Team:** GAM Source Selection
> **Access:** via the `lcp` MCP server (Appian design objects) — this environment has no local code repo for these objects.

---

## 1. What the feature is

Multi-Round Evaluations lets a Contracting Officer (CO) run a **single Best Value evaluation as multiple sequential rounds** (down-selects), progressively narrowing the vendor pool — instead of the current workaround of creating a brand-new evaluation for each phase.

Requested by customers **WHS, FRA, Texas DIR** (and others: UT Arlington, SFPUC, AOC).

### Terminology note (important)
The research/early spec explored **"Multi-Phase"** (phases declared up front) and **advisory vs. firm** down-selects. The **feature actually being built is "Multi-Round"**:
- Rounds are created **iteratively**, not declared in advance.
- **Only Best Value** evaluations are eligible (not LPTA).
- **Out of scope:** Multi-Phase (upfront declaration), and adding vendors/factors to a round ad hoc.

---

## 2. Business rules (confirmed decisions)

| Area | Decision |
| :--- | :--- |
| Eligibility | Best Value evaluations only |
| Max rounds | 5 |
| Round 1 vendor volume | Up to ~400 vendors |
| Down-select minimum | Must select **at least 1** vendor to advance; no maximum |
| Vendor elimination | Only **between** rounds (never mid-round) |
| Previous rounds (CO) | **Read-only**; cannot go back and edit a completed/in-progress round |
| Round deletion | Not allowed (can only delete the whole evaluation) |
| Skipping / early completion | Not allowed — must go through each initiated round; cannot complete early |
| Re-include excluded vendor | Allowed — CO can manually re-include a previously excluded vendor in a new round |
| Evaluator visibility | Evaluator sees a round's data **only if they were on that round's team** (bias prevention) |
| Factor Chair visibility | Can see consensus across rounds, with **visual round indicators** |
| On-the-spot consensus | Configurable **per round** |
| Evaluator masking | Can change **per round** |
| Consensus required | Per-round setting (ask the CO) |
| Dates | Round dates must fall within overall evaluation dates; cannot save if a round exceeds its due date |
| Audit | **Combined** audit trail; round changes captured as history entries |
| Status between rounds | e.g. "Round/Phase 2 Setup", "Round/Phase 2 In Progress" |
| Carry-forward | Prior documents and pricing carry forward but are **editable**; factor→document mappings preserved if the factor is carried forward, reset if the factor is removed |

---

## 3. User flow

1. CO creates a Best Value evaluation; sets up factors, teams, assignments; adds vendors (as today).
2. **Start Evaluation** modal: CO enters Round 1 name, start/due date + duration, and selects applicable factors. Only tasks for selected factors trigger for evaluators.
3. Evaluators submit ratings → Factor Chairs finalize consensus → CO marks factors complete.
4. When all factors complete → CO chooses **Select Awardees** or **Setup New Round**.

**Repeat per subsequent round:**
5. **Setup New Round** wizard:
   - **Step 1:** round name, start/due date, duration, on-the-spot consensus toggle, select applicable factors (with editable per-factor due dates).
   - **Step 2:** select vendors to include (down-select). Teams/assignments carry forward, editable.
   - **Step 3:** configure the VM resubmission request — *Send as Update* (announce to all) vs *Send as Email* (to selected), with editable Title + Description.
6. During setup the CO can also: modify teams/assignments, upload new vendor documents/resubmissions, edit factor due dates, and manually re-include an excluded vendor.
7. **Start Round** confirmation warns the action cannot be undone; on start, included factors & vendor assignments are **locked**.
8. Evaluate → consensus → complete factors → **Select Awardees** or **Setup New Round** again.
9. **Complete Evaluation** after final awardees are selected.

---

## 4. UI / mockup behavior

- **Rounds panel** (Summary): one card per round, status-colored (Set Up = yellow, In Progress = purple, Complete = green); "Setup New Round" link when a round is complete; Edit link on a round in Setup reopens the **pre-filled** setup modal.
- **Round sub-tabs** (Round 1/2/3/4) on: **Ratings, Consensus Reports, Teams** — historic per-round views.
- **Common / unified** (no round tabs): **Documents, Tasks, Task History, Evaluation History**.
- **Factors tab:** shows the full factor list with a **"Rounds" column** mapping each factor to the rounds it participated in. The **Summary** page shows only the current round's factors.
- **Vendors tab:** adds **"Last participated round"** (e.g. "Round 3 | Negotiations") and a **Decision** column (Selected/Rejected).

---

## 5. Integration touchpoints

- **GCW ↔ GSS:** No impact on the GCW side. Clicking the evaluation from GCW opens the **latest round** in GSS. Existing functionality (create eval from solicitation, link, create award, send docs back) must keep working.
- **GSS ↔ VM:** For **included** vendors, a **request resubmission** is triggered in VM on round setup (as an update to all, or email to selected). Excluded vendors are not requested. CO uploads resubmitted docs into GSS.
- **Vendor Response Analysis (stretch):** Re-runnable only for the current round's vendors / new documents; disabled if it wasn't triggered originally; drop findings for deleted documents.

---

## 6. Current implementation — the approach taken

### 6.1 Core architectural decision: "a round is a duplicated Evaluation"

Instead of adding a round dimension onto existing evaluation tables, **each new round is a full clone of the `AS_GSS_Evaluation_SYNCEDRECORD`**. Clones are linked back to the original (round‑1 root) via a `parentEvalId` field, and a new lightweight `AS_GSS_EvaluationRound_SYNCEDRECORD` table stores round metadata and ties the clone to a sequence.

**Why this works well:** Per-round Ratings / Consensus / Teams / Factors come "for free" because each round's data is keyed off its own clone's `evaluationId`. The per-round sub-tabs simply render each clone's existing views.

```
AS_GSS_Evaluation_SYNCEDRECORD (root / Round 1)
  ├─ evaluationId = 100
  ├─ parentEvalId = null (root)
  └─ round (rel) ─────────────► AS_GSS_EvaluationRound_SYNCEDRECORD { roundId, evaluationId:100, sequence:1, ... }

AS_GSS_Evaluation_SYNCEDRECORD (Round 2 clone)
  ├─ evaluationId = 101
  ├─ parentEvalId = 100  ◄── points at the root
  └─ round (rel) ─────────────► AS_GSS_EvaluationRound_SYNCEDRECORD { roundId, evaluationId:101, sequence:2, ... }
```

### 6.2 New record type: `AS_GSS_EvaluationRound_SYNCEDRECORD`
- **UUID:** `931e8145-3f77-4270-a52a-b51de6e76983`
- **Table:** `AS_GSS_EVALUATION_ROUND_SYNCEDRECORD` (jdbc/Appian, schema Appian)

| Field | UUID | Type | Notes |
| :--- | :--- | :--- | :--- |
| roundId | `3a4b03be-cd32-408b-a301-60d75dfb3587` | INTEGER | PK, unique |
| evaluationId | `1756683f-efcf-4edb-8ed1-aa9d83468af7` | INTEGER | FK → the **cloned** Evaluation |
| roundName | `31c08880-eb84-47ee-b92b-9f3c41a446fb` | TEXT | title expression |
| sequence | `d20a1017-98de-4b58-abaa-f8a119687931` | INTEGER | 1-based round order |
| startDate | `7abbf0d2-90d9-4342-9b6a-034ba226298d` | DATE | |
| endDate | `c3f17341-a436-4024-a184-6a70957ca7fd` | DATE | |
| duration | `ecb1038d-6c8d-4249-905b-e030e48e9201` | INTEGER | days |
| isOnSpotConsensus | `85812d35-fe1f-4ccc-b7b0-c61f0e2757d0` | BOOLEAN | per-round |
| createdBy / createdOn | `1929b250…` / `bd6df6db…` | USER / DATETIME | |
| modifiedBy / modifiedOn | `892861fc…` / `284949ba…` | USER / DATETIME | |

**Relationships:**
- `evaluation` (`029ebc2e-4210-4f78-bbea-00df4267bd1d`) MANY_TO_ONE → Evaluation (`e6bc8561-d3a6-4679-b7af-6e279910468e`), on `evaluationId`.
- `createdByUser`, `modifiedByUser` → System User.
- Reciprocal on Evaluation: `round` relationship (`ffe492a5-ac35-47c4-93e3-8655da20b9fa`).

### 6.3 Objects created so far

**Interfaces**
| Name | UUID | Purpose |
| :--- | :--- | :--- |
| `AS_GSS_FM_startNewRound` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42072` | Setup New Round wizard (currently **2 steps**) |
| `AS_GSS_CPS_viewEvaluatorTeam_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42490` | Round-aware Teams wrapper (tab per round → embeddable `viewEvaluatorTeam`) |
| `AS_GSS_CPS_consensusReportView_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42504` | Round-aware Consensus wrapper (tab per round → embeddable, null-hardened `consensusReportView`) |
| `AS_GSS_FM_evaluationDocumentsTab_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42514` | Round-aware Documents wrapper (tab per round → embeddable `evaluationDocumentsTab`; inner Docs/Drafts tabs nest) |
| `AS_GSS_SEC_rounds` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42270` | Rounds panel (cards per round) on Summary |
| `AS_GSS_CP_evaluationSummaryStampField` | `_a-0000e5da-a251-8000-9bbe-011c48011c48_1007655` | Colored circular stamp (icon/text) component |

**Expression rules**
| Name | UUID | Purpose |
| :--- | :--- | :--- |
| `AS_GSS_UT_duplicateEvaluationForNewRound` | `…42160` | Deep-clone an evaluation for a new round |
| `AS_GSS_QR_getEvaluationRoundDetails` | `…42276` | Generic query wrapper over the round record type |
| `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` | `…42289` | Return round records for all child evals of a parent |
| `AS_GSS_UT_returnIdentifiersForEvaluationRounds` | `…42301` | Return parent/child ids, active child, next sequence |
| `AS_GSS_UT_returnViewRenderingConfigFor_Factors` | `…42412` | Build per-round tab config for the Factors tab |
| `AS_GSS_UT_returnLastParticipatedRoundForVendors` | `…42461` | Per-vendor (by uniqueEntityId) last/highest-sequence round across the family. Powers the Vendors tab "Last Participated Round" column. |

*(UUID prefix for the `…` rules above: `_a-0000f04a-0c6d-8000-9ba8-011c48011c48`.)*

### 6.4 How the pieces fit

**`AS_GSS_UT_duplicateEvaluationForNewRound`** (inputs: sourceEvaluation, newEvaluation, newReferenceDocIds, initiator, templateEvaluation)
- Copies header fields (method, CO/CS/chief, title, description, instrument type, IDV award type, masking, weighted-factors, signatures flags).
- Sets `evaluationStatusId = SETTING_UP`, `isDefaultDataGenerated = false`, `isActive = true`, `sourceApplicationId = GSS`, `duplicatedFromEvaluationId = source id`.
- `parentEvalId = source.parentEvalId ?? source.evaluationId` (all rounds point to the round‑1 root).
- Pulls `startDate`/`endDate`/`isOnSpotConsensus` from the new `round` relationship.
- Deep-copies: **phases** (with week/hour→day conversion via `AS_GSS_BL_convertDurationInWeeksOrHoursToDays`), **teams + memberships** (active users only, via `AS_GSS_CO_UT_checkIfUserIsActive`), **criteria/sub-criteria + assignments** filtered to the **selected** factors (`templateEvaluation.criteria` ids), **reference documents** (`newReferenceDocIds`), and **vendors + business types** (nulling ids to force new rows).
- Returns `{ newEvaluation, criteriaTeamMap }` where `criteriaTeamMap` maps factor/sub-factor number → team name.

**`AS_GSS_FM_startNewRound`** (inputs: parentEvaluationId, duplicatedFromEvaluation, templateEvaluation, userAction, newEvaluation)
- Loads parent evaluation, all factor/assignment info, and round identifiers.
- **Step 1:** round name, start date, duration, end date, on-the-spot consensus radio; factor checkboxes toggle criteria in/out of `templateEvaluation.criteria`.
- **Step 2:** `AS_GSS_GRD_vendorListForSelection` (selectable, `maxSelections: 10`, required).
- On "Setup Round": writes selected vendors + round onto `templateEvaluation`, stamps `sequence = nextRoundSequence` + audit fields on the round, and builds `newEvaluation`.

**`AS_GSS_SEC_rounds`** (input: evaluationId)
- Loads rounds via `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation`.
- One `a!cardLayout` per round: decorative bar + tag colored by status (Set Up=yellow / In Progress=purple / Complete=green), round name, "Round N", date range, and an **Edit** record action (`AS_GSS_Evaluation_RECORD.actions.edit`, identifier = that round's evaluationId).

**`AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation`** — queries Evaluation where `parentEvalId = X` and status in {SETTING_UP, INPROGRESS, AWARDEES_SELECTED, COMPLETE}; returns their `round` records.

**`AS_GSS_UT_returnIdentifiersForEvaluationRounds`** — returns `{ parentEvalId, childEvalIds, activeChildId = max(evaluationId), activeChildStatusId, nextRoundSequence = count+1 }`.

**`AS_GSS_UT_returnViewRenderingConfigFor_Factors`** — for each round builds `{ tabName: "Round N", ui: rule!AS_GSS_CPS_viewFactors(evaluationId: <that round's clone>, loggedInUser()) }` — the mechanism behind per-round sub-tabs.

### 6.5 Key existing objects referenced (not new, but central)

| Object | UUID |
| :--- | :--- |
| `AS_GSS_Evaluation_SYNCEDRECORD` (record type) | `e6bc8561-d3a6-4679-b7af-6e279910468e` |
| `AS_GSS_Evaluation_RECORD` (record, for actions) | `4db4a62e-d099-4e54-be19-41498c17b9cc` |
| `AS_GSS_Criteria_SYNCEDRECORD` (factors) | `11dcc745-3c81-49f9-9cb2-6427680e4b41` |
| `AS_GSS_EvaluatorTeam_SYNCEDRECORD` | `791d954b-beae-4171-808f-876583d707fa` |
| `AS_GSS_EvaluatorTeamMembership_SYNCEDRECORD` | `7ac70e31-adcc-4145-a566-fcfe1f55146d` |
| `AS_GSS_CriteriaAssignment_SYNCEDRECORD` | `518a0b4d-1389-4483-8e39-dd103429c2b8` |
| `AS_GSS_EvaluationPhase_SYNCEDRECORD` | `bf3ef3fe-9671-40df-a195-bd71ab8deed8` |
| `AS_GSS_EvaluationVendor_SYNCEDRECORD` | `b6081510-0d11-4d51-8eba-966610b168db` |
| `AS_GSS_EvaluationVendorBusinessType_SYNCEDRECORD` | `28b193af-cca3-4ce3-9837-836838923e60` |
| `AS_GSS_EvaluationDocument_SYNCEDRECORD` | `9c497e08-f4c6-4fbd-bf14-5638dc226230` |

**Reused helper rules:** `AS_GSS_UT_updateRecordsByModelRecord`, `AS_GSS_QR_getCriteria`, `AS_GSS_QR_getEvaluatorTeam`, `AS_GSS_QR_getEvaluationByIdentifier`, `AS_GSS_UT_updateEvaluationRecordWithAllVendors`, `AS_GSS_UT_constructAllFactorAssignmentInformation`, `AS_GSS_GRD_vendorListForSelection`, `AS_GSS_CPS_viewFactors`, `AS_CO_UT_queryRecord`, `AS_CO_UT_indexWhere`, `AS_CO_UT_isNotBlank`, `AS_GSS_CO_UT_checkIfUserIsActive`, `AS_GSS_CO_UT_ArrayLength`.

---

## 6.6 Shipped tab enhancements

- **Vendors tab → "Last Participated Round" column** (2026-08-25, verified): shows each vendor's highest-sequence round (e.g. "Round 3 | Test Round 03"). Backed by `AS_GSS_UT_returnLastParticipatedRoundForVendors` → passed into `AS_GSS_GRD_EvaluationVendors` via new inputs `lastParticipatedRounds` + `showLastParticipatedRound`, computed in `AS_GSS_FM_evaluationVendorsTab`. The **Decision** column already existed. Column is hidden for non-round evals.
- **Teams tab → round sub-tabs** (2026-08-26, verified): `AS_GSS_CPS_viewEvaluatorTeam_Parent` renders `a!tabLayout`, one tab per round, embedding the (now frame-less) `AS_GSS_CPS_viewEvaluatorTeam` per round clone. Established the reusable per-tab wrapper recipe for the remaining 6 tabs.
- **Consensus Reports tab → round sub-tabs** (2026-08-26, verified): `AS_GSS_CPS_consensusReportView_Parent`; the content interface `AS_GSS_CPS_consensusReportView` had **3** HCL frames stripped (one per `if` branch) and its status comparisons **null-hardened** (`a!defaultValue(..., -1)`). Parent supplies `loggedInUser()`.
- **Documents tab → round sub-tabs** (2026-08-26, verified): `AS_GSS_FM_evaluationDocumentsTab_Parent`; content interface `AS_GSS_FM_evaluationDocumentsTab` had 1 HCL frame stripped. Its own Documents/Drafts `a!tabLayout` nests inside the round tab (tabs-in-tabs). No null-hardening needed.

### Round-sub-tab wrapper recipe (proven with Teams)
1. The per-round **content interface must be embeddable** — `a!tabItem.contents` rejects a `HeaderContentLayout`. If the tab interface self-wraps in `AS_GSS_HCL_displayWrapperContents`/`a!headerContentLayout`, strip that outer frame (after `getObjectDependents` confirms scope). An interface with multiple `if` branches may have **multiple frames** to strip (Consensus had 3). `tabItem` contents may be a plain list `{...}` or a `forEach`. `viewFactors` was already embeddable.
1a. **Null-harden the content interface.** Embedded per round, it may receive an evaluationId that resolves to a null evaluation (or the `a!defaultValue` empty round). Guard comparisons like `status = cons!X` with `a!defaultValue(field, -1)`; note `and()` does not short-circuit in SAIL. When saving via `updateInterface`, pass `testInputs` (real evaluationId, and `loggedInUser()` if needed) so validation runs against real data.
2. Put the round-listing **inside the `_Parent` interface** — it cannot be a standalone expression rule because per-round content calls an interface using `env!features` (fails expression-rule validation).
3. `_Parent(evaluationId)` = `headerContentLayout` + `tabLayout` + `forEach(returnEvaluationRoundsForGivenEvaluation)` → `tabItem(label:"Round "&sequence, contents: <content>(roundEvalId))`. RECORD-based tabs wrap the content in a per-round loader that queries the record(s) first.
4. **Repoint the record view manually in Appian Designer** — `updateRecordTypeView`/`getRecordType` fail on `AS_GSS_Evaluation_RECORD` (`None is not a valid RecordTypeSourceType`, service-backed). MCP can create the `_Parent`; a human swaps the one-line rule reference in the view.

## 6.7 Data-model gotchas & SAIL learnings (from implementation)

These are hard-won details — read before touching vendor/round data or building the tab wrappers.

1. **Cross-round vendor identity = `uniqueEntityId` (UEI).** In the current data, `vendorRefId` is **null** and `vendorId` is a per-round PK (changes each clone: 10/11 → 16/17 → 18/19 → 20). Correlate the same vendor across rounds by `uniqueEntityId`. State/local vendors may lack UEI → `stateAndLocalIdentifier` fallback is a future refinement.
2. **Vendor Decision** lives on `AS_GSS_EvaluationVendor_SYNCEDRECORD.decisionTypeId` + `decisionType` relationship (`6732b53c…` → decision-type record `c34b12a0-4ae7-4d21-adb9-09320118b98e`). Label via `AS_GSS_UT_returnDecisionLabelForViewActions`.
3. **Anchor resolution (root ⇄ child):** `anchorId = a!defaultValue(viewedEval.parentEvalId, evaluationId)`; family = `append(anchorId, evals where parentEvalId = anchorId)`. Includes the root even though `returnEvaluationRoundsForGivenEvaluation` returns children only. **Reuse this for every tab wrapper.**
4. **`AS_CO_UT_queryRecord`** accepts returnType strings `"SINGLE_OBJECT"`/`"OBJECT_ARRAY"`; takes `recordType`, `fields`, `filters` (single or list of `a!queryFilter`).
5. **`union()` is type-strict** (errors on Integer + Any-Type empty `{}`). Use `append(tointeger(x), tointeger(a!defaultValue(list,{})))` or `AS_CO_UT_distinct`.
6. **`AS_CO_UT_indexWhere` returns ALL matches** (a list). Wrap with `index(...,1,null)` for first match; `tointeger(max(...))` to avoid "3.0" in labels.
7. **`validateDesignObject` false-positive on i18n components:** grids that require an `i18nData` bundle report `Cannot index property 'lbl_…'` under null-stub validation. Trust `testInterface`/`testRule` (with real inputs) over `validateDesignObject` for these.
8. **Backward-compat pattern:** round-aware helpers should return empty for evals without round records so new UI stays hidden on legacy evaluations.
9. **i18n:** new labels need a bundle key added to the GSS General bundle (loaded via `AS_GSS_CO_UT_loadBundleFromFolder`); the local `.properties` copy is stale. The Vendors column currently uses a literal label (TODO: `lbl_LastParticipatedRound`).

## 7. Known gaps & open risks (to address later)



1. **Setup New Round Step 3 (VM resubmission config) not built.** Wizard is coded as "Step 1 of 2"; missing the *Send as Update / Send as Email* + title/description step, and the actual VM request-resubmission trigger.
2. **`maxSelections: 10`** hardcoded on the vendor selection grid — conflicts with spec ("no max"; Round 1 up to ~400 vendors).
3. **"active round = max(evaluationId)"** assumes the newest round always has the largest id; sequence-based selection would be more robust.
4. **Round-1 / "Start Evaluation" path not yet reviewed.** `startNewRound` handles round 2+. Where the root evaluation gets its first `EvaluationRound` record (Start Evaluation modal) needs confirmation.
5. **No explicit sequence sort** when listing rounds in `SEC_rounds` (query supports `sort` but the section doesn't pass it) — card order relies on default query order.
6. **Cross-cutting UI not yet wired:** round sub-tabs on Ratings/Consensus/Teams; Factors "Rounds" column; Vendors "Last participated round" + Decision columns; Summary showing only current-round factors.
7. **Security / evaluator visibility rules** (per-round team-based access, Factor Chair cross-round visibility) not yet reviewed/implemented.
8. **Start Round confirmation + locking** (factors/vendors locked once a round starts) not yet reviewed.

---

## 8. Source spec artifacts (in this folder)

- `GSS_ Multi Round Evaluations.md` — full research + spec + Q&A.
- `GSS - Multiround Evaluation (1).pdf` — 14-slide Figma mockup deck (empty state, Start Evaluation modal, 3-step Setup New Round, vendor cards, Start Round confirmation, Rounds panel states, per-round tabs for Teams/Consensus/Ratings/Vendors/Factors).
- Figma: https://www.figma.com/deck/U9rGBTKVtpnxLOTNjQmvi8
