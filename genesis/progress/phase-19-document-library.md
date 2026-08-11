# Phase 19 — Genesis Document Library — progress (as-built)

> **Status (2026-08-11):** ✅ **SHIPPED — PHASE 19 COMPLETE (19-01..19-08).** Released **genesis-core v0.9.2 → genesis v0.44.0
> → genesis-workflows v0.9.3**, all CI green; **ADR-040/041 Accepted**. Live-accepted (a real Drive .xlsx added → auto-synced via
> `gws` → parsed → viewed full-screen). Spec: `specs/phase-19-document-library.md` (+ `19-01..19-08`).

## Decisions locked (from the design discussion)
- **Documents = global first-class store + app-link table** (ADR-041). Dedup by Drive file-id (`gdrive:<id>`) / upload
  content-hash (`upload:<sha256>`). **Untrack an app unlinks, never deletes** the shared document. **Latest-version-only** on
  disk (sync overwrites); only a change-detection fingerprint is retained.
- **`gws` = managed-native CLI connector** (ADR-040), the CLI analog of the native Appian MCP (ADR-038) — single static binary,
  no `uv`/venv. **Isolated** config dir `~/.genesis/cli-tools/gws/config` (file keyring, Genesis-driven `gws auth login`);
  **reads the OAuth client** from the dotfiles-provisioned `~/.config/gws/client_secret.json` (**no shipped token**; dotfiles
  setup is a documented prerequisite). Read-only Drive/Docs/Sheets/Slides scopes only.
- **Lesson banked:** never point Genesis at the user's real `~/.config/gws` with a forced keyring — it invalidated their creds
  during a probe. Genesis owns an isolated dir and only *reads* the client file.

## 19-01 — gws OAuth spike ✅ (committed to project-tracker)
`spike/2026-08-11-gws-oauth-and-export.md`. Verified against real `gws 0.22.5`: config isolation; parseable OAuth URL on
stderr under a spawned subprocess; localhost callback (no TTY); exit-2 on missing creds; native `--readonly` scopes; Drive
fingerprint fields (`id,name,mimeType,modifiedTime,version,md5Checksum`) + export. **Live end-to-end confirmed.**

## 19-02 — managed-native gws connector + standard OAuth ✅ (code, UNCOMMITTED) + live smoke test
- **genesis-core** — `CliRegistry` managed-native resolution (`{"managed":"<id>"}` → injected `launch_provider`; PATH fallback).
  Additive, `CORE_MAJOR` stays 1. Files: `genesis_core/clis/registry.py` (M), `tests/test_integrations.py` (M, +4 tests → **65**).
- **genesis** (all green, **343** tests, ruff clean):
  - `runtime/settings.py` (M) — `cli_tools_dir`, isolated `gws_config_dir`, `gws_client_secret_path` (dotfiles client).
  - `cli_tools/native/` (NEW) — `NativeCliInstaller` + `NativeCliLockfile` (drop-in single-binary install/version/rollback/
    `active_launch_spec`/status). Tests: `tests/test_native_cli_installer.py` (+6).
  - `integrations/gws/` (NEW) — `client.py` (read-only allowlist, exit-code map, reuse/isolated modes, `list_files`/`get_file`/
    `connected`/`client_present`/`login_command`/`logout`), `login.py` (`GwsLogin` spawn + URL capture + state), `factory.py`
    (`build_gws_client`/`build_gws_login`, isolated mode). Tests: `tests/test_gws_client.py` (+18), `tests/test_gws_login.py` (+4).
  - `config/service.py` (M) — `native_cli` installer + `gws()`/`gws_login()` accessors + CLI `launch_provider` wiring.
  - `api/native_cli.py` (NEW) — `GET /config/native-cli`, install/rollback, `GET/POST /config/gws/auth[...]` (status, begin-login→URL,
    login state, logout); not-installed/no-client → 409. Registered in `api/app.py` (M). Tests: `tests/test_native_cli_api.py` (+4).
  - `cli/main.py` (M) — `genesis cli install-native|status|rollback-native`.
