# Phase 25 — Architectural Foundation Hardening (Code-Review Remediation)

- **Status:** 📝 SPECS DRAFTED — awaiting approval to build
- **Created:** 2026-08-18
- **Source:** `code-review/genesis-production-readiness-review-2026-08-18.md` (principal-architect production-readiness review)
- **Applies to (baseline):** genesis **v0.48.7** · genesis-core **v0.9.3** · kiro-agent-sdk **v0.7.0** · genesis-workflows **v0.9.5** · genesis-appian-parser **v0.2.0**
- **Proposed ADRs:** ADR-050 (typed SDLC domain + single-authority LifecycleService), ADR-051 (AgentProvider abstraction over the agent runtime), ADR-052 (external-capability provider interfaces — DocumentProvider). To be formalized in `reference/decision-log.md` on approval.

---

## 0. Why this phase exists

The code review concluded that Genesis is **two systems at very different maturity levels**:

1. A **workflow execution engine** (LangGraph + node factories + reliability trio + subprocess workers + SQLite event log + MCP registry) that is strong, standard-aligned, and production-grade *for its stated scope*.
2. An **SDLC domain platform** (Feature → Story → Stage → Artifact lifecycle) that is **~20% built**: a `Feature` + a single `Spec`, placeholder Design/Breakdown, and **no `Story`/`Stage`/`Artifact` domain concept at all**.

The review's verdict: *"the engine will scale; the domain model will not — yet."* Phase 25 hardens the **foundation** — a typed domain + lifecycle authority, the extensibility seams (agent/document providers), observability, concurrency safety, and the decomposition of the god modules — **before** the product grows Design/Breakdown/Story stages on top of strings and placeholders.

**Guiding constraint (from the review §36 "Do Not Over-Engineer"):** the goal is *the simplest architecture that provides strong boundaries and can scale with the product.* Phase 25 adds exactly two new layers (a thin service layer + a typed domain layer) and two provider interfaces. It introduces **no** DI container, message broker, microservices, ORM, or Alembic, and **does not** touch the node-factory/reliability-trio/event-log model that the review rated as a genuine strength.

### Ratings this phase targets (review §A)

| Dimension | Now | Target after Phase 25 |
|---|---|---|
| Architecture | 7.5 | 9 |
| Code quality | 8 | 9 |
| Extensibility | 6 | 8.5 |
| Testability | 8.5 | 9 |
| Security | 8 | 8.5 |
| Production readiness | 6.5 | 8 |

---

## 1. Scope — the full action-item register

Every action item from the review (§C findings, §D critical, §E high-priority, §F extensibility, §I roadmap, §K prioritized list) is assigned to a sub-phase below. **Nothing from the review is dropped.**

| Sub-phase | Title | Review items | Roadmap phase | Repos |
|---|---|---|---|---|
| **25-01** ✅ BUILT | Typed SDLC Domain Model & Lifecycle State Machine | C-1, C-2, §H | Phase 1 (keystone) | genesis (+ m0013) |
| **25-02** ✅ BUILT | Structured Logging & Correlation IDs | E-2 | Phase 0 | genesis, genesis-core |
| **25-03** ✅ BUILT | Atomic JSON-Store Hardening | E-5, D-1 (files) | Phase 0 | genesis, genesis-core |
| **25-04** | Network-Exposure Guardrail (localhost-bind / no-auth intent) | D-2 | Phase 0 | genesis |
| **25-05** | AgentProvider Interface | E-3 | Phase 2 | genesis-core, genesis |
| **25-06** | God-Module Decomposition & Application/Service Layer | C-3, C-5 | Phase 2/3 | genesis |
| **25-07** | ChatModeProfile — compose chat modes | C-4 | Phase 2 | genesis |
| **25-08** | Concurrency & Optimistic Locking | D-1 | Phase 3 | genesis |
| **25-09** | DocumentProvider Interface | F (doc-provider), §19/§20 | Phase 2 | genesis |
| **25-10** | `reliable_agent_step()` Workflow Helper | §F (agent-step), §28 | Phase 2 | genesis-core, genesis-workflows |
| **25-12** | AI Cost & Performance Pass | §31, §32 | Phase 5 | genesis-workflows, genesis |
| **25-13** | Ops Observability II — Metrics & Lifecycle Audit Stream | §22 (metrics/audit) | Phase 4 | genesis, web |
| **25-14** | Phase Release & Closeout (tag, ship, document) | process / phase DoD | final | all touched + project-tracker |

