# Review 53-11 — Phase 53 (kiro-agent-sdk v3), base genesis 62537c2 / genesis-workflows v0.25.0 / playwright-appian v0.3.0 (genesis-review, 2026-11-14)

What this change does: it replaces the v2 Kiro client with a v3-only SDK: `kiro-cli acp --agent-engine v3`, a required
Genesis-owned `KIRO_HOME`, and a projected custom agent per session with an explicit tool list. A permission ladder
reads tool identity only from `_meta.kiro`, and credits come from `turn_completion`. Workflow nodes run with `<run>/_kiro`
as home and D9's trust. Chat runs every mode with `~/.genesis/kiro-home/chat` and a per-mode policy, with Stop that keeps
the session, steering, `session/load` resume and an MCP notice. Skills are managed-only (`appian` published to the
library), preflight checks for kiro-cli ≥ 2.37.1 with v3, and the web gains steering, Stopped, answered-by and Skills
Update.

**Scope of this round (operator, 2026-11-14):** the Appian environments are unavailable, so §3 live acceptance was not
run. The operator asked for a deep code-level review instead. Every §3 row is listed under "Live checks not run" with
the reason. This report replaces the provisional draft of the same day.

Reviewed at: genesis `b9ba5d9` (HEAD, verified `git log -1`), genesis-workflows `b097719` (HEAD), playwright-appian
`38f87fd` (HEAD), spec set at project-tracker `240feaa`. All four trees are clean. The phase base `62537c2` is the
`v0.81.0` tag itself (`git describe --tags 62537c2` → `v0.81.0`; the tag sits on the two 51-13 reap fixes).
`genesis-ctx check --since 62537c2 --repo genesis` → 385 files, 12 areas; `--since v0.25.0 --repo genesis-workflows`
→ 68 files; `--since v0.3.0 --repo playwright-appian` → 13 files.

What I read: the whole product diff (57 files, +4 773 / −1 259 outside tests, fixtures, docs and spikes):
- every SDK module in full (`transport`, `launch`, `session`, `client`, `updates`, `usage`, `errors`, `timeouts`,
  `permissions`, `agent_spec`, `tool_ids`, `__init__` `query`);
- `genesis/chat/manager.py` in full, plus `mode_profile.py`, `mcp.py`, `store.py` and `api/chat.py`;
- `genesis_core/nodes/agent.py`, `workspace.py`, and `runtime/{context,preflight,kiro_auth,settings}.py`;
- the skills store, model and API;
- the web chat hooks, steering, `ChatThread`, `Composer`, skills catalog, run-detail and format diffs.

I also read the callers of every changed signature: `kiro_node` across all 18 workflows, `check_kiro`,
`reload_all_skill_clients`, `onPickSkill`, `Worker.kill`.

A1 precondition (re-diff for Phase 51 v0.81.x patches): none. genesis has no commit between `8e5bacc` (the release)
and `62537c2` besides the two 51-13 reap fixes in the base. genesis-workflows has one commit after `v0.25.0`
(`b097719`, the `appian` skill); nothing changed under `workflows/` except
`story-implementation/tests/test_library_skills.py`.

## §2 Gates (run by the reviewer, 2026-11-14)

