# Agent Onboarding — GSS Multi-Round Evaluations

> Read this first if you are a new agent picking up this work. It tells you **what we're building, where everything lives, how to interact with it, and the conventions to follow.**

---

## 1. The 60-second summary

We are adding **Multi-Round Evaluations** to Appian **Government Source Selection (GSS)**. A Contracting Officer can run one Best Value evaluation as **multiple sequential rounds** (down-selects), narrowing the vendor pool each round, instead of creating a new evaluation per phase.

**The central design idea:** *a round is a full clone of the Evaluation record.* Each clone links back to the round‑1 root via `parentEvalId`, and a new `AS_GSS_EvaluationRound_SYNCEDRECORD` table stores round metadata + sequence. This gives per-round Ratings/Consensus/Teams/Factors for free.

Full details: **`01_FEATURE_AND_TECHNICAL_DESIGN.md`**. Live status: **`02_PROGRESS_TRACKER.md`**.

---

## 2. Where everything lives

| Thing | Location |
| :--- | :--- |
| Spec (research + requirements + Q&A) | `GSS_ Multi Round Evaluations.md` (this folder) |
| Mockups | `GSS - Multiround Evaluation (1).pdf` (this folder) · [Figma](https://www.figma.com/deck/U9rGBTKVtpnxLOTNjQmvi8) |
| Design doc | `01_FEATURE_AND_TECHNICAL_DESIGN.md` |
| Progress tracker | `02_PROGRESS_TRACKER.md` |
| This onboarding | `03_AGENT_ONBOARDING.md` |
| **The actual code (Appian objects)** | Appian **AS GSS Full Application**, accessed via the **`lcp` MCP server** — there is **no local git repo** for these objects |

**Environment:** `gam-gss-32-innovate.appianpreview.com`
**Application:** AS GSS Full Application · UUID `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`
**Custom-objects app** (for customizations that deploy to higher envs): GSS Custom Objects · UUID `_a-0000f044-2075-8000-9ba6-011c48011c48_41633` (currently empty)

---

## 3. How to interact with the code (lcp MCP)

You do **not** edit local `.sail` files for these objects. You read/modify Appian design objects through the `lcp` MCP tools. Common ones:

- **Discover:** `listApplicationObjects`, `listInterfaces`, `listExpressionRules`, `listRecordTypes` (all take `appUuid`; support a `query` filter).
- **Read:** `getInterface` / `getExpressionRule` (pass `expressionFilePath` to dump the SAIL to a local temp file for reading), `getRecordType`, `listRecordTypeFields`, `listRecordTypeRelationships`.
- **Write:** `updateInterface` / `updateExpressionRule` (edit the temp `.sail` file, then pass the same `expressionFilePath` back), `createInterface`, `createExpressionRule`, `addRecordTypeField`, `addRecordTypeRelationship`, etc.
- **Verify:** `validateDesignObject`, `validateExpression`, `testInterface`, `testRule`, `getObjectDependents`.

**Workflow tip:** when reading a rule/interface, dump it to `/tmp/gss_review/<name>.sail`, read it, and delete the temp dir when done. Always `validateDesignObject` after a change.

---

## 4. Naming conventions (follow these)

GSS objects use prefixes that signal type/layer:
- `AS_GSS_` — GSS solution namespace. `AS_CO_` / `AS_GSS_CO_` — shared/common utilities.
- `_FM_` form/modal interface · `_SEC_` section interface · `_CP_`/`_CPS_` component/component-service interface · `_GRD_` grid.
- `_QR_` query rule · `_UT_` utility rule · `_BL_` business-logic rule.
- `_SYNCEDRECORD` — a synced record type (DB-backed). `_RECORD` — the record object exposing actions/views.
- `cons!AS_GSS_…` constants (status ids, hex colors, enums).

When creating new objects, **match the existing pattern** rather than inventing a new one.

---

## 5. Key objects & UUIDs (quick reference)

**New (this feature):**
| Object | UUID |
| :--- | :--- |
| `AS_GSS_EvaluationRound_SYNCEDRECORD` | `931e8145-3f77-4270-a52a-b51de6e76983` |
| `AS_GSS_FM_startNewRound` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42072` |
| `AS_GSS_SEC_rounds` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42270` |
| `AS_GSS_CP_evaluationSummaryStampField` | `_a-0000e5da-a251-8000-9bbe-011c48011c48_1007655` |
| `AS_GSS_UT_duplicateEvaluationForNewRound` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42160` |
| `AS_GSS_QR_getEvaluationRoundDetails` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42276` |
| `AS_GSS_UT_returnEvaluationRoundsForGivenEvaluation` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42289` |
| `AS_GSS_UT_returnIdentifiersForEvaluationRounds` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42301` |
| `AS_GSS_UT_returnViewRenderingConfigFor_Factors` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42412` |
| `AS_GSS_UT_returnLastParticipatedRoundForVendors` | `_a-0000f04a-0c6d-8000-9ba8-011c48011c48_42461` |
| `AS_GSS_CPS_viewEvaluatorTeam_Parent` | `_a-0000f04b-38cd-8000-9baa-011c48011c48_42490` |

**Existing core (read-only context):**
| Object | UUID |
| :--- | :--- |
| `AS_GSS_Evaluation_SYNCEDRECORD` | `e6bc8561-d3a6-4679-b7af-6e279910468e` |
| `AS_GSS_Evaluation_RECORD` | `4db4a62e-d099-4e54-be19-41498c17b9cc` |
| `AS_GSS_Criteria_SYNCEDRECORD` | `11dcc745-3c81-49f9-9cb2-6427680e4b41` |
| `AS_GSS_EvaluatorTeam_SYNCEDRECORD` | `791d954b-beae-4171-808f-876583d707fa` |
| `AS_GSS_EvaluatorTeamMembership_SYNCEDRECORD` | `7ac70e31-adcc-4145-a566-fcfe1f55146d` |
| `AS_GSS_CriteriaAssignment_SYNCEDRECORD` | `518a0b4d-1389-4483-8e39-dd103429c2b8` |
| `AS_GSS_EvaluationPhase_SYNCEDRECORD` | `bf3ef3fe-9671-40df-a195-bd71ab8deed8` |
| `AS_GSS_EvaluationVendor_SYNCEDRECORD` | `b6081510-0d11-4d51-8eba-966610b168db` |
| `AS_GSS_EvaluationVendorBusinessType_SYNCEDRECORD` | `28b193af-cca3-4ce3-9837-836838923e60` |
| `AS_GSS_EvaluationDocument_SYNCEDRECORD` | `9c497e08-f4c6-4fbd-bf14-5638dc226230` |

**Evaluation status constants (seen in code):** `AS_GSS_REF_ID_EVALUATION_STATUS_SETTING_UP`, `…_INPROGRESS`, `…_AWARDEES_SELECTED`, `…_COMPLETE`.

---

## 6. The must-know business rules

- Best Value only. Max **5** rounds. Round 1 can have up to ~400 vendors.
- Must down-select **≥1** vendor to advance; no max. Vendors eliminated **only between rounds**.
- Previous rounds are **read-only** for CO; **no round deletion**; **no skipping/early completion**.
- CO can **re-include** a previously excluded vendor in a new round.
- Evaluators see a round **only if on that round's team**; Factor Chairs see cross-round consensus with visual round indicators.
- On-the-spot consensus and evaluator masking are **per-round**.
- Round dates must sit **within** the overall evaluation dates; block save if a round exceeds its due date.
- Carry-forward docs/pricing are **editable**; factor→doc mapping resets if a factor is removed.
- **Combined** audit trail.

(Full table in `01_FEATURE_AND_TECHNICAL_DESIGN.md` §2.)

---

## 7. Current state in one line

Foundation done: round record type, the evaluation-duplication engine, a 2-step Setup New Round wizard, the Rounds panel, and supporting query rules. **Shipped tab work:** Vendors → "Last Participated Round" column; **Teams → round sub-tabs** (verified). Round sub-tabs remaining for 6 tabs — follow the recipe in `01_…` §6.6. See `02_PROGRESS_TRACKER.md` for the live checklist.

## 7a. Gotchas you MUST know before coding (details in `01_…` §6.6–6.7)
- **Tab content must be embeddable** — a `tabItem` rejects `HeaderContentLayout`. Strip a tab interface's outer `AS_GSS_HCL_displayWrapperContents`/`headerContentLayout` before nesting it per round (the `_Parent` supplies one frame).
- **Round-listing goes inside the `_Parent` interface**, not a standalone expression rule (per-round content uses `env!features`, which fails expression-rule validation).
- **Repoint Evaluation record views manually in Appian Designer** — `updateRecordTypeView`/`getRecordType` fail on `AS_GSS_Evaluation_RECORD` (`None is not a valid RecordTypeSourceType`). MCP creates the `_Parent`; a human swaps the one-line view reference.
- Run **`getObjectDependents`** before refactoring a shared interface to confirm blast radius.
- **Correlate vendors across rounds by `uniqueEntityId`** — `vendorRefId` is null and `vendorId` changes every round.
- **Resolve the anchor** with `coalesce(parentEvalId, evaluationId)`, then family = `append(anchor, children where parentEvalId = anchor)`.
- **`union()` is type-strict**; **`indexWhere` returns all matches** (use `index(...,1,null)`).
- **Trust `testInterface`/`testRule` over `validateDesignObject`** for i18n-bundle-dependent grids (false-positive `lbl_…` index errors under null stubs).
- **Keep it backward-compatible:** round helpers return empty for non-round evals so new UI stays hidden.

---

## 8. Working agreements

1. **Update `02_PROGRESS_TRACKER.md`** at the end of every session (statuses + append a Session Log entry).
2. **Validate** every changed object (`validateDesignObject`) and, where possible, `testInterface` / `testRule` before considering work done.
3. **Confirm priority** with the team before starting a work item — the plan is to pick items *after* documentation is in place.
4. **Match existing conventions** (naming, helper rules, constants) — don't introduce new patterns without reason.
5. **Don't guess UUIDs.** Always resolve them from `list*`/`get*` responses.
6. Treat the design doc as the source of truth for intent; treat the tracker as the source of truth for status.
7. Clean up any temp files (e.g., `/tmp/gss_review`) created while reading objects.

---

## 9. Handy first commands for a fresh agent

```
listApplicationObjects(appUuid: "_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416",
                       objectTypes: ["recordTypes","interfaces","expressionRules"])
listInterfaces(appUuid: <above>, query: "round")
listExpressionRules(appUuid: <above>, query: "round")
getRecordType(uuid: "931e8145-3f77-4270-a52a-b51de6e76983")
```
Then dump the round interfaces/rules to `/tmp/gss_review/*.sail` with `getInterface`/`getExpressionRule` and read them.
