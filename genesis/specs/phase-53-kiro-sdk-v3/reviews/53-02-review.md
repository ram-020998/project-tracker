# Review 53-02 — base 62537c2 (genesis-review, 2026-11-10)

Sub-spec: `specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md` (re-specced in `4ae2915`, `2866d81`; As built in
`3fca98c`, `e82fd30`, `5ce94a3`). Diff: genesis `62537c2..a13798d` (`c7c05b2`, `a885ca3`, `a13798d`; local, not pushed;
HEAD = `a13798d` on `master`). 127 files, +36 147 lines. No Kiro credits were spent and QA was not driven in this
review. Every check below read files only, or ran the offline gates.

## How I checked

- `genesis-ctx check --since 62537c2 --repo genesis`: areas `release-ci`, `security` (always-on); no area gates mapped.
- `git diff --name-only 62537c2..a13798d`, filtered to drop `scripts/spikes/53-02/`, `packages/kiro-agent-sdk/tests/fixtures/v3/`
  and `test_v3_fixtures.py`: **empty**. Nothing outside the expected outputs changed.
- Gates: `cd packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **110 passed in 0.18 s**;
  `../../.venv/bin/ruff check . ../../scripts/spikes/53-02/` → **All checks passed!**
- In-process privacy scan (`/tmp/53-02-review-scan.py`, prints only categories and counts) over all 125 committed
  `.json/.jsonl/.py/.md` files. Secrets loaded in process: every `auth_kv` token in kiro-cli's `data.sqlite3` (8 values
  plus 40-character prefixes), the profile ARN, its account id and its tail, the 2 QA test users' user names and
  passwords (`kb_test_users` + SecretProvider), the login name and its first part, the hostname, and the names under
  `~/.kiro/{skills,agents}`. A second scan joined the streamed chunk texts per file, because a value split across
  chunks escapes a per-frame scrub.
- Independent recomputation of every fixture's `expected.json` from its frames (`/tmp/53-02-review-fx.py`), of the credit
  total from every `turn_completion` in the evidence (`/tmp/53-02-review-credits.py`), and spot reads of the W1, W4, W7,
  W14, W15, W16 and W19 frames and summaries.

## Checklist

### Brief items

- [OK] **1. No product code changed.** The filtered `--name-only` list is empty: `kiro_agent_sdk/src`, `genesis/genesis`
  and `packages/genesis-core` are untouched.
- [OK] **2. Secrets and privacy.** Scan totals: kiro tokens 0, profile ARN / account id 0, QA user names 0, QA passwords 0,
  login name 0, hostname 0, e-mail 0, `sess_` 0, `toolu_` 0, JWT 0, `arn:aws` 0. The only `/Users/` hit is the regex in
  `make_fixtures.py:362`. The only raw UUIDs in files are the app UUID in `gate.py`/`rest.py` (source code).
  `<REDACTED>` appears only in `w12-answer.jsonl` and `access-token.jsonl` (the `accessToken`), with the ARN as `<SECRET_2>`.
  No `<SECRET_n>` appears in the W3/W16 files, so neither the password nor the user name reached a frame. W1: both
  `list_directory` calls on `~/.kiro` and `~/.kiro/skills` (t 13.80 and 16.43) have `rawOutput`/`content` replaced by the
  `drop_user_kiro` marker (4 occurrences). No `[DIR] appian` (the one personal skill) appears anywhere. The 130 hits for
  that skill name are false positives: it is the 6-character substring `appian`. The model's reply quotes only the two
  canaries. Joined-chunk scan: no path, login, e-mail or token. Only steer ids are split (finding m6).
- [OK] **3. Loader test with no Node / kiro-cli (L-112).** `_no_tools_on_path` sets `PATH` to an empty tmp folder and
  asserts `shutil.which("kiro-cli") is None and shutil.which("node") is None` (`test_v3_fixtures.py:43-46`). 110 passed
  and ruff is clean (above). No run in the CI image (declared in the As built; Docker down). The test reads files only.
- [VIOLATION] **4. As built accurate against the evidence.** Most of it checks out. W4's "dropped" description
  contradicts the frames (**M1**). Three claims have no evidence behind them (m1, m2, m3). Details:
  - W1 FAIL + root cause: `w1.json` `result: FAIL`, `skills_listed` = genesis-test-authoring only; `w1b.json` as-shipped vs
    quoted → `[genesis-test-authoring, playwright-appian]`, log `bad indentation of a mapping entry (3:112)`. OK.
  - W2: all three servers `connected` (3.79 / 3.81 / 4.58 s); `env_reached_genesis_kb` and `env_reached_probe` both
    true. OK. W3: `result PASS`, `npx_bin <RUN>/checkout/node_modules/.bin/apwt` 0.3.0 vs PATH 0.2.0, 42 023 bytes,
    0.57 / 0.83 s, two `run_command` asks with `consent.capability shell`. OK. W5: per-case table matches `w5*.json`
    (0.050547 on cancel-after-tool, `[]` on w5a, `aborted`). OK.
  - **W4: the "dropped" half is wrong** (M1).
  - W6–W13, W17, W18 numbers match their summaries (W9 0.134 / 0.078, 10.04 / 5.04 s; W12 8 requests from 0.669 to
    0.772 s; W17b `failed` at 62.82 − 2.81 = 60.0 s; W18 decline). W12's middle case has no evidence (m1).
  - **Credits 7.72: OK.** Non-replay credit entries sum to 7.9415. Minus 0.2511 of W7 entries repeated in `w8.jsonl`, that
    leaves 7.6903. Plus W4's replaced run (0.03) gives 7.72. W6's replayed 0.0324 is excluded. Every figure comes from a
    `turn_completion` credit entry (ADR-032). Two rounding slips are in n1.
  - **W14 guidance: OK.** `w14.json` `real_runs`: silence max 287.1 s, MCP max 18.7 s, shell max 37.9 s, longest turn
    736.8 s. Silence ≥ 600 s and tool stall ≥ 300 s stay above every measured value, so no normal 900 s Phase 51 turn is
    ended early. The cancel grace (0.01–0.03 s measured, 5 s suggested) is fine.
  - **W16: OK as measured.** `w16.json`: kiro groups `[88535, 88544]`; `kiro_left_after_kill []` at 0.54 s;
    `apwt_alive_after_kiro_kill 5`; `procs.reap` → `apwt_left_after_reap []`. Its reach is narrower than the 53-04 bullet
    says (m3).
  - **W7: OK on images.** The steer frames show `_session/steer` with a content list → `-32603 "_session/steer: missing or
    empty message"`. So F16 (53-01 §9.5) is forced to text only, as stated. The note on delivery timing is incomplete (m4).
  - **"Changes for 53-04..53-07":** W9 (no off switch; `ConfigurationSetRefusedError` ×4 in `w9state.json`), W14, W15
    (table matches `w15.json` `permission_by_call`) and W19 (a) 3/3, (b) 0/3 and (d) all match. Problems: the W4 bullet
    (M1), the W16 bullet (m3), the W15 path-scoping claim (m5) and the W19 (c) "also for a later `session/load`" (m2).
  - Fixture list and its deviations from §4: OK. There are 28 pairs plus `tool-ids.json`. The `model-fallback` →
    `model-unavailable` substitution, the `mcp-status-*` split, the `unknown-request` source and the 5 additions are all
    as stated.
