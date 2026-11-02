# Phase 51 — Test execution engine: action library, regression suite and story verification

> **Status:** SPEC-DRAFTED 2026-11-02 · **Author:** genesis-spec agent.
> Sub-specs: `phase-51-test-execution-engine/51-01..51-13`. Findings (code facts, research, every decision):
> `51-01-findings.md`.
> Repos: **genesis** (backend + web, migration **m0026**), **genesis-workflows** (three new workflows + one skill),
> **playwright-appian** (joins the agent system, D19; additive changes as needed), **project-tracker** (agent system).
> Proposed ADRs: **ADR-081** (test automation architecture), **ADR-082** (the QA environment and test data writes),
> **ADR-083** (workflow agents get no shell; browser access through a Genesis MCP server), **ADR-084** (lane order +
> Verification lane automation).
> Part 2 of the testing framework (part 1 = Phase 49 Test Design).

## 1. Why this phase exists

Phase 49 records **what** to test: `TC-` cases with Given/When/Then, ordered `TS-` scenarios, per-feature suites and
Test Impact. Nothing can **run** a test. `playwright-appian` (`apwt`) was built for Genesis so agents can understand and
drive Appian interfaces and leave behind label-based Playwright scripts that re-run without an agent; it leaves managed
storage, composition, intent and triage to "the SDLC application" (its `planning/phase-01/08-roadmap.md:72-77`). This
phase is that layer: a per-application library of reusable automation, a regression suite built from references, an
execution engine with results, and the Workbench Verification lane.

## 2. Goal

1. **Action Library** per application: reusable **actions** (`ACT-`) and **data setups** (`DS-`) as code, with
   contracts, where-used, history, a Draft → Ready → Retired lifecycle, an in-browser editor, and **Record workflow**
   (a person records; an agent splits the recording into actions; you review).
2. **Case scripts** for `TC-` cases; **scenario specs** generated from the Phase 49 tables; nothing copied.
3. **Execution engine:** program-only runs on the **QA environment** (no agent, no credits), minimal data through
   shared data setups, per-scenario and per-case results, flaky detection, Playwright reports.
4. **Regression suite** per application (feature scenarios + cross-feature regression scenarios), scheduled daily or
   weekly by Genesis; **Run impacted tests** from Test Impact.
5. **Story verification:** lanes reordered so Deployment precedes Verification; dragging into Verification runs an
   agent workflow that explores, authors, runs, triages and decides (Done or back to Implementation), proposes library
   and regression updates, and writes a report.

## 3. Decisions (locked with the user, 2026-11-02 — detail and rationale in `51-01-findings.md` §7–§8)

| # | Decision |
|---|---|
| D1 | Code = files in a per-application **git** workspace; catalog (ids, contracts, where-used, suites, results) in `genesis.db` with path + hash. |
| D2 | Layers: Action ← data setup / case script ← scenario (generated spec) ← regression suite; references only. |
| D3 | ~~Sandboxed shell~~ (D3a) → ~~MCP server~~ (D3b) → **D3c (current):** Phase 51 browser agents use Kiro's shell like every other workflow agent, running `npx --no-install apwt` from the run's workspace export; program nodes open and log in the QA sessions; not enforced against the agent — **accepted risk until Phase 52** (agent runtime isolation). |
| D4 | Node ≥ 20 prerequisite; `playwright-appian` tarball vendored in genesis; a self-contained npm project per app; Playwright's own Chromium. |
| D5 | Environment **type** dropdown (Dev, QA, …) replaces the dev toggle; **all testing on QA**; QA site URL + test users by role in the app's Testing tab; every affected role recorded/explored. |
| D6 | Lanes: … Code Review → **Deployment → Verification** → Done. |
| D7 | Deployment stays manual (you deploy dev → QA); automated deployment is a later phase. |
| D8 | ADR: tests may write **application data on the QA host only**, as test users, UI only; the Verification confirm / schedule toggle are the approvals; agents run `apwt --mode full`; unique per-run data, no cleanup. |
| D9 | Regression suite = feature-scenario references + its own cross-feature regression scenarios. |
| D10 | Data setups: built once per execution, shared; "changes shared data" scenarios get a private instance; setup failure = Blocked; Playwright setup projects. |
| D11 | Genesis scheduler: one fixed `regression-run` job, per-app cadence in its options; serial; GitLab CI deferred. |
| D12 | Verification: explore → author → execute → triage (script / product / blocked) → decide (Done / back to Implementation / gate) → proposals → report. |
| D13 | Record workflow: role picked, signed-in Chromium on QA, one role per recording, `action-capture` run → reviewed proposals; trace kept. |
| D14 | `TE-` executions; results per scenario and case step; 1 retry, flaky label + history badge; `automation_status` not-automated / automated / broken; in-app signals only. |
| D15 | One application tab **Testing** with Library · Regression · Executions · Setup. |
| D16 | Library items: Draft → Ready → Retired, delete only if never used; CodeMirror 6 editor; typecheck + commit per save; contracts; history/revert; adopt outside edits; executions run committed code only. |
| D17 | Local only; Hub-ready columns; sharing later via a GitLab remote per workspace. |
| D18 | One phase, one release. |
| D19 | `playwright-appian` joins the agent system as its own repo; its `planning/` stays the home of its internal design; publish it before the Genesis release that vendors it. |

