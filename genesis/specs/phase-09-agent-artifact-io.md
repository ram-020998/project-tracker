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
   server's tool results** held in Genesis's memory — so the *server* cannot perform a
   `save_tool_result` write by itself. **However**, `kiro_node` observes *both* the real tool results
   *and* any call to a Genesis tool in the **same ACP stream**, so a `save_result` *signal* can be
   **serviced by the `kiro_node` tap from its own buffer** (the server just acks). This is the key
   that makes save-by-reference work (see §3.3) — the earlier "impossible" verdict applied only to a
   server doing the write on its own.
3. **Agent file writes are invisible to Genesis.** When the agent uses Kiro's built-in file write,
   the SDK handles the `fs/write_text_file` agent→client request **in-process**
   (`_handle_agent_request` writes the file directly) — it is NOT surfaced as a `Message`, so
   `kiro_node` cannot tap it. Only `tool_call`/`tool_call_update` reach Genesis.
4. **`kiro_node` already streams via `collect_streaming(on_message=…)`** — `_emit_message` is the
   exact, existing hook where a capture tap slots in with no new plumbing.
5. **The SDK's `ToolCall` exposes `title`/`kind`/`status`/`tool_call_id` but not a clean tool
   `name`** (the tool name shows up embedded in `title`, e.g. `"Running: @appian-atlas/get_app_schema"`).
   Matching on the display title is brittle → the SDK should surface a stable `name` + `raw_input`.

**Design conclusion:** `kiro_node` **buffers the full tool results it already receives** and persists
them to the blackboard on a **cheap agent signal** (`save_result`, carrying only a pointer — not the
bytes) and/or a **declarative arg-matched `capture` rule**. The agent keeps all its intelligence and
explicitly chooses *which* result to keep even while navigating many tool calls; Genesis supplies the
bytes from its buffer so nothing large is re-emitted. This is the core of Phase 9 (**Capability A**).
A separate, opt-in **blackboard write server** (**Capability B**) covers agents that *author* content;
the `save_result` tool lives on that same server (facade only — the write is done by the tap).

### 2.1 Why a blanket capture-by-tool-name is not enough (the multi-call problem)
If the agent explores — e.g. calls `get_app_schema` for several apps before settling on the target —
a rule "capture every `get_app_schema` result → `raw_schema.json`" is **ambiguous**: `mode=last` keeps
whatever was called last, not necessarily the intended app. So capture must let the agent (or a
precise arg filter) say **which** result is authoritative. Hence the two mechanisms in §3.3.

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

### 3.2 `genesis-core` — the result buffer
`kiro_node` maintains a per-turn **result buffer** populated from the stream it already receives: for
each completed `ToolCallUpdate` it stores the full extracted content, keyed by `tool_call_id` and by
tool `name`, plus a `"last"` slot (the most recent completed result). Bounded (keep the last result
per tool + the last N overall) to cap memory; large results are written straight to disk rather than
held (see §5). This buffer is what both persistence mechanisms below draw from — **the bytes are
never sent back through the model.**

### 3.3 `genesis-core` — two ways to persist (the agent chooses what to keep)

**(a) Explicit `save_result` signal — primary, robust to navigation.**
The agent gets a tiny tool (on the blackboard server, §4) — `save_result(source, document)` — where
`source` is `"last"` (default; the result it just received) or a tool `name`. It carries only a
pointer, not the payload. When the `kiro_node` tap sees that tool call in the stream, it writes
`buffer[source]` to `ctx.workspace.doc(document)` and emits `artifact.captured`; the server merely
acks. This lets the agent explore freely and then persist exactly the authoritative results:
```
… explore/list_apps … choose target …
get_app_schema(app=target)              → save_result("last", "raw_schema.json")
get_schema_relationships(app=target)    → save_result("last", "raw_relationships.json")
DONE
```
Robust to multiple/probe calls and to the agent resolving a fuzzy name to a canonical app id.

