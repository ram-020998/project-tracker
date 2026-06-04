# Solutions Copilot — Implementation Plan

**Version:** 1.0
**Date:** June 4, 2026
**Author:** Ram
**Status:** POC Implementation

---

## 1. Overview

Solutions Copilot is a working POC that demonstrates the revamped Solutions OS architecture. It proves the complete system works end-to-end: orchestrator agent routing, modular MCP infrastructure, lightweight powers, one-command bootstrap, and SWAT project integration.

### What This POC Proves

1. An orchestrator agent can route requests to specialist sub-agents
2. MCP servers work as shared infrastructure (not power-scoped)
3. Powers are lightweight (POWER.md + steering, no mcp.json)
4. `setup.sh` bootstraps everything in one command
5. Solutions Intelligence Cloud Plane + lcp-api MCP (Write Plane) work together
6. All 20 SWAT projects can be accommodated in this architecture

### What This POC Uses

| Role | Implementation |
|------|---------------|
| Intelligence (read) | Solutions Intelligence Server (existing Docker image) |
| Object CRUD (write) | Solutions LCP MCP Server (new repo, Docker image — wraps Appian OOTB APIs) |
| Deployment | Appian Deployment MCP (github.com/kelseymross/appian-deployment-mcp) |
| Test data | Data Generator MCP (existing Docker image) |
| Orchestration | Kiro agents + powers (new configs) |
| Bootstrap | setup.sh (new, following buildwithclaude pattern) |

---

## 2. Repository Structure

```
solutions-copilot/
├── .kiro/
│   ├── agents/                          # Orchestrator + sub-agents
│   │   ├── solutions-copilot.json      # Default orchestrator
│   │   ├── developer.json              # Engineering specialist
│   │   ├── product-owner.json          # Product specialist
│   │   ├── ux-designer.json            # UX specialist
│   │   ├── sql-forge.json              # Data/SQL specialist
│   │   ├── qe-agent.json              # QE/Test specialist
│   │   ├── code-reviewer.json         # Code review specialist
│   │   └── a11y-fixer.json            # Accessibility specialist
│   ├── skills/                          # Shared reference knowledge
│   │   ├── sail-reference/
│   │   │   └── SKILL.md
│   │   ├── appian-best-practices/
│   │   │   └── SKILL.md
│   │   ├── aurora-design-system/
│   │   │   └── SKILL.md
│   │   ├── a11y-audit/
│   │   │   └── SKILL.md
│   │   └── appian-patterns/
│   │       └── SKILL.md
│   ├── steering/                        # Global directives
│   │   ├── git-workflow.md
│   │   ├── naming-conventions.md
│   │   └── code-standards.md
│   └── settings/
│       └── mcp.json                     # NOT used (setup.sh writes to global)
│
│   ├── developer/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── code-exploration.md
│   │       ├── design-doc-workflow.md
│   │       ├── implementation-workflow.md
│   │       ├── spike-research-workflow.md
│   │       ├── feature-breakdown-workflow.md
│   │       ├── refactor-redeploy-workflow.md
│   │       ├── expression-test-generation.md
│   │       └── pipeline-check-workflow.md
│   ├── sql-forge/
│   │   ├── POWER.md
│   │   └── steering/
│   │       └── data-generation-workflow.md
│   ├── ux-designer/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── prototype-workflow.md
│   │       └── aurora-compliance.md
│   ├── product-owner/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── feature-spec-workflow.md
│   │       ├── release-summary-workflow.md
│   │       └── branding-compliance.md
│   ├── qe-agent/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── test-execution-workflow.md
│   │       └── verify-workflow.md          ← from verify
│   ├── code-reviewer/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── review-checklist.md
│   │       └── code-review-workflow.md     ← from live-plane
│   ├── a11y-fixer/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── fix-patterns.md             ← from a11y-fixer
│   │       ├── fixer-workflow.md
│   │       ├── verification.md
│   │       ├── xml-rules.md
│   │       └── playwright-helper.md
│   ├── doc-genie/                          ← from feature-docgenie power
│   │   ├── POWER.md
│   │   ├── steering/
│   │   │   ├── workflow-fip.md
│   │   │   ├── workflow-tech-design.md
│   │   │   ├── workflow-perf-review.md
│   │   │   ├── workflow-security-review.md
│   │   │   ├── workflow-arch-overview.md
│   │   │   └── workflow-adr.md
│   │   ├── templates/
│   │   │   ├── fip.md
│   │   │   ├── tech-design.md
│   │   │   ├── perf-review.md
│   │   │   ├── security-review.md
│   │   │   ├── arch-overview.md
│   │   │   ├── adr.md
│   │   │   └── docx/              ← 7 DOCX templates
│   │   ├── styles/
│   │   │   └── document.css
│   │   └── scripts/
│   │       └── fix_table_borders.py
│   ├── i18n/                               ← from i18n
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── i18n-audit-workflow.md
│   │       ├── i18n-create-workflow.md
│   │       ├── i18n-lookup-workflow.md
│   │       └── i18n-reference.md
│   └── db-admin/                           ← from db-admin
│       ├── POWER.md
│       └── steering/
│           ├── db-explore-workflow.md
│           ├── db-config-workflow.md
│           ├── db-script-workflow.md
│           ├── db-admin-workflow.md
│           └── smt-reference.md
│
├── src/                                 # The lcp-api MCP server (new)
│   └── lcp_mcp_server/
│       ├── __init__.py
│       ├── __main__.py                  # Entry point
│       ├── server.py                    # FastMCP server + tool registration
│       ├── config.py                    # Env-based configuration
│       ├── client.py                    # HTTP client (Basic Auth → /suite/webapi/lcp-api/*)
│       └── tools/
│           ├── __init__.py
│           ├── applications.py          # listApps, getApp, createApp
│           ├── record_types.py          # CRUD record types, fields, relationships
│           ├── interfaces.py            # CRUD interfaces
│           ├── expression_rules.py      # CRUD expression rules
│           ├── process_models.py        # CRUD process models
│           ├── constants.py             # CRUD constants
│           ├── groups.py                # CRUD groups
│           └── objects.py               # Generic object operations
│
├── products/                            # T.I.M.E. lifecycle (example product)
│   └── example-product/
│       ├── README.md
│       ├── steering/
│       │   └── steering.md
│       ├── 00-context/
│       ├── 01-discovery/
│       ├── 02-refinement/
│       ├── 03-planning/
│       ├── 04-delivery/
│       └── 05-shipped/
│
├── orchestrator/                        # Orchestrator configuration
│   ├── prompt.md
│   ├── capabilities.md
│   └── routing-rules.md
│
├── configurator/                        # Local setup configurator (HTML page)
│   └── index.html                       # Interactive UI for selecting components
│
├── solutions-copilot.manifest.json      # Declarative registry of all components
├── setup.sh                             # One-command bootstrap
├── verify                               # Credential smoke test
├── .env.example                         # Credential template
├── .gitignore
└── README.md
```

