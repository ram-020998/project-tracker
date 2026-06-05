---
inclusion: auto
---

# Implementation Summary Workflow

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING:**

1. ✅ **SHOW THE EXECUTION TRACKER** — Copy the tracker template below and paste it in your response RIGHT NOW
2. ✅ **READ THIS ENTIRE WORKFLOW FILE** — Don't skip ahead, don't assume you know the steps
3. ✅ **CHECK FOR EXISTING SUMMARY FILE** — Look in `implementation-summary/` for an in-progress summary. If one exists with incomplete steps, RESUME from where it left off.
4. ✅ **IF NEW SUMMARY** — Create the summary markdown file FIRST, then proceed step by step
5. ✅ **VERIFY BLOCKING RULES** — Check that previous steps are complete before proceeding

**IF YOU SKIP ANY OF THESE, YOU ARE VIOLATING THE WORKFLOW.**

**Common Triggers That Activate This Workflow:**
- "Implementation summary for GAMS-XXXX"
- "Summarize changes for GAMS-XXXX"
- "What changed in AS_GSS_FM_objectName since version 15?"
- "What changed in AS_GSS_FM_objectName since March 2nd?"
- "Summarize this package: {URL} since {date}"
- User selects option 8 from JARVIS menu

**When you see these triggers, your FIRST action is to show the tracker. Not call tools. Not analyze code. SHOW THE TRACKER.**

---

## Overview

Generates a developer-friendly summary of what changed in Appian objects — either across an entire JIRA ticket's package or for a single object. The agent reads old vs latest SAIL code from the `get_object_diff` API and produces categorized, human-readable change summaries with impact context.

**Three Modes:**

| Mode | Input | Reference Point | Output |
|------|-------|----------------|--------|
| **A: Package Summary (JIRA)** | JIRA ticket key | Auto-extracted from changelog (first "Technical Design" transition, fallback "In Progress") | Local md + optionally Google Doc |
| **B: Single Object** | Object name + (versionNumber OR dateTime) | User-provided | Chat response + local md |
| **C: Package Summary (no JIRA)** | Package URL + dateTime | User-provided dateTime | Local md + optionally Google Doc |

**Key Design Principle:** Like the spike and code review workflows, findings are built incrementally in a local markdown file (`implementation-summary/`). Each step writes its results as it completes. Supports context transfer — a new agent can resume from the file.

## CRITICAL RULES - MANDATORY COMPLIANCE

- ⚠️ STRICT ENFORCEMENT: Follow these steps EXACTLY in order. NO DEVIATIONS ALLOWED.
- ⚠️ STEP SKIPPING IS FORBIDDEN: Every step must be completed before proceeding to the next.
- ⚠️ EXECUTION TRACKER IS MANDATORY: You MUST show the execution tracker in EVERY response and update it after each step.
- ⚠️ BLOCKING CHECKS: Before starting any step, verify the previous step shows ✅ in the tracker. If not, STOP IMMEDIATELY.
- ⚠️ Every step WRITES its findings to the summary markdown file as it completes.
- ⚠️ The summary file is the source of truth — not agent memory.
- ⚠️ Call `get_jarvis_config` to determine application context.
- ⚠️ Deleted objects are NOT considered — skip any object that returns no data.
- ⚠️ The agent does the change summarization — read old vs latest SAIL code and describe what changed in developer-friendly bullet points.

**PERMANENT SOLUTION TO PREVENT STEP SKIPPING:**

The execution tracker is your FORCING MECHANISM. It works like this:

1. **Visual Accountability**: You must show the tracker in every response, making it impossible to hide skipped steps
2. **Blocking Rules**: Each step has a blocking check that references the tracker
3. **No Ambiguity**: ✅ means done, ❌ means not done — no gray area
4. **User Visibility**: User can see exactly which steps were completed and which were skipped
5. **Self-Enforcement**: You cannot claim a step is done without updating the tracker

