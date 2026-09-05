# 35-04 — The `SyncProvider` seam, `CollaborationService` & the local provider

> **Status:** 🟡 DRAFTED. · Part of Phase 35. Repo: **genesis** (backend). · **Depends on:** 35-01 (the Protocol + service contract), 35-02 (`sync_uuid` + `collab_sync_state`). ADR-051/052 (the provider-interface precedent).

## Purpose

Build the pluggable **`SyncProvider` seam**, the transport-agnostic **`CollaborationService`** (publish/pull +
version/provenance + change-manifest + advisory-lock), and a **file-backed local Hub provider** so the entire
mechanism is exercised end-to-end **without Appian** — the seam the Appian provider (Phase 37) drops into.

## Build

1. **`genesis/collab/provider.py`** — the `SyncProvider` Protocol + DTOs (`Record`, `BlobRef`, `Change`,
   `Activity`, `PutResult`, `HubConflict`) per 35-01. Pure interface, no I/O.
2. **`genesis/collab/providers/local.py::LocalHubProvider`** — a file-backed emulator under
   `settings.state_dir/"collab-hub"/` (records as JSON keyed by `kind/sync_uuid` with a version + timestamp +
   publisher; blobs as files keyed by `kind/key/<version>` with a content-hash sidecar → **dedup** no-ops an
   identical latest; a monotonic change log for `changes_since`; activity markers with TTL; teams/memberships
   as JSON). Implements every Protocol method. Doubles as the test provider.
3. **`genesis/collab/service.py::CollaborationService`** — over an injected `SyncProvider`:
   - `publish(kind, sync_uuid)`: read the local row → map to a payload (stamp identity/provenance) →
     `put_record(base_version=row.published_version)` (+ `put_blob` for artifact/KB kinds); on `HubConflict`
     raise a typed "stale — pull + reconcile" error; on success record the new `published_version`/`published_at`.
   - `pull(kind)`: `changes_since(collab_sync_state[kind].last_cursor)` → upsert local mirrors (map global
     `sync_uuid` → local row; **auto-apply** read-only shared kinds; **flag notify-then-apply** when a local
     draft's `published_version` differs) → advance the cursor.
   - `activity` helpers (heartbeat/clear/list); `is_enabled()` (opt-in gate — false when
     `build_sync_provider()` returns `None`).
4. **`build_sync_provider(settings)`** in `genesis/collab/__init__.py` — registry keyed by
   `settings.collab_provider` (`"local"` now; `None`/unset ⇒ disabled). Construct + expose the
   `CollaborationService` on `app.state` (registered in `api/app.py`), gated by the opt-in flag.
5. **Settings additions** (`runtime/settings.py`): `collab_enabled` / `collab_provider` / `collab_hub_*` config
   (env + persisted), all defaulting to disabled.

## Tests

- Round-trip: publish a record/blob to the `LocalHubProvider` → a **second `CollaborationService` instance**
  (separate local DB, same Hub dir) `pull`s it → the mirror row matches; local-only columns stay null.
- Content-hash **dedup**: re-publishing an identical blob is a no-op (no new version).
- **CAS/conflict**: two publishes off the same `base_version` → the second raises the stale-conflict error
  (notify-then-apply); no silent overwrite.
- Advisory markers set/expire/clear; `changes_since` cursor advances; `is_enabled()` false when unconfigured.
- ruff clean.

## Deliverable

`genesis/collab/{provider,service,__init__}.py` + `providers/local.py` + settings + `app.state` wiring + the
opt-in gate + end-to-end tests against the local provider.

## Gate

Independent review = SHIP: provider seam clean + Appian-free; publish/pull/CAS/dedup/advisory proven against the
local provider; disabled = no-op; gates green.
