# 21 — Solutions Copilot: Final Summary & Accomplishments

**Status:** Capstone summary · **Audience:** stakeholders, new joiners, leadership · **Last updated:** 2026-07-02

> The single-document overview of the Solutions Copilot program — what it is, why we built it, what
> we achieved, the hard technical problems we solved, and where it stands. For depth, each section
> points to the authoritative doc (01–20). For the running build log see **doc 18**; for handoff
> detail see **doc 11**.

---

## 1. Executive summary

**Solutions Copilot** replaces the legacy `solutions-os` "powers" toolkit with a modern, standards-based
**Agents + Skills** platform for Appian Solutions teams, delivered privately through a **Kiro IDE
extension** (the installer / command center) that fetches everything from GitLab.

In this program we:

- **Migrated the entire `solutions-os` capability set losslessly** into **6 role agents**, **4 MCP-owning
  sub-agents**, and a shared skill library — **~35,900 lines** of source workflow preserved **verbatim**
  across **105 reference files**, with **74** carrying a delegation protocol.
- **Built a production-grade installer extension** (v0.10.0) — a scope-aware, manifest-driven,
  OOP-architected dashboard that installs/updates agents, captures MCP secrets, manages an environment
  registry, and verifies the setup — **with no manual file editing**.
- **Solved the core delivery problem** that blocked the whole model: getting MCP servers to actually
  reach spawned sub-agents in the Kiro IDE (the `mcp.json` fix), then **validated it end-to-end** with a
  live `developer → atlas-intel → knowledge base` query and a working **Jira** integration.

**Bottom line:** the Agents + Skills product is **structurally complete and installable**, the read path
is **live-validated**, and the remaining work is live validation of the write/deploy paths, a few
installer hardening items, and (deferred) orchestration.

---

## 2. Project overview

### 2.1 The problem
Legacy `solutions-os` bundled capabilities as monolithic "powers," each with its own embedded MCP
configuration and sprawling steering. This didn't scale: powers duplicated logic across branches, mixed
knowledge with tool code, and put dozens of heavy MCP tool schemas into every session — degrading the
model's tool selection and bloating context.

### 2.2 The solution
A three-layer model built on standard Kiro primitives (see **doc 02**, **doc 03**):

1. **Role agents** — the specialists a user picks (Developer, Tester, Product Owner, UX Designer, DevOps,
   Documentation). Each is defined by a system prompt + linked skills, carries the `subagent` tool, and
   **holds no heavy MCP** — keeping it lean.
2. **MCP sub-agents** — dedicated agents that own the heavy servers (Atlas ~30 tools, Jarvis ~42, Data
   Generator, and an Integrations agent for Jira/Google/Playwright). Role agents **delegate** to them, so
   large tool schemas stay isolated from the role's context.
3. **Shared knowledge** — skills reused across roles (SAIL reference, a11y, etc.) plus always-on steering.

This is grounded in Anthropic's multi-agent guidance (an agent with 20+ tools degrades at tool selection;
decompose by context boundaries, not by problem type) and verified against official Kiro documentation.

### 2.3 Scope discipline (what we deliberately did *not* do)
Per the approved subset (**doc 01**): **keep Atlas and Jarvis MCP separate** (defer the merge), **defer
the orchestrator**, and adopt **Agents + Skills with no "powers."** These deferrals de-risked the program
and unblocked everything else.

---

## 3. Key decisions (the foundation)

| # | Decision | Why it mattered |
|---|---|---|
| 1 | Keep Atlas + Jarvis MCP **separate** | Removed the highest-coordination, highest-risk dependency. |
| 2 | **Agents + Skills, no powers** | Modern, portable (open Agent Skills spec), scales cleanly. |
| 3 | **New repo** for tooling; `solutions-os` → docs only | Clean separation of product vs. knowledge. |
| 4 | **Six role agents** | One specialist per role; each owns its slice end-to-end. |
| 5 | **Dedicated MCP sub-agents** | Context protection + tool specialization. |
| 6 | **Both surfaces** (CLI + IDE) | Meets users where they work. |
| 7 | **Orchestrator deferred** | Avoids the "telephone game" anti-pattern until steps are proven. |
| 8 | **Lossless migration** | Every legacy artifact is traced; nothing paraphrased away. |

