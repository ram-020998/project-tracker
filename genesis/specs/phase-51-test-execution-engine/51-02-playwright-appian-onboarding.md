# 51-02 — `playwright-appian` joins the Genesis agent system

> **Status:** SPEC-DRAFTED 2026-11-02. Repo: **project-tracker** (`genesis/agent-system/`, `genesis/context/`). Built by
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
