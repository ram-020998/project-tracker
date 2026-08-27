# 05 — Feature Implementation Plan: GSS Multi-Round Evaluations

> **Purpose.** This is the authoritative, **code-free** blueprint for implementing Multi-Round Evaluations in GSS from a clean (pre-feature) baseline. It tells a developer **what to change, where, why, and what state/behavior each change must produce** — *not* the POC SAIL. The POC (already built and PO-verified) proved the design works; this plan is how to build it for real.
>
> **How to read it.** Sections 1–3 are the mental model — read them first; nothing else makes sense without them. Sections 4–13 are the layered changes. Section 14 is the recommended build sequence. Section 15 is verification. **Appendix A** is the complete object inventory (all 63 package objects → role, new/modified, why).
>
> **Source of this plan.** Synthesized from the POC package object list (`merge-assist-v2/modifiedObjects.md`), live inspection of the current objects, and the design/build records in `01_FEATURE_AND_TECHNICAL_DESIGN.md`, `04_TABS_IMPLEMENTATION_PLAN.md`, and onboarding `03_…` §10. **New/Modified classification** is inferred from object-UUID namespaces + our build log; where it matters, verify against the package's version history.

---

## 1. What we are building (and the one decision everything hangs on)

Today a GSS Best Value evaluation is a **single** pass: the Contracting Officer (CO) starts the evaluation, evaluators rate vendors against factors, consensus is reached, awardees are selected. To run a phased/down-select competition, a CO must create a **brand-new evaluation** per phase and re-key everything.

**Multi-Round Evaluations** let a CO run **one** Best Value evaluation as up to **5 sequential rounds**, narrowing the vendor pool between rounds, while keeping a single continuous record of the competition.

### 1.1 The core architectural decision: *a round is a full clone of the Evaluation record*

Rather than inventing a parallel "round" data structure that every downstream feature (ratings, consensus, teams, tasks, documents, audit) would have to be re-taught, **each round after Round 1 is created as a complete clone of the Evaluation record and all its related data.** Each clone:
- points back to the originating Round-1 record via a new **`parentEvalId`** field, and
- has one row in a new **`EvaluationRound`** table carrying that round's metadata (name, sequence, dates, on-the-spot flag).

**Why this matters:** every existing per-evaluation feature (Ratings, Consensus, Teams, Factors, Tasks, Documents, Audit) already works "for one evaluation." Because a round *is* an evaluation, all of those features work per-round **with zero changes to their core logic** — we only add a thin round-aware presentation layer on top. This is the single highest-leverage decision in the feature; preserve it.

### 1.2 The second decision: hidden-child / parent-only (PO-confirmed, authoritative)

**Users only ever see and work in the parent (Round-1) evaluation.** The round clones are **backend/technical records**; a user never navigates to a child evaluation as if it were a separate evaluation. "Rounds" are surfaced **within the parent's workspace** (a Rounds panel on Summary, and per-round sub-tabs on each content tab).

Consequences that must hold throughout the build:
- **Vendor management, Select Awardees, and award creation happen only on the parent.** Down-selection between rounds decides which vendors are cloned into the next round; it is not per-child vendor editing.
- **External integrations (VM, GCW) resolve to / display the parent.** It is *correct*, not a bug, that they show the root evaluation.
- Any new query/visibility helper must **resolve the family from any member** (see §3) so behavior is identical whether the user is on the root or the system is acting on a child.

---

## 2. Vocabulary (use these terms consistently)

| Term | Meaning |
| :--- | :--- |
| **Family** | The root evaluation + all its round clones. |
| **Root / Parent (Round 1)** | The original evaluation the CO created. `parentEvalId` is null. It **is** Round 1 (not a separate clone). |
| **Child round (Round 2..5)** | A clone created by "Setup New Round." `parentEvalId` = the root's evaluationId. |
| **Anchor** | The root of a family, resolved from any member as `coalesce(parentEvalId, evaluationId)`. |
| **Sequence** | 1-based round order stored on the `EvaluationRound` row. |
| **Down-select** | Choosing which vendors advance from the current round into the next round. |
| **On-the-spot consensus** | Per-round flag: consensus captured live, so no separate evaluator tasks are generated. |

---

## 3. The keystone mechanism: family/anchor resolution

Almost every screen and rule needs to answer: *"Given this evaluation, what are all the rounds in its family, in order?"* This is provided by one rule that everything else depends on.

