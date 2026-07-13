# Phase 10 — Chat: a read-only conversational assistant (umbrella spec)

**Status:** ✅ SHIPPED (2026-07-13) — sdk v0.3.0, genesis-core v0.7.0, genesis v0.19.0. See `progress/phase-10-chat-assistant.md`.
**Owns:** a new **Chat** page in the Genesis workbench + the backend to power it.
**Sub-phase docs:** `specs/phase-10-chat-assistant/10-01 … 10-07` (one per sub-phase).
**ADR:** ADR-031 (read-only assistant boundary) — text in §3 here; to be appended to
`reference/decision-log.md` on approval.
**Author's note:** every "current state" citation below was verified against the real code
(genesis @ v0.18.0, genesis-core @ v0.6.0, kiro-agent-sdk @ v0.2.0) while writing this plan.

---

## 0. Objective

Add a **Chat** page: a ChatGPT-style, multi-turn conversation with Kiro, embedded in the
Genesis SPA. It is a **read-only assistant** with two blended capabilities in one conversation:

1. **Talk to Kiro with MCP access** — ask anything; the agent may call the **`appian-atlas`**
   MCP (read tools only) to ground its answers in Appian documents/data.
2. **Talk to Genesis** — ask about the platform's own state: recent runs, what failed and why,
   a run's progress, installed workflows, integration health — served by a new read-only
   **Genesis-introspection MCP server**.

Inspiration: the internal `appian/prod/ai-sre` app (a Next.js streaming chat over a LangGraph
agent; `agents/universal_agent/agent.py` pools tools + caps a turn with
`tool_call_limit`/`model_call_limit`; `frontend/src/app/api/chat/stream/route.ts` streams SSE
JSON for a `{prompt, session_id}` request). We reuse the interaction model, not the code
(ai-sre is AWS-AgentCore/Bedrock hosted; Genesis is local + Kiro-over-ACP).

## 1. Confirmed product scope (locked with the owner)

| # | Decision |
|---|---|
| 1 | **MCP set = `appian-atlas` only** (read tools), for now. Not "all MCPs" — that keeps the read-only story tractable. |
| 2 | **Sessions are persisted** and the user can **delete** (and rename) them. |
| 3 | **Full Genesis data access** — runs, events, status, failures, progress, workflows/catalog, integration health, config cards (secret-**redacted**). |
| 4 | **Single blended chat** — Atlas + Genesis-introspection tools live together in one session; no mode toggle. |
| 5 | **Single-user, local only** (ADR-026 stands). No auth / multi-tenancy. |

## 2. Non-negotiables that shape the design (existing ADRs)

- **ADR-001** — agents never orchestrate. Chat must not become an LLM orchestrator (that is
  exactly how the retired solutions-copilot failed). → ADR-031 draws the boundary (§3).
- **ADR-002/004/020** — narrow Kiro turns over ACP, **per-node/per-session MCP injection**, no
  global Kiro `mcp.json`. Chat injects only Atlas + the introspection server.
- **ADR-005/029** — MCP registry is two-tier (curated read-only + custom writable); effective
  trust is capped by the server allowlist. Chat trusts only the read allowlist.
- **ADR-010/018/022** — bulk data never inlines in state/chat; it lives in files. Chat tool
  outputs that are large stay bounded (the introspection server returns bounded JSON).
- **ADR-012** — workflow graphs run in disposable subprocess workers; the app never imports
  workflow Python. **Chat imports no workflow Python** (it runs no graph), and the agent is
  already isolated as the kiro-cli subprocess the SDK spawns. → Chat runs **in-process async**
  in the app (see §4.1); this is consistent with ADR-012's rationale, and ADR-031 records it.
- **ADR-023/024** — FastAPI embeds the engine; async-first. ChatManager is async, in-process.
- **ADR-026/027/028** — React+TS SPA, design tokens + existing primitives, all endpoints under
  `/api`, SPA history fallback. Chat page + `/api/chat/*` follow suit.
- **ADR-021** — the sanctioned mutation-gate model is for *workflows*. Chat has **no** mutation
  path at all; there is nothing to gate because nothing is allowed to mutate.

