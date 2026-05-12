# Phase 5: Advanced Capabilities

## Objective

Extend the Data Generator beyond basic CRUD to support bulk operations, cross-table footprint queries, workflow-driven generation, performance testing data loads, and environment management. These capabilities build on the foundation of Phases 1-4.

---

## Capability 1: Bulk Record Creation

### Problem
Creating 1000 records one-at-a-time via HTTP is slow (~30 seconds per record × 1000 = 8+ hours). Performance testing requires loading thousands of records efficiently.

### Solution: Batch API

**New Appian API:** `POST /api/record/bulk-create`

```json
{
  "recordType": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
  "records": [
    {"evaluationTitle": "Eval 1", "evaluationStatusId": 1, "isActive": true},
    {"evaluationTitle": "Eval 2", "evaluationStatusId": 1, "isActive": true},
    {"evaluationTitle": "Eval 3", "evaluationStatusId": 2, "isActive": true}
  ]
}
```

**Response:**
```json
{
  "success": true,
  "created": 3,
  "recordIds": [1050, 1051, 1052]
}
```

**New MCP Tool:** `bulk_create_records`

```json
{
  "record_type_ref": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
  "records": [...],
  "batch_size": 50
}
```

The MCP server splits large requests into batches (default 50) and sends them sequentially, tracking all created IDs in the session.

### Performance Target
- 50 records per batch API call
- ~2 seconds per batch
- 1000 records in ~40 seconds (vs 8+ hours one-at-a-time)

---

## Capability 2: Record Footprint Query

### Problem
To learn from exemplar data, the agent needs to see ALL related records for a given entity — not just the entity itself, but all its children across all related tables.

### Solution: Footprint API

**New Appian API:** `POST /api/record/footprint`

```json
{
  "recordType": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
  "recordId": 1001,
  "depth": 2
}
```

**Response:**
```json
{
  "root": {
    "recordType": "AS_GSS_Evaluation_SYNCEDRECORD",
    "recordId": 1001,
    "fields": {
      "evaluationTitle": "HD940225Q0010",
      "evaluationStatusId": 3,
      "evaluationMethodId": 4
    }
  },
  "related": {
    "evaluationPhase": [
      {"recordId": 2001, "fields": {"phaseName": "Technical", "phaseOrder": 1}},
      {"recordId": 2002, "fields": {"phaseName": "Cost", "phaseOrder": 2}}
    ],
    "vendor": [
      {"recordId": 3001, "fields": {"vendorName": "Acme Corp", "isActive": true}},
      {"recordId": 3002, "fields": {"vendorName": "Beta Inc", "isActive": true}}
    ],
    "criteria": [
      {"recordId": 4001, "fields": {"criteriaName": "Technical Approach", "weight": 30}},
      {"recordId": 4002, "fields": {"criteriaName": "Past Performance", "weight": 20}}
    ],
    "team": [
      {"recordId": 5001, "fields": {"teamName": "Technical Team", "teamLead": "sarah.smith"}}
    ]
  },
  "summary": {
    "total_related_records": 7,
    "by_type": {
      "evaluationPhase": 2,
      "vendor": 2,
      "criteria": 2,
      "team": 1
    }
  }
}
```

**New MCP Tool:** `get_record_footprint`

The agent uses this to:
1. Find an exemplar record in the desired status
2. Query its full footprint
3. Use the footprint as a template for generating new data

### Depth Parameter
- `depth: 1` — direct children only (ONE_TO_MANY relationships)
- `depth: 2` — children and grandchildren (e.g., evaluation → criteria → criteria_assignments)

---

## Capability 3: Workflow-Driven Generation

### Problem
Instead of the agent manually tracing process models and building data plans, provide a higher-level tool that automates the "create entity in status X" pattern using status recipes.

### Solution: Status-Aware Create Tool

**New MCP Tool:** `create_entity_in_status`

```json
{
  "app_name": "SourceSelection",
  "entity": "Evaluation",
  "status": "Complete",
  "overrides": {
    "evaluationMethodId": 4,
    "vendorCount": 3
  }
}
```

**What it does internally:**
1. Loads the status recipe for "Evaluation in Complete status"
2. Resolves all dynamic values (users, dates, reference data)
3. Executes the recipe's insertion order
4. Returns all created record IDs

**Response:**
```json
{
  "success": true,
  "entity": "Evaluation",
  "status": "Complete",
  "root_record_id": 1055,
  "total_records_created": 12,
  "records": {
    "AS_GSS_EVALUATION": [1055],
    "AS_GSS_EVALUATION_PHASE": [2010, 2011],
    "AS_GSS_EVALUATION_VENDOR": [3010, 3011, 3012],
    "AS_GSS_CRITERIA": [4010, 4011, 4012],
    "AS_GSS_EVALUATOR_TEAM": [5010, 5011],
    "AS_GSS_TEAM_MEMBERSHIP": [6010, 6011, 6012]
  }
}
```

### Implementation
This tool lives in the Data Generator MCP but reads status recipes from the Atlas KB (via the GitLab API or bundled locally). It orchestrates multiple `create_record` calls following the recipe.

---

## Capability 4: Environment Management

