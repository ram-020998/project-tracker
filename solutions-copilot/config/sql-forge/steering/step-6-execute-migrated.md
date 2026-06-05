---
inclusion: auto
---

# Step 6: Execution

## 🛑 STOP! READ THIS ENTIRE FILE BEFORE PROCEEDING 🛑

**This step creates actual records in the live Appian environment.** You will read payloads directly from `payloads.json`, execute them in order, verify each creation, and document results. This is irreversible (without rollback) — be precise.

**BEFORE YOU START:**

1. ✅ **VERIFY Step 5 is ✅ COMPLETE** — `validation-report.md` must show ALL CHECKS PASS.
2. ✅ **HAVE payloads.json OPEN** — This is your source of truth. Read values FROM it. Do not improvise.
3. ✅ **SHOW THE EXECUTION TRACKER** — Mark Step 6 as 🔄 IN PROGRESS.

---

## CRITICAL RULES — MANDATORY COMPLIANCE

- ⚠️ **payloads.json IS THE SOURCE OF TRUTH** — Read field values directly from it. Do NOT retype, reinterpret, or improvise.
- ⚠️ **EXECUTE IN EXACT INSERTION ORDER** — Follow the `insertion_sequence` from payloads.json. No reordering.
- ⚠️ **CAPTURE EVERY RESPONSE** — Record the ID returned from every data-generator.create_record call.
- ⚠️ **RESOLVE FK PLACEHOLDERS** — Replace `__FK_FROM_STEP_N__` with actual IDs from prior responses.
- ⚠️ **VERIFY AFTER CREATION** — Query each created record to confirm it exists and has correct values.
- ⚠️ **STOP ON ERROR** — If any create fails, STOP. Do not continue creating records on a broken chain.
- ⚠️ **ASK USER BEFORE STARTING** — Brief confirmation: "I'll create N records across M tables. Proceed?"

---

## BLOCKING CHECK

Before starting, verify:
```
Step 0: Initialize                     [✅] ✅ COMPLETED
Step 1: Workflow Analysis              [✅] ✅ COMPLETED
Step 2: Exemplar Discovery             [✅] ✅ COMPLETED
Step 3: Data Architecture              [✅] ✅ COMPLETED
Step 4: Data Payloads                  [✅] ✅ COMPLETED
Step 5: Validation                     [✅] ✅ COMPLETED
  - validation-report.md: ALL CHECKS PASS
```

**If Step 5 is not ✅, STOP IMMEDIATELY. Go back and complete Step 5.**

---

## EXECUTION

### 6a: Brief User Confirmation

Present a ONE-LINE summary to the user:

> "I'll create {N} records across {M} tables for {entity} in {target_status} status. Proceed?"

**Do NOT dump table names, field lists, or technical details.** The user doesn't need to see that — they already approved the request when they asked for data.

Wait for user to say yes/proceed/go ahead. If they say no, ask what they want to change.

---

### 6b: Execute Payloads in Order

Read `payloads/00-metadata.json` to get the `file_sequence`. Then process each file in order.

**For each payload file in sequence:**

1. **Read the file** from `payloads/{filename}`
2. **For each record in the file's `records` array:**
   - Resolve FK placeholders (`@alias` references) with actual IDs from earlier responses
   - Call `data-generator.create_record` with the record_type_uuid and fields
   - Capture the response — store the created ID using the record's `output_ref` as the alias
3. **Document each creation** in the execution log

```
data-generator.create_record(
  record_type_uuid: "{from payload}",
  fields: {from payload},
  related_records: {from payload, if present}
)
```

4. **Capture the response** — record the created record ID(s)
5. **Store IDs for FK resolution** — subsequent steps may need them

**Document each execution:**

```markdown
### Payload Step {N}: {description}

**Action:** data-generator.create_record
**Record Type:** {name} ({uuid})
**Result:** ✅ Success
**Created Record ID:** {id}
**Related Records Created:** {count} (IDs: [...])
```

---

### 6c: Handle Errors

**If a data-generator.create_record call fails:**

1. **STOP immediately** — do not execute remaining payloads
2. **Document the error** — exact error message, which payload failed, what was sent
3. **Diagnose** — common causes:
   - Invalid field name → check field_map
   - Invalid FK → target record doesn't exist yet
   - Computed field included → remove it from payload
   - Invalid user → not in data-generator.list_users()
   - Type mismatch → date format, integer vs string
4. **Fix and retry** — correct the payload, re-execute ONLY the failed step
5. **Resume** — continue from where you stopped

```markdown
### Payload Step {N}: {description}

**Action:** data-generator.create_record
**Result:** ❌ FAILED
**Error:** {error message}
**Diagnosis:** {root cause}
**Fix Applied:** {what was changed}
**Retry Result:** ✅ Success (ID: {id})
```

---

### 6d: Verify Created Records

