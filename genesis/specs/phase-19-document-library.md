# Phase 19 — Genesis Document Library (umbrella)

> **Status:** ✅ **SHIPPED — COMPLETE (19-01..19-08)** — genesis-core v0.9.2 + genesis v0.44.0 + genesis-workflows v0.9.3, all
> CI green; ADR-040/041 Accepted. · **Author:**
> Genesis agent · **Date:** 2026-08-11
> **Goal:** Let users attach the **business documents that describe an application** — the PDFs / Word docs / Excel sheets /
> Google Docs that today live in Google Drive — to Genesis, parse them into a durable, LLM-consumable form, and make that
> knowledge available **alongside the Appian KB** for spec generation, design discussion, and any future workflow. Documents
> are a **global, first-class store** (one copy per unique document) that can be **linked into one or more applications**;
> Google-Drive-linked documents are **kept in sync** (poll for upstream changes → re-pull → re-parse). Google Drive is
> reached through the **Google Workspace CLI (`gws`)** integrated as a **managed-native connector** (parallel to the managed
> native Appian MCP servers, ADR-038), authenticated with `gws`'s **standard OAuth** browser login.
> **Repos:** **genesis** (migration **m0009** `kb_documents`/`kb_document_links`/`kb_document_sections`, a `DocumentStore`,
> the parsing pipeline, the managed-native **CLI** installer + `gws` connector + OAuth flow, `api/documents.py`, the global
> **Document Library** page + per-app **Business Artifacts** tab) + **genesis-core** (`CliRegistry` managed-native resolution
> — additive, `CORE_MAJOR` stays 1, mirrors the 16-08 `McpRegistry` change) + **genesis-workflows** (the deterministic
> **`sync-documents`** workflow + the `gws` managed-native `cli-registry.json` entry). **kiro-agent-sdk** unchanged.
> **Non-negotiable framing:** the document library is **user content, stored once and linked** (dedup — the same document is
> never maintained per-app); Drive access is **read-only** (read-only OAuth scopes + a drive/docs/sheets/slides-only
> allowlist at the invocation seam); sync is a **deterministic LangGraph workflow** (program nodes only — no agent, no
> credits — ADR-001), with blocking DB writes off the event loop (§7 `asyncio.to_thread` lesson); bulk parsed content lives
> on disk as **latest-version-only** artifacts with pointers/metadata in `genesis.db` (ADR-010/018/030). See **ADR-040**
> (managed-native CLI connector) + **ADR-041** (global document library + app-link model).

---

## 0. TL;DR

Phase 16 gave Genesis the *technical* knowledge of an application; Phase 17 turned that into a *business* picture. But the
richest business context an engineer has often isn't in Appian at all — it's the **requirement docs, design docs, data
dictionaries and spreadsheets sitting in Google Drive**. Phase 19 brings those into Genesis so they can be used as first-class
context.

1. **A global Document Library.** A new top-level store (`kb_documents`) holds **one row per unique document**, its parsed
   content kept as a **single latest-version** Markdown artifact on disk (+ JSON for tabular sources), with metadata + a
   sync fingerprint in `genesis.db`. Documents are **not** children of an application.
2. **Linked into applications (dedup).** `kb_document_links(document_id, app_uuid)` associates a document with one or more
   apps. **Adding a document = upsert into the library (dedup by Drive file-id / content-hash) + link to the current app;**
   the same document is stored and synced **once**, never duplicated per app. Untracking an app **unlinks**, it never deletes
   a shared document (a deliberate change to the per-app table-scoped untrack model — see ADR-041).
3. **Two ways to add.** In an app's new **Business Artifacts** tab (or the global Document Library page): **upload** a file
   from disk (PDF / DOCX / XLSX / MD / TXT / CSV, reusing the ADR-035 multipart+sanitization posture) **or** paste a **Google
   Drive / Docs link**.
4. **Google Drive via a managed-native `gws` connector.** The **Google Workspace CLI** is installed and versioned by Genesis
   as a **managed-native CLI** (a lighter cousin of the ADR-038 native-MCP installer — `gws` is a single static binary, so no
   `uv`/venv), configured in **Settings → CLI**, and authenticated with `gws`'s **standard OAuth** browser login using the
   shared org OAuth client. Read-only Drive/Docs/Sheets/Slides scopes only.
