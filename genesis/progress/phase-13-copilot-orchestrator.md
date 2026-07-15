# Phase 13 — Chat Copilot & Run Orchestrator (as-built progress)

Spec: `specs/phase-13-copilot-orchestrator.md` (+ `phase-13-copilot-orchestrator/13-01..13-06`). ADR-033.

---

## 13-01 — SDK interactive permission bridge

### Load-bearing spike (R1 of the umbrella) — CONFIRMED ✅ (2026-07-15)

**Question:** does kiro-cli fire `session/request_permission` for an **untrusted** MCP tool call (and
skip it for a **trusted** tool)? This is the whole basis of the "leave mutating tools untrusted → confirm
card" model (ADR-033). If it didn't hold, 13-01 would be N/A and we'd fall back to UI-mediated
pending-action confirmation.

**Method:** a real `KiroACPClient` against **kiro-cli 2.12.2**, with a minimal stdio MCP server exposing
`read_thing` (read) + `do_mutation` (write). `_handle_agent_request` was spied to record every
`session/request_permission`. `permission_mode="auto_deny"` so a fired request is denied and the turn
continues. Two cases:
- **CASE A** — `trust_tools=None` (nothing pre-trusted), prompt "call do_mutation value=1".
- **CASE B** — `trust_tools=["@spike/read_thing"]`, prompt "call read_thing key=x".

**Result:**
- CASE A (untrusted `do_mutation`): `session/request_permission` fired **1×**; agent then reported the
  tool was denied (auto_deny selected `reject_once`).
- CASE B (trusted `read_thing`): fired **0×**; the tool ran silently to completion.
- **VERDICT: CONFIRMED.**

**Captured real param shape** (drove the `_permission_request` normalizer):
```json
{
  "sessionId": "…",
  "toolCall": { "toolCallId": "toolu_…", "title": "Running: @spike/do_mutation" },
  "options": [
    {"optionId": "allow_once",   "name": "Yes",    "kind": "allow_once"},
    {"optionId": "allow_always", "name": "Always", "kind": "allow_always"},
    {"optionId": "reject_once",  "name": "No",     "kind": "reject_once"}
  ],
  "id": "57f8c4c9-…"    // NOTE: request id is a STRING uuid, not an int
}
```

**Design consequences (locked in for the implementation):**
1. Request `id` is a **string** — `_respond` already accepts `Any`; fine.
2. The permission request carries **no `rawInput`** (only `toolCall.toolCallId` + `title`). So the confirm
   card (13-03/13-05) must correlate the arguments from the preceding `tool_call` event by `toolCallId`;
   `PermissionRequest.raw_input` is best-effort (usually `{}`), and `tool_name` is parsed from the
   `@server/tool` token in `title`.
3. Option `kind`s are `allow_once` / `allow_always` / `reject_once` — the existing `startswith("allow")` /
   `startswith(("reject","deny"))` matching is correct; `_first_deny` picks `reject_once`.

Spike scripts were throwaway (`/tmp/phase13_spike/`), removed after the run.

### As-built (SHIPPED — kiro-agent-sdk v0.5.0, 2026-07-15)

**Change (additive, backwards-compatible → minor bump):**
- `messages.py` — new `PermissionRequest` TypedDict (`tool_name`, `title`, `raw_input`, `options`,
  `tool_call_id`), documented that the raw permission request carries no arguments (correlate by
  `tool_call_id`).
- `client.py` — `KiroAgentOptions` gained `permission_mode="ask"` (docs), `on_permission:
  Callable[[PermissionRequest], Awaitable[str|None]]`, and `permission_timeout=300.0`. The
  `session/request_permission` handling was factored into `_handle_permission` (three modes) +
  async `_resolve_permission_ask`. The **ask** branch schedules the callback round-trip via
  `asyncio.create_task` (tracked in `self._perm_tasks`) so the read loop is never blocked while a
  human/UI decides. Module helpers `_first_deny` (returns an optionId or None) and
  `_permission_request` (normalizes the raw params → `PermissionRequest`, deriving a namespaced
  `@server/tool` name from the title).
- `__init__.py` — exports `PermissionRequest`.

