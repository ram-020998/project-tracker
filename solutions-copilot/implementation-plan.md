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
│   ├── steering/                        # Global steering (applies everywhere)
│   │   ├── git-workflow.md
│   │   └── code-standards.md
│   └── settings/
│       └── mcp.json                     # NOT used (setup.sh writes to global)
│
├── engineering/                          # For engineers building Appian apps
│   ├── powers/
│   │   ├── developer/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── code-exploration.md
│   │   │       ├── design-doc-workflow.md
│   │   │       ├── implementation-workflow.md
│   │   │       ├── spike-research-workflow.md
│   │   │       ├── feature-breakdown-workflow.md
│   │   │       ├── refactor-redeploy-workflow.md
│   │   │       ├── expression-test-generation.md
│   │   │       ├── pipeline-check-workflow.md
│   │   │       └── bulk-rename-workflow.md
│   │   ├── sql-forge/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── data-generation-workflow.md
│   │   │       └── data-model-from-sheet-workflow.md
│   │   ├── code-reviewer/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── review-checklist.md
│   │   │       └── code-review-workflow.md
│   │   ├── a11y-fixer/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── fix-patterns.md
│   │   │       ├── fixer-workflow.md
│   │   │       ├── verification.md
│   │   │       ├── xml-rules.md
│   │   │       └── playwright-helper.md
│   │   ├── db-admin/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── db-explore-workflow.md
│   │   │       ├── db-config-workflow.md
│   │   │       ├── db-script-workflow.md
│   │   │       └── smt-reference.md
│   │   ├── i18n/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── i18n-audit-workflow.md
│   │   │       ├── i18n-create-workflow.md
│   │   │       ├── i18n-lookup-workflow.md
│   │   │       └── i18n-reference.md
│   │   └── qe-agent/
│   │       ├── POWER.md
│   │       └── steering/
│   │           ├── test-execution-workflow.md
│   │           └── verify-workflow.md
│   ├── skills/
│   │   ├── sail-reference/
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │       ├── component-reference.md
│   │   │       ├── common-functions.md
│   │   │       └── rich-text-icon-aliases.md
│   │   ├── appian-best-practices/
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │       ├── field-types.md
│   │   │       ├── entity-patterns.md
│   │   │       ├── relationship-patterns.md
│   │   │       └── type-manifest.json
│   │   ├── appian-patterns/
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │       ├── sail-code-hygiene.md
│   │   │       ├── sail-documentation-standards.md
│   │   │       └── security-patterns.md
│   │   ├── a11y-audit/
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │       ├── a11y-sail-rules.md
│   │   │       ├── a11y-jira-patterns.md
│   │   │       └── a11y-doc-output-format.md
│   │   └── appian-known-issues/
│   │       └── SKILL.md
│   └── agents/
│       ├── developer.json
│       ├── sql-forge.json
│       ├── code-reviewer.json
│       ├── a11y-fixer.json
│       ├── qe-agent.json
│       └── prompts/
│           ├── developer-prompt.md
│           ├── sql-forge-prompt.md
│           ├── code-reviewer-prompt.md
│           ├── a11y-fixer-prompt.md
│           └── qe-agent-prompt.md
│
├── product/                             # For product managers and UX
│   ├── powers/
│   │   ├── product-owner/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── feature-spec-workflow.md
│   │   │       ├── release-summary-workflow.md
│   │   │       └── branding-compliance.md
│   │   ├── ux-designer/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── prototype-workflow.md
│   │   │       └── aurora-compliance.md
│   │   └── doc-genie/
│   │       ├── POWER.md
│   │       ├── steering/
│   │       │   ├── workflow-fip.md
│   │       │   ├── workflow-tech-design.md
│   │       │   ├── workflow-perf-review.md
│   │       │   ├── workflow-security-review.md
│   │       │   ├── workflow-arch-overview.md
│   │       │   └── workflow-adr.md
│   │       ├── templates/
│   │       │   ├── fip.md
│   │       │   ├── tech-design.md
│   │       │   ├── perf-review.md
│   │       │   ├── security-review.md
│   │       │   ├── arch-overview.md
│   │       │   ├── adr.md
│   │       │   └── docx/
│   │       ├── styles/
│   │       │   └── document.css
│   │       └── scripts/
│   │           └── fix_table_borders.py
│   ├── skills/
│   │   └── aurora-design-system/
│   │       ├── SKILL.md
│   │       └── references/
│   │           └── aurora-components.md
│   └── agents/
│       ├── product-owner.json
│       ├── ux-designer.json
│       └── prompts/
│           ├── product-owner-prompt.md
│           └── ux-designer-prompt.md
│
├── configuration/                       # For building/maintaining the copilot itself
│   ├── powers/
│   │   ├── power-author/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── power-creation-workflow.md
│   │   │       └── power-validation-checklist.md
│   │   ├── skill-author/
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── skill-creation-workflow.md
│   │   │       └── skill-validation-checklist.md
│   │   └── agent-author/
│   │       ├── POWER.md
│   │       └── steering/
│   │           ├── agent-creation-workflow.md
│   │           └── agent-validation-checklist.md
│   ├── skills/
│   │   ├── power-conventions/
│   │   │   └── SKILL.md                # Rules for writing powers (frontmatter, mcpServers, steering format)
│   │   ├── steering-conventions/
│   │   │   └── SKILL.md                # Rules for writing steering files (step format, tool references)
│   │   └── naming-conventions/
│   │       └── SKILL.md                # Naming standards (no codenames, function-based names)
│   ├── agents/
│   │   ├── power-author.json
│   │   ├── skill-author.json
│   │   ├── agent-author.json
│   │   └── prompts/
│   │       ├── power-author-prompt.md
│   │       ├── skill-author-prompt.md
│   │       └── agent-author-prompt.md
│   └── templates/                       # Templates used by meta-agents
│       ├── power-template/
│       │   ├── POWER.md.template
│       │   └── steering/
│       │       └── workflow.md.template
│       ├── skill-template/
│       │   └── SKILL.md.template
│       └── agent-template/
│           ├── agent.json.template
│           └── prompt.md.template
│
├── orchestrator/                        # The main entry point (spans all categories)
│   ├── solutions-copilot.json
│   ├── prompt.md
│   ├── capabilities.md
│   └── routing-rules.md
│
├── products/                            # T.I.M.E. lifecycle per product
│   └── (product folders)
│
├── configurator/                        # Local setup configurator (HTML page)
│   └── index.html
│
├── solutions-copilot.manifest.json
├── setup.sh
├── verify
├── status                               # Health dashboard (MCP servers, environments, metrics)
├── environments.json                    # Shared environment registry (URLs, no secrets)
├── scripts/
│   ├── detect-transition.py             # T.I.M.E. lifecycle hook
│   └── metrics.py                       # Lightweight usage metrics logger
├── .env.example
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

