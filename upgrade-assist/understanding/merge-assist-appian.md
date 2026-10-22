# Understanding — Merge Assist, the Appian application (the backend we keep)

> **Role in Upgrade Assist:** This Appian application **is** our product today. Upgrade Assist = **keep this entire
> backend** (record types, process models, expression-rule logic, converters) and **replace its SAIL front-end** with a
> React component plugin + Java suite plugin, following the Synapse pattern. Read this to understand what exists, what
> is reusable, and the hard internal-platform dependencies.

- **Environment:** the connected Appian dev environment (via the `appian` Dev MCP in this workspace).
- **Captured:** 2026-10-22 (live via MCP: application-objects + expression-rule inventory + conversation with the owner).
- **Naming note:** customers disliked the name "Merge Assist"; the **new application is called "Upgrade Assist."** The
  existing Appian app is still named Merge Assist (prefix `MA`). This doc describes the existing `MA` app.

---

## 0. Applications in the environment

| App | UUID | Prefix | Purpose |
|---|---|---|---|
| **Merge Assist** | `33060c62-b495-4c03-9948-206c2f976d2b` | `MA` | The product. |
| **Merge Assist Tester** | `_a-0000efec-4e49-8000-9be6-011c48011c48_75004` | `MAT` | Test harness: compares our XML→diff converters' output against the environment's **native** `getObjectFn` diff data, per object type, via expression rules exposed as Web APIs. |

## 1. Object inventory (Merge Assist, `MA`)

