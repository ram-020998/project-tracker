---
name: workflow-fip
description: "Feature Implementation Plan (FIP) generation workflow"
inclusion: manual
---

# Workflow: Feature Implementation Plan (FIP)

**Template:** Read `templates/fip.md` for the exact output structure.

## Section-by-Section Fill Instructions

Use Atlas data from Step 2 (single exploration pass) plus spec/JIRA analysis.

### Feature Card/Initiative
- Source: User-provided JIRA epic link
- Fill: `<link>` → JIRA epic URL

### Authors / Reviewers / Status / Created
- Fill: `<names>` → author names, `<Technical Advisor name(s)>` → reviewer names
- Status: `Not Started`, Created: current date

### Feature Kickoff
- Source: User-provided spec doc link(s)
- Content: Link to the feature spec document(s) and any kickoff materials

### Breakdown Tasks
- Source: Breakdown sheet link + JIRA tickets
- Fill: `<link to breakdown doc(s)...>` → breakdown sheet URL + JIRA epic URL
- Summarize: total tickets, story points, sprint distribution
- If JIRA CSV provided but lacks detail (e.g., no descriptions), use JIRA MCP (`get_jira_issue`) to fetch full ticket info
- Flag if total story points exceed typical 2-sprint capacity (~40 SP)

### Stakeholders
- Atlas: Use `get_hub_objects` results — if shared components are impacted, note owning teams
- Atlas: Use `search_bundles` results — identify impacted bundles and their owners
- Fill table with: Reviewer (Technical Advisor), teams owning shared components

### Durable Architecture Documentation
- Decision logic:
  - Feature introduces new services, data stores, or external dependencies → "Required"
  - Feature only modifies existing components → "No changes needed"
  - Unclear → `[TODO: Determine if architectural changes warrant AO update]`

### Feature Documentation/Diagrams
- Source: User-provided mockups + spec links
- If no diagrams: `[TODO: Create component/sequence diagrams for this feature]`

### Architectural Decisions
- If feature involves significant design choices → note ADR needed
- If straightforward → "No ADRs"

### Data Persistence
- Atlas: Check `search_objects(app, keyword, object_type="Data Type")` results from Step 2
- If new CDTs/record types → "Required — link to Feature Data Review"
- If no data model changes → "Not applicable"

### Security and Compliance
- Atlas: Check for integrations and portal bundles from Step 2 results
- New portal → Security Review Required
- New integration → Security Review Required
- New AI capability → AI Usage Audit Log Required
- Otherwise → "Not Required" with justification

### Accessibility (a11y)
- New UI components/interfaces → "Required"
- Backend-only changes → "Not Required"

### Risks/Open Questions
- Features exceeding release cadence (> 2 sprints)
- High-coupling dependencies (from `get_hub_objects`)
- Missing spec information
- Cross-application dependencies

### Squad-Specific Items
- Source: User input or "N/A"
