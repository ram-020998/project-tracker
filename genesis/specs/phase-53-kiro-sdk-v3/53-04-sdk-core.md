# 53-04 — SDK core: launch, transport, session, updates and usage, errors, timeouts

> **Status:** BUILT 2026-11-10 (genesis beea49b + 07b6d07, review SHIP). Repo: **genesis** (`packages/kiro-agent-sdk`). Parent:
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

## As built (2026-11-10, genesis-dev) — review SHIP (round 2)

**Task restated.** In `packages/kiro-agent-sdk`, add the v3 modules (§2) and the v3 `KiroACPClient` / `KiroAgentOptions`
(F1), a fake engine that replays the 53-02 fixtures, one test per fixture, per-module unit tests, a real process-tree
kill and the F13 import gate — with the §1 sequencing: the top-level names stay on the unchanged v2 `client.py`, the v3
client is private (`_v3client.py`), trust is a fail-closed placeholder. Rules applied: ADR-002/004/020 (per-session
MCP over ACP; `KIRO_HOME` required, no fallback to `~/.kiro`), ADR-032 + F17 (credits only from `turn_completion`
credit entries, summed per prompt, replay skipped, `partial` never per turn), ADR-045, ADR-051 (seam untouched),
ADR-080; L-001, L-008, L-011, L-016, L-018, L-044, L-046, L-064, L-088, L-104, L-107, L-108, L-110, L-112. KiroCrew
read as a reference only: `src/kiro_crew/acp/client_timeouts.py` (the transport wait outliving the ceiling),
`transport_errors.py` + `model_registry_errors.py` (classify on `data.errorType` first, then message text),
`runtime_tree_kill.py` (signal a recorded group only while its root identity holds), `transport_framing.py` (a bounded
write; Genesis keeps a flat 30 s bound because its reader is always the local kiro-cli). No ADR deviation.

### Commits (genesis, local, base 143e9d2, not pushed)

- `beea49b` feat(sdk,53-04): the v3 core, the private v3 client, the fake engine and every test below.
- `07b6d07` fix(sdk,53-04): review M1/m1/n1 (import gates also catch `from kiro_agent_sdk import <private>` and
  `<alias>.<private>`; the `--version` cache keyed on the binary's mtime and size; the close warning names skipped
  groups).

### Changed