**(b) Declarative `capture` rule — convenience for the no-navigation case.**
```python
@dataclass
class Capture:
    tool: str                 # MCP tool name to match, e.g. "get_app_schema"
    doc: str                  # blackboard doc to write
    where: dict | None = None # optional arg filter on raw_input, e.g. {"app_name": "{app}"}
    extract: str = "text"     # "text" | "json" (parsed+re-dumped so the validator's JSON check holds)
    mode: str = "last"        # "last" | "first" among matching calls

def kiro_node(..., capture: list[Capture] | None = None) -> Node: ...
```
The tap auto-persists the matching result with **no agent action**. `where` (matched against the
SDK's new `raw_input`) disambiguates when the agent calls a tool for several targets but the target is
known up-front (`{app}` is templated from `state["inputs"]`). Use this only when there's no
identifier transformation; otherwise prefer (a).

**For `fetch_schema` we use (a)** — the agent navigates, so it must choose; the prompt instructs it to
`save_result("last", …)` after each authoritative call.

Common to both: extraction reuses the SDK's `_extract_text` (exposed as a helper); `extract="json"`
validates + re-dumps; a canonical **`artifact.captured`** event `{node, tool, doc, bytes}` is emitted;
node telemetry gains `captured_docs`.

### 3.4 Workflow change (`genesis-workflows` — `erd-generation`)
`fetch_schema` opts into the blackboard tools (`blackboard=True`, §4) and its prompt becomes
**navigation + explicit save** (no verbatim re-typing):
> *"Explore the available apps and identify the one matching "{app}". Then, for that app: call
> `get_app_schema(...)` and immediately `save_result("last", "raw_schema.json")`; call
> `get_schema_relationships(...)` and immediately `save_result("last", "raw_relationships.json")`. Do
> not paste tool output into your reply. Reply DONE when both files are saved."*

```python
fetch = kiro_node(name="fetch_schema", prompt_fn=fetch_prompt, output_doc="raw_schema.json",
                  mcp=["appian-atlas"], blackboard=True)   # save_result serviced by the tap
```
`v_fetch` (`check_fetch`) is unchanged — the saved docs satisfy it. The agent may probe several apps'
schemas while navigating; only the two it explicitly `save_result`s are persisted, and it emits a
handful of navigation tokens instead of regenerating 145 KB → the timeout disappears.

---

## 4. Capability B — Blackboard write tools (the ergonomic authoring path; opt-in)

For agents that **author** content from judgment (e.g. `assign_domains` → `enriched.json`), provide a
Genesis-owned **blackboard MCP server** injected per node when requested.

### 4.1 The server (`genesis-core/mcp/blackboard_server.py`)
A tiny stdio MCP server (JSON-RPC 2.0, same protocol as `introspect.py` speaks) exposing:
- **`save_result(source, document)`** — persist a *previously returned* tool result by pointer
  (`source="last"` or a tool name). **Facade only: it returns `{ok:true}`; the actual write is done by
  the `kiro_node` tap from its result buffer (§3.2/§3.3a)** — the bytes never flow through this server
  or the model. This is the tool that makes save-by-reference work.
- `write_document(name, content)` — write/overwrite a blackboard doc **by logical name** (for content
  the agent *authors*).
- `append_document(name, content)` — append (chunked authoring of larger content).
- `read_document(name)` / `list_documents()`.
Scoped to the run's blackboard dir, passed via argv/env at launch
(`python -m genesis_core.mcp.blackboard_server --root <workspace.root>`). Rejects paths that escape
the root. No secrets, no network. (`write/append/read/list` operate on the dir directly; `save_result`
is the facade the tap services.)

### 4.2 Injection (`genesis-core` — `kiro_node(blackboard=True)`)
When `blackboard=True`, `kiro_node` prepends the blackboard server to `mcp_servers` (alongside the
node's real servers). `kiro_node` taps its `write_document`/`append_document` `tool_call`s to emit
`artifact.captured`/write events for observability. Prompt authors then say *"write your answer to
document `enriched.json`"* instead of passing an absolute path to `fs_write`.

### 4.2a How the agent discovers + is directed to use the tools (three layers)
Symmetric with how the agent already learns about `get_app_schema` (injected server → `tools/list`):
1. **Discovery (automatic):** injecting the blackboard server means Kiro runs `tools/list` on it, so
   the model sees `save_result` / `write_document` / … in its function list **with their descriptions
   + JSON input schemas**. The tool **description is the teaching surface** — write it action-first,
   e.g. *"`save_result(source, document)` — persist a tool result you already made into a run document
   BY REFERENCE (the system copies the bytes; do NOT paste the content). `source`='last' for the most
   recent tool result, or a tool name."*
2. **Direction (explicit):** the **node prompt** names the tool + `source` + target doc at the right
   moments (see §3.4). The prompt is the imperative; the description is the reference. Steering/system
   context is the fallback if a model under-uses it.
3. **Trust (so it doesn't hang):** when `blackboard=True`, `kiro_node` **auto-adds the blackboard tool
   names to the effective trust set** (`node.tools ∩ allowlist ∪ {blackboard tools}`, or keeps
   trust-all when there's no allowlist), so the call is auto-approved in autonomous mode instead of
   stalling on `session/request_permission`.

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

### 4.5 Packaging & shipping (no repo, no image)
The blackboard server ships **inside `genesis-core`** and is launched as a local Python module — it is
NOT a separate repo, NOT a Docker image, and NOT a registry entry:
- **Where:** `genesis_core/mcp/blackboard_server.py`, beside `mcp/introspect.py`. It's Genesis's own
  code and is coupled to the `kiro_node` tap that services `save_result`, so they version in lockstep
  (one genesis-core release; no cross-repo skew).
- **How it's launched:** `kiro_node` injects it with `command=sys.executable`,
  `args=["-m","genesis_core.mcp.blackboard_server","--root",str(ctx.workspace.root)]`. Using
  `sys.executable` guarantees the same interpreter/venv that already has genesis-core installed — no
  install step, no registry pull, no image build.
- **Why not a Docker image (unlike appian-atlas/jarvis):** those are third-party/internal *services*
  shipped as images; the blackboard server is a trivial, local, filesystem-bound facade coupled to
  genesis-core. Dockerizing it would force per-run bind-mounts, a Docker dependency, startup latency,
  and version skew for zero benefit. It's the `introspect.py` category (Genesis-owned local MCP stdio),
  not the external-image category.
- **Platform-provided, not a registry integration:** it is **not** in `mcp-registry.json`, does **not**
  appear in Settings → MCP, and is orthogonal to the curated/custom tiers (ADR-005/029). `kiro_node`
  injects it internally when `blackboard=True`; users never see or configure it.
- **Future optimization (not now):** the only way to drop even the subprocess would be Kiro/ACP
  supporting client-provided tools (as the SDK already special-cases `fs/read`/`fs/write`); out of scope.

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
2. **A blackboard *server* that performs the `save_tool_result` write itself.** Rejected: MCP servers
   are Kiro children isolated from Genesis's memory (research §2.2), so the server can't read another
   server's result. **The adopted design keeps `save_result` as a server-side *facade* but does the
   write in the `kiro_node` tap from its buffer** (§3.3a) — same ergonomics, correct layer.
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
  `ToolCallUpdate{completed, content=<big JSON>}` for `get_app_schema`, assert the tap buffers it and
  the declarative `capture` rule writes `raw_schema.json` verbatim/parsed, emits `artifact.captured`,
  requires **no** agent write; `where` arg-filter selects the matching call; `extract=json` rejects
  non-JSON.
- **genesis-core (save_result / navigation — the multi-call case):** stub a turn that calls
  `get_app_schema` for **app A, app B, then the target**, each returning different content, followed by
  `save_result("last", "raw_schema.json")` after the *target* call → assert the file holds the
  **target's** result (not A's or B's), proving the agent controls which result is kept; a
  `save_result("get_schema_relationships", …)` by tool-name also resolves from the buffer.
- **genesis-core (blackboard server):** `write/append/read/list` scoped to root; path-escape rejected;
  `save_result` returns `{ok:true}` (facade); MCP handshake works (reuse the introspect test harness).
- **genesis-workflows:** an `erd-generation` graph test with a stubbed agent that probes two apps then
  `save_result("last", …)`s the target's schema + relationships → the two docs land and `v_fetch`
  passes **without** the agent writing files verbatim.
- **DoD:** all suites green (pytest+ruff across sdk/core/workflows; `ci/validate_library.py`); a manual
  `genesis serve` erd run (Docker up) shows `fetch_schema` completing in one short turn with the raw
  docs saved by reference; no `turn_timeout`. Update tracker §6 + `progress/phase-09-…`.

---

## 10. Sequencing

1. **A first** (sdk `name`/`raw_input`/full-content → genesis-core buffer + `save_result` tap + the
   minimal blackboard server that exposes `save_result` → erd workflow prompt). This is the
   performance fix and unblocks `erd-generation`. The declarative `capture` rule ships here too (it's
   pure tap, no server needed).
2. **B second, only if warranted** — the *authoring* tools (`write/append/read/list_document`) on the
   same server; evaluate vs. the `fs_write`-to-blackboard convention before building, since they add
   agent-authored-write ergonomics but not bulk help. (`save_result` from step 1 already establishes
   the server, so B is incremental.)

**Non-goals:** no MCP proxy/gateway; no auth/multi-tenancy (ADR-026); no change to the reliability
trio, the data plane, or the platform API.