5. **Parse → structured, LLM-ready content.** Google-native docs are **exported** via `gws` (Docs → Markdown, Sheets →
   CSV/JSON per tab, Slides → text); binary uploads are converted to Markdown (+ JSON tables for spreadsheets) by a
   server-side parser. Output = a canonical **Markdown** body (bulk → artifact file, pointer+hash in the table) plus optional
   heading-scoped **sections** rows (retrieval granularity; the future pgvector seam).
6. **Kept in sync.** A deterministic **`sync-documents`** workflow (mirrors `sync-application`) pulls Drive files, compares
   the stored `modifiedTime`/`version`/`md5` fingerprint, and re-pulls + re-parses only what changed — **overwriting** the
   single latest artifact. **Manual "Sync now" ships first;** a periodic scheduler is deferred (§11).
7. **Consumed alongside the KB.** The `genesis-kb` MCP gains document tools (`list_documents`/`get_document`/
   `search_documents`) and `KbStore.build_evidence_pack` includes an app's linked documents — so chat, `design-doc`, and
   `generate-business-map` can use them as grounding context.

Bulk parsed content and the raw pulled files live on disk (ADR-010/018); only compact metadata + pointers reach `genesis.db`;
sync stays deterministic (ADR-001) and read-only against Google.

---

## 1. Motivation & user story

> *"We can add an Appian application and build its knowledge base inside Genesis. But the documents that actually explain the
> application — the requirement and design docs, the data dictionaries, the spreadsheets — are all in Google Drive. I want a
> way to attach those documents to an application and keep them in Genesis, so that whenever we generate a spec or have a
> design discussion, that knowledge is used along with the KB. Users should be able to upload a document, or give a Google
> Drive link; we pull it, parse it, store its contents in a structured way, and when the Google doc changes we sync the latest
> version back. To talk to Google we should use the Google Workspace CLI — integrated natively inside Genesis like our Appian
> Dev MCP, configured and authenticated from the CLI page. And the same document shouldn't have to be maintained separately
> for every application — keep an overall document library and link documents into applications."*

Net: Phase 16/17 made Genesis understand the *code*; Phase 19 lets Genesis hold the *human context around the code*, curated
per application but stored once, and kept current with its source of truth in Google Drive.

---

## 2. Background — what we build on

- **Applications surface (16-04).** `api/applications.py` over `KbStore` + `RunManager`, `web/features/applications` (detail
  tabs Business Map · Overview · Syncs · Releases), a Sidebar entry. Phase 19 adds a **Business Artifacts** tab + a global
  **Document Library** sidebar page.
- **`KbStore` + `kb_*` schema (16-02, m0007; 17-01, m0008).** The migration idiom (`Migration(version=N, …)`, `CREATE TABLE
  IF NOT EXISTS`, `kb_*` namespace, FK to `kb_applications` `ON DELETE CASCADE`) and the "current row + reserved
  `release_label`" modelling from `m0008` are the templates for **m0009**. **Note:** documents are *global*, so they are **not**
  FK-scoped to a single app and are **not** swept by the per-app table-scoped untrack — this is the ADR-041 deviation.
- **`sync-application` workflow (16-03).** A program-only LangGraph graph `resolve → export → parse → write_kb → validate →
  present`, all network/CLI/secret access isolated in one seam, blocking KB writes via `asyncio.to_thread` (the §7 deadlock
  lesson). **`sync-documents` is its sibling.**
- **Managed-native MCP installer (16-08, ADR-038).** Drop-in / versioned / rollback / `current` pointer, sha-verified,
  launched from the install, env resolved by the registry (`SecretProvider → EnvironmentRegistry → os.environ`), **no
  auto-fetch**. `gws` gets the same treatment via a **`NativeCliInstaller`** — simpler, because `gws` is a single static
  binary (no `uv sync`/venv). `CliRegistry` gains a `"managed":"<id>"` resolution path exactly like `McpRegistry` did.
- **CLI registry (ADR-005/029).** `CliRegistry` today is PATH-only (`ensure()` = `shutil.which`); the two-tier curated+custom
  model + the Settings → **CLI** tab already exist. Phase 19 adds the managed-native tier for CLIs and the `gws` connector UI.
- **Run-launch file attachments (ADR-035).** `POST /api/runs/upload` + blackboard provisioning + 10 MB cap + extension
  allowlist + filename sanitization. The **upload-from-disk** path reuses this posture.
