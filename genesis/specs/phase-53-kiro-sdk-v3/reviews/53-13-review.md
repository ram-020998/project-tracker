# Review 53-13 — base d2bdec5 (genesis-review, 2026-11-13)

What this change does: the six spec-style chat modes, whose cwd is the per-session skill-output sandbox, now reach the
managed skills (`state_dir/.kiro/skills`) through the projected custom agent's `resources`
(`skill://<skills_dir>/*/SKILL.md`), via a new additive SDK option `KiroAgentOptions.skill_dirs`. Read-only chat and
copilot are unchanged (cwd = `state_dir`, no `resources`). A §2 probe on kiro-cli 2.37.1 (R1–R4 PASS, 0.10 credits)
backs it, and its frames are the new fixture `agent-resources-skills`. Nothing is copied.

Reviewed: genesis `480bae9` (resolved; local master, not pushed), 19 files. The range `d2bdec5..480bae9` also holds
`7d7cd2d docs(architecture)` (33 files under `docs/architecture/`, docs only, describing v0.81.0); that commit is not
part of 53-13 and was not reviewed, which is why `genesis-ctx check` lists 52 files. project-tracker: the uncommitted
As built of 53-13 and ADR-086 item 6 in `adr-drafts.md` (diff read).

## Gates (re-run by the reviewer at 480bae9, clean tree)

- SDK `../../.venv/bin/python -m pytest -q`: **300 passed** (29 s). `ruff check src tests`: **All checks passed**.
- genesis `.venv/bin/python -m pytest -q -p no:warnings`: **1915 passed** (9 min 28 s). `ruff check genesis`: **All
  checks passed**.
- Web gates (lint, typecheck, vitest, build): N/A. No file under `web/` changed (`git show --stat 480bae9`).
- genesis-core: not re-run; no file under `packages/genesis-core` changed.

## Probe evidence and fixture (checked)

- `scripts/spikes/53-13/evidence/agent-resources-skills.json`: `result PASS`, R1–R4 each `pass: true`,
  `kiro_log_drops []`, credits 0.10136 (metered). R2 lists exactly `appian-object-generation`, `gam`,
  `genesis-test-authoring`, scope `global`, uris `file://<RUN>/state/.kiro/skills/<id>/SKILL.md`. R3: one load
  `Load skill: gam` (`toolId disclose_context`, `rawInput {name: gam}`), one ladder decision `approved, identity
  disclose_context, optionId accept`, `browse []`, canary in reply. R4: `after_load` and `after_new` both add
  `probe-late-skill`, `not_found_after_load []`. `agent-resources-empty.json`: PASS, 0 prompts, 0 credits, no skill.
- **The control is real, not a timing artefact.** In the evidence frames each resources session gets an empty
  `items_changed` and then the skill list 10–35 ms later (frames 33→40 at t 7.603→7.617; 157→164 at 6.861→6.880).
  The control session (frame 11, t 3.508) got only the empty one in its 4 s wait. So "the control listed none" means
  the engine found none, not that the probe stopped listening too early.
- **The fixture is real frames.** All 71 non-header frames of
  `packages/kiro-agent-sdk/tests/fixtures/v3/agent-resources-skills.jsonl` occur, in order, in the 166 `in`/`out`
  frames of the evidence file (reviewer script: `missing 0, in order True`). Line 1 carries `kiro-cli 2.37.1`; the
  evidence's line 1 does too. The recorded `session/new` carries `resources ["skill://<RUN>/state/.kiro/skills/*/SKILL.md"]`
  and cwd `<RUN>/skill-output/probe-session`.
- **Scrubbing.** `grep -i 'ramaswamy\|/Users/\|accessToken\|Bearer\|eyJ\|aoa…'` over the fixture pair and all four
  evidence files: no match. Session ids are `<SESSION_n>`, paths `<RUN>`.

## Checklist

