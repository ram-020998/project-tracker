# Review 53-07 — genesis d5a6a4e → b46c877 (genesis-review, 2026-11-12)

What this change does: chat in all eight modes now runs on the v3 SDK client. Each session gets the chat `KIRO_HOME`, one
`TrustPolicy` built from its mode profile, and the mode's steering as the custom agent's prompt. A chat resumes with
`session/load` and falls back to `session/new` plus the preamble. The change also adds steering (`POST …/steer`,
`user.steer`, `unread_steers`), a Stop that keeps the client (`session/cancel`, `turn_status: cancelled`, then
`STOPPED_TURN_NOTE` once on the next prompt) and Clear / Compact / delete / reap on the v3 methods. The v2 client and the
`Legacy*` aliases are deleted from the SDK. The b46c877 fix makes a cancel the engine answers with -32603 end the turn
`cancelled`, and strips kiro-cli's `[STEERING steer-…]` ack from the stored answer.

Both commits exist (`git rev-parse --short`: d5a6a4e, 8139cd2, b46c877; b46c877 is HEAD, the tree is clean). I ran
`genesis-ctx check --since d5a6a4e --repo genesis` (44 files; areas api, chat, config-secrets, release-ci, sdk-acp,
security) and answer every line it listed below. genesis-workflows: `git grep` for the removed names and for
`LegacyKiro|_v3client|extra_trust` finds nothing.

## Checklist

### ADRs
- [OK] ADR-001 — chat does not orchestrate. The change touches the chat turn only, with no graph or run-control code
  added. Copilot still operates runs only through the confirm-gated control tools.
- [OK] ADR-002 — narrow Kiro turns over ACP via `kiro-agent-sdk`: `_make_client` → `KiroACPClient(options)`
  (`chat/manager.py:62-66`). MCP is sent per session (`mcp_servers=servers`, `manager.py:285`).
- [OK] ADR-004 — MCP per session. `build_chat_mcp` keeps choosing the servers, and the projected agent has
  `includeMcpJson: False` (`test_every_mode_gets_its_trust_policy_and_never_a_shell`, `test_chat_manager.py:147`).
- [N/A] ADR-005 — no registry change. `settings.py` only adds `chat_kiro_home`.
- [OK] ADR-010 — events and stored meta stay small: `turn_status`, `kind: steer`, `message_seq` and `unread_steers` are
  ints or short strings (`manager.py:477-479`, `:613-617`).
- [N/A] ADR-011 — no workflow agent node changed (chat is not a graph node).
- [OK] ADR-012 — chat stays in-process as before (module docstring `manager.py:3-5`). It imports no workflow Python.
- [N/A] ADR-013 — no config UI change.
- [OK] ADR-019 — `CORE_MAJOR` untouched. The SDK surface change is v3-only by D5, pinned by `test_public_surface.py`.
- [OK] ADR-020 — the user's `~/.kiro` is not touched. `KIRO_HOME = settings.chat_kiro_home` (`settings.py:131-136`,
  `manager.py:282-284`), and the catalog probe and delete client use the same home (`manager.py:768`, `:982`).
  `includeMcpJson: False` is asserted.
- [N/A] ADR-021 — no workflow gates.
- [N/A] ADR-022 — no run artifacts.
- [OK] ADR-023 — still FastAPI embedding. One new route under the existing router (`api/chat.py:273-289`).
- [OK] ADR-026 — no new network surface. The route sits on the loopback app.
- [N/A] ADR-027 / ADR-055 — the web change is a comment only (`Composer.tsx`, 1 line). `vite build` output is identical to
  `web/static`.
- [OK] ADR-028 — `/api/chat/sessions/{id}/steer` is under `/api` (`register_chat_routes(api…)`).
- [OK] ADR-029 — the trust cap is unchanged in kind: read tools come from `build_chat_mcp` (curated allowlist for
  `appian-dev`), namespaced `@server/tool` (`mcp.py` docstring; `trust_policy`, `mode_profile.py:252-268`).
