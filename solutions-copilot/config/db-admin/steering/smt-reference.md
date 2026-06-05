# SMT (Script Management Tool) — Complete Reference

This document is the authoritative reference for the jarvis-smt power. All SMT skills load this file as context. It contains everything the agent needs to work with SMT correctly: the data model, rules, conventions, verification requirements, and access patterns.

---

## 1. Overview

SMT (Script Management Tool) is an internal Appian developer tool for managing database SQL scripts across Appian applications. It handles the full lifecycle of schema changes: creation, review, verification, approval, and export for deployment to higher-level environments.

**Key facts:**
- SMT exists ONLY in development environments — it is never deployed to higher environments
- Target environments receive only the exported SQL files, not the SMT application itself
- SMT supports multiple database engines: MariaDB, Oracle, SQL Server, PostgreSQL
- Scripts are organized by Application and Release (Dev Phase)
- All scripts must be idempotent (re-runnable without error)
- Verification deploys scripts against a blank schema to validate correctness

**Site URL:** `https://<env>/suite/sites/smt`

---

## 2. Core Concepts

### Applications
An application in SMT represents a logical grouping of database objects (tables, views, triggers, procedures) that belong to one Appian application. Each application has:
- A unique **Application Prefix** (e.g., `AS_GSS`, `AS_AM`, `AS_RM`) used for table naming
- One or more **Supported DB Types** (MariaDB, Oracle, SQL Server, PostgreSQL)
- Optional **Dependencies** on other applications (scripts deploy in dependency order)
- A **JIRA Prefix** for linking change requests to tickets

### Dev Phases (Releases)
A Dev Phase represents a version/release of an application (e.g., "GSS v1.0", "GSS v1.1", "GSS v1.2"). Scripts are organized by release. Each release has:
- An **Internal Name** (used within SMT)
- A **Public Name** (customer-facing version name)
- A **Primary** flag indicating the current active development release
- A **Precedent** linking to the previous release (for ordering)

### Change Requests
A Change Request (CR) is the unit of work in SMT — analogous to a Pull Request for SQL. A CR:
- Contains one or more SQL scripts
- Is linked to a JIRA ticket number
- Goes through a lifecycle: OPEN → INITIAL_REVIEW → APPROVED (or REJECTED/CANCELLED)
- Must pass verification before submission
- Once closed (approved/rejected), cannot be modified

### Scripts
A script is an individual SQL file within a Change Request. Each script has:
- A name describing what it does (e.g., "Create table AS_GSS_VENDOR_SCORECARD")
- A description explaining why
- SQL content for each supported DB type (MariaDB, Oracle, etc.)
- A script type classification
- A status within the CR lifecycle


---

## 3. Database Schema

SMT uses 13 tables that may reside in EITHER the `Appian` schema or the `DevTools` schema depending on the environment. The correct schema must be detected at runtime.

### Schema Detection (REQUIRED — Run Once Per Session)

Different environments configure SMT's data source differently. Some use `Appian.SMT_*`, others use `DevTools.SMT_*`. To determine the correct schema, run this probe query at the start of any SMT workflow:

```sql
SELECT 'DevTools' as schema_name, COUNT(*) as app_count FROM DevTools.SMT_Application LIMIT 1
```

