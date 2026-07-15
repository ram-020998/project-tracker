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



---

## 13-02 — Genesis Control MCP server (+ ADR-033)

### As-built (code committed to genesis master `b6edf7c`; NO release yet — see below)

**`genesis/mcp/control_server.py`** — a write-capable stdio MCP server, the sibling of the read-only
`introspection_server`, but a **thin MCP→HTTP facade** over the existing `/api` surface (Codex-as-MCP
pattern). It holds no run logic; each tool is one HTTP call, so `RunManager` stays the single source of
truth. 10 run-management tools:
- read (trusted by the 13-03 wiring): `list_launchable_workflows` (`GET /catalog`),
  `get_workflow_inputs_schema` (`GET /workflows/{id}` → `inputs_schema`+`required_mcp/cli`),
  `check_launch_readiness` (`/workflows/{id}` + `/config/mcp-cards` + `/config/cli-cards` →
  unconfigured/missing-secret MCP + missing CLI), `get_run_status` (compact `/runs/{id}`, no bulk/secret
  echo), `get_run_steps` (`/runs/{id}/steps`), `get_pending_gate` (`/runs/{id}` → `.gate`),
  `list_session_runs` (`/chat/runs`).
- mutating (left UNTRUSTED by 13-03 → per-call confirm): `start_run` (`POST /runs`), `respond_to_gate`
  (validates a string decision against the gate's `options`, normalizes `{"decision":…}`, feedback dict
  always allowed → `POST /runs/{id}/respond`), `cancel_run` (`POST /runs/{id}/cancel`).
- `MUTATING_TOOLS = {start_run, respond_to_gate, cancel_run}` is exported as the authoritative untrusted
  set for the 13-03 wiring + tests.

**Boundary (ADR-033 / ADR-029):** the tool set is run-management ONLY — there are deliberately **no**
config/secret/registry/workflow-definition/deploy tools (authority-by-tool-set). Tests assert the exact
tool set and the absence of any forbidden name.

**`genesis/api/chat.py`** — added a `GET /api/chat/runs` placeholder returning `[]` (filled by 13-03's
link table) so `list_session_runs` has a stable endpoint.

**ADR-033** already recorded in `reference/decision-log.md` (Proposed) from the planning phase; its text
matches this sub-phase. 13-06 flips it to Accepted.

**Tests:** `tests/test_control_server.py` — 23 tests (mock the HTTP session): exact tool set;
no config/registry/deploy tools; every tool dispatchable; each read/mutating tool → correct endpoint +
payload; `respond_to_gate` rejects an option not in the gate and does NOT post; feedback-dict allowed;
not-awaiting error; decision normalization; token header sent iff configured; `initialize`/`tools/list`
protocol. Full genesis suite **145 passed**; ruff clean on touched files. Also stdio-smoke-tested
(`initialize` → `genesis-control`, `tools/list` → 10 tools).

### Deviations from the spec (intentional, flagged)

1. **`requests`, not `httpx`.** The spec said httpx, but **httpx is a dev-only dependency of genesis**
   while `requests` is a runtime dependency — a real install wouldn't have httpx, and the control server
   runs as a subprocess in that install. `requests` is synchronous, which also fits the stdio loop.
2. **Token gating deferred (does NOT gate shared endpoints).** The spec called for a per-process token
   that the mutation endpoints *require*. But `POST /api/runs` / `/respond` / `/cancel` are the **same
   endpoints the browser Runs UI already calls tokenless** — hard-requiring a token would break the UI,
   and it would be incoherent security (the whole app is unauthenticated on localhost per ADR-026;
   `POST /config/secrets` is itself tokenless). So: the control server **sends** `X-Genesis-Control-Token`
   when launched with `--token` (ready to *identify* copilot-originated calls for the 13-06 audit log),
   but 13-02 does **not** add an app-side gate, and does not yet generate the token (that lands in 13-03
   where the server is actually launched). The real security/kill-switch/rate-limit model is designed
   holistically in **13-06**. Acceptance criterion 2's "mutations require the control token" is therefore
   deliberately **not** met literally — flagged for the record.

### Release status
Genesis code committed to master (`b6edf7c`, pushed) but **NOT tagged**. The control server is inert until
13-03 wires it into a copilot chat session, and 13-03 also carries the coordinated `kiro-agent-sdk` v0.5.0
pin bump (genesis + genesis-core together). So genesis is released once at 13-03.
