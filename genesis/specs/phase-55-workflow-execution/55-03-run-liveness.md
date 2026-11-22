# 55-03 — Run liveness: `node.started`, one versioned snapshot, hint SSE and the run graph

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/runs/`, `genesis/api/run_routes.py`,
> `web/src/features/run-detail/`). Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**.
> Decisions: D10, D12 (items 2, 3), F12, F13 (`55-01-findings.md`). ADR draft: ADR-090 (`adr-drafts.md`). The 55-02
> mockups are approved (D12), so §5 may start.

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
  duration_s, credits}}, edges: {"src->dst": count}, active_edges: [{src, dst, state: running|waiting}], legacy:
  bool}`. `version` = the run's highest event `seq` (F13).
- **`active_edges` (D12 items 2, 3):** for each active node, only the edge **just taken** into it — from the node that
  completed last before this node's `node.started` (or before its `gate.awaiting`) — so on a loop re-entry
  `reassemble → verify` is lit, not `assemble → verify`. State `running` for a running node, `waiting` for a gate that
  waits (drawn in the warning colour). The fold records the order of completions, not only counts.
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
  lit only when it is in `snapshot.active_edges` (running, or waiting in the warning colour, D12); traversed edges from
  `snapshot.edges`. Match the approved `/dev/phase-55` graph states (genesis `d0aa1b2`, 55-02 As built). Remove the dead
  loop heuristic and the `after=0` `useRunStream` replay from the graph path. The Refresh control refetches the
  snapshot. A running node shows its elapsed time; a loop node shows "round k".
- The layout still re-runs only on topology change (L-067); level-of-detail unchanged (L-034).

## 6. Tests

