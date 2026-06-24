# Feature 1 — Data Integrity: Implementation Plan

**Status:** ✅ IMPLEMENTED — Work Items A, B, C, D complete (see §0). CDT rollback (`cdt/delete`) deferred.
**Spec:** `changes_V1/spec.md` §2 (decisions D1–D6)
**Goal:** Move table-coverage from probabilistic steering to a **deterministic, machine-checkable contract**: the parser emits a per-node `writes` set (record **and** CDT/DSE) into every bundle, the Atlas MCP composes an FK-closed required-table set for a chosen path, and the power enforces a **hard-block coverage gate** before and after execution.

> Reading order for an implementer: §1 (what exists today) → §2 (target data contract) → §3–§7 (per-repo work) → §8 (sequencing) → §9 (testing) → §10 (deploy) → §11 (risks) → §12 (acceptance).

---

## 0. Implementation status (last updated 2026-06-23)

| Work item | Status | Notes |
|-----------|--------|-------|
| **A — Parser** (`solutions-atlas-parser`) | ✅ **DONE — merged to `dev/main`, synced to KB, validated** | Per-node `writes` (RECORD + CDT), `gateway_conditions`, distinct `WRITE_RECORDS`/`WRITE_DSE` node types; CDT `@Table` + constant DataStoreEntity-ref extraction. 319 parser tests pass; validated across 8+ real packages and in the live KB. |
| **B — Atlas MCP** (`solutions-atlas-mcp-server`) | ✅ **DONE — on branch `feature/f1-write-set-tools` (awaiting user commit/merge)** | `get_entry_point_write_graph` + `resolve_write_set` (FK closure + business/task-mgmt filter + branch pruning). 81 tests pass; real-KB smoke test on SourceSelection returned a 12-table FK-closed set. |
| **C — ADG app + DG MCP** | ✅ **DONE** (CDT rollback deferred) | ADG side: 4 rules + `cdt` Web API (`write`/`properties`/`query`) verified live. DG MCP side: client methods + `DseTools` (3) + `verify_write_coverage` + `_post` error handling + CDT session tracking, on branch `feature/f1-cdt-dse-tools`, 43 tests pass, all verified live. Deferred: `cdt/delete` + `delete_data_store_entity` for CDT rollback. |
| **D — Power steering (gate)** | ✅ **DONE** (both copies) | New `step-4b-coverage-gate.md` (HARD BLOCK via `resolve_write_set`); `step-1` uses `get_entry_point_write_graph`/`resolve_write_set` + records entry_points/branch_decisions; `step-6-execute` mechanism-aware dispatch + post-exec `verify_write_coverage`; tool-reference docs updated; `action-generate-data` pipeline runs step-4b between 4 and 5; `step-0` creates `coverage-gate.md`; POWER.md + `.kiro/steering.md` updated. Applied to dev + prod; parity verified. |

**Work Item C breakdown:**

