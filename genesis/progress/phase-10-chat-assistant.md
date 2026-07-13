# Phase 10 — Chat assistant: as-built progress

**Status:** ✅ SHIPPED (2026-07-13). Release chain: **kiro-agent-sdk v0.3.0 → genesis-core v0.7.0 →
genesis v0.19.0**. CI green: genesis-core `#6335360`, genesis `#6335364` (sdk has no CI).
Spec: `specs/phase-10-chat-assistant.md` + `phase-10-chat-assistant/10-01..10-07`. ADR: **ADR-031**.

## What shipped (per sub-phase)

**10-01 — SDK read-only permission policy (kiro-agent-sdk v0.3.0).**
`KiroAgentOptions.permission_mode` (`auto_approve` default | `auto_deny`) + `allow_fs_write`
(default True). `auto_deny` selects a `reject`/`deny` permission option (else `{"outcome":"cancelled"}`);
`allow_fs_write=False` refuses `fs/write_text_file` (`-32000`) and advertises
`clientCapabilities.fs.writeTextFile=false`. Defaults unchanged. 7 unit tests (`test_permission_policy.py`);
55 SDK tests pass, ruff clean.

**10-01 SPIKE (load-bearing gate) — PASSED vs real kiro-cli 2.12.1.** With a stub MCP server exposing a
trusted read tool + an untrusted mutate tool (each dropping an execution marker):
- Trusted read tool auto-ran; untrusted mutate tool was **auto-denied (never executed)**; fs write was
  refused (both the native `write` tool via permission AND the `fs/write_text_file` capability);
  multi-turn context persisted across `prompt()` calls.
- **Critical finding:** kiro-cli matches `--trust-tools` for MCP tools by the **namespaced** name
  `@<server>/<tool>` — bare/other forms are NOT trusted. The chat trust set is therefore built as
  `@appian-atlas/<tool>` + `@genesis/<tool>`. Permission options confirmed:
  `allow_once`/`allow_always`/`reject_once` (the deny path matches `kind.startswith("reject")`).

**10-02 — Genesis-introspection MCP server (genesis).** `genesis/mcp/introspection_server.py`: stdlib
stdio JSON-RPC, launched `<python> -m genesis.mcp.introspection_server --db … --library … --lockfile …`.
Read-only: opens `genesis.db` via a `mode=ro` connection (`_RoDatabase`); reuses `RunStore`/`EventLog` +
the extracted `fold_steps`. Tools: `list_runs`, `get_run`, `get_run_steps`, `get_run_events`,
`list_failures`, `list_workflows`, `get_workflow`, `integration_health`, `platform_stats`. Secret-looking
input keys redacted; payloads capped at 32 KB. Extracted `RunManager.steps()` fold → `runs/steps.py`
(shared, no behavior change). 9 tests incl. an assertion the ro connection refuses INSERT.

**10-03 — Chat persistence (genesis).** Migration `m0002_chat` (`chat_sessions` + `chat_messages`, FK
`ON DELETE CASCADE`) registered as version 2. `chat/store.py` `ChatStore`/`ChatMessageStore` (Database-
injected, recency-ordered list with `message_count`, cascade delete). 5 tests; `test_db.py` updated for
two migrations.

**10-04 — ChatManager (genesis).** `chat/events.py` (`map_message_to_events` mirrors
`kiro_node._emit_message`). `chat/mcp.py` (`build_chat_mcp` → `(servers, trust)`; Atlas best-effort,
introspection always; trust in `@server/tool` form). `chat/manager.py` `ChatManager`/`ChatSession`:
persistent `KiroACPClient` (in-process, ADR-031), read-only options
(`trust_all_tools=False` + `@server/tool` allowlist + `permission_mode="auto_deny"` +
`allow_fs_write=False`), per-turn streaming with monotonic `seq`, persists user + assistant (+ folded
thoughts/tools), auto-title, one-turn lock (`is_busy`), cancel/`aclose_all`/idle-reaper, cold-start
transcript preamble, and a steering preamble (secondary reinforcement). `set_client_factory` test seam;
`chat_*` settings. 5 tests (fake client).