### Problem
After testing, environments accumulate test data that needs cleanup. Also, teams need to reset environments to a known state.

### Solution: Environment Management Tools

**New MCP Tools:**

| Tool | Description |
|------|-------------|
| `get_environment_info` | Returns environment name, URL, record counts by type |
| `cleanup_test_data` | Delete all records created after a given timestamp |
| `reset_to_baseline` | Delete all non-reference data, leaving only lookup tables intact |

**`cleanup_test_data`:**
```json
{
  "since": "2024-12-01T00:00:00Z",
  "record_types": ["AS_GSS_Evaluation_SYNCEDRECORD", "AS_GSS_EvaluationVendor_SYNCEDRECORD"],
  "confirm": true
}
```

**`reset_to_baseline`:**
```json
{
  "app_name": "SourceSelection",
  "preserve_reference_data": true,
  "confirm": true
}
```

### Safety
- Both tools require `confirm: true`
- `reset_to_baseline` shows a preview of what will be deleted before executing
- All deletions follow reverse topological order (children first, then parents)

---

## Capability 5: Exemplar-Based Cloning

### Problem
The agent wants to create data that exactly matches an existing record's pattern — same structure, same child record counts, same field value patterns — but with different specific values.

### Solution: Clone Tool

**New MCP Tool:** `clone_record`

```json
{
  "source_record_type": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
  "source_record_id": 1001,
  "include_children": true,
  "overrides": {
    "evaluationTitle": "Cloned Evaluation",
    "contractingOfficer": "new.user"
  }
}
```

**What it does:**
1. Fetches the source record's full footprint
2. Creates a new root record with the same field values (minus PK, plus overrides)
3. Creates all child records with updated FK references to the new parent
4. Returns the complete set of new record IDs

This is the most powerful exemplar-based generation pattern — "give me another one just like this."

---

## Capability 6: Data Validation & Consistency Checks

### Problem
After creating data, how do we know it's correct? The application UI might still break if implicit constraints aren't satisfied.

### Solution: Validation Tools

**New MCP Tool:** `validate_entity`

```json
{
  "record_type_ref": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
  "record_id": 1055,
  "checks": ["fk_integrity", "required_children", "status_consistency"]
}
```

**Checks performed:**
- `fk_integrity` — All FK references point to existing records
- `required_children` — For the given status, expected child records exist
- `status_consistency` — Field values are consistent with the status (e.g., "Complete" status has a completion date)
- `date_sequence` — Dates follow logical order (start < due < completion)

**Response:**
```json
{
  "valid": false,
  "checks": {
    "fk_integrity": {"passed": true},
    "required_children": {"passed": true},
    "status_consistency": {
      "passed": false,
      "issues": [
        "Status is 'Complete' (3) but evaluationCompletionDate is null"
      ]
    },
    "date_sequence": {"passed": true}
  }
}
```

---

## Capability 7: Version-Aware Generation

### Problem
When testing migration scripts, you need data that matches an older schema version — not the current one.

### Solution: Version-Targeted Generation

The Atlas KB already stores version history. The agent can:
1. Query the release index to find the schema at a specific version
2. Use the historical schema (if stored) to understand the old table structure
3. Generate data matching the old schema

**This requires:**
- Storing schema snapshots per release (similar to how the KB stores release_snapshots for objects)
- A tool to query schema at a specific version

**New MCP Tool (Atlas MCP):** `get_schema_at_release`

```json
{
  "app_name": "SourceSelection",
  "release": "2.7.0"
}
```

Returns the schema as it was at that release — useful for creating data that tests migration scripts.

---

## Capability 8: Multi-Entity Scenario Generation

### Problem
Real test scenarios involve multiple related entities. "Create a complete evaluation with 3 vendors, where vendor 1 wins and vendors 2-3 lose" requires coordinated data across many tables.

### Solution: Scenario Templates

**New MCP Tool:** `execute_scenario`

```json
{
  "app_name": "SourceSelection",
  "scenario": "awarded_evaluation",
  "parameters": {
    "vendor_count": 3,
    "winning_vendor_index": 0,
    "evaluation_method": "LPTA",
    "include_consensus": true
  }
}
```

Scenarios are more complex than status recipes — they describe multi-entity interactions with conditional logic. They're stored as structured JSON or YAML in the KB.

---

## Implementation Priority

| Capability | Priority | Depends On | Effort |
|-----------|----------|------------|--------|
| Bulk creation | High | Phase 3 | 3 days |
| Record footprint | High | Phase 2 API | 2 days |
| Workflow-driven generation | High | Phase 4 recipes | 3 days |
| Environment management | Medium | Phase 3 | 2 days |
| Exemplar cloning | Medium | Footprint API | 2 days |
| Validation | Medium | Phase 4 recipes | 2 days |
| Version-aware generation | Low | KB version history | 3 days |
| Multi-entity scenarios | Low | All above | 4 days |

**Recommended order:** Footprint → Bulk creation → Workflow-driven → Validation → Cloning → Environment mgmt → Version-aware → Scenarios

---

## Total Phase 5 Estimated Effort

~21 days for all capabilities. Recommend implementing incrementally based on user feedback after Phase 4 is complete.
