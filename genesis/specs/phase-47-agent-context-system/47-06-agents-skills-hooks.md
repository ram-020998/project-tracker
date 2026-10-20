# 47-06 — The five agents, their skills and hooks (Kiro CLI 3)

> **Status:** 🟡 SPEC-DRAFTED 2026-10-20. Repo: project-tracker (`genesis/agent-system/`). Parent:
> `specs/phase-47-agent-context-system.md`. Decisions D2–D5, D9. Session S5.

## 1. Goal

Five global agents whose context is L0 + their role, which pull task context through `genesis-ctx`, and whose
permissions make the role boundaries hard (a dev agent cannot push; a review agent cannot edit code).

## 2. Step 0 — probe CLI 3 on this machine (≤ 15 minutes, before writing profiles)

Verify on the installed CLI 3 and record results in this spec's As-built: (a) a Markdown profile in `~/.kiro/agents/`
with absolute `file://` and `skill://` resources loads (`/context show`); (b) a `SessionStart` hook's stdout appears in
context; (c) a `Stop` hook returning `{"decision":"block","reason":…}` makes the agent continue; (d) a `PreToolUse` hook
exiting 2 blocks a `read` and the agent sees stderr — and what the hook's stdin JSON looks like for `read` (path,
offset/limit field names); (e) `toolsSettings.subagent.availableAgents` lets `genesis-dev` spawn `genesis-review`;
(f) `permissions.rules` deny on `shell` `git push*` blocks. Any feature that does not behave as documented gets the
fallback in §8.

## 3. Agent matrix

| | `genesis-spec` | `genesis-dev` | `genesis-review` | `genesis-release` | `genesis-docs` |
|---|---|---|---|---|---|
| Purpose | Q&A → findings, umbrella, sub-specs with manifests | implement **one** sub-spec | independent review + live acceptance | version, tag, push, CI, deploy | write-back after a phase |
| `tools` | read, write, shell, web, subagent, code | read, write, shell, web, subagent, code | read, shell, code, write | read, write, shell | read, write, shell |
| `fs_write` allow | `{{TRACKER}}/specs/**`, `{{TRACKER}}/README.md` | `{{REPOS}}/**`, `{{TRACKER}}/specs/**` | `{{TRACKER}}/specs/**/reviews/**`, `/tmp/genesis-review/**` | version files in `{{REPOS}}/**` (ask), `{{TRACKER}}/specs/**` | `{{TRACKER}}/**` |
| `fs_write` deny | `{{REPOS}}/**` | `{{REPOS}}/**/.git/**` | `{{REPOS}}/**` | — | `{{REPOS}}/**` |
| `shell` allow | `genesis-ctx *`, `git status*`, `git log*`, `git diff*`, `git show*`, `git -C {{TRACKER}} add/commit` | + pytest, ruff, npm/npx (lint, typecheck, test, build), `git add*`, `git commit*` | + pytest, ruff, npm/npx test/lint/typecheck, node (Playwright scripts in `/tmp`) | + `git add*`, `git commit*`, `glab ci list*`, `glab ci trace*` | `genesis-ctx *`, `git -C {{TRACKER}} …` status/diff/add/commit |
| `shell` ask | `git -C {{TRACKER}} push*`, anything else | anything else | anything else | `git tag*`, `git push*`, `gsm *` | `git push*` |
| `shell` deny | `git tag*`, any push from a code repo | `git push*`, `git tag*`, `git reset --hard*`, `git clean*`, `rm -rf*` | `git commit*`, `git push*`, `git tag*` | `git push --force*`, `git reset --hard*` | `git push --force*` |
| Extra L1 file | — | `reference/coding-standards.md` | `reference/coding-standards.md` | — | — |
| Skills | spec-authoring | backend-dev, api-dev, web-dev, workflow-authoring, db-migration, live-acceptance | code-review, live-acceptance | release | doc-writeback, spec-authoring |
| Sub-agents | default (exploration) | `genesis-review` | default (exploration) | — | default (exploration) |
| Hooks | SessionStart status · Stop `lint --specs-only` (bounded) | SessionStart status · PreToolUse bulk-read guard | SessionStart status · PreToolUse guard | SessionStart status | SessionStart status · Stop `lint` (bounded) |

