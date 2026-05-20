# Solutions OS Revamp Plan

**Version:** 1.0 Draft
**Date:** May 20, 2026
**Author:** Ram
**Status:** Proposal for Approval

---

## 1. Executive Summary

Solutions OS is being elevated from a knowledge repository to a **production-grade AI development platform** for Appian Solutions teams. This document proposes three interconnected changes:

1. **Merge Atlas and Jarvis into a single unified Appian Intelligence service** — eliminating tool fragmentation and providing one MCP interface for all application intelligence needs
2. **Introduce a single Orchestrator Agent** — so that any user who clones the repo has immediate access to all capabilities without manual power installation or MCP configuration
3. **Restructure the repository** — to support the orchestrator pattern, simplify onboarding, and enforce consistency

### Why Now

- Solutions OS is moving to production use across all Solutions teams
- Two tools (Atlas and Jarvis) solve overlapping problems with different storage strategies, causing confusion and duplicated effort
- Powers built on one tool don't benefit from the other, splitting the ecosystem
- Users must manually install powers, configure MCP servers, and understand the repo structure before they can do anything

### Expected Outcomes

| Metric | Current | After Revamp |
|--------|---------|--------------|
| Time to first useful interaction | 30-60 min (install power, configure MCP, learn commands) | < 5 min (clone, set env vars, start) |
| Number of MCP configs to manage | 3+ per user (Atlas, Jarvis, Data Gen, Google, etc.) | 1 (unified service) |
| Powers that work with both backends | 0 (each power is built for one) | All (unified interface) |
| Agent/tool discovery | Manual (read READMEs, find folders) | Automatic (orchestrator routes) |
| Cross-release analysis + live data | Requires switching tools | Single query, auto-routed |

---

## 2. Problem Statement

### 2.1 Tool Fragmentation: Atlas vs Jarvis

Two developers independently built tools solving the same core problem: *"Give AI agents structured knowledge about Appian applications."*

| Dimension | Atlas | Jarvis |
|-----------|-------|--------|
| **Storage** | GitLab (JSON files in `solutions-atlas-kb`) | Live Appian environment (JAI app) |
| **KB Generation** | Atlas Parser → CI pipeline → GitLab | JAI Appian app → generates KB in-env |
| **Freshness** | Point-in-time snapshots; refreshed via pipeline | Always-latest (queries live data) |
| **Multi-release** | Yes — full version history, changelogs, release comparison | No — only current state |
| **Write operations** | None (read-only by design) | Yes — create objects, deploy packages, evaluate SAIL, run SQL |
| **Tool count** | 30 tools | 42 tools |
| **Shared across team** | Yes (centralized GitLab KB) | Per-environment (each env has its own KB) |
| **Offline analysis** | Yes | No (requires live connection) |

**The core conflict:** Both tools have KB exploration tools that overlap significantly:

| Capability | Atlas Tool | Jarvis Tool |
|-----------|-----------|-------------|
| App overview | `get_app_overview` | `jarvis_get_app_tree` |
| Search objects | `search_objects` | `jarvis_search_objects` |
| Get code | `get_object_code` | `jarvis_get_object_content` |
| Dependencies | `get_dependencies` | `jarvis_get_dependency_chain` |
| Orphan/dead code | `list_orphans` | `jarvis_get_dead_code` |
| Impact analysis | `get_transitive_dependencies` | `jarvis_get_impact_analysis` |

Powers are being duplicated — atlas-developer and Jarvis both offer code exploration, code review, and design document workflows. Teams must choose one, and their choice limits which capabilities they access.

### 2.2 Usability: No Single Entry Point

Current user journey:
1. Clone `solutions-os` → see a complex repo with folders everywhere
2. Figure out which power you need → navigate to `ai-framework/Engineering/.kiro/powers/` or `ai-framework/Product/.kiro/powers/`
3. Install the power manually in Kiro IDE
4. Configure MCP: edit `mcp.json`, set env vars, ensure Docker is running, authenticate with registry
5. Repeat for each additional power you want
6. Learn each power's activation triggers and workflows

**Result:** Most users install one power and never explore others. Capabilities remain siloed.

### 2.3 Naming and Structure Inconsistencies

- Products use different folder conventions (`features/` vs `Features/`, `steering/` vs `Steering/`)
- `@DOCS/schemas/` is empty — the "schema-driven" principle has no enforcement
- Most products lack steering files, leaving AI agents without product-specific guidance
- `ai-framework/tools/` duplicates documentation from source repos

---

## 3. Atlas + Jarvis Merge Strategy

### 3.1 Design Principle: Two Data Planes, One Service

Atlas and Jarvis are not competitors — they are **complementary data planes** serving different temporal needs:

- **Cloud Plane (Atlas)** — Versioned, shared, offline-capable, multi-release intelligence stored in GitLab
- **Live Plane (Jarvis)** — Real-time, per-environment, write-capable intelligence via Appian Web APIs

