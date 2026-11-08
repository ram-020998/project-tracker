# 51-13 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: playwright-appian, genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-51-test-execution-engine.md`. After 51-12 **code-level** SHIP (Re-run 2) **and** 51-12 parts 2–3 green
> (installs, restarts, the step-24 isolation and step-20 width probes) — **D38**: the release precedes live acceptance;
> 51-12 live steps 1–27 run on the released v0.81.0 and any finding ships as a v0.81.x patch. **genesis-release** asks
> before every tag and push; then **genesis-docs** does the write-back.

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
  environment types, Verification lane, lane order; **and, under Known open items, that Phase 51 live acceptance —
  51-12 steps 1–27 on QA — is still open (D38)**), code map, `progress/phase-51-test-execution-engine.md`,
  `changelog.md` (the v0.81.0 entry says live acceptance is open), README row 51 → **SHIPPED (live acceptance open)**
  until 51-12 passes, then SHIPPED, tracker §6, `bible/08` §9 pointer to the new
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

## As built — Linux reap fix before the push (genesis-dev, 2026-11-08)

There is no **As run** yet. This fix comes first: genesis CI pipeline #7335323 failed the genesis job with 10 tests, all
process-group reaping (`test_apwt_client` open ×2, `test_testexec_procs` reap, `test_testexec_recording` refresh/reap,
`test_testing_api` cancel / startup reap / replay cancel, `test_runs` run-end reap ×3). The base is the release commit
`8e5bacc`. Its local tag `v0.81.0` was not touched.

- **Cause.** `procs._group_commands` ran `ps -A -o pgid=,command=`. procps-ng (4.0.4 in `python:3.13`) cuts each line
  to `$COLUMNS` even when the output is piped, and the CI runner sets `COLUMNS`. The workspace and run markers at the
  end of long command lines were therefore cut off, so `reap()` found no process of ours, signalled nothing and dropped
  the record. A `ps` error was swallowed into `[]`. macOS BSD `ps` does not truncate (8,460-character lines with
  `COLUMNS=80`), which is why the gates were green locally.
- **Fix.** On Linux, full command lines are read from `/proc/<pid>/cmdline`, with the group taken from
  `/proc/<pid>/stat` after the last `)`. Elsewhere, and when procfs is empty or unreadable, the fallback is
  `ps -A -ww -o pgid=,command=`. A `ps` that cannot run, or that exits non-zero, now logs a warning. `reap()` itself
  is unchanged, so a group is still signalled only while one of its processes names a recorded marker.
- **Commits (genesis, local, not pushed or tagged):** `2e92fca` (the fix and its regression tests) and `62537c2`
  (review m1/m2/n3/n5).
- **Tests.** In `tests/test_testexec_procs.py`, five new tests (6 with parametrization):
  - a marker past column 80 under `COLUMNS=80`;
  - the `ps` fallback reads full lines (`-ww`);
  - a `ps` failure is logged with the exact text (2 cases);
  - a fake procfs (comm with spaces and parens, empty cmdline, garbage stat, vanished entry);
  - an empty or missing procfs falls back to `ps`.
- **Test runs:**
  - **Docker `python:3.13`, `COLUMNS=80`, base `procs.py`:** 11 failed, 5 passed (the 10 CI failures plus the
    regression test).
  - **Same container, `62537c2`:** 21 passed. The tests were the 10 CI failures plus the whole procs file. `2e92fca`
    also passed without `COLUMNS`.
  - **How the container was set up:** a venv built from the dev venv's exact `pip freeze`, without PyMuPDF (it OOMs
    the container). The full suite was not run in Linux.
  - **macOS:** `ruff check genesis` + the test file are clean. Full `pytest` at `2e92fca`: **1836 passed,
    1 deselected** (`test_config.py::test_server_readiness_probe`, the known hang). At `62537c2`: the procs file
    (12) and the 21 reap tests with `COLUMNS=80` passed.
- **Review.** `reviews/51-13-reap-fix-review.md`: **SHIP** on `2e92fca`, with no blocker or major finding.
  - Fixed in `62537c2`: m1 (procfs parser test), m2 (empty procfs returns `None`), n3 (exact log text) and n5
    (docstring).
  - Left as is: n4 (a broken `ps` warns once per record per reap; this happens only off Linux and only on failure).
  - `62537c2` was not re-reviewed.
