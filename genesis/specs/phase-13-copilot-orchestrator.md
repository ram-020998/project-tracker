# Phase 13 — Chat Copilot & Run Orchestrator (umbrella)

> **Status:** ✅ SHIPPED (genesis v0.25.0 + kiro-agent-sdk v0.5.0; 13-01..06; ADR-033 Accepted) · **Author:** Genesis agent · **Date:** 2026-07-15
> **Goal:** Evolve the read-only Chat (Phase 10) into a **copilot / run-operator**: from a chat session the
> user can trigger any installed workflow via a **slash-command** + schema-driven inputs, the **Kiro agent
> starts the run**, and then **supervises it on the user's behalf** — sensing HITL gates, surfacing the
> options, relaying the user's decision back to the run, and reporting terminal outcomes — **without the
> agent having to stay alive for the whole run**.
> **Repos:** primarily **genesis** (control MCP server, copilot chat mode, supervision bridge, API, web) +
> a small **kiro-agent-sdk** change (interactive permission bridge). **genesis-core** unchanged.
> **Non-negotiable framing:** the agent is a **supervised operator at the run-management layer**, NOT a
> workflow engine — LangGraph still owns every workflow's control flow (ADR-001), and every mutating
> action is **human-confirmed** (new **ADR-033**).

---

## 0. TL;DR

Today Chat is a **read-only** assistant (ADR-031): it answers questions using the Atlas read MCP and a
read-only Genesis-introspection MCP server. Phase 13 makes it a **copilot** that can *act* — but only at the
**run-management layer**, and only with **explicit human confirmation** for each mutating action.

The design is the industry-standard **"agent orchestrates, durable engine executes"** pattern (Microsoft
Durable Task "Agentic Application Patterns", Airflow-MCP, OpenAI Codex-as-MCP-server): a **durable
orchestrator sits between the stateless agent and execution**. In Genesis that orchestrator already exists
— **LangGraph + `RunManager`** own the run and its checkpointed HITL gates. The copilot is simply a new
**client** of that orchestrator, exactly like the human operator using the Runs UI. It never becomes the
control flow.

Four pillars:
1. **A write-capable Genesis Control MCP server** (`genesis/mcp/control_server.py`) — the sibling of the
   read-only introspection server — exposing run-management as tools (`start_run`, `get_run_status`,
   `get_pending_gate`, `respond_to_gate`, `cancel_run`, `list_launchable_workflows`,
   `get_workflow_inputs_schema`, `list_session_runs`). It is a **thin MCP→HTTP facade over the existing
   `/api` surface**, so `RunManager` stays the single source of truth (input validation, subprocess
   supervisor, durable state).
2. **Human-confirmed actions via ACP's native permission mechanism** — read tools are trusted (no prompt);
   **mutating tools are left UNTRUSTED**, so each call fires `session/request_permission`, which a new SDK
   **`permission_mode="ask"`** bridge routes to a **confirm card in chat**. The user allows/denies; the SDK
   returns the decision (timeout → deny). No dependence on (client-unsupported) MCP elicitation.
3. **An event-driven supervision bridge** — the agent need not stay alive. A `ChatRunSupervisor` in the app
   process watches `RunManager`'s event stream for **runs linked to a chat session**; on `gate.awaiting` or
   `run.final` it emits a **notification** and injects a proactive **"nudge" turn** so the copilot surfaces
   the gate + options in the conversation. The user replies; the agent calls `respond_to_gate` (confirmed).
