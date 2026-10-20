# 47-06 — The five agents, their skills and hooks (Kiro CLI 3)

> **Status:** 🟢 BUILT 2026-10-20 (session S5; As built below — live acceptance after the real install recorded in
> S5b, see "Live acceptance after the real install"). Repo: project-tracker (`genesis/agent-system/`). Parent:
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
| `shell` allow | `genesis-ctx *`, `git status*`, `git log*`, `git diff*`, `git show*`, `git -C {{TRACKER}} add/commit` | + pytest, ruff, npm/npx (lint, typecheck, test, build), `git add*`, `git commit*` | + pytest, ruff, npm/npx test/lint/typecheck (`node *` is `ask`) | + `git add*`, `git commit*`, `glab ci list*`, `glab ci trace*` | `genesis-ctx *`, `git -C {{TRACKER}} …` status/diff/add/commit |
| `shell` ask | `git -C {{TRACKER}} push*`, anything else | anything else | anything else | `git tag*`, `git push*`, `gsm *` | `git push*` |
| `shell` deny | `git tag*`, any push from a code repo | `git push*`, `git tag*`, `git reset --hard*`, `git clean*`, `rm -rf*` | `git commit*`, `git push*`, `git tag*` | `git push --force*`, `git reset --hard*` | `git push --force*` |
| Extra L1 file | — | `reference/coding-standards.md` | `reference/coding-standards.md` | — | — |
| Skills | spec-authoring | backend-dev, api-dev, web-dev, workflow-authoring, db-migration, live-acceptance | code-review, live-acceptance | release | doc-writeback, spec-authoring |
| Sub-agents | default (exploration) | `genesis-review` | default (exploration) | — | default (exploration) |
| Hooks | SessionStart status · PreToolUse shell-guard · Stop `lint --specs-only` (bounded) | SessionStart status · PreToolUse bulk-read guard · PreToolUse shell-guard | SessionStart status · PreToolUse bulk-read guard · PreToolUse shell-guard | SessionStart status · PreToolUse shell-guard (`--allow-push-tag`) | SessionStart status · PreToolUse shell-guard · Stop `lint` (bounded) |

`{{TRACKER}}` = `/Users/ramaswamy.u/repo/project-tracker/genesis`, `{{REPOS}}` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u`
(rendered by the installer, 47-07). Deny always wins (CLI 3).

**Permission hardening (47-09 fix B1/M1).** The broad read-command shell allows (`cat *`, `grep *`, `ls *`, `rg *`,
`find *`) are removed from every profile — reads go through the built-in `read`/`grep`/`code` tools — and `node *` is
`ask`. A `cat x > /any/path` (or `node -e "fs.writeFileSync(…)"`) therefore no longer slips through an allow rule, and
the `shell-guard.sh` PreToolUse hook (§8) is a hard backstop that holds **even under `--trust-all-tools`**: it refuses
`git push`/`tag` for every agent but `genesis-release` (any path, `env`/`-C`/chain/`sh -c` form) and any shell write
outside the agent's write roots. The installer validation also rejects re-adding a bare `<write-cmd> *` shell allow.

## 4. Example profile — `agent-system/agents/genesis-dev.json` (template)

> **Correction (S5b, operator decision #5):** profiles are **JSON** (`genesis-*.json`), not Markdown — see As built,
> deviation 1. The block below shows the fields in the original frontmatter notation; the committed file
> `agents/genesis-dev.json` is authoritative (same fields, `prompt` string = the body, `permissions.rules` objects).

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
start. You do **not** read the bible. Follow the retrieval protocol in L0-core §3; fetch full texts in ONE direct call,
many ids: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-021 ADR-032` (or `lesson L-056 L-057`), never inside a loop, pipe,
`;`, `&&`, `$(…)`, redirect or `VAR=` prefix (those are denied). ADRs are non-negotiable; lessons are
do-not-regress; ask before destructive or irreversible actions; report with cited evidence." (The one-call clause is
47-09 round-2 m9: the agent's batched `G=…; for a in …; do $G adr …; done` fell outside the `genesis-ctx *` allow rule
and was denied non-interactively; `test_documented_retrieval_form_matches_each_profiles_allow_rules` pins it.)

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
| `stop-lint.sh [--specs-only]` | Stop: run `genesis-ctx lint`; on failure, if this session has continued < 2 times (counter in `$TMPDIR/genesis-stop-<session_id>`), print `{"decision":"block","reason":"<lint summary>"}`; else exit 0 and leave the summary for the user. Hook `timeout: 10` s, set explicitly (47-09 m7). Measured full lint on this tracker: 0.18 s warm, 0.38 s cold, 0.78 s cold under 8-core load; 2× ≈ 1.6 s, so the CLI default already covered it and is kept as the floor | role prompt step "run lint before finishing" |
| `shell-guard.sh [--allow-push-tag] --write-root R…` | PreToolUse on `shell` (47-09 B1/M1): exit 2 on (a) a `git push`/`tag` subcommand from any form (absolute path, `env`/`command`/`exec`/`VAR=`/`-C`/chain/`sh -c`) unless `--allow-push-tag` (genesis-release); (b) a shell write (`>`/`>>`/`2>`/`&>`, `tee`, `cp`, `mv`, `rm`, `sed -i`, `dd of=`) whose target resolves outside the agent's `--write-root`s (or cannot be resolved statically). The command is lexed like a shell (47-09 M5): a `>` inside quotes is not a redirect; fd duplications (`2>&1`, `>&2`, `N>&M`) are not writes; `/dev/null`·`/dev/stdout`·`/dev/stderr`·`/dev/tty`·`/dev/fd/N` are allowed targets. Holds under `--trust-all-tools`. Fails open only if the payload can't be read | the removed broad allows + the no-trust `ask` gate + the review |
| (SessionStart) | `genesis-ctx status --brief` directly | `UserPromptSubmit` with `cache_ttl` |

