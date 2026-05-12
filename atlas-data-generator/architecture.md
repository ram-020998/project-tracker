# Atlas Data Generator — Architecture Document

## Executive Summary

The Atlas Data Generator is a new capability within the Atlas ecosystem that enables AI agents to create realistic, workflow-aware test data in Appian application environments. Unlike traditional test data tools that generate random rows, this system leverages Atlas's deep understanding of application structure — process models, business rules, record types, and dependency graphs — to produce data that represents valid business states across complex multi-table relationships.

The system addresses multiple use cases: manual testing, automated test data preparation, performance testing data loads, and demo environment setup.

---

## Problem Statement

### The Challenge

Appian applications typically consist of 40-50 interconnected database tables. A single business entity (e.g., a "Source Selection Request") doesn't live in one table — its state is distributed across many tables that are populated at different stages of a workflow.

When we say "create a request in AWARDED status," the actual data footprint includes:
- The request record itself with status = AWARDED
- Vendor response records (created during submission phase)
- Evaluation panel records (created when evaluation starts)
- Individual evaluation records (created during evaluation)
- Award decision records (created during award phase)
- Audit trail records at each transition
- Various junction/relationship tables linking these entities

Each of these records has specific field values that are computed by business rules, set by process models, or derived from upstream data. Simply inserting a row with `status = 'AWARDED'` produces an inconsistent database state that will break the application UI and downstream processes.

### Why Existing Approaches Fail

| Approach | Why It Fails for This Problem |
|----------|-------------------------------|
| Random data generators (Faker, etc.) | No understanding of inter-table relationships or workflow semantics |
| Database snapshot/restore | Inflexible — can't create specific scenarios on demand |
| Manual scripting | Doesn't scale, breaks on app version changes, requires deep domain knowledge |
| Record-at-a-time UI automation | Extremely slow, brittle, doesn't support direct data loading |

### What We Need

An AI agent that can:
1. Understand the complete data model (tables, relationships, constraints)
2. Understand the workflow logic (what data is created/modified at each step)
3. Construct a valid data plan for any requested business state
4. Execute that plan via APIs against a target environment
5. Validate the result

---

## Architecture Overview

### The Four-Layer Context Stack

The Data Generator's intelligence comes from four complementary layers of context, each providing a different type of understanding:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AI AGENT                                         │
│                                                                         │
│  Input: "Create 5 Source Selection requests in AWARDED status           │
│          with 3 vendors each, using LPTA evaluation method"             │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
            ┌────────────────────────┼────────────────────────┐
            │                        │                        │
            ▼                        ▼                        ▼
┌───────────────────┐  ┌──────────────────────┐  ┌────────────────────────┐
│  LAYER 1          │  │  LAYER 2             │  │  LAYER 3               │
│  Schema &         │  │  Workflow            │  │  Live Environment      │
│  Relationships    │  │  Analysis            │  │  Introspection         │
│                   │  │                      │  │                        │
│  Static knowledge │  │  Static knowledge    │  │  Runtime queries       │
│  from Atlas KB    │  │  from Atlas KB       │  │  against target env    │
└───────────────────┘  └──────────────────────┘  └────────────────────────┘
            │                        │                        │
            └────────────────────────┼────────────────────────┘
                                     │
                                     ▼
                        ┌──────────────────────┐
                        │  LAYER 4             │
                        │  Exemplar Pattern    │
                        │  Learning            │
                        │                      │
                        │  Query real data     │
                        │  to validate/learn   │
                        └──────────────────────┘
                                     │
                                     ▼
                        ┌──────────────────────┐
                        │  DATA GENERATOR      │
                        │  MCP SERVER          │
                        │                      │
                        │  CRUD operations     │
                        │  against Appian env  │
                        └──────────────────────┘