- [N/A] ADR-030 — no schema change (meta and usage go in existing JSON columns).
- [OK] ADR-031 — fail-closed in every mode. `read_only` and the six spec-style modes use `mode=auto_deny`. Only read
  tools and, in the spec modes, `fs_read`/`fs_write` are listed and approved. No shell is ever listed
  (`test_every_mode_gets_its_trust_policy_and_never_a_shell`, all 8 `PROFILES`, asserts `execute_bash`/`delete_file`
  absent). The catalog probe and delete client use the empty `TrustPolicy()` and `allow_fs_write=False`. Custom-agent
  commands are neither offered nor sent raw (`engine_commands`, `manager.py:127-138`).
- [VIOLATION → M1] ADR-032 — real metered credits per turn. A normal turn, a load (no replay yielded:
  `test_resume_by_load_sends_no_preamble_and_stores_nothing_replayed`) and a Stop through `POST /cancel` store their
  usage correctly. **The Stop the web actually performs (abort the SSE, then POST /cancel) drops the stopped turn's
  metered usage**: see M1.
- [OK] ADR-033 — copilot's `start_run`/`respond_to_gate`/`cancel_run` are listed but never approved, so they reach `ask`
  and the confirm bridge (`chat_confirm_tools`, `mcp.py:92-96`; asserted per mode, `test_chat_manager.py:158-161`;
  live: start_run confirm card denied, nothing started, `live-modes.json`). Stop resolves pending permissions as denied
  (`test_stop_resolves_a_pending_permission_as_denied`). No config, secret or deploy tool is added.
- [OK] ADR-034 — writes go only to the per-session sandbox (`fs_write_root=skill_out`, `manager.py:288-289`; asserted
  `opts.fs_write_root.endswith(rec.id)`). Skills still come from cwd (D7).
- [N/A] ADR-035, 036, 037, 038, 040, 041, 043, 046, 047, 048, 049, 050, 059, 060, 061, 062, 063, 065, 068, 071, 073, 074,
  081, 082, 084, 085 — not touched (no KB, document, lifecycle, collab, test-execution, report or registry code changed).
- [OK] ADR-042 — spec authoring stays conversational in chat. The spec modes keep their sandboxed file tools (live:
  `feature_spec` wrote `spec.html`).
- [OK] ADR-045 — mirrors the CLI surface within ADR-031. Model selection goes through `options.model` →
  `set_config_option` (`client.py:160-161`), compaction through `client.compact()`, and images through `_blocks`. The
  slash palette shows the engine's non-custom-agent commands plus Genesis `/clear` and `/compact`. Ruling on
  deviation (3): OK, because v3 has no prompt-path clear/compact (53-01 P12) and the buttons already used these.
- [OK] ADR-051 — the workflow turn path is not touched (chat is not a workflow node).
- [OK] ADR-053 — memory is unchanged. `_MEMORY_HINT` and the memory MCP stay in the mode steering and server list.
- [N/A] ADR-069 — workflow-node skills not touched.
- [OK] ADR-075 / ADR-076 — the feature_spec post-turn clause hook still runs after every non-command turn
  (`manager.py:484-485`). The CR flow is unchanged.
- [OK] ADR-077 — no agent run with `--trust-all-tools`. Spike scripts use the SDK, not the CLI flag.
- [OK] ADR-080 — one repo and one version. The SDK stays under `packages/` with no new internal dependency entry.
- [OK] ADR-083 — browser agents not touched. The 51-03 harness only gets a header comment.

### Lessons
- [OK] L-001 — the MCP env shape comes from `build_chat_mcp` / `_control_entry` (`"env": []` list), unchanged.
- [N/A] L-002 — `kiro_node` not touched.
- [OK] L-003 — the chat SSE ends on `agent.result`. The run bus is not touched.
- [OK] L-004 — the data plane stays SQLite.
- [OK] L-007 — the transcript fold is unchanged. New events (`session.notice`, `user.steer`) are flat `{type, seq, …}`
  and pass through `chatEventToRunEvent` (`web/src/features/chat/conversation.ts:9-12`). Their rendering is 53-10.