**Fail-closed guarantees:** any callback exception, a timeout, or an optionId the agent didn't offer →
select the reject/deny option (or cancel if none). **Hardening beyond the spec:** `permission_mode="ask"`
WITHOUT an `on_permission` callback also fails closed (deny) rather than silently falling through to
`auto_approve` — a misconfiguration can never make the agent autonomous.

**Tests:** `tests/test_permission_ask.py` — 16 tests (normalizer + `_first_deny`; allow; choose-reject;
None→deny; raises→deny; timeout→deny; unknown-option→deny; no-reject→cancelled; ask-without-callback→deny;
3 auto_approve/auto_deny regressions). Full SDK suite **75 passed**; ruff clean on all touched files.
(Pre-existing, unrelated `E401` in `tests/test_erd_workflow.py:119` left as-is — not modified; SDK repo
has no CI.)

**Release:** committed + tagged **v0.5.0** + pushed (`b07e9fd`).

**Pin bump DEFERRED to 13-03 (intentional).** Both `genesis` AND `genesis-core` pin
`kiro-agent-sdk` directly. Bumping only one to `v0.5.0` while the other stays `v0.4.0` would give pip two
conflicting direct git refs for the same package (unresolvable). Nothing consumes `permission_mode="ask"`
until 13-03 (copilot chat mode), so the pins stay at `v0.4.0` for now and will be bumped together in a
coordinated genesis-core + genesis release when the feature is actually wired in. The `v0.5.0` tag exists
and is ready.



---

## 13-02 — Genesis Control MCP server (+ ADR-033)

### As-built (code committed to genesis master `b6edf7c`; NO release yet — see below)

**`genesis/mcp/control_server.py`** — a write-capable stdio MCP server, the sibling of the read-only
`introspection_server`, but a **thin MCP→HTTP facade** over the existing `/api` surface (Codex-as-MCP
pattern). It holds no run logic; each tool is one HTTP call, so `RunManager` stays the single source of
truth. 10 run-management tools:
- read (trusted by the 13-03 wiring): `list_launchable_workflows` (`GET /catalog`),
  `get_workflow_inputs_schema` (`GET /workflows/{id}` → `inputs_schema`+`required_mcp/cli`),
  `check_launch_readiness` (`/workflows/{id}` + `/config/mcp-cards` + `/config/cli-cards` →
  unconfigured/missing-secret MCP + missing CLI), `get_run_status` (compact `/runs/{id}`, no bulk/secret
  echo), `get_run_steps` (`/runs/{id}/steps`), `get_pending_gate` (`/runs/{id}` → `.gate`),
  `list_session_runs` (`/chat/runs`).
- mutating (left UNTRUSTED by 13-03 → per-call confirm): `start_run` (`POST /runs`), `respond_to_gate`
  (validates a string decision against the gate's `options`, normalizes `{"decision":…}`, feedback dict
  always allowed → `POST /runs/{id}/respond`), `cancel_run` (`POST /runs/{id}/cancel`).
- `MUTATING_TOOLS = {start_run, respond_to_gate, cancel_run}` is exported as the authoritative untrusted
  set for the 13-03 wiring + tests.

**Boundary (ADR-033 / ADR-029):** the tool set is run-management ONLY — there are deliberately **no**
config/secret/registry/workflow-definition/deploy tools (authority-by-tool-set). Tests assert the exact
tool set and the absence of any forbidden name.

**`genesis/api/chat.py`** — added a `GET /api/chat/runs` placeholder returning `[]` (filled by 13-03's
link table) so `list_session_runs` has a stable endpoint.

**ADR-033** already recorded in `reference/decision-log.md` (Proposed) from the planning phase; its text
matches this sub-phase. 13-06 flips it to Accepted.

**Tests:** `tests/test_control_server.py` — 23 tests (mock the HTTP session): exact tool set;
no config/registry/deploy tools; every tool dispatchable; each read/mutating tool → correct endpoint +
payload; `respond_to_gate` rejects an option not in the gate and does NOT post; feedback-dict allowed;
not-awaiting error; decision normalization; token header sent iff configured; `initialize`/`tools/list`
protocol. Full genesis suite **145 passed**; ruff clean on touched files. Also stdio-smoke-tested
(`initialize` → `genesis-control`, `tools/list` → 10 tools).

### Deviations from the spec (intentional, flagged)

