# Genesis — Production-Readiness Architecture Review

- **Date:** 2026-08-18
- **Reviewer role:** Principal software architect / senior code reviewer (comprehensive production-readiness review)
- **Versions reviewed:** genesis **v0.48.7** · genesis-core **v0.9.3** · kiro-agent-sdk **v0.7.0** · genesis-workflows **v0.9.5** · genesis-appian-parser **v0.2.0**
- **Objective:** Determine whether Genesis has a strong, standard, extensible, maintainable, testable, and production-ready foundation for an AI-native SDLC orchestration platform that will evolve significantly over time — i.e. *"if this project grows 10x in features, agents, users, integrations, and workflows, will the current architecture continue to work?"*

## Scope note & method

Verified against real code (not the bible's self-description): backend module sizes (`genesis` 15.7k LOC, `genesis-core` 1.9k, sdk 1.3k, `genesis-workflows` 5.8k, web 18.7k TS), the DI/wiring in `api/app.py`, the agent factory `genesis-core/nodes/agent.py`, a representative workflow (`design-doc/graph.py`), the domain stores (`kb/features.py`, `kb/store.py`), and targeted smell-greps. I did **not** deep-audit every web feature folder or run the suites; where inferring, it is called out.

One framing correction up front, because it determines how to read everything below: **Genesis today is two things at very different maturity levels.**

1. A **workflow execution engine** (LangGraph + node factories + reliability trio + subprocess workers + SQLite event log + MCP registry) that is genuinely strong, standard-aligned, and production-grade *for its stated scope*.
2. An **SDLC domain platform** (Feature → Story → Stage → Artifact lifecycle) that the review prompt assumes exists — but which is **~20% built**: there is a `Feature` + a single `Spec`, placeholder Design/Breakdown, and **zero `Story` concept anywhere** (`grep story` = 0 hits in backend). The review's hardest questions (parallel story execution, stage state machines, artifact lifecycle) are about a domain layer that hasn't been built yet.

That gap — not the engine — is the real finding.

---

## A. Executive Summary

| Dimension | Rating | One-line justification |
|---|---|---|
| **Architecture** | **7.5/10** | Excellent engine layering + explicit DI; the SDLC domain layer is thin and a few god modules exist. |
| **Code quality** | **8/10** | Zero `Any`, zero un-annotated broad excepts, docstrings-as-design-memory, strong tests; dragged down by god modules + `print()` logging. |
| **Extensibility** | **6/10** | New workflow/tool/MCP = clean & data-driven. New SDLC stage/story/artifact/LLM-provider/doc-provider = real surgery. |
| **Testability** | **8.5/10** | `set_collect_impl` ACP seam, DB-backed repos, MSW, ~900 tests total. LLM path is single-provider-coupled. |
| **Security** | **8/10** | Thoughtful agentic least-privilege (per-node MCP injection, `node.tools ∩ server.allowlist`, `fs_write_root` sandbox, ask/deny permission bridge). Prompt-injection content defense + authz are the gaps (authz by-design absent). |
| **Production readiness** | **6.5/10** | Solid for local single-user; observability, concurrency hardening, and the domain model block a 10x/multi-user future. |

### The 5 most important findings

1. **The SDLC domain model is largely unbuilt and what exists is weakly typed.** `FeatureStore` returns raw `dict`s, statuses are bare strings validated only by *set membership* (`VALID_SPEC_STATUSES`), `set_status()` permits **any→any** transition (no transition matrix, no single authoritative state machine), and there is **no `Story`, `Stage`, or `Artifact` entity**. A 10x SDLC platform cannot grow on this. (Evidence: `kb/features.py` lines 41, 158–168; `grep story` = 0.)

2. **Two different "stage" axes are conflated.** Workflow stages (LangGraph nodes — strong) are being asked to stand in for SDLC lifecycle stages (Feature/Story artifacts — absent). The feature "pipeline" (ADR-044) is placeholder cards. Parallel story execution — an explicit product goal — has no domain, persistence, or concurrency model behind it yet.

3. **Ops-layer observability is thin.** 4 `getLogger` uses and **22 `print()`** calls across the backend; no correlation/request IDs, no structured logging, no tracing. Domain observability (the `run_events` log, credits provenance, `copilot_actions` audit) is genuinely strong — but "why did this run behave this way" outside a run is hard to answer.

4. **God modules concentrate risk.** `kb/store.py` **1,373 LOC**, `api/app.py` **841**, `chat/manager.py` **716** (with `if mode == "copilot"/"feature_spec"` branching in ~7 spots). These are the modules most touched by every new feature and the hardest to test in isolation.

5. **Concurrency hardening is incomplete for multi-actor use.** FastAPI runs sync route handlers in a threadpool; only `secrets.json` writes were made atomic (bible §7 admits the other JSON stores share the old non-atomic pattern). There's no optimistic locking / row versioning on KB/feature mutations — fine for one user, unsafe once stories run in parallel.

**What is genuinely good and should be protected:** the node-factory composition model (`kiro_node`/`program_node`/`validator_node`/`hitl_gate`/`attach_reliability` are all functions returning `Node`, not an inheritance tree), the reliability trio as a CI-enforced invariant, the ACP test seam, per-node MCP injection with allowlist intersection, the durable event log as source-of-truth, and the disciplined typing/lint floor. Do not "refactor" these.

---

## B. Architecture Diagram (as actually implemented)

```
Browser (React+TS SPA, TanStack Query + Zustand + React Router)
      │  fetch → client.ts (prepends /api, throws ApiError)
      ▼
FastAPI app  (api/app.py :: create_app — deps built once, passed explicitly)
   ├── register_*_routes(api, deps)   features/chat/documents/applications/native_*/schedules/system
   ├── app.state.{run_manager, chat, kb_store, schedule_store, scheduler, supervisor, skills}
      │
      ├──────────────► RunManager ──► subprocess Worker (importlib graph.py)
      │                    │                 │  ADR-012 isolation: app never imports workflow py
      │                    │                 ▼
      │                    │           LangGraph graph (program/kiro/validator/gate/reliability nodes)
      │                    │                 │  AsyncSqliteSaver checkpoints
      │                    ▼                 ▼
      │              EventLog (run_events, durable)  ◄── the source of truth; EventBus = live SSE
      │
      ├──────────────► ChatManager (IN-PROCESS ACP client; read_only|copilot|feature_spec)
      │                    └─ ChatRunSupervisor (observes gates/terminal → nudges)
      │
      ├──────────────► ConfigService (MCP/CLI registries, secrets, environments, health)
      │
      └──────────────► Domain stores over ONE genesis.db (WAL):
                          KbStore (kb_*), DocumentStore, FeatureStore, ChatStore, RunStore
                                    │
   Agent turns ─────────────────────┴──► kiro-agent-sdk (ACP) ──► Kiro CLI (the ONLY LLM provider)
   Integrations (each a subprocess/HTTP adapter module):
        Dev/DevOps MCP (native installer), gws CLI (Google Workspace), Appian Deployment REST
                                    │
                                    ▼
                          External: Appian env, Google Drive, GitLab
```

Layer directions are respected (`sdk ← core ← genesis`; app never imports workflow Python). The **missing box** is a **Domain/Application layer between the API and the stores** — today route closures call stores and `RunManager` directly, so "SDLC lifecycle logic" has nowhere to live except in route handlers and per-workflow graph code.

---

## C. Architecture Findings (significant)

### C-1 · No SDLC domain layer; entities are dicts + string statuses
- **Severity:** High · **Category:** Domain modeling / extensibility · **Location:** `kb/features.py`, `kb/store.py`, `api/features.py`
- **Current design:** Stores return `dict`; `Spec.status` is TEXT; `set_status` validates membership only; no `Story`/`Stage`/`Artifact` types; feature "pipeline" is placeholder (ADR-044).
- **Problem:** Every consumer re-interprets untyped dicts; lifecycle rules have no home; adding a stage means touching stores + API + web strings in lockstep.
- **Why it matters:** This is the substrate the whole product is meant to grow on. It is the single biggest lever on the "10x" question.
- **Recommended design:** Introduce a small typed domain (`dataclass`/Pydantic) `Feature`, `Story`, `Stage`, `Artifact`, `ArtifactVersion` + `Enum` states, and **one** `LifecycleService` that owns transitions (a declarative transition table). Keep stores as thin persistence; map rows↔entities at that boundary. This is *not* over-engineering — it replaces scattered strings, it doesn't add layers you won't use.
- **Migration:** Additive — introduce entities + `LifecycleService` alongside `FeatureStore`; route handlers call the service; DB schema is already migration-driven so states can become a lookup/enum without churn.

### C-2 · `set_status` is not a state machine
- **Severity:** High · **Category:** State management · **Location:** `kb/features.py:158`
- **Current design:** any status in the 4-tuple is accepted from any current status.
- **Problem:** impossible/illegal transitions (`completed → draft`) are allowed; transition logic will get duplicated across API + web + future workflows.
- **Recommended design:** a single authoritative transition map (see §8 matrix) enforced in `LifecycleService.transition(entity, action)`; emit a domain event on each transition (feeds observability + the future activity feed).

### C-3 · God modules
- **Severity:** Medium–High · **Location:** `kb/store.py` (1,373), `api/app.py` (841), `chat/manager.py` (716)
- **Problem:** high fan-in, hard to unit-test in isolation, merge-contention magnets. `KbStore` is a single class owning app lifecycle + SCD-2 temporal merge + bundles + releases + 7 read-projections.
- **Recommended:** split `KbStore` along seams already visible in the code (`SyncWriter` [baseline/delta/apply], `KbQuery` [reads/projections], `ReleaseStore`). Move `api/app.py` run/artifact routes into `register_run_routes(...)` like the other domains already do (the modular pattern exists — apply it to the core routes too).

### C-4 · Chat mode branching is a latent strategy/polymorphism smell
- **Severity:** Medium · **Location:** `chat/manager.py` (`if self.mode == "copilot" … elif "feature_spec"` at lines 159/167/196/200/310/312/577)
- **Current design:** one `ChatSession` class branches on a string mode for cwd, trust set, MCP wiring, permission behavior.
- **Why it matters:** every new chat mode (e.g. a future "design" or "review" authoring mode) adds another branch in multiple methods.
- **Recommended:** a `ChatModeProfile` (cwd, trust_tools, mcp_servers, fs_write_root, permission_mode) resolved once per session — composition over conditionals. Bounded today (3 modes), so **Medium**, not urgent.

### C-5 · Missing Application/Service layer → logic in route closures
- **Severity:** Medium · **Location:** `api/*.py register_*_routes`
- **Current design:** handlers orchestrate stores + `RunManager` directly (e.g. `applications.py` add→baseline-sync).
- **Recommended:** thin services for multi-store operations so the same logic is reachable from the scheduler, chat copilot, and API without duplication. (`sync_jobs.py` already re-implements app-sync orchestration the API also does — that duplication is the tell.)

---

## D. Critical Findings (address immediately)

For the **stated scope (local, single-user)** there are **no "stop-ship" criticals** — the app works, secrets are 0600+atomic, the agent is sandboxed, runs are durable. The items I'd label critical are all **conditional on the near-term roadmap**:

- **D-1 (critical *if* parallel stories / multi-actor land):** no optimistic locking / row-versioning on KB + feature mutations, and non-atomic JSON stores beyond `secrets.json`. Concurrent writers can interleave/corrupt. Must be fixed *before* concurrency features, not after.
- **D-2 (critical for any shared/hosted future):** there is **no authentication/authorization** (ADR-026 makes this deliberate for local use). The moment Genesis is exposed beyond localhost, this is a hard blocker. Keep ADR-026 honest: add an explicit "localhost-bind + no-auth" guard so it can't be accidentally served on 0.0.0.0 without a conscious decision.

---

## E. High-Priority Findings (before significant further development)

- **E-1** Build the typed SDLC domain + `LifecycleService` (C-1/C-2) **before** adding Design/Breakdown/Story — otherwise the placeholder pattern metastasizes.
- **E-2** Introduce structured logging (`structlog` or stdlib `logging` + JSON) with a **run_id/session_id correlation field**; replace the 22 `print()`s. Reuse the existing IDs you already have (run_id, chat session_id, tool_call_id) as correlation keys — cheap, high payoff.
- **E-3** Abstract the **LLM/agent provider** behind the existing `set_collect_impl` seam into a named `AgentProvider` interface. Right now Kiro-CLI-over-ACP is the *only* provider and its assumptions (skills-from-filesystem, `_kiro.dev/*` extensions) leak into `chat/` and `nodes/agent.py`. You don't need a second provider today, but the seam should be a first-class interface so adding one isn't a cross-cutting edit.
- **E-4** Split the three god modules (C-3) along the seams already implied by their own section comments.
- **E-5** Harden the remaining JSON stores to the atomic temp+`os.replace`+lock pattern already used for secrets (bible §7 flags this as known-deferred).

---

## F. Extensibility Assessment (the core question)

| Change | Effort today | Why |
|---|---|---|
| **New workflow** | **Easy** | Drop a `graph.py` + `workflow.yaml` in `genesis-workflows`, `genesis install`. Data-driven, CI-gated. ✅ |
| **New tool / MCP server** | **Easy** | Curated registry entry (MR) or custom tier; per-node `tools=` allowlist. ✅ |
| **New agent step in a workflow** | **Easy–Medium** | `kiro_node(...)` + validator + reliability, wired in `build()`. Idiomatic but *hand-wired per workflow* (design-doc wires 11 node/validator pairs by hand, ~880 LOC) — a `reliable_agent_step()` helper would cut the repetition. |
| **New LLM provider (Kiro → Anthropic/OpenAI)** | **Hard** | Single provider; ACP/Kiro assumptions leak into core + chat. Needs E-3 first. |
| **New document provider (Drive → SharePoint)** | **Medium** | `gws` is reasonably isolated (`integrations/gws/`, `DocumentSyncEngine` via `ctx.extras`), but there's no `DocumentProvider` interface — you'd add a sibling adapter and a branch. Better than average, not clean. |
| **New application type (Appian → Salesforce)** | **Very Hard** | The KB, parser, Dev/DevOps MCP, and sync workflow are Appian-specific end-to-end. This is a platform-defining assumption, not an adapter. Expect a new parser + KB schema + MCP set. |
| **New SDLC stage (e.g. Security Review)** | **Hard** | No stage abstraction — you'd add strings across `FeatureStore`, `api/features.py`, and web, plus placeholder UI. This is exactly what C-1/C-2 fix. |
| **Parallel story execution** | **Very Hard today** | No `Story` entity, no per-story workflow-run linkage, no concurrency/locking model. Requires the domain build-out + D-1. |

**Architectural decisions that currently limit extensibility:** (1) untyped dict domain + string statuses; (2) single hard-wired LLM provider; (3) Appian-specific KB/parser assumed throughout; (4) no domain/service layer to absorb lifecycle logic; (5) chat behavior keyed on a string mode.

---

## G. Framework Assessment

| Framework/Library | Purpose | Standard? | Verdict |
|---|---|---|---|
| **LangGraph** | Orchestration/checkpointing | ✅ | **Keep.** Used idiomatically (graphs, AsyncSqliteSaver, `interrupt()` gates). Not wrapped in needless custom abstraction. |
| **FastAPI + Pydantic** | API + validation | ✅ | **Keep.** Modular `register_*_routes` + explicit deps is good. |
| **SQLite (+ own migration runner)** | Persistence | ✅ (ADR-030) | **Keep** for now. The hand-rolled forward-only migration runner is a *justified* small custom piece (no Alembic dependency for a single-file local DB). Revisit only on the ADR-030 triggers (multi-user/pgvector). |
| **Repository pattern (Stores)** | Data access | ✅ | **Keep but split** (C-3). The abstraction is justified (schema owned in `db/`, DB-agnostic signatures). |
| **React + TanStack Query + Zustand + React Router + Vite** | Frontend | ✅ | **Keep.** Standard, layered client, feature folders. |
| **kiro-agent-sdk (ACP adapter)** | Agent runtime | Custom (justified) | **Keep, but interface it** (E-3). It exists because Kiro speaks ACP; that's real. Make `AgentProvider` explicit. |
| **Reliability trio (validator+retry+escalation)** | AI reliability | Custom | **Keep.** This is the right custom abstraction for deterministic-around-nondeterministic; CI-enforced. |
| **EventBus + EventLog** | Events/observability | Custom | **Keep** (the dual-bus was already simplified to one). Don't add Kafka/Redis — a modular monolith needs neither. |
| **Custom DI (via `app.state` + constructor params)** | Wiring | Lightweight | **Keep.** *Not* a custom DI framework — explicit and testable. Do **not** introduce a DI container. |
| **Logging** | Observability | stdlib/print | **Introduce** standard structured **logging** (E-2) — this is the one place to adopt a library (`structlog`). |

**Introduce:** structured logging (`structlog`); a typed domain layer (stdlib `dataclass`/`Enum` + Pydantic at API edges — no new dependency). **Replace:** nothing wholesale. **Simplify:** the god modules; per-workflow reliability wiring (helper).

---

## H. State Machine Review — proposed authoritative transition matrix

Today `set_status` (kb/features.py) accepts any target status. The single authoritative implementation (in a `LifecycleService`) should encode, for the spec artifact:

| Current | Action | Next | Preconditions |
|---|---|---|---|
| `draft` | start | `in-progress` | spec exists |
| `in-progress` | submit | `in-review` | html artifact present |
| `in-review` | approve | `completed` | reviewer sign-off |
| `in-review` | request-changes | `in-progress` | — |
| `completed` | reopen | `in-progress` | explicit reopen only |

Illegal today and should be rejected: `completed → draft`, `draft → completed`, `in-review → draft`. When Story/Stage entities land, each gets its own table (Story: `design → implementation → code-review → deployment → verification → done`), all enforced in one place.

---

## I. Refactoring Roadmap

**Phase 0 — Guardrails (small, do first)**
- Explicit localhost-bind assertion + a "no-auth is intentional" check (D-2 safety net).
- Harden remaining JSON stores to atomic writes (E-5).
- Structured logging + correlation IDs, replace `print()` (E-2).

**Phase 1 — Domain foundation (the keystone)**
- Typed `Feature/Story/Stage/Artifact/ArtifactVersion` + `Enum` states.
- One `LifecycleService` owning a declarative transition table (C-1/C-2).
- Map rows↔entities at the store boundary; keep stores thin.

**Phase 2 — Extensibility seams**
- `AgentProvider` interface over the `set_collect_impl` seam (E-3).
- `DocumentProvider` interface (Drive as first impl).
- `ChatModeProfile` composition (C-4); `reliable_agent_step()` helper.

**Phase 3 — Reliability & concurrency**
- Optimistic locking / row-version on KB + feature mutations (D-1).
- Per-story WorkflowRun linkage + a concurrency model for parallel stories.
- Split god modules (C-3).

**Phase 4 — Production hardening**
- AuthN/Z *iff* leaving localhost; audit-event stream from lifecycle transitions; metrics endpoint.

**Phase 5 — Optimization**
- Reduce redundant agent turns (deterministic code where an LLM is currently used for parsing/matching); prompt-size/context-duplication pass.

---

## J. Target Architecture (adapted to the actual codebase)

```
Frontend (keep) ──► API/BFF (FastAPI, register_*_routes)
                          │  (thin controllers — no lifecycle logic here)
                          ▼
                 Application/Service Layer   ◄── NEW, small
                 (LifecycleService, SyncService, SpecService)
                          ▼
                 Domain Layer (typed)          ◄── NEW, the keystone
                 Feature · Story · Stage · Artifact · Workflow  (+ Enum states, transition table)
             ┌────────────┼─────────────────────┐
             ▼            ▼                       ▼
      Orchestrator   Agent Layer            Integration Adapters
      (LangGraph –   (AgentProvider iface   (AppianKB · DocumentProvider ·
       keep as-is)    over ACP/Kiro)         DeploymentREST — behind interfaces)
             │            │                       │
             ▼            ▼                       ▼
       Persistence    Tools (per-node MCP,   External systems
       (thin Stores)   allowlist-capped)     (Appian · Drive · GitLab)
```

The engine, tools, MCP model, event log, and reliability trio stay exactly as they are. The additions are a **thin service layer** and a **typed domain layer**, plus two **provider interfaces** — the minimum that turns "an Appian workflow runner" into "an extensible SDLC platform" without adding infrastructure you won't use.

---

## K. Prioritized list of changes to actually implement

**Do now (foundation, high leverage, low regression risk):**
1. Typed SDLC domain + `LifecycleService` with an authoritative transition table (C-1, C-2).
2. Structured logging + correlation IDs; remove `print()` (E-2).
3. Atomic-write hardening for the remaining JSON stores (E-5).
4. Localhost-bind/no-auth guardrail (D-2 safety).

**Do next (before parallel-story / provider work):**
5. `AgentProvider` interface over the ACP seam (E-3).
6. Split `KbStore`, `api/app.py`, `ChatManager` along their existing seams (C-3); `ChatModeProfile` (C-4).
7. Optimistic locking on KB/feature mutations (D-1).

**Optional second phase:**
8. `DocumentProvider` interface; `reliable_agent_step()` helper; per-story WorkflowRun linkage; deterministic-vs-LLM cost pass; metrics/audit-event stream.

**Explicitly do NOT do:** introduce a DI container, an external message broker, microservices, an ORM, or Alembic; replace LangGraph/FastAPI/SQLite; or "clean up" the node-factory/reliability-trio model. These would add complexity without buying the product anything at its scale.

---

## L. Bottom line

**The engine will scale; the domain model will not — yet.** Genesis has an unusually disciplined *execution* foundation (typing, tests, sandboxing, reliability) but the *SDLC domain* the product is meant to become is still mostly strings and placeholders. Build the thin domain/service layer and the two provider interfaces now, while the codebase is small and well-tested, and future stages/agents/providers become additive rather than structural.

**Recommended next step:** write a spec for **#1 (typed domain + `LifecycleService`)** first (per the planning-before-implementation loop), get sign-off on the entity/transition design, then implement behind tests. No code changes until the spec is approved.

---

## Phase 25 outcome (closeout 2026-08-19)

Phase 25 (Architectural Foundation Hardening) remediated this review across two coordinated releases —
**genesis v0.49.0 + genesis-core v0.9.4** (25-01..25-08) and **genesis v0.50.0 + genesis-core v0.9.5**
(25-09, 25-10-core, 25-13) — both CI-green.

**Resolved:** C-1/C-2 (typed SDLC domain + single-authority `LifecycleService`, ADR-050); C-3 (god
modules: `KbStore` 1373→652, `api/app.py` 841→189, `chat/manager.py` mode branching → `ChatModeProfile`);
C-4 (ChatModeProfile); C-5 (`ApplicationSyncService` de-dup); E-2 (structured logging + correlation ids);
E-3 (`AgentProvider`, ADR-051); E-5/D-1-files (atomic JSON writes); D-1/§17 (optimistic locking m0014 +
run-start idempotency); D-2 (localhost-bind guardrail, ADR-026 amended); §F/§19/§20 (`DocumentProvider`,
ADR-052); §22 (metrics + `/runs/{id}/provenance` + lifecycle Activity feed).

**Partially resolved:** §F agent-step ergonomics — `reliable_agent_step()` shipped (genesis-core), workflow
adoption opportunistic; §22 story-level Activity — feature-spec Activity shipped, story activity pending the
backlog 25-11.

**Deferred (backlog / separate track):** 25-11 per-story execution; 25-12 AI cost & performance pass
(data-driven — needs live run telemetry); auth/multi-tenancy, Salesforce, Postgres (ADR-026/030 triggers,
out of scope for local single-user).
