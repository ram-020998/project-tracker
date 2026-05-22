# Atlas Data Generator — Progress Tracker

**Last Updated:** 2026-05-22

---

## Project Overview

AI-driven test data generation for Appian applications. Uses Atlas KB (application structure + workflow logic) combined with a Data Generator MCP server to create realistic, workflow-aware test data via CRUD APIs or bulk SQL scripts.

**Repos involved:**
| Repo | Location | Purpose |
|------|----------|---------|
| `solutions-atlas-parser` | `appian/solutions-atlas-parser` | Parses Appian packages, includes schema extraction |
| `solutions-atlas-mcp-server` | `appian/solutions-atlas-mcp-server` | Read-only MCP for application intelligence + schema tools |
| `solutions-atlas-dg-mcp-server` | `ramaswamy.u/solutions-atlas-dg-mcp-server` | Write-capable MCP for data operations |
| `solutions-atlas-kb` | `ramaswamy.u/solutions-atlas-kb` | KB storage, CI sync pipeline |
| `atlas-data-generator-power` | `ramaswamy.u/atlas-data-generator-power` | Kiro power with steering files |

---

## Phase 1: Schema Layer ✅ COMPLETE

- DDL replay engine integrated into parser (both `dump_package` and `delta_package` paths)
- Outputs to `data/<AppName>/current/schema/` (6 JSON files)
- 5 schema query tools added to Atlas MCP server
- Parser: 302 tests passing | MCP Server: 77 tests passing
- Validated against all 14 packages (2.44s total)
- **Merged to main** in both parser and MCP server repos

---

## Phase 2: Appian Environment APIs ✅ COMPLETE

### APIs Deployed on `merge-assist.appianpreview.com`
| API | Endpoint | Notes |
|-----|----------|-------|
| Properties | `POST /suite/webapi/record/properties` | Returns columnar field metadata |
| Create | `POST /suite/webapi/record/create` | Supports `relatedRecords` for nested writes |
| Update | `POST /suite/webapi/record/update` | PK in fields → update |
| Delete | `POST /suite/webapi/record/delete` | PK + isActive:false → soft delete |
| Query | `POST /suite/webapi/record/query` | Filters, pagingInfo (1-based startIndex) |
| Users | `POST /suite/webapi/users/list` | Returns flat username strings |

### Appian Rules Created
| Rule | Purpose |
|------|---------|
| `ADG_API_recordOperations` | Web API router (record/{method}) |
| `ADG_API_users` | Web API router (users/{method}) |
| `ADG_UT_getRecordTypeProperties` | Returns field metadata with `tostring()` on references |
| `ADG_UT_createOrUpdateRecords` | Builds record + related records, calls `a!writeRecords` |
| `ADG_UT_buildRelatedRecords` | Constructs nested child records for relationships |
| `ADG_UT_applyRelatedRecords` | Applies one relationship at a time (avoids list flattening) |
| `ADG_UT_queryRecordTypeWithFilters` | Query with dynamic filters, paging, sort |
| `ADG_UT_convertFieldValue` | Type conversion (Date, Datetime, User, Integer, Decimal, Boolean) |
| `ADG_UT_returnFieldReferenceFromFieldName` | Maps camelCase name → UUID reference |
| `ADG_UT_returnRecordReferenceFromUuid` | `eval(concat("recordType!{", uuid, "}"))` |
| `ADG_UT_initialiseEmptyRecordForGivenUuid` | Creates empty record instance |
| `ADG_UT_queryUsersFromEnvironment` | Queries User record type, returns `tostring()` usernames |

### Key Technical Details
- Appian `a!toJson` on `a!recordTypeProperties` returns **columnar format**: `fields: [{"name": [...], "type": [...]}]`
- `reference` field requires `tostring()` before JSON serialization
- Related records use `reduce` pattern to avoid `a!forEach` list flattening
- `startIndex` is 1-based (0 causes 500 error)
- Type conversion handles null values per type (e.g., `touser(null)` not just `null`)

---

## Phase 3: Data Generator MCP Server ✅ COMPLETE

### Deployment
- **GitLab:** `ramaswamy.u/solutions-atlas-dg-mcp-server`
- **Docker image:** `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`
- **Pipeline:** Lint + Test + Build (kaniko from `gcr.io`) — all passing
- **Local:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp`

### Tools (8)
| Tool | Description |
|------|-------------|
| `get_record_properties` | Field metadata (handles columnar format) |
| `create_record` | Create with optional `related_records` for nested children |
| `update_record` | Partial update (auto-includes PK) |
| `delete_record` | Soft delete (isActive=false) |
| `query_records` | Filters, paging (enforces startIndex≥1) |
| `list_users` | Flat username strings |
| `get_session` | Session summary (shared singleton) |
| `rollback_session` | Reverse-order soft delete of all session records |

### Key Implementation Details
- `field_registry.py` handles both columnar and row response formats
- All tools share `SessionManager` via `_shared.py` (fixes session tracking)
- `create_record` supports `related_records` for atomic parent+children creation
- `query_records` enforces `startIndex >= 1` (Appian is 1-based)
- 16 unit tests passing

### E2E Verified
- Create → Query → Session → Rollback: all working
- Related records (parent + children in one call): working
- Soft delete correctly sets isActive=false

---

## Phase 4: Agent Integration & Steering ✅ COMPLETE

### Power: `atlas-sql-forge` (renamed from atlas-data-generator)
- **Production Location:** `appian/solutions-os/ai-framework/Engineering/.kiro/powers/atlas-sql-forge/`
- **Dev Location:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-power` (original)
- **Format:** Standard Kiro power (same as atlas-developer, atlas-dev-documentation)
- **MCP Servers:** Atlas (read) + Data Generator (write) in `mcp.json`

