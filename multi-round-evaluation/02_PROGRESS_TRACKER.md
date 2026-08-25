# GSS Multi-Round Evaluations — Progress Tracker

> Update this file at the end of every working session. Keep the **Session Log** append-only.
> Companion docs: `01_FEATURE_AND_TECHNICAL_DESIGN.md`, `03_AGENT_ONBOARDING.md`.

**Last updated:** 2026-08-25
**Overall status:** 🟡 Foundation in place (record type + duplicate engine + setup wizard skeleton + rounds panel). First tab enhancement shipped (Vendors → "Last Participated Round"). Round sub-tabs not yet built.

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

> Detailed design for the round-aware tabs is in **`04_TABS_IMPLEMENTATION_PLAN.md`**.

| # | Item | Status | Notes |
| :-- | :--- | :--- | :--- |
| 5.1 | `AS_GSS_SEC_rounds` panel (cards + status colors) | ✅ | Built |
| 5.2 | "Setup New Round" link in panel | ⬜ | Not present in component |
| 5.3 | Sequence-based sorting of rounds | ⬜ | Query supports sort; not applied (see plan §4.2) |
| 5.4 | Factors tab per-round rendering config | ✅ | `viewFactors_Parent` + `returnViewRenderingConfigFor_Factors` wired to view `_n_87YA` |
| 5.5 | Round sub-tabs on Ratings | ⬜ | **record-based** loader (query eval per round) — plan WI-4/6e |
| 5.6 | Round sub-tabs on Consensus Reports | ⬜ | id-based wrapper — plan WI-5 |
| 5.7 | Round sub-tabs on Teams | ⬜ | id-based wrapper — plan WI-6 |
| 5.7a | Round sub-tabs on Documents | ⬜ | id-based; nested inner Documents/Drafts tabs — plan WI-6a |
| 5.7b | Round sub-tabs on Task History | ⬜ | id-based wrapper — plan WI-6b |
| 5.7c | Round sub-tabs on Tasks | ⬜ | **record-based** loader — plan WI-6c |
| 5.7d | Round sub-tabs on Evaluation History | ⬜ | **record-based, heavy** (6 collections/round); do lazy pattern — plan WI-6d |
| 5.8 | Factors tab "Rounds" column | ⬜ | Add to `AS_GSS_GRD_ViewFactorsAndSubfactors` — plan WI-7 |
| 5.9 | Summary shows only current-round factors | ⬜ | plan WI-9 |
| 5.10 | Vendors tab: Decision column | ✅ | Already existed in `AS_GSS_GRD_EvaluationVendors` (decisionType-based) |
| 5.10a | Vendors tab: Last Participated Round column | ✅ | Built + render-verified (eval 12 → "Round 3 \| Test Round 03"). New rule `AS_GSS_UT_returnLastParticipatedRoundForVendors` keyed on **uniqueEntityId**; grid+tab wired; column gated by `showLastParticipatedRound`. i18n key TODO (literal label). |
| 5.11 | Anchor / Round-1 inclusion in tab list (blocker) | 🔵 | Rounds query filters `parentEvalId = id` (children only) — verify Round 1 shows & child-record anchor — plan WI-1 |
| 5.12 | Generic `returnRoundTabRenderingConfig` + `roundTabs_Parent` (8 tabs) | ⬜ | Consolidate wrappers; 3 record-based loaders — plan WI-2/WI-3/WI-6c/6d/6e |

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
| 7.5 | `AS_GSS_UT_returnLastParticipatedRoundForVendors` | ✅ | Per-vendor (by uniqueEntityId) max-sequence round across the family; anchor = coalesce(parentEvalId, evaluationId) |

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
1. Wire per-round sub-tabs — start with an ID-based tab (Teams) to prove the generic path (plan WI-2/WI-3/WI-6), then Consensus, Task History, Documents, then record-based (Ratings, Tasks, Evaluation History).
2. Review the Round-1 / Start Evaluation path (§4) to confirm the entry point, round-1 record creation, and settle the anchor question (plan WI-1). The anchor helper pattern is proven (see Session Log 2026-08-25 Vendors, learning #3).
3. Fix `maxSelections` on the vendor grid (§2.4) and make active-round selection sequence-based (§7.3).
4. Build Setup New Round Step 3 + VM resubmission trigger (§2.5, §8.1).
5. Add i18n bundle key for the Vendors "Last Participated Round" column label (§5.10a).

*(Confirm priority with the team before starting each item.)*

---

## Session Log (append-only)

### 2026-08-25 — Discovery & documentation
- Read full spec (`GSS_ Multi Round Evaluations.md`) and all 14 mockup slides.
- Explored AS GSS Full Application via `lcp` MCP; identified all new objects (1 record type, 3 interfaces, 5 rules) and mapped the "round = duplicated evaluation" architecture.
- Authored `01_FEATURE_AND_TECHNICAL_DESIGN.md`, this tracker, and `03_AGENT_ONBOARDING.md`.
- No functional changes made to Appian objects yet.

### 2026-08-25 — Tabs analysis & plan
- Analyzed the Factors round-sub-tab pattern (view `uiExpr` → `AS_GSS_CPS_viewFactors_Parent` → `AS_GSS_UT_returnViewRenderingConfigFor_Factors` → per-round `AS_GSS_CPS_viewFactors`).
- Catalogued input shapes for all Evaluation record tabs: Ratings is **record-based** (`evaluation`), Consensus/Teams/Factors/Vendors are **id-based** (`evaluationId`).
- Identified a blocker: rounds query filters `parentEvalId = id` (children only) — need to confirm Round 1 inclusion + child-record anchor resolution.
- Authored `04_TABS_IMPLEMENTATION_PLAN.md` (per-tab treatment, generic config rule + parent proposal, work items, validation checklist, sequencing).
- No functional changes made to Appian objects yet.

### 2026-08-25 — Expanded tab scope (stakeholder request)
- Added Documents, Tasks, Task History, and Evaluation History to the round-sub-tab set (now 8 tabs total incl. Factors).
- Confirmed input shapes: Documents (id, has inner Documents/Drafts tabs), Task History (id), Tasks (record), Evaluation History (record + 6 queried collections — heavy).
- Updated plan §2/§3/§5/§6/§7/§8/§9/§10 and tracker §5: 5 ID-based + 3 RECORD-based tabs; recommended per-round **loader** interfaces for record-based tabs + a lazy `showWhen` pattern for the heavy Evaluation History tab.
- No functional changes made to Appian objects yet.

### 2026-08-25 — Vendors tab: "Last Participated Round" column (SHIPPED + verified)
First functional change to Appian objects. Implemented and render-verified in this session.

**Objects changed:**
- **Created** `AS_GSS_UT_returnLastParticipatedRoundForVendors` (`_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42461`) — input `evaluationId`; returns `List of Map{uniqueEntityId, sequence, roundName, roundLabel}` where roundLabel = "Round {seq} | {roundName}".
- **Updated** `AS_GSS_GRD_EvaluationVendors` (`_a-0000e5da-a251-8000-9bbe-011c48011c48_1082078`) — added inputs `lastParticipatedRounds` (Map, multiple) + `showLastParticipatedRound` (Boolean); added a "Last Participated Round" column before the existing Decision column.
- **Updated** `AS_GSS_FM_evaluationVendorsTab` (`_a-0000e5da-a251-8000-9bbe-011c48011c48_1082379`) — computes the rounds via the new rule (RECORD_ACTION refresh) and passes to the grid; column shown only when the eval has round records (`isNotBlank`).

**Verification:**
- `testRule` (eval 12): `123456789123 → "Round 3 | Test Round 03"`, `123456789122 → "Round 2 | Test Round 01"`.
- `testInterface` (eval 12): tab rendered, `diagnostics.error = null`; grid shows Test Vendor 001 with column value "Round 3 | Test Round 03".
- PO verified visually — approved.

**Key learnings (important for future tabs):**
1. **Cross-round vendor identity = `uniqueEntityId` (UEI).** `vendorRefId` is **null in the data** (never populated) and `vendorId` is the per-row PK that changes each round (10/11 → 16/17 → 18/19 → 20). Do NOT use vendorId or vendorRefId to correlate a vendor across rounds — use `uniqueEntityId`. (For state/local vendors UEI may be blank → `stateAndLocalIdentifier` fallback is a future refinement.)
2. **Decision data already exists.** `AS_GSS_EvaluationVendor_SYNCEDRECORD` has `decisionTypeId` + `decisionType` relationship (`6732b53c…` → `c34b12a0-4ae7-4d21-adb9-09320118b98e`), and the grid already renders a Decision column via `AS_GSS_UT_returnDecisionLabelForViewActions`. Only "Last Participated Round" was missing vs the mockup.
3. **Anchor resolution pattern that works for both root and child records:** `anchorId = a!defaultValue(viewedEval.parentEvalId, evaluationId)`, then family = `append(anchorId, children where parentEvalId = anchorId)`. This includes the root even though `returnEvaluationRoundsForGivenEvaluation` returns children only — reuse this for the tab wrappers (WI-1).
4. **`AS_CO_UT_queryRecord`** accepts returnType strings `"SINGLE_OBJECT"` / `"OBJECT_ARRAY"` and takes `recordType`, `fields`, `filters` (single or list of `a!queryFilter`). Used directly for custom cross-record queries.
5. **`union()` is type-strict** — it errors on mixed types (e.g. Integer scalar + Any-Type empty `{}`). Use `append(tointeger(x), tointeger(a!defaultValue(list, {})))` or `AS_CO_UT_distinct` instead.
6. **`AS_CO_UT_indexWhere`** returns ALL matches (a list). Test data had duplicate `sequence` values across rounds → wrap with `index(..., 1, null)` to take the first, and `tointeger(max(...))` to avoid "3.0" in labels.
7. **`validateDesignObject` on the grid reports a false-positive** (`Cannot index property 'lbl_Vendors'…`) because it stubs `i18nData` as null; the grid requires a real bundle. The tab validates clean and the interface renders fine — trust `testInterface` over `validateDesignObject` for i18n-dependent components.
8. **Non-round (legacy) evals are unaffected** — the helper returns empty when no round records exist, so the column stays hidden. Safe, backward-compatible pattern to reuse.
9. **i18n TODO:** column label is a literal ("Last Participated Round"); add a bundle key (e.g. `lbl_LastParticipatedRound`) to the GSS General bundle for consistency. Mockup casing is "Last participated round".
10. **Scope note:** the vendor list still queries only the viewed evaluation's vendors (vendor query untouched). Whether the list should aggregate dropped vendors across rounds is deferred to the anchor/Start-Evaluation work.
