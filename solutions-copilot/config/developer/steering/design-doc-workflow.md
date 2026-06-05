---
inclusion: auto
---

# Design Document Creation Workflow

## ⚠️ KB-FIRST APPROACH — READ FIRST

**This workflow uses the Jarvis Knowledge Base (KB) as the PRIMARY research source when available.**
**The KB replaces the Atlas power for codebase research. Atlas is no longer required.**

When the target application has a `kbFolderId` in the `get_jarvis_config` response:
- Track A uses KB tools (jarvis_get_app_tree, jarvis_search_objects, jarvis_get_cluster, etc.)
- Track B uses live API for recently created objects and database verification
- Step 3.5 uses jarvis_get_impact_analysis instead of sequential get_object_dependencies calls

When the application does NOT have a `kbFolderId`:
- Track A is skipped entirely
- Track B (live API) is the only research source

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING:**

1. ✅ **SHOW THE EXECUTION TRACKER** - Copy the tracker template below and paste it in your response RIGHT NOW
2. ✅ **READ THIS ENTIRE WORKFLOW FILE** - Don't skip ahead, don't assume you know the steps
3. ✅ **IDENTIFY YOUR STARTING POINT** - Determine which step you're on based on user input
4. ✅ **VERIFY BLOCKING RULES** - Check that previous steps are complete before proceeding

**IF YOU SKIP ANY OF THESE, YOU ARE VIOLATING THE WORKFLOW.**

**Common Triggers That Activate This Workflow:**
- "Start Design for GAMS-XXXX"
- "Create design document for [ticket]"
- "Design [JIRA ticket]"
- User selects option 1 from JARVIS menu

**When you see these triggers, your FIRST action is to show the tracker. Not call tools. Not retrieve tickets. SHOW THE TRACKER.**

---

## Overview
Automated workflow to create design documents from JIRA tickets with Appian KB-powered implementation design.

## Trigger
User says: **"Start Design for GAMS-XXXX"**

