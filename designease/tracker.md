# Design Ease — Project Tracker

**Last Updated:** 2026-06-11
**Type:** Appian application (explored + reviewed via LCP MCP server)
**Application UUID:** `b65607a8-d424-40ed-ac8d-753aa5d041fd`
**Prefix:** `DE` | **URL Identifier:** `2hdo0g`

---

## Overview

**Design Ease** is an Appian application that automates the creation of design documents
for development tasks. Developers draft a design request, attach the application objects
being changed (synced from a live object catalog), route it through design and
implementation review stages with object-level comments and an event timeline, and finally
auto-generate a formatted design document. An AI chat layer allows Q&A on any design.

It optionally integrates with an external **SMT** system (`SMT_Application`, `SMT_DevPhase`,
`PCK_AppConfig`) gated by the `DE_BOOL_SMT_REFERENCE_ENABLED` flag.

---

## Status

- **Exploration:** ✅ Complete — full object inventory + data model + workflow mapped via LCP MCP server.
- **Code review:** ✅ Complete — source-level review of core rules, process models, security, and validation. See `DesignEase_Code_Review.md`.
- **Remediation:** ⬜ Not started — findings documented, no fixes applied yet.

---

## Architecture Snapshot

### Data model (DATABASE-backed, `jdbc/Appian`)
- **Central transactional record:** `DE_DesignRequestDetails` (`DE_DESIGN_REQUEST_DETAILS`) — only record with **Record Events** enabled. Fans out to:
  - `DE_DesignObjectDetails` (1:M) — junction linking a design to specific objects (tracks initial/current version, modification type); 1:M to `DE_CommentDetails`.
  - `DE_TestCaseDetails` (1:M), `DE_ExternalLinkDetails` (1:M), `DE_DesignEventHistory` (1:M).
  - `DE_R_ApplicationDetails` (M:1), `DE_R_DesignStatus` (M:1), `DE_R_DesignPriority` (M:1).
- **Object catalog:** `DE_R_ObjectDetails` (`DE_R_OBJECT_DETAILS`) — reference list of all design objects per application; populated by sync processes.
- **Lookups:** `DE_R_DesignStatus`, `DE_R_DesignPriority`, `DE_R_CommentTypes`, `DE_R_LinkTypes`, `DE_ObjectModificationTypes`, plus record-events supporting set (`DE_R_EventTypeLookup`, `DE_DesignEventHistory`, `DE_EventReplyThread`, subscriber).
- **External (SMT-synced):** `DE_R_EXT_Application (SMT)`, `DE_R_EXT_DevPhases`, `DE_R_EXT_ApplicationConfigs`.

### Lifecycle (encoded in constants)
- **Statuses:** 1 In Design → 2 Design Review → 3 In Implementation → 4 Implementation Review → 5 Completed → 6 Cancelled.
- **Event types:** 1 Create, 2 Update, 3 Approve, 4 Send Back, 5 Save and Close.
- **Comment types:** 1 Object Design, 2 Object Design Review, 3 Object Implementation, 4 Object Implementation Review.

### Process models
- **DE Create Design** — multi-step wizard (app/ticket → object selection → object change descriptions); kicks off **DE Sync Objects**; writes design + children; confirmation screen for new designs.
- **DE Design Approval Process** — shared by Review Design / Complete Implementation / Review Implementation related actions; renders `DE_FM_ReviewDesignRequest`, updates status/metadata, writes records, fires **DE Send Email** async.
- Supporting: **DE Sync Applications Nightly Process**, **DE Sync Objects**, **DE Send Email**, **DE Object Version Compare**, **DE Generate Design Document**, **DE Create Or Update Ref Object**.

### UI
- **DesignEase site** (`/designease`, HEADER_BAR / MERCURY): **Design** page (record grid + flows) and **AI Chat** page (record chat).
- Record actions on Design Request: Create Design (list), Review Design, Complete Implementation, Review Implementation, Continue Design, Generate Design Document.
- Views: Summary + Object Details.

### Security
- Two app groups: **DE Administrators** (admin + alerts) and **DE Users** (viewer). No connected systems, no Web APIs. No record-level security configured.

