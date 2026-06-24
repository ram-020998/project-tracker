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

### May 21, 2026 — New Object Type Converters + Process Model Rewrite

#### Completed

**Object type coverage analysis across test packages:**

| Object Type | V1 (GSS) | V2 (CaseManagement) | V2 (RenRe) | Conversion Rule Status |
|---|---|---|---|---|
| content (rules/interfaces/constants/integrations/decisions) | 2121 | 1177 | 1982 | ✅ Existed |
| translationString | — | 793 | 1934 | ✅ NEW - Built & tested |
| translationSet | — | 1 | 3 | ✅ NEW - Built & tested |
| groupType | — | — | 1 | ✅ NEW - Built & tested |
| controlPanel | — | 1 | — | ✅ NEW - Built & tested |
| aiSkill | 1 | — | — | ⚠️ No native diff config — needs custom renderer |
| processModel | 108 | 72 | 101 | 🔄 Rewriting — value extraction issue |
| datatype | 107 | 4 | 49 | ✅ Existed |
| group | 93 | 9 | 15 | ✅ Existed |
| recordType | 48 | 70 | 89 | ✅ Existed |
| dataStore | 9 | 2 | 3 | ✅ Existed |
| connectedSystem | 6 | — | 2 | ✅ Existed |
| webApi | 4 | — | 1 | ✅ Existed |
| processModelFolder | 4 | 2 | 3 | ✅ Existed |
| site | 3 | 1 | 3 | ✅ Existed |
| application | 1 | 2 | 4 | ✅ Existed |

**New conversion rules built (file: `sail-conversion-rules/MA_convert_new_types.sail`):**

| Rule | Key Fields | Notes |
|---|---|---|
| `MA_convert_translationString` | `id, uuid, description, translationSetId, translatorNotes, versionUuid, translatedText[{id, locale{id,locale}, translatedText}], translationStringVariables` | Working. System expects `translatedText` not `translationTexts`. |
| `MA_convert_translationSet` | `id, uuid, name, description, versionUuid, enabledLocales[{id,locale}], defaultLocale{id,locale}, enabledLocalesValue, defaultLocaleValue, stringCount, stringData, totalCount, parent, saveIn, roleMap{inherit, entries}` | Working. Required `totalCount: 0` (page handler accesses `ri!left.totalCount`), `stringData: {}`, `enabledLocales.id` must be integer (not null). `en-US` = locale ID 17. |
| `MA_convert_groupType` | `id, uuid, name, description, groupTypeAttributes[{name, type, value}]` | Working. Simple structure. |
| `MA_convert_controlPanel` | `controlPanel{id, name, description, urlStub, settings{displayName, objectStorageCfg, primaryRecordCfg, brandingCfg, hierarchyCfg}}, interfaceTypes, interfaces, referenceableRecordTypes, customPages, roleMap` | Working. Deeply nested — diff config uses `fieldPath: {"controlPanel", "settings", "..."}`. |

**Dispatcher updates (in `MA_convertXmlToDiffMap`):**
- Added: `translationstring`, `translationset`, `aiskill`, `controlpanel`, `grouptype`
- Improved `content` subtype handling: auto-detects rule/interface/constant/knowledgeCenter/document/ruleFolder/documentFolder

**Process Model converter rewrite (`sail-conversion-rules/MA_convert_processModel_v2_part*.sail`):**
- Split into 4 parts for manageability
- Nodes now include framework-expected fields: `inputs`, `hiddenInputs`, `events`, `customOutputs`, `resultOutputs`, `conditions`, `customParameters`, `complexGatewayData`
- `activityClass.parameters` → named map (name→value) via `a!mapFromLists`
- `hiddenInputs` → name→value map of hidden ACPs
- `inputs` → visible non-hidden ACPs as list with string `value`
- Conditions extracted from XOR (`core.4`) and complex gateway (`core.7`) rules
- Lanes have `uniqueId` field (format: `"<name><index>"`)
- `other` map includes `multipleInstance`, `whenNodeIsChained`, `whenNodeIsCompleted`, `whenNodeIsExecuted`

#### Decisions Made

