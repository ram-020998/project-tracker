# Action: Explore

General exploration of Appian applications — finding objects, understanding implementations, viewing SAIL code, and answering technical questions.

## Workflow

1. **Identify the app**: If not specified, call `list_applications()` to find it.
2. **Search**: Use `search_objects` (returns description) or `search_bundles` to find what the user is asking about.
3. **View code**: Use `get_object_code(app, name)` to see SAIL code for a specific object.
4. **View metadata**: Use `get_dependencies(app, name)` for full object detail with calls/called_by and type_specific fields.
5. **Explore bundle**: Use `get_bundle(app, bundle_id)` with `object_type` filter to see specific member types.
6. **Trace paths**: Use `get_dependency_path` or `get_transitive_dependencies` for relationship questions.
7. **Respond**: Include full object names, SAIL code snippets, and dependency info.

## Response Guidelines

- Always include full technical names with prefixes (e.g., `AS_GSS_FM_addVendors`)
- Show UUID for precise identification
- Mention object type explicitly (Interface, Expression Rule, etc.)
- Use `get_object_code` for code — don't load full bundles
- Show both `calls[]` and `called_by[]` relationships
- Use graph tools for "how does A relate to B?" questions
- Flag circular dependencies or high coupling
- Point out orphaned objects as potential technical debt

## Efficiency Tips

- Use `search_objects` with `limit` — default 20 is usually enough
- Use `get_bundle` with `object_type` filter to narrow results
- Use `get_object_code` for one object's code instead of loading entire bundle
- Use `get_hub_objects` to quickly find shared utilities
