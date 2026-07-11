# 02 — P0: Overview Dashboard (wire `/home` + extend it)

**Priority:** P0 · **Layers:** `genesis` (extend `/home`) + `web` (wire the screen) ·
**Depends on:** none (independent of `01`) · **Implements:** the screen defined in `spec 07-01 §7`.

> Goal: replace the static Overview placeholder with a live dashboard driven by `GET /home`,
> and extend `/home` with the aggregate metrics, active-run summaries, per-integration health,
> and trend series the screen needs.

---

## 1. Problem (current state, verified)

- **`web/src/app/routes/Overview.tsx`** is a **static placeholder**: a hardcoded `TREND` array,
  `MetricCard`s showing `"—"`, and an "Overview is a work in progress" `EmptyState`. It calls **no
  API**. Its own comment: *"Real data wiring (GET /home) lands with the Overview spec work
  (phase-07-01 §7)."*
- **`GET /api/home`** (`genesis/api/app.py`) **exists** but is minimal:
  ```python
  return {"installed": [{id, version, name} …], "recent_runs": [_record(r) …][:10],
          "health": [c.__dict__ for c in config.health()]}
  ```
- Components already exist in `shared/ui`: `MetricCard`, `TrendChart`, `SegmentedControl`,
  `AutoRefreshChip`, `Card`, `EmptyState`. So this is **wiring + a backend extension**, not new UI primitives.

The screen was defined in `07-01 §7` but never implemented (the sub-series went 07-03 → 07-10).

---

## 2. Goals / Non-goals

**Goals**
1. Extend `GET /home` to return everything the dashboard needs in **one call**: aggregate metrics,
   a trend series, active-run summaries, per-integration status, and installed workflows.
2. Wire `Overview.tsx` to `/home` via a TanStack Query hook (`useHome`) polling every 15s, with
   loading/empty/error states.
3. Render, per `07-01 §7`: a **date-range** segmented control + auto-refresh chip; a
   **MetricCards** grid; a **TrendChart**; an **active-runs strip**; an **integrations-health
   strip**; an **installed-workflows** grid with quick-launch.

**Non-goals**
- No new charting library (reuse `TrendChart`/Recharts already in the stack, ADR-027).
- No historical warehouse — metrics are computed on demand from the runs table + event log.
- `credits`/tokens remain **best-effort** (honest `null` when the SDK doesn't surface usage — see
  `state-and-data-model.md §1.4`).
- Date-range filtering may be **client-side v1** over the returned window (see §3.4) — server-side
  range params are an optional enhancement.

---

## 3. Backend — extend `GET /home`

### 3.1 New response shape
```jsonc
{
  "metrics": {
    "total_runs": 42,            // all runs (or within range if range param honored)
    "active": 3,                 // non-terminal (pending/running/awaiting/paused)
    "succeeded": 30, "failed": 6,
    "success_rate": 0.833,       // succeeded / (succeeded + failed); null if denom 0
    "avg_duration_ms": 61000,    // mean(updated_at - created_at) over terminal runs; null if none
    "tokens": null,              // sum telemetry._run.credits when available, else null (best-effort)
    "tool_calls": 128            // sum telemetry._run.tool_calls across runs (cheap, always available)
  },
  "trend": [ { "date": "2026-07-05", "runs": 3, "succeeded": 2, "failed": 1 }, ... ],  // last 14 buckets
  "active_runs": [
    { "run_id": "...", "workflow_id": "...", "workflow_name": "...", "status": "running",
      "cursor": "assign_domains", "created_at": "...", "updated_at": "..." }
  ],
  "integrations": [
    { "name": "appian-atlas", "kind": "mcp", "status": "ok|missing_secret|error", "detail": "..." },
    { "name": "erd-gen", "kind": "cli", "status": "available|missing", "detail": "..." },
    { "name": "gitlab", "kind": "token", "status": "ok|missing" }
  ],
  "installed": [ { "id": "...", "version": "...", "name": "...", "roles": [...] } ]
}
```

### 3.2 Computation (all from existing sources — no new tables)
Add a small pure helper module `genesis/api/home.py` (unit-testable, no FastAPI import):

```python
def build_home(manager, config, loader) -> dict: ...
```
- **runs** = `manager.list()` (RunStore). Partition by status using `store` constants
  (`DONE`, `FAILED`, `CANCELLED` = terminal; else active).
