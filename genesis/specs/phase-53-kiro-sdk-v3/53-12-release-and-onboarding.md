# 53-12 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-11-03. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-53-kiro-sdk-v3.md`. After 53-11 = SHIP. **genesis-release** asks before every tag and push; then
> **genesis-docs** does the write-back.

## 1. Release order (after Phase 51's release, D11)

0. **playwright-appian 0.3.1** first (D14; built in 53-06): CI green; tag `v0.3.1`; publish to the GitLab npm registry
   of project 13864 and verify the published tarball (the Phase 51 51-13 procedure); all on the user's go-ahead. Then
   re-vendor **the published tarball byte for byte** into genesis: `genesis/testexec/vendor/playwright-appian-0.3.1.tgz`
   replaces 0.3.0, `VENDORED_APWT_VERSION = "0.3.1"` and the provenance docstring in `genesis/testexec/vendor.py:7-16`
   (tag, commit, sha256). This goes into the genesis release commit of step 1 (L-056: verify the commit contains it).
1. **genesis** next minor after Phase 51's (Phase 51 shipped v0.81.0; expected **v0.82.0**, after any v0.81.x patches from Phase 51's open live acceptance; 53-03's migration `m0029`, DB v28 → v29): version in
   `pyproject.toml` files of the app and the three packages (one shared version, ADR-080), `create_app`,
   `web/src/version.ts`; `npm run build` + commit `web/static/` as separate steps (L-089); verify the release commit has
   every changed file, including `tool_ids.json` and the v3 fixtures as package/test data (L-056, L-048); tag; push on
   the user's go-ahead; CI green (packages, genesis, frontend, clean-install). **Before the release commit (L-112):**
   run the SDK suite once in the `python:3.13` image or on a CI branch run (not yet run: 53-04 As built; the Linux
   `/proc` reader is otherwise covered only by a fake-procfs test). `test_regression_job_handler_starts_due_apps_and_skips_busy_ones`
   reads the real date and can fail on some days (phase-51 backlog, 51-13 §1.5); a red result there is that known
   issue, not a Phase 53 regression, and needs the user's call before tagging. **D27:** it fails whenever the real time
   is 00:00–02:00 IST, so tag, push and re-run CI only outside **18:30–20:30 UTC**; if a run lands in that window and
   goes red on that test alone, re-run it outside the window rather than treating it as a regression. The python:3.13
   image check ran in 53-11 (four failures identical on v0.81.0; the amd64 release CI decides).
2. **genesis-workflows** next minor (expected **v0.26.0**; Phase 51 shipped v0.25.0): the `appian` skill (53-06) + its `skills-registry.json` entry; pins on the new genesis tag
   (`#subdirectory=packages/<name>`, gate 9, L-057); CI green.
3. Never read CI variables through the API (L-100).
4. If any 53-11 live check could not run, the release notes, README row and state say so plainly (L-111). **By D24
   and D26, only 4 of the 15 agent-node workflows are live-accepted on v3 before the release** (53-11 §5 lists the
   rest); say which, and that findings ship as patches.
