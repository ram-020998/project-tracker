---
name: atlas-data-generator
description: Generate realistic, workflow-aware test data in Appian environments. Use when the user asks to create test records, generate data, populate an environment, or set up test scenarios for any Appian application.
---

# Atlas Data Generator

Generate realistic test data for Appian applications by combining schema intelligence from the Atlas KB with write operations via the Data Generator MCP server.

---

## MCP Servers

### appian-atlas (read-only — schema + application intelligence)

| Tool | Purpose |
|------|---------|
| `get_record_type_map(app_name, table_name?)` | **USE FIRST** — Table → record type UUID + relationship names |
| `get_field_map(app_name, table_name?)` | UPPER_SNAKE column → camelCase field name mapping |
| `get_reference_data(app_name, table_name?)` | Reference table metadata: UUID, row_count, ref_types |
| `get_app_schema(app_name, table_name?, classification?)` | Table definitions, columns, types, PKs |
| `get_schema_relationships(app_name, table_name?)` | FK relationships |
| `get_insertion_order(app_name)` | Topologically sorted table list |
| `get_schema_summary(app_name)` | Statistics and table classification |
| `get_app_overview(app_name)` | Application structure, bundles, object counts |
| `search_bundles(app_name, query)` | Find workflow/process bundles by name |
| `get_bundle(app_name, bundle_id, detail_level?)` | Bundle structure, members, flow |
| `search_objects(app_name, query, object_type?)` | Find objects by name |
| `get_object_code(app_name, object_name)` | SAIL code for expression rules |
| `get_dependencies(app_name, object_name)` | What an object calls and what calls it |

### appian-data-generator (write — data operations)

| Tool | Purpose |
|------|---------|
| `get_record_properties(record_type_uuid)` | Field metadata from live environment |
| `create_record(record_type_uuid, fields, related_records?)` | Create record with optional nested children |
| `update_record(record_type_uuid, record_id, fields)` | Partial update |
| `delete_record(record_type_uuid, record_id)` | Soft delete (isActive=false) |
| `query_records(record_type_uuid, filters?, paging_info?)` | Query records (do NOT pass selected_fields) |
| `list_users()` | Available usernames |
| `get_session()` | View created records |
| `rollback_session(confirm)` | Undo all session records |

---

## Critical Rules

1. **Call `get_record_type_map` FIRST** — gives you all UUIDs and relationship names in one call. No need to search for UUIDs.
2. **Call `get_field_map` for field names** — gives exact camelCase names. No guessing.
3. **Query reference data LIVE** — use `get_reference_data` to get the ref table UUID, then `query_records(ref_uuid)` to get actual values from the environment.
4. **Call `list_users` once** — get real usernames.
5. **Follow insertion order** from `get_insertion_order`.
6. **NEVER supply PK values** — auto-generated.
7. **NEVER write to custom/computed fields** (isCustomRecordField=true).
8. **MAXIMIZE field population** — fill ALL writable fields. Document reason for every null.
9. **Do NOT pass `selected_fields`** in queries — always fetch all fields.
10. **NEVER skip milestones** — full workflow every time.
11. **EVERY milestone MUST produce its file on disk** — no exceptions. If the file is not created, the milestone is NOT complete and you CANNOT proceed.

---

## MANDATORY Document Generation

| Milestone | File | Gate |
|-----------|------|------|
| M1 | `analysis.md` | MUST exist before M2 |
| M2 | `exemplar.md` | MUST exist before M3 |
| M3 | `data-architecture.md` | MUST exist before M4 |
| M4 | `payloads.json` | MUST exist before M5 |
| M5 | User says "yes" | MUST have approval before M6 |
| M6 | `execution-log.md` | MUST exist after execution |

**After each milestone:** Create the file → Confirm: "✅ Created: <path>" → Show completion banner → Proceed.

**`payloads.json` is the source of truth for M6.** During execution, use values FROM this file. Do not improvise.

---

## Efficient Data Gathering Pattern

Instead of many scattered calls, use this optimized sequence:

```
Step 1: get_record_type_map(app_name)
        → All table UUIDs + relationship names in ONE call

Step 2: get_field_map(app_name)
        → All column-to-field mappings in ONE call

Step 3: get_reference_data(app_name)
        → All ref table metadata (UUIDs + ref_types) in ONE call

Step 4: list_users()
        → All usernames in ONE call

Step 5: query_records(ref_table_uuid, paging_info={startIndex:1, batchSize:200})
        → Live reference values from environment

Step 6: get_insertion_order(app_name)
        → Creation sequence
```

After these 6 calls you have EVERYTHING needed to generate data. No more calls to Atlas MCP required.

---

## create_record with Related Records

Create parent + children atomically. Appian auto-links FK:

```json
{
  "record_type_uuid": "<from record_type_map>",
  "fields": {
    "<camelCase field from field_map>": "value"
  },
  "related_records": [
    {
      "relationshipName": "<from record_type_map relationships>",
      "recordType": "<child UUID from record_type_map>",
      "records": [
        {"<field>": "value", "<field>": "value"},
        {"<field>": "value", "<field>": "value"}
      ]
    }
  ]
}
```

