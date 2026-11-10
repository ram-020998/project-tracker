# 53-04 — SDK core: launch, transport, session, updates and usage, errors, timeouts

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (`packages/kiro-agent-sdk`). Parent:
> `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D1, D3 (#1, #2, #3, #4, #5, #6, #9, #10, #11, #13), D5, D6, D10;
> F1, F3, F4, F6, F7, F10, F12, F13, F14, F15. Uses 53-02's fixtures and numbers.

## 1. Goal

Replace `client.py`'s v2 transport with small v3 modules behind the public names callers use today (F1), so 53-05..53-07
build on a tested core. The old `KiroACPClient` code path is kept importable (unused by new code) until 53-07 moves the
last caller, then deleted (umbrella §6, D5).

**Sequencing (agreed with genesis-dev before the build, 2026-11-10).** §1 and the F1 option changes in §2 conflict:
genesis-core (`nodes/agent.py`, `tests/test_core_units.py:211-226`) and chat (`chat/manager.py:132-138`) use the top-level
`KiroAgentOptions` with `trust_tools` / `trust_all_tools` / `on_session_status` until 53-06 / 53-07 move them. So:

1. **53-04:** the top-level names `KiroAgentOptions`, `KiroACPClient`, `query`, `collect*` keep pointing at today's
   `client.py`, unchanged byte for byte. New public names are added: `KiroError`, the error codes, `AgentNotActive`,
   `SessionStatus`. The v3 client and options live in the private `_v3client.py` (plus the §2 modules); only SDK tests
   import it. `test_public_surface.py` pins the names that exist **in this sub-spec**; each later sub-spec changes the
   pin on purpose (53-05 adds `TrustPolicy`; 53-06 and 53-07 as below).
2. **53-06:** the public names point at the v3 client when `kiro_node` moves. The v2 client stays reachable for chat only
   as `LegacyKiroACPClient` / `LegacyKiroAgentOptions`, and chat's import switches to them (a one-line change in
   `chat/manager.py`).
3. **53-07:** chat moves to v3, then the old `client.py` and the `Legacy*` aliases are deleted and `_v3client.py` becomes
   `client.py`.
4. **Trust in 53-04:** `trust` is an untyped placeholder until 53-05. The agent sent in `session/new` is
   `{id, prompt, tools: []}`, which fails closed. Permission requests use a port of v2's `permission_mode` logic as a
   stopgap, so the ask/reject/auto-approve fixtures replay end to end; 53-05 replaces it with the identity check and the
   backstop. Nothing outside SDK tests reaches this path until 53-06, after 53-05.
5. **Fake engine:** while the agent body is a placeholder, the fake engine may skip comparing
   `_meta.kiro.customAgents` in `session/new` / `session/load`. The skip must be one named switch, listed in the As
   built, and 53-05 turns it off so the projection is checked against the recorded frames.

## 2. Modules (`packages/kiro-agent-sdk/src/kiro_agent_sdk/`)

| Module | Owns |
|---|---|
| `launch.py` | Binary (option → `PATH` → `~/.local/bin`); `--version` probe (parsed `(major, minor, patch)`); argv `acp --agent-engine v3 [--auth-method client]`; **explicit env** (`env=` option; default = the caller's environment with `KIRO_HOME` set, kept as today because Phase 51's shell turns need the worker's `PATH` and `PLAYWRIGHT_BROWSERS_PATH`, 53-01 §9.3 item 2; narrowing it is Phase 52's job; never `KIRO_API_KEY` when `--auth-method client`, 52-01 D8); `KIRO_HOME` required (D6: the SDK refuses to start without one, so no caller falls back to `~/.kiro`); `start_new_session=True` (own process group, F12); `close()` = graceful `session/close` → `SIGTERM` kiro-cli's group → `SIGKILL` after 5 s. The tree (53-02 W16): `kiro-cli` and `kiro-cli-chat` share a group, the engine (`…/kiro-cli/node`) has **its own** group, and the MCP servers sit in the engine's group. On an idle session, killing kiro-cli's group took the whole tree with it (0.54 s). Still, record both pgids at start and check both groups are gone after the kill, signalling the engine's group if not. Not yet measured: a kill while a shell tool runs (review m3); a 53-04 test covers it with a real child tree. It signals only those two groups (never the program's `apwt` groups, which W16 showed survive and `procs.reap` removes, 53-01 §9.3 item 4) and writes no run state (the worker's intended-stop + compare-and-set rule, L-108, stays the only terminal writer) |
| `transport.py` | JSON-RPC framing (newline JSON, oversized-line recovery, the 64 MB limit), request ids and futures, a **bounded** write; agent→client requests dispatched to registered handlers (`fs/*`, `session/request_permission`, `_kiro/mcp/elicitation` W18, `_kiro/auth/getAccessToken` W12); **an unknown request is answered `-32601`** (D3 #6, fixture `unknown-request`); `request_ext(method, params)` for extension requests; `on_notification(callback)` for non-turn notifications (the 51-03 need). Any redaction the SDK applies to its own logs works on the joined text of streamed chunks, not frame by frame (the 53-02 scrubber is per frame and must not be reused as it is, review m6) |
| `session.py` | All shapes below are from 53-02 and its fixtures (`tests/fixtures/v3/`). **`initialize`** (`protocolVersion: 1`, `fs` capabilities, `terminal: false`, `clientInfo` = SDK name + version; no `_meta.kiro.settings`: only `memory` is read and on-demand MCP loading has no client switch, W9, so F10 keeps the engine default). **`session/new {cwd, mcpServers, _meta.kiro.customAgents}`** (agent from 53-05; stdio servers, and `{type: "http", name, url, headers: []}` for HTTP, W13). **Activation** (W4, fixtures `set-mode-active`, `set-mode-dropped`): `session/set_mode` answers `{}` whether or not our agent exists, so its answer proves nothing. (1) Before `set_mode`, our id must be in `session/new.result.modes.availableModes` with `_meta.kiro.resource.source.origin: "client"`. (2) After it, active = a `config_option_update` whose `mode.currentValue` is our id (seen ≤ 30 ms; wait up to 2 s). (3) **Dropped** = `_kiro/customAgent/not_found {requestedAgent, fallbackAgent}` and a `config_option_update` to the fallback (`vibe`, the engine's default agent with every built-in): the engine has **moved the running session to an agent Genesis did not configure**. Any of (1)–(3) failing → raise `AgentNotActive` (fail closed), mark the session unusable so **no prompt is ever sent on it**, and `session/close` it. The message carries the reason from the session's own `KIRO_HOME/logs/<t>/kiro.log` (`client.agent.drop.invalid {index, error}`). Unknown extra keys do not drop an agent. **MCP readiness** (F3, W17): collect `_kiro/mcp/status` for the servers Genesis sent until each is `connected` (with `tools`) or `failed {errorMessage, failedAuthorization}`, bounded by `startup_timeout` (default 65 s, above the engine's own 60 s connect limit, fixture `mcp-status-timeout`); exposed as `mcp_status` (`{name: {state, error}}`). **`prompt`**: send the `prompt` key only (`content` alone is refused, W11; images allowed, `promptCapabilities.image`). **`steer(text)`** (W7, fixtures `steer`, `steer-at-turn-end`): `_session/steer {sessionId, message: <non-empty string>}` → `{queued, messageId}`; text only (an image is refused, `-32603`); `delivered` = a later `steering_injected` with that `messageId` (0.1 s while the model streams; after the running tool ends while a tool runs); `unread` = `steering_cleared` without a prior `steering_injected` (never seen, still handled). The method is not in `extensionMethods`; do not gate on that list. **`cancel`**: `session/cancel`, then wait for the prompt answer (`stopReason: "cancelled"`; 0.01–0.03 s measured, grace 5 s, W5). The SDK does not revert or rewrite history; the caller handles what follows a Stop (53-07 §4, D15). **`compact`**: `_kiro/session/compact {sessionId}` → `{success}`; progress kind `summarization_completed` (W8; no Clear method exists, Clear stays close + new). **`set_config_option(id, value)`**: validate a model id against `configOptions.model.options` first (an unknown id is accepted and fails only at the next prompt, W10, fixture `model-unavailable`). **`load(session_id)`**: `session/load {sessionId, cwd, mcpServers, _meta.kiro.customAgents}` (agent re-sent) + activation; the replay (`user_message_chunk` / `agent_message_chunk` with `_meta.kiro.replayId`, and the old `turn_completion` with `_meta.kiro.replay: true`) arrives **before** the load answer and is **not** a new turn and **not** new credits (W6, fixture `load`). **`close`** (`session/close`), **`delete`** (`_kiro/session/delete`). `_kiro/mcp/resetServer` exists but is not used this phase |
| `updates.py` | `session/update` → the **existing** message classes (`AgentMessageChunk`, `AgentThoughtChunk`, `ToolCall`, `ToolCallUpdate`, `PlanUpdate`; F1): MCP tool `name` from `title` `@server/tool` (or `rawInput.tool_id` `server::tool`), `server` from `_meta.kiro.serverName`, **`raw_input` = `rawInput.arguments`** for MCP calls (else `rawInput`), `output` from `rawOutput.response`/`message` or `content` text (53-01 P8); built-in names from the tool-id fixture (53-05). `session_info_update` → per-**prompt** accumulator: one `session/prompt` can span several engine turns (a steer queued as a turn ends starts another, W7b), so **sum the credit entries of every `turn_completion` until the prompt answer** (sum of `promptTurnSummaries[].usage` where `unit == "credit"`) and sum `turn_duration_ms` (`elapsedTime`); skip any frame with `_meta.kiro.replay: true` (W6); `context_usage` → `context_pct`; the fallback frame → `model`, `fallback_from` (shape **not yet measured**: W10 could not force one; handle it defensively and record the first live one as a fixture); `summarization_completed` → a `SessionStatus` message (F15). `available_commands_update` → `commands`; `config_option_update` → `config_options` (`model`, `mode`, `effortLevel` …). A `tool_call_update` for an id with no earlier `tool_call` is accepted (53-02 W5: the engine's "Tool Load" step arrives that way) |
| `usage.py` | `usage = {credits, context_pct, turn_duration_ms, provenance, model?, fallback_from?}` per prompt (summed as in `updates.py`); `provenance` is `metered` when at least one non-replayed `turn_completion` carried a credit entry, else `unavailable`; never a number without a credit entry (ADR-032, L-016). This holds for an aborted prompt too (53-02 W5, F17): a cancel after a finished tool round carried 0.05 → `metered`; a cancel during a model call carried none → `unavailable`; a killed process sends no `turn_completion` → `unavailable`. `partial` stays an aggregate value only (some turns reported, some not; `genesis/runs/eventlog.py:188-207`), never a per-turn value; the turn's cancellation is shown by its status, not its provenance |
| `errors.py` | One classification for every failure the SDK raises or puts in `ResultMessage.error`: `kiro_missing`, `kiro_too_old`, `engine_missing` (no v3), `not_signed_in` (also `-32000 ModelRegistryUnauthenticatedError`, W12), `model_unavailable` (`-32000 "The model '…' is not available"`, W10), `throttled`, `request_too_large`, `process_died` (with the stderr tail), `mcp_failed` (server names; at start from `_kiro/mcp/status`; **after start only from the tool failure text**, "Connection closed" then "Not connected", because the engine sends no status update and does not restart a dead server, 53-02 W5), `agent_not_active`, `timeout_silent`, `timeout_tool_stall`, `timeout_ceiling`, `cancelled`, `protocol_error`. Each carries `code`, a user-facing `message` with the remedy, and `retryable: bool`. Classifiers read stderr and JSON-RPC errors (KiroCrew `acp/transport_errors.py` as reference; Genesis's own texts) |
| `timeouts.py` | Three limits per turn (F7), defaults in one place from 53-02 W14 (real runs: longest silence 287 s, MCP call 19 s, shell command 38 s, turn 737 s): **silent** = 600 s with no frame; **tool stall** = 300 s with no update on a running tool call; **ceiling** = the caller's `turn_timeout`. No normal turn of the 53-01 §9.2 workflows ends early. Each ends the turn with its `errors` code and a message naming the limit; the transport wait outlives the ceiling by a margin so the ceiling's message wins (KiroCrew `acp/client_timeouts.py`) |
| `client.py` | `KiroACPClient` rebuilt on the modules above, same public methods minus `execute_command` and `set_model` (F1); new: `steer`, `cancel`, `compact`, `set_config_option`, `load`, `delete`, properties `available_models` / `current_model_id` (from `config_options.model`), `available_commands` (from `available_commands_update`), `modes`, `mcp_status`, `kiro_version` |
| `__init__.py` | Public surface (F13): the names in 53-01 §2.1 (minus the removed options/methods) + `TrustPolicy` (53-05) + `KiroError` codes. Everything else is private (`_` modules or documented as internal) |

`KiroAgentOptions` (F1): removed `trust_all_tools`, `trust_tools`, `agent_engine`, `command_timeout`, `on_commands`,
`on_session_status`, `extra_args`; added `trust: TrustPolicy`, `kiro_home: str` (required), `env: dict | None`,
`agent_prompt: str`, `agent_id: str` (default `genesis`), `auth_method: "cli" | "client"`, `on_access_token`
(53-05), `on_status` (one callback for `SessionStatus` and MCP readiness), `silent_timeout`, `tool_stall_timeout`.
`query` / `collect` / `collect_streaming` / `collect_json` keep their signatures.

## 3. Fake engine and fixture tests (F14)

- `packages/kiro-agent-sdk/tests/fake_engine.py`: a stdio program that replays a `tests/fixtures/v3/*.jsonl` script —
  checks each client frame against the recorded one (method + key fields; ids and session ids by placeholder) and sends
  the recorded engine frames. The SDK's `kiro_cli_path` points at it in tests.
- One test per fixture (53-02 §4 and its As built list: 28 pairs + `tool-ids.json`): the SDK produces the
  `expected.json` (messages, usage, errors, answers it sent). `set-mode-dropped` must show no prompt sent after the
  fallback to `vibe`; `load` must show the replayed credits not counted; `steer-at-turn-end` must show both engine
  turns' credits summed.
- Unit tests for each module (framing, `-32601`, classification table, timeouts with a fake clock, process-group kill
  with a real child process tree).
- **Import gate** (F13): `packages/kiro-agent-sdk/tests/test_public_surface.py` pins `__all__`; a test in
  `genesis/tests/` and in `packages/genesis-core/tests/` scans their sources (`genesis/genesis/**`,
  `genesis_core/**`) and fails on any `kiro_agent_sdk.<module>` import other than the public package. `scripts/spikes/**`
  is outside the gate (the 51-03 harness imports private modules and is historical, 53-01 §9.4).
- **CI image** (L-112): the fake engine and every fixture test run with no Node and no kiro-cli on `PATH` (the CI image
  `python:3.13` has neither); one test runs the process-group kill with a plain Python child tree.

## 4. Gates

`cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` and `ruff check src tests`; the genesis and
genesis-core suites still green (the old path untouched until 53-07).

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["sdk-acp", "observability-credits"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-032", "ADR-045", "ADR-051", "ADR-080"]
lessons  = ["L-001", "L-011", "L-016", "L-018", "L-044", "L-046", "L-064", "L-008", "L-104", "L-107", "L-108", "L-112"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**", "genesis/genesis/testexec/procs.py"]
upstream = ["53-02", "53-03"]
```