## 3. ADR-031 (proposed) — Chat is a read-only conversational assistant

> **Decision.** Genesis gains a Chat surface: a persistent, multi-turn Kiro conversation with a
> curated read-only tool set. Chat is an **assistant / observability co-pilot**, not a
> controller. It **observes and answers**; it never drives or mutates anything.
>
> **Hard boundary (enforced, not merely prompted):**
> - No workflow control: cannot start / pause / resume / cancel / fork / respond-to-gate on runs.
> - No configuration mutation: cannot create/edit/delete MCP servers, CLIs, environments,
>   secrets, or install/remove workflows.
> - No filesystem writes, no terminal, no CLI execution, no deploy.
> - Tools are limited to **read** tools: the `appian-atlas` read allowlist + the read-only
>   Genesis-introspection tools.
>
> **Enforcement (defense in depth), in priority order:**
> 1. **Capability restriction** — the ACP session is launched with `trust_all_tools=False` and a
>    `trust_tools` allowlist that contains *only* read tools; no write/exec tools are trusted.
> 2. **Permission auto-deny** — the SDK is run with a new `permission_mode="auto_deny"` so any
>    tool the agent tries that is *not* pre-trusted (i.e. would trigger
>    `session/request_permission`) is denied, not auto-approved. (Default SDK behavior is
>    auto-approve; Chat flips it — 10-01.)
> 3. **No fs-write capability** — the SDK is run with `allow_fs_write=False`, which both refuses
>    `fs/write_text_file` agent requests and advertises `clientCapabilities.fs.writeTextFile=false`
>    in `initialize`.
> 4. **Read-only data sources** — the introspection MCP server opens genesis.db with a
>    **read-only** connection (`file:...?mode=ro`) and exposes only SELECT-backed tools.
> 5. **Steering / system prompt** — a chat persona that states the read-only contract (secondary
>    reinforcement only; never the sole control).
>
> **Execution model.** Chat runs **in-process** in the FastAPI app (async ChatManager holding one
> `KiroACPClient` per live session). ADR-012's subprocess isolation exists to keep *workflow
> Python* out of the app process; Chat executes no workflow code, and the agent itself is already
> isolated as the kiro-cli subprocess the SDK spawns. A bespoke chat "worker" would add
> complexity with no isolation benefit.
>
> **Scope.** Single-user, local (ADR-026). Atlas-only MCP for v1. Full read-only Genesis data.
>
> **Consequences.** ADR-001 is preserved: LangGraph still owns all *workflow* control flow; Chat
> is a parallel read surface that cannot influence it. If Chat is ever given a mutating action,
> this ADR must be revisited (it would re-open the copilot-orchestrator failure mode).

## 4. Architecture

### 4.1 Component overview

```
Browser (SPA)                         FastAPI app process (genesis serve)
┌───────────────────┐   POST msg      ┌───────────────────────────────────────────┐
│ Chat page         │ ──────────────► │ /api/chat/* routes                          │
│  session list     │   SSE (fetch    │   ↕                                         │
│  transcript       │ ◄─ reader) ──── │ ChatManager (async, in-process)             │
│  composer         │   agent.* events│   ├── ChatStore / ChatMessageStore (SQLite) │
└───────────────────┘                 │   └── per-session ChatSession               │
                                       │         ├── KiroACPClient (persistent) ─────┼──► kiro-cli acp (subprocess)
                                       │         │      trust=read-only, auto_deny    │        │  MCP stdio
                                       │         └── per-turn EventBus (live fan-out) │        ▼
                                       └───────────────────────────────────────────┘   ┌──────────────┐
                                                                                        │ appian-atlas │ (read tools)
                                                                                        │ genesis-     │ (read-only,
                                                                                        │ introspection│  own ro conn to
                                                                                        └──────────────┘  genesis.db)
```

Reused verbatim: the `agent.message/thought/tool_call/tool_update/result` canonical event shapes
(`kiro_node._emit_message`), the `EventBus` fan-out, the SSE named-event framing, and the web
`buildTranscript`/`groupTurns`/`TurnView` transcript renderer.

