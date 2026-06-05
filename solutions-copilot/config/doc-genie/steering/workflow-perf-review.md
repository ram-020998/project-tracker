---
name: workflow-perf-review
description: "Performance Review document generation workflow"
inclusion: manual
---

# Workflow: Performance Review

**Template:** Read `templates/perf-review.md` for the exact output structure.

## Section-by-Section Fill Instructions

Use Atlas data from Step 2 (single exploration pass) plus spec/JIRA analysis. Replace each **Response** section in the template with analyzed content.

### Header
- `<Insert Solution Release and Feature Name Here>` → release name + feature name

### Section 1: Data Load

**1a — Maximum expected data table sizes:**
- From Atlas: `search_objects` results with `object_type="Data Type"` and `"Record Type"` → tables
- From Atlas: `get_dependencies` → parent/child relationships
- Fill volume table from spec. If spec doesn't specify: estimate from Atlas (child record count, app maturity, similar tables) and mark as **"Estimated — confirm with PO"**

**1b — Performance guardrails:**
- Reference: Performance Data Load Guardrails
- If volumes < 10K rows/year: "Standard guardrails apply"

**1c — Testing strategy:**
- Metrics: page load times, slow expressions, record response times
- Whether testing can be incremental
- Risk: "Risk grows over long periods of production usage"

### Section 2: Concurrent Usage

**2a — High volume concurrent usage?**
- From Atlas: `get_hub_objects` → check if feature touches high-traffic components
- From spec: expected concurrent users, peak usage
- If spec doesn't specify: estimate from Atlas hub object traffic (low inbound = <100 users, high inbound = 500+) and mark as **"Estimated — confirm with PO"**

**2b — Guardrails:**
- Reference: Performance Concurrency Guardrails

**2c — Testing strategy:**
- Locust scripts, throughput targets, SAIL/Http response monitoring
- Risk: "Dependent on user usage levels and environment hardware"

### Section 3: Portals

**3a — Portal introduced/updated?**
- From Atlas: `search_bundles` results for "portal"
- If no portal: "This feature does not introduce or update a public portal. Section 3 is not applicable."

**3b/3c — Guardrails and testing (if portal exists):**
- Mock web API requests at peak traffic rate
- Measure web API response times, not portal UI

### Section 4: Other Performance Factors

**4a — ETL, bulk processing, plugins, document generation?**
- From Atlas: search results for "sync", "batch", "document", "plugin", integrations
- If none: "This feature does not introduce ETL, bulk processing, or non-standard plugin usage."

**4b/4c — Guardrails and testing:**
- Test design for each concern; success criteria (completion time, resource stability)
- Risk: "Not able to be determined without spike tests"

### Section 5: Performance Testing Decision

**5a — Is performance testing needed?**
- Decision logic:
  - High data volumes (> 100K rows/year) → YES
  - High concurrency (> 500 users) → YES
  - Portal with > 1000 visits/hour → YES
  - ETL/bulk processing → YES
  - Otherwise → "Performance testing is not required for this feature"
- If YES: summarize what to test and when (Sprint 2 before hardening)
