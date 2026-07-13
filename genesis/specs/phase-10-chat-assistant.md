# Phase 10 (proposed) — Chat: a read-only conversational assistant for Genesis

**Status:** 📝 Draft handoff (2026-07-13) — requirements + confirmed scope + design direction.
**Not yet a full implementation spec.** Next agent: expand into a full spec + ADR, spike the
read-only enforcement, then implement on approval (plan-first per the working agreements).

## 1. Objective
Add a new **Chat** page to the Genesis web app: a ChatGPT-style, multi-turn conversation with Kiro.
Inspiration: the internal `appian/prod/ai-sre` project (readable via `glab`, default branch `main`) —
a multi-agent LangGraph app with a Next.js streaming chat; its `agents/universal_agent/agent.py` pools
all tools and filters per request, and it caps each turn with tool-call/model-call limits. We reuse the
*idea*, not the code.

The Chat serves two blended purposes in a single conversation:
1. **Talk to Kiro with MCP access** — ask anything; the agent can call MCP tools to answer (document
   Q&A etc.).
2. **Talk to Genesis** — ask about the platform's own state: recent runs, what failed and why, a run's
   progress/status, installed workflows, integration health, etc.

## 2. Confirmed scope decisions (from the product owner)
1. **MCP set: `appian-atlas` only** for now (not "all MCPs"). This greatly simplifies the read-only
   story — we expose Atlas's read tools only.
2. **Sessions are persisted**, and the user can **delete** them (session list + delete).
3. **Full Genesis data access** — runs, events, status, failures, progress, workflows/catalog,
   integration health, config (secret-redacted).
4. **Single blended chat** — Atlas tools + Genesis-introspection tools available together in one
   session (no mode toggle).
5. **Single-user, local only** (ADR-026 stands) — no auth/multi-tenancy.

## 3. Interaction model + the ADR boundary (decide first)
Genesis's ADR-001 says **agents never orchestrate** (the retired solutions-copilot failed as an
LLM-orchestrator). A chat agent is that shape, so we make the boundary explicit with a **new ADR
(≈031): Chat is a read-only assistant / observability co-pilot — it observes and answers, it never
drives or mutates.** Hard rules:
- **No mutations, ever**: cannot start/pause/resume/cancel/fork runs, cannot install/remove workflows,
  cannot edit config/secrets, cannot deploy, no `fs_write`, no terminal, no CLI nodes.
- Only **read** tools: Atlas read tools + read-only Genesis introspection tools.
- **Flip the SDK permission default for chat**: today the SDK auto-*approves*
  `session/request_permission`; for chat, auto-**deny** anything mutating (defense in depth beyond
  simply not granting write tools).
- Read-only is enforced by **not granting capabilities**, not by prompt text (prompt/steering is only a
  secondary reinforcement).

## 4. Proposed architecture (Genesis-native)
- **Web**: a new `Chat` nav entry + page. Reuse the run-detail conversation renderer (`buildTranscript`
  / `TurnView` / markdown) for the transcript; reuse the SSE `EventBus` +
  `agent.message/thought/tool_call/tool_update` events for streaming. Left rail = session list
  (select/new/delete); main = transcript + composer.
- **Backend**: a `ChatManager` (sibling to `RunManager`) that owns **persistent multi-turn Kiro ACP
  sessions** — the SDK's `KiroACPClient` already supports `start()` once + `prompt()` per turn (we've
  only used one-turn-per-node so far). Lean toward running each session in a **supervised subprocess**
  (like workers, ADR-012) to keep Kiro out of the app process; needs lifecycle:
  create/idle-timeout/cancel/cleanup, one active turn at a time per session.
- **MCP wiring**: inject **`appian-atlas`** (read tools only, via the ADR-029 allowlist/`mode`) **+ a
  new read-only "Genesis introspection" MCP server** (Genesis-owned, launched per session like the
  Phase-9 blackboard server; it reads the SQLite DB / stores directly since a kiro-cli child can't
  reach app memory). Redact secrets in its outputs.