### Separate Repository: solutions-lcp-mcp-server

The LCP API MCP server is our own build — a thin HTTP client wrapping Appian's OOTB `/suite/webapi/lcp-api/*` endpoint. Workflows and power content from Saurabh's `lcp-api` repo are migrated into solutions-copilot as steering files.

See **Section 4** for full design.

---

## 3. Implementation Phases

### Phase 1: Foundation (Days 1-2)

**Goal:** Repo scaffolded, lcp-api MCP server working, setup.sh functional.

#### 3.1.1 Repository Setup

**Two repos to create:**

1. **`solutions-copilot`** — the platform repo (powers, skills, agents, products, setup.sh, configurator)
2. **`solutions-lcp-mcp-server`** — the LCP API MCP server (Docker image wrapping Appian OOTB APIs)

For `solutions-copilot`:
- [ ] Create repo on GitLab
- [ ] Initialize with `.gitignore`, `README.md`
- [ ] Create directory structure as defined in Section 2

For `solutions-lcp-mcp-server`:
- [ ] Create repo on GitLab
- [ ] Initialize with `pyproject.toml`, `Dockerfile`, `.gitlab-ci.yml`
  ```toml
  [project]
  name = "solutions-lcp-mcp-server"
  requires-python = ">=3.11"
  dependencies = ["fastmcp>=2.0.0", "httpx>=0.27.0", "pydantic>=2.0.0", "pydantic-settings>=2.0.0"]
  ```
- [ ] Create `src/lcp_mcp_server/` with client + tools (see Section 4)
- [ ] Create CI pipeline that builds + pushes Docker image
- [ ] Run `uv lock` to generate lockfile

#### 3.1.2 LCP API MCP Server

Build a thin MCP server that translates tool calls → HTTP requests to `/suite/webapi/lcp-api/*`.

**Architecture:**

```python
# src/lcp_mcp_server/config.py
class LCPConfig(BaseSettings):
    lcp_url: str                    # e.g., https://mysite.appiancloud.com
    lcp_username: str               # Basic Auth username
    lcp_password: str               # Basic Auth password
    lcp_api_path: str = "/suite/webapi/lcp-api"

# src/lcp_mcp_server/client.py
class LCPClient:
    """HTTP client that hits /suite/webapi/lcp-api/* with Basic Auth."""
    async def get(self, path: str, params: dict = None) -> dict
    async def post(self, path: str, body: dict) -> dict
    async def put(self, path: str, body: dict) -> dict
    async def delete(self, path: str) -> dict

# src/lcp_mcp_server/server.py
mcp = FastMCP("lcp-api")

# Tools registered per domain:
# applications.py → listApplications, getApplication, createApplication
# record_types.py → listRecordTypes, getRecordType, createRecordType, updateRecordType
# interfaces.py → listInterfaces, getInterface, createInterface, updateInterface
# expression_rules.py → listExpressionRules, getExpressionRule, createExpressionRule
# process_models.py → listProcessModels, getProcessModel
# constants.py → listConstants, getConstant, createConstant
# groups.py → listGroups, getGroup, createGroup
# objects.py → searchObjects, getObject, getObjectDependencies
```

**Tools to implement (MVP — most critical for SWAT project workflows):**

| Tool | Method | Path | Purpose |
|------|--------|------|---------|
| `listApplications` | GET | `/applications` | List all apps |
| `getApplication` | GET | `/applications/{uuid}` | Get app details |
| `createApplication` | POST | `/applications` | Create new app |
| `listRecordTypes` | GET | `/applications/{uuid}/record-types` | List record types in app |
| `getRecordType` | GET | `/record-types/{uuid}` | Get record type details |
| `createRecordType` | POST | `/record-types` | Create record type |
| `updateRecordType` | PUT | `/record-types/{uuid}` | Update record type |
| `getInterface` | GET | `/interfaces/{uuid}` | Get interface SAIL code |
| `createInterface` | POST | `/interfaces` | Create interface |
| `updateInterface` | PUT | `/interfaces/{uuid}` | Update interface |
| `getExpressionRule` | GET | `/expression-rules/{uuid}` | Get expression rule |
| `createExpressionRule` | POST | `/expression-rules` | Create expression rule |
| `createConstant` | POST | `/constants` | Create constant |
| `searchObjects` | GET | `/objects?query=` | Search all objects |
| `getObjectDependencies` | GET | `/objects/{uuid}/dependencies` | Get deps |
| `evaluateExpression` | POST | `/expressions/evaluate` | Test expressions |