- **Decisions.** No ADR deviation.
- **Lesson candidate.** procps `ps` honours `$COLUMNS` even when piped. Any check that matches text at the end of a
  command line must read `/proc/<pid>/cmdline` or pass `-ww`. A tool failure that turns into an empty list must log
  first, because an empty list reads as "nothing to do".
- **Code-map changes.** `genesis/testexec/procs.py` gains `_PROC_ROOT`, `_cmdlines_from_proc(pgid, root=None)` and
  `_cmdlines_from_ps(pgid)`. `_group_commands` keeps its signature.
- **For genesis-release.** `v0.81.0` (local) points at `8e5bacc`, which does not have the fix. Ask the user whether to
  move the unpushed tag to `62537c2` or to cut v0.81.1. Then confirm a green genesis pipeline on the tagged commit
  before pushing.

## As built — genesis-workflows test without Node (genesis-dev, 2026-11-02)

There is still no **As run** section, so this note sits beside the reap fix above. genesis-workflows master pipeline
#7336032, job `workflow-tests`, had 1 failed and 427 passed. Base: `b295394`, the pushed v0.25.0 release commit.

- **Cause.** The failing test was `action-capture` `test_scan_refs_reports_why_it_cannot_run`. Its first assertion
  expected "no lib/scan-refs.mjs" while node was whatever the host had. The CI image `python:3.13` has no Node, and
  `scan_refs` (`graph.py:466-470`) correctly checks node first, so it raised "node is not installed". On a machine
  with Node the test passed.
- **Fix (test only; `graph.py` and all versions unchanged).** The test now takes PATH from its own folders, never the
  host's:
  - PATH = an empty folder → "node is not installed".
  - PATH = the fake `bin/node` plus that empty folder → "no lib/scan-refs.mjs".
  - Then `lib/scan-refs.mjs` is added → "no JSON document".
- **Commits (genesis-workflows, local, not pushed or tagged):** `60dde75` (the fix) and `6a7d432` (review nits).
- **Other host-tool assumptions.** The grep found none in the workflow tests:
  - Every `npx` and `node` is a fake bin on a temporary PATH.
  - story-verification reads roles from the recorded scan.
  - No test calls git or ps directly.
  - Genesis helpers the tests reach use git (present in the image) and, on Linux, `/proc` before `ps` (present).
- **Docker run.** `python:3.13` with no node, npm or npx. Script: `.reap-repro/ci-wf.sh`, outside the repos.
  - **Steps:** the CI `before_script`'s `ci/check_internal_pins.py`; the four internal pins exactly as
    `pyproject.toml` lists them (`genesis.git@v0.81.0`, rewritten to the local genesis checkout, where `v0.81.0`
    peels to `62537c2` as on the remote); this repo editable; then the three CI job commands.
  - **Difference from CI:** CI's one-pass `pip install -e ".[dev]"` is OOM-killed in this Docker VM. The
    third-party packages come from the genesis dev venv's exact freeze instead, without PyMuPDF.
  - **At `6a7d432`:** internal pins PASSED, `validate_library` PASSED (18), `validate_skills` PASSED (4),
    workflow-tests **428 passed**.
  - **With the `b295394` test file:** 1 failed, 427 passed, with the pipeline's exact message.
- **macOS.** `validate_library` PASSED (18), `validate_skills` PASSED (4), workflow pytest 428 passed (at
  `6a7d432`); `ruff check workflows/action-capture` clean. One run of the action-capture file had 1 failure among 54
  before I recorded its name. 14 repeats then passed 54/54, so it is unidentified and probably load-related.
- **Review.** `reviews/51-13-workflows-node-test-review.md`: **SHIP** on `60dde75`, with no blocker, major or minor.
  Both nits were fixed in `6a7d432`, which was not re-reviewed. The reviewer also ran the suite on macOS with node
  removed from PATH: 428 passed.
- **For genesis-release.** Push `6a7d432`. A new genesis-workflows tag is your call: no workflow or version changed,
  only a test.

## As run (2026-11-08, genesis-release)

**Phase 51 live acceptance is still open (D38).** 51-12 live steps 1–27 on QA have not run. They run on the released
v0.81.0 when QA is back, and anything they find ships as a v0.81.x patch. 51-12 stays open until they pass.

Every tag and every push below was asked for and confirmed by the user, one at a time.

### Versions

