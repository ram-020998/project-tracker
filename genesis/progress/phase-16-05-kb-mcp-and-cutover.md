# Phase 16-05 — `genesis-kb` MCP server + chat cutover (as built)

> **Status:** ✅ SHIPPED (server + CHAT cutover) — genesis **v0.33.0**, CI green (pipeline **6513536**, `genesis` job
> success; `frontend` correctly skipped — no `web/**` change). **Follow-up 16-05b** tracks the `erd-generation` +
> `design-doc` workflow cutover (deferred by decision — see below).
> **Date:** 2026-08-06 · **Repo:** genesis only (genesis-workflows unchanged).

## What shipped

**1. `genesis/mcp/kb_server.py` (NEW) — the read-only `genesis-kb` MCP server.**
Modeled 1:1 on `genesis/mcp/introspection_server.py`: newline-delimited JSON-RPC 2.0 over stdio
(`initialize`/`tools/list`/`tools/call`), a read-only `file:{db}?mode=ro` connection (defense in depth), a 32 KB
payload cap (`_cap`), launched `python -m genesis.mcp.kb_server --db <genesis.db>`. `KbAccessor` wraps `KbStore`
(a `_RoDatabase(Database)` subclass forces `mode=ro`). Exposes the **17 Tier-1 tool names** (contracts §2.1–2.16;
the batch entry 2.7 is two tools) with **Atlas-mirrored return shapes** so the chat cutover is lossless:
`list_applications`, `get_app_overview`, `search_objects`, `get_dependencies`, `get_object_detail`,
`get_entry_points_for_object`, `get_dependents_batch`, `get_precedents_batch`, `get_shared_objects`, `search_bundles`,
`get_bundle`, `list_orphans`, `get_orphan`, `get_object_code`, `get_dependency_path`, `get_transitive_dependencies`,
`get_hub_objects`. All read-only (no create/update/delete/write/deploy verbs anywhere in the surface).

**2. Live code via the Dev MCP (never stored — ADR-037).** `genesis/kb/dev_mcp.py` gained `object_code(config, *,
object_uuid, object_type, object_name)` + a `_CODE_GETTERS` map (object type → Dev-MCP read getter:
`getExpressionRule`/`getInterface`/`getProcessModel`/`getRecordType`/`getConstant`/`getIntegration`/`getWebApi`/…) +
`_extract_code` (defensive: peels `{content:[{text}]}`, accepts raw SAIL or a JSON code field). Reuses the existing
direct-stdio `_call_tool` client. `get_object_code` resolves name→uuid+type from the KB then fetches live; `get_orphan`
= `get_object` detail + live code. On any failure (Dev MCP not installed / dev env untagged / secret missing / timeout)
it returns `code_status:"unavailable"` + a reason — **never a fabricated value** (the ADR-032 honesty principle applied
to code). Live retrieval is a **manual-acceptance** item (live MCP can't be driven headlessly).

**3. `KbStore` (`genesis/kb/store.py`) — the 7 remaining reads.** 8 tools were already backed (16-02); added
`get_entry_points_for_object`, `get_dependents_batch`/`get_precedents_batch` (one `IN (…)` query, grouped by pivot),
`get_shared_objects` (bundle-membership `HAVING COUNT(DISTINCT bundle) ≥ n`), `get_hub_objects` (inbound-edge GROUP BY,
desc), and the two graph traversals `get_dependency_path` (BFS shortest path + edge types) / `get_transitive_dependencies`
(bounded BFS, optional `edge_types` filter, `outbound|inbound`, capped at 200 + `truncated`). Helpers `_adjacency`
(current edges → adjacency + labels), `_resolve_uuid`, `_label`, `_batch`. **Current-state only** throughout
(`valid_to_sync IS NULL`).

**4. Chat cutover (`genesis/chat/mcp.py`).** Removed the `appian-atlas` wiring; `build_chat_mcp` now ALWAYS adds
`genesis-kb` (`_kb_entry` → `-m genesis.mcp.kb_server --db <db>`, `env:[]`) with `@genesis-kb/<tool>` in the read trust
set, plus a **best-effort `@appian-dev`** co-inject (read-only allowlist) for live code — degrading gracefully if the
Dev MCP is absent. Introspection (always) + control (copilot) unchanged. `KB_TOOLS` is imported from
`kb_server.TOOLS` (no drift).

**Tests:** genesis **288 pytest** green (up from 274): `tests/test_kb_store.py` +7 (the new reads), `tests/test_kb_server.py`
NEW (dispatch shapes for every tool, no-write-tool assertion, graceful code-unavailable, error paths, `_cap`, a
**subprocess JSON-RPC wire smoke**, real-package skip-if-missing), `tests/test_copilot_mode.py` +1 (chat wires
`genesis-kb` not `appian-atlas`). ruff clean.

## Decision — phased cutover (2026-08-06): `appian-atlas` RETAINED for the workflows

The cutover cannot be *lossless* in iteration 1: `genesis-kb` deliberately omits the **schema/DDL tools (Section C,
deferred)** and the **release/version tools (Section B → 16-06 backlog, gated on Dev MCP AP-62096)** — exactly what
`erd-generation` (`get_app_schema`/`get_schema_relationships`) and `design-doc`'s `research_atlas`
(`get_app_schema`/`get_field_map` + `list_releases`/`get_object_at_release`/`get_changelog`/`compare_releases`/
`get_release_impact`) depend on; `design-doc`'s `research_jarvis` also still uses Jarvis. **Per the user's decision,
`appian-atlas` stays registered and both workflows keep using it (their `required_mcp` unchanged) until parity lands.**
Only **chat** cut over (it used Atlas *structural* read tools, which `genesis-kb` mirrors). Documented in the phase-16
umbrella spec ("Phased-cutover decision"). Full workflow cutover = **16-05b** (unblocked by 16-06 + a Section-C
decision + Jarvis→Dev-MCP retirement).

## Not done (by design / follow-up)
- **16-05b** — `erd-generation` + `design-doc` cutover (blocked as above).
- **Live acceptance** (manual): a chat KB question answered from a locally-synced app; a `get_object_code` returning
  live SAIL via the Dev MCP — can't be driven headlessly.
