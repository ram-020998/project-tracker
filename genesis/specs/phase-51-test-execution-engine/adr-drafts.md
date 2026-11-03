# Phase 51 — ADR drafts (ADR-081 … ADR-084)

> **Status:** DRAFTED 2026-11-03 by genesis-dev in 51-04 (§6). **Proposed**, not yet in `reference/decision-log.md`.
> At release, 51-13 / genesis-docs adds each one with `genesis-ctx add adr` using the fields in its header table and
> the bullet list under it as `--body-file`, then updates the Status line to Accepted with the shipped versions.
> Sources: umbrella `../phase-51-test-execution-engine.md` §12, `51-01-findings.md` §7–§8 (D1–D19, D3a–D3d, F1–F14),
> `51-03-spike-sandboxed-shell.md` (both As built sections), `51-04-adrs-and-data-model.md` As built.
>
> **Settled (D22, user 2026-11-03):** ADR-082 amends **both** ADR-068 and ADR-021 (`--amends ADR-068,ADR-021`; if
> `genesis-ctx add adr` takes one id per flag, repeat the flag). The ADR-021 chain then shows the QA-data exception.

---

## ADR-081

| field | value |
|---|---|
| `--id` | `ADR-081` |
| `--title` | `Test automation architecture: an action library, case scripts and program-run executions (Phase 51)` |
| `--areas` | `browser-testing,stories-workbench,features-stages,db` |
| `--rule` | `Test code lives as files in a per-app git workspace and genesis.db holds only the catalog; scripts reference actions and cases, never copy them; executions are program-only and run committed code.` |
| `--amends` | `ADR-078` |
| `--status` / `--phase` | `proposed` / `51` |

- **Status:** **Proposed** — 2026-11-03 (Phase 51; spec set `specs/phase-51-test-execution-engine.md` + `51-01..51-13`;
  findings `51-01-findings.md`). Data model built in 51-04 (m0026 → DB v26).
- **Context.** Phase 49 (ADR-078/079) records *what* to test: suites, ordered `TS-` scenarios of reusable `TC-` cases,
  linked to stories and objects. Nothing runs them. Phase 51 adds *how*: scripts that drive the Appian UI through
  `playwright-appian` (`apwt`), shared so a change to one screen is fixed once, and results with history. The industry
  rule is that test code lives in version control and its metadata in the test-management store; Playwright's own
  recipe is installed Node → `npm ci` → `npx playwright install` → `npx playwright test`. Detail: `51-01-findings.md`
  §4–§5, D1, D2, D9, D10, D14, D16, D17.