| Piece | Status | Detail |
|-------|--------|--------|
| `ADG_UT_getCdtProperties(namespace, tableName)` | ✅ DONE + **verified via `cdt/properties` (HTTP 200)** | Returns `{fieldName: typeName}` via `getdatatypefields_appian_internal`. CDT analogue of `a!recordTypeProperties`. API `properties` branch wraps it: `{ success:true, properties:{field:typeName} }`. Surfaces nested reference types (e.g. `AS_GSS_User`, `AS_GSS_R_Data`). |
| `ADG_UT_getConstantReferenceByName(constantName)` | ✅ DONE | `eval("cons!" & name)` → resolves a DataStoreEntity constant name to its writable reference. |
| `ADG_UT_constructCdtValue(namespace, cdtName, fields)` | ✅ DONE | Builds a populated, type-coerced CDT (`valueToStore`) via `eval("'type!{ns}name'()")` + `a!update` + `ADG_UT_convertFieldValue`. uuid `_a-…_75999`. |
| `ADG_UT_writeDataStoreEntity(dseData)` | ✅ DONE — validated | Full handler (CDT analogue of `createOrUpdateRecords`): validate → resolve entity → construct CDT → `a!writeToDataStoreEntity(... fv!storedValues)` → 200/500 `httpResponse`. uuid `_a-…_76012`. Note: `a!writeToDataStoreEntity` onError exposes **no** `fv!error`; onSuccess uses **`fv!storedValues`** (plural). |
| `ADG_UT_queryDataStoreEntity(constantName, selectedFields, filters, pagingInfo)` | ✅ DONE + **verified via `cdt/query` (HTTP 200)** | CDT analogue of `ADG_UT_queryRecordTypeWithFilters` via `a!queryEntity`. uuid `_a-…_76027`. Returns `{ success, totalCount, data }`; auto-resolves nested reference CDTs. Verified: `totalCount:28` on `AS_GSS_EVALUATION`. |
| `ADG_API_cdtOperations` Web API | ✅ DONE + **verified end-to-end (HTTP 200)** | urlAlias `cdt`, POST, uuid `57716022-…`. Routes on `index(http!request.pathSegments,1)`: `write`→`ADG_UT_writeDataStoreEntity`, `properties`→`ADG_UT_getCdtProperties`. **Body is unwrapped, top-level `{ constantName, namespace, cdtName, fields }`** (key is `constantName`, not `dataStoreEntityConstant`). Success → `{ success:true, storedValues:[…] }`. Verified `POST /suite/webapi/cdt/write` inserted a real `AS_GSS_EVALUATION` row (PK auto-assigned). |
| DG MCP `write_data_store_entity` (client + tool + schema + session-tracking) | ✅ BUILT + **verified live via DseTools** | `client.write_data_store_entity` → `POST /suite/webapi/cdt/write`; `DseTools.write_data_store_entity` accepts `cdt_type` (`{ns}name`, auto-split) or explicit `namespace`+`cdt_name`; tracks PK via `SessionManager.track_cdt`. Real DseTools call stored `evaluationId:37`. |
| DG MCP `get_cdt_properties` tool | ✅ BUILT + **verified via real client** | `client.get_cdt_properties` → `cdt/properties`; `DseTools.get_cdt_properties`. Real-client smoke returned 32 props for `AS_GSS_Evaluation`. |
| DG MCP `query_data_store_entity` tool | ✅ BUILT + **verified live via DseTools** | `client.query_data_store_entity` → `cdt/query`; `DseTools.query_data_store_entity`. Real DseTools call returned `success:true, totalCount:28`. (API namespace guard relaxed to per-branch validation.) |
| DG MCP `verify_write_coverage` tool | ✅ BUILT + **verified live (CDT) + unit-tested** | `CoverageTools.verify_write_coverage`: per required table (RECORD→`query_records` by uuid, CDT→`query_data_store_entity` by constant) counts rows vs `min_rows`, returns `{pass, covered, missing}`. Live smoke: covered table `found_rows:29 ok:true`, no-match filter `found_rows:0 ok:false`. 43 tests pass. |
| Client `_post` 4xx handling | ✅ DONE + unit-tested | `AppianClient._post` now surfaces JSON `{success:false}` bodies as `AppianAPIError` (even on 4xx), falling back to `raise_for_status()` only for non-JSON bodies. Benefits record + CDT tools. 35 tests pass. |

**Deferred / out of scope (V1):** cross-module DSE constants in the ISU app that lack an inline entity reference (graceful degradation, no error) — see §11.

**Commits:** All A/B code changes are on feature branches; the user is handling commits/merges. ADG objects are created live in the ADG app via lcp-mcp-server.

---

## 1. Current state (grounded)

