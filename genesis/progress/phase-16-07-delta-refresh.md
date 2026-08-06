# Phase 16-07 — Delta refresh (Option A: re-export + delta-merge) (as built)

> **Status:** ✅ SHIPPED (Option A — the delta path) — genesis-workflows **v0.8.5**, CI green (pipeline **6513690**).
> The **true incremental** delta (the Appian changed-objects API), the **scheduler**, and the **per-release changelog**
> remain deferred — see `specs/backlog/phase-16-deferred.md` §1.3–§1.5.
> **Date:** 2026-08-06 · **Repo:** genesis-workflows only (genesis unchanged — `KbStore.apply(mode='delta')` shipped in 16-02).

## What shipped — `sync-application` v0.2.0 gains a delta mode

The same deterministic `resolve_inputs → export_package → v_export → parse_package → v_parse → write_kb → v_kb →
present` graph now runs in **two modes** (no new nodes; still program-only, read-only against Appian, no agent/gate):

- **`_resolve_inputs`** — accepts `mode ∈ {baseline, delta}`. **baseline** rejects if a baseline already exists (→ use
  delta, or untrack to re-baseline). **delta** rejects if there is **no** baseline yet ("run a baseline sync first"),
  and computes an informational window `[last-sync-end, now]` (from `KbStore.latest_sync`).
- **`_write_kb_sync`** — mode-aware: `begin_sync(app, mode, window=…)` → `KbStore.apply(sync_id, result, mode=mode)` →
  `finish_sync`. For **delta**, `apply(mode='delta')` diffs the full re-parse against current rows by **`diff_hash`**:
  opens new + modified rows, **closes removed rows (inferred from the re-parse)**, closes/opens changed edges, and
  recomputes bundles — all SCD-2, history preserved. The `[start,end]` window is recorded on `kb_syncs`.
- **`check_kb`** — mode-aware: **baseline** keeps the strict `objects_added == parsed total` reconciliation; **delta**
  asserts the three SCD-2 counters (`objects_added/modified/removed`) are present + non-negative (a delta can't
  reconcile to a single parsed total). Both require the app to have a `baseline_sync_id`.
- **`_present`** — the report now carries `mode` + `window` alongside the counts.

**Why "Option A" (full re-export, not a partial export):** a *true incremental* delta needs a "changed in `[start,end]`"
capability. **Confirmed 2026-08-06** the **Dev MCP cannot provide it** — no modified-since/history/audit tool; `list*`
tools filter only by name/`appUuid`/`limit`/`offset`; design objects carry no modified timestamp. That requires a
**new Appian-side changed-objects API** (owned by the Appian team, contract not finalized, not deployed). Rather than
block, Option A re-exports the whole app and lets `apply(mode='delta')` compute the diff — **correct SCD-2 history +
deletes + bundle recompute + window recording today**, with zero dependency on the missing API. The changed-objects
fast path (export only what changed) slots into the existing `_fetch_package_zip` seam when the API lands.

**Tests (genesis-workflows 55 pytest green, +1; `validate_library` + parity + reliability green):**
- `test_delta_without_baseline_is_rejected` — delta on an untracked app fails fast.
- `test_delta_refresh_merges_scd2` — baseline (3 objects) → delta (`o2` modified, `o3` removed, `o4` added) yields
  `{added:1, modified:1, removed:1}`, current state = `{o1, o2, o4}`, and the delta sync is recorded as `kind=delta`,
  `status=succeeded`, with a window.
- Existing baseline / retry / helper tests unchanged and green.

## Deferred (see `specs/backlog/phase-16-deferred.md`)
- **§1.3** — true incremental delta via the Appian changed-objects API (+ the partial-export optimization).
- **§1.4** — the automatic **scheduler** (per-app interval delta runs). v1 is **manual** "Sync now" (16-04
  `POST /applications/{id}/sync {mode:"delta"}`).
- **§1.5** — the **per-release changelog** (needs 16-06); per-sync deltas are already available from `kb_syncs` + SCD-2.
- **Live acceptance (manual):** re-sync a real app after an env change and confirm the SCD-2 delta + window.

## Post-release live fixes (2026-08-06)

First real sync against the dev env exposed two bugs the synthetic tests missed (both fixed + regression-tested;
verified end-to-end on a live **2516-object** app):

1. **Export 405 (genesis-workflows v0.8.6).** `_fetch_package_zip` was hand-rolled to `POST …/deployments/export`
   with a JSON body → **405**. Corrected to the **real** Appian Deployment REST contract, read from the installed
   DevOps MCP (`appian-deployment-mcp`): **multipart `POST /suite/deployment-management/v2/deployments`** with an
   `Action-Type: export` header + a `json` part `{uuids, exportType, name}`; poll `GET /deployments/{uuid}` to
   `COMPLETED`; download the poll response's **`packageZip`** URL; auth header `appian-api-key`. +2 request-shape tests.
2. **Duplicate object UUIDs (genesis v0.34.0 + genesis-workflows v0.8.7).** The real package listed the same
   `object_uuid` more than once → baseline `KbStore.apply` hit `UNIQUE(app_uuid,object_uuid,valid_from_sync)`.
   `apply` now de-dupes objects by UUID (edges by `(source,target,dep_type)` triple), and the baseline `check_kb`
   reconciliation is `0 < written ≤ parsed` (distinct ≤ raw). +regression tests (KbStore + workflow).

Both are recorded as hard-won lessons in `AGENT_ONBOARDING.md` §7.
