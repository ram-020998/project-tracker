---
inclusion: auto
---

# Step 6: Generate SQL

## 🛑 STOP! READ THIS ENTIRE FILE BEFORE PROCEEDING 🛑

**This step generates a MySQL-compatible SQL file with INSERT statements for all planned records.** You will read payloads from the `payloads/` folder, convert camelCase field names to UPPER_SNAKE column names, format values for SQL, and handle FK references via `LAST_INSERT_ID()`. The output is a ready-to-execute SQL script.

**BEFORE YOU START:**

1. ✅ **VERIFY Step 5 is ✅ COMPLETE** — `validation-report.md` must show ALL CHECKS PASS.
2. ✅ **HAVE payloads/ files OPEN** — These are your source of truth. Read values FROM them.
3. ✅ **SHOW THE EXECUTION TRACKER** — Mark Step 6 as 🔄 IN PROGRESS.

---

## CRITICAL RULES — MANDATORY COMPLIANCE

- ⚠️ **payloads/ files ARE THE SOURCE OF TRUTH** — Read field values directly from them. Do NOT retype or improvise.
- ⚠️ **USE UPPER_SNAKE COLUMN NAMES** — SQL uses the database column names, not camelCase. Get the mapping from `get_field_map`.
- ⚠️ **RESPECT INSERTION ORDER** — Parents before children. Same as records mode.
- ⚠️ **USE LAST_INSERT_ID() FOR FK REFERENCES** — Not hardcoded IDs. Not guessed sequences.
- ⚠️ **NEVER INCLUDE PK COLUMNS** — Auto-increment handles PKs.
- ⚠️ **BATCH LARGE INSERTS** — Max 100 rows per INSERT statement for MySQL safety.
- ⚠️ **ESCAPE STRINGS** — Single quotes doubled: `'People''s Republic'`.
- ⚠️ **INCLUDE SYNC REMINDER** — Appian synced records need manual sync after direct DB writes.

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

Present a ONE-LINE summary:

> "I'll generate a SQL script with {N} records across {M} tables for {entity} in {target_status} status. Generate?"

Wait for user confirmation.

---

### 6b: Get Column Name Mappings

You need to convert camelCase → UPPER_SNAKE for the SQL file:

```
get_field_map(app_name)
```

The field map gives you `UPPER_SNAKE → camelCase`. Reverse it to get `camelCase → UPPER_SNAKE`.

Also get the schema for column type information:
```
get_app_schema(app_name)
```

---

### 6c: Generate SQL File Structure

The SQL file MUST follow this structure:

```sql
-- ============================================================
-- Atlas SQL Forge — Bulk Data SQL
-- Generated: {YYYY-MM-DD HH:MM:SS}
-- Request: {user's original request}
-- Application: {app_name}
-- Total Records: {N}
-- ============================================================

-- Disable FK checks for faster insertion
SET FOREIGN_KEY_CHECKS = 0;

-- [INSERT STATEMENTS IN TOPOLOGICAL ORDER]

-- Re-enable FK checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- SUMMARY
-- Total records: {N}
--   {TABLE_1}: {count}
--   {TABLE_2}: {count}
--   ...
-- ============================================================

-- ⚠️ IMPORTANT: After executing this script, sync records in Appian:
-- Admin Console → Record Types → Select affected types → Sync
```

---

### 6d: Generate INSERT Statements

Process each payload file in the sequence defined by `payloads/00-metadata.json`.

**For each table in insertion order:**

#### Single parent records (need ID capture):

```sql
-- ============================================================
-- PARENT RECORDS: {TABLE_NAME} ({count} records)
-- ============================================================
INSERT INTO `{TABLE_NAME}` (
  `{COLUMN_1}`,
  `{COLUMN_2}`,
  `{COLUMN_3}`,
  ...
) VALUES (
  {value_1},
  {value_2},
  {value_3},
  ...
);
SET @{alias}_1 = LAST_INSERT_ID();
```

If creating multiple parent records that children reference individually:

```sql
INSERT INTO `{TABLE_NAME}` (...) VALUES (...);
SET @{alias}_1 = LAST_INSERT_ID();

INSERT INTO `{TABLE_NAME}` (...) VALUES (...);
SET @{alias}_2 = LAST_INSERT_ID();
```

#### Bulk child records (using parent ID variable):

```sql
-- ============================================================
-- CHILD RECORDS: {TABLE_NAME} ({count} records)
-- ============================================================
INSERT INTO `{TABLE_NAME}` (
  `{FK_COLUMN}`,
  `{COLUMN_2}`,
  `{COLUMN_3}`,
  ...
) VALUES
  (@{parent_alias}_1, {value_2a}, {value_3a}, ...),
  (@{parent_alias}_1, {value_2b}, {value_3b}, ...),
  (@{parent_alias}_1, {value_2c}, {value_3c}, ...),
  (@{parent_alias}_2, {value_2d}, {value_3d}, ...),
  (@{parent_alias}_2, {value_2e}, {value_3e}, ...);
```

#### Bulk parent records (when children use offset):

When creating many parents with children, use ID arithmetic:

```sql
-- 100 parent records
INSERT INTO `{TABLE_NAME}` (...) VALUES
  (...row1...),
  (...row2...),
  ...
  (...row100...);
SET @{alias}_start = LAST_INSERT_ID();

-- Children referencing parents by offset
INSERT INTO `{CHILD_TABLE}` (`{FK_COLUMN}`, ...) VALUES
  (@{alias}_start + 0, ...),   -- child of parent 1
  (@{alias}_start + 0, ...),   -- child of parent 1
  (@{alias}_start + 1, ...),   -- child of parent 2
  (@{alias}_start + 1, ...),   -- child of parent 2
  ...;
```

---

### 6e: Type Formatting for SQL

