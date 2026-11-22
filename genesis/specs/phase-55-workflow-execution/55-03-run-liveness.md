# 55-03 — Run liveness: `node.started`, one versioned snapshot, hint SSE and the run graph

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/runs/`, `genesis/api/run_routes.py`,
> `web/src/features/run-detail/`). Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**.
> Decisions: D10, F12, F13 (`55-01-findings.md`). ADR draft: ADR-090 (`adr-drafts.md`). The web part (§5) waits for
> the user's approval of the 55-02 graph-state mockups; §1–§4 may start before.

## 0. Spike first (record the result in As built)

On the installed LangGraph (1.2.8), run a small checkpointed graph with `astream(stream_mode=["updates","custom",
"tasks"])` and record the exact `tasks` payloads (task start: `id`, `name`, `input`, `triggers`; finish: `id`, `name`,
`result`, `error`, `interrupts`) for: a straight path; a node that loops back (a retry edge); an `interrupt()` gate and
the resume with `Command(resume=…)`; a node killed mid-run (the worker killed, then a fresh worker resumes from the
checkpoint, ADR-012). Check whether `updates` ordering or `final` changes, and whether a resumed task re-emits start.
If `tasks` proves unsuitable, fall back to the worker emitting start itself around each node (record why).

## 1. Worker and events

- `genesis/runs/worker.py:170`: add `"tasks"` to `stream_mode`. On a task start emit `{"kind":"task_start","node":
  name,"task_id":id}`; keep `updates` for completions. Ignore task events of internal LangGraph nodes (`__start__`,
  writers).
- `RunManager._spawn.on_event` (`genesis/runs/manager.py:~228-262`): log a canonical **`node.started`** `{node,
  task_id}` with the node column set. Add it to `CANONICAL_KINDS` (`manager.py:51`), the web list and the golden
  fixtures, tested both ways (L-122). Update L-005 at write-back (55-12).
- Keep `runs.cursor` semantics unchanged (last completed node: `home.py`, `chat.py`, finalizers and `reconcile_status`
  read it, L-094). Fix the small race: call `note_progress` before publishing `node.completed`.
- A late event from a killed worker is still dropped (`manager.py:228-234`, L-108); a node that started and whose
  worker was killed by pause or cancel reads `paused` / `cancelled` in the snapshot, not `running`.

## 2. Snapshot fold (`genesis/runs/snapshot.py`, new)

- `RunSnapshot`: `{version, run: {status, gate, cursor, started_at, ended_at}, active_nodes: [..], nodes: {id:
  {status: pending|running|ok|failed|awaiting|paused|cancelled, executions, attempts, started_at, ended_at,
  duration_s, credits}}, edges: {"src->dst": count}, legacy: bool}`. `version` = the run's highest event `seq` (F13).
- Fold rules: `node.started` → running (also after `ok`: a loop re-entry, L-059); `node.completed` → ok, `executions`
  +1, edge from the previous completed node; `gate.awaiting` → awaiting; `gate.resolved` → running; `error` on the
  active node → failed; `run.final` paused / cancelled → the active node takes that status; credits from
  `agent.result` (metered, ADR-032).
- **Incremental:** one in-memory fold per run, keyed by the last folded `seq`; a read folds only events after it
  (`eventlog.list(after_seq=…)`), never the whole log per call (L-066). Rebuilt from the log on the first read after a
  restart; evicted on terminal + idle. Safe with two `serve` processes on one DB because the version is the seq.
- **Old runs (F12):** a run with no `node.started` event is `legacy: true`; node statuses come from today's
  `fold_steps` and no node is shown running from the cursor.
- `/steps` and `/transitions` stay for their other readers; `fold_steps` gets the same loop re-entry fix only if it
  falls out cheaply (record it).

## 3. Endpoints (added here; 55-08 owns the contract table)

- `GET /api/runs/{id}/snapshot` → `RunSnapshot`; `?since_version=N` may answer `304`-like `{unchanged: true,
  version}` to keep polls cheap.
- `GET /api/runs/{id}/live` (SSE): lifecycle hints only — `node.started`, `node.completed`, `gate.awaiting`,
  `gate.resolved`, `error`, `run.final` — each frame `id: <seq>`, `event: <kind>`, `data: {seq, node, kind}`; honours
  `Last-Event-ID` and `?after=` and **never replays the log** (a fresh connect starts at the current seq); a `ping`
  comment every 15 s; closes after a terminal `run.final` (L-003). The existing `/events/stream` stays for the
  inspector and conversation.

## 4. Transport fixes

- **Subscribers:** replace `asyncio.to_thread(next, sub)` (`run_routes.py:350-374`) with an `asyncio.Queue` per
  subscriber fed by `loop.call_soon_threadsafe`; a bounded queue (e.g. 1,000); on overflow the subscriber gets one
  `resync` frame and is dropped (the client re-fetches the snapshot); disconnect releases it at once. Shield must-finish
  cleanup in the generator (L-118).
- **Bus:** a bounded ring history per run; prune `_cbuses` after terminal (`manager.py:91,125`).
- **Pump:** `Supervisor._pump` (`runs/supervisor.py:69-90`) logs an `on_event` exception at ERROR with the event kind
  instead of swallowing it; worker stderr is drained by its own thread into the log (no blocked 64 KB pipe).

## 5. Web (after the 55-02 approval)

- `useRunSnapshot(runId)`: TanStack Query on `/snapshot`; `refetchInterval` 3 s while the run is active (any non-terminal
  status, gate and paused included), always, independent of node states; refetch on window focus, `visibilitychange`
  and `online`; drop a response whose `version` is lower than the one held.
- `useRunLive(runId)`: `EventSource` on `/live`; every hint invalidates the snapshot (coalesced to one fetch per
  250 ms); `onerror` → reconnect with backoff (1 s → 30 s) from the last seen id; close on terminal `run.final` (L-003).
  The Live badge shows **Live** only while connected, **Reconnecting…** while retrying, **Polling** otherwise.
- `RunDetailPage.tsx` / `RunGraph.tsx` / `node-states.ts`: node status only from the snapshot; remove `runningNode =
  run.cursor` (`RunDetailPage.tsx:97`) and `running = edge.target === runningNode` (`RunGraph.tsx:87`); an edge is
  lit when its target is running and its source has executed; traversed edges from `snapshot.edges`. Remove the dead
  loop heuristic and the `after=0` `useRunStream` replay from the graph path. The Refresh control refetches the
  snapshot. A running node shows its elapsed time; a loop node shows "round k".
- The layout still re-runs only on topology change (L-067); level-of-detail unchanged (L-034).

## 6. Tests

- Worker: `tasks` events → `node.started` for a straight path, a retry loop, a gate + resume, a kill + resume
  (from §0's real payloads, not invented ones).
- Fold: each rule in §2; a 30k-event fixture folds incrementally (time bounded); legacy run; two-reader version
  monotonic.
- SSE: `id:` frames, `Last-Event-ID` resume, no replay, overflow → `resync`, a cancelled task group cleans up (L-118),
  CRLF framing in the client reader (L-018).
- Web: node and edge states per graph state of 55-02; a lower version ignored; reconnect; badge states; jest-axe.
- Contract: kinds list parity both ways (L-122); fixtures from real responses (L-011).

## 7. Gates

genesis pytest + ruff; web lint, typecheck, test; `npm run build`, then commit `web/static/` separately (L-089).

## Context manifest

```toml
areas    = ["runs-worker", "web-runs", "api"]
adrs     = ["ADR-009", "ADR-012", "ADR-024", "ADR-028", "ADR-032", "ADR-066"]
lessons  = ["L-003", "L-005", "L-011", "L-018", "L-034", "L-059", "L-060", "L-066", "L-067", "L-094", "L-108", "L-118", "L-122", "L-089"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md"]
code     = ["genesis/genesis/runs/**", "genesis/genesis/api/run_routes.py", "genesis/web/src/features/run-detail/**"]
upstream = ["55-02"]
```
