# Implementation Backlog — GSS Multi-Round Evaluations

> **Purpose:** the complete feature broken into **implementation stories and tasks**, **sequenced in actual build order**. Synthesized from every feature doc: `05_FEATURE_IMPLEMENTATION_PLAN.md` (build sequence + 63-object inventory), `06_FEATURE_TECHNICAL_DESIGN.md` (8 batches, object-by-object), `07_APPLICATION_IMPACT_ANALYSIS.md` (hidden-child remediation + Q1–Q15), `../01_FEATURE_AND_TECHNICAL_DESIGN.md` (workflow + rules), `02_/04_…` (VM/GCW), and `../08_UI_REDESIGN_NEW_MOCKUPS.md` (deferred).
>
> **Conventions**
> - **Story (US-n):** a **testable, user-observable** outcome. Has *As a / I want / so that* + acceptance criteria (Given/When/Then).
> - **Task (T-n):** **technical work** with no direct user-observable behavior on its own. Has a definition-of-done.
> - **Seq** = global implementation order. Build top-to-bottom; `Deps` lists hard prerequisites.
> - **Src** = source doc/section. **Q#** = a decision from the doc 07 register that gates the item.
> - This is a **clean rebuild** from doc 06 (not incremental patching of POC objects), *except* Epic G items, which modify **existing** shared GSS objects for hidden-child safety.
>
> **Estimation & tooling:** points/owners intentionally omitted (see closing questions). Say the word and I can push these to Jira via the connected project.

---

## Epic map (in order)

| Epic | Theme | Testable feature? |
| :-- | :-- | :-- |
| **A** | Decisions & naming baseline | no (enablement) |
| **B** | Data model & family resolution | partly (rule tests) |
| **C** | Start Evaluation as Round 1 (Best Value) | yes |
| **D** | Round-aware detail tabs | yes |
| **E** | Setup New Round & clone | yes |
| **F** | Start / Complete round & Rounds panel | yes |
| **G** | Hidden-child integrity (impact remediation) | yes |
| **H** | External integrations (VM / GCW) | yes |
| **I** | End-to-end testing & hardening | yes |
| **J** | UI redesign from new mockups | **DEFERRED** (PO) |

---

## EPIC A — Decisions & naming baseline  *(do first; unblocks the rest)*

**T-1 — Resolve the open decision register (Q1–Q15).** `Seq 1` · Src: doc 07 §11
DoD: PO sign-off recorded for Q1–Q15. The build-critical ones and what they gate:
- **Q2** parent-identity helper approach → gates **T-6, Epic G**.
- **Q14** clone `isActive` + `parentEvalId` list filter → gates **US-10/11**.
- **Q1** task-name convention → gates **US-3**.
- **Q4** parent task scope (family vs active round vs parent) → gates **US-13**.
- **Q12** "active round" definition → gates **US-9, US-16, US-6**.
- **Q10** Process-HQ handling → gates **T-17**.
- Q3/Q5/Q7/Q8/Q11/Q13/Q15 → gate US-15/US-14/US-7(consensus)/US-6(docs)/T-18/US-17(awards)/US-11.
> Where a decision is still open when its story starts, proceed with the **doc-06 default** and mark the story "assumption-pending-Q#".

**T-2 — Freeze the final object set (rename / consolidate / eliminate).** `Seq 2` · Deps: T-1 · Src: 05 App.A, 06 §1
DoD: the authoritative list of New / Modified / Regenerated / Eliminated objects (e.g. 8 `_Parent` → 1 wrapper; `returnViewRenderingConfigFor_Factors` eliminated; `_SYNCEDRECORD` vs `_RecordType` suffix per Q from §11.4) is locked, so downstream stories reference final names.

---

## EPIC B — Data model & family resolution  *(doc 06 Batch 1–2)*