| Decision | Reasoning |
|---|---|
| `translationString` doesn't use native diff for translationSet's `stringData` section | We output `stringData: {}` and `totalCount: 0` to skip the translation strings paging section which requires real environment data |
| `aiSkill` skipped for native diff | No entry in `a!dod_config_getTypeMap()` — it's a "remote design object" type. Needs custom diff interface. |
| Locale ID `17` hardcoded for `en-US` | Standard across all Appian environments. Other locales mapped in `local!localeIdMap`. |
| `controlPanel` uses nested `controlPanel.settings.*` structure | Diff config uses `fieldPath: {"controlPanel", "settings", "hierarchyCfg", "..."}` — must match exactly |
| Process model nodes split into inputs/hiddenInputs/parameters(map) | `a!dod_pm_node_updateFieldsForFramework` does this transformation; we replicate it |

#### Technical Learnings

1. **`translationset` diff uses `diffPresentationConfigFn`** (lambda, not static config) — it passes `ri!left`, `ri!right`, `ri!pagingInfo` to build sections. The `translationStringPageHandler` accesses `ri!left.totalCount` — if missing, crashes.
2. **`a!dod_fwk_createDiffComponent` wraps handler calls in `fn!try`** — any handler crash becomes generic "An error has occurred on a diff field" message. The catch block calls `a!dod_fwk_logFieldDiffException` then `fn!error()`.
3. **`enabledLocales[].id` must be integer** for translation sets — the config uses `fv!item.id` to build `fieldPath: "locale-" & fv!item.id` and `"stringCount"` lookup by locale ID.
4. **`controlpanel` and `grouptype` have native diff configs** but `aiSkill` does not.
5. **Process model `activityClass.parameters`** must be a named map (not a list) — the setup section configs access `activityClass; parameters; isTransparent` etc. via nested field paths.
6. **`dod_config_securitySection`** expects `roleMap.inherit` (boolean), `roleMap.entries` (list), `parent`, `saveIn` fields on the object.
7. **Process model nodes need `inputs`/`hiddenInputs` split** — `dod_config_pm_node_dataSection` accesses these directly. `hiddenInputs` is a name→value map, `inputs` is a list of ACP-like maps.
8. **`org.json.XML.toJSONObject` value extraction issue** — when XML has `<a:value xsi:type="xsd:boolean">true</a:value>`, it becomes `{xmlns: "", xsi:type: "xsd:boolean", content: true}` in the JSON. However, `fn!index(map, "content", null())` is NOT finding the `content` key in Appian. `fn!try(ri!val.content, null())` also fails. **This is the current blocker for process model rendering.**

#### Issues Encountered

| Issue | Resolution |
|-------|-----------|
| `translationSet` crash at section 3 | `totalCount: 0` missing — `translationStringPageHandler` accesses `ri!left.totalCount` |
| `translationSet` crash — locale iteration | `enabledLocales[].id` was null — must be integer (17 for en-US) |
| `translationSet` crash — stringData | Changed from `null()` to `{}` — iteration over null crashes |
| `translationSet` security section crash | Added `roleMap.inherit`, `parent`, `saveIn` fields |
| `processModel` crash at node setup section | `activityClass.parameters` was a list, must be named map |
| `processModel` crash — End Node isTransparent | Raw XML typed value map `{xmlns:"", xsi:type:"xsd:boolean", content:true}` passed to checkbox handler instead of boolean `true`. **`fn!index(map, "content", null)` returns null.** Root cause: Appian's map key lookup cannot find `"content"` key on maps produced by `a!fromJson(xmlToMap(...))`. UNRESOLVED. |

#### Current Blocker

**`fn!index` cannot extract `"content"` key from typed value maps produced by `xmlToMap`/`a!fromJson`.**

The XML `<a:value xsi:type="xsd:boolean">true</a:value>` becomes JSON `{"xsi:type":"xsd:boolean","content":true}` via `org.json.XML.toJSONObject`. After `a!fromJson`, accessing `fn!index(map, "content", null)` returns null. Dot access `map.content` also fails.

**Next steps to diagnose:**
1. Evaluate `tostring(fn!index(nodes, 2, a!map()))` to see the raw ACP structure from xmlToMap
2. Check if the key is actually `"content"` or something else (empty string, `#text`, etc.)
3. May need a plugin function to properly extract typed values from XML ACPs
4. Alternative: pre-process the entire JSON in the plugin before returning (extract all typed values at the Java level)

#### Remaining Items

- [ ] **Process model — resolve `content` key extraction issue** from xmlToMap typed value maps
- [ ] **Process model — XOR conditions not extracting** (rules ACP value is still raw map with `a:acps`)
- [ ] **aiSkill — custom diff interface** (no native diff config)
- [ ] **Content subtype dispatching** — document, ruleFolder, documentFolder cases
- [ ] **Test all converters with V1 GSS packages** (larger/more complex PMs)