- [VIOLATION] **5. Fixtures mirror recorded frames (L-011).** Frames are cut verbatim from the evidence. Only thought
  chunks and the listed noise notifications are dropped, and strings over 6 000 characters are cut by the scrubber.
  Recomputed `expected.json` values match the frames for all 28 fixtures: credits, stop reasons, statuses, permission
  ids and resources, MCP final states (`final == expected` true for both status fixtures), the `available-commands` names,
  context %, the load replay credit split (0.047479 − 0.032442 = 0.015037), and 2 engine turns with 0.060572 in
  `steer-at-turn-end`. **Exception: `set-mode-dropped`.** Its header note says "no config_option_update follows", but
  frame 4 of that same fixture is a `config_option_update` with mode `vibe`. Frame 2 is a
  `_kiro/customAgent/not_found` that `expected.json` ignores (M1).
- [OK] **6a. L-101.** Every executed `npx` is `npx --no-install`: 107 occurrences, the harness (`gate.py:204, 226`) and
  every recorded command. The three bare `npx apwt` / `npx playwright` hits are the text of playwright-appian's
  SKILL.md as the agent read it, not commands (n4).
- [OK] **6b. Private KIRO_HOME per run (D6).** `Acp.__init__` always sets `KIRO_HOME = <run>/_kiro` (`acp.py:79`). No
  caller overrides `kiro_home=`. `w1.json` `kiro_home_entries` lists only engine-created entries
  (`cloud-cache, enterprise-management, logs, session-index, sessions, settings`). The only kiro-cli call outside `Acp`
  is `kiro-cli --version`.
