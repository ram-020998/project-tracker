# Phase 53 — ADR draft (ADR-086)

> **Status:** DRAFTED 2026-11-10 by genesis-dev in 53-03 (§2). **Proposed**, not yet in `reference/decision-log.md`.
> **Filing (53-12, genesis-docs):** `genesis-ctx add adr` with the fields in the header table, `--status accepted` (so
> the heading, the tool's own Status line and `tags/adr.toml` all read accepted), and as `--body-file` the bullet list
> **from `- **Context.**` on**: the tool writes the Status line itself, so fold this draft's Status details (date,
> spec set, shipped versions) into that line with one edit. `--amends` takes the seven ids **space-separated after one
> flag** (`nargs="+"`); a repeated flag keeps only the last id, and a comma-joined value is refused. The number is
> fixed at filing (ADR-081..085 are Phase 51's).
> Sources: umbrella `../phase-53-kiro-sdk-v3.md`; `53-01-findings.md` §3 (probes P1–P17), §7 (D1–D16), §8 (F1–F15),
> §9 (Phase 51 re-check), §9.5 (F16), §10 (spike re-spec, F17); `53-02-spike-v3-wire.md` As built (W1–W19, the timings,
> the W15 tool-id table, review SHIP); evidence `genesis/scripts/spikes/53-02/evidence/`, fixtures
> `genesis/packages/kiro-agent-sdk/tests/fixtures/v3/`; the 2026-11-03 probes in `evidence/` of this folder.

---

## ADR-086

| field | value |
|---|---|
| `--id` | `ADR-086` |
| `--title` | `Genesis drives Kiro only through the v3 engine, with a Genesis-owned Kiro home, projected trust and managed skills (Phase 53)` |
| `--areas` | `sdk-acp,chat,core-engine,config-secrets,security` |
| `--rule` | `Start Kiro only as kiro-cli acp --agent-engine v3 under a Genesis-owned KIRO_HOME (nothing loaded from ~/.kiro; reads unscoped); trust: a projected agent, activation verified, fail closed; skills only from Genesis.` |
| `--amends` | `ADR-029 ADR-031 ADR-032 ADR-034 ADR-045 ADR-069 ADR-083` |
| `--status` / `--phase` | `accepted` at filing (this draft is proposed) / `53` |

- **Status:** **Proposed** — 2026-11-10 (Phase 53; spec set `specs/phase-53-kiro-sdk-v3.md` + `53-01..53-12`; findings
  `53-01-findings.md`; spike `53-02-spike-v3-wire.md`, review `reviews/53-02-review.md` = SHIP). Data model built in
  53-03 (m0029 → DB v29). Measured against `kiro-cli` 2.37.1 (KAS 0.66.70) on the user's macOS machine.
- **Context.** Kiro CLI 3.0 makes the v3 engine the default and is retiring v2 ([Kiro blog](https://kiro.dev/blog/cli-3/)).
  Genesis starts every Kiro session with `--trust-tools` or `--trust-all-tools`, which `kiro-cli acp --agent-engine v3`
  rejects at launch (P1). Most of what the v2 SDK relied on is gone or moved on v3: credits (`_kiro.dev/metadata`), the
  command catalog and `_kiro.dev/commands/execute`, `_kiro.dev/{compaction,clear}/status`, `session/set_model`, slash
  commands sent as prompts (P10–P12). Separately, every Genesis session loads the user's global Kiro MCP servers,
  skills, steering and agents (P15; 51-03 P10, ADR-083 risk d), contrary to ADR-004. Phase 53 rebuilds
  `kiro-agent-sdk` for v3 only (D1, D5) and moves every caller: chat in every mode, workflow agent nodes
  (`kiro_node`), the catalog probe.
- **Decision.**
  1. **One engine, no trust flags.** Every Kiro process Genesis starts is `kiro-cli acp --agent-engine v3`, with no
     `--trust-tools` / `--trust-all-tools` (both exit 2 under v3, P1). The v2 path (`agent_engine`, the trust flags,
     `_kiro.dev/*`, `session/set_model`, slash commands as prompts) is deleted before the release; there is no engine
     setting and no fallback (D5). The minimum `kiro-cli` is the verified 2.37.1; below it, or without v3, preflight
     refuses chat and runs with "update kiro-cli"; a newer unverified release warns once and runs (F5, 53-08).
     *Reason:* one code path for an engine that is the only one left; a v2 fallback would live weeks (D5), and the
     user accepted the gap until this phase ships (D4, D12). *Evidence:* P1; P2 (`initialize`: `loadSession`,
     `sessionCapabilities`, `_meta.kiro.extensionMethods`).
  2. **A Genesis-owned `KIRO_HOME` for every process.** `<run folder>/_kiro/` per workflow run (shared by the run's
     agent turns, removed by run retention, ADR-022) and `~/.genesis/kiro-home/chat/` for chat and the catalog probe
     (D6). Genesis never reads the user's `~/.kiro` for agents, MCP servers, skills or steering. Genesis's own MCP servers
     are unaffected: they come from Genesis's registry and travel in `session/new.mcpServers` (ADR-002/004). The user's
     sign-in is unaffected: credentials are not under `KIRO_HOME` (P16). *Reason:* the only way to stop the engine
     loading the user's global configuration (P15), and per-run homes keep the engine's session records and logs with
     the run they belong to, which Phase 52's per-run sandbox needs (52-01 D11). *Evidence:* P15 (default home: the
     user's `jira`, `testcase-mcp`, `power-jarvis-jarvis` servers started, `~/.kiro/skills/appian` listed, the user's
     steering and every `~/.kiro/agents` agent offered as a mode) against P16 (empty private home: none of it loaded,
     sign-in worked); W1 (personal skills absent from the engine's skill list); W2 (`genesis-kb`, blackboard and a probe
     server reached `connected` under a private home, env as a list, L-001); W6 (the session record lives in the home,
     so `session/load` works across processes). *Reconciles* ADR-034 §2, ADR-069 alternative (c) and L-024 ("do not set
     `KIRO_HOME`"): that warning was about relocating the user's own agents, sessions and login inside the user's home.
     Genesis's homes are separate folders, the user's `~/.kiro` is left untouched, and the login does not live in
     `KIRO_HOME`. **What this does not promise.** The engine loads nothing from `~/.kiro`, but an agent's built-in read
     tools (`read_file`, `list_directory`, `grep_search`, `file_search`) can still read any path the user can, including
     `~/.kiro`: in W1 the agent listed `~/.kiro` and `~/.kiro/skills` unprompted, and W15 case A showed an
     `fs_read` rule with `match: ["**"]` allows absolute paths outside the cwd without asking. This is ADR-083 risk (a);
     it closes in Phase 52. **This phase adds no path scope** (D16): W15's finding that `match: ["./**"]` confines
     `read_file`/`list_directory`, and its untested cases (`../`, a symlink out, `~`, the search tools), are Phase 52
     input. The workflow shell can read anything as well (item 7). Also, the engine still offers three steering
     documents that ship inside `kiro-cli` (`builtin:` URIs, W1); they do not come from `~/.kiro`.
  3. **Trust is a projected custom agent, activated and verified, with a Genesis backstop.** Each session sends one
     agent in `session/new` (`_meta.kiro.customAgents`; re-sent on `session/load`) with an explicit `tools` list in v3
     ids and `permissions.rules` that allow only what Genesis trusts (effects `allow | deny | ask | evaluate`). Rules per
     caller (53-05): **chat** `read_only` and `copilot` list only the mode's MCP tools, MCP read tools with allow rules,
     copilot's mutating tools listed with no rule so they reach `ask` and the confirm card (ADR-033); the six
     spec-style modes add the file built-ins (`read_file`, `list_directory`, `fs_write`, `str_replace`, `fs_append`)
     with allow rules, writes still confined to `fs_write_root` by the client (P9); no chat mode has a shell (F2).
     **Workflow nodes** list D9's built-ins (`execute_bash`, `read_file`, `list_directory`, `fs_write`, `str_replace`,
     `fs_append`, `grep_search`, `file_search`, `web_fetch`, `remote_web_search`), auto-approved
     (`permission_mode="auto_approve"`), never `delete_file`; MCP tools are only `node.tools ∩ server allowlist` (a node
     with no tool list: every tool of its servers within each allowlist) plus the blackboard tools (D9). File reads keep
     an unscoped `fs_read` rule (`match: ["**"]`, D16). **Activation** (W4): `session/set_mode` answers `{}` whether or
     not the agent exists, so its answer proves nothing. Genesis requires (i) its id in
     `session/new.result.modes.availableModes` with `source.origin: "client"` before `set_mode`, and (ii) a
     `config_option_update` with `mode.currentValue` = its id after it. On `_kiro/customAgent/not_found` (the engine has
     dropped the agent and **moved the running session to its bundled `vibe` agent**, every built-in) or a missing
     signal, the SDK fails closed (`AgentNotActive`), never sends a prompt on that session and closes it; the drop
     reason is read from the session's own `KIRO_HOME` log (`client.agent.drop.invalid`). Agent ids avoid the bundled
     modes `vibe, spec, quick-spec, bug-fix, plan, autonomous, semantic_reviewer`. **Backstop:** behind the engine, the
     SDK checks every `session/request_permission` against the Genesis allowlist before answering, with the tool's
     identity taken from `_meta.kiro.toolId` / `mcpTool.identity` (never the title) and the measured id table (the shell
     is listed as `execute_bash` but asks as `run_command`, capability `shell`; W3, W15); a refusal gets a fixed,
     cause-specific notice (F11). ADR-031's fail-closed chat and ADR-029's `node.tools ∩ allowlist` cap are enforced
     this way (D9, F2). *Reason:* v3 has no trust flags; the projected agent is the engine's own trust surface, and its
     tool list is a hard limit, so the MCP cap becomes real instead of deciding only which calls skip a prompt.
     *Evidence:* P3–P7 (agent listed as `origin: client`; `tools` a hard limit, `tool_load` of an unlisted tool →
     `not_found`; allow rule runs without a request; a listed tool without a rule asks and a reject fails the call);
     W4 (`set-mode-active`, `set-mode-dropped` fixtures); W3 and W15 (`tool-ids.json`); KiroCrew
     `acp/runtime_session_create.py:856-930` (always activate, refuse a non-client mode).
  4. **Credits and context come from `session_info_update`.** Credits = the sum of the `unit: "credit"` entries in
     every non-replayed `turn_completion.promptTurnSummaries` until the `session/prompt` answer (one prompt can span
     several engine turns, W7b); context = `context_usage.usagePercentage`. **Provenance per turn (F17):** `metered`
     when the engine sent a credit entry, also for an aborted turn (a cancel after a finished tool round reported 0.05);
     `unavailable` when it did not (a cancel during a model call, a killed process). `partial` stays an aggregate value
     only (some turns reported, some not; `genesis/runs/eventlog.py:188-207`); a cancellation shows in the turn's status,
     not its provenance. Credits replayed by `session/load` (`_meta.kiro.replay: true`) are not counted again (W6). The
     ADR-032 rule is unchanged: real, per turn, provenance on every figure, never estimated. *Reason:* the v2 source is
     gone (P10); an engine-sent number is real metered data even for an aborted turn, and a per-turn `partial` would
     change what the run totals already mean. *Evidence:* P10; W5 (the per-case table: `aborted` with and without a
     credit entry, no `turn_completion` after a kill); W6; W7b (0.029 + 0.032 in one prompt).
  5. **The chat surface uses v3's own methods.** Models via `session/set_config_option {configId: "model"}`, validated
     against `configOptions.model.options` first (an unknown id is accepted and fails only at the next prompt, W10);
     the model is still chosen at creation and applies at the next start (21-05, F16). The `/` command list from the
     standard `available_commands_update`. Compact via `_kiro/session/compact` (progress `summarization_completed`).
     Clear = `session/close` + `session/new` (v3 has no clear method, W8); Genesis's transcript stays (F15). Steering
     (D10): Send during a turn calls `_session/steer` (text only, F16), and a steer the turn did not read is sent as the
     next message. **Stop** = `session/cancel`, which keeps the session (D10). Because v3 keeps a stopped prompt and the
     next turn may carry it out (W5 run 1; W19 a: 3/3), the next prompt to that chat starts with a fixed,
     program-owned note, "[The previous request was cancelled by the user. Answer only the request below; use the
     cancelled request only if this request refers to it.]", sent once per Stop and decided from the stored transcript
     (the latest turn ended cancelled), so it survives a restart and a `session/load`, which replays the stopped prompt
     (W19 d). The note never contains the stopped request's text or anything a model or tool produced. Genesis does not
     use `_kiro/checkpoint/revertMultiple` (D15). **Resume:** chat stores the v3 session id
     (`chat_sessions.kiro_session_id`, m0029) and resumes an idle-reaped or restarted chat with `session/load`, falling
     back to today's preamble replay if the load fails (F4, 53-07). `_kiro.dev/commands/execute` and `session/set_model`
     are not used. *Reason:* the v2 methods fail on v3 (P11: `set_model` → `-32603`; P12: `execute` → `-32603`, `/compact`
     as a prompt is plain text); the note is adapted from KiroCrew's one-shot cancelled-turn flag (`prev_turn_cancelled`,
     `session_parts/record.py:151`, consumed once in `dashboard/chat_turn/prompt_assembly.py:712`), but unlike KiroCrew's
     `cancelled_turn_preamble` (`context_assembly/replay.py:565`), which puts the stopped turn's user
     message and assistant text back into the prompt, Genesis's note carries no text from the stopped turn; it uses no
     unadvertised method. *Evidence:* P11–P13 (cancel keeps the session); W6 (load
     replays history and the next turn recalls it); W7 (`steering_queued` → `steering_injected`; an image is refused);
     W8; W10; W19 (b: a shorter fixed line, "The previous request was cancelled by the user. Do not continue it.",
     stopped the carry-over 0/3; the D15 wording itself is first tested in 53-11 A3; c: revert exists but is
     unadvertised; d: load replays the stopped prompt). *Risk:* the note relies on the model obeying it; 53-11 A3 tests
     the exact wording live, and revert stays a possible later fallback.
  6. **Skills come only from Genesis.** Chat sees only the managed workspace `~/.genesis/.kiro/skills/`, read in place
     with no copies: read-only chat and copilot reach it through their cwd (`state_dir`, workspace skills); the six
     spec-style modes, whose cwd is the per-session skill-output sandbox (L-041), reach it through the projected
     agent's `resources`, `["skill://<state_dir>/.kiro/skills/*/SKILL.md"]` (SDK `KiroAgentOptions.skill_dirs`: an
     absolute, existing directory; a relative path, `~`, a glob or `..` is refused). No session gets both, so no skill
     is listed twice (53-13). A
     workflow node's declared skills (`kiro_node(skills=[…])`, ADR-069) are provisioned into `<run>/.kiro/skills/` from
     that managed workspace. There is no fallback to `~/.kiro/skills` and Genesis does not copy personal skills in (D7,
     D8). The `appian` skill is published to the genesis-workflows library so it installs from Settings → Catalog →
     Skills, which gains only an Update button (D7). The one other source is Phase 51's `playwright-appian` skill, read
     from the run's own workspace export (`<run>/checkout/node_modules/playwright-appian/skills/`), so the agent reads
     the skill of the exact `apwt` version it drives (51-07 §7, 53-01 §9.3 item 5). **Front matter is checked** on every
     source before provisioning (`parse_skill_md` + `validate`, PyYAML `safe_load`, `genesis/skills/model.py`): an
     invalid file fails the node with a message naming the skill, the YAML error and the remedy ("Update testing runtime"
     for `playwright-appian`, Settings → Catalog → Skills for a managed skill); a declared skill that is not installed
     fails the run at the start, as today, pointing to the Skills tab (D8, D14). The defect W1 found is fixed upstream:
     `playwright-appian` 0.3.1 writes `description` as a `>-` block, its skill test parses front matter strictly, and
     genesis re-vendors the published tarball byte for byte (D14). Whether a skill loaded is read from the engine's
     skill list (`_kiro/progressive_context/items_changed`), not from a canary in the reply (§10.1). *Reason:* one rule
     for chat and workflows; a workflow no longer depends on one user's personal folder, and v3 drops a skill with bad
     front matter silently (log only). *Evidence:* W1 (managed `genesis-test-authoring` listed and loaded under a private
     home; `playwright-appian` 0.3.0 dropped, `skill.frontmatter.invalid … (3:112)`; the model found the file only by
     browsing); W1b (quoting the value lists it, 0 credits); 51-03 S11 (provisioned skills work in a run); 53-13 R1–R4
     (kiro-cli 2.37.1, 0.10 credits, fixture `agent-resources-skills`: a spec-style agent with `resources` and an
     empty sandbox cwd activated, the engine listed exactly the managed folder's three skills with scope `global`, a
     prompt loaded `gam` through `disclose_context` with its canary back and no browsing, a skill added later was
     listed after `session/load` and `session/new` in a new process; the same agent without `resources` listed none;
     an empty folder still activates; with the production nesting, cwd `<state>/skill-output/<id>`, each skill is listed
     once with `resources` and not at all without it, so the engine does not walk up from the cwd).
  7. **ADR-083 and ADR-029 (53-01 §9.3 item 7).** ADR-083's accepted risk (d) closes: no Genesis session, workflow turn
     or chat, loads the user's global Kiro MCP servers (item 2; P15 against P16). ADR-029/083's "a node with no tool list
     trusts every tool" becomes "D9's built-ins plus the node's own servers within their allowlists", enforced by the
     projected tool list (item 3; P5). ADR-083's risks (a) (session rules not enforced against the agent: its shell and
     read tools reach the user's files and the loopback API), (b) (the agent shell inherits the worker's whole
     environment, which Phase 51's `npx --no-install apwt` turns need for `PATH` and `PLAYWRIGHT_BROWSERS_PATH`; 53-01
     §9.3 item 2) and (c) (passwords in the `open --login` and replay subprocess environments) stay open until Phase 52.
     *Reason:* D6 and D9 remove (d) and the uncapped tool list for every session at once, before Phase 52; nothing in
     this phase isolates the shell. *Evidence:* 51-03 P10 (`d3c-p10.json`); P5, P15, P16; W3 (the Phase 51 recipe on
     v3, 0.42 credits).
