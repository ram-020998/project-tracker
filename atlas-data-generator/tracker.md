# Atlas Data Generator — Progress Tracker

**Last Updated:** 2026-05-13

---

## Project Overview

AI-driven test data generation for Appian applications. Uses Atlas KB (application structure + workflow logic) combined with a new Data Generator MCP server to create realistic, workflow-aware test data via CRUD APIs.

**Repos involved:**
- `solutions-atlas-parser` — parses Appian packages, now includes schema extraction
- `solutions-atlas-mcp-server` — read-only MCP for application intelligence, now includes schema tools
- `solutions-data-generator-mcp` — NEW (not yet created) — write-capable MCP for data operations
- `solutions-os` — KB storage, CI sync pipeline

---

## Phase 1: Schema Layer ✅ COMPLETE

### What was done
- Built DDL replay engine that parses incremental MySQL DDL scripts from Appian packages
- Integrated into `solutions-atlas-parser` pipeline — runs automatically on every parse
- Outputs to `data/<AppName>/current/schema/` (6 JSON files)
- Added 5 schema query tools to `solutions-atlas-mcp-server`

### Files created/modified

**solutions-atlas-parser:**
| File | Status |
|------|--------|
| `appian_parser/schema/__init__.py` | ✅ Created |
| `appian_parser/schema/models.py` | ✅ Created |
| `appian_parser/schema/script_finder.py` | ✅ Created |
| `appian_parser/schema/statement_parser.py` | ✅ Created |
| `appian_parser/schema/ddl_replay_engine.py` | ✅ Created |
| `appian_parser/schema/schema_builder.py` | ✅ Created |
| `appian_parser/cli.py` | ✅ Modified (added schema extraction) |
| `tests/schema/__init__.py` | ✅ Created |
| `tests/schema/test_schema.py` | ✅ Created (38 tests) |

**solutions-atlas-mcp-server:**
| File | Status |
|------|--------|
| `atlas_mcp/tools/schema.py` | ✅ Created (5 tool handlers) |
| `atlas_mcp/tools/__init__.py` | ✅ Modified (added SchemaTools) |
| `atlas_mcp/server.py` | ✅ Modified (registered 5 tools) |
| `atlas_mcp/models.py` | ✅ Modified (added tool schemas) |
| `tests/test_server.py` | ✅ Modified (updated counts 25→30) |

### Test results
- Parser: 302 tests passing, 0 regressions
- MCP Server: 77 tests passing, 0 regressions
- Validated against all 14 packages with scripts (2.44s total)

### NOT pushed to git yet (per instruction)

---

## Phase 2: Appian Environment APIs ✅ COMPLETE (Owner: Ramaswamy)

### APIs Built
| API | Status | Notes |
|-----|--------|-------|
| `POST /record/properties` | ✅ Done | Returns field names, types, references, isPrimaryKey, isCustomRecordField |
| `POST /record/create` | ✅ Done | Creates record (no PK in payload), returns recordsUpdated |
| `POST /record/update` | ✅ Done | Include PK in fields → updates existing record |
| `POST /record/delete` | ✅ Done | Include PK + isActive:false → soft delete |
| `POST /record/query` | ✅ Done | Filters, selectedFields, pagingInfo with sort |
| `POST /users/list` | ✅ Done | Returns flat username strings |

### Environment
- URL: `https://merge-assist.appianpreview.com`
- Web APIs: `ADG_API_recordOperations` (alias: `record`), `ADG_API_users` (alias: `users/list`)
- Helper rules: `ADG_UT_getRecordTypeProperties`, `ADG_UT_createOrUpdateRecords`, `ADG_UT_queryRecordTypeWithFilters`, `ADG_UT_convertFieldValue`, `ADG_UT_returnFieldReferenceFromFieldName`, `ADG_UT_returnRecordReferenceFromUuid`, `ADG_UT_initialiseEmptyRecordForGivenUuid`, `ADG_UT_queryUsersFromEnvironment`

---

## Phase 3: Data Generator MCP Server ✅ COMPLETE

### Repo
- Location: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp`
- GitLab: `ramaswamy.u/solutions-atlas-dg-mcp-server`
- Docker image: `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`
- Pipeline: Lint + Test + Build (kaniko) — all passing

### Tools (8)
| Tool | Status | Notes |
|------|--------|-------|
| `get_record_properties` | ✅ | Handles columnar response format from Appian |
| `create_record` | ✅ | Filters writable fields, tracks session |
| `update_record` | ✅ | Auto-includes PK field |
| `delete_record` | ✅ | Soft delete (isActive=false) |
| `query_records` | ✅ | Filters, selectedFields, pagingInfo (startIndex=1) |
| `list_users` | ✅ | Returns flat username strings |
| `get_session` | ✅ | Shared singleton across tools |
| `rollback_session` | ✅ | Reverse-order soft delete |

### Key Implementation Details
- Appian returns properties in **columnar format**: `fields: [{"name": [...], "type": [...]}]`
- `field_registry.py` handles both columnar and row formats
- All tools share a single `SessionManager` instance via `_shared.py`
- `startIndex` in Appian paging is **1-based** (not 0)
- Pipeline uses `gcr.io/kaniko-project/executor:v1.23.2-debug` for Docker builds (no appian/prod access needed)

---

## Phase 4: Agent Integration & Steering ✅ COMPLETE

### Power Created
- Location: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-power`
- Both MCP servers configured (Atlas + Data Generator)
- 6 steering files covering all actions