The merged service exposes a **single unified tool namespace**. Agents never need to know which plane answers their query — the service routes automatically based on operation type.

```
┌──────────────────────────────────────────────────────────────┐
│                    Unified MCP Server                          │
│              "appian-intelligence" (single Docker image)       │
├─────────────────────────────┬────────────────────────────────┤
│       Cloud Plane           │         Live Plane              │
│    (GitLab KB - Atlas)      │    (Appian APIs - Jarvis)       │
│                             │                                 │
│  • Multi-release history    │  • Real-time object state       │
│  • Cross-release diffs      │  • SAIL expression eval         │
│  • Shared team knowledge    │  • SQL queries                  │
│  • Offline graph analysis   │  • Package create/deploy        │
│  • Schema snapshots         │  • Object creation              │
│  • Bundle-based navigation  │  • Semantic search              │
│  • Pipeline refresh trigger │  • Live dependency lookup       │
└─────────────────────────────┴────────────────────────────────┘
```

### 3.2 Routing Logic

The unified server routes based on the nature of each request:

| Query Type | Routes To | Reason |
|-----------|-----------|--------|
| "What changed between release 2.7 and 2.8?" | Cloud | Only Atlas has version history |
| "Show me current SAIL code for X" | Live (fallback: Cloud) | Jarvis has real-time; Atlas has last-parsed |
| "Deploy this package" | Live | Only Jarvis can write |
| "Evaluate this SAIL expression" | Live | Requires live environment |
| "Run SQL query" | Live | Requires live database |
| "Show dependency graph for X" | Cloud (fallback: Live) | Atlas has pre-computed graph; Jarvis has live lookup |
| "What are the orphaned objects?" | Cloud | Pre-computed by parser |
| "Find objects named 'vendor'" | Both (merge results) | Cloud has full index; Live has latest |
| "What's the schema for this app?" | Cloud | Parser-generated, stable |
| "Create a constant" | Live | Write operation |
| "Show me app architecture/patterns" | Cloud preferred | Pre-computed intelligence |

**Fallback behavior:**
- If Live Plane is not configured (no `APPIAN_ENV_URL`), all queries go to Cloud
- If Cloud Plane has no data for an app, route to Live
- For queries both can answer, prefer the more complete source (usually Cloud for analysis, Live for current state)

### 3.3 Unified Tool Namespace

The merged server consolidates overlapping tools and preserves unique capabilities:

#### Consolidated Tools (overlap eliminated)

| Unified Tool | Replaces (Atlas) | Replaces (Jarvis) | Routing |
|-------------|------------------|-------------------|---------|
| `get_app_overview` | `get_app_overview` | `jarvis_get_app_tree` | Cloud preferred |
| `search_objects` | `search_objects` | `jarvis_search_objects` | Both, merge results |
| `get_object_code` | `get_object_code` | `jarvis_get_object_content` | Live preferred (latest) |
| `get_object_context` | `get_object_detail` | `jarvis_get_context` | Cloud (richer context) |
| `get_dependencies` | `get_dependencies` | `jarvis_get_dependency_chain` | Cloud (pre-computed graph) |
| `get_impact_analysis` | `get_transitive_dependencies` | `jarvis_get_impact_analysis` | Cloud (blast radius) |
| `list_dead_code` | `list_orphans` | `jarvis_get_dead_code` | Cloud |
| `get_data_model` | (schema tools) | `jarvis_get_data_model` | Cloud |

#### Cloud-Only Tools (Atlas unique capabilities)

| Tool | Purpose |
|------|---------|
| `list_releases` | List all parsed releases |
| `compare_releases` | Diff between two releases |
| `get_changelog` | What changed in a release |
| `get_object_history` | Object changes across releases |
| `get_object_at_release` | Object state at a specific version |
| `get_release_impact` | What a release affects |
| `search_bundles` | Bundle-based navigation |
| `get_bundle` | Bundle content with SAIL code |
| `get_hub_objects` | Most-connected objects in graph |
| `get_dependency_path` | Shortest path between two objects |
| `refresh_knowledge_base` | Trigger CI pipeline to re-parse |

#### Live-Only Tools (Jarvis unique capabilities)

| Tool | Purpose |
|------|---------|
| `evaluate_sail_expression` | Test SAIL in live environment |
| `query_sql` | Read-only SQL against live database |
| `create_package_for_ticket` | Create package from JIRA ticket |
| `inspect_package` | Validate package before deploy |
| `deploy_package` | Deploy to environment |
| `get_deployment_results` | Check deployment status |
| `create_constant` | Create new constant object |
| `get_object_diff` | Compare object versions (live) |
| `search_objects_semantic` | Semantic search (live index) |

#### Data Generator Tools (separate plane, integrated)