#### 3.1.3 Configuration & Credentials

- [ ] Create `.env.example`:
  ```bash
  # Solutions Intelligence (Solutions Cloud Plane)
  GITLAB_TOKEN=
  SOLUTIONS_KB_PROJECT_ID=13490
  SOLUTIONS_DATA_PREFIX=solutions-kb/data

  # LCP API (Object CRUD)
  LCP_URL=https://your-site.appiancloud.com
  LCP_USERNAME=
  LCP_PASSWORD=

  # Data Generator
  DATA_GEN_ENV_URL=
  DATA_GEN_API_KEY=

  # Jira
  JIRA_URL=https://appian-eng.atlassian.net
  JIRA_EMAIL=
  JIRA_TOKEN=
  ```

#### 3.1.4 Verify Script

- [ ] Create `verify` script that tests all configured credentials:
  - Hits GitLab API with GITLAB_TOKEN
  - Hits LCP API with Basic Auth (`GET /applications?limit=1`)
  - Hits Data Generator endpoint
  - Reports pass/fail per service

#### 3.1.5 Setup Script

- [ ] Create `setup.sh` following buildwithclaude pattern:

  ```bash
  #!/bin/bash
  set -e
  # 1. Preflight: Python 3.11+, uv, docker
  # 2. Create .env from .env.example if missing
  # 3. Install Python dependencies (uv sync)
  # 4. Pull Docker images (intelligence, data-gen, jira, playwright)
  # 5. Write MCP config to ~/.kiro/settings/mcp.json
  # 6. Symlink powers into ~/.kiro/powers/installed/
  # 7. Update ~/.kiro/powers/installed.json
  # 8. Symlink skills into ~/.kiro/skills/
  # 9. Symlink agents into ~/.kiro/agents/
  # 10. Symlink steering into ~/.kiro/steering/
  # 11. Run verify
  ```

- [ ] MCP config generated by setup.sh:
  ```json
  {
    "mcpServers": {
      "solutions-intelligence": {
        "command": "docker",
        "args": ["run", "--rm", "-i", "--env", "GITLAB_TOKEN", "--env", "SOLUTIONS_KB_PROJECT_ID", "--env", "SOLUTIONS_DATA_PREFIX",
          "registry.gitlab.appian-stratus.com/appian/prod/solutions-solutions-intelligence-mcp-server/solutions-solutions-intelligence-mcp-server:latest"],
        "env": { "GITLAB_TOKEN": "<from .env>", "SOLUTIONS_KB_PROJECT_ID": "13490", "SOLUTIONS_DATA_PREFIX": "..." },
        "autoApprove": ["*"]
      },
      "lcp-api": {
        "command": "docker",
        "args": ["run", "--rm", "-i", "--env", "LCP_URL", "--env", "LCP_USERNAME", "--env", "LCP_PASSWORD",
          "registry.gitlab.appian-stratus.com/appian/prod/solutions-lcp-mcp-server:latest"],
        "env": { "LCP_URL": "<from .env>", "LCP_USERNAME": "<from .env>", "LCP_PASSWORD": "<from .env>" },
        "autoApprove": ["*"]
      },
      "data-generator": {
        "command": "docker",
        "args": ["run", "--rm", "-i", "--env", "APPIAN_ENV_URL", "--env", "APPIAN_API_KEY",
          "registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-data-generator-server:latest"],
        "env": { "APPIAN_ENV_URL": "<from .env>", "APPIAN_API_KEY": "<from .env>" },
        "autoApprove": ["*"]
      },
      "jira": {
        "command": "docker",
        "args": ["run", "--rm", "-i", "--env", "JIRA_EMAIL", "--env", "JIRA_TOKEN", "--env", "JIRA_URL",
          "registry.gitlab.appian-stratus.com/appian/prod/jira-mcp-proxy/jira-mcp-proxy:latest"],
        "env": { "JIRA_URL": "<from .env>", "JIRA_EMAIL": "<from .env>", "JIRA_TOKEN": "<from .env>" },
        "autoApprove": ["get_jira_issue", "search_jira_issues", "get_issue_comments"]
      },
      "playwright": {
        "command": "npx",
        "args": ["@playwright/mcp@latest"],
        "autoApprove": ["browser_navigate", "browser_snapshot", "browser_click", "browser_type"]
      }
    }
  }
  ```

---

### Phase 2: Orchestrator & Sub-Agents (Days 3-4)

**Goal:** Orchestrator routes to specialist agents. Powers activate correctly.

#### 3.2.1 Orchestrator Agent

- [ ] Create `.kiro/agents/solutions-copilot.json`:
  ```json
  {
    "name": "solutions-copilot",
    "description": "Solutions Copilot — unified AI assistant for Appian development",
    "prompt": "file://./orchestrator/prompt.md",
    "tools": ["*", "subagent"],
    "toolsSettings": {
      "subagent": {
        "availableAgents": ["developer", "product-owner", "ux-designer", "sql-forge", "qe-agent", "code-reviewer", "a11y-fixer"]
      }
    },
    "resources": [
      "file://./README.md",
      "file://./orchestrator/capabilities.md",
      "file://./orchestrator/routing-rules.md"
    ],
    "model": "claude-sonnet-4",
    "welcomeMessage": "Solutions Copilot ready. I have access to all Appian applications, product knowledge, and development tools. What are you working on?"
  }
  ```