- [OK] L-010 — the new route is under `/api`.
- [N/A] L-012, L-019, L-023, L-028, L-029, L-031, L-039, L-048, L-049, L-053, L-054, L-068, L-070, L-073, L-081, L-086,
  L-105 — areas not touched by this diff.
- [OK] L-016 — credits are never estimated (no pricing code). The loss in M1 is an omission, not an estimate.
- [OK] L-017 — fail-closed, namespaced allowlists (`@genesis-kb/…`, `@genesis/…`, `@genesis-control/…`), and never
  trust-all.
- [OK] L-018 — SSE framing is unchanged (`EventSourceResponse`). API tests read via `iter_text`.
- [N/A] L-021 — no change to tool-output handling in chat.
- [OK] L-024 — skills still come from the filesystem (cwd `.kiro/skills`). `reload_skills` closes the client, and the
  next start uses `session/load` in a new process.
- [OK] L-025 / L-027 — ruff is pinned. `ruff check genesis` and SDK `ruff check src tests` are clean.
- [N/A] L-030 — the web diff is comment-only, and the bundle is identical.
- [OK] L-041 — spec modes run with cwd = fs_write_root = skill-output/<id> and fs tools approved
  (`manager.py:279-281`; asserted `opts.cwd == opts.fs_write_root` for every `STAGE_CHAT_MODES` entry).
- [OK] L-042 — no bulk context inlined. The preamble is bounded (`_REPLAY_MAX_CHARS`), as before.
- [OK] L-044 — typed v3 methods (`compact`, `steer`, `new_session`, `delete`) are used, not `execute`. Command-listing
  behaviour was probed on the installed CLI (`scripts/spikes/53-07/subagent_probe.py`, evidence JSONs).
- [OK] L-045 — the human-confirm backstop is kept (ADR-033 line).
- [OK] L-046 — a typed `/x` goes through `prompt()`. `execute_command` is gone (grep clean). Tested by
  `test_an_unlisted_slash_text_is_sent_as_text` and `test_a_listed_command_is_sent_raw_and_an_unlisted_one_as_text`.
- [OK] L-047 — the export reads stored messages. New meta keys are additive.
- [OK] L-056 / L-057 / L-099 — no release in this sub-spec. Both commits carry their files (`git show --stat`), and no
  pin moves.
- [N/A] L-058 / L-061 — no run→artifact bridge changed.
- [OK] L-064 — the turn ceiling is unchanged (`turn_timeout=s.chat_turn_timeout`). Ruling on deviation (6), a timeout is
  not a Stop: OK. The SDK cancels on its own limit, and D15 is about the person's Stop.
- [OK] L-069 — no `<Button asChild>`.
- [OK] L-087 / L-088 / L-089 / L-100 / L-101 / L-104 — no doc migration, guard, CI-variable call or npx use. Gates were
  run one per message.
- [OK] L-092 — `tests/chat_fakes.py` is not named `test*`. No `tests/__init__.py` was added.
- [OK] L-093 — store before announce: the assistant message is stored in the `finally` before `agent.result` is
  yielded (`manager.py:477-490`), and a steer is stored before `user.steer` is queued (`manager.py:613-617`).
- [N/A] L-096 — the new `/steer` route has no generic sibling it could shadow.
- [OK] L-098 — the SDK import stays lazy (`_make_client`, `_options_cls`, `trust_policy`).
- [OK] L-107 — every turn path stores a terminal message (normal, error, start failure `manager.py:400-408`, abandoned
  `:461-479`).
- [OK] L-109 — one home each: `STOPPED_TURN_NOTE`, `GENESIS_COMMANDS`, and `trust_policy` derived from the profile, not
  from mode names.
- [VIOLATION → M1] L-110 / L-111 (tests mirror reality) — the "closed stream" test drives `agen.aclose()`. The
  production path is sse-starlette's anyio cancel scope, which behaves differently (M1).
- [Not checked] L-112 — the python:3.13 CI image run was not done. It is the stated 53-12 precondition.

