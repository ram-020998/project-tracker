# GSS Multi-Round Evaluations — Progress Tracker

> Update this file at the end of every working session. Keep the **Session Log** append-only.
> Companion docs: `01_FEATURE_AND_TECHNICAL_DESIGN.md`, `03_AGENT_ONBOARDING.md`.

**Last updated:** 2026-08-26
**Overall status:** 🟢 **All 8 round sub-tabs shipped** (Factors, Teams, Consensus Reports, Documents, Task History, Ratings, Checklist Items/Tasks, Evaluation History) + Vendors → "Last Participated Round". Remaining: retrofit the 4 ID-based parents with the current-eval fallback (ties to WI-1 anchor), and the deferred Start Evaluation / round-1 anchor work.

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
| 5.5 | Round sub-tabs on Ratings | ✅ | Built + verified. `AS_GSS_CPS_evaluationRatingsTab_Parent` → per-round query + `AS_GSS_CPS_evaluationRatingsTab`. Content **paneLayout → columnsLayout** (panes not allowed in a tabItem). Current-eval fallback. View `_30fhDw` repointed manually. |
| 5.6 | Round sub-tabs on Consensus Reports | ✅ | Built + verified. `AS_GSS_CPS_consensusReportView_Parent` → per-round `AS_GSS_CPS_consensusReportView` (made embeddable: stripped 3 HCL frames + null-hardened status comparisons). View `_KJy-Pg` repointed manually; drop the `loggedInUser` arg (parent supplies it). |
| 5.7 | Round sub-tabs on Teams | ✅ | Built + verified. `AS_GSS_CPS_viewEvaluatorTeam_Parent` (inlined config) → per-round `AS_GSS_CPS_viewEvaluatorTeam` (made embeddable). View `_j9bz9g` repointed manually (MCP can't update this record type). |
| 5.7a | Round sub-tabs on Documents | ✅ | Built + verified. `AS_GSS_FM_evaluationDocumentsTab_Parent` → per-round `AS_GSS_FM_evaluationDocumentsTab` (made embeddable: stripped 1 HCL frame; inner Documents/Drafts tabs nest fine; no null-hardening needed). View `_wHo-OA` repointed manually. |
| 5.7b | Round sub-tabs on Task History | ✅ | Built + verified. `AS_GSS_TMG_FM_taskAuditActionHistory_Parent` → per-round `AS_GSS_TMG_FM_taskAuditActionHistory` (made embeddable: stripped 1 HCL frame; no null-hardening). View `_YpCKng` repointed manually. |
| 5.7c | Round sub-tabs on Tasks | ✅ | Built + verified. `AS_GSS_TMG_CPS_viewRecordTasks_Parent` → per-round query (SINGLE_OBJECT) + `AS_GSS_TMG_CPS_viewRecordTasks` (1 HCL frame stripped). Current-eval fallback. View `_WTzSLQ` repointed manually. |
| 5.7d | Round sub-tabs on Evaluation History | ✅ | Built + verified. `AS_GSS_FM_evaluationAuditHistory_Parent` → per-round 6 queries + `AS_GSS_FM_evaluationAuditHistory` (unwrapped to its grid rule). Lazy tab-load keeps queries per open round. Current-eval fallback. View `_JJzYag` repointed manually. |
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
| 7.6 | `AS_GSS_CPS_viewEvaluatorTeam_Parent` (interface) | ✅ | Round-aware Teams wrapper; inlined round-listing (env!features prevents an expression-rule config) |
| 7.7 | `AS_GSS_CPS_consensusReportView_Parent` (interface) | ✅ | Round-aware Consensus wrapper; parent supplies `loggedInUser()` |
| 7.8 | `AS_GSS_FM_evaluationDocumentsTab_Parent` (interface) | ✅ | Round-aware Documents wrapper; inner Documents/Drafts sub-tabs nest per round |
| 7.9 | `AS_GSS_TMG_FM_taskAuditActionHistory_Parent` (interface) | ✅ | Round-aware Task History wrapper |
| 7.10 | `AS_GSS_CPS_evaluationRatingsTab_Parent` (interface) | ✅ | Round-aware Ratings wrapper; per-round eval query; current-eval fallback |
| 7.11 | `AS_GSS_TMG_CPS_viewRecordTasks_Parent` (interface) | ✅ | Round-aware Checklist Items wrapper; per-round eval query; current-eval fallback |
| 7.12 | `AS_GSS_FM_evaluationAuditHistory_Parent` (interface) | ✅ | Round-aware Evaluation History wrapper; per-round 6 queries (lazy); current-eval fallback |

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
1. **Retrofit the 4 ID-based parents** (Teams/Consensus/Documents/Task History) with the **current-eval fallback** the 3 record-based parents use — so a leaf/round-clone record shows its own data instead of a blank "Round " tab. Ties to WI-1. Needs quick re-verification of each.
2. Review the Round-1 / Start Evaluation path (§4); settle the anchor question (plan WI-1): resolve anchor = `coalesce(parentEvalId, evaluationId)` and include the root as its own round tab (Round 1). This would replace the per-parent current-eval fallback with a proper family-wide round list.
3. Fix `maxSelections` on the vendor grid (§2.4) and sequence-based active-round (§7.3) + round sort (§5.3).
4. Build Setup New Round Step 3 + VM resubmission trigger (§2.5, §8.1).
5. i18n bundle keys for new literal labels (Vendors column, "Round " tab labels).
6. Update the stale description on `AS_GSS_UT_returnLastParticipatedRoundForVendors` (says "by vendorRefId"; actually keyed on uniqueEntityId).

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

### 2026-08-26 — Teams tab → round sub-tabs (SHIPPED + verified)
First round-sub-tab tab beyond Factors. Established the reusable per-tab wrapper pattern.

**Objects changed:**
- **Created** `AS_GSS_CPS_viewEvaluatorTeam_Parent` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42490`) — round-aware wrapper: `a!headerContentLayout` + `a!tabLayout`, one `a!tabItem` per round (label `"Round " & sequence`), contents = `AS_GSS_CPS_viewEvaluatorTeam(evaluationId: <round clone>)`. Round list via `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (same call Factors uses).
- **Modified** `AS_GSS_CPS_viewEvaluatorTeam` (`_a-0000e5da-a251-8000-9bbe-011c48011c48_1061788`) — removed its outer `AS_GSS_HCL_displayWrapperContents(...)` frame so it returns embeddable content (the inner `if(...)`). The parent now supplies the page frame.
- **Repointed (manually, by CO in Appian Designer)** the Teams record view `_j9bz9g` on `AS_GSS_Evaluation_RECORD` from `viewEvaluatorTeam(...)` → `viewEvaluatorTeam_Parent(...)`.

**Verification:** `testInterface` on the parent (eval 12) → `diagnostics.error = null`, `tabLayout` renders one tab per round with the team content embedded (empty-state shows correctly). CO confirmed working in the UI.

**Key learnings (critical for the remaining 6 tabs):**
1. **Tab content must be EMBEDDABLE.** `a!tabItem.contents` rejects a `HeaderContentLayout`. Tab interfaces that self-wrap in `AS_GSS_HCL_displayWrapperContents` or `a!headerContentLayout` (Teams, Documents, Tasks, Task History, Evaluation History likely) must have that outer frame removed first; the `_Parent` supplies ONE frame. `viewFactors` was already embeddable — that's why Factors worked out of the box.
2. **The round config CANNOT be a standalone expression rule** when its per-round content calls an interface using `env!features` (fails `createExpressionRule` validation: "Could not find variable 'env!features'"). **Inline the round-listing inside the `_Parent` interface** instead (interfaces have `env` context). This is the chosen pattern for all remaining tabs (deviates from Factors' separate `_UT_` config rule).
3. **`updateRecordTypeView` (and `getRecordType`) fail on `AS_GSS_Evaluation_RECORD`** with `None is not a valid RecordTypeSourceType` (service-backed record, no DB sourceType). **Repointing any Evaluation record view must be done manually in Appian Designer.** Build the `_Parent` via MCP, then hand the CO the one-line rule swap. `listRecordTypeViews` still works for reading.
4. **Safe-refactor check:** run `getObjectDependents` on the content interface first. `viewEvaluatorTeam` was used only by the Teams view → safe to make embeddable in place (no new `_Content` object needed).
5. **Consistency:** using the same `returnEvaluationRoundsForGivenEvaluation` as Factors means Teams shows the identical round-tab set. Blank "Round " labels for null-`sequence` rounds are a pre-existing data issue shared with Factors (tracker 5.3 / WI-1), not introduced here.

**Reusable recipe for the next tab:**
1. `getInterface` the tab's content interface; `getObjectDependents` to confirm scope.
2. If it self-wraps in HCL/headerContentLayout, strip the wrapper → embeddable; `updateInterface`.
3. Create `AS_GSS_CPS_<tab>_Parent(evaluationId)` = `headerContentLayout` + `tabLayout` + `forEach(rounds)` → `tabItem(label:"Round "&sequence, contents: <content interface>(roundEvalId))`. For RECORD-based tabs, wrap the content call in a per-round loader that queries the record(s) first.
4. `testInterface` the parent on eval 12.
5. Hand the CO the one-line view repoint for the record view urlStub.

### 2026-08-26 — Consensus Reports tab → round sub-tabs (SHIPPED + verified)
Second round-sub-tab beyond Factors. Reused the Teams recipe; surfaced two new wrinkles.

**Objects changed:**
- **Created** `AS_GSS_CPS_consensusReportView_Parent` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42504`) — round tabs, each `tabItem` embeds `AS_GSS_CPS_consensusReportView(evaluationId: <round clone>, loggedInUser: local!loggedInUser)`. Parent computes `loggedInUser()` once. Round list via `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` with the same `additionalFields` the Teams parent passes.
- **Modified** `AS_GSS_CPS_consensusReportView` (`_a-0000e721-640b-8000-9ba8-011c48011c48_40123`, v4) — (a) stripped **three** HCL frames: the empty-state `AS_GSS_HCL_displayWrapperContents` and BOTH the summary and detail `a!headerContentLayout` branches → returns embeddable content (empty-state interface / `{backLink, summary}` / `a!forEach` of factor sections). (b) **Null-hardened** the two status comparisons with `a!defaultValue(..., -1)` so a round whose evaluation is unresolved/null doesn't crash.
- **Repointed (manually, by CO)** the Consensus view `_KJy-Pg`: `consensusReportView(evaluationId, loggedInUser)` → `consensusReportView_Parent(evaluationId)` (loggedInUser arg dropped).

**Verification:** `testInterface` parent (eval 12) → `diagnostics.error = null`, tabLayout with per-round tabs, each embedding the Consensus content (empty-state card rendered). CO confirmed in UI.

**New learnings (in addition to the Teams learnings):**
6. **Content interfaces with >1 branch may have MULTIPLE frames to strip.** Consensus had 3 (one per `if` branch). Strip each branch's frame; a `tabItem`'s contents can be a plain list `{...}` or a `forEach` — it doesn't have to be a single component.
7. **Embeddability may require NULL-HARDENING.** When a tab is fed per-round evaluationIds, a round may resolve to a null evaluation (or the `a!defaultValue` empty round record). Comparisons like `status = cons!X` then throw "Cannot compare Null and Number (Integer)". Guard with `a!defaultValue(field, -1)`. Note `and()` does NOT short-circuit in SAIL, so ordering an `isNotBlank` first is not enough — the comparison itself must be null-safe.
8. **`updateInterface` validates with saved test inputs.** For null-unsafe interfaces, pass `testInputs` (e.g. `evaluationId=12`, `loggedInUser=loggedInUser()`) so validation runs against real data instead of nulls (mirrors `testInterface`). Without it, the save fails on the null comparison even though runtime is fine.
9. **`returnEvaluationRoundsForGivenEvaluation` requires a non-empty `additionalFields`** — an empty/absent one compiles to a `[""]` field ref and errors. Pass at least one valid field reference (copy the Teams/Factors parent's).

### 2026-08-26 — Documents tab → round sub-tabs (SHIPPED + verified)
Third round-sub-tab beyond Factors. Straightforward — one frame, no null-hardening.

**Objects changed:**
- **Created** `AS_GSS_FM_evaluationDocumentsTab_Parent` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42514`) — round tabs, each `tabItem` embeds `AS_GSS_FM_evaluationDocumentsTab(evaluationId: <round clone>)`.
- **Modified** `AS_GSS_FM_evaluationDocumentsTab` (`_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_951806`, v3) — stripped the single outer `AS_GSS_HCL_displayWrapperContents` frame → returns the inner `if(...)` directly. The interface's OWN Documents/Drafts `a!tabLayout` (shown when AI Doc Builder is enabled for CO users) nests fine inside the round `tabItem` (tabs-in-tabs is allowed).
- **Repointed (manually, by CO)** the Documents view `_wHo-OA`: `evaluationDocumentsTab(evaluationId)` → `evaluationDocumentsTab_Parent(evaluationId)`.

**Verification:** `testInterface` parent (eval 12) → `diagnostics.error = null`; per-round tab embeds the full Documents UI with real data (filters + docs grid showing "Amendment (1).pdf", download links, 2 docs). CO confirmed in UI.

**Learnings:**
10. **Nested tabs are fine.** A content interface that itself renders an `a!tabLayout` embeds cleanly inside a round `tabItem` (Documents' inner Documents/Drafts tabs). No special handling.
11. **No null-hardening was needed here** — unlike Consensus. Whether it's required depends on the content interface's own null-tolerance; check per tab rather than assuming.

### 2026-08-26 — Task History tab → round sub-tabs (SHIPPED + verified)
Fourth round-sub-tab; last of the ID-based tabs.

**Objects changed:**
- **Created** `AS_GSS_TMG_FM_taskAuditActionHistory_Parent` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42524`).
- **Modified** `AS_GSS_TMG_FM_taskAuditActionHistory` (`_a-0000e2cd-bc96-8000-9ba2-011c48011c48_137309-tmg-am-am`, v3) — stripped the single outer `AS_GSS_HCL_displayWrapperContents` frame (wrapped a `columnsLayout`) → embeddable. No null-hardening needed.
- **Repointed (manually, by CO)** the Task History view `_YpCKng`.

**Verification:** `testInterface` parent (eval 12) → `diagnostics.error = null`; per-round tab embeds the full audit view (Phase History left panel, audit trail with real entries, filters, pagination "1-5 of 16"). CO confirmed in UI.

**Milestone:** all 4 ID-based round sub-tabs done (Teams, Consensus, Documents, Task History), plus Factors. Remaining: the 3 record-based tabs (Ratings, Tasks, Evaluation History) whose views pass queried collections rather than an evaluationId — the parent must run the same queries per round (inlined in the `tabItem` contents; `a!tabLayout` loads inactive tabs lazily, so the heavy Evaluation-History queries only run when a round tab is opened).

### 2026-08-26 — Ratings + Checklist Items + Evaluation History → round sub-tabs (SHIPPED + verified)
The 3 **record-based** tabs, done in one session. **This completes all 8 round sub-tabs.**

**Objects changed:**
- **Ratings:** created `AS_GSS_CPS_evaluationRatingsTab_Parent` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42562`); modified `AS_GSS_CPS_evaluationRatingsTab` (`_a-0000efa1-370d-8000-9ea1-011c48011c48_19633560`, v3) — stripped the `a!headerContentLayout` frame AND **converted its `a!paneLayout` (2 panes) to a 2-column `a!columnsLayout`** (NARROW_PLUS + AUTO), because a `paneLayout` is rejected inside a `tabItem`. Per-round content: `evaluationRatingsTab(evaluation: getEvaluationByIdentifier(roundEvalId))`.
- **Checklist Items / Tasks:** created `AS_GSS_TMG_CPS_viewRecordTasks_Parent` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42542`); modified `AS_GSS_TMG_CPS_viewRecordTasks` (`_a-0000e2cd-bc96-8000-9ba2-011c48011c48_57203-tmg-am-am`, v2) — stripped 1 HCL frame. Per-round content: `viewRecordTasks(evaluation: getEvaluation(SINGLE_OBJECT, roundEvalId))`. (View passes OBJECT_ARRAY but the input is single; SINGLE_OBJECT is the correct, unambiguous form.)
- **Evaluation History:** created `AS_GSS_FM_evaluationAuditHistory_Parent` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42552`); modified `AS_GSS_FM_evaluationAuditHistory` (`_a-0000e5da-a251-8000-9bbe-011c48011c48_998301`, v2) — the whole interface was just an HCL wrapper around `AS_GSS_GRD_evaluationChangesAudit(...)`; unwrapped to return that grid rule directly. Per-round content: the 6 audit queries (evaluation SINGLE_OBJECT + phases/vendors/criteria/teams/docs OBJECT_ARRAY, getActiveAndInactive/fetchAll true).
- **Repointed (manually, by CO)** views `_30fhDw` (Ratings), `_WTzSLQ` (Checklist Items), `_JJzYag` (Evaluation History) — each simplified to a single `evaluationId` arg (parent runs the queries).

