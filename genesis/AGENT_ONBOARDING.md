# Genesis — Agent Onboarding & Reference ("the bible") — INDEX

> **This is the bible index.** The Genesis bible is the single, task-agnostic source of truth that brings any agent
> session fully up to speed on Genesis and defines every practice you must follow. It has been **split into functional
> chunks** under [`bible/`](./bible/) so that agents can find + update the right part without wrestling a 1,300-line file.
> **Splitting changed the packaging, NOT the authority: the bible is still one document — read + obey all of it.**
>
> ## ⛔ MANDATORY — what "read the bible" means
> When the human says **"read the bible"** (or points you at `AGENT_ONBOARDING.md`), you MUST:
> 1. Read **this index**, then
> 2. Read **every chunk listed in the manifest below, in order** — not just the one that looks relevant. The chunks are
>    interdependent (architecture ↔ ADRs ↔ lessons ↔ the loop); skipping any means you will violate a constraint you
>    never read.
> 3. Then **follow all of it religiously** for the rest of the session — the ADRs (§5) and working agreements (§8/§10)
>    are non-negotiable; the lessons (§7) are do-not-regress.
>
> After reading, briefly **restate** the architecture + current state + the non-negotiables, then do the work the human
> gives you following the loop in `bible/07-working-on-tasks-and-agreements.md` (§8). **This document assigns no task.**
>
> **Last refreshed: 2026-08-20 — latest SHIPPED: genesis v0.51.4 + genesis-core v0.9.5 + genesis-workflows v0.9.6 +
> kiro-agent-sdk v0.7.0 + genesis-appian-parser v0.2.0.** (genesis v0.50.0 + genesis-core v0.9.5 = the
> Phase-25 Architectural Foundation Hardening release (v0.49.0 + v0.50.0), sub-phases 25-01..25-10 + 25-13 (25-11 + 25-12 backlog) — Phase 25 COMPLETE.)
> **Newest planning: Phase 26 — Agentic Memory Layer — IN PROGRESS. 26-01 (separate `memory.db` + MemoryStore/
> GraphStore + mm0001) + 26-02 (local Embedder + sqlite-vec VectorIndex) + 26-03 (the nightly
> `memory-consolidation` workflow + ctx.extras wiring) are BUILT (unreleased — local on `genesis` +
> `genesis-workflows` master, no tag; the phase release is 26-07). NEXT = 26-05 (the read-only `genesis-memory`
> MCP). Umbrella + 26-01..26-08 spec'd; Proposed ADR-053 + ADR-054.**
> See `bible/08-roadmap-and-backlog.md` §9 + `specs/phase-26-agentic-memory-layer.md` + `progress/phase-26-agentic-memory-layer.md`.
> (Full phase/release banner + version detail live in
> `bible/00-onboarding-and-overview.md` and `bible/01-current-state.md`.)

---

## ▶ ACTIVE HANDOFF — continue Phase 26 (Agentic Memory Layer) at **26-05**

