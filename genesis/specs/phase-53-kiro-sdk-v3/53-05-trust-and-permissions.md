# 53-05 — Trust and permissions: agent projection, tool ids, permission ladder

> **Status:** BUILT 2026-11-11 (genesis 57a18f9 + 466d51a, review SHIP). Repo: **genesis** (`packages/kiro-agent-sdk`). Parent:
> `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D3 (#7, #8, #11, #14), D6, D9, D18, D19; F2, F5, F8, F9, F11. Uses 53-02 W3,
> W4, W12, W15, W18.

## 1. Goal

Turn a Genesis trust decision into a v3 custom agent the engine enforces, and answer every permission request through
one ladder that cannot widen it. This is where ADR-031's fail-closed chat and ADR-029's cap live on v3.

## 2. `TrustPolicy` (public)

```python
@dataclass(frozen=True)
class TrustPolicy:
    builtins: tuple[str, ...]          # Genesis names: "shell", "fs_read", "fs_write", "grep", "glob", "web_fetch", "web_search"
    mcp_tools: tuple[str, ...]         # "@server/tool" or "@server" (whole server), servers from session/new.mcpServers
    auto_approve: tuple[str, ...]      # the subset approved without asking (names as above)
    mode: str                          # "auto_deny" | "ask" | "auto_approve" — the answer for everything else
```

Callers build it (53-06 for nodes from D9, 53-07 for chat from F2). It has no "all tools" value: `mcp_tools=("@srv",)`
means every tool of that server, and only servers the caller sent are reachable.

## 3. Projection (`agent_spec.py`, private)

`project(policy, *, agent_id, prompt) -> dict` builds one `customAgents` entry (KiroCrew `acp/kas_agents.py` as
reference):

- `id`: `agent_id`, renamed if it collides with an engine built-in mode id (`vibe`, `spec`, `quick-spec`, `bug-fix`,
  `plan`, `autonomous`, `semantic_reviewer` on 2.37.1, 53-02 W4; the fixture's `reserved_mode_ids` is the source); `prompt`: inline text (never a `file://`); `description`.
- `tools`: **always explicit** (absent = no tools): each built-in name expanded through the tool-id fixture (§4) to its
  v3 registered ids (`fs_read` → `read_file`, `list_directory`; `fs_write` → `fs_write`, `str_replace`, `fs_append`;
  `shell` → `execute_bash`; `grep` → `grep_search`; `glob` → `file_search`; `web_search` → `remote_web_search`;
  `web_fetch` → `web_fetch`) + each MCP entry as `@server/tool` or `@server`. `delete_file` is never projected (D9).
- `permissions.rules`: one `{capability: "mcp", match: [...], effect: "allow"}` for the MCP entries in `auto_approve`
  (`@srv` → `srv/*`, `@srv/tool` → `srv/tool`; a glob or empty server name is refused, never widened); one `allow` per
  built-in capability in `auto_approve` (`shell`, `fs_read`, `fs_write`, `web_fetch`, `web_search`); capabilities come
  only from this fixed list, because the engine accepts a misspelt capability silently and the rule then never matches
  (53-02 W15); never the meta
  capabilities `all`, `builtin`, `filesystem`; nothing else, so every other request reaches the client as `ask`.
  Listing a capability never adds a tool: `delete_file` asks under `fs_write`, but it is absent from `tools`, so the
  model cannot call it. **`fs_read` path scope: none in this phase (D16).** The built-in allow rules use
  `match: ["**"]`, so reads reach any path the user can, as today. Confinement is Phase 52's; 53-02 W15's path-rule
  findings are its input.
