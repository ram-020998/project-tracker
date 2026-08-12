# Progress — Phase 21: Feature Workspace, Spec-Builder UX & Chat Parity

> **Status (2026-08-12):** 🚧 IN PROGRESS. **21-01 ✅** · **21-02 ✅** · **21-03 ✅** · **21-04 ✅** · **21-05 ✅** ·
> **21-06 ✅ (chat MD export, uncommitted)**. Next: **21-07** (release chain + bible refresh) — the last sub-phase. Per the
> user, **all repo commits (kiro-agent-sdk + genesis-core + genesis) are held for a single release chain at 21-07** — only
> project-tracker is committed as we go. Spec: `specs/phase-21-feature-workspace-and-chat-parity.md` (+ `21-01..21-07`).
> **ADR-044/045** (Proposed).

## 21-01 — ACP parity spike ✅ (committed to project-tracker)

Verified the ACP-extension surface against the installed **kiro-cli 2.16.2** (throwaway stdlib harness). **GO.** Findings +
recommended SDK surface: `spike/2026-08-12-acp-parity.md`. Headlines:
- **Model list is free at `session/new`** — result `.models = {currentModelId, availableModels[{modelId,name,description}]}`
  (no Settings fallback needed as primary). `session/set_model {sessionId, modelId}` works; agents live under `.modes` +
  `session/set_mode`.
- **`_kiro.dev/commands/available`** is a **notification** (not a request → -32601) carrying the full slash catalog + prompts +
  tools. Per-command `optionsMethod` is advertised but **not wired** in 2.16.2 → **autocomplete client-side** off the catalog.
- **`_kiro.dev/commands/execute`** exists but a headless request **times out** on panel commands → treat as **streaming**; nail
  the terminal signal in 21-04 (fallback: send slash text via the normal prompt path).
- `contextUsagePercentage` (via `_kiro.dev/metadata`) + `promptCapabilities.image: true` present.
- **Impact:** 21-05 sources models from `session/new`; recommend a `chat_sessions.model` column (`m0011`).

## 21-02 — Feature workspace landing ✅ (code-complete; genesis working tree, uncommitted)

Turned the feature page into a **workspace landing** (ADR-044) instead of dropping into the spec builder.

**Backend** (`genesis/api/features.py`): `spec_artifact` gained `annotate: int = 1`. `annotate=0` serves the spec HTML with
**theme only, no Lavish SDK** (the read-only "eye" preview); default `annotate=1` still injects the SDK (the builder's editable
surface). Test `test_artifact_readonly_mode_omits_sdk` added — **13** features-API tests + ruff clean.

**Frontend** (`web/src/features/features/`):
- **`ArtifactPipeline.tsx`** (new) — the ordered pipeline ① Spec ② Design ③ Breakdown with connectors. `SpecCard`: status pill
  + **Edit** (pencil → `…/spec`) + **View** (eye → a full-screen read-only `Dialog` preview at `previewUrl`, `annotate=0`), or a
  single **Create spec** button when none (→ creates then routes to the builder). `PlaceholderCard` (Design/Breakdown): a
  purpose-built **disabled** state — dashed border, muted surface, lock glyph + "Coming soon" (non-interactive). Sequential
  unlock deferred (ADR-044).
- **`FeaturePage.tsx`** rewritten as the landing (renders `ArtifactPipeline`).
- **`SpecBuilderPage.tsx`** (new) at route **`/applications/:appUuid/features/:featureId/spec`** — renders the existing
  `SpecWorkspace` unchanged (the full-width + Preview-popup re-layout is 21-03).
