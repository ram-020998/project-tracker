# 35-01 — Data model, the sync seam & ADR-063

> **Status:** ✅ SHIPPED (genesis v0.63.0). · Part of Phase 35. Repo: **genesis** (planning). · **Depends on:** ADR-026 (amended here), ADR-030 (DB-agnostic repos), ADR-051/052 (the provider-interface precedent), ADR-050/25-08 (`LifecycleService` + m0013 `actor` + `row_version`), ADR-053 (memory scope), ADR-060/061 (the entities that will sync).

## Purpose

Lock the exact schema (migration **m0019**), the `SyncProvider` Protocol + `CollaborationService` contract, the
identity/team model + the canonical-username rule, and the provenance/version/advisory-lock model — so
35-02/35-03/35-04/35-05 build without re-deciding. Draft **ADR-063**. **No code.**

## Migration m0019 (`collab_identity_and_sync_ids`)

`genesis/db/migrations/m0019_collab.py` — `CREATE TABLE IF NOT EXISTS` + guarded `ADD COLUMN` (idempotent,
forward-only) + a one-time backfill; `current_version` 18 → **19**. Additive and harmless for solo installs.

**(a) Global identifiers — add + backfill `sync_uuid` on every synced entity** (a stable, client-generated UUID
alongside the local int PK; local↔global map on hydrate):

```sql
ALTER TABLE kb_features        ADD COLUMN sync_uuid TEXT;   -- + UNIQUE index; backfill uuid4() per row
ALTER TABLE kb_feature_stages  ADD COLUMN sync_uuid TEXT;
ALTER TABLE kb_epics           ADD COLUMN sync_uuid TEXT;
ALTER TABLE kb_stories         ADD COLUMN sync_uuid TEXT;
ALTER TABLE workbench_boards   ADD COLUMN sync_uuid TEXT;
ALTER TABLE kb_board_cards     ADD COLUMN sync_uuid TEXT;
-- backfill: UPDATE <t> SET sync_uuid = <uuid4> WHERE sync_uuid IS NULL;  then a UNIQUE index per table.
```

**(b) Concurrency — add `row_version` where missing** (the tables that lack the m0014 CAS column):

```sql
ALTER TABLE kb_features      ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE kb_epics         ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE kb_board_cards   ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE workbench_boards ADD COLUMN row_version INTEGER NOT NULL DEFAULT 0;
```

**(c) Provenance + forward-compat visibility tags** on the top-level synced entities:

```sql
-- kb_features, kb_stories, workbench_boards:
ADD COLUMN owner_username    TEXT;      -- creator/owner (canonical username); stamped, not enforced
ADD COLUMN team_uuid         TEXT;      -- forward-compat per-team visibility seam; stamped, not enforced
ADD COLUMN published_by      TEXT;      -- last publisher (canonical username)
ADD COLUMN published_at      TEXT;      -- ISO ts of the last publish
ADD COLUMN published_version INTEGER;   -- the Hub version this local row was last published/pulled at
```
Stage/artifact rows (`kb_feature_stages`, `kb_story_stages`) additionally record **consumed upstream versions**
for the cross-stage staleness badge (a small JSON column `upstream_versions_json` — e.g. `{"spec": 3}` recorded
at stage-start snapshot time). Locked shape below.

**(d) Local identity + team cache + sync state** (local-only tables; never leave the machine except teams/
membership which are *authored* to the Hub — these are the read cache):

```sql
CREATE TABLE collab_identity (            -- singleton (id=1)
  id               INTEGER PRIMARY KEY CHECK (id = 1),
  name             TEXT,
  appian_username  TEXT,                  -- the CANONICAL user id
  email            TEXT,
  active_team_uuid TEXT,
  created_at       TEXT, updated_at TEXT
);
CREATE TABLE collab_teams (               -- local read cache of Hub teams
  team_uuid  TEXT PRIMARY KEY, title TEXT NOT NULL,
  created_by TEXT, created_at TEXT, updated_at TEXT
);
CREATE TABLE collab_memberships (
  team_uuid TEXT NOT NULL, username TEXT NOT NULL,
  name TEXT, email TEXT, joined_at TEXT,
  PRIMARY KEY (team_uuid, username)
);
CREATE TABLE collab_sync_state (          -- per entity-kind pull cursor + markers
  kind         TEXT PRIMARY KEY,          -- 'kb' | 'feature' | 'feature_stage' | 'story' | 'epic' | 'board' | 'board_card' | 'team' | 'membership'
  last_cursor  TEXT,                      -- opaque manifest cursor from changes_since()
  last_pulled_at TEXT
);
```

