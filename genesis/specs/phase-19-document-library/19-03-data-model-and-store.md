# 19-03 — Document Library data model + `DocumentStore` (migration m0009)

> **Status:** ✅ **CODE-COMPLETE — UNCOMMITTED** (commit at 19-08 per the user). m0009 (schema v9) + `DocumentStore` + 9 tests
> (genesis 343 green, ruff clean); `untrack_application` unlinks-not-deletes (ADR-041). See `progress/phase-19-document-library.md`.
> **Repo:** genesis. **This is ADR-041** (global document library + app-link model;
> unlink-not-delete). Can proceed in parallel with 19-02 after the spike.

## Goal
A **global, first-class** document store (not app-scoped) with an app-link table, following the `kb_*` migration idiom
(`m0007`/`m0008`) but breaking the per-app table-scoped-untrack invariant on purpose (documents are shared).

## Migration `m0009_documents` (`Migration(version=9, name="documents", up=_up)`; `CREATE TABLE IF NOT EXISTS`)

```sql
CREATE TABLE IF NOT EXISTS kb_documents (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  source_type          TEXT NOT NULL,                 -- 'upload' | 'gdrive'
  dedup_key            TEXT NOT NULL UNIQUE,           -- 'gdrive:<fileId>' | 'upload:<sha256>'
  title                TEXT NOT NULL,
  mime_type            TEXT,
  gdrive_file_id       TEXT,                           -- null for uploads
  source_url           TEXT,                           -- the Drive/Docs link, for gdrive
  content_path         TEXT,                           -- pointer to latest.md (bulk on disk)
  content_hash         TEXT,
  tables_path          TEXT,                           -- pointer to tables.json (Sheets/Excel)
  raw_path             TEXT,                           -- pointer to the raw pulled source (latest only)
  byte_size            INTEGER,
  status               TEXT NOT NULL DEFAULT 'pending',-- pending|parsed|error|stale|source_missing
  parse_error          TEXT,
  gdrive_modified_time TEXT,                           -- sync fingerprint
  gdrive_version       TEXT,
  gdrive_md5           TEXT,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  last_synced_at       TEXT
);

CREATE TABLE IF NOT EXISTS kb_document_links (
  document_id INTEGER NOT NULL REFERENCES kb_documents(id)        ON DELETE CASCADE,
  app_uuid    TEXT    NOT NULL REFERENCES kb_applications(app_uuid) ON DELETE CASCADE,
  linked_at   TEXT    NOT NULL,
  PRIMARY KEY (document_id, app_uuid)
);
CREATE INDEX IF NOT EXISTS ix_kb_doclink_app ON kb_document_links(app_uuid);

CREATE TABLE IF NOT EXISTS kb_document_sections (   -- optional; retrieval granularity + pgvector seam
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id INTEGER NOT NULL REFERENCES kb_documents(id) ON DELETE CASCADE,
  ordinal     INTEGER NOT NULL,
  heading     TEXT,
  text        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_kb_docsec_doc ON kb_document_sections(document_id);
```

`current_version` becomes 9. Additive + forward-only.

## `DocumentStore` (`genesis/kb/documents.py` or `genesis/documents/store.py`)
DB-agnostic signatures (ADR-030); blocking writes callable via `asyncio.to_thread` from async nodes (§7).
- **Upsert/dedup:** `upsert_document(source_type, dedup_key, title, …) -> (id, created: bool)` — insert or return existing by
  `dedup_key`.
- **Link/unlink:** `link(document_id, app_uuid)` (idempotent), `unlink(document_id, app_uuid)`, `links_for_app(app_uuid)`,
  `apps_for_document(id)`.
- **Content pointers:** `set_content(id, content_path, content_hash, tables_path?, raw_path?, status, byte_size)`,
  `set_sections(id, sections[])`, `set_error(id, msg)`, `mark_source_missing(id)`.
- **Sync fingerprint:** `set_fingerprint(id, modified_time, version, md5)`, `get_fingerprint(id)`.
- **Reads:** `list_documents(app_uuid?)`, `get_document(id)` (metadata + resolved content), `search(query, app_uuid?)`
  (`LIKE` over title + section text first; pgvector later).
- **Lifecycle:** `remove_document(id)` (deletes row + cascades links + removes on-disk artifacts). **Untrack an app never
  deletes documents** — it removes that app's links; a document with zero links stays in the library (a first-class citizen).

## On-disk layout (ADR-010/018; latest-only)
`~/.genesis/kb-documents/<document_id>/` → `latest.md`, `tables.json` (optional), `raw.<ext>` (optional). Sync **overwrites**.

## Tests
- Migration up + `current_version=9`; dedup (same `dedup_key` → one row); link idempotency + `UNIQUE`; unlink; **cascade on
  app delete removes links, not documents**; `remove_document` cleans links + files; `LIKE` search scoped by app; fingerprint
  round-trip; `source_missing` retains content.

## Exit criteria
m0009 applies, `DocumentStore` supports the full add/dedup/link/unlink/content/fingerprint/search lifecycle with the
global-not-app-scoped semantics. **ADR-041 → Accepted** on ship.