---

## Code Review Findings (see DesignEase_Code_Review.md)

Severity tally: **2 Critical, 4 High, 6 Medium, 7 Low.** All objects validated clean (no
syntax errors) — findings are logic/design defects.

### Critical
- **C-1 — Broken status state machine** (`DE_ReturnStatusIdOfDesignBasedOnAction`): branches use
  `and(currentStatusId = X, cons!DE_INT_EVENT_TYPE_APPROVE)` where the 2nd arg is a bare constant,
  not `ri!buttonAction = ...`. The button action is never checked → **Send Back from Design Review
  wrongly advances to In Implementation** (identical condition, Approve branch matches first).
- **C-2 — Ownership overwritten on every write** (`DE_UpdateStatusAndMetaDataForDesignRequest`):
  unconditionally sets `designer: loggedInUser()` and `developer: {}`. Any reviewer/approver action
  (routed through this rule) overwrites the original designer and wipes the developer.

### High
- **H-1** — Heavy reliance on undocumented internal functions (`a!assystem_appian_internal`,
  `appdesigner_getApplicationList/getPackageContents`, `objectselect_appian_internal`,
  `aos_getObjects`): upgrade fragility + elevated-context visibility leak risk.
- **H-2** — N+1 query pattern in `DE_UpdateMetaDataForDesignObjectDetails` (~3 nested queries per
  object, inside the synchronous save path).
- **H-3** — `DE_GetAllObjects`: `pagingInfo` else-branch passes an `Application` where `PagingInfo`
  is expected; `batchSize: -1` unbounded; fragile self-exclusion filter.
- **H-4** — `DE_QR_GetDesignRequestDetails` eager-loads 8 deep/nested relationships by default for
  every caller.

### Medium / Low (selected)
- M-1: stray `pv! pv!` token in the Sync Objects process node's `applicationUuid` input.
- M-3: duplicated utility rules (`isBlank`/`replaceNull` exist 2–3 times).
- M-4: no record-level security (all DE Users see all designs).
- M-5: enum config triplicated across constants/list-constants/lookup tables.
- M-6: `designReviewer`/`peerReviewer` typed TEXT (should be USER).
- L-1: pervasive identifier typos (`DESGIN`, `DesignPbject`, `Miletsone`).
- L-4: leftover scratch artifacts (`DE Test doc 04`, `DE Temporary Folder`, `DE_ExpressionTestData`).

### Strengths preserved
- `DE_UTIL_QueryRecord` is a well-designed generic query helper (returnType modes, search, refresh,
  early-exit). Consistent QR wrappers, audit + soft-delete conventions, normalized lookups, record
  events, consistent naming prefixes, correct object-security mapping.

---

## Decisions Made

| Decision | Reasoning |
|----------|-----------|
| Review via static analysis + `validateDesignObject` | `evaluateExpression`-style live runs not used; LCP MCP read tools + validation sufficient to surface logic defects |
| Document findings, don't fix yet | User asked for a review document, not remediation |

---

## Remaining Items / Next Steps

- [ ] Confirm C-1, C-2, H-2, and M-1 with targeted runtime tests (run each review action; inspect
      resulting `statusId`, `designer`, `developer`, saved object versions).
- [ ] Fix C-1 (rewrite state machine with explicit action comparisons + per-transition tests).
- [ ] Fix C-2 (preserve designer/developer on update).
- [ ] Fix H-3 + M-1 (pagingInfo type mismatch; stray `pv!` token).
- [ ] Address H-2 (remove N+1 from the save path).
- [ ] Mitigate H-1 (document/contain internal-API dependency + supported version range).
- [ ] Tune H-4 (slim default field sets).
- [ ] Cleanup: M-3 (dedupe utilities), M-5 (config single source), L-1..L-7 (naming, scratch artifacts).

---

## Documents

| Document | Location |
|----------|----------|
| Code review | `DesignEase_Code_Review.md` (this folder) |
| This tracker | `/Users/ramaswamy.u/repo/project-tracker/designease/tracker.md` |