> **After reading the whole bible, this is the work to pick up.** Phase 26 is IN PROGRESS; **26-01 + 26-02 +
> 26-03 are BUILT + tested green but UNRELEASED** (local commits, no tag — the phase release is **26-07**).
>
> **Read first (in this order):** `specs/phase-26-agentic-memory-layer.md` (umbrella) →
> `specs/phase-26-agentic-memory-layer/26-05-genesis-memory-mcp-and-retrieval.md` (the next task) →
> `progress/phase-26-agentic-memory-layer.md` (as-built for 26-01..26-03) → `bible/08` §9 Phase-26 block →
> **Proposed ADR-053 + ADR-054** in `bible/04`. Then read the code the task cites (below) before editing.
>
> **Done so far (reuse these — do NOT rebuild):**
> - **26-01** — a **separate `~/.genesis/memory.db`** (genesis.db untouched at v14) + `mm0001` + `MemoryStore`
>   / `GraphStore` in `genesis/genesis/memory/{store,models,db,migrations}.py`. Key reads you'll call:
>   `MemoryStore.search_memories(query,scope,owner,types,entity_ids,top_k,current)` (FTS5 + filters),
>   `get_entity`/`get_entity_by_id`/`get_entity_memories`, `mark_used(ids)`; `GraphStore.related_entities(id,
>   rel_type,depth,current)` (recursive-CTE traversal) / `relationships_of`. DB-agnostic (ADR-030/054).
> - **26-02** — `genesis/memory/embedder.py` (`Embedder` protocol; `NullEmbedder`/`FakeEmbedder`/`LocalEmbedder`
>   [default **model2vec** static, optional extra `pip install genesis[embeddings]`]; `build_embedder(settings)`
>   → degrades to NullEmbedder if the dep is absent) and `genesis/memory/vector.py` (`VectorIndex` protocol;
>   `SqliteVecIndex` [sqlite-vec `vec0` cosine] + `BruteForceVectorIndex` pure-python fallback;
>   `build_vector_index(db,dim)` returns None when dim==0; `embed_pending`). `sqlite-vec==0.1.9` is a core dep.
> - **26-03** — `ctx.extras` now carries `memory_store` / `chat_read` (read-only) / `embedder_factory` (lazy),
>   wired in `genesis/runtime/context.py`; the nightly **`memory-consolidation`** workflow lives in
>   genesis-workflows (`workflows/memory-consolidation/`, registered).
>
> **NEXT = 26-05 — the read-only `genesis-memory` MCP + hybrid retrieval (makes memory usable by the agent):**
> - Model it on **`genesis/genesis/mcp/kb_server.py`** (read-only stdio JSON-RPC MCP; launched `-m
>   genesis.mcp.memory_server --db <memory.db>`). Add `genesis/genesis/mcp/memory_server.py` +
>   **`genesis/genesis/memory/retrieval.py`** (a PURE, unit-tested fuse: relevance [semantic vector +
>   keyword FTS5 + entity/graph proximity] × **recency** [exp decay on `last_used_at`/`created_at`] ×
>   **importance**; α=0 when NullEmbedder → degrades to keyword+entity — Generative-Agents scoring).
> - Tools (all read-only, owner/entity-scoped): `search_memory(query,scope,entity_refs,types,top_k)`,
>   `get_entity`/`get_entity_memories`, `get_related_entities(entity_ref,rel_type,depth)` (graph traversal),
>   `get_relationships`, `get_personal_memory` (the configured owner only).
> - **Build the embedder inside the MCP subprocess** via `build_embedder(settings)` (NEVER in the web process);
>   candidate-generate with `VectorIndex.search` (scope/entity pre-filtered) ∪ `MemoryStore.search_memories`
>   ∪ `GraphStore`; owner scoping — until the 26-06 `memory_owner_username` setting lands, pass `--owner`
>   (default `"local"`). **Injection is MCP-only** (ADR-002/004/020, ADR-031/045): wire `genesis-memory` into
>   chat (`genesis/genesis/chat/mcp.py`, alongside `genesis-kb`) + relevant agentic nodes + a **steering hint**
>   telling the agent to query it; add a `genesis-memory` entry to genesis-workflows `mcp-registry.json`.
>   **No write tools** — the MCP stays strictly read-only.
>
> **Then (remaining build order):** 26-05 → **26-08** (Memory Management UI + Obsidian-style graph + curation
> API) → **26-04** (the `memory-maintenance` "dreaming" workflow) → **26-06** (scheduler jobs + `memory_owner_username`
> setting + `GET /api/system/memory`) → **26-07** (release: bump/tag **genesis + genesis-workflows**, `genesis db
> upgrade` covers both DBs, ADR-053/054 → Accepted, bible/tracker/progress).
>
> **Gotchas / rules:** memory.db is **separate** (`settings.memory_db_path`) with its own migration set — never
> mix with genesis.db migrations; the embedder/vector index only load in the **worker/MCP subprocess**;
> retrieval must handle `NullEmbedder` (dim 0 / index None) → FTS+graph; memory.db writes inside async nodes go
> via `asyncio.to_thread` (bible §7). **Code commits are local/unpushed** (genesis + genesis-workflows master,
> no tag) — the release is 26-07; don't push master / bump versions until then unless the human asks.
>
> **Dev/test (bible §6):** venv `genesis/.venv`. Gates: `cd genesis && .venv/bin/python -m pytest -q -p
> no:warnings` (currently **598**) `+ .venv/bin/ruff check genesis`; workflows `cd genesis-workflows &&
> ../genesis/.venv/bin/python ci/validate_library.py` `+ ... -m pytest -q workflows --ignore=workflows/_fixtures`
> (currently **86**). Stub Kiro in tests via `set_collect_impl` (see `workflows/memory-consolidation/tests/`).

---

## 📚 The bible manifest (read all, in this order)

