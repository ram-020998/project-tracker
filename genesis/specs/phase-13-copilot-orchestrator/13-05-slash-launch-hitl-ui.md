# Phase 13-05 — Slash-Command Launch & In-Chat HITL/Confirm UI

> **Status:** DRAFT (planning) · **Repo:** genesis (web) · **Depends on:** 13-02/13-03/13-04
> **Goal:** The copilot UX — type `/` to pick a workflow, fill a schema-driven launch dialog, hand the agent
> the instruction to start it, then render the permission-confirm cards, gate cards, and terminal
> notifications inline so the whole launch→supervise→decide loop happens in the conversation.

---

## 1. Slash-command palette (composer)

- In the Chat `Composer`, typing `/` at the start opens a **command palette** (Radix popover + fuzzy filter)
  listing installed **launchable workflows** from `GET /api/catalog` (id, name, roles, prereq/secret
  readiness from `check_launch_readiness`). Grey out + annotate workflows with missing secrets/MCP.
- Selecting a workflow (Enter/click) opens the **launch dialog** (§2). Escape dismisses; `/` with no match
  falls back to a plain message. (Palette is additive; existing free-text chat is unchanged.)
- Reuse the existing command-palette/primitives; no new heavy deps.

## 2. Schema-driven launch dialog (reuse 07-05)

- **Reuse the Phase 07-05 Catalog launch form** (it already renders `META.inputs_schema` → typed fields with
  validation). Fetch the schema via `get_workflow_inputs_schema`/`GET /api/workflows/{id}`.
- On submit, the UI does **not** call `/api/runs` directly. Per the user's ask ("the Kiro agent starts the
  run"), it **hands the agent the action**: it posts a chat turn carrying a structured launch instruction,
  e.g. an assistant-visible user message *"Start **ERD Generation** with these inputs"* plus a hidden
  structured block `{intent: "start_run", workflow_id, inputs, environment}`. The copilot calls
  `start_run(workflow_id, inputs)` → (untrusted) → a **confirm card** appears → the user confirms → the run
  starts and is linked to the session (13-03). The dialog submit + the confirm card together are the
  human confirmation ADR-033 requires.
- Rationale for routing through the agent (vs a direct API call): it keeps the agent as the actor/owner of
  the run so its supervision + conversation have full context, and it exercises the same confirmed-mutation
  path as gate decisions (one consistent model).

## 3. In-chat cards (the agent-inbox surface, conversational)

Render three new inline card types in the transcript (reusing run-detail primitives where possible):

- **Permission-confirm card** (`permission.request` SSE, from 13-01/13-03): "The copilot wants to
  **{approve|reject|start|cancel}** … on run `r-…`. [Allow] [Deny]". Allow/Deny → `POST
  …/permissions/{tool_call_id}`. Auto-expires per the SDK `permission_timeout` (shows a countdown; on
  timeout renders "expired — denied").
- **Gate card** (`run.notification` kind=gate): the gate prompt + `options` as buttons (Approve / Reject /
  Feedback-with-textarea) + context-artifact links (open in the Documents drawer). Clicking an option is a
  shortcut that composes the decision for the agent (which then calls `respond_to_gate` → confirm card), OR
  the user can just type their decision — both paths converge.
- **Terminal card** (`run.notification` kind=final): status + verdict/summary + a link to Run Detail.

## 4. Supervised-runs strip

A compact strip at the top of a copilot session listing the session's linked runs (`GET /api/chat/runs`)
with live status dots (running / awaiting-you / done / failed) — a mini agent-inbox. "Awaiting-you" is
visually prominent. Clicking a run scrolls to its latest card / opens Run Detail.

## 5. SSE + state

- Extend the chat SSE reader (`readSse`, CRLF-safe from 10-01) to handle the new named events
  (`permission.request`, `run.notification`) in addition to the existing `agent.*`.
- Mode: a copilot session shows the slash palette + supervised-runs strip; a read-only session does not. A
  header toggle switches a session to copilot (also auto-switches on first launch).
- Accessibility: cards are keyboard-operable; confirm/deny are real buttons; jest-axe on new components.

## 6. Files & tests (web)
- `features/chat/Composer.tsx` — `/` palette + workflow list.
- `features/chat/LaunchDialog.tsx` — reuse the 07-05 form; emit the `start_run` intent turn.
- `features/chat/cards/{PermissionCard,GateCard,TerminalCard}.tsx` + `SupervisedRunsStrip.tsx`.
- `lib/api/chat.ts` — permission resolve, notifications list/ack, `chat/runs`, mode toggle; SSE event types.
- `types/chat.ts` — `PermissionRequest`, `RunNotification`, `ChatSessionMode`.
- Vitest: palette filter + launch-intent emission; each card's action posts the right endpoint; SSE parses
  the new events; supervised-strip status mapping; jest-axe. Golden fixtures for the new SSE shapes.

## 7. Acceptance criteria
1. `/` lists launchable workflows (readiness-annotated); selecting → schema dialog; submit → agent
   `start_run` → confirm card → run starts + linked + appears in the supervised strip.
2. A gate on that run surfaces a gate card (+ the agent's conversational nudge); choosing an option →
   confirm card → decision reaches the run → run resumes; terminal card on completion.
3. Read-only sessions are visually + functionally unchanged; `web/static` rebuilt + committed; vitest +
   tsc + eslint + jest-axe green.

## 8. Out of scope
- Audit log / limits / advanced-gate policies (13-06).