- **Design-doc + business-map consumers.** `design-doc` and `generate-business-map` already synthesize narrative from Appian
  data; both become natural consumers of linked documents via the evidence pack (19-06).

---

## 3. Architecture (the mental model)

```
Settings → CLI                          Applications → <app> → Business Artifacts        Document Library (global)
  └─ Google Workspace connector              └─ Add: Upload | Paste Drive link                 └─ all documents
       install (managed-native gws)               └─ link into this app                              + link/unlink
       + standard OAuth login                                                                        + Sync now
                │                                          │
                ▼                                          ▼
         NativeCliInstaller  ──launch spec──►  CliRegistry(managed)  ──►  gws (read-only Drive/Docs/Sheets)
                │                                                              │  structured JSON / export
                ▼                                                              ▼
         ~/.genesis/cli-tools/gws/…                             sync-documents workflow (deterministic, program-only)
         (binary + OAuth config dir)                              resolve → pull/export(gws) → parse → write → validate
                                                                          │
                                                    ┌─────────────────────┴───────────────────────┐
                                                    ▼                                               ▼
                                         DocumentStore (genesis.db)                     ~/.genesis/kb-documents/<doc_id>/
                                         kb_documents / _links / _sections              latest.md (+ tables.json, raw source)
                                                    │
                                                    ▼
                                 genesis-kb MCP (list/get/search_documents) + KbStore.build_evidence_pack
                                                    │
                                                    ▼
                                        chat · design-doc · generate-business-map
```

Key boundaries:
- **The `gws` binary location** is owned by `NativeCliInstaller`; **auth/scope env** stays on the `cli-registry.json` entry and
  resolves via the registry/SecretProvider (mirrors the ADR-038 launch-vs-env boundary). The **user's Google tokens** live in
  `gws`'s own encrypted config dir under `~/.genesis`; Genesis never stores or logs them.
- **All Google/`gws` access is isolated** behind one seam (a `gws_client` module) — the workflow node and the connector call
  it, nothing else shells out. Read-only allowlist enforced there.
- **Bulk on disk, metadata in db** (ADR-010/018): raw pulled file + parsed `latest.md` (+ `tables.json`) under
  `~/.genesis/kb-documents/<document_id>/`; `kb_documents` holds pointers + hashes + the sync fingerprint.

---

## 4. Data model (migration m0009, detail in 19-03)

Three tables in the `kb_*` namespace (but **app-independent**):

- **`kb_documents`** — one row per unique document. Columns (sketch): `id` (pk), `source_type` (`upload`|`gdrive`),
  `dedup_key` (unique: `gdrive:<fileId>` or `upload:<sha256>`), `title`, `mime_type`, `gdrive_file_id` (nullable),
  `source_url` (nullable), `content_path` (pointer to `latest.md`), `content_hash`, `tables_path` (nullable),
  `raw_path` (nullable), `byte_size`, `status` (`pending`|`parsed`|`error`|`stale`|`source_missing`),
  `gdrive_modified_time`/`gdrive_version`/`gdrive_md5` (sync fingerprint), `parse_error`, `created_at`, `updated_at`,
  `last_synced_at`.
- **`kb_document_links`** — `(document_id FK→kb_documents ON DELETE CASCADE, app_uuid FK→kb_applications ON DELETE CASCADE,
  linked_at)`, `UNIQUE(document_id, app_uuid)`. Untrack-app deletes links (cascade), never the document.
- **`kb_document_sections`** *(optional, retrieval granularity + future pgvector seam)* — `(id, document_id FK, ordinal,
  heading, text)`. Populated by the parser; safe to defer to a later sub-phase if we want the thinnest first cut.

**Latest-version-only:** sync **overwrites** `latest.md`/`tables.json`/raw source; no historical content is retained on disk.
The fingerprint columns are the only "previous state" kept, purely for change detection. Deleted-upstream → `source_missing`
(keep last content, flag it), never a silent drop.

**Dedup identity:** Drive file-id is canonical for `gdrive` docs (same Drive doc added by two apps = one row, two links);
content-hash for `upload` docs (re-uploading the same bytes = same row).

---

## 5. Google Workspace auth (sub-phase 19-01 spike + 19-02 auth)

Uses `gws`'s **standard OAuth** — no bespoke auth. Genesis points `gws` at a Genesis-owned config dir and drives its
interactive browser login:

- **Config isolation:** `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.genesis/cli-tools/gws/config` +
  `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file` (creds encrypted at rest by `gws`, key under the config dir — right for a
  server-managed process; never the OS keyring).
- **Shared OAuth client:** `GOOGLE_WORKSPACE_CLI_CLIENT_ID`/`CLIENT_SECRET` from Genesis's **SecretProvider** (the shared org
  "Desktop app" client — the `peng-os` equivalent dotfiles uses), so we skip `gws auth setup`/`gcloud` entirely.
- **Login flow:** user clicks **Connect Google Workspace** → Genesis spawns `gws auth login -s drive.readonly,
  documents.readonly,spreadsheets.readonly,presentations.readonly` → captures the printed OAuth URL → surfaces it in the UI →
  user approves in the browser → `gws`'s localhost callback completes (same machine, works alongside Genesis on :8760) →
  Genesis verifies with a cheap read and marks **connected**.
- **Lifecycle:** `gws` auto-refreshes tokens; Genesis re-triggers login only on exit-code-2 (auth error).
- **The load-bearing risk (why 19-01 is a spike first):** confirm `gws` prints a parseable URL and completes the localhost
  callback under a **spawned, non-interactive** subprocess with our env; if it needs a TTY, fall back to the
  `gws auth export` → `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` handoff. This mirrors the 13-01 kiro-permission spike discipline.

**Dependency to obtain from the org:** the shared OAuth client id/secret (Desktop-app type, localhost redirect registered).

---

## 6. Sync & lifecycle (sub-phase 19-05)

- **`sync-documents`** deterministic workflow (program nodes only): `resolve_targets → fetch/export(gws) → parse → write(DocumentStore) → validate → present`. All `gws` access via the shared seam; blocking DB writes via `asyncio.to_thread`.
- **Change detection:** compare stored `gdrive_modified_time`/`version`/`md5` against a fresh `gws drive files get
  --params '{"fileId":…,"fields":"id,name,mimeType,modifiedTime,version,md5Checksum"}'`; re-pull/re-parse only on change.
- **Scope:** a single document, an app's linked set, or the whole library (workflow input selects). Uploaded docs have no Drive
  source → skipped by sync (static until re-uploaded).
- **Manual first:** a "Sync now" action (per-document + per-app + library). A **periodic scheduler is deferred** to a later
  sub-phase/backlog (Genesis has no scheduler; 16-07 deferred one). Remember the 17-05/17-06 lesson: a newly released
  library workflow must be `genesis install`-ed and the endpoint returns a friendly 409, not a 500.

---

## 7. Parsing pipeline (sub-phase 19-04)

- **Google-native (Docs/Sheets/Slides):** `gws` **export** — Docs → Markdown/HTML→MD, Sheets → CSV/JSON per tab, Slides →
  text. No extra dependency.
- **Binary uploads (PDF/DOCX/XLSX):** a server-side converter to Markdown. Candidate: **MarkItDown** (one dependency,
  LLM-oriented MD across PDF/Word/Excel/PPT) — alternatively à-la-carte `pypdf` + `python-docx` + `openpyxl` (the last also
  yields clean per-sheet JSON). **Decision + dependency pin lands in 19-04** (flagged as a real new platform dependency;
  pinned per the supply-chain caution). Parsing runs off the event loop / in the worker; bulk output → artifact files.
- **Output contract:** `latest.md` (canonical body) + optional `tables.json` (spreadsheet data) + optional `sections[]`
  (heading-scoped) + a `content_hash`. Errors set `status=error` + `parse_error` (never a fabricated body).

---

## 8. Consumption — using documents with the KB (sub-phase 19-06)

- **`genesis-kb` MCP** gains read-only document tools: `list_documents(app_uuid?)`, `get_document(id)` (returns the Markdown +
  metadata), `search_documents(query, app_uuid?)` (keyword/`LIKE` first; semantic/pgvector is a future trigger per ADR-030).
- **`KbStore.build_evidence_pack`** (Phase 17) is extended to include the app's **linked documents** (titles + content or
  section excerpts) so `design-doc` and `generate-business-map` synthesize with document context. Chat can query them directly
  via the MCP.
- Read-only throughout; documents are grounding context, not something workflows mutate.

---

## 9. Web (sub-phase 19-07)

- **Global "Document Library" page** (new Sidebar entry): list all documents (title, source, linked apps, status, last-synced),
  add (upload / paste Drive link), open (rendered Markdown via the existing 07-09 `DocumentPreview`), sync, remove-from-library.