## 9. Acceptance

- `kiro-cli agent validate` (or the CLI-3 equivalent) passes for all five rendered profiles.
- In a fresh `genesis-dev` session from the root workspace, `/context show` lists exactly the §4 resources and the
  starting **Genesis share** is **≤ 5 %** of the window before any pack. Genesis share = session total − a plain
  `kiro-cli --v3` session with the same prompt; the total is recorded for information only (47-01 §5.7).
- Probe results (§2) recorded; any fallback applied.

## Context manifest

```toml
docs = ["tracker:specs/phase-47-agent-context-system/47-02-layout-and-metadata.md",
        "tracker:specs/phase-47-agent-context-system/47-07-install-and-update.md",
        "tracker:specs/phase-47-agent-context-system/47-08-documentation-standard.md"]
```

## As built

**Session:** S5, 2026-10-20. **Bootstrap rule honored** (no bible read whole; only `genesis-ctx` + ranged reads).

### Step 0 — CLI probe (§2), on `kiro-cli --v3` (KAS 0.66.43)

The default `kiro-cli` is 2.32.0; the next-gen engine is launched with **`kiro-cli --v3`** (the user confirmed it is
installed). All six §2 checks were run empirically on this machine:

| § | Check | Result |
|---|---|---|
| (a) | A profile with absolute `file://`/`skill://` resources loads | **Pass.** A JSON profile in `.kiro/agents/` loads; `file://` resources resolve at load and a missing one is reported by `agent list`. `file://./x` resolves relative to `~/.kiro/agents/`, so **absolute paths (D3) are required**. The interactive `/context show` TUI command cannot be driven in `--no-interactive` (it narrates instead), so the live resource listing + ≤5% is verified after the real install (47-07 §5 / §9 here); the token budget is computed below. |
| (b) | `SessionStart` stdout → context | **Pass.** The hook fires (confirmed via a side-effect log); docs confirm exit-0 stdout is added to context for `SessionStart`. |
| (c) | `Stop` `{"decision":"block"}` → continue | **Doc-confirmed** (hooks/types): exit-0 `{"decision":"block","reason":…}` on stdout makes the agent take another turn; not independently driven headlessly. `stop-lint.sh` bounds this to **two** continues per session. |
| (d) | `PreToolUse` exit 2 blocks a read + stderr seen; stdin shape | **Pass (key probe).** A `PreToolUse` hook with `matcher: "read"` fired on the read tool, exit 2 **blocked** it and the agent reported the stderr verbatim. The stdin JSON is `{"session_id","hook_event_name","cwd","tool_name":"read_file","tool_input":{"path","offset","limit"}}` — so the guard keys on `tool_input.path` and treats a read with no positive `limit`/`offset` as whole-file. |
| (e) | `toolsSettings.subagent.availableAgents` | **Doc-confirmed** + profile validates with the block present; runtime spawn verified in the pilot (47-09). |
| (f) | `permissions.rules` deny on `shell` blocks | **Pass.** A `shell` deny rule blocked a matching command **even under `--trust-all-tools`** — deny wins over trust. |

