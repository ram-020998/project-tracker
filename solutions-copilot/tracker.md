# Solutions Copilot — Project Tracker

## Session ID
Planning session: `a0d0510c-a343-4cf6-b32a-620d0bc6385a`
Exution session: `b43a1e18-0fff-4d3d-ab5b-f8b7e46b2c76`

## Overview
Building the Solutions Copilot POC — a modular AI development platform for Appian Solutions teams. Two repos under `ramaswamy.u` namespace on GitLab.

## Status
Active development — Phases 1-5 complete, P1 migrations done, format alignment done.

---

## Session Log

### June 5, 2026 — Full POC Implementation (Phases 1–5 + Migration)

---

#### Repos Created

| Repo | URL | Purpose |
|------|-----|---------|
| solutions-lcp-mcp-server | https://gitlab.appian-stratus.com/ramaswamy.u/solutions-lcp-mcp-server | LCP API MCP server (Docker image) |
| solutions-copilot | https://gitlab.appian-stratus.com/ramaswamy.u/solutions-copilot | Platform repo (powers, skills, agents, setup.sh) |

---

#### Phase 1: Foundation (LCP MCP Server + Scaffold)

**Commits:** `8fc5d81` (lcp-server), `1fa640c` (copilot)

**solutions-lcp-mcp-server:**
- 19 MCP tools implemented and live-tested against merge-assist environment
- Tools: listApplications, getApplication, createApplication, listRecordTypes, getRecordType, createRecordType, updateRecordType, listInterfaces, getInterface, createInterface, updateInterface, listExpressionRules, getExpressionRule, createExpressionRule, evaluateExpression, listConstants, createConstant, searchObjects, getObjectDependencies
- Architecture: flat `lcp_server/` package, `main.py` entry point, `mcp.server.stdio`, `Server()` class
- Follows `solutions-atlas-dg-mcp-server` pattern exactly
- Validated: 10 apps, 58 record types in GSS, 19 interfaces, SAIL code retrieval (3666 chars)
- All unit tests pass (9/9), flake8 lint clean
- Dockerfile: python:3.11-slim, pip install, ENTRYPOINT python3 main.py
- .gitlab-ci.yml: Lint → Test → Build (kaniko to registry)
- Test environment: https://merge-assist.appianpreview.com (Basic Auth admin.user)

**solutions-copilot scaffold:**
- Three-category structure: `engineering/`, `product/`, `configuration/`
- Each category has `powers/`, `skills/`, `agents/` subdirs
- `.kiro/steering/git-workflow.md` — global steering
- `setup.sh` — one-command bootstrap (initial version)
- `solutions-copilot.manifest.json` — declarative component registry
- `.env.example` — credential template
- `README.md`

**Files created (lcp-server):**
- `main.py`, `lcp_server/__init__.py`, `lcp_server/config.py`, `lcp_server/client.py`
- `lcp_server/server.py`, `lcp_server/models.py`, `lcp_server/utils.py`
- `lcp_server/tools/__init__.py`, `_shared.py`, `applications.py`, `record_types.py`
- `lcp_server/tools/interfaces.py`, `expression_rules.py`, `constants.py`, `objects.py`
- `tests/__init__.py`, `tests/test_server.py`
- `Dockerfile`, `.gitlab-ci.yml`, `requirements.txt`, `requirements-dev.txt`
- `pytest.ini`, `.env.example`, `.gitignore`, `README.md`

---

#### Phase 2: Orchestrator + Sub-Agents

**Commit:** `0e8a384` (23 files, 531 insertions)

**Created 7 specialist agent JSON configs:**
- `engineering/agents/developer.json`
- `engineering/agents/sql-forge.json`
- `engineering/agents/code-reviewer.json`
- `engineering/agents/a11y-fixer.json`
- `engineering/agents/qe-agent.json`
- `product/agents/product-owner.json`
- `product/agents/ux-designer.json`

**Created 7 specialist agent prompts:**
- `engineering/agents/prompts/developer-prompt.md`
- `engineering/agents/prompts/sql-forge-prompt.md`
- `engineering/agents/prompts/code-reviewer-prompt.md`
- `engineering/agents/prompts/a11y-fixer-prompt.md`
- `engineering/agents/prompts/qe-agent-prompt.md`
- `product/agents/prompts/product-owner-prompt.md`
- `product/agents/prompts/ux-designer-prompt.md`

