# 51-01 — Findings: the test execution engine (script library, regression suite, story verification)

> **Status:** SPEC-DRAFTED 2026-11-02 — Q&A complete: decisions D1–D19 (§7), defaults F1–F14 (§8, confirmed).
> Parent: `specs/phase-51-test-execution-engine.md`.
>
> What was researched and decided before the spec set is written: the problem as the user stated it, how Genesis and
> `playwright-appian` work today (code-grounded), how the standards and other products handle it, the proposed
> architecture, the open questions, and every decision.

---

## 1. The problem (as stated by the user, 2026-11-02)

Part 2 of the testing framework. Phase 49 (part 1) records **what** to test (`TC-` cases, `TS-` scenarios, per-feature
suites, Test Impact). This phase decides **how** it is tested: automated scripts and the engine that runs them.

- **`playwright-appian` (`apwt`) is Genesis's browser-test tool.** It was built for Genesis: agents use it to
  understand and drive Appian interfaces, and what they do becomes a script that re-runs **without an agent**. It ships
  with Genesis as a pre-installed tool, like `gws`.
- **Part A — Script library (per application).** Create, edit, delete scripts; each has an identifier. A
  **Record workflow** button opens a browser; the user logs in and performs a flow; on stop, a workflow checks and
  formats the recording and stores it in the library **as modules** (create evaluation, add factor, add vendor, update
  factor, delete factor …), not as one monolithic script. The library is the single place scripts are written; every
  other place refers to it.
- **Part B — Regression pack (per application).** The full regression set for the app: all scenarios and cases, run
  daily or weekly. It is a set of **references** into the library (never copies) that stitches library scripts into
  scenarios. It must use **minimal test data**: not one evaluation per scenario; one shared evaluation for every
  scenario that can share it, and a separate one only where a scenario needs a different kind.
- **Part C — Story verification (the Workbench Verification lane).** When a story moves to Verification an agent:
  1. reads the story's test cases and scenarios;
  2. **explores** the app with `apwt` (no testing yet): visits the screens the story changed; the session is captured
     as scripts;
  3. **authors** the verification scripts: exploration captures + library scripts (e.g. "create evaluation" when the
     story is "add vendor"), stitched into one script per scenario/case;
  4. **runs** them: a failure sends the story back to Implementation;
  5. on a pass, an agent **updates the regression pack** with the story's scenarios and **adds new scripts to the
     library**;
  6. writes a **test execution report**.
- **The user's questions:** (Q-a) how to store scripts: database, JSON or something else; (Q-b) how Test Impact turns a
  set of changed objects into a runnable set of scripts; (Q-c) whether story scripts should reference library scripts by
  id and only write what the library lacks, rather than copy (the user leans to references: scripts change often).
- **The bar:** industry-standard design, a strong foundation that accommodates future change.

## 2. How Genesis works today (verified in the code, 2026-11-02)

