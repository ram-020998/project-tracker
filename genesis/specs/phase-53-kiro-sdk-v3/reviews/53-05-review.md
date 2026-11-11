# Review 53-05 — base 07b6d07, head 57a18f9 (genesis-review, 2026-11-11)

What this change does: it adds the public `TrustPolicy` and its projection into one v3 `customAgents` entry (explicit
`tools` from a measured tool-id table, `allow` rules only for auto-approved entries, from a fixed capability list).
It replaces the 53-04 `permission_mode` stopgap with a permission ladder: identity from `_meta.kiro` only, a backstop
outside the policy, an answer by mode, and the D18 skill-load exception. It also adds fixed refusal notices over
`_session/steer`, elicitation decline, the access-token responder, `check_kiro()`, and the D19 structural agent check
in the fake engine, backed by a zero-credit live probe of six caller shapes. Scope: `packages/kiro-agent-sdk` and
`scripts/spikes/53-05/`. The public names stay on the v2 client (53-04 §1), so nothing here is reachable from the app.

Inputs checked: spec `53-05-trust-and-permissions.md` and `53-01-findings.md` D9/D16/D18/D19 at project-tracker
4e51b04 (4d30829 is an ancestor; no phase-53 spec change since). Genesis head resolved: `57a18f9` (one commit over
`07b6d07`, tree clean after the review).

## Checklist

ADRs
- [OK] ADR-001 — the SDK answers requests and orchestrates nothing; the ladder (`permissions.py:160-195`) is
  deterministic program code.
- [OK] ADR-002 / ADR-004 — MCP still arrives only in `session/new.mcpServers`; the projection sets
  `includeMcpJson: false`, `includePowers: false` (`agent_spec.py:165`); `test_projection_golden` pins this on every shape.
- [N/A] ADR-005 — no registry change.
- [N/A] ADR-010 — no state or blackboard change.
- [N/A] ADR-011 — no agent node or lint change (CI lint unchanged).
- [N/A] ADR-019 — `CORE_MAJOR` untouched.
- [OK] ADR-020 — no write to the user's Kiro config. The probe runs under a private run home (53-02 `acp.py`
  `new_run`). The projection never reads `~/.kiro` (`includeMcpJson`/`includePowers` false, D6).
- [OK] ADR-021 / ADR-068 — `delete_file` is never listed. Three things guard it: the table's `never_projected`, the
  `RuntimeError` invariant (`agent_spec.py:148-150`), and the fake engine's `genesis_problems`. The negative case
  `test_customagents_are_checked_in_every_replay` appends `delete_file` and an `all` rule and sees both flagged.
- [N/A] ADR-026, ADR-027, ADR-028, ADR-055, ADR-085 — no server, web or route change.
- [OK] ADR-029 — `tools` is always an explicit list (`[]` for the empty policy, `test_the_client_activates_the_projected_id`).
  MCP entries are literal `@server[/tool]`; globs, `/`, backslashes, whitespace and empty names are refused
  (`test_policy_refuses_what_it_cannot_honour_literally`, 22 cases). Computing `node.tools ∩ allowlist` stays with the
  caller (53-06).
- [N/A] ADR-030, ADR-037, ADR-041, ADR-042, ADR-050, ADR-053, ADR-059, ADR-060, ADR-063, ADR-065, ADR-073–076 — not touched.
- [OK] ADR-031 — fail-closed. The default policy lists nothing and denies (`TrustPolicy()` mode `auto_deny`;
  `test_trust_policy_is_the_53_05_shape`). A missing identity is denied, and so is anything outside the policy
  (`test_ladder_identity_missing_is_denied`, `test_ladder_backstop_denies_outside_the_policy`). `ask` with no callback
  or a timeout, error or unknown option is denied (`test_ladder_ask_mode`).
- [N/A] ADR-032 — no credit path changed; the probe sent no prompt (`evidence/projection-probe.json` `prompts_sent: 0`).
- [OK] ADR-033 — `ask` routes to the human's `on_permission`. An `*_always` choice becomes `*_once`
  (`permissions.py:146`, `test_ladder_ask_mode`), so no engine-persisted grant outlives the confirm. The copilot shape
  keeps mutating tools unruled (golden `copilot`).
