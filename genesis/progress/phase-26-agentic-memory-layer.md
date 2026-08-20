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

## 26-03 — memory-consolidation workflow ✅ BUILT (unreleased)
- **Commits:** genesis `a416a21` (ctx.extras wiring) + genesis-workflows `8cb06e3` (the workflow). Local, no tag.
- **As built:**
  - **genesis** — `build_context` injects three memory extras (all cheap; deferred load): `memory_store`
    (MemoryStore over memory.db), **`chat_read`** (a NEW read-only `ChatReadAccessor` over genesis.db
    chat_sessions/messages — no write methods; the job is read-only against chat), and **`embedder_factory`**
    (a lazy `build_embedder(settings)` callable — a model loads only in the embed node, never at every build).
  - **genesis-workflows** — `workflows/memory-consolidation/` (graph.py + workflow.yaml) + registry entry.
    Graph: `resolve_window → load_sessions (redact secrets) → [extract → v_extract] → reconcile_prep →
    [reconcile → v_reconcile] → apply → advance_cursor → present`; an `escalate` gate on validation
    exhaustion; an **empty-day short-circuit** (resolve_window → advance_cursor when no sessions). Two Kiro
    turns only interpret (ADR-001; reliability trio ADR-011): **extract** emits atomic memories (scope
    personal/shared, type semantic/episodic/procedural, importance, shared-entity/relationship structure);
    **reconcile** classifies each candidate vs the top-k similar EXISTING memories (fetched keyword+entity in
    `reconcile_prep`) as **ADD/UPDATE/INVALIDATE/NOOP** (mem0 ops + Graphiti invalidation). **apply** is a raw
    async node (`to_thread`) writing memory.db (entities/relationships/memories, bi-temporal), then embeds via
    the lazy factory (NullEmbedder → `skipped`). Secrets redacted before the agent/memory.
- **Verified:** 9 workflow tests (stubbed Kiro + seeded chat + separate memory.db) — happy path
  (memories/entities/relationships + graph traversal), ADD / UPDATE-supersede / INVALIDATE, empty-day no-op +
  cursor advance, secret redaction, pure helpers/validators; `ci/validate_library.py` PASSED (8 workflows,
  reliability trio enforced, graph parity); full workflows suite **77→86**; genesis pytest 598 (build_context
  regression-checked), ruff clean.

## 26-05 — genesis-memory MCP + hybrid retrieval ✅ BUILT (unreleased)
- **Commit:** genesis `f95ac0b` (local, no tag). genesis-only (see the registry note below).
- **As built:**
  - **`genesis/memory/retrieval.py`** — a pure, framework-free hybrid fuse (generative-agents scoring):
    `score = w_rel·relevance + w_rec·recency + w_imp·importance`, `relevance = minmax(α·semantic +
    β·keyword + γ·entity/graph_proximity)`, **α=0 under a NullEmbedder**. `HybridRetriever` candidate-
    generates from the vector index (26-02) ∪ FTS5 (26-01) ∪ graph proximity (26-01), **always scope/owner
    pre-filtered** (vector search never global), then fuses + ranks. Keyword is a **binary presence** signal
    (the store surfaces no BM25 and its ordering already folds in recency/importance → rank-decay would
    double-count). DB-agnostic (consumes `Memory` + `VectorIndex`).
  - **`genesis/mcp/memory_server.py`** — a **separate** read-only stdio JSON-RPC MCP (modeled on
    `kb_server`, NOT merged with `genesis-kb`), launched `-m genesis.mcp.memory_server --db <memory.db>
    [--owner <u>]`. Tools (all read-only): `search_memory`, `get_personal_memory`, `get_entity`,
    `get_entity_memories`, `get_related_entities` (graph traversal), `get_relationships`. Reads via a
    `mode=ro` connection; the embedder is built **in this subprocess** via `build_embedder` (NullEmbedder →
    keyword+graph). **Owner scoping:** personal reads restricted to `--owner`; `search_memory` defaults to
    `shared` so one user's personal memory is never volunteered. **Strictly read-only** — no write tools; the
    `mark_used` recency bump is deliberately not done here (nightly job owns recency).
  - **Injection (MCP-only, §11.5):** `chat/mcp.py` wires `genesis-memory` into every chat session (read_only
    / copilot / feature_spec) alongside `genesis-kb`, auto-trusted; `chat/mode_profile.py` adds a memory
    steering hint to all three preambles (recall personal prefs + shared app knowledge before re-asking the
    user; no auto-prefetch). Owner via `getattr(settings,'memory_owner_username','local')` — forward-compat
    with the 26-06 setting.