ADRs (from `genesis-ctx check`):
- [N/A] ADR-001 — no control-flow change; chat options only.
- [OK] ADR-002 — agent turns still go through `kiro-agent-sdk` over ACP; `resources` rides in the same
  `_meta.kiro.customAgents` entry (`session.py:232,245`), no global `mcp.json`.
- [OK] ADR-004 — MCP injection unchanged (`manager.py` `mcp_servers=servers` untouched).
- [N/A] ADR-005 — registry untouched.
- [OK] ADR-010 — no bulk in state or chat; skills stay files, only a path is sent.
- [N/A] ADR-011 — no workflow agent node changed.
- [N/A] ADR-013 — no config UI.
- [OK] ADR-019 — the SDK change is additive (`skill_dirs` defaults to `()`, `test_public_surface.py`
  `KiroAgentOptions().skill_dirs == ()`); no `CORE_MAJOR` impact.
- [OK] ADR-020 — nothing in the user's `~/.kiro` is read or written. `~` is refused anywhere in an entry
  (`agent_spec.py` `_SKILL_DIR_REFUSED`); the only resource Genesis builds names `settings.skills_dir`
  (`manager.py:271-273`).
- [N/A] ADR-021, ADR-022 — no workflow, gate or artifact change.
- [N/A] ADR-026, ADR-027, ADR-028 — no bind, web or endpoint change.
- [OK] ADR-029 — tool trust unchanged; `resources` adds no tool, rule or allowlist entry
  (`test_projection_with_skill_dirs_adds_resources_and_nothing_else`: entry == plain + `resources`).
- [N/A] ADR-030 — no persistence change.
- [OK] ADR-031 — chat stays fail-closed: the spec-mode policy is unchanged and the skill load is approved by the
  existing D18 ladder under `auto_deny` (replay `test_agent_resources_skills`: one answer `accept`, no notice). No
  new write path; nothing lands in the sandbox.
- [OK] ADR-032 — the replay asserts metered credits `0.10136…`, provenance `metered`.
- [OK] ADR-033 — copilot gets `skill_dirs == ()` (`test_every_mode_gets_its_trust_policy_and_never_a_shell`, the
  `else` branch); its confirm bridge is untouched.
- [OK] ADR-034 — skills stay filesystem-provisioned in `~/.genesis/.kiro/skills`, invoked by the engine;
  `fs_write_root` unchanged (`manager.py:280`).
- [N/A] ADR-035, ADR-036, ADR-037, ADR-038, ADR-040, ADR-041, ADR-042, ADR-045, ADR-046, ADR-047, ADR-048, ADR-049,
  ADR-050, ADR-051, ADR-053, ADR-055, ADR-059, ADR-060, ADR-061, ADR-062, ADR-063, ADR-065, ADR-068, ADR-073,
  ADR-074, ADR-075, ADR-076, ADR-081, ADR-082, ADR-084, ADR-085 — none of their surfaces (run inputs, KB, MCP
  installs, CLI, documents, specs, IA, lifecycle, provider protocol, memory, design, stages, board, collaboration,
  Implementation lane, package tools, sync, cids, CRs, test code, QA, Verification, report origin) is touched.
- [OK] ADR-069 — workflow nodes unchanged; `genesis-core` has no `skill_dirs` caller (`grep -rn skill_dirs
  packages/genesis-core` empty), so run provisioning into `<run>/.kiro/skills/` is as before.
- [OK] ADR-077 — the agent system is untouched; the review used `genesis-ctx`.
- [OK] ADR-080 — one repo, no new internal dependency entry.
- [N/A] ADR-083 — no browser agent or shell trust change.

