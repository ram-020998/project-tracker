# 36-03 — Document management & blob store (Appian)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side). · **Depends on:** 36-01 (the blob contract), 36-02 (the StageArtifact/Feature/Story records the blobs attach to).

## Purpose

Build the **versioned blob store** for the two large payloads — the gzipped **KB blob** (one per app) and the
published **stage-artifact HTML** (spec/UX/TD/breakdown/design) — using Appian **document-management record
types**, with **version history**, **content-hash dedup**, and **keep-last-N** retention.

## Build (Dev-MCP agent)

1. **KbBlob** document-management record type: keyed by `app_uuid`; each upload = a **new document version**
   carrying `content_hash`, `size`, `created_by`, `created_at`, and the gzip payload (~1–2 MB for a large app —
   well within document limits; confirm on the target Appian version per 36-01). Content-hash **dedup**: an
   upload whose hash equals the latest version is a **no-op** (returns the existing version).
2. **ArtifactBlob** document-management record type: keyed by `(parent_sync_uuid, stage)`; versioned HTML
   payload + `content_hash` + provenance. Linked from the StageArtifact metadata record's `blob_ref`.
3. **Retention:** keep the last **N** versions per key (record-type-managed cleanup or a scheduled job — decide
   in 36-01/here); older versions pruned. History (created_by/at) preserved for the kept versions.
4. **Download** returns the latest (or a specified) version's bytes; **list-versions** returns the version
   history metadata.

## Validation

Upload → new version; identical re-upload → dedup no-op; download returns the bytes; list-versions returns
history; retention prunes beyond N. Verified by the contract harness (36-06) using the 36-01 blob fixtures.

## Gate

Contract-conformant blob store → 36-04.