5. **After the release (D24, D26):** when Dev is up, run 53-11 §5's Dev rows. Separately, with Phase 51's postponed
   live acceptance (D20): publish playwright-appian 0.3.1 and
   re-vendor it (step 0 above, if not already done), run Update testing runtime, then run `story-verification`,
   `action-capture` and `setup-composer` on QA on v3 (with both skills in the engine's skill list, not a canary), the
   cancelled-run `apwt` reap check, and Phase 51's 51-12 steps 1–27. Findings ship as patch releases.

## 2. Deploy

Never restart while a run is active. Fleet: `gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`;
install the `appian` skill from Settings → Catalog → Skills on each instance; run **Update testing runtime** on each
application that has a testing workspace (it brings `playwright-appian` 0.3.1; until then the Phase 51 browser workflows
fail at the start with the front-matter message, D14); verify `/openapi.json` `info.version` and
the DB version; `GET /api/system/kiro` shows a verified kiro-cli. User checklist in the release notes:

- kiro-cli at least the verified minimum (`kiro-cli update`). Verified on 2.37.1 only; on 3.x Genesis warns and runs
  (D22, `specs/backlog/kiro-cli-3x-reverify.md`).
- Global Kiro MCP servers (`~/.kiro/settings/mcp.json`) and personal skills (`~/.kiro/skills`) no longer appear in
  Genesis: add a server as a custom MCP server in Settings (the custom MCP tier, ADR-029); install skills from Settings → Catalog →
  Skills.
- Existing chats continue (first resume falls back to the preamble replay once; 53-07 §2).
- API and SDK changes for anyone scripting against Genesis: `POST /chat/sessions/{id}/steer` is new and answers
  `message_seq`; `GET /skills` items lost `shadows_personal`; `GET /system/kiro` gained `version`, `minimum`,
  `verified`, `engine_v3`; `/chat/commands` lists `/clear` and `/compact` only (D21). SDK: `KiroAgentOptions` lost the
  v2 trust options and gained `trust`, `kiro_home`, `skill_dirs` and the rest of F1; `check_kiro()` returns
  `binary` and `minimum`; `TrustPolicy`, `KiroError`, `AgentNotActive`, `SessionStatus` are public.
- Applications with a testing workspace: run Update testing runtime once (`playwright-appian` 0.3.1).

## 3. Docs write-back (genesis-docs)

- **ADR-086** from `adr-drafts.md` (53-03 §2) via `genesis-ctx add adr --amends ADR-029 ADR-031 ADR-032 ADR-034 ADR-045 ADR-069 ADR-083` (one flag, the seven ids space-separated; repeating the flag keeps only the last; the filing note in `adr-drafts.md` holds the full command, with `--status accepted`)
  with areas `sdk-acp, chat, core-engine, config-secrets, security`.
- **Lessons** (candidates from As built sections; at least): v3 rejects the v2 trust flags over ACP; v3 MCP calls nest
  arguments under `rawInput.arguments` and arrive through `tool_load`; a custom agent's `tools` absent = no tools;
  verify `set_mode` activation; credits moved to `turn_completion`. Update **L-024** (sanctioned Genesis `KIRO_HOME`),
  **L-044 / L-046** (v3 methods), **L-016** (capture source) as amendments, not rewrites.
- **Architecture docs** (`genesis/docs/architecture/`, added in `7d7cd2d`, describing v0.81.0): update to the
  Phase 53 build at least `modules/kiro-agent-sdk.md` (rewritten for v3), `modules/chat-and-skills.md` (`:421-427`
  skills reach and D23 `resources`, Stop/steer/resume, the palette D21), `modules/core-engine.md` (`kiro_node` trust,
  `_node_mcp_trust`, `KIRO_HOME`), `modules/configuration-and-secrets.md` (preflight kiro-cli items),
  `modules/testing.md` (playwright-appian 0.3.1), `10-architecture-decisions.md` (ADR-086) and `glossary.md`. Grep
  the folder for `trust_tools`, `--trust`, `~/.kiro/skills`, `shadows_personal`, `_kiro.dev/` and `agent_engine`
  until nothing stale is left.
- **Areas:** map `genesis/genesis/runtime/preflight.py`, `runtime/kiro_auth.py`, `runtime/context.py` (no area today)
  and `genesis/packages/kiro-agent-sdk/tests/fixtures/**` to `sdk-acp`/`config-secrets` so `check` routes them.
- `context/state/current.md` (versions, DB version, test counts, "what works": v3 engine, Genesis Kiro homes, steering,
  resume, managed skills only; **known open items: Phase 51's live acceptance, postponed by D20, now runs on v3 with
  playwright-appian 0.3.1**; the Phase 51 umbrella and README row 51 get the same note), code map, `progress/phase-53-kiro-sdk-v3.md`, `changelog.md`, README row 53 →
  SHIPPED, tracker §6, and `specs/backlog/phase-53-follow-ups.md` (umbrella §9 Deferred list + build findings).
  `genesis-ctx index && lint` green.

## As built

_To be filled by genesis-release (As run) and genesis-docs._

## As run (2026-11-14/15, genesis-release)

**Live acceptance is only partly done (D24, D26, L-111).** Before the release, 4 of the 15 agent-node workflows were
live-accepted on v3: `hello-appian`, `generate-business-map`, `memory-consolidation` and `memory-maintenance`
(53-11 §5). The other 8 Appian workflows wait for Appian Dev. The 3 Phase 51 browser workflows (`story-verification`,
`action-capture`, `setup-composer`) and the cancelled-run `apwt` reap check wait for Phase 51's postponed live acceptance
(51-12 steps 1–27, D20). Findings ship as v0.82.x patches. Verified on kiro-cli **2.37.1 only**; on 3.x Genesis warns
and runs (D22).

Every tag and every push below was asked for and confirmed by the user, one at a time. The fleet steps were too.

### Versions

| Repo | Version | Tag | Tagged commit |
|---|---|---|---|
| playwright-appian | 0.3.1 | `v0.3.1` | `38f87fd` (`release: 0.3.1`, built in 53-06) |
| genesis | 0.82.0 (the app and the three packages; `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged; m0029, DB v29) | `v0.82.0` | `00e8078` (release commit `08f5142` + the test fix `00e8078`) |
| genesis-workflows | 0.26.0 (skill `appian` 1.0.0; no workflow version changed) | `v0.26.0` | `d0c0f53` (on `b097719`, the 53-06 `appian` skill commit) |

Published tarball: `https://gitlab.appian-stratus.com/api/v4/projects/13864/packages/npm/playwright-appian/-/playwright-appian-0.3.1.tgz`
(746,256 bytes; sha256 `1388cf9bc97b39627addc41397e18be608b619c0e39bc40749a28e00914c2155`; registry `dist.shasum`
`752c6daf5c8cdb45759ade3d8e138c59ee15abcd`, equal to the downloaded file's SHA-1; its SHA-512 equals the registry
integrity `sha512-gVbUiXhA7ZXw…bteRqZQ==`).

### CI pipelines

| Repo | Pipeline | Ref / sha | Result |
|---|---|---|---|
| playwright-appian | #7425672 | `main` `38f87fd` | green: lint, build, unit, install-smoke (`live-e2e` manual, not run) |
| playwright-appian | #7425696 | tag `v0.3.1` | green: lint, build, unit, install-smoke, **publish**, **verify-published** |
| genesis | #7425756 | `master` `08f5142` | **red**: `genesis` job 1 failed / 1883 passed / 61 skipped (`test_idle_reap_closes_the_client_and_keeps_the_record`, see below); genesis-core, kiro-agent-sdk, genesis-appian-parser, frontend, clean-install green |
| genesis | #7425785 | `master` `00e8078` | green: genesis (1884 passed, 61 skipped), genesis-core, kiro-agent-sdk, genesis-appian-parser (frontend and clean-install not triggered by their `changes` rules) |
| genesis | #7425844 | tag `v0.82.0` (`00e8078`) | green: all six jobs (genesis 1884 passed, 61 skipped) |
| genesis-workflows | #7425893 | `master` `d0c0f53` | green: library-validate, skills-validate, workflow-tests (432 passed); pip installed genesis, genesis-core, kiro-agent-sdk and genesis-appian-parser 0.82.0 from `genesis.git@v0.82.0` |
| genesis-workflows | #7425904 | tag `v0.26.0` (`d0c0f53`) | green |

### What happened, in order

0. **Preconditions.** Inputs matched: genesis `61ec063`, genesis-workflows `b097719`, playwright-appian `38f87fd`,
   project-tracker `cc16236`. `git fetch` and `git push --dry-run` worked on all three GitLab remotes, so no access
   problem this time. The session started at 19:28 UTC, inside the D27 window (18:30–20:30 UTC).
1. **playwright-appian 0.3.1.**
   - Versions were already 0.3.1 at `38f87fd` (`package.json`, lockfile, `src/core/version.ts`, CHANGELOG
     `[0.3.1] - 2026-11-11`, README tarball URL), so no new commit.
   - Gates: lint (eslint + prettier) and typecheck clean; `npm test` 1401/1402. The one failure was
     `tests/cli/agent-nav.test.ts` "goto without a URL is exit 2" (exit 1) on a loaded machine; the file alone passed
     20/20. Build clean; `npm run smoke:install` PASS.
   - **The push of `main` and the tag went out at 20:01 and 20:06 UTC, inside the D27 window, by the user's
     decision:** D27 protects one genesis test, and playwright-appian's pipeline does not run it. Everything genesis
     went out after 20:30 UTC.
   - Download: an anonymous `curl` of the tarball URL answers 404 (package reads need a token). It was fetched with
     `npm pack playwright-appian@0.3.1 --registry https://gitlab.appian-stratus.com/api/v4/projects/13864/packages/npm/`
     using the user's `~/.npmrc` token (checked by count only, never printed), then checked against `npm view` `dist.*`.
   - Published-tarball check: `npm run smoke:install -- --tarball <URL>` RESULT PASS (`apwt --version` 0.3.1).
2. **Vendor.** `genesis/testexec/vendor/playwright-appian-0.3.1.tgz` is the published file byte for byte (sha256 equal
   to the download) and replaces 0.3.0. `vendor.py`: `VENDORED_APWT_VERSION = "0.3.1"`, `VENDORED_APWT_SHA256 =
   1388cf9b…`, `VENDORED_APWT_SOURCE_COMMIT = "38f87fd"`, and the docstring names the tag, commit, sha256 and
   registry shasum. `MIN_APWT_VERSION` stays (0, 3, 0). The 14 testing test files: 333 passed and 1 failed:
   `test_start_regenerates_commits_exports_and_starts_the_run` compared `apwt_version` with the literal `"0.3.0"`.
   The user changed it to compare with `VENDORED_APWT_VERSION` (test only); then the file passed 48/48 after 20:30 UTC,
   the clock test included.
3. **genesis v0.82.0.**
   - **Release commit `08f5142`.** 0.82.0 in the root and the three `packages/*/pyproject.toml`, the parser
     `__version__`, `create_app` and `web/src/version.ts` (`test_version_sync` 6 passed). README status heading:
     "v0.82.0 (Phase 53 kiro-agent-sdk v3, 2026-11-15; live acceptance partly open)" with the caveats above; it already
     read m0001–m0029 (DB v29). The commit holds 12 source files (the 7 version sources, README, `vendor.py`, the
     tarball swap, the `test_testexec_execution.py` fix) and 63 `web/static` files (`git show --stat -- web/static`).
   - **Gates** (local, macOS):
     - app pytest 1943 passed, 2 deselected (`test_config.py::test_server_readiness_probe`, which hangs with Docker
       installed, and the D27 clock test, run alone after 20:30 UTC);
     - genesis-core 109; kiro-agent-sdk 302; parser all passed, 1 skipped; the four CI ruff commands clean;
     - web: lint 0 errors (the 20 known warnings), typecheck clean, vitest 764 passed (66 files);
     - `npm run build` → commit → a fresh build and an empty `git status --short --untracked-files=all`, each in its
       own message (L-089).
   - **Package data (L-048).** The genesis wheel built from the tree holds
     `genesis/testexec/vendor/playwright-appian-0.3.1.tgz` (746,256 bytes), `genesis/db/migrations/m0029_chat_kiro_session.py`,
     the six `testexec/templates/*` files and `web_static/index.html`; the kiro-agent-sdk wheel holds
     `kiro_agent_sdk/tool_ids.json`. The v3 fixtures (`packages/kiro-agent-sdk/tests/fixtures/v3/*`, 61 files) are tracked.
   - **Red `master` #7425756 (L-112).** The first CI run of Phase 53's code (26 commits since `62537c2`). One test:
     `tests/test_chat_manager.py::test_idle_reap_closes_the_client_and_keeps_the_record` set `last_used = 0` as
     "long idle". `reap_idle()` (`genesis/chat/manager.py:1142-1144`) closes only when `last_used < monotonic() -
     chat_idle_minutes*60` (30 min default). Linux `time.monotonic()` counts from boot, so on a runner up for less
     than 30 min the cutoff is negative and nothing is reaped; on macOS uptime is days. Not an app bug (a real
     `last_used` is a `monotonic()` reading).
   - **The fix `00e8078`** (test only, edited by the user from the agent's description, committed by genesis-release):
     `last_used = time.monotonic() - manager.settings.chat_idle_minutes * 60 - 1`. Fail-first: with `time.monotonic()`
     shifted to read 600 s (`/tmp/genesis-release-53-12/fresh_boot.py`), the `08f5142` test fails as in CI and the new
     one passes. `test_chat_manager.py` 49 passed; ruff (F, I) clean. No other test treats a fixed `monotonic()` value
     as "long ago". A new commit on top, no history rewrite (`08f5142` was already pushed). Not re-reviewed by
     genesis-review (test-only, one line, with fail-first evidence).
   - Then `master` #7425785 went green, the tag `v0.82.0` was created on `00e8078`, and #7425844 went green on all six
     jobs. The three tests that failed only on aarch64 in 53-11's image check (`test_sail_cli.py` ×2, the parser
     bundle count) passed on the x86_64 runner.
4. **genesis-workflows v0.26.0.**
   - **Release commit `d0c0f53`.** `pyproject.toml` 0.26.0; all four pins on `genesis.git@v0.82.0` (`genesis-core`,
     `kiro-agent-sdk`, dev `genesis-appian-parser` with `#subdirectory=packages/<name>`, dev `genesis` without; L-057);
     `registry.json` `genesis_core_version` 0.82.0, `genesis_core_major` stays 1. The `appian` skill 1.0.0 and its
     `skills-registry.json` entry came in with `b097719` (53-06).
   - **Gates:** gate 9 PASSED; `validate_library` PASSED (18); `validate_skills` PASSED (5); `pytest workflows` 432 passed.
   - `master` #7425893 green, tag `v0.26.0` on `d0c0f53`, #7425904 green.
5. **Deploy (user's go-ahead), 03:31–03:36 IST (22:01–22:06 UTC).**
   - **Before:** both instances healthy, 0 running runs, `/openapi.json` 0.81.0. **main was already on DB v29** (an
     earlier restart during the Phase 53 build applied m0029, D20); **userb was on v28** with m0029 pending. memory.db
     v1 on both.
   - **userb had one non-terminal run:** `r-9e903a4e5a0e`, the scheduled `memory-maintenance` at 21:30 UTC, parked at
     its escalation gate `escalate_reflect` (`awaiting_input:gate`). All three `reflect` attempts failed before any work
     with "Kiro could not load the list of models for this account … (-32000 Kiro could not load the available
     models. Please try again.)", no credits. It ran on the old 0.81.0 server with Phase 53 worker code (D20). A gated
     run has no worker and the startup sweep never touches it (`runs/manager.py:473`), so the restart went ahead; after
     it, the run is still at its gate and userb's `/api/system/kiro` shows a signed-in, verified kiro-cli. The gate was
     left for the user.
   - **Backups** (`/tmp/genesis-release-53-12/backup/`, stamp `20261115-033147`; SQLite online backup from a
     read-only source; `/tmp/genesis-release-53-12/backup.py`): main genesis.db integrity ok, v29, 466 runs, 0
     non-terminal; userb genesis.db integrity ok, v28, 137 runs, 1 non-terminal (the gated run); both memory.db ok, v1;
     plus each `installed.lock.json` and `.kiro/skills` folder.
   - `gsm provision --all --no-mcp --no-env --force`: 18 workflows on each instance from the checkout at `d0c0f53`
     (ref `local`); versions unchanged from v0.25.0.
   - Run check: 0 running on both. Then `gsm restart --all`: main pid 21722 → **56834**, userb 28280 → **56871**;
     `gsm status` healthy.
   - **After:**
     - `/openapi.json` `info.version` is **0.82.0** on both;
     - `gsm exec <name> -- db status`: schema **v29**, nothing pending, memory.db v1, on both;
     - `GET /api/system/kiro` on both: `installed`, `authenticated`, `version` 2.37.1, `minimum` 2.37.1,
       `verified: true`, `engine_v3: true`;
     - 0 `Traceback`/`ERROR` lines in either log since startup. The last ones before userb's stop were Genesis Hub
       collab pulls timing out (`HubTransportError … ReadTimeout` against `merge-assist-dev.appianpreview.com`),
       not this release.
   - **`appian` skill:** `POST /api/skills/install {"id":"appian","ref":"v0.26.0"}` on :8760 and :8761 (the API behind
     Settings → Catalog → Skills → Install): both answered version 1.0.0, ref v0.26.0. `/api/skills` lists it as
     `library` on both. Skills now: main `appian`, `appian-object-generation` (local), `gam`, `genesis-test-authoring`;
     userb `appian`, `appian-object-generation`, `gam`, `genesis-test-authoring`, `sail-mockup-generation`.
   - **Update testing runtime:** main has one testing workspace (`_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`, apwt
     0.3.0 → `update_available: true`); userb has none. `POST …/testing/workspace/update-runtime` → job `d1c54541…`
     succeeded in 10 s: workspace commits `553a7a0` "Update playwright-appian 0.3.0 → 0.3.1" and `4e8074b` (tsconfig
     from the template); `npx --no-install apwt --version` 0.3.1 in the workspace; its `SKILL.md` description is a `>-`
     block.

### Release notes (the user checklist)

- **kiro-cli:** at least 2.37.1 (`kiro-cli update`). Verified on 2.37.1 only; on 3.x Genesis warns and runs (D22,
  `specs/backlog/kiro-cli-3x-reverify.md`).
- **Live acceptance is partly open:** 4 of 15 agent-node workflows were live-accepted on v3 before the release
  (`hello-appian`, `generate-business-map`, `memory-consolidation`, `memory-maintenance`). The 8 Appian workflows wait
  for Dev, and the 3 Phase 51 browser workflows wait for Phase 51's postponed acceptance (D24, D26). Findings ship as
  patches.
- **Global `~/.kiro` MCP servers and personal skills no longer appear in Genesis.** Add a server as a custom MCP server
  in Settings (the custom tier, ADR-029); install skills from Settings → Catalog → Skills (the `appian` skill is new
  in the library).
- **Existing chats continue;** the first resume may fall back to the preamble replay once (53-07 §2).
- **Applications with a testing workspace:** run Update testing runtime once (playwright-appian 0.3.1). Until then the
  Phase 51 browser workflows fail at the start with the front-matter message (D14).
- **API and SDK changes:** `POST /chat/sessions/{id}/steer` is new and answers `message_seq`; `GET /skills` items lost
  `shadows_personal`; `GET /system/kiro` gained `version`, `minimum`, `verified`, `engine_v3`; `/chat/commands` lists
  `/clear` and `/compact` only (D21). SDK: `KiroAgentOptions` lost the v2 trust options and gained `trust`,
  `kiro_home`, `skill_dirs` and the rest of F1; `check_kiro()` returns `binary` and `minimum`; `TrustPolicy`,
  `KiroError`, `AgentNotActive`, `SessionStatus` are public.

### Deferred / follow-ups

- **Live rows after the release (53-11 §5):** A1 for the other eight workflows (`story-implementation` only with the
  user's go-ahead, ADR-068), A2's remaining modes, A8, A9(a) when Dev is up; and, with Phase 51's postponed acceptance,
  `story-verification`, `action-capture`, `setup-composer` on QA on v3, the cancelled-run `apwt` reap check, and 51-12
  steps 1–27.
- **userb gate `r-9e903a4e5a0e`** (memory-maintenance, escalation at `escalate_reflect`) waits for the user. Watch the
  next scheduled memory-maintenance on userb: if "could not load the list of models" recurs on 0.82.0, it is a v3
  finding for genesis-dev (userb's state dir has no `kiro-home/` folder; main's has one).
- **Backlog, unchanged by this release (D27):** m1 (the clock-dependent regression-job test, still unfixed: tag and CI
  outside 18:30–20:30 UTC), n1 (the MCP notice names the server twice), n2 (the too-old message repeats the version).
- **playwright-appian:** the live `npm run e2e` was not run for 0.3.1 (QA/Dev down). `agent-nav.test.ts` "goto
  without a URL is exit 2" failed once under load in a full `npm test` (passes alone): a candidate timeout like
  `f00cebb`'s.
- **Fixture provenance:** `tests/fixtures/apwt/apwt-0.3.0-*.json` were recorded on 0.3.0; 0.3.1 changes only the skill
  and `install --skills`, not the CLI output these fixtures pin.
- `scripts/probes/chat-steer-widths.mjs:83` still mocks `/api/system/update` as v0.81.0 (probe data, not a version
  source; left as is).
- **For genesis-docs:**
  - `context/state/current.md`: playwright-appian v0.3.1, genesis v0.82.0, genesis-workflows v0.26.0, DB v29
    (m0001–m0029); fleet main + userb on v0.82.0 / DB v29, 18 workflows, `appian` 1.0.0 on both, main's test workspace
    on apwt 0.3.1; test counts: app 1943 local (+ the 2 deselected) / CI 1884 passed + 61 skipped, core 109, SDK 302,
    parser all passed + 1 skipped (count not printed), web 764 (66 files), workflows 432, `validate_library` 18, `validate_skills` 5,
    playwright-appian 1402.
  - main's DB reached v29 before the release (D20); userb migrated at the release restart.
  - `genesis/docs/architecture/modules/testing.md:144` still names `playwright-appian-0.3.0.tgz` (53-12 §3 lists
    `modules/testing.md` for update).
  - This machine's git has no `gpg.ssh.allowedSignersFile`, so `git log %G?` shows `N`; commits were made with the
    usual signing settings, but signatures were not verified here.
- **Lesson candidates:**
  - A test that uses `0` as "long ago" for a `time.monotonic()` timestamp fails on a freshly booted Linux runner
    (monotonic counts from boot); build "past" values relative to `monotonic()` and the real cutoff (extends L-112).
    Fail-first trick: shift `time.monotonic` by a constant so it reads a small value; asyncio still works.
  - A test that asserts the vendored tool's version as a literal breaks on every re-vendor; compare with the
    constant (`VENDORED_APWT_VERSION`).
  - The project 13864 npm registry answers 404 to anonymous reads; fetch the published tarball with `npm pack <name>@<v>
    --registry <project registry>` (the user's `~/.npmrc` token) and compare with `npm view … dist.shasum`. Record this
    step in the release skill (it was not in 51-13).
- **Process:** no L-089 batching of dependent steps in this session (tag and `rev-list`, build and status, commit and
  verify, push and `ci list`, provision and run check, restart and status each in their own message). One push
  (playwright-appian) ran inside the D27 window by the user's explicit decision.

## Context manifest

```toml
areas    = ["release-ci", "distribution", "workflows-library", "browser-testing"]
adrs     = ["ADR-019", "ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-030", "L-048", "L-056", "L-057", "L-089", "L-098", "L-099", "L-100", "L-111", "L-112"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3.md", "tracker:agent-system/skills/genesis-release/SKILL.md", "tracker:agent-system/skills/genesis-doc-writeback/SKILL.md"]
code     = ["genesis/pyproject.toml", "genesis/packages/kiro-agent-sdk/pyproject.toml", "genesis/genesis/testexec/vendor.py", "genesis/genesis/testexec/vendor/**", "playwright-appian/package.json", "genesis-workflows/registry.json", "genesis-workflows/skills-registry.json", "genesis-workflows/skills/**"]
upstream = ["53-11"]
```
