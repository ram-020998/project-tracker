# DB Script Workflow

Generate SQL scripts that match the team's existing patterns in SMT. This skill NEVER generates SQL from generic knowledge. It always researches existing scripts in the same application first, then produces SQL that follows the same conventions, naming, style, and structure.

---

## Triggers

Activate this skill when the user asks:
- "Generate a script to add a column to X"
- "Create a table for vendor scorecards"
- "I need an ALTER TABLE for..."
- "Write a CREATE VIEW for..."
- "Add an index on..."
- "Generate the DB script for this design"
- "I need a trigger for audit logging"

---

## CRITICAL RULE: Pattern-First Generation

**DO NOT generate SQL from general knowledge.** Always follow this order:

1. **Research** — Find existing scripts in the same app that do something similar
2. **Extract patterns** — Note the naming, quoting, spacing, comment style, column conventions
3. **Generate** — Produce SQL that matches those patterns exactly
4. **Validate** — Check against SMT rules (idempotency, naming, separation)

If no similar scripts exist in the app, look at scripts from other apps in the same SMT instance. Only fall back to the templates in `smt-reference.md` if no existing patterns can be found at all.

---

## Workflow Steps

### Step 0: Schema Detection (MANDATORY — see smt-reference.md Section 3)

Before any query, detect the correct schema:
```sql
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1
```
If count > 0 → use `DevTools.SMT_*`. Otherwise → use `Appian.SMT_*`. Use `{SMT_SCHEMA}` as placeholder below.

---

### Step 1: Resolve Application Context

Identify the target application and current release:

```sql
SELECT a.appid, a.appname, a.appdbtableprefix, a.dbtypes,
       dp.devphaseid, dp.devphasename
FROM Appian.SMT_Application a
JOIN Appian.SMT_DevPhase dp ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<PREFIX>'
AND dp.iscurrentlyprimary = 1
LIMIT 1
```

Note the `dbtypes` — if the app supports multiple DB types (e.g., `["MARIA_DB","ORACLE"]`), you must generate scripts for EACH type.

### Step 2: Research Existing Patterns

**Find similar scripts in the same app.** Choose the query based on what the user wants to do:

**For CREATE TABLE — find existing table creation scripts:**
```sql
SELECT s.scriptid, s.scriptname, s.scriptcontentmariadb
FROM Appian.SMT_Script s
WHERE s.devphaseid IN (
  SELECT devphaseid FROM Appian.SMT_DevPhase WHERE appid = <APP_ID>
)
AND s.scriptname LIKE 'Create%'
AND s.scriptcontentmariadb LIKE '%CREATE TABLE%'
ORDER BY s.scriptid DESC
LIMIT 5
```

**For ALTER TABLE — find existing alter scripts:**
```sql
SELECT s.scriptid, s.scriptname, s.scriptcontentmariadb
FROM Appian.SMT_Script s
WHERE s.devphaseid IN (
  SELECT devphaseid FROM Appian.SMT_DevPhase WHERE appid = <APP_ID>
)
AND s.scriptcontentmariadb LIKE '%ALTER TABLE%'
ORDER BY s.scriptid DESC
LIMIT 5
```

**For CREATE VIEW — find existing view scripts:**
```sql
SELECT s.scriptid, s.scriptname, s.scriptcontentmariadb
FROM Appian.SMT_Script s
WHERE s.devphaseid IN (
  SELECT devphaseid FROM Appian.SMT_DevPhase WHERE appid = <APP_ID>
)
AND s.scriptcontentmariadb LIKE '%VIEW%'
ORDER BY s.scriptid DESC
LIMIT 5
```

**For triggers/procedures — find existing trigger scripts:**
```sql
SELECT s.scriptid, s.scriptname, s.scriptcontentmariadb
FROM Appian.SMT_Script s
WHERE s.devphaseid IN (
  SELECT devphaseid FROM Appian.SMT_DevPhase WHERE appid = <APP_ID>
)
AND (s.scriptcontentmariadb LIKE '%TRIGGER%' OR s.scriptcontentmariadb LIKE '%PROCEDURE%')
ORDER BY s.scriptid DESC
LIMIT 5
```

**For any script touching the same table:**
```sql
SELECT s.scriptid, s.scriptname, s.scriptcontentmariadb
FROM Appian.SMT_Script s
WHERE s.devphaseid IN (
  SELECT devphaseid FROM Appian.SMT_DevPhase WHERE appid = <APP_ID>
)
AND s.scriptcontentmariadb LIKE '%<TABLE_NAME>%'
ORDER BY s.scriptid DESC
LIMIT 5
```

### Step 3: Examine the Target Table (if it exists)

If the script modifies an existing table, get its current structure:

```sql
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_COMMENT, EXTRA
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME = '<TABLE_NAME>'
ORDER BY ORDINAL_POSITION
LIMIT 50
```

This tells you:
- What columns already exist (avoid duplicates)
- What naming pattern the columns follow (UPPER_CASE? camelCase?)
- What types are used (int(11)? bigint? varchar(255)?)
- Whether audit columns exist (CREATED_BY, MODIFIED_ON, etc.)
- What the PK column is named

