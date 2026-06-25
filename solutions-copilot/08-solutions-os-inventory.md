# 08 — solutions-os Inventory (all branches)

**Captured:** 2026-06-25 via `git ls-tree` / `git diff` against `origin/main` and `dev/*` (no checkout).
**Excluded from line-item detail:** `ai-framework/tools/Atlas/solutions-kb/data/**` (thousands of generated KB JSON files — this is *data*, handled as one row INV-ATLAS-KBDATA) and `.playwright-mcp/**` (transient logs) and `**/node_modules/**` (prototype deps).

Legend — Current form: PWR=power, AGT=agent, MCP=mcp server source, CFG=mcp/config, HOOK=hook,
STG=steering, TOOLCI=tool CI/shell, DATA=generated data, DOC=product knowledge/prototype.

## A. Engineering powers (`ai-framework/Engineering/.kiro/powers/`)

| ID | Asset | Branch(es) | Form | Contents |
|---|---|---|---|---|
| INV-E01 | `atlas-developer` | main (+most) | PWR | POWER.md, mcp.json, README, .kiro/steering.md; steering/: action-explore, action-impact-analysis, action-design-document, action-code-review, action-technical-debt, tool-reference |
| INV-E02 | `atlas-sql-forge` | main | PWR | POWER.md, mcp.json, README, .kiro/steering.md; steering/: action-explore-schema, action-generate-data, action-query-and-validate, action-bulk-sql, action-erd, action-rollback, step-0..6, step-6-generate-sql, tool-reference-atlas, tool-reference-data-generator |
| INV-E03 | `atlas-demo-driver` | main | PWR | POWER.md, mcp.json, README, .kiro/steering.md; steering/: action-generate-data, action-query-and-validate, action-rollback, step-0..6, tool-reference-atlas, tool-reference-data-generator |
| INV-E04 | `feature-docgenie` | main | PWR | POWER.md, README, scripts/fix_table_borders.py; steering/: workflow-fip, workflow-tech-design, workflow-perf-review, workflow-security-review, workflow-arch-overview, workflow-adr; templates/ (md + docx/), styles/document.css |
| INV-E05 | `sail-reference` | main | PWR | POWER.md, README; steering/: sail-grammar, sail-common-functions, sail-common-mistakes, appian-design-best-practices, appian-accessibility-guide |
| INV-E06 | `atlas-dev-documentation` | dp-test-execution-agent, atlas-qe-forge, expressionTestCases, jarvisRefactorRedeploy, add-landing-page-feature, shared-playwright-deploy, new-branch (branch-only; not on main) | PWR | POWER.md, mcp.json, README, .kiro/steering.md; steering/: atlas-usage, google-workspace-cli, workflow-adr/-arch-overview/-fip/-perf-review/-security-review/-tech-design (overlaps INV-E04) |

## B. Product powers (`ai-framework/Product/.kiro/powers/`)

| ID | Asset | Branch(es) | Form | Contents |
|---|---|---|---|---|
| INV-P01 | `atlas-product-owner` | main | PWR | POWER.md, mcp.json, README, .kiro/steering.md; steering/: action-explore, action-feature-inventory, action-feature-spec, action-cross-app-analysis, action-impact-analysis, action-onboarding, action-release-review, action-research, action-technical-debt, guide-appian-docs |
| INV-P02 | `atlas-ux-designer` | main (+most) | PWR | POWER.md, mcp.json, README, .kiro/steering.md; steering/: action-aurora-compliance-check, action-component-decomposition, action-create-html-prototype, action-create-sailwind-prototype, action-design-consistency-review, action-design-to-dev-handoff, action-edge-case-analysis, action-generate-sail, action-platform-feasibility-check |

## C. Tools (`ai-framework/tools/`) — power + (sometimes) server source