> **13 active sub-phases** (25-01..25-10, 25-12, 25-13, 25-14). A 14th by original number — **per-story execution & WorkflowRun
> linkage** (former 25-11) — was **moved to backlog** on 2026-08-18 (`specs/backlog/phase-25-11-per-story-execution.md`): it is
> new product capability, not code-review remediation, and is not acceptance-testable until the Breakdown→Stories step +
> per-stage workflows exist. See §1.1. **25-14** is the capstone that tags/releases + documents the whole phase.

**Explicitly out of scope for Phase 25** (recorded so it is a conscious deferral, not an omission):
- **Per-story execution & WorkflowRun linkage (former 25-11) — MOVED TO BACKLOG** (`specs/backlog/phase-25-11-per-story-execution.md`, 2026-08-18). New product capability, not remediation; gated on a Breakdown step that produces Stories + per-stage agent workflows. 25-01 pre-defines the `Story`/`Stage` types so it's a clean future pickup.
- AuthN/Z implementation (review D-2) — only the *guardrail* (25-04) is in-scope; real auth stays deferred until Genesis leaves localhost (re-opens ADR-026, a separate track).
- New application type (Appian → Salesforce) — a platform-defining effort, not remediation.
- Postgres/pgvector migration — remains gated on the ADR-030 triggers.
- The Design / Breakdown artifact *content* and their agent workflows — Phase 25 builds the **domain + seams** they will sit on; authoring those artifacts is later product work.

## 1.1 Completability assessment (as of 2026-08-18)

Assessed against the **actual** current app (Features + a single Spec + *placeholder* Design/Breakdown; **no** Story, no
Breakdown-produces-stories, no per-stage workflows): **12 of the 13 originally-specced sub-phases are completable now**; only
the former 25-11 must wait.

- **Immediately (independent):** 25-02, 25-03, 25-04, 25-05, 25-07, 25-09, 25-10, 25-12 (8).
- **After the keystone 25-01 (all still this cycle):** 25-06, 25-08, 25-13 (3) — plus 25-01 itself.
- **Capstone (after all the above ship):** 25-14 release & closeout.
- **Backlog (blocked on future product work):** 25-11.

"Completable now" = implementable + acceptance-testable against today's app (each still ships its own release per §2).

---

## 2. Sequencing & dependency graph

```
Phase 0 (guardrails, independent, do first, low risk)
  25-02 logging ─┐
  25-03 atomic  ─┼─ parallelizable
  25-04 guardrail┘

Phase 1 (keystone)
  25-01 typed domain + LifecycleService   ◄── unblocks 25-08, 25-11, 25-13

Phase 2 (extensibility seams — after 25-01 for the ones that touch the domain)
  25-05 AgentProvider (independent of 25-01)
  25-06 god-module split + service layer (uses 25-01 entities for the feature/kb services)
  25-07 ChatModeProfile (independent; pairs with 25-06)
  25-09 DocumentProvider (independent)
  25-10 reliable_agent_step helper (independent; genesis-core)

Phase 3 (reliability & concurrency — after 25-01)
  25-08 optimistic locking
  (former 25-11 per-story execution → BACKLOG: needs Breakdown→Stories + per-stage workflows)

Phase 4
  25-13 metrics + lifecycle audit stream  ◄── consumes 25-01 domain events + 25-02 correlation ids
        (Feature/Spec activity now; Story activity when 25-11 leaves backlog)

Phase 5
  25-12 AI cost/perf pass (independent; can slot anytime)

Capstone (after every active sub-phase ships)
  25-14 phase release & closeout  ◄── ADRs→Accepted, cross-repo pin alignment, bible/tracker/progress, review-delta, CI-green sweep
```

**Critical path:** 25-01 → (25-06, 25-08) → 25-13 → 25-14. The Phase-0 guardrails and 25-05/25-09/25-10/25-12 can proceed in parallel with everything; 25-14 is last by definition.

**Release strategy:** each sub-phase ships its own genesis (and, where noted, genesis-core / genesis-workflows) release following the ADR-019 protocol (bump version + tag + push + dependent pins + CI green; frontend-only still ships a genesis release + committed `web/static`). Backend schema changes (25-01 m0013, 25-11 possibly m0014) bump every hardcoded `current_version==N` test alongside the migration (a known lesson, bible §7).

---

## 3. Cross-cutting design principles (apply to every sub-phase)

