# 11. Quality scenarios, risks and technical debt

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 sections 10 and 11

Section 1.3 named the quality goals. This page makes them testable with concrete scenarios, then lists the
known risks and technical debt in v0.81.0.

## 11.1 Quality scenarios

A quality scenario says: when *this* happens, the system must respond *this way*. Each row names the
mechanism that delivers it.

| Goal | Scenario | Expected response | Mechanism |
|---|---|---|---|
| Trustworthy output | An agent writes an analysis that is missing a required section | The validator fails; the step runs again with the failure message; after the retry budget a person is asked | Reliability trio ([core-engine](modules/core-engine.md#54-how-validators-and-the-trio-route)) |
| Trustworthy output | A verify step finds three wrong items in a 40-item backlog | Only those items are patched and re-verified; at most one guided restart; then a person | Healing tier (ADR-067) |
| Human control | The engineer pauses a run in the middle of a 7-minute agent turn | The worker is killed at once; the run shows Paused; resume re-runs that step from the last checkpoint | Disposable worker (ADR-012) |
| Human control | A workflow is about to write to the Appian Dev environment | Nothing is written until a person approves, through a gate or the lane's confirm | ADR-021, ADR-068 |
| Human control | The copilot decides to cancel a run | A confirm card appears; nothing happens without Allow | ADR-033 |
| Durability | The app process is killed while three runs are active | At the next start the runs are failed as "worker lost" (or adopt their logged end), and every finalizer catches up | Startup sweep and reconciles ([07](07-runtime-view.md#77-the-app-restarts-while-runs-are-active)) |
| Durability | A cancel and a worker crash finish a run at the same moment | Exactly one terminal status and one `run.final` | Compare-and-set (L-108) |
| Durability | Two browser tabs edit the same story | The second save answers 409 with the expected version | `row_version` |
| Safety | A web page on another site tries to read a Playwright report's data through `/api` | The report runs on another origin and cannot reach `/api` | Reports origin (ADR-085) |
| Safety | A test-user password could appear in a Playwright report | Every report file, including zips, is scrubbed in raw, JSON, XML and HTML-escaped forms | L-105 |
| Safety | Someone runs `genesis serve --host 0.0.0.0` | It refuses unless `--i-understand-no-auth` is given | ADR-026 |
| Observability | Kiro does not report credits for a turn | The turn shows credits as unavailable; totals are not reduced | ADR-032 |
| Observability | An engineer asks "what exactly did the agent see on its second attempt?" | The turn explorer shows that attempt's prompt file, conversation, outputs and metrics | ADR-066 |
| Simple authoring | A contributor adds a workflow without a validator after an agent step | `genesis test-workflow` and the library CI fail with the node name | Reliability lint |
| Local-first | The Genesis Hub is unreachable | Publishing and pulling pause; every local feature keeps working | ADR-063 |
| Local-first | GitLab is unreachable | Installed workflows keep running; only browse and install fail | Installed library copy |

## 11.2 Risks

| Risk | Impact | Current treatment |
|---|---|---|
| **Workflow agents are not isolated.** Permission requests are auto-approved, Kiro's shell is available, the user's global Kiro MCP servers are loaded, and the shell inherits the worker's environment. Prompt injection from untrusted input (QA page text, documents) could reach the user's files, tokens or the local API. | High | Accepted risk in ADR-083. Agent isolation is the planned fix (Phase 52). Credentials for Appian and test users never enter prompts. |
| **No authentication on the local API.** Any local process can call it; a cross-site body-less POST is not blocked. | High on a shared or compromised machine | Loopback-only bind (ADR-026). Reports on a separate origin (ADR-085). Listed in the Phase 51 follow-ups backlog. |
| **Kiro CLI behaviour changes between versions.** The ACP extension surface is not fully documented. | Medium | The SDK accepts naming variants; behaviour is probed on the installed CLI before designs rely on it (L-044). Phase 53 is moving to Kiro's v3 engine with recorded fixtures. |
| **The live Appian side differs from its documented contract or from local emulators.** | Medium | Live acceptance passes on the real environments (L-078, L-111); contract fixtures for the Hub. |
| **One SQLite file for every writer.** The checkpointer, the app and program nodes write the same file. | Medium under heavy parallel runs | WAL, a 30 s busy timeout, blocking writes off the event loop (L-026). Postgres stays behind explicit triggers (ADR-030). |
| **Secrets are a plaintext JSON file.** | Medium | File mode 0600, atomic writes, values never logged or put in state. |
| **A dead `kiro-cli` holds a workflow turn until its timeout.** The v0.81.0 SDK does not fail a pending request when the process exits. | Low (time, not data) | The turn ends with an error after `turn_timeout` and the trio retries. Phase 53's client fails pending requests at end of file. |
| **One test execution at a time per machine.** | Low | A visible queue; verifications share it. |

## 11.3 Technical debt

Known items in v0.81.0, found by the module authors. Each module document describes the current behaviour; this
list says what should change. A fuller list of unverified findings from the documentation pass is in the
project's backlog (`specs/backlog/architecture-docs-findings.md`).

| Area | Debt |
|---|---|
| Runs | The run worker loads only the curated MCP and CLI registries and gives the CLI registry no launch provider, so custom servers and managed CLIs are not reachable through `ctx.mcp`/`ctx.clis` in a run. |
| Lifecycle | Some stage-start routes set `in-progress` without the lifecycle service and its audit; a deprecated spec status route bypasses the transition table. |
| Workbench | The implementation finalizer has no startup reconcile (only on board read). Start routes move a card before starting the run, so a failed start leaves the card moved. |
| Chat | `reap_idle` has no caller, so idle chat clients are not closed. Copilot limits apply to run start only. |
| Lint | `check_hitl_posture` is not called by any gate, and its gate-kind check does nothing. Library JSON schemas are not used by any gate. |
| Versions | The API and SPA version literals are edited by hand each release (a test checks they match). |
| Data | The retired `kb_feature_specs` tables are still created and written. |
| Web | The navigation differs from ADR-049; the `/dev` gallery is in the production bundle; the run graph has no level-of-detail rendering. |
| Logging | Worker stderr reaches only the run's error detail, not `genesis.log`; two context fields are declared but never bound. |
| Docstrings | Several module docstrings describe earlier behaviour (sync modes in `api/applications.py`, collaboration bindings in `collab/service.py`, the checkpointer signature). |
