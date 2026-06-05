# Solutions Copilot — Migration Status

**Last Updated:** June 5, 2026
**Repo:** gitlab.appian-stratus.com/ramaswamy.u/solutions-copilot

---

## Source Inventory

### From solutions-os (prod 13490 + dev 13491)

| # | Source | Type | Files | Description |
|---|--------|------|-------|-------------|
| 1 | `Engineering/.kiro/powers/atlas-developer` | Power | POWER.md + 6 steering | Code exploration, design docs, impact analysis |
| 2 | `Engineering/.kiro/powers/atlas-sql-forge` | Power | POWER.md + 16 steering | Test data generation, bulk SQL, ERD |
| 3 | `Engineering/.kiro/powers/atlas-demo-driver` | Power | POWER.md + 11 steering | Demo data generation (subset of sql-forge) |
| 4 | `Engineering/.kiro/powers/feature-docgenie` | Power | POWER.md + 6 steering + 7 DOCX templates + CSS + script | Full document generation (FIP, Tech Design, etc.) |
| 5 | `Engineering/.kiro/powers/sail-reference` | Power→Skill | POWER.md + 5 steering | SAIL grammar, functions, best practices |
| 6 | `Product/.kiro/powers/atlas-product-owner` | Power | POWER.md + 10 steering | Feature specs, release reviews, onboarding |
| 7 | `Product/.kiro/powers/atlas-ux-designer` | Power | POWER.md + 9 steering | Prototypes, Aurora compliance, SAIL generation |
| 8 | `tools/Jarvis/jarvis-power` | Power | POWER.md + 19 steering | Codebase exploration, design docs, code review, implementation |
| 9 | `tools/Jarvis-A11yFixer/jarvis-a11y-fixer-power` | Power | POWER.md + 5 steering | Automated a11y fix deployment |
| 10 | `tools/A11yAudit/a11y-audit-power` | Power→Skill | POWER.md + 9 steering | 80+ a11y rules, audit workflow |
| 11 | `tools/jarvis-i18n/jarvis-i18n-power` | Power | POWER.md + 4 steering | Internationalization workflows |
| 12 | `tools/jarvis-smt/jarvis-smt-power` | Power | POWER.md + 6 steering | Database admin (SMT scripts) |
| 13 | `tools/jarvis-verify/jarvis-verify-power` | Power | POWER.md + 3 steering | Test verification workflows |

### From SWAT-a-Palooza Projects (20 projects)

| # | Project | Lead | Type | Fits As |
|---|---------|------|------|---------|
| 1 | A11Y Fixer | Soma | Power | `a11y-fixer` power |
| 2 | AI A11y Audit | Ganesh | Skill | `a11y-audit` skill |
| 3 | Atlas SQL Forge | Ram | Power | `sql-forge` power |
| 4 | DataForge (bulk) | Hitesh | Power | Merge into `sql-forge` |
| 5 | Flow-Craft Sprint Report | Josh | Standalone | Standalone script (not power) |
| 6 | Atlas UX Designer Enhancements | Vedant | Power | `ux-designer` power |
| 7 | Kiro to FigJam | Anthony | Power | `ux-designer` steering |
| 8 | Spec to Slides | Sonali | Power | `product-owner` steering |
| 9 | Jarvis SAIL Canvas | Govind | Power | `ux-designer` steering |
| 10 | Jarvis Sweep | Khoa | Power | `developer` steering |
| 11 | Perf-Profiler | Raajiv | Standalone | CLI tool (invokable by developer) |
| 12 | Local-IDE Development | William | Standalone | VSCode/Kiro extension |
| 13 | LCP APIs / a!migo | Saurabh | MCP Server | IS the `lcp-api` MCP server |
| 14 | SAIL to SQL | Dineshkumar | Power | `sql-forge` steering |
| 15 | Feature Doc Genie | Meenakshi | Power | `doc-genie` power |
| 16 | ERD + Release Docs | Revathi | Power | `sql-forge` steering |
| 17 | AI KB Maintenance | Colin | Skill + Hook | `kb-maintenance` skill |
| 18 | T.I.M.E. Framework | Ben | Structure | Core repo structure (done) |
| 19 | Test Execution Agent (TEA) | Divya | Power | `qe-agent` power |
| 20 | Expression Assert (Jarvis) | Abby | Power | `developer` steering |

