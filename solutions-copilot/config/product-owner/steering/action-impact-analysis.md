# Action: Impact Analysis

Help a PO understand the risk and scope of a proposed change.

## When to use
- "What would break if we change X?"
- "How risky is this change?"
- "What's the testing scope for modifying Y?"
- Grooming / prioritization discussions

## Workflow

1. `search_objects(app, name)` → find the component, note its description
2. `get_transitive_dependencies(app, name, direction="inbound")` → everything that depends on it
3. Group the results by bundle (feature) using the `bundles` field
4. `get_hub_objects(app)` → check if this is a widely-shared component
5. If PO asks "how are A and B connected": `get_dependency_path(app, A, B)`

## How to present

**Frame as business risk, not technical dependency:**

❌ "This object has 47 inbound dependencies across 12 bundles"
✅ "This validation logic is used in 12 features. Changing it would require testing:
   - Add Vendors (vendor entry)
   - Edit Vendor (vendor updates)
   - Bulk Import (batch processing)
   - Vendor API (external integrations)
   - ... and 8 more features"

**Risk levels:**
- **Low risk**: Used in 1-2 features, no shared components
- **Medium risk**: Used in 3-5 features, or touches a shared component
- **High risk**: Used in 6+ features, or IS a shared component (hub)
- **Critical risk**: Hub object used across 10+ features

**Always recommend testing scope:**
```
Impact Assessment: Vendor Validation Logic

Risk Level: HIGH
Affected Features: 12
Affected Business Areas: Vendor Management, Evaluation, Data Import

Recommended Testing:
- Full regression: Add Vendors, Edit Vendor, Bulk Import
- Smoke test: All other vendor-related features
- API test: Vendor API endpoint

Recommendation: Schedule this change for a dedicated sprint with full QA coverage.
```

**If PO asks about a specific path:**
- `get_dependency_path(app, "Start Evaluation", "Vendor Validation")` → show the chain
- Describe each step: "The evaluation start form → calls the vendor list → which uses vendor validation"
