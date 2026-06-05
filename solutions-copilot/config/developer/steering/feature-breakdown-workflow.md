---
inclusion: auto
---

# Feature Breakdown Workflow

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING:**

1. ✅ **SHOW THE EXECUTION TRACKER** - Copy the tracker template below and paste it in your response RIGHT NOW
2. ✅ **READ THIS ENTIRE WORKFLOW FILE** - Don't skip ahead, don't assume you know the steps
3. ✅ **IDENTIFY YOUR STARTING POINT** - Determine which step you're on based on user input
4. ✅ **VERIFY BLOCKING RULES** - Check that previous steps are complete before proceeding

**IF YOU SKIP ANY OF THESE, YOU ARE VIOLATING THE WORKFLOW.**

**Common Triggers That Activate This Workflow:**
- "Feature breakdown for [feature name]"
- "Break down this feature: [spec doc link]"
- "Generate grooming tickets from [spec doc]"
- "Create feature breakdown from spec and mockups"
- User selects option 6 from JARVIS menu

**When you see these triggers, your FIRST action is to show the tracker. Not call tools. Not read documents. SHOW THE TRACKER.**

---

## Overview

Automated workflow to generate a feature breakdown document from a specification document (Google Doc) and optional mockup slide deck (Google Slides). The output is a structured table of Epics and Tickets suitable for team grooming sessions.

**Output Format:** Google Sheet with 3 tabs — Breakdown (Epic | Ticket Title | Description | Acceptance Criteria | Effort | Mockup Ref | Story Points), Codebase Research, Summary

**Output Destination:** Google Sheet

## Trigger

User says: **"Feature breakdown for [feature name]"** and provides:
- A Google Doc link (spec document) — REQUIRED
- A Google Slides link (mockup deck) — OPTIONAL

If the user doesn't provide links, ask for them.

## CRITICAL RULES - MANDATORY COMPLIANCE

- ⚠️ Follow steps EXACTLY in order. NO DEVIATIONS.
- ⚠️ Every step must be completed before proceeding to the next.
- ⚠️ EXECUTION TRACKER IS MANDATORY in EVERY response.
- ⚠️ Create a Google Sheet with 3 tabs (Breakdown, Codebase Research, Summary).
- ⚠️ Call `get_jarvis_config` to determine application context.

## WORKFLOW ISOLATION - CRITICAL

