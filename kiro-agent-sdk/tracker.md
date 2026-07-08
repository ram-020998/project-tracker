# kiro-agent-sdk — Implementation Tracker

| | |
|---|---|
| **Project** | kiro-agent-sdk |
| **Status** | ✅ Working proof (SDK + first workflow validated end-to-end) |
| **Local path** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/kiro-agent-sdk` |
| **GitLab repo** | `kiro-agent-sdk` (named, not yet pushed at time of writing) |
| **Language** | Python 3.10+ (dev/tested on 3.14.6; also runs on 3.9) |
| **License** | MIT (SDK code) |
| **Created** | 2026-07-06 |
| **Last updated** | 2026-07-07 |
| **Tests** | 39 passing (offline unit) |
| **Depends on** | `kiro-cli` 2.10.0 (ACP subcommand); no runtime pip deps |

---

## 1. Executive Summary

`kiro-agent-sdk` is a Python library that embeds **Kiro's own agent** into your
own programs — the AWS/Kiro analogue of Anthropic's **Claude Agent SDK**.

Rather than re-implementing an agent loop (or forking Kiro's now-proprietary
source), it drives the real Kiro CLI agent over its **Agent Client Protocol
(ACP)** interface (`kiro-cli acp`, JSON-RPC 2.0 over stdio) and surfaces the
event stream as a clean, typed async API:

```python
async for message in query("Fix the bug in auth.py", KiroAgentOptions(trust_all_tools=True)):
    print(message)
