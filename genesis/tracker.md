# Genesis — Master Tracker

> **Genesis** is an agentic SDLC platform for the Appian **Solutions** department.
> It is a local web application that orchestrates multi-step SDLC **workflows**
> using **LangGraph** as the engine and **Kiro** (via `kiro-agent-sdk` over ACP)
> as the agent runtime. Workflows are pulled from a shared GitLab library and run
> on the user's machine with their own credentials.

| | |
|---|---|
| **Program** | Genesis |
| **Platform repo** | `genesis` (local web app + LangGraph engine + config UI) |
| **Workflow library repo** | `genesis-workflows` (workflow packages + authoring steering) |
| **Agent adapter** | `kiro-agent-sdk` (Kiro ACP node adapter — already built) |
| **Engine** | LangGraph (v1) |
| **Users** | Internal Solutions dept — Dev, Tester, PO, UX |
| **Status** | 🟢 Phases 1–7 COMPLETE (M1–M7) + post-M7 live bring-up. Workbench runs real workflows: **hello-appian green end-to-end**; **erd-generation** past MCP init into the live Atlas fetch after fixing the ACP MCP env-shape bug (+ `genesis install` CLI, SSE loop, diagnostics, real MCP images). Latest: kiro-agent-sdk **v0.1.0**, genesis-core **v0.4.0**, genesis **v0.7.0**, genesis-workflows **v0.3.0** (M7.1 data plane shipped). 43 platform + 5 frontend + 16 core + 9 workflow tests green; CI green. Next: Phase 8 (skill migration). |
| **Agent onboarding** | [`AGENT_ONBOARDING.md`](AGENT_ONBOARDING.md) — paste into any new agent session working on fixes/enhancements |
| **Supersedes** | solutions-copilot (retired) — Genesis realizes its deferred doc-19 orchestrator |
| **Created** | 2026-07-07 |

---

## 1. What Genesis is (and why it exists)

solutions-copilot tried to use an **LLM agent as the orchestrator** of multi-step
SDLC skills. It failed the way agent-orchestrators fail: agents skipped steps and
didn't follow the skill's workflow. solutions-copilot's own `19-workflows-orchestration-deferred.md`
concluded durable external orchestration was needed and explicitly named LangGraph.

**Genesis is that orchestrator.** The control flow moves out of the model and into
LangGraph. Each former "skill" becomes a **workflow** — a Python LangGraph package
whose steps are either deterministic **program nodes** or narrow **agent nodes**
(Kiro via ACP). Determinism of sequencing never depends on a model's discipline.

Positioning: **Genesis replaces solutions-copilot.** The agents/skills/powers/
IDE-installer model is retired. We keep the *content* (the 45 skills become the
specs for workflows) and proven *patterns* (manifest→catalog, lockfile, MCP
wiring, analysis-doc handoff), reimplemented natively in Genesis.

---

## 2. Locked design decisions (Q1–Q14)