- `includeMcpJson: false`, `includePowers: false` (explicit; D6 already hides the user's files).
- Limits: ≤ 64 patterns per rule (split), ≤ 50 agents (one per session here).

## 4. Tool-id fixture (`tool_ids.json`, package data) (D3 #11, F5)

Built from 53-02's `tests/fixtures/v3/tool-ids.json` (kiro-cli 2.37.1, KAS 0.66.70; the W15 table in 53-02's As built):
per built-in its registered id, permission `toolId`, `consent.capability`, `kind` and `toolCallId` prefix. For
example, the shell is listed as `execute_bash` but asks as `run_command`; `remote_web_search` asks as itself with kind
`other` and capability `web_search`. Also the meta tools, the rule capabilities and effects, and the reserved mode ids.
Shape:
`{kiro_cli_verified: ["2.37.1", …], builtins: {genesis_name: {registered: [...], permission_tool_id: [...],
capability}}, meta_tools: ["tool_load", "tool_call", "disclose_context"], reserved_mode_ids: [...]}`. MCP tools ask as
`mcp_<server>_<tool>`; identity still comes from `mcpTool.identity`.
`tool_ids.verified(version) -> bool`; `kiro_agent_sdk.check_kiro()` (used by preflight, 53-08) returns
`{installed, version, engine_v3, minimum_ok, verified}`. A start on an unverified newer version logs one warning per
version per process.

## 5. Permission ladder (`permissions.py`, private)

For each `session/request_permission`, answered exactly once:

1. **Identity** from the engine's `_meta.kiro`: `toolId` (built-ins, mapped back to the Genesis name by the fixture's
   **permission** id, which can differ from the listed id: the shell is listed as `execute_bash` but asks as
   `run_command`, with `consent.capability: "shell"`, 53-02 W3), `mcpTool.identity {serverName, toolName}` (MCP). Never
   from `toolCall.title` (the model can influence it). No readable identity → **deny**. The request itself carries no
   `kind`; `raw_input` and `kind` come from the `tool_call` with the same `toolCallId`, which arrives 15–55 ms earlier.
2. **Backstop:** the identity must be in the policy's `builtins` or `mcp_tools`; else **deny** (the engine should not have
   asked; this catches a projection bug or an engine change). **One exception, skill loads (D18):** a request whose
   `_meta.kiro.toolId` is `disclose_context` **and** whose `consent.capability` is `skill` is approved in every mode,
   never by its title. Under D6–D8 the engine can offer only skills Genesis provisioned. No skill rule is projected
   and `TrustPolicy` has no skills field. Bypass corpus: a `Load skill:` title with another `toolId`, `capability:
   skill` with another `toolId`, and `disclose_context` with another capability are all denied.
3. **Answer by mode:** in `auto_approve` → the `allow_once` option; `auto_deny` → the `reject_once` option; `ask` → the
   caller's `on_permission(PermissionRequest)` (shape unchanged, F1; `tool_name` = `@server/tool` or the Genesis built-in
   name; `raw_input` from the correlated `tool_call` by `toolCallId`), fail closed on timeout / error / unknown option
   (as today, `client.py:460-485`).