| Repo | Version | Tag | Tagged commit |
|---|---|---|---|
| playwright-appian | 0.3.0 | `v0.3.0` | `d3ed993` (`release: 0.3.0`) |
| genesis | 0.81.0 (the app and the three packages; `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged; m0026–m0028, DB v28) | `v0.81.0` | `62537c2` (release commit `8e5bacc` + the reap fix `2e92fca`, `62537c2`) |
| genesis-workflows | 0.25.0 (test-execution 0.1.1, action-capture 0.2.2, setup-composer 0.1.1, story-verification 0.1.0, skill genesis-test-authoring 0.3.0) | `v0.25.0` | `6a7d432` (release commit `b295394` + the test fix `60dde75`, `6a7d432`) |

Published tarball: `https://gitlab.appian-stratus.com/api/v4/projects/13864/packages/npm/playwright-appian/-/playwright-appian-0.3.0.tgz`
(744,734 bytes; sha256 `9ba92b932d14a5dfb5390de9af27f885667b257fdb3274b49d98b35addab41e4`; registry `dist.shasum`
`375e3205f1b1d31d238a774e695afaed43bd417a`, equal to the downloaded file's SHA-1).

### CI pipelines

| Repo | Pipeline | Ref / sha | Result |
|---|---|---|---|
| playwright-appian | #7335244 | `main` `d3ed993` | green: lint, build, unit, install-smoke (`live-e2e` manual, not run) |
| playwright-appian | #7335271 | tag `v0.3.0` | green: lint, build, unit (coverage 98.57 %), install-smoke, **publish** (job 82599625), **verify-published** (job 82599626) |
| genesis | #7335323 | `master` `8e5bacc` | **red**: `genesis` job 10 failed / 1762 passed / 61 skipped (Linux reap, see below); genesis-core, kiro-agent-sdk, genesis-appian-parser, frontend, clean-install green |
| genesis | #7335941 | `master` `62537c2` | green: genesis (1778 passed, 61 skipped), genesis-core, kiro-agent-sdk, genesis-appian-parser (frontend and clean-install not triggered by their `changes` rules) |
| genesis | #7335975 | tag `v0.81.0` (`62537c2`) | green: all six jobs (genesis, genesis-core, kiro-agent-sdk, genesis-appian-parser, frontend, clean-install) |
| genesis-workflows | #7336032 | `master` `b295394` | **red**: workflow-tests 1 failed / 427 passed (`test_scan_refs_reports_why_it_cannot_run`, no Node in `python:3.13`); library-validate and skills-validate green, so the v0.81.0 pins resolved (pip checked out `77f88542`, the `v0.81.0` tag object) |
| genesis-workflows | #7336147 | `master` `6a7d432` | green: library-validate, skills-validate, workflow-tests |
| genesis-workflows | #7336158 | tag `v0.25.0` (`6a7d432`) | green |

### What happened, in order

1. **playwright-appian.** `package.json`, the lockfile and `src/core/version.ts` were already 0.3.0 at `f00cebb`.
   `d3ed993` moved the CHANGELOG `[Unreleased]` notes under `[0.3.0] - 2026-11-08`, changed the README tarball URL
   to 0.3.0, and updated the `planning/TRACKER.md` handoff and log row. The user's uncommitted `.gitignore` line
   (`playwright-appian.code-workspace`) was kept out and is still uncommitted.
   - Gates, 14:18–14:25 IST, load average 3.5–4.9: `prettier --check`, build, typecheck and lint are clean; `npm test`
     1399/1399; `npm run coverage` 1399/1399; `npm run smoke:install` PASS.
   - **Live `npm run e2e` was skipped by the user's decision** (QA/Dev down; 0.3.0's feature was checked in the
     51-03 spike, and the commits since are test timeouts only).
   - The first `git push` timed out on SSH port 22 (VPN down). The retry after the user restored the VPN worked.
   - Published-tarball check: `npm run smoke:install -- --tarball <URL>` RESULT PASS (`apwt --version` 0.3.0).
2. **Vendor.** `genesis/testexec/vendor/playwright-appian-0.3.0.tgz` is now the published tarball, byte for byte. It
   replaces the 51-05 pre-release pack from `5d7ae2d`: same version, and no change under `src`, `scripts` or
   `package*.json` between `5d7ae2d` and `d3ed993`. `vendor.py`: `VENDORED_APWT_SHA256 = 9ba92b93…`,
   `VENDORED_APWT_SOURCE_COMMIT = "d3ed993"`, and the docstring now names the registry. The workspace template uses
   placeholders, so it needed no change. 13 test files that use the tarball: **312 passed, 0 skipped**.
3. **genesis v0.81.0.**
   - **Release commit `8e5bacc`.** The version moved to 0.81.0 in the root and the three `packages/*/pyproject.toml`,
     the parser `__version__`, `create_app` and `web/src/version.ts`. The README now says "m0001–m0028 (DB v28)", and
     its status heading reads "v0.81.0 … live acceptance open". The commit also holds the vendored tarball and the
     rebuilt `web/static`. Ten source files are in it (L-056).
   - **Package data (L-048).** A wheel built from the tree has `genesis/testexec/vendor/playwright-appian-0.3.0.tgz`
     (744,734 bytes), the six `testexec/templates/*` files and `web_static/index.html`.
   - **Gates, 15:08–15:25 IST** (outside 00:00–02:00):
     - app pytest: 1832 passed, 1 deselected (`test_config.py::test_server_readiness_probe`, which hangs when Docker
       is installed);
     - `test_version_sync` 6 passed; genesis-core 96; kiro-agent-sdk 79; parser all passed, 1 skipped;
     - the four CI ruff commands: clean;
     - web: lint 0 errors (the 20 known warnings), typecheck clean, vitest 726 passed (62 files);
     - `npm run build`, commit, then a fresh build and an empty `git status --short --untracked-files=all` in its own
       call.
   - **Red `master` #7335323.** All of Phase 51 had stayed local, and the `backup/phase-51-*` pipelines are skipped,
     so this was the first CI run of the Phase 51 code. On Linux, procps `ps` cut command lines to `$COLUMNS` and
     dropped the reap markers, so `reap()` killed nothing.
   - **The fix.** genesis-dev fixed it in `2e92fca` + `62537c2` (see "As built — Linux reap fix" above; review SHIP).
     I re-ran ruff and the five affected test files plus `test_version_sync` on `62537c2`: 145 passed.
   - **Re-tag.** The local `v0.81.0` (tag object `50a1e77` on `8e5bacc`, never pushed; `git ls-remote` empty) was
     deleted and re-created on `62537c2` at the user's choice. `master` #7335941 was green, then the tag was pushed
     (#7335975 green).
4. **genesis-workflows v0.25.0.**
   - **Release commit `b295394`.** `pyproject.toml` is version 0.25.0, and all four internal pins are on
     `genesis.git@v0.81.0` (`genesis-core`, `kiro-agent-sdk`, dev `genesis-appian-parser` with
     `#subdirectory=packages/<name>`, dev `genesis` without it; L-057). `registry.json` has `genesis_core_version`
     0.81.0, and `genesis_core_major` stays 1. The four workflow versions and the skill 0.3.0 were already in
     `workflow.yaml`, `META`, `registry.json` and `skills-registry.json`.
   - **Gates:** gate 9 PASSED; `validate_library` PASSED (18); `validate_skills` PASSED (4); `pytest workflows` 428
     passed; ruff on the four testing workflows and `ci` clean.
   - **Red `master` #7336032.** One test assumed Node on the runner. The user fixed it in `60dde75` + `6a7d432` (test
     only; review SHIP). I re-ran it on `6a7d432` with `PATH=/usr/bin:/bin` (no node): it passed. The other gates
     were unchanged and green.
   - Then `master` #7336147 went green, the tag `v0.25.0` was created on `6a7d432`, and #7336158 went green.
5. **Deploy (user's go-ahead), 21:53–21:55 IST.**
   - **Before:** both instances healthy, 0 running runs, DB v28 with nothing pending (memory.db v1), `/openapi.json`
     0.80.0 (`346f885` code since the 51-12 Part 2 restarts).
     - main had all four workflows and the skill as a `local` copy, identical to the release apart from
       `.genesis-source.json`.
     - userb had no story-verification and no skill.
     - **This differs from §2:** userb was already on DB v28, not v25. The reviewer's Part 2 restarts migrated it.
       genesis-docs should record the real state.
   - **Backups** (`/tmp/genesis-release-51-13/backup/`; SQLite online backup from a read-only source;
     `/tmp/genesis-release-51-13/backup.py`):
     - `main-20261108-215339.genesis.db`: integrity ok, v28, 428 runs, 0 non-terminal, plus the lockfile and the
       skill folder;
     - `userb-20261108-215345.genesis.db`: integrity ok, v28, 119 runs, 0 non-terminal, plus the lockfile.
   - `gsm provision --all --no-mcp --no-env --force`: 18 workflows on each instance from the checkout at `6a7d432`
     (ref `local`), including test-execution 0.1.1, action-capture 0.2.2, setup-composer 0.1.1 and story-verification
     0.1.0 (now on userb too).
   - `POST /api/skills/install {"id":"genesis-test-authoring","ref":"v0.25.0"}` on :8760 and on :8761: both answered
     version 0.3.0, ref v0.25.0. `/api/skills` lists it as `library` on both.
   - Run check: 0 running on both. Then `gsm restart --all`: main pid 30385 → **28431**, userb 30749 → **28463**;
     `gsm status` healthy.
   - **After:**
     - `/openapi.json` `info.version` is **0.81.0** on both;
     - `gsm exec <name> -- db status` shows schema **v28**, nothing pending, on both;
     - `/api/workflows/<id>` returns 0.1.1 / 0.2.2 / 0.1.1 / 0.1.0 on both;
     - reports listeners on :8860 (28431) and :8861 (28463);
     - the `…/test-cases/{case_key}/script` route is present;
     - 0 `Traceback`/`ERROR` lines in either log since the restart.

### Deferred / follow-ups

- **Live acceptance (D38):** 51-12 steps 1–27 on QA, on v0.81.0. The step-24 report-isolation probe on userb needs an
  execution there (P-O1).
- **Backlog, by the user's decision (2026-11-08):** 51-12 Parts 2–3 P1 (the step-20 width probe has no compose dialog
  or picker) and P2 (picker layout: `contracting-officer` breaks mid-word, the "Data setup" badge wraps, the search
  placeholder is clipped), plus nit N1 (the case-script page's hint when the scanner cannot run; D38, backlog §23).
- **playwright-appian:** the live `npm run e2e` was not run for 0.3.0 (user's decision). Its `planning/` phase record
  (BIBLE §10.5 step 6) only has the tracker row and handoff; the pipeline ids are here.
- **Existing test workspaces keep the pre-release 0.3.0 tarball** (same version, same code, different sha).
  "Update testing runtime" compares only the version, so it does not offer an update. This is harmless; note it if a
  later check compares the workspace copy's sha.
- **Fixture provenance:** `tests/fixtures/apwt/apwt-0.3.0-*.json` `_source` still says "packed from commit `5d7ae2d`",
  which is true of when they were recorded; the CLI is unchanged.
- **Ruff outside CI:** `ruff check genesis tests` (genesis) and `ruff check workflows` (genesis-workflows) report
  pre-existing errors in test files and older workflows. CI does not run those commands.
- **For genesis-docs:**
  - `context/state/current.md`: playwright-appian v0.3.0, genesis v0.81.0, genesis-workflows v0.25.0, DB v28; fleet
    on v0.81.0 / DB v28 with the four workflows and the skill on both; test counts (app 1832 local / 1778 + 61 skipped
    in CI, web 726, workflows 428); live acceptance open.
  - The user's checklist: Node ≥ 20 and Chromium per machine.
- **Process (L-089 recurrences in this session; every outcome was re-verified alone and was correct):**
  - `git tag` + `rev-list` (playwright-appian and genesis `v0.81.0` ×2);
  - `mkdir` + `npm pack` (the pack failed and was redone);
  - `cp` + `shasum`;
  - build + `git status` (twice; the status was redone alone);
  - `git add` + `git status`;
  - `git add` + `git commit` (genesis-workflows);
  - tag delete + `ls-remote` + re-tag;
  - push + `ci list` (twice).

  Also, `sleep` calls sent in one batch with a status read did not wait before the read; `date && sleep && date` in
  one call did.
- **Lesson candidates:**
  - Phase work that stays local until the release meets CI for the first time at the tag. Phase 51's 44 genesis and
    9 genesis-workflows commits held two Linux-only test failures, and the `backup/*` branch pipelines are skipped.
    Push to a CI-run branch during the phase, or run the package jobs in a Linux container before the release.
  - `glab ci get` showed a pipeline as running for minutes after its jobs had ended (#7335323). Read the job traces
    (`glab ci trace <job> -b <ref>`) before deciding that a pipeline is stuck.