1. **`requests`, not `httpx`.** The spec said httpx, but **httpx is a dev-only dependency of genesis**
   while `requests` is a runtime dependency — a real install wouldn't have httpx, and the control server
   runs as a subprocess in that install. `requests` is synchronous, which also fits the stdio loop.
2. **Token gating deferred (does NOT gate shared endpoints).** The spec called for a per-process token
   that the mutation endpoints *require*. But `POST /api/runs` / `/respond` / `/cancel` are the **same
   endpoints the browser Runs UI already calls tokenless** — hard-requiring a token would break the UI,
   and it would be incoherent security (the whole app is unauthenticated on localhost per ADR-026;
   `POST /config/secrets` is itself tokenless). So: the control server **sends** `X-Genesis-Control-Token`
   when launched with `--token` (ready to *identify* copilot-originated calls for the 13-06 audit log),
   but 13-02 does **not** add an app-side gate, and does not yet generate the token (that lands in 13-03
   where the server is actually launched). The real security/kill-switch/rate-limit model is designed
   holistically in **13-06**. Acceptance criterion 2's "mutations require the control token" is therefore
   deliberately **not** met literally — flagged for the record.

### Release status
Genesis code committed to master (`b6edf7c`, pushed) but **NOT tagged**. The control server is inert until
13-03 wires it into a copilot chat session, and 13-03 also carries the coordinated `kiro-agent-sdk` v0.5.0
pin bump (genesis + genesis-core together). So genesis is released once at 13-03.


---

## 13-03 — Copilot chat mode + run↔session link (SHIPPED — genesis v0.21.0 + genesis-core v0.8.1)

Turns a chat session into a supervised run **operator** (ADR-033). Bundles the 13-02 control server
(previously inert) into a working feature, and cuts the coordinated SDK-v0.5.0 pin bump.

**Wiring resolved.** `Settings.api_base` (env `GENESIS_API_BASE`, default `http://127.0.0.1:8760`); the
`genesis serve` command exports it from `--host/--port` (normalizing `0.0.0.0`/`::` → `127.0.0.1`) so the
in-process chat can tell the control **subprocess** where to call back. Each copilot session mints a
per-session control **token**, registered in a ChatManager `token→session` map and passed to the control
server via `--token`; `POST /api/runs` reads `X-Genesis-Control-Token` and links the run to the session.

**Schema (`m0004_copilot`, version=4).** `chat_sessions.mode` (`read_only` default | `copilot`);
`chat_run_links` (run_id PK → session, cascade); `chat_permissions` (tool_call_id PK, tool_name, args,
options, status pending|allowed|denied, decision, timestamps). New stores `ChatRunLinkStore` +
`ChatPermissionStore`; `ChatStore.set_mode`; `ChatSessionRecord.mode`.

**MCP surface (`build_chat_mcp(config, settings, mode, *, base_url, token)`).** Copilot mode adds the
`genesis-control` server; its **read** tools are trusted (`@genesis-control/<tool>`), its **mutating**
tools (`start_run`/`respond_to_gate`/`cancel_run`) are left UNTRUSTED so each fires
`session/request_permission`. Read-only mode is byte-for-byte unchanged (no control server).

**Permission bridge (the core).** Copilot sessions use `permission_mode="ask"` + a session-bound
`_on_permission` callback that: (1) persists a pending `chat_permissions` row; (2) emits a
`permission.request` event on the live turn's SSE via an **out-of-band queue merged into `stream_turn`**
(refactored to a pump-task + merged queue carrying `msg`/`err`/`end`/`perm` — read-only output unchanged);
(3) awaits an `asyncio.Future` keyed by `tool_call_id`. `POST /api/chat/sessions/{id}/permissions/{tcid}`
(`option_id`|null) resolves it → the SDK responds to kiro (allow optionId → tool runs; null/timeout → deny).
On timeout/cancel the callback's `finally` marks the row denied (fail-closed). A `permission.resolved` event
is emitted on resolution.

**API.** `GET /api/chat/runs` (session from the control-token header OR `?session=`, joins live run status
via RunManager); `POST /api/chat/sessions/{id}/mode` (toggle; closes the live client so the next turn
rebuilds the surface); `POST …/permissions/{tcid}` (resolve). `app.state.chat` + `app.state.run_manager`
exposed for the 13-04 supervisor + tests.

