# GSS Multi-Round Evaluations — Progress Tracker

> Update this file at the end of every working session. Keep the **Session Log** append-only.
> Companion docs: `01_FEATURE_AND_TECHNICAL_DESIGN.md`, `03_AGENT_ONBOARDING.md`.

**Last updated:** 2026-08-26
**Overall status:** 🟡 Foundation in place. Shipped round sub-tabs: Factors, **Teams**, **Consensus Reports**, **Documents**. Plus Vendors → "Last Participated Round". Remaining round sub-tabs: Task History, Ratings, Tasks, Evaluation History.

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
| 5.6 | Round sub-tabs on Consensus Reports | ✅ | Built + verified. `AS_GSS_CPS_consensusReportView_Parent` → per-round `AS_GSS_CPS_consensusReportView` (made embeddable: stripped 3 HCL frames + null-hardened status comparisons). View `_KJy-Pg` repointed manually; drop the `loggedInUser` arg (parent supplies it). |
| 5.7 | Round sub-tabs on Teams | ✅ | Built + verified. `AS_GSS_CPS_viewEvaluatorTeam_Parent` (inlined config) → per-round `AS_GSS_CPS_viewEvaluatorTeam` (made embeddable). View `_j9bz9g` repointed manually (MCP can't update this record type). |
| 5.7a | Round sub-tabs on Documents | ✅ | Built + verified. `AS_GSS_FM_evaluationDocumentsTab_Parent` → per-round `AS_GSS_FM_evaluationDocumentsTab` (made embeddable: stripped 1 HCL frame; inner Documents/Drafts tabs nest fine; no null-hardening needed). View `_wHo-OA` repointed manually. |
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
| 7.6 | `AS_GSS_CPS_viewEvaluatorTeam_Parent` (interface) | ✅ | Round-aware Teams wrapper; inlined round-listing (env!features prevents an expression-rule config) |
| 7.7 | `AS_GSS_CPS_consensusReportView_Parent` (interface) | ✅ | Round-aware Consensus wrapper; parent supplies `loggedInUser()` |
| 7.8 | `AS_GSS_FM_evaluationDocumentsTab_Parent` (interface) | ✅ | Round-aware Documents wrapper; inner Documents/Drafts sub-tabs nest per round |

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
1. Continue round sub-tabs using the **established pattern** (embeddable content interface + `_Parent` wrapper): next ID-based — **Task History** (WI-6b). Then record-based — **Ratings** (WI-4), **Tasks** (WI-6c), **Evaluation History** (WI-6d).
   - ⚠️ Each `_Parent` wrapper is created via MCP, but **repointing the record view must be done manually in Appian Designer** — the `updateRecordTypeView` MCP tool errors on this record type (`None is not a valid RecordTypeSourceType`). Provide the CO the one-line rule swap.
   - ⚠️ Check whether each tab's content interface self-wraps in `AS_GSS_HCL_displayWrapperContents`/`headerContentLayout`; if so, make it embeddable (as done for Teams) before nesting in a tab.
2. Review the Round-1 / Start Evaluation path (§4); settle the anchor question (plan WI-1). Anchor helper pattern proven (Vendors learning #3).
3. Fix `maxSelections` on the vendor grid (§2.4) and sequence-based active-round (§7.3) + round sort (§5.3).
4. Build Setup New Round Step 3 + VM resubmission trigger (§2.5, §8.1).
5. i18n bundle keys for new literal labels (Vendors column, round tab labels if needed).

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