| Area | Finding | File / location |
|------|---------|-----------------|
| Node extraction | `_extract_nodes` already produces rich node dicts: `node_id`, `node_type` (raw activity-class local-id, e.g. `internal3.write_records_to_source_23r3`), `node_name`, `gateway_conditions` (already extracted for gateway types), `inputs[{input_name,input_expression}]`, `outputs[{save_into,output_expression}]`, `interface_uuid`, `subprocess_uuid`. | `appian_parser/parsers/process_model_parser.py` L195+ |
| Write detection (legacy) | `_extract_writes_to` already knows the three write node types and a `recordType!` regex, but emits a **flat, bundle-level, name-only** `writes_to` list — no per-node, no UUID/table, no DSE resolution. | `appian_parser/output/bundle_builder.py` L507+ |
| Write node types (reuse) | `{internal3.write_records_to_source_23r3, appian.system.smart-services.write-to-data-store, appian.system.smart-services.multi-write-to-data-store}` | `bundle_builder.py` L~512 |
| recordType regex (reuse) | `recordType!\{([^}]+)\}(\w+)` → group(1)=uuid, group(2)=name | `bundle_builder.py` L~518 |
| Active v3 builder | `bundle_structure_builder._build_flow_graph` produces the KB's `flow.process_model.nodes[]` (only `name`,`type`,`next`,`subprocess`,`interface`). `_NODE_TYPE_MAP` **flattens** `"Write Records" → SCRIPT_TASK`, **losing write identity**, and drops `gateway_conditions` + `inputs`. | `appian_parser/output/bundle_structure_builder.py` L23, L186+ |
| KB reality | Grep across `current/` for `writes_to` = **zero matches** → the v3 structure builder is what populates `current/bundles/`; the legacy `writes_to` is not in the KB. **Manual SAIL reading is today's root cause of dropped tables.** | `solutions-atlas-kb/data/<App>/current/bundles/*.json` |
| CDT parser | Extracts per-field `@Column name="..."` from JPA appinfo via regex; **no class-level table name**. | `appian_parser/parsers/cdt_parser.py` `_extract_fields` |
| Data store parser | Emits `entities[{entity_uuid, entity_name, cdt_type}]` → DSE→CDT binding exists. | `appian_parser/parsers/data_store_parser.py` |
| Schema artifacts | `record_type_map.json` (table→uuid+name+relationships), `relationships.json` (174 FKs), `insertion_order.json`, `table_classification.json` (business/reference/audit/task_management/framework), `summary.json`. | `current/schema/*.json` |
| Atlas MCP tool pattern | Tools = classes with `@staticmethod async def(arguments)`; read KB via `GitLabDataSource.read_json(app_name, rel_path)`. Register in `server.py` `tool_handlers` dict + `tools/__init__.py` + `models.py` `ToolSchemas.get_all_tools()`. | `atlas_mcp/server.py`, `atlas_mcp/tools/*`, `atlas_mcp/models.py` |
| DG MCP tool pattern | `tools/` classes; `_shared` singletons `get_client/get_registry/get_session`; `AppianClient._post(path,payload)` to `/suite/webapi/{record|users}/…`; schemas in `models.py`; register in `server.py` `tool_handlers` + `tools/__init__.py`. | `data_generator/*` |
| ADG runtime CDT helper | `ADG_UT_getCdtProperties` (uuid `_a-0000eff6-da77-8000-9bf2-011c48011c48_75944`) already returns CDT field metadata (CDT analogue of `ADG_UT_getRecordTypeProperties`). | ADG app |

**Key implication:** most plumbing already exists. The work is to (a) move write-extraction into the **active** v3 builder at **per-node** granularity, (b) add the CDT/DSE branch + CDT→table link, (c) surface gateway conditions, (d) add two read tools to Atlas MCP, (e) add a DSE write path + coverage-verify to DG/ADG, (f) wire the gate into steering.

---

## 2. Target data contract

### 2.1 Per-node `writes` (in `flow.process_model.nodes[]`)

```jsonc
{
  "name": "Write Award Decision",
  "type": "WRITE_RECORDS",                 // no longer flattened to SCRIPT_TASK
  "next": ["Notify Vendor"],
  "gateway_conditions": [                    // only on gateway nodes
    { "condition": "pv!approved = true", "to": "Notify Vendor" },
    { "condition": "else", "to": "Reject" }
  ],
  "writes": [
    {
      "mechanism": "RECORD",                 // RECORD | CDT
      "table": "AS_GSS_AWARD_DECISION",
      "operation": "WRITE",                  // best-effort; gate keys on table presence
      "record_type_uuid": "ddf6d201-…",
      "record_type_name": "AS_GSS_AwardDecision",
      "via": "internal3.write_records_to_source_23r3"
    },
    {
      "mechanism": "CDT",
      "table": "AS_GSS_EVALUATION",
      "operation": "WRITE",
      "data_store_entity": "AS_GSS_ENT_Evaluation",
      "cdt_type": "{urn:…:AS_GSS}AS_GSS_Evaluation",
      "via": "appian.system.smart-services.write-to-data-store"
    }
  ]
}
```

