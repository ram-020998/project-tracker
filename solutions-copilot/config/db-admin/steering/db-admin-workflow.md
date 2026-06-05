# DB Admin Workflow

Guide users through SMT administrative tasks: registering new applications, creating releases, managing dependencies, and migrating existing apps into SMT.

---

## Triggers

Activate this skill when the user asks:
- "How do I register a new app in SMT?"
- "I want to add a new application"
- "How do I create a release?"
- "How do I set up dependencies?"
- "How do I migrate an existing app to SMT?"
- "What are the steps to onboard to SMT?"
- "How do I configure verification?"
- "Who has admin access?"

---

## Prerequisites

### Step 0: Schema Detection (MANDATORY — see smt-reference.md Section 3)

```sql
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1
```
If count > 0 → use `DevTools.SMT_*`. Otherwise → use `Appian.SMT_*`.

### Access Requirements

- Only **SMT Admins** can register applications, create releases, and modify configuration
- SMT Admins group is managed in Appian Designer (not in SMT itself)
- You cannot remove yourself from the Admins list
- Regular **SMT Users** can only create and submit change requests

---

## Workflow 1: Register a New Application

### What You Need Before Starting

Help the user decide on these values before they go to the SMT UI:

| Field | Convention | How to Decide |
|-------|-----------|---------------|
| **Application Name** | Full descriptive name | Match the Appian application name |
| **DB Table Prefix** | `AS_<ACRONYM>` | Must be unique — check existing prefixes first |
| **JIRA Ticket Prefix** | Project key from JIRA | e.g., `GAMS`, `PRS`, `PSS` |
| **DB Types** | MariaDB, Oracle, or both | Match what your target environments use |
| **Dependency (Precedent App)** | Another SMT app or none | Set if your tables reference another app's tables |
| **Is Public** | true/false | true = customer-facing solution app |

### Step 1: Verify Prefix Uniqueness

Before registering, confirm the prefix isn't already taken:

```sql
SELECT appid, appname, appdbtableprefix
FROM {SMT_SCHEMA}.SMT_Application
WHERE appdbtableprefix = '<PROPOSED_PREFIX>'
LIMIT 1
```

If this returns a row, the prefix is taken — suggest an alternative.

Also check for similar prefixes to avoid confusion:
```sql
SELECT appid, appname, appdbtableprefix
FROM {SMT_SCHEMA}.SMT_Application
WHERE appdbtableprefix LIKE '<PARTIAL_PREFIX>%'
ORDER BY appname
LIMIT 10
```

### Step 2: Identify Dependency (if any)

If the new app's tables will reference tables from another app (e.g., FK to `AS_GAM_R_COUNTRY`), identify the dependency:

```sql
SELECT appid, appname, appdbtableprefix
FROM {SMT_SCHEMA}.SMT_Application
WHERE appdbtableprefix = '<DEPENDENCY_PREFIX>'
LIMIT 1
```

The `appid` returned becomes the `precappid` for the new application.

**Dependency implications:**
- Scripts from the dependency app deploy BEFORE yours
- Each release of your app must specify a compatible release of the dependency
- Verification will include the dependency's scripts when validating yours

### Step 3: Register in SMT UI

Direct the user to:
1. Navigate to **SMT site** → **CONFIGURATION** tab (top navigation bar)
2. Look for the **"+ Add Application"** action (typically at the bottom of the left sidebar app list)
3. Fill in the form with the values decided in the planning step
4. Save

### Step 4: Verify Registration

After the user registers, confirm it worked:

```sql
SELECT appid, appname, appdbtableprefix, jiraticketprefix, precappid, ispublicapp, dbtypes
FROM {SMT_SCHEMA}.SMT_Application
WHERE appdbtableprefix = '<NEW_PREFIX>'
LIMIT 1
```

---

## Workflow 2: Create a New Release (Dev Phase)

### When to Create a Release

- First release after registering a new app
- Starting a new version/sprint that needs separate script tracking
- When the dependency app creates a new release you need to be compatible with

### Step 1: Check Existing Releases

```sql
SELECT dp.devphaseid, dp.devphasename, dp.devphasepublicname, dp.precdevphaseid
FROM {SMT_SCHEMA}.SMT_DevPhase dp
JOIN {SMT_SCHEMA}.SMT_Application a ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
ORDER BY dp.devphaseid
LIMIT 30
```

### Step 2: Determine Release Naming

