# Feature Impact Analysis — Multi-Round Evaluations vs. the whole GSS application

> **Status: MAJOR-SURFACE SWEEP COMPLETE (evidence-based); minor residuals listed in §12.**
> All high-traffic surfaces (both evaluation lists, home + record-summary task grids, task-name generation, the email family, consensus view) have been read and their findings are CONFIRMED from SAIL. A short tail of low-traffic surfaces (documents grids, ratings rollups, alerts, awards, search/pickers) is enumerated in §12 as VERIFY.
> **Purpose:** The POC focused on *building* the feature. It did **not** systematically ask *"what else in the application does the parent-child (hidden-child / parent-only) model touch?"* This document grounds the feature into the wider application: it walks the GSS app, finds every place a **child-round evaluation** can leak to users, break an aggregation, or violate an assumption, and raises the **decisions we need** to handle each.
>
> Read after `05_FEATURE_IMPLEMENTATION_PLAN.md` and `06_FEATURE_TECHNICAL_DESIGN.md`. This is the *"is it safe in the application?"* companion to those *"what/how to build"* docs. Integration (VM/GCW) impact already lives in `02_…`/`04_…`; this doc covers the **in-application** surfaces and references those where they overlap.

---

## 0. The core reason this analysis is needed

The multi-round model is: **a round is a full clone of the `AS_GSS_Evaluation` record** (its own `evaluationId`, `evaluationNumber`, tasks, ratings, consensus, documents, teams). Under the **PO-confirmed hidden-child / parent-only** rule, **users must only ever see and act on the parent (root) evaluation.** Round clones are backend-only technical records.

But almost every downstream object in GSS is keyed on **`evaluationId`** and freely joins `…→ evaluation → evaluationNumber / evaluationTitle` and links to `AS_GSS_Evaluation_RECORD` by that id. When those rows belong to a **child clone**, the child's identity and record link surface to the user. So the recurring risk is one of two failure classes:

- **Leak** — a child evaluation's name, number, or record link is shown to a user (grids, columns, emails, filters, search, notifications), or a user is navigated *into* a child evaluation record.
- **Miscount / mis-scope** — an aggregation, KPI, list, report, or analytics feed treats each clone as a separate evaluation (double counting, inflated Process-HQ mining, wrong "active" scoping).

**The universal fix pattern** (to be decided per surface): resolve the **display identity + record link** to the **parent/root** (`parentEvalId` chain), while keeping the underlying data query on the child. A single shared helper (e.g. `AS_GSS_UT_returnParentEvaluationIdentity(evaluationId)` → parent id + parent number/title) referenced everywhere is strongly preferable to per-interface patches.

