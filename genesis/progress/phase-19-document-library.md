# Phase 19 — Genesis Document Library — progress (as-built)

> **Status (2026-08-11):** IN PROGRESS. **19-01 ✅ (live-verified) · 19-02 ✅ code-complete + CLI + live smoke test · 19-03 ✅
> code-complete · 19-04 ✅ (parsing pipeline) · 19-05 ✅ (sync-documents workflow + api/documents.py).** Next: 19-06 → 19-08.
> **⚠️ IMPORTANT — the 19-02/19-03/19-04/19-05 code is UNCOMMITTED** in the working trees of `genesis`, `genesis-core`,
> `genesis-workflows` (per the user's instruction to *commit at phase completion*). A new session must NOT re-create these
> files — they already exist locally. Spec: `specs/phase-19-document-library.md` (+ `19-01..19-08`); ADR-040 (managed-native
> CLI) + ADR-041 (global document library) — both **Proposed** (flip to Accepted at release, 19-08).

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

## Test status (uncommitted working tree)
- genesis **372 pass**, ruff clean · genesis-core **65 pass**, ruff clean · genesis-workflows **75 workflow tests** +
  `validate_library.py` green (7 workflows).

## Resume here (next session)
1. **19-06 — consumption**: `genesis-kb` MCP `list/get/search_documents` (over `DocumentStore`, Atlas-style shapes) +
   `KbStore.build_evidence_pack` extended to include an app's linked documents (sections). Chat/spec/design flows then use docs
   alongside the KB.
2. **19-07 — web**: global Document Library page (upload/add-Drive/link/sync/search) + per-app **Business Artifacts** tab +
   Settings→CLI **gws connector card** (status/connect/disconnect from the 19-02 `api/native_cli.py` gws-auth routes).
3. **19-08 — release**: bump chain (genesis-core → genesis → genesis-workflows), **commit the whole phase**, CI green, live
   acceptance, flip ADR-040/041 → Accepted, refresh the bible §2 tag table + test counts.

**Handoff note:** everything above (19-02/19-03/19-04/19-05) is in the working trees, tested green, but NOT committed. Do not
regenerate; `git status` in each repo shows the new/modified files. Commit at phase completion (19-08) per the user's
instruction. **New runtime deps** (`pypdf`/`python-docx`/`openpyxl`) are already `pip install`-ed in the `.venv` and declared
in `pyproject.toml`.