### Gates (run by me at b46c877)
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **1894 passed** in 585 s (author: 1893 at 8139cd2;
  +1 in b46c877).
- [OK] `cd genesis && .venv/bin/ruff check genesis` → All checks passed.
- [OK] `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **265 passed**. `ruff check src tests`
  is clean.
- [OK] genesis-core `pytest -q` → 109 passed.
- [OK] `cd genesis/web && npm run lint && npm run typecheck && npm test` → lint 0 errors (pre-existing fast-refresh
  warnings), tsc clean, vitest **726 passed** (62 files).
- [OK] stale bundle: `npx vite build --outDir /tmp/5307-static` then `diff -r /tmp/5307-static web/static` → identical.

## Findings

### Blockers
None.

### Majors
- M1 **The web's Stop path loses the stopped turn's metered credits, and the test that covers it does not use the
  real cancellation mechanism** (`genesis/chat/manager.py:461-479`, `:566-583`; test
  `tests/test_chat_manager.py:434-448`).
  - What the code does: when the SSE consumer goes away mid-turn, `stream_turn`'s `finally` calls `_finish_abandoned`.
    That method awaits `client.cancel()` and then waits up to 8 s on the pump, so that the turn's `ResultMessage` (text,
    tools, usage) is drained and stored. The web always stops this way: `stop()` aborts the fetch first, then posts
    `/cancel` (`web/src/features/chat/hooks.ts:139-142`).
  - The problem: sse-starlette 3.4.5 does not `aclose()` the body iterator on a disconnect. It cancels the anyio task
    group's scope, and that cancellation is level-triggered, so every await in the `finally` is cancelled again at
    once. `session/cancel` still goes out, because its bytes are written before the first suspension. The wait for the
    answer is cut off, though, so `t.result` stays `None` and the message is stored with `usage=None`. The POST `/cancel`
    that follows finds `_turn_q is None` and does nothing.
  - Concrete case, verified with a reviewer probe (`/tmp/g5307_probe/test_probe_sse_cancel.py`, not committed). It runs
    the real `KiroACPClient` over `fake_engine` with the recorded `cancel-after-tool` fixture (metered 0.0505 credits)
    and closes the stream at the first `agent.tool_call`:
    - closed as sse-starlette does (`async with anyio.create_task_group() as tg: … tg.cancel_scope.cancel()`): the
      engine received `session/cancel`, and the stored message has `meta={'turn_status':'cancelled'}` and
      **`usage=None`**;
    - closed as the test does (`agen.aclose()`): the stored message has
      `usage={'credits': 0.0505…, 'provenance': 'metered'}`.

    So after a tool round, a Stop from the browser drops real metered credits from the chat's usage and the credits
    totals, and shows that turn as having no usage. The brief's claim that the stopped turn's usage is stored is true
    only for an in-process `ChatManager.cancel`, the path the live script used (`live_chat.py:132,137`). The test's
    assertion (`provenance == "unavailable"`) passes only because the fake returns `UNAVAILABLE`.
  - Fix (smallest):
    - Run the abandoned-turn handling shielded from the outer cancellation. Wrap the `if not ended:` block in
      `with anyio.CancelScope(shield=True):` (anyio ships with starlette). The waits are already bounded by
      `_STOP_WAIT_S`.
    - Replace the `agen.aclose()` test with one that consumes `stream_turn` inside an anyio task group and cancels its
      scope. Run it on the real client over `fake_engine` `cancel-after-tool`, and assert the stored usage is metered
      and `session/cancel` was received. The probe's `_consume_until` and `test_real_client_sse_close_cancel_after_tool`
      are a ready template.
  - If skipped: the Stop button under-records spent credits whenever it lands after a tool or model round (ADR-032).
    The regression stays invisible to every gate.

### Minors
- m1 **`test_context_usage` lost its `def` line and now runs inside the delete test**
  (`packages/kiro-agent-sdk/tests/test_v3_replay.py:340-380`).
  - What: the new `test_delete_before_start_launches_without_a_session` was inserted over
    `def test_context_usage(tmp_path):`. The old test's body now follows the delete test's assertions and reuses its
    `tmp_path`, and the delete test never calls its own `r.assert_clean()`.
  - Problem: the context-usage check no longer has its own name or failure report. A failure in either check is
    reported as the other, and pytest counts one test fewer.
  - Fix: restore `def test_context_usage(tmp_path):` before `r = Replay(tmp_path, "context-usage")`, and add
    `r.assert_clean()` to the delete test.
- m2 **Spec §7's web-fixture line and the 53-09 `user.steer` field name are left open without a recorded hand-off.**
  - What: the backend now emits `session.notice`, `user.steer {message_seq, text, status}`, `agent.result`
    `{code, model, fallback_from, unread_steers}` and `error.code`. `web/src/types/chat.ts` and `web/src/test/fixtures/`
    have none of them, and 53-09's table writes `user.steer {seq, …}`.
  - Ruling on deviation (1): `message_seq` is right, because `seq` is the stream's dedupe key and the steer needs a
    second number. The contract now disagrees with the 53-09 table, though, and §7 asks for fixtures "regenerated from
    real responses" (L-011, L-083).
  - Fix: in As built, record the final event shapes (copy one real `user.steer` and one `agent.result` from
    `live-modes.json`), and hand §7's fixture line and the 53-09 field name to 53-10 explicitly.

### Nits
- n1 After a Stop followed by `/clear`, the next prompt still gets `STOPPED_TURN_NOTE`, because `_latest_turn_cancelled`
  skips command replies (`manager.py:153-164`). The new Kiro session never saw the stopped request, so the note is
  noise there. It is harmless (the note carries no stopped text). Optional: treat a successful `/clear` reply as a turn
  boundary.
- n2 Deviation (8): `reap_idle` still has no caller (pre-existing). Put it in the backlog so "idle reap =
  session/close" is not read as live behaviour.

### Rulings on the listed deviations
1. `message_seq`: OK. See m2 for the hand-off.
2. Custom-agent commands are never offered or sent raw: OK. This is fail-closed under ADR-031 with live probe evidence.
   The spec's "sent only if the engine listed it" is narrowed, not contradicted.
3. `/clear` and `/compact` in the catalog: OK (ADR-045).
4. SSE close counts as a Stop: OK as a design, since closing a tab mid-turn stopping it is reasonable. The
   implementation is incomplete in production; see M1.
5. Delete through a throwaway process: OK. It is best-effort, bounded at 30 s, uses the empty policy, and has an SDK
   test (`test_delete_before_start_launches_without_a_session`).
6. Timeouts are not marked cancelled: OK (L-064 line).
7. Mode change loads with a different agent and falls back to new + preamble: the code is OK (`_resume` falls back on
   any load error, `manager.py:309-324`), but it is not exercised live. Listed under Not checked.
8. `reap_idle` uncalled: pre-existing (n2).
9. The orphan "Tool Load" `agent.tool_update`: 53-10, agreed.
10. Grep and the 51-03 harness: **satisfied**. §6 itself names `scripts/spikes/51-03/harness.py` among the hits and
    prescribes its disposition: "marked historical (a header comment; it is outside the F13 gate)". The header says so
    (`harness.py:1-3`). The harness is outside `testpaths = ["tests"]`, has no test module importing it, and is not
    product code. Every other hit is gone in genesis and genesis-workflows (`git grep` output: only
    `harness.py:284,286`).

### Other checks requested
- **The b46c877 SDK fix** (`session.py:430-434`) is right. A requested cancel that ends in `protocol_error` or
  `cancelled` becomes `cancelled` with the detail kept, and without a cancel the error stays `protocol_error`. The
  regression test `test_a_cancel_answered_with_an_engine_error_is_still_cancelled` fails on the old branch (old
  `elif err is None and …` leaves `protocol_error`).
- **The F13 import gate** passes in the full run (`tests/test_sdk_import_boundary.py`,
  `packages/genesis-core/tests/test_core_sdk_import_boundary.py`). Chat imports only public names (`KiroACPClient`,
  `KiroAgentOptions`, `TrustPolicy`, `check_kiro`).
- **L-094 consumers:**
  - every caller of the changed surface was reached: `api/chat.py` (cancel, steer, clear/compact →
    `run_slash_command`, delete), `api/app.py:375` `aclose_all` and `api/skills.py:54`;
  - the tests that used the old fakes were updated: `test_copilot_mode`, `test_copilot_safety`,
    `test_change_requests`, `test_spec_clauses_api` and `test_chat_api`;
  - `build_chat_mcp` callers read the same `(servers, list)` shape;
  - nothing reads the dropped catalog `tools` key (grep).
- **The stream `finally` / GeneratorExit path:**
  - on `aclose()` (GeneratorExit), the path works as designed;
  - on the anyio cancellation that production uses, it sends the cancel and stores the turn cancelled but loses
    its usage (M1);
  - after the `finally`, `CancelledError`/`GeneratorExit` propagates, so the feature_spec post-turn hook does not run
    for an abandoned turn. The next turn runs it, so this needs no change.

## Not checked
- The python:3.13 CI image run (L-112). This is the 53-12 precondition.
- A real `genesis serve` plus the web: the browser's Stop, steer and notice rendering (53-10/53-11). M1 was shown with a
  reproduction of sse-starlette's mechanism, not through a browser.
- A mode change that loads the Kiro session with a different agent, live (deviation 7).
- A steer while a tool runs, an unread steer live, and a steer whose `_session/steer` call is in flight when the turn
  ends (the code reports it unread unless `agent.result` was already yielded; not reproduced).
- Whether kiro-cli routes every spec-mode write through the client `fs/write_text_file` (so `fs_write_root` holds). This
  was settled in 53-05 and not re-probed here.

## Verdict: NEEDS_CHANGES

Fix M1: shield the abandoned-turn handling from the SSE's anyio cancellation, and replace the `aclose()` test with an
anyio-scope test on the real client over `cancel-after-tool` that asserts metered usage is stored. Fix m1 too, since it
is a one-line restore. m2 can be closed in As built. Everything else is ready.

---

# Round 2 — genesis b46c877 → 2af786f (genesis-review, 2026-11-12)

What 2af786f changes: `ChatSession.stream_turn`'s whole `finally` now runs inside `anyio.CancelScope(shield=True)`
(M1), and `anyio>=4,<5` is declared in `pyproject.toml`. A successful typed `/clear` ends the D15 note scan, and command
replies store `meta {"command", "ok"}` (n1). The SDK test `test_context_usage` gets its `def` line back, and the
delete-before-start test calls `r.assert_clean(ended=False)` (m1). There are two new tests. HEAD is 2af786f and the tree
is clean (`git status --short` is empty). `genesis-ctx check --since b46c877 --repo genesis` lists 5 files in the areas
chat, release-ci and security. Every line it lists is answered below.

## Round-1 findings

- **M1: fixed.**
  - **The fix** (`genesis/chat/manager.py:465-490`). The shield covers `_finish_abandoned`, the pump wait, the store and
    the fatal-code `_drop_client`. Every await inside it is bounded:
    - `client.cancel()` and the pump wait are each capped by `asyncio.wait_for(…, _STOP_WAIT_S=8)` (`:579`, `:583`);
    - `await pump_task` follows `pump_task.cancel()`, and the SDK's `Session.prompt` `finally` has no await
      (`session.py:383-388`);
    - `client.close()` is bounded by `SESSION_CLOSE_TIMEOUT_S` and `terminate(grace=CLOSE_GRACE_S)`.

    So a shielded `finally` cannot hang the SSE task. The `with` block contains no `yield`, so it never holds a scope
    across a suspension of the generator. The outer cancellation is delivered after the block, at the post-turn hook,
    as before.
  - **The regression test fails without the fix.** In a scratch worktree at 2af786f I checked out b46c877's
    `manager.py` and confirmed that `genesis.chat.manager` imported from the worktree. There,
    `test_a_browser_stop_keeps_the_stopped_turns_metered_usage` fails with
    `ChatMessageRecord(… usage=None, meta={'turn_status': 'cancelled'})`, which is the round-1 symptom. With 2af786f's
    `manager.py` restored, `tests/test_chat_v3_engine.py` and `tests/test_chat_manager.py` give 43 passed.
  - **The test mirrors the real mechanism (L-110).** It consumes `stream_turn` inside an anyio task group and cancels
    that group's scope at the first `agent.tool_call`, without `break` or `aclose()`. That is the shape sse-starlette
    uses. It runs on the real `KiroACPClient` over `fake_engine` `cancel-after-tool`, and it asserts `session/cancel`,
    `turn_status: cancelled` and metered credits equal to the fixture's (`approx`, 1e-6).
  - **Extra reviewer probe** (written in the scratch worktree, then deleted): the web's POST `/cancel` arriving
    *during* the shielded drain, which the committed test does not cover (it calls `m.cancel` after the group exits).
    Result: one `session/cancel` reached the engine, and the stored message was `meta={'turn_status':'cancelled'}`,
    `usage={'credits': 0.0505…, 'provenance': 'metered'}`. The concurrent `stop()` → `Session.cancel` only waits on
    the same `turn.done`, so the race is harmless.
  - **The dependency** (`pyproject.toml:46-48`). Installed: anyio 4.14.1. sse-starlette 3.4.5 requires `anyio>=4.7.0`
    and starlette 1.3.1 requires `anyio<5,>=3.6.2`, so `>=4,<5` fits both. No other pin or install script names anyio
    (`git grep`). This is not an internal dependency entry, so ADR-080 holds.
- **m1: fixed.** `def test_context_usage(tmp_path):` is back (`test_v3_replay.py:363`). The delete test ends with
  `r.assert_clean(ended=False)`, and `assert_clean(self, *, ended=True)` exists (`:116`), so it still checks for
  mismatches, stalls and the D19 agent checks without requiring `script_end`. `-k "delete_before_start or
  context_usage"` gives 2 passed. The SDK total rose 265 → 266.
