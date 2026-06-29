# 18 — Build Tracker & Accomplishments (everything to date)

**Purpose:** a complete, self-contained record of everything built and decided so far across the
Solutions Copilot program — the agents/skills migration AND the configuration/dashboard extension.
Read this to get fully caught up without reconstructing from individual docs.

**Last updated:** 2026-06-26 · **Installer version:** v0.7.0

---

## 0. The three repositories
| Repo | Path | Role |
|---|---|---|
| **Working repo** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot` | The product: `.kiro/` agents+skills+steering AND the **`installer/`** Kiro extension. |
| **Tracker (this)** | `/Users/ramaswamy.u/repo/project-tracker/solutions-copilot` | Docs only (this folder, docs 01–18). |
| **Legacy source** | `gitlab.appian-stratus.com:appian/solutions-os` | Migrate FROM (powers across branches). |

GitLab: `gitlab.appian-stratus.com`, project `ramaswamy.u/solutions-copilot` (private). Registry:
`registry.gitlab.appian-stratus.com`. Single auth: `GITLAB_TOKEN`.

---

## 1. What we have accomplished (top line)
1. **Program design & migration plan** (docs 01–12): approved Agents+Skills model, lossless
   migration methodology, full inventory + traceability matrix of `solutions-os`.
2. **Developer role COMPLETE** in `.kiro/`: 15 developer skills + 3 shared skills (~19.7k lines of
   source preserved verbatim) + 3 sub-agents (atlas-intel, jarvis-intel, integrations). Loads on CLI
   and IDE.
3. **A private Kiro extension** (`installer/`) that evolved from a one-shot installer into a full,
   scope-aware **command center / dashboard** with install, MCP-secrets, environment registry,
   custom authoring, updates, and recent activity — built to a **standard, modular, OOP** architecture.
4. **Design docs 13–17** specifying the config app, dashboard, CI/CD, and architecture/review.

---

## 2. The agents/skills product (`.kiro/`) — current state
- **Role agents:** `developer`, `tester`, `product-owner`, `ux-designer`, `devops`, `documentation` — **all 6 complete**.
- **Sub-agents:** `atlas-intel` (read-only Atlas KB), `jarvis-intel` (live + write/deploy),
  `data-generator` (live test/demo data CRUD + rollback), `integrations` (Jira · Google · Playwright).
- **Developer skills (15):** appian-explore, impact-analysis, technical-debt, code-review,
  design-document, implementation, implementation-summary, feature-breakdown, spike-research,
  refactor-redeploy, expression-test-generation, knowledge-query, i18n, a11y-fix,
  database-script-management.
- **Tester skills (3):** test-execution (TEA), unit-test (←jarvis-verify), test-data-generation
  (sql-forge pipeline).
- **Product-owner skills (9):** onboarding, explore, feature-inventory, feature-spec, research,
  cross-app-analysis, feature-impact-analysis, release-review, chat-triage (←ChatTriage).
- **UX-designer skills (10):** aurora-compliance, branding-compliance (←Jarvis), design-consistency-review,
  edge-case-analysis, component-decomposition, platform-feasibility-check, create-html-prototype,
  create-sailwind-prototype, generate-sail, design-to-dev-handoff.
- **DevOps skills (4):** pipeline-check (←Jarvis pipeline-check-workflow), package-management, deployment,
  promote (last three authored over Jarvis deploy/package handlers).
- **Documentation skills (7):** doc-fip, doc-tech-design, doc-adr, doc-perf-review, doc-security-review,
  doc-arch-overview (←feature-docgenie), generate-erd (←erd-generator; Lucid diagram step not wired).
- **Shared skills (5):** sail-reference, sail-code-hygiene, sail-documentation-standards, a11y-audit,
  guide-appian-docs.
- **Conventions:** dual-surface agents (`.json` for CLI + `-prompt.md` v3 frontmatter for IDE);
  lossless skill migration (verbatim source in `references/` + Delegation Protocol); skills never
  call MCP directly — they delegate to sub-agents.

---

## 3. The extension (`installer/`) — version history
| Ver | Delivered |
|---|---|
| 0.1.0 | POC installer: single-page webview, GitLab runtime fetch, install developer role into target `.kiro`, `.env` bridge. |
| 0.1.1 | Status-bar entry point. |
| 0.1.2 | **Activity-bar view** + lowered engine to `^1.74` (fixed silent non-activation in Kiro). |
| 0.2.0 | **Rewrite:** esbuild + Preact webview; `core`/`app`/`infra` split; 7-step wizard; selectable install-location cards; headless test suite. |
| 0.3.0 | **Dashboard foundation:** scope selector (Workspace/Global), installed-inventory reader, per-scope lockfile, recent-activity feed (reads `~/.kiro/sessions`), nav sections. |
| 0.4.0 | UX feedback 1–7: auto-connect with stored token; MCP **connection cards** w/ edit; per-agent secret filtering; **catalog profile cards** + install preview; activity global; only-our-agents filter. |
| 0.4.1 | Show session **id** instead of an Open button. |
| 0.5.0 | **Custom authoring** (point 8): create custom agents; add new/existing skills; add custom MCP servers; tracked in `custom.json`; shown tagged "custom"; survives updates via `applyCustom()`. |
| 0.6.0 | **Code review + refactor:** decomposed god-class into 8 DI **services**; **manifest-driven** secret/global classification (removed hardcoded var lists); manifest agent metadata surfaced. |
| 0.7.0 | **UX redesign:** dropped three-pane → two-pane; Agents = card grid + full-width drill-in detail; consistent toolbars/alignment; **fixed** custom-skill display (new + linked existing). |

---

## 4. Architecture (standard, modular, OOP)
```
webview/ (Preact) ──postMessage──▶ app/ConfigPanel (controller) ──▶ services/ (OOP, DI) ──▶ core/ (pure) + infra/ (fs/os)
```
- **`core/`** (vscode-free, unit-tested): `gitlab`, `manifest` (+ classification helpers),
  `planner`, `generator` (secret substitution), `secretFields`, `secretProvider` (PlaintextProvider),
  `registry`, `steering`, `inventory`, `lockfile`, `sessions`, `dashboard`, `authoring`, `paths`.
- **`infra/`**: `writer` (file writes, 0600 on agent configs, `.gitignore`).
- **`services/`** (classes, dependency-injected; composition root in `ConfigPanel`):
  `Settings`, `ScopeService`, `SecretsService`, `ConnectionService`, `EnvironmentService`,
  `InstallService`, `DashboardService`, `AuthoringService`.
- **`app/ConfigPanel`**: thin controller — owns webview + routes messages; no business logic.
- **`webview/`**: Preact app (`app.tsx`, `main.tsx`, `vscode.ts`) ↔ host via typed protocol
  (`src/messages.ts`).
- **Build:** host `tsc` → `out/` (zero runtime deps, Node built-ins only); webview esbuild →
  `media/dist/main.js`. Packaged with `vsce --no-dependencies`.

---

## 5. Feature inventory (implemented)
- **Connect & persist:** GitLab token stored once (PlaintextProvider); **auto-connect** on open.
- **Scope-aware:** Workspace (default when a folder is open) vs Global dropdown; drives inventory,
  install, activity.
- **Overview:** installed count, update badge, recent-activity feed (session id + cwd).
- **Agents:** card grid → full-width detail (skills installed/available, status, recent interactions,
  configure secrets). Only agents we maintain (manifest ∪ lockfile); custom agents tagged.
- **Catalog/Add:** profile cards with descriptions + custom selection; install preview; installs to
  the active scope.
- **MCP Connections:** per-server **cards** with Edit → secret fields (masked); per-agent filtering;
  manifest-driven secret/global/non-secret classification.
- **Environments:** labeled reference-data registry (CRUD), delivered to `.kiro/environments.json`
  + generated `steering/environments.md`; rejects secret-looking fields.
- **Custom authoring:** create custom agent; add new/existing skill; add custom MCP server; marked
  custom; survives updates.
- **Status:** health checks (token, manifest, MCP secrets).
- **Updates:** coarse (lockfile `ref` vs latest tag).
- **Secret → MCP:** plaintext store (`secrets.json`, 0600, gitignored) substituted into generated
  agent configs; `SecretProvider` seam for the keychain roadmap.

---

## 6. Key decisions (locked)
**Program (doc 01):** Agents+Skills only (no powers); Atlas/Jarvis kept separate; orchestrator
deferred; lossless migration; both surfaces.
**Config app (doc 13):** D1 keychain = macOS `security` (roadmap); D2 **Preact+esbuild**; D3 no
launcher in v1 (substitution); D4 per-request multi-env via registry-by-label read; D5 local registry;
D6 URLs are non-secret registry fields; D7 **plaintext secrets now, keychain on roadmap** behind
`SecretProvider`.
**Dashboard (doc 16):** DB1 interaction **metadata only**; DB2 CLI sessions first; DB3 scope default =
Workspace when a folder is open; DB4 multi-root = first folder v1; DB5 per-agent attribution after a
session-format spike.
**Architecture (doc 17):** manifest is the single declarative source → **adding a new agent needs no
extension code changes.**

---

## 7. Modularity contract — add a new agent (no code change)
1. Add to the **manifest** in GitLab: `agents.roles`/`agents.intelligence`, `skills.<role>`, optional
   `agentMeta[name]={title,summary}`.
2. New MCP → add `mcp.<server>` with `owner`, `envKeys`, `secretKeys`/`publicKeys`; shared vars →
   `globalEnvKeys`.
3. Commit the agent's `.kiro/agents/<name>.{json,-prompt.md}` (+ skills) to the repo.

On next connect the dashboard lists it, shows skills, derives correctly-classified MCP secret cards,
installs it (sub-agents auto-resolved), and tracks updates. Proven by `test/classification.test.js`.

---

## 8. Tests (11 headless, `npm test`)
manifest parse/catalog/env-keys · **manifest-driven classification** (new agent) · secret fields +
resolution · mcp cards · generator substitution (no leftover `${VAR}`) · registry validation + CRUD
(rejects secrets) · writer placement/0600/gitignore · inventory reader · lockfile roundtrip · dashboard
assembler (incl. foreign-agent exclusion + custom agents) · custom authoring (files, marker, scaffold,
link, mcp add, applyCustom idempotence). Plus host `tsc` compile + webview typecheck.

---

## 9. Generated/runtime files (per scope)
- `~/.kiro/.solutions-copilot/secrets.json` (0600) — secret vault (global).
- `<kiroDir>/.solutions-copilot/installed.lock.json` — install provenance.
- `<kiroDir>/.solutions-copilot/custom.json` — custom registry.
- `<kiroDir>/environments.json` + `<kiroDir>/steering/environments.md` — env registry + steering.
- `<kiroDir>/agents/*.{json,-prompt.md}`, `skills/**` — installed (secrets substituted; gitignored).

---

## 10. Private distribution & CI (doc 15 — not yet implemented)
- `.gitlab-ci.yml`: validate → test → package → publish `.vsix` to GitLab **Release** + Generic
  Package Registry on `v*` tags, via `CI_JOB_TOKEN`. Bootstrap one-liner installs latest.
- Prereqs: a CI runner on the project; commit `installer/package-lock.json`.

---

## 11. Tracker docs index
01 decisions · 02 Kiro primitives · 03 architecture · 04 repo structure · 05 skill standard ·
06 migration methodology · 07 sequencing · 08 inventory · 09 traceability matrix · 10 backlog ·
11 handoff · 12 runbook · **13 config-app design** · **14 config-app implementation plan** ·
**15 GitLab CI/CD** · **16 dashboard/command center** · **17 installer architecture & review** ·
**18 this build tracker.**

---

## 12. What's NOT done (prioritized next)
1. **Remaining role agents** (tester, ux-designer, product-owner, devops, documentation) + the
   `data-generator` sub-agent (use doc 12 runbook).
2. **Managed-agent overlays** — add custom skills/MCP to built-in agents, surviving update-regen.
3. **Per-object update diff** (git-blob-sha vs GitLab tree ids) — doc 16 H2; "what changed" view.
4. **Per-agent activity attribution** (locate the agent field in session data); IDE sessions.
5. **CI/CD pipeline** (doc 15) + bootstrap installer script.
6. **Keychain provider** (roadmap) — swap `PlaintextProvider` → macOS `security` behind `SecretProvider`.
7. **JSON Schemas (ajv)** for manifest/registry/secrets/lockfile + schema validation in CI.
8. **Live end-to-end validation** of jarvis-intel/integrations (needs creds + Docker).
9. Nothing is committed/pushed yet in the working repo (per session).

---

## 13. Build / install / test (quick reference)
```bash
cd /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot/installer
npm install
npm run build            # tsc host + esbuild webview
npm run typecheck:webview
npm test                 # 11 headless tests
npm run package          # -> solutions-copilot.vsix (prod build + vsce)
kiro --install-extension solutions-copilot.vsix --force   # then reload Kiro
# open: activity-bar "Solutions Copilot" → Open Configuration (or 🚀 status bar)
```
