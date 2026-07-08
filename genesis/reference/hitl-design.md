# Genesis — Human-in-the-Loop (HITL) Design

All three HITL modes are required (ADR-009, Q7). This doc specifies each mode's
mechanism, API, UX, and how they rely on the durable checkpointer. They are
**distinct features**, not one vague "interrupt anywhere."

Foundation: the SQLite checkpointer snapshots state after **every superstep**
(durability=full). All three modes depend on this.

---

## 0. Default posture — `auto_approve` (codified)

**Default: `META.auto_approve = true`.** Validated steps **auto-advance** — the
run never pauses for per-step confirmation. A run pauses **only** at one of three
**sanctioned pause classes**:

| Class | When | Node |
|---|---|---|
| **(a) Approval gate** | author-designed decision points (declared in `META.hitl_points`) | `hitl_gate(kind="approval")` |
| **(b) Escalation** | a reliability trio exhausts its retries (ADR-011) | `hitl_gate(kind="escalation")` |
| **(c) Pre-mutation** | immediately before any write/deploy/data mutation | `hitl_gate(kind="pre_mutation")` — **required** |

Anything else auto-advances. This makes "keep gates rare" a **default of the
system**, not a guideline authors must remember — preventing accidental approver
fatigue (solutions-copilot doc-19 warning).

Rules:
- `auto_approve` defaults to `true`; an author may set it `false` only with a
  documented reason (rare; e.g., a high-stakes workflow wanting step-wise review).
- **(c) is mandatory:** any node that uses a write/deploy/data MCP server (registry
  `mode ∈ {read-write, read-write-deploy, read-write-data}`) **must** be preceded
  by a `pre_mutation` gate. Enforced by the HITL lint (Phase 2).
- Gates outside classes (a)/(b)/(c) are flagged in review/CI (approver-fatigue guard).
- Ad-hoc pause (Mode 2) is always available to the *user* regardless of `auto_approve`.

---

## Mode 1 — Designed approval gates

**What:** the *workflow author* marks deliberate pause points (approve a design
doc, confirm before deploy). Also the target of retry-exhaustion escalation
(reliability-standard.md).

**Mechanism:**
- Node `hitl_gate(kind, prompt_fn, options)` calls LangGraph `interrupt(payload)`.
- `payload = {kind, prompt, options, context_refs}` where `context_refs` point to blackboard artifacts the human should review.
- Graph pauses; run status → `awaiting_input(gate)`; payload surfaced via API + stream.
- Resume via `Command(resume=decision)`:
  - `approve` → continue on the approved edge.
  - `reject` → route to the author-defined rejection/END edge.
  - `{feedback: "..."}` → write to `state.decisions["<gate>.feedback"]`; the next node's `prompt_fn` consumes it (targeted "give my thoughts").

**API:** `POST /runs/{id}/respond {gate, decision}`.

**UX:** gate card with the prompt, links to `context_refs` artifacts, buttons
Approve / Reject, and a Feedback textarea. Escalation gates are visually distinct
("the agent retried N times — needs your help").

**Guidance:** keep gates **rare, targeted, load-bearing** (solutions-copilot
doc-19 warning: approver fatigue kills adoption). Mandatory before mutations
(write/deploy/data), optional elsewhere.

---

## Mode 2 — Ad-hoc pause / resume anywhere

**What:** the *user* stops a running workflow at any time and resumes later
(possibly after an app restart), from the last checkpoint.

**Mechanism:**
- **Pause:** cooperative — `pause(run_id)` sets a flag; the engine checks it at
  each node boundary and stops cleanly (the completed node is already
  checkpointed). Status → `awaiting_input(paused)`.
  - For an **in-flight** agent node (slow Kiro turn), the turn is cancelled via
    ACP `session/cancel`; the checkpoint is **not** advanced (the node will re-run
    on resume). Partial artifacts are ignored (referenced only on success).
- **Resume:** `resume(run_id)` re-invokes the graph from the last checkpoint.
- Because snapshots are per-superstep, pause/resume is exact and survives restart.

**API:** `POST /runs/{id}/pause`, `POST /runs/{id}/resume`, `POST /runs/{id}/cancel`.

**UX:** Pause/Resume/Cancel buttons on Run Detail; "pausing at next step
boundary…" → "paused — resume / edit / fork".

---

## Mode 3 — Mid-run state injection (edit & continue)

**What:** at any pause (gate or ad-hoc), the user reads and **edits the run's
state**, then continues — the "enhance the agent / give thoughts" capability.

**Mechanism:**
- State is small + human-readable by design (ADR-010), so it's directly editable.
- `PATCH /runs/{id}/state {json-merge-patch}` applies the edit via LangGraph
  `update_state(config, values)` on the checkpointed thread.
- **Editable keys:** `inputs`, `decisions`, workflow-declared `META.editable`
  fields, and `artifacts` *paths*. Bulk artifact **contents** are edited by
  editing the files in the blackboard directly.
- **Read-only keys:** `run_id`, `status`, `cursor`, `retries`, `_validation`, `_last_turn`.
- Server-side validation: the merged state must satisfy the workflow's state
  schema before resume is allowed.
- **Fork (time-travel):** `POST /runs/{id}/fork {from_checkpoint, edits}` creates
  a **new run (new `thread_id`)** seeded from the chosen checkpoint's state via
  `update_state(new_cfg, values, as_node=<producing_node>)` (+ edits), then
  resumes it — the original run is untouched (ADR-025; verified in the spike).
  Note: LangGraph's raw `update_state` on a past checkpoint rewinds the *same*
  thread; Genesis deliberately seeds a new thread instead so the original stays intact.

**API:** `GET /runs/{id}/state`, `PATCH /runs/{id}/state`, `POST /runs/{id}/fork`.

**UX:** a State panel (pretty-printed) with inline editing of whitelisted keys, a
"Resume with changes" action, and a "Fork from here" action on any checkpoint in
the timeline.

---

## Cross-cutting

### Durability
Every mode resumes from a checkpoint; runs survive process restart. The run
record + checkpoints live in `~/.genesis/genesis.db`; artifacts in the blackboard.

### Streaming
While running, the UI streams `updates` (node deltas) + `custom` (agent tool-call
events). At a pause, the stream emits an `awaiting_input` event carrying the gate
payload or the "paused" marker so the UI can render controls.

### Safety
- State edits are validated against the schema; non-editable keys are rejected.
- Cancelling an in-flight agent turn must not corrupt state (checkpoint not
  advanced; partial blackboard writes ignored).
- Mutations (write/deploy) always sit behind a Mode-1 approval gate.

### Studio (interim, M6)
LangGraph Studio provides Mode-1 interrupts, state inspection/editing, and
time-travel out of the box — covering much of this before the custom workbench
(Phase 7) implements the bespoke UX above.

---

## Summary table

| Mode | Trigger | Mechanism | API | Resumes from |
|---|---|---|---|---|
| 1 Approval gate | author-defined node | `interrupt()` / `Command(resume=...)` | `/respond` | the gate |
| 2 Pause/resume | user, anytime | cooperative stop + checkpoint | `/pause` `/resume` | last checkpoint |
| 3 State injection | user, at a pause | `update_state` / `fork` | `/state` `PATCH`, `/fork` | edited checkpoint |
