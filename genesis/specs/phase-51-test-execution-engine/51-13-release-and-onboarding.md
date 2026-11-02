# 51-13 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: playwright-appian, genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-51-test-execution-engine.md`. After 51-12 = SHIP. **genesis-release** asks before every tag and push;
> then **genesis-docs** does the write-back.

## 1. Release order

1. **playwright-appian** (only if it changed in this phase): bump `package.json` to the new version (semver; below 1.0
   a minor may break, its D-36); its gates; tag `vX.Y.Z` equal to the version; push on the user's go-ahead; its tag
   pipeline publishes to the GitLab registry (its D-38); verify the published tarball. Never publish by hand; never read
   CI variables (L-100).
2. **Vendor** that exact tarball into `genesis/genesis/testexec/vendor/`, update `VENDORED_APWT_VERSION` + sha256, and
   the workspace template; re-run the genesis tests that use it.
3. **genesis v0.81.0** (minor; m0026, DB 25 → 26): version in `pyproject.toml`, `create_app`, `web/src/version.ts`;
   `npm run build` + commit `web/static/` as separate steps (L-089); verify the release commit contains every changed
   file, including the vendored tarball as package data (L-056, L-048); tag; push on go-ahead; CI green (genesis,
   frontend, clean-install).
4. **genesis-workflows v0.25.0**: `test-execution`, `action-capture`, `story-verification` (each v0.1.0) + `registry.json`
   entries + skill `genesis-test-authoring` in `skills-registry.json`; pins on `genesis.git@v0.81.0` (+
   `#subdirectory=packages/<name>`, gate 9, L-057); CI green.

## 2. Deploy

Never restart while a run is active. Fleet update as usual (`gsm provision --all --no-mcp --no-env --force`, `gsm
restart --all`); `genesis install test-execution action-capture story-verification` on each instance; verify
`/openapi.json` `info.version` = 0.81.0 and DB v26. The `userb` instance keeps reading `environments.json` through the
`is_dev` mirror (51-05 §5). Node ≥ 20 and Chromium are per machine: note them in the user's checklist.

## 3. Docs write-back (genesis-docs)

- **ADRs:** add ADR-081..084 from `adr-drafts.md` (51-04 §6) via `genesis-ctx add adr` with `--amends` (ADR-078 /
  ADR-068 / ADR-029 / ADR-061) and areas (`browser-testing` + the relevant existing areas); an ADR-047 note for the
  per-app cadence inside `regression-run`'s options (51-06 §8).
- **Areas:** extend `browser-testing` (51-02) with every new path; map `genesis/genesis/testexec/**`,
  `api/testing.py`, `integrations/apwt/**`, `chat/story_verification_finalizer.py`,
  `web/src/features/testing/**`, the three workflows and the skill `genesis-test-authoring`
  to their areas so `check` routes them.
- `context/state/current.md` (versions incl. `playwright-appian`, DB v26, test counts, "what works": Testing tab,
  environment types, Verification lane, lane order), code map, `progress/phase-51-test-execution-engine.md`,
  `changelog.md`, README row 51 → SHIPPED, tracker §6, `bible/08` §9 pointer to the new
  `specs/backlog/phase-51-follow-ups.md` (Deferred list from the umbrella §9 + anything found in the build), lessons via
  `genesis-ctx add lesson`. `genesis-ctx index && lint` green.

## Context manifest

```toml
areas    = ["release-ci", "distribution", "workflows-library"]
adrs     = ["ADR-019", "ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-030", "L-033", "L-048", "L-056", "L-057", "L-089", "L-098", "L-099", "L-100"]
docs     = ["tracker:specs/phase-51-test-execution-engine.md", "tracker:agent-system/skills/genesis-release/SKILL.md", "tracker:agent-system/skills/genesis-doc-writeback/SKILL.md"]
code     = ["genesis/pyproject.toml", "genesis/genesis/testexec/vendor/**", "genesis-workflows/registry.json", "genesis-workflows/skills-registry.json", "playwright-appian/package.json"]
upstream = ["51-12"]
```
