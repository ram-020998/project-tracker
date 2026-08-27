# 08 — UI Redesign from New Mockups (DEFERRED — not started)

> **Status: DEFERRED by PO (2026-08-27) — "leave this, we don't need this now."** This doc preserves the review of the **new mockups** so the work isn't lost. No screens were changed.
>
> **Mockup source (local, not in repo):** `/Users/ramaswamy.u/Downloads/GSS - Multiround Evaluation (1)/images/*.jpeg` (32 images: 8 full-screen + Start Evaluation / Setup New Round wizard steps + Rounds-panel crops + component crops). Ask the PO for the Figma/deck if these are gone.

## 1. Scope in one line
A redesign centered on the **Evaluation Summary + round workflow**. The other content tabs (Factors, Vendors, Ratings, Consensus Reports, Teams) appear **unchanged** in the mockups.

## 2. Per-screen change inventory (mockup → object)
| # | Screen / mockup | What changed | Target object(s) | Editable via |
| :-- | :--- | :--- | :--- | :--- |
| 1 | **Summary — right-hand "Rounds" panel** (the main change) | Round cards: name, date range, status pill **COMPLETE / SET UP / IN PROGRESS**, chevron into completed rounds, "*N vendors advanced*" + completed date, **Edit round details** link, **START ROUND** button on the set-up round, **Setup New Round** link. New **Settings** section (On the Spot Consensus \| Round N, Consensus Report Signatures, Weighted Factors), **Description** (with More/edit), **Solicitation** (empty-state / related procurements). | `AS_GSS_SEC_rounds` (`_a-…42270`) for the round cards; the **Summary view layout** + section composition on `AS_GSS_Evaluation_RECORD` | Rounds section: **MCP**. Summary layout: **Designer only** (MCP blocked on `AS_GSS_Evaluation_RECORD`, §10.47) |
| 2 | **Header actions** (state-driven) | **START EVALUATION** → **START ROUND** → **SETUP NEW ROUND**; plus **UPLOAD DOCUMENTS**, **⋯**, and a **Select Awardees** link. | Record actions on `AS_GSS_Evaluation_RECORD` | **Designer only** |
| 3 | **Start Evaluation** modal | Round Name (default "Initial Evaluation") + Start Date / Duration (days) / Due Date; **Factors** checklist with per-factor **Team / Evaluators / Due Date**; "N of N selected" badge; note "Once started, factors & assignments cannot be modified." | `AS_GSS_FM_startEvaluationBestValue` (`_a-…42569`) | **MCP** |
| 4 | **Setup New Round** wizard | **Step 1** — round name + Start/Duration/Due + **On the Spot Consensus Yes/No** + **Factors** checklist (Team/Evaluators/per-factor Due Date, "N of N selected"). **Step 2** — **vendor checklist** (search, Name/UEI, "N of N selected", paging). **Step 3** — *Configure resubmission request*: **Send as Update / Send as Email** + **Title** + **Description**. | `AS_GSS_FM_startNewRound` (`_a-…42072`) | **MCP** |
| 5 | **Start Round** confirm | Confirm dialog (already built as `AS_GSS_FM_startRound` `_a-…42738`); verify against mockup. | `AS_GSS_FM_startRound` | **MCP** |
| 6 | **Phases** tab | A **Phases** tab appears in the newer "IVS" mockups (purple env) but not the "wqe" ones (grey env). | `AS_GSS_Evaluation_RECORD` views | **Designer only** |

## 3. Open questions to resolve before building
1. **Setup New Round steps: 2 or 3?** One mockup shows "Step 1 of 2 / Step 2 of 2"; another shows "Step 3 of 3 — Configure resubmission request." The 3-step version adds the resubmission-request step. Confirm the final count and whether the resubmission step is in scope.
2. **Phases tab — in or out?** Inconsistent across mockups.
3. Confirm the exact **Settings** fields and **Solicitation** section content/source on the Summary.
4. Reconcile with the **hidden-child / parent-only model** (`01_…` §1a): the Rounds panel shows round *cards* within the parent (allowed — that's round info, not navigating into child evaluations). Confirm the round cards don't deep-link into child evaluation records.

## 4. Suggested sequencing (when un-deferred)
1. `AS_GSS_SEC_rounds` — round-card redesign (status pills, date range, "N vendors advanced"/completed date, chevron, Edit round details, per-state Start Round / Setup New Round). *(MCP; verify with `testInterface` on the round-family evals.)*
2. `AS_GSS_FM_startNewRound` — 2/3-step wizard (factors → vendors → resubmission).
3. `AS_GSS_FM_startEvaluationBestValue` / `AS_GSS_FM_startRound` — align to mockups.
4. Hand off Designer-only pieces (Summary layout, header record actions, Phases tab) with precise specs.
