---
inclusion: auto
---

# Step 2: Exemplar Discovery

## 🛑 STOP! READ THIS ENTIRE FILE BEFORE PROCEEDING 🛑

**This step is NEVER skipped.** You MUST find and study a real record in the target state (or closest available state) to use as ground truth. This is your template — the proof that data in this shape actually works in the application.

**BEFORE YOU START:**

1. ✅ **VERIFY Step 1 is ✅ COMPLETE** — `analysis.md` must be filled with actual data, not PENDING.
2. ✅ **HAVE THE TABLE INVENTORY FROM STEP 1** — You need to know which tables and relationships to query.
3. ✅ **SHOW THE EXECUTION TRACKER** — Mark Step 2 as 🔄 IN PROGRESS.

---

## CRITICAL RULES — MANDATORY COMPLIANCE

- ⚠️ **ALL APPLICATION DATA COMES FROM ATLAS KB AND LIVE ENVIRONMENT ONLY** — Do NOT read local files, folders, or documents for application context. Only use Atlas MCP tools and Data Generator MCP tools.
- ⚠️ **THIS STEP IS NEVER SKIPPED** — Even if the user says "just generate data." Even if you think you have enough info. NEVER.
- ⚠️ **QUERY THE LIVE ENVIRONMENT** — Not the KB. Real data from the real environment.
- ⚠️ **FETCH ALL FIELDS** — Do NOT pass `selected_fields`. Always fetch ALL fields for every query.
- ⚠️ **QUERY EVERY RELATIONSHIP** — For every one-to-many relationship on the record type, query those children.
- ⚠️ **DOCUMENT ACTUAL VALUES** — Write down what you see. Not what you expect. The exemplar is truth.
- ⚠️ **IF NO RECORDS IN TARGET STATUS** — Query ANY status. An imperfect exemplar is better than no exemplar.
- ⚠️ **IF THE TABLE IS COMPLETELY EMPTY** — Document that it's empty. Do NOT skip it.

---

## BLOCKING CHECK

Before starting, verify:
```
Step 0: Initialize                     [✅] ✅ COMPLETED
Step 1: Workflow Analysis              [✅] ✅ COMPLETED
  - analysis.md status: ✅ COMPLETE
```

**If Step 1 is not ✅, STOP IMMEDIATELY. Go back and complete Step 1.**

---

## EXECUTION

### 2a: Get Record Type Map

```
get_record_type_map(app_name)
```

This gives you ALL table → UUID mappings and relationship names. You need this to query records.

---

### 2b: Find an Exemplar Record

Query the PRIMARY entity table for a record in the target status.

**Tools:**
```
query_records(
  record_type_uuid: "{uuid from record_type_map}",
  filters: [{"field": "{statusField}", "operator": "=", "value": {target_status_id}}],
  paging_info: {"startIndex": 1, "batchSize": 1}
)
```

**If results = 0 (no records in target status):**
1. Try querying WITHOUT the status filter — get ANY record
2. Document that the exemplar is in a different status
3. Note which fields would differ in the target status (from Step 1 analysis)

**If the table is completely empty:**
1. Document "No exemplar available — table empty"
2. You will rely entirely on Step 1 analysis + schema for field values
3. Still continue — do NOT skip Step 2

---

### 2c: Query the Exemplar's Full Field Set

Once you have a record, examine ALL its fields. Note:
- Which fields have values vs which are null
- The format/pattern of each value (dates, IDs, strings, booleans)
- Which fields are FK references (integer IDs pointing to other tables)
- Which fields are user references (username strings)

---

### 2d: Query ALL Child Relationships (From Record Type Map)

For EVERY one-to-many relationship listed in the `record_type_map` for this entity:

```
query_records(
  record_type_uuid: "{child_uuid}",
  filters: [{"field": "{fk_field}", "operator": "=", "value": {exemplar_record_id}}],
  paging_info: {"startIndex": 1, "batchSize": 100}
)
```

⚠️ **Query EVERY relationship. Not just the ones you think are relevant.**
⚠️ **If a relationship returns 0 records, document that. It might mean that relationship is optional for this status.**

For each child type, document:
- How many child records exist
- What fields they have populated
- Any patterns (e.g., all have same parentFK, sequential ordering fields, varied statuses)

---

### 2e: Query ALL Tables from Step 1 Analysis (CRITICAL — DO NOT SKIP)

⚠️ **THIS IS THE MOST IMPORTANT SUB-STEP. READ CAREFULLY.**