### Skill: `atlas-data-generator-skill`
- **Location:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-skill/`
- Standalone skill for integration into any agent
- 2 files: `SKILL.md` (main, 220 lines) + `rollback.md`
- `INTEGRATION.md` documents how to plug into testing agents

### Power Structure (Updated 2026-05-22)
```
atlas-sql-forge/
├── POWER.md                              # Main instructions + dual-mode action router
├── mcp.json                              # Both MCP servers (Atlas + DG)
├── .kiro/steering.md                     # Power metadata + architecture diagram
├── README.md                             # Detailed documentation (576 lines)
└── steering/
    ├── action-generate-data.md           # Orchestrator: sub-agents + mode routing
    ├── action-bulk-sql.md                # Redirect → action-generate-data in sql mode
    ├── action-explore-schema.md          # Schema exploration
    ├── action-query-and-validate.md      # Query and verify
    ├── action-rollback.md                # Session cleanup
    ├── step-0-initialize.md             # Create folder + 6 PENDING files + tracker
    ├── step-1-workflow-analysis.md      # Exhaustive PM/rule trace (3-part per action)
    ├── step-2-exemplar-discovery.md     # Real record + reconciliation gate
    ├── step-3-data-architecture.md      # Field maps, live ref data, coverage checklist
    ├── step-4-data-payloads.md          # Split files, field_reasoning, ≥80% coverage
    ├── step-5-validation.md             # 4 automated checks
    ├── step-6-execute.md                # Records mode: API calls + verify
    ├── step-6-generate-sql.md           # SQL mode: INSERT stmts + LAST_INSERT_ID
    ├── tool-reference-atlas.md           # Atlas MCP schema tools
    └── tool-reference-data-generator.md  # DG MCP tools