- `lib/api/features.ts` `previewUrl(featureId, theme)` → `artifact?annotate=0`; `shared/ui/icons.ts` + Eye/Lock/Layers/ListChecks;
  `router.tsx` + the `/spec` route; **`FeaturesTab` feature card drops the spec-status badge** (item 1 — a spec's status is not
  the feature's status; no feature status shown yet).

**Gate:** typecheck + eslint clean; **147** Vitest (18 files); `npm run build` OK. `web/static/` rebuilt (uncommitted).

**Note for 21-03:** `SpecBuilderPage` currently renders the OLD 2-column `SpecWorkspace` — 21-03 replaces that with the
full-width chat + full-screen annotatable Preview (our comment-queue + Send-all), the `ChatThread` `chrome="spec"` variant, and
`feature_spec` session isolation from the main chat list.

## 21-03 — Spec-builder re-layout, comment queue & session isolation ✅ (code-complete; uncommitted)

The spec builder is now **chat-first** with an on-demand full-screen review, and its sessions are isolated from the main chat.

**Backend:**
- `ChatStore.list(exclude_modes=())` → `WHERE mode NOT IN (…)`; `ChatManager.list_sessions(exclude_modes=())`; the **main** chat
  list endpoint (`api/chat.py`) now passes `exclude_modes=("feature_spec",)`. `get()`/unfiltered list still return them (the
  feature page loads its session by id). Test `test_list_sessions_excludes_feature_spec`.

**Frontend:**
- **`ChatThread`** gained `chrome?: "full" | "spec"` (default `"full"`). In `"spec"` the **mode banner + Enable-copilot toggle**
  are hidden (item 6); the supervised-runs strip + copilot cards were already gated by copilot mode. The main chat is unchanged.
- **`SpecWorkspace`** rewritten: a **full-width** `ChatThread(chrome="spec")` under a top action bar (Add context · status ·
  Export .md · Save milestone · **Preview**). The always-on right iframe is gone. **Preview** opens a **full-screen `Dialog`**
  (`h-[92vh] w-[94vw]`): the annotatable spec iframe (left) + **our own comment-queue rail** (right). Every `lavish:queuePrompt`
  lands in React state and renders as a removable row (quoted anchor + comment); a single **Send all to agent** composes one
  chat turn (`composeFeedback` → the thread's `send`) and clears the queue. The queue persists across open/close; the iframe
  live-reloads on each new assistant message. (Added the `Send` icon.)

**Gate:** backend **399** pytest + ruff clean; web typecheck + eslint clean, **149** Vitest (18 files), build OK.

**Note:** the Composer's small hint line still reads "Read-only assistant · type / for skills" (a visible span, not the banner) —
left as-is; the Composer is revamped in **21-05** (chat parity).

## 21-04 — `kiro-agent-sdk` ACP extensions ✅ (code-complete; uncommitted, release held for 21-07)

Added the ACP-extension surface the chat-parity work needs, **additive + backward-compatible**, guided by the 21-01 spike and
verified against kiro-cli 2.16.2.

**`KiroACPClient` (client.py):**
- **`start()`** now captures the LLM catalog (`session/new` result `.models`) + agent personas (`.modes`) onto `self.models`/
  `self.modes`, briefly waits for the `_kiro.dev/commands/available` notification, and returns them on **`SystemInit`**
  (new fields `models`, `modes`, `commands`, `prompts`, `tools` — all default empty for older CLIs). `self.capabilities` is
  stored from `initialize`.
- **`_dispatch`** intercepts the extension notifications independently of any turn: `_kiro.dev/commands/available` → updates the
  command catalog + fires the optional `on_commands` callback; `_kiro.dev/{compaction,clear}/status` → `on_session_status`
  callback. (Metadata still flows to the turn loop for metering.)
- **`set_model(model_id)`** → `session/set_model`; **`set_mode(mode_id)`** → `session/set_mode`.
- **`execute_command(text)`** → streams `_kiro.dev/commands/execute` through the shared turn loop (prompt() was refactored to a
  private `_turn(method, params, timeout)`; `execute_command` reuses it with `command_timeout`). Documented caveat from the
  spike: panel commands may not return a terminal result headlessly → ends on timeout; 21-05 falls back to the prompt path.
- **`prompt(text, images=None)`** — optional image content parts, gated on `promptCapabilities.image` (dropped gracefully if not
  advertised). Text-only behavior unchanged.
- Accessors: `available_models` / `current_model_id` / `available_commands` / `available_tools`.
- `KiroAgentOptions` gained `on_commands`, `on_session_status`, `command_timeout` (all optional/defaulted).

**Tests:** `tests/test_acp_extensions.py` (11 new) — content building + image gating, command-catalog capture + callbacks,
session-status callback, model accessors, set_model/set_mode frames, not-started guard, execute_command uses the extension
method. **93 SDK tests pass** (82 prior + 11), ruff clean (src + the new test). Pre-existing `E401` in `test_erd_workflow.py`
left untouched (out of scope; the SDK repo has no ruff CI).

**Release:** version bump + tag + push are **deferred to the 21-07 chain** (kiro-agent-sdk → genesis-core pin → genesis). 21-05
develops against the editable SDK install in the genesis `.venv`.

## 21-05 — Chat parity (model · slash commands · context/compaction · clear · images) ✅ (code-complete; uncommitted)

Brought the reused chat to Kiro CLI/ACP parity, in **both** the main chat and the spec builder (the shared `ChatThread`/
`Composer`), consuming the 21-04 SDK. **ADR-045** relaxes ADR-031: safe introspection commands run freely; write-capable
actions stay human-confirmed via the existing permission bridge.

**Backend (genesis):**
- **m0011** `chat_sessions.model` (nullable) — per-session LLM; `current_version` → 11 (all suite version assertions updated).
- `ChatStore`: `model` on the record + `create()` persists it + `set_model()`.
- `ChatManager`: `create_session(model=)`; `_ensure_started` applies `rec.model or chat_model` to `KiroAgentOptions.model` +
  wires `on_session_status`; caches the agent catalog on first start; `ensure_agent_catalog()` (cache or a one-off throwaway
  client) → `available_models()` / `available_commands()`; `set_session_model()`; `run_slash_command()` (bounded, for
  clear/compact); `stream_turn(text, images=)` routes a leading-`/` message through the SDK `execute_command` (raw, no
  steering) else `prompt(images=)`; a `session.status` event is streamed for compaction/clear.
- `api/chat.py`: `GET /chat/models`, `GET /chat/commands`, `POST /chat/sessions/{id}/{model,clear,compact}`;
  `CreateSession.model`; `SendMessage.images` (base64 JSON — reuses the SSE endpoint; the SDK gates on
  `promptCapabilities.image`); `model` on the session dict.
- Tests: 6 new manager tests; fake clients across 5 test files updated for the new `prompt(images=)` signature.

**Frontend (web):**
- `types/chat.ts` (+`ChatModel`/`SlashCommand`/`ChatImage`, `ChatSession.model`, `ChatEvent.method/params`); `lib/api/chat.ts`
  (+`models`/`commands`/`setModel`/`clear`/`compact`, `createSession(model)`, `sendMessage(images)`); `hooks.ts`
  (+`useChatModels`/`useChatCommands`/`useSetModel`/`useClearSession`/`useCompactSession`; `send(text, images?)`).
- `Composer` rewritten: a parity toolbar (**model select** + **context-usage meter** + **Clear/Compact**), a **Commands**
  palette section (client-side autocomplete off `/chat/commands`; picking a command sends `/name` → `execute_command`), and
  **image attachments** (file → base64 chips). `ChatThread` wires it all and computes the context % from the freshest
  `agent.result`/assistant `usage.context_pct`. Both chrome variants get it (spec omits the workflow launcher).
- Fixes: file-input `aria-label` (a11y); the context-% memo depends on `data?.messages` (exhaustive-deps).

**Gate:** backend **405** pytest + ruff clean; web typecheck + eslint clean, **150** Vitest (18 files), build OK.

**Release:** the genesis + genesis-core (SDK pin) + kiro-agent-sdk changes all ship together in the **21-07** chain.

## 21-06 — Chat transcript export (Markdown) ✅ (code-complete; uncommitted)

Export the full conversation as **Markdown** (server-side, **includes tool calls + thinking**), in both the main chat and the
spec builder.

- **Backend:** `genesis/chat/export.py` `session_to_markdown(session, messages, usage_total)` — header (title/session/mode/
  model/total credits) + per-turn rendering: assistant turns render the folded `events` (💭 thinking, 🔧 tool calls + `↳`
  updates with previews) then the answer + a per-turn credit line; user/system turns rendered plainly. Pure string building
  (no dependency — the MD-first decision). Route `GET /api/chat/sessions/{id}/export.md` (PlainTextResponse, `text/markdown`,
  attachment filename from the title slug).
- **Frontend:** `chatApi.exportMdHref(id)`; the shared `Composer` parity toolbar gains an **Export** download link (wired from
  `ChatThread` → both chat surfaces get it).
- **Tests:** backend `test_export_markdown` + `test_create_with_model_and_catalog_endpoints` + `test_set_model_clear_compact` +
  `test_slash_command_message_routes_to_execute` (the fake client gained a catalog + `execute_command`); web parity test
  asserts the Export link href. **PDF is deferred** (browser print-to-PDF only, per the resolved decision — not shipped).
- **Gate:** backend **409** pytest + ruff clean; web typecheck + eslint clean, **150** Vitest, build OK.