### Step 4: Extract Patterns from Research

From the scripts found in Step 2, note:

**Naming patterns:**
- Do they use backticks around table/column names? (e.g., `` `AS_GSS_EVALUATION` `` vs `AS_GSS_EVALUATION`)
- Are column names UPPER_CASE, lower_case, or camelCase?
- What's the PK naming convention? (`<TABLE>_ID`? `ID`? `<table>Id`?)
- Do they include comments on columns?

**Structure patterns:**
- Do CREATE TABLEs include `IF NOT EXISTS`?
- Do they include `ENGINE=InnoDB`?
- Do they include `DEFAULT CHARSET=utf8mb4`?
- Are audit columns included (CREATED_BY, CREATED_ON, MODIFIED_BY, MODIFIED_ON)?
- Is there an `IS_ACTIVE` soft-delete column?
- What's the AUTO_INCREMENT style?

**Style patterns:**
- Indentation (spaces? tabs? how many?)
- Comma placement (trailing? leading?)
- Line breaks between columns?
- Comment style (inline `COMMENT 'text'`? separate line?)

### Step 5: Generate the Script

Produce SQL that:
1. **Matches the patterns** found in Steps 2-4 exactly
2. **Is idempotent** (follows SMT verification rules from smt-reference.md)
3. **Uses the correct app prefix** from Step 1
4. **Covers ALL supported DB types** — check `{SMT_SCHEMA}.SMT_Application.dbtypes` and generate for each
5. **Research patterns for EACH DB type separately** — query both `scriptcontentmariadb` AND `scriptcontentoracle` from existing scripts

### Step 6: Present to the User — SMT Form-Ready Format

⚠️ **OUTPUT MUST BE COPY-PASTE READY** for the SMT "Add Script" form. Present each script as a block that maps directly to the form fields:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Script Name:        {name following app conventions}                 │
│ Script Type:        {type name} (ID: {type_id})                     │
│ Script Description: {one sentence business reason}                   │
└─────────────────────────────────────────────────────────────────────┘

--- MariaDB Script Content ---
{complete MariaDB SQL — copy directly into the MariaDB field}

