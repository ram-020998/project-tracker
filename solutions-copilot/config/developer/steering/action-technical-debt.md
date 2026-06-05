# Action: Technical Debt

Identify and analyze technical debt — orphaned objects, over-used utilities, and objects that changed frequently.

## Workflow

1. **Orphan analysis**: `list_orphans(app, object_type="Expression Rule")` → filter by type.
2. **Examine orphans**: `get_orphan(app, uuid)` → see code and determine if dead code.
3. **Hub analysis**: `get_hub_objects(app, top_n=20)` → find over-used utilities (refactoring candidates).
4. **Version churn**: `get_object_history(app, name)` → find objects that change every release (unstable).
5. **Release impact**: `get_changelog(app, release)` → see what changed recently.
6. **Report**: Categorize debt as dead code, over-coupling, or instability.

## Response Guidelines

- Group orphans by type and suggest action (delete, bundle, migrate)
- Highlight hubs with very high inbound_count as refactoring candidates
- Flag objects with many version_history entries as unstable
- Use `get_transitive_dependencies(direction="inbound")` to assess hub impact before recommending changes