- [OK] **6c. L-092.** There is no `tests/__init__.py`. The test module is `test_v3_fixtures.py`, and its helpers are
  `load_fixture` / `fixture_names` / `_no_tools_on_path`. The spike folder has no `test*` module or symbol.

### genesis-ctx check lines

- [N/A] ADR-011: no agent node or workflow changed. - [N/A] ADR-019/ADR-080/ADR-046: no package metadata, version or
  install change. - [N/A] ADR-021/ADR-068: no workflow or gate. - [OK] ADR-026/ADR-063/ADR-065: no server or bind. W13's
  HTTP MCP test server is loopback-only (`rest.py` W13, `127.0.0.1`). - [N/A] ADR-028/ADR-085: no endpoint. - [OK]
  ADR-029/ADR-083: tool trust is set per spike agent (`tools` + allow rules); the W3 shell use is the accepted ADR-083
  recipe on a program-opened session. - [N/A] ADR-074. - [OK] ADR-077: the harness launches `kiro-cli acp` with no
  `--trust-all-tools`. - [OK] ADR-082: QA was used only through `ApwtFactory` sessions. The agent ran only `--version`
  and a read-only `snapshot` (`w3.json` `shell_commands`). - [OK] L-017: the spike agents get named tool lists and
  `@server/tool` allow rules (`gate.py` `agent()`). - [N/A] L-025/L-027: no new ruff pin needed (dev venv ruff, clean).
  - [N/A] L-030: no web change. - [OK] L-044/L-087: the installed CLI was probed on the wire; bundle-only facts are
  marked "bundle". - [N/A] L-045, L-051. - [N/A] L-056/L-057: no release. - [N/A] L-088: no guard changed. - [OK] L-089:
  the As built gives one commit per gate stage. - [OK] L-092 (6c). - [N/A] L-098/L-099. - [OK] L-100: the kiro token is
  read in process, registered as a secret, and absent (item 2). - [OK] L-101 (6a). - [OK] L-104: `ps -A -ww`, full
  command lines (`acp.py` `ps_table`); `procs.reap` on recorded pid files (W16). - [OK] L-105: no Playwright report is
  committed. The W3 snapshot is page JSON, scanned clean. - [OK] L-111: the As built states that the W1 PASS re-run is
  owed in 53-06. - [OK] L-112 (item 3).

## Findings

### Blockers

None.

### Majors

