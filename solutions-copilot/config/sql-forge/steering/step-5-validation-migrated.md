---
inclusion: auto
---

# Step 5: Validation

## 🛑 STOP! READ THIS ENTIRE FILE BEFORE PROCEEDING 🛑

**This step is your final safety net.** You will systematically verify that your payloads cover all required tables, all FK references are valid, all reference data IDs exist, and your planned data matches the exemplar patterns. This is an automated self-check — no human involvement.

**BEFORE YOU START:**

1. ✅ **VERIFY Step 4 is ✅ COMPLETE** — `payloads.json` must have status "COMPLETE".
2. ✅ **HAVE ALL PREVIOUS FILES AVAILABLE** — analysis.md, exemplar.md, data-architecture.md, payloads.json.
3. ✅ **SHOW THE EXECUTION TRACKER** — Mark Step 5 as 🔄 IN PROGRESS.

---

## CRITICAL RULES — MANDATORY COMPLIANCE

- ⚠️ **THIS STEP IS AUTOMATED** — No human input needed. You verify everything yourself.
- ⚠️ **IF VALIDATION FAILS, YOU DO NOT PROCEED** — Go back and fix payloads.json first.
- ⚠️ **EVERY CHECK MUST PASS** — A single FAIL means Step 5 is not complete.
- ⚠️ **BE HONEST** — Do not mark checks as PASS if you haven't actually verified them.

---

## BLOCKING CHECK

Before starting, verify:
```
Step 0: Initialize                     [✅] ✅ COMPLETED
Step 1: Workflow Analysis              [✅] ✅ COMPLETED
Step 2: Exemplar Discovery             [✅] ✅ COMPLETED
Step 3: Data Architecture              [✅] ✅ COMPLETED
Step 4: Data Payloads                  [✅] ✅ COMPLETED
  - payloads.json status: COMPLETE
  - Field coverage: all ≥80%
```

**If Step 4 is not ✅, STOP IMMEDIATELY. Go back and complete Step 4.**

⚠️ **Payloads are split across multiple files in `payloads/` folder.** Read `payloads/00-metadata.json` first to get the file list, then read each numbered file.

---

## EXECUTION

### 5a: Full Table Coverage Check

Get the complete list of ALL tables in the application:

```
solutions-intelligence.get_app_schema(app_name)
```

For EVERY table in the application schema, determine its status relative to your payloads:

```markdown
## Table Coverage

| # | Table | In Payloads? | Status | Reason |
|---|-------|-------------|--------|--------|
| 1 | AS_APP_EVALUATION | ✅ | COVERED | Root entity — payload step 1 |
| 2 | AS_APP_EVAL_VENDOR | ✅ | COVERED | Related record in payload step 1 |
| 3 | AS_APP_EVAL_CRITERIA | ✅ | COVERED | Related record in payload step 1 |
| 4 | AS_APP_EVAL_TEAM | ✅ | COVERED | Separate create in payload step 2 |
| 5 | AS_APP_STATUS_REF | ⬜ | REFERENCE TABLE | Lookup only — never written to |
| 6 | AS_APP_METHOD_REF | ⬜ | REFERENCE TABLE | Lookup only — never written to |
| 7 | AS_APP_AUDIT_LOG | ⬜ | AUTO-GENERATED | Platform creates on every write |
| 8 | AS_APP_NOTIFICATION | ⬜ | NOT NEEDED | Created by async listener, not required for state |
| 9 | AS_APP_REPORT_CACHE | ⬜ | NOT NEEDED | Rebuilt by scheduled process, not part of entity state |
| 10 | AS_APP_USER_PREFS | ⬜ | NOT NEEDED | User preferences — unrelated to entity state |
```

**Valid statuses:**
- ✅ COVERED — table has records in payloads.json
- ⬜ REFERENCE TABLE — lookup data, never written by the workflow
- ⬜ AUTO-GENERATED — platform/system creates these automatically
- ⬜ NOT NEEDED — not part of the entity's state (with specific reason)
- ❌ MISSING — should be covered but isn't → **FAIL, go fix payloads**

