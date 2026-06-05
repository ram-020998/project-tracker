# Tool Reference: Solutions Intelligence MCP (Schema Tools)

The Solutions Intelligence MCP server provides read-only access to application schema data.

---

## solutions-intelligence.get_record_type_map ⭐ USE FIRST

Get mapping from DDL table names to record type UUIDs and relationship names. **Call this first — gives you everything needed for UUID resolution in ONE call.**

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `app_name` | string | Yes | Application folder name |
| `table_name` | string | No | Filter to a specific table |

**Returns:**
```json
{
  "AS_GSS_EVALUATION": {
    "record_type_uuid": "e6bc8561-...",
    "record_type_name": "AS_GSS_Evaluation_SYNCEDRECORD",
    "relationships": {
      "vendor": "b6081510-...",
      "criteria": "11dcc745-...",
      "team": "791d954b-...",
      "evaluationPhase": "bf3ef3fe-..."
    }
  }
}
```

**What you get:** Table UUID (for `data-generator.create_record`), relationship names (for `related_records`), child UUIDs (for querying children).

---

## solutions-intelligence.get_field_map ⭐ USE SECOND

Get mapping from DDL column names (UPPER_SNAKE) to Appian field names (camelCase).

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `app_name` | string | Yes | Application folder name |
| `table_name` | string | No | Filter to a specific table |

**Returns:**
```json
{
  "AS_GSS_EVALUATION": {
    "EVALUATION_ID": "evaluationId",
    "EVALUATION_TITLE": "evaluationTitle",
    "EVALUATION_STATUS_ID": "evaluationStatusId",
    "IS_ACTIVE": "isActive"
  }
}
```

**What you get:** Exact camelCase field names to use in `data-generator.create_record` payloads.

---

## get_reference_data

Get reference table metadata (NOT row data). Use the UUID to query live values.

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `app_name` | string | Yes | Application folder name |
| `table_name` | string | No | Filter to a specific table |

**Returns:**
```json
{
  "AS_GSS_R_DATA": {
    "record_type_uuid": "c34b12a0-...",
    "row_count": 110,
    "ref_types": ["Evaluation Status", "Evaluation Method", "Document Type"],
    "key_columns": ["REF_DATA_ID", "REF_LABEL", "REF_TYPE", "IS_ACTIVE"]
  }
}
```

**To get actual values:** Call `data-generator.query_records(record_type_uuid, paging_info={startIndex:1, batchSize:200})` on the Data Generator MCP.

---

## solutions-intelligence.get_app_schema

Get table definitions with columns, types, PKs.

**Args:** `app_name`, `table_name?`, `classification?` (business/reference/audit/task_management/framework)

---

## solutions-intelligence.get_schema_relationships

Get FK relationships. **Args:** `app_name`, `table_name?`

---

## solutions-intelligence.get_insertion_order

Get topologically sorted table list. **Args:** `app_name`

---

## get_schema_summary

Get statistics and table classification. **Args:** `app_name`

---

## Efficiency Rules

1. Call `solutions-intelligence.get_record_type_map` ONCE — gives all UUIDs and relationships
2. Call `solutions-intelligence.get_field_map` ONCE — gives all field name mappings
3. Call `get_reference_data` ONCE — gives ref table UUIDs for live querying
4. Use `table_name` filter only when you need one specific table
5. Do NOT call `solutions-intelligence.search_objects` to find record type UUIDs — use `solutions-intelligence.get_record_type_map` instead
