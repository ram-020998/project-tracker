# Phase 4: Agent Integration & Steering

## Objective

Configure the AI agent to effectively use both Atlas MCP (for understanding) and Data Generator MCP (for action) together. This includes steering documents, prompt patterns, record type mapping knowledge, and status recipes that guide the agent through the workflow analysis → data plan → execution pattern.

---

## What the Agent Needs to Know

For the data generation workflow to succeed, the agent must understand:

1. **How to find the record type reference** for a given table (Atlas KB → record type objects)
2. **How to read the schema** to understand table relationships and insertion order
3. **How to analyze workflows** to determine what data is needed for a given status
4. **How to construct a data plan** respecting FK dependencies and topological order
5. **How to execute the plan** using the Data Generator MCP tools in the correct sequence
6. **How to validate** the created data against exemplars

---

## Steering Document

Create a steering file that the agent loads when the Data Generator power is active.

**Location:** `ai-framework/Engineering/.kiro/powers/atlas-data-generator/steering.md`

```markdown
# Atlas Data Generator — Agent Steering

## Your Role
You are a data generation agent for Appian applications. You create realistic, 
workflow-aware test data by combining your understanding of the application 
(from Atlas KB) with write operations (via Data Generator MCP).

## Available MCP Servers

### Atlas MCP (read-only — application understanding)
- `get_app_schema` — table definitions, columns, types, constraints
- `get_reference_data` — valid values for lookup/enum fields
- `get_insertion_order` — FK-safe table creation order
- `get_relationships` — foreign key graph
- `search_bundles` / `get_bundle` — workflow/process model logic
- `search_objects` / `get_object_detail` — application objects

### Data Generator MCP (write — data operations)
- `get_record_properties` — field UUIDs and types (MUST call before create)
- `create_record` — create a single record
- `update_record` — update fields on existing record
- `query_records` — query existing data (for exemplar learning)
- `delete_record` — delete a record
- `list_users` — available usernames for User fields
- `get_session` — view records created in this session
- `rollback_session` — undo all creates in this session

## Workflow: Creating Data for a Specific Status

### Step 1: Understand the Schema
```
Atlas MCP: get_app_schema(app_name, classification="business")
Atlas MCP: get_insertion_order(app_name)
Atlas MCP: get_reference_data(app_name, table_name="AS_GSS_R_DATA")
```

### Step 2: Analyze the Workflow (for status-specific data)
```
Atlas MCP: search_bundles(app_name, query="<status-related keyword>")
Atlas MCP: get_bundle(bundle_id, detail_level="structure")
```
Read the process model to understand what tables are written at each transition.

### Step 3: Get Record Type References
Look up the record type objects in Atlas KB to find the UUID references needed 
for the Data Generator API calls.

### Step 4: Get Field Metadata
```
Data Generator MCP: get_record_properties(record_type_ref)
```
Cache this — you need it for every create/update call.

### Step 5: Check for Exemplars (optional but recommended)
```
Data Generator MCP: query_records(record_type_ref, 
  filters=[{field: "evaluationStatusId", operator: "=", value: 3}], 
  limit: 1)
```
Cross-check your data plan against real data.

### Step 6: Execute in Topological Order
Create records following the insertion order from the schema. 
Parent records first, then children that reference them.

### Step 7: Validate
Query the created records to confirm they exist and have correct values.

## Critical Rules

1. **ALWAYS call get_record_properties before creating records** — you need the 
   field references.
2. **NEVER write to custom/computed fields** (isCustomRecordField=true) — they 
   are calculated by Appian.
3. **NEVER supply primary key values** — they are auto-generated.
4. **Follow insertion order** — create parent records before children.
5. **Use valid reference data IDs** — check get_reference_data for valid enum values.
6. **Use real usernames** — call list_users to get valid usernames for User fields.
7. **Track your session** — use get_session to see what you've created. Use 
   rollback_session if something goes wrong.

## Record Type Reference Resolution

To find the record type reference for a table:
1. The Atlas KB has parsed record type objects with their UUIDs
2. Table name `AS_GSS_EVALUATION` maps to record type `AS_GSS_Evaluation_SYNCEDRECORD`
3. The full reference is: `recordType!{uuid}AS_GSS_Evaluation_SYNCEDRECORD`
4. Use search_objects in Atlas MCP to find record types by name

## Field Name Mapping

- Schema (DDL) uses UPPER_SNAKE_CASE: `EVALUATION_STATUS_ID`
- Appian record type uses camelCase: `evaluationStatusId`
- The Data Generator MCP accepts camelCase field names

## Reference Data Pattern

The `AS_GSS_R_DATA` table is a multi-type lookup table. Values are grouped by 
`REF_TYPE`. When setting a status field like `evaluationStatusId`, the value is 
the `REF_DATA_ID` from this table where `REF_TYPE = 'Evaluation Status'`.

Example:
- evaluationStatusId = 1 → "Setting up"
- evaluationStatusId = 2 → "In progress"  
- evaluationStatusId = 3 → "Complete"
- evaluationMethodId = 4 → "Least Price Technically Acceptable"
- evaluationMethodId = 5 → "Best Value"
```

