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
| 5 | Secrets | **OK (code)**; live step 19 pending | Passwords live under `testusers-<sha1>` in the SecretProvider (`settings_service.py:34-40`); reach only the Playwright child env (`runner.py:120`); the whole report folder is scrubbed in raw, JSON, `\u`-JSON and XML forms incl. the HTML report's embedded zip and nested trace zips (`runner.py:149-221`); apwt output scrubbed; `secret_values` is a scrub source only (`settings_service.py:207`). Tests: `test_scrub_reaches_the_html_reports_embedded_zip_and_trace_zips`, `test_scrub_catches_json_and_xml_escaped_passwords`, `test_every_phase_51_route_answers_without_a_secret` (`test_testing_api.py:533`), the workflow tests' state/checkpoint/event/file scans. A failed or cancelled verification run's `apwt-out` is not scrubbed by design (51-09 decision 11) — step 19 greps it. |
| 6 | Agent access to `apwt` (D3c, ADR-083) | **OK** | The prompt prefix is `cd <export> && PLAYWRIGHT_APPIAN_HOME=<run>/.apwt npx --no-install apwt -s <session>` (`client.py:372-377`, used at `story-verification/graph.py:681`); sessions are opened/closed by program nodes (`open_sessions`, `cleanup`); `kiro_node`'s trust-all is unchanged (`packages/genesis-core/genesis_core/nodes/agent.py:298-301`, no Phase 51 diff); ADR-083 draft names the accepted risks, P10 and Phase 52 (`adr-drafts.md:134-220`). |
| 7 | Reliability; no `pre_mutation` on QA-writing workflows | **OK** | `attach_reliability` on `segment` (`action-capture/graph.py:701`), `explore`, `author`, `propose` (`story-verification/graph.py:1201-1212`); `attach_healing` on `replay/heal` and `triage/heal` with `META.healing {1,1}` (`action-capture/graph.py:86,703`; `story-verification/graph.py:107,1206`); `validate_library` PASSED (17), incl. the reliability and HITL lints, with no `pre_mutation` in the three (grep). |
| 8 | Lifecycle | **OK** | Library status writes only through `TestLibraryStore.set_status` (`testexec_store.py:491-515`, the `LifecycleService` primitive, re-checks referrers in its transaction); no other `UPDATE … SET status` on actions/setups (grep); `LIBRARY_TRANSITIONS` keeps `TEST_TRANSITIONS` unchanged (`test_testexec_library.py`); captures/executions are CAS run records (51-04 decision 8); story lane edges via `build_story_lifecycle_service().transition` (`story_verification_finalizer.py:104,264-269`). |
| 9 | Lane order consumers (L-094) | **OK** | 51-09 As built §L-094 lists every consumer; `STORY_LANES` order and edges in `domain/transitions.py`; `test_lane_order_board_api_and_card_join`; `workbench.test.tsx` asserts the board renders the API order; web `lanes.ts` labels only. |
| 10 | Finalizers | **OK** | Bound-run guards (`story_verification_finalizer.py:153-160`, `finalizer.py` `test_bound_run_guard`), CAS idempotency (`StaleWriteError` → no-op, `:194-197`), startup + on-read reconcile (`:120-148`; `test_get_reconciles_a_finished_run_on_read`, `test_routes_start_409_view_report_and_on_read_recovery`); live tests end runs through the real `RunManager._finalize`, which stores before announcing (`runs/manager.py:146-151`). |
| 11 | Subprocesses: timeouts + process groups; nothing left after cancel/pause | **OK in genesis; minor gap in the workflows** | `run_bounded`/`start_long_lived` start every child with `start_new_session=True`, record the pgid in `<run>/.pids` and kill the group on timeout (`procs.py:9-11,158-190`); git, npm, tsc, scan-refs, apwt and Playwright all go through them (`workspace.py:126-139,294,416`); `RunManager` reaps `.pids` on finalize, pause and the sweep (`manager.py:154-169,337-344`). **m1:** the workflows' own `tsc` call (`story-verification/graph.py:549-551`, `action-capture/graph.py:279-281`) is a plain `subprocess.run` (no own group, not in `.pids`). Live step 18 checks `ps`. |
| 12 | DB | **OK** | Fresh → v27 and real-data v25 → v27 (§2); m0027 from a populated v26 is in `test_testexec_regression.py`; the collab feature tombstone takes `BEGIN IMMEDIATE` and writes the note before the generic delete (`collab/service.py:589-596`). Re-reviewed post-SHIP fixes: 51-08 n1 — `run_now` reads the selection once and passes it (`regression_service.py:258-261`, `execution_service.py:190-198`); 51-08 n2 — `RegressionScenarioBody(ScenarioCreate)` (`api/testing.py:339`); 51-04 m1′ — `foreign_key_check` compared on `tuple(r)[:3]` = `(table, rowid, parent)` (`db/runner.py:69,76-78`), with the tolerance + "added violation refused" tests and a rollback test. See nit **n2**. |
| 13 | Web | **OK, with m2 pending step 24** | Across the 57 changed web source files: no `<Button asChild>`, no `"/api` outside `lib/api/`, no `fetch(` outside `lib/api/`, no direct `lucide-react` import, no raw palette classes (grep); `LazyCodeEditor` and `PassRateChart` are `lazy()` (`LazyCodeEditor.tsx:7`, `RegressionView.tsx:25`); 9 new test files use jest-axe; `contract.test.ts` fixtures. **m2:** the story page report iframe (`VerificationSection.tsx:225`). |
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
- [OK] ADR-009 — the new workflows keep pause/resume/gates; gates `escalate`/`escalate_blocked` (`story-verification/graph.py:1180-1183`).
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
- [OK] L-004 — SQLite.  [OK] L-005 — no new event kinds.  [N/A] L-007 — transcript unchanged.
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
- **[PENDING]** L-090 — live step 20.  [OK] L-091 — lock first (`BEGIN IMMEDIATE`/CAS).  [OK] L-092 — §1.15.
- [OK] L-093 — store before announce; real `_finalize` tests.  [OK] L-094 — §1.9.  [N/A] L-095 (no object UUID written).
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

