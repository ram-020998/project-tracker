---
name: workflow-arch-overview
description: "Architecture Overview document generation workflow"
inclusion: manual
---

# Workflow: Architecture Overview

**Template:** Read `templates/arch-overview.md` for the exact output structure.

## Section-by-Section Fill Instructions

Use Atlas data from Step 2 (single exploration pass) plus spec/JIRA analysis.

### [NAME] in title
- Replace with architecture name (feature name or system name)

### Background
- Source: Product domain docs + feature spec
- Business context: what problem this architecture solves, who uses it
- Historical context from `list_releases` if available

### Requirements (MoSCoW)
- From spec: categorize into Must Have / Should Have / Could Have / Won't Have
- Cross-reference with Atlas: note existing capabilities vs new ones

### Architecture Summary
- From Atlas: `get_app_overview` → object counts, bundle types, coverage
- From Atlas: `get_hub_objects` → core shared components
- Describe: key components, how they interact, shortcomings

### Architecture Diagrams
- From Atlas: `get_hub_objects` → central nodes
- From Atlas: `get_dependencies` → major paths between components
- From Atlas: `search_objects` with `object_type="Integration"` → external systems
- If cross-app: call `get_app_overview` on other apps to show integration boundaries

**Fill each diagram section with text descriptions:**
- **Context Diagram** — system boundary, external actors, data flows
  - `[TODO: Create C4 Context Diagram in LucidChart showing <actors> and <external systems>]`
- **Container Diagram** — major containers (app bundles, integrations, data stores, portals)
  - `[TODO: Create C4 Container Diagram in LucidChart]`
- **Deployment Diagram** — if relevant
  - `[TODO: Create C4 Deployment Diagram if applicable]`

### Architecture Decisions
- **Performance** — key decisions from Performance Review analysis
- **Security** — security model from Security Review analysis
- **Compliance** — applicable frameworks (SOC2, FedRAMP if any)

### API / Contracts
- From Atlas: web APIs and integration contracts
- If none: "No external API contracts for this architecture."

### Glossary
- Domain-specific terms from spec and product docs

### Additional Information
- Links to related documents (spec, mockups, other AOs)
