# 26-03 — `memory-consolidation` workflow (the nightly write path)

> **Status:** 📋 DRAFT · **Repos:** genesis-workflows (the workflow) + genesis (`ctx.extras` injection) · **Depends on:** 26-01 (store), 26-02 (embedder/vectors) · **Unblocks:** 26-04 (dreaming reuses the reconcile primitives), 26-06 (scheduler fires it) · **Proposed ADR:** ADR-053
> **Goal:** A **deterministic LangGraph workflow** that turns a day's chat sessions into memories — extract atomic memories,
> classify **personal/shared** + type, extract **entities + relationships** for shared, **reconcile ADD/UPDATE/INVALIDATE/NOOP**
> against similar existing memories, then **embed + write** to `memory.db`. Kiro agent nodes do the reasoning (ADR-001; reliability
> trio ADR-011); program nodes do all I/O. Read-only against `genesis.db`.

## 1. Current state (grounded)
- `sync-application` (genesis-workflows) is the template: a program-heavy graph with `ctx.extras['kb_store']` injection, network/env
  access isolated in a seam, and a **raw async `write_kb` node that runs the blocking write via `asyncio.to_thread`** (the §7
  deadlock lesson). `memory-consolidation` mirrors this shape.
- `nodes/reliable.py` `reliable_agent_step(...)` (25-10) composes kiro-agent + validator + retry/escalation in one call — used for
  every agent node here (satisfies the CI-enforced reliability lint).
- `build_context` (genesis `runtime/context.py`) provides `ctx.extras` — we add `memory_store` (over memory.db), `chat_read` (a
  **read-only** chat accessor over genesis.db), and `embedder` (26-02) at every worker construction site (mirrors the
  `kb_store`/`document_sync` wiring).
- Chat source: `chat_sessions`(+`mode`,`model`) / `chat_messages`(+`usage`) — the transcripts to distil.

## 2. Graph (workflow.yaml + graph.py, self-contained per the contract)

```
resolve_window (program)
  → load_sessions (program)
  → extract_memories (agent + validator)                 # reliable_agent_step
  → classify (agent + validator)                          # personal|shared + semantic|episodic|procedural  (may fold into extract)
  → extract_entities_relationships (agent + validator)    # shared only: entities + typed edges
  → reconcile (agent + validator)                         # per candidate vs top-k neighbours: ADD|UPDATE|INVALIDATE|NOOP
  → embed_and_write (program, asyncio.to_thread)
  → advance_cursor (program) → present
```

- **`resolve_window` (program):** read `memory_store.consolidation_cursor()`; select sessions from `chat_read` with
  `created_at > cursor` up to "end of yesterday" (or an explicit `{since,until}` input for manual/backfill runs). Emits the
  session id list to state (pointers, not bulk — ADR-010/018).
- **`load_sessions` (program):** pull each session's messages via `chat_read`; **redact secrets** (regex/pattern pass — no tokens,
  keys, passwords ever enter memory; mem0's rule); write the cleaned per-session transcript to the **blackboard**
  (`$GENESIS_ARTIFACTS_DIR`), passing only paths in state.
- **`extract_memories` (agent, reliable):** prompt Kiro to emit **atomic memories** as JSON — each `{text, type, scope,
  importance(1-10→0..1), rationale}`. Validator: JSON-parses, `type ∈ {semantic,episodic,procedural}`, `scope ∈
  {personal,shared}`, non-empty, count within bounds; coerces defensively (the §7 "validators must coerce data" lesson).
- **`extract_entities_relationships` (agent, reliable):** for `shared` memories, emit `{entities:[{kind,ref,name}],
  relationships:[{source,target,rel_type,fact,confidence}]}`; entity `ref` reuses KB ids where known (app_uuid/feature_id).
  Validator: referential integrity (every relationship endpoint is a named entity), allowed `rel_type`, confidence range.