**Verification:** `testInterface` all three on eval 12 → `diagnostics.error = null`. Ratings shows the 2-column factor/legend/vendor-ratings layout; Eval History shows the audit grid with 4 real rows ("Duplicated the evaluation…", added factors/phases/teams); Tasks shows the checklist status cards + grid. CO confirmed all three in the UI.

**New learnings (critical):**
12. **`returnEvaluationRoundsForGivenEvaluation(id)` returns children only** (`parentEvalId = id`). For a **leaf/round-clone** eval (e.g. eval 12), it returns **`[]`**. The old `a!defaultValue(rounds, default: emptyRoundRecord())` then yields a round with **null evaluationId** → content is called with a null eval. The 4 ID-based content interfaces tolerated null (blank tab); Ratings and Eval History **crash** on it (`queryFilter "=" null`, and a grid "data may not contain fv!pagingInfo" on empty arrays). **Fix pattern (record-based parents):** compute `local!roundTabs` = `if(isNullOrEmpty(roundsRaw), {a!map(evalId: ri!evaluationId, seq: null)}, forEach → a!map(evalId, seq))`, i.e. **fall back to the CURRENT evaluation** (a real, non-null eval) and drive the forEach off plain maps (`fv!item.evalId` / `fv!item.seq`) instead of record field refs. Recommended to retrofit the 4 ID-based parents with the same fallback (ties to WI-1).
13. **`a!paneLayout` is NOT allowed inside `a!tabItem`** (same as `headerContentLayout`). Convert panes → `a!columnsLayout`/`a!columnLayout` (drop the pane-only `accessibilityText`; keep `width`). Trade-off: loses the panes' independent scroll, acceptable inside a tab.
14. **Test-input cardinality matters.** For a single-typed record input, a testInput expression returning an OBJECT_ARRAY makes `ri!x.field` a **list**, breaking downstream `=` filters (`TypedValue[it=101,v={12}]`). Use SINGLE_OBJECT test values for single inputs. (When a real rule! call feeds a declared-single input, Appian coerces list→single; raw testInputs do not.)
15. **`a!tabLayout` loads inactive tabs lazily** — the heavy per-round Evaluation-History queries (6 each) run only for the open round, so cost scales with interaction, not round count.