---

### May 22, 2026 — Plugin Approaches for Universal XML→Diff Conversion (ALL FAILED)

#### Goal

Eliminate per-type SAIL conversion rules by building a plugin that converts vendor package XML directly to the diff-ready JSON format that `a!dod_fwk_sectionsGenerator` expects.

#### Research Findings (AE Repo)

**Key internal classes discovered:**

| Class | Path | Purpose |
|---|---|---|
| `XmlContext` | `com.appiancorp.ix.xml.XmlContext` | Holds static `JAXBContext` with all Haul classes registered. Field `context` is package-private. |
| `XmlProducer` | `com.appiancorp.ix.xml.XmlProducer` | Unmarshals XML via JAXB, calls `registerCustomAdapters()` and `afterUnmarshal()` |
| `ProcessModelAdapter` | `com.appiancorp.ix.xml.adapters.ProcessModelAdapter` | XmlAdapter for PM. Has `ThreadLocal<ServiceContext> SC` that MUST be set before unmarshal. Calls `ProcessPortService.deserializeProcessModelForIx(Element)` |
| `ProcessPortService` | `com.appiancorp.process.ProcessPortService` | `deserializeProcessModelForIx(Node)` — converts PM DOM → ProcessModel without needing object in environment |
| `ProcessPortServiceLocator` | `com.appiancorp.process.ProcessPortServiceLocator` | `getProcessPortService(ServiceContext)` — gets the service via ServiceLocator |
| `DiffProcessModelConverter` | `com.appiancorp.designobjectdiffs.converters.processmodel.DiffProcessModelConverter` | Spring bean. `convertModel(ProcessModel, EvalPath, AppianScriptContext)` → `DiffProcessModelDto`. Has 8 sub-converter dependencies. |
| `GetProcessModelVersion` | `com.appiancorp.designobjectdiffs.functions.processmodel.GetProcessModelVersion` | Java function `dod_getprocessmodelversion`. Calls `DiffProcessModelConverter.convertModel()` then `dto.toTypedValue()` then `Value.fromTypedValue(tv)` |
| `DiffProcessModelDto` | `com.appiancorp.type.cdt.DiffProcessModelDto` | Generated CDT class (not in compile JARs). Has `toTypedValue()`. |
| `IxDocumentManager` | `com.appiancorp.object.action.IxDocumentManager` | `toJson(TypedValue, TypeService)` → JSON string. `fromJson(String, TypeService)` → TypedValue. Used by Connected Environments. |
| `DodToJson` / `DodFromJson` | `com.appiancorp.designobjectdiffs.functions.encoding.*` | SAIL functions `a!dod_encoding_toJson` / `a!dod_encoding_fromJson`. JSON channel normalization. |
| `dod_connEnv_simulateConnectedEnvReturn` | SAIL rule | Just does `a!dod_encoding_fromJson(a!dod_encoding_toJson(ri!diffObject))` — JSON roundtrip normalization |
| `ApplicationContextHolder` | `com.appiancorp.common.config.ApplicationContextHolder` | Static access to Spring application context. `getBean(Class)` method. |
| `ServiceContextProvider` | `com.appiancorp.services.spring.ServiceContextProvider` | Spring bean. `getServiceContext()` → ServiceContext |
| `ContentHaul` | `com.appiancorp.ix.data.ContentHaul` | Haul for content types. `getIxObject()` returns FreeformRule/Constant/Integration/etc. |
| `ProcessModelHaul` | `com.appiancorp.ix.data.ProcessModelHaul` | Haul for PMs. `getProcessModel()` returns ProcessModel (only works if adapter SC was set) |
| `Type.HAUL_CLASSES` | `com.appiancorp.ix.Type` | Set of all Haul classes registered for JAXB |
| `ObjectReadSupport` | `com.appiancorp.object.action.read.ObjectReadSupport` | Interface for reading objects from DB by UUID. Used by `appdesigner_actionReadByUuid`. NOT usable for vendor XML (reads from DB only). |
| `UuidReadActionHandler` | `com.appiancorp.object.action.read.UuidReadActionHandler` | Handles `readByUuid` action. Calls `ObjectReadSupport.read(uuid)` which reads from **database**. |
| `JSONSerializerUtil` | `com.appiancorp.process.common.presentation.JSONSerializerUtil` | `marshall(Object, ServiceContext)` / `unmarshall(String, Class, ServiceContext)` — used by Connected Environments for PM JSON transport |

