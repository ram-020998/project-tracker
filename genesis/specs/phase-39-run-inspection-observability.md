# Phase 39 — Run Inspection & Node Observability (the run-detail deep-dive)

> **Status:** 🟡 **DRAFT — spec only; awaiting user sign-off at 39-01 before any build.** ADR-066 (Proposed). Umbrella + `phase-39-run-inspection-observability/39-01..39-07`. · **Author:** Genesis agent (2026-09-10)
> **Type:** multi-repo — **genesis-core** (per-turn prompt/artifact/iteration capture + a generic `_iteration` grouping convention), **genesis** (a per-iteration fold + endpoint + topology `description` passthrough + the web run-detail redesign), **genesis-workflows** (a `description` on every `graph:` node + `_iteration` stamps in loop/heal program nodes). kiro-agent-sdk / genesis-appian-parser **unchanged**. · **Depends on:** Phase 07-02/07-08 (the durable event log + node inspector + `fold_steps`), Phase 11/ADR-032 (per-turn metered credits on `agent.result`), Phase 30 v0.58.0 (`/steps` authoritative + `fold_transitions` + per-node `executions`).

---

## 1. Why this phase exists

The run-detail page is the **core of Genesis** — it is where a user understands what a workflow actually did.
Today, clicking a node dumps *everything* (conversation + inputs/outputs + validation + raw) into one below-graph
panel, yet paradoxically shows **too little of what matters**: you cannot see **what prompt the agent was given,
what artifacts/context it received, what it produced per iteration, or how many credits/how long each iteration
took**. For an agent node that ran 10 loop iterations and 2 retries, the panel is one flattened blob.

Two concrete gaps, grounded in the code:
1. **The prompt is never persisted.** `kiro_node` computes `prompt = prompt_fn(...)` but only emits `agent_start`
   (with the MCP list) — the prompt text, the attached image docs, and the injected context are **not** captured
   as events. So "what was fed to the model" is unrecoverable today.
2. **Everything is aggregated per node.** `runs/steps.py::fold_steps` gives one summary per node (status,
   `attempts`, `executions`, `tool_calls`, `messages`, summed `credits`, one `duration_ms`). There is **no
   per-iteration breakdown**, no per-execution timing/credits, and **no node `description`** anywhere.

**This phase rebuilds the run-detail node experience into a two-level, information-rich inspector** that shows,
for every iteration of every node, exactly what went in (prompt + artifacts), what happened (thinking / messages
/ tool calls), what came out (artifact + state delta), and what it cost (credits / context / time) — presented in
a way that **adapts to how the node actually re-executed** (loop iterations, reliability retries, and — with
Phase 40 — heal passes). This is the standard agent-trace-inspection UX (LangSmith-style: per-step inputs, prompt
sent, output, timing, token/credit cost, errors) brought to Genesis.

---

## 2. Goal

1. **Single-click = a concise summary.** Clicking a node shows, in the below-graph pane, **the node's
   description first**, then **basic metrics**: number of executions, **per-execution response time**,
   per-execution + total credits, tool-calls, status. No walls of transcript.
2. **A `description` on every node.** A new authored `description` field on each workflow's `graph:` nodes
   explains, in plain language, **what the node is supposed to do**. Surfaced at the top of the summary pane.
3. **"View details" / double-click = a large modal — the adaptive turn explorer.** A full-height modal whose
   **left rail is an adaptive tree of the node's turns**, collapsing to exactly the depth reality needs, and
   whose **right pane shows the selected turn's full detail**. For an **agent** turn the detail includes:
   **Prompt** (the exact text sent to the model) · **Artifacts / inputs provided** (attached docs, images,
   upstream artifacts) · **Conversation** (thinking + messages + tool calls, in order) · **Output** (the doc it
   wrote + the state delta) · **Metrics** (credits, context %, tool calls, duration, stop reason, errors).
   **Nothing is hidden** — the user sees precisely what the model received and produced.
4. **The turn explorer adapts** (see §3). One clear vocabulary — **Pass › Item › Attempt › Turn** — shown only to
   the depth that occurred, so a single-shot node shows one turn while a 30-turn loop node shows a grouped tree.

**Success = opening any node on a new run, reading its description + at-a-glance per-execution metrics, then
drilling into any single iteration to see the full prompt, the artifacts it was given, its conversation, its
output, and its exact credit/latency cost — with the navigation matching how that node actually ran.**

