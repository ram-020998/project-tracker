---
inclusion: auto
---

# Spike Research Workflow

## 🛑 STOP! READ THIS FIRST 🛑

**BEFORE YOU DO ANYTHING:**

1. ✅ **READ THIS ENTIRE WORKFLOW FILE** — Don't skip ahead, don't assume you know the steps
2. ✅ **CHECK FOR EXISTING SPIKE FILE** — Look in `spike-documents/` for an in-progress spike. If one exists with incomplete steps, RESUME from where it left off.
3. ✅ **IF NEW SPIKE** — Create the spike markdown file FIRST, then proceed step by step
4. ✅ **VERIFY BLOCKING RULES** — Check that previous steps are complete before proceeding

**IF YOU SKIP ANY OF THESE, YOU ARE VIOLATING THE WORKFLOW.**

**Common Triggers That Activate This Workflow:**
- "Spike for GAMS-XXXX"
- "Research GAMS-XXXX"
- "Do a spike on [topic]"
- "Investigate [feature/change] for GAMS-XXXX"
- User selects option 7 from Solutions Intelligence menu

---

## Overview

Collaborative spike research workflow that investigates a JIRA ticket (or topic) by deep-diving into the existing codebase, analyzing affected objects, tracing dependencies, assessing security, and generating a structured findings document.

**Key Design Principle:** The spike is built incrementally in a local markdown file. Each step writes its findings as it completes. The user can see progress in real-time, ask questions, redirect research, and provide input at interactive checkpoints. If context fills up, a new agent can resume from the file.

**Output:** Local markdown file in `spike-documents/` → converted to Google Doc at the end.

## Trigger

User says: **"Spike for GAMS-XXXX"** or **"Do a spike on [topic]"** and optionally provides:
- A spec document link (Google Doc) — for broader feature context
- A feature breakdown sheet link (Google Sheet) — to understand which ticket is being spiked
- Specific questions to focus on (e.g., "Focus on security implications")

## CRITICAL RULES - MANDATORY COMPLIANCE

- ⚠️ Follow steps EXACTLY in order. NO DEVIATIONS.
- ⚠️ Every step WRITES its findings to the spike markdown file as it completes.
- ⚠️ The spike file is the source of truth — not agent memory.
- ⚠️ Call `solutions-intelligence.list_applications` to determine application context.
- ⚠️ Include SAIL code snippets as examples where relevant — devs find these useful.
- ⚠️ **INTERACTIVE CHECKPOINTS are MANDATORY** — do NOT skip past them.
- ⚠️ **ASK, DON'T ASSUME** — If you're unsure about anything at any step, ask the user. See the "When to Ask" rule below.

## WHEN TO ASK — MANDATORY

**At ANY point during the workflow, if you encounter one of these situations, STOP and ask the user before proceeding:**

| Situation | What to Ask |
|-----------|-------------|
| Scope is ambiguous — ticket mentions multiple features or areas | "This ticket touches X, Y, and Z. Which area should I focus the spike on?" |
| Keywords aren't finding relevant objects in the codebase | "My searches for '{keyword}' aren't returning much. Do you know the naming convention or specific objects I should look at?" |
| Platform research returned thin results | "I didn't find much in Drive for '{keyword}'. Are there specific docs, wikis, or resources you know about that I should check?" |
| Multiple viable approaches and unclear which to recommend | "I see two strong options here: {A} and {B}. Do you have a preference or constraints that would help me narrow the recommendation?" |
| The spike is revealing a much larger scope than expected | "This is turning out to be bigger than the ticket suggests — it touches N objects across X areas. Should I continue with the full scope or narrow down?" |
| You need domain context the codebase can't tell you | "I can see the data model but I'm not sure about the business rule for {X}. Can you clarify how {thing} is supposed to work?" |
| Security or permissions model is unclear | "I see security groups on these objects but I'm not sure which groups the target users belong to. Can you clarify?" |
| You're about to make a judgment call that affects the recommendation | "Should I optimize this recommendation for throughput or for simplicity? The approaches differ significantly." |

**The rule is simple: if you're about to guess, ask instead.** The user is right there — use them. A 30-second question saves a wrong recommendation that wastes the whole spike.

## WORKFLOW ISOLATION - CRITICAL

