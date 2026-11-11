# 10. Architecture decisions

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 section 9

Genesis records every binding design decision as a numbered Architecture Decision Record (ADR). Each record has
a context, the decision, the alternatives that were rejected and the consequences. Later decisions may *amend*
an earlier one (change part of it) or *supersede* it (replace it). The records themselves are kept in the
project's planning repository. This page lists every one in plain words, grouped by topic, with the module
document that explains it in context.

How to read the status column: **Accepted** means in force. **Amended by** lists the records that changed part
of it; read them together. **Superseded** means a later record replaced it.

## 10.1 Foundations

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-001 | The workflow graph, written in code, decides what happens next. Agents never orchestrate. | Accepted | [05](05-solution-strategy.md), [core-engine](modules/core-engine.md) |
| ADR-002 | Agent steps are narrow Kiro turns, driven over ACP by `kiro-agent-sdk`, with MCP servers given per step. | Accepted | [kiro-agent-sdk](modules/kiro-agent-sdk.md) |
| ADR-003 | Genesis is a local web app using the user's own credentials, pulling workflows from a shared GitLab library. | Accepted | [03](03-system-context.md) |
| ADR-008 | One local app holds the engine and the UI; LangGraph Studio was only an interim harness. | Accepted | [api](modules/api.md) |
| ADR-013 | The old solutions-copilot is retired; Genesis has its own configuration UI. | Accepted | [configuration-and-secrets](modules/configuration-and-secrets.md) |
| ADR-015 | Build order: the complete app first, then the workbench, then migrate skills to workflows. | Accepted (historical) | — |
| ADR-016 | Names: `genesis`, `genesis-workflows`, `kiro-agent-sdk`. | Accepted | — |
| ADR-017 | One language, Python, for engine, nodes and workflows. | Accepted | [02](02-constraints.md) |
| ADR-023 | The backend is FastAPI with LangGraph embedded as a library; no LangGraph Server. | Accepted | [api](modules/api.md) |
| ADR-024 | The engine is async, with the async SQLite checkpointer; Python 3.13. | Accepted | [runs-and-workers](modules/runs-and-workers.md) |
| ADR-026 | A local, single-user React app; serving refuses a non-loopback address unless explicitly allowed. No authentication. | Amended by ADR-063, ADR-085 | [api](modules/api.md), [08](08-crosscutting-concepts.md#86-security-and-trust) |
| ADR-080 | One repo for the app and its three libraries, one shared version (the tag), one install command, no internal dependency entries. | Accepted | [distribution](modules/distribution.md) |

## 10.2 Workflows, the engine and reliability

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-004 | Inject MCP servers per agent step; never rely on global agents or a global Kiro `mcp.json`. | Accepted | [core-engine](modules/core-engine.md) |
| ADR-006 | A workflow is a self-contained folder (`workflow.yaml` + `graph.py`) in a catalog; users install a selection, pinned in a lockfile. | Accepted | [workflow-library](modules/workflow-library.md), [distribution](modules/distribution.md) |
| ADR-007 | Roles are filter tags and bundles are suggestions; nothing is gated by role. | Accepted | [workflow-library](modules/workflow-library.md) |
| ADR-009 | All three human-in-the-loop modes are required: gates, pause/resume, state editing. | Accepted | [runs-and-workers](modules/runs-and-workers.md) |
| ADR-010 | State is small and editable; bulk data lives in the run's blackboard folder. | Accepted | [08](08-crosscutting-concepts.md#82-state-the-blackboard-and-files) |
| ADR-011 | Every agent step has a validator, retries and escalation to a gate; CI enforces it. | Accepted | [core-engine](modules/core-engine.md) |
| ADR-012 | Graphs run in a disposable subprocess worker; pause kills it, resume starts a fresh one; the app never imports workflow code. | Accepted | [runs-and-workers](modules/runs-and-workers.md) |
| ADR-014 | Workflows are authored with the scaffolder, the test harness and the library's guides; anyone may contribute. | Accepted | [workflow-library](modules/workflow-library.md) |
| ADR-018 | Data passes between steps as blackboard files with pointers in state. | Accepted | [core-engine](modules/core-engine.md) |
| ADR-019 | The loader refuses a library built for a different `CORE_MAJOR`; changes within a major are additive. | Amended by ADR-080 | [distribution](modules/distribution.md) |
| ADR-021 | Workflows run without stopping by default; they pause only at sanctioned gates; a `pre_mutation` gate comes before writes unless a confirm is the approval. | Amended by ADR-068, ADR-082 | [core-engine](modules/core-engine.md), [workflow-library](modules/workflow-library.md) |
| ADR-022 | Run artifacts go under a configurable artifacts root with retention. | Accepted | [runs-and-workers](modules/runs-and-workers.md) |
| ADR-025 | Fork creates a new run from a past checkpoint; the original is untouched. | Accepted | [runs-and-workers](modules/runs-and-workers.md) |
| ADR-035 | Files given at launch are copied into the run folder, bounded and sanitised, never passed inline. | Accepted | [runs-and-workers](modules/runs-and-workers.md) |
| ADR-051 | Agent steps call an `AgentProvider` interface; Kiro over ACP is the default implementation. | Accepted | [core-engine](modules/core-engine.md) |
| ADR-067 | A second reliability tier heals an assembled artifact in place, or restarts once with guidance, before escalating. | Accepted | [core-engine](modules/core-engine.md) |
| ADR-069 | A workflow step declares Kiro skills, which Genesis copies into the run folder; never rely on the host's global skills. | Accepted | [core-engine](modules/core-engine.md), [chat-and-skills](modules/chat-and-skills.md) |

## 10.3 Configuration, registries and integrations

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-005 | The shared MCP and CLI registry lives in the library and changes by merge request. | Amended by ADR-029 | [configuration-and-secrets](modules/configuration-and-secrets.md) |
| ADR-020 | Never change the user's global Kiro configuration. | Amended by ADR-029 | [configuration-and-secrets](modules/configuration-and-secrets.md) |
| ADR-029 | Two registry tiers: curated (read-only, from the library) and custom (the user's); a server's allowlist caps a step's tool list. | Amended by ADR-083 | [configuration-and-secrets](modules/configuration-and-secrets.md), [core-engine](modules/core-engine.md#53-how-tool-trust-is-computed) |
| ADR-038 | The Appian Dev and DevOps MCP servers are managed, versioned local installs. | Amended by ADR-073 | [configuration-and-secrets](modules/configuration-and-secrets.md) |
| ADR-040 | The Google Workspace CLI (`gws`) is a managed, versioned local binary. | Accepted | [documents](modules/documents.md) |
| ADR-048 | Core Appian credentials are stored per environment in the SecretProvider and used only from the Dev environment. | Accepted | [configuration-and-secrets](modules/configuration-and-secrets.md) |

## 10.4 Chat and skills

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-031 | Chat is read-only and fail-closed: a read-only allowlist and deny-by-default. | Amended by ADR-033, ADR-034, ADR-045, ADR-076 | [chat-and-skills](modules/chat-and-skills.md) |
| ADR-033 | The copilot may run, answer and cancel runs only with a human confirm for each action, and gets no configuration, secret or deploy tools. | Amended by ADR-034 | [chat-and-skills](modules/chat-and-skills.md) |
| ADR-034 | Skills are standalone activities beside workflows, provisioned as files; chat writes only into a per-session folder. | Accepted | [chat-and-skills](modules/chat-and-skills.md) |
| ADR-045 | Chat mirrors the Kiro CLI surface (models, slash commands, compaction, images) within the read-only posture. | Amended by ADR-076 | [chat-and-skills](modules/chat-and-skills.md) |

## 10.5 Data, credits and observability

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-030 | Persistence stays SQLite until an explicit trigger (multi-user, transcript search, heavy analytics). | Amended by ADR-037, ADR-041 | [data-and-migrations](modules/data-and-migrations.md) |
| ADR-032 | Credits are the metered values Kiro reports, never estimated; every figure carries its provenance. | Accepted | [observability-and-credits](modules/observability-and-credits.md) |
| ADR-054 | Memory lives in its own database file with its own migrations and a local embedder. | Accepted | [memory](modules/memory.md) |
| ADR-066 | Record what each agent turn was given and produced, and show it per turn in the run detail. | Accepted | [observability-and-credits](modules/observability-and-credits.md) |

## 10.6 Knowledge base and documents

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-036 | Genesis owns the Appian KB: its own parser and a local store, fed only by the Dev environment. | Amended by ADR-073 | [knowledge-base](modules/knowledge-base.md) |
| ADR-037 | The KB stores structure only, never SAIL code; code is read live through the Dev MCP. | Amended by ADR-073 | [knowledge-base](modules/knowledge-base.md), [appian-parser](modules/appian-parser.md) |
| ADR-039 | Business understanding is an evidence-grounded artifact built by a workflow from the KB. | Accepted | [knowledge-base](modules/knowledge-base.md) |
| ADR-041 | Documents are one global store (latest version only) linked into applications; untracking removes links, never documents. | Accepted | [documents](modules/documents.md) |
| ADR-052 | Documents are read through a `DocumentProvider` interface. | Accepted | [documents](modules/documents.md) |
| ADR-073 | Package tools are used only by Genesis program code, only on `genesis-delta-*` packages. | Accepted | [knowledge-base](modules/knowledge-base.md) |
| ADR-074 | KB sync is incremental: list objects changed since this machine's last sync and parse only those. | Accepted | [knowledge-base](modules/knowledge-base.md), [scheduler-and-jobs](modules/scheduler-and-jobs.md) |

## 10.7 Features, stages and specs

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-042 | Features and specs belong to an application; a spec is written in chat, and its HTML is authoritative. | Amended by ADR-075 | [features-and-stages](modules/features-and-stages.md) |
| ADR-043 | In-app HTML review uses the vendored Lavish annotation SDK, themed from design tokens. | Accepted | [features-and-stages](modules/features-and-stages.md) |
| ADR-044 | A feature is a workspace of artifact stages, each with its own status. | Superseded by ADR-056 | [features-and-stages](modules/features-and-stages.md#53-the-parallel-and-prerequisite-model) |
| ADR-050 | Every lifecycle status change goes through one `LifecycleService.transition`. | Amended by ADR-076 | [features-and-stages](modules/features-and-stages.md#51-the-lifecycle-service) |
| ADR-056 | Stages are parallel, independent containers over one shared substrate. | Amended by ADR-057, ADR-058, ADR-078 | [features-and-stages](modules/features-and-stages.md) |
| ADR-057 | The UX Design stage turns an uploaded PDF mockup into a grounded analysis. | Amended by ADR-058 | [features-and-stages](modules/features-and-stages.md) |
| ADR-058 | The Technical Design stage builds a grounded object-level design; a stage may declare prerequisites. | Accepted | [features-and-stages](modules/features-and-stages.md) |
| ADR-059 | The Feature Breakdown stage builds a grounded, Jira-ready backlog. | Amended by ADR-075 | [features-and-stages](modules/features-and-stages.md) |
| ADR-060 | Finalize Stories is a one-time, irreversible step that turns the backlog into story records. | Amended by ADR-075 | [features-and-stages](modules/features-and-stages.md), [stories-and-workbench](modules/stories-and-workbench.md) |
| ADR-075 | Every spec clause carries a hidden id that program code owns; stories point at clauses. | Accepted | [features-and-stages](modules/features-and-stages.md#55-clause-ids-and-the-normalizer) |
| ADR-076 | A locked spec changes only through a change request: chat drafts it, program code applies it. | Accepted | [features-and-stages](modules/features-and-stages.md) |
| ADR-078 | A Test Design stage creates reusable cases and ordered scenarios after stories are finalized. | Amended by ADR-081 | [testing](modules/testing.md) |

## 10.8 Stories and the Workbench

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-049 | Applications-first navigation; Overview and Catalog in Settings. | Amended by ADR-061 (the code differs; see [web-app](modules/web-app.md)) | [web-app](modules/web-app.md) |
| ADR-061 | The Workbench: per-application Kanban boards over finalized stories with eight fixed lanes; membership is explicit. | Amended by ADR-062, ADR-084 | [stories-and-workbench](modules/stories-and-workbench.md) |
| ADR-062 | Dragging into Design opens a confirm that launches the design workflow. | Amended and partly superseded by ADR-068 | [stories-and-workbench](modules/stories-and-workbench.md) |
| ADR-068 | Implementation is the only lane that writes design objects; its confirm is the one blanket approval; rollback document first; never delete. | Amended by ADR-082 | [stories-and-workbench](modules/stories-and-workbench.md#54-the-implementation-lane-adr-068-adr-082-amendment) |
| ADR-070 | The Object Wiki is a local-first, Hub-shared, append-only change ledger per object. | Accepted | [stories-and-workbench](modules/stories-and-workbench.md#55-the-object-wiki-adr-070) |
| ADR-071 | One canonical story page, reached from every entry point. | Accepted | [web-app](modules/web-app.md) |
| ADR-072 | Every story gets a global `GNS_` id from a counter inside the creating transaction. | Accepted | [stories-and-workbench](modules/stories-and-workbench.md) |
| ADR-084 | Deployment comes before Verification; dropping into Verification runs the verification workflow and moves the card by its outcome. | Accepted | [stories-and-workbench](modules/stories-and-workbench.md#56-the-verification-lane-adr-084) |

## 10.9 Testing

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-079 | Cases link to stories (fingerprinted) and to KB-confirmed objects; impact is computed on demand and never stored. | Accepted | [testing](modules/testing.md) |
| ADR-081 | Test code is files in a per-application git workspace; the database holds only the catalog; executions run committed code, by program only. | Accepted (amends ADR-078, ADR-047) | [testing](modules/testing.md) |
| ADR-082 | All test execution and agent browser sessions run only on the QA environment, as test users, through the UI. | Accepted | [testing](modules/testing.md) |
| ADR-083 | Browser agents use Kiro's shell with program-opened, QA-pinned sessions; credentials never reach the agent; missing isolation is an accepted risk. | Accepted (accepted risks open) | [testing](modules/testing.md), [08](08-crosscutting-concepts.md#86-security-and-trust) |
| ADR-085 | Playwright reports are served only from a second loopback origin with no `/api`. | Accepted | [api](modules/api.md), [testing](modules/testing.md) |

## 10.10 Collaboration and memory

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-053 | A memory layer distils memory from stored conversations, in personal and shared scopes; personal memory is never shared. | Accepted | [memory](modules/memory.md) |
| ADR-063 | Genesis stays local-first; collaboration is an opt-in sharing of a defined subset through the Hub. | Amended by ADR-065, ADR-074 | [collaboration-hub](modules/collaboration-hub.md) |
| ADR-064 | The Hub is an Appian application in the dev environment with a frozen Web API contract. | Accepted | [collaboration-hub](modules/collaboration-hub.md) |
| ADR-065 | Collaboration is on only when both the environment switch and the Settings switch are on. | Accepted | [collaboration-hub](modules/collaboration-hub.md) |

## 10.11 Web, shipping and process

| ADR | Decision in plain words | Status | Explained in |
|---|---|---|---|
| ADR-027 | Use the established web stack and design tokens, not raw colours. | Accepted | [web-app](modules/web-app.md) |
| ADR-028 | Every backend endpoint is under `/api`; the client adds the prefix centrally. | Amended by ADR-085 | [api](modules/api.md) |
| ADR-046 | Genesis ships as a clone plus a virtual environment, started by `genesis up`, updated by git tag. | Amended by ADR-080 | [distribution](modules/distribution.md) |
| ADR-047 | Scheduled maintenance syncs are fixed and defined by the backend. | Amended by ADR-074, ADR-081 | [scheduler-and-jobs](modules/scheduler-and-jobs.md) |
| ADR-055 | A light-first design language built on the existing tokens and primitives, not a component library. | Accepted | [web-app](modules/web-app.md) |
| ADR-077 | The project's development agents load a small core plus a task pack, never the bulk documents, and never run with trust-all. | Accepted | Not part of the product |

## 10.12 Where the code and a record differ

Writing these documents surfaced places where the v0.81.0 code does not match the wording of a record. The
module documents describe the code and note the difference. The main ones:

- **ADR-029 and ADR-004** for workflow agents: permission requests are auto-approved and Kiro adds the user's
  global MCP servers, so the trust cap is not enforced. ADR-083 records this as an accepted risk.
- **ADR-049**: the navigation shows Home, Workbench, Chat, Runs, Catalog, Documents and Memory; Overview and
  Catalog are not under Settings ([web-app](modules/web-app.md)).
- **ADR-050**: some stage-start routes set `in-progress` directly instead of through the lifecycle service
  ([features-and-stages](modules/features-and-stages.md)).
- **ADR-070**: an Object Wiki entry for a story that already has one on the page is refreshed in place
  ([stories-and-workbench](modules/stories-and-workbench.md#55-the-object-wiki-adr-070)).
- **ADR-046, ADR-047**: their body text describes earlier behaviour; the amending records (ADR-074, ADR-080,
  ADR-081) describe the code.
- **ADR-048**: the record names a secret scope `env:<label>` and an `LCP_API_PATH` value; the code uses the scope
  `env-<hash>` and no longer has `LCP_API_PATH` ([configuration-and-secrets](modules/configuration-and-secrets.md)).