- **Decision.** (1) **Storage split (D1).** Test **code** lives as files in one **git repository per application**
  under `~/.genesis/testing/apps/<app_uuid>/` (F4), a self-contained npm + Playwright project (exact-version lockfile,
  own `node_modules`, the vendored `playwright-appian` tarball, D4) runnable on its own and portable to CI. Genesis
  writes the files and commits. The **catalog** — ids, contracts, where-used, suites, executions, results — lives in
  `genesis.db`, which records each file's workspace-relative path and content hash so an edit outside Genesis is
  detected ("changed outside Genesis", then Adopt). (2) **Layers, references only (D2).** **Actions** (`ACT-000001`)
  are the library, each with a declared input/output contract; **data setups** (`DS-000001`) are named shared
  preconditions (an ordered list of action calls run as one role, producing named outputs); a **case script** (one per
  `TC-`) holds that case's When + Then; **scenario specs** are generated from the Phase 49 `TS-` scenarios (ordered
  cases + the scenario's data setup), committed, regenerated before every execution and never hand-edited; suites
  reference scenarios. Every piece of code exists in one file; `kb_test_refs` is a derived index of the code's imports.
  (3) **Regression suite (D9).** One per application: references to feature scenarios plus its own regression
  scenarios (same `TS-` sequence) whose steps may use any non-retired case of the same application; feature scenarios
  keep Phase 49's same-suite rule. (4) **Data setups (D10).** Built once per execution and shared by the scenarios
  that name them (data is shared, browser state never); a scenario flagged *changes shared data* gets a private
  instance; a setup that fails marks its scenarios **Blocked**; implemented as Playwright setup projects. (5)
  **Executions are program-only.** A test execution (`TE-000001`, kind verification / regression / impact / ad-hoc)
  runs from a clean checkout of the **committed** workspace at a recorded commit (a git worktree, D16.7), records the
  QA environment, the commit and the `playwright-appian` / Playwright versions, and stores results per scenario and
  per case step (passed / failed / flaky / blocked / skipped / not-run, attempts, duration, error, attachments). One
  retry; fail-then-pass is **flaky**, never failed; a scenario flaky in ≥ 3 of its last 10 results gets a flaky badge
  (D14). One execution at a time per machine (F7). (6) **Library lifecycle (D16).** Actions and setups move **Draft →
  Ready → Retired** through `LifecycleService` (ADR-050): Ready needs a passing replay on QA at the current content
  hash; retire is refused while a non-retired action, setup, case script or scenario uses the item (the refusal names
  them); hard delete only for an item nothing ever referenced. Save = write → typecheck the workspace → one git commit;
  a breaking contract change (remove/rename an input or output, add a required input) is refused while the item is
  used. (7) **Scheduling (D11).** One fixed backend job, `regression-run` (ADR-047), runs the due applications'
  regression executions one at a time; each application's cadence is its job options; off by default (F13). (8)
  **Local only (D17).** The new tables carry the m0019 collab columns, unused; `ACT-`/`DS-`/`TE-` ids are per-machine
  counters (as `TC-`/`TS-`) and must be made machine-unique before any sharing phase.
- **Alternatives rejected.** Code in the database (no diffs, history or revert; not runnable by plain Playwright); one
  JSON library file (merge conflicts, no per-item history); copying steps into each scenario (a screen change is fixed
  in N places); agent-run executions (non-reproducible, credits per run; the agent authors, the program runs); a
  separate regression scenario model (duplicates Phase 49 scenarios); `globalSetup` for data (one failure blocks
  everything; Playwright recommends project dependencies); quarantine of flaky tests now (deferred).
- **Consequences.** Amends ADR-078: `automation_status` takes the values not-automated · automated · broken (store
  validated); a scenario may be owned by the application's regression suite and reference other features' cases; a
  scenario may name a data setup. m0026 (DB → v26) rebuilds `kb_test_suites` (`kind` feature | regression, nullable
  `feature_id`, `app_uuid`; the first table rebuild in Genesis, run by the migration runner's new `foreign_keys_off`
  flag with a `foreign_key_check` before commit) and adds `kb_test_settings`, `kb_test_users`, `kb_test_actions`,
  `kb_test_setups`, `kb_test_case_scripts`, `kb_test_refs`, `kb_regression_items`, `kb_test_executions`,
  `kb_test_results`, `kb_test_captures`, `kb_test_scenarios.setup_id` / `changes_shared_data` and three
  `kb_sequences` rows. Result rows are kept forever — a later scenario or case delete leaves them with the stored
  `scenario_key` / `case_key` — while trace/screenshot/report files follow ADR-022 retention (the
  newest 20 executions per application keep files, F11). `playwright-appian` stays its own repository with its own
  design record (D19); Genesis ADRs cover only how Genesis uses it. Basis for ADR-082 (where tests run), ADR-083 (how
  agents reach the browser) and ADR-084 (the Verification lane).

---

## ADR-082

| field | value |
|---|---|
| `--id` | `ADR-082` |
| `--title` | `The QA environment and test data writes (Phase 51)` |
| `--areas` | `config-secrets,browser-testing,appian-integration,security` |
| `--rule` | `All test execution and agent browser sessions run only on the single QA environment, as the app's test users, changing application data through the UI only — never design objects, deployments or MCP writes.` |
| `--amends` | `ADR-068,ADR-021` (D22) |
| `--status` / `--phase` | `proposed` / `51` |

