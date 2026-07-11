# Genesis — Phase 7.7 (Web Revamp: Run Detail — Graph Visualization) Implementation Record

> As-built record of `specs/phase-07-07-run-detail-graph.md` — the centerpiece screen.
> Frontend-only (data plane shipped in 07-02). Part of milestone M7.1.

**Date:** 2026-07-11 · **Status:** ✅ COMPLETE — committed `af04e7b` (32 web tests,
tsc strict, **frontend + genesis CI green**). No backend change (genesis stays v0.10.0).
Build-alongside (served `static/` untouched — cutover 07-10).

---

## 1. Summary

`/runs/:runId` is now the live Run Detail: an interactive **React Flow** workflow graph
that lights up node-by-node from the durable event log, an accessible list mirror, a
timeline + telemetry strip, and a resizable inspector region — correct after reload/
restart via durable-log hydration, with an SSE tail for live updates. Node inspection
detail (07-08) and the documents drawer (07-09) plug into the layout defined here.

New deps (public npm): **@xyflow/react@12.3.5**, **@dagrejs/dagre@1.1.4**.

---

## 2. Node-status fold (`node-states.ts`)

`deriveNodeStates(topology, events, run)` — a pure, memoized selector mirroring the
server `steps()` counters (tool_calls / messages / attempts) and resolving each node to
`pending | running | ok | failed | awaiting | retrying | skipped`. Key realities of the
07-02 event model baked in:

- There is **no `node.started`/`node.failed`** event. "running" therefore derives from
  **`run.cursor`**; a node failure is **attributed to the cursor** on a `failed` run; a
  gated run marks the cursor `awaiting`.
- `node.completed` → ok; `gate.awaiting` → awaiting; `retry.scheduled` → retrying (+attempt);
  `error` → failed; `agent.*` bumps counters and lifts pending→running.
- On a terminal run, never-entered nodes become `skipped` (not `pending`).

Unit-tested with scripted fixtures (running/skipped/failed/awaiting + current-node flag).

---

## 3. Data & live updates (`hooks.ts`, `lib/sse` inline)

- `useRun(id)` (polls 3s while active), `useRunEvents(id)` (hydrates `GET /events`),
  `useRunSteps(id)` (timeline/telemetry, polls while a step runs).
- **`useRunStream(id, onState)`** — opens `EventSource` to `/api/runs/{id}/events/stream?after=<lastSeq>`,
  reconciles new events into the `['run',id,'events']` cache (dedupe by seq), and closes
  on `run.final`. **The server sends _named_ SSE events (`event: <kind>`),** so the hook
  registers the handler per known kind (not just `message`). Guarded to a no-op under
  jsdom (no `EventSource`) — hydration alone is correct for terminal/gated runs (durable log).

---

## 4. Graph canvas (`graph/`)

- `layout.ts` — deterministic **dagre** left-to-right layout, computed **once per topology**;
  per-tick derived status is injected into node `data` without re-layout.
- `NodeCard.tsx` — memoized custom React Flow node: kind icon + label + StatusPill +
  counters (attempts/tool-calls/messages); gate nodes bordered distinctly; running/awaiting/
  failed get a status ring; current node pulses.
- `RunGraph.tsx` — `ReactFlow` + Background + Controls + MiniMap; read-only (nodes not
  draggable); click → select; animated edge into the running node; a **static mode**
  (`states={}`) reused by the Catalog workflow-detail Graph tab.

---

## 5. Layout, panels, and the page (`RunDetailPage.tsx`)

- Full-height header: back-to-runs, workflow + copyable run id, StatusPill + live Duration,
  a **live/replaying/closed** connection chip, a Graph/List view toggle, and a Documents button.
- `SplitPane` (vertical): graph (or list+timeline) on top, **Inspector** below.
- **List view** (`NodeListView`) — accessible, keyboard-first mirror of the graph with the
  same statuses; shown alongside the Timeline + TelemetryStrip.
- **Timeline / TelemetryStrip** (`Timeline.tsx`) — from `/steps`: per-node rows + MetricCards
  (elapsed, tool calls, messages, retries).
- **Inspector** (`Inspector.tsx`) — interim: selected node's status, counters, and raw event
  stream + a note that the rich tabs land in 07-08.
- `stores/run-view.ts` — Zustand slice (view mode, inspector position/open, docs open).
- Router: `/runs/:runId` and `/runs/:runId/node/:nodeId` → `RunDetailPage` (node selection is
  route-driven + deep-linkable).

---

## 6. Verification

- `tsc --noEmit` strict clean; `vitest run` **32 passed** (added 5: 4 fold cases + 1
  NodeListView render); temp `vite build` OK; `git status` confirms `static/` unchanged.
  Frontend + genesis CI **success** (commit `af04e7b`).

---

## 7. Decisions & honest deviations

- **Inspector body + HITL bar are placeholders** — the layout slot is built; the
  Conversation/Inputs-Outputs/Validation/Raw tabs and the gate/approve controls are 07-08.
- **Documents drawer is a placeholder** — the toggle + side-sheet exist; artifact list +
  preview are 07-09.
- **Telemetry is folded from `/steps`**, not from `telemetry` events (cheaper, no extra
  stream); a richer Recharts activity timeline can come later.
- **React Flow canvas is not asserted in jsdom** — it needs real layout/dimensions, so the
  DoD's fold + current-highlight coverage is via the pure `deriveNodeStates` unit tests +
  the `NodeListView` render (which mirrors the same statuses).
- Benign Radix "DialogContent missing Description" console warning (non-failing); can add
  `aria-describedby` in a later polish pass.

---

## 8. Definition of done (07-07) — status

1. Interactive React Flow graph from topology — ✅.
2. Node statuses accurate/live + correct after reload (durable-log hydration) — ✅.
3. Click/keyboard node select → inspector, deep-linkable `/node/:nodeId`; accessible list
   mirror — ✅ (arrow-key edge traversal is a follow-on; list + click/Enter work).
4. Timeline + telemetry from `/steps` — ✅.
5. Live/replaying/closed indicator; animated transitions (reduced-motion honored) — ✅.
6. Node-status fold + current-highlight component tests with scripted fixtures — ✅.

---

## 9. Next

07-08 (Node Inspection, Kiro Conversation & HITL) — fills the Inspector with the per-node
conversation transcript (agent.* events) + Inputs/Outputs/Validation/Raw tabs, and adds the
HITL bar (approve/reject/feedback/pause/resume/cancel/fork) driven by the durable gate.
