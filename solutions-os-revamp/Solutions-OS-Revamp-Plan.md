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

## 6. T.I.M.E. Framework Integration

### 6.1 Why T.I.M.E.

The current `products/` structure organizes content by **artifact type** (domain/, features/, arch-decision-logs/). This tells you *what* something is, but not *where it is in the lifecycle*. AI agents have no signal about whether an idea is raw, being refined, committed to a sprint, or shipped.

The T.I.M.E. Framework (Taking Ideas to Market Expeditiously) solves this by organizing content by **SDLC outcome**. The folder structure itself becomes a workflow signal — when a file moves from `01-discovery/` to `02-refinement/`, AI agents know to expand it into a spec.

### 6.2 Revised Product Folder Structure

Each product adopts the T.I.M.E. lifecycle folders:

```
products/<product-name>/
├── README.md                    # Product overview
├── steering/                    # AI directives (always-on context)
│   └── steering.md
├── 00-context/                  # Ground truth — vision, architecture, current state
│   ├── vision.md
│   ├── personas/
│   ├── architecture/
│   ├── competitive-analysis/
│   └── branding/
├── 01-discovery/                # Raw ideas, feedback, research
│   └── <idea-name>.md
├── 02-refinement/               # Ideas being shaped into specs and prototypes
│   └── <feature-name>/
│       ├── spec.md
│       ├── prototype.html
│       └── ux-research.md
├── 03-planning/                 # Committed work, ready for breakdown
│   └── <feature-name>/
│       ├── spec.md              # (moved from refinement)
│       ├── tickets.md           # AI-generated ticket breakdown
│       └── release-target.md
├── 04-delivery/                 # Active development and QA
│   └── <feature-name>/
│       ├── design.md
│       ├── tasks.md
│       └── test-plan.md
├── 05-shipped/                  # What made it to market
│   └── <feature-name>/
│       ├── release-notes.md
│       └── post-mortem.md
└── src-appian-atlas/            # Appian source packages for KB generation
```

### 6.3 How AI Acts on Transitions

The orchestrator and sub-agents use folder location as a **signal for automated actions**:

| Transition | AI Action |
|-----------|-----------|
| New file in `01-discovery/` | Scan for duplicates across all products, flag cross-suite dependencies, suggest related context from `00-context/` |
| Move to `02-refinement/` | Expand idea using product context, generate feature card template, draft spec outline, kick off lightweight HTML prototype |
| Move to `03-planning/` | Break feature into implementation tickets, estimate complexity using KB data, relate to release |
| Move to `04-delivery/` | Generate design document from spec, create task breakdown, link to relevant Appian objects via unified MCP |
| Move to `05-shipped/` | Write release notes, update product README, archive delivery artifacts |

### 6.4 Implementation via Hooks

The orchestrator agent uses `postToolUse` hooks to detect file movements:

```json
{
  "hooks": {
    "postToolUse": [
      {
        "matcher": "fs_write",
        "command": "python3 ai-framework/orchestrator/detect-transition.py"
      }
    ]
  }
}
```

The detection script checks if a file was created in a lifecycle folder and triggers the appropriate automation. This keeps the magic invisible — users just move files, AI responds.

### 6.5 Migration from Current Structure

| Current Location | Maps To |
|-----------------|---------|
| `domain/` (vision, personas, overview) | `00-context/` |
| `competitive-analysis/` | `00-context/competitive-analysis/` |
| `features/<feature>/` (specs in progress) | `02-refinement/` or `03-planning/` depending on state |
| `arch-decision-logs/` | `00-context/architecture/` |
| `src-appian-atlas/` | Stays at root level (not lifecycle-bound) |

Teams migrate incrementally — move existing content into the appropriate lifecycle stage based on its current state.

### 6.6 What Stays from Current Structure

