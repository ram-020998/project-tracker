# Phase 16-03 — `sync-application` workflow (KB baseline) — AS BUILT

> **Status:** ✅ Implemented + tested + shipped · **Date:** 2026-08-04
> **Releases:** genesis **v0.29.1** (`4bbb63f`) · genesis-workflows **v0.8.2** (`6728e82`) — CI green on both master
> and the tag pipeline (genesis #6496959; genesis-workflows master #6497156 + tag #6497157, incl. the `workflow-tests`
> job). *(v0.8.1 was superseded by v0.8.2 — see the concurrency lesson below.)*
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

**A blocking DB write inside an async node deadlocks the LangGraph checkpointer.** `write_kb` did a **synchronous,
blocking** `KbStore` write on `genesis.db` *inside the async worker*. The `AsyncSqliteSaver` (aiosqlite) shares that
db and does `execute` then `await commit()`; when a checkpoint write is in-flight (write lock held, commit pending)
and the node's sync write seizes the single-threaded event loop waiting for that same lock, the checkpointer's commit
can never run to release it → **deadlock** → `sqlite3.OperationalError: database is locked` after the busy_timeout.
It's timing-dependent: it passed locally and on the master pipeline but failed on the **tag** pipeline for the *same
commit* (#6496968). WAL + busy_timeout on the saver connection (genesis v0.29.1) only *reduced* the flake — the
loop-starvation deadlock is the real cause. **Deterministic fix (v0.8.2):** `write_kb` is a **raw async node** that runs
the blocking `KbStore` write via **`asyncio.to_thread`**, keeping the loop free so the checkpointer can commit/release.
Reproduced in isolation: a sync write on the loop FAILS in ~5s, `to_thread` SUCCEEDS in ~0.25s. Reads (WAL) don't take
the write lock, so the validator/read nodes stay sync.

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