---

## Session Log — 2026-08-26 — WI-1 Start Evaluation (Best Value) build

**Built + verified (MCP):**
- Interface `AS_GSS_FM_startEvaluationBestValue` (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42569`) — single-screen modal (round name/start/duration/due + factor multi-select + live counter). testInterface clean on eval 12. **PO-verified in UI.** Team/Evaluators on factor card deferred (relationship join empty in harness); shows factor name + number + due date.
- Process model `AS GSS Start Evaluation Best Value` (`0000f04b-68ab-8000-fbf5-7f0000014e7a`) — 16 nodes, validates clean. Clone of Start Eval PM minus LPTA + new **Scope Selected Factors** node. `selectedFactorIds` PV added; start form wired.
- Anchor rule `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` (v4) — family resolution `coalesce(parentEvalId, evaluationId)` → anchor + children rounds. Verified in-context via Teams parent on eval 6 (diagnostics.error null).

**Tooling deviations (Appian/MCP limits):**
- `start-process-4` nodes uncreatable via MCP (`acSchemaId is null` NPE) → replaced Sync-GCW + Reqt-Extraction with async SUB_PROC nodes (same PMs, accept `evaluationId`).
- Bulk `updateProcessModel(nodes)` hit same NPE → built graph incrementally with `createProcessModelNode`.

**Manual (MCP blocked on `AS_GSS_Evaluation_RECORD` — `None is not a valid RecordTypeSourceType`):**
- CO to create action `startEvaluationBestValue` (PM above; MEDIUM_PLUS/TALL; visibility = SETTING_UP & Best Value; contextExpr = existing + `selectedFactorIds:{}`) and guard the existing `startEvaluation` action with `method <> BEST_VALUE`. Full copy-paste spec in `03_AGENT_ONBOARDING.md` §10.45.

**Step 5 (tab fallback):** no change — current-eval fallback is compatible with the anchor change and still handles non-round evals.

**Next:** CO creates the two actions per spec → end-to-end UI test on a fresh Best Value eval (Round-1 row seq=1, scoped tasks/ratings/consensus, Round 1 tab appears).

### Addendum — same session — vendor documents on new round

- **`AS_GSS_UT_duplicateEvaluationForNewRound`** (`_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42160`, **v9**): copies each carried vendor's **documents** into the new round. **Queries the source evaluation's vendor documents once** (`local!sourceVendorDocuments` via `AS_CO_UT_queryRecord`: `evaluationId` `f1f3c4f7` = source, `isDeleted` `f0a0bf35` = false, `vendorId` `7771b188` operator "not null") and maps per vendor inside the vendor `updateRecordsByModelRecord`: the `documents` relationship (`f017ee11`) = `a!forEach(items: index(local!sourceVendorDocuments, wherecontains(tointeger(sourceVendorId `757685e2`), tointeger(a!defaultValue(sourceVendorDocuments.vendorId, {}))), {}), expression: updateRecordsByModelRecord(nulled keys…))`. Each doc copied with **nulled** `evaluationDocumentId`(PK), `vendorId`(cascade), `evaluationId`, `consensusId`, `criteriaId`, `taskId`; **preserved** `appianDocId` (same file), `documentName/Description`, `fileType`, `docType`, `documentTemplate`, `documentSubType`, `version`, `isPriceExtractionSelected`, `sourceApplicationId`, `isDeleted`; created/modified reset to initiator/now.
- **Self-contained** — no longer depends on the template vendor loading the `documents` relationship (earlier v8 read `fv!item[…documents]`; replaced with the query+map above because those documents are not passed in with the vendor).
- **Note:** copied docs have `evaluationId = null`; they link to the eval via the new `vendorId` (vendor→documents). Fine for per-vendor access; flag if any query fetches vendor docs by `evaluationId`.
- EvaluationDocument field UUIDs: evaluationDocumentId `f7ef236a-fba6-483a-80ae-f15adb0c05eb` · appianDocId `fb650755-eca1-4f41-9d8e-e15664ef5ee2` · evaluationId `f1f3c4f7-e366-45f7-a3ce-987fdc61a897` · consensusId `5f719599-8605-46b4-bd94-537710f6c3f4` · criteriaId `93fca4ae-85e4-4d6c-99b0-7b52cfd10f84` · vendorId `7771b188-06be-43e5-89de-953e225f763a` · taskId `41c000b4-660c-4c3f-b2e4-419ce51a09d2` · docType `41df7759-4fed-416d-81ee-4813ca9d95c6`.

### Tooling limitations discovered this session (important for next agent)
- **`AS_GSS_Evaluation_RECORD` (`4db4a62e`) mutations fail** via MCP: `getRecordType`, `updateRecordTypeView`, **and `addRecordTypeAction`/`updateRecordTypeAction`** all return `None is not a valid RecordTypeSourceType`. `listRecordTypeActions` works (read-only). ⇒ record actions + view repoints on this RT are **manual in Designer**.
- **`start-process-4` (Start Process) nodes cannot be created** via `createProcessModelNode`/`updateProcessModel` — platform NPE `Cannot invoke "java.lang.Long.intValue()" because "acSchemaId" is null` (even with no params). Workaround: use async `SUB_PROC` (`internal.38`) to the same PM if it exposes the needed params.
- **Bulk `updateProcessModel(nodes=[...])`** with many activity nodes also hit the `acSchemaId` NPE. Workaround: create the PM shell, set PVs+startForm first (separate call), then add nodes one-by-one with `createProcessModelNode` (backward from End so targets exist), then rewire Start.
- **PVs must exist before nodes reference them** — set `processVariables` before adding nodes with `pv!` refs (else `Variable(s) not found`).
- **`a!formLayout` rejects `skipAutoFocus`** (only the `_25r1` variant accepts it).
- **XOR conditions must be null-safe** at validation: `field = true()` fails "Cannot compare Null and Boolean" — wrap with `a!defaultValue(field, false())`.
- **`AS_CO_UT_filterCdtByField(field:"parentCriteriaId")` returns empty against `AS_GSS_QR_getCriteria` output** (UUID-keyed record maps, not named CDT). Use a UUID-based `wherecontains(true, a!forEach(... isnull(...parentCriteriaId)))` filter instead. (The `continueSetup` contexts use `filterCdtByField` on `AS_GSS_QE_getEvaluationCriteria`, which returns named CDT — that works.)
- **`testInterface`/`testRule` `inputs` maps pass values literally** (a record-typed value passed as a string errors `Could not cast from Text`). Prefer saved default test inputs (set via create/update `testInputs`) and call with no `inputs`.
- **Read-tool display quirk:** node/rule expressions come back with a spurious `pv!`/`=` prefix (e.g. `pv!rule!...`, `pv!pv!evaluation`) — this is cosmetic; the stored expression is correct.

## Session Log — 2026-08-26 (WI-2: Start Round)

Built **Start Round** — starting an already-created child round, reusing the existing Start Evaluation process without creating a new round.

- **`AS_GSS_FM_startRound`** (`_a-0000f04b-38cd-8000-9baa-011c48011c48_42738`) — p8 confirm dialog; dynamic round number + included-vendor count; sets INPROGRESS + userAction on Start. Query logic verified via throwaway integer-input probe (eval 12→Round 3/1 vendor; eval 13→Round 1/2 vendors) — `testInterface` can't inject a typed eval so it renders generic in-harness (`AS_CO_UT_queryRecord` drops empty-value filters).
- **`AS GSS Start Round`** PM (`0000f04b-9451-8000-fc0b-7f0000014e7a`) — thin wrapper: Start (start form = new form) → SUB_PROC `internal.38` → `0002ecdd…` (sync, chained, forwards 6 params) → End. Reuses the entire Start Evaluation flow; no round creation. `validateDesignObject` clean.
- **`startRound` action** (CO-created, `84ac0b39-bf4e-43ba-bbb3-050dd2e5d9f4`) → wrapper PM; visibility SETTING_UP + BestValue + `isNotBlank(parentEvalId)`; contextExpr = existing `startEvaluation` (no selectedFactorIds). **"Start Evaluation (BV)"** guarded with `isBlank(parentEvalId)` (root only).
- **`AS_GSS_SEC_rounds`** (`…42270` v7) — added `startRound` recordActionItem to each round card's action field (keyed by round `evaluationId`). Validates clean.

**Design note:** a record action's dialog is its PM's single start form, so reusing `0002ecdd…` *and* showing a new form required the wrapper-PM-calls-subprocess pattern. Remaining: end-to-end UI test (start a fully set-up child round → INPROGRESS, scoped tasks/ratings/consensus generated, no new EvaluationRound row).

## Session Log — 2026-08-26 (WI-3: Complete Round + Setup New Round gating)

- **`AS GSS Complete Round`** PM (`0000f04b-add3-8000-fc11-7f0000014e7a`) — no start form; Start → SUB_PROC → `0004e60d…` (Mark Evaluation as Complete) with evaluation pre-set to COMPLETE + `userAction=SUBMIT` → End. Backend-only completion, reuses original write/GCW/audit, original untouched. Validates clean.
- **`completeRound` action** (CO-created, `853cb2b7-5587-48fa-8af4-15d6206a7421`) → wrapper PM; contextExpr passes `evaluation`; visibility = `getRelatedActionVisibilityForMarkEvaluationAsComplete`.
- **`AS_GSS_SEC_rounds`** (v9): actions rebuilt as `a!flatten({ startRound (latest+SetUp), completeRound (INPROGRESS), edit })`. Verified render on eval 6 (Round 03 shows Start Round+Edit; no INPROGRESS round so Complete Round absent), diagnostics.error null.
- **`setupNewRound` visibility** (MANUAL, CO applied): visible only when ≥1 round exists and none is SETTING_UP/INPROGRESS (all COMPLETE) — corrected from the initial "any round complete" which wrongly showed while a later round was active. Optional `count(rounds) < 5` cap offered.

Lifecycle now: Round INPROGRESS → Complete Round → COMPLETE → Setup New Round appears → new round SETTING_UP → Start Round → INPROGRESS → … End-to-end UI test pending.

## Session Log — 2026-08-27 (Cross-app integration research kickoff)

Mapped GSS's external integration surface (verified via MCP) as prep for impact analysis of multi-round.
- **7 connected systems, 15 integrations, 5 Web APIs.** Detailed inventory + VM contract in new doc **`07_CROSS_APP_IMPACT_RESEARCH.md`**.
- **VM (Vendor Management)** — CS `_a-0000ed77…_15308175`. GSS→VM: OpportunityDetails (`getOppDetailsForEval?noticeId`), VendorIdentifierDetails (`getVendorIdentifierDetails?noticeId&isVendorLinked`), getVendorsAndDocuments (`getVendorDetailsForEvaluation?solicitationNumber&startIndex&batchSize&vendorId`), getProposalDocument (`downloadVmDocument?appianDocId`, binary), updateProposalVendorAction (POST `{solicitationPiid, vendorId[], actionType}`). VM→GSS Web APIs: `getEvaluationDetailsForVm` (eval details + site URL), `vendor-proposal-action` (proposal action inbound).
- **GCW (Contract Writing)** — `evaluationList` Web API + `SyncEvaluationStatusList` integration push evaluation statuses. **Flagged HIGH impact**: multi-round emits N evaluations per solicitation, so status sync + PIID→evaluation resolution likely need round-awareness.
- Other: Source Selection (external doc fetch), GSM/DRM (vendor reconciliation), SAM.gov, SharePoint/MS Graph, Azure OpenAI.
- **Tooling note:** `getWebApi` returns `expression: null` in this env — Web API bodies must be traced via the expression rules they call.

**Next phase = analysis only** (do not change integrations). Findings log + per-integration hypotheses seeded in `07_…` §4/§6. Docs updated: 03 onboarding (§2 table, §7 current state, §10.47), 07 created, 01 design (integrations note).

Also consolidated prior build progress into onboarding §7: WI-1 (Start Evaluation as Round 1), WI-2 (Start Round), WI-3 (Complete Round + Setup New Round gating), rounds card v9, and `AS_GSS_UT_returnLatestChildEvaluationInSetupForGivenEvaluation` (`…43812`).

## Session Log — 2026-08-27 (VM↔GSS integration Phase 1 — current state, both sides)

VM is now deployed in this env (`AS VM Full Application` `_a-0000e79a-fc04-8000-9bf4-011c48011c48_2088050`), so both sides of the integration were read directly. Delivered a complete current-state mapping in **`artifacts/01_VM_GSS_CURRENT_STATE_INTEGRATION.md`** (+ `artifacts/README.md`). **Paused for user review before Phase 2 (multi-round impact).**

Traced all 7 flows end-to-end (trigger → request → handler → data written):
- GSS→VM (5): OpportunityDetails, VendorIdentifier, **getVendorsAndDocuments** (writes GSS EvaluationVendor/Address/BusinessType/Document, sourceApplicationId=VM), downloadVmDocument (binary), **updateProposalVendorAction** (POST; flips VM `Proposal.isEvaluationLinked`, trigger PM `0002ed96`).
- VM→GSS (2): **getEvaluationDetailsForVm** (VM opp summary shows GSS status+link), **vendor-proposal-action** (POST; GSS writes `VendorUpdates`, trigger PM `0002ed86`).

Key mechanics documented: join key `Opportunity.noticeId == Evaluation.evaluationNumber`; vendor identity `externalVendorId=VM vendorId` + UEI; dedup via `Proposal.isEvaluationLinked`; sealed-bid gating; two master toggles. Phase-2 seams listed in doc 01 §9 (esp. PIID→evaluation now 1:N under multi-round; per-opportunity dedup vs per-round re-include). Full object/UUID evidence appendix in §10.

## Session Log — 2026-08-27 (VM↔GSS Phase 2 — multi-round impact)

Delivered **`artifacts/02_VM_GSS_MULTIROUND_IMPACT.md`** (per-flow breaks/works/risk + fixes), grounded in verified mechanics.

**Root cause:** `evaluationNumber` is overloaded as both display label AND the VM join key (`Evaluation.evaluationNumber` ↔ `Opportunity.noticeId`). `duplicateEvaluationForNewRound` (v9) rewrites clones to `"<PIID> Round N"`, so only the **root (Round 1)** keeps the real PIID. Data-confirmed on the test family (root 16 `26082602`; clones 17/18/19 `26082602 Round 2/3/4`).

**Per-flow verdict:**
- ✅ **D (download):** works across all rounds — carried docs retain the same VM `appianDocId` (as intended).
- ✅ **B/C (vendor pulls):** work — Round-1 activity on the root; later rounds carry vendors internally (no VM re-fetch).
- ⚠️ **A (opportunity details):** blank on round-clone views if the clone's number is passed (Med).
- ❌ **E (push add/remove):** breaks from clones (VM opp lookup on `"PIID Round N"` fails) + between-round down-selects never call VM at all → VM `isEvaluationLinked` reflects only Round-1 membership (High).
- ❌ **F (VM reads GSS status):** always returns Round-1 status + Round-1 record URL, stale once advanced (High).
- ❌ **G (proposal action → VendorUpdates):** always attaches to the Round-1 evaluation + Round-1 vendor row, not the active round (High).
- Identity (`externalVendorId`/UEI) + provenance (`sourceApplicationId=VM`) carry fine; toggles/sealed-bid unaffected.

**Top fix:** decouple the VM join key from the label (keep raw PIID on every round), then add round-selection logic to F/G and decide the between-round→VM sync question. Failures are **silent** (no user-visible error), which raises priority. Open confirmations listed in doc §6.

## Session Log — 2026-08-27 (GCW↔GSS Phase 1 — current state, both sides)

GCW now installed (`AS GCW Full Application` `_a-0000e85f-3e2e-8000-9bfd-011c48011c48_2767135`). Delivered **`artifacts/03_GCW_GSS_CURRENT_STATE_INTEGRATION.md`**. **Paused for review before Phase 2 (GCW multi-round impact → `04_…`).**

**Mechanism (KEY difference from VM):** GCW↔GSS uses **APPREF→ENTRYPOINT**, not HTTP. Each caller has an `AS_<APP>_APPREF_<TARGET>_…` wrapper that resolves the target's `AS_<TARGET>_…_ENTRYPOINT_…` rule **by name** via `AS_FRM_getRuleReferenceOrNoOp` (`refreshAlways:true`) and executes it in-process; if the target app isn't installed it's a graceful no-op (`ifNull_default:{}`). Same-environment, in-JVM, no connected system/API key. Entrypoint types: GETDATA (read), DISPLAY (UI fragment), RECORDACTION (action link), STARTPROCESS (returns {processModel,params} to start a process in the target = the write path).

**Inventory:** 13 GSS→GCW APPREFs, 9 GCW→GSS APPREFs (all listed with UUIDs in doc 03 §2).

**Lifecycle:** GCW solicitation → [createEvaluationFromSolicitation] → GSS Evaluation (evaluationNumber=PIID, sourceApplication=AM); GSS → [updateEvalSolicMapping]+[folder security] → GCW; status changes → [syncEvalStatusInGcw] → GCW keeps synced status copy; GCW summary ← [getEvaluationDetailsBySolicPiid/relatedEvaluationDetails]; completion → [getWinningVendorAndBasicInformation] → [create(Single/Multiple)AwardsFromEvaluation] → GCW Awards.

**Multi-round seams (Phase 2):** (1) `getEvaluationDetailsBySolicPiid_V1` matches evaluationNumber=PIID + sourceApplication=AM → root-only (clones are "PIID Round N" + sourceApplication=GSS) → GCW shows Round-1 status regardless of active round; (2) status sync per evaluationId, `evaluationList` has no parentEvalId filter; (3) winning-vendor/award creation takes evaluationIds[] — must be the final round; (4) eval↔solic map created for root only; (5) two sync mechanisms (APPREF vs HTTP integration wired to PM 0006ef1c) — resolve which is active.

## Session Log — 2026-08-27 (GCW↔GSS Phase 2 — multi-round impact)

Delivered **`artifacts/04_GCW_GSS_MULTIROUND_IMPACT.md`**.

**Root cause = two identity models:** (a) PIID-keyed reads (`getEvaluationDetailsBySolicPiid_V1`: evaluationNumber=PIID AND sourceApplication=AM) → **root-only/stale** (clones are "PIID Round N" + sourceApplication=GSS); (b) `evaluationId`-keyed reads/writes (status sync, winning-vendors, vendor-details, awards) operate on exactly the ids passed — `constructEvalVendorAndDocsForMultipleEvalIds` uses `WHERE evaluationId IN (...)` with **no family expansion** — and GCW's eval↔solic mapping caches the **root** id.

**Per-flow:** ✅ B(createEval root), 7(folder security), solicitation reads (2/5/6/13), ref-data/toggles. ⚠️ 4(mapping root-only), 10(status sync accumulates one row per round w/ mangled names, no parent context; contradicts C), F(single id → wrong round if root), 9(award-links scope). ❌ HIGH: C(GCW summary shows Round-1 status+link forever), H+8/11(winning-vendors/award correct ONLY if final round's evaluationId used, else Round-1 awardees — wrong). Identity (gsmVendorRefId/externalVendorId/UEI) + appianDocId carry fine → gap is round selection, not identity. Failures silent. Both sync paths (APPREF+HTTP) accumulate rounds.

**Top fix:** ensure award/winning-vendor creation targets the FINAL round's evaluationId (award correctness); then family-aware PIID summary (C) + decide status-sync semantics (10). Open confirmations (doc §6): which evaluationId GCW passes to award/H/F (root mapping vs GSS record action from awardees-selected round); whether GCW's synced list is meant to be plural.

**All 4 integration artifacts (VM 01/02, GCW 03/04) complete.** Remaining suite integrations (GSM/DRM, SAM, SharePoint, OpenAI) not yet mapped (see 07).

## Session Log — 2026-08-27 (PO clarification: hidden-child/parent-only model + reassessment)

**Major design clarification from PO** (documented as authoritative in `01_…` §1a; principle added to onboarding §1):
- **Parent evaluation is the ONLY user-facing evaluation.** Round clones are **backend-only, hidden from users** (technical records for per-round task/rating/consensus generation). Users only ever create/see "rounds" within the parent workspace.
- **Vendor addition only on the parent** (subsequent rounds just select from already-added vendors). **Select Awardees + award creation only on the parent.**
- Canonical workflow captured: Create Evaluation → Start Evaluation (Round 1 on parent) → complete tasks → **Complete Factor** → (Select Awardees | Start New Round) → Create New Round (child, Setup) → editable setup → **Start Round** (In Progress) → complete tasks → **Complete Round** → back on parent (Select Awardees | Create New Round) → … until final awardee.

**Reassessment of integration impact (both docs updated with an authoritative §1b):**
- **VM:** A/B/C/D/E/F = **Not an issue** (parent is the identity VM sees/links; vendor push only from parent; showing parent is intended). **Only Flow G (vendor proposal action) needs a minor change** — resolve the latest round's child evaluation and match the vendor there so the active round reflects the update.
- **GCW:** B/4/7/C/H/8/11/F/9 + reads/toggles = **Not an issue** (parent-only display + parent-only awardee/award = correct). **Flow 10 (status sync) = optional low-sev review** — Start/Complete Round run on child evals and trigger the GCW sync, so confirm child-round statuses are suppressed/redirected to the parent (avoid leaking hidden-child rows to GCW).

Net: multi-round is integration-safe under the parent-only model; **1 minor VM change (Flow G)** + **1 optional GCW hygiene item (Flow 10)**. Pre-clarification structural matrices retained in each doc §2 for the mechanism record.

## Session Log — 2026-08-27 (Implemented VM Flow G; documented GCW Flow 10 decision)

- **VM Flow G — IMPLEMENTED.** `AS_GSS_mapVendorUpdatesToRecord` (`_a-0000ed8a-02db-8000-9dfc-011c48011c48_15443462`, now v2): after matching the parent by `evaluationNumber = noticeId`, it resolves the family's **latest round** (`AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation`, max `sequence` → that round's `evaluationId`) and targets the vendor query + writes the `VendorUpdates` against the **latest round's child `evaluationId`**; falls back to the parent when no round rows exist. `evaluationNumber` still holds the solicitation PIID. Fix for the `wherecontains` type mismatch: `tointeger(max(...))`. Verified via `testRule` on `26082602` → resolved to latest round eval **21** (not root 16), `error: null`. Doc 02 §1b updated to "Implemented".
- **GCW Flow 10 — DECISION DOCUMENTED (implement later).** Doc 04 §1b now states: **GCW status syncs should be skipped for child evaluations** (only the parent's status should sync; Start Round/Complete Round must not push child statuses). Deferred to a later change.

## Session Log — 2026-08-27 (Factor→document mapping carry-forward for new rounds)

Implemented the "criteria pre-write" solution to carry `AS_GSS_FactorDocumentMapping` rows into new rounds.
- **Built + verified rule** `AS_GSS_UT_constructFactorDocumentMappingsForNewRound` (`_a-0000f04c-8a45-8000-9bac-011c48011c48_83697`): correlates factor by `factorNumber` + document by `appianDocId`, copies active source mappings → new `FactorDocumentMapping` rows. `testRule` (new round 21, source 16) → 3 mappings (doc 52 → factors 43/44/45), `error:null`. Uses the criteria/doc ids already persisted by PM `000bf04a` node 6 "Write Evaluation".
- **Remaining MANUAL step (Designer, MCP-blocked by lane):** add a "Write Records and Related Records" node after node 6 in PM `000bf04a` (lane System), Records = the rule call, Version 6, PauseOnError true, CaptureEvents false. Full spec in onboarding §10.50.
- Decision on `isActive`: copy only currently-active source mappings; create new ones active. (Confirm if reactivating all was intended.)