---

## 3. The iteration model (analyzed & locked with the user, 2026-09-10)

A node re-executes for **three independent reasons**, each from a real mechanism in the code:

| Dimension | Mechanism | Counter / source |
|---|---|---|
| **Attempt** (node-level) | reliability trio re-runs the *same* node after its validator failed | `retries[node]` / `retry.scheduled` (agent already computes `attempt = retries+1`) |
| **Item** (loop-level) | a MAP loop runs the node once per work-unit (epic / workstream / object / screen) | the loop program node (e.g. `_next_epic` pops the queue) |
| **Pass** (workflow-level) | the whole sub-graph re-runs (today's verify-revise; Phase 40's heal restart) | `decisions.verify_rounds` / Phase-40 pass counter |

A **Turn** (one model call = one `agent.result`) is the leaf, identified by **(Pass, Item, Attempt)**. Crucially
**most nodes exercise only one dimension** — a rigid fixed nesting would show mostly-empty levels. So the explorer
is **adaptive**: it renders only the dimensions that actually occurred.

- single-shot agent, no retry → **just the turn** (no tree).
- single-shot + retries → a flat list: `Attempt 1 — failed validation`, `Attempt 2 — ok`.
- MAP-loop node → grouped **by Item** (`Round 1 · epic: Intake`, `Round 2 · epic: Review`…), each Item expandable
  to its Attempts if it retried.
- a heal/verification restart occurred → an outer **Pass** level wraps the above (`Pass 1` / `Pass 2 · after heal`).

Every leaf carries scan-chips: status (ok/failed), ✕retry, credits, duration. The right pane always shows the
selected turn's full detail. This is the LangSmith/Braintrust span-tree convention (depth = reality).