Rules:
- `relationshipName` comes from `get_record_type_map` → relationships keys
- Child `recordType` UUID comes from `get_record_type_map` → relationships values
- Do NOT include FK field in children — Appian auto-populates it
- Use `get_field_map` for the child table to get correct camelCase field names

---

## Data Generation Workflow: 6 Milestones

### STEP 0: INITIALIZE

**Immediately create the folder and ALL 5 empty files with PENDING status:**
```
data-requests/<date>_<description>/
├── analysis.md           → "# Workflow Analysis\n> Status: PENDING"
├── exemplar.md           → "# Exemplar Discovery\n> Status: PENDING"
├── data-architecture.md  → "# Data Architecture\n> Status: PENDING"
├── payloads.json         → {"status": "PENDING", "records": []}
└── execution-log.md      → "# Execution Log\n> Status: PENDING"
```
Update each file from PENDING → COMPLETE as you finish each milestone.

Create folder `data-requests/<date>_<description>/` for artifacts.

### M1: WORKFLOW ANALYSIS → `analysis.md`

Query Atlas KB for workflow logic:
```
Atlas MCP: search_bundles(app_name, query="<status keywords>")
Atlas MCP: get_bundle(app_name, bundle_id, detail_level="structure")
```
Document: workflow path, transitions, what data is created at each step.

### M2: EXEMPLAR DISCOVERY → `exemplar.md`

Find a real record in target status and document its COMPLETE data footprint:
```
DG MCP: query_records(parent_uuid, filters=[{field:"<statusField>", operator:"=", value:<status_id>}], paging_info:{startIndex:1, batchSize:1})
DG MCP: query_records(parent_uuid, filters=[{field:"<pkField>", operator:"=", value:<id>}])
```
Then for EVERY relationship in `record_type_map`:
```
DG MCP: query_records(child_uuid, filters=[{field:"<fkField>", operator:"=", value:<id>}], paging_info:{startIndex:1, batchSize:50})
```
**Query ALL relationships. Do NOT skip any.**

Document: all fields, all children, patterns observed.

### M3: DATA ARCHITECTURE → `data-architecture.md`

Map tables using data already gathered:
- Tables from `record_type_map`
- Fields from `field_map`
- Reference values from live query
- Insertion order from `get_insertion_order`

**Record Type Coverage Checklist (MANDATORY):**
For EVERY relationship, decide INCLUDE or EXCLUDE with reason:
```
Relationship     | Exemplar Count | Decision
vendor           | 3              | ✅ INCLUDE
criteria         | 2              | ✅ INCLUDE
task             | 5              | ❌ EXCLUDE (auto-generated)
```

### M4: DATA PAYLOADS → `payloads.json`

Generate exact payloads with reasoning for every field value.

**MANDATORY: Field Completeness Verification**

For EACH record type, call `get_record_properties(uuid)` and verify:
1. List ALL writable fields (isPrimaryKey=false AND isCustomRecordField=false)
2. Your payload MUST include every writable field — either with a value or documented as null with reason
3. If coverage < 80% of writable fields → STOP and re-examine

Include in `payloads.json`:
```json
{
  "field_coverage": {
    "<TABLE>": {
      "total_writable_fields": 28,
      "fields_populated": 24,
      "fields_null_with_reason": 4,
      "null_fields": [{"field": "<name>", "reason": "<why>"}]
    }
  }
}
```
```json
{
  "records": [{
    "record_type_uuid": "<uuid from get_record_type_map>",
    "table": "<TABLE_NAME>",
    "fields": {
      "<fieldName>": {"value": "<value>", "reason": "<why this value>"},
      "<statusField>": {"value": "<id>", "reason": "<label> from live query of ref table"}
    },
    "related_records": [...]
  }]
}
```

**All values MUST come from live queries (reference data, users) or logical derivation (dates, booleans). NEVER use hardcoded IDs or labels.**

### M5: VALIDATION & APPROVAL

Present plan. **WAIT for user approval.**

### M6: EXECUTION → `execution-log.md`

Execute using `create_record` with `related_records`. Report each creation. Verify via `query_records`.

---

## Field Population Rules

**Fill ALL writable fields.** Only leave null when:
- Field represents an event that hasn't occurred at this status
- Field references a record type not being created
- Field is deprecated per workflow analysis

**For every null, document WHY.**

---

## Type Conversion

| Type | Format | Example |
|------|--------|---------|
| Text | String | `"My Record Title"` |
| Integer | Number | `1`, `60` |
| Decimal | Float | `99.5` |
| Boolean | true/false | `true` |
| Date | ISO date | `"2026-05-13"` |
| Datetime | ISO datetime | `"2026-05-13T07:29:45Z"` |
| User | Username | `"<from list_users>"` |
