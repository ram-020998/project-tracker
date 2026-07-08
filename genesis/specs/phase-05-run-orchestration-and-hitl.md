# Phase 5 — Run Orchestration & HITL

> **Goal:** Turn "a graph that can run" into "a supervised run": a run lifecycle
> with durable state, live streaming of steps, and **all three HITL modes** —
> (1) designed approval gates, (2) ad-hoc pause/resume anywhere, (3) mid-run state
> injection. Validate the whole thing through **LangGraph Studio** as the interim
> surface (Q6).

Prereq: `specs/00-architecture-overview.md`, Phases 1–4.

---

## 1. Objective & success statement

A user can start a run of an installed workflow with validated inputs, watch each
node execute live (streamed), be stopped at **designed gates** to approve/reject/
give feedback, **pause the run at any time** and resume later from the last
checkpoint, and **edit the run's state** at a pause and continue. All runs are
durable (survive process restart) and inspectable. Proven in LangGraph Studio.

---

## 2. Scope

**In scope:** run lifecycle + persistence; **subprocess-worker execution
orchestration** (spawn/supervise/kill, IPC, checkpoint-driven resume); input
validation; streaming; the three HITL mechanisms; run APIs; Studio integration.
**Out of scope:** the bespoke web workbench UI (Phase 7 — this phase uses Studio);
new workflows beyond `hello-appian`/ERD.

---

## 3. Decisions applied

Q6 (single app; Studio first), Q7 (all three HITL modes, important), Q8 (durable
editable state + SQLite checkpointer), Q9 (escalation gate on retry exhaustion is
a HITL gate).

---

## 4. Detailed design

### 4.1 Run lifecycle & model
- **Run == LangGraph thread.** `run_id == thread_id`.
- States: `pending → running → awaiting_input (gate|paused) → running → done|failed|cancelled`.
- Persistent run record (SQLite, alongside checkpoints): `{run_id, workflow_id, version, inputs, status, cursor, created_at, updated_at, artifacts_dir}` — `artifacts_dir` is the **absolute** path under the configured artifacts root (relocation-safe).
- `start(workflow_id, inputs)`:
  1. Loader (Phase 3) enforces the **genesis-core major-compat gate**, then validates `inputs` against `META` (read from `workflow.yaml`, no graph import in the app).
  2. Create `RunWorkspace` under `<GENESIS_ARTIFACTS_DIR>/<workflow_id>/<run_id>/` (NOT `~/.genesis/`) + run record.
  3. **Spawn a subprocess worker** (ADR-012) that imports `graph.py`, calls `build(ctx)`, and stream-executes with `thread_id=run_id` against the shared `genesis.db` checkpointer. The app never imports workflow Python.
  4. The app supervises the worker over a small IPC channel: events out (stream), control in (respond/pause/resume/cancel).
- **Worker model (checkpoint-driven, disposable):** because state is checkpointed
  after every superstep, workers hold no authoritative state. The app can kill a
  worker at any time (pause/cancel) and later spawn a **fresh** worker that
  `resume(thread_id)` from the checkpointer. A worker crash/hang/exit fails only
  that run — never the app/UI — and the run is resumable from the last checkpoint.
- Resource limits (memory/time) may be imposed on the worker.

### 4.2 Streaming (live step view)
Use LangGraph stream modes multiplexed to a per-run event bus:
- `updates` → per-node state deltas (drives the step timeline).
- `messages` → token stream from agent nodes (if surfaced).
- `custom` → `ctx.emit(...)` events, including **ACP tool-call events** from
  `kiro_node` (ToolCall/ToolCallUpdate) so the UI shows what Kiro is doing.
- `checkpoints`/`tasks` → progress + resume points.
- **telemetry** → per-node `{duration_ms, tool_calls, turns, credits, retries}` and the run aggregate (from `state.telemetry`, §1.4 of state-and-data-model) emitted as `custom` events so the UI shows live cost/duration per step.
Transport: Server-Sent Events (SSE) or WebSocket on the local app; Studio consumes
LangGraph's native stream directly.

