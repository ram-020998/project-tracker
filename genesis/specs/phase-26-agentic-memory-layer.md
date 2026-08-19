# Phase 26 — Agentic Memory Layer (umbrella)

> **Status:** 📋 **DRAFT — spec only (umbrella + 26-01..26-07); awaiting approval to implement.** · **Author:** Genesis agent · **Date:** 2026-08-19
> **Goal:** Give Genesis a **persistent, self-maintaining agentic memory** distilled from the conversations that already
> accumulate in `genesis.db`. As POs, UX, developers and testers chat with the agent across the SDLC, Genesis learns —
> **personal (local) memory** (a named user's preferences, coding style, review rules, work habits, feedback) and **shared
> (application) memory** (an application's knowledge, architecture, decisions, business rules, patterns) — stored as an
> **entity-relationship graph** with **hybrid semantic + keyword + graph retrieval**, built by a **nightly consolidation
> workflow** and refined by a **periodic "dreaming" maintenance job**, and served to agents through a **separate read-only
> `genesis-memory` MCP** (never merged with `genesis-kb`).
> **Repos:** **genesis** (a new `~/.genesis/memory.db` + `MemoryStore`/`GraphStore`/`VectorIndex`/`Embedder` seams + the local
> embedder + the `genesis-memory` MCP + two new scheduler jobs + a username setting) and **genesis-workflows** (two new
> deterministic LangGraph workflows: `memory-consolidation` + `memory-maintenance`). genesis-core likely unchanged (a small
> optional helper only). **Schema change:** yes — a **NEW, separate `memory.db`** with its own migration set (`mm0001`), **not**
> a change to `genesis.db` (keeps the runs/checkpoint plane untouched and isolates the future Postgres move).
> **Non-negotiable framing:** stays **local single-user** (ADR-026). All reasoning (extraction / classification / entity &
> relationship synthesis / reconciliation / reflection) is done by **Kiro over ACP** inside deterministic LangGraph workflows
> (ADR-001 preserved; every agent node under the reliability trio, ADR-011). Embeddings are produced by a **small local
> embedding model** (CPU, in a subprocess) — **no outbound data** (ADR-026). Memory injection is **MCP-only** (the agent pulls
> memory on demand; ADR-002/004/020, ADR-031/045). This is the explicit **"transcript RAG" trigger ADR-030 anticipated** for
> introducing a vector store.

---

## 0. TL;DR

Genesis already persists every chat session + message (`chat_sessions`/`chat_messages`, m0002/m0011). Today that history is
inert. Phase 26 turns it into **memory**:

1. **A separate memory store (26-01)** — a new `~/.genesis/memory.db` with a **bi-temporal entity-relationship model**
   (`memory_entities`, `memory_relationships`, `memories`, `memory_links`, `memory_communities`, FTS5) behind **DB-agnostic
   repository seams** (`MemoryStore` + `GraphStore` + `VectorIndex` + `Embedder`). SQLite + `sqlite-vec` + FTS5 now; **the seam
   is designed so a Postgres + pgvector (+ Apache AGE) swap is a re-home behind the interface, not a caller change.**
2. **A local embedder + vector index (26-02)** — a small **ONNX/static** embedding model (e.g. quantized `bge-small` via
   `fastembed`, or `model2vec` static, ~30–150 MB, CPU, ms-latency) loaded **only in the worker/MCP subprocess**, behind an
   `Embedder` protocol; vectors indexed in `sqlite-vec`.
3. **A nightly consolidation workflow (26-03)** — `memory-consolidation`: read the day's sessions → **extract atomic memories**
   → **classify personal/shared + type** → **extract entities + relationships** → **reconcile ADD/UPDATE/INVALIDATE/NOOP**
   against similar existing memories → **embed + write**. Kiro agent nodes (reliability trio) for reasoning; program nodes for
   I/O.
4. **A periodic "dreaming" maintenance job (26-04)** — `memory-maintenance`: **reflect** (synthesize higher-level memories),
   **dedup/merge/evolve**, **invalidate** contradicted facts (bi-temporal), **decay/forget** stale low-value memories, and
   **recompute communities/clusters**.
5. **A read-only `genesis-memory` MCP + hybrid retrieval (26-05)** — a **separate** stdio MCP (modeled on `genesis-kb`) with
   `search_memory` / `get_entity` / `get_related_entities` (graph traversal) / `get_personal_memory`, ranked by **relevance
   (semantic + keyword + entity) × recency × importance** (Generative-Agents scoring), scoped by owner/entity.
6. **Scheduler integration + config (26-06)** — register the two jobs on the **Phase-23 scheduler** (m0012 `scheduled_jobs`),
   add a **named-user** setting for personal-memory ownership, preflight-skip when unconfigured.
7. **Release + acceptance (26-07)** — release chain + ADR-053/054 Accepted + bible/tracker/progress.

**Design is grounded in a survey of mem0, Zep/Graphiti, Letta/MemGPT, LangMem, cognee, A-MEM and the Stanford generative-agents
paper (§2).** We reproduce the *concepts*, integrate **no external memory service** (ADR-026), and reuse existing Genesis
machinery wherever possible (the scheduler, the SCD-2 temporal pattern, the read-only MCP-server pattern, the reliability trio,
the subprocess-worker model).

---

## 1. Motivation & context

Requirement (user, 2026-08-19): Genesis is an Appian **agentic SDLC orchestrator**. Users across roles chat with the agent all
day — a PO authoring a spec, a UX designer discussing mockups, developers and testers sharing knowledge to help the agent
complete a task. Every session is stored in `genesis.db`, but that knowledge is never reused. **A persisted memory of all these
conversations would multiply agent efficiency.** Two memory kinds:

- **Personal / local memory** — specific to a **named user** (e.g. "Ram"): their preferences, instructions, feedback, work
  habits, coding style, review rules. **Must not be shared** across users.
- **Shared / application memory** — about the **application(s)** being built: knowledge, architecture, decisions, best
  practices, business rules, patterns. **Shareable** (across users/teams, conceptually). Must be **entity-based** — a memory
  about *Application A* vs *Application B* vs *a feature of A* is anchored to the right entity, with **entities and
  relationships** between them.

The user's requested shape (confirmed 2026-08-19): a **nightly LangGraph run** that takes the day's sessions, **summarizes +
categorizes** them, **splits personal vs shared** (and, inside shared, into **entities + relationships**), and stores them in a
**memory database**; a **periodic memory-manager** that **organizes, drops outdated memories, and "dreams"** (reflects/refines);
and, on the read side, **queryable memory** injected into new chats / agentic runs via a **separate MCP server** (not the
`genesis-kb` server). Confirmed decisions: **SQLite + sqlite-vec now with an easy Postgres swap later**; a **true relationship
graph with traversal**; **reflection/dreaming in v1**; **MCP-only injection** (the agent is prompted to query it); **personal
memory keyed to a named user**; and a **small local embedder** running in a subprocess (not the always-on server).

**What already exists (so we build on, not rebuild):**
- `chat/store.py` (`ChatStore`/`ChatMessageStore` over `genesis.db`) — the **source** of memory (sessions + messages + per-message
  usage; `chat_sessions.mode` distinguishes chat/copilot/feature_spec).
- `runtime/scheduler.py` + `runtime/schedule_store.py` + **m0012 `scheduled_jobs`** (Phase 23, ADR-047) — the **cadence engine**;
  adding two jobs is `ensure_defaults` rows + two handlers, no new engine.
- `db/database.py` + `db/runner.py` (`Migration`/`migrate()`, contiguity guard, `schema_migrations`) — a **generic** migration
  runner we can point at a **second** `Database(memory.db)` with its own `MEMORY_MIGRATIONS` list.
- `mcp/kb_server.py` + `mcp/introspection_server.py` — the **read-only stdio MCP-server pattern** the `genesis-memory` server
  copies.
- `kb/store.py` — a **precedent for a bi-temporal (SCD-2) graph in SQLite** with **BFS/recursive traversal** (dependency-path /
  transitive-deps), and for `ctx.extras['kb_store']` injection into a workflow worker.
- `nodes/reliable.py` (`reliable_agent_step`, 25-10) — composes the reliability trio in one call for the agent nodes.

**The gaps this phase fills:** there is no memory store, no embedder, no memory workflows, and no `genesis-memory` MCP anywhere
in the codebase (grep-confirmed intent).

---

## 2. Research synthesis (what we borrow, and from where)

A survey of the leading agentic-memory systems (grounded 2026-08-19). We integrate none of them; we reproduce a **minimal, local**
subset of their **concepts**.

| Source | Concept we adopt |
|---|---|
| **mem0** (arXiv 2504.19413; docs "How Mem0 Works") | **Extract facts, not transcripts.** Two phases: **extraction (write)** and **retrieval (read)**. On write, look up similar existing memories and have the LLM classify each candidate as **ADD / UPDATE / DELETE / NOOP**. Split stores: **SQL = source of truth**, **vector = similarity**, **entity store = entity boost**. Retrieval **fuses semantic + keyword + entity + temporal** signals, always **scoped** (`user`/`agent`/`run`). *Don't store secrets.* |
| **Zep / Graphiti** (arXiv 2501.13956) | **Bi-temporal knowledge graph.** Every fact/edge records **valid-time** (when it became / stopped being true) + **transaction-time** (when ingested). On contradiction, **invalidate the old edge** (set `valid_to`) instead of deleting — history is preserved. **Episodic ingestion**, **custom entity types**, **hybrid retrieval** (vector + BM25 + graph traversal), and **communities** (clusters). |
| **Letta / MemGPT** (arXiv 2310.08560; "Sleep-time compute") | **Sleep-time / background consolidation** — a separate agent that runs during "downtime", **rewrites/consolidates** shared memory. This is exactly the user's **nightly job + "dreaming"**. Memory tiers (in-context vs retrieved) inform the MCP injection model. |
| **LangMem** | **Memory taxonomy:** **semantic** (facts), **episodic** (experiences/events), **procedural** (learned rules/preferences/behavior) — and **background** (not just hot-path) formation with dedup + evolution. Maps directly onto our type column. |
| **Stanford Generative Agents** | **Retrieval scoring = recency (exponential decay) + importance (LLM-rated 1–10) + relevance (cosine)**, and **reflection** — periodically synthesize higher-level memories from raw observations. The academic root of "dreaming". |
| **cognee** | **ECL / cognify pipeline** — classify → extract entities+relations → summarize → embed → commit edges — a clean template for the consolidation graph; plus a **refine (memify) loop** ≈ our maintenance job. |
| **A-MEM** (arXiv 2502.12110) | **Zettelkasten memory evolution** — atomic notes with LLM-generated links; when new memory arrives, **linked notes are updated/evolved**. Informs `memory_links` + the maintenance dedup/merge/evolve step. |

**Convergent pattern (our blueprint):** (1) extract atomic memories, never store transcripts; (2) LLM reconciles new-vs-existing
(add/update/invalidate); (3) entities + relationships as a graph; (4) hybrid, owner-scoped retrieval; (5) bi-temporal validity so
stale facts are invalidated not overwritten; (6) a background consolidation + forgetting/reflection pass. Genesis's substitution:
**Kiro (ACP) does all the LLM reasoning inside deterministic workflows**, and a **local embedder** does the vectors — so the whole
system is local and ADR-compliant.

---

## 3. Sub-phases & build order

| # | Sub-phase | What ships | Repo |
|---|---|---|---|
| **26-01** | **Memory model + store + migration** | `memory.db` + `mm0001` (bi-temporal `memory_entities`/`memory_relationships`/`memories`/`memory_links`/`memory_communities`/`memory_consolidation_state` + FTS5) + `MemoryStore`/`GraphStore` (recursive-CTE traversal) with **DB-agnostic signatures**; a second `Database` + `MEMORY_MIGRATIONS` runner. Store unit tests (no LLM/embedder/network). | genesis |
| **26-02** | **Embedder + vector index** | `Embedder` Protocol + a local **ONNX/static** implementation (subprocess-loaded, CPU) + `VectorIndex` over **`sqlite-vec`**; a documented `NullEmbedder` (FTS-only) fallback; embedding-status bookkeeping. Deterministic tests with a fake embedder. | genesis |
| **26-03** | **Consolidation workflow** | `memory-consolidation` LangGraph workflow (extract → classify → entities/relationships → reconcile ADD/UPDATE/INVALIDATE/NOOP → embed → write), Kiro agent nodes under the reliability trio, program I/O nodes; `ctx.extras['memory_store'|'chat_read'|'embedder']` injection; restart-safe via `memory_consolidation_state`. | genesis-workflows (+ genesis wiring) |
| **26-04** | **Memory-maintenance ("dreaming")** | `memory-maintenance` workflow: reflect (synthesize) → dedup/merge/evolve (A-MEM) → invalidate contradicted (bi-temporal) → decay/forget → recompute communities. Idempotent, bounded. | genesis-workflows (+ genesis wiring) |
| **26-05** | **`genesis-memory` MCP + retrieval** | `genesis/mcp/memory_server.py` (read-only, separate from `genesis-kb`) with `search_memory`/`get_entity`/`get_related_entities`/`get_personal_memory`; **hybrid retrieval** (semantic+keyword+entity × recency × importance); embeds the query in-process; steering hint so the agent knows to query it; wired into chat + agentic workflow nodes. | genesis (+ genesis-workflows registry) |
| **26-06** | **Scheduler integration + config** | Register `memory-consolidation` (nightly) + `memory-maintenance` (weekly) on the Phase-23 scheduler (`scheduled_jobs` rows + handlers, preflight-skip when unconfigured); a **named-user** setting for personal-memory ownership; read-only `GET /api/system/memory` status (counts/last-run). | genesis |
| **26-07** | **Release + acceptance** | Release chain (genesis + genesis-workflows), CI green, **ADR-053 + ADR-054 → Accepted**, bible/tracker/progress. | both |

**Suggested order:** 26-01 → 26-02 (store + vectors, testable with fakes, nothing running) → 26-03 (nightly write path) →
26-05 (read path/MCP — makes the memory usable) → 26-04 (dreaming) → 26-06 (schedule + config) → 26-07 (release). 26-04 can trail
26-05 so memory is *usable* before it's *refined*; both ship in the phase (dreaming is v1 per decision §11.4).

---

## 4. The memory model (decided shape)

**Two scopes × three types, entity-anchored, bi-temporal.**

- **Scope** — `personal` (owner = a named user; never entity-shared) or `shared` (about applications/features; entity-anchored,
  conceptually shareable). Single-user today (ADR-026) → scope is a **label + query filter**; when multi-user arrives it becomes
  an **ACL** (the seam is built now, enforcement deferred — §8, ADR-053).
- **Type** (LangMem taxonomy) — `semantic` (facts/knowledge), `episodic` (a decision/event that happened), `procedural`
  (a rule/preference/how-to). Personal skews procedural+episodic; shared skews semantic+episodic.
- **Entity anchoring** — shared memories link to `memory_entities` (`application`, `feature`, `record_type`, `concept`, …,
  reusing Genesis's KB entity vocabulary — an application's `app_uuid`, a feature's id), with **typed relationships** between
  entities (`memory_relationships`) that are **traversable** (recursive CTE, like `KbStore`'s dependency BFS).
- **Bi-temporal** (Graphiti) — every memory and every relationship carries **valid-time** (`valid_from`/`valid_to`) and
  **transaction-time** (`created_at`); a contradiction **closes** (`valid_to = now`, `superseded_by = …`) rather than deleting.
  Consistent with the KB's existing SCD-2 discipline.
- **Retrieval metadata** — `importance` (LLM-rated), `access_count` + `last_used_at` (recency/usage), `source_session_id` +
  `source_message_ids` (provenance), `tags`, and an `embedding` (via `sqlite-vec`).

*(Full DDL in 26-01.)*

---

## 5. Write path — the nightly consolidation workflow (26-03)

A **deterministic `memory-consolidation` LangGraph workflow** (program + narrow Kiro agent nodes; ADR-001; reliability trio on
every agent node). Fired nightly by the Phase-23 scheduler (§6). Graph:

```
resolve_window (program)      # sessions since memory_consolidation_state cursor (yesterday's, unprocessed)
  → load_sessions (program)   # read chat_sessions/messages from genesis.db (READ-ONLY), redact secrets
  → extract_memories (agent + validator)          # atomic facts; per fact: scope(personal|shared), type
  → extract_entities_relationships (agent + validator)  # entities + typed edges for shared memories
  → reconcile (agent + validator + program CAS)    # per candidate vs top-k similar: ADD|UPDATE|INVALIDATE|NOOP
  → embed_and_write (program, asyncio.to_thread)   # embed via Embedder; write MemoryStore (memory.db)
  → advance_cursor (program) → present
```

- **Kiro does the reasoning**; program nodes do all genesis.db reads + memory.db writes + embedding. The **blocking memory.db
  write runs via `asyncio.to_thread`** (the §7 async-write-deadlock lesson — mirrors `sync-application`'s `write_kb`).
- **Reconciliation** (mem0 ADD/UPDATE/DELETE/NOOP + Graphiti invalidation): for each candidate memory, the program node fetches
  the **top-k similar existing memories** (vector + entity), the agent classifies the operation, and the program executes it
  with a compare-and-set on the bi-temporal columns.
- **Restart-safe / idempotent**: `memory_consolidation_state` records the last processed session/day cursor; re-running a day is a
  NOOP-heavy pass (dedup catches re-extraction). Read-only against `genesis.db` (never mutates chat).
- **Secrets never enter memory** (mem0's explicit warning) — a redaction pass in `load_sessions` + an extraction-prompt rule.

---

## 6. Maintenance — the "dreaming" workflow (26-04) + scheduler (26-06)

A lower-frequency **`memory-maintenance`** workflow (weekly by default):

- **Reflect** (Generative-Agents / Letta sleep-time) — synthesize **higher-level memories** from clusters of related
  episodics/semantics ("the team consistently prefers X for Y").
- **Dedup / merge / evolve** (A-MEM + mem0 UPDATE) — collapse near-duplicates; evolve linked notes when new info refines them.
- **Invalidate** (Graphiti) — close facts/edges contradicted by newer, higher-confidence memories (bi-temporal, reversible).
- **Decay / forget** — archive or close low-`importance`, long-unused, superseded memories (never hard-delete history in v1 —
  set `valid_to`/an `archived` flag; a true purge is a later, gated option).
- **Recompute communities/clusters** — refresh `memory_communities` for retrieval boosting.

Both jobs run on the **Phase-23 scheduler** (m0012 `scheduled_jobs`, ADR-047): `memory-consolidation` nightly (e.g. **02:00 IST**,
after the day's chats, before the 07:00 app-sync), `memory-maintenance` weekly (e.g. **Sun 03:00 IST**). Preflight-skip when
Kiro isn't signed in or no sessions exist. They call the same `RunManager.start` a human clicks (ADR-001/033 lineage,
`auto_approve`, no HITL).

---

## 7. Read path — `genesis-memory` MCP + retrieval (26-05)

A **separate** read-only stdio MCP server `genesis/mcp/memory_server.py` (modeled on `kb_server.py`; **not** merged with
`genesis-kb` — decision §11.5), launched `-m genesis.mcp.memory_server --db <memory.db>`. Tools (all read-only, owner/entity
scoped):

- `search_memory(query, scope?, entity_refs?, types?, top_k?)` → ranked memories (hybrid).
- `get_entity(entity_kind, entity_ref)` + `get_entity_memories(entity_ref)`.
- `get_related_entities(entity_ref, rel_type?, depth?)` → **graph traversal** (recursive CTE).
- `get_relationships(entity_ref)` → the edges (with validity).
- `get_personal_memory(query?, types?)` → owner-scoped personal memory (the configured user).

**Hybrid retrieval** = fuse **relevance** (semantic vector via the in-process embedder + keyword FTS5 + entity overlap/graph
proximity) with **recency** (exponential decay on `last_used_at`/`created_at`) and **importance** (Generative-Agents weighted
sum), scoped by `owner`/`entity`, current-time by default (`valid_to IS NULL`). The MCP loads the **embedder in its own process**
(not the app). A **steering hint** (in chat + agentic-node system prompts) tells the agent the memory MCP exists and **when** to
query it (a new chat, an agentic step, or when an application/feature is in context) — injection stays **MCP-only** (decision
§11.5; ADR-002/004/020, ADR-031/045).

---

## 8. Security & ADR posture (stated explicitly)

- **Local single-user, localhost-only (ADR-026).** All LLM reasoning is **Kiro over ACP** (already authed); embeddings are a
  **local model**, CPU, in a subprocess — **no outbound data**, no cloud LLM/embeddings API. No memory service integrated.
- **ADR-001 / ADR-011 / ADR-047.** The consolidation + dreaming jobs are deterministic LangGraph workflows with agent nodes under
  the **reliability trio**, fired by the **existing scheduler** — the same `RunManager.start` a human clicks; `auto_approve`, no
  HITL. LangGraph owns their control flow.
- **ADR-030.** This is the **named "transcript RAG" trigger** for a vector store. We introduce vectors via `sqlite-vec` in a
  **separate `memory.db`** (genesis.db stays SQLite/unchanged) and keep **DB-agnostic repository signatures** so the future
  Postgres+pgvector move is a re-home behind `MemoryStore`/`VectorIndex`/`GraphStore` — **ADR-054**.
- **ADR-031/045.** Memory injection is **read augmentation via a read-only MCP** — no new write authority; posture preserved.
- **Personal vs shared = a scope/ownership boundary.** Single-user today → a label + query filter; **multi-user ACL is deferred**
  (ADR-026). Personal memory is keyed to a **named user** now so the future split is clean (decision §11.6).
- **No secrets in memory** — a redaction pass + extraction-prompt rule (mem0's warning); memory rows are metadata/derived facts,
  not raw transcripts.

Recorded as **ADR-053** (the Memory Layer) + **ADR-054** (the store/infra + local embedder) — §10.

---

## 9. Non-goals / deferred

- **Multi-user sharing / ACL enforcement** — the scope/owner columns exist; enforcement + a sharing UX is deferred to the
  multi-user track (ADR-026).
- **Postgres + pgvector (+ Apache AGE) migration** — designed-for (the seam), not built now; a later swap when scale/multi-user
  triggers it (ADR-054 records the plan).
- **A memory-browser UI** — out of v1 (a read-only `GET /api/system/memory` status is the only surface); a Settings "Memory"
  panel to inspect/pin/forget memories is a follow-up.
- **Hot-path (in-turn) memory writes** — v1 forms memory in the **background** (nightly), not on every turn (LangMem's hot path is
  deferred; avoids per-turn latency/cost).
- **Auto pre-fetch + prompt injection at chat start** — deferred; **MCP-only** now (decision §11.5). (An optional pre-fetch behind
  a flag is a possible follow-up.)
- **Hard-deleting memories** — v1 invalidates/archives (bi-temporal, reversible); a true purge/GDPR-style delete is a later gated
  option.
- **Embedding the full KB / documents into memory** — out; memory is distilled from **conversations**. (The KB + Document Library
  remain their own stores/MCP.)

---

## 10. Decision record (ADRs — to be added to the decision log on approval)

- **ADR-053 (PROPOSED) — Genesis Agentic Memory Layer.** Genesis distils its stored conversations into a persistent,
  self-maintaining **agentic memory** with two scopes — **personal** (a named user's preferences/rules/habits, never shared) and
  **shared** (application knowledge/architecture/decisions/patterns, **entity-anchored** with **traversable relationships**) — and
  three types (semantic/episodic/procedural). Memory is **formed in the background** by a **nightly `memory-consolidation`
  LangGraph workflow** (extract atomic memories → classify → entities+relationships → reconcile ADD/UPDATE/INVALIDATE/NOOP →
  embed → write) and **refined by a periodic `memory-maintenance` "dreaming" workflow** (reflect / dedup-evolve / invalidate /
  decay / cluster), both on the Phase-23 scheduler. All reasoning is **Kiro over ACP** inside deterministic workflows (ADR-001;
  reliability trio ADR-011); it is **read-augmentation only**, injected via a **separate read-only `genesis-memory` MCP** (ADR-031/045
  preserved; not merged with `genesis-kb`). **Bi-temporal** validity (Graphiti-style) invalidates rather than overwrites.
  **Local single-user** (ADR-026) — personal/shared is a scope label now, a multi-user ACL later. No external memory service.
  Concepts adopted from mem0 / Zep-Graphiti / Letta / LangMem / cognee / A-MEM / generative-agents (§2). Ships genesis + a local
  embedder + two genesis-workflows.
- **ADR-054 (PROPOSED) — Memory store & infrastructure: separate `memory.db` on SQLite + sqlite-vec now, DB-agnostic seam to
  Postgres + pgvector later; local embedder.** Agentic memory lives in a **new, separate `~/.genesis/memory.db`** (not
  `genesis.db`) with its own migration set, holding a **bi-temporal entity-relationship model** + **FTS5 keyword index** +
  **`sqlite-vec` vector index**, behind **DB-agnostic repository interfaces** (`MemoryStore` + `GraphStore` + `VectorIndex` +
  `Embedder`). This is the explicit **ADR-030 "transcript RAG" trigger** for introducing vectors, kept local (ADR-026) and
  isolated (a future **Postgres + pgvector + optional Apache AGE** migration re-homes one subsystem behind the interfaces, not the
  whole platform, and does not touch the runs/checkpoint plane). Embeddings are produced by a **small local model** (ONNX/static,
  e.g. quantized `bge-small` via `fastembed` or `model2vec`, ~30–150 MB artifact, CPU, ms-latency) loaded **only in the
  worker/MCP subprocess** — **no outbound data**; the `Embedder` is swappable and optional (a `NullEmbedder` degrades to
  FTS5+graph retrieval). Preserves ADR-046 (no Docker / no new always-on service; the model artifact is a first-run download).

---

## 11. Decisions (resolved 2026-08-19)

1. **Infra → SQLite + `sqlite-vec` in a separate `memory.db` now, with a DB-agnostic seam so Postgres + pgvector is an easy swap
   later.** (User: "definitely move to Postgres in future — make the swap very easy.")
2. **Graph → a true relationship graph with traversal** (recursive-CTE now; Apache AGE / relational edges on the Postgres swap).
3. **Reflection / "dreaming" → in v1** (the `memory-maintenance` workflow ships in this phase, not deferred).
4. **Injection → MCP-only** — a separate `genesis-memory` MCP; the agent is prompted (steering) to query it when relevant. No
   auto pre-fetch/inject in v1.
5. **Personal memory → keyed to a named user** (a username setting), even though single-user today — to make the future
   multi-user split clean.
6. **Embedder → a small local model** (ONNX/static, CPU, subprocess-loaded), behind a swappable `Embedder` seam — accepted after
   confirming it is **not** a RAM-heavy LLM (~30–150 MB artifact, CPU, loaded only in the worker/MCP subprocess, ms-latency).

---

## 12. Release & test plan

- **Repos:** **genesis** (memory.db + `mm0001` + `MemoryStore`/`GraphStore`/`VectorIndex`/`Embedder` + local embedder + the
  `genesis-memory` MCP + two scheduler jobs + username setting + `GET /api/system/memory`) and **genesis-workflows** (the
  `memory-consolidation` + `memory-maintenance` workflows + registry/mcp-registry entries). genesis-core likely unchanged. Release
  order: (core if touched →) **genesis → genesis-workflows** (so the workflow library pins the genesis tag that ships the store +
  MCP + `ctx.extras` injection).
- **Schema:** a **separate `memory.db`** with its own `MEMORY_MIGRATIONS` (`mm0001`) + `schema_migrations` — **`genesis.db` is
  untouched** (no genesis.db `current_version` bump; the existing `current_version==N` tests are unaffected). A memory.db
  migration round-trip test + a `genesis db upgrade` that also upgrades memory.db.
- **Deps (genesis):** the embedder runtime (`fastembed`/`onnxruntime` or `model2vec`, pinned) + `sqlite-vec` (pinned) — CPU-only,
  no torch. The model artifact is fetched on first run and cached under `~/.genesis/` (documented prereq; offline fallback =
  `NullEmbedder` → FTS5+graph).
- **Tests:** (26-01) `MemoryStore`/`GraphStore` bi-temporal apply + recursive traversal + scope isolation + `untrack`/decay units
  (no LLM/embedder/network). (26-02) `VectorIndex` round-trip + a **fake embedder** hybrid-rank unit + a `NullEmbedder`
  degradation test. (26-03/26-04) workflow node tests with a **stubbed Kiro** (`set_collect_impl`) + a fake store/embedder —
  extraction→reconcile ADD/UPDATE/INVALIDATE/NOOP transitions, restart-safe cursor, reflection/decay/dedup; reliability-trio lint
  passes on every agent node; `ci/validate_library.py` green. (26-05) MCP tool contracts (shapes) + hybrid-ranking pure-function
  units + a guard that the server is read-only and owner-scoped. (26-06) scheduler due-slot units (reuse the Phase-23 fake-clock)
  + preflight-skip + the username setting. Full existing suites stay green; ruff/eslint/tsc clean; `web/static` rebuilt if any web
  lands (v1 is backend-only unless a status chip is added).
- **Acceptance (user-driven / observed):** with Kiro signed in and a day of chats present, manually trigger `memory-consolidation`
  → memories appear in `memory.db` split personal/shared with entities+relationships; query the `genesis-memory` MCP (via chat or
  a direct tool call) for an application/feature → relevant memories return, graph traversal resolves related entities; run
  `memory-maintenance` → duplicates merge, a contradicted fact is invalidated (not deleted), stale low-value memories are archived;
  leave `genesis serve` up across the nightly slot → the job fires once and records `last_run_*`. (Real nightly firing + Kiro
  reasoning quality are observed over time; the LLM reasoning can't be driven headlessly — the manual trigger is the check.)

---

## 13. Open items to confirm with the human

*(Resolved: infra = SQLite+sqlite-vec with a Postgres-ready seam; graph-with-traversal = yes; dreaming = v1; injection = MCP-only;
personal = named user; embedder = small local model. Remaining, non-blocking, can be decided at build time:)*

1. **Embedder model choice** — quantized `bge-small` via `fastembed` (higher quality, ~130 MB, ONNX) **vs** `model2vec` static
   (~30 MB, near-zero compute, slightly lower quality). Lean: start `fastembed`/`bge-small`; the seam makes it swappable.
2. **Consolidation cadence** — nightly at **02:00 IST** (proposed). Confirm the slot (must precede the 07:00 app-sync and follow
   the day's activity).
3. **Maintenance cadence** — weekly **Sun 03:00 IST** (proposed) vs a longer/shorter cycle.
4. **Retention of raw memories** — v1 never hard-deletes (invalidate/archive). Confirm that's acceptable (a true purge is a gated
   follow-up).