The record_type_map relationships only cover DIRECT one-to-many links from the parent. But Step 1's workflow analysis identified ALL tables that receive writes — including tables that:
- Are linked through intermediate tables (not directly from root)
- Are populated by subprocesses that use a different FK path
- Are sibling entities written to in parallel
- Are lookup/junction tables updated during the workflow

**YOU MUST query every table from Step 1's Table Inventory that was NOT already covered in 2d.**

**Process:**

1. Open `analysis.md` and read the **Complete Table Inventory** section
2. For each table listed there, check: "Did I already query this in step 2d?"
3. If NO — you MUST query it now using the appropriate FK or filter

**For tables not directly linked to the parent:**
- Use the FK field identified in Step 1 analysis to find related records
- If the FK points to a child (not the root), filter by the child's ID from step 2d
- If unsure which FK to use, query with NO filter (small batchSize) just to see the data shape

```
# Example: Table written by subprocess but linked to a CHILD, not the root
query_records(
  record_type_uuid: "{table_uuid_from_record_type_map}",
  filters: [{"field": "{fk_to_child}", "operator": "=", "value": {child_record_id_from_2d}}],
  paging_info: {"startIndex": 1, "batchSize": 100}
)
```

**For junction/mapping tables:**
```
# Junction tables often have composite FKs — filter by one side
query_records(
  record_type_uuid: "{junction_table_uuid}",
  filters: [{"field": "{fk_to_parent_or_child}", "operator": "=", "value": {known_id}}],
  paging_info: {"startIndex": 1, "batchSize": 100}
)
```

⚠️ **EVERY table from Step 1's inventory MUST be queried. No exceptions.**
⚠️ **If you cannot find records for a table, document WHY (empty? wrong FK? not applicable for this status?).**
⚠️ **If you don't know the FK path, use `get_schema_relationships(app_name)` to find it.**

---

### 2f: Query Grandchildren (Depth 2+)

If any child record type ALSO has one-to-many relationships (from the record_type_map), query those too.

Example: Evaluation → Criteria → Criteria Assignments (grandchildren)

**Go at least 2 levels deep. If the Step 1 analysis shows writes to tables at depth 3, go deeper.**

**Also check:** Do any of the tables queried in 2e have their OWN children? If yes, query those too.

---

### 2g: Reconciliation — Verify Complete Coverage

⚠️ **THIS IS YOUR GATE CHECK. DO NOT SKIP.**

Build a reconciliation table comparing:
- Column A: Every table from Step 1's Table Inventory
- Column B: Was it queried in this step? (2d, 2e, or 2f)
- Column C: Records found? (count or "empty")
- Column D: If NOT queried — WHY?

```markdown
## Reconciliation: Step 1 Tables vs Exemplar Queries

| # | Table (from Step 1) | Queried In | Records Found | Status |
|---|---|---|---|---|
| 1 | TABLE_A | 2d (direct relationship) | 3 | ✅ Covered |
| 2 | TABLE_B | 2e (via child FK) | 2 | ✅ Covered |
| 3 | TABLE_C | 2f (grandchild) | 5 | ✅ Covered |
| 4 | TABLE_D | 2e (direct query) | 0 | ⚠️ Empty — optional for this status |
| 5 | TABLE_E | ❌ NOT QUERIED | - | 🛑 MUST QUERY NOW |
```

**If ANY row shows "NOT QUERIED" — go back and query it before proceeding.**
**If ANY row shows "0 records" — document whether this is expected or a gap.**

---

### 2h: Write the Exemplar Document

⚠️ **WRITE THE FILE USING CHUNKED APPROACH:**

1. **First:** Use `create` command to write the header + Exemplar Record + first few relationships
2. **Then:** Use `insert` command (no insertLine) to append: remaining relationships, Grandchildren, Reconciliation, Field Value Patterns, Data Footprint Summary

⚠️ **Do NOT use strReplace.** Use `create` for the first chunk, then `insert` to append remaining sections.
⚠️ **If total content exceeds ~3000 words, split into 2-3 append operations.**

Update `exemplar.md` — **overwrite with create, then append sections with insert.**

**Required sections (ALL mandatory):**

