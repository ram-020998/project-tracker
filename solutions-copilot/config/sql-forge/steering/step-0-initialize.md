---
inclusion: auto
---

# Step 0: Initialize Data Request

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING ELSE:**

1. ✅ **SHOW THE EXECUTION TRACKER** — Copy the tracker template below and paste it in your response RIGHT NOW
2. ✅ **CREATE THE FOLDER** — Create the data-requests folder with the correct naming
3. ✅ **CREATE ALL 6 FILES** — Every file must exist with PENDING status before you proceed
4. ✅ **VERIFY ALL FILES EXIST** — List the folder contents to confirm

**IF YOU SKIP ANY OF THESE, YOU ARE VIOLATING THE WORKFLOW.**

---

## CRITICAL RULES — MANDATORY COMPLIANCE

- ⚠️ **ALL 6 FILES MUST BE CREATED NOW** — Not later. Not "when we get to that milestone." NOW.
- ⚠️ **FILES ARE GATES** — No milestone can start unless its file already exists on disk.
- ⚠️ **EXECUTION TRACKER IS MANDATORY** — Show it in EVERY response and update after each step.
- ⚠️ **BLOCKING CHECKS** — Before starting any milestone, verify this Step 0 shows ✅ COMPLETED.
- ⚠️ **NO TOOL CALLS BEFORE STEP 0 IS COMPLETE** — Do not call Atlas MCP, Data Generator, or any API until all 6 files exist.

---

## MANDATORY EXECUTION TRACKER

⚠️ **Copy this tracker into your response and update it after EACH milestone.**

```
DATA GENERATION WORKFLOW — EXECUTION TRACKER
=============================================
Request: {user's request summary}
Application: {app_name}
Mode: {records | sql}
Folder: data-requests/{YYYY-MM-DD}_{short-description}/

Step 0: Initialize                     [  ] ❌ NOT STARTED
  - Create folder                      [  ] ❌
  - Create analysis.md (PENDING)       [  ] ❌
  - Create exemplar.md (PENDING)       [  ] ❌
  - Create data-architecture.md (PENDING) [  ] ❌
  - Create payloads/00-metadata.json (PENDING) [  ] ❌
  - Create validation-report.md (PENDING) [  ] ❌
  - Create execution-log.md (PENDING)  [  ] ❌
  - Verify all files exist             [  ] ❌

Step 1: Workflow Analysis              [  ] ❌ NOT STARTED
Step 2: Exemplar Discovery             [  ] ❌ NOT STARTED
Step 3: Data Architecture              [  ] ❌ NOT STARTED
Step 4: Data Payloads                  [  ] ❌ NOT STARTED
Step 5: Validation                     [  ] ❌ NOT STARTED
Step 6: Execution/SQL Generation       [  ] ❌ NOT STARTED

BLOCKING RULES:
- Cannot start Step 1 until Step 0 shows ✅ (all 6 files exist)
- Cannot start Step 2 until Step 1 shows ✅ (analysis.md updated)
- Cannot start Step 3 until Step 2 shows ✅ (exemplar.md updated)
- Cannot start Step 4 until Step 3 shows ✅ (data-architecture.md updated)
- Cannot start Step 5 until Step 4 shows ✅ (payloads/ files written)
- Cannot start Step 6 until Step 5 shows ✅ (validation-report.md updated)

CURRENT STATUS: Step 0 — Initializing
NEXT REQUIRED ACTION: Create folder and all 6 files
```

---

## EXECUTION

### 0a: Determine Folder Name

Parse the user's request to extract:
- **Application name** — which Appian application (e.g., "SourceSelection", "GrantManagement")
- **Short description** — what they want (e.g., "eval-complete-3-vendors", "bulk-100-evaluations")
- **Mode** — records or sql

Folder name format: `data-requests/{YYYY-MM-DD}_{short-description}/`

### 0b: Create the Folder