Lessons:
- [OK] L-001 — MCP env shape untouched.
- [N/A] L-002 — `kiro_node` not changed; it does not pass `skill_dirs` (default `()`).
- [N/A] L-007, L-012, L-018, L-019, L-021, L-023, L-028, L-029, L-031, L-046, L-047, L-048, L-049, L-053, L-054,
  L-058, L-061, L-064, L-069, L-070, L-081, L-086, L-093 — their surfaces (transcript, settings detail, SSE,
  secrets, MCP results, introspection, managed-native, deployment, slash commands, MD export, SPA, Hub, finalizers,
  turn size, web buttons, LCP URL, defaults, cids, run bridges) are untouched.
- [OK] L-011 — the fixture is the real frames (subset check above); `test_agent_resources_skills` asserts today's
  `project()` equals the agent the engine accepted, and `recorded_problems` now compares `resources`.
- [OK] L-016 — see ADR-032.
- [OK] L-017 — no allowlist change; `resources` is not a trust surface.
- [OK] L-024 — skills still load from the filesystem; only a folder path goes on the wire.
- [OK] L-025, L-027 — `ruff` is the pinned dev-venv binary; clean.
- [N/A] L-030 — no web change, no tag here.
- [OK] L-041 — spec-mode cwd stays the sandbox and `fs_write` stays trusted (`manager.py:269`; chat test asserts
  `opts.cwd == opts.fs_write_root`).
- [OK] L-042 — no bulk sent as chat content.
- [OK] L-044, L-087 — probed the installed CLI (2.37.1) before building, KiroCrew read as reference only.
- [OK] L-045 — read-only posture unchanged.
- [N/A] L-051, L-056, L-057, L-098, L-099, L-100, L-101, L-104 — no release, pin, install, version, CI-variable,
  npx or reaping work here.
- [OK] L-073 — no copy fallback, so nothing new lands in the sandbox; `_current_stage_html` and the milestone save
  are untouched (`git show --stat 480bae9`: no change outside the listed files).
- [OK] L-088 — refusals have a bypass corpus (17 cases in `test_skill_dirs_refuses_what_it_cannot_send_literally`,
  each also through the client constructor) and a positive corpus (normalisation/dedupe, the string-vs-sequence
  control); the fake's check has 2 accepted and 10 refused cases; the probe has a no-`resources` control.
- [OK] L-089 — the probe and gates are sequential; nothing batched with its verifier.
- [OK] L-092 — no new `tests/__init__.py`, no non-test `test*` symbol (the new helpers are `send_skill_list`,
  `skill_resources`).
- [N/A] L-105 — no Playwright report. The analogous scrub of the probe output was checked (above).
- [OK] L-111 — no live chat turn through `genesis serve`; the As built says so and hands it to 53-11 (see Live
  acceptance below).
- [OK] L-112 — not run in the `python:3.13` CI image; the As built says so and leaves it to 53-12. Nothing new
  assumes a tool the image lacks: the fixture replay uses the fake engine, and the probe is a spike, not a test.

Gates:
- [OK] SDK pytest (300 passed) — reviewer re-run.
- [OK] genesis pytest (1915 passed) — reviewer re-run (listed twice by the check, chat and config-secrets).
- [OK] `ruff check genesis` — clean.
- [OK] SDK `ruff check src tests` — clean.
- [N/A] web lint/typecheck/test, web build — no `web/` change.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **"No skill is listed twice" is proven on a layout production does not have** (`scripts/spikes/53-13/
  probe_resources.py:118-124`; claim in `chat/manager.py:13-14`, As built Decision 5, ADR-086 item 6). What: the
  probe puts the skills at `<run>/state/.kiro/skills` and the cwd at `<run>/skill-output/probe-session`, so no
  ancestor of the cwd holds a `.kiro/skills`. Problem: in Genesis the sandbox is `state_dir/skill-output/<id>`
  (`settings.py:128-132`), a child of `state_dir`, whose `.kiro/skills` is the managed folder. If the engine looks
  for workspace skills in ancestors of the cwd (kiro.log names the step `fs.resolveWorkspaceAgentRoots`, plural),
  a production spec-mode session lists each managed skill twice, as `workspace` and as `global`, and Decision 5's
  name-clash rule ("unmeasured … cannot arise") would apply. The evidence leans against a walk-up: the probe's cwd
  sits under `~` and `~/.kiro/skills` was not listed, and 53-02 W1 found no personal skill. But a walk-up that
  stops at `$HOME` or skips the home `.kiro` would pass both of those checks, and the fake engine models cwd only, so
  `test_a_chat_session_lists_the_managed_skills_once` cannot catch it. Fix: in 53-11 (or a re-run now, 0 credits,
  same as `--empty`), run the probe's no-prompt session with the real nesting (`<state>/skill-output/<id>` as cwd,
  skills at `<state>/.kiro/skills`), with and without `resources`, and record that each skill is listed once. If it
  is listed twice, the fix is to drop `resources` (the modes already see the skills) and correct 53-01 §10.5. If
  skipped: a duplicate skill list in every spec-style session, found only by a user.