- [ ] Create `orchestrator/prompt.md` — system prompt with:
  - Overview of available capabilities
  - Routing rules (when to handle directly vs delegate)
  - Tool usage guidance (which MCP server for which verb)
  
- [ ] Create `orchestrator/capabilities.md` — machine-readable manifest
- [ ] Create `orchestrator/routing-rules.md` — classification signals

#### 3.2.2 Sub-Agent Definitions

Each sub-agent gets a JSON config + prompt file:

- [ ] `developer.json` + `developer-prompt.md`
  - Capabilities: code exploration, impact analysis, design docs, implementation
  - Tools: solutions-intelligence (read), lcp-api (write), jira
  
- [ ] `product-owner.json` + `product-owner-prompt.md`
  - Capabilities: feature specs, release summaries, onboarding
  - Tools: solutions-intelligence (read), jira
  
- [ ] `ux-designer.json` + `ux-designer-prompt.md`
  - Capabilities: prototypes, Aurora compliance, SAIL generation
  - Tools: solutions-intelligence (read), lcp-api (write)
  
- [ ] `sql-forge.json` + `sql-forge-prompt.md`
  - Capabilities: test data, ERDs, SAIL-to-SQL
  - Tools: solutions-intelligence (read), data-generator, lcp-api (write)
  
- [ ] `qe-agent.json` + `qe-agent-prompt.md`
  - Capabilities: test execution, verification, a11y auditing
  - Tools: solutions-intelligence (read), playwright, jira
  
- [ ] `code-reviewer.json` + `code-reviewer-prompt.md`
  - Capabilities: package review, best practices, checklist
  - Tools: solutions-intelligence (read)
  
- [ ] `a11y-fixer.json` + `a11y-fixer-prompt.md`
  - Capabilities: automated a11y fixes, 56 fix patterns
  - Tools: solutions-intelligence (read), lcp-api (write), playwright, jira

#### 3.2.3 Powers (Lightweight)

Each power folder contains ONLY:
- `POWER.md` — activation trigger + description (YAML frontmatter)
- `steering/` — workflow instructions referencing tools by name

No `mcp.json` anywhere. Example:

```markdown
---
name: "developer"
description: "Explore Appian applications, analyze code, generate design documents, review packages, and implement features. Use when working on engineering tasks."
---

## Available Tools

You have access to:
- **solutions-intelligence** MCP: get_app_overview, search_objects, get_object_code, get_dependencies, get_impact_analysis, compare_releases
- **lcp-api** MCP: createInterface, updateInterface, createRecordType, createConstant
- **jira** MCP: get_jira_issue, search_jira_issues

## Workflows

See steering files for detailed workflows:
- Code exploration: steering/code-exploration.md
- Design documents: steering/design-doc-workflow.md
- Implementation: steering/implementation-workflow.md
```

---

### Phase 3: Skills & Steering (Days 4-5)

**Goal:** Shared knowledge accessible to all agents.

#### 3.3.1 Skills

- [ ] `sail-reference/SKILL.md` — SAIL component catalog, patterns, common functions
  - Source: buildwithclaude's `skills/appian-sail/` + references
- [ ] `appian-best-practices/SKILL.md` — naming conventions, field types, architecture
  - Source: buildwithclaude's `skills/appian-record-types/`, `appian-data-modeling/`
- [ ] `aurora-design-system/SKILL.md` — Aurora components, styling, accessibility
  - Source: existing ux-designer power steering
- [ ] `a11y-audit/SKILL.md` — 80+ a11y rules, recursive interface discovery
  - Source: SWAT project #2 (Ganesh)
- [ ] `appian-patterns/SKILL.md` — common Appian patterns (CRUD, approval, intake)
  - Source: compiled from existing power steerings

#### 3.3.2 Steering Files

- [ ] `git-workflow.md` — commit conventions, branch naming, PR structure
- [ ] `naming-conventions.md` — Solutions OS naming rules (no legacy codenames)
- [ ] `code-standards.md` — coding guidelines for powers, skills, steering

---

### Phase 4: Manifest & Platform Agnosticism (Day 5)

**Goal:** Declarative manifest drives setup. Architecture is platform-independent.

#### 3.4.1 Manifest File