- **genesis-workflows** — `cli-registry.json` (M): `gws` managed entry + read-only allowlist. `validate_library.py` green.
- **LIVE SMOKE TEST PASSED (2026-08-11):** installed the real brew `gws` into the managed dir
  (`~/.genesis/cli-tools/gws/versions/0.22.5/gws`), drove Genesis's **own** isolated `gws auth login` (browser approval by the
  user), then `connected: True` (`keyring_backend: file`, read-only scopes) + a real `list_files` read with the fingerprint.
  Genesis's isolated gws auth is persisted at `~/.genesis/cli-tools/gws/`; the user's `~/.config/gws` was untouched.
- **Remaining:** the Settings→CLI connector **card** = 19-07 (web).

## 19-03 — Document Library data model + DocumentStore ✅ (code, UNCOMMITTED)
- **Migration `m0009_documents.py`** (NEW) — `kb_documents` (global, dedup_key UNIQUE) + `kb_document_links`
  (FK→kb_applications ON DELETE CASCADE) + `kb_document_sections`. Registered in `db/migrations/__init__.py` (M); schema now **v9**.
- **`kb/documents.py`** (NEW) `DocumentStore` — upsert/dedup, link/unlink, content pointers + fingerprint (latest-only),
  sections, keyword (`LIKE`) search, remove. Exported from `kb/__init__.py` (M).
- **`kb/store.py`** (M) — `untrack_application` now explicitly removes `kb_document_links` (ADR-041: unlink, keep the global doc).
- Tests: `tests/test_document_store.py` (+9); migration-count/version assertions updated in `tests/test_db.py`,
  `tests/test_chat_store.py`, `tests/test_kb_store.py` (8→9; synthetic next-migration test → v10).

## 19-04 — Parsing pipeline (documents → structured, LLM-ready content) ✅ (code, UNCOMMITTED)
- **Dependency decision (PINNED):** à-la-carte **`pypdf==6.15.0` + `python-docx==1.2.0` + `openpyxl==3.1.5`** over MarkItDown
  — pure-Python, narrow/auditable dependency trees (supply-chain caution), and openpyxl yields clean per-sheet JSON directly.
  Added to `pyproject.toml` `[project.dependencies]`. MD/TXT/CSV need no dependency.
- **`kb/doc_parsing.py`** (NEW) — `ParsedDocument` (content_md, content_hash [sha256 of the body], title, mime_type, byte_size,
  tables, sections) + `parse_document(path)` / `parse_bytes(data, filename=…)`. Per-type parsers: MD/TXT passthrough; CSV→
  one table + MD table; PDF→pypdf page text (`## Page N`); DOCX→python-docx (Title/Heading styles→ATX headings, tables→JSON+MD);
  XLSX→openpyxl **per-sheet** `{sheet, rows}` JSON + MD tables. `_sections_from_markdown` splits the body into heading-scoped
  sections (retrieval granularity). Errors → `DocumentParseError` (never a fabricated body).
- **Google-native convergence:** `is_google_native` + `google_export_target(mime)` → Docs=`text/markdown`, Sheets=`.xlsx`
  (so openpyxl gives per-tab structure, not a flattened first sheet), Slides=`text/plain`. The connector exports to that target
  then feeds the file through the SAME `parse_document` — no separate Google parser.
- **`integrations/gws/client.py`** (M) — `export_file(file_id, mime, out)` (`gws drive files export -o`) + `download_file`
  (binary Drive files via `get` `alt=media -o`); both pass the read-only allowlist.
- **`kb/doc_parsing.store_parsed(store, docs_dir, id, parsed)`** — writes `latest.md` (+ `tables.json`) under
  `kb_documents_dir/<id>/` (**latest-version-only**, overwrite) and calls `DocumentStore.set_content`/`set_sections`.
  `runtime/settings.py` (M) adds `kb_documents_dir` (`~/.genesis/kb-documents`).
- Tests: `tests/test_doc_parsing.py` (+11 — real docx/xlsx/csv/md/txt fixtures + a hand-built PDF + the Sheet→xlsx convergence
  + unsupported/corrupt → error + `store_parsed` round-trip); `tests/test_gws_client.py` (+2 — export writes+parses, download).
- Runs OFF the event loop (upload path `asyncio.to_thread`; Drive path in the 19-05 worker subprocess).

