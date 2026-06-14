# Solutions OS — SWAT-a-Palooza Integration & Migration Plan

**Version:** 1.0 Draft
**Date:** June 14, 2026
**Author:** Ram
**Status:** For technical review (Principal Leads & Architects)
**Companion to:** `Solutions-OS-Technical-Implementation.md` and `Solutions-OS-Revamp-Plan.md`

---

## About This Document

The 20 projects built during SWAT-a-Palooza are the proof that Solutions OS works. This document specifies **how each of them is brought into the new architecture** — what *format* each becomes (power, skill, agent, steering/hook, MCP server, CLI, or external tool), **where it lives** in the repository structure, which **tools** it depends on, which **SDLC stage** it serves, and a **step-by-step migration plan** to convert it into that proper format.

It is the integration companion to the Technical Implementation document: that doc defines the target repos and the orchestration layer; this doc places all 20 projects into them and sequences the migration.

The guiding constraint (from the Technical Implementation doc): `solutions-os` holds **knowledge and orchestration only** (powers, skills, agents, steering, feature packets). **Tool inner-workings** live in `solutions-ai-tools`. So each SWAT project is split, where relevant, into (a) its **orchestration artifact** in `solutions-os` and (b) its **tool inner-workings** in `solutions-ai-tools` or an external repo.

---

## Table of Contents