If this succeeds and returns rows, use `DevTools.SMT_*` for all SMT queries. If it fails (schema doesn't exist), fall back to `Appian.SMT_*`.

**Why this matters:** Some environments have SMT tables in BOTH schemas, but one is stale/outdated. The `DevTools` schema is typically the live one when it exists. If both exist, compare row counts — the schema with MORE rows in `SMT_Application` is the active one.

**Cache the result:** Once detected, use the same schema prefix for all subsequent SMT queries in the session. Store it mentally as `{SMT_SCHEMA}` (either `Appian` or `DevTools`).

### Detection Query Pattern
```sql
-- Step 1: Try DevTools first
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1

-- Step 2: If Step 1 fails or returns 0, use Appian
SELECT COUNT(*) as cnt FROM Appian.SMT_Application LIMIT 1

-- Step 3: If BOTH exist, compare counts — higher count = active schema
```

### Mandatory Session Init (ALL Workflows)

**Every SMT workflow MUST start with this probe before any other query.** Do not skip this step. Do not assume a schema from a previous session.

```sql
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1
```

- If this returns a count > 0 → set `{SMT_SCHEMA}` = `DevTools`
- If this errors or returns 0 → set `{SMT_SCHEMA}` = `Appian`
- Use `{SMT_SCHEMA}.SMT_*` for ALL subsequent SMT queries in the session
- Use `Appian.*` (without SMT_ prefix) for application data tables (AS_GSS_*, AS_VM_*, etc.) — these always live in the Appian schema

**Example first two queries of any session:**
```sql
-- 1. Detect schema
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1

-- 2. Now use detected schema for all SMT queries
SELECT appid, appname, appdbtableprefix FROM {SMT_SCHEMA}.SMT_Application WHERE appdbtableprefix = 'AS_VM' LIMIT 1
```

---

All tables below are accessed via `query_sql` with the detected schema prefix (e.g., `{SMT_SCHEMA}.SMT_Application`).

**⚠️ TABLE NAME FORMAT: CamelCase (NOT underscores). Use `SMT_ChangeRequest` NOT `SMT_CHANGE_REQUEST`.**

**Quick Reference — SMT Data Model:**
```
SMT_Application          → Registered apps (appid, prefix, DB types)
  └── SMT_DevPhase       → Releases per app (devphaseid, "GSS v1.2")
       └── SMT_Script    → Approved scripts (the master registry)
       └── SMT_ChangeRequest → "Pull requests" for scripts (OPEN → APPROVED → COMMITTED)
            └── SMT_ChangeRequest_Script → Individual scripts in a CR (contains the SQL)
            └── SMT_Comment → Review comments on a CR

SMT_ScriptExecutionHistory → Deployment log (which scripts ran on which env)
SMT_DataSourceConfig       → DB connection configs per environment
SMT_EnvConfig              → Environment definitions
SMT_Diff                   → Version comparisons (before/after)
SMT_UserConfig             → Per-user preferences
SMT_InformationViewTables  → Cached table metadata (from INFORMATION_SCHEMA)
SMT_InformationViewColumns → Cached column metadata (from INFORMATION_SCHEMA)
```

**Workflow:** Developer writes script → submits Change Request → reviewer approves → scripts get committed to SMT_Script → deployed via SMT_ScriptExecutionHistory

### SMT_Application
Registered applications that SMT manages scripts for.

| Column | Type | Description |
|---|---|---|
| `appid` | INT PK AUTO_INCREMENT | Unique application identifier |
| `appname` | VARCHAR(255) | Display name (e.g., "Source Selection", "Award Management") |
| `appdbtableprefix` | VARCHAR(255) | Table naming prefix (e.g., "AS_GSS", "AS_AM", "AS_RM") |
| `jiraticketprefix` | VARCHAR(50) | JIRA project key for constructing links (e.g., "GAM") |
| `precappid` | INT | Precedent application ID (dependency — this app's scripts deploy after precapp) |
| `ispublicapp` | TINYINT(1) | Whether the app is public/shared |
| `dbtypes` | VARCHAR(255) | JSON array of supported DB engines (e.g., `["MARIA_DB","ORACLE"]`) |

### SMT_DevPhase
Release versions per application. Scripts are organized by dev phase.

| Column | Type | Description |
|---|---|---|
| `devphaseid` | INT PK AUTO_INCREMENT | Unique phase identifier |
| `devphasename` | VARCHAR(255) | Internal release name (e.g., "GSS v1.2", "AM v1.1") |
| `devphasepublicname` | VARCHAR(255) | Customer-facing release name (e.g., "Source Selection 1.2") |
| `iscurrentlyprimary` | TINYINT(1) | Whether this is the active development release (true = current) |
| `appid` | INT FK → SMT_Application | Which application this release belongs to |
| `precdevphaseid` | INT | Previous dev phase ID (for script ordering across releases) |

### SMT_ChangeRequest
Change requests — the "pull requests" for SQL scripts.

| Column | Type | Description |
|---|---|---|
| `changeid` | INT PK AUTO_INCREMENT | Unique CR identifier |
| `changename` | VARCHAR(255) | CR title (typically JIRA ticket + description) |
| `changedesc` | LONGTEXT | Detailed description of the change |
| `changestatus` | VARCHAR(255) | Status: `OPEN`, `INITIAL_REVIEW`, `APPROVED`, `COMMITTED`, `CANCELLED` |
| `devphaseid` | INT FK → SMT_DevPhase | Target release for these scripts |
| `jiraticketnumber` | INT | Linked JIRA ticket number (numeric part only) |
| `submittedby` | VARCHAR(255) | Username who submitted the CR |
| `submittedon` | DATETIME | Submission timestamp |
| `reviewedby` | VARCHAR(255) | Username who reviewed (approved/rejected) |
| `reviewedon` | DATETIME | Review timestamp |
| `updatedby` | VARCHAR(255) | Last modifier |
| `updatedon` | DATETIME | Last modification timestamp |

### SMT_ChangeRequest_Script
Individual scripts within a change request. Contains the actual SQL content.

| Column | Type | Description |
|---|---|---|
| `changescriptid` | INT PK AUTO_INCREMENT | Unique script-in-CR identifier |
| `changeid` | INT FK → SMT_ChangeRequest | Parent change request |
| `scriptid` | INT FK → SMT_Script | Link to master script (if modifying existing) |
| `scriptname` | VARCHAR(255) | Script title (e.g., "Create table AS_GSS_VENDOR_SCORECARD") |
| `scriptdesc` | VARCHAR(255) | Description of what the script does and why |
| `scriptcontentmariadb` | LONGTEXT | **The actual MariaDB SQL content** |
| `scriptcontentoracle` | LONGTEXT | **The actual Oracle SQL content** |
| `scriptstatus` | VARCHAR(255) | Status within the CR (e.g., "INITIAL_REVIEW") |
| `scripttype` | INT | Script type classification |
| `jiraticketnumber` | INT | JIRA ticket link |

### SMT_Script
Master script registry. Contains the approved/committed version of scripts.

| Column | Type | Description |
|---|---|---|
| `scriptid` | INT PK AUTO_INCREMENT | Unique script identifier |
| `scriptname` | VARCHAR(255) | Script name |
| `scriptdesc` | VARCHAR(255) | Description |
| `scriptcontentmariadb` | LONGTEXT | Approved MariaDB SQL content |
| `scriptcontentoracle` | LONGTEXT | Approved Oracle SQL content |
| `devphaseid` | INT FK → SMT_DevPhase | Which release this script belongs to |
| `ishotfix` | TINYINT(1) | Whether this is a hotfix script |
| `scriptstatus` | VARCHAR(255) | Current status |
| `scripttype` | INT | Type classification |
| `lastmodifiedby` | VARCHAR(255) | Last editor username |
| `lastmodifiedon` | DATETIME | Last edit timestamp |

### SMT_ScriptExecutionHistory
Deployment execution log. Tracks which scripts have been run on target environments.

| Column | Type | Description |
|---|---|---|
| `scriptexecuteid` | INT PK AUTO_INCREMENT | Execution record ID |
| `executeid` | INT | Execution batch identifier |
| `releaseid` | INT | Release identifier |
| `releasename` | VARCHAR(255) | Release name (e.g., "Script Management 1.0") |
| `scriptid` | INT | Which script was executed |
| `scriptname` | VARCHAR(255) | Script name at time of execution |
| `scriptversionid` | INT | Version of the script that was executed |
| `starttime` | TIMESTAMP | Execution start time |
| `endtime` | TIMESTAMP | Execution end time (null if skipped) |
| `executetime` | INT | Duration in milliseconds |
| `issuccess` | TINYINT(1) | Whether execution succeeded |
| `executionskipped` | TINYINT(1) | Whether execution was skipped (already run previously) |

### SMT_Comment
Review comments on change requests.

| Column | Type | Description |
|---|---|---|
| `commentid` | INT PK AUTO_INCREMENT | Comment identifier |
| `changeid` | INT FK → SMT_ChangeRequest | Which CR this comment belongs to |
| `comment` | LONGTEXT | Comment text |
| `lastmodifiedby` | VARCHAR(255) | Who wrote the comment |
| `lastmodifiedon` | DATETIME | When the comment was written |

### SMT_Diff
Script version comparisons (before/after).

| Column | Type | Description |
|---|---|---|
| `jsondatetime` | VARCHAR(255) PK | Timestamp key for the diff |
| `original` | LONGTEXT | Previous version of the script |
| `new` | LONGTEXT | New version of the script |

### SMT_InformationViewTables
Cached table metadata from INFORMATION_SCHEMA. Used by the Data Dictionary feature.

| Column | Type | Description |
|---|---|---|
| `TABLE_IDENTIFIER` | VARCHAR(129) | Composite key (schema.table) |
| `TABLE_NAME` | VARCHAR(64) | Table name |
| `TABLE_SCHEMA` | VARCHAR(64) | Schema name |
| `TABLE_TYPE` | VARCHAR(64) | `BASE TABLE` or `VIEW` |
| `TABLE_ROWS` | BIGINT UNSIGNED | Approximate row count |
| `AVG_ROW_LENGTH` | BIGINT UNSIGNED | Average row size in bytes |
| `CREATE_TIME` | DATETIME | When the table was created |
| `UPDATE_TIME` | DATETIME | Last DDL modification time |
| `TABLE_COMMENT` | VARCHAR(2048) | Developer-written table description |

### SMT_InformationViewColumns
Cached column metadata from INFORMATION_SCHEMA. Used by the Data Dictionary feature.

| Column | Type | Description |
|---|---|---|
| `COLUMN_IDENTIFIER` | VARCHAR(194) | Composite key |
| `TABLE_IDENTIFIER` | VARCHAR(129) | Parent table identifier |
| `TABLE_NAME` | VARCHAR(64) | Parent table name |
| `COLUMN_NAME` | VARCHAR(64) | Column name |
| `ORDINAL_POSITION` | BIGINT UNSIGNED | Column order (1-based) |
| `IS_NULLABLE` | VARCHAR(3) | `YES` or `NO` |
| `COLUMN_TYPE` | LONGTEXT | Full type definition (e.g., `int(11)`, `varchar(255)`, `longtext`) |
| `COLUMN_KEY` | VARCHAR(3) | `PRI` (primary key), `MUL` (foreign key/index), `UNI` (unique), or empty |
| `COLUMN_COMMENT` | VARCHAR(1024) | Developer-written column description |
| `EXTRA` | VARCHAR(80) | Additional info (e.g., `auto_increment`) |

### SMT_DataSourceConfig
Maps database types to their data source UUIDs for verification.

| Column | Type | Description |
|---|---|---|
| `dbtype` | VARCHAR(255) PK | Database type (e.g., "MARIA_DB", "ORACLE") |
| `dsuuid` | VARCHAR(255) | Appian data source UUID for verification |

### SMT_EnvConfig
Environment configuration for deployment targets.

| Column | Type | Description |
|---|---|---|
| `envid` | INT PK AUTO_INCREMENT | Environment identifier |
| `envurl` | VARCHAR(255) | Environment URL |
| `envusername` | VARCHAR(255) | Service account username |
| `envpassword` | VARCHAR(255) | Service account password (encrypted) |
| `isverificationenv` | TINYINT(1) | Whether this is the verification environment |
| `iscurrentenv` | TINYINT(1) | Whether this is the current environment |

### SMT_Deployment
Deployment tracking records.

| Column | Type | Description |
|---|---|---|
| `deploymentid` | INT PK AUTO_INCREMENT | Deployment identifier |


---

## 4. Change Request Lifecycle

### State Machine

```
OPEN → INITIAL_REVIEW → APPROVED → COMMITTED
                      ↘ REJECTED
OPEN → CANCELLED
```

### Workflow Steps

**Creating a Change Request:**
1. Navigate to Scripts tab, select correct Application and Release
2. Click "Start Change Request for \<App\> - \<Release\>"
3. If modifying an existing script: expand it and edit in place (Diff section appears showing changes)
4. If adding a new script: click "Add Standard Script"
5. For each script, provide:
   - **Script Name** — describes the action and target object (e.g., "Create table AS_AM_TABLEC")
   - **Script Description** — general description of purpose
   - **Script Type** — categorization of the SQL type
   - **Script Content** — the actual SQL for each supported DB type
6. Multiple scripts can be added per CR (e.g., CREATE TABLE + CREATE VIEW for same ticket)
7. Fill Change Request metadata:
   - **Name** — JIRA ticket number
   - **Description** — why these scripts are needed
8. Click **Verify Script** to run verification
9. Poll "Refresh Verification" until verification completes
10. If verification returns Success → click **Submit Change Request**
11. Confirm submission

**Modifying a Change Request:**
- Only OPEN change requests can be modified (closed CRs are immutable)
- Click "Modify Change Request" on the CR detail screen
- Edit scripts directly
- Re-verify after modifications
- Click "Submit Change Request Modification"

**Cancelling a Change Request:**
- Select the open CR on the Dashboard tab
- Click "Cancel Change Request" button
- Confirm cancellation

**Reviewing a Change Request (Admin only):**
- Only members of **SMT Admins** group can approve/reject
- Open the CR from the Dashboard "Open Change Requests" section
- Review scripts, add comments in the Conversation section
- Click **Reject** or **Approve**
- If approved: scripts move to Approved Scripts and appear on the Scripts tab

**Removing a Script:**
- Removal is done via a new Change Request (not direct deletion)
- On Scripts tab, expand the script to remove → click Remove button (highlights in red)
- Fill CR metadata: Name (JIRA ticket), Description (why script is being removed)
- Verify → Submit → Approve (same lifecycle as adding)

### Important Rules
- One Change Request per JIRA ticket (group related scripts together)
- Closed CRs cannot be modified — create a new CR for further changes
- Scripts can only be added through Change Requests (no direct insertion)
- Verification is mandatory before submission
- Only SMT Admins can approve/reject

---

## 5. Script Rules

### Pattern-First Generation (MANDATORY)

**NEVER generate SQL from general knowledge.** Follow this strict fallback chain:

| Priority | Source | When to Use | Transparency |
|---|---|---|---|
| **Level 1** | App-specific patterns | ALWAYS try first — query existing scripts in the SAME app | "Generated from existing [App] [action] pattern (script #XXXX)" |
| **Level 2** | Cross-app patterns | Only if Level 1 finds nothing | "No [App] patterns found. Used [OtherApp] pattern (script #XXXX)" |
| **Level 3** | SMT templates (Section 7) | Only if Level 1 AND Level 2 find nothing | "No existing patterns found. Used SMT [template name] template." |
| **Level 4** | NEVER | Generic SQL from general knowledge is NEVER acceptable | — |

**How to research patterns:**
```sql
-- Find similar scripts in the same app (replace <ACTION> with CREATE, INSERT, ALTER, etc.)
SELECT s.scriptid, s.scriptname, s.scriptcontentmariadb, s.scriptcontentoracle
FROM {SMT_SCHEMA}.SMT_Script s
WHERE s.devphaseid IN (
  SELECT devphaseid FROM {SMT_SCHEMA}.SMT_DevPhase WHERE appid = <APP_ID>
)
AND s.scriptcontentmariadb LIKE '%<ACTION>%'
ORDER BY s.scriptid DESC
LIMIT 5
```

**If Level 3 (template) is used, explicitly tell the user:**
> "No existing patterns found for this type of script in [App] or other apps. Generated from SMT template. Please verify this matches your team's conventions before submitting."

### Multi-DB Type Enforcement (MANDATORY)

Before generating ANY script, check what DB types the app supports:

```sql
SELECT dbtypes FROM {SMT_SCHEMA}.SMT_Application WHERE appdbtableprefix = '<PREFIX>' LIMIT 1
```

- If `dbtypes` = `["MARIA_DB","ORACLE"]` → you MUST generate BOTH versions
- If `dbtypes` = `["MARIA_DB"]` → generate MariaDB only
- Research patterns for EACH DB type separately (the Oracle version may follow different conventions than MariaDB in the same app)
- NEVER skip a supported DB type
- NEVER assume Oracle syntax from MariaDB patterns — always query `scriptcontentoracle` from existing scripts

### Idempotency (CRITICAL)

All scripts MUST be re-runnable without error. The verification framework runs all scripts TWICE to enforce this.

**For tables:**
```sql
-- CORRECT: Idempotent
CREATE TABLE IF NOT EXISTS `AS_GSS_VENDOR_SCORECARD` (
  `SCORECARD_ID` int(11) NOT NULL AUTO_INCREMENT,
  `VENDOR_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`SCORECARD_ID`)
);

