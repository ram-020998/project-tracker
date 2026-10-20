# 47-07 — Install, update, uninstall

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: project-tracker (`genesis/agent-system/`). Parent:
> `specs/phase-47-agent-context-system.md`. Decision D2. Session S5.

## 1. Goal

Edit agents, skills and hooks in project-tracker; run one script; the global installation matches. Safe to re-run,
never touches files it does not own, always reversible.

## 2. What gets installed

| Source (`agent-system/`) | Installed to | Notes |
|---|---|---|
| `agents/genesis-*.md` | `~/.kiro/agents/genesis-*.md` | rendered (placeholders → absolute paths) |
| `skills/genesis-*/**` | `~/.kiro/genesis/skills/genesis-*/**` | outside `~/.kiro/skills/` so other agents don't inherit them |
| `hooks/*.sh` | `~/.kiro/genesis/hooks/*.sh` | rendered; `chmod 755` |
| — | `~/.kiro/genesis/bin/genesis-ctx` | a shim: `exec python3 {{TRACKER}}/agent-system/tools/genesis_ctx "$@"` — tool fixes apply **without** reinstall |
| — | `~/.kiro/genesis/install.json` | manifest: source commit, rendered values, every installed file + sha256 |
| — | `~/.kiro/genesis/backups/<timestamp>/` | previous versions of replaced/removed files |

`{{GENESIS_HOME}}` = `~/.kiro/genesis` (expanded to an absolute path).

## 3. Scripts

All three are thin `bash` wrappers (`set -euo pipefail`, macOS-compatible) around
`python3 agent-system/tools/installer` (stdlib only).

| Script | Behaviour |
|---|---|
| `install.sh [--dry-run] [--force]` | Preflight → render into a temp dir → validate → show the plan → copy → write manifest. Refuses to overwrite an existing `~/.kiro/agents/genesis-*.md` that is **not** in the manifest (a file you made yourself) unless `--force` (which backs it up first). |
| `update.sh [--pull] [--dry-run]` | `--pull` first runs `git -C <project-tracker> pull --rebase`. Re-render, diff against the manifest: prints **added / changed / removed / unchanged**, backs up changed and removed files, applies, rewrites the manifest. Removes installed files whose source was deleted. No-op (and says so) when nothing changed. |
| `uninstall.sh [--dry-run]` | Removes exactly the manifest's files (backup first) and the manifest. Leaves `backups/`. |

Kiro CLI 3 hot-reloads agent profiles, so running sessions pick up changes; start a new session to be sure.

### 3.1 Preflight

`kiro-cli --version` ≥ 3 (warn and continue on 2.x with "profiles need CLI 3"); `python3` ≥ 3.11; `{{TRACKER}}` and
`{{REPOS}}` exist; the five repos exist under `{{REPOS}}`; `git` present. Fails with a clear message otherwise.

### 3.2 Configuration — `agent-system/install.conf` (optional; `install.conf.example` committed)

```ini
TRACKER=/Users/ramaswamy.u/repo/project-tracker/genesis   # default: derived from the script location
REPOS=/Users/ramaswamy.u/repo-gitlab/ramaswamy.u
GENESIS_HOME=~/.kiro/genesis
MODEL=                                                    # empty = your default model
```

`install.conf` is git-ignored (machine-specific).

### 3.3 Validation before copying

Every rendered profile: YAML frontmatter parses (minimal stdlib parser for the subset we use, or `kiro-cli agent
validate --path` when available); no `{{…}}` left; every `file://` / `skill://` path exists; every hook command path
exists and is executable; every skill has `name` + `description` frontmatter.

## 4. Tests

pytest with a temp `HOME`: fresh install; idempotent re-install; update with an edited agent (changed + backup), a new
skill (added), a deleted hook (removed + backup); refusal on a foreign `genesis-x.md`; `--force` backs up; uninstall
removes only manifest files; render leaves no placeholders; validation catches a missing resource path. ≥ 12 tests.

## 5. Acceptance

`install.sh` on this machine → `kiro-cli agent list` shows the five agents; `~/.kiro/genesis/bin/genesis-ctx status
--brief` works; editing a role prompt + `update.sh` shows exactly one changed file and the running agent reflects it.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-06-agents-skills-hooks.md"]
```
