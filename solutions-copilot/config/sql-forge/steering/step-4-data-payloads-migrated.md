---
inclusion: auto
---

# Step 4: Data Payloads

## 🛑 STOP! READ THIS ENTIRE FILE BEFORE PROCEEDING 🛑

**This step generates the exact JSON payloads that will be sent to the Data Generator MCP.** Every field value must be deliberate, documented, and traceable back to the exemplar, workflow analysis, or reference data. No guessing. No placeholders.

**BEFORE YOU START:**

1. ✅ **VERIFY Step 3 is ✅ COMPLETE** — `data-architecture.md` must be filled with actual data, not PENDING.
2. ✅ **HAVE data-architecture.md OPEN** — Field maps, insertion sequence, ref data values, users.
3. ✅ **HAVE exemplar.md OPEN** — Actual values from the real record to match patterns.
4. ✅ **SHOW THE EXECUTION TRACKER** — Mark Step 4 as 🔄 IN PROGRESS.

---

## CRITICAL RULES — MANDATORY COMPLIANCE

- ⚠️ **EVERY FIELD VALUE MUST HAVE A DOCUMENTED REASON** — "Why this value?" must be answerable for every field.
- ⚠️ **NEVER GUESS VALUES** — If you don't know the correct value, go back to Step 3 and query it.
- ⚠️ **NEVER SET PK FIELDS** — Auto-generated. If you include a PK, the API will fail.
- ⚠️ **NEVER SET COMPUTED FIELDS** — isCustomRecordField=true fields will error. Exclude them.
- ⚠️ **FIELD COVERAGE MUST BE ≥80%** — You must populate at least 80% of writable fields for each record type.
- ⚠️ **USE EXACT camelCase FIELD NAMES** — From `solutions-intelligence.get_field_map`. Not UPPER_SNAKE. Not guessed names.
- ⚠️ **REFERENCE DATA IDs FROM STEP 3** — Use the actual IDs you queried. Not hardcoded.
- ⚠️ **USERNAMES FROM data-generator.list_users()** — Never invent users.
- ⚠️ **payloads.json IS THE SOURCE OF TRUTH** — Step 6 reads directly from this file. It must be complete and correct.

---

## BLOCKING CHECK

Before starting, verify:
```
Step 0: Initialize                     [✅] ✅ COMPLETED
Step 1: Workflow Analysis              [✅] ✅ COMPLETED
Step 2: Exemplar Discovery             [✅] ✅ COMPLETED
Step 3: Data Architecture              [✅] ✅ COMPLETED
  - data-architecture.md status: ✅ COMPLETE
  - Field maps: defined for all INCLUDED tables
  - Insertion sequence: defined
  - Reference data: queried live
```

**If Step 3 is not ✅, STOP IMMEDIATELY. Go back and complete Step 3.**

---

## EXECUTION

### 4a: Build Payloads in Insertion Order

Follow the exact insertion sequence from `data-architecture.md`. For each record to create:

1. Look up the **record type UUID** from `record_type_map`
2. Look up the **field names** from `field_map` (camelCase)
3. For each field, determine the value from:
   - **Exemplar** — match the pattern from the real record
   - **Reference data** — use the exact ID queried in Step 3
   - **Users** — pick from `data-generator.list_users()` result
   - **Dates** — follow the sequencing plan from Step 3
   - **Calculated** — derive from business logic documented in Step 1
   - **Static** — documented constant (e.g., isActive=true)

---

### 4b: Structure Each Payload

**For records using `related_records` (parent + children atomically):**

```json
{
  "record_type_uuid": "{parent_uuid}",
  "fields": {
    "{field1}": "{value}",
    "{field2}": "{value}"
  },
  "related_records": [
    {
      "relationshipName": "{from record_type_map relationships}",
      "recordType": "{child_uuid}",
      "records": [
        {"{childField1}": "{value}", "{childField2}": "{value}"},
        {"{childField1}": "{value}", "{childField2}": "{value}"}
      ]
    }
  ]
}
```

**For standalone records (separate `data-generator.create_record` calls):**

```json
{
  "record_type_uuid": "{uuid}",
  "fields": {
    "{field1}": "{value}",
    "{fkField}": "{PLACEHOLDER — from previous create response}"
  }
}
```

⚠️ **For FK fields that depend on a previously created record's ID — mark as `"__FK_FROM_STEP_N__"` and document which step provides the value.**

---

### 4c: Document Reasoning for Every Value

For EACH payload, create a reasoning table:

```json
{
  "record_type": "AS_APP_EVALUATION",
  "record_type_uuid": "e6bc8561-...",
  "fields": {
    "evaluationTitle": "HD940225Q0010",
    "evaluationStatusId": 3,
    "evaluationMethodId": 4,
    "contractingOfficer": "admin.user",
    "startDate": "2026-04-01",
    "dueDate": "2026-05-15",
    "completionDate": "2026-05-10",
    "isActive": true
  },
  "field_reasoning": {
    "evaluationTitle": "Pattern from exemplar — alphanumeric contract-style ID",
    "evaluationStatusId": "3 = Complete (from STATUS_REF query in Step 3)",
    "evaluationMethodId": "4 = LPTA (from METHOD_REF query in Step 3, matches exemplar)",
    "contractingOfficer": "admin.user (from data-generator.list_users(), first available)",
    "startDate": "Before dueDate per sequencing plan",
    "dueDate": "After startDate, after completionDate (business logic)",
    "completionDate": "Required for Complete status (from Step 1 analysis)",
    "isActive": "Always true for active records"
  }
}
```

⚠️ **Every field MUST have an entry in field_reasoning. No exceptions.**

---

### 4d: Field Completeness Verification

For EACH record type in the payloads, verify field coverage:

```
data-generator.get_record_properties(record_type_uuid)
```

Count:
- **Total writable fields** = all fields where isCustomRecordField ≠ true AND field is not PK
- **Fields in payload** = fields you're setting a value for
- **Coverage** = fields_in_payload / total_writable_fields × 100

```markdown
## Field Completeness

| Record Type | Total Writable | In Payload | Coverage | Status |
|---|---|---|---|---|
| AS_APP_EVALUATION | 20 | 18 | 90% | ✅ Pass |
| AS_APP_EVAL_VENDOR | 12 | 10 | 83% | ✅ Pass |
| AS_APP_EVAL_CRITERIA | 8 | 5 | 62% | ❌ FAIL — must add fields |
```

⚠️ **If any record type is below 80%, you MUST add more fields.**
⚠️ **For fields you choose to leave null, document WHY in the reasoning.**

**Valid reasons for null:**
- Field is deprecated (null in exemplar, not referenced in any workflow rule)
- Field is only populated in a different status path
- Field is optional and has no business logic dependency

**Invalid reasons for null:**
- "Don't know what to put" — go back and research
- "Seems unimportant" — if it's writable, it matters
- No reason given — MUST document

---

### 4e: Write Payload Files

⚠️ **SPLIT PAYLOADS INTO MULTIPLE FILES.** Do NOT write one giant payloads.json.

Create a `payloads/` subfolder inside the data-requests folder and write one file per insertion phase:

```
data-requests/{date}_{description}/
├── payloads/
│   ├── 00-metadata.json          (metadata + insertion sequence)
│   ├── 01-{root-entity}.json     (root record)
│   ├── 02-{child-type}.json      (first child type)
│   ├── 03-{child-type}.json      (next child type)
│   ├── ...
│   └── NN-{last-type}.json       (last in insertion order)
├── analysis.md
├── exemplar.md
├── ...
```

**Rules:**
- File names are numbered by insertion order: `01-`, `02-`, `03-`, etc.
- Each file contains an array of records for ONE table type
- Each file is small enough to write in a single operation
- The `00-metadata.json` file contains the overall metadata and file sequence

**00-metadata.json structure:**
```json
{
  "status": "COMPLETE",
  "application": "{app_name}",
  "request": "{user's request}",
  "created": "{YYYY-MM-DD}",
  "total_records": 18,
  "file_sequence": [
    "01-evaluation.json",
    "02-evaluator-team.json",
    "03-team-membership.json",
    "04-vendors.json",
    "05-criteria.json",
    "06-assignments.json",
    "07-consensus-reports.json"
  ],
  "field_completeness": {
    "AS_APP_EVALUATION": {"writable": 20, "populated": 18, "coverage": "90%"}
  }
}
```

**Each numbered file structure:**
```json
{
  "table": "AS_APP_EVALUATION",
  "record_type_uuid": "e6bc8561-...",
  "records": [
    {
      "description": "Root evaluation record",
      "fields": { ... },
      "output_ref": "evaluation_id",
      "field_reasoning": { ... }
    }
  ]
}
```

**For FK references:** Use `@alias.fieldName` syntax (e.g., `"@evaluation_id"`) — Step 6 resolves these from prior creation responses.

**Writing approach:**
1. Create the `payloads/` folder
2. Write `00-metadata.json` first
3. Write each numbered file one at a time — each is a single `create` operation
4. Each file should be small (1-6 records max per file, ~50-100 lines)