- **7 record types** — the persisted data model (replaces 3WM's SQLAlchemy models):
  - `MA_REC_MergeSession` (sessions), `MA_REC_ObjectClassification` (one row per classified object),
    `MA_REC_ObjectAiSummary` (async AI summary per classified object).
  - Lookups: `MA_REC_SessionStatus`, `MA_REC_ObjectClassificationStatus`, `MA_REC_ObjectReviewStatus`, plus system `User`.
- **9 process models** — the workflow engine (replaces the `ThreeWayMergeOrchestrator`):
  `MA Inspect Package`, `MA Extract Package`, `MA Create New Session`, `MA Process Session Packages`, `MA View Diff`,
  `MA Review Objects`, `MA Generate AI Summaries` + `… Batch`, `MA View Process Model Diff`.
- **107 expression rules** — the logic layer (see §3).
- **14 interfaces** — the SAIL front-end + a reusable UI kit (see §5). **This is what the React port replaces.**
- **1 site** — `MA_MergeAssist` (`merge-assist`, sidebar layout, Home → `MA_DSH_homePage`). The current entry point.
- **29 constants** — reference-ID enums (session statuses 1–5, classifications New=1/Updated=2/Conflict=3, review
  statuses Pending/Reviewed/Approved/Rejected/Skipped, AI-summary statuses, batch size = 5) + folders + reused
  `AS_CO_*` platform-common constants.
- **1 connected system** — `MA_TEST_CS_HTTP` (temporary, for converter self-test).
- **8 folders**, 7 groups (MA Administrators/Users/Alerts + reused solution groups). No Web APIs/agents/CDTs/data stores
  in the `MA` app itself (AI summarisation calls an AI Skill from a process model).

## 2. Classification model (as implemented in Appian)

Simplified vs 3WM to three classifications, driven by reference-id constants:

- **New** (`MA_REF_ID_OBJECT_CLASSIFICATION_NEW = 1`)
- **Updated** (`= 2`) — treated as **"Safe"** (safe-to-import) in the UI; shown green.
- **Conflict** (`= 3`) — needs manual review; shown red.

Review lifecycle per object: Pending → Reviewed / Approved / Rejected / Skipped. Progress is computed dynamically by
`MA_QR_getReviewProgress` (aggregation over `MA_REC_ObjectClassification` by review-status).

## 3. The logic layer — 107 expression rules

Grouped by job:

### 3a. The converter family (the crown jewels) — `MA_convert_*` + `MA_convertXmlToDiffMap`
One rule per object type that **converts exported object XML (as JSON) into a normalized "diff map"** the diff framework
consumes. Dispatcher: **`MA_convertXmlToDiffMap`** (the Appian analogue of 3WM's `parser_factory`). Converters exist for:
`application, connectedSystem, constant, dataStore, dataType, group, groupType, interface, knowledgeCenter, processModel,
processModelFolder, recordType, rule, decision, integration, site, webApi, translationString, translationSet, aiSkill,
controlPanel`. These map directly onto 3WM's ~12 parsers + comparison strategies.

### 3b. Diff-data derivation (the left/right feeders — see §4)
- `MA_UT_deriveDiffObjectDataFromEnv` — builds the structured payload from the **live environment object** (the reliable
  "left" side).
- `MA_UT_deriveDiffObjectDataFromXml` — builds the **same structure from the uploaded package XML** (the "right" side —
  harder; complete for some object types, pending/imperfect for others).
- `MA_UT_returnDiffConfigForGivenObject`, `MA_UT_updateDiffConfigsWithSupportedSections`, `MA_returnObjectConfig`,
  `MA_returnObjectInfoAsMap` — per-object diff configuration + which sections are supported.
- Resolver/util helpers that call internal platform functions: `MA_util_resolveGroupDisplay`,
  `MA_util_resolveConnectedSystem`, `MA_util_resolveInputTypeName`, `MA_util_buildContentParent`,
  `MA_util_xmlTypeToAppianType`, `MA_util_convertRoleMap[_V2]`, `MA_util_transformNodeForFramework`, etc.
- Session/classification plumbing: `MA_UT_constructObjectClassifications`, `MA_getValidObjectTypes`,
  `MA_UT_updateDocumentIdForObjects`, `MA_UT_returnContentSubTypeId`, `MA_QR_getSessions`, `MA_QR_getObjectClassification`.

### 3c. AI-summary pipeline (Priority 4)
`MA_UT_buildAiSummaryContent` (resolve SAIL / XML→JSON, truncate to 6000 chars) → `MA_UT_buildAiSummaryBatchJson` →
(AI Skill) → `MA_UT_parseAiSummaryResults` / `MA_UT_buildFailedAiSummaries` → `MA_QR_getAiSummary`. Batched async
(batch size 5) after a session reaches READY.

### 3d. Reused platform-common libraries (not ours, do not port)
`AS_CO_*` (Appian Solutions common: query/cast/null-safety/CDT utilities) and `AS_GSS_*` helpers. There are also several
`MA_TMP_*` / `MA_Test*` scratch rules (converter-debugging; not product surface).

## 4. The three-way model, normalized onto the environment

The product is still **three-way**, but normalized so the customer leg is the **live environment** instead of an upload:

| Leg | 3WM (desktop) | Merge Assist / Upgrade Assist (Appian) |
|---|---|---|
| **Base** (e.g. Source Selection 1.0) | uploaded ZIP | **optional** upload |
| **Customized** (customer's current state) | uploaded ZIP | **the hosting environment itself** (app is installed into the customer's customized env) — read live via `…FromEnv` |
| **Latest / New Vendor** (e.g. 5.0) | uploaded ZIP | **required** upload — read via `…FromXml` |

**Session behavior by what you upload:**

- **Latest only** → one diff per object: **Latest vs Environment**.
- **Latest + Base** → object diff view gets a **dropdown** to switch comparisons.

**The three pairings (the full design):**

| Pairing | Meaning | Status |
|---|---|---|
| **Latest vs Environment** | new vendor release vs the customer's current (customized) state — the actual merge surface | ✅ implemented |
| **Base vs Latest** | pure vendor delta (1.0 → 5.0), independent of customizations | ✅ implemented (when Base uploaded) |
| **Base vs Environment** | pure **customer customization** delta (what the customer changed on base) | 🔜 **planned, not yet implemented** |

Having all three lets a reviewer reason about *why* something conflicts (vendor touched it **and** customer touched it),
not just that it differs. **Design implication for React:** treat "comparison pairing" as a **first-class selectable
dimension** from the start (up to 3 options, gated on whether Base was uploaded) — encode it in component `state`.

## 5. The SAIL front-end — what the React port replaces

- **Pages:** `MA_DSH_homePage` (dashboard), `MA_FM_createNewSession` (new-session form, with the upload options),
  `MA_sessionSummary` (record view), `MA_FM_reviewObjects` (one-by-one review workflow),
  `MA_renderDiffViewForObject` (the object diff view — the hardest screen),
  `MA_SEC_viewDependentsAndPrecedents` (dependency inspection in the review flow).
- **Reusable UI kit** (nice to know — React will re-create these as components): `MA_UI_statusChip`,
  `MA_UI_sectionHeader`, `MA_UI_statCard`, `MA_UI_emptyState`, `MA_UI_kpiDonut`, `MA_UI_objectHeader`,
  `MA_UI_aiSummaryCard`.
- **Display single-sources-of-truth** (reuse the semantics, not the SAIL): `MA_UI_classificationDisplay`,
  `MA_UI_reviewStatusDisplay`, `MA_UI_sessionStatusDisplay` (label/color/bg/icon per status), `MA_UI_sessionEstimates`
  (heuristic effort/complexity from counts).

## 6. ⚠️ Hard dependencies on Appian **internal** platform functions (the biggest risk area)

To build this natively, the team deliberately reused **undocumented internal Appian functions/frameworks** not meant for
app developers. This has three consequences the React port must plan around:

1. **The internal diff-view framework is the current diff renderer.** It takes a **left** and **right** structured
   payload and draws the comparison. Our converters exist to produce those payloads:
   - **Left = Environment** → `MA_UT_deriveDiffObjectDataFromEnv` (reliable; object is native).
   - **Right = Uploaded XML** → `MA_UT_deriveDiffObjectDataFromXml` (reconstruct the *same* structure from XML; done for
     some object types, **still pending/imperfect for others** — matching the internal shape exactly is the active pain).

   > **Critical porting insight:** the internal framework does **two** jobs — it defines the **data contract** *and* it
   > is the **renderer**. A React component **cannot embed the internal renderer**, so the diff visualization must be
   > **rebuilt in React**. The **converter layer carries over** (it is the valuable asset) and would be surfaced to React
   > via a suite-plugin client API / expression function returning the diff map as JSON. Silver lining: owning the
   > renderer lets us define our **own** canonical diff schema, which may make the still-pending XML conversions *easier*
   > (target a format we control instead of reverse-engineering the internal one).

2. **Dependents/precedents** in the review workflow also use internal functions to resolve the object dependency graph;
   these must likewise be surfaced through the suite plugin for React to call.

3. **MCP read limitation (known, accepted):** the Dev MCP often **cannot read interfaces/expression rules that reference
   these internal functions**. Expect some `MA_*` objects to be opaque to tooling/agents. Treat an unreadable object as
   **"references internal functions," not broken** — flag it, don't guess at or fabricate its contents.

## 7. Reusability summary (keep vs rebuild)

| Layer | Verdict |
|---|---|
| Record types / data model (`MA_REC_*`) | **Keep as-is.** |
| Process models (session/extract/diff/review/AI) | **Keep**, expose actions to React via client APIs. |
| Converters (`MA_convert_*`, `MA_convertXmlToDiffMap`) + diff-data derivation | **Keep** — the core asset; surface output as JSON. |
| Classification / review / AI-summary logic | **Keep.** |
| Internal diff-view **renderer** | **Cannot reuse** — rebuild in React. |
| Dependents/precedents internal functions | **Keep logic**, wrap in a suite-plugin client API. |
| SAIL pages + `MA_UI_*` kit | **Replace** with React components (reuse the display semantics / SoT rules). |
| Site `MA_MergeAssist` | Replaced by the React component mounted in a SAIL interface (Synapse pattern). |

## 8. Open questions to resolve before/while porting

1. **Diff rendering strategy:** keep feeding the internal framework in a SAIL pane (React handles only shell/nav), or
   **own the diff rendering in React** off a converter-produced JSON schema? (This is the single biggest decision.)
2. Which screens port first? (Dashboard + session create are easy wins; **the object diff view is the hard core**.)
3. How complete are the XML converters per object type today — which object types still don't match the env structure?
4. What suite-plugin client-API surface do we need (diff-map fetch, dependents/precedents, session/review writes,
   AI-summary fetch), and how much of Synapse's suite plugin can we reuse vs build fresh?
5. Confirm scope/sequencing for the planned **Base vs Environment** pairing in the new UI.
