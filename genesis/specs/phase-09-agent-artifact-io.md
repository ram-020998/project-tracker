# Phase 9 — Agent Artifact I/O: Session Tool-Output Store & Save-by-Reference

**Status:** 📋 Planned — **design validated by spike** (2026-07-13). Spec-only; no production code
until approved.
**Layers:** `kiro-agent-sdk` (additive minor) + `genesis-core` (additive minor, `CORE_MAJOR` stays 1)
+ `genesis-workflows` (erd-generation adoption + docs). No required `genesis` platform change.
**Supersedes:** the earlier "capture tap on `ToolCallUpdate.content`" / "argument-matched capture" /
"program-node fetch" ideas (see §9). Those were ruled out by the spikes in §2.

---

## TL;DR

An agent step can fetch a large MCP tool result (e.g. a ~145 KB Atlas schema) but **cannot write it to
the blackboard by retyping it** — regenerating that many output tokens blows `turn_timeout` (the live
`erd-generation` bug, run `r-d4c40befde41`). The fix, validated end-to-end by a spike:

1. **Genesis records every tool result of a Kiro session to a per-run store** (`_toolcalls/`), purely by
   observing the ACP stream — no bytes pass back through the model.
2. **A Genesis-owned "blackboard" MCP server exposes that store to the agent** via two tools:
   `list_tool_outputs()` (metadata only) and `save_tool_output(ref, document)` (copies a captured
   output to a named blackboard doc **by reference**).
3. **The agent decides** which captured output belongs in which file. Genesis needs **zero** domain
   knowledge — this is why it works as a *common module* across all workflows, not just erd.

Spike result (real Kiro 2.12.1, three ~107 KB fetches for `alpha`/`beta`/`gamma`): the agent saved the
**full 107,839-byte gamma** output to `raw_schema.json`, correct and complete, and **`MARKER-gamma`
never appeared in the model's own messages** (its entire reply was *"I'll execute these steps in
order.DONE"*). 107 KB persisted, zero re-emission. See §2.

---

## 1. Problem & goals

### 1.1 The concrete bug
`erd-generation`'s `fetch_schema` is a `kiro_node` whose prompt says *"DUMP the raw tool outputs
VERBATIM into two pre-created files … Write exactly what each tool returns."* On run
`r-d4c40befde41` (Docker up, Atlas MCP healthy) the agent **did** call the real tools
(`@appian-atlas/get_app_schema` ≈ 100 KB + `get_schema_relationships` ≈ 41 KB) but every attempt ended
`agent.result{ok:false, duration_ms≈432000}` — it hit `turn_timeout` (420 s) trying to **regenerate
~145 KB as its own output tokens** to write the files. `v_fetch` then failed (`raw_schema.json
missing/empty`), the reliability trio retried, and the retries exhausted. Root cause: **routing bulk
through the agent turn's output**, an ADR-010/018 violation.

### 1.2 Hard constraints (confirmed with the domain owner)
- **The step must stay an agent** — it explores the apps the MCP server exposes and narrows to the
  requested application's schema. A deterministic program node is *not* acceptable.
- **This is a common module.** The mechanism must work for **any** workflow, where Genesis will **not**
  have a domain identifier to pick "the right" output. Selection must be driven by the **agent's**
  understanding, not by Genesis matching on inputs.

### 1.3 Goals / non-goals
**Goals:** (a) let an agent get arbitrarily large tool results into the blackboard with **no
re-emission through the model**; (b) generic across workflows (no per-domain wiring); (c) architecturally
standard; (d) no measurable hot-path performance cost. **Non-goals:** trimming the model's *input*
context (that needs a gateway — §9); auth/multi-tenancy (ADR-026); changing the reliability trio, data
plane, or platform API.

---

## 2. Spikes & evidence (why we trust this design)

Two spikes were run against **real kiro-cli 2.12.1** via the SDK. Artifacts lived under `/tmp/spike/`.

### 2.1 Spike 1 — what does Kiro actually send over ACP for a tool call?
A minimal stdio MCP server exposed `get_app_schema(app_name)`; a driver ran one turn and dumped the raw
`session/update` payloads. Findings (decisive):

