# Review 53-06 — genesis 466d51a → 0c0a4aa, genesis-workflows 6a7d432 → b097719, playwright-appian 02c65b7 → 38f87fd (genesis-review, 2026-11-11)

What this change does: workflow agent nodes (`kiro_node`) now run on the v3 SDK client. Each turn gets the run's own
Kiro home (`<run>/_kiro`), D9's `TrustPolicy` (seven built-ins plus only the node's MCP servers within their allowlists,
plus the blackboard, all auto-approved) and a fixed node prompt. The SDK's public names switch to v3; chat keeps v2
through the `Legacy*` aliases. Workflow skills resolve only from the managed workspace and the run checkout's
`playwright-appian`, with a front-matter check that fails the node before any turn. The `appian` skill is copied into
the library, the skill store accepts any bundle folder, and playwright-appian 0.3.1 fixes the front matter that made v3
drop its skill.

All three heads exist and are the repos' HEADs (`git rev-parse --short HEAD`: 0c0a4aa, b097719, 38f87fd; genesis
working tree clean). `genesis-ctx check --since 466d51a --repo genesis` was run; the checklist below answers every line
it listed.

## Checklist

### ADRs
- [OK] ADR-001 — agents never orchestrate: the change touches one turn's options and skill provisioning only; no graph
  or routing change (`nodes/agent.py` diff; no `graph.py` changed in genesis-workflows).
- [OK] ADR-002 — narrow Kiro turns over ACP with per-node MCP: `servers = ctx.mcp.acp_servers(list(mcp))` unchanged
  (`agent.py:315`); one `query()` session per node (`kiro_agent_sdk/__init__.py:120-136`).
- [OK] ADR-004 — per-node MCP: the TrustPolicy lists only the node's servers (`_node_mcp_trust` drops entries for any
  server outside `mcp_names`, test `test_only_the_nodes_own_servers_and_no_bare_names`); the run's own `KIRO_HOME`
  means the engine no longer loads `~/.kiro/settings/mcp.json`.
- [OK] ADR-005 — the `appian` skill enters through the library (`skills/appian/`, `skills-registry.json`), installed by
  `SkillInstaller` (`tests/test_skill_install.py::test_appian_installs_from_the_library_and_the_workflow_resolver_finds_it`).
- [N/A] ADR-009 — HITL modes untouched (no gate, pause or fork code changed).
- [OK] ADR-010 — state keeps pointers only: `agent.prompt` still carries `prompt_ref`; the new `agent.result` keys
  `model`, `fallback_from` are short strings (`agent.py:452-460`).
- [OK] ADR-011 — reliability trio: an `mcp_failed` turn reaches the node as `err` with `ok: False`
  (`test_core_agent_v3.py::test_mcp_failed_turn_reports_the_error_and_no_credits`); `validate_library` reliability
  lint green (18 workflows).
- [OK] ADR-012 — the app imports no workflow Python: `runtime/context.py` changed only inside `_skill_source`; the
  worker path is unchanged. Live check did not cross the worker boundary (Not checked).
- [N/A] ADR-017 — Python only; no new language in genesis (playwright-appian is its own TS repo).
- [OK] ADR-018 — bulk via the blackboard: `save_tool_output` detection keeps `raw_input["document"]`, now restricted to
  server `blackboard` (`agent.py:383-384`, `test_save_tool_output_of_another_server_is_not_a_blackboard_save`).
- [OK] ADR-019 — `kiro_node` signature unchanged (no change in the `def kiro_node(` parameters in the diff);
  `CORE_MAJOR` unchanged; `SkillSourceError` is an additive export (`genesis_core/__init__.py:27,53`). The removed
  `_compute_effective_trust` was private; no caller outside core tests (`git grep` in genesis and genesis-workflows).
- [N/A] ADR-020 — no global Kiro write; the personal `~/.kiro/skills/appian` is untouched (mtime 27 Aug; `diff -r`
  against the library copy differs only at `documentation-lookup-strategy.md:191`).
