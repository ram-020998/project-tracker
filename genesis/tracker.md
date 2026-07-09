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
| **Status** | 🟢 Phases 1–3 COMPLETE (M1–M3) — engine, contract+library+lint, distribution (install/lockfile/loader+compat gate). 24 platform tests green; CI green. Next: Phase 4. |
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