Defaults F1–F14 (confirmed) and the workspace location (`~/.genesis/testing/`): `51-01-findings.md` §8.

## 4. Current state (code-grounded — full detail in `51-01-findings.md` §2–§3)

| Area | Today | File(s) |
|---|---|---|
| Test records | Per-feature suites, `TC-`/`TS-`, ordered steps, story + object links; `automation_status` unused | m0025, `genesis/genesis/kb/testdesign.py` |
| Test Impact | objects / story / sync → suites → scenarios → cases, on demand | `genesis/genesis/services/testimpact.py`, `api/testdesign.py:446` |
| Workbench | 8 lanes; Design + Implementation launch runs; finalizer pattern | `domain/transitions.py:99-127`, `api/workbench.py:179,290`, `chat/story_implementation_finalizer.py` |
| Managed CLIs | single binaries only (`gws`, `sail`); no Node; `cli_node` has no timeout | `cli_tools/native/installer.py`, `genesis_core/nodes/cli.py:26` |
| Agent tools | MCP only per node; no shell; Kiro launched with the worker's whole environment | `genesis_core/nodes/agent.py:195-301`, `kiro_agent_sdk/client.py:182-190` |
| Scheduler | fixed `DEFAULT_JOBS`; `options_json` seam | `runtime/scheduler.py`, `runtime/sync_jobs.py:37` |
| Environments | `url`, `api_endpoint`, free-text `type`, single-select `is_dev` | `config/environments.py:24-49` |
| `playwright-appian` 0.2.0 | trace → flat spec (deterministic); agent sessions with `--json`; person recorder | `playwright-appian/src/**` |

## 5. Design overview

```
                    Settings → Environments: type = Dev | QA | …          (51-05)
                                   │ QA host + site path + test users (Testing → Setup)
                                   ▼
 Record workflow ─► apwt recorder ─► trace ─► action-capture run ─► proposals ─► Action Library   (51-07)
 (person, one role)                                                   accept      ~/.genesis/testing/apps/<app>/  (git)
                                                                                   actions/ setups/ cases/ suites/ lib/
 Phase 49 TC-/TS- ─────────────────────────────── case scripts ◄── agents (verification) / editor
        │                                                                 │
        ▼                                                                 ▼
 Scenario specs generated from the DB (51-06) ─► execution checkout (committed) ─► npx playwright test (QA)
        ▲                                                       │ setup projects per data setup (D10)
 Regression suite (51-08) ─ schedule (regression-run job)       ▼
 Test Impact ─ Run impacted tests                     results.json ─► finalizer ─► kb_test_results / automation_status
 Workbench: Deployment ─drag─► Verification ─► story-verification run (51-09)
            explore (Kiro shell + workspace `apwt` on program-owned QA sessions, D3c) → author → execute → triage/heal → decide → proposals → report
            pass ─► Done · product defect ─► Implementation · blocked ─► gate
```

| Building block | Sub-spec |
|---|---|
| Findings + decisions | 51-01 |
| `playwright-appian` joins the agent system | 51-02 |
| Spike: sandbox evidence (done) + the D3c loop (shell + workspace `apwt` on program-owned sessions), signed-in recording, Chromium, timing (gate) | 51-03 |
| ADRs + data model (m0026), stores, ids, lifecycle | 51-04 |
| Runtime, workspaces, environment types, test users | 51-05 |
| Execution engine (generation, setups, runs, results, queue, impact run, schedule job) | 51-06 |
| Action Library + Record workflow + `action-capture` | 51-07 |
| Regression suite | 51-08 |
| Story verification (lanes, workflow, finalizer, proposals, report) | 51-09 |
| HTTP API | 51-10 |
| Web experience | 51-11 |
| Review, hardening, live acceptance | 51-12 |
| Release + docs write-back | 51-13 |