| Gate | Result |
|---|---|
| SDK `cd packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` | **302 passed** in 28.8 s |
| SDK `ruff check src tests` | All checks passed |
| genesis-core `pytest -q -p no:warnings` | **109 passed** in 10.3 s |
| genesis-core `ruff check genesis_core` | All checks passed |
| genesis-appian-parser `pytest -q` | **53 passed, 1 skipped** (`test_diff_hash.py:39`, two real exports not provided; unchanged) |
| genesis `.venv/bin/python -m pytest -q -p no:warnings --deselect tests/test_config.py::test_server_readiness_probe` (with `GIT_CONFIG_COUNT=1 … commit.gpgsign=false`, as in 53-10's review) | **1933 passed, 1 deselected** in 587.9 s |
| genesis `ruff check genesis` | All checks passed |
| web `npm run lint` | 0 errors, 20 warnings (pre-existing `react-refresh` / unused-disable; same count as 53-10's review) |
| web `npm run typecheck` | clean |
| web `npm test` | **762 passed (66 files)** |
| Stale bundle: `npx vite build --outDir /tmp/rv5311/static`, then `diff -r /tmp/rv5311/static web/static` | **identical** (diff exit 0) |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (18 workflows) |
| genesis-workflows `ci/validate_skills.py` | SKILLS VALIDATION PASSED (5 skills: gam, appian-object-generation, sail-mockup-generation, genesis-test-authoring, appian) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **432 passed** in 32.2 s |
| playwright-appian `npm run lint && npm run typecheck` | Prettier clean; `tsc` (cjs + esm) clean |
| playwright-appian `npm test` | **1402 passed (95 files)** |
| The three Python suites in the `python:3.13` image (53-12 precondition, L-112) | **NOT RUN**: Docker is down (`colima status` → "colima is not running"); I did not start it |
| Clean-install CI job | **NOT RUN**: CI runs only on a push; nothing is pushed before 53-12 |

Gate output: `/tmp/rv5311/*.txt`.

Extra checks run by the reviewer (0 credits):
- **Workflow tool lists against the registry caps.** Each `graph.py` was loaded standalone and every upper-case
  tool-list constant (`GROUNDING_TOOLS`, `KB_RO`, `NODE_TOOLS[...]`, …) was compared with `mcp-registry.json`
  `tool_allowlist`. No node lists a tool its server's allowlist does not hold, so the new per-server intersection
  (`_node_mcp_trust`) removes no tool any of the 18 workflows relies on. (v2's `_compute_effective_trust`
  intersected `@server/tool` with bare allowlist names, which 53-06 fixed.)
- **Stdin-EOF probe** (`/tmp/rv5311/eof_probe.py`; kiro-cli 2.37.1, private `KIRO_HOME` under `/tmp`, `initialize` +
  `session/new` only, no prompt). Question: does kiro-cli leak when the run worker is killed by `Worker.kill()`'s
  SIGTERM? On SIGTERM the SDK's `close()` never runs; only the pipe closes. After stdin EOF, `kiro-cli`,
  `kiro-cli-chat` and the engine (`node`, its own group) were all gone within **4.57 s**. Limit: an idle session with
  no MCP server and no tool running. The mid-turn case (an `apwt` shell tool) is A6/D24.
- **Chat home contents** (read-only, values never printed). `~/.genesis/kiro-home/chat` on `main` is 896 KB: 6 log
  folders of about 67 KB each, and two session records. The engine log lines carry `mcpServers` as counts only. The
  session records hold no `env` block, and their one `APPIAN_` hit is skill text. No secret value is at rest there.

## §1 Review items 1–9

1. **v3 only (D5): VIOLATION, see M1. Otherwise OK.** `git grep` over genesis (excluding `web/static`) and
   genesis-workflows found no product-code use of these: `--trust-tools`, `--trust-all-tools`, `agent-engine v2`,
   `_kiro.dev/metadata`, `_kiro.dev/commands`, `_kiro.dev/{compaction,clear}/status`, `session/set_model`,
   `execute_command`.
   - The hits are the 51-03 spike harness (historical), the `m0011` docstring (historical), the architecture docs
     from `7d7cd2d` (they describe v0.81.0, and 53-12's write-back updates them, `240feaa`) and four stale comments
     (n1).
   - The only launch is `launch.build_argv` (`acp --agent-engine v3`).
   - What fails the item: a typed engine `skill` command is still sent raw "to make the engine act" (M1).
2. **Kiro home (D6): OK.**
   - `launch.build_env` raises without a home (`launch.py:160-168`, test `test_v3_units.py:329`).
   - Nodes use `<run>/_kiro` (`agent.py:367`, `workspace.py:15`).
   - Chat, the catalog probe and the delete client use `settings.chat_kiro_home` (`manager.py:290-293`, `:814-816`,
     `:1026-1029`, `settings.py:135-140`).
   - No `Path.home() / ".kiro"` remains in product code. The `~/.kiro` hits are docstrings saying it is never read.
   - `kiro_auth.py:48,94,133` run `whoami` / `logout` / `login` without `KIRO_HOME`. These are sign-in commands only
     (no agent, MCP, skill or steering), so D6 holds.
3. **Trust (D9, F2, 53-05): OK.**
   - `project()` (`agent_spec.py:171-206`): `tools` is always explicit, from the tool-id table. `never_projected =
     ['delete_file']` and the meta tools are checked as an invariant (`RuntimeError`, also under `-O`).
   - Rule capabilities come only from the fixed list `('fs_read','fs_write','shell','web_fetch','web_search','mcp')`,
     so never `all`/`builtin`/`filesystem`. MCP globs are refused by `split_mcp` (`_NAME`).
   - The ladder (`permissions.py:161-196`) takes identity only from `_meta.kiro` and denies when there is none. The
     backstop is `OUTSIDE_POLICY`, and a `*_always` option is never chosen.
   - Read-only: `builtins=()`, `auto_deny` (`mode_profile.py:272-275`).
   - Copilot's mutating control tools are listed without approval (`mcp.py:94-98`, `mode_profile.py:265-268`), so they
     reach `ask` and the confirm card.
   - Activation fails closed (`session.py:252-275`, `set-mode-dropped` replay).
   - Spec-mode writes: the engine's write is a client `fs/write_text_file` (53-01 P9), still confined by
     `fs_write_root` with a resolve-and-parents check (`client.py:345-363`).
   - Node trust: `_node_mcp_trust` (`agent.py:172-208`) plus `NODE_BUILTINS`, all auto-approved, in line with D9.
4. **Credits (ADR-032): OK.**
   - `usage.py:62-90`: credits come only from `turn_completion` entries with `unit == "credit"`, summed over the engine
     turns in one prompt; replay frames are skipped.
   - `provenance` is `metered` only with a credit entry, otherwise `unavailable` with `credits None`; no 0 is invented.
   - `query()` refuses a turn on a failed MCP server before the prompt, reporting `unavailable` with no credits
     (`__init__.py:115-121`).
   - The stopped-turn credits are 53-07 M1's shielded finalization (`manager.py:494-516`).
5. **Contracts (53-09): OK.** `tests/test_phase53_api_contract.py` records the 16 web fixtures from real responses
   (`contract_fixtures.record`), and `web/src/test/fixtures/phase53-contract.test.ts` reads them; both suites are green.
6. **Process hygiene (F12): OK in code; live A6 not run.**
   - `KiroProcess.terminate` (`launch.py:342-367`) sends TERM, then KILL, to kiro-cli's group, then to each recorded
     engine group it can still prove is its own; it never signals a later group.
   - A worker killed by SIGTERM leaves nothing behind in the idle case (stdin-EOF probe above).
   - `genesis serve` shutdown closes every chat client (`app.py:375` `aclose_all`).
7. **Import surface (F13): OK.**
   - The gate tests pass in the suites above: `tests/test_sdk_import_boundary.py`,
     `packages/genesis-core/tests/test_core_sdk_import_boundary.py` and
     `packages/kiro-agent-sdk/tests/test_public_surface.py`.
   - `git grep` finds no `from kiro_agent_sdk.<module> import`, no `import kiro_agent_sdk.<module>` and no
     `from kiro_agent_sdk import _…` in `genesis/**` or `genesis_core/**`, and no SDK import at all in
     genesis-workflows.
8. **Secrets / tokens: OK.**
   - A regex scan found 0 strings shaped like a JWT, an `aoa…` token, an `accessToken`/`refreshToken` value or an
     account ARN in: `packages/kiro-agent-sdk/tests/fixtures`, `web/src/test/fixtures`, `scripts/spikes`, `tests`, and
     the phase's `evidence/` folder.
   - The access-token responder registers the token and the ARN as `FrameLog` secrets and never echoes the callback's
     text (`client.py:402-450`).
   - `FrameLog` scrubs token-named keys and redacts joined chunk text (`transport.py:46-105`).
   - The chat home holds no secret value (extra checks above).
9. **Skills (D7, D8): OK.**
   - `_skill_source` resolves only the managed workspace and the run checkout's playwright-appian, and validates front
     matter (`context.py:76-109`).
   - `personal_dir` / `shadows_personal` appear only in tests that assert their absence, and in the architecture docs
     (53-12).
   - `appian` 1.0.0 is in `skills-registry.json` and validates.
   - The D17 bundle rules keep the traversal, dot-segment, size and count caps (`store.py:47-58`, `:165-171`).

## Checklist (union of the three `genesis-ctx check` lists)

ADRs
- [OK] ADR-001 — no agent orchestrates; a steer only adds user text to the chat's own turn (`manager.py:644-665`).
- [OK] ADR-002 / ADR-004 — every agent turn goes through the SDK with the node's own `mcp_servers` (`agent.py:373`); `includeMcpJson: false` (`agent_spec.py:201`).
- [N/A] ADR-003, ADR-005, ADR-007, ADR-008, ADR-013, ADR-015, ADR-017 — not touched by this phase.
- [OK] ADR-006 — `appian` is a library skill folder registered in `skills-registry.json`; the workflows are unchanged.
- [N/A] ADR-009, ADR-025 — HITL and fork are unchanged (no `genesis/runs` change besides the SDK swap).
- [OK] ADR-010 / ADR-018 / ADR-022 — the run home `<run>/_kiro` lives in the run folder, is hidden from the artifact listing (`workspace.py:69-83`) and goes with run retention; nothing bulk enters state.
- [OK] ADR-011 — the `validate_library` reliability lint passes (18 workflows); `mcp_failed` before the prompt is a failed turn the trio retries (`agent.py` docstring, `__init__.py:115-121`).
- [OK] ADR-012 — the app imports no workflow Python; nodes run the SDK in the worker; a killed worker's kiro-cli exits on stdin EOF (probe).
- [OK] ADR-019 / ADR-080 — `CORE_MAJOR` unchanged; the packages stay under `packages/` with no internal dependency entry.
- [OK] ADR-020 — nothing writes `~/.kiro`; the `appian` copy left the personal folder untouched (no write path to `~/.kiro` in the diff).
- [OK] ADR-021 — node policy `mode="auto_approve"` (`agent.py:215-216`); gates unchanged.
- [N/A] ADR-023, ADR-024 — engine and backend shape unchanged.
- [OK] ADR-026 — no new non-loopback bind; `/steer` sits under the existing app.
- [OK] ADR-027 / ADR-055 — `McpNoticeCard` uses `border-warning/40 bg-warning-subtle` and `TriangleAlert` from `@/shared/ui`; `AnsweredBy` sits in `shared/ui/format.tsx`; no raw palette colours in the web diff.
- [OK] ADR-028 / L-010 — the new routes are under `/api`; the web calls go through `lib/api/{chat,skills,system}.ts`.
- [OK] ADR-029 — `_node_mcp_trust` caps a node with a tool list to `node.tools ∩ allowlist` per server, and gives a node without one its servers' allowlists (`agent.py:172-208`); all 18 workflows' lists are inside the caps (extra check).
- [N/A] ADR-030 — m0029 is one nullable column (reviewed in 53-03).
- [VIOLATION — M1] ADR-031 / ADR-045 as narrowed by D21 — tools stay read-only, but engine `skill` commands are offered and sent raw.
- [OK] ADR-032 / L-016 — item 4.
- [OK] ADR-033 — copilot's mutating tools reach `ask` (item 3); no config, secret or registry tool added.
- [OK] ADR-034 — writes only in `fs_write_root` (`manager.py:295-296`, `client.py:345-363`); managed skills only.
- [N/A] ADR-035 – ADR-044, ADR-046 – ADR-050, ADR-053, ADR-054, ADR-056 – ADR-067, ADR-070 – ADR-079, ADR-081, ADR-084, ADR-085 — reached only through shared folders (`genesis/api`, `web/src/features`); none of their behaviour changed in this diff.
- [OK] ADR-051 — nodes still go through `AgentProvider` / `KiroAcpProvider` (`agents/kiro.py:13`).
- [OK] ADR-068 — `delete_file` is never projected; `story-implementation`'s write tools are unchanged (no delete).
- [OK] ADR-069 — skills are provisioned into `<cwd>/.kiro/skills` from managed sources only (`agent.py:111-149`, `context.py:76-109`).
- [OK] ADR-077 — nothing launches with `--trust-all-tools`.
- [OK] ADR-082 / ADR-083 — Phase 51 shell turns keep the inherited env (`agent.py:369`); risk (d) is closed by D6; (a)–(c) remain until Phase 52.

Lessons
- [OK] L-001 — the MCP env list shape is kept (`agent.py` builds `"env": []` lists; `mcp-allow` replay).
- [OK] L-002 — `kiro_node` builds the real options (`test_core_units.py:186-228`).
- [OK] L-011 / L-083 — fixtures recorded from real responses (item 5). The one gap is M1's catalog test, which uses a fixture without skills.
- [OK] L-017 — `@server/tool` form throughout; no trust-all.
- [OK] L-018 — SSE parsing unchanged; the contract test runs the real app's SSE.
- [OK] L-021 / L-023 — `save_tool_output` detection keyed on the blackboard server; engine meta steps are not recorded (`agent.py:392-411`).
- [OK] L-024 — skills come from the filesystem only (cwd or `skill://` resources).
- [OK] L-025 / L-027 — ruff pinned; all ruff gates green.
- [N/A] L-030 — a release concern (53-12); a web file changed in this phase, so the frontend job runs.
- [OK] L-041 — spec modes run with cwd = `fs_write_root` and the fs tools approved (`manager.py:283-296`).
- [OK] L-044 — every v3 method was spiked on the installed 2.37.1 (53-02), except the raw skill-command path (M1).
- [VIOLATION — M1] L-045 / L-046 — the human-confirm backstop holds, but an engine command is routed raw instead of being declined (D21).
- [OK] L-056 / L-057 — release-time checks (53-12); noted for the release agent.
- [OK] L-088 — the import gates have bypass and positive corpora (53-04 M1 fix).
- [OK] L-089 — gates run one per message here; the bundle was checked after the build had exited.
- [N/A this round] L-090 — the A7 width probe was not run (53-10's probe passed at 1280/1440/1920 in light and dark).
- [OK] L-092 — no new `tests/__init__.py` in workflow folders; `test_library_skills.py` is uniquely named.
- [OK] L-093 — the stopped turn is stored before `agent.result` is yielded (`manager.py:494-525`).
- [OK] L-094 — the `shadows_personal` removal reaches the backend, API, web types and fixtures (item 9 grep). The callers of `onPickSkill` were checked for M1.
- [OK] L-101 — the playwright-appian 0.3.1 skill tells the agent to stop on a version mismatch (`38f87fd`).
- [OK in code; live open] L-104 / L-108 — process-group close and stdin-EOF exit; the apwt reap runs after the release (D24).
- [OPEN] L-111 — no live acceptance this round; see "Live checks not run". The release must say plainly which rows are open.
- [OPEN] L-112 — the python:3.13 image run was not done (Docker down); it is required before the 53-12 release commit.
- [N/A] every other lesson in the three lists (L-003 – L-009, L-012 – L-015, L-019, L-020, L-022, L-026, L-028, L-029, L-031, L-033, L-034, L-039, L-042, L-043, L-047 – L-055, L-058 – L-087, L-091, L-095 – L-100, L-102, L-103, L-105 – L-107, L-109, L-110) — their areas appear only through shared folders; no code they govern changed.

Gates: every gate the three checks list is in §2, all green except the two NOT RUN rows.

## Findings

### Blockers
None.

### Majors
- M1 **Engine `skill` commands are offered in the `/` palette and sent raw, against D21. After a Stop, a raw send
  drops the D15 note** (`genesis/chat/manager.py:134-143`, `:410-416`, `:442-466`;
  `web/src/features/chat/ChatThread.tsx` `onPickSkill`).

  What the code does:
  - `engine_commands` drops only entries whose `_meta.kiro.type` is `custom-agent`. Every other entry the engine
    lists is offered by `catalog_commands`.
  - When such a command is typed, `_listed_command` makes `stream_turn` send it raw, with none of Genesis's prompt
    pieces.

  The problem:
  - Since 53-13 the engine lists every managed skill as a `skill`-type command: in spec-style modes through
    `resources`, and in read-only and copilot through the cwd.
  - On the recorded frame `packages/kiro-agent-sdk/tests/fixtures/v3/agent-resources-skills.jsonl` line 12,
    `catalog_commands(...)` returns `['/genesis-test-authoring', '/gam', '/appian-object-generation', '/clear',
    '/compact']` (run by the reviewer).
  - D21 says the palette offers only `/clear` and `/compact`, and engine commands are not sent. 53-07's ruling rested
    on "with the projected agent the engine lists only that agent, so in practice no engine command is offered"
    (53-07 As built, decision 2). That stopped being true once 53-13 listed the managed skills.
  - A typed `/gam draft …` therefore reaches the engine raw, on a command path whose trust was never measured.
  - The palette's Skills section uses the same path: `onPickSkill` sends `/${name}`.
  - D15 gap: after a Stop, the raw send omits `STOPPED_TURN_NOTE`. The reply is stored as an ordinary turn (no
    `meta.command`), so `_latest_turn_cancelled` (`manager.py:159-172`) returns False on the next turn and the note is
    lost for good. 53-02 measured exactly this carry-over.
  - Each skill is also listed twice in the palette: once as a command and once in the Skills section
    (`Composer.tsx:101-127`).
  - No test catches it. `test_the_catalog_on_the_real_client` uses the `available-commands` fixture, which holds
    custom agents only. `test_a_listed_command_is_sent_raw_and_an_unlisted_one_as_text` pins the raw path with an
    invented `usage` command.

  Fix (deletes code, and uses only a measured path):
  1. Make `catalog_commands` return `GENESIS_COMMANDS` only.
  2. Remove `_listed_command` and the raw branch, so every typed `/x` other than `/clear` / `/compact` is user text
     with the Genesis pieces.
  3. Make `onPickSkill` send a text instruction that names the skill (`Use the <id> skill.`). That form is the one
     53-13 R3 measured: "Use the gam skill …" loaded `gam` through `disclose_context`, approved by the D18 ladder
     under `auto_deny`, 0.10 credits.

  Regression tests:
  - the catalog over the `agent-resources-skills` frame equals `['/clear', '/compact']`;
  - `/gam x` after a stopped turn carries `STOPPED_TURN_NOTE`;
  - a palette skill pick sends the text form;
  - replace the `usage` test.

  The alternative is to keep `skill` commands raw: probe their trust first, amend D21, add the D15 note and dedupe
  the palette. That is more work and keeps an extra path.

  If skipped: the release ships a palette that contradicts D21, an unmeasured engine path in every chat mode, and a
  D15 gap.

### Minors
- m1 **Skills Update closes running chat turns, and its library fetch blocks the event loop**
  (`genesis/api/skills.py:101-117`, `manager.py:922-925`, `:1081-1084`).
  - What happens: 53-10 adds the Update button to `POST /skills/update`. The route calls `installer.update(...)`
    synchronously inside an `async def`, which means a GitLab fetch on the event loop. It then calls
    `reload_all_skill_clients` → `aclose_all`, which closes every live client, including one whose turn holds its
    lock.
  - Concrete case: a chat turn is streaming in one tab and the user clicks Update on `gam` in Settings. That turn
    ends with `process_died` ("kiro-cli stopped unexpectedly"), is stored as not cancelled (so no D15 note), and keeps
    no metered usage (`provenance: unavailable`). While the fetch runs, every SSE stream and chat turn on that server
    stalls.
  - Both behaviours predate this phase (`install` and `update` did the same at v0.81.0). 53-10 makes Update one
    click away.
  - Fix:
    - Run the installer call with `await asyncio.to_thread(...)` (also in `install_skill`).
    - In `aclose_all` / `reload_all_skill_clients`, skip sessions whose `_lock` is held and set a `_reload_after`
      flag that `stream_turn`'s `finally` honours (drop the client after the turn).
    - Regression test: an update during a fake streaming turn leaves that turn's stored usage and status intact.

### Nits
- n1 **Stale v2 comments.** In each, name the v3 source (`available_commands_update`, `configOptions`,
  `session_info_update` `turn_completion`). The architecture docs from `7d7cd2d` are already in 53-12's write-back.
  - `packages/kiro-agent-sdk/src/kiro_agent_sdk/messages.py:48-56`: `SystemInit` names
    `_kiro.dev/commands/available` and `session/new.models`.
  - `messages.py:131`: `ResultMessage` usage "from `_kiro.dev/metadata`".
  - `packages/genesis-core/genesis_core/nodes/agent.py:439-442`: credits "from `_kiro.dev/metadata`", "older kiro-cli".
  - `web/src/types/chat.ts:24`: `SlashCommand` "from `_kiro.dev/commands/available`".

## Live checks not run, and why

All of §3 was not run: **the Appian environments are unavailable, and the operator asked for a code-level review
instead (2026-11-14).** No fleet instance was restarted or changed, nothing was installed, and no workflow, chat turn
or browser session was started on Genesis. The only live process was the reviewer's zero-credit kiro-cli EOF probe,
under a `/tmp` home.

| Row | Needs Appian? | Status |
|---|---|---|
| A1 — 12 agent-node workflows on v3 (15 minus Phase 51's three, D24), incl. `story-implementation` on Dev | yes (Dev / jira / jarvis / appian-atlas) | not run. Before it: install `appian` on the chosen instance (not installed on `main`). jira, jarvis and appian-atlas are configured there. |
| A2 — the eight chat modes | partly (`appian-dev` reads are best effort; genesis-kb is local) | not run |
| A3 — model picker, palette, Compact, Clear, Stop × 3 (D15) incl. across a `serve` restart, steering, resume by load | no | not run. It needs a `genesis serve` restart (D20: ask first) |
| A3b — mode change resuming under another agent; steers during a tool, unread, at turn end; the browser's Stop order; skill found after `session/load`; model-fallback frame; `/system/kiro` with kiro-cli only in `~/.local/bin`; a Feature Spec turn naming a managed skill (D23) | no | not run. M1's fix changes what the skill-naming turn sends |
| A4 — isolation from `~/.kiro` MCP servers and skills | no (`story-implementation` part: yes) | not run |
| A5 — failing MCP server, kiro-cli below the minimum, an unverified newer kiro-cli | no | not run |
| A6 — no stray kiro-cli / MCP processes | no | not run (code and the EOF probe above only) |
| A7 — width probe at 1280/1440/1920, light and dark | no | not run (53-10's probe passed on `b9ba5d9`) |
| A8 — credits in the v2 range | yes (A1's runs) | not run |
| A9 — blackboard under a whole-server entry; permission round trips per turn; a read-only refusal during a pending request | (a) yes (a Phase 51 node, D24); (b)(c) no | not run |
| A1/A6 for `story-verification`, `action-capture`, `setup-composer`, and the apwt reap | QA | after the release (D24) |

**Recommendation (L-111):** A3, A3b, A4 (chat part), A5, A6 and A7 do not need Appian. Run them on an isolated
`genesis serve` before the release even while the environments are down, after M1 is fixed. Run A1, A2, A8 and A9(a)
when Dev is back. If the release goes first, its notes must say which rows are open.

## Not checked (code-level, needs a live run or a probe)

- **A steer whose `_session/steer` answer arrives after the prompt's answer.** `ChatSession.steer` (`manager.py:644-665`)
  stores the message and queues `user.steer` on a turn queue that no longer has a reader. 53-02 W7b measured a steer
  queued before the answer (a second engine turn in the same prompt). It did not measure what the engine does with a
  steer queued after the answer: a background turn whose credits Genesis would not record, or a steer held for the
  next prompt. That is A3b's "steer arriving as the turn ends".
- **`session/load` after a mode change that also changes the cwd** (read-only `state_dir` → spec sandbox) (A3b).
- **The tool-stall limit (300 s, `timeouts.py:24`) against long single MCP calls** in `story-implementation`'s
  write tools and jarvis's `review_object`. W14's longest measured MCP call was 18.7 s (A1).
- **Retention of the chat home** (`~/.genesis/kiro-home/chat/logs`, about 67 KB per client start, nothing prunes it).
  Not a finding until it is known whether kiro-cli rotates its logs under a custom `KIRO_HOME`.
- **The clean-install CI job and the `python:3.13` image run** (§2).

## Credits spent by this review

**0.** The one live call was the stdin-EOF probe (`initialize` + `session/new`, no prompt, no MCP servers).

## Verdict: NEEDS_CHANGES

Fix M1 with its regression tests; m1 is recommended in the same pass. Then re-run the chat suite and the web suite,
and run the live rows that need no Appian (A3, A3b, A4 chat part, A5, A6, A7) before 53-12. A1, A2, A8 and A9(a) stay
open until the Appian environments return, and the release must say so (L-111).
