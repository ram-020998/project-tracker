# DB Explore Workflow

Explore the database schema for an Appian application using SMT's Data Dictionary. This skill answers questions about tables, columns, views, row counts, relationships, and missing documentation.

---

## Triggers

Activate this skill when the user asks:
- "What tables does GSS have?"
- "Show me the schema for AS_GSS_EVALUATION"
- "What columns does this table have?"
- "How many rows in the evaluation table?"
- "What views exist for AM?"
- "Show me the data model for Source Selection"
- "Which tables are missing comments?"
- "What's the FK relationship between these tables?"

---

## Prerequisites

Before running any queries, perform the mandatory session init and resolve the application context:

### Step 0: Schema Detection (MANDATORY — see smt-reference.md Section 3)

```sql
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1
```
If count > 0 → use `DevTools.SMT_*`. Otherwise → use `Appian.SMT_*`.

### Step 1: Resolve Application

1. Identify the app prefix from the user's request (e.g., "GSS" → `AS_GSS`, "AM" → `AS_AM`, "RM" → `AS_RM`)
2. Confirm the app exists in SMT:

```sql
SELECT appid, appname, appdbtableprefix, dbtypes
FROM {SMT_SCHEMA}.SMT_Application
WHERE appdbtableprefix = '<PREFIX>'
LIMIT 1
```

If the app is not found in SMT, tell the user: "This application is not registered in SMT. The Data Dictionary is only available for SMT-managed applications." Then fall back to using `DESCRIBE Appian.<TABLE_NAME>` for basic schema info.

---

## Strategies

### Strategy 1: List All Tables for an Application

When the user asks "What tables does X have?" or "Show me the schema for X":

```sql
SELECT TABLE_NAME, TABLE_TYPE, TABLE_ROWS, TABLE_COMMENT
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
ORDER BY TABLE_NAME
LIMIT 100
```

**Present results as:**
- Group by TABLE_TYPE (BASE TABLE vs VIEW)
- Show row counts for context (helps identify large/important tables)
- Flag tables with empty TABLE_COMMENT as "Missing description"
- If more than 30 tables, summarize by pattern (e.g., "15 audit tables (A_R_ prefix), 8 core tables, 4 views")

### Strategy 2: Show Columns for a Specific Table

When the user asks "What columns does X have?" or "Show me the schema for table X":

```sql
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_COMMENT, EXTRA
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME = '<TABLE_NAME>'
ORDER BY ORDINAL_POSITION
LIMIT 100
```

**Present results as:**
- Show column name, type, nullable, key type (PK/FK/UNI), and comment
- Highlight the primary key
- Identify likely foreign keys (columns ending in `_ID` that aren't the PK)
- Flag columns with empty COLUMN_COMMENT as "Missing description"
- Note any `auto_increment` columns

### Strategy 3: Find Relationships Between Tables

When the user asks "How are these tables related?" or "What references X?":

1. First get the columns of the target table:
```sql
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_KEY
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME = '<TABLE_NAME>'
AND COLUMN_KEY IN ('PRI', 'MUL')
ORDER BY ORDINAL_POSITION
LIMIT 50
```

2. For each FK column (COLUMN_KEY = 'MUL' and name ends in `_ID`), infer the referenced table:
   - Column `VENDOR_ID` likely references `<APP_PREFIX>_VENDOR`
   - Column `EVALUATION_ID` likely references `<APP_PREFIX>_EVALUATION`
   - Column `DEVPHASEID` likely references `SMT_DevPhase`

3. Verify the referenced table exists:
```sql
SELECT TABLE_NAME FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME = '<INFERRED_TABLE>'
LIMIT 1
```

**Present as:** A relationship summary showing parent → child connections.

### Strategy 4: Show Views for an Application

When the user asks "What views exist?" or "Show me the views":

```sql
SELECT TABLE_NAME, TABLE_COMMENT
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND TABLE_TYPE = 'VIEW'
ORDER BY TABLE_NAME
LIMIT 50
```

### Strategy 5: Show Large Tables (Data Volume)

When the user asks "Which tables are biggest?" or "What's the data volume?":

```sql
SELECT TABLE_NAME, TABLE_ROWS, AVG_ROW_LENGTH,
       ROUND(TABLE_ROWS * AVG_ROW_LENGTH / 1024 / 1024, 2) as estimated_size_mb
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_ROWS DESC
LIMIT 20
```

### Strategy 6: Find Tables/Columns Missing Comments

When the user asks "What's missing documentation?" or "Which tables need comments?":

**Tables missing comments:**
```sql
SELECT TABLE_NAME, TABLE_ROWS
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND (TABLE_COMMENT IS NULL OR TABLE_COMMENT = '')
ORDER BY TABLE_ROWS DESC
LIMIT 30
```

**Columns missing comments (for a specific table):**
```sql
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_KEY
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME = '<TABLE_NAME>'
AND (COLUMN_COMMENT IS NULL OR COLUMN_COMMENT = '')
ORDER BY ORDINAL_POSITION
LIMIT 50
```

**Summary across all tables:**
```sql
SELECT 
  COUNT(DISTINCT CASE WHEN TABLE_COMMENT = '' OR TABLE_COMMENT IS NULL THEN TABLE_NAME END) as tables_missing_comments,
  COUNT(DISTINCT TABLE_NAME) as total_tables
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
LIMIT 1
```

### Strategy 7: Compare Table Structure Across DB Types

When the user asks about Oracle vs MariaDB differences, or multi-DB structure:

First check what DB types the app supports:
```sql
SELECT dbtypes FROM Appian.SMT_Application WHERE appdbtableprefix = '<APP_PREFIX>' LIMIT 1
```

Then use `DESCRIBE Appian.<TABLE_NAME>` for the MariaDB structure (since SMT_InformationViewTables is MariaDB only). For Oracle structure, check the script content:
```sql
SELECT scriptname, LEFT(scriptcontentoracle, 500) as oracle_preview
FROM Appian.SMT_Script
WHERE devphaseid = <CURRENT_DEV_PHASE_ID>
AND scriptname LIKE '%<TABLE_NAME>%'
LIMIT 5
```

### Strategy 8: Search for a Column Across Tables

When the user asks "Which tables have a VENDOR_ID column?" or "Where is X used?":

```sql
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, COLUMN_KEY
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND COLUMN_NAME LIKE '%<SEARCH_TERM>%'
ORDER BY TABLE_NAME
LIMIT 30
```

---

## Presentation Guidelines

- Always show the application name and prefix at the top of the response
- Use tables for structured data (columns, types, etc.)
- Flag missing comments with a warning marker
- Show row counts to give context about table importance
- When showing relationships, use arrows: `EVALUATION → VENDOR (via VENDOR_ID)`
- If the Data Dictionary data seems stale (UPDATE_TIME is old), mention: "Note: Data Dictionary was last refreshed on <date>. Run 'Generate data dictionary' in SMT to update."
- For large result sets (>20 tables), summarize first, then offer to drill into specific areas

---

## Fallback: No SMT Data Dictionary

If the application is not in SMT, or `SMT_InformationViewTables` has no data for the prefix, fall back to:

```sql
-- List tables directly
SHOW TABLES FROM Appian LIKE '<APP_PREFIX>%'

-- Describe a specific table
DESCRIBE Appian.<TABLE_NAME>
```

This gives basic schema info but without row counts, comments, or the richer metadata that SMT provides.
