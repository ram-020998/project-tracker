# 53-11 — Review, hardening and live acceptance

> **Status:** SPEC-DRAFTED 2026-11-03. Repos: genesis, genesis-workflows. Parent: `specs/phase-53-kiro-sdk-v3.md`. Run
> by **genesis-review** (read-only on code) after 53-02..53-10 are BUILT; report in
> `specs/phase-53-kiro-sdk-v3/reviews/53-11-review.md` with SHIP / NEEDS_CHANGES. Findings are fixed by genesis-dev before
> release; each fix gets a regression test.

## 1. Independent review (file:line evidence for each; plus `genesis-ctx check --since <phase base>` per repo)

1. **v3 only** (D5): no `--trust-tools`, `--trust-all-tools`, `--agent-engine v2`, `_kiro.dev/metadata`,
   `_kiro.dev/commands/*`, `_kiro.dev/{compaction,clear}/status`, `session/set_model`, `execute_command`, or slash commands
   sent to make the engine act, anywhere in genesis, genesis-core, the SDK or genesis-workflows.
2. **Kiro home** (D6): every Kiro process has an explicit Genesis-owned `KIRO_HOME`; the SDK refuses to start without one;
   nothing reads `~/.kiro` for agents, MCP, skills or steering (grep `Path.home() / ".kiro"` and `~/.kiro`).
3. **Trust** (D9, F2, 53-05): the projection never emits `all`/`builtin`/`filesystem`, a server glob, or `delete_file`;
   `tools` is always explicit; activation is verified and fails closed; identity comes only from `_meta`; the backstop
   denies anything outside the policy; read-only chat has no built-ins and no mutating tool; copilot's mutating tools
   reach the confirm card (ADR-031, ADR-033).
4. **Credits** (ADR-032): every `credits` value comes from a `turn_completion` credit entry; cancelled / timed-out turns
   per 53-02 W5; `provenance` honest; no number invented.
5. **Contracts** (53-09): the web's shapes unchanged except the listed additions; fixtures regenerated from real
   responses (L-011, L-083).
6. **Process hygiene** (F12): close leaves no kiro-cli or MCP process (checked live, §3).
7. **Import surface** (F13): the gate test exists and passes; no private SDK import.
8. **Secrets / tokens:** no access token, refresh token or secret value in logs, events, evidence or fixtures (F9).
9. **Skills** (D7, D8): no `~/.kiro/skills` fallback; `shadows_personal` gone; `appian` in the library.

## 2. Gates

SDK (`cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q`, `ruff check src tests`), genesis-core
(pytest, ruff), genesis (pytest, ruff), web (`npm run lint && npm run typecheck && npm test`, `npm run build` +
committed `web/static/`), genesis-workflows (`validate_library`, `validate_skills`, pytest), clean-install CI job.

## 3. Live acceptance (local `genesis serve` on the release candidate, kiro-cli at the verified minimum, the user's real
login and apps)

