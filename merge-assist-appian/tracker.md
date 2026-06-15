# Merge Assist (Appian) — Project Tracker

> **Session ID:** `<FILL IN — this session's id>`  *(retrieve via `/chat` session list or `/chat save` metadata; could not be read programmatically from within the session)*
> **Tracked by:** Project Tracker Agent
> **Model:** claude-opus-4.8
> **Primary working repo:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-appian`
> **First tracked:** 2026-06-10

---

## Overview

**Merge Assist (Appian)** is an Appian-native application + Java plugin that helps customers
manage **vendor application upgrades**. It is the next-generation **replacement** for the
legacy **3WM** Flask app — not a port. A user uploads the **base** and **latest vendor**
packages; the system classifies every object (New / Updated-Safe / Conflict today) and lets
reviewers inspect each change with Appian's native diff renderer and an impact-analysis panel.

### The pivotal design idea
The application is deployed **into the customer's own Appian environment**, so the live
environment **is** the customer's customized version (Package B). The user therefore uploads
only **two** packages (Base = A, Latest vendor = C). The "customer delta" is computed by
inspecting the base package against the environment; the "vendor delta" by inspecting the
latest package against the environment. Classification cross-references the two inspect results.

### Key repositories & locations
| Repo / path | Role |
|---|---|
| `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-appian` | This repo: steering, docs, implementation plans, `MergeAssist_Documentation.md` |
| `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-v2` | The v2 effort: plugin Java source, SAIL conversion rules, app export, test packages |
| `/Users/ramaswamy.u/repo/3WM` | Legacy 3WM Flask app (functional reference; `repo-intel/` is authoritative) |
| `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/power-appian-reference` | SAIL/Appian reference steering docs (imported) |
| `/Users/ramaswamy.u/repo/project-tracker/merge-assist-v2/tracker.md` | The v2 plugin-build tracker (April–May 2026) |

### Live Appian application metadata (verified via LCP MCP server)
| Property | Value |
|---|---|
| Name | Merge Assist |
| UUID | `33060c62-b495-4c03-9948-206c2f976d2b` |
| Prefix | `MA` |
| URL Identifier | `MziVvQ` |
| Administrators Group UUID | `7e9d879d-0f13-4ae4-b506-bef6f6685aa2` |
| Users Group UUID | `7cd3291e-0127-468b-8e0c-ad5bc6667092` |
| Process Model Folder UUID | `6a00ff09-4e2a-4459-b3c6-789f23ca57a2` |
| Rules & Constants Folder UUID | `41b92b16-1bd2-4530-8270-e25c2933fccd` |
| Knowledge Center UUID | `f5f5deee-9036-4de3-9aad-9ea698967d2c` |

---

## Status

- **Phase:** Documentation & planning complete; about to begin Priority 1 (review workflow) implementation.
- **Priority order (reprioritized this session):**
  1. Complete the **review workflow**
  2. **UX revamp** (match the appreciated 3WM UI)
  3. Everything else — **complex converters (process models & record types) last**
- **Priority 1 implementation plan:** drafted, awaiting confirmation of 6 open decisions
  (`implementation/priority-1-review-workflow-plan.md`).
- **Blocker watch:** right-side (vendor) XML→diff conversion for complex types; process-model
  `content`-key extraction bug; `evaluateExpression` MCP tool returns 403.
- **NEW (2026-06-10):** the LCP MCP server was upgraded with a large tool set (full CRUD across
  most object types, record-data read/write, process-model node editing, validation/test tools).
  This removes several workarounds baked into the Priority 1 plan — **the plan needs an update**
  (see Remaining Items).

---

## Architecture snapshot (verified via MCP)

### Two deliverables
1. **Plugin JAR** `merge-assist-plugin-1.0.0.jar` (`com.appiancorp.mergeassist`, min Appian 23.2),
   deployed to `_admin/plugins/`. Zero object-type-specific code; public SDK only.
2. **Appian application** — SAIL interfaces, expression rules, record types, constants, process model.

### Plugin functions
| Function (key) | Type | Purpose |
|---|---|---|
| `MA Inspect Package` (`inspectPackageV2`) | Smart service | `ImportExportService.inspectPackage()` of a package vs the environment. Returns JSON `{created[], updated[], failed[], summary{created,updated,notChanged,failed}}`; each item `{uuid,name,type}`. `notChanged` counted only. `@Unattended`, read-only. |
| `MA Extract Package Objects` (`extractPackageObjects`) | Smart service | Unzips package; stores each object XML as a document (`type_uuid_timestamp`, `UNIQUE_NONE`); returns `[{uuid,name,objectType,documentId}]`. |
| `xmlToMap` | Expression fn | Generic XML→JSON (`org.json.XML.toJSONObject`). |
| `extractDefinition` | Expression fn | Extract SAIL from `<definition>` (CDATA or plain). |
| `resolveExpression` | Expression fn | Stored→display SAIL via `FreeformRule.setDefinition()/getDefinition()`. |

### Classification logic — `MA_UT_constructObjectClassifications(baseResponse, vendorResponse, session)`
- `baseResponse.updated` = customer-modified objects (base differs from env).
- `vendorResponse.created` → **NEW** (status 1).
- `vendorResponse.updated` NOT in `baseResponse.updated` → **UPDATED/Safe** (status 2).
- `vendorResponse.updated` IN `baseResponse.updated` → **CONFLICT** (status 3).
- Both empty → session **FAILED (5)**; else **READY (2)**. Writes counts + classification children.
- **Only 3 classifications are produced today** (no CUSTOMISED/DELETED/UNCHANGED).

### Diff render — `MA_renderDiffViewForObject(object)`
- **Left (customer/env):** `a!asSystem_appian_internal(a!dod_fwk_asGetObjectFn(getObjectFn/getEditableObjectFn(...)))`
  wrapped in `a!dod_connEnv_simulateConnectedEnvReturn`; falls back to editableObject. The
  `asSystem + asGetObjectFn` combo bypasses the framework guards.
- **Right (vendor):** `MA_convertXmlToDiffMap(type, a!fromJson(xmltomap(vendorXmlDocId)))`.
- Configs via `diffPresentationConfigFn`/`diffPresentationConfig`; `a!dod_fwk_sectionsGenerator`.
- RecordType (`objectTypeId = 228`) removes config indices `{9, 20}`. Columns: "Customer Version" | "Vendor Version".

### Converter dispatcher — `MA_convertXmlToDiffMap`
`a!match` on `lower(type)` → ~23 routes (rule, interface, constant, group, processmodelfolder,
knowledgecenter, content, datastore, datatype, webapi, connectedsystem, site, application,
recordtype/record, processmodel, decision, integration, translationstring, translationset,
aiskill, controlpanel, grouptype); default = error map.

### Review workflow — `MA_FM_reviewObjects(session, buttonAction)`
- Loads classifications via `MA_QR_getObjectClassification(OBJECT_ARRAY, sessionId, triggerRefresh)`;
  `local!currentIndex` starts at 1.
- Shows name, type tag, UUID, classification status; **View Diff** record action; embedded
  `MA_SEC_viewDependentsAndPrecedents`; **Notes** field; **Save and Close / Next / Previous**.
- **Gap:** does NOT set `objectReviewStatusId`/`reviewedBy`/`reviewedOn`; no Approve/Reject/Skip;
  session status not transitioned.

### Data model (verified)
- **`MA_REC_MergeSession`** (`fd17fe05-91f4-4f35-9c6b-fd3096dd4629`): sessionId(PK), sessionName,
  sessionDesc, vendorPackageDocId, basePackageDocId, extractionFolderId, recSessionStatusId,
  totalObjects, newCount, safeCount, conflictCount, createdBy/On, modifiedBy/On. Rels:
  recSessionstatus, createdByUser, modifiedByUser, objectClassification (1:M). *No customer
  package field; no customized/deleted counts.*
- **`MA_REC_ObjectClassification`** (`e8afcb0f-f662-4cec-9afe-ab5f38e6bfd5`): classificationId(PK),
  sessionId, objectUuid, objectName, objectTypeId, objectTypeName, objectClassificationStatusId,
  vendorXmlDocId, objectReviewStatusId, reviewedBy, reviewedOn, reviewNotes. Rels:
  recObjectclassificationstatus, recObjectreviewstatus, reviewedByUser, session.
- **Lookups:** `MA_REC_SessionStatus` (`eb52484a-…`), `MA_REC_ObjectClassificationStatus`
  (`59d43e3b-…`), `MA_REC_ObjectReviewStatus` (`58d05be0-…`) — each id/value/isActive/sortOrder.

### Interfaces (6) & key UUIDs
| Interface | UUID |
|---|---|
| MA_DSH_homePage | `_a-0000efa9-1a7d-8000-9ba8-011c48011c48_35178` |
| MA_FM_createNewSession | `_a-0000efa6-747f-8000-9ba4-011c48011c48_33965` |
| MA_sessionSummary | `303fb288-2301-456c-a72c-7ac84224c75f` |
| MA_FM_reviewObjects | `_a-0000efb2-70a7-8000-9bb2-011c48011c48_56655` |
| MA_renderDiffViewForObject | `_a-0000efa9-1a7d-8000-9ba8-011c48011c48_35306` |
| MA_SEC_viewDependentsAndPrecedents | `_a-0000efb2-70a7-8000-9bb2-011c48011c48_56676` |

Record actions: `startReview` on MergeSession (`141da790-82bf-46d1-b23c-eb55499c9e1b`),
`viewDiff` on ObjectClassification (`aeb672b6-4d53-4706-a6ac-36e9fdecb0e1`),
`createNewSession` on MergeSession (`cee683e3-…`).

### Constants (verified)
Session status: PROCESSING=1, READY=2, IN_REVIEW=3, COMPLETED=4, FAILED=5.
Classification: NEW=1, UPDATED=2, CONFLICT=3. Plus `MA_GRP_ALERTS`,
`MA_FOLDER_SESSION_UPLOADS`, `MA_FOLDER_SESSION_EXTRACTS`. *No review-status constants yet.*

---

## Session Log

### 2026-06-15 — Single-inspect classification via native conflict detection

**Big simplification: the base-package inspection is being removed.** Discovered that the Appian SDK's
`ImportResults` exposes a first-class **`getConflictedObjects()`** bucket (native conflict detection)
that the plugin's `InspectPackageService` had been ignoring. A **single inspect of the vendor package**
now yields the full three-way result directly: `created` → New, `updated` (minus `conflicted`) → Safe,
`conflicted` → Conflict. This replaces the dual-inspect (base + vendor) cross-reference.

#### Completed
- **Plugin (`InspectPackageService.java`, merge-assist-v2):** now emits the `conflicted` bucket (array
  + `summary.conflicted` count + log). **Additive, signature unchanged** → key `inspectPackageV2` kept
  (no bump). Rebuilt with JDK 17; user redeployed and confirmed `conflicted` is populated on a real run.
- **Verified bucket semantics on a real sample:** `summary {created:1, updated:6, notChanged:31,
  conflicted:5, failed:0}`. **`updated` is a superset that already contains `conflicted`** (not
  disjoint) → **Safe = updated − conflicted**. Also: `conflicted` entries can omit the `type` field, so
  name/type are read from the `updated`/`created` entries and `conflicted` is used only as a UUID set.
- **`MA_UT_constructObjectClassifications` (live via LCP MCP):** rewritten — `baseResponse` input
  removed (signature now `(vendorResponse, session)`); conflict set = `vendorResponse.conflicted`;
  validity/G6 now checks only the vendor response; G7 counts unchanged. `validateDesignObject` clean.
- **Docs:** created `docs/04-single-inspect-conflict-detection.md` (+ README index); supersedes the
  dual-inspect description in `docs/02` / steering `12`.

#### Decisions
- **Use native conflict detection (`getConflictedObjects`)** instead of reconstructing conflicts via a
  base inspect. (Standard Appian feature; halves inspect work; removes cross-reference complexity.)
- **Keep the base package upload + extraction.** It is still used by the **"Base Vs Vendor Latest"**
  diff option (`baseXmlDocId` → `MA_UT_deriveDiffObjectDataFromXml` → `MA_renderDiffViewForObject`
  diffViewType 2). Only the base **inspection** is removed — the upload form, `basePackageDocId`,
  `baseXmlDocId`, base extraction node, and `MA_UT_updateDocumentIdForObjects` are unchanged.

#### Remaining / handed to user (Designer)
- [ ] **`MA Process Session Packages`** (`0002efa8-20a2-…`): delete node 2 "Inspect Base Package",
      reconnect Start(0)→Inspect Vendor(14), update node 3 "Construct Object Classification" expression
      to call `MA_UT_constructObjectClassifications(vendorResponse: pv!vendorInspectionResults,
      session: pv!session)`. (`baseInspectionResults` PV becomes orphaned — harmless.)
- [ ] End-to-end test: `new + safe + conflict = total`; sample app → 1 New / 1 Safe / 5 Conflict; both
      diff modes still render; failed/empty vendor inspect → session **Failed**.
- [ ] Sync `MergeAssist_Documentation.md` + steering `11`/`12` to the single-inspect model.

### 2026-06-10 — Discovery, documentation, reprioritization, Priority 1 plan

#### Completed
- Read `MergeAssist_Documentation.md`; confirmed the LCP MCP server is live (Merge Assist app found).
- Deep-explored **3WM** (README + `repo-intel/`: SYSTEM_OVERVIEW, DOMAIN_MODEL, MERGE_WORKFLOW,
  REPO_GLOSSARY, ARCHITECTURAL_INVARIANTS, EXTENSION_PLAYBOOKS, CONFIG_BEHAVIOR).
- Deep-explored the **live Appian app** via MCP: read `MA_convertXmlToDiffMap`,
  `MA_renderDiffViewForObject`, `MA_UT_constructObjectClassifications`, `MA_FM_reviewObjects`,
  `MA_sessionSummary`, `MA_DSH_homePage`, `MA_QR_getObjectClassification`, `MA_QR_getSessions`,
  the two transactional record types + three lookups, and the constants list.
- Deep-explored the **v2 plugin**: both smart-service Java sources, `appian-plugin.xml`,
  `SESSION_PROGRESS.md`, and the (large, complex) process-model SAIL converter.
- **Created `.kiro/steering/`** docs. Initially framed the project as a "3WM→Appian migration";
  **corrected** to the v2 plugin-based, environment-as-customer approach after the user clarified.
- **Imported** 5 SAIL/Appian reference steering docs from `power-appian-reference`.
- **Created `docs/`**: `01-3wm-application.md`, `02-merge-assist-appian.md`,
  `03-next-steps-and-action-items.md`, plus `README.md` index.
- **Reorganized** steering into a grouped, numbered scheme (`00-index` + 10s project / 20s
  practices / 30s SAIL reference) and updated all cross-references.
- **Reprioritized** the next-steps backlog and steering roadmap: review workflow → UX → complex converters last.
- **Drafted** `implementation/priority-1-review-workflow-plan.md` (detailed, with 6 open decisions).
- Discovered the **MCP server was upgraded** with a much larger tool set (documented below).

#### Decisions Made
- **v2 approach is canonical** — replace 3WM, don't port it; environment = customer version;
  two-package upload; classification via dual `inspectPackage`. (Reason: leverage the platform;
  no need to upload the customer package.)
- **Plugin stays generic** — all object-type awareness lives in SAIL `MA_convert_*` (reason:
  maintainability; a universal Java converter was tried and abandoned in v2).
- **All live Appian design-object changes go through the LCP MCP server** (reason: single
  sanctioned, auditable path; the docs may lag the live env, so verify live first).
- **Steering = concise directive guidance; `docs/` = detailed living reference** (reason: reduce
  confusion from overlap).
- **Priority order:** review workflow → UX → process models/record types last (user directive).
- **Priority 1 review-status model:** recommended **Model A** — single field with
  Pending(1)/Approved(2)/Rejected(3)/Skipped(4) (reason: simplest; one field already exists).
- **Priority 1 written to avoid editing expression rules / inserting data** — because at plan
  time the MCP server lacked `updateExpressionRule` and a data-insert tool. *(Superseded — see Issues/Remaining.)*

#### Learnings
- **Environment-as-customer** is the core insight that distinguishes v2 from 3WM's three-upload model.
- **Only 3 classifications** are produced live (New/Updated/Conflict); the 5–6 in v2 notes
  (CUSTOMISED/UNCHANGED/DEPRECATED) are aspirational, not implemented.
- The review form **never sets review status / reviewer / timestamp** and has no decision actions.
- `MA_QR_getObjectClassification` already supports sort/filter/aggregation → conflict-first
  sort + filters need no rule change.
- Home dashboard counts sessions by status → lifecycle transitions surface there automatically.
- Diff viewer **left side works for all types**; **right side** (vendor XML→diff) is the blocker
  for complex types; process-model `content`-key extraction from `xmlToMap`/`a!fromJson` is unresolved.
- **MCP tool schemas load at connection init and don't refresh mid-session.** A `/chat new` or
  CLI restart is needed to pick up server tool changes.

#### Issues Encountered
- **Initial misframing** (migration vs replacement) → corrected after user clarification;
  steering rewritten. ✅
- **`evaluateExpression` returns 403 Access denied** — even for `1 + 1`. Tool/endpoint blocked
  in this environment; could not dry-run SAIL or query live data. ⚠️ Still open at session end.
- **MCP tools didn't refresh mid-session** after the server was upgraded → recommended reconnect.
  ⚠️ This session still bound to the old schemas; new tools known only from the user's pasted list.

#### Remaining Items / Next Steps
- [ ] **Fill in the session ID** at the top of this tracker.
- [ ] **Update `implementation/priority-1-review-workflow-plan.md`** to use the new MCP tools
      (remove workarounds): use `updateExpressionRule` to default review status at creation,
      `insertRecordData` to seed the `MA_REC_ObjectReviewStatus` lookup directly (drop the
      `MA_SETUP_seedReviewStatuses` interface), `add/updateRecordTypeAction` for record actions,
      and `validateExpression`/`testInterface`/`testRule` for verification (since `evaluateExpression`
      is blocked). Consider a process-backed `startReview` via `createProcessModel` if desired.
- [ ] **Confirm the 6 Priority 1 open decisions** (review-status model, decision semantics,
      when "In Review" is set, jump-to-list scope, seeding approach, whether to edit the
      classification rule) — several are now easier given the new tools.
- [ ] Implement **Priority 1 — review workflow** (Approve/Reject/Skip + status + reviewer/date,
      session lifecycle, progress, conflict-first sort + filters, jump-to list).
- [ ] Then **Priority 2 — UX revamp**; then **Priority 3** (classification completeness, other
      gaps, and complex converters last).

---

## Reference: LCP MCP Server tool inventory (post-upgrade, provided 2026-06-10)

> The session that produced this tracker was still bound to the **pre-upgrade** tool set
> (limited CRUD + a blocked `evaluateExpression`). The user provided the **post-upgrade**
> inventory below. A session reconnect (`/chat new` or CLI restart) is required to actually
> invoke these. List captured as provided (the source list was truncated after Robotic Tasks).

**Applications (5):** listApplications, getApplication, createApplication, addObjectsToApplication
(associate existing objects), deleteApplication (container only; objects preserved/unassociated).

**Record Types (29):** listRecordTypes, getRecordType, createRecordType, updateRecordType (partial),
deleteRecordType, listRecordTypeFields, getRecordTypeField, addRecordTypeField (creates DB column
for CDM-backed), updateRecordTypeField (partial), deleteRecordTypeField (drops column; PK can't be
deleted), listRecordTypeRelationships, addRecordTypeRelationship, updateRecordTypeRelationship,
deleteRecordTypeRelationship, listRecordTypeActions (incl. PM UUIDs/visibility), addRecordTypeAction,
updateRecordTypeAction (partial; actionType immutable), deleteRecordTypeAction, listRecordTypeViews,
addRecordTypeView (first = Summary), updateRecordTypeView, deleteRecordTypeView (Summary can't be
deleted), reorderRecordTypeViews (all urlStubs), configureRecordEvents, getRecordEventsConfig,
listRecordTypeUserFilters, addRecordTypeUserFilter, updateRecordTypeUserFilter, deleteRecordTypeUserFilter.

**Record Data (4):** listRecordData (CSV, paginated), insertRecordData (CSV; returns PKs),
updateRecordData (by PK from CSV; partial), deleteRecordData (hard-delete by PK from CSV).

**Interfaces (6):** listInterfaces, getInterface (incl. SAIL), createInterface, updateInterface
(partial), deleteInterface, testInterface (render with test inputs; catches runtime errors).

**Expression Rules (5):** listExpressionRules, getExpressionRule (incl. code), createExpressionRule,
updateExpressionRule (partial), deleteExpressionRule.

**Constants (5):** listConstants, getConstant, createConstant (typed), updateConstant (partial),
deleteConstant.

**Process Models (15):** listProcessModels, listProcessModelFolders, getProcessModel,
createProcessModel, deleteProcessModel, listApplicationProcesses (runtime instances; optional status),
updateProcessModel (partial), listProcessModelNodeTypes, getProcessModelNodeTypeSchema,
testProcessModel (run unattended to completion; returns PVs), listProcessModelNodes,
getProcessModelNode, createProcessModelNode, updateProcessModelNode (partial; type/id immutable),
deleteProcessModelNode (cleans up connections).

**Integrations (5):** listIntegrations, getIntegration, createIntegration, updateIntegration, deleteIntegration.

**Connected Systems (7):** listConnectedSystemTypes, getConnectedSystemType (operations → operationId),
listConnectedSystems, getConnectedSystem (live schema), createConnectedSystem (returns schema for
iterative config), updateConnectedSystem (schema-driven), deleteConnectedSystem.

**Web APIs (5):** listWebApis, getWebApi, createWebApi, updateWebApi, deleteWebApi.

**Sites (5):** listSites, getSite, createSite (requires ≥1 page), updateSite, deleteSite.

**Groups (8):** listGroups, getGroup (by name), createGroup, listGroupMembers, addGroupMembers
(batch), removeGroupMember, updateGroup, deleteGroup.

**Folders (6):** listFolders, getFolder, createFolder, updateFolder, deleteFolder, listFolderContents.

**Documents (8):** listDocuments, getDocument, updateDocument (metadata), deleteDocument,
getDocumentContent (binary), getDocumentText (extracted text), replaceDocumentContent (auto
base64), uploadDocument.

**Objects — cross-cutting (3):** listApplicationObjects (all design objects in one call),
getObjectSecurity (role map by UUID), updateObjectSecurity (set role map by UUID).

**Validation (2):** validateDesignObject (validate all expressions on an object),
validateExpression (compile-check raw SAIL without running).

**Test Rule (1):** testRule (execute an expression rule or integration with test inputs).

**AI Skills (2):** listAiSkills, getAiSkill. **AI Agents (2):** listAgents, getAgent.
**Robotic Tasks (2):** listRoboticTasks, getRoboticTask. *(source list truncated here)*

### Impact of the new tools on plans
- The Priority 1 plan's three biggest workarounds are now removable: (1) seed
  `MA_REC_ObjectReviewStatus` via **`insertRecordData`** instead of a setup interface; (2) edit
  `MA_UT_constructObjectClassifications` via **`updateExpressionRule`** to default review status;
  (3) manage record actions via **`add/updateRecordTypeAction`**.
- **Verification** can now use `validateExpression`, `validateDesignObject`, `testInterface`, and
  `testRule` — important because `evaluateExpression` remains 403.
- **Process models** are now fully editable (node-level), which helps Priority 3 work and enables a
  process-backed `startReview` if desired.

---

## Document map (this repo)
- `MergeAssist_Documentation.md` — object-level reference for the live app.
- `docs/01-3wm-application.md`, `docs/02-merge-assist-appian.md`, `docs/03-next-steps-and-action-items.md`, `docs/README.md`.
- `.kiro/steering/00-index.md` + `10–14` (project), `20–21` (practices), `30–34` (SAIL/Appian reference).
- `implementation/priority-1-review-workflow-plan.md`.

---
