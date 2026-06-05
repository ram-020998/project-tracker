# Action: Feature Specification

Help a PO write a structured feature specification using Solutions Intelligence data.

## When to use
- "Write a spec for [feature idea]"
- "Document this feature request"
- "Create a story for [requirement]"

## Workflow

1. **Understand the request**: Ask the PO what the feature should do
2. **Research existing state**: Use Solutions Intelligence to find related features
   - `solutions-intelligence.search_bundles(app, keywords)` → similar existing features
   - `solutions-intelligence.search_objects(app, keywords)` → related components
3. **Analyze dependencies**: What would the new feature connect to?
   - `solutions-intelligence.get_bundle(app, similar_bundle)` → understand patterns used in similar features
   - `solutions-intelligence.get_hub_objects(app)` → shared components the new feature might reuse
4. **Check history**: Has something similar been attempted before?
   - `solutions-intelligence.list_orphans(app)` → might find abandoned attempts
5. **Write the spec** using the template below

## Spec Template

```markdown
# Feature: [Feature Name]

## Summary
[One paragraph describing what the feature does and why it matters]

## User Story
As a [role], I want to [action], so that [benefit].

## Current State
[What exists today — discovered from Solutions Intelligence]
- Related features: [from solutions-intelligence.search_bundles]
- Existing components that could be reused: [from hub_objects or solutions-intelligence.search_objects]
- Similar patterns in the app: [from solutions-intelligence.get_bundle on similar features]

## Proposed Behavior
[Step-by-step user workflow]
1. User navigates to...
2. User clicks...
3. System does...
4. User sees...

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Dependencies
[Components this feature would need to interact with — from Solutions Intelligence dependency analysis]

## Impact Assessment
[What existing features might be affected — from solutions-intelligence.get_transitive_dependencies]

## Complexity Estimate
[Based on similar features in Solutions Intelligence]
- Similar feature "[name]" has [N] components
- Estimated complexity: [Low / Medium / High]

## Open Questions
- [Question 1]
- [Question 2]
```

## Guidelines
- Fill in "Current State" and "Dependencies" from Solutions Intelligence data — don't guess
- Use `solutions-intelligence.get_bundle` on similar features to understand the typical pattern and size
- If the PO mentions a specific component to modify, run impact analysis
- Keep the spec in business language — technical details go in a separate "Technical Notes" section only if the PO asks
