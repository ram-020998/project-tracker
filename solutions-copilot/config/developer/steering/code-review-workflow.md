---
inclusion: auto
---

# Code Review Workflow

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING:**

1. ✅ **SHOW THE EXECUTION TRACKER** - Copy the tracker template below and paste it in your response RIGHT NOW
2. ✅ **READ THIS ENTIRE WORKFLOW FILE** - Don't skip ahead, don't assume you know the steps
3. ✅ **IDENTIFY YOUR STARTING POINT** - Determine which step you're on based on user input
4. ✅ **VERIFY BLOCKING RULES** - Check that previous steps are complete before proceeding

**IF YOU SKIP ANY OF THESE, YOU ARE VIOLATING THE WORKFLOW.**

**Common Triggers That Activate This Workflow:**
- "Do code review for GAMS-XXXX"
- "Review [object name]"
- "Code review [package URL]"
- User selects option 2 or 3 from JARVIS menu

**When you see these triggers, your FIRST action is to show the tracker. Not call tools. Not analyze code. SHOW THE TRACKER.**

---

## CRITICAL RULES - MANDATORY COMPLIANCE
- ⚠️ STRICT ENFORCEMENT: Follow these steps EXACTLY in order. NO DEVIATIONS ALLOWED.
- ⚠️ STEP SKIPPING IS FORBIDDEN: Every step must be completed before proceeding to the next.
- ⚠️ EXECUTION TRACKER IS MANDATORY: You MUST show the execution tracker in EVERY response and update it after each step.
- ⚠️ BLOCKING CHECKS: Before starting any step, verify the previous step shows ✅ in the tracker. If not, STOP IMMEDIATELY.

**PERMANENT SOLUTION TO PREVENT STEP SKIPPING:**

The execution tracker is your FORCING MECHANISM. It works like this:

1. **Visual Accountability**: You must show the tracker in every response, making it impossible to hide skipped steps
2. **Blocking Rules**: Each step has a blocking check that references the tracker
3. **No Ambiguity**: ✅ means done, ❌ means not done - no gray area
4. **User Visibility**: User can see exactly which steps were completed and which were skipped
5. **Self-Enforcement**: You cannot claim a step is done without updating the tracker

**If you skip a step, the tracker will show it, and the user will catch it immediately.**

**How Validation Checkpoints Work:**
- Before starting each step, you MUST verify the previous step's checklist items
- Each checkpoint lists specific deliverables that must be completed
- If you cannot confirm all checkpoint items, you MUST go back and complete the missing work
- These checkpoints are designed to catch workflow deviations before they compound

## WORKFLOW ISOLATION - CRITICAL