-- WRONG: Will fail on second run
CREATE TABLE `AS_GSS_VENDOR_SCORECARD` (
  `SCORECARD_ID` int(11) NOT NULL AUTO_INCREMENT,
  `VENDOR_ID` int(11) DEFAULT NULL,
  PRIMARY KEY (`SCORECARD_ID`)
);
```

**For columns (ALTER TABLE):**
```sql
-- MariaDB: Use IF NOT EXISTS for adding columns
ALTER TABLE `AS_GSS_EVALUATION` ADD COLUMN IF NOT EXISTS `VENDOR_SCORE` DECIMAL(5,2);

-- For modifying columns (inherently idempotent):
ALTER TABLE `AS_GSS_EVALUATION` MODIFY `DUE_DATE` datetime;
```

**For views:**
```sql
-- CORRECT: Always use CREATE OR REPLACE
CREATE OR REPLACE VIEW AS_GSS_EVALUATION_SUMMARY AS
SELECT ...;

-- WRONG: Will fail if view exists
CREATE VIEW AS_GSS_EVALUATION_SUMMARY AS
SELECT ...;
```

**For stored procedures, functions, and triggers:**
```sql
-- CORRECT: DROP then CREATE (these ALWAYS re-run regardless of execution history)
DROP PROCEDURE IF EXISTS AS_GSS_SP_CALCULATE_SCORE;
CREATE PROCEDURE AS_GSS_SP_CALCULATE_SCORE()
BEGIN
  ...