- **n1: fixed for the typed `/clear`.** `_latest_turn_cancelled` returns False at a `/clear` reply with `ok` true
  (`manager.py:163-165`). A failed `/clear` (`ok: False`) or a `/compact` still continues the scan. That is right,
  because the Kiro session that saw the stopped request is still in use. Command replies stored before this commit
  have no `ok` key and keep the old behaviour (they are skipped), which is safe. The new test
  `test_a_typed_clear_after_a_stop_drops_the_note` fails at b46c877 (the prompt is `STOPPED_TURN_NOTE … User: next`)
  and passes at 2af786f. The existing assertion is updated to `{"command": "/compact", "ok": True}`. Residual: the
  Clear *button* stores no exchange, so after Stop followed by a button Clear the note still goes once. This is
  harmless, and the author records it in As built. Accepted.
- **m2: deferred to As built, as round 1 allowed.** It is not closed yet; see Not checked.
- **n2: deferred to As built / backlog.** It is not closed yet; see Not checked.

## Checklist (round-2 diff)

### ADRs
- [OK] ADR-032: the M1 violation is closed. A browser Stop stores the turn's real metered usage (test above, the
  failure without the fix shown, and the concurrent-POST probe). No figure is estimated.
- [OK] ADR-080: one repo and one version. `anyio` is a third-party dependency already resolved transitively, and no
  internal package gains a dependency entry.