| Tool | Purpose |
|------|---------|
| `get_record_properties` | Field metadata for record type |
| `create_record` | Create test data record |
| `update_record` | Update existing record |
| `delete_record` | Soft-delete record |
| `query_records` | Query with filters |
| `list_users` | Available usernames |
| `get_session` | Session tracking |
| `rollback_session` | Undo all session creates |

### 3.4 KB Generation: Unified Pipeline

Today:
- **Atlas:** Parser runs via GitLab CI → outputs JSON → stored in `solutions-atlas-kb` repo
- **Jarvis:** JAI Appian app generates KB → stored in Appian folders

**After merge:** The Atlas Parser becomes the single KB generation engine for both planes.

```
Appian .zip packages (from test environments)
         │
         ▼
   Atlas Parser (unified)
         │
         ├──→ GitLab KB (Cloud Plane data)
         │    └── JSON files: bundles, objects, code, graph, versions, schema
         │
         └──→ Appian Environment (Live Plane KB - optional)
              └── JAI app stores parsed clusters, patterns, architecture
```

**Key decision:** The JAI Appian app continues to exist for Live Plane KB (clusters, patterns, architecture) because it provides real-time staleness detection (`staleCount`) and in-env semantic search. But the **parsing logic** is unified — Atlas Parser output feeds both storage locations.

### 3.5 Ownership Model

| Component | Owner | Responsibility |
|-----------|-------|---------------|
| Atlas Parser | Ram | Parsing logic, schema extraction, versioning, graph building |
| Cloud Plane (GitLab KB + tools) | Ram | Version history, bundles, offline analysis, CI pipeline |
| Live Plane (Appian APIs + tools) | Soma | Real-time queries, write operations, deployment, SAIL eval |
| Unified MCP Server | Joint | Routing layer, shared interface, tool registration |
| Data Generator | Ram | Test data CRUD operations |
| JAI Appian App | Soma | KB storage in Appian, staleness tracking, registration UI |

This preserves clear ownership boundaries while delivering a unified user experience.

---

## 4. Unified MCP Architecture

### 4.1 Single Docker Image

The unified service ships as one Docker image with configurable planes:

```dockerfile
# registry.gitlab.appian-stratus.com/appian/prod/appian-intelligence:latest
FROM python:3.11-slim
# Contains: Cloud Plane + Live Plane + Data Generator + Router
```

**Configuration via environment variables:**

| Variable | Required | Enables |
|----------|----------|---------|
| `GITLAB_TOKEN` | Yes (for Cloud) | Cloud Plane — GitLab KB access |
| `ATLAS_KB_PROJECT_ID` | No (default: 13490) | Which GitLab project holds the KB |
| `APPIAN_ENV_URL` | No | Live Plane — real-time Appian access |
| `APPIAN_API_KEY` | No | Live Plane authentication |
| `DATA_GEN_ENABLED` | No (default: true if APPIAN_ENV_URL set) | Data Generator tools |

**Graceful degradation:**
- Only `GITLAB_TOKEN` set → Cloud-only mode (30+ tools available)
- Only `APPIAN_ENV_URL` set → Live-only mode (25+ tools available)
- Both set → Full mode (all 50+ tools available)
- Neither set → Server refuses to start with clear error

### 4.2 Server Architecture

```python
# Simplified architecture
class UnifiedMCPServer:
    """Single MCP server with pluggable planes."""

    def __init__(self):
        self.cloud = CloudPlane()     # Atlas GitLab client
        self.live = LivePlane()       # Jarvis Appian client
        self.data_gen = DataGenPlane() # Data Generator client
        self.router = ToolRouter(self.cloud, self.live, self.data_gen)

    # All tools registered in one namespace
    # Router handles dispatch based on tool category and availability
```

**Internal module structure:**

```
appian_intelligence/
├── __init__.py
├── main.py                    # Entry point
├── server.py                  # MCP server + tool registration
├── router.py                  # Decides which plane handles each call
├── config.py                  # Environment configuration
├── cloud/                     # Cloud Plane (ex-Atlas)
│   ├── client.py              # GitLab API client
│   ├── datasource.py          # LRU cache + file fetching
│   ├── tools/                 # Cloud-specific tool implementations
│   │   ├── application.py
│   │   ├── bundle.py
│   │   ├── version.py
│   │   ├── graph.py
│   │   ├── schema.py
│   │   └── pipeline.py
│   └── models.py
├── live/                      # Live Plane (ex-Jarvis)
│   ├── client.py              # Appian HTTP client
│   ├── tools/                 # Live-specific tool implementations
│   │   ├── object.py
│   │   ├── deployment.py
│   │   ├── expression.py
│   │   ├── sql.py
│   │   ├── creation.py
│   │   └── kb.py             # Jarvis KB tools (clusters, patterns)
│   └── models.py
├── data_gen/                  # Data Generator Plane
│   ├── client.py
│   ├── tools/
│   │   ├── record.py
│   │   ├── properties.py
│   │   └── session.py
│   └── field_registry.py
└── shared/                    # Shared across planes
    ├── tool_schemas.py        # Unified tool definitions
    ├── logging_config.py
    └── utils.py
```

