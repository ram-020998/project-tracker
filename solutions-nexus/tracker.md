# Solutions Nexus — Project Tracker

## Overview
Building a Tauri desktop application ("Solutions Nexus") that serves as a Kiro-powered development workbench for Appian Solutions teams. The app provides a visual UI layer on top of the `solutions-os` GitLab repo, enabling guided AI workflows (spec creation, UX design, tech design, testing) without requiring users to work directly in the terminal with Kiro CLI.

## Status
**Phase: Exploration & Architecture Design** — Deep analysis of solutions-os repo structure complete. Tauri app architecture mapped. Ready to define MVP scope and begin scaffolding.

## Session Log

### 2026-05-03 — Deep exploration of solutions-os + Tauri architecture mapping

#### Completed
- Moved exploration notes from `/Users/ramaswamy.u/repo/kiro-workbench-exploration/exploration-notes.md` to `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-nexus/exploration-notes.md`
- Created `solutions-nexus` folder at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-nexus/`
- Deep exploration of entire `solutions-os` repo at `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os/`
- Mapped all solutions-os structures and workflows to 7 Tauri app flows

#### Prior Exploration (2026-04-29, from exploration-notes.md)
- Analyzed Warp terminal open-source codebase (Rust, 60+ crates, custom GPU-accelerated UI) — concluded building a terminal emulator is 2+ years of work, wrong approach
- Rejected terminal emulator concept in favor of document-centric workbench
- Analyzed ProductOS (existing internal tool by Josh Linder & Charles Tsui) — React + AWS Amplify + Bedrock AgentCore + Aurora PostgreSQL + Google Docs
- Compared ProductOS (database-driven/cloud) vs. proposed Kiro Workbench (git-driven/local-first)
- Identified git-native architecture using solutions-os as the data layer

#### Decisions Made
- **Build new rather than extend ProductOS** — Fundamentally different data models (git+markdown vs. PostgreSQL+Google Docs), Kiro CLI is local-first, solutions-os AI framework (steering/powers) has no equivalent in ProductOS
- **Use Tauri for desktop app** — Rust backend handles git ops, file watching, Kiro CLI process spawning natively; small binary (~10MB); local-first by design; frontend is still just React/Svelte
- **Git-native architecture** — solutions-os repo IS the data layer; no database migration needed; git history = audit trail; zero infrastructure cost
- **Name: Solutions Nexus** — Working project name for the workbench

#### Learnings

##### solutions-os Repo Structure (4 layers)
1. **AI Framework** (`ai-framework/`) — 4 powers with Action Router dispatch:
   - `atlas-developer` (Engineering): SAIL code, UUIDs, dependency trees, impact analysis, code review
   - `sail-reference` (Engineering): SAIL grammar, best practices (no MCP, reference-only)
   - `atlas-product-owner` (Product): Business-language Atlas data, feature specs, release reviews
   - `atlas-ux-designer` (Product): HTML/Sailwind prototypes, SAIL interface generation, publish to Vercel
2. **Products** (`products/`) — 3 areas:
   - Case Management Studio (very mature: 6 domain docs, 3 features, prototypes, full Appian source 1800+ objects)
   - ProcureSight (early stage: cross-reference docs + steering only)
   - GAM Solutions (suite with 8 children, only personas + PSE cross-references populated)
3. **Governance** (`.kiro/`, `@DOCS/`) — Git workflow steering, one detailed spec (sealed-core-prototype), @DOCS scaffolded but empty
4. **Context Inheritance** — Suite-level domain flows to children; cross-product references link standalone ↔ suite variants

##### Action Router Pattern (key for UI workflow buttons)
Each power's POWER.md has an Action Router table mapping user intent → steering files. Example: "What does X do?" → `action-explore`, "Write a spec" → `action-feature-spec`. This maps directly to UI workflow buttons in the Tauri app.

##### Atlas Knowledge Base
- `tools/Atlas/solutions-kb/data/` has 15 Appian apps with structured JSON (manifests, objects, SAIL code, dependency graphs, search indexes, changelogs)
- Synced via CI pipeline (`sync_packages.py` + `.gitlab-ci-sync.yml`) pulling from Appian API
- MCP server runs as Docker container (stdio transport), reads from GitLab project 13490

##### Jarvis (separate from Atlas)
- Connects to live Appian environment (not static data)
- Pre-computed KB inside Appian via Java plugin
- SQL queries, SAIL evaluation, package creation, pipeline monitoring
- 5 main workflows: Explore, Spike Research, Design Document, Code Review, Pipeline Check

##### Spec Workflow Pattern
- `.kiro/specs/<name>/` with `.config.kiro` (UUID, workflow type), `requirements.md`, `design.md`, `tasks.md`
- Requirements-first: gather context → generate requirements → review → generate design → review → generate tasks
- The sealed-core-prototype spec is a production-quality example (11 requirements, 37K design doc, 10 task groups)

##### Git Workflow Governance
- `.kiro/steering/git-workflow.md` defines strict rules: branch from `prod/main`, push to `dev` only, `<type>/<short-description>` naming, warn on >40 files, present MR URL after push

##### Product Maturity
| Product | Domain | Features | Prototypes | Appian Source | Overall |
|---------|--------|----------|------------|---------------|---------|
| CMS | Rich (6 docs) | 3 features | 6 artifacts | Full app + prototype | Very Mature |
| ProcureSight | Minimal | Empty | N/A | Empty | Early Stage |
| GAM Suite | Personas only | Empty | N/A | Empty | Scaffolded |

#### Architecture: 7 Tauri App Flows Identified

1. **Product Explorer** — Read `products/`, detect suite vs. standalone (presence of `solutions/` subdir), build navigable tree with document counts and maturity indicators
2. **AI-Powered Workflows** — Map Action Router patterns to UI buttons per role (PO: onboard, explore, spec, release review, impact analysis, research; Engineer: explore, design doc, impact analysis, code review, tech debt; UX: HTML prototype, Sailwind prototype, SAIL interface, publish)
3. **Spec Management** — Create/browse/edit specs under `.kiro/specs/`, track requirements → design → tasks progression, render markdown with checkboxes
4. **Atlas KB Browser** — Browse 15 apps' structured JSON, drill into objects/dependencies/code, view changelogs, trigger sync
5. **Document Viewer/Editor** — Markdown rendering + editing, HTML prototype preview, JSON viewer, git diff view
6. **Git Operations** — Branch management, commit with diff preview, push to `dev`, MR URL display, sync from `prod/main` — all governed by git-workflow steering
7. **Context-Aware Kiro Chat** — Auto-load domain docs + steering + Atlas KB based on current navigation position; spawn `kiro-cli` with correct working directory and power

#### Issues Encountered
- solutions-os repo location was at `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os/` (not the initially assumed path)
- `@DOCS/` (schemas, standards) and `.gemini/commands/` are scaffolded but empty — app should handle gracefully
- 7 of 8 GAM child solutions are empty scaffolds — app needs to show maturity/completeness indicators

#### Remaining Items
- [ ] Define MVP scope (recommended: Product Explorer + "Write Feature Spec" workflow + Atlas KB Browser + Git status/commit)
- [ ] Choose frontend framework (React vs. Svelte)
- [ ] Scaffold Tauri project in `solutions-nexus/`
- [ ] Build repo structure parser (Rust: detect suite vs. standalone, enumerate products/features/domain docs)
- [ ] Implement Kiro CLI process spawning with correct working directory + power loading
- [ ] Design IPC command surface between frontend and Rust backend
- [ ] Implement markdown rendering + editing in frontend
- [ ] Implement git operations layer (using `git2` crate or shelling out to git CLI)
- [ ] Implement file watcher for live reload on solutions-os changes
- [ ] Design context-loading logic (which domain docs + steering to auto-load per navigation position)
- [ ] Evaluate MCP server management (Atlas Docker container lifecycle)
- [ ] Decide how to handle Jarvis integration (live environment access from desktop app)

#### Reference Links & Paths
- **solutions-nexus working folder:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-nexus/`
- **solutions-os repo:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os/`
- **Exploration notes:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-nexus/exploration-notes.md`
- **ProductOS (existing):** https://main.d1rsz9k1ewt2u4.amplifyapp.com/
- **ProductOS repo:** https://gitlab.appian-stratus.com/josh.linder/product-os-app
- **Warp terminal (reference):** https://github.com/warpdotdev/warp
- **Atlas MCP Docker image:** `registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-mcp-server/solutions-atlas-mcp-server:latest`
- **Jarvis Docker image:** `registry.gitlab.appian-stratus.com/appian/prod/solutions-os/jarvis:latest`
- **Atlas KB GitLab project ID:** 13490

---