- **Tool arguments ARE present** on both `tool_call` and `tool_call_update`:
  ```json
  { "sessionUpdate": "tool_call", "toolCallId": "toolu_bdrk_015…",
    "title": "Running: @echo/get_app_schema",
    "rawInput": { "app_name": "alpha" },
    "_meta": { "kiro": { "toolName": "get_app_schema" } } }
  ```
- **A clean tool name** is available at `_meta.kiro.toolName` — no fragile title-parsing needed.
- **CORRECTION to the earlier premise:** the tool **result is NOT in `content`.** For an MCP tool the
  completed update carries it in **`rawOutput`**:
  ```json
  { "sessionUpdate": "tool_call_update", "status": "completed",
    "rawInput": { "app_name": "alpha" },
    "rawOutput": { "items": [ { "Json": { "content": [ { "type": "text",
        "text": "{\"__served_for_app__\":\"alpha\", …}" } ] } } ] } }
  ```
  The SDK's current `ToolCallUpdate.content = update.get("content")` returns **`None`** for MCP tools —
  it silently discards the result (it survives only in `.raw`). **Capture must read `rawOutput`.** We
  would never have caught this without the spike; the original "capture from `content`" plan would have
  written empty files.

### 2.2 Spike 2 — the full loop (store + agent-driven save-by-reference)
Two MCP servers were injected into **one** Kiro session: the `echo` tool server (returning a large,
unique, deterministic per-app payload) and a **blackboard** server exposing `list_tool_outputs()` +
`save_tool_output(ref, document)`. The driver played the `kiro_node` role: it observed the ACP stream
and recorded every non-blackboard tool output to `<root>/_toolcalls/` (`index.json` + `<ref>.out`). The
prompt told the agent to fetch `alpha`, `beta`, `gamma`, then `list_tool_outputs()`, then
`save_tool_output(<gamma ref>, "raw_schema.json")`.

**Result — ALL PASS:**
```
[recorded] call_1 get_app_schema input={'app_name':'alpha'} bytes=107839
[recorded] call_2 get_app_schema input={'app_name':'beta'}  bytes=105317
[recorded] call_3 get_app_schema input={'app_name':'gamma'} bytes=107839
[PASS] raw_schema.json written              [PASS] saved is the GAMMA output
[PASS] contains MARKER-gamma                [PASS] NOT alpha/beta
[PASS] full size (>40KB)                    [PASS] MARKER-gamma NOT in agent's messages (no re-emission)
[PASS] recorded all 3 app fetches           RESULT: ALL PASS ✅
agent final text: "I'll execute these steps in order.DONE"   saved bytes: 107839
```

**What it proves:** (1) two MCP servers coexist in one session; (2) Genesis can record all tool outputs
from the stream; (3) the agent selects the right one **by meaning** (its `app_name`), not by order —
robust even when the agent fired calls in parallel; (4) the **full** output lands byte-correct; (5) the
**decisive** point — 107 KB was persisted while the model emitted ~40 characters, so **the bulk never
passed through the model**; (6) cross-process coordination through the shared run dir works with no
race (a short retry covers the just-written file).

---

## 3. Architecture — session tool-output store + save-by-reference

```
                         ACP session/update stream
   ┌──────────┐   tool_call / tool_call_update   ┌────────────────────────────┐
   │ kiro-cli │ ───────────────────────────────► │ kiro_node (Genesis, in-proc)│
   │  (agent  │                                   │  observes EVERY tool result │
   │   loop)  │ ◄─── tools/call (echo, atlas) ─── │  → writes to the STORE:     │
   └────┬─────┘                                   │    <run>/_toolcalls/        │
        │ launches (session/new.mcpServers)       │      index.json  (metadata) │
        │                                         │      <ref>.out   (full body)│
        ▼                                         └────────────┬────────────────┘
   ┌──────────────┐  ┌───────────────────────┐                │ shared run dir
   │ appian-atlas │  │ blackboard MCP server  │◄───────────────┘ (the blackboard)
   │  (workflow)  │  │ (Genesis-owned, --root)│  reads index / copies <ref>.out → <document>
   └──────────────┘  └───────────────────────┘
                          ▲  list_tool_outputs() / save_tool_output(ref, document)
                          └──── the agent calls these (tiny args; no bulk) ─────
```