| # | Decision | Detail |
|---|---|---|
| **Q1** | **Local web app; shared GitLab library; internal Solutions users** | Engine + Kiro/MCP run locally with the user's creds; workflows pulled from GitLab; users = Dev/Tester/PO/UX. |
| **Q2** | **Per-node MCP injection** (not global-installed agents) | Each agent node opens an ACP session with only the MCP server(s) it needs; session closes after the step. Proven in the ERD workflow. |
| **Q3** | **No "profiles"** — shared **MCP registry** only | One registry defines how each MCP server launches + its secrets. Nodes reference servers by name + carry their own prompt/tools. |
| **Q4** | **Workflow = self-contained package**; catalog via `registry.json` | Folder per workflow: `workflow.yaml` (META) + `graph.py` (`build()`), `common/` shared lib, root `registry.json` + `mcp-registry.json`. |
| **Q4** | **Selective install + lockfile** | Persona-driven; users install the workflows they need; pinned by ref; update detection. |
| **Q5** | **Role = filter tag + curated bundles**; cross-role picking allowed | No hard gating; multi-hat users; "install the Tester set" bundles for onboarding. |
| **Q6** | **Single app** (engine + UI bundled); **Studio first, custom workbench later** | Validate on LangGraph Studio, then build the bespoke web workbench. |
| **Q7** | **All three HITL modes required** | (1) designed approval gates, (2) ad-hoc pause/resume anywhere, (3) mid-run state injection. All important, v1. |
| **Q8** | **Small editable state + pointers; bulk in per-run artifacts folder; local SQLite checkpointer** | State is human-editable; blackboard holds bulk data + cross-agent handoff docs. |
| **Q9** | **Reliability standard = HARD REQUIREMENT** | Every agent node must have a program **validator** + **retry/escalation**; enforced in library CI at publish time. Retry count configurable per workflow; escalates to HITL on exhaustion. |
| **Q10** | **`build()` + `META` contract; validated in CI; run in a subprocess worker** | Trust internal GitLab + CI + pinned refs; graph execution runs in a disposable subprocess worker (ADR-012), not in-process — crash/hang/leak isolation + kill switch. genesis-core semver + hard major-compat gate (ADR-019). |
| **Q11** | **solutions-copilot retired; Genesis has its own config UI** | Reuse concepts (SecretProvider, env registry, GitLab client) as fresh implementations. |
| **Q12** | **Authoring: scaffolder + templates + test harness AND agent-assisted authoring**; **authoring steering in the library**; open contribution | Any Solutions engineer can build a workflow, guided. |
| **Q13** | **Build the complete application + ERD workflow first; then migrate skills one by one** | Custom workbench UI is the one explicitly-deferred piece (Studio interim). |
| **Q14** | **Name = Genesis** | Platform `genesis`, library `genesis-workflows`, SDK `kiro-agent-sdk`. |

---

## 3. Phase index (see `specs/` for the detailed spec of each)

| Phase | Spec file | Title | Outcome |
|---|---|---|---|
| — | `specs/00-architecture-overview.md` | Architecture Overview | Shared reference for all phases |
| 1 | `specs/phase-01-core-platform-foundation.md` | Core Platform Foundation | Engine, node framework, state, checkpointer, blackboard, MCP registry, validator/retry |
| 2 | `specs/phase-02-workflow-contract-and-library.md` | Workflow Contract & Library System | `build()`/`META` contract, common lib, authoring scaffolder + steering, CI enforcement |
| 3 | `specs/phase-03-distribution-install-lockfile.md` | Distribution: GitLab Pull, Selective Install, Lockfile | Catalog browse, install/update/remove, lockfile |
| 4 | `specs/phase-04-configuration-and-secrets.md` | Configuration & Secrets | Config UI, SecretProvider, env registry, GitLab token |
| 5 | `specs/phase-05-run-orchestration-and-hitl.md` | Run Orchestration & HITL | Run lifecycle, all 3 interrupt modes, streaming, Studio integration |
| 6 | `specs/phase-06-erd-reference-workflow.md` | ERD Reference Workflow | ERD ported to Genesis as the canonical template |
| 7 | `specs/phase-07-custom-web-workbench.md` | Custom Web Workbench UI | Bespoke run/observe/interrupt UI (deferred item) |
| 7.1 | `specs/phase-07-01-web-revamp-program-overview.md` | **Web Revamp** — Program Overview & Frontend Architecture | ADR-027 stack, folder/routing/state architecture, delivery plan (anchor) |
| 7.1 | `specs/phase-07-02-backend-data-plane.md` | Web Revamp — Backend & Core Data-Plane | Persistent event log, gate-from-checkpoint, ACP conversation streaming, topology/steps/artifact-content/status APIs |
| 7.1 | `specs/phase-07-03-design-system.md` | Web Revamp — Design System & Component Library | Tokens/themes, shadcn/ui inventory, layout primitives, a11y |
| 7.1 | `specs/phase-07-03a-visual-language-reference.md` | Web Revamp — Visual Language Reference (Overcut-inspired) | First-hand Overcut study; tokens/patterns Genesis adopts + how it innovates on top |
| 7.1 | `specs/phase-07-04-settings-configuration.md` | Web Revamp — Settings & Configuration | MCP/CLI cards + live status, config drawer, connection test, environments |
| 7.1 | `specs/phase-07-05-catalog-and-install.md` | Web Revamp — Catalog & Install Management | Browse/filter/prereqs, install/update/remove, schema-driven launch |
| 7.1 | `specs/phase-07-06-runs-list-and-history.md` | Web Revamp — Runs List & History | Active vs history, filters, live status, quick actions |
| 7.1 | `specs/phase-07-07-run-detail-graph.md` | Web Revamp — Run Detail: Graph & Orchestration | React Flow graph, node-status fold, timeline, telemetry |
| 7.1 | `specs/phase-07-08-node-inspection-conversation-hitl.md` | Web Revamp — Node Inspection, Kiro Conversation & HITL | Per-node transcript, all 3 HITL modes from durable state |
| 7.1 | `specs/phase-07-09-documents-and-preview.md` | Web Revamp — Documents & Artifact Preview | Documents drawer + rendered preview (md/json/mermaid/csv/text) |
| 7.1 | `specs/phase-07-10-testing-ci-rollout.md` | Web Revamp — Testing, CI & Rollout | Test pyramid, contract fixtures, CI, cutover from interim web |
| 8 | `specs/phase-08-skill-migration-program.md` | Skill → Workflow Migration Program | Methodology + backlog to migrate 45 skills |

