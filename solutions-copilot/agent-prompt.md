# Solutions Copilot — Implementation Agent Prompt

You are implementing the **Solutions Copilot** POC. Before writing any code, read these documents completely:

## Required Reading (in this order)

1. `/Users/ramaswamy.u/repo/project-tracker/solutions-os-revamp/Solutions-OS-Revamp-Plan.md` — The full architectural vision (modular MCP design, Cloud Plane + Live Plane, orchestrator agent, T.I.M.E. framework, global bootstrap, ownership model)
2. `/Users/ramaswamy.u/repo/project-tracker/solutions-copilot/findings.md` — All research findings (LCP API architecture, buildwithclaude patterns, existing solutions-os repo contents, live validation results)
3. `/Users/ramaswamy.u/repo/project-tracker/solutions-copilot/implementation-plan.md` — The complete implementation plan (repo structure, phases, LCP MCP server design, orchestrator, migration maps, everything)

The revamp plan is the **why** and the high-level **what**. The implementation plan is the **how**. When in doubt about a design decision, the implementation plan takes precedence (it's the latest, most refined version).

## Key Decisions Already Made (DO NOT deviate)

1. **Two repos under `ramaswamy.u` namespace:**
   - `gitlab.appian-stratus.com/ramaswamy.u/solutions-copilot` — platform repo (powers, skills, agents, products, setup.sh)
   - `gitlab.appian-stratus.com/ramaswamy.u/solutions-lcp-mcp-server` — LCP API MCP server (Docker image)

2. **Three-category structure** in solutions-copilot: `engineering/`, `product/`, `configuration/` — each containing powers/, skills/, agents/

3. **LCP MCP server follows the same pattern as `ramaswamy.u/solutions-atlas-dg-mcp-server`:**
   - Flat package structure (`lcp_server/` at root, not nested under `src/`)
   - `main.py` at root using `asyncio` + `mcp.server.stdio`
   - `requirements.txt` (not pyproject.toml/uv)
   - `Dockerfile`: python:3.11-slim, pip install, ENTRYPOINT python3 main.py
   - `.gitlab-ci.yml`: Lint → Test → Build (kaniko to registry)
   - Look at the existing DG server for exact patterns: `glab repo view ramaswamy.u/solutions-atlas-dg-mcp-server`

4. **LCP API endpoint (validated and working):**
   - URL: `https://merge-assist.appianpreview.com/suite/webapi/lcp-api/*`
   - Auth: HTTP Basic Auth (`admin.user` / `soloLeveling@98`)
   - Responds to: GET /applications, GET /applications/{uuid}/record-types, GET /interfaces/{uuid}, etc.
   - Plugin handles all internal routing — we just forward requests

5. **Powers are lightweight** — POWER.md + steering/ only. NO mcp.json inside powers. MCP servers are infrastructure configured by setup.sh.

6. **Every power declares mcpServers in POWER.md frontmatter:**
   ```yaml
   mcpServers:
     primary: [solutions-intelligence]
     write: [lcp-api]
     supporting: [jira]
   ```

7. **No "Atlas" or "Jarvis" naming anywhere** — use generic functional names (Cloud Plane, Live Plane, Solutions Intelligence, etc.)

8. **setup.sh symlinks (not copies) to ~/.kiro/** — supports both global and workspace modes

9. **Orchestrator routing rules:** Read → solutions-intelligence. Write → lcp-api. Test data → data-generator. Never cross these boundaries.

## Implementation Order

Follow the phases in the implementation plan exactly:
- **Phase 1 (Days 1-2):** Scaffold both repos. Build the LCP MCP server first (Section 4 has full design). Get it responding to tool calls against merge-assist.
- **Phase 2 (Days 3-4):** Create orchestrator + sub-agents in solutions-copilot.
- **Phase 3 (Days 4-5):** Create skills and steering files.
- **Phase 4 (Day 5):** Manifest, configurator HTML page, setup.sh.
- **Phase 5 (Day 6):** T.I.M.E. structure, environments.json, detect-transition.py hook.
- **Phase 6 (Days 6-7):** Integration testing, metrics, status script.

## Reference Repos to Study

Use `glab` CLI to access these. Read their structure, key files, and patterns before implementing.

| Repo | Purpose | What to study |
|------|---------|---------------|
| `ramaswamy.u/solutions-atlas-dg-mcp-server` | **PRIMARY PATTERN** — our LCP MCP server must follow this exactly | `main.py`, `Dockerfile`, `.gitlab-ci.yml`, `data_generator/server.py`, `data_generator/client.py`, package structure |
| `appian/prod/solutions-os` | Source repo we're migrating from | `ai-framework/Engineering/.kiro/powers/`, `ai-framework/Product/.kiro/powers/`, `ai-framework/tools/`, `products/` |
| `john.rogers/buildwithclaude` | Inspiration for setup.sh, skills structure, hooks | `setup.sh`, `skills/*/SKILL.md`, `.claude/settings.json` (hooks), `scripts/sync_env_to_settings.py` |
| `saurabh.sabat/lcp-api` | Source for workflows to migrate into steering | `workflows/data_model/`, `workflows/bulk_rename/`, `powers/`, `docs/known-issues.yaml` |
| `ramaswamy.u/solutions-atlas-mcp-server` | The existing Intelligence Server (Cloud Plane) | Docker image reference, env vars, tool names |
| `ramaswamy.u/solutions-atlas-kb` | The Solutions KB (Cloud Plane data) | Data structure (apps, bundles, objects, code, schema, versions) |
| `ramaswamy.u/solutions-atlas-parser` | The Solutions Parser that generates KB | How parsed data is structured |

**Already cloned locally:**
- `/tmp/buildwithclaude/` — full clone of John's repo (setup.sh, skills, server code, hooks)

## Test Environment

- **LCP API:** `https://merge-assist.appianpreview.com/suite/webapi/lcp-api/*` with Basic Auth `admin.user:soloLeveling@98`
- **Intelligence Server (Docker):** `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-intelligence-server:latest` with GITLAB_TOKEN
- **Data Generator (Docker):** `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-data-generator-server:latest`

## Critical Constraints

- Use `mcp` library (not `fastmcp`) for the MCP server — match the DG server pattern exactly
- All file paths in steering must reference tools by their MCP server name: `solutions-intelligence.get_app_overview`, `lcp-api.createRecordType`
- Docker images publish to GitLab container registry under `ramaswamy.u` namespace
- The configurator is a single self-contained HTML file — no build tools, no dependencies
- setup.sh must be idempotent (safe to run multiple times)