Full rationale and the follow-on decisions (`jarvis-smt`→Developer, `jarvis-verify`→Tester, dedicated
`data-generator`, ERD→Documentation, a11y-fix→Developer, CLI tools deferred) are in **doc 01** and the
traceability matrix **doc 09**.

---

## 4. What we built — the product

### 4.1 Agents (6 roles + 4 sub-agents, all loading on CLI and IDE)

| Agent | Kind | Role |
|---|---|---|
| `developer` | role | Appian engineering across the lifecycle — explore, build, refactor, test-gen, DB scripts, a11y, review, design docs. |
| `tester` | role | Quality engineering — TEA end-to-end testing, unit/AC verification, test-data generation, a11y audits. |
| `product-owner` | role | Product & planning — onboarding, feature specs, inventories, cross-app analysis, impact, release notes, research, chat triage. |
| `ux-designer` | role | Design-to-build — Aurora/branding/consistency & a11y audits, decomposition, prototypes, SAIL generation, dev handoff. |
| `devops` | role | Ship safely — pipeline checks, package management, deploy, promote across environments. |
| `documentation` | role | Evidence-grounded docs — FIPs, tech designs, ADRs, perf/security reviews, architecture overviews, ERDs. |
| `atlas-intel` | sub-agent | Owns the Atlas (Cloud KB) MCP — read-only code intelligence. |
| `jarvis-intel` | sub-agent | Owns the Jarvis (live env) MCP — read + write/eval/deploy. |
| `data-generator` | sub-agent | Owns the Data Generator MCP — record/test data CRUD. |
| `integrations` | sub-agent | Jira (via `jira-mcp-proxy`) · Google Workspace (not wired) · Playwright. |

Each agent ships as **two files** — a CLI `.json` and an IDE v3 `-prompt.md` (the dual-surface
requirement, **doc 02 §2.1 / doc 11 §5.1**).

### 4.2 Skills (the capabilities, one purpose each)

- **Developer (15):** appian-explore, impact-analysis, technical-debt, code-review, design-document,
  implementation, implementation-summary, feature-breakdown, spike-research, refactor-redeploy,
  expression-test-generation, knowledge-query, i18n, a11y-fix, database-script-management.
- **Tester (3):** test-execution (TEA), unit-test, test-data-generation.
- **Product Owner (9):** onboarding, explore, feature-inventory, feature-spec, research,
  cross-app-analysis, feature-impact-analysis, release-review, chat-triage.
- **UX Designer (10):** aurora-compliance, branding-compliance, design-consistency-review,
  edge-case-analysis, component-decomposition, platform-feasibility-check, create-html-prototype,
  create-sailwind-prototype, generate-sail, design-to-dev-handoff.
- **DevOps (4):** pipeline-check, package-management, deployment, promote.
- **Documentation (7):** doc-fip, doc-tech-design, doc-adr, doc-perf-review, doc-security-review,
  doc-arch-overview, generate-erd.
- **Shared (5):** sail-reference, sail-code-hygiene, sail-documentation-standards, a11y-audit,
  guide-appian-docs.

### 4.3 The lossless-migration achievement
The defining engineering constraint was **"lose nothing."** Rather than paraphrasing 800–1000+ line
workflows (which silently drops behavior), we:

1. Copied each source workflow **verbatim** into the skill's `references/` via `git show`.
2. Prepended a **Delegation Protocol** header to every tool-bearing reference (redirecting direct MCP
   calls to the owning sub-agent — the "skills never call MCP directly" principle).
3. Wrote a **thin `SKILL.md`** orchestrator (frontmatter + which references to load + a tooling-adaptation
   note), consolidating multiple sources as **modes**.

**Result:** ~35,900 lines preserved verbatim across 105 references (74 with the protocol), every
`solutions-os` inventory item traced to a target in **doc 09**, with a documented reason for every drop.

---

## 5. What we built — the installer / command center

A private Kiro IDE extension (`installer/`, v0.10.0) that turns "clone + hand-edit JSON" into a guided,
verifiable experience (design **doc 13**, plan **doc 14**, dashboard **doc 16**, architecture **doc 17**,
UX standards **doc 20**).

**Capabilities:**
- **Runtime fetch from GitLab** at a configurable ref (zero runtime dependencies; Node built-ins only).
- **Scope-aware** (Workspace vs. Global) install, inventory, and status.
- **Manifest-driven catalog** — agents are self-describing (titles, summaries, profiles); **adding a new
  agent requires only manifest + repo changes, no extension code change** (verified by test).
