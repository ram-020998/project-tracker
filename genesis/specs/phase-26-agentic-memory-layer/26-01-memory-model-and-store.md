# 26-01 — Memory model, store & migration (`memory.db`, `mm0001`, `MemoryStore` + `GraphStore`)

> **Status:** 📋 DRAFT · **Repo:** genesis · **Depends on:** nothing · **Unblocks:** 26-02 (vectors), 26-03 (consolidation writes), 26-05 (retrieval reads) · **Proposed ADR:** ADR-053 + ADR-054
> **Goal:** Create a **new, separate `~/.genesis/memory.db`** with a **bi-temporal entity-relationship memory model** and a
> `MemoryStore` + `GraphStore` repository with **DB-agnostic signatures**, so a future Postgres+pgvector(+AGE) swap is a re-home
> behind the interface (ADR-054). After 26-01 the memory layer is a fully-tested persistence layer independent of any LLM,
> embedder, or environment.

## 1. Current state (grounded)
- `db/database.py` — `Database(path)` (WAL, busy_timeout, foreign_keys, `row_factory=sqlite3.Row`, `tx()`); generic — takes any
  path. `db/runner.py` — `Migration(version,name,up)` + `migrate(db, MIGRATIONS)` applies pending in-tx + records
  `schema_migrations`; contiguity guard; `current_version`. **The runner is DB-instance-scoped** — pointing it at a *second*
  `Database` with a *second* migration list gives `memory.db` its own independent `schema_migrations` + `current_version`.
- `kb/store.py` — the precedent: a `Database`-backed repository over a **bi-temporal (SCD-2)** model with recursive-CTE
  traversal (dependency-path / transitive-deps BFS), dataclass records with `_from_row` (forward-compat via `r.keys()`),
  writes in `tx()`, reads via `connect()`/try-finally, JSON columns, **DB-agnostic signatures (ADR-030)**, and
  `untrack_application` table-scoped deletes. `memory.db` mirrors this shape.
- `runtime/settings.py` — `Settings` holds `state_dir=~/.genesis`, `db_path`, etc. Add `memory_db_path=state_dir/"memory.db"`.

## 2. Design

### 2.1 A second database + migration set
- `genesis/memory/db.py` — `memory_database(settings) -> Database` (`Database(settings.memory_db_path)`).
- `genesis/memory/migrations/` — `mm0001_memory.py` (+ `__init__.py` building `MEMORY_MIGRATIONS`), same file shape as
  `db/migrations/` (docstring, `def _up(conn)`, module-level `Migration(version=1, name="memory", up=_up)`).
- `migrate(memory_db, MEMORY_MIGRATIONS)` is called at boot (in `create_app`, next to the genesis.db `migrate`) and by
  `genesis db upgrade` (upgrade **both** DBs). `memory.db` has its **own** `schema_migrations`/`current_version` (starts at 1) —
  **`genesis.db` is untouched**, so no genesis.db `current_version==N` test changes.

### 2.2 `mm0001` schema (all `CREATE TABLE IF NOT EXISTS`, additive, FK `ON DELETE CASCADE` where child rows belong to a parent)

