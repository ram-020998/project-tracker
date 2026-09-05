# 35-02 — Global identifiers & concurrency migration (m0019)

> **Status:** ✅ SHIPPED (genesis v0.63.0). · Part of Phase 35. Repo: **genesis** (backend + migration). · **Depends on:** 35-01 (locked m0019 schema).

## Purpose

Ship migration **m0019** (`sync_uuid` + backfill; `row_version` where missing; owner/team/provenance columns;
the `collab_*` local tables) and the minimal store changes to **generate + expose `sync_uuid`** on create/read
— the groundwork every synced entity needs before publish/pull. `current_version` 18 → **19**.

## Build

1. **`genesis/db/migrations/m0019_collab.py`** per 35-01's DDL: guarded `ADD COLUMN` for `sync_uuid` on the six
   synced tables + a **backfill** (`UPDATE … SET sync_uuid = <uuid4> WHERE sync_uuid IS NULL`) + a `UNIQUE`
   index per table; `row_version` on the four tables lacking it; owner/team/provenance columns on the top-level
   synced entities + `upstream_versions_json` on the two stage tables; the `collab_identity`/`collab_teams`/
   `collab_memberships`/`collab_sync_state` local tables. Register in `migrations/__init__.py`. Idempotent
   (`_has_column` guards + `IF NOT EXISTS`).
2. **Store create-paths generate a `sync_uuid`** (uuid4) at insert: `FeatureStore.create_feature`,
   `StageStore.get_or_create`, `StoryStore.finalize`/`create_story` + epics, `BoardStore.add_board`/
   `import_stories` (cards). **Reads expose `sync_uuid`** (already `SELECT *` in most; confirm each DTO carries
   it).
3. **No behavior change** otherwise — the columns are inert until Phases 37/38 use them. `owner_username` is
   stamped from `current_user()` when available (35-03 lands `current_user()`; until then null-safe).

## Tests

- A migration test: a fresh DB upgrades to **v19**; a **populated** fixture DB (features/stories/boards rows)
  backfills a unique `sync_uuid` on every row; re-running m0019 is idempotent (no dup columns, no re-backfill).
- Store tests: new entities get a `sync_uuid`; `row_version` present + defaults 0 on the four tables.
- **Bump every hardcoded `current_version == 18` assertion → 19** (test_db count, the migration-list row, the
  synthetic-next 19→20, the per-store `current_version` assertions — the §7 lesson). ruff clean.

## Deliverable

m0019 + the store `sync_uuid` generation/exposure + tests; `current_version` 19; all `==18` tests bumped.

## Gate

Independent review = SHIP: migration additive + backfill correct + idempotent; a populated DB upgrades cleanly;
solo behavior unchanged; gates green.
