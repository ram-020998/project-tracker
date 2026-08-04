# Phase 16-02 — KB schema (m0007) + KbStore — AS BUILT

> **Status:** ✅ Implemented + tested + shipped · **Release:** genesis **v0.28.0** (commit `2729139`, CI green) · **Date:** 2026-08-04
> **Repo:** `genesis` (master) · **Spec:** `specs/phase-16-appian-knowledge-base/16-02-kb-schema-and-store.md`

## What was built

- **Migration `m0007_kb`** (`genesis/db/migrations/m0007_kb.py`, registered in `MIGRATIONS`): the code-free
  temporal (SCD-2) `kb_*` tables — `kb_applications`, `kb_syncs`, `kb_objects`, `kb_dependencies`,
  `kb_bundles` (+`flow_json`, `key_objects_json`, `entry_point_json`, `release_label`, `snapshot_sync`),
  `kb_bundle_members`, `kb_releases` + indexes. Additive/forward-only; `current_version` → **7**; auto-applies
  at boot via `migrate()` (runs/chat managers).
- **`KbStore`** (`genesis/kb/store.py`): repository over `kb_*` in the `ChatStore` style (takes a `Database`,
  never opens ad-hoc connections, never creates tables).
  - Lifecycle: `register_application` (upsert), `get_application`, `archive_application`,
    `untrack_application` (**table-scoped** delete — never touches runs/chat/copilot tables).
  - Sync: `begin_sync` / `apply(sync_id, result, mode=baseline|delta, removed_uuids=?)` / `finish_sync`.
    `apply` implements the SCD-2 transitions (open on baseline; on delta: unchanged→leave, changed→close+open,
    new→open, removed→close; edges diffed by `(source,target,dep_type)`); recomputes the current bundle set each
    sync and stores **`flow_json` verbatim** (the Atlas-standard structured flow).
  - Releases + point-in-time: `tag_release` (tags the latest succeeded sync + snapshots current bundles under a
    `release_label`), `list_releases`, and a validity-range helper so reads can reconstruct state `at_release`
    (versioning *tools* remain 16-06 backlog).
  - Reads (contract-shaped dicts): `list_applications`, `get_app_overview` (`at_release`), `search_objects`
    (cross-app when `app=None`), `get_dependencies`, `get_object`, `get_bundle` (flow verbatim),
    `search_bundles`, `list_orphans`.
  - **No source code stored or returned** (ADR-037): only the parser's code-free `metadata`.
  - Duck-types the `KbParseResult` (no runtime dependency on `genesis-appian-parser` yet — the pin lands in
    16-03; a `TYPE_CHECKING` hint only).

## Verification (evidence)

- **`tests/test_kb_store.py` (10 tests, green):** migration creates the 7 tables (`current_version==7`);
  baseline apply + all reads; delta transitions with **SCD-2 history preserved** (closed + open rows) and
  deletes closed; explicit `removed_uuids`; cross-app search + scoping; `untrack` table-scoped (a
  `chat_sessions` row survives); point-in-time overview via tagged releases; no-code guard; and a **real
  end-to-end** test parsing the vendored `AiDocumentCenter` package → apply → reads (skips if the parser
  isn't installed).
- Manual real-package check: **2620 objects / 5084 edges / 174 bundles / 804 orphans** all reconcile between
  parser output and `KbStore` reads.
- **Full genesis suite: 239 passed.** `ruff check genesis` clean. **CI green** (pipeline #6496454).

## Existing-test + infra changes

- Bumped migration-count assertions to 7: `test_chat_store.py` (`current_version`), `test_db.py` (baseline
  `[1..7]`, `schema_migrations` 7 rows incl. `kb`, adoption/idempotency, helpers) and moved the synthetic
  "next migration" fixture from version 7 → 8.
- **Fixed a pre-existing, unrelated time-bomb:** `tests/test_config.py::test_retention_plan_and_usage` hard-coded
  a `now` but `plan_prune` used the real clock (drifted past the fixture dates after ~2026-07-29) — now passes
  `now=now` (test-only; `plan_prune` already accepted it).
- **Pinned `ruff==0.15.20`** in dev deps. Unpinned `ruff>=0.6` had drifted (newer default rule set added `UP*`),
  turning ~170 pre-existing repo-wide `Optional[...]` usages into CI failures. Pin makes CI reproduce local;
  none of the flagged issues were in the new KB code (which uses `X | None`).

## Decisions / notes

- `flow_json` stores the parser's structured flow **verbatim** (Atlas standard, per the 16-01 resolution);
  `get_bundle` returns it verbatim.
- Iteration-1 writes/reads are **current-state only** (`valid_to_sync IS NULL`); the SCD-2 columns + `kb_releases`
  are present so versioning (16-06) lands as code-only, no migration.

## Remaining / hand-off

- **Next: 16-03** — the `sync-application` workflow (deterministic Deployment-REST export → parse → `KbStore.apply`),
  which adds the `genesis-appian-parser` tag pin to genesis and makes the real end-to-end kb test run in CI.
- Consider a follow-up to adopt a newer ruff repo-wide (convert `Optional[...]` → `X | None`) and then un-pin.