```markdown
# Exemplar Discovery

**Status:** ✅ COMPLETE
**Application:** {app_name}
**Request:** {user's request}
**Created:** {YYYY-MM-DD}
**Exemplar Record ID:** {id}
**Exemplar Status:** {status name} ({status_id})
**Matches Target Status:** {Yes/No — if No, explain what differs}

---

## Exemplar Record

**Record Type:** {name} (UUID: {uuid})
**Record ID:** {id}

| Field | Value | Type | Notes |
|-------|-------|------|-------|
| {field1} | {value} | {Text/Integer/Date/User/...} | {PK/FK to X/status field/...} |
| {field2} | {value} | ... | ... |
| ... | ... | ... | ... |

## Child Records by Relationship

### Relationship: {relationshipName} → {ChildRecordType}
**UUID:** {child_uuid}
**Count:** {N} records found
**FK Field:** {field linking to parent}

| Record # | {key_field_1} | {key_field_2} | {status_field} | ... |
|----------|---|---|---|---|
| 1 | {value} | {value} | {value} | ... |
| 2 | {value} | {value} | {value} | ... |

{Repeat for EVERY relationship}

### Relationship: {next relationship}
...

## Grandchildren (Depth 2)

### {Parent} → {Child} → {Grandchild}
...

## Cross-Reference with Step 1

| # | Table (from analysis) | Queried In | Count | Status |
|---|---|---|---|---|
| 1 | ... | 2d/2e/2f | ... | ✅ Covered / ⚠️ Empty / 🛑 Gap |

## Field Value Patterns

- **Date patterns:** {e.g., startDate always before dueDate, completionDate = today for Complete status}
- **User patterns:** {e.g., chief and contractingOfficer are different users}
- **Status patterns:** {e.g., all child records also in Complete when parent is Complete}
- **Numeric patterns:** {e.g., weights sum to 100, ordering is sequential 1,2,3}
- **Null patterns:** {e.g., cancellationDate always null for Complete status}

## Data Footprint Summary

| Record Type | Count | Key Fields |
|-------------|-------|------------|
| {Parent} | 1 | ... |
| {Child 1} | N | ... |
| {Child 2} | N | ... |
| {Grandchild} | N | ... |
| **TOTAL** | **{sum}** | |
```

---

## QUALITY CHECK BEFORE MARKING COMPLETE

Before marking Step 2 as ✅, verify ALL of the following:

- [ ] An exemplar record was found (or documented as empty with explanation)
- [ ] ALL fields of the exemplar were fetched (no selected_fields filter used)
- [ ] EVERY relationship in record_type_map was queried for children (step 2d)
- [ ] EVERY table from Step 1's Table Inventory was queried — even if not directly related (step 2e)
- [ ] Grandchildren (depth 2+) were queried where applicable (step 2f)
- [ ] Reconciliation table is complete — ALL tables accounted for with status (step 2g)
- [ ] NO table shows "NOT QUERIED" in the reconciliation
- [ ] Field value patterns are documented
- [ ] Data footprint summary has total record count across ALL tables
- [ ] `exemplar.md` has been written to disk with ✅ COMPLETE status

**If ANY of these are false, you are NOT done. Keep querying.**

---

## EXECUTION TRACKER UPDATE — MANDATORY

⚠️ **After completing this step, you MUST show the full execution tracker in your response.**
⚠️ **The tracker must be shown in EVERY response during this step — not just at the end.**

Update the tracker:
- Mark Step 2 as ✅ COMPLETED
- Set CURRENT STATUS to: `Step 3 — Data Architecture`
- Set NEXT REQUIRED ACTION to: `Follow step-3-data-architecture steering`

```
Step 2: Exemplar Discovery             [✅] ✅ COMPLETED
  - Exemplar record ID: {id}
  - Exemplar status: {status}
  - Relationships queried: {count}
  - Total records in footprint: {count}
```

---

## COMPLETION CRITERIA

Step 2 is ✅ COMPLETE only when:

1. `exemplar.md` status is changed from ⏳ PENDING to ✅ COMPLETE
2. ALL sections in the document are filled with actual data (no placeholders)
3. The quality check above passes ALL items
4. The execution tracker is updated and SHOWN in your response

**ONLY THEN may you proceed to Step 3.**

---

## COMMON FAILURES TO AVOID

| Failure | Why It's Bad | How to Prevent |
|---------|-------------|----------------|
| Skipping exemplar ("I have enough info") | No ground truth = invented data = broken app | NEVER skip. This rule is absolute. |
| Using `selected_fields` in queries | Misses fields you didn't know existed | NEVER pass selected_fields |
| Only querying 1-2 relationships | Misses child tables that are required | Query ALL relationships in record_type_map |
| Not going to depth 2 | Grandchildren are often required (e.g., scores, assignments) | Always check if children have their own relationships |
| Not cross-referencing with Step 1 | Tables from workflow analysis may not be reachable via relationships | Explicitly compare both lists |
| Documenting "looks good" instead of actual values | Loses the detail needed for payload construction | Write actual field=value pairs |