END;

-- OR use CREATE OR REPLACE where supported:
CREATE OR REPLACE PROCEDURE AS_GSS_SP_CALCULATE_SCORE()
BEGIN
  ...
END;
```

**For indexes:**
```sql
-- MariaDB: Use IF NOT EXISTS
CREATE INDEX IF NOT EXISTS idx_vendor_id ON `AS_GSS_EVALUATION` (`VENDOR_ID`);
```

**For foreign keys:**
```sql
-- MariaDB: Drop IF EXISTS before adding
ALTER TABLE `AS_GSS_EVALUATION` DROP FOREIGN KEY IF EXISTS fk_eval_vendor;
ALTER TABLE `AS_GSS_EVALUATION` ADD CONSTRAINT fk_eval_vendor 
  FOREIGN KEY (`VENDOR_ID`) REFERENCES `AS_GSS_VENDOR` (`VENDOR_ID`);
```

### Idempotency Framework (ScriptExecutionHistory)

SMT tracks script execution via a `<App Acronym>_ScriptExecutionHistory` table:
- Each script has a unique `scriptId`
- On deployment: if `scriptId` exists in history → `executionskipped = 1` (skipped)
- **EXCEPTION:** Stored procedures, functions, and triggers ALWAYS re-run regardless of execution history
- Best practice: Always separate procedure/trigger creation into their own scripts

### Naming Conventions

**Script names must:**
- Describe the action AND the target object
- Use the application's table prefix
- Be specific enough to understand without reading the SQL

**Good names:**
- "Create table AS_GSS_VENDOR_SCORECARD"
- "Add VENDOR_SCORE column to AS_GSS_EVALUATION"
- "Create index on AS_GSS_EVALUATION.VENDOR_ID"
- "Create or replace view AS_GSS_EVALUATION_SUMMARY"
- "Drop FK on AS_RM_QNM_A_T_QUESTION_PRECEDENT_SET"

**Bad names:**
- "New table" (what table?)
- "Update" (update what?)
- "Fix" (fix what?)
- "Script 1" (meaningless)

### Script Separation Rules

- **One logical change per script** — don't mix CREATE TABLE with CREATE TRIGGER
- **Stored procedures/triggers in their own scripts** — they always re-run, so isolate them
- **Tables before views** — views reference tables, so tables must exist first
- **Multiple scripts per CR is fine** — a JIRA ticket might need CREATE TABLE + CREATE VIEW + CREATE TRIGGER = 3 scripts

### DELIMITER Keyword

- If a script contains `DELIMITER`, it must be idempotent without relying on the idempotent framework
- The verification framework may not handle DELIMITER correctly
- Best practice: avoid DELIMITER by using `CREATE OR REPLACE` patterns instead

### Multi-DB Considerations

When an application supports multiple DB types (e.g., MariaDB + Oracle):
- Developers must submit script content for EACH enabled DB type
- Syntax differences between engines must be handled:
  - MariaDB: backtick quoting (\`TABLE_NAME\`), `AUTO_INCREMENT`, `IF NOT EXISTS`
  - Oracle: no backticks, `SEQUENCE` for auto-increment, different `ALTER TABLE` syntax
  - Oracle: column name `DESC` is a reserved word — use `DESCRIPTION` instead
  - Oracle: `TIMESTAMP` vs MariaDB `DATETIME`
- Both scripts should achieve the same logical result

---

## 6. Verification Framework

### How Verification Works

The verification framework runs ALL scripts up to the current one, in the schemas configured as verification data sources. It validates three things:

1. **Syntactically correct** — Runs scripts on a blank validation schema. Any SQL syntax error is caught via the error messaging returned.

2. **Re-runnable** — Runs all SQL scripts TWICE in the validation environment. This ensures scripts are idempotent. If a script fails on the second run, it's not re-runnable.

3. **Correct dependency order** — Runs all approved scripts in order. Validates that the currently viewed script has the correct dependencies (e.g., a table is created before a view that references it).

### Common Verification Failures

| Failure | Cause | Fix |
|---|---|---|
| Invalid SQL syntax | Typo, wrong keyword, missing comma | Fix the SQL |
| `DELIMITER` not idempotent | Script uses DELIMITER but can't re-run | Use `CREATE OR REPLACE` instead |
| `CREATE STORED PROCEDURE/FUNCTION/TRIGGER` without DROP | These always re-run and will fail if they exist | Add `DROP IF EXISTS` before CREATE, or use `CREATE OR REPLACE` |
| Missing dependency | Script references a table from another app not configured as dependency | Add the other app as a dependency in Configuration |
| Table/column doesn't exist | View references a table that hasn't been created yet | Ensure table script comes before view script in ordering |

### Diagnosing Verification Errors

1. Download the error log → search for `Caused by: java.sql.SQLException` — this gives the actual SQL error
2. Download the verification file → manually re-run on the verification schema → find where it breaks by running portions of the file

### Verification Data Sources

- Each DB type needs its own dedicated verification schema
- **WARNING:** The verification schema is TRUNCATED AND REPLACED during verification — NEVER use a production or shared schema
- Connected System UUIDs are stored in `SMT_DataSourceConfig`


---

## 7. Script Templates

SMT provides 20 script templates organized into 6 categories, available per DB type (MariaDB, Oracle, SqlServer). Templates are defined in the expression rule `SMT_ENUM_SCRIPT_TYPES_AND_TEMPLATES` and accessed via the Templates tab or the `SMT_WA_GET_TemplateCodeBlock` Web API.

### Template Categories

| Category | Templates |
|---|---|
| **CREATE** | Create reference table, Create transactional table, Create view, Create trigger, Create procedure, Add column, Add index, Add constraint |
| **DATA** | Insert reference data, Data update, Data migration |
| **ALTER** | Alter/rename table, Alter/rename column, Set auto increment |
| **DROP** | Drop index, Drop constraint, Truncate/delete/drop |
| **COMMENT** | Data dictionary (table and column comments) |
| **AUXILIARY** | Show table definition, Show view definition, Clone table, Copy table data, Toggle foreign key checks |
| **OTHER** | Catch-all for anything else |

### CREATE Templates

#### Create Reference Table (id: 24)
For reference/configuration tables with static data. Includes `CROSS_ENVIRONMENT_UUID` column with triggers for cross-environment consistency.

**MariaDB:**
```sql
-- Create the table (wrapped in IF NOT EXISTS since this will be re-run each time due to the triggers)
CREATE TABLE IF NOT EXISTS <table_name> (
  <primary_col> INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '<Primary key for table>',
  CROSS_ENVIRONMENT_UUID VARCHAR(255) UNIQUE COMMENT 'A unique value per row which is identical across all environments',
  <str_col> VARCHAR(255) DEFAULT NULL COMMENT '<default string column>',
  <datetime_col> DATETIME DEFAULT NULL COMMENT '<default date and time column>',
  <date_col> DATE DEFAULT NULL COMMENT '<default date column>',
  <bool_col> TINYINT(1) DEFAULT NULL COMMENT '<default boolean column>',
  <double_col> DOUBLE DEFAULT NULL COMMENT '<default double column>'
) AUTO_INCREMENT=1 COMMENT '<example table description>';

