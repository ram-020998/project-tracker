# Action: Onboarding

Help a PO understand an Appian application for the first time.

## When to use
- PO is new to the application
- Stakeholder asks "what does this app do?"
- Need a high-level capability overview

## Workflow

1. `solutions-intelligence.list_applications()` → show available apps, let PO pick one
2. `solutions-intelligence.get_app_overview(app)` → get the full map
3. Summarize in business terms:
   - Total features grouped by type (actions, workflows, views, dashboards, APIs)
   - Coverage: what % of the app is organized into features vs unused
   - Top shared components (hubs) — the building blocks everything depends on
4. `solutions-intelligence.search_bundles(app, "")` or browse the bundle list from overview → group by business area
5. For any feature the PO wants to explore deeper → hand off to `action-explore`

## How to present

**Group features by business function, not by technical type.** Look at bundle names and group them:
- "Vendor Management (8 features): Add, Edit, Remove, Sync, Import..."
- "Evaluation Process (15 features): Create, Score, Complete, Consensus..."
- "Reporting (3 features): Dashboard, Summary View, Export..."

**Highlight key numbers:**
- Total user-facing features (count of bundles)
- Total components (objects — but don't call them objects, say "components")
- Coverage (bundled vs orphaned — say "organized features" vs "unused components")

**End with suggested next steps:**
- "Want me to walk through any specific feature?"
- "Want to see what changed in the latest release?"
- "Want to see the most complex features for planning?"