**Two repos to create (under `ramaswamy.u` namespace):**

1. **`gitlab.appian-stratus.com/ramaswamy.u/solutions-copilot`** — the platform repo
2. **`gitlab.appian-stratus.com/ramaswamy.u/solutions-lcp-mcp-server`** — the LCP API MCP server

For `solutions-copilot`:
- [ ] Create repo at `https://gitlab.appian-stratus.com/ramaswamy.u/solutions-copilot`
- [ ] Initialize with `.gitignore`, `README.md`
- [ ] Create directory structure as defined in Section 2

For `solutions-lcp-mcp-server`:
- [ ] Create repo at `https://gitlab.appian-stratus.com/ramaswamy.u/solutions-lcp-mcp-server`
- [ ] Initialize with `requirements.txt`, `Dockerfile`, `.gitlab-ci.yml`, `main.py`
- [ ] Create `lcp_server/` package with client + tools (see Section 4)
- [ ] Create CI pipeline that builds + pushes Docker image
- [ ] Verify locally: `python3 main.py` connects to merge-assist environment

#### 3.1.2 LCP API MCP Server

Build a thin MCP server that translates tool calls → HTTP requests to `/suite/webapi/lcp-api/*`.

**Architecture:**

```python
# lcp_server/config.py
class LCPConfig(BaseSettings):
    lcp_url: str                    # e.g., https://mysite.appiancloud.com
    lcp_username: str               # Basic Auth username
    lcp_password: str               # Basic Auth password
    lcp_api_path: str = "/suite/webapi/lcp-api"

# lcp_server/client.py
class LCPClient:
    """HTTP client that hits /suite/webapi/lcp-api/* with Basic Auth."""
    async def get(self, path: str, params: dict = None) -> dict
    async def post(self, path: str, body: dict) -> dict
    async def put(self, path: str, body: dict) -> dict
    async def delete(self, path: str) -> dict

# lcp_server/server.py
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
          "registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-intelligence-server:latest"],
        "env": { "GITLAB_TOKEN": "<from .env>", "SOLUTIONS_KB_PROJECT_ID": "13490", "SOLUTIONS_DATA_PREFIX": "..." },
        "autoApprove": ["*"]
      },
      "lcp-api": {
        "command": "docker",
        "args": ["run", "--rm", "-i", "--env", "LCP_URL", "--env", "LCP_USERNAME", "--env", "LCP_PASSWORD",
          "registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-lcp-mcp-server:latest"],
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

#### Available Tools

You have access to:
- **solutions-intelligence** MCP: get_app_overview, search_objects, get_object_code, get_dependencies, get_impact_analysis, compare_releases
- **lcp-api** MCP: createInterface, updateInterface, createRecordType, createConstant
- **jira** MCP: get_jira_issue, search_jira_issues

#### Workflows

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
        "lcp-api": { "type": "docker", "image": "registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-lcp-mcp-server:latest", "env_keys": ["LCP_URL", "LCP_USERNAME", "LCP_PASSWORD"] },
        "data-generator": { "type": "docker", "image": "...", "env_keys": ["DATA_GEN_ENV_URL", "DATA_GEN_API_KEY"] },
        "jira": { "type": "docker", "image": "...", "env_keys": ["JIRA_URL", "JIRA_EMAIL", "JIRA_TOKEN"] },
        "playwright": { "type": "npx", "package": "@playwright/mcp@latest" }
      }
    },
    "categories": {
      "engineering": {
        "powers": [
          { "name": "developer", "path": "engineering/powers/developer" },
          { "name": "sql-forge", "path": "engineering/powers/sql-forge" },
          { "name": "code-reviewer", "path": "engineering/powers/code-reviewer" },
          { "name": "a11y-fixer", "path": "engineering/powers/a11y-fixer" },
          { "name": "qe-agent", "path": "engineering/powers/qe-agent" },
          { "name": "db-admin", "path": "engineering/powers/db-admin" },
          { "name": "i18n", "path": "engineering/powers/i18n" }
        ],
        "skills": [
          { "name": "sail-reference", "path": "engineering/skills/sail-reference" },
          { "name": "appian-best-practices", "path": "engineering/skills/appian-best-practices" },
          { "name": "appian-patterns", "path": "engineering/skills/appian-patterns" },
          { "name": "a11y-audit", "path": "engineering/skills/a11y-audit" },
          { "name": "appian-known-issues", "path": "engineering/skills/appian-known-issues" }
        ],
        "agents": [
          { "name": "developer", "path": "engineering/agents/developer.json" },
          { "name": "sql-forge", "path": "engineering/agents/sql-forge.json" },
          { "name": "code-reviewer", "path": "engineering/agents/code-reviewer.json" },
          { "name": "a11y-fixer", "path": "engineering/agents/a11y-fixer.json" },
          { "name": "qe-agent", "path": "engineering/agents/qe-agent.json" }
        ]
      },
      "product": {
        "powers": [
          { "name": "product-owner", "path": "product/powers/product-owner" },
          { "name": "ux-designer", "path": "product/powers/ux-designer" },
          { "name": "doc-genie", "path": "product/powers/doc-genie" }
        ],
        "skills": [
          { "name": "aurora-design-system", "path": "product/skills/aurora-design-system" }
        ],
        "agents": [
          { "name": "product-owner", "path": "product/agents/product-owner.json" },
          { "name": "ux-designer", "path": "product/agents/ux-designer.json" }
        ]
      },
      "configuration": {
        "powers": [
          { "name": "power-author", "path": "configuration/powers/power-author" },
          { "name": "skill-author", "path": "configuration/powers/skill-author" },
          { "name": "agent-author", "path": "configuration/powers/agent-author" }
        ],
        "skills": [
          { "name": "power-conventions", "path": "configuration/skills/power-conventions" },
          { "name": "steering-conventions", "path": "configuration/skills/steering-conventions" },
          { "name": "naming-conventions", "path": "configuration/skills/naming-conventions" }
        ],
        "agents": [
          { "name": "power-author", "path": "configuration/agents/power-author.json" },
          { "name": "skill-author", "path": "configuration/agents/skill-author.json" },
          { "name": "agent-author", "path": "configuration/agents/agent-author.json" }
        ]
      }
    },
    "profiles": {
      "full": { "categories": ["engineering", "product", "configuration"] },
      "engineering": { "categories": ["engineering"] },
      "product": { "categories": ["product"] },
      "minimal": { "categories": ["engineering"], "powers": ["developer"] },
      "maintainer": { "categories": ["configuration"] }
    }
  }
  ```