-- Triggers for cross environment uuid
DELIMITER ;

CREATE OR REPLACE TRIGGER <table_name>_IN BEFORE INSERT ON <table_name>
  FOR EACH ROW
  SET NEW.CROSS_ENVIRONMENT_UUID =
  IF(NEW.CROSS_ENVIRONMENT_UUID IS NULL OR LENGTH(NEW.CROSS_ENVIRONMENT_UUID) = 0, UUID(), NEW.CROSS_ENVIRONMENT_UUID);

CREATE OR REPLACE TRIGGER <table_name>_UP BEFORE UPDATE ON <table_name>
  FOR EACH ROW SET NEW.CROSS_ENVIRONMENT_UUID = OLD.CROSS_ENVIRONMENT_UUID;
```

**Oracle:**
```sql
CREATE TABLE <table_name> (
  <primary_col> NUMBER(10),
  CROSS_ENVIRONMENT_UUID VARCHAR2(255),
  <str_col> VARCHAR2(255) DEFAULT NULL,
  <datetime_col> TIMESTAMP DEFAULT NULL,
  <date_col> DATE DEFAULT NULL,
  <bool_col> NUMBER(1) DEFAULT NULL,
  <double_col> FLOAT DEFAULT NULL,
  PRIMARY KEY(<primary_col>)
);

ALTER TABLE <table_name> ADD CONSTRAINT <table_name>_UQ UNIQUE (CROSS_ENVIRONMENT_UUID);

-- NOTE: Triggers must be in their own SMT script
CREATE OR REPLACE TRIGGER <table_name>_IN BEFORE INSERT ON <table_name> FOR EACH ROW
  BEGIN
    IF LENGTH(:NEW.CROSS_ENVIRONMENT_UUID) = 0 OR :NEW.CROSS_ENVIRONMENT_UUID IS NULL THEN
      :NEW.CROSS_ENVIRONMENT_UUID := SYS_GUID();
    END IF;
  END;
/

CREATE OR REPLACE TRIGGER <table_name>_UP BEFORE UPDATE ON <table_name> FOR EACH ROW
  BEGIN
    :NEW.CROSS_ENVIRONMENT_UUID := :OLD.CROSS_ENVIRONMENT_UUID;
  END;
/

CREATE SEQUENCE <table_name>_SQ START WITH 1 INCREMENT BY 1;
COMMENT ON TABLE <table_name> IS '<Table description>';
```

**Notes:**
- Auto-increment should start at 100,000 for reference tables (allows shipping additional rows to customer environments)
- `CROSS_ENVIRONMENT_UUID` ensures the same row has the same UUID across all environments
- Oracle triggers MUST be in a separate SMT script

#### Create Transactional Table (id: 25)
For business/runtime data tables. No pre-inserted data recommended.

**MariaDB:**
```sql
CREATE TABLE <table_name> (
  <primary_col> INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '<Primary key for table>',
  <str_col> VARCHAR(255) DEFAULT NULL COMMENT '<description>',
  <datetime_col> DATETIME DEFAULT NULL COMMENT '<description>',
  <date_col> DATE DEFAULT NULL COMMENT '<description>',
  <bool_col> TINYINT(1) DEFAULT NULL COMMENT '<description>',
  <double_col> DOUBLE DEFAULT NULL COMMENT '<description>'
) AUTO_INCREMENT=1 COMMENT '<table description>';
```

**Oracle:**
```sql
CREATE TABLE <table_name> (
  <primary_col> NUMBER(10),
  <str_col> VARCHAR2(255) DEFAULT NULL,
  <datetime_col> TIMESTAMP DEFAULT NULL,
  <date_col> DATE DEFAULT NULL,
  <bool_col> NUMBER(1) DEFAULT NULL,
  <double_col> FLOAT DEFAULT NULL,
  PRIMARY KEY(<primary_col>)
);

CREATE SEQUENCE <table_name>_SQ START WITH 1 INCREMENT BY 1;
COMMENT ON TABLE <table_name> IS '<Table description>';
COMMENT ON COLUMN <table_name>.<primary_col> IS '<Primary key for table>';
```

#### Create View (id: 2)
Uses CREATE OR REPLACE for idempotency.

**MariaDB / Oracle (same syntax):**
```sql
CREATE OR REPLACE VIEW <view_name> AS
SELECT
  <a>.<col1> AS <column1>,
  <a>.<col2> AS <column2>,
  <b>.<col3> AS <column3>
FROM <table_a> <a>
JOIN <table_b> <b> ON <a>.<col1> = <b>.<col5>;
```

**Note:** Keep views as simple as possible for performance and maintenance.

#### Create Trigger (id: 3)
ALWAYS re-runs. Must be in its own script.

**MariaDB:**
```sql
DROP TRIGGER IF EXISTS <trigger_name>;

DELIMITER $$
CREATE TRIGGER <trigger_name> BEFORE <INSERT|UPDATE> ON <table_name> FOR EACH ROW
BEGIN
  DECLARE <var1> <var1_type>;
  IF <CONDITION> THEN
    SET NEW.<col_name> = 'some value';
  END IF;
END$$
DELIMITER ;
```

**Oracle:**
```sql
CREATE OR REPLACE TRIGGER <trigger_name> BEFORE <INSERT|UPDATE> ON <table_name> FOR EACH ROW
  DECLARE
    <var1> <var1_type>;
BEGIN
  IF <CONDITION> THEN
    :NEW.<col_name> := 'some value';
  END IF;
END;
/
```

#### Create Procedure (id: 4)
ALWAYS re-runs. Must be in its own script. Useful for conditional structure changes and data migrations.

**MariaDB:**
```sql
DROP PROCEDURE IF EXISTS <procedure_name>;

DELIMITER $$
CREATE PROCEDURE <procedure_name> (IN <input_var1> <input_var1_type>)
BEGIN
  <DO SOMETHING>
END $$
DELIMITER ;
```

**Oracle:**
```sql
CREATE OR REPLACE PROCEDURE <procedure_name> (<input_var1> IN <input_var1_type>)
IS
BEGIN
  <DO SOMETHING>
END;
/
```

#### Add Column (id: 5)

**MariaDB:**
```sql
-- Column type examples:
-- VARCHAR(255) DEFAULT NULL -- text
-- INT(11) DEFAULT NULL -- integer
-- TINYINT(1) DEFAULT NULL -- boolean
-- DATETIME DEFAULT NULL -- datetime
-- DATE DEFAULT NULL -- date
-- DOUBLE DEFAULT NULL -- decimal