**Steering.** A copilot preamble replaces the read-only one (operator rules: only start on confirmed
inputs; relay — never invent — gate decisions; every mutation is confirmed; no config/secret/deploy).

**Tests.** `tests/test_copilot_mode.py` (13): MCP surface (reads trusted / mutations untrusted / no config;
read-only has no control); copilot options (`ask` + on_permission + `allow_fs_write=False`); permission
allow (tool runs, row `allowed`, `permission.resolved`), deny (tool refused, row `denied`), timeout
(finally marks denied); read-only unchanged; token registry; link + list session runs; resolve-returns-False
when nothing pending; API mode-toggle + resolve + `/chat/runs` scoped by query & token. Updated
`test_chat_store.py` + `test_db.py` for schema version 4. **Full genesis suite 158 passed; genesis package
ruff-clean.** (Pre-existing test-only lint in other files left as-is — CI lints the `genesis` package only.)

**Release (coordinated, resolves the 13-01 deferral).** Because both genesis AND genesis-core pin the SDK
directly, they were bumped together: **genesis-core v0.8.1** (SDK pin v0.4.0→v0.5.0, dependency-only, no code
change) → **genesis v0.21.0** (SDK pin→v0.5.0, core pin→v0.8.1, copilot mode; version + FastAPI version
string bumped). 13-02's control server ships here (it was inert on master until now). CI verified on both.


---

## 13-04 — Run-supervision bridge (SHIPPED — genesis v0.22.0)

Makes the copilot **sense** what happens to a run it started without staying alive.

**Mechanism.** `RunManager` gained a lightweight `add_event_observer(cb)` hook invoked in `_log` for every
canonical event. `ChatRunSupervisor` (`genesis/chat/supervisor.py`) registers an observer; for a
**session-linked** run (via `chat_run_links`, 13-03) hitting `gate.awaiting` or a terminal `run.final` it:
(1) writes a durable `chat_notification` (m0005; UNIQUE `dedup_key = run_id:kind:seq`); (2) pushes a
`run.notification` on a **per-session notification SSE**; (3) injects a **deterministic system nudge**
(role=`system`) into the transcript so the copilot surfaces the gate + options. The user replies → the
agent calls `respond_to_gate` (confirm card, 13-03) → the run resumes.

**Threading.** The observer fires on the **worker reader thread** (`RunManager._log`), so it does
thread-safe DB writes then schedules the SSE push + nudge on the captured app loop via
`loop.call_soon_threadsafe` (bound at FastAPI startup; runs inline when no loop is bound, e.g. tests).

**Level-triggered robustness.** `reconcile(session|all)` recovers a pending gate / missed terminal from
`RunManager.pending_gate` + `RunStore` + `eventlog.latest` — run at **startup** (all links) and on **each
notification-stream connect** (one session). Idempotent: reconcile reuses the event's `seq` in the dedup
key, so a live event + a reconcile of the same gate nudge exactly once (survives restart / dropped stream).

**SLA.** `check_sla(now)` re-nudges a gate left unconsumed past `copilot_gate_sla_minutes` (env, default 0 =
off) with a windowed dedup key; it **never auto-answers** — timeout only escalates attention.

**Design decision (flagged).** The "nudge" is a **deterministic system message**, not an LLM-generated
turn: it surfaces the gate + options with **no surprise credit spend** and no risk of a hallucinated nudge;
the agent does the real work when the user replies. (The spec said "nudge turn" — this is a cleaner,
cheaper realization of the same intent.)

**API.** `GET /api/chat/sessions/{id}/notifications` (+`?unconsumed`), `POST …/notifications/{id}/ack`,
`GET …/notifications/stream` (SSE: reconcile + SLA on connect, replay unconsumed, tail live).

**Tests.** `tests/test_supervisor.py` (8, `FakeRunManager`): gate on a linked run notifies + nudges once +
dedups on replay; unlinked run ignored; terminal notifies once; non-terminal `run.final` marker skipped;
reconcile recovers a pending gate after a simulated restart (idempotent); reconcile + live same-gate no
double; SLA re-nudge past the window; SLA disabled by default. Updated `test_db.py` + `test_chat_store.py`
for schema **version 5** (synthetic next-migration bumped to 6). **Full genesis suite 166 passed; genesis
package ruff-clean.** Exposed `app.state.supervisor`.

