# 53-06 — Workflow nodes on v3, and managed-only skills

> **Status:** BUILT 2026-11-11 (genesis 0c0a4aa + d5a6a4e, genesis-workflows b097719, playwright-appian 38f87fd; review
> SHIP, round 2). SPEC-DRAFTED 2026-11-03; re-specced 2026-11-10 (D14). Repos: **genesis** (`packages/genesis-core`,
> `genesis/runtime/context.py`), **genesis-workflows** (the `appian` skill), **playwright-appian** (the skill's front
> matter, 0.3.1). Parent: `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D5, D6, D8, D9, D14;
> F1, F3, F6, F7, F10.

## 1. Goal

Every workflow agent turn runs on the v3 SDK with the run's own Kiro home, D9's trust, and the same events, telemetry and
blackboard behaviour as today; workflow skills come only from the managed workspace. No workflow's `graph.py` changes
(`kiro_node`'s signature is unchanged, F1; `CORE_MAJOR` stays 1, ADR-019).

## 2. `kiro_node` (`packages/genesis-core/genesis_core/nodes/agent.py`)

- **Home** (D6): `kiro_home = <ctx.workspace.root>/_kiro` (created if missing; shared by the run's turns). The run's
  artifact listing hides `_kiro/` from the documents view (it holds engine records and logs, not deliverables) but keeps
  it on disk for debugging and retention (ADR-022).
- **Trust** (D9): `TrustPolicy(builtins=("shell", "fs_read", "fs_write", "grep", "glob", "web_fetch", "web_search"),
  mcp_tools=<effective>, auto_approve=<all of them>, mode="auto_approve")`, where `<effective>` =
  `_compute_effective_trust(tools, mcp, ctx.mcp)` (`agent.py:137-166`) plus `BLACKBOARD_TOOLS`; a `None` result
  (no node list, no allowlists) becomes `@<server>` for every server in `mcp` + `@blackboard` (when the node has the
  blackboard). So a Phase 51 node (no `mcp`, no `tools`) gets D9's built-ins + `@blackboard`, and a `blackboard=False`
  node with `mcp=[]` gets built-ins only (53-01 §9.2). Never `--trust-all-tools`
  semantics: only the node's servers are reachable. `permission_mode="auto_approve"` is now explicit (52-01 D9).
- **Agent prompt:** a short fixed Genesis node prompt (role: a narrow workflow step; save large tool output with
  `save_tool_output`, L-021); the node's `prompt_fn` text stays the user prompt.
- **MCP readiness** (F3): if `mcp_status` reports a failed server, the turn ends before the prompt with
  `ResultMessage.error` classified `mcp_failed` (no credits spent); the reliability trio retries/escalates as today
  (ADR-011).
- **Events** (shapes unchanged, ADR-066, L-005): `_emit_message` (`agent.py:169-192`) reads `name` (now `@server/tool`
  → the tool name, or the built-in's registered id such as `execute_bash` or `read_file`, D19), `raw_input` (now the MCP `arguments`, 53-04), `output`; `save_tool_output`
  detection (`agent.py:321-337`) keeps `raw_input["document"]` because 53-04 unwraps `arguments`; `agent.result` keeps
  `credits, context_pct, turn_duration_ms, provenance` and adds `model`, `fallback_from` when present (F6); telemetry
  keys unchanged.
- **Timeouts** (F7): `turn_timeout` stays the ceiling (default 420 s; Phase 51 nodes set 600–900 s); silent and
  tool-stall limits from the SDK defaults; a node may not raise them.
- **Environment:** the turn keeps the worker's environment plus `KIRO_HOME` (53-04; Phase 51's `npx --no-install apwt`
  needs the worker's `PATH`, 53-01 §9.3 item 2).
- **AgentProvider** (ADR-051): `KiroAcpProvider` and `_load_real` unchanged in shape; `options_cls()` returns the new
  `KiroAgentOptions`; the test hooks `set_collect_impl` / `set_agent_provider` keep working (genesis-workflows tests use
  them).
- **Public names switch here** (53-04 §1 sequencing): `kiro_agent_sdk.KiroAgentOptions` / `KiroACPClient` / `query` /
  `collect*` point at the v3 client (`_v3client.py`). Chat, still on v2 until 53-07, imports `LegacyKiroACPClient` /
  `LegacyKiroAgentOptions` (`chat/manager.py`, one import line); `test_public_surface.py` pin updated.
  `test_core_units.py:211-226` (asserts `trust_tools` / `trust_all_tools`) is rewritten to the `TrustPolicy` shape.
  53-05 must be BUILT first.

## 3. Managed-only skills (D8)

- `genesis/genesis/runtime/context.py:76-97` `_skill_source`: search **only** `settings.skills_dir`; remove the
  `~/.kiro/skills` entry (`:93`). **Keep** Phase 51's `playwright-appian` branch (`:87-92`, 51-07 §7): that skill's
  one home is the run's workspace export (`<run>/checkout/node_modules/playwright-appian/skills/`), a Genesis-owned
  source, so it stays consistent with D8. A test pins both: managed skills resolve, `playwright-appian` resolves from the
  checkout, and a skill present only in `~/.kiro/skills` does not resolve.
- `core/nodes/agent.py:106-110` error text: "skill '<id>' (declared by node '<node>') is not installed — install it in
  Settings → Catalog → Skills." (no `~/.kiro/skills` wording).
- **`appian` skill** (genesis-workflows): **copy** (never move or edit) the user's `~/.kiro/skills/appian/` into
  `skills/appian/` (`SKILL.md`, `references/**`, and the component registry; content confirmed by the user
  2026-11-10). The user's personal copy is untouched (ADR-020). From then on the library copy is Genesis's one home
  for the skill: changes go through an MR to genesis-workflows (ADR-005/029), and Genesis installs it into the managed
  workspace from Settings → Catalog → Skills. Register it
  in `genesis-workflows/skills-registry.json`; the library's skill CI gates (`validate_skills`) green. `story-implementation`
  (`workflows/story-implementation/graph.py:120-121`) is unchanged and now installs `appian` from the library.
  **Skill folders (D17):** in `genesis/skills/store.py`, drop the `scripts/`/`references/`/`assets/` restriction on
  bundled files (`:151-171`). A file may sit at any relative path inside the skill. Keep the refusals for absolute
  paths, `..` segments and dot-file or dot-folder segments, and keep the size and count caps (`:28-29`). Update the
  module docstrings (`store.py:4-5`, `model.py:7`), which name only the three folders. Copy `appian` with
  `registry/components-registry.json` unchanged; change only `references/documentation-lookup-strategy.md:191` from
  `skills/appian/registry/…` to the skill-root-relative `registry/components-registry.json`. Tests: a bundled file
  under `registry/` installs; `../x`, `/abs`, `.hidden/x` and an over-cap file are still refused; `appian` installs
  from the library fixture through `SkillInstaller.install_selection` (`genesis/dist/skill_install.py:50-59`) and
  `_skill_source` resolves it.
- **Workflows that declare skills:** a run fails fast with the message above when the skill is not installed (as today,
  better text). Consider (backlog, not this phase): auto-installing a workflow's declared library skills at
  `genesis install`.
- **Front matter is checked before a skill is provisioned (D14 part 3).** `_skill_source` runs
  `genesis.skills.model.parse_skill_md` + `validate(expected_id=<id>)` on the resolved `SKILL.md`. This applies to
  every source: the managed workspace and the `playwright-appian` checkout branch. The check lives in genesis because
  genesis-core has no YAML dependency. On failure it raises an error that `_provision_skills` (`agent.py:78-113`)
  passes on as the node's failure: "skill '<id>' (declared by node '<node>') has invalid front matter: <YAML error>.
  <remedy>". The remedy for `playwright-appian` is "Update testing runtime on the application's Testing → Setup"; for a
  managed skill it is "update or reinstall it in Settings → Catalog → Skills". The node fails at the start, before
  any credits are spent; it never runs without a declared skill.
- **`playwright-appian` 0.3.1 (D14 parts 1–2; repo `playwright-appian`, branch `main`, own semver; skill
  `genesis-playwright-appian-dev`):** `skills/playwright-appian/SKILL.md:3` → `description: >-` block. In the same edit, fix `SKILL.md:16`: it currently
  says "if the versions differ, use npx apwt", a bare `npx` that L-101 forbids. Tell the agent to stop and report a
  version mismatch instead (53-02 review n4). In
  `tests/skills/skill.test.ts:54-57`, replace the text-prefix assertion with a strict YAML parse of the front matter
  (name = `playwright-appian`, a non-empty `description`). Use `js-yaml`, the parser whose error v3 logged, as a
  devDependency. Bump to 0.3.1 with that repo's changelog and planning notes. Commit locally. Publishing the package
  and re-vendoring it into genesis are 53-12 steps, because the vendored tarball must be the published one byte for
  byte (`genesis/testexec/vendor.py:7-16`). Until then, test with a locally packed 0.3.1 (`npm pack`).
- **53-02 W1 re-run:** with the locally packed 0.3.1 in a workspace export, W1's PASS line (both skills in the engine's
  skill list, `_kiro/progressive_context/items_changed`; the personal skill absent) is recorded in 53-02's As built.

## 4. Tests

genesis-core: `kiro_node` builds the expected `TrustPolicy` and `kiro_home` for (no tools, a tool list, an allowlist cap,
blackboard on/off); an `mcp_failed` turn emits `agent.result` with the error and no credits; v3-shaped messages through
`_emit_message` and the tool-output store (fixtures from 53-02: MCP `arguments` nesting, `save_tool_output`); provider
hooks. genesis: `_skill_source` ignores `~/.kiro/skills` (tmp home with a same-named skill), still resolves
`playwright-appian` from the run checkout and `genesis-test-authoring` from the managed workspace, and refuses a
`SKILL.md` with invalid front matter from either source. The refusal test uses the 0.3.0 file's real line 3 (L-083:
real value shapes) and checks that the node fails before any turn with the remedy text;
`tests/test_workflow_skill_provisioning.py` (asserts the fallback today, `:4`, `:41`) rewritten to the managed-only rule.
genesis-workflows: `story-implementation` tests with the skill resolvable from the library fixture; the Phase 51
workflows' tests (`story-verification`, `action-capture`, `setup-composer`) still green through the provider hooks;
`validate_skills` green. Before starting, rebase on current master and re-diff genesis-workflows: Phase 51's
live-acceptance patches (v0.81.x) may have changed those three workflows (53-01 §9.3 item 8).

## As built (2026-11-11, genesis-dev) — review SHIP (round 2)

**Task restated.** Move `kiro_node` to the v3 SDK (the run's own `KIRO_HOME`, D9's `TrustPolicy`, an explicit
`auto_approve`, a fixed node prompt, `mcp_failed` before the prompt, unchanged event shapes, the worker's environment
plus `KIRO_HOME`); switch the SDK's public names to v3 with `Legacy*` aliases for chat; make workflow skills
managed-only with a front-matter check (D8, D14 part 3); let the skill store accept any folder (D17); publish `appian`
to genesis-workflows; fix playwright-appian's skill as 0.3.1 (D14 parts 1–2); re-run W1; run real nodes live. Rules
applied: ADR-011, -012, -019 (`kiro_node` signature and `CORE_MAJOR` unchanged; `SkillSourceError` is an additive
export), -020, -021, -022, -029, -032, -051, -066, -069, -083; L-002, -005, -016, -021, -023, -024, -042, -064, -083,
-089, -092, -094, -101, -112. KiroCrew read as a reference only: `src/kiro_crew/acp/kas_agents.py` (the custom agent's
`prompt` must be inline text, which 53-05's projection already enforces). **No ADR deviation.** One spec deviation,
decision 1 below.

### Commits (local, not pushed)

- genesis (base `466d51a`): `0c0a4aa` feat(core,sdk,53-06) — everything below; `d5a6a4e` fix(core,53-06) — review m1.
- genesis-workflows (base `6a7d432`, re-diffed first: no Phase 51 v0.25.x patch exists after v0.25.0): `b097719`.
- playwright-appian (base `02c65b7`, the user's own `.gitignore` commit, left as it is): `38f87fd` release: 0.3.1
  (local, not published).

### Changed

genesis — `packages/kiro-agent-sdk`:
- `__init__.py`: `KiroACPClient` / `KiroAgentOptions` / `query` / `collect*` are the v3 client (`_v3client`);
  `LegacyKiroACPClient` / `LegacyKiroAgentOptions` = the v2 `client.py` (chat only, until 53-07). `query()` checks MCP
  readiness after `start()`: when a server the caller sent is not `connected` (`failed`, or still `connecting` when
  the readiness wait ended), no prompt is sent and the `ResultMessage` is `error_code="mcp_failed"`, the failed servers
  named, `stop_reason="error"`, `credits: None`, `provenance: "unavailable"`. `_v3client.py` docstring only.

genesis — `packages/genesis-core`:
- `nodes/agent.py`:
  - `KIRO_HOME = <run>/_kiro` (created; shared by the run's turns); `env` left to the SDK default (the worker's
    environment plus `KIRO_HOME`).
  - `NODE_BUILTINS` (D9's seven), `NODE_AGENT_ID = "genesis-node"`, `NODE_AGENT_PROMPT` (a narrow workflow step; save
    large tool output with `save_tool_output`, L-021).
  - `_node_mcp_trust` (replaces `_compute_effective_trust`, decision 1) + `_trust_policy` → `TrustPolicy(builtins,
    mcp_tools, auto_approve=all of them, mode="auto_approve")`, a plain dict when the SDK is absent.
  - `_tool_name`: MCP `@server/tool` → the tool name (as on v2), built-ins keep the registered id (D19).
    `save_tool_output` counts only from the blackboard server (or a server-less stub). `agent.result` adds `model` and
    `fallback_from` when the SDK reports them. `agent.prompt.tools` is now the MCP entry list (never `"all"`; n4).
  - `_is_engine_step` (review m1): the v3 engine's own steps (`_meta.kiro.toolId` in the meta tools, or the tool-load
    input `{tool_ids}`) are not recorded in the tool-output store.
  - `SkillSourceError(problem, remedy)`; `_provision_skills` turns it into "skill '<id>' (declared by node '<node>')
    has <problem>. <remedy>"; a missing skill says "… is not installed — install it in Settings → Catalog → Skills.".
- `workspace.py`: `KIRO_HOME_DIR = "_kiro"`; `manifest()` (the run's artifact listing) skips it; the folder stays.
- `__init__.py`: exports `SkillSourceError`.

genesis — app:
- `chat/manager.py`: the two lazy imports use `LegacyKiroACPClient` / `LegacyKiroAgentOptions`.
- `runtime/context.py` `_skill_source`: the managed workspace, or for `playwright-appian` only the run checkout; no
  `~/.kiro/skills`. It runs `parse_skill_md` + `validate(expected_id=<id>)` on the resolved `SKILL.md` and raises
  `SkillSourceError("invalid front matter: <error, one line>", <remedy>)`: "Update testing runtime on the application's
  Testing → Setup." for `playwright-appian`, "Update or reinstall it in Settings → Catalog → Skills." otherwise.
- `skills/store.py`: the `scripts/`/`references/`/`assets/` rule is gone (D17). Refused: absolute paths, `..`, a
  backslash, any dot segment, a bundled `SKILL.md`; caps kept. Docstrings in `store.py` and `model.py` updated.

genesis — spike (outside the import gates): `scripts/spikes/53-06/{w1_rerun.py, live_node.py, evidence/*}`,
`scripts/spikes/53-02/evidence/w1-rerun-031.*`.

genesis-workflows: `skills/appian/` (66 files copied with `cp -Rp` from `~/.kiro/skills/appian`; `diff -r` differs only at
`references/documentation-lookup-strategy.md:191`, now `cat registry/components-registry.json | jq …`; the personal
copy untouched); `skills-registry.json` entry `appian` 1.0.0; `workflows/story-implementation/tests/test_library_skills.py`.

playwright-appian (0.3.1, D-115): `SKILL.md` description as a `>-` block; the setup check says "If the two versions
differ, stop and report the version mismatch to the user. Never run a bare `npx apwt` …"; `src/cli/skills.ts`
`parseSkill` reads a folded value and `renderSkill` keeps the source front matter (the old code re-wrote
`description:` as a plain value, which would have made every `install --skills` file invalid YAML again; found by the
existing `help-standards` tests); `tests/skills/skill.test.ts` parses the front matter with `js-yaml` 4.1.1 (new exact
devDependency, with `@types/js-yaml` 4.0.9), proves the 0.3.0 line is rejected, and checks no bare `npx apwt` in code
blocks; `package.json`, `package-lock.json`, `src/core/version.ts`, README tarball URL → 0.3.1; CHANGELOG 0.3.1;
DECISIONS D-115; TRACKER handoff and log; BIBLE skill rule.

### Tests

- SDK: `test_public_surface.py` pins the 53-06 set (`test_public_names_point_at_the_v3_client_from_53_06`);
  `test_v3_replay.py`: `test_top_level_collect_runs_on_the_v3_client` without the patch, and
  `test_query_ends_before_the_prompt_when_a_sent_server_is_not_connected` × 2 (fixtures `mcp-status-startup`, three
  failed servers, and `mcp-status-timeout`; no `session/prompt` on the wire, also through `collect`). The v2 tests import
  the Legacy options. **321 passed**, ruff clean.
- genesis-core: `test_core_units.py::test_kiro_node_builds_real_options` rewritten to the TrustPolicy shape (Phase 51
  shape → `@blackboard`; no tool list → allowlists or whole server; a tool list capped; `blackboard=False`, `mcp=[]` →
  built-ins only; `kiro_home`, `env None`, agent id and prompt; manifest hides `_kiro`). `test_integrations.py::
  TestNodeMcpTrust` (12, incl. the namespace regression and per-server caps). New `test_core_agent_v3.py` (5): real v3
  messages from the 53-02 recording `shell-auto-approve` via the SDK's `translate` (event key sets, names, `artifact.saved`
  from `raw_input["document"]`, exactly two `execute_bash` outputs), a look-alike `save_tool_output` on another server,
  `mcp_failed` → `ok: False`, no credits, and `model` / `fallback_from` with telemetry keys unchanged; a skill load not
  recorded. `test_agent_skills.py`: the new text and a `SkillSourceError` failing the node before the provider is
  called. The m1 tests fail with the fix reverted (2 failed). **109 passed**, ruff `genesis_core` clean.
- genesis: `test_workflow_skill_provisioning.py` rewritten (10): managed resolves, `~/.kiro/skills` ignored (tmp home with
  same-named skills), `playwright-appian` from the checkout only, the shipped 0.3.0 front matter verbatim (L-083)
  refused with the remedy, four invalid managed shapes refused, and two `kiro_node` runs failing before any turn.
  `test_skills_store.py`: any folder installs; 9 unsafe paths and both caps refused. `test_skill_install.py`: an
  `appian`-shaped library fixture with `registry/` installs through `install_selection` and `_skill_source` finds it.
  `test_testexec_recording.py`: its stub `SKILL.md` given a real front matter. **1863 passed + 1** (the edited test,
  deselected in the full run and passed alone; the reviewer's full run: 1864), ruff clean.
- genesis-workflows: `validate_library` 18, `validate_skills` **5**, pytest **432** (428 + 4: `appian` and
  `appian-object-generation` installed from this checkout and provisioned into a run; the not-installed remedy).
- playwright-appian: lint, typecheck, build clean; `npm test` **1402 passed** (95 files).
- **Scan** (throwaway, not committed): every `kiro_node` of the 15 workflows built with the real `mcp-registry.json`: no node loses
  a server, every policy projects (story-implementation `implement`: 105 MCP entries).
- **Live, kiro-cli 2.37.1** (isolated state and artifacts dirs under `/tmp`; the fleet's DB and runs untouched):
  - W1 re-run **PASS** (recorded in 53-02's As built): 0.20 credits.
  - `hello-appian` `make_result` through `build_context` and its standalone `graph.py` (in process, not the worker):
    ok, `result.json` valid, cursor `finish`; tool calls `list_directory`, `execute_bash` ×2, `fs_write` (registered ids);
    **0.341 credits, metered**, 16.2 s; `_kiro/` holds `logs`, `sessions`, `session-index`, `settings`, … and the
    manifest lists none of it. `model` / `fallback_from` absent: the engine sent no fallback frame.
  - A Phase 51-shaped probe node (no `mcp`, no `tools`, blackboard on; `agent.prompt.tools = ["@blackboard"]`):
    `execute_bash`, then `list_tool_outputs` and `save_tool_output` under the whole-server `@blackboard` entry, saved by
    reference (`probe/shell.txt` = the shell output). **0.231 credits**. Run again with the SDK frame log: **0
    `session/request_permission`, 0 `_session/steer`** → the built-in `match ["**"]` rules and the `blackboard/*` rule
    approve engine-side, and a whole-server `@blackboard` tool is called (53-05's two open questions, 53-11 A9a);
    0.368 credits. Evidence `scripts/spikes/53-06/evidence/live-node{,-frames}.json`.
  - **No real Phase 51 workflow node was run.** QA answered (HTTP 200), but on this build every Phase 51 browser
    workflow fails at its first agent node (m2): the resolver refuses the real 0.3.0 skill in an existing export
    (`~/Genesis/runs/action-capture/r-0ac738fb746d`: "has invalid front matter: … line 2, column 112 … Update testing
    runtime …"), and Update testing runtime still installs the vendored 0.3.0. That run needs 53-12's re-vendor.
  - Live credits this sub-spec: 1.14 (0.20 + 0.341 + 0.231 + 0.368).
- **Not run:** the `python:3.13` CI image (L-112); a run through the subprocess worker; chat live on the `Legacy*`
  aliases; story-implementation with the library `appian` against Dev (and whether the agent's shell finds
  `registry/components-registry.json`, relative to the skill folder while the cwd is the run root).

### Review

`reviews/53-06-review.md`: round 1 **SHIP** at `0c0a4aa` / `b097719` / `38f87fd` (m1, m2, n1–n4); m1 fixed in `d5a6a4e`
(it also covered skill loads, which would have stored the whole `SKILL.md`); round 2 **SHIP** (n5–n7). Left: m2 (53-12
step 0, with a guard test); n1 (the YAML error counts lines within the front-matter block: "line 2" for file line 3); n2
(an unreadable `SKILL.md` reads as "invalid front matter"); n3 (`SKILL.md:100,110` bare `npx playwright test`, backlog);
n4 (above); n5 (no test pins that an MCP output is still recorded; the reviewer's `mcp-allow` probe shows it is); n6
(the skill-load test's frames are simplified from the recording, not verbatim); n7 (an empty engine-step id would skip
id-less updates; none recorded).

### Decisions / deviations

1. **Spec deviation — `_node_mcp_trust` replaces `_compute_effective_trust`** (§2 names the old function). It compared
   node tools in `@server/tool` form (`KB_RO`, `DEV_RO`) with bare allowlist names and returned `[]` for every allowlisted
   server; v2 hid it by approving everything. Passed through as specified, every grounding node would have lost its MCP
   tools on v3. Same ADR-029 rule, per server: a node with a tool list gets none of a server it lists no tool of; an
   allowlist caps only its own server; `@blackboard` for a node without a tool list, its three tools with one.
2. `mcp_failed` lives in the SDK's one-shot `query()`, because `kiro_node` only sees `collect_streaming`'s result;
   chat (53-07) uses the client and decides itself. A server still `connecting` after the wait counts as failed.
3. The event `name` of an MCP tool stays the bare tool name (as v2), so the store, the blackboard index and the web are
   unchanged.
4. Store: dot segments are refused at any depth (before, only the top-level folder rule refused them), and a bundled
   `SKILL.md` is refused (it would have overwritten the validated one); the installer already removes it.
5. playwright-appian: js-yaml **4.1.1** (5.x exists; the KAS bundle's js-yaml version could not be read, its message
   matches 4.x). The `install --skills` re-serialization fix was needed for the `>-` block and is in the same commit.
6. The live node runs used `build_context` in process with an in-memory checkpointer, because starting an isolated
   server from this agent shell was refused; the node, SDK and kiro-cli code are the real ones.

### Lesson candidates

- **A trust set computed for a permissive client can be wrong without anyone noticing:** v2 approved every call, so a
  cap that intersected two name forms (`@server/tool` against bare names) produced `[]` for years. When a value moves
  from advisory to enforced, test it with the real registry and real node lists before the switch (extends L-094).
- **Fixing a file format in one place can break a writer elsewhere:** playwright-appian's `install --skills`
  re-serialized the front matter it parsed, which would have turned the fixed `>-` block back into the invalid plain
  value. When a format is tightened, list every reader and writer of it (L-094).
- **Batching an edit with the check that proves it** (L-089, recurred): a `diff -r` and the line-191 edit ran in the same
  message; the result happened to be correct but proved nothing at the time.

### Code-map changes

- `kiro_agent_sdk/__init__.py`: public names = v3; `LegacyKiroACPClient` / `LegacyKiroAgentOptions`; `query()` MCP
  readiness check (`_unready_servers`).
- `genesis_core/nodes/agent.py`: `NODE_BUILTINS`, `NODE_AGENT_ID`, `NODE_AGENT_PROMPT`, `SkillSourceError`,
  `_node_mcp_trust` (was `_compute_effective_trust`), `_trust_policy`, `_tool_name`, `_is_engine_step`.
  `genesis_core/workspace.py`: `KIRO_HOME_DIR`, manifest hides it.
- `genesis/runtime/context.py` `_skill_source`: managed + checkout only, front-matter check. `genesis/skills/store.py`:
  any bundle folder.
- genesis-workflows: `skills/appian/` (library skill, 1.0.0). playwright-appian: 0.3.1, D-115, `src/cli/skills.ts`
  folded-value parse.
- Spike: `genesis/scripts/spikes/53-06/` (W1 re-run, live node probe).

### Changes for 53-07..53-12

- **53-07 (chat):** chat imports `LegacyKiroACPClient` / `LegacyKiroAgentOptions` (`chat/manager.py:55,60`); switching
  to v3 means those two lines plus the options. `query()` now stops one-shot turns on `mcp_failed`; chat uses the client
  and reads `mcp_status` itself. The v2 tests importing `LegacyKiroAgentOptions` (`test_acp_extensions.py`,
  `test_fs_write_sandbox.py`, `test_permission_ask.py`, `test_permission_policy.py`, `test_transport.py`) go with
  `client.py`.
- **53-08 (readiness/skills):** `SkillInfo.shadows_personal` and its UI are still there (D7 removes them). The managed
  workspace now needs `appian` installed from the library for `story-implementation`; a run without it fails with the
  Catalog remedy. Consider (backlog) installing a workflow's declared library skills at `genesis install`.
- **53-11 (acceptance):** A9a answered by the live probe: a whole-server `@blackboard` tool was called, and with D9's
  policy no permission request reached the client (built-in `["**"]` rules approve engine-side). Still to run live: a
  Phase 51 node on QA (after 53-12 step 0), story-implementation with the library `appian` on Dev (check the agent's shell finds
  `registry/components-registry.json` from the run root), a node through the subprocess worker, and the first fallback
  frame for `model` / `fallback_from`.
- **53-12 (release):** **step 0 first:** publish playwright-appian 0.3.1 from `38f87fd` (its `.gitignore` commit
  `02c65b7` goes with it), re-vendor the published tarball byte for byte (`genesis/testexec/vendor/`,
  `VENDORED_APWT_VERSION`), and add the m2 guard test (extract the vendored `SKILL.md`, run `parse_skill_md` +
  `validate(expected_id="playwright-appian")`). Until then every Phase 51 browser workflow fails at its first agent
  node with the remedy text. Then each app runs Update testing runtime. genesis-workflows' new test installs
  `appian` with `registry/`, which only genesis ≥ this build accepts, so its CI needs the new genesis pin (L-057).
  Run the three Python suites once in `python:3.13` (L-112). ADR-086 must record D6's run `KIRO_HOME`, which ADR-069's
  rejected alternative (c) contradicts (review round 1, ADR-069 line).
- **Backlog:** n1, n2, n3 (bare `npx playwright test` in the skill), n5–n7; the date-dependent
  `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` (53-04) passed in these runs.

## Context manifest

```toml
areas    = ["core-engine", "workflows-library", "sdk-acp", "runs-worker"]
adrs     = ["ADR-011", "ADR-012", "ADR-019", "ADR-021", "ADR-022", "ADR-029", "ADR-032", "ADR-051", "ADR-066", "ADR-067", "ADR-069", "ADR-010", "ADR-018", "ADR-083"]
lessons  = ["L-002", "L-005", "L-016", "L-020", "L-021", "L-023", "L-024", "L-026", "L-042", "L-064", "L-092", "L-101", "L-112"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/packages/genesis-core/genesis_core/agents/**", "genesis/packages/genesis-core/tests/**", "genesis/genesis/runtime/context.py", "genesis/genesis/chat/manager.py", "genesis/genesis/skills/model.py", "genesis/genesis/skills/store.py", "genesis/genesis/dist/skill_install.py", "genesis/tests/test_workflow_skill_provisioning.py", "genesis-workflows/skills/**", "genesis-workflows/workflows/story-implementation/**", "playwright-appian/skills/**", "playwright-appian/tests/skills/**"]
upstream = ["53-04", "53-05"]
```