```
memory_entities
  id            INTEGER PRIMARY KEY
  entity_kind   TEXT NOT NULL              -- 'application'|'feature'|'record_type'|'user'|'concept'|...
  entity_ref    TEXT NOT NULL              -- canonical id: app_uuid | feature_id | username | slug
  name          TEXT NOT NULL
  scope         TEXT NOT NULL              -- 'personal'|'shared'
  owner         TEXT                        -- username for personal; NULL for shared
  attributes_json TEXT                      -- freeform typed attributes
  created_at    TEXT NOT NULL
  updated_at    TEXT NOT NULL
  UNIQUE(entity_kind, entity_ref, scope, owner)

memory_relationships                        -- the traversable graph edges (bi-temporal)
  id            INTEGER PRIMARY KEY
  source_entity_id INTEGER NOT NULL REFERENCES memory_entities(id) ON DELETE CASCADE
  target_entity_id INTEGER NOT NULL REFERENCES memory_entities(id) ON DELETE CASCADE
  rel_type      TEXT NOT NULL              -- 'depends_on'|'part_of'|'decided_for'|'relates_to'|...
  fact          TEXT                        -- natural-language statement of the relationship
  scope         TEXT NOT NULL
  owner         TEXT
  confidence    REAL                        -- 0..1
  source_memory_id INTEGER REFERENCES memories(id) ON DELETE SET NULL
  valid_from    TEXT NOT NULL              -- valid-time start (bi-temporal)
  valid_to      TEXT                        -- NULL = currently true; set = invalidated
  invalidated_by_memory_id INTEGER
  created_at    TEXT NOT NULL              -- transaction-time
  INDEX(source_entity_id), INDEX(target_entity_id), INDEX(rel_type), INDEX(valid_to)

memories                                    -- the atomic memories (facts/notes)
  id            INTEGER PRIMARY KEY
  memory_type   TEXT NOT NULL              -- 'semantic'|'episodic'|'procedural'
  scope         TEXT NOT NULL              -- 'personal'|'shared'
  owner         TEXT                        -- username for personal; NULL for shared
  text          TEXT NOT NULL              -- the atomic memory statement
  summary       TEXT
  importance    REAL NOT NULL DEFAULT 0.5  -- LLM-rated 0..1 (Generative-Agents importance)
  tags_json     TEXT
  entities_json TEXT                        -- linked memory_entities.id[] (denormalized for fast filter)
  source_session_id TEXT                     -- provenance (chat_sessions.id)
  source_message_ids_json TEXT
  origin        TEXT NOT NULL DEFAULT 'consolidation'  -- 'consolidation'|'reflection'
  valid_from    TEXT NOT NULL
  valid_to      TEXT                        -- NULL = current; set = invalidated/superseded
  superseded_by INTEGER REFERENCES memories(id) ON DELETE SET NULL
  archived      INTEGER NOT NULL DEFAULT 0  -- decay/forget (soft)
  access_count  INTEGER NOT NULL DEFAULT 0
  last_used_at  TEXT
  embedding_status TEXT NOT NULL DEFAULT 'pending'  -- 'pending'|'embedded'|'skipped'
  created_at    TEXT NOT NULL
  updated_at    TEXT NOT NULL
  INDEX(scope, owner), INDEX(memory_type), INDEX(valid_to), INDEX(archived), INDEX(embedding_status)

memory_entity_links                         -- memories ⋈ entities (many-to-many, for join queries)
  memory_id     INTEGER NOT NULL REFERENCES memories(id) ON DELETE CASCADE
  entity_id     INTEGER NOT NULL REFERENCES memory_entities(id) ON DELETE CASCADE
  PRIMARY KEY(memory_id, entity_id)

memory_links                                -- A-MEM zettelkasten note↔note links
  from_memory_id INTEGER NOT NULL REFERENCES memories(id) ON DELETE CASCADE
  to_memory_id   INTEGER NOT NULL REFERENCES memories(id) ON DELETE CASCADE
  link_type     TEXT NOT NULL              -- 'refines'|'contradicts'|'elaborates'|'related'
  reason        TEXT
  created_at    TEXT NOT NULL
  PRIMARY KEY(from_memory_id, to_memory_id, link_type)

memory_communities                          -- Graphiti-style clusters (maintenance-computed)
  id            INTEGER PRIMARY KEY
  label         TEXT NOT NULL
  summary       TEXT
  scope         TEXT NOT NULL
  owner         TEXT
  member_entities_json TEXT
  created_at    TEXT NOT NULL
  updated_at    TEXT NOT NULL

memory_consolidation_state                  -- restart-safe cursor for the nightly job
  id            INTEGER PRIMARY KEY CHECK (id = 1)   -- singleton row
  last_processed_session_created_at TEXT
  last_processed_session_id TEXT
  last_run_at   TEXT
  last_maintenance_at TEXT

memories_fts  = FTS5(text, summary, content='memories', content_rowid='id')   -- keyword/BM25 retrieval
  -- triggers keep memories_fts in sync on insert/update/delete
```

- **Iteration-1 scope:** bi-temporal columns exist and are honored (writes set `valid_to=NULL`; invalidation/supersede close
  them); communities/links are populated by the maintenance job (26-04). The **vector index is a separate `sqlite-vec` virtual
  table added in 26-02** (kept out of `mm0001` so the schema is embedder-agnostic — a `NullEmbedder` deployment needs no vec
  table).
- **DB-agnostic:** no SQLite-only types in signatures; `sqlite-vec`/FTS5 specifics stay inside the SQLite implementation so the
  Postgres+pgvector(+AGE) adapter is a drop-in (ADR-054).

### 2.3 `genesis/memory/store.py` — `MemoryStore` + `GraphStore`
Constructed with a `Database` (mirrors `KbStore`/`ChatStore`); dataclass records with `_from_row`; writes in `tx()`; reads via
`connect()`. **DB-agnostic signatures (ADR-030).** Split responsibilities (behaviour-preserving mixins, per the 25-06 pattern):