- [OK] ADR-021 — `META.auto_approve` and gates untouched; the node's mode is now explicit `auto_approve`
  (`_trust_policy`, `agent.py:207-218`).
- [OK] ADR-022 — `_kiro/` lives under the run root inside the artifacts root and goes with retention; the listing hides
  it, the folder stays (`workspace.py:69-83`, asserted in `test_kiro_node_builds_real_options`).
- [N/A] ADR-023, ADR-024, ADR-025 — engine, async model and fork untouched.
- [N/A] ADR-026 — no bind or server change.
- [N/A] ADR-027 — no web change (no `web/` file in the diff).
- [N/A] ADR-028 — no endpoint added or changed.
- [OK] ADR-029 — `node.tools ∩ server.allowlist` per server, now enforced by the engine's tool list: see decision 1
  below. Own scan of every literal and generated `@server/tool` in `genesis-workflows/workflows/*/graph.py` against
  `mcp-registry.json`: no listed tool falls outside its server's allowlist (only false positives such as
  `@playwright/test` in comments). The ADR-086 draft (`adr-drafts.md:79`) states the same rule.
- [N/A] ADR-030 — no persistence change.
- [OK] ADR-031, ADR-033, ADR-034, ADR-045 — chat unchanged: `chat/manager.py:55,60` import the v2 client as
  `LegacyKiroACPClient` / `LegacyKiroAgentOptions`; `test_chat_manager.py` and `test_copilot_mode.py` (still asserting
  v2 `trust_tools`) pass in the 1864-test run.
- [OK] ADR-032 — credits stay metered: `mcp_failed` carries `credits: None`, `provenance: unavailable` and no prompt is
  sent (`test_v3_replay.py::test_query_ends_before_the_prompt_when_a_sent_server_is_not_connected`, checks
  `session/prompt` never reaches the wire).
- [N/A] ADR-035, ADR-037, ADR-039, ADR-041, ADR-042, ADR-050, ADR-053, ADR-054, ADR-055, ADR-059, ADR-060, ADR-061,
  ADR-062, ADR-063, ADR-065, ADR-073, ADR-074, ADR-075, ADR-076, ADR-084, ADR-085 — areas not touched by the diff.
- [N/A] ADR-046, ADR-080 — no packaging or version change in genesis (versions stay 0.81.0; release is 53-12).
- [OK] ADR-051 — `KiroAcpProvider` / `_load_real` unchanged; `options_cls()` now returns the v3 options;
  `set_collect_impl` / `set_agent_provider` hooks still drive every genesis-workflows test (432 passed).
- [OK] ADR-066 — event shapes unchanged: key sets of `agent.tool_call` / `agent.tool_update` asserted from real v3
  messages (`test_v3_messages_keep_the_event_shapes_and_the_save_by_reference`); `agent.result` additive only.
- [OK] ADR-067 — heal nodes are ordinary `kiro_node` turns; `test_healing.py` green (core 108 passed).
- [OK] ADR-068 — story-implementation's write server stays injected only on `implement` / `heal` (`NODE_MCP`
  unchanged); its write tools stay capped by the `appian-dev-write` allowlist, now engine-enforced.
- [OK] ADR-069 — skills still provisioned into `<run>/.kiro/skills/`; personal fallback removed as D8 / ADR-086 draft
  (`adr-drafts.md:195`) require; `test_resolver_ignores_the_personal_kiro_skills`. ADR-069's rejected alternative (c)
  "set KIRO_HOME" is reconciled by the ADR-086 draft (`adr-drafts.md:59`); it must land at 53-12 write-back.
- [OK] ADR-077 — no `--trust-all-tools`; the TrustPolicy lists tools explicitly.
- [OK] ADR-082 — no execution or environment change; Phase 51 nodes keep their shape.
- [OK] ADR-083 — Phase 51 node shape (no `mcp`, no `tools`) gets the built-ins plus `@blackboard`
  (`test_kiro_node_builds_real_options`, live probe `live-node.json` → `agent_prompt_tools: [["@blackboard"]]`, shell +
  blackboard tools ran with 0 permission requests). Risk (d) closes with the run's own `KIRO_HOME`, per the ADR-086 draft.

