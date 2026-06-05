# Action: Code Review

Review Appian objects for quality, best practices, and potential issues.

## Workflow

1. **Find the objects**: `search_objects` or `search_bundles` to locate them.
2. **Load code**: `get_bundle(app, bundle_id, "full")` to get SAIL code.
3. **Check enrichment**: `get_object_enrichment(app, uuid)` for complexity and depth metrics.
4. **Trace dependencies**: `get_dependencies` to understand coupling.
5. **Check for patterns**: `search_by_tags(app, ["complex"])` to find flagged objects.
6. **Review**: Assess code quality, naming, complexity, and best practices.

## What to Check

- Naming conventions (AS_GSS_ prefix, proper type indicators)
- Dependency depth and coupling
- Objects tagged as `complex` or `integration_heavy`
- Missing descriptions
- High dependent_count objects (risky to change)
- For SAIL syntax/best practices: delegate to `power-appian-reference`

## Response Guidelines

- Show specific code snippets with issues highlighted
- Reference line numbers when possible
- Suggest concrete fixes
- Flag accessibility concerns for interfaces
