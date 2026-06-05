# Action: Research

Help a PO investigate a topic, feature idea, or problem space.

## When to use
- "Research [topic] for this app"
- "What are the options for implementing X?"
- "Investigate how we could add Y"
- "What do we know about Z?"

## Workflow

1. **Define the question**: Clarify what the PO wants to learn
2. **Check existing state in Atlas**:
   - `search_bundles(app, topic)` → do we already have something related?
   - `search_objects(app, topic)` → any components with this name?
   - `get_app_overview(app)` → understand the app's current scope
3. **Analyze related features**:
   - `get_bundle(app, related_bundle)` → how are similar things built?
   - `get_hub_objects(app)` → what shared components exist that could be leveraged?
4. **Check history**:
   - `list_orphans(app)` → was something similar built and abandoned?
   - `get_object_history(app, name)` → has a related component been changing frequently?
5. **Synthesize findings** using the template below

## Research Template

```markdown
# Research: [Topic]

## Question
[What are we trying to learn?]

## Current State
[What exists in the application today related to this topic]
- Existing features: [from Atlas search]
- Related components: [from Atlas search]
- Recent changes: [from release history if relevant]

## Analysis
[What the existing data tells us]
- Patterns observed: [how similar things are built in this app]
- Reusable components: [shared utilities that could be leveraged]
- Gaps identified: [what's missing]

## Options
[If applicable — different approaches to consider]

### Option A: [Name]
- Description: ...
- Pros: ...
- Cons: ...
- Estimated impact: [from Atlas dependency analysis]

### Option B: [Name]
- Description: ...
- Pros: ...
- Cons: ...

## Recommendation
[Based on the analysis]

## Open Questions
- [What we still don't know]
```

## Guidelines
- Ground everything in Atlas data — show what actually exists
- If the PO mentions a specific area, load that bundle and analyze its structure
- Use `compare_releases` if the topic involves understanding how something evolved
- Don't speculate about implementation — use Atlas to show real patterns
