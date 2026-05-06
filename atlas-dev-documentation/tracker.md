# Atlas Dev Documentation Power — Project Tracker

## Overview
Kiro power that generates standardized Appian Solutions release documents (FIP, Technical Design, Performance Review, Security Review, Architecture Overview, ADR) using Atlas as the primary data source and Google Workspace CLI for styled Google Docs output.

## Status
Initial version created — ready for testing.

## Location
`solutions-os/ai-framework/Engineering/.kiro/powers/atlas-dev-documentation/`

## Session Log

### May 5, 2026 — Power created

#### Completed
- Created full power structure with 12 files:
  - `POWER.md` — keywords: docgenie, release docs, documentation, fip, technical design, performance review, security review
  - `mcp.json` — Atlas MCP server (project 13490, solutions-os data prefix)
  - `README.md` — usage guide, prerequisites (GWS CLI, Atlas MCP), product selection
  - `.kiro/steering.md` — main orchestration (product selection, input gathering, Atlas exploration, Google Docs output, markdown backup)
  - `steering/atlas-usage.md` — all 20 Atlas tools documented, efficiency rules, per-document tool mapping, anti-hallucination checklist
  - `steering/google-workspace-cli.md` — GWS CLI reference for document creation
  - `steering/workflow-fip.md` — FIP template + Atlas fill instructions
  - `steering/workflow-tech-design.md` — Technical Design template + Atlas fill instructions
  - `steering/workflow-perf-review.md` — Performance Review template + Atlas fill instructions
  - `steering/workflow-security-review.md` — Security Review template + Atlas fill instructions
  - `steering/workflow-arch-overview.md` — Architecture Overview template + Atlas fill instructions
  - `steering/workflow-adr.md` — ADR template + Atlas fill instructions
- Moved from `Product/` to `Engineering/` directory
- Renamed from `docgenie` to `atlas-dev-documentation`

#### Decisions Made
- Atlas as primary data source (Jarvis skipped — not needed as dependency)
- Product selection from `products/` directory (procuresight, gam-solutions, case-management-studio)
- Separate steering files per document type (not one monolithic file) — each is self-contained with template + tool mapping + fill logic
- Google Workspace CLI as prerequisite documented in main steering (not a separate MCP dependency)
- Power placed in Engineering (not Product) — this is a developer-facing tool
- Markdown backups saved to `products/<product>/features/<feature-name>/docs/`
- Official Google Docs templates copied and filled via `replaceAllText` and `insertText` operations

#### Design Principles
- Anti-hallucination: all technical facts must come from Atlas MCP tool calls
- Efficiency rules: call `get_app_overview` once, use filters on `get_bundle`, use `limit` on searches
- Per-document Atlas tool mapping: each workflow file specifies exactly which tools to call per section
- Template fidelity: verbatim official templates preserved in each workflow file

#### Source Reference
- Original `solutions-docgenie` repo by `meenakshi.velmurugan` — adapted and restructured
- Atlas tool patterns from `atlas-developer` and `atlas-product-owner` powers
- Google Docs template IDs from original docgenie steering file

#### Remaining Items
- [ ] Test power end-to-end with a real feature spec
- [ ] Verify Google Docs template copying and placeholder replacement works
- [ ] Test Atlas tool mapping produces useful content for each document section
- [ ] Add power to solutions-os repo (commit and push)
- [ ] Consider adding JIRA MCP as optional dependency for direct ticket queries

---