- [OK] ADR-031 / ADR-033 / ADR-034 / ADR-045: the diff touches no trust policy, tool list, confirm path or
  `fs_write_root`. The `/clear` and `/compact` commands still run `_clear`/`_compact` and are never prompted
  (`test_typed_clear_and_compact_are_genesis_commands` still asserts `client.prompts == ["an essay"]`).
- [OK] ADR-010: the new meta key `ok` is a bool.
- [OK] ADR-002 / ADR-004 / ADR-020: the client construction, MCP servers and `KIRO_HOME` are unchanged by this diff.
- [N/A] ADR-001, 005, 011, 019, 021, 026, 027, 028, 029, 030, 035, 037, 041, 042, 046, 050, 051, 053, 055, 059, 060,
  063, 065, 068, 069, 073, 074, 075, 076, 077, 082, 083, 085: this diff changes none of the routes, web, registry,
  schema, workflows, KB, spec, lifecycle, collaboration, test execution or report serving. ADR-075's post-turn hook
  still runs after the shielded block (`manager.py:492-495`). ADR-077 holds: no agent was run with
  `--trust-all-tools`.

### Lessons
- [OK] L-016: credits are real, not estimated (see ADR-032).
- [OK] L-093: store before announce is kept. The assistant message is stored inside the shielded block, before
  `agent.result` is yielded (`manager.py:484-487`, `:501`).
