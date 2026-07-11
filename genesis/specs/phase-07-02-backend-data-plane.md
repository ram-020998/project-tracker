# Phase 7.2 — Backend & Core Data-Plane Enhancements

> **Goal:** Extend the platform so the backend **emits and durably stores**
> everything the revamped UI must show — a persistent event log, gate state derived
> from the checkpoint, per-node step records, workflow graph topology, the **live
> Kiro ACP conversation** (messages, thoughts, tool calls), artifact content, and
> per-integration status. This is the critical-path enabler for the whole revamp:
> the UI cannot render what the backend does not produce. Spans `genesis`,
> `genesis-core`, and `kiro-agent-sdk`.

Prereq: 07-01. Consumers: every screen spec (04–09), especially Run Detail (07-07/08/09).

> **Serving path (ADR-028, added 2026-07-11):** all endpoints below are served under the
> **`/api`** prefix (e.g. `GET /runs/{id}/events` → `GET /api/runs/{id}/events`). This doc
> writes the logical paths without the prefix for brevity; the prefix is applied by the
> FastAPI `APIRouter` and prepended centrally by the frontend client. Non-`/api` paths fall
> through to the SPA history fallback. See ADR-028.

Design tenets: **durable-first** (nothing critical lives only in an in-memory bus),
**typed contracts** (stable JSON shapes the frontend mirrors in `types/`),
**backward-compatible** within genesis-core major 1 (ADR-019), **subprocess-safe**
(the worker remains the only importer of workflow Python — ADR-012).

---

## 1. Problem statement (what's missing today)

Traced against the current code:

1. **Ephemeral gate → unreachable approval.** `RunManager` publishes the `AWAITING`
   event to an **in-memory** `EventBus`. On reload/restart the bus is empty, so the
   UI can't reconstruct the gate → no approval control. Gate/interrupt state must be
   derivable from the **persistent checkpoint**.
2. **No persistent event log.** `EventBus` history is per-process. A run's timeline,
   activity, and any conversation vanish on restart and can't be viewed after the
   fact.
3. **Kiro conversation discarded.** `kiro_node` uses `collect()` and keeps only the
   final output. The SDK's `prompt()` already yields `AgentMessageChunk`,
   `AgentThoughtChunk`, `ToolCall`, `ToolCallUpdate`, `ResultMessage` — none reach
   the UI.
4. **No graph topology.** There is no endpoint describing a workflow's nodes/edges,
   so the UI cannot draw the diagram.
5. **No per-node step records.** Node start/finish/status/duration/attempts aren't
   recorded, so neither the graph nor the timeline can show progress reliably.
6. **Artifacts have no content endpoint.** `/runs/{id}/artifacts` lists names/sizes
   only; preview is impossible.
7. **No per-integration status.** Health is global; the UI wants a per-server
   configured/reachable signal.

---

## 2. Architecture: the persistent event log

Introduce a durable, append-only event log as the backbone for run observability.
It coexists with the live `EventBus` (the bus becomes a fan-out for *live*
subscribers; the log is the durable record used for hydration + history).

### 2.1 Storage

New SQLite table in `~/.genesis/genesis.db` (same DB as RunStore/checkpointer),
owned by a new `genesis/genesis/runs/eventlog.py`:

```sql
CREATE TABLE IF NOT EXISTS run_events (
  seq         INTEGER PRIMARY KEY AUTOINCREMENT,  -- global monotonic
  run_id      TEXT NOT NULL,
  node        TEXT,                                -- node id if node-scoped
  kind        TEXT NOT NULL,                       -- see §3 event union
  payload     TEXT NOT NULL,                       -- JSON
  ts          TEXT NOT NULL                        -- ISO8601 UTC
);
CREATE INDEX IF NOT EXISTS ix_run_events_run ON run_events(run_id, seq);
```

`EventLog` API (sync, mirrors RunStore style):
- `append(run_id, kind, payload, node=None) -> int(seq)`
- `list(run_id, after_seq=0, kinds=None, node=None, limit=..., offset=...) -> list[EventRecord]`
- `last_seq(run_id) -> int`
- `purge(run_id)` (used by retention).

