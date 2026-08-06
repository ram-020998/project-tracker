# Phase 13-04 — Run-Supervision Bridge (async gate/terminal → chat)

> **Status:** ✅ SHIPPED (Phase 13 complete — 13-01..06; see `progress/phase-13-copilot-orchestrator.md`) · **Repo:** genesis · **Depends on:** 13-03 (copilot mode + run↔session link)
> **Goal:** Make the copilot **sense** what happens to a run it started, without staying alive. A
> `ChatRunSupervisor` watches `RunManager` events for session-linked runs and, on a gate or terminal event,
> notifies the session and injects a proactive **nudge** turn so the copilot surfaces the gate + options to
> the user — the "it should be able to track it and make decisions on it" requirement.

---

## 1. The mechanism (event-driven re-engagement)

`RunManager` already emits canonical events on a single in-memory `EventBus` and persists them to the durable
`EventLog`. The supervisor uses both:

1. **Subscribe** — one `ChatRunSupervisor`, created with the app, subscribes to the `EventBus`. For each
   event it checks `chat_run_links` (13-03): is this `run_id` owned by a chat session? If not, ignore.
2. **React to two kinds** — `gate.awaiting` (a HITL gate paused the run) and `run.final` (done/failed/
   cancelled). Everything else is ignored for notification purposes (the UI still streams full events for a
   supervised run if the user opens it).
3. **Notify (durable)** — write a `chat_notification` row (session_id, run_id, kind, payload, created_at,
   consumed_at) and push it over the session SSE so the UI can render a card immediately.
4. **Nudge (proactive turn)** — enqueue a **system-authored turn** on the session and, when the session is
   idle, run it through the copilot so it speaks up:
   - gate: *"Run `r-…` (**ERD Generation**) is waiting at the **approve-domains** gate — {prompt}. Options:
     approve / reject / feedback. Context: {artifact refs}. What would you like to do?"*
   - terminal: *"Run `r-…` finished: **done** — verdict *Approved with Comments*. Summary: …"*
   The nudge is delivered as a distinct system message so it never masquerades as the user.

The user answers in natural language → the copilot calls `respond_to_gate` (untrusted → confirm card,
13-01/13-03) → `RunManager` resumes the durable graph via `Command(resume=…)`.

## 2. Concurrency, idempotence, ordering

- **Session lock** — `ChatSession` allows one active turn. A nudge **queues** behind any in-flight user turn
  and runs when idle (or is delivered as a passive notification card if the user is mid-conversation, then
  the agent references it on the next turn).
- **De-duplication** — a nudge is keyed by `(run_id, gate_node, raised_at)` so a replayed/duplicated event
  never double-nudges. Terminal nudges keyed by `(run_id, "final")`.
- **Ordering** — notifications are appended in event order; the UI renders them chronologically inline.

## 3. Durability & catch-up (no reliance on a live subscription)

- On **app restart**, the in-memory `EventBus` subscription is gone, but state isn't lost: on startup (and on
  each SSE (re)connect for a session) the supervisor **reconciles** — for every linked, non-terminal run it
  calls `RunManager.pending_gate(run_id)`; if a gate is pending and no un-consumed notification exists, it
  creates one + nudges. Terminal runs since last seen are detected from the `EventLog` / `RunStore` status.
- This makes the bridge **level-triggered** (reconcile against durable truth), not purely edge-triggered
  (live events) — the standard robust pattern (Kubernetes-style reconcile), matching the existing
  `useRunStream` backstop philosophy.

## 4. SLA / timeout (advanced-gate hygiene; from research)

- A configurable `copilot_gate_sla_minutes`: a linked run awaiting a decision beyond the SLA triggers a
  **re-nudge** ("still waiting on run `r-…`") and a persistent "needs you" chip. The copilot **never**
  auto-answers — timeout escalates attention, it does not decide.
- Terminal notifications have no SLA.

## 5. Notification API + SSE

- `chat_notification` store (part of `m0004` or a small `m0005`): CRUD + `list_unconsumed(session)` +
  `mark_consumed`.
- SSE: extend the session stream with `run.notification` (gate/terminal) and (from 13-03) `permission.request`
  events. `GET /api/chat/sessions/{id}/notifications` for cold load; `POST …/notifications/{id}/ack`.

## 6. Files & tests
- `genesis/chat/supervisor.py` — `ChatRunSupervisor` (subscribe, filter by link, notify, nudge, reconcile,
  SLA); wired in `create_app` alongside `RunManager` + `ChatManager`.
- `genesis/chat/store.py` — `ChatNotificationStore`.
- `genesis/chat/manager.py` — `enqueue_system_turn(session_id, text)` (nudge injection respecting the lock).
- `genesis/api/chat.py` — notification list/ack + the SSE additions.
- `tests/test_supervisor.py` — feed synthetic `gate.awaiting`/`run.final` for a linked vs unlinked run →
  assert notify + nudge only for linked; de-dup on replay; reconcile after a simulated restart recovers a
  pending gate; SLA re-nudge; nudge queues behind an active turn.

## 7. Acceptance criteria
1. A gate on a session-linked run produces exactly one notification + one nudge; the copilot surfaces the
   gate + options; the user's decision reaches the run and resumes it.
2. Terminal outcomes notify once. Unlinked runs never notify a session.
3. After an app restart, a still-pending gate on a linked run is recovered and surfaced (level-triggered
   reconcile). SLA re-nudges; the copilot never auto-answers.

## 8. Out of scope
- Rendering (13-05). Audit/limits (13-06).
