# 53-02 — Spike: the remaining v3 wire unknowns, recorded as fixtures (gate)

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (spike harness under `genesis/scripts/spikes/53-02/`, fixtures
> under `genesis/packages/kiro-agent-sdk/tests/fixtures/v3/`, notes in this file's As built; no product code). Built by
> genesis-dev on the user's machine with the installed `kiro-cli` (2.37.1 at spec time). Parent:
> `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D5, D6, D7, D9, D10; F3–F7, F9, F10, F15.

## 1. Goal

The 2026-11-03 probe (53-01 §3, `evidence/`) answered most of how v3 behaves. Answer the rest **before** the SDK is
designed in code, record every behaviour the SDK depends on as a frame fixture, and measure the numbers the defaults
need (timeouts, F7). Probe the **installed CLI, not its docs** (L-044, L-087).

## 2. Questions (each with evidence: the request, the frames, a pass/fail line)

Must-pass items are marked **(gate)**. A FAIL on a gate item stops the phase: the spec agent re-specs the affected
sub-specs before 53-03 starts.

| # | Question | Pass criterion |
|---|---|---|
| W1 **(gate)** | Workspace skills under a private `KIRO_HOME`: a skill in `<cwd>/.kiro/skills/<id>/SKILL.md` is listed (context breakdown) and usable; nothing from `~/.kiro/skills` appears (D6, D7, D8; 51-03 S11 retest). Use Phase 51's real pair: `playwright-appian` copied from a workspace export's `checkout/node_modules/playwright-appian/skills/` and the managed `genesis-test-authoring`, each with a canary line (53-01 §9.3 item 5) | both managed/provisioned skills visible, personal skill absent |
| W2 **(gate)** | MCP servers from `session/new.mcpServers` with real `env` values (list form, L-001), including a Genesis managed server (`genesis-kb`) and the blackboard server | both start, `env` reaches the server, tools run |
| W3 **(gate)** | The shell over v3 with `execute_bash` in `tools`: permission request shape (`_meta.kiro.toolId`, `consent`), tool frames (`kind`, title, `rawInput`), auto-approve works. Workload: Phase 51's recipe `cd <ws> && PLAYWRIGHT_APPIAN_HOME=<run>/.apwt npx --no-install apwt …` (53-01 §9.3 item 1) under the caller's environment (`PATH` with Node) — against a signed-in QA session if QA is available, otherwise `npx --no-install apwt --version` plus one command on a local page; and one large output saved through `@blackboard/save_tool_output` | frames recorded; the commands run; `npx` resolves the workspace's own `apwt` |
| W4 **(gate)** | `session/set_mode` confirmation: the `config_option_update` (or other frame) that proves our agent is active; what happens when the agent fails the engine's schema (deliberately bad field) | a reliable "active" signal and a reliable "dropped" signal |
| W5 **(gate)** | Credits on a turn that does not end cleanly: `session/cancel` mid-turn, a turn hitting the client timeout, a turn whose MCP server fails | `turn_completion` present or absent per case recorded; nothing invents a number (ADR-032) |
| W6 | `session/load` of a chat session after the kiro-cli process exits (same `KIRO_HOME`): history restored, the custom agent re-sent and active, a new turn sees prior context | works, or the exact failure |
| W7 | Steering: the method v3 accepts mid-turn (`_session/steer` or other), its answer, how a consumed steer shows on the wire, what happens to an unread steer at turn end (D10) | method + consumption signal recorded |
| W8 | Clear: `session/close` + `session/new` vs any v3 clear method; Compact: `_kiro/session/compact` on a long session, the `session_info_update` kinds it emits (F15) | both recorded |
| W9 | On-demand MCP loading: the `tool_load` / `tool_call` steps on a 3–5 tool node; whether an `initialize` setting (`_meta.kiro.settings`, cf. KiroCrew `ACP_BACKENDS_CLIENT_META_SETTINGS`) turns it off, and the step/credit difference (F10) | numbers for both, or "no off switch" |
| W10 | Model fallback: the frame v3 sends when a turn moves to another model (`modelFallbackReporting`), and `model` in `configOptions` after a `session/set_config_option` (F6) | shape recorded (force with an unavailable model id if needed) |
| W11 | Images in `session/prompt` (`promptCapabilities.image`), and whether v3 needs only the `prompt` key (today the SDK sends `content` and `prompt`) | image turn works; key decided |
| W12 | `--auth-method client`: the engine's access-token request (`_kiro/auth/getAccessToken` or as observed), its params, the answer shape; with no answer, the failure (F9; 52-01 D8) | request/answer recorded with a token from the user's login, **token value never written to evidence** |
| W13 | HTTP MCP servers in `session/new` (`mcpCapabilities.http: true`): a local Streamable HTTP server reached (52-01 D7 input) | works or the failure |
| W14 | Timings for F7: time between frames in a long silent model step, the longest normal MCP tool call in a real workflow node, the longest normal shell command in the W3 workload, and the cancel grace (time from `session/cancel` to the prompt answer). Reference: a 51-03 v2 explore turn made 26 tool calls in 194 s (8.44 credits); Phase 51 turns run up to 900 s (a live heal took 482 s) | numbers → 53-04's timeout values, none of which would end a normal 900 s Phase 51 turn early |
| W15 | The built-in tool ids on 2.37.1: registered id vs permission `toolId` for each built-in D9 and F2 name (`execute_bash`/`run_command`, `read_file`, `list_directory`, `fs_write`, `str_replace`, `fs_append`, `grep_search`, `file_search`, `web_fetch`, `remote_web_search`, `delete_file`); the meta tools (`tool_load`, `tool_call`, `disclose_context`). Also (added in the W1–W5 re-spec): can a v3 permission rule limit `fs_read` (`read_file`, `list_directory`, `grep_search`, `file_search`) to path patterns, for example the cwd? In W1 the agent listed `~/.kiro` without being asked (53-01 §10) | the table for 53-05's fixture; the path-scoping answer, yes with the rule shape or no |
| W16 | Process tree: which processes kiro-cli starts (engine child, MCP servers) and their process groups; whether killing kiro-cli's own group reaches them (F12). Also: a program-started `apwt` session daemon and its Chromium (own groups, recorded in `<run>/.pids`, 53-01 §9.3 item 4) survive that kill and are still reaped by `testexec/procs.py` | tree recorded; a kill that leaves nothing of kiro-cli's behind and leaves the program's apwt processes to their own reaper |
| W17 | `_kiro/mcp/status` states for a server that fails to start, needs auth, or is slow; how long `connecting` lasts (F3) | states + timings |
| W18 | Elicitation: the request an MCP tool's elicitation produces on v3 (`elicitation/create` or `_kiro/mcp/elicitation`) and the decline answer (F8) | request + decline recorded |
| W19 | **Stop before the answer (added in the W1–W5 re-spec, 53-01 §10).** W5 run 1 showed that a prompt cancelled before the model answered stays in the conversation, and the next turn carried it out (the essay and the 90 s tool call). Measure: (a) how often across 3 tries; (b) whether a fixed client line at the start of the next prompt ("The previous request was cancelled by the user. Do not continue it.") stops it; (c) whether v3 has a method that removes or rewinds the last turn (look in `initialize.agentCapabilities`, `extensionMethods` and `_kiro/session/*`); (d) whether `session/load` of that session replays the cancelled prompt | the behaviour per option, with the frames; feeds the Stop decision (53-01 §10 Q11) |

## 3. Method

- Reuse the probe's raw JSON-RPC harness (`specs/phase-53-kiro-sdk-v3/evidence/probe*.py`) moved to
  `genesis/scripts/spikes/53-02/`; one script per question group; each writes `evidence/<id>.jsonl` (raw frames) and
  `evidence/<id>.json` (summary + pass/fail). A minimal stdio MCP server like `probe_mcp.py`, plus `genesis-kb` from the
  managed registry for W2.
- Every run uses a private `KIRO_HOME` under the spike's run folder unless the question needs otherwise (D6).
- Never write a token, a secret value or the user's `~/.kiro` contents into evidence; scrub before saving (L-100's rule
  applied to Kiro tokens).
- Credits: about 1–2 per probe run on 2026-11-03; budget ≤ 20 credits for the whole spike; report the real total.

## 4. Fixtures (the product output of this spike)

Copy the frames the SDK depends on into `genesis/packages/kiro-agent-sdk/tests/fixtures/v3/`, one file per behaviour,
each with `<name>.jsonl` (frames in order, both directions, `{dir, msg}`) and `<name>.expected.json` (what the SDK
must produce from it): `initialize`, `session-new-custom-agent`, `set-mode-active`, `set-mode-dropped`, `mcp-allow`,
`mcp-ask-approve`, `mcp-ask-reject`, `fs-write-client`, `shell-auto-approve`, `turn-usage`, `context-usage`,
`cancel`, `compact`, `config-option-model`, `available-commands`, `mcp-status-*`, `load`, `steer`, `elicitation`,
`access-token`, `model-fallback`, `unknown-request`. Record the kiro-cli version in each file's first line. Scrub
`sessionId`s, home paths and request ids to stable placeholders.

## 5. Tests

None for product code. The spike leaves the fixtures plus a small loader test that parses each fixture file (so a
malformed fixture fails CI at once).

## As built (2026-11-10, genesis-dev) — GATE: W1 FAIL (re-specced, D14), W2–W5 PASS; W6–W19 recorded; fixtures in; review SHIP

**kiro-cli 2.37.1** (`kiro-cli --version`, recorded as the first line of every evidence file). genesis base
`62537c2` (master; `git fetch` was refused by the remote (access rights), so the rebase was onto the last-known
`origin/master` = local `master`). Harness and evidence: `genesis/scripts/spikes/53-02/` (`acp.py` = the 2026-11-03
`Probe` moved and adapted; `probe_mcp.py` moved and extended; `scrub.py`; `gate.py`; `README.md`). Every run used a
private `KIRO_HOME` at `~/Genesis/runs/spike-53-02/<id>-<time>/_kiro`.

**Task restated.** Answer W1–W18 against the installed kiro-cli over raw JSON-RPC, gate items W1–W5 first, record
each as `evidence/<id>.jsonl` + `<id>.json`, turn the frames the SDK depends on into fixtures under
`packages/kiro-agent-sdk/tests/fixtures/v3/` with one loader test, no product code. Rules applied: ADR-002/004/020
(per-session MCP over ACP, no global Kiro mutation), ADR-029/083 (the trust cap, the accepted shell risk), ADR-032
(nothing invents a credit number), ADR-034/069 (skills are files in `<cwd>/.kiro/skills`), L-001 (env as a list),
L-024, L-044/L-087 (probe the installed CLI), L-100 (no secret in evidence), L-101 (`npx --no-install`), L-104,
L-112 (fixture tests without Node or kiro-cli).

### Gate results so far

| # | Result | Evidence (`genesis/scripts/spikes/53-02/evidence/`) |
|---|---|---|
| **W1 (gate)** | **FAIL.** Under a private `KIRO_HOME`, v3 discovers workspace skills from `<cwd>/.kiro/skills/` and lists them in the `_kiro/progressive_context/items_changed` notification (`items[{name, type:"skill", description}]`) — the managed `genesis-test-authoring` was listed, loaded with the engine's skill tool (`title: "Load skill: genesis-test-authoring"`, `rawInput {name}`) and its canary came back. **`playwright-appian` (copied from a Phase 51 export, `checkout/node_modules/playwright-appian/skills/`, package 0.3.0) was NOT listed:** kiro.log `skill.frontmatter.invalid … Failed to parse front matter: bad indentation of a mapping entry (3:112)`. Line 3 is its unquoted `description:`, which contains `(package playwright-appian): open a session` — a `: ` inside a plain YAML scalar, which v3's strict parser rejects. The model found the file only by browsing (`list_directory` of `<run>/.kiro/skills`) and read it with `read_file`, so its canary came back too, but the skill was never offered. The personal skill (1 id under `~/.kiro/skills`, directory names only) was absent from the skill list and from every frame. 0.46 credits, 20.3 s. | `w1.json`, `w1.jsonl` |
| W1b (diagnosis, no prompt) | **Root cause confirmed, 0 credits.** Two sessions in one process: the package's `SKILL.md` as shipped → listed `[genesis-test-authoring]` only, log `skill.frontmatter.invalid`; the same file with only the `description` value quoted → listed `[genesis-test-authoring, playwright-appian]`, no log warning. The bad line is in the `playwright-appian` source (`skills/playwright-appian/SKILL.md:3`, since commit `0ada4c1`, P4-12), so every 0.3.0 export carries it. | `w1b.json`, `w1b.jsonl` |
| **W2 (gate)** | **PASS.** `session/new.mcpServers` with the probe server, `genesis-kb` (launched as the worker does, `python -m genesis.mcp.kb_server --db …`, `genesis/runs/worker.py:89`) and the blackboard server (`genesis_core.mcp.blackboard_server --root <run>`), `env` in list form (L-001). `_kiro/mcp/status` went `connecting` → `connected` for all three within 1.0 s of the `session/new` answer (probe 3.79 s, genesis-kb 3.81 s, blackboard 4.58 s after launch; `session/new` 2.98 s, `set_mode` 0.09 s). A canary env var reached both the probe server and `genesis-kb` (checked with `ps -E` on the spawned processes, boolean only), and the probe's `env` tool returned it. `@probe/env`, `@genesis-kb/list_applications` and `@blackboard/list_tool_outputs` all completed with no permission request (each had an allow rule). 0.16 credits, 13.8 s. | `w2.json`, `w2.jsonl` |
| **W3 (gate)** | **PASS.** A program step opened and signed in a QA session as `contracting-officer` through Genesis's own `ApwtFactory.for_run(...).open_session(..., role=…)` (9.8 s, `signedIn: true`, chromium; password only in that subprocess's environment and registered with the scrubber, no `<SECRET_n>` placeholder appears anywhere, so it never reached a frame). The agent (tools `execute_bash`, `read_file`, two blackboard tools) ran Phase 51's recipe exactly: `cd <ws> && PLAYWRIGHT_APPIAN_HOME=<run>/.apwt npx --no-install apwt --version` → `0.3.0` (0.57 s), then `… apwt -s w3-officer snapshot --full --json` (0.83 s), then saved that output with `@blackboard/save_tool_output` as `w3/snapshot.txt` (**42 023 bytes**, by reference; the reply quoted nothing). **`npx` resolves the workspace's own `apwt`:** from the checkout `npx --no-install` gives `<RUN>/checkout/node_modules/.bin/apwt` 0.3.0, while the `apwt` on this machine's `PATH` is a global nvm install, version **0.2.0** (L-101: the recipe is what keeps the agent off it). **Frames:** `tool_call` first (`toolCallId: "run_command_toolu_…"`, `kind: "execute"`, `title` = the model's own description, `rawInput {command, description, run_in_background}`), then 15–55 ms later `session/request_permission` with the same `toolCallId`, no `kind`, `title` = the command, `_meta.kiro {toolId: "run_command", command, consent {capability: "shell", resource: <command>, askType: "implicit", triggeringResource: "cd <RUN>/checkout", workspaceRoot}, consentRound: 1}`, options `accept/always-accept/reject/always-reject`; the client's `allow_once` answer ran it; result `rawOutput {output, exitCode, message}` + `content[]`. 0.42 credits, 27.4 s. Run 1 (`w3-run1.*`, 0.29 credits) failed only the size check: plain `apwt snapshot` prints a 333-byte pointer and writes the page to a file. | `w3.json`, `w3.jsonl`, `w3-run1.*` |
| **W4 (gate)** | **PASS.** **Active:** after `session/set_mode` (answer `{}`), a `session/update` `config_option_update` whose `mode` option has `currentValue` = our id arrives within ~30 ms; a codeword from our agent's prompt came back (0.03 credits). Client agents are listed in `session/new.result.modes.availableModes` with `_meta.kiro.resource.source.origin: "client"`. **Dropped:** a schema-invalid agent (`permissions.rules[0].effect: "sometimes"`; `tools` as a string) is dropped at `session/new` without a notification: absent from `availableModes` and from the `mode` option list (no `_kiro/customAgent/config_error`). `session/set_mode` to its id still answers **`{}`**, but first the engine sends **`_kiro/customAgent/not_found {sessionId, requestedAgent, fallbackAgent: "vibe"}`** and a `config_option_update` that **moves the session from our active agent to the bundled `vibe` agent** (corrected after review M1: the first summary stopped its mode timeline too early; `w4.json` `not_found_notifications`, `mode_timeline_all`). The schema error itself is only in `KIRO_HOME/logs/<t>/kiro.log`: `[ClientCustomAgents] client.agent.drop.invalid {index, error}` (`index` = position in `customAgents`; `error` = zod issues, e.g. `invalid_enum_value` at `permissions.rules.0.effect`, options `allow, deny, ask, evaluate`; `invalid_union` at `tools`). An unknown extra key (`notAField: true`) is accepted and the agent becomes active. Bundled modes on 2.37.1: `vibe, spec, quick-spec, bug-fix, plan, autonomous, semantic_reviewer`. | `w4.json`, `w4.jsonl` |
| **W5 (gate)** | **PASS (recorded; nothing invents a number).** One session per case (`w5.*`), plus `w5a.*` and run 1 (`w5-run1.*`, credits recomputed: an empty summary is None, not 0). | `w5.json`, `w5.jsonl`, `w5a.*`, `w5-run1.*` |

**W5 per case** (`turn_completion` = `session_info_update` kind `turn_completion`; its `promptTurnSummaries` carries
the credit entry):

| Case | `turn_completion` | `status` | credit entry | stop | cancel → prompt answer |
|---|---|---|---|---|---|
| `session/cancel` before any output (run 1, 6 s in) | present | `aborted` | **none** (`[]`) | `cancelled` | 0.03 s |
| `session/cancel` 0.5 s after the first streamed chunk (`w5a`) | present | `aborted` | **none** (`[]`), although ~1.5 K characters had streamed | `cancelled` | 0.01 s |
| client timeout while an MCP tool runs (cancel 10 s into a 90 s `sleep`) | present | `aborted` | **0.0505** (`usedTools: [tool_load, tool_call]`) | `cancelled` | 0.02 s; the tool call is marked `failed` at once |
| the MCP server exits during a call | present | `success` | 0.082 | `end_turn` | — (tool `failed` "Connection closed") |
| next turn, same server | present | `success` | 0.085 | `end_turn` | — (tool `failed` "Not connected"; not restarted) |
| kiro-cli's group killed mid-stream | **absent** | — | — | — (EOF) | — |

So an aborted turn sometimes carries a credit entry (the model calls finished before the cancel) and sometimes none
(an interrupted model call is not reported). `turn_completion` arrives ~10 ms before the `session/prompt` answer.
After the MCP server died, no `_kiro/mcp/status` update was sent. **Run 1 also showed a carry-over:** a prompt
cancelled before any output stays in the conversation, and the next turn answered it as well (it wrote the cancelled
essay, then the next turn ran the cancelled 90 s `sleep` before its own tool); in `w5a` (cancelled mid-stream) the
next turn did not.

**W6–W19** were run after the re-spec (project-tracker `4ae2915`, `2866d81`; W15 gained path-scoped `fs_read`, W19
is new). The W1 PASS re-run happens in 53-06 with the fixed skill (D14).

**W1 re-run (53-06, 2026-11-11): PASS.** kiro-cli 2.37.1, run's own `KIRO_HOME`, playwright-appian **0.3.1 packed
locally** (`npm pack` of playwright-appian `38f87fd`, extracted as an install lays it out into
`<run>/checkout/node_modules/playwright-appian/`; not the published tarball, which is 53-12's) plus the managed
`genesis-test-authoring`. `_kiro/progressive_context/items_changed` listed **both** skills
(`[genesis-test-authoring, playwright-appian]`); the personal skill (`appian`, the 1 id under `~/.kiro/skills`) was in no
frame; kiro.log had no `skill.frontmatter.invalid`; both skills were loaded by the engine's skill tool (`Load skill: …`)
and both canaries came back. 0.20 credits, 9.4 s. Harness `scripts/spikes/53-06/w1_rerun.py` (reuses this spike's
`acp.py` and `gate.py` helpers); evidence `evidence/w1-rerun-031.{json,jsonl}` (genesis `0c0a4aa`).

### W6–W19 results

| # | Result | Evidence |
|---|---|---|
| W6 | **Works.** After kiro-cli exited (no `session/close`), a new process with the same `KIRO_HOME` answered `session/load {sessionId, cwd, mcpServers, _meta.kiro.customAgents}` in 2.1 s; the answer's `_meta.agentMode` was our agent and the history came back before the load answer as `user_message_chunk` + `agent_message_chunk` (each with `_meta.kiro.replayId`) **and the old turn's `turn_completion` again, with its credit entry and `_meta.kiro.replay: true`**; `set_mode` then confirmed active; the next turn recalled the codeword. 0.05 credits. | `w6.*` |
| W7 | **`_session/steer {sessionId, message: string}`** → `{queued: true, messageId: "steer-<uuid>"}` (KAS 2.37 also has `_session/steer/clear` → `{cleared, messageIds}`; neither is in `extensionMethods`). Consumption on the wire: `session_info_update` kinds `steering_queued {messageId, content}` → `steering_injected {messageId, content}` (the model then saw it, and echoed a `[STEERING steer-…: …]` note) → `steering_cleared {messageIds}` after `turn_end`. A steer sent while the model streamed was injected 0.12 s later; one sent while an MCP tool ran (an 8 s `sleep`) was injected only after the tool finished (queued 12.03 s → injected 20.06 s), so delivery can lag by the running tool's duration (review m4). **A steer queued as the turn ends (`w7b`) starts a second engine turn inside the same `session/prompt`:** two `turn_start`/`turn_completion` pairs (0.029 + 0.032 credits) before the one prompt answer. No steer stayed unread in any test. **Images: no** — `message` must be a non-empty string; a content list is refused (`-32603 "_session/steer: missing or empty message"`), so F16's text-only steer is the only option. | `w7.*`, `w7b.*` |
| W8 | **Compact:** `_kiro/session/compact {sessionId}` → `{success: true}` in 14.7 s, one `session_info_update` kind **`summarization_completed`** (`_meta.kiro.summarization {status, summary}`); the next turn still knew the earlier context. **Clear:** no v3 clear method (`_kiro/session/clear`, `session/clear`, `_session/clear` → `-32603` "no persistence classification"); `session/close` (`{}`) + `session/new` took 0.03 s in a warm process, the new session knew nothing (F15 holds). | `w8.*` |
| W9 | **No client off switch.** `initialize` `clientCapabilities._meta.kiro.settings` is read for `memory` only (KAS 2.37 `acp-server.js`); the engine's `toolSearch` / `toolSearchNeverDefer` settings exist, but `_kiro/configuration/set` refuses them from the client at the `session` and `client-connection` layers (`ConfigurationSetRefusedError`, `reason: notGranted`). **Numbers** (4-tool node, 3 tools used): first turn 1 batched `tool_load` + 3 calls, 10.0 s, 0.134 credits; second turn in the same session 0 loads, 5.0 s, 0.078 credits. The cost is one load step per session, so F10 keeps the default. | `w9.*`, `w9state.*` |
| W10 | `configOptions.model`: `currentValue` + options (`auto`, `claude-opus-5.5`, `claude-sonnet-5.5`, …). `session/set_config_option {configId: "model", value}` → `{configOptions}` + a `config_option_update`. An **unknown id is accepted** (`currentValue` = the bad id); the next prompt fails `-32000 "The model '…' is not available"` with a `display_error` kind and `turn_end stopReason: error`. **No fallback frame was produced**; the bundle has fallback triggers for refusal and availability (`MODEL_FALLBACK_REFUSAL/AVAILABILITY`) and a `modelFallback` constant, not forced here. F6 shape still unmeasured. | `w10.*` |
| W11 | `promptCapabilities {image: true, embeddedContext: true}`. Image + text with key **`prompt` only: works** ("Red."); **`content` only: `-32602`** (prompt required); both keys: works. **Decision: send `prompt` only.** | `w11.*` |
| W12 | `kiro-cli acp --agent-engine v3 --auth-method client`: the engine sends **`_kiro/auth/getAccessToken {}`** (no params) right after start. **No answer** (`-32601`): 8 retries in 0.1 s, `session/new` still succeeds, the prompt fails `-32000 ModelRegistryUnauthenticatedError` ("not signed in"). **Answer `{accessToken, expiresAt}` only** (`w12-answer_no_arn.*`, re-run credit-free after review m1): one request, `session/new` succeeds, the prompt fails `-32000 ModelRegistryUnavailableError` ("could not load the available models"; per the bundle, without `profileArn` the region falls back to `us-east-1`). **Answer `{accessToken, expiresAt (ISO), profileArn, authMethod: "IdC", provider: "Enterprise"}`** with the user's own login token (read in process from kiro-cli's store, never printed; the ARN scrubbed too): one request, turn `end_turn`, 0.03 credits. The engine refreshes when the token is within 180 s of expiry. | `w12-no_answer.*`, `w12-answer_no_arn.*`, `w12-answer.*` |
| W13 | **Works.** `mcpServers: [{type: "http", name, url, headers: []}]`: the engine POSTed `server/discover` (our `-32601`), then `initialize`, `notifications/initialized`, a GET for SSE (our 405), `tools/list`, `tools/call`; status `connecting` → `connected` in 0.06 s (labelled `authType: "oauth"` even without auth); the tool ran. | `w13.*` |
| W14 | See "Timings" below. | `w14.*` |
| W15 | Table below (`tool-ids.json`). **Path-scoped `fs_read`: yes.** The client rejected every ask: (A) `{capability: "fs_read", match: ["**"], effect: "allow"}` also allows absolute paths outside the cwd (no ask); (B) adding `{…, match: ["/tmp/53-02-outside/**", "/private/tmp/53-02-outside/**"], effect: "deny"}` refuses those reads without asking; (C) **`match: ["./**"]` allows the cwd only** — the outside read and listing asked (`consent.resource` = the realpath, `/private/tmp/…`) and failed on the client's reject. An unknown `capability` (`"zzz"`) does not drop the agent (a typo makes the rule silently never match). | `w15.*`, `w15path.*` |
| W16 | **PASS.** `kiro-cli` (own group) → `kiro-cli-chat` (same group) → the KAS engine (`…/kiro-cli/node`, **its own group**) → the MCP servers (in the engine's group). `killpg(kiro-cli, TERM)`: kiro-cli exited in 0.54 s and the whole tree was gone by then; `SIGKILL` of kiro-cli's group alone (`w16b`) also left nothing after 1 s (the engine exits with its parent). The program's `apwt` session daemon (own group, recorded in `<run>/.pids/apwt-daemon-w16-anon.json`) and its Chromium (another group) all survived the kill (5 processes) and `testexec/procs.reap(<run>/.pids)` then removed every one. | `w16.*`, `w16b.*` |
| W17 | `_kiro/mcp/status` per server (5 in one session, `w17`): healthy `connecting` → `connected` in 0.16 s (each update carries the tool list); exits before `initialize` → `failed {failedAuthorization: false, errorMessage: "Connection closed"}` in 0.18 s; exits with a 401-style stderr → the same (stdio has no auth state); slow (answers `initialize` after 8 s) → `connected` at 8.2 s; HTTP answering 401 + `WWW-Authenticate` → `connecting {authType: "oauth"}`, then `failed "fetch failed"` (it tried the OAuth metadata URL), `failedAuthorization: false`. **`connecting` lasts at most 60 s** (`w17b`: `failed "MCP server 'slow' connection timed out after 60000ms"` at 60.0 s). | `w17.*`, `w17b.*` |
| W18 | An MCP `elicitation/create` reaches the client as **`_kiro/mcp/elicitation {sessionId, toolCallId, elicitation: {mode: "form", message, requestedSchema}}`** (the engine declares `elicitation {form, url}` to MCP servers). Our `{action: "decline"}` was passed to the server unchanged and the tool returned it; a failed client call makes the engine answer `{action: "cancel"}` (bundle). | `w18.*` |
| W19 | **(a) Carried out 3/3:** a prompt cancelled 1 s after `turn_start` (no output, no tool) was carried out by the next turn ("Reply with the single word: alive") every time — the cancelled `echo` ran in all three, once with the haiku too. **(b) The fixed line works 0/3 carried out:** "The previous request was cancelled by the user. Do not continue it." at the start of the next prompt → only `alive`. **(c) Rewind exists:** `_kiro/checkpoint/revertMultiple {sessionId, messageId}` (KAS `handleRevertToMessage`; not in `extensionMethods`; refused while a turn runs) with the cancelled prompt's `userMessageId` (from `user_message_id_assigned`) → `{success: true, affectedFiles: [], totalFiles: 0}`; `_kiro/session/history` then empty; next turn not carried out. **(d) `session/load` replays the cancelled prompt** (`user_message_chunk` with its text) and the next turn after the load carried it out. Credits 0.56. | `w19.*` |

### Timings (W14, for F7)

| Measure | Value | Source |
|---|---|---|
| Longest silence between frames in a long v3 model step (one 1 500-word `fs_write`, 96 s turn) | **12.0 s** (before the `tool_call`); thoughts stream otherwise. 2.46 credits | `w14.json` `silent_turn` |
| Longest silence inside a finished agent turn in real runs (v2, `genesis.db` `run_events`, 281 728 gaps) | p99 4.9 s, **max 287 s** (`technical-design-analysis` `assemble`, the L-064 turn), then ~250 s (`erd-generation`) | `w14.json` `real_runs` |
| Longest MCP tool call in real workflow nodes (1 920 calls) | p95 5.7 s, p99 11 s, **max 18.7 s** (`@appian-dev/listExpressionRules` in `story-implementation`) | same |
| Longest shell command (195 calls; Phase 51's apwt commands are < 3 s, W3: 0.6–0.8 s) | p99 15 s, **max 37.9 s** (`story-implementation` `implement`) | same, `w3.json` |
| Longest agent turn | **737 s** (`action-capture` `segment`), 482 s (`heal`) | same |
| Cancel grace (`session/cancel` → prompt answer) | **0.01–0.03 s**, also during an MCP call | `w5*.json` |
| MCP `connecting` limit (engine) | 60 s | `w17b.json` |

None of these needs a limit that would end a normal 900 s Phase 51 turn early: a silent-turn limit must sit above
287 s (suggest ≥ 600 s), a tool-stall limit above 38 s for the shell and 19 s for MCP (suggest ≥ 300 s, since
Phase 51's `apwt open` program steps are not agent tool calls but an agent may still run a 60 s+ replay), and the
cancel grace can be a few seconds.

### W15 — built-in tool ids on kiro-cli 2.37.1 (`fixtures/v3/tool-ids.json`)

| Registered id (in `tools`) | Tool-call title | `kind` | Permission `toolId` | `consent.capability` | `toolCallId` prefix |
|---|---|---|---|---|---|
| `read_file` | Read File | `read` | `read_file` | `fs_read` | — |
| `list_directory` | List Directory | `search` | `list_directory` | `fs_read` | — |
| `fs_write` | Write File | `edit` | `fs_write` | `fs_write` | — |
| `str_replace` | Replace in File | `edit` | `str_replace` | `fs_write` | — |
| `fs_append` | Append to File | `edit` | `fs_append` | `fs_write` | — |
| `grep_search` | Grep Search | `search` | `grep_search` | `fs_read` | — |
| `file_search` | File Search | `search` | `file_search` | `fs_read` | — |
| `web_fetch` | Fetch URL | `fetch` | `web_fetch` | `web_fetch` | — |
| `remote_web_search` | `web_search` | `other` | `remote_web_search` | `web_search` | `web_search_` |
| `execute_bash` | Run Command (or the model's description) | `execute` | **`run_command`** | `shell` | `run_command_` |
| `delete_file` | Delete File | `delete` | `delete_file` | `fs_write` | — |

Meta tools: `tool_load` (title "Tool Load", sometimes only a `tool_call_update`), `tool_call`, `disclose_context`
(permission `toolId: disclose_context`, capability `skill`, when a skill loads). MCP tools ask as
`mcp_<server>_<tool>`, capability `mcp`. Every built-in asks (`askType: implicit`) when no rule allows it; reads too.
Rule effects: `allow | deny | ask | evaluate`.

**Other W1 observations (not the failure).**
- When the skill was missing, the model listed the user's `~/.kiro` and `~/.kiro/skills` with `list_directory`
  on its own: v3's built-in read tools are not confined to the cwd (ADR-083 accepted risk a; Phase 52). The two
  outputs are blanked in `w1.jsonl` (`acp.drop_user_kiro`, applied to every later save).
- The context breakdown (`session_info_update` `breakdown.contextFiles.items`) lists a skill only once it is
  loaded (`progressivelyLoaded: true`), by path (`.kiro/skills/<id>/SKILL.md`); the list of *available* skills is
  `_kiro/progressive_context/items_changed`.
- A second `session/new` in a warm process took 0.04 s (the first 2.85 s).
- With a private `KIRO_HOME` the engine still sends `_kiro/steering/documents_changed` with three built-in
  steering documents (`architecture-selection`, `quick-spec`, `bug-fix`, `scope: global`, `uri: builtin:…`): these
  ship inside kiro-cli, not from `~/.kiro`.

### For the spec agent (re-spec input)

- **The `playwright-appian` skill does not load on v3 as shipped.** Phase 51's browser agents (`story-verification`,
  `action-capture`, `setup-composer`) declare it (53-01 §9.3 item 5), so on v3 they would run without it unless the
  model happens to browse for the file. The fix is one line in `playwright-appian` (quote the `description` value, or
  use a `>-` block as `genesis-test-authoring` does), a patch release and a re-vendor into genesis
  (`testexec/vendor/`) — or a Genesis-side normalisation when it provisions the skill. Affected sub-specs: 53-06 §3
  (the `playwright-appian` branch), 53-08 (readiness/skills, if a frontmatter check is wanted), 53-11 (acceptance).
  Worth a check in the same pass: every library skill's frontmatter under a strict YAML parser.
- The skill mechanism itself (D6, D7, D8) holds: workspace skills load from the cwd under a private `KIRO_HOME`;
  personal skills do not appear.

### Fixtures (`genesis/packages/kiro-agent-sdk/tests/fixtures/v3/`)

Cut from the evidence by `scripts/spikes/53-02/make_fixtures.py`. Each `<name>.jsonl` starts with
`{"kiro_cli": "kiro-cli 2.37.1", "fixture", "source", "note"}`, then `{dir, msg}` frames in order (both directions;
engine noise no behaviour depends on — `_kiro/sessions/changed`, steering/governance/policy/memory/powers/
progressive-context/tools-changed notifications — and thought chunks dropped); `<name>.expected.json` is what the SDK
must produce. Placeholders: `<SESSION_n>`, `<UUID_n>`, `<TOOL_CALL_n>`, `<REQUEST_ID_n>`, `<RUN>`, `<HOME>`,
`<PYTHON>`, `<SECRET_n>`, `<REDACTED>` (token-named keys).

`initialize`, `session-new-custom-agent`, `set-mode-active`, `set-mode-dropped`, `mcp-allow`, `mcp-ask-approve`,
`mcp-ask-reject`, `fs-write-client`, `shell-auto-approve`, `turn-usage`, `context-usage`, `cancel`,
`cancel-after-tool`, `mcp-died`, `compact`, `config-option-model`, `model-unavailable`, `available-commands`,
`mcp-status-startup`, `mcp-status-timeout`, `load`, `steer`, `steer-at-turn-end`, `elicitation`, `access-token`,
`unknown-request`, `prompt-image`, `prompt-content-key` (28 pairs) + `tool-ids.json` (W15 table, verified version
2.37.1, KAS 0.66.70, rule capabilities and effects, reserved mode ids). **Deviations from §4's list:**
`model-fallback` → `model-unavailable` (no fallback could be forced, W10); `mcp-status-*` → `mcp-status-startup` +
`mcp-status-timeout`; `unknown-request` is the `-32601` answer to `_kiro/auth/getAccessToken` (the only agent→client
request the harness did not handle); added `cancel-after-tool`, `mcp-died`, `steer-at-turn-end`, `prompt-image`,
`prompt-content-key`.

Loader test `packages/kiro-agent-sdk/tests/test_v3_fixtures.py` (no `__init__.py`, L-092): every required behaviour
has a fixture; each file parses (header, `{dir, msg}` JSON-RPC frames, a non-empty expected file); no `/Users/`,
raw `sess_`/`toolu_` id, JWT-like token or AWS ARN; answers follow their requests; the tool-id table holds the
`run_command` pair. It runs with `PATH` set to an empty folder and asserts no `kiro-cli` or `node` is found (L-112).

### Changes for 53-04..53-07

From W2–W5:

- **53-04 `session.py` activation (W4) — contradicts "fail closed: `AgentNotActive`" if that relies on a
  `set_mode` error:** `session/set_mode` answers `{}` even for an agent the engine dropped. The signals are
  (1) our id in `session/new.result.modes.availableModes` (origin `client`) — check it *before* `set_mode`;
  (2) active: the `config_option_update` with `mode.currentValue` = our id (seen ≤ 30 ms); (3) dropped:
  `_kiro/customAgent/not_found {requestedAgent, fallbackAgent}` plus a `config_option_update` to the fallback
  (`vibe`, the engine's default agent with all built-ins). A failed `set_mode` therefore **moves a running session
  to `vibe`**: the SDK must fail closed (`AgentNotActive`) and never prompt that session again (review M1). The
  reason for a drop is only in `KIRO_HOME/logs/<t>/kiro.log` (`client.agent.drop.invalid {index, error}`); the SDK can read
  it from the session's own `KIRO_HOME` for the error text. Unknown extra keys do not drop an agent. Permission rule
  `effect` values are `allow | deny | ask | evaluate`.
- **53-05 built-in mode ids (W4):** add `semantic_reviewer` to the collision list (`vibe, spec, quick-spec, bug-fix,
  plan, autonomous, semantic_reviewer`).
- **53-05 tool ids (W3):** the shell is listed as `execute_bash` but asks permission as `_meta.kiro.toolId:
  "run_command"`, with `consent.capability: "shell"` and `toolCallId` prefix `run_command_`. The permission request
  carries no `kind`; the `tool_call` (`kind: "execute"`) with the same `toolCallId` arrives 15–55 ms earlier. The
  tool-id fixture needs the registered id → permission id pair (rest of the table in W15).
- **53-04 `usage.py` (W5) — refines "`metered` when `turn_completion` carried a credit entry":** an `aborted`
  `turn_completion` can carry a credit entry (cancel after a finished tool round: 0.05) or none (cancel during a
  model call, even with output already streamed). ADR-032 has a `partial` provenance; the spec agent should say
  whether an aborted turn with a credit entry is `partial` rather than `metered`. A killed process sends no
  `turn_completion` → `unavailable`.
- **53-04 cancel grace (W5, F7):** `session/cancel` → prompt answer `stopReason: "cancelled"` in 0.01–0.03 s, also
  while an MCP tool runs (that call is marked `failed` at once). `turn_completion` precedes the answer by ~10 ms.
  W14 adds the long-turn numbers; nothing measured here needs a grace above a few seconds.
- **53-04 `errors.py` / F3 (W5):** an MCP server that dies after start produces **no** `_kiro/mcp/status` update;
  the call fails with "Connection closed", later calls with "Not connected", and the server is not restarted. A
  "server died mid-turn" classification has to come from the tool failure text, not from `mcp_status`.
- **53-04 `updates.py` (W5 timeline):** the engine's `tool_load` step appeared as a `tool_call_update` ("Tool Load",
  `completed`) with no preceding `tool_call` in some turns; the update fold must accept an update for an unknown id.
- **53-07 Stop (W5, D10):** a prompt cancelled before the model produced output stays in the conversation, and the
  next turn may carry it out (run 1: the next turn wrote the cancelled essay and ran the cancelled 90 s tool call).
  Cancelled mid-stream (`w5a`), it did not. Stop therefore does not always end the request for good; how chat
  should handle that is for the spec agent.
- **53-06 / Phase 51 (W3):** the recipe works on v3 as written. This machine also has a global `apwt` **0.2.0** on
  `PATH`; `npx --no-install` from the workspace picks the export's 0.3.0, as intended (L-101).

From W6–W19:

- **53-04 `usage.py` — contradicts "one `turn_completion` per turn" (W7b):** one `session/prompt` can span several
  engine turns (a steer queued at the end starts another). Sum the credit entries of **every** `turn_completion`
  until the prompt answer, and take `turn_duration_ms` as the sum (or the wall time); `provenance` per F17.
- **53-04 timeouts (W14, F7):** the real-run silence reaches 287 s inside a normal finished turn, MCP calls 19 s,
  shell 38 s, turns 737 s. A silent-turn limit of ≥ 600 s and a tool-stall limit of ≥ 300 s end no normal 900 s
  Phase 51 turn early; the cancel grace can be 5 s. The engine's own MCP connect limit is 60 s, so `startup_timeout`
  for MCP readiness (F3) should be ≥ 60 s or the SDK reports `connecting` servers as slow, not failed.
- **53-04 `steer` (W7):** method `_session/steer {sessionId, message}` (string only), answer `{queued, messageId}`;
  "delivered" = a later `steering_injected` with that `messageId` (0.1 s while the model streams, but only after a
  running tool call ends — 8 s in W7); "queued, unread" = `steering_cleared` without a prior `steering_injected`
  (never observed). Not advertised in `extensionMethods`, so the SDK cannot gate it on
  that list.
- **53-07 / F16 (W7):** the steering method does **not** accept image content — F16's text-only steer is forced, not
  just safe.
- **53-07 Stop (W19, Q11):** without help, a prompt stopped before the answer is carried out by the next turn 3/3,
  and again after `session/load`. Two working remedies measured: the fixed line at the start of the next prompt
  (0/3), and `_kiro/checkpoint/revertMultiple {sessionId, messageId}` on the stopped prompt's `userMessageId`
  (removes it from history; not advertised; refused while a turn runs). Whether a revert also holds across a
  later `session/load` was not measured (review m2).
- **53-04 `load` (W6):** `session/load` needs `customAgents` re-sent; the answer's `_meta.agentMode` names the
  restored agent, and the replay arrives as `user_message_chunk` / `agent_message_chunk` with `_meta.kiro.replayId`
  **before** the load answer, including the old `turn_completion` with `_meta.kiro.replay: true` — the SDK must not
  treat replayed chunks as a new turn, and must not count a replayed credit entry again (ADR-032).
- **53-04 `compact` / F15 (W8):** the progress kind is `summarization_completed` (no start/progress kind seen); there
  is no clear method — Clear stays close + new.
- **53-04 `session.py` (W9, F10):** no off switch for on-demand loading; drop the `_meta.kiro.settings` item from
  `initialize` (only `memory` is read).
- **53-04 / F6 (W10):** an unknown model id is accepted by `set_config_option` and fails at the next prompt
  (`-32000`, `display_error`); validate a model id against `configOptions.model.options` before setting it. The
  fallback frame shape is still unmeasured.
- **53-04 / 53-07 images (W11):** send `prompt` only; `content` alone is refused.
- **53-04 access token / F9 (W12):** request `_kiro/auth/getAccessToken {}`; answer `{accessToken, expiresAt (ISO),
  profileArn, authMethod, provider}` — `profileArn` is required for an IdC/enterprise login, or every model call
  fails. Without an answer, `session/new` still succeeds and the first prompt fails "not signed in"
  (`ModelRegistryUnauthenticatedError`).
- **53-04 HTTP MCP (W13, 52-01 D7):** works with `{type: "http", name, url, headers: []}`; the engine first POSTs
  `server/discover`.
- **53-05 tool ids (W15):** the table above is the fixture. `remote_web_search` shows as title `web_search`, kind
  `other`, capability `web_search`; `delete_file` asks under `fs_write`; reads ask too. **Path scoping works as
  far as tested:** `{capability: "fs_read", match: ["./**"], effect: "allow"}` auto-approved the cwd read and made
  absolute outside paths ask (with their realpath), and `deny` rules refuse without asking. Only `read_file` and
  `list_directory` on absolute paths were tested: `../` traversal, a symlink inside the cwd pointing out, `~`, and
  `grep_search` / `file_search` were not, so 53-05 must cover them before treating this as a boundary (ADR-083 risk
  a; review m5). A misspelt capability is accepted silently, so
  53-05 should project capabilities only from a fixed list.
- **53-04 `close()` / F12 (W16):** on an **idle** session (MCP servers connected, no turn or shell tool running),
  TERM to kiro-cli's group ends the engine and its MCP servers too (0.54 s), and even SIGKILL leaves nothing; a kill
  during a running shell tool (for example an agent's `apwt` command) was not measured — 53-04 should test it before
  relying on "nothing left" (review m3); the engine runs in its own group, so the SDK should still record both pgids and
  check after the kill. The program's `apwt` groups are untouched and stay with `procs.reap` (53-01 §9.3 item 4
  holds).
- **53-04 MCP readiness / F3 (W17):** states seen: `connecting`, `connected` (with `tools`), `failed`
  (`errorMessage`, `failedAuthorization`); no separate "needs auth" state for stdio, and an HTTP 401 server ended
  `failed` with `authType: "oauth"`. `_kiro/mcp/resetServer` exists in KAS (not tested) — a possible remedy for the
  mid-turn MCP death in W5.
- **53-04 elicitation / F8 (W18):** the request is `_kiro/mcp/elicitation`, not `elicitation/create`; decline with
  `{action: "decline"}`.

### Credits

**7.72 metered** of the 20 budget (sum of every `turn_completion` credit entry in the evidence, counting the W7/W8
shared frames once, skipping W6's replayed entry (`replay: true`, 0.03), plus W4's replaced first run 0.03, whose evidence was not kept;
items rounded): W1 0.46 · W2 0.16 · W3 0.71 (both runs) · W4 0.06 · W5 1.35
(both runs + W5a) · W6 0.05 · W7 0.34 (W7 + W7b) · W8 0.06 · W9 0.21 · W10 0.00 · W11 0.04 · W12 0.03 · W13 0.09 ·
**W14 2.46** (the 1 500-word file) · W15 0.88 (incl. path tests) · W18 0.11 · W19 0.56 · fixture capture 0.13 · W16,
W17, W1b, W9state 0. Not metered (no credit entry sent, ADR-032): six aborted or killed turns.

### Changed

genesis (spike, no product code): `scripts/spikes/53-02/{README.md, .gitignore, acp.py, scrub.py, probe_mcp.py,
http_mcp.py, gate.py, rest.py, make_fixtures.py}`, `scripts/spikes/53-02/evidence/*.{json,jsonl}` (31 questions and
variants, 5.4 MB, scrubbed); `packages/kiro-agent-sdk/tests/fixtures/v3/` (28 `.jsonl` + `.expected.json` pairs,
`tool-ids.json`; 772 KB); `packages/kiro-agent-sdk/tests/test_v3_fixtures.py`.

### Tests

- `packages/kiro-agent-sdk`: `pytest -q` **111 passed** (79 before + 32 new in `test_v3_fixtures.py`); `ruff check .`
  clean.
- `ruff check scripts/spikes/53-02/` clean.
- The loader test runs with an empty `PATH` (asserts no `kiro-cli`/`node`). A run in the `python:3.13` image was not
  possible here (the Docker daemon, colima, was not running); the test reads files only.
- Evidence and fixtures: no `/Users/` path, login name, raw session/tool-call id or e-mail address; the access token
  is `<REDACTED>` and the profile ARN `<SECRET_n>` (W12); no QA password or user name appears (W3).

### Review / commits

- genesis (local, base `62537c2`, not pushed): `c7c05b2` (harness + W1), `a885ca3` (W2–W5), `a13798d` (W6–W19 +
  fixtures + loader test), `a54b1f4` (review fixes), `e824d3d` (re-review nit n9).
- Review: `reviews/53-02-review.md` — first pass NEEDS_CHANGES (M1, m1–m6, n1–n8), fixed in genesis `a54b1f4`
  (see Decisions); **re-review: SHIP** (same file; nits n9 fixed in `e824d3d`, n11 marked "bundle", n10 left:
  the QA host is a literal in `make_fixtures.py`).
- **For the spec agent before 53-04 starts:** `53-04-sdk-core.md` §`session.py` activation does not yet mention
  `_kiro/customAgent/not_found` or the fallback to `vibe` (W4, review M1); the "Changes for 53-04" bullet above has
  the correction.

### Decisions / deviations

- No ADR deviation.
- Stopped at the W1 gate FAIL; W1b was a zero-credit diagnosis. W2–W5 ran on the user's instruction; W6–W19 after
  the re-spec (`4ae2915`, `2866d81`). The W1 PASS re-run is 53-06's (D14).
- W3 and W16 used a QA session opened by Genesis's own `ApwtFactory` (W3 signed in as `contracting-officer`; W16
  not signed in); the agent ran only `--version` and a read-only `snapshot` (ADR-082/083).
- W12 used the user's own kiro-cli login token, read in process from kiro-cli's store and handed back to the same
  engine, as the question requires; nothing of it reached a file or this session's output.
- Engine internals (method names, settings, the steer handler) were read from the installed KAS bundle
  (`~/Library/Application Support/kiro-cli/kas/2.37.0-…/node_modules/@kiro/agent/dist/server/acp-server.js`) to find
  what to probe; every behaviour reported above was then measured on the wire (L-044), except where marked "bundle".
- Fixture list deviations: see Fixtures.
- Review (`reviews/53-02-review.md`, NEEDS_CHANGES → fixed): M1 corrected (W4, the 53-04 bullet, the
  `set-mode-dropped` fixture now has `notification`, `fallback_mode`, `mode_before`, `mode_after`); m1 evidenced
  (`w12-answer_no_arn.*`, no model call); m2–m5 qualified above; **m6 open, recorded:** the scrubber works per frame,
  so a value split across streamed chunks escapes it — the loader test now also scans the joined chunk text of each
  stream for `LEAKS` (passes); the model's echo of a steer `messageId` stays raw across chunks in `steer`,
  `steer-at-turn-end` and `w7/w7b/w8.jsonl` (harmless, but its correlation to `steer-<UUID_n>` is lost; re-scrub
  before replay tests depend on it). Nits: n1 (rounding) and n2 (README) fixed; n3 the QA host is `<QA_HOST>` in the
  fixtures (evidence keeps it); n8 W16 no longer reads credentials; n4 forwarded below; n5–n7 left (optional test
  tightening, `tool-ids.json` ids come from the prompt order, v2 `Running:` shell titles classed builtin — the
  maxima are unaffected).
- For 53-06 (review n4): playwright-appian 0.3.0's `SKILL.md` tells the agent "if the versions differ, use npx apwt"
  — a bare `npx`, contrary to L-101; fix it in the same D14 edit.

### Lesson candidates

- **A skill file can be valid for one Kiro engine and invisible to another** (W1; see above).
- **v3 accepts and drops without an error** (W4, W10, W15): an invalid custom agent is dropped at `session/new`
  silently, a `set_mode` to it answers `{}` (and falls back to `vibe`), an unknown model id and an unknown rule
  capability are accepted; confirm by the positive signal, never by the absence of an error.
- **Probe one case per session** (W5 run 1).
- **One prompt is not one engine turn** (W7b): a steer at the end starts a second turn inside the same
  `session/prompt`, with its own `turn_completion` — sum credits over the prompt, not the last turn.
- **A stopped prompt is not a cancelled request** (W19): the conversation keeps it and the next turn — or a
  `session/load` — carries it out unless the client says not to or reverts it.
- **The installed engine is a readable bundle:** when an extension method is not advertised, the KAS bundle names
  it (steer, revert, resetServer); probe from there, never from the docs (extends L-044).

### Code-map changes

None in product code. New test assets: `packages/kiro-agent-sdk/tests/fixtures/v3/` (the v3 wire fixtures 53-04/53-05
replay) and `tests/test_v3_fixtures.py`. The spike harness `scripts/spikes/53-02/` is historical (outside F13's
import gate).

## Context manifest

```toml
areas    = ["sdk-acp", "chat", "core-engine"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-029", "ADR-031", "ADR-032", "ADR-034", "ADR-045", "ADR-069", "ADR-083"]
lessons  = ["L-001", "L-011", "L-016", "L-021", "L-024", "L-041", "L-044", "L-046", "L-064", "L-087", "L-100", "L-101", "L-104", "L-112"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/scripts/spikes/53-02/**", "genesis/packages/kiro-agent-sdk/tests/fixtures/v3/**", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py"]
upstream = []
```
