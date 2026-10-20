---
name: genesis-agent-system
description: Use when changing the Genesis agent system itself — the five agent profiles, skills, hooks, shell-guard, the installer (install/update/uninstall), their tests, and the Kiro CLI-3 behaviours they depend on. For the genesis-docs agent (and any agent asked to edit agent-system/).
---

# Maintaining the Genesis agent system

Source of truth: `{{TRACKER}}/agent-system/` (never edit the installed copies under `~/.kiro`). Design: ADR-077
(`{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-077`); spec `{{TRACKER}}/specs/phase-47-agent-context-system.md` (47-06
agents/skills/hooks, 47-07 installer); known limits `{{TRACKER}}/specs/backlog/phase-47-follow-ups.md`.

## Layout

| Path | What |
|---|---|
| `agents/genesis-<role>.json` | CLI-3 JSON profiles (`name`, `description`, `model` = claude-opus-5.5, `tools`, `resources`, `permissions.rules`, `toolsSettings`, `hooks`, `prompt`, `welcomeMessage`) |
| `skills/genesis-<name>/SKILL.md` | frontmatter `name` (= directory) + `description`; ≤ 2K tokens; procedures + absolute-path pointers, never copies of source docs |
| `hooks/shell-guard.sh` | PreToolUse on `shell`: blocks git push/tag (any form) except genesis-release, and shell writes outside the agent's write roots — even under `--trust-all-tools` |
| `hooks/bulk-read-guard.sh` | PreToolUse on `read`: blocks whole-file reads of decision-log, bible/03/04/06, tracker, archive |
| `hooks/stop-lint.sh` | Stop: `genesis-ctx lint` (spec/docs), continues the agent at most twice |
| `tools/genesis_ctx/` | the context compiler (runs from source via the shim — no reinstall needed) |
| `tools/installer/` | stdlib installer; `install.sh` / `update.sh [--pull] [--dry-run]` / `uninstall.sh` |
| `tests/` | pytest: `{{REPOS}}/genesis/.venv/bin/python -m pytest -q {{TRACKER}}/agent-system/tests` |
| `OPERATOR_GUIDE.md` | the human's guide — update it whenever behaviour, prompts or launch commands change |

Placeholders rendered at install: `{{TRACKER}}`, `{{REPOS}}`, `{{GENESIS_HOME}}`, `{{MODEL}}` (`install.conf` overrides).

## CLI-3 facts (verified live, KAS 0.66.43 — re-check after a CLI upgrade)

- Launch: `kiro-cli --v3 chat --agent genesis-<role>` from `~/repo-gitlab/ramaswamy.u`; `kiro-cli --version` still
  prints 2.x. `kiro-cli agent validate` is lenient — the installer's own validation is the gate.
- Profile `skill://` resources are NOT registered on `chat --agent`: every skill must ALSO be named by absolute
  `SKILL.md` path in the prompt's "Skills" paragraph (the installer refuses a profile otherwise).
- Sub-agent spawn needs a `permissions` rule `{capability: subagent, match: [<agent>], effect: allow}`;
  `toolsSettings.subagent.trustedAgents` alone does not stop the approval prompt. Sub-agents get no SessionStart hook.
- Permission rules: deny wins; prefix globs on commands leak (redirects, `/usr/bin/git`, `env git`, `sh -c`) — real
  blocking belongs in `shell-guard.sh`. Never add a bare `cat|grep|ls|find|… *` allow (the installer refuses it).
- Non-interactive (`--no-interactive`) mode denies anything that would prompt — keep the documented one-call
  `genesis-ctx` form inside the allow rules.
- `chat.enableAutoAgentUpgrade` may rewrite profiles: after a CLI upgrade, run `update.sh --dry-run` (it compares
  sha256 with `~/.kiro/genesis/install.json`).

## Procedure for any change

1. Edit the source file(s). For a new skill: create the directory, add `skill://{{GENESIS_HOME}}/skills/<name>/SKILL.md`
   to each profile that needs it AND name its path in that prompt's Skills paragraph.
2. Guards: every change to `shell-guard.sh` needs a bypass test (must stay blocked) AND a positive test (legitimate
   command must pass) in `tests/test_shell_guard.py` (lesson L-088).
3. Run the tests and `genesis-ctx lint`; then `{{TRACKER}}/agent-system/update.sh --dry-run`, show the plan, and
   tell the human to run `update.sh` (or run it if allowed). Backups go to `~/.kiro/genesis/backups/`.
4. Update `OPERATOR_GUIDE.md` if the user-visible behaviour changed; record the change (and any new CLI fact) in the
   relevant spec's As-built or a lesson via `genesis-ctx add lesson`.
5. Commit project-tracker; ask before pushing.
