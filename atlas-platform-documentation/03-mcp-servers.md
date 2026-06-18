# 03 — MCP Servers

Atlas exposes its capabilities to AI agents through **three MCP servers**. The Atlas MCP is read-only (intelligence); the Data Generator MCP writes to live environments; the Locust MCP provides performance-testing API intelligence.

---

## 1. Atlas MCP Server (read-only) — `solutions-atlas-mcp-server`

The core serving layer. Reads the parsed KB and exposes it to Kiro / Amazon Q.

- **Image:** `registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest`
- **Package:** `atlas_mcp` (Python), stdio transport
- **Security:** token validated — refuses write/admin scopes
- **Caching:** LRU (500) + pinned anchor files

### Configuration
| Env Var | Purpose | Default |
|---------|---------|---------|
| `GITLAB_TOKEN` | GitLab PAT (read-only: `read_api`, `read_repository`) | required |
| `ATLAS_KB_PROJECT_ID` | KB repo project ID | `13490` |
| `ATLAS_DATA_PREFIX` | Directory prefix for app data | `ai-framework/tools/Atlas/solutions-kb/data` |
| `ATLAS_DATA_BRANCH` | Branch to read from | `main` |
| `ATLAS_PIPELINE_TRIGGER_TOKEN` | KB sync pipeline trigger (baked at build) | optional |

### Tool Catalog
| Category | Tools |
|----------|-------|
| **Discovery** | `list_applications`, `get_app_overview` |
| **Bundles** | `search_bundles`, `get_bundle` (detail: summary / structure / full+code) |
| **Objects** | `search_objects`, `get_dependencies`, `get_object_detail`, `get_object_code` |
| **Graph** | `get_dependency_path`, `get_transitive_dependencies`, `get_hub_objects` |
| **Versions** | `list_releases`, `get_changelog`, `compare_releases`, `get_object_history`, `get_object_at_release`, `get_release_impact` |
| **Orphans** | `list_orphans`, `get_orphan` |
| **Pipeline** | `refresh_knowledge_base` |
| **Schema (for QE/data)** | `get_record_type_map`, `get_field_map`, `get_reference_data`, `get_app_schema`, `get_schema_relationships`, `get_insertion_order`, `get_schema_summary` |

### Schema Tools — Detail
- `get_record_type_map(app_name)` — **call first**; table → record type UUID + relationship names (one call)
- `get_field_map(app_name)` — UPPER_SNAKE column → camelCase field name
- `get_reference_data(app_name)` — ref table metadata + UUIDs (query live for actual values)
- `get_app_schema` / `get_schema_relationships` / `get_insertion_order` / `get_schema_summary`

---

## 2. Data Generator MCP Server (write) — `solutions-atlas-dg-mcp-server`

Performs record CRUD against a live Appian environment. Used by the QE / data-generation tooling.

- **Image:** `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`
- **Backed by:** an `Atlas Data Generator` Appian application exposing Web APIs

### Configuration
| Env Var | Purpose |
|---------|---------|
| `APPIAN_ENV_URL` | Target environment, e.g. `https://<env>.appianpreview.com` |
| `APPIAN_API_KEY` | API key for the environment |

### Tool Catalog
| Tool | Purpose |
|------|---------|
| `create_record(uuid, fields, related_records?)` | Create with optional nested children (atomic parent+child) |
| `update_record(uuid, record_id, fields)` | Partial update (PK included automatically) |
| `delete_record(uuid, record_id)` | Soft delete (isActive=false) |
| `query_records(uuid, filters?, paging_info?)` | Query (never pass selected_fields; paging is 1-based) |
| `get_record_properties(uuid)` | Live field metadata from the environment |
| `list_users()` | Available usernames |
| `get_session()` | View all records created this session |
| `rollback_session(confirm)` | Reverse-order soft delete of all session records |

### Backing Web APIs
`/suite/webapi/record/properties` · `/record/create` (supports `relatedRecords`) · `/record/update` · `/record/delete` · `/record/query` · `/users/list`

---

## 3. Locust MCP Server (read-only) — `solutions-atlas-locust-mcp-server`

Provides `appian-locust` API intelligence for performance-test generation. Loads method signatures dynamically from the live appian-locust GitLab repo.

### Tool Catalog (6)
| Tool | Purpose |
|------|---------|
| `get_interaction_methods` | Available appian-locust interaction methods |
| `get_method_signature` | Parameter details for a method |
| `get_component_mapping` | Map a SAIL component → the correct locust method |
| `get_navigation_patterns` | Navigation/auth patterns |
| `get_test_template` | Script templates (sequential / multi_role / record_workflow) |
| `validate_script` | Validate a generated locust script |

---

## How Tools Combine

| Tool / Power | Atlas MCP | DG MCP | Locust MCP |
|--------------|:---------:|:------:|:----------:|
| Knowledge search / version history | ✅ | | |
| ERD generation | ✅ (schema) | | |
| SQL Forge (test data / bulk SQL) | ✅ (schema) | ✅ | |
| Locust Forge (perf scripts) | ✅ | ✅ (setup) | ✅ |
| Role powers (Dev / PO / UX) | ✅ | | |