```

### Major Update: Dual-Mode 6-Step Workflow (2026-05-22)
- Adopted the elaborated 6-step workflow from `atlas-demo-driver` (sub-agent orchestration)
- SQL Forge now supports **both** test data generation (records via API) AND bulk SQL generation
- Steps 0-5 are identical for both modes; Step 6 diverges (execute vs generate-sql)
- Sub-agents run Steps 1-5 (fresh context per step, no token exhaustion)
- Orchestrator runs Step 6 directly (user interaction during execution)
- Hardened steering files with blocking checks, quality gates, execution tracker
- Split payloads into multiple small files (robust writes)
- Demo Driver stays as-is (records-only, separate power)

### Data Generation Workflow (6 Milestones)
| # | Milestone | Output | Purpose |
|---|-----------|--------|---------|
| 0 | Initialize | All 5 empty files | Create folder + PENDING files upfront |
| M1 | Workflow Analysis | `analysis.md` | Query Atlas KB for process models, trace workflow |
| M2 | Exemplar Discovery | `exemplar.md` | Find real record, document ALL relationships (mandatory, never skipped) |
| M3 | Data Architecture | `data-architecture.md` | Map tables, FKs, ref data + coverage checklist |
| M4 | Data Payloads | `payloads.json` | Exact values + field completeness verification (≥80%) |
| M5 | Validation & Approval | User confirms | Present plan, wait for explicit approval |
| M6 | Execution | `execution-log.md` | Create records, verify, document |

### Key Steering Rules (Latest)
- **Step 0:** Create all 5 empty files with PENDING status at start — no document forgotten
- **Exemplar is NEVER skipped** — if no records in target status, try any status; if empty, do structural analysis
- **Field completeness verification** — call `get_record_properties` for each record type, verify ≥80% coverage
- **No hardcoded data in steering** — all values from live queries (ref data, users, UUIDs)
- **`get_record_type_map` first** — one call for all UUIDs + relationships
- **`get_field_map` second** — one call for all column→field mappings
- **Reference data queried live** — `query_records(ref_uuid)` not from KB (KB has metadata only)
- **Documents are mandatory gates** — file must exist before next milestone starts
- **`payloads.json` is source of truth** — execution reads from it, doesn't improvise
- **Related records** — use `related_records` for parent+children (atomic, no FK management)

---

## Phase 5: Advanced Capabilities 🔄 PARTIALLY STARTED

| Capability | Status | Notes |
|-----------|--------|-------|
| Related record writes | ✅ Done | `create_record` supports `related_records` |
| Bulk SQL generation | ✅ Done | `action-bulk-sql.md` steering file |
| Exemplar discovery | ✅ Done | M2 queries all relationships, never skipped |
| Record type coverage checklist | ✅ Done | M3 verification step |
| ERD Generation (Draw.io) | ✅ Done | `action-erd.md` supports .drawio, .md, .html output |
| Field completeness verification | ✅ Done | M4 verifies ≥80% coverage via `get_record_properties` |
| `record_type_map.json` | ✅ Done | Table → UUID + relationships (parser generates) |
| `field_map.json` | ✅ Done | UPPER_SNAKE → camelCase (parser generates) |
| Reference data metadata only | ✅ Done | KB stores metadata, agent queries live values |
| Atlas MCP new tools | ✅ Done | `get_record_type_map`, `get_field_map` (32 tools total) |
| Step 0 initialization | ✅ Done | Creates all empty files upfront |
| `writes_to` bundle metadata | ✅ Done | Parser extracts write targets from PM nodes + expression rules |
| Atlas Demo Driver power | ✅ Done | Separate power for live env data generation, sub-agent orchestration |
| Power migrated to solutions-os | ✅ Done | `atlas-sql-forge` in Engineering powers |
| Presentation created | ✅ Done | `finalPresentation/presentation.html` |
| Skill created | ✅ Done | Standalone skill for any agent integration |
| Record footprint query | ⏳ Pending | Need dedicated API endpoint |
| Environment management | ⏳ Pending | Cleanup/reset tools |
| Version-aware generation | ⏳ Pending | Historical schema support |
| Multi-entity scenarios | ⏳ Pending | Complex cross-table scenarios |

---

## Bugs Fixed During Testing

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| `a!toJson` fails on `reference` field | Type reference (it=284) not serializable | `tostring(fv!item.reference)` |
| `unhashable type: 'list'` in field_registry | Appian returns columnar format `[{"name": [...]}]` | Handle both columnar and row formats |
| Session tracking shows 0 records | Each tool file had its own `SessionManager` instance | Shared singleton via `_shared.py` |
| 500 on query with startIndex=0 | Appian paging is 1-based | Enforce `startIndex >= 1` |
| `a!update` key/value mismatch for related records | `a!forEach` flattens nested lists | Use `reduce` pattern (one relationship at a time) |
| Schema not generated on delta parse | `delta_package()` didn't call schema extraction | Added schema extraction to delta path |
| Docker build fails (appian/prod access) | `stratus-service` component needs appian/prod registry | Use `gcr.io/kaniko-project/executor` directly |
| Reference data empty in KB | KB synced before parser merge | Re-triggered sync after merge |
| Atlas MCP returns empty ref data | LRU cache holds stale data | Restart MCP container (cache flushes on staleness check) |
| 404 on users endpoint | Wrong path `/suite/webapi/users` vs `/suite/webapi/users/list` | URL alias is `users/list` |

---

## Key Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Separate MCP servers | Atlas (read) + Data Generator (write) | Different security posture, credentials |
| Schema source | DDL script from scripts/ folder | Authoritative, includes all tables + ref data |
| DDL parsing | Custom regex replay engine | 16x faster than simple-ddl-parser, more complete |
| Reference data detection | Any table with INSERT = reference | Works across all naming conventions |
| API payload format | Simple JSON (camelCase) → Appian handles conversion | Agent doesn't need UUID knowledge |
| Related records | Nested in single `a!writeRecords` call | Atomic, auto-links FKs |
| Bulk data | SQL file generation | Bypasses API for 100+ records |
| Exemplar pattern | Query real data as ground truth | Validates workflow analysis |
| Field population | Maximize — fill all writable fields | Realistic data, not skeleton inserts |
| Docker builds | kaniko from gcr.io (public) | No appian/prod registry access needed |

---

## Quick Start for New Session

### Repos
1. **Parser:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-parser` — `python3 -m pytest tests/`
2. **Atlas MCP:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-mcp-server` — `python3 -m pytest tests/` (32 tools)
3. **DG MCP:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp` — `python3 -m pytest tests/`
4. **Power (prod):** `appian/solutions-os/ai-framework/Engineering/.kiro/powers/atlas-sql-forge/`
5. **Power (dev):** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-power`
6. **Skill:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-skill`
7. **KB:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-atlas-kb`

### Testing
- E2E test: `python3 /Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/test_mcp_e2e.py`
- Related records test: `python3 /Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/test_related_records.py`
- Field check: `python3 /Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/check_fields.py`

### Environment
- **Appian:** `https://merge-assist.appianpreview.com`
- **APIs:** `/suite/webapi/record/{method}`, `/suite/webapi/users/list`
- **Docker image:** `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`

### Schema Files in KB (8 files)
- `tables.json` — table definitions
- `relationships.json` — FK graph
- `reference_data.json` — metadata only (UUID, row_count, ref_types)
- `insertion_order.json` — topological sort
- `table_classification.json` — business/reference/audit
- `summary.json` — statistics
- `record_type_map.json` — table → UUID + relationships
- `field_map.json` — UPPER_SNAKE → camelCase

### Reference: Similar Project
- **ASPECT** (`amrut.rao/ASPECT`) — SQL-only test data generator power. Schema-driven, no MCP. Has solution profiles.