- **MCP secrets** captured once and substituted into a generated `.kiro/settings/mcp.json` (mode `0600`,
  gitignored) — behind a `SecretProvider` seam so a keychain backend is a one-line swap.
- **Environment registry** — a labeled, secret-free `environments.json` the agents read by label at
  runtime, plus generated steering.
- **Verification** — health checks for token, Docker, MCP launch, file drift, and secret completeness.

**Architecture:** a clean layered, OOP design — Preact webview → thin `ConfigPanel` controller → 8
single-responsibility services (DI) → pure `core/` + `infra/`. The webview is a **token-based design
system** with a decomposed component library and a strict typed message protocol (doc 20). **12 headless
tests pass**; host + webview both typecheck.

---

## 6. Hard problems we solved (and how)

These are the load-bearing lessons — the difference between "looks configured" and "actually works"
(full detail in **doc 11 §6**).

1. **Dual-surface agent loading.** The CLI reads `.json`; the IDE reads a Markdown file with **v3 YAML
   frontmatter** — different schemas. Symptom: agents silently didn't appear in the IDE. Fix: every agent
   ships both files; frontmatter uses block-style `mcpServers`, `tools`/`permissions` (not
   `allowedTools`/`toolsSettings`), and exactly two `---` delimiters.

2. **MCP servers didn't reach spawned sub-agents (the big one).** Symptom: `developer → atlas-intel`
   returned "unreachable" and fell back to file reads, even though running `atlas-intel` *directly*
   worked. **Root cause (verified via the IDE `mcp.log`):** MCP servers **embedded** in an agent's
   `mcpServers` block start only when that agent is run directly — **not** when it's spawned as a
   sub-agent. Only servers declared in **`.kiro/settings/mcp.json`** reach spawned sub-agents. **Fix:**
   declare the heavy servers in `mcp.json`; sub-agents set `includeMcpJson: true` with scoped `tools`;
   role agents stay `includeMcpJson: false`; the installer generates `mcp.json` from a committed
   `mcp.json.template`. This preserved the architecture — only *where the server is declared* changed.

3. **A new `.vsix` doesn't take effect until the window is reloaded.** Symptom: after installing v0.10.0
   the `settings/` folder wasn't created — because the still-running previous extension host did the
   install. Fix/process: **always reload after `--install-extension`**, then verify the log shows
   `Wrote settings/mcp.json (N MCP servers)`.

4. **The Jira MCP was a placeholder that never started.** Symptom: `integrations` reached `@playwright`
   fine but had no `@jira` tools. Cause: the template used a non-existent npm package. **Fix:** switched
   to the working **`jira-mcp-proxy` Docker image** (env `JIRA_URL`/`JIRA_EMAIL`/`JIRA_TOKEN`). Google
   Workspace has no verified server and is explicitly marked not-wired.

5. **Skills that called MCP directly / condensed workflows.** Early drafts broke the "lose nothing" and
   "delegate, don't call" rules. Fixed by the verbatim-reference + Delegation-Protocol pattern (§4.3).

---

## 7. Outcomes & current status

| Area | Status |
|---|---|
| Role agents (6) + sub-agents (4) | ✅ **Complete** — all built, structurally validated, load on CLI + IDE. |
| Lossless migration (doc 09 matrix) | ✅ **Complete** — every inventory item traced; ~35,900 lines preserved. |
| Installer extension | ✅ **v0.10.0 packaged** — scope-aware dashboard, manifest-driven, 12/12 tests. |
| MCP delivery to sub-agents | ✅ **Solved & live-validated** — `mcp.json` model; `developer → atlas-intel → KB` works. |
| Jira integration | ✅ **Working** via `jira-mcp-proxy`. |
| End-to-end install (reload + workspace) | ✅ **Validated** — fresh workspace install generates `mcp.json` and the read path works. |
| Live write/deploy paths (jarvis-intel, data-generator) | ⏳ **Pending validation** — needs live creds + Docker. |
| Installer Global-scope safety (merge-on-write) | 🅿️ **Backlog (BL-4)** — Global install overwrites an existing `mcp.json`; use Workspace scope meanwhile. |
| Google Workspace MCP | 🅿️ **Not wired** — no verified public server; export steps stubbed. |
| `setup.sh` global install | ⏳ **Not done** — largely superseded by the installer. |
| Workflows / orchestration | 🅿️ **Deferred** (doc 19) — blocked on agent hardening + agent-driven Appian object creation. |
| CI/CD pipeline (doc 15) | 📋 **Designed, not implemented** — ready-to-use `.gitlab-ci.yml`, scheduled for hardening. |

