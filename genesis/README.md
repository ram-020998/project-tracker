# Genesis — Documentation Index

**Genesis** is an agentic SDLC platform for the Appian **Solutions** department:
a local web application that orchestrates multi-step SDLC **workflows** using
**LangGraph** as the engine and **Kiro** (via `kiro-agent-sdk` over ACP) as the
agent runtime. Workflows are pulled from a shared GitLab library and run on the
user's machine with their own credentials. Genesis **replaces** solutions-copilot
and realizes its deferred (doc-19) orchestration vision.

> All planning/design documentation lives here in `project-tracker/genesis/`.
> Code repos (`genesis`, `genesis-workflows`) are not yet scaffolded.

---

## How to navigate

**Start here**
- [`tracker.md`](tracker.md) — master tracker: status, the Q1–Q14 locked decisions, phase index, reuse map, open items.
- [`specs/00-architecture-overview.md`](specs/00-architecture-overview.md) — the layered architecture, domain model, node taxonomy, state/blackboard rule. **Read before any phase spec.**
- [`progress/`](progress/) — as-built implementation records per phase (evidence, decisions, deviations). Start with [`progress/phase-01-implementation.md`](progress/phase-01-implementation.md).

**Phase specs (the build plans)** — `specs/`
| Phase | Spec | Title |
|---|---|---|
| 1 | [phase-01](specs/phase-01-core-platform-foundation.md) | Core Platform Foundation |
| 2 | [phase-02](specs/phase-02-workflow-contract-and-library.md) | Workflow Contract & Library System |
| 3 | [phase-03](specs/phase-03-distribution-install-lockfile.md) | Distribution: GitLab Pull, Selective Install, Lockfile |
| 4 | [phase-04](specs/phase-04-configuration-and-secrets.md) | Configuration & Secrets |
| 5 | [phase-05](specs/phase-05-run-orchestration-and-hitl.md) | Run Orchestration & HITL |
| 6 | [phase-06](specs/phase-06-erd-reference-workflow.md) | ERD Reference Workflow |
| 7 | [phase-07](specs/phase-07-custom-web-workbench.md) | Custom Web Workbench UI |
| 8 | [phase-08](specs/phase-08-skill-migration-program.md) | Skill → Workflow Migration Program |

**Reference docs (the stable, cross-cutting truth)** — `reference/`
| Doc | Purpose |
|---|---|
| [decision-log](reference/decision-log.md) | ADR-style record of Q1–Q14 + alternatives + rationale |
| [roadmap-and-sequencing](reference/roadmap-and-sequencing.md) | Phases, milestones, dependencies, build order |
| [repo-structure](reference/repo-structure.md) | Layout of `genesis` + `genesis-workflows` |
| [node-taxonomy-reference](reference/node-taxonomy-reference.md) | Every node factory + the kiro-agent-sdk integration |
| [state-and-data-model](reference/state-and-data-model.md) | `PlatformState`, blackboard, artifact conventions |
| [mcp-and-cli-registry](reference/mcp-and-cli-registry.md) | Registry schemas + catalog of known servers/CLIs |
| [workflow-authoring-standard](reference/workflow-authoring-standard.md) | The canonical standard authors follow |
| [reliability-standard](reference/reliability-standard.md) | The hard requirement: validator + retry/escalation |
| [hitl-design](reference/hitl-design.md) | The three HITL modes in depth |
| [security-and-secrets](reference/security-and-secrets.md) | Trust model, secret handling, pulled-code stance |
| [testing-strategy](reference/testing-strategy.md) | Platform + workflow testing + CI gates |
| [langgraph-capability-map](reference/langgraph-capability-map.md) | Which LangGraph features are used where |
| [solutions-copilot-relationship](reference/solutions-copilot-relationship.md) | Positioning + reuse map + doc-19 realization |
| [glossary](reference/glossary.md) | Terms |

---

## The idea in five bullets

1. **LangGraph owns control flow** — determinism never depends on a model's discipline (the failure that sank the solutions-copilot agent-orchestrator).
2. **Each former "skill" becomes a workflow** — a LangGraph package; each step is a **program** (if deterministic) or a narrow **agent** node (Kiro via ACP with per-node MCP injection).
3. **Reliability trio is mandatory** — every agent node has a program **validator** + **retry/escalation**, enforced in library CI. This is the differentiator.
4. **Small editable state + a per-run blackboard folder** for bulk data — makes durable checkpointing and human state-editing usable.
5. **Local web app, shared GitLab workflow library, selective install** — internal Solutions use (Dev/Tester/PO/UX), all three HITL modes required.

---

## Related trackers

- [`../kiro-agent-sdk/tracker.md`](../kiro-agent-sdk/tracker.md) — the Kiro/ACP node adapter (built + validated: ERD ran end-to-end, 37 tables / 174 relationships).
- [`../solutions-copilot/`](../solutions-copilot/) — the retired predecessor; its 45 skills are the migration source (Phase 8) and doc-19 is Genesis's de-facto requirements.