```

On top of the SDK we built and validated the first real workflow: an automated
**ERD generation** pipeline that ports `atlas-sql-forge/steering/action-erd.md`
into a program-orchestrated flow (the program does deterministic work; the Kiro
agent is invoked only where genuine judgment/data-access is needed).

**Proven end-to-end** against the `SourceSelection` Appian app: 37 tables, 174
relationships fetched via Atlas MCP, domain-classified, and assembled into a
valid `erd-gen` input document.

---

## 2. Origin & Motivation

Chronological intent that led here:

1. User asked what the **Claude Agent SDK** is (https://code.claude.com/docs/en/agent-sdk/overview).
2. Asked whether we could **build something like it for Kiro**.
3. Asked to **research deeply** — which revealed AWS already has most of the stack.
4. Asked to **build a POC** to prove the approach.
5. Asked to build a **real workflow** using the SDK (ERD generation).
6. Iterated on **architecture** (program-orchestrated, agent-only-where-needed;
   blackboard handoff files) and **fixed multiple bugs** to reach a working run.
7. Renamed `kiro-agent-sdk-poc` → `kiro-agent-sdk`; this tracker created.

---

## 3. Research Findings (grounding the approach)

### 3.1 What Kiro CLI is
- Kiro CLI is the **successor to Amazon Q Developer CLI**. `q` / `q chat` still work; MCP, custom agents, hooks, steering all carry over.
- **License change**: Q Developer CLI was Apache 2.0 (`github.com/aws/amazon-q-developer-cli`, Rust); **Kiro CLI is under the "AWS Intellectual Property License"** → forking Kiro's source is not an option, so we integrate via supported surfaces.
- Config migrated from `~/.aws/amazonq` → `~/.kiro`; tool renames (`fs_read`→`read`, `execute_bash`→`shell`, etc.), backward compatible.

### 3.2 The AWS mirror of the Claude ecosystem
| Claude / Anthropic | AWS / Kiro equivalent | Status |
|---|---|---|
| Claude Code CLI (interactive) | Kiro CLI interactive (`kiro-cli chat`) | Shipped |
| Claude Code CLI `--print` | **Kiro CLI headless** (`--no-interactive`, `KIRO_API_KEY`) | Shipped (CLI 2.0) |
| **Claude Agent SDK** (library) | **Strands Agents SDK** (Apache 2.0, Py/TS) | Shipped |
| Anthropic Client SDK (raw API) | Bedrock `InvokeModel` / boto3 | Shipped |
| Managed Agents (hosted) | **Bedrock AgentCore** | Shipped |

### 3.3 Two interpretations of "an SDK like Claude's for Kiro"
- **(A) General agent framework** → already exists = **Strands Agents** (model + system prompt + tools; hooks, MCP, sessions, structured output, subagents). Not Kiro's specific agent.
- **(B) Embed *Kiro's own* agent as a library** → the true parallel. Kiro exposes this via **ACP** (`kiro-cli acp`). The gap = a thin idiomatic wrapper → **this project fills exactly that gap.**

### 3.4 ACP (Agent Client Protocol) — the surface we wrap
- `kiro-cli acp` speaks **JSON-RPC 2.0 over stdio** (newline-delimited).
- Core methods: `initialize`, `session/new`, `session/load`, `session/prompt`, `session/cancel`, `session/set_mode`, `session/set_model`.
- Session updates: `AgentMessageChunk`, `ToolCall`, `ToolCallUpdate`, `TurnEnd`.
- Agent→client requests: `fs/read_text_file`, `fs/write_text_file`, `session/request_permission`.
- Kiro extensions (`_kiro.dev/*`): commands, MCP events, compaction status — optional.
- Sessions persisted at `~/.kiro/sessions/cli/`. Logs at `$TMPDIR/kiro-log/kiro-chat.log`.

---

## 4. Architecture

```
your code ──query()/collect()──▶ KiroACPClient ──stdin(JSON-RPC)──▶ kiro-cli acp
                                              ◀──stdout(JSON-RPC)──
                                              (spawns Kiro's own agent + its MCP tools)
```

- **Transport** (`client.py`): spawns `kiro-cli acp`, does the `initialize` →
  `session/new` handshake, sends `session/prompt`, and translates the
  notification stream into typed messages. Auto-answers agent→client requests
  (fs read/write, permission auto-approve).
- **Message model** (`messages.py`): typed dataclasses (`SystemInit`,
  `AgentMessageChunk`, `ToolCall`, `ToolCallUpdate`, `PlanUpdate`,
  `ResultMessage`, `UnknownMessage`, `TurnResult`).
- **Public API** (`__init__.py`): `query`, `collect`, `collect_json`,
  `extract_json`, `load_mcp_servers`, `load_dotenv`, `RunWorkspace`, `Doc`.
- **Handoff blackboard** (`handoff.py`): `RunWorkspace` / `Doc` — per-run folder
  of pre-created documents that agent steps write into and the program reads.

### 4.1 Tolerance / robustness built into the transport
- Accepts ACP naming variants: `session/update` **and** `session/notification`,
  PascalCase **and** snake_case update discriminators (`_norm`).
- Unknown notifications become `UnknownMessage` (never crash).
- Auto-approves `session/request_permission` (for autonomous/headless use).
- **64 MB stream buffer** + chunked oversized-line recovery (see Bug #3).
- Captures subprocess stderr; `KIRO_ACP_DEBUG=1` traces all JSON-RPC.

---

## 5. Public API Reference

### Core
- `async query(prompt, options) -> AsyncIterator[Message]` — stream typed messages.
- `async collect(prompt, options) -> TurnResult` — run to completion; aggregate `{text, stop_reason, error, tool_calls, messages}`.
- `async collect_json(prompt, options) -> (data, TurnResult)` — parse JSON from the final text.
- `KiroACPClient` — lower-level transport (`start()`, `prompt()`, `close()`, `stderr_text`).

### Options — `KiroAgentOptions`
`cwd`, `trust_all_tools` (default True), `trust_tools`, `agent`, `model`,
`agent_engine` (v1/v2/v3), `kiro_cli_path`, `extra_args`, `mcp_servers`,
`startup_timeout` (30s), `turn_timeout` (300s), `stream_limit_bytes` (64 MB),
`debug`.

### Helpers
- `extract_json(text)` — recover JSON from fenced/embedded/bare text (largest balanced span).
- `load_mcp_servers(mcp_json_path, only=[...])` — read `mcp.json`, resolve `${VAR}` env refs, emit ACP `session/new` server entries.
- `load_dotenv(path=".env", override=False)` — dependency-free `.env` loader.

### Handoff blackboard
- `RunWorkspace.create(base_dir, run_name, timestamp=True)` — make a run folder.
- `.doc(name, create_empty=True)` — register + pre-create an empty handoff doc → `Doc`.
- `Doc`: `write_text/write_json/read_text/read_json/is_empty/path`.
- `.read_json/.write_json/.manifest()`.

---

## 6. The ERD Generation Workflow (`workflows/erd_workflow.py`)

Ports `atlas-sql-forge/steering/action-erd.md`. **Program orchestrates; agent
only where needed.** Design principle (from the user): *if a step can be done by
a program, write a program; invoke the agent only for genuine agent output.*

| Step | Owner | What happens | Artifact |
|---|---|---|---|
| Workspace | program | create `runs/<app>-erd-<ts>/` + pre-created docs | folder |
| 0. Pre-flight | program | install/verify `erd-gen`, check Lucid token | — |
| 1. Fetch schema | **agent** | Atlas MCP `get_app_schema` + `get_schema_relationships`, **dump raw outputs verbatim** to files | `raw_schema.json`, `raw_relationships.json` |
| 2. Normalize | program | raw Atlas shapes → unified schema | `schema.json` |
| 3. Domain + fields | **agent** | judgment: assign domain per table + select PK/FK/business fields; write decisions | `enriched.json` |
| 3b. Assemble | program | merge relationships, inject domain color palette | `erd-input.json` |
| 4. Run erd-gen | program | `erd-gen generate/update` (subprocess), parse doc id + URL | — |
| 5. Report | program | Lucidchart summary block | — |

### 6.1 Real Atlas MCP output shapes (captured from live runs)
- `get_app_schema` → `{ "TABLE": {"columns": {"COL": {"type": "int(11)"}}, "primary_key": ["COL"]} }`
- `get_schema_relationships` → `[ {"from_table": "...", "to_table": "..."} ]` (no type → default `many_to_one`)

### 6.2 Domain color palette (program-owned; agent only picks the domain name)
`Evaluation #cfe2f3`, `Task Management #d9ead3`, `Consensus #fff2cc`,
`Vendor Management #f4cccc`, `AI #fce5cd`, `Other #d9d2e9`.

### 6.3 CLI
```bash
python3 workflows/erd_workflow.py --app <AppName> [--scope business|full] \
    [--document-id <id>] [--out-dir <dir>] [--workspace <path>] [--dry-run] [--env-file .env]
```

---

## 7. The "Blackboard" Handoff Pattern (key architectural decision)

**Decision:** Never push bulk data through the chat channel. Every time a step
(agent or program) produces something, it writes it to a **named document in a
per-run folder**; the next step is handed the *path*, not the data.

**Why:** LLM agents are slow and unreliable at reproducing large structured
payloads inline (the agent itself said so — see Bug #2). Files give each handoff
a durable, inspectable artifact and remove the inline-JSON bottleneck.

**Reusable:** implemented as `RunWorkspace`/`Doc` in the SDK so every future
workflow uses the same pattern.

---

## 8. Engineering Log — Bugs Found & Fixed (chronological, nothing omitted)

### Bug #1 — Inline-JSON extraction returned a fragment
- **Symptom:** `fetch_schema: unexpected agent JSON: {'name': 'AS_GSS_CRITERIA', ...}` — a single table instead of `{tables, relationships}`.
- **Root cause:** first design asked the agent to dump the **entire schema as one inline JSON reply**. For the large `SourceSelection` app the reply was huge/slow ("stuck at step 2"); when truncated, `extract_json`'s balanced-span fallback grabbed the first complete inner `{...}` (one table).
- **Fix (interim):** switched agent steps to **file artifacts** instead of inline JSON.

### Bug #2 — Agent went off-plan; wrote to `/tmp`, not our path
- **Symptom:** `agent did not write SourceSelection-schema.json ... stop_reason=` (empty). Evidence: agent had written `/tmp/ss_schema.json` (21 KB) and `/tmp/ss_rels.json` (13 KB) itself.
- **Root cause:** told to hand-transcribe a large schema into an exact file, the agent judged it error-prone ("I'll write the raw tool outputs to temp files and transform them with a script to avoid manual transcription errors") and used its own temp files + a transform script. Wrong use of the agent for a mechanical transform.
- **Fix:** adopted the **blackboard pattern** (user's proposal) — pre-create empty docs; agent **dumps raw tool output verbatim**; the **program** does the normalize/transform. Agent's judgment step reduced to **compact decisions** (domain + field constraints), not data reproduction.

### Bug #3 — 64 KB readline overrun silently killed the reader (the real hang)
- **Symptom:** repeated "stuck / step 2 for a long time", then empty `stop_reason` with only the agent's opening narration; run-folder docs all 0 bytes.
- **Root cause:** asyncio `StreamReader.readline()` has a **64 KB per-line limit**. Atlas results are large (`raw_schema.json` 48 KB, normalized `schema.json` 75 KB); a single JSON-RPC line exceeded 64 KB → `LimitOverrunError` killed `_read_loop` → `session/prompt` never resolved → 420 s timeout → empty `stop_reason`. Small tests passed (tiny lines); large apps failed.
- **Fix:** set `limit=64 MB` on `create_subprocess_exec`; added `_read_oversized_line` chunked recovery; added stderr capture + `KIRO_ACP_DEBUG` tracing so failures are diagnosable.
- **Result:** `SourceSelection` dry-run → **exit 0**, 37 tables / 174 relationships.

### Minor fixes along the way
- Missing `collect` import in the workflow (`NameError`) → added to imports.
- `write` tool requires `command` field (create/strReplace) — tooling note.
- Path-bound venv broke on folder moves → recreate venv after each move.
- Removed unused `pytest-asyncio` config option (warning).

---

## 9. Testing

**39 offline unit tests, all passing** (no `kiro-cli` needed):

| File | Tests | Covers |
|---|---|---|
| `tests/test_transport.py` | transport | `_norm`, `_extract_text`, `_translate` (all update types, naming variants), arg building |
| `tests/test_sdk_helpers.py` | helpers | `extract_json` (fenced/bare/embedded/nested/array/none), `load_mcp_servers` (env resolve, missing blank), `load_dotenv` (parse/quotes/export/override/missing) |
| `tests/test_erd_workflow.py` | workflow | `build_erd_document`, palette, `build_erdgen_command`, `parse_erdgen_output` (json+text), `format_report`, `write_input_json`, `_read_written_doc` (file/inline/fences/missing-keys/empty), `normalize_atlas_schema` (real shapes), `merge_relationships` |
| `tests/test_handoff.py` | blackboard | `RunWorkspace` create/doc/write-read/manifest/no-timestamp |

**Live validations performed:**
- `collect_json` structured output against real agent → parsed JSON, `end_turn`.
- Tool-use turn (agent `Reading` tool) → `ToolCall`/`ToolCallUpdate` streamed.
- Large-file write (25 KB) → `end_turn`, no error.
- **Full `SourceSelection` dry-run → exit 0**: raw_schema 48 KB, raw_rels 41 KB, normalized schema 75 KB, enriched 12 KB, erd-input 39 KB; 37 tables, 174 relationships; domains colored; audit columns excluded; PKs/FKs correct.

**Run tests:**
```bash
python3 -m venv .venv && .venv/bin/pip install pytest
.venv/bin/python -m pytest -q
```

---

## 10. File Inventory

```
kiro-agent-sdk/
├── README.md                         (103)  overview, API, workflow, tests
├── pyproject.toml                    ( 22)  package metadata (name kiro-agent-sdk)
├── .env.example                      ( 38)  token config template
├── .gitignore                        (  8)  ignores .venv, .env, caches
├── src/kiro_agent_sdk/
│   ├── __init__.py                   (211)  query/collect/collect_json/helpers/exports
│   ├── client.py                     (450)  ACP JSON-RPC transport (KiroACPClient, KiroAgentOptions)
│   ├── handoff.py                    ( 98)  RunWorkspace + Doc (blackboard)
│   └── messages.py                   ( 95)  typed message dataclasses + TurnResult
├── examples/
│   └── quickstart.py                 ( 57)  streams a single prompt
├── workflows/
│   └── erd_workflow.py               (495)  ERD generation pipeline
└── tests/
    ├── test_transport.py             (105)
    ├── test_sdk_helpers.py           (105)
    ├── test_erd_workflow.py          (163)
    └── test_handoff.py               ( 45)
```

---

## 11. Environment / Configuration

`.env` (git-ignored; loaded automatically by the workflow):

| Var | Purpose | Required for |
|---|---|---|
| `GITLAB_TOKEN` | Atlas MCP docker image auth (schema fetch) | ERD workflow |
| `ATLAS_KB_PROJECT_ID` | Atlas KB project (default 13490) | ERD workflow |
| `ATLAS_DATA_PREFIX` | Atlas data prefix | ERD workflow |
| `LUCID_API_TOKEN` | Lucidchart upload (or `erd-gen config --token`) | Publishing |
| `KIRO_API_KEY` | headless/CI auth (no interactive login) | CI only |
| `APPIAN_ENV_URL`, `APPIAN_API_KEY` | data-generator / LCP MCP servers | extensions |

The workflow reads the Atlas MCP config from the atlas-sql-forge workspace
`mcp.json` and injects **only** `appian-atlas` into the ACP session
(`load_mcp_servers(..., only=["appian-atlas"])`).

---

## 12. Known Limitations / Not Yet Done

- **Live Lucidchart publish not yet run** — all validation used `--dry-run`
  (skips `erd-gen generate`). Needs `LUCID_API_TOKEN` and a real `erd-gen` call.
- **Single-turn only** — `query`/`collect` open+close a session per call.
  Multi-turn (`session/load`, follow-ups) not yet wired.
- **No streaming interrupts / cancel** — `session/cancel` unused.
- **No TypeScript twin** — Python only.
- **`_kiro.dev/*` extensions** surfaced as `UnknownMessage` (not typed).
- **Not yet git-committed / pushed** to the GitLab repo.
- **fs capability**: client advertises fs read/write true and handles those
  requests; interplay with Kiro's own server-side write tool is not fully mapped
  (both paths land files on disk; works in practice).

---

## 13. Next Steps / Backlog

1. **Live ERD run** — drop `--dry-run`, publish `SourceSelection` to Lucidchart; capture doc ID + URL.
2. **Expose usage/metrics in `TurnResult`** — surface ACP usage (credits/tokens), turn count, and tool-call count + wall-clock duration so downstream (Genesis per-node telemetry, `state-and-data-model` §1.4) can record `credits`. Capture `duration_ms/tool_calls/turns` regardless; `credits` when ACP provides usage.
2. **Generalize a workflow base** on top of `RunWorkspace` so new actions (e.g. `action-generate-data`) reuse the blackboard + step-orchestration scaffolding.
3. **Multi-turn sessions** — expose `session/load` + follow-up prompts; keep a `KiroSession` object open across steps.
4. **TypeScript port** of the SDK for parity with Claude Agent SDK ergonomics.
5. **Typed `_kiro.dev` extensions** — slash commands, MCP OAuth, compaction status.
6. **Package + publish** (build wheel; decide internal index).
7. **git init + first commit + push** to the GitLab `kiro-agent-sdk` repo.
8. **Headless/CI mode doc** — run under `KIRO_API_KEY` for pipelines.

---

## 14. Key Decisions Log

| # | Decision | Rationale |
|---|---|---|
| D1 | Wrap `kiro-cli acp`, don't fork Kiro | Kiro CLI is proprietary-licensed; ACP is the supported, stable surface |
| D2 | Provide `query()`-style async API | Match Claude Agent SDK ergonomics for familiarity |
| D3 | Program orchestrates; agent only for judgment/data-access | User's core principle: program where deterministic, agent only where needed |
| D4 | Blackboard handoff files (`RunWorkspace`) | Avoid pushing bulk data through chat; durable, inspectable artifacts |
| D5 | Agent dumps raw MCP output verbatim; program normalizes | Fixes agent transcription anxiety; deterministic transform stays in code |
| D6 | Agent emits compact decisions (domain + field constraints) only | Minimizes agent output; keeps bulk assembly in the program |
| D7 | 64 MB stream buffer + oversized-line recovery | Fixes the real hang (64 KB readline overrun on large payloads) |
| D8 | Injected only `appian-atlas` MCP into the session | Least privilege; the ERD workflow needs no other servers |
```