---

## Status Recipes

Status recipes are structured documents that map a desired business state to the exact data that must exist. They are manually created and stored in the KB.

**Location:** `data/<AppName>/current/schema/status_recipes/`

### Recipe Format

```json
{
  "entity": "Evaluation",
  "status": "Complete",
  "description": "An evaluation that has completed all phases with scores assigned",
  "status_field": {
    "table": "AS_GSS_EVALUATION",
    "field": "evaluationStatusId",
    "value": 3,
    "ref_label": "Complete"
  },
  "required_records": [
    {
      "table": "AS_GSS_EVALUATION",
      "record_type": "AS_GSS_Evaluation_SYNCEDRECORD",
      "count": 1,
      "fields": {
        "evaluationStatusId": 3,
        "evaluationMethodId": {"ref_type": "Evaluation Method", "pick": "any"},
        "evaluationStartDate": {"relative": "-30 days"},
        "evaluationDueDate": {"relative": "-5 days"},
        "evaluationCompletionDate": {"relative": "-1 day"},
        "completedBy": {"type": "user", "pick": "any"},
        "evaluationChief": {"type": "user", "pick": "any"},
        "contractingOfficer": {"type": "user", "pick": "any"},
        "isActive": true
      }
    },
    {
      "table": "AS_GSS_EVALUATION_PHASE",
      "record_type": "AS_GSS_EvaluationPhase_SYNCEDRECORD",
      "count": "1-3",
      "depends_on": "AS_GSS_EVALUATION",
      "fields": {
        "evaluationId": {"fk": "AS_GSS_EVALUATION.evaluationId"},
        "phaseName": {"generate": "Phase {n}"},
        "phaseOrder": {"sequence": 1},
        "startDate": {"relative": "-25 days"},
        "endDate": {"relative": "-10 days"}
      }
    },
    {
      "table": "AS_GSS_EVALUATION_VENDOR",
      "record_type": "AS_GSS_EvaluationVendor_SYNCEDRECORD",
      "count": "2-5",
      "depends_on": "AS_GSS_EVALUATION",
      "fields": {
        "evaluationId": {"fk": "AS_GSS_EVALUATION.evaluationId"},
        "vendorName": {"generate": "Vendor {n} LLC"},
        "isActive": true
      }
    },
    {
      "table": "AS_GSS_CRITERIA",
      "record_type": "AS_GSS_Criteria_SYNCEDRECORD",
      "count": "2-4",
      "depends_on": "AS_GSS_EVALUATION",
      "fields": {
        "evaluationId": {"fk": "AS_GSS_EVALUATION.evaluationId"},
        "criteriaName": {"generate": "Factor {n}"},
        "criteriaStatusId": 3,
        "weight": {"range": [10, 40]}
      }
    },
    {
      "table": "AS_GSS_EVALUATOR_TEAM",
      "record_type": "AS_GSS_EvaluatorTeam_SYNCEDRECORD",
      "count": "1-3",
      "depends_on": "AS_GSS_EVALUATION",
      "fields": {
        "evaluationId": {"fk": "AS_GSS_EVALUATION.evaluationId"},
        "teamName": {"generate": "Team {n}"},
        "teamLead": {"type": "user", "pick": "any"}
      }
    }
  ],
  "insertion_order": [
    "AS_GSS_EVALUATION",
    "AS_GSS_EVALUATION_PHASE",
    "AS_GSS_EVALUATION_VENDOR",
    "AS_GSS_CRITERIA",
    "AS_GSS_EVALUATOR_TEAM"
  ]
}
```

### Recipe Value Types

| Syntax | Meaning |
|--------|---------|
| `3` | Literal value |
| `{"ref_type": "Evaluation Method", "pick": "any"}` | Pick any active value from reference data with this REF_TYPE |
| `{"relative": "-30 days"}` | Date relative to today |
| `{"type": "user", "pick": "any"}` | Pick any available user |
| `{"fk": "TABLE.field"}` | Use the ID from the parent record created earlier |
| `{"generate": "Pattern {n}"}` | Generate with pattern (n = sequence number) |
| `{"sequence": 1}` | Auto-incrementing sequence starting at given value |
| `{"range": [10, 40]}` | Random value in range |
| `"1-3"` | Count range (agent picks within range) |

---

## Record Type Mapping Document

The agent needs to know which Atlas KB table maps to which Appian record type reference. This mapping is stored in the schema output.

**Location:** `data/<AppName>/current/schema/record_type_map.json`

```json
{
  "AS_GSS_EVALUATION": {
    "record_type_name": "AS_GSS_Evaluation_SYNCEDRECORD",
    "record_type_ref": "recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD",
    "plural_name": "Evaluations"
  },
  "AS_GSS_EVALUATION_VENDOR": {
    "record_type_name": "AS_GSS_EvaluationVendor_SYNCEDRECORD",
    "record_type_ref": "recordType!{b6081510-0d11-4d51-8eba-966610b168db}AS_GSS_EvaluationVendor_SYNCEDRECORD",
    "plural_name": "Evaluation Vendors"
  }
}
```