- [OK] L-107: the terminal store now completes on the anyio-cancel path too. That path was the M1 gap.
- [OK] L-110 / L-111: the test drives the production cancellation mechanism, and live acceptance stays with 53-11.
- [OK] L-025 / L-027: ruff is pinned, and both repos' ruff runs are clean (below).
- [OK] L-092: no `tests/__init__.py` and no non-test `test*` name added.
- [OK] L-046: a typed `/clear` still runs the Genesis command and is not sent through `execute`.
- [OK] L-047: the export reads stored messages. The `ok` meta key is additive.
- [OK] L-056 / L-057 / L-099: there is no release here. `git show --stat 2af786f` carries the implementation, both
  tests, the SDK test and `pyproject.toml`, and no internal pin moves.
- [OK] L-089: I ran verifying steps one per message. Early in this review I ran two dependent scratch-worktree steps
  in parallel, which raced. I discarded those results and re-ran each step on its own. Only the sequential runs are
  cited above.
- [N/A] L-001, L-007, L-017, L-018, L-024, L-030 (no web file), L-041, L-042, L-044, L-045, L-051, L-058, L-061, L-069,
  L-073, L-086, L-087, L-088, L-098, L-100, L-101, L-104, L-105: not touched by this diff.
- [Not checked] L-112: the python:3.13 CI image run is still the 53-12 precondition.

