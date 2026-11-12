# 53-13 — Managed skills in the spec-style chat modes (agent `resources`)

> **Status:** SPEC-DRAFTED 2026-11-11. Repo: **genesis** (`packages/kiro-agent-sdk`, `genesis/chat/**`). Parent:
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

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["chat", "sdk-acp"]
adrs     = ["ADR-020", "ADR-031", "ADR-034", "ADR-069"]
lessons  = ["L-011", "L-024", "L-041", "L-073", "L-087"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md", "tracker:specs/phase-53-kiro-sdk-v3/53-05-trust-and-permissions.md", "tracker:specs/phase-53-kiro-sdk-v3/53-07-chat-backend.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/kiro-agent-sdk/tests/**", "genesis/genesis/chat/manager.py", "genesis/genesis/chat/mode_profile.py", "genesis/tests/test_chat_manager.py", "genesis/scripts/spikes/53-02/**"]
upstream = ["53-05", "53-07", "53-08"]
```
