---
name: workflow-security-review
description: "Security Review document generation workflow"
inclusion: manual
---

# Workflow: Security Review

**Template:** Read `templates/security-review.md` for the exact output structure.

## Section-by-Section Fill Instructions

Use Atlas data from Step 2 (single exploration pass) plus spec/JIRA analysis. Replace each **Response** section in the template with analyzed content.

### Section 1: Object Security Matrix Changes

- **If Security Matrix sheet is provided:** Use it directly to fill the table — it already contains the Role/Object/Access mapping. Cross-reference with Atlas for any new objects from the spec.
- **If no Security Matrix sheet:** Generate from Atlas + spec:
  - From Atlas: `search_objects` with `object_type="Record Type"` → record types
  - From Atlas: `get_bundle` results → process models, interfaces (sites/pages)
  - From spec: new roles/groups
- Fill security matrix table:
  ```
  | Type | Objects | Who (Groups) | What (No Access, View, Edit) |
  | Sites | <from Atlas> | <from spec> | <access level> |
  | Process models | <from Atlas> | ... | ... |
  | Record types | <from Atlas> | ... | ... |
  | Reports | <from Atlas> | ... | ... |
  | Document folders | <from spec> | ... | ... |
  ```
- If no changes: "This feature does not require changes to the solution's object Security Matrix."

### Section 2: Row-Level Record Security

- From Atlas: record types + security-related dependencies
- If feature requires per-user/per-group filtering → describe paradigm
- If not: "This feature does not require row-level record security."

### Section 3: Runtime Document Security

- From Atlas: search results for "document", "folder"
- From spec: document upload requirements
- If documents: describe folder security model (per-group, per-record)
- If not: "This feature does not allow uploading of runtime documents."

### Section 4: Portal Security

- From Atlas: `search_bundles` results for "portal"
- If portal: confirm no sensitive info surfaced publicly, list all portal actions
- If not: "This feature does not introduce or update a portal."

### Section 5: Plugin Security

- From Atlas: search results for "plugin"
- If plugins: list them, note code scan requirements
- If not: "This feature does not require updating existing plugins or using new ones."

### Section 6: Third-Party Integration Security

- From Atlas: `search_objects` with `object_type="Integration"`
- If integrations: describe auth method, credentials management, HTTP verbs, external system security
- If not: "This feature does not require integration with third parties."

### Section 7: Tempo Access

- Default: "Tempo access is restricted for users (default option for solutions)."
- Reference: Solution Tempo Access Policy

### Team Action Items

- Summary of security actions needed before release:
  - Code scans (if plugins changed)
  - Penetration testing scope
  - Security matrix validation
  - Portal security review (if applicable)
