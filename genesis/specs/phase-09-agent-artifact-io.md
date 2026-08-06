# Phase 9 — Agent Artifact I/O: Session Tool-Output Store & Save-by-Reference

**Status:** ✅ SHIPPED (kiro-agent-sdk v0.2.0 + genesis-core v0.6.0 + genesis v0.17.0 + genesis-workflows v0.4.0).
Design validated by spike (2026-07-13).
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
- **Injection & default (IMPORTANT — this is a *standard, always-available* capability):** the
  blackboard tools are injected for **every agent node by default** (`blackboard=True` is the default;
  set `blackboard=False` to opt out). `kiro_node` prepends the blackboard server to the ACP
  `mcp_servers` list (alongside the node's real servers), shaped exactly like `McpRegistry.acp_servers`
  entries: `{"name":"blackboard","command":sys.executable,
  "args":["-m","genesis_core.mcp.blackboard_server","--root",str(ctx.workspace.root)],"env":[]}`.
  Rationale: the whole point is that **any agent, in any workflow, can save any tool output to any
  document at any time** — that only holds if the tools are present without the author remembering to
  enable them. The cost is one lean stdio subprocess per agent node (pure-Python, fast start); acceptable
  for a local single-user app, and opt-out is available for nodes that make no tool calls.
- **Trust:** `kiro_node` auto-adds the blackboard tool names to the effective trust set —
  `node.tools ∩ server.allowlist ∪ {list_tool_outputs, save_tool_output, read_tool_output}` — or keeps
  `trust_all_tools=True` when the node has no allowlist. (The spike ran `trust_all_tools=True`; both
  servers' tools were callable with no permission stall.)
- **Recording is always on for an agent node** (it's cheap and generically useful) whenever the store
  exists; the tools are what let the agent *act* on it. With the default above, both are present for
  every agent node.
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

### 4.7 Storage location & lifecycle (where it lives; purge/retention)
- **Location — the per-run blackboard, not the DB:**
  `<artifacts_root>/<workflow_id>/<run_id>/_toolcalls/` (`index.json` + `call_<n>.out`), where
  `artifacts_root = $GENESIS_ARTIFACTS_DIR or ~/Genesis/runs` (`default_artifacts_root`, ADR-022) — the
  same tree as the workflow's real artifacts. **Not** under `~/.genesis/` (DB + config) and **not** in
  SQLite: bulk stays on the filesystem per ADR-010/018. Only the small metadata events
  (`tool_output.recorded`, `artifact.saved`) are written to the durable event log — the DB does not
  bloat.
- **During the run:** the store must persist — the agent may `list`/`save` at any point in its turn,
  and on retry/resume a fresh agent turn simply re-records with new refs (stale entries are harmless).
- **After terminal — it's scratch and should be reclaimed:** the deliverables the agent saved (e.g.
  `raw_schema.json`) live alongside and are what downstream/users need; `_toolcalls/` is redundant and
  can be **large** (it captures *every* tool output, including exploratory calls the agent didn't save).
  Two layers:
  1. **Baseline (no new mechanism):** `_toolcalls/` lives inside the run's blackboard dir, so the
     existing spec-04 `RetentionService` (`genesis/config/retention.py`, keep-last / max-age) already
     reclaims it together with the run's blackboard. Covered by default.
  2. **Recommended addition:** eagerly purge `_toolcalls/` at run finalization (via the `_finalize`
     terminal chokepoint in `runs/manager.py`), keeping the named artifacts. It has no post-run
     execution purpose, so dropping it immediately bounds disk regardless of the retention window.
     Gate behind a setting (`purge_tool_store_on_final`, default **True**) so a debugging session can
     retain it. This also removes the redundancy where a saved output exists both as `<ref>.out` and as
     the named doc.
- **Not a `genesis` platform change beyond the optional purge hook:** the store lives in genesis-core's
  `RunWorkspace`; the eager-purge hook (if adopted) is a few lines in the platform's existing
  `_finalize` path + one setting — small, and the baseline retention path needs nothing.

---

## 5. Persistence modes

### 5.0 A standard, always-available capability (convention for ALL workflows)
This is **not** an erd-specific feature. Once shipped, **every agent node** (by default, §4.4) has the
tool-output store and its tools available: the agent can call `list_tool_outputs()` to see everything it
has fetched this session and `save_tool_output(ref, document)` to persist **any** tool output to **any**
blackboard document **at any point in its turn** — without ever retyping the bytes. Workflow authors get
this for free and should treat it as the default way an agent moves large tool results into the
blackboard. The authoring guides (§11) document it as a first-class convention so future workflows use
it consistently instead of asking agents to re-emit bulk (which risks `turn_timeout` and violates
ADR-010/018).

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

# AFTER — the blackboard tool-output store is default-on for agent nodes (§4.4);
# no node change is strictly required. The prompt (10.2) drives the save-by-reference.
fetch = kiro_node(name="fetch_schema", prompt_fn=fetch_prompt,
                  output_doc="raw_schema.json", mcp=["appian-atlas"])
# (blackboard=True is the default; pass blackboard=False only to opt a node out.)
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

> **Framing (per the "make this a common thing" requirement):** these updates must present the store +
> `save_tool_output` as a **standard, always-available capability for every agent node**, not an
> erd-specific trick. The message future authors must absorb: *"An agent can save any tool output to any
> document at any time via `save_tool_output` — never make an agent retype bulk."*

1. **`steering/01-authoring-overview.md`** — add the capability to the overview so it's seen first:
   a short "Agent nodes can persist large tool results to the blackboard by reference (the tool-output
   store) — it's on by default; see `steering/04`." bullet.
2. **`steering/02-node-taxonomy-and-reliability.md`** — in the **agent node** description, state that
   every agent node gets `list_tool_outputs()` + `save_tool_output(ref, document)` by default, and that
   this is the standard way to move bulk tool output into the blackboard (contrast with re-typing,
   which is forbidden).
3. **`steering/04-mcp-and-cli-usage.md`** — the primary reference section **"Large tool outputs — the
   session store & save-by-reference"** (the full how-to + code, as previously specified), explicitly
   noting it's default-on and available in any agent node.
4. **`steering/03-state-and-blackboard-rules.md`** — reinforce ADR-010/018: **bulk tool outputs must be
   persisted via the store / `save_tool_output`, never re-typed by the agent or inlined into
   state/chat**, with a pointer to §04.
5. **`README.md`** (repo root) — capabilities bullet: *"Every agent node can save tool results to the
   blackboard by reference via the built-in tool-output store — see `steering/04`."*
6. **`workflows/erd-generation/README.md`** (new) — document the fetch step's list/save-by-reference
   behavior as the reference example of the convention.
7. **`MIGRATION.md`** — note the erd switch from verbatim-dump to save-by-reference (traceability).

**Also in the tracker (design docs):** `reference/workflow-authoring-standard.md` and
`reference/node-taxonomy-reference.md` gain the same convention (agent nodes have the tool-output store
by default; save-by-reference is the standard bulk path) so the canonical standard reflects it. Applied
when Phase 9 ships (so the standard tracks reality).

---

## 12. Files touched & release order

| Repo | Change |
|------|--------|
| `kiro-agent-sdk` | `ToolCall/ToolCallUpdate`: `name`, `raw_input`, `output`; `extract_tool_output` helper. Tests. **Release minor (→ v0.2.0).** |
| `genesis-core` | `nodes/tool_store.py` (store format + recorder); `mcp/blackboard_server.py`; `kiro_node` **default-on** blackboard injection (`blackboard=True` default + opt-out) + trust + recording + events + telemetry; bump SDK pin. Tests. **Release minor** (`CORE_MAJOR` stays 1 — additive). |
| `genesis-workflows` | `erd-generation`: `fetch_prompt` rewrite (node needs no change — default-on) + tests; docs (§11: steering 01/02/03/04 + README + erd README + MIGRATION); bump genesis-core pin; re-publish (7-gate CI). |
| `genesis` | none required for the core mechanism (retention already reclaims `_toolcalls/`). **Optional:** the eager-purge-at-finalization hook + `purge_tool_store_on_final` setting (§4.7) — a few lines in `runs/manager.py._finalize` + `runtime/settings.py`; and an optional genesis-core pin bump + release so `genesis serve` runs the new core. |

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
- **Resolved:** the blackboard tools are **on by default for every agent node** (opt-out via
  `blackboard=False`), so the capability is universally available (§4.4/§5.0). Remaining sub-question:
  is the per-node subprocess cost ever high enough to warrant a shared/session-level server instead of
  per-node? (Lean: per-node for now; revisit if startup latency shows up.)
- **Resolved (§4.7):** `_toolcalls/` is reclaimed by the existing retention service as a baseline, plus
  a recommended eager purge at run finalization (`purge_tool_store_on_final`, default True). Remaining
  sub-question: purge eagerly always, or keep for a short debug window when a run failed? (Lean: purge
  on success; retain on failure to aid diagnosis — a cheap refinement.)

---

## 17. Non-goals / deferred (explicit)
Automatic/threshold capture; argument-matched capture; `write_document` authoring tools; the MCP
gateway (input-context trimming / `ResourceLink`); any auth/multi-tenancy; web UI rendering of the new
events; changes to the reliability trio, data plane, or platform API.
