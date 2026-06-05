# DB Config Workflow

Query the SMT application registry, release configuration, dependency chains, and deployment ordering. This skill answers questions about which applications are managed, their relationships, supported DB types, and how scripts deploy across environments.

---

## Triggers

Activate this skill when the user asks:
- "What apps are in SMT?"
- "What's the latest release for VM?"
- "What does VM depend on?"
- "Show me the dependency chain for GCW"
- "What DB types does Award Management support?"
- "What's the deployment order for VM v2.8?"
- "Which apps use the GAM JIRA prefix?"
- "What's the compatible GAM release for VM v2.4?"
- "How many releases does GSS have?"
- "Is this app public?"
- "What's the app prefix for Award Management?"

---

## Strategies

### Step 0: Schema Detection (MANDATORY — see smt-reference.md Section 3)

Before any query, detect the correct schema:
```sql
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1
```
If count > 0 → use `DevTools.SMT_*`. Otherwise → use `Appian.SMT_*`. Use `{SMT_SCHEMA}` as placeholder below.

---

### Strategy 1: List All Applications

User asks "What apps are in SMT?" or "Show me all registered applications":

```sql
SELECT appid, appname, appdbtableprefix, jiraticketprefix, dbtypes, ispublicapp,
       (SELECT appname FROM Appian.SMT_Application dep WHERE dep.appid = a.precappid) as depends_on
FROM Appian.SMT_Application a
ORDER BY appname
LIMIT 30
```

**Present as a table showing:**
- Application Name
- Prefix (AS_GSS, AS_AM, etc.)
- DB Types (MariaDB, Oracle, or both)
- Depends On (parent app name or "Independent")
- JIRA Prefix
- Public flag

---

### Strategy 2: Show Application Details

User asks about a specific app: "Tell me about VM" or "What's the config for Award Management?"

```sql
SELECT a.appid, a.appname, a.appdbtableprefix, a.jiraticketprefix, a.dbtypes, a.ispublicapp,
       dep.appname as depends_on_app, dep.appdbtableprefix as depends_on_prefix
FROM Appian.SMT_Application a
LEFT JOIN Appian.SMT_Application dep ON a.precappid = dep.appid
WHERE a.appdbtableprefix LIKE '%<PREFIX>%' OR a.appname LIKE '%<NAME>%'
LIMIT 5
```

Then get its releases:
```sql
SELECT dp.devphaseid, dp.devphasename, dp.devphasepublicname, dp.iscurrentlyprimary
FROM Appian.SMT_DevPhase dp
WHERE dp.appid = <APP_ID>
ORDER BY dp.devphaseid
LIMIT 30
```

And script count per release:
```sql
SELECT dp.devphasename, COUNT(s.scriptid) as script_count
FROM Appian.SMT_DevPhase dp
LEFT JOIN Appian.SMT_Script s ON dp.devphaseid = s.devphaseid
WHERE dp.appid = <APP_ID>
GROUP BY dp.devphaseid, dp.devphasename
ORDER BY dp.devphaseid
LIMIT 30
```

---

### Strategy 3: Show Releases for an Application

User asks "What releases does VM have?" or "What's the latest release for GSS?"

```sql
SELECT dp.devphaseid, dp.devphasename, dp.devphasepublicname, dp.iscurrentlyprimary,
       dp.precdevphaseid
FROM Appian.SMT_DevPhase dp
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<PREFIX>'
ORDER BY dp.devphaseid
LIMIT 30
```

**Highlight the current primary release** (where `iscurrentlyprimary = 1`).

---

### Strategy 4: Show Dependency Chain

User asks "What does VM depend on?" or "Show me the dependency chain for GCW":

**Step 1 — Get the app and its direct dependency:**
```sql
SELECT a.appid, a.appname, a.appdbtableprefix, a.precappid,
       dep.appname as depends_on, dep.appdbtableprefix as dep_prefix
FROM Appian.SMT_Application a
LEFT JOIN Appian.SMT_Application dep ON a.precappid = dep.appid
WHERE a.appdbtableprefix = '<PREFIX>'
LIMIT 1
```

**Step 2 — Walk the chain (if dependency has its own dependency):**
```sql
SELECT a.appname, a.appdbtableprefix,
       dep.appname as depends_on
FROM Appian.SMT_Application a
LEFT JOIN Appian.SMT_Application dep ON a.precappid = dep.appid
WHERE a.precappid IS NOT NULL
ORDER BY a.appname
LIMIT 20
```

