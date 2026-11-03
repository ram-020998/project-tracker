# 53-02 — Spike: the remaining v3 wire unknowns, recorded as fixtures (gate)

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (spike harness under `genesis/scripts/spikes/53-02/`, fixtures
> under `genesis/packages/kiro-agent-sdk/tests/fixtures/v3/`, notes in this file's As built; no product code). Built by
> genesis-dev on the user's machine with the installed `kiro-cli` (2.37.1 at spec time). Parent:
> `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D5, D6, D7, D9, D10; F3–F7, F9, F10, F15.

## 1. Goal

The 2026-11-03 probe (53-01 §3, `evidence/`) answered most of how v3 behaves. Answer the rest **before** the SDK is
designed in code, record every behaviour the SDK depends on as a frame fixture, and measure the numbers the defaults
need (timeouts, F7). Probe the **installed CLI, not its docs** (L-044, L-087).

## 2. Questions (each with evidence: the request, the frames, a pass/fail line)

Must-pass items are marked **(gate)**. A FAIL on a gate item stops the phase: the spec agent re-specs the affected
sub-specs before 53-03 starts.

| # | Question | Pass criterion |
|---|---|---|
| W1 **(gate)** | Workspace skills under a private `KIRO_HOME`: a skill in `<cwd>/.kiro/skills/<id>/SKILL.md` is listed (context breakdown) and usable; nothing from `~/.kiro/skills` appears (D6, D7, D8; 51-03 S11 retest) | managed skill visible, personal skill absent |
| W2 **(gate)** | MCP servers from `session/new.mcpServers` with real `env` values (list form, L-001), including a Genesis managed server (`genesis-kb`) and the blackboard server | both start, `env` reaches the server, tools run |
| W3 **(gate)** | The shell over v3 with `execute_bash` in `tools`: permission request shape (`_meta.kiro.toolId`, `consent`), tool frames (`kind`, title, `rawInput`), auto-approve works | frames recorded; a command runs |
| W4 **(gate)** | `session/set_mode` confirmation: the `config_option_update` (or other frame) that proves our agent is active; what happens when the agent fails the engine's schema (deliberately bad field) | a reliable "active" signal and a reliable "dropped" signal |
| W5 **(gate)** | Credits on a turn that does not end cleanly: `session/cancel` mid-turn, a turn hitting the client timeout, a turn whose MCP server fails | `turn_completion` present or absent per case recorded; nothing invents a number (ADR-032) |
| W6 | `session/load` of a chat session after the kiro-cli process exits (same `KIRO_HOME`): history restored, the custom agent re-sent and active, a new turn sees prior context | works, or the exact failure |
| W7 | Steering: the method v3 accepts mid-turn (`_session/steer` or other), its answer, how a consumed steer shows on the wire, what happens to an unread steer at turn end (D10) | method + consumption signal recorded |
| W8 | Clear: `session/close` + `session/new` vs any v3 clear method; Compact: `_kiro/session/compact` on a long session, the `session_info_update` kinds it emits (F15) | both recorded |
| W9 | On-demand MCP loading: the `tool_load` / `tool_call` steps on a 3–5 tool node; whether an `initialize` setting (`_meta.kiro.settings`, cf. KiroCrew `ACP_BACKENDS_CLIENT_META_SETTINGS`) turns it off, and the step/credit difference (F10) | numbers for both, or "no off switch" |
| W10 | Model fallback: the frame v3 sends when a turn moves to another model (`modelFallbackReporting`), and `model` in `configOptions` after a `session/set_config_option` (F6) | shape recorded (force with an unavailable model id if needed) |
| W11 | Images in `session/prompt` (`promptCapabilities.image`), and whether v3 needs only the `prompt` key (today the SDK sends `content` and `prompt`) | image turn works; key decided |
| W12 | `--auth-method client`: the engine's access-token request (`_kiro/auth/getAccessToken` or as observed), its params, the answer shape; with no answer, the failure (F9; 52-01 D8) | request/answer recorded with a token from the user's login, **token value never written to evidence** |
| W13 | HTTP MCP servers in `session/new` (`mcpCapabilities.http: true`): a local Streamable HTTP server reached (52-01 D7 input) | works or the failure |
| W14 | Timings for F7: time between frames in a long silent model step, the longest normal MCP tool call in a real workflow node, and the cancel grace (time from `session/cancel` to the prompt answer) | numbers → 53-04's timeout values |
| W15 | The built-in tool ids on 2.37.1: registered id vs permission `toolId` for each built-in D9 and F2 name (`execute_bash`/`run_command`, `read_file`, `list_directory`, `fs_write`, `str_replace`, `fs_append`, `grep_search`, `file_search`, `web_fetch`, `remote_web_search`, `delete_file`); the meta tools (`tool_load`, `tool_call`, `disclose_context`) | the table for 53-05's fixture |
| W16 | Process tree: which processes kiro-cli starts (engine child, MCP servers) and their process groups; whether killing kiro-cli's own group reaches them (F12) | tree recorded; a kill that leaves nothing behind |
| W17 | `_kiro/mcp/status` states for a server that fails to start, needs auth, or is slow; how long `connecting` lasts (F3) | states + timings |
| W18 | Elicitation: the request an MCP tool's elicitation produces on v3 (`elicitation/create` or `_kiro/mcp/elicitation`) and the decline answer (F8) | request + decline recorded |

## 3. Method

- Reuse the probe's raw JSON-RPC harness (`specs/phase-53-kiro-sdk-v3/evidence/probe*.py`) moved to
  `genesis/scripts/spikes/53-02/`; one script per question group; each writes `evidence/<id>.jsonl` (raw frames) and
  `evidence/<id>.json` (summary + pass/fail). A minimal stdio MCP server like `probe_mcp.py`, plus `genesis-kb` from the
  managed registry for W2.
- Every run uses a private `KIRO_HOME` under the spike's run folder unless the question needs otherwise (D6).
- Never write a token, a secret value or the user's `~/.kiro` contents into evidence; scrub before saving (L-100's rule
  applied to Kiro tokens).
- Credits: about 1–2 per probe run on 2026-11-03; budget ≤ 20 credits for the whole spike; report the real total.

## 4. Fixtures (the product output of this spike)

Copy the frames the SDK depends on into `genesis/packages/kiro-agent-sdk/tests/fixtures/v3/`, one file per behaviour,
each with `<name>.jsonl` (frames in order, both directions, `{dir, msg}`) and `<name>.expected.json` (what the SDK
must produce from it): `initialize`, `session-new-custom-agent`, `set-mode-active`, `set-mode-dropped`, `mcp-allow`,
`mcp-ask-approve`, `mcp-ask-reject`, `fs-write-client`, `shell-auto-approve`, `turn-usage`, `context-usage`,
`cancel`, `compact`, `config-option-model`, `available-commands`, `mcp-status-*`, `load`, `steer`, `elicitation`,
`access-token`, `model-fallback`, `unknown-request`. Record the kiro-cli version in each file's first line. Scrub
`sessionId`s, home paths and request ids to stable placeholders.

## 5. Tests

None for product code. The spike leaves the fixtures plus a small loader test that parses each fixture file (so a
malformed fixture fails CI at once).

## As built

_To be filled by genesis-dev: per question the evidence path, PASS/FAIL, the numbers; the fixture list; the credits
spent; anything that changes 53-04..53-07 (flag it for the spec agent)._

## Context manifest

```toml
areas    = ["sdk-acp", "chat", "core-engine"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-029", "ADR-031", "ADR-032", "ADR-034", "ADR-045", "ADR-069"]
lessons  = ["L-001", "L-011", "L-016", "L-021", "L-024", "L-041", "L-044", "L-046", "L-064", "L-087", "L-100"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/scripts/spikes/53-02/**", "genesis/packages/kiro-agent-sdk/tests/fixtures/v3/**", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py"]
upstream = []
```
