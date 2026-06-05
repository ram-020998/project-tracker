# MCP Tool Reference — v3

Complete reference for all 20 Appian Atlas MCP tools.

## Knowledge Base Structure (v3)

Each parsed application uses a versioned data layer:

```
data/<AppName>/
├── app_config.json              # App identity and version constant
├── release_index.json           # Ordered release history
├── current/
│   ├── manifest.json            # Master index (uuid → metadata + hash)
│   ├── objects/<uuid>.json      # Per-object metadata + dependencies + type_specific
│   ├── code/<uuid>.json         # SAIL code (separate from metadata)
│   ├── bundles/<Name>.json      # Lightweight bundle views with members array
│   ├── graph.json               # Complete dependency graph
│   ├── search_index.json        # Name → uuid lookup (includes description)
│   ├── app_overview.json        # Package metadata + stats
│   └── orphans_index.json       # Orphan catalog with type breakdown
├── history/<uuid>/<version>.json  # Historical object snapshots
└── changelogs/<version>.json      # Release diffs
```

Key v3 changes:
- **Code separated from metadata** — use `get_object_code` for SAIL code, `get_object_detail` for metadata
- **Bundles are lightweight** — contain `members` array with `{uuid, name, type}`, not full object data
- **Dependency graph** — `graph.json` enables path finding and transitive dependency queries
- **Version history** — each object tracks when it changed across releases

---

## Core Tools (9 existing, enhanced)

### `list_applications`
Discover all available Appian applications with stats.

### `get_app_overview`
**Args**: `app_name`
Complete technical map: object counts, bundle index, dependency summary, coverage.

### `search_objects`
**Args**: `app_name`, `query`, `object_type` (optional), `limit` (default 20, max 100)
Returns matches with **description**, bundle count, dependency counts. Use `limit` to control result size.
Response includes `total_matches` and `returned` count.

### `search_bundles`
**Args**: `app_name`, `query`, `bundle_type` (optional)
Search bundles by name or parent name.

### `get_bundle`
**Args**: `app_name`, `bundle_id`, `object_type` (optional), `limit` (default 50, max 200)
Returns bundle structure, flow, and **filtered member list**. Always includes `member_summary` with `by_type` breakdown.
- Use `object_type="Interface"` to see only interfaces in the bundle
- Use `limit=10` for a quick peek
- To see code, use `get_object_code` on specific objects

### `get_dependencies`
**Args**: `app_name`, `object_name`
Full object metadata with `calls[]` and `called_by[]` arrays, `type_specific` fields, bundle membership.

### `get_object_detail`
**Args**: `app_name`, `object_uuid`
Same as `get_dependencies` but by UUID instead of name.

### `list_orphans`
**Args**: `app_name`, `object_type` (optional), `limit` (default 50, max 200)
Orphan catalog with `by_type` breakdown. Filter by type for focused analysis.

### `get_orphan`
**Args**: `app_name`, `object_uuid`
Full orphan detail including SAIL code.

---

## New: Code Tool (1)

### `get_object_code`
**Args**: `app_name`, `object_name`
**Purpose**: Get SAIL code for a specific object WITHOUT loading the entire bundle.
Returns `{uuid, name, type, sail_code}`. Returns message if object type has no code (Constants, Groups, CDTs).

**This is the primary way to view code in v3.** Don't load full bundles just to see one object's code.

---

## New: Graph Tools (3)

### `get_dependency_path`
**Args**: `app_name`, `from_name`, `to_name`, `max_hops` (default 6), `direction` (outbound|inbound)
Find shortest path between two objects.
- `outbound`: "How does A end up calling B?"
- `inbound`: "What entry points reach this utility?"

### `get_transitive_dependencies`
**Args**: `app_name`, `object_name`, `max_hops` (default 3), `edge_types` (optional), `direction` (outbound|inbound)
All objects reachable from a starting point. Hub objects are leaf nodes (not expanded).
- `outbound`: "What does this process model touch?"
- `inbound`: "What would break if I changed this?"

### `get_hub_objects`
**Args**: `app_name`, `top_n` (default 20), `object_type` (optional)
Most-depended-on objects. These are shared utilities called by many objects.

---

## New: Version Tools (6)

### `list_releases`
**Args**: `app_name`
All releases with metadata and change summaries.

### `get_changelog`
**Args**: `app_name`, `release`, `filter_type` (optional), `filter_status` (optional), `filter_bundle` (optional)
Detailed changes for a release: added/modified/removed objects, bundle member diffs.

### `compare_releases`
**Args**: `app_name`, `from_release`, `to_release`
Compare any two releases (not just adjacent).

### `get_object_history`
**Args**: `app_name`, `object_name`
Version timeline: when was this object added, when was it last modified, across how many releases.

### `get_object_at_release`
**Args**: `app_name`, `object_name`, `release`
Full object data as it was at a specific historical release.

### `get_release_impact`
**Args**: `app_name`, `release`
Bundle-focused view: which functional flows were affected by this release.

---

## New: Pipeline Tool (1)

### `refresh_knowledge_base`
**Args**: `app_name` (optional)
Trigger a knowledge base refresh. If app_name provided, refreshes only that app. Otherwise refreshes all. Runs as background pipeline (1-2 minutes). Use when data seems stale or after a deployment.

---

## Recommended Workflows

### Explore an object
```
1. search_objects(app, "vendorValidation") → find it with description
2. get_object_code(app, "AS_GSS_BL_validateVendors") → see SAIL code
3. get_dependencies(app, "AS_GSS_BL_validateVendors") → see calls/called_by
```

### Understand a bundle
```
1. get_bundle(app, "AS_GSS_Complete_LPTA_Evaluation") → see structure + member_summary
2. get_bundle(app, "...", object_type="Interface") → filter to interfaces only
3. get_object_code(app, "AS_GSS_IF_CompleteLPTAEvaluation") → see specific code
```

### Impact analysis
```
1. get_transitive_dependencies(app, "AS_GSS_BL_validateVendors", direction="inbound") → what depends on it
2. get_dependency_path(app, "AS_GSS_PM_StartEval", "AS_GSS_BL_validateVendors") → trace the path
3. get_hub_objects(app) → identify shared utilities
```

### Release analysis
```
1. list_releases(app) → see all releases
2. get_changelog(app, "25.04.02.09.00") → what changed
3. get_release_impact(app, "25.04.02.09.00") → which bundles affected
4. get_object_history(app, "AS_GSS_BL_validateVendors") → how this object evolved
```

### Technical debt
```
1. list_orphans(app, object_type="Expression Rule") → orphaned rules
2. get_orphan(app, uuid) → examine code
3. get_hub_objects(app) → find over-used utilities (refactoring candidates)
```

---

## Efficiency Rules

1. **Use `get_object_code` for code** — don't load full bundles just to see one object's implementation
2. **Use `search_objects` with `limit`** — default 20 results, increase only if needed
3. **Use `get_bundle` with `object_type` filter** — don't load 282 members when you only need interfaces
4. **Use graph tools for path questions** — don't manually trace through get_dependencies calls
5. **Use `get_object_history` for version questions** — one call, not manifest walking
6. **Call `get_app_overview` ONCE** — cache the result mentally, don't repeat
