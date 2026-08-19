# 25-09 — DocumentProvider Interface

- **Status:** ✅ BUILT (2026-08-19, commit `cd9abc8`; **SHIPPED genesis v0.50.0**, ADR-052 Accepted) — `DocumentProvider` Protocol + `GoogleDriveProvider`; `DocumentSyncEngine` depends on the interface; fake-provider tests green (no gws). · **Review items:** F (new document provider), §19, §20 · **Roadmap:** Phase 2 · **Repos:** genesis · **Proposed ADR:** ADR-052 · **Depends on:** nothing

## As built (commit `cd9abc8`; genesis 566 pytest [+5] + ruff green)
- **`genesis/integrations/documents/` (NEW):** `DocumentProvider` Protocol (`supports`/`resolve`/`fetch`) + provider-neutral `DocRef`/`DocMeta` (fingerprint map for stale-detection, §21) + `DocumentProviderError`; `GoogleDriveProvider` wraps the read-only `gws` connector (resolve=`get_file`+modifiedTime/version/md5; fetch=export[native]/download[binary] — `is_google_native`/`google_export_target` moved out of the engine into here); `build_document_providers()` = composition-root registry `{gdrive: …}`.
- **`kb/doc_sync.py`:** `DocumentSyncEngine.fetch`/`add_gdrive` depend on the interface (gws types no longer imported there; `GwsError`→`DocumentProviderError`). The `gws_provider` constructor arg stays back-compat (auto-builds the registry); `runtime/context.py` injects `providers=` at the composition root.
- **Behavior preserved:** `fetch()` result shapes + auth fail-fast + fingerprint stale-skip byte-identical; existing `test_doc_sync`/`test_documents_api`/`test_gws_client` (45) green via `GoogleDriveProvider`. +5 `test_document_provider.py` drive the engine end-to-end with a `FakeDocumentProvider` (no gws).
- **Design note:** the Appian Deployment REST export stays **concrete** (one impl; review §36 over-abstraction) — only documents got an interface.
- **DoD:** met except ADR-052→Accepted + genesis release CI + `bible/03` release update → deferred to the next release (ships with 25-09..).

## 1. Goal
Introduce a thin **`DocumentProvider`** interface so document sourcing is a capability with a clean boundary (Google Drive as the first implementation, behind the interface), making a second source (e.g. SharePoint) an **additive adapter + registry entry** rather than a sibling adapter wired via branches through business logic.

## 2. Why (review evidence)
- **§F "New document provider (Drive → SharePoint)":** rated **Medium** — `gws` is reasonably isolated (`integrations/gws/`, `DocumentSyncEngine` via `ctx.extras`) but there is **no `DocumentProvider` interface**; you'd add a sibling adapter and a branch.
- **§19/§20:** external integrations should sit behind a clear adapter boundary; CLI calls must not spread through business logic. `gws` is mostly contained already — this sub-phase promotes it to a named interface.
- **ADR-052:** define capability interfaces only where a second implementation is plausibly on the roadmap — documents qualifies; the Appian Deployment REST export does **not** (stays concrete until a second deploy target exists — avoids review §36 over-abstraction).

## 3. Current state (cited)
- `genesis/integrations/gws/` — `GwsClient` (read-only Drive/Docs/Sheets/Slides allowlist), `GwsLogin`, `factory.build_gws_client`.
- `genesis/kb/doc_sync.py` — `DocumentSyncEngine` (injected via `ctx.extras['document_sync']`): resolve/fetch/parse/write/add_upload/add_gdrive/remove — already the seam, but typed to `gws` specifics.
- `kb/doc_parsing.py` — provider-agnostic already (PDF/DOCX/XLSX/CSV/MD/TXT → Markdown + tables).

## 4. Design
### 4.1 The interface (`genesis/integrations/documents/provider.py` — NEW)
```python
class DocumentProvider(Protocol):
    id: str                                   # "gdrive" | "sharepoint" | ...
    def resolve(self, ref: DocRef) -> DocMeta: ...          # id/title/mime/modified fingerprint
    def fetch(self, ref: DocRef) -> bytes | Path: ...       # export→binary/text convergence
    def supports(self, ref: DocRef) -> bool: ...
```
- `DocRef`/`DocMeta` are provider-neutral dataclasses (external id, mime, revision/fingerprint for stale-detection — review §21).
- `GoogleDriveProvider` (wraps today's `GwsClient`) is the first impl; `DocumentSyncEngine` depends on `DocumentProvider`, not `GwsClient`.
- A tiny registry maps a source id → provider (uploads remain a built-in local "provider"/path).

### 4.2 Stale detection & provenance (review §21)
- The interface returns a **fingerprint** (Drive revision / content hash) so `DocumentSyncEngine` can skip unchanged docs and record provenance — formalizing what §21 asks for (checksum/external-id/stale-version handling).

## 5. Files touched
- **New:** `integrations/documents/{__init__,provider,gdrive}.py`, `tests/test_document_provider.py`.
- **Edit:** `kb/doc_sync.py` (`DocumentSyncEngine` depends on `DocumentProvider`), `integrations/gws/*` (wrap in `GoogleDriveProvider`), `runtime/context.py` (inject the provider).

## 6. Tests
- A `FakeDocumentProvider` drives `DocumentSyncEngine` end-to-end (resolve→fetch→parse→store) with **no `gws` binary** — proves the boundary.
- Fingerprint stale-skip: unchanged fingerprint → no re-parse/re-write.
- Regression: existing gws/document tests pass via `GoogleDriveProvider`.

## 7. Risks & mitigations
- **Risk:** over-abstracting with one impl. **Mitigation:** ADR-052 constrains to capabilities with a plausible 2nd impl; the interface is 3 methods.
- **Risk:** the "list method must populate derived fields" bug (bible §7). **Mitigation:** keep `DocumentStore` shape untouched; the interface only changes sourcing.

## 8. Out of scope
Building the SharePoint provider; changing the Document Library UI; the Appian Deployment REST abstraction (stays concrete).

## 9. Definition of Done
`DocumentProvider` Protocol + `GoogleDriveProvider`; `DocumentSyncEngine` depends on the interface; fake-provider tests green (no gws needed); ADR-052 → Accepted + mirrored to `bible/04`; genesis release CI-green; `bible/03` updated; progress doc.
