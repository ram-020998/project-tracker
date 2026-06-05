# Action: Impact Analysis

Analyze the impact of changing an Appian object — who depends on it, what it depends on, and how wide the blast radius is.

## Workflow

1. **Find the target object**: `search_objects(app, query)` to get name and description.
2. **Trace direct dependencies**: `get_dependencies(app, object_name)` for `calls[]` and `called_by[]`.
3. **Trace transitive impact**: `get_transitive_dependencies(app, object_name, direction="inbound")` to find everything that would break.
4. **Find the path**: `get_dependency_path(app, entry_point, target, direction="inbound")` to understand how entry points reach this object.
5. **Check hub status**: `get_hub_objects(app)` to see if this is a widely-shared utility.
6. **Check version history**: `get_object_history(app, object_name)` to see how often it changes.
7. **Report**: Show dependency tree, bundle impact, and risk assessment.

## Response Guidelines

- Show the full dependency tree (both directions)
- Use `get_transitive_dependencies` with `direction="inbound"` for "what breaks if I change this?"
- Group impacted objects by bundle using the object's `bundles` field
- Highlight shared utilities with high inbound_count
- Flag cross-bundle dependencies
- Show version history if the object changes frequently
- Recommend testing scope based on impact
