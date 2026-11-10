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
| W15 | The built-in tool ids on 2.37.1: registered id vs permission `toolId` for each built-in D9 and F2 name (`execute_bash`/`run_command`, `read_file`, `list_directory`, `fs_write`, `str_replace`, `fs_append`, `grep_search`, `file_search`, `web_fetch`, `remote_web_search`, `delete_file`); the meta tools (`tool_load`, `tool_call`, `disclose_context`) | the table for 53-05's fixture |
| W16 | Process tree: which processes kiro-cli starts (engine child, MCP servers) and their process groups; whether killing kiro-cli's own group reaches them (F12). Also: a program-started `apwt` session daemon and its Chromium (own groups, recorded in `<run>/.pids`, 53-01 §9.3 item 4) survive that kill and are still reaped by `testexec/procs.py` | tree recorded; a kill that leaves nothing of kiro-cli's behind and leaves the program's apwt processes to their own reaper |
| W17 | `_kiro/mcp/status` states for a server that fails to start, needs auth, or is slow; how long `connecting` lasts (F3) | states + timings |
| W18 | Elicitation: the request an MCP tool's elicitation produces on v3 (`elicitation/create` or `_kiro/mcp/elicitation`) and the decline answer (F8) | request + decline recorded |

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

## As built (2026-11-10, genesis-dev) — STOPPED AT THE GATE: W1 FAILS

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
| W2–W5 (gate) | **Not run** — stopped after the W1 FAIL, as the spike's rules require. | — |
| W6–W18 | Not started. | — |

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

### Credits

0.46 metered (W1's one turn; W1b sent no prompt). Budget 20.

### Changed

genesis (spike only, commit `c7c05b2`): `scripts/spikes/53-02/{README.md,
.gitignore, acp.py, scrub.py, probe_mcp.py, gate.py, evidence/w1.json, w1.jsonl, w1b.json, w1b.jsonl}`. No product
code, no fixtures yet.

### Tests

`ruff check scripts/spikes/53-02/` clean. Evidence scan: no `/Users/` path, UUID, `sess_` id, `toolu_` id, login
name or e-mail address left in `evidence/`.

### Review / commits

genesis `c7c05b2` (local, base `62537c2`; not pushed). project-tracker: this As built. The review by genesis-review and
the fixtures follow when the spike resumes.

### Decisions / deviations

- No ADR deviation.
- Stopped at the first gate FAIL as instructed; W1b is a zero-credit diagnosis of that failure, not a workaround.

### Lesson candidates

- **A skill file can be valid for one Kiro engine and invisible to another.** v3 parses `SKILL.md` front matter with
  a strict YAML parser and drops a file with an unquoted `: ` in `description`, logging only to `kiro.log`; the
  model then never sees the skill. Check the skill list (`_kiro/progressive_context/items_changed`), not a canary in
  the reply: the model can still find and read the file by browsing.

### Resume note

- **Done:** harness, W1 (FAIL) and W1b (root cause).
- **Next, once the spec agent has re-specced the W1 consequence** (or the user says to go on): run `gate.py w2`…`w5`
  (W3 needs the QA site; it was reachable on 2026-11-10, HTTP 200 on `/suite/`), then W6–W18, then the fixtures and
  the loader test, the review, the commits and the rest of this As built. For W1, a re-run with a fixed
  `playwright-appian` skill shows the PASS line.
- **Open:** whether the v2 engine ever offered this skill (51-03 S11's agent read both files because the prompt
  pointed it there); not measured.

## Context manifest

```toml
areas    = ["sdk-acp", "chat", "core-engine"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-029", "ADR-031", "ADR-032", "ADR-034", "ADR-045", "ADR-069", "ADR-083"]
lessons  = ["L-001", "L-011", "L-016", "L-021", "L-024", "L-041", "L-044", "L-046", "L-064", "L-087", "L-100", "L-101", "L-104", "L-112"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/scripts/spikes/53-02/**", "genesis/packages/kiro-agent-sdk/tests/fixtures/v3/**", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py"]
upstream = []
```
