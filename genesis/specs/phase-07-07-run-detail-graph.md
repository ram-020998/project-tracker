# Phase 7.7 — Run Detail: Graph Visualization & Orchestration State

> **Goal:** Build the heart of the product — the Run Detail screen and its live
> **workflow graph**. Replace the JSON-dump experience with an interactive diagram
> that shows every node, lights up the node currently executing, colors past/failed/
> gated nodes, and lets the user click any node to inspect it. This doc covers the
> screen scaffold, the graph canvas, the node-status model, the timeline, and
> telemetry; node inspection/conversation (07-08), HITL (07-08), and documents
> (07-09) plug into the layout defined here.

Prereq: 07-02 (topology, events, steps, gate), 07-03 (design system) + 07-03a (visual
language). Feature dir: `features/run-detail/`. Routes: `/runs/:runId` (+ nested
`/node/:nodeId`, `/docs/:docName`).

> **Visual update (per `phase-07-03a`):** the React Flow custom nodes use the
> **NodeCard** aesthetic derived from Overcut's workflow-builder canvas — a title bar
> (kind icon + label + StatusPill), config-summary lines, and counters/colored dots —
> but Genesis makes them **live** (status overlay + current-node pulse), which Overcut
> does not. Run Detail also gains a **Dashboard sub-tab** using **MetricCards**
> (Overcut's per-workflow dashboard applied to a single run's telemetry: duration,
> tokens, tool calls, retries) alongside the Graph, Inspector, and Docs regions.

---

## 1. Objective & user story

"As a user watching a run, I see the whole workflow as a diagram. I can tell at a
glance where it is, what's done, what failed, and where it's waiting for me. I click
a node to see what happened there. When it needs my approval, the control is right
there."

---

## 2. Screen layout

A resizable three-region layout (design-system `SplitPane` + `Drawer`):

```
┌───────────────────────────────────────────────────────────────┐
│ Topbar: ⟵ Runs / ERD Generation · r-… · ● Running · [Docs ▸]    │
├───────────────────────────────────────────────┬───────────────┤
│                                                 │  Documents     │
│              GRAPH CANVAS (React Flow)          │  drawer        │
│         nodes with live status + current        │  (07-09,       │
│              node highlighted                   │  collapsible)  │
│                                                 │               │
├───────────────────────────────────────────────┴───────────────┤
│  NODE INSPECTOR (resizable bottom panel)  — 07-08              │
│  [ Conversation | Inputs/Outputs | Validation | Raw ]          │
│  + contextual HITL bar when the run/node awaits input          │
└───────────────────────────────────────────────────────────────┘
```

- **Header** (Topbar): breadcrumb, workflow name, run id (copy), StatusPill,
  Duration, a global **HITL affordance** (pulses when `awaiting_input:gate`), and a
  Documents toggle.
- **Graph** center; **Inspector** bottom (default) or right (user pref, persisted).
- **Documents** right drawer, collapsible.
- Empty inspector prompt: "Select a node to inspect."

---

## 3. Data sources & hydration

On mount:
1. `useRun(runId)` — record incl. `status`, `cursor`, `gate`.
2. `useWorkflowGraph(workflowId)` — topology (nodes/edges) for the canvas.
3. `useRunEvents(runId)` — **hydrate** the full event log (`GET /events`), then
4. **tail** via the SSE bridge (`/stream?after=<lastSeq>`), reconciling into the
   `['run',id,'events']` cache. On terminal, socket closes; on a gated/terminal run
   opened later, hydration alone is sufficient (no live socket needed).
5. `useRunSteps(runId)` — per-node summary for the timeline (lazy/secondary).

This is the concrete application of 07-01 §4.4 and directly relies on 07-02's durable
log — so the screen is fully correct after a reload or server restart.

---

## 4. Node-status model (client-side fold)

Compute each node's status by folding events over topology (memoized selector
`deriveNodeStates(topology, events, run)`):

| Node state | Trigger | Visual |
|---|---|---|
| `pending` | no event yet | muted, dashed border |
| `running` | `node.started` (latest, no completion) or `run.cursor==node` | primary, animated ring |
| `ok` | `node.completed` | success check |
| `failed` | `node.failed` / `error` scoped to node | danger, error icon |
| `awaiting` | `gate.awaiting` at node | warning, pulsing badge "Needs you" |
| `retrying` | `retry.scheduled` at node | warning, retry icon + attempt n |
| `skipped` | terminal run, never entered | neutral |

