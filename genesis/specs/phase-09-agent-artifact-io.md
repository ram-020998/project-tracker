# Phase 9 — Agent Artifact I/O: Tool-Result Capture & Blackboard Writes

**Status:** 📋 Planned (spec drafted 2026-07-13) · **Layers:** `kiro-agent-sdk` + `genesis-core` +
`genesis-workflows` (no `genesis` platform change). · **Motivated by:** the `erd-generation`
`fetch_schema` timeout (a large MCP tool result can't be persisted within one agent turn).

> **Goal:** let an **agent** step reason with full intelligence *and* get large MCP tool results
> into the blackboard **without re-emitting the bytes through the model** (which blows
> `turn_timeout`), and give authoring agents an easy, safe, blackboard-scoped way to write
> documents. Zero measurable performance cost on the hot path.

---

## 1. Motivation (code-grounded)

`erd-generation`'s `fetch_schema` is a `kiro_node` whose prompt says *"call `get_app_schema` …
write its raw JSON to `{out_path}` … write exactly what each tool returns."* Observed on run
`r-d4c40befde41` (Docker up, MCP healthy): the agent **did** call the real tools
(`@appian-atlas/get_app_schema` + `get_schema_relationships`), but every attempt ended
`agent.result{ok:false, duration_ms≈432000}` — i.e. it hit `turn_timeout` (420 s) — and the
validator `v_fetch` failed with *"raw_schema.json missing/empty or not JSON"*, looping through
both retries.

**Root cause:** the agent has to **reproduce ~145 KB of tool output as its own output tokens** to
write the file (`get_app_schema` ≈ 100 KB + relationships ≈ 41 KB). LLM generation of that volume
does not fit a single turn. This is also an **ADR-010/018 smell** — routing bulk *through the agent
turn* instead of persisting it to the blackboard.

**Constraint (confirmed with the domain owner):** this step genuinely needs an **agent** — it must
explore the apps exposed by the MCP server and narrow to the requested application's schema. A
deterministic program node is NOT acceptable. So the fix must keep the agent and remove only the
byte-copy cost.

## 2. Research findings that determine the design (read the code)

Verified in `kiro-agent-sdk/src/kiro_agent_sdk/client.py` + `messages.py`, `genesis-core/
genesis_core/nodes/agent.py`, `mcp/registry.py`, `workspace.py` on 2026-07-13:

1. **The full tool result is already delivered to Genesis.** ACP `tool_call_update` notifications
   carry the tool's output in `update.content`; the SDK surfaces it as `ToolCallUpdate.content`.
   `kiro_node._emit_message` receives it and calls `_preview(content, limit=2048)` — it **truncates
   for the event but has the full bytes in hand** at that moment. Capturing them is essentially free.
2. **MCP servers are children of `kiro-cli`, not Genesis.** They're passed to `session/new` as
   `mcpServers` and launched by the ACP process; Genesis never proxies MCP traffic. **Consequence:**
   a Genesis-owned "blackboard MCP server" (which would also be a Kiro child) **cannot access another
   server's tool results** held in Genesis's memory. → A `save_tool_result(tool_call_id, name)`
   blackboard tool is **not cleanly implementable** and is rejected (see §7).
3. **Agent file writes are invisible to Genesis.** When the agent uses Kiro's built-in file write,
   the SDK handles the `fs/write_text_file` agent→client request **in-process**
   (`_handle_agent_request` writes the file directly) — it is NOT surfaced as a `Message`, so
   `kiro_node` cannot tap it. Only `tool_call`/`tool_call_update` reach Genesis.
4. **`kiro_node` already streams via `collect_streaming(on_message=…)`** — `_emit_message` is the
   exact, existing hook where a capture tap slots in with no new plumbing.
5. **The SDK's `ToolCall` exposes `title`/`kind`/`status`/`tool_call_id` but not a clean tool
   `name`** (the tool name shows up embedded in `title`, e.g. `"Running: @appian-atlas/get_app_schema"`).
   Matching on the display title is brittle → the SDK should surface a stable `name` + `raw_input`.

**Design conclusion:** the correct, performant mechanism is a **passive capture tap** on the
tool-result stream `kiro_node` already receives — not a proxy, not a program node, not a
save-by-reference tool. The agent keeps all its intelligence; Genesis silently persists designated
raw tool outputs to the blackboard. This is the core of Phase 9 (**Capability A**). A separate,
opt-in **blackboard write server** (**Capability B**) covers agents that *author* content.

---

## 3. Capability A — Tool-Result Capture (the core; the performance fix)

### 3.1 SDK change (`kiro-agent-sdk`, additive minor)
Surface the tool name + raw input, and guarantee the full result content, on the typed messages:
- `ToolCall.name: str` and `ToolCall.raw_input: dict` — parse from the ACP `tool_call` update
  (`toolCallId`, `rawInput`/`raw_input`, `kind`, and the `@server/tool` token in `title` as a
  fallback). Keep `title` for display.
- `ToolCallUpdate.content` stays the **full** ACP content (already the case) — document it as the
  authoritative result payload; add `ToolCallUpdate.name` (carried from the matching `ToolCall`) so a
  consumer can match without tracking ids.
- No behavior change to prompting/turns; purely richer typed messages. Bump kiro-agent-sdk minor.

### 3.2 `genesis-core` — `kiro_node(capture=…)`
Add an optional declarative capture map to `kiro_node`:
```python
@dataclass
class Capture:
    tool: str            # MCP tool name to match, e.g. "get_app_schema"
    doc: str             # blackboard doc to write, e.g. "raw_schema.json"
    extract: str = "text"  # "text" (concatenate text blocks) | "json" (first json/text block, validated)
    mode: str = "last"     # "last" (last completed call wins) | "first"

def kiro_node(..., capture: list[Capture] | None = None) -> Node: ...
```
- **Tap:** wrap the existing `on_message` so that, in addition to `_emit_message`, when a
  `ToolCallUpdate` with `status ∈ {completed, success}` matches a `Capture.tool` (by
  `ToolCallUpdate.name`, falling back to the `ToolCall` recorded for its `tool_call_id`), extract the
  content and **write it to `ctx.workspace.doc(capture.doc)`** — verbatim for `text`, parsed+re-dumped
  for `json` (so the validator's JSON check is guaranteed).
- **Extraction:** ACP content is `[{type:content, content:{type:text, text:"…"}}]`; concatenate the
  text blocks (reuse the SDK's `_extract_text` logic, exposed as a helper).
- **Streaming/large results:** write to the doc as blocks arrive (append) or on the terminal
  `completed` update; either way the bytes never pass back through the model. The SDK already raises
  the ACP stream limit to 64 MB for large payloads — consistent.
- **Multiplicity:** `mode="last"` (default) — if a tool is called more than once (retry, or the agent
  probing), the last completed result wins. `first` available for idempotent fetches.
- **Event:** emit a canonical **`artifact.captured`** event `{node, tool, doc, bytes}` (observable in
  the timeline; the UI can show "captured raw_schema.json ← get_app_schema (103 KB)").
- **Telemetry:** add `captured_docs` to the node telemetry.

### 3.3 Workflow change (`genesis-workflows` — `erd-generation`)
Rewrite `fetch_prompt` to be **navigation-only** and drop the "write the raw JSON to a file"
instruction:
> *"Explore the available apps, identify the schema for "{app}", then call `get_app_schema(...)` and
> `get_schema_relationships(...)` for it. You do not need to save anything — reply DONE when both
> tool calls have returned."*

Declare capture on the node:
```python
fetch = kiro_node(name="fetch_schema", prompt_fn=fetch_prompt, output_doc="raw_schema.json",
                  mcp=["appian-atlas"],
                  capture=[Capture(tool="get_app_schema", doc="raw_schema.json", extract="json"),
                           Capture(tool="get_schema_relationships", doc="raw_relationships.json", extract="json")])
```
`v_fetch` (`check_fetch`) is unchanged — the captured docs satisfy it. The agent's turn now emits a
handful of navigation tokens instead of regenerating 145 KB → the timeout disappears.

---

## 4. Capability B — Blackboard write tools (the ergonomic authoring path; opt-in)

For agents that **author** content from judgment (e.g. `assign_domains` → `enriched.json`), provide a
Genesis-owned **blackboard MCP server** injected per node when requested.

### 4.1 The server (`genesis-core/mcp/blackboard_server.py`)
A tiny stdio MCP server (JSON-RPC 2.0, same protocol as `introspect.py` speaks) exposing:
- `write_document(name, content)` — write/overwrite a blackboard doc **by logical name**.
- `append_document(name, content)` — append (chunked authoring of larger content).
- `read_document(name)` / `list_documents()`.
Scoped to the run's blackboard dir, passed via argv/env at launch
(`python -m genesis_core.mcp.blackboard_server --root <workspace.root>`). Rejects paths that escape
the root. No secrets, no network.

### 4.2 Injection (`genesis-core` — `kiro_node(blackboard=True)`)
When `blackboard=True`, `kiro_node` prepends the blackboard server to `mcp_servers` (alongside the
node's real servers). `kiro_node` taps its `write_document`/`append_document` `tool_call`s to emit
`artifact.captured`/write events for observability. Prompt authors then say *"write your answer to
document `enriched.json`"* instead of passing an absolute path to `fs_write`.

### 4.3 Why B does NOT replace A (be explicit)
`write_document(content)` still requires the agent to **produce** `content` as output tokens — so it
does **not** help the bulk verbatim-copy case (that's A's job). B is purely an ergonomics + safety +
observability win for *authored* content, which is small/medium.

### 4.4 Performance-driven decision on B
Injecting the server adds **one subprocess + MCP handshake per opting node** (startup cost). Therefore
B is **opt-in** (default off) and the server must be fast-starting (pure-Python stdio, no imports of
the heavy genesis stack). **Alternative considered:** keep using Kiro's built-in `fs_write` with a
blackboard-relative path plus a prompt/lint convention (zero new process). Given the modest benefit,
**B is lower priority than A**; ship A first, evaluate B against the fs_write convention before building.

---

## 5. Performance analysis (the explicit requirement)

- **Capability A adds no hot-path cost — it is net faster.** The full tool content is *already*
  received and materialized by `kiro_node` today (for the preview); the tap only **also writes it to
  disk** (a write that replaces the agent's own far-slower fs write). It removes the dominant cost —
  the model regenerating ~145 KB of output tokens (tens of seconds → minutes) — turning a
  timeout-and-retry loop (~14 min, then failure) into a single short navigation turn (seconds). No
  new process, no new network, no extra model tokens.
- **Memory:** the captured result is held transiently (as it already is for the preview). For
  pathological sizes, write incrementally as content blocks stream (append) rather than buffering the
  whole result. The SDK's 64 MB ACP stream limit bounds a single message.
- **Capability B** costs one subprocess spawn + handshake per opting node; mitigated by opt-in + a
  lean server. Not on the bulk path.
- **No change to the platform/API/data-plane;** no `genesis` release strictly required for A/B logic
  (it's core+sdk+workflows), though the erd workflow re-publish + a genesis-core release are needed.

---

## 6. ADR alignment

- **ADR-001** — control flow unchanged; the agent still drives, LangGraph still orchestrates.
- **ADR-002/004** — per-node MCP injection unchanged; capture is a read-only tap on the existing
  ACP stream; the blackboard server (B) is just another injected per-node MCP server.
- **ADR-010/018/022** — this is the *fix* that keeps bulk in the blackboard instead of the agent turn.
- **ADR-024** — async-first; the tap runs inside the existing async `on_message` path.
- **ADR-011** — the reliability trio is unchanged; `v_fetch` still validates the captured artifact.

---

## 7. Alternatives considered & rejected

1. **Program node calling the MCP tool directly (`tools/call`).** Rejected: the step needs agent
   intelligence to navigate/choose the app (domain-owner constraint). (Still noted as valid for
   *purely* deterministic fetches elsewhere.)
2. **`save_tool_result(tool_call_id, doc)` blackboard tool.** Rejected: MCP servers are Kiro children
   isolated from Genesis's memory (research §2.2), so a blackboard server cannot retrieve another
   server's captured result. The tap (A) achieves the same outcome without cross-process state.
3. **MCP gateway/proxy that Genesis interposes.** Rejected for now: a faithful multiplexing proxy
   (initialize/tools/list/tools/call/notifications, N backing servers, secret resolution) is a large
   moving part; the tap gets the same result far more cheaply. Kept as a future option if we later
   need to mediate MCP calls for other reasons.
4. **Plain `write_document(content)` for the bulk case.** Rejected: still re-emits the payload
   through the model (§4.3).

---

## 8. Files touched & release order

| Repo | Change |
|------|--------|
| `kiro-agent-sdk` | `ToolCall.name`/`raw_input`; `ToolCallUpdate.name`; document `.content` as full result; expose `_extract_text` helper. Tests. **Release minor.** |
| `genesis-core` | `Capture` dataclass + `kiro_node(capture=…)` tap; `mcp/blackboard_server.py` + `kiro_node(blackboard=…)` injection; `artifact.captured` event; telemetry. Bump genesis-core pin to the new sdk tag. Tests. **Release minor** (CORE_MAJOR stays 1 — additive). |
| `genesis-workflows` | `erd-generation`: navigation-only `fetch_prompt` + `capture=[…]` on `fetch_schema`; bump genesis-core pin; re-publish. Tests. |
| `genesis` | none required (may bump the genesis-core pin + release if desired so `genesis serve` runs the new core). |

Release order: **kiro-agent-sdk → genesis-core → genesis-workflows** (→ optional genesis pin bump).

---

## 9. Testing / DoD

- **SDK:** `ToolCall.name`/`raw_input` parsed from representative ACP `tool_call` payloads (snake/Pascal
  variants); `ToolCallUpdate.content` carries full multi-block content; `_extract_text` unit tests.
- **genesis-core (capture):** with a stubbed `collect_streaming` that emits a `ToolCall` +
  `ToolCallUpdate{completed, content=<big JSON>}` for `get_app_schema`, assert the tap writes
  `raw_schema.json` verbatim/parsed, emits `artifact.captured`, and does **not** require the agent to
  write; `mode=last` wins on repeated calls; `extract=json` rejects non-JSON; escape-path guard on B.
- **genesis-core (blackboard server):** `write/append/read/list` scoped to root; path-escape rejected;
  MCP handshake works (reuse the introspect test harness).
- **genesis-workflows:** an `erd-generation` graph test with a stubbed agent that "calls" the two
  tools (emitting capture-shaped updates) → `raw_schema.json` + `raw_relationships.json` land and
  `v_fetch` passes **without** the agent writing files.
- **DoD:** all suites green (pytest+ruff across sdk/core/workflows; `ci/validate_library.py`); a manual
  `genesis serve` erd run (Docker up) shows `fetch_schema` completing in one short turn with the raw
  docs captured; no `turn_timeout`. Update tracker §6 + `progress/phase-09-…`.

---

## 10. Sequencing

1. **A first** (sdk → core → erd workflow) — unblocks `erd-generation` and is the performance fix.
2. **B second, only if warranted** — evaluate the blackboard server vs. the `fs_write`-to-blackboard
   convention; build the server only if the ergonomics/observability justify the per-node subprocess.

**Non-goals:** no MCP proxy/gateway; no auth/multi-tenancy (ADR-026); no change to the reliability
trio, the data plane, or the platform API.