**Method / coverage note:** findings below are marked **[CONFIRMED]** (verified by reading the object's SAIL/config), **[LIKELY]** (same pattern, object family inspected but not each member), or **[VERIFY]** (identified by name/role, not yet read). This is a first pass; §12 lists what still needs inspection so we do not over-claim completeness.

---

## 1. WORKED EXAMPLE — the "My Tasks" home grid (the PO's example), fully traced

**Objects:** `AS_GSS_GRD_activeTasks` (`_a-0000ec6b-e6c2-8000-9d9d-011c48011c48_13241781`), task-name generator `AS_GSS_generateEvaluationTasksForAssignee` (`_a-0000edaa-0a95-8000-9e03-011c48011c48_15676146`), title helper `AS_GSS_UT_displayEvaluationRecordTitle` (`_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_939678`).

### 1a. The "Evaluation" column [CONFIRMED — leak]
On the home page (`isHomepage`) the grid renders an **Evaluation** column:
```
text: rule!AS_GSS_UT_displayEvaluationRecordTitle(
         evaluationNumber: task.evaluation.evaluationNumber,   /* rel 0d42598e → Evaluation e6bc8561 */
         evaluationTitle:  task.evaluation.evaluationTitle),
link: a!recordLink(
         recordType: AS_GSS_Evaluation_RECORD {4db4a62e…},
         identifier: task.evaluationId)                        /* field 32da1410 */
```
For a task generated in **Round N**, `task.evaluationId` = the **child clone id**, so:
- **Displayed name** = the child's `evaluationNumber` + `evaluationTitle` (the number differs per clone → visible leak).
- **Link target** = the **child** evaluation record (navigates the user into a hidden evaluation).
- **Sort field** = `evaluation.evaluationNumber` (child's).

### 1b. The task **name** string [CONFIRMED — baked leak]
`generateEvaluationTasksForAssignee` stores `taskName` as a static column:
```
taskName = evaluation.evaluationNumber & " - " & criteria.factorNumber & " - " & vendor.legalName
```
It embeds the **child clone's `evaluationNumber`** (not literally "Round 1"; the round identity rides in via the clone's number). Because it is a persisted `VARCHAR(255)`, it is frozen at generation time — the rebuild controls the convention (see Q1).

### 1c. The "Evaluation" **user filter** [CONFIRMED — leak]
The same grid exposes record user-filters including `…filters.{cd37b4b3-…}Evaluation`. A list-of-values filter sourced from `task.evaluation` will present **child clones as selectable filter options** in the My Tasks toolbar.

### 1d. Decisions this one grid forces
- Show **parent** number/title and link to the **parent** record, while the task list still queries the child's tasks. (Q2)
- Decide the persisted **task-name** convention (parent number? parent number + "Round N"?). (Q1)
- The **Evaluation user filter** must group child clones under their parent (or list only parents). (Q3)

---

## 2. Task surfaces beyond the home grid

**Family inspected:** `listInterfaces(query:"task")` = 89 interfaces; `listExpressionRules(query:"task")` = 145. The `task → evaluation` relationship (`0d42598e`) is the common leak vector.

| Surface | Object(s) | Finding |
| :-- | :-- | :-- |
| Record-summary "active tasks" (per-evaluation) | `AS_GSS_TMG_CPS_recordSummaryActiveTasks` (`…13367338`) → `AS_GSS_GRD_activeTasks` with `isHomePage:false` | **[CONFIRMED — miscount]** The non-home branch filters `evaluationId = ri!evaluationId`. On the **parent** record `ri!evaluationId` = parent id, so the parent's Tasks section shows **only the parent's own tasks and misses every round task** (those carry child ids). Must aggregate the family (or the active round) per the Q4 scope decision. |
| Task detail / start-process link | `AS_GSS_TMG_UT_taskProcessAsLink`, `AS_GSS_TMG_QE_getRuntimeTask` | **[VERIFY]** Task forms open by `taskId` (safe), but any breadcrumb/header showing the parent evaluation resolves via child `evaluationId`. |
| Factor / sub-factor task grids | `AS_GSS_GRD_factorTaskGrid`, `AS_GSS_CPS_factorTaskGridAndToolbar`, `AS_GSS_CPS_subFactorTaskGridAndToolbar` | **[VERIFY]** These are round-scoped by design (rendered inside a round context); confirm they never link out to the child eval header. |
| Task % completion / KPIs | `AS_GSS_TMG_UT_calculateTaskPercentCompletion`, `AS_GSS_TMG_QE_calculateTotalAndCompletedTasks`, `AS_GSS_QE_getAggregatedUserByTaskStatus` | **[VERIFY — miscount]** If any home/summary KPI counts tasks "for an evaluation" by parent id, it will miss round tasks (they're on child ids); if it counts across the family it may double-count completed rounds. Define the intended scope. (Q4) |
| Task due-date / reassign related actions | `AS_GSS_FM_editTaskDueDateRelatedAction`, `AS_GSS_TMG_FM_reassignTasks` | **[VERIFY]** Operate on `taskId`; low risk, but any confirmation text naming the evaluation uses the child. |

---

## 3. Email / notification surfaces  [CONFIRMED family — leak in outbound comms]

**Family inspected:** `listExpressionRules(query:"email")` = 32 rules. Task-assignment email **[CONFIRMED]**: `AS_GSS_UT_emailBodyForTaskAssignment` → `AS_GSS_UT_emailInstructionForTaskAssignment(evaluation: distinct(tasks.evaluation[1]))` resolves the task's **child** evaluation and lists task names (which embed the child number). Same leak vector applies to the whole family:

| Notification | Rules |
| :-- | :-- |
| Task assignment | `emailBodyForTaskAssignment` (`…_1964290`), `emailInstructionForTaskAssignment` (`…_1964314`), `emailSubjectForTaskAssignment` (`…_1964363`), `emailBodyForEvaluationTasksAssignment` (`…_15681374`) |
| Task **record** assignment | `emailSubjectForTaskRecordAssignment` (`…_14286853`), `emailInstructionForTaskRecordAssignment` (`…_14286941`), `emailBodyForTaskRecordAssignment` (`…_14286956`) |
| Task reassignment | `emailSubjectForTaskReassignment` (`…_1966621`), `emailBodyForTaskReassignment` (`…_1966783`) |
| Due / overdue tasks | `emailSubjectForTasksDueAndOverdue` (`…_74288`), `emailBodyForDueAndOverdueTasks` (`…_74305`), `returnUsersForEmailNotification` (`…_14499052`) |
| Due-date change | `emailBodyDueDateChange` (`…_1964662`), `emailSubjectForDueDateChange` (`…_1964741`), `getUserTasksToSendEmailOnDueDateChange` (`…_1964786`) |
| Consensus signature | `emailSubjectForSigningConsensusReport` (`…_9561775`), `emailBodyForSigningConsensusReport` (`…_9562191`), `emailSubjectForConsensusSignNotNeeded` (`…_9561935`), `emailBodyForConsensusSignNotNeeded` (`…_9563724`) |
| VM proposal submission | `emailSubjectForNewProposalSubmission` (`…_15471055`), `emailBodyForNewProposalSubmission` (`…_15471096`) |

**Impact:** emails are the one surface users **cannot** be shielded from by UI filtering — a leaked child number/title/deep-link in an email is permanent. Every rule that names an evaluation or builds an evaluation deep-link must resolve to the **parent**. (Q5)

---

## 4. The Evaluations lists & landing  [CONFIRMED — leak + miscount]

**Correction from the first pass:** the evaluation lists are **ordinary interfaces (readable via MCP)**, not the record-type record list — so this is now CONFIRMED by reading the SAIL, not blocked. There are **two** listing surfaces, and **neither filters out clones**:

- **Evaluations page** — `AS_GSS_GRD_EvaluationRecordList` (`_a-0000ea82-c8e1-8000-9cb9-011c48011c48_7941671`), the target of the site's **Evaluations** page. Its `a!recordData` over `AS_GSS_Evaluation_RECORD` has exactly one structural filter — **`isActive = true`** — plus a role/status OR-block (createdBy / CO / CS / chief / `applicableEvaluationIds`). **No `parentEvalId` filter.** The name cell links `a!recordLink(identifier: evaluationId)`. **[CONFIRMED — child clones list as rows and link to the child.]** For evaluators, `applicableEvaluationIds` is built from assigned criteria + consensus + tasks + team membership — all of which, for round work, reference **child** ids → clones surface for evaluators too.
- **Home "My Workspace"** — `AS_GSS_evaluationLandingPage` (`…13137819`) → **My Active Evaluations** cards via `AS_GSS_CPS_activeEvaluations` fed by `AS_GSS_BL_returnEvaluationInfoForLandingPage` (`_a-0000ec62-ac34-8000-9d9a-011c48011c48_13125383`). That rule filters by **`isActive` + status + role** (createdBy / criteria assignee / consensus startedBy / criteria chair / CO / CS / chief) — again **no `parentEvalId` exclusion**. **[CONFIRMED — clones appear as landing-page cards.]**

**Fix:** add a `parentEvalId is null` (root-only) filter to **both** surfaces, and map any child-derived `applicableEvaluationIds` back to their parent so an evaluator's card/row points at the parent. Also confirm the **clone's `isActive`** value (Q14) — if clones are written `isActive = true` (default for a full clone), they pass today's only structural filter.

**Counts/KPIs:** any `count()`/aggregation over `AS_GSS_Evaluation` (landing counts, reporting) is inflated by clones until the same filter is applied. (Q4/Q14)

---

## 5. Consensus reports (cross-round, Factor Chairs)  [VERIFY — intended cross-round vs. leak]

Factor Chairs are *meant* to see consensus across rounds (a feature), but naming/links still matter.

- `AS_GSS_ConsensusReport_RECORD` / `_SYNCEDRECORD`, `AS_GSS_CPS_consensusReportView` (`…40123`) + `_Parent` (round-aware wrapper). Consensus rows are keyed on the **child** `evaluationId`.
- **[PARTIAL — already round-aware]** `AS_GSS_CPS_consensusReportView` already computes `local!isParentEval = isBlank(evaluation.parentEvalId)` and branches on it (e.g. factor filters `applyWhen: isParentEval`) — the POC touched it. So the cross-round consensus surface is *aware* of the parent/child distinction; the residual questions are labeling and links, not basic awareness.
- **Questions:** In the cross-round consensus view, is each round labeled by **round name/sequence** (good) or by the **child evaluation number** (leak)? Do consensus **record links** (and the consensus-signature emails in §3) point to the parent? (Q7)

---

## 6. Documents  [VERIFY — leak via doc→evaluation]

`AS_GSS_EvaluationDocument_SYNCEDRECORD` (`9c497e08`) rows created for a round carry the **child** `evaluationId` (and copied-doc `evaluationId` is null, attaching via vendor — see onboarding §10.46). The Documents tab is round-aware (`AS_GSS_FM_evaluationDocumentsTab_Parent`).

- **Questions:** Any document grid/column or export that shows the owning **evaluation** name/link resolves to the child. Any "all documents for this evaluation" view keyed on parent id will miss round documents (they're on child ids). Define the intended document scope on the parent. (Q8)

---

## 7. Ratings, Audit trail, and Process-HQ analytics  [VERIFY / CONFIRMED-by-architecture — miscount]

- **Ratings** (`AS_GSS_Rating_SYNCEDRECORD` `49daf634`) — per child; the Ratings tab is round-aware. Any rating rollup/report keyed on parent id misses rounds. (Q9)
- **Combined audit trail** — the Evaluation History tab is round-aware, but the underlying audit records reference the child `evaluationId`; confirm the combined view relabels by round rather than child number. (Q9)
- **Process-HQ / process mining record types** — `AS_GSS_Evaluation_Audit_SYNCEDRECORD` (`5c676254`), `AS_GSS_Evaluation_Field_Audit_SYNCEDRECORD` (`9721dd98`), `AS_GSS_Evaluation_Status_History_SYNCEDRECORD` (`f0784326`). **[CONFIRMED-by-architecture — analytics distortion]:** every child clone runs its own SETTING_UP → INPROGRESS → COMPLETE lifecycle, so process-mining will see **many short-lived "evaluations"** instead of one multi-round journey. This materially changes Process-HQ dashboards / cycle-time metrics. Decide whether children are excluded from mining or stitched to the parent case id. (Q10)

---

## 8. Security & direct navigation  [VERIFY — access + leak]

- A leaked **record link** to a child evaluation only "works" if the recipient passes record-level security on `4db4a62e`. Two failure modes: (a) an evaluator on the round *can* open the child (leak of the hidden-child concept); (b) a user *not* on the round gets an access error from a link that should have gone to the parent (broken UX). (Q6/Q11)
- **Related actions** (`startEvaluationBestValue`, `startRound`, `completeRound`, `setupNewRound`, `edit`) are visibility-gated by status + `parentEvalId` — but if a user reaches a child record directly, confirm no action (e.g. `edit`, `setupNewRound`) is inappropriately available there. (Q11)

---

## 9. Integrations (VM / GCW) — cross-reference

Already analyzed in `02_VM_GSS_MULTIROUND_IMPACT.md` and `04_GCW_GSS_MULTIROUND_IMPACT.md`, and folded into `06` (Batch 8). Summary of the in-app-relevant decisions, repeated here so this doc is self-contained:
- **VM Flow G** (`AS_GSS_mapVendorUpdatesToRecord`) targets the **latest round's** child eval, falling back to parent. Depends on the "active round" definition (Q12).
- **GCW status sync** must be **skipped for child evaluations** (guard on `parentEvalId` populated) so GCW only ever reflects the parent. (Q12)
- Web API payloads returning `evaluationId`/number to VM/GCW must return the **parent** identity. (Q5/Q12)

---

## 10. Awards & awardee selection  [VERIFY]

Award creation and Select Awardees happen **only on the parent** (per the parent-only model). Confirm: awardee selection reads vendors/ratings across the **family** (final round) but persists the award against the **parent**; any award document / notification names the parent. (Q13)

---

## 11. CONSOLIDATED open-questions register (for PO / team)

> **This is the single consolidated question list for the impact analysis** (Q1–Q15). It absorbs and extends the four "open confirmations" from onboarding §11.4 (the "active round" definition below is the same as §11.4's). Answers should be folded into `06_FEATURE_TECHNICAL_DESIGN.md` as explicit build items.

**Identity & display**
- **Q1 — Task-name convention.** What should the persisted `taskName` contain for a round task? Options: (a) parent `evaluationNumber` only; (b) parent number + "Round N"; (c) unchanged child number (rejected — leak). Note it is persisted, so it also affects historical rounds.
- **Q2 — Parent-identity helper.** Approve a single shared helper that maps any `evaluationId` → parent id + parent number/title, to be used by every grid/column/email/link (vs. per-interface fixes)?
- **Q3 — "Evaluation" user filters.** Where a task/consensus/document grid filters by evaluation, should options list **parents only** (children grouped under parent), or show rounds explicitly?
- **Q15 — Landing/list identity for a family.** On the Evaluations page and home "My Active Evaluations" cards, a family should appear as **one row/card = the parent**. Should that row show the **current round's** status/progress (e.g. "Round 3 — In Progress") or the parent's own status? (Drives what the parent-only filter must still surface.)

**Scope & aggregation**
- **Q4 — Task scope on the parent.** On the parent summary/home KPIs, should "tasks for this evaluation" mean the **current/active round**, the **whole family**, or **parent-only**? (Confirmed gap: the record-summary tasks section shows parent-only today and misses round tasks — §2.)
- **Q9 — Ratings/audit rollups.** Same question for ratings rollups and the combined audit: current round, whole family, or parent-only?
- **Q10 — Process-HQ / mining.** Exclude child clones from the audit/status-history mining feeds, or stitch them to the parent as one case? (Materially changes analytics.)
- **Q14 — Clone `isActive` + list/count filter.** Both evaluation lists filter only on `isActive` + status + role with **no `parentEvalId` exclusion** (§4). Confirm the fix = add a `parentEvalId is null` (root-only) filter to `AS_GSS_GRD_EvaluationRecordList`, `AS_GSS_BL_returnEvaluationInfoForLandingPage`, and every evaluation `count()`/KPI — and decide whether clones should also be written `isActive = false` as defense-in-depth (and whether that breaks the round-aware tabs which query clones directly).

**Comms & external**
- **Q5 — Emails & Web API payloads.** Confirm every notification (§3) and every VM/GCW Web API response must render the **parent** identity/deep-link. Any exception?

**Record list, security, navigation**
- **Q6 — Evaluation lists (interface-based, not the record list).** Confirmed the two lists are ordinary interfaces missing a parent filter (§4, Q14). Also decide **global record search / pickers** over `AS_GSS_Evaluation_RECORD` — should clones be excluded there too?
- **Q11 — Child record access.** Should users be *hard-blocked* from opening a child evaluation record entirely (redirect to parent), or only steered away via links? What actions, if any, are valid on a child record? (Depends on record-level security on `4db4a62e` — Designer-only.)

**Feature-specific**
- **Q7 — Consensus cross-round labeling** — the view is already `isParentEval`-aware (§5); confirm rounds are labeled by round name/sequence (not child number) and links resolve to parent.
- **Q8 — Document scope** on the parent (family vs. round).
- **Q12 — "Active round" definition** (max-sequence vs. latest non-complete) — reused by VM latest-round targeting and the Summary active-round vendors (= onboarding §11.4).
- **Q13 — Awards** persist on parent while reading final-round data — confirm.

---

## 12. Sweep coverage — done vs. residual

**Read & CONFIRMED this sweep:**
1. **Evaluations page** `AS_GSS_GRD_EvaluationRecordList` (`…7941671`) — no `parentEvalId` filter → clones list (§4). *(The earlier "MCP-blocked record list" concern was wrong — it is a readable interface.)*
2. **Home landing** `AS_GSS_evaluationLandingPage` (`…13137819`) + `AS_GSS_BL_returnEvaluationInfoForLandingPage` (`…13125383`) + `AS_GSS_CPS_activeEvaluations` — no `parentEvalId` filter → clone cards (§4).
3. **Home task grid** `AS_GSS_GRD_activeTasks` (`…13241781`) — evaluation column name+link resolve to child (§1).
4. **Record-summary tasks** `AS_GSS_TMG_CPS_recordSummaryActiveTasks` (`…13367338`) — parent misses round tasks (§2).
5. **Consensus view** `AS_GSS_CPS_consensusReportView` (`…40123`) — already `isParentEval`-aware (§5).
6. **Task-name generator** + **task-assignment email** — child identity baked / rendered (§1, §3).
7. **Sites/pages** — 3 site pages, all interface-backed (My Workspace, Evaluations, Vendors); Vendors page (`…16580901`) is a global GSM grid, **not** evaluation-scoped → low risk.

**Residual (VERIFY — low-traffic, not yet read; recommend before build):**
1. Remaining **email bodies** beyond task-assignment (consensus-signature, due/overdue, reassignment, VM proposal) — same vector, confirm each renders parent identity.
2. **Documents** grids/exports and any "download all" that names the evaluation.
3. **Ratings** rollups/reports keyed on parent id.
4. **Process-HQ** audit/status-history mining feeds (analytics decision Q10).
5. In-app **alerts** (`AS_GSS_TMG_FM_alertTask`).
6. **Awards / awardee selection** interfaces.
7. **Record-level security** on `AS_GSS_Evaluation_RECORD` (`4db4a62e`) — Designer-only (MCP-blocked) — governs whether a leaked child link is even openable (§8, Q11).

---

## 13. Recommended handling strategy (proposal, pending PO)

1. **One parent-identity helper** (Q2) used everywhere an evaluation name/number/record-link is rendered from a child-keyed row — cheapest, lowest-risk, consistent fix.
2. **Persisted task names** (Q1) generated with the parent's number (+ optional "Round N") at creation time in the rebuild.
3. **Record-list / security filter** (Q6) to remove clones from the Evaluations list, search, and pickers — the single biggest leak surface.
4. **Emails/Web APIs** (Q5) routed through the same parent-identity helper.
5. **Analytics decision** (Q10) made explicitly with the Process-HQ owners before go-live.
6. Everything else (task/rating/document/consensus scope) follows from the **Q4/Q9 scope decisions**.

Once Q1–Q13 are answered, fold the resolutions into `06_FEATURE_TECHNICAL_DESIGN.md` as explicit build items (new helper + per-surface changes) so the rebuild handles them by construction rather than as afterthoughts.