### From buildwithclaude (John Rogers)

| # | Source | Type | Files | Description |
|---|--------|------|-------|-------------|
| 1 | `skills/appian-sail` | Skill | SKILL.md + 23 references | SAIL components, layouts, patterns |
| 2 | `skills/appian-record-types` | Skill | SKILL.md + 1 reference | Record type creation, fields |
| 3 | `skills/appian-data-modeling` | Skill | SKILL.md + 2 references | Entity design, normalization |
| 4 | `skills/appian-expressions` | Skill | SKILL.md | Expression syntax, operators |
| 5 | `skills/appian-security` | Skill | SKILL.md | Group hierarchies, access control |
| 6 | `skills/appian-process-models` | Skill | SKILL.md | Node types, gateways |
| 7 | `skills/appian-interfaces` | Skill | SKILL.md | Interface patterns |
| 8 | `skills/appian-expression-rules` | Skill | SKILL.md | Expression rule patterns |
| 9 | `skills/appian-sites` | Skill | SKILL.md | Site configuration |
| 10 | `skills/appian-supporting-objects` | Skill | SKILL.md | Connected systems, integrations |
| 11 | `skills/appian-web-apis` | Skill | SKILL.md | Web API patterns |
| 12 | `skills/appian-change-planning` | Skill | SKILL.md | Change planning methodology |
| 13 | `skills/appian-change-review` | Skill | SKILL.md | Change review methodology |

### From saurabh.sabat/lcp-api

| # | Source | Type | Description |
|---|--------|------|-------------|
| 1 | `docs/known-issues.yaml` | Skill data | LCP API bugs and workarounds (308 lines) |
| 2 | `data/type_manifest.json` | Skill data | Type ID → name mapping |
| 3 | `workflows/data_model/` | Steering | Google Sheet → Appian record types |
| 4 | `workflows/bulk_rename/` | Steering | Object rename workflow |
| 5 | `powers/appian-data-model-workflow/` | Power | Data model creation |
| 6 | `powers/appian-bulk-rename-workflow/` | Power | Bulk rename |

---

## Migration Status

### ✅ COMPLETED — Powers (Full steering content migrated)

| Target Power | Source(s) | Steering Files | Status |
|-------------|-----------|----------------|--------|
| `engineering/powers/developer` | atlas-developer + Jarvis power (merged) | 20 files | ✅ Done |
| `engineering/powers/sql-forge` | atlas-sql-forge + atlas-demo-driver (merged) | 16 files | ✅ Done |
| `engineering/powers/code-reviewer` | Jarvis code-review-workflow | 2 files | ✅ Done |
| `engineering/powers/a11y-fixer` | Jarvis-A11yFixer | 5 files | ✅ Done |
| `engineering/powers/qe-agent` | A11yAudit + jarvis-verify (partial) | 9 files | ✅ Done |
| `product/powers/product-owner` | atlas-product-owner | 10 files | ✅ Done |
| `product/powers/ux-designer` | atlas-ux-designer | 9 files | ✅ Done |

### ✅ COMPLETED — Skills

| Target Skill | Source(s) | Status |
|-------------|-----------|--------|
| `engineering/skills/sail-reference` | buildwithclaude appian-sail (494 lines + 23 refs) | ✅ Done |
| `engineering/skills/appian-best-practices` | buildwithclaude record-types + data-modeling (5 refs) | ✅ Done |
| `engineering/skills/appian-patterns` | buildwithclaude expressions + security + process-models | ✅ Done |
| `engineering/skills/a11y-audit` | Written from SWAT #2 specs (87-line rules) | ✅ Done |
| `engineering/skills/appian-known-issues` | lcp-api known-issues.yaml (308 lines) | ✅ Done |
| `product/skills/aurora-design-system` | Written (basic) | ✅ Done |
| `configuration/skills/power-conventions` | Written | ✅ Done |
| `configuration/skills/steering-conventions` | Written | ✅ Done |
| `configuration/skills/naming-conventions` | Written | ✅ Done |

### ✅ COMPLETED — Agents

