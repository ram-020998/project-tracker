# DB Status Workflow

Check the status of SQL scripts, change requests, and deployments in SMT. This skill answers questions about what scripts exist, what's pending review, what's linked to a JIRA ticket, and what's been deployed.

---

## Triggers

Activate this skill when the user asks:
- "Find scripts for GAMS-3098"
- "What DB scripts are linked to this ticket?"
- "What change requests are open?"
- "What's pending review?"
- "Show me the SQL for change request #308"
- "What's been approved for GSS v1.2?"
- "Who submitted scripts this week?"
- "What scripts were deployed recently?"
- "Is there a DB script for this feature?"
- "Show me the full SQL content of script #1126"

---

## Strategies

### Step 0: Schema Detection (MANDATORY — see smt-reference.md Section 3)

Before any query, detect the correct schema:
```sql
SELECT COUNT(*) as cnt FROM DevTools.SMT_Application LIMIT 1
```
If count > 0 → use `DevTools.SMT_*`. Otherwise → use `Appian.SMT_*`. Use `{SMT_SCHEMA}` as placeholder below.

---

### Strategy 1: Find Scripts for a JIRA Ticket

The most common ask. User wants to know if a JIRA ticket has associated DB scripts and what they contain.

**Step 1 — Extract the ticket number.** From "GAMS-3098", extract the numeric part: `3098`. SMT stores only the number in `jiraticketnumber`.

**Step 2 — Query change requests for that ticket:**
```sql
SELECT cr.changeid, cr.changename, cr.changestatus, cr.submittedby, cr.submittedon,
       cr.reviewedby, cr.reviewedon, dp.devphasename, a.appname
FROM Appian.SMT_ChangeRequest cr
JOIN Appian.SMT_DevPhase dp ON cr.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE cr.jiraticketnumber = <TICKET_NUMBER>
ORDER BY cr.changeid DESC
LIMIT 10
```

**Step 3 — Get the scripts within those CRs:**
```sql
SELECT cs.changescriptid, cs.scriptname, cs.scriptdesc, cs.scriptstatus, cs.scripttype
FROM Appian.SMT_ChangeRequest_Script cs
WHERE cs.changeid = <CHANGE_ID>
ORDER BY cs.changescriptid
LIMIT 20
```

**Step 4 — If user wants the actual SQL content:**
```sql
SELECT scriptname, scriptdesc, scriptcontentmariadb, scriptcontentoracle
FROM Appian.SMT_ChangeRequest_Script
WHERE changescriptid = <CHANGESCRIPT_ID>
LIMIT 1
```

**Present as:**
```
DB Scripts for GAMS-3098

Change Request: #308 — "Updating Column Data Type"
  Status: OPEN
  App: Source Selection (AS_GSS) — Release: GSS v1.2
  Submitted by: niranjana.a on 2021-11-30

  Scripts (2):
    1. Update AS_GSS_TMG_TASK — Update Column Date Type [INITIAL_REVIEW]
    2. Update AS_GSS_TMG_TASK_CHANGE_REASON_MAPPING — Update Column Date Type [INITIAL_REVIEW]
```

---

### Strategy 2: Show Open Change Requests

User wants to see what's pending across an app or all apps.

**For a specific application:**
```sql
SELECT cr.changeid, cr.changename, cr.changestatus, cr.jiraticketnumber,
       cr.submittedby, cr.submittedon, dp.devphasename
FROM Appian.SMT_ChangeRequest cr
JOIN Appian.SMT_DevPhase dp ON cr.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND cr.changestatus IN ('OPEN', 'INITIAL_REVIEW')
ORDER BY cr.submittedon DESC
LIMIT 20
```

**Across all applications:**
```sql
SELECT cr.changeid, cr.changename, cr.changestatus, cr.jiraticketnumber,
       cr.submittedby, cr.submittedon, a.appname, dp.devphasename
FROM Appian.SMT_ChangeRequest cr
JOIN Appian.SMT_DevPhase dp ON cr.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE cr.changestatus IN ('OPEN', 'INITIAL_REVIEW')
ORDER BY cr.submittedon DESC
LIMIT 20
```

**Present as:**
```
Open Change Requests — Source Selection

  #308 — "Updating Column Data Type" [OPEN]
         GAMS-3098 | niranjana.a | Nov 30, 2021 | GSS v1.2
         
  (No other open CRs)
```

---

### Strategy 3: Show Approved Scripts for a Release

User wants to see what's been committed to a specific release.

**Step 1 — Find the release:**
```sql
SELECT dp.devphaseid, dp.devphasename, dp.iscurrentlyprimary, a.appname
FROM Appian.SMT_DevPhase dp
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
ORDER BY dp.devphaseid DESC
LIMIT 10
```

**Step 2 — Get approved scripts for that release:**
```sql
SELECT s.scriptid, s.scriptname, s.scriptdesc, s.scriptstatus, 
       s.lastmodifiedby, s.lastmodifiedon, s.ishotfix
FROM Appian.SMT_Script s
WHERE s.devphaseid = <DEV_PHASE_ID>
AND s.scriptstatus != 'DELETED'
ORDER BY s.scriptid
LIMIT 100
```

**Present as:**
```
Approved Scripts — Source Selection v1.2 (GSS v1.2)

  Total: 14 scripts

  #1101 — Create AS_GSS_TMG_TASK [Standard]
  #1102 — Create AS_GSS_TMG_TASK_CATEGORY [Standard]
  #1103 — Create index on AS_GSS_TMG_TASK.CATEGORY_ID [Standard]
  ...
```

---

### Strategy 4: Show Full SQL Content of a Script

User wants to read the actual SQL.