## CRITICAL RULES - MANDATORY COMPLIANCE
- ⚠️ STRICT ENFORCEMENT: Follow these steps EXACTLY in order. NO DEVIATIONS ALLOWED.
- ⚠️ STEP SKIPPING IS FORBIDDEN: Every step must be completed before proceeding to the next.
- ⚠️ TOOL SELECTION IS MANDATORY: Use the exact tools specified for each step (see Tool Selection Guide below).
- ⚠️ EXECUTION TRACKER IS MANDATORY: You MUST show the execution tracker in EVERY response and update it after each step.
- ⚠️ BLOCKING CHECKS: Before starting any step, verify the previous step shows ✅ in the tracker. If not, STOP IMMEDIATELY.
- Build the entire document as a local HTML file, then import as Google Doc (2 API calls)
- Call `get_jarvis_config` to determine appUuid for package creation
- If app cannot be determined from JIRA ticket, ask the user

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
⚠️ DO NOT apply patterns from Code Review Workflow or Implementation Workflow
⚠️ DO NOT review code (that's code review workflow)
⚠️ DO NOT create objects (that's implementation workflow)
⚠️ THIS WORKFLOW: Create design doc → Save locally → Optionally export to Google Docs → Create empty package

**Key Differences:**
- **Design Doc Workflow:** Creates HTML file → Imports to Google Docs → Creates package (NO code review, NO object creation)
- **Implementation Workflow:** Creates Appian objects via Deployment API
- **Code Review Workflow:** Reviews existing code → Presents text response

**What This Workflow Does:**
1. Gets JIRA ticket information
2. Searches Atlas for implementation details
3. Analyzes dependencies for impact assessment
4. Creates HTML file with design document in design-documents/ folder
5. Optionally exports to Google Docs (if MCP available)
6. Creates empty package in Appian

**What This Workflow Does NOT Do:**
- ❌ Review code quality or best practices
- ❌ Create Appian objects (constants, interfaces, etc.)
- ❌ Deploy anything
- ❌ Present findings as text (creates Google Doc instead)

If you find yourself reviewing code or creating objects, STOP - you're in the wrong workflow.

## Tool Selection Guide: KB vs Live API

**Step 3 uses KB as the primary source (when kbFolderId exists) with live API for gaps:**

**Track A — KB (pre-computed intelligence):**
- ✓ Clusters show how objects work together as features
- ✓ 35 behavioral tags per object (entity-query, save-into, etc.)
- ✓ SAIL code with resolved UUIDs — human-readable
- ✓ Data model, architecture, patterns, shared objects — all pre-computed
- ✓ Dependency graph pre-computed — no sequential API calls
- ✗ Snapshot — objects created after last KB generation won't appear

**Track B — JARVIS MCP (live environment):**
- ✓ Sees ALL objects including recently created/undeployed
- ✓ Semantic search catches objects KB keyword search misses
- ✓ Database verification via query_sql
- ✗ No architectural context, patterns, or cluster groupings

**Step 3.25 merges the best of both:**
- KB provides the "how" (patterns, architecture, clusters, code examples)
- Live API provides the "what's new" (recently created objects, DB verification)

**If kbFolderId does NOT exist:** Track A is skipped entirely. Track B (live API) is the only source.

## MANDATORY EXECUTION TRACKER

⚠️ **CRITICAL: You MUST maintain this execution tracker throughout the workflow**
⚠️ **Copy this tracker into your response and update it after EACH step**
⚠️ **If any step shows ❌, you are FORBIDDEN from proceeding to the next step**

```
DESIGN WORKFLOW EXECUTION TRACKER - GAMS-XXXX
==============================================
Step 1: Get JIRA Ticket        [ ] ❌ NOT STARTED
Step 1.5: Mockup Check (i18n)  [ ] ❌ NOT STARTED (OPTIONAL - ask user)
Step 2: Determine Application   [ ] ❌ NOT STARTED  
Step 2.5: KB Freshness Check   [ ] ❌ NOT STARTED (skip if no kbFolderId)
Step 3: Research                       [ ] ❌ NOT STARTED ⚠️ REQUIRED: KB (if available) + JARVIS MCP
  Track A: KB Research                      [ ] ❌ (skip if no kbFolderId)
  Track B: JARVIS MCP Research              [ ] ❌
Step 3.25: Consolidate & Reconcile     [ ] ❌ NOT STARTED ⚠️ MERGE + VALIDATE
Step 3.75: Application Info     [ ] ❌ NOT STARTED ⚠️ REQUIRED TOOL: get_application_info
Step 3.8: Best Practices Review [ ] ❌ NOT STARTED
Step 3.9: Open Questions        [ ] ❌ NOT STARTED (OPTIONAL — skip if straightforward)
Step 4: Build HTML Document     [ ] ❌ NOT STARTED → design-documents/{TICKET}.html
Step 4.5: Export to Google Docs [ ] ❌ NOT STARTED (OPTIONAL — requires Google MCP)
Step 5: Create Package          [ ] ❌ NOT STARTED

BLOCKING RULES:
- Cannot proceed to Step 1.5 until Step 1 shows ✅
- Cannot proceed to Step 2 until Step 1.5 shows ✅ or ⏭️ SKIPPED
- Cannot proceed to Step 2.5 until Step 2 shows ✅
- Cannot proceed to Step 3 until Step 2.5 shows ✅ or ⏭️ SKIPPED
- Cannot proceed to Step 3.25 until Step 3 shows ✅ (both tracks complete)
- Cannot proceed to Step 3.75 until Step 3.25 shows ✅
- Cannot proceed to Step 3.8 until Step 3.75 shows ✅
- Cannot proceed to Step 3.9 until Step 3.8 shows ✅
- Cannot proceed to Step 4 until Step 3.9 shows ✅ or ⏭️ SKIPPED
- Cannot proceed to Step 4.5 until Step 4 shows ✅
- Cannot proceed to Step 5 until Step 4.5 shows ✅

CURRENT STATUS: Workflow not started
NEXT REQUIRED ACTION: Execute Step 1
```

**HOW TO USE THIS TRACKER:**
1. Copy the tracker into your response at the start of the workflow
2. After completing each step, update the tracker:
   - Change [ ] to [✅] for completed steps
   - Change ❌ NOT STARTED to ✅ COMPLETED with tool name
3. Show the updated tracker in EVERY response
4. Check BLOCKING RULES before proceeding to next step
5. If you cannot show ✅ for a step, you MUST stop and complete it

**EXAMPLE AFTER STEP 1:**
```
Step 1: Get JIRA Ticket        [✅] ✅ COMPLETED - mcp_jira_get_jira_issue called
Step 2: Determine Application   [ ] ❌ NOT STARTED
...
CURRENT STATUS: Step 1 complete
NEXT REQUIRED ACTION: Execute Step 2
```

## Workflow Steps

### Step 1: Get JIRA Ticket Information

⚠️ **BEFORE STARTING:** Show the execution tracker with Step 1 marked as IN PROGRESS

```
Tool: mcp_jira_get_jira_issue
Input: issue_key (e.g., "GAMS-7126")
Fields needed:
  - fields.summary → Ticket title
  - fields.description → Description
  - fields.customfield_10227 → Acceptance criteria
  - fields.parent → Parent epic (for app context)
  - fields.project.key → Project key (for app matching)
Output: JIRA URL = https://appian-eng.atlassian.net/browse/{TICKET_KEY}
```

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 1 as ✅ COMPLETED, show tool called

### Step 1.5: Mockup Check for Internationalization (OPTIONAL)

⚠️ **BLOCKING CHECK:** Verify Step 1 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 1.

⚠️ **BEFORE STARTING:** Update tracker - mark Step 1.5 as IN PROGRESS

```
PURPOSE: Extract user-facing strings from mockup to generate i18n bundle key-value suggestions.
THIS STEP IS OPTIONAL — if user has no mockup, mark as ⏭️ SKIPPED and proceed.

Process:
  1. ASK the user: "Do you have a mockup for this ticket? If yes, paste the Google Slides link."
  2. WAIT for user response before proceeding.
  
  If user provides a Google Slides link:
    a. Extract the presentation ID from the URL
    b. Tool: mcp_google_workspace_get_drive_file_content
       Input: file_id={presentation_id}, user_google_email={from config}
    c. Extract ALL user-facing strings from slide content:
       - Labels (field labels, section headers, tab names, column headers)
       - Button text (Submit, Cancel, Save, etc.)
       - Validation messages (required field, invalid input, etc.)
       - Placeholder text (Search..., Select a value, etc.)
       - Accessibility text (screen reader labels, aria descriptions)
       - Status text (Active, Inactive, Pending, etc.)
       - Tooltip text
    d. Generate i18n key-value pairs using prefix conventions:
       - lbl_ → Labels, headers, column names, tab names
       - vld_ → Validation messages
       - plc_ → Placeholder text
       - acs_ → Accessibility / screen reader text
       - txt_ → General text, descriptions, tooltips
    e. Key naming rules:
       - Use camelCase after prefix: lbl_vendorName, vld_requiredField
       - Keep keys descriptive but concise
       - Use [%1], [%2] for dynamic arguments: vld_maxLength=Must be [%1] characters or fewer
    f. Use = (equals sign) as the separator between key and value (NOT colon)
       - Good: lbl_vendorName=Vendor Name
       - Bad: lbl_vendorName:Vendor Name
    g. Store the generated key-value pairs for inclusion in the HTML document (Step 5)

  h. **DUPLICATE DETECTION (jarvis-i18n integration):**
     After generating key-value pairs, check if any of the proposed labels already exist:
     
     - **BND apps** (GSS, VM, GCW, RM, AM): Query for existing keys with matching labels:
       ```sql
       SELECT k.keyname, k.enuslabel, b.bundlename
       FROM Appian.BND_Key k
       JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
       JOIN Appian.SMT_Application a ON b.appid = a.appid
       WHERE a.appdbtableprefix = '{APP_PREFIX}'
       AND k.enuslabel IN ('{label1}', '{label2}', ...)
       AND k.isdeleted = 0
       LIMIT 30
       ```
     - **Translation Set apps** (GSM): Use `jarvis_get_translation(parentFolderId, query="{label}")` for each unique label
     
     For each match found:
       - Mark the key as "REUSE EXISTING" instead of "NEW"
       - Show: `lbl_VendorName → REUSE existing key "lbl_VendorName" from AS.VM.General`
     
     For keys with no match:
       - Mark as "NEW — to be created"
     
     Budget: 1-2 SQL calls (batch all labels into one IN clause)

  If user says no / no mockup available:
    - Mark Step 1.5 as ⏭️ SKIPPED in tracker
    - The INTERNATIONALIZATION section will NOT be included in the design doc
    - Proceed to Step 2

Output (if mockup provided):
  - List of i18n key-value pairs grouped by prefix type
  - Ready for inclusion in INTERNATIONALIZATION section of design doc
```

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 1.5 as ✅ COMPLETED (with mockup) or ⏭️ SKIPPED (no mockup)

### Step 2: Determine Application from JIRA Ticket

⚠️ **BLOCKING CHECK:** Verify Step 1.5 shows ✅ COMPLETED or ⏭️ SKIPPED in tracker. If not, STOP and complete Step 1.5.

⚠️ **BEFORE STARTING:** Update tracker - mark Step 2 as IN PROGRESS

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 1:
- ✅ Called mcp_jira_get_jira_issue with ticket key
- ✅ Retrieved fields: summary, description, customfield_10227, parent, project.key
- ✅ Have JIRA URL constructed
- ✅ Have ticket data ready for app matching

```
Process:
  - Call `get_jarvis_config` to get the list of registered applications
  - Match JIRA project key (e.g., "GAMS") against `jiraProjects` in each application
  - Also match parent epic name, description against `appPrefix` and `appName`
  - If match found: use app_name and appUuid from config
  - If no match found: ask the user which application
```

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 2 as ✅ COMPLETED, show appUuid determined

### Step 2.5: KB Freshness Check

⚠️ **BLOCKING CHECK:** Verify Step 2 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 2.

⚠️ **CONDITION:** Only run if `kbFolderId` exists (non-null, non-empty) for the matched application from `get_jarvis_config`. If no kbFolderId, mark as ⏭️ SKIPPED and proceed to Step 3.

```
Check the `staleCount` field from the `get_jarvis_config` response for the matched application.

If staleCount is 0 → mark as ✅ COMPLETED and proceed silently
If staleCount > 0 → STOP. Your NEXT message to the user MUST be:
  "KB Status: {staleCount} objects have changed since the last generation.
   Shall I proceed with the KB, or would you like to refresh first?"
Do NOT proceed to Step 3 until the user responds.
If you call any KB tool before showing this warning, you are violating the workflow.
```

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 2.5 as ✅ COMPLETED or ⏭️ SKIPPED

### Step 3: Parallel Research — KB + JARVIS MCP (MANDATORY - DO NOT SKIP)

⚠️ **BLOCKING CHECK:** Verify Step 2 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 2.

⚠️ **BEFORE STARTING:** Update tracker - mark Step 3 as IN PROGRESS

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 2:
- ✅ Called `get_jarvis_config` to get application list
- ✅ Matched JIRA project/epic against config
- ✅ Determined app_name, appUuid, and kbFolderId (if available)
- ✅ Have application context ready for research

```
⚠️ THIS STEP RUNS TWO RESEARCH TRACKS
⚠️ Extract 2-3 keywords from the JIRA ticket requirements before starting

TRACK A — Knowledge Base Research (pre-computed intelligence)
==============================================================
⚠️ CONDITION: Only run if kbFolderId exists in the `get_jarvis_config` response for this application.
⚠️ If kbFolderId does NOT exist, skip Track A entirely and rely on Track B only.

Using the keywords from the JIRA ticket, run these KB tools:

1. Application context (if not already loaded in this conversation):
   Tool: mcp_jarvis_jarvis_get_app_tree
   Input: parentFolderId={kbFolderId}
   Purpose: Understand app shape, find relevant clusters/entry points

2. Object discovery:
   Tool: mcp_jarvis_jarvis_search_objects
   Input: parentFolderId={kbFolderId}, query={keyword}
   Purpose: Find relevant objects with descriptions, tags, complexity, cluster membership

3. Feature context (for the most relevant cluster):
   Tool: mcp_jarvis_jarvis_get_cluster
   Input: parentFolderId={kbFolderId}, clusterName={from app-tree or search results}
   Purpose: See all objects in the feature — understand how they work together

4. Existing patterns (MANDATORY — design reference):
   Tool: mcp_jarvis_jarvis_get_patterns
   Input: parentFolderId={kbFolderId}
   Purpose: Find CRUD sets, wizard patterns, batch processes, utility libraries.
   Use these as "follow this existing pattern" references in the implementation plan.

5. Data model context:
   Tool: mcp_jarvis_jarvis_get_data_model
   Input: parentFolderId={kbFolderId}
   Purpose: Understand record types, fields, relationships, data stores.
   Positions the new feature correctly in the data model.

6. Architecture context:
   Tool: mcp_jarvis_jarvis_get_architecture
   Input: parentFolderId={kbFolderId}
   Purpose: Understand application layers and central record types.
   Helps position the new feature in the right architectural layer.

7. Source code for key objects being MODIFIED (top 2-3):
   Tool: mcp_jarvis_jarvis_get_object_content
   Input: parentFolderId={kbFolderId}, objectName={name}
   Purpose: Read current SAIL code with resolved UUIDs before designing changes

8. Shared object awareness:
   Tool: mcp_jarvis_jarvis_get_shared_objects
   Input: parentFolderId={kbFolderId}
   Purpose: Identify which objects are shared across many features.
   If the plan involves modifying a shared utility, flag it as high-risk.

KB strengths:
  - Pre-computed clusters show how objects work together as features
  - 35 behavioral tags per object (entity-query, save-into, start-process, etc.)
  - Resolved UUIDs in SAIL code — human-readable without additional lookups
  - Data model, architecture, patterns, shared objects — all in one place
  - Dependency graph pre-computed — no sequential API calls needed

KB limitation:
  - Snapshot — objects created after last KB generation won't appear
  - No folder UUIDs for deployment (use get_application_info in Step 3.75)

Output from Track A:
  - List of relevant objects with descriptions, tags, complexity
  - Feature cluster context (how objects relate)
  - Existing implementation patterns to reference
  - Data model context (fields, relationships)
  - Architecture context (layers, central records)
  - Shared object risk flags
  - SAIL code for key objects being modified
  - Draft implementation plan (CREATE/UPDATE objects)

Budget: 5-10 KB calls (richer data per call than live API)


TRACK B — JARVIS MCP Research (live environment, current state)
================================================================
⚠️ REQUIRED TOOLS: list_application_objects, search_objects_semantic
⚠️ PURPOSE: Catch recently created objects not in KB + database verification

Using the SAME keywords from the JIRA ticket:

1. Semantic search (for broader discovery and recent objects):
   Tool: mcp_jarvis_search_objects_semantic
   Input: searchTerm={ticket feature description}, appPrefix={from config}

2. Record Type discovery (if KB Track A didn't cover this):
   Tool: mcp_jarvis_list_application_objects
   Input: appUuid, searchTerm={keyword}, objectType="Record Type"

3. Database verification (MANDATORY when implementation plan involves database):
   Tool: mcp_jarvis_query_sql

   | Trigger (detected from implementation plan) | SQL to run |
   |---------------------------------------------|------------|
   | Plan includes CREATE for database table/CDT | `DESCRIBE {TABLE_NAME}` if table already exists |
   | Plan includes CREATE/UPDATE for Record Type | `DESCRIBE {source_table}` → verify columns match |
   | Plan includes CREATE for QE_/QR_ rule | `DESCRIBE {target_table}` → verify table exists |
   | Plan includes UPDATE for existing QE_/QR_ rule | `DESCRIBE {target_table}` + `SHOW INDEX FROM {target_table}` |
   | Plan involves new FK relationships | `DESCRIBE {both_tables}` → verify FK columns |

   Skip SQL ONLY when: All objects are pure UI or pure logic without database interaction.
   NOTE: If KB Track A provided data model via jarvis_get_data_model, SQL verification
   becomes a targeted confirmation rather than discovery. Focus SQL on verifying
   specific columns/indexes mentioned in the implementation plan.

   Budget: 1-4 SQL calls (reduced from 2-6 when KB provides data model context)

4. Database Script Detection (jarvis-smt integration — ANY database operation):

   ⚠️ **CRITICAL TRIGGER:** If the JIRA ticket mentions ANY of the following, you MUST activate the
   jarvis-smt-power and research the SMT context BEFORE writing the design doc:
   - New database tables (CREATE TABLE)
   - New columns on existing tables (ALTER TABLE)
   - Data inserts (INSERT INTO — reference data, templates, configuration, seed data)
   - Data updates/deletes (UPDATE, DELETE)
   - Views, triggers, stored procedures
   - Any mention of "script", "migration", "database", "table", "SQL"

   **How to detect:** Check the JIRA ticket description and acceptance criteria for keywords:
   `script`, `insert`, `table`, `database`, `migration`, `template data`, `reference data`,
   `seed data`, `SQL`, `DDL`, `DML`, `schema`

   **When triggered:**
   1. **MANDATORY: Activate jarvis-smt-power FIRST** — do NOT query SMT tables directly.
      The SMT power handles schema detection (DevTools vs Appian) which you cannot do correctly without it.
      If you query `Appian.SMT_Application` and get empty results, it's because the schema is `DevTools` — 
      the SMT power knows this. Never conclude "app is not in SMT" without activating the power first.
   2. Use the SMT power's schema detection to find the correct prefix
   3. Query `SMT_Application` to find if the target app is registered in SMT
   4. If registered → get current release (devphaseid), supported DB types (MariaDB/Oracle)
   5. Research existing script patterns for that app (how do they write INSERTs? Do they use stored procedures?)
   6. Include in the design doc:
      - SMT app info (appid, release, DB types)
      - Script type needed (DDL for schema, DML for data)
      - Pattern reference (existing script IDs to follow)
      - Note that this must be submitted as an SMT Change Request

   **DDL conventions (schema changes):**
   - All scripts MUST be idempotent (safe to run multiple times)
   - Use `IF NOT EXISTS` for CREATE TABLE
   - Use conditional column existence checks for ALTER TABLE
   - Table names: UPPERCASE with app prefix (e.g., `AS_VM_VENDOR_SCORE`)
   - Always include: primary key, audit columns (createdBy, createdDatetime, modifiedBy, modifiedDatetime, isActive)
   - FK columns should have indexes

   **DML conventions (data inserts/updates):**
   - All scripts MUST be idempotent (use INSERT IGNORE, or check existence before insert)
   - Follow existing patterns for the app (some use stored procedures, some use individual INSERTs)
   - If app supports multiple DB types (MariaDB + Oracle), note that both scripts are needed
   - Reference data inserts should use explicit IDs when possible

   **If app is NOT in SMT:** Generate the script directly in the design doc without SMT metadata.

   Budget: 2-4 SQL calls (SMT app lookup + existing pattern research)

Output from Track B:
  - Recently created objects not in KB
  - Database structure verification
  - Current object descriptions and types
  - Database script context (SMT app info, patterns, script type needed)
```

⚠️ **AFTER COMPLETING BOTH TRACKS:** Update tracker - mark Step 3 as ✅ COMPLETED, show tool calls from both tracks

### Step 3.25: Consolidate & Reconcile Findings (MANDATORY - DO NOT SKIP)

⚠️ **BLOCKING CHECK:** Verify Step 3 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 3.

⚠️ **BEFORE STARTING:** Update tracker - mark Step 3.25 as IN PROGRESS

```
⚠️ PURPOSE: Merge KB intelligence with MCP live data into one unified implementation plan
⚠️ THIS STEP CANNOT BE SKIPPED

RECONCILIATION PROCESS:

1. If KB Track A was available:
   KB is the PRIMARY source. Live API (Track B) supplements for gaps.

   ✅ KB found the object → HIGH CONFIDENCE
      - Use KB for: cluster context, tags, complexity, dependencies, SAIL code, patterns
      - Use live API only to verify recently created objects not in KB

   🆕 Live API found objects NOT in KB → VALIDATE RELEVANCE
      - Object was created after last KB generation
      - MUST verify relevance before including:
        a. Read source code: call mcp_jarvis_get_appian_object with the UUID
        b. Check: Does the object relate to the ticket requirements?
        c. Check: Was it only found because it shares a generic keyword?
      - If relevant: include in plan with note "new — not in KB"
      - If not relevant: drop it
      - Budget: Read source code for top 2-3 candidates only

2. If KB Track A was NOT available (no kbFolderId):
   Live API is the only source. Use semantic search + list_application_objects results directly.
   Read source code for top 3-5 objects being modified via get_appian_object.

3. Build unified implementation plan:
   - For each object: name, UUID, type, action (CREATE/UPDATE)
   - Include KB insights: cluster context, existing patterns to follow, data model position
   - Include architecture context: which layer this feature sits in
   - Flag shared objects: if modifying an object shared across 5+ clusters, note HIGH RISK
   - For objects being MODIFIED: include key details from SAIL code reading

4. Present reconciliation summary to user:
   - If KB available: "KB provided X objects with full context. Live API found Y additional recent objects."
   - If KB not available: "Found X objects via live API search."

Output (REQUIRED):
  - Unified implementation plan with best data from both sources
  - Reconciliation summary (confirmed / stale / new counts)
  - Source code context for top 2-3 objects being modified
  - Test cases from acceptance criteria

IMPLEMENTATION PLAN FORMAT (MANDATORY):
  For each object in the plan, use this structure:
  1. **Header:** CREATE/UPDATE — {Object Name}
  2. **Description:** 1-2 sentence description of what the object does. This should be copy-paste ready
     for the Appian object description field. Write it from the object's perspective:
     - Good: "Stores AI-generated validation results for evaluation tasks, linking findings to vendors and criteria."
     - Good: "Displays the vendor analysis tab with scoring breakdown, confidence levels, and AI-generated findings."
     - Bad: "This is the interface for the vendor analysis feature." (too vague)
     - Bad: "Created for GAMS-7359." (not a description of the object)
  3. **What to build:** Bullet list of actionable implementation details — what the developer needs to DO.
     Focus on behavior, logic, and structure. Keep it scannable.

  The description serves double duty: it goes in the design doc AND the developer copies it into the
  Appian object's description field when creating it.

Budget: 3-8 API calls (Atlas-only verification + MCP-only source code reads + key object reads)
```

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 3.25 as ✅ COMPLETED, show reconciliation summary

### Step 3.75: Get Application Info and Validate Naming/Folders (MANDATORY - DO NOT SKIP)

⚠️ **BLOCKING CHECK:** Verify Step 3.25 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 3.25.

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 3.25:
- ✅ Ran KB research (Track A) and/or live API research (Track B)
- ✅ Reconciled findings into unified implementation plan
- ✅ Have implementation plan ready for naming/folder validation

```
⚠️ REQUIRED TOOL: mcp_appian_get_application_info
⚠️ THIS STEP CANNOT BE SKIPPED

Tool: mcp_appian_get_application_info
Input: appUuid (from Step 2)

Extract:
  - namingConvention (e.g., "AS_GSS", "AS_GAM")
  - ruleFolderDetails[] (list of valid folders with id, uuid, name, description)
  - lastUsedFolderForConst (folder id for constants)
  - lastUsedFolderForRule (folder id for expression rules)
  - lastUsedFolderForInterface (folder id for interfaces)

Purpose:
  - Auto-populate correct folder locations in implementation plan
  - Validate object names follow app naming convention
  - Use lastUsedFolder* to suggest default folders for new objects
  - Ensure consistency with app standards

Validation Rules (MANDATORY):
  - All new object names MUST start with "{namingConvention} " (with space) OR "{namingConvention}_" (with underscore)
  - Valid examples for AS_GSS: "AS GSS FM Dashboard", "AS_GSS_FM_Dashboard"
  - Invalid examples: "ASGSS_FM", "AS-GSS FM", "GSS_FM", "AS_FM"
  - Flag ANY object name that doesn't match this pattern

Folder Selection (MANDATORY):
  - For constants: Use folder matching lastUsedFolderForConst id
  - For expression rules: Use folder matching lastUsedFolderForRule id
  - For interfaces: Use folder matching lastUsedFolderForInterface id
  - Include folder name and UUID in implementation plan

Output for design doc (REQUIRED):
  - Implementation plan includes folder name for each object
  - All object names validated against naming convention

⚠️ VALIDATION: Before proceeding to Step 4, confirm you have:
  - Called get_application_info with correct appUuid
  - Validated ALL object names against naming convention
  - Selected correct folder for each object based on type
  - Included folder information in implementation plan
```

### Step 3.8: Review Best Practices Checklist (MANDATORY - DO NOT SKIP)

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 3.75:
- ✅ Called mcp_appian_get_application_info with correct appUuid
- ✅ Validated ALL object names against naming convention
- ✅ Selected correct folder for each object based on type
- ✅ Included folder name and UUID in implementation plan
- ✅ Have complete object specifications ready for checklist review

```
⚠️ REQUIRED REFERENCE: .kiro/steering/appian-best-practices-checklist.md
⚠️ THIS STEP CANNOT BE SKIPPED
⚠️ APPLIES TO: Objects identified in Step 3 (Atlas implementation details)

Purpose:
  - Ensure design notes for Atlas-identified objects follow Appian SOLUTIONS best practices
  - Provide guidance aligned with code review standards
  - Prevent common design mistakes early in the process
  - Validate that objects from Atlas search follow proper conventions

Reference Document:
  #[[file:.kiro/steering/appian-best-practices-checklist.md]]

What to Review (based on object types from Step 3 Atlas search):
  
  For ALL Objects (from Atlas):
    - Section 1: General SAIL Principles
      - Naming conventions (Section 1.F)
      - Parameter passing patterns (Section 1.G)
      - Commenting guidelines (Section 1.B)
  
  For Constants (from Atlas):
    - Section 4: Constants
      - Naming with type prefixes (BOL, INT, TXT, etc.)
      - Appropriate use cases
      - No array constants (use expression rules)
  
  For Expression Rules (from Atlas):
    - Section 5: Expression Rules
      - Naming with purpose prefixes (BL, QE, UI, VD, etc.)
      - Query patterns (use CO utilities)
      - Test case requirements
  
  For Interfaces (from Atlas):
    - Section 6: Interfaces
      - Naming with UI type prefixes (FM, GRD, SCT, etc.)
      - Logic separation (minimal logic in interfaces)
      - Default inputs requirement
  
  For Process Models (from Atlas):
    - Section 7: Process Models
      - Naming convention (AS <app> <name> SF)
      - Security group requirements
      - Archiving/deletion policies
  
  For Record Types (from Atlas):
    - Section 3: Record Types
      - Naming with _RecordType suffix
      - Relationship setup
      - Security configuration

Design Notes Checklist (MANDATORY for Atlas objects):
  ✓ Object names from Atlas follow naming conventions from checklist
  ✓ Implementation notes reference appropriate CO rules
  ✓ Design considers reusability (Section 1.C)
  ✓ Parameters follow keyword-syntax pattern (Section 1.G)
  ✓ State management patterns considered (Section 1.H)
  ✓ Internationalization planned (Section 9)
  ✓ Reference data patterns followed (Section 8)

Output for design doc (REQUIRED):
  - Add "Design Notes" subsection in IMPLEMENTATION PLAN for each Atlas object
  - Include relevant best practice references
  - Example: "Use AS_CO_UT_queryEntity() per Section 5.C"
  - Example: "Follow affirmative naming per Section 1.F"
  - Example: "Extract validation logic to VD rule per Section 6.C"

⚠️ VALIDATION: Before proceeding to Step 4, confirm you have:
  - Reviewed checklist sections relevant to Atlas object types
  - Validated naming conventions of Atlas objects against checklist
  - Added design notes referencing best practices for each object
  - Ensured implementation plan for Atlas objects aligns with SOLUTIONS standards
```

### Step 3.9: Synthesize Open Questions (OPTIONAL — SKIP IF STRAIGHTFORWARD)

⚠️ **BLOCKING CHECK:** Verify Step 3.8 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 3.8.

```
⚠️ PURPOSE: Surface edge cases, ambiguities, and assumptions that need human judgment
⚠️ NO NEW API CALLS — pure reasoning over data already gathered in Steps 1-3.8
⚠️ OPTIONAL — if the ticket is straightforward with no ambiguities, mark as ⏭️ SKIPPED

Review all research findings and synthesize 3-7 open questions by examining:

SOURCE 1 — JIRA ticket gaps:
  - Compare acceptance criteria against what a complete implementation needs
  - What scenarios does the AC not cover? (empty states, error states, edge cases)
  - Are there ambiguous requirements that could be interpreted multiple ways?

SOURCE 2 — Dependency analysis (Step 3.5):
  - High-dependent objects being modified — have all consumers been considered?
  - Are there cross-feature impacts the ticket doesn't mention?

SOURCE 3 — Source code reading (Step 3.25):
  - Did the existing code make assumptions that conflict with the ticket?
  - Are there hardcoded values or patterns that need to change?
  - Missing null checks, empty state handling, or error paths?

SOURCE 4 — Atlas pattern comparison (Step 3):
  - Does the proposed approach differ from established patterns in the codebase?
  - Is there a reason to deviate, or should it follow the existing pattern?

SOURCE 5 — Data model (Step 3.25):
  - Are there missing fields, relationships, or Record Type changes needed?
  - Does the data model support all the scenarios in the AC?

SOURCE 6 — Security / access:
  - Does the feature involve data with record-level security?
  - Are new security groups or permissions needed?

SOURCE 7 — Database structure (from query_sql in Track B, if available):
  - Does the table have the columns the ticket assumes?
  - Is the data volume large enough to need indexes or pagination?
  - Are there NULL values in columns the design assumes are populated?

QUALITY RULES:
  - Only include questions that need a HUMAN decision — not things the agent can answer
  - Each question should be specific and actionable, not vague
  - Tag each question with its source: [Edge Case], [Assumption], [Scope], [Security], [Data Model], [Cross-Feature]
  - Cap at 3-7 questions — if you have more, prioritize the most impactful
  - If the ticket is straightforward and you have zero genuine questions, SKIP this step

Output: List of open questions ready for inclusion in the HTML document
```

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 3.9 as ✅ COMPLETED (or ⏭️ SKIPPED if straightforward)

### Step 4: Create Appian Package

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 3.9 (or marked as ⏭️ SKIPPED):
- ✅ Reviewed checklist sections relevant to object types
- ✅ Validated naming conventions against checklist
- ✅ Added design notes referencing best practices for each object
- ✅ Ensured implementation plan aligns with SOLUTIONS standards
- ✅ Open questions synthesized (or skipped if straightforward)
- ✅ Have complete design content ready for package creation

```
Tool: mcp_appian_create_package_for_ticket
Input:
  - appUuid: From step 2
  - packageName: "{TICKET_KEY} {TICKET_TITLE}"
Output: Package URL
```

### Step 4.5: Validate HTML Structure (MANDATORY - DO NOT SKIP)

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 4:
- ✅ Called mcp_appian_create_package_for_ticket
- ✅ Received package URL
- ✅ Have all design content ready (overview, implementation plan, i18n delta keys, test cases)
- ✅ Ready to build HTML document

```
⚠️ BEFORE writing the HTML file, YOU MUST confirm:

REQUIRED CHECKLIST:
  ✓ Document has EXACTLY 6 sections if mockup was provided, or 5 sections if no mockup (no more, no less)
  ✓ If Step 3.9 produced open questions, add OPEN QUESTIONS section (yellow header #fff2cc) — increases section count by 1
  ✓ Each section is a table with blue header (#c9daf8)
  ✓ Section names match template EXACTLY:
    1. OVERVIEW
    2. IMPLEMENTATION PLAN
    3. INTERNATIONALIZATION (ONLY if Step 1.5 produced i18n keys — OMIT if Step 1.5 was SKIPPED)
    4. OPEN QUESTIONS (ONLY if Step 3.9 produced questions — OMIT if Step 3.9 was SKIPPED. Uses yellow header #fff2cc)
    5. TEST CASES
    6. DEPLOYMENT
  ✓ NO additional sections added beyond the template
  ✓ IMPLEMENTATION PLAN includes description and "What to build" bullets for each object (NO References line)
  ✓ INTERNATIONALIZATION shows ONLY new keys (delta) — keys that already exist are excluded
  ✓ TEST CASES uses <ol> numbered list
  ✓ Title is <h1> with JIRA hyperlink
  ✓ All object names follow naming convention: "{namingConvention} " or "{namingConvention}_"

FORBIDDEN - DO NOT ADD THESE SECTIONS:
  ❌ Executive Summary
  ❌ Requirements
  ❌ Risk Assessment
  ❌ Success Criteria
  ❌ Open Questions
  ❌ References
  ❌ Appendix
  ❌ Configuration Management
  ❌ Any section not in the template

⚠️ If you cannot confirm ALL items above, STOP and re-read the HTML Template Structure section.
```

### Step 5: Build HTML Document and Import as Google Doc

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 4.5:
- ✅ Confirmed document has correct number of sections (6 with mockup, 5 without)
- ✅ Confirmed each section is a table with blue header
- ✅ Confirmed section names match template EXACTLY
- ✅ Confirmed NO additional sections added
- ✅ Confirmed IMPLEMENTATION PLAN has description + "What to build" for each object (NO References line)
- ✅ Confirmed all object names follow naming convention
- ✅ If Step 1.5 produced i18n keys: confirmed INTERNATIONALIZATION section shows ONLY new (delta) keys
- ✅ If Step 1.5 was SKIPPED: confirmed INTERNATIONALIZATION section is NOT included
- ✅ If Step 3.9 produced open questions: confirmed OPEN QUESTIONS section is included with yellow header
- ✅ If Step 3.9 was SKIPPED: confirmed OPEN QUESTIONS section is NOT included
- ✅ Ready to write HTML file

⚠️ OUTPUT FORMAT: HTML file saved to design-documents/ folder. Optionally exported to Google Doc if MCP is available.

```
Step 5a: Build HTML file locally
Tool: fsWrite
Input: path="design-documents/design-{TICKET_KEY}.html"
Content: Full HTML document with all sections (see HTML Template below)

Step 5b: Export to Google Doc (OPTIONAL — only if Google Workspace MCP is available)
⚠️ CONDITION: Only attempt this step if Google Workspace MCP tools are working.
⚠️ If MCP is unavailable, skip this step and inform the user:
   "Design document saved to design-documents/design-{TICKET_KEY}.html
    To import to Google Docs: open the file in a browser, select all (Ctrl+A), 
    copy (Ctrl+C), and paste into a new Google Doc."

If MCP IS available:
Tool: mcp_google_workspace_import_to_google_doc
Input:
  - file_name: "{TICKET_KEY} {TICKET_TITLE}"
  - file_path: "design-documents/design-{TICKET_KEY}.html"
  - folder_id: {from `get_jarvis_config` → matched application → designDocFolderId}
  - source_format: "html"
  - user_google_email: {user's Google email}
Output: Google Doc ID with all formatting preserved

Note: The folder_id comes from the matched application's designDocFolder field (determined in Step 2)
```

## HTML Template Structure

## CRITICAL: HTML Template Compliance

⚠️ THE TEMPLATE IS NOT A SUGGESTION - IT IS MANDATORY
⚠️ DO NOT ADD SECTIONS NOT IN THE TEMPLATE
⚠️ DO NOT CREATE "COMPREHENSIVE" OR "COMPLETE" DOCUMENTS
⚠️ EXACTLY 7 SECTIONS (or 6 if no mockup/i18n) - NO MORE, NO LESS

**Common mistakes to AVOID:**
- ❌ Adding "Executive Summary" section
- ❌ Adding "Requirements" section with FR-1, FR-2 tables
- ❌ Adding "Risk Assessment" section
- ❌ Adding "Success Criteria" section
- ❌ Adding "Open Questions" section
- ❌ Adding "References" section
- ❌ Adding "Appendix" section
- ❌ Adding "Configuration Management" section
- ❌ Creating multi-level headers (h2, h3, h4)
- ❌ Creating multiple tables per section
- ❌ Adding extra formatting or styling beyond the template

**What you MUST do:**
- ✅ Use ONLY the 6 sections shown in the template below (5 if no mockup — omit INTERNATIONALIZATION)
- ✅ Each section is a SINGLE table with blue header and white body
- ✅ Follow the EXACT HTML structure provided
- ✅ Use the EXACT section names (OVERVIEW, IMPLEMENTATION PLAN, INTERNATIONALIZATION, TEST CASES, DEPLOYMENT)
- ✅ Keep content concise and focused on essentials

```html
<html>
<body>

<h1><a href="{JIRA_URL}">{TICKET_KEY}: {TICKET_TITLE}</a></h1>

<table style="width:100%; border:1px solid #999;">
  <tr><td style="background-color:#c9daf8; padding:8px;"><b>OVERVIEW</b></td></tr>
  <tr><td style="padding:8px;">{Brief overview of the implementation}</td></tr>
</table>
<br/>

<table style="width:100%; border:1px solid #999;">
  <tr><td style="background-color:#c9daf8; padding:8px;"><b>IMPLEMENTATION PLAN</b></td></tr>
  <tr><td style="padding:8px;">

    <p><b>CREATE/UPDATE — {OBJECT_NAME_1}</b></p>
    <p><i>{Object description — 1-2 sentences explaining what this object does. Copy-paste ready for the Appian object description field.}</i></p>
    <p><b>What to build:</b></p>
    <ul>
      <li>{Actionable implementation detail 1}</li>
      <li>{Actionable implementation detail 2}</li>
      <li>{Actionable implementation detail 3}</li>
    </ul>
    <hr/>

    <p><b>CREATE/UPDATE — {OBJECT_NAME_2}</b></p>
    <p><i>{Object description — 1-2 sentences explaining what this object does.}</i></p>
    <p><b>What to build:</b></p>
    <ul>
      <li>{Actionable implementation detail 1}</li>
      <li>{Actionable implementation detail 2}</li>
    </ul>

  </td></tr>
</table>
<br/>

<!-- INTERNATIONALIZATION section: ONLY include if Step 1.5 produced NEW (delta) i18n keys. OMIT entirely if Step 1.5 was SKIPPED or all keys already exist. -->
<!-- Determine i18n system from get_jarvis_config: if translationSets[] is populated → Translation Sets format, otherwise → BND bundle format -->
<table style="width:100%; border:1px solid #999;">
  <tr><td style="background-color:#c9daf8; padding:8px;"><b>INTERNATIONALIZATION</b></td></tr>
  <tr><td style="padding:8px;">
    <p><i>New i18n keys to create. Existing keys have been verified and excluded — only delta (new) keys are listed below.</i></p>
    <p><b>System:</b> {BND Bundles | Appian Translation Sets} — Target: {bundle name or translation set name}</p>
    <p><b>Labels (lbl_)</b></p>
    <pre>lbl_exampleField=Example Field
lbl_exampleHeader=Example Header</pre>
    <p><b>Validation (vld_)</b></p>
    <pre>vld_exampleRequired=[%1] requires a value</pre>
    <p><b>Placeholders (plc_)</b></p>
    <pre>plc_exampleSearch=Search...</pre>
    <p><b>Accessibility (acs_)</b></p>
    <pre>acs_exampleAction=Press enter to [%1]</pre>
    <p><b>General Text (txt_)</b></p>
    <pre>txt_exampleDescription=Description text</pre>
  </td></tr>
</table>
<br/>

<!-- OPEN QUESTIONS section: ONLY include if Step 3.9 produced questions. OMIT entirely if Step 3.9 was SKIPPED. -->
<table style="width:100%; border:1px solid #999;">
  <tr><td style="background-color:#fff2cc; padding:8px;"><b>OPEN QUESTIONS</b></td></tr>
  <tr><td style="padding:8px;">
    <p><i>Questions identified during research that need human judgment before or during implementation.</i></p>
    <ol>
      <li><b>[Tag]</b> Question text</li>
      <li><b>[Tag]</b> Question text</li>
    </ol>
  </td></tr>
</table>
<br/>

<table style="width:100%; border:1px solid #999;">
  <tr><td style="background-color:#c9daf8; padding:8px;"><b>TEST CASES</b></td></tr>
  <tr><td style="padding:8px;">
    <ol>
      <li>Verify that [expected behavior 1]</li>
      <li>Verify that [expected behavior 2]</li>
    </ol>
  </td></tr>
</table>
<br/>

<table style="width:100%; border:1px solid #999;">
  <tr><td style="background-color:#c9daf8; padding:8px;"><b>DEPLOYMENT</b></td></tr>
  <tr><td style="padding:8px;">
    <p>Package: <a href="{PACKAGE_URL}">{PACKAGE_URL}</a></p>
  </td></tr>
</table>

</body>
</html>
```

## HTML Formatting Rules
- Title: `<h1>` with `<a href>` for JIRA hyperlink
- Each section: Single-column table with blue header row (`background-color:#c9daf8`) and white body row
- Section Headers: `<b>` inside blue `<td>` (OVERVIEW, IMPLEMENTATION PLAN, INTERNATIONALIZATION, TEST CASES, DEPLOYMENT)
- Body Text: `<p>` for paragraphs inside body `<td>`
- Object names in implementation plan: `<b>` inside `<p>`
- Bullet lists: `<ul>` with `<li>`
- Numbered lists (test cases): `<ol>` with `<li>`
- JSON/code blocks: `<pre>`
- Package link: Hyperlinked URL inside DEPLOYMENT section body

## Configuration
- Design doc folder ID: From `get_jarvis_config` → applications[].designDocFolderId (per application)
- User email: User's Google email (from MCP environment or ask user)
- JIRA base URL: https://appian-eng.atlassian.net/browse/
- App config: `get_jarvis_config` API (replaces config/app_config.json)
