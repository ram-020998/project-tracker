# Phase 16-05 — `genesis-kb` MCP server + cutover (the headline milestone)

> **Status:** ✅ **SHIPPED (server + CHAT cutover)** — genesis **v0.33.0** (see `progress/phase-16-05-kb-mcp-and-cutover.md`).
> The `erd-generation` + `design-doc` cutover is **deferred to follow-up 16-05b** (they depend on Section-C schema +
> 16-06 versioning + a Jarvis→Dev-MCP retirement — `appian-atlas` is RETAINED for them; see the umbrella spec's
> "Phased-cutover decision"). · **Repos:** genesis (+ genesis-workflows for 16-05b) · **Depends on:** 16-02 (KbStore), 16-04 (apps)
> **Goal:** Expose the local KB to agents via a Genesis-owned, **read-only** `genesis-kb` stdio MCP server (the
> internal counterpart of the external Atlas MCP), with **live code fetch via the Dev MCP**, and **cut chat /
> `erd-generation` / `design-doc` off the external `appian-atlas` onto `genesis-kb`** — preserving functionality. This
> is the "KB swapped, everything still works" milestone.

---

## 1. Current state (grounded)
- Internal MCP servers: `genesis/genesis/mcp/introspection_server.py` (read-only stdio JSON-RPC 2.0 —
  `initialize`/`tools/list`/`tools/call`; a read-only `file:...?mode=ro` `genesis.db` connection; secret redaction;
  32 KB payload cap; `TOOLS` module constant), `control_server.py` (thin HTTP facade), and genesis-core
  `blackboard_server.py` (per-run, launched `-m ... --root <workspace>`).
- Chat wiring: `genesis/genesis/chat/mcp.py` builds `(mcp_servers, trust_tools)` — `_introspection_entry(settings)`
  (`command=sys.executable, args=["-m","genesis.mcp.introspection_server","--db",db_path,...], env:[]`), an
  `_atlas`/`appian-atlas` entry (best-effort, skipped if secrets unresolved — never trust-all), and trust built with the
  **namespaced `@server/tool`** form (kiro-cli match rule). `ChatManager` passes these into the SDK options.
- Per-node injection (workflow agent nodes): `genesis-core/nodes/agent.py` `kiro_node` → `ctx.mcp.acp_servers(mcp)` +
  `_compute_effective_trust(tools, mcp, ctx.mcp)` (= `node.tools ∩ server.allowlist`).
- Consumers of `appian-atlas` today: chat (Atlas read tools), `genesis-workflows/workflows/erd-generation` (Atlas
  schema fetch) and `design-doc` (Atlas dual-source research — `ATLAS_RO` allowlist). `appian-atlas` in
  `mcp-registry.json` has a 33-read-tool `tool_allowlist` (from the Phase-10 follow-up).
- ADR-031 read-only posture: introspection uses `mode=ro` + a read trust allowlist + `permission_mode=auto_deny` for
  chat.

## 2. Design

### 2.1 `genesis/genesis/mcp/kb_server.py` (read-only)
Model on `introspection_server.py`: JSON-RPC over stdio, a read-only `_RoDatabase` (`file:{db_path}?mode=ro`), 32 KB
cap, secret redaction (defensive — the KB holds no secrets, but keep the guard). Launched
`python -m genesis.mcp.kb_server --db <genesis.db>`. Backed by `KbStore` read methods (16-02).

**Authoritative tool surface + per-tool contracts:** see **`genesis-kb-tool-contracts.md`** in this folder — it is the
implementation source of truth (params, exact return JSON, backing `kb_*` query, and parser fields for every tool).
The **iteration-1 surface = 16 read-only tools** (Section A / Tier-1 of the Atlas+Jarvis analysis):
`list_applications`, `get_app_overview`, `search_objects`, `get_dependencies`, `get_object_detail`,
`get_entry_points_for_object`, `get_dependents_batch`, `get_precedents_batch`, `get_shared_objects`, `search_bundles`,
`get_bundle`, `list_orphans`, `get_orphan`, `get_dependency_path`, `get_transitive_dependencies`, `get_hub_objects`,
plus `get_object_code` (live via Dev MCP). All read-only, all cross-app-capable (`app_name` selects the app).
**Versioning tools are NOT in iteration 1** — `list_releases`/`get_changelog`/`compare_releases`/`get_object_history`/
`get_object_at_release`/`get_release_impact` are **backlog** (16-06, gated on Dev MCP AP-62096). Schema/DDL tools are
**deferred** (Section C). Return shapes mirror the Atlas MCP so the cutover is lossless.

### 2.2 Live code — `get_object_code` / `get_object_detail(version?)`
- **Recommended wiring (Q3): co-inject the Dev MCP** alongside `genesis-kb`. `genesis-kb` serves **structure**; the
  agent calls `@appian-dev/<read-tool>` for **code**. Single-purpose servers, least coupling. `get_object_detail`
  returns KB metadata + a hint ("code via @appian-dev") rather than embedding code.
