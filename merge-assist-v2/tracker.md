# Merge Assist v2 — Project Tracker

## Project Overview

**Objective:** Build an Appian-native plugin + application that helps customers manage vendor application upgrades. Users upload base and new vendor packages, the system classifies objects (NEW/SAFE/CONFLICT/CUSTOMIZED/UNCHANGED), and users review differences using Appian's native diff rendering components.

**Repo:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-v2/`
**Start Date:** April 2026
**Status:** Phase 1 MVP — Plugin built and deployed, diff viewer left side working, right side conversion in progress

---

## Architecture

Two deliverables:
1. **Plugin JAR** (`merge-assist-plugin-1.0.0.jar`) — deployed to `_admin/plugins/`
2. **Appian Application** — SAIL interfaces, process models, record types

Plugin uses public Appian SDK. Zero Appian-schema-specific code in the plugin — all object-type awareness lives in SAIL.

---

## Session Log

### April 23–25, 2026 — Plugin Development & Diff Viewer Validation

#### Completed

**Plugin — 5 functions built, compiled, and deployed:**

| Function | Type | File | Purpose |
|----------|------|------|---------|
| `InspectPackageService` | Smart Service | `smartservice/InspectPackageService.java` | Inspects vendor package against environment via `ImportExportService.inspectPackage()`. Returns JSON with created/updated/failed arrays + summary counts. `notChanged` excluded from output (only count in summary). |
| `ExtractPackageObjectsService` | Smart Service | `smartservice/ExtractPackageObjectsService.java` | Unzips vendor package, stores each object XML as document. Returns JSON with uuid/name/objectType/documentId. |
| `xmlToMap` | Expression | `functions/XmlToMapFunction.java` | Generic XML→JSON via `org.json.XML.toJSONObject()` |
| `extractDefinition` | Expression | `functions/ExtractDefinitionFunction.java` | Extracts SAIL from `<definition>` tag (handles CDATA and non-CDATA) |
| `resolveExpression` | Expression | `functions/ResolveExpressionFunction.java` | Converts stored-form SAIL to display form using `FreeformRule.setDefinition()/getDefinition()` |

**ExtractPackageObjectsService — UUID/Name extraction fixed for all object types:**

| Object Type | UUID Source | Name Source |
|------------|-----------|------------|
| Content types (rule, interface, constant, integration) | `<uuid>text</uuid>` | `<name>text</name>` |
| Process Model | `<uuid><![CDATA[text]]></uuid>` → strips CDATA | `name="text"` attribute |
| Record Type | `<uuid>text</uuid>` | `name="text"` attribute |
| Group | `<uuid>text</uuid>` | `<name>text</name>` |
| Site / Web API | `a:uuid="text"` attribute | `name="text"` attribute |
| Data Type (XSD) | URL-decoded filename minus `.xsd` extension | `<xsd:complexType name="...">` attribute |

**Diff Viewer — Left side working for ALL object types:**
- Universal pattern: `a!asSystem_appian_internal(a!dod_fwk_asGetObjectFn(getEditableObjectFn(uuid, version)))` 
- Bypasses `dod_security_getRoleMap` and `dod_displayName_userOrGroup` guards
- Native `diffPresentationConfig` from `a!dod_config_getTypeMap()` renders correctly
- Created 15 diff viewer SAIL prototypes (`prototypes/diff-viewers-all-types.sail`)

**Expression Resolution:**
- `FreeformRule.setDefinition(storedForm)` + `getDefinition()` converts internal form to display form
- Converts `#"SYSTEM_SYSRULES_sectionLayout_v1"` → `a!sectionLayout`, `#"_a-uuid..."` → `rule!MyRule`

**Classification Logic Designed:**
- Two parallel `inspectPackage` calls (base + new vendor) in process model
- Cross-reference matrix: SAFE / CONFLICT / CUSTOMIZED / NEW / UNCHANGED / DEPRECATED

**Documentation:**
- Steering document: `.kiro/steering/project-steering.md` (494 lines, 13 sections)
- Implementation plan: `IMPLEMENTATION_PLAN.md` (935 lines)
- Session progress: `SESSION_PROGRESS.md`

#### Decisions Made

| Decision | Reasoning |
|----------|-----------|
| Third-party distributable plugin | Independent of Appian release cycle, deployable to any environment |
| `inspectPackage()` for classification | Public SDK, read-only, Appian maintains it |
| `FreeformRule.setDefinition()/getDefinition()` for expression resolution | Public SDK, handles all expression types automatically |
| `asSystem_appian_internal + dod_fwk_asGetObjectFn` for left side | Only combination that bypasses all guards for native diff rendering |
| Removed `UnmarshalVendorObjectFunction` | Can't return `Object` type from plugin functions; JAXB approach abandoned |
| Excluded `notChanged` array from inspect output | Too much data; only count needed in summary |
| One class per function | Matches Appian plugin conventions from reference repo |
| Single JSON output from smart services | Simpler process variable management |
| Timestamp + `UNIQUE_NONE` for extracted documents | Avoids `InsufficientNameUniquenessException` on re-runs |
| URL-decode + strip `.xsd` for data type UUIDs | Data types use namespace-qualified filenames, not `<uuid>` elements |

#### Technical Learnings

