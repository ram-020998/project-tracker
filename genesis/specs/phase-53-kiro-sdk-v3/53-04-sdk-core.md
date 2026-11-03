# 53-04 — SDK core: launch, transport, session, updates and usage, errors, timeouts

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (`packages/kiro-agent-sdk`). Parent:
> `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D1, D3 (#1, #2, #3, #4, #5, #6, #9, #10, #11, #13), D5, D6, D10;
> F1, F3, F4, F6, F7, F10, F12, F13, F14, F15. Uses 53-02's fixtures and numbers.

## 1. Goal

Replace `client.py`'s v2 transport with small v3 modules behind the public names callers use today (F1), so 53-05..53-07
build on a tested core. The old `KiroACPClient` code path is kept importable (unused by new code) until 53-07 moves the
last caller, then deleted (umbrella §6, D5).

## 2. Modules (`packages/kiro-agent-sdk/src/kiro_agent_sdk/`)

| Module | Owns |
|---|---|
| `launch.py` | Binary (option → `PATH` → `~/.local/bin`); `--version` probe (parsed `(major, minor, patch)`); argv `acp --agent-engine v3 [--auth-method client]`; **explicit env** (`env=` option; default = the caller's environment with `KIRO_HOME` set; never `KIRO_API_KEY` when `--auth-method client`, 52-01 D8); `KIRO_HOME` required (D6: the SDK refuses to start without one, so no caller falls back to `~/.kiro`); `start_new_session=True` (own process group, F12); `close()` = graceful `session/close` → `SIGTERM` the group → `SIGKILL` the group after 5 s, using the tree findings of 53-02 W16 |
| `transport.py` | JSON-RPC framing (newline JSON, oversized-line recovery, the 64 MB limit), request ids and futures, a **bounded** write; agent→client requests dispatched to registered handlers; **an unknown request is answered `-32601`** (D3 #6); `request_ext(method, params)` for extension requests; `on_notification(callback)` for non-turn notifications (the 51-03 need) |
| `session.py` | `initialize` (`protocolVersion: 1`, `fs` capabilities, `terminal: false`, `clientInfo` = SDK name + version, `_meta.kiro.settings` per F10); `session/new {cwd, mcpServers, _meta.kiro.customAgents}` (agent from 53-05); **activation**: `session/set_mode` to the agent, then wait for the active signal 53-02 W4 found (fail closed: `AgentNotActive` with the engine's mode list); **MCP readiness** (F3): collect `_kiro/mcp/status` for the servers Genesis sent until each is connected or failed, bounded by `startup_timeout`; result exposed as `mcp_status` (`{name: {state, error}}`); `prompt`, `steer` (W7 method; returns `delivered` / `queued`), `cancel` (`session/cancel`, then wait the measured grace for the prompt answer), `compact` (`_kiro/session/compact` when listed in `extensionMethods`), `set_config_option(id, value)` (model, effort), `load(session_id)` (`session/load` + agent re-sent + activation), `close` (`session/close`), `delete` (`_kiro/session/delete`) |
| `updates.py` | `session/update` → the **existing** message classes (`AgentMessageChunk`, `AgentThoughtChunk`, `ToolCall`, `ToolCallUpdate`, `PlanUpdate`; F1): MCP tool `name` from `title` `@server/tool` (or `rawInput.tool_id` `server::tool`), `server` from `_meta.kiro.serverName`, **`raw_input` = `rawInput.arguments`** for MCP calls (else `rawInput`), `output` from `rawOutput.response`/`message` or `content` text (53-01 P8); built-in names from the tool-id fixture (53-05). `session_info_update` → per-turn accumulator: `turn_completion` → `credits` (sum of `promptTurnSummaries[].usage` where `unit == "credit"`), `turn_duration_ms` (`elapsedTime`); `context_usage` → `context_pct`; the W10 frame → `model`, `fallback_from`; summarization kinds → a `SessionStatus` message (F15). `available_commands_update` → `commands`; `config_option_update` → `config_options` (`model`, `mode`, `effortLevel` …) |
| `usage.py` | `usage = {credits, context_pct, turn_duration_ms, provenance, model?, fallback_from?}`; `provenance` `metered` when `turn_completion` carried a credit entry, else `unavailable`; never a number without a credit entry (ADR-032, L-016); a cancelled or timed-out turn follows 53-02 W5 |
| `errors.py` | One classification for every failure the SDK raises or puts in `ResultMessage.error`: `kiro_missing`, `kiro_too_old`, `engine_missing` (no v3), `not_signed_in`, `throttled`, `request_too_large`, `process_died` (with the stderr tail), `mcp_failed` (server names), `agent_not_active`, `timeout_silent`, `timeout_tool_stall`, `timeout_ceiling`, `cancelled`, `protocol_error`. Each carries `code`, a user-facing `message` with the remedy, and `retryable: bool`. Classifiers read stderr and JSON-RPC errors (KiroCrew `acp/transport_errors.py` as reference; Genesis's own texts) |
| `timeouts.py` | Three limits per turn (F7): **silent** (no frame for N s), **tool stall** (a tool call with no update for M s), **ceiling** (the caller's `turn_timeout`); values from 53-02 W14, defaults in one place; each ends the turn with its `errors` code and a message naming the limit; the transport wait outlives the ceiling by a margin so the ceiling's message wins (KiroCrew `acp/client_timeouts.py`) |
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
- One test per fixture (53-02 §4): the SDK produces the `expected.json` (messages, usage, errors, answers it sent).
- Unit tests for each module (framing, `-32601`, classification table, timeouts with a fake clock, process-group kill
  with a real child process tree).
- **Import gate** (F13): `packages/kiro-agent-sdk/tests/test_public_surface.py` pins `__all__`; a test in
  `genesis/tests/` and in `packages/genesis-core/tests/` scans their sources and fails on any `kiro_agent_sdk.<module>`
  import other than the public package.

## 4. Gates

`cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` and `ruff check src tests`; the genesis and
genesis-core suites still green (the old path untouched until 53-07).

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["sdk-acp", "observability-credits"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-032", "ADR-045", "ADR-051", "ADR-080"]
lessons  = ["L-001", "L-011", "L-016", "L-018", "L-044", "L-046", "L-064", "L-008"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**"]
upstream = ["53-02", "53-03"]
```
