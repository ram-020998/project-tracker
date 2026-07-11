# Genesis — Phase 7.6 (Web Revamp: Runs List & History) Implementation Record

> As-built record of `specs/phase-07-06-runs-list-and-history.md`. Frontend-only —
> the `/runs` list + pause/cancel endpoints already existed. Part of milestone M7.1.

**Date:** 2026-07-11 · **Status:** ✅ COMPLETE — committed `0cbf6f1` (27 web tests,
tsc strict, **frontend + genesis CI green**). No backend change (genesis stays v0.10.0).
Build-alongside (served `static/` untouched — cutover 07-10).

---

## 1. Summary

`/runs` is now the operator's mission-control list: Active and History sections with
live status pills, current node, duration, filters (search / status / workflow / sort),
and quick actions (open / pause / cancel-with-confirm / review-a-gate). Polling is scoped
to active runs. Reuses `types/run.ts` + the `lib/api`/`lib/query` layer.

---

## 2. Frontend (`genesis/web/features/runs/`)

- **`lib/api/runs.ts`** — `runsApi` (list with `status`/`workflow` query, get, steps,
  pause, cancel) + `RunsFilter` (re-exported from the api barrel). `lib/query/keys.ts`
  gained `runs.list(filters)` + `runs.steps(id)`.
- **`hooks.ts`** — `useRuns(filter)` with a **`refetchInterval` that returns 3000 only
  while any run is non-terminal** and `false` once all terminal (spec §4); `usePauseRun`/
  `useCancelRun` (invalidate `['runs']` + toast); status predicates `isActive`/`isGated`/
  `isAttention` and `runDurationMs` (live for active runs, final span for terminal).
- **`RunsPage.tsx`** — toolbar (run count, `New run` → Catalog, AutoRefreshChip while
  polling); filter bar (search, status SegmentedControl, workflow `<select>`, sort);
  **Active (N)** and **History (N)** sections; empty (no runs) + filtered-empty (clear)
  + loading + error states; a Cancel ConfirmDialog.
- **`components/RunsTable.tsx`** — dense table: StatusPill (animated running / amber
  "Approval needed"), workflow + version, copyable short run id, current node (`cursor`),
  RelativeTime started, live Duration, and right-aligned actions (Review for gated, Pause
  for running, Cancel for any active, Open). Rows are click-through to `/runs/:id`;
  attention rows (gated/failed) get a subtle tint. Action cells `stopPropagation`.
- **Tests (`runs.test.tsx`, MSW):** active/history split + statuses, status filtering,
  pause action, and cancel-after-confirm.
- Router: `/runs` → `RunsPage` (replaced the placeholder).

---

## 3. Verification

- `tsc --noEmit` strict clean; `vitest run` **27 passed** (14 ds + 5 settings + 4 catalog
  + 4 runs); temp `vite build` OK; `git status` confirms `static/` unchanged. Frontend +
  genesis CI **success** (commit `0cbf6f1`).

---

## 4. Decisions & honest deviations

- **Filters applied client-side over a full `/runs` fetch.** The backend supports
  server-side `status`/`workflow`, but fetching all runs and filtering client-side keeps
  the **Active/History split** coherent and is trivially cheap at local single-user scale.
  If run volume ever grows, switch the status/workflow filters to server-side + paginate.
- **Progress column = current node + status, not a precise step bar.** A per-row step
  count would require an N+1 `/steps` fan-out (or a topology fold per run). To keep the
  list fast we show the current node (`cursor`) + an animated running pill; a precise
  percentage bar is deferred (best served by adding `steps_done/total` to the `/runs`
  record or a batch endpoint).
- **Pagination** is not yet added (History renders in full). Local run counts are small;
  virtualization/pagination is a follow-on if needed (spec §6 allows it as optional).
- Cancel confirm button is labeled **"Yes, cancel"** to avoid an accessible-name clash
  with the row's "Cancel run" action.

---

## 5. Definition of done (07-06) — status

1. Active + history with live status and progress (current node + live pill) — ✅
   (precise step-count bar deferred, see §4).
2. Filters (status/workflow/search/sort) work; gated/failed surfaced (tint + sort) — ✅.
3. Quick actions (open/pause/cancel/review) with confirm + toast — ✅.
4. Polling scoped to active runs only; terminal lists static — ✅.
5. States designed; component/MSW tests for filtering, live status, actions — ✅.

---

## 6. Next

07-07 (Run Detail — Graph Visualization) — the centerpiece: React Flow live node-status
graph from `/workflows/{id}/graph` + an `/events` fold. This also delivers the interactive
graph renderer that retro-fits the 07-05 catalog detail's static `GraphPreview`.