- [ ] Create `solutions-copilot.manifest.json`:
  ```json
  {
    "version": "1.0.0",
    "description": "Solutions Copilot — modular MCP configuration manifest",
    "infrastructure": {
      "mcpServers": {
        "solutions-intelligence": { "type": "docker", "image": "...", "env_keys": ["GITLAB_TOKEN", "SOLUTIONS_KB_PROJECT_ID"] },
        "lcp-api": { "type": "docker", "image": "registry.gitlab.appian-stratus.com/appian/prod/solutions-lcp-mcp-server:latest", "env_keys": ["LCP_URL", "LCP_USERNAME", "LCP_PASSWORD"] },
        "data-generator": { "type": "docker", "image": "...", "env_keys": ["DATA_GEN_ENV_URL", "DATA_GEN_API_KEY"] },
        "jira": { "type": "docker", "image": "...", "env_keys": ["JIRA_URL", "JIRA_EMAIL", "JIRA_TOKEN"] },
        "playwright": { "type": "npx", "package": "@playwright/mcp@latest" }
      }
    },
    "knowledge": {
      "powers": [
        { "name": "developer", "path": "powers/developer" },
        { "name": "sql-forge", "path": "powers/sql-forge" },
        { "name": "ux-designer", "path": "powers/ux-designer" },
        { "name": "product-owner", "path": "powers/product-owner" },
        { "name": "qe-agent", "path": "powers/qe-agent" },
        { "name": "code-reviewer", "path": "powers/code-reviewer" },
        { "name": "a11y-fixer", "path": "powers/a11y-fixer" },
        { "name": "doc-genie", "path": "powers/doc-genie" },
        { "name": "i18n", "path": "powers/i18n" },
        { "name": "db-admin", "path": "powers/db-admin" }
      ],
      "skills": [
        { "name": "sail-reference", "path": ".kiro/skills/sail-reference" },
        { "name": "appian-best-practices", "path": ".kiro/skills/appian-best-practices" },
        { "name": "aurora-design-system", "path": ".kiro/skills/aurora-design-system" },
        { "name": "a11y-audit", "path": ".kiro/skills/a11y-audit" },
        { "name": "appian-patterns", "path": ".kiro/skills/appian-patterns" }
      ],
      "agents": [
        { "name": "solutions-copilot", "path": ".kiro/agents/solutions-copilot.json" }
      ],
      "steering": [
        { "name": "git-workflow", "path": ".kiro/steering/git-workflow.md" },
        { "name": "naming-conventions", "path": ".kiro/steering/naming-conventions.md" }
      ]
    },
    "profiles": {
      "full": { "powers": "*", "skills": "*" },
      "engineering": { "powers": ["developer", "sql-forge", "code-reviewer", "a11y-fixer"], "skills": ["sail-reference", "appian-best-practices"] },
      "product": { "powers": ["product-owner", "ux-designer"], "skills": ["aurora-design-system"] }
    }
  }
  ```

#### 3.4.2 Setup Configurator (Interactive HTML Page)

A local HTML page (`configurator/index.html`) that reads `solutions-copilot.manifest.json` and lets users visually select what to install.

**How it works:**
1. User opens `configurator/index.html` in their browser (local file, no server needed)
2. Page reads the manifest JSON (embedded or fetched via relative path)
3. Shows all available powers, skills, agents with descriptions and dependencies
4. User checks what they want
5. Page generates a `user-config.json` and/or the exact shell command
6. User runs `./setup.sh` which reads `user-config.json` for selections

**UI Layout:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Solutions Copilot — Setup Configurator                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ⚡ MCP Servers (Infrastructure — always installed)              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ ✓ solutions-intelligence  │ Application knowledge        │   │
│  │ ✓ lcp-api                 │ Object CRUD                  │   │
│  │ ✓ data-generator          │ Test data                    │   │
│  │ ✓ playwright              │ Browser automation           │   │
│  │ ○ jira (optional)         │ Issue tracking               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  🔧 Powers (select what you need)                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ ☑ developer        │ Code exploration, design docs, impl │   │
│  │ ☑ sql-forge        │ Test data, ERDs, SAIL-to-SQL        │   │
│  │ ☐ ux-designer      │ Prototypes, Aurora compliance       │   │
│  │ ☐ product-owner    │ Feature specs, release summaries    │   │
│  │ ☑ code-reviewer    │ Package review, best practices      │   │
│  │ ☐ a11y-fixer       │ Automated accessibility fixes       │   │
│  │ ☐ doc-genie        │ Full document generation (6 types)  │   │
│  │ ☐ i18n             │ Internationalization workflows      │   │
│  │ ☐ db-admin         │ Database admin & management         │   │
│  │ ☐ qe-agent         │ Test execution & verification       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  📚 Skills (shared knowledge — auto-selected based on powers)   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ ✓ sail-reference         │ needed by: developer, ux      │   │
│  │ ✓ appian-best-practices  │ needed by: developer, reviewer│   │
│  │ ○ aurora-design-system   │ needed by: ux-designer        │   │
│  │ ○ a11y-audit             │ needed by: a11y-fixer, qe     │   │
│  │ ○ appian-patterns        │ needed by: all                │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Quick Profiles: [Engineering] [Product] [QE] [Full] [Minimal]  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  ./setup.sh --config user-config.json                     │   │
│  │                                                           │   │
│  │  [Copy Command]  [Download user-config.json]  [Install]   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Preset profile buttons (one click selects a sensible group)
- Dependency indicators (selecting a11y-fixer auto-selects a11y-audit skill)
- MCP server requirements shown per power (so users know what creds they need)
- Generates `user-config.json`:
  ```json
  {
    "powers": ["developer", "sql-forge", "code-reviewer"],
    "skills": ["sail-reference", "appian-best-practices"],
    "mcpServers": ["solutions-intelligence", "lcp-api", "data-generator", "playwright"]
  }
  ```
- `setup.sh` reads this file if present, otherwise installs all (full profile)

**Implementation:** Single self-contained HTML file (no build step, no dependencies). Reads manifest via `fetch('./solutions-copilot.manifest.json')`. Pure vanilla JS.

#### 3.4.3 Setup Script Reads Manifest

- [ ] Update `setup.sh` to read `solutions-copilot.manifest.json` for:
  - Which MCP servers to configure
  - Which powers/skills/agents/steering to symlink
  - Profile-based selective install (`--profile engineering`)

---

### Phase 5: T.I.M.E. Structure & Products (Day 6)

**Goal:** Migrate existing product folders into T.I.M.E. lifecycle structure.

