# Genesis architecture

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · **Owner:** the `genesis-docs` agent

This folder explains how Genesis is built: what the parts are, how they talk to each other, why they are shaped
the way they are, and where to find them in the code. It is written for an engineer who is new to the project and
wants to change it safely. Product managers and reviewers can read the first five documents without reading code.

The documents describe the system as it is at the version in the header, not as it was planned. When a document
and the code disagree, the code is right and the document has a bug: please report it.

## How these documents are organised

The structure follows two widely used standards:

- **[arc42](https://arc42.org/overview)**, a template for architecture documentation used across many
  organisations. Its numbered sections (goals, constraints, context, solution strategy, building blocks, runtime,
  deployment, cross-cutting concepts, decisions, quality, risks, glossary) give the numbered files below.
- **[The C4 model](https://c4model.com/)** for diagrams. C4 draws a system at four zoom levels: **context** (the
  system and the people and systems around it), **containers** (the separately running processes and data
  stores), **components** (the main parts inside one container) and **code**. Each level has its own document.

Two more sources shaped the layout:

- **[Diátaxis](https://diataxis.fr/)** separates tutorials, how-to guides, reference and explanation. These
  documents are *explanation*: they tell you how and why things work. Install steps live in `docs/INSTALL.md`;
  the HTTP reference is the live Swagger page at `/docs`.
- **KiroCrew** (`docs/architecture/` and `docs/system-specs/modules/` in that repo) keeps short "map" documents
  apart from per-module mechanism documents. Genesis does the same: the numbered files are maps, and
  `modules/` holds one detailed document per module.

## Reading order

| # | Document | Read it to learn |
|---|---|---|
| 1 | [01-introduction-and-goals.md](01-introduction-and-goals.md) | What Genesis is for, who uses it, and the quality goals that drive every design choice |
| 2 | [02-constraints.md](02-constraints.md) | The fixed rules: technology, platform, organisation and the binding decisions |
| 3 | [03-system-context.md](03-system-context.md) | C4 level 1: Genesis and every person and outside system it talks to |
| 4 | [04-container-view.md](04-container-view.md) | C4 level 2: every process and data store at run time, and how they connect |
| 5 | [05-solution-strategy.md](05-solution-strategy.md) | The dozen key ideas the architecture is built on, and why |
| 6 | [06-building-blocks.md](06-building-blocks.md) | The module map: every module, its job, its code path and its document |
| 7 | [07-runtime-view.md](07-runtime-view.md) | The main scenarios end to end: a run, a copilot chat, a KB sync, a stage, a story, a test execution, a restart, an update |
| 8 | [08-crosscutting-concepts.md](08-crosscutting-concepts.md) | The rules every module follows: reliability, state, durability, events, human control, security, ids, versions, errors, testing |
| 9 | [09-deployment-view.md](09-deployment-view.md) | What is installed where, ports, the developer checkout and the test fleet |
| 10 | [10-architecture-decisions.md](10-architecture-decisions.md) | Every decision record in plain words, grouped by topic, and where code and record differ |
| 11 | [11-quality-and-risks.md](11-quality-and-risks.md) | Quality scenarios, known risks and technical debt |
| — | [glossary.md](glossary.md) | Every Genesis term in one place |

### Module documents (C4 level 3)

Each module document uses the same sections, so you always know where to look: purpose, at a glance, concepts,
structure, how it works, interfaces, data, failure handling, configuration, extending it, design decisions, known
pitfalls, tests and a code map. They are long, because they are complete. Read the purpose and the "How it works"
section first; use the rest as reference.

| Layer | Module | Document |
|---|---|---|
| Libraries | genesis-core: the workflow engine library | [modules/core-engine.md](modules/core-engine.md) |
| | kiro-agent-sdk: the ACP client for Kiro | [modules/kiro-agent-sdk.md](modules/kiro-agent-sdk.md) |
| | genesis-appian-parser: Appian exports to code-free structure | [modules/appian-parser.md](modules/appian-parser.md) |
| Platform core | Runs and workers: run control, subprocess workers, events, gates | [modules/runs-and-workers.md](modules/runs-and-workers.md) |
| | API: app assembly, `/api`, startup, SPA serving | [modules/api.md](modules/api.md) |
| | Data and migrations: `genesis.db`, every table | [modules/data-and-migrations.md](modules/data-and-migrations.md) |
| | Configuration and secrets: settings, secrets, environments, registries, managed installs | [modules/configuration-and-secrets.md](modules/configuration-and-secrets.md) |
| | Scheduler and jobs | [modules/scheduler-and-jobs.md](modules/scheduler-and-jobs.md) |
| | Observability and credits | [modules/observability-and-credits.md](modules/observability-and-credits.md) |
| | Distribution: install, library, loader, launcher, update | [modules/distribution.md](modules/distribution.md) |
| Product features | Chat and skills | [modules/chat-and-skills.md](modules/chat-and-skills.md) |
| | Knowledge base and sync | [modules/knowledge-base.md](modules/knowledge-base.md) |
| | Documents | [modules/documents.md](modules/documents.md) |
| | Features and stages | [modules/features-and-stages.md](modules/features-and-stages.md) |
| | Stories and Workbench | [modules/stories-and-workbench.md](modules/stories-and-workbench.md) |
| | Test design and execution | [modules/testing.md](modules/testing.md) |
| | Collaboration Hub | [modules/collaboration-hub.md](modules/collaboration-hub.md) |
| | Memory | [modules/memory.md](modules/memory.md) |
| Front end | Web app | [modules/web-app.md](modules/web-app.md) |
| Library | Workflow library and authoring (`genesis-workflows`) | [modules/workflow-library.md](modules/workflow-library.md) |

## Conventions

- **Diagrams** are [Mermaid](https://mermaid.js.org/) blocks. GitLab renders them inline. Each diagram has a
  short text description, so the document still reads without it.
- **Code paths** are relative to the root of the `genesis` repo, for example `genesis/runs/manager.py` or
  `packages/genesis-core/genesis_core/nodes/agent.py`. Paths in the workflow library start with
  `genesis-workflows/`.
- **Decision ids** such as ADR-012 point to the project's architecture decision records. Each document explains
  the decision in plain words, so you do not need the record to follow it.
  [Section 6.4](06-building-blocks.md#64-binding-decisions-by-module) lists which decisions govern which module.
- **Lesson ids** such as L-093 point to the project's list of hard-won lessons: mistakes that happened once and
  must not happen again. Documents mention them where they explain a design that looks odd.
- **Numbers that change every release** (test counts, the database version, installed workflow versions) are
  not repeated here. The header says which version a document describes.

## How these documents stay current

The source copy of this folder lives in project-tracker (`genesis/architecture/`). Any other copy, such as the
genesis repo's `docs/architecture/`, is made from it and never edited directly. After every release, the
`genesis-docs` agent updates every document whose module changed in that release, moves the "Describes" version
forward and records the review date. The procedure is in the `genesis-doc-writeback` skill.