**Data plane rule preserved (ADR-010/018/022):** the bulk goes stream → disk (blackboard); the model
only ever handles *metadata* (the index) and *references* (a `ref` + a filename). The two Genesis
processes (`kiro_node` and the blackboard server) never touch each other's memory — they coordinate
through the shared run directory, which *is* the blackboard.

---

## 4. Detailed design

### 4.1 `kiro-agent-sdk` changes (additive minor; e.g. v0.2.0)
Surface, on the typed messages, what the spike proved is present in `.raw`:

| Field | Source in the ACP `update` | Notes |
|---|---|---|
| `ToolCall.name` / `ToolCallUpdate.name` | `_meta.kiro.toolName`; fallback = token after `@server/` in `title` | stable tool identity |
| `ToolCall.raw_input` / `ToolCallUpdate.raw_input` | `rawInput` | the arguments (e.g. `{"app_name":"gamma"}`) |
| `ToolCallUpdate.output` | extracted from `rawOutput` | **the actual tool result** (fixes the `content=None` gap) |

- Add a module helper `extract_tool_output(update_raw) -> str`: walk `rawOutput` collecting
  `{"type":"text","text":…}` nodes (handles the `items[].Json.content[].text` shape observed);
  fall back to `content`, then to `json.dumps(rawOutput)`. Export it (used by genesis-core).
- Keep `content` for back-compat; document that MCP results arrive in `output`/`rawOutput`.
- Purely additive to the message dataclasses. No change to prompting, turns, or the ACP handshake.
- **Tests:** parse representative `tool_call` / `tool_call_update` payloads (snake + Pascal variants;
  the `_meta.kiro.toolName` and `rawOutput.items[].Json.content[].text` shapes captured in Spike 1) and
  assert `name` / `raw_input` / `output` are populated; `extract_tool_output` unit tests.

### 4.2 `genesis-core` — the session tool-output store
A small module `genesis_core/nodes/tool_store.py` (or inline in `agent.py`) owns the store format under
the run's `RunWorkspace`:
```
<workspace.root>/_toolcalls/
  index.json     # JSON array, atomic-written; grows as calls complete
  call_1.out     # full extracted output text of that call (verbatim)
  call_2.out
  …
```
`index.json` entries:
```json
{ "ref": "call_1", "tool": "get_app_schema", "tool_call_id": "toolu_…",
  "input": { "app_name": "alpha" }, "bytes": 107839, "ts": "2026-07-13T…Z" }
```
- **Refs** are short/stable (`call_<n>`, sequential per session) so the agent echoes a clean string.
- **Recording** happens inside `kiro_node`'s existing streaming `on_message` hook: on each
  `ToolCallUpdate` with `status ∈ {completed, success}`, resolve the tool name (map `tool_call_id →
  name` from the preceding `ToolCall`), **skip** the blackboard tools themselves, extract the output
  (`extract_tool_output`), and **atomically** write `<ref>.out` + append to `index.json`.
- **Atomic writes** (`write tmp` → `os.replace`) so the blackboard server never reads a half-written
  index/file (proven necessary pattern in the spike).
- **Bounding:** record all non-blackboard outputs (this *is* the offloading). A configurable
  `capture_min_bytes` (default 0 = all) and a per-session cap can be added later; not needed for v1.
- `_toolcalls/` is scratch — eligible for the spec-04 retention reclaim like other run artifacts.

### 4.3 `genesis-core` — the blackboard MCP server
New: `genesis_core/mcp/blackboard_server.py` — a tiny stdio MCP server (JSON-RPC 2.0, newline-delimited;
same framing `mcp/introspect.py` already speaks: `initialize` → `notifications/initialized` →
`tools/list` → `tools/call`, `protocolVersion "2024-11-05"`). Launched with `--root <workspace.root>`.