- **Status:** **Proposed** — 2026-11-03 (Phase 51; `51-01-findings.md` D5, D7, D8, F2, F3, F12; built in 51-05).
- **Context.** Every Genesis write to Appian so far is either a design-object write in the Implementation lane
  (ADR-068) or a `genesis-delta-*` package (ADR-073), both on the single dev-tagged environment (ADR-036/048). Running
  tests means creating, changing and deleting **application data** — evaluations, vendors, ratings — and doing it on
  Dev would pollute the environment the KB syncs from. Environments today carry a free-text `type` and a single-select
  `is_dev` flag (`genesis/config/environments.py`).
- **Decision.** (1) **Environment type replaces the dev toggle:** Dev, QA, UAT, Production, Other; exactly one Dev (as
  today — KB sync, Implementation writes, core MCP credentials) and at most one **QA**, the testing environment.
  Migration: `is_dev: true` → Dev; an old free-text `type` → Production when it reads prod/production, else Other,
  with the old text kept in `notes` (F3). (2) **Every test execution and every agent browser session runs on the QA
  environment only** — story verification, regression, impact and ad-hoc runs; there is no per-run environment
  choice. With no QA environment the Deployment → Verification drag is refused with a dialog that names Settings →
  Environments (F2). Genesis refuses to run tests when the QA host equals the Dev host or any other environment's host.
  (3) **Only the application's test users** (D5): a role key, label and username per application in `genesis.db`, the
  password in the SecretProvider under `testusers-<app hash>/<ROLE>_PASSWORD` (F12), never in a file or the agent's
  view; Settings warns when a username matches the Dev-MCP service account. (4) **Application data through the UI
  only:** sessions are pinned to the QA site with `apwt --allow-host`; no design objects, no MCP write tools, no
  deployments. (5) **Approvals:** the Verification confirm dialog is the single blanket approval for a story's run;
  turning a regression schedule on is the approval for its scheduled runs; there are no per-step gates and agent
  sessions run in `apwt --mode full` (every step lands in the session's action log, which the run keeps). (6) Every
  run uses unique per-run values so runs never collide; there is no automatic cleanup this phase (QA data
  accumulates; cleanup actions can be library actions later). (7) The Deployment lane stays manual (D7): the user
  deploys dev → QA with their usual Appian deployment.
- **Alternatives rejected.** Testing on Dev (pollutes the KB source and the Implementation lane's environment); a
  per-run environment choice (several places where tests can run, harder to reason about); the Dev-MCP service
  account as the test user (a privileged identity driving the UI); a confirm on destructive-looking agent actions
  (QA exists to be written to — the host allow-list and the test-user rule are the boundary; the user dropped it);
  Genesis deploying dev → QA now (needs ADR-068/073 amendments, a rollback design and its own gate — deferred).
- **Consequences.** Amends ADR-068 and ADR-021 (D22). ADR-068: Implementation stays the only lane that mutates
  **design objects**; QA **application data** written through the UI by the test users is a second, narrower
  sanctioned write, on a different environment. ADR-021: like ADR-068 for the Implementation lane, the Verification
  confirm (and, for scheduled regression runs, the schedule toggle) replaces the `pre_mutation` gate for these writes;
  `story-verification`, `test-execution` and the `regression-run` job carry no `pre_mutation` gate, and ADR-021's
  "required before any write" no longer covers QA application data written through the UI as test users. ADR-036/048's
  single Dev environment is unchanged; the
  environment model gains a type. A Settings → Applications "Testing → Setup" view holds the QA site path and the test
  users (D15). Automated dev → QA deployment and QA data cleanup are later phases.

---

## ADR-083

| field | value |
|---|---|
| `--id` | `ADR-083` |
| `--title` | `Phase 51 browser agents and the isolation boundary (an accepted risk until Phase 52)` |
| `--areas` | `browser-testing,security,sdk-acp,core-engine,workflows-library` |
| `--rule` | `Phase 51 browser agents use Kiro's shell with the workspace's own apwt on program-opened, QA-pinned sessions; credentials never reach the agent; the missing isolation is an accepted risk until Phase 52.` |
| `--amends` | `ADR-029` |
| `--status` / `--phase` | `proposed` / `51` |

- **Status:** **Proposed** — 2026-11-03 (Phase 51; `51-01-findings.md` D3 → D3a → D3b → **D3c**, D3d; spike
  `51-03-spike-sandboxed-shell.md`, both As built sections, review `reviews/51-03-review.md` = SHIP). Phase 52 —
  agent runtime isolation (`specs/phase-52-agent-runtime-isolation/52-01-findings.md`) — is the fix.
- **Context.** Phase 51's explore, author and capture steps need an agent to drive a real browser on the QA site
  through `apwt`. Workflow agents today are ordinary `kiro_node` turns with an unrestricted shell: `auto_approve`,
  and `--trust-all-tools` for a node with no tool list (51-01 §2.3). Phase 51 adds a new untrusted input to such a
  turn: live QA page text, which can carry prompt injection. Four designs were tried in order: **D3** (Kiro's local
  command sandbox around the shell), **D3a** (the same with the mechanism corrected by the spike), **D3b** (no shell;
  a Genesis `appian-browser` MCP server in a fail-closed node) and **D3c** (the shell, as every workflow agent has it
  today, with isolation solved for **all** workflow agents in Phase 52). The spike measured each step on the user's
  macOS machine with `kiro-cli` 2.37.1.
- **Evidence (51-03).** *Sandbox sessions (S1, S5, S6):* `kiro-cli acp --agent-engine v3` ignores a project
  `sandbox.json` (the binary warns that the ACP launch path does not apply sandbox isolation; `s1-file.json`: `$HOME`
  write and network both succeeded). The sandbox turns on over ACP with the extension request `_kiro/sandbox/applyConfig`
  (`sandboxNetworkMode=default_blocked`, then `sandbox=enabled`) and reports `_kiro/sandbox/status {status:"active",
  backend:"seatbelt"}`; rules come from a per-run `KIRO_HOME/settings/permissions.yaml` (`s1-rpc.json`: `$HOME` write
  denied, network blocked, run folder and `$TMPDIR` writable). V3 ACP rejects `--trust-tools`, so "trust only the shell"
  is a client policy keyed on tool kind `execute`. A minimal allow-listed environment (`HOME, USER, LOGNAME, SHELL,
  TMPDIR, LANG, LC_ALL, TERM`, a fixed `PATH`, `PLAYWRIGHT_BROWSERS_PATH`) still authenticates (S5). Under the captured
  Seatbelt profile the bypass corpus is blocked at the OS layer — writes outside the run folder, reads of
  `secrets.json`/`genesis.db`/`.ssh`/`.aws`/the Kiro store/another run's session files, the network except the QA host
  via the proxy, `launchctl`/`osascript`/`ssh-agent`, and the agent cannot widen its own sandbox; the no-sandbox
  baseline allowed every item (S6, `s6-os-corpus.txt`, `s6-net-qa.json`, `bypass-nosandbox.json`). The model refused to
  run the corpus itself, so the proof is model-independent (L-088). **Residual 1:** Kiro's Seatbelt base profile always
  allows loopback, so a sandboxed shell can still call the unauthenticated Genesis API on `127.0.0.1:8760` (no origin or
  token check, ADR-026) — start an Implementation run that writes to Dev, answer a HITL gate, change Settings —
  reachable by prompt injection from page text. *D3c session (L1, S4, S8–S11, P10):* a program step opened and signed
  in a role's session (10.0–13.5 s); one real `kiro_node` turn (194.2 s, 26 tool calls, 8.44 credits) recorded a flow
  with `npx --no-install apwt` and the generated spec replayed green (L1); the agent shell's `env`, `ps -Eww` of the 11
  run processes, the session control files and every tool result and file held no password, while the same scan found
  it in 6 operator processes (the positive control) (S4); signed-in recording and one Chromium everywhere needed
  `playwright-appian` 0.3.0 (D-114: `record start --state`, `--browser chromium`) (S8/S9); provisioned skills and the
  blackboard MCP tools worked (S11); and a workflow turn **loads the user's global `~/.kiro/settings/mcp.json`
  servers and trusts them** (a `jira` server started with `JIRA_TOKEN`; `testcase-mcp` exposed Jira write tools) (P10,
  `d3c-p10.json`).
- **Decision.** (1) Phase 51 browser agents are **ordinary `kiro_node` agents** and use Kiro's shell like every other
  workflow agent today; no `appian-browser` MCP server, no fail-closed node, no sandbox (D3c). (2) They run **`npx
  --no-install apwt` from the run's workspace export** — the workspace's own `playwright-appian` (D4), never a global
  install — with the prompt giving the exact prefix (`cd <ws> && PLAYWRIGHT_APPIAN_HOME=<run>/.apwt npx --no-install
  apwt -s <role> …`); the CLI `playwright-appian` skill from that package and a `genesis-test-authoring` skill are
  provisioned per ADR-069. (3) **Program nodes own the sessions:** they open and sign in one session per role with
  `apwt -s <role> open <QA site> --login --allow-host <QA host> --mode full --browser chromium`, with the credentials
  only in that one subprocess's environment and `PLAYWRIGHT_APPIAN_HOME` inside the run folder; they pass the session
  names to the agent, and close the sessions and replay the specs as program steps (the replay subprocess also gets the
  role's credentials, and nothing else does). (4) **Signed-in recording** (D13) saves the role's login to a state file,
  starts `apwt record start --detach --browser chromium --state <file>`, and deletes the file once the recorder has
  started, so the recorder process never holds the password. (5) Explore/author turns get `turn_timeout` 900 s (F10).
- **Accepted risks (until Phase 52).** (a) **None of the session rules is enforced against the agent.** With the
  shell it can open its own session to another host, read the user's files (`~/.genesis/secrets.json`,
  `genesis.db`, `~/.ssh`), and call the local Genesis API — as any workflow agent can today — and Phase 51 adds live
  QA page text as a new untrusted input to such a turn. (b) The agent's shell **inherits the worker's whole
  environment** (S4 saw names such as `OPENAI_API_KEY` and `SSH_AUTH_SOCK`); the S5 clean environment is not applied.
  (c) The role's **password sits in the environment of the `open --login` and Playwright replay subprocesses** while
  they run (about 10 s), visible to a same-user `ps -Eww`; a `--password-stdin` option in `playwright-appian` would close
  that window (candidate follow-up). (d) **Every workflow turn loads the user's global Kiro MCP servers with full
  trust** (P10, D3d), which defeats ADR-004's "only the servers the step needs"; Phase 51 changes nothing here, since
  under D3c the shell can read that global configuration and its tokens anyway.
- **Alternatives rejected.** The sandboxed shell (D3/D3a): proven to box files, network and processes, but residual 1
  leaves the most dangerous target — the local API — reachable, and it needs new `kiro-agent-sdk`/`kiro_node` surface
  (an `env=` launch override, ACP extension requests, sandbox-status notifications). The `appian-browser` MCP server
  with a fail-closed node (D3b): removes the shell for these nodes only, adds a server and a skill variant to maintain,
  and leaves every other workflow agent as it is; the user chose to fix isolation for all agents at once (Phase 52)
  rather than change working workflows now. A globally installed `apwt` (version drift with the workspace's generated
  specs — `VERSION_MISMATCH` — PATH differences between nvm and Homebrew Node, machines without it). A clean `KIRO_HOME`
  for Phase 51 nodes only, or for every workflow now (D3d options B/C): little gain while the shell can read the global
  configuration.
- **Consequences.** Amends ADR-029: records that its effective-trust cap (`node.tools ∩ server.allowlist`) does not
  cap tools under `auto_approve` / `--trust-all-tools` — a node with no tool list trusts every tool, including the
  shell and any server from the user's global Kiro configuration, which sits outside both registry tiers. Not an
  ADR-020 violation (Genesis mutates no global Kiro configuration) but contrary to ADR-004's intent; named here so it is
  not lost. ADR-077's "never `--trust-all-tools`" governs the role agents and is unchanged. **Phase 52 (agent runtime
  isolation) is the fix:** every agent turn runs in a sandbox container that never sees `~/.kiro`, the user's files or
  the loopback API, with a clean environment (`52-01-findings.md` §8 option E, revised by §14 D1: Genesis and the agent
  sandboxes run inside a Genesis-owned Linux VM). The S1/S5/S6 Seatbelt recipe and its residuals are Phase 52 input as
  an optional second layer (§7 option B), not the fix.
  When Phase 52 ships, this ADR is amended (the accepted risks close) rather than the Phase 51 nodes being rebuilt.

---

## ADR-084

| field | value |
|---|---|
| `--id` | `ADR-084` |
| `--title` | `Lane order and Verification lane automation (Phase 51)` |
| `--areas` | `stories-workbench,features-stages,browser-testing,workflows-library` |
| `--rule` | `Deployment precedes Verification; dragging a story into Verification (after confirming QA has its changes) launches story-verification; pass → Done, product defect → Implementation, blocked → a gate.` |
| `--amends` | `ADR-061` |
| `--status` / `--phase` | `proposed` / `51` |

- **Status:** **Proposed** — 2026-11-03 (Phase 51; `51-01-findings.md` D6, D7, D12, F2, F10; built in 51-09).
- **Context.** The eight Workbench lanes (ADR-061) end Code Review → Verification → Deployment → Done, so a story
  would be verified before its changes reach the environment it is tested on. Phase 51 tests on QA only (ADR-082) and
  the Design and Implementation lanes already launch workflows from a confirmed drag (ADR-062/068).
- **Decision.** (1) **Lane order:** To Do → Design → Design Review → Implementation → Code Review → **Deployment →
  Verification** → Done. Edges: `code-review --approve--> deployment`, `deployment --deployed--> verification`,
  `verification --verify--> done`, `verification --reject--> implementation` (replacing `code-review → verification`,
  `verification → deployment`, `deployment → done`). Lane values are unchanged, so stored story statuses and the Hub's
  board data need no migration. (2) **Deployment stays manual** (D7): the user deploys dev → QA, then drags the card
  into Verification. (3) That drag opens a **confirm dialog** — the user confirms the changes are on QA; without a QA
  environment the drag is refused (F2) — and launches the **`story-verification`** workflow. (4) The workflow (D12):
  **explore** (one session per affected role, no testing) → **author** (a case script per story case from library
  actions, a data setup per scenario, new actions/setups where the library has none; a program validator checks every
  case has a script, the workspace typechecks and `playwright test --list` sees every scenario) → **execute** (program
  only, ADR-081) → **triage** each failure: *script defect* → heal in place (ADR-067: ≤ 1 patch, ≤ 1 guided restart)
  and re-run that scenario; *product defect* → stays **Failed** with expected vs actual, screenshot and trace;
  *blocked* (QA unreachable, sign-in fails, a setup will not build) → an escalation gate (retry / send back / accept)
  → **decide**: all story cases pass → `verify` (**Done**); any product defect → `reject` (**Implementation**,
  automatically, with a defect report on the story); fail-then-pass = passed and flaky. Every agent node keeps the
  ADR-011 trio. (5) On a pass the run prepares **proposals** — new actions/setups, the story's scenarios for the
  regression suite, changes to existing actions — accepted per item or all on the report and committed to the
  workspace; the move to Done does not wait for them. (6) A test execution report (HTML) is shown on the story page.
  (7) Every status change goes through `LifecycleService` (ADR-050) and the m0013 audit, driven by a run→story
  finalizer that stores the terminal state before it announces it and recovers level-triggered (L-058, L-093).
- **Alternatives rejected.** Keep the order and deploy before moving to Verification (the board would not say the
  story is deployed); Genesis deploys as part of Verification (needs ADR-068/073 amendments and a rollback design —
  deferred); verify on Dev (ADR-082); require a human pass/fail decision (the case's Then is the oracle; humans review
  proposals, not results).
- **Consequences.** Amends ADR-061 (the order of the eight fixed lanes and the story-stage edges in
  `domain/transitions.py`). Extends the ADR-062/068 lane-automation pattern to a third lane: a confirmed drag launches
  the lane's workflow, the workflow's outcome drives the audited transition. The Hub board contract is unchanged
  (lane values only). Automated dev → QA deployment from the Deployment lane is a later phase.