### Structure
```
atlas-data-generator-power/
├── POWER.md                              # Main instructions + action router
├── mcp.json                              # Both MCP servers
├── .kiro/steering.md                     # Power metadata
├── README.md
└── steering/
    ├── action-generate-data.md           # 4-phase workflow
    ├── action-explore-schema.md          # Schema exploration
    ├── action-query-and-validate.md      # Query and verify
    ├── action-rollback.md                # Session cleanup
    ├── tool-reference-atlas.md           # 5 Atlas schema tools
    └── tool-reference-data-generator.md  # 8 DG tools
```

### Key design decisions (already agreed)
- API accepts simple field name → value JSON (camelCase field names)
- Appian-side handles UUID reference construction and type formatting (fn!date, fn!touser, etc.)
- PK is auto-generated, not supplied by caller
- Only non-null fields need to be sent
- Environment URL + API key passed as MCP server config params
- Start with Source Selection application, Evaluation record type

### Reference: Record type properties format
The properties API returns field UUIDs in the `reference` field:
```
recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD.fields.{7f7c2d3b-1410-4650-a5c8-afd218753011}evaluationId
```

### Reference: CRUD payload format
```
'recordType!{uuid}Name'(
  'recordType!{uuid}Name.fields.{field-uuid}fieldName': value,
  ...
)
```

---

## Phase 3: Data Generator MCP Server ⏳ SEE ABOVE (COMPLETE)

---

## Phase 4: Agent Integration & Steering ⏳ SEE ABOVE (COMPLETE)

---

## Phase 5: Advanced Capabilities ⏳ NOT STARTED

Deferred until Phases 1-4 are complete. Priority order:
1. Record footprint query
2. Bulk creation
3. Workflow-driven generation (status recipes)
4. Validation tools
5. Exemplar cloning
6. Environment management
7. Version-aware generation
8. Multi-entity scenarios

---

## Key Architecture Decisions (Agreed)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Separate MCP servers | Atlas (read) + Data Generator (write) | Different security posture, credentials, lifecycles |
| Schema source | DDL script from scripts/ folder | Authoritative source, includes all tables + ref data |
| DDL parsing approach | Custom regex replay engine | 16x faster than simple-ddl-parser, more complete output |
| Reference data detection | Any table with INSERT = reference | Works across all naming conventions (CMGT_CFG_, AIA_, _R_) |
| Statement splitting | Line-based (split on line-ending `;`) | Avoids escaped quote bugs in character-by-character splitting |
| Target application | Source Selection first | Most mature in Atlas KB |
| Cross-app tables | Reference only, don't insert | AS_GAM_* tables exist for FK understanding |
| Environment safety | Config params on MCP server | URL + API key determine target environment |
| Bulk operations | Deferred to Phase 5 | MVP uses single-record CRUD |
| Status recipes | Manually created by Ramaswamy | Stored as structured JSON in KB |

---

## Documentation Location

```
/Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/
├── architecture.md                          ← Full architecture document
├── implementation/
│   ├── phase-1-schema-layer.md              ← ✅ Complete with results
│   ├── phase-2-appian-environment-apis.md   ← API specs and design
│   ├── phase-3-data-generator-mcp.md        ← Server architecture
│   ├── phase-4-agent-integration.md         ← Steering + recipes
│   └── phase-5-advanced-capabilities.md     ← Future capabilities
├── ddl_replay.py                            ← Original prototype (superseded)
├── schema_output/                           ← Prototype output (superseded)
├── 01.SourceSelectionv2.9.0.sql             ← Test script file
└── schema-alt/                              ← simple-ddl-parser comparison (rejected)
```

---

## Quick Start for New Session

1. **Parser repo:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-parser`
   - Schema module: `appian_parser/schema/`
   - Run tests: `python3 -m pytest tests/ --tb=short`

2. **Atlas MCP Server repo:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-mcp-server`
   - Schema tools: `atlas_mcp/tools/schema.py`
   - Run tests: `python3 -m pytest tests/ --tb=short`

3. **Data Generator MCP Server:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp`
   - Run tests: `python3 -m pytest tests/ --tb=short`
   - E2E test: `python3 /Users/ramaswamy.u/repo/project-tracker/atlas-data-generator/test_mcp_e2e.py`
   - Docker image: `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`

4. **Power:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-data-generator-power`

5. **KB repo:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-atlas-kb`
   - Schema data at: `data/SourceSelection/current/schema/`

6. **Appian environment:** `https://merge-assist.appianpreview.com`
   - APIs: `/suite/webapi/record/{method}`, `/suite/webapi/users/list`

7. **Packages for testing:** `/Users/ramaswamy.u/Documents/Backup/package-backup/packages/`

8. **Nothing has been pushed to the appian/prod repos (parser + atlas mcp changes are merged).**