**Build order per Q13:** Phases 1–6 constitute the "complete application + ERD workflow" milestone (Studio as interim UI). Phase 7 (custom workbench) follows. Phase 8 is the ongoing migration program.

---

## 3a. Progress logs (implementation detail per phase)

Detailed, evidence-backed records of what was actually built each phase live in
`progress/`. The specs in `specs/` are the plan; these are the as-built record.

| Phase | Progress log | Status |
|---|---|---|
| 1 | [`progress/phase-01-implementation.md`](progress/phase-01-implementation.md) | ✅ Complete (M1) — repos/tags, modules, evidence, decisions |
| 2 | [`progress/phase-02-implementation.md`](progress/phase-02-implementation.md) | ✅ Complete (M2) — contract, library, scaffolder, reliability lint (CI-proven) |
| 3 | [`progress/phase-03-implementation.md`](progress/phase-03-implementation.md) | ✅ Complete (M3) — GitLab pull, install, lockfile, loader + compat gate |
| 4 | [`progress/phase-04-implementation.md`](progress/phase-04-implementation.md) | ✅ Complete (M4) — SecretProvider, MCP cards, env registry, health, retention, ConfigService |
| 5 | [`progress/phase-05-implementation.md`](progress/phase-05-implementation.md) | ✅ Complete (M5) — subprocess worker, run store, RunManager (3 HITL modes), FastAPI + SSE, Studio doc |
| 6 | [`progress/phase-06-implementation.md`](progress/phase-06-implementation.md) | ✅ Complete (M6) — erd-generation reference workflow (2 trios, approval gate, cli node) |
| 7 | [`progress/phase-07-implementation.md`](progress/phase-07-implementation.md) | ✅ Complete (M7) — React+TS web workbench (6 surfaces, 3 HITL modes, SSE); `genesis serve` |

---

## 4. Component reuse from solutions-copilot

| Genesis needs | Reuse (reimplemented in Genesis) | Source doc/module |
|---|---|---|
| Catalog/registry | Manifest → Catalog projection + lockfile | manifest.ts, registry.ts, lockfile.ts |
| MCP wiring | Template → generated config, `${VAR}` substitution, owner/env-key classification | mcpConfig.ts, secretFields.ts |
| Secrets | SecretProvider (plaintext→keychain), `scope/VAR` vault keys | secretProvider.ts |
| Env registry | Credential-free `environments.json`, label resolution | registry.ts, steering.ts |
| GitLab pull | REST v4 client, tag-based update detection | gitlab.ts, planner.ts |
| Handoff | `.kiro/analysis/*.md` loss-free docs → Genesis blackboard | doc 11 §7 |
| Workflow specs | The 45 skills (SKILL.md + references, ~35,900 lines) | solutions-copilot `.kiro/skills/**` |

