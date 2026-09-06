# 38-01 — Features + published stage artifacts sync

> **Status:** ✅ SHIPPED (genesis v0.65.0). · Part of Phase 38. Repo: **genesis**. · **Depends on:** Phase 37 (`CollaborationService` + `AppianHubProvider`), Phase 35 (`sync_uuid`/provenance/`upstream_versions`), `FeatureStore`/`StageStore`, Phase 36 (Feature/StageArtifact records + ArtifactBlob).

## Purpose

Make a **Feature** a shared object contributed to stage-by-stage: **publish a completed stage** (Spec / UX /
Technical Design / Breakdown) — the artifact bytes + metadata — while the **authoring chat + run stay local**;
**pull** materializes a read-only local mirror with the artifact on disk so a downstream stage can consume it.

## Build

1. **Publish (per completed stage)** — a `feature`/`feature_stage` mapping in `CollaborationService`:
   - Upsert the **Feature** record (kind `feature`) if not yet published (lazy — first completed stage triggers
     it); stamp `owner_username`/`team_uuid`/`published_by`.
   - Upsert the **StageArtifact metadata** record (kind `feature_stage`, keyed by the stage `sync_uuid`,
     referencing the feature `sync_uuid`): `stage`, `status`, `content_hash`, `blob_ref`, `published_by`,
     **`upstream_versions_json`** (the versions of the upstream artifacts this stage consumed — captured at
     stage-start snapshot time; the cross-stage staleness signal).
   - Upload the **artifact bytes** (`ArtifactBlob`, content-hash dedup) — the freshest HTML (`_current_stage_html`
     → sandbox copy else `html_path`).
   - Base-version CAS → `HubConflict` → notify-then-apply. **Never publish** `chat_session_id`/`run_id`/local
     `html_path` (FK-free local-only columns).
2. **Pull (read-only mirror)** — materialize/refresh the Feature + its published stages locally: upsert the
   mirror rows (map global `sync_uuid` → local row), **write the artifact bytes to the puller's disk** + set
   their local `html_path` + `content_hash`, leave `chat_session_id`/`run_id` null, record `published_version`.
   A pulled stage is **read-only** unless/until this user is the one advancing it (they can start the next stage
   against it).
3. **Publish trigger** — a "Publish to team" control on a **completed** stage (Phase 38-04 UI); also invocable at
   stage-finalize. Publishing a not-completed stage is disallowed (publish-on-complete).

## Tests

- Publish a completed spec → Feature + StageArtifact records + ArtifactBlob on the (fake) Hub; **no** chat/run
  leak. Pull on a second instance → the feature + spec appear; the artifact file is on disk; local-only columns
  null; a downstream stage can read it. `upstream_versions` captured. CAS conflict → notify. ruff clean.

## Deliverable

Feature + per-stage publish/pull mappings (artifact-only) + `upstream_versions` capture + tests.

## Gate

Independent review = SHIP: artifact-only (no chat/run leak); pull materializes a usable read-only mirror; CAS +
staleness capture correct; gates green.