- m2 **The SDK accepts a path the fake engine refuses** (`agent_spec.py` `skill_resources`, `os.path.normpath`).
  What: POSIX `normpath` keeps a leading `//` (`os.path.normpath('//a/b') == '//a/b'`, reviewer check), so
  `skill_dirs=("//a/b",)` projects `skill:////a/b/*/SKILL.md`. Problem: `fake_engine.genesis_problems` refuses
  any resource whose path holds `//`, so the two D19 models disagree on that input, and the engine's reading of
  `skill:////…` is unmeasured. Genesis never produces such a path (`state_dir` comes from `Path`), so this is not
  reachable today. Fix: refuse an entry that starts with `//` (one condition beside the `startswith("/")` check) and
  add it to the refusal corpus. If skipped: a future caller can send an unmeasured URI that no test models.

### Nits
- n1 **A path with a space is accepted but unmeasured** (`agent_spec.py` `_SKILL_DIR_REFUSED`). `GENESIS_STATE_DIR`
  may contain a space, and nothing shows whether the engine parses `skill:///Users/x/My Folder/…` as a literal
  path or a URL. The default `~/.genesis` has none, so this is optional: either note it in the 53-12 3.x re-measure
  or add one zero-credit probe case.
- n2 **The architecture docs added at `7d7cd2d` now trail the code.** `docs/architecture/modules/chat-and-skills.md`
  :421-427 says the stage modes' cwd "is therefore not the managed" folder and that Kiro reads `~/.kiro/skills`. That
  doc set describes v0.81.0 by design, so this is a hand-off for genesis-docs at the phase write-back, not a code
  change.
- n3 The 53-13 As built's `### Review` still reads "_Pending_"; the dev fills it from this report.

## Live acceptance

Not required now; I accept it as a 53-11 item, for these reasons: the wire behaviour the change depends on (R1–R4)
was measured on the installed CLI with the product's own projection and ladder; the chat wiring is covered by
`test_a_chat_session_lists_the_managed_skills_once` on the real SDK client over the fake engine; the fleet runs
v0.81.0 (not this commit) and must not be restarted. 53-11 must cover: one Feature Spec turn through `genesis serve`
that names a managed skill, checking the `Load skill` tool call in the turn's events, **and** the skill list of that
session showing each managed skill once (m1).

## Not checked

- A live spec-mode chat turn through `genesis serve` and `ChatManager` (accepted as 53-11, above).
- The production directory nesting on the real engine (m1).
- The `python:3.13` CI image (L-112; 53-12).
- The author's mutation checks: not repeated (the reviewer cannot edit code); the tests' assertions were read and
  each mutation they claim would fail one of them.
- kiro-cli 3.x (53-12 re-measure).
- Commit `7d7cd2d` (docs only, outside 53-13).

## Verdict: SHIP

No blocker or major; every gate green on re-run. m1 is a measurement owed before the phase ships (53-11, zero
credits); m2 is a one-line hardening that can ride with the next 53-x commit.