| # | Chunk | Original § | What it holds — why you read it |
|---|---|---|---|
| 0 | [`bible/00-onboarding-and-overview.md`](./bible/00-onboarding-and-overview.md) | header + §0 + §1 | Purpose + how to keep the bible current; the phase/release banner; **what Genesis is** (one paragraph); the **onboarding read-order** (which design docs + code to read before touching an area). **Start here.** |
| 1 | [`bible/01-current-state.md`](./bible/01-current-state.md) | §2 | **Current state** — the five-repo tag table, dependency chain, test counts, milestones, and "what works today". *Changes every release.* |
| 2 | [`bible/02-architecture.md`](./bible/02-architecture.md) | §3 | **Architecture / mental model** — layered design (agents never orchestrate), the reliability trio, state/blackboard rule, subprocess-worker execution, the SQLite data plane, HITL modes, release/versioning. |
| 3 | [`bible/03-codebase-map.md`](./bible/03-codebase-map.md) | §4 | **Codebase map** — where every module lives across genesis-core / genesis / genesis-workflows / kiro-agent-sdk / genesis-appian-parser. |
| 4 | [`bible/04-adrs-and-constraints.md`](./bible/04-adrs-and-constraints.md) | §5 | **Non-negotiable constraints** — ADR-001..047 + key implementation contracts. **Do not violate; flag + confirm if a task requires it.** |
| 5 | [`bible/05-dev-loop-and-release.md`](./bible/05-dev-loop-and-release.md) | §6 | **Environment, dev loop, release, CI** — the venv, how to run tests/app, the versioning/tag/push protocol, CI, npm/gitignore gotchas. |
| 6 | [`bible/06-hard-won-lessons.md`](./bible/06-hard-won-lessons.md) | §7 | **Hard-won lessons** — concrete bugs + root causes you must not regress. *Grows often.* |
| 7 | [`bible/07-working-on-tasks-and-agreements.md`](./bible/07-working-on-tasks-and-agreements.md) | §8 + §10 | **The work loop** (understand→verify→scope→test→gates→release→document→report) + the **working agreements** (honest pushback, ask before destructive actions, keep scope tight). |
| 8 | [`bible/08-roadmap-and-backlog.md`](./bible/08-roadmap-and-backlog.md) | §9 | **Roadmap & backlog** — the shipped-phase as-builts (context) + what is next. *Largest; grows every phase.* |

Adjacent authoritative folders (referenced throughout the chunks): [`specs/`](./specs/) (per-phase plans + `specs/backlog/` deferred work + `specs/bugs/` filed defects), [`progress/`](./progress/) (as-built records), [`reference/`](./reference/) (decision-log/ADRs, coding-standards, taxonomies), [`spike/`](./spike/), [`tracker.md`](./tracker.md) (§6 status log = running history).

---

## 🔁 Cross-reference map (§N → chunk)

The chunks preserve the original section numbers, so references inside them like *"see §7"* / *"per §2"* still resolve.
Use this map:

- **§0** What Genesis is → chunk 00 · **§1** How to onboard → chunk 00
- **§2** Current state → chunk 01
- **§3** Architecture → chunk 02
- **§4** Codebase map → chunk 03
- **§5** ADRs / constraints → chunk 04
- **§6** Environment / dev loop / release / CI → chunk 05
- **§7** Hard-won lessons → chunk 06
- **§8** The work loop → chunk 07 · **§10** Working agreements → chunk 07
- **§9** Roadmap & backlog → chunk 08

---

## ✍️ Keeping the bible current (part of Definition of Done)

When tags, architecture, ADRs, or hard-won lessons change, update the **specific chunk** (not a monolith) and this
index's "Last refreshed" stamp. Routing:

- **A release** (new tag / version / test counts / "what works") → `bible/01-current-state.md` (§2) + this index's
  Last-refreshed line + the release banner in `bible/00-onboarding-and-overview.md`.
- **A new/changed ADR** → `bible/04-adrs-and-constraints.md` (§5) — and mirror the decision in `reference/decision-log.md`.
- **A new hard-won lesson** → `bible/06-hard-won-lessons.md` (§7).
- **A new module / moved code** → `bible/03-codebase-map.md` (§4).
- **A roadmap/phase change** → `bible/08-roadmap-and-backlog.md` (§9).
- **A change to the process/loop or working agreements** → `bible/07-working-on-tasks-and-agreements.md` (§8/§10).

Rules for editing a chunk: **keep it verbatim-faithful — never summarize away or drop existing content when adding an
entry** (the intelligence of the bible is the accumulated detail). Append/refine in place. If you add a NEW chunk, add a
row to the manifest above and to the §→chunk map. Then push project-tracker (`git pull --rebase` → push) per §6.