## 6. Session plan

S1 = 51-02 (**genesis-docs**, project-tracker agent system) → S2 = 51-03 spike (genesis-dev; **gate**: if the
D3c loop — program-owned sessions + agent `apwt` through the shell — cannot complete on QA, stop and re-spec 51-05 /
51-07 / 51-09 before continuing) → S3 = 51-04 → S4 = 51-05
→ S5 = 51-06 → S6 = 51-07 (genesis + genesis-workflows) → S7 = 51-08 → S8 = 51-09 (genesis + genesis-workflows) → S9 =
51-10 (API completion + contract fixtures; each backend sub-spec adds its own routes, 51-10 owns the contract table and
the cross-cutting tests) → S10 = 51-11 → S11 = 51-12 (genesis-review) → S12 = 51-13 (genesis-release, then
genesis-docs). One at a time: they share the genesis checkout. A `playwright-appian` change found in any session is
made in that repo in the same session (D19), with its own tests, and recorded in the sub-spec's As built.

## 7. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 51-01 | project-tracker | Findings, decisions D1–D19, defaults F1–F14 |
| 51-02 | project-tracker (agent-system) | Repo list, new `browser-testing` area + gates, agent allow rules, release flow, invariants |
| 51-03 | genesis (spike code + notes), playwright-appian (if needed) | Sandbox evidence S1/S5/S6 (done; ADR-083 and Phase 52 rationale); then the D3c items: the full loop on QA (program-owned login, agent shell + workspace `apwt`, spec replays), no credential in the agent's view, signed-in recording, Chromium everywhere, timing, skills + blackboard |
| 51-04 | genesis | m0026 (catalog, executions, results, test users, settings, suite rebuild), stores, `ACT-`/`DS-`/`TE-` ids, lifecycle, ADR texts |
| 51-05 | genesis, playwright-appian (if needed) | Node/Chromium detection + install, vendored tarball, `TestWorkspace`, `ApwtClient`, program-owned sessions for agents (D3c), environment types + QA, test users, test settings |
| 51-06 | genesis, genesis-workflows | Spec generator, setup projects, execution checkout, `test-execution` workflow + finalizer, queue, Run impacted tests, `regression-run` job, subprocess hygiene |
| 51-07 | genesis, genesis-workflows | Library service (save/typecheck/commit/retire/delete/revert/adopt, refs), `lib/` helper, recording service, `action-capture` workflow + finalizer, proposals, `genesis-test-authoring` skill |
| 51-08 | genesis | Regression suite (own scenarios, references, grouping), schedule settings + job handler, latest/trend |
| 51-09 | genesis, genesis-workflows | Lane reorder + transitions, `start_verification`, `story-verification` workflow, `StoryVerificationFinalizer`, proposals, report, defects on the story |
| 51-10 | genesis | API contract table + contract fixtures + cross-cutting tests |
| 51-11 | genesis (web) | Testing tab, item pages + editor, execution page + report, Settings env dropdown + runtime card, Workbench dialog + Verification view, case/scenario/Test Impact additions, `web/static` |
| 51-12 | genesis, genesis-workflows, playwright-appian | Independent review + gates + live acceptance on a real QA environment (incl. width probe, L-090) |
| 51-13 | all four | Release order, deploy, docs write-back (ADR-081..084) |

## 8. Release plan

If `playwright-appian` changed: release it first (tag `vX.Y.Z` → its CI publishes) and vendor that exact tarball into
genesis. Then **genesis v0.81.0** (minor; m0026, DB 25 → 26). Then **genesis-workflows v0.25.0** (`test-execution`,
`action-capture`, `story-verification`, the `genesis-test-authoring` skill) pinned on `genesis.git@v0.81.0` (L-057).
Without the workflows installed, every start returns the friendly "not installed" 409 (L-033). No Hub change. Detail:
51-13.

## 9. Scope

- **In:** §2; the four ADRs; the environment-type change; tests (pytest, workflow tests, `playwright-appian` tests,
  Vitest + jest-axe).
- **Out:** automated dev → QA deployment (D7); Hub sync and GitLab remotes for workspaces (D17); GitLab CI scheduled
  pipelines and result import (D11); quarantine; desktop/email notifications (D14); test data cleanup (D8); SSO/MFA
  test users (`playwright-appian` supports username/password only); data-driven datasets (shared parameters).
- **Deferred** (backlog `specs/backlog/phase-51-follow-ups.md`, created by 51-13): the items above plus Xray/TestRail
  result export, cross-browser projects, visual comparisons, API-based data setups.

## 10. Defaults

