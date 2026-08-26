# WI-1 Analysis — Start Evaluation as Round 1 (anchor) + factor-scoped task generation

**Status:** Analysis / design proposal — no code changed yet.
**Date:** 2026-08-26
**Author:** agent (read-only investigation via `lcp` MCP)

> Goal: When a Contracting Officer clicks **Start Evaluation**, the parent evaluation itself
> must become **Round 1** (an `AS_GSS_EvaluationRound` row), the CO must provide **round info**
> (round name, start date, duration, due date) and **select factors** (NOT vendors), and
> **evaluation tasks must be generated only for the selected factors × the evaluation's vendors**
> — not for all factors as today. This is the "anchor" fix that WI-1 refers to: once Round 1
> exists as a round record, every round-aware tab shows Round 1 alongside later rounds, and the
> `returnEvaluationRoundsForGivenEvaluation` family logic can resolve correctly.

---

## 1. Why this is different from "Setup New Round"

| | Setup New Round (exists) | Start Evaluation (this WI) |
| :-- | :-- | :-- |
| Trigger | Related action on an in-progress/complete eval | Related action on a **SETTING_UP** eval |
| Creates | A **new** Evaluation record (a clone) + its `EvaluationRound` row | **No new evaluation** — registers the **existing (parent)** eval as Round 1 |
| Collects round info | Yes (name, dates, duration, on-spot) | **Yes — new requirement** (currently collects nothing) |
| Selects factors | Yes (which factors carry into the new round) | **Yes — new requirement** (currently uses all) |
| Selects vendors | Yes (down-select) | **No** (vendors already attached to the eval) |
| Task generation | On the new round's own Start Evaluation | **Must now be factor-scoped** to the selected factors |

The important architectural point: **Setup New Round writes round metadata through the
Evaluation→`round` relationship** and the DB write cascades to create the `EvaluationRound` row.
Start Evaluation can reuse the *same mechanism* on the parent eval — we do **not** need a new
"create round" service; we set `parentEval['…round…']` fields and let the existing Write node
persist them.

---

## 2. Current-state facts (verified this session)

### 2.1 Start Evaluation action
- Record action `startEvaluation` on `AS_GSS_Evaluation_RECORD` (`4db4a62e-…`).
  - Process model **`0002ecdd-8ec4-8000-bf9c-7f0000014e7a`** ("AS GSS Start Evaluation").
  - `dialogHeight: SHORT` (confirmation-sized).
  - **`contextExpr`** pre-loads and passes to the process:
    - `evaluation` / `originalEvaluation` — `AS_GSS_QR_getEvaluationByIdentifier(evalId)`
    - `evaluationFactorsAndSubFactors` / `originalEvaluationFactorsAndSubFactors` —
      `AS_GSS_QR_getCriteria(evaluationId, isActive: true)` → **ALL active factors+subfactors**
    - `vendors` — `AS_GSS_QR_getEvaluationVendors(evaluationId)` (id, legalName, evaluationId, isActive)
    - `userAction: null`