Paths: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis`, `workflows/` =
`/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-workflows/workflows`.

### 2.1 Test Design (Phase 49) — the "what"

- m0025 (`genesis/genesis/db/migrations/m0025_test_design.py`): `kb_test_suites` **one per feature**
  (`feature_id UNIQUE`); `kb_test_cases` (`TC-`, `gherkin_json {given,when,then}`, `test_type`, `priority`, `status`
  draft·ready·retired, **`automation_status` default `not-automated`**); `kb_test_scenarios` (`TS-`);
  `kb_test_scenario_steps` (ordered case references, same case may repeat); `kb_test_case_stories`;
  `kb_test_case_objects` (by `(app_uuid, object_uuid)`); `kb_test_topups`. Hub-ready collab columns, unused.
- `automation_status` is written by nothing; read only by the case page badge, the CSV export and the TS type
  (`web/src/features/test-design/TestCasePage.tsx:86`, `genesis/services/testdesign_stage.py:281`,
  `web/src/types/testdesign.ts:59`). Phase 49 reserved it for this phase (`49-01-findings.md:145`).
- Everything is **per feature**; no application-level grouping of cases exists. Phase 49 deferred "app-wide regression
  suites + cross-feature case reuse; shared preconditions / shared steps" (`phase-49-test-design.md:133-135`).
- **Test Impact** (`genesis/services/testimpact.py`, `POST /api/applications/{app}/test-impact`,
  `genesis/api/testdesign.py:446`): from objects / a story / a KB sync, a BFS over inbound `kb_dependencies` (1–5 hops,
  default 2) → `suites[] → scenarios[] → cases[]` with `hop`; computed on demand, stored nowhere.

### 2.2 The Workbench lanes

- Lanes = story `status` (`genesis/domain/enums.py:40-51`). `STORY_STAGE_TRANSITIONS` already declares
  `(verification, verify) → deployment` and `(verification, reject) → implementation`
  (`genesis/domain/transitions.py:115-118`); nothing drives them. Only Design and Implementation launch runs
  (`genesis/api/workbench.py:179`, `:290`).
- The pattern to copy: `start_implementation` (fail-fast 409s → `story_stages.get_or_create(story, stage)` (m0018) →
  inputs written to the story-stage dir → `move_card` → `run_manager.start(...)` → bind run) and
  `StoryImplementationFinalizer` (`genesis/chat/story_implementation_finalizer.py`: `run.final` observer, reads
  `result.json` `decision`, bound-run + still-in-lane guards, audited `LifecycleService` transition, on-read and startup
  recovery; L-058, L-062, L-093).

### 2.3 Tools, agents, workers

- Managed CLIs (`genesis/cli_tools/native/installer.py`, ADR-040) are **single self-contained binaries** copied into
  `~/.genesis/cli-tools/<id>/versions/<v>/`; known ids `gws`, `sail`. No Node/npm tool, no browser provisioning; no
  Node detection at runtime (Node is used only to build the SPA).
- `CliRegistry` (`packages/genesis-core/genesis_core/clis/registry.py`) resolves a binary; `run()` passes no env and
  `cli_node` (`nodes/cli.py:26`) passes **no timeout**. Child processes of a killed worker are not reaped
  (`genesis/runs/supervisor.py:30-37`; no process group).
- Workflow agent nodes (`kiro_node`, `nodes/agent.py:195`) get **MCP tools only** (per-node, trust =
  `node.tools ∩ server.allowlist`, ADR-029) plus provisioned skills (ADR-069); **no shell tool** reaches a workflow
  agent today. `sail` is a program-only seam (`ctx.extras['sail']`), with no workflow consumer.
- The blackboard (`RunWorkspace`, ADR-010/022) is `<artifacts_root>/<workflow>/<run>/`. The generic artifact preview
  serves json/markdown/mermaid/csv/text only; images and HTML download but do not preview (`genesis/api/_shared.py`).

### 2.4 Scheduling, environments, credentials

- The scheduler (`genesis/runtime/scheduler.py`) runs a **fixed backend list** (`DEFAULT_JOBS`,
  `genesis/runtime/sync_jobs.py:37`; ADR-047); cadence = `daily_times` / `interval_window` (+ weekdays, timezone); only
  `application-sync` is user-editable; per-job config rides in `options_json` (m0023). No per-application schedules.
- `environments.json` has `url`, `api_endpoint`, `is_dev` (single-select); no site URL field
  (`genesis/config/environments.py:24`). Core creds (`LCP_USERNAME/LCP_PASSWORD/APPIAN_API_KEY`) live per environment
  in the SecretProvider and resolve only from the dev-tagged env (ADR-048, `resolve_var` `:201`). No store for **test
  user accounts** exists.
- No run concurrency cap (`genesis/runs/manager.py`); no notification of scheduled-job outcomes beyond Settings →
  General's last-run badge.

## 3. `playwright-appian` today (v0.2.0, `repo-gitlab/ramaswamy.u/playwright-appian`)

- **Trace = source of truth, spec = artifact.** `playwright_appian.trace.v1` (`src/core/types.ts:134,278-289`); additive
  optional fields are not a version bump, removals are v2 (`src/core/trace-schema.ts:15`). The generator is
  deterministic, LLM-free (D-02), and `generate` on a written trace gives the same spec (`src/agent/spec-writer.ts:4-6`).
- **Generated specs are flat.** One `describe` → `beforeEach` (`goto` start path on `SITE_URL`, `login(page)`) → one
  `test` (`src/generator/emit.ts:88-138`). No exported functions, no parameters, no composition. The only
  parameterization: `--unique <literal>=NAME` → `const NAME = process.env.NAME ?? …` and `fill --from-env VAR`.
- **Recording a person:** `apwt record start --detach --url …` → `SESSION/TRACE_PATH/PID`; `record stop --session <id>
  --json`; `generate <trace>` (`src/cli/index.ts:111-213`). Standard username/password logins are stripped and replaced
  by `login(page)`; SSO/MFA is not detected (`src/generator/detect.ts:37-67`).
- **Agent sessions:** `apwt -s <name> open|snapshot|do|fill|…|expect|record-start|record-stop|spec|close`, `--json` on
  every command, exit codes 0/1/2; a per-session daemon on a local socket; safety: `--mode confirm` (destructive words
  need `--yes`), host allow-list, upload root, `--from-env` secrets, page text marked as data
  (`src/cli/agent/commands.ts`, `capture-commands.ts`). The in-process API `playwright-appian/agent` is TypeScript-only.
- **Runs:** plain `npx playwright test`; `SITE_URL`, `APPIAN_USERNAME`, `APPIAN_PASSWORD`; Node ≥ 20;
  `@playwright/test` pinned exactly `1.59.1`; Chrome if installed, else Playwright Chromium. `login(page, {username,
  password})` already takes explicit credentials (`src/login.ts:8`).
- **Distribution:** private GitLab npm registry (project 13864, token needed); the **project must hold its own copy**
  because specs `import 'playwright-appian'`.
- **Gaps (tabs/popups → TODO, some grid cells → TODO, SSO, drag/hover).** Explicitly left to "the SDLC application"
  (`planning/phase-01/08-roadmap.md:72-77`): assertion/intent synthesis, **managed storage of traces/tests**, triage,
  flaky detection, SSO login strategies, structured grid reconstruction.
- **`gss-playwright-tests`** (same root) is a hand-built consumer that already shows the target shape: Layer 1
  `playwright-appian`, Layer 2 `pages/` = parameterized business functions returning data
  (`pages/evaluation/create-evaluation.ts:27` returns the solicitation id), Layer 3 `tests/regression/*.spec.ts` whose
  one `beforeEach` stitches modules into **one shared evaluation for 17 scenarios** (`ratings-tab.spec.ts:17-67`), plus
  an object → spec reverse index (`tests/index.map.json`).

## 4. Standards and other products (research, 2026-11-02)

| Topic | What the standard / product does | Source |
|---|---|---|
| Layered automation architecture | ISTQB gTAA: test generation, test definition, test execution and test adaptation layers; the adaptation layer connects abstract scripts to the system under test. | [ISTQB TAE cheat sheet](https://cheatography.com/narayanan-palani/cheat-sheets/istqb-test-automation-engineering/pdf), [Robot Framework syllabus](https://robotframework.org/robotframework-RFCP-syllabus/docs/chapter-01/architecture) |
| Reusable modules, referenced not copied | Tosca: apps are scanned into reusable Modules; reusable test step blocks are maintained in one place and every test case using them updates. | [Tosca reusable test steps](https://documentation.tricentis.com/tricentis_cloud/en/content/create_tests/design_reusable_teststeps.htm), [Tosca modules](https://docs.tricentis.com/tosca-cloud/en-us/content/create_tests/design_modules.htm) |
| Shared steps + shared data | Azure Test Plans: Shared Steps and Shared Parameters are separate items referenced by many test cases; one case can belong to several suites and plans without copies. | [Azure shared steps](https://docs.microsoft.com/en-us/azure/devops/test/mtm/share-steps-between-test-cases?view=vsts), [Azure test objects](https://learn.microsoft.com/en-us/azure/devops/test/test-objects-overview?view=azure-devops) |
| Execution records | Xray: a Test Execution aggregates tests run in a target context and environment; each test inside it is a Test Run holding a copy of the definition and its result. | [Xray execute tests](https://getxraydocs.atlassian.net/wiki/spaces/XRAYCLOUDDRAFT/pages/44833634/Execute+Tests) |
| Page objects / business functions | Playwright documents page object models; fixtures provide them to tests. | [Playwright POM](https://playwright.dev/docs/pom), [fixtures](https://playwright.dev/docs/test-fixtures) |
| One-time setup, auth reuse | Playwright recommends setup **project dependencies** over `globalSetup` (traces, fixtures, report visibility); `storageState` reuses a login. | [Global setup](https://playwright.dev/docs/test-global-setup-teardown), [Auth](https://playwright.dev/docs/auth) |
| Shared state across tests | Tests in a file run in order in one worker; `describe.configure({mode:'serial'})` runs and retries a group together and skips the rest after a failure. | [Parallelism](https://playwright.dev/docs/test-parallel) |
| Selection + reporting | Tags/annotations + `--grep` select subsets; JSON, JUnit, HTML and blob reporters; `test.step` gives per-step results. | [Annotations](https://playwright.dev/docs/test-annotations), [Reporters](https://playwright.dev/docs/test-reporters) |
| Agentic authoring | Playwright Test Agents (1.56+): planner explores the app and writes a Markdown plan, generator writes tests from it and verifies locators live, healer replays failures and patches or skips. A **seed test** sets up the environment. | [Playwright test agents](https://playwright.dev/docs/test-agents) |
| Flaky tests | Playwright labels a test flaky when it fails then passes on retry; that label is per run, so cross-run history is needed to manage flakes; quarantine keeps a test running without failing the build. | [currents.dev](https://currents.dev/posts/best-flaky-test-detection-tools-for-playwright), [TestDino controls](https://testdino.mintlify.app/guides/test-controls) |
| Regression test selection | Test Impact Analysis selects only the tests a change can affect, from a change → test map (static or recorded). | [Azure TIA](https://docs.microsoft.com/en-us/azure/devops/pipelines/test/test-impact-analysis), [Launchable](https://www.launchableinc.com/what-is-test-impact-analysis) |
| Test code storage | Test automation code is kept in version control (separate repo or beside the app); test management tools keep the metadata and link to the automated tests. | [Ministry of Testing](https://store.ministryoftesting.com/insights/choosing-the-best-repo-for-your-test-automation-code), [maestro.dev](https://maestro.dev/insights/version-control-test-automation-best-practices) |
| Test data | Make each test own its setup against a known baseline; seed data deterministically; a shared fixture trades speed for coupling. | [repeato](https://www.repeato.app/blog/qa/best-practices-for-managing-test-data-in-automated-testing/), [Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) |

Content was rephrased for compliance with licensing restrictions.

## 5. Proposed architecture (assistant draft for the Q&A, kept as asked; §7 decisions win where they differ)

### 5.1 Terms (standard names for the user's words)

| User's word | Proposed term | Standard it follows |
|---|---|---|
| a module in the script library | **Action** (`ACT-000001`): one business operation as a parameterized function with declared inputs and outputs | Tosca reusable test step block / Azure shared steps / keyword (ISTQB keyword-driven) |
| script library | **Action Library** (per application) | |
| the evaluation shared by many scenarios | **Data setup** (`DS-000001`, a shared test fixture): a named precondition built from actions, producing data (e.g. a solicitation id) | xUnit shared fixture; Playwright setup projects |
| the script for one test case | **Case script**: the When + Then of a `TC-`, calling actions and asserting; its Given comes from a data setup or earlier steps | ISTQB test script |
| regression pack | **Regression suite** (per application): a curated set of references to scenarios | ISTQB regression test suite; Xray test plan |
| one run of a set of tests | **Test execution** (`TE-000001`) with one **test result** per scenario and per case | Xray Test Execution / Test Run |

### 5.2 Layers (gTAA mapping)

1. **Adaptation:** `playwright-appian` components (exists).
2. **Action Library:** `actions/<area>/<slug>.ts` — `export const createEvaluation = defineAction({ id:'ACT-000001',
   inputs:{…}, outputs:{piid} }, async ({ appian }, input) => { … return { piid } })`.
3. **Data setups:** `setups/<slug>.ts` — an ordered list of action calls; outputs passed to scenarios.
4. **Case scripts:** `cases/TC-000123.ts` — calls actions, asserts with `expect`.
5. **Scenario specs (generated, never hand-edited):** Genesis renders `suites/**/<setup>.spec.ts` deterministically from
   the database: one file per data setup, serial; `beforeAll` builds the setup once; each `TS-` is a `test()` tagged
   `@TS-000045`; each step is `test.step('TC-000123 …')`. Composition stays in the Phase 49 tables (one home), the code
   for a case lives in one file, the code for an action in one file. References, never copies.
6. **Execution:** program code runs `npx playwright test --grep <tags>` with JSON + JUnit + HTML reporters, traces and
   screenshots on failure; results are parsed into the database. **No agent and no credits at execution.**

### 5.3 Storage (answer to Q-a, proposed)

- **Code = files in a per-application test workspace that is a local git repository** (diffs, history, revert, open in
  an editor, runnable by plain `npx playwright test`, pushable to GitLab later).
- **Catalog = `genesis.db`** (new migration): actions, data setups, case ↔ script bindings, regression suites and their
  items, executions and results, test accounts. The DB stores each file's path + content hash; Genesis writes the files
  and commits; a hand edit is detected by the hash.
- Not JSON blobs (no history, no execution), not code-in-DB (no diff, needs materializing to run).

### 5.4 Impact → run (answer to Q-b, proposed)

Test Impact already lists the affected cases. A **Run impacted tests** action selects every automated scenario that
contains an affected case, groups them by data setup, and starts one test execution with `--grep`. Affected cases with
no script are listed as "not covered by automation".

### 5.5 References (answer to Q-c, proposed)

Yes: references only. Story case scripts call library actions; an agent writes new code only where the library has no
action, and proposes those as new actions. Safety for "change once, used everywhere": each action has a declared
input/output contract; Genesis shows where-used; an action edit re-runs its dependents; git history allows revert;
a breaking change is a new action.

### 5.6 Workflows

- `action-capture` (from a recording or an exploration log): segment into actions, parameterize literals, detect
  outputs, match existing actions, typecheck, replay → **proposals** a human accepts (the top-up pattern).
- `story-verification` (Verification lane): explore → author → run → triage/heal (ADR-067 tier) → decide → propose
  regression + library updates → report; finalizer moves the card `verify → deployment` or `reject → implementation`.
- `test-execution` (program-only): run a selection, parse results, write `automation_status` / last result.

## 6. Open questions (asked one at a time 2026-11-02; all answered — see §7: Q1→D1, Q2→D2, Q3→D3, Q4→D4, Q5→D5–D7, Q6→D8, Q7→D9, Q8→D10, Q9→D11, Q10→D12, Q11→D13, Q12→D14, Q13→D15, Q14 (library management)→D16, Q14 (collaboration)→D17, Q13 (delivery)→D18, `playwright-appian` changes→D19; the remaining small choices → §8)

| # | Question |
|---|---|
| Q1 | Storage model: code as files in a per-application git workspace + catalog in `genesis.db` (§5.3)? |
| Q2 | Reference model and layers: Action → Data setup → Case script → generated scenario spec → Regression suite (§5.2, §5.5)? |
| Q3 | How workflow agents reach `apwt`: a Genesis MCP server wrapping `apwt --json` (fits ADR-002/029) or a guarded shell tool? |
| Q4 | Runtime: require Node ≥ 20 on the machine + ship the package tarball with Genesis, or bundle Node? Browser: system Chrome or managed Chromium? |
| Q5 | Target environment and test accounts: which Appian environment tests run against (dev-tagged only, or a separate test env); test user accounts per application and role (persona) stored in the SecretProvider. |
| Q6 | Tests write application data through the UI (create evaluations). A new ADR scoping this (test accounts only, never design objects, never the delete-word actions without the test's own data)? |
| Q7 | Regression suite contents: references to feature scenarios only, or its own end-to-end scenarios composed from cases of any feature of the app? |
| Q8 | Data setups: the minimal-data rule as shared, serial, per-setup groups; how a scenario declares its setup. |
| Q9 | Scheduling: Genesis's scheduler (a fixed `regression-run` job with per-app options; laptop must be on) or a GitLab CI scheduled pipeline on the pushed workspace? |
| Q10 | Verification outcome rules: product defect vs script defect; healing bound; what a fail/pass does to the card; who confirms regression/library updates (auto vs proposal). |
| Q11 | Recording UX: headed browser launched by Genesis, persona picked before recording, review of proposed actions. |
| Q12 | Results: flaky handling (retries, quarantine), history, report surfaces, notifications. |
| Q13 | Delivery: one phase or several (foundation + library, regression, verification lane)? |
| Q14 | Collaboration: local only this phase (like Phase 49), with Hub-ready columns? |

## 7. Decisions (locked with the user, one at a time)

| # | Decision | Reason |
|---|---|---|
| D1 | **Storage split (Q1).** Test **code** lives as files in a per-application test workspace that is a **local git repository** under `~/.genesis/`; Genesis writes the files and commits. The **catalog** (ids, input/output contracts, where-used, suites, executions, results) lives in `genesis.db`, which records each file's path and content hash so a hand edit is detected. Not code in the DB, not a JSON library file. | User agreed (2026-11-02): matches the industry rule (test code in version control, metadata in the test-management store); gives diffs, history and revert; runnable by plain `npx playwright test`; pushable to GitLab later. |
| D2 | **Layering and references (Q2).** **Action** (`ACT-`, the library; declared inputs/outputs) ← called by **data setups** (`DS-`, a named shared precondition = a list of action calls) and **case scripts** (one per `TC-`: its When + Then; its Given comes from the scenario's data setup or earlier steps; a case runs as a step inside a scenario, not alone) ← ordered by **scenarios** (`TS-`, the Phase 49 ordered case list + the data setup it needs), whose spec files Genesis **generates** from the DB and nobody hand-edits ← referenced by the per-application **regression suite** (scenario references). Every piece of code exists in one file; nothing is copied. | User accepted (2026-11-02): "what is tested" stays in the Phase 49 scenarios/cases, "how" in the actions; the same scenario serves a feature suite and the regression suite with no second definition (Tosca reusable step blocks, Azure shared steps, Playwright test/step mapping). |
| D3 | **Agents drive `apwt` through Kiro's shell inside Kiro's local command sandbox (Q3, option B).** The agent node trusts only the shell tool (+ blackboard tools) and uses the `playwright-appian` CLI skill; every command and its children run in Kiro's OS sandbox (Seatbelt on macOS, Kiro CLI ≥ 2.31, V3 engine), configured by Genesis in the run's blackboard (`.kiro/settings/sandbox.json` + permission rules): writes confined to the blackboard + temp, credential paths denied, network limited to the Appian host under test. **Program nodes own the sessions**: they open and log in the `apwt` sessions before the agent's turn; the agent only attaches by session name, and Kiro is started with a **clean environment** (no secrets in the shell). **The first sub-spec is a spike** that must prove, on macOS: (1) a V3 ACP session (`kiro-cli acp --agent-engine v3`) honours the sandbox; (2) `apwt`'s Chrome/Chromium runs inside it (nested sandbox) and reaches the Appian host through the sandbox network proxy; (3) the shell sees no secrets; (4) a bypass corpus (writes outside, reads of credential paths, other hosts, reading the session-state files) is denied (L-088). **If the spike fails, the fallback is option A**: a Genesis-owned `appian-browser` MCP server wrapping `apwt --json` (managed entry like `genesis-kb`, per-node allowlist). A new ADR records the first shell for a workflow agent and its sandbox boundary. | User chose B (2026-11-02) after both options were explained: reuses the shipped CLI skill and every future `apwt` command with no wrapper to maintain; the OS sandbox is Kiro's own supported boundary. Risks accepted: the sandbox is the only boundary once the shell is trusted, and Kiro says it cannot guarantee complete isolation; the unknowns are proven or refuted by the spike before anything depends on them. Sources: [Kiro local sandboxing](https://kiro.dev/blog/local-sandboxing/), [CLI 2.31](https://kiro.dev/changelog/cli/2-31/); `kiro-cli acp --help` (2.37.1) lists `--agent-engine v3`; `kiro_agent_sdk/client.py` starts Kiro with `env=os.environ.copy()` today. |
| D3a | **D3 mechanism corrected by the 51-03 spike (2026-11-02; the decision itself stands).** `kiro-cli acp --agent-engine v3` (2.37.1) **does not apply** a `<cwd>/.kiro/settings/sandbox.json` (the binary warns: "kiro-cli acp does not apply sandbox isolation on this launch path"). The sandbox is turned on **over ACP**: after `session/new`, Genesis sends the extension request `_kiro/sandbox/applyConfig` `{configId:"sandboxNetworkMode", value:"default_blocked"}` then `{configId:"sandbox", value:"enabled"}` and waits for the `_kiro/sandbox/status` notification `{status:"active", backend:"seatbelt"}` before the first prompt. The rules come from a **per-run `KIRO_HOME`** whose `settings/permissions.yaml` carries `fs_read` denies (credential paths, `~/.genesis`, saved `apwt` logins), `fs_write` allow (the run folder; temp is allowed by the sandbox) and a `sandbox_network` allow for the **QA host only**; `mcpSandboxing` disabled (Genesis's own blackboard MCP stays outside). Auth is unaffected (`--auth-method cli` reads the Kiro CLI credential store; the user's `~/.kiro` is untouched). **"Trust only the shell" is a client policy:** V3 ACP rejects `--trust-tools`, so the node runs `permission_mode="ask"` with an `on_permission` that allows only tool calls of **kind `execute`** (correlated to the `tool_call` by `toolCallId`) plus the blackboard MCP tools, and denies everything else fail-closed. The clean environment (S5, proven) is `HOME, USER, LOGNAME, SHELL, TMPDIR, LANG, LC_ALL, TERM`, a fixed `PATH`, `PLAYWRIGHT_BROWSERS_PATH`. **Product work this adds:** `kiro-agent-sdk` gets an `env=` launch override, a method to send an ACP extension request, and a way to observe `_kiro/sandbox/status` (today non-turn notifications are dropped); `genesis-core`'s `kiro_node` gets a sandboxed-shell mode that uses them (51-05 §4a). | Spike evidence: `genesis/scripts/spikes/51-03/evidence/s1-file.json` (file only → no isolation) vs `s1-rpc.json` (RPC → `$HOME` write denied, network blocked, run folder + `$TMPDIR` writable); 51-03 As built. Additive and within Kiro's supported surface, so D3 is not refuted; the remaining spike items (S2–S4, sandboxed S6, S7–S11) still decide the gate. |
| D3b | **Agents reach `apwt` only through a Genesis-owned `appian-browser` MCP server — no shell (Q3c, option A; replaces D3/D3a's sandboxed shell).** The 51-03 spike proved the sandbox (S1, S5, S6 PASS) but found **residual 1**: Kiro's Seatbelt profile always allows loopback, so a sandboxed shell can call the unauthenticated Genesis API on `127.0.0.1:8760` (no origin/token check in `genesis/genesis/api/**`, ADR-026) — e.g. start an Implementation run that writes to Dev, answer a HITL gate, change Settings — reachable by prompt injection from page text. Decision: (1) a stdio MCP server `genesis/genesis/mcp/appian_browser_server.py` (the `genesis-kb` pattern: a **managed** entry `appian-browser` in `mcp-registry.json` with a `tool_allowlist`), injected per node (ADR-002/004), whose tools map one-to-one onto `apwt --json` commands with argv lists (no shell); no open/login/close/state/attach/mode tools — **program nodes own the sessions** and pass the session names, the QA allow-host, the artifacts folder and a clean environment (no credentials) to the server; (2) the browser agent nodes run **fail-closed**: `permission_mode="auto_deny"` with an explicit trust list (the node's `@appian-browser/…` tools + the blackboard tools + file writes confined to the run folder via `fs_write_root`), so Kiro's shell and every untrusted tool is refused; (3) a separate `playwright-appian` skill variant for MCP tool names, shipped in genesis-workflows. The sandbox findings stay as ADR-083's evidence for why a shell is not given to workflow agents; a local API token (the Jupyter pattern, an ADR-026 amendment, which would also close the browser CSRF gap) is a later phase. | User chose A (2026-11-02): removes the whole class of risk with no platform change; also removes the model-refusal and sandbox-recipe fragility the spike hit. Spike evidence: 51-03 As built (S6 OS-layer corpus, residual 1). `kiro-agent-sdk` needs no sandbox/ext additions now (51-05 §4a rewritten). |
| D4 | **Runtime and installation (Q4).** (1) **Node ≥ 20 is a machine prerequisite**, detected (startup preflight + a Settings → CLI "Appian browser testing" card that names the fix); Genesis never downloads Node. (2) The **`playwright-appian` tarball is vendored in the genesis repo** (e.g. `vendor/`); its version moves with a Genesis release; no registry token on any machine. (3) **Each application's test workspace is a self-contained npm project** (`package.json` + `package-lock.json` with exact versions, `playwright.config.ts`, own `node_modules`), created on first use, installed with `npm ci` from the vendored tarball (`@playwright/test` 1.59.1 from the normal npm registry / Artifactory proxy, once), portable to GitLab CI as-is; the agent's shell finds `apwt` via the workspace's `node_modules/.bin`. (4) **Browser = Playwright's own Chromium** pinned by `@playwright/test`, installed with `npx playwright install chromium` into `~/.genesis/` from an explicit Settings action; every test run and agent session uses it; branded Chrome is an optional per-workspace setting. To verify while writing the spec: every `apwt` path (agent `open`, `record start`, generated specs' config) can be pointed at Playwright Chromium (`apwt open --browser chromium` exists; `record start` prefers system Chrome today). | User accepted the corrected recommendation (2026-11-02). Standard: Playwright's recipe is installed Node → `npm ci` → `npx playwright install` → `npx playwright test` ([Playwright CI](https://playwright.dev/docs/ci)); each Playwright version needs its own browser builds, branded Chrome is an opt-in and follows enterprise policies that can block testing ([Playwright browsers](https://playwright.dev/docs/browsers)); a system Chrome auto-updates under a nightly regression. Vendoring is the accepted alternative to a private registry when no credential should be on every machine (Genesis precedent: ADR-038, ADR-043). |
| D5 | **Test environment, application test settings, roles (Q5).** (1) **Environment type** replaces the dev toggle: the Add/Edit environment dialog in Settings → Environments gets a **type dropdown** (Dev, QA, …) instead of the "dev environment" switch. `Dev` keeps today's meaning (the single dev-tagged env: KB sync, Implementation writes, core MCP creds, ADR-036/048); a new **`QA`** type is the **testing environment**. (2) **Every test execution runs on the QA environment only** — story verification, regression, impact and ad-hoc runs; there is no per-run environment choice. (3) **No QA environment configured** → moving a card to Verification shows a **warning** that names the fix (configure a QA environment in Settings). (4) A **new application-page tab** holds the application's test settings: the **site URL** on the QA environment and the **test users** (role key, username, password; password in the SecretProvider, never in a file), and the rest of the app's test setup. (5) Scripts name a role; credentials go only into the test process, never the agent's shell (D3). (6) **Recording and exploration cover every affected role:** when a story's scenarios involve several roles, recording/exploration happens from the point of view of each affected role (one session per role). | User's direction (2026-11-02), replacing the per-run environment choice proposed in §5: one place where all testing happens; environment purpose made explicit in Settings; application test configuration in one tab. Existing `environments.json` fields: `type` is free text today (`"prod"` in a fixture) and `is_dev` a single-select bool (`genesis/config/environments.py:24,49,99`); the spec must map `is_dev` → type `Dev` without losing the single-Dev rule (and decide what the old free-text `type` becomes). |
| D6 | **Lane order changes: Deployment moves before Verification (Q5b).** The Workbench lanes become To Do → Design → Design Review → Implementation → Code Review → **Deployment → Verification** → Done, so a story's changes are in the QA environment before it is tested there (D5). Transitions follow: `code-review --approve--> deployment`, `deployment --deployed--> verification`, `verification --verify--> done`, `verification --reject--> implementation` (replacing `code-review → verification`, `verification → deployment`, `deployment → done` in `genesis/domain/transitions.py:115-119`). Lane values are unchanged (only order + edges), so stored story statuses and the Hub's board data need no migration. Amends ADR-061 (the eight fixed lanes' order). | User's direction (2026-11-02), chosen over "you deploy before moving to Verification" (A), "Genesis deploys as part of Verification" (B) and "verify on dev" (C): the board itself now says the story is deployed before it is verified. |
| D7 | **The Deployment lane stays manual this phase (Q5c).** The user deploys the story's changes dev → QA with their usual Appian deployment, then drags the card Deployment → **Verification**; that drag's confirm dialog asks the user to confirm the changes are deployed to QA (and shows the D5 warning when no QA environment exists), then launches the verification run. No new environment-write capability; ADR-068/073 unchanged. **Automated dev → QA deployment from the Deployment lane is a later phase** (it would need ADR-068/073 amendments, a rollback design and its own gate) — recorded in the phase's Deferred list. | User agreed (2026-11-02): keeps this phase's blast radius to test execution. |
| D8 | **Writing application data in QA (Q6) — a new ADR.** (1) Test runs and agent browser sessions may create, change and delete **application data only on the QA environment's host** (the `apwt` host allow-list = the QA site; other hosts refused); Genesis refuses to run tests when the QA host equals the Dev host or any other environment's host. (2) Only the application's **test users** (D5), never the Dev-MCP service account. (3) Application data through the UI only: no design objects, no MCP write tools, no deployments. (4) **Approval:** the Verification confirm dialog is the single blanket approval for a story run (like ADR-068's Implementation confirm); turning a regression schedule on is the approval for scheduled runs; no per-step gates. (5) **Agents are not restricted on destructive-looking actions in QA:** agent sessions run in `apwt --mode full` (no `--yes` gating); every step still lands in the session's action log, which the run keeps. (6) Every run uses **unique per-run values** so runs never collide; **no automatic cleanup** this phase (QA data accumulates; cleanup actions can be library actions later). | User accepted 1–4 and 6 and dropped the proposed rule 5 ("agents confirm a destructive action only when a test case requires it, listed in the report") (2026-11-02): QA exists to be written to, so a confirm layer adds friction without protecting anything that matters; the host allow-list and test-user-only rules are the boundary. Interpretation of "5 is not needed" recorded as `--mode full`; reported to the user, who did not object (2026-11-02). |
| D9 | **Regression suite contents (Q7, option B).** The per-application regression suite holds **references to feature scenarios** and **its own regression scenarios**: `TS-` scenarios (same id sequence) owned by the regression suite, each an ordered list of cases from **any feature of the same application** (cross-feature end-to-end journeys, e.g. create evaluation → add vendor → rate). Schema: a scenario is owned by a feature suite **or** the app's regression suite; only regression scenarios may reference other features' cases (feature scenarios keep 49 D2's same-suite rule). Phase 49's "a case can't be retired while a non-retired scenario uses it" extends to regression scenarios. The minimal-data rule (D2 data setups) applies across the whole regression suite. | User accepted the recommendation (2026-11-02): Azure Test Plans / Xray plans draw test cases from anywhere; regression packs are normally built from end-to-end journeys, which no single feature owns. Resolves Phase 49's deferred "app-wide regression suites + cross-feature case reuse" (`phase-49-test-design.md:133-135`). |
| D10 | **Data setups — the minimal-data model (Q8).** (1) A **data setup** (`DS-`) is an application-level library item: a name, an ordered list of action calls with inputs, run as one test-user role, producing named outputs (e.g. `piid`); referenced, never copied. (2) Each scenario names **one data setup or none** (starts from the site home); agents propose it while authoring; the user can change it on the scenario page. (3) **Shared by default:** each setup is built **once per test execution**; every scenario naming it runs against that data; each scenario opens its own page and logs in as its own role, then navigates to the shared data (share data, never browser state). (4) A scenario flagged **changes shared data** gets a **private instance** of its setup (the user's "different type of evaluation" case). (5) Scenarios sharing a setup run in a fixed order, read-only first. (6) A setup that fails to build marks its scenarios **Blocked** (not Failed); other setups still run; a failed scenario does not stop the next scenarios on the same setup. (7) Mechanism: Playwright **setup projects** — one project per setup instance writes its outputs to a file in the run folder; that group's scenario project depends on it, so a failure blocks only that group and a retry never rebuilds the data. | User accepted (2026-11-02). xUnit "shared fixture" with an explicit escape hatch for state-changing tests; Playwright recommends project dependencies over `globalSetup` ([global setup](https://playwright.dev/docs/test-global-setup-teardown)); matches the `gss-playwright-tests` one-evaluation-for-17-scenarios practice. Example: 50 scenarios, 3 setups, 2 state-changing → 5 evaluations, not 50. |
| D11 | **Scheduling: Genesis's own scheduler (Q9, option A).** One fixed backend job, **`regression-run`**, added to `DEFAULT_JOBS` (fits ADR-047's fixed, backend-defined jobs; per-application cadence lives in the job's options, `options_json` m0023 seam). Each application's schedule (off / daily / weekly, days, time) is set in the application test tab (D5). Each tick starts the due applications' regression executions **one at a time** (no two browser-heavy runs overlap; the run manager has no global cap). Runs only while Genesis runs; a missed slot runs once at startup (existing `due_slot` behaviour). **GitLab CI scheduled pipelines are deferred**: the workspace is already CI-portable (D4); a later phase can add a result import. | User accepted (2026-11-02): results land in Genesis with history and links; no CI runner, CI secrets or result import needed now; agents never read CI variables (L-100). Whether per-app cadence inside one job's options needs an ADR-047 amendment note is settled in the spec (the scheduler today edits only `application-sync`). |
| D12 | **Story verification flow and outcome rules (Q10).** Steps, each agent step with the ADR-011 trio and the ADR-067 healing tier: (1) **Explore** — one session per affected role (D5), no testing; captures to the run folder. (2) **Author** — a case script per story case from library actions + captures, a data setup per scenario, new actions/setups where the library has none; a program validator checks every story case has a script, the workspace typechecks, and `playwright test --list` sees every scenario. (3) **Execute** — program only. (4) **Triage** each failure: **script defect** (locator/timing/data) → heal in place (≤ 1 patch, ≤ 1 guided restart, `META.healing`) and re-run that scenario; **product defect** (behaviour contradicts the case's Then) → stays **Failed** with expected vs actual, screenshot, trace; **blocked** (QA unreachable, login fails, setup won't build) → escalation gate (retry / send back / accept). (5) **Decide** — all story cases pass → `verify` **Verification → Done**; any product defect → `reject` **Verification → Implementation** automatically, defect report on the story; fail-then-pass on retry = passed, marked **flaky**. (6) On a pass, the agent prepares **proposals**: new actions/setups for the library, the story's scenarios added to the regression suite, changes to existing library actions; shown on the report with Accept all and per-item accept/reject; accepting commits to the workspace's git repo; the card's move to Done does not wait. (7) **Report** — a test execution report (HTML) on the story page. | User accepted (2026-11-02). Separates product from script failures (the standard triage split; Playwright healer behaviour); proposals because library code is shared and test code is normally reviewed before joining the main suite; matches the Phase 49 top-up proposal pattern. |
| D13 | **Record workflow (Q11).** (1) A **Record workflow** button in the application's Action Library opens a dialog: the **role** (a D5 test user), a **name + intent**, an optional start page (default: the QA site home). (2) Genesis opens a **visible Playwright Chromium window on the QA site, already signed in as that role** (the user never types the test user's password) — the spec settles the mechanism: Genesis signs in and records into that browser (`apwt record start --cdp`), or `playwright-appian` gains a small login option; the recorder strips logins either way. (3) While recording, Genesis shows a "Recording as <role>… Stop" bar; closing the window also stops it. (4) **One recording = one role**; a second role's part of a flow is a second recording (D5.6). (5) After Stop, an **`action-capture`** run: `apwt generate` (deterministic) → an agent splits the steps into actions at business boundaries (a dialog opened/closed, Create/Save, navigation), turns typed literals into **inputs** and detected results into **outputs**, and **matches each against existing actions** (reuse unchanged / propose update / propose new) → a validator typechecks and **replays on QA as that role**. (6) **Review:** proposals in the library (new / reused / updates, each with code + replay result), accept or reject per item or all; accepting commits to the workspace git repo; nothing joins the library unreviewed (same rule as D12.6). (7) The raw trace is kept with the proposals so a capture can be re-run with a newer `playwright-appian`. | User accepted (2026-11-02). Trace = source of truth, spec = artifact (`playwright-appian` D-02); proposals keep shared library code reviewed. |
| D14 | **Results, flaky tests, surfaces (Q12).** (1) A **test execution** record (`TE-`) per run: kind (verification / regression / impact / ad-hoc), trigger (story, schedule, impact source, user), QA environment, the workspace **git commit** and the **`playwright-appian` version** (reproducible), totals. (2) **Results per scenario and per case step**: passed / failed / flaky / blocked / skipped / not run, duration, error, attachments (Playwright trace, screenshot on failure); result rows kept permanently; trace/screenshot files follow run retention (ADR-022: the latest executions per application keep files, older pruned). (3) **One retry** per test; fail-then-pass = **flaky**, never failed (Playwright's rule). (4) Each scenario shows its last 10 results; flaky in ≥ 3 of them → **flaky badge**; **quarantine deferred**. (5) `automation_status` ∈ **not-automated / automated / broken** (broken = an unhealed script defect); each case shows its **last result** (status, when, execution). (6) Surfaces: **Application → Regression** (suite, schedule, latest execution, pass-rate trend, executions list); **execution page** (summary → scenarios → cases → failures with screenshots + the **Playwright HTML report** and trace viewer, served by a dedicated route since the generic artifact preview cannot show HTML); case/scenario pages (automation status, last results); story page Verification section (D12); Test Impact tab **Run impacted tests** (§5.4). (7) **In-app signals only**: a "last regression: N failed" badge on the application header and the job status in Settings; desktop/email notifications deferred. | User accepted (2026-11-02). Xray Test Execution / Test Run model; Playwright flaky semantics; per-run flaky labels need cross-run history ([currents.dev](https://currents.dev/posts/best-flaky-test-detection-tools-for-playwright)). |
| D15 | **One new application tab, "Testing", with four sub-tabs (Q13)**, after Test Impact, URL-addressable (`?tab=testing&view=library|regression|executions|setup`): **Library** (actions + data setups: search/filter by area, role, status; item page with code, inputs/outputs, where used, history; Record workflow; capture proposals awaiting review), **Regression** (referenced feature scenarios + own regression scenarios grouped by data setup; latest result + trend; Run now), **Executions** (every execution → the D14 execution page), **Setup** (QA site URL, test users by role with passwords as secrets, the regression schedule (D11), runtime status — Node, browser, workspace — and the no-QA-environment warning). Test Impact stays its own tab and gains Run impacted tests; the feature Tests tab and case/scenario pages gain automation status + last results. D5's "new application tab" is this tab's Setup view. | User accepted (2026-11-02): keeps the application page at nine tabs instead of twelve; one home for everything about executing tests. |
| D16 | **Library item management (Q14)** — actions and data setups. (1) Lifecycle **Draft → Ready → Retired** (as Phase 49): accepted proposals and new items start Draft; **Ready** after a passing replay on QA; **retire, not delete**, once anything uses it — retire is refused while a non-retired case script, data setup or action uses it (the refusal names them); **Delete** only for an item never used (e.g. a bad capture), as a commit. (2) **Create** via Record workflow (D13), verification proposals (D12) or **New action** (a template). (3) **Edit** on the item page: a contract form (name, area, role, inputs, outputs) + an in-browser **CodeMirror 6** editor for the TypeScript (one new web dependency, lazy-loaded on that page, L-015). (4) **Save** = write file → **typecheck the workspace** → refuse with errors on failure → else **one git commit** with a message; when the item is used elsewhere, offer **Run the N scenarios that use it**. (5) **Contracts:** adding an optional input is allowed; removing/renaming an input or output or adding a required input is **breaking** → refused while used, with **Save as new action** offered. (6) **History:** the item page lists the file's git history and can **revert** (a new commit, same typecheck). (7) **Edits outside Genesis** are detected by hash ("changed outside Genesis" + diff); **Adopt** re-validates and commits; until adopted, executions use the last adopted version — executions therefore run from a **clean checkout of the committed version** (a git worktree at the recorded commit, D14), never from uncommitted working files. | User accepted (2026-11-02). Matches Phase 49's retire-not-delete; contracts protect "change once, used everywhere" (§5.5); committed-only execution makes every result reproducible from its recorded commit. |
| D17 | **Local only this phase (Q15).** No Hub contract change; the new tables carry the m0019 collab columns (unused) so Hub sync is additive later. Future sharing of **scripts** = a GitLab remote per application test workspace (push/pull of the git repo, D1); the Hub would carry only the catalog and results — both deferred. Known prerequisite: `ACT-`/`DS-`/`TE-` ids, like `TC-`/`TS-`, are per-machine counters and must be made machine-unique before any sharing phase (49 D12). | User accepted (2026-11-02): same posture as Phase 49; git is the standard sharing mechanism for test code. |
| D18 | **Delivery: one phase, one release (Q16).** Phase 51, sub-specs built in order: 51-01 findings · 51-02 **spike** (D3 gate; on failure the MCP fallback replaces the agent-access design before anything else is built) · 51-03 ADRs + data model (m0026) · 51-04 runtime + environments + test users · 51-05 execution engine (spec generation, data-setup projects, runs, results, `test-execution` workflow, Run impacted tests, `regression-run` job) · 51-06 library (lifecycle, editor, `action-capture`, Record workflow, proposals) · 51-07 regression suite · 51-08 story verification (lane reorder, `story-verification`, finalizer, report, proposals) · 51-09 API · 51-10 web experience · 51-11 review & acceptance (live on QA) · 51-12 release & onboarding. **One release at the end**: genesis + genesis-workflows (+ the vendored `playwright-appian`). | User chose one phase with one release (2026-11-02) over three separately released phases. |
| D19 | **`playwright-appian` joins the Genesis agent system as its own repository (Q17).** Not moved into the `genesis` monorepo. An early sub-spec (done by `genesis-docs`, which maintains the agent system) adds: the repo to `genesis-ctx status` and the L0 repo map; a new area (e.g. `browser-testing`) whose globs cover `playwright-appian/src/**` (+ the Genesis test-execution code) with gates `npm run lint && npm run typecheck && npm test`; the release agent's knowledge of its flow (tag `vX.Y.Z` → its CI publishes to the GitLab registry, its D-38). **One home per fact:** `playwright-appian/planning/` (BIBLE, DECISIONS, TRACKER) stays the home of the package's internal design and its D-ids; Genesis specs cite those ids; Genesis ADRs cover only how Genesis uses it; its invariants (no LLM inside, D-02; Appian knowledge only in the taxonomy, D-05; label-only generated code, D-04) are written into the area so agents keep them. **Release order:** publish the `playwright-appian` version first, then the Genesis release that vendors that exact tarball (the L-057 pin rule). **Amends D18:** the sub-spec list gains this onboarding step before the spike. | User chose this (2026-11-02) because `playwright-appian` will change a lot alongside Genesis. Separate repo rather than `genesis/packages/`: it has its own consumers and semver on the npm registry (`gss-playwright-tests`), npm cannot install from a git subfolder (ADR-080's sharing mechanism), and it has its own Node toolchain and design record. |

## 8. Defaults — ✅ confirmed by the user 2026-11-02 ("I accept these")

> F4 follow-up (user, 2026-11-02): the workspace stays under the hidden `~/.genesis/testing/` (offered the visible
> `~/Genesis/testing/`; declined). The Setup view shows the path with an "Open folder" link.

| # | Default | Why |
|---|---|---|
| F1 | **Terms** (UI and code): **Action Library** (the user's "script library"), **Action** `ACT-000001`, **Data setup** `DS-000001`, **Case script**, **Regression suite** (the user's "regression pack"), **Test execution** `TE-000001`, test result. New `kb_sequences` counters `test_action`, `test_setup`, `test_execution`. | Standard names (§5.1); the ADR-072 id pattern. |
| F2 | **No QA environment → the Verification drag is refused** with the warning dialog (names Settings → Environments); the card stays in Deployment and no run starts. | D5's warning; nothing can run without QA. |
| F3 | **Environment types:** Dev, QA, UAT, Production, Other. Exactly one Dev (as today) and at most one QA. Migration: `is_dev: true` → Dev; the old free-text `type` → `Production` when it reads prod/production, else `Other`, with the old text kept in `notes`. | D5; keeps ADR-036/048's single-Dev rule. |
| F4 | **Paths:** workspace `~/.genesis/testing/apps/<app_uuid>/` (git repo, own `node_modules`); Chromium in `~/.genesis/testing/browsers` (`PLAYWRIGHT_BROWSERS_PATH`); execution checkouts in the run's blackboard. | D1, D4, D16.7. |
| F5 | **Workspace layout:** `actions/<area>/<slug>.ts`, `setups/<slug>.ts`, `cases/TC-000123.ts`, `suites/**` (generated scenario specs, **committed**, regenerated before each execution) + `lib/` (a small Genesis-owned helper: `defineAction`, `defineSetup`, `defineCase`, `loginAs`). Generated specs are committed so the repo runs alone (`npm ci && npx playwright test`). | D2; CI portability (D4, D11). |
| F6 | **Playwright config:** `workers: 1` (Playwright's CI recommendation; one browser at a time), `retries: 1` (D14), `globalTimeout` 2 h regression / 1 h verification and impact, `actionTimeout` 15 s, reporters json + junit + html, `trace: 'retain-on-failure'`, `screenshot: 'only-on-failure'`, headless. | [Playwright CI](https://playwright.dev/docs/ci); `playwright-appian`'s config defaults. |
| F7 | **One test execution at a time per machine:** a second one queues (shown as Queued) until the first ends; the regression job is serial (D11). | No run-manager cap today; browser-heavy runs. |
| F8 | **Subprocess hygiene:** every `apwt`/`playwright` call from program code has a timeout and runs in its own process group, killed with it on pause/cancel/timeout (closes the `cli_node` no-timeout and no-reaping gaps, §2.3). | ADR-012 pause = kill must not leave browsers behind. |
| F9 | **Run impacted tests:** runs every automated scenario (feature or regression) containing an affected case, grouped by data setup; affected cases without a script are listed "not covered by automation". | §5.4. |
| F10 | **Verification agent bounds:** reliability `retry_max` 2 per agent node; `META.healing {max_heal: 1, max_restart: 1}`; the default workflow model; the explore step's turn timeout sized in the spike. | ADR-011/067; house defaults. |
| F11 | **Retention:** trace/screenshot/report files kept for the last 20 executions per application; result rows kept forever. | D14.2; ADR-022. |
| F12 | **Test-user secrets** under their own SecretProvider scope (`testusers-<app hash>/<ROLE>_PASSWORD`); usernames and role labels in `genesis.db`; Settings warns when a username matches the Dev-MCP service account. | D5, D8. |
| F13 | **Regression schedule off by default** for every application. | L-081 (a new default that turns a job on must respect the user). |
| F14 | **A scenario's data setup defaults to none** until an agent proposes one or the user picks one. | D10.2. |

## Context manifest


```toml
areas    = ["features-stages", "stories-workbench", "runs-worker", "workflows-library", "config-secrets", "distribution"]
adrs     = ["ADR-001", "ADR-002", "ADR-010", "ADR-011", "ADR-012", "ADR-021", "ADR-022", "ADR-029", "ADR-040", "ADR-047", "ADR-048", "ADR-067", "ADR-068", "ADR-069", "ADR-078", "ADR-079"]
lessons  = ["L-021", "L-042", "L-058", "L-062", "L-064", "L-088", "L-093", "L-095"]
docs     = ["tracker:specs/phase-49-test-design.md", "tracker:specs/phase-49-test-design/49-01-findings.md", "tracker:specs/backlog/phase-49-follow-ups.md"]
code     = ["genesis/genesis/kb/testdesign.py", "genesis/genesis/services/testimpact.py", "genesis/genesis/api/workbench.py", "genesis/genesis/chat/story_implementation_finalizer.py", "genesis/genesis/cli_tools/native/installer.py", "genesis/genesis/runtime/scheduler.py"]
upstream = []
```