#### 3.4.2 Setup Configurator (Interactive HTML Page)

A local HTML page (`configurator/index.html`) that reads `solutions-copilot.manifest.json` and lets users visually select what to install.

**How it works:**
1. User opens `configurator/index.html` in their browser (local file, no server needed)
2. Page reads the manifest JSON (embedded or fetched via relative path)
3. User selects **install mode** (global vs workspace)
4. Shows all available powers, skills, agents with descriptions and dependencies
5. User checks what they want
6. Page generates a `user-config.json` and/or the exact shell command
7. User runs `./setup.sh` which reads `user-config.json` for selections

**Install Modes:**

| Mode | Target | When to use |
|------|--------|-------------|
| **Global** (`~/.kiro/`) | Available in every workspace/project | Default — for team members who use Solutions Copilot across multiple projects |
| **Workspace** (`<project>/.kiro/`) | Only available in one specific project | For isolated setups — e.g., a project that needs only specific powers |

**Setup script usage:**
```bash
./setup.sh                                        # Default: global, full profile
./setup.sh --workspace /path/to/my-project        # Workspace-level install
./setup.sh --config user-config.json              # Read all selections from config
./setup.sh --workspace . --config user-config.json # Workspace mode in current dir
```

**`user-config.json` format:**
```json
{
  "installMode": "global",
  "workspacePath": "",
  "categories": ["engineering", "product"],
  "powers": ["developer", "sql-forge", "product-owner"],
  "skills": ["sail-reference", "appian-best-practices", "aurora-design-system"],
  "agents": ["developer", "sql-forge", "product-owner"],
  "mcpServers": ["solutions-intelligence", "lcp-api", "data-generator", "jira", "playwright"]
}
```

**Symlink targets per mode:**

