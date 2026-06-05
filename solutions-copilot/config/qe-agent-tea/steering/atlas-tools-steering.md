# Atlas MCP Server — Complete Tool Reference for QE

## Overview

The Appian Atlas MCP Server provides **read-only** access to pre-parsed Appian application data stored in a GitLab-hosted knowledge base. It exposes 30+ tools across 8 categories that allow you to explore application structure, trace dependencies, view SAIL code, analyze releases, query database schemas, and detect orphaned objects.

**Your ONLY source for Appian application knowledge is the Atlas MCP tools.** Do not guess object names, UUIDs, dependencies, or code. Always query Atlas.

---

## Critical Efficiency Rules

1. **Call `list_applications` ONCE** at session start to discover available apps.
2. **Call `get_app_overview` ONCE per app** — cache the result mentally, never repeat.
3. **Use `get_object_code` for SAIL code** — never load full bundles just to read one object's code.
4. **Use `get_bundle` with `object_type` filter** — don't load 200+ members when you need only Interfaces or Expression Rules.
5. **Use `search_objects` with `limit`** — default 20, increase only when explicitly needed.
6. **Use graph tools for path/impact questions** — don't manually chain `get_dependencies` calls.
7. **Use `get_object_history` for version questions** — one call replaces manifest walking.
8. **Use `get_transitive_dependencies` with `direction="inbound"`** for regression scope — finds everything that depends on a changed object.
9. **Use `get_schema_relationships` for data integrity testing** — understand FK constraints before designing test data.
10. **Use `get_reference_data` for valid test values** — get actual enum/lookup values instead of guessing.

---

## Knowledge Base Structure (v3)

Each parsed application uses a versioned data layer:

```
data/<AppName>/
├── app_config.json                    # App identity and version constant
├── release_index.json                 # Ordered release history
├── current/
│   ├── manifest.json                  # Master index (uuid → name, type, hash, version)
│   ├── app_overview.json              # Package metadata + stats + bundle index
│   ├── search_index.json              # Name → {uuid, type, description, bundle_count, dep_counts}
│   ├── graph.json                     # Complete dependency graph (nodes + edges)
│   ├── orphans_index.json             # Orphan catalog with type breakdown
│   ├── objects/<uuid>.json            # Per-object: metadata, dependencies, type_specific, version_history
│   ├── code/<uuid>.json               # SAIL code (separate from metadata)
│   ├── bundles/<BundleId>.json        # Bundle: entry_point, flow, members[], key_objects
│   ├── documents/_index.json          # Document/image catalog
│   ├── documents/<file>               # Binary document files
│   └── schema/                        # Database schema data
│       ├── tables.json                # Table definitions (columns, types, PKs)
│       ├── relationships.json         # Foreign key relationships
│       ├── reference_data.json        # Lookup/enum values
│       ├── insertion_order.json       # Topological sort for safe inserts
│       ├── table_classification.json  # business | reference | audit | task_management | framework
│       └── summary.json              # Stats: table count, column count, FK count
├── history/<uuid>/<version>.json      # Historical object snapshots
├── changelogs/<version>.json          # Release diffs (object + bundle changes)
└── release_snapshots/<version>/       # Full manifest snapshots per release
```

---

## Tool Categories

| Category | Tools | QE Use Case |
|----------|-------|-------------|
| **Discovery** | `list_applications`, `get_app_overview` | Identify test scope, understand app structure |
| **Bundle** | `search_bundles`, `get_bundle` | Map functional flows for end-to-end test scenarios |
| **Object** | `search_objects`, `get_dependencies`, `get_object_detail`, `get_object_code` | Understand object behavior, trace data flow for test design |
| **Graph** | `get_dependency_path`, `get_transitive_dependencies`, `get_hub_objects` | Regression scope, impact analysis, risk assessment |
| **Version** | `list_releases`, `get_changelog`, `compare_releases`, `get_object_history`, `get_object_at_release`, `get_release_impact` | Regression test planning, change-based testing |
| **Orphan** | `list_orphans`, `get_orphan` | Dead code identification, coverage gaps |
| **Schema** | `get_app_schema`, `get_schema_relationships`, `get_reference_data`, `get_insertion_order`, `get_schema_summary` | Test data design, data integrity validation |
| **Document** | `list_documents`, `get_document` | UI asset verification |
| **Git Content** | `list_git_directory`, `get_git_content`, `search_git_content` | Access design docs, test references |
| **Pipeline** | `refresh_knowledge_base` | Refresh stale data after deployments |

---

## QE Workflows — Efficient Tool Sequences

### Workflow 1: Regression Test Scope for a Release

```
Step 1: get_release_impact(app, release) → affected bundles
Step 2: For each affected bundle, get_bundle(app, bundle_id, limit=10) → what changed
Step 3: get_changelog(app, release, filter_status="modified") → specific changed objects
Step 4: For critical objects, get_transitive_dependencies(app, object_name, direction="inbound") → blast radius
```

### Workflow 2: Test Case Generation from Bundle Analysis

```
Step 1: search_bundles(app, "feature_name") → find bundle
Step 2: get_bundle(app, bundle_id) → entry point, flow, members
Step 3: get_object_code(app, entry_point_name) → UI fields, validations, buttons
Step 4: get_object_code(app, validation_rule_name) → boundary conditions
Step 5: get_dependencies(app, entry_point_name) → integration points
Step 6: get_app_schema(app, table_name) → column constraints
Step 7: get_reference_data(app, table_name) → valid enum values
```

### Workflow 3: Impact Analysis for a Code Change

```
Step 1: get_transitive_dependencies(app, changed_object, direction="inbound", max_hops=3) → dependents
Step 2: get_hub_objects(app) → check if changed object is a hub
Step 3: get_dependencies(app, changed_object) → direct callers
Step 4: For entry-point callers, get_bundle(app, bundle) → map to test suites
```

### Workflow 4: Test Data Setup Design

```
Step 1: get_schema_summary(app) → schema complexity
Step 2: get_insertion_order(app) → correct creation sequence
Step 3: get_app_schema(app, classification="business") → table definitions
Step 4: get_schema_relationships(app, table_name) → FK dependencies
Step 5: get_reference_data(app) → valid lookup values
```

---

## Anti-Patterns — What NOT to Do

1. DON'T call `get_app_overview` repeatedly — call it once.
2. DON'T load full bundles to see one object's code — use `get_object_code`.
3. DON'T manually chain `get_dependencies` to trace paths — use graph tools.
4. DON'T guess object names or UUIDs — always use `search_objects` first.
5. DON'T load all bundle members when you need one type — use `object_type` filter.
6. DON'T ignore the `direction` parameter on graph tools.
7. DON'T skip `get_reference_data` when designing test data.
8. DON'T call `refresh_knowledge_base` unless data seems stale.