### Lessons
- [N/A] L-001 — no MCP env construction changed (`"env": []` for the blackboard as before).
- [OK] L-002 — `test_kiro_node_builds_real_options` builds the real v3 `KiroAgentOptions` dataclass for four node shapes.
- [N/A] L-004, L-006, L-007, L-009, L-018, L-022, L-030, L-045, L-046, L-047, L-058, L-059, L-061, L-065, L-069, L-073,
  L-076, L-086, L-087, L-088, L-093, L-098, L-099, L-100, L-104, L-105, L-106 — not in the diff's reach.
- [OK] L-005 — no new event kind; `artifact.saved`, `tool_output.recorded`, `skills.provisioned` existed.
- [OK] L-016 — credits real; see ADR-032.
- [OK] L-017 — namespaced `@server/tool` entries throughout `_node_mcp_trust`; the namespace regression test
  `test_namespaced_node_tools_meet_bare_allowlists` pins the old bug.
- [OK] L-020 — retries still keyed by node name (`state["retries"][name]`, unchanged).
- [OK] L-021 — `NODE_AGENT_PROMPT` tells the agent to save large output with `save_tool_output`; the live probe saved by
  reference (`live-node.json`: `saved_by_reference`).
- [OK] L-023 — `raw_input` read defensively (`getattr(..., {}) or {}`), unchanged.
- [OK] L-024 — skills from the filesystem; W1 re-run lists both skills in `items_changed` (`w1-rerun-031.json`).
- [OK] L-025, L-027 — ruff pinned and green in all three Python trees.
- [OK] L-026 — no DB write added to a node.
- [OK] L-041 — cwd = run root and `fs_write` in the built-ins, as before.
- [OK] L-042 — skill content as files; unchanged.
- [OK] L-044 — designs verified against the installed kiro-cli 2.37.1 (W1 re-run, live hello-appian, probe frames).
- [OK] L-051 — no shipping change.
- [N/A] L-056, L-057 — no tag or pin in this sub-spec (local commits; 53-12 releases).
- [OK] L-064 — `turn_timeout` unchanged and still the ceiling.
- [OK] L-075 — `mcp_failed` spends no credits before the retry.
- [OK] L-083 — the refusal tests use the vendored 0.3.0 line 3 verbatim (checked against
  `genesis/testexec/vendor/playwright-appian-0.3.0.tgz` `package/skills/playwright-appian/SKILL.md` lines 1-4).
- [OK] L-089 — reviewer verification reads were done after their producing commands finished.
- [OK] L-092 — `workflows/story-implementation/tests/test_library_skills.py` has a unique basename and no `__init__.py`
  was added.
- [OK] L-101 — `SKILL.md:16` bare `npx apwt` replaced by "stop and report"; `skill.test.ts` "never runs a bare npx
  apwt". The bare `npx playwright test` at `SKILL.md:100,110` remains (n3).
- [OK] L-111 — the author states plainly that no real Phase 51 workflow and no worker-path run was done (see Not checked).
- [N/A] L-112 — applies at the release commit, not to this local commit; no run in the `python:3.13` CI image has
  been done yet, and it must happen before 53-12 tags (Not checked).