## 19-05 — `sync-documents` workflow + Document Library API ✅ (code, UNCOMMITTED)
- **`genesis/kb/doc_sync.py`** (NEW) — `DocumentSyncEngine`, the injected seam (bundles the read-only `gws` client + global
  `DocumentStore` + 19-04 parser). Methods: `resolve_targets(scope=document|app|library)` (uploads skipped — no Drive source),
  `fetch(target, dest)` (fingerprint change-detect → export/download; **fails fast on auth**; 404→source_missing),
  `parse(path)` (returns `{ok, parsed|error}` — no exception crosses the workflow boundary), `write(id, parsed, fingerprint)`
  (BLOCKING → `store_parsed` + `set_fingerprint`), `write_error`/`write_source_missing`, `add_upload`/`add_gdrive`, `remove`
  (row+links+sections+on-disk). Helpers `parse_gdrive_url`/`sha256_hex`.
- **`genesis/runtime/context.py`** (M) — injects `ctx.extras['document_sync']` (lazy `_gws_provider` = `build_gws_client` +
  `NativeCliInstaller`), mirroring `kb_store`.
- **genesis-workflows `workflows/sync-documents/`** (NEW) — program-only graph `resolve_targets → fetch_or_export → parse →
  write_documents → v_write → present` (+ `surface_error`). `write_documents` is a **raw async node** running the blocking
  writes via `asyncio.to_thread` (§7 deadlock lesson). `graph.py` never imports the platform (uses `ctx.extras['document_sync']`
  + `ctx.workspace`). Registered in `registry.json`. `validate_library` passes (**7 workflows**).
- **`genesis/api/documents.py`** (NEW, registered in `app.py`) — `POST /documents/upload` (multipart; ADR-035 guards: 10 MB,
  ext allowlist, sanitized name; parse+store off-thread), `POST /documents/gdrive` (`{url, app_uuid?}`; 409 if not connected),
  `POST/DELETE /documents/{id}/link`, `POST /documents/{id}/sync` / `POST /applications/{uuid}/documents/sync` /
  `POST /documents/sync` (**friendly 409 if the workflow isn't installed OR gws not connected** — the 17-06 lesson, never a
  500), `GET /documents`(+`?app_uuid=`), `GET /documents/search`, `GET /documents/{id}` (+ rendered content), `DELETE`.
- Tests: `tests/test_doc_sync.py` (+10 — engine resolve/fetch[unchanged/fetched/source_missing/auth]/parse/write/add-upload-
  dedup/add-gdrive/remove, with a fake gws), `tests/test_documents_api.py` (+6 — upload+dedup, bad-ext, link/unlink, list/get/
  search/delete, sync→409, gdrive→409); `workflows/sync-documents/tests/test_workflow.py` (+7 — baseline pull→parse→store,
  unchanged-skip, source_missing, auth-fail-fast, validator/summary, with a fake gws via the harness).

## 19-06 — Consumption: genesis-kb document tools + evidence-pack ✅ (code, UNCOMMITTED)
- **`genesis/mcp/kb_server.py`** (M) — three read-only document tools added to the Tier-1 surface (now 20 tools):
  `list_documents(app_uuid?)`, `get_document(document_id)` (metadata + Markdown body + JSON tables), `search_documents(query,
  app_uuid?)` (LIKE over title + section text). `KbAccessor` refactored to share one read-only `Database` (`_ro_db`) across a
  `KbStore` + a `DocumentStore` (`_docs`). Auto-trusted in chat: `chat/mcp.py` builds the trust set from `_KB_TOOLS`, so
  `@genesis-kb/{list,get,search}_documents` are trusted with no chat change.
- **`genesis/kb/store.py`** (M) — `build_evidence_pack` now includes a **`documents`** key: an app's linked, parsed docs
  (`kb_document_links` JOIN `kb_documents WHERE status='parsed'`) as **bounded, code-free excerpts** (new caps
  `documents`=12, `document_chars`=4000; `_evidence_documents` helper reads the on-disk Markdown, truncates, flags
  `excerpt_truncated`). Read-only (docs never mutated); protects the context window (Phase-9 spirit). `design-doc` /
  `generate-business-map` get document-aware grounding for free.
