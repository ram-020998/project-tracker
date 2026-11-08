# Review 51-12 — Phase 51 review, hardening and live acceptance (genesis-review, 2026-11-04)

**Ranges reviewed.** genesis `v0.80.0..cca8ff8` (HEAD, resolved; 21 commits, 338 files) · genesis-workflows
`v0.24.0..93e6e35` (HEAD, resolved; 3 commits, 21 files) · playwright-appian `v0.2.0..main` (`5d7ae2d`; the dirty
`.gitignore` line `playwright-appian.code-workspace` is the user's, pre-existing, not reviewed) · project-tracker Phase 51
agent-system commits `6f549da` + `4e2220d` (15 files; 51-02, re-review SHIP).

**Read:** the 51-12 pack (`context/.packs/51-12.md`), every upstream As built (51-02, 51-03 §2b, 51-04 … 51-11, 51-14
incl. As built §5), the 51-13 spec, the ADR-081..084 drafts. Evidence files: `/tmp/genesis-review/51-12/`.

---

## §1 Independent review (the 15 checks)

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | No agent at execution | **OK** | `test-execution/graph.py:40` imports only `program_node`; nodes `:361-366` are `prepare_env`, `run_playwright` (raw async, `asyncio.to_thread` `:321-324`), `parse_results`, `present` — no `kiro_node`. Regression, impact and ad-hoc executions all launch `WORKFLOW_ID = "test-execution"` (`execution_service.py:38`, `:289`); only `kind == verification` goes through a launcher (`:252-254`). |
| 2 | Committed code only; D24 overlay; nothing agent-authored before accept | **OK** | `_launch` regenerates and commits only the generated paths, then `prepare` exports that commit (`execution_service.py:268-283`); `export` is `git archive` of the commit (`workspace.py:530-541`); the catalog reads case scripts with `ws.show(head, path)` (`execution_service.py:106-110`). Tests `test_uncommitted_script_does_not_count`, `test_regeneration_commits_only_the_generated_paths`. Verification exports HEAD + restores only its stored overlay (`verification_service.py:258-268`); `test_tools_generate_into_the_checkout_and_leave_the_workspace_and_db_alone`, `test_passed_moves_to_done_keeps_the_overlay_and_the_proposals` (asserts workspace HEAD and the script hash unchanged). The `automated` promotion after a verification needs a committed script binding (`finalizer.py:249-252` joins `kb_test_case_scripts`), so an overlay-only case is not marked automated. See **MJ1** for `broken`. |
| 3 | References, never copies; deterministic generator | **OK** | Generated specs import cases (`tests/fixtures/testexec/generated/suites/DS-000001/002-TS-000007.spec.ts:4-5`, `TC_000001(await pages.ctx(...))`); golden files under `tests/fixtures/testexec/generated/**` checked by `test_testexec_generator.py` (7). |
| 4 | QA only | **OK** | `ApwtClient` refuses a session without a QA host or on another host before spawning (`integrations/apwt/client.py:193-197`) and passes `--allow-host <QA>` (`:207`); `ApwtFactory.qa_host` refuses without a QA env (`factory.py:36-40`); readiness lists "No QA environment" and a host clash (`settings_service.py:244-250`); environment refusals in `config/environments.py` (`test_environment_types.py`, 18). None of the three workflows declares an MCP server (grep for `mcp`/`servers`/`tools=` in the three `graph.py`: none); no deployment node. |
| 5 | Secrets | **OK (code)**; live step 19 NOT RUN (skipped by the user) | Passwords live under `testusers-<sha1>` in the SecretProvider (`settings_service.py:34-40`); reach only the Playwright child env (`runner.py:120`); the whole report folder is scrubbed in raw, JSON, `\u`-JSON and XML forms incl. the HTML report's embedded zip and nested trace zips (`runner.py:149-221`); apwt output scrubbed; `secret_values` is a scrub source only (`settings_service.py:207`). Tests: `test_scrub_reaches_the_html_reports_embedded_zip_and_trace_zips`, `test_scrub_catches_json_and_xml_escaped_passwords`, `test_every_phase_51_route_answers_without_a_secret` (`test_testing_api.py:533`), the workflow tests' state/checkpoint/event/file scans. A failed or cancelled verification run's `apwt-out` is not scrubbed by design (51-09 decision 11) — step 19 greps it. |
| 6 | Agent access to `apwt` (D3c, ADR-083) | **OK** | The prompt prefix is `cd <export> && PLAYWRIGHT_APPIAN_HOME=<run>/.apwt npx --no-install apwt -s <session>` (`client.py:372-377`, used at `story-verification/graph.py:681`); sessions are opened/closed by program nodes (`open_sessions`, `cleanup`); `kiro_node`'s trust-all is unchanged (`packages/genesis-core/genesis_core/nodes/agent.py:298-301`, no Phase 51 diff); ADR-083 draft names the accepted risks, P10 and Phase 52 (`adr-drafts.md:134-220`). |
| 7 | Reliability; no `pre_mutation` on QA-writing workflows | **OK** | `attach_reliability` on `segment` (`action-capture/graph.py:701`), `explore`, `author`, `propose` (`story-verification/graph.py:1201-1212`); `attach_healing` on `replay/heal` and `triage/heal` with `META.healing {1,1}` (`action-capture/graph.py:86,703`; `story-verification/graph.py:107,1206`); `validate_library` PASSED (17), incl. the reliability and HITL lints, with no `pre_mutation` in the three (grep). |
| 8 | Lifecycle | **OK** | Library status writes only through `TestLibraryStore.set_status` (`testexec_store.py:491-515`, the `LifecycleService` primitive, re-checks referrers in its transaction); no other `UPDATE … SET status` on actions/setups (grep); `LIBRARY_TRANSITIONS` keeps `TEST_TRANSITIONS` unchanged (`test_testexec_library.py`); captures/executions are CAS run records (51-04 decision 8); story lane edges via `build_story_lifecycle_service().transition` (`story_verification_finalizer.py:104,264-269`). |
| 9 | Lane order consumers (L-094) | **OK** | 51-09 As built §L-094 lists every consumer; `STORY_LANES` order and edges in `domain/transitions.py`; `test_lane_order_board_api_and_card_join`; `workbench.test.tsx` asserts the board renders the API order; web `lanes.ts` labels only. |
| 10 | Finalizers | **OK** | Bound-run guards (`story_verification_finalizer.py:153-160`, `finalizer.py` `test_bound_run_guard`), CAS idempotency (`StaleWriteError` → no-op, `:194-197`), startup + on-read reconcile (`:120-148`; `test_get_reconciles_a_finished_run_on_read`, `test_routes_start_409_view_report_and_on_read_recovery`); live tests end runs through the real `RunManager._finalize`, which stores before announcing (`runs/manager.py:146-151`). |
| 11 | Subprocesses: timeouts + process groups; nothing left after cancel/pause | **OK in genesis; minor gap in the workflows** | `run_bounded`/`start_long_lived` start every child with `start_new_session=True`, record the pgid in `<run>/.pids` and kill the group on timeout (`procs.py:9-11,158-190`); git, npm, tsc, scan-refs, apwt and Playwright all go through them (`workspace.py:126-139,294,416`); `RunManager` reaps `.pids` on finalize, pause and the sweep (`manager.py:154-169,337-344`). **m1:** the workflows' own `tsc` call (`story-verification/graph.py:549-551`, `action-capture/graph.py:279-281`) is a plain `subprocess.run` (no own group, not in `.pids`). Live step 18 checks `ps`. |
| 12 | DB | **OK** | Fresh → v27 and real-data v25 → v27 (§2); m0027 from a populated v26 is in `test_testexec_regression.py`; the collab feature tombstone takes `BEGIN IMMEDIATE` and writes the note before the generic delete (`collab/service.py:589-596`). Re-reviewed post-SHIP fixes: 51-08 n1 — `run_now` reads the selection once and passes it (`regression_service.py:258-261`, `execution_service.py:190-198`); 51-08 n2 — `RegressionScenarioBody(ScenarioCreate)` (`api/testing.py:339`); 51-04 m1′ — `foreign_key_check` compared on `tuple(r)[:3]` = `(table, rowid, parent)` (`db/runner.py:69,76-78`), with the tolerance + "added violation refused" tests and a rollback test. See nit **n2**. |
| 13 | Web | **VIOLATION** — B1, B2 (live), m2, m8 | Across the 57 changed web source files: no `<Button asChild>`, no `"/api` outside `lib/api/`, no `fetch(` outside `lib/api/`, no direct `lucide-react` import, no raw palette classes (grep); `LazyCodeEditor` and `PassRateChart` are `lazy()` (`LazyCodeEditor.tsx:7`, `RegressionView.tsx:25`); 9 new test files use jest-axe; `contract.test.ts` fixtures. **m2:** the story page report iframe (`VerificationSection.tsx:225`). |
| 14 | `playwright-appian` | **OK** | Additive only: `record start --browser/--state`, optional `start_signed_in` (`trace-schema.ts`, `types.ts`, `trace-keys.ts` +1 optional key each); D-114 recorded (`planning/DECISIONS.md:107`); taxonomy untouched, generator still label-only; gates green (§2). Vendored tarball sha256 `5712a7a5…f0ed` = `VENDORED_APWT_SHA256` (`testexec/vendor.py:17`), its `package.json` is 0.3.0. |
| 15 | Naming (L-092) | **OK, one nit** | No new `test_*`/`*_test` module outside tests (git diff `--diff-filter=A`); every `Test*` class in `genesis/**` passes the AST scan in `test_testexec_store.py:593`. **n1:** `TestExecutionState` in `genesis-workflows/workflows/test-execution/graph.py:91` has no `__test__ = False`. |

## §2 Gates (all run by the reviewer)

| Repo | Gate | Result |
|---|---|---|
| genesis | `.venv/bin/python -m pytest -q -p no:warnings` | **1680 passed** in 650 s (51-14 As built: 1679 + the `45e9827` m2 test) — `/tmp/genesis-review/51-12/pytest-genesis.txt` |
| genesis | `.venv/bin/ruff check genesis` | **All checks passed** |
| genesis | ruff on the Phase 51-changed `tests/*.py` | clean except `tests/test_db.py:16` unused `tempfile`, pre-existing since `a9aac7ff` (not Phase 51) |
| genesis | DB: fresh → v27 | m0001–m0027 applied, FK check empty, integrity ok, re-run no-op, `ACT-`/`DS-`/`TE-` counters present — `db/db-probe.json` |
| genesis | DB: v25 → v27 with data | `~/.genesis/genesis.db` is **already v27** (m0026/m0027 applied 2026-11-04 11:59 UTC; see O1), so a real-data v25 DB was rebuilt: v25 schema from `MIGRATIONS[:25]` (m0001–m0025 unchanged since v0.80.0) + every row of a read-only backup of the main DB (2 feature suites, 126 cases, 23 scenarios, 135 steps, 139 story links, 448 object links, 4 top-ups, 142 stories, 271 383 run events, …). Migrated 25 → 26 → 27: FK check empty before and after, integrity ok, every old column of every table value-equal (only `kb_sequences` gained the 3 new rows), suite AUTOINCREMENT high-water 14 kept, children still reference `kb_test_suites`, re-run no-op, `RegressionStore.get_or_create` → id 15, the suite tree reads 34 cases — `db/db-probe-real-v25.json`. userb's real v25 DB (no Phase 49 rows) also → v27 clean. |
| genesis/web | `npx tsc --noEmit` | clean |
| genesis/web | `npx eslint .` | 0 errors, 20 warnings (all pre-existing) |
| genesis/web | `npx vitest run` | **665 passed, 61 files** |
| genesis/web | bundle | `npx vite build --outDir /tmp/genesis-review/51-12/static`, waited 65 s, `diff -r` against `web/static`: **identical** (71 assets each) |
| genesis-workflows | `ci/validate_library.py` | **PASSED (17 workflows)** incl. reliability lint, internal-pin check (9 bad tables) |
| genesis-workflows | `ci/validate_skills.py` | **PASSED (4 skills)** |
| genesis-workflows | `pytest -q workflows --ignore=workflows/_fixtures` | **360 passed** |
| playwright-appian | `npm run build`, `lint`, `typecheck` | all clean |
| playwright-appian | `npm test` | first run under load (genesis pytest in parallel): 1 failed / 1398 — `tests/cli/agent-act.test.ts` "a ref without an address…" hit vitest's 5 s timeout; that file alone 6/6, full re-run **95 files / 1399 passed** (O2) |
| project-tracker | `pytest agent-system/tests` | **389 passed** |
| project-tracker | `genesis-ctx lint` | OK, 0 errors, L0 ~23,845 / 24,000 |

## `genesis-ctx check` checklists

Raw outputs: `/tmp/genesis-review/51-12/check-genesis.txt`; workflows / playwright-appian / tracker printed in-session
(`check --repo project-tracker` is not supported — 51-02 known limit — so the tracker files were checked with `--files
tracker:…`). "No change" = the Phase 51 diff touches nothing the rule governs.

### genesis (`check --since v0.80.0 --repo genesis`)

**ADRs**
- [OK] ADR-001 — §1.1; workflows own control flow; agents are narrow nodes.
- [OK] ADR-002 — agent steps are `kiro_node` turns; no new ACP path.
- [OK] ADR-003 — local app; QA runs with the user's own test users.
- [OK] ADR-004 — no MCP server added to any new node (the P10 global-server finding is ADR-083's accepted risk).
- [N/A] ADR-005 — no registry change.
- [N/A] ADR-007 — no role gating change.
- [N/A] ADR-008 — no change.
- [VIOLATION] ADR-009 — ad-hoc pause fails a run instead of pausing it (B3, live TE-000011; pre-existing `RunManager` path). The new workflows' designed gates exist (`story-verification/graph.py:1180-1183`).
- [OK] ADR-010 — state holds pointers (`_doc(ctx, …)` artifacts); bulk in the run folder; workflow tests scan state.
- [OK] ADR-011 — §1.7.
- [OK] ADR-012 — worker reaches Genesis only through `ctx.extras['apwt']`; graph.py files import only genesis_core/langgraph.
- [N/A] ADR-013 — no change.
- [OK] ADR-018 — results, plans, proposals are run-folder documents.
- [OK] ADR-019 — no `CORE_MAJOR` change; genesis-core API unchanged.
- [OK] ADR-020 — nothing global written; apwt home is `<run>/.apwt`; browsers in `~/.genesis/testing/browsers`.
- [OK] ADR-021 — amended by the drafted ADR-082 (D22, `adr-drafts.md:91`); written at 51-13.
- [OK] ADR-022 — run files under the artifacts root; F11 retention (`test_retention_prunes_files_beyond_the_newest_twenty`), replays pruned to 20.
- [OK] ADR-023 — routes are FastAPI.
- [OK] ADR-024 — async nodes offload blocking work with `asyncio.to_thread`; startup sweeps via `to_thread` (`api/app.py`).
- [N/A] ADR-025 — no fork change.
- [OK] ADR-026 — no new network surface; no auth added.
- [OK] ADR-027 — §1.13.
- [OK] ADR-028 — all new routes under `/api`; client prepends centrally (`lib/api/testing.ts`).
- [OK] ADR-029 — amended by drafted ADR-083 for the trust-all note.
- [OK] ADR-030 — SQLite, forward-only m0026/m0027, sync store signatures.
- [N/A] ADR-031 — chat unchanged.
- [N/A] ADR-032 — credits path unchanged (step 14 records real metered credits).
- [N/A] ADR-033 — no copilot tool added.
- [OK] ADR-034 — `genesis-test-authoring` is filesystem-provisioned per node (ADR-069).
- [OK] ADR-035 — verification inputs written as files in the stage folder (`inputs_dir`).
- [OK] ADR-036 — single dev still enforced (`set_dev_environment` refuses the QA env).
- [N/A] ADR-037 — no KB content change.
- [N/A] ADR-038 — no MCP install change.
- [N/A] ADR-039 — no change.
- [OK] ADR-040 — apwt vendored, versioned, sha-checked, never auto-updated (`vendor.py`).
- [N/A] ADR-041 — no change.
- [OK] ADR-042 — suites/scenarios cascade with feature/app (m0026 tests).
- [N/A] ADR-043 — Lavish unchanged.
- [N/A] ADR-044 — superseded; untouched.
- [N/A] ADR-045 — chat unchanged.
- [OK] ADR-046 — the tarball and templates ship as package data (51-05 wheel check).
- [OK] ADR-047 — one fixed `regression-run` job; per-app cadence in options (`regression_job.py`, `schedule_store.update_option_entry`); ADR-047 note owed at 51-13.
- [OK] ADR-048 — Dev credentials still from the dev env; test users have their own scope.
- [OK] ADR-049 — one more application tab (Testing).
- [OK] ADR-050 — §1.8.
- [OK] ADR-051 — nodes use `kiro_node` (AgentProvider path unchanged).
- [N/A] ADR-053 — no change.
- [N/A] ADR-054 — no change.
- [OK] ADR-055 — tokens + shared primitives (§1.13).
- [N/A] ADR-056/057/058/059 — stage model unchanged; `verification` is a story stage (`kb/story_stages.py`), not a feature stage.
- [N/A] ADR-060 — no change.
- [OK] ADR-061 — amended by drafted ADR-084 (lane order, D6).
- [OK] ADR-062 — Deployment → Verification confirm launches the bound run, finalizer moves the card.
- [OK] ADR-063 — Phase 51 data is local; collab untouched except the tombstone note.
- [N/A] ADR-064 — Hub contract unchanged.
- [N/A] ADR-065 — no change.
- [OK] ADR-066 — agent nodes are ordinary `kiro_node` turns (turn explorer).
- [OK] ADR-067 — §1.7.
- [OK] ADR-068 — amended by drafted ADR-082 (QA writes); no Appian object write or delete tool.
- [OK] ADR-069 — `skills=SKILLS` on every agent node; `playwright-appian` resolved from `<run>/checkout/node_modules` only (`runtime/context.py`).
- [N/A] ADR-070 — no change.
- [OK] ADR-071 — verification lives on the one story page.
- [N/A] ADR-072 — no story id change.
- [N/A] ADR-073 — no package tool use.
- [N/A] ADR-074 — no sync change.
- [N/A] ADR-075/076 — no spec change.
- [OK] ADR-077 — role agents unchanged; no `--trust-all-tools` for them.
- [OK] ADR-078 — retire not delete; regression scenarios Draft → Ready → Retired.
- [OK] ADR-079 — impact on demand, stores nothing; regression group added.
- [OK] ADR-080 — no internal dependency entry added (`pyproject.toml` untouched).

**Lessons**
- [N/A] L-001 — no ACP env change.  [OK] L-002 — `kiro_node` unchanged.  [N/A] L-003 — SSE unchanged.
- [OK] L-004 — SQLite.  [VIOLATION] L-005 — a cancelled run emits two `run.final` (`cancelled`, then `failed`; MJ3).  [N/A] L-007 — transcript unchanged.
- [N/A] L-008 — unchanged.  [OK] L-009 — async nodes, async checkpointer.  [OK] L-010 — `/api` only.
- [OK] L-011 — `contract.test.ts` + 42 + 3 fixtures from real responses.  [N/A] L-012.
- [OK] L-014 — jest-axe matchers via the existing setup.  [OK] L-015 — §1.13.  [N/A] L-016 (live step 14 records metered credits).
- [OK] L-017 — no chat trust change.  [N/A] L-018.  [OK] L-019 — passwords through the provider.
- [OK] L-020 — `recursion_limit` 120/200 in META.  [OK] L-021 — the agent saves logs by reference (51-03 S11).
- [OK] L-023 — `normalize_report` defensive, tested on real + derived shapes.  [OK] L-024 — skills as files.
- [OK] L-025/L-027 — ruff pinned, unchanged.  [OK] L-026 — sync stores, `to_thread` from async.
- [N/A] L-028/L-029.  [OK] L-030 — web changed; frontend job will run.  [N/A] L-031/L-032.
- [OK] L-033 — recording refuses without `action-capture`; verification `not_installed`.  [N/A] L-034/L-035/L-037.
- [OK] L-039 — one DTO builder for board list/single card (51-14 test), scenario DTO.  [N/A] L-040.
- [OK] L-041 — agents author inside `<run>/checkout`.  [OK] L-042 — context as files (`library.json`, inputs).
- [N/A] L-043/L-044/L-045/L-046/L-047.  [OK] L-048 — package data.  [N/A] L-049/L-050/L-051.
- [OK] L-053 — no core credential read by the workflows.  [N/A] L-054/L-055.
- [OK] L-056 — every As built commit followed by an empty status; release check owed at 51-13.
- [OK] L-057 — the pin move is named as required in 51-13 §1.4.
- [OK] L-058 — on-read + startup recoveries; failures logged.  [N/A] L-059/L-060.
- [OK] L-061 — bound-run guard; see O1 for the restart rule.  [OK] L-062 — workflow → finalizer per kind.
- [N/A] L-063.  [OK] L-064 — explore/author split; turn bounds.  [OK] L-065 — gate→END paths set a status (story-verification tests).
- [N/A] L-066/L-067.  [OK] L-068 — `index.html` `no-cache` (`api/testing.py:299`, `workbench.py:514`).
- [OK] L-069 — no `<Button asChild>`.  [N/A] L-070/L-071/L-072/L-073/L-074.
- [OK] L-075 — healing tier patches in place.  [OK] L-076 — one author turn for the story's scripts.
- [N/A] L-077/L-078/L-079/L-080.  [OK] L-081 — regression schedule off by default, `user_modified` kept.
- [N/A] L-082/L-084/L-085/L-086.  [OK] L-083 — fixtures from real responses and the real 1.59.1 report.
- [N/A] L-087.  [OK] L-088 — 51-02 corpora.  [OK] L-089 — settled-bundle proof (§2).
- [VIOLATION] L-090 — CasesTable `min-w-[1072px]` set by eye scrolls at 1280 (m8, live probe).  [OK] L-091 — lock first (`BEGIN IMMEDIATE`/CAS).  [OK] L-092 — §1.15.
- [VIOLATION] L-093 — store-before-announce holds, but cancel's two terminal writes race (MJ3).  [OK] L-094 — §1.9.  [N/A] L-095 (no object UUID written).
- [OK] L-096 — whole-route-table shadow test (`test_testing_api.py`).  [OK] L-097 — sweeps under `holds_run_owner_lock()` (`api/app.py`).
- [OK] L-098 — no internal dependency.  [N/A] L-099.  [OK] L-100 — no CI-variables call.

**Gates:** pytest, ruff, kiro-agent-sdk (unchanged package; not re-run), web lint/typecheck/test, build — §2.

### genesis-workflows (`check --since v0.24.0 --repo genesis-workflows`)

- [OK] ADR-001, 006 (three folder packages + `registry.json`), 010, 011, 012, 017, 018, 019, 021 (via ADR-082 draft),
  022, 029 (ADR-083 draft), 034, 035, 048 (no Appian credential read), 062, 067, 068 (ADR-082 draft), 069, 078, 080 —
  as in §1 and above.
- [N/A] ADR-003, 005, 007, 014 (scaffolder not used; trio present and linted), 015, 020, 026, 030, 031, 033, 036, 037,
  038, 039, 041, 045, 046, 056, 057, 058, 059, 061, 063, 065, 073, 074, 075, 076, 077.
- [OK] L-006 (topologies; `test_story_verification_workflow` asserts ids = compiled nodes), L-009, L-013, L-020, L-021,
  L-023, L-024, L-026, L-033, L-042, L-064, L-075, L-076, L-092 (no `tests/__init__.py`; n1), L-057 (51-13 §1.4).
- [N/A] L-017, L-022 (no reducer keys), L-025/L-027 (unchanged), L-029, L-030, L-045, L-049, L-051, L-053, L-056 (51-13),
  L-087, L-088, L-089, L-098, L-099, L-100.
- Gates: `validate_library` PASSED (17), `pytest workflows` 360, genesis pytest/ruff — §2.

### playwright-appian (`check --since v0.2.0 --repo playwright-appian`)

- [N/A] ADR-011, 019, 026, 046, 063, 065, 074, 077, 080 — no Genesis surface in this repo's diff.
- [OK] L-056 (release check owed at 51-13), L-057 (vendor + pins at 51-13), L-100. [N/A] L-017, 025, 027, 030, 045,
  051, 087, 088, 089, 092, 098, 099.
- Gates: `lint && typecheck && test` green, `build` ok — §2.

### project-tracker agent-system (`check --files tracker:agent-system/… tracker:context/…`)

- [OK] ADR-077 (no `--trust-all-tools`; allow rules narrowed to `npx --no-install apwt`), L-088 (shell-guard rules (c)/(d)
  with bypass + positive corpora; re-review SHIP), L-100. [N/A] ADR-011, 019, 026, 046, 063, 065, 074, 080; L-017, 025,
  027, 030, 045, 051, 056, 057, 087, 089, 092, 098, 099.
- Gates: agent-system 389 passed; `genesis-ctx lint` OK.

---

## §3 Live acceptance

Run with the user on 2026-11-04/05 (the user drove the browser; the reviewer read DB snapshots, the run log, `ps` and the workspace git log, and ran the step 20/24 real-browser probes).

**Setup (HITL, 2026-11-04).** The user restarted main (:8760) on HEAD `cca8ff8` (pid 64742, 22:46 IST; no run active)
and configured the QA environment `https://eng-test-gam-automation-site.appianpreview.com` and two test users
(`contracting-officer` / `contracting.officer1`, `contracting-specialist` / `contracting.specialist1`, passwords entered
by the user). Reviewer, with the user's go-ahead: DB backup (sqlite backup API, source read-only)
`/tmp/genesis-review/51-12/backup/genesis-20261104-225053.db` (integrity ok, v27, 126 cases, 2 test users);
`genesis install --from <genesis-workflows checkout> test-execution action-capture story-verification` (0.1.0 each,
ref `local`); skill `genesis-test-authoring` via `POST /api/skills` (source local — the library install needs the
unpushed skill on GitLab; installed `SKILL.md` byte-identical to the checkout). App: **AS GSS Full Application**
(`_a-0000e5bc-…_930416`). Readiness `[]`; runtime ok (node 20.20.2, Chromium 1217, apwt 0.3.0, @playwright/test 1.59.1).

| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | Environments: Dev via the select, second QA, QA on the Dev host, second Dev | **PASS** (user) | Dev unchanged in `environments.json` (`type: dev`, `is_dev: true`); second QA and host collision refused as field errors. Leftover test row `https://example-qa2.appianpreview.com` type `other` (user to delete). KB-sync re-check not run. |
| 2 | CLI card; Install Chromium | **PASS** (user) | Card shows node/Chromium/apwt; Chromium 1217 + headless shell under `~/.genesis/testing/browsers`; afterwards no Playwright/npm process, `~/.genesis/testing/jobs/.pids` empty. |
| 3 | Setup: site, users, workspace | **PASS** (user + reviewer); password grep **NOT RUN** (skipped by the user) | Readiness clear; workspace is a git repo (`b2462a1` Create the test workspace, `b2eeea7` Install the testing runtime) with the template (`lib/`, `suites/`, `cases/`, `setups/`, `actions/`, `vendor/`); `.gitignore` covers `.auth/`, `.env*`, `output/`. |
| 4 | Record as role A | **PASS** (user + reviewer) | Capture #1 as `contracting-officer`; `action-capture` run `r-8ee5d311c719` done in 11 min 45 s: `segment` 159 s, 8 tool calls, **4.84 credits** (metered); first replay failed → `heal` **482 s of the 600 s `turn_timeout` (80 %)**, 9 tool calls, **12.72 credits** → replay passed (healing tier worked, ADR-067). See m4. Untracked `captures/1/trace_debug.json` left in the workspace (m3). |
| 5 | Accept / reject → one commit | **PASS (partial)** | The user accepted all four proposals (no reject exercised live; reject is covered by `test_testexec_recording.py`). One commit `eb64193` "Apply capture #1 …" = the 4 action files + `captures/1/trace.json`; ACT-000001..4 `ready` with audited `draft → ready approve` rows (replay passed at the code's hash). |
| 6 | Edit an action: type error, save, history, revert, editor themes | **PASS** (user + reviewer) for the parts without a user; the breaking-contract and Save-as-new parts are row 6 (part 2) | On ACT-000002: type-error save refused inline, nothing committed; `e4fd785` Update + audited `ready → draft changed` (17:48:22 UTC); `200f4e0` Revert to `eb64193`; then `draft → ready approve`. CodeMirror legible in light and dark (user). |
| 7 | Edit outside Genesis → banner; execution before Adopt runs the old code; Adopt commits | **PASS** | "Changed outside Genesis" with the diff (user). The library Replay before Adopt ran the **committed** code: `…/library-replays/<app>/ACT-000003-20261104T175126255585/checkout/actions/evaluations/search-evaluations.ts` has no `// edited in VS Code`, the workspace file has it. Adopt → `7e3bf78` "Adopt ACT-000003 (edited outside Genesis)", status `draft`. |
| 13–17 | Verification lane, verification run, product defect, gates, proposals | **NOT RUN** (deferred by the user) | No story with Ready cases in a scenario is in a lane that can reach Verification on this KB (Code Review stories have 0 Ready cases). The F10 write-flow re-measure (step 14) stays open. |
| 6 (part 2) | Breaking contract while used; Save as new | **PASS via the code editor; FAIL via the contract form (MJ2)** | Form: adding a required input to ACT-000002 (used by TC-000007) → two `PUT` 200 "Saved", nothing written (MJ2). Code editor: the same change refused as breaking, naming TC-000007, **Save as new** → ACT-000005 "Open evaluations (tab)" Draft with input `tab` (`69bfa01`); ACT-000002 unchanged, Ready (user + DB). |
| 8 | Regression: references, own scenario, data setups, plan, Run now | **PASS** (user + reviewer); cross-feature regression scenario not possible with today's scripted cases | DS-000001 "Evaluation for regression" (`4a466be`, `6e8ddfe`), replayed twice → Ready (audited) and 2 evaluations in QA. References TS-000002 (setup DS-000001, shared) + TS-000007 (not automated: "TC-000033 has no case script"); own TS-000024 "51-12 cross check" (TC-000007; DS-000001, changes shared data) — reachable only by URL (m7). Plan: groups `DS-000001` [TS-000002] and `DS-000001.TS-000024` private [TS-000024]. `TE-000002` regression, run `r-caff4434baea`, passed in 66 s; result rows carry `setup_instance` `DS-000001` and `DS-000001.TS-000024`; QA gained 2 evaluations (4 total, user) = one per setup instance; no browser process left. |
| 8 (part) | First execution (TS-000002 Run from the scenario page) | **PASS** (user + reviewer) | Prep: the user saved scripts for TC-000007 (calls ACT-000002) and TC-000017 (`3eaf704`…`1118cc0`); ref TC-000007 → ACT-000002. Before running, both cases read `not-automated` and the scenario "Not automated" (m6). `TE-000001` adhoc, run `r-af6555f0e7af`, queued → running → **passed** in 20 s; commit `d9192337`, apwt 0.3.0, Playwright 1.59.1, QA URL + site path recorded; results: scenario + 2 case rows passed (6.2 s); afterwards both cases `automated`; no Playwright/Chromium process left. |
| 9 | Break one step on purpose | **PASS** | TC-000017 with `link('No Such Link 51-12')` → `TE-000003` regression **failed**: TS-000002 failed at TC-000017 (locator timeout, 2 attempts = the one retry), TC-000007 passed before it, scenario row carries `test-failed-1.png` + trace; TS-000024 on its own instance still ran and passed; execution page shows the error, both screenshots and `error-context.md`/`trace.zip` links (screenshot `step20/execution-page-1280-dark.png`). |
| 10 | A failing setup blocks only its scenarios | **PASS** | DS-000002 "Broken setup 51-12" (wrong `contractSpecialist`, Draft) on TS-000024: `TE-000004` (adhoc) and `TE-000005` (regression) → **blocked**: TS-000024 `blocked` with `setup:DS-000002…: TimeoutError`, its step `not-run`; TS-000002 on DS-000001 ran and passed (3 rows). `TE-000005` started 0.4 s after `TE-000004` finished (the F7 queue, live). |
| 11 | Test Impact → Run impacted tests | **PASS** | Object "AS GSS Start Evaluation" (linked only to TC-000007): `TE-000006`/`TE-000007` kind `impact`, trigger `{impact_source: objects, max_hops: 2, changed: [0002ecdd…]}`, selection `[2, 24]` = exactly the scenarios containing TC-000007; `TE-000006` blocked (DS-000002), `TE-000007` passed after the user reset the setup. |
| 12 | Schedule | **NOT RUN** (deferred by the user) | `regression-run` row: hourly window 00:00–23:00 IST, last tick 2026-11-05 00:00 "no application has a regression schedule". |
| 20 | Real-browser width probe (L-090) | **PASS except CasesTable at 1280 (m8)**; Verification dialog NOT RUN | `/tmp/genesis-review/51-12/probe20.cjs`, `probe20b.cjs` → `step20/result.json`, `step20b/result.json` + 66 screenshots; Chromium 1217 headless, light + dark (`theme-*` class checked), Tailwind resolved (`table-fixed` computes `fixed`). No page-level horizontal scroll on any screen at 1280/1440/1920, no clipped header or cell in any table. Measured (light = dark): **LibraryView** 982/1142/1350 px — Key 97/112/133, Name 271/315/373, Area 106/123/146, Role 158/184/217, Status 83/96/114, Used by 69/80/94, Last result 199/231/273; **ExecutionsView** (fixed px) Key 110, Kind 110, Trigger 130, Status 110, Duration 100, Started 130, Totals 292/452/660; **Setup users** 940/1100/1308 — Role 186/217/258, Username 193/226/269, Password 126/147/175, Set password 334/391/465, Actions 102/119/141; **CasesTable** (92 rows) Key 96, Title 256/326/258, Type 108, Priority 88, Status 80, Stories 92, Scenarios 100, Review 136, Automation 116 — **at 1280 the table is 1072 px in a 982 px container: horizontal scroll** (m8); execution page, Regression view, CLI tab: no overflow (screenshots); dialogs Record 512×592, New action 448×492, Environment 512×900, all inside the 1000 px viewport, no inner overflow. The Verification dialog needs a card in Deployment (steps 13–17 deferred). |
| 18 | Cancel a running execution | **FAIL (MJ3)**; no process left **PASS** | User cancelled `TE-000008` (run `r-a99b86a0a4b8`) while running; it ended **`error`** "worker exited abnormally" instead of cancelled. The run log has **two** `run.final` events 0.2 ms apart: `cancelled` (seq 275216) then `failed` (seq 275217); run stored `failed`; the reap ran twice ("stopped 1 leftover process group(s)", `genesis.log` 177143-4); `ps` afterwards: no Playwright/Chromium/apwt. |
| 21 | Restart `serve` with one running and one queued | **PASS** | `TE-000009` (regression, run `r-93aab6c223e2`) running at the restart → `error` "worker lost across a server restart" (the L-097 startup sweep under the run-owner lock); the queued `TE-000010` (adhoc) started 0.3 s later (05:23:57.34 UTC) and passed. |
| 19 | Security spot checks (password grep of every run folder) | **NOT RUN** (skipped by the user) | No password file was provided; the static scrub tests (§1.5) stand. Verification runs (whose failed `apwt-out` is not scrubbed) were not run either. |
| 22 | Known limits: a paused execution does not hold the queue | **FAIL (B3)**; the queue part PASS | User paused `TE-000011` (run `r-daaa91b97cc3`, `POST …/pause` 200, `genesis.log` 177374): the run went **`failed`** "worker exited abnormally" (`run.final{failed}`, seq 275242), execution `error`; it can never be resumed. `TE-000012` (TS-000002 Run) started 26 s later and passed, so a stopped run does not hold the queue. The execution page has **no link to its run** (the user found the run through Runs; m9). The verification half (a paused verification, the collab-pull lane race) NOT RUN (13–17 deferred). |
| 23 (rest) | Create workspace / Update testing runtime routes | **NOT RUN** | Buttons hidden while not applicable (correct); the reviewer did not call the route without the user's OK. |
| 24 | Report isolation | **FAIL (B2)** | Real-browser probe `/tmp/genesis-review/51-12/probe24.cjs` → `step24/result.json` + screenshots on TE-000001's report: served with no CSP; **top-level tab** (how the execution page opens it): `fetch('/api/applications')` → 200 with the app's uuid; **iframe `sandbox="allow-scripts"`**: origin `null`, the report renders **blank** (`b-allow-scripts.png`); **iframe `allow-scripts allow-same-origin`**: renders, origin `http://127.0.0.1:8760`, reads `/api/applications` (200). The report needs `allow-same-origin` and is served from the SPA's origin, so it can reach `/api`. |
| 23 | Setup jobs + library Replay jobs | **FAIL (B1)** for the Replay UI; job backend **PASS** | Replay job `caadd0ad…` 202 → `succeeded` in 28 s (17:51:26 → :54), result `failed` (m5), recorded once in `last_replay`; a repeat click returned the same job (one replay folder). Cancel: job `04478cc9…` 202 → DELETE → `cancelled` in 1 s, no result recorded, no Playwright/Chromium/apwt process in `ps` afterwards, `jobs/.pids` empty. **But the item page never showed either outcome and looped**: 70 job polls + 142 item reads in 10 s after the first replay; 731 job polls + 125 item reads after the cancel; stops only on reload (B1). Install Chromium job PASS (step 2). Create workspace / Update testing runtime are hidden while not applicable (`WorkspaceSection.tsx:38-45`); their routes not exercised live. |

---

## Findings

### Blockers
- **B1 (51-11) — the library item page loops forever after a Replay job ends and never shows its result (live
  steps 7/23).** Live on ACT-000003: the job ended `succeeded` (result `failed`) after 28 s, yet the page kept the
  "Replaying on QA" spinner and Cancel, at ~7 job polls + ~14 item reads per second (10 s sample: 70 + 142;
  `~/.genesis/run/genesis.log` lines 155188–164663); a cancelled job looped the same way (731 polls + 125 reads). Only a
  reload stops it. Cause (from the code): the item read's `replay_job` is cached as `running`; `LibraryItemPage.tsx:159`
  calls `resume(detail.replay_job)` on every render; on the terminal poll `useJobRunner` invalidates every testing
  query (`hooks.ts:90-94`), which cancels and restarts the item refetch before it lands, so the stale `running`
  `replay_job` re-arms the poll (`hooks.ts:111-113` → `track`). **Fix:** don't resume a job id that this runner has
  already seen finish (keep the finished id), and/or refetch the item without cancelling (`cancelRefetch: false`) or
  set the item's cached `replay_job` to null on terminal; a regression test that renders the page with an item read
  whose `replay_job` is running, finishes the job, and asserts the poll stops and the result shows (MSW counts the
  requests).
- **B2 (51-06 / 51-11) — the Playwright HTML report can call `/api` (live step 24; the spec's rule: "a report that can
  reach `/api` is a blocker").** `GET …/testing/executions/{key}/report/{path}` serves the report from the SPA's origin
  with no `Content-Security-Policy` (`api/testing.py:292-300`), and the execution page opens it top-level in a new tab
  (`ExecutionPage.tsx:73,84,120`). Probe on TE-000001: top-level `fetch('/api/applications')` → 200 with the app; in an
  iframe with `sandbox="allow-scripts"` alone the report is blank (opaque origin), with `allow-same-origin` it renders
  and reads `/api` again. The report embeds QA page text, error messages and agent-authored step titles (D3c: QA page
  text is untrusted), and Genesis has no auth (ADR-026), so a script there can drive every `/api` route. **Fix (pick
  with the user):** serve report files from a second loopback origin (e.g. a separate port that serves only report
  folders, no `/api`) and embed/link that origin; or serve them with `Content-Security-Policy: sandbox allow-scripts
  allow-popups allow-downloads` and make the report work in an opaque origin (the probe shows Playwright 1.59's report
  does not today). Same for the story page's iframe (m2). Test: a route test for the header/origin and a real-browser
  check that the served report cannot read `/api`.

- **B3 (runs-worker; pre-existing in `runs/manager.py`, surfaced by live step 22) — Pause fails the run instead of
  pausing it (ADR-009 mode 2).** `RunManager.pause` kills the worker and stores `paused` (`runs/manager.py:337-344`);
  the worker dies on SIGTERM with a non-zero code, the supervisor emits `worker_exit` (`runs/supervisor.py:83-87`), and
  the event handler finalizes `failed` "worker exited abnormally" (`runs/manager.py:240-245`) because `_finalize`
  refuses only TERMINAL statuses and `paused` is not one (`:142`). The same path exists at `v0.80.0` (`manager.py:224`).
  Live: TE-000011 paused → `failed`, execution `error`, no resume possible. In this DB no run has ever ended `paused`
  (`runs` statuses: done 284, failed 111, cancelled 17). ADR-009 makes ad-hoc pause/resume REQUIRED; 51-06/51-09 rely
  on it (a paused execution or verification is a documented known limit, step 22). **Fix with MJ3:** record the
  intended stop (pause / cancel) before `w.kill()` and ignore `worker_exit` for a run whose stored status is `paused`
  or terminal; only an unexpected death fails the run. Regression test with a real subprocess worker that exits
  non-zero on SIGTERM: pause → `paused`, resume → continues from the checkpoint.

### Majors
- **MJ1 (51-06 / 51-09) — a case marked `broken` can never leave `broken`.** `StoryVerificationFinalizer._mark_broken`
  sets `automation_status = broken` for each triage-`script` case (`chat/story_verification_finalizer.py:236-247`). The
  only other writer is `TestExecutionFinalizer._automation`, which promotes **only** `not-automated` → `automated`
  (`testexec/finalizer.py:249-256`); `TestScriptStore.upsert` (`kb/testexec_store.py:650-666`), the case-script save,
  the verification apply and `delete` never touch the column (grep: no other writer in `genesis/**`). So after the
  script is fixed, accepted and passes in a library execution, the case page, `CasesTable` and the Tests tab keep
  showing Broken for good, and the user has no action that clears it (D14.5: broken = an *unhealed* script defect).
  **Fix:** when a library execution or verification records a passed/flaky case step whose script binding exists, set
  `automated` over `broken`; reset to `automated` (or `not-automated`) when the case script is saved/accepted/adopted;
  regression tests for both paths, through the real `RunManager._finalize`.

- **MJ2 (51-07 / 51-11) — the item page's contract form is silently ignored: "Saved", nothing saved (live step 6).**
  The page always sends `code` with the form's `contract` (`LibraryItemPage.tsx:122-131`). On a code save the stored
  contract is the code's literal `inputs`/`outputs` when present (`library_service.py:652`, `:673-676`; 51-07 decision 7),
  and every recorded or template action declares them. Unchanged code is a no-op with no catalog write
  (`:659`), so the PUT answers 200 and the toast says "Saved". Live: the user added a required input `tab` to
  ACT-000002 (used by TC-000007) in the form and saved twice: both `PUT …/actions/ACT-000002` → 200
  (`genesis.log` lines 170191, 170195); `contract_json` still `{"inputs": [], "outputs": []}`, `row_version` 7 and
  `updated_at` unchanged, no commit. The D16.5 rule held (nothing changed), but the breaking-change refusal and
  **Save as new** are unreachable from the form, and the user is told the edit was saved. **Fix:** either make the
  form edit the code's literal metadata (write the contract into the `defineAction` call), or refuse a save whose
  form contract differs from the code's declared one ("the contract is declared in the code — edit it there"), and
  never answer "Saved" for a save that changed nothing; a route + page test with a literal-declared item.

- **MJ3 (51-06; root cause in `runs/manager.py`, pre-existing since `105d2c74`) — Cancel on a running execution ends it
  `error`, with two `run.final` events (live step 18).** `RunManager.cancel` kills the worker and then calls
  `_finalize(CANCELLED)` (`runs/manager.py:346-352`); the killed worker's `worker_exit` event, on the reader thread,
  calls `_finalize(FAILED, "worker exited abnormally")` (`:240-245`) at the same moment. `_finalize`'s guard
  (`rec.status in TERMINAL`, `:142-143`) is a read-then-write, so both pass it: `run_events` of `r-a99b86a0a4b8` hold
  `run.final{cancelled}` then `run.final{failed}`, the run is stored `failed`, and `TestExecutionFinalizer` maps it to
  `error` (TE-000008). Before Phase 51 a cancelled run ending `failed` was cosmetic; now the execution's status, the
  Executions list, the header badge and the regression trend report a user's cancel as an error, and every observer
  sees two terminal events (L-005, L-093). **Fix:** make the terminal transition single-shot — a CAS store
  (`UPDATE runs SET status=? WHERE run_id=? AND status NOT IN (terminal)`) or a per-run lock in `_finalize`, emitting
  `run.final` only for the write that won; mark the run as cancelling before `w.kill()` so `worker_exit` is ignored.
  Regression test through the real `RunManager` with a worker that exits non-zero on SIGTERM: one `run.final{cancelled}`,
  execution `cancelled`.

### Minors
- **m1 (51-07 / 51-09, genesis-workflows) — the workflows' `tsc` runs outside the process-group/`.pids` rule (F8).**
  `story-verification/graph.py:549-551` and `action-capture/graph.py:279-281` call `subprocess.run([npx, …, "tsc", …],
  timeout=…)`: no `start_new_session`, nothing in `<run>/.pids`. On a timeout only `npx` is killed; on cancel/pause the
  supervisor terminates the worker pid only (`runs/supervisor.py:31-37`), so a running `npx`/`tsc` pair outlives the
  run until it finishes. **Fix:** start it in its own session and record the pgid in `<run>/.pids` (or kill the group
  on timeout); the program nodes already reach Genesis's helpers through `ctx.extras['apwt']`. Add a test.
- **m2 (51-11) — the story page report iframe is not sandboxed.** `VerificationSection.tsx:225` uses
  `sandbox="allow-scripts allow-same-origin"` on `report_url`, a same-origin `/api/…/verification/report`
  (`api/workbench.py:504-514`). With both flags on a same-origin URL the sandbox does nothing. The served page is
  Genesis's own `verification-report.html` (`story-verification/graph.py:561-605`: `html.escape` everywhere, no script),
  so it needs neither flag; the comment at `:221-223` gives a wrong reason (it is not Playwright's report). Its links
  (attachments, session logs) navigate inside the iframe to any file of the execution report folder, with the same
  non-sandbox. **Fix:** `sandbox=""` (plus `allow-popups` and `target="_blank"` on the report's links if they should
  open). Severity is re-assessed in live step 24.
- **m3 (51-07) — every recording leaves an untracked `captures/<id>/trace_debug.json` in the workspace.** apwt writes
  `<trace>_debug.json` beside the trace (`playwright-appian/src/recorder/index.ts:32`); Genesis commits only
  `trace.json` (`eb64193`), so `git status` of the workspace shows `?? captures/1/trace_debug.json` from then on (live,
  capture #1). **Fix:** delete it after `record stop` (or git-ignore `captures/*/*_debug.json`); test.
- **m4 (51-07, F10) — `action-capture`'s `heal` turn came within 20 % of its bound.** Live run `r-8ee5d311c719`: `heal`
  482 s (`duration_ms` 482395) against `HEAL_TIMEOUT_S = 600` (`action-capture/graph.py:107`), 9 tool calls, 12.72
  credits; `segment` 159 s of 900 s. By the step-14 rule, raise the heal bound (e.g. to 900 s, like `segment`) or bound
  the heal prompt's flow.
- **m5 (51-07) — a library Replay of a mid-flow action can never pass.** `replay_spec_ts` opens the site home, signs
  in and calls the item alone (`testexec/replay.py`, header). ACT-000003 "Search evaluations" (recorded right after
  "Open evaluations") fills the Evaluations page's search box, so its Replay fails with `locator.fill … Timeout 15000ms`
  (live job `caadd0ad…`). Once an edit or Adopt sends such an action to Draft (D20), no Replay can bring it back to
  Ready. **Fix (pick one, with the user):** let Replay take preceding steps (e.g. the capture's order, or "replay
  with ACT-x first"), or let the user approve an action whose dependent scenario passed; document the rule in the
  item page.
- **m7 (51-11) — a regression-owned scenario has no way in from the UI.** The Regression view's member rows
  (`RegressionView.tsx:214-252`) show key, title and badges but link nowhere; a regression scenario has no feature, so
  its scenario page (status, data setup, changes shared data) is reachable only by typing
  `/applications/:app/test-scenarios/:id` (live: TS-000024). **Fix:** link each member's key to its scenario page.
- **m8 (51-11, L-090) — the Phase 49 CasesTable scrolls sideways at 1280 px.** `CasesTable.tsx:90`
  `min-w-[1072px]` (set by eye) is 90 px wider than the 982 px the Tests tab gives it at a 1280 px viewport (probe
  `step20b/result.json`: scroller client 982, scroll 1072, both themes); at 1440 it fits (1142). The spec asks for no
  horizontal scroll at ≥ 1280. **Fix from the measurement:** the fixed columns sum to 816 px (Key 96, Type 108,
  Priority 88, Status 80, Stories 92, Scenarios 100, Review 136, Automation 116), leaving Title 166 px at a 982 px
  floor — lower `min-w` to ≤ 982 px (e.g. Review 136 → 112, Type 108 → 96, keep Title ≥ 200) and re-probe.
- **m6 (51-06 / 51-11) — a scripted case reads "Not automated" until it has run once.** `automation_status` becomes
  `automated` only in the execution finalizer (`testexec/finalizer.py:249-256`); saving or accepting a script never sets
  it, and the web derives a scenario's state from its cases' statuses (`features/testing/automation.ts:5-9`). Live:
  after the user saved scripts for TC-000007/TC-000017, the cases and TS-000002 read "Not automated" while the generator
  would run them; they turned Automated only after TE-000001. **Fix with MJ1:** set `automated` when a case script is
  saved/accepted/adopted (and back to `not-automated` when its script is deleted); test.

- **m9 (51-11) — the execution page has no link to its run.** `ExecutionPage.tsx` renders no `run_id` link (grep:
  none in `features/testing/*.tsx`); to pause, inspect or read the run graph the user had to find the run in Runs
  (live step 22). **Fix:** a "View run" link like the story page's.
- **m10 (51-07 / 51-10, user question 6) — a library Replay creates no run and shows no evidence.** By design the
  Replay is an in-app `library-replay` job, not a run and not a `TE-` (51-07 decision 3, 51-10 decision 7): nothing
  appears in Runs or Executions. Its Playwright report and screenshot are written to
  `~/Genesis/runs/library-replays/<app>/<key>-<stamp>/report` (live: `ACT-000003-20261104T175126255585`), but the item
  page shows only the error string (`ReplayResultView`, `LibraryItemPage.tsx:430-442`; the stored `last_replay.detail`
  keeps raw ANSI escapes such as `\x1b[2m`) and links nothing. **Fix (with genesis-spec):** link the replay's report and
  failure screenshot from the item page (a report route for replay folders, under the B2 isolation rule), strip ANSI
  from `detail`; or record replays as ad-hoc executions.
- **m11 (51-11, user-reported UX) — the Testing screens do not match the application's established patterns.**
  Reported by the user in live acceptance, to be designed by genesis-spec and built by genesis-dev:
  (a) Action and Data setup item pages: the card section titles have too little space above them, so they look
  misaligned; (b) the Library grid does not follow the grid style used elsewhere — the reference is the Stories grid on
  the feature page (`/applications/<app>/features/6`); (c) the Testing tab adds two more layers of tabs (application
  tabs → Testing views → in-view sub-tabs; three layers in total): simplify the navigation; (d) the execution page
  (e.g. `/testing/executions/TE-000012`) needs a better layout. Screenshots of the current state:
  `/tmp/genesis-review/51-12/step20/{library,execution-page,regression,setup}-1440-light.png`.

### Nits
- **n1 (genesis-workflows) —** `TestExecutionState` (`workflows/test-execution/graph.py:91`) is a `Test*` class outside
  tests without `__test__ = False` (L-092 rule; not collected today because no test module imports the name).
- **n2 (51-04) —** the m1′ tolerance key `(table, rowid, parent)` (`db/runner.py:69,76`) would also hide a *new*
  violation on the same row towards the same parent table through a different FK column. No current migration can
  produce one; a comment would do.

- **n3 (51-11, user suggestion) —** a **Format** button for the code editor (e.g. Prettier on the TypeScript); a
  feature request for the backlog, not a defect.

### Observations (not findings against the code)
- **O1 — the fleet is not in the state `context/state/current.md` describes.** The main instance (:8760, pid 89692,
  started 2026-11-04 17:35 IST from the editable dev venv) runs Phase 51 backend code from before 51-14 (`9b258bb`
  21:06) and its DB was migrated to v27 at 11:59 UTC; the SPA it serves from disk is HEAD's bundle (`cca8ff8`), which
  expects `verification_active`. `/openapi.json` still says 0.80.0. userb (:8761) runs pre-Phase-51 code (started
  2026-11-01) on DB v25. For genesis-docs / genesis-release.
- **O2 — playwright-appian test timing.** `tests/cli/agent-act.test.ts` (not in the Phase 51 diff) hit vitest's 5 s
  default under parallel load; green alone and on a full re-run.

## Verdict: NEEDS_CHANGES

**Gates:** all green (§2). **Static review:** checks 1–4, 6–10, 12, 14 OK; 5 OK in code; 11 and 15 OK with m1 / n1;
13 violated (B1, B2, m2, m8). **Live acceptance:** PASS — 1, 2, 3, 4, 5 (accept only), 6 (code path), 7, 8, 9, 10, 11,
21, 25; FAIL — 6 via the contract form (MJ2), 18 (MJ3), 20 at 1280 for CasesTable (m8), 22 (B3), 23 Replay UI (B1),
24 (B2); NOT RUN — 12, 13–17 (no story with Ready cases in a scenario; the F10 write-flow re-measure with them), 19,
the rest of 23, the Verification dialog of 20.

**Required before SHIP (each fix with a regression test; then a re-review and the NOT RUN steps live):**

| Finding | Owner sub-spec | Fix in one line |
|---|---|---|
| B1 | 51-11 | the item page stops polling after the job ends and shows the result (no stale `replay_job` resume) |
| B2 | 51-06 / 51-11 (user decision on the approach) | serve Playwright reports from an origin that cannot reach `/api` |
| B3 | runs-worker (pre-existing; fix with MJ3) | an intended pause is not turned into `failed` by `worker_exit` |
| MJ1 | 51-06 / 51-09 | `broken` can return to `automated` (passing run of a bound script, script save/accept) |
| MJ2 | 51-07 / 51-11 | the contract form either edits the code's declared contract or is refused; no false "Saved" |
| MJ3 | 51-06 + `runs/manager.py` | one terminal transition per run; cancel ends `cancelled` |

Minors m1–m11 and nits n1–n3 should be fixed or moved to `specs/backlog/phase-51-follow-ups.md` by the user's choice
(m11 and n3 need genesis-spec first). O1 is for genesis-docs/genesis-release (the fleet's real state) before 51-13.

---

# Re-run — after 51-14, 51-15, 51-16, 51-17 (genesis-review, 2026-11-07)

**Ranges reviewed** (every head resolved; each is the repo's current HEAD):

| Repo | Range | Size |
|---|---|---|
| genesis | `v0.80.0..2b2cf9d` (37 commits, 372 files) | delta since the first pass: `cca8ff8..2b2cf9d` (16 commits, 97 source files) |
| genesis-workflows | `v0.24.0..69bface` (8 commits, 48 files) | delta since the first pass: `93e6e35..69bface` (35 files) |
| playwright-appian | `v0.2.0..5d7ae2d` | no commit since the first pass; the dirty `.gitignore` line is the user's own, pre-existing |
| project-tracker agent-system | `6f549da`, `4e2220d` | no agent-system or `context/` commit since the first pass (`git log --since=2026-11-04`) |

**What was read:**
- The 51-12 pack (`genesis-ctx pack 51-12`, 50.2K tokens, OK).
- The first pass above.
- The As built and review of 51-14 (incl. §5), 51-15 (sessions 1 and 2), 51-16 and 51-17.
- The full diffs of `runs/manager.py`, `runs/store.py`, `kb/testexec_store.py`, `testexec/{library_service, proposals, compose, capture_finalizer, recording, finalizer, execution_service, generator, replay, reports_origin, verification}.py`, `api/{testing, workbench, app, run_routes}.py`, `cli/main.py`, `chat/story_verification_finalizer.py`, m0028, the templates and the web job runner.
- The new `workflows/setup-composer/graph.py` in full.
- The action-capture 0.2.x, story-verification m1 and test-execution n1 diffs.

Evidence folder: `/tmp/genesis-review/51-12-rerun/`.

**Scope change, decided by the user on 2026-11-07.** The QA environment and the Dev environment are down: no `*.appianpreview.com` host resolves from this machine (`socket.gaierror` for both QA and Dev, while `gitlab.appian-stratus.com` resolves). The user therefore asked for the complete code-level review now, with live acceptance (§3) later. **§3 is NOT RUN in this re-run.** The setup it needs is done (below), so the next session can start at step 1.

## Setup done for §3 (user-approved; each step recorded)

1. **Backups.** Made with SQLite's online backup API from read-only sources; integrity ok on every copy. Index: `backup/backup-20261107-201211.json`.
   - `backup/main-20261107-201211.genesis.db`: v27, 427 runs, 126 cases.
   - `backup/userb-20261107-201211.genesis.db`: v25, 118 runs.
   - Both `memory.db` files.
2. **`genesis db upgrade`.**
   - main: 27 → 28, applied `[28]`.
   - userb (`gsm exec userb -- db upgrade`): 25 → 28, applied `[26, 27, 28]`.
   - Afterwards both report `max(version)=28`, integrity ok and an empty `foreign_key_check`.
3. **Installs on main.**
   - `genesis install --from <genesis-workflows checkout>`: `test-execution` 0.1.0, `action-capture` 0.2.1, `story-verification` 0.1.0, `setup-composer` 0.1.0 (ref `local`); each `graph.py` is byte-identical to the checkout.
   - Skill `genesis-test-authoring` 0.3.0 through `POST /api/skills` (source local; `SKILL.md` identical to the checkout; `version: 0.3.0`).
   - userb has no Phase 51 workflows (not needed except for step 24's second instance).
4. **Restarts** (`gsm restart main`, `gsm restart userb`), with no run active on either (L-061; checked by a DB read first).
   - main: pid 14358, :8760, reports :8860.
   - userb: pid 14393, :8761, reports :8861.
   - Both serve `/api/applications/{app}/testing/compose` (HEAD code).
   - `/openapi.json` still says 0.80.0 (pre-release).
5. **Cleanup of the first pass's leftovers.**
   - **DS-000002**: Delete was not offered, because it was used once (`ever_referenced = 1`). The user retired it in the UI, with an audit row `test_setup 2 draft → retired retire admin.user 14:49:34Z`.
     - The user then clicked Restore twice; both answered 409, the D20 rule "replay it first" (`domain/transitions.py:231`).
     - The user then replayed the retired setup (202; failed `ERR_NAME_NOT_RESOLVED`). This is the designed path to a restore.
   - **ACT-000005** (never used): the user deleted it (`DELETE …/actions/ACT-000005` 204, workspace commit `f411090`).
   - **The workspace's untracked `captures/1/trace_debug.json` and `captures/2/`**: deleted by the user. My shell guard refused the write: `~/.genesis/testing` is outside the reviewer's write roots, and I did not go around the guard. `git status` of the workspace is now empty.
   - **The TC-000007 / TC-000017 scripts**: the user asked for a revert. **Genesis offers no way to remove a case script** (finding R-m5), so they stay; both cases read `automated`.
   - **The `example-qa2` environment**: still present. It is part of live step 1.
   - **The "Genesis 51-12 regression" evaluations in QA**: for the user in Appian (QA down).

## §1 Independent review (re-run on the whole Phase 51 diff)

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | No agent at execution | **OK** | `test-execution/graph.py:40` imports only `program_node`; its nodes are at `:361-363`. Regression, impact and ad-hoc executions launch `WORKFLOW_ID = "test-execution"` (`execution_service.py:39`); only `verification` goes through a launcher (`:93-95`). Nothing in the delta adds an agent to an execution path. D28's promotion is program code in the finalizer (`finalizer.py:199-232`). |
| 2 | Committed code only; D24 overlay; nothing agent-authored before accept | **OK, with R-m2 (proof integrity)** | Exports stay `git archive` of a commit (`workspace.py:528-541`). A compose exports the HEAD it records in `request.commit` (`compose.py:205-216`). A verification's overlay cases (or every case, when the overlay changes an action or setup) are excluded from the automation update (`story_verification_finalizer.py:202-213`), and verification never promotes actions (`finalizer.py:199`). Composed and recorded setups reach the library only through `ProposalService.apply` after a person accepts them. **But** a replay runs from a checkout the agent can write to, and Genesis checks only direct uses against what ran (R-m2). |
| 3 | References, never copies; deterministic generator | **OK** | Multi-role golden files `tests/fixtures/testexec/generated-roles/**` (two-role setup → `setup:DS-000001` depends on `auth:buyer`, `auth:approver`); the existing goldens are unchanged. The composer's replay generators are copies pinned by the cross-repo parity tests (100 passed locally, 0 skipped). See **R-MJ1**: the generator's roles reader disagrees with the scanner. |
| 4 | QA only | **OK** | `ApwtClient._check_url` refuses a session without a QA host or on another host (`client.py:191-197`) and passes `--allow-host` (`:207`); `ApwtFactory.qa_host` refuses without a QA env (`factory.py:36-42`). `setup-composer` declares `required_mcp: []` (`setup-composer/graph.py:98`) and has no MCP, write or deploy node; its replay goes through the 51-06 runner on `inputs.qa_url`. The reports origin binds the app's host only (`cli/main.py:151-157`), after the ADR-026 bind guard. |
| 5 | Secrets | **OK (code)**; live step 19 NOT RUN | The runner scrubs the whole report folder recursively (`runner.py:149-165`, `scrub_dir` `rglob`). That covers D29's new HTML report under `<replay>/report/html` and the composer's replay report (`setup-composer/graph.py:736` uses `_apwt(ctx).playwright(...)`). The composer removes `.auth` in a `finally` and again after the replay (`:739-747`). Its overlays copy the checkout without `.auth` (`overlay`, `ignore_patterns(".git", ".auth", "test-results")`). The compose agent gets file paths only and no session (`compose_prompt`: "Do not open a browser or run apwt sessions"). The reports origin serves only `…/report/**` and never a checkout (`reports_origin.py:47-53`; refusals `:56-81`). |
| 6 | Agent access to `apwt` (D3c, ADR-083) | **OK** | No change to the D3c path since the first pass (`client.py`, `story-verification/graph.py` only gained m1). The composer's agent nodes open no session (prompt above); `kiro_node` is unchanged (no genesis-core diff). |
| 7 | Reliability; no `pre_mutation` on QA-writing workflows | **OK** | `setup-composer`: `attach_reliability` on `compose` (`graph.py:851`) and `attach_healing` on `replay/heal/reassemble` with `META.healing {1,1}` (`:855`, `:103`). `hitl_points: ["escalate"]`, no `pre_mutation` (`:100`); the same holds for action-capture (`:113`), story-verification (`:105`) and test-execution (`:73`). `validate_library` **PASSED (18 workflows)**, including the reliability lint. F10: action-capture's heal is now 900 s (`action-capture/graph.py:137`, m4). The composer's turns are 900 s (`:122-123`); live timing is still to be measured. |
| 8 | Lifecycle | **OK, with R-m4** | Library status is written only by `TestLibraryStore.set_status` (`testexec_store.py:514`, grep: the only `SET status` on the library tables). D28's promotion uses `self.lifecycle.transition(... "approve", actor=execution_key)` (`library_service.py:878-930`). The compose apply goes through `ProposalService` (origin `compose`). The action approve refusal follows D28 (`domain/transitions.py:198-207`). **R-m4:** a retired action can be restored only with a passing replay at its hash, which D28 can no longer produce. |
| 9 | Lane order consumers (L-094) | **OK** | No lane or consumer change since the first pass. New registry values: `VALID_CAPTURE_KINDS += compose` and `VALID_LIBRARY_ORIGINS += compose` (`testexec_store.py:52,69`). Their consumers were grepped: the Library panel's `_LISTED_KINDS` (`api/testing.py:770`); the recording service's `kind == "recording"` guards (`recording.py:171,446`); the capture finalizers' kind guards (`capture_finalizer.py:139,170`); the web `origin` union (`types/testing.ts:176`). Verification captures stay apart (`verification_service.py:320`). The library is local-only, so there is no Hub consumer. |
| 10 | Finalizers | **OK** | `ComposeFinalizer` checks the bound run, the workflow and the kind (`capture_finalizer.py:166-171`), moves with a CAS (`set_status(..., expected_status="analysing")`), has a kind-guarded startup reconcile (`:136-143`; wired at `api/app.py:356`) and an on-read settle for the list and single reads (`api/testing.py:780-830`). The tests run through the real `RunManager._finalize` (51-17 As built). Every terminal write is now single-shot (`RunStore.claim_status`, `runs/store.py:126-142`), and only the winner announces (`manager.py:130-151`). |
| 11 | Subprocesses: timeouts + process groups; nothing left after cancel/pause | **OK** (first-pass m1 closed) | The workflows' `tsc` and `scan-refs` go through `ctx.extras['apwt'].run_bounded`: own group, pgid in `<run>/.pids`, group killed on timeout (`factory.py:86-97`; `action-capture/graph.py:455`; `setup-composer/graph.py` `_bounded`; `story-verification/graph.py:545-582`). The `_own_group` fallback uses `start_new_session` + `killpg`. `RunManager` reaps `<artifacts>/<workflow>/<run>/.pids` on finalize and on pause (`manager.py:166-178`), the same folder `ctx.workspace.root` names. Live step 18 (`ps`) is NOT RUN. |
| 12 | DB | **OK** | m0028 is additive and guarded by `PRAGMA table_info` (`m0028_capture_request.py:17-20`). m0026/m0027 are unchanged since the first pass. The n2 comment is at `db/runner.py:74-77`. Probes in §2 below: fresh → 28; real main v27 → 28; real userb v25 → 28; rebuilt Phase-49 main v25 → 28. |
| 13 | Web | **OK** (first-pass B1, B2, m2, m8 closed in code; live probes NOT RUN) | Over the 61 changed web source files: no `<Button asChild>`. The only `asChild` is the pre-existing `PopoverTrigger` in `TestImpactTab.tsx:289` (blame `8a7ca96e`, before v0.80.0). No `/api` or `fetch(` outside `lib/api/`, no direct `lucide-react` import, no raw palette class, no `dangerouslySetInnerHTML`. `LazyCodeEditor` and `PassRateChart` stay `lazy()`. Each of the 10 new test files runs jest-axe (1–11 checks each). The fixes: B1 `hooks.ts:84,97-98,131`; m2 `VerificationSection.tsx:227` (`allow-popups allow-popups-to-escape-sandbox`; the page is served with `script-src 'none'`, `api/workbench.py:518-519`); m8 `CasesTable.tsx:90` `min-w-[980px]`; m9 `ExecutionPage.tsx:269-276`; m7 `RegressionView.tsx:244`; D30 `LibraryView.tsx:52`; m11a `LibraryItemPage.tsx:241,249,297`. |
| 14 | `playwright-appian` | **OK** | No change since the first pass. lint, typecheck and build are clean. `npm test` failed in 1–2 of 1399 tests, by timeout, in both full runs; the file passes alone. That test predates the range (R-O1). |
| 15 | Naming (L-092) | **OK** (first-pass n1 closed) | `TestExecutionState.__test__ = False` (`test-execution/graph.py:91-92`; loaded standalone, `__test__` is False). No new `test_*` module or symbol outside tests in either repo (`git diff --diff-filter=A` + grep). `test_no_module_or_symbol_named_test_outside_tests` (`tests/test_testexec_store.py:597`) passes in the full run. `setup-composer/tests/` has no `__init__.py`. |

## First-pass findings against their 51-15 fixes (code level)

| Finding | Fix (where) | Regression test | Code verdict | Live |
|---|---|---|---|---|
| B1 Replay poll loop | The runner remembers job ids it saw end and never resumes one; on a terminal job it nulls `replay_job` in the cached reads and refetches with `cancelRefetch: false` (`hooks.ts:84-131`) | `item.test.tsx`: succeeded and cancelled; poll count stops, ≤ 1 item read after (shown failing on the old code, 51-15 As built) | **Fixed** | step 23 NOT RUN |
| B2 report can call `/api` | `ReportsServer` on app port + 100: registered `report/` roots only, traversal/symlink/NUL/encoded refusals, 405 for non-GET/HEAD, 421 for a foreign `Host`, `nosniff`, `no-cache` on `index.html` (`reports_origin.py`); old route → 410 (`api/testing.py:293-303`) | `tests/test_reports_origin.py` (26, real socket) | **Fixed** | step 24 probe NOT RUN |
| B3 pause fails the run | `_intend_stop` per worker before the kill; `worker_exit`/`error`/`on_exit` ignored for an intended stop (`manager.py:255-274,363-384`); `note_progress` never overwrites a stop (`store.py:144-153`) | `test_pause_of_a_running_worker_pauses_and_resume_continues_from_the_checkpoint` (real worker, non-zero SIGTERM exit; `first.count == 1` proves the checkpoint resume) + `test_a_late_worker_exit_of_a_paused_worker_cannot_fail_the_resumed_run` | **Fixed**; see R-m1 for a newly reachable edge | step 22 NOT RUN |
| MJ1 `broken` forever | `_follow_script` is THE rule (`testexec_store.py:746-764`); bind → automated (`:677`), `record_run` passed → automated over broken (`:712-725`), triage → `mark_broken` (`:727-732`) | MJ1 paths through `RunManager._finalize` (51-15 As built) | **Fixed** | — |
| MJ2 contract form ignored | The contract comes only from the code: a literal is required (`library_service.py:401-410`); a `contract` field is refused (`:625-627`); `changed=False` on a no-op (`:642`); read-only `ContractTable` on the page | route + page tests, no-op save | **Fixed** | step 6 NOT RUN |
| MJ3 cancel → error, two `run.final` | Cancel claims `cancelled` by CAS before the kill and only the winner announces (`manager.py:386-400`, `store.py:126-142`) | `test_cancel_of_a_running_worker_ends_cancelled_with_exactly_one_run_final` (observer sees stored == announced, once), `test_finalize_is_single_shot_under_concurrent_callers` (8 threads), real-worker execution cancel in `test_testexec_execution.py` | **Fixed** | step 18 NOT RUN |
| m1 workflows' tsc outside `.pids` | `run_bounded` / `_own_group` (row 11) | +3 workflow tests | **Fixed** | — |
| m2 story iframe not sandboxed | no scripts, no same-origin; CSP on the served page | `verification.test.tsx` | **Fixed** | step 24 |
| m3 `trace_debug.json` left | `_drop_debug_trace` after stop and discard (`recording.py:109-116,288,341`); template `.gitignore` (`templates/gitignore.txt`) | yes | **Fixed** for new recordings (existing workspaces get the delete, not the ignore line) | step 4 |
| m4 heal near its bound | 600 → 900 s | — (a constant) | **Fixed** | step 4 re-measure |
| m5 → D28 | Actions never replay alone; promotion when a dependent passes (`library_service.py:878-930`, `finalizer.py:206-232`) | promote / stale hash / failing / verification never | **Fixed**; see R-m3, R-m4 | step 23 |
| m6 | with MJ1 | yes | **Fixed** | — |
| m7 → D31, m11b | `grid.tsx`, `grid-logic.ts`; Regression row opens the scenario (`RegressionView.tsx:244`) | `regression.test.tsx` | **Fixed** | step 20 |
| m8 CasesTable at 1280 | `min-w-[980px]`, fixed columns 780 (`CasesTable.tsx:90`); layout pin `min-w = fixed + 200 ≤ 982` | `testDesign.test.tsx` | **Fixed** (51-15 probe: 982 / Title 202 at 1280) | step 20 re-probe |
| m9 → D32 | View run, Open report, Cancel (`ExecutionPage.tsx:269-276`) | `executions.test.tsx` | **Fixed** | step 20 |
| m10 → D29 | `record_replay(report=, screenshot=)`, ANSI stripped (`testexec_store.py:46-47,379-395`); item read maps both onto the reports origin (`api/testing.py:655-661`) | mi-1 glue test, contract fixture re-recorded | **Fixed** | step 23 |
| m11a/c/d → D30, D32 | `CardHeader`; `?kind=` filter; execution page layout | tests listed in 51-15 | **Fixed** | step 20 |
| n1 / n2 | `__test__ = False`; runner comment | — | **Fixed** | — |
| Capture #2 "lost" | Finding: it waited at its escalate gate. Capture reads now carry `run_status` (`api/testing.py:832-841`) | `capture` fixture + test | **Fixed** | — |

## §2 Gates (all run by the reviewer, 2026-11-07)

| Repo | Gate | Result |
|---|---|---|
| genesis | `.venv/bin/python -m pytest -q -p no:warnings` | **1785 passed** in 585 s (= 51-17 As built), `pytest-genesis.txt` |
| genesis | `.venv/bin/ruff check genesis` | **All checks passed** |
| genesis | ruff on every Phase 51-changed `tests/*.py` | only `tests/test_db.py:16` unused `tempfile`, pre-existing since `a9aac7ff` (as the first pass found) |
| genesis | cross-repo tests run locally (`tests/test_testexec_library.py`, `test_testexec_compose.py`, `test_testexec_recording.py`, `-rs`) | **100 passed, 0 skipped**: the sibling checkout was found, so action-capture's and setup-composer's code rules ran against Genesis's save checks on the real scanner, and the replay generator parity and hash parity were checked. `gates/crossrepo.txt` |
| genesis | DB fresh → v28 | m0001–m0028 applied, re-run `[]`, FK check empty, integrity ok, 59 tables. `db/fresh.json` |
| genesis | DB real main v27 → v28 (copy of the backup) | applied `[28]`, re-run `[]`, FK empty before/after, integrity ok; only change `kb_test_captures.request_json`; every old column of every table hash-equal (only `schema_migrations` gained a row); 287 641 run events, 126 cases, 24 scenarios, 3 suites, 12 executions kept. `db/main-v27.json` |
| genesis | DB real userb v25 → v28 (copy) | applied `[26, 27, 28]`, re-run `[]`, FK empty, integrity ok; 11 new tables, `kb_test_scenarios.{setup_id, changes_shared_data}` and `kb_test_suites.{kind, app_uuid}` added; every old value equal (only `kb_sequences` gained its 3 rows). `db/userb-v25.json` |
| genesis | DB rebuilt main v25 with the Phase 49 data → v28 (the first pass's method, `db/rebuilt_v25.py`) | 126 cases, 24 scenarios, 136 steps, 139 story links, 448 object links, 287 641 events copied; applied `[26, 27, 28]`; old columns equal (only `kb_sequences` +3); suite high-water 139 kept; children still reference `kb_test_suites`; `RegressionStore.get_or_create` → id 140; the suite tree reads 34 cases; re-run `[]`. One FK orphan existed **before** m0026: my rebuild copied TS-000024 (a regression scenario) without its regression suite. The runner reported it as pre-existing and refused nothing, which is the m1′ tolerance working live. `db/main-rebuilt-v25.json` |
| genesis/web | `npx eslint .` | 0 errors, 20 warnings (the base count) |
| genesis/web | `npx tsc --noEmit` | clean |
| genesis/web | `npx vitest run` | **721 passed, 62 files** (= 51-17 As built) |
| genesis/web | bundle | `npx vite build --outDir /tmp/genesis-review/51-12-rerun/static-2b2cf9d`, then a 60 s wait, then `diff -r` against `web/static`: **IDENTICAL** (71 assets each); `git status --short web/static` empty |
| genesis-workflows | `ci/validate_library.py` | **PASSED (18 workflows)**, incl. the reliability lint and the internal-pin check |
| genesis-workflows | `ci/validate_skills.py` | **PASSED (4 skills)** |
| genesis-workflows | `pytest -q workflows --ignore=workflows/_fixtures` | **421 passed** (= 51-17 As built) |
| genesis-workflows | `ruff check` on the four testing workflows + `ci` | clean |
| playwright-appian | `npm run lint`, `npm run typecheck`, `npm run build` | clean (`dist/` is git-ignored) |
| playwright-appian | `npm test` | run 1 (sequential after the other gates): **2 failed / 1399**. `agent-act.test.ts` "a ref without an address…" and `agent-do.test.ts` "a new Appian error is a WARN…" both hit vitest's 5 s timeout; both files alone 25/25. Run 2 (idle apart from the two servers): **1 failed / 1399**, the same `agent-act` test; alone it takes 2.5 s. R-O1 |
| project-tracker | `pytest agent-system/tests` | **389 passed** |
| project-tracker | `genesis-ctx lint` | OK, 0 errors, 0 warnings, L0 ~23,845 / 24,000 |

## `genesis-ctx check` checklists (re-run)

Raw output: `check-genesis.txt` (372 files). genesis-workflows and playwright-appian printed in-session (48 and 25 files). project-tracker: no agent-system change since the first pass, so its checklist (OK ADR-077, L-088, L-100; the rest N/A) stands, with the gates re-run above. "As the first pass" = the line and its evidence are unchanged by the delta (re-checked against the delta diff).

### genesis (`check --since v0.80.0 --repo genesis`)

**ADRs**
- [OK] ADR-001 (§1.1; setup-composer is LangGraph-routed, its agents are nodes).
- [OK] ADR-002 (kiro_node turns).
- [OK] ADR-003.
- [OK] ADR-004 (no MCP on any new node).
- [N/A] ADR-005 · 007 · 008.
- [**OK, was VIOLATION**] ADR-009: pause now pauses and resume continues from the checkpoint (B3 fix + test). See R-m1 for an edge.
- [OK] ADR-010 (composer state holds artifact pointers; picked/compose/replay/result are run-folder docs).
- [OK] ADR-011 (§1.7).
- [OK] ADR-012 (`setup-composer/graph.py` imports only langgraph/genesis_core; Genesis reads its META only through `RunManager._meta`, `compose.py:175`).
- [N/A] ADR-013 · 016.
- [OK] ADR-017.
- [OK] ADR-018.
- [OK] ADR-019 (no `CORE_MAJOR` change; no genesis-core diff).
- [OK] ADR-020 (reports listener and testing dirs under Genesis's own roots).
- [OK] ADR-021 (as amended by the drafted ADR-082; no `pre_mutation` on the 4 QA-writing workflows).
- [OK] ADR-022 (replays pruned to 20; D29 evidence under `library-replays/`).
- [OK] ADR-023.
- [OK] ADR-024 (the composer's tsc/scanner/replay run under `asyncio.to_thread`; compose start is sync in the threadpool).
- [N/A] ADR-025.
- [OK] ADR-026 (the reports listener binds the same host after the bind guard, `cli/main.py:151-157`; `Host` check, 421).
- [OK] ADR-027 (§1.13).
- [**OK with R-m6**] ADR-028 (every API route is still under `/api`; the reports origin is a second static listener outside `/api`, a user decision D26 with no ADR amendment drafted yet).
- [OK] ADR-029.
- [OK] ADR-030 (m0028 forward-only, sync stores).
- [N/A] ADR-031 · 032 · 033.
- [OK] ADR-034 (skill 0.3.0 filesystem-provisioned; compose checks its version and section, `compose.py:165-173`).
- [OK] ADR-035.
- [OK] ADR-036.
- [N/A] ADR-037 · 038 · 039.
- [OK] ADR-040.
- [N/A] ADR-041.
- [OK] ADR-042.
- [N/A] ADR-043 · 044 · 045.
- [OK] ADR-046 (templates/scanner as package data; `sync_lib` brings old workspaces up).
- [OK] ADR-047 · 048 · 049 · 050 (§1.8).
- [OK] ADR-051.
- [N/A] ADR-053 · 054.
- [OK] ADR-055.
- [N/A] ADR-056–060.
- [OK] ADR-061 (ADR-084 draft) · 062 · 063.
- [N/A] ADR-064 · 065.
- [OK] ADR-066 · 067 (healing tier on the composer, `{1,1}`) · 068 (ADR-082 draft) · 069 (`skills=SKILLS` on compose/heal) · 071.
- [N/A] ADR-070 · 072–076.
- [OK] ADR-077 · 078 · 079 · 080 (no internal dependency entry added).

**Lessons**
- [N/A] L-001.
- [OK] L-002.
- [N/A] L-003 (the bus stays open on pause, asserted in the B3 test).
- [OK] L-004.
- [**OK, was VIOLATION**] L-005: one `run.final{cancelled}` per cancel.
- [N/A] L-007.
- [OK] L-008: an unexpected death still fails with its specific error (`test_an_unexpected_worker_death_still_fails_the_run`).
- [OK] L-009 · 010.
- [OK] L-011: compose, capture-setup and error-dependency fixtures recorded from real responses; `contract.test.ts`.
- [N/A] L-012.
- [OK] L-014 · 015.
- [N/A] L-016.
- [OK] L-017 (no chat change).
- [N/A] L-018.
- [OK] L-019 · 020 (composer `recursion_limit` 120) · 021 · 023 (`composed_from_run`, `proposals_from_run` defensive) · 024 · 025/027 · 026.
- [N/A] L-028/029.
- [OK] L-030.
- [N/A] L-031/032.
- [OK] L-033 (compose refuses without setup-composer ≥ 0.1.0 and the skill ≥ 0.3.0; Record refuses a setup request below action-capture 0.2.0, re-checked at Stop).
- [N/A] L-034/035/037.
- [OK] L-039.
- [N/A] L-040.
- [OK] L-041 · 042 (picked.json, library.json as files).
- [N/A] L-043–047.
- [OK] L-048.
- [N/A] L-049–051.
- [OK] L-053 (version skew handled by the gates above).
- [N/A] L-054/055.
- [OK] L-056 · 057 (owed at 51-13) · 058 (on-read settle + startup reconcile, failures logged) · 061 · 062.
- [N/A] L-063.
- [OK] L-064 · 065.
- [N/A] L-066/067.
- [OK] L-068 (reports origin `index.html` no-cache, `reports_origin.py:124-125`) · 069.
- [N/A] L-070–074.
- [OK] L-075 · 076.
- [N/A] L-077–080.
- [OK] L-081.
- [N/A] L-082 · 084–087.
- [OK] L-083 · 088 · 089 (settled out-of-tree bundle identical).
- [**OK in code, was VIOLATION**] L-090: `min-w-[980px]` from the measurement; the live re-probe is in step 20.
- [OK] L-091 (`claim_status`, `bind_run` and the compose lock are writes-first) · 092.
- [**OK, was VIOLATION**] L-093: store-then-announce, single-shot.
- [OK] L-094 (§1.9).
- [N/A] L-095.
- [OK] L-096 (`/testing/compose` adds no shadowing pair; the whole-route shadow test passes) · 097 (compose finalizer startup failure only under `holds_run_owner_lock`, `capture_finalizer.py:160`) · 098.
- [N/A] L-099.
- [OK] L-100.

**Gates:** pytest, ruff, web lint/typecheck/test, build: §2. kiro-agent-sdk has no diff, so it was not re-run.

### genesis-workflows (`check --since v0.24.0 --repo genesis-workflows`)

- **OK:**
  - ADR-001, 006 (`setup-composer/` folder package + `registry.json`), 010, 011, 012, 017, 018, 019, 021 (ADR-082 draft), 022, 029 (ADR-083 draft), 034, 035, 048 (no Appian credential read), 062, 067, 068 (ADR-082 draft), 069, 078, 080.
  - L-006 (setup-composer `graph:` topology mirrors its compiled nodes; the workflow test asserts it), L-009, L-013, L-020, L-021, L-022 (no custom reducer keys, so `from __future__` is safe), L-023, L-024, L-026, L-033, L-042, L-064 (compose is one setup per turn), L-075, L-076, L-092 (n1 fixed; no `tests/__init__.py`).
- **N/A:**
  - ADR-003, 005, 007, 014, 015, 020, 026, 030, 031, 033, 036, 037, 038, 039, 041, 045, 046, 056, 057, 058, 059, 061, 063, 065, 073, 074, 075, 076, 077.
  - L-017, L-025/027 (unchanged pin), L-029, L-030, L-045, L-049, L-051, L-053 (no core credential), L-056/057 (owed at 51-13), L-087, L-088, L-089, L-098, L-099, L-100.
- **Gates:** `validate_library` PASSED (18), `validate_skills` PASSED (4), `pytest workflows` 421, genesis pytest/ruff (§2).

### playwright-appian (`check --since v0.2.0 --repo playwright-appian`)

- **OK:** L-056 (owed at 51-13), L-057 (vendor + pins at 51-13), L-100.
- **N/A:**
  - ADR-011, 019, 026, 046, 063, 065, 074, 077, 080 (no Genesis surface).
  - L-017, 025, 027, 030, 045, 051, 087, 088, 089, 092, 098, 099.
- **Gates:** lint, typecheck and build clean; `npm test` 1–2 timeouts in full runs (R-O1).

## §3 Live acceptance — NOT RUN in this re-run

The QA and Dev environments are down (DNS). The user deferred steps 1–27. The instances are ready for them: DB v28, HEAD code, workflows and skill installed on main, leftovers cleaned. The probes `scripts/probes/reports-origin-isolation.mjs` (step 24) and `scripts/probes/testing-widths.mjs` (step 20) are read-only: their only POST goes to the reports origin and expects 405, and the width probe drives a Vite on :5174. They do not need QA, so they can run before QA is back. What must be checked live because the code review cannot:
- B1 (step 23).
- B2 (24, both instances; userb has no execution yet, so the probe will exit 2 there unless given `--report-url`).
- B3 (22).
- MJ2 (6).
- MJ3 (18).
- m8 / D31 / D32 widths and screenshots (20).
- F10 re-measure (14, and 26/27 for the 900 s composer and heal turns).
- R-MJ1 and R-m1 live (below).

## Findings (re-run)

### Blockers
None at code level.

### Majors
- **R-MJ1 (51-17): Genesis's reader of a data setup's extra roles disagrees with the scanner, so a valid multi-role setup can lose its extra roles everywhere but the save check.**
  - **The cause.** `generator.setup_extra_roles` cuts the options at the first `\basync\b|\bfunction\b|=>` (`generator.py:156,164-180`). In `defineSetup({ key, name, role, roles, outputs }, …)`, `name` comes before `roles` and is free text. So a name containing the word `async` or `function`, or `=>`, hides `roles`.
  - **Reproduced** (reviewer, `python -c` on the HEAD function):
    - `name: 'Evaluation approved'` → `(['approver'], False)`.
    - `name: 'Evaluation for async approval'` → `([], False)`.
    - `name: 'Draft => Approved'` → `([], False)`.
    - A comment inside the array, `roles: ['approver' /* … */]`, → `([], True)`.
  - **The other reader** is the save check (`library_service._setup_roles_problems`, `:415-440`) and the composer (`setup-composer/graph.py:254-316`). Both read the same file with `lib/scan-refs.mjs` and see `['approver']`.
  - **Effects.** For such a setup:
    - the library Replay signs in no extra role (`library_service._setup_roles` → `[]`) and `ctx.as('approver')` fails;
    - readiness does not require the approver test user (`Catalog.roles`);
    - the generated `setup:` project does not depend on `auth:approver` (`_config_ts`), so the setup fails unless another scenario happens to create `.auth/approver.json`;
    - verification scope misses the role (`verification.story_context`);
    - compose's m-3 check misses a picked setup's extra roles (`compose._extra_roles`).
  - **The worst path is a composed setup.** setup-composer's replay signs in the request's roles (`setup-composer/graph.py:731-744`), passes and is proven. Apply makes it a Ready `DS-` item, and then every execution blocks it.
  - **Missing test.** The tests cover literal, constant and spread roles only (`tests/test_testexec_compose.py:71-79`). None uses a name with those words, and none compares the generator with the scanner. This repeats 51-16's own lesson candidate: "two readers of one contract must be the same reader".
  - **Fix.** Read the extra roles from the scanner's output: the generator already has the committed files, and `RecordingService.library_snapshot` already reads `roles` that way (`recording.py:404-418`). Alternatively, parse the options object to its closing brace, skipping string literals and comments.
  - **Tests to add.** Names containing `async`, `function` and `=>`, and a comment in the array, through the generator, Replay, readiness and compose. Also a parity test: generator reading = scanner reading on every setup fixture of both repos.

### Minors
- **R-m1 (runs-worker; the code predates Phase 51, but the B3 fix makes it reachable for the first time): a paused run turns back into "awaiting gate" on any read in a new server process when an earlier, already-answered gate is its latest `run.final`.**
  - **The cause.** `pause()` stores `awaiting_input:paused` and logs no `run.final` (`manager.py:370-384`). After a restart no worker is tracked, so `reconcile_status` adopts the latest `run.final` (`manager.py:433-456`). If the run had answered a gate earlier, that marker is the gate marker.
  - **Reproduced** with the public API on temp dirs (`/tmp/genesis-review/51-12-rerun/probe_paused_reconcile.py`): after `pause` the run reads `awaiting_input:paused`; after one `reconcile_status` in a fresh `RunManager` it reads `awaiting_input:gate`.
  - **Where it bites.** action-capture, story-verification and setup-composer all have escalation gates with Retry. Retry at the gate, then Pause, then restart `serve`, and the run shows the old gate as pending instead of Resume. `fail_orphaned_runs` already says paused runs are never touched; the read-time reconcile does not keep that promise.
  - **Fix.** Skip `reconcile_status` for a `paused` record (as the sweep does), or log a pause marker that the reconcile reads.
  - **Tests to add.** That case, plus pause → restart → resume (step 22 should include a restart while paused).
- **R-m2 (51-16 / 51-17; D24 spirit): a replay can prove code the agent changed in the checkout.**
  - **Where the replay runs.** Both action-capture and setup-composer replay from an overlay of `<run>/checkout` (`setup-composer/graph.py:327-337,724`), a folder the agent can write. The prompts forbid it, but `kiro_node` trust is unchanged (ADR-083).
  - **What Genesis checks.** Direct uses are hashed from that checkout and compared with git (`_stale_reuses`, `_stale_composed`). That is fail-safe: a changed direct use counts as stale.
  - **What it does not check.** Everything further down the refs closure is compared only between Genesis's own git (`ws.show(commit, path)`, `proposals.py:315`) and the current hash, never with the bytes that ran. The same applies to `promote_proven_actions` after a recording's setup.
  - **Consequence.** An agent edit to, for example, an action inside a picked data setup can make the replay pass. Genesis would then mark Ready code that never passed.
  - **Fix.** Before `replay`, compare every library file in the checkout with the export commit, and fail the replay on any difference. Or replay from a fresh export the agent never saw.
  - **Test to add.** An agent-modified transitive file must leave the setup Draft.
- **R-m3 (D28 as built in 51-15/51-16/51-17): "used" means "imported".** `kb_test_refs` is the import index (`scan-refs.mjs`), and every proof walks it (`library_service.py:878-930`; action-capture's setup-first `replay_plan` gives every action in `uses` the setup's result, `action-capture/graph.py:510-523`). So an action that is imported but never called, or called only in a branch the run did not take, becomes Ready without ever running. The workspace `tsconfig.json` has no `noUnusedLocals` (`templates/tsconfig.json`), so even an unused import passes. **Fix (user decision):** add `noUnusedLocals` to the template (catches the plain case), and/or record per-action steps in the replay (`test.step` per action call) and prove only the actions whose step ran.
- **R-m4 (51-15 D28): a retired action can be restored only with evidence D28 can no longer produce.**
  - **Why.** Restore needs `replay_passed_at_hash` (`domain/transitions.py:231`). An action has no Replay (`library_service.py:944-947`), and `promote_proven_actions` touches only Draft actions (`:920`). A retired action is also not importable by a new save (51-07 §3, "non-retired catalog item").
  - **Consequence.** An action retired while its last evidence was stale or failed can never be restored; the only way out is Save as new.
  - **Fix (user decision).** Restore an action to Draft, or let Run dependents of a retired action's former users prove it.
- **R-m5 (51-07 / 51-15 MJ1): a case script cannot be removed.** The case-script API is `GET` and `PUT` only (`api/testing.py:740-768`). `TestScriptStore.delete` and its `not-automated` rule (`testexec_store.py:690-702`) are reachable only from a refused apply's rollback (`library_service.py:557-559`). This re-run's cleanup hit it: the user asked to revert the TC-000007 and TC-000017 scripts, and there is no supported way to do it. A manual `git rm` would leave the DB binding and an import of a missing file. **Fix:** a "Remove script" on the case page (one commit + `delete`), or record that scripts are permanent (backlog).
- **R-m6 (51-13 docs): D26's reports origin is a backend surface outside ADR-028 ("ALL backend endpoints live under /api").** It is a deliberate user decision (51-01 D26) and is safe by design (static files, no `/api`), but `adr-drafts.md` has no ADR-028 (or ADR-026) amendment for it. **Fix (genesis-docs at 51-13):** amend ADR-028 with the reports origin's scope and rules, and mention it in ADR-026's network-surface note.

### Nits
- **R-n1 (51-15):** the old worker's late events after a pause are not fully dropped. `on_event` returns early only for an intended **cancel** (`manager.py:221-222`). For a pause, a late `node` event from the killed worker is still logged as `node.completed` and moves the cursor (`note_progress`), even after the resume has spawned a new worker. The window is milliseconds; returning early for any intended stop would close it.
- **R-n2 (51-15):** `_promote_actions` runs synchronously on the run reader thread (`finalizer.py:199-204`), with one `git show` per file of the closure. That is fine at today's library size; consider `self._defer` like the next-queued start.

### Observations
- **R-O1 (playwright-appian, outside the range):** `tests/cli/agent-act.test.ts` "a ref without an address acts on the element…" timed out at 5 s in both full runs (2.5 s alone). It was last changed in `e239bab`, before v0.2.0. Together with the first pass's O2 that is three of three full runs on this machine. 51-13's release gate runs this suite: give that test a longer timeout, or find why it slows under load, before tagging.
- **R-O2 (fleet):** main and userb now run HEAD `2b2cf9d` code on DB v28. Only main has the Phase 51 workflows. `/openapi.json` reports 0.80.0. The genesis `README.md` DB line is still "m0001–m0024" (now v28). These are for genesis-docs / genesis-release.
- **R-O3:** the composer's start lock covers the check and the capture insert. The run starts after the lock and `bind_run` follows. A run that ends before the bind is settled on the next read (51-17 decision j); the code matches the decision (`compose.py:188-228`).

## Verdict: NEEDS_CHANGES

- **Static review:** checks 1, 3–7 and 9–15 OK; 2 OK with R-m2; 8 OK with R-m4. Every first-pass blocker, major, minor and nit is fixed in code with a regression test. One new major (R-MJ1) and six new minors.
- **Gates:** all green except playwright-appian `npm test` (1–2 timeouts per full run, a test outside the range, R-O1).
- **Live acceptance:** NOT RUN (QA and Dev down). 51-12 cannot SHIP until steps 1–27 pass.

| Finding | Owner | Fix in one line |
|---|---|---|
| R-MJ1 | 51-17 (genesis `generator.py` + callers) | one reader for a setup's extra roles (the scanner's), with tricky-name tests and a generator = scanner parity test |
| R-m1 | runs-worker (`manager.py`) | the read-time reconcile never moves a `paused` run; test pause → restart → read → resume |
| R-m2 | 51-16 / 51-17 (workflows) | a replay refuses a checkout whose library files differ from the export commit |
| R-m3 | D28 (user decision) | prove only the actions a replay ran (per-call steps) and/or `noUnusedLocals` |
| R-m4 | D28 (user decision) | a path back from Retired for an action |
| R-m5 | 51-07 (user decision) | Remove script on the case page, or document scripts as permanent |
| R-m6 | 51-13 genesis-docs | ADR-028 / ADR-026 amendment for the reports origin |
| R-O1 | 51-13 / playwright-appian | stabilise `agent-act.test.ts` before the release gate |

After R-MJ1 is fixed (and the minors are fixed or moved to `specs/backlog/phase-51-follow-ups.md`), the next step is a delta re-review of that fix, then §3 steps 1–27 live once QA is back.

---

# Re-run 2 — the 51-18 delta, code level (genesis-review, 2026-11-08)

**Ranges reviewed** (every sha resolves and is the repo's HEAD; all three trees clean apart from the user's own
playwright-appian `.gitignore` line, O3 of the 51-18 review):

| Repo | Range | Commits |
|---|---|---|
| genesis | `2b2cf9d..346f885` (51 source files outside `web/static`) | `51e55f9`, `e75a668`, `2d1adb7`, `96354a8` (bundle), `0a5d342`, `346f885` |
| genesis-workflows | `69bface..6218803` (14 files) | `6218803` |
| playwright-appian | `5d7ae2d..f00cebb` (2 test files) | `0950798`, `f00cebb` |

**Read:** the 51-12 pack (`genesis-ctx pack 51-12`, 50.2K tokens, OK); the Re-run section above; the 51-18 spec, its As
built and its review (first pass and delta re-review); the diffs of `runs/manager.py`, `testexec/{roles, generator,
library_service, finalizer, replay, workspace}.py`, `domain/{transitions, lifecycle}.py`, `integrations/apwt/factory.py`,
`api/testing.py`, the templates (`lib/index.ts`, `lib/scan-refs.mjs`, `tsconfig.json`), the web diff
(`AutomationBadge.tsx`, `logic.ts`, `lib/api/testing.ts`, types, fixtures), the workflows' `test-execution/graph.py`
and the drift and replay code of `setup-composer/graph.py`; the whole of the m5 commit `346f885`.

**Scope, decided by the user on 2026-11-08.** The QA and Dev environments are down. The user runs live acceptance
(steps 1–27) and asked me for the rework review only. So **Part 2 (installs + restarts), Part 3 (the two no-QA probes)
and Part 4 (live steps) were NOT done in this session**, and I made no change to the user's machine: no install, no
restart, no fleet command. Evidence folder: `/tmp/genesis-review/51-12-rerun2/`.

## Each re-run finding against its 51-18 fix

| Finding | Fix at HEAD | Regression test | Verdict |
|---|---|---|---|
| R-MJ1 two roles readers | `testexec/roles.py`: one reader over Genesis's template `scan-refs.mjs` in a scratch folder with the workspace's TypeScript, cached by text hash; `case_role_of` / `setup_roles_of` interpret the scanner's `defines`. Every consumer goes through it: `generator.build_catalog(role_reader=)` (`generator.py:178,216,227,264,278`), `execution_service.py:120`, `verification_service.py:101`, `verification.py:254,405,416`, `compose.py:157-167`, `library_service.py:393,1043`, `api/testing.py:756`. The regex readers are gone (`grep setup_extra_roles\|case_script_role\|_CALLBACK_RE genesis/` finds nothing). The scanner lists a non-string literal `role` as dynamic (`scan-refs.mjs:112-113`). | `test_testexec_roles.py`: `async` / `function` / `=>` in the name, block and line comments in `roles`, 8 case-option shapes, scanner failure → not automated with the reason, recording = fresh real scan, cross-repo parity | **Fixed** |
| R-m1 paused run turns into an old gate | `reconcile_status` returns a `paused` record unchanged (`runs/manager.py:445`) | `test_a_read_in_a_new_process_leaves_a_paused_run_paused` (`test_runs.py:878`, the earlier probe), `test_pause_then_restart_then_resume_continues_from_the_checkpoint` (`:893`, real worker) | **Fixed** |
| R-m2 replay can prove agent-edited code | `TestWorkspace.library_drift` compares `actions/ setups/ cases/ lib/` of the checkout with the export commit by git blob id, in the workspace repository outside the run folder (`workspace.py:513-538`); `ApwtFactory.library_drift` (`factory.py:85-90`). Both capture workflows check it before **every** replay, so a heal cannot get past it (`setup-composer/graph.py:773-782`, `action-capture/graph.py:703-716` + its replay). The replay writes its own spec and config (`setup-composer/graph.py:787-789`), so a checkout `playwright.config.ts` edit does not run either. | drift end to end in both workflows (`replay["drift"] == [...]`), `library_drift` on a real export | **Fixed** |
| R-m3 "used" = "imported" | `noUnusedLocals` in the template (`templates/tsconfig.json:7`), brought to old workspaces by Update testing runtime in its own typechecked commit; `defineAction` wraps every call in `test.step('<key> <name>')` (`templates/lib/index.ts:74`); `replay.action_steps` / `passed_action_keys` (`replay.py:185,206`); the finalizer proves only actions whose own step passed in a passed scenario or setup project, and nothing from test-execution < 0.1.1 (`finalizer.py:228-239`); test-execution 0.1.1 reports `actions` per scenario and per setup project | real tsc refuses an unused import; a real Playwright 1.59.1 report of nested action steps; parity of the three workflow copies; called → promoted, imported-not-run / branch not taken / failed step / old workflow → Draft | **Fixed** |
| R-m4 retired action cannot be restored | `ACTION_TRANSITIONS` adds `(retired, restore) → draft` with no precondition (`transitions.py:256-260`), used only for `TEST_ACTION` (`lifecycle.py:379-394`); setups keep restore → Ready after a passing Replay; toast "Restored to Draft — Run dependents to make it Ready" (`logic.ts` `transitionMessage`) | store test (audited `retired → draft`), setup unchanged, `item.test.tsx`, `logic.test.ts` | **Fixed** |
| R-m5 a case script cannot be removed | `DELETE /applications/{app}/test-cases/{case_key}/script` (`api/testing.py:769-785`) → `remove_case_script` (`library_service.py:826-860`): one commit, binding and refs deleted, case `not-automated`; 404 without a script; 409 naming every queued or running execution that uses the case, checked at once and again inside the workspace lock (L-091). Web: **Remove script** + `ConfirmDialog` + the refusal in place (`AutomationBadge.tsx` `CaseScriptView`) | route, one commit, second remove 404, running / queued / running-verification refusals, `phase49.test.tsx` with jest-axe, contract fixture `case-script-remove` | **Fixed** (incl. m5 below) |
| R-m6 ADR-028 amendment | Docs, not code: carried in 51-13 §3 ("Also (51-12 re-run R-m6) … amend ADR-028 … note it in ADR-026") | — | **Carried to 51-13** |
| R-n1 a paused worker's late events | `on_event` returns at once for any intended stop (`manager.py:220`); `on_exit` likewise (`:271`); per worker, so the resumed worker's events count. Decision (d): a paused worker's late terminal `final` is dropped too. | `test_a_late_node_event_of_a_paused_worker_is_dropped` (`test_runs.py:822`), `test_a_paused_workers_late_terminal_final_is_dropped_and_resume_finishes_the_run` (`:849`) | **Fixed** |
| R-n2 promotion on the reader thread | `self._defer(promote)` (`finalizer.py:207`), failures still logged | `test_action_promotion_runs_through_the_defer_off_the_reader_thread` | **Fixed** |
| R-O1 playwright-appian CLI timeouts | `agent-act` and `agent-do` tests have an explicit `30_000` with the measured times in a comment (`agent-act.test.ts:66-83`, `agent-do.test.ts:149-163`); bodies unchanged | 3 consecutive green full runs (below) | **Fixed** for both named tests; see O5 |

## 51-18's delta-review m5 fix (`346f885`, not re-reviewed before)

- **What changed.** `_executions_running` (`library_service.py:798-824`) now reads every queued **and** running
  execution of the app in one way. It takes the plan's steps (a launched adhoc, impact or regression execution), the
  `scenario_ids` plus any plan ids, resolved through `kb_test_scenario_steps WHERE case_id=?`, and a verification's
  `case_keys`. The running branch no longer depends on a plan, which a verification never gets
  (`verification_service.py:203-207,279-281`: its running selection is the queued one plus `resumed`).
- **Shape check (L-083).** The selection keys the code reads are the real ones: `scenario_ids` holds ints
  (`verification_service.py:203`), and `case_keys` holds `TC-` keys (`:206`). The test builds a subset of that shape
  (`scenario_ids` or `case_keys`, plus `resumed`) and moves the execution to running with the real `set_running`.
- **Regression proof.** I exported `0a5d342` to `/tmp/g51-m5-old` and copied in the HEAD
  `tests/test_testexec_execution.py`. Both cases of `test_a_running_story_verification_also_refuses_remove_script`
  (`[scenario_ids]`, `[case_keys]`) fail there with `DID NOT RAISE CaseScriptInUse` (`:1002`). The queued test still
  passes there. All three pass at `346f885`.
- **Lock (L-091).** The check runs once before the lock, without a typecheck (`:855`), and again inside the workspace
  lock in `before_commit` (`:847`). A verification is queued until `prepare` calls `set_running` and exports its
  checkout, so the in-lock check sees it either as queued (`scenario_ids`) or as running (the same keys). There is no
  gap between the two states.
- **Verdict: fixed.** The 409 text, the docstring and the dialog ("queued or running") now hold for every kind of
  execution.

## Gates (all run by the reviewer, 13:22–13:55 IST, outside 00:00–02:00)

| Repo | Gate | Result |
|---|---|---|
| genesis | `.venv/bin/python -m pytest -q -p no:warnings --deselect tests/test_config.py::test_server_readiness_probe` | **1832 passed, 1 deselected** in 660 s (= 1829 + the earlier O2 flake now passing + the 2 m5 cases). O2 (`test_regression_job_handler_starts_due_apps_and_skips_busy_ones`) passed because the run was outside 00:00–02:00 IST. The deselected test is O1 (Docker is installed, so it attempts a real handshake); nothing under `genesis/config`, `integrations/mcp*` or `tests/test_config.py` changed in the range. A first attempt in the background was killed by the tool's 120 s limit at 27% and is discarded. |
| genesis | `ruff check genesis` + every changed test file (14 files) | All checks passed |
| genesis | cross-repo tests locally: `pytest -rs tests/test_testexec_{roles,library,compose,recording}.py` | **132 passed, 0 skipped** (the sibling genesis-workflows checkout was found, so the real-scanner, parity and hash tests ran) |
| genesis web | `npm run lint` | 0 errors, 20 warnings (the base count) |
| genesis web | `npm run typecheck` | clean |
| genesis web | `npx vitest run` | **726 passed, 62 files** |
| genesis web | stale bundle: `npx vite build --outDir /tmp/genesis-review/51-12-rerun2/static-346f885`, a 30 s wait, then `diff -r` against `web/static` | **IDENTICAL**; then `git status --short --untracked-files=all` empty, in its own call |
| genesis-workflows | `ci/validate_library.py` | **PASSED (18 workflows)**, incl. the reliability lint and the internal-pin check |
| genesis-workflows | `ci/validate_skills.py` | **PASSED (4 skills)** |
| genesis-workflows | `pytest -q workflows --ignore=workflows/_fixtures` | **428 passed** |
| genesis-workflows | `ruff check` on action-capture, setup-composer, test-execution, story-verification, `ci` | All checks passed |
| playwright-appian | `npm run lint`, `npm run typecheck` | clean |
| playwright-appian | `npm test`, each run issued alone (L-089) | Run 1 (load 5.1 at the start, `softwareupdated` at 186% CPU): **2 failed / 1399**. The failures were `tests/agent/browser/act.test.ts` "refs without an address … fill, click and press" (5005 ms) and `tests/agent/browser/observe.test.ts` "the Appian error dialog is in the snapshot" (5004 ms); alone they take 2497 ms and 518 ms (O5). Runs 2, 3 and 4: **1399/1399 each** (three consecutive greens; load 9.9–17.8 from the OS updater). `agent-do.test.ts` file 29.7 s / 30.6 s, `agent-act.test.ts` 24.3 s / 25.9 s, inside their explicit timeouts. |

## `genesis-ctx check` checklists (51-18 delta)

Raw output: `check-genesis.txt` (114 files incl. `web/static`). genesis-workflows (14 files) and playwright-appian
(3 files incl. the uncommitted `.gitignore`) were printed in-session. Every N/A means the delta does not touch that
surface; the earlier re-run's answers for the whole Phase 51 diff stand where the delta changes nothing.

### genesis (`check --since 2b2cf9d --repo genesis`)

**ADRs**
- [OK] ADR-001: no agent orchestrates. The new code is program code (scanner reader, drift check, proofs).
- [OK] ADR-009: pause stays paused across a new process (R-m1) and wins over a late worker `final` (R-n1, decision d). Both are tested with a real worker.
- [OK] ADR-010 / ADR-018 / ADR-022: `results.json` `actions` and `replay.actions` are small lists in run-folder documents. No bulk data goes into state.
- [OK] ADR-011: no agent node added (workflows below).
- [OK] ADR-012: the workflows carry copies of `action_steps`, pinned by parity tests. Genesis reaches the workspace only through `ctx.extras['apwt']` (`factory.py:85-90`), and the app imports no workflow Python.
- [N/A] ADR-008 · 019 · 023 · 025 · 026 · 031–035 · 037 · 041–045 · 047 · 049 · 054–060 · 063–065 · 070 · 072–076 · 080: not touched by the delta (no core, bind, chat, credits, KB, Hub, stage, spec or packaging change).
- [OK] ADR-021 / ADR-068: no `pre_mutation` change. Remove script deletes a workspace file through a commit (history kept), not an Appian object.
- [OK] ADR-024: the scanner and git calls are blocking. They run in sync FastAPI routes (threadpool; `get_case_script` and `delete_case_script` are `def`), in the deferred finalizer, or in the worker's `asyncio.to_thread` replay (`setup-composer/graph.py:820`).
- [OK] ADR-027: `Button`, `Trash2` and `ConfirmDialog` come from the existing primitives. Colors use the `text-danger` token, and no raw palette class was added.
- [OK] ADR-028: the new DELETE is under `/api` through the router. The client adds `/api` centrally (`testingApi.removeCaseScript`).
- [OK] ADR-030: no migration (DB stays v28). SQL stays in the stores, plus one read-only `SELECT` in the service (the pattern already in that file).
- [OK] ADR-050: action restore goes through `LifecycleService.transition` with the new table (`lifecycle.py:379-394`), audited. Remove script changes `automation_status` through `TestScriptStore.delete`, the store's existing rule.
- [OK] ADR-061 / 062: no lane change.
- [OK] ADR-066: run evidence is unchanged.
- [OK] ADR-067: healing is bounded as before, and the drift check repeats on every replay, so a heal cannot bypass it.
- [OK] ADR-069: no skills change.
- [OK] ADR-071: the Remove script action sits on the canonical case page; no new surface.
- [OK] ADR-077: one-call retrieval, a pack, never `--trust-all-tools`.
- [OK] ADR-078 / 079: cases keep Draft → Ready → Retired. Removing a script removes only that case's script binding and refs; the case record stays.

**Lessons**
- [N/A] L-003 · 010 · 016 · 017 · 018 · 019 · 021 · 031 · 041–043 · 045 · 048 · 050 · 051 · 059 · 060 · 063 · 066 · 071–074 · 082 · 084–087 · 095 · 098 · 100: not touched.
- [OK] L-004: SQLite stores only.
- [OK] L-005: no new event kind, and still one `run.final` per terminal (m4 test).
- [OK] L-008: an unexpected death still fails with its specific error. The stop check runs first, and `test_an_unexpected_worker_death_still_fails_the_run` is in the green full run.
- [OK] L-009: no sync invoke.
- [OK] L-011: new contract fixture `case-script-remove`, and re-recorded `capture-*` fixtures with `replay.actions`. `contract.test.ts` passes.
- [OK] L-020: no new loops.
- [OK] L-023: `action_steps` and `passed_action_keys` are defensive about types.
- [OK] L-025 / 027: ruff pin unchanged and green.
- [OK] L-026: no blocking DB write on an event loop (above).
- [OK] L-030: the web change is committed with its bundle (`96354a8`), and the out-of-tree build is identical.
- [OK] L-033 / L-053: recordings need action-capture ≥ 0.2.2 and compose needs setup-composer ≥ 0.1.1, refused at Start and at Stop (`recording.PROOF_WORKFLOW_VERSION`, `compose.COMPOSE_WORKFLOW_VERSION`). An old test-execution proves no action, and that is logged.
- [OK] L-039: the GET case-script and the catalog read roles through the same reader.
- [OK] L-056: every commit holds its implementation and tests; the tree is clean.
- [OK] L-057 / 099: the pin move is required at 51-13 and stated in 51-13 §1.4. The editable dev venv hides it locally (51-18 n6).
- [OK] L-058: promotion failures are logged loudly inside the deferred job.
- [OK] L-061: no restart was done by me.
- [OK] L-062 / 065: unchanged.
- [OK] L-064 / 075 / 076: no agent turn shape change.
- [OK] L-068: unchanged.
- [OK] L-069: no `<Button asChild>` in the delta. The new `Button` is plain.
- [OK] L-081: the new `noUnusedLocals` default reaches old workspaces only through the user's Update testing runtime, which refuses with `file:line` and keeps the rest of the update (`RuntimeUpdateRefused`).
- [OK] L-083: real scanner recordings re-checked against a fresh scan, a real Playwright report, and real selection shapes in the m1 and m5 tests.
- [OK] L-088: my shell guard refused `rm -rf` in `/tmp`, and I worked around it with a fresh folder, not by bypassing the guard.
- [OK] L-089: the bundle was proven by a rebuild and then an empty status, each in its own call. playwright-appian runs were issued one per call.
- [N/A] L-090: no table or width change.
- [OK] L-091: the busy check runs again inside the workspace lock, and the claim/CAS writes are unchanged.
- [OK] L-092: new tests have unique `test_*` names. `genesis/testing/scan_recording.py` is not named `test_*`, and `test_no_module_or_symbol_named_test_outside_tests` passes.
- [OK] L-093: m4's test goes through the real `_finalize`, and promotion stays after the stored terminal.
- [OK] L-094: no registry value added. `ACTION_TRANSITIONS` is a separate table used only for `TEST_ACTION`.
- [OK] L-096: the new DELETE `…/test-cases/{case_key}/script` has no shadowing pair (testdesign's `DELETE /test-cases/{case_id}` has a different prefix), and `test_no_route_is_shadowed_by_an_earlier_path_parameter_route` passes.
- [OK] L-097: no startup sweep change.

**Gates:** pytest, ruff, web lint, typecheck, vitest and the bundle are green (above).

### genesis-workflows (`check --since 69bface --repo genesis-workflows`)

- **OK:**
  - ADR-001, 006 (folder packages; `registry.json` and `workflow.yaml` bumped with `META`), 010, 011 (no agent node added; `validate_library` reliability lint passes), 012 (copies, parity-pinned), 017, 018, 019, 021 (no `pre_mutation`; QA-only, ADR-082 draft), 022, 067 (drift re-checked on every replay inside the heal loop), 068, 077, 078, 080.
  - L-006, L-009, L-013 (parity lint passes), L-020, L-022, L-023, L-026 (replay in `to_thread`), L-033 (version bumps match Genesis's gates), L-056, L-057 (owed at 51-13, stated), L-089, L-092 (no `tests/__init__.py` added).
- **N/A:**
  - ADR-003, 005, 007, 014, 015, 020, 026, 029, 030, 031, 033, 034, 035, 036, 037, 038, 039, 041, 045, 046, 048, 056–059, 061–063, 065, 069, 073–076.
  - L-017, L-021, L-024, L-025/027 (unchanged pin, ruff green), L-029, L-030, L-042, L-045, L-049, L-051, L-053, L-064, L-075, L-076, L-087, L-088, L-098, L-099, L-100.
- **Gates:** `validate_library` PASSED (18), `validate_skills` PASSED (4), `pytest workflows` 428, genesis pytest and ruff (above).

### playwright-appian (`check --since 5d7ae2d --repo playwright-appian`)

- [N/A] ADR-011, 019, 026, 046, 063, 065, 074, 080: two test timeouts only.
- [OK] ADR-077.
- [N/A] L-017, 025, 027, 030, 045, 051, 057, 087, 088, 092, 098, 099, 100.
- [OK] L-056: the two commits hold the two test files only. The `.gitignore` line is uncommitted (O3) and must stay out of the 51-13 release commit unless the user says otherwise.
- [OK] L-089: four runs, one per call.
- **Gates:** lint and typecheck clean; `npm test` three consecutive greens (runs 2–4) after one loaded run with two timeouts outside the range (O5). `npm run build` is release-only.

## Findings (re-run 2)

### Blockers
None.

### Majors
None.

### Minors
None.

### Nits
- **N1 (R-MJ1, new path):** `GET …/test-cases/{case_key}/script` drops the scanner's error.
  - `api/testing.py:756-758` takes `.role` from the reading. When it is `None`, the route shows `UNREADABLE_ROLE_WARNING` ("write the role first … as a plain string literal").
  - Since R-MJ1, a `None` role can also mean that the scanner could not run (`RoleReading.error`, e.g. "the test workspace is not installed (no node_modules/typescript …)" or "node is not installed"). The page then gives the wrong advice.
  - The generator path keeps the reason (scenarios are "not automated" with it), so only the case page's hint is affected.
  - **Fix (optional):** when `reading.error` is set, return that error as the warning instead.

### Observations
- **O1 / O2** (51-18 review): unchanged. O2 passed in this run (13:30 IST); keep it in the backlog.
- **O5 (playwright-appian, outside the range):** under external load (`softwareupdated` at 186% CPU), two more in-process tests hit vitest's 5 s default: `tests/agent/browser/act.test.ts` "refs without an address … fill, click and press" (2.5 s alone) and `tests/agent/browser/observe.test.ts` "the Appian error dialog is in the snapshot" (0.5 s alone). Neither file changed in the range. Together with R-O1 and O4, the suite has several tests with less than 2× margin to 5 s under load. For 51-13, run the release gate on an idle machine (51-13 §1.5 already says so). If it recurs, consider a suite-wide `testTimeout` for `tests/agent/browser/**` instead of per-test fixes.
- **n6 / n7 / R-m6** are carried in 51-13: the pin move (§1.4), the area globs (§3 "Areas"), and the ADR-028 / ADR-026 amendment (§3 "ADRs").

## Not done in this session (user decision)

- **Part 2:** no `genesis install` of test-execution 0.1.1, action-capture 0.2.2 or setup-composer 0.1.1, and no restart. The instances still run the HEAD code from the editable venv (so the Genesis-side 51-18 code is live after a restart), but the installed workflows are the older 0.1.0 / 0.2.1 / 0.1.0. With those, Record and Compose refuse (409) by design until the new versions are installed.
- **Part 3:** `scripts/probes/reports-origin-isolation.mjs` (step 24) and `scripts/probes/testing-widths.mjs` (step 20, with the compose dialog and picker) were not run.
- **Part 4:** live steps 1–27 are with the user. That includes the m5 live check: Remove script must be refused while a story verification that uses the case is running.

## Verdict: SHIP (code level)

Every re-run finding (R-MJ1, R-m1–R-m5, R-n1, R-n2, R-O1) is fixed in code, and each fix has a test that would have
caught the original bug. R-m6 is a docs item carried to 51-13. 51-18's delta-review m5 fix is correct and proven
against `0a5d342`. Every gate is green in my runs. The only red was one playwright-appian run under OS-updater load,
in tests outside the range, followed by three consecutive greens. The one new nit (N1) does not block.

**51-12 as a whole is not closed by this verdict:** it SHIPs when the user's live steps 1–27 pass, after the Part 2
installs and restarts (L-061) and the two Part 3 probes.

## Re-run 2, continued: Part 2 (setup) and Part 3 (the no-QA probes), 2026-11-08 14:06–14:20 IST

The user asked for Parts 2 and 3, with a question before each change. This supersedes the "Not done in this session"
list above for Parts 2 and 3. Part 4 (live steps 1–27) is still the user's. Evidence: `/tmp/genesis-review/51-12-rerun2/`
(`backup/`, `probes/`).

### Part 2 — installs and restarts (each change approved by the user first)

| # | Change | Result |
|---|---|---|
| 1 | Back up main | `backup/main-20261108-140635.genesis.db`: SQLite online backup from a read-only source; integrity ok, v28, 428 runs, 0 non-terminal; lockfile copied beside it (`backup.py`) |
| 2 | Install on main: `gsm exec main -- install --from <genesis-workflows> test-execution action-capture setup-composer` | test-execution **0.1.1**, action-capture **0.2.2**, setup-composer **0.1.1** (ref `local`). Each installed `graph.py` is byte-identical to the checkout at `6218803`. story-verification stays 0.1.0, and the skill is unchanged. |
| 3 | Back up userb, then the same install on userb (the user chose both instances) | `backup/userb-20261108-140653.genesis.db`: integrity ok, v28, 119 runs, 0 non-terminal. The same three versions are installed, byte-identical. userb's lockfile went from 14 to 17 workflows. userb has no story-verification and no `genesis-test-authoring` skill (not asked for). |
| 4 | Restart main (`gsm restart main`), after a DB check: no non-terminal run, no queued or running execution, no recording or analysing capture | pid 14358 → **30385**, healthy. The log since the restart has no error or traceback, and the reports listener is on :8860. `/openapi.json` has `delete`/`get`/`put` on `/api/applications/{app_uuid}/test-cases/{case_key}/script` (the 51-18 code is live), and `info.version` is still 0.80.0 (pre-release). `GET /api/workflows/<id>` gives 0.1.1 / 0.2.2 / 0.1.1 / story-verification 0.1.0. |
| 5 | Restart userb (`gsm restart userb`), after the same check | pid 14393 → **30749**, healthy. No error in the log; the reports listener is on :8861 (`lsof`). The DELETE script route is present. The three workflows answer 0.1.1 / 0.2.2 / 0.1.1; story-verification is 404 (not installed). |

No migration (DB v28 on both). No run was active on either instance at either restart (L-061).

**My own process slips (L-089), with what I checked afterwards. No harm came from either.**
- **userb.** Its verify read, backup and install went out in one message and ran together. The order still held: the
  backed-up lockfile has 14 workflows and no test-execution, the live lockfile changed at 14:06:54 (one second after
  the backup), and the install did not touch `genesis.db` (last written 14:00:07).
- **main.** The restart and a verification read (with a 5 s wait) also went out together. I repeated the
  verification on its own afterwards; the results above come from that second read.
- **userb restart.** Its pre-restart DB check went in the same message as the restart. A separate read-only check a
  minute earlier, which I had reported to the user, was also empty.

### Part 3 — the probes (read-only)

**Step 24, `scripts/probes/reports-origin-isolation.mjs --base http://127.0.0.1:8760` (main): PASS, 12/12.**
- The probe loads TE-000012's HTML report (`http://127.0.0.1:8860/executions/test-execution/r-6f190dcfbac4/report/html/index.html`) from the reports origin.
- `nosniff` is set, and `index.html` is served `no-cache, must-revalidate` (L-068).
- From the report page:
  - a same-origin `/api/applications` → 404 (9 bytes);
  - a cross-origin `fetch` to :8760 is blocked (no CORS);
  - a `no-cors` fetch is opaque with 0 bytes;
  - an XHR is blocked.
- The origin refuses `../../etc/passwd`, `%2e%2e/%2e%2e/`, `/` and `/api/applications` (404 each) and a POST (405).
- Output: `probes/reports-origin-main.json`.

**Step 24, second instance (userb).** userb has no execution, so the probe has no report to load there. That needs an
execution on userb, which needs QA, and it stays in the user's live step 24. Read-only HTTP checks of both listeners
instead:

| Request | :8860 (main) | :8861 (userb) |
|---|---|---|
| `GET /` | 404 | 404 |
| `GET /api/applications` | 404 | 404 |
| `GET /executions/%2e%2e/%2e%2e/` | 404 | 404 |
| `POST /` | 405 | 405 |
| `GET /` with `Host: evil.example` | 421 | 421 |
| `X-Content-Type-Options` | nosniff | nosniff |
| main's report path, requested on :8861 | — | 404 (each listener serves only its own instance's reports) |

**Step 20, `scripts/probes/testing-widths.mjs --app _a-0000e5bc…_930416 --feature 4 --execution TE-000012,TE-000010`:
PASS, all 42 entries clean.**
- It ran Vite on :5174 from the HEAD source, at 1280/1440/1920 in both themes (`theme-light` / `theme-dark` confirmed on `<html>`).
- Tailwind resolved, and no page scrolls sideways. No table is wider than its card, no header wraps or is clipped, and no cell spills.
- Table widths at 1280 / 1440 / 1920:
  - Library, Executions, Regression and the execution pages' Scenario results: 982 / 1142 / 1350 px.
  - Setup Test users: 940 / 1100 / 1308.
  - Execution step tables: 950 / 1110 / 1318.
  - The Test Design Cases table (m8): 982 / 1142 / 1074. At 1280 its columns are Key 96, Title 202, Type 96, Priority 88, Status 80, Stories 92, Scenarios 100, Review 112, Automation 116, the same as the 51-15 probe.
- Output: `probes/widths/` (`result.json` + 42 screenshots).

**Step 20, the compose dialog and its picker: PASS on the automatic checks, with minor findings below.**
- `testing-widths.mjs` predates 51-17 and has no compose page (it has no "compose", "dialog" or "picker" in it; last
  changed in `f6d86ff`, 51-15). That contradicts the 51-12 spec's "The compose dialog and its picker are in the step-20
  width probe" (step 27). So I wrote a reviewer driver, `compose-dialog-widths.mjs` (in the evidence folder):
  - It opens Library → **New data setup** (the choice dialog), then **Compose with AI**, at 1280/1440/1920 in both themes.
  - It measures each dialog and the picker table the same way the probe measures tables, takes screenshots, and closes with Escape.
  - It aborts every non-GET `/api` request: **0 were attempted**.
- **Choice dialog:** 448 × 322 at every width, inside the viewport.
- **Compose dialog:** 768 × 900 at every width. That is `max-w-3xl` and `max-h-[90vh]`; it scrolls vertically, never sideways, and stays inside the viewport.
- **Picker table:** 724 px, all 5 library items. Columns: Pick 40, Key 100, Kind 96, Name 167, Role 104, Contract 217. No overflow, no header wrapping or clipped, no spilling cell.
- The driver's "filter-lines 3" value is a flaw in my metric: it counts distinct element tops in an `items-center` row. The screenshots show one line.
- **What the numbers do not catch, from the screenshots** (`probes/compose-widths/compose-dialog-*.png`):
  - In the 104 px Role column, `[overflow-wrap:anywhere]` breaks `contracting-officer` into "contracting / -officer" on every row.
  - The "Data setup" badge wraps to two lines in the 96 px Kind column; on the Library page it stays on one line.
  - The search placeholder is clipped ("Search key, name, area" cut off at `w-52`).
  - The Contract column is the right place for long text: ACT-000001's row is 133 px tall.
  - The dialog is the same 768 px at every viewport, so all six layouts are identical.

### Findings from Parts 2 and 3

- **Blockers / majors:** none.
- **Minor P1 (51-17 / 51-15, probe coverage): the step-20 width probe does not cover the compose dialog, although the
  51-12 spec says it does.** L-090 asks for column widths from a real-browser probe. The picker's widths (100 / 96 / 104 /
  30%) were never probed before this reviewer driver. **Fix:** add the choice dialog and the compose dialog to
  `scripts/probes/testing-widths.mjs` (open from Library, measure inside `[role=dialog]`, abort non-GET `/api`), so 51-13
  and later changes re-run it. My driver can be the starting point.
- **Minor P2 (51-17, compose picker layout, cosmetic):**
  - `contracting-officer` breaks mid-word in the Role column.
  - "Data setup" wraps to two lines in the Kind column.
  - The search placeholder is clipped.
  - **Fix:** give Role the room it needs for the longest real role key without breaking inside a word (e.g. drop `[overflow-wrap:anywhere]` on that cell, or widen Role to ≈ 152 px and take it from Contract's 30%). Let Kind fit "Data setup" on one line (≈ 104 px). Widen the search input or shorten the placeholder. Then re-probe. None of this hides data or blocks an action.
- **Observation P-O1:** userb's report isolation can be probed only after an execution on userb (needs QA). It is part of the user's step 24.

### Verdict after Parts 2 and 3: SHIP (code level), unchanged

Parts 2 and 3 found no blocker or major. The instances are ready for Part 4:
- both run HEAD (`346f885`) on DB v28;
- both have test-execution 0.1.1, action-capture 0.2.2 and setup-composer 0.1.1;
- main also has story-verification 0.1.0 and the skill 0.3.0;
- the reports listeners are up on :8860 and :8861.

P1 and P2 are minors for the developer, to fix before 51-13 tags or to move to the Phase 51 follow-ups backlog. They do
not block. 51-12 as a whole SHIPs when the user's live steps 1–27 pass. Stopped before Part 4.
