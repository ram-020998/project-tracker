# Phase 13-03 — Copilot Chat Mode & Run↔Session Link

> **Status:** ✅ SHIPPED (Phase 13 complete — 13-01..06; see `progress/phase-13-copilot-orchestrator.md`) · **Repo:** genesis · **Depends on:** 13-01 (permission bridge), 13-02 (control server)
> **Goal:** Turn a chat session into a **copilot** — wire the control MCP server with read tools trusted and
> mutating tools untrusted (routed through the 13-01 permission-ask bridge to a chat confirm card), add
> orchestration steering, persist a per-session **mode**, and link runs started from a session to that
> session (`m0004`).

---

## 1. Session mode

Add a `mode` column to `chat_sessions` (`m0004`): `"read_only"` (default, unchanged Phase-10 behavior) or
`"copilot"`. A session becomes `copilot` when the user (a) toggles it, or (b) launches a workflow via the
slash UI (13-05). Read-only sessions keep the exact Phase-10 MCP surface + `permission_mode="auto_deny"`.

## 2. MCP surface for a copilot session (`build_chat_mcp` extension)

Extend `build_chat_mcp(config, settings, mode)` → `(mcp_servers, trust_tools, options_overrides)`:

- **Read tools TRUSTED** (silent): Atlas read allowlist + `@genesis/*` introspection tools (as today) +
  the control server's **read** tools (`@genesis-control/list_launchable_workflows`,
  `get_workflow_inputs_schema`, `check_launch_readiness`, `get_run_status`, `get_run_steps`,
  `get_pending_gate`, `list_session_runs`).
- **Mutating tools UNTRUSTED** (not in `trust_tools`): `@genesis-control/start_run`, `respond_to_gate`,
  `cancel_run`. Because they are untrusted, kiro-cli fires `session/request_permission` for each call
  (verified in 13-01) → routed to the confirm card.
- **Permission policy:** `permission_mode="ask"` with `on_permission` = a session-bound callback (below).
  `allow_fs_write=False` stays (the copilot writes nothing to disk; it acts via the control API).
- The control server entry is added with `--base-url`/`--token` (the app's per-process control token).

The `@server/tool` **namespaced** trust rule (10-01) applies: the control server is named `genesis-control`
so trusted read tools are `@genesis-control/<tool>`.

## 3. The permission callback (bridges 13-01 → chat UI)

`ChatSession` supplies `on_permission(req)`:
1. Persist a **pending permission** row (session_id, tool, args, options, created_at) and emit a
   `permission.request` event on the session's SSE (13-05 renders the confirm card).
2. `await` an `asyncio.Future` keyed by `tool_call_id`, resolved when the UI POSTs the user's decision
   (`POST /api/chat/sessions/{id}/permissions/{tool_call_id}` → allow optionId / deny).
3. Return the chosen optionId (or None → deny). The SDK enforces the `permission_timeout` fail-closed.

So a mutating tool call = "assistant proposes → chat shows a confirm card → user allows/denies → tool runs
or is refused." This is the per-action human confirmation ADR-033 requires, using ACP's native mechanism.

## 4. Run↔session link (`m0004 chat_run_links`)

```
chat_run_links(run_id TEXT PRIMARY KEY, session_id TEXT NOT NULL,
               created_at TEXT, FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE)
```

When `start_run` succeeds, the backend records the link (the control token identifies the owning session —
the token is minted per copilot session, or the `start_run` proxy passes the session id). `list_session_runs`
+ the supervisor (13-04) use this table. `GET /api/chat/runs?session=…` returns the linked runs + their live
status (joined against `RunStore`).

## 5. Orchestration steering (copilot preamble)

A copilot-mode steering preamble replaces the read-only one:
> *"You are Genesis Copilot, an operator assistant. In addition to answering questions, you can start and
> supervise workflow runs on the user's behalf using the control tools. Rules: (1) only start a run when the
> user has provided inputs via the launch dialog or explicitly confirmed them; (2) to answer a workflow's
> approval/escalation gate you MUST present the gate's options and use the user's stated decision — never
> invent or assume one; (3) starting a run, answering a gate, and cancelling a run each require the user to
> confirm the action (a confirmation prompt will appear); (4) you cannot change configuration, secrets,
> workflows, or deploy. When a run needs a decision, summarize the gate context and list the options
> clearly. Cite run ids."*

Enforcement remains the trust/permission model + control tool set; the preamble only shapes behavior.

## 6. Files & tests
- `genesis/db/migrations/m0004_chat_run_links.py` (+ mode column on chat_sessions).
- `genesis/chat/mcp.py` — `build_chat_mcp(..., mode)`; control server entry; trusted/untrusted split.
- `genesis/chat/manager.py` — copilot `on_permission` callback + pending-permission store + resolve API hook;
  mode on `ChatSession`; copilot steering; record link on `start_run` (via a control→app callback or the
  `/api/chat/runs` write).
- `genesis/api/chat.py` — `POST /api/chat/sessions/{id}/permissions/{tool_call_id}` (resolve), `GET
  /api/chat/runs`, mode toggle on session.
- `tests/test_copilot_mode.py` — a fake client that triggers `on_permission` → assert the pending row + SSE
  event + Future resolution flow (allow/deny/timeout); read tools trusted / mutating untrusted; link row on
  start; read-only sessions unchanged.

## 7. Acceptance criteria
1. A copilot session trusts read tools (silent) and routes each mutating tool call through a confirm
   round-trip (allow → executes, deny/timeout → refused, fail-closed).
2. `m0004` adds `chat_run_links` + `chat_sessions.mode`; a started run is linked; `list_session_runs` returns
   it; read-only sessions behave exactly as Phase 10.
3. No config/secret/registry/deploy tool is reachable from chat.

## 8. Out of scope
- The event-driven nudge/notifications (13-04) and the UI (13-05).