- [OK] ADR-034 — `fs/write_text_file` keeps its own `fs_write_root` gate (`test_fs_write_client_keeps_its_own_gate`).
  I also checked that all three v3 write tools write through the client. In 53-02 `w15.jsonl`, `fs_write` (frame
  99), `str_replace` (122) and `fs_append` (145) each end in a client `fs/write_text_file`. So the `fs_write` allow
  rule with `match ["**"]` in spec-style modes cannot write outside the sandbox.
- [N/A] ADR-035 — no run-input change.
- [N/A] ADR-045 — chat surface unchanged until 53-07.
- [N/A] ADR-046 / ADR-080 — no packaging or version change. `tool_ids.json` sits inside `src/kiro_agent_sdk/`, which
  the hatch wheel target `packages = ["src/kiro_agent_sdk"]` ships whole. I could not rebuild the wheel offline (no
  hatchling in the venv); see Not checked.
- [N/A] ADR-051 — the node turn path is unchanged (53-06).
- [OK] ADR-069 — skills are provisioned, not projected. D18 approves `disclose_context` + `skill` only
  (`permissions.py:103-105`).
- [OK] ADR-077 — no agent ran with `--trust-all-tools`; this review used `genesis-ctx check`.
- [N/A] ADR-082 — no test execution or browser session.
- [OK] ADR-083 — node shapes keep today's built-ins with `match ["**"]` (D16). That is the accepted risk, unchanged
  and documented in the `agent_spec.py:14` docstring.

Lessons
- [N/A] L-001, L-002 — no MCP env building, no `kiro_node` change.
- [N/A] L-007, L-018, L-047, L-058, L-061, L-069, L-073, L-086, L-093 — app or web paths not touched.
- [N/A] L-016 — no credit computation.
- [OK] L-017 — never trust-all: there is no "all tools" value, entries are in namespaced `@server/tool` form, and the
  ladder fails closed (tests above).
- [N/A] L-021, L-042, L-064 — no tool-output or turn-size change.
- [OK] L-024 — skills still come from the filesystem. The ladder only approves the engine's load request.
- [OK] L-025 / L-027 — ruff stays pinned at `0.15.20` (`pyproject.toml` dev extra); `ruff check src tests` clean.
- [N/A] L-030 — no web change.
- [OK] L-041 — the ladder and the fs gate stay two independent checks (`test_fs_write_client_keeps_its_own_gate`:
  ladder `accept`, write refused).
