# 25-09 — DocumentProvider Interface

- **Status:** 📝 DRAFTED · **Review items:** F (new document provider), §19, §20 · **Roadmap:** Phase 2 · **Repos:** genesis · **Proposed ADR:** ADR-052 · **Depends on:** nothing

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
