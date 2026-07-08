# Genesis — MCP & CLI Registry Reference

The shared registries (ADR-005) are the single place that defines *how* external
capabilities are launched and *what secrets* they need. Workflows reference them
by name; nodes never define servers/CLIs ad hoc.

---

## 1. `mcp-registry.json`

### 1.1 Schema
```jsonc
{
  "version": 1,
  "servers": {
    "<server-name>": {
      "command": "docker",                 // or "npx", etc.
      "args": ["run","--rm","-i", "..."],  // launch argv (may contain --env NAME)
      "env": { "VAR": "${VAR}" | "literal" },
      "mode": "read-only" | "read-write" | "read-write-deploy" | "read-write-data" | "integration",
      "secretKeys": ["VAR", ...],          // env keys that are secrets (drive the config UI)
      "publicKeys": ["VAR", ...],          // env keys that are non-secret (may have literal defaults)
      "note": "optional"
    }
  }
}
```
- `${VAR}` in `env` is resolved at run time (SecretProvider → environment → literal default). Unresolved required var ⇒ fail fast before spawning Kiro.
- `secretKeys`/`publicKeys` classify env for the Phase-4 config UI (secret cards vs prefilled defaults).
- `mode` drives safety posture: write/deploy servers get stricter node defaults + mandatory HITL gates before mutations.

### 1.2 Known servers (initial catalog)
| Name | Mode | Purpose | Key env |
|---|---|---|---|
| `appian-atlas` | read-only | Appian code intelligence over Atlas KB (schema, objects, deps) | `GITLAB_TOKEN`(secret,global), `ATLAS_KB_PROJECT_ID`, `ATLAS_DATA_PREFIX` |
| `jarvis` | read-write-deploy | Live Appian env: query_sql, evaluate_sail, write, deploy | `APPIAN_BASE_URL`, `APPIAN_API_KEY`(secret), `JARVIS_SITES_CONFIG` |
| `appian-data-generator` | read-write-data | Test/demo data CRUD + rollback | `APPIAN_ENV_URL`, `APPIAN_API_KEY`(secret) |
| `lcp` | read-write | **Appian design-object authoring** (record types, interfaces, process models, sites…) — the OD-1 unlock | `APPIAN_ENV_URL`/creds (TBD from LCP MCP) |
| `jira` | integration | Jira read/write via jira-mcp-proxy | `JIRA_URL`, `JIRA_EMAIL`(public), `JIRA_TOKEN`(secret) |

(Extend as workflows require. `google-workspace`, `playwright` can be added when wired.)

### 1.3 Per-node injection
`ctx.mcp.acp_servers(names)` returns the ACP `session/new` `mcpServers` entries
for exactly the named servers, with `${VAR}` resolved. A node lists only what it
needs (e.g., `kiro_node(..., mcp=["appian-atlas"])`). Genesis never writes a
global Kiro `mcp.json` (ADR-020).

---

## 2. `cli-registry.json`

### 2.1 Schema
```jsonc
{
  "version": 1,
  "clis": {
    "<cli-name>": {
      "binary": "erd-gen",
      "version_check": ["erd-gen", "--version"],
      "install_hint": "curl -fsSL https://.../install.sh | bash",
      "config_check": ["erd-gen", "config", "--check"],   // optional readiness probe
      "note": "optional"
    }
  }
}
```
- `ctx.clis.ensure(name)` verifies presence (and surfaces `install_hint` if missing).
- `ctx.clis.run(name, argv)` executes and returns the completed process for a `cli_node`'s `parse_fn`.

### 2.2 Known CLIs (initial)
| Name | Purpose |
|---|---|
| `erd-gen` | Generate + publish ERDs to Lucidchart (Phase 6) |
| (future) `acli` | Jira/Confluence CLI (note: redirect stdout to a temp file — solutions-copilot steering) |

---

## 3. Secrets & environments (cross-ref)
- Secret values are **never** stored in the registries — only key *names* + classification. Values live in the SecretProvider (`~/.genesis/secrets.json`, `0600`), keyed `scope/VAR` (see `security-and-secrets.md`).
- Environment targeting (e.g., which Appian env `jarvis`/`lcp` hits) resolves from the credential-free environment registry by label (`state`/`inputs` may carry the chosen label).

---

## 4. Governance
- Adding a server/CLI = editing the registry in `genesis-workflows` (reviewed via MR) — no platform code change (manifest-driven, like solutions-copilot).
- Write/deploy servers (`jarvis`, `lcp`, `appian-data-generator`) must only be used by nodes that are followed by validators and preceded by HITL approval gates for mutations (see `reliability-standard.md` + `hitl-design.md`).
- CI validates that every `required_mcp`/`required_cli` in a workflow exists in the registries (Phase 2).