| Component | Global mode | Workspace mode |
|-----------|-------------|---------------|
| Powers | `~/.kiro/powers/installed/<name>` | `<project>/.kiro/powers/installed/<name>` |
| Skills | `~/.kiro/skills/<name>` | `<project>/.kiro/skills/<name>` |
| Agents | `~/.kiro/agents/<name>.json` | `<project>/.kiro/agents/<name>.json` |
| Steering | `~/.kiro/steering/<name>` | `<project>/.kiro/steering/<name>` |
| MCP config | `~/.kiro/settings/mcp.json` | `<project>/.kiro/settings/mcp.json` |
| Powers registry | `~/.kiro/powers/installed.json` | `<project>/.kiro/powers/installed.json` |

**UI Layout:**

```
┌─────────────────────────────────────────────────────────────────┐
│  Solutions Copilot — Setup Configurator                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📍 Install Mode                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ ● Global (~/.kiro/) — available in all workspaces        │   │
│  │ ○ Workspace — only in a specific project                 │   │
│  │                                                          │   │
│  │   Workspace path: [________________________] [Browse]    │   │
│  └──────────────────────────────────────────────────────────┘   │
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

#### T.I.M.E. Lifecycle Automation (Hooks)

When a file is moved between lifecycle stages, AI should act automatically. This is implemented via a `PostToolUse` hook that detects file creation in lifecycle folders.

**Implementation:**

```
solutions-copilot/
├── scripts/
│   └── detect-transition.py       # PostToolUse hook script
```

**Hook registration** (in `.kiro/steering/` or agent config):
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "fs_write|fs_move",
        "hooks": [{ "type": "command", "command": "python3 scripts/detect-transition.py" }]
      }
    ]
  }
}
```

**`scripts/detect-transition.py` logic:**

```python
#!/usr/bin/env python3
"""Detect file transitions in T.I.M.E. lifecycle folders and suggest AI actions."""
import json, sys, re
from pathlib import Path

LIFECYCLE_ACTIONS = {
    "01-discovery": "Scan for duplicates across products. Flag cross-suite dependencies. Suggest related context from 00-context/.",
    "02-refinement": "Expand idea into spec outline. Generate feature card. Draft lightweight HTML prototype.",
    "03-planning": "Break feature into implementation tickets. Estimate complexity using KB data. Relate to release.",
    "04-delivery": "Generate design document from spec. Create task breakdown. Link to relevant Appian objects.",
    "05-shipped": "Write release notes. Update product README. Archive delivery artifacts.",
}

def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("{}"); return

    file_path = (data.get("tool_input") or {}).get("file_path", "")
    if not file_path:
        print("{}"); return

    # Check if file is in a lifecycle folder
    for stage, action in LIFECYCLE_ACTIONS.items():
        if f"/{stage}/" in file_path or file_path.endswith(f"/{stage}"):
            result = {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": f"[T.I.M.E. TRANSITION] File created in {stage}/. Suggested action: {action}"
                }
            }
            print(json.dumps(result)); return

    print("{}")

if __name__ == "__main__":
    main()
```

**Tasks:**
- [ ] Create `scripts/detect-transition.py`
- [ ] Register hook in orchestrator agent config
- [ ] Test: create a file in `products/example/02-refinement/` → agent receives suggestion
- [ ] Define action templates per lifecycle stage

---

### Phase 5b: Environment Registry (Day 6)

**Goal:** Support multiple Appian environments without editing .env each time.

#### Design

```
solutions-copilot/
├── environments.json                # Shared registry (committed — URLs only, no secrets)
├── .env                             # Default credentials (gitignored)
└── ~/.solutions-copilot/
    └── credentials                  # Per-environment secrets (user's machine, chmod 600)
```

**`environments.json`:**
```json
{
  "environments": {
    "gam-dev2": {
      "url": "https://eng-test-fed-aq-dev2.appianpreview.com",
      "products": ["source-selection", "vendor-management", "contract-writing"],
      "type": "development"
    },
    "merge-assist": {
      "url": "https://merge-assist.appianpreview.com",
      "products": ["gss"],
      "type": "development"
    },
    "cms-dev": {
      "url": "https://eng-test-solutions-cms-dev.appianpreview.com",
      "products": ["case-management-studio"],
      "type": "development"
    }
  },
  "defaults": {
    "intelligence": "merge-assist",
    "lcp-api": "merge-assist"
  }
}
```

**`~/.solutions-copilot/credentials`** (gitignored, per-user):
```bash
# merge-assist
MERGE_ASSIST_USERNAME=admin.user
MERGE_ASSIST_PASSWORD=soloLeveling@98

# gam-dev2
GAM_DEV2_USERNAME=ramaswamy.u
GAM_DEV2_API_KEY=eyJ0eXAiOiJKV1Q...

# GitLab (shared across environments)
GITLAB_TOKEN=Cms4AhIQz3jv...
```

**How it works:**

1. `setup.sh` creates `~/.solutions-copilot/credentials` from template if missing
2. MCP server config reads default environment from `environments.json`
3. Agent can switch environments mid-session: "Query the evaluations table on gam-dev2"
4. Orchestrator resolves environment name → URL + credentials from registry + credentials file

**Environment switching in the orchestrator prompt:**
```markdown
## Environment switching
When user mentions an environment by name, resolve it from environments.json.
- "on dev2" → gam-dev2
- "on merge-assist" → merge-assist
- "on staging" → look for type: "staging"
If ambiguous, ask: "Which environment? Available: gam-dev2, merge-assist, cms-dev"
```

