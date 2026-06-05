# Action: Query and Validate

Query existing records in the Appian environment and verify data created by the generator.

---

## When to Use

- User asks "Show me existing evaluations"
- User asks "Find records with status X"
- User asks "Verify what we just created"
- User asks "How many records exist?"
- After data generation, to confirm success

---

## Workflow

### Querying Existing Data

```
Data Generator MCP: data-generator.query_records(
  record_type_uuid: "e6bc8561-d3a6-4679-b7af-6e279910468e",
  filters: [
    {"field": "evaluationStatusId", "operator": "=", "value": 3},
    {"field": "isActive", "operator": "=", "value": true}
  ],
  selected_fields: ["evaluationId", "evaluationTitle", "evaluationStatusId"],
  paging_info: {"startIndex": 1, "batchSize": 10}
)
```

### Verifying Created Records

After creating records, verify by querying with the returned ID:

```
Data Generator MCP: data-generator.query_records(
  record_type_uuid: "e6bc8561-...",
  filters: [{"field": "evaluationId", "operator": "=", "value": 1045}],
  selected_fields: ["evaluationId", "evaluationTitle", "evaluationStatusId", "evaluationMethodId", "isActive"]
)
```

### Checking Child Records

After creating parent + children, verify children exist:

```
Data Generator MCP: data-generator.query_records(
  record_type_uuid: "b6081510-...",
  filters: [{"field": "evaluationId", "operator": "=", "value": 1045}]
)
```

---

## Response Format

### Query Results:
```
📊 Query Results: AS_GSS_Evaluation (evaluationStatusId = 3)
═══════════════════════════════════════
Total: 25 records found (showing first 10)

ID    | Title                    | Status | Method
──────┼──────────────────────────┼────────┼────────
1045  | LPTA Evaluation Test     | 3      | 4
1042  | <record title>         | 3      | 5
1038  | Best Value Analysis      | 3      | 5
...
```

### Verification Results:
```
✅ VERIFICATION PASSED
═══════════════════════════════════════
Record: AS_GSS_Evaluation ID 1045
  evaluationTitle: "LPTA Evaluation Test" ✅
  evaluationStatusId: 1 (Setting up) ✅
  evaluationMethodId: 4 (LPTA) ✅
  isActive: true ✅

Child records:
  AS_GSS_EvaluationVendor: 3 records found ✅
  AS_GSS_Criteria: 2 records found ✅
  AS_GSS_EvaluatorTeam: 1 record found ✅
```

---

## Filter Operators

| Operator | Usage | Example |
|----------|-------|---------|
| `=` | Exact match | `{"field": "status", "operator": "=", "value": 3}` |
| `<>` | Not equal | `{"field": "status", "operator": "<>", "value": 1}` |
| `>` / `>=` | Greater than | `{"field": "id", "operator": ">", "value": 1000}` |
| `<` / `<=` | Less than | `{"field": "id", "operator": "<", "value": 2000}` |
| `in` | In list | `{"field": "status", "operator": "in", "value": [1, 2, 3]}` |
| `is null` | Null check | `{"field": "completedBy", "operator": "is null", "value": null}` |
| `not null` | Not null | `{"field": "completedBy", "operator": "not null", "value": null}` |

---

## Tips

- Always include `isActive = true` filter unless specifically looking for deleted records
- Use `selected_fields` to reduce response size — don't fetch all 32 fields if you only need 5
- Use `paging_info.sort` to get most recent records first: `{"field": "evaluationId", "ascending": false}`
- Default batch size is 10 — increase to 50 or 100 for bulk verification
