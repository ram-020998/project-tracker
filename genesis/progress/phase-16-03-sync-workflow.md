# Phase 16-03 — `sync-application` workflow (KB baseline) — AS BUILT

> **Status:** ✅ Implemented + tested + shipped · **Date:** 2026-08-04
> **Releases:** genesis **v0.29.1** (`4bbb63f`) · genesis-workflows **v0.8.1** (`1015244`) — both CI green
> (genesis #6496959; genesis-workflows #6496967, incl. the `workflow-tests` job).
> **Spec:** `specs/phase-16-appian-knowledge-base/16-03-sync-workflow.md`

## What was built

A deterministic, **program-only** LangGraph workflow that populates the local KB from a live Appian app:

```
resolve_inputs → export_package → v_export → parse_package → v_parse → write_kb → v_kb → present
                                     ↘ (retry)                              ↘ fail ↘ surface_error
```

- **`genesis-workflows/workflows/sync-application/`** — `workflow.yaml` + `graph.py` (460 lines) + `README.md`
  + `__init__.py` + `tests/test_workflow.py`. No agent nodes ⇒ no reliability trio, no credits; no
  `pre_mutation` gate (Appian access is **read-only** export; the only write is the local KB).
- **`export_package`** — Appian **Deployment REST API** (export → poll → download) in a program node
  (ADR-001: a mechanical sequence, not an LLM turn). **All** network/env/secret access is isolated in the
  module-level `_fetch_package_zip` seam (the test seam). Terminal errors (missing config, 401/403/404) fail
  fast with actionable messages; transient errors (timeout / 409 / 5xx) record `decisions.export_error` and
  the validator **retries** (only the export retries — a deterministic parse can't change on re-run, and a KB
  mutation must not be blind-retried). Uses `requests` (already a genesis runtime dep), sync, inside the node.
- **`parse_package`** — `genesis_appian_parser.parse(zip)` → a **code-free** `result.json` in the blackboard
  (ADR-037); stashes the result in `ctx.extras['_parse_result']` for the in-process fast path (falls back to a
  deterministic re-parse from the zip on a cold resume).
- **`write_kb`** — `KbStore.register_application → begin_sync(baseline) → apply(mode="baseline") → finish_sync`.
  The `KbStore` is provided by the platform via `ctx.extras['kb_store']` — `graph.py` never imports the genesis
  platform. Re-baselining an app that already has a `baseline_sync_id` is **rejected** in `resolve_inputs`
  (untrack first, or delta/16-07) so a sync can never duplicate rows.
- **Validators** — `v_export` (real, non-empty ZIP via `ctx.workspace`, NOT `target_artifact` — a binary zip
  would crash the validator's utf-8 read), `v_parse` (objects>0, identifies the app), `v_kb` (baseline recorded +
  counts reconcile: `objects_added == parsed total`). Failure → `surface_error` raises → the run fails clearly.

### genesis-side changes (v0.29.0 → v0.29.1)
- **pyproject** pins `genesis-appian-parser@v0.1.0` (runtime); version 0.28.0 → **0.29.1**; app.py version match.
- **runtime/context.py** injects `ctx.extras['kb_store'] = KbStore(settings.db_path)` (lazy; safe for all runs) —
  the single place both the worker and the test harness build context, so the KB store reaches program nodes
  without a `genesis` import in workflow code.
- **config/environments.py** adds public `active()` / `active_environment()` accessors (write_kb records the env
  label a sync came from).
- **runtime/checkpoint.py** — set `PRAGMA journal_mode=WAL` + `busy_timeout=30000` on the `AsyncSqliteSaver`
  connection (see the lesson below).

### Registries (genesis-workflows)
- `registry.json`: `sync-application` catalog entry (`required_mcp: []` — export is REST, not MCP).
- `mcp-registry.json`: replaced the stale **`lcp` `<lcp-image>`** placeholder with **`appian-dev`** (Dev MCP,
  read-only) and added **`appian-devops`** (DevOps MCP, export-only) — both **managed-native** references
  (ADR-038) whose `<managed-native:…>` launch spec is resolved by 16-08. Registered for **agent** use elsewhere
  (16-04/16-05); the sync pipeline injects neither.
- Bumped the genesis-workflows dev-pin **genesis v0.17.0 → v0.29.1** and aligned the runtime
  **genesis-core v0.6.0 → v0.8.2** (what genesis v0.29.1 requires); version 0.7.1 → **0.8.1**.

## Verification (evidence)

- **genesis-workflows:** `validate_library.py` PASSED (5 workflows: schema + contract-parity + reliability +
  refs + catalog + fixture); `workflows/sync-application/tests` 9 passed; full workflow suite **54 passed**;
  ruff clean. **CI green** #6496967 (library-validate + skills-validate + workflow-tests).
- **genesis:** full suite **240 passed** (incl. the new `test_build_context_injects_kb_store`); the real
  package parse→`KbStore` e2e runs locally and skips in CI when the fixture is absent; ruff clean. **CI green**
  #6496959.
- The stubbed full-graph test drives `export→parse→write_kb→validate` end-to-end (export + parse monkeypatched)
  against a **migrated temp KB** and asserts `kb_*` is populated (`get_app_overview` reconciles) and the
  `result.json` is code-free.

## Hard-won lesson (added to the bible §7)

**The LangGraph checkpointer shares `genesis.db` — give its connection WAL + busy_timeout.** The
`AsyncSqliteSaver` connection set no `journal_mode`/`busy_timeout`. When a program node writes `genesis.db`
synchronously **in the same worker process** (the new `KbStore` write), the saver could hold the write lock in
rollback-journal mode and starve the KbStore write → `sqlite3.OperationalError: database is locked` (green
locally, red in CI on the `sync-application` run). Fix: `PRAGMA journal_mode=WAL` + `busy_timeout=30000` on the
saver connection so all writers on the shared db serialize gracefully (WAL = short write locks; busy_timeout =
wait, don't error). App-side `Database` connections already did this.

## Deviations from the spec (deliberate, documented)

- **Retry only on `export`** (not on every validator). Re-running a deterministic parse can't change its result,
  and blind-retrying the KB write would duplicate a baseline — so `v_parse`/`v_kb` fail fast with a clear error.
- **Managed-native MCP representation** kept in the existing registry entry shape with a `<managed-native:…>`
  launch placeholder (mirroring the old `lcp` placeholder convention); 16-08 finalizes the uv-venv launch spec +
  the exact tool names.

## Remaining / hand-off

- **Live acceptance (manual):** a real export against the connected env → parse → KB populated (headless-undrivable).
  The `_fetch_package_zip` Deployment-REST endpoints/bodies are pinned against the live API during this step.
- **Next: 16-08** (managed-native Dev/DevOps MCP install + the `is_dev` toggle) — the prereq for 16-04/16-05.