F1–F14 in `51-01-findings.md` §8. Key ones: QA missing → Verification drag refused (F2); one execution at a time per
machine (F7); 1 worker, 1 retry (F6); schedule off by default (F13); files kept for the last 20 executions (F11).

## 11. Risks

| Risk | Mitigation |
|---|---|
| A browser agent goes beyond its sessions (opens another host, reads files, calls the local Genesis API) | **Accepted until Phase 52** (D3c, ADR-083): program-owned sessions pinned to QA, credentials never in the agent's environment, skill + prompt conventions; every shell command is in `run_events`; Phase 52 boxes every agent turn |
| An agent sees a secret | Program-owned sessions; the MCP server and Kiro start with a clean environment; corpus in 51-03 and 51-12 (L-088) |
| Shared data setups couple scenarios (one scenario breaks the next) | Read-only first ordering, "changes shared data" private instances, Blocked vs Failed (D10) |
| Library edits break many tests at once | Contracts + breaking-change refusal, where-used re-run, git revert, proposals for agent changes (D12, D16) |
| Flaky Appian UI timing | `playwright-appian`'s Appian waits; 1 retry + flaky history (D14) |
| Long browser runs block or orphan processes | Timeouts + process groups (F8); queue (F7); `globalTimeout` (F6) |
| Lane reorder surprises a consumer | Grep every consumer of `STORY_LANES`/lane order (L-094); 51-09 §2 list |
| SQLite table rebuild of `kb_test_suites` (D9) | SQLite's documented 12-step procedure with `foreign_keys` off and `foreign_key_check`; upgrade test on a v25 DB with data (51-04 §2) |
| QA data accumulates | Unique per-run values; cleanup is a later library feature (D8) |
| Version skew (genesis vs workflows vs `playwright-appian`) | Vendored exact tarball; release order (§8); L-033 409s |

## 12. ADR summaries (Proposed — full text added at release by genesis-docs from 51-04 §6)

- **ADR-081 — Test automation architecture.** Test code lives as files in a per-application git workspace (a
  self-contained npm + Playwright project); `genesis.db` holds the catalog. Layers: actions (contracts) ← data setups /
  case scripts ← generated scenario specs ← suites; references only, never copies. Executions are program-only (no
  agent), run committed code, and record per-scenario and per-case results. Amends ADR-078 (automation status values;
  regression-owned scenarios across features).
- **ADR-082 — The QA environment and test data.** Environments carry a type (Dev, QA, …); all test execution and agent
  browser sessions run on the single QA environment, may create/change/delete application data there through the UI as
  the application's test users only, never design objects; the Verification confirm and the schedule toggle are the
  approvals. Amends ADR-068 (Implementation stays the only lane that mutates design objects).
- **ADR-083 — Phase 51 browser agents and the isolation boundary.** Browser agents drive `apwt` through Kiro's shell
  with the workspace's own `playwright-appian` (`npx --no-install apwt`), on sessions opened, logged in and pinned to
  the QA host by program nodes; credentials never in the agent's environment. Recorded as an **accepted risk** until
  Phase 52: workflow agents have an unrestricted shell today (`auto_approve`, `--trust-all-tools` for nodes with no
  tool list; 51-01 §2.3), so these measures are conventions, not a boundary; a sandboxed shell (51-03 S1/S6) was
  rejected because Kiro's sandbox always allows loopback to the unauthenticated local API. Phase 52 boxes every agent
  turn. Amends ADR-029 (documents that the allowlist does not cap untrusted tools under `auto_approve`).
- **ADR-084 — Lane order and Verification lane automation.** Deployment precedes Verification; dragging into
  Verification launches `story-verification`; pass → Done, product defect → Implementation, blocked → gate; audited
  transitions. Amends ADR-061 (lane order) and extends ADR-062/068's lane-automation pattern.

## Context manifest

```toml
areas    = ["features-stages", "stories-workbench", "runs-worker", "workflows-library", "config-secrets", "distribution", "web-shell", "db", "api"]
adrs     = ["ADR-001", "ADR-010", "ADR-011", "ADR-012", "ADR-021", "ADR-029", "ADR-040", "ADR-047", "ADR-048", "ADR-061", "ADR-062", "ADR-067", "ADR-068", "ADR-069", "ADR-078", "ADR-079"]
lessons  = ["L-033", "L-057", "L-058", "L-088", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-49-test-design.md"]
code     = ["genesis/genesis/kb/testdesign.py", "genesis/genesis/api/workbench.py", "genesis/genesis/domain/transitions.py"]
upstream = []
```
