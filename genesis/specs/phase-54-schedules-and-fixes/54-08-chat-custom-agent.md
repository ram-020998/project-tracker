# 54-08 — Chat: a read-only session with a custom agent

> **Status:** BUILT 2026-11-19 (genesis `41971a0..8f8b1a1`, local; review SHIP, `reviews/54-08-review.md`).
> SPEC-DRAFTED 2026-11-19. Repo: genesis (`genesis/chat/`, `genesis/api/chat.py`, `web/src/features/chat/`).
> Parent: `specs/phase-54-schedules-and-fixes.md`. Built by **genesis-dev** after 54-03's approval. Decisions: D5, D6
> (`54-01-findings.md` §8).

## 1. Backend

1. `POST /chat/sessions` accepts `agent_id` only with `mode == "read_only"` (422 otherwise, 54-06). **54-06 already
   added** the `mode` field, the validation, the `chat_sessions` snapshot column (in m0030) and a 409 stub for a valid
   read-only `agent_id` (D37); 54-08 stores the snapshot, projects it, and removes the 409. The session stores
   the agent's **snapshot** (`custom_agents.snapshot`, 54-05 §1) in `agent_json` (54-06 As built: the column is `chat_sessions.agent_json`). 54-08 still owes, per 54-06's As built: store
   the snapshot, remove the 409, build the chat projection, and rebuild it on resume. The agent is fixed
   for the session: `set_session_mode` (`chat/manager.py:937`) to another mode is refused (422) for a session with an
   agent (the toggle is hidden, D26).
2. The read-only profile (`chat/mode_profile.py:226`, `ChatModeProfile`) is unchanged for every other session. For a
   session with an agent:
   - instructions: the read-only assistant's own prompt first, then a delimited block "Additional instructions from the
     custom agent <name>" (the assistant's rules keep precedence: ADR-031);
   - skills: the agent's skills, if installed, are listed to the model; they are reached through the chat cwd as today
     (Phase 53, managed skills only);
   - MCP: the agent's servers are validated with `check_picks(config.merged_mcp_registry(), picks)` (D33; 54-05 As
     built) and added to the session's servers, each still capped to its **read-only** allowlist in
     the projected agent and backed by the permission ladder's `auto_deny` (ADR-031, L-017); a custom server marked
     read-only by the user is added with the same fail-closed treatment (no tool is trusted beyond the read-only
     allowlist build, L-116);
   - built-ins: none beyond the read-only mode's (no shell, no writes outside the sandbox, ADR-034);
   - model: the agent's model, if set, is the session's starting model (the user can still change it as today).
3. Resume (`session/load`, Phase 53) rebuilds the same agent from the stored snapshot.
4. Trust is verified as for every chat session (activation checked, fail closed, L-113); add one live probe in
   acceptance (54-10).

## 2. Web

From 54-07's As built: reuse `useCustomAgents` (`features/catalog/agents/hooks.ts`) for the picker, take the tools-note
wording from the Agents editor so both say the same thing, and use the shared `RowMenu` if a menu is needed;
`ScheduledBadge` is a model for a small linked badge in the chat header.

New-chat control with an optional custom agent picker (read-only mode only), the agent name in the chat header, and
a short note that in chat the agent keeps chat's read-only tools (D5), as in the approved mockup
(`web/src/dev/mockups/phase54/bell-chat.tsx`, genesis `b09b08e`). **A chat with a custom agent hides the Copilot
toggle (D26)**; the backend still refuses a mode change to copilot for such a session (§1.1).

## 3. Tests

Backend: the projected agent for a session with an agent contains only read-only tools and the agent's skills; a
copilot session with `agent_id` → 422; resume keeps the agent; deleting the agent while a chat uses it is allowed (F3
refuses only when a schedule uses it) and the chat keeps its stored snapshot. Web: picker, header, a11y.

## 4. Gates

SDK, genesis pytest + ruff; web lint, typecheck, test; build + commit `web/static/` separately (L-089).