| Target Agent | Status |
|-------------|--------|
| `orchestrator/solutions-copilot.json` | ✅ Done |
| `engineering/agents/developer.json` | ✅ Done |
| `engineering/agents/sql-forge.json` | ✅ Done |
| `engineering/agents/code-reviewer.json` | ✅ Done |
| `engineering/agents/a11y-fixer.json` | ✅ Done |
| `engineering/agents/qe-agent.json` | ✅ Done |
| `product/agents/product-owner.json` | ✅ Done |
| `product/agents/ux-designer.json` | ✅ Done |
| `configuration/agents/power-author.json` | ✅ Done |
| `configuration/agents/skill-author.json` | ✅ Done |
| `configuration/agents/agent-author.json` | ✅ Done |

### ✅ COMPLETED — Infrastructure

| Item | Status |
|------|--------|
| solutions-lcp-mcp-server (19 tools, live-tested) | ✅ Done |
| setup.sh (install/verify/status/uninstall) | ✅ Done |
| solutions-copilot.manifest.json | ✅ Done |
| configurator/index.html | ✅ Done |
| environments.json | ✅ Done |
| scripts/detect-transition.py (T.I.M.E. hook) | ✅ Done |
| scripts/metrics.py | ✅ Done |
| status dashboard | ✅ Done |
| products/gss (T.I.M.E. example) | ✅ Done |

---

## ❌ PENDING — Powers to Migrate

| # | Power | Source | Files to Migrate | Priority | Notes |
|---|-------|--------|-----------------|----------|-------|
| 1 | `engineering/powers/i18n` | jarvis-i18n-power | POWER.md + 4 steering | P1 | Internationalization workflows — audit, create, lookup |
| 2 | `engineering/powers/db-admin` | jarvis-smt-power | POWER.md + 6 steering | P1 | Database admin — explore, config, scripts, SMT reference |
| 3 | `product/powers/doc-genie` | feature-docgenie | POWER.md + 6 steering + 7 DOCX templates + CSS + script | P1 | Full document generation (FIP, Tech Design, Perf, Security, Arch, ADR) |
| 4 | `engineering/powers/locust-forge` | atlas-locust-forge (separate repo) | Unknown | P2 | Performance test generation |

### Steering files NOT yet migrated (from Jarvis, to be added to existing powers)

| # | File | Target Power | Source | Notes |
|---|------|-------------|--------|-------|
| 1 | `branding-compliance.md` | product-owner | Jarvis steering | Brand guidelines enforcement |
| 2 | `sail-code-hygiene.md` | skill: appian-patterns | Jarvis steering | Moved to skill references |
| 3 | `sail-documentation-standards.md` | skill: appian-patterns | Jarvis steering | Moved to skill references |

---

## ❌ PENDING — Skills to Migrate

| # | Skill | Source | Priority | Notes |
|---|-------|--------|----------|-------|
| 1 | Enriched `a11y-audit` | A11yAudit power (9 steering files — full rules) | P1 | Current skill has summary; need full rules from source |
| 2 | `appian-sites` | buildwithclaude | P2 | Site configuration patterns |
| 3 | `appian-web-apis` | buildwithclaude | P2 | Web API patterns |
| 4 | `appian-supporting-objects` | buildwithclaude | P2 | Connected systems, integrations |
| 5 | `appian-change-planning` | buildwithclaude | P3 | Change planning methodology |
| 6 | `appian-change-review` | buildwithclaude | P3 | Change review methodology |
| 7 | `appian-expression-rules` | buildwithclaude | P2 | Expression rule best practices |
| 8 | `appian-interfaces` | buildwithclaude | P2 | Interface patterns (beyond SAIL ref) |
| 9 | `kb-maintenance` | SWAT #17 (Colin) | P3 | KB maintenance procedures |

---

## ❌ PENDING — SWAT Projects to Integrate