### 4.3 MCP Configuration (User-Facing)

Users configure ONE entry in their MCP settings:

```json
{
  "mcpServers": {
    "appian": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "--env", "GITLAB_TOKEN",
        "--env", "APPIAN_ENV_URL",
        "--env", "APPIAN_API_KEY",
        "registry.gitlab.appian-stratus.com/appian/prod/appian-intelligence:latest"
      ],
      "env": {
        "GITLAB_TOKEN": "${GITLAB_TOKEN}",
        "APPIAN_ENV_URL": "${APPIAN_ENV_URL}",
        "APPIAN_API_KEY": "${APPIAN_API_KEY}"
      }
    }
  }
}
```

This replaces:
- `atlas-mcp.json` (current Atlas config)
- Jarvis power `mcp.json` (current Jarvis config)
- Data Generator `mcp.json` (current DG config)

### 4.4 Tool Registration: Self-Describing

The unified server dynamically registers tools based on which planes are active:

```python
async def list_tools() -> list[Tool]:
    tools = []
    tools.extend(SHARED_TOOLS)  # Always available (search, overview, etc.)

    if self.cloud.is_configured():
        tools.extend(CLOUD_TOOLS)  # Version, bundle, graph tools

    if self.live.is_configured():
        tools.extend(LIVE_TOOLS)  # Deploy, SAIL eval, SQL tools

    if self.data_gen.is_configured():
        tools.extend(DATA_GEN_TOOLS)  # Record CRUD tools

    return tools
```

This means agents see only the tools they can actually use — no confusing "tool not available" errors.

### 4.5 Extensibility: Adding New Tools

When a developer wants to add a new tool:

1. Create a handler function in the appropriate plane (`cloud/tools/`, `live/tools/`, or `data_gen/tools/`)
2. Add the tool schema to `shared/tool_schemas.py`
3. Register in `server.py`
4. The tool is immediately available to all agents through the unified server

No need to create a new MCP server, new Docker image, or new configuration. One PR, one deployment, all users get it.

---

## 5. Orchestrator Agent Design

### 5.1 The Single Entry Point

When a user clones `solutions-os` and runs `kiro-cli chat`, they interact with the **Solutions OS Orchestrator** — a single agent that:

- Knows all available capabilities (sub-agents, tools, product knowledge)
- Routes requests to the appropriate specialist automatically
- Handles 80% of queries directly (using the unified MCP tools)
- Delegates complex multi-step workflows to specialist sub-agents

```
User → "How does evaluation scoring work in GSS?"
     → Orchestrator classifies: codebase question, GSS app
     → Uses unified MCP tools directly (get_app_overview, search_objects, get_object_code)
     → Answers in 2-3 tool calls

User → "Generate a full design document for GAMS-7126"
     → Orchestrator classifies: complex workflow, needs JIRA + KB + template
     → Delegates to design-doc sub-agent
     → Sub-agent runs full workflow, returns result
```

### 5.2 Orchestrator Agent Configuration

Located at `.kiro/agents/solutions-os.json` (workspace-level, available to all who clone):

```json
{
  "name": "solutions-os",
  "description": "Solutions OS — unified AI assistant for Appian development, product, QE, and UX workflows",
  "prompt": "file://./ai-framework/orchestrator/prompt.md",
  "mcpServers": {
    "appian": {
      "command": "docker",
      "args": ["run", "--rm", "-i",
        "--env", "GITLAB_TOKEN",
        "--env", "APPIAN_ENV_URL",
        "--env", "APPIAN_API_KEY",
        "registry.gitlab.appian-stratus.com/appian/prod/appian-intelligence:latest"
      ],
      "env": {
        "GITLAB_TOKEN": "${GITLAB_TOKEN}",
        "APPIAN_ENV_URL": "${APPIAN_ENV_URL}",
        "APPIAN_API_KEY": "${APPIAN_API_KEY}"
      }
    }
  },
  "tools": ["*", "subagent"],
  "allowedTools": ["read", "knowledge", "@appian"],
  "toolsSettings": {
    "subagent": {
      "availableAgents": [
        "developer",
        "product-owner",
        "ux-designer",
        "qe-agent",
        "sql-forge",
        "demo-driver",
        "code-reviewer",
        "a11y-fixer"
      ],
      "trustedAgents": ["developer", "product-owner", "ux-designer"]
    }
  },
  "resources": [
    "file://./README.md",
    "file://./ai-framework/orchestrator/capabilities.md",
    "file://./ai-framework/orchestrator/routing-rules.md",
    {
      "type": "knowledgeBase",
      "source": "file://./products",
      "name": "ProductKnowledge",
      "description": "All product domain context, features, steering, and decisions",
      "indexType": "best",
      "autoUpdate": true
    }
  ],
  "hooks": {
    "agentSpawn": [
      { "command": "echo 'Solutions OS ready' >&2" }
    ]
  },
  "includeMcpJson": true,
  "model": "claude-sonnet-4",
  "keyboardShortcut": "ctrl+s",
  "welcomeMessage": "Solutions OS ready. I have access to all Appian applications, product knowledge, and development tools. What are you working on?"
}
```