### 2.2 CDT object gains a bound table (D6.1)

`current/objects/.../<CDT>.json` `type_specific` gains `table: "AS_GSS_EVALUATION"` (from XSD `@Table`, column-set fallback).

### 2.3 `resolve_write_set` output (Atlas MCP, computed — not stored)

```jsonc
{
  "entry_points": ["AS_GSS_Award_Vendor"],
  "branch_decisions": { "Approved?": "yes" },
  "required_tables": [
    { "table": "AS_GSS_REQUEST",        "classification": "business",        "reason": "written by node 'Update Request'", "mechanism": "RECORD" },
    { "table": "AS_GSS_AWARD_DECISION", "classification": "business",        "reason": "written by node 'Write Award Decision'", "mechanism": "RECORD" },
    { "table": "AS_GSS_EVALUATION",     "classification": "business",        "reason": "FK prerequisite of AS_GSS_AWARD_DECISION", "mechanism": "RECORD" }
  ],
  "excluded_tables": [
    { "table": "AS_GSS_REJECTION", "reason": "branch 'Approved?=yes' not taken" }
  ]
}
```
Only `business` + `task_management` tables appear (D3); reference/audit/framework are filtered out via `table_classification.json`.

---

## 3. Work item A — Parser (`solutions-atlas-parser`)

### A1. Extract a `WriteExtractor` helper (shared)
- **New file:** `appian_parser/parsers/write_extractor.py`.
- Lift the constants/logic currently inside `bundle_builder._extract_writes_to` into reusable functions:
  - `WRITE_NODE_TYPES` (the 3 known types).
  - `RT_PATTERN = re.compile(r"recordType!\{([^}]+)\}(\w+)")`.
  - `extract_node_writes(node, *, record_type_map, dse_index, cdt_table_index) -> list[dict]` returning the §2.1 `writes` entries.
- Mechanism split:
  - `internal3.write_records_to_source_23r3` → `RECORD`: scan `inputs[].input_expression` + `outputs[]` for `recordType!{uuid}name`; resolve `table` via `record_type_map` (uuid→table; fallback name→table).
  - `appian.system.smart-services.write-to-data-store` / `…multi-write-to-data-store` → `CDT`: scan inputs for the DSE constant ref (`cons!{uuid}NAME` / entity reference) → look up `dse_index` (entity→`cdt_type`) → `cdt_table_index` (`cdt_type`→`table`).
- `operation`: best-effort `WRITE` (D4). Optionally refine `INSERT`/`UPDATE` if statically obvious, but the gate keys on `table`.

### A2. CDT→table extraction (D6.1)
- **File:** `cdt_parser.py`.
- Add class-level `@Table(name="…")` extraction: read the complexType-level `xsd:annotation/xsd:appinfo` JPA text and apply `re.search(r'@Table\([^)]*name="([^"]+)"', text)`. Mirrors the existing `@Column` approach.
- Store `data['table'] = <table>` (None if absent).
- **Fallback** (annotation absent): build `cdt_table_index` by matching the CDT's `column_name` set against `tables.json` columns (best column-set overlap). Implement in a small post-extraction step (where `record_type_map`/`tables.json` are available) so the CDT cache + tables are both present.

### A3. Build the resolution indexes
- Where the schema cache is assembled (alongside `record_type_mapper.py` / bundle coordination), build:
  - `dse_index`: `entity_name`/`entity_uuid` → `cdt_type` (from data store parser `entities[]`).
  - `cdt_table_index`: `cdt_type` → `table` (from A2).
- Pass these into the structure builder.

