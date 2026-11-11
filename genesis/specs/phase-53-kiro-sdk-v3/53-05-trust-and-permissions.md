# 53-05 — Trust and permissions: agent projection, tool ids, permission ladder

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (`packages/kiro-agent-sdk`). Parent:
> `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D3 (#7, #8, #11, #14), D6, D9; F2, F5, F8, F9, F11. Uses 53-02 W3,
> W4, W12, W15, W18.

## 1. Goal

Turn a Genesis trust decision into a v3 custom agent the engine enforces, and answer every permission request through
one ladder that cannot widen it. This is where ADR-031's fail-closed chat and ADR-029's cap live on v3.

## 2. `TrustPolicy` (public)

```python
@dataclass(frozen=True)
class TrustPolicy:
    builtins: tuple[str, ...]          # Genesis names: "shell", "fs_read", "fs_write", "grep", "glob", "web_fetch", "web_search"
    mcp_tools: tuple[str, ...]         # "@server/tool" or "@server" (whole server), servers from session/new.mcpServers
    auto_approve: tuple[str, ...]      # the subset approved without asking (names as above)
    mode: str                          # "auto_deny" | "ask" | "auto_approve" — the answer for everything else
```

Callers build it (53-06 for nodes from D9, 53-07 for chat from F2). It has no "all tools" value: `mcp_tools=("@srv",)`
means every tool of that server, and only servers the caller sent are reachable.

## 3. Projection (`agent_spec.py`, private)

`project(policy, *, agent_id, prompt) -> dict` builds one `customAgents` entry (KiroCrew `acp/kas_agents.py` as
reference):

- `id`: `agent_id`, renamed if it collides with an engine built-in mode id (`vibe`, `spec`, `quick-spec`, `bug-fix`,
  `plan`, `autonomous`, `semantic_reviewer` on 2.37.1, 53-02 W4; the fixture's `reserved_mode_ids` is the source); `prompt`: inline text (never a `file://`); `description`.
- `tools`: **always explicit** (absent = no tools): each built-in name expanded through the tool-id fixture (§4) to its
  v3 registered ids (`fs_read` → `read_file`, `list_directory`; `fs_write` → `fs_write`, `str_replace`, `fs_append`;
  `shell` → `execute_bash`; `grep` → `grep_search`; `glob` → `file_search`; `web_search` → `remote_web_search`;
  `web_fetch` → `web_fetch`) + each MCP entry as `@server/tool` or `@server`. `delete_file` is never projected (D9).
- `permissions.rules`: one `{capability: "mcp", match: [...], effect: "allow"}` for the MCP entries in `auto_approve`
  (`@srv` → `srv/*`, `@srv/tool` → `srv/tool`; a glob or empty server name is refused, never widened); one `allow` per
  built-in capability in `auto_approve` (`shell`, `fs_read`, `fs_write`, `web_fetch`, `web_search`); capabilities come
  only from this fixed list, because the engine accepts a misspelt capability silently and the rule then never matches
  (53-02 W15); never the meta
  capabilities `all`, `builtin`, `filesystem`; nothing else, so every other request reaches the client as `ask`.
  Listing a capability never adds a tool: `delete_file` asks under `fs_write`, but it is absent from `tools`, so the
  model cannot call it. **`fs_read` path scope: none in this phase (D16).** The built-in allow rules use
  `match: ["**"]`, so reads reach any path the user can, as today. Confinement is Phase 52's; 53-02 W15's path-rule
  findings are its input.
- `includeMcpJson: false`, `includePowers: false` (explicit; D6 already hides the user's files).
- Limits: ≤ 64 patterns per rule (split), ≤ 50 agents (one per session here).

## 4. Tool-id fixture (`tool_ids.json`, package data) (D3 #11, F5)

Built from 53-02's `tests/fixtures/v3/tool-ids.json` (kiro-cli 2.37.1, KAS 0.66.70; the W15 table in 53-02's As built):
per built-in its registered id, permission `toolId`, `consent.capability`, `kind` and `toolCallId` prefix. For
example, the shell is listed as `execute_bash` but asks as `run_command`; `remote_web_search` asks as itself with kind
`other` and capability `web_search`. Also the meta tools, the rule capabilities and effects, and the reserved mode ids.
Shape:
`{kiro_cli_verified: ["2.37.1", …], builtins: {genesis_name: {registered: [...], permission_tool_id: [...],
capability}}, meta_tools: ["tool_load", "tool_call", "disclose_context"], reserved_mode_ids: [...]}`. MCP tools ask as
`mcp_<server>_<tool>`; identity still comes from `mcpTool.identity`.
`tool_ids.verified(version) -> bool`; `kiro_agent_sdk.check_kiro()` (used by preflight, 53-08) returns
`{installed, version, engine_v3, minimum_ok, verified}`. A start on an unverified newer version logs one warning per
version per process.

## 5. Permission ladder (`permissions.py`, private)

For each `session/request_permission`, answered exactly once:

1. **Identity** from the engine's `_meta.kiro`: `toolId` (built-ins, mapped back to the Genesis name by the fixture's
   **permission** id, which can differ from the listed id: the shell is listed as `execute_bash` but asks as
   `run_command`, with `consent.capability: "shell"`, 53-02 W3), `mcpTool.identity {serverName, toolName}` (MCP). Never
   from `toolCall.title` (the model can influence it). No readable identity → **deny**. The request itself carries no
   `kind`; `raw_input` and `kind` come from the `tool_call` with the same `toolCallId`, which arrives 15–55 ms earlier.
2. **Backstop:** the identity must be in the policy's `builtins` or `mcp_tools`; else **deny** (the engine should not have
   asked; this catches a projection bug or an engine change). **One exception, skill loads (D18):** a request whose
   `_meta.kiro.toolId` is `disclose_context` **and** whose `consent.capability` is `skill` is approved in every mode,
   never by its title. Under D6–D8 the engine can offer only skills Genesis provisioned. No skill rule is projected
   and `TrustPolicy` has no skills field. Bypass corpus: a `Load skill:` title with another `toolId`, `capability:
   skill` with another `toolId`, and `disclose_context` with another capability are all denied.
3. **Answer by mode:** in `auto_approve` → the `allow_once` option; `auto_deny` → the `reject_once` option; `ask` → the
   caller's `on_permission(PermissionRequest)` (shape unchanged, F1; `tool_name` = `@server/tool` or the Genesis built-in
   name; `raw_input` from the correlated `tool_call` by `toolCallId`), fail closed on timeout / error / unknown option
   (as today, `client.py:460-485`).
4. **Refusal notice** (D3 #8, F11): on a Genesis deny, before answering, send a fixed, cause-specific message into the
   turn with `_session/steer` (53-02 W7; text only, delivered after the running tool call ends), e.g. read-only chat "This chat is read-only; <tool> is not available here.",
   outside policy "<tool> is not available to this step." Text is static per cause, never built from tool arguments.
   Prefer the clean `reject_once` option (the turn continues) over `cancelled` (ends the turn), as KiroCrew records.
- `fs/write_text_file` keeps its own gate (`allow_fs_write`, `fs_write_root`; L-041): two independent checks. 53-02 P9
  showed v3 still writes through the client.

## 6. Elicitation (D3 #7, F8)

The engine's request is `_kiro/mcp/elicitation {sessionId, toolCallId, elicitation: {mode: "form", message,
requestedSchema}}` (53-02 W18; not `elicitation/create`). It is answered `{action: "decline"}` in every session (the
engine passes it to the server unchanged) with a notice on the turn
("<server> asked for input; Genesis does not support MCP input requests yet."). A chat form is backlog.

## 7. Access-token requests (D3 #14, F9)

With `auth_method="client"`, the engine sends `_kiro/auth/getAccessToken {}` right after start (53-02 W12). The SDK
calls `on_access_token()` and answers `{accessToken, expiresAt (ISO 8601), profileArn, authMethod, provider}`.
`profileArn` is required for an IdC/enterprise login: without it every model call fails (`ModelRegistryUnavailableError`).
The engine asks again when the token is within 180 s of expiry. The SDK never logs or stores the token or the ARN, and
it fails the request (classified `not_signed_in`) when the callback is missing or raises. With no answer at all,
`session/new` still succeeds and the first prompt fails "not signed in". Not used by Genesis in this phase (Phase 52
wires it, 52-01 D8). Tested with the `access-token` fixture.

## 8. Tests

Turn off the fake engine's `customAgents` skip (53-04 §1 item 5) so every replay checks the projected agent. The
recorded agents are bare spike agents, so the check is structural, not byte for byte (D19): every received agent
passes the W4 schema rules (`tools` a list of strings; rule `effect` in `allow|deny|ask|evaluate`) and the Genesis
rules (explicit `tools`, no `delete_file`, capabilities only from the fixed list, no globs, `includeMcpJson` and
`includePowers` false). Where a fixture recorded an agent, `id` and `prompt` match, every recorded tool and rule is
present, and extra keys come only from `description`, `permissions`, `includeMcpJson`, `includePowers`. **Live
schema probe (D19, no prompt, 0 credits):** send the projection of every 53-06/53-07 caller shape to the installed
kiro-cli and record that each activates (`availableModes` entry + `config_option_update`); record the frames as a
fixture. Projection golden tests (policy → entry) for every 53-06/53-07 caller shape, including the Phase 51 node shape (no `mcp`,
no `tools`, blackboard on: D9's built-ins + `@blackboard` only) and a `blackboard=False` node with `mcp=[]` (built-ins
only, no MCP); refusal of globs and meta capabilities;
reserved-id rename; ladder table tests (identity missing, outside policy, each mode, timeout, unknown option); fixture
replays `mcp-allow`, `mcp-ask-approve`, `mcp-ask-reject`, `shell-auto-approve`, `fs-write-client`, `elicitation`,
`access-token`; a `tool_load` of an unlisted tool is not approved (53-01 P5/C1–C2 shape).

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["sdk-acp", "security", "chat"]
adrs     = ["ADR-029", "ADR-031", "ADR-033", "ADR-034", "ADR-004", "ADR-020", "ADR-068", "ADR-083"]
lessons  = ["L-017", "L-041", "L-045", "L-088", "L-011"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**"]
upstream = ["53-02", "53-04"]
```
