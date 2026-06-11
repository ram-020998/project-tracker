# Design Ease (DE) — Code Review

**Application:** Design Ease (prefix `DE`, UUID `b65607a8-d424-40ed-ac8d-753aa5d041fd`)
**Reviewed:** 2026-06-11
**Scope:** Record types & data model, expression rules, process models, interfaces, site, security, naming/conventions.
**Method:** Static inspection of object definitions and SAIL source via lcp-mcp-server, plus `validateDesignObject` runtime checks on key objects.

---

## 1. Executive Summary

Design Ease is a well-structured solution for managing the design-request lifecycle: create a request, attach the application objects being changed (synced from a live object catalog), route it through design and implementation review stages, and auto-generate a design document. The architecture is sound — normalized reference tables, a generic query helper, consistent QR wrapper rules, audit columns, soft-delete (`isActive`), and record events for collaboration.

However, the review found **two critical correctness bugs** in the core workflow logic, a **heavy dependency on undocumented internal Appian functions**, and several **performance and data-integrity concerns**. All inspected objects are syntactically valid (no validation errors), so the issues below are logic/design defects rather than compile errors — they will not surface until specific runtime paths execute.

### Severity tally
| Severity | Count |
|----------|-------|
| Critical | 2 |
| High | 4 |
| Medium | 6 |
| Low / Nits | 7 |

---

## 2. Critical Findings

### C-1. Broken status state-machine — `DE_ReturnStatusIdOfDesignBasedOnAction`
This rule decides the next `statusId` from the current status and the button/event action. The approval and send-back branches are written as:

```
whenTrue: and(
  ri!currentStatusId = cons!DE_INT_DESIGN_STATUS_DESGIN_REVIEW,
  cons!DE_INT_EVENT_TYPE_APPROVE          /* <-- BUG: bare constant, not a comparison */
),
```

The second argument to `and()` is the **literal constant value** (e.g. `3`), not `ri!buttonAction = cons!DE_INT_EVENT_TYPE_APPROVE`. A non-zero integer coerces to `true`, so every approve/send-back branch effectively reduces to *just* `ri!currentStatusId = X` and **ignores the button action entirely**.

Concrete consequences:
- **Send Back from Design Review is unreachable.** The Approve branch and the Send-Back branch both reduce to the identical condition `currentStatusId = DESIGN_REVIEW`. Because `a!match` returns the first match top-to-bottom, the Approve branch always wins — a *Send Back* from Design Review will incorrectly advance the design to **In Implementation**.
- The send-back branches also compare against **status constants used as booleans**, e.g. `and(currentStatusId = IN_IMPLEMENTATION, cons!DE_INT_DESIGN_STATUS_IN_DESGIN)` — the second term is a status ID, not an action check, and is meaningless here.

**Impact:** The reviewer "Send Back" action does not return designs to the prior editing stage. This breaks a core part of the review loop.

**Fix:** Make every branch compare the action explicitly, and prefer a tuple-based match on `(currentStatusId, buttonAction)`:
```
whenTrue: and(
  ri!currentStatusId = cons!DE_INT_DESIGN_STATUS_DESGIN_REVIEW,
  ri!buttonAction   = cons!DE_INT_EVENT_TYPE_SEND_BACK
),
then: cons!DE_INT_DESIGN_STATUS_IN_DESGIN,
```
Add unit coverage for each (status × action) transition.

---

### C-2. Audit/ownership fields overwritten on every write — `DE_UpdateStatusAndMetaDataForDesignRequest`
This rule constructs the design record for **every** persistence path (Create Design *and* the shared Design Approval process). It unconditionally sets:

```
...designer: loggedInUser(),
...developer: {},
...modifiedBy: loggedInUser(),
```