- **Suite inheritance** (GAM → child solutions) — unchanged
- **Cross-product linking** (reference files, steering directives) — unchanged
- **`steering/`** — stays at product root, not inside a lifecycle folder (it's always-on context for agents, not a lifecycle artifact)

---

## 7. Repository Structure Changes

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

Every product MUST follow the T.I.M.E. lifecycle structure (see Section 6):

```
products/<product-name>/
├── README.md              # Product overview, team, getting started
├── steering/              # Product-level AI directives (REQUIRED)
│   └── steering.md
├── 00-context/            # Ground truth: vision, personas, architecture
├── 01-discovery/          # Raw ideas and research
├── 02-refinement/         # Ideas → specs and prototypes
├── 03-planning/           # Committed work, ticket breakdowns
├── 04-delivery/           # Active dev and QA
├── 05-shipped/            # Released features and notes
└── src-appian-atlas/      # Appian source packages for KB generation
```

**Enforcement:** A CI check validates that every product has at minimum `README.md`, `steering/steering.md`, and the six lifecycle folders.

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

## 8. Implementation Phases

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

## 9. Knowledge Base Strategy

### 8.1 Current State

The Atlas KB lives inside the solutions-os repo at `ai-framework/tools/Atlas/solutions-kb/`. It contains parsed JSON data for each registered Appian application (bundles, objects, code, graph, versions, schema). This data is generated by the Atlas Parser and synced via a GitLab CI pipeline.

### 8.2 Two Knowledge Layers

With T.I.M.E. and the orchestrator, we now have **two distinct knowledge layers**:

| Layer | Source | Contains | Used By |
|-------|--------|----------|---------|
| **Product Knowledge** | `products/` folders (T.I.M.E. structure) | Vision, personas, feature specs, decisions, competitive analysis | Orchestrator's knowledgeBase resource, product-owner agent |
| **Application Knowledge** | `ai-framework/tools/Atlas/solutions-kb/data/` | Parsed Appian code, objects, dependencies, schema, bundles | Unified MCP (Cloud Plane), developer agent, sql-forge agent |

These serve different purposes:
- **Product Knowledge** answers "what should we build and why?"
- **Application Knowledge** answers "what exists in the code and how does it work?"

### 8.3 Knowledge Base Indexing

The orchestrator agent indexes `products/` as a knowledge base:

```json
{
  "resources": [
    {
      "type": "knowledgeBase",
      "source": "file://./products",
      "name": "ProductKnowledge",
      "description": "All product domain context, lifecycle artifacts, and decisions",
      "indexType": "best",
      "autoUpdate": true
    }
  ]
}
```

Application Knowledge is accessed via the unified MCP tools (not indexed as a knowledge base — it's already structured JSON queried on demand).

### 8.4 KB Refresh Pipeline

The existing CI pipeline at `ai-framework/tools/Atlas/solutions-kb/.gitlab-ci-sync.yml` continues to handle Application KB refresh. No change needed — it runs when triggered, parses the latest Appian packages, and commits updated JSON to the repo.

Product Knowledge auto-updates on every `git pull` (since it's just the `products/` folder contents indexed by Kiro's knowledge base engine).

---

## 10. Environment Registry

### 9.1 The Problem

Teams work across multiple Appian environments (dev, test, staging, demo). Currently, environment details are scattered:
- Jarvis stores them in `mcp.json` env vars (one env at a time)
- API keys live in individual users' configs
- No shared knowledge of which environments exist, who has access, or what's deployed where

### 9.2 Centralized Environment Registry

A registry file at `.tao/environments.json` (or `.kiro/environments.json`) that all agents can reference:

```json
{
  "environments": {
    "gam-dev2": {
      "url": "https://eng-test-fed-aq-dev2.appianpreview.com",
      "api_endpoint": "https://eng-test-fed-aq-dev2.appianpreview.com/suite/webapi/",
      "products": ["source-selection", "vendor-management", "contract-writing"],
      "type": "development",
      "notes": "Primary GAM development environment"
    },
    "cms-dev": {
      "url": "https://eng-test-solutions-cms-dev.appianpreview.com",
      "api_endpoint": "https://eng-test-solutions-cms-dev.appianpreview.com/suite/webapi/",
      "products": ["case-management-studio"],
      "type": "development",
      "notes": "CMS development environment"
    },
    "solutions-global-dev": {
      "url": "https://eng-test-solutions-global-dev.appianpreview.com",
      "api_endpoint": "https://eng-test-solutions-global-dev.appianpreview.com/suite/webapi/",
      "products": ["jarvis-app-intelligence"],
      "type": "shared",
      "notes": "Shared environment for cross-product tools"
    }
  },
  "users": {
    "ramaswamy.u": {
      "default_env": "gam-dev2",
      "accessible_envs": ["gam-dev2", "cms-dev", "solutions-global-dev"]
    }
  }
}
```

### 9.3 How Agents Use It

- **Environment selection** — When a user says "deploy to staging," the agent looks up the environment by name/type
- **Context-aware routing** — If the user is working on a CMS feature, the agent auto-selects the CMS environment
- **Multi-env queries** — "Compare the schema between dev and staging" routes to both environments
- **Credential resolution** — API keys stored separately in a secure credentials file (`~/.tao/env` or `~/.kiro/credentials`), referenced by environment name

### 9.4 Credential Storage (Separate from Registry)

Environment URLs are safe to commit. Credentials are NOT:

```bash
# ~/.solutions-os/credentials (gitignored, chmod 600)
GAM_DEV2_API_KEY=<key>
CMS_DEV_API_KEY=<key>
SOLUTIONS_GLOBAL_API_KEY=<key>
GITLAB_TOKEN=<token>
```

The unified MCP server reads the registry for URLs and the credentials file for auth. The `setup.sh` script guides users through initial credential setup.

### 9.5 Environment Switching in the Unified MCP

The unified server supports a `set_environment` tool or auto-detects from context:

```
User: "Query the evaluations table in dev2"
Agent: Uses GAM_DEV2_API_KEY + gam-dev2 URL for SQL query

User: "Now deploy this to staging"
Agent: Looks up staging env, uses staging credentials
```

If no environment is specified, the agent uses the user's `default_env` from the registry.

---

## 11. Metrics and Observability

### 10.1 What to Measure

| Category | Metrics |
|----------|---------|
| **Adoption** | Daily active users, sessions per user, agent selection distribution |
| **Efficiency** | Time to first useful response, tool calls per query, session duration |
| **Quality** | Error rate per tool, failed delegations, user corrections |
| **Coverage** | Products with steering files, KB freshness (staleCount), lifecycle folder usage |
| **Tool usage** | Most/least used tools, Cloud vs Live plane distribution, write operation frequency |

### 10.2 Implementation

A lightweight SQLite metrics store (similar to Tao's approach):

```sql
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    session_id TEXT,
    agent TEXT,
    event TEXT NOT NULL,       -- 'tool_call', 'delegation', 'error', 'transition'
    tool_name TEXT,
    duration_ms INTEGER,
    success BOOLEAN,
    metadata TEXT              -- JSON blob for event-specific data
);
```

The unified MCP server logs every tool call with timing. The orchestrator logs delegations and routing decisions. This data feeds a simple dashboard (can be as basic as a CLI report or a future web UI).

### 10.3 Health Dashboard

A `tao doctor`-style command that shows system health:

```bash
$ solutions-os status

Unified MCP Server:
  ☁️  Cloud Plane:  ✅ Connected (GitLab KB, 6 apps indexed)
  🔴 Live Plane:   ✅ Connected (gam-dev2, 42 tools active)
  📊 Data Gen:     ✅ Connected (8 tools active)

Knowledge Base:
  📚 Product KB:   6 products indexed, last update 2min ago
  🔧 App KB:       6 apps, 0 stale

Environments:
  gam-dev2:        ✅ Reachable
  cms-dev:         ✅ Reachable
  solutions-global: ⚠️  API key not configured
```

---

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Dev resistance to merge | Medium | High | Clear ownership model (Section 3.5), neither tool "loses" |
| Breaking existing workflows during migration | Medium | Medium | Phase 4 runs parallel — old powers kept until new agents verified |
| Docker image too large (3 planes combined) | Low | Low | Python slim base, shared deps, multi-stage build |
| Context window bloat (too many tools registered) | Medium | Medium | Dynamic registration (Section 4.4) — only show active tools |
| Teams don't update product folders | High | Medium | CI enforcement (Section 6.4), workshop, champion per product |

---

## 12. Risk Assessment

| Metric | Target | Measured By |
|--------|--------|-------------|
| Onboarding time (clone → first useful interaction) | < 5 minutes | User testing |
| Tool discovery (% of users who use 3+ capabilities) | > 70% | Usage telemetry |
| Power installation support tickets | 0 | Slack channel |
| Duplicated powers (same capability, different backend) | 0 | Repo audit |
| Product folders with steering files | 100% | CI check |
| Sub-agent delegation success rate | > 90% | Agent logs |

---

## 13. Decision Points for Approval

The following decisions need stakeholder sign-off:

1. **Merge Atlas + Jarvis into one image** — Requires both devs to commit to the unified namespace
2. **Deprecate individual powers** — Teams currently using atlas-developer or Jarvis power will need to switch
3. **Enforce product folder conventions** — All teams must add `steering/steering.md` at minimum
4. **Single orchestrator as default** — When users open the repo, they get the orchestrator, not the default Kiro agent
5. **KB generation ownership** — Atlas Parser as the single parsing engine, JAI app as optional live storage

---

## Appendix A: SWAT-a-Palooza Project Integration Map

All 20 completed projects from SWAT-a-Palooza, organized by theme, with their placement in the revamped Solutions OS architecture.

### Accessibility (2 projects)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 1 | **A11Y Fixer** | Soma | Soma, Harish | `a11y-fixer` sub-agent | Uses unified MCP Live Plane (get object, deploy), Jira MCP, Playwright MCP. 56 fix patterns in agent prompt. Orchestrator delegates on "fix accessibility" triggers. |
| 2 | **AI A11y Audit Power** | Ganesh | Ganesh | Skill: `.kiro/skills/a11y-audit/SKILL.md` | 80+ rule checks, recursive interface discovery, cross-app pattern matching. Loadable by developer, qe-agent, and a11y-fixer agents. Google Doc report via gws CLI. |

### Data Generation (2 projects)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 3 | **Atlas SQL Forge** | Ram | Ram, Dineshkumar | `sql-forge` sub-agent | Uses unified MCP Cloud Plane (schema, relationships, insertion-order) + Data Gen Plane (CRUD). 6-step workflow (analyze → discover → architect → plan → approve → execute). |
| 4 | **DataForge - AI-Powered Test Data at Scale** | Hitesh | Hitesh | `sql-forge` sub-agent capability | Complements SQL Forge with bulk/offline mode. Schema introspection, pattern-matched generators, dependency-ordered inserts. Scale tiers (S/M/L/XL) per solution. |

### Delivery Flow Coach (1 project)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 5 | **Flow-Craft Sprint Report** | Josh | Josh, Saravana, Rob | Standalone automation / orchestrator capability | Python-based metrics aggregation (no hallucinations). Uses Jira MCP + custom data sources. Color-coded health reports. Could become a capability triggered by "generate sprint report". |

### Design and UX Handoff (4 projects)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 6 | **Atlas UX Designer Power Enhancements** | Vedant | Vedant | `ux-designer` sub-agent | 6 actions become capabilities in agent prompt: Edge Case Analysis, Platform Feasibility, Design Consistency, Component Decomposition, Design-to-Dev Handoff, Aurora Compliance. |
| 7 | **Kiro to FigJam (Spec to User Flow)** | Anthony | Anthony | `ux-designer` sub-agent capability | Reads specs from T.I.M.E. `02-refinement/`. FigJam MCP for diagram creation. Auto-syncs diagrams as specs evolve. |
| 8 | **Spec to Slides** | Sonali | Sonali | `product-owner` sub-agent capability | Transforms markdown spec into .pptx with feature titles, interaction callouts, SAIL link placeholders. Exports to Google Slides as single source of truth for handoff. |
| 9 | **Jarvis SAIL Canvas** | Govind | Govind | `ux-designer` sub-agent capability | Uses unified MCP Live Plane (get object with dependencies). Local React app for interactive preview with state switching. Exports validated SAIL code. |

### Development Tooling and IDE (5 projects)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 10 | **Jarvis Sweep** | Khoa | Khoa, Allie, Noah, Will | `developer` sub-agent capability | Workflow (export → analyze → clean → deploy) in `ai-framework/workflows/sweep-workflow.md`. Uses unified MCP Live Plane. Triggered by "sweep X" or "clean up X". |
| 11 | **Application Performance Profiling (Perf-Profiler)** | Raajiv | Raajiv | Standalone CLI tool / `developer` capability | Package transformation tool. Input: Appian zip. Output: instrumented zip. Invokable by developer sub-agent as shell command. Generic — works across any app. |
| 12 | **Local-IDE Development** | William Ingold | William Ingold | Standalone tool (IDE extension) | VSCode/Kiro extension. Benefits from environment registry (LCP API target) and unified MCP (same tools). Not a sub-agent itself. |
| 13 | **LCP APIs / a!migo** | Saurabh | Saurabh, Ayisha, Hunter, Eric, Karan | `developer` sub-agent capability | 130+ Appian operations via LCP API. Data model workflow uses environment registry. Foundation for automating object creation, mockups-to-SAIL, query record generation. |
| 14 | **Performance Power - SAIL to SQL** | Dineshkumar K | Dineshkumar K, Ram | `sql-forge` sub-agent capability | Converts SAIL code to SQL stored procedures. Uses unified MCP Cloud Plane (get object code) + Live Plane (evaluate). Multiple DB support (MariaDB, Oracle). |

### Documentation and Reporting (2 projects)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 15 | **Solutions Feature Doc Genie** | Meenakshi | Meenakshi | `product-owner` sub-agent capability | One prompt → 6 documents (FIP, Tech Design, Perf Review, Security Review, Arch Overview, ADR). Uses unified MCP Cloud Plane (8 Atlas tool calls). Spec readiness validation. Google Docs export. |
| 16 | **Automate ERD and Release Documentation** | Revathi | Revathi, Ranjith, Gautham | `sql-forge` sub-agent capability | One line → ERDs (simple + complex) in Lucidchart + release notes in Google Docs. Uses unified MCP Cloud Plane for schema. Handles 155+ tables, 199 FKs. |

### Process and Methodology (2 projects)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 17 | **AI-assisted Kiro KB Maintenance** | Colin Hutchison | Colin Hutchison | Skill + Hook | Steering file becomes skill. On release: reviews public docs, KB files, app code → updates → quality checklist → cross-document review → commit. Hook automates git operations. |
| 18 | **The T.I.M.E. Framework** | Ben Lloyd | Ben Lloyd | Core repo structure (Section 6) | Integrated as product folder convention. Six lifecycle stages. AI acts on file transitions. Foundation of the revamp. |

### Testing (2 projects)

| # | Project | Lead | Team | Fits As | Integration |
|---|---------|------|------|---------|-------------|
| 19 | **Solutions Test Execution Agent** | Divya | Divya, Annamalai, Ram, Anu, Susheela, Harish, Devin, Rajesh, Asmita, Suganya, Hanna | `qe-agent` sub-agent | Uses unified MCP (Cloud for impact analysis, Live for data gen), Playwright MCP, Jira MCP. Environment registry provides target env. QE knowledge base as skill. Future: zero-touch via GitLab CI. |
| 20 | **Expression Test Case Generation (Jarvis Assert)** | Abby | Abby, Sarah, Brian | `developer` sub-agent capability | Generates expression rule tests (happy path, null, off-by-one, out-of-bounds). Same deploy pipeline as Sweep. Triggered by "generate tests for X". |

### Summary: Agent Placement

```
.kiro/agents/
├── solutions-os.json        # Orchestrator (routes to all below)
├── developer.json           # Projects: 10 (Sweep), 11 (Perf-Profiler), 13 (LCP/a!migo), 20 (Assert)
├── product-owner.json       # Projects: 8 (Spec to Slides), 15 (Feature Doc Genie)
├── ux-designer.json         # Projects: 6 (UX Enhancements), 7 (Kiro→FigJam), 9 (SAIL Canvas)
├── sql-forge.json           # Projects: 3 (SQL Forge), 4 (DataForge), 14 (SAIL-to-SQL), 16 (ERD Gen)
├── qe-agent.json            # Projects: 19 (TEA)
├── code-reviewer.json       # Code review workflows (from Jarvis)
└── a11y-fixer.json          # Projects: 1 (A11Y Fixer)

.kiro/skills/
├── a11y-audit/SKILL.md      # Project 2 (AI A11y Audit)
├── kb-maintenance/SKILL.md  # Project 17 (KB Maintenance)
├── sail-reference/SKILL.md  # SAIL grammar + best practices
└── aurora-design/SKILL.md   # Aurora Design System reference

Standalone tools (not sub-agents):
├── Perf-Profiler             # Project 11 (CLI tool, invokable by developer agent)
├── Local-IDE Extension       # Project 12 (VSCode/Kiro extension)
└── Flow-Craft Sprint Report  # Project 5 (metrics automation script)
```

**Every project works because:**
1. **Unified MCP** — all agents access both Cloud and Live tools through one server
2. **Orchestrator** — auto-routes requests to the right specialist, no manual selection
3. **Environment registry** — handles multi-env targeting without hardcoded URLs
4. **T.I.M.E. structure** — provides lifecycle context for smarter automation
5. **Skills** — share reference knowledge (a11y rules, SAIL grammar) across all agents

---

## Appendix B: Current Tool Inventory

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
