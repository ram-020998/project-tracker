# Solutions Copilot — Program Documentation

**Status:** Active build (approved subset of the Solutions OS Revamp)
**Working repo:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot`
**Docs (this folder):** `/Users/ramaswamy.u/repo/project-tracker/solutions-copilot`
**Source of legacy assets:** `solutions-os` (`appian/prod` 13490 / `appian/dev` 13491)
**Last updated:** 2026-06-25

---

## What this is

`solutions-copilot` is a **new repository** that holds the working AI tooling for Appian Solutions
teams — **Agents and Skills** (plus their configuration, steering, and MCP wiring). The existing
`solutions-os` repo is reduced to **documentation and product knowledge only**; all executable
tooling moves here.

This is the approved, de-risked subset of the larger *Solutions OS Revamp Plan*. It deliberately
defers the most contentious pieces (the Atlas/Jarvis MCP merge, the orchestrator) and adopts an
**Agents + Skills** model with **no "powers"** concept at all.

## The approved approach in one paragraph

We build **six role-based agents** — Product Owner, UX Designer, Developer, Tester, DevOps,
Documentation — each one a specialist defined by its system prompt and a set of linked **skills**
(one skill = one purpose). The heavy MCP servers (Atlas ~30 tools, Jarvis ~42 tools) plus a Data Generator are each
wrapped in a **dedicated sub-agent** that the role agents call to gather information or act, keeping
those large tool schemas out of the role agents' context. Skills shared across roles live in one shared library.
Everything is migrated losslessly from `solutions-os` via a reviewed traceability matrix. Both
Kiro **CLI and IDE** are targeted; the orchestrator is deferred.

## Locked decisions (2026-06-25)

| # | Decision |
|---|---|
| 1 | **Do not merge Atlas and Jarvis MCP** — keep separate; revisit later. |
| 2 | **Agents + Skills only — no powers.** All existing powers become skills. |
| 3 | **New repo `solutions-copilot`** holds all tools/agents/skills/config; `solutions-os` keeps docs only. |
| 4 | **Six role agents**: Product Owner, UX Designer, Developer, Tester, DevOps, **Documentation**. Each functionality of a role = one skill. |
| 5 | **Dedicated sub-agents** (Atlas, Jarvis, Data Generator) invoked by role agents to gather info / act. |
| 6 | **Both surfaces** (Kiro CLI + IDE). |
| 7 | **Orchestrator deferred** to a later phase. |
| 8 | **Lossless migration** — nothing from `solutions-os` is dropped; every artifact is traced to a target. |
| 9 | **`jarvis-smt`** (DB script mgmt) → **Developer** skill; **`jarvis-verify`** → **Tester** `unit-test` skill (distinct from TEA `test-execution`). Neither needs its own MCP (both use Jarvis). |
| 10 | **CLI tools deferred** — `playwright-deploy`, `fix_table_borders.py`, `QE-Agent` CI not migrated now. |
| 11 | **Drop `atlas-demo-driver`** — not migrated (no demo-driver capability). |
| 12 | **`feature-docgenie` → its own `documentation` role** (not Product Owner). The doc-* workflows live here. |
| 13 | **`erd-generator` → Documentation skill** (`generate-erd`) — it is a power/knowledge, so it migrates as a skill, not a deferred CLI. |
| 14 | **`a11y-fix` (Jarvis-A11yFixer) → Developer skill.** |

## Document index

| Doc | Purpose |
|---|---|
| [01-approved-approach-and-decisions.md](./01-approved-approach-and-decisions.md) | Context, the approved subset, and the rationale/correction behind each decision |
| [02-kiro-primitives-reference.md](./02-kiro-primitives-reference.md) | Verified Kiro syntax for agents, skills, sub-agents, steering, hooks (with sources) |
| [03-target-architecture.md](./03-target-architecture.md) | The three-layer architecture: role agents, MCP sub-agents, shared skills |
| [04-repo-structure.md](./04-repo-structure.md) | Concrete `solutions-copilot` directory layout and conventions |
| [05-skill-design-standard.md](./05-skill-design-standard.md) | Skill granularity rules, SKILL.md template, power→skill mapping rules |
| [06-migration-methodology.md](./06-migration-methodology.md) | Lossless inventory → traceability matrix → transform → verify (gated) |
| [07-sequencing-plan.md](./07-sequencing-plan.md) | Phased build plan with exit criteria |
| [08-solutions-os-inventory.md](./08-solutions-os-inventory.md) | Living inventory of every project/asset across all `solutions-os` branches |
| [09-traceability-matrix.md](./09-traceability-matrix.md) | One row per source artifact → its target in `solutions-copilot` |
| [10-backlog-future-work.md](./10-backlog-future-work.md) | Post-slice work: environment/secrets registry (BL-1) and installer web app/HTML page (BL-2) |
| [11-implementation-status-and-handoff.md](./11-implementation-status-and-handoff.md) | **Read first for handoff** — full status, conventions, mistakes/fixes, what's done, what's next |
| [12-runbook-build-a-role.md](./12-runbook-build-a-role.md) | Step-by-step runbook (copy-paste templates + commands) to build the next role |

## Companion source documents (in `solutions-os-revamp`)

- `Solutions-OS-Revamp-Plan.md` — the approved Round-1 vision
- `Solutions-OS-Technical-Implementation.md` — four-repo topology & decisions log
- `SWAT-a-Palooza-Integration-and-Migration.md` — the 20-project mapping (seed for the matrix)
