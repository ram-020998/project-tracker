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

## 7. As built (2026-10-13, genesis `d93420e`, local) — deviations from §1–§5

- **m0023 is schema-only** (`kb_syncs.details_json`, `scheduled_jobs.options_json`, `scheduled_jobs.user_modified`).
  The `application-sync` default adoption (enabled, every 4 h 08:00–20:00 IST weekdays) moves to
  `ScheduleStore.ensure_defaults` in **45-07**: adopt the new default once for rows whose `options_json` IS NULL
  and `user_modified = 0`. Reason: a migration data step would be overwritten by today's `ensure_defaults` on the
  next boot (it rewrites `schedule_json` every boot) and would enable a schedule kind (`interval_window`) the
  current scheduler doesn't understand if a DB reached v23 before 45-07's code.
- **Guards (defense in depth for the 45-01 finding):** `apply(mode='full'|'delta'|'baseline')` refuses a result
  that carries `stats.incremental`; `apply(mode='incremental')` refuses a result without it.
- **Full mode refreshes unchanged objects in place** (`metadata_json`, `is_entry_point`, `entry_point_kind`,
  `is_orphan`) — required by 45-03 §6 (new stub metadata, and derived counts drift as the rest of the app changes).
  `mode='delta'` is an alias of `'full'`.
- **Bundles:** replaced wholesale; if `skipped_entry_points`/`incomplete_flow_bundles` is non-empty the existing
  bundles that weren't rebuilt are kept (`_recompute_bundles(keep_unrebuilt=True)`).
- **`export_snapshot` order:** objects in **KB row order** (not uuid-sorted) — deterministic for a given KB and it
  preserves the parse order a teammate's `hydrate_from_blob` reproduces (name-collision order matters to the
  parser); edges sorted by (source, target, type); bundles by `bundle_id`; members by uuid; no timestamps.
- Also: `update_sync_details(sync_id, details)` (shallow merge — for `published_version`, 45-08); `list_syncs`
  rows gain `details`; `KbStore.FULL_KINDS = ("baseline", "full", "delta")`.

**Evidence:** `tests/test_kb_incremental.py` (10) incl. the real-parser regression (vendored export: baseline →
40 changed + `delta_roots` → incremental merge → identical objects/edges/bundles, zero new versions). On a sqlite
backup copy of the live KB (never the live DB): full refresh of AS GSS with parser 0.3.0 → 2,929 / 19,009 / 230;
then an incremental merge of a 262-object delta package → **2,929 / 19,009 / 230** (parse 4.6 s, apply 0.5 s).
genesis pytest 879, ruff clean; fresh DB → v23.