1. **Additive, not a rewrite.** New layers sit *alongside* the stores; the stores remain the persistence layer. No behavior a user sees changes unless a sub-phase says so.
2. **Typed contracts at boundaries only.** Introduce `dataclass`/`Enum`/Pydantic where the review found weak typing (domain entities, API edges). Do **not** add typing ceremony to internal glue (review §10).
3. **One authority per concern.** Lifecycle transitions live in exactly one place (`LifecycleService`); agent-runtime specifics live behind one interface (`AgentProvider`); each external capability behind one adapter interface.
4. **Preserve the invariants the review praised** — ADR-001 (LangGraph owns control flow), ADR-011 (reliability trio), ADR-012 (subprocess isolation), the durable `run_events` log, per-node MCP injection with `node.tools ∩ server.allowlist`, `fs_write_root` sandbox, secrets-by-key-name.
5. **Tests-with-the-change.** Every sub-phase adds unit tests; the domain/state-machine/provider seams must be unit-testable **without** LLM/DB/network/shell (review §24). Where a stub previously hid a contract, fix the stub (bible §7).
6. **Keep the bible current** — on each sub-phase ship: `bible/01` (versions/tests), `bible/04` (any new ADR), `bible/03` (new modules), `bible/08` (roadmap), tracker §6, a `progress/phase-25-NN-*.md`.

---

## 4. Sub-phase index (detailed specs)

Each is a standalone document under [`phase-25-architectural-foundation-hardening/`](./phase-25-architectural-foundation-hardening/):

- [`25-01-typed-domain-and-lifecycle.md`](./phase-25-architectural-foundation-hardening/25-01-typed-domain-and-lifecycle.md)
- [`25-02-structured-logging-and-correlation-ids.md`](./phase-25-architectural-foundation-hardening/25-02-structured-logging-and-correlation-ids.md)
- [`25-03-atomic-json-store-hardening.md`](./phase-25-architectural-foundation-hardening/25-03-atomic-json-store-hardening.md)
- [`25-04-network-exposure-guardrail.md`](./phase-25-architectural-foundation-hardening/25-04-network-exposure-guardrail.md)
- [`25-05-agent-provider-interface.md`](./phase-25-architectural-foundation-hardening/25-05-agent-provider-interface.md)
- [`25-06-god-module-decomposition-and-service-layer.md`](./phase-25-architectural-foundation-hardening/25-06-god-module-decomposition-and-service-layer.md)
- [`25-07-chat-mode-profile.md`](./phase-25-architectural-foundation-hardening/25-07-chat-mode-profile.md)
- [`25-08-concurrency-and-optimistic-locking.md`](./phase-25-architectural-foundation-hardening/25-08-concurrency-and-optimistic-locking.md)
- [`25-09-document-provider-interface.md`](./phase-25-architectural-foundation-hardening/25-09-document-provider-interface.md)
- [`25-10-reliable-agent-step-helper.md`](./phase-25-architectural-foundation-hardening/25-10-reliable-agent-step-helper.md)
- [`25-12-ai-cost-and-performance-pass.md`](./phase-25-architectural-foundation-hardening/25-12-ai-cost-and-performance-pass.md)
- [`25-13-observability-metrics-and-lifecycle-audit.md`](./phase-25-architectural-foundation-hardening/25-13-observability-metrics-and-lifecycle-audit.md)
- [`25-14-phase-release-and-closeout.md`](./phase-25-architectural-foundation-hardening/25-14-phase-release-and-closeout.md)
- 🅱️ **BACKLOG:** [`specs/backlog/phase-25-11-per-story-execution.md`](../backlog/phase-25-11-per-story-execution.md) (former 25-11)

---

## 5. Proposed ADRs (full text; to be added to `reference/decision-log.md` on approval)

### ADR-050 — Typed SDLC domain model with a single-authority LifecycleService
**Status:** Proposed (2026-08-18). **Context:** the SDLC entities (Feature/Spec, and the not-yet-built Story/Stage/Artifact) are persisted as `dict`s with bare-string statuses; `FeatureStore.set_status` validates set-membership only and permits any→any transitions — there is no authoritative state machine, and lifecycle logic will duplicate across API/web/workflows as stages grow. **Decision:** introduce a typed domain (`dataclass`/`Enum`) for `Feature`, `Story`, `Stage`, `Artifact`, `ArtifactVersion`, and a single `LifecycleService` that owns a **declarative transition table** and is the *only* code allowed to mutate a lifecycle status. Stores stay thin persistence; entities are mapped at the store boundary. Statuses become enums; illegal transitions are rejected with a typed `IllegalTransitionError`; each transition emits a domain event. **Consequences:** adding a stage/state is a table + enum edit, not a cross-cutting string hunt; the web + copilot + scheduler all transition through one path. Additive over the existing schema (a new migration adds no destructive change). Preserves ADR-001 (LangGraph still owns *workflow* control flow; this governs *SDLC entity* lifecycle, a different axis).

