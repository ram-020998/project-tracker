# Backlog — The Object Wiki as agent grounding/memory

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-09-23 (Phase 42 spin-off, Q15). · Depends on Phase 42 (ADR-070 — the Object Wiki exists + is Hub-shared).

## Context
Phase 42 introduces the **Object Wiki** (ADR-070): a local-first, Hub-shared, append-only per-object change ledger (business + technical description, story ref, author, version) written by the implementation workflow. It is a *record* now — humans + the review surface read it.

## The deferred capability
Make the wiki **readable by agents as grounding/memory**, so design/implementation (and future) agents consult an object's prior wiki entries ("what is this object for, what changed for it and why, in which tickets") before designing or changing it. This turns the wiki into durable, shared, cross-ticket agent memory — complementing the code-free KB (structure) and the Agentic Memory Layer (Phase 26, conversation-distilled).

## Shape when picked up
- A read tool on `genesis-kb` (or a small dedicated read MCP): `get_object_wiki(app_uuid, object_uuid)` / `search_object_wiki` → the page + entries. Read the **Hub-synced** view so cross-user history is visible.
- Wire it into the design + implementation workflows' grounding (alongside `@genesis-kb`/`@appian-dev`), and optionally chat.
- Relation to ADR-053 (Agentic Memory): the Object Wiki is *authored intent per object*; memory is *distilled from conversations* — keep them distinct; a reader could union both.

## Open questions
- Retrieval shape (latest entry vs full history vs a summarized rollup); how much to inject (bounded excerpts, the ADR-010/018 rule).
- Whether it's a new MCP or a `genesis-kb` extension; freshness (pull-before-read when the Hub is available).
