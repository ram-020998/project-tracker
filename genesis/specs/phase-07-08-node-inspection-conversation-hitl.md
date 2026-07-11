# Phase 7.8 — Run Detail: Node Inspection, Kiro Conversation & HITL Controls

> **Goal:** Make the run legible and controllable. When the user selects a node they
> see exactly what happened there — including the **live Kiro conversation** (the
> agent's messages, thoughts, tool calls, and results) — and when the workflow needs
> a human, the user can **approve, reject, give feedback, pause, resume, cancel, edit
> state, or fork**, all from purpose-built controls surfaced from durable state. This
> is where the platform's full HITL power finally reaches the UI.

> **API paths (ADR-028):** endpoints referenced here are served under **`/api`** (the
> `lib/api` client prepends it centrally; the SSE stream is `/api/runs/{id}/events/stream`);
> non-`/api` paths hit the SPA history fallback.

Prereq: 07-02 (agent.* events, GateDescriptor, respond/pause/resume/fork endpoints),
07-03/07-03a (design system + visual language), 07-07 (screen layout + node selection).
Feature dir: `features/run-detail/components/{inspector,hitl}/`.

> **Visual (per `phase-07-03a`):** the conversation transcript uses the message/tool-
> card treatment (mono for tool args/results, MarkdownView for assistant text,
> collapsible thoughts); the HITL bar uses StatusPill + Button variants. This is a
> Genesis original — Overcut has only a single global chat, not a per-node inspector.

---

## 1. Objective & user stories

- "I click the `fetch_schema` node and watch Kiro call the Atlas tools and stream its
  reasoning and messages, live."
- "The run pauses for my approval on the detected domains; I review, then Approve —
  and it continues. Or I send feedback and it re-runs the step with my notes."
- "Something looks off — I pause, edit a decision in the state, and resume; or I fork
  from an earlier node to try a different path."

---

## 2. Node Inspector

A tabbed panel (bottom or right region from 07-07), bound to the selected node
(`/runs/:runId/node/:nodeId`). Tabs:

1. **Conversation** (agent nodes) — the Kiro transcript (§3). Hidden/"n/a" for pure
   program nodes; program/cli nodes show their inputs/outputs + logs instead.
2. **Inputs / Outputs** — the node's state delta (`node.completed.delta_keys` +
   resolved values from run state) and any blackboard docs it produced (links into
   07-09 preview). Human-readable, not raw dump (raw available in tab 4).
3. **Validation** — the reliability trio outcome for this node: `validator.result`
   checks (name/ok/detail), and any `retry.scheduled` attempts with reasons. Clear
   pass/fail visualization.
4. **Raw** (developer-inspect) — JsonTree of the node's events + delta; copyable.

Header: node label, KindBadge, StatusPill, counters (messages, tool-calls, attempts,
duration). Navigation: prev/next node buttons; deep-linkable.

---

## 3. Kiro conversation transcript (the marquee feature)

Renders the per-node conversation reconstructed from the event log
(`GET /runs/{id}/events?node=<id>&kinds=agent.*` , ordered by `seq`) and tailed live
via the SSE bridge. Message renderers:

| Event | Rendered as |
|---|---|
| `agent.message` | assistant message bubble (markdown via MarkdownView); consecutive chunks coalesced into one growing bubble until `final` |
| `agent.thought` | a muted, collapsible "thinking" block (distinct styling; collapsed by default, expandable) |
| `agent.tool_call` | a **tool-call card**: tool name + title + KindBadge, args preview (JsonTree/CodeBlock), status = pending |
| `agent.tool_update` | updates the matching tool-call card (by `tool_call_id`): status running→ok/failed, result/content preview; expandable |
| `agent.result` | a turn-summary chip: ok/failed, duration, tokens (if present) |
| `validator.result` / `retry.scheduled` | inline system notes between turns (validation ran; retry n scheduled: reason) |

Behavior:
- **Live streaming**: new chunks append and auto-scroll (with a "jump to latest"
  affordance when the user scrolls up). Tool-call cards update in place.
- **Coalescing**: `agent.message` chunk-spam is merged for readability; full text is
  the concatenation.
- **Long transcripts**: virtualized list; lazy-render collapsed thoughts/tool bodies.
- **After the fact**: identical rendering from the durable log for terminal runs (no
  live socket) — this is why 07-02's persistence matters.