--- Oracle Script Content ---
{complete Oracle SQL — copy directly into the Oracle field}
```

**Script Type must be one of these valid values:**

| ID | Name | Category | Use when... |
|---|---|---|---|
| 1 | Create table | CREATE | Creating a new table (deprecated — use 24 or 25 instead) |
| 24 | Create reference table | CREATE | New table for reference/config data (has CROSS_ENVIRONMENT_UUID) |
| 25 | Create transactional table | CREATE | New table for runtime/transactional data |
| 2 | Create view | CREATE | Creating or replacing a view |
| 3 | Create trigger | CREATE | Creating a trigger (must be separate script) |
| 4 | Create procedure | CREATE | Creating a stored procedure (must be separate script) |
| 5 | Add column | CREATE | Adding a column to an existing table |
| 6 | Add index | CREATE | Adding an index to a column |
| 7 | Add constraint | CREATE | Adding a foreign key constraint |
| 11 | Insert reference data | DATA | Inserting rows into a reference/config table |
| 12 | Data update | DATA | Updating specific data values |
| 8 | Data migration | DATA | Complex data migrations (catch-all) |
| 13 | Alter/rename table | ALTER | Renaming a table |
| 14 | Alter/rename column | ALTER | Renaming or modifying a column definition |
| 15 | Set auto increment | ALTER | Changing auto-increment start value |
| 16 | Drop index | DROP | Removing an index |
| 17 | Drop constraint | DROP | Removing a foreign key constraint |
| 10 | Data dictionary | COMMENT | Adding/updating table and column comments |
| 9 | Other | OTHER | Anything that doesn't fit above |

**Rules for choosing Script Type:**
- New table with CROSS_ENVIRONMENT_UUID → **24 (Create reference table)**
- New table without CROSS_ENVIRONMENT_UUID → **25 (Create transactional table)**
- INSERT INTO reference table → **11 (Insert reference data)**
- UPDATE existing data → **12 (Data update)**
- Complex multi-step data migration → **8 (Data migration)**

**If multiple scripts are needed** (e.g., CREATE TABLE + INSERT DATA + ADD INDEX), present each as a separate block with its own Script Name, Type, and Description. Each block = one entry in the SMT form.

**Source attribution** — after the script blocks, state which pattern was used:
- "Based on existing pattern: [script name] (script #XXXX)"
- "No app-specific pattern found. Used [other app] pattern (script #XXXX)"
- "No existing patterns found. Generated from SMT template. Please verify this matches your team's conventions."

**Warnings** — flag any concerns:
- "This table doesn't have audit columns — existing tables in this app do. Want me to add them?"
- "No Oracle scripts exist for this app — Oracle version generated from template. Please verify."

---

## Generation Rules (Always Apply)

### For CREATE TABLE

- Always use `CREATE TABLE IF NOT EXISTS`
- Match the PK naming from existing tables in the same app
- Include audit columns if other tables in the app have them
- Include `COMMENT` on the table and columns if the app's pattern includes them
- Match the engine and charset from existing tables

### For ALTER TABLE (Add Column)

- Use `ADD COLUMN IF NOT EXISTS` (MariaDB)
- Match the column type patterns from the same table
- Place the column logically (after related columns, before audit columns)
- Include `COMMENT` if other columns in the table have comments

### For ALTER TABLE (Modify Column)

- Inherently idempotent (MODIFY is re-runnable)
- Verify the column exists first (from Step 3)
- Warn if the modification could cause data loss (e.g., shrinking varchar length)

### For CREATE VIEW

- Always use `CREATE OR REPLACE VIEW`
- Match the view naming convention from existing views (typically `<PREFIX>_V_<NAME>` or `<PREFIX>_<NAME>_VIEW`)
- Include column aliases that match the app's naming style

### For Triggers

- MUST be in a separate script (never combined with table DDL)
- Always use `DROP TRIGGER IF EXISTS` + `CREATE TRIGGER`
- Match trigger naming from existing triggers (typically `<PREFIX>_TRG_<NAME>`)
- Warn the user: "Triggers always re-run on every deployment"

### For Stored Procedures

- MUST be in a separate script
- Always use `DROP PROCEDURE IF EXISTS` + `CREATE PROCEDURE`
- Match procedure naming (typically `<PREFIX>_SP_<NAME>`)
- Warn the user: "Procedures always re-run on every deployment"

### For Indexes

- Use `CREATE INDEX IF NOT EXISTS` (MariaDB)
- Match index naming from existing indexes (check via DESCRIBE or existing scripts)
- Suggest indexes for FK columns that don't have them

### For Foreign Keys

- Use `DROP FOREIGN KEY IF EXISTS` + `ADD CONSTRAINT` pattern
- Match FK naming convention from existing scripts
- Verify the referenced table exists

---

## Multi-DB Generation

If the app supports multiple DB types (check `SMT_Application.dbtypes`):

1. Generate MariaDB version first (primary)
2. **MANDATORY: Research existing Oracle scripts in the same app BEFORE generating Oracle SQL:**
   ```sql
   SELECT s.scriptid, s.scriptname, s.scriptcontentoracle
   FROM {SMT_SCHEMA}.SMT_Script s
   WHERE s.devphaseid IN (
     SELECT devphaseid FROM {SMT_SCHEMA}.SMT_DevPhase WHERE appid = <APP_ID>
   )
   AND s.scriptcontentoracle IS NOT NULL
   AND s.scriptcontentoracle != ''
   AND s.scriptname LIKE '%<SIMILAR_ACTION>%'
   ORDER BY s.scriptid DESC
   LIMIT 3
   ```
3. Generate Oracle version matching the patterns found — NOT from generic Oracle knowledge
4. Key syntax differences to verify against actual scripts:
   - No backticks — check if team uses double quotes or no quotes
   - `SEQUENCE` + trigger for auto-increment (instead of `AUTO_INCREMENT`)
   - `VARCHAR2` instead of `VARCHAR` — verify from existing scripts
   - `TIMESTAMP` vs `DATETIME` — check what the team uses
   - `NUMBER(10)` vs `INT` — match existing column types
   - `INSERT ALL ... SELECT * FROM DUAL` vs `INSERT INTO` — match existing inserts
   - No `IF NOT EXISTS` on some statements — check how team handles idempotency in Oracle

**NEVER generate Oracle SQL by guessing.** If no Oracle scripts exist for the app, check scripts from other apps in the same SMT instance. Only fall back to templates in smt-reference.md as a last resort.

---

## Script Name and Description Guidelines

**Script Name** — derived from existing patterns. Look at how other scripts in the app are named:
- "Create table AS_GSS_VENDOR_SCORECARD"
- "Add VENDOR_SCORE column to AS_GSS_EVALUATION"
- "Create or replace view AS_GSS_EVALUATION_SUMMARY"
- "Drop FK on AS_RM_QNM_A_T_QUESTION_PRECEDENT_SET"

**Script Description** — one sentence explaining the business reason:
- "New table to store vendor scorecard calculations per evaluation phase"
- "Update Column Date Type"
- "Drop the question precedent set FK on AS_RM_QNM_A_T_QUESTION_PRECEDENT_SET"

---

## What NOT to Do

- Do NOT generate SQL from generic textbook patterns
- Do NOT assume column naming conventions without checking existing tables
- Do NOT assume backtick/quoting style without checking existing scripts
- Do NOT generate a trigger in the same script as a CREATE TABLE
- Do NOT forget `IF NOT EXISTS` / `CREATE OR REPLACE` for idempotency
- Do NOT generate Oracle SQL by guessing — always check existing Oracle scripts first
- Do NOT add columns that already exist (check Step 3 first)
- Do NOT use `DELIMITER` unless the existing scripts in the app use it