ALTER TABLE <table_name> ADD COLUMN <new_column_name> <column_definition> COMMENT '<column comment>' AFTER <existing_column_name>;
```

**Oracle:**
```sql
-- Column type examples:
-- VARCHAR2(255) DEFAULT NULL -- text
-- NUMBER(10) DEFAULT NULL -- integer
-- NUMBER(1) DEFAULT NULL -- boolean
-- TIMESTAMP DEFAULT NULL -- datetime
-- DATE DEFAULT NULL -- date
-- FLOAT DEFAULT NULL -- decimal

ALTER TABLE <table_name> ADD <new_column_name> <column_definition>;
COMMENT ON COLUMN <table_name>.<new_column_name> IS '<column comment>';
```

**Note:** Specify AFTER clause in MariaDB to control column position. Column comments are strongly recommended.

#### Add Index (id: 6)

**MariaDB:**
```sql
ALTER TABLE <table_name> ADD INDEX <index_name> (<column_name>);
```

**Oracle:**
```sql
CREATE INDEX <index_name> ON <table_name> (<column_name>);
```

**Note:** Add indexes to high-cardinality columns that are queried or joined on. KEY and INDEX are synonyms in MariaDB.

#### Add Constraint (id: 7)
Foreign key constraint. Automatically adds an index in MariaDB (but NOT in Oracle).

**MariaDB:**
```sql
ALTER TABLE <table_name> ADD CONSTRAINT <constraint_name>
  FOREIGN KEY (<column_name>) REFERENCES <reference_table_name> (<reference_table_column_name>);
```

**Oracle:**
```sql
ALTER TABLE <table_name> ADD CONSTRAINT <constraint_name>
  FOREIGN KEY (<column_name>) REFERENCES <reference_table_name> (<reference_table_column_name>);

CREATE INDEX <index_name> ON <table_name> (<column_name>);
-- NOTE: Oracle does NOT automatically add indexes to foreign-keyed columns
```

### DATA Templates

#### Insert Reference Data (id: 11)
Requires primary key and CROSS_ENVIRONMENT_UUID. Do NOT insert into transactional tables.

**MariaDB:**
```sql
INSERT [IGNORE] INTO <table_name> (<primary_key>, CROSS_ENVIRONMENT_UUID, <col3>, <col4>) VALUES
(1, MD5('<table_name>_1'), 'some value 1', CURRENT_TIMESTAMP),
(2, MD5('<table_name>_2'), 'some value 2', CURRENT_TIMESTAMP),
(3, MD5('<table_name>_3'), 'some value 3', CURRENT_TIMESTAMP);
```

**Oracle:**
```sql
INSERT ALL
INTO <table_name> (<primary_key>, CROSS_ENVIRONMENT_UUID, <col3>, <col4>) VALUES (1, STANDARD_HASH('<table_name>_1'), 'some value 1', CURRENT_TIMESTAMP)
INTO <table_name> (<primary_key>, CROSS_ENVIRONMENT_UUID, <col3>, <col4>) VALUES (2, STANDARD_HASH('<table_name>_2'), 'some value 2', CURRENT_TIMESTAMP)
INTO <table_name> (<primary_key>, CROSS_ENVIRONMENT_UUID, <col3>, <col4>) VALUES (3, STANDARD_HASH('<table_name>_3'), 'some value 3', CURRENT_TIMESTAMP)
SELECT * FROM DUAL;
```

#### Data Update (id: 12)

**MariaDB / Oracle (same syntax):**
```sql
UPDATE <table_name> SET <updating_column_name> = 'set to value'
  [WHERE <any_column_name> = 'conditional value'];
```

#### Data Migration (id: 8)
No template — catch-all for complex data migrations. Use procedures for complex logic.

### ALTER Templates

#### Alter/Rename Table (id: 13)

**MariaDB:**
```sql
ALTER TABLE <table_name> RENAME TO <new_table_name>;
```

**Oracle:**
```sql
RENAME <table_name> TO <new_table_name>;
```

**Note:** Never rename unless absolutely necessary. If table is referenced in Appian, the DSE must be updated to match.

#### Alter/Rename Column (id: 14)

**MariaDB:**
```sql
-- Alter definition
ALTER TABLE <table_name> MODIFY COLUMN <column_name> <column_definition> COMMENT '<column comment>' AFTER <existing_column_name>;

-- Rename
ALTER TABLE <table_name> RENAME COLUMN <column_name> TO <new_column_name>;
```

**Oracle:**
```sql
-- Alter definition
ALTER TABLE <table_name> MODIFY <column_name> <column_definition>;

-- Rename
ALTER TABLE <table_name> RENAME COLUMN <column_name> TO <new_column_name>;
```

**Note:** Editing column datatype may delete existing data. Never rename unless absolutely necessary. If column is referenced in Appian, the DSE must be updated.

#### Set Auto Increment (id: 15)

**MariaDB:**
```sql
ALTER TABLE <table_name> AUTO_INCREMENT = <new_value>;
```

**Oracle:**
```sql
DROP SEQUENCE <table_name>_SQ;
CREATE SEQUENCE <table_name>_SQ START WITH <new_value> INCREMENT BY 1;
```

**Note:** Set to at least 100,000 for reference tables to allow shipping additional rows after customer data exists.

### DROP Templates

#### Drop Index (id: 16)

**MariaDB:** `DROP INDEX <index_name> ON <table_name>;`
**Oracle:** `DROP INDEX <index_name>;`

#### Drop Constraint (id: 17)

**MariaDB / Oracle:** `ALTER TABLE <table_name> DROP CONSTRAINT <constraint_name>;`

#### Truncate, Delete, Drop (id: 22)

**MariaDB / Oracle (same syntax):**
```sql
TRUNCATE TABLE <table_name>;           -- Delete all data
DROP TABLE <table_name>;               -- Delete table
ALTER TABLE <table_name> DROP COLUMN <column_name>;  -- Delete column
DELETE FROM <table_name> WHERE <any_column_name> = 'conditional value';  -- Conditional delete
```

**CRITICAL:** Never delete data from tables shipped in solutions. Rename to 'deprecated' instead. Only use for temporary tables in data migrations.

### COMMENT Template

#### Data Dictionary (id: 10)

**MariaDB:**
```sql
ALTER TABLE <table_name> COMMENT '<table comment>';
ALTER TABLE <table_name> MODIFY COLUMN <column_name> <column_definition> COMMENT '<column comment>';
```

**Oracle:**
```sql
COMMENT ON TABLE <table_name> IS '<table comment>';
COMMENT ON COLUMN <table_name>.<column_name> IS '<column comment>';
```

### AUXILIARY Templates (Non-Selectable — Reference Only)

| Template | MariaDB | Oracle |
|---|---|---|
| Show table definition | `SHOW CREATE TABLE <table_name>;` | `DESCRIBE <table_name>;` |
| Show view definition | `SHOW CREATE VIEW <view_name>;` | `SELECT TEXT FROM ALL_VIEWS WHERE VIEW_NAME = '<view_name>';` |
| Clone table | `CREATE TABLE <new> LIKE <existing>;` | `CREATE TABLE <new> AS (SELECT * FROM <existing>);` |
| Copy table data | `INSERT [IGNORE] INTO <new> SELECT * FROM <existing>;` | `INSERT INTO <new> SELECT * FROM <existing>;` |
| Toggle FK checks | `SET FOREIGN_KEY_CHECKS=0; ... SET FOREIGN_KEY_CHECKS=1;` | `ALTER TABLE <t> DISABLE CONSTRAINT <c>;` |

### Accessing Templates Programmatically

Templates are defined in the expression rule `SMT_ENUM_SCRIPT_TYPES_AND_TEMPLATES`. To get template content:

```
rule!SMT_ENUM_SCRIPT_TYPES_AND_TEMPLATES()
```

Or via the Web API:
```
GET /suite/webapi/SMT_WA_GET_TemplateCodeBlock?templateId=<id>&dbType=<MARIA_DB|ORACLE>
```

---

## 8. Application Dependencies

### How Dependencies Work

Applications can depend on other applications. This means:
- Dependent app's scripts are bundled AFTER the dependency's scripts in the downloadable SQL file
- Example: If App B depends on App A, and App C depends on App B:
  - App A's SQL file contains: only App A scripts
  - App B's SQL file contains: App A scripts + App B scripts (in order)
  - App C's SQL file contains: App A scripts + App B scripts + App C scripts (in order)

### Configuration

1. Set up all applications with at least one release each
2. On the dependent application, set **Dependent On** to the dependency application
3. On each release of the dependent app, specify the **Compatible Release** of the dependency
4. The **Release Dependency Path** (visible in Configuration tab) shows the full ordering

### Querying Dependencies

```sql
-- Find an app's dependency
SELECT a.appname, a.appdbtableprefix, dep.appname as depends_on
FROM Appian.SMT_Application a
LEFT JOIN Appian.SMT_Application dep ON a.precappid = dep.appid
WHERE a.appdbtableprefix = 'AS_GSS'
LIMIT 1
```

### Implications for Script Generation

When generating scripts for an app that depends on another:
- Tables from the dependency app can be referenced (e.g., foreign keys)
- Views can join across dependency boundaries
- The dependency must be configured in SMT Configuration tab BEFORE verification will pass

---

## 9. Data Dictionary

### Purpose

The Data Dictionary provides a front-end for viewing and updating table and column descriptions (comments). Currently supports MariaDB only.

### How It Works

- SMT caches table/column metadata from `INFORMATION_SCHEMA` into `SMT_InformationViewTables` and `SMT_InformationViewColumns`
- Tables and views matching the application's prefix are displayed
- Developers can add/edit comments for tables and columns
- Missing comments are flagged with a warning symbol
- Comment updates are persisted to the approved SQL scripts (as `ALTER TABLE ... COMMENT` statements)
- Data Dictionary modifications are auto-approved (no review needed)

### Querying the Data Dictionary

```sql
-- All tables for an application (with row counts and comments)
SELECT TABLE_NAME, TABLE_TYPE, TABLE_ROWS, TABLE_COMMENT, CREATE_TIME, UPDATE_TIME
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
ORDER BY TABLE_NAME
LIMIT 100