### Gates (run by the reviewer)
- [OK] `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **321 passed**; `ruff check src tests` → all checks passed.
- [OK] `cd genesis/packages/genesis-core && ../../.venv/bin/python -m pytest -q -p no:warnings` → **108 passed**; `ruff check genesis_core` → passed.
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **1864 passed** in 573 s (none deselected; the
  readiness probe did not hang this time); `ruff check genesis` → passed.
- [N/A] `cd genesis/web && npm run lint && npm run typecheck && npm test` / `npm run build` — no `web/` file changed.
- [OK] genesis-workflows: `ci/validate_library.py` → 18 validated; `ci/validate_skills.py` → 5 validated;
  `pytest -q workflows --ignore=workflows/_fixtures` → **432 passed**.
- [OK] playwright-appian: `npm run lint`, `npm run typecheck`, `npm run build` clean; `npm test` → **95 files, 1402
  passed**; working tree clean after the build.

### Author's decisions, checked
1. **`_node_mcp_trust` replaces `_compute_effective_trust`** — correct and needed. The old function intersected
   `@server/tool` node tools (e.g. `KB_RO`, `story-implementation/graph.py:62`) with bare allowlist names
   (`registry.py:59-65`), so every grounding node would have had an empty MCP list on v3. The new rule is per server
   (an allowlist on server a no longer opens the same name on server b, `test_allowlists_cap_their_own_server_only`),
   matches ADR-029 and the ADR-086 draft (`adr-drafts.md:79`). It deviates from the spec's wording (§2 names
   `_compute_effective_trust`); record it in As built as a deviation.
2. **`mcp_failed` in `query()`** — right place: `kiro_node` sees only `collect_streaming`'s result, and chat uses the
   client directly. Counting `connecting` after the wait is consistent with `session.wait_mcp_ready`, which marks
   unreported servers `connecting` (`session.py:321-329`); `kiro_node`'s `startup_timeout` default is 120 s, above the
   engine's 60 s connect limit.
3. **Event `name`** — matches v2 for MCP tools; built-ins carry registered ids (D19), evidence in `live-node.json`.
4. **One-line YAML error** — fine; see n1 for the line number.
5. **Store refusals** — matches the spec ("dot-file or dot-folder segments"); `SkillInstaller` pops `SKILL.md` before
   calling `store.create` (`dist/skill_install.py:57`), so the new second-`SKILL.md` refusal breaks no install. No
   library skill has a dot file (`git ls-tree -r skills | grep '/\.'` empty).
6. **js-yaml 4.1.1 exact devDependency** — acceptable; the test proves the 0.3.0 line is rejected. Bare `npx
   playwright test` left: see n3.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **The v3 "Tool Load" step is recorded as a tool output** (`packages/genesis-core/genesis_core/nodes/agent.py:391-397`)
  — What: every completed `ToolCallUpdate` that is not a blackboard save goes to `store.record(tool=tname, …)`. Problem:
  v3 emits an engine step titled `Tool Load` (rawInput `{"tool_ids": ["blackboard::list_tool_outputs", …]}`, fixture
  `kiro-agent-sdk/tests/fixtures/v3/shell-auto-approve.jsonl`), and its `name` is `Tool Load`, so it is stored in
  `_toolcalls/`, appears in the agent's `list_tool_outputs`, and counts in `telemetry.tool_outputs_recorded`. Live: the
  probe ran one shell command and recorded 2 tool outputs (`live-node.json` `probe_phase51_shape`, `tool_output.recorded:
  2`, `tool_updates_completed` includes `"Tool Load"`). v2 had no such step, so this is a telemetry and blackboard
  change against §1's "same … telemetry and blackboard behaviour". `test_v3_messages_keep_the_event_shapes…` compares
  `tool_outputs_recorded` to `len(recorded)` and so accepts the extra entry. Fix: skip recording when the update is the
  engine's tool-load step (no `server` and `raw_input` has `tool_ids`, or `name == "Tool Load"`), and assert in that test
  that `recorded` is exactly the two `execute_bash` outputs. If skipped: every v3 node that loads deferred tools records
  one junk output per load and over-reports the count.
- m2 **Phase 51 workflows fail at their first agent node until 53-12 re-vendors 0.3.1**
  (`genesis/runtime/context.py:93-109` with `genesis/testexec/vendor/playwright-appian-0.3.0.tgz`) — What: the resolver
  now refuses the 0.3.0 skill, as the spec requires. Problem: on this build, action-capture / story-verification and any
  node declaring `playwright-appian` fail with the remedy text, and the vendored tarball that "Update testing runtime"
  installs is still 0.3.0, so the remedy cannot work until 53-12 step 0. Nothing in the genesis tests ties the two: a
  release of genesis without the re-vendor would pass every gate. Fix (in 53-12, or now as an xfail-free test there): a
  genesis test that extracts the vendored tarball's `SKILL.md` and runs `parse_skill_md` + `validate(expected_id=
  "playwright-appian")`; record the dependency in this sub-spec's As built and the Resume note. If skipped: a partial
  release ships every Phase 51 browser workflow broken.

### Nits
- n1 **The YAML error names the line within the front-matter block** (`context.py:107-108`) — the 0.3.0 error says
  "line 2, column 112" while the file's line is 3. Optional: say "front matter line 2" or add one in the message.
- n2 **`_skill_source` labels I/O errors as "invalid front matter"** (`context.py:107`) — an unreadable `SKILL.md`
  (`OSError`) reads as a front-matter problem. Optional: say "unreadable SKILL.md" for `OSError`.
- n3 **Bare `npx playwright test`** (`playwright-appian/skills/playwright-appian/SKILL.md:100,110`) — out of this spec's
  scope, as the author said; Playwright is a dependency of the workspace export, so it resolves locally there, but in a
  folder without it npx would install from the registry (L-101's mechanism). Put it in the Phase 53 or playwright-appian
  backlog.
- n4 **`agent.prompt.tools` changed meaning** (`agent.py:369`) — it now lists only MCP entries (never `"all"`, never the
  built-ins). No consumer reads it (`genesis/runs/steps.py:117` passes it through; `web/src/types/event.ts:39` still
  allows `"all"`; nothing renders it). Optional: note it in As built.

## Not checked
- A run through the subprocess worker (ADR-012): the live hello-appian run and the probe used `build_context` in
  process (`live_node.py` docstring says so).
- A real Phase 51 workflow node (action-capture, story-verification, setup-composer) on v3 with QA, and the
  story-implementation nodes with the library `appian` skill against Dev.
- The `python:3.13` CI image (L-112) for all three Python suites.
- The `appian` skill's changed line 191 in practice: `cat registry/components-registry.json` is relative to the skill
  folder, while the agent's cwd is the run root; it follows the spec's instruction, but no live turn exercised it.
- Chat on the `Legacy*` aliases live (only its unit tests ran).

## Verdict: SHIP

No blockers or majors; every gate the check lists is green as re-run here. Fix m1 before 53-12 if it fits (it is small
and has a ready fixture); m2 must be closed by 53-12 step 0 and should get its guard test there.

---

# Round 2 — genesis 0c0a4aa → d5a6a4e (genesis-review, 2026-11-11)

Scope: one commit, `d5a6a4e`, the fix for round 1's m1. It touches two files (`git show --stat d5a6a4e`):
`packages/genesis-core/genesis_core/nodes/agent.py` (+21) and `packages/genesis-core/tests/test_core_agent_v3.py`
(+33/−4). genesis HEAD is `d5a6a4e` and the working tree is clean. genesis-workflows (`b097719`) and playwright-appian
(`38f87fd`) did not change since round 1. `genesis-ctx check --since 0c0a4aa --repo genesis` was run. It maps
`agent.py` to core-engine (plus always-on release-ci and security) and lists two gates.

What the fix does: `_is_engine_step(m)` (`agent.py:236-244`) returns True for a message with no `server` whose
`_meta.kiro.toolId` is one of the SDK's `meta_tools` (`tool_load`, `tool_call`, `disclose_context`; checked against
`kiro_agent_sdk/tool_ids.json:28`), or whose `raw_input` holds `tool_ids` (the tool-load step, which arrives as an
update with no call before it, 53-02 W5). `_on_message` keeps the `toolCallId` of every engine-step `ToolCall`
(`agent.py:392,397`) because a skill load's completed update carries no `_meta` (checked in
`scripts/spikes/53-02/evidence/w1-rerun-031.jsonl:46`). It skips those updates before the store (`agent.py:402`). The
events (`agent.tool_call` / `agent.tool_update`) are unchanged, so the run's conversation still shows both steps.

## Checklist (round 2)

### ADRs
- [OK] ADR-001, ADR-002, ADR-004 — no control-flow, session or MCP-injection change; the diff is inside the message
  callback only.
- [N/A] ADR-009, ADR-012, ADR-017, ADR-019 (no signature or export change; `_is_engine_step` and
  `_ENGINE_META_TOOL_IDS` are private), ADR-020, ADR-021, ADR-023, ADR-024, ADR-025, ADR-026, ADR-028, ADR-030,
  ADR-037, ADR-039, ADR-041, ADR-042, ADR-046, ADR-050, ADR-053, ADR-054, ADR-061, ADR-062, ADR-063, ADR-065, ADR-068,
  ADR-073, ADR-074, ADR-075, ADR-076, ADR-080, ADR-082, ADR-084, ADR-085 — not in this diff's reach.
- [OK] ADR-010, ADR-018, ADR-022 — the blackboard now holds only the work's outputs. The shell recording leaves exactly
  `_toolcalls/call_1.out` and `call_2.out` (`test_core_agent_v3.py:107-108`); a skill load's text (16 731 bytes in W1)
  no longer lands in `_toolcalls/`.
- [OK] ADR-011, ADR-067 — validators and healing do not read the tool-output store count; core suite green (109).
- [OK] ADR-029 — MCP outputs are untouched: `_is_engine_step` returns False whenever `server` is set (`agent.py:238`),
  so a deferred MCP call is never skipped, whatever its `toolId`. Reviewer probe (`/tmp/r2-53-06-probe.py`, the
  `mcp-allow.jsonl` fixture through `kiro_node`): `recorded: ['env', 'list_applications']`, `tool_outputs_recorded: 2`,
  `Tool Load` not recorded.
- [OK] ADR-051 — still drives the turn through the provider; `_StreamingProvider` in the tests.
- [OK] ADR-066 — what each agent did is still captured: the skill-load test asserts the `agent.tool_call` event
  `Load skill: genesis-test-authoring` is emitted (`test_core_agent_v3.py:128`); only the store entry is dropped.
- [OK] ADR-069 — skill provisioning untouched; `tests/test_workflow_skill_provisioning.py` passes.
- [OK] ADR-077 — no trust widening; no `--trust-all-tools`.
- [OK] ADR-083 — Phase 51 recording test (`tests/test_testexec_recording.py`) passes; built-in outputs still recorded.

### Lessons
- [OK] L-002 — the tests drive the real `kiro_node` with real v3 messages translated by the SDK (`translate`,
  `ToolIndex`).
- [OK] L-005 — no event kind added or removed.
- [OK] L-016 — credits untouched.
- [OK] L-017 — no trust change.
- [OK] L-021 — the store keeps saves by reference; `artifact.saved` for `w3/snapshot.txt` still asserted
  (`test_core_agent_v3.py:97-99`).
- [OK] L-023 — the new reads are defensive: `getattr(..., None) or {}`, `isinstance(raw, dict)`, `(… or {})` at each
  `_meta` level (`agent.py:240-243`).
- [OK] L-044 — the identity comes from measured frames (W5 tool load, W1 re-run skill load) and the measured tool-id
  table, not from docs.
- [OK] L-083 — the shell test uses the recorded fixture verbatim. The skill-load test's frames are not quite the
  recording: see n6. The difference does not touch what the code reads.
- [OK] L-025, L-027 — `ruff check genesis_core` passed with the pinned ruff.
- [OK] L-089 — each verifying read ran after its producing command finished (separate calls).
- [OK] L-111 — no live v3 turn was run for this fix; it is unit-level, stated in Not checked.
- [N/A] L-001, L-004, L-006, L-009, L-020, L-022, L-026, L-030, L-041, L-042, L-045, L-051, L-056, L-057, L-059, L-064,
  L-065, L-075, L-076, L-087, L-088, L-092, L-098, L-099, L-100, L-101, L-104, L-105, L-106, L-112 — not in this diff's
  reach (L-112 stays open for 53-12 as in round 1).

### Gates (run by the reviewer)
- [OK] `cd genesis/packages/genesis-core && ../../.venv/bin/python -m pytest -q -p no:warnings` → **109 passed**;
  `../../.venv/bin/ruff check genesis_core` → all checks passed.
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings tests/test_workflow_skill_provisioning.py
  tests/test_testexec_recording.py` → **45 passed**.
