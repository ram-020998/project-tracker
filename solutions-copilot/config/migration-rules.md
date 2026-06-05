# Migration Rules — Tool Name Mapping

This document defines how tool references in the original steering files are mapped to the new architecture.

## MCP Server Mapping

| Original Server | New Server | Notes |
|----------------|-----------|-------|
| jarvis (Soma's Docker image) | solutions-intelligence + lcp-api | Split: reads → intelligence, writes → lcp-api |
| appian-atlas (Atlas MCP) | solutions-intelligence | Same tools, different server name |
| appian-data-generator | data-generator | Same tools, different server name |
| mcp_jira | jira | Same tools |
| mcp_google_workspace | (removed for now) | Not part of POC |
| playwright | playwright | Same |

## Tool Name Mapping — Jarvis KB → solutions-intelligence

| Original Tool | New Tool | Notes |
|--------------|----------|-------|
| `jarvis_get_app_tree` | `solutions-intelligence.get_app_overview` | Similar output |
| `jarvis_search_objects` | `solutions-intelligence.search_objects` | |
| `jarvis_get_cluster` | `solutions-intelligence.get_bundle` | Clusters ≈ bundles |
| `jarvis_get_object_content` | `solutions-intelligence.get_object_code` | |
| `jarvis_get_context` | `solutions-intelligence.get_object_detail` + `get_dependencies` | Split into 2 calls |
| `jarvis_get_dependency_chain` | `solutions-intelligence.get_dependencies` | |
| `jarvis_get_impact_analysis` | `solutions-intelligence.get_transitive_dependencies` | |
| `jarvis_get_data_model` | `solutions-intelligence.get_app_schema` | |
| `jarvis_get_patterns` | `solutions-intelligence.search_bundles` | Patterns → bundles |
| `jarvis_get_architecture` | `solutions-intelligence.get_app_overview` | Included in overview |
| `jarvis_get_dead_code` | `solutions-intelligence.list_orphans` | |
| `jarvis_get_shared_objects` | `solutions-intelligence.get_hub_objects` | |
| `jarvis_get_dependents_batch` | `solutions-intelligence.get_dependencies` (per object) | No batch, iterate |
| `jarvis_get_precedents_batch` | `solutions-intelligence.get_dependencies` (per object) | No batch, iterate |
| `jarvis_get_objects_by_type` | `solutions-intelligence.search_objects` with type filter | |
| `jarvis_get_entry_points_for_object` | `solutions-intelligence.get_dependencies` | Use called_by=[] |

## Tool Name Mapping — Jarvis Live API → lcp-api

| Original Tool | New Tool | Notes |
|--------------|----------|-------|
| `get_appian_object` | `lcp-api.getInterface` / `lcp-api.getExpressionRule` | By object type |
| `search_objects_by_name` | `lcp-api.searchObjects` | |
| `search_objects_semantic` | `lcp-api.searchObjects` | No semantic mode yet |
| `list_application_objects` | `lcp-api.listInterfaces` / `lcp-api.listRecordTypes` etc | By type |
| `evaluate_sail_expression` | `lcp-api.evaluateExpression` | |
| `query_sql` | (not available in POC) | Removed from scope |
| `create_package_for_ticket` | (not available in POC) | Use Deployment MCP later |
| `get_object_dependencies` | `solutions-intelligence.get_dependencies` | Reads go to intelligence |
| `get_object_diff` | `solutions-intelligence.get_object_history` | Version comparison |
| `get_jarvis_config` | (removed) | No longer needed — env from environments.json |
| `get_application_info` | `lcp-api.getApplication` | App details |
| `create_constant` | `lcp-api.createConstant` | |
| `preview_constant` | (removed) | |

## Tool Name Mapping — Atlas MCP → solutions-intelligence

| Original Tool | New Tool | Notes |
|--------------|----------|-------|
| `list_applications` | `solutions-intelligence.list_applications` | Same |
| `get_app_overview` | `solutions-intelligence.get_app_overview` | Same |
| `search_objects` | `solutions-intelligence.search_objects` | Same |
| `get_object_code` | `solutions-intelligence.get_object_code` | Same |
| `get_dependencies` | `solutions-intelligence.get_dependencies` | Same |
| `get_bundle` | `solutions-intelligence.get_bundle` | Same |
| `search_bundles` | `solutions-intelligence.search_bundles` | Same |
| `list_orphans` | `solutions-intelligence.list_orphans` | Same |
| `get_hub_objects` | `solutions-intelligence.get_hub_objects` | Same |
| `get_dependency_path` | `solutions-intelligence.get_dependency_path` | Same |
| `get_transitive_dependencies` | `solutions-intelligence.get_transitive_dependencies` | Same |
| `list_releases` | `solutions-intelligence.list_releases` | Same |
| `compare_releases` | `solutions-intelligence.compare_releases` | Same |
| `get_changelog` | `solutions-intelligence.get_changelog` | Same |
| `get_object_history` | `solutions-intelligence.get_object_history` | Same |
| `get_object_at_release` | `solutions-intelligence.get_object_at_release` | Same |
| `get_release_impact` | `solutions-intelligence.get_release_impact` | Same |
| `get_app_schema` | `solutions-intelligence.get_app_schema` | Same |
| `get_schema_relationships` | `solutions-intelligence.get_schema_relationships` | Same |
| `get_insertion_order` | `solutions-intelligence.get_insertion_order` | Same |
| `refresh_knowledge_base` | `solutions-intelligence.refresh_knowledge_base` | Same |

## Concepts Mapping

| Original Concept | New Concept | Notes |
|-----------------|-------------|-------|
| "Jarvis KB" | "Solutions Intelligence Cloud Plane" | Pre-computed app knowledge |
| "Jarvis Live API" | "lcp-api" (for writes) + "solutions-intelligence" (for reads) | Split |
| "Atlas KB" / "Atlas MCP" | "solutions-intelligence" | Same backend, renamed |
| "KB parentFolderId" | Not needed | Intelligence server resolves by app name |
| "kbFolderId" | Not needed | Intelligence server has app registry |
| "get_jarvis_config" | `environments.json` + `solutions-intelligence.list_applications` | Split config vs discovery |
| "appUuid" | Still used for lcp-api calls | LCP API uses UUIDs |
| "staleCount" | (handled by intelligence server internally) | |
| "JARVIS menu" | Orchestrator routing (removed) | Orchestrator handles routing |

## Removal List

These elements should be REMOVED from steering files:
- References to "JARVIS" or "Jarvis" (use generic language)
- References to "Atlas" (use "solutions-intelligence" or "intelligence")
- `get_jarvis_config` calls (replaced by `environments.json` reference)
- `parentFolderId` / `kbFolderId` parameters (not needed)
- Google Drive/Docs integration (not in POC scope)
- SQL queries via `query_sql` (not in POC scope)
- Package creation (not in POC scope)
- "staleCount" freshness checks (intelligence server handles internally)
- References to "JAI app" or "Jarvis Application Intelligence"

## Preservation List

These elements should be PRESERVED in full:
- Workflow steps and their ordering
- Execution trackers and blocking rules
- Validation checkpoints
- Action Router tables (update tool names)
- HTML template structures
- Best practices checklists
- Quality rules and constraints
- Budget recommendations (call counts)
- Response format guidelines