⚠️ **If a table has many records (e.g., 18 ratings), split further:** `06a-ratings-vendor1.json`, `06b-ratings-vendor2.json`
⚠️ **Do NOT use strReplace.** Always use `create` for each file.
⚠️ **Verify:** After writing all files, list the `payloads/` folder to confirm all files exist.
⚠️ **Do NOT run shell commands to validate JSON.** Instead, read each file using the file read tool — if it reads successfully, the JSON is valid. Do NOT use terminal/python/bash for validation.

```json
{
  "status": "COMPLETE",
  "application": "{app_name}",
  "request": "{user's request}",
  "created": "{YYYY-MM-DD}",
  "insertion_sequence": [
    "Step 1: Create EVALUATION with related VENDOR + CRITERIA",
    "Step 2: Create EVAL_TEAM (FK → evaluation)",
    "Step 3: Create TEAM_MEMBERSHIP (FK → team)",
    "Step 4: Update EVALUATION (set completionDate)"
  ],
  "field_completeness": {
    "AS_APP_EVALUATION": {"writable": 20, "populated": 18, "coverage": "90%"},
    "AS_APP_EVAL_VENDOR": {"writable": 12, "populated": 10, "coverage": "83%"}
  },
  "payloads": [
    {
      "step": 1,
      "action": "data-generator.create_record",
      "description": "Create root evaluation with vendors and criteria",
      "record_type": "AS_APP_EVALUATION",
      "record_type_uuid": "e6bc8561-...",
      "fields": { ... },
      "related_records": [ ... ],
      "field_reasoning": { ... }
    },
    {
      "step": 2,
      "action": "data-generator.create_record",
      "description": "Create evaluation team",
      "record_type": "AS_APP_EVAL_TEAM",
      "record_type_uuid": "abc123-...",
      "fields": { ... },
      "fk_dependencies": ["Step 1 → evaluationId"],
      "field_reasoning": { ... }
    }
  ]
}
```

---

## QUALITY CHECK BEFORE MARKING COMPLETE

Before marking Step 4 as ✅, verify ALL of the following:

- [ ] Every INCLUDED table from Step 3 has a payload entry
- [ ] Every field value uses the correct camelCase name from field_map
- [ ] Every field has a documented reason in field_reasoning
- [ ] No PK fields are being set (auto-generated)
- [ ] No computed/custom record fields are being set
- [ ] All reference data IDs match values queried in Step 3
- [ ] All usernames come from data-generator.list_users() result
- [ ] All dates follow the sequencing plan
- [ ] Field completeness is ≥80% for ALL record types
- [ ] Any field left null has a documented valid reason
- [ ] FK dependencies are clearly marked with which step provides the value
- [ ] Insertion sequence matches Step 3's plan
- [ ] `payloads.json` has been written to disk with status "COMPLETE"

**If ANY of these are false, you are NOT done. Fix it.**

---

## EXECUTION TRACKER UPDATE — MANDATORY

⚠️ **After completing this step, you MUST show the full execution tracker in your response.**
⚠️ **The tracker must be shown in EVERY response during this step — not just at the end.**

Update the tracker:
- Mark Step 4 as ✅ COMPLETED
- Set CURRENT STATUS to: `Step 5 — Validation & Approval`
- Set NEXT REQUIRED ACTION to: `Present plan to user and wait for approval`

```
Step 4: Data Payloads                  [✅] ✅ COMPLETED
  - Payload steps: {count}
  - Total records to create: {count}
  - Field coverage: all ≥80%
```

---

## COMPLETION CRITERIA

Step 4 is ✅ COMPLETE only when:

1. `payloads.json` status is changed from "PENDING" to "COMPLETE"
2. ALL payloads have field_reasoning for every field
3. Field completeness is ≥80% for all record types
4. The quality check above passes ALL items
5. The execution tracker is updated and SHOWN in your response

**ONLY THEN may you proceed to Step 5.**

---

## COMMON FAILURES TO AVOID

| Failure | Why It's Bad | How to Prevent |
|---------|-------------|----------------|
| Using UPPER_SNAKE field names | API expects camelCase — will fail silently or error | Use field_map values only |
| Setting PK fields | API error or duplicate key | Never include PK in fields |
| Hardcoding status ID without querying | Wrong ID in different env = wrong state | Use value from Step 3 ref data query |
| Coverage below 80% | Incomplete records = broken app state | Check with data-generator.get_record_properties |
| No reasoning for field values | Can't debug when data is wrong | Document EVERY value's source |
| Inventing a username | API error or orphaned user reference | Only use data-generator.list_users() values |
| Wrong insertion order | FK violation on create | Follow Step 3's insertion sequence exactly |