- Worker: `tasks` events → `node.started` for a straight path, a retry loop, a gate + resume, a kill + resume
  (from §0's real payloads, not invented ones).
- Fold: each rule in §2; `active_edges` on a straight path, a loop re-entry (only the edge just taken) and a waiting
  gate; a 30k-event fixture folds incrementally (time bounded); legacy run; two-reader version monotonic.
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

## As built

**Status:** BUILT 2026-11-23, review **SHIP** (re-run 1). Repo genesis, branch master, base `d0aa1b2`, head `29775149`,
5 local commits (not pushed, not tagged). No DB migration, no genesis-core change (`CORE_MAJOR` 1).

### Commits (genesis)

| sha | what |
|---|---|
| `793c04b6` | source, tests, fixtures, probe `scripts/probes/phase55-run-graph.mjs` |
| `d4f99d84` | `web/static` for 793c04b (66 files) |
| `1576a229` | review round 1: M1, m1, m2, n1, n2 + tests |
| `2647574b` | `web/static` for 1576a22 (66 files) |
| `29775149` | review re-run n3: exact stopped-time assertions (test only, no bundle change) |

Bundle proof (L-089): each bundle commit checked with `git show --stat <sha> -- web/static` in its own call after the
build had exited; a rebuild in a later call left `git status --short --untracked-files=all` empty both times. The
reviewer's out-of-tree build was identical to `web/static` both rounds.

### §0 spike result (LangGraph 1.2.8, langgraph-checkpoint-sqlite 3.1.0)

Scripts kept in `evidence/55-03/spike/` (`spike.py`, `spike2.py`), run with `AsyncSqliteSaver` and
`astream(stream_mode=["updates","custom","tasks"])`.

- **Shapes.** A task start is `{id, name, input, triggers}`, e.g. `{"id": "7cb502d7-…", "name": "a", "input": {"i": 0},
  "triggers": ["branch:to:a"]}`; a join start has `triggers: ["branch:to:j", "join:l+r:j"]`. A finish is `{id, name,
  error, result, interrupts}`. Per task the order is start → `updates` chunk → finish; the next task's start follows.
  `input` is the node's whole input state, so the worker never forwards it (ADR-010).
- **Straight path:** one start/finish pair per node, as above.
- **Retry loop** (`work → check → work …`): every round is a new task with a new id and its own start.
- **Gate:** the gate task starts; the interrupt arrives as an `updates` chunk keyed **`__interrupt__`**, then a finish
  with `interrupts: [{value, id}]`; `get_state().next == ["ask"]`. On `Command(resume=…)` the gate task **starts again
  with the same id**, then completes normally.
- **Kill + resume:** killed with SIGTERM during `slow` (exit 143) after its start; a fresh process resuming from the
  checkpoint **re-emits the start with the same task id**, then the node completes.
- **Error:** a finish with `error: "RuntimeError('blew up')"` and no `updates` chunk, then the exception raises.
- **Fan-out:** both branch starts come before either completes; a compiled subgraph node shows as one outer task.
- `updates` ordering and the final state are the same with and without `tasks`.
- Conclusion: `tasks` is suitable, so there is no worker-emitted fallback. Side finding: the `__interrupt__` updates
  chunk reached the worker before 55-03 too; it was forwarded as a node, `on_event` raised on the list delta's `.keys()`,
  and `Supervisor._pump` swallowed it on every gate (no such row in the real `genesis.db`). It is now filtered
  (`worker._internal`), and the pump logs such failures.

### Changed

- `genesis/runs/worker.py`: `"tasks"` in `stream_mode`; `_task_start` → `{kind: task_start, node, task_id}`;
  `_internal` drops `__*` pseudo-nodes from `updates` and `tasks`.
- `genesis/runs/manager.py`: `NODE_STARTED` in `CANONICAL_KINDS`; `task_start` → `node.started {task_id}` with the node
  column; `note_progress` runs before `node.completed` is logged (a failed cursor write is logged, the completion still
  goes out); a terminal run's bus is dropped after its `run.final`, a bounded `_finished` set (10,000) keeps it reading
  closed; `snapshot(run_id)`; `events()` fixed (it called a non-existent `self.bus`). `runs.cursor` semantics unchanged.
- `genesis/runs/snapshot.py` (new): `RunFold` (the §2 rules), `SnapshotCache` (one fold per run, LRU 64, terminal and
  idle 300 s evicted; reads only `FOLD_KINDS` after the last folded seq, so `agent.thought`/`tool_update` rows are
  never parsed; version = max(the head read before listing, folded seq)), `snapshot_of`.
- `genesis/runs/events.py`: bounded history (500); `Subscription` = an `asyncio.Queue` fed by `call_soon_threadsafe`,
  bound 1,000 → one `RESYNC` and dropped; `release()` is synchronous; the sync generator `subscribe()` is gone.
- `genesis/runs/supervisor.py`: stderr drained by its own thread into logger `genesis.worker` with a 64 KB tail for
  `worker_exit`; `on_event` failures logged at ERROR with the kind.
- `genesis/api/run_routes.py`: `GET /api/runs/{id}/snapshot`; `GET /api/runs/{id}/live`; `/events/stream` subscribes
  before replaying and ends with `resync` on overflow.
- Web: `types/snapshot.ts`; `runsApi.snapshot`/`runsApi.live` (fetch + `readSse`); `qk.runs.snapshot`;
  `hooks.ts` `useRunSnapshot`, `useRunLive`, `newerSnapshot`, `backoffMs` (and `useRunSteps`, `useRunTransitions`,
  `useRunStream` deleted); `node-states.ts` `snapshotNodeStates`, `snapshotSteps`, `edgeState`, `EDGE_COLOR/WIDTH`
  (`deriveNodeStates` deleted); `RunGraph`/`ElkEdge`/`NodeCard` from the snapshot only (the `runningNode` prop,
  the cursor edge rule and the graph-panel reload button are gone); `NodeCard` fixed height 104 (`layout.ts NODE_H`),
  elapsed clock, `round k`, ↻ runs; `components/LiveStatus.tsx` (`LiveBadge`, `RefreshControl` in the header);
  `RunDetailPage` (status from the snapshot first, credits and the List telemetry from snapshot nodes);
  `hitl-hooks` invalidates the snapshot; `useRunNodeStream` re-reads on `resync`/error; badge status `paused`.

### Tests

- `tests/test_run_liveness.py` (37 tests): spike payloads → `_task_start`; real subprocess workers for a straight path,
  a loop, a gate + resume (same task id, no `__interrupt__`, no pump error), pause + resume (paused, same task id),
  cancel; cursor before announce; pump logging; 240 KB stderr; every fold rule; `active_edges` straight / loop re-entry
  / waiting gate; the seven approved graph states (records `runs/graph-states.json`); legacy and fresh runs; a 30k-event
  run (first fold < 5 s, then one read after the held version, < 0.5 s); two readers agree and never go back; cache
  eviction; bus overflow, cross-thread feed, bounded history, dropped terminal bus; `/snapshot` (records
  `snapshot-gate.json`, `snapshot-done.json`); `/live` id frames, hints only, CRLF, terminal end (records
  `live-frames.json`), Last-Event-ID → one resync, nothing missed → no resync, terminal run, overflow, ping;
  cancelled task group releases the subscriber on both streams (L-118); `/events/stream` tail and overflow.
- Fail-first: with the old `supervisor.py`, the stderr test times out (the worker blocks on a full pipe; 55-01 had
  this as "latent, not reproduced") and the pump-logging test fails.
- Web: `node-states.test.ts` (the seven mockup states from the recorded snapshots, round/runs, stopped times),
  `liveness.test.tsx` (newer version kept, visibilitychange refetch, backoff/coalescing/terminal close, unmount abort,
  node-stream resync, CRLF reader, non-OK reject, badge states + jest-axe), `contract.test.ts` (kinds both ways with
  `node.started`, snapshot and live fixture shapes against typed values), `run-detail.test.tsx` updated.
- Gates at `29775149`: genesis pytest **2159 passed** (reviewer, at 1576a22; 2122 at v0.83.0), ruff clean;
  genesis-core 124 passed; web lint 0 errors / 20 warnings (baseline), typecheck clean, `npm test` 83 files /
  **963 passed** (943 at the 55-02 head).

### Real-browser check (L-090)

Scratch `genesis serve` on :8790 with its own `GENESIS_STATE_DIR=/tmp/gr-55-03/state` (system schedules paused; the
fleet on 8760/8761 untouched). `node scripts/probes/phase55-run-graph.mjs` drove a program-only `liveness-probe`
workflow (held by files; sources in `evidence/55-03/spike/`) through program running, loop re-entry, paused, gate,
done and failed, and `--only-agent` one real `hello-appian` run `r-86a0a8e446bc` (one Kiro turn, 0.312 metered
credits). 1280/1440/1920 px × light/dark: 36 + 12 shots, no page sideways scroll, no wrapped badge or button. Read from
the DOM: only `prepare→work` lit; on the re-entry only `check→work` lit with "round 2"; nothing lit when paused, done or
failed; `check→approve` in the waiting colour at the gate; the badge Live while active and Finished after. Evidence:
`evidence/55-03/<state>-<width>-<theme>.jpg`, `result-probe.json`, `result-agent.json`. The agent shots predate
`1576a229` (review n4); that fix does not change a running node.

### Review

`reviews/55-03-review.md`. Round 1 NEEDS_CHANGES: M1 (a paused or failed re-entry lost its round count and showed the
earlier execution's time), m1 (node dialog tail went quiet after a `/events/stream` resync), m2, n1, n2. All fixed in
`1576a229`/`2647574b`. **Re-run 1: SHIP**; n3 taken in `29775149` (the reviewer's suggested paused value was off by
18 s; the fixture's 3,581,000 ms is used), n4 noted above.

### Decisions / deviations

No ADR deviation. Choices the spec did not cover:
1. **`?since_version` not built.** A pause writes no event, so an equal seq cannot prove the snapshot unchanged; the
   full snapshot is small. The client takes an equal version and drops only a lower one. For 55-08.
2. **A reconnect that missed hints gets one `resync` frame**, not the missed hints replayed (a hint only triggers a
   re-read). `run.final` frames also carry `status` so the client closes only on a terminal one (L-003).
3. **Extra snapshot node fields:** `tool_calls`, `messages` (the cards and the List telemetry) and `entered_from` (the
   hop into an unfinished execution). The page no longer fetches `/steps` or `/transitions`.
4. **Edge counts** are completed hops (the same rule as `/transitions`, asserted equal) plus the hop into an unfinished
   node, so the counts match the mockup (×4 into a node in its 4th round; ×3 into a node paused in its 3rd).
5. **↻ counts the current or stopped execution; "round k"** shows while a re-entered node runs. The mockup's
   "of 3" and per-item labels ("workstream 4 of 8") are not shown: nothing generic in the log gives them.
6. **A stopped execution's time** runs from its start to the run's terminal `run.final`, or to the stored pause time.
7. **`legacy`** = node activity with no `node.started`; a run that has not reached its first node is not legacy.
8. **Badge states:** Polling before the first connect, Live while connected, Reconnecting (with a countdown) while
   waiting to retry, Finished when the run is not active. Paused and gated runs keep the stream open (not terminal).
9. **Refresh moved to the header** as in the mockup ("Updated N s ago"); the graph panel's reload button is gone.
10. The `/events/stream` frames are unchanged (no `id:` added); only its subscriber, ordering and overflow changed.
11. `fold_steps` loop re-entry fix: **not done**; `/steps` keeps its old rule for its other readers (the MCP
    introspection server, chat).
12. The `/live` endpoint uses `fetch` + `readSse`, not `EventSource`, so reconnect, backoff and `after` are ours.

### Lesson candidates

1. **Spike the real stream before designing on it.** The `tasks` spike also found that an interrupt arrives as an
   `updates` chunk keyed `__interrupt__`, which had been raising in `on_event` and was swallowed by the pump on every
   gate since the first gate; a swallowed exception hides a bug for as long as the swallow exists.
2. **A child's stderr PIPE that nobody reads blocks the child** once the pipe fills (64 KB on macOS): drain it on its
   own thread. A test that writes 240 KB reproduced the hang the code review had called latent.
3. **A count shown on a node and on its incoming edge must use the same rule** for every status, not only running
   (review M1): compare them in one test per state.

### Code-map changes (for genesis-docs, bible/03)

- `genesis/runs/snapshot.py` (new): `RunFold`, `SnapshotCache`, `snapshot_of`, `FOLD_KINDS`.
- `genesis/runs/events.py`: `Subscription`, `CLOSED`, `RESYNC`, `HISTORY_MAX`, `SUBSCRIBER_MAX`; bounded `EventBus`.
- `genesis/runs/manager.py`: `NODE_STARTED`, `snapshot()`, `_finished`, `_snapshots`.
- `genesis/runs/worker.py`: `_task_start`, `_internal`. `genesis/runs/supervisor.py`: stderr drainer, `STDERR_TAIL`.
- `genesis/api/run_routes.py`: `GET /runs/{id}/snapshot`, `GET /runs/{id}/live` (`LIVE_KINDS`, `LIVE_PING_S`, `_hint`).
- `web/src/types/snapshot.ts`; `web/src/features/run-detail/components/LiveStatus.tsx`; `hooks.ts` (`useRunSnapshot`,
  `useRunLive`); `node-states.ts` (`snapshotNodeStates`, `edgeState`, `snapshotSteps`); fixtures
  `web/src/test/fixtures/runs/{snapshot-gate,snapshot-done,live-frames,graph-states}.json`.
- `scripts/probes/phase55-run-graph.mjs`: the run-graph browser probe.
- Removed: `deriveNodeStates`, `useRunSteps`, `useRunTransitions`, `useRunStream`, `EventBus.subscribe()` generator.

### For 55-04+

- **55-08** owns the contract table: add `/snapshot` (with the extra node fields, decision 3) and `/live` (frames,
  `resync`, `status` on `run.final`); decide whether `?since_version` is wanted (decision 1).
- **55-06/55-07** (escalation gate, Resolve): the gate node reads `awaiting` with a `waiting` edge; `snapshot.run.gate`
  carries the gate payload, so the F6 fields will reach the snapshot without a fold change. New run actions
  (relaunch, restart_from) need nothing here: a new run gets its own fold.
- **55-09**: the Resolve tab can key on `snapshot.run.status` and `active_nodes`; the "Needs you" pill text is still
  `statusMeta` (unchanged here).
- **55-12** write-back: L-005 (node.started canonical), ADR-090 text (decisions 1, 2, 4, 7), lesson candidates above.
- Not covered by a test or the probe: parallel fan-out edge counting (consecutive-completion rule) and two `serve`
  processes watching one live run (the second gets no hints and relies on the 3 s poll by design).
- Cleanup for the user: `/tmp/gr-55-03/` (scratch home, stopped) and `/tmp/spike-55-03/`.
