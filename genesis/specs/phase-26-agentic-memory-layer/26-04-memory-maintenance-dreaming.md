# 26-04 — `memory-maintenance` workflow (the periodic "dreaming" refiner)

> **Status:** 📋 DRAFT · **Repos:** genesis-workflows (the workflow) + genesis (wiring reused from 26-03) · **Depends on:** 26-01, 26-02, 26-03 (store + embedder + the reconcile primitives) · **Unblocks:** 26-06 (scheduler fires it) · **Proposed ADR:** ADR-053
> **Goal:** A **periodic** deterministic LangGraph workflow that keeps memory healthy — **reflect** (synthesize higher-level
> memories), **dedup/merge/evolve** (A-MEM), **invalidate** contradicted facts (bi-temporal), **decay/forget** stale low-value
> memories, and **recompute communities/clusters**. This is the user's **"dreaming"** — shipped in v1 (decision §11.4). Kiro does
> the synthesis (reliability trio); program nodes do I/O; nothing is hard-deleted (reversible).

## 1. Concept grounding
- **Reflection** (Stanford generative agents) — periodically synthesize higher-level memories from clusters of raw
  observations ("the team consistently prefers X for Y" from many episodics).
- **Sleep-time consolidation** (Letta) — a background pass that rewrites/refines the shared memory during downtime.
- **Memory evolution** (A-MEM) — when memories relate, evolve the linked notes; maintain the note-link network (`memory_links`).
- **Fact invalidation + communities** (Graphiti) — close contradicted edges (bi-temporal), cluster entities into communities for
  retrieval boosting.
- **Forgetting** — decay by low importance + long disuse + supersession (soft archive in v1, not purge).

## 2. Graph

```
load_candidates (program)          # clusters/episodics per scope+entity; near-duplicate groups; stale set; contradiction pairs
  → reflect (agent + validator)    # synthesize higher-level memories (origin='reflection') from clusters
  → dedup_merge_evolve (agent + validator)   # collapse near-dups (UPDATE), evolve linked notes, add memory_links
  → invalidate_contradictions (agent + validator)  # close facts/edges contradicted by newer higher-confidence memory
  → recompute_communities (program, + optional agent labels)
  → decay_forget (program)         # archive low-importance + long-unused + superseded (soft)
  → embed_new (program, to_thread) # embed the reflection memories; VectorIndex.upsert
  → present
```

- **`load_candidates` (program):** pure selection over `MemoryStore`/`VectorIndex` — group near-duplicates (high cosine + entity
  overlap), collect episodics per (scope, entity) for reflection, find candidate contradictions (opposing facts on the same
  edge), and the stale set (`importance < θ AND last_used_at < now-δ AND access_count low`). All bounded (top-N per group) to keep
  the Kiro turns small.
- **`reflect` (agent, reliable):** given a cluster, emit 0..k higher-level memories with citations to the source memory ids →
  `record_reflection` + `add_memory_link(type='elaborates')`. Validator: cites real source ids; non-trivial (not a restatement).
- **`dedup_merge_evolve` (agent, reliable):** for each near-dup group, choose a canonical + `update_memory`(supersede) the rest;
  add `memory_links` (`refines`/`related`) where notes relate but shouldn't merge (A-MEM). Validator: references real ids;
  never merges across `scope`/`owner`.
- **`invalidate_contradictions` (agent, reliable):** for each candidate pair, if the newer/higher-confidence memory contradicts,
  `invalidate_memory`/`invalidate_relationship(by_memory_id=…)` (bi-temporal close, reversible). Validator: only closes when a
  clear supersession exists.
- **`recompute_communities` (program + optional agent label):** cluster entities via graph connectivity + embedding proximity →
  `upsert_community`; an optional small agent turn labels/summarizes each community.
- **`decay_forget` (program):** `archive_memory` the stale set (soft; `MemoryStore.forget_before`-style). **No hard delete in v1**
  (history preserved; a true purge is a gated follow-up per umbrella §9).
- **`embed_new` (program, `asyncio.to_thread`):** embed reflection memories; `VectorIndex.upsert`; set `embedding_status`.

## 3. Safety & determinism
- Same posture as 26-03: ADR-001 (LangGraph control flow), reliability trio on every agent node, `auto_approve`/no HITL,
  read-only against genesis.db, memory.db writes via `to_thread`. **Idempotent + bounded** (top-N per group; a re-run converges —
  no runaway merging). **Reversible** (invalidate/archive set flags/`valid_to`, never `DELETE`).
- **Scope integrity:** never merges/links/reflects across `scope` or `owner` (personal stays personal).

## 4. Files & tests
- **New (genesis-workflows):** `workflows/memory-maintenance/{workflow.yaml, graph.py, common/…}` + `tests/`. Reuses the
  `ctx.extras` wiring from 26-03 (no new genesis wiring beyond registration).
- **Tests (stubbed Kiro + fake store/embedder):** reflection emits cited higher-level memories; dedup collapses a seeded dup group
  to one canonical + supersedes the rest; contradiction invalidates the older fact (bi-temporal, not deleted); decay archives only
  the stale set; communities recomputed; **convergence** test (a second run is a NOOP-heavy pass); scope/owner never crossed;
  reliability-trio + `ci/validate_library.py` green.

## 5. Acceptance criteria
1. `memory-maintenance` reflects, dedups/evolves, invalidates contradictions, decays/forgets, and recomputes communities —
   idempotently and reversibly.
2. No cross-scope/owner contamination; nothing hard-deleted in v1.
3. Reliability trio + contract lint green; runs read-only against genesis.db.

## 6. Out of scope
- Retrieval/MCP (26-05); scheduling cadence (26-06); a true purge/GDPR delete (gated follow-up).
