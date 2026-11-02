---
name: genesis-playwright-appian-dev
description: Use when changing the playwright-appian repo (apwt, Genesis's browser-test tool) — where things are, its gates and e2e suites, how a decision is recorded, version rules and the invariants never to weaken. For the genesis-dev and genesis-review agents (area browser-testing).
---

# playwright-appian development

`{{REPOS}}/playwright-appian` is Genesis's browser-test tool (`apwt`): its own repo (branch `main`), its own semver,
published by its CI to the GitLab npm registry of project 13864. It is NOT part of the genesis monorepo (51-01 D19).
Its `planning/` is the home of its internal design: `BIBLE.md` (rules; wins on conflict), `DECISIONS.md` (the
`D-NN` ids), `TRACKER.md`, `AGENT-ONBOARDING.md` §4 (repository map). Read them in ranges. Genesis specs cite its
D-ids; Genesis ADRs cover only how Genesis uses it.

## Where things are
- `src/core/` (browser-safe; `taxonomy.ts` = all Appian element knowledge, `trace-schema.ts` + `types.ts` = the
  trace contract, `version.ts` = `VERSION`, `PLAYWRIGHT_VERSION`, `tarballUrl()`), `src/components/` (the label-based
  component library), `src/recorder/`, `src/generator/` (trace → spec), `src/agent/` (agent sessions, in-process API
  `playwright-appian/agent`), `src/cli/` (`apwt`; built to `dist/cli/index.js`).
- `skills/playwright-appian/SKILL.md` — the CLI skill that workflow agents use. `tests/` (vitest; `tests/invariants/`
  guards architecture, taxonomy-only, dual build, package metadata and CI config; `tests/e2e/` needs a live site).

## Gates (`{{GENESIS_HOME}}/bin/genesis-ctx check --repo playwright-appian --since <rev>` lists them)
- `npm run lint && npm run typecheck && npm test` from the repo root. Tests under `tests/cli`, `tests/package` and
  some invariants run the built `dist/`: run `npm run build` first after a source change (BIBLE §10.1).
- Run the CLI from the checkout as `npx --no-install apwt …` or `node dist/cli/index.js …`. Never a bare
  `npx apwt`: in a non-TTY shell npx assumes `--yes` and installs a missing `apwt` from the registry.
- `npm run e2e*` drives a live Appian site with real credentials: run it only when the sub-spec says so; otherwise
  run the unit and real-browser tests (`npm test`) and say the live loop was not run.

## Recording a decision
Append a row to `planning/DECISIONS.md` in its house format (`| D-NNN | Decision | Who, when | Why | Enforced /
documented |`, next free id, in the right section); a changed decision gets a new row that supersedes the old one
(say so in both) and the BIBLE is updated in the same change. Ask the user before changing a **User** decision.
Cite the D-id from the Genesis sub-spec's **As built**.

## Versions
Semver below 1.0: a minor may break the API (D-36). The version lives in `package.json` and `src/core/version.ts`
(`package-meta.test.ts` ties them). `playwright`, `@playwright/test` and the CI image share one exact Playwright
version (BIBLE §10.4). Releases are genesis-release's job (genesis-release skill).

## Invariants — never weaken one without the user
- No LLM inside the framework; what it cannot decide is an explicit `// TODO` (D-02).
- Appian element knowledge only in `src/core/taxonomy.ts` (D-05).
- Generated code is label-only: `appian.<factory>('<label>')…`, never raw locators (D-04).
- One npm package with subpath exports and one bin (D-01).
- The trace schema `playwright_appian.trace.v1` is additive-only within v1 (`src/core/trace-schema.ts`, BIBLE §1.5):
  removing, renaming or re-meaning a field is a v2.
- Exact dependency pins; publish only to this project's registry (`package-meta.test.ts`).

## Git
Commit locally with explicit paths (never `git add .`); never push or tag (genesis-release does, asking first).
Agents never call the CI-variables API (L-100).
