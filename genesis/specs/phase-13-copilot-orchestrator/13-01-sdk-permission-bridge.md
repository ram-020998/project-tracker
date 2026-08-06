# Phase 13-01 — SDK Interactive Permission Bridge

> **Status:** ✅ SHIPPED (Phase 13 complete — 13-01..06; see `progress/phase-13-copilot-orchestrator.md`) · **Repo:** kiro-agent-sdk · **Depends on:** none (lands first)
> **Goal:** Add a third permission policy — `permission_mode="ask"` — that forwards each ACP
> `session/request_permission` request to an **async callback** supplied by the embedding app, and returns
> the caller's decision to kiro-cli. This is the load-bearing primitive that lets the Phase-13 copilot get
> **per-action human confirmation** for mutating tools using ACP's native mechanism (no dependence on
> MCP elicitation, which kiro-cli does not support).

---

## 1. Background (as-built)

`kiro-agent-sdk` `client.py` handles agent→client requests. Permission today is **binary**
(`KiroAgentOptions.permission_mode`):
- `"auto_approve"` (default) — mirror the requested `allow` option (autonomous).
- `"auto_deny"` — select a `reject`/`deny` option, else signal `cancelled` (read-only; Phase 10-01).

`session/request_permission` is fired by kiro-cli **only for tools that are not pre-trusted** (tools in
`trust_tools` are auto-run without a permission round-trip). Chat (Phase 10) uses `auto_deny` +
a read-only `trust_tools` allowlist. There is **no** interactive/`ask` path and no elicitation handler.

## 2. Spike (must run first — de-risks R1 of the umbrella)

Before building, prove the assumption with a real kiro-cli session:
1. Start a session with an MCP server that exposes one **mutating** tool, and DO NOT list it in
   `trust_tools` (leave it untrusted).
2. Prompt the agent to call it.
3. **Assert** kiro-cli emits `session/request_permission` with `options` (allow/reject variants) for that
   call — i.e., untrusted MCP tool calls really do trigger the permission round-trip.
4. Confirm a trusted read tool in the same session does **not** trigger it.

If confirmed → implement §3. If NOT (kiro-cli auto-runs or auto-denies untrusted MCP tools without asking)
→ fall back to the umbrella's R1 alternative (UI-mediated pending-action confirmation in 13-02/13-05) and
mark this sub-phase N/A. **Record the spike result in `progress/`.**

## 3. Design

Add `permission_mode="ask"` and an optional async callback to `KiroAgentOptions`:

```python
# messages / options
PermissionRequest = TypedDict("PermissionRequest", {
    "tool_name": str,           # e.g. "@genesis-control/respond_to_gate" (namespaced if provided)
    "title": str,               # kiro-cli's human title for the call
    "raw_input": dict,          # the tool arguments (best-effort, from params)
    "options": list[dict],      # the ACP options [{optionId, name, kind}]
    "tool_call_id": str,
})

# KiroAgentOptions (additive)
permission_mode: str = "auto_approve"        # now one of: auto_approve | auto_deny | ask
# Called only when permission_mode == "ask". Returns the chosen optionId (allow/deny) or None → deny.
on_permission: Optional[Callable[[PermissionRequest], Awaitable[str | None]]] = None
permission_timeout: float = 300.0            # seconds; on timeout → deny (fail-closed)
```

Handler change in `_handle_request` for `session/request_permission`:

```python
elif method == "session/request_permission":
    opts = params.get("options", [])
    mode = self.options.permission_mode
    if mode == "auto_deny":
        ... # unchanged (Phase 10-01)
    elif mode == "ask" and self.options.on_permission is not None:
        req = _permission_request(params)               # normalize to PermissionRequest
        try:
            chosen = await asyncio.wait_for(self.options.on_permission(req),
                                            timeout=self.options.permission_timeout)
        except (asyncio.TimeoutError, Exception):        # fail-closed
            chosen = None
        if chosen and any(o.get("optionId") == chosen for o in opts):
            self._respond(req_id, {"outcome": {"outcome": "selected", "optionId": chosen}})
        else:
            deny = _first_deny(opts)
            self._respond(req_id, {"outcome": {"outcome": "selected", "optionId": deny}} if deny
                          else {"outcome": {"outcome": "cancelled"}})
    else:  # auto_approve (unchanged)
        ...
```

Notes:
- **Fail-closed** — any callback error/timeout, or an optionId the agent didn't offer → deny/cancel.
- The callback is `async` so the embedding app can await a UI round-trip (the chat confirm card).
- `on_permission` receives enough context (tool name + args + options) for Genesis to render a meaningful
  confirm card ("The assistant wants to **approve** gate *approve-domains* on run `r-…`. Allow?").
- No change to `auto_approve`/`auto_deny`; existing callers (workflow `kiro_node`, read-only chat) are
  unaffected. Backwards compatible → **minor** version bump.

## 4. Files & tests

- `src/kiro_agent_sdk/client.py` — the `ask` branch + `_permission_request`/`_first_deny` helpers.
- `src/kiro_agent_sdk/messages.py` — `PermissionRequest` type; export.
- `src/kiro_agent_sdk/__init__.py` — export the new option/type.
- `tests/test_permission_ask.py` — drive the handler with a fake `session/request_permission`:
  (a) callback returns an allow optionId → `selected` with that id; (b) callback returns None → deny;
  (c) callback raises → deny; (d) callback exceeds `permission_timeout` → deny; (e) callback returns an
  optionId not in `options` → deny; (f) `auto_approve`/`auto_deny` paths still behave as before (regression).

## 5. Acceptance criteria
1. Spike recorded: untrusted MCP tool calls fire `session/request_permission` (or the fallback is chosen).
2. `permission_mode="ask"` forwards to `on_permission` and returns its decision; fail-closed on
   error/timeout/invalid option.
3. Existing `auto_approve`/`auto_deny` behavior unchanged (regression tests green).
4. Additive, backwards-compatible; SDK minor release; genesis pins the new tag.

## 6. Out of scope
- The UI confirm card (13-05) and the chat wiring of the callback (13-03).
- MCP elicitation support (explicitly not used).
