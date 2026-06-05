# Action: Technical Debt

Help a PO identify cleanup opportunities and unused features.

## When to use
- "What features are unused?"
- "What's the technical debt?"
- "What can we clean up?"
- Backlog grooming, cleanup sprint planning

## Workflow

1. `solutions-intelligence.list_orphans(app)` → get the full orphan summary with `by_type` breakdown
2. `solutions-intelligence.list_orphans(app, object_type="Interface")` → unused forms (user-visible debt)
3. `solutions-intelligence.list_orphans(app, object_type="Expression Rule")` → unused business logic
4. `solutions-intelligence.get_hub_objects(app)` → over-used components (refactoring candidates)
5. `solutions-intelligence.get_app_overview(app)` → coverage stats (bundled vs orphaned)

## How to present

**Frame as business opportunity, not technical problem:**

```
Cleanup Opportunity Report: Source Selection

Overall Health:
- 78% of components are organized into features (good)
- 22% are unused (572 components — cleanup candidates)

Unused by Category:
- 53 unused forms — these are screens nobody can reach
- 198 unused business rules — logic that's never called
- 107 unused data types — data structures with no purpose
- 97 unused groups — permission groups not referenced
- 94 unused settings — configuration values not used
- 23 other

Priority Recommendations:
1. HIGH: Review 53 unused forms — may confuse developers, easy to identify
2. MEDIUM: Review 198 unused rules — may be legacy code from old features
3. LOW: Data types and groups — less visible, lower priority

Estimated Effort: 2-3 sprint days for review, 1-2 sprints for cleanup
```

**For hub analysis (refactoring candidates):**
```
Over-Used Components (consider refactoring):
- "isBlank" utility — used 409 times (any bug here affects everything)
- "Bundle Loader" — used 350 times
- These are working fine but represent concentration risk
```

**Always ask:**
- "Want me to examine any specific unused component?"
- "Want to see which features changed most recently? (frequently changing = unstable)"