1. **`a!asSystem_appian_internal()` alone doesn't propagate** into nested function calls — must combine with `a!dod_fwk_asGetObjectFn()` which sets `evalPath.insideDiffGetObjectFunction()` flag
2. **`getObjectFn` fails for interfaces/rules** due to `dod_testValues_interface_getTestCases` error — fallback to `getEditableObjectFn` works
3. **`a!dod_guiUtil_pageView` causes flicker** — use `a!forEach` on components directly instead
4. **Data type files are XSD, not XML** — no `<uuid>` element, UUID is the namespace-qualified filename
5. **Process model `<name>` is a multi-line localized element** — can't use simple `<name>...</name>` extraction, need attribute fallback
6. **`javax.xml.bind` not available in Java 17** — reflection approach to `XmlContext.context` compiles but can't return result to SAIL
7. **Plugin functions cannot return `java.lang.Object`** — Appian rejects it at deployment
8. **Smart service keys cannot change once deployed** — used `inspectPackageV2` when output format changed
9. **`@DocumentDataType`** is at `com.appiancorp.suiteapi.knowledge.DocumentDataType` in SDK 23.2
10. **`ContentService.download()` returns `Document[]`** — use `docs[0].getInputStream()`

#### Issues Encountered

| Issue | Resolution |
|-------|-----------|
| Properties files not included in JAR | Fixed `build.gradle` to include resources from correct path |
| `PortableNamedTypedValueWithChildren` class not found | Added `appian-expression-evaluator.jar` to lib/ |
| `Constant.isEnvironmentSpecific()` doesn't exist in SDK 23.2 | Removed the field from output |
| UUID extraction broken for process models (CDATA) | Added CDATA stripping in `extractUuid()` |
| UUID extraction broken for sites/webApis (attribute) | Added `a:uuid="..."` attribute extraction |
| Name extraction broken for process models (localized XML) | Skip `<name>` elements containing `<` (nested XML) |
| Data type UUID/name garbled (URL-encoded XSD filename) | URL-decode filename, strip `.xsd`, extract name from `xsd:complexType` attribute |
| `UnmarshalVendorObjectFunction` can't return Object | Abandoned approach, removed function |

### May 2, 2026 — Impact Analysis (Dependents & Precedents) Viewer

#### Completed

**Impact Analysis SAIL interface built (`sail-interfaces/MA_impactAnalysis.sail`):**
- Two-tab UI: Dependents (what depends on this object) and Precedents (what this object depends on)
- Uses internal Appian functions: `a!appdesigner_impactAnalysis_objectDependents` and `a!appdesigner_impactAnalysis_objectPrecedents`
- Object type mapping from Merge Assist type names to Appian IA type references (Interface, ContentFreeformRule, Constant, ProcessModel, RecordType, Group, Datatype, WebApiEndpointDesignObject, SiteDesignObject, ConnectedSystem, Decision, OutboundIntegration)
- UUID-based lookup via `uuidAndTypeList` parameter (no object ID needed for dependents)
- Object ID resolution via `fn!objectselect_appian_internal` + `a!aos_getObjects` for precedents
- Resolves object metadata (name, type, description) via `a!aos_getObjects`
- Grid display with icon, name, type, location/breadcrumbs, and sub-dependency count
- Empty state messages for both tabs

**Key internal functions discovered:**

| Function | Purpose |
|----------|---------|
| `a!appdesigner_impactAnalysis_objectDependents` | Fetches objects that depend on a given object. Accepts `uuidAndTypeList` (UUID+type) or `objectId` |
| `a!appdesigner_impactAnalysis_objectPrecedents` | Fetches objects that a given object depends on. Requires `objectId` |
| `fn!objectReadAction_appian_internal` | Low-level function that both wrappers call with action name `"dependents"` or `"precedents"` |
| `fn!objectselect_appian_internal` | Creates an object selection from `id` or `uuid` (dict with type+uuid) |
| `a!aos_getObjects` | Resolves object metadata (name, resource type, description, imageUrl, etc.) from a selection |
| `fn!formatIaGridData_appian_internal` | Formats raw IA data into hierarchical grid rows (used by Appian's own IA UI) |

**Return structure from IA functions:**
```
Dictionary?list where each entry = {
  id, uuid, hasChildren, expanded, numChildren,
  children: [{id, uuid, hasChildren, numChildren, location: Text?list, inApp, inPkg}]
}
```

#### Remaining Items

- [ ] **Right side (vendor) diff conversion** — Find standard way to convert vendor XML → diff-ready format without hardcoding per-type field mapping
- [ ] **Appian application** — Record types (MergeSession, ClassifiedObject, ReviewAction), upload interface, dashboard
- [ ] **Classification process model** — Parallel inspection + cross-reference logic
- [ ] **Review workflow** — Approve/reject/skip per object
- [ ] **Process model diff** — Properties, variables, nodes, connections
- [ ] **Record type diff** — Fields, relationships
- [ ] **Reviewer assignment + notifications**
- [ ] **Excel report generation**

#### Open Questions

1. How to convert vendor XML to the exact same format as `getEditableObjectFn` returns, without manual field mapping per type?
2. Can `dod_connEnv_simulateConnectedEnvReturn` convert a generic map into diff-ready format?
3. Is there a way to call `getObjectFn` with an unmarshalled object from the plugin?

---

## Build & Deploy

```bash
cd plugin
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home ./gradlew clean jar
cp build/libs/merge-assist-plugin-1.0.0.jar <APPIAN_HOME>/_admin/plugins/
```

## Key Files

| File | Purpose |
|------|---------|
| `.kiro/steering/project-steering.md` | Steering document (494 lines, 13 sections) |
| `IMPLEMENTATION_PLAN.md` | Detailed implementation plan (935 lines) |
| `SESSION_PROGRESS.md` | Session progress summary |
| `prototypes/diff-viewers-all-types.sail` | 15 diff viewer SAIL prototypes |
| `prototypes/diff-viewer-rule.sail` | First validated prototype |
| `plugin/src/main/resources/appian-plugin.xml` | Plugin registration |