- **What:** a utility rule that, given any evaluationId, resolves the **anchor** = `coalesce(parentEvalId, evaluationId)`, then returns the `EvaluationRound` rows for the anchor **and** its children, sorted by `sequence`. It must also expose (via additional related fields) each round's evaluationId and status so callers can drive tabs, gating, and labels without re-querying.
- **Where:** `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (family resolver) with companions `AS_GSS_UT_returnIdentifiersForEvaluationRounds` (round→identifier helper) and `AS_GSS_QR_getEvaluationRoundDetails` (query wrapper).
- **Why:** guarantees identical behavior from the root or any child; makes the round list the single source of truth for the Rounds panel, the per-round sub-tabs, and every visibility gate.
- **Behavioral requirements:**
  - Must return the **root's own Round-1 row** (the resolver returns rounds for the anchor itself, not only children). *Historical bug to avoid: an early version filtered `parentEvalId = id`, which hid Round 1 and broke child navigation.*
  - Must be **empty-safe**: an evaluation that has never been started (no round row) returns empty, so all round-aware UI stays hidden and legacy single-pass evaluations are unaffected.
  - Legacy in-flight evaluations (already in progress before the feature) have **no** Round-1 row and are **not** backfilled — accept this and confirm with PO.

---

## 4. Data model changes

### 4.1 New table + record: `EvaluationRound`
- **What/Where:** new synced record `AS_GSS_EvaluationRound_SYNCEDRECORD` over a new table.
- **Fields:** `roundId` (PK), `evaluationId` (FK → the round's evaluation clone), `roundName`, `sequence`, `startDate`, `endDate`, `duration`, `isOnSpotConsensus`, plus standard created/modified audit columns.
- **Relationship:** many-to-one `evaluation` (this round's `evaluationId` → `Evaluation.evaluationId`).
- **Why:** stores the per-round metadata that is *not* part of an Evaluation (name, sequence, per-round on-the-spot flag) and gives the family resolver something to sort by. One row per round; Round 1's row is created when the evaluation is started (§6).

### 4.2 `Evaluation` record gains parent linkage + round relationship
- **What/Where:** `AS_GSS_Evaluation_SYNCEDRECORD` (and the exposed `AS_GSS_Evaluation_RECORD`).
- **Changes:**
  1. New **`parentEvalId`** field — null on the root, = root's id on every child clone. This is the family backbone.
  2. New **`round`** relationship (Evaluation → EvaluationRound) so that writing an Evaluation with a populated `round` **cascades** the EvaluationRound row in the same transaction (no separate round write needed).
- **Why:** `parentEvalId` powers anchor resolution (§3); the cascading `round` relationship is how Round 1 and each clone's round row are persisted atomically with the evaluation write (§6.2, §7).

### 4.3 Supporting CDT/type regenerations (verify field-level deltas)
The package contains regenerated datatypes: `AS_GSS_Evaluation`, `AS_GSS_EvaluationVendor`, `AS_GSS_Criteria`, `AS_GSS_EvaluatorTeam`, `AS_GSS_Rating`, `AS_GSS_EvaluationPhase`, `AS_GSS_TMG_Task`, `AS_GSS_TMG_TaskActionAudit`, `AS_GSS_EvaluationComments`, `AS_GSS_FactorDocumentMapping`.
- **Why they appear:** `AS_GSS_Evaluation` regenerates because of `parentEvalId`; the others are pulled in as **dependencies / schema-sync regenerations** touched by the clone and generation logic.
- **Action for the developer:** treat `Evaluation` (+ `EvaluationRound`) as the substantive schema change. For the rest, **diff each against the baseline** to confirm whether any gained a genuine new column vs. being a pure regeneration; do not assume new fields where none exist.

### 4.4 `FactorDocumentMapping` — no schema change, new usage
`FactorDocumentMapping` links a factor (Criteria) to an evaluation document. It is **not** structurally changed, but it must now be **carried forward** when a round is cloned (§6.4).

---

## 5. Security / access model
- **What/Where:** groups **Contracting Officer** and **Evaluators**.
- **Why in scope:** round-aware visibility. The existing rules already gate "who can start/act on an evaluation" and "which evaluators see which teams." Because a round *is* an evaluation with its own Teams, the existing per-evaluation team membership automatically scopes evaluators to the round(s) they're on. Requirements to enforce:
  - Evaluators see a round **only if** they are on that round's team.
  - Previous rounds are **read-only** for the CO.
  - Factor Chairs can see cross-round consensus (with round indicators).
- **Action:** confirm the two groups' role in the record/action security and ensure no new group is required; the design intent is to reuse existing membership semantics, applied per-round.

---

## 6. Round creation — how a new round comes into existence

There are two distinct creation moments. **Round 1 is not cloned** (it *is* the root); **Rounds 2–5 are cloned** from the current round.

### 6.1 Round 1 — created by *starting* the evaluation (WI-1)
Round 1 is not a separate object; starting a Best Value evaluation **registers the parent as Round 1**. See §7 (Start Evaluation) — the evaluation write populates the `round` relationship with one EvaluationRound row (`sequence = 1`, `parentEvalId` stays null).

### 6.2 Rounds 2–5 — created by "Setup New Round"
- **Where:** interface `AS_GSS_FM_startNewRound` (the wizard) → process model **`AS GSS Duplicate Evaluation For New Round`** → orchestrates the clone via `AS_GSS_UT_duplicateEvaluationForNewRound`.
- **What happens & why:**
  1. **Gate:** "Setup New Round" is only available when the family has ≥1 round and **no round is currently SETTING_UP or INPROGRESS** (i.e., the latest round is COMPLETE). *Why:* you cannot open a new round while the current one is still active; forces finalize-before-advance. Also cap at **5 rounds**.
  2. **Wizard Step 1 — round details + factors:** CO names the round, sets start/duration/due dates, sets the per-round **On-the-Spot Consensus** flag, and selects which **factors** carry into this round. Teams/evaluators **carry forward** from the previous round but are editable.
  3. **Wizard Step 2 — vendor down-select:** CO selects which vendors advance (grid `AS_GSS_GRD_vendorListForSelection`). Must advance **≥1**; no maximum. Previously-excluded vendors may be **re-included**.
  4. **(Optional) Step 3 — resubmission request:** configure how vendors are asked to resubmit (out of scope if the PO confirms 2-step; see `08_…`).
  5. **Clone:** `AS_GSS_UT_duplicateEvaluationForNewRound` builds a new Evaluation graph: new Evaluation (status SETTING_UP, `parentEvalId` = anchor), the selected factors, the advancing vendors, and — cascaded via the `round` relationship — a new EvaluationRound row (`sequence` = previous + 1).
- **State transition:** starting the new round moves the **previous** round to COMPLETE and the **new** round SETTING_UP → (on Start Round) INPROGRESS.

### 6.3 What the clone copies / nulls / resets (`AS_GSS_UT_duplicateEvaluationForNewRound`)
- **Copied:** selected factors (Criteria) and their structure; the advancing vendors; each carried vendor's **documents** (same underlying file via `appianDocId`), so proposals/pricing persist into the new round and remain **editable**.
- **Nulled/reset per cloned child row:** primary keys, back-references (evaluationId/vendorId/consensusId/criteriaId/taskId on documents), and audit fields (created/modified = initiator/now). New DB keys are generated during the round write.
- **Why:** the new round starts as an independent working copy that inherits context but doesn't share identity with the prior round.

### 6.4 Carry factor→team assignments (`AS_GSS_UT_updateFactorTeamMappingForDuplicatedEvaluation`)
- **What/Why:** after the clone, re-establish each carried factor's **evaluator-team assignment** on the new round so evaluators/teams carry forward (matching the wizard's "teams carry forward" promise). Runs as part of the duplicate orchestration.

### 6.5 Carry factor→document mappings (`AS_GSS_UT_constructFactorDocumentMappingsForNewRound`)
- **The problem it solves:** `FactorDocumentMapping` has two FKs (factorId → Criteria, documentId → EvaluationDocument) that are **DB-generated during the round write**, so the mapping cannot be built inside the pre-write clone graph, and Criteria has no child relationship to nest it under.
- **The approach (PO-approved "criteria pre-write"):** the Setup-New-Round process writes the criteria/evaluation **first** and returns the persisted records (with new ids). A dedicated rule then correlates **factor by `factorNumber`** (old criteriaId → factorNumber → new criteriaId) and **document by `appianDocId`** (old documentId → appianDocId → new documentId), and produces the new mapping rows (only where the source mapping was active).
- **Why the correlation keys:** `factorNumber` and `appianDocId` are **stable across the clone** (surrogate keys are not). Mappings whose factor or document was **not** carried are naturally dropped — this satisfies the rule "factor→doc mapping resets if a factor is removed."
- **Where it runs:** a **Write Records** step in the Setup-New-Round process, immediately **after** the evaluation/criteria write, in the System lane.

---

## 7. Start Evaluation as Round 1 (WI-1)

**Goal:** clicking Start Evaluation on a Best Value evaluation must (a) register the parent as Round 1, and (b) generate tasks/ratings/consensus scoped to the selected factors × the evaluation's vendors — turning today's confirm-only dialog into the round-aware entry point.

### 7.1 The modal — `AS_GSS_FM_startEvaluationBestValue`
- **What:** a single-screen Start Evaluation modal (Best Value only): **Round Name** (default "Initial Evaluation"), **Start Date / Duration / Due Date**, and a **factor multi-select** showing each factor's Team / Evaluators / due date (default all selected, with a live "N of N selected" count). **No vendor step and no on-the-spot toggle** here (Round 1 uses the evaluation's existing vendors; on-the-spot is a per-round concept introduced from Round 2 onward).
- **Why:** the factor selection is the scoping input that makes generation round-aware (§7.3). The banner must state that **once started, factors & assignments cannot be modified** for the round.
- **On submit:** set the evaluation to **INPROGRESS**, write the chosen dates, and **populate the `round` relationship** with one EvaluationRound (`sequence = 1`, dates/on-spot from the modal). Output the **selected factor ids** to the process.

### 7.2 The process — `AS GSS Start Evaluation Best Value`
- **What/Where:** a Best-Value-only process cloned from the existing Start Evaluation process **minus the LPTA branch**, plus a new **"Scope Selected Factors"** step.
- **Node intent (in order):** cancel-guard → **write the evaluation** (with the populated `round` relationship → cascades the Round-1 row) → sync status to GCW → **scope factors** (filter the evaluation's factor list to the selected parents **and** their subfactors) → generate ratings → write ratings → update factors with ratings → (vendor-analysis toggle) → optional requirement extraction → **XOR on on-the-spot**: if on-the-spot, create consensus reports only; else generate evaluator tasks then consensus → capture audit → end.
- **Why:** task/rating/consensus generation is **factor-list driven** — every generator iterates `factors × vendors`. Scoping the factor list up front makes all generation automatically scoped to the selected factors, with **no change to the generator subprocesses**.

### 7.3 The record action + visibility split — `AS_GSS_Evaluation_RECORD`
- **What:** a new record action **`startEvaluationBestValue`** pointing at the WI-1 process, visible only when the evaluation is **SETTING_UP AND method = Best Value AND is the root** (`parentEvalId` is blank).
- **Also:** the **existing** Start Evaluation action must be guarded to fire only when **method ≠ Best Value** (so LPTA/other methods keep the old confirm-only flow) — this is the single change to an existing action, and ensures exactly one Start action shows.
- **Why the root guard:** a child round is started via **Start Round** (§8), not Start Evaluation.

---

## 8. Start Round (WI-2) — starting an already-created child round

**Goal:** after Setup New Round creates a child (SETTING_UP), the CO clicks **Start Round** to run the full generation (INPROGRESS + ratings/tasks/consensus + on-the-spot XOR) **without creating another round** (factors/vendors are already scoped on the clone).

- **The constraint that shapes the design:** a record action's dialog *is* its process's start form, and one process binds exactly one start form. To show a **new** Start Round confirm dialog while **reusing** the existing generation process, use a **thin wrapper process** whose start form is the new dialog and which calls the existing Start-Evaluation generation process as a subprocess.
- **Objects:**
  - `AS_GSS_FM_startRound` — confirm dialog; shows the **round number** and **included-vendor count**; on Start sets the evaluation INPROGRESS.
  - `AS GSS Start Round` — wrapper process: start form = the dialog → subprocess = existing generation process (writes the evaluation **without** a `round` relationship → no new round) → end.
  - Record action **`startRound`** on `AS_GSS_Evaluation_RECORD`, visible when the evaluation is **Best Value AND a child** (`parentEvalId` not blank) AND start-ready.
- **Why reuse:** maximum reuse, no duplicated generation logic, and it avoids re-creating process nodes the platform tooling can't (see §16).

---

## 9. Complete Round + Setup-New-Round gating (WI-3)

- **Complete Round — `AS GSS Complete Round`:** a wrapper process with **no start form** (runs immediately on click) that reuses the existing Mark-Evaluation-Complete logic with the evaluation pre-set to **COMPLETE**. Reuses the existing write + GCW sync + audit.
- **Record action `completeRound`** on `AS_GSS_Evaluation_RECORD`, shown on the **INPROGRESS** round.
- **Open-task guard — `AS_GSS_UT_checkifAnyOpenTaskForGivenEval`:** used to determine whether the round can be completed / a new round opened while evaluation tasks are still open. *Why:* enforces "finalize all evaluation actions before advancing" and "no early/skipped completion."
- **Setup-New-Round gate:** visible only when the family has ≥1 round and **no round is SETTING_UP or INPROGRESS** (all complete), and count < 5. *Why:* a new round can only begin after the current one is finished.

### 9.1 The full lifecycle (state machine to implement)
```
root SETTING_UP
  → Start Evaluation (Best Value)  → Round 1 INPROGRESS
  → Complete Round                 → Round 1 COMPLETE
  → Setup New Round (clone)        → Round 2 SETTING_UP
  → Start Round                    → Round 2 INPROGRESS
  → Complete Round                 → Round 2 COMPLETE
  → … (max 5) … → Select Awardees (on parent) → award
