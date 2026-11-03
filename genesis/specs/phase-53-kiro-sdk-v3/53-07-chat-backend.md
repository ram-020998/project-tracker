# 53-07 — Chat backend on v3

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (`genesis/chat/**`, `genesis/api/chat.py`,
> `packages/kiro-agent-sdk` v2 removal). Parent: `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D5, D6, D7, D10;
> F1–F4, F6, F8, F11, F15. Uses 53-02 W6, W7, W8.

## 1. Goal

Chat in every mode runs on the v3 SDK with the same API shapes the web reads (53-01 §2.2), plus steering, a Stop that
keeps the session, resume with `session/load` and an MCP failure notice. When this sub-spec is BUILT, no caller uses the
v2 path and it is deleted from the SDK (D5).

## 2. Session start (`chat/manager.py` `_ensure_started`, `:97-176`)

- **Home** (D6): `kiro_home = settings.state_dir / "kiro-home" / "chat"` (created on first use); cwd unchanged
  (`state_dir`, or the skill-output sandbox for the spec modes), so managed skills keep loading from
  `~/.genesis/.kiro/skills/` (D7).
- **Trust per mode** (F2), from `chat/mode_profile.py` + `chat/mcp.py` `build_chat_mcp` (which returns MCP tool names as
  today):
  - `read_only`: `TrustPolicy(builtins=(), mcp_tools=<read tools>, auto_approve=<read tools>, mode="auto_deny")`.
  - `copilot`: `mcp_tools=<read + control mutating tools>`, `auto_approve=<read tools>`, `mode="ask"` →
    `on_permission` (the confirm bridge, `manager.py:181-227`, unchanged; ADR-033).
  - spec modes: `builtins=("fs_read", "fs_write")` added to `mcp_tools`/`auto_approve` (replaces `extra_trust`),
    `fs_write_root` = the skill-output dir (L-041).
- **Agent prompt:** the mode's steering text moves from "prepended to the first prompt" (`profile.steering`,
  `manager.py:243-247`) into the custom agent's `prompt` (sent once with the agent; survives `session/load`).
- **MCP readiness** (F3): a failed server → a `session.notice` event `{kind: "mcp_failed", servers: [...],
  detail}` on the first turn's stream; the turn proceeds.
- **Resume** (F4): if the chat record has `kiro_session_id` (53-03) and the client is new (idle reap, restart, after a
  model change), call `load(kiro_session_id)`; on success no preamble is sent; on failure (logged with the classified
  error) fall back to `session/new` + today's preamble (`_build_preamble`, `:383-396`). Store the new id after every
  `session/new`.
- **Model** (unchanged behaviour, 21-05): the session's model is applied at start with `set_config_option("model", …)`
  instead of `--model`.

## 3. Catalog (`ensure_agent_catalog`, `available_models`, `available_commands`, `:439-477`)

The throwaway catalog client uses the chat home and `TrustPolicy(builtins=(), mcp_tools=(), auto_approve=(),
mode="auto_deny")`. `models` from `config_options["model"]` mapped to today's shape `{availableModels:[{modelId, name,
description}], currentModelId}` so `GET /chat/models` is unchanged; `commands` from `available_commands_update` mapped
to `SlashCommand {name (with "/"), description, meta}`; `modes` unchanged. The cache is cleared on a kiro-cli version
change.

## 4. Turn behaviour (`stream_turn`, `:229-356`)

- **Slash commands typed by the user:** the palette lists the engine's commands; a typed `/…` is sent as a prompt only if
  the engine listed it (v3 handles its listed commands in `session/prompt`; 53-02 W8 confirms which); `/clear` and
  `/compact` are mapped to §5. An unlisted `/x` is sent as plain text, as v3 would.
- **Steering** (D10): `steer(session_id, text)`: when a turn is running, store the text as a user message with
  `meta_json.kind = "steer"`, call the SDK `steer`, and emit `user.steer {seq, text, status: "delivered" | "queued"}` on
  the live stream; at turn end, every steer the engine did not consume (53-02 W7 signal) is reported on `agent.result` as
  `unread_steers: [seq]`, and the web sends them as the next message (53-10). No steer while no turn runs (→ 409 at the
  API, use the normal send).
- **Stop** (D10): `cancel()` becomes `session/cancel` (wait the grace, then mark the turn `cancelled`); the client stays
  alive; pending permission futures resolve as today (`:358-366`); only `delete_session`, idle reap and mode/model
  changes close the client (`session/close`).
- **Refusals and elicitation:** the SDK's notices (53-05) arrive as agent text; nothing to do here.
- **Usage:** `agent.result` adds `model`, `fallback_from` when present (F6); `chat_messages.usage` stores them (no schema
  change).
- `session.status` events: from the SDK's `SessionStatus` (summarization kinds) instead of `_kiro.dev/*/status`
  (`_on_session_status`, `:178-185`); same event shape.

## 5. Clear, Compact, delete (`run_slash_command`, `:486-520`; `api/chat.py:210-224`, `delete_session`)

- **Compact** (F15): `compact()` → `{ok, error?}`.
- **Clear** (F15): `session/close` the Kiro session, `session/new` a fresh one (new `kiro_session_id`), no preamble;
  Genesis's transcript stays; `{ok, error?}`.
- **Delete chat:** `_kiro/session/delete` for the stored `kiro_session_id` (best effort, logged), then today's delete.
- **Idle reap** (`reap_idle`, `:683-692`): `session/close` (record kept for resume).

## 6. v2 removal (D5)

Delete from the SDK: the v2 launch flags, `_kiro.dev/metadata` folding, `_kiro.dev/commands/*`, `_kiro.dev/{compaction,
clear}/status`, `execute_command`, `set_model`, the removed options; their tests are replaced by the fixture tests. Grep
the monorepo and genesis-workflows for any remaining use (`trust_tools`, `trust_all_tools`, `agent_engine`,
`on_session_status`, `execute_command`) and fail the sub-spec until none is left. The 51-03 spike harness keeps working
or is marked historical.

## 7. Tests

`tests/test_chat_manager.py`, `test_chat_api.py`, `test_copilot_*`, `test_chat_store.py` moved onto the fake engine
(53-04): every mode's `TrustPolicy`; catalog shapes from v3 fixtures; steer delivered/queued/unread; Stop keeps the
client and the next turn needs no preamble; resume by load and the fallback; Clear gives a new Kiro session; Compact;
delete removes the record; `session.notice` on an MCP failure; usage with `model`/`fallback_from`. Web fixtures in
`web/src/test/fixtures/` regenerated from real responses (L-011, L-083).

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["chat", "sdk-acp", "api"]
adrs     = ["ADR-031", "ADR-033", "ADR-034", "ADR-042", "ADR-045", "ADR-032", "ADR-053", "ADR-004", "ADR-020"]
lessons  = ["L-007", "L-017", "L-018", "L-041", "L-045", "L-046", "L-047", "L-073", "L-086", "L-011", "L-083"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md"]
code     = ["genesis/genesis/chat/**", "genesis/genesis/api/chat.py", "genesis/tests/test_chat_manager.py", "genesis/tests/test_chat_api.py", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**"]
upstream = ["53-03", "53-04", "53-05", "53-06"]
```