```

---

## Layer 1: Schema & Relationships (Structural Foundation)

### What It Provides

The structural understanding of the application's data model:
- Complete table definitions (columns, data types, constraints, nullable fields, comments)
- Primary key and foreign key relationships
- Topological ordering (which tables must be populated before others)
- **Complete reference data** — the actual values pre-loaded into lookup/reference tables
- Stored procedures and triggers that affect data behavior

### Source: The Application DDL Script

Every Appian application package contains a **`scripts/` folder** with the complete DDL SQL script for the application's database. This is the authoritative source for schema information — not the application objects (data stores, record types, CDTs).

For example, the Source Selection v2.9.0 package contains `01.SourceSelectionv2.9.0.sql` — an 11,500-line SQL script that includes:

1. **Script execution framework** — tables and procedures for tracking script execution history (`AS_GAM_ScriptExecutionHistory`, `AS_GSS_ScriptExecutionHistory`)

2. **Complete CREATE TABLE statements** — ~104 tables with full column definitions, data types, constraints, primary keys, auto-increment settings, and column comments. Example:
   ```sql
   CREATE TABLE `AS_GSS_EVALUATION` (
     `EVALUATION_ID` int(11) NOT NULL AUTO_INCREMENT,
     `EVALUATION_PHASE_ID` int(11) DEFAULT NULL,
     `VENDOR_ID` int(11) DEFAULT NULL,
     `STATUS` varchar(255) DEFAULT NULL,
     `WEIGHTED_SCORE` decimal(10,2) DEFAULT NULL,
     ...
     PRIMARY KEY (`EVALUATION_ID`)
   );
   ```

3. **Foreign key constraints** — defined via ALTER TABLE statements or inline, showing all inter-table relationships

4. **Reference data INSERT statements** — the actual values loaded into lookup tables. This is critical because it tells the AI exactly what valid values exist. For example:
   ```sql
   INSERT INTO `AS_GSS_R_DATA` (...) VALUES
   (1, 'Setting up', NULL, 'Evaluation Status', 'gear', '#757575', 1, 1, ...),
   (2, 'In progress', NULL, 'Evaluation Status', 'spinner', '#757575', 2, 1, ...),
   (3, 'Complete', NULL, 'Evaluation Status', 'check-circle', 'POSITIVE', 3, 1, ...),
   (4, 'Least Price Technically Acceptable', NULL, 'Evaluation Method', '', '', 1, 1, ...),
   (5, 'Best Value', NULL, 'Evaluation Method', '', '', 2, 1, ...);
   ```

5. **Schema migrations** — ALTER TABLE statements showing how the schema evolved across releases, wrapped in the script execution framework for idempotent execution

### Table Naming Conventions (from the Source Selection script)

The script reveals a clear naming pattern:
- **`AS_GSS_*`** — Source Selection application tables (core business data)
- **`AS_GSS_R_*`** — Reference/lookup tables (pre-loaded static data)
- **`AS_GSS_A_R_*`** — Audit trail tables (history of changes)
- **`AS_GSS_A_R_*_FIELD`** — Audit field-level change tracking
- **`AS_GSS_TMG_*`** — Task Management module tables
- **`AS_GSS_TMG_R_*`** — Task Management reference tables
- **`AS_GAM_*`** — Shared GAM Suite tables (used across multiple solutions)
- **`AS_GAM_R_*`** — Shared GAM reference tables

### What the Agent Learns from This Layer

From the DDL script alone, the agent knows:
- "Table `AS_GSS_EVALUATION` has columns: EVALUATION_ID (PK, auto-increment), EVALUATION_PHASE_ID (FK), VENDOR_ID (FK), STATUS, WEIGHTED_SCORE..."
- "To insert into `AS_GSS_EVALUATION`, I must first have valid rows in the tables referenced by EVALUATION_PHASE_ID and VENDOR_ID"
- "The valid Evaluation Methods are: 'Least Price Technically Acceptable' (ID=4) and 'Best Value' (ID=5) — from the reference data inserts"
- "Evaluation Status values are: 'Setting up' (1), 'In progress' (2), 'Complete' (3)"
- "Audit tables (`A_R_*`) track field-level changes — I need to create audit records when simulating workflow transitions"
- "Reference tables (`R_*`) are pre-populated — I should use existing reference IDs, not create new reference data"

### Enhancement Required for Atlas Parser

The parser already has access to the scripts folder in the application ZIP. The enhancement is to:

1. **Parse the DDL script as a sequential migration replay** — The script file is **cumulative and incremental**, not a clean schema snapshot. A table created in v1.0 appears as a CREATE TABLE, and subsequent releases add ALTER TABLE statements later in the same file (ADD COLUMN, MODIFY COLUMN, ADD CONSTRAINT, etc.). The parser must replay the entire script in order to compute the final schema state.

   Example of what the parser encounters in a single file:
   ```sql
   -- From v1.0 (early in the file)
   CREATE TABLE `AS_GSS_EVALUATION` (
     `EVALUATION_ID` int(11) NOT NULL AUTO_INCREMENT,
     `STATUS` varchar(255) DEFAULT NULL,
     PRIMARY KEY (`EVALUATION_ID`)
   );

   -- From v2.3 (later in the same file)
   ALTER TABLE `AS_GSS_EVALUATION` ADD COLUMN `WEIGHTED_SCORE` decimal(10,2);

   -- From v2.7 (even later)
   ALTER TABLE `AS_GSS_EVALUATION` MODIFY COLUMN `STATUS` varchar(100) NOT NULL;
   ALTER TABLE `AS_GSS_EVALUATION` ADD COLUMN `EVALUATION_METHOD_ID` int(11);
   ALTER TABLE `AS_GSS_EVALUATION` ADD CONSTRAINT FK_EVAL_METHOD
     FOREIGN KEY (`EVALUATION_METHOD_ID`) REFERENCES `AS_GSS_R_DATA`(`REF_DATA_ID`);
   ```

2. **Build an in-memory schema model by replaying statements in order:**
   - `CREATE TABLE` → register table with initial columns, types, constraints
   - `ALTER TABLE ... ADD COLUMN` → add column to existing table model
   - `ALTER TABLE ... MODIFY COLUMN` → update column type/constraints
   - `ALTER TABLE ... DROP COLUMN` → remove column from model
   - `ALTER TABLE ... ADD CONSTRAINT` / `ADD FOREIGN KEY` → add FK relationship
   - `ALTER TABLE ... RENAME` → rename table or column
   - `DROP TABLE` → remove table from model entirely

3. **Replay reference data mutations** — Reference data also accumulates incrementally:
   - `INSERT INTO` on reference tables → add to reference data catalog
   - `UPDATE` on reference tables (e.g., `SET IS_ACTIVE = 0`) → update existing values
   - The final output should reflect only the current active reference data

4. **Output the resolved final state** as structured JSON:
   - `schema/tables.json` — final table definitions (as if written as a single clean DDL)
   - `schema/relationships.json` — FK graph (all constraints accumulated across releases)
   - `schema/reference_data.json` — final active reference data values
   - `schema/insertion_order.json` — topological sort from FK graph
   - `schema/table_classification.json` — tables categorized by naming convention

5. **Implementation approach** — Build a lightweight SQL DDL parser in Python that understands the specific patterns used by the GAM Script Execution Framework. Since these scripts are generated by a consistent framework, the SQL patterns are predictable and limited. This avoids adding a database engine dependency to the parser (maintaining the zero-runtime-dependency design).

The key insight is that **we don't need to reverse-engineer the schema from application objects** (data stores, record types, CDTs). The DDL script IS the schema — it's the exact SQL that creates and evolves the database. The parser just needs to replay it to compute the current state.

---

## Layer 2: Workflow Analysis (Behavioral Understanding)

### What It Provides

The behavioral understanding of how data is created and transformed through the application's workflow:
- Which process models execute at each workflow transition
- What database writes each process model performs
- What business rules compute field values
- What conditions gate each transition
- What subprocesses are invoked and what they write

### Source

Already available in the Atlas KB. The parsed application contains:
- **Process Model bundles** — complete workflow definitions with nodes, transitions, write operations
- **Expression Rules** — business logic that computes values
- **Action bundles** — entry points that trigger workflows
- **Dependency graphs** — which process model calls which rules, writes to which record types

### What the Agent Learns from This Layer

The agent can trace a complete workflow path. For example, tracing "Draft → Awarded" in Source Selection:

**Transition: Draft → Submitted**
- Process Model: `AS_GSS_Submit_Request`
- Writes: Updates `SS_Request.status = 'SUBMITTED'`, sets `SS_Request.submitted_date = now()`
- Creates: `SS_Submission_Audit` record
- Calls: `AS_GSS_Notify_Evaluators` (sends notifications)

**Transition: Submitted → Evaluation**
- Process Model: `AS_GSS_Start_Evaluation`
- Writes: Updates `SS_Request.status = 'IN_EVALUATION'`, sets `evaluation_start_date`
- Creates: `SS_EvaluationPanel` records (one per evaluation factor)
- Creates: `SS_Evaluator_Assignment` records
- Calls: `AS_GSS_Initialize_Scoring_Matrix`

**Transition: Evaluation → Evaluation Complete**
- Process Model: `AS_GSS_Complete_Evaluation`
- Writes: Updates `SS_Request.status = 'EVALUATION_COMPLETE'`
- Creates: `SS_Evaluation` records with scores
- Computes: `SS_Evaluation.weighted_score` via expression rule `AS_GSS_Calculate_Weighted_Score`

**Transition: Evaluation Complete → Awarded**
- Process Model: `AS_GSS_Award_Vendor`
- Writes: Updates `SS_Request.status = 'AWARDED'`, sets `award_date`
- Creates: `SS_Award_Decision` record
- Updates: Winning `SS_Vendor_Response.award_status = 'AWARDED'`
- Updates: Losing `SS_Vendor_Response.award_status = 'NOT_AWARDED'`

### How the Agent Uses This

When asked to create a request in AWARDED status, the agent:
1. Queries Atlas for the action/process bundles related to "award" in the target application
2. Traces the workflow path backwards from AWARDED to identify all prerequisite transitions
3. For each transition, reads the process model to understand what data is written
4. Constructs a data plan that simulates the cumulative effect of all transitions

### Key Advantage

This is **white-box understanding**. The agent doesn't guess what data should look like — it reads the actual application code that creates the data. When the application is updated (new version parsed by Atlas), the agent's understanding automatically updates too.

---

## Layer 3: Live Environment Introspection (Runtime Validation)

### What It Provides

Real-time information from the target Appian environment:
- Current record type field properties (types, constraints, required fields)
- Available reference data values (what's actually in lookup tables right now)
- Environment-specific configuration (which features are enabled, what integrations exist)
- Current data state (how many records exist, what IDs are in use)

### Source

New APIs built in the Appian application environment:
- **Record Properties API** — returns field metadata for any record type
- **Reference Data API** — returns current values from lookup/constant tables
- **Record Query API** — queries existing records (for exemplar pattern learning)

### What the Agent Learns from This Layer

- "In this environment, the `SS_EVALUATION_METHOD` lookup table has values: LPTA, BEST_VALUE, TRADE_OFF"
- "The `created_by` field requires a valid user ID — available users are: [list]"
- "Record IDs in this environment use auto-increment starting from 10001"
- "The `organization` field references `ORG` table — current orgs are: [list]"

### Why This Layer Is Needed

- Schema (Layer 1) tells you the structure, but not the current valid values
- Workflow analysis (Layer 2) tells you what fields are set, but not what values are valid in *this specific environment*
- Reference data varies between environments (dev vs staging vs demo)
- Some constraints are environment-specific (e.g., integration endpoints, feature flags)

---

## Layer 4: Exemplar Pattern Learning (Ground Truth Cross-Check)

### What It Provides

Real data patterns from existing records in the target environment:
- Complete data footprint of a record in a specific status (all related table rows)
- Actual field value patterns (date ranges, naming conventions, ID formats)
- Implicit relationships not visible in schema or workflow (platform-level side effects)
- Distribution patterns (how many child records per parent, typical value ranges)

### Source

Query APIs against the target environment:
- "Give me all data related to request #123 which is in AWARDED status"
- Returns: the request record + all related evaluation records + vendor responses + award decisions + audit trail

### What the Agent Learns from This Layer

- "A real AWARDED request has exactly 1 award decision record, 3-5 evaluation records, and 2-4 vendor responses"
- "The `evaluation_score` field ranges from 0.0 to 100.0 with most values between 60-95"
- "Timestamps follow a logical sequence: created_date < submitted_date < evaluation_start_date < award_date"
- "The Appian platform automatically sets `modified_date` and `modified_by` — I don't need to set these"

### How Exemplars Complement Workflow Analysis

| Aspect | Workflow Analysis Alone | With Exemplar Cross-Check |
|--------|------------------------|---------------------------|
| Platform side effects | Invisible (set by Appian engine) | Visible in real data |
| Default values | May not be in process model | Present in actual records |
| Data distributions | Knows what's written, not typical ranges | Shows realistic ranges |
| Implicit constraints | Only explicit checks visible | Reveals hidden patterns |
| Validation | Theoretical correctness | Empirical correctness |

### Usage Pattern

Exemplars serve as a **validation oracle**, not the primary source of truth:
1. Agent builds data plan from workflow analysis (Layer 2)
2. Agent queries an exemplar in the target status
3. Agent cross-checks: "Does my plan produce the same data shape as the real thing?"
4. If discrepancies found → adjusts the plan
5. If no exemplar exists (new status, empty environment) → relies on Layers 1-3 alone

---

## Data Generator MCP Server

### Purpose

The MCP server is the execution layer — it provides the AI agent with tools to actually create, read, update, and delete data in the target Appian environment.

### Tool Categories

#### Schema & Discovery Tools
| Tool | Description |
|------|-------------|
| `get_app_schema` | Returns complete table schema with FK relationships for an application |
| `get_record_properties` | Returns field metadata for a specific record type from the live environment |
| `get_reference_data` | Returns current values from lookup/reference tables |
| `get_insertion_order` | Returns topologically-sorted table list for safe insertion |

#### Exemplar & Query Tools
| Tool | Description |
|------|-------------|
| `query_records` | Query records by type with filters (status, date range, etc.) |
| `get_record_footprint` | Returns all related data for a specific record across all tables |
| `get_status_exemplar` | Finds a record in the requested status and returns its complete data footprint |

#### Write Tools
| Tool | Description |
|------|-------------|
| `create_record` | Creates a single record in a specified record type |
| `update_record` | Updates fields on an existing record |
| `delete_record` | Deletes a record (for cleanup) |
| `bulk_create_records` | Creates multiple records in a single operation |

#### Validation & Utility Tools
| Tool | Description |
|------|-------------|
| `validate_record` | Checks if a record's data is consistent with business rules |
| `get_session_records` | Lists all records created in the current session (for rollback) |
| `rollback_session` | Deletes all records created in the current session |

### Appian-Side APIs

The MCP server communicates with APIs built in the Appian application:

```
┌─────────────────────┐         ┌──────────────────────────────────┐
│  Data Generator     │  HTTP   │  Appian Application Environment  │
│  MCP Server         │────────▶│                                  │
│                     │         │  Web APIs:                       │
│  • Tool handlers    │         │  • /api/record/{type}/create     │
│  • Field registry   │         │  • /api/record/{type}/update     │
│  • Payload builder  │         │  • /api/record/{type}/query      │
│  • Session mgmt     │         │  • /api/record/{type}/properties │
│                     │         │  • /api/reference-data/{table}    │
│                     │         │  • /api/record/{id}/footprint     │
└─────────────────────┘         └──────────────────────────────────┘
```

### Appian Record Type Payload Construction

Appian's CRUD APIs require data in a specific record type reference format. Each field value must be addressed by its full UUID-based reference path:

```
'recordType!{record-type-uuid}RecordTypeName'(
  'recordType!{record-type-uuid}RecordTypeName.fields.{field-uuid}fieldName': value,
  'recordType!{record-type-uuid}RecordTypeName.fields.{field-uuid}fieldName': value,
  ...
)
```

Example for creating an Evaluation record:
```
'recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD'(
  'recordType!{e6bc8561-...}.fields.{1aabcd17-...}evaluationTitle': "Test Evaluation",
  'recordType!{e6bc8561-...}.fields.{4e467ee1-...}evaluationStatusId': 1,
  'recordType!{e6bc8561-...}.fields.{5e919546-...}evaluationStartDate': fn!date(2024, 12, 11),
  'recordType!{e6bc8561-...}.fields.{5a7c462a-...}contractingOfficer': fn!touser("jason.john"),
  'recordType!{e6bc8561-...}.fields.{058baf74-...}isActive': true
)
```

**The field UUIDs come from the Record Type Properties API.** Each field's `reference` property contains the full path including the UUID:
```
reference: 'recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD.fields.{7f7c2d3b-1410-4650-a5c8-afd218753011}evaluationId'
```

**Type-specific value formatting:**

| Field Type | Null Value | Non-null Value |
|-----------|-----------|----------------|
| Integer | `fn!tointeger(null)` | `1001` |
| Text | `""` | `"some text"` |
| Date | `null` | `fn!date(2024, 12, 11)` |
| Datetime | `null` | `fn!datetime(2024, 12, 11, 7, 29, 45, 0)` |
| User | `fn!touser(null)` | `fn!touser("jason.john")` |
| Boolean | `false` | `true` |
| Decimal | `fn!todecimal(null)` | `99.5` |

### MCP Server as Translation Layer

The agent sends simple JSON to the MCP server:
```json
{
  "record_type": "AS_GSS_Evaluation",
  "fields": {
    "evaluationTitle": "Test Evaluation",
    "evaluationStatusId": 1,
    "evaluationStartDate": "2024-12-11",
    "contractingOfficer": "jason.john",
    "isActive": true
  }
}
```

The MCP server handles all the complexity:

1. **Field Registry** — On first use of a record type, calls the Properties API and caches a field registry mapping field names to their full reference paths, types, and metadata. Fields with `isCustomRecordField: true` are marked as non-writable (computed fields like `totalTaskCount`, `vendorCount`, etc.).

2. **Payload Construction** — Maps each field name to its UUID reference path, applies type-specific formatting, and assembles the full Appian record type payload.

3. **Validation** — Rejects attempts to write to custom/computed fields, validates types match, ensures required fields are present.

This keeps the agent's interface clean — it works with human-readable field names and simple values. The MCP server is the translation layer that handles Appian's UUID-based addressing and expression syntax.

### Safety Guardrails

Since this system performs write operations, safety is critical:

1. **Environment Isolation** — The MCP server only connects to designated test/dev environments. Production environments are blocked at the configuration level.

2. **Session Tracking** — Every record created is tracked in a session. The agent can roll back an entire session if something goes wrong.

3. **Confirmation for Bulk Operations** — Operations creating more than N records (configurable threshold) require explicit confirmation.

4. **Validation Before Write** — Optional pre-write validation checks FK constraints, required fields, and data type compatibility before executing.

5. **Rate Limiting** — Write operations are rate-limited to prevent runaway agents from flooding the environment.

6. **Audit Trail** — All operations are logged with timestamp, agent identity, and operation details.

---

## Agent Workflow: End-to-End Example

### Request: "Create 3 Source Selection requests in AWARDED status with LPTA evaluation method and 2 vendors each"

#### Phase 1: Understand the Application (Atlas KB — Layers 1 & 2)

```
Agent → Atlas MCP: search_bundles(app="SourceSelection", query="award")
Agent → Atlas MCP: get_bundle(bundle_id="AS_GSS_Award_Vendor", detail_level="full")
Agent → Atlas MCP: get_bundle(bundle_id="AS_GSS_Submit_Request", detail_level="structure")
Agent → Atlas MCP: get_bundle(bundle_id="AS_GSS_Start_Evaluation", detail_level="structure")
Agent → Atlas MCP: get_bundle(bundle_id="AS_GSS_Complete_Evaluation", detail_level="structure")
Agent → Atlas MCP: get_app_overview(app="SourceSelection")
```

The agent now understands:
- The complete workflow path from Draft to Awarded
- What tables are written at each step
- What fields are set and what rules compute their values
- The dependency order of tables

#### Phase 2: Understand the Environment (Layer 3)

```
Agent → DataGen MCP: get_record_properties(record_type="SS_Request")
Agent → DataGen MCP: get_reference_data(table="SS_EVALUATION_METHOD")
Agent → DataGen MCP: get_reference_data(table="SS_REQUEST_STATUS")
Agent → DataGen MCP: get_insertion_order(app="SourceSelection")
```

The agent now knows:
- Exact field types and constraints in this environment
- Valid reference data values (confirms LPTA is available)
- Current auto-increment state for IDs

#### Phase 3: Learn from Exemplar (Layer 4)

```
Agent → DataGen MCP: get_status_exemplar(
    record_type="SS_Request",
    status="AWARDED",
    evaluation_method="LPTA"
)
```

Returns the complete data footprint of a real AWARDED request. The agent cross-checks its workflow-derived plan against this real data.

#### Phase 4: Construct Data Plan

The agent builds an ordered execution plan:

```
For each of 3 requests:
  1. Create SS_Request (status=AWARDED, eval_method=LPTA, dates in logical sequence)
  2. Create 2x SS_Vendor_Response (linked to request, one AWARDED, one NOT_AWARDED)
  3. Create SS_EvaluationPanel (linked to request, method=LPTA)
  4. Create 2x SS_Evaluation (one per vendor, with LPTA scores)
  5. Create SS_Award_Decision (linked to request, winning vendor)
  6. Create audit trail records for each transition