```

---

## 10. The Rounds panel (Summary) — `AS_GSS_SEC_rounds`

- **What:** the section on the parent's Summary that renders one **card per round** (from the family resolver, §3): round name, date range, a **status pill** (SET UP / IN PROGRESS / COMPLETE), a chevron into completed rounds, and — depending on state — action buttons.
- **Action placement rules (why each is state-scoped):**
  - **Start Round** — only on the **latest** round when it is **SETTING_UP** (older set-up rounds never show it).
  - **Complete Round** — only on the **INPROGRESS** round.
  - **Edit round details** / **Setup New Round** — per the gates in §9.
- **Helper:** `AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation` resolves "the latest child round in SETTING_UP" so the card shows Start Round on exactly the right round.
- **Why on the parent only:** consistent with §1.2 — the user manages rounds from within the parent workspace, never by navigating into a child.

---

## 11. Round-aware content tabs (the 8 sub-tabbed tabs)

Every Evaluation content tab must become **round-aware**: show one sub-tab per round, each rendering that tab's existing content **for that round's evaluation clone**. This is a **presentation wrapper**, not a rewrite of the tab.

### 11.1 The pattern (apply to every tab)
- **What:** create a `_Parent(evaluationId)` wrapper interface per tab that: resolves the family (§3), and renders a `tabLayout` with one `tabItem` per round (label = "Round N"), whose contents call the **existing** tab content for that round's evaluationId.
- **Why a wrapper:** the round clone already has its own Teams/Consensus/Ratings/etc., so the *content* interface needs no logic change — only a per-round host.
- **Two content shapes:**
  - **ID-based tabs** (content takes an evaluationId): Factors, Teams, Consensus, Documents, Task History — the wrapper just passes each round's id.
  - **Record/query-based tabs** (content takes already-queried objects): Ratings, Checklist Items/Tasks, Evaluation History — the wrapper must **run that tab's query per round** inside the tab item, with a **current-evaluation fallback** when a member has no child rounds.

### 11.2 Mandatory gotchas (these will bite; they're why the content interfaces are in the package)
- **Content must be embeddable** — a `tabItem` rejects a `HeaderContentLayout`. Each tab's content interface must have its outer header/wrapper frame **stripped** so it can nest per round (this is why `AS_GSS_CPS_viewFactors`, `…viewEvaluatorTeam`, `…consensusReportView`, `…evaluationRatingsTab`, `…viewRecordTasks`, `…evaluationAuditHistory`, `…taskAuditActionHistory`, `…evaluationDocumentsTab` all appear as **modified**). Some interfaces have multiple frames to strip.
- **Null-harden** per-round content: a per-round evaluationId may resolve null; guard status comparisons with defaults (SAIL `and()` does not short-circuit).
- `paneLayout` is rejected inside a `tabItem` — use columns.
- Keep it **backward-compatible**: helpers return empty for non-round evaluations, so single-pass evaluations render exactly as before.

### 11.3 The tabs and their wrappers
| Tab | Content (modified → embeddable) | Round-aware wrapper (new) | Shape |
| :--- | :--- | :--- | :--- |
| Factors | `AS_GSS_CPS_viewFactors` | `AS_GSS_CPS_viewFactors_Parent` | ID |
| Teams | `AS_GSS_CPS_viewEvaluatorTeam` | `AS_GSS_CPS_viewEvaluatorTeam_Parent` | ID |
| Consensus Reports | `AS_GSS_CPS_consensusReportView` | `AS_GSS_CPS_consensusReportView_Parent` | ID |
| Documents | `AS_GSS_FM_evaluationDocumentsTab` | `AS_GSS_FM_evaluationDocumentsTab_Parent` | ID |
| Task History | `AS_GSS_TMG_FM_taskAuditActionHistory` | `AS_GSS_TMG_FM_taskAuditActionHistory_Parent` | ID |
| Ratings | `AS_GSS_CPS_evaluationRatingsTab` | `AS_GSS_CPS_evaluationRatingsTab_Parent` | Record |
| Checklist Items / Tasks | `AS_GSS_TMG_CPS_viewRecordTasks` | `AS_GSS_TMG_CPS_viewRecordTasks_Parent` | Record |
| Evaluation History | `AS_GSS_FM_evaluationAuditHistory` | `AS_GSS_FM_evaluationAuditHistory_Parent` | Record |

- **Factors tab specifics:** `AS_GSS_UT_returnViewRenderingConfigFor_Factors` drives how the Factors tab renders per round, and grid `AS_GSS_GRD_ViewFactorsAndSubfactors` shows factors with expandable subfactors (round-aware rating column).
- **Record-view repoint (manual):** each tab's Evaluation record view must be pointed at the new `_Parent` wrapper. This is a **manual step in Designer** (see §16).

---

## 12. Vendors tab

- **What/Where:** `AS_GSS_FM_evaluationVendorsTab` + grid `AS_GSS_GRD_EvaluationVendors`, backed by `AS_GSS_UT_returnLastParticipatedRoundForVendors`.
- **Change:** add a **"Last Participated Round"** column showing, per vendor, the highest-sequence round the vendor was part of across the family.
- **Why & correlation key:** vendors are cloned per round, so a vendor's surrogate key (`vendorId`) **changes every round** and `vendorRefId` may be null — vendors must be correlated across rounds by **`uniqueEntityId` (UEI)**. This column tells the CO where each vendor dropped out.

---

## 13. Summary composition & the Rounds context

The Summary view must be recomposed so the parent workspace shows: current-round essentials on the left, the Rounds panel and settings/description/solicitation on the right, and the active round's vendors.

- **`AS_GSS_CPS_evaluationInformationForLeftPanelOfSummary`** — left column: evaluation **Details** (status, duration, method, instrument type) for the current round.
- **`AS_GSS_CPS_evaluationInformationForRightPanelOfSummary`** — right column: **Settings** (On-the-Spot Consensus | Round N, Consensus Report Signatures, Weighted Factors), **Description**, **Solicitation/Opportunity**.
- **`AS_GSS_SEC_DisplayActiveRoundVendorsInSummary`** — the vendor cards for the **active round** shown on Summary.
- **`AS_GSS_SEC_rounds`** — the Rounds panel (§10), placed in the right column.
- **Supporting rules for Summary factor progress:** `AS_GSS_UT_returnEvaluationTaskProgressForGivenCriteria` (per-factor **task completion %** shown in the Summary factor list) and `AS_GSS_UT_constructAllFactorAssignmentInformation` (factor rows enriched with their assignment/team/evaluator info).
- **Why:** the Summary is the single pane where the CO drives the whole multi-round lifecycle; it must reflect the **current/active round** while exposing the full round history via the Rounds panel.
- **Manual:** the Summary record view layout and the header record actions (Start Evaluation / Start Round / Setup New Round / Select Awardees / Upload Documents) are edited in Designer (§16).

---

## 14. Integration touchpoints (VM & GCW)

The parent-only model (§1.2) makes multi-round largely integration-safe, but two touchpoints need attention.

- **VM (Vendor Management) — vendor proposal updates:** `AS_GSS_mapVendorUpdatesToRecord` must map an inbound vendor update to the vendor row in the **latest round's** evaluation clone (resolve the family, take the max-sequence round), falling back to the parent. *Why:* when a round is active, an incoming proposal/resubmission belongs to the current round's vendor record, not a stale earlier round.
- **GCW (Contract Writing) — status sync:** GCW status syncs should reflect the **parent** only; **skip syncs for child evaluations** (a child going COMPLETE mid-competition must not tell GCW the whole evaluation is done). *(Documented decision; implement when the integration work is scheduled — `artifacts/04_…`.)*
- **General rule for any other integration:** always resolve to the **anchor/parent** before reading or writing evaluation identity outward.

---

## 15. Business rules to enforce (acceptance checklist)
- Best Value only; **max 5 rounds**.
- Must advance **≥1** vendor to a new round; no maximum. Vendors eliminated **only between rounds**.
- Previous rounds are **read-only** for the CO; **no round deletion**; **no skipping / early completion** (open-task guard, §9).
- CO can **re-include** a previously excluded vendor in a new round.
- Evaluators see a round **only if** on that round's team; Factor Chairs see cross-round consensus with round indicators.
- On-the-spot consensus and evaluator masking are **per-round**.
- Round dates must sit **within** the overall evaluation dates; block save if a round exceeds its due date.
- Carry-forward documents/pricing are **editable**; factor→doc mapping **resets** if a factor is removed (§6.5).
- **Combined** audit trail across rounds.

---

## 16. Recommended build sequence (dependency order)

1. **Data model** (§4): create `EvaluationRound`; add `parentEvalId` + `round` relationship to `Evaluation`. *Nothing else compiles without this.*
2. **Family resolver** (§3): `returnEvaluationRoundsForGivenEvaluation` (+ identifier/query helpers). Verify on a known multi-round family before building UI.
3. **Start Evaluation as Round 1** (§7): modal → process → record action + visibility split. This creates the Round-1 row that everything else keys off.
4. **Round-aware tabs** (§11): strip content interfaces to embeddable, build the 8 `_Parent` wrappers, repoint record views (manual).
5. **Setup New Round + clone** (§6): wizard, duplicate rule, team-mapping carry, factor-doc-mapping carry (Write step).
6. **Start Round / Complete Round + gating** (§8, §9) and the **Rounds panel** (§10).
7. **Summary recomposition + Vendors last-round** (§12, §13).
8. **Integration touchpoints** (§14).
9. **Business-rule enforcement pass + full acceptance test** (§15, §17).

---

## 17. Verification plan
- Use a **multi-round test family** (root + several child rounds) as the fixture.
- After Start Evaluation: assert a Round-1 row exists (`sequence=1`, `parentEvalId` null), status INPROGRESS, and generated **tasks = selectedFactors × vendors**, with ratings/consensus scoped to the selected factors; on-the-spot variant creates consensus only (no tasks); LPTA/non-Best-Value paths are unchanged.
- After Setup New Round: assert a new clone (SETTING_UP, `parentEvalId` = anchor, `sequence` = prev+1), advancing vendors + their documents copied, factor→team and factor→document mappings carried, and previous round moved COMPLETE.
- Round-aware tabs render one sub-tab per round on the parent; single-pass evaluations render exactly as before (regression).
- Vendors "Last Participated Round" correct across a down-select.
- Integration: a VM vendor update lands on the latest round's vendor; GCW is not told "complete" on a mid-competition child.
- Prefer live render/execute tests over static validation for i18n-bundle grids.

---

## 18. Platform / tooling constraints that shaped the POC (so a dev isn't surprised)
- **`AS_GSS_Evaluation_RECORD` record-action and view edits could not be automated** in the POC tooling (they failed with a source-type error) — **record actions and view repoints are done manually in Designer.** Budget for this.
- **Certain process nodes (Start Process) couldn't be created via tooling** — the POC used async subprocess calls to the same processes instead; validate these in Designer for the real build.
- **Adding a lane-scoped process node had to be done manually** (the factor→doc-mapping Write step, §6.5).
- These are POC-environment tooling limits, **not** design constraints — a normal Designer build does all of the above directly.

---

## Appendix A — Complete object inventory (all 63 package objects)

**Legend:** N = new for this feature · M = modified existing object · R = regenerated type/dependency. New/Modified inferred from UUID namespace + build log; confirm against package version history.

### A.1 Data model & types
| Object | Kind | N/M | Role / why it's in the package |
| :--- | :--- | :-- | :--- |
| `AS_GSS_EvaluationRound_SYNCEDRECORD` | Record+table | N | New per-round metadata (name, sequence, dates, on-spot). §4.1 |
| `AS_GSS_Evaluation_SYNCEDRECORD` | Record | M | Added `parentEvalId` + `round` relationship. §4.2 |
| `AS_GSS_Evaluation_RECORD` | Record | M | New/guarded record actions + view repoints to `_Parent` wrappers. §7.3, §11 |
| `AS_GSS_Evaluation` (type) | CDT | R | Regenerated from `parentEvalId`. §4.3 |
| `AS_GSS_EvaluationVendor` / `AS_GSS_Criteria` / `AS_GSS_EvaluatorTeam` / `AS_GSS_Rating` / `AS_GSS_EvaluationPhase` / `AS_GSS_TMG_Task` / `AS_GSS_TMG_TaskActionAudit` / `AS_GSS_EvaluationComments` / `AS_GSS_FactorDocumentMapping` (types) | CDT | R | Dependency/schema regenerations touched by clone + generation; verify field-level deltas. §4.3 |

### A.2 Family resolution & round metadata
| Object | Kind | N/M | Role |
| :--- | :--- | :-- | :--- |
| `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` | Rule | M | **Keystone** family/anchor resolver. §3 |
| `AS_GSS_UT_returnIdentifiersForEvaluationRounds` | Rule | N | Round → identifier helper. §3 |
| `AS_GSS_QR_getEvaluationRoundDetails` | Rule | N | Query wrapper for round rows. §3 |
| `AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation` | Rule | N | "Latest child in SETTING_UP" → Rounds-card Start Round placement. §10 |

### A.3 Round creation / clone
| Object | Kind | N/M | Role |
| :--- | :--- | :-- | :--- |
| `AS GSS Duplicate Evaluation For New Round` | Process | N | Setup-New-Round orchestration (write criteria → carry mappings → clone). §6.2 |
| `AS_GSS_UT_duplicateEvaluationForNewRound` | Rule | M | Builds the clone graph (factors, vendors, documents). §6.3 |
| `AS_GSS_UT_updateFactorTeamMappingForDuplicatedEvaluation` | Rule | M | Carry factor→team assignments to the new round. §6.4 |
| `AS_GSS_UT_constructFactorDocumentMappingsForNewRound` | Rule | N | Carry factor→document mappings (correlate by factorNumber/appianDocId). §6.5 |
| `AS_GSS_updateEvaluationRecordWithRelatedInfo` | Rule | M | Generic evaluation write (round row cascades via `round` rel). §4.2, §7.2 |
| `AS_GSS_FM_startNewRound` | Interface | N | Setup New Round wizard (round details, factor select, vendor down-select). §6.2 |
| `AS_GSS_GRD_vendorListForSelection` | Grid | N | Vendor down-select / awardee selection grid. §6.2 |

### A.4 Start / Complete round workflow
| Object | Kind | N/M | Role |
| :--- | :--- | :-- | :--- |
| `AS_GSS_FM_startEvaluationBestValue` | Interface | N | WI-1 Start Evaluation modal (round details + factor scoping). §7.1 |
| `AS GSS Start Evaluation Best Value` | Process | N | WI-1 generation process (scoped factors, cascades Round 1). §7.2 |
| `AS_GSS_FM_startRound` | Interface | N | WI-2 Start Round confirm dialog. §8 |
| `AS GSS Start Round` | Process | N | WI-2 wrapper reusing generation process. §8 |
| `AS GSS Complete Round` | Process | N | WI-3 complete active round (no form). §9 |
| `AS_GSS_UT_checkifAnyOpenTaskForGivenEval` | Rule | N | Open-task guard for Complete/Setup gating. §9 |

### A.5 Rounds panel & Summary
| Object | Kind | N/M | Role |
| :--- | :--- | :-- | :--- |
| `AS_GSS_SEC_rounds` | Interface | M | Rounds panel: per-round cards + state-scoped actions. §10 |
| `AS_GSS_CPS_evaluationInformationForLeftPanelOfSummary` | Interface | M | Summary left column (Details). §13 |
| `AS_GSS_CPS_evaluationInformationForRightPanelOfSummary` | Interface | M | Summary right column (Settings/Description/Solicitation). §13 |
| `AS_GSS_SEC_DisplayActiveRoundVendorsInSummary` | Interface | N | Active-round vendor cards on Summary. §13 |
| `AS_GSS_UT_returnEvaluationTaskProgressForGivenCriteria` | Rule | N | Per-factor task-completion % on Summary. §13 |
| `AS_GSS_UT_constructAllFactorAssignmentInformation` | Rule | M | Factor rows enriched with assignment info. §13 |

### A.6 Round-aware content tabs (wrappers = N, content = M)
| Object | Kind | N/M | Role |
| :--- | :--- | :-- | :--- |
| `AS_GSS_CPS_viewFactors_Parent` / `AS_GSS_CPS_viewFactors` | Interface | N / M | Factors tab: round wrapper / embeddable content. §11.3 |
| `AS_GSS_UT_returnViewRenderingConfigFor_Factors` | Rule | N | Factors render config per round. §11.3 |
| `AS_GSS_GRD_ViewFactorsAndSubfactors` | Grid | M | Factors + expandable subfactors (round-aware). §11.3 |
| `AS_GSS_CPS_viewEvaluatorTeam_Parent` / `AS_GSS_CPS_viewEvaluatorTeam` | Interface | N / M | Teams tab wrapper / content. §11.3 |
| `AS_GSS_CPS_consensusReportView_Parent` / `AS_GSS_CPS_consensusReportView` | Interface | N / M | Consensus tab wrapper / content. §11.3 |
| `AS_GSS_GRD_vendorDataForConsensusReport` | Grid | M | Consensus vendor data grid. §11.3 |
| `AS_GSS_FM_evaluationDocumentsTab_Parent` / `AS_GSS_FM_evaluationDocumentsTab` | Interface | N / M | Documents tab wrapper / content. §11.3 |
| `AS_GSS_TMG_FM_taskAuditActionHistory_Parent` / `AS_GSS_TMG_FM_taskAuditActionHistory` | Interface | N / M | Task History tab wrapper / content. §11.3 |
| `AS_GSS_CPS_evaluationRatingsTab_Parent` / `AS_GSS_CPS_evaluationRatingsTab` | Interface | N / M | Ratings tab wrapper / content (record-shape). §11.3 |
| `AS_GSS_TMG_CPS_viewRecordTasks_Parent` / `AS_GSS_TMG_CPS_viewRecordTasks` | Interface | N / M | Checklist/Tasks tab wrapper / content (record-shape). §11.3 |
| `AS_GSS_FM_evaluationAuditHistory_Parent` / `AS_GSS_FM_evaluationAuditHistory` | Interface | N / M | Evaluation History tab wrapper / content (record-shape). §11.3 |

### A.7 Vendors tab
| Object | Kind | N/M | Role |
| :--- | :--- | :-- | :--- |
| `AS_GSS_FM_evaluationVendorsTab` | Interface | M | Vendors tab: adds Last Participated Round. §12 |
| `AS_GSS_GRD_EvaluationVendors` | Grid | M | Vendors grid: new round column. §12 |
| `AS_GSS_UT_returnLastParticipatedRoundForVendors` | Rule | N | Highest round per vendor (by UEI). §12 |

### A.8 Integrations & security
| Object | Kind | N/M | Role |
| :--- | :--- | :-- | :--- |
| `AS_GSS_mapVendorUpdatesToRecord` | Rule | M | VM: map vendor updates to the **latest round's** vendor. §14 |
| `Contracting Officer` | Group | M | Round workflow permissions. §5 |
| `Evaluators` | Group | M | Per-round team visibility. §5 |

---

## Appendix B — Coverage caveat
This plan was assembled from the package **object list**, **live object inspection**, and our design/build records — **not** from a version-by-version diff (the tooling can't diff prior versions). The **New/Modified** flags and the exact field-level deltas on the regenerated CDTs (§4.3) should be confirmed against the package's version history during the real build. Everything in §§1–17 (the design intent, sequencing, state transitions, and rationale) is verified against the working POC.