### 2.2 Write path

`RunManager._spawn.on_event` writes **every** event to `EventLog.append(...)`
**before** publishing to the live `EventBus`. Ordering guarantee: `seq` is the
canonical order; `ts` is display-only. The manager continues to update `RunStore`
status/cursor as today.

### 2.3 Read/hydrate path

- `GET /runs/{id}/events?after=<seq>&kinds=...&node=...` — paginated history from
  the log (see §6). The UI hydrates from this on mount, then tails via SSE.
- SSE (`GET /runs/{id}/stream?after=<seq>`) replays from the log starting at
  `after` (or `0`) then switches to live bus fan-out — a single unified stream with
  **no duplicates** (dedupe by `seq`) and **no loss** across restarts. If the run is
  terminal, the stream emits history then closes.

### 2.4 Retention

`config/retention.py` extends `apply_prune` to `EventLog.purge(run_id)` when a run's
artifacts are pruned, keeping the log bounded.

---

## 3. Canonical event union (the contract)

All events share an envelope and a discriminated `kind`. Frontend mirrors this in
`types/events.ts`.

```jsonc
// envelope
{ "seq": 128, "run_id": "r-…", "kind": "node.completed", "node": "fetch_schema",
  "ts": "2026-07-10T…Z", "payload": { … } }
```

| kind | node? | payload | meaning |
|---|---|---|---|
| `run.started` | — | `{workflow_id, version, inputs_keys}` | run began |
| `node.started` | ✓ | `{attempt}` | node entered |
| `node.completed` | ✓ | `{delta_keys, duration_ms}` | node finished a superstep |
| `node.failed` | ✓ | `{error, attempt}` | node raised |
| `agent.message` | ✓ | `{text, final:bool}` | Kiro assistant text chunk |
| `agent.thought` | ✓ | `{text}` | Kiro reasoning/thought chunk |
| `agent.tool_call` | ✓ | `{tool_call_id, name, title, kind, args_preview}` | tool call started |
| `agent.tool_update` | ✓ | `{tool_call_id, status, content_preview}` | tool call progressed/finished |
| `agent.result` | ✓ | `{ok, output_ref?, tokens?, duration_ms}` | Kiro turn ended |
| `validator.result` | ✓ | `{ok, checks:[{name,ok,detail}]}` | reliability validator outcome |
| `retry.scheduled` | ✓ | `{attempt, max, reason}` | trio retry |
| `telemetry` | — | `{...counters}` | telemetry snapshot delta |
| `gate.awaiting` | ✓ | `GateDescriptor` (see §4) | interrupt reached; human needed |
| `gate.resolved` | ✓ | `{decision}` | gate answered |
| `artifact.written` | — | `{name, path, bytes, media_type}` | a document was produced |
| `run.final` | — | `{status, next:[..]}` | run reached a terminal-or-gate state |
| `error` | — | `{detail, traceback_tail}` | worker/run error |

Notes:
- `*_preview` fields are truncated (e.g. 2KB) for stream economy; full content is
  fetched on demand (tool result bodies and large args live in the blackboard or are
  re-derivable; the UI shows preview + "view full" where a ref exists).
- Existing worker event kinds (`node`, `custom`, `final`, `error`) are **mapped**
  into this union by the manager (see §5.4); the worker's raw emission is refined in
  §5.

---

## 4. Gate state from the checkpoint (fixes the approval bug)

### 4.1 GateDescriptor

A stable shape describing a pending human decision, reconstructable from durable
state:

```jsonc
{
  "node": "approve_domains",
  "kind": "approval",            // approval | escalation | pre_mutation | review  (ADR-021)
  "prompt": "Review the 37 detected domains before assembly.",
  "context_refs": { "domains": "domains.json" },   // blackboard doc names
  "options": ["approve", "reject", "feedback"],     // allowed responses
  "raised_at": "2026-07-10T…Z"
}
```

### 4.2 Durable derivation

Add `RunManager.pending_gate(run_id) -> GateDescriptor | None`:
1. Fast path: read the latest `gate.awaiting` event from `EventLog` (and ensure no
   later `gate.resolved`).
