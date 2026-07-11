# 05 — P2 (Decision): Persistence Scale — SQLite vs Postgres/pgvector

**Type:** Decision framework (not an implementation spec) · **Depends on:** `01` (repositories
must be DB-agnostic in signature first). **Status:** **Decision deferred** until a §2 trigger fires.

> This exists so the SQLite→Postgres question is answered by **explicit triggers and a documented
> migration path**, not by accident or vibe. Today's answer: **stay on SQLite.**

---

## 1. Current position (recap from `00`)
- Run lifecycle, the full agent conversation, and checkpoints live in **SQLite** (`genesis.db`,
  WAL; ADR-024 async saver). Bulk artifacts are files (ADR-010/018). Config is JSON files.
- For a **local, single-user** app this is the correct, zero-ops choice. The access pattern
  (single writer; append-only `run_events`; reads by `run_id`) is SQLite's sweet spot and scales to
  millions of rows without trouble. Moving to Postgres purely for volume adds ops burden for no
  single-user benefit.

**Default decision: remain on SQLite.** Re-open only on a trigger below.

---

## 2. Triggers that would justify Postgres (any one)
1. **Multi-user / hosted / concurrent writers.** SQLite's single-writer model is the wall. This is
   the primary trigger — and it **re-opens ADR-012/023/026** (auth/RBAC, vault secrets, hosted
   execution) as a whole track, not just a DB swap.
2. **Semantic search / RAG over transcripts & runs.** A likely near-term *feature* trigger: "find
   past runs where the agent did X", chat-with-your-history, or retrieval over conversation/artifacts.
   `pgvector` is the clean home for embeddings; SQLite vector options exist (e.g. `sqlite-vec`) but
   Postgres+pgvector is the more durable choice if this becomes central.
3. **Heavy cross-run analytics** (large JSONB querying, concurrent dashboards, reporting) beyond the
   bounded aggregates in `02`.

If **none** of these are on the near roadmap, do nothing.

---

## 3. What `01` already buys us
`01` makes repositories carry **DB-agnostic signatures** and centralizes connection policy. That is
the prerequisite for a low-cost move: the query bodies change, the callers do not. Keep it that way
(no SQLite-only types in repository return values).

---

## 4. Migration path (when a trigger fires)
1. **Adopt SQLAlchemy Core + Alembic** (the alternative deferred in `01 §7`): re-home the
   repositories onto Core (still no ORM needed), regenerate migrations under Alembic. This gives DB
   portability + autogenerate.
2. **Checkpointer:** switch LangGraph's `AsyncSqliteSaver` → the **Postgres checkpointer**
   (`langgraph-checkpoint-postgres`), which is a supported, drop-in async saver. `runtime/checkpoint.py`
   already isolates this behind one factory.
3. **Data migration:** a one-shot export/import (runs + run_events) SQLite→Postgres; the append-only
   shape makes this straightforward. Provide a `genesis db migrate-to-postgres` command.
4. **pgvector (if trigger 2):** add an `embeddings` table keyed by `(run_id, node, seq)` referencing
   `run_events`; index transcripts/artifacts; add a retrieval API. This is a **feature**, specced
   separately when prioritized.
5. **Config/secrets:** revisit the secret store (Keychain/vault) as part of the hosted track (trigger 1).

---

## 5. Effort & risk
- **SQLite→Postgres (single-user, no search):** ~2–4 days (Core/Alembic re-home + checkpointer swap
  + data migration + CI Postgres service). Low risk if `01`'s abstraction held.
- **+ pgvector search:** a separate feature initiative (embedding pipeline, indexing, retrieval UI).
- **Hosted/multi-user:** a large, separate program (auth, RBAC, secrets vault, execution isolation)
  — explicitly out of scope of the current product posture (ADR-026).

---

## 6. Recommendation
- **Now:** stay on SQLite; ship `01` so the seam exists.
- **Watch:** if transcript search/RAG (trigger 2) enters the roadmap, that is the most probable and
  lowest-drama reason to adopt Postgres+pgvector — write the ADR then.
- **Guard:** do not adopt Postgres "to be safe." It is only warranted by a real trigger; premature
  adoption imposes ops cost with no single-user return.
