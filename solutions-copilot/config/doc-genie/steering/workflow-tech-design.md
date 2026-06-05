---
name: workflow-tech-design
description: "Technical Design document generation workflow"
inclusion: manual
---

# Workflow: Feature Technical Design

**Template:** Read `templates/tech-design.md` for the exact output structure.

## Section-by-Section Fill Instructions

Use Atlas data from Step 2 (single exploration pass) plus spec/JIRA analysis.

### Header
- `<Feature Name>` → feature name
- `<Feature high-level objective>` → one-line objective from spec
- Dev Lead → author name
- Reviewing Architect → reviewer name

### Resources
- Spec → feature spec doc link
- Mockups → mockups link or "N/A"
- Jira epic → JIRA epic URL
- Story map → breakdown sheet link

### Data Model

**From Atlas Step 2 data:**
- `search_objects` results with `object_type="Data Type"` → existing CDTs
- `search_objects` results with `object_type="Record Type"` → existing records
- `get_dependencies` results → entity relationships

**Fill with:**
- New entities from spec (mark as NEW): name, fields, types
- Updated entities from spec + Atlas confirmation: name, new fields
- Reference data: constants, lookup tables
- Entity relationships from Atlas dependency data

**If no CDTs found:** `[TODO: Data model not found in Atlas KB — manually list entities, fields, types]`

### Core Components

**From Atlas Step 2 data:**
- `search_bundles` results → relevant feature bundles
- `get_bundle` results filtered by object_type → record types, processes, interfaces

**Fill each sub-section:**
- **Record Types** — list from Atlas with purpose; mark NEW ones from spec
- **Processes** — list process models; describe trigger, flow, outcome
- **Reports** — list report objects if found
- **Interfaces** — list key interfaces; describe purpose
- **Documents** — storage approach, security model, archival, generation

### Anything Else

- **Complex Designs** — non-trivial patterns from spec + Atlas dependency paths
- **Configurations/Customizations** — search for "config"/"custom" in Atlas results
- **Interaction Points (APPREFS/ENTRYPOINTS)** — cross-app references from `get_dependencies`
- **Technical Tickets/Spikes** — JIRA tickets with type "Spike" or "Technical Task"
- **Integrations** — from `search_objects` with `object_type="Integration"`; describe endpoint, auth, data
- **Plugins** — from Atlas search for "plugin"; list name, version, purpose
- **Testing Concerns** — high-coupling areas from `get_hub_objects`, cross-bundle dependencies
- **Product Metrics** — from spec

### Cross-App Integration Analysis

If the spec mentions interaction with another application (e.g., Source Selection → Award Management, or any external Appian app):

1. Call `get_app_overview` on the **other** app as well
2. Call `search_objects(other_app, keyword)` to find the integration surface
3. Call `get_dependencies(primary_app, integration_object)` to trace the connection
4. Document: which objects cross the boundary, what data flows between apps, what breaks if one app changes

This is critical for Technical Design — integration points are the highest-risk areas.

### Questions
- Gaps identified during Atlas exploration + spec analysis
