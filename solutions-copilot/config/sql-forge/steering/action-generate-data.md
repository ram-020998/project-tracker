---
inclusion: auto
---

# Action: Generate Data

## 🛑 THIS IS THE MASTER WORKFLOW. READ EVERY WORD. 🛑

**When a user asks you to create, generate, or set up data in an Appian environment, THIS workflow activates.**

**Common triggers:**
- "Create an evaluation in Complete status"
- "Generate test data for..."
- "Set up a record with 3 vendors"
- "I need demo data for..."
- "Create 100 records as SQL"
- "Generate bulk SQL for performance testing"
- "Create a SQL script with evaluations"

---

## MODE DETECTION

Before starting, determine the output mode:

| Signal | Mode |
|--------|------|
| Quantity ≤ 50, or no quantity specified | **records** (API) |
| Quantity > 50, or "bulk", "SQL", "script", "performance" | **sql** (SQL file) |
| User explicitly says "in the environment" or "create records" | **records** |
| User explicitly says "SQL file" or "INSERT statements" | **sql** |

**If ambiguous, ask the user.** Otherwise, proceed with the detected mode.

The mode affects ONLY Step 6:
- **records** → Follow `step-6-execute` (create via API, verify, document)
- **sql** → Follow `step-6-generate-sql` (generate INSERT statements)

**Steps 0-5 are IDENTICAL for both modes.**

---

## ABSOLUTE RULES

1. **YOU MUST USE SUB-AGENTS FOR STEPS 1-5.** You are the orchestrator. You do NOT execute Steps 1-5 yourself.
2. **YOU EXECUTE STEP 6 YOURSELF.** After sub-agents complete planning, YOU create records or generate SQL so the user can interact with you during execution.
3. **DO NOT call Atlas MCP or Data Generator MCP tools during Steps 1-5.** Those are for sub-agents.
4. **YOU MAY call MCP tools in Step 6** (create_record, query_records, get_session, rollback_session for records mode; get_app_schema, get_field_map for SQL mode).
5. **YOUR JOBS ARE:** (a) Step 0: Initialize, (b) Spawn sub-agents for Steps 1-5, (c) Read all output files, (d) Confirm with user, (e) Execute Step 6, (f) Report results.
6. **FILES ON DISK ARE THE HANDOFF.** Sub-agents write files. You read them before executing.
7. **IF A SUB-AGENT FAILS, re-run that step only.** Don't restart the whole pipeline.

---

## EXECUTION

### Phase 1: You (Orchestrator) — Initialize

1. Parse the user's request: application name, entity, target status, conditions, **mode** (records/sql)
2. Create the folder: `data-requests/{YYYY-MM-DD}_{short-description}/`
3. Create all PENDING files per `step-0-initialize` steering
4. Verify all files exist
5. Then dispatch the sub-agent pipeline

### Phase 2: Spawn Sub-Agent Pipeline (Steps 1-5)

⚠️ **THIS IS MANDATORY. You MUST call the `subagent` tool now.** Do NOT execute Steps 1-5 yourself.

Call the `subagent` tool with the following pipeline. Replace `{app_name}`, `{task}`, and `{folder_path}` with actual values from Phase 1:

```
subagent(
  task: "{user's original request}",
  mode: "blocking",
  stages: [
    {
      name: "step-1-workflow-analysis",
      role: "kiro_default",
      model: "claude-opus-4-20250918",
      prompt_template: "You are executing Step 1 of the Atlas SQL Forge data generation workflow.

APPLICATION: {app_name}
REQUEST: {task}
FOLDER: {folder_path}

INSTRUCTIONS: Read the steering file 'step-1-workflow-analysis' from the atlas-sql-forge power. Follow it EXACTLY.

YOUR JOB: Trace ALL process models, subprocesses, and rules in the workflow lifecycle from entity creation to the target state. Document EVERY table that receives writes.

OUTPUT: Update {folder_path}/analysis.md with complete workflow analysis. Change status from PENDING to COMPLETE.

CRITICAL: Trace the ENTIRE lifecycle (Create → Start → intermediate steps → target state). Do NOT only read the final action."
    },
    {
      name: "step-2-exemplar-discovery",
      role: "kiro_default",
      model: "claude-opus-4-20250918",
      prompt_template: "You are executing Step 2 of the Atlas SQL Forge data generation workflow.

APPLICATION: {app_name}
REQUEST: {task}
FOLDER: {folder_path}

INSTRUCTIONS: Read the steering file 'step-2-exemplar-discovery' from the atlas-sql-forge power. Follow it EXACTLY.

PREREQUISITE: Read {folder_path}/analysis.md first — it contains the table inventory you must query.

YOUR JOB: Find a real record in the target status, query ALL its fields, query ALL relationships and ALL tables from the analysis. Build a complete reconciliation.

OUTPUT: Update {folder_path}/exemplar.md with complete exemplar data. Change status from PENDING to COMPLETE.

CRITICAL: Query EVERY table from the analysis — not just direct relationships.",
      depends_on: ["step-1-workflow-analysis"]
    },
    {
      name: "step-3-data-architecture",
      role: "kiro_default",
      model: "claude-opus-4-20250918",
      prompt_template: "You are executing Step 3 of the Atlas SQL Forge data generation workflow.

APPLICATION: {app_name}
REQUEST: {task}
FOLDER: {folder_path}

INSTRUCTIONS: Read the steering file 'step-3-data-architecture' from the atlas-sql-forge power. Follow it EXACTLY.

PREREQUISITE: Read {folder_path}/analysis.md and {folder_path}/exemplar.md first.

YOUR JOB: Get field maps, insertion order, reference data (queried LIVE), users list. Build coverage checklist with INCLUDE/EXCLUDE for every table. Map fields for each included table.

OUTPUT: Update {folder_path}/data-architecture.md with complete architecture. Change status from PENDING to COMPLETE.",
      depends_on: ["step-2-exemplar-discovery"]
    },
    {
      name: "step-4-data-payloads",
      role: "kiro_default",
      model: "claude-opus-4-20250918",
      prompt_template: "You are executing Step 4 of the Atlas SQL Forge data generation workflow.

APPLICATION: {app_name}
REQUEST: {task}
FOLDER: {folder_path}

INSTRUCTIONS: Read the steering file 'step-4-data-payloads' from the atlas-sql-forge power. Follow it EXACTLY.

PREREQUISITE: Read {folder_path}/data-architecture.md and {folder_path}/exemplar.md first.

YOUR JOB: Build exact JSON payloads for every included table. Every field must have a documented reason. Field coverage must be ≥80% for all record types.

OUTPUT: Write payload files to {folder_path}/payloads/ with complete payloads. Change status from PENDING to COMPLETE.",
      depends_on: ["step-3-data-architecture"]
    },
    {
      name: "step-5-validation",
      role: "kiro_default",
      model: "claude-opus-4-20250918",
      prompt_template: "You are executing Step 5 of the Atlas SQL Forge data generation workflow.

APPLICATION: {app_name}
REQUEST: {task}
FOLDER: {folder_path}

INSTRUCTIONS: Read the steering file 'step-5-validation' from the atlas-sql-forge power. Follow it EXACTLY.

PREREQUISITE: Read ALL files in {folder_path}/ (analysis.md, exemplar.md, data-architecture.md, payloads/).

YOUR JOB: Run 4 validation checks — table coverage (ALL app tables), FK integrity, exemplar diff, reference data IDs. If any check fails, fix payload files before completing.

OUTPUT: Update {folder_path}/validation-report.md with ALL CHECKS PASS. Change status from PENDING to COMPLETE.",
      depends_on: ["step-4-data-payloads"]
    }
  ]
)
```

### Phase 3: You (Orchestrator) — Review, Confirm, Execute

After the sub-agent pipeline completes, YOU take over for Step 6.

**Step 1: Read ALL generated documents:**
- `{folder_path}/analysis.md` — understand the workflow and tables
- `{folder_path}/exemplar.md` — see real data patterns
- `{folder_path}/data-architecture.md` — understand the plan
- `{folder_path}/payloads/00-metadata.json` — get file sequence and record counts
- `{folder_path}/validation-report.md` — confirm ALL CHECKS PASS

⚠️ **You MUST read all documents before proceeding.** Do not skip any.

**Step 2: Confirm with user:**

For **records** mode:
> I've completed the analysis and planning. Here's what I'll create:
> - {N} records across {M} tables
> - Entity: {entity} in {status} status
> - Key data: {brief description}
>
> Proceed?

For **sql** mode:
> I've completed the analysis and planning. Here's what I'll generate:
> - SQL script with {N} records across {M} tables
> - Entity: {entity} in {status} status
> - Key data: {brief description}
>
> Generate the SQL file?

**Step 3: On user confirmation — Execute Step 6:**

- **Records mode:** Read the `step-6-execute` steering file for guidance
  - Read each payload file from `payloads/` in sequence
  - Execute `create_record` calls, resolve FK references
  - Show progress, verify, write `execution-log.md`

- **SQL mode:** Read the `step-6-generate-sql` steering file for guidance
  - Read each payload file from `payloads/` in sequence
  - Map camelCase → UPPER_SNAKE column names via `get_field_map`
  - Generate INSERT statements with LAST_INSERT_ID() for FK handling
  - Write `bulk-data.sql`

**Step 4: Report results:**

For **records** mode:
> ✅ Done! Created {entity} in {status} status.
> - Record ID: {id}
> - Child records: {N} across {M} tables
> - Total records created: {total}
> - To undo: I can rollback all records created in this session.

For **sql** mode:
> ✅ Done! SQL script generated.
> - File: {folder_path}/bulk-data.sql
> - Total records: {N} across {M} tables
> - To execute: `mysql -h <host> -u <user> -p <database> < bulk-data.sql`
> - ⚠️ Remember to sync records in Appian after execution.

---

## RESUMING A FAILED PIPELINE

If a sub-agent step (1-5) fails:
1. Read the files in the folder to determine which step failed
2. Fix the issue (if it's a steering/config problem)
3. Re-run ONLY the failed step and subsequent steps as a new sub-agent pipeline

If Step 6 fails:
1. You're already in conversation with the user — discuss the error
2. Fix the payload or adjust the approach
3. Continue from where you stopped (don't re-create already-created records)
4. Use `get_session()` to see what's already been created (records mode only)