- Tests: `tests/test_kb_server.py` (+2 — doc-tool shapes + app-scoping + not-found + trust-surface membership);
  `tests/test_kb_store.py` (+1 evidence-pack-with-linked-documents [size budget respected] + a `documents == []` assert on the
  no-docs pack).

## 19-07 — Web: Document Library page + Business Artifacts tab + gws connector card ✅ (code, UNCOMMITTED)
- **Client:** `types/documents.ts` + gws types in `types/config.ts`; `lib/api/documents.ts` (list/get/search/upload[multipart]/
  addGdrive/link/unlink/sync[single|app|library]/remove) + `configApi` gws methods (`gwsAuth`/`gwsLoginBegin`/`gwsLogout`) +
  api-index export; query keys `documents.*` + `config.gwsAuth`.
- **`features/library/`** (NEW — note: `features/documents/` was already taken by the 07-09 `DocumentPreview`/renderers, which
  this REUSES): `hooks.ts` (TanStack query/mutations), `DocumentTable.tsx` (+`docTone`), `AddDocumentDialog.tsx` (Upload /
  Google-Drive-link / **multi-select** Pick-from-library tabs), `DocumentDetailPage.tsx` (full-screen `/documents/:id` viewer —
  full-width + horizontal scroll, Back nav, metadata + `MarkdownView` body), `LibraryPage.tsx`
  (global page: search + source/status filters + Sync-all + Add + remove-confirm).
- **Per-app tab:** `BusinessArtifactsTab.tsx` (linked docs; Add [upload/drive/pick] + per-row Sync + Unlink) wired into
  `features/applications/ApplicationDetail.tsx` as the 5th tab (**Business Map · Overview · Syncs · Releases · Business
  Artifacts**).
- **Settings → CLI:** `components/cli/GwsConnectorCard.tsx` (install/connection state + Connect/Reconnect [opens the sign-in URL
  from `POST /config/gws/auth/login`] / Disconnect; read-only-scopes note) mounted atop `CliTab`; gws hooks in `settings/hooks.ts`.
- **Nav/routes:** Sidebar “Documents” entry (`FileText`); routes `/documents` + `/documents/:id`.
- Tests: `features/library/library.test.tsx` (+6 — list, add-upload, sync, **jest-axe a11y**, connector connect-flow [mocked
  auth URL] + connected/disconnect). **`web/static/` rebuilt** (`npm run build`) — uncommitted with the rest.

## Test status (as released)
- genesis **375 pytest**, ruff clean · genesis-core **65 pytest**, ruff clean · genesis-workflows **75 workflow tests** +
  `validate_library` (7 workflows) · **web: tsc clean, eslint 0 errors, 138 Vitest (17 files), `npm run build` OK.**

## 19-08 — Release ✅ (SHIPPED)
- Release chain (tags + pins, dependency order): **genesis-core v0.9.2** (`831f7dd`) → **genesis v0.44.0** (`ff94753`,
  repins core v0.9.2 + declares pypdf/python-docx/openpyxl) → **genesis-workflows v0.9.3** (`b1c6685`, repins core v0.9.2 +
  genesis v0.44.0). All three **CI pipelines green** (core #39, genesis #147, workflows #61 — incl. the genesis `frontend`
  stale-bundle guard on the rebuilt `web/static/`). `ruff==0.15.20` pinned in genesis + genesis-core.
- **ADR-040 + ADR-041 → Accepted** in `reference/decision-log.md`.
- **Post-release fixes folded in before the tag** (surfaced by live click-through): `DocumentStore.list_documents` now
  populates `linked_apps` (a missing field had crashed the web list); the Drive **add** path auto-starts a single-doc
  `sync-documents` run (parse immediately, not only on manual Sync); the document viewer is a **full-screen page**
  (`/documents/:id`, full-width + horizontal scroll for wide sheets) with Back nav (replaced the narrow drawer); the
  Business-Artifacts "Pick from library" supports **multi-select**.
- **Live acceptance PASSED:** a real Google Drive document (including an `.xlsx`) was added → auto-synced via the read-only
  `gws` export → parsed → rendered in the full-screen viewer. **PHASE 19 COMPLETE.**

**Optional future polish:** a spreadsheet-grid view rendered from `tables.json`; a scheduler for periodic document sync;
semantic/pgvector document search (an ADR-030 trigger).
