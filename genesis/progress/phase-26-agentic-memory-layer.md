# Phase 26 — Agentic Memory Layer — progress (as-built)

> Running as-built record for Phase 26 (spec: `specs/phase-26-agentic-memory-layer.md` + `26-01..26-08`).
> **Status:** IN PROGRESS — **26-01 + 26-02 BUILT (unreleased)**; ships via 26-07. Repos: **genesis** (+
> **genesis-workflows** from 26-03). genesis code commits are local on `genesis` master (no tag yet — the
> phase release is 26-07). No user-facing surface until the MCP (26-05) / UI (26-08).

## 26-01 — Memory model, store & migration ✅ BUILT (unreleased)
- **Commit:** genesis `14eb3ab` (local, master). **No release/tag** (26-07).
- **As built:** a NEW, separate **`~/.genesis/memory.db`** (genesis.db untouched, stays `current_version`
  14) with its own migration set + `schema_migrations`:
  - `genesis/memory/migrations/mm0001_memory.py` — the bi-temporal model: `memory_entities`, traversable
    `memory_relationships`, atomic `memories` (semantic/episodic/procedural; personal/shared; + the 26-08
    human-curation columns `origin`/`pinned`/`protected`/`user_verified`/`review_status`/`edited_by`/
    `confidence`), `memory_entity_links`, `memory_links` (A-MEM), `memory_communities`, a singleton
    `memory_consolidation_state` cursor, and an **FTS5** external-content keyword index + sync triggers.
  - `genesis/memory/store.py` — **`MemoryStore`** (add / update-supersede / invalidate / archive /
    set_flags / forget_before [skips human-curated] / mark_used / mark_embedded / pending_embeddings;
    `upsert_entity` [manual select-then-write — SQLite treats a NULL owner as DISTINCT so `ON CONFLICT`
    wouldn't dedup shared entities]; relationships + invalidation; memory↔entity links; memory_links;
    communities; FTS5 keyword search + scope/owner/type/entity filters; consolidation cursor) and
    **`GraphStore`** (recursive-CTE traversal, current-time aware).
  - `genesis/memory/{models,db,__init__}.py`; `Settings.memory_db_path`; `migrate_memory` at `create_app`
    boot + `genesis db upgrade`/`db status` upgrade+report **both** DBs. **DB-agnostic signatures**
    (ADR-030/054) so the future Postgres+pgvector(+AGE) swap is a re-home.
- **Verified:** `tests/test_memory_store.py` (13) — migration + idempotency + separateness-from-genesis.db;
  bi-temporal add/supersede/invalidate/archive; `forget_before` respects pinned/protected/user; FTS5
  keyword; scope/owner isolation; entity upsert dedup; graph traversal depth + currency; cursor. genesis
  pytest 575→588; ruff clean. CLI smoke: `db upgrade` → genesis.db `[1..14]` + memory.db `[1]`.
- **Notable fix:** the NULL-owner UNIQUE pitfall (above) — dedup for shared entities would have silently
  broken; caught by a test + fixed with a manual upsert.

## 26-02 — Embedder & vector index ✅ BUILT (unreleased)
- **Commit:** genesis `67bd71b` (local, master).
- **As built:**
  - `genesis/memory/embedder.py` — an `Embedder` Protocol + `NullEmbedder` (dim 0 → FTS+graph only),
    `FakeEmbedder` (deterministic, pure-python, tests), `LocalEmbedder` (lazy; **default backend
    `model2vec` static** — lightest, no onnxruntime; `fastembed`/bge-small as a swappable alternative).
    `build_embedder()` **degrades to NullEmbedder (logged)** if the optional model dep is absent.
  - `genesis/memory/vector.py` — a `VectorIndex` Protocol + `SqliteVecIndex` (sqlite-vec `vec0` cosine,
    lazily created against the embedder `dim`, kept OUT of mm0001) + `BruteForceVectorIndex` (pure-python
    cosine fallback when a SQLite build can't load extensions). `build_vector_index` probes sqlite-vec →
    falls back; `embed_pending` embeds+indexes pending memories (NullEmbedder → `skipped`).
  - **Deps:** `sqlite-vec==0.1.9` (core, tiny pure wheel); `[embeddings]`=model2vec + `[embeddings-onnx]`=
    fastembed (OPTIONAL extras — core clone stays light [ADR-046], CI fast; embedder loads only in the
    worker/MCP subprocess — no outbound data [ADR-026]). `Settings.memory_embedder_backend`/`model`.
- **Build-time decision:** default embedder = **model2vec static** (directly answers the Phase-26 RAM /
  "just a program" concern; no onnxruntime), behind the pluggable seam — a reasoned refinement of the
  earlier bge-small lean; not locked in.
- **Verified:** `tests/test_memory_vector.py` (10) — Fake/Null embedders; brute-force cosine ordering +
  id-filter + delete; **real `SqliteVecIndex` round-trip** (exercised — sqlite-vec present + extension
  loads); `embed_pending` backfill + NullEmbedder→skipped; `build_embedder` fallback. genesis pytest
  588→598; ruff clean across `genesis`.

## Next
- **26-03** — the nightly `memory-consolidation` LangGraph workflow (genesis-workflows) + `ctx.extras`
  wiring (memory_store / chat_read / embedder) in genesis. Then 26-05 (MCP), 26-08 (UI), 26-04 (dreaming),
  26-06 (scheduler/config), 26-07 (release: bump/tag genesis + genesis-workflows, ADR-053/054 → Accepted).
