# 09 — Traceability Matrix (source → target)

Maps every inventory item (doc 08) to its destination in `solutions-copilot` (or "stays in
solutions-os"). **Rule:** every INV-* row appears here; nothing is dropped without a reason.
Status starts `pending`. Skill names are proposals (one purpose each), to be confirmed at transform.

Targets: **ROLE** = role agent · **SKILL(role|shared)** · **SUBAGENT** = MCP-owning sub-agent ·
**MCP** = server source (tool code) · **STEER** = steering · **HOOK** · **CLI/TOOL** · **DOC** = stays
in solutions-os · **DROP** (with reason) · **KBDATA** = intelligence KB data store.

## Role agents (entry points) — derived targets

| Role agent | Built from | Skills linked |
|---|---|---|
| `developer` | INV-E01, parts of INV-T01/T07, INV-T06, INV-T08 | explore, impact-analysis, design-document, code-review, technical-debt, implementation, implementation-summary, feature-breakdown, spike-research, refactor-redeploy, sail-to-sql, expression-test-generation, i18n-*, a11y-fix (←Jarvis-A11yFixer), database-script-management (←jarvis-smt) + shared |
| `tester` | INV-A01 (qe-agent = TEA), INV-T09, parts of INV-E02/T03 | test-execution (TEA), unit-test (←jarvis-verify), a11y-audit(shared), test-data-generation + shared |
| `ux-designer` | INV-P02 | aurora-compliance, component-decomposition, create-html-prototype, create-sailwind-prototype, design-consistency-review, design-to-dev-handoff, edge-case-analysis, generate-sail, platform-feasibility-check, branding-compliance + shared |
| `product-owner` | INV-P01, INV-T04 | feature-spec, feature-inventory, explore, cross-app-analysis, impact-analysis, onboarding, release-review, research, chat-triage + shared |
| `devops` | Jarvis deploy/package handlers, INV-T01 pipeline-check | deployment, package-management, promote, pipeline-check + shared |
| `documentation` | INV-E04 (feature-docgenie), INV-E06, INV-T05 (erd-generator) | doc-fip, doc-tech-design, doc-perf-review, doc-security-review, doc-arch-overview, doc-adr, generate-erd + shared |

## Sub-agents (MCP owners)

| Sub-agent | Built from | Form |
|---|---|---|
| `atlas-intel` | INV-G04 (atlas-mcp.json), INV-T02 (Atlas), reads INV-DATA01 | SUBAGENT + MCP config (read-only) |
| `jarvis-intel` | INV-T01 `Jarvis/server/**` (Python MCP source) | SUBAGENT + MCP source |
| `data-generator` | data-gen MCP referenced by INV-E02/E03 tool-reference-data-generator | SUBAGENT (dedicated — decision 2026-06-25) |

> `jarvis-smt` and `jarvis-verify` need **no** sub-agent of their own — both explicitly have no MCP
> and delegate to `jarvis-intel` (SQL/eval) and, for verify, Playwright.

## Detailed mapping

| INV ID | Source | Target | Destination (solutions-copilot) | Status | Notes |
|---|---|---|---|---|---|
| INV-E01 | atlas-developer | SKILL(developer) ×5 | skills/developer/{explore,impact-analysis,design-document,code-review,technical-debt} | pending | mcp.json → DROP; tool-reference → delegate to atlas-intel/jarvis-intel (STEER) |
| INV-E02 | atlas-sql-forge | SKILL(developer/tester) | skills/developer/{explore-schema,sail-to-sql}, skills/tester/{test-data-generation,query-validate,rollback,bulk-data} | pending | 6-step flow → one `test-data-generation` workflow skill; mcp.json → DROP; uses data-generator |
| INV-E03 | atlas-demo-driver | DROP | — | dropped | decision 2026-06-25: no demo-driver capability |
| INV-E04 | feature-docgenie | SKILL(documentation) ×6 | skills/documentation/{doc-fip,doc-tech-design,doc-perf-review,doc-security-review,doc-arch-overview,doc-adr} | pending | own **documentation** role; templates/docx → skill `references/`; scripts/fix_table_borders.py → **DEFER** (CLI util) |
| INV-E05 | sail-reference | SKILL(shared) | skills/shared/{sail-grammar,sail-functions,sail-common-mistakes,appian-design-best-practices}; a11y guide → skills/shared/a11y-audit | pending | shared across developer/ux/tester |
| INV-E06 | atlas-dev-documentation | MERGE → INV-E04 (documentation) | skills/documentation/* | pending | DEDUPE doc workflows; atlas-usage/gws-cli → STEER |
| INV-P01 | atlas-product-owner | SKILL(product-owner) ×8 | skills/product-owner/{explore,feature-inventory,feature-spec,cross-app-analysis,impact-analysis,onboarding,release-review,research} | pending | guide-appian-docs → skills/shared; mcp.json → DROP |
| INV-P02 | atlas-ux-designer | SKILL(ux-designer) ×9 | skills/ux-designer/{aurora-compliance,component-decomposition,create-html-prototype,create-sailwind-prototype,design-consistency-review,design-to-dev-handoff,edge-case-analysis,generate-sail,platform-feasibility-check} | pending | mcp.json → DROP |
| INV-T01 (power) | Jarvis power steering | SKILL(developer/ux/devops) | skills/developer/{implementation,implementation-summary,feature-breakdown,spike-research,refactor-redeploy,expression-test-generation,knowledge-query}; skills/devops/pipeline-check; skills/shared/{sail-code-hygiene,sail-documentation-standards}; skills/ux-designer/branding-compliance | pending | code-review/design-doc DEDUPE with INV-E01; jarvis-menu/workspace-rules/t-retriever-navigation → STEER or DROP(UI) |
| INV-T01 (server) | Jarvis/server | MCP → SUBAGENT | jarvis-intel (server source) | pending | tool code, NOT a skill; templates/CI → its config |
| INV-T02 | Atlas + solutions-kb sync | SUBAGENT/KB pipeline | atlas-intel backing; sync pipeline → KB tooling | pending | pipeline stays as data tooling |
| INV-T03 | A11yAudit | SKILL(shared) | skills/shared/a11y-audit (+references: jira-patterns, gchat-policy) | pending | used by tester/developer/ux; uses atlas-intel |
| INV-T04 | ChatTriage | SKILL(product-owner)+HOOK | skills/product-owner/chat-triage; hook → solutions-copilot hooks | pending | merge with INV-G01 hook |
| INV-T05 | erd-generator | SKILL(documentation) | skills/documentation/generate-erd (+references: simple-erd-all-tables, sql-release-lookup) | pending | decision 2026-06-25: it's a power/knowledge → skill, not a CLI; uses atlas-intel/jarvis-intel for schema |
| INV-T06 | Jarvis-A11yFixer | SKILL(developer) | skills/developer/a11y-fix (+references: fix-patterns, xml-rules, verification) | pending | decision 2026-06-25: Developer role; playwright-appian-helper → skills/shared; uses jarvis-intel(write)+deploy |
| INV-T07 | jarvis-i18n | SKILL(developer) ×4 | skills/developer/{i18n-audit,i18n-create,i18n-lookup}; i18n-reference → references | pending | |
| INV-T08 | jarvis-smt | SKILL(developer) | skills/developer/database-script-management (db-explore/status/script/config/admin + smt-reference) | pending | decision 2026-06-25: Developer role; **no own MCP** — delegates SQL to jarvis-intel |
| INV-T09 | jarvis-verify | SKILL(tester) | skills/tester/unit-test (+references: data-setup, reference) | pending | **no own MCP** — uses jarvis-intel + Playwright. Labeled **unit-test** to distinguish from TEA (test-execution, INV-A01) |
| INV-T10 | QE-Agent CI | DEFER | — (CI shell; not migrated now) | deferred | decision 2026-06-25 |
| INV-A01 | qe-agent.md | ROLE | agents/roles/tester.json + prompts/roles/tester.md | pending | existing agent → basis for Tester role |
| INV-A02 | QE steering | STEER + SKILL + DOC | steering/ (atlas-tools, data-generator); qe-knowledge-base-GSS → DOC(solutions-os); qe-environments → environments.json | pending | |
| INV-A03 | qe-agent-mcp.json | CFG | tester agent mcpServers / sub-agent wiring | pending | |
| INV-G01 | chat-triage hook | HOOK | solutions-copilot hooks (with INV-T04) | pending | |
| INV-G02 | global steering | STEER | steering/{acli-usage,git-workflow,gws-usage}; erd-power-routing → source-routing steering | pending | |
| INV-G03 | sealed-core-prototype spec | DOC | stays in solutions-os | pending | |
| INV-G04 | mcp-configs/atlas-mcp.json | CFG → SUBAGENT | atlas-intel mcpServers | pending | |
| INV-G05 | @DOCS/standards | DOC | stays in solutions-os | pending | component-plugin-conventions.md (branch) included |
| INV-G06 | empty placeholders | DROP | — | pending | `.gitkeep` only |
| INV-B01 | playwright-deploy | DEFER | — (CLI; not migrated now) | deferred | decision 2026-06-25; Playwright plugin deploy |
| INV-B02 | SI-1067 root sync | MERGE → INV-T02 | KB pipeline | pending | DEDUPE |
| INV-K01 | products/* | DOC | stays in solutions-os | pending | fix casing drift (insurance-underwriting) |
| INV-K02 | gam-suite prototype | DOC | stays in solutions-os (product knowledge) | pending | drop node_modules |
| INV-K03 | insurance/doccenter prototypes | DOC | stays in solutions-os (product knowledge) | pending | |
| INV-DATA01 | Atlas KB data | KBDATA | intelligence KB store (read by atlas-intel) | pending | not in solutions-copilot |

## Coverage check

All INV-* rows from doc 08 are represented (A: 6, B: 2, C: 10, D: 3, E: 6, F: 2, G: 3, H: 1).
DEDUPE consolidations: INV-E06→INV-E04; INV-B02→INV-T02; code-review/design-doc INV-T01→INV-E01.
DROPPED: INV-E03 (atlas-demo-driver — no demo-driver capability); INV-G06 placeholders.
DEFERRED (decision 2026-06-25): INV-B01 (playwright-deploy), INV-T10 (QE-Agent CI), and the
`fix_table_borders.py` util in INV-E04. (INV-T05 erd-generator is **no longer deferred** — it is a
Documentation skill.) No row is silently dropped — drops carry a reason.

## Build progress (2026-06-25) — Developer role COMPLETE

All Developer-role skills are built in `solutions-copilot/.kiro/skills/` using the validated pattern
(verbatim source in `references/` + Delegation Protocol on tool-bearing refs + thin orchestrating
`SKILL.md`). 19,700 lines of source workflow preserved; 21 references carry the protocol; all
frontmatter valid; `developer` + `atlas-intel` load in `kiro-cli`.

| Skill (developer) | Source(s) | Refs |
|---|---|---|
| appian-explore | action-explore | inline-delegating |
| impact-analysis | action-impact-analysis | inline-delegating |
| technical-debt | action-technical-debt | 1 |
| code-review | Jarvis code-review-workflow + checklist + action-code-review | 3 (modes) |
| design-document | Jarvis design-doc-workflow + action-design-document | 2 (modes) |
| implementation | Jarvis implementation-workflow | 1 |
| implementation-summary | Jarvis implementation-summary-workflow | 1 |
| feature-breakdown | Jarvis feature-breakdown-workflow | 1 |
| spike-research | Jarvis spike-research-workflow | 1 |
| refactor-redeploy | Jarvis refactor-redeploy + step-translation + utility-substitution | 3 |
| expression-test-generation | Jarvis expression-test-generation | 1 |
| knowledge-query | Jarvis knowledge-query-workflow | 1 |
| i18n | jarvis-i18n audit/create/lookup + i18n-reference | 4 (3 modes) |
| a11y-fix | Jarvis-A11yFixer workflow + patterns/verification/xml-rules/playwright-helper | 5 |
| database-script-management | jarvis-smt smt-reference + 5 db-* workflows | 6 (5 modes) |

Shared skills built: `sail-reference`, `sail-code-hygiene`, `sail-documentation-standards`.

**Minor deviation (noted):** `i18n` consolidated to **one skill with 3 modes** (audit/create/lookup)
sharing one `i18n-reference`, instead of 3 separate skills — avoids triplicating the reference and
matches the code-review/design-document mode pattern.

**Dependency:** write/deploy/live skills (implementation, refactor-redeploy, expression-test-generation,
a11y-fix, database-script-management, and the live paths of code-review/design-document/knowledge-query)
delegate to **jarvis-intel** / **data-generator** / Google Workspace, which are **not yet built** —
those steps are explicitly stubbed in each SKILL.md until those sub-agents land.

---

## Resolved confirmations (2026-06-25)

1. ✅ `jarvis-smt` / `jarvis-verify` have **no own MCP** → skills (DevOps / Tester) delegating to `jarvis-intel` (+Playwright for verify). No new sub-agents.
2. ✅ `data-generator` → **dedicated sub-agent**.
3. ✅ Deploy/package → owned by the new **`devops`** role, reached via `jarvis-intel` (Jarvis server already has deployment/package handlers). Standalone deploy MCP = later option.
4. ✅ CLI tools (`erd-generator` INV-T05, `playwright-deploy` INV-B01, `fix_table_borders.py` in INV-E04, `QE-Agent` CI INV-T10) → **DEFER**, not migrated now.

## Still open (non-blocking)

- Standalone deploy MCP vs. continued reuse of Jarvis deploy handlers (v1 = Jarvis).
- Eventual home for deferred CLI tools (this repo vs. separate tools repo).
- Whether `jarvis-intel` should be split into read-only vs. write/deploy surfaces later.