4. **A slash-command launch UX** — typing `/` in the composer opens a **workflow palette** (from the
   catalog); selecting one opens the **schema-driven launch dialog** (reusing the Phase 07-05 Catalog launch
   form); on submit the UI hands the agent an instruction to start that workflow with those exact inputs, so
   the **agent is the actor** that starts the run (per the user's ask), and supervision begins.

**Net:** the chat becomes a conversational operator for runs, with the durable engine + human confirmation
keeping it safe and auditable. Nothing about the workflow-execution model changes.

---

## 1. Motivation & user story

> *"When I type `/` in chat, show me the workflows. I pick one, get a dialog for its inputs, and on submit
> the Kiro agent starts the run with those values and supervises it. It need not watch continuously, but it
> should track the run and act on it — e.g. when the run is waiting at a manual approval gate, the agent
> senses it, presents the options to me, I give my decision, and the agent sends it to the workflow. Expose
> the run's actions as MCP tools."*

This is a **conversational run operator** — a very common enterprise pattern (Slack workflow bots, Copilot
Studio agents, ChatOps). The scarce, valuable thing the copilot adds over the Runs UI is **attention
management**: the user launches-and-forgets, and the copilot re-engages them exactly when a human decision
is required, in natural language, with the run's context already loaded.

---

## 2. Architectural position & the ADR-001 / ADR-031 reconciliation (the crux)

Two locked decisions appear to conflict with "the agent orchestrates runs":
- **ADR-001** — *LangGraph owns control flow; agents never orchestrate.*
- **ADR-031** — *Chat is a read-only assistant; it observes/answers, never drives or mutates.*

**Resolution (ADR-033, drafted in 13-02).** Distinguish **two layers**:

| Layer | Owner | Phase 13 stance |
|---|---|---|
| **Workflow control flow** (which node runs next, gates, retries, loops) | **LangGraph** (per ADR-001) | **Unchanged.** The copilot cannot alter it. |
| **Run management** (start a run, read its status, answer its gates, cancel) | The **operator** (a human in the Runs UI today) | The copilot becomes a **second operator client** at this layer. |

Starting a run, reading its state, and answering a gate are exactly what the **human operator already does
through the Runs UI** — they are *not* orchestration of the workflow's internal control flow. The copilot
performs the same operator actions through the same `RunManager` API. So:
- **ADR-001 is preserved** — the agent is never the workflow engine; it calls the same durable API a human
  clicks. The workflow's own HITL gates still pause the graph and still require a human decision; the copilot
  **relays** that decision, it cannot invent or auto-approve it.
- **ADR-031 is refined, not broken** — Chat is no longer *strictly* read-only, but every mutation is (a) at
  the run-management layer only, (b) **human-confirmed** (launch dialog for `start_run`; per-call permission
  card for `respond_to_gate`/`cancel_run`), (c) unable to touch config, secrets, workflow definitions, the
  registry, or deployments. A read-only chat mode remains available and is the default for sessions that
  never launch anything.

This is precisely the researched industry pattern: **"Skills/agents orchestrate; MCP tools execute; a
durable orchestrator converts stateless agent requests into stateful workflows."** The copilot orchestrates
*at the operator layer*; LangGraph remains the stateful engine.

---

## 3. System overview

```
        ┌──────────────────────────── Genesis app process (FastAPI) ────────────────────────────┐
        │                                                                                        │
 ┌────────────┐   SSE (events, notifications, permission requests)    ┌──────────────────────┐  │
 │  Web Chat  │◀──────────────────────────────────────────────────── │      ChatManager      │  │
 │  (React)   │   POST turn / POST permission decision / POST launch  │  (copilot sessions)   │  │
 └────────────┘ ─────────────────────────────────────────────────▶   └──────────┬───────────┘  │
        ▲  slash palette + launch dialog + gate/confirm cards                    │ prompt()      │
        │                                                          persistent ACP │  (per turn)   │
        │                                                          ┌──────────────▼────────────┐ │
        │                                                          │  KiroACPClient (SDK)      │ │
        │                                                          │  permission_mode="ask" ───┼─┼──▶ confirm card
        │                                                          └──────────────┬────────────┘ │      (13-01 bridge)
        │                                                    stdio MCP             │ tool calls   │
        │                                          ┌───────────────────────────────▼───────────┐ │
        │                                          │  Genesis Control MCP server (13-02)        │ │
        │                                          │  start_run / get_run_status /              │ │
        │                                          │  get_pending_gate / respond_to_gate / …    │ │
        │                                          └───────────────────────────────┬───────────┘ │
        │                                                    HTTP  /api/runs, /api/catalog        │
        │                                          ┌───────────────────────────────▼───────────┐ │
 ┌───────────────────┐   subscribes EventBus       │            RunManager  +  API              │ │
 │ ChatRunSupervisor │◀───────────────────────────│  (start/respond/gate/cancel; durable)      │ │
 │  (13-03)          │   gate.awaiting/run.final    └───────────────────────────────┬───────────┘ │
 │  → session nudge  │ ─────────────────────────────────────────────────────────── │ subprocess   │
 └───────────────────┘                                                              ▼  worker      │
        └──────────────────────────────────────────────────────────────── LangGraph run (ADR-012) ┘
```

Key properties:
- **`RunManager` is the single source of truth.** The control MCP server never writes state directly; it
  calls the same `/api` endpoints the UI uses. This keeps input validation, the subprocess supervisor,
  durable checkpoints, gate-from-checkpoint, and credit metering unchanged and un-duplicated.
- **The copilot is stateless per turn** (like all Kiro turns). Durability lives in `RunManager` + the
  chat persistence tables. The supervisor re-engages the copilot via a nudge — no long-lived agent loop.
- **Every mutation is human-confirmed** — either by the launch dialog (`start_run`) or a per-call permission
  card (`respond_to_gate`, `cancel_run`). Read tools (`get_run_status`, `list_*`, `get_pending_gate`) are
  trusted and silent.

---

## 4. The async-supervision model (how the copilot "senses" a gate without staying alive)

A Kiro turn is request/response: after answering, the session idles. A run is long-lived and hits gates
asynchronously. Bridging the two is the core mechanism (13-03):

1. **Link** — when the copilot starts a run, the backend records a `chat_run_link` (session_id ↔ run_id) so
   the run is "owned" by that chat session.
2. **Watch** — a single `ChatRunSupervisor` subscribes to `RunManager`'s `EventBus`. For events on linked
   runs it reacts to two canonical kinds: `gate.awaiting` and `run.final`.
3. **Notify** — it writes a durable **notification** (per session) + pushes it over the chat SSE, so the UI
   can render a **gate card / terminal card** immediately even if the agent is idle.
4. **Nudge (proactive turn)** — it injects a **system-authored turn** into the session ("Run `r-…` for
   *ERD Generation* is awaiting approval at gate *approve-domains*. Options: approve / reject / feedback.
   Surface this to the user and collect their decision."). The copilot renders the gate + options
   conversationally. The user's reply → the agent calls `respond_to_gate` (confirmed) → `RunManager` resumes
   the durable graph via `Command(resume=…)`.
5. **Reconnect / catch-up** — on app restart or a reconnecting client, pending gates are recovered from
   durable state (`RunManager.pending_gate`) and the `EventLog`, so nothing is missed (no reliance on a live
   in-memory subscription).
6. **SLA / timeout** — a linked run left awaiting beyond a configurable window re-nudges (and can surface a
   "still waiting" chip); the copilot never auto-answers.

This is the researched **event-driven re-engagement** pattern (LangGraph Agent Inbox surfaces interrupts; we
bridge them into the conversation). Polling is also supported: the user can ask "what's the status of my
runs?" any time and the agent calls `list_session_runs` / `get_run_status`.

---

## 5. Sub-phases (each has its own detailed spec under `phase-13-copilot-orchestrator/`)

| Sub-phase | Title | Repos | Outcome |
|---|---|---|---|
| **13-01** | SDK interactive permission bridge | kiro-agent-sdk | `permission_mode="ask"` + an async permission callback; the client forwards `session/request_permission` to it and returns the decision (timeout→deny). Spike proves kiro-cli fires `request_permission` for **untrusted** MCP tool calls. The load-bearing enabler for human-confirmed agent actions. |
| **13-02** | Genesis Control MCP server + ADR-033 | genesis | `genesis/mcp/control_server.py` — write-capable stdio MCP server proxying `/api` (start/status/gate/respond/cancel/catalog/schema). ADR-033 records the copilot boundary. |
| **13-03** | Copilot chat mode + run↔session link | genesis | Extend `ChatManager`/`build_chat_mcp` with a **copilot** session mode (adds the control server; read tools trusted, mutating tools untrusted + permission-ask bridged to chat); `m0004 chat_run_links`; orchestration steering; a per-session `mode` flag. |
| **13-04** | Run-supervision bridge | genesis | `ChatRunSupervisor` (EventBus subscription for linked runs → notifications + proactive nudge turns), notification persistence + SSE, SLA/timeout, reconnect catch-up. |
| **13-05** | Slash-command launch & in-chat HITL/confirm UI | genesis (web) | Composer `/` palette (catalog), schema-driven launch dialog (reuse 07-05 form), permission-confirm cards, gate cards, terminal notifications, supervised-runs strip; `permission.request` + `run.notification` SSE streams. |
| **13-06** | Safety, audit, advanced-gate patterns + integration & release | genesis | Scope/rate limits, agent-action audit log, conditional/batch/timeout gate handling, copilot kill-switch; E2E + live acceptance; ADR-033 finalized; tracker/onboarding; release chain. |

**Sequencing rationale:** 13-01 is the safety enabler and must land first (a spike de-risks it). 13-02 gives
the agent hands (read-only-usable immediately). 13-03 makes chat a copilot. 13-04 adds the sensing. 13-05 is
the UX that makes it feel like a copilot. 13-06 hardens + ships. Each sub-phase is independently valuable
and testable.

---

## 6. Release chain & versioning (ADR-019)

`kiro-agent-sdk` (13-01, minor: additive `permission_mode="ask"` + callback) → `genesis` (13-02..13-06:
control server + copilot mode + supervisor + api + web + m0004; direct sdk pin bump). **`genesis-core` is
expected to need no change** (the control server lives in `genesis` like the introspection server; the
permission bridge is SDK + `genesis`). Every `web/src` change rebuilds + commits `web/static` (CI stale-bundle
guard). Frontend-only changes still ship a `genesis` release.

---

## 7. Cross-cutting non-negotiables (carried from the ADRs)

- **ADR-001 preserved** — LangGraph owns control flow; the copilot only operates the run-management API.
- **ADR-012** — chat runs **in-process** (it executes no workflow Python; the agent is isolated as the
  kiro-cli subprocess). The *workflow* still runs in its subprocess worker; the copilot just calls the API.
- **ADR-021** — the workflow's own `pre_mutation`/approval/escalation gates are untouched; the copilot
  relays decisions to them, it cannot bypass or auto-approve them.
- **ADR-028** — all new endpoints under `/api`; the web client prepends `/api` centrally.
- **ADR-029** — the control server's authority is scoped by its tool set (run-management only); it exposes
  **no** config/secret/registry/deploy tools.
- **ADR-033 (new)** — the copilot boundary (this phase). See 13-02.

---

## 8. Risks & open questions (resolved per sub-phase)

- **R1 — does kiro-cli fire `session/request_permission` for untrusted MCP tools?** Load-bearing for the
  confirm-card model. **Spike in 13-01** before building anything else. Fallback if not: a UI-mediated
  pending-action confirmation (agent's mutating tool returns "pending" + the UI confirms + a release
  endpoint executes) — more moving parts but no SDK dependency.
- **R2 — proactive "nudge" turns must not fight a user turn.** The session lock (one active turn) already
  serializes; nudges queue behind any in-flight user turn and are de-duplicated per (run, gate).
- **R3 — agent fabricating a decision.** Mitigated structurally: `respond_to_gate`/`cancel_run` are
  untrusted → every call needs a human confirm card; the launch dialog is the confirm for `start_run`;
  audit log (13-06) records every agent-initiated action with the confirming user event.
- **R4 — control server ↔ API auth on localhost.** Single-user localhost (ADR-026); the control server
  targets `127.0.0.1:<port>`; add a per-process shared token so only the co-launched server can call the
  control endpoints (13-02).
- **Q1 — copilot default on or opt-in per session?** Recommend a per-session **mode** (`read_only` default,
  `copilot` when the user first launches something or toggles it) so existing read-only chat is unchanged.
- **Q2 — multiple runs per session.** Supported via `list_session_runs`; the supervisor tracks all linked
  runs; nudges name the run explicitly.

## 9. Out of scope (this phase)
- Autonomous multi-step orchestration without per-action human confirmation.
- The copilot editing workflows, config, secrets, the registry, or deploying.
- Multi-user / shared sessions (ADR-026 remains single-user).
- Cross-session run ownership hand-off.
