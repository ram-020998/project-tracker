# 51-02 — `playwright-appian` joins the Genesis agent system

> **Status:** BUILT 2026-11-02 (genesis-docs; As built below). Repo: **project-tracker** (`genesis/agent-system/`, `genesis/context/`). Built by
> **genesis-docs** (it maintains the agent system; skill `genesis-agent-system`). Parent:
> `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D19, D4.

## 1. Goal

Every later sub-spec may change `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/playwright-appian` with the same context,
review and release discipline as the Genesis repos, without moving it into the `genesis` monorepo.

## 2. Changes

1. **Tracked repos.** Add `playwright-appian` to `REPO_NAMES` in `agent-system/tools/genesis_ctx/config.py:13` and
   `agent-system/tools/installer/genesis_installer.py:32` (status, `check --repo`, `--since` resolution). Its default
   branch is `main` (genesis uses `master`); `status` must read each repo's own branch. Update L0-core §2 "Where things
   are" with one line: the repo, its role (Genesis's browser-test tool, own semver, published to the GitLab npm registry
   of project 13864), and that its `planning/` is the home of its internal design.
2. **New area `browser-testing`** in `context/areas.toml`:
   - globs: `playwright-appian/src/**`, `playwright-appian/skills/**`, `playwright-appian/tests/**`,
     `playwright-appian/package.json`, plus the Genesis test-execution paths created by this phase
     (`genesis/genesis/testexec/**`, `genesis/genesis/integrations/apwt/**`, `genesis/web/src/features/testing/**`,
     `genesis-workflows/workflows/{test-execution,action-capture,story-verification}/**`,
     `genesis-workflows/skills/genesis-test-authoring/**`). Lint fails on a glob matching nothing (state "What works"):
     add the Genesis globs in the sub-spec that creates the first file under each (51-05/51-06/51-07/51-09/51-11), or
     land the area with the `playwright-appian` globs only and extend it then — record which in the As built.
   - gates: `cd playwright-appian && npm run lint && npm run typecheck && npm test` (and, for a release, `npm run build`).
   - skills: `genesis-backend-dev` for now; a short new skill `playwright-appian-dev` (§3) is the procedure.
   - ADR/lesson routing: none of its own yet; ADR-081..084 are tagged to it when added (51-13).
3. **Agent allow rules** (`agent-system/agents/genesis-{dev,review,release}.json`): today dev may run `npm run *`,
   `npm ci*`, `npm install*`, `npx tsc*`, `npx eslint*`, `npx vitest*`. Add for dev and review: `npx playwright test*`,
   `npx playwright install chromium*`, `npx --no-install apwt *`, `npx apwt *`, `node dist/cli/index.js *` (the
   package's own CLI from a checkout). The shell guard (`hooks/shell-guard.sh`) must parse them like other commands
   (L-088): extend its positive corpus with these and its bypass corpus with `npx apwt …; rm …`, `npx playwright test
   $(…)`, and an `apwt` call that pipes to a network tool.
4. **Release flow** (`agent-system/skills/genesis-release/SKILL.md`): `playwright-appian` releases by tag `vX.Y.Z`
   equal to `package.json` version; its CI publishes to the registry only after the tag pipeline's gates (its D-37,
   D-38); record the published tarball URL; then vendor that exact tarball into genesis (51-05 §2) before the genesis
   release. Never publish by hand; never read CI variables (L-100).
5. **Invariants written into the area's docs** (so `pack`/`check` carry them): no LLM inside the framework (its D-02);
   Appian element knowledge only in `src/core/taxonomy.ts` (D-05); generated code is label-only (D-04); one npm
   package with subpath exports (D-01); trace schema `playwright_appian.trace.v1` is additive-only within v1
   (`src/core/trace-schema.ts:15`). Area `docs`: `playwright-appian/planning/BIBLE.md`, `DECISIONS.md`,
   `TRACKER.md` (ranged reads).
6. `agent-system/update.sh`, then `genesis-ctx index && genesis-ctx lint` green; `genesis-ctx status` shows four repos.

## 3. Skill `playwright-appian-dev` (≤ 1 page)

Where things are in the package, how to run its gates and its e2e suites (`npm run e2e:*` needs a live site — the
agents run only unit/real-browser tests unless the sub-spec says otherwise), how a decision is recorded (append a D-row
to `planning/DECISIONS.md` in its house format and cite it from the Genesis As built), version bump rules (semver below
1.0: a minor may break), and "never weaken an invariant in §2.5 without the user".

## 4. Tests

The agent-system test suite (`agent-system/tests/`, `pytest.ini`): `status` lists four repos with their own default
branches; an `npx apwt` command is allowed and its bypass variants denied; `check --repo playwright-appian --since
<rev>` routes `src/core/taxonomy.ts` to `browser-testing`.

## Context manifest

```toml
areas    = ["release-ci", "security"]
adrs     = ["ADR-077", "ADR-080"]
lessons  = ["L-087", "L-088", "L-100"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:agent-system/OPERATOR_GUIDE.md"]
code     = ["tracker:agent-system/tools/genesis_ctx/config.py", "tracker:agent-system/tools/installer/genesis_installer.py", "tracker:agent-system/agents/**", "tracker:agent-system/hooks/shell-guard.sh", "tracker:context/areas.toml"]
upstream = []
```

## As built (2026-11-02, genesis-docs)

**Commits:** project-tracker, one local commit "51-02: playwright-appian joins the agent system" (not pushed).

**Changed**
- Repo list: `REPO_NAMES` = genesis, genesis-workflows, playwright-appian in `tools/genesis_ctx/config.py` and
  `tools/installer/genesis_installer.py` (status, `check` with and without `--repo`, `--since`, installer preflight).
  `status` already read each repo's own HEAD branch; no code change was needed there, only a test.
- `context/areas.toml`: new area `browser-testing`, **playwright-appian globs only** (`src/**`, `skills/**`, `tests/**`,
  `package.json`); a comment names the Genesis globs and the sub-specs that add each one when they create its first
  file (51-05/51-06/51-07/51-09/51-11). Gates: `npm run lint && npm run typecheck && npm test` (the comment names the
  invariant tests and D-ids, so `check` prints them) and `npm run build` for a release. Docs: the new skill, then
  `planning/BIBLE.md`, `DECISIONS.md`, `TRACKER.md`. Skills: the new skill + `genesis-backend-dev`.
- Agents `genesis-dev` and `genesis-review`: allow `npx playwright test*`, `npx playwright install chromium*`,
  `npx --no-install apwt *`, `node dist/cli/index.js *`; the new skill as a `skill://` resource and in the prompt's
  Skills paragraph. `genesis-release` unchanged (it already allows `npx *`; its release flow is in its skill).
- `hooks/shell-guard.sh` rule **(c)**, every agent including genesis-release: refuse data fed into a network client
  (`curl`, `wget`, `nc`/`ncat`/`netcat`, `socat`, `telnet`, `ssh`, `scp`, `sftp`, `rsync`, `ftp`, `http`/`https`,
  `xh`): a pipe into it (also through `xargs`, `parallel`, `eval`, `sh -c`), a here-doc/here-string, or a `<` from a
  file other than `/dev/null`. The lexer marks a command that follows `|`/`|&` as `piped`.
- New skill `skills/genesis-playwright-appian-dev/SKILL.md` (§3: layout, gates, e2e rule, decision rows, versions,
  invariants, git). `skills/genesis-release/SKILL.md`: three repos, order playwright-appian → genesis →
  genesis-workflows, a playwright-appian section (tag = version, CI publishes after the tag pipeline's gates, tarball
  URL in the As run, vendor before the genesis release, never publish by hand, L-100), the template line.
  `skills/genesis-ctx/SKILL.md`: status row.
- `context/L0-core.md` §2: one line for the repo. `OPERATOR_GUIDE.md` §2 (four status rows, three repos) and the
  shell-guard troubleshooting row. `context/state/current.md`: active phase and the status line only.

**Tests:** agent-system suite **289 passed** (`…/genesis/.venv/bin/python -m pytest -q agent-system/tests`). New:
`test_shell_guard.py` 13 positive + 15 bypass cases + release case; `test_routing.py` status lists four repos and reads
each repo's own branch (genesis `master`, playwright-appian `main`), real areas route five playwright-appian paths to
`browser-testing` and leave `planning/`, `node_modules/`, `dist/` unmapped, the area's gates/docs/skills, `check --repo
playwright-appian --since <rev>` routes `src/core/taxonomy.ts` to `browser-testing` with its gates, dev/review profiles
carry the four allow rules and the skill and no bare `npx apwt`. `test_installer.py`: skill count 12 → 13. The bypass
corpus was run against the previous hook: its 6 chain/substitution/write cases were already blocked, its 9
network-feed cases were not (all 9 now blocked). `genesis-ctx index` + `lint` green (L0 ~23,845 / 24,000);
`update.sh --dry-run`: preflight 3 repos, validation 5 profiles / 13 skills / 3 hooks, plan 1 added · 5 changed.
Live: `genesis-ctx status --brief` shows `playwright-appian main v0.2.0`; `check --repo playwright-appian --files
src/core/taxonomy.ts` → `browser-testing` + its two gates.

**Review:** no independent review (genesis-docs cannot spawn one). The guard change is security-relevant: a
`genesis-review` pass over this commit is recommended.

**Decisions / deviations**
- **No bare `npx apwt *` allow** (§2.3 listed it). npm's own docs (`npm help exec`): "When standard input is not a TTY
  … `--yes` is assumed", so in an agent shell `npx apwt` with no local install fetches and runs whatever package
  named `apwt` the registry serves (none on npmjs today, checked 2026-11-02). `npx --no-install apwt` resolves the
  checkout's own bin (`0.2.0` from `playwright-appian/`). The skill tells agents to use that form; a bare `npx apwt`
  stays unlisted (asked; denied in a non-interactive session).
- **Skill named `genesis-playwright-appian-dev`**, not `playwright-appian-dev`: the installer installs only
  `skills/genesis-*` (`build_desired`); renaming kept its ownership rule unchanged. Only this sub-spec used the old name.
- **Network-feed rule added to the guard** so the "pipes to a network tool" bypass case is actually refused; before
  this the guard had no network rule. A client run on its own (`curl -s http://127.0.0.1:8760/…`) and piping out of
  one stay allowed.
- Area globs: playwright-appian only (see Changed); the later sub-specs add the Genesis globs.

**Known limits / unverified**
- Not probed live: whether Kiro V3 lets the specific allow `node dist/cli/index.js *` win over the broader
  `node *` → `ask` in the same profile. If it asks, `npx --no-install apwt` is the allowed equivalent.
- The guard does not see a client that reads a file by name (`curl -d @/tmp/x https://…`) or a network call made by a
  script/test file; the permission layer (curl is not allow-listed) is the backstop there.
- `npx playwright …` outside an installed project would also auto-install `playwright` from the registry (the real
  package; low risk, version drift only).
- L0 headroom is ~155 tokens: four ADR digest lines (ADR-081..084, 51-13) will not fit without a compression
  (proposal to the user, not applied).

**Lesson candidates:** `npx <bin>` in a non-TTY agent shell auto-installs a missing package (`--yes` assumed): allow
only `npx --no-install <bin>` for internal tools (a dependency-confusion path like ADR-080's PyPI case).

**Code-map changes:** none in Genesis code; agent-system only (record in the Phase 51 write-back).