Tools exposed:
| Tool | Args | Behavior | Bulk through model? |
|---|---|---|---|
| `list_tool_outputs` | — | read `_toolcalls/index.json`; return the metadata list (ref, tool, input, bytes) | No (metadata only) |
| `save_tool_output` | `ref`, `document` | copy `_toolcalls/<ref>.out` → `<root>/<document>` (bounded retry if the file isn't flushed yet); return `{ok, document, bytes}` | No (ref + filename only) |
| `read_tool_output` *(optional)* | `ref`, `max_bytes=2048` | return a **truncated preview** so the agent can disambiguate by content when inputs aren't enough | No (bounded preview) |

- **Coordination decision (locked): the server does the copy from the on-disk store**, with a bounded
  retry (~3 s) for a just-written `<ref>.out`. This is what the spike used and passed. Rationale: the
  store must be on disk anyway (offloading + `list` needs the index), so a file-copy is the simplest,
  self-contained mechanism; neither process reaches into the other's memory.
  *(Alternative considered — the `kiro_node` tap services `save` from an in-memory buffer and the
  server just acks — removes the race but forces `kiro_node` to hold large outputs in memory for the
  whole turn and still needs the on-disk index for `list`. Rejected as more complex for no real gain.)*
- **Path safety:** `document` is resolved under `<root>` and rejected if it escapes (no `..`, no
  absolute paths). No secrets, no network.

### 4.4 `kiro_node(blackboard=True)` — injection, trust, events, telemetry
- **Injection:** when `blackboard=True`, `kiro_node` prepends the blackboard server to the ACP
  `mcp_servers` list (alongside the node's real servers), shaped exactly like `McpRegistry.acp_servers`
  entries: `{"name":"blackboard","command":sys.executable,
  "args":["-m","genesis_core.mcp.blackboard_server","--root",str(ctx.workspace.root)],"env":[]}`.
- **Trust:** `kiro_node` auto-adds the blackboard tool names to the effective trust set —
  `node.tools ∩ server.allowlist ∪ {list_tool_outputs, save_tool_output, read_tool_output}` — or keeps
  `trust_all_tools=True` when the node has no allowlist. (The spike ran `trust_all_tools=True`; both
  servers' tools were callable with no permission stall.)
- **Recording is always on for an agent node** (it's cheap and generically useful); the *tools* are
  only injected when `blackboard=True`. (A node can therefore record without exposing the tools, e.g.
  for a future auto-capture mode.)
- **Events (additive, dotted convention):** `tool_output.recorded {node, ref, tool, bytes}` on each
  record; `artifact.saved {node, ref, document, bytes}` on each `save_tool_output`. Emitted via
  `ctx.emit`, persisted by the `EventLog`. Rendering these in the web timeline is **optional/out of
  scope** (the transcript folds only `agent.*`); they're observability, not correctness.
- **Telemetry:** node telemetry gains `tool_outputs_recorded` and `documents_saved` (the reducer sums
  the counters and the `_run` aggregate).

### 4.5 How the agent discovers + is directed to use the tools (three layers)
Identical mechanics to how the agent already learns about `get_app_schema` (injected server →
`tools/list`):
1. **Discovery (automatic):** injection ⇒ Kiro runs `tools/list` on the blackboard server ⇒ the model
   sees `list_tool_outputs` / `save_tool_output` with their **descriptions + input schemas**. The
   descriptions are the teaching surface (action-first, "BY REFERENCE — do NOT paste content").
2. **Direction (explicit):** the **node prompt** tells the agent when/how to call them (§10). The prompt
   is the imperative; the description is the reference.
3. **Trust:** auto-added (§4.4) so calls are auto-approved in autonomous mode.

### 4.6 Packaging & shipping (no repo, no image, no registry entry)
- Ships **inside `genesis-core`** (`genesis_core/mcp/blackboard_server.py`), beside `introspect.py`.
  Coupled to the recording code, versioned in lockstep (one genesis-core release).
- Launched as a **local module via `sys.executable`** (§4.4) — no install step, no image build, no
  Docker dependency, no per-run bind-mounts. It needs the local blackboard filesystem, which a
  containerized server would not have cleanly. It's the `introspect.py` category (Genesis-owned local
  MCP stdio), **not** the external-image category (appian-atlas/jarvis).
- **Platform-provided, invisible to users:** not in `mcp-registry.json`, not in Settings → MCP,
  orthogonal to the curated/custom tiers (ADR-005/029). A workflow's `required_mcp` does **not** list
  it — `kiro_node(blackboard=True)` injects it internally.

---

## 5. Persistence modes

**Primary (Phase 9 core): agent-driven save-by-reference.** The agent explores, then uses
`list_tool_outputs` + `save_tool_output(ref, document)` to place exactly the outputs it wants. General,
robust to multi-app navigation and parallel calls, no domain identifier needed. **Validated (§2.2).**

**Optional / deferred: automatic capture.** For workflows that *do* have the identifier or want
zero-agent-action, a declarative rule (`capture=[{tool, where:{arg==input}, doc}]`) or a size-threshold
auto-offload (Deep-Agents style) can write the store entry straight to a named doc. Deferred — the
primary mode already covers erd and is more general. (Feasible: Spike 1 confirmed `raw_input` is
available for `where`-matching.)

**Deferred: authoring tools.** `write_document(name, content)` for agents that *author* small/medium
content (e.g. `assign_domains` → `enriched.json`) — a convenience on the same server, evaluated later
against just using `fs_write` to a blackboard path. Does **not** help bulk (content still flows through
the model), so it's out of the Phase 9 core.

---

## 6. Performance analysis (spike-grounded)

- **No hot-path cost; net far faster.** Recording writes bytes `kiro_node` already receives to disk —
  replacing the agent's catastrophic path (regenerating ~145 KB of output tokens → `turn_timeout`,
  ~14 min then failure) with a few metadata/ref tokens. In Spike 2 the model emitted ~40 characters to
  persist 107 KB. The extra tool calls (`list` + `save`) are trivially small.
- **Disk:** each recorded output is written once (offload) and copied once on save (local disk, ~100s
  of KB). `_toolcalls/` is retention-eligible.
- **Memory:** outputs are streamed to disk, not held; bounded by the SDK's 64 MB ACP stream limit per
  message.
- **Honest caveat — input context is unchanged.** Because kiro-cli owns the model loop and Genesis only
  *observes* ACP, the model still *receives* each tool result once in its own context (Spike 2's turn
  handled ~320 KB across three calls comfortably). We eliminate the **output** re-emission — which **is**
  the timeout bug. Trimming the model's *input* context would require an MCP gateway (Family 2, §9);
  out of scope and unnecessary for this bug.

---

## 7. Prior art / standards alignment

Our approach is the mainstream **"offload large tool outputs to a filesystem"** pattern, adapted to an
ACP-observer architecture:
- **LangChain Deep Agents SDK:** *"We offload large tool responses to the filesystem whenever they
  occur … substitutes it with a file path reference and a preview."* (auto, size-threshold.)
- **TrueFoundry Agent Harness:** automatic tool-response offloading to a sandbox on thresholds.
- **Anthropic "Code execution with MCP" (Nov 2025) + Cloudflare "Code Mode":** intermediate tool
  results stay in the execution environment and *"never enter the model's context"* — the same
  principle (keep bulk out of the model), via a different (code-sandbox) mechanism.
- **MCP spec (2025-06):** `ResourceLink` + `structuredContent` + download URLs — the **server-side**
  by-reference option (needs the tool server to cooperate; we don't own Atlas).
- **Anthropic on Claude Code (a CLI agent, our closest analog):** it *"has direct filesystem access …
  downloads and processes with pandas locally"* rather than widgets — i.e. for **CLI agents the
  filesystem/blackboard is the right offloading medium**, exactly what we do.

**Where we sit:** harness-side filesystem offloading (the dominant pattern), with the twist that Genesis
*observes* the loop rather than *owning* it — so we solve the output/timeout side (our bug), and the
gateway/`ResourceLink` route is the deferred way to also trim input context.

---

## 8. ADR alignment

- **ADR-001** — control flow unchanged; the agent drives, LangGraph orchestrates.
- **ADR-002/004/020** — per-node MCP injection; the blackboard server is just another per-node injected
  server (Genesis-owned); no global `mcp.json`.
- **ADR-010/018/022** — this is the *fix*: bulk lives in the blackboard, state/chat carry only pointers.
- **ADR-011** — the reliability trio is unchanged; `v_fetch` still validates the saved artifact.
- **ADR-024** — async-first; recording runs in the existing async `on_message` path.
- **ADR-005/029** — the blackboard server is platform-provided, orthogonal to the curated/custom
  registry tiers; effective tool trust still honored (with the blackboard tools auto-added).

---

## 9. Alternatives considered & rejected

1. **Program node calling the MCP tool directly.** Rejected — the step needs agent intelligence to
   navigate/choose the app (domain-owner constraint).
2. **Capture from `ToolCallUpdate.content`.** Rejected — Spike 1 proved MCP results arrive in
   `rawOutput`, not `content`; `content` is `None`. (Folded into the SDK change instead.)
3. **Genesis argument-matching (`app_name == inputs.app`).** Works for erd but **not general** — a
   common module can't assume Genesis holds the identifier. Demoted to the optional auto-capture mode.
4. **A blackboard *server* that reads another server's result from Genesis memory.** Impossible — MCP
   servers are kiro-cli children, isolated from Genesis. Resolved by coordinating through the shared
   run dir (the server copies from the on-disk store Genesis writes).
5. **MCP gateway/proxy returning `ResourceLink`s (Family 2).** The fuller-fidelity standard that also
   trims *input* context — **deferred, not wrong.** Larger moving part (multiplex initialize/tools/
   call/notifications, secret resolution); unnecessary for an output-side timeout. Kept as the future
   upgrade if input-context cost ever matters.
6. **"last-wins" capture by tool name.** Rejected — ambiguous under multi-app navigation / parallel
   calls (the agent literally called tools in parallel in Spike 1).

---

## 10. `erd-generation` changes (exact)

### 10.1 `graph.py` — `fetch_schema` node
```python
# BEFORE
fetch = kiro_node(name="fetch_schema", prompt_fn=fetch_prompt,
                  output_doc="raw_schema.json", mcp=["appian-atlas"])

# AFTER — opt into the blackboard tool-output store
fetch = kiro_node(name="fetch_schema", prompt_fn=fetch_prompt,
                  output_doc="raw_schema.json", mcp=["appian-atlas"],
                  blackboard=True)
```

### 10.2 `graph.py` — `fetch_prompt` (navigation + save-by-reference; no verbatim dump)
```python
def fetch_prompt(state, ctx: PlatformContext, out_path: str) -> str:
    app = state["inputs"]["app"]
    scope = state["inputs"].get("scope", "business")
    classification = ', classification="business"' if scope == "business" else ""
    vmsg = state.get("_validation", {}).get("v_fetch", {}).get("message", "")
    return (
        f'Fetch the database schema for the Appian application "{app}". You have MCP tools to '
        f'explore applications, plus a blackboard tool-output store.\n'
        f'IMPORTANT: never paste tool output into your reply — save it BY REFERENCE.\n'
        f'1. Identify the app and call get_app_schema(app_name="{app}"{classification}).\n'
        f'2. Call get_schema_relationships(app_name="{app}").\n'
        f'3. Call list_tool_outputs() to see the captured outputs (each has a "ref" + its input args).\n'
        f'4. Find the get_app_schema output for "{app}" and call '
        f'save_tool_output(ref=<that ref>, document="raw_schema.json").\n'
        f'5. Find the get_schema_relationships output for "{app}" and call '
        f'save_tool_output(ref=<that ref>, document="raw_relationships.json").\n'
        f'6. Reply only DONE.\n'
        f'previous_validation_feedback={vmsg}'
    )
```
- The `out_path` arg stays in the signature (kiro_node pre-creates `raw_schema.json`); the agent writes
  it via `save_tool_output(document="raw_schema.json")`, which the blackboard server resolves under the
  same `RunWorkspace.root`.
- **Validator `check_fetch` is unchanged** — the saved docs are the raw tool JSON, so `raw_schema.json`
  json-loads to a non-empty dict and `raw_relationships.json` is valid JSON. ✅
- The reliability trio wrapping (`attach_reliability`, `retry_max=2`, `on_exhaust_gate="escalate"`) is
  unchanged; on retry, `previous_validation_feedback` is threaded to the prompt.

### 10.3 `workflow.yaml`
- **No change to `required_mcp`** (stays `[appian-atlas]`) — the blackboard server is platform-injected,
  not a workflow MCP dependency, so it must NOT be added to the registry or `required_mcp` (the contract
  parity lint and CI registry check stay green).
- **No change to the `graph:` viz topology** — node ids/kinds unchanged.

### 10.4 Tests (`workflows/erd-generation/tests/`)
- Update/extend the graph test to drive a **stubbed agent** (via `set_collect_impl` /
  `set_streaming_impl`) that emits: three `get_app_schema`-style completed updates (alpha/beta/target)
  plus the target `get_schema_relationships`, then `save_tool_output(<target refs>, …)` calls → assert
  `raw_schema.json` + `raw_relationships.json` land with the **target** payloads and `v_fetch` passes,
  **without** the stub emitting file-write bytes. Reuse the pure-function tests unchanged.

---

## 11. `genesis-workflows` docs to update (exact)

1. **`steering/04-mcp-and-cli-usage.md`** — add a section **"Large tool outputs — the session store &
   save-by-reference"**:
   > When an agent must persist a **large** tool result (schemas, exports, transcripts), do **not** ask
   > it to write the bytes to a file — regenerating that many output tokens can exceed `turn_timeout`.
   > Instead set `blackboard=True` on the node. Genesis records **every** tool result of the session to
   > a per-run store and gives the agent two tools: `list_tool_outputs()` (metadata) and
   > `save_tool_output(ref, document)` (saves a captured output to a blackboard doc **by reference** —
   > no bytes through the model). Prompt the agent to fetch, `list_tool_outputs()`, then
   > `save_tool_output` the right refs. See `erd-generation/fetch_schema`.
   ```python
   fetch = kiro_node(name="fetch_schema", prompt_fn=_p, output_doc="raw_schema.json",
                     mcp=["appian-atlas"], blackboard=True)
   ```
2. **`steering/03-state-and-blackboard-rules.md`** — reinforce ADR-010/018: add a note that **bulk tool
   outputs must be persisted via the tool-output store / `save_tool_output`, never re-typed by the
   agent or inlined into state/chat**, with a one-line pointer to `blackboard=True`.
3. **`README.md`** (repo root) — under "Author a workflow" / capabilities, add a bullet:
   *"Agent nodes that fetch large data can opt into the **blackboard tool-output store**
   (`kiro_node(blackboard=True)`) to save results by reference — see `steering/04`."*
4. **`workflows/erd-generation/`** — add a short `README.md` documenting the fetch step's new
   list/save-by-reference behavior and why (the timeout fix), so the reference workflow teaches the
   pattern. *(Currently erd has no README; this creates one.)*
5. **`MIGRATION.md`** — if it references the erd fetch behavior, note the switch from verbatim-dump to
   save-by-reference (traceability).

---

## 12. Files touched & release order

| Repo | Change |
|------|--------|
| `kiro-agent-sdk` | `ToolCall/ToolCallUpdate`: `name`, `raw_input`, `output`; `extract_tool_output` helper. Tests. **Release minor (→ v0.2.0).** |
| `genesis-core` | `nodes/tool_store.py` (store format + recorder); `mcp/blackboard_server.py`; `kiro_node(blackboard=…)` injection + trust + recording + events + telemetry; bump SDK pin. Tests. **Release minor** (`CORE_MAJOR` stays 1 — additive). |
| `genesis-workflows` | `erd-generation`: `fetch_schema` `blackboard=True` + `fetch_prompt` rewrite + tests; docs (§11); bump genesis-core pin; re-publish (7-gate CI). |
| `genesis` | none required; optional genesis-core pin bump + release so `genesis serve` runs the new core. |

**Release order:** `kiro-agent-sdk` → `genesis-core` → `genesis-workflows` (→ optional `genesis`).

---

## 13. Testing / Definition of Done

- **SDK:** `name`/`raw_input`/`output` parsed from the Spike-1 payload shapes; `extract_tool_output`
  handles `rawOutput.items[].Json.content[].text`, plain `content`, and fallback; snake/Pascal variants.
- **genesis-core (store):** recorder writes `index.json` + `<ref>.out` atomically from stubbed
  completed updates; blackboard tools are **not** recorded; refs are stable/sequential.
- **genesis-core (blackboard server):** `list_tool_outputs` returns the index; `save_tool_output`
  copies `<ref>.out` → doc (with retry) and rejects path escapes; `read_tool_output` truncates;
  MCP handshake works (reuse the introspect harness).
- **genesis-core (integration — the multi-app case):** stub a session that records alpha/beta/gamma then
  `save_tool_output(<gamma ref>, "raw_schema.json")` → assert the file holds **gamma**, full bytes, and
  the stub emitted no bulk in its messages. (This is the Spike-2 assertion set, promoted to a test.)
- **genesis-workflows:** the erd graph test in §10.4; `ci/validate_library.py` (7 gates) green;
  contract parity + reliability lint green.
- **All suites green:** genesis-core pytest+ruff, sdk pytest, workflows pytest + validate_library, and
  (if genesis is released) genesis pytest+ruff + web gates.
- **Manual acceptance (documented, not headless-runnable):** a live `genesis serve` erd run (Docker up)
  shows `fetch_schema` completing in one short turn, `raw_schema.json`/`raw_relationships.json` saved by
  reference, **no `turn_timeout`**, `v_fetch` pass. Capture the run id + `artifact.saved` events.
- **Docs:** tracker §6 + `progress/phase-09-…` written; the §11 workflow docs updated.

---

## 14. Delivery sequencing

0. **Spikes — DONE** (§2): ACP payload shape confirmed; full loop passed.
1. **kiro-agent-sdk** — add `name`/`raw_input`/`output` + `extract_tool_output` + tests; tag v0.2.0.
2. **genesis-core** — store recorder + blackboard server + `kiro_node(blackboard=True)` + trust/events/
   telemetry + tests; bump SDK pin; tag minor.
3. **genesis-workflows** — adopt in `erd-generation` (node + prompt + tests) + docs (§11); bump core
   pin; re-publish.
4. **(optional) genesis** — bump core pin + release so the running server uses the new core.
5. **Manual acceptance** on a live erd run; record evidence; update tracker/progress.

The optional auto-capture mode, authoring `write_document`, and the MCP gateway are **not** in this
sequence (deferred, §5/§9).

---

## 15. Risks & mitigations

| Risk | Sev | Mitigation |
|---|---|---|
| Cross-process race (server reads `<ref>.out` before it's flushed) | Med | Atomic writes + bounded retry in the server (spike-proven); ACP delivers the completed update before the model decides to `save`. |
| `rawOutput` wrapping differs for the real Atlas tool vs the echo stub | Med | `extract_tool_output` is shape-tolerant (walks for text nodes); **confirm against one real Atlas call** during manual acceptance. |
| Agent under-uses `list`/`save` or picks the wrong ref | Med | Clear tool descriptions + explicit stepwise prompt; `list_tool_outputs` shows `input` args so selection is unambiguous; `v_fetch` + retry catches a wrong/missing save and re-prompts with feedback. |
| Tool-name / trust string format for `--trust-tools` (namespaced MCP tools) | Low | erd uses trust-all (no allowlist); verify the namespaced format when a node first uses an allowlist + blackboard. |
| New event kinds unrendered in the web UI | Low | Additive/observability only; UI rendering is optional follow-up; transcript folds only `agent.*`. |
| Disk growth from recording every output | Low | Local disk, retention-eligible `_toolcalls/`; add `capture_min_bytes`/cap later if needed. |

---

## 16. Open questions

- Do we expose `read_tool_output` (preview) in v1, or add it only if agents need to disambiguate by
  content? (Lean: include it — cheap, helps selection.)
- Should recording be unconditional for all agent nodes, or gated behind `blackboard=True`? (Lean:
  record always for agent nodes; inject *tools* only when `blackboard=True`.)
- `_toolcalls/` retention policy — reclaim immediately post-run, or with the standard retention window?

---

## 17. Non-goals / deferred (explicit)
Automatic/threshold capture; argument-matched capture; `write_document` authoring tools; the MCP
gateway (input-context trimming / `ResourceLink`); any auth/multi-tenancy; web UI rendering of the new
events; changes to the reliability trio, data plane, or platform API.
