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

## Phase 2: Appian Environment APIs 🔄 IN PROGRESS (Owner: Ramaswamy)

### What needs to be built (in Appian)
| API | Status | Notes |
|-----|--------|-------|
| `POST /api/record/properties` | 🔄 Pending | Returns field UUIDs, types, relationships |
| `POST /api/record/create` | 🔄 Pending | Creates a record, returns generated ID |
| `POST /api/record/update` | 🔄 Pending | Partial update by record ID |
| `POST /api/record/query` | 🔄 Pending | Query with filters |
| `POST /api/record/delete` | 🔄 Pending | Delete by ID |
| `GET /api/users/list` | 🔄 Pending | Available usernames |

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

## Phase 3: Data Generator MCP Server ⏳ NOT STARTED

### What needs to be built
- New Python MCP server (`solutions-data-generator-mcp`)
- Docker-containerized, communicates via stdio
- Talks to Appian APIs from Phase 2

### Components planned
| Component | Purpose |
|-----------|---------|
| `config.py` | Environment URL, API key from env vars |
| `client.py` | HTTP client for Appian APIs |
| `field_registry.py` | Caches record type properties (field UUIDs + types) |
| `payload_builder.py` | Converts simple JSON → Appian format |
| `session_manager.py` | Tracks created records for rollback |
| `tools/record.py` | create_record, update_record, delete_record, query_records |
| `tools/properties.py` | get_record_properties |
| `tools/users.py` | list_users |
| `tools/session.py` | get_session, rollback_session |

### Depends on
- Phase 2 APIs deployed and accessible

---

## Phase 4: Agent Integration & Steering ⏳ NOT STARTED

### What needs to be built
| Item | Owner | Status |
|------|-------|--------|
| Steering document for data generator power | TBD | ⏳ |
| Status recipes (JSON) for Source Selection | Ramaswamy | ⏳ |
| Record type mapping (table → record type ref) | Parser enhancement | ⏳ |
| Power configuration (mcp.json with both servers) | TBD | ⏳ |
| End-to-end testing | Both | ⏳ |

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
   - Test against package: `python3 -m appian_parser dump <package.zip> /tmp/output`

2. **MCP Server repo:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-mcp-server`
   - Schema tools: `atlas_mcp/tools/schema.py`
   - Run tests: `python3 -m pytest tests/ --tb=short`

3. **Packages for testing:** `/Users/ramaswamy.u/Documents/Backup/package-backup/packages/`

4. **Nothing has been pushed to git yet.**
