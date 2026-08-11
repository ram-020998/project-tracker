# 20-02 — Data model + `FeatureStore` (migration m0010)

> **Status:** 📋 DRAFT. **Repo:** genesis. **This is ADR-042** (Features & Specs model). Can proceed in parallel with 20-01
> after the spike is under way (no dependency on the SDK).

## Goal
A first-class **Feature** under an application, and its **Spec** artifact + milestone **revisions**, following the `kb_*`
migration idiom (`m0007`/`m0008`/`m0009`). Unlike Phase-19 documents (global, unlink-not-delete), a feature is **intrinsic to
its app** — untracking the app cascade-deletes its features and their specs.

## Migration `m0010_features` (`Migration(version=10, name="features", up=_up)`; `CREATE TABLE IF NOT EXISTS`)

```sql
CREATE TABLE IF NOT EXISTS kb_features (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  app_uuid    TEXT NOT NULL REFERENCES kb_applications(app_uuid) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_kb_feature_app ON kb_features(app_uuid);

CREATE TABLE IF NOT EXISTS kb_feature_specs (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  feature_id      INTEGER NOT NULL REFERENCES kb_features(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'draft',   -- draft | in-progress | in-review | completed
  chat_session_id TEXT,                            -- → chat_sessions.id (the authoring conversation)
  html_path       TEXT,                            -- pointer to the authoritative spec.html (bulk on disk)
  content_hash    TEXT,
  md_export_path  TEXT,                            -- pointer to the last Markdown export (optional)
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_kb_spec_feature ON kb_feature_specs(feature_id);

CREATE TABLE IF NOT EXISTS kb_feature_spec_revisions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  spec_id     INTEGER NOT NULL REFERENCES kb_feature_specs(id) ON DELETE CASCADE,
  revision_no INTEGER NOT NULL,
  html_path   TEXT NOT NULL,                       -- snapshot on disk
  note        TEXT,                                -- milestone note (user or agent supplied)
  created_at  TEXT NOT NULL,
  UNIQUE (spec_id, revision_no)
);
CREATE INDEX IF NOT EXISTS ix_kb_specrev_spec ON kb_feature_spec_revisions(spec_id);
```

`current_version` becomes **10**. Additive + forward-only. Status is a **TEXT with an app-side enum** (`VALID_SPEC_STATUSES`)
— transitions validated in the store, not by a DB constraint (matches the existing `kb_*` style).

## `FeatureStore` (`genesis/kb/features.py`)
DB-agnostic signatures (ADR-030); blocking writes callable via `asyncio.to_thread` (§7). Uses the shared `Database` factory.
- **Features:** `create_feature(app_uuid, name, description) -> id`, `list_features(app_uuid)`, `get_feature(id)`,
  `update_feature(id, name?, description?)`, `delete_feature(id)` (cascades specs + revisions + on-disk dirs).
- **Specs:** `create_spec(feature_id, title, chat_session_id) -> id` (status `draft`), `get_spec(id)`, `get_spec_for_feature(feature_id)`
  (v1 = 0..1), `set_spec_html(id, html_path, content_hash)`, `set_status(id, status)` (validate against `VALID_SPEC_STATUSES`),
  `set_md_export(id, path)`, `delete_spec(id)`.
- **Revisions:** `add_revision(spec_id, html_path, note) -> revision_no` (auto-increment per spec), `list_revisions(spec_id)`,
  `get_revision(spec_id, revision_no)`.
- **Reads for the API/UI:** feature summaries (name/desc/spec-status/updated_at), spec detail (metadata + resolved HTML path).

## On-disk layout (ADR-010/018; latest + snapshots)
`~/.genesis/feature-specs/<spec_id>/spec.html` (authoritative latest) + `revisions/<n>.html` (milestone snapshots) +
`export.md` (last Markdown export, optional). `settings.feature_specs_dir` (new, defaults under `~/.genesis`). The agent
authors into its **per-session sandbox**; a milestone **copies** the sandbox `spec.html` into this store (see 20-04).

## Tests
- Migration up + `current_version=10`; feature CRUD; **cascade on app delete removes features + specs + revisions**;
  spec create/get/`get_spec_for_feature`; status transition validation (reject an unknown status); revision auto-increment +
  `UNIQUE(spec_id, revision_no)`; `delete_feature` cleans rows + on-disk dirs; HTML pointer + hash round-trip.

## Exit criteria
m0010 applies (schema v10), `FeatureStore` supports the full feature→spec→revision lifecycle with app-cascade semantics and
validated status transitions. **ADR-042 → Accepted** on ship (with the rest of the phase).