### 5.3 Sub-Agent Definitions

Each specialist becomes a sub-agent at `.kiro/agents/`:

| Agent File | Purpose | Key Capabilities |
|-----------|---------|-----------------|
| `developer.json` | Engineering — code exploration, impact analysis, tech debt | Cloud+Live tools, SAIL reference |
| `product-owner.json` | Product — feature specs, release reviews, onboarding | Cloud tools, product KB |
| `ux-designer.json` | UX — prototypes, SAIL generation, design compliance | Cloud tools, Aurora reference |
| `sql-forge.json` | Data — test data, bulk generation, ERDs, SAIL-to-SQL | Cloud schema + Data Gen tools |
| `demo-driver.json` | Demo data — workflow-aware realistic data creation | Cloud + Data Gen + exemplar learning |
| `qe-agent.json` | QE — test execution, verification, a11y auditing | Live tools + Playwright |
| `code-reviewer.json` | Code review — package review against best practices | Cloud+Live tools, checklist |
| `a11y-fixer.json` | Accessibility — automated a11y fix deployment | Live tools + Playwright |

Each sub-agent:
- Has its own prompt file with specialized instructions (from current steering files)
- Inherits MCP tools from the workspace (`includeMcpJson: true`)
- Can use only the subset of tools relevant to its role
- Returns results to the orchestrator via the `summary` tool

### 5.4 Capabilities Registry

The orchestrator loads a **capabilities manifest** at spawn time:

`ai-framework/orchestrator/capabilities.md`:

```markdown
# Available Capabilities

## Direct (handled by orchestrator)
- Explore any Appian application (code, dependencies, data model)
- Search for objects across all applications
- View release history and changelogs
- Query schema and relationships
- Answer product domain questions (from knowledge base)

## Delegated (sub-agents)

### developer
Trigger: code review requests, impact analysis, refactoring, implementation
Examples: "Review this package", "What breaks if I change X?", "Implement GAMS-1234"

### product-owner
Trigger: feature specs, release summaries, competitive analysis, onboarding
Examples: "Write a feature spec for X", "Summarize the last release", "Onboard me to GSS"

### ux-designer
Trigger: prototype creation, design system compliance, component decomposition
Examples: "Create an HTML prototype for X", "Check Aurora compliance", "Generate SAIL for this design"

### sql-forge
Trigger: test data, bulk data, ERD generation, SAIL-to-SQL conversion
Examples: "Create test data for evaluations", "Generate ERD for GSS", "Convert this SAIL to SQL"

### qe-agent
Trigger: test execution, verification, automated testing
Examples: "Verify GAMS-1234", "Run accessibility audit on this page"
```

### 5.5 Routing Rules

The orchestrator follows these rules (defined in `routing-rules.md`):

1. **Simple questions → answer directly** using unified MCP tools
2. **Multi-step workflows → delegate** to the appropriate sub-agent
3. **Ambiguous requests → ask** the user for clarification
4. **Product-specific context → search** the knowledge base first
5. **If a sub-agent fails → report** what happened, offer alternatives

**Classification signals:**

| Signal | Route To |
|--------|----------|
| "Review", "code review", package URL | `code-reviewer` |
| "Design doc", "spike", "implement" | `developer` |
| "Feature spec", "release summary", "onboard" | `product-owner` |
| "Prototype", "HTML", "SAIL UI", "Aurora" | `ux-designer` |
| "Test data", "bulk", "ERD", "SQL" | `sql-forge` |
| "Verify", "test", "execute test" | `qe-agent` |
| "Fix accessibility", "a11y" | `a11y-fixer` |
| Everything else | Handle directly |

---

## 6. Repository Structure Changes

### 6.1 Before → After Overview

**Current structure problems:**
- Powers scattered across `ai-framework/Engineering/.kiro/powers/` and `ai-framework/Product/.kiro/powers/`
- Each power has its own MCP config that needs separate installation
- No workspace-level agent — users must install powers manually
- `ai-framework/tools/Atlas/` and `ai-framework/tools/Jarvis/` duplicate docs from source repos
- Inconsistent product folder conventions