### A4. Emit per-node `writes` + gateway conditions in the **v3** builder
- **File:** `bundle_structure_builder.py` `_build_flow_graph`.
- For each raw node `n`:
  - Add `node_entry['writes'] = extract_node_writes(n, …)` when non-empty.
  - Surface `node_entry['gateway_conditions'] = n['gateway_conditions']` when present (already parsed — just stop dropping it).
  - **Stop flattening write identity:** add explicit `_NODE_TYPE_MAP` entries so write nodes get a distinct type, e.g. `'Write Records' → 'WRITE_RECORDS'`, `'Write to Data Store Entity' → 'WRITE_DSE'`, `'Write to Multiple Data Store Entities' → 'WRITE_DSE'`. (Keep other mappings unchanged.)
- Keep output additive — existing consumers that read `name/type/next` are unaffected.

### A5. Decommission legacy `writes_to` / `BundleBuilder` — **VERIFIED SAFE TO REMOVE**
- **Verification (2026-06-23):** `writes_to` has **zero consumers**. It appears only inside `bundle_builder.py` itself (L506/509/581). The legacy `BundleBuilder` class is **never imported or instantiated** anywhere — the active pipeline is `cli.py` → `BundleCoordinator` → `BundleFileBuilder` → `BundleStructureBuilder` (v3). No references in Atlas MCP, DG MCP, power steering, `tests/`, or the KB `current/**`.
- **Action:** make the shared `write_extractor` (A1) the single source of truth, then **delete the orphaned `bundle_builder.py` / `BundleBuilder`** (and its `_extract_writes_to`) to prevent drift. Confirm nothing in `parser_registry.py` / dynamic loaders references it before deletion (grep clean as of verification).
- If a reviewer prefers caution, downgrade to: keep the file but route `_extract_writes_to` through `write_extractor` and add a deprecation note. Default recommendation: **remove**, since it is dead code.

### A6. Tests
- `tests/parsers/test_write_extractor.py`: RECORD + CDT extraction from sample node dicts; uuid/name/table resolution; DSE→CDT→table chain; empty/no-write nodes.
- `tests/parsers/test_cdt_parser.py`: `@Table` extraction + column-set fallback.
- `tests/output/test_v3_builders.py`: extend `test_process_model_concatenates_nodes` to assert `writes` + `gateway_conditions` + distinct write type appear on nodes.
- Run against `test_data/AS_GSS_Full_Application.zip` end-to-end; assert a known write node (e.g. `AS_GSS_FM_completeEvaluation` path) yields its table.

---

## 4. Work item B — Atlas MCP (`solutions-atlas-mcp-server`)

### B1. New tool module `atlas_mcp/tools/write_set.py`
Class `WriteSetTools` with two static async tools, reading KB via `GitLabDataSource`.

**`get_entry_point_write_graph(app_name, entry_point)`**
- Resolve bundle (reuse `_resolve_bundle_id` pattern from `bundle.py`), read `current/bundles/{id}.json`.
- Return `flow.process_model.nodes[]` projected to `{name, type, next, gateway_conditions, writes}` + subprocess graphs. Lets the agent *see* the data flow.

**`resolve_write_set(app_name, entry_points[], branch_decisions{})`**
- Load each entry point's bundle nodes + subprocess nodes.
- Walk the flow honoring `branch_decisions` (gateway label/condition → chosen edge); collect `writes[].table` for nodes on the selected path. Nodes on unselected branches → `excluded_tables` with the branch reason.
- **FK closure:** load `relationships.json`; for every collected table add its FK-parent business/task-mgmt tables transitively (use `insertion_order.json` for ordering).
- **Classification filter:** load `table_classification.json`; keep only `business` + `task_management` (D3).
- Return the §2.3 structure (deterministic; no free reasoning).

### B2. Register
- `tools/__init__.py`: export `WriteSetTools`.
- `server.py`: import + add `"get_entry_point_write_graph"` and `"resolve_write_set"` to `tool_handlers`.
- `models.py`: add input schemas to `ToolSchemas.get_all_tools()` (`app_name` required; `entry_points` array; `branch_decisions` object).