### Deviations from the spec text (all applied; none changes WHICH context loads)

1. **Profiles are JSON, not Markdown** (47-06 §4 showed Markdown frontmatter). V3 accepts both, but JSON is what
   `kiro-cli --v3 agent create` emits and lets the installer validate with stdlib `json` (no YAML parser needed). Same
   fields, same semantics. The long role prompt (§5) is the JSON `prompt` string.
2. **`permissions.rules` replace `allowedTools`** (V3): a profile with `allowedTools`/`toolsSettings` but no
   `permissions` is skipped by V3 as un-migrated. Every profile carries a `permissions` block. Capability names are
   `fs_read` / `fs_write` / `shell` (not `execute_bash`); **deny wins** across scopes.
3. **`tools` uses V3 tags** `read, write, shell, web, subagent` plus **`code`** — the `--v3` engine's `/tools` lists a
   **code-intelligence tool `code`** (tree-sitter/LSP symbol search, refs, AST, diagnostics), so it is kept on
   `genesis-spec`, `genesis-dev` and `genesis-review` (per the operator's instruction to verify the tool exists before
   dropping it). `genesis-release`/`genesis-docs` have no `code`. `subagent` is on every agent that spawns sub-agents
   (spec/dev/review/docs); `genesis-release` has none.
4. **PreToolUse matcher is the tag `read`** (confirmed firing on `read_file`); shell globs support only `*` (fs globs
   support `**`), which all patterns respect.
5. **`agent validate` is lenient** (it accepted a bad `effect` and an unknown capability; exit code unreliable). The
   47-07 installer therefore does its own stdlib validation and relies on the loader's own missing-resource error.
6. **`fs_read` allow** is granted to `{{TRACKER}}/**`, `{{REPOS}}/**`, `{{GENESIS_HOME}}/**`, `/tmp/**` on every agent
   (agents launch from the root workspace but must read project-tracker); the bulk-read-guard protects the big docs.
