# Review 53-04 — base 143e9d2, change beea49b (genesis-review, 2026-11-10)

What this change does: adds the v3 SDK core under `packages/kiro-agent-sdk` (`launch`, `transport`, `session`,
`updates`, `usage`, `errors`, `timeouts` and the private `_v3client.KiroACPClient` / `KiroAgentOptions`), a fake engine
that replays the 28 recorded 53-02 fixtures, unit and process-tree tests, a public-surface pin, and SDK import gates in
genesis and genesis-core. Per §1 "Sequencing" the top-level names still point at the v2 `client.py`, which is unchanged
(`git diff 143e9d2..beea49b --quiet -- …/client.py` → no diff). Nothing outside SDK tests reaches the v3 path.

Reviewed: `git diff 143e9d2..beea49b` (17 files, +4113/−2); beea49b is HEAD on master, not pushed. Spec:
`53-04-sdk-core.md` §1–§4 (sequencing agreed in project-tracker 08cbe8c), plus 53-06 §MCP readiness for the
`mcp_failed` hand-off.

## Checklist

ADRs (from `genesis-ctx check --since 143e9d2 --repo genesis`; the changed files map to areas chat, sdk-acp, plus the
always-on release-ci and security):
- [OK] ADR-001 — LangGraph owns control flow — the SDK adds session operations only; no orchestration (`_v3client.py`).
- [OK] ADR-002 — narrow Kiro turns over ACP with per-node MCP — `session/new {cwd, mcpServers, _meta.kiro.customAgents}`
  (`session.py` `new`/`load`); no `mcp.json` is written anywhere in the diff.
- [OK] ADR-004 — per-node MCP injection — `KiroAgentOptions.mcp_servers` goes into `session/new` / `session/load` only.
- [N/A] ADR-005 — registry location; not touched.
- [N/A] ADR-010 — state/blackboard; the SDK holds no run state.
- [N/A] ADR-011 — reliability trio; no node changed (53-06 owns `kiro_node`).
- [OK] ADR-019 / ADR-080 — no internal dependency entries added; no version bump in this commit (the release does it).
- [OK] ADR-020 — never touches the user's global Kiro config — `launch.build_env` refuses without `kiro_home`
  (`launch.py` `build_env`, test `test_launch_options` line 329; `test_start_refuses_an_old_kiro…` asserts `ValueError`
  without `kiro_home`).
- [N/A] ADR-021 — gates; not touched.
- [N/A] ADR-026, ADR-027, ADR-028, ADR-055, ADR-085 — no server bind, web, route or report-origin change.
- [OK] ADR-029 — trust is the agreed placeholder (`_agent_spec` → `tools: []`, fails closed; §1 item 4); 53-05 owns it.
- [N/A] ADR-030, ADR-037, ADR-041, ADR-042, ADR-050, ADR-053, ADR-059, ADR-060, ADR-063, ADR-065, ADR-073, ADR-074,
  ADR-075, ADR-076 — no persistence, KB, documents, spec, lifecycle, memory or collaboration code changed.
- [OK] ADR-031 / ADR-033 / ADR-034 — chat is untouched and stays on v2 (`test_public_names_still_point_at_the_v2_client_until_53_06`);
  the v3 `_fs_write` keeps v2's `fs_write_root` containment (`_v3client.py` `_fs_write`).
- [OK] ADR-032 — credits only from `turn_completion` credit entries, summed per prompt, replay skipped, provenance
  `metered`/`unavailable`, never a number without an entry (`usage.py` `PromptUsage`; tests
  `test_usage_sums_every_engine_turn_and_skips_replay`, `test_usage_provenance_never_invents_a_number`,
  `test_load_replay_is_not_a_turn_and_not_credits`, `test_steer_at_turn_end_sums_both_engine_turns`,
  `test_cancel_during_a_model_call_is_unavailable`, `test_cancel_after_a_tool_round_is_metered`).
- [N/A] ADR-035 — run input files; not touched.
- [OK] ADR-045 — the v3 surface (model via `set_config_option`, commands via `available_commands_update`, `compact`,
  image prompts) is present; `execute_command` / `set_model` removed per F1 (`test_v3_options_follow_f1`).
- [OK] ADR-051 — the `AgentProvider` seam is untouched; the v3 client is private until 53-06.
- [N/A] ADR-068, ADR-069, ADR-082 — no lane, skill-provisioning or test-execution code changed.
- [OK] ADR-077 — no agent-system change; nothing runs with `--trust-all-tools` (v3 argv has no trust flags,
  `launch.build_argv`).