- Per-node live counters (from events): message count, tool-call count, attempt —
  shown as small chips on the node.
- The current node (`run.cursor`) gets the strongest emphasis + auto-centers once.

---

## 5. Graph canvas (React Flow / `@xyflow/react`)

- **Custom node component** per kind (program/agent/cli/validator/gate/subgraph):
  KindBadge icon, label, StatusPill, counters; gate nodes render distinctly (diamond
  or badged) and show a "Needs you" chip when awaiting.
- **Edges**: directed; conditional edges (e.g. gate `approve`/`feedback`) labeled;
  the active path can be subtly emphasized. Animated edge into the running node.
- **Auto-layout**: deterministic left-to-right (or top-down) layout via `dagre`
  (or `elkjs`) computed from topology; user can pan/zoom; layout cached in
  `run-view` store. Fit-to-view control + minimap for large graphs.
- **Interaction**: click a node → select it (updates `run-view.selectedNode` and
  navigates to `/runs/:runId/node/:nodeId`), opening the Inspector (07-08). Hover →
  tooltip with status + counters. Keyboard: nodes are focusable buttons; arrow keys
  move selection along edges; Enter opens inspector.
- **Performance**: memoized nodes; only changed nodes re-render on event ticks;
  target 60fps at ≥100 nodes; virtualization/минimap for very large graphs.
- **Static mode**: the same renderer runs read-only in Catalog workflow-detail
  (07-05) with all nodes `pending`.
- **Accessibility**: a synced **list/outline view** of nodes (same statuses) as an
  a11y-friendly and small-screen alternative to the canvas; toggle in the toolbar.

---

## 6. Timeline & telemetry (secondary panels)

- **Timeline** (collapsible): chronological node entries from `/steps` — node, kind,
  status, duration, attempts, tool-calls, messages; click scrolls the canvas to that
  node and opens the inspector. This is the linear counterpart to the spatial graph.
- **Telemetry strip**: MetricTiles from the run's `telemetry` state (e.g. tokens,
  tool calls, retries, elapsed) + a small Recharts timeline of activity. Sourced from
  `telemetry` events / run state.

---

## 7. Live update UX

- Node status transitions animate (respecting reduced-motion); a subtle toast/inline
  marker when the run transitions to `awaiting_input:gate` ("Approval needed") that
  scrolls the gate node into view and surfaces the HITL bar (07-08).
- Terminal transition (done/failed) updates the header StatusPill and stops polling.
- A "live" indicator in the header shows the SSE connection state (live / reconnecting
  / replaying history / closed).

---

## 8. States

- **Loading**: graph skeleton (placeholder nodes) + inspector skeleton.
- **Empty/early**: run just started, no events yet → "Waiting for the first step…"
  with the topology already drawn (all pending).
- **Error**: run fetch/topology error → ErrorState with retry; a partial error
  (events failed but record ok) degrades gracefully to record-only.
- **Terminal**: full graph with final statuses; inspector fully browsable from the log.

---

## 9. Data & hooks

- `useRun`, `useWorkflowGraph`, `useRunEvents` (hydrate+tail), `useRunSteps`,
  selectors `deriveNodeStates`, `useSelectedNode` (route-driven).
- SSE bridge lives in `lib/sse` and writes into the events query cache; the screen
  subscribes via `useRunStream(runId)`.

---

## 10. Definition of done

1. Run Detail renders the workflow as an interactive React Flow graph from topology.
2. Node statuses (incl. current-node highlight, retries, gate) are accurate, live,
   and correct after reload/restart (durable-log hydration).
3. Clicking/keyboarding a node selects it and opens the inspector (deep-linkable
   `/node/:nodeId`); an accessible list view mirrors the canvas.
4. Timeline + telemetry panels render from `/steps` and telemetry.
5. Live/replaying/closed connection state is visible; transitions animate
   (reduced-motion honored).
6. All states designed; component tests with a scripted event fixture assert the
   node-status fold and current-node highlight.