**Tasks:**
- [ ] Create `environments.json` with known environments
- [ ] Create `~/.solutions-copilot/credentials` template
- [ ] Update `setup.sh` to create credentials file on first run
- [ ] Update MCP config generation to read default environment
- [ ] Add environment switching guidance to orchestrator prompt
- [ ] Test: switch environments mid-session

---

### Phase 5c: Metrics & Observability (Day 7)

**Goal:** Track usage, errors, and system health for continuous improvement.

#### Design

```
solutions-copilot/
├── scripts/
│   ├── detect-transition.py
│   └── metrics.py                   # Lightweight metrics logger
├── .metrics/                        # Local SQLite DB (gitignored)
│   └── usage.db
└── status                           # Health check script (like verify but richer)
```

**Metrics store (`scripts/metrics.py`):**

```python
"""Lightweight metrics — logs tool calls, delegations, errors to local SQLite."""
import sqlite3, json, time
from pathlib import Path

DB_PATH = Path.home() / ".solutions-copilot" / "metrics.db"

def init_db():
    DB_PATH.parent.mkdir(exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT DEFAULT (datetime('now')),
            session_id TEXT,
            agent TEXT,
            event TEXT NOT NULL,
            tool_name TEXT,
            mcp_server TEXT,
            duration_ms INTEGER,
            success BOOLEAN,
            metadata TEXT
        )
    """)
    conn.commit()
    return conn

def log_event(event: str, **kwargs):
    conn = init_db()
    conn.execute(
        "INSERT INTO events (event, agent, tool_name, mcp_server, success, metadata) VALUES (?,?,?,?,?,?)",
        (event, kwargs.get("agent"), kwargs.get("tool"), kwargs.get("mcp"), kwargs.get("success", True), json.dumps(kwargs.get("meta", {})))
    )
    conn.commit()
```

**Health dashboard (`status` script):**

```bash
#!/bin/bash
# solutions-copilot status — system health check

echo "🔍 Solutions Copilot Status"
echo ""

# Check MCP servers
echo "MCP Servers:"
for server in solutions-intelligence lcp-api data-generator jira playwright; do
  if docker ps --format '{{.Image}}' | grep -q "$server" 2>/dev/null; then
    echo "  ✅ $server — running"
  else
    echo "  ⚪ $server — not running (starts on demand)"
  fi
done

echo ""
echo "Environments:"
python3 -c "
import json
with open('environments.json') as f:
    envs = json.load(f)['environments']
for name, env in envs.items():
    print(f'  {name}: {env[\"url\"]} ({env[\"type\"]})')
"

echo ""
echo "Installed Components:"
echo "  Powers: $(ls ~/.kiro/powers/installed/ 2>/dev/null | wc -l | tr -d ' ')"
echo "  Skills: $(ls ~/.kiro/skills/ 2>/dev/null | wc -l | tr -d ' ')"
echo "  Agents: $(ls ~/.kiro/agents/ 2>/dev/null | grep -c '.json' | tr -d ' ')"

echo ""
echo "Metrics (last 7 days):"
python3 -c "
import sqlite3
from pathlib import Path
db = Path.home() / '.solutions-copilot' / 'metrics.db'
if db.exists():
    conn = sqlite3.connect(db)
    total = conn.execute('SELECT COUNT(*) FROM events WHERE timestamp > datetime(\"now\", \"-7 days\")').fetchone()[0]
    errors = conn.execute('SELECT COUNT(*) FROM events WHERE success=0 AND timestamp > datetime(\"now\", \"-7 days\")').fetchone()[0]
    print(f'  Tool calls: {total}')
    print(f'  Errors: {errors}')
    print(f'  Success rate: {((total-errors)/total*100) if total else 0:.1f}%')
else:
    print('  No metrics yet (run some sessions first)')
" 2>/dev/null || echo "  No metrics yet"
```

**What gets tracked:**

| Event | When | Data |
|-------|------|------|
| `tool_call` | Every MCP tool invocation | agent, tool name, mcp server, success, duration |
| `delegation` | Orchestrator delegates to sub-agent | source agent, target agent, trigger signal |
| `error` | Tool call fails | error message, mcp server, tool name |
| `transition` | File moved to lifecycle stage | product, stage, file |
| `env_switch` | User switches environment | from_env, to_env |

**Tasks:**
- [ ] Create `scripts/metrics.py` with SQLite logging
- [ ] Create `status` script (health dashboard)
- [ ] Add PostToolUse hook that logs tool calls to metrics
- [ ] Add delegation logging to orchestrator prompt
- [ ] Test: run a session → check `status` shows stats
- [ ] Store metrics at `~/.solutions-copilot/metrics.db` (survives repo updates)

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

Follows the same pattern as `ramaswamy.u/solutions-atlas-dg-mcp-server`:

