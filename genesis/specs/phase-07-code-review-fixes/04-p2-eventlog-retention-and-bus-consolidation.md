# 04 — P2: Event-Log Retention & Event-Bus Consolidation

**Priority:** P2 (hardening) · **Layer:** `genesis` · **Depends on:** `01` (soft — uses the DB
layer); bus removal happens at the **07-10 cutover**.

> Two independent cleanups: (a) stop the durable event log from growing unbounded, respecting the
> hard "never purge non-terminal runs" safety rule; (b) delete the legacy interim event bus once
> the new UI is the only consumer.

---

## Part A — Event-log retention

### A.1 Problem (verified)
- `EventLog.purge(run_id)` (`genesis/runs/eventlog.py`) exists but **nothing schedules it** — the
  `run_events` table grows forever.
- **Artifact** retention is specced (ADR-022) and `Settings` already carries
  `retention_keep_last` + `retention_max_age_days` (env `GENESIS_RETENTION_KEEP_LAST` /
  `GENESIS_RETENTION_MAX_AGE_DAYS`); `genesis/config/retention.py` has `disk_usage`. But retention
  currently targets the blackboard, not the event log.

### A.2 Goal / Non-goals
- **Goal:** apply a retention policy to `run_events` (and, consistently, to prunable blackboard
  runs) so old **terminal** runs' transcripts are reclaimable — manually and/or on a schedule.
- **Hard safety rule (non-negotiable, ADR-022 / state-and-data-model §4.1):** **never** purge a
  run that is `running | awaiting_input:gate | awaiting_input:paused` — its checkpoint references
  artifacts and resume would break. Only `done | failed | cancelled` are candidates.
- **Non-goal:** deleting checkpointer rows (LangGraph owns those; deleting a terminal run's thread
  is a separate, later concern — document, don't do here).

### A.3 Design
Extend `genesis/config/retention.py` with a pure planner + an executor:
```python
def prunable_runs(runs: list[RunRecord], *, keep_last: int, max_age_days: int, now=None) -> list[str]:
    """Return run_ids eligible for purge: TERMINAL only, then (keep_last: all but the N most
    recent terminal runs) UNION (max_age_days: terminal runs older than N days). 0 disables a
    dimension. Never includes a non-terminal run."""

class RetentionService:
    def __init__(self, store: RunStore, eventlog: EventLog, workspace_root: Path, settings): ...
    def plan(self) -> RetentionPlan            # {run_ids, event_rows_est, bytes_est}
    def apply(self, run_ids: list[str]) -> RetentionResult  # eventlog.purge + blackboard rm; guarded
```
- `apply` re-checks each run's status **immediately before** purge (defensive against a run that
  transitioned since planning) and skips non-terminal ones.
- Purge = `EventLog.purge(run_id)` + remove the run's blackboard dir (existing artifact retention),
  optionally delete the `runs` row (config flag; default keep the row as a tombstone so history/UX
  isn't confused — recommended: keep the `runs` row, purge only events+artifacts).

### A.4 Triggers
1. **Manual (primary):** API `POST /api/config/retention/apply` (+ `GET /api/config/retention/plan`
   for a dry-run preview) → surfaced in **Settings → Storage** (a "Reclaim space" panel showing the
   plan then applying). Reuses the existing `StorageSection`.
2. **On startup (opt-in):** if `GENESIS_RETENTION_ON_START=1`, run `apply(plan())` once at
   `RunManager` init. Off by default (explicit, non-surprising).
3. (Deferred) a periodic timer — not needed for single-user; documented as a follow-on.

### A.5 Files / tests
- `genesis/config/retention.py` — `prunable_runs`, `RetentionService`.
- `genesis/api/app.py` — `GET/POST /api/config/retention/{plan,apply}`.
- `web/.../settings/components/StorageSection.tsx` — plan preview + apply (with confirm).
- `tests/test_retention.py` — **safety test**: a `running`/`awaiting` run is never in `prunable_runs`
  even when older than `max_age_days`; keep_last/age math; `apply` skips a run that flipped
  non-terminal between plan and apply.
- **DoD:** the safety test is mandatory; `pytest`+`ruff` + web gates green.

---

## Part B — Event-bus consolidation

### B.1 Problem (verified)
`RunManager` (`genesis/runs/manager.py`) maintains **two** in-memory live buses plus the durable
log:
- `_buses` — **legacy** bus feeding the **interim** UI (`Event(NODE|CUSTOM|AWAITING|FINAL|ERROR)`).
- `_cbuses` — the **canonical** bus (07-02 §3) feeding the new UI (`_log()` publishes here).
- `EventLog` — durable persistence.

Every worker event is handled twice (legacy `bus.publish(...)` **and** `self._log(...)`). The
interim UI (and its `static/` bundle) is slated for retirement at the **07-10 cutover**.

### B.2 Goal
After the cutover (new UI is the only consumer), **remove `_buses` and the legacy `Event`
kinds/paths**, leaving `_cbuses` (live) + `EventLog` (durable) as the single event model.

### B.3 Design
- In `_spawn.on_event`, drop every `bus.publish(...)` call; keep the `self._log(...)` canonical
  writes and `store.set_status` updates. `on_exit` closes only `cbus`.
- Remove `RunManager.bus()`, `events()` (legacy history) and the `_buses` dict; keep `cbus()`,
  `log_events()`, `steps()`.
- Remove the legacy `Event` kind constants that are now unused (`genesis/runs/events.py`) — keep
  `EventBus` (used by `_cbuses`).
- API: the interim `GET /runs/{id}/stream` (legacy bus) and `GET /runs/{id}/events` (legacy
  history) are removed **iff** nothing but the retired UI used them; the canonical
  `/runs/{id}/events` (durable log) + `/runs/{id}/events/stream` remain. **Verify** the new UI only
  uses the canonical endpoints before deleting (grep the web client).

### B.4 Sequencing / safety
- **Gate:** do Part B **only at/after the 07-10 cutover** (when `static/` interim UI is deleted).
  Doing it earlier breaks the interim UI still shipped in `static/`.
- Confirm via `web/src/lib/api/runs.ts` that the new client calls only the canonical routes
  (it does, per 07-07/08 — `events(id, after)` + the named SSE stream), then remove the legacy paths.

### B.5 Files / tests
- `genesis/runs/manager.py` — remove `_buses`, legacy publishes, `bus()`, `events()`.
- `genesis/runs/events.py` — prune unused legacy kinds.
- `genesis/api/app.py` — remove legacy stream/history routes (post-verify).
- `tests/test_runs.py`, `test_dataplane.py`, `test_api.py` — update to the canonical-only model;
  assert a run still produces the full durable timeline + live `cbus` stream.
- **DoD:** single event path (grep shows no `_buses`); all run/HITL/streaming tests green;
  Run-Detail live + reload still correct (manual).

---

## Estimate
Part A ~0.5 day (planner + service + API + Storage panel + safety test). Part B ~0.5 day (mechanical
removal + test updates), **scheduled at the 07-10 cutover**. Backend-only releases.