#### Existing Products to Migrate (from solutions-os main)

| Product | Type | Current Structure |
|---------|------|-------------------|
| `gam-solutions/` | Suite (parent) | domain/, steering/, solutions/ (contains child products) |
| `case-management-studio/` | Standalone | arch-decision-logs/, competitive-analysis/, domain/, features/, src-appian-packages/ |
| `procuresight/` | Standalone | arch-decision-logs/, competitive-analysis/, domain/, features/, src-appian-packages/ |
| `synapse/` | Standalone | (similar structure) |
| `doccenter/` | Standalone | (similar structure) |
| `insurance-underwriting/` | Standalone | (similar structure) |

#### GAM Suite Children (nested under gam-solutions/solutions/)

- contract-writing
- procuresight-enterprise
- source-selection
- vendor-management
- (others)

#### Migration Tasks

- [ ] Create `products/` directory with T.I.M.E. lifecycle folders
- [ ] Migrate at least one product (e.g., case-management-studio) to full T.I.M.E. structure as example
- [ ] Map existing content: `domain/` → `00-context/`, `features/` → `02-refinement/` or `03-planning/`, `arch-decision-logs/` → `00-context/architecture/`
- [ ] Preserve `src-appian-packages/` at product root (not lifecycle-bound)
- [ ] Preserve suite inheritance (GAM → child solutions)
- [ ] Verify orchestrator can search product knowledge

---

### Phase 6: Integration Testing (Days 6-7)

**Goal:** End-to-end verification that everything works together.

#### Test Scenarios

| Scenario | What it tests |
|----------|--------------|
| "List applications on my environment" | Intelligence Server (Cloud Plane) responding |
| "Create a constant called MY_CONST" | lcp-api MCP server writing to Appian |
| "What changed in the last release of GSS?" | Cloud Plane release comparison |
| "Generate test data for evaluations" | Data Generator MCP |
| "Create a design doc for GAMS-7126" | Orchestrator → developer agent delegation |
| "Fix accessibility on this interface" | Orchestrator → a11y-fixer delegation |
| New user runs `./setup.sh` | Full bootstrap on clean machine |
| `./setup.sh --uninstall` | Clean removal of all symlinks/configs |

#### Verification Checklist

- [ ] All MCP servers start and respond
- [ ] Orchestrator routes correctly (direct vs delegation)
- [ ] Powers activate and reference correct tools
- [ ] Skills load on demand based on description
- [ ] `setup.sh` is idempotent (run 3x, same result)
- [ ] `setup.sh --profile engineering` installs subset
- [ ] `verify` reports all services healthy
- [ ] Agents can compose workflows across multiple MCP servers

---

## 4. LCP MCP Server — Our Build