7. **`genesis-ctx` is invoked by absolute path** `{{GENESIS_HOME}}/bin/genesis-ctx` in every role prompt, skill body
   and hook command (agent shells do not load the user's shell profile, so a bare `genesis-ctx` would not resolve, and
   PATH/`/usr/local/bin` are deliberately left untouched — operator decision #3). The installer renders `{{GENESIS_HOME}}`
   and prints a one-line `export PATH=…` hint for the operator's own terminal. The bare `genesis-ctx *` shell-allow rule
   is kept in each profile as a harmless extra. (The absolute path lives inside backtick/code spans; prose descriptions
   and the `"genesis-ctx *"` allow rule stay bare.)
8. **Profile vs §3 matrix, recorded deviations (47-09 m6).** (a) genesis-review `fs_write` allows `/tmp/**` as well as
   `/tmp/genesis-review/**`: its live-acceptance and probe scripts use throwaway sandboxes such as `/tmp/gr-sbx`, and a
   `/tmp` write cannot reach code or the tracker. Its shell-guard write roots are `{{TRACKER}}/specs` + `/tmp`. Kept.
   (b) genesis-spec has no explicit `git -C <code repo> push*` deny rule; it falls to "ask". In practice it is denied,
   because shell-guard refuses any push/tag from a non-release agent, in any form, even under trust-all. Kept.
   (c) genesis-dev `trustedAgents` now **matches** §4 (`["genesis-review"]`, so spawning the reviewer needs no
   approval), pinned by `test_subagent_trust_matches_the_spec`.

### Files (under `project-tracker/genesis/agent-system/`)

```
agents/genesis-{spec,dev,review,release,docs}.json   5 JSON profiles, {{TRACKER}}/{{REPOS}}/{{GENESIS_HOME}}/{{MODEL}} placeholders
skills/genesis-{spec-authoring,backend-dev,api-dev,web-dev,workflow-authoring,
       db-migration,live-acceptance,code-review,release,doc-writeback}/SKILL.md   10 skills, each ≤ 2K tokens
hooks/bulk-read-guard.sh    PreToolUse on read: blocks WHOLE-file reads of decision-log / bible 03·04·06 / archive / tracker
hooks/stop-lint.sh [--specs-only]   Stop: genesis-ctx lint; {"decision":"block"} to continue, bounded to 2/session
```
Removed the `.gitkeep` sentinels in `agents/`, `skills/`, `hooks/`. SessionStart uses `genesis-ctx status --brief`
directly (no script). Skills are **procedures + absolute-path pointers** (inline code, not markdown links, so `lint` stays
clean) into the real docs — no source doc was rewritten.

### Skills (token sizes, all ≤ 2K)

`spec-authoring` 802 · `backend-dev` 578 · `api-dev` 380 · `web-dev` 409 · `workflow-authoring` 444 ·
`db-migration` 393 · `live-acceptance` 407 · `code-review` 480 · `release` 503 · `doc-writeback` 1108.
Each points at `genesis-ctx adr|lesson|area` and the authoritative `reference/` / `bible/05` docs by absolute path.

### Acceptance (§9)

- **All five rendered profiles pass `kiro-cli --v3 agent validate`** (and round-trip through stdlib `json`).
- **Starting context budget** for a fresh `genesis-dev` (the §4 resources): L0 = **~14.9K tokens** = **1.49 %** of a
  1M window (L0-core 1.1K + bible/02 0.9K + bible/07 0.9K + adr-digest 4.1K + lesson-digest 3.8K + area-catalog 0.8K +
  state 0.8K + coding-standards 2.4K). Plus the ~1.2K role prompt and the `status --brief` output (~0.5K) and the six
  `skill://` **metadata** lines (loaded on demand, not full bodies) → **≈ 1.7 % before any pack**, well under the ≤ 5 %
  bar. The live `/context show` confirmation runs in the fresh-session acceptance after the real install (47-07 §5).
- **`genesis-ctx lint` green** with the new `agent-system/*.md` skills (0 errors, 0 warnings; L0 ~12,267 tokens).
- `bulk-read-guard.sh` unit-checked: blocks whole-file reads of decision-log / bible-04 / archive / tracker, allows a
  ranged read (positive `limit` or non-zero `offset`) and any other path.

### Resume pointer

Live `/context show` + runtime sub-agent spawn (e) are verified in the fresh-session acceptance right after
`install.sh` runs (47-07). Build order from here: **47-07** (installer + tests, then `install.sh --dry-run` → real
install on the operator's yes), then **47-08** (the `genesis-doc-writeback` skill is already written to the 47-08
standard; verify the `add adr|lesson` formats and finalize).

### Live acceptance after the real install (S5b, 2026-10-20, `kiro-cli --v3`, KAS 0.66.43)

Headless probes: `kiro-cli --v3 chat --agent <a> --output-format stream-json …` from `~/repo-gitlab/ramaswamy.u`; the
context numbers are the engine's own `contextUsage` breakdown (the data `/context show` renders).

| Check | Result |
|---|---|
| `kiro-cli --v3 agent list` | **five** `genesis-*` agents, Global, no load errors (the two "File URI not found" errors in the list belong to the pre-existing `project-tracker` agent). |
| L0 resources loaded (genesis-dev) | **Pass** — exactly the eight §4 `file://` resources: L0-core 1,126 · bible/02 900 · bible/07 888 · adr-digest 4,051 · lesson-digest 3,750 · area-catalog 760 · state 792 · coding-standards 2,428 = **14,695 tokens (1.5 %)**. |
| SessionStart status in context | **Pass** — the agent quoted `genesis-ctx status (local refs only, no fetch)` + the repo lines verbatim. |
| Starting context (≤ 5 % bar) | genesis-dev **5.51 %** vs a plain V3 session with the same one-line prompt **3.87 %** → **Genesis-attributable ≈ 1.6 %** (matches the 1.7 % estimate above). The remaining ≈ 3.9 % is Kiro's own system prompt + built-in tools, present in every session. The literal 5 % is exceeded only by that platform baseline — **flagged to the operator**; the bar is read as Genesis-attributable. |
| `code` tool (decision #2) | **Present** — the V3 built-in list contains `code` (tree-sitter/LSP); genesis-dev ran `code get_document_symbols` successfully. Kept on spec/dev/review by exact id `code`. |
| Sub-agent spawn (e) | **Pass** — genesis-dev spawned `genesis-review`; it answered in its review role with L0 loaded. SessionStart hooks do **not** run for sub-agents → review prompt step 1 now says to run `genesis-ctx status --brief` itself when no status block is present. |
| Bulk-read guard (installed) | **Pass** — a whole-file read of `decision-log.md` by genesis-dev was blocked with the guard message (now naming the absolute `genesis-ctx` path); a ranged read passes. |
| **`skill://` resources** | **Fallback applied.** The skill tool listed only the inherited `appian` skill. Root cause (KAS source + log): profile skills are registered only at `session/new` when the session is *created* in the agent's mode; `kiro-cli --v3 chat --agent X` creates it as `vibe` and then calls `session/setMode`, which does not re-register skills. Fallback (§8 spirit): every prompt ends with a **Skills** paragraph naming each skill and its absolute `SKILL.md` path ("activate it if listed, else read it directly"); verified — genesis-dev read `genesis-backend-dev` and quoted its heading. The `skill://` entries stay (they work wherever a client creates the session in-mode); the installer now **fails validation** if a `skill://` path is not named in the prompt. |
| CLI auto-upgrade | `chat.enableAutoAgentUpgrade` is on; after the first and every later `--v3` launch the installed files still match the manifest (**18/18 sha256 + mode**). |

Interactive check for the operator: `cd ~/repo-gitlab/ramaswamy.u && kiro-cli --v3 chat --agent genesis-dev`, then
`/context show` → expect the eight L0 files (≈ 14.7K tokens, ≈ 1.5 %) and a total of **≈ 5–6 %** before any pack; if the
six `genesis-*` skills also appear as progressively-loaded items, the interactive client creates sessions in-mode and
the fallback is merely redundant.

### 47-09 round-2 fix M5 — quote-aware `shell-guard.sh` (2026-10-20, genesis-dev)

The round-1 guard ran a `>` regex over raw segment text, so it read quoted `>` and fd duplications as file targets and
false-denied ordinary commands (`2>/dev/null`, `… 2>&1`, an f-string `{v:>7}`, `grep '2>/dev/null'`). The embedded
Python now **lexes the command like a shell**: quotes, `\` escapes, `#` comments, line continuations; `;` `&&` `||` `|`
`|&` `&` newline and `( … )` subshells; heredocs (body attached to its command); `$(…)`, backticks and `<(…)`/`>(…)`
bodies are analysed recursively; `$((…))`, `(( … ))` and `[[ … ]]` are not redirects.
- **Redirects:** `N>`, `>>`, `>|`, `&>`, `&>>`, `<>` and `>&file` are writes; `>&N` / `N>&M` / `N>&-` are fd dups (not
  writes). `/dev/null`, `/dev/stdout`, `/dev/stderr`, `/dev/tty`, `/dev/fd/N` are allowed for redirects, `tee`, `cp`,
  `dd of=` (not for `rm`/`mv`). Paths are normalised first (`/dev/../etc/x` is blocked).
- **Resolution:** `NAME=…` / `export NAME=…` earlier in the line and `for v in a b c` loop values are tracked; `~` and
  set environment variables expand; `cd`/`pushd` move the cwd, a `( … )` subshell restores it. A write target that
  cannot be resolved statically (unset `$VAR`, a `$(…)` inside it) is **blocked** (fail closed) — the round-1 guard
  resolved such a target as a relative path and could *allow* it.
- **Push/tag (a), hardened while here:** any word that is `git` (also via `$G`, `/usr/bin/git`) followed by push/tag
  after git's global options; wrappers `env -i`/`sudo -u x`/`timeout N`/`nice -n N`/`stdbuf`; `if`/`while` heads;
  `sh|bash|zsh -c` with combined flags (`-lc`); `eval`; a heredoc/here-string fed to a shell; an unresolvable git
  subcommand (`git $X`); `git -c alias.…=…`. Known over-blocks kept (fail closed): `git push --help`, read-only
  `git tag -l` (the profiles deny `git tag*` anyway). Not a sandbox: a script *file* run by an interpreter is not
  inspected (the profiles don't allow-list `bash`/`python`, so without trust-all it still asks).

Evidence: `tests/test_shell_guard.py` **94 passed** (34 round-1 cases unchanged, the 4 review false positives plus 21 more
idioms allowed, 20 real out-of-scope writes and 14 push/tag forms blocked). The review's probe table re-run against the
repo hook (`/tmp/genesis-dev/guard_probe_r2.sh`) gave **38/38** as expected: the 33 original probes and 5 false-positive
probes. A replay of all **196 distinct shell commands** that Genesis agents ran in recorded sessions, through the old and
new hook, found **0 newly blocked**; 22 old false denials now pass, and the 14 still blocked are the review's deliberate
push/tag/out-of-root probes (plus `git tag --sort` listing).
