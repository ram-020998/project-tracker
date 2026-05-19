# Atlas Demo Driver — Project Tracker

**Last Updated:** 2026-05-19

---

## Overview

A Kiro power that generates realistic, workflow-aware test and demo data directly in Appian environments. It combines schema intelligence from the Atlas KB with write operations via the Data Generator MCP server, following a strict 7-step process (Step 0 + Steps 1-6) with sub-agent orchestration.

**Location:** `appian/solutions-os/ai-framework/Engineering/.kiro/powers/atlas-demo-driver/`

---

## Session Log

### 2026-05-19 — Major Steering Overhaul + Sub-Agent Architecture

#### Completed

- Created the `atlas-demo-driver` power (separated from `atlas-sql-forge`)
- Built 7 hardened steering files modeled after the code-review-workflow pattern:
  - `step-0-initialize.md` — 6 PENDING files + execution tracker
  - `step-1-workflow-analysis.md` — exhaustive PM/rule/subprocess trace
  - `step-2-exemplar-discovery.md` — all tables queried + reconciliation gate
  - `step-3-data-architecture.md` — coverage checklist + field maps + live ref data
  - `step-4-data-payloads.md` — split payload files with field_reasoning
  - `step-5-validation.md` — 4 automated checks (table coverage, FK, exemplar diff, ref IDs)
  - `step-6-execute.md` — create, verify, document