**Enabling convention (generic):** `kiro_node` is workflow-agnostic and cannot know "epic". A **reserved
`state["_iteration"]` key** — `{pass:int, item_label:str|None, item_index:int|None}` — is stamped by the loop/heal
**program** nodes; `kiro_node` copies it onto the turn's capture events. The UI groups by those labels. Turns with
no `_iteration` render as a simple attempt list. (This convention is shared with Phase 40's `pass`.)

---

## 4. Constraints & decisions (locked with the user, 2026-09-10)

1. **Two-level disclosure:** single-click → summary (description + basic metrics); "View details" / double-click →
   a **very large modal** (not a full page).
2. **Iteration labels:** the adaptive **Pass › Item › Attempt › Turn** model of §3; a **left-rail selector**
   navigates passes/items; each turn is individually inspectable.
3. **Prompt storage:** the exact rendered prompt is **written to a per-turn blackboard file** and referenced by a
   pointer event — **never inlined** into `run_events` (prompts embed large spec/UX/TD text; ADR-010/018). The
   modal fetches it lazily.
4. **New runs only.** No backfill for historical runs (they never captured prompts). Acceptable.
5. **Program / validator nodes:** the **summary is enough**; additionally show any **artifact generated in that
   iteration**. The full per-turn agent detail (prompt/conversation) is agent-node-only.
6. **Descriptions are authored** per node in each `workflow.yaml` `graph:` block (existing workflows updated in one
   pass; a standing rule for new workflows). Not auto-generated.
7. **A coded hi-fi mockup at `/dev`** is approved **before** the real wiring (the Phase 27–29 convention), because
   this is a heavy-UX surface.

---

## 5. Current state (what we build on) — code-grounded

- **Event capture (`genesis-core/nodes/agent.py`).** Emits `agent_start{node,mcp}`, streamed
  `agent.message|thought|tool_call|tool_update`, and `agent.result{ok,stop_reason,error,tool_calls,duration_ms,
  credits,context_pct,turn_duration_ms,provenance}` (+ `agent_end`, `tool_output.recorded`, `artifact.saved`). It
  **computes `attempt = retries[name]+1`** already. **The prompt text + attached `image_docs` are NOT emitted** —
  this is the core capture gap.
- **Manager persistence.** `_CANONICAL_CUSTOM` persists `agent.result` verbatim into `run_events`, so any field we
  add to it (e.g. `attempt`, `iteration`) reaches the fold + SSE for free (the Phase-11 pattern).
- **Folds (`runs/steps.py`).** `fold_steps` → per-node aggregate (incl. `executions` = count of `node.completed`,
  `attempts` = max retry); `fold_transitions` → the executed-path edge counts. Neither segments per turn.
- **Endpoints.** `GET /runs/{id}/events?node=` (server-side node filter — the perf fix), `/steps`, `/transitions`.
  The Inspector (`web/.../components/Inspector.tsx`) fetches `?node=` events, folds via `buildTranscript`, renders
  4 tabs. `panels.tsx` shows state `delta_keys` (Inputs/Outputs), validator checks (Validation), raw events (Raw).
- **Topology.** `workflow.yaml` `graph.nodes[]` = `{id,label,kind,mcp?,gate_kind?}` (UI-only, exempt from META
  parity). Surfaced via `/workflows/{id}/graph` → `GraphTopology`/`GraphNode` (`web/src/types/catalog.ts`) → the
  run-detail graph + Inspector. **No `description` field today.**

**Takeaway:** additively (a) capture the prompt (as a blackboard-file pointer) + attached artifacts + the
`_iteration` label + `attempt` on the turn events; (b) add a per-iteration fold + endpoint; (c) add
`GraphNode.description`; (d) rebuild the web inspector into the summary pane + the adaptive turn-explorer modal;
(e) author node descriptions across the workflows. No SDK change; no genesis.db migration (this is event-log +
blackboard, not schema).

---

## 6. Data capture & backend (finalized in 39-01/02/03)

- **genesis-core `agent.py` (additive):** before the turn, write the rendered `prompt` to a blackboard file
  (e.g. `_prompts/<node>-<attempt>-<ts>.txt`) and emit **`agent.prompt`** `{node, prompt_ref, model,
  mcp, tools (effective), image_docs:[...], iteration: state.get("_iteration"), attempt}`. Add `attempt` +
  `iteration` to the existing `agent.result`. Everything rides `run_events` via `_CANONICAL_CUSTOM`. The prompt
  file is a normal blackboard doc (openable/previewable); it is **excluded from `_KEEP_ARTIFACTS` cleanup only if
  we choose to keep it — decision in 39-01** (default: keep prompts; they are the point of this phase).
- **The `_iteration` convention:** a reserved state key stamped by loop/heal program nodes; documented in the
  workflow-authoring standard. genesis-core reads it opaquely.
- **genesis `runs/steps.py` — a new `fold_iterations(events)`** → per node, an ordered list of **turns**:
  `{pass, item_label, item_index, attempt, seq_start, seq_end, status, duration_ms, credits, context_pct,
  tool_calls, prompt_ref, output_artifacts:[...] }`, grouped into the Pass › Item › Attempt tree. Framework-free
  (reused by the introspection MCP, like `fold_steps`).
- **Endpoint:** `GET /runs/{id}/nodes/{node}/iterations` (or extend `/steps` with an `iterations` block) returning
  the fold; the modal fetches this + lazily `GET /runs/{id}/artifacts/{prompt_ref}` for a selected turn's prompt.
- **Topology:** `GraphNode` gains optional `description`; `/workflows/{id}/graph` + the run topology pass it
  through; `web/src/types/catalog.ts` mirrors it.

---

## 7. Web (finalized in 39-01 mockup → 39-04)

- **Summary pane (single-click, below the graph):** `description` (prominent) → a compact metrics strip
  (executions, per-execution response times, credits per-execution + total, tool-calls, status) → a **"View
  details"** button. The current 4 heavy tabs move into the modal.
- **The adaptive turn-explorer modal (`NodeIterationsDialog`):** a very large modal; **left rail** = the adaptive
  Pass › Item › Attempt tree (§3) with scan-chips; **right pane** = the selected turn's detail sections — Prompt
  (lazy) · Artifacts/inputs provided · Conversation (reuse the existing `Conversation`/`TurnView` fold) · Output
  (doc + state delta, reuse `InputsOutputsPanel`) · Metrics. Program/validator turns show summary + generated
  artifact only.
- Double-click a graph node also opens the modal. jest-axe on the modal + tree; keyboard-navigable tree.
- **`/dev` mockup** of the whole thing first (39-01), approved before 39-04 wiring. `web/static` committed.

---

## 8. ADR

- **ADR-066 (PROPOSED — this phase): Run inspection & node observability — capture what the agent was given and
  produced, per iteration.** genesis-core additively **captures the rendered prompt (as a blackboard-file pointer),
  attached artifacts, the `_iteration` grouping label, and `attempt`** on the turn events (no schema change — event
  log + blackboard, honoring ADR-010/018 "no bulk inline"). A generic **`_iteration` state convention** lets
  workflow-agnostic `kiro_node` label loop/pass turns. genesis adds a **per-iteration fold + endpoint** and a
  **`GraphNode.description`** passthrough. The web run-detail becomes **single-click summary (description + metrics)
  + a large adaptive turn-explorer modal** (Pass › Item › Attempt › Turn, depth = reality) exposing the full
  prompt / artifacts / conversation / output / metrics per turn. New runs only. Reuses Phase-11 metering + the
  `_CANONICAL_CUSTOM` verbatim-persist pattern. Mirror in `reference/decision-log.md` + (on Accept) `bible/04`.

---

## 9. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **39-01** | Research, contracts, ADR & **mockup** | Lock the capture events (`agent.prompt` + `agent.result` additions), the `_iteration` convention, the `fold_iterations`/endpoint contract, the `GraphNode.description` passthrough, and the prompt-file retention rule; draft **ADR-066**; a coded **hi-fi mockup at `/dev`** of the summary pane + adaptive turn-explorer modal. **Docs + mockup only.** | ⭐ user sign-off → build |
| **39-02** | genesis-core: capture | `agent.py` writes the prompt file + emits `agent.prompt`; adds `attempt`+`iteration` to `agent.result`; the `_iteration` convention documented; tests (stubbed collect). Additive, `CORE_MAJOR` unchanged. | independent review = SHIP |
| **39-03** | genesis: fold + endpoint + topology | `fold_iterations` + `GET /runs/{id}/nodes/{node}/iterations`; `GraphNode.description` through `/workflows/{id}/graph` + run topology; tests. | independent review = SHIP |
| **39-04** | genesis web: summary pane + modal | The single-click summary (description + metrics) + the `NodeIterationsDialog` adaptive turn explorer (lazy prompt fetch, per-turn detail, program/validator summary), matching the approved mockup; jest-axe; `web/static` committed. | independent review = SHIP |
| **39-05** | genesis-workflows: descriptions + `_iteration` stamps | Add an authored `description` to **every** `graph:` node across all workflows; stamp `state["_iteration"]` in each loop/heal program node; the authoring-standard rule. | independent review = SHIP |
| **39-06** | Code review & hardening | Independent review (no bulk-in-events, prompt-file size/retention, secrets-in-prompt handling, adaptive-tree degeneracy cases, a11y/dark-parity/contract fixtures, new-runs-only honesty); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **39-07** | Coordinated release | genesis-core vX.Y.Z → genesis vX.Y.0 (re-pin) → genesis-workflows vX.Y.0 (descriptions); tags; CI green; docs (bible §2/§3/§4/§7 + tracker + progress + ADR-066 → Accepted). | CI green |

**Suggested order:** 39-01 → 39-02 → 39-03 → 39-04 → 39-05 → 39-06 → 39-07 (linear; each gated on the prior).

---

## 10. Release plan

Multi-repo, ADR-019 order: **genesis-core → genesis → genesis-workflows**. genesis-core is additive
(`CORE_MAJOR` unchanged). **No genesis.db migration** (event-log + blackboard only). Per sub-phase: build → gates
(pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`) → local commit → independent review → docs;
**no tag/push until 39-07** on the user's go-ahead. kiro-agent-sdk + genesis-appian-parser unchanged.

---

## 11. Scope

**In scope:** per-turn prompt/artifact/`_iteration`/`attempt` capture (blackboard-file pointer + events); the
`_iteration` convention; `fold_iterations` + the iterations endpoint; `GraphNode.description`; the redesigned
run-detail (single-click summary + adaptive turn-explorer modal with full per-turn prompt/artifacts/conversation/
output/metrics); node descriptions authored across all workflows; a `/dev` mockup.

**Out of scope:** backfill for historical runs; a genesis.db schema change; changing what the agent runtime does
(capture is observational only); cross-run comparison/eval dashboards; exporting traces to an external
observability platform; the healing loop (Phase 40 — this phase only *displays* passes it produces).

---

## 12. Open questions

None blocking — the approach + the adaptive turn-explorer are approved (2026-09-10). Detail decisions for 39-01:
prompt-file retention (default keep) & any secret-redaction of captured prompts; whether the iterations fold is a
new endpoint vs a `/steps` extension; exact per-turn artifact attribution for program nodes.