**Rules:**
- Every table from Step 1's workflow analysis that receives writes MUST be ✅ COVERED
- Tables marked NOT NEEDED must have a specific, defensible reason
- If ANY table is ❌ MISSING, this check FAILS

---

### 5b: FK Integrity Pre-Check

For every FK field in your payloads, verify the target record will exist at execution time:

```markdown
## FK Integrity Check

| # | Payload Step | Field | Points To | Value Source | Valid? |
|---|---|---|---|---|---|
| 1 | Step 1 | evaluationStatusId | STATUS_REF | 3 (queried in Step 3) | ✅ Exists in ref table |
| 2 | Step 1 | evaluationMethodId | METHOD_REF | 4 (queried in Step 3) | ✅ Exists in ref table |
| 3 | Step 2 | evaluationId | EVALUATION.PK | From Step 1 response | ✅ Created in prior step |
| 4 | Step 3 | teamId | EVAL_TEAM.PK | From Step 2 response | ✅ Created in prior step |
```

**Check logic:**
- If FK points to a reference table → verify the ID exists in the ref data queried in Step 3
- If FK points to a record created in an earlier payload step → verify the step order is correct (dependency exists before the dependent)
- If FK is marked as `__FK_FROM_STEP_N__` → verify that step N actually creates the target record

**If ANY FK points to a non-existent value or circular dependency → FAIL**

---

### 5c: Exemplar Pattern Diff

Compare your payloads against the exemplar record from Step 2. For each field:

```markdown
## Exemplar Diff

### Root Entity: AS_APP_EVALUATION

| Field | Exemplar Value | Payload Value | Match? | Delta Reason |
|---|---|---|---|---|
| evaluationTitle | "HD940225Q0010" | "HD260519Q0001" | ⚠️ Different | New unique value — pattern matches (alphanumeric) |
| evaluationStatusId | 3 | 3 | ✅ Same | Target status |
| evaluationMethodId | 4 | 4 | ✅ Same | Same method |
| contractingOfficer | "sarah.smith" | "admin.user" | ⚠️ Different | Different user — both valid from data-generator.list_users() |
| startDate | "2025-12-01" | "2026-04-01" | ⚠️ Different | New date — sequencing preserved |
| completionDate | "2026-01-15" | "2026-05-10" | ⚠️ Different | New date — sequencing preserved |
| cancellationDate | null | null | ✅ Same | Not applicable for Complete status |
| isActive | true | true | ✅ Same | Always true |
```

**Rules:**
- ✅ Same — good, matches exemplar
- ⚠️ Different — acceptable IF there's a valid delta reason
- ❌ Conflict — exemplar says X but payload says Y with no good reason → **investigate**

**Key patterns to verify:**
- Fields that were null in exemplar should generally be null in payload (unless Step 1 analysis says otherwise)
- Fields that had specific values in exemplar should match the pattern (not necessarily the exact value)
- Child record COUNT should be similar (exemplar had 3 vendors → payload has 3 vendors)
- Status-dependent fields must align with the target status

---

### 5d: Reference Data ID Validation

For every reference data ID used in payloads, verify it exists:

```markdown
## Reference Data Validation

| # | Field | Ref Table | ID Used | Valid? | Label |
|---|---|---|---|---|---|
| 1 | evaluationStatusId | STATUS_REF | 3 | ✅ | "Complete" |
| 2 | evaluationMethodId | METHOD_REF | 4 | ✅ | "LPTA" |
| 3 | vendorStatusId | VENDOR_STATUS_REF | 2 | ✅ | "Active" |
| 4 | criteriaTypeId | CRITERIA_TYPE_REF | 1 | ✅ | "Technical" |
```

Cross-reference against the actual ref data values queried in Step 3.