- [OK] genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` → **432 passed** (core is editable in the
  shared venv, so this ran against `d5a6a4e`).
- [OK] Regression tests fail without the fix. I made a scratch copy (`git archive d5a6a4e packages/genesis-core` plus
  the SDK fixtures, into `/tmp/r2-53-06b`) with `agent.py` from `0c0a4aa`, and ran `tests/test_core_agent_v3.py` with
  the copy first on `sys.path` → **2 failed, 3 passed**. The event-shapes test fails at `'Tool Load' != 'execute_bash'`;
  the skill-load test records `tool: 'Load skill: genesis-test-authoring'`. This matches the author's claim.

## m1 — closed

Every part of the round 1 fix is in. The engine's tool-load step is skipped by identity, never by title. The test now
pins the exact recorded list, the count of 2 and the `_toolcalls/*.out` files, where before it compared the count to
itself. The fix also covers a case round 1 missed: a skill load (`disclose_context`) would have recorded the whole
`SKILL.md` text as a tool output.

## Findings (round 2)

### Blockers
None.

### Majors
None.

### Minors
None new. m2 from round 1 is unchanged and stays with 53-12 step 0.

### Nits
- n5 **No suite test pins that a non-blackboard MCP output is still recorded** (`test_core_agent_v3.py`). The new
  filter has a negative side (engine steps skipped) and two tests for it. Its positive side has a test for built-ins
  (`execute_bash` ×2) but none for MCP. The `server` guard (`agent.py:238`) is what keeps a deferred MCP call (engine
  id `tool_call`, never seen in any recorded frame) recorded. My probe shows it holds today. A later edit that drops
  the guard would pass every test. Optional fix: run `mcp-allow.jsonl` through `_run_node` and assert
  `recorded == ["env", "list_applications"]`, as the probe does.
- n6 **The skill-load test's frames are edited, not the recording** (`test_core_agent_v3.py:116-122`). The docstring
  says they come from `w1-rerun-031.jsonl` and are "scrubbed". In the recording, the completed update's title is
  `Loaded skill: …` and its `rawOutput` is `{contentLength, item}` (line 46), not `Load skill: …` / `{message}`. The
  `in_progress` update (line 45) is also missing, and it is the one update that does carry `toolId:
  disclose_context`. The code does not read either field, so the test still proves the fix. Optional: copy lines
  36, 45 and 46 verbatim, or say "simplified" in the docstring (L-083).
- n7 **An empty `toolCallId` on an engine-step `ToolCall` would put `""` in `meta_calls`** (`agent.py:397`). Every
  update without an id would then be skipped. No recorded frame has an empty id, so this is theoretical. Optional:
  add the id only when it is truthy.

## Not checked (round 2)
- A live v3 turn that loads deferred tools and a skill through `kiro_node` with this commit (the probe and tests replay
  recorded frames only).
- The full genesis suite (1864 in round 1). Only the two files the author cited were re-run, since the diff is confined
  to genesis-core's message callback.
- Everything listed under round 1's Not checked is still open.

## Verdict (round 2): SHIP

m1 is fixed by engine identity, the new tests fail without the fix and pass with it, and every listed gate is green as
re-run here. n5–n7 are optional. m2 still has to be closed at 53-12 step 0.
