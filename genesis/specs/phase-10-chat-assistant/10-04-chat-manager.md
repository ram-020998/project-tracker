# 10-04 — ChatManager: sessions, MCP wiring, streaming, safety

**Repo:** `genesis` · **Ships with:** v0.19.0 · **Depends on:** 10-01, 10-02, 10-03 · **Blocks:** 10-05
**The heart of the phase.** An async, in-process manager that owns persistent read-only Kiro chat
sessions, streams turns, and persists transcripts.

## 1. Objective

Provide `ChatManager` (a sibling to `RunManager`) that: creates/lists/renames/deletes sessions;
holds one persistent `KiroACPClient` per live session wired with the Atlas + introspection MCP
servers under read-only options; runs a user turn as a stream of canonical `agent.*` events;
persists the user prompt + assistant answer; and cleans up.

## 2. Current state (verified)

- SDK persistent path (10-01): `KiroACPClient(options)` → `await start()` (once) →
  `async for m in client.prompt(text)` (per turn) → `await client.close()`. Messages:
  `SystemInit`, `AgentMessageChunk(text)`, `AgentThoughtChunk(text)`, `ToolCall(tool_call_id, title,
  kind, status, name, raw_input)`, `ToolCallUpdate(tool_call_id, status, name, output, ...)`,
  `ResultMessage(stop_reason, result, error)`. `collect*/query` are single-shot — **not** used here.
- `genesis-core kiro_node._emit_message(ctx, node, m)` maps those message types → canonical event
  dicts `agent.message/thought/tool_call/tool_update` (+ the node emits `agent.result`). **Copy this
  mapping** into a small pure `chat/events.py` (duck-typed on class name, no hard SDK import) so chat
  emits identical shapes.
- MCP wiring: `McpRegistry.from_layers(curated, custom, secrets=, environments=)` then
  `acp_servers(["appian-atlas"])` → ACP entries with `${VAR}` resolved; `allowlist("appian-atlas")`
  → the read tool list. The curated registry file is the installed library's `mcp-registry.json`;
  the custom tier is `CustomMcpStore` (`~/.genesis/mcp-custom.json`). `ConfigService` already builds
  the merged registry — reuse it (see `config/service.py`) rather than re-wiring layers.
- `EventBus` (`runs/events.py`) — per-stream history + subscribers, `publish`, `close` (sentinel);
  reuse verbatim for the per-turn live stream.
- Stub seam precedent: `kiro_node.set_collect_impl(...)` lets tests inject a fake. Provide the same
  for chat: a `set_client_factory(...)` hook so tests inject a fake `KiroACPClient`.

## 3. Read-only options assembly (ADR-031 §3, uses 10-01)

```python
opts = KiroAgentOptions(
    cwd=<a scratch dir or the state dir>,
    mcp_servers=atlas_servers + [introspection_server_entry],
    trust_all_tools=False,
    trust_tools=sorted(atlas_read_allowlist | introspection_tool_names),
    permission_mode="auto_deny",      # 10-01
    allow_fs_write=False,             # 10-01
    model=<optional chat model>,
    turn_timeout=<e.g. 300>,
    startup_timeout=<e.g. 120>,
)
```

- `atlas_read_allowlist = set(registry.allowlist("appian-atlas") or [])`. If Atlas has no allowlist
  configured, fall back to introspecting it once (ADR-029 direct-stdio introspect) or to a curated
  static read list — **but never `trust_all_tools=True`** (that would defeat read-only). Document
  that Atlas must declare a read allowlist in the curated registry for chat to trust its tools.
- `introspection_tool_names` = the fixed set from 10-02 (`list_runs`, `get_run`, …).
- If Atlas secrets are unresolved, `acp_servers` raises fail-fast → surface as a friendly chat error
  ("Atlas isn't configured — set its token in Settings").

## 4. `ChatManager` / `ChatSession`

### 4.1 Construction

`ChatManager(settings, config: ConfigService)` — builds `Database`, `ChatStore`,
`ChatMessageStore`; keeps `_live: dict[session_id, ChatSession]`. Reuses `config` for the merged MCP
registry + secrets.

### 4.2 Session CRUD

- `create(title="New chat") -> ChatSessionRecord` — persists a row (id `c-<uuid12>`).
- `list()`, `get(id)` (record + messages), `rename(id, title)`, `delete(id)` — delegate to the
  stores; `delete` also `await`-closes+drops any live `ChatSession`.

### 4.3 `ChatSession` (per live session)

Holds: the `KiroACPClient` (created lazily on first message via the injectable client factory),
`asyncio.Lock` (one active turn), a `last_used` timestamp, and the current turn's `EventBus`.

- `_ensure_started()` — build read-only options (§3), `client = factory(opts)`, `await
  client.start()`. On failure, mark the session errored and raise a friendly message.
- `stream_turn(text) -> AsyncIterator[event dict]` (see 4.4).
- `cancel()` — `await client.close()` (kills the kiro-cli subprocess mid-turn); the in-flight
  `stream_turn` emits a terminal `error`/`agent.result{stop_reason:"cancelled"}` and releases the lock.
- `aclose()` — close the client, drop from `_live`.

### 4.4 Running a turn (streaming + persistence)