### B3. Tests
- `tests/test_write_set.py`: fixture bundle with a gateway + RECORD + CDT writes; assert path resolution, FK closure, classification filtering, branch exclusion. Mock `GitLabDataSource.read_json`.

---

## 5. Work item C — ADG app + DG MCP (DSE write path + coverage verify)

> **Status note (2026-06-23):** the ADG side (C1) is **built and validated** — see §0 for object uuids. The contract below reflects what was actually implemented, which differs from the original draft (a **dedicated `cdt` Web API**, not the `record` router; rule input is a **`dseData` map**).

### C1. ADG DSE write rule + Web API — ✅ DONE
- **`ADG_UT_writeDataStoreEntity(dseData)`** (uuid `_a-…_76012`) — CDT analogue of `ADG_UT_createOrUpdateRecords`. Input `dseData` map: `{ dataStoreEntityConstant, namespace, cdtName, fields }`. Flow: validate → `ADG_UT_getConstantReferenceByName` (resolve writable entity) → `ADG_UT_constructCdtValue` (typed, coerced CDT) → `a!writeToDataStoreEntity(dataStoreEntity, valueToStore, onSuccess, onError)` → 200/500 `a!httpResponse`.
  - **Signature gotchas (from Appian 26.5 docs):** `onSuccess` exposes **`fv!storedValues`** (plural, Any Type); `onError` exposes **no** function variable (unlike `a!writeRecords`, so no `fv!error`). The multi-entity variant is `a!writeToMultipleDataStoreEntities(valuesToStore, …)` taking `a!entityData(entity, data)` — not needed for single-CDT writes.
- Supporting rules (all done): `ADG_UT_getCdtProperties(namespace, tableName)`, `ADG_UT_getConstantReferenceByName(constantName)`, `ADG_UT_constructCdtValue(namespace, cdtName, fields)`.
- **Web API:** **`ADG_API_cdtOperations`** (uuid `57716022-…`, urlAlias **`cdt`**, POST). Dedicated `cdt` router — **all methods invoked via POST** (`POST /suite/webapi/cdt/{method}`). Mirrors `ADG_API_recordOperations` (`record` router).

### C2. DG MCP `write_data_store_entity` tool — ⬜ PENDING
- **`client.py`:** add `write_data_store_entity(constant_name, namespace, cdt_name, fields)` → `_post("/suite/webapi/cdt/write", {constantName, namespace, cdtName, fields})`. **Verified contract:** body is unwrapped/top-level (key `constantName`, not `dataStoreEntityConstant`); success → `{success:true, storedValues:[…]}`.
- **New tool class** `DseTools` in `tools/dse.py` (mirror `RecordTools.create_record`): validate `{constantName, namespace, cdtName, fields}`, call client, track in `SessionManager` for rollback. PK comes back in `storedValues[0]` (DB-assigned identity → capture for rollback/FK refs).
- **`get_cdt_properties` tool** — the `cdt` API **does** expose `properties` (→ `ADG_UT_getCdtProperties(namespace, tableName=cdtName)`); add `client.get_cdt_properties(namespace, cdt_name)` → `_post("/suite/webapi/cdt/properties", {namespace, cdtName})` and a tool for it.
- **`query_data_store_entity` tool** — the `cdt` API exposes `query` (→ `ADG_UT_queryDataStoreEntity`, uuid `_a-…_76027`); add `client.query_data_store_entity(constant_name, selected_fields, filters, paging_info)` → `_post("/suite/webapi/cdt/query", {constantName, selectedFields, filters, pagingInfo})` → `{success, totalCount, data}`. Used by `verify_write_coverage` for CDT-backed tables (the record path uses `query_records`).
- Register all in `models.py` `ToolSchemas` + `server.py` `tool_handlers` + `tools/__init__.py`.
- **Rollback:** add a `cdt/delete` method (delete-from-DSE by PK) or soft-delete via `isActive=false` where present.

