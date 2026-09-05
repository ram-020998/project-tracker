# 36-03 — Documents & blob store (Appian build)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side). · **Depends on:** 36-01 (`GH Blob Version` record + the blob contract), 36-02 (the `GH Blob Version` record type). · **Skill refs:** `supporting-objects.md` (folders/documents), `write-records-patterns.md`, `expressions.md`, `function-reference.md`.

## Purpose

Build the **versioned blob store** for the two large payloads — the gzipped **KB blob** (one per app) and the
published **stage-artifact HTML** — as Appian **Documents** (which version natively) indexed by the
**`GH Blob Version`** record type, with **content-hash dedup** and **keep-last-N** retention.

## Structure

- **Knowledge Center `GH Documents`** with folders **`GH KB Blobs`** and **`GH Artifact Blobs`** (constants
  `GH_FOLDER_KB_BLOBS` / `GH_FOLDER_ARTIFACT_BLOBS` point at them — created in 36-04 alongside the other
  constants, or here).
- **Bytes = an Appian Document per blob key** (skill: `supporting-objects.md`): for `kind='kb'` the key is the
  `app_uuid`; for `kind='artifact'` the key is `<parentSyncUuid>:<stage>`. A new publish either **creates** the
  document (first version) or **uploads a new version** of the existing document (Appian keeps the version
  history). The document lives in the matching folder; its name encodes the key.
- **Index = `GH Blob Version`** (36-01 §2.8): one row per stored version — `blobKind`, `blobKey`, `version`
  (monotonic per key), `contentHash`, `documentId` (the Appian Document ref), `size`, `publishedBy`, `createdAt`;
  `unique(blob_kind, blob_key, version)`. This is what makes dedup, "list versions", and retention **queryable**
  (Appian document versions alone don't carry our `contentHash`).

## Behavior (implemented by the `GH_blobs_put` Web API + helpers in 36-04)

- **Dedup:** on `POST /blobs/{kind}/{key}`, query the latest `GH Blob Version` for the key; if its `contentHash`
  equals the request's → **no-op** (`200 {status:"unchanged", version}`), no new document version, no change-log
  row.
- **Store:** else create/upload the document (new version) → insert a `GH Blob Version` row with
  `version = latest + 1` + the `documentId`/`contentHash`/`size`/`publishedBy` → append a `'blob'`
  `GH Change Log` row → **`201 {status:"new", version}`**.
- **Retention (keep-last-N):** after inserting, delete `GH Blob Version` rows (and their Documents) beyond the
  most-recent `GH_BLOB_KEEP_LAST_N` for that key. Inline in `GH_pruneBlobVersions` (36-04); a scheduled process
  model is an acceptable alternative if inline delete is undesirable (skill: `process-models.md`) — inline is the
  default (no process model).
- **Download:** `GET /blobs/{kind}/{key}` returns the latest version's document bytes (base64) + `contentHash` +
  `version`; `GET /blobs/{kind}/{key}/versions` returns the `GH Blob Version` history metadata.
- **Size:** a large app's KB blob ≈ **1–2 MB gzipped** — well within Appian document limits (confirm the limit on
  the target 26.6 env; note it in the runbook).

## Validation

Upload → new document version + `GH Blob Version` row; identical re-upload → dedup no-op (no new version);
download returns the bytes; list-versions returns history; retention prunes beyond N (rows + documents).
Confirmed by the 36-06 harness with the 36-01 blob fixtures.

## Deliverable

The `GH Documents` knowledge center + blob folders + the document-per-key versioning + the `GH Blob Version`
index, with dedup + keep-last-N.

## Gate

Contract-conformant blob store → 36-04.