2. Cold path (log empty, e.g. gated before this build shipped): spawn a
   `get_state` worker op; `worker._snapshot` already extracts
   `snap.tasks[].interrupts[].value` — normalize that into a `GateDescriptor`.

`hitl_gate` (genesis-core `nodes/gate.py`) is updated so the value passed to
`interrupt(...)` is exactly a `GateDescriptor` dict (node/kind/prompt/context_refs/
options), so both paths yield the same shape.

### 4.3 Surfacing

- `GET /runs/{id}` gains `gate: GateDescriptor | null` (populated when
  `status == awaiting_input:gate`).
- The UI renders HITL controls whenever `status == awaiting_input:gate`, driven by
  `run.gate` — **never** by a live event. This makes the approval bug structurally
  impossible.

### 4.4 Resolution

`POST /runs/{id}/respond` unchanged in shape (`{decision, gate?}`), but the manager
appends a `gate.resolved` event and validates the decision against
`gate.options` (400 on mismatch).

---

## 5. Kiro ACP conversation streaming (SDK → core → worker → log)

The marquee feature: show what the agent is actually doing, live and after the fact.

### 5.1 kiro-agent-sdk (v0.1.0)

The typed messages already exist (`prompt()` yields them). Add an ergonomic
streaming collector so callers don't re-implement iteration:

```python
async def collect_streaming(
    client, prompt: str, *, on_message: Callable[[Message], None]
) -> ResultMessage: ...
```

- Invokes `on_message` for each `AgentMessageChunk | AgentThoughtChunk | ToolCall |
  ToolCallUpdate` and returns the terminal `ResultMessage`.
- `Message` types expose stable fields: chunk `.text`; tool call
  `.tool_call_id/.name/.title/.kind/.raw`; update `.status/.content`.
- Backward-compatible: existing `collect()` / `collect_json()` unchanged.
- Bump SDK to **v0.1.0** (minor: additive).

### 5.2 genesis-core `kiro_node` (v0.4.0)

`kiro_node` switches from `collect()` to `collect_streaming(...)`, forwarding each
message to `ctx.emit(...)` as a typed conversation event, tagged with the node name:

```python
def _emit_msg(m):
    if isinstance(m, AgentMessageChunk):  ctx.emit({"type":"agent.message","node":name,"text":m.text})
    elif isinstance(m, AgentThoughtChunk):ctx.emit({"type":"agent.thought","node":name,"text":m.text})
    elif isinstance(m, ToolCall):         ctx.emit({"type":"agent.tool_call","node":name, ...})
    elif isinstance(m, ToolCallUpdate):   ctx.emit({"type":"agent.tool_update","node":name, ...})
res = await collect_streaming(client, prompt, on_message=_emit_msg)
ctx.emit({"type":"agent.result","node":name,"ok":res.ok, ...})
```

- The node still writes its final output to the blackboard doc as today.
- The reliability trio is unchanged; `validator.result` and `retry.scheduled` are
  emitted by `attach_reliability` (new emits, additive).
- Chunk coalescing: `agent.message` chunks may be frequent; the node coalesces to
  ≤ ~10/s to bound event volume (full text still reconstructable by concatenation).
- CORE_MAJOR stays 1 (additive). Bump genesis-core to **v0.4.0**.

### 5.3 SDK availability guard

`kiro_node` degrades gracefully if the installed SDK lacks `collect_streaming`
(older pin): fall back to `collect()` and emit a single `agent.result`. Prevents a
hard coupling break.

### 5.4 worker + manager mapping

- `worker.py` already forwards `ctx.emit(...)` payloads as `{"kind":"custom","data":..}`.
  The manager's `on_event` maps `custom` payloads with a `type` in the
  `agent.*|validator.*|retry.*|telemetry` set into the corresponding canonical event
  `kind` (§3), tagging `node` from the payload. Unknown custom payloads still pass
  through as a generic `custom` kind (forward-compatible).
- `node`/`final`/`error` map to `node.completed`/`run.final`+`gate.awaiting`/`error`.

### 5.5 Transcript reconstruction

