# Action: Explore Schema

Understand the database structure, relationships, valid values, and field metadata for an application.

---

## When to Use

- User asks "What tables exist?"
- User asks "What are the valid statuses?"
- User asks "What fields does the Evaluation table have?"
- User asks "How are tables related?"
- User asks "What reference data is available?"
- User needs to understand the schema before generating data

---

## Workflow

### Step 1: Identify the application
```
Solutions Intelligence MCP: solutions-intelligence.list_applications()
```

### Step 2: Get schema summary
```
Solutions Intelligence MCP: get_schema_summary(app_name)
```
Returns: total tables, columns, FKs, reference data counts, and table classification (business/reference/audit/task_management/framework).

### Step 3: Based on user's question, call the appropriate tool:

| Question | Tool |
|----------|------|
| "What tables exist?" | `solutions-intelligence.get_app_schema(app_name)` |
| "What business tables exist?" | `solutions-intelligence.get_app_schema(app_name, classification="business")` |
| "What fields does X have?" | `solutions-intelligence.get_app_schema(app_name, table_name="X")` |
| "How are tables related?" | `solutions-intelligence.get_schema_relationships(app_name)` |
| "What references table X?" | `solutions-intelligence.get_schema_relationships(app_name, table_name="X")` |
| "What are the valid statuses?" | `get_reference_data(app_name, ref_type="Evaluation Status")` |
| "What reference data exists?" | `get_reference_data(app_name)` |
| "What order should I create records?" | `solutions-intelligence.get_insertion_order(app_name)` |

---

## Response Guidelines

### When showing table structure:
```
📋 AS_GSS_EVALUATION (Business Table)
═══════════════════════════════════════
Primary Key: evaluationId (Integer, auto-increment)

Fields (32 total):
─────────────────────────────────────
  evaluationId          Integer     PK, auto-increment
  evaluationNumber      Text        
  evaluationTitle       Text        
  evaluationStatusId    Integer     FK → AS_GSS_R_DATA.REF_DATA_ID
  evaluationMethodId    Integer     FK → AS_GSS_R_DATA.REF_DATA_ID
  evaluationChief       User        FK → AS_GSS_USER.USERNAME
  evaluationStartDate   Date        
  evaluationDueDate     Date        
  evaluationCompletionDate Date     
  completedBy           User        
  isActive              Boolean     
  ...

Custom/Computed Fields (not writable):
  totalTaskCount        Integer     computed
  vendorCount           Integer     computed
  factorCount           Integer     computed
```

### When showing relationships:
```
📋 AS_GSS_EVALUATION — Relationships
═══════════════════════════════════════
Outbound FKs (this table references):
  evaluationStatusId → AS_GSS_R_DATA.REF_DATA_ID
  evaluationMethodId → AS_GSS_R_DATA.REF_DATA_ID
  evaluationChief → AS_GSS_USER.USERNAME

Inbound FKs (other tables reference this):
  AS_GSS_EVALUATION_VENDOR.evaluationId → this.evaluationId
  AS_GSS_CRITERIA.evaluationId → this.evaluationId
  AS_GSS_EVALUATOR_TEAM.evaluationId → this.evaluationId
  AS_GSS_EVALUATION_PHASE.evaluationId → this.evaluationId
  AS_GSS_CONSENSUS_REPORT.evaluationId → this.evaluationId
```

### When showing reference data:
```
📋 Reference Data — Evaluation Status
═══════════════════════════════════════
ID  | Label              | Active
─────────────────────────────────────
1   | Setting up         | ✅
2   | In progress        | ✅
3   | Complete           | ✅
4   | Cancelled          | ✅
```

---

## Combining with Record Properties

If the user wants to understand what they can actually WRITE (vs what exists in the schema), also call:
```
Data Generator MCP: data-generator.get_record_properties(record_type_uuid)
```

This shows the Appian-side view: which fields are writable, which are computed, and the exact camelCase names to use in create/update payloads.

---

## Key Distinctions to Explain

| Concept | Explanation |
|---------|-------------|
| Business tables | Core application data (evaluations, vendors, criteria) |
| Reference tables | Lookup/enum values (statuses, methods, document types) |
| Audit tables | Change history tracking (auto-populated by app) |
| Framework tables | Script execution tracking (internal, never write to) |
| Custom fields | Computed by Appian (totalTaskCount, vendorCount) — read-only |
| Insertion order | Topological sort — parents before children |