**Release.** genesis **v0.22.0** (`a51c79b`). No SDK/core change (observer hook + supervisor + m0005 are all
in genesis). Bundles nothing else.


---

## 13-05 — Slash-command launch & in-chat HITL/confirm UI (SHIPPED — genesis v0.23.0, frontend)

The copilot UX — the whole launch → supervise → decide loop happens in the conversation.

**Slash palette** (`Composer.tsx`): in copilot mode, typing `/` opens a fuzzy list of installed workflows
(`useInstalled` + `prereqFor` → unready ones annotated "needs setup"); arrow/enter/click selects one and
opens the **LaunchDialog**; Escape/newline dismisses. Read-only mode has no palette.

**LaunchDialog** (`LaunchDialog.tsx`): reuses the 07-05 `buildLaunchForm`/`toRunInputs` to render the
workflow's `inputs_schema` (react-hook-form + zod). On submit it does **not** call `/api/runs` — it emits a
`start_run` **intent chat turn** (`Please start the "<name>" workflow (id: …) with these inputs …`) so the
KIRO AGENT starts the run (ADR-033); the agent's untrusted `start_run` then raises a confirm card. Dialog
submit + confirm card = the human confirmation.

**In-chat cards** (`cards.tsx`): **PermissionCard** (from the live turn's `permission.request`; Allow picks
the allow-kind optionId, Deny → null → `POST …/permissions/{tcid}`; shows a resolved state after);
**GateCard** (from a `run.notification` kind=gate; option buttons + a feedback textarea compose a decision
message the agent relays); **TerminalCard** (kind=final; status + a Run-Detail link). **SupervisedRunsStrip**
lists the session's linked runs (`GET /chat/runs`) with live status dots ("awaiting you" highlighted).

**Wiring** (`ChatThread.tsx`): a per-session **mode toggle** (`useSetMode`); `SupervisedRunsStrip` + a
`useSessionNotifications` stream (opens the notification SSE, seeds unconsumed, dedups by id) rendering the
gate/terminal cards; `SystemNudge` renders `role=system` transcript messages (the 13-04 nudges);
`LivePermissions` derives confirm cards from the live turn events. Read-only chat is visually + functionally
unchanged.

**SSE**: `readSse` made generic (`<T=ChatEvent>`) so it serves both the turn stream (ChatEvent, incl.
`permission.request`/`permission.resolved`) and the per-session `run.notification` stream. New API methods:
`setMode`, `resolvePermission`, `sessionRuns`, `notifications`/`ackNotification`, `streamNotifications`.
Types: `ChatSessionMode`, `ChatMessage.role +system`, `RunNotification`, `SessionRunRow`.

**Tests.** `copilot.test.tsx` (11): readSse run.notification; palette lists/filters/picks + no-palette in
read-only; LaunchDialog schema→onLaunch inputs; PermissionCard allow→optionId/deny→null + resolved state;
GateCard option→decision text; TerminalCard status+link; SupervisedRunsStrip status mapping + empty + a11y.
**Full web suite 89 passed** (was 78); lint 0 errors, tsc clean, jest-axe green.

**Release.** genesis **v0.23.0** (`e74e896`); frontend-only but still a genesis release (`web/static`
rebuilt + committed — the CI stale-bundle guard requires it). No SDK/core change.


---

## 13-06 — Safety, audit, advanced-gate patterns & release (SHIPPED — genesis v0.24.0)

Hardens the copilot for real use and finalizes ADR-033 (→ Accepted). **Phase 13 complete.**

**Persisted safety config** (`genesis/config/copilot.py` — `CopilotConfig`, atomic
`~/.genesis/copilot.json`, the hardened secrets pattern; defaults from env/`Settings`):
`enabled` (kill-switch), `max_active_runs` (3), `rate_limit_per_min` (10), `gate_sla_minutes`,
`workflow_allow`/`workflow_deny`. Runtime-toggleable (unlike env-only `Settings`).

**Kill-switch** (defense in depth, 3 layers): `ChatSession._ensure_started` demotes a
`copilot` session to the read-only surface when disabled (the control server is never wired
→ mutating tools gone); `ChatManager.set_session_mode` refuses `copilot` when disabled;
`POST /api/runs` refuses a copilot-token start (403). Instant + reversible.