**Created 3 meta-agent configs + prompts:**
- `configuration/agents/power-author.json` + `prompts/power-author-prompt.md`
- `configuration/agents/skill-author.json` + `prompts/skill-author-prompt.md`
- `configuration/agents/agent-author.json` + `prompts/agent-author-prompt.md`

**Orchestrator:**
- `orchestrator/solutions-copilot.json` — references all 10 sub-agents, trustedAgents, postToolUse hook
- `orchestrator/prompt.md` — tool routing rules
- `orchestrator/routing-rules.md` — delegation signals + disambiguation
- `orchestrator/capabilities.md` — machine-readable capability manifest

**Other:**
- `environments.json` — 4 Appian environments (merge-assist, gam-dev2, cms-dev, solutions-global-dev)

---

#### Phase 3: Skills & Steering Enrichment

**Commit:** `cfcae94` (46 files, 14,680 insertions)

**Skills enriched from buildwithclaude (John Rogers' repo):**
- `sail-reference`: 494-line SKILL.md + 23 reference files (components, layouts, patterns, icons)
  - Source: `/tmp/buildwithclaude/skills/appian-sail/`
- `appian-best-practices`: SKILL.md + 5 references (field-types.md, data-modeling.md, record-types.md, entity-patterns.md, relationship-patterns.md)
  - Source: buildwithclaude `appian-record-types/` + `appian-data-modeling/`
- `appian-patterns`: SKILL.md + 3 references (expressions.md, security-patterns.md, process-models.md)
  - Source: buildwithclaude `appian-expressions/` + `appian-security/` + `appian-process-models/`

**Skills created from SWAT specs:**
- `a11y-audit`: 87-line comprehensive rule set (25+ rules by component type, severity levels)

**Skills created from lcp-api repo:**
- `appian-known-issues`: SKILL.md + `references/known-issues.yaml` (308 lines from saurabh.sabat/lcp-api)

**Configuration skills created:**
- `power-conventions/SKILL.md`
- `steering-conventions/SKILL.md`
- `naming-conventions/SKILL.md`

**Steering files added:**
- `product/powers/product-owner/steering/release-summary-workflow.md`
- `product/powers/product-owner/steering/feature-spec-workflow.md`
- `product/powers/ux-designer/steering/prototype-workflow.md`
- `engineering/powers/qe-agent/steering/test-execution-workflow.md`
- `engineering/powers/sql-forge/steering/data-model-from-sheet-workflow.md`
- `engineering/powers/developer/steering/bulk-rename-workflow.md`

---

#### Phase 4: Manifest, Configurator, Setup Refinement

**Commit:** `3e2739a` (4 files, 390 insertions)

- Updated `solutions-copilot.manifest.json` with all Phase 3 additions + maintainer profile
- Created `configurator/index.html` — self-contained HTML (no deps, no build)
  - Install mode toggle (global/workspace with path input)
  - Quick profile buttons (Full, Engineering, Product, Minimal, Maintainer)
  - Checkboxes for powers/skills
  - Generated command output + copy button + download user-config.json
- Refined `setup.sh` with `--uninstall`, `--verify`, `--status` modes
- Created `verify` script (shorthand)

---

#### Phase 5: T.I.M.E. Structure, Hooks, Metrics

**Commit:** `e9ec3d1` (11 files, 302 insertions)

- `scripts/detect-transition.py` — PostToolUse hook detecting lifecycle stage transitions (01-discovery → 05-shipped), returns AI action suggestions
- `product/products/gss/` — example product with full T.I.M.E. structure (README, steering, 00-context/vision.md, 01-discovery/ai-vendor-scoring.md)
- `scripts/metrics.py` — SQLite metrics logger at `~/.solutions-copilot/metrics.db`
- `status` — dashboard script showing MCP servers, environments, products, metrics

---

#### Kiro Format Alignment

**Commit:** `769458e` (7 files)

**Issues found from Kiro documentation:**
- `allowedTools` used wrong format (`solutions-intelligence.*` → should be `@solutions-intelligence`)
- `tools` field was just `["*"]` → should list explicit built-in tools + @server refs
- Agents had no `resources` with `skill://` references
- Orchestrator had no `hooks` section

**Fixed in all 10 agent JSON configs:**
- `allowedTools`: `@server` format (per Kiro docs)
- `tools`: explicit list of built-in tools + `@server` MCP references
- `resources`: added `file://` for POWER.md + `skill://` for on-demand skills
- Orchestrator: added `postToolUse` hook for T.I.M.E. detection

**Powers format (Kiro IDE):**
- Added `displayName`, `keywords`, `author` to all POWER.md frontmatter
- Confirmed: NO `mcp.json` needed (global MCP infra via setup.sh)
- Powers reference tools by name in instructions; tools already available from `~/.kiro/settings/mcp.json`

**Skills format (confirmed correct):**
- YAML frontmatter with `name` + `description` — matches Kiro docs exactly
- Loaded on demand via `skill://` URI in agent resources

---

#### Full-Fidelity Steering Migration

**Commit:** `7a49a4a` (87 files, 25,434 insertions)

**Source files downloaded from GitLab via glab API:**

| Source | Project ID | Branch | Files |
|--------|-----------|--------|-------|
| Jarvis power | 13490 (prod) | main | POWER.md + 19 steering |
| Atlas-developer | 13490 (prod) | main | POWER.md + 6 steering |
| Atlas-sql-forge | 13490 (prod) | main | POWER.md + 16 steering |
| Atlas-product-owner | 13490 (prod) | main | POWER.md + 10 steering |
| Atlas-ux-designer | 13490 (prod) | main | POWER.md + 9 steering |
| Jarvis-A11yFixer | 13491 (dev) | main | POWER.md + 5 steering |
| A11yAudit | 13490 (prod) | main | 9 steering |

**Tool name transformations applied (via sed):**
- `jarvis_get_app_tree` → `solutions-intelligence.get_app_overview`
- `jarvis_search_objects` → `solutions-intelligence.search_objects`
- `jarvis_get_cluster` → `solutions-intelligence.get_bundle`
- `jarvis_get_object_content` → `solutions-intelligence.get_object_code`
- `jarvis_get_context` → `solutions-intelligence.get_object_detail`
- `jarvis_get_dependency_chain` → `solutions-intelligence.get_dependencies`
- `jarvis_get_impact_analysis` → `solutions-intelligence.get_transitive_dependencies`
- `jarvis_get_data_model` → `solutions-intelligence.get_app_schema`
- `jarvis_get_patterns` → `solutions-intelligence.search_bundles`
- `jarvis_get_dead_code` → `solutions-intelligence.list_orphans`
- `jarvis_get_shared_objects` → `solutions-intelligence.get_hub_objects`
- `get_appian_object` → `lcp-api.getInterface`
- `evaluate_sail_expression` → `lcp-api.evaluateExpression`
- `search_objects_semantic` → `lcp-api.searchObjects`
- `get_object_dependencies` → `solutions-intelligence.get_dependencies`
- `get_jarvis_config` → `solutions-intelligence.list_applications`
- All `JARVIS`/`Jarvis`/`Atlas` branding removed
- `parentFolderId`/`kbFolderId` params removed

**Final power steering counts:**
- developer: 20 steering files (174-line POWER.md)
- sql-forge: 16 steering files (189-line POWER.md)
- product-owner: 10 steering files (114-line POWER.md)
- ux-designer: 9 steering files (140-line POWER.md)
- a11y-fixer: 5 steering files (112-line POWER.md)
- code-reviewer: 2 steering files (50-line POWER.md)
- qe-agent: 9 steering files (60-line POWER.md)

---

#### P1 Power Migrations (i18n, db-admin, doc-genie, TEA)

**Commit:** `ff615e5` (37 files, 11,268 insertions)

**Sources downloaded from:**

| Power | Source | Branch | Files |
|-------|--------|--------|-------|
| i18n | jarvis-i18n (prod 13490) | main | POWER.md + 4 steering |
| db-admin | jarvis-smt (prod 13490) | main | POWER.md + 6 steering |
| doc-genie | feature-docgenie (dev 13491) | meenakshi/feature-docgenie-power | POWER.md + 6 steering + 6 templates + CSS + script |
| TEA (qe-agent enrichment) | Engineering/Testing (dev 13491) | dp-test-execution-agent | 9 steering files (5,799 lines) |

**Results:**
- `engineering/powers/i18n/`: POWER.md + 4 steering
- `engineering/powers/db-admin/`: POWER.md + 6 steering
- `product/powers/doc-genie/`: POWER.md + 6 steering + 6 templates (`templates/`) + `styles/document.css` + `scripts/fix_table_borders.py`
- `engineering/powers/qe-agent/`: now has 18 steering files total (9 a11y-audit + 9 TEA)

---

#### Structure Refactoring

**Commit:** `76fd501` — Moved `products/` under `product/` (department grouping)
**Commit:** `172bd2a` — Removed `.DS_Store` files, deleted stray `{skills` folder
**Commit:** `8302483` — Updated `scripts/detect-transition.py` and `status` for `product/products/` path

---

#### Configuration Rewrite

**Commit:** `33f33c2` (6 files, 456 insertions)

Rewrote all configuration skills + agent prompts with real repo format:
- `configuration/skills/power-conventions/SKILL.md` (122 lines) — full POWER.md format, frontmatter, MCP server names
- `configuration/skills/steering-conventions/SKILL.md` (144 lines) — file structure, tool refs, execution trackers
- `configuration/skills/naming-conventions/SKILL.md` (63 lines) — no-codenames rule, per-type naming
- `configuration/agents/prompts/power-author-prompt.md` (48 lines) — 6-step creation workflow
- `configuration/agents/prompts/agent-author-prompt.md` (77 lines) — JSON format, @server syntax
- `configuration/agents/prompts/skill-author-prompt.md` (63 lines) — skill vs steering distinction

---

#### Git Workflow Steering

**Commit:** `2249c96` — Replaced with full version from solutions-os (remotes, mandatory rules, never rules, commit format)

---

#### Configurator Fix

**Commit:** `da76fd9` — Workspace mode now shows path input field, includes path in generated command and user-config.json

---

#### MCP Config Fix

**Commit:** `0899aa6` — `solutions-intelligence` now points to existing Atlas MCP server:
`registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest`

---

#### Manifest-Driven Setup

**Commit:** `45c6180` (120 insertions, 186 deletions)

- `setup.sh` fully rewritten to read `solutions-copilot.manifest.json`
- Python reads manifest → resolves profile → categories → powers/skills
- MCP config generated from `manifest.infrastructure.mcpServers`
- No more hardcoded case statements
- Adding a new power = one line in manifest

---

#### Decisions Made

| Decision | Reasoning |
|----------|-----------|
| No `mcp.json` in powers | Prevents duplicate Docker containers; MCP is global infra via setup.sh |
| `solutions-intelligence` as server name (not atlas) | No legacy codenames; functional naming |
| Points to Atlas MCP image for now | Intelligence server not built yet; Atlas is the current Cloud Plane |
| Manifest-driven setup.sh | Single source of truth; adding components = 1 line change |
| Powers as Kiro IDE format (not CLI agents) | Users are on Kiro IDE; powers with displayName/keywords for IDE picker |
| Skills loaded on-demand via `skill://` | Saves context window; loaded only when description matches |
| `product/products/` for T.I.M.E. folders | Groups by department (engineering/product/configuration) |
| Three-category structure | Clear separation: who is this for? |
| Steering files adapted (not copied raw) | Tool names must match new MCP servers; no Jarvis/Atlas references |

---

#### Learnings

- Kiro IDE powers need `displayName`, `keywords`, `author` in frontmatter
- Kiro CLI agents use `@server` format for allowedTools (not `server.*`)
- Skills need `name` + `description` in YAML frontmatter (both required)
- Steering files don't need frontmatter (loaded automatically), but can use `inclusion: manual`
- The `solutions-os` dev project (13491) has feature branches with SWAT content
- `glab api` with URL-encoded paths works for reading files from any branch
- `sed` bulk replacement is effective for tool name migration across 80+ files

---

#### Issues Encountered

| Issue | Resolution |
|-------|-----------|
| GitLab token lacks project creation scope | Git push auto-creates private projects on first push |
| `pip` blocked by PEP 668 on macOS | Used `python3 -m venv .venv` for isolation |
| Test count mismatch (18 vs 19 tools) | Fixed test assertion after counting |
| `.DS_Store` committed to git | Added to `.gitignore`, removed from tracking |
| Stray `{skills` folder created | Removed manually (wasn't tracked by git) |
| setup.sh ran Python block twice | Removed duplicate heredoc block |
| `solutions-intelligence` image didn't exist | Changed to existing Atlas MCP server image |
| Configurator didn't ask for workspace path | Added input field + show/hide toggle |

---

#### Remaining Items

- [ ] Migrate `locust-forge` power (from atlas-locust-forge, separate repo)
- [ ] Add remaining buildwithclaude skills (sites, web-apis, supporting-objects, expression-rules, interfaces, change-planning, change-review)
- [ ] Integrate SWAT steering additions (Sweep, Expression Assert, SAIL-to-SQL, ERD, Spec-to-Slides, FigJam, SAIL Canvas)
- [ ] Enrich `a11y-audit` skill with full 9-file ruleset from A11yAudit power
- [ ] Migrate 6 products to T.I.M.E. structure (from colin-hutchison branch)
- [ ] Create `kb-maintenance` skill (SWAT #17, Colin)
- [ ] Build the actual Solutions Intelligence Server (merge Cloud + Live planes)
- [ ] CI/CD pipeline for solutions-copilot repo
- [ ] Integration testing: run Kiro IDE with installed powers, verify agent routing works
- [ ] Wire configurator to read manifest via fetch() instead of inline data

---

#### Reference: Commit History

| Commit | Description |
|--------|-------------|
| `8fc5d81` | LCP MCP server initial (19 tools) |
| `1fa640c` | Solutions copilot scaffold |
| `0e8a384` | Phase 2 — orchestrator + 10 sub-agents |
| `cfcae94` | Phase 3 — skills & steering enrichment (14,680 lines) |
| `3e2739a` | Phase 4 — manifest, configurator, setup.sh refinement |
| `e9ec3d1` | Phase 5 — T.I.M.E. structure, hooks, metrics |
| `769458e` | Fix: Kiro IDE format alignment |
| `7a49a4a` | Full-fidelity steering migration (25,434 lines) |
| `ff615e5` | P1 migrations: i18n, db-admin, doc-genie, TEA (11,268 lines) |
| `76fd501` | Refactor: products/ → product/products/ |
| `172bd2a` | Chore: .DS_Store cleanup |
| `8302483` | Fix: scripts for product/products/ path |
| `33f33c2` | Configuration skills + prompts rewrite |
| `2249c96` | Git workflow steering (full version) |
| `da76fd9` | Configurator workspace path fix |
| `0899aa6` | MCP config: point to atlas image |
| `45c6180` | setup.sh manifest-driven |

---

#### Reference: Final Repo Structure

```
solutions-copilot/
├── .kiro/steering/git-workflow.md
├── engineering/
│   ├── powers/
│   │   ├── developer/ (POWER.md + 20 steering)
│   │   ├── sql-forge/ (POWER.md + 16 steering)
│   │   ├── code-reviewer/ (POWER.md + 2 steering)
│   │   ├── a11y-fixer/ (POWER.md + 5 steering)
│   │   ├── qe-agent/ (POWER.md + 18 steering)
│   │   ├── i18n/ (POWER.md + 4 steering)
│   │   └── db-admin/ (POWER.md + 6 steering)
│   ├── skills/
│   │   ├── sail-reference/ (SKILL.md + 23 references)
│   │   ├── appian-best-practices/ (SKILL.md + 5 references)
│   │   ├── appian-patterns/ (SKILL.md + 3 references)
│   │   ├── a11y-audit/ (SKILL.md)
│   │   └── appian-known-issues/ (SKILL.md + known-issues.yaml)
│   └── agents/ (5 JSON + 5 prompts)
├── product/
│   ├── powers/
│   │   ├── product-owner/ (POWER.md + 10 steering)
│   │   ├── ux-designer/ (POWER.md + 9 steering)
│   │   └── doc-genie/ (POWER.md + 6 steering + 6 templates + CSS + script)
│   ├── agents/ (2 JSON + 2 prompts)
│   └── products/
│       └── gss/ (T.I.M.E. example)
├── configuration/
│   ├── powers/ (power-author, skill-author, agent-author — placeholders)
│   ├── skills/ (power-conventions, steering-conventions, naming-conventions)
│   └── agents/ (3 JSON + 3 prompts)
├── orchestrator/ (solutions-copilot.json + prompt.md + routing-rules.md + capabilities.md)
├── scripts/ (detect-transition.py, metrics.py)
├── configurator/index.html
├── solutions-copilot.manifest.json
├── environments.json
├── setup.sh
├── verify
├── status
├── .env.example
└── README.md
```

**Total: 10 powers (96 steering files), 8 skills (30+ reference files), 11 agents, 5 MCP servers configured**