`packages/kiro-agent-sdk/src/kiro_agent_sdk/`:
- **New** `launch.py` (binary resolution option → env `PATH` → `~/.local/bin`; `--version` probe cached per
  `(path, mtime, size)`, minimum `(2, 37, 1)`; argv `acp --agent-engine v3 [--auth-method client]`; `build_env` =
  the given env or this process's, plus `KIRO_HOME`, refuses without a home, drops `KIRO_API_KEY` with `client`;
  `KiroProcess` with `start_new_session=True`, a 200-line stderr tail, `record_tree()` (the descendants' groups other
  than kiro-cli's, with leader pid + start token), `terminate()` → `CloseReport`: SIGTERM kiro-cli's group, SIGKILL after
  5 s, then each recorded group still provably ours (a descendant of a live kiro-cli, or the same leader pid + start)
  is signalled the same way if alive; a group created after the record (an `apwt` daemon) is never signalled; process
  table from Linux `/proc`, else `ps -A -ww` by absolute path, a `ps` failure logged).
- **New** `transport.py` (`Transport`: newline JSON-RPC via `readuntil`, so a line over the stream limit is recovered;
  serialized writes bounded at 30 s; `request` / `request_ext` / `notify`; handlers per method on their own tasks,
  **unknown request → `-32601`**, a handler error → `-32603`; listeners called in order before a later answer resolves;
  EOF classified through `eof_error` and every pending request failed with it; `FrameLog`: token-named keys and
  registered secrets replaced, chunk text logged only as the **joined, redacted text per turn**).
- **New** `session.py` (`Session`: `initialize` without `_meta.kiro.settings`; `new` / `load` with `customAgents`;
  **`activate`** = listed with origin `client` before `set_mode`, then the `config_option_update` to our id within 2 s,
  and `_kiro/customAgent/not_found` → fail closed: `unusable` set, `session/close`, `AgentNotActive` with the
  `client.agent.drop.invalid` reason read from the logging channel the `initialize` answer names, else
  `KIRO_HOME/logs/*/kiro.log`; `wait_mcp_ready`; `prompt` with the three limits and the cancel grace; `steer` (text only)
  with `queued → delivered | unread`; `cancel`; `compact`; `set_config_option` (a model id validated against
  `configOptions.model.options`); `close`; `delete`; a permission request pauses the silent and stall limits, not the
  ceiling; a failed MCP tool whose text says "Connection closed" / "Not connected" marks that server `failed` in
  `mcp_status`).
- **New** `updates.py` (`session/update` → the existing message classes; MCP `name` `@server/tool` from
  `rawInput.tool_id` or the title, `server` from `_meta.kiro.serverName`, `raw_input` = the unwrapped `arguments`,
  `output` from `rawOutput.response|message|output`, then `content` text, then a string `rawOutput`; an update for an
  unknown id accepted; state kinds yield no message).
- **New** `usage.py` (`PromptUsage`: credits = the sum of every non-replayed `turn_completion`'s credit entries,
  `turn_duration_ms` = the sum of `elapsedTime`, `context_pct` from `context_usage`; `provenance` `metered` only with a
  credit entry; a `*fallback*` kind read defensively into `model` / `fallback_from` and logged as unverified).
- **New** `errors.py` (`KiroError(code, message, retryable, detail)`, the 15 codes of §2 as `ERROR_CODES`,
  `AgentNotActive`, `RpcError`, `classify_rpc_error`, `classify_stderr`, `mcp_failure_server`).
- **New** `timeouts.py` (every default: silent 600, tool stall 300, cancel grace 5, MCP readiness 65, activation 2,
  close grace 5, request 60, compact 300, transport margin 30, write 30 s; `TurnWatch` with an injectable clock and
  messages naming the limit).
- **New** `_v3client.py` (`KiroAgentOptions` per F1 plus `permission_mode` / `on_permission` / `permission_timeout` /
  `allow_fs_write` / `fs_write_root` / `model` / `mcp_servers` / `startup_timeout` (65 s) / `turn_timeout` (300 s, as v2)
  / `stream_limit_bytes` / `debug`; `KiroACPClient` with `start`, `load`, `close` (idempotent, returns the
  `CloseReport`), `prompt`, `steer`, `steer_state`, `cancel`, `compact`, `set_config_option`, `set_mode` (verified),
  `delete`, and the properties `session_id`, `config_options`, `models` (v2 shape from `configOptions`),
  `available_models`, `current_model_id`, `available_commands`, `modes`, `mcp_status`, `kiro_version`; `fs/*` handlers
  keep v2's `allow_fs_write` + `fs_write_root` containment; `_agent_spec` = the placeholder `{id, prompt, tools: []}`;
  `_answer_permission_stopgap` = v2's `permission_mode` port, fail closed).
- `messages.py`: additive fields `ToolCall.server`, `ToolCallUpdate.server`, `ResultMessage.error_code`,
  `TurnResult.error_code`; new `SessionStatus(kind, data)`.
- `__init__.py`: exports `SessionStatus`, `KiroError`, `AgentNotActive`, `ERROR_CODES`; `collect_streaming` copies
  `error_code`. `client.py` is byte for byte unchanged.

Tests: `packages/kiro-agent-sdk/tests/{fake_engine.py, test_v3_replay.py, test_v3_units.py, test_v3_process_tree.py,
test_public_surface.py}`; `genesis/tests/test_sdk_import_boundary.py`;
`packages/genesis-core/tests/test_core_sdk_import_boundary.py` (named `test_core_…` so pytest's module names do not
collide across the two test roots, L-092).

### Tests

- **Fake engine** (`tests/fake_engine.py`): a stdio program the SDK launches through a generated `kiro-cli` shell
  launcher that execs it with the test's Python, so it runs with an empty `PATH`. It checks every client frame
  (method, the set of param keys, `sessionId` / `modeId` / `configId` / `value` / `cwd`, steer message, prompt block
  types and texts, MCP server names), maps answer ids, holds early client frames, answers an unscripted
  `session/close` / `_kiro/session/delete` with `{}`, and logs every check. `FAKE_ENGINE_PRELUDE` synthesizes
  `initialize` / `session/new` (our agent listed, origin `client`) / `set_mode` for fixtures that start mid-session.
  **The one named skip switch: `fake_engine.CHECK_CUSTOM_AGENTS = False`** — `_meta.kiro.customAgents` in
  `session/new` / `session/load` is not compared (each skip is logged; a missing `customAgents` still fails), pinned by
  `test_the_customagents_skip_is_the_one_named_switch`. 53-05 sets it to `True`.
- **`test_v3_replay.py`: 31 tests** — one per fixture (all 28 pairs; `test_every_fixture_has_a_replay_test` fails on a
  new fixture without a test) + `tool-ids.json` (read in `test_shell_auto_approve`) + the top-level `collect()` run on
  the v3 client with the name patched (what 53-06's switch will rely on). Highlights: `set-mode-dropped` →
  `AgentNotActive` naming `vibe`, the `kiro.log` reason in `detail`, **no `session/prompt` ever sent** (also not when
  the caller tries again) and `session/close` after `set_mode`; `steer-at-turn-end` → both engine turns' credits
  (0.060572) and durations (4280 + 3656 ms) summed; `load` → 2 replayed chunks not yielded, credits 0.015037 (the
  replayed 0.032 not counted), mode restored; `cancel` → `unavailable`, `cancel-after-tool` → 0.050547 `metered`;
  `unknown-request` → 8 answers `-32601`, the prompt classified `not_signed_in`; `access-token` → argv has
  `--auth-method client`, the token and ARN never reach the SDK log; `mcp-died` → no status frame, the server marked
  `failed` from the tool text, no turn error; `model-unavailable` → refused by the SDK before sending, and classified
  `model_unavailable` when the engine is sent it raw.
- **`test_v3_units.py`: 31 tests** — framing (`-32601`, handler errors, notification order before the answer, a
  50 000-byte line over a 1 024-byte limit, EOF → classified exit, request timeout, a stuck write), `FrameLog` joined
  redaction (a secret split across two chunks), the classification table (7 engine error shapes) and stderr, the
  timeouts on a fake clock (silent, tool stall, ceiling tie, permission hold), usage sums/replay/provenance/fallback,
  the update fold, launch options, an old kiro / a missing engine at start, an in-place kiro-cli update probed again
  (m1), and session edge cases (unlisted agent, no confirmation, readiness bound, steer unread, tool stall / silent /
  ceiling ending a turn, cancel without an answer).
- **`test_v3_process_tree.py`: 6 tests** — a plain Python tree like W16 (kiro + chat in one group, the engine in its
  own group with an MCP server): **killed while a shell tool runs in the engine's group** (review m3 of 53-02), both
  with an engine that takes SIGTERM and one that ignores it and does not die with its parent — every process gone,
  both groups checked; an `apwt`-like daemon started in its own group after the record survives (`procs.reap`'s job);
  a recorded group whose leader identity no longer matches is skipped and survives; an unreadable process table skips
  and logs the groups (n1); the process table; the Linux `/proc` reader on a fake procfs.
- **Gates** (07b6d07): SDK `pytest -q` **183 passed** (111 before + 72 new); `ruff check src tests` clean; the v3 test
  files with `PATH=/nonexistent` 104 passed. genesis-core `pytest -q` **98 passed** (96 + 2); `ruff check genesis_core`
  clean. genesis `pytest -q` **1844 passed, 1 failed** at beea49b: `tests/test_testexec_execution.py::
  test_regression_job_handler_starts_due_apps_and_skips_busy_ones` fails identically with this change stashed (it uses
  `datetime.now(IST)`; date-dependent, pre-existing, not in this diff — for the backlog); `ruff check genesis` clean.
- **Not run:** the `python:3.13` image (L-112): the Docker daemon (colima) was not running. The Linux `/proc` reader is
  covered by the fake-procfs test only; run the SDK suite in the image before the 53-12 release commit.

### Review

`reviews/53-04-review.md`: round 1 NEEDS_CHANGES (M1 import-gate hole for `from kiro_agent_sdk import _v3client`,
L-088; m1 stale version cache; n1 silent skipped groups), each fixed in `07b6d07` with a regression test that fails
on beea49b; **round 2 SHIP**. Left: n2 (the gates would flag a non-`__all__` dunder such as `__version__`; nothing uses
one) and the dynamic `getattr` / built-up `importlib` string forms, which a static gate cannot see (§3 does not ask).

### Decisions / deviations

- No ADR deviation. The §1 sequencing (agreed before the build, project-tracker 08cbe8c) is followed as written.
- `mcp_failed` is classified but not raised by the SDK in 53-04: at start the caller decides from `mcp_status` (53-06
  §MCP readiness ends the node turn; 53-07 shows a notice); after start the SDK only marks the server `failed` from the
  tool text, since the turn itself succeeds (`mcp-died`).
- Readiness times out to the server's last state with an `error` naming the wait ("still not connected after 65 s");
  it does not raise.
- A pending permission request pauses the silent and tool-stall limits (the engine waits on Genesis, e.g. a chat
  confirm card up to `permission_timeout`); the ceiling still runs.
- A limit (silent, stall, ceiling) sends `session/cancel` and ends the turn on the answer or after the 5 s grace, with
  the limit's code and message; the stop reason is then `cancelled`.
- `turn_timeout` default stays 300 s (as v2); `startup_timeout` default becomes the 65 s MCP readiness bound.
- The `kiro.log` reason is read from the log channel the `initialize` answer names, then any `KIRO_HOME/logs/*/kiro.log`.
- `ps` is found by absolute path (`/bin/ps`, `/usr/bin/ps`) when the launch `PATH` lacks it: an SDK caller may run with
  a narrow `PATH`, and an unreadable table must not leave groups behind silently.
- The fake engine re-uses `session-new-custom-agent`'s recorded `session/new` answer for fixtures cut mid-session,
  listing the client's agent id in place of the recorded one.

### Lesson candidates

- **An import gate that only reads `node.module` misses `from pkg import private_module`** (review M1): a boundary on a
  package's public names must also check each imported name and attribute against `__all__`, and its bypass corpus
  must include the `from pkg import <module>` and alias forms (extends L-088).
- **`StreamReader.readline()` discards an over-limit line** (it clears the buffer on `LimitOverrunError`), so the v2
  "recover the oversized line" path could never see its data; read with `readuntil` and take the overrun with
  `readexactly`. Found by the 50 000-byte unit test, which failed on the first version.
- **A cache keyed on a binary's path outlives an in-place update** (review m1): key a version probe on the file's
  mtime and size.

### Code-map changes

`packages/kiro-agent-sdk/src/kiro_agent_sdk/`: new `launch.py`, `transport.py`, `session.py`, `updates.py`, `usage.py`,
`errors.py`, `timeouts.py` (the v3 core) and the private `_v3client.py` (v3 `KiroACPClient` / `KiroAgentOptions`;
public in 53-06, renamed `client.py` in 53-07). `client.py` is still the v2 client behind the top-level names.
New public names: `KiroError`, `AgentNotActive`, `ERROR_CODES`, `SessionStatus`. Tests: `tests/fake_engine.py` (the
replaying fake engine, switch `CHECK_CUSTOM_AGENTS`), `test_v3_replay.py`, `test_v3_units.py`,
`test_v3_process_tree.py`, `test_public_surface.py`; import gates `genesis/tests/test_sdk_import_boundary.py` and
`packages/genesis-core/tests/test_core_sdk_import_boundary.py`.

### Changes for 53-05..53-07

The sequencing of the public names, the trust placeholder and the fake-engine switch is in §1 (items 1–5) and in
53-05, 53-06 and 53-07, which already carry it. From the build:

- **53-05:** set `fake_engine.CHECK_CUSTOM_AGENTS = True` and update `test_the_customagents_skip_is_the_one_named_switch`
  (§1 item 5); replace `_v3client._agent_spec` with the projection and `_answer_permission_stopgap` with the ladder
  (§1 item 4); register `_kiro/mcp/elicitation` and `_kiro/auth/getAccessToken` in `KiroACPClient._register_handlers`
  (both answer `-32601` today; `test_elicitation_is_routed_to_its_handler` and `test_access_token_request_is_routed`
  register stand-ins and become real tests); register the access token with `Transport.frame_log.add_secret` so it is
  redacted even inside chunk text; the refusal notice can use `Session.steer`; `PermissionRequest.raw_input` comes
  from `Session.tools` (the correlated `tool_call`), already wired; `ToolCall.name` for a built-in is still its title
  (map it through the tool-id table, `updates.ToolIndex.identity`). Add `TrustPolicy` to `test_public_surface.py`.
- **53-06:** point the public names at `_v3client` (and add the `Legacy*` aliases) per §1 item 2 — then
  `test_public_names_still_point_at_the_v2_client_until_53_06` changes on purpose, and
  `test_top_level_collect_runs_on_the_v3_client` already shows `collect` works on the v3 client. The node reads
  `ResultMessage.error_code` (`mcp_failed`, `agent_not_active`, `timeout_*`) and `KiroACPClient.mcp_status` after
  start: a server in `failed` means end the turn before the prompt with `mcp_failed` (the SDK does not do it). The
  turn's `raw_input` is the unwrapped MCP `arguments` and `ToolCall.server` is new, so `_emit_message` /
  `save_tool_output` detection can key on `name == "@blackboard/save_tool_output"` and `raw_input["document"]`
  (`test_shell_auto_approve`). `startup_timeout` now means MCP readiness (default 65 s).
- **53-07:** chat reads steering state from `SessionStatus` (`steering_queued|injected|cleared`, `data.messageId(s)`)
  through `on_status` or `KiroACPClient.steer_state(id)`; Compact progress is `SessionStatus(kind=
  "summarization_completed", data={"status"})`; MCP readiness arrives as `SessionStatus(kind="mcp_status",
  data={"servers"})`; the catalog maps `available_models` (already the v2 `{modelId, name, description}` shape) and
  `available_commands` (raw `availableCommands`, names without "/"); `load()` raises on failure, closing the process
  (fall back to `session/new` + preamble in a new client). The probe cache is per process: the app process sees an
  in-place kiro-cli update (m1).
- **53-12 / release (L-112):** run the SDK suite once in `python:3.13` (or a CI branch run) before the release commit.
- **Backlog:** `tests/test_testexec_execution.py::test_regression_job_handler_starts_due_apps_and_skips_busy_ones`
  is date-dependent and fails today on master (143e9d2) without this change.

## Context manifest

```toml
areas    = ["sdk-acp", "observability-credits"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-032", "ADR-045", "ADR-051", "ADR-080"]
lessons  = ["L-001", "L-011", "L-016", "L-018", "L-044", "L-046", "L-064", "L-008", "L-104", "L-107", "L-108", "L-112"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**", "genesis/genesis/testexec/procs.py"]
upstream = ["53-02", "53-03"]
```