**Net:** the product is installable and the read path is proven live. Remaining work is validation of the
live write/deploy paths, installer hardening, and the deferred orchestration layer.

---

## 8. Outcomes for users (what this enables)

- **Pick a specialist and go.** A user opens the Developer (or Tester, PO, UX, DevOps, Documentation)
  agent and gets a capability menu; skills auto-activate by request.
- **Lean, accurate agents.** Heavy tool schemas stay behind sub-agents, so role agents reason well and
  cite real objects (results come from sub-agent delegation, never invented).
- **One-time, no-hand-editing setup.** The installer captures secrets once, generates all config, and
  verifies the environment — onboarding is a guided flow, not a JSON-editing chore.
- **Push updates easily.** Runtime fetch + ref pinning + update detection; updates preserve secrets and
  the environment registry.
- **Private and portable.** GitLab-only distribution; the same `.kiro/` artifacts work on CLI and IDE via
  the open Agent Skills format.

---

## 9. What's next (prioritized)

1. **Live-validate the write/deploy paths** — `jarvis-intel`, `data-generator`, `integrations` with real
   creds + Docker (the read path is already proven).
2. **Installer merge-on-write (BL-4)** — make Global installs safe (merge into an existing `mcp.json`
   instead of overwriting).
3. **CI/CD pipeline (doc 15)** — build the `.vsix` on push, publish on tag; add the bootstrap installer.
4. **Keychain provider** — swap plaintext secrets for the macOS keychain behind the existing
   `SecretProvider` seam.
5. **Dashboard depth** — per-object update diff, per-agent activity attribution, managed-agent overlays.
6. **(Deferred) Workflows / orchestration** — revisit once steps are hardened and agent-driven Appian
   object creation is solved (doc 19).

---

## 10. Artifact & document map

**Working repo** — `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot`
- `.kiro/agents/<name>.{json,-prompt.md}` — the 6 roles + 4 sub-agents (dual-surface).
- `.kiro/skills/<role|shared>/<skill>/SKILL.md (+references/)` — the capabilities (verbatim sources).
- `.kiro/steering/*.md` — source-routing, naming, acli-usage, environments.
- `.kiro/settings/mcp.json.template` — committed template the installer resolves into `mcp.json`.
- `solutions-copilot.manifest.json` — the single install/catalog contract.
- `installer/` — the Kiro IDE extension (Preact webview + OOP host services), v0.10.0.

**Tracker repo (docs)** — `/Users/ramaswamy.u/repo/project-tracker/solutions-copilot`
- **01** decisions · **02** Kiro primitives · **03** architecture · **04** repo structure · **05** skill
  standard · **06** migration methodology · **07** sequencing · **08** inventory · **09** traceability
  matrix · **10** backlog · **11** implementation status & handoff (*read first*) · **12** build-a-role
  runbook · **13** config-app design · **14** config-app implementation plan · **15** GitLab CI/CD · **16**
  dashboard/command center · **17** installer architecture & review · **18** build tracker · **19**
  workflows (deferred) · **20** dashboard UX standards · **21** this final summary.

---

## 11. In one paragraph (for a slide)

Solutions Copilot migrated the entire `solutions-os` toolkit into a modern **Agents + Skills** platform —
**6 role agents**, **4 MCP-owning sub-agents**, and a shared skill library, with **~35,900 lines of
workflow preserved verbatim** and every legacy artifact traced. It ships through a **manifest-driven Kiro
IDE installer** (v0.10.0) that sets up agents, secrets, and environments with **no manual file editing**.
We solved the core problem of getting MCP servers to spawned sub-agents (the `.kiro/settings/mcp.json`
model) and **validated the developer-agent knowledge-base path live**, plus a working Jira integration.
The product is **complete and installable**; what remains is live validation of the write/deploy paths, a
few installer hardening items, and the deliberately deferred orchestration layer.