`{{TRACKER}}` = `/Users/ramaswamy.u/repo/project-tracker/genesis`, `{{REPOS}}` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u`
(rendered by the installer, 47-07). Deny always wins (CLI 3).

## 4. Example profile — `agent-system/agents/genesis-dev.md` (template)

```markdown
---
name: genesis-dev
description: Genesis developer — implements ONE sub-spec end to end (pack → build → test → review → As-built). Never pushes or tags.
tools: ["read", "write", "shell", "web", "subagent", "code"]
resources:
  - file://{{TRACKER}}/context/L0-core.md
  - file://{{TRACKER}}/bible/02-architecture.md
  - file://{{TRACKER}}/bible/07-working-on-tasks-and-agreements.md
  - file://{{TRACKER}}/context/_generated/adr-digest.md
  - file://{{TRACKER}}/context/_generated/lesson-digest.md
  - file://{{TRACKER}}/context/_generated/area-catalog.md
  - file://{{TRACKER}}/context/state/current.md
  - file://{{TRACKER}}/reference/coding-standards.md
  - skill://{{GENESIS_HOME}}/skills/genesis-backend-dev/SKILL.md
  - skill://{{GENESIS_HOME}}/skills/genesis-api-dev/SKILL.md
  - skill://{{GENESIS_HOME}}/skills/genesis-web-dev/SKILL.md
  - skill://{{GENESIS_HOME}}/skills/genesis-workflow-authoring/SKILL.md
  - skill://{{GENESIS_HOME}}/skills/genesis-db-migration/SKILL.md
  - skill://{{GENESIS_HOME}}/skills/genesis-live-acceptance/SKILL.md
permissions:
  rules:
    - { capability: fs_write, match: ["{{REPOS}}/**", "{{TRACKER}}/specs/**"], effect: allow }
    - { capability: fs_write, match: ["{{REPOS}}/**/.git/**"], effect: deny }
    - { capability: shell, match: ["{{GENESIS_HOME}}/bin/genesis-ctx *", "git status*", "git diff*", "git log*",
        "git show*", "git add *", "git commit *", "*/.venv/bin/python -m pytest*", "*/.venv/bin/ruff *",
        "npm run *", "npx tsc *", "npx eslint *", "npx vitest *"], effect: allow }
    - { capability: shell, match: ["git push*", "git tag*", "git reset --hard*", "git clean*", "rm -rf*"], effect: deny }
toolsSettings:
  subagent: { availableAgents: ["genesis-review"], trustedAgents: ["genesis-review"] }
hooks:
  - name: genesis-status
    trigger: SessionStart
    action: { type: command, command: "{{GENESIS_HOME}}/bin/genesis-ctx status --brief" }
  - name: bulk-read-guard
    trigger: PreToolUse
    matcher: read
    action: { type: command, command: "{{GENESIS_HOME}}/hooks/bulk-read-guard.sh" }
welcomeMessage: "genesis-dev ready. Tell me the sub-spec id (e.g. 'Implement 48-03')."
---
(role prompt — §5)
```

## 5. Role prompts (agent body, each ≤ 1.2K tokens)

Shared opening (every agent): "You are a Genesis <role> agent. Your always-loaded context is L0 (core, architecture,
work loop, the ADR and lesson digests, the area catalog, the current state); the live repo status was printed at session
start. You do **not** read the bible. Follow the retrieval protocol in L0-core §3. ADRs are non-negotiable; lessons are
do-not-regress; ask before destructive or irreversible actions; report with cited evidence."

| Agent | Procedure (abridged — full text in the profile) |
|---|---|
| spec | 1) Ask what to build; restate. 2) `genesis-ctx area <a>` for each area it touches; send sub-agents to read code and old specs, keep their summaries. 3) Research externally when useful. 4) Q&A **one question at a time**, record every answer in findings §Decisions. 5) Write `NN-01-findings`, the umbrella, the sub-specs (template + mandatory set from the skill), each with a `## Context manifest`. 6) `genesis-ctx lint --specs-only` green. 7) Update the README phase row (status "SPEC-DRAFTED"). Never edit code. |
| dev | 1) `genesis-ctx pack <id>`; read the pack and the **upstream As-built** sections. 2) Restate the task + applicable ADRs. 3) Work loop (bible/07 §8 steps 1–5). 4) Spawn `genesis-review` as a sub-agent with the sub-spec id and the base revision; fix findings until SHIP. 5) Commit locally per repo. 6) Write the sub-spec's **As-built** (§7). 7) If context passes ~60 %, write a **Resume note** in As-built and tell the user to start a fresh session. |
| review | 1) Input: phase or sub-spec ids + base revisions. 2) `genesis-ctx check --since <rev>` per repo; read the diff (not whole files) and the specs. 3) Run the gates. 4) Answer every checklist line OK / VIOLATION / N/A with evidence. 5) Report: findings by severity (blocker / major / minor / nit), verdict **SHIP** or **NEEDS_CHANGES**, written to `specs/<phase>/reviews/<id>-review.md`. 6) Live acceptance per the skill when asked; stop at every HITL gate and ask the user. |
| release | 1) Read the release sub-spec; `genesis-ctx status`. 2) ADR-019 order; bump versions in every place the skill lists; rebuild + commit `web/static` when web changed. 3) **Ask** before each tag and push. 4) Verify CI with `glab ci list`; record pipeline ids. 5) Fleet refresh only on the user's go-ahead. 6) Write the release sub-spec's **As run**. |
| docs | 1) Input: phase id. 2) Gather only: umbrella status + every sub-spec's As-built + review reports + release As-run + `git log <prev-tag>..<tag> --oneline` per repo. 3) Apply the write-back routing (47-08 §2) using `genesis-ctx add adr|lesson`. 4) Overwrite `state/current.md`; changelog line; README row; ≤ 5-line tracker §6 entry; progress doc. 5) `genesis-ctx index && lint` green. 6) Commit project-tracker; ask before push. |