_In progress — filled step by step with the user._

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
| 3 | Setup: site, users, workspace | **PASS** (user + reviewer); password grep PENDING | Readiness clear; workspace is a git repo (`b2462a1` Create the test workspace, `b2eeea7` Install the testing runtime) with the template (`lib/`, `suites/`, `cases/`, `setups/`, `actions/`, `vendor/`); `.gitignore` covers `.auth/`, `.env*`, `output/`. |
| 4 | Record as role A | **PASS** (user + reviewer) | Capture #1 as `contracting-officer`; `action-capture` run `r-8ee5d311c719` done in 11 min 45 s: `segment` 159 s, 8 tool calls, **4.84 credits** (metered); first replay failed → `heal` **482 s of the 600 s `turn_timeout` (80 %)**, 9 tool calls, **12.72 credits** → replay passed (healing tier worked, ADR-067). See m4. Untracked `captures/1/trace_debug.json` left in the workspace (m3). |
| 5 | Accept / reject → one commit | **PASS (partial)** | The user accepted all four proposals (no reject exercised live; reject is covered by `test_testexec_recording.py`). One commit `eb64193` "Apply capture #1 …" = the 4 action files + `captures/1/trace.json`; ACT-000001..4 `ready` with audited `draft → ready approve` rows (replay passed at the code's hash). |
| 6 | Edit an action: type error, save, history, revert, editor themes | **PASS** (user + reviewer) for the parts without a user; **breaking contract while used** and **Save as new** PENDING (nothing references an action yet: 0 case scripts, 0 refs) | On ACT-000002: type-error save refused inline, nothing committed; `e4fd785` Update + audited `ready → draft changed` (17:48:22 UTC); `200f4e0` Revert to `eb64193`; then `draft → ready approve`. CodeMirror legible in light and dark (user). |
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

### Nits
- **n1 (genesis-workflows) —** `TestExecutionState` (`workflows/test-execution/graph.py:91`) is a `Test*` class outside
  tests without `__test__ = False` (L-092 rule; not collected today because no test module imports the name).
- **n2 (51-04) —** the m1′ tolerance key `(table, rowid, parent)` (`db/runner.py:69,76`) would also hide a *new*
  violation on the same row towards the same parent table through a different FK column. No current migration can
  produce one; a comment would do.

### Observations (not findings against the code)
- **O1 — the fleet is not in the state `context/state/current.md` describes.** The main instance (:8760, pid 89692,
  started 2026-11-04 17:35 IST from the editable dev venv) runs Phase 51 backend code from before 51-14 (`9b258bb`
  21:06) and its DB was migrated to v27 at 11:59 UTC; the SPA it serves from disk is HEAD's bundle (`cca8ff8`), which
  expects `verification_active`. `/openapi.json` still says 0.80.0. userb (:8761) runs pre-Phase-51 code (started
  2026-11-01) on DB v25. For genesis-docs / genesis-release.
- **O2 — playwright-appian test timing.** `tests/cli/agent-act.test.ts` (not in the Phase 51 diff) hit vitest's 5 s
  default under parallel load; green alone and on a full re-run.

## Verdict: PENDING (live acceptance in progress)
