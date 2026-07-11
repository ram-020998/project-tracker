# Phase 7.6 — Runs List & History

> **Goal:** A single, fast surface to see all workflow runs — active and historical —
> with live status, meaningful filtering/search, quick actions, and a clear path into
> each run's detail. This is the operator's "mission control" list.

> **API paths (ADR-028):** endpoints referenced here are served under **`/api`** (the
> `lib/api` client prepends it centrally); non-`/api` paths hit the SPA history fallback.

Prereq: 07-02 (runs + status), 07-03 (design system) + 07-03a (visual language).
Feature dir: `features/runs/`. Route: `/runs`.

> **Visual (per `phase-07-03a`):** mirrors Overcut's **Executions** table — FilterBar
> with removable chips + "Add filter", an **AutoRefreshChip**, count + pagination, and
> **StatusPill** cells — plus Genesis additions (current-node column + a progress bar).

---

## 1. Objective & user story

"As a user, I want to see everything that's running now and everything that ran
before, filter to what I care about, spot failures and pending approvals instantly,
and jump into any run."

---

## 2. Layout

- **Header/Toolbar**: title, count, `New run` (→ Catalog), refresh indicator.
- **FilterBar**: search (workflow id / run id); status filter (Running /
  Awaiting input / Done / Failed / Cancelled / All); workflow filter; date range;
  sort (newest / longest / status).
- **Two logical groups** (toggle or stacked sections):
  - **Active** — non-terminal runs (running, awaiting_input:gate/paused). Emphasized;
    live-updating.
  - **History** — terminal runs (done/failed/cancelled), paginated.

## 3. Run row / card

A dense table (default) with an optional card view:

| Col | Content |
|---|---|
| Status | StatusPill (animated when running; amber "Approval needed" when gated) |
| Workflow | name + version |
| Run | short run id (copyable) |
| Current node | `cursor` (or "—") |
| Progress | steps done / total (from `/steps` or topology fold) with a thin bar |
| Started | RelativeTime |
| Duration | Duration (live for running) |
| Actions | Open · (running) Pause/Cancel · (gate) Review → deep-links to gate |

- Row click → `/runs/:runId`. "Review" on a gated run deep-links to the run with the
  HITL panel focused.
- Quick actions use ConfirmDialog for Cancel; optimistic + toast.
- **Attention surfacing**: gated and failed runs are visually prioritized (badge,
  subtle row tint) and can be pinned to top via the default sort.

## 4. Live behavior

- `useRuns(filters)` (TanStack Query) with `refetchInterval` 3s **only while any
  active run exists**; stops when all terminal.
- No per-row SSE (would be many sockets); the list polls the cheap `/runs` endpoint.
  Live token-level detail is reserved for Run Detail's single SSE.
- New runs appear on next poll; status transitions animate the pill.

## 5. States

- **Loading**: skeleton rows.
- **Empty**: "No runs yet — launch one from the Catalog" with a primary action; a
  distinct empty for a filtered result ("No runs match these filters — clear").
- **Error**: inline retry.

## 6. Pagination & performance

- History paginated (server `limit/offset` already supported; add `total` header or
  count if needed). Virtualize if a page is large.
- Column sort client-side within a page; status/workflow filters server-side.

## 7. Data & hooks

- `useRuns({status, workflow, range})`, `useRunSteps(id)` (for progress, lazy),
  mutations `usePauseRun`, `useCancelRun` (invalidate `['runs']`).
- Derived selectors: `activeRuns`, `historyRuns`, `attentionRuns` (gated/failed).

## 8. Definition of done

1. Runs list shows active + history with accurate live status and progress.
2. Filters (status/workflow/search/date) and sort work; gated/failed runs surfaced.
3. Quick actions (open/pause/cancel/review) work with confirmation + toast.
4. Polling is scoped to active runs only; terminal lists are static.
5. States designed; component + MSW tests for filtering, live status, and actions.
