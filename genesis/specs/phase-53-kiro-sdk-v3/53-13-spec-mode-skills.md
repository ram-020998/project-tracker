# 53-13 — Managed skills in the spec-style chat modes (agent `resources`)

> **Status:** BUILT 2026-11-13 (genesis 480bae9 + bf908ae; §2 probe PASS, no fallback; review SHIP). Repo: **genesis** (`packages/kiro-agent-sdk`, `genesis/chat/**`). Parent:
> `specs/phase-53-kiro-sdk-v3.md`. Decision: 53-01 D23 (Q18, option B). Runs after 53-08 and before 53-09.

## 1. Goal

The six spec-style chat modes (`feature_spec`, `ux_design`, `technical_design`, `feature_breakdown`, `story_design`,
`test_design`) see the managed skills, as read-only chat and copilot do. They run with cwd = the per-session
skill-output sandbox (`chat/manager.py:264`, L-041), and the engine discovers workspace skills only from
`<cwd>/.kiro/skills` (53-02 W1). Managed skills live in `state_dir/.kiro/skills`, so today these modes find none
(53-01 §10.5). The fix points the projected custom agent at the managed folder with the agent `resources` field
([kiro.dev/docs/skills](https://kiro.dev/docs/skills/): `"resources": ["skill://…/*/SKILL.md"]`). It makes no copies
and does not change the cwd.

## 2. Probe first (gate; about 0.2 credits)

`resources` in an ACP `customAgents` entry has never been sent to an engine. Probe it with the 53-02 harness on the
installed kiro-cli (2.37.1), under a private `KIRO_HOME`, with cwd = an empty sandbox folder:

| # | Check | Pass |
|---|---|---|
| R1 | A spec-style projection plus `resources: ["skill://<abs state_dir>/.kiro/skills/*/SKILL.md"]` (absolute path, no `~`) | the agent activates (D19 rule: `availableModes` entry + `config_option_update`; no `client.agent.drop.invalid` in `kiro.log`) |
| R2 | The engine's skill list | `_kiro/progressive_context/items_changed` lists every managed skill in that folder, and nothing else |
| R3 | One prompt that needs a managed skill | the skill loads through `disclose_context` (approved by the D18 ladder), its canary comes back, and the frames show the load, not a browse |
| R4 | A skill installed after the session started | listed after the next session start (the existing `reload_all_skill_clients` path) |

Record the frames as fixture `agent-resources-skills` (with the kiro-cli version line, scrubbed as 53-02 §4).

**If R1–R3 fail, fall back to option A (D23):** copy the managed skills into `<sandbox>/.kiro/skills/` at session
start. Re-copy on `reload_all_skill_clients`. Keep `.kiro/` out of everything that reads the sandbox as documents:
the milestone save, `_current_stage_html` (L-073) and the chat MD export. Record the failure and the fallback in the
As built.

## 3. SDK

- `KiroAgentOptions.skill_dirs: tuple[str, ...] = ()` (public, additive). Each entry must be an absolute, existing
  directory. The projection (`agent_spec.py`) adds `resources: ["skill://<dir>/*/SKILL.md", …]` and nothing else to
  `resources`. A relative path, a `~`, a glob or a `..` in a caller's entry is refused (`ValueError`), never widened.
- The fake engine's D19 structural check accepts `resources` as a known extra key. Its entries must be
  `skill://<absolute>/*/SKILL.md`.
- `test_public_surface.py` and the projection golden tests are updated.

## 4. Chat

- For a profile with `cwd_sandbox=True`, `_ensure_started` passes `skill_dirs=(str(settings.skills_dir),)`.
  Read-only chat and copilot run with cwd = `state_dir`, already see the managed skills through the cwd, and get no
  `resources`, so no skill is listed twice.
- `chat/manager.py`'s module docstring (`:11`) says how each mode reaches the managed skills.
- Workflow nodes are unchanged: they provision declared skills into `<run>/.kiro/skills/` (ADR-069).

## 5. ADR draft

`specs/phase-53-kiro-sdk-v3/adr-drafts.md`, ADR-086 item 6: managed skills reach a session through its cwd or, for a
session whose cwd is a sandbox, through the agent's `resources`; no copies (or the A fallback, if §2 fails).

## 6. Tests

- SDK: projection with and without `skill_dirs`; refusal of relative, `~`, glob and `..` entries; the
  `agent-resources-skills` replay.
- Chat: each of the eight `PROFILES` gets `skill_dirs` exactly when `cwd_sandbox` is set; a spec-mode session lists
  the managed skills (fake engine). If the A fallback was taken: copies are made and refreshed, and none reaches the
  milestone save or the MD export.
- Gates: SDK and genesis pytest + ruff.

## As built (2026-11-13, genesis-dev) — §2 probe PASS (R1–R4); review SHIP (m1/m2/n1 fixed after it)

**Task restated.** Probe first whether a `resources: ["skill://<abs>/*/SKILL.md"]` entry on the projected custom
agent makes the v3 engine list and load the managed skills for a session whose cwd is an empty sandbox (R1–R4, private
`KIRO_HOME`, fixture `agent-resources-skills`); it passed, so no copy fallback. Then: a public, additive
`KiroAgentOptions.skill_dirs` projected into `resources` (absolute existing directories only; relative, `~`, glob and
`..` refused), the fake engine's D19 check accepting `resources`, the public-surface pin; chat passes `skill_dirs` only
for profiles with `cwd_sandbox=True`; the docstrings and ADR-086 item 6 say how each session reaches the managed
skills. Rules applied: ADR-020 / ADR-086 item 2 (nothing from `~/.kiro`; the resource names only Genesis's folder),
ADR-031 (no tool, rule or trust added: `resources` changes what the engine lists, not what it may call), ADR-034 (skills
stay filesystem-provisioned in the managed workspace; `fs_write_root` unchanged), ADR-069 (workflow nodes untouched);
L-011 (fixture from real frames, re-checked against today's projection), L-024 (skills are files; nothing on the wire
but a path), L-041 (spec-style cwd stays the sandbox), L-073 (nothing new lands in the sandbox, so the milestone save
and `_current_stage_html` are unaffected), L-087 (probed the installed CLI first), L-088 (positive and bypass corpus
for the refusals and the fake's check; a no-`resources` control in the probe), L-094 (every doc that said "the chat cwd
is `state_dir`" updated), L-110 (mutation checks below, bytecode cleared).

KiroCrew read as a reference only: `src/kiro_crew/acp/kas_spec_carry.py` `projected_resources` (KAS takes string
`resources` as-is; `skill://` entries are carried, knowledge-base dicts checked), `src/kiro_crew/agent_discovery_parts/
spec_fields.py` `expand_skill_uri` (the three URI forms kiro-cli accepts: `skill://~/…`, `skill:///abs/…`,
`skill://<relative to cwd>`), `src/kiro_crew/acp/kas_skill_scope.py` (KAS loads the `resources` skills on top of the
default trees, and a fixed copy is added as `skill://<abs>`). Validated, not copied: Genesis sends only the absolute
form (the `~` form would point the engine at a home folder, and the relative form depends on the cwd), and adds no
`skill` deny rules (KiroCrew narrows a 45-skill catalog; Genesis's private `KIRO_HOME` already leaves only the managed
skills, R2). No ADR deviation.

### Probe (§2) — kiro-cli 2.37.1, private `KIRO_HOME`, 0.10 credits

`genesis/scripts/spikes/53-13/probe_resources.py` (reuses the 53-02 `acp.py` / `scrub.py`). The state folder is a copy
of `~/.genesis/.kiro/skills` (appian-object-generation, gam, genesis-test-authoring) under the run folder; cwd =
`<run>/skill-output/probe-session` (empty); the agent = `project()` of the spec-style policy (`fs_read`/`fs_write`
approved, `auto_deny`) + `resources`; permission requests answered by the SDK's own ladder.

| # | Result |
|---|---|
| R1 | **PASS.** Listed with origin `client`, `config_option_update` to `genesis-chat-feature-spec` after `set_mode`, no `_kiro/customAgent/not_found`, no `client.agent.drop.invalid` or `skill.frontmatter.invalid` in `kiro.log`. |
| R2 | **PASS.** `items_changed` listed exactly the three managed skills, scope `global`, `uri file://<RUN>/state/.kiro/skills/<id>/SKILL.md`, nothing else. **Control:** the same agent without `resources`, same cwd, listed no skill. |
| R3 | **PASS.** "Use the gam skill …": one `tool_call` "Load skill: gam" (`toolId disclose_context`, `rawInput {name: gam}`); the ladder approved it (`allow_once`, D18) under `auto_deny`; the canary came back; no read tool touched a skill folder. 0.1014 credits, metered. |
| R4 | **PASS.** A skill installed after the first process ended was listed in a new process after `session/load` of the same session (agent re-sent and active) and after a `session/new` — the `reload_all_skill_clients` path (close; the next turn loads). |
| Extra | An **empty** managed folder (a fresh install; chat creates it): the agent activates, no skill listed, no drop (0 credits, `agent-resources-empty`). |
| Nesting (review m1, n1) | **PASS**, no prompt, 0 credits (`--nesting`, `agent-resources-nesting`). The production layout: cwd = `<state>/skill-output/<id>`, a child of the folder whose `.kiro/skills` is the managed one. (a) With `resources`, each managed skill is listed **exactly once**. (b) Without it, **none**: the engine does not walk up from the cwd, so `resources` is needed and no skill is listed twice. (c) A skill folder whose path holds a space is listed through `resources`. |

Evidence: `scripts/spikes/53-13/evidence/agent-resources-{skills,empty,nesting}.json(l)` (scrubbed: no home path, user name or
token). Fixture: `packages/kiro-agent-sdk/tests/fixtures/v3/agent-resources-skills.{jsonl,expected.json}` (process 1's
`initialize` + the resources session; the control session cut out; kiro-cli version on line 1).

### Commits (genesis, local, base d2bdec5, not pushed)

- `480bae9` feat(sdk,chat,53-13): everything under Changed, the probe and its evidence.
- `bf908ae` fix(sdk,53-13): review m1/m2/n1 (the nesting probe and its evidence; the leading `//` refusal).
- project-tracker: this As built, the status line, ADR-086 item 6 in `adr-drafts.md`, `reviews/53-13-review.md`.

### Changed

genesis — `packages/kiro-agent-sdk`:
- `agent_spec.py`: `skill_resources(skill_dirs)` → `["skill://<dir>/*/SKILL.md", …]`; refuses (`ValueError`) a string
  instead of a sequence, a non-string or blank entry, `* ? [ ] { } ! \ ~` or a control character anywhere, a
  non-absolute path or one with a leading `//` (bf908ae, review m2), a `..` segment, a missing path or a file; normalises a trailing `/` and `.` segments; drops
  duplicates, keeps order. `project(…, skill_dirs=())` adds `resources` only when there is an entry (so every 53-05
  golden is unchanged). Module docstring.
- `client.py`: `KiroAgentOptions.skill_dirs: tuple[str, ...] = ()` (documented), passed to `project()` in the
  constructor, so a bad entry fails before any launch.

genesis — app:
- `chat/manager.py` `_build_options`: for `cwd_sandbox` profiles, `settings.skills_dir.mkdir(parents=True,
  exist_ok=True)` and `skill_dirs=(str(skills_dir),)`; other profiles `()`. Module docstring (the "Home and cwd"
  bullet) and `reload_skills` docstring.
- Docstrings only: `chat/mcp.py` (SKILLS note), `runtime/settings.py` (`skills_dir`, `chat_kiro_home`),
  `skills/__init__.py`.

### Tests

- SDK `tests/test_v3_trust.py` (+21): projection with `skill_dirs` = the spec-mode entry plus `resources` and nothing
  else, and without = no key; normalisation and dedupe; 18 refusals (relative, a leading `//` (bf908ae; fails without
  the fix), `./`, `~`, `~` inside, `*`, `?`, `[ ]`,
  `{ }`, `**`, backslash, `..` mid and end, newline, empty, blank, missing, a file), each also refused by the client's
  constructor; a string and a non-string refused, with the same folder as a string accepted; the client projects it.
- SDK `tests/test_v3_replay.py` (+13): `test_agent_resources_skills` — today's `project()` equals the agent the engine
  accepted; the recording's last skill list = the three managed skills; the replay on the real client passes the D19
  check with `resources`, the skill load is answered `accept` under `auto_deny` with no notice, the canary is in the
  reply, 0.1014 credits metered. `test_the_fake_engine_checks_resources` (12 cases: 2 accepted, 10 refused — relative,
  `~`, `..`, `**`, a glob segment, a single file, `file://`, a knowledge-base dict, empty, a string). The fixture count
  pin is 30, and `test_v3_fixtures.py` loads the new fixture (+1).
- SDK `tests/fake_engine.py`: `resources` a known extra key; `genesis_problems` accepts only
  `skill://<absolute>/*/SKILL.md`; `recorded_problems` compares a recorded agent's `resources`; the prelude sends the
  engine's skill list (`send_skill_list`: the cwd's `.kiro/skills` as `workspace` + the agent's `skill://` folders as
  `global`, as R2 and W1 recorded), logged as `skills_listed`.
- SDK `tests/test_public_surface.py`: `OPTION_FIELDS` gains `skill_dirs`; default `()`.
- genesis `tests/test_chat_manager.py`: every `PROFILES` entry gets `skill_dirs == (skills_dir,)` (and the folder
  exists, and the projection's `resources` is the one entry) exactly when `cwd_sandbox`, else `()` with cwd =
  `state_dir`.
- genesis `tests/test_chat_v3_engine.py` (+2): a `feature_spec` and a `read_only` session on the real SDK client over the
  fake engine, with two managed skills installed: each skill listed exactly once, from `skills_dir` (feature_spec:
  cwd = the sandbox, `resources` = the folder, scope `global`; read_only: cwd = `state_dir`, no `resources`, scope
  `workspace`).
- **Mutation checks** (`__pycache__` removed, `PYTHONDONTWRITEBYTECODE=1`): `project()` not adding `resources` → the
  replay's golden fails; the client not passing `skill_dirs` → the fake engine logs "resources differ from the recorded
  agent" and the replay fails; chat not setting `skill_dirs` → 7 failures (the six spec-style profiles and the
  feature_spec engine test).
- **Gates at 480bae9:** SDK `pytest -q` **300 passed** (266 before), `ruff check src tests` clean; genesis `pytest -q`
  **1915 passed** (1913 at d2bdec5), `ruff check genesis` clean (`ruff check tests` has 24 errors, all pre-existing at
  d2bdec5 and outside the gate); genesis-core `pytest -q` **109 passed**, ruff clean (no core change). The reviewer
  re-ran SDK and genesis pytest + ruff: same counts.
- **Gates at bf908ae** (SDK and spike only): SDK `pytest -q` **301 passed**, `ruff check src tests` and the spike clean;
  genesis chat tests (`test_chat_v3_engine`, `test_chat_manager`, `test_chat_mode_profile`) **59 passed**.
- **Not run:** a live chat turn through `ChatManager` in a spec-style mode (the probe used the SDK's projection and
  ladder on raw JSON-RPC, not the full chat stack: 53-11 can take it with its other live checks); the `python:3.13` CI
  image (L-112, 53-12); the web (nothing changed).

### Review

`reviews/53-13-review.md`: **SHIP** at 480bae9 (no blocker or major; the reviewer re-ran the gates, checked that all 71
fixture frames occur in order in the evidence, that the R2 control is not a timing artefact, and the scrubbing).
Findings and what was done:
- **m1** "no skill is listed twice" was shown on a layout production does not have (the probe's sandbox was not under
  the state folder): measured in bf908ae with the production nesting (Probe table, "Nesting"): once with `resources`,
  none without. The claim in `chat/manager.py` and ADR-086 item 6 stands.
- **m2** a leading `//` survived `normpath`: refused in bf908ae, in the corpus.
- **n1** a path with a space: measured, listed (Nesting case c).
- **n2** `docs/architecture/modules/chat-and-skills.md:421-427` (added in `7d7cd2d`, outside 53-13) now trails the code:
  a hand-off to genesis-docs (below).
- **n3** this section (filled).
Live acceptance: accepted by the reviewer as a 53-11 item (below). bf908ae was not re-reviewed: it only adds a probe
run, one refusal condition and one test case for findings the reviewer specified.

### Decisions / deviations

No ADR deviation.
1. **Option B as specced; the A fallback was not built** (R1–R3 passed). Nothing is copied into the sandbox, so the
   milestone save, `_current_stage_html` (L-073) and the chat MD export are untouched.
2. **The refusal set is wider than §3's list:** besides relative, `~`, globs and `..`, a backslash, `!`, a control
   character, a missing path and a file are refused, and a non-sequence is refused. `~` is refused anywhere in the
   path, not only as a prefix (the engine expands a leading `~`; a literal `~` elsewhere is legal on disk but Genesis
   never produces one).
3. **Chat creates `skills_dir`** before projecting it: `skill_dirs` requires an existing directory, and a fresh install
   may have none. An empty folder activates and lists nothing (probe "Extra").
4. **The fake engine now models the skill list** in its prelude (R2's shape) so a chat test can show which skills a
   session would see; the SDK and chat still do not read `items_changed` (unchanged; 53-01 §10.1 says it is the check
   for "did a skill load", which the probe used).
5. **Scope is `global`** for a `resources` skill and `workspace` for a cwd skill (measured). On a name clash between
   the two the engine's rule is unmeasured; no Genesis session sends both (§4), and the engine does not find the
   managed folder by walking up from a sandbox cwd (Nesting b), so it cannot arise.

### Lesson candidates

- **A spike harness should answer permission requests with the product's own ladder**, not a blanket approve: R3 then
  proves the product would approve the skill load (D18), not only that the engine can do it.
- **Give a "did it list X" probe a control that must list nothing** (the same agent without `resources`, same cwd):
  without it, R2 could have passed on skills found some other way (extends L-088 to probes).
- **Probe the production directory layout, not a convenient one** (review m1): the first probe put the sandbox beside
  the skills folder, which could not show whether the engine walks up from the cwd. Copy the real nesting
  (`state_dir/skill-output/<id>` under `state_dir/.kiro/skills`) when a claim depends on where the cwd sits.

### Code-map changes

- `packages/kiro-agent-sdk/src/kiro_agent_sdk/agent_spec.py`: `skill_resources()`; `project(…, skill_dirs=)`.
- `packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py`: `KiroAgentOptions.skill_dirs` (public, additive).
- `genesis/genesis/chat/manager.py` `_build_options`: `skill_dirs` for `cwd_sandbox` profiles.
- Tests: fixture `agent-resources-skills`; `fake_engine.send_skill_list`, `resources` in the D19 checks.
- Spike: `genesis/scripts/spikes/53-13/` (`probe_resources.py`, `--empty`, `--nesting`).

### Changes for 53-09..53-12

- **53-11 (acceptance):** the 53-08 hand-off "do the spec-style modes see managed skills at all" is answered on the
  wire (R1–R3, Nesting); the reviewer requires one live Feature Spec turn through `genesis serve` that names a managed
  skill, checking the `Load skill` tool call in the turn's events and that the session's skill list shows each managed
  skill once. R4 also answers 53-07's "a skill installed meanwhile is discovered after a `session/load`" on the raw
  wire.
- **genesis-docs (phase write-back):** `genesis/docs/architecture/modules/chat-and-skills.md:421-427` says the stage
  modes' cwd is not the managed folder and that Kiro reads `~/.kiro/skills`; both changed (D7 and this sub-spec).
- **53-12 (release):** release notes: `KiroAgentOptions.skill_dirs` (new, additive). On kiro-cli 3.x, re-run
  `probe_resources.py` with the W15 re-measure (the `resources` URI form and the skill list are engine behaviour).

## Context manifest

```toml
areas    = ["chat", "sdk-acp"]
adrs     = ["ADR-020", "ADR-031", "ADR-034", "ADR-069"]
lessons  = ["L-011", "L-024", "L-041", "L-073", "L-087"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md", "tracker:specs/phase-53-kiro-sdk-v3/53-05-trust-and-permissions.md", "tracker:specs/phase-53-kiro-sdk-v3/53-07-chat-backend.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**", "genesis/genesis/chat/manager.py", "genesis/genesis/chat/mode_profile.py", "genesis/tests/test_chat_manager.py", "genesis/scripts/spikes/53-02/**"]
upstream = ["53-05", "53-07", "53-08"]
```