- **Scope note (deviation from 26-05 §5):** `genesis-memory` is **NOT** added to genesis-workflows
  `mcp-registry.json`. That registry does not `${}`-resolve a server's `command`, so it can't express the
  venv python an internal module server needs — exactly why `genesis-kb` (the internal-server precedent) is
  chat-wired, not in the registry. Injecting internal servers into **agentic workflow nodes** needs an
  internal-server node-injection mechanism in genesis-core (mirroring `_kb_entry` for nodes) — a deliberate
  follow-up (filed against 26-06/26-07 wiring). The primary agent surface (chat) is fully delivered.
- **Verified:** `tests/test_memory_retrieval.py` (pure units + `HybridRetriever` over a temp memory.db +
  FakeEmbedder + BruteForceVectorIndex: keyword/semantic rank, scope/owner isolation, entity-proximity
  boost, NullEmbedder degradation) + `tests/test_memory_server.py` (tool-contract shapes, owner-scoped
  personal reads, shared default doesn't leak personal, graph traversal, read-only guard, tools/list). genesis
  pytest **598→616**, ruff clean; a **subprocess smoke** (initialize/tools/list/search/personal) passes.

## 26-08 — Memory Management UI + curation API ✅ BUILT (unreleased)
- **Commits:** genesis `5c6cc0d` (08a backend) + `07bc946` (08b web). Local, no tag. genesis-only.
- **08a — browser-only curation API** (`genesis/api/memory.py`, all under `/api`; the agent MCP stays
  read-only): reads `GET /memory` (filter/paginate), `/memory/{id}` (+ bi-temporal history), `/memory/graph`
  (nodes+edges; `?entity_ref+depth` local graph; `?at` point-in-time; `?include_invalidated`),
  `/memory/entities[/{id}]`, `/memory/relationships`, `/memory/review`; writes: manual add (origin='user',
  pending embed), PATCH = supersede (history kept; re-scope guarded by `confirm_scope_change`),
  pin/protect/verify(+un), invalidate/archive/unarchive, DELETE `?hard=true` (gated purge), review
  approve/discard, bulk, relationship POST/PATCH/DELETE, entity PATCH. New `MemoryStore` methods
  (list_memories, memory_history, delete_memory, get/list/update/delete_relationship, update_entity,
  unarchive) + `vector.purge_vectors`. Human edits set `origin='user'` → already exempt from
  `forget_before` maintenance.
- **08b — the web workspace** (`web/src/features/memory/**`, route `/memory` + a Sidebar entry): a
  SplitPane `main | inspector` with a **Graph ⇄ List ⇄ Review** switch + shared selection/scope state.
  **MemoryGraph** = an Obsidian-style `@xyflow/react` explorer (node size by degree, colour by kind,
  invalidated edges dashed; hover→neighbour-highlight+dim, click→inspector, node search, MiniMap; toolbar:
  find-node, `as of` time-scrub, show-invalidated) over a **pure, unit-tested `graph.ts`** radial fold.
  **MemoryList** (FTS search + scope/type filters + bulk pin/verify/archive), **MemoryInspector** (edit
  every attribute = supersede; pin/protect/verify; invalidate/forget/hard-delete; provenance + version
  history), **ReviewQueue** (approve/edit/discard). No new dependency (reused `@xyflow/react`; a canvas
  force lib is a deferred ADR-027 swap; community colouring deferred to 26-04 → colour-by-kind for now).
- **Verified:** genesis pytest **616→625** (`tests/test_memory_api.py`: add/list/detail+history,
  edit-supersede, re-scope guard, flags, soft-forget vs hard-purge, invalidate, relationship+entity CRUD +
  graph payload, review, and the maintenance guardrail), ruff clean; web **tsc + eslint + vitest 181→189**
  green (`graph.test.ts` pure units + `memory.test.tsx` RTL + **jest-axe** clean), `web/static` rebuilt +
  committed.
- **Deferred within 26-08 (noted follow-up):** the two contextual reuses — Application-detail "Memory" tab
  + Settings "Your Memory" panel — reuse these components (thin wiring).

## 26-04 — memory-maintenance "dreaming" workflow ✅ BUILT (unreleased)
- **Commits:** genesis `d080335` (store helpers) + genesis-workflows `93e3c4f` (the workflow). Local, no tag.
- **As built:** a deterministic LangGraph workflow (`workflows/memory-maintenance/`) modelled on 26-03 —
  `load_candidates → [reflect → v_reflect] → [curate → v_curate] → apply → recompute_communities →
  decay_forget → embed_new → present` (per-agent escalation gates; reliability trio on both agents; memory.db
  writes via `to_thread`; reused `ctx.extras`). **reflect** synthesizes higher-level memories from entity
  clusters citing real source ids (`record_reflection` + `add_memory_link('elaborates')`); **curate** MERGEs
  near-duplicates / INVALIDATEs contradicted members bi-temporally (reversible); **recompute_communities**
  = connected components over shared relationships (idempotent via `clear_communities`); **decay_forget** =
  `forget_before` soft-archive; **embed_new** embeds the reflections.
- **Safety:** `load_candidates` builds the auto-eligible set EXCLUDING pinned/protected/user_verified/
  origin∈{user,reflection}, and `apply` only touches ids in that set — **never overrides human curation**
  (26-08 guardrail), never crosses scope/owner, nothing hard-deleted. Idempotent + bounded → a re-run
  converges (reflected clusters are skipped via `memory_link_targets`; merged dups are closed).
- **genesis store helpers added:** `clear_communities(scope?, owner?)` (idempotent recompute) +
  `memory_link_targets(link_type?)` (reflection convergence guard).
- **Verified:** genesis pytest `test_memory_store.py` 13→15, ruff clean; genesis-workflows
  `ci/validate_library.py` PASSED (9 workflows, reliability trio enforced), workflows suite **86→93**
  (reflection+convergence, curate-merge reversible, decay-skips-protected, communities-idempotent, pure
  units). Unreleased.

## 26-06 — scheduler integration + config + status ✅ BUILT (unreleased)
- **Commit:** genesis `f5d34be` (local, no tag). genesis-only.
- **As built:**
  - **`runtime/memory_jobs.py`** — `DEFAULT_MEMORY_JOBS` (seeded via `ScheduleStore.ensure_defaults`) +
    `register_memory_jobs`: **memory-consolidation** nightly **02:00 IST**, **memory-maintenance** weekly
    **Sun 03:00 IST**. Handlers `RunManager.start(<id>, {owner})` → poll to terminal → `(status, detail)`.
    **Preflight skips** (logged, never 500): Kiro not signed in, workflow not installed, or (consolidation)
    no new chat sessions since the cursor. Wired in `api/app.py`.
  - **`runtime/scheduler.py`** — `due_slot` gains an optional `days` filter (`[int]` Mon=0..Sun=6) for
    weekly jobs (backward-compatible); `api/schedules.py` `_next_due` honours it.
  - **`runtime/settings.py`** — `memory_owner_username` (env `GENESIS_MEMORY_OWNER`; "" → "local"), threaded
    to the workflow `owner` input, the `genesis-memory` MCP `--owner`, and `api/memory.py` `edited_by` (all
    already read `getattr`).
  - **`GET /api/system/memory`** — `{owner, memory_db_version, counts (MemoryStore.stats), last_consolidation_at,
    last_maintenance_at}`.
- **Design note (build-time):** `memory_owner_username` defaults to **"local"** (env-overridable) rather than
  auto-detecting the OS user — deterministic + matches the existing single-user default; OS-user auto-detect
  is a trivial follow-up. Both jobs ship **enabled** (local + reversible). The 26-05 internal-server
  node-injection follow-up is **deferred to 26-07/backlog** (chat injection already works; it's not on the
  release critical path).
- **Verified:** genesis pytest **625→635** (`tests/test_memory_jobs.py`: weekly Sunday due-slot + no-refire,
  maintenance skips no-Kiro/not-installed, happy path threads owner, `GENESIS_MEMORY_OWNER` threaded,
  consolidation skips no-new-sessions, `GET /system/memory` shape; `test_sync_jobs` expectation +2 jobs),
  ruff clean, full suite green.

## Next
- **26-07** — RELEASE + acceptance (the last sub-phase): bump/tag **genesis + genesis-workflows** (this is
  the FIRST push to master for Phase 26 — needs the human's go-ahead), verify `genesis db upgrade` covers
  both DBs, run the acceptance checklist across 26-01..26-08, flip **ADR-053 + ADR-054 → Accepted**, and
  finalize bible/tracker/progress.