> **Deriving `namespace` + `cdtName` (input sourcing for the agent/tool):** for CDT objects the KB stores the type's qualified name in the object's `uuid` field as `{namespace}cdtName`, e.g. `"AS_GSS_Evaluation": { "uuid": "{urn:com:appian:types:AS:GSS}AS_GSS_Evaluation", "type": "CDT", … }`. Split it: `namespace` = text between `{`…`}` (`urn:com:appian:types:AS:GSS`), `cdtName` = text after `}` (`AS_GSS_Evaluation`). This is the **same `{namespace}cdtName` form** the parser already emits as `cdt_type` on a CDT write entry, so `write_data_store_entity` / `get_cdt_properties` / `query_data_store_entity` can split on `}` from either the KB object `uuid` or the bundle write entry. The `constantName` (DataStoreEntity) comes from the write entry's `data_store_entity`. **Steering + tool-reference docs (Work Item D) must spell this out** so the agent knows where to find namespace/cdtName/constant.

### C3. DG MCP coverage-verify tool (post-execution) — ⬜ PENDING
- **New tool** `verify_write_coverage(required_tables[], root_filters)` in `tools/coverage.py`.
- For each required table, resolve its record-type uuid (agent passes uuid alongside table, or tool calls `record_type_map` via the agent), `query_records` with the root/FK filter, and report `{table, found_rows, ok}`.
- Returns `{covered: [...], missing: [...], pass: bool}`. This is the **post-exec** half of the gate (the pre-exec half is a pure diff the agent computes from `resolve_write_set` vs `payloads.json`).

> Execution routing (D6.2): the agent picks `write_data_store_entity` vs `create_record` based on each write's `mechanism` tag.

---

## 6. Work item D — Power steering (the gate)

### D1. New steering file `steering/step-4b-coverage-gate.md` (hard block between Step 4 and Step 5)
- Inputs: `resolve_write_set(entry_points, branch_decisions)` (Atlas MCP) and the table set present in `payloads/*.json`.
- **Pre-execution diff (HARD BLOCK):** any `business`/`task_management` table in the required set absent from payloads → **STOP**. The agent must diagnose *why* (missed node, wrong branch) and fix before proceeding. The only allowed bypass is an explicit recorded exclusion citing a specific `branch_decision`.
- Output: `coverage-gate.md` with the required set, the payload set, the diff, and any cited exclusions.

### D2. Update `step-1-workflow-analysis.md`
- Replace "manually read every write node" guidance with: call `get_entry_point_write_graph` to enumerate writes deterministically, then record the chosen `entry_points` + `branch_decisions`. Manual SAIL tracing becomes a cross-check, not the source of truth.

### D3. Update `step-6-execute.md`
- After execution, call `verify_write_coverage(...)`; any missing required table → **remediate** (create the missing rows) before marking complete.
- Add mechanism-aware execution: for each payload entry, dispatch `create_record` (RECORD) or `write_data_store_entity` (CDT) per the write's `mechanism`.

### D4. Update `tool-reference-atlas.md` + `tool-reference-data-generator.md`
- Document `get_entry_point_write_graph`, `resolve_write_set`, `write_data_store_entity`, `get_cdt_properties`, `query_data_store_entity`, `verify_write_coverage`.
- **Document where CDT inputs come from:** `namespace` + `cdtName` are parsed from the CDT object's KB `uuid` (`{namespace}cdtName`) or the bundle write entry's `cdt_type`; `constantName` from the write entry's `data_store_entity`. (See §5 C2 note.)

### D5. Apply to **both** power copies
- Dev: `repo-gitlab/ramaswamy.u/atlas-sql-forge/steering/`
- Prod: `repo-gitlab/appian/solutions-os/ai-framework/Engineering/.kiro/powers/atlas-sql-forge/steering/`

---

## 7. Cross-cutting: KB re-parse
After parser changes (A1–A5), the affected apps **must be re-parsed and the KB re-synced** to GitLab before Atlas MCP / steering can use the new `writes`/`gateway_conditions`. Add to the rollout runbook; verify by grepping a refreshed `current/bundles/*.json` for `"writes"`.

---

## 8. Sequencing & dependencies