- **Per-app "Business Artifacts" tab** (Applications detail): the app's linked documents; **Add documents** dialog with two
  modes — **Upload** (FileDropList, ADR-035 multipart) / **Paste a Google Drive link** — plus **pick from the existing
  library** (link without re-adding); per-row status + "Sync now" + unlink.
- **Settings → CLI**: the **Google Workspace** connector card — install/version/rollback (managed-native), **Connect / Reconnect**
  (the OAuth flow of §5), connection status, configured scopes.
- Reuse existing primitives + tokens; jest-axe on new interactive UI; after any `web/src` change → `npm run build` + commit
  `web/static/` (stale-bundle guard).

---

## 10. Sub-phases, build order & release chain

| # | Sub-phase | Spec |
|---|---|---|
| 19-01 | **`gws` OAuth spike** (load-bearing feasibility: managed browser-OAuth under a spawned subprocess) | `phase-19-document-library/19-01-gws-auth-spike.md` |
| 19-02 | **Managed-native `gws` CLI connector + standard OAuth** (NativeCliInstaller, CliRegistry managed resolution, Settings→CLI connector, read-only scopes) | `…/19-02-gws-connector-and-auth.md` |
| 19-03 | **Document Library data model + `DocumentStore`** (m0009: `kb_documents`/`_links`/`_sections`; dedup + link + unlink-not-delete) | `…/19-03-data-model-and-store.md` |
| 19-04 | **Parsing pipeline** (gws export for Google-native + binary→Markdown/JSON; dependency decision + pin) | `…/19-04-parsing-pipeline.md` |
| 19-05 | **`sync-documents` workflow** (deterministic add/link/pull/parse/write + change detection; manual "Sync now") | `…/19-05-sync-documents-workflow.md` |
| 19-06 | **Consumption** (`genesis-kb` document tools + evidence-pack integration) | `…/19-06-kb-consumption.md` |
| 19-07 | **Web** (global Document Library page + per-app Business Artifacts tab + CLI connector UI) | `…/19-07-web-document-library.md` |
| 19-08 | **Release + acceptance** (version chain, docs, live acceptance; scheduler deferred note) | `…/19-08-release-and-acceptance.md` |

**Suggested build order:** 19-01 (spike, gates auth) → 19-02 (connector+auth) → 19-03 (data model) → 19-04 (parsing) → 19-05
(sync workflow) → 19-06 (consumption) → 19-07 (web) → 19-08 (release/acceptance). 19-03/19-04 can proceed in parallel with
19-02 once the spike (19-01) confirms the auth mechanics.

**Release chain:** `genesis-core` (CliRegistry managed-native resolution — additive, `CORE_MAJOR` stays 1) → `genesis`
(m0009 + DocumentStore + NativeCliInstaller + gws connector + parsing + api/documents + web) → `genesis-workflows`
(`sync-documents` workflow + `gws` managed-native `cli-registry.json` entry). Release order core → genesis → genesis-workflows
so tags exist. Frontend changes ship a genesis release (committed `web/static/`). **kiro-agent-sdk unchanged.**

---

## 11. Open items / deferred

- **Periodic sync scheduler** — deferred (manual "Sync now" ships first). Genesis has no scheduler yet; design a lightweight
  in-process periodic poller (or reuse whatever 16-07's deferred scheduler lands as) in a follow-up sub-phase/backlog.
- **Semantic search over document content** — the `kb_document_sections` table is the seam; actual pgvector is a future ADR-030
  trigger, not this phase.
- **Non-Drive Google sources / other providers** — out of scope (Drive + uploads only; no Gmail/Calendar per the user).
- **Multi-version history** — explicitly out (latest-version-only per the user).
- **Dependency to obtain:** the shared org OAuth client id/secret (Desktop-app), provisioned into Genesis secrets.
- **Parsing library choice** finalized in 19-04 (MarkItDown vs à-la-carte) — a real new platform dependency, pinned.

## 12. Non-goals

- Not a Google Drive browser/file-manager; not editing or writing back to Drive (read-only).
- Not Gmail/Calendar/Chat/Admin — Drive + documents only.
- Not per-app duplication of documents (global store + links).
- Not a general RAG/vector search engine (yet) — keyword search first.
- Not the periodic scheduler (deferred).
