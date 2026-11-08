# Phase 51 — Test execution engine: action library, regression suite and story verification — as built

> **Status:** 🚢 SHIPPED (live acceptance open) 2026-11-08 · playwright-appian **v0.3.0** (`d3ed993`) → genesis
> **v0.81.0** (`62537c2`; the app and the three packages at 0.81.0, `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged)
> → genesis-workflows **v0.25.0** (`6a7d432`; `test-execution` 0.1.1, `action-capture` 0.2.2, `setup-composer` 0.1.1,
> `story-verification` 0.1.0, skill `genesis-test-authoring` 0.3.0; all internal pins on `genesis.git@v0.81.0`) ·
> m0026–m0028 (DB 25 → 28; memory.db v1) · **ADR-081..084** Accepted.
> **Live acceptance is still open (D38):** 51-12 steps 1–27 run on QA on v0.81.0 when QA is back; findings ship as
> v0.81.x patches. Spec: `specs/phase-51-test-execution-engine.md` + `51-01..51-18` (each with its As built; 51-13 has
> the As run). Reviews: `specs/phase-51-test-execution-engine/reviews/`. Follow-ups: `specs/backlog/phase-51-follow-ups.md`.
> CI: playwright-appian main #7335244 + tag #7335271 (publish job 82599625, verify-published 82599626); genesis master
> #7335323 (red, Linux reap) → #7335941 + tag #7335975 (six jobs); genesis-workflows master #7336032 (red, Node
> assumption) → #7336147 + tag #7336158. Published tarball sha256 `9ba92b93…41e4` (744,734 bytes).

## What changed

- **For a user:** an application **Testing** tab (Library · Regression · Executions · Setup). Configure a **QA**
  environment (Settings → Environments now has a Type: Dev, QA, UAT, Production, Other), the QA site and the
  application's test users; install Chromium and create the per-app test workspace (Node ≥ 20 and Chromium are per
  machine). Record a flow as one role (**Record workflow**, optionally also as a data setup) or **Compose with AI** a
  data setup from library items; review the proposals; write case scripts for `TC-` cases; run scenarios, the
  regression suite (also on a schedule, off by default) or **Run impacted tests**; read results per scenario and step,
  flaky badges and the Playwright report (on its own loopback origin, :8860 for :8760). On the Workbench, Deployment now
  precedes Verification; dragging a card into Verification runs `story-verification`, which moves it to Done or back
  to Implementation with a defect report and leaves proposals and a report on the story page.
- **For a developer:** new `genesis/genesis/testexec/` engine, `integrations/apwt/`, `kb/testexec_store.py`,
  `api/testing.py`, `web/src/features/testing/`; the vendored `playwright-appian` tarball is package data; workspaces
  live under `~/.genesis/testing/apps/<app>/` (git); `genesis serve` also starts the reports origin
  (`--reports-port`). The genesis-workflows tests import Phase 51 genesis modules, so its pins must move with genesis
  (L-057). Code map: `bible/03` "Phase 51" block.
- **For the agent system:** `playwright-appian` is a third code repo in `genesis-ctx`; the `browser-testing` area routes
  every Phase 51 path (51-02 + this write-back); shell-guard rules (c) network feed and (d) bare `npx apwt` (51-02).

## Delivered (by sub-spec)

| Sub-spec | Result | Commits |
|---|---|---|
| 51-01 | Findings; decisions D1–D38 (D3a–D3d), defaults F1–F14 | — |
| 51-02 | playwright-appian joins the agent system (repo lists, `browser-testing` area, allow rules, skill `genesis-playwright-appian-dev`, release flow); shell-guard rules (c)/(d); review fixes (M1a–c, m1–m5); agent-system tests 389 | project-tracker `6f549da`, `4e2220d` |
| 51-03 | Spike: sandbox evidence S1/S5/S6 (PASS, residual 1 = loopback); D3c loop L1/S4/S11 PASS; S8/S9 via playwright-appian 0.3.0 (D-114); S10 timings (194 s, 26 calls, 8.44 credits); P10 global MCP servers load into workflow turns; review SHIP | genesis `340520a`, `5a15d41`, `87efc73`, `36cfe6f`, `55af523`; playwright-appian `395b2ac`, `5d7ae2d` |
| 51-04 | m0026 (suite rebuild with the new runner flag `foreign_keys_off`, ten tables, three counters; DB v26), `kb/testexec_store.py`, library lifecycle, `adr-drafts.md`; review SHIP | genesis `316ac5a` |
| 51-05 | Runtime detection + Chromium install, vendored tarball, `TestWorkspace`, `ApwtClient` + factory, `procs` (bounded children, daemon records, reap), environment types + single QA, test settings and users; review SHIP | genesis `c18d1a7` |
| 51-06 | Spec generator, `RunManager.start(prepare=)`, runner with the whole-report password scrub (B1, R1), `test-execution` 0.1.0, finalizer, queue, Run impacted tests (+ regression group), `regression-run` job; review SHIP (third pass) | genesis `ee1b77c`; workflows `5a24d17` |
| 51-07 | `lib/` + `scan-refs.mjs`, `TestLibraryService`, `RecordingService` (0.3.0 sequence), `CaptureFinalizer`, `ProposalService`, `LIBRARY_TRANSITIONS`, `action-capture` 0.1.0, skill 0.1.0; review SHIP (third pass) | genesis `bb577c4`; workflows `966c022` |
| 51-08 | `RegressionService`, one `regression_selection`, retired references kept (D21), m0027 notes (DB v27), per-app schedules with `since`; review SHIP | genesis `d701ea9` |
| 51-09 | Lane reorder, Verification launch (409 codes), D24 overlay, `story-verification` 0.1.0, `StoryVerificationFinalizer`, proposals apply; review SHIP | genesis `7daa505`; workflows `93e6e35` |
| 51-10 | The Phase 51 HTTP contract: D23 background jobs, library-replay jobs, `expected_row_version`, recording readiness, route-order and no-secret tests over every route, `types/testing.ts` + 42 fixtures; review SHIP | genesis `83fa255` |
| 51-11 | Every Phase 51 screen (Testing tab, item pages + lazy CodeMirror, Record dialog + bar, proposals, executions, setup, Settings type select + CLI card, Verification dialog + story section, Phase 49 page additions); `ApiError.body`; review SHIP (third pass) | genesis `8f013be`, `0170834` |
| 51-14 | Queued verification guard (D25): moves out cancel it, launch re-checks the lane twice, board `verification_active`; §5 Queued cards movable with a confirm; reviews SHIP | genesis `9b258bb`, `b23337c`, `c74cbed`, `45e9827`, `a1f7f3e`, `209297a`, `cca8ff8` |
| 51-15 | 51-12 first-pass fixes: B1 replay poll loop, B2 reports origin (D26; probe 12/12), B3 + MJ3 pause/cancel per worker + CAS terminal write, MJ1/m6 automation status rule, MJ2/D27 contract from code, D28 actions proven in use, D29–D32 UI (width probe 42/42 clean), m1–m4, m8, n1, n2; review SHIP (second pass) | genesis `d8c1fc8`, `e001b30`, `6fe9e71`, `f68c7ca`, `4412645`, `f6d86ff`, `750f0d1`, `b4265da`, `521910b`; workflows `daf3612` |
| 51-16 | Record as a data setup (D34): m0028 `request_json` (DB v28), `action-capture` 0.2.0 + skill 0.2.0, setup-first replay, dependency rule; review SHIP | genesis `8dd7b6b`, `f80dde1`, `b4402ca`, `4f6f283`; workflows `9970714`, `f6b9397` |
| 51-17 | Compose with AI (`setup-composer` 0.1.0, D35) + multi-role setups (D36); `action-capture` 0.2.1, skill 0.3.0; review SHIP after M-1/M-2 | genesis `96dceeb`, `2621743`, `2b2cf9d`; workflows `24145bf`, `69bface` |
| 51-18 | 51-12 re-run fixes (D37): R-MJ1 one roles reader (the scanner) + parity test, R-m1 paused runs kept, R-m2 replay only from untouched library files, R-m3 `noUnusedLocals` + per-action `test.step` proofs, R-m4 action restore → Draft, R-m5 Remove script, R-n1, R-n2, R-O1; version gates (`action-capture` ≥ 0.2.2, `setup-composer` ≥ 0.1.1); review SHIP (+ delta m5) | genesis `51e55f9`, `e75a668`, `2d1adb7`, `96354a8`, `0a5d342`, `346f885`; workflows `6218803`; playwright-appian `0950798`, `f00cebb` |
| 51-12 | Independent review + gates + live acceptance. First pass NEEDS_CHANGES (B1–B3, MJ1–MJ3, m1–m11); re-run NEEDS_CHANGES (R-MJ1, R-m1–R-m6); **Re-run 2 SHIP (code level)**; Parts 2–3 (installs, restarts, isolation probe 12/12, width probe 42/42 + the compose dialog) PASS. **Live steps 1–27 open (D38).** | — |
| 51-13 | Release (As run): playwright-appian v0.3.0 published and vendored byte for byte; genesis v0.81.0 (`8e5bacc` + the Linux reap fix `2e92fca`, `62537c2`; the unpushed local tag moved to `62537c2` at the user's choice); genesis-workflows v0.25.0 (`b295394` + the no-Node test fix `60dde75`, `6a7d432`); fleet deployed; this write-back | genesis `8e5bacc`, `2e92fca`, `62537c2`; workflows `b295394`, `60dde75`, `6a7d432`; playwright-appian `d3ed993` |

Tests at release: genesis app pytest **1832** locally (1 deselected: `test_config.py::test_server_readiness_probe`
hangs with Docker installed), **1778 passed + 61 skipped** in CI (1418 at v0.80.0); web vitest **726** (62 files; 467
before); genesis-core 96, kiro-agent-sdk 79, genesis-appian-parser 53 + 1 skipped (unchanged); genesis-workflows
`validate_library` **18**, `validate_skills` **4**, pytest **428** (317 before); playwright-appian **1399** (coverage
98.57 %); agent-system 389.

## Deploy (51-13 §2, 2026-11-08 21:53–21:55 IST)

Before: both instances healthy, 0 runs active, **both already on DB v28** — main since its Phase 51 dev-venv runs and
the 51-12 re-run's `db upgrade` (27 → 28), **userb migrated 25 → 28 by the same re-run** (51-13 §2 still said v25;
the real state is recorded here), both serving `346f885` code and reporting 0.80.0. Backups (SQLite online backup,
integrity ok) under `/tmp/genesis-release-51-13/backup/`. `gsm provision --all --no-mcp --no-env --force` (18
workflows each, the four testing workflows on both), the skill installed on both through `POST /api/skills/install`,
`gsm restart --all`. After: `/openapi.json` 0.81.0 and schema v28 on both, reports listeners :8860 and :8861, no error
in either log.

## Live acceptance (51-12 §3)

The first live pass (2026-11-04/05, main, QA) passed steps 1–11 and 21 and found **B1** (the item page polled forever
after a replay job ended), **B2** (a Playwright report could call `/api`), **B3** (pause failed the run), **MJ2** (the
contract form saved nothing) and **MJ3** (cancel ended `error` with two `run.final`) — none of which the code reviews of
51-06..51-11 had found. All are fixed and re-reviewed at code level, and the no-QA probes passed (step 24 isolation on
main 12/12; step 20 widths). **Still open (D38):** steps 1–27 on v0.81.0 with QA — real Kiro turns in the three agent
workflows, a QA replay, a two-role sign-in, the Verification lane end to end, the new dialogs in a real browser,
pause/restart/cancel on the live instances, step 24 on userb (needs an execution there), the F10 re-measure of the
900 s turns, and the m5 check (Remove script refused during a running verification).

## Decisions and deviations

- Every decision is in `51-01-findings.md` §7 (D1–D38) and §8 (F1–F14). The agent-access design went D3 → D3a →
  D3b → **D3c** (the ordinary shell, isolation in Phase 52; ADR-083). D20/D28 changed how library items become Ready;
  D24 the verification overlay; D25 the queued-verification guard; D26 the reports origin; D27 contracts in code only;
  D33–D36 recording-as-setup, the composer and multi-role setups, all inside Phase 51; D37 every re-run finding fixed;
  **D38 released before live acceptance.**
- No ADR deviation. ADR-021's `pre_mutation` rule for QA test data is amended by ADR-082 (D22); the reports origin is
  an amendment of ADR-028 and a note in ADR-026's network surface, carried by ADR-081 (51-12 re-run R-m6); the per-app
  cadence inside `regression-run`'s options is an ADR-047 note in ADR-081 (51-06 §8).
- Release (51-13 As run): Phase 51's 43 genesis and 9 genesis-workflows build commits first met CI with the release
  commits (macOS-only local runs; the `backup/phase-51-*` pushes used `-o ci.skip`). Linux CI then exposed procps `ps`
  truncating command lines to `$COLUMNS` (reap found no marker; fixed by reading `/proc/<pid>/cmdline`, `ps -ww`
  elsewhere, and logging a `ps` failure) and a workflow test that assumed Node on PATH. The local `v0.81.0` tag, never
  pushed, was moved from `8e5bacc` to `62537c2` at the user's choice.
- Dates: the record dates D38 and the end of 51-18 "2026-11-09"; the release, its tags and this write-back are
  2026-11-08 (tag dates). The umbrella and this doc use 2026-11-08.

## Lessons (write-back decisions)

_Proposed to the user 2026-11-08; filled in when approved._

## Agent-system notes

1. **L-089 recurred in every role** despite the lesson and the skills: 51-13 As run (tag + `rev-list`, `cp` +
   `shasum`, build + status, add + commit, push + `ci list`, batched `sleep`s that did not wait), 51-14 (two commits
   staged before the bundle reached the disk), 51-15 (build + status, add/commit + status), 51-18 (build + bundle
   commit; three full test runs at once), the reviewers of 51-12 Part 2 (verify + backup + install, restart + verify),
   51-14 and 51-18, and the spec sessions. Every outcome was re-verified alone and was correct. A structural guard is
   proposed (backlog `phase-50-follow-ups.md` §5).
2. `browser-testing` now routes the Genesis test-execution paths (23 globs, 8 gates); the verification lane's paths are
   also in `stories-workbench`.
3. The genesis `README.md` DB line was fixed in the release commit (m0001–m0028, DB v28).