-- All columns for a specific table (with types and comments)
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_COMMENT, EXTRA
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME = '<TABLE_NAME>'
ORDER BY ORDINAL_POSITION
LIMIT 100

-- Find tables missing comments
SELECT TABLE_NAME, TABLE_ROWS
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND (TABLE_COMMENT IS NULL OR TABLE_COMMENT = '')
ORDER BY TABLE_NAME
LIMIT 50

-- Find columns missing comments
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND (COLUMN_COMMENT IS NULL OR COLUMN_COMMENT = '')
ORDER BY TABLE_NAME, ORDINAL_POSITION
LIMIT 100
```

### Generating Data Dictionary Comments

When generating comments for tables/columns, follow these guidelines:
- Table comments: describe the business purpose (e.g., "Stores vendor evaluation scores and ratings per evaluation phase")
- Column comments: describe what the column holds and any constraints (e.g., "Foreign key to AS_GSS_VENDOR. Links evaluation to the vendor being scored")
- Keep comments concise but informative — one sentence is ideal
- Include FK relationships in column comments
- Note any business rules (e.g., "Must be between 0 and 100")

---

## 10. Web APIs

### SMT Web APIs (Internal)

These are Appian Web APIs exposed by the SMT application for programmatic access.

| Endpoint | Method | Purpose | Parameters |
|---|---|---|---|
| `SMT_WA_GET_CodeBlock` | GET | Returns formatted HTML code block for a script | `changeScriptId`, `dbType` |
| `SMT_WA_GET_TemplateCodeBlock` | GET | Returns template code blocks | (template parameters) |
| `SMT_WA_GET_ScriptDiff` | GET | Returns diff between script versions | `jsonDateTime` |
| `SMT_WA_GET_DocumentContent` | GET | Returns document content for a release | (document parameters) |
| `SMT_WA_POST_InitVerification` | POST | Triggers script verification (starts process model) | (CR context) |
| `SMT_WA_POST_ScriptDiff` | POST | Creates/triggers a script diff | (script parameters) |
| `SMT_WA_POST_CancelDeploy` | POST | Cancels an in-progress deployment | (deployment context) |

### Export SQL Script API (Key External API)

**Endpoint:** `https://<env>/suite/webapi/smt-doc-download`

**Method:** GET

**Parameters:**
| Parameter | Required | Description | Example |
|---|---|---|---|
| `devPhaseId` | Yes | Primary key from `SMT_DevPhase` table | `26` |
| `appPrefix` | Yes | Application prefix from Configuration | `SMT`, `AS_GSS` |
| `documentType` | Yes | Always use `FULL_WITH_PRECEDENTS` | `FULL_WITH_PRECEDENTS` |
| `dbType` | Yes | One of: `MARIA_DB`, `ORACLE`, `SQLSERVER`, `POSTGRES` | `MARIA_DB` |

**Example URL:**
```
https://eng-test-fed-aq-dev2.appianpreview.com/suite/webapi/smt-doc-download?devPhaseId=26&appPrefix=AS_GSS&documentType=FULL_WITH_PRECEDENTS&dbType=MARIA_DB
```

**Returns:** A downloadable SQL file containing ALL approved scripts for the specified application and release, including scripts from dependent applications, in correct dependency order.

**Notes:**
- This consolidates all scripts into a single executable file
- Includes scripts from dependent releases (based on the Release Dependency Path)
- The file is ready to run on a target environment's database

---

## 11. Key SQL Queries for jarvis-smt Skills

### Application Context

```sql
-- Get all registered applications
SELECT appid, appname, appdbtableprefix, jiraticketprefix, dbtypes
FROM Appian.SMT_Application
ORDER BY appname
LIMIT 20

-- Get current release for an application
SELECT dp.devphaseid, dp.devphasename, dp.devphasepublicname, a.appname
FROM Appian.SMT_DevPhase dp
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND dp.iscurrentlyprimary = 1
LIMIT 1

-- Get all releases for an application
SELECT devphaseid, devphasename, devphasepublicname, iscurrentlyprimary
FROM Appian.SMT_DevPhase
WHERE appid = (SELECT appid FROM Appian.SMT_Application WHERE appdbtableprefix = '<APP_PREFIX>')
ORDER BY devphaseid
LIMIT 20
```

### Change Request Queries