1. [Target Format Taxonomy](#1-target-format-taxonomy)
2. [Placement Rules](#2-placement-rules)
3. [Master Mapping Table (all 20 projects)](#3-master-mapping-table-all-20-projects)
4. [Expanded solutions-os Repo Structure (with all projects placed)](#4-expanded-solutions-os-repo-structure-with-all-projects-placed)
5. [Per-Project Migration Detail](#5-per-project-migration-detail)
   - [5.1 Accessibility](#51-accessibility)
   - [5.2 Data Generation](#52-data-generation)
   - [5.3 Design & UX Handoff](#53-design--ux-handoff)
   - [5.4 Development Tooling & IDE](#54-development-tooling--ide)
   - [5.5 Documentation & Reporting](#55-documentation--reporting)
   - [5.6 Process & Methodology](#56-process--methodology)
   - [5.7 Testing](#57-testing)
6. [Cross-Cutting Migration Concerns](#6-cross-cutting-migration-concerns)
7. [Phased Migration Plan](#7-phased-migration-plan)
8. [Risks & Validation](#8-risks--validation)

---

## 1. Target Format Taxonomy

Every SWAT project is migrated into exactly one **primary** format (and sometimes a secondary one). The formats and where they live:

| Format | What it is | Lives in | Token cost |
|---|---|---|---|
| **Power** | IDE-first packaged workflow (POWER.md + steering), no bundled MCP config | `solutions-os` → `ai-framework/powers/<name>/` | loaded on activation |
| **Skill** | On-demand reference knowledge, reusable across agents/powers | `solutions-os` → `ai-framework/skills/<name>/` | loaded when relevant |
| **Sub-agent** | Specialist invoked by the orchestrator | `solutions-os` → `.kiro/agents/<name>.json` (+ prompt in `ai-framework/agents/`) | session |
| **Steering / Hook** | Always-on directive, or event-triggered automation | `solutions-os` → `ai-framework/steering/` or `.kiro/hooks/` | always / on event |
| **MCP server** | Interactive tool inner-workings (a Docker image) | `solutions-ai-tools` → `servers/<name>/` | standing schemas |
| **CLI tool** | Batch/one-shot tool inner-workings (a Docker image, shelled out to) | `solutions-ai-tools` → `servers/<name>/` | zero standing |
| **External / Standalone** | Tool that is not an MCP/CLI we host (e.g., an IDE extension, a hosted app) | its own repo; **referenced** by `solutions-os` manifest/registry | n/a |
| **Core structure** | A convention baked into the repo itself (not a deliverable artifact) | `solutions-os` conventions | n/a |

A project frequently maps to **a power or sub-agent in `solutions-os` that *uses* a tool in `solutions-ai-tools`.** The migration therefore usually has two tracks: (1) author the orchestration artifact, (2) place/adopt the tool.

---

## 2. Placement Rules

The rules that decide a project's format and location:

1. **Workflow → Power (default).** If the project is a guided, multi-step AI workflow a user activates, it becomes a power under the relevant specialist. Most SWAT projects are powers or power-actions.
2. **Reusable reference knowledge → Skill.** If the project is primarily a rule set, grammar, or checklist used *by* other workflows, it becomes a skill (shared across powers/agents).
3. **Cross-power orchestration → Sub-agent.** If it coordinates multiple powers/tools and is invoked by the orchestrator, it becomes a sub-agent (which may itself call a power).
4. **Interactive, fine-grained tool → MCP server.** Goes to `solutions-ai-tools/servers/` as an MCP image.
5. **Batch/one-shot/large-output tool → CLI.** Goes to `solutions-ai-tools/servers/` as a CLI image (token-efficient).
6. **Not ours to host → External, referenced only.** IDE extensions and hosted apps stay in their own repos; `solutions-os` references them via the manifest/environment registry.
7. **A convention, not a deliverable → Core structure.** Baked into the repo layout.
8. **Event-driven automation → Hook;** always-on guidance → **Steering**.
9. **No bundled `mcp.json` anywhere.** Powers reference globally-available tools by name (per the Technical Implementation doc).
10. **Every artifact declares its SDLC stage** so the orchestrator can route to it.

---

## 3. Master Mapping Table (all 20 projects)

| # | Project | Primary format | SDLC stage(s) | Lands in | Tool dependencies | Origin owner |
|---|---|---|---|---|---|---|
| 1 | A11Y Fixer | **Power** `a11y-fixer` (+ sub-agent wrapper) | Verify, Support | `ai-framework/powers/a11y-fixer/` | intelligence (live), write, playwright, jira | Soma, Harish |
| 2 | AI A11y Audit | **Skill** `a11y-audit` | Verify | `ai-framework/skills/a11y-audit/` | intelligence (read), google (report) | Ganesh |
| 3 | Atlas SQL Forge | **Power** `sql-forge` (+ sub-agent) | Build, Verify | `ai-framework/powers/sql-forge/` | intelligence (cloud schema), data-generator | Ram, Dineshkumar |
| 4 | DataForge | **Power-action** in `sql-forge` + **CLI** for scale | Verify | `sql-forge/steering/` + `solutions-ai-tools/servers/data-generator/` | data-generator (bulk), intelligence schema | Hitesh |
| 5 | Flow-Craft Sprint Report | **CLI** + power wrapper | Release, Support | `solutions-ai-tools/servers/sprint-report/` + `ai-framework/powers/sprint-report/` | jira, (custom metrics) | Josh, Saravana, Rob |
| 6 | UX Designer Power Enhancements | **Power** `ux-designer` | Design | `ai-framework/powers/ux-designer/` | intelligence, aurora skill | Vedant |
| 7 | Kiro → FigJam | **Power-action** in `ux-designer` | Design | `ux-designer/steering/action-figjam.md` | external FigJam MCP | Anthony |
| 8 | Spec → Slides | **Power-action** in `product-owner` | Release | `product-owner/steering/action-slides.md` | google workspace | Sonali |
| 9 | Jarvis SAIL Canvas | **Power-action** in `ux-designer` + **External** preview app | Design | `ux-designer/` + external React app | intelligence (live get object) | Govind |
| 10 | Jarvis Sweep | **Power-action** in `developer` (workflow) | Build, Support | `developer/steering/action-sweep.md` | intelligence (live), write, deploy | Khoa et al. |
| 11 | Perf-Profiler | **CLI** | Verify | `solutions-ai-tools/servers/perf-profiler/` | (package transform; standalone) | Raajiv |
| 12 | Local-IDE Development | **External / Standalone** (IDE extension) | Build | own repo; referenced | env registry, write | William Ingold |
| 13 | LCP APIs / a!migo | **MCP server** `solutions-write-mcp` | Build | `solutions-ai-tools/servers/write/` | (is the write tool) | Saurabh et al. |
| 14 | SAIL → SQL | **Power-action** in `sql-forge` | Build, Verify | `sql-forge/steering/action-sail-to-sql.md` | intelligence (read code), write (eval) | Dineshkumar, Ram |
| 15 | Feature Doc Genie | **Power** `feature-docgenie` (under product-owner) | Plan, Release | `ai-framework/powers/feature-docgenie/` | intelligence (cloud), google docs | Meenakshi |
| 16 | ERD & Release Docs | **Power-action** in `sql-forge` / `product-owner` | Release | `sql-forge/steering/action-erd.md` | intelligence (schema), external Lucidchart, google | Revathi et al. |
| 17 | KB Maintenance | **Skill** + **Hook** | Release, Support | `ai-framework/skills/kb-maintenance/` + `.kiro/hooks/` | intelligence, git | Colin Hutchison |
| 18 | T.I.M.E. Framework | **Core structure** (feature packets + SDLC stages) | all | `solutions-os` conventions | n/a | Ben Lloyd |
| 19 | Test Execution Agent | **Sub-agent** `qe-agent` | Verify | `.kiro/agents/qe-agent.json` | intelligence, data-generator, playwright, jira | Divya et al. |
| 20 | Expression Test Gen (Jarvis Assert) | **Power-action** in `developer` | Build, Verify | `developer/steering/action-expression-tests.md` | intelligence, write (eval), deploy | Abby et al. |

**Summary by format:** 4 standalone powers (a11y-fixer, sql-forge, ux-designer, feature-docgenie) · 1 power+CLI (sprint-report) · 6 power-actions folded into existing powers · 2 skills (a11y-audit, kb-maintenance) · 1 sub-agent (qe-agent; plus a11y-fixer optionally) · 2 tool servers (write/a!migo, perf-profiler CLI) · 1 external (Local-IDE) · 1 core-structure (T.I.M.E.).

---

## 4. Expanded solutions-os Repo Structure (with all projects placed)

This shows exactly where every SWAT project lands. Annotations in `← #n` reference the project number from the master table.

```
solutions-os/                              (appian/dev + appian/prod)
├── setup.sh
├── solutions-os.manifest.json             # declares powers/skills/agents + tool images
├── environments.json
│
├── .kiro/
│   ├── agents/
│   │   ├── orchestrator.json               # routes by SDLC stage
│   │   ├── qe-agent.json                    ← #19 Test Execution Agent
│   │   ├── a11y-fixer.json                  ← #1 (sub-agent wrapper over the power)
│   │   ├── developer.json
│   │   ├── product-owner.json
│   │   └── ux-designer.json
│   ├── hooks/
│   │   └── kb-maintenance-on-release.hook   ← #17 (event-driven KB refresh)
│   └── steering/                            # global steering (incl. source-routing guidance)
│
├── ai-framework/
│   ├── orchestrator/                        # prompt, capabilities, SDLC routing rules
│   ├── agents/                              # sub-agent prompts
│   │   ├── qe-agent-prompt.md               ← #19
│   │   ├── a11y-fixer-prompt.md             ← #1
│   │   ├── developer-prompt.md
│   │   ├── product-owner-prompt.md
│   │   └── ux-designer-prompt.md
│   ├── powers/
│   │   ├── a11y-fixer/                       ← #1  (Verify/Support)
│   │   │   ├── POWER.md
│   │   │   └── steering/ (56 fix patterns)
│   │   ├── sql-forge/                        ← #3  (Build/Verify)
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── action-explore-schema.md
│   │   │       ├── action-generate-data.md
│   │   │       ├── action-bulk-sql.md        ← #4  DataForge (bulk/offline)
│   │   │       ├── action-sail-to-sql.md     ← #14 SAIL→SQL
│   │   │       └── action-erd.md             ← #16 ERD & Release Docs
│   │   ├── ux-designer/                      ← #6  (Design)
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── action-aurora-compliance.md
│   │   │       ├── action-component-decomposition.md
│   │   │       ├── action-figjam.md          ← #7  Kiro→FigJam
│   │   │       └── action-sail-canvas.md     ← #9  SAIL Canvas (drives external app)
│   │   ├── developer/                        # (Build/Support)
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── action-explore.md
│   │   │       ├── action-impact-analysis.md
│   │   │       ├── action-design-document.md
│   │   │       ├── action-code-review.md
│   │   │       ├── action-sweep.md           ← #10 Jarvis Sweep
│   │   │       └── action-expression-tests.md← #20 Expression Test Gen
│   │   ├── product-owner/                    # (Plan/Release)
│   │   │   ├── POWER.md
│   │   │   └── steering/
│   │   │       ├── action-feature-spec.md
│   │   │       ├── action-release-review.md
│   │   │       └── action-slides.md          ← #8  Spec→Slides
│   │   ├── feature-docgenie/                 ← #15 (Plan/Release)
│   │   │   ├── POWER.md
│   │   │   ├── steering/ (6 doc workflows)
│   │   │   └── templates/
│   │   └── sprint-report/                    ← #5  (Release/Support) power wrapper over CLI
│   │       └── POWER.md
│   ├── skills/
│   │   ├── a11y-audit/                        ← #2  (80+ rule checks)
│   │   │   └── SKILL.md
│   │   ├── kb-maintenance/                    ← #17 (release update checklist)
│   │   │   └── SKILL.md
│   │   ├── sail-reference/                    # SAIL grammar + best practices
│   │   └── aurora-design-system/              # used by #6/#7/#9
│   └── steering/
│
├── products/                                 ← #18 T.I.M.E. realized as feature packets
│   └── <solution>/
│       ├── domain/  competitive-analysis/  arch-decision-logs/  steering/
│       └── features/<feature>/   { spec.md, mockups/, adrs/, design.md, status.md }
│
└── @DOCS/  schemas/  standards/
```

### Tool inner-workings that land in `solutions-ai-tools` (not `solutions-os`)

```
solutions-ai-tools/servers/
├── intelligence/        # READ — backs nearly every project's "understand the app" step
├── write/               ← #13 a!migo / LCP APIs (the write MCP)
├── deploy/              # used by #10 Sweep, #20 Assert (deploy step)
├── data-generator/      # used by #3 SQL Forge, #4 DataForge, #19 QE
├── locust/              # perf-test generation
├── perf-profiler/       ← #11 Perf-Profiler (CLI; package transform)
└── sprint-report/       ← #5  Flow-Craft (CLI; Python metrics + Jira)
```

### External / referenced (not hosted in either repo)

| Project | Where it stays | How solutions-os relates to it |
|---|---|---|
| #12 Local-IDE Development | its own IDE-extension repo | referenced in manifest; benefits from env registry + write tool |
| #9 SAIL Canvas preview app | its own React-app repo | launched by the `ux-designer` SAIL-canvas action |
| FigJam MCP (#7), Lucidchart (#16), Google Workspace (#8/#15/#16), Jira, Playwright | external/3rd-party MCPs | registered as infrastructure by `setup.sh` |

---

## 5. Per-Project Migration Detail

Each entry follows the same shape: **What it is · Current source · Target format & path · Dependencies · Migration steps · Acceptance criteria.** Steps assume the standard pattern: decouple any bundled `mcp.json`, normalize naming (drop tool codenames), and reference globally-available tools.

### 5.1 Accessibility

#### #1 — A11Y Fixer
- **What it is:** automated accessibility remediation with 56 fix patterns; finds violations, applies fixes, deploys.
- **Current source:** Soma/Harish project; uses live environment + Jira + Playwright.
- **Target format & path:** **Power** `ai-framework/powers/a11y-fixer/` (POWER.md + steering with the 56 patterns), plus a thin **sub-agent** `.kiro/agents/a11y-fixer.json` so the orchestrator can delegate on "fix accessibility" triggers.
- **Dependencies:** intelligence (live get-object), write (apply fixes), deploy, playwright, jira.
- **Migration steps:**
  1. Extract the 56 fix patterns into `steering/` (one file per pattern group); keep them tool-agnostic (reference tool names, not configs).
  2. Remove any bundled MCP config; the power calls the global write + deploy + playwright tools.
  3. Author POWER.md with the find→fix→deploy workflow keyed to SDLC stages Verify/Support.
  4. Add the sub-agent wrapper + prompt for orchestrator delegation.
- **Acceptance:** activating the power on a flagged interface fixes and (optionally) deploys; orchestrator routes "fix a11y" to it.

#### #2 — AI A11y Audit
- **What it is:** 80+ accessibility rule checks with recursive interface discovery and cross-app pattern matching; produces a report.
- **Current source:** Ganesh project (originally a power).
- **Target format & path:** **Skill** `ai-framework/skills/a11y-audit/SKILL.md` (the rule set as reference knowledge), so it is loadable by `developer`, `qe-agent`, and `a11y-fixer` alike.
- **Dependencies:** intelligence (read, recursive discovery), google (report export).
- **Migration steps:**
  1. Convert the power's rule knowledge into a SKILL.md (frontmatter + the 80+ rules).
  2. Keep report-generation as guidance that calls the google tool; no bundled config.
  3. Reference the skill from the a11y-fixer power and qe-agent.
- **Acceptance:** any agent can load the audit skill on demand and run the checks; a11y-fixer consumes it for its find step.

### 5.2 Data Generation

#### #3 — Atlas SQL Forge
- **What it is:** 6-step workflow (analyze→discover→architect→plan→approve→execute) for schema-aware test data.
- **Current source:** existing power `ai-framework/Engineering/.kiro/powers/atlas-sql-forge/` (with bundled `mcp.json`).
- **Target format & path:** **Power** `ai-framework/powers/sql-forge/` (renamed — drop "atlas"), plus a **sub-agent** for orchestrator delegation.
- **Dependencies:** intelligence (cloud schema, relationships, insertion order), data-generator (CRUD).
- **Migration steps:**
  1. Rename `atlas-sql-forge` → `sql-forge`; remove bundled `mcp.json`.
  2. Repoint steering tool references to the unified intelligence tools (`get_data_model`, schema tools) + data-generator.
  3. Keep the 6 step files; add SDLC stage tags (Build/Verify).
- **Acceptance:** the workflow runs end-to-end against the global tools with no per-power config.

#### #4 — DataForge (bulk/offline)
- **What it is:** bulk, offline, scale-tiered (S/M/L/XL) test-data generation; schema introspection + dependency-ordered inserts.
- **Current source:** Hitesh project.
- **Target format & path:** **Power-action** folded into `sql-forge` (`steering/action-bulk-sql.md`) for the interactive path, **plus** a **CLI** capability in `solutions-ai-tools/servers/data-generator/` for true scale/offline runs.
- **Dependencies:** data-generator (bulk), intelligence (schema, insertion order).
- **Migration steps:**
  1. Merge the bulk-generation guidance into sql-forge as an action.
  2. Add a batch/offline mode to the data-generator server invokable as a CLI for large volumes (token-efficient).
- **Acceptance:** small/interactive volumes via the MCP path; large volumes via the CLI; both honor dependency order.

### 5.3 Design & UX Handoff

#### #6 — UX Designer Power Enhancements
- **What it is:** 6 actions — edge-case analysis, platform feasibility, design consistency, component decomposition, design-to-dev handoff, Aurora compliance.
- **Current source:** existing power `ai-framework/Product/.kiro/powers/atlas-ux-designer/`.
- **Target format & path:** **Power** `ai-framework/powers/ux-designer/`.
- **Dependencies:** intelligence (read), `aurora-design-system` skill.
- **Migration steps:** rename (drop "atlas"); remove bundled config; keep the action files; reference the Aurora skill; tag SDLC stage Design.
- **Acceptance:** all 6 actions run against global tools.

#### #7 — Kiro → FigJam
- **What it is:** turns specs (from feature packets) into FigJam user-flow diagrams; auto-syncs as specs evolve.
- **Current source:** Anthony project; uses a FigJam MCP.
- **Target format & path:** **Power-action** in `ux-designer` (`steering/action-figjam.md`).
- **Dependencies:** external FigJam MCP (registered as infrastructure), reads packet `spec.md`.
- **Migration steps:** add the action to ux-designer; register FigJam MCP in the manifest; point the action at the feature-packet `spec.md`.
- **Acceptance:** running the action on a packet produces/updates a FigJam diagram.

#### #8 — Spec → Slides
- **What it is:** transforms a markdown spec into slides (pptx / Google Slides) for handoff.
- **Current source:** Sonali project.
- **Target format & path:** **Power-action** in `product-owner` (`steering/action-slides.md`).
- **Dependencies:** google workspace MCP.
- **Migration steps:** add the action; reference the global google tool; source from packet `spec.md`; tag stage Release.
- **Acceptance:** a packet spec exports to Google Slides.

#### #9 — Jarvis SAIL Canvas
- **What it is:** interactive SAIL preview (local React app) with state switching; exports validated SAIL.
- **Current source:** Govind project; uses live get-object; ships a local React app.
- **Target format & path:** **Power-action** in `ux-designer` (`steering/action-sail-canvas.md`) that drives an **external** preview app (kept in its own repo).
- **Dependencies:** intelligence (live get-object with dependencies); the external app.
- **Migration steps:** add the action; keep the React app external and reference it in the manifest; the action fetches object+deps via the intelligence tool and launches the preview.
- **Acceptance:** the action previews and exports validated SAIL.

---

### 5.4 Development Tooling & IDE

#### #10 — Jarvis Sweep
- **What it is:** export→analyze→clean→deploy workflow that removes dead/duplicate objects.
- **Current source:** Khoa et al.; uses the live environment.
- **Target format & path:** **Power-action** in `developer` (`steering/action-sweep.md`).
- **Dependencies:** intelligence (live + dead-code), write (clean), deploy.
- **Migration steps:** add the action to the developer power; reference intelligence dead-code tools + write + deploy; tag Build/Support.
- **Acceptance:** "sweep X" runs the full cycle through global tools.

#### #11 — Perf-Profiler (Application Performance Profiling)
- **What it is:** package transformation — input an Appian zip, output an instrumented zip. Generic, app-agnostic.
- **Current source:** Raajiv; standalone CLI-style tool.
- **Target format & path:** **CLI** `solutions-ai-tools/servers/perf-profiler/` (Docker image, shelled out to). Optionally invokable by the `developer` power.
- **Dependencies:** none on the live env (pure transform); reads/writes zips.
- **Migration steps:** bring the transformer into the monorepo as a CLI server image; expose a `developer` action that shells out to it.
- **Acceptance:** developer can produce an instrumented package via the CLI.

#### #12 — Local-IDE Development
- **What it is:** a VSCode/Kiro IDE extension for local Appian development.
- **Current source:** William Ingold; an IDE extension.
- **Target format & path:** **External / Standalone** — stays in its own repo; **referenced** by `solutions-os` (manifest/registry). It is not a power/skill/agent.
- **Dependencies:** benefits from the environment registry and the write tool, but is not hosted here.
- **Migration steps:** document it in the manifest as an external tool; ensure it can target environments via the registry and use the write API.
- **Acceptance:** the extension is discoverable/documented in solutions-os without its source being imported.

#### #13 — LCP APIs / a!migo
- **What it is:** 130+ (plugin) + 107 (beta) LCP operations — the full write/CRUD surface.
- **Current source:** `saurabh.sabat/lcp-api`; today a **library + ops dispatch module**, not an MCP server.
- **Target format & path:** **MCP server** `solutions-ai-tools/servers/write/` → `solutions-write-mcp`.
- **Dependencies:** Appian LCP plugin + feature toggles on the target site.
- **Migration steps:**
  1. Bring the LCP client into `servers/write/`.
  2. **Wrap it as an MCP server** (the one genuine "library→MCP" build task; the buildwithclaude MCP server is the reference for exposing LCP as MCP).
  3. Absorb `evaluate_sail_expression` and `query_sql` here (moved off the read server).
  4. Keep the data-model-from-sheet and bulk-rename workflows as write-side capabilities.
- **Acceptance:** all object creation/mutation, SAIL eval, and SQL go through this single write image.

#### #14 — SAIL → SQL
- **What it is:** converts SAIL logic into SQL stored procedures; multi-DB (MariaDB, Oracle, …).
- **Current source:** Dineshkumar/Ram.
- **Target format & path:** **Power-action** in `sql-forge` (`steering/action-sail-to-sql.md`).
- **Dependencies:** intelligence (read object code), write (evaluate).
- **Migration steps:** add the action; read code via intelligence, validate via write-eval; emit SQL per dialect.
- **Acceptance:** a SAIL rule converts to validated SQL for the chosen dialect.

### 5.5 Documentation & Reporting

#### #15 — Solutions Feature Doc Genie
- **What it is:** one prompt → 6 documents (FIP, Tech Design, Perf Review, Security Review, Arch Overview, ADR); spec-readiness validation; Google Docs export.
- **Current source:** existing power `ai-framework/Engineering/.kiro/powers/feature-docgenie/` (has templates + scripts).
- **Target format & path:** **Power** `ai-framework/powers/feature-docgenie/` (retain), under product-owner's purview.
- **Dependencies:** intelligence (cloud, ~8 read calls), google docs.
- **Migration steps:** keep the power and templates; remove any bundled config; source inputs from the feature packet; output ADRs back into the packet's `adrs/`; tag Plan/Release.
- **Acceptance:** the power generates the 6 docs from a packet and writes ADRs into the packet.

#### #16 — Automate ERD & Release Documentation
- **What it is:** one line → ERDs (simple + complex) in Lucidchart + release notes in Google Docs; handles 155+ tables.
- **Current source:** Revathi et al.
- **Target format & path:** **Power-action** in `sql-forge` (ERD) and/or `product-owner` (release notes) — `steering/action-erd.md`.
- **Dependencies:** intelligence (schema), external Lucidchart, google docs.
- **Migration steps:** add the action; pull schema from intelligence; register Lucidchart + google as infrastructure; tag Release.
- **Acceptance:** ERDs and release notes generate from the schema in one action.

### 5.6 Process & Methodology

#### #5 — Flow-Craft Sprint Report
- **What it is:** Python-based, hallucination-free sprint metrics aggregation; color-coded health reports.
- **Current source:** Josh/Saravana/Rob; standalone Python + Jira.
- **Target format & path:** **CLI** `solutions-ai-tools/servers/sprint-report/` (deterministic Python), with a thin **power** `ai-framework/powers/sprint-report/` that invokes it.
- **Dependencies:** jira, custom data sources.
- **Migration steps:** bring the Python tool into the monorepo as a CLI image; add a power that shells out to it and formats the result; tag Release/Support.
- **Acceptance:** "generate sprint report" produces the metrics report via the deterministic CLI.

#### #17 — AI-assisted Kiro KB Maintenance
- **What it is:** on release, reviews public docs + KB + app code, updates the KB, runs a quality checklist, commits.
- **Current source:** Colin Hutchison; a steering file + git automation.
- **Target format & path:** **Skill** `ai-framework/skills/kb-maintenance/` (the checklist/knowledge) + **Hook** `.kiro/hooks/` (the on-release git automation).
- **Dependencies:** intelligence, git.
- **Migration steps:** convert the steering into a skill; register the git automation as a hook keyed to release events; ensure it updates the consolidated KB sources.
- **Acceptance:** a release triggers the maintenance hook; the skill guides the review/checklist.

#### #18 — The T.I.M.E. Framework
- **What it is:** lifecycle methodology — taking ideas to market expeditiously.
- **Current source:** Ben Lloyd; a methodology.
- **Target format & path:** **Core structure** — realized as the **feature packet** convention (`features/<feature>/` with `status.md`) and the **SDLC routing taxonomy** (Plan→…→Support) in the orchestrator. Not a discrete deliverable artifact.
- **Migration steps:** ensure the products/feature-packet structure and the orchestrator's stage taxonomy encode the lifecycle; document the stage transitions and the AI actions per transition.
- **Acceptance:** moving a packet's stage triggers the appropriate orchestrator behavior.

### 5.7 Testing

#### #19 — Solutions Test Execution Agent
- **What it is:** end-to-end test execution + verification; impact-aware; uses data gen, Playwright, Jira.
- **Current source:** Divya et al.; lives on a solutions-os branch (`dp-test-execution-agent` / `atlas-qe-forge`).
- **Target format & path:** **Sub-agent** `.kiro/agents/qe-agent.json` (+ prompt), with the QE knowledge as a **skill**.
- **Dependencies:** intelligence (impact analysis), data-generator, playwright, jira.
- **Migration steps:** consolidate the branch work into the qe-agent sub-agent; reference intelligence + data-generator + playwright + jira via global config; tag Verify; expose a QE skill for shared checklists.
- **Acceptance:** "verify GAMS-XXXX" runs impact-aware tests through the sub-agent.

#### #20 — Expression Test Case Generation (Jarvis Assert)
- **What it is:** generates expression-rule tests (happy path, null, off-by-one, out-of-bounds); same deploy pipeline as Sweep.
- **Current source:** Abby et al.; lives on the `expressionTestCases` branch.
- **Target format & path:** **Power-action** in `developer` (`steering/action-expression-tests.md`).
- **Dependencies:** intelligence (read rule), write (evaluate), deploy.
- **Migration steps:** add the action to the developer power; generate test cases, validate via write-eval, deploy via the deploy tool; tag Build/Verify.
- **Acceptance:** "generate tests for X" produces and validates expression tests.

---

## 6. Cross-Cutting Migration Concerns

These apply to *every* project migration and should be done consistently.

### 6.1 Decouple MCP config from powers
Today several powers bundle their own `mcp.json` (e.g., `atlas-developer`, `atlas-sql-forge`). Every migrated power **removes** its bundled config and instead references tools that `setup.sh` has made globally available. This is the single most repeated migration step.

### 6.2 Naming normalization
Drop tool codenames from artifact names: `atlas-developer` → `developer`, `atlas-sql-forge` → `sql-forge`, `atlas-ux-designer` → `ux-designer`, `atlas-product-owner` → `product-owner`. Artifacts are named for **what they do**, not the backend they came from. (The Cloud/Live planes are an internal detail behind the unified intelligence tools.)

### 6.3 Source-routing moves to steering
Wherever a project chose between "parsed KB" and "live environment," that choice becomes the `source` parameter on the unified intelligence tools, and the *guidance* for when to use which lives in the power/agent steering — not in the project's own logic.

### 6.4 Tool extraction to `solutions-ai-tools`
Projects that are actually tools (a!migo, Perf-Profiler, Flow-Craft, the data-gen bulk path) have their inner-workings extracted into `solutions-ai-tools/servers/` as images; only their orchestration artifact (power/action) stays in `solutions-os`.

### 6.5 Feature-packet wiring
Documentation/UX projects (Doc Genie, Spec→Slides, Kiro→FigJam, ERD) read from and write to the **feature packet** (`features/<feature>/`) rather than ad-hoc locations, so the unit of work stays coherent.

### 6.6 Shared knowledge as skills
Rule sets and references (a11y rules, SAIL grammar, Aurora, KB-maintenance checklist) become **skills** so multiple powers/agents reuse them instead of duplicating.

### 6.7 Branch consolidation
Projects currently living on `solutions-os` branches (Test Execution Agent on `dp-test-execution-agent`/`atlas-qe-forge`, Jarvis Assert on `expressionTestCases`, prototypes on `insuranceprototype`/`gam-suite`/`doccenter-integration-prototype`) are consolidated onto the restructured `main` in their target format. Prototype branches feed into the relevant product's feature packets.

---

## 7. Phased Migration Plan

The migration runs **after** the four target repos exist (per the Technical Implementation doc's Phases 1–2) and overlaps the `solutions-os` restructure (its Phase 3). Each phase has an exit criterion; legacy powers keep working until their replacement is verified (parallel operation).

### Phase A — Foundations & shared assets
- Stand up the skills first (they are dependencies of many powers): `a11y-audit` (#2), `kb-maintenance` (#17), plus `sail-reference` and `aurora-design-system`.
- Confirm the global tool images exist (intelligence, write, data-generator, deploy) so powers have something to reference.
- **Exit:** shared skills load; global tools resolve by name.

### Phase B — Core specialist powers (rename + decouple)
- Migrate the four standalone powers by rename + config-decouple: `developer`, `sql-forge` (#3), `ux-designer` (#6), `product-owner`, plus retain `feature-docgenie` (#15).
- **Exit:** the four powers run end-to-end with no bundled `mcp.json`; orchestrator can route to each by SDLC stage.

### Phase C — Power-actions folded into specialists
- Add the action-level projects into their host powers: Sweep (#10), Expression Tests (#20) → `developer`; DataForge (#4), SAIL→SQL (#14), ERD (#16) → `sql-forge`; FigJam (#7), SAIL Canvas (#9) → `ux-designer`; Spec→Slides (#8) → `product-owner`.
- **Exit:** each action is invocable within its host power and reads/writes the feature packet where relevant.

### Phase D — Sub-agents & event automation
- Stand up `qe-agent` (#19) and the `a11y-fixer` sub-agent wrapper (#1); register the KB-maintenance hook (#17).
- **Exit:** the orchestrator delegates QE and a11y workflows; release events trigger KB maintenance.

### Phase E — Tool servers & externals
- Land the tool inner-workings in `solutions-ai-tools`: `write`/a!migo (#13, incl. the MCP wrapper), `perf-profiler` CLI (#11), `sprint-report` CLI (#5), data-generator bulk path (#4).
- Reference externals in the manifest: Local-IDE (#12), SAIL Canvas app (#9), FigJam/Lucidchart/Google/Jira/Playwright.
- **Exit:** every tool image builds and is consumed by the relevant power/action; externals are documented and reachable.

### Phase F — Core structure & convergence
- Ensure T.I.M.E. (#18) is fully realized as feature packets + SDLC routing; consolidate branch-resident projects onto `main`.
- Validate all 20 against their acceptance criteria; retire legacy powers/branches.
- **Exit:** all 20 projects operate in their new format; no project depends on a legacy power or branch.

### Dependency notes
- Skills (Phase A) precede powers that consume them (B/C).
- The `write` server (Phase E, #13) is needed before write-dependent actions (Sweep #10, Assert #20, a11y-fixer #1) are fully functional — sequence E early or in parallel with C/D.
- Feature packets (Phase F core) should exist before doc/UX actions are validated end-to-end.

---

## 8. Risks & Validation

| Risk | Likelihood | Mitigation |
|---|---|---|
| Owners hesitant to relocate their project | Medium | Keep legacy working in parallel; migrate format without changing behavior; clear ownership via CODEOWNERS |
| a!migo→MCP wrapper is non-trivial (only true build task) | Medium | Use buildwithclaude as the reference; sequence early in Phase E; treat as its own work item |
| Power-actions bloat a single power's context | Medium | Keep action steering as on-demand (manual) inclusion; only the active action loads |
| Branch-resident projects drift before consolidation | Medium | Freeze feature work on those branches once their target format is ready; consolidate promptly (Phase F) |
| External tools (FigJam/Lucidchart) unavailable | Low | Actions degrade gracefully; outputs saved locally / to the feature packet |
| Duplicate capability across powers (e.g., data gen in sql-forge and qe-agent) | Medium | Single shared tool (data-generator) + shared skills; powers call, not re-implement |

### Per-project validation
Each project is "migrated" only when its **acceptance criterion** (Section 5) passes against the global tools with no bundled config. The program-level exit is the original success metric: every SWAT capability works in its new format, routed by the orchestrator, with zero powers carrying their own MCP config.

### Traceability
This plan maps 1:1 to Appendix A of `Solutions-OS-Revamp-Plan.md` (the approved 20-project inventory) and places each project into the architecture defined by `Solutions-OS-Technical-Implementation.md`.

---

*End of Document*