**How this is generated:** The Atlas parser already parses record type objects from the application package. Each record type XML contains the UUID and the data source table name. We extract this mapping during the parse phase and include it in the schema output.

---

## Power Configuration

**Location:** `ai-framework/Engineering/.kiro/powers/atlas-data-generator/`

```
atlas-data-generator/
├── steering.md          ← the steering document above
├── mcp.json             ← combined MCP config (both Atlas + Data Generator)
└── README.md            ← power description and setup instructions
```

**`mcp.json`:**
```json
{
  "mcpServers": {
    "appian-atlas": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--env", "GITLAB_TOKEN", "--env", "ATLAS_KB_PROJECT_ID", "--env", "ATLAS_DATA_PREFIX",
        "registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server:latest"],
      "env": {
        "GITLAB_TOKEN": "${GITLAB_TOKEN}",
        "ATLAS_KB_PROJECT_ID": "13490",
        "ATLAS_DATA_PREFIX": "ai-framework/tools/Atlas/solutions-kb/data"
      }
    },
    "appian-data-generator": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--env", "APPIAN_ENV_URL", "--env", "APPIAN_API_KEY",
        "registry.gitlab.appian-stratus.com/appian/prod/solutions-data-generator-mcp:latest"],
      "env": {
        "APPIAN_ENV_URL": "${APPIAN_ENV_URL}",
        "APPIAN_API_KEY": "${APPIAN_API_KEY}"
      }
    }
  }
}
```

---

## Example Agent Interaction

### User Request
"Create 2 evaluations in Complete status with LPTA method and 3 vendors each"

### Agent Execution Flow

```
1. Agent → Atlas MCP: get_app_schema("SourceSelection", classification="business")
   ← Gets 18 business tables with columns

2. Agent → Atlas MCP: get_reference_data("SourceSelection", table_name="AS_GSS_R_DATA")
   ← Gets reference data: Status 3 = "Complete", Method 4 = "LPTA"

3. Agent → Atlas MCP: get_insertion_order("SourceSelection")
   ← Gets topological order

4. Agent → Data Generator MCP: list_users()
   ← Gets ["jason.john", "sarah.smith", "appian.administrator"]

5. Agent → Data Generator MCP: get_record_properties(
     "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD")
   ← Gets field UUIDs and types

6. Agent → Data Generator MCP: get_record_properties(
     "recordType!{b6081510-...}AS_GSS_EvaluationVendor_SYNCEDRECORD")
   ← Gets vendor field UUIDs

7. FOR each of 2 evaluations:
   Agent → Data Generator MCP: create_record(
     record_type_ref="recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
     fields={
       "evaluationTitle": "LPTA Evaluation 1",
       "evaluationStatusId": 3,
       "evaluationMethodId": 4,
       "evaluationStartDate": "2024-11-01",
       "evaluationCompletionDate": "2024-12-01",
       "completedBy": "jason.john",
       "evaluationChief": "sarah.smith",
       "contractingOfficer": "jason.john",
       "isActive": true
     })
   ← Returns {record_id: 1050}

   FOR each of 3 vendors:
   Agent → Data Generator MCP: create_record(
     record_type_ref="recordType!{b6081510-...}AS_GSS_EvaluationVendor_SYNCEDRECORD",
     fields={
       "evaluationId": 1050,
       "vendorName": "Acme Corp",
       "isActive": true
     })
   ← Returns {record_id: 5001}

8. Agent → Data Generator MCP: get_session()
   ← Shows 8 records created (2 evaluations + 6 vendors)

9. Agent reports success to user with created record IDs
```

---

## Testing the Integration

### End-to-End Test Scenarios

1. **Simple create** — Create a single evaluation in "Setting up" status
2. **Status-specific create** — Create an evaluation in "Complete" status with all required child records
3. **Exemplar-based create** — Query an existing complete evaluation, then create a new one matching its pattern
4. **Rollback** — Create records, then rollback the entire session
5. **Error recovery** — Attempt to create with invalid reference data, handle the error, retry with correct values

### Validation Criteria

- [ ] Agent correctly resolves table names to record type references
- [ ] Agent calls get_record_properties before any create
- [ ] Agent respects insertion order (parents before children)
- [ ] Agent uses valid reference data IDs (not arbitrary numbers)
- [ ] Agent uses real usernames from list_users
- [ ] Agent skips custom/computed fields
- [ ] Created records are queryable and have correct values
- [ ] Rollback successfully deletes all session records

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Steering document | 2 hours |
| Status recipes (3-4 statuses) | 4 hours |
| Record type mapping generation | 2 hours |
| Power configuration | 1 hour |
| End-to-end testing | 4 hours |
| Documentation | 2 hours |
| **Total** | **~15 hours (2 days)** |

---

## Dependencies

- Phase 1 (schema in KB) — for insertion order and reference data
- Phase 2 (Appian APIs) — for actual data operations
- Phase 3 (MCP server) — for the tool interface
- Record type mapping — needs parser enhancement to extract table→record type mapping from parsed record type objects