- [OK] ADR-083 — the explicit default env keeps the worker's `PATH` / `PLAYWRIGHT_BROWSERS_PATH` (spec §2 launch row);
  `close()` never signals a later (apwt) group (`test_close_during_a_running_shell_tool_kills_both_groups_and_leaves_the_daemon`).

Lessons:
- [OK] L-001 — MCP `env` list shape — the v3 client passes `mcp_servers` through as given, like v2 (`client.py:219`);
  callers still build them with `load_mcp_servers` (`__init__.py:237-254`).
- [N/A] L-002 — `kiro_node` is unchanged (53-06).
- [N/A] L-007, L-024, L-041, L-042, L-047, L-058, L-061, L-069, L-073, L-086, L-093 — web/chat/stage/skill code not touched.
- [OK] L-008 — a specific exit classification is not clobbered: `Transport._read_loop` classifies EOF via
  `eof_error`; `aclose` only sets the generic "closed" error when nothing is set (`transport.py` `aclose`); test
  `test_eof_fails_pending_requests_with_the_classified_exit`.
- [N/A] L-011 — no event/gate/topology contract or web type changes; `messages.py` changes are additive dataclass fields.
- [OK] L-016 — see ADR-032.
- [N/A] L-017 — chat trust untouched.
- [OK] L-018 (principle: accept both separators) — the reader `strip()`s each line, so `\r\n` frames parse
  (`transport.py` `_read_loop`).
- [N/A] L-021 — no tool-output path changed (`raw_input` unwrapping for `save_tool_output` is tested:
  `test_shell_auto_approve` asserts `raw_input["document"]`).
- [OK] L-025 / L-027 — ruff pinned already; `ruff check src tests` clean.
- [N/A] L-030 — no web change.
- [OK] L-044 / L-046 — typed methods only (`_session/steer`, `_kiro/session/compact`, `session/set_config_option`);
  no `commands/execute`.
- [N/A] L-051, L-056, L-057, L-099, L-100, L-101, L-111 — no release, tag, pin, CI-variable or npx use in this commit.
- [OK] L-064 — `turn_timeout` default 300 s kept as in v2 (`client.py:77`); the ceiling's message wins over the
  transport wait (`TRANSPORT_MARGIN_S`, `test_ceiling_and_cancel_grace`).
- [N/A] L-087, L-089 — no doc migration or bundle commit.
- [VIOLATION] L-088 (principle: test every guard with a bypass corpus) — the new import gates miss
  `from kiro_agent_sdk import _v3client` / `from kiro_agent_sdk import client`; see M1.
- [OK] L-092 — no `tests/__init__.py` added; `fake_engine.py` is not named `test*`.
- [N/A] L-098 — no install-origin change.
- [OK] L-104 — process listing reads `/proc` on Linux and `ps -A -ww` elsewhere (by absolute path when `PATH` lacks
  it), and logs a `ps` failure (`launch.py` `_table_from_ps`); the group identity is checked by leader pid + start
  token (`_still_ours`); fake-procfs parser test `test_linux_procfs_reader_on_a_fake_proc`.
- [N/A] L-105 — no report scrubbing.
- [OK] L-107 — every start error path closes (`start` / `load` `except BaseException: await self.close()`); the
  stderr drain task is cancelled in `terminate`; the transport's `finally` always sets `closed` and fails pending
  futures.
- [OK] L-108 — `launch.py` writes no run state; `CloseReport` is for logs/tests only.
- [OK, open item] L-112 — the fake engine and every fixture test need no Node and no kiro-cli: the autouse fixture
  asserts `shutil.which("kiro-cli") is None and shutil.which("node") is None`, and my run with `PATH=/nonexistent`
  passed; the process-tree test uses a plain Python tree. The one run in the `python:3.13` image was not done (colima
  down); it must happen before the release commit (see Not checked).

