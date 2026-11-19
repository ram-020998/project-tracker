# Review 54-08 — base 41971a0, head 2531930 (genesis-review, 2026-11-19)

What this change does: `POST /api/chat/sessions` with `agent_id` (read-only mode only) now stores the custom agent's
snapshot in `chat_sessions.agent_json`, with its servers normalized by `check_picks`, and starts the session on the
agent's model unless the body names one. The 54-06 409 stub is gone. Every client start, new or `session/load`,
rebuilds the agent from the stored snapshot: the read-only steering first, then a delimited agent block. The agent's
servers are re-checked with `check_picks` and capped to their registry allowlists. Refused servers go into the F3
notice, and the session runs under its own engine agent id. The web adds a New chat agent picker, an agent header
that hides the Copilot toggle (D26), and an agent marker in the session list.

Commits: `c31fd76` (source, tests, fixture, probe) and `2531930` (web/static only). Both resolve; local, not pushed.

## Checklist

`genesis-ctx check --since 41971a0 --repo genesis` listed 83 files: the 19 source files plus 64 `web/static` assets.
Most ADRs and lessons in the list come from the `api` and `features-stages` path globs on `api/chat.py` and the shared
web folders. They are answered N/A where the diff does not touch their subject.

### ADRs
- [OK] ADR-001: chat only answers. No control flow moved to an agent; nothing in the diff orchestrates.
- [OK] ADR-002/004/020: servers are injected per session over ACP (`manager.py` `_build_options` → `mcp_servers=servers`). `kiro_agent_sdk/client.py:start` sends the agent in `session/new`/`session/load` (`agents=[...]`). No global `mcp.json` is written.
- [OK] ADR-005/029: the agent's servers come from `config.merged_mcp_registry()` (both tiers). Trust is `@server/tool` from `registry.allowlist(name)` only (`custom_agent.py` `agent_servers`, `out.reads`). The engine's tool list is the cap; `test_the_projected_agent_of_a_session_with_an_agent_is_read_only` asserts the 33 real appian-atlas tools and the 2 team-wiki tools, and nothing for team-notes.
- [N/A] ADR-010/018/022: no run state or blackboard. The snapshot is a small JSON row.
- [N/A] ADR-011/067: no workflow agent node changed.
- [OK] ADR-012: the app process imports only `genesis_core.mcp.pickable` (core). No workflow Python is imported.
- [N/A] ADR-019, ADR-021, ADR-023, ADR-024, ADR-025, ADR-030 (still SQLite, repository signature unchanged), ADR-032/L-016 (credits path untouched), ADR-033 (copilot unchanged; an agent session can't become copilot), ADR-035, ADR-037, ADR-041–044, ADR-047, ADR-049–051, ADR-053, ADR-056–066, ADR-068, ADR-070–076, ADR-078–085: the diff does not touch their subjects.
- [OK] ADR-026/028/L-010: the route stays under `/api`. The web goes through `chatApi.createSession` (`lib/api/chat.ts:30`); no component calls `fetch` or uses a literal `/api`.
- [OK] ADR-027/055: `agent.tsx` reuses the shared `Popover`, `Select`, `Badge`, `Button`/`buttonVariants` and the icons re-export. It uses tokens only (`bg-surface-2`, `text-fg-muted`, `text-success`); no raw palette colors.
- [OK] ADR-031: the profile stays `auto_deny` with no built-ins (`p.builtins == ()`, `p.mode == "auto_deny"` in the projection test). Reads are listed and auto-approved, and nothing else is listed. The agent block comes after `_STEERING` and says the rules above win (`agent_prompt`; asserted `startswith(_STEERING + "\n\n")`). The mode route returns 422, and `set_session_mode` raises `ValueError` behind it (`manager.py:968–970`; `test_only_a_mode_that_takes_an_agent_accepts_one`).
- [OK] ADR-034: `fs_write_root` is still the per-session `skill_output_dir/<id>` (asserted in the projection test). The agent adds no write path.
- [OK] ADR-045: model selection is unchanged. The agent's model is only the starting `rec.model`, and `set_config_option` validates it as before.
- [N/A] ADR-046, ADR-077, ADR-080: no packaging, install or agent-system change. `packages/kiro-agent-sdk` is unchanged (`git diff --stat` shows no `packages/` path).
- [OK] ADR-069/L-024: chat skills still come from the cwd `state_dir/.kiro/skills` (asserted: `"resources" not in agent and opts.cwd == state_dir`). The agent block only names installed skills (`SkillStore.exists`); `not-installed` is asserted absent.
- [OK] ADR-086: the start path is unchanged: v3, the Genesis-owned `chat_kiro_home`, a projected agent, and activation verified by the SDK's `_after_session` → `session.activate`. The live probe shows `genesis-chat-agent-42` listed with origin `client` and activated, the same on `session/load`, and a control with a bad rule effect failing with `AgentNotActive` (`evidence/chat-agent-probe.json`, `result: PASS`, kiro-cli 2.37.1, 0 prompts).

### Lessons
- [OK] L-001: agent servers come from `registry.acp_servers`, which builds `env` as a list of `{name,value}` (`genesis_core/mcp/registry.py:161`).
- [N/A] L-003, L-018, L-118: the SSE path is unchanged.
- [OK] L-004/L-039: the snapshot is stored in SQLite. `list()` and `get()` share `ChatSessionRecord._from_row`, so the list carries `agent` too (`store.py:53–56`; the web list marker relies on it).
- [N/A] L-007, L-019, L-025/L-027 (ruff pin unchanged), L-030 (the release's concern), L-031, L-041/L-042 (no authoring change), L-043, L-044, L-046, L-047, L-048, L-051, L-056/L-057 (no release), L-058, L-061–L-064, L-068, L-071–L-076, L-081–L-088, L-090, L-092 (the new test module name is fine and has no `__init__`), L-093, L-095, L-096 (no new route), L-098–L-101, L-104, L-105, L-107, L-112, L-114, L-115, L-119.
- [OK] L-017: chat trust stays fail-closed. Allowlists are namespaced `@server/tool`. A server with no allowlist adds no tool and is not started (`NO_ALLOWLIST`), and `auto_deny` sits behind the list. The negative control shows the ladder denies `appian-dev-write` write tools and `@team-wiki/delete_page` (`permissions.decide(...).approved is False`).
- [N/A] L-045: no new CLI surface is exposed.
- [OK] L-069: no `<Button asChild>`. `PopoverTrigger asChild` wraps a native `<button>` styled with `buttonVariants` (`agent.tsx`).
- [OK] L-089: `git show --stat 2531930 -- web/static` → 64 files, 283+/283−. `git show --stat c31fd76 -- web/static` is empty. A fresh `npx vite build --outDir /tmp/54-08-static-r1` gives `diff -r` against `web/static` → IDENTICAL. `git status` is clean.
- [OK] L-094: I grepped the consumers. `create_session` callers (`stage_finalizer.py:129`, `story_design_finalizer.py:139`, `api/features.py:483`) pass no agent. `sessions.set_mode` writers are only `create_session` and `set_session_mode`, and both are guarded. The only user of `useCreateSession` / `chatApi.createSession` is `SessionList`.
- [N/A] L-109: the D3 rule keeps one home (`check_picks`), and chat calls it rather than copying it (D33). `CHAT_TOOLS_NOTE` now gives the editor and the chat one wording.
- [OK] L-110/L-111: gates re-run by me, below. Live acceptance in a real browser is honestly left to 54-10.
- [OK] L-113: trust is the projected agent, with no flag. Activation is verified by the SDK, and the probe's control proves the check can fail.
- [OK] L-116: tested on the real `genesis-workflows/mcp-registry.json` (copied into a temp library) with every `NOT_PICKABLE_CURATED` server as a negative control. The test is skipped only when the sibling checkout is absent; it was present here and ran.
- [OK] L-117: the probe uses the product's own path (`ChatSession._ensure_started`, the real `ConfigService`, the real `KiroACPClient`, a throwaway home under a `~/.genesis` guard). It runs one case per session and includes a control that must fail, which did fail. The unit negative control also has a positive control (`team-wiki/get_page` approved; the leaked-agent check flags 2).

### Gates (re-run by me, 2026-11-19 IST)
- [OK] `.venv/bin/python -m pytest -q -p no:warnings` → **2088 passed** in 661.89s, nothing deselected (run at about 19:25, outside the D27 window).
- [OK] `.venv/bin/ruff check genesis` → All checks passed.
- [OK] `packages/kiro-agent-sdk`: `../../.venv/bin/python -m pytest -q` → 302 passed.
- [OK] web `npm run lint` → 0 errors and 20 warnings, all in files this diff does not touch (router, catalog/skills, documents, library, settings, workbench, shared/ui). `npm run typecheck` → clean. `npx vitest run` → 78 files, 864 passed.
- [OK] Build: an out-of-tree build is identical to the committed `web/static` (see L-089).

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **A picked custom server with no allowlist is accepted at creation but silently gives the chat no tools** (`genesis/chat/custom_agent.py` `agent_servers` → `NO_ALLOWLIST`; `web/src/features/catalog/agents/notes.ts` `CHAT_TOOLS_NOTE`).
  - What the code does: `session_snapshot` (the create route) only runs `check_picks`, so a custom server marked read-only but with no `tool_allowlist` passes, and the session is created with 200. At the first turn, `agent_servers` leaves the server out and the F3 card says "team-notes did not start: team-notes: has no tool allowlist, so chat lists none of its tools."
  - Problem: the same agent's server gets `@team-notes` (every tool) in a schedule or Run (`genesis_core/nodes/agent.py:184`, "or the whole server (`@server`) when it has none"). In chat it gets nothing, but the picker note says the agent keeps "only the read tools of its servers", which reads as "some tools". The user learns otherwise only after sending a prompt.
  - Fix (smallest): add one clause to `CHAT_TOOLS_NOTE`, for example "a server with no tool allowlist adds no tools in chat". That one string feeds both the Agents editor and the chat picker. Optionally return `agent_servers(...).refused` with the create response.
  - If skipped: the user picks an agent, asks a question that needs its custom server, and gets a warning card and an answer without that server's data.
  - This is the author's decision 1. The behaviour itself is the fail-closed reading of §1.2 and ADR-031, and I agree with it. The user should still confirm it, as the author plans.

### Nits
- n1 The module docstring says a refused server is "reported once, on the client's first turn". It is reported again after every client start (idle reap, restart, mode/skills reload), because `_agent_refused` is rebuilt in `_build_options`. That is the right behaviour; the wording "once per client start" would say it exactly.

### On the author's decisions
1. A no-allowlist custom server adds no tool in chat: agreed. It is fail-closed and matches the existing `build_chat_mcp` treatment of `appian-dev` (registry allowlist only). It diverges from the workflow (`@server`), so the user must confirm; see m1 for the UI wording.
2. A start-time refused pick is left out with the F3 notice, and creation returns 422: agreed. Covered by `test_negative_control_mutating_tools_are_absent_and_denied` (hand-written snapshot) and `test_create_refuses_an_agent_whose_server_is_no_longer_pickable`.
3. A distinct engine id `genesis-chat-agent-<id>`: fine. The agent is sent over the wire per session (`client.py` `session.new(..., agents=[...])`) and is not a file in the shared `chat_kiro_home`, so two sessions with different snapshots of one agent cannot overwrite each other. `agent_id_for` still handles a clash with an engine mode name.
4. An explicit `body.model` wins: fine, and tested (`"model": "other"`).
5. One-click New chat with no custom agents: fine, and tested ("with no custom agents, New chat starts a chat at once").

## Not checked
- The real-browser look of the popover and agent header (both themes, focus return on close). The author left this to 54-10; jsdom axe passes closed and open.
- Live denial of a non-allowlisted tool of a picked server by the engine. The probe sent no prompt (0 credits), so it proves activation and the projection, not a denied call on the wire; the unit test proves the SDK ladder denies it. This is for 54-10's live probe (spec §1.4).
- The author's mutation claims (dropping `check_picks`, showing the banner for an agent session). The code is read-only for me, so I did not repeat them. The negative and positive controls I read would fail in those cases.

## Verdict: SHIP
No blockers or majors, and every gate is green when re-run. m1 (one clause in `CHAT_TOOLS_NOTE`) and the user's
confirmation of decision 1 can land with this sub-spec or as a 54-10 follow-up.