### ADR-051 — AgentProvider abstraction over the agent runtime
**Status:** Proposed (2026-08-18). **Context:** Kiro-CLI-over-ACP is the *only* agent/LLM provider, and its assumptions (skills-from-filesystem, `_kiro.dev/*` ACP extensions, `KiroAgentOptions`) leak into `genesis-core/nodes/agent.py` and `genesis/chat/`. Swapping/adding a provider today is a cross-cutting edit. The `set_collect_impl` test seam already proves the call site is interceptable. **Decision:** formalize a named `AgentProvider` interface (Protocol) — `collect`/`collect_streaming`, capability advertisement (models/commands/images), permission-bridge shape — with the Kiro/ACP implementation as the first (and, for now, only) provider. `genesis-core` depends on the Protocol, not on `kiro_agent_sdk` directly (it already lazy-binds). **Consequences:** a second provider becomes an additive adapter, not a refactor; tests inject a fake provider through the same interface. No behavior change; genesis-core `CORE_MAJOR` unchanged (additive). Does **not** mandate building a second provider now.

### ADR-052 — External-capability provider interfaces (DocumentProvider first)
**Status:** Proposed (2026-08-18). **Context:** external integrations are isolated in modules (`integrations/gws/`, `kb/dev_mcp.py`, Deployment REST) but there is no *interface* for a capability class — e.g. document sourcing is `gws`-specific with no `DocumentProvider` seam, so a second source (SharePoint) would be a sibling adapter + branch. **Decision:** define thin capability interfaces where a second implementation is plausibly on the roadmap, starting with `DocumentProvider` (resolve/fetch/export/metadata), with `gws` as the first implementation behind it. Do **not** pre-abstract capabilities with only one conceivable implementation (e.g. the Appian Deployment REST export stays a concrete adapter until a second deploy target exists). **Consequences:** adding a document source is an adapter + a registry entry; business logic depends on the interface, not the CLI. Bounded — one interface now, more only when a second impl is real (avoids review §36 over-abstraction).

---

## 6. Definition of Done (phase-level)

- All 13 sub-phase specs approved; each sub-phase implemented behind tests and shipped per §2.
- ADR-050/051/052 formalized (Accepted) in `reference/decision-log.md` **and** mirrored into `bible/04`.
- Review ratings re-assessed against the §A targets; a closing note in `code-review/` records the delta.
- No regression to the CI gates (ruff/eslint/tsc/pytest/vitest/stale-bundle/reliability-lint/contract-lint).
- Bible + tracker + `progress/phase-25-*.md` current.

---

## 7. Traceability matrix (review item → sub-phase → DoD)

| Review ref | Item | Sub-phase |
|---|---|---|
| C-1 | No SDLC domain layer; dicts + string statuses | 25-01 |
| C-2 | `set_status` is not a state machine | 25-01 |
| C-3 | God modules (`kb/store.py`, `api/app.py`, `chat/manager.py`) | 25-06 (+25-07 for chat) |
| C-4 | Chat mode string-branching | 25-07 |
| C-5 | Missing Application/Service layer | 25-06 |
| D-1 | Optimistic locking + non-atomic JSON stores | 25-08 (DB) + 25-03 (JSON) |
| D-2 | Localhost-bind / no-auth guardrail | 25-04 |
| E-1 | Domain before Design/Breakdown/Story | 25-01 (enabler) |
| E-2 | Structured logging + correlation IDs | 25-02 |
| E-3 | AgentProvider interface | 25-05 |
| E-4 | Split god modules | 25-06 |
| E-5 | Atomic JSON stores | 25-03 |
| F/§F | New agent step ergonomics | 25-10 |
| F | New document provider | 25-09 |
| F | Parallel story execution | 🅱️ backlog — `specs/backlog/phase-25-11-per-story-execution.md` |
| §22 | Ops observability (metrics/audit) | 25-13 |
| §31/§32 | Performance / AI cost | 25-12 |

Every action item in the review maps to exactly one owning sub-phase (some appear in two where the fix spans DB + files).
