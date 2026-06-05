# Tool Reference: Data Generator MCP

The Data Generator MCP server provides write access to Appian application environments.

---

## data-generator.get_record_properties

Get field metadata for a record type. **MUST call before any create/update.**

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `record_type_uuid` | string | Yes | Record type UUID (without `recordType!{...}` wrapper) |

**Returns:** Record type name and fields array with: name, reference, type, isPrimaryKey, isCustomRecordField.

**Usage:**
```json
{"record_type_uuid": "e6bc8561-d3a6-4679-b7af-6e279910468e"}
```

**Key information from response:**
- `isPrimaryKey: true` → skip in create payloads (auto-generated)
- `isCustomRecordField: true` → skip always (computed by Appian)
- `type` → determines value format (Date, User, Integer, etc.)
- `name` → exact camelCase field name to use in payloads

---

## data-generator.create_record

Create a single record, optionally with nested related records. PK is auto-generated. Custom fields are auto-skipped.

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `record_type_uuid` | string | Yes | Record type UUID |
| `fields` | object | Yes | Field name-value pairs (camelCase) |
| `related_records` | array | No | Nested child records via relationships |

### Simple Usage (no children):
```json
{
  "record_type_uuid": "e6bc8561-d3a6-4679-b7af-6e279910468e",
  "fields": {
    "evaluationTitle": "Test Evaluation",
    "evaluationStatusId": 1,
    "isActive": true
  }
}
```

### With Related Records (parent + children in one call):
```json
{
  "record_type_uuid": "e6bc8561-d3a6-4679-b7af-6e279910468e",
  "fields": {
    "evaluationTitle": "Complete Evaluation with Vendors",
    "evaluationStatusId": 3,
    "isActive": true
  },
  "related_records": [
    {
      "relationshipName": "vendor",
      "recordType": "b6081510-0d11-4d51-8eba-966610b168db",
      "records": [
        {"vendorName": "<vendor name>", "isActive": true},
        {"vendorName": "Beta Inc", "isActive": true},
        {"vendorName": "Gamma LLC", "isActive": true}
      ]
    },
    {
      "relationshipName": "criteria",
      "recordType": "11dcc745-3c81-49f9-9cb2-6427680e4b41",
      "records": [
        {"criteriaName": "Technical Approach", "isActive": true},
        {"criteriaName": "Past Performance", "isActive": true}
      ]
    }
  ]
}
```

### Related Records Rules:
- `relationshipName` must match a relationship from `data-generator.get_record_properties` (e.g., "vendor", "criteria", "team")
- Do NOT include the FK field in child records — Appian auto-populates it from the parent
- Children are created atomically with the parent (all succeed or all fail)
- Supports multiple relationship types in one call
- Supports multiple levels of nesting (children of children)

**Returns:** `{success: true, recordsUpdated: [{evaluationId: 45, ...}]}`

---

## data-generator.update_record

Update specific fields on an existing record (partial update).

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `record_type_uuid` | string | Yes | Record type UUID |
| `record_id` | integer | Yes | Primary key of the record |
| `fields` | object | Yes | Fields to update |

**Usage:**
```json
{
  "record_type_uuid": "e6bc8561-d3a6-4679-b7af-6e279910468e",
  "record_id": 1045,
  "fields": {
    "evaluationStatusId": 3,
    "evaluationCompletionDate": "2024-12-15",
    "completedBy": "<username from data-generator.list_users>"
  }
}
```

**Note:** Only the specified fields are updated. Other fields remain unchanged.

---

## data-generator.delete_record

Soft-delete a record (sets isActive=false).

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `record_type_uuid` | string | Yes | Record type UUID |
| `record_id` | integer | Yes | Primary key of the record |

**Usage:**
```json
{
  "record_type_uuid": "e6bc8561-d3a6-4679-b7af-6e279910468e",
  "record_id": 1045
}
```

**Note:** Delete children before parents to avoid FK issues.

---

## data-generator.query_records

Query records with filters, field selection, and paging.

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `record_type_uuid` | string | Yes | Record type UUID |
| `filters` | array | No | `[{field, operator, value}]` |
| `selected_fields` | array | No | Field names to return |
| `paging_info` | object | No | `{startIndex, batchSize, sort: {field, ascending}}` |

**Operators:** `=`, `<>`, `>`, `<`, `>=`, `<=`, `in`, `not in`, `is null`, `not null`, `starts with`, `ends with`

**Usage:**
```json
{
  "record_type_uuid": "e6bc8561-d3a6-4679-b7af-6e279910468e",
  "filters": [
    {"field": "evaluationStatusId", "operator": "=", "value": 3},
    {"field": "isActive", "operator": "=", "value": true}
  ],
  "selected_fields": ["evaluationId", "evaluationTitle", "evaluationStatusId"],
  "paging_info": {"startIndex": 1, "batchSize": 10, "sort": {"field": "evaluationId", "ascending": false}}
}
```

**Defaults:** No filters = all records. No selected_fields = all fields. No paging = first 10.

**IMPORTANT:** Do NOT pass `selected_fields` unless you specifically need to limit the response. By default, let the API return all fields — this ensures you never miss data.

---

## data-generator.list_users

List available usernames in the environment.

**Args:** None.

**Returns:** `{success: true, totalCount: N, users: ["username1", "username2", ...]}`

**Usage:** Call ONCE at the start. Use these exact strings for User-type fields.

---

## data-generator.get_session

Get summary of all records created in this session.

**Args:** None.

**Returns:** Session start time, total records, records by type, and individual record list with IDs and timestamps.

**Usage:** Call after data generation to verify, or before rollback to preview.

---

## data-generator.rollback_session

Soft-delete ALL records created in this session. Reverse order (children first).

**Args:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `confirm` | boolean | Yes | Must be `true` to execute |

**Usage:**
```json
{"confirm": true}
```

**With `confirm: false`:** Returns a preview of what would be deleted (session summary).
**With `confirm: true`:** Executes the rollback, clears the session.

---

## Efficiency Rules

1. Call `data-generator.get_record_properties` ONCE per record type — cache the result
2. Call `data-generator.list_users` ONCE — usernames don't change during a session
3. Use `selected_fields` in queries — don't fetch all 32 fields when you need 3
4. Use `paging_info.batchSize` appropriately — 10 for verification, 50-100 for bulk queries
5. Check `data-generator.get_session` before rollback — know what you're deleting
6. After each `data-generator.create_record`, capture the returned ID immediately — you need it for child records
7. Do NOT pass `selected_fields` by default — always fetch all fields to avoid missing data
