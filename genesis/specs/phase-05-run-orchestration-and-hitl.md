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

**In scope:** run lifecycle + persistence; input validation; streaming; the three
HITL mechanisms; run APIs; Studio integration.
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
- Persistent run record (SQLite, alongside checkpoints): `{run_id, workflow_id, version, inputs, status, cursor, created_at, updated_at, artifacts_dir}`.
- `start(workflow_id, inputs)`:
  1. Load workflow (Phase 3 loader) → `build(ctx)`.
  2. Validate `inputs` against `META.inputs_schema`.
  3. Create `RunWorkspace` (`~/.genesis/runs/<run_id>/`) + run record.
  4. Stream-execute the compiled graph with `thread_id=run_id`.

### 4.2 Streaming (live step view)
Use LangGraph stream modes multiplexed to a per-run event bus:
- `updates` → per-node state deltas (drives the step timeline).
- `messages` → token stream from agent nodes (if surfaced).
- `custom` → `ctx.emit(...)` events, including **ACP tool-call events** from
  `kiro_node` (ToolCall/ToolCallUpdate) so the UI shows what Kiro is doing.
- `checkpoints`/`tasks` → progress + resume points.
Transport: Server-Sent Events (SSE) or WebSocket on the local app; Studio consumes
LangGraph's native stream directly.

### 4.3 HITL mode 1 — Designed approval gates
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
- **Pause:** cooperative cancellation between supersteps. `pause(run_id)` sets a
  flag; the engine checks it at each node boundary and stops cleanly (LangGraph
  has already checkpointed the completed node). Status → `awaiting_input(paused)`.
  - For a long-running *in-flight* node (e.g., a slow Kiro turn), pause takes
    effect at the next node boundary; the current node completes or is cancelled
    (agent nodes: cancel the ACP turn via `session/cancel`, checkpoint not advanced).
- **Resume:** `resume(run_id)` re-invokes the graph from the last checkpoint.
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
GET    /runs/{id}/artifacts                                    -> blackboard file list
GET    /runs                    ?status=&workflow=             -> history
```

### 4.7 Studio integration (interim UI — Q6)
- Run the compiled graphs under a **LangGraph Server** app (the same local
  process) so **LangGraph Studio** can attach: visualize the graph, watch state
  transitions, hit interrupts, edit state, time-travel — most of the workbench UX
  for free while the bespoke UI (Phase 7) is built.
- Document how to launch Studio against the local Genesis server.

### 4.8 Failure & escalation
- Node exception → run `failed` with the error captured in `state.errors`; the
  run is resumable after a fix/edit (mode 3) or restart.
- Retry exhaustion (Q9) → routes to an `escalation` gate (mode 1) rather than
  failing silently.

---

## 5. Task breakdown

1. Run record store (SQLite) + lifecycle state machine + `start()`.
2. Input validation against `META.inputs_schema`.
3. Stream multiplexer: map LangGraph `updates/messages/custom/checkpoints` → per-run event bus; SSE/WebSocket endpoint.
4. Wire `kiro_node` ACP tool-call events into the `custom` stream via `ctx.emit`.
5. HITL mode 1: finalize `hitl_gate` + `interrupt` payload schema + `/respond` resume + approve/reject/feedback routing.
6. HITL mode 2: cooperative pause flag + node-boundary checks + `session/cancel` for in-flight agent turns + `/pause` `/resume`.
7. HITL mode 3: `/state` GET + PATCH via `update_state`, editable-key guardrails, `/fork` (time-travel).
8. Run APIs (all endpoints) + history query.
9. LangGraph Server app config so Studio attaches; write the "run in Studio" doc.
10. End-to-end demo (Studio): run `hello-appian` with a gate; approve; pause mid-run; edit a decision; resume; fork from a checkpoint.

---

## 6. Acceptance criteria

- [ ] Start a run with validated inputs; invalid inputs are rejected pre-run.
- [ ] Live step timeline streams (updates + agent tool-call events).
- [ ] **Mode 1:** run stops at a designed gate; approve continues; reject routes correctly; feedback reaches the next node.
- [ ] **Mode 2:** pause at an arbitrary point; app restart; resume continues exactly from the last checkpoint (no re-run of completed nodes); in-flight Kiro turn cancels cleanly.
- [ ] **Mode 3:** edit a `decisions` value at a pause via PATCH; resume uses the edited value; fork creates an independent run from a past checkpoint.
- [ ] Retry exhaustion escalates to a HITL gate (Q9), not a silent failure.
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
- LangGraph Server app + Studio attach doc.
- Studio-driven end-to-end HITL demo on `hello-appian`.