### 4.3 HITL mode 1 — Designed approval gates
- **Default posture:** `META.auto_approve = true` (default) → the engine auto-advances every validated step and pauses ONLY at the three sanctioned classes: `approval` (author gates), `escalation` (retry exhaustion), `pre_mutation` (before write/deploy). No per-step confirmations (see `hitl-design.md` §0).
- `hitl_gate(kind)` node (Phase 1 primitive) calls `interrupt(payload)` where
  `payload = {kind, prompt, options, context_refs}`.
- The graph pauses; run status → `awaiting_input(gate)`; payload surfaced via API/stream.
- Resume via `Command(resume=decision)` where `decision ∈ {approve, reject, {feedback: "..."}}`.
  - `approve` → continue on the approved edge.
  - `reject` → route to a rejection/END edge (author-defined).
  - `feedback` → write the note into `state.decisions[<gate>.feedback]`; the next
    node's `prompt_fn` consumes it (this is the "give my thoughts" path at a gate).
- Q9 escalation gates reuse this exact mechanism (kind = `escalation`).

### 4.4 HITL mode 2 — Ad-hoc pause / resume anywhere
- **Pause:** because workers are disposable and state is checkpointed per
  superstep (ADR-012), `pause(run_id)` = **kill the worker** after the current
  superstep boundary (cooperative flag for a clean stop; hard kill as fallback).
  The last completed node is already checkpointed. Status → `awaiting_input(paused)`.
  - For a long-running *in-flight* agent node (slow Kiro turn), cancel the ACP turn
    via `session/cancel` (SDK enhancement) so the worker exits promptly; the
    checkpoint is **not** advanced (the node re-runs on resume). Partial blackboard
    writes are ignored (referenced only on success).
