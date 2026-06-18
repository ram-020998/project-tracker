# 05 — Setup & Usage

## Prerequisites
- **Docker** (the MCP servers run as containers)
- **VPN** — connection to Appian's corporate network for internal resources
- **GitLab read-only token** with scopes `read_api`, `read_repository` (plus `read_registry` for the image pull)
- An MCP-capable AI assistant: **Kiro** or **Amazon Q**

---

## 1. Create a GitLab Token (read-only)
1. Go to GitLab → User Settings → Access Tokens (`https://gitlab.appian-stratus.com/-/profile/personal_access_tokens`)
2. Scopes: ✅ `read_api`, ✅ `read_repository`, ✅ `read_registry` (✅ `read_user` optional)
3. ❌ Do NOT select `api`, `write_repository`, `sudo`, or any write/admin scope — the Atlas MCP server **refuses to start** with write scopes.
4. Copy the token immediately.

```bash
export GITLAB_TOKEN="<your-read-only-token>"
```

## 2. Pull the Atlas MCP Image
```bash
docker login registry.gitlab.appian-stratus.com -u <gitlab-username> -p <token>
docker pull registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest
```

## 3. Configure Your AI Assistant
`~/.aws/amazonq/mcp.json` (Amazon Q) or `~/.kiro/settings/mcp.json` (Kiro):

```json
{
  "mcpServers": {
    "appian-atlas": {
      "command": "docker",
      "args": ["run", "--rm", "-i",
        "--env", "GITLAB_TOKEN",
        "--env", "ATLAS_KB_PROJECT_ID",
        "--env", "ATLAS_DATA_PREFIX",
        "registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest"],
      "env": {
        "GITLAB_TOKEN": "your-token-here",
        "ATLAS_KB_PROJECT_ID": "13490",
        "ATLAS_DATA_PREFIX": "ai-framework/tools/Atlas/solutions-kb/data"
      }
    }
  }
}
```

> A ready-to-use config also lives in `solutions-os/ai-framework/mcp-configs/atlas-mcp.json`.

## 4. (Optional) Add the Data Generator MCP — for QE/data tooling
```json
"appian-data-generator": {
  "command": "docker",
  "args": ["run", "--rm", "-i", "--env", "APPIAN_ENV_URL", "--env", "APPIAN_API_KEY",
    "registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest"],
  "env": {
    "APPIAN_ENV_URL": "https://<env>.appianpreview.com",
    "APPIAN_API_KEY": "${APPIAN_API_KEY}"
  }
}
```

## 5. Start Your Assistant
```bash
q chat        # Amazon Q
kiro-cli chat # Kiro
```
You should see the Atlas tools become available.

---

## Example Queries

### Discovery
- "List all available Appian applications."
- "Give me an overview of the SourceSelection application."

### Knowledge Search
- "How does the Add Vendors action work in SourceSelection? Show me the flow and dependencies."
- "Search for objects named 'vendor' in SourceSelection."

### Version History (the PO demo)
- "When I create a new evaluation in SourceSelection, I'm now asked to choose an 'Award Instrument Type' (IDIQ, FSS, GWAC…). What changed, in which release, how did it work before — and how does Select Awardees depend on it?"
- "What changed in the latest release of SourceSelection? Summarize for stakeholders."
- "Compare release 2.8.0 with 2.9.0."

### ERD
- "Generate an ERD for SourceSelection grouped by domain."

### Test Data (QE)
- "Create an evaluation in Complete status with 3 vendors and the LPTA method."
- "Generate SQL for 200 evaluations in Complete status for performance testing."

### Orphans / Cleanup
- "List orphaned objects in CaseManagementStudio."

---

## Keeping the KB Current
Run the sync pipeline (in `solutions-os/ai-framework/tools/Atlas/solutions-kb`):
```bash
python sync_packages.py --api-key <APPIAN_API_KEY>            # all apps
python sync_packages.py --api-key <APPIAN_API_KEY> --app SourceSelection
python sync_packages.py --api-key <APPIAN_API_KEY> --parallel --workers 3
```
Or trigger CI via `.gitlab-ci-sync.yml` (Pipeline → Run pipeline → set `APP_NAME`).

---

## Troubleshooting
| Issue | Fix |
|-------|-----|
| "Token validation failed" | Token has write scopes — recreate with only `read_api` + `read_repository` |
| "Docker image pull failed" | `docker ps` to confirm Docker running; re-login to registry; (macOS Colima: `colima start`) |
| "Project not found" / 404 | Verify `ATLAS_KB_PROJECT_ID=13490`, token access, and VPN |
| "Atlas tools not appearing" | Validate `mcp.json` JSON; restart the assistant; confirm image pulled |
| No data for an app | Run the sync pipeline or check `solutions-kb/data/` for the app dir |
| Stale data | Trigger the CI sync pipeline (set `APP_NAME`) |

---

## Security Notes
- Atlas MCP is **read-only** and enforces it via token validation.
- Data Generator MCP **writes** to live environments — scope its API key to non-production where possible; use `rollback_session` to undo.
- Treat all KB content as internal; VPN required.