- Form **`AS_GSS_FM_startEvaluation`** (`_a-0000ecda-a664-8000-9dc8-011c48011c48_14286788`),
  inputs `userAction`, `evaluation`. **It is only a confirmation dialog** ("Start evaluation
  <title>?"). On **Start** it sets `userAction = START` and flips
  `evaluationStatusId → INPROGRESS` (+ modifiedBy/modifiedDatetime) and records several metrics
  (signature required, weighted factors, duplicated-eval, on-spot). It does **not** collect round
  info or factor selection.

### 2.2 Start Evaluation process model flow (PM `0002ecdd…`, 16 nodes)
`Start → XOR "Is cancel?" (userAction=CANCEL → End) → `
1. **Update Evaluation Record** (Write Records, `AS_GSS_Evaluation_SYNCEDRECORD`) — persists the status change.
2. **Sync Eval Status in GCW** (Start Process `0006ef1c-885e-8000-e8da`).
3. **Populate Parent And Child Ratings** — `AS_GSS_BL_createTransactionalRatings(initiator, evaluationFactorsAndSubFactors, evaluationRecord)` → `pv!evaluationRatings`. **Uses the full factor list.**
4. **Write Rating Records** (`AS_GSS_Rating_SYNCEDRECORD`); also `AS_GSS_BL_updateRatingDetailsToCriteriaRecords`.
5. **Update Factors And SubFactors With Ratings** (`AS_GSS_Criteria_SYNCEDRECORD`).
6. **XOR "Toggle"** (`cons!AS_GSS_TOGGLE_VENDOR_ANALYSIS_ENABLED`) → **Trigger Reqt Extraction** (Start Process `0005ef63-71ba-8000`) → Dummy, else Dummy.
7. **XOR "Identify Workflow"**:
   - LPTA → **Generate LPTA Task** (SUB_PROC `0002ee10-7d81-8000-d4cf`)
   - On-the-spot consensus (`isOnSpotConsensus = true`) → **Create Consensus Reports** (SUB_PROC `0003ece5-8031-8000-bff8`)
   - default → **Generate Evaluation Tasks** (SUB_PROC **`0002edab-48b7-8000-cee8-7f0000014e7a`**, inputs `evaluation`, `evaluationFactorsAndSubFactors`, `vendors`) → Create Consensus Reports.
8. **Capture Audit** (SUB_PROC `0007e5df-28c1-8000`, `AS_GSS_UT_constructStartEvaluationAudit`) → End.
- **Process variables:** `evaluation`, `originalEvaluation`, `evaluationFactorsAndSubFactors`, `originalEvaluationFactorsAndSubFactors`, `vendors`, `userAction`, `evaluationRatings`.
- **Task/rating generation is driven entirely by `pv!evaluationFactorsAndSubFactors`** (currently = all active factors). This is the single lever for "only selected factors."

### 2.3 EvaluationRound record + relationship (from getRecordType)
- `AS_GSS_EvaluationRound_SYNCEDRECORD` (`931e8145-…`), DB-backed. Fields:
  `roundId`(PK), `evaluationId`(`1756683f`), `roundName`(`31c08880`), `sequence`(`d20a1017`),
  `startDate`(`7abbf0d2`), `endDate`(`c3f17341`), `duration`(`ecb1038d`),
  `isOnSpotConsensus`(`85812d35`), plus created/modified. Relationship `evaluation`(`029ebc2e`) → Evaluation.
- Evaluation → `round` relationship UUID = **`ffe492a5-ac35-47c4-93e3-8655da20b9fa`**.

### 2.4 How Setup New Round creates the round row (rule `AS_GSS_UT_duplicateEvaluationForNewRound`)
- Builds `newEvaluation` and **reads** `newEvaluation['…round.startDate/endDate/isOnSpotConsensus']`
  to set the eval's `evaluationStartDate` / `evaluationDueDate` / `isOnSpotConsensus`.
- Sets `parentEvalId = a!defaultValue(source.parentEvalId, source.evaluationId)` — i.e. the
  family anchor is the root eval id.
- The wizard (`AS_GSS_FM_startNewRound`, inputs `parentEvaluationId`, `duplicatedFromEvaluation`,
  `templateEvaluation`, `userAction`, `newEvaluation`) captures round fields into
  `newEvaluation['…round…']`; the process's Write Records node persists the Evaluation **and**
  cascades the `round` relationship → creates the `EvaluationRound` row. **⇐ reuse this pattern.**

---

## 3. Target design (proposal)

### 3.1 UX — Start Evaluation becomes a short wizard (mirror Setup New Round, minus vendors)
Replace the single confirmation screen with a stepper:
1. **Round details** — round name, start date, duration, due date (+ on-spot consensus if applicable).
   Reuse the Setup-New-Round round-details step/section and its validations (dates within the
   overall evaluation window; due date ≥ start).
2. **Select factors** — the factor/subfactor picker (default: all selected). **No vendor step.**
3. **Confirm & Start** — keep the existing confirmation copy + metrics.

Cross-reference the mockup (`GSS - Multiround Evaluation (1).pdf`) for the exact field set,
labels, and whether Round 1 shows a special label ("Round 1"/"Initial round"). *(Mockup pages
still to be visually confirmed — see §6.)*

### 3.2 Data — register Round 1 on the parent
On Start, set on the parent evaluation before the write:
- `evaluation['…round…']` = a new `EvaluationRound(evaluationId: parentEvalId, sequence: 1,
  roundName, startDate, endDate(=dueDate), duration, isOnSpotConsensus)`.
- Keep `parentEvalId` **null** on the root (the family anchor = the root's own id, consistent with
  `coalesce(parentEvalId, evaluationId)` used elsewhere), OR set `parentEvalId = evaluationId`.
  **Decision needed** (see §6) — the rounds query and the record-tab fallback must agree.
- Persist via the existing **Update Evaluation Record** write node (it already writes the
  Evaluation record; adding the populated `round` relationship makes it cascade — verify the
  node's field scope / `Version` includes the relationship).

### 3.3 Behavior — factor-scoped task + rating generation
- Carry the **selected** factor list from the wizard into `pv!evaluationFactorsAndSubFactors`
  (instead of the context's "all active"). All downstream nodes (ratings + task generation +
  consensus) then naturally scope to the selection.
- Confirm the **Generate Evaluation Tasks** subprocess (`0002edab-48b7…`) loops
  `evaluationFactorsAndSubFactors × vendors` and has no independent re-query of "all factors"
  (see §6 open item). If it re-queries, we must pass/lock the selection instead.
- Unselected factors: decide whether they are **deactivated** (`isActive=false`) on the eval or
  simply skipped for task generation (still visible). **Decision needed** (§6).

---

## 4. Change inventory (proposed, once design is confirmed)

| # | Object | Change |
| :-- | :-- | :-- |
| A | `AS_GSS_FM_startEvaluation` (interface) | Convert confirmation → multi-step wizard (round details + factor select + confirm). New inputs for round fields + selected factor ids. Reuse Setup-New-Round round-details + factor-picker components. |
| B | Start Evaluation action `contextExpr` | Pass through what the wizard needs (already loads factors + vendors). Possibly seed default round name/dates. |
| C | Start Evaluation PM `0002ecdd…` | (1) On the write node, include the populated `round` relationship so Round 1 is created. (2) Set `pv!evaluationFactorsAndSubFactors` = **selected** factors before ratings/tasks. Possibly a new PV `selectedFactorIds`. |
| D | `AS_GSS_BL_createTransactionalRatings` / task subprocess `0002edab-48b7` | Verify they honor the passed factor list; adjust if they re-query all. |
| E | Round helpers (`AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` / anchor) | Once Round 1 exists, implement family resolution `anchor = coalesce(parentEvalId, evaluationId)` so all tabs show Round 1 + children. Retires the per-parent "current-eval fallback." |
| F | Round-aware tab parents (8) | After E, simplify/remove the current-eval fallback; verify Round 1 tab appears. |
| G | i18n | New labels for the wizard steps + "Round 1". |

---

## 5. Risks & considerations
- **Write-node relationship cascade:** confirm the existing "Update Evaluation Record" node
  persists the `round` relationship (it currently writes only scalar status fields). If it uses a
  restricted field set, we either widen it or add a dedicated write.
- **Idempotency / re-entry:** Start Evaluation should create Round 1 **once**. Guard against a
  second round row if the action is re-run (status already INPROGRESS → action hidden today via
  `AS_GSS_BL_getRelatedActionVisibilityForStartEvaluation`, good).
- **LPTA & on-spot branches** also need Round 1 created and factor scoping — the round write must
  happen on the common path (before the workflow XOR), not only in the default branch.
- **Sequence numbering:** Round 1 = sequence 1; Setup New Round must then continue at 2, 3…
  Confirm how Setup New Round assigns `sequence` today (does it compute max+1 across the family?).
- **Backward compatibility:** existing in-flight evaluations (already INPROGRESS, no Round 1 row)
  won't retroactively get a Round 1. Decide whether a one-time backfill is needed or the
  anchor/fallback keeps them working.
- **Vendors:** unchanged on Start (all attached vendors participate in Round 1). The "down-select"
  only happens at Setup New Round.

---

## 6. Open questions / to confirm before building (Phase 0)
1. **Anchor convention:** root eval keeps `parentEvalId = null` (anchor via `coalesce`) or sets
   `parentEvalId = self`? Pick one and align `returnEvaluationRoundsForGivenEvaluation` + tab fallbacks.
2. **Task subprocess `0002edab-48b7…` internals:** does it iterate the passed
   `evaluationFactorsAndSubFactors × vendors`, or re-query all criteria? (Determines whether
   passing the selection is sufficient.) — *inspect PM nodes.*
3. **`AS_GSS_BL_createTransactionalRatings`:** honors the passed factor list? — *read rule.*
4. **Setup New Round wizard step structure** (`AS_GSS_FM_startNewRound`, body saved at
   `/tmp/gss_se/…`): confirm the round-details + factor-picker components to reuse. — *read file.*
5. **Unselected factors:** deactivate on the eval or just skip for task gen?
6. **Sequence assignment** in Setup New Round (max+1 across family?) so Round 1 = 1 stays consistent.
7. **Mockup cross-reference:** exact fields/labels/step order for Start Evaluation, and whether a
   "Round 1" indicator is shown. — *render `GSS - Multiround Evaluation (1).pdf` pages.*
8. **Write-node field scope:** does "Update Evaluation Record" cascade the `round` relationship, or
   do we need a separate Write for the EvaluationRound row?

---

## 7. Recommended next steps
1. Close the §6 open items (small, targeted reads: task subprocess nodes, ratings rule, the
   Setup-New-Round wizard body, mockup pages).
2. Decide the anchor convention (Q1) and unselected-factor behavior (Q5) with the PO.
3. Then write the build plan (objects A–G) and implement behind verification on eval **6** (root,
   has children) and a fresh SETTING_UP eval.