```sql
-- Get open change requests for an application
SELECT cr.changeid, cr.changename, cr.changestatus, cr.jiraticketnumber, 
       cr.submittedby, cr.submittedon, dp.devphasename
FROM Appian.SMT_ChangeRequest cr
JOIN Appian.SMT_DevPhase dp ON cr.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND cr.changestatus IN ('OPEN', 'INITIAL_REVIEW')
ORDER BY cr.changeid DESC
LIMIT 20

-- Get scripts for a specific JIRA ticket
SELECT cs.changescriptid, cs.scriptname, cs.scriptdesc, cs.scriptstatus,
       cr.changename, cr.changestatus
FROM Appian.SMT_ChangeRequest_Script cs
JOIN Appian.SMT_ChangeRequest cr ON cs.changeid = cr.changeid
WHERE cr.jiraticketnumber = <JIRA_NUMBER>
ORDER BY cs.changescriptid
LIMIT 20

-- Get full SQL content for a script
SELECT changescriptid, scriptname, scriptdesc, scriptcontentmariadb, scriptcontentoracle
FROM Appian.SMT_ChangeRequest_Script
WHERE changescriptid = <ID>
LIMIT 1

-- Get recent change requests across all apps
SELECT cr.changeid, cr.changename, cr.changestatus, cr.submittedby, cr.submittedon,
       a.appname, dp.devphasename
FROM Appian.SMT_ChangeRequest cr
JOIN Appian.SMT_DevPhase dp ON cr.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
ORDER BY cr.changeid DESC
LIMIT 20
```

### Approved Scripts

```sql
-- Get all approved scripts for a release
SELECT s.scriptid, s.scriptname, s.scriptdesc, s.scriptstatus, s.lastmodifiedby, s.lastmodifiedon
FROM Appian.SMT_Script s
WHERE s.devphaseid = <DEV_PHASE_ID>
ORDER BY s.scriptid
LIMIT 100

-- Get full SQL content of an approved script
SELECT scriptid, scriptname, scriptcontentmariadb, scriptcontentoracle
FROM Appian.SMT_Script
WHERE scriptid = <ID>
LIMIT 1
```

### Data Dictionary Queries

```sql
-- All tables for an app with metadata
SELECT TABLE_NAME, TABLE_TYPE, TABLE_ROWS, TABLE_COMMENT, UPDATE_TIME
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
ORDER BY TABLE_NAME
LIMIT 100

-- Full column details for a table
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_COMMENT, EXTRA, ORDINAL_POSITION
FROM Appian.SMT_InformationViewColumns
WHERE TABLE_NAME = '<TABLE_NAME>'
ORDER BY ORDINAL_POSITION
LIMIT 100

-- Tables with row counts (for understanding data volume)
SELECT TABLE_NAME, TABLE_ROWS, AVG_ROW_LENGTH
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_ROWS DESC
LIMIT 20

-- Views only
SELECT TABLE_NAME, TABLE_COMMENT
FROM Appian.SMT_InformationViewTables
WHERE TABLE_NAME LIKE '<APP_PREFIX>%'
AND TABLE_TYPE = 'VIEW'
ORDER BY TABLE_NAME
LIMIT 50
```

### Deployment History

```sql
-- Recent script executions
SELECT scriptexecuteid, releasename, scriptname, starttime, endtime, 
       executetime, issuccess, executionskipped
FROM Appian.SMT_ScriptExecutionHistory
ORDER BY starttime DESC
LIMIT 20

-- Failed executions
SELECT scriptname, releasename, starttime
FROM Appian.SMT_ScriptExecutionHistory
WHERE issuccess = 0
ORDER BY starttime DESC
LIMIT 10
```

---

## 12. Administration

### Upgrade Application (SMT itself)

When upgrading the SMT application to a newer version:
1. Download the newest version from the app market
2. Add modified application objects to a package named **Modified Objects** for tracking
3. Run the correct `/sql/<db vendor>/*.sql` files to upgrade the database schema
4. Deploy `application/upgrade/*.zip` files to upgrade the Appian application objects
5. Check the **Modified Objects** package to see if any previously modified objects were updated
6. Merge customizations using the compare versions tool

### Deploy to Higher-Level Environments

**CRITICAL: SMT should NOT be deployed to any higher-level environments.** It exists only in the development environment. It is not needed in target environments for successful deployment of scripts.

Target environments receive only:
- The exported SQL files (from the "Downloadable SQL Files" section or the `smt-doc-download` Web API)
- These SQL files are self-contained and include all scripts in dependency order

### Migrate Existing Application to SMT Framework

For applications that already have database tables but aren't yet managed by SMT:

1. Set up a new application in SMT (Configuration tab) with a new release
2. From the database, create an export of ALL existing DDLs:
   - Tables
   - Views
   - Indices (may be included in CREATE TABLE statements)
   - Constraints
   - Sequences (Oracle)
   - Triggers
   - Stored procedures
   - Functions
3. Create a Change Request with scripts in order, one per DDL type:
   - Standard scripts for tables/views/indices
   - Separate scripts for each trigger (they always re-run)
   - Separate scripts for each stored procedure (they always re-run)
   - Use `CREATE OR REPLACE` or `DROP + CREATE` for all procedures/triggers
4. Submit and Approve the change request
5. During approval, verification populates the `<App Acronym>_ScriptExecutionHistory` table
6. Take a **Data and Structure** export of the execution history table
7. Run this export on each target environment that already has the DDLs
8. This ensures SMT won't try to re-run scripts that are already deployed

### Security Groups

| Group | Access Level |
|---|---|
| **SMT Users** | Can create and submit change requests |
| **SMT Admins** | Can approve/reject CRs, modify configuration, manage user access |

- Only SMT Admins see the Configuration tab
- You cannot remove yourself from the Admins list
- To add a group (instead of individual users), add members to the SMT Admins group manually in Appian Designer

---

## 13. Relationship to JARVIS

### How jarvis-smt Uses JARVIS Tools

jarvis-smt is a steering-only power with no MCP server of its own. It relies on the JARVIS MCP server's `query_sql` tool for all database access. The relationship:

- **`query_sql`** — Primary tool for reading all SMT tables (applications, scripts, CRs, data dictionary)
- **`evaluate_sail_expression`** — Can call SMT expression rules if needed
- **`get_jarvis_config`** — Maps JARVIS app prefixes to SMT app prefixes (they use the same prefixes)

### Mapping Between JARVIS and SMT Applications

| JARVIS App (from get_jarvis_config) | SMT App (from SMT_Application) | Prefix |
|---|---|---|
| AS GSS Full Application | Source Selection | AS_GSS |
| AS VM Full Application | (not in SMT currently) | AS_VM |
| AS GCW Full Application | (not in SMT currently) | AS_GCW |
| AS RM Full Application | Requirements Management | AS_RM |

To find the SMT app for a JARVIS app:
```sql
SELECT appid, appname, appdbtableprefix, dbtypes
FROM Appian.SMT_Application
WHERE appdbtableprefix = '<prefix from JARVIS config>'
LIMIT 1
```

### When JARVIS Design Workflow Should Invoke jarvis-smt

During the JARVIS design-doc workflow, if the design includes:
- New database tables
- New columns on existing tables
- New views
- Schema modifications

Then JARVIS should suggest: "This design requires database changes. Want me to generate the SMT scripts?"

The jarvis-smt power then takes over to generate idempotent SQL following all the rules in this document.
