# 26-02 — Embedder & vector index (`Embedder` protocol, local model, `sqlite-vec`)

> **Status:** 📋 DRAFT · **Repo:** genesis · **Depends on:** 26-01 (`MemoryStore`) · **Unblocks:** 26-03 (embed-on-write), 26-05 (semantic retrieval) · **Proposed ADR:** ADR-054
> **Goal:** Add a **pluggable, local `Embedder`** (a small CPU model, loaded only in the worker/MCP subprocess — no outbound
> data, ADR-026) and a **`VectorIndex`** over **`sqlite-vec`**, behind DB-agnostic interfaces so a future pgvector swap is a
> re-home. The embedder is **swappable and optional** — a `NullEmbedder` degrades retrieval to FTS5 + graph with no schema
> change.

## 1. Why an embedder (recap of the grounded decision)
Retrieval fuses three signals — **keyword** (FTS5), **entity/graph** (26-01), and **semantic** (vectors). Semantic match rescues
queries that neither share words nor name a known entity (paraphrase). An embedder turns text → a fixed-length vector; nearest
vectors ≈ closest meaning. **It is not a chat LLM:** embedding models are 22M–140M params (~30–150 MB), **CPU**, one forward pass
(~5–50 ms). It runs **only** during the nightly consolidation (worker subprocess) and at query time (the MCP subprocess) — never
in the always-on `genesis serve` process (ADR-026/046 preserved).

## 2. Design

### 2.1 `Embedder` protocol (`genesis/memory/embedder.py`)
```python
class Embedder(Protocol):
    model_id: str
    dim: int
    def embed(self, texts: list[str]) -> list[list[float]]: ...   # batch; deterministic per model
    def embed_query(self, text: str) -> list[float]: ...
```
- **Default impl — `LocalEmbedder`:** a small ONNX/static model. Two candidate backends behind the same protocol (choice
  finalized at build; §umbrella 13.1):
  - **`fastembed`/ONNX** with a quantized `bge-small-en` (384-dim, ~130 MB) — higher quality, no PyTorch dependency.
  - **`model2vec` static** (e.g. `potion-base-8M`, ~30 MB) — token→vector lookup + pooling, near-zero compute, no transformer
    inference; best for the tightest RAM budget.
  Lazy-loaded on first `embed`; the process holds it only while the job/query runs. Pinned dependency + pinned model id + pinned
  `dim` (a model/dim change is a re-embed migration, tracked via `memories.embedding_status`).
- **`NullEmbedder`:** `dim=0`, `embed→[]` — used offline / by choice; the vector table is simply empty and retrieval falls back to
  FTS5 + graph (26-05 handles the fuse gracefully). Lets Genesis boot + form memory with **zero** model artifact if desired.
- **Where it lives / loads:** injected into the worker via `ctx.extras['embedder']` (26-03) and constructed inside the
  `genesis-memory` MCP process (26-05). **Never constructed in `create_app`/the web process.**

### 2.2 `VectorIndex` (`genesis/memory/vector.py`, over `sqlite-vec`)
- A tiny migration-adjacent setup that `CREATE VIRTUAL TABLE IF NOT EXISTS memory_vectors USING vec0(memory_id INTEGER PRIMARY
  KEY, embedding FLOAT[<dim>])` — created **lazily against the configured `dim`** the first time a real embedder is used (kept out
  of `mm0001` so a `NullEmbedder`/pgvector deployment doesn't need it; ADR-054 DB-agnostic seam).
- `VectorIndex` interface (DB-agnostic): `upsert(memory_id, vector)`, `delete(memory_id)`, `search(query_vector, k, *,
  memory_ids=None) -> [(memory_id, distance)]` (cosine). The `sqlite-vec` KNN + an optional `memory_ids` pre-filter (from the
  scope/entity SQL filter) implement the **filtered vector search** pattern (crunchy/pgvector-style hybrid) — so semantic search
  is always scoped, never "top-k over everything".
- **Postgres swap (documented, not built):** the same interface backed by **pgvector** (`vector` column + HNSW index + a hybrid
  SQL that fuses cosine with `tsvector` rank), optionally **Apache AGE** for the relationship graph — ADR-054.

### 2.3 Embed-on-write + status
- The consolidation `embed_and_write` node (26-03) calls `embedder.embed([...])` for new/updated memories and `VectorIndex.upsert`,
  then sets `memories.embedding_status='embedded'`. A `NullEmbedder` sets `'skipped'`.
- A small idempotent **backfill** helper (`embed_pending(store, embedder, vector_index, limit)`) re-embeds `status='pending'`
  rows (used after a model change / a NullEmbedder→real upgrade) — runnable from the maintenance job or `genesis` CLI.

## 3. Files & tests
- **New:** `genesis/memory/embedder.py` (`Embedder`, `LocalEmbedder`, `NullEmbedder`), `genesis/memory/vector.py`
  (`VectorIndex` over sqlite-vec), pinned deps in `pyproject`. `tests/test_memory_vector.py`.
- **Tests (deterministic, no network/model download in CI):** use a **`FakeEmbedder`** (hash→fixed-dim vector) so tests never pull
  a model: `VectorIndex.upsert/search` round-trip returns nearest by cosine; a filtered search restricts to `memory_ids`;
  `NullEmbedder` path yields empty vectors + retrieval still works (asserted in 26-05); `embed_pending` backfills only `pending`
  rows. A separate, **network-gated** smoke test (skipped in CI) loads the real `LocalEmbedder` to sanity-check `dim` + latency.

## 4. Acceptance criteria
1. `Embedder` is a swappable protocol; `LocalEmbedder` runs CPU-only in a subprocess; `NullEmbedder` degrades cleanly.
2. `VectorIndex` (sqlite-vec) supports filtered cosine KNN behind a DB-agnostic interface; the pgvector swap is documented
   (ADR-054).
3. Embedding is never loaded in the web process; the vector table is created lazily against the model `dim`.
4. genesis pytest + ruff green with the fake embedder (no model download in CI).

## 5. Out of scope
- Calling the embedder from the workflow (26-03) / MCP (26-05); the actual model-choice finalization (build-time, §umbrella 13.1);
  the pgvector implementation (future, ADR-054).