Gates (run by me at beea49b = HEAD, clean tree for these paths):
- [OK] `cd packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **181 passed** in 16.0 s.
- [OK] `cd packages/kiro-agent-sdk && ../../.venv/bin/ruff check src tests` → All checks passed.
- [OK] `PATH=/nonexistent … pytest -q tests/test_v3_replay.py tests/test_v3_units.py tests/test_v3_process_tree.py
  tests/test_public_surface.py` → 70 passed.
- [OK] `cd packages/genesis-core && ../../.venv/bin/python -m pytest -q` → **98 passed**; `ruff check genesis_core
  tests/test_core_sdk_import_boundary.py` clean.
- [OK, 1 pre-existing failure] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **1844 passed, 1 failed**:
  `tests/test_testexec_execution.py::test_regression_job_handler_starts_due_apps_and_skips_busy_ones`. The diff
  touches neither that test nor `genesis/testexec/` (`git diff --stat 143e9d2..beea49b -- tests/test_testexec_execution.py
  genesis/testexec` is empty); the test's clock is `datetime.now(IST).replace(hour=3, …)` (line 686), so it depends on
  the real date. Same as the author's base check. Unrelated to 53-04, but it reds the app gate today; it belongs in
  the backlog.
- [OK] `cd genesis && .venv/bin/ruff check genesis tests/test_sdk_import_boundary.py` → clean.
- [N/A] web lint/typecheck/test/build — no `web/**` change.

Spec points asked for specially:
- Activation fails closed on `_kiro/customAgent/not_found`: OK. `test_set_mode_dropped_fails_closed_and_never_prompts`
  shows `AgentNotActive` naming `vibe`, the `kiro.log` reason in `detail`, no `session/prompt`, and `session/close`
  after `set_mode`; a second prompt attempt raises before sending. An unlisted agent is refused before `set_mode`
  (`test_session_new_custom_agent`, `test_activation_fails_closed_without_a_confirmation`), and a `{}` answer without a
  mode update fails after 2 s.
- Credits across every engine turn, replay skipped: OK (`steer-at-turn-end` sums 4280 + 3656 ms and both turns'
  credits; `load` counts 0.015037, not the replayed 0.032).
- F17 provenance: OK (cancel mid-model → `unavailable`, cancel after a tool round → `metered`, no `turn_completion` →
  `unavailable`; `partial` never produced).
- Timeouts: OK — `timeouts.py` silent 600 s, tool stall 300 s, cancel grace 5 s, MCP readiness 65 s, activation 2 s;
  fake-clock tests for each limit, the permission hold and the ceiling tie-break.
- `close()` checks both groups and never touches apwt groups: OK — both the TERM-taking and TERM-ignoring engine
  parametrizations kill kiro, chat, engine, MCP and the running shell; the later daemon group survives; a recorded group
  whose leader identity no longer matches is skipped.
- Redaction on the joined chunk text: OK — `FrameLog.frame` replaces chunk text with a length placeholder and
  `flush_chunks` redacts the joined text (`test_frame_log_redacts_on_the_joined_chunk_text`); the 53-02 per-frame
  scrubber is not reused. The access-token test checks the token and `profileArn` never reach the log.
- The one named skip switch: OK — `fake_engine.CHECK_CUSTOM_AGENTS = False`, each skip logged, and the skip still
  fails if `customAgents` is missing; pinned by `test_the_customagents_skip_is_the_one_named_switch`.
- `mcp_failed`: the code exists but no SDK path raises it. That matches the split: 53-06 §MCP readiness owns "a failed
  server ends the turn before the prompt classified `mcp_failed`"; after start the fixture expects no turn error
  (`mcp-died.expected.json`: `stop_reason: end_turn`, error none) and the SDK marks `mcp_status[srv] = failed`. N/A here.

## Findings

### Blockers
None.

### Majors
- M1 **The F13 import gates miss `from kiro_agent_sdk import <private module>`** (`tests/test_sdk_import_boundary.py:24-31`,
  `packages/genesis-core/tests/test_core_sdk_import_boundary.py:24-31`). What: for an `ImportFrom` the gate checks only
  `node.module`, and flags it when it starts with `kiro_agent_sdk.`. Problem: `from kiro_agent_sdk import _v3client`
  (or `… import client as v2`, `… import session`) has `module == "kiro_agent_sdk"` and passes. I ran the genesis
  gate's `private_sdk_imports` on a folder holding exactly those two lines: `found: []`. That is the most natural way
  for a 53-06 change to reach the private v3 client from genesis-core, which is what this gate exists to stop (spec §3:
  "fails on any `kiro_agent_sdk.<module>` import other than the public package"). The gates' own bypass tests
  (`test_the_gate_catches_a_private_import`, both copies) do not include this form (L-088: test a guard with a bypass
  corpus). Fix: in both copies, also flag `ImportFrom` with `module == "kiro_agent_sdk"` when an alias name is not in
  `kiro_agent_sdk.__all__` (or when `importlib.util.find_spec(f"kiro_agent_sdk.{name}")` finds a submodule), and add
  `from kiro_agent_sdk import _v3client` and `from kiro_agent_sdk import client` to each bypass corpus. If skipped:
  53-06/53-07 can bind genesis or genesis-core to `_v3client` / `client` with the gate green, and the 53-07 rename of
  `_v3client.py` → `client.py` breaks them at runtime.

### Minors
- m1 **A cached `--version` probe keeps a too-old kiro-cli "too old" after the user updates it** (`launch.py`
  `probe_version`: `_version_cache[binary] = (ver, text)` is stored before `check_version` runs). Case: in a
  long-running process (the app process once chat moves to v3 in 53-07), the first start on kiro-cli 2.30.0 raises
  `kiro_too_old` with the remedy "Update kiro-cli and try again"; the user updates `~/.local/bin/kiro-cli` in place and
  tries again; the cache returns 2.30.0 and the same error repeats until Genesis restarts. `kiro_version` also stays
  stale after an upgrade. Not reachable today (workflow turns run in fresh worker processes; chat is on v2). Fix:
  key the cache on `(binary, st_mtime_ns, st_size)` of the resolved file (or drop the cache; the probe is one short
  subprocess per session start), and add a test that changes `FAKE_ENGINE_VERSION` behind the same launcher path.

### Nits
- n1 `KiroProcess.terminate` (`launch.py`): when the process table cannot be read, every recorded engine group lands
  in `skipped_groups` and is never signalled, but the closing warning fires only on `kiro_gone` / `engine_groups`, so a
  possibly surviving engine is not named in the log (only the earlier generic `ps` failure is). Add
  `or report.skipped_groups` to the warning condition.

## Not checked
- The `python:3.13` CI-image run (L-112): Docker/colima was not running for me either. The Linux `/proc` reader is
  covered only by the fake-procfs test and the real process-tree test ran on macOS (`ps` path). Run the SDK suite once
  in the image before the 53-12 release commit.
- Live kiro-cli 2.37.1 behaviour beyond the recorded fixtures (no live acceptance applies to 53-04; first live use is
  53-06's acceptance). In particular the model-fallback frame shape is still unmeasured (read defensively, logged).
- A kill during a running shell tool on the real kiro-cli tree (review m3 of 53-02): covered by the Python stand-in
  tree only, as the spec allows.

## Verdict: NEEDS_CHANGES

One major (M1): close the `from kiro_agent_sdk import <module>` hole in both import gates and add that form to both
bypass corpora. m1 is small and worth taking in the same fix commit. Everything else, including the §1 sequencing, the
fail-closed activation, credits/provenance, timeouts and the process-group close, matches the spec and is tested; all
gates are green apart from the pre-existing, date-dependent testexec failure.

---

# Re-review 53-04 — fix commit 07b6d07 over beea49b (genesis-review, 2026-11-10)

Reviewed: `git diff beea49b..07b6d07` (5 files, +106/−13; one commit, local, not pushed). Callers of the changed
function: `launch.probe_version` has one caller, `_v3client.KiroACPClient._launch` (`_v3client.py:124`), which passes
the output of `launch.resolve_binary`, which always returns an existing file. So `os.stat` succeeds on every real path
and the `(binary, 0, 0)` fallback key is reached only by a direct call with a missing file, where the probe raises and
caches nothing.

## Round-1 findings

- **M1: fixed.** Both gates (`tests/test_sdk_import_boundary.py`, `packages/genesis-core/tests/test_core_sdk_import_boundary.py`)
  now flag `from kiro_agent_sdk import <name>` and `<alias>.<name>` attribute use for any name outside
  `kiro_agent_sdk.__all__` (27 names, all classes and helpers, no module names). Both bypass corpora gained
  `from kiro_agent_sdk import _v3client`, `… import client` (mixed with a public name) and the aliased attribute form;
  the genesis copy also asserts that a public attribute (`kiro_agent_sdk.collect`) is not flagged. My own probe, run
  through both gate functions on files outside the corpora:
  - flagged: `from kiro_agent_sdk import *`; `import kiro_agent_sdk as k; k.launch.probe_version`; an alias imported
    inside a function (`def f(): import kiro_agent_sdk as sdk; sdk.client.KiroACPClient`).
  - not flagged, correctly: `import kiro_agent_sdk as k` + `from kiro_agent_sdk import KiroAgentOptions, collect` +
    `k.KiroError`.
  - not flagged: `getattr(kiro_agent_sdk, "_v3client")` and `importlib.import_module("kiro_agent_sdk" + "._v3client")`.
    Both are dynamic lookups that spec §3's import gate does not promise to catch; the literal-string form
    (`'kiro_agent_sdk._v3client'`) is still caught. Recorded under Not checked, not a finding.
  The real trees pass both gates (`4 passed` for the two gate files, which include the boundary test on `genesis/`
  and `genesis_core/`).
- **m1: fixed.** The cache key is now `(binary, st_mtime_ns, st_size)` (`launch.py:72-92`). I loaded beea49b's
  `launch.py` from `git show` and the current one side by side, and ran the same steps on each: write a 2.30.0 script,
  probe, rewrite it in place as 2.37.1 (same size, mtime +1 s), probe again. Old: `(2, 30, 0) -> (2, 30, 0)`. New:
  `(2, 30, 0) -> (2, 37, 1)`. The new test `test_v3_units.py::test_an_in_place_kiro_update_is_probed_again` covers
  exactly this, plus the cache hit on an unchanged file. A symlinked launcher (`~/.local/bin/kiro-cli` → a versioned
  file) is also handled, because `os.stat` follows the link to the new target.
- **n1: fixed.** `terminate` now warns when `skipped_groups` is non-empty, and the message says skipped groups were
  never signalled (`launch.py:313-315`). On beea49b, with an unreadable table, `mine` is empty, so `all({}.values())`
  is True and `kiro_gone` is True: no warning. The new test
  `test_v3_process_tree.py::test_an_unreadable_process_table_skips_the_engine_groups_and_says_so` therefore fails on
  that version because the warning is missing, not only because the wording changed. It asserts that the engine pgid
  is in the log, and its `finally` kills the stand-in groups, so it leaks no processes. No other test asserts the old
  wording (grep for `still alive after close`: no hits).

## Checklist delta

Only the lines the fix touches change. Every other round-1 line stands for 07b6d07, because the diff touches nothing
else.
- [OK] L-088: the guard now has a bypass corpus covering the missed forms, and a positive case for public names
  (above).
- [OK] L-104: the new close-warning path logs every recorded group that was skipped (n1).
- [OK] L-110: each new regression test was shown to fail on beea49b's code (my side-by-side run for m1, and the code
  path traced for n1), and both pass at 07b6d07.
- [OK, open item] L-112: the CI-image run is still not done (below).

## Gates (run by me at 07b6d07 = HEAD)

- [OK] `packages/kiro-agent-sdk`: `pytest -q`: **183 passed** (181 + the 2 new tests); `ruff check src tests`: clean.
- [OK] `PATH=/nonexistent pytest -q tests/test_v3_fixtures.py tests/test_v3_replay.py tests/test_v3_units.py
  tests/test_v3_process_tree.py tests/test_public_surface.py`: **104 passed**, matching the author's count.
- [OK] `packages/genesis-core`: `pytest -q`: **98 passed**.
- [OK] `tests/test_sdk_import_boundary.py` + `packages/genesis-core/tests/test_core_sdk_import_boundary.py`:
  4 passed; ruff on both files: clean.
- [N/A] The full genesis app suite was not re-run. The only app-side file changed is the gate test, which ran. The
  round-1 result (1844 passed, 1 pre-existing date-dependent testexec failure) stands.

## Findings

Blockers, majors, minors: none.

Nit (no change needed for this sub-spec):
- n2 Both gates flag a non-`__all__` dunder such as `kiro_agent_sdk.__version__` the same way as a private module. No
  code uses it today. If someone later needs it, add it to an explicit allow set in both copies; do not widen
  `__all__` for it.

## Not checked

- Dynamic lookups through `getattr` or a built-up module string (above). The spec does not ask for them, and the gate
  cannot catch them statically.
- Carried over from round 1: the `python:3.13` CI-image run (L-112) must still happen before the 53-12 release commit,
  and live kiro-cli behaviour is first exercised in 53-06's acceptance.
- 07b6d07 is local and not pushed. That is expected: the release agent pushes it.

## Verdict: SHIP

M1, m1 and n1 are all fixed, each by the smallest change, and each has a regression test that fails on beea49b's code
and passes now. Every gate I re-ran is green, with counts matching the author's.
