# Progress: P1 03 — Integrations Studio (MCP/CLI Modularity)

**Spec:** `specs/phase-07-code-review-fixes/03-p1-integrations-studio.md`
**Delivered in:** genesis-core v0.5.0 + genesis v0.13.1
**CI:** All pipelines SUCCESS
**Date:** 2026-07-11

---

## Summary

Implemented the full Integrations Studio: a two-tier MCP/CLI registry (curated read-only +
custom user-writable), CRUD API, tool introspection via direct MCP stdio, per-server allowlist,
effective-trust intersection at runtime, an Overcut-inspired UI with a CodeMirror JSON editor,
and ADR-029.

---

## Deliverables

### genesis-core v0.5.0 (28 new tests, 45 total)

| File | What |
|------|------|
| `mcp/custom_store.py` | `CustomMcpStore`: JSON file CRUD + allowlist + validation |
| `clis/custom_store.py` | `CustomCliStore`: JSON file CRUD + validation |
| `mcp/registry.py` | `from_layers()`, `allowlist()`, `servers()` |
| `clis/registry.py` | `from_layers()`, `clis()` |
| `mcp/introspect.py` | Direct MCP stdio client (JSON-RPC 2.0 initialize + tools/list) |
| `nodes/agent.py` | `_compute_effective_trust`: node.tools ∩ server.allowlist |

### genesis v0.13.1 (75 pytest)

| File | What |
|------|------|
| `runtime/settings.py` | `custom_mcp_path`, `custom_cli_path` |
| `config/service.py` | Merged registries, CRUD, introspect, allowlist, upgraded test_server |
| `api/app.py` | 11 new routes (MCP CRUD + tools + allowlist + test; CLI CRUD) |

### Frontend (59 vitest, tsc + eslint clean)

| File | What |
|------|------|
| `types/integrations.ts` | TypeScript types for all API shapes |
| `lib/api/integrations.ts` | Full CRUD resource |
| `lib/api/client.ts` | Added `put()` method |
| `lib/query/keys.ts` | `integrations.mcpServers`, `clis`, `tools(name)` |
| `features/settings/hooks.ts` | 8 new hooks (CRUD + introspect + allowlist) |
| `features/settings/components/JsonEditor.tsx` | CodeMirror 6 (dark, line numbers, live validation, format) |
| `features/settings/components/McpSection.tsx` | Add MCP Server button + dialog |
| `features/settings/components/McpServerDetail.tsx` | Overcut-style redesign (General/Config/Tools/Secrets) |
| `features/settings/components/CliSection.tsx` | Add CLI button + dialog |

### ADR-029

Written in `reference/decision-log.md`. Revises ADR-005/020. Documents the two-tier merge,
tool allowlist semantics, introspection model, and security posture.

---

## Key Design Decisions

- **Server allowlist is a hard cap:** `effective_trust = node.tools ∩ union(server.allowlists)`.
  A workflow node can never exceed its server's allowlist — a safety improvement.
- **Introspection is agent-independent:** Direct MCP stdio (not via Kiro/ACP). Correct layer
  for capability discovery; no SDK dependency.
- **Custom store is a JSON file v1:** Mirrors secrets.json/environments.json. The interface
  (`CustomMcpStore`) is the seam for a future DB migration.
- **health() + missing_secrets() remain scoped to installed servers:** Custom servers get cards
  and injection but don't affect the "machine ready?" question unless used by a workflow.

---

## What's NOT verified

- **Live MCP introspection:** Requires a real MCP server process. The introspect code path is
  tested with a stubbed subprocess (AsyncMock). A manual e2e with a real npx MCP server would
  confirm the full handshake.
- **Browser visual QA:** The Overcut-style redesign is committed + served; visual confirmation
  needs a browser session.

---

## Next

P1 06 — Conversation rich-chat (`06-conversation-rich-chat.md`): unified auto-expand Thinking
timeline + markdown rendering in the Run-Detail Conversation tab.
