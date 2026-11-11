# 53-01 — Findings: the Kiro SDK on the v3 engine

> **Status:** SPEC-DRAFTED 2026-11-03 — Q&A complete: decisions D1–D12 (§7), defaults F1–F15 (§8, confirmed).
> Parent: `specs/phase-53-kiro-sdk-v3.md` (written after the Q&A).
>
> What was researched and decided before the spec set is written: the problem as the user stated it, how Genesis
> drives Kiro today (code-grounded), what the v3 engine does on the wire (live probe), how KiroCrew drives v3, the
> proposed design, the open questions, and every decision.

---

## 1. The problem (as stated by the user, 2026-11-03)

- Kiro CLI V3 becomes the default experience with CLI 3.0 ([Kiro blog](https://kiro.dev/blog/cli-3/); the
  2.30.0 changelog says "at the end of October"). `kiro-cli acp` 2.37.1 still starts v2 when neither
  `--agent-engine` nor `acp.agentEngine` is set (`kiro-cli acp --help`). KiroCrew's decision record
  (`docs/decisions/2026-10-28-a-kiro-cli-choice-runs-on-kas.md`) says the ACP default moves to v3 and v2 is removed
  at the end of November; not confirmed by Kiro.
- Genesis passes `--trust-tools` on every Kiro launch (chat `genesis/genesis/chat/manager.py:133`, workflow nodes
  `packages/genesis-core/genesis_core/nodes/agent.py:299`) and `--trust-all-tools` for nodes with no tool list. v3
  rejects both at launch (exit 2, measured §3). When the default flips, chat and every agent node stop starting.
- The user wants **one phase that rebuilds `kiro-agent-sdk` for v3, completely**, learning from KiroCrew
  (`github.com/kirodotdev/KiroCrew`, its v3 "KAS" driver) but built for Genesis.

## 2. How Genesis drives Kiro today (verified in the code, 2026-11-03)

Paths: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis`; `sdk/` =
`genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk`; `core/` = `genesis/packages/genesis-core/genesis_core`.

### 2.1 The SDK (`sdk/`, 4 files, ~1 300 lines, 79 unit tests)

- **Surface** (`__init__.py:27-51`): `query`, `collect`, `collect_streaming`, `collect_json`, `extract_json`,
  `load_mcp_servers`, `load_dotenv`, `extract_tool_output`, `KiroACPClient`, `KiroAgentOptions`, `RunWorkspace`,
  `Doc`, the message types. `handoff.py` (`RunWorkspace`/`Doc`) is a pure filesystem blackboard, not ACP.
- **Options** (`client.py:40-89`): `cwd`, `trust_all_tools=True`, `trust_tools`, `permission_mode="auto_approve"`
  (`auto_approve | auto_deny | ask`), `on_permission`, `permission_timeout=300`, `allow_fs_write=True`,
  `fs_write_root`, `agent`, `model`, `agent_engine` (passed through, unused by callers), `kiro_cli_path`,
  `extra_args`, `mcp_servers`, `startup_timeout=30`, `turn_timeout=300`, `command_timeout=120`,
  `stream_limit_bytes=64MB`, `on_commands`, `on_session_status`, `debug`.
- **Launch** (`client.py:155-246`): binary from the option, `PATH` or `~/.local/bin`; argv `acp` + `--trust-all-tools`
  or `--trust-tools <csv>` + `--agent/--model/--agent-engine` + extras; `env=os.environ.copy()`; no `KIRO_HOME`;
  `initialize` (`protocolVersion: 1`, `fs.readTextFile`, `fs.writeTextFile = allow_fs_write`, `terminal: false`),
  then `session/new {cwd, mcpServers}`; reads `models` and `modes` off `session/new`; waits ≤ 1 s for
  `_kiro.dev/commands/available`.
- **Close** (`client.py:249-264`): `terminate()` the kiro-cli process, 5 s, then `kill()`. No process group, so the MCP
  servers kiro-cli starts are not signalled by Genesis.
- **Read loop** (`client.py:289-368`): intercepts `_kiro.dev/commands/available` and
  `_kiro.dev/{compaction,clear}/status` outside turns; every other notification goes to the current turn's queue
  and is dropped when no turn runs. `_translate` maps `agent_message_chunk`, `agent_thought_chunk`, `tool_call`,
  `tool_call_update`, `plan`; others become `UnknownMessage`.
- **Agent→client requests** (`client.py:370-485`): `fs/read_text_file` (any path); `fs/write_text_file` (refused
  when `allow_fs_write=False`; confined to `fs_write_root` with a resolve-and-parents check);
  `session/request_permission` by mode (`auto_approve` picks the first `allow*` option, `auto_deny` the first
  `reject*/deny*` else `cancelled`, `ask` awaits `on_permission` on a task, fail-closed); **any other request gets
  an empty `{}` result** (`:412-414`).
- **Turn** (`client.py:610-670`): one `session/prompt` (sends both `content` and `prompt` keys), drains the queue,
  ends on the response; one flat `turn_timeout`; process death surfaces as a timeout error. **Credits**
  (`:488-536`): folds `_kiro.dev/metadata` (`meteringUsage` `unit == "credit"`, `contextUsagePercentage`,
  `turnDurationMs`) into `usage = {credits, context_pct, turn_duration_ms, provenance}`, `provenance` `metered` or
  `unavailable`.
- **Other methods**: `execute_command` (`_kiro.dev/commands/execute`, unused by chat since L-046), `set_model`
  (`session/set_model`, unused by chat), `set_mode`. **No** `session/cancel`, `session/load`, `session/close`,
  steering, elicitation, MCP status, extension-request or notification hooks.
- **Tests**: 9 files, 79 tests, all unit level (direct calls to `_translate`, `_dispatch`, `_handle_permission`,
  `_accumulate_meta`, `_build_args`). **No fake kiro-cli, no recorded frames; the real wire is never exercised.**

### 2.2 Callers

| Caller | Where | v2-only dependency |
|---|---|---|
| `kiro_node` | `core/nodes/agent.py:195-406` | `--trust-tools` = `_compute_effective_trust` (`:137-166`, node.tools ∩ allowlists, + `BLACKBOARD_TOOLS`), else `--trust-all-tools`; SDK default `auto_approve` (never set, so untrusted tools are approved too, 52-01 §3.1); `agent.result` carries `credits, context_pct, turn_duration_ms, provenance` (`:388-392`); tool-output store and `save_tool_output` detection key on `ToolCallUpdate.name` and `raw_input["document"]` (`:321-337`) |
| `AgentProvider` / `KiroAcpProvider` | `core/agents/provider.py:18-39`, `core/agents/kiro.py:13-43` | none (the ADR-051 seam: `options_cls`, `supports_streaming`, `collect`, `collect_streaming`; tests inject through `set_collect_impl` / `set_agent_provider`) |
| skill provisioning | `core/nodes/agent.py:78-114` | copies skills to `<run>/.kiro/skills/`; never sets `KIRO_HOME` (`:87`) |
| chat session | `genesis/chat/manager.py:98-168` | `--trust-tools` from `build_chat_mcp` (`chat/mcp.py:91-148`) + mode `extra_trust` (`fs_read`, `fs_write` for the six spec-style modes `feature_spec`, `ux_design`, `technical_design`, `feature_breakdown`, `story_design`, `test_design`; `chat/mode_profile.py:243-283`); `auto_deny` or `ask`; `fs_write_root` = per-session skill-output dir; cwd = `~/.genesis` or the sandbox |
| chat cold start | `chat/manager.py:151-154, 382-395` | replays a bounded history preamble on every new client (app restart, idle reap, Stop) |
| chat Stop | `api/chat.py:262`, `chat/manager.py:359-376` | closes (kills) kiro-cli; the next turn cold-starts with the preamble |
| chat Clear / Compact | `chat/manager.py:486-505`, `api/chat.py:210-224` | `/clear`, `/compact` sent as prompts (kiro-cli v2 intercepts a leading slash) |
| chat catalog | `chat/manager.py:438-477`, `api/chat.py:193-201` | `session/new.models` (`availableModels`, `currentModelId`), `modes`, `_kiro.dev/commands/available`; a throwaway client fills the cache |
| chat model | `chat/manager.py:479-484` | persisted per session (m0011), applied at the next start as `--model` |
| chat status | `chat/manager.py:170-179` | `_kiro.dev/{compaction,clear}/status` → `session.status` events |
| web chat | `web/src/types/chat.ts:17-105`, `features/chat/ChatThread.tsx:72-88,176-186`, `Composer.tsx` (`:313-322` shows Stop **instead of** Send while streaming; textarea `:303`, model select `:180` and attach `:309` are disabled while streaming), `hooks.ts:139-142` | shapes `ChatModel{modelId,name,description}`, `SlashCommand{name,description,meta}`, `usage{credits,context_pct,turn_duration_ms,provenance}`, `agent.result`, `permission.request{tool_call_id,tool_name,args,options}`; Stop aborts the SSE and posts `/cancel` |
| run detail | `web/src/features/run-detail/conversation.ts:133`, `components/Inspector.tsx:106-177`, `RunDetailPage.tsx:105-180` | `agent.result.credits/provenance` per turn, summed per node and run |
| Kiro sign-in | `genesis/runtime/kiro_auth.py`, `runtime/preflight.py:35-38` | `kiro-cli whoami/login` on the user's global login (not the SDK) |
| 51-03 spike | `genesis/scripts/spikes/51-03/harness.py` | imports the private modules `kiro_agent_sdk.client` / `.messages` (`:28-29`); `agent_engine="v3"`, `trust_all_tools=False` (`:282-284`); swaps `os.environ` to pass a clean env (`:88-89`). Historical once D5 deletes the v2 options |
| genesis-workflows | `workflows/**/graph.py` | no direct SDK use; everything goes through `kiro_node` |

Contract shapes the web and DB rely on (must stay stable): `usage` and `agent.result` keys above; the typed message
class names (`AgentMessageChunk`, `AgentThoughtChunk`, `ToolCall`, `ToolCallUpdate`; `chat/events.py:23-47`,
`core/nodes/agent.py:169-192`); `GET /chat/models` = `{models:[ChatModel], current}`; `GET /chat/commands` =
`{commands:[SlashCommand]}`; Clear/Compact return `{ok, error?}`; `chat_messages.usage.credits`
(`chat/store.py:168-180`); the web fixtures `web/src/test/fixtures/events.ts`, `data.ts`.

### 2.3 Global Kiro configuration reaches Genesis sessions today

51-03 P10 (`genesis/scripts/spikes/51-03/evidence/d3c-p10.json`): a workflow turn loads the user's global
`~/.kiro/settings/mcp.json` and trusts its servers (`jira` started with `JIRA_TOKEN`; `testcase-mcp` exposed Jira
write tools), contrary to ADR-004; accepted until Phase 52 (51-01 D3d). Chat (Phase 14) deliberately keeps the
user's global `~/.kiro/skills` active, with the managed workspace winning on a name clash.

## 3. What the v3 engine does (live probe, kiro-cli 2.37.1, 2026-11-03)

Three throwaway probes (scripts and raw frames kept in `specs/phase-53-kiro-sdk-v3/evidence/`: `probe.py`,
`probe2.py`, `probe3.py`, `probe_mcp.py`, `frames2.jsonl` (default `HOME`), `frames3.jsonl` (private `KIRO_HOME`),
`frames4.jsonl` (`tool_load` bypass attempts); the first run's frames were overwritten, its results are in the table)
drove
`kiro-cli acp --agent-engine v3` over raw JSON-RPC with a two-tool stdio MCP server (`probe`: `echo`, `secret`) and
a custom agent `{tools: ["@probe/echo", "read_file", "list_directory", "fs_write", …], permissions: {rules:
[{capability: "mcp", match: ["probe/echo"], effect: "allow"}]}}`, model `claude-sonnet-5.5`. About 20 turns,
roughly 1–2 credits. **To move into the repo as fixtures (53-03).**

| # | Behaviour | Result |
|---|---|---|
| P1 | `--trust-tools`, `--trust-all-tools` | Both rejected at launch, exit 2: "not supported with --agent-engine=v3". (The CLI 3.0 blog says `--trust-all-tools` stays for interactive V3; not for `acp`.) |
| P2 | `initialize` | `protocolVersion: 1`; `loadSession: true`; `sessionCapabilities {list, close, delete, fork}`; `mcpCapabilities {http, sse}`; `_meta.kiro`: `checkpoints`, `policyNotifications`, `modelFallbackReporting`, `autoCompactionThreshold {min 0, max 80, default 80}`, `extensionMethods` (incl. `_kiro/session/compact`, `_kiro/session/context`, `_kiro/session/history`, `_kiro/config…`, `_kiro/workflow/*`), `logging.logDir`; `authMethods`. |
| P3 | `session/new` with `_meta.kiro.customAgents` | Our agent listed as a mode with `source.origin: "client"`; `currentModeId: "vibe"` (the engine's default agent, all built-ins) until `set_mode`; no `models` key (models in `configOptions`: ids `mode`, `model`, `effortLevel`, `memoryReflection`, `autopilot`, `contentCollection`). Start-up: process + `initialize` 0.7 s, `session/new` 2.5 s, `set_mode` 0.1 s. |
| P4 | `session/set_mode` | Returns `{}`; confirmation is a `config_option_update` with `mode.currentValue` = our id. |
| P5 | `tools` as a hard limit | Holds. Visible: the listed built-ins + `tool_load`, `tool_call`, `disclose_context`. Shell, `delete_file`, `probe/secret` (not listed) unavailable; `tool_load` of an unlisted server or tool returns `not_found`. |
| P6 | `mcp` allow rule | `probe/echo` ran with no permission request. |
| P7 | Listed MCP tool, no rule | `session/request_permission` with `_meta.kiro.toolId: "mcp_probe_secret"`, `consent {capability: "mcp", resource: "probe/secret"}`, `mcpTool.identity {serverName, toolName}`, `agentManagesTrust: true`; options `accept / always-accept / reject / always-reject` (kinds `allow_once / allow_always / reject_once / reject_always`). Approve runs it; reject → tool `failed` "The user rejected this tool call.", turn continues (`end_turn`), the model reports "rejected by the user". |
| P8 | MCP call shape | MCP tools are loaded on demand: the model calls `tool_load {tool_ids: ["probe::echo"]}` then the tool. The tool's frames: `title: "@probe/echo"`, `kind: "other"`, `_meta.kiro.serverName: "probe"`, **`rawInput: {tool_id: "probe::echo", arguments: {...}}`** (arguments nested), `rawOutput: {response, message, imageBase64Urls}`. No `_meta.kiro.toolName`. |
| P9 | File writes | Permission request `toolId: fs_write`, `consent.resource` relative inside the workspace (`out.txt`), absolute realpath outside (`/private/tmp/…`); the write itself is a client `fs/write_text_file` (preceded by `fs/read_text_file`). A client refusal blocks it, so `fs_write_root` still works. |
| P10 | Credits and context | No `_kiro.dev/metadata`. `session_info_update` with `_meta.kiro.kind`: `turn_completion` (`promptTurnSummaries[{unit: "credit", usage}]`, `elapsedTime`, `status`, `requestIds`), `context_usage` (`usagePercentage`, `summarizationThreshold`, token `breakdown`), `turn_start`, `turn_end` (`stopReason`), `user_message_id_assigned`, `focus_update`. |
| P11 | Models | `session/set_model` → `-32603` "no persistence classification"; `session/set_config_option {configId: "model", value}` works. |
| P12 | Commands | No `_kiro.dev/commands/available`; standard `available_commands_update` instead. `_kiro.dev/commands/execute` → `-32603`. `/compact` sent as a prompt is plain text to the model. `_kiro/session/compact` → `{success: true}`. No `_kiro.dev/{compaction,clear}/status`. |
| P13 | `session/cancel` | Turn ends `stopReason: "cancelled"`; the same session answers the next prompt. |
| P14 | Other notifications | `_kiro/mcp/status` (per-server `connecting`/…, origin `client` or `user`), `_kiro/tools/didChange`, `_kiro/sessions/changed`, `_kiro/customAgent/config_error` (the user's own broken agents), `_kiro/steering/documents_changed`, `_kiro/governance/state`, `_kiro/policy/changed`, `_kiro/memory/syncStatus`, `_kiro/powers/items_changed`, `_kiro/progressive_context/items_changed`. |
| P15 | Default `HOME` | The engine started the user's global MCP servers (`jira`, `testcase-mcp`, `power-jarvis-jarvis`), listed `~/.kiro/skills/appian/SKILL.md` as context, the user's steering docs, and every `~/.kiro/agents` agent as a mode. The agent could not call the global servers (P5). |
| P16 | Private `KIRO_HOME` (empty dir) | None of P15 loaded; sign-in still worked (credentials are not under `KIRO_HOME`); the engine wrote `settings/cli.json`, `sessions/`, `session-index/`, `logs/`, `enterprise-management/`, `cloud-cache/` there. |
| P17 | Session records | The engine persists every session under `KIRO_HOME/sessions` (the user's `~/.kiro/sessions` is 2.0 GB; Genesis's share unknown). |

Also measured on this machine: `~/.kiro/settings/cli.json` has `chat.agentEngine: "v3"` and
`chat.enableAutoAgentUpgrade: true` (interactive V3 rewrites `~/.kiro/agents/*.json` with `.bak` backups,
[changelog 2.37.0](https://kiro.dev/changelog/cli/)); the probes rewrote nothing.

## 4. How KiroCrew drives v3 (research, 2026-11-03; `src/kiro_crew/` at `github.com/kirodotdev/KiroCrew`)

KiroCrew calls the v3 engine "KAS". Its ACP layer is ~140 files / ~86 000 lines (`acp/`, `agent_sdk/`), built for
eight runtimes; only the KAS parts are relevant.

- **Agent projection** (`acp/kas_agents.py`): `to_client_custom_agent` builds `{id, prompt (inline), tools, permissions,
  description, excludedTools, welcomeMessage, includeMcpJson/includePowers (only when the spec states them),
  resources, mcpServers}`; `tools` absent means zero tools, so it is always explicit; `match` absent means every
  resource; an agent that fails the engine's schema is dropped whole; ≤ 50 agents per batch. Attached by
  `_dispatch.attach_kas_custom_agents` on both `session/new` and `session/load`.
- **Permissions** (`acp/kas_permissions.py`): `@server` → `mcp` rule `server/*`, `@server/tool` → `server/tool`; a glob
  in the server part is refused; shell and file tools never get an allow rule (`WITHHELD_FROM_AUTO_APPROVE`,
  `WITHHELD_CAPABILITIES`), so they reach the permission request where KiroCrew's own checks run; the meta
  capabilities `all`/`builtin`/`filesystem` are expanded before that check; ≤ 64 patterns per rule.
- **Tool ids** (`platform/tool_names.py`, `test/fixtures/kas_builtin_tool_ids.json`): `fs_read` → `read_file`,
  `list_directory`; `fs_write` → `str_replace`, `fs_append` (+ `fs_write`); `grep` → `grep_search`; `glob` →
  `file_search`; `web_search` → `remote_web_search`; the shell registers as `execute_bash` and reports `run_command`;
  `delete_file` is deny-only under `fs_write`. Verified-versions list + a once-per-release warning
  (`warn_kas_vocabulary_drift`).
- **Activation** (`acp/runtime_session_create.py:776-866`, `acp/harness/kas.py:885`): always `set_mode` to the injected
  agent; refuse when the mode is missing or not `origin: "client"` (a built-in under the same id); reserved ids
  renamed (`kas_wire_agent_id`).
- **Identity** (`acp/_dispatch_parts/tool_call_identity.py`): built-ins from `_meta.kiro.toolId`, MCP from
  `mcpTool.identity` / `serverName`; never from the title; an unreadable identity is refused.
- **v3 surface**: credits from `promptTurnSummaries` (`acp/session_handle_kas.py:410`); context from `context_usage`
  (`:303-391`); model via `set_config_option` (`acp/session_handle_model_selection.py:368`); effort via `effortLevel`;
  `_kiro.dev/commands/execute` excluded (`agent_sdk/backends_turns.py:545-567`); Compact via `_kiro/session/compact`
  when listed in `extensionMethods` (`acp/session_handle_compaction.py:74-119`); Clear answered locally
  (`ACP_BACKENDS_LOCAL_CLEAR`); steering (`ACP_BACKENDS_STEER` includes KAS); `session/close` vs
  `_kiro/session/delete` (`acp/harness/kas.py:995-1015`); MCP readiness from `_kiro/mcp/status`
  (`docs/system-specs/modules/acp-client.md` "KAS managed MCP readiness"); skill scope as `skill` deny rules because
  v3 loads `~/.kiro/skills` and the workspace's skills (`acp/kas_skill_scope.py`: 45 → 3 skills); global MCP servers
  are **not** suppressed (`agent-host-contract.md:428-436`).
- **Not used by KiroCrew**: `available_commands_update` (no command UI, `acp/session_handle_kas.py:294`).
- **Runtime hardening**: named timeouts (`acp/client_timeouts.py`), error classification (`acp/transport_errors.py`),
  unknown requests → `-32601`, elicitation (`acp/elicitation.py`), deny notice (`deny_notice.py`,
  `deny_guidance.py`), process-tree tracking (`acp/runtime_process_tree.py`), `session/load` resume
  (`acp/runtime_session_load.py`), import boundary gate (`agent_sdk/__init__.py`, `scripts/check_agent_sdk_boundary.py`),
  recorded frames + expected results per behaviour (`test/fixtures/acp_frames/kas/*.jsonl`).

## 5. Proposed design (assistant draft for the Q&A; §7 decisions win where they differ)

**One engine, one policy object, one public surface.** The SDK is rebuilt as small modules behind the existing public
names, so callers change only where v3 forces it:

| Module | Owns |
|---|---|
| `launch` | binary + version probe (`--version`), argv (`acp --agent-engine v3 [--auth-method]`), env (explicit, clean option), Genesis-owned `KIRO_HOME`, own process group, tree kill |
| `transport` | JSON-RPC framing, oversized lines, requests/responses, unknown agent→client requests → `-32601`, extension requests and a notification hook |
| `agent_spec` | Genesis trust → custom agent: inline prompt, explicit `tools` in v3 ids, `mcp` allow rules for exactly the trusted MCP tools, no allow rule for shell/file tools, reserved-id renaming, schema limits |
| `session` | `initialize`, `session/new` (+ `customAgents`), `set_mode` + confirmation (`config_option_update`, `origin: client`), MCP readiness, `session/load`, `session/close` / `_kiro/session/delete`, cancel, steer, compact, config options (model, effort) |
| `permissions` | one decision ladder per request: identity from `_meta` → Genesis allowlist backstop → mode (`auto_deny` / `ask` / `auto_approve`) → answer once; a fixed cause-specific notice on a Genesis refusal; elicitation declined (nodes) |
| `updates` | `session/update` → the existing typed messages (MCP name from `serverName` + title, arguments from `rawInput.arguments`, output from `rawOutput`), `session_info_update` → usage (credits, context, duration, model fallback) |
| `errors`, `timeouts` | one classification (sign-in, throttled, too large, process died, MCP failed, engine missing / too old) and separate silent-turn / tool-stall / ceiling timeouts |
| `tool_ids` + fixture | measured v3 built-in ids, verified kiro-cli versions, a warning on others |
| `auth` | an optional responder for the engine's access-token requests (`--auth-method client`, for Phase 52) |

Sub-specs (final list in the umbrella §7): 53-01 findings · 53-02 spike (gate) · 53-03 ADR draft + data model ·
53-04 SDK core · 53-05 trust and permissions · 53-06 workflow nodes and skills · 53-07 chat backend · 53-08 readiness
and skills cleanup · 53-09 API · 53-10 web · 53-11 review and acceptance · 53-12 release and onboarding. (No v2-pin
hotfix: D4, D12.)

## 6. Open questions (asked one at a time 2026-11-03; all answered — see §7: Q1→D4, Q2→D5, Q3→D6, Q4→D7, Q5→D8, Q6→D9, Q7→D10, Q8→D11, Q9→D12; the rest → §8 defaults; the wire unknowns below → the 53-02 spike)

Asked one at a time; each answer goes to §7. Still unknown on the wire (for a spike): the shell (`run_command`)
permission request and frames; MCP servers with real `env` values; skills in the workspace's `.kiro/skills` under a
private `KIRO_HOME`; `session/load` after a process restart; images; Clear; turning off on-demand MCP loading
(`tool_load`) through `initialize` settings; `--auth-method client`; HTTP MCP servers (52-01 D7); a credit-less turn
(timeout, cancel); the steering method on v3.

1. Ship a v2 pin now, as its own release, before the rest of the phase?
2. Cutover: a dual-engine period (v2 kept behind an option until v3 passes acceptance) or a single switch?
3. `KIRO_HOME`: one Genesis-owned home for everything, or one per run for workflow turns plus one for chat?
4. Chat and the user's global `~/.kiro/skills`: keep them active (today) or managed skills only?
5. Workflow nodes on the host until Phase 52: which built-in tools they get and how they are approved.
6. MCP on-demand loading (`tool_load`): keep the engine default or turn it off for Genesis sessions?
7. The public API: keep `KiroAgentOptions` / `collect_streaming` (compatible) or a new policy-based API with the
   callers moved.
8. Chat session records and resume: retention rule; resume with `session/load`.
9. kiro-cli versions: the minimum, and refuse or warn on an unverified release.
10. Steering (D3 #12) and model-fallback reporting (#13): where they show in the UI.
11. Phase ordering against Phase 51 (in build) and Phase 52 (Q&A).

## 7. Decisions (locked with the user, one at a time)

| # | Decision | Reason |
|---|---|---|
| D1 | **Scope: a complete rebuild of `kiro-agent-sdk` for the v3 engine.** Every Kiro session Genesis starts (chat in every mode, workflow agent nodes, the one-shot catalog probes) runs on `kiro-cli acp --agent-engine v3`. In scope: v3 launch with a Genesis-owned `KIRO_HOME`; trust as a projected custom agent (`_meta.kiro.customAgents`: explicit `tools`, `permissions` rules, `session/set_mode` activation, checked); permission handling (`auto_deny` / `ask` / `auto_approve`, tool identity from the engine's `_meta`, a Genesis allowlist backstop); the v3 surface (credits and context from `session_info_update`, models through config options, `available_commands_update`, Compact via `_kiro/session/compact`, Clear, Stop via `session/cancel`); version and v3 preflight with a measured tool-id table; golden wire fixtures; moving every caller over and retiring v2. Learn from KiroCrew, do not copy its multi-harness design. Phase 52 (agent isolation) builds on this phase; Phase 51 continues unchanged. Out: other agent runtimes, a warm process pool, KiroCrew's recovery ladder and crash log, and the non-SDK KiroCrew ideas (memory learning, redaction, audit log) which stay in the backlog. | User (2026-11-03): "we need a separate phase to implement all of this … the complete revamp of kiro sdk for v3. We can refer and learn from kirocrew but built specifically for genesis." Warm pool explained and left out: only the 0.7 s process start + `initialize` can be done ahead (`session/new`, 2.5 s, carries the per-node tools and MCP servers), and a pool shared across runs conflicts with ADR-012. |
| D2 | **Name: Phase 53, `phase-53-kiro-sdk-v3`.** | Proposed by the assistant; the user did not object (2026-11-03). Phase 52 is a brief only, 53 is the next free number. |
| D3 | **All fourteen KiroCrew ideas are in scope** (user: "We can add all 14", 2026-11-03): (1) separate silent-turn / tool-stall / turn-ceiling timeouts with a message naming the limit (`acp/client_timeouts.py`); (2) one error classification (not signed in, throttled, request too large, process died, MCP failed) with a remedy and a retry verdict (`acp/transport_errors.py`); (3) wait for MCP readiness (`_kiro/mcp/status`) before the first prompt and report a failed server; (4) session cleanup (`session/close` vs `_kiro/session/delete`) with a retention rule for chat; (5) resume chat with `session/load` instead of a replayed preamble; (6) answer unknown agent→client requests with `-32601`, not an empty result (today `kiro_agent_sdk/client.py:412-414`); (7) MCP elicitation: decline cleanly in workflow nodes, a chat form later; (8) an in-band, cause-specific notice when Genesis refuses a tool; (9) clean up the whole process tree (kiro-cli and the MCP servers it starts); (10) one enforced SDK import surface with a lint gate; (11) fixtures re-measured per kiro-cli release with a verified-versions list and a warning; (12) mid-turn steering in chat; (13) model-fallback reporting next to credits; (14) answering the engine's access-token requests (`--auth-method client`) for Phase 52's D8. | User decision. Each idea is grounded in KiroCrew code (paths above, under `src/kiro_crew/`) and in a Genesis gap found in this research. |
| D4 | **No separate v2-pin hotfix (Q1, option B).** The explicit `agent_engine="v2"` pin and a preflight "this kiro-cli no longer offers v2" error are not shipped as a v0.80.1 patch; Phase 53 itself carries the move to v3 in its normal release. Risk accepted: if CLI 3.0 switches `kiro-cli acp` to v3 before Phase 53 ships, chat and every agent node stop starting until it does. | User (2026-11-03): "B - bcos we will start phase 53 tomorrow. So its fine." Considered: A, a hotfix cut from the `v0.80.0` tag (master is 5 commits ahead with unreleased Phase 51 work, so a master tag would ship half-built code). |
| D5 | **Cutover: a single switch to v3 (Q2, option A).** The SDK is rebuilt for the v3 engine only; every caller (chat in every mode, `kiro_node`, the catalog probe) moves in this phase; the v2 code path (`--trust-tools`, `--trust-all-tools`, `_kiro.dev/metadata`, `_kiro.dev/commands/*`, `_kiro.dev/{compaction,clear}/status`, `session/set_model`, slash commands as prompts) is deleted before the release. No engine setting, no fallback. Safety net: the acceptance sub-spec runs every genesis-workflows agent node and every chat mode live on v3 at least once before the release; a v3 problem found after release is fixed by a patch release. | User chose A (2026-11-03). One code path to build and test; Kiro is retiring v2 (CLI 3.0, [Kiro blog](https://kiro.dev/blog/cli-3/)), so a v2 fallback would live only weeks. Rejected B (both engines behind a setting for a release): two paths to build and test for an engine on its way out. |
| D6 | **`KIRO_HOME`: one per workflow run, one for chat (Q3, option B).** Every Kiro process Genesis starts gets an explicit Genesis-owned `KIRO_HOME`; the user's `~/.kiro` is never read for agents, MCP servers, skills or steering. (1) **Workflow runs:** `<run folder>/_kiro/` (one per run, shared by the run's agent turns), so the engine's session records and logs (`kiro.log`, `mcp.log`) belong to the run, are removed by run retention (ADR-022) and can be read when debugging the run; (2) **chat:** `~/.genesis/kiro-home/chat/`; (3) the catalog probe uses the chat home. Genesis's MCP servers are unaffected: they come from Genesis's registry and travel in `session/new.mcpServers` (ADR-002/004), not from any Kiro config file (probe B1, private home, MCP tool ran). Skills Genesis provisions stay in the session's cwd (`<cwd>/.kiro/skills`, ADR-034/069), not in `KIRO_HOME` (51-03 S11; re-checked in the spike). Consequences: the user's global `~/.kiro/settings/mcp.json` servers no longer load into Genesis sessions (closes the ADR-004 gap of 51-03 P10 / 51-01 D3d for every session, before Phase 52); a user who wants one adds it as a Genesis custom MCP server. Sign-in is unaffected (P16: credentials are not under `KIRO_HOME`). | User chose B (2026-11-03) after asking whether Genesis-installed MCP servers stay available (yes: they never depend on `KIRO_HOME`). Per-run homes fit Phase 52, where a sandbox sees only its run folder (52-01 D11). Rejected A (one shared home): every run's records and logs mixed in one folder, cleanup by per-turn deletes only. Start-up cost of an empty home measured the same (~3.2 s, §3 P3/P16). |
| D7 | **Chat uses managed skills only; skills stay managed in Settings → Catalog → Skills, which gains an Update button (Q4, the user's own option; refined 2026-11-03).** Chat no longer sees the user's personal `~/.kiro/skills` (it has its own `KIRO_HOME`, D6) and Genesis does **not** copy them in: only skills installed in Genesis's managed workspace (`~/.genesis/.kiro/skills/`, discovered through the chat cwd) are available. Skills stay where they are managed today, the Skills sub-tab of Settings → Catalog (`web/src/features/catalog/skills/SkillsTab.tsx`: view, search, install from the genesis-workflows library, author, remove). The only addition is an **Update** button on an installed library skill, calling the existing `POST /api/skills/update` (`genesis/api/skills.py:100`; reinstalls the library's latest ref). No new Settings tab, no "update available" badge. The "shadows a skill in your personal ~/.kiro/skills" warning (`SkillCard.tsx:61-65`, `SkillInfo.shadows_personal`) is removed. | User (2026-11-03): "can we have just the Managed skills … So this avoids copying all the skills from the personal kiro folder which might be unwanted", then: "we dont need a top level skills tab in settings. The skills tab in catalog is just fine. And lets just provide the update button alone." Considered: A (managed only, nothing else) and B (copy `~/.kiro/skills` into the chat home at each session start; rejected by the user as copying skills that may be unwanted). |
| D8 | **Workflows use managed skills only too (Q5, option A).** The `~/.kiro/skills` fallback in the workflow skill resolver (`genesis/runtime/context.py:76-97`, `_skill_source`; line numbers as of v0.81.0, which also added a `playwright-appian` branch that stays, see 53-06 §3) is removed: a skill a workflow declares (`kiro_node(skills=[…])`, ADR-069) comes only from the managed workspace. The `appian` skill, today only in the user's personal `~/.kiro/skills` and declared by `story-implementation` (`genesis-workflows/workflows/story-implementation/graph.py:120-121`, `IMPLEMENT_SKILLS`, `READ_SKILLS`), is **published to the genesis-workflows library** (`genesis-workflows/skills/appian/`) so it installs from the Skills tab. A run whose workflow declares a skill that is not installed fails at the start (as today, `core/nodes/agent.py:106-110`) with a message naming the skill and pointing to Settings → Catalog → Skills; the message's "or the global ~/.kiro/skills" wording goes. | User chose A (2026-11-03). One rule for chat and workflows; a workflow no longer depends on what happens to be in one user's personal folder (another machine may not have `appian` at all). Rejected B (keep the fallback for workflows only). |
| D9 | **Workflow agent nodes on v3: today's built-ins, auto-approved; MCP really capped (Q6, option A).** (1) **Built-ins:** every node's custom agent lists the v3 forms of today's built-ins: shell (`execute_bash`), file read (`read_file`, `list_directory`), file write (`fs_write`, `str_replace`, `fs_append`), search (`grep_search`, `file_search`), `web_fetch`, `remote_web_search`; their requests are approved (`permission_mode="auto_approve"`, set explicitly in `kiro_node`, matching 52-01 D9). (2) **MCP:** the node sees only `node.tools ∩ server allowlist` (`_compute_effective_trust`, plus the blackboard tools); a node with no tool list sees every tool of its servers within each server's allowlist; nothing else is mounted, so ADR-029's cap is enforced by v3's `tools` list (probe P5, P5's `tool_load` bypass attempts refused) instead of only deciding which calls skip a prompt. (3) **Not listed:** v3's `delete_file` (v2's file-write tool cannot delete, so this keeps behaviour) and any other v3 built-in not in (1). The exact id list is confirmed by the spike against kiro-cli's tool table and kept in the measured tool-id fixture (D3 #11). | User chose A (2026-11-03). Keeps every working workflow working; makes the MCP cap real now; the boundary for built-ins is Phase 52's sandbox (52-01 D9). Rejected B (built-ins only when a node lists them): breaks working nodes, e.g. `technical-design-analysis` `analyze_section` ran 26 shell commands without listing the shell (52-01 §4). |
| D10 | **Chat steering: Send steers while a turn runs (Q7, option A).** The composer stays enabled during a turn; Send adds the message to the running turn (v3 steering; the exact method is confirmed by the spike). It shows in the transcript as the user's message marked "sent during the turn" and is stored like any user message. If the turn ends before the agent reads it, Genesis sends it as a normal next message, so nothing is lost. Stop ends the turn with `session/cancel` and keeps the session (no process kill, no cold start). Applies to every chat mode (read-only rules are unchanged: a steered message is a user message, ADR-031). | User chose A (2026-11-03). The natural chat behaviour; KiroCrew enables steering for v3 (`agent_sdk/backends_turns.py:94`) and queues a steer the turn did not read (`harness-parity.md` H6). Rejected B (a separate Steer button) and C (SDK only, no UI). |
| D11 | **Ordering: Phase 51 is completed and released first; Phase 53 starts after it (Q8, option C).** Phase 53 builds on the master that carries Phase 51, so its callers include Phase 51's new agent workflows (`story-verification` for the Verification lane, `action-capture` for recording, `setup-composer`; `test-execution` is program-only; list corrected after Phase 51 shipped, see §9); D5's live acceptance covers them on v3. Phase 52 builds on Phase 53 (D1). Consequence: the D4 risk (CLI 3.0 switching `kiro-cli acp` to v3 before Phase 53 ships) lasts through the rest of Phase 51 as well; Phase 51's acceptance runs on v2. | User (2026-11-03): "We will complete 51 first and then start 53." No branch juggling and no half-built work on a shared tag. Rejected A (pause 51, release 53 first) and B (parallel, 53 on a branch). |
| D12 | **D4 stands after D11 (Q9, option B).** No v2 pin, neither as a hotfix nor in Phase 51's release; the risk that CLI 3.0 switches `kiro-cli acp` to v3 before Phase 53 ships is accepted for the whole of Phase 51 too. If it happens, the recovery is to start Phase 53's v3 work at once (or pin kiro-cli's engine by hand with `acp.agentEngine`). | User (2026-11-03): "lets go with B, keep D4 as it is: no pin, and accept the risk until Phase 53 ships" (after first asking for a pin prompt, then withdrawing it). Rejected A (add the pin to Phase 51's release). |
| D13 | **After W1's gate FAIL, W2–W5 ran before the re-spec (2026-11-10).** W1's failure is a defect in one shipped skill file, not in the v3 skill mechanism, and W2–W5 do not use skill files, so the whole gate was measured first and the re-spec covers it in one pass. W6–W18 (and the new W19) wait for this re-spec. Result: W2–W5 PASS (53-02 As built). | User approved the assistant's recommendation (2026-11-10); the dev agent ran them for 2.29 more credits (2.75 of 20 in total). Rejected: re-spec first, then run W2–W5, which risks a second re-spec round. |
| D14 | **The `playwright-appian` skill is fixed upstream (Q10, option A).** (1) `playwright-appian` (own repo, own semver): `skills/playwright-appian/SKILL.md:3` `description` becomes a `>-` block (as `genesis-test-authoring` writes it); its skill test parses the front matter with a strict YAML parser instead of matching a text prefix (`tests/skills/skill.test.ts:54-57`); release **0.3.1** to the GitLab npm registry (project 13864). (2) genesis re-vendors the **published** 0.3.1 tarball byte for byte (`genesis/testexec/vendor/`, `VENDORED_APWT_VERSION`, `testexec/vendor.py`), and an app workspace picks it up through "Update testing runtime". (3) Genesis checks a skill's front matter before provisioning it: `_skill_source` (`genesis/runtime/context.py`) runs `parse_skill_md` + `validate` (`genesis/skills/model.py:90-157`, PyYAML `safe_load`) on every source, managed or checkout. An invalid file fails the node with a message naming the skill, the YAML error and the remedy ("Update testing runtime" for `playwright-appian`, Settings → Catalog → Skills for a managed skill). Today such a skill is lost silently on v3 (53-02 W1). | User chose A (2026-11-10). The fix lands where the file lives, and the agent keeps reading the skill of the exact `apwt` version it drives (51-07 §7). Rejected B (Genesis rewrites the front matter while provisioning): it edits another package's file and hides the defect. |
| D15 | **Stop: a fixed note on the next prompt (Q11, option B).** Stop sends `session/cancel` and keeps the session (D10). The stopped user message stays in the Genesis transcript, marked as stopped. On the next prompt to that chat, Genesis puts a fixed note at the start of the prompt: "[The previous request was cancelled by the user. Answer only the request below; use the cancelled request only if this request refers to it.]" Program code builds the note as a constant; it never contains the stopped request's text or anything the model or a tool produced. Whether the note is needed is read from the stored transcript (the latest turn before this prompt ended cancelled), so it survives an app restart and a `session/load`, which replays the stopped prompt (53-02 W19 d). It is sent once per Stop, also when the Stop came after the model had started answering. Genesis does not use `_kiro/checkpoint/revertMultiple`. | User chose B (2026-11-10) after the assistant checked KiroCrew: its Stop sets a one-shot flag and the next prompt starts with a `[PREVIOUS TURN WAS CANCELLED BY THE USER …]` block telling the model to answer only the current request (`context_assembly/replay.py` `cancelled_turn_preamble`, `session.md` `prev_turn_cancelled`); it never reverts. KiroCrew built that for v2, which forgot cancelled turns; on v3 the turn is kept and carried out, and a shorter fixed line of the same intent ("The previous request was cancelled by the user. Do not continue it.") stopped it 0/3 (53-02 W19 b); the D15 wording itself is first tested live in 53-11 A3. Unlike KiroCrew's block, Genesis's note does not put the stopped turn's text back into the prompt (v3 still holds it). The note keeps "continue that" working and uses no unadvertised method. Rejected A (revert with the note as fallback): an unadvertised method, and the engine would forget a request the transcript still shows. Rejected C (both every time). Risk: the note relies on the model obeying (3 runs); 53-11 A3 re-tests it live, and revert stays a possible later fallback. |
| D16 | **No path scope on file reads in this phase (Q12, option C).** The projected agent's `fs_read` allow rule stays unscoped (`match: ["**"]`), in chat's spec-style modes and in workflow nodes alike, so reads behave as they do today: any path the user can read (53-02 W15 A). Confining agents to their folder is left whole to Phase 52 (52-01). 53-02 W15's finding that `match: ["./**"]` confines `read_file`/`list_directory` (absolute paths only tested) and the untested cases (`../`, a symlink pointing out, `~`, `grep_search`/`file_search`; review m5) are recorded as Phase 52 input. ADR-086 states the read tools are not confined (ADR-083 risk a stays open). | User chose C (2026-11-10). Considered: A (scope reads in the six spec-style chat modes, which have no shell, so it would be a real boundary) and B (scope everywhere, which for workflow nodes only looks safer because their shell reads anything). |
| D17 | **Genesis's skill store accepts any subfolder, as the Agent Skills standard does (Q13, option B).** The store's rule that bundled files live only under `scripts/`, `references/` or `assets/` (`genesis/skills/store.py:151-171`) is removed: a bundled file may sit at any relative path inside the skill folder. Kept: no absolute paths, no `..` segments, no dot-file or dot-folder segments, the 5 MB per-file and 200-file caps (`store.py:28-29`), and the `SKILL.md` front-matter checks. The `appian` skill is copied with its `registry/components-registry.json` unchanged; the library copy differs from the user's only in `references/documentation-lookup-strategy.md:191`, whose `skills/appian/registry/…` path becomes the skill-root-relative `registry/components-registry.json`. | User chose B (2026-11-10) after the assistant checked the sources: Kiro's docs show the three folders as optional ([kiro.dev/docs/skills](https://kiro.dev/docs/skills/)); the Agent Skills standard allows any files and folders and calls the three conventions ([agentskills.io/specification](https://agentskills.io/specification)); KiroCrew supports nested folders with no whitelist (`src/kiro_crew/docs/skills.md:50`). Rejected A (move the file to `assets/` in the library copy): the copy drifts from the user's, and the next standard skill with its own folder fails the same way. |

## 8. Defaults — ✅ confirmed by the user 2026-11-03 ("i accept")

| # | Default | Why |
|---|---|---|
| F1 | **Public API.** Keep the public names and shapes callers and the web rely on (§2.2): `query`, `collect`, `collect_streaming`, `collect_json`, `KiroACPClient`, `KiroAgentOptions`, the message classes, `TurnResult`, `usage {credits, context_pct, turn_duration_ms, provenance}`. `KiroAgentOptions` loses `trust_all_tools`, `trust_tools`, `agent_engine`, `command_timeout`, `on_commands`, `on_session_status` (and the client loses `execute_command`, `set_model`); it gains a `trust` policy (built-in tool ids, MCP tools `@server/tool`, which of them are auto-approved), `kiro_home`, `env`, `agent_prompt`. `kiro_node`'s signature (`mcp=`, `tools=`, `skills=`, …) is unchanged, so no workflow changes and `CORE_MAJOR` stays 1 (ADR-019). | Smallest change for callers; ADR-051's seam stays. |
| F2 | **Chat agents per mode.** `read_only` and `copilot`: `tools` = the mode's MCP tools only (today built-ins are untrusted and denied there); MCP read tools get allow rules; copilot's mutating tools are listed with no rule, so they reach `ask` and the confirm card (ADR-033). Spec-style modes (`feature_spec`, `ux_design`, `technical_design`, `feature_breakdown`, `story_design`, `test_design`; the last two were missed on 2026-11-03, `chat/mode_profile.py:243-283`): plus the file built-ins (`read_file`, `list_directory`, `fs_write`, `str_replace`, `fs_append`) with an allow rule, as today's trusted `fs_read`/`fs_write`; writes stay confined to `fs_write_root` by the client (§3 P9). No shell in any chat mode. | Parity with today's chat trust (ADR-031/034, L-041). |
| F3 | **MCP readiness.** Before the first prompt, wait (within `startup_timeout`) until every server Genesis sent is `connected` or failed (`_kiro/mcp/status`). Workflow node: a failed server ends the turn before any prompt with a classified error (no credits spent; the reliability retry applies). Chat: start anyway and show a notice naming the failed server. | D3 #3. |
| F4 | **Session records and resume.** Workflow turns end with `session/close`; their records stay in the run's `_kiro/` until run retention (D6). Chat: records kept while the chat exists; deleting a chat deletes its record (`_kiro/session/delete`); an idle-reaped or restarted chat resumes with `session/load`, falling back to today's preamble replay if the load fails (logged). | D3 #4, #5. |
| F5 | **kiro-cli versions.** Minimum = the release the spike verifies (expected 2.37.1); below it, or without the v3 engine, preflight fails and chat and runs refuse to start with "update kiro-cli". A newer release not in the verified list warns once per version (log + Settings health) and runs. | D3 #11; Genesis does not install kiro-cli. |
| F6 | **Model fallback.** When v3 reports a turn moved to another model, `usage` records `model` and `fallback_from`; chat and run detail show "answered by <model>" beside the credit badge. | D3 #13. |
| F7 | **Timeouts.** Three limits: no frame for a set time (silent turn), a tool call that never finishes (tool stall), the caller's ceiling (`turn_timeout`, unchanged per caller). Values set from the spike's measurements. Each ends the turn with a message naming the limit. | D3 #1. |
| F8 | **Elicitation.** Declined in every session this phase, with a notice naming the tool; a chat form is backlog. | D3 #7. |
| F9 | **Access-token requests (`--auth-method client`).** The SDK supports them with an `on_access_token` callback and never logs the token; Genesis does not use it until Phase 52 (its D8 picks the token source). Tested with recorded frames. | D3 #14. |
| F10 | **On-demand MCP loading (`tool_load`).** Keep the engine's default unless the spike shows it adds steps or credits on typical nodes; then turn it off through `initialize` settings. | §3 P8. |
| F11 | **Deny notice.** Only on a Genesis refusal, a fixed text per cause (e.g. read-only chat: "This chat is read-only; <tool> is not available here."), never built from tool arguments. | D3 #8. |
| F12 | **Process tree.** kiro-cli starts in its own process group; close = `session/close`, then terminate the group, kill it after 5 s. | D3 #9. |
| F13 | **Import boundary.** `genesis/` and `genesis-core` import only top-level `kiro_agent_sdk` names; a test fails on a private-module import. | D3 #10. |
| F14 | **Fixtures.** Recorded v3 frames under `packages/kiro-agent-sdk/tests/fixtures/v3/`, a replaying fake engine for tests, and the measured tool ids + verified versions in one fixture. | D3 #11, L-011. |
| F15 | **Compact and Clear.** Compact = `_kiro/session/compact`; progress from `session_info_update` maps to today's `session.status` event. Clear = close the Kiro session and open a new one; Genesis's transcript stays. Both keep returning `{ok, error?}`. | §3 P12; web unchanged. |

## 9. Re-check against Phase 51 as shipped (genesis v0.81.0 + 2 fixes at `62537c2a`, genesis-workflows v0.25.0)

The specs were written against v0.80.0. After Phase 51 shipped (2026-11-08) every code citation in this set was
re-checked against HEAD, and Phase 51's specs, ADR-081..085 and lessons L-101..L-112 were read for their effect here.

### 9.1 What Phase 51 changed in the code Phase 53 rebuilds

- **Unchanged since v0.80.0:** the whole SDK (only the version in `pyproject.toml`), `genesis-core` `nodes/agent.py` and
  `agents/*`, `chat/{manager,mcp,mode_profile,store,events}.py`, `api/{chat,skills,system}.py`, `skills/*`,
  `runtime/kiro_auth.py`, web `features/{chat,run-detail,catalog}`. The line-number corrections made on this re-check
  are old imprecision, not Phase 51 drift.
- **Changed:**
  - `runtime/context.py`: `APWT_SKILL_ID` (`:15`), the `playwright-appian` branch in `_skill_source` (`:87-92`;
    resolved only from `<run>/checkout/node_modules/playwright-appian/skills/`), and an `apwt` factory in
    `ctx.extras`.
  - `runtime/preflight.py`: two optional items, Node 20+ and Playwright Chromium (`:67-78`, same `_item` shape;
    optional = warning).
  - Migrations `m0026`–`m0028` (DB v28). Phase 53's migration is therefore `m0029`.
  - ADR-081..085 are taken. Phase 53's ADR is **ADR-086**.

### 9.2 Workflows with agent nodes (genesis-workflows v0.25.0) — the D5 acceptance set

15 workflows, 55 agent nodes. `sync-application`, `sync-documents` and `test-execution` are program-only.
"Grounding" = `mcp=["genesis-kb","appian-dev"]`, `tools=KB_RO+DEV_RO`.

| Workflow | Agent nodes (mcp / tools / skills) |
|---|---|
| hello-appian | `make_result` (mcp `[]`) |
| erd-generation | `fetch_schema` (`appian-atlas`); `assign_domains` (`[]`) |
| code-review | `fetch_ticket` (jira, `@jira/get_jira_issue`); `fetch_package`, `resolve_objects`, `fetch_context`, `kb_check`, `kb_preanalysis`, `review_object` (jarvis, listed tools); `propose_verdict` (`[]`, `blackboard=False`) |
| generate-business-map | `synthesize_capabilities`, `synthesize_value_streams` (`[]`, `blackboard=False`) |
| memory-consolidation | `extract`, `reconcile` (`[]`, `blackboard=False`) |
| memory-maintenance | `reflect`, `curate` (`[]`, `blackboard=False`) |
| ux-design-analysis | `screen_inventory` (`[]`, `image_docs`); `spec_reconcile` (`[]`); `live_grounding` (grounding); `synthesize` (`[]`); `verify` (grounding, `image_docs`); `heal` (grounding) |
| technical-design-analysis | `plan_sections`, `draft_section`, `synthesize` (`[]`); `analyze_section`, `verify`, `heal` (grounding) |
| feature-breakdown-analysis | `plan_epics` (`[]`); `break_epic`, `verify`, `heal` (grounding) |
| story-design-analysis | `research`, `verify` (grounding); `design` (`[]`) |
| test-design-analysis | `design_cases`, `compose_scenarios`, `heal` (genesis-kb, KB_RO); `verify` (grounding) |
| story-implementation | `reverify_design`, `prepare_rollback`, `verify`, `implement`, `heal`, `author_wiki` (`NODE_MCP`/`NODE_TOOLS`, `graph.py:104-119`; `implement`/`heal` add `appian-dev-write`, 55 create/update tools, no delete); skills `appian` (+ `appian-object-generation` on `implement`/`heal`; none on `author_wiki`) |
| story-verification (51) | `explore`, `author`, `triage`, `heal`, `propose` — no `mcp`/`tools` (so blackboard + D9 built-ins); skills `playwright-appian`, `genesis-test-authoring`; `turn_timeout` 900/900/600/600/600 s |
| action-capture (51) | `segment`, `heal` — as above; 900 s |
| setup-composer (51) | `compose`, `heal` — as above; 900 s |

Live prerequisites this adds to 53-11: the QA environment and its test users (the three Phase 51 workflows, ADR-082);
the `jira` and `jarvis` servers (code-review) and `appian-atlas` (erd-generation) resolving from Genesis's registry and
secrets, not from `~/.kiro` (D6).

### 9.3 Phase 51 behaviour Phase 53 must keep (and where it lands)

1. **The shell recipe (ADR-083 decision 2).** Browser agents run
   `cd <ws> && PLAYWRIGHT_APPIAN_HOME=<run>/.apwt npx --no-install apwt -s <role> …` through `execute_bash` (L-101: never a
   bare `npx`). A 51-03 explore turn made 26 tool calls in 194 s for 8.44 credits. → 53-02 W3/W14 use this workload;
   D9's built-ins cover it; 53-11 A1.
2. **The inherited environment.** Those turns need the worker's `PATH` (Node from nvm or Homebrew for `npx`) and
   `PLAYWRIGHT_BROWSERS_PATH`. ADR-083 accepted risk (b) (the shell inherits the whole environment) stays open until
   Phase 52. → 53-04's default env (the caller's environment + `KIRO_HOME`) is kept; Phase 53 does not narrow it.
3. **Long turns.** `turn_timeout` 900 s on explore/author/capture (ADR-083 decision 6); a live heal took 482 s of 600.
   → 53-04/53-06: the silent and tool-stall limits must never end such a turn early; W14 measures them on this workload.
4. **Program-owned browser processes.** `apwt open` leaves a session daemon and its Chromium running in their own
   process groups, recorded in `<run>/.pids` and reaped by `testexec/procs.py` on cancel, pause and the startup sweep
   (L-104, L-107). The worker records an intended stop before the kill and writes terminal state by compare-and-set
   (L-108). → 53-02 W16, 53-04 `close()`: killing kiro-cli's group must not reach those groups, and must not write a
   run state of its own.
5. **Skills.** `playwright-appian` comes only from the run's checkout; `genesis-test-authoring` is a managed library
   skill. → 53-06 §3 keeps the branch; 53-02 W1 checks both under a private `KIRO_HOME`.
6. **Run folder layout.** `<run>/checkout/`, `.apwt/`, `apwt-out/<role>/`, `.pids/`, `inputs/`, `.kiro/skills/`
   (provisioned skills). `<run>/_kiro/` (D6) collides with none of them. `testexec/runner.py` `scrub_dir` scans only
   the report folder and `apwt-out`, so `_kiro/` is not scrubbed or copied; run retention removes it (ADR-022).
7. **ADR-083 and ADR-029.** ADR-083 records that a node with no tool list trusts every tool, including servers from the
   user's global Kiro configuration (accepted risk d). D6 closes risk (d): global servers no longer load. D9 replaces
   "trusts every tool" with "D9's built-ins + the node's servers within their allowlists". Risks (a)–(c) (unenforced
   session rules, inherited env, passwords in the `open --login` subprocess env) stay until Phase 52. → ADR-086 also
   amends ADR-083 and ADR-029 (53-03).
8. **Phase 51's live acceptance is still open (D38).** Its findings ship as v0.81.x patches, which may change the
   three Phase 51 workflows while Phase 53 builds. → Each Phase 53 sub-spec rebases on current master before it
   starts. 53-06 and 53-11 re-diff genesis-workflows. 53-12's version numbers shift if patches ship first. Lesson
   L-111 (say plainly where acceptance is open) applies to both phases.
9. **CI image.** The CI image (`python:3.13`) has no Node or kiro-cli (L-112). The fake engine and fixture tests must
   not need either.

### 9.4 Corrections made on this re-check

- Line numbers in §2, D3, D7, D8 and 53-06/53-07 (for example the unknown-request `{}` reply is
  `client.py:412-414`; `run_slash_command` is `manager.py:486-505`; `POST /skills/update` is `api/skills.py:100`;
  `Inspector.tsx` lives under `run-detail/components/`).
- Chat has **eight** modes, not six. `story_design` and `test_design` are spec-style modes with
  `extra_trust=("fs_read","fs_write")` and `cwd_sandbox=True`, so they get F2's spec-mode agent (F2, 53-07, 53-11 A2).
- D11's list of Phase 51 agent workflows is corrected (`test-execution` is program-only; `setup-composer` was missing).
- The 51-03 harness imports private SDK modules. It sits under `scripts/spikes/`, outside F13's gate (which scans
  `genesis/genesis/**` and `genesis-core`), and becomes historical when D5 deletes the v2 options.
- The Composer today shows Stop **instead of** Send while streaming and disables the textarea, the model select and
  attach (`Composer.tsx:180, 303, 309, 313-322`). D10 needs the textarea and Send enabled during a turn, so 53-10 W1 is a
  real layout change.
- Tests that assert today's behaviour and must change: `genesis/tests/test_workflow_skill_provisioning.py` (asserts the
  `~/.kiro/skills` fallback, 53-06), `genesis/tests/test_skills_store.py:158-161` and `web/src/types/skill.ts:15-16`
  (`shadows_personal`, 53-08/53-10), `tests/test_chat_mode_profile.py` (53-07).

### 9.5 Default from this re-check — ✅ confirmed by the user 2026-11-10 (option A)

| # | Default | Why |
|---|---|---|
| F16 | **Composer during a turn.** While a turn runs, the textarea stays enabled and Send and Stop are both shown. Send steers (D10) and Enter does the same. The model select and attach stay disabled, so a steer is text only. | D10 needs the textarea and Send enabled (§9.4). The model applies at the next start (21-05), not mid-turn. The steering method takes text only (53-02 W7), so a steer cannot carry an image. User confirmed A (2026-11-10). Rejected B (Stop only during a turn, Enter steers): no visible way to steer. A separate Steer/Queue split was not offered (D10 rejected a separate Steer button). |

## 10. Spike gate re-spec (53-02 W1–W5, 2026-11-10)

Results live in 53-02's As built. This section records what they change and what is still open.

### 10.1 Facts (verified by the spec agent)

- **W1 FAIL is a skill-file defect, not a v3 one.** `playwright-appian/skills/playwright-appian/SKILL.md:3` has an
  unquoted `description:` value that contains `: ` (since `0ada4c1`). v3 parses front matter strictly, drops the whole
  skill, and logs it only to `kiro.log` (`skill.frontmatter.invalid`). The vendored `genesis/testexec/vendor/
  playwright-appian-0.3.0.tgz` carries the same file. A strict `yaml.safe_load` of every skill's front matter: the four
  genesis-workflows library skills pass; `playwright-appian` fails. The library skills and Genesis's managed store are
  already parsed strictly (`genesis-workflows/ci/validate_skills.py:41-66`; `genesis/skills/model.py:90-157` on
  create, get and list, where list skips a bad skill silently). The gap is `playwright-appian`'s own skill: its test
  matches a text prefix only (`tests/skills/skill.test.ts:54-57`), and Genesis copies it from the checkout without
  parsing it (`runtime/context.py:87-92`). (Corrected on Q10: an earlier draft of this paragraph said nothing parses
  front matter.) The v3 skill mechanism itself passed: workspace skills load from the cwd under a
  private `KIRO_HOME`, and personal skills never appear (D6–D8 stand).
- **A canary in the reply does not prove a skill loaded.** The model found and read the dropped file by browsing.
  Check the engine's skill list (`_kiro/progressive_context/items_changed`).
- **An agent's read tools are not confined.** In W1 the agent listed `~/.kiro` and `~/.kiro/skills` unprompted. The
  engine loads nothing from there, but `read_file`/`list_directory` reach any path the user can (ADR-083 risk a). This
  applies to workflow nodes (D9) and to chat's spec-style modes (F2). 53-03's ADR draft now says so; 53-02 W15 checks
  for path-scoped `fs_read` rules.
- **W2–W5 consequences applied to the sub-specs:**
  - 53-04: the activation check (the `set_mode` answer proves nothing); the cancel grace (0.01–0.03 s); a mid-turn
    MCP death is classified from the tool failure text; an update for an unknown tool-call id is accepted.
  - 53-05: the shell's permission id `run_command` ≠ the listed id `execute_bash`; `kind` and `raw_input` come from
    the correlated `tool_call`; `semantic_reviewer` is reserved.
  - 53-02: W15 gains path scoping; W19 is added.

### 10.2 Defaults set in this re-spec (the user may object)

| # | Default | Why |
|---|---|---|
| F17 | **Credits on an aborted turn.** Per turn, `provenance` is `metered` when the engine's `turn_completion` carried a credit entry (a cancel after a finished tool round: 0.05) and `unavailable` when it did not (a cancel during a model call, a killed process). `partial` stays an aggregate value only (some turns reported, some not), as `genesis/runs/eventlog.py:188-207` already defines it. The cancellation shows in the turn's status. | ADR-032 requires real numbers and honest provenance. An engine-sent number is real metered data even for an aborted turn. Using `partial` per turn would change the meaning the run totals already give it. |

### 10.3 Open, asked one at a time

- **Q10: How the `playwright-appian` skill is fixed.** Answered: D14 (option A, fix upstream).
- **Q11: How Stop keeps a stopped prompt from being carried out by the next turn.** Answered: D15 (option B, a fixed
  note on the next prompt).
- **Q12: Should `fs_read` be limited to the working folder?** Answered: D16 (option C, not in this phase; Phase 52).
- **F16** (§9.5): confirmed (option A, Send and Stop both shown during a turn; text-only steer).

All questions are answered; nothing in the spec set is open.

- **Q13 (raised 2026-11-10, before 53-06): the `appian` skill's `registry/` folder.** Answered: D17 (option B, the
  store accepts any subfolder, as the Agent Skills standard does).

### 10.4 53-02 complete (2026-11-10, review SHIP)

W6–W19 results, the timings, the tool-id table and the 28 fixtures are in 53-02's As built. This re-spec carried them
into the sub-specs:
- **53-04:** activation now fails closed on `_kiro/customAgent/not_found` (the engine moves the session to `vibe`) and
  never prompts that session again. Credits are summed over every engine turn of a prompt, and replayed credits are
  skipped. Timeouts are 600 s silent, 300 s tool stall and a 5 s cancel grace, with MCP readiness at 65 s. Also: the
  steer, load, compact, model-validation, `prompt`-only, HTTP-MCP, elicitation and access-token shapes; the kill
  checks both process groups; redaction works on joined chunk text.
- **53-05:** the tool table comes from the fixture; capabilities come only from a fixed list; the elicitation method
  and the access-token answer (with `profileArn`) are spelled out.
- **53-06:** the bare `npx` line in the skill is fixed too.
- **53-07:** steering and resume are spelled out.
- **53-08:** the minimum kiro-cli is 2.37.1.
- **53-09:** the steer API returns `queued`.

Still unmeasured, owed to the build:
- the model-fallback frame (W10; handled defensively in 53-04);
- a kill while a shell tool runs (W16, review m3; 53-04 test);
- path-scope edge cases (W15, review m5): Phase 52 input (D16), not tested in this phase;
- whether a revert survives a later `session/load` (W19, review m2);
- the loader test in the `python:3.13` image (Docker was down; L-112).

## Context manifest

```toml
areas    = ["sdk-acp", "chat", "core-engine", "runs-worker", "config-secrets"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-029", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-045", "ADR-051", "ADR-069", "ADR-083"]
lessons  = ["L-001", "L-002", "L-016", "L-017", "L-024", "L-041", "L-044", "L-046", "L-101", "L-104", "L-108", "L-111", "L-112"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md", "tracker:specs/phase-51-test-execution-engine.md"]
code     = ["genesis/packages/kiro-agent-sdk/**", "genesis/genesis/chat/manager.py", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/runtime/context.py", "genesis/genesis/skills/**"]
upstream = []
```
