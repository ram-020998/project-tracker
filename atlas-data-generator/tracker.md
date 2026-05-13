# Atlas Data Generator — Progress Tracker

**Last Updated:** 2026-05-13 (Evening)

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

### Power: `atlas-data-generator-power`
- **Location:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-power`
- **MCP Servers:** Atlas (read) + Data Generator (write)
- **Docker images:** Both configured in `mcp.json`

### Structure
```
atlas-data-generator-power/
├── POWER.md                              # Main instructions + action router + 10 critical rules
├── mcp.json                              # Both MCP servers configured
├── .kiro/steering.md                     # Power metadata
├── README.md
└── steering/
    ├── action-generate-data.md           # 6-milestone workflow (750+ lines)
    ├── action-bulk-sql.md                # Bulk SQL generation for 100+ records
    ├── action-explore-schema.md          # Schema exploration
    ├── action-query-and-validate.md      # Query and verify
    ├── action-rollback.md                # Session cleanup
    ├── tool-reference-atlas.md           # 5 Atlas schema tools
    └── tool-reference-data-generator.md  # 8 DG tools (with related_records docs)
```

### Data Generation Workflow (6 Milestones)
| # | Milestone | Output | Purpose |
|---|-----------|--------|---------|
| M1 | Workflow Analysis | `analysis.md` | Query Atlas KB for process models, trace workflow path |
| M2 | Exemplar Discovery | `exemplar.md` | Find real record in target status, document full data footprint |
| M3 | Data Architecture | `data-architecture.md` | Map tables, FKs, ref data + record type coverage checklist |
| M4 | Data Payloads | `payloads.json` | Exact values with reasoning, validated against exemplar |
| M5 | Validation & Approval | User confirms | Present plan, wait for explicit approval |
| M6 | Execution | `execution-log.md` | Create records, verify, document |

### Key Steering Rules
- **Maximize field population** — fill ALL writable fields, document reason for every null
- **Exemplar as ground truth** — query ALL relationships, not just predicted ones
- **Record type coverage checklist** — explicit INCLUDE/EXCLUDE for every relationship
- **Never pass `selected_fields`** — always fetch all fields by default
- **Related records preferred** — use `related_records` for parent+children (atomic, no FK management)
- **Never skip milestones** — even simple requests go through all 6

### Bulk SQL Generation (`action-bulk-sql.md`)
- For 100+ records, generates MySQL INSERT scripts
- Uses `LAST_INSERT_ID()` for FK linking
- Batches at 100 rows per INSERT
- Disables FK checks for speed
- Includes sync reminder for Appian

---

## Phase 5: Advanced Capabilities 🔄 PARTIALLY STARTED

| Capability | Status | Notes |
|-----------|--------|-------|
| Related record writes | ✅ Done | `create_record` supports `related_records` |
| Bulk SQL generation | ✅ Done | `action-bulk-sql.md` steering file |
| Exemplar discovery | ✅ Done | M2 in workflow queries all relationships |
| Record type coverage checklist | ✅ Done | M3 verification step |
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
2. **Atlas MCP:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-mcp-server` — `python3 -m pytest tests/`
3. **DG MCP:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp` — `python3 -m pytest tests/`
4. **Power:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-power`
5. **KB:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-atlas-kb`

### Testing
- E2E test: `python3 /Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/test_mcp_e2e.py`
- Related records test: `python3 /Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/test_related_records.py`
- Field check: `python3 /Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/check_fields.py`

### Environment
- **Appian:** `https://merge-assist.appianpreview.com`
- **APIs:** `/suite/webapi/record/{method}`, `/suite/webapi/users/list`
- **Docker image:** `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`

### Key UUIDs (Source Selection)
| Table | Record Type UUID |
|-------|-----------------|
| AS_GSS_EVALUATION | `e6bc8561-d3a6-4679-b7af-6e279910468e` |
| AS_GSS_EVALUATION_VENDOR | `b6081510-0d11-4d51-8eba-966610b168db` |
| AS_GSS_CRITERIA | `11dcc745-3c81-49f9-9cb2-6427680e4b41` |
| AS_GSS_EVALUATOR_TEAM | `791d954b-beae-4171-808f-876583d707fa` |
| AS_GSS_EVALUATION_PHASE | `bf3ef3fe-9671-40df-a195-bd71ab8deed8` |
| AS_GSS_R_DATA | `c34b12a0-4ae7-4d21-adb9-09320118b98e` |
| AS_GSS_CONSENSUS_REPORT | `53315796-2d3b-4edd-bd96-55f169c999dc` |
| AS_GSS_TMG_TASK | `9a04b944-b726-41f5-9b37-8ec71b6cc370` |

### Reference: Similar Project
- **ASPECT** (`amrut.rao/ASPECT`) — SQL-only test data generator power for Appian. Schema-driven, no MCP server. Has solution profiles (CCM). Good patterns for SQL formatting, known issues tables, as-built column verification.
