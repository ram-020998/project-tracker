# Progress: P0 02 — Overview Dashboard

**Spec:** `specs/phase-07-code-review-fixes/02-p0-overview-dashboard.md`
**Delivered in:** genesis v0.12.1 (commit `fdeb8dc`, tag `v0.12.1`)
**CI:** pipelines #6328357 (master) + #6328356 (tag) — both SUCCESS
**Date:** 2026-07-11

---

## Summary

Replaced the static Overview placeholder with a live dashboard driven by `GET /api/home`.
Extended the `/home` endpoint to return aggregate metrics, a 14-day trend series, active-run
summaries, per-integration health status, and installed workflow metadata — all computed from
existing stores with O(1)-in-queries performance.

---

## Deliverables

### 1. Backend (`genesis/api/home.py`)

Pure `build_home(manager, config, loader)` aggregator:
- **Metrics:** total_runs, active, succeeded, failed, success_rate, avg_duration_ms, tokens (null),
  tool_calls (from new `EventLog.aggregate_tool_calls` batch query).
- **Trend:** 14-day buckets (date/runs/succeeded/failed) from runs bucketed by `created_at`.
- **Active runs:** non-terminal runs (cap 20) with workflow_name enriched from loader.
- **Integrations:** MCP (ok/missing_secret), CLI (available/missing), GitLab token (ok/missing).
- **Installed:** id/version/name/roles from `loader.installed()`.

`EventLog.aggregate_tool_calls(run_ids)`: single indexed `GROUP BY run_id` query.

### 2. Frontend (`features/overview/`)

| File | Purpose |
|------|---------|
| `types/home.ts` | TypeScript types mirroring the backend response |
| `lib/api/home.ts` | API resource (`homeApi.get()`) |
| `lib/query/keys.ts` | Added `home` key |
| `features/overview/hooks.ts` | `useHome()` — TanStack Query, 15s refetch |
| `features/overview/OverviewPage.tsx` | Full dashboard: MetricCards, TrendChart, ActiveRuns strip, Integrations chips, Installed workflows grid |
| `features/overview/overview.test.tsx` | 6 vitest tests |
| `app/router.tsx` | Index route → `OverviewPage` |
| `app/routes/Overview.tsx` | Trimmed to `ComingSoon` only |

### 3. Design decisions

- **Date-range filtering is client-side v1** (spec §3.4): the 14-day trend + all metrics are
  returned, and the SegmentedControl (Today/7d/30d/All) filters the trend client-side.
- **tokens = null** until the SDK surfaces usage credits (honest, per spec §3.1).
- **tool_calls** always available via the batched `aggregate_tool_calls` query.

---

## Evidence

```
# Backend
$ pytest -q -p no:warnings
75 passed in 14.87s

$ ruff check genesis
All checks passed!

# Frontend
$ npm run lint       → 0 errors, 9 pre-existing warnings
$ npm run typecheck  → clean
$ npm test           → 9 files, 59 tests passed
$ npm run build      → ✓ built in 6.39s

# CI
Pipeline #6328357 (master): SUCCESS
Pipeline #6328356 (v0.12.1): SUCCESS
```

---

## What's NOT verified (honest disclosure)

- **Live browser verification:** not performed headlessly. The wiring is structurally correct
  (the existing `test_api.py` confirms `/home` returns the expected shape, and the vitest
  confirms the component renders from that data via MSW). A manual `genesis serve` + browser
  check would confirm the visual rendering.

---

## Next

P1 03 — Integrations Studio (`03-p1-integrations-studio.md`): two-tier MCP/CLI registry
(curated + custom-writable), CRUD API, JSON code editor, tool introspection + allowlist.
Or P1 06 — Conversation rich-chat (`06-conversation-rich-chat.md`): unified Thinking timeline +
markdown rendering in the Run-Detail Conversation tab.