| ID | Asset | Branch | Form | Contents |
|---|---|---|---|---|
| INV-T01 | `Jarvis` | main | PWR+MCP | jarvis-power/POWER.md + 20 steering: appian-best-practices-checklist, branding-compliance, code-review-workflow, design-doc-workflow, expression-test-generation, feature-breakdown-workflow, implementation-summary-workflow, implementation-workflow, jarvis-menu, knowledge-query-workflow, pipeline-check-workflow, refactor-redeploy-workflow, refactor-step-translation, refactor-step-utility-substitution, sail-code-hygiene, sail-documentation-standards, spike-research-workflow, t-retriever-navigation, workspace-rules. **server/** = Python MCP source (analyzer, handlers/, creators/, templates/, Dockerfile, pyproject, tests). mcp.json.template, sites.json.template, .gitlab-ci-jarvis.yml, README |
| INV-T02 | `Atlas` | main | CFG+DATA | README; solutions-kb/: .gitlab-ci-sync.yml, releases.json, sync_packages.py, sync_pipeline.sh (parser pipeline) + **data/** (generated KB — see INV-DATA01) |
| INV-T03 | `A11yAudit` | main | PWR | a11y-audit-power/POWER.md + steering: a11y-audit-workflow, a11y-doc-output-format, a11y-gchat-kb, a11y-gchat-response-policy, a11y-jira-patterns, a11y-jira-validation-workflow, a11y-menu, a11y-sail-rules, a11y-sail-rules-proposed; mcp.json.template, README |
| INV-T04 | `ChatTriage` | main | PWR+HOOK | chat-triage-power/POWER.md + steering: chat-triage-workflow, deduplication-strategy, response-policy; hook.json, README |
| INV-T05 | `erd-generator` | main | PWR | POWER.md + steering: generate-erd, simple-erd-all-tables, sql-release-lookup |
| INV-T06 | `Jarvis-A11yFixer` | main | PWR | jarvis-a11y-fixer-power/POWER.md + steering: a11y-fix-patterns, a11y-fixer-workflow, a11y-verification, a11y-xml-rules, playwright-appian-helper; appian-env.template, README |
| INV-T07 | `jarvis-i18n` | main | PWR | jarvis-i18n-power/POWER.md + steering: i18n-audit-workflow, i18n-create-workflow, i18n-lookup-workflow, i18n-reference |
| INV-T08 | `jarvis-smt` | main | PWR(+MCP?) | jarvis-smt-power/POWER.md + steering: db-admin-workflow, db-config-workflow, db-explore-workflow, db-script-workflow, db-status-workflow, smt-reference (DB/SMT management) |
| INV-T09 | `jarvis-verify` | main | PWR | jarvis-verify-power/POWER.md + steering: verify-data-setup, verify-reference, verify-workflow; verify-credentials.template, README |
| INV-T10 | `QE-Agent` | dp-test-execution-agent | TOOLCI | .gitlab-ci-qe-agent.yml, README (CI/tool shell for the QE agent) |

## D. Agents & QE config (branch dp-test-execution-agent)

| ID | Asset | Branch | Form | Contents |
|---|---|---|---|---|
| INV-A01 | `.kiro/agents/qe-agent.md` | dp-test-execution-agent | AGT | The Test Execution Agent definition (existing agent — closest precedent for the Tester role) |
| INV-A02 | QE steering | dp-test-execution-agent | STG | `.kiro/steering/`: QE_Agent_Steering_File, qe-environments, qe-knowledge-base-GSS, atlas-tools-steering, atlas-data-generator |
| INV-A03 | `ai-framework/mcp-configs/qe-agent-mcp.json` | dp-test-execution-agent | CFG | MCP wiring for the QE agent |

## E. Global config & governance (`main`)

| ID | Asset | Form | Contents |
|---|---|---|---|
| INV-G01 | `.kiro/hooks/chat-triage.kiro.hook` | HOOK | Chat triage hook |
| INV-G02 | `.kiro/steering/` | STG | acli-usage, erd-power-routing, git-workflow, gws-usage |
| INV-G03 | `.kiro/specs/sealed-core-prototype` | DOC | A Kiro spec (prototype) |
| INV-G04 | `ai-framework/mcp-configs/` | CFG | atlas-mcp.json, README |
| INV-G05 | `@DOCS/standards/` | DOC | coding-guidelines.md (empty), + (branch shared-playwright-deploy) component-plugin-conventions.md |
| INV-G06 | `ai-framework/{Engineering,Product}/steering/`, `.kiro/skills/`, `.kiro/hooks/` | — | empty `.gitkeep` placeholders |

## F. Branch-only tooling & experiments

| ID | Asset | Branch | Form | Contents |
|---|---|---|---|---|
| INV-B01 | `tools/playwright-deploy/` | shared-playwright-deploy | TOOLCI | deploy-plugins.spec.ts, package.json, playwright.config.ts, README (Playwright plugin-deploy automation) |
| INV-B02 | root `releases.json`, `sync_packages.py` | SI-1067 | CFG | parser-sync experiment at repo root |

## G. Product knowledge & prototypes (`products/`) — stays in solutions-os

| ID | Asset | Branch | Form | Contents |
|---|---|---|---|---|
| INV-K01 | `products/{synapse,procuresight,case-management-studio,insurance-underwriting,gam-solutions,doccenter}` | main | DOC | domain/, features/, steering/, competitive-analysis/, arch-decision-logs/, src-appian-atlas/ (note casing drift: insurance-underwriting uses Steering/Features/Specs) |
| INV-K02 | `products/gam-suite/.../acquisition-central-landing-page/prototype/` | gam-suite | DOC | React/Vite prototype (index.html, guidelines, node_modules) |
| INV-K03 | `products/insurance-underwriting/Features/doccenter-integration/prototype/*.html` | insuranceprototype, doccenter-integration-prototype | DOC | HTML prototypes (data-conflict-resolution, doc-versioning-config) |

## H. Generated data

| ID | Asset | Form | Note |
|---|---|---|---|
| INV-DATA01 | `ai-framework/tools/Atlas/solutions-kb/data/**` | DATA | Parser-generated Appian KB (per-app: app_overview, bundles, code, objects, graph, changelogs, enrichment). NOT a skill — this is the data the `atlas-intel` sub-agent reads. Belongs in a KB data store, not in solutions-copilot. |

## Notes / observations

- **Branch divergence is large.** Most dev branches *delete* the bulk of `main`'s tools (they were cut from older states) and add one or two things. The authoritative superset = `main` ∪ {`atlas-dev-documentation`, `qe-agent` + QE config, `QE-Agent`, `playwright-deploy`, prototypes}. Treat `main` as the baseline; pull only the branch-unique adds (INV-E06, INV-A01/02/03, INV-T10, INV-B01, INV-K02/03).
- **Jarvis is both a power and an MCP server** (Python source in `server/`). The power steering → skills; the server source → the `jarvis-intel` sub-agent's MCP (tool code, not a skill).
- **Heavy duplication** confirmed: doc workflows exist in both `feature-docgenie` (INV-E04) and `atlas-dev-documentation` (INV-E06); a11y exists as audit (INV-T03), fixer (INV-T06), and rules inside sail-reference (INV-E05). These consolidate to single skills in the matrix.
- **`jarvis-smt`** (DB admin) and **`jarvis-verify`** may be backed by their own MCPs — confirm during transform whether they need their own sub-agent or fold into existing ones.