| # | Check | Pass |
|---|---|---|
| A1 | **Every genesis-workflows agent node runs on v3** (D5, narrowed by D24): run each of the 15 agent-node workflows in 53-01 §9.2 once (or a fixture input that reaches each agent node) **except Phase 51's `story-verification`, `action-capture` and `setup-composer`**, which run after the release (D24). This includes the Implementation lane's `story-implementation` against Dev, with `appian` installed from the library. Prerequisites: the `jira`, `jarvis` and `appian-atlas` servers configured in Genesis, since `~/.kiro` no longer supplies them (D6). Before the run, re-diff genesis-workflows against the version the specs were checked at (v0.25.0) for Phase 51 v0.81.x patches | each run completes or reaches its designed gate; every agent turn has `provenance: metered` credits; run detail shows the conversation; no Phase 51 turn ends on a silent or tool-stall limit |
| A2 | Each of the eight chat modes: read-only, copilot (start + supervise a run; confirm card), `feature_spec`, `ux_design`, `technical_design`, `feature_breakdown`, `story_design`, `test_design` | answers; read-only refuses a mutating tool with the notice; copilot's mutation waits for confirm; each spec-style mode writes only inside its sandbox |
| A3 | Chat surface: model picker list + model at start; `/` palette; Compact; Clear; Stop then a fast next turn (no cold start); **Stop before the answer (D15):** in 3 tries, stop a request with a visible side effect (a tool call) about 1 s after sending, then send an unrelated message; repeat once with a `genesis serve` restart between the Stop and the next message; steering (delivered, and one unread re-sent after the turn); restart `genesis serve` and continue a chat (resume by load) | all behave as specified in 53-07 / 53-10; the stopped request is never carried out (any carry-over is a finding that reopens D15) |
| A3b | Chat paths 53-07 could not run live (its As built, 53-11 item): a mode change that resumes under a different agent; a steer during a tool call, an unread steer, and a steer arriving as the turn ends (one Genesis turn, summed credits); the browser's Stop through a real `genesis serve` (53-10 order: `/cancel` first, the stream kept open up to 10 s; the stopped turn's credits stored and the Stopped label shown live; leftover steers return to the composer); a skill installed meanwhile found after a `session/load`; the first model-fallback frame if one occurs; `/system/kiro` on a machine where kiro-cli is only in `~/.local/bin` (`installed: true` beside its version, 53-09); a steer queued just after the turn's answer; resuming a chat after a mode change that also moves its working folder (sandbox ↔ `state_dir`); **one Feature Spec turn through `genesis serve` that names a managed skill** (D23, 53-13: the skill loads through `disclose_context` in a sandboxed spec-mode session, and read-only chat lists it once) | each behaves as 53-07 specifies; a fallback frame, if seen, is recorded as a fixture |
| A4 | Isolation: with a server in `~/.kiro/settings/mcp.json` and a skill only in `~/.kiro/skills`, neither appears in chat or a workflow turn; `story-implementation` gets `appian` from the library | as stated |
| A5 | Failure paths: an MCP server that fails to start (chat notice; node fails before the prompt, no credits); kiro-cli below the minimum (preflight + refusal message); an unverified newer kiro-cli (warning only) | as stated |
| A6 | Process hygiene: after A1–A3, no stray `kiro-cli`, `kiro-cli-chat` or MCP server processes (`ps`). (The reap of a cancelled `story-verification` run's `apwt` daemons and Chromium runs after the release with the Phase 51 workflows, D24; 53-02 W16 measured it.) | none |
| A7 | Web: real-browser check of the steered bubble, the "answered by" text, the MCP notice card and the Skills Update action at 1280 / 1440 / 1920 px, light and dark (L-090) | no overflow or clipping |
| A9 | Open from 53-05's As built, checked on A1–A3's runs: (a) a node with no tool list calls a tool under its whole-server `@blackboard` entry (`save_tool_output` in a Phase 51 node); (b) whether the built-in `match: ["**"]` rules auto-approve, or every built-in call asks and the ladder approves (count the `session/request_permission` frames per turn); (c) a read-only chat refusal while another permission request is pending, and whether a notice at turn end starts a second metered engine turn (credits stay summed per prompt) | (a) works; (b) recorded either way, a finding only if the extra round trips slow turns visibly; (c) the refusal reaches the turn and nothing hangs |
| A8 | Credits sanity: A1's per-node credits in the same range as the same workflow's last v2 runs (± the `tool_load` effect measured in 53-02 W9) | no unexplained jump |

## 4. Fix pass after round 1 (review `reviews/53-11-review.md`, NEEDS_CHANGES; genesis-dev, one pass)

1. **M1 (D25): skills are not engine commands in chat.**
   - The engine command list is filtered to `/clear` and `/compact` only (`engine_commands`; D21). Skill-type and
     agent-type engine commands are never offered and never sent raw.
   - The palette's skill rows keep coming from Genesis's skill store (`Composer.tsx:123`), so each skill shows once.
     Picking one sends the prompt `Use the <id> skill.` through the normal prompt path, with any text the user typed
     after it.
   - A typed `/<id> …` where `<id>` is an installed managed skill is rewritten the same way before it is sent. No
     prompt that starts with `/` reaches the engine except `/clear` and `/compact`, which map to the 53-07 §5 methods.
   - The D15 note still applies on every one of these paths after a Stop.
   - Tests: the recorded 53-13 frame no longer yields skill commands; the palette lists each skill once; a pick and a
     typed `/gam x` send `Use the gam skill. x`; after a Stop that prompt starts with the note; no raw `/`-prompt
     reaches the fake engine.
2. **m1: Skills Update does not kill a running turn or block the server.**
   - The library fetch of `POST /skills/install` and `/skills/update` runs off the event loop (`asyncio.to_thread`,
     L-026).
   - The reload closes only idle chat clients now. A client with a turn in progress is marked and closed when that
     turn ends, so it re-discovers skills on its next turn.
   - Tests: an Update during a streaming turn lets the turn finish with its credits; another session's stream keeps
     flowing while the fetch runs (a slow fake fetch).
3. **n1:** fix the four v2-era comments.

Then genesis-review re-reviews the delta (round 2).

## 5. Live rows before and after the release (D24, D26)

| When | Rows |
|---|---|
| **Before 53-12**, on a separate `genesis serve` (no Appian needed) | A1 for `hello-appian`, `generate-business-map`, `memory-consolidation`, `memory-maintenance`; A3; A3b; A4's chat part; A5; A6; A7 |
| **After the release, when Dev is up** | A1 for the other eight workflows (`story-implementation` only with the user's go-ahead, ADR-068); A2's remaining modes; A8; A9(a) |
| **After the release, with Phase 51's acceptance** (D24) | `story-verification`, `action-capture`, `setup-composer`; the cancelled-run `apwt` reap check |

The 53-11 verdict covers the review, the gates and the before-release rows. The later rows are recorded in this As
built when they run.

## As built

_To be filled by genesis-review (report path, verdict) and genesis-dev (fixes)._

### Fix pass after round 1 (genesis-dev, 2026-11-14; §4)

**Commits** (genesis, local, on master after `b9ba5d9`; not pushed, not tagged; the fleet was not restarted, D20):
`483170e` source + tests (M1, m1, n1); `dd27c46` `web/static` only. A fresh `npm run build` after `dd27c46` leaves
`git status --short --untracked-files=all` empty.

**Changed**
- M1 (D25), `genesis/chat/manager.py`: `engine_commands` keeps only entries named `clear` / `compact`, so the 53-13
  `skill`-type commands and every agent command are never offered (`catalog_commands` over the recorded 53-13 frame
  is `['/clear', '/compact']`). `_listed_command`, the raw-prompt branch and `_command_type` are removed. A typed
  `/<id> …` where `<id>` is an installed managed skill (`SkillStore.exists`) is sent as `Use the <id> skill. …`
  (`skill_prompt`); any other text starting with `/` goes as `User: /…`, so no prompt that starts with `/` reaches the
  engine. `/clear` and `/compact` still map to the 53-07 §5 methods. Every turn now takes Genesis's pieces, so the D15
  note applies on every path, and the post-turn hook runs on every non-command turn.
- M1, web: `Composer.tsx` skill rows come only from the skill store; an exact `/<id> <text>` keeps that skill's row,
  and a pick passes the text after the id. `ChatThread.tsx` `onPickSkill` sends `Use the <id> skill.` plus that
  text through the normal send. The Commands rows are the backend's list, now only `/clear` and `/compact`.
- m1, `genesis/api/skills.py`: `POST /skills/install` and `/skills/update` run the installer with
  `asyncio.to_thread` (L-026), under one `asyncio.Lock` that `DELETE /skills/{id}` also takes for its lockfile write.
  `ChatManager.reload_all_skill_clients` and `reload_skills` close an idle client at once. A client whose turn holds
  the lock is marked (`_close_after_turn`) and closed by `ChatSession._turn_scope` as the turn ends. The scope also
  wraps the Clear and Compact buttons (`run_slash_command`). `aclose_all` (shutdown) is unchanged.
- n1: `SystemInit` and `ResultMessage` (`messages.py`), `kiro_node`'s credit comment (`agent.py`) and `SlashCommand`
  (`web/src/types/chat.ts`) now name the v3 sources (`configOptions`, `available_commands_update`,
  `session_info_update` `turn_completion`).

**Tests, with fail-first evidence** (each new test was run on the `b9ba5d9` code before the fix):

| Test | On `b9ba5d9` |
|---|---|
| `test_chat_manager.py::test_the_recorded_53_13_frame_yields_no_skill_commands` | failed: `['/genesis-test-authoring', '/gam', '/appian-object-generation', '/clear', '/compact']` |
| `::test_a_session_listing_the_managed_skills_offers_no_skill_command` | failed: the same list from `/chat/commands` |
| `::test_catalog_commands_offers_only_clear_and_compact` (replaces the `usage` mapping test) | failed: `/usage` offered |
| `::test_a_typed_skill_command_is_sent_as_use_the_skill` (`/gam x`, `/gam`, the pick text) | failed: prompts `['/gam x', '/gam', …]` |
| `::test_after_a_stop_a_skill_prompt_starts_with_the_note[/gam x]` | failed: the prompt was `'/gam x'`, no note |
| `::test_after_a_stop_a_skill_prompt_starts_with_the_note[Use the gam skill. x]` | passed (the pick's text was already a normal prompt; it pins the pick path) |
| `::test_no_raw_slash_prompt_reaches_the_engine` (skill, engine skill, agent, unknown, `/clear`, `/compact`) | failed: `['/gam x', '/gam y', '/genesis-test-authoring', '/general-task-execution do it', …]` |
| `::test_a_slash_word_that_is_no_skill_is_the_users_text_with_genesis_pieces` (replaces the raw `usage` test) | failed: `'/general-task-execution do it'` sent raw |
| `test_skills_api.py::test_a_reload_during_a_turn_lets_it_finish_with_its_credits_then_closes_the_client` | failed: `assert not busy_client.closed` (the reload closed the running turn's client) |
| `::test_an_update_with_a_slow_library_fetch_keeps_another_chat_streaming` (0.6 s blocking fake fetch) | failed: `0 chunks arrived during the fetch` |
| `test_phase53_api_contract.py::test_commands_when_the_engine_lists_the_managed_skills` | recorded on the base, the fixture held the three skill commands; re-recorded after the fix: `/clear`, `/compact` |
| web `skills-chat.test.tsx` "picking a skill sends 'Use the <id> skill.'" | failed: `expected '/gam' to be 'Use the gam skill.'` |
| web "picking a skill with text after its id …" (`/gam x` → `Use the gam skill. x`) | failed: no GAM row for `/gam x` |
| web "lists each skill once when the engine lists the managed skills" (reads `fixtures/chat/commands-skills-listed.json`) | failed with the base-recorded fixture: 2 gam rows (`/gam` command and the GAM skill) |

Also changed: `test_chat_api.py::test_an_unlisted_slash_text_is_sent_as_text` pinned the raw `/help` prompt; it now
expects `User: /help`. `_StubLive` in `test_skills_api.py` gained the real session's `_lock`.

**Gates** (after the fix, each its own step): genesis `pytest` **1943 passed**, run with
`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false` for the 3 testexec tests that make
git commits (as in 53-09/53-10); `ruff check genesis` clean, plus the changed test files (`ruff check tests` still
reports 24 errors in files this pass did not touch). The SDK has **302** tests and genesis-core **109**, both
passing; only comments changed there, and both ruff scopes are clean. Web: `npm run lint` 0 errors (20 warnings,
none in chat), `npm run typecheck` clean, `npm test` **764 passed** (66 files), `npm run build`. The commits are
signed as usual; signing was turned off only for the test run.

**Decisions**
1. The pick text follows §4 literally: the web builds `Use the <id> skill. <text>`. The backend's `skill_prompt`
   builds the same string for a typed `/<id> …`. That gives the string two homes, and a test pins the exact text in
   each.
2. The stored user message is what the person typed (`/gam x`). Only the prompt is rewritten, the same way the D15
   note and the preamble are never stored.
3. Fail closed for an unknown `/x`: with no other pieces it goes as `User: /x`, the same form a prompt with pieces
   already uses.
4. Taking the fetch off the loop also removes the serialization the blocking call gave by accident. Two installs, or
   an install and a delete, could then interleave their lockfile read-modify-write, so one lock covers install,
   update and delete.
5. The same rule applies to `reload_skills` (one session) and to Clear and Compact, so no reload path kills a
   running turn.
6. `FakeV3Client.commands_fixture` (default `available-commands`) lets a test use the 53-13 command list. The old
   fake listed custom agents only, which is why no test caught M1 (L-011).

**Flag for round 2 (not in §4; nothing changed):** `POST /chat/sessions/{id}/steer` passes a steer text starting
with `/` to `_session/steer` unchanged. A steer is not a prompt, and the web never steers a `/` text (Composer
`commandWaits`). How the engine treats such a steer was never measured.

**Lesson candidates:** (a) When a later sub-spec changes what the engine lists (53-13 added `skill`-type commands),
point the fakes at the new recording. A stub that still serves the older shapes hides the change (extends L-011).
(b) Taking a blocking call off the event loop removes the serialization it gave by accident, so a shared file it
wrote needs its own lock.

**Code-map changes:** `genesis/chat/manager.py` adds `skill_prompt` (public),
`ChatSession._engine_text`, `ChatSession._turn_scope` / `_close_after_turn` and `ChatManager._reload_live`, and
drops `_listed_command` and `_command_type`. `genesis/api/skills.py` adds a library lock, and the install and update
routes now run the installer in a thread.

### Round 2 fixes (genesis-dev, 2026-11-14; review round 2 NEEDS_CHANGES)

**Commit:** `61ec063` (genesis, local, signed; no web change, so no `web/static` commit).

- **B1:** a message of only `/` crashed `_engine_text`, because the split of the empty rest unpacked nothing. The
  user message was already stored by then. Now the split result is checked first, and the message goes as `User: /`.
  Test: `"/"` was added to `test_no_raw_slash_prompt_reaches_the_engine`, and every input must now end in
  `agent.result`. On `dd27c46` it failed with `ValueError: not enough values to unpack (expected at least 1, got 0)`
  at `manager.py:433`.
- **m1 (the flagged steer path):** `ChatSession.steer` now sends `_no_slash(text)`, the same D25 rule a prompt
  without pieces gets. A managed skill id becomes `Use the <id> skill. …`, and any other leading `/` is prefixed
  `User: `. The stored steer is what was typed. Test: `test_a_steer_never_reaches_the_engine_starting_with_a_slash`.
  On `dd27c46` the engine was sent `['/gam x', '/general-task-execution do it', 'plain']`.
- **n1:** `POST /skills` (author, `replace`) takes `library_lock`. Test:
  `test_authoring_a_skill_waits_for_a_running_library_update`. On `dd27c46` the author finished 0.42 s before the
  update it should have waited for.
- **n2** is not taken. The reviewer left it to the spec agent: the web could send `/<id> <text>` and leave the rewrite
  to the backend, so the string has one home. §4 words the pick as sending `Use the <id> skill.`, so this stays as
  built until the spec agent rules.

**Gates:** genesis `pytest` **1945 passed**, with the same signing override for the testexec tests. The chat, skills
and contract subset has 101 tests, all passing. `ruff check genesis` and the changed test files are clean.

**Review:** round 2 (on `dd27c46`) NEEDS_CHANGES (B1, m1, n1 above). Round 3 (on `61ec063`) **SHIP**: no findings,
and the reviewer re-ran the three new tests against the `dd27c46` source, where all three fail. Both rounds are in
`reviews/53-11-review.md`. n2 stays open for the spec agent. This verdict does not cover the §5 live rows, which
genesis-review runs next on a separate `genesis serve` (L-111).

### §5 live rows before the release (genesis-review, 2026-11-14/15)

Run on a separate `genesis serve` from the dev checkout at genesis `61ec063`, with kiro-cli 2.37.1. State
`/tmp/genesis-53-11/state` (a `.backup` copy of the fleet main's DB, with its schedules off), port 8770 (reports
8870). The fleet was not touched (D20). Report: `reviews/53-11-review.md` § "Live rows (before release)". Evidence and
driver scripts: `reviews/53-11-live/`.

| Row | Result | Metered credits |
|---|---|---|
| A1 `hello-appian`, `generate-business-map`, `memory-consolidation`, `memory-maintenance` | PASS: all done; 7 agent turns, all `metered`; built-in tool ids are registered ids; the turn explorer shows each conversation | 4.7591 |
| A3 (Stop × 3 + once across a serve restart, D15; models, model at start, Compact, Clear, palette) | PASS: no carry-over in 4 tries plus a fifth after a finished tool round; resume by `session/load` | 0.2225 |
| A3b (steer during a tool, late, after the answer, unread; browser Stop; mode change moving the cwd; Feature Spec skill turn; skill found after load; `~/.local/bin`) | PASS; no model-fallback frame occurred | 1.1938 |
| A4 chat part (`~/.kiro` MCP servers and skill) | PASS: neither reaches chat; the `~/.kiro` skill is a copy of a library skill, so it was checked by removing that skill from the instance | 0.2263 |
| A5 (failing MCP server notice; kiro-cli 2.36.0 fake; 2.38.0 fake) | PASS: notice once; refusal `kiro_too_old` with no credits; newer → warning only | 0.0827 |
| A6 (`ps -ww` after the runs and after each serve stop) | PASS: no stray kiro-cli, kiro-cli-chat, engine or MCP process | 0 |
| A7 (1280/1440/1920 × light/dark) | PASS: 24 live checks plus 12/12 on the 53-10 mock probe ("answered by") | 0.0846 |

Total **6.569** credits (chat 1.8103, runs 4.7591).
- **python:3.13 image (L-112): run.** SDK 302, core 109 and genesis 1881 passed; ruff is clean everywhere. 3 genesis
  tests and 1 parser test fail, identically on `62537c2`, so they are not Phase 53's. One of them is clock-dependent
  (finding m1: it fails 00:00–02:00 IST, which is 18:30–20:30 UTC). The other three look aarch64-only; an emulated
  amd64 re-run hung and did not complete.
- **Findings for genesis-dev:** m1 (pre-existing Phase 51 test; fix it before 53-12 or tag outside that window), n1
  (the MCP notice names the server twice), n2 (the too-old message repeats the version).
- **Verdict:** before-release rows PASS. **53-11 SHIP**; 53-12 is next.
- **Open until after the release (D26):** A1 for the other 8 workflows, A2's remaining modes, A8, A9(a), the Phase 51
  workflows and the `apwt` reap.

## Context manifest

```toml
areas    = ["sdk-acp", "chat", "core-engine", "workflows-library", "security"]
adrs     = ["ADR-004", "ADR-011", "ADR-020", "ADR-029", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-045", "ADR-051", "ADR-069", "ADR-082", "ADR-083"]
lessons  = ["L-011", "L-016", "L-017", "L-041", "L-083", "L-088", "L-089", "L-090", "L-093", "L-101", "L-104", "L-108", "L-111"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3.md", "tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md"]
code     = ["genesis/packages/kiro-agent-sdk/**", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/chat/**", "genesis/genesis/api/chat.py", "genesis/web/src/features/chat/**"]
upstream = ["53-02", "53-03", "53-04", "53-05", "53-06", "53-07", "53-08", "53-09", "53-10"]
```