`createdBy`/`createdOn` are correctly preserved with `DE_UTIL_replaceNull`, but `designer` and `developer` are not:
- **`designer` is overwritten with the current user on every update.** When a reviewer or approver runs Review Design / Complete Implementation / Review Implementation (all of which route through this rule via the approval process's *Update Status* node), the original designer is replaced by the reviewer.
- **`developer` is blanked (`{}`) on every write**, discarding any previously assigned developer.

**Impact:** Loss of ownership data and incorrect attribution after the first review action.

**Fix:** Only set `designer`/`developer` on creation (use `replaceNull` or branch on `isNullOrEmpty(designId)`), and never blank `developer` unless that is an explicit, intended action.

---

## 3. High Findings

### H-1. Heavy reliance on undocumented internal Appian functions
Several rules call internal/unsupported APIs:
- `DE_GetAllApplications` → `a!assystem_appian_internal(a!appdesigner_getApplicationList(...))`
- `DE_GetAllObjectsByPackage` → `a!assystem_appian_internal(a!appdesigner_getPackageContents(...))`
- `DE_GetAllObjects` → `a!aos_getObjects(on: fn!objectselect_appian_internal(...))`

These `*_appian_internal` / `appdesigner_*` / `aos_*` functions are not part of the public, supported function set. Risks:
1. **Upgrade fragility** — behavior or availability can change between Appian releases without notice.
2. **Security/visibility** — `a!assystem_appian_internal` runs in an elevated system context; `DE_GetAllApplications` returns *every* application in the environment regardless of the calling user's permissions, which may leak object names the user shouldn't see.

**Recommendation:** Isolate all internal-API usage behind these few wrapper rules (already mostly done), document the dependency and the supported Appian version range, and add a fallback/feature flag. Confirm with Appian whether supported equivalents exist.

### H-2. N+1 query pattern inside a write path — `DE_UpdateMetaDataForDesignObjectDetails`
Inside `a!forEach` over the design's objects, each iteration runs up to **three nested record queries** (`DE_QR_ReferenceObjectDetails` twice + `DE_getObjectVersionHistory` → `DE_getObjectDetailsByUUID`, which itself hits internal version-history APIs). For a design with *N* objects this is ~*3N* synchronous queries, executed during the design save. This will degrade noticeably as object counts grow and lengthens the user-facing save transaction.

**Recommendation:** Pre-fetch the reference object data (type id + uuid) for all object IDs in a single query before the loop, then index into it inside `forEach`. Cache version-history lookups. Consider moving version reconciliation out of the synchronous save path.

### H-3. `DE_GetAllObjects` — type mismatch and unbounded paging
```
pagingInfo: if(
  a!isNullOrEmpty(ri!pagingInfo),
  a!pagingInfo(startIndex: 1, batchSize: -1),   /* unbounded fetch */
  ri!applicationId                              /* BUG: Application passed where PagingInfo expected */
)
```
- The else-branch passes `ri!applicationId` (an `Application` value) where a `PagingInfo` is required — only the null branch is functional; passing a `pagingInfo` would error or misbehave.
- `batchSize: -1` fetches all objects unbounded — fine for small apps, risky for large ones.
- The self-exclusion filter `tointeger(fv!item.typeId) = typeof(ri!applicationId)` is a fragile way to drop the application object from results.

### H-4. `DE_QR_GetDesignRequestDetails` eager-loads deep relationships by default
The wrapper always requests 8 fields/relationships including nested chains (`designObjectDetails.designObjectComments`, `designObjectDetails.refObjectDetails`, `deExternalLinkDetails.deRLinktypes`). Every caller pays for the full graph even when it only needs scalar fields (e.g. the record grid, the title rule). This inflates query cost across the app.

**Recommendation:** Make the default field set lean (scalars only) and let callers opt into related data via the existing `fields`/`relatedRecordData` inputs, which the helper already supports.

---

## 4. Medium Findings

### M-1. Process-model expression typo — "Sync Objects" node (DE Create Design)
The `applicationUuid` input on the Sync Objects sub-process node is:
```
pv! pv!designRequestDetails['...refApplicationDetails.fields...applicationUuid']
```
The leading stray `pv! ` token is almost certainly a copy/paste artifact. It should be a single `=pv!...` expression. Verify it evaluates correctly; at best it's misleading, at worst the sync receives a null UUID.

### M-2. `a!match` value/whenTrue mix obscures intent
`DE_ReturnStatusIdOfDesignBasedOnAction` sets `value: ri!buttonAction` and then uses `whenTrue:` branches (which ignore `value`). This mixed style is what masked bug **C-1**. Pick one form — preferably explicit `whenTrue` comparisons against both inputs — and drop the unused `value`.

### M-3. Duplicated utility rules
Three near-identical copies of the same helpers exist: `CO_UT_isBlank` / `DE_UTIL_isBlank` / `DE_CO_UT_isBlank`, and likewise for `replaceNull` (`DE_UTIL_replaceNull`, `DE_CO_UT_replaceNull`). This is a maintenance hazard (fixes/behavior can drift). Consolidate to a single canonical rule.

### M-4. No record-level security
`DE_DesignRequestDetails` (and the other records) have `securityRules`/`securityExpression` = null. Object security grants **all** `DE Users` viewer access, so any user sees every design. If designs should be restricted to participants (designer/developer/reviewers) or by application, add record-level security rules. If global visibility is intentional, document it.

### M-5. Business config duplicated across constants and lookup tables
Status/event/comment IDs are encoded *both* as individual constants (`DE_INT_DESIGN_STATUS_*`), as list constants (`DE_INT_DESIGN_STATUS_IDS`), *and* as rows in reference record types (`DE_R_DesignStatus`, `DE_R_EventTypeLookup`, `DE_R_CommentTypes`). Three sources of truth for the same enumerations risks drift. Decide on the authoritative source (lookup tables) and derive the rest.

### M-6. Reviewer fields typed inconsistently
`designer` and `developer` are `USER` type, but `designReviewer` and `peerReviewer` are `TEXT`. For referential integrity, user pickers, and reuse of user-display utilities, the reviewer fields should also be `USER`.

---

## 5. Low Findings / Nits

- **L-1. Pervasive spelling errors in identifiers** (hard to rename later): `DESGIN` instead of `DESIGN` in many constants (`DE_INT_DESIGN_STATUS_IN_DESGIN`, `..._DESGIN_REVIEW`), `DE_CARD_DesignPbject` (Object), `DE_MLS_createNewDesignMiletsone` (Milestone).
- **L-2. Auto-generated plural names left unedited**: `DE_DesignRequestDetailses`, `DE_R_DesignPriorities`, `DE_ObjectModificationTypeses`. Set human-readable plurals.
- **L-3. Inconsistent record naming**: mix of `DE_R_*` (ApplicationDetails, ObjectDetails, DesignStatus) and non-prefixed (`DE_DesignRequestDetails`, `DE_CommentDetails`). Standardize the reference-vs-transactional naming scheme.
- **L-4. Leftover scratch/test artifacts** in the app: `DE Test doc 04`, `DE Temporary Folder`, `DE HTML Template`, `DE_ExpressionTestData`. Remove or move out of the deployable package.
- **L-5. Misleading constant description**: `DE_INT_EVENT_TYPE_SAVE_AND_CLOSE` value is `5` but its description says "Save and Close - 1" (copy/paste).
- **L-6. Verbose inline field references**: rules like `DE_UpdateStatusAndMetaDataForDesignRequest` repeat fully-qualified `recordType!{uuid}...` paths dozens of times without `a!localVariables` aliasing — readable but error-prone to edit (this verbosity contributed to C-2 going unnoticed).
- **L-7. `DE_GetAllObjects` comment typo** ("NON-APPLICAITON OBJECTS") and similar comment typos elsewhere.

---

## 6. Strengths (worth preserving)

- **`DE_UTIL_QueryRecord`** is a genuinely good generic query helper: supports `OBJECT_ARRAY`/`SINGLE_OBJECT`/`DATA_SUBSET`/`TOTAL_COUNT` return modes, multi-term search across fields, `executeWhen` early-exit, `refreshVariable` with record-action refresh, grouping/aggregation, and a sensible `default` error path. This is a strong reusable foundation.
- **Consistent per-record QR wrappers** (`DE_QR_Get*`) layer cleanly on top of the helper.
- **Audit + soft-delete conventions** (`createdBy/On`, `modifiedBy/On`, `isActive`) applied uniformly across record types.
- **Normalized reference/lookup tables** and **record events** for collaboration are good modeling choices.
- **Consistent naming prefixes** (`DE_QR_`, `DE_UT_`, `DE_SEC_`, `DE_FM_`, `DE_CARD_`, `DE_INT_`, `DE_HEX_`) make the object set easy to navigate.
- **Reuse of the shared `CO_UT_*` common utility library** instead of re-implementing primitives.
- **Object security** is correctly mapped (admin → DE Administrators, viewer → DE Users; no stray editor/data-steward grants).
- All inspected objects passed `validateDesignObject` with **zero validation errors**.

---

## 7. Prioritized Remediation Plan

1. **Fix C-1** (status state machine) — rewrite `DE_ReturnStatusIdOfDesignBasedOnAction` with explicit action comparisons; add per-transition tests. *Blocks correct review flow.*
2. **Fix C-2** (ownership overwrite) — preserve `designer`/`developer` on update in `DE_UpdateStatusAndMetaDataForDesignRequest`.
3. **Fix H-3 & M-1** — correct the `pagingInfo` type mismatch in `DE_GetAllObjects` and the stray `pv!` token in the Sync Objects node.
4. **Address H-2** — remove the N+1 pattern from `DE_UpdateMetaDataForDesignObjectDetails`.
5. **Mitigate H-1** — document and contain internal-API dependencies; confirm supported alternatives and version range.
6. **Tune H-4** — slim default field sets in `DE_QR_GetDesignRequestDetails`.
7. **Clean up** — M-3 (dedupe utilities), M-5 (config single source), L-1..L-7 (naming, scratch artifacts, descriptions).

---

*Note: This review is based on static analysis of object definitions and SAIL source. Findings C-1, C-2, H-2, and M-1 should be confirmed with targeted runtime tests (execute each review action and inspect resulting `statusId`, `designer`, `developer`, and saved object versions) before and after remediation.*