## 6. Skills (`agent-system/skills/<name>/SKILL.md`, installed to `{{GENESIS_HOME}}/skills/`)

Skills are **procedures + pointers** to existing documents (by absolute path, read in ranges), not rewrites. Each
`SKILL.md` ≤ 2K tokens; templates go in `references/`.

| Skill | Content | Sources it points at |
|---|---|---|
| `genesis-spec-authoring` | umbrella + sub-spec templates; mandatory sub-spec set (**NN-01 findings**, **API** (or "N/A" in the ledger), **review & acceptance** (code review + hardening + live acceptance), **release & onboarding** (release + docs write-back)) + feature sub-specs; context-manifest rules; Q&A protocol; status vocabulary | `specs/phase-46-*` as the exemplar; 47-02 §5 |
| `genesis-backend-dev` | venv, test/ruff commands, Python conventions, regression-test rule | `bible/05` §6, `reference/coding-standards.md` §2–§4, `reference/testing-strategy.md` |
| `genesis-api-dev` | `/api` router rules, client `/api` prefixing, contract fixtures + `web/src/types` parity, 409/CAS conventions | ADR-028 (`genesis-ctx adr ADR-028`), `bible/06` API lessons (via `area api`) |
| `genesis-web-dev` | web gates, build + commit `web/static`, tokens not hex, jest-axe, both themes, `<Button asChild>` ban | `bible/05`, ADR-027/055, `area web-shell` |
| `genesis-workflow-authoring` | reliability trio, `attach_healing`, META ↔ yaml parity, `validate_library`, node descriptions | `reference/workflow-authoring-standard.md`, `reference/reliability-standard.md`, ADR-011/067 |
| `genesis-db-migration` | forward-only migrations, `current_version`, never hand-written DDL, `genesis db upgrade`, backup rule | `area db` |
| `genesis-live-acceptance` | fleet + Playwright procedure, HITL stop rule, evidence screenshots, DB backups before fleet update | `bible/05` (Phase 46-10 bullet), `specs/phase-46-*/46-10-*` |
| `genesis-code-review` | `check` usage, checklist answering, severity scale, report template, verdict rules | `reference/coding-standards.md` §1, 46-10 §1 |
| `genesis-release` | ADR-019 order, every version location, pin bumps, tag/push protocol, CI verification, fleet refresh, release-notes template | `bible/05` §6, lessons in `area release-ci`, `specs/phase-46-*/46-11-release.md` |
| `genesis-doc-writeback` | the documentation standard (47-08), `add adr|lesson`, state overwrite rules, budgets | 47-08 |

## 7. The As-built section (dev → docs handoff, in every sub-spec)

```markdown
## As built (<date>, genesis-dev)
- **Commits:** genesis `abc1234` (local), genesis-workflows `def5678` (local)
- **Changed:** files/modules (one line each) · **Tests:** genesis pytest 1112 (+7), web vitest 335 (+3)
- **Review:** reviews/48-03-review.md — SHIP after 2 fixes
- **Decisions / deviations:** … (each with the reason; ADR impact: none | amends ADR-0NN | new ADR proposed)
- **Lesson candidates:** one line each (the docs agent turns them into lessons)
- **Code-map changes:** new/moved modules (area)
- **Resume note:** (only if the session ended early) what is done, what is next, open problems
```

## 8. Hook scripts (`agent-system/hooks/`) and fallbacks

| Script | Behaviour | Fallback if CLI 3 differs (§2) |
|---|---|---|
| `bulk-read-guard.sh` | PreToolUse on `read`: if the path is one of `reference/decision-log.md`, `bible/03|04|06`, `archive/**`, `tracker.md` **and** no range is given → exit 2 with "Use `genesis-ctx adr|lesson|area|search` or a ranged read." | rely on the L0 protocol + review; keep the script for later |
| `stop-lint.sh [--specs-only]` | Stop: run `genesis-ctx lint`; on failure, if this session has continued < 2 times (counter in `$TMPDIR/genesis-stop-<session_id>`), print `{"decision":"block","reason":"<lint summary>"}`; else exit 0 and leave the summary for the user | role prompt step "run lint before finishing" |
| (SessionStart) | `genesis-ctx status --brief` directly | `UserPromptSubmit` with `cache_ttl` |

## 9. Acceptance

- `kiro-cli agent validate` (or the CLI-3 equivalent) passes for all five rendered profiles.
- In a fresh `genesis-dev` session from the root workspace, `/context show` lists exactly the §4 resources and the
  starting context is **≤ 5 %** of the window before any pack.
- Probe results (§2) recorded; any fallback applied.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md",
        "tracker:specs/phase-47-agent-context-system/47-07-install-and-update.md",
        "tracker:specs/phase-47-agent-context-system/47-08-documentation-standard.md"]
```
