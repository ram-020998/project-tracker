# 19-05 — `sync-documents` workflow (add / pull / parse / write + change detection)

> **Status:** ✅ **CODE-COMPLETE — UNCOMMITTED** (commit at 19-08 per the user). `DocumentSyncEngine` (`genesis/kb/doc_sync.py`,
> injected via `ctx.extras['document_sync']`) + the deterministic **`sync-documents`** workflow (genesis-workflows) + the
> `api/documents.py` add/link/sync/browse routes (friendly 409 when the workflow's not installed or gws not connected). +23
> tests (genesis 372 green; genesis-workflows 75 + validate_library 7 workflows), ruff clean. See
> `progress/phase-19-document-library.md`. **Repos:** genesis-workflows (the workflow) + genesis (`DocumentStore` wiring +
> `api/documents.py`). **Depends on:** 19-02 (gws_client), 19-03 (store), 19-04 (parser).

## Goal
A **deterministic, program-only** LangGraph workflow (no agent, no credits — ADR-001) that ingests and refreshes documents,
mirroring `sync-application` (16-03). Plus the API to add/link/sync from the UI.

## Graph (all program nodes)
`resolve_targets → fetch_or_export → parse → write_documents → v_write → present`
- **resolve_targets** — input selects one of: a single `document_id`, an `app_uuid` (its linked Drive docs), or `all`
  (whole library). Uploaded docs (no `gdrive_file_id`) are skipped by sync.
- **fetch_or_export** — via the `gws_client` seam only. For each Drive doc: `gws drive files get` the fingerprint
  (`modifiedTime,version,md5Checksum,mimeType,name`); **change detection** = compare to the stored fingerprint; unchanged →
  skip. Changed/new → export (Google-native) or download (binary) into a temp path (bulk → blackboard, ADR-010/018). Fail-fast
  on auth (exit 2) / 404 (mark `source_missing`); retry on transient.
- **parse** — `parse_document` (19-04) → `ParsedDocument`.
- **write_documents** — a **raw async node** running the blocking `DocumentStore` writes via `asyncio.to_thread` (§7 deadlock
  lesson): overwrite `latest.md`/`tables.json`/raw, `set_content`/`set_sections`/`set_fingerprint`, `status=parsed`,
  `last_synced_at`. Store injected via `ctx.extras['document_store']` (like `kb_store` in 16-03; `graph.py` never imports the
  platform).
- **v_write** — validator: written rows ≥ changed targets; each parsed doc has a non-empty body or an explicit error.
- **present** — summary (added / updated / unchanged / errors).

## API (genesis, `api/documents.py`, all under `/api`)
- `POST /api/documents` — **add**: `{source: upload|gdrive, …}`. Upload = multipart (ADR-035 posture: 10 MB cap, extension
  allowlist, filename sanitization) → dedup by content-hash. gdrive = `{url}` → resolve `fileId` → dedup by file-id. **Upsert
  into the library + link to `app_uuid` if provided**; kick off a baseline `sync-documents` (single-doc).
- `POST /api/documents/{id}/link` / `DELETE …/link` — link/unlink to an app (unlink never deletes the doc).
- `POST /api/documents/{id}/sync` / `POST /api/applications/{uuid}/documents/sync` / `POST /api/documents/sync` — start a
  `sync-documents` run (single / per-app / library). **Return a friendly 409 if the workflow isn't installed** (the 17-05/17-06
  lesson), not a 500.
- `GET /api/documents` (+ `?app_uuid=`), `GET /api/documents/{id}` (metadata + rendered content), `DELETE /api/documents/{id}`
  (remove from library + artifacts).

## Tests
- Workflow: baseline add (new doc → parsed + linked), delta (fingerprint unchanged → skip; changed → re-parse + overwrite),
  `source_missing` on 404, auth-fail fast. `write_documents` uses `to_thread` (assert no event-loop-blocking write).
- API: add-upload dedup, add-gdrive dedup, link/unlink, sync-not-installed → 409. Use a stub `gws` mirroring real JSON.

## Exit criteria
Add (upload + Drive link) works end-to-end into the global store with app linkage; a changed Drive doc re-syncs to the latest
version; unchanged docs are skipped; not-installed returns 409.