- **`reconcile` (agent, reliable):** for each candidate, the **program pre-step** fetches top-k similar existing memories
  (`VectorIndex.search` filtered by scope/owner/entity + `search_memories` keyword) and passes them in; Kiro classifies the op
  per candidate: **ADD** (novel), **UPDATE** (refines/supersedes an existing → `update_memory`), **INVALIDATE** (contradicts an
  existing fact/edge → `invalidate_memory`/`invalidate_relationship`), **NOOP** (duplicate). Validator: op ∈ the set, references a
  real neighbour id for UPDATE/INVALIDATE. (mem0's ADD/UPDATE/DELETE/NOOP + Graphiti invalidation, decided by the agent.)
- **`embed_and_write` (program, async + `asyncio.to_thread`):** apply the reconciled ops via `MemoryStore` (add/update/invalidate,
  `upsert_entity`/`add_relationship`, `link_memory_entities`); embed new/updated texts via `ctx.extras['embedder']` +
  `VectorIndex.upsert`; set `embedding_status`. All memory.db writes off the event loop (§7).
- **`advance_cursor` (program):** set `memory_consolidation_state` to the last processed session; record `last_run_at`.
- **`present` (program):** a small summary doc to the blackboard (counts: extracted / added / updated / invalidated / noop).

## 3. Determinism, safety & reliability
- **ADR-001:** LangGraph owns control flow; agent nodes are narrow single-purpose Kiro turns.
- **Reliability trio (ADR-011):** every agent node via `reliable_agent_step` (validator + retry + escalation) — CI lint enforced.
- **Read-only against genesis.db** (never mutates chat); writes go **only** to memory.db.
- **Restart-safe / idempotent:** the cursor + reconcile-dedup make a re-run a NOOP-heavy pass.
- **No new MCP for the agent nodes** — extraction/reasoning need no external MCP (the transcript is provided as blackboard files);
  keep per-node `mcp=[]`, `auto_approve`, no HITL (the job is non-interactive; ADR-047 lineage).
- **`graph.py` self-contained** (no sibling/platform imports; no `from __future__ import annotations` if it defines reducer state
  keys — the §7 loader lesson); pure helpers in `graph.py`.

## 4. genesis-side wiring
- `build_context` injects `ctx.extras['memory_store'|'chat_read'|'embedder']` (read-only chat accessor + memory store over
  memory.db + the local embedder), at the worker construction site (mirrors `kb_store`). `chat_read` is a thin **read-only**
  facade over `ChatStore` (no write methods exposed).
- Register `memory-consolidation` in genesis-workflows `registry.json` (+ `workflow.yaml`/`META` parity; `graph:` topology for the
  Run Detail preview).

## 5. Files & tests
- **New (genesis-workflows):** `workflows/memory-consolidation/{workflow.yaml, graph.py, common/…}` + `tests/`.
- **New (genesis):** the `chat_read` read-only accessor + `build_context` extras wiring; tests.
- **Tests:** node tests with a **stubbed Kiro** (`set_collect_impl`) + a fake `MemoryStore`/`Embedder`: extraction JSON →
  validators; reconcile drives the four ops correctly (ADD/UPDATE/INVALIDATE/NOOP) with the right store calls; cursor advances +
  restart re-run is NOOP-heavy; secret-redaction removes seeded tokens; `ci/validate_library.py` + the reliability-trio lint pass;
  `graph.py` loads standalone.

## 6. Acceptance criteria
1. `memory-consolidation` runs end-to-end (stubbed Kiro in tests; real Kiro on manual trigger) and writes correctly-scoped,
   entity-anchored, embedded memories to `memory.db`.
2. Reconciliation performs ADD/UPDATE/INVALIDATE/NOOP against similar existing memories (bi-temporal).
3. Read-only against genesis.db; memory.db writes via `to_thread`; reliability trio + contract lint green.
4. Restart-safe via the cursor; secrets never persisted.

## 7. Out of scope
- The periodic reflect/decay/dedup (26-04); the retrieval/MCP (26-05); scheduling (26-06).