4. **Refusal notice** (D3 #8, F11): on a Genesis deny, before answering, send a fixed, cause-specific message into the
   turn with `_session/steer` (53-02 W7; text only, delivered after the running tool call ends), e.g. read-only chat "This chat is read-only; <tool> is not available here.",
   outside policy "<tool> is not available to this step." Text is static per cause, never built from tool arguments.
   Prefer the clean `reject_once` option (the turn continues) over `cancelled` (ends the turn), as KiroCrew records.
- `fs/write_text_file` keeps its own gate (`allow_fs_write`, `fs_write_root`; L-041): two independent checks. 53-02 P9
  showed v3 still writes through the client.

## 6. Elicitation (D3 #7, F8)

The engine's request is `_kiro/mcp/elicitation {sessionId, toolCallId, elicitation: {mode: "form", message,
requestedSchema}}` (53-02 W18; not `elicitation/create`). It is answered `{action: "decline"}` in every session (the
engine passes it to the server unchanged) with a notice on the turn
("<server> asked for input; Genesis does not support MCP input requests yet."). A chat form is backlog.

## 7. Access-token requests (D3 #14, F9)

With `auth_method="client"`, the engine sends `_kiro/auth/getAccessToken {}` right after start (53-02 W12). The SDK
calls `on_access_token()` and answers `{accessToken, expiresAt (ISO 8601), profileArn, authMethod, provider}`.
`profileArn` is required for an IdC/enterprise login: without it every model call fails (`ModelRegistryUnavailableError`).
The engine asks again when the token is within 180 s of expiry. The SDK never logs or stores the token or the ARN, and
it fails the request (classified `not_signed_in`) when the callback is missing or raises. With no answer at all,
`session/new` still succeeds and the first prompt fails "not signed in". Not used by Genesis in this phase (Phase 52
wires it, 52-01 D8). Tested with the `access-token` fixture.

## 8. Tests

Turn off the fake engine's `customAgents` skip (53-04 §1 item 5) so every replay checks the projected agent. The
recorded agents are bare spike agents, so the check is structural, not byte for byte (D19): every received agent
passes the W4 schema rules (`tools` a list of strings; rule `effect` in `allow|deny|ask|evaluate`) and the Genesis
rules (explicit `tools`, no `delete_file`, capabilities only from the fixed list, no globs, `includeMcpJson` and
`includePowers` false). Where a fixture recorded an agent, `id` and `prompt` match, every recorded tool and rule is
present, and extra keys come only from `description`, `permissions`, `includeMcpJson`, `includePowers`. **Live
schema probe (D19, no prompt, 0 credits):** send the projection of every 53-06/53-07 caller shape to the installed
kiro-cli and record that each activates (`availableModes` entry + `config_option_update`); record the frames as a
fixture. Projection golden tests (policy → entry) for every 53-06/53-07 caller shape, including the Phase 51 node shape (no `mcp`,
no `tools`, blackboard on: D9's built-ins + `@blackboard` only) and a `blackboard=False` node with `mcp=[]` (built-ins
only, no MCP); refusal of globs and meta capabilities;
reserved-id rename; ladder table tests (identity missing, outside policy, each mode, timeout, unknown option); fixture
replays `mcp-allow`, `mcp-ask-approve`, `mcp-ask-reject`, `shell-auto-approve`, `fs-write-client`, `elicitation`,
`access-token`; a `tool_load` of an unlisted tool is not approved (53-01 P5/C1–C2 shape).

## As built (2026-11-11, genesis-dev) — review SHIP (round 2)

**Task restated.** Inside `packages/kiro-agent-sdk` (public names stay on v2 until 53-06, 53-04 §1): the public
`TrustPolicy`; its projection into one `customAgents` entry (`agent_spec.py`); the tool-id table as package data with
`verified()` and a public `check_kiro()`; the permission ladder (`permissions.py`) replacing the 53-04
`permission_mode` stopgap; fixed refusal notices over `_session/steer`; the elicitation decline; the access-token
responder; `CHECK_CUSTOM_AGENTS` on. Two spec gaps were raised before the build and decided by the user (project-tracker
4d30829): **D18** (skill loads ask as `disclose_context` / capability `skill`, which the backstop would deny) and
**D19** (an exact `customAgents` match against bare spike agents is impossible; a structural check plus a zero-credit
live probe instead). Rules applied: ADR-004/020 (`includeMcpJson`/`includePowers` false, only the sent servers),
ADR-029 (`tools` always explicit, literal entries only), ADR-031/033 (fail closed; `ask` keeps the human confirm),
ADR-034 + L-041 (the `fs/write_text_file` gate stays independent), ADR-068 (no `delete_file`), ADR-083 (reads stay
unscoped, D16); L-011, L-017, L-045, L-088 (bypass + positive corpus, mutation-checked; a negative control in the live
probe), L-110, L-112. KiroCrew read as a reference only: `src/kiro_crew/acp/kas_permissions.py` (`_mcp_pattern`: a
glob or non-literal server is refused, never widened; `META_CAPABILITY_EXPANSION`: why `all`/`builtin`/`filesystem`
are never projected; `CAPABILITY_BY_TOOL`: `disclose_context` is the capability-`skill` tool),
`src/kiro_crew/acp/client_permissions.py` (`reject_tool`: prefer the `reject_once` option over `cancelled`, which ends
the turn). Not copied: KiroCrew grants skills through a listed tool plus a rule, which Genesis does not project (D18).
No ADR deviation.

### Commits (genesis, local, base 07b6d07, not pushed)

- `57a18f9` feat(sdk,53-05): trust and permissions — everything below.
- `466d51a` fix(sdk,53-05): review m1/n1/n2.

### Changed

`packages/kiro-agent-sdk/src/kiro_agent_sdk/`:
- **New** `agent_spec.py`: `TrustPolicy(builtins, mcp_tools, auto_approve, mode)` (frozen; default = nothing listed,
  `auto_deny`). It refuses an unknown built-in, a non-literal MCP entry (glob, `/` in a tool name, backslash,
  whitespace, empty server or tool), an `auto_approve` entry its lists do not cover, and an unknown mode.
  `project(policy, *, agent_id, prompt)` builds `{id, description, prompt, tools, includeMcpJson: false,
  includePowers: false[, permissions]}`:
  - `tools`: built-ins expanded through the table, then the MCP entries;
  - built-in allow rules (`match ["**"]`) only when **every** listed built-in of that capability is auto-approved;
  - one `mcp` rule (`srv/*` | `srv/tool`, collapsed, split at 64);
  - a reserved mode id is renamed `genesis-<id>`; a `file://` prompt is refused;
  - invariants raise even under `-O`.
- **New** `tool_ids.json` (package data; present in an isolated wheel build) and `tool_ids.py`: per Genesis built-in
  the registered and permission ids and the capability; per registered id the title, kind, permission id, capability
  and `toolCallId` prefix. Also `skill_load`, the rule capabilities, the meta capabilities, the effects and the
  reserved mode ids. Functions: `builtin_tool_name()` (by prefix, a unique kind, then kind + title), `verified()`,
  and `warn_if_unverified()` (once per version per process, called from `_launch`).
- **New** `permissions.py`, the ladder (§5):
  - `identify()` reads `_meta.kiro` only. An MCP identity also needs `consent.capability == "mcp"`; a built-in
    `toolId` is mapped by its permission id and needs its measured capability.
  - `decide()` applies D18, the backstop and the mode. It answers `allow_once` / `reject_once` only: an `*_always`
    choice becomes `*_once`, and with no once option it fails closed to `reject_once` or `cancelled`. `ask` fails
    closed on None, an unknown option, an error, a timeout or a missing callback.
  - Fixed `NOTICES` per cause: `no_identity`, `outside_policy`, `read_only` (for `auto_deny`), and `not_confirmed`
    (`ask` failing closed). No notice follows a person's own reject. The identity is inserted only when it matches
    `[A-Za-z0-9_./@-]{1,128}`, else "this tool". The elicitation notice uses the same rule for the server name.
- `_v3client.py`:
  - `trust: Optional[TrustPolicy]`; `permission_mode` removed. The constructor projects the policy (`_agent`), so a
    bad policy fails before a launch.
  - Activation uses the projected id. `policy` and `notices` (`{cause, text, messageId}`) are exposed.
  - Handlers for `_kiro/mcp/elicitation` (decline plus notice) and `_kiro/auth/getAccessToken`:
    - no callback → `-32601`;
    - a failing or bad callback → `-32000` "not signed in";
    - the answer is `{accessToken, expiresAt (ISO 8601; a datetime is converted), profileArn?, authMethod?,
      provider?}`, with the token and the ARN registered as FrameLog secrets, and a warning without values when
      `profileArn` is missing.
  - `_notice()` steers within `NOTICE_TIMEOUT_S` = 2 s, and a failure never blocks the answer. The stopgap is
    deleted.
- `launch.py`: `probe_engine_v3()` reads the `acp --help` possible values, cached on the binary's mtime and size.
  `check_kiro(kiro_cli_path=None, env=None)` returns `{installed, version, engine_v3, minimum_ok, verified}` and
  never raises.
- `session.py`: `Session.calls`, a `ToolIndex` filled in the read loop as `tool_call` / `tool_call_update` frames
  arrive (not replays), and reset per prompt.
- `updates.py`: `ToolIndex` records `kind` and `title`, and gains `get()`. A built-in's name is its registered id.
- `timeouts.py`: `NOTICE_TIMEOUT_S` = 2 s and `ACCESS_TOKEN_TIMEOUT_S` = 30 s.
- `__init__.py`: exports `TrustPolicy` and `check_kiro`.

`packages/kiro-agent-sdk/tests/`:
- `fake_engine.py`: `CHECK_CUSTOM_AGENTS = True` with the D19 check on every received agent, scripted or in the
  prelude:
  - `schema_problems`: the W4 drop rules;
  - `genesis_problems`: independent of the SDK, reading the 53-02 `tool-ids.json`;
  - `recorded_problems`: same `id` and `prompt`, every recorded tool and rule, extra keys only from the known four.
  - `FAKE_ENGINE_EXPECT_INVALID` names agents that are sent invalid on purpose and must fail the checks.
  - `check_w4_model` checks the fake's W4 model against every recorded `session/new` answer.
  - Unscripted `_session/steer` gets `{queued, messageId: <NOTICE_n>}`, logged as a `notice`, only in fixtures that
    script no steer of their own.
  - `acp --help` is supported, for `check_kiro`.
- New `test_v3_trust.py`; `test_v3_replay.py` and `test_public_surface.py` updated.
- New fixture `fixtures/v3/projection-probe.{jsonl,expected.json}` (29 pairs now).

`scripts/spikes/53-05/`: `probe_projection.py` (throwaway; reuses the 53-02 `acp.py` / `scrub.py`) and
`evidence/projection-probe.json(l)`.

### Tests

- **Live probe (D19), kiro-cli 2.37.1, 0 credits, no prompt:** the projections of six caller shapes all activate,
  each listed with origin `client` and confirmed by the `config_option_update` after `set_mode`, with no `kiro.log`
  drop. The shapes are read-only chat, copilot, a spec-style mode, a Phase 51 node (D9 built-ins + `@blackboard`), a
  node with a tool list, and a `blackboard=False` node with no MCP. They carry `description`, `includeMcpJson`,
  `includePowers` and the built-in `match ["**"]` rules for `shell` / `fs_write` / `web_*`. A control agent with
  `effect: "sometimes"` was dropped: not listed, `_kiro/customAgent/not_found`, exactly one `invalid_enum_value` in
  `kiro.log`. That shows the check is not vacuous. `test_projection_probe_every_caller_shape_activates` asserts
  that today's `project()` equals each agent the engine accepted, and replays all seven sessions.
- **`test_v3_trust.py` (131 tests):**
  - the package table pinned to the 53-02 measurement;
  - the shell listed as `execute_bash`, asking as `run_command`;
  - ToolCall names for every built-in;
  - one warning per unverified version;
  - 22 policy refusals;
  - projection goldens for the read-only, copilot, spec-mode, Phase 51 node, tool-list node, no-blackboard node and
    catalog shapes, plus invariants;
  - the per-capability rule rule;
  - collapse and the 64-pattern split;
  - every reserved id renamed; `file://` and blank ids refused;
  - the ladder table: identity missing (8 shapes), never from the title, the backstop (shell, `delete_file`,
    `fs_write`, an unlisted MCP tool, another server), each mode, `ask` (approve, reject, `*_always` downgrades, and
    5 fail-closed cases), no once option → `cancelled`;
  - a `tool_load`-ed unlisted tool refused in every mode;
  - D18: the positive corpus (the real `w1.jsonl` shape × 3 modes × 2 policies) and the **bypass corpus**, 13 cases
    × 3 modes (a `Load skill:` title with any other `toolId` or none; capability `skill` with another `toolId` or an
    MCP identity; `disclose_context` with `fs_read` / `shell` / `mcp` / no consent; `disclose_context` with an MCP
    identity), mutation-checked: an approve-by-title ladder fails 27 cases, an either-field ladder 30 (the reviewer's
    combined mutation: 39);
  - notices: unsafe identities never inserted, never built from tool arguments;
  - a failing or 60 s-hanging steer: the answer still goes out in under 1 s;
  - permission correlation from `Session.calls`; the session records a call on arrival;
  - elicitation names the server;
  - access token: no callback `-32601`; 5 bad callbacks `-32000` with the token never in a log or message; the answer
    shape and redaction; the missing-`profileArn` warning;
  - `check_kiro`: verified, newer, older, no v3, not installed.
- **`test_v3_replay.py` (37):**
  - `customAgents` checked in every replay (`assert_clean` requires a check per sent agent; a hand-widened agent
    with `delete_file` and an `all` rule is flagged);
  - `session-new-custom-agent` with the projected good agent and the spike's three bad agents expected invalid;
  - `mcp-allow` with its recorded policy, its `mcp` rule pinned (review m1);
  - `mcp-ask-approve` (`ask`);
  - `mcp-ask-reject` (`auto_deny`: `reject_once`, and the read-only notice steered before the answer);
  - `fs-write-client`, plus the `fs_write_root` gate still refusing after the ladder approved (L-041);
  - `shell-auto-approve` (the Phase 51 shape; names `execute_bash`), plus the backstop denying the same `run_command`
    asks under a policy without the shell, with the fixed notice;
  - `elicitation` (decline + notice);
  - `access-token` (the real responder, the token and the ARN never in the SDK log);
  - `unknown-request` (no callback → `-32601` × 8, prompt `not_signed_in`);
  - `projection-probe`.
- **Gates at 466d51a:**
  - SDK `../../.venv/bin/python -m pytest -q`: **319 passed** (183 at 07b6d07); `ruff check src tests` clean.
  - The five v3 test files with `PATH=/nonexistent`: 235 passed.
- **Gates at 57a18f9** (the delta touches only the SDK):
  - genesis-core `pytest -q` **98 passed**; `ruff check genesis_core` clean.
  - genesis `pytest -q` **1845 passed** (the date-dependent regression-job test passed today); `ruff check genesis`
    clean.
- **Not run:** the `python:3.13` image (L-112, 53-12 precondition).

### Review

`reviews/53-05-review.md`: round 1 **SHIP** at 57a18f9 with m1 (the `mcp-allow` replay ran under the empty policy,
so no replay covered the MCP allow-rule projection), n1 (`Decision.kind` had no reader) and n2 (a docstring said
"newer"). All three were fixed in `466d51a`, and round 2 was **SHIP** (the reviewer checked m1 against the W2
recording frame by frame). Carried as not checked: under `@server`, a tool call; built-in `**` rule matching; steer
latency while a permission request is pending; the engine's reaction to `-32000`; the CI image.

### Decisions / deviations

- **D18, D19** as recorded (project-tracker 4d30829). No ADR deviation.
- **Agreed defaults** (user, 2026-11-11):
  - access token: `-32601` / `-32000` as above;
  - notices for the four causes, never for a person's reject, identity charset as above, 2 s bound;
  - a capability rule only when every listed built-in of it is auto-approved (stricter than §3);
  - correlation recorded on arrival;
  - `ToolCall.name` for a built-in = its registered id (the "Tool Load" meta step keeps its title).
- **`*_always` → `*_once`:** a confirm card's "always" answer, or an engine offering only `*_always`, never persists
  an engine-side grant, because it would outlive the policy. With no once option the ladder answers `reject_once`,
  else `cancelled`.
- **Consent capability is part of the identity:** a built-in or MCP request whose `consent.capability` differs from
  the measured one (or is missing) is unidentified, so it is denied. This is fail-closed. If a future engine omits
  `consent`, every ask is denied until the table is re-measured (`warn_if_unverified` flags the version).
- **The `auto_deny` notice says "This session is read-only; …"** rather than "This chat …": the SDK does not know
  its caller. Outside the policy, it says "`<tool>` is not available to this agent."
- **`PermissionRequest` is unchanged (F1).** `kind` is read from the correlated call, logged with every deny and kept
  on `Decision` for 53-07.
- **The access-token answer omits empty optional keys.** Spec §7 lists all five keys; only `accessToken` and
  `expiresAt` are required, because a non-IdC login may have no `profileArn`. The missing-ARN case is logged.
- **The live probe uses probe MCP servers under the real server names**, plus the real blackboard server. It checks
  activation only; tool names are not resolved without a prompt.

### Lesson candidates

- **A recording made for a spike cannot pin a product shape byte for byte** (D19). Plan the check when the spike is
  specced: record agents in the product's shape, or pair a structural check with a zero-credit live probe that sends
  the real projection. Give the probe a negative control (an agent the engine must drop), so "all activated" means
  something (extends L-088's positive-control rule to probes).
- **A permission answer must never choose an `*_always` option on a caller's behalf.** The engine persists it, and it
  then outlives the policy that allowed one call (53-05 ladder).
- **Truncating a file at a grep'd line number cut the code just appended to it, and ruff did not flag the duplicated
  method block** that a re-append then left (caught by a source grep before commit). After any scripted edit, list
  the file's definitions (`grep -n "def "`) before running the gates.

### Code-map changes

`packages/kiro-agent-sdk/src/kiro_agent_sdk/`:
- new `agent_spec.py` (`TrustPolicy`, public; `project`);
- new `permissions.py` (the ladder, `NOTICES`);
- new `tool_ids.py` + `tool_ids.json` (the package-data tool-id table);
- `launch.py` adds `check_kiro` (public) and `probe_engine_v3`;
- `Session.calls`;
- `KiroACPClient.policy` / `.notices`;
- the `permission_mode` option is gone from the v3 options.

New public names: `TrustPolicy`, `check_kiro`. Tests: `tests/test_v3_trust.py`; `fake_engine.py` agent checks
(`schema_problems`, `genesis_problems`, `recorded_problems`, `FAKE_ENGINE_EXPECT_INVALID`); fixture
`projection-probe`. Spike harness `scripts/spikes/53-05/`.

### Changes for 53-06..53-07

- **53-06 (nodes):**
  - Build `TrustPolicy(builtins=D9, mcp_tools=<effective> (+ "@blackboard" or the blackboard tools),
    auto_approve=<all of them>, mode="auto_approve")` and pass it as `trust=`. `permission_mode` no longer exists on
    the v3 options.
  - Give `agent_prompt`. Pick an `agent_id` that is not a reserved mode id, or expect `genesis-<id>`.
  - Skill loads need nothing from the node (D18).
  - **First live node turn must show:**
    - a tool under a whole-server `@blackboard` entry actually called (only activation is proven);
    - whether the built-in `match ["**"]` rules match (if not, the engine asks and the ladder approves; only round
      trips are lost).
  - Built-in tool events now carry the registered id (`execute_bash`, `read_file`). The 53-06 events line was
    updated by the user.
  - `KiroACPClient.notices` lists any refusal the node met. Under D9 a refusal means a projection bug or an engine
    change, worth logging with the node.
- **53-07 (chat):**
  - Build the F2 policies: read-only = `auto_deny`; copilot = `ask` with `on_permission` = the confirm bridge
    (unchanged shape); spec-style modes add the `fs_read` / `fs_write` built-ins, auto-approved, with
    `fs_write_root` kept (L-041). The catalog client uses `TrustPolicy()`.
  - The bridge may return an "always" option id: it is answered as "once".
  - Refusal and elicitation notices are steered into the turn as user-side steering. Their texts are in
    `permissions.NOTICES` / `ELICITATION_NOTICE`, and `client.notices` carries their `messageId`s, so the transcript
    can label or hide them. **Measure live (53-11):** a notice landing at turn end may start a second, metered engine
    turn (53-02 W7b); `usage` sums it correctly, but the cost should be seen once.
  - `PermissionRequest.raw_input` now comes from the correlated call (the MCP `arguments`), so the confirm card shows
    real arguments.
- **53-08 (preflight):** `kiro_agent_sdk.check_kiro()` returns `{installed, version, engine_v3, minimum_ok,
  verified}`, never raises and spends nothing.
- **Phase 52 / backlog:** the engine's reaction to a `-32000` access-token answer is unmeasured (only `-32601` was,
  W12).

## Context manifest

```toml
areas    = ["sdk-acp", "security", "chat"]
adrs     = ["ADR-029", "ADR-031", "ADR-033", "ADR-034", "ADR-004", "ADR-020", "ADR-068", "ADR-083"]
lessons  = ["L-017", "L-041", "L-045", "L-088", "L-011"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**"]
upstream = ["53-02", "53-04"]
```