**New structure principles:**
- Orchestrator + sub-agents at `.kiro/agents/` — immediately available
- Single MCP config at `.kiro/settings/mcp.json` — no per-power configs
- Skills replace powers for specialized knowledge (lighter, no MCP overhead)
- Products enforce consistent conventions via templates

### 6.2 New Directory Layout

```
solutions-os/
├── .kiro/
│   ├── agents/                          # ← NEW: All agents live here
│   │   ├── solutions-os.json           # Orchestrator (default entry point)
│   │   ├── developer.json              # Engineering sub-agent
│   │   ├── product-owner.json          # Product sub-agent
│   │   ├── ux-designer.json            # UX sub-agent
│   │   ├── sql-forge.json              # Data/SQL sub-agent
│   │   ├── demo-driver.json            # Demo data sub-agent
│   │   ├── qe-agent.json              # QE/Test sub-agent
│   │   ├── code-reviewer.json         # Code review sub-agent
│   │   └── a11y-fixer.json            # Accessibility sub-agent
│   ├── settings/
│   │   └── mcp.json                    # ← Single MCP config (unified server)
│   ├── skills/                          # ← NEW: On-demand specialized knowledge
│   │   ├── sail-reference/
│   │   │   └── SKILL.md
│   │   ├── appian-best-practices/
│   │   │   └── SKILL.md
│   │   ├── aurora-design-system/
│   │   │   └── SKILL.md
│   │   └── google-workspace/
│   │       └── SKILL.md
│   └── steering/                        # Global steering (always loaded)
│       └── git-workflow.md
│
├── ai-framework/
│   ├── orchestrator/                    # ← NEW: Orchestrator configuration
│   │   ├── prompt.md                   # System prompt for orchestrator
│   │   ├── capabilities.md            # Registry of all capabilities
│   │   └── routing-rules.md           # Classification & routing logic
│   ├── agents/                          # ← NEW: Sub-agent prompts
│   │   ├── developer-prompt.md
│   │   ├── product-owner-prompt.md
│   │   ├── ux-designer-prompt.md
│   │   ├── sql-forge-prompt.md
│   │   ├── demo-driver-prompt.md
│   │   ├── qe-agent-prompt.md
│   │   ├── code-reviewer-prompt.md
│   │   └── a11y-fixer-prompt.md
│   └── workflows/                       # ← MOVED: Workflow definitions (from steering files)
│       ├── code-review-workflow.md
│       ├── design-doc-workflow.md
│       ├── spike-research-workflow.md
│       ├── implementation-workflow.md
│       └── pipeline-check-workflow.md
│
├── products/                            # Unchanged structure, enforced conventions
│   ├── gam-solutions/                  # Suite
│   ├── case-management-studio/         # Standalone
│   ├── procuresight/                   # Standalone
│   ├── synapse/                        # Standalone
│   ├── insurance-underwriting/         # Standalone
│   └── doccenter/                      # Standalone
│
├── @DOCS/                              # Shared standards
│   ├── schemas/
│   │   └── product-folder.schema.md   # ← NEW: Enforces consistent conventions
│   └── standards/
│       └── coding-guidelines.md
│
├── README.md
└── setup.sh                             # ← NEW: One-command onboarding script
```

### 6.3 What Gets Removed

| Current Location | Action | Reason |
|-----------------|--------|--------|
| `ai-framework/Engineering/.kiro/powers/atlas-developer/` | Convert to sub-agent prompt | Powers replaced by agents |
| `ai-framework/Engineering/.kiro/powers/atlas-sql-forge/` | Convert to sub-agent prompt | Powers replaced by agents |
| `ai-framework/Engineering/.kiro/powers/atlas-demo-driver/` | Convert to sub-agent prompt | Powers replaced by agents |
| `ai-framework/Engineering/.kiro/powers/atlas-dev-documentation/` | Merge into developer agent | Consolidated |
| `ai-framework/Engineering/.kiro/powers/sail-reference/` | Convert to skill | Reference docs, not an agent |
| `ai-framework/Product/.kiro/powers/atlas-product-owner/` | Convert to sub-agent prompt | Powers replaced by agents |
| `ai-framework/Product/.kiro/powers/atlas-ux-designer/` | Convert to sub-agent prompt | Powers replaced by agents |
| `ai-framework/tools/Atlas/` | Remove (pointer to source repo only) | Docs live in source repo |
| `ai-framework/tools/Jarvis/` | Remove (pointer to source repo only) | Docs live in source repo |
| `ai-framework/mcp-configs/atlas-mcp.json` | Replace with unified config | Single config in `.kiro/settings/` |

### 6.4 Product Folder Convention (Enforced)

Every product MUST follow this structure:

```
products/<product-name>/
├── README.md              # Product overview, team, getting started
├── steering/              # Product-level AI directives (REQUIRED)
│   └── steering.md       # Tells agents how to work with this product
├── domain/                # Business context
│   ├── personas/          # User personas (if applicable)
│   └── *.md              # Vision, overview, entities
├── features/              # Feature specs (one folder per feature)
│   └── <feature-name>/
│       └── spec.md
├── competitive-analysis/  # Market research
├── arch-decision-logs/    # ADRs
└── src-appian-atlas/      # Appian source packages for KB generation
```

**Enforcement:** A CI check validates that every product has at minimum `README.md` and `steering/steering.md`.

### 6.5 Setup Script

`setup.sh` — One-command onboarding:

```bash
#!/bin/bash
# Solutions OS Setup
# Usage: ./setup.sh

echo "🔧 Solutions OS Setup"

# Check prerequisites
command -v docker >/dev/null || { echo "❌ Docker required"; exit 1; }
command -v kiro-cli >/dev/null || { echo "❌ Kiro CLI required"; exit 1; }

# Check env vars
[[ -z "$GITLAB_TOKEN" ]] && echo "⚠️  Set GITLAB_TOKEN for full functionality"
[[ -z "$APPIAN_ENV_URL" ]] && echo "ℹ️  Set APPIAN_ENV_URL for live environment access"

# Docker login
echo "📦 Authenticating with Docker registry..."
docker login registry.gitlab.appian-stratus.com 2>/dev/null

# Pull unified image
echo "📥 Pulling Appian Intelligence image..."
docker pull registry.gitlab.appian-stratus.com/appian/prod/appian-intelligence:latest

# Verify
echo "✅ Setup complete. Run: kiro-cli --agent solutions-os"
```

---

## 7. Implementation Phases

### Phase 1: Unified MCP Server (Weeks 1-3)

**Goal:** Single Docker image that serves tools from both planes.

| Task | Owner | Deliverable |
|------|-------|------------|
| Create `appian-intelligence` repo with module structure | Ram | Repo scaffolded with cloud/, live/, data_gen/, shared/ |
| Port Atlas MCP tools into `cloud/` module | Ram | All 30 Atlas tools working |
| Port Jarvis MCP tools into `live/` module | Soma | All 42 Jarvis tools working |
| Port Data Generator tools into `data_gen/` module | Ram | All 8 DG tools working |
| Implement router with plane detection | Ram | Auto-routing based on config |
| Consolidate overlapping tools (Section 3.3) | Joint | Unified namespace, no duplicates |
| Docker image build pipeline | Ram | CI builds + publishes to registry |
| Integration tests | Joint | All tools pass against test env |

**Exit criteria:** `docker run appian-intelligence` with both env vars set → all tools available via single MCP connection.

### Phase 2: Orchestrator + Sub-Agents (Weeks 2-4, parallel with Phase 1)

**Goal:** Clone repo → run orchestrator → everything works.

| Task | Owner | Deliverable |
|------|-------|------------|
| Write orchestrator prompt (`prompt.md`) | Ram | Routing logic, product awareness |
| Write capabilities registry | Ram | Machine-readable agent/tool manifest |
| Convert atlas-developer power → `developer.json` agent | Ram | Agent config + prompt file |
| Convert atlas-product-owner power → `product-owner.json` | Ram | Agent config + prompt file |
| Convert atlas-ux-designer power → `ux-designer.json` | Ram | Agent config + prompt file |
| Convert atlas-sql-forge power → `sql-forge.json` | Ram | Agent config + prompt file |
| Convert Jarvis workflows → sub-agent prompts | Soma | code-reviewer, design-doc integration |
| Convert sail-reference power → skill | Ram | SKILL.md with frontmatter |
| Create `.kiro/settings/mcp.json` (unified) | Ram | Single MCP config |
| Write `setup.sh` onboarding script | Ram | Docker + token validation |

**Exit criteria:** New user runs `./setup.sh && kiro-cli --agent solutions-os` → can explore apps, ask questions, and delegate to specialists.

### Phase 3: Repo Restructure (Week 4-5)

**Goal:** Clean structure, enforced conventions, deprecated paths removed.

| Task | Owner | Deliverable |
|------|-------|------------|
| Move agent prompts to `ai-framework/agents/` | Ram | All prompts in one location |
| Move workflows to `ai-framework/workflows/` | Joint | All workflow MDs consolidated |
| Create orchestrator directory | Ram | prompt.md, capabilities.md, routing-rules.md |
| Remove old powers directories | Ram | Clean deletion after agents verified |
| Remove `ai-framework/tools/Atlas/` and `Jarvis/` | Ram | Replace with README pointer |
| Fix product folder inconsistencies | All teams | Standardize casing, add missing steering |
| Create `@DOCS/schemas/product-folder.schema.md` | Ram | Convention enforcement |
| Add CI check for product conventions | Ram | Pipeline validates structure |
| Update README.md | Ram | Reflects new architecture |