After ALL payloads are executed successfully, verify the data exists:

**Query the root entity:**
```
data-generator.query_records(
  record_type_uuid: "{root_uuid}",
  filters: [{"field": "{pk_field}", "operator": "=", "value": {created_id}}],
  paging_info: {"startIndex": 1, "batchSize": 1}
)
```

**Verify:**
- Record exists
- Status field matches target status
- Key fields match what was sent

**Query at least 2 child record types to confirm they're linked:**
```
data-generator.query_records(
  record_type_uuid: "{child_uuid}",
  filters: [{"field": "{fk_field}", "operator": "=", "value": {parent_id}}],
  paging_info: {"startIndex": 1, "batchSize": 100}
)
```

**Verify:**
- Expected count of children exists
- FK field correctly points to parent

---

### 6e: Write Execution Log

⚠️ **WRITE THE FILE USING CHUNKED APPROACH:**

1. **First:** Use `create` command to write header + Created Records table
2. **Then:** Use `insert` command (no insertLine) to append: Verification Results, Session Summary, Quick Reference

⚠️ **Do NOT use strReplace.** Use `create` for the first chunk, then `insert` to append.

Update `execution-log.md` — **overwrite with create, then append sections with insert.**

```markdown
# Execution Log

**Status:** ✅ COMPLETE
**Application:** {app_name}
**Request:** {user's request}
**Created:** {YYYY-MM-DD}
**Executed:** {YYYY-MM-DD HH:MM}
**Total Records Created:** {count}

---

## Created Records

| # | Step | Record Type | Record ID | Related Records | Status |
|---|------|-------------|-----------|-----------------|--------|
| 1 | 1 | AS_APP_EVALUATION | 1055 | 3 vendors, 4 criteria | ✅ |
| 2 | 2 | AS_APP_EVAL_TEAM | 5010 | — | ✅ |
| 3 | 3 | AS_APP_TEAM_MEMBERSHIP | 6010, 6011 | — | ✅ |

## Verification Results

| Check | Result |
|-------|--------|
| Root entity exists | ✅ Verified (ID: {id}) |
| Root status = {target} | ✅ Verified |
| Child records linked | ✅ {N} children found for parent |
| FK integrity | ✅ All FKs resolve |

## Session Summary

**Session ID:** {from data-generator.get_session()}
**Records in session:** {count}
**Rollback available:** Yes — use `data-generator.rollback_session(confirm: true)` to undo all

## Quick Reference

- **Root Record ID:** {id}
- **Application:** {app_name}
- **Entity:** {entity_name} in {target_status} status
- **To rollback:** `data-generator.rollback_session(confirm: true)`
```

---

### 6f: Present Results to User

Show the user a clean summary:

> ✅ **Done!** Created {entity} in {status} status.
>
> - **Record ID:** {id}
> - **Child records:** {N} across {M} tables
> - **Total records created:** {total}
>
> To undo: I can rollback all records created in this session.

---

## QUALITY CHECK BEFORE MARKING COMPLETE

Before marking Step 6 as ✅, verify ALL of the following:

- [ ] User confirmed execution
- [ ] All payload steps executed successfully (or failed → fixed → retried)
- [ ] Every created record ID is documented
- [ ] FK placeholders were resolved with actual IDs
- [ ] Root entity was queried and verified
- [ ] At least 2 child types were queried and verified
- [ ] `execution-log.md` has been written to disk with ✅ COMPLETE status
- [ ] User was presented with a clean summary

**If ANY of these are false, you are NOT done.**

---

## EXECUTION TRACKER UPDATE — MANDATORY

⚠️ **After completing this step, you MUST show the full execution tracker in your response.**

Update the tracker:
- Mark Step 6 as ✅ COMPLETED
- Set CURRENT STATUS to: `✅ WORKFLOW COMPLETE`

```
DATA GENERATION WORKFLOW — EXECUTION TRACKER
=============================================
Step 0: Initialize                     [✅] ✅ COMPLETED
Step 1: Workflow Analysis              [✅] ✅ COMPLETED
Step 2: Exemplar Discovery             [✅] ✅ COMPLETED
Step 3: Data Architecture              [✅] ✅ COMPLETED
Step 4: Data Payloads                  [✅] ✅ COMPLETED
Step 5: Validation                     [✅] ✅ COMPLETED
Step 6: Execution                      [✅] ✅ COMPLETED

CURRENT STATUS: ✅ WORKFLOW COMPLETE
Records created: {count}
Root entity ID: {id}
Rollback available: Yes
```

---

## COMPLETION CRITERIA

Step 6 is ✅ COMPLETE only when:

1. All records created successfully in the environment
2. Verification queries confirm data exists and is correct
3. `execution-log.md` has been written with all IDs and verification results
4. User has been shown the results
5. Execution tracker shows all steps ✅

**Workflow is now complete. Offer to rollback if needed.**