## As built

**Status:** BUILT 2026-11-19, review **SHIP** (round 1; m1 and n1 fixed after it). Repo genesis, branch master, base
`41971a0`, head `8f8b1a1`, 4 local commits (not pushed, not tagged). Source, tests, fixture and probe: 19 files,
+1133/−47. `web/static` in two build commits. No migration change: `chat_sessions.agent_json` is m0030's (54-06), DB
stays **v30**. `packages/kiro-agent-sdk` not changed. The fleet's `genesis serve` was not restarted; `~/.genesis` was
not read or written (every test and the probe use a throwaway home).

### Commits (genesis)

| sha | what |
|---|---|
| `c31fd76` | the snapshot stored on create, the projection rebuilt at every client start, D26 in the manager, the web picker / header / hidden toggle, tests, the `chat/session-created-agent` fixture, the live probe and its evidence |
| `2531930` | `web/static` for `c31fd76` (`git show --stat 2531930 -- web/static`: 64 files; a rebuild in a later call left `git status --short --untracked-files=all` empty; the reviewer's out-of-tree build was identical) |
| `9396277` | review m1 (the tools note says a server with no allowlist adds no tools) and n1 (docstring) |
| `8f8b1a1` | `web/static` for `9396277` (64 files, checked the same way; `git show --stat 9396277 -- web/static` is empty) |

### Changed

- **`genesis/chat/custom_agent.py`** (new), the one home of the chat side of D6:
  - `agent_engine_id(agent)` → `genesis-chat-agent-<id>` (stable per custom agent, so `session/load` re-sends it).
  - `agent_prompt(base, agent, installed=)`: the read-only assistant's `_STEERING` first, then a block between
    `=== Additional instructions from the custom agent "<name>" ===` and `=== End of the instructions from the custom
    agent "<name>" ===`. The block says the agent's instructions add to the rules above and never replace them, the
    assistant stays READ-ONLY with only the listed tools, and the rules above win on a conflict. It names the agent's
    installed skills only (`SkillStore.exists`), then the instructions. The name is collapsed to one line.
  - `agent_servers(config, agent, present=)`: for each pick (the first pick of a name counts, as `check_picks`),
    `check_picks(config.merged_mcp_registry(), [pick])` (D33) at every client start. A pick already in the session
    (`genesis-kb`, a co-injected `appian-dev`) adds nothing. A server that passes adds `registry.acp_servers([name])`
    and `@name/<t>` for each `tool_allowlist` tool only. A server with no allowlist adds no tool and is not started
    (`NO_ALLOWLIST`). A refused, malformed or unresolvable pick is left out with `{name, reason}`. An unreadable
    registry refuses every pick.
  - `session_snapshot(agents, agent_id, registry)`: `CustomAgentStore.snapshot` with `mcp_servers` normalized by
    `check_picks`; `LookupError` / `NotPickableError`.
- **`chat/mode_profile.py`**: `ChatModeProfile.takes_custom_agent` (True only for `read_only`), so no `self.mode ==`
  branch is added (the 25-07 guard test).
- **`chat/manager.py`**:
  - `_build_options`: when `rec.agent` is set and the profile takes an agent, the agent's servers and reads are added
    (reads listed and auto-approved, `auto_deny` behind them; no built-ins), the agent id and prompt replace the
    profile's. Resume goes through the same code from the stored snapshot.
  - `_mcp_notice(client, servers, refused)`: the refused picks join the F3 `session.notice` (`mcp_failed`), shown on
    the first turn of each client start.
  - `create_session(..., agent=)` refuses an agent for a mode that takes none (`ValueError`).
  - `set_session_mode` raises `ValueError` for an agent session to such a mode (defence behind the route's 422, D26).
- **`chat/store.py`**: `ChatStore.create` writes `agent_json` (`json.dumps` of the snapshot) only when an agent is set,
  so a store over a pre-m0030 DB still creates sessions (two existing store tests need that).
- **`api/chat.py`**: `POST /chat/sessions` with `agent_id` (read-only only) stores the snapshot; 422 `agent_id` for an
  unknown agent, and 422 `{detail, field: "agent_id", refused}` when `check_picks` refuses a server. `model` = the
  body's, else the agent's. The D37 409 and `CHAT_AGENT_NOT_BUILT` are gone. The mode route's 422 is unchanged.
- **Web**:
  - `features/chat/agent.tsx` (new): `ChatAgentNote`, `ChatAgentHeader` ("Agent: <name>", Read-only, the note),
    `NewChatPicker` (shared `Popover` + `Select` + `Button`; the trigger is a native `<button>` with `buttonVariants`,
    L-069; a 422's `detail` shows as an alert in the panel).
  - `SessionList.tsx`: with custom agents (`useCustomAgents`), New chat opens the picker; without, it starts a chat at
    once as before. Rows show a `Bot` icon and an sr-only ", agent <name>" for agent chats, `MessagesSquare` otherwise
    (the mockup's rail).
  - `ChatThread.tsx`: an agent session shows `ChatAgentHeader` instead of the mode banner, so no Copilot toggle (D26).
  - `hooks.ts`: `useCreateSession()` takes `{title?, agentId?}`.
  - `features/catalog/agents/notes.ts` (new): `CHAT_TOOLS_NOTE`, used by the Agents editor ("In Chat: …") and the chat
    note ("In chat, …"), so both say the same thing.
  - `types/chat.ts`: comments (no 409).
- **Fixture** `web/src/test/fixtures/chat/session-created-agent.json`, recorded from a real response
  (`GENESIS_WRITE_CONTRACT_FIXTURES=1`, L-011, L-083).
- **Probe** `scripts/spikes/54-08/probe_chat_agent.py` (throwaway harness) and `evidence/chat-agent-probe.json`.

### Tests

- `tests/test_chat_custom_agent.py` (new, 9). The projection tests copy the real `genesis-workflows/mcp-registry.json`
  into a temp library (skipped when the sibling checkout is absent, as other cross-repo tests are), use a real
  `ConfigService` with two custom servers (`team-wiki` with an allowlist, `team-notes` without), and the v3 fake client:
  - the projected agent (built by the SDK's own `agent_spec.project`): no built-in, no non-mcp rule, `auto_deny`;
    `appian-atlas` with exactly its 33 real allowlist tools; `team-wiki` with its 2; nothing of `team-notes`;
    `genesis-kb` not sent twice; the fake engine's D19 `schema_problems` + `genesis_problems` empty; agent id; cwd =
    `state_dir` (skills through the cwd, no `resources`); `fs_write_root` the session sandbox; the model; the prompt
    order and block; only installed skills named; the notice for `team-notes`;
  - **negative control**: a hand-written snapshot naming every `NOT_PICKABLE_CURATED` server, an unmarked custom server,
    an unknown name and a repeated pick. None reaches the agent, each reason is in the notice, and the SDK permission
    ladder (`permissions.decide`) denies five real `appian-dev-write` write tools and the picked `team-wiki`'s
    `delete_page`. Positive controls: `team-wiki/get_page` is approved, and the check flags a leaked write tool and
    `execute_bash` (L-117);
  - resume: after an idle reap the new client uses `session/load` with the same agent id, prompt, trust and servers;
  - a session without an agent is unchanged;
  - only `read_only` takes an agent; the snapshot reads back unchanged; `set_session_mode` to copilot refuses;
  - the block's shape (one-line name, installed skills);
  - API: create stores the snapshot and starts on the agent's model, a body model wins, copilot + `agent_id` → 422,
    the mode change → 422; a server no longer pickable → 422 with `refused` and nothing stored; deleting the agent
    (204, F3) keeps the chat's snapshot, and the next turn still projects it.
- `tests/test_schedules_api.py`: the 54-06 test now asserts the stored snapshot and records the new fixture.
- Web `features/chat/chat-agent.test.tsx` (new, 8): the picker by keyboard with userEvent (Tab to New chat, Enter,
  the agent Select by Enter / ArrowDown / Enter, focus back in the panel, Tab to Start chat, Enter → `agent_id: 1`,
  navigation); the panel without an agent; a 422 shown in the panel; no agents → one-click as before; the list
  marker; jest-axe closed and open (L-014); the header with the agent, Read-only and the note, no Copilot button, axe;
  a plain chat keeps its toggle. `phase54-contract.test.ts` (+1): the new fixture through `chatApi.createSession`.
- Mutation evidence: dropping `check_picks` in `agent_servers` fails the negative-control test; showing the mode banner
  for an agent session fails the hidden-toggle test. Each was reverted and re-checked in a later call.
- **Gates** (at `c31fd76`; the `9396277` fix is a string and a docstring, after which ruff, lint, typecheck and the full
  web suite were re-run):
  - genesis `.venv/bin/python -m pytest -q -p no:warnings`: **2088 passed**, 18:59–19:10 IST, **outside** the
    00:00–02:00 window, nothing deselected. The reviewer re-ran it: 2088 passed.
  - `.venv/bin/ruff check genesis`: clean.
  - web `npm run lint` 0 errors (20 pre-existing warnings, none in changed files), `npm run typecheck` clean,
    `npm test` **864 passed** in 78 files.
  - SDK untouched; the reviewer ran its pytest anyway: 302 passed.

### Live probe (0 credits, no prompt; the Phase 53 D19 pattern)

`.venv/bin/python -u scripts/spikes/54-08/probe_chat_agent.py`, 2026-11-19 19:01 IST, kiro-cli **2.37.1**, signed in.
A throwaway home (a guard refuses `~/.genesis`), the real `mcp-registry.json`, a custom server `team-kb` (a second
copy of Genesis's KB server, marked read-only, allowlist of 3 tools), the managed skill `appian`, a real
`ConfigService` and the real `KiroACPClient`, started through `ChatSession._ensure_started` as a first turn would.
Result **PASS** (`evidence/chat-agent-probe.json`):
- `genesis-chat-agent-42` listed with origin `client`, `current_mode` = its id, no `_kiro/customAgent/not_found` (the
  SDK's activation check passed); start 3.8 s;
- 38 tools, all `@server/tool`, no built-in, all within allowlists; one mcp allow rule; servers `genesis-kb`,
  `genesis-memory`, `genesis`, `team-kb`, all `connected`; `jira` left out with its D3 reason in the notice;
- `session/load` of the same session re-sent the same agent and activated again;
- control: the same projection with one rule effect `sometimes` failed closed with `AgentNotActive` ("invalid_enum_value"
  read from the session's own log).

Not proven live: a denied call of a non-allowlisted tool on the wire (no prompt was sent); the unit test proves the SDK
ladder denies it. That is for 54-10's probe (§1.4).

### Review

`specs/phase-54-schedules-and-fixes/reviews/54-08-review.md`. **Round 1 (`2531930`): SHIP.**
- m1: a custom server with no allowlist is accepted at creation but gives the chat no tools, while the note promised
  "the read tools of its servers". Fixed in `9396277`: `CHAT_TOOLS_NOTE` adds "(a server with no tool allowlist adds
  none)", in both the editor and the chat.
- n1: the docstring said "reported once"; it is per client start. Fixed in `9396277`.
- The reviewer agreed with my five decisions below; decision 1 still needs the user's confirmation.
- Not re-reviewed after `9396277` (a string and a docstring; gates re-run).

### Decisions / deviations

No ADR deviation. Mine (the reviewer agreed with each):
1. **To confirm with the user: a custom server marked read-only but with no `tool_allowlist` adds no tool in chat** and
   is not started (reported in the notice). This is the spec's "no tool is trusted beyond the read-only allowlist
   build" and matches `build_chat_mcp`'s `appian-dev` treatment. A schedule or Run gives the same server every tool
   (`@server`, `genesis_core/nodes/agent.py:184`). The alternative is to trust the user's mark in chat too (`@server`
   listed and auto-approved).
2. A pick refused at a client start (the registry changed after creation) is left out with the F3 notice, and the chat
   still answers. Creation refuses with 422.
3. An engine agent id per custom agent (`genesis-chat-agent-<id>`), not `genesis-chat-read-only`.
4. An explicit `model` in the create body wins over the agent's model.
5. With no custom agents, New chat stays one click (no panel); the panel opens once the agents have loaded.

### Lesson candidates

1. **A list shared by two writers needs the reader's own dedupe rule.** `check_picks` keeps the first pick of a name;
   running it per pick (to get a per-server result) silently accepted a later duplicate until the loop copied the
   rule. When you split a whole-list validator into per-item calls, carry over its cross-item rules.
2. **A test that holds a reference to an element can miss a re-render that replaces it.** The New chat button is a
   different element once the agents load; `waitFor` on the old reference never saw the popover trigger. Re-query
   inside `waitFor`.
3. **When the same capability is weaker in one context, say so where the user picks it, not only where it fails.** The
   no-allowlist server was correct and fail-closed, but the user would learn about it only from a warning after a
   prompt (review m1).

### Code-map changes (for genesis-docs, bible/03)

- `genesis/chat/custom_agent.py` (new): `agent_engine_id`, `agent_prompt`, `agent_servers` (`AgentServers`),
  `session_snapshot`, `NO_ALLOWLIST`: a read-only chat with a custom agent (D6).
- `genesis/chat/mode_profile.py`: `ChatModeProfile.takes_custom_agent`.
- `genesis/chat/manager.py`: `_build_options` projects the agent; `_mcp_notice(…, refused)`;
  `create_session(agent=)`; `set_session_mode` refuses for an agent session.
- `genesis/chat/store.py`: `ChatStore.create` writes `agent_json`.
- `genesis/api/chat.py`: `POST /chat/sessions` stores the agent snapshot (no 409).
- `web/src/features/chat/agent.tsx` (new): `ChatAgentNote`, `ChatAgentHeader`, `NewChatPicker`.
- `web/src/features/catalog/agents/notes.ts` (new): `CHAT_TOOLS_NOTE`.
- `scripts/spikes/54-08/` (new): the zero-credit chat-agent activation probe.

### For 54-09 / 54-10

- **54-10 live rows:**
  - in a real browser, both themes: the New chat panel (Select inside the Popover, focus back on close), the agent
    header, the list marker;
  - one real turn in a chat with an agent: the instructions followed, an installed skill used, a picked server's read
    tool used, and a non-allowlisted tool of a picked server refused on the wire (the probe sent no prompt);
  - resume after a `genesis serve` restart keeps the agent;
  - deleting the agent from Catalog → Agents while its chat is open; the chat keeps working;
  - the user's answer to decision 1.
- `scripts/spikes/54-08/probe_chat_agent.py` can be re-run against the release candidate (0 credits).
- 54-09: nothing from this sub-spec. `Badge` with `border bg-surface-1` is the agent chip; no new shared primitive.

## Context manifest

```toml
areas    = ["chat", "sdk-acp", "config-secrets"]
adrs     = ["ADR-029", "ADR-031", "ADR-034", "ADR-045", "ADR-086"]
lessons  = ["L-017", "L-024", "L-089", "L-113", "L-116", "L-117"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-54-schedules-and-fixes/54-05-custom-agents-and-agent-prompt.md"]
code     = ["genesis/genesis/chat/**", "genesis/genesis/api/chat.py", "genesis/web/src/features/chat/**"]
upstream = ["54-03", "54-05", "54-06", "54-07"]
```