**T-3 — Add `parentEvalId` to the EvaluationRound table.** `Seq 3` · Deps: T-2 · Src: 06 Batch 1; onboarding §11.2
DoD: new column on `AS_GSS_EvaluationRound_SYNCEDRECORD` (null for root's Round-1 row, = root id for child rounds); synced-record refreshed; index on `(evaluationId, parentEvalId, sequence)`; existing round fields verified (`sequence`, `roundName`, dates, `isOnSpotConsensus`).

**T-4 — Family/round helper rules (with unit test cases).** `Seq 4` · Deps: T-3 · Src: 06 Batch 2
DoD: build + test-case-cover `AS_GSS_QR_getEvaluationRoundDetails`, keystone `AS_GSS_QR_getRoundsForEvaluation` (2 queries, rounds-table-only, sequence-sorted, status-joined), `returnIdentifiersForEvaluationRounds`, `returnLatestChildEvaluationInSetupForGivenEvaluation`, `hasOpenCompleteEvaluationTask`. All standards-compliant (`AS_CO_UT_queryRecord`, sort-in-query). Each rule has passing test cases on the known family (root 6 → rounds).

**T-5 — Parent-identity resolver helper.** `Seq 5` · Deps: T-3 · Src: 07 Q2
DoD: `AS_GSS_UT_returnParentEvaluationIdentity(evaluationId)` → { parentEvalId, parentEvaluationNumber, parentEvaluationTitle }, resolving `coalesce(parentEvalId, evaluationId)`. Test cases for root and child inputs. **This is the shared dependency for all Epic G display fixes.**

---

## EPIC C — Start Evaluation as Round 1 (Best Value)  *(doc 06 Batch 3)*

**US-1 — Start a Best Value evaluation as Round 1.** `Seq 6` · Deps: T-4 · Src: 06 Batch 3; 01 §1a; onboarding §10.45
> *As a Contracting Officer, I want to start a Best Value evaluation and capture Round 1 details + factor selection, so that the parent becomes Round 1 and evaluation work begins.*
AC: Given a SETTING_UP Best Value eval, When I open Start Evaluation, Then I see the single-screen modal (Round name default "Initial Evaluation", start/duration/due, factor multi-select all-checked, "N of N selected"). When I submit, Then the eval → INPROGRESS and a Round-1 `EvaluationRound` row is created (`sequence=1`, `parentEvalId` null). LPTA/non-Best-Value are unaffected (old flow).

**US-2 — Generation scoped to selected factors × vendors.** `Seq 7` · Deps: US-1 · Src: 06 Batch 3
> *As a CO, I want tasks/ratings/consensus generated only for the selected factors and the eval's vendors, so that unselected factors create no work.*
AC: Given a factor subset, When Start Evaluation runs, Then tasks = selectedFactors(+subfactors) × vendors; ratings & consensus are scoped identically; on-spot Best Value creates consensus but no evaluation tasks.

**US-3 — Task names show the parent identity.** `Seq 8` · Deps: US-2, T-5 · Src: 07 §1b, Q1
> *As a user, I want task names to reference the parent evaluation (not a hidden child), so that no child identity leaks.*
AC: Given the Q1-approved convention, When tasks are generated for any round, Then the persisted `taskName` uses the **parent** number (+ "Round N" if approved), never the child clone number.

**T-6 — Start Evaluation Best Value PM (node-by-node).** `Seq 9` · Deps: US-1 · Src: 06 Batch 3; onboarding §10.45
DoD: clone of `0002ecdd…` minus LPTA + a "Scope Selected Factors" node; PVs incl. `selectedFactorIds`; `validateDesignObject` clean; the two Start-Process steps handled per env constraints (§10.47).

**T-7 — [MANUAL/Designer] Start Evaluation record action + visibility split.** `Seq 10` · Deps: T-6 · Src: onboarding §10.45–10.47
DoD: create `startEvaluationBestValue` action → PM; visibility = SETTING_UP AND Best Value AND `isBlank(parentEvalId)`; guard existing `startEvaluation` with the Best-Value exclusion so exactly one shows.

---

## EPIC D — Round-aware detail tabs  *(doc 06 Batch 4)*

**US-4 — View per-round sub-tabs on an evaluation.** `Seq 11` · Deps: T-4 · Src: 06 Batch 4; onboarding §7b
> *As a user of a multi-round evaluation, I want each detail tab (Factors, Teams, Consensus, Documents, Task History, Ratings, Checklist Items, Evaluation History) to show one sub-tab per round, so that I can review any round in place.*
AC: Given a family with N rounds, When I open a round-aware tab on the parent, Then I see sub-tabs "Round 1..N" each rendering that round's content; a single-round/leaf eval renders without error; content is null-safe.

**T-8 — Consolidated round-tab wrapper.** `Seq 12` · Deps: US-4 · Src: 06 Batch 4
DoD: build `AS_GSS_CPS_roundContentTabs(evaluationId, tabType)` (a!match router) replacing all 8 `_Parent` wrappers; embeddable-content contract enforced (strip outer HCL frames); `testInterface` per tabType on the known family; retire the 8 `_Parent` + `returnViewRenderingConfigFor_Factors`.

**T-9 — [MANUAL/Designer] Repoint Evaluation record views to the wrapper.** `Seq 13` · Deps: T-8 · Src: onboarding §7a, §10.47
DoD: each round-aware view on `AS_GSS_Evaluation_RECORD` references the consolidated wrapper (MCP-blocked → Designer).

---

## EPIC E — Setup New Round & clone  *(doc 06 Batch 5)*

**US-5 — Set up a new round after the current round completes.** `Seq 14` · Deps: US-1, T-4 · Src: 06 Batch 5; 01 §1a
> *As a CO, I want to set up a new round (name/dates, vendor down-select, factor carry) once the prior round is complete, so that the evaluation narrows to the next round.*
AC: Given all existing rounds COMPLETE, When I open Setup New Round, Then I complete the wizard and a new child round eval is created (SETTING_UP, `sequence=max+1`, `parentEvalId=root`); ≥1 vendor required; round dates must sit within overall eval dates; max 5 rounds enforced. Setup New Round is hidden while any round is SETTING_UP/INPROGRESS.

**US-6 — New round clones the evaluation faithfully.** `Seq 15` · Deps: US-5 · Src: 06 Batch 5; onboarding §10.46, §10.50
> *As a CO, I want the new round to carry the right data forward, so that carried factors/teams/vendors/documents are correct.*
AC: When a round is created, Then clone copies/nulls/resets per spec; factor→team mapping set (evaluatorTeamId only); carried vendors' documents copied; **factor→document mappings** carried (factor by factorNumber, doc by appianDocId), dropping mappings whose factor/doc wasn't carried. (Active-round semantics per Q12.)

**T-10 — Clone + carry rules.** `Seq 16` · Deps: US-6 · Src: 06 Batch 5
DoD: clone builder, `updateFactorTeamMappingForDuplicatedEvaluation` (merge-only), `constructFactorDocumentMappingsForNewRound` — all built + test-covered.

**T-11 — Setup New Round PM (node-by-node).** `Seq 17` · Deps: T-10 · Src: 06 Batch 5
DoD: PM builds the round, writes criteria (node 6), returns persisted ids; `validateDesignObject` clean.

**T-12 — [MANUAL/Designer] Factor-doc-mapping Write node + setupNewRound action + gating.** `Seq 18` · Deps: T-11 · Src: onboarding §10.50, §10.49
DoD: "Write Records" node after node 6 (System lane) writing the mapping rule output; `setupNewRound` action created; visibility gated to "all rounds COMPLETE" + optional `<5` cap.

---

## EPIC F — Start / Complete round & Rounds panel  *(doc 06 Batch 6)*

**US-7 — Start an already-created round.** `Seq 19` · Deps: US-5, US-2 · Src: 06 Batch 6; onboarding §10.48
> *As a CO, I want to start a set-up round, so that its tasks/ratings/consensus generate without creating a new round.*
AC: Given the latest round is SETTING_UP, When I click Start Round, Then it → INPROGRESS and generation runs (reusing the Start-Evaluation process, no new round); no factor-selection step (already scoped).

**US-8 — Complete the active round.** `Seq 20` · Deps: US-7 · Src: 06 Batch 6; onboarding §10.49
> *As a CO, I want to complete the in-progress round, so that I can then set up the next round.*
AC: Given an INPROGRESS round, When I click Complete Round, Then it → COMPLETE (backend, no form), reusing Mark-Complete + GCW sync + audit.

**US-9 — Rounds panel shows each round with correct status and actions.** `Seq 21` · Deps: US-7, US-8 · Src: 06 Batch 6; onboarding §10.48–10.49; Q12
> *As a CO, I want a Rounds panel listing each round with status and the right action, so that I can drive the lifecycle.*
AC: Then each round card shows name/sequence/status (color per status); Start Round shows only on the latest SETTING_UP round; Complete Round only on the INPROGRESS round; Edit always; "active round" resolved per Q12.

**T-13 — Round wrapper PMs + status-display helper.** `Seq 22` · Deps: US-9 · Src: 06 Batch 6
DoD: `AS GSS Start Round` + `AS GSS Complete Round` wrapper PMs; `AS_GSS_UT_returnRoundStatusDisplayConfig` (de-dupes the 4 status→color matches); validated.

**T-14 — [MANUAL/Designer] startRound / completeRound actions.** `Seq 23` · Deps: T-13 · Src: onboarding §10.48–10.49
DoD: both actions created with correct visibility (`parentEvalId` gating) and contextExpr.

---

## EPIC G — Hidden-child integrity (impact remediation)  *(doc 07; needs clones from Epic E to test)*

**US-10 — Child clones excluded from the Evaluations list.** `Seq 24` · Deps: US-5, T-5 · Src: 07 §4, Q14
> *As a user, I want the Evaluations page to show one row per evaluation family (the parent), so that hidden rounds never appear.*
AC: Given a family with rounds, When I open the Evaluations page, Then only the parent appears (child clones filtered by `parentEvalId is null`); evaluator scoping maps child-derived ids back to the parent; the row links to the parent.

**US-11 — Child clones excluded from home cards & counts.** `Seq 25` · Deps: US-10 · Src: 07 §4, Q14/Q15
> *As a user, I want "My Active Evaluations" and any evaluation count to reflect families, not clones.*
AC: Then home cards show the parent only (optionally the current round's status per Q15); evaluation counts/KPIs exclude clones.

**US-12 — My Tasks grid shows parent name + parent link.** `Seq 26` · Deps: T-5 · Src: 07 §1, Q2
> *As a user, I want the Evaluation column on My Tasks to name and link the parent, so that a round task doesn't navigate me into a hidden child.*
AC: Given a round task, When the grid renders, Then the Evaluation column shows the parent number/title and `a!recordLink` targets the parent id; sort still works.

**US-13 — Record-summary tasks scoped correctly.** `Seq 27` · Deps: US-7, T-5 · Src: 07 §2, Q4
> *As a user on the parent record, I want the Tasks section to show the intended scope, so that round tasks aren't missing.*
AC: Per Q4 (family / active round / parent-only), When I view the parent's Tasks section, Then it shows the agreed scope (today it wrongly shows parent-only and misses round tasks).

**US-14 — Notifications render parent identity + parent deep-link.** `Seq 28` · Deps: T-5 · Src: 07 §3, Q5
> *As an email recipient, I want notifications to name/link the parent evaluation, so that no child identity leaks in comms.*
AC: For task-assignment, reassignment, due/overdue, due-date-change, and consensus-signature emails, When sent for round work, Then subject/body/links use the parent identity.

**US-15 — Evaluation user-filters group by parent.** `Seq 29` · Deps: US-10 · Src: 07 §1c, Q3
> *As a user filtering task/consensus/document grids by evaluation, I want options to be parents, so that clones aren't selectable.*
AC: Then the "Evaluation" user filter lists parents only (or groups children under parent per Q3).

**T-15 — Apply parent-identity helper across remaining grids/columns/links.** `Seq 30` · Deps: T-5 · Src: 07 §12
DoD: sweep §12 residuals (documents grids/exports, ratings rollups, alerts, awards displays) and route evaluation name/link through `returnParentEvaluationIdentity`; each upgraded from VERIFY to fixed.

**T-16 — Process-HQ / audit-status-history handling.** `Seq 31` · Deps: T-1 (Q10) · Src: 07 §7, Q10
DoD: implement the Q10 decision — exclude child clones from mining feeds, or stitch clones to the parent case id — across `Evaluation_Audit`, `Evaluation_Field_Audit`, `Evaluation_Status_History`.

**T-17 — [MANUAL/Designer] Child-record access control.** `Seq 32` · Deps: T-1 (Q11) · Src: 07 §8, Q11
DoD: per Q11, set record-level security / navigation guard so a leaked child link either redirects to the parent or is blocked; confirm no inappropriate actions on a child record.

---

## EPIC H — External integrations (VM / GCW)  *(doc 06 Batch 8; 02/04)*

**US-16 — VM vendor updates target the latest round's clone.** `Seq 33` · Deps: US-5, T-4 · Src: 06 Batch 8; 02 §1b; Q12
> *As the VM integration, I want vendor updates written to the latest round's evaluation, so that changes land on the active round (parent fallback).*
AC: When VM Flow G runs, Then `mapVendorUpdatesToRecord` targets the latest-round clone (per Q12), falling back to parent; verified via testRule.

**US-17 — GCW status sync suppressed for child rounds.** `Seq 34` · Deps: US-8 · Src: 06 Batch 8; 04 §1b
> *As the GCW integration, I want only the parent's status to sync, so that child-round transitions don't leak to GCW.*
AC: When a child round changes status, Then the GCW sync is skipped (guard on `parentEvalId` populated); parent transitions still sync.

**T-18 — Web API payloads return parent identity.** `Seq 35` · Deps: T-5 · Src: 07 §9, Q5/Q12
DoD: VM/GCW-facing Web APIs returning `evaluationId`/number resolve to the parent identity.

---

## EPIC I — End-to-end testing & hardening

**US-18 — Full round lifecycle on a live family.** `Seq 36` · Deps: Epics C–H · Src: 01 §1a; onboarding §7
> *As QA, I want to run Create → Start Evaluation → Complete factor work → Setup New Round → Start Round → Complete Round → … → Select Awardees on a live family, so that the end-to-end flow is verified with no child leakage.*
AC: The lifecycle completes; at each step the leak/scope checks (Epic G) hold; awards persist on the parent (Q13).

**T-19 — Regression: LPTA & non-Best-Value unaffected.** `Seq 37` · Deps: US-1 · Src: 05 verification
DoD: LPTA and non-Best-Value evaluations behave exactly as before (start flow, tasks, no rounds UI).

**T-20 — Complete §12 residual verification.** `Seq 38` · Deps: T-15 · Src: 07 §12
DoD: read + confirm/clear the low-traffic residuals (other email bodies, documents grids, ratings rollups, alerts, awards, record-level security) so no VERIFY items remain.

---

## EPIC J — UI redesign from new mockups  *(DEFERRED — PO)*

Tracked in `../08_UI_REDESIGN_NEW_MOCKUPS.md`. Not scheduled. When picked up, create stories per screen (Summary Rounds panel restyle, Setup New Round wizard redesign, Start Evaluation form redesign). Some pieces are Designer-only.

---

## Sequencing summary (build order)

`A(T1–T2) → B(T3→T4,T5) → C(US1→US2→US3, T6→T7) → D(US4→T8→T9) → E(US5→US6→T10→T11→T12) → F(US7→US8→US9→T13→T14) → G(US10→US11→US12→US13→US14→US15→T15→T16→T17) → H(US16→US17→T18) → I(US18→T19→T20)` · **J deferred.**

Rationale: data model + helpers first (everything depends on them); the **parent-identity helper (T-5)** is built early because Epic G depends on it; Start Evaluation before tabs (tabs need Round 1 to exist); Setup New Round before the integrity epic (you need a real clone to test that clones are hidden); integrations after the lifecycle exists; E2E last.

---

## Assumptions & open questions (for you)

**Assumptions made** (so the backlog is usable now):
1. Stories that depend on an unresolved Q proceed on the **doc-06 default** and are flagged "assumption-pending-Q#".
2. Epic G (integrity) is sequenced **after** Setup New Round because a child clone must exist to test the fixes; if you'd rather fix leaks the moment clones can appear, US-10/11/12 can move up right after US-5.
3. Manual/Designer items are kept as **tasks** (technical), even where they enable a story, because MCP can't perform them.

**Questions before I finalize / estimate:**
1. **Tracking tool** — do you want these pushed to **Jira** (I can create the epics + stories/tasks via the connected project), or keep this markdown backlog as the source of truth?
2. **Granularity** — is this the right grain, or do you want the larger stories (US-1, US-6) split further (e.g., modal vs PM vs action as separate stories)?
3. **Estimates/owners** — should I add story points and suggested owners/labels?
4. **Q1–Q15 gating** — proceed with doc-06 defaults where a decision is open (current approach), or hold the gated stories until the PO answers?
5. **Deferred UI (Epic J)** — leave deferred, or break it out now for visibility?