- **success_rate** = `succeeded / (succeeded + failed)` or `None` if denom 0.
- **avg_duration_ms** = mean of `iso(updated_at) - iso(created_at)` over terminal runs; `None` if none.
- **tokens / tool_calls**: fold `telemetry["_run"]` per run. `credits` is summed only when
  non-`None` for **all** contributing runs, else `tokens=None` (don't fabricate). `tool_calls`
  always summable. Source: read the run's telemetry from state via `manager.get_state(run_id)` is
  **too heavy** for a list; instead derive `tool_calls` cheaply from `manager.steps(run_id)` sums,
  or (preferred) add a lightweight `EventLog` aggregate: count `agent.tool_call` per run. **Chosen:**
  a new `EventLog.aggregate_tool_calls(run_ids)` (single indexed `GROUP BY run_id` query) to keep
  `/home` O(1) queries, not O(runs).
- **trend**: bucket runs by `date(created_at)` for the last 14 days (`succeeded`/`failed`/total).
  Single pass over the runs list.
- **active_runs**: the non-terminal runs (cap 20), enriched with `workflow_name` from `loader`.
- **integrations**: MCP from `config.health()` (already returns per-server `HealthCheck`); CLI from
  `config.cli_cards()` (`available`); GitLab from `config.gitlab_token_set()`.
- **installed**: `loader.installed()` (id/version/name/roles).

### 3.3 Route change
`@api.get("/home")` returns `build_home(manager, config, loader)`. Keep it synchronous + cheap
(bounded queries). No new dependencies.

### 3.4 Date range (v1 decision)
Return the **last-14-days trend** + all-time metrics. The segmented control (`today/7d/30d/month`)
filters **client-side** over `active_runs`/`trend`/`recent` for v1. If server-side ranges are
wanted later, add `?range=` and filter runs by `created_at` server-side (documented as an optional
follow-on, not required for DoD).

---

## 4. Frontend

### 4.1 Data layer
- `web/src/lib/api/home.ts` — `homeApi.get(): Promise<HomeData>` (typed to §3.1).
- `web/src/lib/query/keys.ts` — add `home: () => ["home"] as const`.
- `web/src/features/overview/hooks.ts` — `useHome()` = `useQuery({ queryKey: keys.home(),
  queryFn: homeApi.get, refetchInterval: 15_000 })`.
- Types in `web/src/types/home.ts` mirroring §3.1.

### 4.2 Screen (`web/src/features/overview/OverviewPage.tsx`)
Move the route target from `app/routes/Overview.tsx` to a real feature module (keep `ComingSoon`
where it is for the `*` route). Compose:
- **Toolbar row:** `SegmentedControl` (date range, client-filter) + `AutoRefreshChip seconds={15}`
  (wire to query `dataUpdatedAt`).
- **MetricCards grid** (from `metrics`): Total Runs, Success Rate (`—` when `null`), Avg Duration
  (`Duration` formatter), Currently Running, Tool Calls (+ Tokens only when non-null).
- **Run trend:** `TrendChart` from `trend` (runs over time; stacked succeeded/failed optional).
- **Active runs strip:** cards for `active_runs` with live status pill + "jump in" link to
  `/runs/:runId`. Empty → a subtle "no active runs" state.
- **Integrations health strip:** compact green/amber/red chips from `integrations`, each linking to
  `/settings/:server` (MCP) or `/settings` (CLI/GitLab).
- **Installed workflows:** grid/list from `installed` with a quick **Launch** → `/catalog/:id/launch`;
  getting-started `EmptyState` when none installed.
- **States:** `LoadingState` skeleton while `isLoading`; route error boundary already exists;
  empty (fresh install) shows the getting-started guidance.

### 4.3 Router
`web/src/app/router.tsx`: change `index: true` element from the placeholder `Overview` to the new
`OverviewPage`. Keep `ComingSoon` for `*`.

---

## 5. Files touched

| File | Change |
|------|--------|
| `genesis/api/home.py` | **new** — pure `build_home()` aggregator |
| `genesis/api/app.py` | `/home` returns `build_home(...)` |
| `genesis/runs/eventlog.py` | add `aggregate_tool_calls(run_ids)` (indexed GROUP BY) |
| `tests/test_home.py` | **new** — `build_home` metric math + edge cases |
| `web/src/lib/api/home.ts`, `lib/api/index.ts` | **new** home resource + export |
| `web/src/lib/query/keys.ts` | add `home` key |
| `web/src/types/home.ts` | **new** types |
| `web/src/features/overview/{OverviewPage.tsx,hooks.ts,overview.test.tsx}` | **new** |
| `web/src/app/router.tsx` | index → `OverviewPage` |
| `web/src/app/routes/Overview.tsx` | keep `ComingSoon`; remove the placeholder `Overview` (or leave unused-safe) |

---

## 6. Testing / DoD

**Backend (`tests/test_home.py`):** with a seeded manager (fake runs across statuses + a couple of
`agent.tool_call` events): success_rate math (incl. 0-denominator → `null`), avg_duration over
terminal only, active partition, trend bucketing, `tokens=null` when any contributing run lacks
credits, integrations mapping. Assert `/home` shape via an API smoke test (MSW-free, TestClient).

**Frontend (`overview.test.tsx`, MSW):** renders metrics from a mocked `/home`; `—` for null
success rate; active-runs strip links to `/runs/:id`; integration chip links to settings; empty
install shows getting-started; auto-refresh chip present. jest-axe pass.

**DoD**
- Backend `pytest`+`ruff` green; web `tsc`+`vitest`+`build` green; `web/static/` untouched.
- Manual: with a real backend + at least one run, `/` shows live metrics, an active run appears
  while a workflow runs, and integration chips reflect Settings.

---

## 7. Risks & deviations
- **Deviation:** date-range filtering is client-side in v1 (server-side ranges deferred) — noted so
  it's a conscious choice, not a miss.
- **Honesty:** `tokens` is `null` until the SDK surfaces usage (`credits`), matching the existing
  telemetry contract; `tool_calls` is always shown.
- **Perf:** `/home` must stay O(1)-in-queries — hence `aggregate_tool_calls` batches rather than
  per-run state reads. Cap `active_runs`/`recent` lists.

## 8. Estimate
~0.5 day: `/home` extension + `build_home` + tests (2–3h); frontend wiring + tests (2–3h). One
backend release + one frontend commit.