```

#### Phase 5: Execute

```
Agent → DataGen MCP: create_record(type="SS_Request", fields={...})  → id=10045
Agent → DataGen MCP: create_record(type="SS_Vendor_Response", fields={request_id: 10045, ...})
Agent → DataGen MCP: create_record(type="SS_Vendor_Response", fields={request_id: 10045, ...})
Agent → DataGen MCP: create_record(type="SS_EvaluationPanel", fields={request_id: 10045, ...})
... (continues for all records)
```

#### Phase 6: Validate

```
Agent → DataGen MCP: validate_record(type="SS_Request", id=10045)
Agent → DataGen MCP: get_record_footprint(type="SS_Request", id=10045)
```

Agent confirms the created data matches the expected pattern.

---

## Integration with Existing Atlas Ecosystem

### How This Fits

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ATLAS ECOSYSTEM                                       │
│                                                                             │
│  ┌──────────────┐    ┌───────────────┐    ┌──────────────────────────────┐  │
│  │ Atlas Parser │───▶│ Atlas KB      │───▶│ Atlas MCP Server             │  │
│  │              │    │ (solutions-os)│    │ (read-only exploration)      │  │
│  │ ZIP → JSON   │    │              │    │                              │  │
│  └──────────────┘    └───────┬───────┘    └──────────────────────────────┘  │
│                              │                                               │
│                              │ schema + workflow knowledge                    │
│                              ▼                                               │
│                    ┌──────────────────────────────────────┐                  │
│                    │ Data Generator MCP Server    [NEW]    │                  │
│                    │                                      │                  │
│                    │ • Reads schema from Atlas KB          │                  │
│                    │ • Reads workflow logic from Atlas KB  │                  │
│                    │ • Queries live environment            │                  │
│                    │ • Writes data via Appian APIs         │                  │
│                    └──────────────────────────────────────┘                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Relationship to Existing Components

| Component | Role in Data Generator |
|-----------|----------------------|
| **solutions-atlas-parser** | Produces the schema and workflow knowledge (Layers 1 & 2). Needs enhancement to parse the DDL script from the `scripts/` folder in the application ZIP — extracting table definitions, FK graphs, and reference data inserts into a structured `schema/` output section. |
| **solutions-os (Atlas KB)** | Stores the parsed application data that the Data Generator reads for context. No changes needed — the Data Generator MCP reads from the same KB. |
| **solutions-atlas-mcp-server** | The existing read-only MCP server. The Data Generator agent uses this alongside the new Data Generator MCP for a complete workflow. |
| **Data Generator MCP Server** | **NEW** — The write-capable MCP server that communicates with Appian environment APIs. |
| **Appian Environment APIs** | **NEW** — Web APIs built in the Appian application for CRUD operations and record introspection. |

### Agent Configuration

The AI agent (Kiro/Amazon Q) would have two MCP servers configured:

```json
{
  "mcpServers": {
    "appian-atlas": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "...atlas-mcp-server:latest"],
      "env": {
        "GITLAB_TOKEN": "${GITLAB_TOKEN}",
        "ATLAS_KB_PROJECT_ID": "13490",
        "ATLAS_DATA_PREFIX": "ai-framework/tools/Atlas/solutions-kb/data"
      }
    },
    "appian-data-generator": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "...data-generator-mcp:latest"],
      "env": {
        "APPIAN_ENV_URL": "${APPIAN_ENV_URL}",
        "APPIAN_API_KEY": "${APPIAN_API_KEY}",
        "ALLOWED_ENVIRONMENTS": "dev,test,staging"
      }
    }
  }
}
```

---

## Use Cases

### 1. Manual Testing — Scenario Setup

**User**: "I need to test the award notification email. Create a request that just got awarded."

The agent creates a complete request in AWARDED status with all prerequisite data, so the tester can immediately trigger the notification workflow and verify the email content.

### 2. Automated Test Data Preparation

**User**: "Create test data for the evaluation regression suite: 10 requests in each status (DRAFT, SUBMITTED, IN_EVALUATION, EVALUATION_COMPLETE, AWARDED, CANCELLED)."

The agent creates 60 requests across all statuses, each with appropriate related data, providing comprehensive coverage for automated test suites.

### 3. Performance Testing Data Load

**User**: "Load 10,000 requests distributed across all statuses with realistic proportions (50% AWARDED, 20% IN_EVALUATION, 15% SUBMITTED, 10% DRAFT, 5% CANCELLED). Each should have 3-5 vendors."

The agent generates bulk data with realistic distributions, suitable for performance testing the application under load.

### 4. Demo Environment Setup

**User**: "Set up a demo environment for the customer presentation. Create 5 requests showing the full lifecycle — one in each major status — with the customer's industry-specific terminology."

The agent creates a curated set of records with realistic, presentation-ready data.

### 5. Edge Case Testing

**User**: "Create a request where the evaluation resulted in a tie between two vendors — both have identical weighted scores."

The agent uses its workflow knowledge to understand how scores are calculated and creates data that produces the exact edge case.

### 6. Data Migration Validation

**User**: "Create records that match the data patterns from the v2.7 release so we can test the v2.8 migration scripts."

The agent uses Atlas's version history to understand the old data model and creates records matching the previous schema.

---

## Comparison with Alternative Approaches

### Why Not Just Use the Application UI?

| Factor | UI Automation | Data Generator |
|--------|--------------|----------------|
| Speed | Minutes per record (click through workflow) | Seconds per record (direct API) |
| Bulk capability | Impractical for >10 records | Handles thousands |
| Status flexibility | Must walk through every step | Can create any status directly |
| Reproducibility | Fragile (UI changes break scripts) | Stable (API-based) |
| Edge cases | Hard to create specific data patterns | Full control over field values |

### Why Not Just Write SQL Scripts?

| Factor | Manual SQL Scripts | Data Generator |
|--------|-------------------|----------------|
| Maintenance | Breaks on every schema change | Adapts automatically (reads current schema) |
| Domain knowledge | Requires deep app understanding | AI derives from workflow analysis |
| Correctness | Easy to miss implicit constraints | Validates against exemplars |
| Flexibility | Fixed scenarios | Any scenario on demand |
| Time to create | Hours per scenario | Minutes (natural language request) |

### Why Not Use a Generic Synthetic Data Tool?

| Factor | Generic Tools (Faker, SDV) | Data Generator |
|--------|---------------------------|----------------|
| Workflow awareness | None | Full (reads process models) |
| Business rule compliance | Random values | Computed from actual rules |
| Cross-table consistency | FK-aware at best | Workflow-state-aware |
| Appian-specific knowledge | None | Deep (via Atlas) |
| Status-specific data | Not possible | Core capability |

---

## What Makes This Approach Novel

### The Unique Advantage

Most data generation tools in the industry operate at one of two levels:
1. **Schema-aware** — understand tables and FKs, generate structurally valid data
2. **Statistical** — learn distributions from existing data, generate statistically similar data

Neither understands **workflow semantics** — the business logic that determines what data should exist for a given application state.

Our approach is unique because Atlas has already reverse-engineered the entire application into LLM-readable form. The process models, expression rules, and dependency graphs are all parsed and queryable. This means:

- **The AI can read the actual code that creates the data** — not infer patterns from examples
- **When the application changes, the understanding updates automatically** — Atlas re-parses the new version
- **Edge cases can be constructed deliberately** — the AI knows the validation rules and can create data that tests boundaries
- **New statuses/workflows are immediately supported** — no need to wait for exemplar data to accumulate

### The Feedback Loop

```
Appian App (new version)
    │
    ▼