**If you skip a step, the tracker will show it, and the user will catch it immediately.**

## WORKFLOW ISOLATION - CRITICAL

⚠️ THIS WORKFLOW IS COMPLETELY INDEPENDENT
⚠️ DO NOT create design documents (that's design workflow)
⚠️ DO NOT do code review scoring (that's code review workflow)
⚠️ DO NOT create Appian objects (that's implementation workflow)

**What This Workflow Does:**
1. Creates a summary markdown file and builds it incrementally
2. Resolves the reference point (dateTime from JIRA changelog, user input, or versionNumber)
3. Gets package contents or resolves a single object
4. Determines application context
5. For each object sequentially: diffs → summarizes → writes findings to file → next object
6. Pulls dependents count for impact context
7. Cross-references changes against JIRA acceptance criteria (Mode A only)
8. Asks user about Google Doc export (Mode A/C) or presents in chat (Mode B)

**What This Workflow Does NOT Do:**
- ❌ Create JIRA tickets or comments
- ❌ Create Appian objects
- ❌ Score or grade code quality (that's code review)
- ❌ Make architectural recommendations (that's spike research)

---

## CONTEXT MANAGEMENT — WHY THIS WORKFLOW USES SEQUENTIAL PROCESSING

This workflow processes objects ONE AT A TIME and writes findings to a local markdown file after each object. This is intentional:

- A single process model diff can consume 500-3000+ lines of context
- With 10+ objects, fetching all diffs at once overflows the context window
- By processing sequentially and persisting to file, each object gets full attention
- If context fills up mid-workflow, a new agent can read the summary file and resume from where it left off
- The summary file is also the final deliverable — it builds up incrementally

**CRITICAL: Do NOT fetch all object diffs in parallel. Process them one at a time in the object loop (Step 5).**

---

## Object Type ID Mapping

The `get_object_diff` tool requires a `typeId` integer. Use this mapping:

| Friendly Name | typeId | Naming Hint |
|--------------|--------|-------------|
| Interface | 260 | `FM_`, `SCT_`, `CPS_`, `CRD_`, `GRD_`, `HCL_`, `DLG_` |
| Expression Rule | 39 | `QR_`, `QE_`, `UT_`, `BL_`, `FN_`, `CO_` |
| Constant | 40 | `INT_`, `TXT_`, `BOL_`, `REF_`, `HEX_`, `ENT_` |
| Process Model | 23 | (no prefix pattern — identified by type from search) |
| Integration | 250 | `INT_` (context-dependent — check object type from search) |
| Decision Rule | 248 | `DR_` |

**Resolution strategy:** When the user provides an object name (Mode B), resolve the UUID AND type via `search_objects_by_name` or `search_objects_semantic`. The search results include the object type — map it to typeId using the table above. Do NOT guess from naming convention alone.

---

## Change Categories

When summarizing changes, tag each object's changes with one or more categories:

| Category | Icon | Description |
|----------|------|-------------|
| UI Change | 🎨 | Interface layout, styling, labels, visibility, component additions/removals |
| Logic Change | ⚙️ | Expression rule logic, conditions, calculations, query filters |
| Data Model Change | 🗄️ | Record type fields, relationships, views, actions |
| Config Change | 🔧 | Constants, connected systems, integration endpoints |
| New Object | 🆕 | Object created after the reference point (old = null) |

An object can have multiple categories (e.g., an interface change that also changes embedded logic).

---

## Summary File Convention

**Folder:** `implementation-summary/`

**File naming:**
- Mode A: `summary-GAMS-7130.md`
- Mode B: `summary-{OBJECT_NAME}.md` (e.g., `summary-AS_GSS_FM_updateEvaluation.md`)
- Mode C: `summary-pkg-{PACKAGE_ID}.md` (extract ID from package URL)

---

## MANDATORY EXECUTION TRACKER

⚠️ **CRITICAL: You MUST maintain this execution tracker throughout the workflow**
⚠️ **Copy this tracker into your response and update it after EACH step**
⚠️ **If any step shows ❌, you are FORBIDDEN from proceeding to the next step**

```
IMPLEMENTATION SUMMARY EXECUTION TRACKER — {TITLE}
====================================================
Step 1: Detect Mode & Collect Inputs   [ ] ❌ NOT STARTED
Step 2: Resolve Reference Point        [ ] ❌ NOT STARTED
Step 3: Get Objects                    [ ] ❌ NOT STARTED
Step 4: Determine Application          [ ] ❌ NOT STARTED
Step 5: Object Diff & Summary Loop     [ ] ❌ NOT STARTED ⚠️ SEQUENTIAL — ONE AT A TIME
  Object 1/N: {name}                   [ ] ❌
  Object 2/N: {name}                   [ ] ❌
  ...
Step 6: Impact Analysis                [ ] ❌ NOT STARTED
Step 7: AC Cross-Reference             [ ] ❌ NOT STARTED (Mode A only)
Step 8: Present & Export               [ ] ❌ NOT STARTED

BLOCKING RULES:
- Cannot proceed to Step 2 until Step 1 shows ✅
- Cannot proceed to Step 3 until Step 2 shows ✅
- Cannot proceed to Step 4 until Step 3 shows ✅
- Cannot proceed to Step 5 until Step 4 shows ✅
- Cannot proceed to next object until current object shows ✅
- Cannot proceed to Step 6 until ALL objects in Step 5 show ✅
- Cannot proceed to Step 7 until Step 6 shows ✅
- Cannot proceed to Step 8 until Step 7 shows ✅ (or ⏭️ Skipped)

CURRENT STATUS: Workflow not started
NEXT REQUIRED ACTION: Execute Step 1
SUMMARY FILE: implementation-summary/{filename}.md
```

**HOW TO USE THIS TRACKER:**
1. Copy the tracker into your response at the start of the workflow
2. After completing each step, update the tracker:
   - Change [ ] to [✅] for completed steps
   - Change ❌ NOT STARTED to ✅ COMPLETED
3. Show the updated tracker in EVERY response
4. Check BLOCKING RULES before proceeding to next step
5. If you cannot show ✅ for a step, you MUST stop and complete it
6. In Step 5, update the object list with actual names from Step 3 and mark each ✅ as completed

**EXAMPLE AFTER STEP 5 OBJECT 2:**
```
Step 5: Object Diff & Summary Loop     [ ] 🔄 IN PROGRESS (2/7 complete)
  Object 1/7: AS_GSS_INT_myConstant   [✅] ✅ COMPLETED
  Object 2/7: AS_GSS_BL_calcScore     [✅] ✅ COMPLETED
  Object 3/7: AS GSS Create Eval      [ ] ❌ NEXT
  ...
```

---

## Summary File Template

When creating a new summary file, write this template first:

```markdown
# Implementation Summary — {TITLE}

**Generated by:** JARVIS
**Mode:** {A: JIRA Package | B: Single Object | C: Package (no JIRA)}
**Date:** {current date}
**JIRA:** [{TICKET_KEY}]({JIRA_URL}) <!-- Mode A only -->
**Package:** [{package_id}]({PACKAGE_URL}) <!-- Mode A/C only -->
**Object:** {OBJECT_NAME} <!-- Mode B only -->
**Reference Point:** {dateTime or versionNumber}
**Application:** {to be determined}

---

## Execution Tracker

| Step | Status | Notes |
|------|--------|-------|
| 1. Detect Mode & Collect Inputs | ❌ Not Started | |
| 2. Resolve Reference Point | ❌ Not Started | |
| 3. Get Objects | ❌ Not Started | |
| 4. Determine Application | ❌ Not Started | |
| 5. Diff & Summarize Each Object | ❌ Not Started | |
| 6. Impact Analysis | ❌ Not Started | |
| 7. AC Cross-Reference | ❌ Not Started | Mode A only |
| 8. Present & Export | ❌ Not Started | |

**Current Status:** Workflow not started
**Next Action:** Step 1

---

<!-- Sections below are filled incrementally as each step completes -->
```

**IMPORTANT:** Update the tracker row AND the "Current Status" / "Next Action" lines every time a step completes. Use:
- ❌ Not Started
- 🔄 In Progress
- ✅ Complete
- ⏭️ Skipped

---

## Context Transfer Protocol

If context is running low or a new agent picks up this summary:

1. **Read the summary file** in `implementation-summary/` — it contains all findings so far
2. **Check the Execution Tracker** — identify which step to resume from
3. **Call `get_jarvis_config`** — for application context
4. **Continue from the next incomplete step** — do NOT re-do completed steps
5. **Tell the user** you're resuming: "I'm picking up the implementation summary from Step X."

The summary file IS the context. Everything the previous agent found is written there.

---

## Workflow Steps

### Step 1: Detect Mode & Collect Inputs

⚠️ **BEFORE STARTING:** Show the execution tracker with Step 1 marked as IN PROGRESS

Analyze the user's message to determine which mode:

**Mode A indicators:** JIRA ticket key present (e.g., "GAMS-7130"), no explicit dateTime or package URL
**Mode B indicators:** Object name present (e.g., "AS_GSS_FM_updateEvaluation"), with versionNumber or dateTime
**Mode C indicators:** Package URL present, with dateTime, no JIRA ticket key

| Mode | Required Inputs | Optional Inputs |
|------|----------------|-----------------|
| A | JIRA ticket key | — |
| B | Object name + (versionNumber OR dateTime) | — |
| C | Package URL + dateTime | — |

If inputs are ambiguous or missing, ask the user. Examples:
- "You mentioned GAMS-7130 — should I summarize the full package (Mode A) or a specific object?"
- "I need a reference point. What dateTime should I compare against? (e.g., 2026-03-02T07:21:11Z)"
- "What version number should I use as the baseline?"

**Create the summary file now** using the template above, filling in known fields.

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 1 as ✅ COMPLETED

---

### Step 2: Resolve Reference Point

⚠️ **BLOCKING CHECK:** Verify Step 1 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 1.

**Mode A — Extract from JIRA changelog:**

```
Tool: mcp_jira_get_jira_issue
Input: issue_key, expand: ["changelog"]
```

Scan `changelog.histories` for status transitions:
1. Look for `field === "status"` entries
2. Find the FIRST entry where `toString === "Technical Design"` → use its `created` timestamp
3. If no "Technical Design" found, fallback to FIRST `toString === "In Progress"` → use its `created` timestamp
4. Convert to ISO-8601 UTC format (the JIRA timestamp includes timezone offset, convert it)

Also extract from the ticket:
- `fields.summary` → ticket title
- `fields.description` → description
- `fields.customfield_10227` → acceptance criteria (for Step 7)
- Package URL from `fields.customfield_XXXXX` or from ticket comments/description (search for appianpreview.com/suite/design/package/)

**If no package URL found in the ticket**, ask the user: "I couldn't find a package URL in GAMS-XXXX. Can you provide it?"

**Mode B — User-provided:**
- `dateTime`: Use as-is (ISO-8601)
- `versionNumber`: Use as-is (integer)

**Mode C — User-provided:**
- `dateTime`: Use as-is (ISO-8601)

**Baseline Version Verification (Mode A — after extracting reference_date):**

The JIRA changelog date may not perfectly align with Appian version boundaries due to timezone differences. To determine the correct baseline version, verify against actual version history using the first diffable object from the package (skip Record Types — they don't support diff):

```
Tool: mcp_jarvis_get_version_context
Input: uuid={first diffable object UUID}, typeId={typeId}, dateTime={reference_date}
```

This returns 3 versions before and 3 after the reference date, each with `versionNumber`, `modifiedOn`, and `modifiedBy`.

**Decision logic — cross-reference with JIRA ticket assignee:**
1. Get the ticket assignee name from `fields.assignee.displayName`
2. Look at the `after` versions — find the FIRST version modified by the assignee
3. The correct baseline is the version IMMEDIATELY BEFORE that first assignee change
4. If the assignee doesn't appear in any `after` versions, use the last `before` version as baseline
5. If the assignee name doesn't match any version author (e.g., someone else committed), fall back to the dateTime-based version

**If the verified baseline version differs from what dateTime alone would give:**
- Use `versionNumber` instead of `dateTime` when calling `get_object_diff` in Step 5
- Note in the summary: "Reference adjusted from dateTime-based to v{N} based on assignee version analysis"

**Show the user the resolved reference point before proceeding:**

> "Reference date from JIRA: `{dateTime}`. Version context for {object_name} shows the assignee's first change is v{X} on {date}. Using v{X-1} as baseline. Does this look right?"

**Wait for user confirmation.** If the user provides a different date or version number, use that instead.

**Write to summary file:**

```markdown
## 1. Reference Point

**Mode:** {A/B/C}
**Reference:** {dateTime or versionNumber}
**Verified Baseline:** v{N} (from get_version_context — assignee's first change is v{N+1})
**Source:** {JIRA changelog — first "Technical Design" transition at {timestamp} / User-provided / User-provided}
**JIRA Title:** {title} <!-- Mode A only -->
**Acceptance Criteria:** <!-- Mode A only -->
{AC text from JIRA}
```

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 2 as ✅ COMPLETED

---

### Step 3: Get Objects

⚠️ **BLOCKING CHECK:** Verify Step 2 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 2.

**Mode A / Mode C — Get package contents:**

```
Tool: mcp_jarvis_get_package_contents_from_url
Input: package_url
```

This returns a list of objects with: name, type, UUID.

**Mode B — Resolve single object:**

First, try semantic search:
```
Tool: mcp_jarvis_search_objects_semantic
Input: searchTerm={object_name}, appPrefix={from get_jarvis_config}
```

If not found, try prefix search:
```
Tool: mcp_jarvis_search_objects_by_name
Input: searchTerm={object_name}
```

Extract: UUID, object type (friendly name), and map to typeId using the Object Type ID Mapping table.

**Sort objects for processing order** (lightweight first, heavyweight last):
- Constants → Expression Rules → Decision Rules → Integrations → Interfaces → Record Types → Process Models
- This ensures lightweight objects are persisted before heavyweight ones consume context

**Write to summary file:**

```markdown
## 2. Objects

| # | Object Name | Type | UUID | typeId |
|---|-------------|------|------|--------|
| 1 | {name} | {type} | {uuid} | {typeId} |
| 2 | ... | ... | ... | ... |

**Total objects:** {count}
```

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 3 as ✅ COMPLETED, show object count and sorted list

---

### Step 4: Determine Application Context

⚠️ **BLOCKING CHECK:** Verify Step 3 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 3.

```
Process:
  - Call `get_jarvis_config` to get the list of registered applications
  - Match object name prefix (AS_GSS, AS_VM) or JIRA project key against `appPrefix`, `appName`, `jiraProjects`
  - Store appUuid, appPrefix for later use
```

Update the summary file header with the application name.

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 4 as ✅ COMPLETED

---

### Step 5: Object Diff & Summary Loop (SEQUENTIAL — ONE AT A TIME)

⚠️ **BLOCKING CHECK:** Verify Step 4 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 4.

⚠️ **CRITICAL: Process objects ONE AT A TIME. Do NOT fetch all diffs in parallel.**
⚠️ **After each object, write findings to the summary file. Diff data falls out of context.**

For each object in the sorted list from Step 3, execute sub-steps 5a through 5c:

**Step 5a: Fetch Diff**

Call the diff API for the current object:

```
Tool: mcp_jarvis_get_object_diff
Input:
  - uuid: {object UUID}
  - typeId: {object typeId}
  - dateTime: {reference_date}  ← Mode A/C, or Mode B with dateTime
  - versionNumber: {version}    ← Mode B with versionNumber only
```

Record the raw result:
- `change_type`: NEW (old is null), MODIFIED (old ≠ latest), UNCHANGED (old = latest)
- `old_version`: version number at reference point (null if NEW)
- `latest_version`: current version number
- `old_expression` / `latest_expression`: SAIL code
- `old_inputs` / `latest_inputs`: rule inputs

**Step 5b: Summarize Changes**

For MODIFIED or NEW objects, analyze the diff:

1. **Read the old and latest SAIL code** from the diff result
2. **Compare them** — identify what was added, removed, or changed
3. **Write developer-friendly bullet points** describing each change
4. **Assign change categories** (🎨 UI, ⚙️ Logic, 🗄️ Data Model, 🔧 Config, 🆕 New)

**Summarization guidelines:**
- Be specific: "Added `vendorId` filter to the query" not "Updated query"
- Reference actual field/variable names from the SAIL code
- Note structural changes: "Moved scoring logic from inline to separate expression rule"
- For NEW objects: describe what the object does based on the latest code
- For interfaces: focus on component additions/removals, visibility changes, layout changes
- For expression rules: focus on logic changes, new parameters, filter changes, return value changes
- For constants: just state old value → new value
- For process models: focus on node additions/removals, flow changes, subprocess changes
- Keep each bullet to one clear change — don't combine multiple changes into one bullet

**Skip UNCHANGED objects** — note them in the summary but don't analyze further.

**Database verification (MANDATORY when diff involves database interaction):**

| Trigger (detected from diff result) | SQL to run |
|--------------------------------------|------------|
| NEW object with QE_/QR_ prefix | `DESCRIBE {target_table}` → verify the table it queries exists with expected columns |
| MODIFIED QE_/QR_ with new column references | `DESCRIBE {target_table}` → verify new columns exist |
| NEW or MODIFIED Record Type with field changes | `DESCRIBE {source_table}` → verify fields match database columns |
| NEW or MODIFIED object containing `a!queryEntity`/`a!queryRecordType` | `DESCRIBE {queried_table}` → verify table structure |
| Diff shows new `cons!*_ENT_*` references | `DESCRIBE {referenced_table}` → verify Data Store Entity target exists |

Skip SQL ONLY when: The diff shows changes to pure UI logic, variable renaming, comment changes, or non-database expression rules.

Budget: 0-2 SQL calls per object based on triggers above.

**Step 5c: Write Object Findings to Summary File**

⚠️ **CRITICAL: This step MUST happen before moving to the next object.**

Append the following to the summary markdown file for the current object:

For MODIFIED/NEW objects:
```markdown
### {Object Name} ({Type}) — {🎨/⚙️/🗄️/🔧/🆕} {Category}

**Change Type:** {MODIFIED / NEW}
**Versions:** v{old} → v{latest}

**Changes:**
- {Specific change description}
- {Specific change description}
- {Specific change description}

<details>
<summary>Raw Diff</summary>

Old Expression:
\`\`\`sail
{old expression or "N/A — new object"}
\`\`\`

Latest Expression:
\`\`\`sail
{latest expression}
\`\`\`

Old Inputs: {old inputs or "N/A"}
Latest Inputs: {latest inputs}
</details>

---
```

For UNCHANGED objects:
```markdown
### {Object Name} ({Type}) — ✅ UNCHANGED
No changes since reference point.

---
```

After writing, update the in-file tracker status.

⚠️ **AFTER COMPLETING EACH OBJECT:** Update chat tracker — mark the object as ✅ in the object list
⚠️ **AFTER ALL OBJECTS COMPLETE:** Update tracker — mark Step 5 as ✅ COMPLETED

**Budget:** 1 API call per object. For a typical package of 5-15 objects, this is 5-15 calls.

---

### Step 6: Impact Analysis

⚠️ **BLOCKING CHECK:** Verify ALL objects in Step 5 show ✅ COMPLETED. If any object is missing, STOP and complete it.

For each MODIFIED or NEW object, get the dependents count:

```
Tool: mcp_jarvis_get_object_dependencies
Input: object_uuid, dependency_type="DEPENDENTS", object_name
```

Classify risk:
- 🟢 Low: 0-5 dependents
- 🟡 Medium: 6-15 dependents
- 🔴 High: 16+ dependents

**Write to summary file:**

```markdown
## Impact Analysis

| Object | Change Type | Category | Dependents | Risk |
|--------|------------|----------|------------|------|
| {name} | MODIFIED | ⚙️ Logic | 12 | 🟡 Medium |
| {name} | NEW | 🆕 New | 0 | 🟢 Low |
| {name} | UNCHANGED | — | — | — |

**Overall Risk:** {🟢 Low / 🟡 Medium / 🔴 High} — based on highest individual risk
```

**Budget:** 1 API call per modified/new object.

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 6 as ✅ COMPLETED

---

### Step 7: AC Cross-Reference (Mode A Only)

⚠️ **BLOCKING CHECK:** Verify Step 6 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 6.

**Skip this step for Mode B and Mode C.** Mark as ⏭️ Skipped.

Compare the change summaries from Step 5 against the acceptance criteria extracted in Step 2.

For each AC:
- ✅ **Covered** — identify which object(s) and change(s) address this AC
- ⚠️ **Partially Covered** — some aspects addressed but not all
- ❌ **Not Covered** — no matching changes found in the package

**Write to summary file:**

```markdown
## Acceptance Criteria Coverage

| AC | Status | Covered By |
|----|--------|------------|
| AC1: {description} | ✅ Covered | {Object Name} — {specific change} |
| AC2: {description} | ⚠️ Partial | {Object Name} — {what's covered}. Missing: {what's not} |
| AC3: {description} | ❌ Not Covered | No matching changes found |
```

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 7 as ✅ COMPLETED (or ⏭️ Skipped for Mode B/C)

---

### Step 8: Present & Export

⚠️ **BLOCKING CHECK:** Verify Step 7 shows ✅ COMPLETED (or ⏭️ Skipped). If not, STOP and complete Step 7.

**Step 8a: Present Summary in Chat**

Present the complete summary in chat by reading the summary file and outputting it as a formatted markdown response. Include all sections:
1. Header with metadata
2. Per-object change summaries (condensed — just the change bullets, no raw diffs)
3. Impact analysis table
4. AC coverage (Mode A only)

**Step 8b: Ask About Google Doc Export**

**Mode A / Mode C:**

After presenting the summary, ask the user:

> "Would you like me to export this summary to Google Docs? I'll create it in the team's shared Drive folder."

**If user says yes:**

1. Use the `designDocFolderId` from the `get_jarvis_config` response for the matched application
2. Build an HTML document from the summary file contents:

```html
<h1>Implementation Summary — {TITLE}</h1>
<p><strong>JIRA:</strong> <a href="{url}">{TICKET_KEY}</a></p> <!-- Mode A -->
<p><strong>Package:</strong> <a href="{url}">{package_id}</a></p>
<p><strong>Reference Point:</strong> {dateTime}</p>
<p><strong>Application:</strong> {app name}</p>
<p><strong>Generated:</strong> {date} by JARVIS</p>

<h2>Summary Overview</h2>
<table>
  <tr><th>Object</th><th>Change</th><th>Category</th><th>Dependents</th><th>Risk</th></tr>
  <!-- One row per object -->
</table>

<h2>Detailed Changes</h2>
<!-- For each modified/new object: -->
<h3>{Object Name} ({Type}) — {Category Icon} {Category}</h3>
<p><strong>Versions:</strong> v{old} → v{latest}</p>
<ul>
  <li>{change bullet}</li>
  <li>{change bullet}</li>
</ul>

<!-- For unchanged objects: -->
<h3>{Object Name} ({Type}) — ✅ UNCHANGED</h3>
<p>No changes since reference point.</p>

<h2>Impact Analysis</h2>
<table>
  <tr><th>Object</th><th>Change Type</th><th>Category</th><th>Dependents</th><th>Risk</th></tr>
  <!-- Impact table -->
</table>
<p><strong>Overall Risk:</strong> {risk level}</p>

<!-- Mode A only: -->
<h2>Acceptance Criteria Coverage</h2>
<table>
  <tr><th>AC</th><th>Status</th><th>Covered By</th></tr>
  <!-- AC table -->
</table>
```

3. Write the HTML to a temp file and import to Google Docs:

```
Tool: fsWrite
Path: jarvis-appian/temp_impl_summary.html
Content: {HTML above}
```

```
Tool: mcp_google_workspace_import_to_google_doc
Input:
  - user_google_email: {user's Google email}
  - file_name: "Implementation Summary — {TITLE}"
  - file_path: "file:///Users/somasundaram.d/Soma-Repos/Appian MCP/jarvis-appian/temp_impl_summary.html"
  - source_format: "html"
  - folder_id: {designDocFolderId from get_jarvis_config for the matched application}
```

4. Present the Google Doc link to the user
5. Clean up temp file: `deleteFile jarvis-appian/temp_impl_summary.html`

**If user says no:**
- Confirm the local summary file path: `implementation-summary/{filename}.md`
- Done.

**Mode B — Chat output only:**

Present the summary directly in chat. No Google Doc export for Mode B — the chat response is the output.

```
## Implementation Summary — {Object Name}

**Reference:** {versionNumber or dateTime}
**Versions:** v{old} → v{latest}
**Change Type:** {MODIFIED / NEW}
**Category:** {icon} {category}
**Dependents:** {count} ({risk level})

### Changes:
- {bullet 1}
- {bullet 2}
- {bullet 3}
```

⚠️ **AFTER COMPLETING:** Update tracker — mark Step 8 as ✅ COMPLETED

---

## CONTEXT TRANSFER RESILIENCE

If context fills up during the object loop (Step 5), a new agent can resume:

1. Read the summary file from `implementation-summary/` to see which objects are already processed
2. Check the execution tracker in the last message to see current progress
3. Continue from the next unprocessed object
4. The summary file is the source of truth — not agent memory

**File naming convention:**
- With ticket: `implementation-summary/summary-GAMS-7130.md`
- Without ticket (Mode B): `implementation-summary/summary-{OBJECT_NAME}.md`
- Without ticket (Mode C): `implementation-summary/summary-pkg-{PACKAGE_ID}.md`
  - Package ID is extracted from the URL: `https://...appianpreview.com/suite/design/package/{PACKAGE-ID}`

---

## API Budget

| Step | Mode A | Mode B | Mode C |
|------|--------|--------|--------|
| Step 2: JIRA | 1 | 0 | 0 |
| Step 3: Package/Search | 1 | 1-2 | 1 |
| Step 5: Diffs | N (objects) | 1 | N (objects) |
| Step 6: Dependencies | N (modified) | 1 | N (modified) |
| Step 8: Export | 0-1 | 0 | 0-1 |
| **Total** | **2N + 2-3** | **3-4** | **2N + 1-2** |

For a typical package of 10 objects: ~22 API calls (Mode A).

---

## JIRA Status Names Reference

These are the exact status names on the JIRA board (case-sensitive for changelog matching):

- "Backlog"
- "Technical Design"
- "In Progress"
- "Code Review"
- "Verification & Validation"
- "Done"

**Precedence for reference_date:** "Technical Design" > "In Progress"