We build our own MCP server that wraps `src/appian_lcp/` (from Saurabh's repo) as the foundation, then own the MCP layer and Docker image independently.

### 4.1 Repository: solutions-lcp-mcp-server

```
solutions-lcp-mcp-server/
├── src/
│   └── lcp_mcp_server/
│       ├── __init__.py
│       ├── __main__.py              # Entry point (stdio)
│       ├── server.py                # FastMCP server + tool registration
│       ├── config.py                # Env-based configuration (LCP_URL, username, password)
│       ├── client.py                # httpx client (Basic Auth → /suite/webapi/lcp-api/*)
│       └── tools/
│           ├── __init__.py
│           ├── applications.py      # list, get, create
│           ├── record_types.py      # CRUD + fields + relationships
│           ├── interfaces.py        # CRUD
│           ├── expression_rules.py  # CRUD
│           ├── process_models.py    # CRUD
│           ├── constants.py         # CRUD
│           ├── groups.py            # CRUD
│           ├── folders.py           # CRUD
│           ├── documents.py         # CRUD
│           ├── objects.py           # search, get, dependencies
│           └── expressions.py       # evaluate, test
├── Dockerfile
├── .gitlab-ci.yml                   # Build + push to registry
├── pyproject.toml
├── uv.lock
├── tests/
└── README.md
```

**Docker image:** `registry.gitlab.appian-stratus.com/appian/prod/solutions-lcp-mcp-server:latest`

### 4.2 Design

The server is simple — a thin HTTP client that forwards tool calls to `/suite/webapi/lcp-api/*` with Basic Auth. The Appian plugin handles all routing internally.

```python
# client.py — the entire client is ~30 lines
class LCPClient:
    def __init__(self, base_url: str, username: str, password: str):
        self.client = httpx.AsyncClient(
            base_url=f"{base_url}/suite/webapi/lcp-api",
            auth=httpx.BasicAuth(username, password),
            timeout=httpx.Timeout(60.0),
        )

    async def get(self, path: str, **params) -> dict: ...
    async def post(self, path: str, json: dict) -> dict: ...
    async def put(self, path: str, json: dict) -> dict: ...
```

```python
# tools/applications.py — each tool is 5-10 lines
@mcp.tool()
async def listApplications(query: str | None = None, limit: int = 50) -> dict:
    """List Appian applications."""
    return await client.get("/applications", query=query, limit=limit)

@mcp.tool()
async def createApplication(name: str, prefix: str | None = None) -> dict:
    """Create a new Appian application."""
    return await client.post("/applications", json={"name": name, "prefix": prefix})
```

### 4.3 Tools to Implement (prioritized)

**P0 — Required for POC:**

| Tool | Method | Path |
|------|--------|------|
| `listApplications` | GET | `/applications` |
| `getApplication` | GET | `/applications/{uuid}` |
| `createApplication` | POST | `/applications` |
| `listRecordTypes` | GET | `/applications/{uuid}/record-types` |
| `getRecordType` | GET | `/record-types/{uuid}` |
| `createRecordType` | POST | `/record-types` |
| `updateRecordType` | PUT | `/record-types/{uuid}` |
| `getInterface` | GET | `/interfaces/{uuid}` |
| `createInterface` | POST | `/interfaces` |
| `updateInterface` | PUT | `/interfaces/{uuid}` |
| `getExpressionRule` | GET | `/expression-rules/{uuid}` |
| `createExpressionRule` | POST | `/expression-rules` |
| `createConstant` | POST | `/constants` |
| `searchObjects` | GET | `/objects?query=` |
| `getObjectDependencies` | GET | `/objects/{uuid}/dependencies` |
| `evaluateExpression` | POST | `/expressions/evaluate` |

**P1 — After POC:**

| Tool | Method | Path |
|------|--------|------|
| `listInterfaces` | GET | `/applications/{uuid}/interfaces` |
| `listExpressionRules` | GET | `/applications/{uuid}/expression-rules` |
| `getProcessModel` | GET | `/process-models/{uuid}` |
| `listConstants` | GET | `/applications/{uuid}/constants` |
| `createGroup` | POST | `/groups` |
| `listGroups` | GET | `/groups` |
| `createFolder` | POST | `/folders` |
| `getDocument` | GET | `/documents/{uuid}` |
| `querySql` | POST | `/sql/query` |

### 4.4 Migration from saurabh.sabat/lcp-api into solutions-copilot

Content from Saurabh's repo that becomes powers/skills/steering:

| Source (lcp-api repo) | Target (solutions-copilot) | Form |
|----------------------|---------------------------|------|
| `workflows/data_model/` (parse sheet, validate, gen SQL, create from manifest) | `powers/sql-forge/steering/data-model-from-sheet-workflow.md` | Steering — agent follows steps using MCP tools |
| `workflows/bulk_rename/` (discover, plan, execute, report) | `powers/developer/steering/bulk-rename-workflow.md` | Steering — agent follows steps |
| `powers/appian-data-model-workflow/POWER.md` | Merge into `powers/sql-forge/POWER.md` | Power trigger |
| `powers/appian-bulk-rename-workflow/POWER.md` | Merge into `powers/developer/POWER.md` | Power trigger |
| `docs/known-issues.yaml` | `.kiro/skills/appian-known-issues/SKILL.md` | Skill — queryable by all agents |
| `data/type_manifest.json` | `.kiro/skills/appian-best-practices/references/type-manifest.json` | Reference data |
| `scripts/capture.py` pattern | Inform error handling in orchestrator prompt | Design pattern |
| Profile concept (`profiles.yaml`) | `.env` multi-profile support in setup.sh | Architecture |

**Key insight:** The workflows in Saurabh's repo are Python scripts that run sequentially. In solutions-copilot, they become **steering files** — markdown that tells the agent the step-by-step process. The agent uses the individual MCP tools at each step. This means:
- The workflow is AI-driven (can adapt, ask questions, handle errors intelligently)
- No Python pipeline to maintain — just markdown instructions
- New steps can be added by editing steering, not by writing code

---

## 5. Orchestrator Design

### 5.1 Routing Rules

```markdown
# orchestrator/routing-rules.md

## Direct handling (orchestrator answers directly)
- Simple questions about applications (uses solutions-intelligence)
- Object search across apps
- Release history and changelogs
- Schema and relationship queries

## Delegation signals
| Signal | Delegate to |
|--------|-------------|
| "review", "code review", package URL | code-reviewer |
| "design doc", "spike", "implement", "build" | developer |
| "feature spec", "release summary", "onboard" | product-owner |
| "prototype", "HTML", "SAIL UI", "Aurora" | ux-designer |
| "test data", "bulk data", "ERD", "SQL" | sql-forge |
| "verify", "test", "execute test" | qe-agent |
| "fix accessibility", "a11y" | a11y-fixer |

## Disambiguation strategy

Signals above are hints, not hard rules. When a request is ambiguous:

### Step 1: Gather context before routing
If the request could match multiple agents, use solutions-intelligence to inspect the object first. The object type and state often resolve ambiguity:
- "Help me fix this interface" + interface has a11y violations → a11y-fixer
- "Help me fix this interface" + interface has a bug → developer
- "Help me fix this interface" + interface needs UX rework → ux-designer

### Step 2: Ask when genuinely ambiguous
If context doesn't resolve it, ask the user ONE clarifying question:
- "I can help with that. Are you looking to fix an accessibility issue, debug a functional problem, or redesign the layout?"
- Never ask more than one clarifying question. If still unclear after one, default to developer (broadest capability).

### Step 3: Fallback chain
When no signal matches or the user's request is vague:
1. Try to handle directly (orchestrator uses intelligence tools)
2. If it requires code changes → developer
3. If developer fails or reports it's out of scope → ask user to clarify

### Step 4: Mid-workflow rerouting
If a delegated agent discovers the task belongs elsewhere:
- Agent returns a summary + recommendation: "This is actually an a11y issue, not a logic bug. Recommend delegating to a11y-fixer."
- Orchestrator confirms with user, then reroutes

### Common ambiguous cases

| Request | Possible agents | Resolution strategy |
|---------|----------------|-------------------|
| "Help me fix this interface" | developer, a11y-fixer, ux-designer | Inspect object first — check for a11y violations, then ask |
| "Update this record type" | developer, sql-forge | If adding fields → developer. If generating test data → sql-forge |
| "Make this better" | any | Ask: "Better how? Performance, UX, accessibility, or functionality?" |
| "Deploy and verify" | developer, qe-agent | Split: developer handles deploy prep, qe-agent handles verification |
| "Create a report" | product-owner, sql-forge, doc-genie | Ask: "A data report, a feature spec, or a technical document?" |
```

### 5.2 Tool Routing (Which MCP for What)

```markdown
# orchestrator/prompt.md (excerpt)

## Tool routing — which MCP server to use

- **Understand** something → `solutions-intelligence` (get_app_overview, search_objects, get_dependencies, etc.)
- **Create/modify** an object → `lcp-api` (createRecordType, updateInterface, createConstant, etc.)
- **Generate test data** → `data-generator` (create_record, get_record_properties, etc.)
- **Track work** → `jira` (get_jira_issue, search_jira_issues, etc.)
- **Test in browser** → `playwright` (browser_navigate, browser_click, etc.)

Never use lcp-api for reading — use solutions-intelligence.
Never use solutions-intelligence for writing — use lcp-api.
```

---

## 6. SWAT Project Integration Map + All Existing Powers

### How Each Project/Power Fits

| # | Project/Power | Solutions Copilot Power | Skills Used | MCP Servers Used |
|---|---------|-------------|-------------|-----------------|
| 1 | A11Y Fixer | a11y-fixer | a11y-audit | lcp-api, playwright, jira |
| 2 | AI A11y Audit | (skill: a11y-audit) | a11y-audit | solutions-intelligence |
| 3 | SQL Forge | sql-forge | appian-best-practices | solutions-intelligence, data-generator |
| 4 | DataForge | sql-forge | — | solutions-intelligence, data-generator |
| 5 | Flow-Craft Sprint | (standalone script) | — | jira |
| 6 | UX Enhancements | ux-designer | aurora-design-system | solutions-intelligence |
| 7 | Kiro→FigJam | ux-designer | — | solutions-intelligence |
| 8 | Spec to Slides | product-owner | — | solutions-intelligence |
| 9 | SAIL Canvas | ux-designer | sail-reference | solutions-intelligence, lcp-api |
| 10 | Sweep | developer | — | solutions-intelligence, lcp-api |
| 11 | Perf-Profiler | developer | — | (CLI tool, shell invocation) |
| 12 | Local-IDE | (standalone) | — | lcp-api |
| 13 | LCP/a!migo | (IS the lcp-api server) | — | — |
| 14 | SAIL-to-SQL | sql-forge | sail-reference | solutions-intelligence, lcp-api |
| 15 | Feature Doc Genie | doc-genie | — | solutions-intelligence |
| 16 | ERD Gen | sql-forge | — | solutions-intelligence |
| 17 | KB Maintenance | (skill + hook) | kb-maintenance | solutions-intelligence |
| 18 | T.I.M.E. Framework | (core structure) | — | — |
| 19 | Test Execution Agent | qe-agent | — | solutions-intelligence, playwright, jira |
| 20 | Expression Assert | developer | — | solutions-intelligence, lcp-api |
| — | i18n | i18n | — | solutions-intelligence, lcp-api |
| — | DB Admin (SMT) | db-admin | — | solutions-intelligence, lcp-api |
| — | Verify | qe-agent (merged) | — | solutions-intelligence, playwright |
| — | Demo Driver | sql-forge (merged) | — | solutions-intelligence, data-generator |
| — | code-review | code-reviewer | appian-best-practices | solutions-intelligence |
| — | design-doc | developer | — | solutions-intelligence, jira |

---

## 7. Success Criteria

| Metric | Target |
|--------|--------|
| Time from clone to first AI interaction | < 5 minutes |
| Number of manual config steps | 0 (setup.sh handles all) |
| MCP servers that start successfully | 100% |
| Orchestrator routes correctly | > 90% of test scenarios |
| Powers that work without bundled mcp.json | 100% |
| `setup.sh` idempotency | Pass (run 3x, same state) |
| `setup.sh --uninstall` cleanliness | All symlinks removed |

---

## 8. Dependencies & Prerequisites

| Requirement | Purpose |
|-------------|---------|
| Python 3.11+ | lcp-api MCP server |
| uv | Python package management |
| Docker | Intelligence, Data Gen, Jira MCP servers |
| Kiro CLI | Agent orchestration |
| GitLab token | Solutions Cloud Plane access |
| Appian site (26.2+) with LCP plugin | lcp-api target |
| Appian API key | Data Generator |
| Jira API token | Issue tracking |

---

## 9. Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| LCP plugin not deployed on target site | Verify script checks upfront; graceful degradation |
| Kiro agent format changes | Pin to known working format; test on each Kiro update |
| Docker images unavailable | setup.sh reports pull failures clearly |
| MCP server startup failures | Each server logs errors; verify script diagnoses |
| Power symlinks break on Kiro update | Manifest-driven re-linking; setup.sh --update |

---

## 10. Timeline

| Day | Deliverable |
|-----|------------|
| 1 | Repo scaffolded, pyproject.toml, directory structure |
| 2 | lcp-api MCP server functional (10+ tools), setup.sh, verify |
| 3 | Orchestrator agent + 3 sub-agents (developer, sql-forge, a11y-fixer) |
| 4 | Remaining sub-agents, all powers created |
| 5 | Skills, steering, manifest, platform agnosticism |
| 6 | T.I.M.E. structure, integration testing |
| 7 | Polish, documentation, demo preparation |