---

## 5. Open items to validate early

1. **LCP MCP as the "Appian authoring" unlock** — solutions-copilot's stated blocker was "no reliable agent path to author Appian objects." Validate that the `lcp-mcp-server` can create record types/interfaces/process models/sites within a workflow (Phase 6/8 dependency for write-path workflows).
2. **ACP + `KIRO_API_KEY`** — confirm whether ACP honors API-key auth for headless/CI contexts (default is local interactive login).
3. **Cost/latency of many one-shot ACP sessions** — measure; add a session-pool later if needed.
4. **HITL when actor is a sub-agent** — LangGraph `interrupt()` gates at the graph level, sidestepping solutions-copilot's open question.

---

## 6. Status log

- **2026-07-07** — Design locked through Q1–Q14; name = Genesis; specs authored. Implementation pending.
- Prior art: `kiro-agent-sdk` built + validated (ERD workflow ran end-to-end: 37 tables, 174 relationships). See `project-tracker/kiro-agent-sdk/tracker.md`.
- **2026-07-08** — Review feedback applied: in-process → **subprocess-worker execution** (ADR-012 revised) + **genesis-core semver major-compat gate** (ADR-019 revised).
- **2026-07-08** — **Phase 1 de-risking spike PASSED** (25/25 assertions). Validated on **langgraph 1.2.8 / Python 3.13.3**: per-superstep SQLite checkpoints; `interrupt()`+resume; `update_state` edit; fork; async node; subprocess worker kill→resume (no re-exec) + `sys.exit`/hang isolation; compat-gate. Two findings recorded → **ADR-024** (async-first engine: `AsyncSqliteSaver`+`aiosqlite`; Python 3.13 pin) and **ADR-025** (fork = seed a new thread). See `reference/spike-findings.md`.
- **2026-07-08** — **Phase 1 core BUILT + tests green** (M1). Scaffolded `genesis-core` and `genesis` repos at `repo-gitlab/ramaswamy.u/` (git-initialized, committed locally). Implemented: `genesis_core` (state+reducers, RunWorkspace/Doc, PlatformContext, compat gate, node factories `program/kiro/cli/validator/gate/subgraph`, `attach_reliability` trio, batteries-included `validators` toolkit, MCP+CLI registries) and `genesis` platform (settings with state+artifacts roots, async `AsyncSqliteSaver` checkpointer, engine compile/run/resume, context builder, testing harness). **20 tests pass** (15 core units + 5 platform smoke), **ruff clean**. Acceptance verified: smoke workflow completes; reliability trio retries `retry_max` then escalates; per-node + `_run` telemetry captured; MCP fail-fast on unresolved `${VAR}`; per-node MCP injection; no bulk in state; durable resume from checkpoint (true kill/resume proven in the spike).
- **2026-07-08** — **Repos pushed to GitLab + distribution wired.** `kiro-agent-sdk` tagged **v0.0.1**, `genesis-core` **v0.1.0**, `genesis` **v0.1.0**. Git-pinned dependencies (option A): `genesis → genesis-core → kiro-agent-sdk`, all `git+ssh` by tag with `allow-direct-references`. Verified in clean venvs that `pip install genesis@v0.1.0` resolves the entire tree — **the SDK is pulled transitively; no separate download**. `genesis-workflows` remote exists but is empty (Phase 2).
- 📄 **Full detail:** [`progress/phase-01-implementation.md`](progress/phase-01-implementation.md) — repos/tags, module inventory, evidence table, implementation decisions, deviations, deferred items, dev run instructions.
- **2026-07-09** — CI fixed: `git+ssh` deps couldn't clone in runners; each `.gitlab-ci.yml` now rewrites to HTTPS via `GITLAB_PUSH_TOKEN` (matches solutions-atlas-kb). All three pipelines green (genesis-workflows `library-validate` runs the reliability-lint gate + fixture proof in real CI).
- **2026-07-09** — **Phase 3 COMPLETE + pushed** (M3 — Distribution works). Added `genesis/dist/`: GitLab REST client, catalog (filter + bundle expand + cross-role selection + prereqs), lockfile (+ update detection), installer (resolve/install/update/remove), and the loader with the **genesis-core major-compat gate** (ADR-019 — refuses load on major skew). Proven end-to-end: install `hello` from a fake GitLab → load → run to completion. **24 platform tests green**, ruff clean. Tags: genesis **v0.3.0**, genesis-workflows **v0.1.1**. 📄 Detail: [`progress/phase-03-implementation.md`](progress/phase-03-implementation.md). **Next: Phase 4** (configuration & secrets).
- **2026-07-09** — **Phase 4 COMPLETE + pushed** (M4 — Config & secrets). Added `genesis/config/`: `SecretProvider`/`PlaintextProvider` (0600, `scope/VAR`, server→global resolve, collisions), MCP-registry-derived config cards + `missing_secrets`, credential-free `EnvironmentRegistry` (rejects credential-looking fields; requires url+api_endpoint), artifacts **retention** (keep-last-N / max-age over terminal runs) + Settings, **health checks** incl. the stubbable **MCP literal-env probe**, and the `ConfigService` facade. genesis-core `McpRegistry` `${VAR}` resolution is now **server-scoped** (additive, backward-compatible — MAJOR stays 1) with **fail-fast before Kiro spawns**; `build_context` default-wires the providers. **26 platform + 15 core + 2 workflow tests green**, ruff clean, library validation passing. Tags: genesis-core **v0.3.0**, genesis **v0.4.0**, genesis-workflows **v0.1.2**. 📄 Detail: [`progress/phase-04-implementation.md`](progress/phase-04-implementation.md). **Next: Phase 5** (run orchestration & HITL).
- **2026-07-09** — **Phase 5 COMPLETE + pushed** (M5 — Supervised runs). Added `genesis/runs/` (RunStore + lifecycle, EventBus, input/edit validation, **subprocess worker** per ADR-012, supervisor spawn/kill/death-detection, **RunManager** facade) and `genesis/api/` (FastAPI backend embedding LangGraph + SSE stream + Studio debug graph). **All three HITL modes** implemented and tested: designed gates (approve/reject/feedback), pause/resume (durable across a fresh manager = app restart), and state injection (edit + fork on a new thread, ADR-025). **Worker isolation** proven (a crashing workflow fails only its run; app survives; resumable). **40 platform tests green** (10 run + 4 API via real subprocess workers on program-only workflows), ruff clean. Tag: genesis **v0.5.0** (core/workflows unchanged). ⚠️ The "demonstrable in Studio" criterion is a GUI step — wiring + runbook delivered (`langgraph.json`, `studio.py`, `docs/debug-in-studio.md`); not runnable in this headless env. In-flight ACP `session/cancel` deferred to the SDK. 📄 Detail: [`progress/phase-05-implementation.md`](progress/phase-05-implementation.md). **Next: Phase 6** (ERD reference workflow).
- **2026-07-09** — **Phase 6 COMPLETE + pushed** (M6 — Reference workflow). Built **`erd-generation`** in genesis-workflows: the canonical reference workflow porting the validated ERD pipeline onto Genesis primitives — `preflight`→`fetch_schema`(agent, appian-atlas, verbatim-dump)→`normalize`(program)→`assign_domains`(agent, decisions-to-file)→**approve-domains** gate (feedback re-runs assign)→`assemble`→`run_erdgen`(cli, dry-run branch)→`report`, with **two reliability trios** (custom cross-artifact validators: table coverage, domain-in-set, PK-first, audit exclusion) sharing an `escalate` gate. Ported pure fns are unit-tested; stubbed-graph tests prove gate-resume + forced-failure escalation. **9 workflow tests green**, library validation passing (2 workflows), steering points to it as the template. Tag: genesis-workflows **v0.2.0**. ⚠️ Live dry-run parity (~37 tables/174 rels) needs real Atlas+Kiro+Lucid creds (opt-in; stubbed pipeline proven). 📄 Detail: [`progress/phase-06-implementation.md`](progress/phase-06-implementation.md). **Next: Phase 7** (custom web workbench).
- **2026-07-09** — **Phase 7 COMPLETE + pushed** (M7 — Product UI). Built the **Genesis web workbench**: a **React + TypeScript** SPA (Vite) served by the FastAPI backend, replacing Studio for day-to-day use. Six surfaces (Overview, Catalog w/ role filter + prereq badges, Config, Run launch w/ schema-driven form, Run Detail, History) with **all three HITL modes** in the UI (gate approve/reject/feedback, pause/resume/cancel, edit-state + fork), live **SSE** step timeline + activity + telemetry + artifacts. Backend gained static SPA serving + config CRUD + `/home`/`/workflows/{id}` aggregates; one-command launch via **`genesis serve`** (uvicorn). **Live launch verified** (index + JS bundle + /home/ /catalog served). **43 platform + 5 frontend tests green**; both CI jobs green (added a node:20 `frontend` job: typecheck+vitest+build). Tag: genesis **v0.6.0**. ⚠️ Deviation (approved): spec said Preact; user chose **React+TS** for enterprise-grade future-proofing (backend unchanged — still local single-user). ⚠️ Visual/UX QA is a manual browser step; Catalog install/remove endpoints are a small follow-up. 📄 Detail: [`progress/phase-07-implementation.md`](progress/phase-07-implementation.md). **Next: Phase 8** (skill migration program).
- **2026-07-10** — **Web-revamp designs updated from a first-hand Overcut study.** Analyzed 19 screenshots of the Overcut app and authored **`specs/phase-07-03a-visual-language-reference.md`** (the visual north star): Genesis adopts Overcut’s vocabulary (near-black surface, **metric cards** w/ oversized numerals + date-range/group-by/auto-refresh, **master-detail** config, **category-chip card** catalogs, **node-card** canvases, status pills/dots, tool chips, grouped sidebar) and **innovates on top** (live run graph as hero, **per-node Kiro conversation** inspector, first-class HITL, doc preview drawer). Revised **07-01** (shell/nav grouping + Genesis nouns, metric-card Overview), **07-03** (tokens → observed palette + new components: MetricCard/SegmentedControl/DateRange/FilterChip/CategoryChips/ToolChipRow/NodeCard/TrendChart), **07-04** (master-detail config), **07-05** (category chips + workflow sub-tabs), **07-06** (Executions-table parity), **07-07** (NodeCard aesthetic + per-run dashboard tab). ADR-027 addendum recorded. Genesis stays local single-user.
- **2026-07-10** — **M7.1 · phase-07-02 (Backend Data Plane) COMPLETE + released.** Implemented the critical-path data plane for the web revamp — durable-first and fully additive. **Persistent event log** (`run_events` table + `EventLog`): every event is durably logged + fanned out, so a run’s timeline/conversation survives a reload/restart. **Gate-from-checkpoint** fixes the approval bug at the root: `hitl_gate` emits a full GateDescriptor, `RunManager.pending_gate()` derives it from the durable log (fast) or the checkpoint’s pending interrupt (cold), and `GET /runs/{id}` now returns `gate` — controls no longer depend on a transient event (regression test: gate reachable from a fresh RunManager = simulated server restart). **Live Kiro conversation**: SDK `collect_streaming`, `kiro_node` forwards ACP messages as canonical `agent.*` events (graceful fallback), trio emits `validator.result`/`retry.scheduled`. New APIs: `/workflows/{id}/graph` (topology), `/runs/{id}/events` + `/events/stream` (durable replay+live, dedupe by seq), `/runs/{id}/steps`, artifact `content`/`download` + media/preview kinds, `respond` gate-option validation. ERD `workflow.yaml` gained a `graph:` section (parity lint exempts yaml-only keys). Tests: sdk 41 · core 17 · genesis 48 (incl. 5 data-plane) · workflows validation green; ruff clean. Released in order: kiro-agent-sdk **v0.1.0** → genesis-core **v0.4.0** → genesis **v0.7.0** → genesis-workflows **v0.3.0** (pins bumped, stale workflow pins cleared); all CI green. 📄 [`progress/phase-07-02-implementation.md`](progress/phase-07-02-implementation.md). **Next: 07-03 design system + screen specs.**
- **2026-07-10** — **Web Revamp program specced (M7.1 — sub-series of Phase 7).** After live use surfaced that the interim workbench under-exposes the platform (HITL gate approval unreachable after reload/restart; Kiro conversation discarded; no workflow graph, node inspection, or document preview), scoped a full **enterprise-grade web-app revamp** as a spec-first program. Authored **10 detailed implementation specs** in `specs/phase-07-0N-*`: (01) program overview & frontend architecture, (02) backend/core data-plane — persistent event log, gate-from-checkpoint (root-cause fix for the approval bug), ACP **conversation streaming** across kiro-agent-sdk/genesis-core/worker, topology/steps/artifact-content/status APIs, (03) design system (Tailwind + shadcn/ui), (04) settings, (05) catalog & install, (06) runs list, (07) run-detail **graph visualization** (React Flow), (08) node inspection + **Kiro conversation** + **all 3 HITL modes** from durable state, (09) documents & preview, (10) testing/CI/rollout. Stack recorded as **ADR-027** (Vite/React/TS + React Router + TanStack Query + Zustand + Tailwind/shadcn + React Flow + rhf/zod + Vitest/RTL/MSW/Playwright). Full rebuild of `genesis/web/`; backend changes additive (data plane spans genesis v0.7.0 / genesis-core v0.4.0 / kiro-agent-sdk v0.1.0 / genesis-workflows v0.3.0). ⚠️ Deviation approved: expanded frontend dep surface + cross-repo data-plane work (user authorized touching any repo). **Next: implement 07-02 + 07-03 (critical path), then screen specs.**
- **2026-07-09** — **Post-M7 live bring-up + hardening** (first real end-to-end runs via the workbench). Added the missing distribution loop: **`genesis install` / `genesis list`** CLI (GitLab pull via the stored token, or `--from <local checkout>`) + a `LocalSource` — populates `~/.genesis/library` so the Catalog is non-empty. Ran **hello-appian green end-to-end** (real Kiro: 1 turn, validator passed, `result.json` written). Then drove **erd-generation** to first success, fixing a chain of real bugs found only by running live:
    1. **`kiro_node` passed an unsupported `tools=` kwarg** to `KiroAgentOptions` → mapped to the SDK's `trust_tools`/`trust_all_tools`; added a regression test using the **real** options dataclass (core **v0.3.1**).
    2. **SSE reconnect-replay loop** (the "13× repeated activity"): terminal runs closed the bus → `EventSource` auto-reconnected and re-replayed history forever. Fixed server-side (keep the bus open until terminal; don't mislabel a paused worker as failed) + client-side (dedupe replays; close `EventSource` on terminal) (**v0.6.2**).
    3. **Error diagnostics clobbering** — a generic `worker_exit` overwrote the real error; now the specific error (with exception type + timeout hint) surfaces in the UI (**v0.6.3**).
    4. **Placeholder MCP images** in the library registry (`<atlas-image>` …) → replaced with the real internal images (atlas/jarvis/datagen/jira); configurable `startup_timeout` (default 120s) for heavy MCP servers (genesis-workflows **v0.2.1**, core **v0.3.2**).
    5. **THE root cause — ACP MCP `env` shape:** `McpRegistry.acp_servers()` emitted `env` as a **dict**, but ACP/kiro-cli expects a **list of `{name,value}`** (per the SDK's `load_mcp_servers`). So kiro-cli silently dropped the env → the Atlas container ran **without `GITLAB_TOKEN`** and hung to the session timeout. Fixed to the list shape; corrected the smoke/config/core tests that had asserted the wrong dict shape (the stub that hid the bug). Verified live: ERD now gets past MCP init into the real (slow) Atlas schema fetch instead of failing at ~120s (core **v0.3.3**, genesis **v0.6.4**). Latest tags: genesis-core **v0.3.3**, genesis **v0.6.4**, genesis-workflows **v0.2.1**. Remaining follow-ups: Catalog install/remove buttons in the UI; a browser UX pass; full ERD dry-run parity (~37 tables/174 rels) once the two agent turns complete.