- Moved all files from `steering/workflow-steps/` to flat `steering/` (Kiro doesn't support subfolders)
- Implemented sub-agent orchestration via `subagent` tool (Kiro native feature)
- Added `writes_to` metadata extraction in parser's `bundle_builder.py`
- Split `payloads.json` into multiple small files (`payloads/01-xxx.json`, `02-xxx.json`, etc.)
- Added chunked file writing instructions (create + insert, no strReplace)
- Added rule: "ALL application data comes from Atlas KB only — never local files"
- Removed single-agent fallback — sub-agents are mandatory
- Ran 3 test iterations, identified and fixed issues each time

#### Decisions Made

- Sub-agents for each step (reason: fresh context per step, no token exhaustion, each step gets full attention)
- Split payloads into multiple files (reason: agent struggles to write large JSON in one operation)
- No subfolder in steering/ (reason: Kiro powers can't read files with path separators)
- No hardcoded app-specific data in steering (reason: must work for any application)
- Removed human approval gate (reason: users don't know table structures, just confirm record count)
- Deferred Record Footprint Query and Exemplar Cloning features (reason: focus on core workflow first)
- Added `writes_to` to bundles instead of new `workflow_graph.json` (reason: data already exists in bundles, just needs annotation)

#### Issues Encountered

- Agent only traced final action PM, missed auto-generated records from earlier transitions → Fixed by rewriting Step 1 to mandate tracing ENTIRE lifecycle
- Agent did not create template files at start → Fixed with Step 0 + blocking rules
- Kiro can't read steering files in subfolders → Moved all to flat `steering/`
- Agent struggled with large file writes (6+ edits, failures) → Split payloads into multiple small files, added chunked write instructions
- Agent reading local files for app context instead of KB → Added explicit rule at POWER.md + step level
- Main agent executing steps itself instead of spawning sub-agents → Removed fallback, made sub-agents mandatory with stronger language

#### Parser Enhancement

- File: `appian_parser/output/bundle_builder.py`
- Added `_extract_writes_to()` method — scans PM nodes for Write Records/Write to Data Store types, extracts recordType! references from inputs
- Also scans Expression Rules for `a!writeRecords` patterns
- Added to both action bundles and process bundles
- All 302 parser tests passing

#### Learnings

- Kiro `subagent` tool supports sequential pipelines with `depends_on` — perfect for our workflow
- Agents cut corners on detail depth even with strict rules — need explicit quality checks + reconciliation gates
- File write operations have practical size limits — split large outputs
- `strReplace` fails on complex content — use `create` + `insert` (append) instead
- Steering files need to say what NOT to do as much as what TO do (common failures table)

#### Remaining Items

- [ ] Run full end-to-end test with new sub-agent pipeline
- [ ] Verify `writes_to` field appears in parsed bundles (needs a dump package with PMs)
- [ ] Add new Atlas MCP tool to serve `writes_to` data (or include in existing bundle response)
- [ ] Test with applications other than SourceSelection
- [ ] Consider reducing Step 1 token usage by using `writes_to` from bundles directly
- [ ] Track if sub-agent handoff loses critical context between steps

---

## What It Does

Given a natural language request like "Create an evaluation in Complete status with 3 vendors", it:

1. Analyzes the application's workflow logic from Atlas KB
2. Finds a real record in the target status as a template
3. Maps all required tables, FKs, and reference data
4. Generates exact payloads with documented reasoning for every value
5. Gets user approval
6. Creates records in the live Appian environment with correct relationships

---

## Architecture

```
Atlas KB (schema data)
    │
    ▼
Atlas MCP Server (read-only tools)
    │  get_record_type_map, get_field_map, get_reference_data,
    │  get_insertion_order, search_bundles, get_bundle, get_object_code
    │
    ▼
Atlas Demo Driver Power (orchestration + steering)
    │  6-milestone workflow, file generation, validation
    │
    ▼
Data Generator MCP Server (write tools)
    │  create_record, query_records, list_users, rollback_session
    │
    ▼
Appian Environment (live database via Web APIs)
    │  /suite/webapi/record/{method}
    │  /suite/webapi/users/list
    ▼
Records created in the application
```

---

## Components

### 1. Atlas KB (Schema Data)

Auto-generated from DDL scripts on every package sync by the parser.

| File | Content |
|------|---------|
| `tables.json` | Table definitions with columns, types, PKs |
| `relationships.json` | FK graph (from_table, to_table, columns) |
| `record_type_map.json` | Table → record type UUID + relationship names |
| `field_map.json` | UPPER_SNAKE column → camelCase field name |
| `reference_data.json` | Ref table metadata (UUID, row_count, ref_types) |
| `insertion_order.json` | Topologically sorted table list |
| `table_classification.json` | business/reference/audit/task_management/framework |
| `summary.json` | Statistics |

### 2. Atlas MCP Server

Docker image: `registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest`

Key tools for this power:
- `get_record_type_map` — ALL table UUIDs + relationships in one call
- `get_field_map` — ALL column → field name mappings in one call
- `get_reference_data` — ref table UUIDs for live querying
- `get_insertion_order` — creation sequence
- `search_bundles` / `get_bundle` / `get_object_code` — workflow analysis

### 3. Data Generator MCP Server

Docker image: `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`

| Tool | Purpose |
|------|---------|
| `create_record` | Create with optional `related_records` for nested children |
| `update_record` | Partial update (includes PK automatically) |
| `delete_record` | Soft delete (isActive=false) |
| `query_records` | Filters, paging (1-based startIndex, no selected_fields) |
| `get_record_properties` | Live field metadata from environment |
| `list_users` | Valid usernames |
| `get_session` | View created records |
| `rollback_session` | Reverse-order soft delete of all session records |

### 4. Appian Web APIs

Deployed on target environment. Generic — work with ANY record type.

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/suite/webapi/record/properties` | POST | Field metadata |
| `/suite/webapi/record/create` | POST | Create (supports relatedRecords) |
| `/suite/webapi/record/update` | POST | Update (PK in fields) |
| `/suite/webapi/record/delete` | POST | Soft delete (PK + isActive=false) |
| `/suite/webapi/record/query` | POST | Query with filters/paging |
| `/suite/webapi/users/list` | POST | List usernames |

---

## 6-Milestone Workflow

### Step 0: Initialize
Create folder `data-requests/<date>_<description>/` with all 5 files in PENDING state.

### M1: Workflow Analysis → `analysis.md`
- Query Atlas KB for process models related to the target status
- Trace the workflow path (transitions, what data is created at each step)
- Document business rules that affect field values

### M2: Exemplar Discovery → `exemplar.md`
- Query the live environment for a record in the target status
- Fetch ALL fields (no selected_fields filter)
- Query ALL relationships (every child record type)
- Document complete data footprint as ground truth
- **NEVER skipped** — if no records in target status, try any status

### M3: Data Architecture → `data-architecture.md`
- Call `get_record_type_map` for UUIDs + relationships
- Call `get_field_map` for field name mappings
- Call `get_reference_data` + `query_records(ref_uuid)` for live values
- Call `get_insertion_order` for creation sequence
- Call `list_users` for valid usernames
- **Record Type Coverage Checklist** — explicit INCLUDE/EXCLUDE for every relationship

### M4: Data Payloads → `payloads.json`
- Generate exact field values with reasoning for every value
- Use `related_records` for parent-child creation
- **Field Completeness Verification** — call `get_record_properties` for each record type, verify ≥80% coverage
- Document `field_coverage` stats in the payload
- Every null field must have a documented reason

### M5: Validation & Approval
- Present complete plan to user
- Show record counts, key values, relationships
- **WAIT for user approval** — never auto-execute

### M6: Execution → `execution-log.md`
- Create records using payloads.json as source of truth
- Use `related_records` for atomic parent+children writes
- Report each creation with record ID
- Verify via `query_records`
- Document all IDs and verification results

---

## Key Rules

| Rule | Description |
|------|-------------|
| No hardcoded data | All values from live queries (ref data, users, UUIDs) |
| `get_record_type_map` first | One call for all UUIDs + relationships |
| `get_field_map` second | One call for all field name mappings |
| Reference data live | `query_records(ref_uuid)` — never from KB |
| Maximize field population | Fill ALL writable fields, document every null |
| No `selected_fields` | Always fetch all fields in queries |
| Documents are gates | File must exist before next milestone starts |
| `payloads.json` is truth | Execution reads from it, doesn't improvise |
| Exemplar never skipped | Always query real data as template |
| ≥80% field coverage | Stop and re-examine if below threshold |

---

## Power Structure

```
atlas-demo-driver/
├── .kiro/steering.md                     # Power metadata
├── mcp.json                              # Both MCP servers
├── POWER.md                              # Main instructions + rules + action router
├── README.md
└── steering/
    ├── action-generate-data.md           # 6-milestone workflow (Step 0 + M1-M6)
    ├── action-query-and-validate.md      # Query and verify records
    ├── action-rollback.md                # Session cleanup
    ├── tool-reference-atlas.md           # Atlas MCP tools (7 schema + 6 app tools)
    └── tool-reference-data-generator.md  # Data Generator MCP tools (8 tools)
```

---

## Environment Configuration

```bash
export GITLAB_TOKEN="<gitlab-token>"           # For Atlas MCP (read KB)
export APPIAN_ENV_URL="https://<env>.appiancloud.com"  # Target environment
export APPIAN_API_KEY="<api-key>"              # For Data Generator MCP
```

---

## Relationship to Other Powers

| Power | Scope |
|-------|-------|
| **atlas-demo-driver** | Live environment data creation (this power) |
| `atlas-sql-forge` | Bulk SQL scripts, ERD generation, SAIL-to-SQL |
| `atlas-developer` | Code exploration, impact analysis, design docs |

---

## Repos Involved

| Repo | Role |
|------|------|
| `appian/solutions-atlas-parser` | Generates schema data in KB |
| `appian/solutions-atlas-mcp-server` | Serves schema via MCP (32 tools) |
| `ramaswamy.u/solutions-atlas-dg-mcp-server` | Data Generator MCP (8 tools, Docker) |
| `ramaswamy.u/solutions-atlas-kb` | KB storage with schema files |
| `appian/solutions-os` | Power location (ai-framework/Engineering/.kiro/powers/) |