```
solutions-lcp-mcp-server/
├── lcp_server/                      # Main package (same level as main.py)
│   ├── __init__.py
│   ├── client.py                    # httpx client (Basic Auth → /suite/webapi/lcp-api/*)
│   ├── config.py                    # Env-based configuration
│   ├── models.py                    # Pydantic models
│   ├── server.py                    # MCP server class + tool registration
│   ├── utils.py                     # Error handling, pagination helpers
│   └── tools/
│       ├── __init__.py
│       ├── _shared.py               # Common tool helpers
│       ├── applications.py
│       ├── record_types.py
│       ├── interfaces.py
│       ├── expression_rules.py
│       ├── process_models.py
│       ├── constants.py
│       ├── groups.py
│       ├── folders.py
│       ├── objects.py
│       └── expressions.py
├── tests/
│   ├── __init__.py
│   └── test_server.py
├── docs/
│   └── tools.md
├── main.py                          # Entry point (asyncio + mcp.server.stdio)
├── mcp.json                         # MCP server metadata
├── Dockerfile
├── .gitlab-ci.yml                   # Lint → Test → Build (kaniko to registry)
├── .env.example
├── .gitignore
├── requirements.txt
├── requirements-dev.txt
├── pytest.ini
└── README.md
```

**Docker image:** `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-lcp-mcp-server:latest`

### 4.2 Key Files

**`main.py`** (same pattern as DG MCP server):
```python
#!/usr/bin/env python3
"""Solutions LCP MCP Server — Entry point"""
import asyncio, logging, sys
import mcp.server.stdio
from lcp_server.config import config
from lcp_server.server import LCPMCPServer

async def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s", stream=sys.stderr)
    logger = logging.getLogger(__name__)
    try:
        config.initialize()
        logger.info(f"Connected to: {config.lcp_url}")
        lcp = LCPMCPServer()
        server = lcp.get_server()
        async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
            await server.run(read_stream, write_stream, server.create_initialization_options())
    except ValueError as e:
        print(f"Configuration error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
```

**`Dockerfile`:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY lcp_server/ ./lcp_server/
COPY main.py .
ENV PYTHONPATH=/app
ENTRYPOINT ["python3", "main.py"]
```

**`.gitlab-ci.yml`** (same CI pattern as DG server):
```yaml
include:
  - project: appian/prod/k8s-gitlab-runners
    file: /templates/.gitlab-ci.v1.yaml

stages: [Lint, Test, Build]

workflow:
  rules:
    - if: '$CI_PIPELINE_SOURCE != "merge_request_event"'

default:
  id_tokens:
    STRATUS_JWT:
      aud: $CI_SERVER_URL

lint:
  extends: [.executor-small]
  stage: Lint
  image: python:3.11-slim
  tags: [k8s-executor]
  before_script: [pip install flake8]
  script: [flake8 lcp_server/ tests/ --max-line-length=120 --ignore=E501,W503]
  retry: 2

test:
  extends: [.executor-small]
  stage: Test
  image: python:3.11-slim
  tags: [k8s-executor]
  before_script: [pip install -r requirements.txt -r requirements-dev.txt]
  script: [python -m pytest tests/ -v --tb=short]
  retry: 2

build-image:
  extends: [.executor-small]
  stage: Build
  image: { name: gcr.io/kaniko-project/executor:v1.23.2-debug, entrypoint: [""] }
  tags: [k8s-executor]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"${CI_REGISTRY}\":{\"auth\":\"$(printf \"%s:%s\" \"${CI_REGISTRY_USER}\" \"${CI_REGISTRY_PASSWORD}\" | base64 | tr -d '\\n')\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor --context "${CI_PROJECT_DIR}" --dockerfile "${CI_PROJECT_DIR}/Dockerfile" --destination "${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}" --destination "${CI_REGISTRY_IMAGE}:latest"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  retry: 2
```

**`requirements.txt`:**
```
mcp>=1.0.0
httpx>=0.27.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
```

### 4.3 Design

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

### 5.3 Tool Routing Enforcement in Powers

Every power's `POWER.md` declares its MCP server usage in frontmatter:

```yaml
---
name: "developer"
description: "Code exploration, design docs, implementation, refactoring"
category: "engineering"
mcpServers:
  primary:
    - solutions-intelligence    # All reads — app knowledge, code, deps
  write:
    - lcp-api                   # Object creation and modification
  supporting:
    - jira                      # Ticket context and tracking
