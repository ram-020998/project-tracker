---
inclusion: manual
---

# Implementation Workflow

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING:**

1. ✅ **SHOW THE EXECUTION TRACKER** - Copy the tracker template below and paste it in your response RIGHT NOW
2. ✅ **READ THIS ENTIRE WORKFLOW FILE** - Don't skip ahead, don't assume you know the steps
3. ✅ **IDENTIFY YOUR STARTING POINT** - Determine which step you're on based on user input
4. ✅ **VERIFY BLOCKING RULES** - Check that previous steps are complete before proceeding

**IF YOU SKIP ANY OF THESE, YOU ARE VIOLATING THE WORKFLOW.**

**Common Triggers That Activate This Workflow:**
- "Implement GAMS-XXXX"
- "Create objects for [ticket]"
- "Implement [design document]"
- User selects option 4 from JARVIS menu

**When you see these triggers, your FIRST action is to show the tracker. Not call tools. Not create objects. SHOW THE TRACKER.**

---

## CRITICAL RULES - MANDATORY COMPLIANCE
- ⚠️ STRICT ENFORCEMENT: Follow these steps EXACTLY in order. NO DEVIATIONS ALLOWED.
- ⚠️ STEP SKIPPING IS FORBIDDEN: Every step must be completed before proceeding to the next.
- ⚠️ DESIGN DOCUMENT IS MANDATORY: Implementation requires an approved design document.
- ⚠️ ONE OBJECT AT A TIME: Create objects sequentially with user confirmation for each.
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
⚠️ DO NOT apply patterns from Design Doc Workflow or Code Review Workflow
⚠️ DO NOT create HTML files (that's design doc workflow)
⚠️ DO NOT review code (that's code review workflow)
⚠️ DO NOT create packages (that's design doc workflow)
⚠️ THIS WORKFLOW: Create Appian objects from design doc → Deploy via Deployment API

**Key Differences:**
- **Design Doc Workflow:** Creates HTML file → Imports to Google Docs → Creates package
- **Implementation Workflow:** Creates Appian objects via Deployment API (NO HTML files, NO code review)
- **Code Review Workflow:** Reviews existing code → Presents text response

**What This Workflow Does:**
1. Reads design document from Google Drive
2. Parses TECHNICAL DETAILS section for object specifications
3. Creates objects one at a time with user confirmation
4. Uses Deployment API to deploy objects to Appian
5. Updates design doc with implementation status

**What This Workflow Does NOT Do:**
- ❌ Create HTML files or Google Docs
- ❌ Review code quality or best practices
- ❌ Create packages (package already exists from design workflow)
- ❌ Present findings as text

If you find yourself creating HTML files or reviewing code, STOP - you're in the wrong workflow.

## Overview

This workflow implements Appian objects from approved design documents. It supports two paths:
- **Path A**: Implement from design document (for JIRA tickets)
- **Path B**: Direct object creation (for ad-hoc objects)

Currently supports: **Constants only** (other object types coming soon)

---

## MANDATORY EXECUTION TRACKER - PATH A

⚠️ **CRITICAL: You MUST maintain this execution tracker throughout the workflow**
⚠️ **Copy this tracker into your response and update it after EACH step**
⚠️ **If any step shows ❌, you are FORBIDDEN from proceeding to the next step**

```
IMPLEMENTATION WORKFLOW (PATH A) EXECUTION TRACKER - GAMS-XXXX
================================================================
Step 1: Search for Design Document  [ ] ❌ NOT STARTED
Step 2: Read Design Document        [ ] ❌ NOT STARTED
Step 3: Parse Object Specifications [ ] ❌ NOT STARTED
Step 4: Display Object List         [ ] ❌ NOT STARTED
Step 5: Preview Object              [ ] ❌ NOT STARTED ⚠️ REQUIRED TOOL: preview_constant
Step 6: Create Object               [ ] ❌ NOT STARTED ⚠️ REQUIRED TOOL: create_constant
Step 7: Update Design Document      [ ] ❌ NOT STARTED

BLOCKING RULES:
- Cannot proceed to Step 2 until Step 1 shows ✅
- Cannot proceed to Step 3 until Step 2 shows ✅
- Cannot proceed to Step 4 until Step 3 shows ✅
- Cannot proceed to Step 5 until Step 4 shows ✅
- Cannot proceed to Step 6 until Step 5 shows ✅ AND user confirms
- Cannot proceed to Step 7 until Step 6 shows ✅

CURRENT STATUS: Workflow not started
NEXT REQUIRED ACTION: Execute Step 1
```

## MANDATORY EXECUTION TRACKER - PATH B

```
IMPLEMENTATION WORKFLOW (PATH B) EXECUTION TRACKER
===================================================
Step 1: Show Application List       [ ] ❌ NOT STARTED
Step 2: Get Application Info        [ ] ❌ NOT STARTED ⚠️ REQUIRED TOOL: get_application_info
Step 3: Collect Object Parameters   [ ] ❌ NOT STARTED
Step 4: Preview Object              [ ] ❌ NOT STARTED ⚠️ REQUIRED TOOL: preview_constant
Step 5: Create Object               [ ] ❌ NOT STARTED ⚠️ REQUIRED TOOL: create_constant

BLOCKING RULES:
- Cannot proceed to Step 2 until Step 1 shows ✅
- Cannot proceed to Step 3 until Step 2 shows ✅
- Cannot proceed to Step 4 until Step 3 shows ✅
- Cannot proceed to Step 5 until Step 4 shows ✅ AND user confirms

CURRENT STATUS: Workflow not started
NEXT REQUIRED ACTION: Execute Step 1
```

**HOW TO USE THIS TRACKER:**
1. Copy the appropriate tracker (Path A or Path B) into your response at the start
2. After completing each step, update the tracker:
   - Change [ ] to [✅] for completed steps
   - Change ❌ NOT STARTED to ✅ COMPLETED with tool name
3. Show the updated tracker in EVERY response
4. Check BLOCKING RULES before proceeding to next step
5. If you cannot show ✅ for a step, you MUST stop and complete it

---

## Path A: Implement from Design Document

### Trigger

User says: **"Implement GAMS-XXXX"** (or any JIRA ticket key)

### Step 1: Search for Design Document

⚠️ **BEFORE STARTING:** Show the Path A execution tracker with Step 1 marked as IN PROGRESS

1. Call `mcp_google_workspace_search_drive_files` with:
   - `query`: "GAMS-XXXX" (the ticket key)
   - `drive_id`: Not specified (searches user's drive)
   - `include_items_from_all_drives`: true
   - Filter results to folder: {from `get_jarvis_config` → matched app → designDocFolderId}

2. If NO document found:
   ```
   ❌ Design document not found for GAMS-XXXX.
   
   Please run the design workflow first:
   "Start Design for GAMS-XXXX"
   ```
   **STOP WORKFLOW** - Do not proceed without design document.

3. If multiple documents found:
   - Use the most recently modified document
   - Show user which document was selected

4. Get document ID from search results

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 1 as ✅ COMPLETED, show document found

### Step 2: Read Design Document

⚠️ **BLOCKING CHECK:** Verify Step 1 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 1.

⚠️ **BEFORE STARTING:** Update tracker - mark Step 2 as IN PROGRESS

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 1:
- ✅ Called mcp_google_workspace_search_drive_files with ticket key
- ✅ Filtered results to design doc folder
- ✅ Found design document (or stopped workflow if not found)
- ✅ Have document ID ready for reading

1. Call `mcp_google_workspace_get_doc_as_markdown` with:
   - `document_id`: From Step 1
   - `include_comments`: false
   - `user_google_email`: {user's Google email}

2. Parse the Markdown content to extract:
   - **TECHNICAL DETAILS** section (contains JSON array of objects)
   - **IMPLEMENTATION PLAN** section (for context)
   - **DEPLOYMENT** section (for package URL)

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 2 as ✅ COMPLETED, show sections found

### Step 3: Parse Object Specifications

⚠️ **BLOCKING CHECK:** Verify Step 2 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 2.

⚠️ **BEFORE STARTING:** Update tracker - mark Step 3 as IN PROGRESS

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 2:
- ✅ Called mcp_google_workspace_get_doc_as_markdown
- ✅ Retrieved Markdown content
- ✅ Identified TECHNICAL DETAILS section
- ✅ Identified IMPLEMENTATION PLAN section
- ✅ Identified DEPLOYMENT section
- ✅ Have document content ready for parsing

1. Extract JSON from TECHNICAL DETAILS section (between ```json and ```)

2. Expected JSON format:
   ```json
   [
     {
       "name": "AS_GSS_INT_MAX_RETRIES",
       "uuid": "[UUID to be generated]",
       "type": "CONSTANT",
       "namespace": "type!{http://www.w3.org/2001/XMLSchema}int",
       "folder": "AS CO SAIL Design Objects",
       "folderUuid": "abc-123-def-456",
       "value": 3,
       "description": "Maximum number of retry attempts"
     }
   ]
   ```

3. Required fields for constants:
   - `name`: Object name
   - `type`: Must be "CONSTANT"
   - `namespace`: Type namespace (extract constant_type from this)
   - `folder`: Folder name (for display)
   - `folderUuid`: Folder UUID (for creation)
   - `value`: Constant value
   - `description`: Constant description

4. Extract `constant_type` from namespace:
   - From `"type!{http://www.w3.org/2001/XMLSchema}int"` → Extract "int"
   - From `"type!{http://www.appian.com/ae/types/2009}Text"` → Extract "Text"
   - Pattern: Extract text after last `}` or last `/`

⚠️ **AFTER COMPLETING:** Update tracker - mark Step 3 as ✅ COMPLETED, show object count

### Step 4: Display Object Selection List

⚠️ **BLOCKING CHECK:** Verify Step 3 shows ✅ COMPLETED in tracker. If not, STOP and complete Step 3.

⚠️ **BEFORE STARTING:** Update tracker - mark Step 4 as IN PROGRESS

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 3:
- ✅ Extracted JSON from TECHNICAL DETAILS section
- ✅ Parsed all object specifications
- ✅ Validated required fields for each object
- ✅ Extracted constant_type from namespace for constants
- ✅ Have complete object list ready for display

1. Group objects by support status:
   - **Supported**: type = "CONSTANT"
   - **Not Supported**: All other types

2. Display numbered list:
   ```
   Objects from GAMS-XXXX design document:
   
   SUPPORTED:
   1. AS_GSS_INT_MAX_RETRIES (Constant)
   2. AS_GSS_TXT_ERROR_MESSAGE (Constant)
   
   NOT SUPPORTED YET:
   3. AS_GSS_BL_validateInput (Expression Rule)
   4. SSD_TestRecordTasks (Record Type)
   
   Enter object number to create (one at a time), or 'done' to finish:
   ```

3. Wait for user input (single number)

4. If user enters number for unsupported object:
   ```
   ⚠️ Object type not supported yet. Please select a constant (1 or 2).
   ```

5. If user enters 'done' or 'exit':
   - Skip to Step 7 (Update Implementation Status)

### Step 5: Validate and Auto-Fix Object Name

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 4:
- ✅ Displayed object selection list
- ✅ Received user selection (object number)
- ✅ Validated selection is for supported object type
- ✅ Have selected object ready for validation

1. Get application info to determine naming convention:
   - Extract `appUuid` from first object's folder or ask user
   - Call `mcp_appian_get_application_info` with appUuid
   - Extract `namingConvention` (e.g., "AS_GSS")

2. Check if object name follows convention:
   - Valid: Starts with "{namingConvention} " (space) or "{namingConvention}_" (underscore)
   - Examples: "AS_GSS INT_MAX_RETRIES", "AS_GSS_INT_MAX_RETRIES"

3. If name does NOT follow convention:
   - **Auto-fix**: Add prefix + type
   - Original: "MAX_RETRIES"
   - Fixed: "AS_GSS_INT_MAX_RETRIES"
   - Pattern: `{namingConvention}_{TYPE}_{original_name}`
   - Show user: "⚠️ Auto-fixed name: MAX_RETRIES → AS_GSS_INT_MAX_RETRIES"

### Step 6: Preview and Create Object

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 5:
- ✅ Called mcp_appian_get_application_info
- ✅ Extracted namingConvention
- ✅ Validated object name against convention
- ✅ Auto-fixed name if needed
- ✅ Have validated object ready for creation

⚠️ OUTPUT: Creates actual Appian objects via Deployment API (NOT HTML files, NOT text reviews)
⚠️ DO NOT create HTML files - create objects in Appian instead
⚠️ DO NOT review code - create objects from design specs

**Pre-creation database check (jarvis-smt integration — for future object types):**

When creating Record Types or Data Store Entities (future enhancement), verify the underlying table exists BEFORE attempting creation:
```sql
DESCRIBE Appian.{TABLE_NAME}
```
- If table NOT found → STOP and warn: "Table {TABLE_NAME} does not exist. Run the DDL script from the design doc's DATABASE CHANGES section first."
- If table found → proceed with creation
- For Constants: skip this check (constants don't require database tables)

1. Call `mcp_appian_preview_constant` with:
   - `name`: Object name (auto-fixed if needed)
   - `value`: From TECHNICAL DETAILS JSON
   - `constant_type`: Extracted from namespace
   - `description`: From TECHNICAL DETAILS JSON
   - `app_uuid`: From Step 5
   - `folder_uuid`: From TECHNICAL DETAILS JSON

2. Show preview to user:
   ```
   CONSTANT DETAILS
   Application: AS GSS Full Application
   Name: AS_GSS_INT_MAX_RETRIES
   Description: Maximum number of retry attempts
   Type: int
   Value: 3
   Environment Specific: No
   Save in: AS CO SAIL Design Objects
   UUID: abc-123-def-456
   
   Create this constant? (y/n):
   ```

3. Wait for user confirmation:
   - If **yes** → Proceed to create
   - If **no** → Mark as skipped, return to Step 4

4. Call `mcp_appian_create_constant` with same parameters

5. Track result:
   - ✅ Success: Store UUID and status
   - ❌ Failure: Store error message

6. Return to Step 4 for next object

### Step 7: Update Design Document with Implementation Status

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 6:
- ✅ Created all selected objects (or user said 'done')
- ✅ Tracked results for each object (success/skipped/failed)
- ✅ Have complete implementation results ready for documentation
- ✅ Ready to update design document

1. Get document structure:
   - Call `mcp_google_workspace_inspect_doc_structure` to find end of document

2. Create IMPLEMENTATION STATUS table at end:
   - Call `mcp_google_workspace_create_table_with_data` with:
     - `index`: End of document (from step 1)
     - `bold_headers`: true
     - `table_data`: 2x1 table with header and content
   
   Example table data:
   ```
   [
     ["IMPLEMENTATION STATUS"],
     ["Implementation Date: 2026-02-22 15:30:00\n\nObjects Created:\n• AS_GSS_INT_MAX_RETRIES (UUID: abc-123) - Created successfully\n• AS_GSS_TXT_ERROR_MESSAGE (UUID: def-456) - Created successfully\n• AS_GSS_BL_validateInput - Skipped by user\n• AS_GSS_INT_TIMEOUT - Failed: Duplicate constant name\n\nSummary: 2 created, 1 skipped, 1 failed out of 4 total objects"]
   ]
   ```

3. Apply text background color to header (optional):
   - Call `mcp_google_workspace_modify_doc_text` with:
     - `background_color`: "#FFFACD" (light yellow)
     - Range: Header cell text range
   - Note: This colors the text only, not the entire cell
   - For full cell background, user must manually set in Google Docs UI

4. Show final summary:
   ```
   ✅ Implementation complete for GAMS-XXXX
   
   Results:
   - 2 objects created successfully
   - 1 object skipped by user
   - 1 object failed
   
   Design document updated with implementation status.
   Note: To apply light yellow background to entire header cell, 
   open the document and set cell background color manually.
   ```

---

## Path B: Direct Object Creation

### Trigger

User says: **"Create constant {NAME}"** (e.g., "Create constant AS_GSS_INT_MAX_RETRIES")

### Step 1: Extract Object Name

1. Parse object name from user input
2. If no name provided, ask: "What is the constant name?"

### Step 2: Get Application Context

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 1:
- ✅ Extracted object name from user input
- ✅ Have object name ready for application context

1. Call `get_jarvis_config` to get list of applications

2. Show application list:
   ```
   Select application:
   1. AS GSS Full Application
   2. AS GAM Full Application
   3. AS VM Full Application
   
   Enter number:
   ```

3. Get selected app's `appUuid` from config

4. Call `mcp_appian_get_application_info` with appUuid

5. Extract:
   - `namingConvention` (e.g., "AS_GSS")
   - `ruleFolderDetails[]` (list of folders)
   - `lastUsedFolderForConst` (default folder UUID)

### Step 3: Auto-Fix Object Name

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 2:
- ✅ Displayed application list
- ✅ Received user selection
- ✅ Retrieved appUuid from config
- ✅ Called mcp_appian_get_application_info
- ✅ Extracted namingConvention and ruleFolderDetails
- ✅ Have application context ready for name validation

1. Check if name follows convention:
   - Valid: Starts with "{namingConvention} " or "{namingConvention}_"

2. If NOT valid:
   - Ask user for constant type: "What type? (int, Text, Boolean, etc.)"
   - Auto-fix: `{namingConvention}_{TYPE}_{original_name}`
   - Show: "⚠️ Auto-fixed name: MAX_RETRIES → AS_GSS_INT_MAX_RETRIES"

### Step 4: Get Folder Selection

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 3:
- ✅ Validated object name against naming convention
- ✅ Auto-fixed name if needed
- ✅ Have validated object name ready for folder selection

1. Show folder list from `ruleFolderDetails`:
   ```
   Select folder:
   1. AS CO SAIL Design Objects (default)
   2. AS CO Constants
   3. AS CO Utilities
   
   Enter number (or press Enter for default):
   ```

2. If user presses Enter, use `lastUsedFolderForConst`

3. Get selected folder's UUID

### Step 5: Get Constant Parameters

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 4:
- ✅ Displayed folder list
- ✅ Received user selection (or used default)
- ✅ Have folder UUID ready for object creation

1. Ask for value:
   ```
   Enter constant value:
   ```

2. Ask for description:
   ```
   Enter constant description:
   ```

3. Ask for constant type (if not already determined from auto-fix):
   ```
   Enter constant type (int, Text, Boolean, Date, Document):
   ```

### Step 6: Preview and Create

⚠️ **VALIDATION CHECKPOINT:** Before proceeding, confirm you have completed Step 5:
- ✅ Received constant value from user
- ✅ Received constant description from user
- ✅ Received constant type from user
- ✅ Have all parameters ready for preview and creation

1. Call `mcp_appian_preview_constant` with collected parameters

2. Show preview and wait for confirmation (y/n)

3. If yes → Call `mcp_appian_create_constant`

4. Show result

---

## Error Handling

### Design Document Not Found
- **Action**: Stop workflow, tell user to run design workflow first
- **Message**: "Design document not found. Please run 'Start Design for GAMS-XXXX' first."

### Invalid Object Selection
- **Action**: Show error, ask for valid selection
- **Message**: "Invalid selection. Please enter a number from the list."

### Unsupported Object Type
- **Action**: Show warning, ask for different selection
- **Message**: "Object type not supported yet. Please select a constant."

### Object Creation Failure
- **Action**: Log error, mark as failed, continue with next object
- **Message**: "❌ Failed to create {name}: {error_message}"

### Duplicate Constant Name
- **Action**: Show error, mark as failed, continue with next object
- **Message**: "❌ Constant {name} already exists. Skipping."

---

## Configuration

- **Design Doc Folder**: From `get_jarvis_config` → applications[].appConfig.designDocFolderId (per application)
- **User Email**: User's Google email (from MCP environment or ask user)
- **App Config**: `get_jarvis_config` API (replaces config/app_config.json)
- **Supported Object Types**: CONSTANT (others coming soon)

---

## Technical Details JSON Schema

Required fields for constants in TECHNICAL DETAILS section:

```json
{
  "name": "string (object name)",
  "uuid": "string (UUID or '[UUID to be generated]')",
  "type": "string (must be 'CONSTANT')",
  "namespace": "string (type namespace, e.g., 'type!{http://www.w3.org/2001/XMLSchema}int')",
  "folder": "string (folder name for display)",
  "folderUuid": "string (folder UUID for creation)",
  "value": "any (constant value - number, string, boolean, etc.)",
  "description": "string (constant description)"
}
```

---

## Implementation Status Section Format

The implementation status is added as a 2x1 table at the end of the design document:

**Row 1 (Header):**
- Text: "IMPLEMENTATION STATUS" (bold)
- Text background: Light yellow (#FFFACD) applied to text only
- Note: Full cell background color must be set manually in Google Docs UI

**Row 2 (Content):**
- Implementation Date
- Objects Created (bullet list with status icons)
- Summary line

**Example:**
```
┌─────────────────────────────────────────────────────────┐
│ IMPLEMENTATION STATUS (bold, yellow text background)    │
├─────────────────────────────────────────────────────────┤
│ Implementation Date: 2026-02-22 15:30:00                │
│                                                          │
│ Objects Created:                                         │
│ • AS_GSS_INT_MAX_RETRIES (UUID: abc-123) - Created      │
│ • AS_GSS_TXT_ERROR_MESSAGE (UUID: def-456) - Created    │
│ • AS_GSS_BL_validateInput - Skipped by user             │
│ • AS_GSS_INT_TIMEOUT - Failed: Duplicate name           │
│                                                          │
│ Summary: 2 created, 1 skipped, 1 failed out of 4 total  │
└─────────────────────────────────────────────────────────┘
```

Status Icons:
- ✅ = Created successfully
- ⏭️ = Skipped by user
- ❌ = Failed with error

---

## Future Enhancements

1. **Support for Expression Rules**: Create expression rules from design docs
2. **Support for Interfaces**: Create interfaces with SAIL code
3. **Support for Record Types**: Create record types with relationships
4. **Batch Creation**: Create multiple objects without individual confirmation
5. **Package Integration**: Add created objects to package automatically
6. **Rollback**: Undo created objects if workflow fails
7. **Update Operations**: Modify existing objects instead of just creating new ones