**Write / apply (used by the workflows, 26-03/26-04):**
- `add_memory(memory) -> memory_id` — insert a current memory (`valid_from=now`, `valid_to=NULL`, `embedding_status='pending'`).
- `update_memory(old_id, new_memory) -> new_id` — supersede: close the old (`valid_to=now`, `superseded_by=new_id`), insert new.
- `invalidate_memory(memory_id, *, by_memory_id=None)` — bi-temporal close (contradiction).
- `archive_memory(memory_id)` — soft decay/forget.
- `upsert_entity(entity) -> entity_id` / `add_relationship(edge) -> id` / `invalidate_relationship(id, *, by_memory_id=None)`.
- `link_memory_entities(memory_id, entity_ids)` / `add_memory_link(...)` (A-MEM).
- `record_reflection(memory)` (origin='reflection'); `upsert_community(...)`.
- All writes are **executed by program nodes via `asyncio.to_thread`** in the async worker (§7 async-write lesson).

**Read (used by retrieval 26-05 + status 26-06):**
- `get_memory(id)` / `search_memories(*, scope=None, owner=None, entity_ids=None, types=None, query=None, top_k, current=True)`
  — keyword (FTS5) + filters; the **hybrid semantic fuse is layered in 26-05** (this returns candidates + scores the
  keyword/recency/importance part).
- `get_entity(entity_kind, entity_ref, *, scope, owner=None)` / `list_entities(...)` / `get_entity_memories(entity_id)`.
- `mark_used(memory_ids)` — bump `access_count` + `last_used_at` (called by the MCP on return; recency signal).

**`GraphStore` (traversal — recursive CTE, like `KbStore`'s BFS):**
- `related_entities(entity_id, *, rel_type=None, depth=1, current=True) -> [(entity, path)]` — `WITH RECURSIVE` over
  `memory_relationships` bounded by `depth`, honoring `valid_to IS NULL` (current) / a point-in-time predicate.
- `relationships_of(entity_id, *, current=True)` / `neighbors(entity_id)`.

**Lifecycle:** `owner_memories(owner)` (personal export), `forget_before(cutoff, *, max_importance)` (decay helper),
`consolidation_cursor()` / `advance_cursor(...)` over `memory_consolidation_state`.

### 2.4 Point-in-time predicate (reused everywhere)
Current reads apply `valid_to IS NULL AND archived = 0`; a future point-in-time read applies
`valid_from <= :t AND (valid_to IS NULL OR valid_to > :t)` — the same discipline as `KbStore`, kept private so callers stay
time-agnostic.

## 3. Files & tests
- **New:** `genesis/memory/__init__.py`, `genesis/memory/db.py`, `genesis/memory/migrations/{__init__,mm0001_memory}.py`,
  `genesis/memory/store.py`, `genesis/memory/models.py`; `settings.memory_db_path`; `create_app` + `genesis db upgrade` wire the
  second `migrate`. `tests/test_memory_store.py`.
- **Tests (no LLM/embedder/network):** `mm0001` applies on a fresh memory.db; `current_version==1`; idempotent re-run; genesis.db
  untouched. `add`/`update`(supersede)/`invalidate`/`archive` produce the right bi-temporal transitions. Entity upsert dedups on
  `UNIQUE`. `GraphStore.related_entities(depth=2)` traverses and respects `valid_to`. Scope/owner isolation: a `personal` query
  for user A never returns user B's or `shared` rows unless asked. FTS5 keyword search returns expected rows. `forget_before`
  archives only matching rows. A guard test: no store method returns a raw transcript (memories are derived text only).

## 4. Acceptance criteria
1. `memory.db` exists as a **separate** DB with its own migrations; boot + `genesis db upgrade` apply `mm0001`; genesis.db's
   `current_version` and its tests are unchanged.
2. `MemoryStore`/`GraphStore` implement the bi-temporal model + recursive traversal + scope/owner isolation, verified by tests.
3. Signatures are DB-agnostic (no SQLite/sqlite-vec/FTS types leak into the interface) — the Postgres seam stays cheap (ADR-054).
4. Full genesis pytest + ruff green.

## 5. Out of scope
- The `sqlite-vec` vector table + embedding writes (26-02); the workflows that call the store (26-03/26-04); the MCP that reads
  it (26-05); the scheduler/config (26-06).