Create the folder in the current working directory.

### 0c: Create All 6 Files

Create each file with the PENDING template below. **All 6 files. No exceptions.**

---

**File 1: `analysis.md`**

```markdown
# Workflow Analysis

**Status:** ⏳ PENDING
**Application:** {app_name}
**Request:** {user's request}
**Mode:** {records | sql}
**Created:** {YYYY-MM-DD}

---

## Workflow Path

_To be completed in Step 1_

## Business Rules

_To be completed in Step 1_

## Required Statuses & Transitions

_To be completed in Step 1_

## Tables Involved

_To be completed in Step 1_
```

---

**File 2: `exemplar.md`**

```markdown
# Exemplar Discovery

**Status:** ⏳ PENDING
**Application:** {app_name}
**Request:** {user's request}
**Created:** {YYYY-MM-DD}

---

## Exemplar Record

_To be completed in Step 2_

## Child Records by Relationship

_To be completed in Step 2_

## Field Value Patterns

_To be completed in Step 2_

## Data Footprint Summary

_To be completed in Step 2_
```

---

**File 3: `data-architecture.md`**

```markdown
# Data Architecture

**Status:** ⏳ PENDING
**Application:** {app_name}
**Request:** {user's request}
**Created:** {YYYY-MM-DD}

---

## Record Type Coverage Checklist

_To be completed in Step 3_

## Reference Data Values

_To be completed in Step 3_

## Insertion Order

_To be completed in Step 3_

## Field Mappings

_To be completed in Step 3_
```

---

**File 4: `payloads/00-metadata.json`**

```json
{
  "status": "PENDING",
  "application": "{app_name}",
  "request": "{user's request}",
  "mode": "{records | sql}",
  "created": "{YYYY-MM-DD}",
  "total_records": 0,
  "file_sequence": []
}
```

---

**File 5: `validation-report.md`**

```markdown
# Validation Report

**Status:** ⏳ PENDING
**Application:** {app_name}
**Request:** {user's request}
**Created:** {YYYY-MM-DD}

---

## Table Coverage

_To be completed in Step 5_

## FK Integrity Check

_To be completed in Step 5_

## Exemplar Diff

_To be completed in Step 5_

## Reference Data Validation

_To be completed in Step 5_
```

---

**File 6: `execution-log.md`**

```markdown
# Execution Log

**Status:** ⏳ PENDING
**Application:** {app_name}
**Request:** {user's request}
**Mode:** {records | sql}
**Created:** {YYYY-MM-DD}

---

## Created Records / Generated SQL

_To be completed in Step 6_

## Verification Results

_To be completed in Step 6_

## Session Summary

_To be completed in Step 6_
```

---

### 0d: Verify All Files Exist

List the contents of the folder. You MUST see exactly 6 items:
1. `analysis.md`
2. `exemplar.md`
3. `data-architecture.md`
4. `payloads/00-metadata.json` (inside a `payloads/` subfolder)
5. `validation-report.md`
6. `execution-log.md`

**If any file is missing, create it now. Do NOT proceed.**

### 0e: Update Tracker

Update the execution tracker:
- Mark all sub-items under Step 0 as ✅
- Mark Step 0 as ✅ COMPLETED
- Set CURRENT STATUS to: `Step 1 — Workflow Analysis`

---

## COMPLETION CRITERIA

Step 0 is ✅ COMPLETE only when ALL of these are true:

- [ ] Folder exists at `data-requests/{date}_{description}/`
- [ ] `analysis.md` exists with PENDING status
- [ ] `exemplar.md` exists with PENDING status
- [ ] `data-architecture.md` exists with PENDING status
- [ ] `payloads/00-metadata.json` exists with PENDING status
- [ ] `validation-report.md` exists with PENDING status
- [ ] `execution-log.md` exists with PENDING status
- [ ] Folder listing confirms all 6 files

**ONLY THEN may you proceed to Step 1.**