### 4.2 Data model (m0002 migration)

```sql
CREATE TABLE chat_sessions (
  id          TEXT PRIMARY KEY,          -- c-<uuid12>
  title       TEXT NOT NULL DEFAULT 'New chat',
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE TABLE chat_messages (
  seq         INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id  TEXT NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role        TEXT NOT NULL,             -- 'user' | 'assistant'
  content     TEXT NOT NULL,             -- final text (user prompt / assistant answer)
  events      TEXT NOT NULL DEFAULT '[]',-- JSON: the turn's folded agent.* items (thoughts/tools)
  ts          TEXT NOT NULL
);
CREATE INDEX ix_chat_messages_session ON chat_messages(session_id, seq);
```

Delete = `DELETE FROM chat_sessions WHERE id=?` (FK cascade removes messages;
`PRAGMA foreign_keys=ON` is already set by `Database`). Retention: v1 leaves sessions to explicit
user delete; a later `RetentionService` extension can prune old sessions (out of scope).

### 4.3 API surface (`/api/chat`, ADR-028)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/chat/sessions` | list sessions (id, title, timestamps, message_count) |
| POST | `/api/chat/sessions` | create `{title?}` → `{id}` |
| GET | `/api/chat/sessions/{id}` | session + full transcript (messages) |
| PATCH | `/api/chat/sessions/{id}` | rename `{title}` |
| DELETE | `/api/chat/sessions/{id}` | delete (cascade); closes any live client |
| POST | `/api/chat/sessions/{id}/messages` | `{text}` → **SSE stream** of the turn's `agent.*` events (closes on `agent.result`/`error`) |
| POST | `/api/chat/sessions/{id}/cancel` | cancel the in-flight turn |

The message POST returns the SSE stream **directly** (like ai-sre) because `EventSource` cannot
POST; the web client consumes it with `fetch` + a `ReadableStream` reader (10-06). One active turn
per session (a lock); a second concurrent POST returns `409`.

### 4.4 Event model (reuse the canonical kinds)

The turn streams the same canonical kinds the run conversation uses:
`agent.message`, `agent.thought`, `agent.tool_call`, `agent.tool_update`, `agent.result`, plus a
chat-scoped `error`. Each carries a monotonic per-turn `seq` for client-side dedupe. This lets the
web reuse `buildTranscript` + `groupTurns` unchanged.

### 4.5 Read-only enforcement — summary (full detail in 10-01)

`ChatSession` launches the ACP client with:
`trust_all_tools=False`, `trust_tools = atlas_read_allowlist ∪ introspection_tool_names`,
`permission_mode="auto_deny"`, `allow_fs_write=False`, plus the chat steering preamble.
The introspection server is read-only by construction (ro SQLite connection, SELECT-only tools).

## 5. Sub-phase index (delivery order)

| Sub-phase | Doc | Repo(s) | Summary | Depends on |
|---|---|---|---|---|
| **10-01** | `10-01-sdk-readonly-permission.md` | kiro-agent-sdk | Add `permission_mode` (`auto_approve`\|`auto_deny`) + `allow_fs_write` to `KiroAgentOptions`; **spike** read-only enforcement against real kiro-cli + Atlas. Ship **sdk v0.3.0**. | — |
| **10-02** | `10-02-genesis-introspection-mcp.md` | genesis | Read-only Genesis-introspection MCP server (`genesis/mcp/introspection_server.py`) exposing runs/events/steps/failures/workflows/health/stats over an ro genesis.db connection. | — |
| **10-03** | `10-03-chat-persistence.md` | genesis | m0002 migration (`chat_sessions`+`chat_messages`) + `ChatStore`/`ChatMessageStore` repositories. | — |
| **10-04** | `10-04-chat-manager.md` | genesis | `ChatManager` + `ChatSession`: persistent `KiroACPClient`, MCP wiring (Atlas + introspection), per-turn streaming, safety caps, title, delete, idle reaper + history replay. | 10-01, 10-02, 10-03 |
| **10-05** | `10-05-chat-api.md` | genesis | `/api/chat/*` routes + SSE turn stream; wire `ChatManager` into `create_app`. | 10-04 |
| **10-06** | `10-06-web-chat-page.md` | genesis/web | Chat nav + route, session list (new/select/rename/delete), transcript (reuse folds), composer, SSE-over-fetch hook, read-only banner. Rebuild `web/static`. | 10-05 |
| **10-07** | `10-07-adr-integration-release.md` | all | ADR-031 into decision-log; chat steering/system prompt; end-to-end wiring + live acceptance; release chain; tracker/progress. | 10-01…10-06 |

