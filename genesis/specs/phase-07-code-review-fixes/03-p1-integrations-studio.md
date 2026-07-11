# 03 — P1: Integrations Studio (MCP/CLI Modularity)

**Priority:** P1 (the core "Genesis is modular" vision) · **Layers:** `genesis-core`,
`genesis`, `kiro-agent-sdk` (small), `web` · **Soft-depends on:** `01` (store custom config in
the DB once it lands; a file store works meanwhile) · **Revises:** ADR-005, ADR-020 → **new
ADR-029**.

> Goal: make MCP servers and external CLIs **first-class, user-configurable integrations** that
> can be added, edited, secured, introspected, and tool-scoped **from the app's frontend** —
> without breaking the curated, reproducible library model for shared workflows.

---

## 1. Problem (current state, verified)

- **`genesis-core/mcp/registry.py` `McpRegistry`** is **read-only**: `load()`/`from_dict()` +
  `acp_servers(names)` (resolves `${VAR}` from the `SecretProvider`, ADR-004). No `save/add/write`.
- **`genesis-core/clis/registry.py` `CliRegistry`** — same, read-only.
- The registries are files installed from **`genesis-workflows`** into `~/.genesis/library/`.
  Governance = ADR-005 ("shared registry") + "add a server = MR to the library" + ADR-020 ("no
  global Kiro mutation").
- **Settings UI (07-04)** only: renders cards for servers **required by installed workflows**,
  sets **secrets** (`config/service.py::set_secret`), and runs a **readiness probe**
  (`test_server`: checks secret present + docker on PATH — *not* a live handshake).
- **Tool allow-listing** exists only at authoring time: `kiro_node(tools=[...])`
  (`genesis-core/nodes/agent.py`) → the SDK's `trust_tools`/`trust_all_tools`. **No** tool
  introspection anywhere; **no** UI to view/allow a server's tools.
- **API (`genesis/api/app.py`)** has **no** MCP/CLI create/update/delete route.

**Gap:** you cannot, from the app, add a custom MCP server (name + JSON config), set its secrets,
introspect and allow-list its tools, or add a custom CLI.

---

## 2. Goals / Non-goals

**Goals**
1. **Two-tier registry**: Tier-1 **curated** (library `mcp-registry.json`/`cli-registry.json`,
   read-only) + Tier-2 **custom** (user-writable, local), merged by name (custom overrides/extends).
2. **CRUD API** for custom MCP servers + CLIs.
3. A frontend **"Add / Edit MCP server"** flow: **name**, a **JSON config code editor**, a
   **Secrets** section (arbitrary keys), and a **Tools** tab that **introspects** the server's
   tools and lets you **mark which are allowed** (per-server allowlist). CLI parity (simpler).
4. **Tool introspection** via a direct MCP stdio client (agent-independent) → `tools/list`.
5. **Effective tool trust** at run time = `node.tools ∩ server.allowlist` (server allowlist is a
   hard cap; node stays a subset). Upgrade `/test` to a **real** handshake.

**Non-goals**
- No auth/RBAC/multi-tenant (ADR-026). Custom servers run locally with the user's privileges.
- No change to Tier-1 governance: curated servers stay read-only in the app (edit via MR).
- No remote/HTTP MCP transport in v1 (stdio launch only, matching current servers). HTTP MCP is a
  documented follow-on.

---

## 3. ADR-029 (revises ADR-005/020) — two-tier registry

**Decision.** Genesis resolves integrations from **two layers**:
- **Curated (Tier-1):** the library's `mcp-registry.json` / `cli-registry.json` — reproducible,
  MR-governed, **read-only in the app** (preserves ADR-005 for shared workflows).
- **Custom (Tier-2):** a **user-writable** local store (`~/.genesis/mcp-custom.json`,
  `~/.genesis/cli-custom.json`; migrated to the DB when `01` lands). Editable from the UI.

Resolution merges by name; a **custom entry with the same name overrides** the curated one
(with a visible "overrides curated" flag in the UI). ADR-020 is preserved: Genesis still never
writes a global Kiro `mcp.json` — custom servers are injected per-node via `acp_servers`, exactly
like curated ones. **Security note (recorded in the ADR):** a custom MCP server is an arbitrary
local command; this is acceptable for a local single-user tool but must be surfaced in the UI.

---

## 4. Backend design

### 4.1 `genesis-core` — writable custom store + merged registry

New `genesis_core/mcp/custom_store.py`:
```python
class CustomMcpStore:
    """Read/write store for user-defined MCP servers. v1 = JSON file at a path
    (mirrors secrets.json/environments.json); swap to a DB repo when spec 01 lands."""
    VERSION = 1
    def __init__(self, path): ...
    def list(self) -> dict[str, dict]: ...        # {name: server_spec}
    def get(self, name) -> dict | None: ...
    def upsert(self, name, spec: dict) -> dict: ...  # validates shape; sets source="custom"
    def delete(self, name) -> None: ...
    def set_allowlist(self, name, tools: list[str]) -> dict: ...
```
`server_spec` shape = the existing registry entry + additions:
```jsonc
{
  "command": "npx", "args": ["-y","@acme/mcp"], "env": {"ACME_TOKEN":"${ACME_TOKEN}"},
  "mode": "read-write", "secretKeys": ["ACME_TOKEN"], "publicKeys": ["ACME_REGION"],
  "note": "Acme MCP", "source": "custom",
  "tool_allowlist": ["search","read"]   // NEW: null/absent = all tools trusted
}
```

Extend `McpRegistry` (`genesis_core/mcp/registry.py`):
```python
@classmethod
def from_layers(cls, curated: dict, custom: dict, *, secrets=None, environments=None):
    merged = {**(curated.get("servers", curated)), **custom}  # custom overrides by name
    return cls(merged, secrets=secrets, environments=environments)

def allowlist(self, name: str) -> list[str] | None:
    return (self._servers.get(name) or {}).get("tool_allowlist")
```
`acp_servers(names)` unchanged except it may also surface each server's `tool_allowlist` so the
node can compute effective trust (see §4.4). `CliRegistry` gets an analogous `CustomCliStore` +
`from_layers`.

### 4.2 `genesis-core/mcp/introspect.py` — direct MCP tool discovery (agent-independent)

A minimal **MCP stdio client** (JSON-RPC 2.0 over newline-delimited stdio, same shape as the
SDK's ACP client but speaking MCP): spawn the server `command/args/env` (with `${VAR}` resolved),
send `initialize`, then `tools/list`, return the tool descriptors, and terminate. This does **not**
require Kiro — it talks to the MCP server directly, which is the correct layer for capability
discovery.

```python
@dataclass
class McpTool:
    name: str
    description: str = ""
    input_schema: dict | None = None

async def list_tools(spec: dict, *, secrets=None, environments=None,
                     startup_timeout=20.0) -> list[McpTool]:
    """Launch the MCP server from a resolved spec, MCP-handshake, return tools/list.
    Raises McpIntrospectError on spawn/handshake/timeout failure (surfaced to the UI)."""
```
Notes: resolve `${VAR}` via the same `McpRegistry._resolve` path (fail-fast on missing secrets);
enforce `startup_timeout`; always reap the subprocess in a `finally`. This is the single new piece
of real capability and is well-scoped.

### 4.3 `kiro-agent-sdk` — (minimal, optional)
Introspection is done in `genesis-core` (direct MCP), so **no SDK change is required** for tool
discovery. The SDK already exposes `trust_tools`/`trust_all_tools` (`KiroAgentOptions`). Only if we
later prefer routing introspection through Kiro would the SDK need a `list_mcp_tools()` — **out of
scope here**; recorded as an alternative.

### 4.4 Effective tool trust at run time
Today `kiro_node(tools=...)` sets `trust_tools=tools` or `trust_all_tools=True`. Change
(`genesis-core/nodes/agent.py`): compute **effective trust** per server as the **intersection** of
the node's requested tools and each server's `tool_allowlist`:
- node has no `tools` and server has no allowlist → `trust_all_tools=True` (unchanged).
- server has an allowlist → `trust_tools = (node.tools or allowlist) ∩ allowlist`,
  `trust_all_tools=False`.
- node has `tools` and server has none → `trust_tools = node.tools` (unchanged).

The server allowlist is thus a **hard cap** a workflow cannot exceed. `acp_servers()` returns the
allowlist alongside each server so the node can compute this without importing config.

### 4.5 `ConfigService` (`genesis/config/service.py`) — facade methods
```python
def custom_mcp_store(self) -> CustomMcpStore              # lazily built on settings.custom_mcp_path
def merged_mcp_registry(self) -> dict                     # curated ∪ custom (for cards/health/run)
def list_mcp_servers(self) -> list[dict]                  # [{name, source:'curated'|'custom', mode, overrides, has_secrets, allowlist, tools_known}]
def create_mcp_server(self, name, spec) -> dict           # custom only; 409 if curated name w/o override intent
def update_mcp_server(self, name, spec) -> dict           # custom only
def delete_mcp_server(self, name) -> None                 # custom only
async def introspect_mcp_server(self, name) -> list[dict] # via introspect.list_tools; requires secrets set
def set_mcp_allowlist(self, name, tools) -> dict          # custom store
def test_server(self, name) -> dict                       # UPGRADE: real handshake (see §4.6)
# CLI parity:
def custom_cli_store(self); list_clis(); create_cli(); update_cli(); delete_cli()
```
The MCP-card/health/run paths switch from `mcp_registry()` to `merged_mcp_registry()` so custom
servers get secret cards + health + injection automatically.

### 4.6 Upgrade `test_server` to a real handshake
Replace the readiness-only probe with: resolve spec → `introspect.list_tools()` with a short
timeout. `ok` iff the MCP handshake succeeds (and returns tools). Fall back to the current
readiness reasons (missing secret, docker absent) **before** attempting launch (fail-fast, cheap).
Returns `{server, ok, reason, tool_count, checked_at}`; never returns secret values.

### 4.7 API routes (`genesis/api/app.py`, under `/api`)
```
GET    /api/config/mcp-servers                 -> list_mcp_servers()
POST   /api/config/mcp-servers                 -> create_mcp_server(name, spec)   (body: {name, spec})
PUT    /api/config/mcp-servers/{name}          -> update_mcp_server(name, spec)
DELETE /api/config/mcp-servers/{name}          -> delete_mcp_server(name)
POST   /api/config/mcp-servers/{name}/tools    -> introspect_mcp_server(name)     (async; returns [{name,description}])
PUT    /api/config/mcp-servers/{name}/allowlist-> set_mcp_allowlist(name, tools)  (body: {tools:[...]})
POST   /api/config/mcp-servers/{name}/test     -> test_server(name)               (UPGRADED)
# CLI parity:
GET/POST/PUT/DELETE /api/config/clis[/{name}]
```
Validation: reject creating/deleting a **curated** server (409 with a clear message: "curated
servers are managed via the library"). Validate the spec JSON server-side (required
`command`; `args`/`env` types; `mode` enum) and return field-level errors (mirror
`InputValidationError` handling).

### 4.8 Settings paths (`genesis/runtime/settings.py`)
Add properties: `custom_mcp_path = state_dir / "mcp-custom.json"`,
`custom_cli_path = state_dir / "cli-custom.json"`. (When `01` lands, back these with a DB repo
behind the same `CustomMcpStore` interface.)

---

## 5. Frontend design (Settings → "Integrations")

`RootLayout` already labels Settings as **"Integrations"** — this section makes that real. Add a
`web/src/lib/api/integrations.ts` resource + `useMcpServers/useCreateMcpServer/...` hooks
(TanStack Query, invalidate on mutate).

### 5.1 Code editor dependency (new)
ADR-027 includes `shiki` (highlighting) but **no editor**. Add **CodeMirror 6** via
**`@uiw/react-codemirror`** + `@codemirror/lang-json` (lightweight, tree-shakeable, TS-first) as an
ADR-027 addendum. Used for the JSON config field (and reusable by the HITL Edit-State/Fork dialogs).

### 5.2 MCP Servers section (`features/settings/components/McpSection.tsx` — extend)
- List all servers from `GET /mcp-servers` with a **source badge** (`Curated` read-only vs
  `Custom` editable) and status (configured / missing secret / unknown).
- **"Add MCP server"** button → dialog:
  - **Name** (validated: lowercase/digits/hyphen, matching the secret scope grammar).
  - **Config** — a **CodeMirror JSON editor** prefilled with a template
    (`{command, args, env, mode, secretKeys, publicKeys, note}`), live JSON validation + a "format"
    action. On save → `POST /mcp-servers`.
  - Security callout: "Custom servers run a local command with your privileges."
- **Detail view** (`McpServerDetail`, extend) with tabs:
  - **Config** (custom only): the JSON editor (`PUT`); curated shows read-only JSON.
  - **Secrets**: reuse the existing secret-field UI (never pre-fills values; `POST /config/secrets`).
  - **Tools**: a **"Discover tools"** button → `POST /mcp-servers/{name}/tools`; renders the tool
    list with checkboxes; **Save allowlist** → `PUT /allowlist`. Shows "all tools trusted" when no
    allowlist. Disabled with guidance if required secrets are unset.
  - **Test**: runs the real handshake; shows ok/reason + tool count.
- Delete (custom only) with confirm.

### 5.3 CLI section (`features/settings/components/CliSection.tsx` — extend)
Parity, simpler: list curated + custom CLIs (availability from `which`); "Add CLI" dialog
(`name`, `binary`, `version_check`, `install_hint`, `note`); edit/delete custom only.

### 5.4 Tests (MSW)
- List renders curated (read-only) + custom (editable) with correct badges.
- Add-server dialog validates JSON + name; POST payload shape asserted.
- Tools tab: discover → checklist → save allowlist payload asserted.
- Curated server shows read-only config + no delete.
- jest-axe pass on dialogs (Radix Dialog `aria-describedby`).

---

## 6. Files touched (by repo)

**genesis-core**
| File | Change |
|------|--------|
| `mcp/custom_store.py` | **new** `CustomMcpStore` |
| `mcp/introspect.py` | **new** direct MCP stdio client + `list_tools` |
| `mcp/registry.py` | add `from_layers`, `allowlist()`; surface allowlist in `acp_servers` |
| `clis/registry.py` + `clis/custom_store.py` | **new** custom CLI store + `from_layers` |
| `nodes/agent.py` | effective-trust intersection (node ∩ server allowlist) |
| `tests/test_core_units.py` | merge/override, allowlist intersection, introspect (stubbed subprocess) |

**genesis**
| File | Change |
|------|--------|
| `config/service.py` | merged registry + custom CRUD + introspect + allowlist + real `test_server` |
| `runtime/settings.py` | `custom_mcp_path`, `custom_cli_path` |
| `api/app.py` | new `/config/mcp-servers*` + `/config/clis*` routes; upgraded `/test` |
| `tests/test_config.py`, `tests/test_api.py` | CRUD + introspect (stubbed) + real-test-fallback |

**kiro-agent-sdk**: none required (introspection is core-side). Recorded alternative only.

**web**
| File | Change |
|------|--------|
| `lib/api/integrations.ts`, `lib/query/keys.ts`, `lib/api/index.ts` | resource + keys |
| `features/settings/components/McpSection.tsx`, `McpServerDetail.tsx` | add flow + tabs |
| `features/settings/components/CliSection.tsx` | custom CLI CRUD |
| `features/settings/components/JsonEditor.tsx` | **new** CodeMirror wrapper |
| `package.json` | add `@uiw/react-codemirror` + `@codemirror/lang-json` |
| `features/settings/settings.test.tsx` | extend |

---

## 7. Security & safety (must-haves)
- **Arbitrary exec disclosure:** the add/edit dialog must state that a custom MCP server launches a
  local command with the user's privileges. No silent creation.
- **Secrets:** custom-server secrets flow through the existing `SecretProvider` (`scope/VAR`,
  0600) — values never returned by any endpoint; only key names/booleans surface (unchanged model).
- **Introspection sandbox:** `list_tools` enforces `startup_timeout`, always reaps the subprocess,
  and never logs resolved secret values.
- **Allowlist is a hard cap:** a workflow node can only ever trust tools within the server's
  allowlist (§4.4) — a safety win over today's node-only trust.

---

## 8. Definition of Done
- **Core:** merged registry (custom overrides curated), allowlist intersection, and `list_tools`
  (subprocess stubbed) unit-tested; `pytest`+`ruff` green.
- **genesis:** full MCP/CLI CRUD + introspect + allowlist + upgraded `/test` tested (introspection
  subprocess stubbed offline); a custom server added via API appears in cards/health/injection.
- **web:** add/edit/secrets/tools/allowlist flows work against MSW; `tsc`+`vitest`+`build` green;
  `web/static/` untouched; jest-axe clean.
- **ADR-029** written into `reference/decision-log.md`; ADR-005/020 annotated as revised.
- **Manual e2e:** add a real local MCP server (e.g. an `npx` echo/filesystem MCP), set a secret,
  discover tools, allow-list a subset, run a workflow node that uses it, and confirm only allow-listed
  tools are trusted.

---

## 9. Risks & deviations
- **Deviation from ADR-005** (registry-via-MR only) is intentional and captured in ADR-029; curated
  tier stays governed.
- **MCP protocol drift:** the introspect client must be tolerant (like the ACP client is) to naming
  variance across MCP server versions; cover with a stubbed-subprocess test.
- **Soft dep on `01`:** custom config is a JSON file until the DB lands; the `CustomMcpStore`
  interface is the seam so the swap is internal.
- **Scope guard:** stdio transport only in v1; HTTP/remote MCP is a follow-on.

## 10. Estimate
~3–5 days (mini-phase): core store + introspect + registry/agent changes (1–1.5d); genesis CRUD +
API + upgraded test + tests (1–1.5d); frontend Studio (editor + tabs + tests) (1.5–2d). One release
each of genesis-core + genesis; one frontend commit series. Sequence the SDK-free core work first.
