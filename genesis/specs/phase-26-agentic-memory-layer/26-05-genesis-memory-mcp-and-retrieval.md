# 26-05 — `genesis-memory` MCP server & hybrid retrieval (the read path)

> **Status:** 📋 DRAFT · **Repo:** genesis (server + wiring) + genesis-workflows (registry entry) · **Depends on:** 26-01 (store/graph), 26-02 (embedder/vectors) · **Unblocks:** usable memory in chat + agentic workflows · **Proposed ADR:** ADR-053
> **Goal:** A **separate, read-only `genesis-memory` MCP server** (modeled on `genesis-kb`, **not merged with it** — decision
> §11.5) that serves memory via **hybrid retrieval** — relevance (semantic + keyword + entity/graph) × recency × importance
> (Generative-Agents scoring) — scoped by owner/entity, with **graph traversal**. Injection is **MCP-only**: the agent is told
> (steering) the memory MCP exists and when to query it.

## 1. Current state (grounded)
- `mcp/kb_server.py` / `mcp/introspection_server.py` — the read-only stdio JSON-RPC MCP-server pattern: a `mode=ro` DB connection,
  a fixed tool set with Atlas/introspection-mirrored shapes, launched `-m genesis.mcp.<server> --db <path>`, wired into chat via
  `chat/mcp.py`. `genesis-memory` copies this exactly (over `memory.db`).
- 26-01 `MemoryStore`/`GraphStore` (keyword + filters + traversal) and 26-02 `Embedder`/`VectorIndex` (semantic) are the building
  blocks; retrieval **fuses** them here.
- ADR-002/004/020 (per-node MCP injection), ADR-031/045 (read augmentation, human-confirmed writes) — the memory MCP is
  **read-only**, so it fits the read posture with no new write authority.

## 2. Server — `genesis/mcp/memory_server.py`
- Launched `-m genesis.mcp.memory_server --db <memory.db>`; opens a **read-only** memory.db connection; constructs a
  `LocalEmbedder` **in-process** (the MCP is a spawned subprocess — the model loads here, not in `genesis serve`; a `NullEmbedder`
  if none configured → FTS+graph only).
- **Tools (all read-only, owner/entity-scoped, Atlas-style compact JSON, ≤ a response cap like kb_server's 32 KB):**
  - `search_memory(query, scope?='shared'|'personal'|'all', entity_refs?=[], types?=[], top_k?=8)` → ranked memories
    `[{id, text, type, scope, importance, entities, score, last_used_at}]`.
  - `get_entity(entity_kind, entity_ref)` → the entity + its attributes.
  - `get_entity_memories(entity_ref, top_k?)` → memories anchored to an entity.
  - `get_related_entities(entity_ref, rel_type?, depth?=1)` → **graph traversal** (via `GraphStore.related_entities`) with the
    connecting relationships + validity.
  - `get_relationships(entity_ref, current?=true)` → the entity's edges.
  - `get_personal_memory(query?, types?, top_k?)` → the **configured named user's** personal memory only (owner-scoped).
- **Owner scoping:** the server resolves the configured username (26-06 setting, passed via `--owner` / env) and **restricts
  personal reads to that owner**; `shared` reads are open. (Single-user today; the seam is the future ACL point.)
- **Read-only + safe:** no write tools; `mark_used(memory_ids)` (recency bump) is the only side-effect and is an **allowed
  read-path write to memory.db** done through a narrow guarded call (or deferred to a batched updater to keep the server strictly
  read-only — build-time choice; default: strictly read-only, recency handled by the maintenance job).

## 3. Hybrid retrieval (the fuse) — `genesis/memory/retrieval.py`
A pure, unit-tested ranking function (framework-free), reused by the server:
```
score(memory | query) =
      w_rel * relevance   +   w_rec * recency   +   w_imp * importance
relevance = normalize( α*semantic_cosine + β*keyword_bm25 + γ*entity_overlap/graph_proximity )
recency   = exp(-Δt / τ)         # Δt from last_used_at or created_at
importance= memory.importance    # 0..1 (LLM-rated at write time)
```
- **Candidate generation:** union of (a) `VectorIndex.search(embed_query(query), k, memory_ids=<scope/entity filter>)`,
  (b) `MemoryStore.search_memories(query, …)` (FTS5), (c) entity-anchored memories via `GraphStore` when `entity_refs` given —
  all **pre-filtered by scope/owner** so vector search is never global.
- **Fuse + rank** by the weighted score; return `top_k`. Weights are constants (tunable), documented; `NullEmbedder` sets α=0 so
  retrieval degrades to keyword+entity+recency+importance with no code path change.
- **Graph-boost:** memories whose entities are within `depth` of a queried entity get a proximity bonus (γ), giving the
  "traversal" value the user asked for on the read side too.

## 4. Injection = MCP-only + steering (decision §11.5)
- Wire `genesis-memory` into **chat** (`chat/mcp.py`, alongside `genesis-kb`, auto-trusted read tools) and into **agentic
  workflow nodes** that benefit (spec authoring, design, code-review) via their per-node `mcp=[...]` + read-only `tools=`
  allowlist (ADR-002/004/020; effective trust = node.tools ∩ server.allowlist).
- Add a **steering hint** (a short system-prompt/steering note) telling the agent: *a `genesis-memory` MCP holds personal
  preferences + shared application knowledge; query it at the start of a new chat / agentic step, and whenever an application or
  feature is in context, before asking the user to repeat themselves.* No auto pre-fetch/inject in v1 — the agent decides to call
  the tools (MCP-only).

## 5. Files & tests
- **New (genesis):** `genesis/mcp/memory_server.py`, `genesis/memory/retrieval.py`; `chat/mcp.py` wiring + the steering note.
- **New (genesis-workflows):** a `genesis-memory` entry in `mcp-registry.json` (read-only allowlist) so agentic nodes can inject
  it.
- **Tests:** pure `retrieval.py` ranking units (semantic+keyword+entity fuse, recency decay, importance weight, `NullEmbedder`
  degradation) with a fake embedder/store; MCP tool-contract shape tests; a **read-only guard** (no write tool; personal reads
  owner-scoped — user A never sees user B / must ask for `personal`); graph-traversal tool returns related entities + edges. No
  live Kiro/network.

## 6. Acceptance criteria
1. A **separate** read-only `genesis-memory` MCP serves hybrid, scoped, graph-aware retrieval (not merged with `genesis-kb`).
2. Retrieval fuses semantic + keyword + entity/graph × recency × importance, degrades cleanly under `NullEmbedder`, and is always
   scope/owner filtered.
3. Injection is MCP-only; chat + relevant agentic nodes have the tools + a steering hint; no auto-inject.
4. genesis pytest + ruff green; the server is provably read-only + owner-scoped.

## 7. Out of scope
- Auto pre-fetch/prompt-injection (deferred, umbrella §9); a memory-browser UI (follow-up); write tools of any kind.
