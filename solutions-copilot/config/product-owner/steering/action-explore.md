# Action: Explore

Help a PO understand a specific feature or workflow.

## When to use
- "How does X work?"
- "Show me the evaluation feature"
- "What happens when a user clicks Add Vendors?"

## Workflow

1. `search_bundles(app, keyword)` → find the feature
2. `get_bundle(app, bundle_id)` → get structure, flow, and member summary
3. Describe the **user journey**:
   - What triggers this feature (button click, scheduled job, API call)
   - What the user sees (forms, views)
   - What happens after (workflows, notifications, data changes)
4. Show the `member_summary.by_type` breakdown in business terms:
   - "This feature involves 3 forms, 2 workflows, 15 business rules, and 5 data lookups"
5. If PO wants to see specific forms: `get_bundle(app, id, object_type="Interface")`
6. If PO wants to see workflows: `get_bundle(app, id, object_type="Process Model")`

## How to present

**Describe as a user story flow:**
```
1. User clicks "Complete Evaluation" on the evaluation record
2. A form appears asking for final scores and comments
3. System validates scores against minimum thresholds
4. On submit, a workflow runs that:
   - Updates the evaluation status
   - Generates a consensus report
   - Sends notification emails to the team
```

**Never show unless asked:**
- Object names with prefixes (AS_GSS_...)
- UUIDs
- SAIL code
- Dependency counts as raw numbers

**If PO asks "how is this built?" or "show me the technical details":**
- Then and only then, use `get_object_code(app, name)` and show implementation
- Still explain what the code does in plain language alongside the technical view