- **Empty**: program nodes → "This step ran deterministic code (no agent
  conversation)." Agent node not yet started → "Waiting to start…".
- **Copy/expand**: each message/tool card is copyable; a "view full" opens large tool
  results via the artifact/preview path where a ref exists.

---

## 4. HITL controls (the full model)

Controls are **contextual** and always derived from **durable run state**
(`run.status` + `run.gate`), never from a transient event — this structurally fixes
the current approval bug. Rendered in a prominent **HITL bar** in the inspector
region and mirrored by the header pulse.

### 4.1 Mode 1 — Designed gates (approve / reject / feedback)

Shown when `status == awaiting_input:gate`, driven by `run.gate` (GateDescriptor):
- Panel styled by `gate.kind` (approval / escalation / pre_mutation / review), with
  the `prompt` and links to `context_refs` docs (open in preview, 07-09).
- Buttons from `gate.options`:
  - **Approve** → `POST /respond {decision:"approve"}`.
  - **Reject** → `POST /respond {decision:"reject"}` (ConfirmDialog).
  - **Feedback** → textarea → `POST /respond {decision:{feedback:"…"}}` (re-runs the
    step with notes).
- `pre_mutation` gates get an explicit "this will modify external systems" treatment.
- After respond: optimistic → the run flips to running; the gate node clears; the
  socket resumes tailing. Server validates decision ∈ `gate.options` (surface 400).

### 4.2 Mode 2 — Pause / Resume / Cancel

- **Pause** (`status==running`) → `POST /pause` (kills worker; state safe in
  checkpoint). **Resume** (`status==awaiting_input:paused`) → `POST /resume`.
- **Cancel** (non-terminal) → `POST /cancel` (ConfirmDialog).
- Buttons reflect current status; disabled/hidden when not applicable.

### 4.3 Mode 3 — Edit state & Fork (time-travel)

- **Edit state**: an editor limited to **editable keys** (inputs, decisions,
  workflow-declared) — a structured form where possible (e.g. decision toggles),
  JSON fallback otherwise. `PATCH /state`; guardrails enforced server-side
  (`check_editable`); then Resume. Clear "only editable keys" messaging; surface 400.
- **Fork** (ADR-025): "Fork from this node" → choose seed node (defaults to selected/
  cursor) + optional edits → `POST /fork` → navigates to the new run. Framed as
  "try a different path from here; the original run is untouched."

### 4.4 Safety & UX

- All mutating actions: pending state, success/failure toast, optimistic where safe
  with rollback on error.
- Destructive/irreversible (cancel, reject, fork) → ConfirmDialog with a plain-English
  summary of the effect.
- Controls are keyboard-accessible and announced via `aria-live` when they appear
  (so a gated run is discoverable without watching).

---

## 5. Data & hooks

- `useNodeConversation(runId, nodeId)` — selector over the events cache filtered by
  node + `agent.*|validator.*|retry.*`, coalesced; live via the shared stream.
- `useNodeIO(runId, nodeId)` — delta + docs for the node.
- Mutations: `useRespondGate`, `usePauseRun`, `useResumeRun`, `useCancelRun`,
  `usePatchState`, `useForkRun` — each reconciles run + events cache and toasts.
- `run.gate` from `useRun`; the HITL bar is a pure function of `status`+`gate`.

---

## 6. States

- **Conversation**: streaming / loaded-from-log / empty(program) / not-started /
  error(partial → show what loaded).
- **HITL bar**: none (running, no gate) / gate (mode 1) / paused (resume) / editable
  (mode 3 always available on non-terminal) / terminal (history only, no controls).

---

## 7. Definition of done

1. Selecting a node shows Conversation / I-O / Validation / Raw tabs with accurate
   per-node data.
2. The Kiro transcript renders messages, thoughts, tool calls+updates, and results —
   live for active runs and fully from the durable log for past runs — with coalescing
   and virtualization.
3. All three HITL modes work end-to-end from the UI, surfaced from durable state:
   approve/reject/feedback at gates, pause/resume/cancel, edit-state, fork. The
   approval control is reachable after reload/restart.
4. Mutations are safe (confirm on destructive, toasts, optimistic+rollback);
   controls are keyboard-accessible and announced.
5. Component tests: scripted `agent.*` event fixture renders the transcript; gate
   fixture renders + submits each response; edit-state guardrail rejection surfaces.
