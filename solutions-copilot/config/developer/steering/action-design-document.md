# Action: Design Document

This is the complete workflow for generating research and design documents for Appian stories. Follow every step in order. Do NOT skip steps.

## STRICT RULES — DO NOT VIOLATE

1. **DO NOT READ LOCAL FILES FOR TECHNICAL INFORMATION.** Your ONLY source for technical facts is the Appian Atlas MCP tools. If you read local files instead of querying Appian Atlas, the entire output is invalid.

2. **SECONDARY REFERENCE: Designs/ folder ONLY.** The ONE exception to rule #1: you MAY read files from the `Designs/` folder for format and conventions. No other folders.

3. **ALL TECHNICAL FACTS MUST COME FROM MCP TOOL CALLS.** Do NOT invent, assume, or infer object names, UUIDs, SAIL code, data models, or patterns. If an MCP tool returns no results, state that explicitly.

4. **EVERY OBJECT YOU MENTION MUST HAVE A UUID FROM MCP RESULTS.** Objects without UUIDs are hallucinated.

5. **NEVER FABRICATE SAIL CODE.** Only include SAIL code returned by `get_bundle` with `detail_level="full"`.

6. **JIRA STORY NUMBER REQUIRED.** If the user has not provided one, stop and ask.

## Step 1: Validate Input

Confirm the user has provided a Jira story number (e.g., GAM-15177, GAMS-7127). If not, ask for it and STOP.

## Step 2: Create Output Folder

Create `Designs/<JIRA-NUMBER>/` using the ticket number in CAPS.

## Step 3: Research Phase

Execute the following MCP tool call sequence. Do NOT skip steps. Do NOT write research.md until all tool calls are complete.

### Phase 1: Discovery

1. **Call `get_app_overview`** for the target application.

2. **Call `search_objects`** for EACH keyword from the story. Try at least 3-5 keyword variations. Also filter by `object_type` when the story implies it.

3. **Call `search_bundles`** for the same keywords.

### Phase 2: Deep Dive

4. **For each relevant object**, call `get_dependencies` to trace inbound/outbound.

5. **For 2-3 critical bundles**, call `get_bundle` with `detail_level="full"` to get SAIL code.

6. **For supporting bundles**, call `get_bundle` with `detail_level="summary"`.

### Phase 3: Gap Analysis

7. If the story mentions objects not found via MCP, note them as "NOT FOUND in Appian Atlas" — do NOT invent them.

8. Search for related patterns (e.g., if story says "add a tab", search for existing tab implementations).

### Write research.md

Write `Designs/<JIRA-NUMBER>/research.md` with these sections:

**Story Summary** — Brief restatement of the ticket.

**MCP Query Log** — Every MCP call and its result count:
```
- search_objects("SourceSelection", "evaluation summary") → 5 results
- search_objects("SourceSelection", "vendor analysis") → 0 results
- get_bundle("SourceSelection", "AS_GSS_...", "full") → retrieved with SAIL code
```

**Relevant Objects (from MCP)** — Table:
| Object Name | Type | UUID | Source (MCP tool call) | Role/Purpose |

EVERY row must have a real UUID. No exceptions.

**Bundle Analysis** — Impacted bundles with IDs.

**Dependency Map** — Key chains from `get_dependencies`.

**SAIL Code Snippets** — Only code from `get_bundle` with `detail_level="full"`. Cite bundle ID and object name.

**Data Layer** — CDTs, record types found via MCP.

**Existing Patterns** — Similar implementations found via MCP.

**Not Found / Gaps** — What the story requires but was NOT found.

**Key Findings** — Observations, risks, recommendations.

## Step 4: Validate Research

After writing research.md, verify:
- Does it have an "MCP Query Log" section?
- Do objects have UUIDs?
- Is there a "Not Found / Gaps" section?

If research lacks MCP-sourced data, re-run searches with different keywords before proceeding.

## Step 5: Design Phase

Read research.md, then write `Designs/<JIRA-NUMBER>/design.md` using ONLY objects confirmed in the research (with UUIDs). Clearly mark new objects.

### Design Document Template

```markdown
# <TICKET-ID>: <Title>

**Jira:** [<TICKET-ID>](<jira-link>)
**Designer:** <name>
**Date:** <date>

## Problem

<What's broken or missing. Why this work matters. Reference the Jira story requirements.>

## Solution

<High-level approach. What we're building and the key design decisions made.
Mention the application area affected and the general strategy (new bundle, extend existing, etc.).>

## Implementation Details

### Objects Created (New)

| Object | Type | Purpose |
|---|---|---|
| AS_GSS_FM_objectName (New) | Interface | Description of what it does |
| AS_GSS_ER_objectName (New) | Expression Rule | Description of what it does |

<For each new object, add implementation notes below the table:>

**AS_GSS_FM_objectName (New)**
<What this object does, key rule inputs, behavior, validations.>

**AS_GSS_ER_objectName (New)**
<Logic description, parameters, return type.>

### Objects Modified

| Object | Type | UUID | Change |
|---|---|---|---|
| AS_GSS_FM_existingObject | Interface | abc-123-... | Add new tab for vendor details |
| AS_GSS_PM_existingProcess | Process Model | def-456-... | Add approval node after creation |

<For each modified object, describe the specific changes:>

**AS_GSS_FM_existingObject** (`abc-123-...`)
<What to change, where in the code, reference SAIL line numbers from research if available.>

**AS_GSS_PM_existingProcess** (`def-456-...`)
<Specific modifications needed.>

### Data Flow

<Step-by-step flow of how data moves through the system:>
1. User opens <interface> → fills in <fields>
2. On submit, calls <expression rule> with <parameters>
3. <Expression rule> validates and saves to <CDT>
4. <Process model> triggers <next step>

### Data Model Changes

| CDT | Field | Type | Change |
|---|---|---|---|
| AS_GSS_CDT_Vendor | status | Text | New field |
| AS_GSS_CDT_Vendor | approvedBy | User | New field |

### Dependencies

<Key dependency relationships that matter for this change.
Which shared utilities are affected, what calls what.>

## Test Cases

- Verify if <test case 1>
- Verify if <test case 2>
- Verify if <test case 3>
- Verify if existing validations are retained after changes
- Verify if accessibility requirements are met

## Risks & Notes

- <Any edge cases, deployment order concerns, SDX config changes>
- <Performance considerations>
- <Backward compatibility notes>
- SDX configuration needs to be updated based on UI changes. Ensure validations and conditions are retained and verified.
```

### Template Rules

- **New objects**: Always marked with `(New)` in the table. No UUID (they don't exist yet).
- **Modified objects**: MUST have UUID from research. If no UUID, it doesn't go in the design.
- **Data Flow**: Always include — shows how the pieces connect.
- **Test Cases**: Each starts with "Verify if".
- **Risks & Notes**: Always include SDX note for UI changes.

## Step 6: Summary

Report to user:
- Folder created at `Designs/<JIRA-NUMBER>/`
- Both documents generated with paths
- Research quality: object count with UUIDs, gaps noted
- Key findings or concerns

## Anti-Hallucination Rules

- If `search_objects` returns 0 results, say "No objects found for '<keyword>'"
- If `get_dependencies` returns an error, say "Dependencies not available for '<object>'"
- NEVER write "the standard pattern is..." without citing a specific MCP result
- NEVER invent constant names, expression rule names, or interface names
- New objects: mark as "(New)" with no UUID
- Existing objects in design: ONLY those with UUIDs from research