- **Safety caps** (from ai-sre): per-turn **tool-call limit + model-call limit** to bound a runaway
  chat turn; plus `turn_timeout`.
- **Persistence**: new SQLite migration — `chat_sessions` (id, title, created_at, updated_at) +
  `chat_messages` (session_id, role, content, events/tool-calls, ts). Delete = cascade remove a
  session. Follows the `genesis/db/` migration pattern (never hand-write DDL).
- **Token/context note**: Atlas-only avoids the "load all MCP tool defs" bloat; keep an eye on it if
  the MCP set grows later (progressive disclosure / tool-search is the known mitigation).

## 5. "Genesis introspection" read-only tool set (full data access)
Backed by `RunStore` / `EventLog` / `ConfigService` (all read-only):
`list_runs(status?, limit?)`, `get_run(run_id)` (status/cursor/timing), `get_run_events(run_id, kinds?)`,
`get_run_progress(run_id)` (nodes done/total, current), `list_failures(window?)`, `list_workflows()` /
`get_workflow(id)`, `integration_health()`, `platform_stats()` (the /home metrics). All secret-redacted.

## 6. Reuse map (low net-new)
SDK persistent session (exists) · per-node MCP injection + registry (exists) · SSE `EventBus` +
conversation events + web conversation components (exist) · Genesis-owned MCP server pattern +
`introspect.py` framing (Phase 9) · `RunStore`/`EventLog`/`ConfigService` read APIs (exist) ·
`genesis/db/` migrations (exists). **Net-new:** `ChatManager` + session lifecycle, the
Genesis-introspection MCP server, the read-only/permission-deny enforcement, chat persistence tables,
the Chat page/UI, chat API routes (`/api/chat/...` + SSE).

## 7. Risks / still-open decisions
- **Read-only enforcement** is the load-bearing risk → do a **spike** first: confirm we can (a) restrict
  Atlas to read tools via allowlist, and (b) auto-deny mutating permission requests in a persistent SDK
  session, before building.
- **Session execution model** (subprocess vs in-process async) — pick during spec.
- **Secret redaction** in the Genesis tools (config/run data may contain tokens).
- **History/transcript growth** and context window for long sessions (summarization/truncation later;
  not v1).
- Where the introspection server lives (genesis-core vs genesis) — likely `genesis` since it reads the
  platform DB.

## 8. Suggested delivery sequence
1. Spec + ADR-031 (read-only assistant boundary).
2. Spike: read-only Atlas + auto-deny permissions in a persistent SDK session.
3. Backend: `ChatManager` + session lifecycle + persistence migration + SSE.
4. Genesis-introspection MCP server (read-only) + Atlas read-tool injection.
5. Web: Chat page (session list + transcript + composer), reusing conversation components.
6. Tests (backend + web) → release genesis (+ genesis-core if the server lands there).

## 9. Context to resume cold
- Repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/{kiro-agent-sdk,genesis-core,genesis,genesis-workflows}`;
  project-tracker (design/specs) at `/Users/ramaswamy.u/repo/project-tracker/genesis/` (read
  `AGENT_ONBOARDING.md` first).
- **Current versions:** kiro-agent-sdk **v0.2.0**, genesis-core **v0.6.0**, genesis **v0.18.0**,
  genesis-workflows **v0.4.1**; `CORE_MAJOR=1`; ADRs through 030 (Chat ADR would be ~031).
- Read the reference repo with `glab` (authed for reads): e.g.
  `glab api "projects/appian%2Fprod%2Fai-sre/repository/tree?recursive=true&per_page=100"` and
  `glab api "projects/appian%2Fprod%2Fai-sre/repository/files/<url-encoded-path>/raw?ref=main"`.
  Relevant files: `agents/universal_agent/agent.py` (tool pooling + call limits),
  `frontend/src/app/api/chat/stream/route.ts` (SSE chat), `mcp/knowledge_base_mcp/` (their doc MCP).
- This is **spec/plan-first** (per the working agreements): write the Phase 10 spec + ADR, spike the
  read-only enforcement, then implement on approval.