### Gates (run by me at 2af786f)
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **1896 passed** in 569 s (round 1: 1894; +2 new
  tests).
- [OK] `cd genesis && .venv/bin/ruff check genesis` → All checks passed.
- [OK] `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **266 passed**.
  `../../.venv/bin/ruff check src tests` → All checks passed.
- [N/A] genesis-core: unchanged since round 1 (109 passed then).
- [N/A] web lint/typecheck/vitest/build: no `web/**` file changed in b46c877..2af786f (`git diff --stat`). The round-1
  run (726 passed, identical bundle) stands.

## Findings (round 2)

### Blockers
None.

### Majors
None.

### Minors
None new.

### Nits
- r2-n1 (optional, test-only) The committed M1 test calls `m.cancel` after the task group has exited. The web's real
  order sends POST `/cancel` while the shielded drain is still running. My probe shows that order also stores the
  metered usage, with one `session/cancel` received. A second test with a concurrent `m.cancel` would pin it. The
  current code is correct without it.

## Not checked
- **As built** is not written yet, so these hand-offs are promised but not verified. The dev must record them before
  the sub-spec closes:
  - m2: the final event shapes, with one real `user.steer` and one `agent.result` from `live-modes.json`;
  - m2: §7's web-fixture line, and 53-09's `user.steer {seq}` → `message_seq`, handed to 53-09 and 53-10;
  - n2: `reap_idle` (still uncalled) entered in the backlog;
  - the Clear-button residual of n1.
- Everything in the round-1 Not checked list still applies: the CI image (L-112), the browser Stop/steer/notice
  through a real `genesis serve` (53-10/53-11), a live mode-change load, live steer edge cases, and spec-mode write
  routing.

## Verdict: SHIP

M1, m1 and n1 are fixed, each with a regression test that I saw fail without the fix and pass with it. All gates are
green at 2af786f. m2 and n2 close in As built, as agreed in round 1, and the items above must appear there.