**The diff framework's `testObject` parameter:**
- `dod_pm_getDiffObject` accepts `ri!testObject` — if provided, skips UUID lookup and uses the object directly
- `dod_record_getDiffObject`, `dod_config_decision_getObjectFn`, `dod_config_document` also support this
- BUT: the subsequent transformations in `getDiffObject` (security, display names, etc.) still call environment-dependent functions

**Connected Environment flow:**
- Remote env calls `getObjectFn(uuid)` → produces diff object → `IxDocumentManager.toJson()` → sends JSON over HTTP → client calls `IxDocumentManager.fromJson()` → produces Map
- For PM specifically: uses `JSONSerializerUtil.marshall(pm, sc)` to serialize the raw ProcessModel to JSON, then deserializes on client

#### Plugin 1: `xml-converter-plugin` (unmarshalXmlToJson)

**Location:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-v2/xml-converter-plugin/`
**Approach:** JAXB unmarshal + getter-based serialization to JSON

**What worked:**
- ✅ `XmlContext.context` accessible via reflection (`Field.setAccessible(true)`)
- ✅ JAXB unmarshal works for ContentHaul (interfaces, rules, constants)
- ✅ `ContentHaul.getIxObject()` returns FreeformRule with `getDefinition()` already in display form
- ✅ Getter-based serialization produces clean JSON with proper field names
- ✅ Expression resolution happens automatically (`FreeformRule.getDefinition()` converts stored→display form)
- ✅ All content type fields accessible: name, uuid, description, definition, parameters, attributes, etc.

**What failed:**
- ❌ `Gson.toJson(haul)` → `StackOverflowError` (circular references in Appian type system objects)
- ❌ `Gson` with ExclusionStrategy → `Failed making field 'javax.xml.namespace.QName#namespaceURI' accessible` (JDK module access)
- ❌ `Gson` with TypeAdapters → `Failed making field 'java.util.concurrent.atomic.AtomicReference#value' accessible`
- ❌ Process Model XML unmarshal → `javax.xml.bind.UnmarshalException` (needs ProcessModelAdapter with ServiceContext ThreadLocal)
- ❌ Content type output doesn't match diff framework format directly (needs field renaming + `inputs` restructuring)

**Serialization issues encountered:**
1. Gson reflection fails on JDK internal classes (Java 17 module system)
2. Object graph has circular references (Type → Storage → Type)
3. `getCoreTypeInfo()` getter returns the entire Appian type hierarchy (massive recursive structure)
4. Raw getter serialization includes infrastructure fields not needed for diff

**Final state:** Works for content types but output requires light SAIL transformation. Doesn't work for process models.

#### Plugin 2: `xml-diff-converter-plugin` (convertXmlToDiffObject)

**Location:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-v2/xml-diff-converter-plugin/`
**Approach:** JAXB unmarshal + Spring DiffProcessModelConverter + getter-based serialization