**Blast-radius enforcement — app-side, gated on the control token** (`_enforce_copilot_start`
in `app.py`, BEFORE `manager.start`): kill-switch (403), workflow allow/deny (403), per-session
concurrency cap (429, counts non-terminal linked runs), per-session rate limit (429, in-memory
60s window). **Deviation from the spec §7 (flagged):** the spec said "enforce in
`control_server.py`", but the control server is a bypassable HTTP proxy subprocess — the
authoritative point is the app endpoint, keyed on `X-Genesis-Control-Token`. Browser Runs-UI
starts are tokenless → **never** gated (they hit the same endpoint the copilot does; hard-gating
would break the UI and be incoherent on a single-user localhost, ADR-026).

**Audit trail** (`m0006 copilot_actions`, schema v6; `CopilotActionStore`): one row per
agent-initiated mutating tool call, keyed by `tool_call_id`. `ChatSession._on_permission`
records the **proposal** (tool + args + best-effort run_id); `ChatManager.resolve_permission`
records the **human decision** (allowed/denied) + `confirmed_by_user`; the `_on_permission`
timeout `finally` records `timeout`. `GET /api/chat/actions[?session=]` surfaces it read-only.
**Honest scope (flagged):** the tool's deep return value isn't observable from genesis, so
`outcome` = the confirmed decision + linkage (the `run_id` for `start_run` comes via
`chat_run_links`), not the run's eventual result.

**Advanced-gate patterns.** *Conditional/pre_mutation:* structurally, a workflow's own gates
(incl. `pre_mutation`) can **never** be auto-approved — the copilot only RELAYS a decision via
the untrusted, always-confirmed `respond_to_gate`; no mutating control tool is ever in the
trust set (asserted by test). *Timeout:* the 13-04 SLA re-nudge now reads the persisted
`gate_sla_minutes` (`supervisor._sla_effective`); it only escalates attention, never
auto-answers. *Batch review:* the supervised-runs strip already consolidates multiple awaiting
runs (each still individually confirmed) — kept as the light realization.

**API.** `GET/PUT /api/config/copilot`; `GET /api/chat/actions`.

**Web.** Settings → General **Copilot** section (`CopilotSection.tsx`): kill-switch `Switch` +
concurrency/rate/SLA number fields + allow/deny (raw-text, split-on-save to avoid the
controlled-input separator round-trip) + a read-only **activity table** (tool · run · outcome
badge · when). The Chat **mode toggle is gated on the kill-switch** (`useCopilotEnabled` → GET
`/config/copilot`; disabled + read-only ⇒ the toggle is disabled with a hint).

**Live acceptance (NOT run by me — flagged).** The stubbed E2E (below) proves the genesis-side
loop; a real-kiro-cli session (untrusted control tools fire `request_permission`, launch
`erd-generation`/`hello-appian`, answer the approve-domains gate from chat, run completes) is a
manual step — it can't be driven headlessly. Procedure: `genesis serve` on ≥ v0.24.0 with a
connected Atlas secret; enable copilot in Settings → General; in Chat type `/`, pick a workflow,
submit the dialog, allow the confirm card, then answer the gate card; verify Settings → Copilot
activity shows the two confirmed rows.

**Tests.** `tests/test_copilot_safety.py` (13): kill-switch demotes the session + refuses start;
setmode refused when disabled; browser start unaffected; workflow deny/allow; concurrency cap
(seeds a running `RunRecord`); rate limit; audit proposal→confirmation→outcome (+ denial); the
actions endpoint; config get/update (comma-string coerced to list); mutating tools never
trusted. `tests/test_copilot_e2e.py` (1): a scripted client + `test_supervisor.FakeRunManager`
drive launch(confirm+audit) → link → gate nudge → respond(confirm+audit) → terminal, asserting
two allowed audit rows. **genesis 180 pytest** (was 166); ruff clean; `test_db`/`test_chat_store`
bumped to schema v6. Web `copilot-settings.test.tsx` (4, incl jest-axe) → **web 93** (was 89);
lint 0 errors, tsc clean; `web/static` rebuilt.

**Release.** genesis **v0.24.0** (`237d411`). No SDK/core change (all in genesis: config store +
m0006 + app enforcement + web). ADR-033 flipped **Proposed → Accepted**.