- **No change** to chat/runs/documents/memory tables (local-only). No FK from a synced entity to a local-only
  thing is published (the `chat_session_id`/`run_id`/`html_path` columns stay null on a puller).

## `SyncProvider` Protocol (`genesis/collab/provider.py`)

Transport-neutral; mirrors `AgentProvider`/`DocumentProvider`. Provider-neutral DTOs (`Record`, `BlobRef`,
`Change`, `Activity`, `PutResult`) live beside it. Methods:

| Group | Method | Purpose |
|---|---|---|
| Records | `put_record(kind, sync_uuid, payload, *, base_version) -> PutResult` | upsert with **base-version CAS** → `HubConflict` (the notify-then-apply signal) |
| | `get_record(kind, sync_uuid) -> Record\|None` · `list_records(kind, *, since=None) -> list[Record]` | reads |
| Blobs | `put_blob(kind, key, data, *, content_hash, meta) -> BlobRef` | store a versioned blob (KB gzip / artifact bytes); **content-hash dedup** (no-op if identical to latest) |
| | `get_blob(ref) -> bytes` · `list_blob_versions(kind, key) -> list[BlobRef]` | reads |
| Manifest | `changes_since(cursor) -> (list[Change], next_cursor)` | the tiny "what's new" feed (kind, sync_uuid, version, updated_at, published_by) |
| Advisory | `set_activity(kind, sync_uuid, username, *, ttl)` · `clear_activity(...)` · `list_activity(kind) -> list[Activity]` | soft "in-progress by X" markers |
| Identity | `upsert_team(team)` · `list_teams()` · `upsert_membership(m)` · `list_memberships(team_uuid)` · `resolve_user(username)` | teams/membership |
| Health | `is_available() -> bool` | offline-first gating |

`build_sync_provider(settings) -> SyncProvider | None` — registry keyed by provider type (`local` this phase;
`appian` in Phase 37). Returns **`None` when no Hub is configured** (collaboration disabled — the opt-in gate).

## `CollaborationService` (`genesis/collab/service.py`)

Transport-agnostic orchestration over a `SyncProvider`:
- **Publish** `(kind, local_row)`: map the row → a record payload (stamp `sync_uuid`, `owner_username`,
  `team_uuid`, `published_by=current_user`, bump/carry `published_version`), `put_record(base_version=…)`;
  for artifact/KB entities also `put_blob(...)`. On `HubConflict` → surface "someone published a newer version —
  pull + reconcile" (never silently overwrite).
- **Pull** `(kind)`: `changes_since(cursor)` → for each change, `get_record`/`get_blob` → **upsert the local
  mirror** (map global `sync_uuid` → local row; leave local-only columns null) → advance the cursor in
  `collab_sync_state`. **Auto** for read-only shared views + boards; **notify-then-apply** where a local draft
  exists (compare `published_version`).
- **Advisory**: heartbeat `set_activity` while a workspace/edit is open; `clear_activity` on publish/close;
  `list_activity` feeds the "in-progress by X" badge.
- **Never** imports Appian — only the Protocol. The **`LocalHubProvider`** (35-04) is the first impl + test
  double.

## Identity & canonical username (for 35-03)

- The **Appian username** in `collab_identity` is the **single canonical user id** everywhere:
  `LifecycleEvent.actor`, `published_by`/`modified_by`/`owner_username`, and the personal-memory `owner`
  (`memory_owner_username` becomes a derived read of `current_user().username`, back-compat retained).
- `current_user()` reads the cached `collab_identity`; solo/unconfigured → falls back to today's behavior
  (`memory_owner_username` or `"local"`), so nothing breaks when collaboration is off.

## ADR-063 (draft — Proposed)

Write the ADR-063 block (Proposed) into `reference/decision-log.md` per §9 of the umbrella (decision + context +
alternatives considered [Appian-Hub vs dedicated-service vs git; blob-vs-records for the KB; self-asserted-vs-
verified identity; CRDT-vs-single-writer] + consequences), **amending ADR-026**. Mirror to `bible/04` on Accept.

## Open items for later sub-phases (recorded, not blocking)

1. The exact `upstream_versions_json` capture point (35-03/Phase 38) — recorded at stage-start snapshot time.
2. Whether `collab_sync_state` needs per-app granularity for the KB kind (Phase 37 decides — likely
   `kind='kb:<app_uuid>'`).

## Deliverable

This spec (locked m0019 schema / `SyncProvider` Protocol / `CollaborationService` model / identity model /
provenance-version-advisory model / opt-in gate) + **ADR-063 drafted (Proposed)**. No implementation.

## Gate

⭐ User sign-off on the schema + seam + identity model → proceed to 35-02.
