# GSS Multi-Round Evaluations — Progress Tracker

> Update this file at the end of every working session. Keep the **Session Log** append-only.
> Companion docs: `01_FEATURE_AND_TECHNICAL_DESIGN.md`, `03_AGENT_ONBOARDING.md`.

**Last updated:** 2026-08-25
**Overall status:** 🟡 Foundation in place (record type + duplicate engine + setup wizard skeleton + rounds panel). Not yet end-to-end.

---

## Status legend
✅ Done · 🟡 In progress · ⬜ Not started · 🔵 Needs review · ❌ Blocked

---

## 1. Foundation / data model

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 1.1 | `AS_GSS_EvaluationRound_SYNCEDRECORD` record type | ✅ | Fields, PK, relationships, title done |
| 1.2 | `round` relationship on Evaluation record type | ✅ | `ffe492a5-…` |
| 1.3 | `parentEvalId` linkage strategy (round = cloned eval) | ✅ | Confirmed approach |
| 1.4 | `duplicatedFromEvaluationId` field usage | 🟡 | Set in duplicate rule; verify downstream use |

## 2. Setup New Round (round 2+)

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 2.1 | `AS_GSS_FM_startNewRound` wizard skeleton | 🟡 | Currently 2 steps; spec needs 3 |
| 2.2 | Step 1 — round name/dates/duration/on-spot consensus | ✅ | Built |
| 2.3 | Step 1 — factor selection (toggle criteria) | ✅ | Built |
| 2.4 | Step 2 — vendor selection | 🟡 | Built but `maxSelections:10` (should be unbounded) |
| 2.5 | Step 3 — VM resubmission config (Update vs Email + title/desc) | ⬜ | Not built |
| 2.6 | Edit due dates per factor in setup | ⬜ | In mockup; not confirmed built |
| 2.7 | Re-include previously excluded vendor | ⬜ | "Include Vendor" action on vendor card |
| 2.8 | Pre-filled edit of a round in Setup | 🔵 | SEC_rounds has Edit action; verify pre-fill |

## 3. Duplication engine

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 3.1 | `AS_GSS_UT_duplicateEvaluationForNewRound` | ✅ | Clones header/phases/teams/criteria/vendors/docs |
| 3.2 | Carry-forward factors filtered to selection | ✅ | Uses templateEvaluation.criteria ids |
| 3.3 | Carry-forward pricing (editable) | ⬜ | Not confirmed handled |
| 3.4 | Factor→document mapping preserve/reset logic | ⬜ | Reset when factor removed — not confirmed |
| 3.5 | Active-user filtering on teams/assignments | ✅ | `checkIfUserIsActive` |

## 4. Round 1 / Start Evaluation

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 4.1 | Start Evaluation modal (round 1 name/dates/factors) | 🔵 | Path not yet reviewed |
| 4.2 | Create round-1 `EvaluationRound` record | 🔵 | Confirm where/if created |
| 4.3 | Best Value gating (feature only for BV) | ⬜ | Not confirmed enforced |

## 5. Rounds display & navigation

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 5.1 | `AS_GSS_SEC_rounds` panel (cards + status colors) | ✅ | Built |
| 5.2 | "Setup New Round" link in panel | ⬜ | Not present in component |
| 5.3 | Sequence-based sorting of rounds | ⬜ | Query supports sort; not applied |
| 5.4 | Factors tab per-round rendering config | 🟡 | `returnViewRenderingConfigFor_Factors` built; wire into tab |
| 5.5 | Round sub-tabs on Ratings | ⬜ | |
| 5.6 | Round sub-tabs on Consensus Reports | ⬜ | |
| 5.7 | Round sub-tabs on Teams | ⬜ | |
| 5.8 | Factors tab "Rounds" column | ⬜ | |
| 5.9 | Summary shows only current-round factors | ⬜ | |
| 5.10 | Vendors tab: Last participated round + Decision | ⬜ | |

## 6. Round lifecycle actions

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 6.1 | Start Round confirmation dialog | ⬜ | "cannot be undone" + lock |
| 6.2 | Lock factors/vendor assignments on start | ⬜ | |
| 6.3 | Select Awardees vs Setup New Round decision point | ⬜ | |
| 6.4 | Complete Evaluation after final awardees | ⬜ | |
| 6.5 | Enforce ≥1 vendor to advance | ⬜ | |
| 6.6 | Max 5 rounds enforcement | ⬜ | |

## 7. Query / util rules

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 7.1 | `AS_GSS_QR_getEvaluationRoundDetails` | ✅ | Generic query wrapper |
| 7.2 | `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` | ✅ | |
| 7.3 | `AS_GSS_UT_returnIdentifiersForEvaluationRounds` | 🟡 | Active child via max(id) — make sequence-based |
| 7.4 | `AS_GSS_CP_evaluationSummaryStampField` | ✅ | Stamp component |

## 8. Integrations

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 8.1 | VM request-resubmission trigger for included vendors | ⬜ | |
| 8.2 | VM exclusion handling (no request to excluded) | ⬜ | |
| 8.3 | GCW: open latest round on click | ⬜ | Verify no regression |
| 8.4 | Vendor Response Analysis re-run scoping (stretch) | ⬜ | |

## 9. Security & audit

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 9.1 | Per-round team-based evaluator visibility | ⬜ | |
| 9.2 | Factor Chair cross-round consensus visibility + indicators | ⬜ | |
| 9.3 | Per-round evaluator masking | ⬜ | |
| 9.4 | Combined audit trail + round-change history entries | ⬜ | |

## 10. Validation & edge cases

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 10.1 | Round dates within overall eval dates | ⬜ | |
| 10.2 | Block save when round exceeds due date | ⬜ | |
| 10.3 | Cannot edit/delete previous round | ⬜ | |
| 10.4 | Cannot skip round / complete early | ⬜ | |

---

## Immediate next candidates (proposed order)
1. Review the Round-1 / Start Evaluation path (§4) to confirm the entry point and round-1 record creation.
2. Fix `maxSelections` on the vendor grid (§2.4) and make active-round selection sequence-based (§7.3).
3. Build Setup New Round Step 3 + VM resubmission trigger (§2.5, §8.1).
4. Wire per-round sub-tabs (§5.4–5.10).

*(Confirm priority with the team before starting — the user indicated we will pick work items after documentation.)*

---

## Session Log (append-only)

### 2026-08-25 — Discovery & documentation
- Read full spec (`GSS_ Multi Round Evaluations.md`) and all 14 mockup slides.
- Explored AS GSS Full Application via `lcp` MCP; identified all new objects (1 record type, 3 interfaces, 5 rules) and mapped the "round = duplicated evaluation" architecture.
- Authored `01_FEATURE_AND_TECHNICAL_DESIGN.md`, this tracker, and `03_AGENT_ONBOARDING.md`.
- No functional changes made to Appian objects yet.
