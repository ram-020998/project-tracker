# 47-07 — Install, update, uninstall

> **Status:** 🟢 BUILT 2026-10-20 (session S5b; installed on this machine; As built below). Repo: project-tracker
> (`genesis/agent-system/`). Parent: `specs/phase-47-agent-context-system.md`. Decision D2. Session S5.

## 1. Goal

Edit agents, skills and hooks in project-tracker; run one script; the global installation matches. Safe to re-run,
never touches files it does not own, always reversible.

## 2. What gets installed

| Source (`agent-system/`) | Installed to | Notes |
|---|---|---|
| `agents/genesis-*.json` | `~/.kiro/agents/genesis-*.json` | rendered (placeholders → absolute paths); V3-format JSON (47-06 As built, deviation 1) |
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
| `install.sh [--dry-run] [--force]` | Preflight → render into a temp dir → validate → show the plan → copy → write manifest. Refuses to overwrite an existing `~/.kiro/agents/genesis-*.json` (or a same-named `.md`/`.yaml` agent) that is **not** in the manifest (a file you made yourself) unless `--force` (which backs it up first). |
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
MODEL=                                                    # empty = keep each profile's pinned model (claude-opus-5.5)
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

## As built (2026-10-20, session S5b)

- **Commits:** project-tracker — one local commit "Phase 47 (47-07)" (not pushed).
- **Changed** (under `agent-system/`):
  - `tools/installer/genesis_installer.py` — stdlib installer: config (`install.conf`, unknown keys and relative paths
    rejected), in-memory render of **every** copied text file (binary files copied verbatim), own validation, plan
    (added / changed / removed / unchanged / adopted / foreign), unified diffs in `--dry-run`, atomic writes, backups,
    manifest. `tools/installer/__main__.py`, `tools/installer/run.sh` (picks Python ≥ 3.11).
  - `install.sh`, `update.sh`, `uninstall.sh` — thin `set -euo pipefail` wrappers.
  - `install.conf.example` — all four keys documented; agents/hooks: see "Fixes from the live acceptance".
  - `OPERATOR_GUIDE.md` — §2 setup (V3 check, `--v3` launch rule, optional `chat.agentEngine` with its global
    effect, PATH hint), every launch line `kiro-cli --v3 chat --agent …`, §7 measured context, §8 `.json` profiles +
    model override, §9 troubleshooting (V2 engine, skills fallback, sub-agent status, foreign-file refusal).
  - Spec corrections (operator decision #5, profiles are JSON): 47-06 §4 note, this §2/§3, umbrella §6.6; umbrella
    §13 **Q6 → "claude-opus-5.5 pinned in every profile; `MODEL=` in install.conf overrides"** (operator decision).
- **Tests:** `tests/test_installer.py` **25** tests (temp `HOME`, miniature source, fake `kiro-cli`): fresh install,
  render (no placeholders, absolute paths, shim target), MODEL override, dry run writes nothing, idempotent
  re-install, update changed+backup+diff / added / removed+backup, update before install refused, local edit backed
  up, foreign file refused, same-name `.md` agent refused, `--force` backs up, identical file adopted, uninstall
  removes only manifest files, six validation cases, preflight (missing repo; V3 note; no-V3 warning), conf errors,
  and the **real** committed agents/skills/hooks pass validation. Full suite **123 passed**; ruff clean.
- **Installed** (`install.sh`, after the operator's yes): 18 files — 5 profiles → `~/.kiro/agents/genesis-*.json`,
  10 skills → `~/.kiro/genesis/skills/`, 2 hooks + the shim (0755), manifest `~/.kiro/genesis/install.json`.
  Three `update.sh` runs since (see below) each showed exactly the edited file as `~ changed` and backed it up —
  the §5 "one changed file" acceptance. Last dry run: `18 unchanged — up to date`.
- **Acceptance (§5):** `kiro-cli --v3 agent list` → five agents; `~/.kiro/genesis/bin/genesis-ctx status --brief`
  works; edit role prompt + `update.sh` → exactly one changed file, and a new session reflects it (the Skills
  paragraph added via `update.sh` was followed by genesis-dev in the next fresh session). 47-06 §9 results are in
  47-06's As built ("Live acceptance").
  **sha256-vs-manifest after the first `--v3` launch: 18/18 match** (sha256 + mode); re-checked after every probe —
  the CLI's auto-upgrade did not rewrite the profiles.
- **Decisions / deviations** (ADR impact: none):
  1. **Model pinned** `claude-opus-5.5` in all five profiles (operator); `MODEL` non-empty replaces it at render;
     empty keeps the profile's value.
  2. **V3 launch**: `chat.agentEngine` (`v1`/`v2` default/`v3`) exists and is **not** set (operator: leave it);
     preflight reports which applies. Preflight warns — never fails — when no V3 engine is found.
  3. **Shim** execs the source `tools/genesis-ctx` script (which already picks Python ≥ 3.11) instead of
     `python3 …/genesis_ctx` as §2 sketched: macOS `/usr/bin/python3` is < 3.11, and a symlinked bash shim keeps one
     interpreter-selection rule. Tool fixes still apply without reinstall.
  4. **Ownership**: a destination not in the manifest but byte-identical is **adopted** (e.g. a lost manifest) rather
     than refused; a different foreign file, or a same-named agent in another format (`genesis-dev.md` next to our
     `.json`), is refused unless `--force`. Other `genesis-*` agents with different names are left alone (warning).
     Manifest entries outside `~/.kiro/agents/` and `GENESIS_HOME` are ignored (never deleted).
  5. **Render in memory** (not a temp dir) — same effect, nothing to clean up; validation runs before any write.
  6. **Validation is the installer's own** (`agent validate` is lenient, 47-06 deviation 5): JSON parses, name =
     file name, non-empty description/prompt/model, known tool tags, known capabilities/effects, non-empty match
     lists, `file://`/`skill://` absolute and existing (skills must be part of this install and be a `SKILL.md`),
     every hook command absolute + existing + executable, sub-agent names known, skill frontmatter `name` (= dir) +
     `description`, `#!` on hooks/shim, no `{{…}}` left anywhere — and (added after the live probe) every `skill://`
     path named in the prompt.
  7. `update.sh --pull --dry-run` only reports that it would pull (a dry run changes nothing, including git).
  8. **Fixes from the live acceptance** (all via `update.sh`): Skills paragraph with absolute `SKILL.md` paths in all
     five prompts (KAS registers profile skills only for sessions created in-mode — 47-06 As built); genesis-review
     step 1 runs `status --brief` itself when spawned as a sub-agent (no SessionStart there); the bulk-read guard's
     message names the absolute `genesis-ctx` path (agent shells have no PATH setup — decision #3).
- **Lesson candidates:**
  - Kiro V3 (KAS 0.66.43) registers a profile's `skill://` resources only when the session is created in that agent's
    mode; `chat --agent` switches mode after `session/new`, so name skills by path in the prompt as well.
  - SessionStart hooks do not fire for sub-agents; a sub-agent that needs the status must fetch it itself.
  - Measure context against a plain session with the same prompt: the platform baseline (~3.9 %) dwarfs small agent
    budgets and is not ours to cut.
- **Code-map changes:** new `agent-system/tools/installer/` (installer; area: agent-system tooling) + three scripts.