**Present as a chain:**
```
Government Acquisition Management (AS_GAM) — Independent (root)
  ↓
Award Management (AS_AM) — depends on GAM
  ↓
(no further dependents in this chain)

Government Acquisition Management (AS_GAM) — Independent (root)
  ↓
Government Contract Writing (AS_GCW) — depends on GAM
  ↓
Contract Writing TMG (AS_GCW_TMG) — depends on GCW
```

---

### Strategy 5: Show Deployment Order (Release Dependency Path)

User asks "What's the deployment order for VM v2.8?" or "In what order do scripts deploy?"

This shows the order that scripts from dependent applications are included when generating the downloadable SQL file.

**Step 1 — Get the target app and its dependency:**
```sql
SELECT a.appid, a.appname, a.appdbtableprefix, a.precappid
FROM Appian.SMT_Application a
WHERE a.appdbtableprefix = '<PREFIX>'
LIMIT 1
```

**Step 2 — Get all releases for the dependency app (deployed before the target):**
```sql
SELECT dp.devphaseid, dp.devphasename, a.appname
FROM Appian.SMT_DevPhase dp
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE dp.appid = <DEPENDENCY_APP_ID>
ORDER BY dp.devphaseid
LIMIT 30
```

**Step 3 — Get all releases for the target app:**
```sql
SELECT dp.devphaseid, dp.devphasename, a.appname
FROM Appian.SMT_DevPhase dp
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE dp.appid = <TARGET_APP_ID>
ORDER BY dp.devphaseid
LIMIT 30
```

**Present as deployment order:**
```
Deployment Order for VM v2.8:

  Order | Application                      | Release
  ------+----------------------------------+---------
  1     | Government Acquisition Management | GAM v1.0
  2     | Government Acquisition Management | GAM v2.0
  3     | Government Acquisition Management | GAM v3.0
  ...
  7     | Government Acquisition Management | GAM v7.0
  8     | Vendor Management                 | VM v1.0
  9     | Vendor Management                 | VM v1.1
  ...
  18    | Vendor Management                 | VM v2.0
```

---

### Strategy 6: Find Apps by JIRA Prefix

User asks "Which apps use the GAM JIRA prefix?" or "What app is GAMS linked to?"

```sql
SELECT appid, appname, appdbtableprefix, dbtypes
FROM Appian.SMT_Application
WHERE jiraticketprefix = '<JIRA_PREFIX>'
ORDER BY appname
LIMIT 20
```

---

### Strategy 7: Show Supported DB Types

User asks "What DB types does AM support?" or "Which apps support Oracle?"

**For a specific app:**
```sql
SELECT appname, appdbtableprefix, dbtypes
FROM Appian.SMT_Application
WHERE appdbtableprefix = '<PREFIX>'
LIMIT 1
```

**All apps supporting a specific DB type:**
```sql
SELECT appname, appdbtableprefix, dbtypes
FROM Appian.SMT_Application
WHERE dbtypes LIKE '%<DB_TYPE>%'
ORDER BY appname
LIMIT 20
```

(Where `<DB_TYPE>` is `MARIA_DB`, `ORACLE`, `SQLSERVER`, or `POSTGRES`)

---

### Strategy 8: Show Verification Data Sources

User asks "What verification schemas are configured?"

```sql
SELECT dbtype, dsuuid
FROM Appian.SMT_DataSourceConfig
LIMIT 10
```

---

### Strategy 9: Current Release Summary (All Apps)

User asks "Give me an overview of all current releases":

```sql
SELECT a.appname, a.appdbtableprefix, dp.devphasename, dp.devphasepublicname,
       (SELECT COUNT(*) FROM Appian.SMT_Script s WHERE s.devphaseid = dp.devphaseid) as script_count
FROM Appian.SMT_Application a
JOIN Appian.SMT_DevPhase dp ON dp.appid = a.appid AND dp.iscurrentlyprimary = 1
ORDER BY a.appname
LIMIT 20
```

---

## Presentation Guidelines

- Show dependency chains as visual arrows (→ or ↓)
- Highlight the current primary release with a marker (★ or [CURRENT])
- Parse the `dbtypes` JSON array for display (e.g., `["MARIA_DB","ORACLE"]` → "MariaDB, Oracle")
- When showing deployment order, number the steps sequentially
- Group apps by dependency (independent apps first, then their dependents)