Follow the existing pattern for the app:
- Internal name: `<ACRONYM> v<MAJOR>.<MINOR>` (e.g., `GSS v2.8`, `VM v2.7`)
- Public name: `<Full App Name> <MAJOR>.<MINOR>` (e.g., `Source Selection 2.8`, `Vendor Management 2.7`)

The next version should increment from the latest existing release.

### Step 3: Identify Compatible Dependency Release (if app has dependency)

If the app depends on another, check what releases the dependency has:

```sql
SELECT dp.devphaseid, dp.devphasename
FROM {SMT_SCHEMA}.SMT_DevPhase dp
JOIN {SMT_SCHEMA}.SMT_Application a ON dp.appid = a.appid
WHERE a.appid = (
  SELECT precappid FROM {SMT_SCHEMA}.SMT_Application WHERE appdbtableprefix = '<APP_PREFIX>'
)
ORDER BY dp.devphaseid DESC
LIMIT 5
```

The user must select which dependency release their new release is compatible with.

### Step 4: Create in SMT UI

Direct the user to:
1. **CONFIGURATION** tab → select the app in the left sidebar
2. Click **"+ Add release"** (at the bottom of the releases list)
3. Fill in:
   - **Internal Name** — e.g., `VA v1.0`
   - **Public Name** — e.g., `Vendor Analytics 1.0`
   - **Compatible Release** — select the dependency release (if applicable)
4. Save

### Step 5: Verify

```sql
SELECT dp.devphaseid, dp.devphasename, dp.devphasepublicname
FROM {SMT_SCHEMA}.SMT_DevPhase dp
JOIN {SMT_SCHEMA}.SMT_Application a ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
ORDER BY dp.devphaseid DESC
LIMIT 3
```

---

## Workflow 3: Migrate an Existing Application to SMT

For applications that already have database tables but aren't yet managed by SMT.

### Step 1: Register the App (follow Workflow 1)

### Step 2: Create First Release (follow Workflow 2)

### Step 3: Export All Existing DDLs

The user needs to create scripts for everything that already exists in the database. Help them identify what exists:

```sql
-- Tables
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'Appian' AND TABLE_NAME LIKE '<APP_PREFIX>%'
AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME
LIMIT 100

-- Views
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'Appian' AND TABLE_NAME LIKE '<APP_PREFIX>%'
AND TABLE_TYPE = 'VIEW'
ORDER BY TABLE_NAME
LIMIT 50
```

### Step 4: Create Change Request with Baseline Scripts

The user should create a CR containing:
1. **One script per CREATE TABLE** (in dependency order — parent tables first)
2. **One script per CREATE VIEW** (after all tables)
3. **Separate scripts for each trigger** (they always re-run)
4. **Separate scripts for each stored procedure** (they always re-run)
5. All scripts must use `CREATE OR REPLACE` or `IF NOT EXISTS` for idempotency

### Step 5: Submit and Approve

After approval, verification populates the `<App_Prefix>_ScriptExecutionHistory` table.

### Step 6: Backfill Execution History on Target Environments

**Critical step:** Target environments already have these tables, so SMT must know not to re-run the scripts there.

1. Take a **Data and Structure** export of the `Appian.<APP_PREFIX>_ScriptExecutionHistory` table from the dev environment
2. Run this export on each target environment that already has the DDLs
3. This ensures SMT won't try to re-run scripts that are already deployed

---

## Workflow 4: Verify Data Source Configuration

### Check Existing Verification Schemas

```sql
SELECT dbtype, dsuuid
FROM {SMT_SCHEMA}.SMT_DataSourceConfig
LIMIT 10
```

### What's Needed

Each DB type the app supports needs a verification data source:
- **MariaDB** — a blank MariaDB schema dedicated to verification
- **Oracle** — a blank Oracle schema dedicated to verification

**WARNING:** The verification schema is TRUNCATED AND REPLACED during verification. NEVER use a production or shared schema.

### If a Data Source is Missing

An SMT Admin must:
1. Create a new blank database schema on the appropriate DB server
2. Create an Appian Connected System pointing to that schema
3. Register the data source UUID in SMT Configuration

---

## Presentation Guidelines

- When helping plan a new app, present the decisions as a checklist
- Show existing apps/prefixes so the user can see naming patterns
- Warn about dependency implications before they commit
- After registration, always verify with a query to confirm it worked
- For migrations, emphasize the execution history backfill step — skipping it causes scripts to re-run on target environments