- [OK] L-044 / L-087 — the real CLI was probed: six projected shapes activate on kiro-cli 2.37.1 and the bad-effect
  control is dropped (`kiro_log_drops` holds exactly the control's `invalid_enum_value`).
- [OK] L-045 — the human-confirm backstop is kept in `ask`.
- [N/A] L-046, L-051 — not touched.
- [OK] L-056 — `git show --stat 57a18f9` lists all 19 files, including `tool_ids.json`, `tool_ids.py` and both probe
  fixtures; the tree is clean.
- [N/A] L-057 — no tag or pin.
- [OK] L-088 — there is a bypass corpus (`SKILL_BYPASS`, 13 cases × 3 modes) and a positive corpus
  (`test_skill_load_is_approved_in_every_mode`, the real `w1.jsonl` shape × 3 modes × 2 policies). I mutation-checked
  it myself: an either-field-or-title ladder injected through a pytest plugin (`/tmp/53-05-review-mut/mut_either.py`)
  gives **39 failed, 4 passed** on `-k skill`. Every bypass case bites.
- [OK] L-089 — no bundle; the verifying reads were done after the gates exited.
- [OK] L-092 — no `tests/__init__.py`; `fake_engine.py` is not named `test*`.
- [N/A] L-098, L-099, L-100, L-101, L-104 — not touched (the probe uses no `npx`, and no CI-variables API was called).
- [OK] L-105 — no reports here. I scanned the probe evidence and fixture for `arn:aws`, `accessToken`, `Bearer` and
  home paths: 0 hits.
- [OK] L-011 — the fake engine's checks read the 53-02 measurement (`tests/fixtures/v3/tool-ids.json`), not the
  SDK's copy (`fake_engine.py` `_TABLE`). `test_package_table_matches_the_53_02_measurement` pins the SDK table to the
  measurement, and `check_w4_model` checks the fake's W4 model against every recorded `session/new` answer.
- [OK] L-110 — I re-ran every claimed gate at 57a18f9 (below). The two unexercised behaviours (`@server`
  reachability, built-in `**` matching) are stated as limits, not claimed.
- [OK] L-111 — no live acceptance is due for an SDK-only sub-spec that nothing reaches; the limits carry to 53-06/53-11.
- [N/A as a gate here, open] L-112 — the python:3.13 CI image was not run (53-12 precondition). The v3 tests pass
  with no kiro-cli or Node on PATH (below).

Gates (run by me at 57a18f9)
- [OK] `cd packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **319 passed** in 30.5 s.
- [OK] `cd packages/kiro-agent-sdk && ../../.venv/bin/ruff check src tests` → All checks passed.
- [OK] `PATH=/nonexistent … pytest -q tests/test_v3_trust.py tests/test_v3_replay.py` → **165 passed**. These two
  files only; the author's 229 covers more v3 files.
- [OK] `cd packages/genesis-core && pytest -q` → **98 passed**. `ruff check genesis_core` (the CI scope) is clean.
  `ruff check .` shows 5 pre-existing errors in genesis-core `tests/`, which are outside the CI scope and untouched by
  this diff.
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **1845 passed** in 596 s; `ruff check genesis` clean.
- [N/A] web `lint`/`typecheck`/`vitest`/`build` — no web file changed.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **`mcp-allow` replays under a policy that contradicts its recording** (`tests/test_v3_replay.py:379-380`).
  What: `Replay(tmp_path, "mcp-allow")` has no recorded `session/new` (the fixture starts at the prompt), so
  `policy_for` is skipped and the client projects the empty `TrustPolicy()` (`tools: []`). Problem: §8 lists
  `mcp-allow` among the replays that prove the projection. The recording is "three MCP tools with allow rules: no
  permission request" (fixture header), but the replayed agent lists none of those tools and no rule. The test
  passes only because the fake does not enforce `tools`. It proves nothing about the `mcp` allow-rule projection,
  which no other replay covers: every other MCP fixture asks. Fix: pass the matching policy, e.g.
  `trust=TrustPolicy(mcp_tools=("@probe/env", "@genesis-kb/list_applications", "@blackboard/list_tool_outputs"),
  auto_approve=<same>)`. Then the prelude agent the fake checks is the one that yields the recorded no-ask turn.
  If skipped: the replay would keep passing even if the MCP rule projection regressed.

### Nits
- n1 **`Decision.kind` has no reader** (`permissions.py:124`). The ladder threads the correlated `kind` into every
  `Decision`, but `_v3client._permission` reads only `outcome`, `cause` and `notice`, and `PermissionRequest` has no
  kind field (F1). Only `test_ladder_ask_mode` reads it. Either drop the field or note it as kept for 53-07's confirm
  card.
- n2 **`warn_if_unverified` docstring says "newer"** (`tool_ids.py:102`). The code warns for any unverified version.
  It behaves correctly because `check_version` refuses older versions first (`_v3client.py:133-135`), but the
  docstring should say "unverified".

## Not checked
- `@server` (whole server) in `tools` was not checked. It activates live, but no tool call under it ran (no prompt).
  This is the Phase 51 node shape (`@blackboard`), so 53-06's first live node turn must show a blackboard tool being
  called. KiroCrew uses the same form on KAS (`src/kiro_crew/acp/kas_agents.py:18-25`: "`@server` entries in `tools`
  do resolve wherever the server was declared").
- Built-in `match: ["**"]` rules for `shell`/`fs_write`/`web_*` were not checked: they activate, but whether they
  match was not exercised. If they don't match, the engine asks and the ladder approves (functionally safe; the cost
  is extra round trips).
- How the live engine handles `_session/steer` while a permission request is pending was not checked: answer
  latency, and whether a notice landing at turn end starts a second metered turn (53-02 W7b). The fake answers at
  once. The 2 s bound keeps the answer from hanging (`test_a_failed_or_slow_notice_never_blocks_the_answer`).
- The live engine's reaction to the `-32000` "not signed in" answer for a failing `on_access_token` was not checked.
  Only the `-32601` no-callback path was measured (53-02 `w12-no_answer.jsonl`).
- I did not rebuild the wheel (no hatchling in the dev venv, offline). `tool_ids.json` lies inside the shipped
  package folder, and the author reports it present in a built wheel.
- The python:3.13 CI image was not run (L-112; a 53-12 precondition).

## Verdict: SHIP

There are no blockers and no majors, and every gate is green at 57a18f9. m1 should be fixed in this sub-spec or
early in 53-06, which first depends on the MCP allow rule. n1 and n2 are optional. Carry the first two Not-checked
items into 53-06's live node acceptance.

---

## Round 2 (delta 57a18f9..fe25e9e) — genesis-review, 2026-11-11

**Commit id.** `fe25e9e` does not exist in the genesis repo (`git diff 57a18f9..fe25e9e` → "unknown revision"). The
only commit over 57a18f9 is **`466d51a`** (HEAD of master, local, ahead of origin by 10, tree clean). Its message is
"fix(sdk,53-05): review m1/n1/n2". I reviewed `57a18f9..466d51a`. `git show --stat 466d51a` lists 4 files, all in
`packages/kiro-agent-sdk` (`permissions.py`, `tool_ids.py`, `tests/test_v3_replay.py`, `tests/test_v3_trust.py`),
16 insertions and 5 deletions. genesis, genesis-core and the parser are untouched, so their round-1 gate results
(1845 / 98) still hold.

### Findings from round 1
- **m1: resolved.** `test_mcp_allow` (`tests/test_v3_replay.py:379-387`) now passes
  `TrustPolicy(mcp_tools=<the three expected tools>, auto_approve=<same>, mode="auto_deny")` and asserts two things:
  the projected `tools` equal the three `@server/tool` names, and `permissions.rules` is exactly one
  `{"capability": "mcp", "match": [...], "effect": "allow"}`. I checked that against the recording itself.
  `scripts/spikes/53-02/evidence/w2.jsonl` line 3 (`session/new`, agent `genesis-w2`) carries the same `tools` and
  the same single rule, `match ["probe/env", "genesis-kb/list_applications", "blackboard/list_tool_outputs"]`, in
  the same order. The asserts read `_agent` from a fresh client built from the same options. The replay's client
  computes the same value, because `_v3client.py:104` projects in the constructor and the projection is
  deterministic. A regression in the MCP rule projection now fails this test directly. The replay still makes no
  permission request (`not [... "outcome" ...]`), which matches the recording's `permission_requests: 0`.
- **n1: resolved (comment option).** The `Decision.kind` comment says the field is logged with a deny and kept for
  53-07's confirm card (`permissions.py:124`). `_deny` logs it with `%r` (`permissions.py:140-141`), so a control
  character in an engine-supplied kind is escaped in the log. The log line carries only the cause, the identity
  name and the kind: no title, no raw input. `test_ladder_backstop_denies_outside_the_policy` asserts the log has
  `outside_policy` and `'execute'` but not the title text `rm -rf`. On the 57a18f9 `_deny`, `'execute'` is not in
  the log line, so the new assertion would fail there.
- **n2: resolved.** The `warn_if_unverified` docstring (`tool_ids.py:102-103`) now says "not a version the table was
  measured on" and notes that `launch.check_version` refuses older versions first. The code is unchanged.

### Regression check
- The delta changes no signature or return value. `_deny` keeps its signature and `Decision` keeps its fields, so
  there are no new callers to read. The only behaviour change is the log text.
- `.venv/bin/python -m pytest -q` in `packages/kiro-agent-sdk` at 466d51a → **319 passed** (29.2 s). This is the same
  count as round 1: the two changed tests were edited, not added.
- `ruff check src tests` → All checks passed.
- `env PATH=/nonexistent pytest -q` on the five v3 files (`test_v3_fixtures`, `test_v3_process_tree`,
  `test_v3_replay`, `test_v3_trust`, `test_v3_units`) → **235 passed**.
- The two changed tests pass on their own (`-v`: `test_mcp_allow`, `test_ladder_backstop_denies_outside_the_policy`).
- L-056: the commit holds all four changed files and the tree is clean. L-092: no new test module.

### Not checked (round 2)
- The round-1 Not-checked items are unchanged and still carry into 53-06's live node acceptance. They are the
  `@server` reachability and the built-in `match ["**"]` matching.

### Verdict: SHIP

All three round-1 findings are resolved, and the delta adds no new finding. Every gate I re-ran at 466d51a is green.
The brief's `fe25e9e` should read `466d51a` in the sub-spec's As built.
