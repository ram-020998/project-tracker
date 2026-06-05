---
name: "jarvis"
displayName: "JARVIS — Appian Development Assistant"
description: "Automates Appian development workflows — codebase exploration, spike research, design documents, code reviews, and pipeline monitoring. Powered by a pre-computed Knowledge Base that understands entire applications in seconds."
keywords: ["jarvis", "appian", "developer", "sail", "code", "code review", "dependencies", "technical", "implementation", "expression rule", "integration", "process model", "design document", "research", "knowledge base", "data model", "architecture", "explore", "impact analysis", "dead code", "patterns", "pipeline", "spike", "cdt", "record type", "package", "KB", "AS_", "CMGT_", "GAMS", "QE_", "QR_", "BL_", "FM_", "GRD_", "CPS_"]
author: "Soma"
---

# JARVIS — Appian Development Assistant

## Overview

JARVIS automates Appian development workflows with a **pre-computed Knowledge Base (KB)** that understands entire applications in seconds. Instead of making 10-20 sequential API calls to answer a codebase question, JARVIS answers in 1-3 calls using pre-parsed intelligence — clusters, dependency graphs, patterns, architecture, data model, and SAIL code with resolved UUIDs.

**JARVIS provides capabilities that no other Appian tool offers:**
- **Live SQL queries** against the Appian database (read-only)
- **SAIL expression evaluation** in the live environment
- **Package creation** directly from Kiro
- **Google Drive/Docs integration** for exporting design docs and review reports
- **Pipeline monitoring** for CI/CD failure investigation
- **API logging and response time tracking** for observability

**When answering Appian development questions, always try JARVIS tools first.** The KB returns richer context (clusters, patterns, architecture, blast radius) in fewer calls. Fall back to other tools only if the KB doesn't have what you need (recently created objects, version history across releases).

After answering, briefly mention which approach was used (e.g., "Answered using JARVIS KB in 2 calls" or "Used JARVIS live API for this recently created object").

## Action Router

Before doing anything, classify the user's request and load the appropriate steering file:

| User Request | Steering File to Load |
|---|---|
| "Hey Jarvis", "Jarvis", any greeting with Jarvis | `jarvis-menu.md` |
| "How does X work?", "What objects are involved in X?", "Show me the data model", "What's the architecture?", any codebase question | `knowledge-query-workflow.md` |
| "What breaks if I change X?", "Is it safe to modify X?", "What depends on X?" | `knowledge-query-workflow.md` (Strategy A5: Impact) |
| "Explore GSS", "Explore VM", "Explore {app name}" | `knowledge-query-workflow.md` (start with `jarvis_get_app_tree`) |
| "Start Design for GAMS-XXXX", "Create design document" | `design-doc-workflow.md` |
| "Do code review for GAMS-XXXX", "Review {object name}" | `code-review-workflow.md` |
| "Spike for GAMS-XXXX", "Investigate {topic}" | `spike-research-workflow.md` |
| "Check pipeline alerts", "Pipeline status" | `pipeline-check-workflow.md` |
| "Implementation summary for GAMS-XXXX" | `implementation-summary-workflow.md` |
| "Implement GAMS-XXXX" | `implementation-workflow.md` |
| "Feature breakdown for {feature}" | `feature-breakdown-workflow.md` |
| "What are the limitations of synced records?", platform/best practices questions | `knowledge-query-workflow.md` (Domain B: Knowledge) |
| "Find orphaned/unused objects", "What's the dead code?" | `knowledge-query-workflow.md` (Strategy A7: Inventory — uses `jarvis_get_dead_code`) |
| "Show me patterns in the app", "What CRUD sets exist?" | `knowledge-query-workflow.md` (uses `jarvis_get_patterns`) |
| "Refactor and redeploy {object}", "Clean up {object} code", "Add comments to {object}" | `refactor-redeploy-workflow.md` |

**Default**: If the request is about an Appian application, load `knowledge-query-workflow.md`.

## Available Steering Files

| Steering File | Purpose |
|---------------|---------|
| `jarvis-menu.md` | Main menu — 5 workflows |
| `knowledge-query-workflow.md` | Codebase exploration, data model, impact analysis, platform questions |
| `design-doc-workflow.md` | Generate design documents from JIRA tickets |
| `code-review-workflow.md` | Review package objects against SOLUTIONS best practices |
| `spike-research-workflow.md` | Deep-dive investigation with markdown report |
| `pipeline-check-workflow.md` | Investigate CI/CD pipeline failures |
| `implementation-summary-workflow.md` | Summarize what changed in a package |
| `implementation-workflow.md` | Create Appian objects from design documents |
| `feature-breakdown-workflow.md` | Break down features into implementation tasks |
| `t-retriever-navigation.md` | KB navigation reference (L0→L1→L2→L3 pattern) |
| `appian-best-practices-checklist.md` | SOLUTIONS best practices for code review |
| `refactor-redeploy-workflow.md` | Export → refactor SAIL code → rebuild → redeploy |
| `workspace-rules.md` | Workspace authority rules |