```
A (parser: writes + CDT→table + gateway emit)  ──► KB re-parse ──► B (Atlas MCP read tools)
                                                                      │
C (ADG DSE rule + DG dse/cdt-props/coverage tools) ───────────────────┤
                                                                      ▼
                                                              D (steering gate)
```
- A must land first (everything reads its output).
- B depends on a re-parsed KB containing `writes`.
- C is independent of A/B and can proceed in parallel (DSE write path + coverage tool).
- D is last (wires A+B+C into the workflow).

---

## 9. Testing strategy

| Layer | Test |
|-------|------|
| Parser unit | `write_extractor` RECORD/CDT; `cdt_parser` `@Table` + fallback; v3 builder emits `writes`/`gateway_conditions`/distinct types. |
| Parser e2e | Parse `AS_GSS_Full_Application.zip`; assert known write nodes resolve to expected tables (RECORD and CDT). |
| Atlas MCP | `resolve_write_set` path-resolution + FK closure + classification filter + branch exclusion (mocked KB). |
| DG MCP | `write_data_store_entity` create + session-track + rollback; `verify_write_coverage` covered/missing; `get_cdt_properties`. |
| Integration (manual) | Run the full power workflow on a known entity in a non-prod env; confirm the pre-exec gate hard-blocks a deliberately incomplete payload, and post-exec verify passes when complete. |

---

## 10. Deployment & rollout
1. Merge parser (A) → run parser on target apps → push KB (`solutions-atlas-kb`) → verify `writes` in bundles.
2. Deploy Atlas MCP (B) image; smoke-test `resolve_write_set`.
3. Deploy ADG rule + Web API method (C1) to the ADG app; deploy DG MCP image (C2/C3).
4. Update both power copies (D); dev first, validate, then prod.
5. Update `mcp.json` only if tool surface names changed (no new server here).

---

## 11. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| CDT lacks `@Table` and column-set fallback is ambiguous | Log unresolved CDTs; surface `table: null` so the gate can flag rather than silently drop; allow a manual override map. |
| DSE constant reference format varies across apps | Unit-test the DSE-ref parser against multiple sample expressions; fall back to entity-name match. |
| Branch-condition expressions not machine-comparable | `resolve_write_set` matches on the parsed `gateway_conditions` label/edge; where ambiguous, require explicit `branch_decisions` from the agent (recorded). |
| KB staleness (gate runs before re-parse) | Gate checks bundle `_metadata` freshness; warn if `writes` key absent (old KB) and instruct re-parse. |
| Legacy `writes_to` drift | Single-source via shared `write_extractor`; remove legacy emitter if unused. |

> **Validation status (2026-06-23):** Work Item A implemented, merged to `dev/main`, and re-synced into the KB. Verified across apps (RECORD + CDT writes, gateway conditions, `WRITE_RECORDS`/`WRITE_DSE` types now present in `current/bundles/*.json`). **Known deferred limitation:** in the live ConnectedUnderwriting (ISU) app, ~4 cross-module messaging `DataStoreEntity` constants are exported without the inline `<value a:id>` entity reference, so those CDT writes resolve to an entity name but no `table` (graceful, no error). Confirmed the parser resolves these correctly when the inline ref is present (backup package: 4/4). Per direction, **not handled in V1** — would need cross-application entity resolution.

---

## 12. Acceptance criteria
- [ ] Re-parsed `current/bundles/*.json` contain per-node `writes` (RECORD + CDT) and `gateway_conditions`; write nodes are no longer flattened to `SCRIPT_TASK`.
- [ ] CDT objects carry a resolved `table` (or explicit null + log).
- [ ] `resolve_write_set` returns an FK-closed business/task-mgmt table set honoring branch decisions; `get_entry_point_write_graph` returns the node/edge/writes graph.
- [ ] DG MCP can write a CDT via `write_data_store_entity` and roll it back; `verify_write_coverage` reports missing tables.
- [ ] The power **hard-blocks** when a required business/task-mgmt table is missing from payloads, with a recorded diagnosis/exclusion path; post-exec verify enforces the same set.
- [ ] All new unit tests pass; parser e2e on the GSS sample resolves known RECORD + CDT writes.