**Exit criteria:** Repo structure matches Section 6.2. CI passes. No references to old power paths.

### Phase 4: Migration & Deprecation (Week 5-6)

**Goal:** All existing users migrated, old tools deprecated.

| Task | Owner | Deliverable |
|------|-------|------------|
| Write migration guide for power users | Ram | Step-by-step: old power → new agent |
| Add deprecation notice to old power READMEs | Joint | Points to new location |
| Run migration workshop for teams | Joint | Hands-on transition |
| Verify all SWAT-a-Palooza projects work | Joint | A11Y fixer, TEA, Sweep verified |
| Remove old Docker images from registry (after grace period) | Ram | Clean registry |
| Update Kiro powers panel instructions | Ram | New install path documented |

**Exit criteria:** Zero users on old power-based workflow. All teams using orchestrator.

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Dev resistance to merge | Medium | High | Clear ownership model (Section 3.5), neither tool "loses" |
| Breaking existing workflows during migration | Medium | Medium | Phase 4 runs parallel — old powers kept until new agents verified |
| Docker image too large (3 planes combined) | Low | Low | Python slim base, shared deps, multi-stage build |
| Context window bloat (too many tools registered) | Medium | Medium | Dynamic registration (Section 4.4) — only show active tools |
| Teams don't update product folders | High | Medium | CI enforcement (Section 6.4), workshop, champion per product |

---

## 9. Success Metrics

| Metric | Target | Measured By |
|--------|--------|-------------|
| Onboarding time (clone → first useful interaction) | < 5 minutes | User testing |
| Tool discovery (% of users who use 3+ capabilities) | > 70% | Usage telemetry |
| Power installation support tickets | 0 | Slack channel |
| Duplicated powers (same capability, different backend) | 0 | Repo audit |
| Product folders with steering files | 100% | CI check |
| Sub-agent delegation success rate | > 90% | Agent logs |

---

## 10. Decision Points for Approval

The following decisions need stakeholder sign-off:

1. **Merge Atlas + Jarvis into one image** — Requires both devs to commit to the unified namespace
2. **Deprecate individual powers** — Teams currently using atlas-developer or Jarvis power will need to switch
3. **Enforce product folder conventions** — All teams must add `steering/steering.md` at minimum
4. **Single orchestrator as default** — When users open the repo, they get the orchestrator, not the default Kiro agent
5. **KB generation ownership** — Atlas Parser as the single parsing engine, JAI app as optional live storage

---

## Appendix A: Current Tool Inventory

### Atlas MCP Server (30 tools)
`list_applications`, `get_app_overview`, `search_bundles`, `get_bundle`, `search_objects`, `get_dependencies`, `get_object_detail`, `list_orphans`, `get_orphan`, `get_dependency_path`, `get_transitive_dependencies`, `get_hub_objects`, `get_object_code`, `list_releases`, `get_changelog`, `compare_releases`, `get_object_history`, `get_object_at_release`, `get_release_impact`, `refresh_knowledge_base`, `list_documents`, `get_document`, `list_git_directory`, `get_git_content`, `search_git_content`, `get_app_schema`, `get_schema_relationships`, `get_reference_data`, `get_insertion_order`, `get_schema_summary`, `get_record_type_map`, `get_field_map`

### Jarvis MCP Server (42 tools)
**KB:** `jarvis_get_app_tree`, `jarvis_search_objects`, `jarvis_get_cluster`, `jarvis_get_object_content`, `jarvis_get_context`, `jarvis_get_dependency_chain`, `jarvis_get_impact_analysis`, `jarvis_get_data_model`, `jarvis_get_objects_by_type`, `jarvis_get_entry_points_for_object`, `jarvis_get_patterns`, `jarvis_get_architecture`, `jarvis_get_dead_code`, `jarvis_get_shared_objects`, `jarvis_get_dependents_batch`, `jarvis_get_precedents_batch`
**Live:** `get_appian_object`, `search_objects_by_name`, `get_object_dependencies`, `evaluate_sail_expression`, `search_objects_semantic`, `query_sql`, `list_application_objects`, `get_object_diff`, `get_version_context`, `validate_record_relationships`, `analyze_appian_code`, `explain_appian_code`
**Package/Deploy:** `create_package_for_ticket`, `get_package_contents_from_url`, `inspect_package`, `get_inspection_results`, `deploy_package`, `get_deployment_results`
**Creation:** `create_constant`, `preview_constant`
**Config:** `get_jarvis_config`, `get_application_info`, `get_environment_info`, `generate_uuids`, `get_all_type_metadata`, `get_kb_folder_id`, `get_stale_objects`

### Data Generator MCP (8 tools)
`get_record_properties`, `create_record`, `update_record`, `delete_record`, `query_records`, `list_users`, `get_session`, `rollback_session`

---

*End of Document*