⚠️ THIS WORKFLOW IS COMPLETELY INDEPENDENT
⚠️ DO NOT apply patterns from Design Doc Workflow or Implementation Workflow
⚠️ DO NOT create HTML files (that's design doc workflow)
⚠️ DO NOT create objects (that's implementation workflow)
⚠️ DO NOT create packages (that's design doc workflow)
⚠️ THIS WORKFLOW: Review existing code → Build review document → Optionally export to Google Docs

**Key Differences:**
- **Design Doc Workflow:** Creates HTML file → Imports to Google Docs → Creates package
- **Implementation Workflow:** Creates Appian objects via Deployment API
- **Code Review Workflow:** Reviews existing code → Builds review markdown → Optionally exports to Google Doc

**What This Workflow Does:**
1. Gets JIRA ticket, package URL, and reference date (for diff context)
2. Retrieves package contents
3. Sets up review document and validates application info
4. Reviews each object one-by-one (fetch source + diff → implementation notes → analyze → dynamic checklist → write findings)
5. Compiles final report with cross-object analysis
6. Optionally exports to Google Doc

**What This Workflow Does NOT Do:**
- ❌ Create Appian objects
- ❌ Create packages
- ❌ Deploy anything

If you find yourself creating objects or deploying, STOP - you're in the wrong workflow.

## Trigger

When the user says "Do code review for GAMS-XXXX" (or any JIRA ticket key), or provides a package URL, follow this workflow.

## Configuration

- **Application Config:** `get_jarvis_config` API - Returns application UUIDs, naming conventions, and drive folder IDs
- **Best Practices Checklist:** `get_review_checklist` API — dynamic, team-managed checklist (primary source for Step 4e)
- **Static Fallback:** `.kiro/steering/appian-best-practices-checklist.md` — documentation reference if API is unreachable
- **Review Documents Folder:** `review-documents/` - Where review markdown files are saved

---

## Object Type ID Mapping

The `get_object_diff` tool requires a `typeId` integer. Use this mapping:

| Friendly Name | typeId | Naming Hint |
|--------------|--------|-------------|
| Interface | 260 | `FM_`, `SCT_`, `CPS_`, `CRD_`, `GRD_`, `HCL_`, `DLG_` |
| Expression Rule | 39 | `QR_`, `QE_`, `UT_`, `BL_`, `FN_`, `CO_` |
| Constant | 40 | `INT_`, `TXT_`, `BOL_`, `REF_`, `HEX_`, `ENT_` |
| Process Model | 23 | (no prefix pattern — identified by type from package contents) |
| Integration | 250 | `INT_` (context-dependent — check object type from package) |
| Decision Rule | 248 | `DR_` |

**Objects that do NOT support diff:**
- Record Types — `typeId` is `null` from package contents. Skip diff for these.
- CollaborationDocuments — already filtered out in Step 2.

---

## CONTEXT MANAGEMENT — WHY THIS WORKFLOW USES FILE PERSISTENCE

This workflow processes objects ONE AT A TIME and writes findings to a local markdown file after each object. This is intentional:

- A single process model can consume 500-3000+ lines of context
- With 10+ objects, fetching all source code at once overflows the context window
- By processing sequentially and persisting to file, each object gets full attention
- If context fills up mid-review, a new agent can read the review file and resume from where it left off
- The review file is also the final deliverable — it builds up incrementally

**CRITICAL: Do NOT fetch all objects in parallel. Process them one at a time in the object review loop.**

---

## MANDATORY EXECUTION TRACKER

⚠️ **CRITICAL: You MUST maintain this execution tracker throughout the workflow**
⚠️ **Copy this tracker into your response and update it after EACH step**
⚠️ **If any step shows ❌, you are FORBIDDEN from proceeding to the next step**

```
CODE REVIEW WORKFLOW EXECUTION TRACKER - GAMS-XXXX
===================================================
Step 1: Get JIRA Ticket & Package URL  [ ] ❌ NOT STARTED
Step 2: Get Package Contents           [ ] ❌ NOT STARTED
Step 3: Setup Review & App Validation  [ ] ❌ NOT STARTED ⚠️ REQUIRED TOOL: get_application_info
Step 4: Object Review Loop             [ ] ❌ NOT STARTED ⚠️ PER-OBJECT SEQUENTIAL
  Object 1/N: {name}                   [ ] ❌
  Object 2/N: {name}                   [ ] ❌
  ...
Step 5: Compile Final Report           [ ] ❌ NOT STARTED
Step 6: Present & Export               [ ] ❌ NOT STARTED

BLOCKING RULES:
- Cannot proceed to Step 2 until Step 1 shows ✅
- Cannot proceed to Step 3 until Step 2 shows ✅
- Cannot proceed to Step 4 until Step 3 shows ✅
- Cannot proceed to next object until current object shows ✅
- Cannot proceed to Step 5 until ALL objects in Step 4 show ✅
- Cannot proceed to Step 6 until Step 5 shows ✅

CURRENT STATUS: Workflow not started
NEXT REQUIRED ACTION: Execute Step 1
REVIEW FILE: review-documents/{ticket-or-package-id}-review.md
```

**HOW TO USE THIS TRACKER:**
1. Copy the tracker into your response at the start of the workflow
2. After completing each step, update the tracker:
   - Change [ ] to [✅] for completed steps
   - Change ❌ NOT STARTED to ✅ COMPLETED with tool name
3. Show the updated tracker in EVERY response
4. Check BLOCKING RULES before proceeding to next step
5. If you cannot show ✅ for a step, you MUST stop and complete it
6. In Step 4, update the object list with actual names from Step 2 and mark each ✅ as completed

**EXAMPLE AFTER STEP 4 OBJECT 2:**
```
Step 4: Object Review Loop             [ ] 🔄 IN PROGRESS (2/7 complete)
  Object 1/7: AS GSS Add Eval Vendors [✅] ✅ COMPLETED
  Object 2/7: AS_GSS_BL_calcScore     [✅] ✅ COMPLETED
  Object 3/7: AS GSS Create Eval      [ ] ❌ NEXT
  ...
```

---

## Execution Steps

### Step 1: Get JIRA Ticket and Package URL

⚠️ **BEFORE STARTING:** Show the execution tracker with Step 1 marked as IN PROGRESS

**Path A — User provides JIRA ticket key:**
1. Call `mcp_jira_get_jira_issue` with the ticket key
   - Fields: `summary`, `description`, `customfield_10227`, `customfield_10173`, `status`, `assignee`
   - Expand: `["changelog"]` — needed for reference date extraction
2. Extract:
   - `fields.summary` → Ticket title
   - `fields.description` → Full description (contains SETUP, STEPS, OBSERVATION, EXPECTATION, REMEDIATION)
   - `fields.customfield_10227` → Acceptance criteria
   - `fields.customfield_10173` → Package URL
   - `fields.status.name` → Ticket status
   - `fields.assignee.displayName` → Assignee name
3. **Extract reference date from JIRA changelog** (for diff context in Step 4):
   - Scan `changelog.histories` for `field === "status"` entries
   - Find the FIRST entry where `toString === "Technical Design"` → use its `created` timestamp
   - If no "Technical Design" found, fallback to FIRST `toString === "In Progress"` → use its `created` timestamp
   - Convert to ISO-8601 UTC format
   - Store as `reference_date` — used in Step 4a for `get_object_diff`
   - If no status transitions found at all, `reference_date = null` (diff will be skipped)

4. **Verify baseline version using `get_version_context`** (only if `reference_date` is available):
   - Pick the first diffable object from the package (skip Record Types — they don't support diff)
   - Call `mcp_jarvis_get_version_context` with `uuid`, `typeId`, `dateTime: reference_date`
   - This returns 3 versions before and 3 after the reference date, each with `versionNumber`, `modifiedOn`, `modifiedBy`
   - Cross-reference with the ticket assignee (`fields.assignee.displayName`):
     1. Look at the `after` versions — find the FIRST version modified by the assignee
     2. The correct baseline is the version IMMEDIATELY BEFORE that first assignee change
     3. If the assignee doesn't appear in any `after` versions, use the last `before` version as baseline
     4. If the assignee name doesn't match any version author, fall back to dateTime-based version
   - If the verified baseline differs from what dateTime alone would give, note that per-object version resolution is REQUIRED in Step 4a
   - Store as `verified_baseline_version` (integer or null) alongside `reference_date` — this value is ONLY for the sample object checked here. DO NOT reuse this version number for other objects. Each object in Step 4a must resolve its own baseline independently.

5. If no package URL found, ask the user for the package URL or object names

**Path B — User provides package URL directly:**
1. Use the provided URL. Ticket key = "NO-TICKET" unless user provides one.
2. `reference_date = null` — diff context is not available without a JIRA ticket.
   - If the user provides a dateTime alongside the package URL, use that as `reference_date`.

**Path C — User provides object name(s) for standalone review:**
1. Resolve UUID via `mcp_appian_search_objects_by_name`
2. If multiple results, ask user which object they meant
3. Skip Step 2, go directly to Step 3 with the resolved object(s)
4. `reference_date = null` — diff context is not available for standalone review.

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 1 as ✅ COMPLETED. Note the `reference_date` value (or "N/A" if not available).

### Step 2: Get Package Contents

⚠️ **BLOCKING CHECK:** Verify Step 1 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 1.

1. Call `mcp_appian_get_package_contents_from_url` with the package URL
2. Parse the response to get the list of objects with names, types, and **UUIDs**
3. Filter objects for review:
   - **REVIEW**: Objects with type containing `Interface`, `ExpressionRule`, `ProcessModel`, `RecordType`, `Constant`, etc.
   - **SKIP**: Objects with type `CollaborationDocument` (these are i18n bundle files — not code)
4. **Sort objects for processing order** (lightweight first, heavyweight last):
   - Constants → Expression Rules → Interfaces → Record Types → Process Models
   - This ensures lightweight objects are persisted before heavyweight ones consume context
5. **Tag objects requiring SQL verification** — mark objects in the tracker with ⚡ when they need database checks:
   - QE_ or QR_ prefix → ⚡
   - Record Type → ⚡
   - Process Model → ⚡ (verify during review if it has Write to Data Store nodes)
   - Other objects → check source code for query patterns during Step 4a

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 2 as ✅ COMPLETED, show object count and sorted list

### Step 3: Setup Review Document & Application Validation

⚠️ **BLOCKING CHECK:** Verify Step 2 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 2.

This step creates the review markdown file and validates the application context. No object source code is fetched yet.

**Step 3a: Determine Application UUID**

1. Extract application prefix from object names (from Step 2):
   - Look at the first part of object names before the first underscore or space
   - Common prefixes: `AS_VM_*`, `AS_GSS_*`, `AS_GAM_*`, `AS_CO_*`, `AS_FRM_*`
2. Look up appUuid from `get_jarvis_config` response:
   - Match the prefix against `appPrefix` in each application's `appConfig`
   - Extract the `appUuid` for the matched application
3. If appUuid not found: STOP and ask user

**Step 3b: Call get_application_info**

1. Call `mcp_appian_get_application_info` with the appUuid
2. Extract: `namingConvention`, `ruleFolderDetails[]`
3. Verify object name prefix matches `namingConvention`
   - If mismatch: STOP and report error

**Step 3c: Create Review Document**

Create the review markdown file at `review-documents/{ticket-key}-review.md` (or `review-documents/review-{package-id}.md` if no ticket).

Write the initial header:

```markdown
# Code Review: {TICKET_KEY} — {Ticket Title}

**Status:** In Progress (0/{total} objects reviewed)
**Package:** {package_url}
**Application:** {app_name} ({namingConvention})
**Date:** {today}
**Reviewed By:** JARVIS

## Review Summary

| Field | Value |
|-------|-------|
| Ticket | {TICKET_KEY}: {Title} |
| Package | {package_url} |
| Application | {app_name} ({namingConvention}) |
| Objects | {count} ({type breakdown}) |
| Reviewed By | JARVIS |
| Date | {today} |
| Reference Date | {reference_date or "N/A"} |
| Verdict | Pending |

## Objects to Review

{numbered list of objects in processing order with type}

---
```

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 3 as ✅ COMPLETED, show review file path

**Step 3d: KB Pre-Analysis (OPTIONAL — when kbFolderId exists)**

⚠️ **CONDITION:** Only run if the matched application has a `kbFolderId` in the `get_jarvis_config` response. If not available, skip this sub-step.

**KB freshness check (before any KB calls):**
1. Check the `staleCount` field from the `get_jarvis_config` response for the matched application
2. If staleCount is 0 → proceed silently
3. If staleCount > 0 → **STOP. Your NEXT message to the user MUST be:**
   > **KB Status:** {count} objects have changed since last generation.
   > Changed objects (showing first 5): {list}
   > Shall I proceed with the KB, or would you like to refresh first?
4. Wait for user confirmation before proceeding

This sub-step adds contextual intelligence to the review document BEFORE diving into per-object review. It answers "why do these objects matter?" and "what's the blast radius?"

```
1. Feature context — understand what feature these objects belong to:
   Tool: mcp_jarvis_jarvis_search_objects
   Input: parentFolderId={kbFolderId}, query={primary keyword from object names}
   
   From the results, identify which cluster(s) the package objects belong to.
   Then optionally:
   Tool: mcp_jarvis_jarvis_get_cluster
   Input: parentFolderId={kbFolderId}, clusterName={identified cluster}
   
   Purpose: Understand the feature context — what other objects are in this feature,
   how the package objects fit into the bigger picture.

2. Impact pre-computation — blast radius for modified objects:
   Tool: mcp_jarvis_jarvis_get_impact_analysis
   Input: parentFolderId={kbFolderId}, objectName={name of key modified object}
   
   Run for the 2-3 most important objects in the package (Process Models, Record Types first).
   
   Purpose: Pre-compute blast radius so per-object findings in Step 4 can reference
   "this object is called by 47 others across 10 clusters" without additional API calls.

3. Write KB context to review document:
   Append after the Review Summary section:

   ## KB Context
   
   **Feature:** {cluster name} ({member count} objects)
   **Key objects in this feature:** {top 5-10 from cluster, highlighting which are in the package}
   
   **Impact Summary:**
   | Object | Direct Callers | Transitive Callers | Affected Clusters | Risk |
   |--------|---------------|-------------------|-------------------|------|
   | {name} | {count} | {count} | {count} | {Low/Med/High} |
   
   This context helps the reviewer understand WHY findings matter — a naming issue
   in a utility shared across 10 clusters is more important than the same issue in
   a leaf interface used by one page.

Budget: 2-4 KB calls. Skip if kbFolderId not available.
```

---

### Step 4: Object Review Loop (SEQUENTIAL — ONE AT A TIME)

⚠️ **BLOCKING CHECK:** Verify Step 3 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 3.

⚠️ **CRITICAL: Process objects ONE AT A TIME. Do NOT fetch all objects in parallel.**
⚠️ **After each object, write findings to the review file. Source code falls out of context.**

For each object in the sorted list from Step 2, execute sub-steps 4a through 4f:

**Step 4a: Fetch Source Code + Diff (parallel within object)**

Call these in parallel for the current object:
- `mcp_jarvis_get_appian_object` with object UUID, name, type
- `mcp_jarvis_get_version_context` with THIS object's UUID, typeId, dateTime: `reference_date` — **MANDATORY for every diffable object**. Each object has its own independent version history. DO NOT reuse a version number from another object.
  - Use the assignee logic: find the FIRST `after` version by the assignee → baseline is the version immediately before it.
  - Then call `get_object_diff` with the resolved `versionNumber` for THIS specific object.
  - ⚠️ **CRITICAL: Version numbers are per-object. Object A might be at v5 while Object B is at v52. You MUST resolve each one individually.**
- If `reference_date` is null (Path B/C without dateTime): skip the diff call entirely

**Diff call rules:**
- If `reference_date` is `null` (Path B/C without dateTime): skip the diff call entirely
- If the object is a Record Type (typeId is null from package contents): skip the diff call
- If the diff call fails: log the error and continue without diff context — do NOT block the review
- The diff result tells you: `change_type` (NEW / MODIFIED / UNCHANGED), old vs latest SAIL code

From get_appian_object, extract: `name`, `description`, `parentFolder`, source code/config, `inputs[]`

**Database verification (MANDATORY when object interacts with database) — jarvis-smt integration:**

SQL verification is required when the object's source code interacts with the database in any way. Detect by checking the source code for these patterns:

| Trigger | What to check | SQL to run |
|---------|--------------|------------|
| Object prefix is QE_ or QR_ | Table columns match query fields, filter columns indexed | `DESCRIBE Appian.{TABLE_NAME}`, `SHOW INDEX FROM Appian.{TABLE_NAME}` |
| Source contains `a!queryEntity` or `a!queryRecordType` (any object type) | Table columns match query fields | `DESCRIBE Appian.{TABLE_NAME}` |
| Source references `cons!*_ENT_*` (Data Store Entity constant) | Table exists | `DESCRIBE Appian.{TABLE_NAME}` |
| Object is a Record Type | Source table columns match Record Type fields, FK columns have indexes | `DESCRIBE Appian.{TABLE_NAME}`, `SHOW INDEX FROM Appian.{TABLE_NAME}` |
| Object is a Process Model with Write to Data Store / Execute Stored Procedure nodes | Target table exists with correct columns | `DESCRIBE Appian.{TABLE_NAME}` |
| JIRA ticket mentions new table creation | Tables were actually created with correct columns | `DESCRIBE Appian.{TABLE_NAME}` for each new table |

**SMT-enhanced checks (run alongside standard verification):**

| Additional Check | SQL to run | Flag if... |
|-----------------|------------|------------|
| Pending migrations for this table | `SELECT cr.changeRequestId, cr.title, cr.status FROM Appian.SMT_CHANGE_REQUEST cr WHERE cr.tableName = '{TABLE}' AND cr.status NOT IN ('DEPLOYED', 'CANCELLED') LIMIT 5` | Pending migration exists — code may reference columns not yet deployed |
| Index coverage for query filter columns | `SHOW INDEX FROM Appian.{TABLE_NAME}` | Columns used in `a!queryFilter(field: "X")` lack an index — flag as Medium (performance) |
| Column existence for new fields | `DESCRIBE Appian.{TABLE_NAME}` | Code references a column that doesn't exist in the table — flag as Critical |

**When to flag SMT findings:**
- **Critical:** Code references a column that doesn't exist → "Column `{col}` not found in table. Check if DDL migration has been deployed."
- **Medium:** Query filters on a column without an index → "Column `{col}` used in filter but has no index. Consider adding one via SMT."
- **Info:** Pending migration exists for the table → "Note: SMT change request `{title}` is pending for this table."

**Skip SQL verification ONLY when:** The object has no database interaction — pure UI interfaces (FM_, SCT_, CPS_ without inline queries), pure logic rules (BL_, VD_, UT_ without query patterns), and constants that don't reference Data Store Entities.

**Budget:** 1-3 SQL calls per database-interacting object (DESCRIBE + SHOW INDEX + optional SMT check).

**Step 4b: Write Implementation Notes**

⚠️ **Only if diff data is available from Step 4a.** If no diff (reference_date was null, Record Type, or diff call failed), skip this sub-step.

Using the old and latest SAIL code from the diff result, write a human-readable "Implementation Notes" section that summarizes what changed. This goes BEFORE the code review findings.

**Writing style — like a developer explaining their PR to a reviewer:**
- Concise, clear, well-formatted
- Use plain language — not raw diff output
- Reference actual field/variable names but don't dump code
- Focus on the "what" and "why", not line-by-line changes
- 3-6 bullet points max per object — don't overwhelm the reviewer
- For NEW objects: briefly describe what the object does
- For UNCHANGED objects: note "No changes in this ticket" and skip the bullets

**Good example:**
> Added a `triggerRefresh` parameter to the winning vendors grid so it refreshes after record actions. Previously the grid was stale until page reload.

**Bad example:**
> Line 47: Added parameter triggerRefresh: ri!triggerRefresh to rule!AS_GSS_GRD_displayListOfWinningVendors call. Old version had 3 parameters, new version has 4 parameters.

**Category tagging** — tag each object's changes with one or more:
- UI Change — layout, styling, labels, visibility, component additions/removals
- Logic Change — conditions, calculations, query filters, business rules
- Data Model Change — record type fields, relationships, views, actions
- Config Change — constants, connected systems, integration endpoints
- New Object — created after the reference point

**Step 4c: Run Automated Analysis**

Call `mcp_jarvis_analyze_appian_code` with object UUID and name.
This returns complexity metrics, best practices issues, and performance issues.

**Step 4d: Naming & Folder Validation**

- Verify object name starts with `{namingConvention} ` or `{namingConvention}_`
  - Valid: "AS GSS FM Dashboard", "AS_GSS_FM_Dashboard"
  - Invalid: "ASGSS_FM", "AS-GSS FM", "GSS_FM"
  - Flag violations as CRITICAL
- Verify `parentFolder` matches one of `ruleFolderDetails[].name` from app info
  - Flag wrong folder as HIGH
  - Suggest correct folder based on object type:
    - Constants → folder with "Constants" in name
    - Interfaces/Expression Rules → folder with "SAIL" or "Design Objects" in name

**Step 4e: Dynamic Checklist Review**

**Diff-aware review guidance:** When diff data is available, use it to distinguish between issues introduced in this ticket vs pre-existing issues:
- If a finding exists in code that was ADDED or CHANGED in this ticket → flag as **New** (introduced in this ticket)
- If a finding exists in code that was UNCHANGED from the old version → flag as **Pre-existing**
- If no diff data is available → flag as **N/A** (cannot determine)
- Pre-existing issues are still worth noting but should not block the review

**Dynamic checklist procedure:**

⚠️ **CRITICAL RULES:**
- **DO NOT invent checklist items.** Only review against items returned by `get_review_checklist`. If an item is not in the API response, it does not exist for this review.
- **DO NOT skip any checklist item.** Every item returned by the API that applies to the current object type MUST be evaluated. No exceptions, no shortcuts.
- **DO NOT downgrade severity.** The `severity` field from the API is FINAL. You report it exactly as returned (Critical, High, Medium, Low). You may add a `[Pre-existing]` or `[New]` tag but NEVER change the severity value. High stays High even if pre-existing.
- **DO NOT batch objects.** Even if 10 objects have identical changes, each object MUST be evaluated independently against the full applicable checklist. "Same pattern as Object 2" is NOT a valid reason to skip evaluation.
- **DO NOT write findings without running `analyze_appian_code`.** Step 4c is mandatory for EVERY object. If you reach Step 4f and realize you skipped 4c, STOP and run it now before writing findings.
- The API response is the single source of truth. Nothing more, nothing less.

1. **Call `get_review_checklist`** (no params — gets full checklist). Call once per review session and cache the response. Do NOT call per object.

2. **Filter cached items for the current object** using the `applicableObjectTypes` array on each item. Match the object type string from the package contents directly:
   - Interface → `"Interface"`
   - Expression Rule → `"Expression Rule"`
   - Process Model → `"Process Model"`
   - Record Type → `"Record Type"`
   - Constant → `"Constant"`
   - Integration → `"Integration"`
   - Connected System → `"Connected System"`
   - Data Type → `"Data Type"`
   - Web API → `"Web API"`

3. **For each applicable checklist item**, review the object's source code against:
   - The item's `description` — explains what to look for
   - The item's `examples` (goodExample/badExample) — pattern reference for violations
   - The item's `severity` — determines how to classify the finding (Critical, High, Medium, Low)

4. **Record results:**
   - If violation found → add to findings with the item's severity and label
   - If pass → no action needed (don't list passes in the review document)

5. **Suppression rule** (reconcile with `analyze_appian_code` results from Step 4c):
   - If `analyze_appian_code` flagged something that **IS** in the active checklist (match by `label` text or explicit description keyword) → use the analyzer's finding
   - If `analyze_appian_code` flagged something that is **NOT** in the active checklist → **suppress it** from the findings table (do not report as a finding)
   - **Match strictness:** Match must be by explicit `label` text or specific description keyword from the checklist item. DO NOT infer a match from broad category names like "Formatting", "Best Practices", or "Code Reusability". If the analyzer finding doesn't map to a specific checklist item's label or description, it is NOT a match.
   - Suppressed findings that are genuinely useful should be captured in the "Analyzer Observations" section (see Step 4f) — they are informational only, not findings.
   - This ensures only team-approved checks appear in the review findings table

**NOTE:** For Record Types, `analyze_appian_code` automatically routes to the Record Type analyzer. Manual review should focus on business logic correctness, security appropriateness, and action visibility alignment.

**DEEP ANALYSIS (Optional):** For Record Types with relationships, consider running `validate_record_relationships` to check bidirectional relationships and dual-record migration patterns.

**For Internationalization — AUTOMATED i18n AUDIT (jarvis-i18n integration):**

⚠️ **This check is now partially automated.** For Interfaces and Expression Rules with user-facing text:

1. **Scan source code for hard-coded strings** in these parameters:
   - `label:`, `instructions:`, `placeholder:`, `helpTooltip:`, `accessibilityText:`
   - `validationMessage:`, `confirmHeader:`, `confirmButtonLabel:`
   - Any string literal in a display context (not variable names or technical values)

2. **For each hard-coded string found**, determine if a key already exists:
   - **BND apps** (GSS, VM, GCW, RM, AM): Query `Appian.BND_Key` table:
     ```sql
     SELECT k.keyname, k.enuslabel, b.bundlename
     FROM Appian.BND_Key k
     JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
     JOIN Appian.SMT_Application a ON b.appid = a.appid
     WHERE a.appdbtableprefix = '{APP_PREFIX}'
     AND k.enuslabel = '{HARD_CODED_TEXT}'
     AND k.isdeleted = 0
     LIMIT 5
     ```
   - **Translation Set apps** (GSM): Use `jarvis_get_translation(parentFolderId, query="{text}")` 

3. **Report findings with actionable recommendations:**
   - If key EXISTS → "Use existing key `{keyname}` from bundle `{bundlename}`"
   - If key does NOT exist → "Create new key: `{suggested_prefix}_{SuggestedName}` with value `{text}`"
   - Suggested prefix based on parameter context: label→`lbl_`, button→`btn_`, validation→`vld_`, placeholder→`plc_`, tooltip→`hlp_`, accessibility→`acs_`, instruction→`ins_`, general text→`txt_`

4. **Budget:** 1-2 SQL calls per object (batch all hard-coded strings into one LIKE query if possible)

**Checklist items (covered by dynamic checklist above — verify edge cases manually):**
- All display text internationalized with bundle keys? (automated scan above catches most)
- Bundle keys use correct prefixes (acs_, btn_, lbl_, txt_, vld_, etc.)?
- No label concatenation in code (e.g., `& " " &` between displayLabel calls)?

**For Process Models — Manual Business Logic Review:**

NOTE: The automated analyzer already runs 47 structural checks covering naming, security, alerts, archiving, flow, expressions, variables, and performance. The dynamic checklist (above) covers structural PM checks (naming, security, alerts, archiving). The manual review below focuses on what neither the analyzer NOR the checklist can assess — business logic correctness and design intent.

- Does the process implement what the ticket describes?
- Are lane assignments appropriate? (correct teams/roles, not everything in one lane)
- Is subprocess decomposition logical?
- Are alert recipients appropriate for the business context?
- Do user task forms reference correct interfaces?
- Do XOR gateway conditions cover all business scenarios?
- Is error handling adequate?
- Are process variable types appropriate for data being stored?
- Are integration/subprocess timeouts and retries configured where needed?

Key things to check manually that automated analysis misses:
- **Accessibility**: a11y text, labels, screen reader support
- **Internationalization**: Verify automated i18n scan results (Step 4e Section 9). Manually check edge cases: dynamic key construction, conditional labels, rich text with embedded strings
- **Business-configurable values**: Decimal weights/thresholds/percentages should be constants
- **Ticket requirements**: Does the code actually fix what the ticket describes?
- **Parameter descriptions**: Are rule inputs documented?
- **Database alignment** (MANDATORY for all database-interacting objects): Verify DESCRIBE results match columns referenced in SAIL code, Record Type fields, or Process Model write targets. Flag missing columns, missing indexes on FK columns, or table-not-found as HIGH severity findings. Check SMT pending migrations if flagged in Step 4a. Check the SQL verification trigger table in Step 4a to determine if this applies.

**Step 4f: Write Object Findings to Review File**

⚠️ **CRITICAL: This step MUST happen before moving to the next object.**

⚠️ **PRE-WRITE CHECKPOINT:** Before writing ANY findings, verify:
1. `analyze_appian_code` was called for this object in Step 4c. If not → STOP, call it now.
2. Every applicable checklist item was evaluated (not skipped). If you reviewed 40 items for the previous object of the same type, you must review 40 items for this one too.
3. Severity values match the API exactly. If the checklist says High, you write High — not Low, not Medium.

Append the following to the review markdown file for the current object:

```markdown
## Object {N}: {object_name} ({object_type})
```

**If diff data is available, write the Implementation Notes section next:**

```markdown
### Implementation Notes

**Change Type:** {MODIFIED / NEW / UNCHANGED} | **Versions:** v{old} to v{latest}

- {Concise, human-readable change description}
- {Another change}
- {Another change}
```

For UNCHANGED objects, write: `No changes were made to this object in this ticket.`

For NEW objects, write a brief description of what the object does.

**Then write the findings:**

```markdown
### Findings

| # | Severity | Finding | Recommendation |
|---|----------|---------|----------------|
| 1 | {sev} | [{category}] {finding} | {recommendation} |
| ... | ... | ... | ... |
```

Severity values: Critical, High, Medium, Low. Category is merged into the Finding column in brackets (e.g., "[Commenting] Rule inputs have empty descriptions").

Do NOT include a Scope column. Do NOT include emoji icons in any column.

If the object has no issues, write "No issues found." instead of the findings table.

**Then write the checklist status as a single line:**

```markdown
**Checklist:** {N} items evaluated ({pass} pass, {fail} fail → see findings, {na} N/A) | i18n: Pass
```

The count MUST match the number of applicable items returned by `get_review_checklist` for this object type. If the API returned 42 items for "Interface" and you report "42 items evaluated", that's verifiable. If you report "38 items evaluated", explain why 4 were skipped.

Use "Pass" for i18n/SQL if no issues, "See findings" if issues were flagged, "N/A" if not applicable. Keep it on one line — do NOT use a table for the checklist.

Only mention SQL verification if there was an actual finding. Do NOT write "N/A — no database interaction" — just omit it.

**Then write Analyzer Observations (optional — only if suppressed findings exist):**

If `analyze_appian_code` flagged issues that were suppressed per the checklist rule (no matching checklist item) but are genuinely useful observations, include them here. This section is **informational only** — it does NOT contribute to the verdict, scorecard, or checklist status.

```markdown
**Analyzer Observations (informational — not in active checklist):**
- {observation from analyzer, e.g., "Deep nesting detected (11 levels) in conditional logic"}
- {another observation}
```

Omit this section entirely if there are no suppressed findings worth surfacing. Do NOT include trivial or obvious observations.

**Then write positives:**

```markdown
**Positives:**
- {Thing this object does well}
- {Another positive}
- {Another positive}
```

```markdown
---
```

After writing, update the review file status line: `**Status:** In Progress ({completed}/{total} objects reviewed)`

⚠️ **AFTER COMPLETING EACH OBJECT:** Update tracker - mark the object as ✅ in the object list
⚠️ **AFTER ALL OBJECTS COMPLETE:** Update tracker - mark Step 4 as ✅ COMPLETED

---

### Step 5: Compile Final Report

⚠️ **BLOCKING CHECK:** Verify ALL objects in Step 4 show ✅ COMPLETED. If any object is missing, STOP and complete it.

Read the review markdown file to compile the final sections. The per-object findings are already written — now add the cross-cutting analysis.

**Step 5a: Overall Scorecard**

Read all per-object findings from the review file and compile the overall scorecard. Append to the review file after the Review Summary section:

```markdown
## Overall Scorecard

| Category | Status | Summary |
|----------|--------|---------|
| Naming Convention | Pass / Warning / Fail | {X/Y objects follow convention} |
| Folder Location | Pass / Warning / Fail | {X/Y in correct folders} |
| Performance | Pass / Warning / Fail | {summary of perf issues} |
| Best Practices | Pass / Warning / Fail | {summary} |
| Security | Pass / Warning / Fail | {summary} |
| Process Model Health | Pass / Warning / Fail | {PM-specific, if applicable} |
```

Use: Pass = No issues, Warning = Minor/non-blocking, Fail = Significant/must address

**Step 5b: Ticket Fix Verification**

If a JIRA ticket was provided, verify ticket requirements against the reviewed code:

```markdown
## Ticket Fix Verification

**Ticket Requirement:** {what the ticket asked for}

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | {requirement} | Met / Not Met | {evidence from code} |
| ... | ... | ... | ... |

**Verdict:** All requirements addressed / Missing requirements
```

If no ticket (package URL only), write: "N/A — Review initiated from package URL without JIRA ticket."

**Step 5c: Cross-Object Analysis**

Analyze patterns across all objects using the persisted findings:

```markdown
## Cross-Object Analysis

- {naming consistency observations}
- {duplicate logic across objects}
- {dependency cross-references}
- {shared patterns or antipatterns}
```

**Step 5d: Positives & Recommendations**

```markdown
## Positives

- {3-5 things the code does well across all objects}

## Recommendations

1. **[{severity}]** {most important recommendation}
2. **[{severity}]** {second recommendation}
3. **[{severity}]** {third recommendation}
```

**Step 5e: Update Verdict and Status**

Update the Review Summary table in the review file:
- Change `Verdict` from `Pending` to one of:
  - `Approved` — No critical or high issues
  - `Approved with Comments` — No critical issues, some high/medium
  - `Needs Rework` — Critical issues that block deployment
- Change `Status` from `In Progress` to `Complete`

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 5 as ✅ COMPLETED

---

### Step 6: Present Review & Export to Google Doc

⚠️ **BLOCKING CHECK:** Verify Step 5 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 5.

**Step 6a: Present Review in Chat**

Present the complete review in chat by reading the review file and outputting it as a formatted markdown response. Include all sections:
1. Review Summary with Verdict
2. Overall Scorecard
3. Ticket Fix Verification
4. Per-Object Findings (condensed — Implementation Notes + findings tables and checklist status)
5. Cross-Object Analysis
6. Positives
7. Recommendations

**Step 6b: Ask About Google Doc Export**

After presenting the review, ask the user:

> "Would you like me to export this review to Google Docs? I'll create it in the team's shared Drive folder."

**If user says yes:**

1. Read the `get_jarvis_config` response to get the drive folder:
   - Use `reviewDocFolderId` for the matched application if it exists
   - Fall back to `designDocFolderId` if `reviewDocFolderId` is not configured
2. Read the review markdown file content
3. Call `mcp_google_workspace_import_to_google_doc` with:
   - `file_name`: "Code Review - {TICKET_KEY} - {Title}" (or "Code Review - {package-id}" if no ticket)
   - `content`: The full review markdown content
   - `source_format`: "md"
   - `folder_id`: The drive folder ID from the config response
   - `user_google_email`: User's Google email
4. Return the Google Doc link to the user
5. Also provide the Drive folder link: `https://drive.google.com/drive/folders/{folder_id}`

**If user says no:**
- Confirm the local review file path: `review-documents/{filename}.md`
- Done.

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 6 as ✅ COMPLETED

---

## CONTEXT TRANSFER RESILIENCE

If context fills up during the object review loop (Step 4), a new agent can resume:

1. Read the review file from `review-documents/` to see which objects are already reviewed
2. Check the execution tracker in the last message to see current progress
3. Continue from the next unreviewed object
4. The review file is the source of truth — not agent memory

**File naming convention:**
- With ticket: `review-documents/GAMS-7081-review.md`
- Without ticket: `review-documents/review-{package-id}.md`
  - Package ID is extracted from the URL: `https://...appianpreview.com/suite/design/package/{PACKAGE-ID}`

---

## Section 2: Category Tags & Severity Guidelines

### Category Tags for Findings

- `[Naming Convention]` — Object name doesn't follow app naming standard
- `[Folder Location]` — Object in wrong folder
- `[Null Safety]` — Missing null checks, unsafe indexing
- `[Performance]` — Queries in saveInto, sync processes, polling, unbounded data
- `[Complexity]` — Deep nesting, too many local variables, large objects
- `[Reusability]` — Duplicate code, logic that should be extracted
- `[Naming]` — Variables, rules, or constants not following conventions
- `[Commenting]` — Missing or inadequate comments
- `[Accessibility]` — Missing labels, a11y text, screen reader support
- `[i18n]` — Hardcoded text, missing bundle keys
- `[State Management]` — Improper state handling, missing triggerRefresh
- `[Security]` — Missing security groups, improper access control
- `[Scope]` — Object doing too much, inputs/outputs misaligned
- `[Formatting]` — Code legibility, parameter ordering
- `[Deprecation]` — Unreferenced objects, missing deprecation markers
- `[Testing]` — Missing test cases, weak assertions

### Severity Guidelines

- **Critical** — Blocks deployment. Naming convention violations, security vulnerabilities, data loss risk, synchronous process calls blocking UI, broken functionality.
- **High** — Should fix before merge. Wrong folder location, deep nesting (>6 levels), missing null safety on critical paths, queries in saveInto, >30 local variables.
- **Medium** — Should fix soon. Missing comments on complex logic, moderate complexity, missing executeWhen on queries, duplicate patterns.
- **Low** — Nice to have. Magic numbers, minor formatting, missing comments on obvious code, minor naming inconsistencies.

---

## Section 3: SOLUTIONS Design Best Practices Checklist (Fallback/Documentation)

The primary checklist source for Step 4e is the **`get_review_checklist` API** (dynamic, team-managed). The static file below serves as:
- **Documentation** — full reference for what each checklist item means
- **Fallback** — use only if the API is unreachable during a review session

#[[file:.kiro/steering/appian-best-practices-checklist.md]]

**Quick Reference:**
- **Interfaces (FM, CPS, SCT, GRD):** Focus on sections 1, 6, 9
- **Expression Rules (BL, QE, QR):** Focus on sections 1, 5
- **Record Types (_RecordType, _SYNCEDRECORD, _RECORD):** Focus on section 3 (automated analyzer handles this)
- **Process Models (PM):** Focus on sections 1, 7
- **Constants:** Focus on section 4
- **CDTs/Data Types:** Focus on section 2

---