⚠️ THIS WORKFLOW IS COMPLETELY INDEPENDENT
⚠️ DO NOT apply patterns from Design Workflow or Code Review Workflow
⚠️ DO NOT create Appian objects (that's implementation workflow)
⚠️ DO NOT review code (that's code review workflow)

**What This Workflow Does:**
1. Reads spec document and mockup slides
2. Researches existing codebase for relevant objects
3. Generates a feature breakdown with epics and tickets
4. Creates a Google Sheet with breakdown, codebase research, and summary tabs

**What This Workflow Does NOT Do:**
- ❌ Create JIRA tickets (that's manual, done after grooming)
- ❌ Create design documents (that's design workflow)
- ❌ Create Appian objects
- ❌ Review code

---

## MANDATORY EXECUTION TRACKER

```
FEATURE BREAKDOWN EXECUTION TRACKER — [FEATURE NAME]
=====================================================
Step 1: Collect Inputs            [ ] ❌ NOT STARTED
Step 2: Read Spec Document        [ ] ❌ NOT STARTED
Step 3: Read Mockup Slides        [ ] ❌ NOT STARTED (skip if no slides)
Step 4: Determine Application     [ ] ❌ NOT STARTED
Step 5: Codebase Research         [ ] ❌ NOT STARTED
Step 6: Generate Breakdown        [ ] ❌ NOT STARTED
Step 7: Create Google Sheet      [ ] ❌ NOT STARTED

BLOCKING RULES:
- Cannot proceed to Step 2 until Step 1 shows ✅
- Cannot proceed to Step 3 until Step 2 shows ✅
- Cannot proceed to Step 4 until Step 3 shows ✅ (or skipped)
- Cannot proceed to Step 5 until Step 4 shows ✅
- Cannot proceed to Step 6 until Step 5 shows ✅
- Cannot proceed to Step 7 until Step 6 shows ✅

CURRENT STATUS: Workflow not started
NEXT REQUIRED ACTION: Execute Step 1
```

---

## Workflow Steps

### Step 1: Collect Inputs

Extract from the user's message:
- **Feature name** — used as document title
- **Spec document link** — Google Doc ID (extract from URL)
- **Mockup slides link** — Google Slides presentation ID (extract from URL, optional)
- **Target release** — if mentioned (optional)

If the spec document link is missing, ask the user for it. Mockup slides are optional.

**Extract Google Doc ID:** From `https://docs.google.com/document/d/{DOC_ID}/edit...` → extract `{DOC_ID}`
**Extract Slides ID:** From `https://docs.google.com/presentation/d/{SLIDES_ID}/edit...` → extract `{SLIDES_ID}`

---

### Step 2: Read Spec Document

```
Tool: mcp_google_workspace_get_doc_content
Input:
  - document_id: {DOC_ID from Step 1}
  - user_google_email: {user's Google email}
```

**Processing the spec content:**

1. The spec may have multiple tabs. Focus on the MAIN spec tab (usually the first tab, or the one named "Spec").
2. Skip tabs that are clearly research, brainstorming, or sample data (e.g., "Research", "Rough", "Sample Prompts", "Template Research").
3. Extract the following from the spec:
   - **Summary** — what is the feature about
   - **Use cases** — what users can do (guiding use cases)
   - **Use cases NOT supported** — explicit exclusions
   - **Functional areas** — distinct areas of functionality (UI screens, backend pipelines, data model changes)
   - **User flows** — step-by-step user interactions
   - **Data structures** — new or modified data entities
   - **Integration points** — external systems, AI services, APIs
   - **Success criteria** — if defined
   - **Open questions** — if any

4. If the spec is very large (>5000 words), prioritize: Summary → Use Cases → User Flows → Data Structures. Skip verbose prompt templates and research notes.

---

### Step 3: Read Mockup Slides (Skip if no slides provided)

```
Tool: mcp_google_workspace_get_presentation
Input:
  - presentation_id: {SLIDES_ID from Step 1}
  - user_google_email: {user's Google email}
```

**Processing the slides:**

1. Extract all text content from each slide (title + body text annotations).
2. The slides are text-annotated mockups — the text descriptions describe each UI state.
3. Map each slide to a UI state:
   - Empty states (no data, loading, disabled)
   - Loaded states (data displayed, default selections)
   - Interaction states (expanded/collapsed, modal open, popup)
   - Error states (failed, not found, unavailable)
4. Group slides by screen/page (e.g., "Vendor Analysis Tab" slides 2-14, "Evaluation Form" slides 15-17).
5. Note: Actual visual mockup images cannot be parsed — rely on text annotations only.

---

### Step 4: Determine Application Context

```
Process:
  - Call `get_jarvis_config` to get the list of registered applications
  - Match keywords from the spec against `appPrefix`, `appName`, `jiraProjects`
  - Use the matched application's appUuid for list_application_objects calls
  - Use the matched application's appPrefix for search_objects_semantic calls (e.g., "AS_GSS", "AS_VM")
  - If no match found, ask the user which application
```

---

### Step 5: Codebase Research

Search the existing codebase to identify objects that will need modification or that are relevant to the feature. This makes tickets actionable with real object names.

**Search Tool Hierarchy:**

| Priority | Tool | Best For |
|----------|------|----------|
| 1st | `search_objects_semantic` | Primary discovery — natural language, cross-app, ranked by relevance. Does NOT return Record Types. Use `appPrefix` from `get_jarvis_config`. |
| 2nd | `list_application_objects` | Exhaustive search, type-filtered, Record Types, keyword contains-match. Required for Record Types. |
| 3rd | `search_objects_by_name` | Precise prefix match when naming pattern is known. |

**Search strategy:**

1. Extract 2-3 natural language descriptions from the spec (e.g., "vendor analysis display tab", "evaluation scoring pipeline", "proposal document extraction").

2. **Semantic discovery (primary):** For each description, search scoped to the application:
```
Tool: mcp_jarvis_search_objects_semantic
Input: searchTerm={natural language description}, appPrefix={from get_jarvis_config}, batchSize=15
```
This returns ranked results across Expression Rules, Interfaces, Process Models, Integrations, Constants — but NOT Record Types.

3. **Record Type discovery (semantic search can't find these):**
```
Tool: mcp_jarvis_list_application_objects
Input:
  - appUuid: {from Step 4}
  - searchTerm: {keyword}
  - objectType: "Record Type"
```

4. **Fill gaps:** If semantic results are thin for a specific area (e.g., no Process Models found), supplement with:
```
Tool: mcp_jarvis_list_application_objects
Input:
  - appUuid: {from Step 4}
  - searchTerm: {keyword}
  - objectType: "Process Model" | "Integration"
```

5. From the combined results, identify:
   - **Objects to MODIFY** — existing objects that need changes (e.g., add a new tab to an existing summary page)
   - **Objects to CREATE** — new objects needed (inferred from spec requirements not covered by existing objects)
   - **Reference objects** — existing patterns to follow (e.g., how other tabs are structured)

**Budget:** 5-10 API calls (down from 8-15 — semantic search replaces multiple keyword × type searches)

**Output:** A table of relevant existing objects with name, type, and relevance to the feature.

---

### Step 6: Generate Feature Breakdown

This is the core step. Using the spec content (Step 2), mockup states (Step 3), and codebase research (Step 5), generate the breakdown.

**Epic Grouping Strategy — Group by Functional Area:**

Identify distinct functional areas from the spec. Common patterns:
- Data model / backend foundation (new tables, Record Types, CDTs)
- Backend pipeline / orchestration (process models, integrations, business logic)
- Configuration / field changes (field type updates, character limits, settings)
- Primary UI screen (the main new interface or tab)
- Secondary UI screen (supporting views, forms, panels)
- Trigger / entry point (how the feature is initiated — buttons, modals, actions)
- Security / access control (role-based visibility, record-level security)

**Rules for each epic:**
- Name should be descriptive and business-oriented (not technical layer names)
- Should contain 1-5 tickets
- If an epic has more than 5 tickets, split it into sub-areas

**Ticket Generation Rules:**

For each ticket:

1. **Title:** Action-oriented, starts with a verb. Examples:
   - "Create vendor analysis data model"
   - "Add Vendor Analysis tab to Evaluation Summary"
   - "Build empty and error states for analysis tab"

2. **Description:** Should include:
   - What needs to be done (functional description)
   - Which existing objects are affected (from codebase research, use real object names)
   - Key implementation details from the spec
   - Mockup slide references if applicable (e.g., "Ref: Mockup slide 6")

3. **Acceptance Criteria:** Use Given/When/Then format:
   - Cover the happy path
   - Cover at least one edge case or error case
   - For UI tickets: reference specific states from mockups
   - For backend tickets: include data validation expectations
   - For configuration tickets: use checklist format if Given/When/Then doesn't fit

4. **Sizing target:** Each ticket should be 1-3 days of work. If a ticket feels larger:
   - Split UI tickets by state (happy path vs. error states)
   - Split backend tickets by data flow step
   - Split integration tickets by endpoint

**What to EXCLUDE from the breakdown:**
- Features explicitly listed in "Use Cases Not Supported"
- Research tabs, sample prompts, brainstorming notes
- Features referenced as "future" or "coming soon" in the spec
- Separate features mentioned in passing (e.g., "AI Docu Chat" referenced but not part of this spec)

**What to INCLUDE in the breakdown:**
- All use cases listed in "Guiding Use Cases"
- All user flows described in the spec
- Data model changes needed
- Security and access control requirements
- Empty states, error states, and edge cases from mockups

---

### Step 7: Create Google Sheet and Populate

**Step 7a: Create the spreadsheet**

```
Tool: mcp_google_workspace_create_spreadsheet
Input:
  - title: "Feature Breakdown — {FEATURE_NAME}"
  - sheet_names: ["Breakdown", "Codebase Research", "Summary"]
  - user_google_email: {user's Google email}
```

Save the returned `spreadsheet_id` for subsequent writes.

**Step 7b: Write the "Breakdown" sheet (main feature breakdown)**

```
Tool: mcp_google_workspace_modify_sheet_values
Input:
  - spreadsheet_id: {from Step 7a}
  - range_name: "Breakdown!A1"
  - values: [
      ["Epic", "Ticket Title", "Description", "Acceptance Criteria", "Effort Estimate", "Mockup Ref", "Story Points"],
      ["{epic_name}", "{ticket_title}", "{description}", "{acceptance_criteria}", "{effort}", "{slide_ref}", ""],
      ...
    ]
```

**Column definitions for "Breakdown" sheet:**

| Column | Header | Content |
|--------|--------|---------|
| A | Epic | Epic name (functional area) |
| B | Ticket Title | Action-oriented title |
| C | Description | What to do, existing objects affected, implementation details |
| D | Acceptance Criteria | Given/When/Then format, one criterion per line (use newlines within cell) |
| E | Effort Estimate | Small / Medium / Large |
| F | Mockup Ref | Slide numbers if applicable (e.g., "Slides 6-7") |
| G | Story Points | Left blank — team fills in during grooming |

**Row conventions:**
- Row 1: Headers
- Epic separator rows: Column A has the epic name, Columns B-G are empty. This visually groups tickets under their epic.
- Ticket rows: All columns populated except G (Story Points)

**Step 7c: Write the "Codebase Research" sheet**

```
Tool: mcp_google_workspace_modify_sheet_values
Input:
  - spreadsheet_id: {from Step 7a}
  - range_name: "Codebase Research!A1"
  - values: [
      ["Object Name", "Type", "Relevance"],
      ["{object_name}", "{type}", "{why_relevant}"],
      ...
    ]
```

**Step 7d: Write the "Summary" sheet**

```
Tool: mcp_google_workspace_modify_sheet_values
Input:
  - spreadsheet_id: {from Step 7a}
  - range_name: "Summary!A1"
  - values: [
      ["Feature Breakdown — {FEATURE_NAME}"],
      [""],
      ["Application", "{APP_NAME}"],
      ["Target Release", "{TARGET_RELEASE}"],
      ["Spec Doc", "{SPEC_DOC_URL}"],
      ["Mockup Deck", "{SLIDES_URL}"],
      ["Generated By", "JARVIS"],
      [""],
      ["Summary"],
      ["{2-3 sentence summary from spec}"],
      [""],
      ["Epic", "Ticket Count", "Effort Estimate"],
      ["{epic_1}", "{count}", "{effort}"],
      ...
      ["Total", "{total_tickets}", ""],
      [""],
      ["Recommended Implementation Order"],
      ["1. {Epic} — {reason}"],
      ...
      [""],
      ["Notes for Grooming"],
      ["{note_1}"],
      ["{note_2}"],
      ...
    ]
```

**Step 7e: Move spreadsheet to design doc folder**

The `create_spreadsheet` tool creates the sheet in the user's root Drive. To move it to the correct folder, use `search_drive_files` to confirm it was created, then note the link for the user. (Google Sheets API does not support folder placement on creation — the user can move it manually, or the agent can note the link.)

⚠️ **IMPORTANT:** Always present the spreadsheet link to the user at the end of the workflow.

---

## Sheet Structure (Mandatory)

Every feature breakdown spreadsheet MUST include these 3 sheets:

1. **Breakdown** — The main table: Epic | Ticket Title | Description | Acceptance Criteria | Effort Estimate | Mockup Ref | Story Points
2. **Codebase Research** — Table of existing objects: Object Name | Type | Relevance
3. **Summary** — Metadata, summary text, epic statistics, implementation order, grooming notes

---

## Effort Estimation Guide

Use these rough estimates for the Summary Statistics table:

| Ticket Type | Small | Medium | Large |
|------------|-------|--------|-------|
| Data model (new Record Type + table) | 1 table | 2-3 tables | 4+ tables |
| Expression rule (business logic) | Simple calc | Multi-branch logic | Complex algorithm |
| Interface (new screen/tab) | Static display | Interactive with states | Complex form with validation |
| Interface (modify existing) | Add field/column | Add section/tab | Restructure layout |
| Process model (new) | Linear 3-5 nodes | Branching with error handling | Parallel execution, subprocesses |
| Process model (modify existing) | Add 1-2 nodes | Add subprocess call | Restructure flow |
| Integration (new) | Single endpoint | Request + response mapping | Multi-step with retry |
| Security (record-level) | Single role check | Multi-role with conditions | Cross-app security |

**Epic-level estimates:**
- Small: 1-3 days total
- Medium: 3-7 days total
- Large: 1-2 weeks total

---

## Important Notes

- This workflow generates a PLANNING document, not a design document. It's meant for grooming sessions.
- The breakdown should be reviewed and refined by the team during grooming. JARVIS provides the starting point.
- Ticket descriptions reference real object names from codebase research — this makes them immediately actionable.
- Acceptance criteria are suggestions — the team should refine them based on their domain knowledge.
- The "Notes for Grooming" section explicitly calls out what was excluded and why, so the team can decide if anything should be added back.