- **Optional ergonomic:** a thin `get_object_code(app, object_uuid, version?)` in `genesis-kb` that **proxies** the Dev
  MCP (like `control_server.py` proxies HTTP) so callers have one tool. `version` maps to a `kb_releases.env_version_ref`
  for point-in-time (lights up when Dev MCP version support ships; current works now). Decide (a) vs (b) here; default
  to **co-inject + a thin optional proxy**.
- Degrade gracefully: if the env/Dev MCP is unavailable, return metadata + an explicit "code unavailable" — never
  fabricate (ADR-032 honesty principle applied to code).

### 2.3 Chat wiring — `chat/mcp.py`
- Add `_kb_entry(settings)` → `{name:"genesis-kb", command:sys.executable, args:["-m","genesis.mcp.kb_server","--db",db_path], env:[]}`.
- Add `@genesis-kb/<tool>` to the **read** trust set (always available, read-only). Keep the Dev MCP entry
  (`@appian-dev/<read-tool>`) trusted for code reads (read-only tools only; write tools untrusted/absent).
- **Remove the external `appian-atlas` entry from chat** once parity is verified (keep it registered in the library
  during transition, then drop from the chat wiring).

### 2.4 Cutover — `erd-generation` + `design-doc`
- Repoint each agent node's `mcp=[...]`/`tools=[...]` from `appian-atlas` → `genesis-kb` (+ `appian-dev` for code where
  a node needs SAIL). Update the node prompts + read-only allowlists + the workflow `required_mcp`.
- **Parity:** `genesis-kb` provides a superset of the Atlas tool surface; where a node used an Atlas tool name that
  differs, either alias it in `genesis-kb` or update the prompt. Update each workflow's tests (they stub tool outputs —
  mirror the **real** `genesis-kb` shapes, not the old Atlas shapes; Phase-12 "stub hid the contract" lesson).
- **Prereq:** the target app must be **synced into the KB** (16-03/04) before these workflows can query it — document
  this (erd/design-doc now assume a locally-synced app rather than the external Atlas KB).

### 2.5 Registry note
`appian-atlas` (external) → **deprecated** as the KB source; removed from chat/erd/design-doc wiring after cutover.
`genesis-kb` is **Genesis-owned** (not a `mcp-registry.json` entry — launched like introspection). `appian-dev` stays
curated (read-only) from 16-03.

## 3. Files & tests
- New: `genesis/mcp/kb_server.py` (+ `-m` entry); `_kb_entry` + trust wiring in `chat/mcp.py`; cutover edits in
  `genesis-workflows/workflows/{erd-generation,design-doc}/` (graph.py prompts/allowlists + workflow.yaml
  `required_mcp` + tests).
- Tests:
  - `tests/test_kb_server.py`: stdio JSON-RPC smoke (initialize/tools/list/tools/call) over a seeded read-only
    `genesis.db`; each tool returns expected shapes; read-only (no write tool); 32 KB cap + redaction; graceful
    "code unavailable" when the Dev MCP path is absent.
  - chat: a test that a chat session wires `@genesis-kb/*` into trust and can answer a KB question from a seeded KB
    (introspection-style test); Atlas entry no longer required.
  - erd/design-doc: updated workflow tests pass against `genesis-kb` tool shapes (`validate_library` + parity +
    reliability green).
  - **Live acceptance (manual, recorded):** chat answers an app-structure question from the internal KB; erd/design-doc
    run against a locally-synced app; a `get_object_code` call fetches current SAIL live via the Dev MCP.
- `web` unaffected except the app-detail "View code" action (16-04) now works; rebuild/commit if touched.

## 4. Acceptance criteria
1. `genesis-kb` MCP serves the KB read-only over stdio; tools return correct shapes from `genesis.db`; cross-app works.
2. `get_object_code`/`get_object_detail` fetch **current** SAIL live via the Dev MCP (version-parameterized signature in
   place; historical lights up with Dev MCP versioning); graceful degradation when unavailable.
3. **Chat + `erd-generation` + `design-doc` run off `genesis-kb`** (external `appian-atlas` no longer wired), with
   equivalent-or-better behavior; their tests pass against real `genesis-kb` shapes.
4. Read-only throughout (no write tools in `genesis-kb`; Dev MCP read tools only); secrets referenced by key name.
5. genesis + genesis-workflows suites + ruff green; manual live acceptance recorded.

## 5. Out of scope
- Version tagging UI + historical-code view (16-06) — the version-parameterized fetch signature lands here; the UX +
  release tagging is 16-06.
- Delta sync (16-07).
- Any Appian write/deploy.