- **Resume:** `resume(run_id)` spawns a **fresh worker** that re-invokes the graph
  from the last checkpoint (no dependence on the original worker's memory).
- Because snapshots are per-superstep, pause/resume is exact and survives an app
  or worker restart.
- Because the checkpointer snapshots after every superstep (durability=full),
  pause/resume is exact and survives an app restart.

### 4.5 HITL mode 3 — Mid-run state injection (edit & continue)
- At any pause (gate or ad-hoc), the user can **read and edit the current state**
  (which is small + human-readable by design, Q8).
- API `PATCH /runs/{id}/state {json-merge-patch}` applies an edit to the
  checkpointed state via LangGraph's `update_state(config, values)`.
- Guardrails: only whitelisted editable keys (`inputs`, `decisions`, and
  workflow-declared `editable` fields in `META`); artifact *pointers* editable,
  bulk artifacts edited by editing the files in the blackboard directly (also allowed).
- Optionally **fork**: `POST /runs/{id}/fork` creates a new thread from a chosen
  checkpoint with edits (time-travel), leaving the original intact.
- After edit, `resume(run_id)` continues from the (edited) checkpoint.

### 4.6 Run APIs
```
POST   /runs                    {workflow_id, inputs}          -> {run_id}
GET    /runs/{id}                                              -> run record + status + cursor
GET    /runs/{id}/stream        (SSE)                          -> live events
GET    /runs/{id}/state                                        -> current state (redacted)
PATCH  /runs/{id}/state         {merge-patch}                  -> edit (mode 3)
POST   /runs/{id}/pause | /resume | /cancel
POST   /runs/{id}/respond       {gate, decision}               -> resume a gate (mode 1)
POST   /runs/{id}/fork          {from_checkpoint, edits}       -> new run (time-travel)
GET    /runs/{id}/artifacts                                    -> blackboard file list + sizes
DELETE /runs/{id}/artifacts                                    -> purge one terminal run's artifacts
POST   /runs/purge          {policy|all_completed}             -> retention sweep (terminal runs only)
GET    /artifacts/usage                                        -> per-run + root disk usage
GET    /runs                    ?status=&workflow=             -> history
```

### 4.7 Studio as an interim dev/debug harness (Q6)
- The Genesis backend is a **FastAPI app** that embeds LangGraph as a library
  (compile/run graphs against the SQLite checkpointer) and exposes the run/stream/
  HITL APIs above (ADR-023). It is **not** a LangGraph Server.
- For interim visualization during M6, run a workflow's graph under
  **`langgraph dev`** (LangGraph Server) pointed at the **same `genesis.db`
  checkpointer**, so **LangGraph Studio** can attach to inspect graph execution,
  interrupts, state, and time-travel — most of the workbench UX for free while the
  bespoke UI (Phase 7) is built.
- Studio is a **developer/debug convenience**, not the product backend; Phase 7's
  custom UI (on the FastAPI APIs) supersedes it.
- Document how to launch `langgraph dev` + Studio against the shared checkpointer.

### 4.8 Failure & escalation
- Node exception → run `failed` with the error captured in `state.errors`; the
  run is resumable after a fix/edit (mode 3) or restart.
- **Worker crash / hang / exit / OOM** → the app detects worker death (IPC close /
  timeout / non-zero exit), marks the run `failed` with a diagnostic, and leaves it
  resumable from the last checkpoint. The app + UI are unaffected (ADR-012).
- Retry exhaustion (Q9) → routes to an `escalation` gate (mode 1) rather than
  failing silently.

---

## 5. Task breakdown

1. Run record store (SQLite) + lifecycle state machine + `start()`.
1a. **Subprocess worker** (`runs/worker.py`): spawn/supervise a worker that builds + runs a workflow graph against the shared checkpointer; IPC channel (events out / control in); worker-death detection; resource limits; **checkpoint-driven resume via a fresh worker**.
2. Input validation against `META.inputs_schema`.
3. Stream multiplexer: map LangGraph `updates/messages/custom/checkpoints` → per-run event bus; SSE/WebSocket endpoint.
4. Wire `kiro_node` ACP tool-call events into the `custom` stream via `ctx.emit`.
5. HITL mode 1: finalize `hitl_gate` + `interrupt` payload schema + `/respond` resume + approve/reject/feedback routing.
6. HITL mode 2: worker-kill pause at superstep boundary + `session/cancel` for in-flight agent turns + resume via a fresh worker + `/pause` `/resume`.
7. HITL mode 3: `/state` GET + PATCH via `update_state`, editable-key guardrails, `/fork` (time-travel).
8. Run APIs (all endpoints) + history query.
9. Backend = FastAPI app embedding LangGraph; provide a `langgraph dev` config so Studio can attach to a graph against the shared `genesis.db`; write the "debug in Studio" doc.
10. End-to-end demo (Studio): run `hello-appian` with a gate; approve; pause mid-run; edit a decision; resume; fork from a checkpoint.

---

## 6. Acceptance criteria

- [ ] Start a run with validated inputs; invalid inputs are rejected pre-run.
- [ ] Live step timeline streams (updates + agent tool-call events).
- [ ] **Mode 1:** run stops at a designed gate; approve continues; reject routes correctly; feedback reaches the next node.
- [ ] **Mode 2:** pause at an arbitrary point; app restart; resume continues exactly from the last checkpoint (no re-run of completed nodes); in-flight Kiro turn cancels cleanly.
- [ ] **Mode 3:** edit a `decisions` value at a pause via PATCH; resume uses the edited value; fork creates an independent run from a past checkpoint.
- [ ] Retry exhaustion escalates to a HITL gate (Q9), not a silent failure.
- [ ] **Worker isolation:** a workflow that calls `sys.exit()` / hangs / OOMs fails only its run (app + UI stay up); the run is resumable from the last checkpoint. Pausing a run kills its worker; resume spawns a fresh worker and continues.
- [ ] Everything above is demonstrable in LangGraph Studio.

---

## 7. Risks

- **Cancelling an in-flight agent node cleanly** — ACP `session/cancel` + not
  advancing the checkpoint; verify partial artifacts don't corrupt state (they
  live in the blackboard, referenced only on success).
- **State-edit safety** — restrict editable keys; validate the merged state
  against the workflow's state schema before resuming.
- **Studio version compatibility** with the LangGraph version pinned in Phase 1.

---

## 8. Deliverables

- Run lifecycle + persistence + streaming + all three HITL modes + run APIs.
- FastAPI backend embedding LangGraph + a `langgraph dev`/Studio debug-attach doc.
- Studio-driven end-to-end HITL demo on `hello-appian`.