**10-05 — Chat API + SSE (genesis).** `api/chat.py` `register_chat_routes`: GET/POST/GET/PATCH/DELETE
`/api/chat/sessions[/{id}]`, POST `/messages` → `EventSourceResponse` (named events, closes on
`agent.result`/`error`), POST `/cancel`. 400 empty/oversized, 409 busy, 404 unknown. Wired into
`create_app` (ChatManager + shutdown `aclose_all`; FastAPI version 0.19.0). 4 tests (TestClient stream).

**10-06 — Web Chat page (genesis/web).** `types/chat.ts`; `lib/api/chat.ts` (`chatApi` + `readSse`
SSE-over-fetch reader — EventSource can't POST); `qk.chat` keys; `features/chat/` (conversation adapters,
hooks incl. streaming `useChatTurn`, `Composer`, `ChatThread` reusing the run-detail
`buildTranscript`+`Conversation` renderer, `SessionList` with rename/`ConfirmDialog` delete, `ChatPage`);
`/chat` + `/chat/:sessionId` routes; Sidebar **Chat** nav; `MessagesSquare`/`ArrowUp` icons. 5 tests
(readSse parser, adapter, SessionList delete-confirm, ChatThread render, jest-axe). 73 web tests, 0 lint
errors, tsc clean, `web/static` rebuilt + committed (stale-bundle guard passes).

**10-07 — ADR + steering + integration + release.** ADR-031 in `reference/decision-log.md`; steering
preamble in `ChatSession`; release chain shipped; this doc + tracker.

## Live acceptance (real kiro-cli 2.12.1, end-to-end)
Ran `ChatManager` with the **real** client factory + the introspection server against a temp
`genesis.db` seeded with a done run + a failed run (erd-generation, "Atlas MCP timed out"):
- **"How many runs do I have, and did any fail? Why?"** → agent called `platform_stats` + `list_failures`
  and answered: *"2 recent runs: 1 done, 1 failed — `r-bad1` (erd-generation), failed because Atlas MCP
  timed out,"* and volunteered that it can't restart runs (read-only).
- **"Please cancel the failed run for me."** → *"I can't cancel runs — Genesis Chat is read-only … head
  to the Runs page."* No mutation attempted.

This exercised ChatManager + real kiro-cli + the introspection subprocess (ro DB) + streaming +
persistence + auto-deny + steering. Atlas was not configured in the smoke, so Atlas tools were skipped
(introspection-only) — as designed (graceful degrade).

## Test tallies (all green at release)
kiro-agent-sdk **55** · genesis **110** (+21 for Phase 10: 9 introspection + 5 chat-store + 5 chat-manager
+ 4 chat-api; `test_db.py` updated) · genesis-core **54** · web **73** (+5 chat). ruff clean; tsc strict
clean; eslint 0 errors.

## Known follow-ups / honest caveats
- **Kiro context is per-live-subprocess**; on app restart / idle-reap the transcript **preamble** replay
  is best-effort (bounded to ~10 msgs / 4 KB), not full-fidelity recovery.
- **Cosmetic**: an `asyncio` "event loop is closed" traceback can print at interpreter teardown when a
  session's kiro-cli subprocess transport is GC'd after the loop closes (seen in the standalone smoke;
  not under the long-lived FastAPI loop). Candidate: await transport cleanup in `close()`.
- **Web**: `ChatThread` imports `buildTranscript`/`Conversation` from `features/run-detail` (interim
  feature→feature import, flagged in spec 10-06). Move to `shared/conversation/` if desired.
- **Live streaming turn** is not unit-tested over a real network (jsdom streaming is flaky); covered by
  the `readSse` parser unit test + the backend SSE tests + the live smoke.
- **Idle reaper** ships but is time-based only; **LLM-generated titles** and **transcript summarization**
  for very long sessions are deferred. Opening the MCP set beyond Atlas needs a read/write tool
  classification story (deferred).

## Post-ship user steps
Restart `genesis serve` to pick up the v0.19.0 bundle (and to apply migration m0002). Configure the
`appian-atlas` MCP (token + a read `tool_allowlist`) for document Q&A; Genesis-introspection chat works
without it. Chat is read-only by design.
