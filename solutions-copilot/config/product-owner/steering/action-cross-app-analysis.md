# Action: Cross-App Analysis

Help a PO compare features across multiple Appian applications.

## When to use
- "Do other apps have a similar feature?"
- "Compare vendor management across apps"
- "Which app has the most complex evaluation workflow?"
- Portfolio-level planning

## Workflow

1. `list_applications()` → see all available apps
2. For each relevant app:
   - `search_bundles(app, keyword)` → find matching features
   - `get_app_overview(app)` → compare sizes and coverage
3. Compare results across apps

## How to present

```
Cross-App Comparison: "Vendor" Features

Source Selection:
- 8 vendor-related features (Add, Edit, Remove, Sync, Import, View, Bulk, API)
- 245 components in the largest vendor feature

Vendor Management:
- 12 vendor-related features (full vendor lifecycle)
- 380 components in the largest vendor feature

Contract Writing:
- 3 vendor-related features (lookup, reference, import)
- 120 components in the largest vendor feature

Observations:
- Vendor Management has the most comprehensive vendor features
- Source Selection and Contract Writing share some vendor components
- Potential for shared vendor utilities across apps
```

## Guidelines
- Keep comparisons at the feature level, not component level
- Highlight opportunities for reuse across apps
- Note where apps might have duplicate functionality
- Don't load full bundles for every app — use overview and search for comparison
