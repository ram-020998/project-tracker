# 52-08 — MCP gateway and relay; Kiro sign-in and credential broker

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`genesis/agent_runtime/gateway/`, `relay/`, `credentials/`;
> `genesis/runtime/kiro_auth.py`; `kiro-agent-sdk` access-token responder use). Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D7, D8, D18, D19, D26. Upstream: 52-02 (S3, S4, S5), 52-03, 52-06.

## 1. Goal

No credential ever enters a sandbox: MCP servers and their secrets stay in the app container behind a gateway the
sandbox reaches through a relay, and Kiro gets short-lived access tokens from a broker that answers from Genesis's own
Kiro sign-in.

## 2. MCP gateway (app container)

- For each turn the gateway starts the node's MCP servers exactly as today (`ctx.mcp.acp_servers(...)` entries, stdio,
  `env` as a list, L-001; managed-native launch specs, L-029), plus the blackboard server (`--root <run folder>`).
- It issues a **relay token** scoped to (turn id, server set), revoked at turn end (`credential.event`).
- It enforces the policy's MCP map (`server → tools`, the ADR-029 cap as computed by `_node_mcp_trust`, L-116): a
  `tools/list` is filtered to it; a `tools/call` outside it is refused and logged; every call is an `mcp.call` event;
  large results keep the save-to-blackboard path (L-021).
- v3 semantics stay as L-114 describes (nested `rawInput.arguments`, `tool_load`, a dead server not restarted); the
  gateway restarts nothing silently and reports a dead server as a tool failure.

## 3. Relay (in the `sandbox` image)

- `genesis-relay <server-name>`: a small stdio MCP server; the session's `mcpServers` lists one relay entry per server
  with `env` holding only `GENESIS_RELAY_URL` and `GENESIS_RELAY_TOKEN` (no other `env` or `headers` values, KiroCrew's
  withholding rule, findings §18.6). It forwards each JSON-RPC message to the gateway and back.
- **Mount check** (KiroCrew `mcp_mount_check.py`): after MCP readiness, the gateway confirms which relay tokens
  connected; a declared server that never connected fails the turn loudly with the server name.
- The engine-side projected tool list (ADR-086) stays as the second layer.

## 4. Kiro sign-in owned by Genesis (D19)

- `genesis/agent_runtime/credentials/kiro_login.py`: the OIDC device-code sign-in for IAM Identity Center (start URL,
  region, Pro licence) and its refresh, ported from KiroCrew's documented contract (`kas-auth.md`), replacing
  `kiro-cli login` in `genesis/runtime/kiro_auth.py`; the login (refresh token) stored in the `genesis-kiro-login`
  volume, mode 0600, readable only by the app process; the Settings sign-in flow (device code, open URL, approve)
  unchanged for the user.
- **Broker** (`credentials/kiro_broker.py`): answers `_kiro/auth/getAccessToken` through the SDK's access-token
  responder (53-05) with `{accessToken, expiresAt ≥ now + 3 min, profileArn, authMethod?, provider?}`; never the
  refresh token; one refresh at a time under a lock; refresh ahead on an idle timer; token-free error categories
  (`not_signed_in`, `refresh_failed`); a refused refresh is shown to the user and never replaced by another login;
  answers only while the requesting turn is live; every issue and refusal is a `credential.event`.
- **Launch rules** for the sandboxed Kiro (used by 52-09): `--auth-method client` unless the version is known to be
  below 2.35.2; `kiro-cli-chat` before 3.0.0, `kiro-cli` from 3.0.0 once 3.x is verified; `KIRO_API_KEY` never set;
  warn outside 2.27.0 to < 4.0.0 (findings §18.6).
- D19's bridge (read and refresh kiro-cli's stored login) is built only if this section proves larger than expected,
  decided with the user.

## 5. Tests

Gateway: allowlist filtering and refusal, token scope and revocation, logging, dead-server classification, the mount
check, with fake MCP servers; relay: framing round trips, a wrong or revoked token refused; Kiro login: the device-code
and refresh flows against a recorded fake (no live tokens in fixtures), lock and idle-refresh timing with a fake clock,
error categories; broker: response shape, refusal after turn end; an integration case on the dev VM proving a
sandboxed turn with credits, a refresh and a no-refresh-token scan (52-02 S4).

## Context manifest

```toml
areas    = ["sdk-acp", "config-secrets", "security", "core-engine", "chat"]
adrs     = ["ADR-002", "ADR-004", "ADR-005", "ADR-020", "ADR-029", "ADR-032", "ADR-038", "ADR-048", "ADR-073", "ADR-086"]
lessons  = ["L-001", "L-017", "L-019", "L-021", "L-023", "L-028", "L-029", "L-049", "L-053", "L-070", "L-114", "L-116"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/.research/kirocrew-trust.md", "tracker:specs/phase-53-kiro-sdk-v3/53-05-trust-and-permissions.md", "tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md"]
code     = ["genesis/genesis/agent_runtime/gateway/**", "genesis/genesis/agent_runtime/relay/**", "genesis/genesis/agent_runtime/credentials/**", "genesis/genesis/runtime/kiro_auth.py", "genesis/packages/genesis-core/genesis_core/mcp/**", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/session.py"]
upstream = ["52-02", "52-03", "52-06"]
```