- **M1 — W4 misreports what a dropped agent does on the wire, and the `set-mode-dropped` fixture's note contradicts its
  own frames (L-011).** The As built (gate table W4 and the "53-04 `session.py` activation" bullet) says that for a
  schema-invalid agent there is "no notification", and that `set_mode` answers `{}` "with no `config_option_update` — the
  mode stays where it was". `w4.jsonl` shows otherwise:
  - 3.533: mode = `genesis-w4-good` (the earlier successful `set_mode`).
  - 5.535: `set_mode genesis-w4-bad-rules`.
  - 5.544: **`_kiro/customAgent/not_found {sessionId, requestedAgent: "genesis-w4-bad-rules", fallbackAgent: "vibe"}`**.
  - 5.558: **`config_option_update` mode = `vibe`**, then the answer `{}`.
  - The same happens for `bad-tools` at 8.568 / 8.585.

  So the engine announces the drop, and **the session falls back from our active agent to the bundled `vibe` agent**. It
  does not stay where it was. `w4.json` `mode_timeline` stops at 3.533, which is probably why the harness summary missed
  this. Both the fixture header (`make_fixtures.py:128-129`) and `expected.json`, which has no `not_found` or fallback
  field, carry the wrong statement into 53-04/53-05, and 53-04 §`session.py` already quotes it. The gate verdict stands
  (W4 PASS, with a stronger "dropped" signal than reported).

  **Fix:**
  - Correct the W4 row and the 53-04 bullet. The direct dropped signal is `_kiro/customAgent/not_found` (with
    `fallbackAgent`), plus a `config_option_update` to the fallback mode. A failed `set_mode` moves a running session to
    `vibe`, so the SDK must fail closed (`AgentNotActive`) and never prompt the session after it. `kiro.log` stays the
    source of the reason.
  - Regenerate `set-mode-dropped` with a correct note and with `expected.json` fields such as
    `"notification": "_kiro/customAgent/not_found"`, `"fallback_mode": "vibe"`, `"mode_after": "vibe"`.
  - Tell the spec agent that 53-04's activation row needs the `not_found` signal and the fallback.

### Minors

- **m1 — W12's middle case has no evidence.** "Answer `{accessToken, expiresAt}` only: one request, then
  `ModelRegistryUnavailableError` (no `profileArn`)" is the basis for the 53-04/F9 rule "`profileArn` is required … or
  every model call fails". No evidence file holds it: `grep -r ModelRegistryUnavailableError evidence/` finds nothing.
  Only `w12-no_answer.*` and `w12-answer.*` exist. **Fix:** mark the case "observed, evidence not retained" in the As
  built, or re-run it with the user. It fails before any model call, so it should be credit-free.
- **m2 — W19 (c) overstates.** The "53-07 Stop" bullet says `revertMultiple` removes the prompt from history "also for a
  later `session/load`". In `w19.jsonl`, try 7 (revert) is followed by `_kiro/session/history` and a prompt, never a
  `session/load`. Try 8 (load) had no revert. **Fix:** drop the clause, or measure revert → `session/load`.