**What failed:**
- ❌ PM unmarshal → `javax.xml.bind.UnmarshalException` even with adapters registered
- ❌ `registerAdapters()` succeeds but PM still fails because `ProcessModelAdapter.SC` ThreadLocal is null during JAXB's internal adapter callback
- ❌ Setting `ProcessModelAdapter.SC` before calling unmarshal doesn't help — JAXB creates a new adapter instance that doesn't see the ThreadLocal (different thread context)
- ❌ Even without adapters, PM unmarshal fails because the XML has elements that require custom adapters (`<pm>` contains typed values that JAXB can't handle without the adapter)

**Root cause:** JAXB's unmarshalling of ProcessModelHaul is fundamentally tied to the `XmlProducer` lifecycle which sets up adapters in a specific way. A standalone `Unmarshaller` can't replicate this.

#### Plugin 3: `vendor-diff-plugin` (vendorXmlToDiffJson) — Approach A: IxDocumentManager.toJson

**Location:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-v2/vendor-diff-plugin/`
**Approach:** JAXB unmarshal → `toTypedValue()` → `IxDocumentManager.toJson(tv, typeService)`

**What failed:**
- ❌ `FreeformRule` doesn't implement `IsTypedValue` and has no `toTypedValue()` method
- ❌ Wrapping raw object in `TypedValue` manually → `IxDocumentManager.toJson()` rejects it: "The value parameter must be a CDT, a dictionary, a map, a record, or a list"
- ❌ `IxDocumentManager.toJson()` ONLY accepts CDTs/Maps/Dictionaries — not raw domain objects like FreeformRule, ProcessModel, Constant

**Root cause:** `IxDocumentManager.toJson()` is designed for already-transformed diff objects (which are Maps/CDTs), not raw domain objects. The transformation step MUST happen before serialization.

#### Plugin 3: `vendor-diff-plugin` — Approach B: DOM + ProcessPortService

**Approach:** Skip JAXB entirely for PM. Parse XML as DOM → find `<process_model_port>` element → `ProcessPortService.deserializeProcessModelForIx(element)` → `DiffProcessModelConverter.convertModel(pm)` → serialize

**Status:** Built but not validated. Expected to work since `ProcessPortService` is designed exactly for this use case (deserialize PM from XML without importing).

**Dependencies required:**
- `ServiceContext` from `ServiceContextProvider` Spring bean
- `ProcessPortServiceLocator.getProcessPortService(sc)` → ProcessPortService
- `DiffProcessModelConverter` from Spring for diff-ready format (optional — raw PM can be serialized via getter-walker as fallback)

#### Why No Plugin Approach Fully Works

1. **The diff framework expects specific map shapes** that are produced by SAIL `getObjectFn` lambdas per-type. These lambdas call environment-dependent functions (`a!dod_security_getRoleMap`, `a!dod_displayName_contentDisplay`, `a!dod_testValues_interface_getTestCases`).

2. **Raw domain objects ≠ diff-ready maps.** A `FreeformRule` has `definition`, `name`, `parameters[]`. The diff framework expects `expression`, `inputs[{key,value,description}]`, `roleMap{...}`, `parent{name,id,uuidForDiff}`. This transformation is NOT a simple rename — it involves resolving type names, security, parent folders.

3. **`IxDocumentManager.toJson()`** only works on CDTs/Maps (output of converters), not on raw objects (input to converters).

4. **JAXB for PM requires the full `XmlProducer` lifecycle** — standalone unmarshalling fails because the `ProcessModelAdapter` callback needs ThreadLocal context that JAXB's internal adapter management doesn't propagate correctly.

5. **`DiffProcessModelConverter`** produces the exact right format but requires Spring beans + the PM must be deserialized first (which requires `ProcessPortService` + `ServiceContext`).

6. **There is no single "XML → diff map" function in Appian.** The architecture is: XML → Haul → import to DB → `ObjectReadSupport.read(uuid)` → DTO → `getObjectFn` SAIL transformation → diff map. Skipping the "import to DB" step breaks the chain.

#### Viable Remaining Options

1. **Continue with SAIL converters (current approach)** — Fix the `content` key extraction issue for PM ACPs. The plugin (`xml-converter-plugin`) works for content types and provides clean typed values. Only PM needs the SAIL-level `unwrapValue` fix.

2. **DOM + ProcessPortService for PM only** — Build a plugin function that takes PM XML, parses as DOM, calls `ProcessPortService.deserializeProcessModelForIx()`, then serializes the raw `ProcessModel` via getter-walker. The SAIL converter then only needs to do the structural transformation (split ACPs, build conditions) on clean typed values.

3. **Accept that SAIL converters are needed** — The diff framework was designed with SAIL `getObjectFn` as the transformation layer. Fighting this architecture has diminishing returns.

#### Decisions

| Decision | Reasoning |
|---|---|
| Abandon `IxDocumentManager.toJson()` approach | Only works on already-transformed CDTs, not raw objects |
| Abandon universal "zero SAIL" plugin approach | Diff framework requires per-type SAIL transformations for security, display names, parent resolution |
| Keep `xml-converter-plugin` for content types | Works, provides clean typed values, expression resolution is automatic |
| JAXB cannot unmarshal ProcessModelHaul standalone | Requires XmlProducer lifecycle + ProcessModelAdapter ThreadLocal |
| DOM + ProcessPortService is viable for PM | Bypasses JAXB entirely, uses Appian's own PM deserializer |

#### Files Created This Session

| File | Purpose |
|---|---|
| `xml-converter-plugin/` | JAXB unmarshal + getter-walker. Works for content types. |
| `xml-diff-converter-plugin/` | Failed attempt with Spring converter + JAXB for all types |
| `vendor-diff-plugin/` | Latest attempt: DOM for PM, JAXB for content, IxDocumentManager (failed) |

#### Updated Remaining Items

- [ ] **Fix PM `content` key issue** — try DOM+ProcessPortService plugin for clean PM values, OR fix SAIL unwrapValue
- [ ] **Validate `xml-converter-plugin` for all content types** — rules, constants, integrations, decisions
- [ ] **Build thin SAIL converters for content types** — ~5 lines each using plugin output
- [ ] **Process model converter** — either fix SAIL unwrapValue or use ProcessPortService plugin
- [ ] **aiSkill — custom diff interface**
- [ ] **Test with full vendor packages (V1 GSS, V2 CaseManagement)**
- [ ] **Explore `solutions-atlas-parser` approach** — Python-based XML→JSON per-type parser exists at `appian/prod/solutions-atlas-parser`. Could port logic to Java plugin or use as reference for SAIL converters. Has parsers for: process_model, interface, expression_rule, constant, decision, integration, record_type, site, web_api, group, connected_system, control_panel, translation_set, translation_string, ai_skill, data_store, cdt, document, folder, application.

#### GitLab Research (`gitlab.appian-stratus.com/appian/prod`)

| Project | URL | Relevance |
|---|---|---|
| `plugin-xmltools` | https://gitlab.appian-stratus.com/appian/prod/plugin-xmltools | Same `org.json.XML.toJSONObject()` approach as our `xmlToMap`. Has `stringsOnly` and `removeNamespace` params. Same `content` key issue applies. |
| `cs-plugin-cdt-diff-utilities` | https://gitlab.appian-stratus.com/appian/prod/cs-plugin-cdt-diff-utilities | Diffs CDT runtime instances — not useful for package XML comparison |
| `ps-plugin-ProcessModelUtilities` | https://gitlab.appian-stratus.com/appian/prod/ps-plugin-ProcessModelUtilities | Reads PMs from DB via ProcessDesignService. Not from XML. |
| **`solutions-atlas-parser`** | https://gitlab.appian-stratus.com/appian/prod/solutions-atlas-parser | **Most relevant.** Python tool that parses ALL Appian package XML types into structured JSON. Per-type parsers in `appian_parser/parsers/`. Validates our SAIL converter approach is correct architecture. Cannot run inside Appian (Python). |
| `solutions-atlas-mcp-server` | https://gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server | MCP server using atlas-parser output — not directly useful |
| `solutions-atlas-kb` | https://gitlab.appian-stratus.com/appian/prod/solutions-atlas-kb | Parsed knowledge base output — not useful |

---

### June 15, 2026 — Native conflict detection: base inspect removed, plugin emits `conflicted`

#### Context
The classification used **two** `inspectPackage` calls (base + vendor) cross-referenced to find
conflicts. Discovered that `com.appiancorp.suiteapi.ix.ImportResults` already exposes a first-class
**`getConflictedObjects()`** bucket (native conflict detection) that `InspectPackageService` was
ignoring — so a **single vendor inspect** can yield New/Safe/Conflict directly.

#### Completed

**Plugin — `InspectPackageService.java`:** emit the `conflicted` bucket.
- Added `json.put("conflicted", toObjectArray(results.getConflictedObjects()))` + `summary.conflicted`
  count + updated `LOG.info`. No other accessors changed.
- **Signature unchanged** (1 input `PackageDocument`, 1 output `ResultJson`) → smart-service key
  **`inspectPackageV2` kept** (no `IncompatibleSmartServiceRegistrationException`; hot-deployable).
- Built with JDK 17 (`JAVA_HOME=temurin-17 ./gradlew clean jar`) → `merge-assist-plugin-1.0.0.jar`.
  Redeployed + tested by user: `conflicted` is populated.

**Verified bucket semantics (real sample):** `summary {created:1, updated:6, notChanged:31,
conflicted:5, failed:0}`. **`updated` ⊇ `conflicted`** (all 5 conflicted UUIDs were also in updated) →
**Safe = updated − conflicted**. `conflicted` entries can omit `type`, so name/type come from
`updated`/`created`; `conflicted` used only as a UUID set. Sample ⇒ 1 New / 1 Safe / 5 Conflict.

**Appian app — `MA_UT_constructObjectClassifications` (via LCP MCP):** rewritten to the single-inspect
model. `baseResponse` input removed; conflict set = `vendorResponse.conflicted`; validity checks only
the vendor response; G7 count logic preserved. `validateDesignObject` clean.

#### Decisions
| Decision | Reasoning |
|---|---|
| Use `getConflictedObjects()` (native conflict detection) | Standard Appian feature; one inspect instead of two; removes cross-reference complexity |
| Keep base upload + extraction (`baseXmlDocId`) | Still powers the "Base Vs Vendor Latest" diff (`MA_renderDiffViewForObject` diffViewType 2) — only the base **inspect** is removed |
| Don't bump the smart-service key | Output JSON content changed but the parameter signature didn't, so `inspectPackageV2` stays valid |

#### Remaining (user / Designer)
- [ ] `MA Process Session Packages` (`0002efa8-20a2-…`): remove node 2 "Inspect Base Package",
      reconnect Start→Inspect Vendor, update node 3 to call the rule with `vendorResponse` + `session`
      only.
- [ ] End-to-end validation on a real session; confirm both diff modes still render.

#### Files changed
`plugin/src/main/java/com/appiancorp/mergeassist/smartservice/InspectPackageService.java`
(+ live edit of `MA_UT_constructObjectClassifications`). Full write-up:
`merge-assist-appian/docs/04-single-inspect-conflict-detection.md`.

---

### June 19, 2026 — Native process-model diff (no SAIL converter); right-side PM blocker solved

#### Goal
Replace the blocked `MA_convert_processModel` SAIL converter (stuck on the `xmlToMap` `content`-key
extraction bug, §"May 21/22" current blocker) by reusing Appian's own machinery: the **import
deserializer** + the **native diff converter**.

#### What works (validated end-to-end — the PM diff renders)
- **New plugin function `pmXmlToDiffJson(documentId)`** added to the **merge-assist plugin**
  (`plugin/src/main/java/com/appiancorp/mergeassist/functions/PmXmlToDiffJsonFunction.java`; registered
  in `appian-plugin.xml`; bundle `pmXmlToDiffJson_en_US.properties`; builds into
  `merge-assist-plugin-1.0.0.jar`).
- Pipeline: read package XML → **namespace-aware** DOM, re-root `<process_model_port>` into its own doc
  → `ProcessPortService.deserializeProcessModelForIx(node)` (off-DB; defers datatype resolution; skips
  XSD validation) → sanitize → `DiffProcessModelConverter.convertModel(pm, evalPath, ctx)` (reflective)
  → return `DiffProcessModelDto.toTypedValue()`.
- Context: `ServiceContext` injected as a function param; `AppianScriptContextBuilder.init().serviceContext(sc).build()`
  + `EvalPath.init().insideDiffGetObjectFunction()`.
- **SAIL wiring (Designer):** feed the raw DTO through the diff config's getObjectFn via its `testObject`
  hook so it gets the framework transforms (esp. `node_updateFieldsForFramework`, parameters list →
  name-keyed map): `a!dod_pm_getDiffObject(testObject: pmXmlToDiffJson(documentId: rv!vendorXmlDocId))`
  on the right side of `MA_renderDiffViewForObject`.

#### How the earlier blockers were cleared (iteration log)
1. plugin i18n bundle path must match `<plugin-key>.<module-key>`.
2. `ServiceContext` via Spring bean returned null → inject it as a function parameter instead.
3. deserialize NPE → parse DOM **namespace-aware** + **re-root** the port element (JAXB `W3CDomHandler` parity).
4. `getProcessModelFromPortXml(false)` failed XSD on record-type datatype QName (`n1:<uuid>`) → use the
   **IX** deserializer (`deserializeProcessModelForIx`), which defers datatype resolution.
5. `convertModel` "Invalid class for Value of type Group" (custom alert recipients) → `setNtfSettings(null)`.
6. `IxDocumentManager.toJson` / SAIL "No DataHandler for ExternalTypedValue" → return the `TypedValue`
   directly AND null deferred `ExternalTypedValue` placeholders on process variables + node ACPs
   (ProcessVariable/ActivityClassParameter both extend TypedValue; carried values were null → ~lossless).
7. `sectionsGenerator` "Cannot index 'pmUUID' into DiffActivityClassParameterDto?list" → the missing
   framework reshaping → fixed by the `a!dod_pm_getDiffObject(testObject: …)` wiring (step above).

#### Decisions
| Decision | Reasoning |
|---|---|
| Reuse import deserialize + native `DiffProcessModelConverter` instead of SAIL | `convertModel` takes an in-memory `ProcessModel` bean off-DB; `deserializeProcessModelForIx` produces it from XML without persisting |
| IX deserializer (not `getProcessModelFromPortXml`) | IX defers datatype resolution + skips XSD validation that rejects record-type datatype UUID-QNames |
| Feed DTO through `a!dod_pm_getDiffObject(testObject:)` | applies the framework transforms (`node_updateFieldsForFramework` etc.) so both diff sides share one pipeline |
| Sanitize alerts + ExternalTypedValue | env-absent groups/record-types can't resolve off-import; values were null → near-lossless |
| Reflective calls for `DiffProcessModelConverter`/`DiffProcessModelDto`/`ApplicationContextHolder` | no compile dependency on the `design-object-diffs` jar |

#### Files
- `plugin/src/main/java/com/appiancorp/mergeassist/functions/PmXmlToDiffJsonFunction.java` (new)
- `plugin/src/main/resources/appian-plugin.xml`, `.../mergeassist/pmXmlToDiffJson_en_US.properties`
- Standalone POC (built first, then ported): `pm-diff-poc-plugin/` (key `com.appiancorp.pmdiff`).
  **Undeploy it before deploying the merge-assist plugin** — same `pmXmlToDiffJson` key would conflict.

#### Remaining
- [ ] Harden against PMs with explicit user/group node assignees, subprocess nodes, and the large
      V1 (GSS) / V2 packages.
- [ ] Generalize to **record types** (the other blocked converter) via the same pattern (deserialize
      haul → native record diff converter → config `testObject` hook).

Full write-up: `merge-assist-appian/docs/05-native-process-model-diff.md`.

---

### June 22, 2026 — PM diff integration; diagram-section fix; open record-view NPE

Integrated the native PM diff into the live app and worked through two post-deployment runtime issues.

#### Integration
- `MA_renderDiffViewForObject` refactored into `{data,error}` helpers (`MA_UT_deriveDiffObjectDataFromXml`
  / `…FromEnv`, `MA_UT_returnDiffConfigForGivenObject`, `MA_UT_updateDiffConfigsWithSupportedSections`),
  generator `try`-wrapped.
- `MA_convertXmlToDiffMap` gained an `xmlDoc` param; **PM branch routes to**
  `a!dod_pm_getDiffObject(testObject: pmXmlToDiffJson(documentId: xmlDoc))`.

#### Issue 1 — PM diagram → `GeneratePmDocAction` "Does not exist: Process Model" (✅ fixed)
First PM `diffPresentationConfig` section is the diagram (`a!dod_config_pm_diagramSection()`), which draws
the model image via `GeneratePmDocAction` → `getProcessModelVersion` against the DB; the vendor version
isn't resident → error (separate servlet request; diff body still renders). **Fix:** drop the diagram
section for PMs, keyed off **`objectTypeName`** (not `objectTypeId` — at runtime in the record-action
path the id wasn't reliably 23, so an id branch silently didn't fire though it worked in Designer).

#### Issue 2 — record-view context NPE on opening the PM diff (⏳ open)
After a restart, opening the PM diff → `NPE Value.getMemoryWeight() because "o" is null` at
`AppianBindingsTop.initializeMemoryWeightAndAttachListener` on `reevaluateRecordView` (preceded by
`Unable to find bindings … Using initial bindings`) for the `MA_REC_MergeSession` record view — a
**Java-null binding** during context build. Live `MA_renderDiffViewForObject` + helper were read; SAIL is
sound → persistence/context-layer failure. **Hypothesis:** the `DiffProcessModelDto` can't be
persisted/rehydrated in saved record-view state (same family as the `ExternalTypedValue` "No DataHandler"
issue) → rehydrates null after restart. **Mitigations:** hard-refresh; render diff as a **transient
related-action dialog** (keep the DTO out of persisted bindings); stub the PM branch to confirm causation.

**Update (later 2026-06-22):** root cause confirmed/refined — the diff value carries record-type/Variant
typed Values that don't survive **live stateful-UI state serialization** (Designer renders; record
action *and* start form fail; other object types fine). Plugin fix: `nullIfExternal` now also **retypes**
unresolved `ExternalTypedValue` PV/ACP slots to Text (`setInstanceType(3)`) — rebuilt, compile-verified.
That cleared the NPE but live render then failed with `Variant?list must be used within a SAIL
component`; section-by-section testing localized it to PM config **index 6 = `node_main`** (per-node
detail: ACP params, event mappings, MNI/other-data, assignment — sites the PV/ACP retype misses).
**Fix path:** type-erase the PM diff object via `a!fromJson(a!toJson(...))` around `MA_convert_processModel`
output (class-level fix); stopgap = drop `node_main` for PMs (lossy). ⏳ awaiting live verification.

Full detail: `merge-assist-appian/docs/05-native-process-model-diff.md` §10–§11.

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