⚠️ THIS WORKFLOW IS COMPLETELY INDEPENDENT
⚠️ DO NOT create Appian objects (that's implementation workflow)
⚠️ DO NOT create design documents (that's design workflow)
⚠️ DO NOT generate feature breakdowns (that's feature breakdown workflow)

**What This Workflow Does:**
1. Creates a spike markdown file and builds it incrementally
2. Reads JIRA ticket and optional context documents
3. Deep-dives into the codebase — finds objects, reads source code, traces dependencies
4. Pauses at interactive checkpoints for user input
5. Analyzes data model, security, and impact
6. Identifies decision points and presents options ADR-style
7. Exports the finished markdown to Google Doc

**What This Workflow Does NOT Do:**
- ❌ Create JIRA tickets
- ❌ Create Appian objects
- ❌ Make architectural decisions (presents options, team decides)
- ❌ Generate ticket split-ups (only when explicitly asked)

---

## Spike File Convention

**Folder:** `spike-documents/` (create if it doesn't exist)

**File naming:**
- Ticket-based: `GAMS-7126-spike.md`
- Topic-based: `vendor-analysis-scalability-spike.md` (kebab-case from topic)

**The spike file has a status tracker at the top** that persists across agent sessions. Any agent picking up the file knows exactly where things stand.

---

## Spike File Template

When creating a new spike file, write this template first:

```markdown
# Spike — {TICKET_KEY}: {TICKET_TITLE}
<!-- Or for topic-based: # Spike — {Topic Name} -->

**Generated by:** Solutions Intelligence
**Application:** {to be determined}
**Date:** {current date}
**JIRA:** [{TICKET_KEY}]({JIRA_URL}) <!-- omit if topic-based -->
**Spec:** [{doc title}]({SPEC_URL}) <!-- omit if none -->
**Breakdown:** [{sheet title}]({BREAKDOWN_URL}) <!-- omit if none -->

---

## Execution Tracker

| Step | Status | Notes |
|------|--------|-------|
| 1. Collect Inputs | ❌ Not Started | |
| 2. Read JIRA Ticket | ❌ Not Started | |
| 3. Read Context Documents | ❌ Not Started | Skip if none provided |
| 4. Determine Application | ❌ Not Started | |
| 4.5. Platform Research | ❌ Not Started | |
| 🔵 CHECKPOINT: Platform Review | ❌ Not Started | User confirms or adds research |
| 5. Deep Codebase Research | ❌ Not Started | |
| 🔵 CHECKPOINT: Codebase Review | ❌ Not Started | User confirms or adds research |
| 6. Dependency & Impact Analysis | ❌ Not Started | |
| 7. Security Analysis | ❌ Not Started | |
| 8. Synthesize Findings | ❌ Not Started | |
| 9. Export to Google Doc | ❌ Not Started | |

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
- 🔵 Waiting for User

---

## Context Transfer Protocol

If context is running low or a new agent picks up this spike:

1. **Read the spike file** in `spike-documents/` — it contains all findings so far
2. **Check the Execution Tracker** — identify which step to resume from
3. **Call `solutions-intelligence.list_applications`** — for application context
4. **Continue from the next incomplete step** — do NOT re-do completed steps
5. **Tell the user** you're resuming: "I'm picking up the spike from Step X. Here's what's been completed so far: [brief summary from tracker]"

The spike file IS the context. Everything the previous agent found is written there.

---

## Workflow Steps

### Step 1: Collect Inputs

Extract from the user's message:
- **JIRA ticket key** — e.g., GAMS-7126 (REQUIRED unless topic-based)
- **Topic** — if no ticket, extract the research topic
- **Spec document link** — Google Doc ID (optional, for broader feature context)
- **Feature breakdown sheet link** — Google Sheet ID (optional, for ticket context)
- **Focus questions** — specific areas to investigate (optional)

If neither a JIRA ticket key nor a clear topic is provided, ask for one.

**If the user's request is broad or mentions multiple areas**, ask them to narrow the focus before proceeding. Example: "You mentioned vendor analysis, scoring, and document extraction. Should I spike all three, or focus on one?"

**Create the spike file now:**
```
Tool: fsWrite
Path: spike-documents/{TICKET_KEY}-spike.md  (or {topic-slug}-spike.md)
Content: [Use the Spike File Template above, filling in known fields]
```

Update tracker: Step 1 → ✅ Complete

---

### Step 2: Read JIRA Ticket (Skip if topic-based)

```
Tool: jira.get_jira_issue
Input: issue_key (e.g., "GAMS-7126")
Fields needed:
  - fields.summary → Ticket title
  - fields.description → Description (the spike scope)
  - fields.customfield_10227 → Acceptance criteria
  - fields.parent → Parent epic (for context)
  - fields.project.key → Project key (for app matching)
```

Extract from the ticket:
- **What is being investigated** — the core question or feature
- **Keywords** — technical terms, object names, feature areas mentioned
- **Constraints** — any specific boundaries or requirements mentioned

**Write to spike file — append Section 1: Context**

```markdown
## 1. Context

{What is being investigated and why. Summarize from JIRA ticket and context documents. 3-5 sentences.}

**Keywords identified:** {keyword1}, {keyword2}, {keyword3}
**Core question:** {The main thing this spike needs to answer}
```

Update tracker: Step 2 → ✅ Complete

---

### Step 3: Read Context Documents (Skip if none provided)

If the user provided a spec document:
```
Tool: mcp_google_workspace_get_doc_content
Input: document_id, user_google_email
```

If the user provided a feature breakdown sheet:
```
Tool: mcp_google_workspace_read_sheet_values
Input: spreadsheet_id, range_name="Breakdown!A1:G100", user_google_email
```

**Append relevant context to Section 1 in the spike file.** Don't create a separate section — enrich the existing Context section with what was learned from the documents.

Update tracker: Step 3 → ✅ Complete (or ⏭️ Skipped)

---

### Step 4: Determine Application Context

```
Process:
  - Call `solutions-intelligence.list_applications` to get the list of registered applications
  - Match JIRA project key against `jiraProjects`, or match object prefix against `appPrefix` and `appName`
  - Use the matched application's appUuid for lcp-api.listApplications calls
  - Use the matched application's appPrefix for lcp-api.searchObjects calls (e.g., "AS_GSS", "AS_VM")
  - If no match found, ask the user
```

Update the spike file header with the application name.

Update tracker: Step 4 → ✅ Complete

---

### Step 4.5: Platform Research (Google Drive + Google Chat)

Search the team's knowledge base for platform-level context that can't be found in the codebase: limitations, gotchas, previous spike findings, architecture decisions, and platform capabilities.

**Skip this step if:** `searchDrive` is `false` in `globalSettings` from `solutions-intelligence.list_applications`.

**⚠️ BUDGET CONSTRAINT: This entire step must complete in 7 API calls max. Do NOT read more than 3 documents. Do NOT spend excessive context on this — it's supplementary research, not the main investigation.**

**Phase 4.5a: Google Drive Research**

**Keyword Strategy — Two Layers:**

**Layer 1: Direct keywords** — Extract 1-2 focused keywords from the JIRA ticket that relate to platform capabilities (e.g., "AI Skill document extraction", "portal authentication", "record event audit").

**Layer 2: Architectural pattern keywords** — Based on the spike's core concern, derive broader architectural keywords that may surface reference solutions the team has documented. Use this mapping:

| Spike Concern | Additional Search Keywords |
|--------------|---------------------------|
| Scale / high volume / throughput | "transaction manager", "queue", "batch processing" |
| Parallel execution / MNI / fan-out | "transaction manager", "parallel", "microbatch" |
| Rate limiting / throttling | "rate limit", "throttle", "transaction manager" |
| Async processing / long-running | "async", "queue", "transaction manager" |
| Retry / error recovery | "retry", "dead letter", "exponential backoff" |
| Scheduling / recurring jobs | "scheduler", "transaction manager", "recurring" |
| Integration / external API | "connected system", "integration pattern" |
| Data migration / bulk load | "migration", "batch", "transaction manager" |

**⚠️ Always search for "transaction manager" when the spike involves any form of batch processing, parallel execution, queue management, or throughput concerns.** It's a platform-level solution that won't surface from feature-specific keywords alone.

Run 1-2 searches (Layer 1 keyword + Layer 2 keyword if applicable):
```
Tool: mcp_google_workspace_search_drive_files
Input:
  - user_google_email: {user's Google email}
  - query: "{keyword}"
  - page_size: 5
```

No folder scoping needed — Google Drive search handles relevance across all accessible files.

Read the top docs (up to `maxDocsToRead` from config, default 3). **Skim for relevant sections only — do NOT read entire documents end-to-end.** Extract:
- Platform limitations and constraints
- Known gotchas from previous implementations
- Architecture decisions and recommended patterns

```
Tool: mcp_google_workspace_get_drive_file_content
Input: file_id, user_google_email
```

**Budget:** 2-4 API calls (1 search + 1-3 doc reads)

**Phase 4.5b: Google Chat Research (Opt-in Only)**

**Only search Chat when ONE of these conditions is true:**
- User explicitly asks ("check if anyone discussed this in chat")
- `searchChat` is set to `true` in `globalSettings` from `solutions-intelligence.list_applications`
- Drive search returned nothing useful AND the topic is very specific or involves a recent platform feature

Search globally across all Chat spaces the user has access to — no need to specify a space_id:
```
Tool: mcp_google_workspace_search_messages
Input:
  - user_google_email: {user's Google email}
  - query: "{keyword}"
  - page_size: 5
```

**Do NOT read full threads.** Extract key points from the returned messages only. If a message references a document or link, note it but don't chase it.

**⚠️ IMPORTANT:** Chat findings are informal and unverified. Always flag them as such in the output. Include the message link so the user can check the full thread context.

**Budget:** 1-2 API calls (1 search, maybe 1 more with refined keyword)

**Phase 4.5c: Write Platform Context to Spike File**

Append to the spike file:

```markdown
## 1.5 Platform Context & Reference

| Source | Key Finding | Confidence |
|--------|-------------|------------|
| [{Document Name}]({link}) | {Platform limitation, gotcha, or relevant context} | High (formal doc) |
| [{Chat Space}]({message_link}) | {Informal finding — needs verification} | ⚠️ Low (chat) |

*Chat-sourced findings are informal and may be outdated. Verify before relying on them.*
```

If no relevant platform context was found, write: "No relevant platform documentation found. Proceeding with codebase research only."

**If results are thin (0-1 useful docs found) and the spike involves a non-trivial architectural concern**, mention this to the user at the checkpoint: "I didn't find much platform documentation for this topic. Do you know of any internal docs, reference architectures, or plugins that might be relevant?"

Update tracker: Step 4.5 → ✅ Complete

---

### 🔵 INTERACTIVE CHECKPOINT: Platform Research Review

**⚠️ THIS CHECKPOINT IS MANDATORY. DO NOT SKIP.**

After writing platform research findings to the spike file, STOP and ask the user:

> **Platform Research Complete.** Here's what I found:
> - {Brief summary of key findings}
> - {Documents read}
>
> **Before I move to codebase research, I want to make sure we haven't missed anything:**
> 1. Are there any specific documents or resources you know about that I should check?
> 2. Any platform features, plugins, or patterns you want me to search for?
> 3. Should I search Google Chat for informal discussions on this topic?
> 4. Ready to proceed to codebase research, or want me to dig deeper on anything?

**Wait for the user to respond.** Do NOT proceed to Step 5 until the user says to continue (e.g., "continue", "looks good", "proceed", "move on").

If the user provides additional research directions:
- Execute the additional research
- Append findings to Section 1.5 in the spike file
- Ask again if they want to continue or research more

**This loop continues until the user explicitly says to move on.**

Update tracker: 🔵 CHECKPOINT: Platform Review → ✅ Complete

---

### Step 5: Deep Codebase Research

This is the core research step. Go deep — read actual source code, not just object names.

**Search Tool Hierarchy:**

| Priority | Tool | Best For |
|----------|------|----------|
| 1st | `lcp-api.searchObjects` | Primary discovery — natural language, cross-app, ranked by relevance. Does NOT return Record Types. Use `appPrefix` from `solutions-intelligence.list_applications`. |
| 2nd | `lcp-api.listApplications` | Exhaustive search, type-filtered, Record Types, keyword contains-match. Required for Record Types. |
| 3rd | `lcp-api.searchObjects` | Precise prefix match when naming pattern is known. |

**Phase 5a: Discovery — Find all relevant objects**

Extract 2-3 natural language descriptions from the JIRA ticket and context documents (e.g., "evaluation task due date validation", "vendor proposal submission flow").

**Step 1 — Semantic discovery (primary):**
For each description, run semantic search scoped to the application:
```
Tool: mcp_solutions-intelligence.lcp-api.searchObjects
Input: searchTerm={natural language description}, appPrefix={from solutions-intelligence.list_applications}, batchSize=15
```
This returns ranked results across Expression Rules, Interfaces, Process Models, Integrations, Constants — but NOT Record Types.

**Step 2 — Record Type discovery (semantic search can't find these):**
```
Tool: lcp-api.listApplications
Input: appUuid, searchTerm={keyword}, objectType="Record Type"
```

**Step 3 — Fill gaps:** If semantic results are thin for a specific area, supplement with `lcp-api.listApplications` using keyword + type filter.

**Budget:** 5-10 API calls for discovery (down from 10-20 — semantic search replaces multiple keyword × type searches)

**If keyword searches aren't returning relevant objects**, don't just try more keywords blindly. Ask the user: "My searches for '{keyword}' aren't finding the objects I'd expect. Do you know the naming convention or specific object names I should look for?"

**Phase 5b: Comprehension — Read source code of key objects**

For the most relevant objects found in 5a (typically 5-15 objects):

```
Tool: lcp-api.getInterface
Input: object_uuid, object_name, object_type
```

For complex objects that need deeper explanation:
```
Tool: explain_appian_code
Input: object_uuid, object_name
```

**What to extract from source code:**
- For Interfaces: rule inputs, key local variables, UI structure, conditional logic, what data it displays/collects
- For Expression Rules: parameters, return type, core logic, what it queries or calculates
- For Process Models: nodes, flow structure, subprocesses called, write operations
- For Record Types: fields, relationships, views, actions, security rules
- For Integrations: endpoint, method, request/response structure

**Include SAIL code snippets** where they illustrate important patterns or logic that the dev needs to understand. Keep snippets focused — extract the relevant section, not the entire object.

**Budget:** 10-25 API calls for comprehension

**Phase 5c: Pattern Research — Find similar implementations**

Search for objects that implement similar patterns to what the spike is investigating:
```
Tool: lcp-api.listApplications
Input: appUuid, searchTerm={pattern_keyword}, objectType={type}
```

If a similar pattern is found, fetch its source code as a reference example.

**Budget:** 3-8 API calls for pattern research

**Phase 5d: Write Codebase Findings to Spike File**

Append the following sections to the spike file as they are completed:

```markdown
## 2. Scope

**Investigated:**
- {Area 1 that was researched}
- {Area 2 that was researched}

**Out of scope:**
- {Area explicitly not investigated and why}

## 3. Affected Objects

| Object Name | Type | Current Purpose | Required Change | Risk |
|-------------|------|-----------------|-----------------|------|
| {name} | {type} | {purpose} | {change needed} | {Low/Medium/High (N dependents)} |

## 4. Data Model Analysis

### Existing Data Model

{Description of relevant existing Record Types, their fields, and relationships.}

| Record Type | Key Fields | Relationships |
|-------------|-----------|---------------|
| {name} | {fields} | {relationships} |

### Proposed Changes
- **New table:** {Table name — columns and types}
- **Modified table:** {Table name — new columns}
```

Update tracker: Step 5 → ✅ Complete

---

### 🔵 INTERACTIVE CHECKPOINT: Codebase Research Review

**⚠️ THIS CHECKPOINT IS MANDATORY. DO NOT SKIP.**

After writing codebase research findings to the spike file, STOP and ask the user:

> **Codebase Research Complete.** Here's what I found:
> - {Number of affected objects} objects identified
> - {Key objects listed}
> - {Data model summary}
> - {Any surprising findings or concerns}
>
> **Before I move to dependency analysis and synthesis, I want to make sure the research is thorough:**
> 1. Are there any objects or areas I missed that you know are relevant?
> 2. Any specific objects you want me to read in more detail?
> 3. Any patterns or existing implementations I should look at for reference?
> 4. Ready to proceed to dependency & impact analysis, or want me to dig deeper?

**Wait for the user to respond.** Do NOT proceed to Step 6 until the user says to continue.

If the user provides additional research directions:
- Execute the additional research
- Update the relevant sections in the spike file (append to affected objects, data model, etc.)
- Ask again if they want to continue or research more

**This loop continues until the user explicitly says to move on.**

Update tracker: 🔵 CHECKPOINT: Codebase Review → ✅ Complete

---

### Step 6: Dependency & Impact Analysis

For each object identified as needing modification in Step 5:

```
Tool: solutions-intelligence.get_dependencies
Input: object_uuid, dependency_type="DEPENDENTS", object_name
```

**Build the impact picture:**

1. **Level 1 (direct dependents):** Always trace
2. **Level 2 (indirect dependents):** Trace for high-risk objects (those with 10+ Level 1 dependents)
3. Classify risk per object:
   - Low Risk: 0-5 dependents
   - Medium Risk: 6-15 dependents
   - High Risk: 16+ dependents

**Also trace precedents for key objects:**
```
Tool: solutions-intelligence.get_dependencies
Input: object_uuid, dependency_type="PRECEDENTS", object_name
```

This reveals what the object depends on — useful for understanding data flow and identifying shared utilities.

**Budget:** 5-15 API calls for impact analysis

**Write to spike file:**

```markdown
## 5. Dependency Impact

{Summary of blast radius across all affected objects.}

\`\`\`
{Object Name} (TARGET — modifying this)
├── {Dependent 1} ({Type}) — N dependents ✅ Low
├── {Dependent 2} ({Type}) — N dependents ⚠️ Medium
└── {Dependent 3} ({Type}) — N dependents 🔴 High
    ├── ...
    └── ...

Total blast radius: X target + Y Level 1 + Z Level 2 = N objects
Risk: ⚠️ MEDIUM
\`\`\`
```

Update tracker: Step 6 → ✅ Complete

---

### Step 7: Security Analysis

For objects where security is relevant (Record Types, Process Models, folders):

```
Tool: lcp-api.getInterface
Input: object_uuid (if not already fetched in Step 5)
```

Extract security-related sections:
- **Record Types:** Record-level security rules, default security groups, source filter expressions
- **Process Models:** Security groups (initiators, viewers, managers)
- **Folders:** Folder-level security (inherited by contents)
- **Integrations:** Authentication method, service account usage

If security is not relevant to the spike (e.g., pure UI change), note "Security: No security implications identified" and move on.

**Budget:** 0-5 API calls (often already fetched in Step 5)

**Write to spike file:**

```markdown
## 6. Security Analysis

{Current security configuration on relevant objects. If no security implications, state that.}

- **{Record Type}:** {Security groups, record-level security rules}
- **{Process Model}:** {Initiator/viewer/manager groups}

**Security changes needed:** {What needs to change, or "None"}
```

Update tracker: Step 7 → ✅ Complete

---

### Step 8: Synthesize Findings

Compile all research into the findings and recommendations. This is where the agent reasons about everything gathered so far.

**For each affected object, determine:**
- What it currently does (from source code analysis)
- What needs to change (from ticket requirements)
- How complex the change is (from code structure and dependency count)

**Identify decision points:**
If the research reveals multiple viable approaches to solving a problem, structure them ADR-style:
- Option 1: Description, Pros, Cons, Estimated Effort
- Option 2: Description, Pros, Cons, Estimated Effort
- Decision: [Left blank — team decides]

Common decision point triggers:
- "We could modify the existing object OR create a new one"
- "We could add a field to this Record Type OR create a new related Record Type"
- "We could handle this in the Process Model OR in an Expression Rule"
- "Single API call with large payload OR multiple batched calls"

**⚠️ MANDATORY: Detailed Implementation Examples for Recommended Approach**

Every spike MUST include a detailed implementation example for the recommended approach. This is NOT optional — developers need to see HOW the recommendation would actually be built, not just a high-level description.

For the recommended approach (and optionally for other strong options), provide ALL of the following:

**8a. SAIL Pseudocode**
Write expression rules and interface snippets showing the core logic. Use real record type names, field names, and object naming conventions discovered during codebase research (Step 5).
- Show the key expression rule(s) that implement the core logic
- Use actual CDT field names and record type references from the codebase
- Follow the application's naming convention (e.g., `AS_GSS_AI_BL_` prefix for business logic)
- Include comments explaining each section
- Show how data flows between rules (what one rule returns, the next consumes)

**8b. Process Model Flow Diagram**
Draw an ASCII art process model showing the full node-by-node flow:
- Start node → each activity/gateway → end node
- Label each node with its type (Script Task, Call Subprocess, XOR Gateway, MNI, etc.)
- Show inputs/outputs on key transitions
- Mark which nodes are new vs. modifications to existing objects
- Show loop-back paths for iterative patterns

Example format:
```
[Start] → [Script: Build Job List] → [Script: Chunk Into Batches] → [XOR: More Batches?]
  ↑                                                                        ↓ Yes
  |                                                              [Script: Get Next Batch]
  |                                                                        ↓
  |                                                              [MNI Subprocess: Process Batch]
  |                                                                        ↓
  └──────────────────── [Script: Update Progress] ←────────────────────────┘
                              ↓ No more batches
                        [Script: Finalize Results] → [End]
```

**8c. Visual Timeline (for scale-sensitive recommendations)**
When the spike involves processing at scale (batch jobs, parallel execution, large data volumes), show a visual timeline demonstrating execution at the expected scale:
- Show batch/phase progression over time
- Include estimated durations per batch/phase
- Show parallelism where applicable
- Calculate total estimated duration
- Reference the scale numbers from the ticket (e.g., "50 evaluations × 10 vendors × 15 docs")

**8d. Error Handling Pattern**
Show how failures are isolated and tracked within the recommended approach:
- What happens when a single item in a batch fails?
- How is partial completion tracked?
- What status values are used (COMPLETED, PARTIALLY_COMPLETED, FAILED)?
- How can the user retry failed items?
- Include a SAIL snippet showing the try/catch or error-handling logic

**8e. Configurable Constants Table**
List all tuning parameters the implementation would need, with recommended defaults:

| Constant Name | Type | Default | Purpose |
|--------------|------|---------|---------|
| `AS_GSS_AI_INT_BATCH_SIZE` | Integer | 10 | Number of items per batch |
| `AS_GSS_AI_INT_MAX_PARALLEL` | Integer | 5 | Max concurrent evaluations |
| ... | ... | ... | ... |

Follow the application's constant naming convention discovered in Step 5.

**When to include each element:**
- SAIL pseudocode: ALWAYS (every recommendation)
- Process model flow: ALWAYS when a process model is involved
- Visual timeline: When the spike involves scale/performance concerns
- Error handling: When the recommendation involves async processing, batch jobs, or external integrations
- Configurable constants: When the recommendation has tunable parameters

**Write to spike file — append Sections 7, 8, and 9:**

```markdown
## 7. Findings & Recommendations

### Key Findings

1. **{Finding title}** — {Description. Include SAIL code snippet if illustrative.}
2. **{Finding title}** — {Description.}

### Recommended Approach

{High-level recommendation based on findings. Reference existing patterns found in the codebase.}

### Existing Patterns to Follow

{Reference similar implementations found during pattern research. Include code snippets.}

### Detailed Implementation Example

*The following pseudocode shows how the recommended approach would be built using the existing codebase patterns and naming conventions.*

#### 7a. Core Logic (SAIL Pseudocode)

\`\`\`sail
/* PSEUDOCODE — not deployable as-is */
/* AS_GSS_XX_BL_ruleNameHere */
/* Purpose: {what this rule does} */
a!localVariables(
  /* ... */
)
\`\`\`

#### 7b. Process Model Flow

\`\`\`
{ASCII art process model diagram}
\`\`\`

#### 7c. Execution Timeline at Scale
<!-- Include ONLY when spike involves scale/performance concerns -->

\`\`\`
{Visual timeline with batch progression and estimated durations}
\`\`\`

#### 7d. Error Handling

{How failures are isolated and tracked}

#### 7e. Configurable Constants

| Constant Name | Type | Default | Purpose |
|--------------|------|---------|---------|
| {name} | {type} | {default} | {purpose} |

## 8. Decision Points

<!-- Repeat for each decision point -->
### Decision: {Title}

**Problem:** {What needs to be decided}

| Option | Description | Pros | Cons | Effort |
|--------|-------------|------|------|--------|
| Option 1 | {desc} | {pros} | {cons} | {effort} |
| Option 2 | {desc} | {pros} | {cons} | {effort} |

**Decision:** *[To be decided by team]*

## 9. Open Questions

1. {Question that needs human input or stakeholder decision}
2. {Question about cross-team dependency}
3. {Question about performance or scalability}
```

**Identify open questions:**
Things the research couldn't determine:
- Stakeholder decisions needed
- Cross-team dependencies
- Performance concerns that need load testing
- Security approvals needed

**Ticket split-up (ONLY if user explicitly asked):**
If the user asked for a ticket split, break the work into implementable tickets:
- Each ticket: Title, Description, Effort estimate (points or T-shirt size)
- Order by dependency (what must be done first)

Update tracker: Step 8 → ✅ Complete

---

### Step 9: Export to Google Doc

**Step 9a: Convert markdown to HTML**

Read the completed spike markdown file and convert it to HTML using the HTML template structure (see HTML Template below).

```
Tool: fsWrite
Input: path="temp_spike_findings.html"
```

**Step 9b: Import to Google Docs**

```
Tool: mcp_google_workspace_import_to_google_doc
Input:
  - file_name: "Spike — {TICKET_KEY}: {TICKET_TITLE}"
  - file_path: "temp_spike_findings.html"
  - folder_id: {from `solutions-intelligence.list_applications` → matched app → spikeDocFolderId or designDocFolderId}
  - source_format: "html"
  - user_google_email: {user's Google email}
```

**Step 9c: Cleanup temp file**

Delete the temporary HTML file after successful import. Keep the markdown file in `spike-documents/` as a permanent local record.

**Step 9d: Update spike file with Google Doc link**

Append to the top of the spike file:
```markdown
**Google Doc:** [{doc title}]({google_doc_url})
**Exported:** {date}
```

Update tracker: Step 9 → ✅ Complete

---

## HTML Template Structure

When converting the spike markdown to HTML for Google Doc import, use this template:

```html
<html>
<head>
<style>
  body { font-family: Arial, sans-serif; font-size: 11pt; line-height: 1.5; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
  th, td { border: 1px solid #999; padding: 8px; vertical-align: top; text-align: left; }
  th { background-color: #c9daf8; font-weight: bold; }
  h1 { font-size: 18pt; }
  h2 { font-size: 14pt; margin-top: 24px; color: #1a73e8; }
  h3 { font-size: 12pt; margin-top: 16px; }
  .meta { color: #666; font-size: 10pt; }
  .risk-low { color: #137333; }
  .risk-medium { color: #b06000; }
  .risk-high { color: #c5221f; }
  pre { background-color: #f5f5f5; padding: 12px; border-radius: 4px;
        font-family: monospace; font-size: 10pt; overflow-x: auto; white-space: pre-wrap; }
  .decision-box { border: 2px solid #fbbc04; background-color: #fef7e0;
                   padding: 12px; margin: 12px 0; border-radius: 4px; }
  .question-box { border: 2px solid #ea4335; background-color: #fce8e6;
                   padding: 12px; margin: 12px 0; border-radius: 4px; }
  ul { margin: 4px 0; padding-left: 20px; }
  li { margin-bottom: 4px; }
</style>
</head>
<body>

<h1>Spike — <a href="{JIRA_URL}">{TICKET_KEY}: {TICKET_TITLE}</a></h1>
<p class="meta">Generated by Solutions Intelligence | Application: {APP_NAME}</p>
<p class="meta">Spec: <a href="{SPEC_URL}">Link</a> (if provided) |
   Breakdown: <a href="{BREAKDOWN_URL}">Link</a> (if provided)</p>

<!-- Convert each markdown section to HTML equivalent -->
<!-- Section 1: Context → <h2>1. Context</h2> -->
<!-- Section 1.5: Platform Context → <h2>1.5 Platform Context & Reference</h2> (only if present) -->
<!-- Section 2: Scope → <h2>2. Scope</h2> -->
<!-- Section 3: Affected Objects → <h2>3. Affected Objects</h2> with <table> -->
<!-- Section 4: Data Model → <h2>4. Data Model Analysis</h2> -->
<!-- Section 5: Dependency Impact → <h2>5. Dependency Impact</h2> with <pre> tree -->
<!-- Section 6: Security → <h2>6. Security Analysis</h2> -->
<!-- Section 7: Findings → <h2>7. Findings & Recommendations</h2> with subsections 7a-7e -->
<!-- Section 8: Decision Points → <h2>8. Decision Points</h2> with .decision-box divs -->
<!-- Section 9: Open Questions → <h2>9. Open Questions</h2> with .question-box div -->
<!-- Section 10: Ticket Split → <h2>10. Suggested Ticket Split</h2> (only if requested) -->

<!-- Strip the Execution Tracker from the HTML output — it's for workflow tracking only -->

</body>
</html>
```

**Conversion rules:**
- Markdown tables → HTML `<table>` with `<th>` headers
- Markdown code blocks → HTML `<pre>` blocks
- Markdown bold → HTML `<b>`
- Markdown links → HTML `<a href>`
- Risk levels: Low → `class="risk-low"`, Medium → `class="risk-medium"`, High → `class="risk-high"`
- Decision points → wrap in `<div class="decision-box">`
- Open questions → wrap in `<div class="question-box">`
- **Do NOT include the Execution Tracker in the HTML** — it's internal workflow state

---

## Document Sections (Mandatory)

Every spike findings document MUST include these sections:

1. **Context** — What and why (3-5 sentences from JIRA ticket)
1.5. **Platform Context & Reference** — (OPTIONAL) Platform docs and chat findings relevant to the spike. Include only if Step 4.5 found useful information. Flag chat-sourced findings as "unverified."
2. **Scope** — What was investigated, what was excluded
3. **Affected Objects** — Table: Object Name | Type | Current Purpose | Required Change | Risk
4. **Data Model Analysis** — Existing model + proposed changes
5. **Dependency Impact** — Blast radius tree, risk levels
6. **Security Analysis** — Current config, changes needed (or "None")
7. **Findings & Recommendations** — Key findings with code snippets, recommended approach, existing patterns, AND detailed implementation example (SAIL pseudocode, process flow diagram, execution timeline if scale-relevant, error handling, configurable constants). The implementation example is MANDATORY — it's what makes the spike actionable.
8. **Decision Points** — ADR-style options table (only if multiple approaches exist)
9. **Open Questions** — Things needing human input

Optional (only when explicitly requested):
10. **Suggested Ticket Split** — Implementable tickets with effort and dependencies

---

## Code Snippet Guidelines

There are TWO levels of code snippets in a spike document:

### Level 1: Illustrative Snippets (in Findings section)

Short snippets that help the developer understand the current codebase:

- **Current structure** — "Here's how the tabs are currently set up in the interface"
- **Relevant logic** — "Here's the conditional that controls visibility"
- **Pattern to follow** — "Here's how a similar feature was implemented in another object"
- **Data queries** — "Here's how the existing query fetches evaluation data"

**Rules for illustrative snippets:**
- Keep snippets focused — extract the relevant 5-20 lines, not the entire object
- Add comments to highlight the important parts
- Use `/* ... */` to indicate omitted code
- Always name the source object: `/* From AS_GSS_FM_evaluationSummary */`

### Level 2: Implementation Examples (in Recommended Approach section)

Full pseudocode showing HOW the recommended approach would be built. These are longer and more detailed:

- **Expression rules** — complete rule signature with inputs, local variables, and return value (20-60 lines)
- **Process model logic** — script task contents, subprocess inputs, gateway conditions
- **Interface patterns** — key UI components showing data binding and user interaction
- **Query patterns** — full `a!queryRecordType` calls with filters, pagination, and aggregation

**Rules for implementation examples:**
- Use real object names, record type names, and field names from the codebase research
- Follow the application's naming convention (prefixes, casing, etc.)
- Include all parameters and local variables — the dev should be able to use this as a starting template
- Add inline comments explaining WHY, not just WHAT
- Show data flow: what one rule returns, the next rule consumes
- Mark clearly as pseudocode: `/* PSEUDOCODE — not deployable as-is */`

---

## Research Depth Guide

| Spike Type | Discovery Depth | Code Reading Depth | Impact Depth |
|-----------|----------------|-------------------|-------------|
| UI change (new tab/section) | Find the target interface + its sub-interfaces | Read target + 2-3 sub-interfaces | Level 1 dependents only |
| Data model change | Find Record Types + related Expression Rules | Read Record Type config + key query rules | Level 1 + Level 2 for Record Types |
| Process flow change | Find Process Model + called subprocesses | Read PM + subprocess structure | Level 1 dependents |
| Integration/API change | Find Integration + Connected System + calling PMs | Read integration config + calling code | Level 1 dependents |
| Security change | Find target objects + folder structure | Read security config sections | Level 1 + security group membership |
| Cross-app integration | Find objects in BOTH applications | Read integration points in both apps | Level 1 in both apps |

**Total API budget per spike:** 25-60 calls (platform research 3-9 + discovery 5-10 + comprehension 10-25 + impact 5-15 + security 0-5 + database 0-5)

**Database Investigation (MANDATORY when spike involves database — detect from ticket):**

When any of these patterns are detected in the JIRA ticket or context documents, SQL investigation is required — not optional:

| Trigger (detected from ticket/context) | SQL to run | Why |
|----------------------------------------|------------|-----|
| Ticket mentions scalability, performance, or "slow" | `SELECT COUNT(*) FROM {TABLE} LIMIT 1` for affected tables | Row counts are essential for scalability assessment |
| Ticket mentions new queries, filters, or search | `SHOW INDEX FROM {TABLE}` for queried tables | Index gaps = performance risk |
| Ticket mentions new columns, fields, or data model changes | `DESCRIBE {TABLE}` for affected tables | Must know current structure before proposing changes |
| Ticket mentions data migration or data cleanup | `SELECT {column}, COUNT(*) FROM {TABLE} GROUP BY {column} ORDER BY COUNT(*) DESC LIMIT 20` | Data distribution informs migration strategy |
| Ticket mentions cross-table relationships | `SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.columns WHERE TABLE_SCHEMA = 'Appian' AND COLUMN_NAME LIKE '%{keyword}%' LIMIT 50` | Discover which tables reference a concept |
| Ticket mentions Record Type changes | `DESCRIBE {source_table}` + `SHOW INDEX FROM {source_table}` | Verify current state before proposing Record Type modifications |

Skip SQL ONLY when: The spike is purely about UI changes, process flow changes without data model impact, or security/access changes that don't involve database queries.

**Budget:** 3-8 SQL calls per spike. Include findings in Section 4 (Data Model Analysis) of the spike document.

---

## Important Notes

- This workflow generates a RESEARCH document, not a design document. It presents findings for the team to act on.
- The spike file in `spike-documents/` is the source of truth. Write findings as you go, not all at the end.
- Decision points are presented with options but the Decision field is left blank — the team decides.
- Ticket split-ups are ONLY generated when the user explicitly asks. Don't add them by default.
- **Illustrative code snippets** (in Findings) should be short — show the relevant 5-20 lines, not the full object.
- **Implementation examples** (in Recommended Approach) should be comprehensive — show full pseudocode with real names, process flows, timelines, error handling, and constants. These are the most valuable part of the spike for the implementing developer.
- If the spike reveals that the change is trivial (1-2 objects, low risk, no decisions needed), say so clearly. The implementation example can be shorter for trivial changes, but still include SAIL pseudocode at minimum.
- If the spike reveals the change is much larger than expected, flag this prominently in the Context section.
- **Interactive checkpoints are the most important part of this workflow.** They ensure the user is involved in the research process and can catch gaps early. Never skip them.
- The markdown file persists across agent sessions. If context fills up, the next agent reads the file and resumes. This is by design.