```
async with self.lock:                         # 409 upstream if already held
    await self._ensure_started()
    self.msgs.append(session_id, "user", text) # persist prompt; touch session
    bus = EventBus(); seq = 0
    folded = []                                 # transcript items for persistence
    answer = []                                 # assistant text chunks
    tool_calls = 0
    try:
        async for m in self.client.prompt(text):
            for ev in map_message_to_events(m):     # chat/events.py (mirrors _emit_message)
                seq += 1; ev["seq"] = seq
                bus.publish(Event(ev["type"], session_id, ev))
                folded.append(ev)
                if ev["type"] == "agent.message": answer.append(ev["text"])
                if ev["type"] == "agent.tool_call":
                    tool_calls += 1
                    if tool_calls == SOFT_TOOL_CAP: ...   # 4.5
            if isinstance(m, ResultMessage): result = m
        final = {"type": "agent.result", "seq": seq+1, "ok": result.error is None,
                 "stop_reason": result.stop_reason, "error": result.error,
                 "tool_calls": tool_calls}
        bus.publish(Event("agent.result", session_id, final))
        self.msgs.append(session_id, "assistant", "".join(answer),
                         events=[i for i in folded if i["type"] in ("agent.thought","agent.tool_call","agent.tool_update")])
    except Exception as e:
        bus.publish(Event("error", session_id, {"detail": str(e)}))
    finally:
        bus.close()
```

`ChatManager.stream_turn(session_id, text)` returns the `bus.subscribe()` generator so the API layer
(10-05) can stream it; the turn task runs concurrently (an `asyncio.Task`), or the API iterates the
prompt directly and forwards — pick the simpler wiring that keeps one active turn (the lock lives on
the session regardless). Persist the assistant message even if the client stream errors mid-way
(partial answer + error note), so history is never lost.

### 4.5 Safety caps

- `turn_timeout` bounds a turn at the SDK level (the `session/prompt` request times out → the turn
  ends with an error the user sees).
- `SOFT_TOOL_CAP` (e.g. 20): when reached, log + emit a `note` event; we cannot hard-interrupt a
  Kiro turn mid-flight, so this is advisory (the real hard stop is the user's Cancel → `client.close`).
- Input length cap (mirror ai-sre `MAX_PROMPT_LENGTH`, enforced again in the API 10-05).

### 4.6 Context continuity across cold clients (risk mitigation)

The kiro-cli conversation state lives in the subprocess, not the DB. When a turn starts and the
client is cold (app restarted, or the idle reaper closed it), `_ensure_started()` replays a
**bounded** preamble reconstructed from the persisted transcript before the user's new text —
e.g. a system-style prefix: "Earlier in this conversation: <condensed last N messages>." Cap the
replay (last ~10 messages / ~4 KB). Document this as best-effort context recovery; a fresh live
session has full fidelity.

### 4.7 Idle reaper + shutdown

An optional background task closes clients idle > `chat_idle_minutes` (setting; default e.g. 30) to
free kiro-cli subprocesses; the session row persists and restarts on next message (with §4.6
replay). On app shutdown, `aclose()` all live sessions. (v1 may ship without the reaper and rely on
app-lifetime clients + explicit delete; note it as a follow-up if descoped.)

### 4.8 Title

v1: derive the title from the first user message (trim to ~48 chars) on the first `append`; user can
rename. (A cheap LLM "summarize to a title" call is a later nicety, not v1.)

## 5. Settings additions

`genesis/runtime/settings.py`: `chat_idle_minutes` (default 30), `chat_turn_timeout` (default 300),
`chat_max_prompt_chars` (default 8000), `chat_model` (optional). Follow the existing env-parse
pattern in `Settings.load()`.

## 6. Files to touch

- `genesis/genesis/chat/manager.py` (new) — `ChatManager` + `ChatSession` + `set_client_factory`.
- `genesis/genesis/chat/events.py` (new) — `map_message_to_events(m)` (mirror
  `kiro_node._emit_message`; duck-typed, no hard SDK import).
- `genesis/genesis/chat/mcp.py` (new, optional) — build the Atlas + introspection ACP entries + the
  read-tool trust set from `ConfigService`.
- `genesis/genesis/runtime/settings.py` — the chat settings.
- `genesis/tests/test_chat_manager.py` (new) — see §7.

## 7. Tests / DoD

- Inject a **fake `KiroACPClient`** (via `set_client_factory`) that yields scripted messages
  (thought → tool_call → tool_update → message chunks → ResultMessage). Assert:
  - the turn streams canonical `agent.*` events with monotonic `seq`, ending in `agent.result`;
  - the user + assistant messages are persisted (assistant `content` = joined chunks; `events`
    holds thoughts/tools; partial answer + error persisted on mid-stream failure);
  - the client is built with read-only options (`trust_all_tools=False`, a read-only `trust_tools`
    set, `permission_mode="auto_deny"`, `allow_fs_write=False`) — assert on the captured options;
  - one-active-turn lock (a concurrent `stream_turn` raises/queues per design);
  - `cancel()` closes the client and terminates the stream;
  - cold-client preamble replay includes prior transcript (bounded).
- No real kiro-cli in unit tests (the fake seam). pytest + ruff green.

## 8. Risks

- **In-process blocking:** the SDK is async and non-blocking (asyncio subprocess); ensure no sync
  DB call blocks the loop for long (SQLite writes are quick; use short txns). If needed, offload
  store writes with `asyncio.to_thread`.
- **Client leak:** ensure `aclose()`/`cancel()` always run (finally blocks); the reaper backstops.
- **Atlas trust gap:** if Atlas ships no read allowlist, chat can't safely trust it → document the
  requirement + fail closed (introspection-only) rather than trusting all.