The full per-node conversation is reconstructable from the event log
(`GET /runs/{id}/events?node=<id>&kinds=agent.*,validator.result,retry.scheduled`),
ordered by `seq`. No separate transcript store is needed.

---

## 6. Workflow graph topology

The UI needs nodes + edges to draw the diagram, without importing workflow Python
in the app process (ADR-012).

### 6.1 Source of truth

`workflow.yaml` / `META` gains an optional **`graph`** section authored alongside
the workflow (parity-linted like the rest of META):

```yaml
graph:
  nodes:
    - id: preflight        # matches the LangGraph node name
      label: Preflight
      kind: program        # program|agent|cli|validator|gate|subgraph
      mcp: []              # servers this node injects (agent/cli)
    - id: fetch_schema
      label: Fetch schema
      kind: agent
      mcp: [atlas]
    - id: approve_domains
      label: Approve domains
      kind: gate
      gate_kind: approval
  edges:
    - { from: preflight, to: fetch_schema }
    - { from: fetch_schema, to: normalize }
    - { from: normalize, to: approve_domains }
    - { from: approve_domains, to: assemble, condition: "approve" }
    - { from: approve_domains, to: fetch_schema, condition: "feedback" }
```

- Authoring guidance + a lint (`lint/contract.py`) that the declared `graph.nodes`
  ids are a superset of the runtime node names (best-effort; agents can't be
  imported by the linter, so parity is checked against `workflow.yaml` step list).
- For the ERD reference workflow, this section is authored as part of 07-07 bring-up.

### 6.2 Endpoint

`GET /workflows/{id}/graph` → `{nodes:[...], edges:[...]}` read by the loader from
META (no graph import). If a workflow omits `graph`, the endpoint returns a
best-effort linear topology derived from the `steps` list so the UI still renders.

### 6.3 Live node status overlay

The UI computes per-node status by folding the event log over the topology:
`pending → running (node.started) → ok (node.completed) | failed (node.failed) |
awaiting (gate.awaiting) | retrying (retry.scheduled)`. `RunRecord.cursor` marks the
current node. No extra endpoint needed; status is a client-side reduction of
`/events` (documented in 07-07).

---

## 7. Per-node step records (optional convenience endpoint)

While node status is derivable from events, expose a **summarized** view for the
timeline and list:

`GET /runs/{id}/steps` → 
```jsonc
[{ "node":"fetch_schema", "kind":"agent", "status":"ok",
   "started_at":"…","ended_at":"…","duration_ms":48213,
   "attempts":1, "tool_calls":6, "messages":42 }]
```
Computed by the manager from the event log (grouped by node). Cheap, cacheable,
drives the timeline without the client folding raw events for the summary view.

---

## 8. Artifact content & preview

### 8.1 Listing (extend existing)

`GET /runs/{id}/artifacts` → add `media_type` (sniffed from extension:
`application/json`, `text/markdown`, `text/csv`, `text/plain`,
`application/vnd.mermaid`, `application/octet-stream`) and `preview_kind`
(`json|markdown|mermaid|csv|text|binary`) per doc.

### 8.2 Content

`GET /runs/{id}/artifacts/{name}?mode=preview|full`
- `preview`: first N KB (default 256KB) + `truncated:bool` for large files.
- `full`: whole file (guarded by a max size, e.g. 10MB; larger → 413 with a
  download hint).
- Response: `{name, media_type, preview_kind, truncated, content}` (text) or a
  streamed binary for `octet-stream`.
- Path safety: resolve strictly within the run's `RunWorkspace` root; reject `..`
  traversal (return 400/404). Never serve outside `artifacts_dir`.

### 8.3 Download

`GET /runs/{id}/artifacts/{name}/download` → `FileResponse` with
`Content-Disposition: attachment`.

---

## 9. Per-integration status

Extend config so the UI's Settings cards show live status per server/CLI.

- `GET /config/mcp-cards` items gain `status` ∈ `configured | missing_secret |
  unknown` (derived from `missing_secrets`) and, when cheap, a `reachable` probe
  result reusing `health.mcp_literal_env_probe`.