- **Alternatives rejected.** A v2-pin hotfix or a pin in Phase 51's release (D4, D12: the user accepted the gap). Both
  engines behind a setting for a release (D5 B: two paths for an engine on its way out). One shared Kiro home for all
  runs (D6 A: every run's records and logs mixed, cleanup by per-turn deletes). Copying `~/.kiro/skills` into the chat
  home (D7 B: copies skills that may be unwanted). Keeping the `~/.kiro/skills` fallback for workflows (D8 B). Built-ins
  only when a node lists them (D9 B: breaks working nodes, e.g. `technical-design-analysis` `analyze_section` ran 26
  shell commands without listing the shell). A separate Steer button, or steering in the SDK only (D10 B, C). Genesis
  rewriting another package's front matter while provisioning (D14 B: hides the defect). Revert on Stop, alone or with
  the note (D15 A, C: an unadvertised method, and the engine would forget a request the transcript still shows).
  Path-scoped reads in the spec-style chat modes or everywhere (D16 A, B: deferred whole to Phase 52; for workflow nodes
  it would only look safer, since their shell reads anything). Trusting `session/set_mode`'s answer as proof of
  activation (W4: it answers `{}` for a dropped agent). A warm process pool (D1: only the 0.7 s start + `initialize` can
  be done ahead, and a pool shared across runs conflicts with ADR-012).
- **Consequences.**
  - **Amends ADR-029:** the effective-trust cap `node.tools ∩ server.allowlist` is now enforced by the engine's tool
    list, and a node with no tool list gets D9's built-ins plus its servers within their allowlists, not every tool.
  - **Amends ADR-031:** enforcement items 1–2 change mechanism: the read-only allowlist is the projected agent's tool
    list and allow rules (not `trust_tools`), and `auto_deny` answers anything else; the SDK backstop that checks
    identity from `_meta` is new. Item 3 (`allow_fs_write=False`, the client refuses `fs/write_text_file`) is unchanged,
    since the write is still a client call (P9). The "bounded transcript preamble" on a cold client becomes
    `session/load` with the preamble as the
    fallback (m0029). Chat is still in-process and still read-only where ADR-031/033/034/045/076 say so; a steered
    message is a user message (D10).
  - **Amends ADR-032:** the source moves from `_kiro.dev/metadata.meteringUsage` to `session_info_update`
    (`turn_completion`, `context_usage`); per-turn provenance is `metered` or `unavailable` (F17); the rule is unchanged.
  - **Amends ADR-034:** chat no longer sees the user's global `~/.kiro/skills` ("the user's own global skills remain
    active" no longer holds) and Genesis now sets `KIRO_HOME`, to its own folder, which leaves the user's personal Kiro
    home untouched (item 2). Skills stay filesystem-provisioned in the managed workspace, and the `fs_write_root` sandbox
    is unchanged.
  - **Amends ADR-045:** the CLI surface is reached through v3's methods (item 5); `session/set_model`,
    `_kiro.dev/commands/{available,options,execute}` and `_kiro.dev/{compaction,clear}/status` are no longer used; Stop
    keeps the session; steering is added (D10, F16). Write-capable actions stay human-confirmed (ADR-033).
  - **Amends ADR-069:** workflow skills come only from the managed workspace (plus the run checkout's
    `playwright-appian`), with front matter checked; the "rely on the global `~/.kiro/skills`" path is removed, and
    rejected alternative (c) is reconciled by item 2.
  - **Amends ADR-083:** accepted risk (d) closes; the "trusts every tool" consequence is replaced (item 7); risks (a)–(c)
    stay open until Phase 52.
  - Unchanged: ADR-002/004 (per-session MCP over ACP, now with no global servers beside them), ADR-020 (Genesis mutates
    no global Kiro configuration and now does not read it either), ADR-033 (confirm cards), ADR-051 (the
    `AgentProvider` seam), ADR-077 (role agents never `--trust-all-tools`). `kiro_node`'s signature is unchanged, so no
    workflow changes and `CORE_MAJOR` stays 1 (F1, ADR-019). Data: m0029 adds `chat_sessions.kiro_session_id`
    (nullable), DB v28 → v29. Phase 52 (agent runtime isolation) builds on this phase and closes ADR-083 (a)–(c) and the
    unscoped reads.