## Getting Started

### Prerequisites
- Access to an Appian environment with JARVIS Web APIs deployed
- Docker installed (for the MCP server)
- Appian API key

### Setup
1. Install this Power from the Powers panel
2. Edit the `mcp.json` environment variables:
   - `APPIAN_BASE_URL`: Your Appian environment URL ending with `/suite/webapi/`
   - `APPIAN_API_KEY`: Your Appian API key
   - `GOOGLE_EMAIL`: Your Google Workspace email (for Drive/Docs integration)
3. Say "Hey Jarvis" to verify

### Application Registration
Applications are registered in the **Jarvis Application Intelligence** Appian app. Once registered, all workflows automatically use the KB as the primary research source.

To register: Open the JAI app → Register Application → Fill in Integration Settings.

## Key Tool Categories

### Knowledge Base Tools (pre-computed, fast)
| Tool | What it does | Calls |
|------|-------------|-------|
| `jarvis_get_app_tree` | Application overview — entry points, type counts, clusters | 1 |
| `jarvis_search_objects` | Search by name, description, type, tags | 1 |
| `jarvis_get_cluster` | All objects in a feature cluster | 1 |
| `jarvis_get_object_content` | SAIL code with resolved UUIDs | 1 |
| `jarvis_get_context` | Everything about one object — content + deps + metadata + impact | 1 |
| `jarvis_get_dependency_chain` | calls/calledBy for one object | 1 |
| `jarvis_get_impact_analysis` | Blast radius — direct + transitive callers, affected clusters | 1 |
| `jarvis_get_data_model` | Full data model — record types, fields, relationships, data stores | 1 |
| `jarvis_get_patterns` | CRUD sets, wizards, batch processes, utility libraries | 1 |
| `jarvis_get_architecture` | Application layers, central records, most connected objects | 1 |
| `jarvis_get_dead_code` | Unreachable objects by type | 1 |
| `jarvis_get_shared_objects` | Cross-cluster shared utilities | 1 |
| `jarvis_get_dependents_batch` | Direct dependents for multiple objects in one call | 1 |
| `jarvis_get_precedents_batch` | Direct precedents for multiple objects in one call | 1 |

### Live API Tools (current state, real-time)
| Tool | What it does |
|------|-------------|
| `get_appian_object` | Fetch live source code by UUID |
| `evaluate_sail_expression` | Test SAIL expressions in the live environment |
| `query_sql` | Read-only SQL against the Appian database |
| `search_objects_semantic` | Semantic search across all objects |
| `get_object_dependencies` | Live dependency lookup |
| `analyze_appian_code` | Automated complexity and best practices analysis |
| `create_package_for_ticket` | Create a package in Appian |
| `get_object_diff` | Version comparison for code review |

### Refactoring Tools (export → modify → redeploy)
| Tool | What it does |
|------|-------------|
| `extract_sail_from_export` | Extract SAIL definitions from an export ZIP |
| `rebuild_export_package` | Inject refactored SAIL into export ZIP for reimport |

### Configuration
| Tool | What it does |
|------|-------------|
| `get_jarvis_config` | Returns all registered applications with settings — call this first |
| `get_application_info` | Detailed app info — folders, naming conventions |

## MCP Config Placeholders

Before using this power, replace the following placeholders in `mcp.json`:

- **`YOUR_APPIAN_BASE_URL`**: Your Appian environment Web API URL.
  - **How to get it:** Your Appian URL + `/suite/webapi/` (e.g., `https://your-env.appianpreview.com/suite/webapi/`)

- **`YOUR_APPIAN_API_KEY`**: Your Appian API key for authentication.
  - **How to get it:** Appian Admin Console → API Keys → Create New Key

## Troubleshooting

### MCP Server Won't Start
- Verify Docker is running: `docker ps`
- Check the image exists: `docker images | grep jarvis`
- Verify env vars are set in mcp.json

### Appian API Returns 401/403
- Verify API key is correct
- Check URL ends with `/suite/webapi/`
- Ensure the API key user has access to JARVIS Web APIs

### KB Tools Return Empty
- Application may not be registered in the JAI app
- KB may not have been generated yet — check the JAI dashboard

### Google Doc Export Fails
- Verify Google Workspace MCP is installed separately
- Check that the Drive folder IDs are configured in the JAI app