- New `POST /config/mcp-cards/{server}/test` → runs the literal-env probe (and, if
  feasible, a short container start) and returns `{ok, detail, checked_at}`. Bounded
  timeout; never blocks the event loop (run in a thread).
- CLI registry similarly exposes `installed:bool` per CLI via `CliRegistry.ensure`
  dry-check in `GET /config/cli-cards` (new, mirrors mcp-cards).

---

## 10. Full API surface (new/changed)

| Method | Path | Purpose | Spec |
|---|---|---|---|
| GET | `/runs/{id}` | + `gate: GateDescriptor|null` | §4 |
| GET | `/runs/{id}/events` | paginated durable event log (`after`,`kinds`,`node`,`limit`) | §2,§3 |
| GET | `/runs/{id}/stream?after=` | unified replay+live SSE (dedupe by seq, closes on terminal) | §2.3 |
| GET | `/runs/{id}/steps` | per-node summary | §7 |
| GET | `/workflows/{id}/graph` | topology | §6 |
| GET | `/runs/{id}/artifacts` | + media_type/preview_kind | §8.1 |
| GET | `/runs/{id}/artifacts/{name}` | content (preview/full) | §8.2 |
| GET | `/runs/{id}/artifacts/{name}/download` | download | §8.3 |
| POST | `/runs/{id}/respond` | validate against gate.options; log gate.resolved | §4.4 |
| GET | `/config/mcp-cards` | + status/reachable | §9 |
| POST | `/config/mcp-cards/{server}/test` | connection test | §9 |
| GET | `/config/cli-cards` | CLI status | §9 |
| GET | `/home` | + active_runs summaries, per-integration status | 07-01 §7 |

All existing endpoints keep their current shapes (additive changes only) so nothing
breaks mid-migration.

---

## 11. Repo/versioning impact

| Repo | Change | Version |
|---|---|---|
| kiro-agent-sdk | `collect_streaming` | v0.1.0 (minor) |
| genesis-core | `kiro_node` streaming emits; `hitl_gate` GateDescriptor; trio emits | v0.4.0 (minor, CORE_MAJOR=1) |
| genesis | EventLog + all endpoints + manager mapping + artifact content + config status | v0.7.0 (minor) |
| genesis-workflows | ERD `workflow.yaml` `graph:` section; gate prompts as GateDescriptor | v0.3.0 (minor); bump core/genesis pins |

Release order: kiro-agent-sdk → genesis-core → genesis → genesis-workflows
(update pins each step; verify CI green per repo).

---

## 12. Testing

- **genesis-core:** unit tests for `kiro_node` streaming (stub `collect_streaming`
  to emit a scripted message sequence; assert `ctx.emit` calls + final output +
  graceful fallback when SDK lacks streaming); `hitl_gate` GateDescriptor shape.
- **kiro-agent-sdk:** `collect_streaming` iterates a scripted `prompt()` and returns
  the result; message field stability.
- **genesis:** EventLog append/list/pagination; SSE replay+dedupe across a simulated
  restart; `pending_gate` fast + cold paths; `/events`, `/steps`, `/graph`,
  artifact content (preview/full/traversal-reject), config status/test. Reuse the
  run-test harness.
- **Contract:** a golden JSON fixture for each event `kind` shared with the frontend
  (`types/` mirrors it); a test asserts the manager emits exactly these shapes.

---

## 13. Definition of done

1. Every event is durably logged; a run's full timeline + conversation survives a
   `genesis serve` restart and is retrievable via `/events`.
2. `GET /runs/{id}.gate` returns a valid GateDescriptor whenever gated, from durable
   state (cold-start included); `respond` validates + logs resolution.
3. `kiro_node` streams the ACP conversation as canonical `agent.*` events (with
   graceful fallback); per-node transcript is reconstructable from `/events`.
4. `/workflows/{id}/graph`, `/runs/{id}/steps`, artifact content/download, and
   per-integration status endpoints return the documented shapes.
5. All four repos released in order, pins bumped, CI green.
6. Golden event-shape fixtures shared with the frontend; test suites green; ruff clean.
