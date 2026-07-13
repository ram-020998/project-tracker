# Progress: P2 04 — Event-Log Retention & Event-Bus Consolidation

**Spec:** `specs/phase-07-code-review-fixes/04-p2-eventlog-retention-and-bus-consolidation.md`
**Delivered in:** genesis v0.14.0 (commit `44af9aa`, tag `v0.14.0`)
**CI:** pipelines #6331764 (master) + #6331766 (tag) — both SUCCESS
**Date:** 2026-07-13

---

## Summary

Two independent cleanups shipped together. **Part A** stops the durable `run_events`
table + blackboard from growing unbounded by adding a retention planner + executor
that reclaims *terminal* runs only, honoring the hard "never purge a non-terminal
run" safety rule. **Part B** removes the legacy interim-UI event bus now that the
07-10 cutover retired that UI, leaving a single canonical event path: the in-memory
`EventBus` (live fan-out) + the durable `EventLog` (persistence).

---

## Part A — Event-log retention

### Backend (`genesis/config/retention.py`)
- **`prunable_runs(runs, *, keep_last, max_age_days, now=None) -> list[str]`** — pure
  planner. TERMINAL runs only (`done|failed|cancelled`); a run is eligible if EITHER
  dimension selects it (`keep_last`: all but the N most-recent by `updated_at`;
  `max_age_days`: older than N days). A `running`/`awaiting_input:gate`/
  `awaiting_input:paused` run is **never** returned (ADR-022 / state-and-data-model §4.1).
- **`RetentionPlan`** `{run_ids, event_rows_est, bytes_est}` and **`RetentionResult`**
  `{purged, skipped, event_rows, bytes_freed}` dataclasses.
- **`RetentionService(store, eventlog, settings)`** — `plan()` (estimates via
  `EventLog.count` + `disk_usage`) and `apply(run_ids)` which **re-checks each run's
  status immediately before delete** (skips any run that flipped non-terminal since
  planning), purges `EventLog.purge(run_id)` + the run's blackboard dir, and **keeps
  the `runs` row as a tombstone** (only events + artifacts are removed).

### Wiring
- `runtime/settings.py` — `retention_on_start: bool` (`GENESIS_RETENTION_ON_START=1`,
  off by default) + `_bool_env` helper.
- `runs/manager.py` — `RunManager._maybe_purge_on_start()` runs one purge at init when
  opted in; never blocks startup (failure is swallowed).
- `runs/eventlog.py` — `EventLog.count(run_id)` for plan estimates.
- `api/app.py` — `GET /api/config/retention/plan` (dry-run preview + current policy) and
  `POST /api/config/retention/apply` (re-plans server-side, then applies).

### Frontend (`features/settings`)
- `types/config.ts` — `RetentionPlan` + `RetentionResult`.
- `lib/api/config.ts` — `retentionPlan()` + `retentionApply()`.
- `hooks.ts` — `useRetentionPlan()` + `useApplyRetention()` as **mutations** (on-demand,
  so nothing fires on mount — keeps the strict-MSW settings tests green).
- `components/StorageSection.tsx` — "Reclaim space" button → plan preview in a confirm
  dialog (count / event rows / bytes + the active policy) → danger **Purge** → applies
  and refreshes disk usage. Replaces the old "coming soon" placeholder.

---

## Part B — Event-bus consolidation

- `runs/manager.py` — removed the legacy `_buses` dict, `bus()`, `events()`, and every
  `bus.publish(...)` in `_spawn`. Only the canonical `self._log()` (durable append +
  `cbus` fan-out) and `store.set_status` remain; `on_exit` closes only `cbus`. Error
  events now log the literal `"error"` kind (was the imported `ERROR` constant).
- `runs/events.py` — pruned the unused legacy `Event` kinds
  (`NODE/CUSTOM/AWAITING/FINAL/ERROR/LOG`) and `EventBus.last_final()`. `Event` +
  `EventBus` remain (used by the canonical bus).
- `api/app.py` — removed the legacy `GET /runs/{id}/stream` route. Verified the new web
  client (`lib/api/runs.ts` + `run-detail/hooks.ts`) uses only the canonical
  `/runs/{id}/events` (GET) + `/runs/{id}/events/stream` (SSE) before deleting.

---

## Tests

`tests/test_retention.py` (8):
- `test_prunable_never_includes_nonterminal_even_when_old` — **mandatory safety**: a
  running/awaiting run 100 days old is never prunable under age *or* keep_last.
- `test_apply_skips_run_that_flipped_nonterminal` — **mandatory safety**: a run that
  flips to `running` between plan and apply is skipped; its events are preserved.
- keep_last / max_age / union / disabled-policy planner math; `apply` purges events +
  blackboard but keeps the row; `plan` respects policy and excludes non-terminal runs.

`tests/test_runs.py` updated to the canonical-only model: happy-path asserts
`node.completed` + `run.final` in the durable log; the gate test derives the awaiting
gate from `pending_gate()` instead of the legacy in-memory bus.

`web/.../settings.test.tsx` — added a reclaim-flow test (click "Reclaim space" → plan
preview dialog → Purge → apply POST fired).

---

## Evidence

```
# Backend
$ pytest -q -p no:warnings           → 83 passed
$ pytest tests/test_retention.py -v  → 8 passed (incl. 2 mandatory safety tests)
$ ruff check genesis                 → All checks passed!

# Frontend
$ npm run lint       → 0 errors, 9 pre-existing warnings
$ npm run typecheck  → clean
$ npm test           → 9 files, 60 tests passed
$ npm run build      → ✓ built; web/static/ committed

# CI
Pipeline #6331764 (master): SUCCESS   Pipeline #6331766 (v0.14.0): SUCCESS
```

---

## Decisions / Deviations

- **`apply` re-plans server-side** (the API ignores any client-supplied ids) — the
  status re-check on each run makes this safe and avoids acting on a stale client plan.
- **Runs row kept as a tombstone** (spec's recommended option) — history/UX stays
  consistent; only events + artifacts are reclaimed.
- **Retention uses `RunRecord.updated_at`** as the terminal timestamp proxy (the store
  has no separate `finished_at`); for a terminal run this is when it reached terminal.
- **Web plan/apply are mutations, not queries** — deliberate so the panel never fetches
  on mount, keeping the strict-`onUnhandledRequest:error` settings tests unaffected.
- **Build rule:** followed the post-07-10-cutover rule (rebuild + **commit** `web/static/`),
  superseding the spec's older "web gates green" phrasing; the CI stale-bundle guard passed.

## What's NOT verified (honest disclosure)

- **Live `genesis serve` + browser QA:** not performed headlessly. The API shape is
  covered by backend tests and the panel by a vitest MSW flow; a manual reclaim on a real
  `~/.genesis/genesis.db` with terminal runs would confirm the end-to-end visual.
- **`GENESIS_RETENTION_ON_START` at real startup:** unit-covered via `RetentionService`;
  the env-driven init path is structural (same service call).

---

## Next

P1 06 — Conversation rich-chat (`06-conversation-rich-chat.md`): unified auto-expand
Thinking timeline + markdown answers in the Run-Detail Conversation tab (web only).
P2 05 remains a decision doc (revisit on a scale trigger).
