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
3. **genesis v0.81.0** (minor; m0026–m0028, DB 25 → 28): version in `pyproject.toml`, `create_app`, `web/src/version.ts`;
   the genesis `README.md` DB line (still "m0001–m0024 (DB v24)"; it becomes m0001–m0028, DB v28; 51-12 re-run R-O2);
   `npm run build` + commit `web/static/` as separate steps (L-089); verify the release commit contains every changed
   file, including the vendored tarball as package data (L-056, L-048); tag; push on go-ahead; CI green (genesis,
   frontend, clean-install).
4. **genesis-workflows v0.25.0**: `story-verification` (v0.1.0), `test-execution` (v0.1.1), `setup-composer` (v0.1.1) and `action-capture` (v0.2.2) — the 51-18 versions, released together with genesis v0.81.0 (Record needs `action-capture` ≥ 0.2.2 and Compose `setup-composer` ≥ 0.1.1) + `registry.json`
   entries + skill `genesis-test-authoring` in `skills-registry.json`; pins on `genesis.git@v0.81.0` (+
   `#subdirectory=packages/<name>`, gate 9, L-057); CI green. The pin move is **required**, not only tidy: since 51-07
   the genesis-workflows tests import Phase 51 genesis modules (`testexec`, `integrations/apwt`), so a pin on v0.80.0
   reds CI. Since 51-18 it is also a **behaviour** dependency: with the old pin the story-verification tests fail
   (no scanner-recording helper, no checkout check) and the two capture workflows refuse every replay.
5. **Release gate conditions (51-18 As built):** run the playwright-appian and genesis gates on a machine that is not
   heavily loaded (one agent-idle timing test failed once at load average ~25). Two known local test issues are not
   regressions: `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` fails between 00:00 and 02:00 IST
   (a time-of-day flake, pre-existing; run the gate outside that window or fix the test first), and
   `test_config.py::test_server_readiness_probe` hangs on a machine with Docker installed (pre-existing). Keep the
   user's uncommitted playwright-appian `.gitignore` line out of the release commit unless the user says otherwise.

## 2. Deploy

Never restart while a run is active. Back up each instance's `genesis.db` before the restart (DB 27 → 28, or 25 → 28 on
userb). Fleet update as usual (`gsm provision --all --no-mcp --no-env --force`, `gsm
restart --all`); `genesis install test-execution action-capture story-verification setup-composer` and the `genesis-test-authoring` skill (0.3.0, from 51-17) install on
each instance (recording refuses to start without both the skill and `action-capture`, 51-07 As built 8); verify
`/openapi.json` `info.version` = 0.81.0 and DB v28. **Fleet state before the release (51-12 review O1):** the main instance has been running
Phase 51 code from the editable dev venv, on DB v27, since 2026-11-04 (its `/openapi.json` still says 0.80.0); userb
runs pre-Phase-51 code on DB v25. `context/state/current.md` does not say so; record the real state in the release's
As run and let genesis-docs correct it. The `userb` instance keeps reading `environments.json` through the
`is_dev` mirror (51-05 §5). Node ≥ 20 and Chromium are per machine: note them in the user's checklist.

## 3. Docs write-back (genesis-docs)

- **ADRs:** add ADR-081..084 from `adr-drafts.md` (51-04 §6) via `genesis-ctx add adr` with `--amends` (ADR-078 /
  ADR-068 + ADR-021 / ADR-029 / ADR-061; D22) and areas (`browser-testing` + the relevant existing areas). **Also
  (51-12 re-run R-m6):** D26's reports origin is a backend surface outside ADR-028's "all endpoints under `/api`":
  amend ADR-028 with its scope and rules (static report files only, no `/api`, its own loopback port) and note it in
  ADR-026's network surface; an ADR-047 note for the
  per-app cadence inside `regression-run`'s options (51-06 §8).
- **Areas:** extend `browser-testing` (51-02) with every new path; map `genesis/genesis/testexec/**`, `genesis/genesis/testing/**`,
  `api/testing.py`, `integrations/apwt/**`, `chat/story_verification_finalizer.py`,
  `web/src/features/testing/**`, the four workflows and the skill `genesis-test-authoring`
  to their areas so `check` routes them.
- `context/state/current.md` (versions incl. `playwright-appian`, DB v28, test counts, "what works": Testing tab,
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
