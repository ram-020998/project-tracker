# Progress — Phase 20: Features & Spec Authoring

> **Status (2026-08-11):** 🚧 IN PROGRESS. **20-01 ✅ (embed spike, PASS + user-confirmed round-trip)** · **20-02 ✅
> (m0010 + `FeatureStore`, code-complete, tests green)**. Next: **20-03** (Features tab + feature page + `api/features.py`).
> Genesis code for 20-02+ is in the working tree, **uncommitted — commits + the single genesis release land at 20-06**
> (Phase-19 rhythm). Spec: `specs/phase-20-features-and-spec-authoring.md` (+ `20-01..20-06`); **ADR-042/043** (Proposed).

## 20-01 — Embedded annotation spike ✅ (PASS + user-confirmed)
Proved Path B (embed the Lavish annotation SDK) before building. Findings: `spike/2026-08-11-lavish-embed.md`.
- Pinned `kunchenguid/lavish-axi` @ **`899747a`** (npm 0.1.50, MIT). The injected browser SDK (`artifact-sdk.js` +
  `mermaid-node.js`) is plain ESM, makes **0** network calls, and talks only via `parent.postMessage`.
- A 2-line browser entry (`import {createArtifactSdk, deriveLavishQueueKey}` → call it) bundled through **our esbuild 0.21.5
  (Node 20.20)** into a **~70.5 kb** self-contained IIFE — esbuild resolves `mermaid-node.js` automatically (cleaner than
  Lavish's own `.toString()` `createSdkJs` assembly). **No `lavish-axi` npm dep, no server/CLI/poll, no Node ≥22.**
- Captured the bridge schema: `lavish:queuePrompt {prompt:{uid,selector,tag,text,prompt,target?:{type:"text-range",text,
  start/end anchors},_lavishQueueKey}}` + `lavish:sendQueuedPrompts`.
- **User confirmed** the in-browser round-trip (element + text-range annotations arrive with anchors + comment).
- **Theming (ADR-027):** the SDK builds its palette on the shadow `:host`; seam = make it consume `--lavish-*` overrides
  (fallbacks preserved) + inject Genesis tokens (`--primary #6d8bff` etc.) via `injectLavishSdk` — applied in the harness,
  var→token map recorded for 20-05 (do it theme-aware; log the vendored-SDK patch in `THIRD-PARTY-NOTICES.md`).

## 20-02 — Data model + `FeatureStore` ✅ (code-complete, uncommitted)
**Migration `m0010_features`** (`genesis/db/migrations/m0010_features.py`, schema **v10**) — three tables mirroring the
`kb_*` idiom (`CREATE TABLE IF NOT EXISTS`, additive/forward-only):
- `kb_features` (`app_uuid` FK → `kb_applications ON DELETE CASCADE`, name, description) + `ix_kb_feature_app`.
- `kb_feature_specs` (`feature_id` FK → `kb_features ON DELETE CASCADE`, title, status DEFAULT 'draft', `chat_session_id`
  [no FK — independent chat lifecycle], `html_path`, `content_hash`, `md_export_path`) + `ix_kb_spec_feature`.
- `kb_feature_spec_revisions` (`spec_id` FK CASCADE, `revision_no`, `html_path`, `note`, `UNIQUE(spec_id, revision_no)`) +
  `ix_kb_specrev_spec`.
Registered in `db/migrations/__init__.py` (`MIGRATIONS += features`).

**`FeatureStore`** (`genesis/kb/features.py`) — same style as `DocumentStore` (injected `Database`, `tx()`/`connect()`,
never creates tables): feature CRUD (`create/list/get/update/delete_feature`; `list_features` LEFT-JOINs the spec's
id+status); spec lifecycle (`create_spec` [draft], `get_spec`, `get_spec_for_feature`, `set_spec_html`, `set_status`
[validated against `VALID_SPEC_STATUSES = draft|in-progress|in-review|completed`], `set_md_export`, `delete_spec`); milestone
`add_revision` (auto-increment `revision_no`) / `list_revisions` / `get_revision`. `delete_feature` returns the deleted spec
ids so the caller can remove `feature_specs_dir/<spec_id>/`. Exported from `genesis/kb/__init__.py`.

**Wiring:** `settings.feature_specs_dir` (`~/.genesis/feature-specs`, parallel to `kb_documents_dir`) for the on-disk bulk
`spec.html` + `revisions/<n>.html`. `KbStore.untrack_application` gains an explicit `DELETE FROM kb_features WHERE app_uuid=?`
(cascades specs+revisions via FK) — the **ADR-042 intrinsic-to-app** rule, contrasting Phase-19 documents (which only unlink).

**Tests:** `tests/test_feature_store.py` (9) — version=10, feature CRUD + list-with-spec-status, FK requires a real app,
spec create/lookup, validated status transitions (reject unknown), html/md pointer round-trip, revision auto-increment +
`UNIQUE`, `delete_feature` cascade + returned spec ids, **untrack-app cascades features/specs/revisions**. `tests/test_db.py`
bumped to v10 (applied list, `schema_migrations` rows incl. `features`, current_version/pending; the synthetic
next-migration test moved 10→11 since m0010 is now real). Version assertions in `test_document_store`/`test_chat_store`/
`test_kb_store` bumped 9→10. **Full suite: genesis 384 pytest green; `ruff check genesis` clean.**