**Release chain (10-07):** kiro-agent-sdk **v0.3.0** → genesis-core **v0.7.0** (bump sdk pin;
no code change) → genesis **v0.19.0** (add a direct git+ssh dep on kiro-agent-sdk@v0.3.0 since
genesis now uses `KiroACPClient` directly, bump the core pin, ship the server + migration + chat
manager + api + web bundle). FastAPI app version → 0.19.0.

## 6. Cross-cutting: testing strategy

- **Backend (pytest):** introspection server tools over a seeded temp genesis.db (10-02); migration
  idempotency + FK-cascade delete (10-03); ChatManager with a **stubbed `KiroACPClient`** (inject a
  fake that yields scripted `AgentMessageChunk/ToolCall/ResultMessage`) to assert streaming,
  persistence, read-only options, and cancel (10-04); API route + SSE tests with the stubbed
  manager (10-05). Mirror the `set_collect_impl` stub seam already used for `kiro_node`.
- **Web (Vitest + RTL + jest-axe):** transcript renders from a scripted `agent.*` fixture via the
  reused folds; session list select/delete (ConfirmDialog); composer disabled while streaming;
  a11y (10-06). A contract fixture guards the chat event shapes (the "stub hid the contract"
  lesson).
- **Live acceptance (10-07, manual — cannot be driven headlessly):** real kiro-cli + Atlas; verify
  a doc question answers, a Genesis question ("why did run X fail?") answers from the introspection
  tools, and a mutation attempt ("cancel run X" / "write a file") is refused. Documented as a
  manual checklist with the exact prompts.

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| **Read-only can be bypassed** if auto-deny/trust don't compose as expected in kiro-cli. | 10-01 is a **spike-first** sub-phase: prove trust-allowlist + auto-deny + no-fs-write against the real CLI before building anything else. This is the load-bearing gate. |
| **Kiro conversation context is lost** when the app restarts or the idle reaper closes a client (context lives in the kiro-cli subprocess, not the DB). | Persist the transcript; on the first message after a cold client, replay a **bounded** transcript preamble to reconstruct context (10-04 §4.6). Accept minor fidelity loss; document it. |
| **Secret/PII leakage** through introspection tools (run inputs/state, config). | Config cards already expose only key names + `is_set`, never values. The server redacts: expose input/state **keys** + bounded value previews with a redaction pass on secret-looking keys (10-02 §4.4). |
| **Token/context bloat** from tool definitions. | Atlas-only + a small introspection tool set keeps definitions modest. Revisit progressive disclosure only if the MCP set grows (noted, not built). |
| **A long/expensive turn** (tool loops). | `turn_timeout` bound + a best-effort per-turn tool-call soft cap that appends a stop-note to the prompt context; hard cancel via `/cancel` (10-04 §4.5). |
| **Concurrency** (two turns on one session). | One-active-turn lock per session; second POST → 409 (10-05). |

## 8. Out of scope (v1)

Multi-user/auth (ADR-026); MCP servers beyond Atlas; letting Chat *take actions* (ADR-031);
transcript summarization/RAG over history; exporting chats; voice; mobile. All are future tracks.

## 9. Definition of Done (umbrella)

All seven sub-phases meet their own DoD; backend pytest + ruff, web lint/typecheck/vitest/jest-axe
green; `web/static` rebuilt + committed (stale-bundle guard); ADR-031 in the decision-log; the
release chain shipped with CI green on each repo; the manual live-acceptance checklist (§6) passed
and recorded in `progress/phase-10-chat-assistant.md`; tracker §3/§6 updated.
