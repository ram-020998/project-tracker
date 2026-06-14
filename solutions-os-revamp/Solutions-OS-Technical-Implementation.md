# Solutions OS — Technical Implementation Document

**Version:** 1.0 Draft
**Date:** June 14, 2026
**Author:** Ram
**Status:** For technical review (Principal Leads & Architects)
**Companion to:** `Solutions-OS-Revamp-Plan.md` (approved, Round 1)

---

## About This Document

This is the **technical "how"** that follows the approved Round-1 vision (`Solutions-OS-Revamp-Plan.md`). It is written for **principal leads and architects**. It deliberately stops short of file-level / code-level prescription — it does **not** specify what to write inside each source file. Instead it specifies:

- The **target repository topology** and how the pieces fit together.
- For **each repository and each major part**: what it is, what it does, which existing tool it is built from, and the details around it.
- A **single standard repository structure** that every repo in this program adheres to.
- The **advantages and the key decision** behind each structural choice.

Where this document references existing assets, those are real repositories that exist today; the program is greenfield (we build new under `appian/dev` + `appian/prod`) and leaves the existing repos in place as legacy/reference except where explicitly reused.

---

## Table of Contents

1. [Context Recap](#1-context-recap)
2. [Target Architecture at a Glance](#2-target-architecture-at-a-glance)
3. [Design Principles](#3-design-principles)
4. [Key Decisions Log](#4-key-decisions-log)
5. [Standard Repository Structure (applies to all repos)](#5-standard-repository-structure-applies-to-all-repos)
6. [Repository: solutions-os](#6-repository-solutions-os)
7. [Repository: solutions-ai-tools (the MCP/CLI monorepo)](#7-repository-solutions-ai-tools-the-mcpcli-monorepo)
8. [Repository: solutions-intelligence-kb](#8-repository-solutions-intelligence-kb)
9. [Reused Repository: solutions-atlas-parser](#9-reused-repository-solutions-atlas-parser)
10. [The Intelligence Server in Depth](#10-the-intelligence-server-in-depth)
11. [Read · Write · Deploy — Capability & Tool Mapping](#11-read--write--deploy--capability--tool-mapping)
12. [MCP vs CLI — Token-Efficiency Classification](#12-mcp-vs-cli--token-efficiency-classification)
13. [solutions-os Orchestration Layer in Depth](#13-solutions-os-orchestration-layer-in-depth)
14. [Bootstrap & Tool Consumption](#14-bootstrap--tool-consumption)
15. [dev → prod Flow, CI/CD, Registry & KB Pipeline](#15-dev--prod-flow-cicd-registry--kb-pipeline)
16. [End-to-End Flows](#16-end-to-end-flows)
17. [Phased Build & Rollout Plan](#17-phased-build--rollout-plan)
18. [Appendix A: Current-State Inventory](#appendix-a-current-state-inventory)
19. [Appendix B: Glossary & Naming](#appendix-b-glossary--naming)

---

## 1. Context Recap

Solutions OS is moving from a knowledge repository to a production-grade, AI-native SDLC platform for Appian Solutions teams. Round 1 approved four interconnected changes: a modular MCP architecture split by verb (Read · Write · Deploy), a single orchestrator agent, a global configuration bootstrap, and a repository restructure.

This document translates that vision into a concrete, buildable repository and deployment architecture. The central technical idea is a **clean separation between three concerns**:

1. **Knowledge & orchestration** — lives in `solutions-os` (the source of truth for product context, feature packets, and the AI orchestration layer of agents, powers, skills, and steering).
2. **Tool inner-workings** — leave `solutions-os` entirely and consolidate into a single tools monorepo (`solutions-ai-tools`), each tool shipping as its own Docker image.
3. **Generated application intelligence (the KB)** — lives in a dedicated data repository (`solutions-intelligence-kb`), produced by the (reused) parser and read by the intelligence server at runtime.

The problem this solves is **fragmentation**. The current ecosystem has multiple forks of the same tools (the Jarvis MCP exists in three places; the application KB exists in four; there are five forks of the buildwithclaude reference). Every structural decision in this document is made to eliminate that duplication and prevent it from recurring.

---

## 2. Target Architecture at a Glance

```
┌──────────────────────────────────────────────────────────────────────┐
│  solutions-os  (appian/dev + appian/prod)                              │
│  THE SOURCE OF TRUTH — knowledge + orchestration only, NO tool code    │
│                                                                        │
│  • Solution knowledge bases (LLM-friendly product context)            │
│  • Feature packets = the unit of work (spec, mockups, ADRs, status)   │
│  • Orchestration layer: Agents · Powers · Skills · Steering            │
│  • Integration config + setup.sh that consumes the tools below        │
│  • Discoverable across SDLC: Plan→Design→Build→Verify→Deploy→          │
│    Release→Support                                                     │
└───────────────┬────────────────────────────────────────────────────────┘
                │ consumes (Docker images pulled by setup.sh; tool contracts)
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  solutions-ai-tools  (appian/dev + appian/prod)                        │
│  ALL MCP/CLI SERVER SOURCE — one monorepo, one image per server        │
│                                                                        │
│  servers/intelligence/    → image: solutions-intelligence-mcp (READ)   │
│  servers/write/           → image: solutions-write-mcp                 │
│  servers/deploy/          → image: solutions-deploy-mcp                │
│  servers/data-generator/  → image: solutions-data-generator-mcp        │
│  servers/locust/          → image: solutions-locust-mcp                │
│  libs/ (shared)  ·  CODEOWNERS  ·  path-scoped CI                      │
└───────────────┬────────────────────────────────────────────────────────┘
                │ intelligence server reads KB at runtime
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  solutions-intelligence-kb  (appian/dev + appian/prod)                 │
│  GENERATED DATA ONLY — parsed Appian application intelligence (JSON)   │
│  data/<App>/ … · releases.json · sync script                           │
└───────────────▲────────────────────────────────────────────────────────┘
                │ scheduled CI writes KB
┌───────────────┴────────────────────────────────────────────────────────┐
│  solutions-atlas-parser  (REUSED — already in appian/prod)             │
│  zip → JSON engine. CI parses Appian package exports and pushes the    │
│  result into solutions-intelligence-kb.                                │
└──────────────────────────────────────────────────────────────────────────┘
```

**Four repositories, three roles:**

| Repo | Role | New or reused |
|---|---|---|
| `solutions-os` | Knowledge + orchestration (source of truth) | Evolve existing |
| `solutions-ai-tools` | All tool inner-workings (MCP/CLI servers) | **New** |
| `solutions-intelligence-kb` | Generated application KB (data) | **New** |
| `solutions-atlas-parser` | KB generation engine | **Reuse as-is** |

Everything new is created under both `appian/dev` and `appian/prod`, consistent with the existing `solutions-os` dual-remote convention.

---

## 3. Design Principles

These principles are the lens through which every structural decision was made. Each later section ties back to one or more of these.

1. **Separation by verb (Read · Write · Deploy).** Tools are grouped by what they *do* to an environment, not by who built them. The intelligence server only reads; writes go to the write server; deploys go to the deploy tool. This keeps the read path provably safe to expose to every agent.

2. **Knowledge separate from tools separate from data.** `solutions-os` holds knowledge and orchestration; `solutions-ai-tools` holds tool code; `solutions-intelligence-kb` holds generated data. The three have different change cadences, different access needs, and different audiences — so they are different repositories.

3. **Consolidate to prevent forks.** The dominant failure mode today is duplication (Jarvis ×3, KB ×4, buildwithclaude ×5). The architecture is biased toward single canonical homes and shared libraries.

4. **Tools are infrastructure, not power-scoped resources.** MCP/CLI servers are set up once, globally, and shared by every power, skill, and agent. Powers no longer bundle their own server configuration.

5. **Token efficiency.** Prefer CLIs over standing MCP servers where a capability is occasional or batch-style; reserve MCP for interactive, fine-grained tools. Control context inclusion deliberately (auto vs manual).

6. **Agent decides; server stays thin.** Where two data sources can answer the same question, the agent chooses via an explicit parameter and the server simply dispatches — the "intelligence about routing" lives in steering, not in server code.

7. **Greenfield, but reuse what already earns its place.** Build new under `appian/*` rather than migrating forks, but reuse mature, correctly-located assets (the parser) instead of rebuilding them.

8. **One standard repo structure.** Every repository in the program follows the same top-level conventions so that any architect can open any repo and immediately know where things are.

9. **Platform-agnostic knowledge.** The orchestration layer (powers/skills/steering) is expressed so it can be projected onto multiple AI surfaces (Kiro IDE today; Kiro CLI and Gemini later) via thin adapters, with no rewrite of the knowledge itself.

---

## 4. Key Decisions Log

This is the authoritative record of the decisions that shaped the architecture, with the rationale for each. Subsequent sections elaborate them.

| # | Decision | Rationale |
|---|---|---|
| D1 | **Single `solutions-intelligence-mcp` server** combining Atlas (Cloud) + Jarvis (Live) read capabilities | One read surface for all consumers; eliminates the Atlas/Jarvis read overlap |
| D2 | **Separate `solutions-intelligence-kb`** data repo for the application KB | KB is large, frequently/auto-refreshed, and its git history is a feature (release diffs); keeping it out of code repos isolates cadence and avoids bloat |
| D3 | **Reuse `solutions-atlas-parser`** as the generation engine | Mature, already in `appian/prod`, well-tested; no value in rebuilding |
| D4 | **Intelligence server is strictly read-only** | Lets it be exposed to every agent without guardrails; matches the existing read-token security model |
| D5 | **`evaluate_sail_expression` and `query_sql` live on the write side** | They require a live, write-capable connection; keeping them off the read server preserves the "read is 100% safe" guarantee |
| D6 | **All MCP/CLI server source in one monorepo `solutions-ai-tools`**, each server → its own Docker image | Directly counters fragmentation; shared libs written once; one CI; atomic cross-cutting changes; one place to enforce contracts |
| D7 | **No shared workspace; each `servers/<name>/` is self-contained** and builds its own image | Keeps images independent and build boundaries clean |
| D8 | **Unified tool namespace with a `source` parameter** (`auto\|cloud\|live`); default = available plane | One tool name (`get_app_overview`) instead of duplicated cloud/live variants; agent decides source; server stays a thin dispatcher |
| D9 | **Dynamic tool registration by configured plane** (Cloud-only with just a GitLab token) | Lowers the barrier: code intelligence works with no live Appian environment |
| D10 | **Powers remain primary (IDE-first); Agents accommodated** and can invoke powers | Most users are on the IDE; agents add CLI orchestration over the same shared knowledge |
| D11 | **SDLC stages (Plan→…→Support) are the orchestrator's routing taxonomy** | Capabilities are discovered by lifecycle position |
| D12 | **Feature packet = folder per feature** (spec, mockups, ADRs, status) | A concrete, travelling unit of work; no extra `knowledge-base/` nesting — the product folder *is* the knowledge base |
| D13 | **Suggested MCP-vs-CLI split** (intelligence/write/data-gen = MCP; deploy/locust/parser = CLI) | Token efficiency; proposed, to be validated in practice |
| D14 | **Manifest-driven `setup.sh`** with profiles + credential-sync hook; committed environment registry (URLs only) | One-command, idempotent onboarding; tools as global infrastructure |
| D15 | **`:latest` image tags everywhere (v1)**; **scheduled** KB refresh; **dev→prod dual-remote** for all repos | Simplicity for v1; consistent with existing `solutions-os` remotes |

---

## 5. Standard Repository Structure (applies to all repos)

Every repository in this program — `solutions-os`, `solutions-ai-tools`, `solutions-intelligence-kb`, and any future repo — adheres to the same top-level conventions. The goal is that an architect can open *any* repo and instantly know where governance, CI, docs, and ownership live, regardless of what the repo contains.

### 5.1 The standard top-level skeleton

```
<repo>/
├── README.md                 # What this repo is, what it does, how to run/consume it
├── CHANGELOG.md              # Human-readable history of notable changes
├── CODEOWNERS                # Who owns what (per directory)
├── .gitlab-ci.yml            # CI/CD pipeline (build, test, lint, publish)
├── .gitignore
├── docs/                     # Deeper documentation, diagrams, ADRs for this repo
│   └── adr/                  # Architecture Decision Records (repo-scoped)
├── .env.example              # Template for any required environment variables
└── <payload>/                # The repo's actual content (varies by repo role)
```

### 5.2 Rules that hold across all repos

| Rule | Why |
|---|---|
| **Dual remote**: `origin` → `appian/prod`, `dev` → `appian/dev` | Consistent dev→prod promotion everywhere |
| **`README.md` answers three questions**: what it is, what it does, how to consume it | Self-documenting; onboarding in minutes |
| **`CODEOWNERS` is mandatory** | Clear ownership even inside shared monorepos |
| **Secrets never committed** | `.env.example` shows shape; real values live in `.env` (gitignored) or the keychain |
| **Repo-scoped ADRs in `docs/adr/`** | Decisions live next to the code they govern |
| **CI is declarative and path-aware** | Only the affected part rebuilds |

### 5.3 How the "payload" differs by repo role

The `<payload>/` is the only part that varies. Each repo's payload is documented in its own section below:

- `solutions-os` payload = knowledge (`products/`) + orchestration (`ai-framework/`, `.kiro/`) + bootstrap.
- `solutions-ai-tools` payload = `servers/` + `libs/`.
- `solutions-intelligence-kb` payload = `data/` + `releases.json` + sync script.
- `solutions-atlas-parser` payload = the parser package (unchanged).

---

## 6. Repository: `solutions-os`

### 6.1 What it is

The **central source of truth** and the only repo most users ever clone. It contains **no tool source code**. It holds the knowledge that makes AI agents experts on our products, and the orchestration layer that drives them. It is the evolution of today's `solutions-os` (`appian/prod` 13490 / `appian/dev` 13491), restructured.

### 6.2 What it does

- Hosts each solution's **knowledge base** (LLM-friendly product context).
- Hosts **feature packets** — the unit of work that travels through the SDLC.
- Hosts the **orchestration layer**: Agents, Powers, Skills, Steering.
- **Consumes** the external tools (Docker images + CLIs) via a one-command bootstrap; it integrates with tools whose source lives elsewhere.
- Makes all capabilities **discoverable across the SDLC stages** (Plan → Design → Build → Verify → Deploy → Release → Support).

### 6.3 Built from

The existing `solutions-os` repository. Today it already carries `products/`, `ai-framework/`, `.kiro/`, `@DOCS/`, and `.gemini/`. The restructure (a) removes tool source that currently lives under `ai-framework/tools/` (Atlas KB, embedded Jarvis), (b) decouples MCP configuration from individual powers, and (c) formalizes feature packets and the SDLC taxonomy.

### 6.4 Structure

```
solutions-os/
├── README.md
├── setup.sh                          # one-command bootstrap (pulls images, wires config)
├── solutions-os.manifest.json        # single source of truth for what setup.sh installs
├── environments.json                 # environment registry (URLs only; creds elsewhere)
├── .env.example
│
├── .kiro/                            # workspace-level Kiro config (agents live here)
│   ├── agents/                       # orchestrator + specialist sub-agents
│   ├── settings/                     # generated global mcp.json target (by setup.sh)
│   └── steering/                     # global, always-on steering
│
├── ai-framework/                     # the orchestration layer (knowledge, not tool code)
│   ├── orchestrator/                 # orchestrator prompt, capabilities, routing rules
│   ├── powers/                       # IDE-first packaged workflows (no bundled mcp.json)
│   ├── skills/                       # on-demand reference knowledge, shared across agents
│   ├── agents/                       # sub-agent prompts
│   └── steering/                     # cross-cutting directives
│
├── products/                         # the solution knowledge bases + feature packets
│   └── <solution>/
│       ├── domain/                   # the solution's KB: personas, vision, overview, branding
│       ├── competitive-analysis/
│       ├── arch-decision-logs/       # product-level (cross-feature) ADRs
│       ├── steering/                 # product-level AI directives
│       └── features/
│           └── <feature>/            # FEATURE PACKET = unit of work
│               ├── spec.md
│               ├── mockups/
│               ├── adrs/             # feature-scoped ADRs
│               ├── design.md
│               └── status.md         # current SDLC stage
│
├── @DOCS/                            # shared governance
│   ├── schemas/                      # artifact schemas (deterministic outputs)
│   └── standards/                    # coding & engineering standards
│
└── .gemini/                          # future surface adapter (Gemini), parallel to .kiro
```

### 6.5 Key decisions for this structure

- **No tool code here (D6).** Everything under the old `ai-framework/tools/` (the Atlas KB data and the embedded Jarvis server) moves out. `ai-framework/` now means *orchestration knowledge*, not tool implementations. This is what makes `solutions-os` lightweight to clone and stable to maintain.
- **Powers stay primary, agents accommodated (D10).** `ai-framework/powers/` is the IDE-first surface; `.kiro/agents/` adds the orchestrator + sub-agents. An agent can invoke a sub-agent and have it use a specific power for an activity — so the two coexist rather than one replacing the other.
- **The product folder *is* the knowledge base (D12).** There is no `knowledge-base/` wrapper; `domain/` plus the feature packets constitute the LLM-friendly context. This matches the current `main` convention and avoids redundant nesting.
- **Feature packet = folder per feature (D12).** `features/<feature>/` bundles spec, mockups, ADRs, design, and a `status.md` that marks its SDLC stage. The orchestrator reads this to know what to do next.
- **Bootstrap and manifest live at the root.** `setup.sh` + `solutions-os.manifest.json` + `environments.json` make the repo self-installing and make "what's available" declarative.

### 6.6 Advantages

- Cloning `solutions-os` is fast and contains no megabytes of generated data or server code.
- The knowledge layer evolves independently of tool releases.
- A single, consistent place for any AI surface (Kiro powers/agents today, Gemini later) to find product context and orchestration.

---

## 7. Repository: `solutions-ai-tools` (the MCP/CLI monorepo)

### 7.1 What it is

A **single monorepo holding the source of every tool server** — the "inner workings" that the proposal says must live outside `solutions-os`. Each server is self-contained and builds into its own Docker image. This is a **new** repo under `appian/dev` + `appian/prod`.

### 7.2 What it does

- Houses all MCP and CLI server implementations in one place.
- Builds one **independent Docker image per server**, published to the GitLab container registry.
- Provides shared libraries (Appian client, auth, MCP-protocol helpers, logging) so common concerns are written once.
- Is the single place where the Read · Write · Deploy contracts are defined and enforced.

### 7.3 Why a monorepo (the key decision — D6/D7)

The single biggest risk this program fights is **fragmentation**: today the Jarvis MCP exists in three divergent copies, the KB in four, and the reference pattern in five. A per-server polyrepo layout quietly re-creates that problem — shared code (Appian auth, HTTP, JWT handling, MCP boilerplate) gets copy-pasted across repos and drifts. A monorepo writes those once in `libs/` and has every server import them.

- **All servers are the same shape** (Python, HTTP to Appian, MCP stdio, Docker) — the ideal monorepo case.
- **Cross-cutting changes are one PR** instead of N coordinated PRs.
- **One CI config**, path-scoped, so only the changed server rebuilds.
- **Ownership stays clear** via `CODEOWNERS` mapping each `servers/<name>/` to its maintainer.
- **No shared workspace (D7):** despite the monorepo, each `servers/<name>/` is independently buildable with its own dependency manifest and Dockerfile — images stay decoupled.

Polyrepo would only win if a server were externally owned/open-sourced or a different runtime; the one candidate (the deploy tool, based on an external open-source project) is handled by vendoring it in (see 7.4.3).

### 7.4 Structure

```
solutions-ai-tools/                  (appian/dev + appian/prod)
├── README.md
├── CODEOWNERS                        # per-server ownership
├── .gitlab-ci.yml                    # path-scoped matrix: build only changed server images
├── docs/
│   └── adr/
├── libs/                             # shared, single-source code
│   ├── appian-client/                # HTTP + auth (Basic / API-key / JWT)
│   ├── mcp-core/                     # base server, tool registration, graceful degradation
│   └── observability/                # logging, telemetry
└── servers/
    ├── intelligence/                 # → image: solutions-intelligence-mcp   (READ-ONLY)
    ├── write/                        # → image: solutions-write-mcp
    ├── deploy/                       # → image: solutions-deploy-mcp
    ├── data-generator/               # → image: solutions-data-generator-mcp
    └── locust/                       # → image: solutions-locust-mcp
```

Each `servers/<name>/` follows an identical internal shape (its own `Dockerfile`, dependency manifest, entry point, `tools/`, and tests) so the monorepo is uniform end-to-end.

### 7.4.1 `servers/intelligence/` → `solutions-intelligence-mcp` (READ-ONLY)

- **What it is:** the unified read server combining the Cloud Plane (versioned KB) and Live Plane (real-time environment) behind one tool namespace.
- **What it does:** answers "help me understand this application" — overview, search, code, dependencies, impact, data model, dead code, version history, clusters, patterns, semantic search.
- **Built from:** the **Atlas MCP server** (`solutions-atlas-mcp-server`, `appian/prod` 13476) for the Cloud Plane, plus the **read tools of the Jarvis MCP** (`somasundaram.d/jarvis-power`, 13473) for the Live Plane. The two are merged into one server with a unified namespace.
- **Detail:** see Section 10. Reads the KB from `solutions-intelligence-kb`; calls the JAI Appian app for live data.

### 7.4.2 `servers/write/` → `solutions-write-mcp`

- **What it is:** the canonical write surface — create/update design objects, evaluate SAIL, run SQL.
- **What it does:** all object mutation via Appian's OOTB LCP APIs; absorbs `evaluate_sail_expression` and `query_sql` (D5) and the two Jarvis write tools (`create_constant`, `preview_constant`).
- **Built from:** **`lcp-api` / a!migo** (`saurabh.sabat/lcp-api`, 13926), which already covers 237 operations. Note: a!migo is today a *library + ops dispatch module*, not an MCP server — so the build item here is an **MCP-server wrapper** around it (the buildwithclaude MCP server, `john.rogers/buildwithclaude`, is the reference for how LCP is exposed as MCP).
- **Detail:** this is the one place with a genuine "wrap an existing library as MCP" build task.

### 7.4.3 `servers/deploy/` → `solutions-deploy-mcp`

- **What it is:** package and deployment automation.
- **What it does:** create deployment packages, inspect contents, deploy to a target environment, check results, promote between environments.
- **Built from:** the open-source **Appian Deployment MCP** (Kelsey Ross, GitHub), **vendored into** this monorepo for full control and consistency, plus the Jarvis deployment/package handlers' behavior as a reference.
- **Suggested form:** CLI (see Section 12) — deployment is occasional/batch and does not need standing MCP tool schemas.

### 7.4.4 `servers/data-generator/` → `solutions-data-generator-mcp`

- **What it is:** test/demo data CRUD against a live environment.
- **What it does:** get record properties, create/update/delete/query records, list users, session tracking + rollback.
- **Built from:** the existing **`solutions-atlas-dg-mcp-server`** (`ramaswamy.u`, 13936) — already a clean standalone MCP server; brought in as a server package. It calls a separate "Atlas Data Generator" Appian app (a per-environment deployment dependency).

### 7.4.5 `servers/locust/` → `solutions-locust-mcp`

- **What it is:** performance-test (Locust) script generation.
- **What it does:** maps Appian flows to Locust tasks; generates runnable perf-test suites.
- **Built from:** the existing **`solutions-atlas-locust-mcp-server`** (`ramaswamy.u`, 14017).
- **Suggested form:** CLI (one-shot generation, large output).

### 7.5 Advantages

- One clone gives an engineer every tool's source and a uniform structure.
- Shared libraries make a new server cheap to add and impossible to drift.
- Independent images mean each tool deploys and versions on its own track despite the shared repo.
- A single contract boundary (Read vs Write vs Deploy) is visible and enforceable in one place.

---

## 8. Repository: `solutions-intelligence-kb`

### 8.1 What it is

A **data-only repository** holding the parsed Appian application intelligence (the "Atlas KB") — structured JSON per registered application. **New** under `appian/dev` + `appian/prod`. It contains no server code; it is read at runtime by the intelligence server's Cloud Plane.

### 8.2 What it does

- Stores, per application, the parser output: app overview, search index, self-contained bundles (with structure + SAIL code), per-object dependency files, and orphan/dead-code catalogs.
- Carries a `releases.json` manifest and a sync script that drives refresh.
- Serves as the **version history** for cross-release analysis — git diffs between commits *are* the changelogs that power `compare_releases` / `get_changelog`.

### 8.3 Built from

The current Atlas KB data, which today lives inside `solutions-os` (project 13490, under `ai-framework/tools/Atlas/solutions-kb/data`) and in several parallel copies (`ramaswamy.u/solutions-atlas-kb` 13671, `gam-knowledge-base` 13537). For greenfield we stand up one canonical KB repo and let the legacy copies remain as-is. The schema is exactly what `solutions-atlas-parser` already emits.

### 8.4 Structure

```
solutions-intelligence-kb/            (appian/dev + appian/prod)
├── README.md
├── .gitlab-ci.yml                    # (optional) validation of committed KB shape
├── releases.json                     # which apps/versions are present
├── sync_packages.py                  # refresh helper (invoked by the parser pipeline)
└── data/
    └── <ApplicationName>/
        ├── app_overview.json
        ├── search_index.json
        ├── bundles/<BundleName>/{structure.json, code.json}
        ├── objects/<uuid>.json
        └── orphans/{_index.json, <uuid>.json}
```

### 8.5 Key decisions for this structure (D2)

- **Data lives apart from code.** Frequent, automated, large KB refreshes never touch the server or knowledge repos, never trigger their CI, and never bloat their clone size.
- **The server reads it remotely.** The intelligence server already supports a remote KB via a project-id + path prefix; pointing it at this repo is configuration, not engineering. No image rebuild is needed when the KB refreshes.
- **Git history is intentional.** Keeping the KB in git (not a blob store) preserves the per-release diff that the multi-release tooling depends on.

### 8.6 Advantages

- Refresh cadence and access control are independent of the code.
- The intelligence server stays stateless with respect to data; scaling and caching are clean.
- A single canonical KB ends the current four-way fork.

---

## 9. Reused Repository: `solutions-atlas-parser`

### 9.1 What it is

The **KB generation engine** — a standalone Python library that parses Appian application package exports (ZIP of XML/XSD) into the structured, reference-resolved JSON consumed by the Cloud Plane. **Reused as-is**; it already lives in `appian/prod` (13475) and `appian/dev` (13480).

### 9.2 What it does

- Reads an Appian `.zip`, detects and parses 15 object types, resolves opaque identifiers (UUIDs, record-field URNs, translation URNs) to human-readable names, builds the dependency graph, generates self-contained functional bundles, and emits the JSON layout described in Section 8.4.

### 9.3 Built from

Itself — no changes. The only integration work is **pipeline wiring**: its CI is pointed at `solutions-intelligence-kb` as the output target instead of the in-`solutions-os` KB path.

### 9.4 Role in the architecture

```
Appian .zip exports ──▶ solutions-atlas-parser (CI, scheduled) ──▶ writes JSON ──▶ solutions-intelligence-kb ──▶ read by solutions-intelligence-mcp (Cloud Plane)
```

### 9.5 Key decision (D3)

Reuse over rebuild: the parser is mature, well-tested, stdlib-only, and correctly located in `appian/prod`. Rebuilding it greenfield would add risk and effort for no benefit. The only change is where it writes.

---

## 10. The Intelligence Server in Depth

### 10.1 Two planes, one server

`solutions-intelligence-mcp` exposes a single read namespace backed by two data sources:

| Plane | Source | Auth | Strengths |
|---|---|---|---|
| **Cloud Plane** | `solutions-intelligence-kb` (via GitLab API) | `GITLAB_TOKEN` + KB project id | versioned, multi-release, offline-capable, pre-computed graphs |
| **Live Plane** | JAI Appian app Web APIs | `APPIAN_ENV_URL` + `APPIAN_API_KEY` | real-time current state, semantic search, staleness |

### 10.2 Unified namespace with a `source` parameter (D8)

Instead of duplicated `cloud_*` / `jarvis_*` tools, there is **one tool per capability** (e.g., `get_app_overview`, `search_objects`, `get_dependencies`, `get_impact_analysis`, `get_data_model`, `list_dead_code`). Each accepts a **`source` parameter**:

- `source: auto` (default) → the server uses the available plane; if both are configured, a sensible default applies and the agent may override.
- `source: cloud` → force the versioned KB (history, offline, blast-radius).
- `source: live` → force the real-time environment (current state).

The **agent decides** which source to request; the *guidance* for when to prefer which lives in **steering**, not in server code (Principle 6). The server is therefore a **thin dispatcher**, not a complex rules engine.

### 10.3 Dynamic tool registration & graceful degradation (D9)

The server registers tools based on which planes are configured:

| Configured | Mode | Consequence |
|---|---|---|
| GitLab token only | **Cloud-only** | Full code intelligence with **no live environment**; works offline |
| Appian env only | **Live-only** | Real-time tools only |
| Both | **Full** | All tools; `source` routing active |
| Neither | **Refuses to start** | Clear configuration error |

The important outcome: a typical user who just wants code intelligence needs **only a GitLab token** — a dramatically lower barrier than today's Jarvis, which requires the JAI app deployed per environment.

### 10.4 The Live Plane dependency (must be captured)

The Live Plane is a **thin client over the JAI Appian application + Jarvis plugin**, which must be deployed to each target environment. Cloud Plane has no such dependency. The documentation and onboarding must make clear: Live tools are unavailable on environments without JAI; Cloud tools always work given a token and a populated KB.

### 10.5 Cloud–Live read overlap (the real consolidation)

The genuine merge effort is not stripping Jarvis (it is already ~90% read-only) — it is **unifying the overlapping read capabilities** that both Atlas and Jarvis provide (overview, search, get-object, dependencies, impact, data model, dead code). These collapse to one tool each, with `source` selecting the backing plane. Cloud-unique tools (release history, bundles, dependency paths, hub objects) and Live-unique tools (semantic search, clusters, patterns, staleness) remain as additive capabilities, registered only when their plane is available.

---

## 11. Read · Write · Deploy — Capability & Tool Mapping

This section makes the verb-based split concrete: where every capability lands.

### 11.1 READ → `solutions-intelligence-mcp`

| Capability (unified tool) | Cloud backing | Live backing |
|---|---|---|
| `get_app_overview` | Atlas KB | JAI app tree |
| `search_objects` | Atlas index | JAI search |
| `get_object_code` / `get_object_content` | Atlas snapshots | JAI live fetch |
| `get_dependencies` | Atlas graph | JAI dependency chain |
| `get_impact_analysis` | Atlas transitive graph | JAI impact analysis |
| `get_data_model` | Atlas schema | JAI data model |
| `list_dead_code` | Atlas orphans | JAI dead code |
| **Cloud-only:** `list_releases`, `compare_releases`, `get_changelog`, `get_object_history`, `get_object_at_release`, bundles, dependency paths, hub objects | Atlas | — |
| **Live-only:** semantic search, clusters, patterns, architecture, staleness, entry points | — | JAI |

### 11.2 WRITE → `solutions-write-mcp`

| Capability | Source of behavior |
|---|---|
| Create/update design objects (record types, fields, interfaces, rules, process models, constants, groups, …) | a!migo (237 ops) |
| `evaluate_sail_expression` | moved from Jarvis (D5) |
| `query_sql` | moved from Jarvis (D5) |
| `create_constant`, `preview_constant` | Jarvis write tools, absorbed |
| Data-model-from-sheet, bulk-rename workflows | a!migo workflows |

### 11.3 DEPLOY → `solutions-deploy-mcp`

| Capability | Source of behavior |
|---|---|
| Create package, inspect package, deploy, get results, promote | Appian Deployment MCP (vendored) + Jarvis deploy/package handlers as reference |

### 11.4 Supporting servers

| Server | Capabilities |
|---|---|
| `solutions-data-generator-mcp` | record CRUD, query, users, session + rollback |
| `solutions-locust-mcp` | perf-test generation (mapping, methods, navigation, templates, validation) |

### 11.5 What this mapping guarantees

- The **read server never mutates** anything (Principle 1 / D4).
- Every write or eval goes through **one** auditable surface.
- Deploy is isolated, so promotion logic is independent of authoring.

---

## 12. MCP vs CLI — Token-Efficiency Classification

### 12.1 The principle

A standing MCP server costs context tokens continuously — every registered tool's schema is in the model's context for the whole session. That cost is justified for **interactive, fine-grained, frequently-called** tools, and wasteful for **occasional, batch, one-shot** tools. The latter are better as **CLIs** the agent shells out to on demand, with zero standing schema cost.

### 12.2 Suggested classification (D13 — proposed, to validate in practice)

| Server | Form | Reasoning |
|---|---|---|
| **intelligence** (read) | **MCP** | called constantly, fine-grained, interactive |
| **write** (a!migo) | **MCP** | interactive object CRUD and evaluation |
| **data-generator** | **MCP** | interactive record CRUD during authoring/demo |
| **deploy** | **CLI** | occasional, batch; no need for standing schemas |
| **locust** (perf gen) | **CLI** | one-shot generation, large output |
| **parser** (KB refresh) | **CLI** | pipeline/occasional, not interactive |

### 12.3 Context inclusion policy

Beyond MCP-vs-CLI, control *when* knowledge enters context:

- **Always / auto** — global steering, the orchestrator's routing rules, the active power's steering.
- **Manual / on-demand** — skills (reference docs), CLI help text, large schemas — pulled only when the task needs them.

### 12.4 Why "suggested" rather than fixed

This split is a v1 recommendation. The exact line between MCP and CLI is best validated with real usage; the architecture supports either form per server without structural change (each is just a Docker image invoked differently). The classification is therefore presented as guidance to be tuned, not a hard contract.

---

## 13. solutions-os Orchestration Layer in Depth

### 13.1 The four primitives and how they relate

| Primitive | What it is | Lifespan | Lives in |
|---|---|---|---|
| **Steering** | always-on directives & routing guidance | persistent | `.kiro/steering/`, `ai-framework/steering/`, product `steering/` |
| **Skill** | on-demand reference knowledge, reusable across agents | loaded when relevant | `ai-framework/skills/` |
| **Power** | IDE-first packaged workflow (POWER.md + steering) | activated contextually | `ai-framework/powers/` |
| **Agent** | orchestrator + specialists that route & execute, calling tools | session | `.kiro/agents/` (+ prompts in `ai-framework/agents/`) |

**Relationship (D10):** Powers are primary because most users are on the IDE. Agents are accommodated as an additional orchestration layer over the *same* shared skills, steering, and tool contracts. The orchestrator agent can invoke a specialist sub-agent, and that sub-agent can in turn use a specific **power** to perform an activity. Powers no longer carry their own `mcp.json` — they reference tools that the bootstrap has already made globally available (Principle 4).

### 13.2 SDLC stages as the routing taxonomy (D11)

The orchestrator classifies a request to an SDLC stage, then to a specialist, then to tools:

| Stage | Specialist | Primary tools |
|---|---|---|
| **Plan** | product-owner | intelligence (read), KB, Jira |
| **Design** | ux-designer | intelligence, Aurora skill |
| **Build** | developer | intelligence, **write** |
| **Verify** | qe-agent | intelligence, data-generator, locust, playwright |
| **Deploy** | deploy flow | **deploy** |
| **Release** | product-owner / docgenie | intelligence, Google Workspace |
| **Support** | developer / a11y-fixer | intelligence, write |

This makes capability discovery a function of *where you are in the lifecycle*, which is how leads and teams already think about work.

### 13.3 Feature packet as the unit of work (D12)

A **feature packet** is `products/<solution>/features/<feature>/` containing `spec.md`, `mockups/`, `adrs/`, `design.md`, and `status.md`. The `status.md` (or an equivalent marker) records the current SDLC stage. The orchestrator uses this signal to know what to do next (e.g., a packet entering "Design" prompts prototype/UX work; entering "Build" prompts design-doc and implementation). Cross-feature decisions live in the product-level `arch-decision-logs/`; feature-scoped ones live in the packet's `adrs/`.

### 13.4 How the layer stays platform-agnostic (Principle 9)

The knowledge (skills, steering) and the tool **contracts** are platform-neutral. Each AI surface gets a **thin adapter**: Kiro powers/agents today (under `.kiro/` and `ai-framework/`), Gemini commands later (under `.gemini/`). Adding a surface means adding an adapter and a `setup-<platform>.sh`, not rewriting knowledge.

### 13.5 Advantages

- One body of knowledge serves IDE powers, CLI agents, and future surfaces.
- Lifecycle-aligned routing matches how teams operate and makes the orchestrator's behavior predictable.
- Feature packets give both humans and agents a single, inspectable unit of work with an explicit stage.

---

## 14. Bootstrap & Tool Consumption

### 14.1 The two-layer model

`solutions-os` holds no tool code, so it needs a clean way to *consume* the external tools. The bootstrap separates **infrastructure** from **knowledge** (Principle 4):

```
┌─ INFRASTRUCTURE (set up once, global, shared by all sessions) ────────┐
│  ~/.kiro/settings/mcp.json  ← written by setup.sh                      │
│  intelligence · write · data-generator (MCP)                          │
│  deploy · locust · parser (CLI, on PATH)                              │
│  + jira · playwright · google (supporting)                            │
└────────────────────────────────────────────────────────────────────────┘
┌─ KNOWLEDGE (symlinked from solutions-os, current after git pull) ─────┐
│  ~/.kiro/powers/   ~/.kiro/skills/   ~/.kiro/agents/   ~/.kiro/steering/│
└────────────────────────────────────────────────────────────────────────┘
```

Powers reference tools by name; the tools are already running globally. Adding a power = add a folder + one manifest line + re-run `setup.sh`. No per-power MCP config.

### 14.2 Manifest-driven installation (D14)

`solutions-os.manifest.json` is the single declarative source of truth for what `setup.sh` installs: the MCP/CLI images and their env keys, the powers/skills/agents/steering to symlink, and the install profiles. CI can validate that every path in the manifest exists.

### 14.3 `setup.sh` behavior

Idempotent, with lifecycle modes:

| Command | Action |
|---|---|
| `./setup.sh` | full install: preflight → pull images → write global `mcp.json` → symlink knowledge → verify |
| `./setup.sh --update` | after `git pull`: re-pull `:latest` images, re-symlink |
| `./setup.sh --verify` | health check (creds, images, symlinks) |
| `./setup.sh --uninstall` | clean removal of symlinks + MCP entries |
| `./setup.sh --profile engineering\|product\|minimal` | selective install |

### 14.4 Credentials & environment registry (D14)

- **Credentials:** `.env` (gitignored) holds tokens; `setup.sh` injects them into `mcp.json`. A **PostToolUse credential-sync hook** re-syncs when `.env` changes from inside the IDE, so password rotations don't require a manual re-run.
- **Environment registry:** `environments.json` (committed) lists environment **URLs** and which products live where; **credentials live separately** (gitignored / keychain). Agents resolve an environment by name; the Cloud Plane needs only a GitLab token, so most users never configure a live environment at all.

### 14.5 Why this is maintainable

Single source of truth (the manifest), no drift (symlinks track git), no orphans (clean uninstall), credential isolation (secrets only in `.env`), and one-command onboarding/offboarding.

---

## 15. dev → prod Flow, CI/CD, Registry & KB Pipeline

### 15.1 Dual-remote dev → prod (all repos — D15)

Every repo carries both remotes (`origin` → `appian/prod`, `dev` → `appian/dev`), matching today's `solutions-os`. Work is developed and tested against `dev` and promoted to `prod` on release. CI builds **dev images** from dev and **prod images** from prod.

```
registry.gitlab.appian-stratus.com/appian/dev/solutions-ai-tools/<server>:latest    # testing
registry.gitlab.appian-stratus.com/appian/prod/solutions-ai-tools/<server>:latest   # released
```

### 15.2 CI in `solutions-ai-tools` (path-scoped matrix)

One pipeline with `rules:changes`: a commit under `servers/write/**` builds **only** the write image. Per server: lint → test → docker build → push. Five independent image pipelines coexisting in one repo, so the monorepo never forces an all-servers rebuild.

### 15.3 Image tagging (D15)

`:latest` everywhere for v1 — simplest consumption; `setup.sh --update` always pulls the current image. (Semver pinning is a later hardening step if reproducibility becomes a requirement; the architecture does not depend on it.)

### 15.4 KB generation pipeline (D15 — scheduled)

```
[schedule] ─▶ solutions-atlas-parser CI ─▶ parse latest Appian .zip exports
           ─▶ emit JSON ─▶ commit/push to solutions-intelligence-kb
           ─▶ solutions-intelligence-mcp (Cloud Plane) reads new data at runtime
```

The refresh is **scheduled**. Because the KB is a separate data repo read at runtime, a refresh requires **no image rebuild** and never triggers the tool or knowledge repos' pipelines. The Live Plane covers anything newer than the last scheduled snapshot.

### 15.5 How it all connects at runtime

`solutions-os` (`setup.sh`) pulls the `:latest` server images and writes the global `mcp.json` → powers/agents call those tools → the intelligence image reads the KB repo and (optionally) the JAI app → writes go through the write image → deploys through the deploy CLI. No repo depends on another's internals; they connect only through **images, the KB data contract, and tool contracts**.

---

## 16. End-to-End Flows

### 16.1 A read request (most common path)

```
User: "How does evaluation scoring work in GSS?"
  └─▶ Orchestrator (solutions-os) classifies → Plan/Build, GSS
      └─▶ developer sub-agent (or atlas-developer power)
          └─▶ calls get_app_overview(source: auto) on solutions-intelligence-mcp
              ├─ Cloud Plane → reads solutions-intelligence-kb (versioned JSON)
              └─ (or Live Plane → JAI app, if source: live)
          └─▶ answers in 1–3 tool calls
```

### 16.2 A build/write request

```
User: "Add a 'riskScore' field to the Evaluation record type."
  └─▶ Orchestrator → Build → developer
      └─▶ get_data_model(source: cloud)  [read, intelligence-mcp]
      └─▶ create/update field           [write, solutions-write-mcp → LCP API]
      └─▶ evaluate_sail_expression       [write server, not read server]
```

### 16.3 KB refresh (scheduled, no human in loop)

```
[nightly schedule] ─▶ solutions-atlas-parser CI ─▶ parse new .zip exports
                   ─▶ push JSON to solutions-intelligence-kb
                   ─▶ next read with source: cloud reflects the refresh (no rebuild)
```

### 16.4 Onboarding a new user

```
git clone solutions-os ─▶ edit .env (GITLAB_TOKEN) ─▶ ./setup.sh
  ─▶ images pulled, global mcp.json written, powers/skills/agents symlinked
  ─▶ open IDE ─▶ Cloud-only intelligence works immediately (no live env needed)
```

---

## 17. Phased Build & Rollout Plan

The architecture is delivered incrementally, each phase with a clear exit criterion. No big-bang cutover; legacy repos remain untouched until their replacements are verified.

### Phase 1 — Foundations: KB repo + Intelligence server
- Stand up `solutions-intelligence-kb` (dev+prod); point the reused parser's CI at it; enable the scheduled refresh.
- Create `solutions-ai-tools` with `libs/` + `servers/intelligence/`; merge Atlas Cloud + Jarvis read tools into the unified namespace with the `source` parameter and dynamic registration.
- **Exit:** `solutions-intelligence-mcp:latest` serves Cloud-only reads with just a GitLab token; full mode works when a JAI env is configured.

### Phase 2 — The rest of the tool monorepo
- Add `servers/write/` (wrap a!migo as MCP, absorb eval/SQL), `servers/deploy/` (vendor the deployment MCP, CLI form), `servers/data-generator/` and `servers/locust/` (bring in existing servers).
- Path-scoped CI publishing all images to dev+prod registries.
- **Exit:** every capability has a home image; read/write/deploy contracts are enforced.

### Phase 3 — solutions-os restructure + bootstrap
- Move tool code out of `ai-framework/tools/`; introduce `ai-framework/orchestrator/`, `agents/`, `skills/`; convert/retain powers without bundled `mcp.json`.
- Author `solutions-os.manifest.json`, `environments.json`, and `setup.sh` (with profiles + credential-sync hook).
- Formalize feature packets and the SDLC routing taxonomy.
- **Exit:** `git clone solutions-os && ./setup.sh` yields a working environment; no power carries its own MCP config.

### Phase 4 — Adoption & convergence
- Onboard teams to the orchestrator + powers; validate the SWAT-a-Palooza capability set against the new homes.
- Validate the suggested MCP-vs-CLI split in real use; tune.
- **Exit:** teams operate on the new platform; the four-repo topology is the working norm.

---

## Appendix A: Current-State Inventory

Captured live from GitLab for traceability (the program is greenfield; these are sources of behavior / provenance, not migration targets).

| Asset | Location (ID) | Role / provenance |
|---|---|---|
| solutions-os | `appian/prod` 13490 / `appian/dev` 13491 | evolves into the source-of-truth repo |
| Atlas parser | `appian/prod` 13475 / `appian/dev` 13480 | **reused** as `solutions-atlas-parser` |
| Atlas MCP (Cloud) | `appian/prod/solutions-atlas-mcp-server` 13476 | basis for `servers/intelligence/` Cloud Plane |
| Jarvis MCP (Live) | `somasundaram.d/jarvis-power` 13473 | basis for `servers/intelligence/` Live Plane (read tools) |
| Jarvis MCP fork | `khoa.nguyen/jarvis-power` 13910 | divergent fork (not canonical) |
| Jarvis (Reflex dashboard) | `appian/prod/jarvis` 13407 | **unrelated** product (release visibility); name collision only |
| a!migo / LCP client | `saurabh.sabat/lcp-api` 13926 | basis for `servers/write/` (needs MCP wrapper) |
| buildwithclaude | `john.rogers/buildwithclaude` 13896 (+4 forks) | reference for setup.sh pattern and LCP-as-MCP exposure |
| Data Generator MCP | `ramaswamy.u/solutions-atlas-dg-mcp-server` 13936 | basis for `servers/data-generator/` |
| Locust MCP | `ramaswamy.u/solutions-atlas-locust-mcp-server` 14017 | basis for `servers/locust/` |
| Atlas KB (data) | `solutions-os` 13490 path · `ramaswamy.u/solutions-atlas-kb` 13671 · `gam-knowledge-base` 13537 · stale `appian/*/solutions-atlas-kb` 13477/13478 | sources for the consolidated `solutions-intelligence-kb` |
| Deployment MCP | external (GitHub, Kelsey Ross) | vendored into `servers/deploy/` |

**Fragmentation observed (the problem being solved):** Jarvis MCP exists in 3 copies; the application KB in 4; the buildwithclaude reference in 5.

---

## Appendix B: Glossary & Naming

| Term | Meaning |
|---|---|
| **Cloud Plane** | Versioned, offline-capable application intelligence served from `solutions-intelligence-kb` (formerly "Atlas") |
| **Live Plane** | Real-time application intelligence served from the JAI Appian app (formerly "Jarvis," read-only subset) |
| **Intelligence Server** | `solutions-intelligence-mcp` — the unified read server combining both planes |
| **a!migo** | The LCP-API-based write capability; basis for `solutions-write-mcp` |
| **JAI** | Jarvis Application Intelligence — the Appian-side app the Live Plane depends on |
| **Feature packet** | `products/<solution>/features/<feature>/` — the unit of work (spec, mockups, ADRs, design, status) |
| **Power** | IDE-first packaged AI workflow (primary surface) |
| **Agent** | Orchestrator + specialist sub-agents (additional orchestration layer) |
| **Skill** | On-demand reference knowledge shared across agents |
| **Steering** | Always-on directives and routing guidance |
| **SDLC stages** | Plan · Design · Build · Verify · Deploy · Release · Support — the orchestrator's routing taxonomy |
| **Naming principle** | Components are named for what they *do*, not for codenames or who built them |

---

*End of Document*
