# 45-04 — KB: m0023, incremental merge, snapshot export

> **Status:** 🟡 DRAFTED. Repo: **genesis**. Implements the KB half of **ADR-074**.
> Parent: `specs/phase-45-incremental-delta-sync.md`.

## 1. Migration m0023 (`current_version` 22 → 23)

Additive + idempotent (guarded `ADD COLUMN`):

| Table | Column | Purpose |
|---|---|---|
| `scheduled_jobs` | `options_json TEXT` | job options (45-07) |
| `scheduled_jobs` | `user_modified INTEGER NOT NULL DEFAULT 0` | protects user edits from `ensure_defaults` |
| `kb_syncs` | `details_json TEXT` | `{changed_count, fallback_reason, skipped_objects[], export_warnings[], package_name, covered_until, published_version}` |

Data step: rewrite the `application-sync` row to the new defaults (enabled, `interval_window` every 4 h
08:00–20:00, weekdays, Asia/Kolkata; options `full_every_days=7, max_changed=500, max_changed_pct=25`) only where
`user_modified = 0` (umbrella Q2). Bump every `current_version == 22` test assertion to 23 (+ the synthetic
next-migration test to 24).

`kb_syncs.kind` values going forward: `baseline`, `full`, `incremental`, `hub-pull`. Legacy `delta` rows are read as
`full` (they were full re-exports).

## 2. `KbStore.known_context(app_uuid) -> (list[KnownObject], list[KnownEdge])`

Reads current objects (uuid, name, type, metadata_json, description) + current edges for the parser (45-03).
Read-only; ~2.8k objects / ~18k edges for AS GSS.

## 3. `KbStore.apply(sync_id, result, mode="incremental")`

One transaction. Never closes an object that isn't in the result.

1. **Objects** (package objects only): new → open; `diff_hash` changed → close + open (SCD-2); unchanged → no-op.
   **No removals** (ADR-074 / D4).
2. **Edges:** for each source in `result.objects`, close its current outgoing edges not in `result.edges`, open
   edges not yet current. Edges whose source is outside the package are untouched.
3. **Bundles:** replace the current bundle set with `result.bundles` (whole-app, from the KB-aware parse). If
   `stats.incremental.roots_missing` is non-empty, keep the existing bundles for those roots.
4. **Derived fields:** apply `stats.derived` to **current rows in place**: `metadata_json` keys
   `inbound_count/outbound_count/is_hub/is_bundled` + the `is_orphan` column. In place (not SCD-2) so unchanged
   objects don't get a new version every delta (umbrella Q3).
5. Mark the business map stale only if any object or edge changed.
6. Counts: `{objects_added, objects_modified, objects_removed: 0, edges_added, edges_removed}`.

Existing modes: `baseline` unchanged; `delta` keeps its full-re-export semantics and is renamed **`full`**
(`delta` remains an accepted alias).

## 4. `KbStore.finish_sync(..., details=None)` + `last_successful_sync(app_uuid, kinds=None)`

`finish_sync` writes `details_json`. `last_successful_sync` returns the newest `succeeded` row (optionally filtered by
kinds) — used for the look-back (`covered_until`, falling back to `started_at`) and the "last full sync" age
(`kinds=("baseline","full","delta")`).

## 5. `KbStore.export_snapshot(app_uuid) -> dict`

Builds the **same shape** as a full `KbParseResult` serialization (`kb/blob.serialize_result` input):
`{application, objects, edges, bundles(+members), orphans, errors: [], stats}` from current KB rows. Rules:
- Deterministic: objects sorted by uuid, edges by (source, target, type), bundles by bundle_id, members by uuid; stable
  JSON key order → the gzip content hash is stable, so unchanged KBs dedupe on the Hub.
- Code-free by construction (the KB never stores code, ADR-037).
- `kb/blob.serialize_result` accepts this dict directly.
- **Round-trip test:** `hydrate_from_blob(serialize(export_snapshot()))` into an empty DB reproduces the same current
  objects / edges / bundles.

## 6. Tests

- `apply(mode='incremental')`: add, modify, unchanged; edge replacement only for package sources; no removals;
  bundles replaced; derived fields updated in place without new versions; business map stale only on change.
- **Regression for the catastrophic case:** a 40-object result into a 2.7k KB leaves every other object and edge
  current (the 45-01 simulation as a test).
- `export_snapshot` determinism (two calls → identical bytes) + round-trip.
- m0023 idempotency + head-version assertions.
