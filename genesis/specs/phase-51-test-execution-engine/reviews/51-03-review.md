# Review 51-03 §2b (D3c, session 3) — genesis base 5a15d41 → 36cfe6f · playwright-appian base 2b1fbf9 → 395b2ac (genesis-review, 2026-11-02)

Scope: the §2b spike evidence (L1, S4, S8, S9, S10, S11, P10), the spike harness under
`genesis/scripts/spikes/51-03/` (commits `87efc73`, `36cfe6f`), and `playwright-appian` D-114 (commit `395b2ac`,
0.3.0, unreleased). The older PARTIAL As built (S1/S5/S6) is context only. Live QA experiments were **not** re-run:
every claim could be judged from the committed evidence plus the code. The uncommitted `.gitignore` line in
playwright-appian pre-dates this work and is excluded.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| playwright-appian `npm run lint` | clean (eslint `--max-warnings 0`, prettier "All matched files use Prettier code style") |
| playwright-appian `npm run typecheck` | clean (`tsc --noEmit` + ESM config) |
| playwright-appian `npm run build` | ok |
| playwright-appian `npm test` | **95 files / 1399 tests passed** (matches the author's claim) |
| genesis `.venv/bin/ruff check scripts/spikes/51-03/` | "All checks passed!" (ruff 0.15.20) |
| Live e2e (`npm run e2e*`) | not run (as the brief says); the live S8 run used the packed 0.3.0 tarball (`d3c-s8.json` `install`, `version` = `0.3.0`) |

## Secret scan

A Python scan that reads `SPIKE_PASSWORD_A` and `SPIKE_USER_A` from its own `os.environ` (values never on a command
line, never printed) checked every file changed in both diffs (29 files) plus the whole spike folder, the Phase 51
spec folder and `playwright-appian/planning/` (78 files): **0 hits** for the password, 0 for the user name. A pattern
scan of the 29 changed files for JWTs, `glpat-`, AWS keys, `sk-` keys, Bearer tokens, `JSESSIONID`/CSRF values and long
cookie `"value"` strings: **0 hits**. `d3c-s4.json` lists environment variable **names** only; `d3c-p10.json` shows
`--env JIRA_TOKEN` as a name (docker's pass-through form), no value. The saved login (`.auth/rec-a.json`) was deleted
by the harness (`run_d3c.py` `state.unlink()`) and is not committed.

## Checklist

### Brief-named ADRs
- [OK] ADR-002 / ADR-004 (agent = narrow Kiro turn over ACP, per-node MCP injection) — the harness calls the real
  `genesis_core.nodes.agent.kiro_node` (`d3c.py:_turn`), with `PlatformContext(mcp=None)` so only the blackboard server
  is injected; `@blackboard/list_tool_outputs` + `save_tool_output` ran (`d3c-l1.json` `tool_calls`). **But P10 shows
  today's turns also load the global `~/.kiro/settings/mcp.json` servers** (`d3c-p10.json`: `docker run … --env
  JIRA_TOKEN …` under the harness; reply lists testcase-mcp, jira, blackboard). This is pre-existing product behaviour
  against the spirit of ADR-004 ("never rely on … a global Kiro mcp.json"), not introduced by this diff — see finding 6.
  I confirmed the global file holds exactly `jira` (docker) and `testcase-mcp` (bash), both enabled (keys/commands
  only), matching the hard-coded `global_mcp_servers` in the evidence.
- [OK] ADR-012 (program steps own subprocesses; app never imports workflow Python) — no product code changed
  (`git diff --stat` touches only `scripts/spikes/51-03/`); session open/close/replay are subprocesses with argv lists
  (`harness.apwt`, `d3c.replay`).
- [OK] ADR-020 (never mutate global Kiro config) — nothing writes `~/.kiro`; `new_run` even deletes the sandbox-era
  `<run>/.kiro/settings` (`d3c.py:new_run`). P10 is about reading, not writing.
- [OK] ADR-069 (skills provisioned into `<cwd>/.kiro/skills/`) — `kiro_node(skills=[…])` with
  `ctx.extras['skill_source']` (`d3c.py:skill_source`) resolving `playwright-appian` to the workspace package and
  `genesis-test-authoring` to the spike draft; `skills.provisioned` event lists both; the agent's first call read
  `<run>/.kiro/skills/{genesis-test-authoring,playwright-appian}/SKILL.md` (`d3c-l1.json` `call_1`); canary line in the
  reply, not in the prompt (`canary_in_reply: true`; `l1_prompt` has no canary).
- [OK] ADR-077 (no `--trust-all-tools` for role agents) — the workflow turn's `kiro-cli acp --trust-all-tools`
  (`d3c-p10.json` processes) is `kiro_node`'s existing default (`kiro_agent_sdk/client.py:169-170`), unchanged; no
  role agent was launched with it.
- [N/A — not yet recorded] ADR-083 (accepted risk, D3c) — `genesis-ctx adr ADR-083` → "unknown ADR id"; it is
  written in 51-04. The spike's posture matches 51-01 D3c (4) and 51-05 §4a. See finding 6 for what ADR-083 should name.

### `genesis-ctx check` — ADRs (both repos list the same set)
- [N/A] ADR-011 — reliability trio: spike harness, no workflow/graph shipped; 51-09 must wire validator + retry + escalation around the explore node.
- [N/A] ADR-019 — no genesis-core change; `CORE_MAJOR` untouched.
- [N/A] ADR-026 — no server/bind change.
- [N/A] ADR-046 — no install/launcher change.
- [N/A] ADR-063 / ADR-065 / ADR-074 — no collaboration or KB-sync code.
- [OK] ADR-077 — see above.
- [OK] ADR-080 — playwright-appian is its own repo (51-01 D19); genesis gets no package/dependency change.

### Lessons
- [OK] L-017 — no chat trust change; the workflow-turn trust-all is today's behaviour, flagged by P10, not widened.
- [OK] L-025 / L-027 — ruff run from the pinned dev venv (0.15.20); no CI change.
- [N/A] L-030 — no web change.
- [N/A] L-045 — no chat surface change.
- [N/A] L-051 — no shipping change.
- [OK] L-056 — `395b2ac` contains every source, test and doc file the As built lists (17 files; the CHANGELOG, README,
  DECISIONS, TRACKER, version.ts, package.json + lock all in the one commit); genesis `87efc73` holds all 11 spike files.
- [N/A] L-057 — nothing tagged; the 0.3.0 vendoring pin is 51-13's job (TRACKER notes D19 ordering).
- [N/A] L-087 — no doc migration.
- [OK] L-088 — §2b needs no bypass corpus (ADR-083 accepted risk); S4 used an outside scan with a positive control
  (6 operator processes found holding the password, `d3c-s4.json` `operator_processes_with_password`), which is the
  right shape for a "can't see X" claim.
- [OK] L-089 — the reviewer's build ran before the tests in one gate chain as the brief specifies; no bundle commit involved.
- [OK] L-092 — no `tests/__init__.py`, no non-test symbol named `test_*` in the spike.
- [N/A] L-098 / L-099 — no internal package or version-keyed behaviour.
- [OK with note] L-100 — no CI-variables API call; no secret in any output or file. The As built honestly reports a
  sub-second slip where the password was a `grep` argv (process list only, not agent output). The value did not reach
  agent output, so L-100's "rotate" trigger is not strictly met; rotating the QA test user's password is still the
  cautious choice (user's call).

### playwright-appian invariants (genesis-playwright-appian-dev skill)
- [OK] D-02 (no LLM; undecidable = explicit `// TODO`) — the change is pure option plumbing; the generator's only
  change is one boolean in `analyze.ts:208-212`.
- [OK] D-04 (label-only generated code) — a signed-in start emits the existing `await login(page)` helper
  (`recorder-state.test.ts` "a signed-in start makes the spec sign in"); no raw locator added.
- [OK] D-05 (Appian knowledge only in `taxonomy.ts`) — no Appian element knowledge added; storage state and channels are Playwright concepts.
- [OK] D-01 / D-69 (one package, one bin) — unchanged.
- [OK] Trace schema v1 additive-only — `start_signed_in` is optional in `types.ts`, `trace-keys.ts` (`'optional'`),
  and `trace-schema.ts` (boolean, not required); `buildTrace` writes it only when true (`consolidate.ts:551`); test
  "buildTrace writes start_signed_in only when asked; the trace stays schema-valid". Schema objects are open (BIBLE §1.5 L38).
- [OK] Default behaviour unchanged — `recorderLaunchPlan()` with no browser = `[chrome, chromium]`, the old
  try-Chrome-then-Chromium (`recorder/index.ts:43-47`, test "keeps the original default"); `detachedRunArgs` adds
  neither option when unset (test "adds neither option when unset"); live S9 `default` launched
  `/Applications/Google Chrome.app` (`d3c-s8.json` `s9.default`).
- [OK] Exact pins / registry — no dependency change; `package.json` and `version.ts` both 0.3.0 (`package-meta` invariant passes).
- [OK] DECISIONS row format — D-114 has the five house columns (Decision · Who, when · Why · Enforced/documented),
  next free id, placed in §8 "Recording and generation behaviour". It is a new decision, so no BIBLE change is required.
- [OK with nits] CHANGELOG (Unreleased, two "Added" bullets citing D-114), README "Recording" (two bullets), TRACKER
  (unreleased 0.3.0 note) — see finding 8.

### D-114 correctness
- `--state` existence is checked before `--detach` or a launch (`cli/index.ts` action, first statement); test "a missing
  saved login fails with exit 1 … before launching a browser" asserts no `SESSION:` line.
- Detached path resolves `--state` to an absolute path before the child's cwd could differ (`sessions.ts:detachedRunArgs`; test asserts `join(process.cwd(), 'rel/role.json')`).
- `storageState` is applied with or without CDP (`recorder/index.ts:238-240`); the real-browser test proves it over
  CDP with a cookie-gated local site, and a control run without `--state` sees the login form.
- `--browser` choices are validated by commander (exit 2 on `firefox`, tested).

### Spike evidence vs claims

| # | Claim | Verdict | Evidence checked |
|---|---|---|---|
| L1 | PASS: program `open --login` → one `kiro_node` turn → spec replays | **Supported** | `d3c-l1.json`: open rc 0, 10.6 s, "OK: signed in"; turn `stop_reason: end_turn`, 26 tool calls, 1 attempt; every apwt call uses the prompt's `npx --no-install apwt` prefix; record-stop `STEPS: 3 TODOS: 1 EXPECTS: 1`; replay rc 0 "1 passed (12.2s)" (13.6 s wall). `fill` was not exercised (no text box; the agent checked with `find "Search"` and `snapshot --all`) — honestly reported. |
| S4 | PASS: no password in the agent's view | **Supported** (wording nit, finding 5) | `d3c-s4.json`: `env_has_password: false`, no `APPIAN_*`/`SPIKE_*` names; ps: 925 processes, turn kiro-cli pid 17445 found from shell pid 17609, daemon 17333, 11 run processes, 0 with the password; 6 operator processes with it (positive control); control files `token`, `state.json`, `daemon.log` listed, `control_has_password: false`; `password_in_tool_results: false`; `files_with_password: []`. Mechanism: `agent_env()` strips `SPIKE_*` before `kiro_agent_sdk` copies `os.environ` (`client.py:191`), which models a worker that never holds the password. |
| S8 | PASS with D-114 | **Supported** (findings 2, 3) | `d3c-s8.json`: state-save 5 cookies, `state_has_password: false`; `record start --detach --cdp … --state …` rc 0; person `SIGNED_IN: true`; trace `start_signed_in: true`, 3 actions, `has_password: false`; spec has `await login(page)`; replay "1 passed (10.7s)". The `--cdp` limitation is correct: `newContext()` over CDP is a fresh context (`recorder/index.ts` before the change). |
| S9 | PASS with D-114 | **Supported** | `d3c-s8.json` `s9`: `--browser chromium` launched `~/.genesis/testing/browsers/chromium-1217/…/Google Chrome for Testing`; default launched system Chrome; L1 open says `chromium 1280x900`; the template's `playwright.config.ts` has no `channel`/`browserName` (reviewer grep). |
| S10 | Measured | **Supported** | `d3c-l1.json` telemetry: 194 225 ms, 26 calls, 8.44 credits `metered`, context 5.97 %. One sample; the As built says so and asks 51-09 to re-measure. |
| S11 | PASS | **Supported** | see ADR-069 line above; `artifact.saved` in `event_types`, `saved_action_log: true`, `documents_saved: 1`. |
| P10 | YES, global servers load | **Supported** (finding 1) | jira's docker process under the harness; the agent lists 35 tools from testcase-mcp (22), jira (10), blackboard (3). The evidence's `testcase_mcp_started: false` and `blackboard_started: false` are false negatives of the poll (see finding 1); blackboard's tools demonstrably ran in L1. |

Outcome rule (§2b: L1, S4, S11 must pass): **all three pass on the evidence; the rule is applied honestly.** S8/S9
gaps were closed as an additive `playwright-appian` change, as §2b allows.

Recipe vs specs: the As built recipe matches 51-05 §4a (ordinary `kiro_node`, `npx --no-install apwt` from the
workspace export, program-owned sessions with `--allow-host`, `--mode full`, `--browser chromium`, `--artifacts` and
`PLAYWRIGHT_APPIAN_HOME` in the run folder, credentials only in the `open --login` subprocess, the workspace's skill +
`genesis-test-authoring`) and 51-01 D3c (1)–(4). The spike omits 51-05 §4's `--json`, `--upload-root` and
`--idle-timeout 30` session defaults; that is fine for a spike, and 51-05 owns them. The new fact that the prompt
prefix must carry `PLAYWRIGHT_APPIAN_HOME` (the agent shell inherits the worker's env) is something 51-05 §4a should
state explicitly.

## Findings

### Blockers
None.

### Majors
None.

### Minors
1. **P10 evidence flags contradict the conclusion and are unexplained.** `evidence/d3c-p10.json:22-23` records
   `"testcase_mcp_started": false` and `"blackboard_started": false`, yet the reply lists both servers' tools and L1
   proves the blackboard works. Cause: `run_d3c.py:_tree` cuts each command to 120 characters (the blackboard is a
   Python process whose long framework path is truncated first; `processes_under_harness` shows two truncated
   `Python.app/…` lines) and `e_p10` matches substrings. Fix: one sentence in the As built P10 row saying the
   conclusion rests on the jira docker process plus the tool list, and that these two flags are poll false negatives.
   No re-run needed.
2. **The recording recipe (As built step 6) was not run live as written.** Step 6 says `record start --detach
   --browser chromium --state <file>`; the live run used `record start --detach --cdp <probe browser> --state <file>`
   (`d3c-s8.json` `record_start.argv`), and S9 ran `--browser chromium` without `--state`. Both halves use the same
   `newContext({storageState})` call, so the risk is low. Fix: say this in the As built and make the exact
   `--browser chromium --state` command a 51-07 live-acceptance step.
3. **The S8 replay proves the signed-in start, not the recorded flow.** The generated spec is `link('Vendors').click()`,
   a `// TODO: no label for multi_dropdown`, and `// TODO: assert` (`d3c-s8.json` `spec_text`). This meets S8's criterion
   ("a trace whose spec replays"), but "replays green" here means sign-in plus one click. As built finding 5 names the
   TODO. Fix: add "replay covers sign-in + navigation only" to the S8 row.
4. **`d3c-l1.json` keeps a failed S4 attempt that reads like an empty pass.** Its `s4` block has `tool_calls: []`,
   `env_present: false`, `processes: 0` (the terse-prompt attempt of As built finding 7). The committed `s4_prompt` is the
   later, honest version, so this block cannot be reproduced from the code. Fix: note in the As built (or the README)
   that the S4 result is `d3c-s4.json` and that the `s4` block in `d3c-l1.json` is the failed first attempt.
5. **S4 wording claims more than the S4 run scanned.** The As built says "no tool result, event or file in either run
   folder has it". `d3c-s4.json` is a rescan (`"rescan": true`): its tool results and files were scanned, its turn's
   events were not (no `password_in_events` key). L1's events were scanned (`password_in_events: false` for both turns).
   Fix: "no tool result or file in either run, and no event of the L1 run".
6. **P10 needs routing now, not only as Phase 52 input.** Every `kiro_node` turn today gets the user's global MCP
   servers under trust-all; on this machine that includes a Jira server fed `JIRA_TOKEN` and testcase-mcp with Jira
   write tools (`add_jira_comment`, `update_jira_fields`, `create_jira_issue`). Phase 51 puts live QA page text (a new
   untrusted input) into exactly such turns. This is pre-existing behaviour against ADR-004's "never rely on … a global
   Kiro mcp.json" and not caused by this diff, so it does not block the spike. Fix: the spec agent records it in ADR-083
   (51-04) as a named part of the accepted risk (or scopes a 51-xx mitigation such as an explicit agent config with no
   global servers, if Kiro supports one), and the docs agent takes the As built's lesson candidate.

### Nits
7. `record start --browser` is silently ignored with `--cdp`. Only the `RecorderOptions` doc comment says so
   (`src/recorder/index.ts:51`); the option's help text (`src/cli/index.ts`, the `new Option('--browser <name>', …)`
   line) does not. Fix: append "(ignored with --cdp)" to the description, or exit 2 on the combination.
8. `planning/TRACKER.md:13-17`: "Working tree: clean. Everything is pushed to `main`" now sits directly above a note
   that 0.3.0 is committed locally and not pushed, and "(D-01 … D-112)" is stale (D-113 already existed; D-114 is new).
   Fix: "Everything up to `v0.2.0` is pushed; 0.3.0 is local" and "D-01 … D-114".
9. The hidden `record __run --browser <name>` has no `.choices()` (`src/cli/index.ts`, `__run` command). It is
   internal and an unknown value only fails the launch. Optional: reuse the same choices.

### Notes for the user (HITL, not findings)
- Consider rotating the QA test user's password because of the reported sub-second argv slip (As built "Process slip").
- The As built's "Review / commits" subsection can be filled with: genesis `87efc73`, `36cfe6f` (base `5a15d41`);
  playwright-appian `395b2ac` (base `2b1fbf9`), unreleased 0.3.0, D-114; review
  `reviews/51-03-review.md`, verdict **SHIP**, minors 1–6 and nits 7–9 open (doc-only except 7 and 9). As reviewer I did
  not edit the sub-spec.

## Verdict: SHIP

No blockers, no majors, and every gate is green. L1, S4 and S11 pass on the committed evidence, and no credential is
in any committed file. D-114 is additive and leaves the default behaviour unchanged, with tests for each new path.
Findings 1–5 are As built wording fixes. Finding 6 is a routing item for 51-04/ADR-083. Findings 7–9 are small
playwright-appian polish that can ride with the 0.3.0 release.
