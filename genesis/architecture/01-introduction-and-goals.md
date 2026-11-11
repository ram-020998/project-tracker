# 1. Introduction and goals

> **Describes:** genesis v0.81.0 (Phase 51) · **Last reviewed:** 2026-11-11 · arc42 section 1

## 1.1 What Genesis is

Genesis is a web application that runs on one person's computer. It helps an Appian Solutions engineer do
software delivery work with AI help, while the engineer stays in control.

It does this in two ways:

1. **Workflows.** A workflow is a fixed series of steps, drawn as a graph. Some steps are ordinary Python code
   (a *program* step). Some steps ask an AI agent to do one narrow job, such as "write the technical design for
   this feature" (an *agent* step). The graph, not the AI, decides what happens next. Every agent step's output
   is checked by code before the workflow moves on. If the check fails, the step is retried; if it keeps failing,
   a person is asked.
2. **Skills in Chat.** A skill is a packaged set of instructions for one standalone activity, such as drafting a
   document. The engineer asks for it in Chat and the AI agent performs it directly. A skill has no stages.

The AI agent is **Kiro**, run locally through the `kiro-cli` program. Genesis talks to it through the **Agent
Client Protocol (ACP)**, a JSON-RPC protocol over the program's standard input and output. Each agent step gets
only the tools it needs.

Genesis replaced an earlier tool, solutions-copilot. That tool let an AI model decide the order of work, and it
was unreliable. Genesis exists to fix that: **code owns the control flow, and agents only do narrow, checked
work.**

## 1.2 What it does today

| Capability | What the engineer gets |
|---|---|
| Workflow runs | Install workflows from a shared library, launch them, watch them live as a graph, inspect every agent turn, approve or reject at gates, pause, resume, fork |
| Chat | A read-only assistant that answers questions about runs, applications and the knowledge base; it can start runs and answer gates only after the engineer confirms each action |
| Skills | Standalone AI activities from the Chat `/` menu, writing only into a per-chat output folder |
| Applications | A local knowledge base of each Appian application: objects, dependencies, business map, history (the Object Wiki), synced incrementally from the development environment |
| Documents | One library of project documents (uploads, Google Drive) linked into applications |
| Feature workspace | A feature moves through Spec, UX Design, Technical Design, Feature Breakdown and Test Design stages; each produces an HTML artifact; the breakdown becomes stories |
| Workbench | A Kanban board per application. Moving a story card into a lane can launch that lane's workflow (design, implementation, verification) |
| Testing | Browser test code per application in its own git workspace, run against the QA environment as the application's test users, with reports, regression suites and impact analysis |
| Collaboration | Optional sharing of a chosen subset of data with teammates through a shared "Genesis Hub" Appian application |
| Memory | Personal and shared memory distilled from past conversations, readable by chat |
| Credits | The real metered Kiro credits of every agent turn and chat message |

## 1.3 Quality goals

These are the qualities Genesis is designed for, in priority order. When two of them conflict, the higher one
wins. Every later document refers back to them.

| Priority | Quality | What it means in practice |
|---|---|---|
| 1 | **Trustworthy agent output** | No agent output is used until a program check passes. A failed check retries the step with the reason; repeated failure goes to a person. |
| 2 | **Human control** | The engineer can stop, pause, inspect, edit state, fork, approve or reject at any point. Writes to Appian need an explicit approval. Chat never acts without a confirm. |
| 3 | **Durability** | A crash, a restart or a killed process loses no completed work. Runs resume from their last checkpoint. The full event history survives. |
| 4 | **Safety and least privilege** | Genesis listens only on localhost. Each agent step gets only the tools it declares (fully enforced for chat today; for workflow agents see the limits in [3.4](03-system-context.md#34-trust-boundaries)). Secrets never appear in state, logs or chat. |
| 5 | **Honest observability** | Every run shows what each agent was given and produced. Credit figures are the metered values, marked as missing when Kiro did not report them, never estimated. |
| 6 | **Simple workflow authoring** | A workflow is one folder with a `graph.py` and a `workflow.yaml`. The safety wiring comes from library helpers, and a lint refuses a workflow without it. |
| 7 | **Local-first** | Everything works offline from shared services. Sharing with teammates is opt-in and limited to a defined subset. |

## 1.4 Non-goals

Genesis deliberately does **not** do these things. A change that moves towards one of them needs a new
decision first.

- **Multi-user or hosted operation.** Genesis has no login and no user accounts. It must not be exposed on a
  network (ADR-026). A hosted version would be a separate project.
- **AI orchestration.** An AI model never decides which step runs next (ADR-001).
- **Estimated costs.** There is no pricing engine; only metered credits are shown (ADR-032).
- **Changing the user's global Kiro setup.** Genesis never writes the user's global Kiro `mcp.json` (ADR-020).
- **Deleting Appian design objects.** No workflow or tool may delete an Appian object (ADR-068).

## 1.5 Stakeholders

| Who | What they need from Genesis | What they need from these documents |
|---|---|---|
| Solutions engineer (the user) | Reliable help with SDLC work, without losing control | Sections 1, 3 and 5 for a mental model |
| Workflow author | A safe, simple way to add a workflow to the shared library | The core-engine module, the workflows-library module and section 5 |
| Platform contributor | Clear module boundaries and rules, so a change does not break something far away | Everything, especially the module documents |
| Reviewer | A way to check a change against the rules it must follow | Section 2, the module "design decisions" tables and the decision index |
| The Genesis agent team (spec, dev, review, release, docs agents) | The same map a human contributor uses | The module documents and their code maps |

## 1.6 Scope of these documents

These documents cover the `genesis` repository (the app and its three libraries under `packages/`), the
`genesis-workflows` library as far as the platform depends on it, and the `playwright-appian` browser-test tool
as far as Genesis runs it. They do not document individual workflows step by step, the Appian side of the Genesis
Hub, or the internal agent system that builds Genesis.