- **m3 — W16 killed an idle session only.** `rest.py:69-123` kills kiro-cli's group after MCP connect, with no turn and
  no tool or shell child running. The 53-04 `close()`/F12 bullet generalises: "TERM … ends the engine and its MCP
  servers too … even SIGKILL leaves nothing". A shell command started by `execute_bash` mid-run (for example an agent's
  `apwt` command) was not covered. **Fix:** qualify the bullet ("idle session; a kill during a running shell tool is
  untested"). 53-04 should test that case before relying on "nothing left".
- **m4 — W7 delivery timing is incomplete.** The As built says "a steer sent mid-stream was injected 0.12 s later". That
  is the late steer (`steer:2`, queued 35.869 → injected 35.99). The steer sent while a tool ran (`steer:1`) was queued at
  12.025 and injected at **20.056 (8.0 s)**, only after the running `sleep` finished. So "delivered" can lag by the
  running tool's duration, which matters for 53-07's queued state. **Fix:** add this to W7 and the 53-04 `steer` bullet.
- **m5 — W15 path scoping is tested narrowly for a security claim.** `w15path.json` C tests absolute outside paths with
  `read_file` and `list_directory` only. It does not test `../` traversal, a symlink inside the cwd that points out, `~`,
  `grep_search` or `file_search`. The 53-05 bullet says `./**` "confines auto-approved reads to the cwd". **Fix:**
  qualify it. 53-05 must cover traversal, symlinks and the two search tools before treating this as a boundary
  (ADR-083 risk a).
- **m6 — The scrub is per frame, so values split across streamed chunks escape it.** The model echoes the steer
  `messageId`, and in the joined `agent_message_chunk` text of `steer.jsonl`, `steer-at-turn-end.jsonl` and
  `w7/w7b/w8.jsonl` it appears as a raw UUID. The answer frame in the same file holds `steer-<UUID_n>`, so the
  correlation breaks. This id is harmless. The same gap applies to `Scrubber.check` and the loader's `LEAKS` regex: a
  secret or home path split across chunks would pass both. **Fix:** before the scrubber or the fixtures are reused
  (53-04/05), also scan the joined chunk text per stream, and scrub or re-cut these fixtures.

### Nits

- **n1** — Per-item credit rounding: W5 is 0.8031 + 0.4944 + 0.0521 = 1.3496 (stated 1.34); W15 is 0.6657 + 0.2167 =
  0.8824 (stated 0.89). The total 7.72 is right. W4's replaced first run (0.03) has no retained evidence; say so.
- **n2** — `scripts/spikes/53-02/README.md` describes only `acp/scrub/probe_mcp/gate` (W1–W5). Add `rest.py` (W6–W19),
  `http_mcp.py`, `make_fixtures.py` and how to run them.
- **n3** — `shell-auto-approve.jsonl` (and `w3.jsonl`) commit the QA site host and a QA page snapshot (task names of the
  Source Selection site). This is not a credential and not on the brief's list. Consider `<QA_HOST>` if fixtures should
  stay environment-neutral.
- **n4** — Outside this diff: playwright-appian 0.3.0's `SKILL.md` (as read in `w1.jsonl`) tells the agent "if the
  versions differ, use npx apwt", a bare `npx`, contrary to L-101. Forward to 53-06, which edits that file for D14.
- **n5** — `test_answers_follow_their_requests` skips answers seen before any request (`… and sent`) and does not check
  the client's answers to agent→client requests. Optional tightening.
- **n6** — `tool-ids.json` `registered_id` comes from prompt order (`make_fixtures.py` `zip([...], w15["permission_by_call"])`),
  not from the frames. The result is consistent today; it is fragile on a re-run.
- **n7** — W14: v2 shell calls titled `Running: <cmd>` were classed as `builtin` (`w14.json` `builtin_call_s.top`), so
  "195 shell calls" undercounts. The maximum is unaffected.
- **n8** — W16 opens an unsigned session but still reads the role's password (`rest.py:74-75` via `qa_client`; deleted
  at once). Read only what the step needs.

## Verdict (first pass): NEEDS_CHANGES

The gate outcome holds: W1 FAIL with its root cause, and W2–W5 PASS. All gates are green, no product code changed, and
no secret, password, user name, ARN, home path, login name or `~/.kiro` content is in the evidence or fixtures.
Before 53-04 starts, fix **M1**:
1. Correct the W4 record and the 53-04 bullet (`_kiro/customAgent/not_found` and the fallback to `vibe`).
2. Regenerate `set-mode-dropped` with a truthful note and expected fields.
3. Flag 53-04's activation row to the spec agent.

Also, in the same pass:
4. Qualify or evidence m1–m5.
5. Close the chunk-split gap in the scrub (m6), or record that it is open.

---

# Re-review 53-02 — fix `a54b1f4` on `a13798d`, sub-spec base still 62537c2 (genesis-review, 2026-11-10)

What changed: one genesis commit `a54b1f4` (11 files, +169 / −15: two fixtures, the loader test, `gate.py`, `rest.py`,
`make_fixtures.py`, the README, `w4.json`, and the new `w12-answer_no_arn.{json,jsonl}`). The As built changed in
project-tracker `ab235d1` and `b4541a1`. The brief names `52fc6de`, which does not exist (`git rev-parse` fails). The
second As built commit is `b4541a1`: it only corrects the review-fix sha from `0ab0e61` to `a54b1f4`. I reviewed
`b4541a1`. No Kiro credits were spent and QA was not driven. Every check read files or ran the offline gates.

## Gates and scope