**If ANY ID doesn't exist in the reference table → FAIL**

---

### 5e: Compute Validation Score

Tally the results:

```markdown
## Validation Summary

| Check | Result | Details |
|-------|--------|---------|
| Table Coverage | ✅ PASS / ❌ FAIL | {X}/{Y} tables accounted for, {Z} covered in payloads |
| FK Integrity | ✅ PASS / ❌ FAIL | {N} FK references verified |
| Exemplar Pattern | ✅ PASS / ❌ FAIL | {N} fields checked, {M} conflicts |
| Reference Data IDs | ✅ PASS / ❌ FAIL | {N} IDs verified against live data |

**OVERALL: ✅ ALL CHECKS PASS / ❌ VALIDATION FAILED**
```

---

### 5f: Handle Failures

**If ANY check fails:**

1. Identify exactly what failed and why
2. Go back to `payloads.json` and fix the issue
3. Re-run the failed validation check
4. Do NOT proceed to Step 6 until ALL checks pass

**Common fixes:**
- Missing table → add payload for that table
- Invalid FK → correct the ID or fix insertion order
- Exemplar conflict → update field value or document why divergence is intentional
- Invalid ref data ID → re-query reference table and use correct value

---

### 5g: Write Validation Report

⚠️ **WRITE THE FILE USING CHUNKED APPROACH:**

1. **First:** Use `create` command to write header + Table Coverage section
2. **Then:** Use `insert` command (no insertLine) to append: FK Integrity, Exemplar Diff, Reference Data Validation, Summary

⚠️ **Do NOT use strReplace.** Use `create` for the first chunk, then `insert` to append.

Update `validation-report.md` — **overwrite with create, then append sections with insert.**

```markdown
# Validation Report

**Status:** ✅ ALL CHECKS PASS
**Application:** {app_name}
**Request:** {user's request}
**Created:** {YYYY-MM-DD}
**Validated:** {YYYY-MM-DD HH:MM}

---

## Table Coverage
{From 5a}

## FK Integrity Check
{From 5b}

## Exemplar Diff
{From 5c}

## Reference Data Validation
{From 5d}

## Validation Summary
{From 5e}
```

---

## QUALITY CHECK BEFORE MARKING COMPLETE

Before marking Step 5 as ✅, verify ALL of the following:

- [ ] EVERY table in the app schema is listed in the coverage check (no table left out)
- [ ] No table shows ❌ MISSING status
- [ ] Every NOT NEEDED table has a specific, defensible reason
- [ ] All FK references point to valid targets (ref data or prior creation step)
- [ ] Exemplar diff shows no unexplained ❌ Conflicts
- [ ] All reference data IDs verified against live queried values
- [ ] Overall validation score shows ALL CHECKS PASS
- [ ] `validation-report.md` has been written to disk with PASS status

**If ANY of these are false, go back and fix the issue. Do NOT proceed.**

---

## EXECUTION TRACKER UPDATE — MANDATORY

⚠️ **After completing this step, you MUST show the full execution tracker in your response.**
⚠️ **The tracker must be shown in EVERY response during this step — not just at the end.**

Update the tracker:
- Mark Step 5 as ✅ COMPLETED
- Set CURRENT STATUS to: `Step 6 — Execution`
- Set NEXT REQUIRED ACTION to: `Follow step-6-execute steering`

```
Step 5: Validation                     [✅] ✅ COMPLETED
  - Table coverage: {X}/{Y} covered
  - FK integrity: all valid
  - Exemplar pattern: {N} fields verified
  - Ref data IDs: all valid
  - Overall: ALL CHECKS PASS
```

---

## COMPLETION CRITERIA

Step 5 is ✅ COMPLETE only when:

1. `validation-report.md` status shows ALL CHECKS PASS
2. No ❌ FAIL in any check
3. The quality check above passes ALL items
4. The execution tracker is updated and SHOWN in your response

**ONLY THEN may you proceed to Step 6.**
