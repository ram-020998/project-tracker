# 19-06 — Consumption: `genesis-kb` document tools + evidence-pack integration

> **Status:** ✅ **CODE-COMPLETE — UNCOMMITTED** (commit at 19-08 per the user). `genesis-kb` MCP gains
> `list_documents`/`get_document`/`search_documents` (read-only `DocumentStore`, auto-trusted in chat via `_KB_TOOLS`) +
> `KbStore.build_evidence_pack` now includes an app's linked docs as bounded code-free excerpts (`documents` key). +3 tests
> (genesis 375 green), ruff clean. See `progress/phase-19-document-library.md`. **Repo:** genesis. **Depends on:** 19-03 (store).
> Makes documents usable *alongside the KB*.

## Goal
Expose the library to the two consumers that matter — **chat** (via the read-only `genesis-kb` MCP) and the **workflows** that
synthesize narrative (`design-doc`, `generate-business-map`) — so documents become grounding context, not an inert store.

## A. `genesis-kb` MCP document tools (`genesis/mcp/kb_server.py`)
Read-only, `mode=ro` `DocumentStore`, Atlas-style shapes; added to the Tier-1 tool surface:
- `list_documents(app_uuid?)` — id, title, source_type, status, linked apps, last_synced.
- `get_document(id)` — metadata + the Markdown body (+ tables if present).
- `search_documents(query, app_uuid?)` — keyword/`LIKE` over title + `kb_document_sections.text` first (semantic/pgvector is a
  future ADR-030 trigger, not here). Return snippets + `document_id` for follow-up `get_document`.
- Chat wiring: these tools are available in the existing read-only chat trust set (namespaced `@genesis-kb/<tool>`).

## B. `KbStore.build_evidence_pack` extension (Phase 17)
- Include the app's **linked documents** in the evidence pack: for `app_uuid`, pull `links_for_app` → for each, the title +
  either full `content_md` (small) or top sections/excerpt (large), under a `documents: [...]` key.
- `design-doc` and `generate-business-map` read the enriched pack → synthesize with document context. Keep it **grounding
  context only** (read-only; documents are never mutated). Bound the injected size (excerpt/section budget) to protect the
  context window (Phase 9 save-by-reference spirit).

## Tests
- MCP: `list/get/search_documents` shapes + read-only connection; search scoped by app.
- Evidence pack: an app with linked docs includes them; size budget respected; no-docs app unaffected.

## Exit criteria
Chat can list/get/search a tracked app's documents; the evidence pack for an app carries its linked documents so
spec/design/business-map generation is document-aware.