---
```

**Enforcement layers:**

1. **Frontmatter** — agent reads this and knows which servers to prefer
2. **Steering files** — each workflow step names the exact tool: "Use `solutions-intelligence.get_app_overview`"
3. **Orchestrator hard rules** — global override that prevents misuse
4. **Tool descriptions** — `[READ]` / `[WRITE]` prefix in MCP tool descriptions

### 5.4 Meta-Agents (Configuration Category)

The configuration agents ensure consistency when team members add new content:

**power-author** — activated when someone says "create a new power" or "add a power for X":
- Asks clarifying questions (purpose, category, which MCP servers needed)
- Generates POWER.md from template with correct frontmatter
- Creates steering skeleton with tool routing annotations
- Validates against `configuration/skills/power-conventions/`
- Places in correct category folder (engineering/product/configuration)

**skill-author** — activated for "create a skill about Y":
- Generates SKILL.md with proper YAML frontmatter (name, description)
- Ensures description is concrete (not vague "helps with Appian")
- Creates references/ directory if needed
- Validates against `configuration/skills/steering-conventions/`

**agent-author** — activated for "add a new agent for Z":
- Generates agent JSON config (name, description, tools, model)
- Creates prompt file with routing rules and tool access declarations
- Registers in manifest under correct category
- Ensures the agent maps to an existing power (or creates one)

---

## 6. Complete Migration Map (solutions-os + SWAT → solutions-copilot)

### 6.1 Powers Migration

| Source (solutions-os / SWAT) | Target Category | Target Path | Notes |
|------------------------------|----------------|-------------|-------|
| `Engineering/.kiro/powers/atlas-developer/` | Engineering | `engineering/powers/developer/` | Rename, merge Jarvis design-doc/implementation workflows |
| `Engineering/.kiro/powers/atlas-sql-forge/` | Engineering | `engineering/powers/sql-forge/` | Add data-model-from-sheet steering from lcp-api |
| `Engineering/.kiro/powers/atlas-demo-driver/` | Engineering | `engineering/powers/sql-forge/` | Merge into sql-forge (same domain: data generation) |
| `Engineering/.kiro/powers/sail-reference/` | Engineering | `engineering/skills/sail-reference/` | Convert to skill (it's reference, not a workflow) |
| `Engineering/.kiro/powers/feature-docgenie/` | Product | `product/powers/doc-genie/` | Keep templates, scripts, styles intact |
| `Product/.kiro/powers/atlas-product-owner/` | Product | `product/powers/product-owner/` | Rename |
| `Product/.kiro/powers/atlas-ux-designer/` | Product | `product/powers/ux-designer/` | Rename |
| `tools/Jarvis/jarvis-power/` | Engineering | Split across multiple powers | See steering migration below |
| `tools/Jarvis-A11yFixer/` | Engineering | `engineering/powers/a11y-fixer/` | Direct migration |
| `tools/A11yAudit/a11y-audit-power/` | Engineering | `engineering/skills/a11y-audit/` | Convert to skill (shared by multiple agents) |
| `tools/jarvis-i18n/` | Engineering | `engineering/powers/i18n/` | Direct migration |
| `tools/jarvis-smt/` | Engineering | `engineering/powers/db-admin/` | Rename |
| `tools/jarvis-verify/` | Engineering | `engineering/powers/qe-agent/` | Merge into qe-agent |
| SWAT #1 (A11Y Fixer) | Engineering | `engineering/powers/a11y-fixer/` | Already covered above |
| SWAT #3 (SQL Forge) | Engineering | `engineering/powers/sql-forge/` | Already covered |
| SWAT #6 (UX Enhancements) | Product | `product/powers/ux-designer/` | Merge capabilities |
| SWAT #8 (Spec to Slides) | Product | `product/powers/product-owner/steering/` | Add as steering workflow |
| SWAT #15 (Feature Doc Genie) | Product | `product/powers/doc-genie/` | Already covered |
| SWAT #19 (Test Execution Agent) | Engineering | `engineering/powers/qe-agent/` | Already covered |
| lcp-api `powers/appian-data-model-workflow/` | Engineering | `engineering/powers/sql-forge/` | Merge |
| lcp-api `powers/appian-bulk-rename-workflow/` | Engineering | `engineering/powers/developer/` | Add as steering |
| (new) power-author | Configuration | `configuration/powers/power-author/` | New for POC |
| (new) skill-author | Configuration | `configuration/powers/skill-author/` | New for POC |
| (new) agent-author | Configuration | `configuration/powers/agent-author/` | New for POC |

### 6.2 Jarvis Power Steering → Split Across Agents

The 20 steering files from `tools/Jarvis/jarvis-power/steering/` distribute as follows:

| Steering File | Target | Target Path |
|--------------|--------|-------------|
| `code-review-workflow.md` | code-reviewer | `engineering/powers/code-reviewer/steering/` |
| `design-doc-workflow.md` | developer | `engineering/powers/developer/steering/` |
| `implementation-workflow.md` | developer | `engineering/powers/developer/steering/` |
| `spike-research-workflow.md` | developer | `engineering/powers/developer/steering/` |
| `feature-breakdown-workflow.md` | developer | `engineering/powers/developer/steering/` |
| `implementation-summary-workflow.md` | developer | `engineering/powers/developer/steering/` |
| `pipeline-check-workflow.md` | developer | `engineering/powers/developer/steering/` |
| `refactor-redeploy-workflow.md` | developer | `engineering/powers/developer/steering/` |
| `refactor-step-translation.md` | developer | `engineering/powers/developer/steering/` |
| `refactor-step-utility-substitution.md` | developer | `engineering/powers/developer/steering/` |
| `expression-test-generation.md` | developer | `engineering/powers/developer/steering/` |
| `knowledge-query-workflow.md` | orchestrator | `orchestrator/routing-rules.md` (absorbed) |
| `sail-code-hygiene.md` | skill | `engineering/skills/appian-patterns/references/` |
| `sail-documentation-standards.md` | skill | `engineering/skills/appian-patterns/references/` |
| `appian-best-practices-checklist.md` | skill | `engineering/skills/appian-best-practices/references/` |
| `branding-compliance.md` | product-owner | `product/powers/product-owner/steering/` |
| `workspace-rules.md` | global steering | `.kiro/steering/workspace-rules.md` |
| `jarvis-menu.md` | REMOVE | Orchestrator handles routing now |
| `t-retriever-navigation.md` | developer | `engineering/powers/developer/steering/` |

### 6.3 Skills Migration

| Source | Target Category | Target Path | Notes |
|--------|----------------|-------------|-------|
| buildwithclaude `skills/appian-sail/` | Engineering | `engineering/skills/sail-reference/` | SKILL.md + references/ (component catalog, icons, patterns) |
| buildwithclaude `skills/appian-record-types/` | Engineering | `engineering/skills/appian-best-practices/` | Merge into broader best-practices skill |
| buildwithclaude `skills/appian-data-modeling/` | Engineering | `engineering/skills/appian-best-practices/references/` | Entity + relationship patterns |
| buildwithclaude `skills/appian-expressions/` | Engineering | `engineering/skills/sail-reference/references/` | Common functions |
| buildwithclaude `skills/appian-interfaces/` | Engineering | `engineering/skills/sail-reference/references/` | UI patterns |
| buildwithclaude `skills/appian-process-models/` | Engineering | `engineering/skills/appian-patterns/references/` | Node types |
| buildwithclaude `skills/appian-security/` | Engineering | `engineering/skills/appian-patterns/references/` | Security patterns |
| A11yAudit steering (8 files) | Engineering | `engineering/skills/a11y-audit/` | Full a11y rule set |
| lcp-api `docs/known-issues.yaml` | Engineering | `engineering/skills/appian-known-issues/` | Queryable at runtime |
| lcp-api `data/type_manifest.json` | Engineering | `engineering/skills/appian-best-practices/references/` | Type ID → name mapping |
| (new) power-conventions | Configuration | `configuration/skills/power-conventions/` | Rules for writing powers |
| (new) steering-conventions | Configuration | `configuration/skills/steering-conventions/` | Rules for writing steering |
| (new) naming-conventions | Configuration | `configuration/skills/naming-conventions/` | No codenames, function-based |

### 6.4 Agents Migration

| Source | Target Category | Target Path | Notes |
|--------|----------------|-------------|-------|
| (new) solutions-copilot orchestrator | Orchestrator | `orchestrator/solutions-copilot.json` | Routes to all categories |
| Current developer power activation | Engineering | `engineering/agents/developer.json` | Full sub-agent |
| Current sql-forge power activation | Engineering | `engineering/agents/sql-forge.json` | Full sub-agent |
| Current code-reviewer workflow | Engineering | `engineering/agents/code-reviewer.json` | Full sub-agent |
| Current a11y-fixer workflow | Engineering | `engineering/agents/a11y-fixer.json` | Full sub-agent |
| SWAT #19 TEA | Engineering | `engineering/agents/qe-agent.json` | Full sub-agent |
| Current product-owner activation | Product | `product/agents/product-owner.json` | Full sub-agent |
| Current ux-designer activation | Product | `product/agents/ux-designer.json` | Full sub-agent |
| (new) power-author | Configuration | `configuration/agents/power-author.json` | Meta-agent |
| (new) skill-author | Configuration | `configuration/agents/skill-author.json` | Meta-agent |
| (new) agent-author | Configuration | `configuration/agents/agent-author.json` | Meta-agent |

### 6.5 Products Migration (solutions-os → T.I.M.E. structure)

| Source (solutions-os) | Target | Migration |
|----------------------|--------|-----------|
| `products/gam-solutions/` | `products/gam-solutions/` | Add T.I.M.E. folders, preserve suite structure |
| `products/case-management-studio/` | `products/case-management-studio/` | `domain/` → `00-context/`, `features/` → `02-refinement/` |
| `products/procuresight/` | `products/procuresight/` | Same pattern |
| `products/synapse/` | `products/synapse/` | Same pattern |
| `products/doccenter/` | `products/doccenter/` | Same pattern |
| `products/insurance-underwriting/` | `products/insurance-underwriting/` | Same pattern |

### 6.6 MCP Tool Routing per Power

Every power declares which MCP servers it uses:

| Power | Primary (read) | Write | Supporting |
|-------|---------------|-------|-----------|
| developer | solutions-intelligence | lcp-api | jira |
| sql-forge | solutions-intelligence | lcp-api, data-generator | — |
| code-reviewer | solutions-intelligence | — | jira |
| a11y-fixer | solutions-intelligence | lcp-api | playwright, jira |
| qe-agent | solutions-intelligence | — | playwright, jira |
| db-admin | solutions-intelligence | lcp-api | — |
| i18n | solutions-intelligence | lcp-api | — |
| product-owner | solutions-intelligence | — | jira |
| ux-designer | solutions-intelligence | lcp-api | — |
| doc-genie | solutions-intelligence | — | — |
| power-author | — | — | — (file system only) |
| skill-author | — | — | — (file system only) |
| agent-author | — | — | — (file system only) |

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
