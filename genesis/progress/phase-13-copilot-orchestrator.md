# Phase 13 — Chat Copilot & Run Orchestrator (as-built progress)

Spec: `specs/phase-13-copilot-orchestrator.md` (+ `phase-13-copilot-orchestrator/13-01..13-06`). ADR-033.

---

## 13-01 — SDK interactive permission bridge

### Load-bearing spike (R1 of the umbrella) — CONFIRMED ✅ (2026-07-15)

**Question:** does kiro-cli fire `session/request_permission` for an **untrusted** MCP tool call (and
skip it for a **trusted** tool)? This is the whole basis of the "leave mutating tools untrusted → confirm
card" model (ADR-033). If it didn't hold, 13-01 would be N/A and we'd fall back to UI-mediated
pending-action confirmation.

**Method:** a real `KiroACPClient` against **kiro-cli 2.12.2**, with a minimal stdio MCP server exposing
`read_thing` (read) + `do_mutation` (write). `_handle_agent_request` was spied to record every
`session/request_permission`. `permission_mode="auto_deny"` so a fired request is denied and the turn
continues. Two cases:
- **CASE A** — `trust_tools=None` (nothing pre-trusted), prompt "call do_mutation value=1".
- **CASE B** — `trust_tools=["@spike/read_thing"]`, prompt "call read_thing key=x".

**Result:**
- CASE A (untrusted `do_mutation`): `session/request_permission` fired **1×**; agent then reported the
  tool was denied (auto_deny selected `reject_once`).
- CASE B (trusted `read_thing`): fired **0×**; the tool ran silently to completion.
- **VERDICT: CONFIRMED.**

**Captured real param shape** (drove the `_permission_request` normalizer):
```json
{
  "sessionId": "…",
  "toolCall": { "toolCallId": "toolu_…", "title": "Running: @spike/do_mutation" },
  "options": [
    {"optionId": "allow_once",   "name": "Yes",    "kind": "allow_once"},
    {"optionId": "allow_always", "name": "Always", "kind": "allow_always"},
    {"optionId": "reject_once",  "name": "No",     "kind": "reject_once"}
  ],
  "id": "57f8c4c9-…"    // NOTE: request id is a STRING uuid, not an int
}
```

**Design consequences (locked in for the implementation):**
1. Request `id` is a **string** — `_respond` already accepts `Any`; fine.
2. The permission request carries **no `rawInput`** (only `toolCall.toolCallId` + `title`). So the confirm
   card (13-03/13-05) must correlate the arguments from the preceding `tool_call` event by `toolCallId`;
   `PermissionRequest.raw_input` is best-effort (usually `{}`), and `tool_name` is parsed from the
   `@server/tool` token in `title`.
3. Option `kind`s are `allow_once` / `allow_always` / `reject_once` — the existing `startswith("allow")` /
   `startswith(("reject","deny"))` matching is correct; `_first_deny` picks `reject_once`.

Spike scripts were throwaway (`/tmp/phase13_spike/`), removed after the run.

### As-built (SHIPPED — kiro-agent-sdk v0.5.0, 2026-07-15)

**Change (additive, backwards-compatible → minor bump):**
- `messages.py` — new `PermissionRequest` TypedDict (`tool_name`, `title`, `raw_input`, `options`,
  `tool_call_id`), documented that the raw permission request carries no arguments (correlate by
  `tool_call_id`).
- `client.py` — `KiroAgentOptions` gained `permission_mode="ask"` (docs), `on_permission:
  Callable[[PermissionRequest], Awaitable[str|None]]`, and `permission_timeout=300.0`. The
  `session/request_permission` handling was factored into `_handle_permission` (three modes) +
  async `_resolve_permission_ask`. The **ask** branch schedules the callback round-trip via
  `asyncio.create_task` (tracked in `self._perm_tasks`) so the read loop is never blocked while a
  human/UI decides. Module helpers `_first_deny` (returns an optionId or None) and
  `_permission_request` (normalizes the raw params → `PermissionRequest`, deriving a namespaced
  `@server/tool` name from the title).
- `__init__.py` — exports `PermissionRequest`.

**Fail-closed guarantees:** any callback exception, a timeout, or an optionId the agent didn't offer →
select the reject/deny option (or cancel if none). **Hardening beyond the spec:** `permission_mode="ask"`
WITHOUT an `on_permission` callback also fails closed (deny) rather than silently falling through to
`auto_approve` — a misconfiguration can never make the agent autonomous.

**Tests:** `tests/test_permission_ask.py` — 16 tests (normalizer + `_first_deny`; allow; choose-reject;
None→deny; raises→deny; timeout→deny; unknown-option→deny; no-reject→cancelled; ask-without-callback→deny;
3 auto_approve/auto_deny regressions). Full SDK suite **75 passed**; ruff clean on all touched files.
(Pre-existing, unrelated `E401` in `tests/test_erd_workflow.py:119` left as-is — not modified; SDK repo
has no CI.)

**Release:** committed + tagged **v0.5.0** + pushed (`b07e9fd`).

**Pin bump DEFERRED to 13-03 (intentional).** Both `genesis` AND `genesis-core` pin
`kiro-agent-sdk` directly. Bumping only one to `v0.5.0` while the other stays `v0.4.0` would give pip two
conflicting direct git refs for the same package (unresolvable). Nothing consumes `permission_mode="ask"`
until 13-03 (copilot chat mode), so the pins stay at `v0.4.0` for now and will be bumped together in a
coordinated genesis-core + genesis release when the feature is actually wired in. The `v0.5.0` tag exists
and is ready.

