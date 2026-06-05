---
name: "feature-docgenie"
displayName: "Feature DocGenie"
description: >
  Generates standardized Appian Solutions release documents (FIP, Technical Design,
  Performance Review, Security Review, Architecture Overview, ADR) using Atlas as the
  primary data source. Asks for inputs, explores the codebase via Atlas MCP in a single
  pass, and outputs markdown documents using the official templates.
keywords:
  - docgenie
  - release docs
  - release documentation
  - fip
  - technical design
  - performance review
  - security review
  - architecture overview
  - adr
  - solutions
  - atlas
author: "Appian Solutions"
---

# Feature DocGenie

You are a **documentation generation power** for Appian Solutions Lead Developers and Technical Architects. You produce release-ready documents (FIP, Technical Design, Performance Review, Security Review, Architecture Overview, ADR) by analyzing feature specs and exploring the application codebase via Atlas — saving architects hours of manual document preparation each release cycle.

## Overview

Atlas Dev Documentation (DocGenie) automates the generation of standardized Appian Solutions release documents. Given a feature spec, breakdown sheet, and JIRA tickets, it produces up to 6 documents that match the official Appian Solutions templates exactly.

All technical facts come from Atlas MCP tool calls. Sections where data is insufficient are marked with `[TODO]` placeholders rather than fabricated content.

## Supported Products

| Product | Atlas App Name(s) |
|---------|-------------------|
| ProcureSight | `ProcureSightEnterprise` |
| GAM Solutions | `GamSuiteModule`, `SourceSelection`, `AwardManagement` |
| Case Management Studio | `CaseManagementStudio` |

## Prerequisites

1. **Docker** — Required for the Atlas MCP server (auto-starts via `mcp.json`)
2. **GITLAB_TOKEN** — Environment variable with GitLab access token
3. **Google Workspace CLI (`gws`)** — For reading specs/sheets from Google Drive
4. **Pandoc** *(optional)* — For Google Docs export (`brew install pandoc`)
5. **JIRA MCP** *(optional)* — For direct JIRA queries instead of CSV exports

### Setup

```bash
export GITLAB_TOKEN="your-gitlab-token"

# GWS (for reading inputs from Google Drive)
brew install googleworkspace-cli
gws auth login -s drive,sheets,slides
```

### Verification

1. **Atlas MCP** — Call `list_applications()` to confirm connection
2. **GWS auth** — Run `gws auth status` to confirm authentication

## File Structure

```
atlas-dev-documentation/
├── POWER.md                    # This file
├── mcp.json                    # Atlas MCP server config (auto-starts)
├── README.md                   # User-facing documentation
├── .kiro/
│   └── steering.md             # Main orchestrator (always loaded)
├── steering/                   # Per-document workflow files (loaded on-demand)
│   ├── workflow-fip.md
│   ├── workflow-tech-design.md
│   ├── workflow-perf-review.md
│   ├── workflow-security-review.md
│   ├── workflow-arch-overview.md
│   └── workflow-adr.md
├── templates/                  # Official templates (editable, version-controlled)
│   ├── fip.md
│   ├── tech-design.md
│   ├── perf-review.md
│   ├── security-review.md
│   ├── arch-overview.md
│   └── adr.md
├── styles/
│   └── document.css            # CSS for Google Docs export styling
└── docs/                       # Generated markdown output goes here
```

## Common Workflows

### Generate All Release Documents

```
Generate release docs for "Vendor Scoring Enhancements" in the "2026.06 Release".

Inputs:
- Product: GAM Solutions (Source Selection)
- Feature spec: https://docs.google.com/document/d/abc123/edit
- Breakdown sheet: https://docs.google.com/spreadsheets/d/xyz789/edit
- JIRA epic: GAMS-1234
- Author: Jane Smith
- Reviewer: John Doe
```

### Generate Specific Documents Only

```
Generate only the Technical Design and Performance Review for "Case Intake Portal".

- Product: Case Management Studio
- Feature spec: ./specs/case-intake-spec.md
- JIRA CSV: ./data/case-intake-tickets.csv
```

## How It Works

1. **Gathers inputs** — specs, JIRA, breakdown (from Drive or local files)
2. **Explores codebase once** — single Atlas pass, results reused across all documents
3. **Generates each document** — reads template, applies workflow instructions, writes markdown
4. **Marks gaps** — `[TODO]` placeholders where data is insufficient

## Output

### Primary: Markdown

```
docs/<release-name>/
├── feature-implementation-plan.md
├── technical-design.md
├── performance-review.md
├── security-review.md
├── architecture-overview.md          (if requested)
└── architecture-decision-record.md   (if requested)
```

### Optional: Styled Google Docs

Converts markdown to styled HTML (using `styles/document.css`) and uploads to Google Drive as a Google Doc. Requires `pandoc` (`brew install pandoc`).

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Atlas MCP not connecting | Verify Docker is running and `GITLAB_TOKEN` is set |
| `gws` auth error | Run `gws auth login -s drive,sheets,slides` |
| Atlas app not found | Call `list_applications()` to see available apps |
| JIRA CSV parse error | Verify columns: Issue Key, Summary, Status, Assignee, Story Points, Issue Type, Description |
| Insufficient data | Marked with `[TODO: <guidance>]` — fill manually |

## Editing Templates

Templates live in `templates/`. To change a template's structure or content:

1. Edit `templates/<doc>.md`
2. Commit the change
3. The agent picks up the new structure on next run

Templates are pure markdown — the exact document structure as it should appear in output.
