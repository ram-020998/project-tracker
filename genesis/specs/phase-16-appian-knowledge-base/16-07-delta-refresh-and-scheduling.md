# Phase 16-07 — Delta refresh + scheduling

> **Status:** DRAFT (planning) · **Repos:** genesis (+ genesis-workflows + Appian-side API) · **Depends on:** 16-03 (sync workflow baseline), 16-02 (SCD-2 store)
> **Goal:** Keep each tracked app's KB current **incrementally**. A **new Appian API** (owned by the Appian side)
> returns *objects modified in `[start,end]`*; the `sync-application` workflow gains a **delta path** that exports only
> the changed objects, delta-merges into the SCD-2 store (archiving history), and records the window. Add **manual +
> scheduled** triggers and a **changelog** surface. This makes the KB self-updating rather than a one-shot baseline.

---

## 1. Current state (grounded / from earlier sub-phases)
- 16-03 delivered `sync-application` with a **baseline/full** path (deterministic REST export → parse → KbStore
  `apply(mode='baseline')`). `inputs_schema` already has `mode: baseline|delta`.
- 16-02's `KbStore.apply(mode='delta')` implements the SCD-2 transitions (close changed/removed rows, open
  new/modified, recompute bundles) and `kb_syncs` records `window_start/window_end`.
- 16-04's `POST /api/applications/{id}/sync {mode}` can start a delta run; `sync-status` shows it.
- Atlas's `-d:m~1` delta is **not** reused (package-repo-specific). The user owns a new Appian app exposing a
  "changed in window" API ("small app + a few Web APIs; no Appian product change").

## 2. Design

### 2.1 The new Appian "changed-objects" API (contract to finalize with the Appian side)
- **`GET /changed-objects?app=<uuid>&start=<iso8601>&end=<iso8601>`** (auth: the same service-account API key).
- **Response (minimum):** `[{object_uuid, name, type, last_modified, change_kind: added|modified|removed}]`, paginated.
- **Ideal (avoids N exports):** also returns (or links) the changed objects' **content/XML** so Genesis parses without a
  per-object export round-trip.
- **Contract points to settle:** content-inline vs identifiers-only (drives whether Genesis then exports the subset via
  the Deployment API); explicit **deletes** (required to close SCD-2 rows) and rename handling (UUID-keyed, fine);
  pagination for large windows; clock/timezone (use the env's server time; store the window Genesis actually queried).

### 2.2 `sync-application` delta path
```
resolve_inputs (program: mode=delta; window=[last_success_end, now])
  → fetch_changes (program: GET changed-objects → changed/removed UUID list [+content])
      → v_changes (validator: well-formed; window recorded)
  → export_changes (program: if content not inlined → export the changed subset via Deployment API → blackboard)
  → parse_changes (program: genesis_appian_parser.parse over the delta set → KbParseResult(delta))
      → v_parse
  → write_kb (program: KbStore.apply(mode='delta') — close removed, open changed/new; recompute bundles)
      → v_kb
  → present (program: delta summary: added/modified/removed, window, affected bundles → report.json)
```
- **Mode detection / new-release handling:** if a configured `version_constant` shows a version bump within the window,
  treat as a new release baseline (optional; manual tagging remains the primary release mechanism — umbrella Q4).
- Reuses the deterministic-REST + blackboard + validator/retry patterns from 16-03; still **read-only** against Appian
  (no `pre_mutation` gate).
- **Empty window** (no changes) → a no-op sync recorded (`objects_*=0`), so the schedule is observable.

### 2.3 Triggers — manual + scheduled
- **Manual:** `POST /api/applications/{id}/sync {mode:"delta"}` (16-04) — "Sync now".
- **Scheduled:** a lightweight in-app scheduler that, per app, starts a delta `sync-application` run every N minutes/
  hours (config on the app: `sync_interval`, on/off). **Wiring decision:** a small background loop in the app process
  (asyncio task started in `create_app`, honoring the single-user local posture) that calls `RunManager.start(...,
  mode='delta')` per due app; or a manual-only v1 with the scheduler as a fast-follow. Guardrails: never overlap a
  sync for the same app (skip if one is running); back off on repeated failures; surface last-run + next-run in the UI.
  (This is the one genuinely new "background job" concept — keep it minimal and observable; runs are still normal
  `sync-application` runs, so tracking/retry/errors come free.)

### 2.4 Changelog surface
- The **Changelog** view (Applications detail): per-sync deltas (from `kb_syncs` + SCD-2) and per-release diffs (16-06),
  reusing the diff/markdown renderers. Highlights added/modified/removed objects + affected bundles.

## 3. Files & tests
- Backend: delta nodes in `sync-application/graph.py`; the changed-objects client (httpx) reading the env domain +
  service-account key; scheduler (if in v1) in `genesis` (started/stopped with the app); `sync_interval` on
  `kb_applications` (a tiny m0008 column, or a config file — decide; prefer an additive m0008).
- Tests:
  - delta apply end-to-end against a **stubbed changed-objects API** (added/modified/removed set) → SCD-2 transitions +
    bundle recompute + `kb_syncs` window recorded; empty-window no-op; deletes close rows.
  - scheduler (if in v1): due-app selection, no-overlap, back-off — unit-tested with a fake clock/RunManager.
  - web: Changelog view renders; "Sync now" starts a delta run and shows status.
  - `validate_library` + parity + reliability green.
  - **Live acceptance (manual, recorded):** with the real changed-objects API deployed, a development change in the env
    is picked up by a delta sync and reflected in the KB + changelog.

## 4. Acceptance criteria
1. `sync-application` has a working **delta path** driven by the changed-objects API; SCD-2 history + bundle recompute +
   window recording are correct (including deletes); empty windows are no-ops.
2. **Manual** delta sync works from the Applications page; **scheduled** delta sync runs per app (or is a documented
   fast-follow if deferred), non-overlapping + observable.
3. Changelog surfaces per-sync + per-release deltas.
4. Still read-only against Appian; suites + `validate_library` green; live acceptance recorded.

## 5. Out of scope
- The Appian-side implementation of the changed-objects API (owned by the Appian team; Genesis consumes the agreed
  contract).
- Retention/pruning of old SCD-2 rows/snapshots (umbrella Q5) — can follow.
- Any Appian write/deploy; multi-environment.
