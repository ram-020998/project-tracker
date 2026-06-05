# Action: Feature Inventory

Help a PO understand the scope, complexity, and distribution of features for planning.

## When to use
- "How many features does this app have?"
- "What are the most complex features?"
- "Give me a feature breakdown for planning"
- Sprint/roadmap planning, resource estimation

## Workflow

1. `get_app_overview(app)` → total counts and bundle list
2. Group bundles by `bundle_type`:
   - **Actions** (user-triggered): things users can do
   - **Processes** (background): automated workflows
   - **Pages** (views): how users see data
   - **Sites** (navigation): application entry points
   - **Dashboards**: admin/reporting views
   - **Web APIs**: external integrations
3. Sort bundles by `object_count` to find most complex features
4. `get_hub_objects(app)` → most-shared components (high impact, high reuse)

## How to present

**Feature summary table:**
```
Application: Source Selection
Total Features: 216

By Type:
- User Actions: 180 (things users can trigger)
- Background Workflows: 20 (automated processes)
- Views & Dashboards: 10 (how users see data)
- External APIs: 6 (integrations with other systems)

Coverage: 78% of components are organized into features
Unused components: 572 (potential cleanup candidates)
```

**Complexity ranking (top 10):**
```
Most Complex Features:
1. Evaluation Record View — 654 components (largest feature)
2. Complete Evaluation — 312 components
3. Start Evaluation — 287 components
4. Add Vendors — 245 components
...
```

**Shared building blocks (hubs):**
```
Most-Used Components (change these = high risk):
1. isBlank utility — used in 409 places
2. Bundle Loader — used in 350 places
3. isNotBlank utility — used in 254 places
...
```

**Use for planning:**
- Complex features (high component count) → need more sprint capacity
- Hub components → changes need extra testing, plan accordingly
- Unused components → cleanup sprint candidates