Atlas Parser (re-parses)
    │
    ▼
Atlas KB (updated knowledge)
    │
    ▼
Data Generator Agent (reads updated workflow)
    │
    ▼
Creates data matching new version's logic
```

This is a self-maintaining system. As the application evolves, the data generator's understanding evolves with it.

---

## Implementation Phases

### Phase 1: Foundation — Schema Layer

**Goal**: Add structured schema data to Atlas KB output by parsing the incremental DDL script from the application's `scripts/` folder

- Build a lightweight SQL DDL replay engine in Python that processes the cumulative script file in order
- Handle CREATE TABLE, ALTER TABLE (ADD/MODIFY/DROP COLUMN, ADD CONSTRAINT, RENAME), DROP TABLE
- Track reference data through INSERT and UPDATE statements, resolving to final active state
- Classify tables by naming convention (business `AS_GSS_*`, reference `*_R_*`, audit `*_A_R_*`, task management `*_TMG_*`)
- Compute topological insertion order from the accumulated FK graph
- Output resolved final state as `schema/` section in the KB: `tables.json`, `relationships.json`, `reference_data.json`, `insertion_order.json`, `table_classification.json`
- Handle edge cases: conditional DDL (`IF NOT EXISTS`, `IF EXISTS`), the script execution framework wrapper (CALL procedures that gate execution), and idempotent patterns

**Depends on**: solutions-atlas-parser changes (the scripts folder is already available in the ZIP — we just need to parse and replay it)

### Phase 1 Prototype: Validated

A working prototype (`ddl_replay.py`) has been built and validated against the Source Selection v2.9.0 DDL script (11,499 lines). Results:

| Metric | Value |
|--------|-------|
| Tables parsed | 84 (18 business, 17 reference, 37 audit, 10 task mgmt, 2 framework) |
| FK relationships extracted | 153 |
| Reference data rows captured | 216 across 10 tables |
| Topological sort violations | 0 ✅ |
| Table renames resolved | 40 |

**Challenges solved in the prototype:**

1. **GAM Script Execution Framework wrapper** — The DDL script doesn't contain bare SQL statements. Every DDL operation is wrapped inside a stored procedure for idempotent execution:
   ```sql
   DELIMITER $$
   CREATE PROCEDURE AS_GAM_RunFrameworkScript()
   BEGIN
   CALL AS_GAM_Initial_Execution("N", 6, "Source Selection 1.0", 345, ...);
   IF @cont > 0 THEN
   -- START SCRIPT CONTENT ---
   CREATE TABLE IF NOT EXISTS `AS_GSS_EVALUATION` (...);
   -- END SCRIPT CONTENT ---
   CALL AS_GAM_Update_Execution(...);
   END IF;
   END $$
   DELIMITER ;
   ```
   The engine extracts content between `-- START SCRIPT CONTENT ---` and `-- END SCRIPT CONTENT ---` markers, ignoring the framework wrapper.

2. **Table renames** — 40 tables are renamed later in the script (long names shortened for MySQL identifier limits). The engine tracks all renames and resolves old names when processing FK constraints and INSERT statements that reference the original name.

3. **Multi-clause ALTER TABLE** — Statements like `ALTER TABLE X ADD KEY ..., ADD CONSTRAINT ... FOREIGN KEY ...` contain multiple clauses separated by commas. The engine splits these at the top level and processes each clause independently.

4. **Reference data consolidation** — INSERT statements use old table names (before rename). The engine consolidates all reference data under the final (current) table name.

5. **The `AS_GSS_R_DATA` pattern** — This single reference table contains all enum/status values for the application, grouped by a `REF_TYPE` column. The prototype captures 45 rows spanning 15 types: Evaluation Status, Evaluation Method, Document Type, Review Type, Consensus Status, etc. This is the primary source of valid field values for the data generator.

**Output files produced:**
- `schema/tables.json` — 75KB, all 84 tables with full column definitions
- `schema/relationships.json` — 29KB, all 153 FK relationships
- `schema/reference_data.json` — 46KB, all reference data rows
- `schema/insertion_order.json` — topologically sorted table list (0 violations)
- `schema/table_classification.json` — tables categorized by type

**Prototype location:** `/atlas-data-generator/ddl_replay.py`

### Phase 2: Appian Environment APIs

**Goal**: Build the CRUD and introspection APIs in the Appian application

- Record Properties API (field metadata)
- Reference Data API (lookup table values)
- Record CRUD APIs (create, update, delete, query)
- Record Footprint API (all related data for a record)

**Depends on**: Appian application development

### Phase 3: Data Generator MCP Server

**Goal**: Build the MCP server that exposes tools to the AI agent

- Schema & discovery tools
- Exemplar & query tools
- Write tools with safety guardrails
- Session management and rollback
- Docker packaging and CI/CD

**Depends on**: Phase 2 (APIs must exist)

### Phase 4: Agent Integration & Steering

**Goal**: Configure the AI agent to use both Atlas MCP and Data Generator MCP effectively

- Steering documents for the data generator power
- Prompt engineering for workflow analysis
- Status recipe templates (optional — for common scenarios)
- Integration testing with real applications

**Depends on**: Phases 1-3

### Phase 5: Advanced Capabilities

**Goal**: Extend beyond basic data creation

- Bulk generation with realistic distributions
- Performance test data loading (parallel execution)
- Cross-application data generation (e.g., GAM Suite shared data)
- Data cleanup and environment reset tools
- Version-aware generation (create data matching a specific app version)

---

## Open Questions & Decisions

1. **Which application first?** — **Source Selection.** Most mature in Atlas KB, DDL prototype already validated against it.

2. **API authentication model** — Environment details (URL, API key) are configured as parameters to the MCP server. No special auth framework needed — standard Appian API key approach. First iteration will have a few basic CRUD APIs built in the Appian application.

3. **Environment targeting** — Handled via MCP server configuration parameters. The environment URL is passed as a config param, so there's no risk of accidental production writes — the server only connects to what's configured.

4. **Schema output location** — Under `data/<AppName>/current/schema/` in the existing Atlas KB structure. Consistent with how the MCP server already reads data.

5. **Multiple script files** — Mostly a single file per application. If multiple exist, parse them sequentially (filename order: `01.*.sql`, `02.*.sql`).

6. **Status recipes** — Will be manually created and maintained. Stored as structured documents that map status → required table data patterns.

7. **Bulk performance** — Deferred. Will address later when performance testing use case is prioritized.

8. **Cross-application tables** — `AS_GAM_*` shared tables are reference-only. The data generator does NOT insert into cross-application tables — they exist in the schema for FK reference understanding only. Data generation targets only the application-specific tables.

9. **Record type reference resolution** — The agent uses the Atlas KB to map DDL table names (e.g., `AS_GSS_EVALUATION`) to Appian record type references (e.g., `recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD`). The parsed record type objects in the KB contain both the UUID and the underlying table mapping.

10. **Primary keys** — Auto-generated by Appian. The agent does NOT supply PK values when creating records. The API returns the generated ID for use in subsequent chained inserts.

11. **Payload sparsity** — Only non-null fields need to be sent in the CRUD API payload. The agent omits fields it doesn't need to set.

12. **User discovery** — A separate API call (`list_users`) provides available usernames in the target environment for populating User-type fields.

13. **Record type discovery** — The agent reads available record types from the Atlas KB (not from a live API). The KB's parsed objects list all record types with their references. The Properties API is then called with the full reference: `a!recordTypeProperties(recordType: 'recordType!{uuid}Name')`.

---

## Summary

The Atlas Data Generator extends the Atlas ecosystem from **read-only application intelligence** to **active data manipulation**. By combining Atlas's deep understanding of application structure and workflow logic with live environment APIs, it enables AI agents to create realistic, workflow-aware test data on demand.

The four-layer context stack (Schema → Workflow → Live Introspection → Exemplar Patterns) provides progressively deeper understanding, making this approach fundamentally more capable than any existing test data generation tool for complex workflow-driven applications.

The key architectural insight is that **Atlas already reverse-engineered the application into LLM-readable form** — we're now using that same reverse-engineering to drive forward-engineering of data. This creates a self-maintaining system where the data generator's capabilities automatically evolve as the application evolves.