**From a change request (pending/in-review):**
```sql
SELECT changescriptid, scriptname, scriptdesc, scriptstatus,
       scriptcontentmariadb, scriptcontentoracle
FROM Appian.SMT_ChangeRequest_Script
WHERE changescriptid = <ID>
LIMIT 1
```

**From approved scripts (committed):**
```sql
SELECT scriptid, scriptname, scriptdesc, scriptstatus,
       scriptcontentmariadb, scriptcontentoracle
FROM Appian.SMT_Script
WHERE scriptid = <ID>
LIMIT 1
```

**Present the SQL in a code block with the DB type labeled:**
```
📄 Script #1126 — "Script to drop FK on AS_RM_QNM_A_T_QUESTION_PRECEDENT_SET"

MariaDB:
​```sql
ALTER TABLE AS_RM_QNM_A_T_QUESTION_PRECEDENT_SET 
  DROP FOREIGN KEY IF EXISTS asrmqnmtqstnprc_qstnprcdntstc;
​```

Oracle:
​```sql
(no Oracle content for this script)
​```
```

---

### Strategy 5: Show Recent Change Requests (Activity Feed)

User wants to see recent activity across all apps.

```sql
SELECT cr.changeid, cr.changename, cr.changestatus, cr.jiraticketnumber,
       cr.submittedby, cr.submittedon, cr.reviewedby, cr.reviewedon,
       a.appname, dp.devphasename
FROM Appian.SMT_ChangeRequest cr
JOIN Appian.SMT_DevPhase dp ON cr.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
ORDER BY cr.changeid DESC
LIMIT 15
```

---

### Strategy 6: Show Scripts by Submitter

User asks "What did X submit?" or "Who submitted scripts this week?"

```sql
SELECT cr.changeid, cr.changename, cr.changestatus, cr.jiraticketnumber,
       cr.submittedon, a.appname, dp.devphasename
FROM Appian.SMT_ChangeRequest cr
JOIN Appian.SMT_DevPhase dp ON cr.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE cr.submittedby = '<USERNAME>'
ORDER BY cr.submittedon DESC
LIMIT 20
```

---

### Strategy 7: Show Deployment History

User asks "What was deployed recently?" or "Did my script deploy successfully?"

```sql
SELECT scriptexecuteid, releasename, scriptname, starttime, endtime,
       executetime, issuccess, executionskipped
FROM Appian.SMT_ScriptExecutionHistory
ORDER BY starttime DESC
LIMIT 20
```

**For failed deployments only:**
```sql
SELECT scriptname, releasename, starttime
FROM Appian.SMT_ScriptExecutionHistory
WHERE issuccess = 0
ORDER BY starttime DESC
LIMIT 10
```

**Present as:**
```
Recent Deployments

  SMT_ChangeRequest — Script Management 1.0 — Oct 20 (skipped - already exists)
  SMT_Script TRIGGER — Script Management 1.0 — Oct 20 (384ms)
  (no failures found)
```

---

### Strategy 8: Show Review Comments on a Change Request

User asks "What feedback was given on CR #308?"

```sql
SELECT c.commentid, c.comment, c.lastmodifiedby, c.lastmodifiedon
FROM Appian.SMT_Comment c
WHERE c.changeid = <CHANGE_ID>
ORDER BY c.lastmodifiedon
LIMIT 20
```

---

### Strategy 9: Show Script Diff (What Changed)

User asks "What changed in this script?" or "Show me the diff"

```sql
SELECT jsondatetime, LEFT(original, 500) as original_preview, LEFT(new, 500) as new_preview
FROM Appian.SMT_Diff
ORDER BY jsondatetime DESC
LIMIT 5
```

For full diff content:
```sql
SELECT original, new
FROM Appian.SMT_Diff
WHERE jsondatetime = '<DATETIME_KEY>'
LIMIT 1
```

---

### Strategy 10: Summary Dashboard

User asks "Give me an overview" or "SMT status":

**Run these queries in parallel:**

1. Open CRs count:
```sql
SELECT COUNT(*) as open_count
FROM Appian.SMT_ChangeRequest
WHERE changestatus IN ('OPEN', 'INITIAL_REVIEW')
LIMIT 1
```

2. Recently approved:
```sql
SELECT COUNT(*) as approved_this_month
FROM Appian.SMT_ChangeRequest
WHERE changestatus = 'APPROVED'
AND reviewedon >= DATE_SUB(NOW(), INTERVAL 30 DAY)
LIMIT 1
```

3. Scripts per app:
```sql
SELECT a.appname, COUNT(s.scriptid) as script_count
FROM Appian.SMT_Script s
JOIN Appian.SMT_DevPhase dp ON s.devphaseid = dp.devphaseid
JOIN Appian.SMT_Application a ON dp.appid = a.appid
WHERE dp.iscurrentlyprimary = 1
GROUP BY a.appname
ORDER BY script_count DESC
LIMIT 10
```

**Present as:**
```
SMT Dashboard Summary

  Open Change Requests: 1
  Approved This Month: 3
  
  Scripts by App (current release):
    Requirements Management: 45 scripts
    Award Management: 38 scripts
    Source Selection: 14 scripts
    Government Clause Automation: 12 scripts
```

---

## Presentation Guidelines

- Always show CR status with clear indicators: OPEN, INITIAL_REVIEW, APPROVED, COMMITTED, CANCELLED
- Link JIRA tickets when showing `jiraticketnumber` (format: GAMS-<number>)
- Show submitter and date for context
- When showing SQL content, use code blocks with `sql` language tag
- If a CR has multiple scripts, list them with numbers before showing content
- For multi-DB apps, show both MariaDB and Oracle content when available
- If Oracle content is empty/null for a MariaDB-only app, don't show the Oracle section