| Appian Type | MySQL Format | Example |
|-------------|-------------|---------|
| Text | `'quoted string'` | `'Evaluation Title'` |
| Integer | Unquoted number | `3` |
| Decimal | Unquoted decimal | `99.5` |
| Boolean | `1` or `0` | `1` |
| Date | `'YYYY-MM-DD'` | `'2026-05-13'` |
| Datetime | `NOW()` or `'YYYY-MM-DD HH:MM:SS'` | `NOW()` |
| User | `'username'` (stored as text) | `'admin.user'` |
| NULL | `NULL` | `NULL` |

### String Escaping
- Escape single quotes by doubling: `'People''s Republic'`
- Backslash escaping: `'People\'s Republic'` (also valid)

---

### 6f: Data Variation for Bulk

For bulk generation (many records of same type), vary the data:

**Text fields:**
- Use CONCAT with sequence: `CONCAT('Evaluation-', LPAD({n}, 4, '0'))`
- Or pre-generate varied values in the INSERT

**Date fields:**
- Spread across a range: vary by days
- Maintain logical sequence per record (start < due < completion)

**User fields:**
- Rotate through available users: `users[n % user_count]`

**Reference data fields:**
- Distribute across valid values (e.g., 60% one status, 40% another)
- Or use specific distribution if user requested

**Boolean fields:**
- Mix with realistic ratios

---

### 6g: Batch Large Inserts

For tables with > 100 records, split into batches:

```sql
-- Batch 1 of 3 (records 1-100)
INSERT INTO `{TABLE_NAME}` (...) VALUES
  (...),
  ...
  (...);

-- Batch 2 of 3 (records 101-200)
INSERT INTO `{TABLE_NAME}` (...) VALUES
  (...),
  ...
  (...);
```

---

### 6h: Write the SQL File

Save to: `data-requests/{folder}/bulk-data.sql`

⚠️ **WRITE USING CHUNKED APPROACH for large files:**

1. **First:** Use `create` command to write the header + first table's INSERT statements
2. **Then:** Use `insert` command (no insertLine) to append each subsequent table's statements
3. **Finally:** Append the footer (re-enable FK checks + summary)

⚠️ **Do NOT use strReplace.** Use `create` for initial content, then `insert` to append.

---

### 6i: Update Execution Log

Update `execution-log.md`:

```markdown
# Execution Log

**Status:** ✅ COMPLETE
**Application:** {app_name}
**Request:** {user's request}
**Mode:** SQL Generation
**Created:** {YYYY-MM-DD}
**Generated:** {YYYY-MM-DD HH:MM}

---

## Generated SQL File

**File:** `bulk-data.sql`
**Total Records:** {count}

| # | Table | Records | Method |
|---|-------|---------|--------|
| 1 | {TABLE_1} | {count} | INSERT with LAST_INSERT_ID |
| 2 | {TABLE_2} | {count} | INSERT with parent FK reference |
| ... | ... | ... | ... |

## Execution Instructions

```bash
mysql -h <host> -u <user> -p <database> < bulk-data.sql
```

## Post-Execution Steps

1. Log into Appian Admin Console
2. Navigate to Record Types
3. Select affected record types
4. Click "Sync" to refresh the synced record cache

## Notes

- FK_CHECKS disabled during execution for speed
- Parent IDs captured via LAST_INSERT_ID() and @variables
- Child records reference parents via @variable arithmetic
- All reference data IDs verified against live environment in Step 5
```

---

### 6j: Present Results to User

> ✅ **Done!** SQL script generated.
>
> - **File:** `data-requests/{folder}/bulk-data.sql`
> - **Total records:** {N} across {M} tables
> - **To execute:** `mysql -h <host> -u <user> -p <database> < bulk-data.sql`
>
> ⚠️ After executing, sync affected record types in Appian Admin Console.

---

## QUALITY CHECK BEFORE MARKING COMPLETE

Before marking Step 6 as ✅, verify ALL of the following:

- [ ] User confirmed SQL generation
- [ ] All payload files were read and converted to SQL
- [ ] Column names are UPPER_SNAKE (from field_map), not camelCase
- [ ] No PK columns are included in INSERT statements
- [ ] All FK references use @variables (LAST_INSERT_ID), not hardcoded IDs
- [ ] Strings are properly escaped
- [ ] FK_CHECKS is disabled at start and re-enabled at end
- [ ] Insertion order respects FK dependencies (parents first)
- [ ] Batches of > 100 rows are split
- [ ] Summary comment shows total record counts
- [ ] Sync reminder is included
- [ ] `bulk-data.sql` has been written to disk
- [ ] `execution-log.md` has been updated with ✅ COMPLETE status

---

## EXECUTION TRACKER UPDATE — MANDATORY

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
Step 6: SQL Generation                 [✅] ✅ COMPLETED

CURRENT STATUS: ✅ WORKFLOW COMPLETE
SQL file: bulk-data.sql
Total records: {count}
```

---

## COMMON FAILURES TO AVOID

| Failure | Why It's Bad | How to Prevent |
|---------|-------------|----------------|
| Using camelCase in SQL | MySQL columns are UPPER_SNAKE — will fail | Use reversed field_map |
| Including PK columns | Duplicate key errors | Never include auto-increment PKs |
| Hardcoding FK values | Wrong in different environments | Use @variables + LAST_INSERT_ID |
| Not escaping quotes | SQL syntax error | Double single quotes in strings |
| Not disabling FK_CHECKS | Slow inserts + ordering issues | Always disable at start |
| One giant INSERT | MySQL max_allowed_packet overflow | Batch at 100 rows |
| Forgetting sync reminder | Records invisible in Appian UI | Always include in footer |
| Wrong insertion order | FK constraint violations | Follow topological order |