| # | Project | Integration Type | Target | Status | Blocker |
|---|---------|-----------------|--------|--------|---------|
| 4 | DataForge (bulk) | Steering addition | sql-forge | ❌ Pending | Need Hitesh's scale tier docs |
| 5 | Flow-Craft Sprint Report | Standalone script | scripts/ or separate repo | ❌ Pending | Not a power — standalone Python |
| 7 | Kiro to FigJam | Steering addition | ux-designer | ❌ Pending | Need Anthony's FigJam MCP reference |
| 8 | Spec to Slides | Steering addition | product-owner | ❌ Pending | Need Sonali's slide generation workflow |
| 9 | SAIL Canvas | Steering addition | ux-designer | ❌ Pending | Need Govind's React app reference |
| 10 | Sweep | Steering addition | developer | ❌ Pending | Need Khoa's sweep workflow |
| 11 | Perf-Profiler | Standalone CLI tool | scripts/ | ❌ Pending | Not a power — CLI tool |
| 14 | SAIL to SQL | Steering addition | sql-forge | ❌ Pending | Need Dineshkumar's conversion workflow |
| 16 | ERD + Release Docs | Steering addition | sql-forge | ❌ Pending | Need Revathi's ERD workflow |
| 17 | AI KB Maintenance | Skill + Hook | engineering/skills/ | ❌ Pending | Need Colin's maintenance procedures |
| 19 | TEA (Test Execution) | Enrich qe-agent | qe-agent | ❌ Pending | Need Divya's full TEA workflow |
| 20 | Expression Assert | Steering addition | developer | ❌ Pending | Need Abby's test generation workflow |

---

## ❌ PENDING — Products (T.I.M.E. Migration)

| Product | Current Location | Status |
|---------|-----------------|--------|
| gss (example) | solutions-copilot/products/gss/ | ✅ Done (example) |
| case-management-studio | solutions-os/products/ | ❌ Pending |
| procuresight | solutions-os/products/ | ❌ Pending |
| synapse | solutions-os/products/ | ❌ Pending |
| doccenter | solutions-os/products/ | ❌ Pending |
| insurance-underwriting | solutions-os/products/ | ❌ Pending |
| gam-solutions (suite) | solutions-os/products/ | ❌ Pending |

---

## Summary

| Category | Total | Done | Pending |
|----------|-------|------|---------|
| Powers | 11 | 7 | 4 (i18n, db-admin, doc-genie, locust-forge) |
| Skills | 18 | 9 | 9 |
| Agents | 11 | 11 | 0 |
| SWAT Integrations | 12 | 0 | 12 (steering additions to existing powers) |
| Products | 7 | 1 | 6 |
| Infrastructure | 9 | 9 | 0 |

---

## Branch Sources Identified

| Branch | Project | Content Found | Lines |
|--------|---------|---------------|-------|
| `dp-test-execution-agent` | SWAT #19 (TEA - Divya) | QE agent + 8 steering files (full test execution workflow) | 5,799 |
| `meenakshi/feature-docgenie-power` | SWAT #15 (Doc Genie) | 6 steering + 6 templates + CSS + script | ~600 |
| `jarvisRefactorRedeploy` | Jarvis refactoring | 3 refactor steering files | Already migrated (in developer) |
| `colin-hutchison/rm-2.6-steering-and-domain-files` | Products | 6 product folders with domain files | T.I.M.E. migration source |
| `Agent_with_A11y` | A11y agent variant | (No unique content beyond main) | — |
| `docs/add-spec-to-slides-power` | SWAT #8 (Spec to Slides) | (Empty diff — may not have been implemented) | — |
| `feature/shared-playwright-deploy` | Shared Playwright | (No unique steering content) | — |

### All Sources Downloaded To

```
/Users/ramaswamy.u/repo/project-tracker/solutions-copilot/config/
├── i18n/              ← POWER-src.md + 4 steering (from main, jarvis-i18n)
├── db-admin/          ← POWER-src.md + 6 steering (from main, jarvis-smt)
├── doc-genie/         ← POWER-src.md + 6 steering + 6 templates + CSS + script
└── qe-agent-tea/      ← 9 steering files (from dp-test-execution-agent branch)
```

---

### Recommended Next Steps (Priority Order)

1. **P1 — Migrate i18n power** (4 steering files from jarvis-i18n)
2. **P1 — Migrate db-admin power** (6 steering files from jarvis-smt)
3. **P1 — Migrate doc-genie power** (6 steering + templates + scripts)
4. **P1 — Enrich a11y-audit skill** (replace summary with full 9-file ruleset from A11yAudit)
5. **P2 — Add remaining buildwithclaude skills** (sites, web-apis, supporting-objects, expression-rules, interfaces)
6. **P2 — Integrate SWAT steering additions** (Sweep, TEA, Expression Assert, SAIL-to-SQL, ERD)
7. **P3 — Migrate products** to T.I.M.E. structure
