---
name: workflow-adr
description: "Architecture Decision Record generation workflow"
inclusion: manual
---

# Workflow: Architecture Decision Record (ADR)

**Template:** Read `templates/adr.md` for the exact output structure.

## Additional Atlas Tools (beyond Step 2 shared data)

For ADRs, you may need these additional calls:
```
get_object_history(app, name)           → how the component evolved
compare_releases(app, from, to)         → what changed between versions
get_transitive_dependencies(app, name, direction="inbound") → blast radius
```

## Section-by-Section Fill Instructions

### Header
- `<PREFIX>` → product prefix: CMS (Case Management), GAM (GAM Solutions), PS (ProcureSight)
- `####` → sequential ADR number (check existing ADRs in product's arch-decision-logs/)
- `[ADR Name]` → concise decision name
- Technical Area → parent Architecture Overview prefix
- Author → user-provided name
- Collaborators → user-provided or "N/A"
- Status → "Proposed" (default)
- Created → current date
- Dev Team → user-provided team name

### Related ADRs
- Check existing ADRs in the product directory
- If none: "No related ADRs"

### Context + Problem Statement
- From Atlas: `get_app_overview` → current architecture state
- From Atlas: `get_object_history` → how the component evolved (shows pain points)
- From Atlas: `get_hub_objects` → coupling issues
- Write one paragraph describing the issue
- Problem statement as a single question

### Options
- From Atlas: `search_bundles` → find similar patterns already in the app
- From Atlas: `get_transitive_dependencies(direction="inbound")` → blast radius per option

**LoE estimation from Atlas:**
- Count affected objects from transitive dependencies
- Low: < 5 objects, no hub objects
- Medium: 5-20 objects, 1-2 hub objects
- High: > 20 objects, multiple hub objects

Fill numbered options with: description, LoE, pros, cons

### Decision
- Which option chosen/recommended
- Brief justification from pros/cons

### Consequences
- From Atlas: `get_transitive_dependencies` → what paths change
- What becomes easier / more difficult
- Migration considerations
- Impact on other teams/features

### Cross-App Impact

If the decision affects integration with another app:
1. Call `get_app_overview` on the other app
2. Call `get_transitive_dependencies(other_app, shared_object, direction="inbound")` → blast radius in the other app
3. Document: which teams/apps are affected, what coordination is needed

## Output

Save to: `docs/<release-name>/<APPCODE>-<RELEASE>-architecture-decision-record.md`