- `cd packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **111 passed in 1.00 s** (110 + the new
  `test_no_leak_split_across_streamed_chunks`).
- `../../.venv/bin/ruff check . ../../scripts/spikes/53-02/` → **All checks passed!**
- `git diff --name-only 62537c2..a54b1f4`, with `scripts/spikes/53-02/`, `tests/fixtures/v3/` and
  `test_v3_fixtures.py` filtered out, gives an **empty** list. No product code changed. The working tree is clean.
- Only `set-mode-dropped` and `shell-auto-approve` changed among the 57 fixture files, so the `make_fixtures.py`
  re-run is deterministic for the other 26 pairs and `tool-ids.json`.
- Re-ran `/tmp/53-02-review-fx.py`, which recomputes every fixture's expected values from its frames. All 28 still
  agree. Re-ran `/tmp/53-02-review-credits.py`: the deduped total is still **7.6903**. `w12-answer_no_arn` adds no
  credit entry.

## Privacy scan (counts only)

`/tmp/53-02-review-scan.py` scanned all 127 files with the same secrets loaded in process: 8 kiro tokens plus their
prefixes, the profile ARN, account id and tail, 2 QA user names and 2 passwords, the login name, the hostname, and the
`~/.kiro` skill and agent names.
- kiro token 0, ARN / account id 0, `arn:aws` 0, QA user name 0, QA password 0, login 0, hostname 0, e-mail 0, JWT 0,
  `sess_` 0, `toolu_` 0.
- `<REDACTED>` appears 5 times. One is new, in `w12-answer_no_arn.jsonl`: the `accessToken` in the client's answer.
  That answer has keys `accessToken` and `expiresAt` only, and no frame contains `profileArn`.
- `/Users/` appears once: the regex in `make_fixtures.py`, as before.
- Raw UUIDs appear twice, both the app UUID in `gate.py` / `rest.py` source.
- The `~/.kiro` agent-name hits are 2 pre-existing word matches from `c7c05b2`. The skill-name hits are the 6-character
  `appian` substring (false positives, as before).
- QA host: 0 occurrences in `tests/fixtures/v3/`. It remains in `evidence/w3.jsonl` (by design) and in
  `make_fixtures.py` (see n10).
- Joined-chunk scan (`/tmp/53-02-review-chunks.py`): there is no path, login, e-mail, token or `sess_` / `toolu_` id.
  The only hits are the known raw steer `messageId`s in `w7/w7b/w8.jsonl`, `steer.jsonl` and `steer-at-turn-end.jsonl`
  (m6, recorded as open).

## Per finding

- [OK] **M1.**
  - `w4.json` `not_found_notifications` (2 entries, t 5.544 / 8.568, `fallbackAgent: "vibe"`) and `mode_timeline_all`
    (7 entries: vibe → genesis-w4-good → **vibe at 5.558** → vibe at 8.585 → …) equal a fresh recomputation from
    `w4.jsonl`. Both comparisons are `True`. `result_note` says the values were recomputed without a re-run.
  - `gate.py:311-317` now derives both for future runs. The PASS logic is unchanged.
  - `set-mode-dropped.jsonl` has 5 frames: `set_mode` (id 4) → `_kiro/customAgent/not_found` (`fallbackAgent: vibe`) →
    `available_commands_update` → `config_option_update` with mode **`vibe`** → answer `{}`. The header note now says
    exactly that. `expected.json` has `notification`, `fallback_mode`, `mode_after` (all match the frames) and
    `mode_before` (see n9).
  - The As built W4 row, the 53-04 activation bullet (fail closed, never prompt the session again) and the lesson
    candidate are corrected.
- [OK] **m1.** `w12-answer_no_arn.jsonl`:
  - One `_kiro/auth/getAccessToken` at 0.672. The answer has keys `[accessToken, expiresAt]`.
  - `session/new` and `set_mode` succeed. `session/prompt` fails at 5.564 with `-32000` "Kiro could not load the
    available models", `data.errorType: ModelRegistryUnavailableError`.
  - There is no `turn_start` or `turn_completion` and no credit entry, so the run was credit-free as claimed. The As
    built row cites the file.
  - The parenthesis "no `profileArn` → region falls back to `us-east-1`" has no evidence (n11).
- [OK] **m2.** The 53-07 Stop bullet now says revert across a later `session/load` "was not measured".
- [OK] **m3.** The W16 bullet is qualified: "on an **idle** session … a kill during a running shell tool … was not
  measured — 53-04 should test it". The measured values are unchanged.
- [OK] **m4.** W7 and the 53-04 `steer` bullet give 12.03 → 20.06 s while a tool ran. This matches `steer:1` in the
  frames.
- [OK] **m5.** The 53-05 tool-ids bullet now reads "works as far as tested". It lists the untested cases (`../`,
  symlink, `~`, `grep_search` / `file_search`) and requires 53-05 to cover them.
- [OK] **m6, recorded as open, with a test.** `test_no_leak_split_across_streamed_chunks` joins the
  `agent_message_chunk` text per `sessionId` and scans it with `LEAKS`. I checked that the test catches a split value:
  with `LEAKS` from the module, the chunks `["see /Us", "ers/x/a"]` give per-frame False and joined True. The
  harness's own per-frame `Scrubber` is unchanged. That is acceptable for a spike because Decisions records it as open,
  but 53-04/05 must not reuse it as-is.
- Nits:
  - [OK] n1: W5 1.35, W15 0.88, W4's lost first run marked "evidence was not kept".
  - [OK] n2: the README covers `rest.py`, `http_mcp.py`, `make_fixtures.py` and the loader test.
  - [OK] n3: `<QA_HOST>` in `shell-auto-approve.jsonl` (3 places).
  - [OK] n4: forwarded to 53-06 in Decisions.
  - [OK] n8: `qa_client(run, credentials=False)` returns before `credentials()`. W16 no longer reads the password.
  - [OK] n5–n7: left, with reasons in Decisions.

## Checklist delta

Nothing in the first-pass checklist changes state, except:
- **Item 4 (As built accurate) is now OK.** One exception: the unevidenced region clause (n11).
- **Item 5 (fixtures mirror frames, L-011) is now OK.** One caveat: n9.

All ADR / lesson lines stand as in the first pass. L-100 still holds: the login token was read in process for the
`answer_no_arn` run and appears only as `<REDACTED>`.

## New findings

### Blockers / Majors

None.

### Minors

None.

### Nits

- **n9** (`set-mode-dropped.expected.json` `mode_before`) — What: `mode_before: "genesis-w4-good"` comes from frame
  3.533 of `w4.jsonl`, which is not in the 5-frame fixture. Problem: a 53-04 replay test fed only this fixture cannot
  derive or check it from the frames. Fix: either add the earlier `config_option_update` to the fixture's frames, or
  mark `mode_before` in the note as "the session's state before frame 1".
- **n10** (`make_fixtures.py:20`) — What: the QA host is a literal constant. Problem: if the QA environment moves, the
  `replace` silently stops scrubbing, and nothing tests for it. Fix: when fixtures are next re-cut, add a host pattern
  (for example `appianpreview\.com`) to the `assert` in `build()`.
- **n11** (As built W12 row) — What: "no `profileArn` → region falls back to `us-east-1`". Problem: no evidence file
  contains `us-east-1` or `region`, and the run's `log` is `[]`. Fix: mark it "bundle", as done elsewhere (L-044).

## Hand-off note (not a finding against this diff)

`53-04-sdk-core.md:19` (activation) still says only that a missing `availableModes` entry or a missing
`config_option_update` → `AgentNotActive`. It does not mention `_kiro/customAgent/not_found` or the fallback to `vibe`.
The As built's "Changes for 53-04" bullet carries the correction. Pass it to `genesis-spec` before 53-04 starts.

## Not checked

- A run of the loader test in the `python:3.13` CI image (L-112). Docker is down, as stated in the As built. The test
  reads files only and passed with an empty `PATH`.
- `w4.json`'s new fields were recomputed from the recorded frames, not from a new W4 run. A live re-run would cost
  credits and was out of scope.
- The `m3` (kill during a running shell tool) and `m5` (traversal / symlink / search tools) cases. They are qualified
  in the As built and owed to 53-04 and 53-05.

## Verdict: SHIP

M1 is fixed in the As built, the evidence summary and the fixture, and it is checked against the frames. m1 is now
evidenced, with no credits spent. m2–m5 are qualified, and m6 is recorded as open with a loader test that catches a
split leak. Both gates are green, no product code changed, and the privacy scan is clean. The nits n9–n11 are optional.
Relay the 53-04 activation correction to the spec agent.
