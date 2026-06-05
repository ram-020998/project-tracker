# Action: Rollback

Session management and cleanup of created records.

---

## When to Use

- User asks "Undo what we created"
- User asks "Rollback"
- User asks "Clean up the test data"
- User asks "Show me what was created in this session"
- After a failed data generation (partial cleanup)

---

## Workflow

### Step 1: Show current session
```
Data Generator MCP: get_session()
```

Present the session summary:
```
📊 CURRENT SESSION
═══════════════════════════════════════
Started: 2024-12-11T07:29:45Z
Records created: 8

By type:
  AS_GSS_Evaluation (e6bc8561-...): 2 records
  AS_GSS_EvaluationVendor (b6081510-...): 6 records

Records (in creation order):
  1. Evaluation ID 1045
  2. Evaluation ID 1046
  3. EvaluationVendor ID 5001
  4. EvaluationVendor ID 5002
  5. EvaluationVendor ID 5003
  6. EvaluationVendor ID 5004
  7. EvaluationVendor ID 5005
  8. EvaluationVendor ID 5006
═══════════════════════════════════════
```

### Step 2: Confirm with user

**ALWAYS ask for confirmation before rollback:**
```
⚠️  This will soft-delete all 8 records (set isActive=false).
    Deletion order: reverse (children first, then parents).
    
    Proceed with rollback? (y/n)
```

### Step 3: Execute rollback
```
Data Generator MCP: rollback_session(confirm: true)
```

### Step 4: Report results
```
✅ ROLLBACK COMPLETE
═══════════════════════════════════════
Rolled back: 8 records
Errors: 0

All records have been soft-deleted (isActive=false).
Session cleared.
═══════════════════════════════════════
```

---

## Partial Rollback

If the user only wants to undo specific records (not the whole session), use `delete_record` individually:

```
Data Generator MCP: delete_record(
  record_type_uuid: "b6081510-...",
  record_id: 5006
)
```

**Important**: Delete children before parents to avoid FK issues.

---

## Error During Rollback

If some records fail to delete:
```
⚠️  ROLLBACK PARTIAL
═══════════════════════════════════════
Rolled back: 6 records
Errors: 2

Failed records:
  ❌ EvaluationVendor ID 5003 — Permission denied
  ❌ EvaluationVendor ID 5004 — Permission denied

These records remain active in the database.
═══════════════════════════════════════
```

---

## Session Lifecycle

- Session starts when the MCP server process starts
- Session tracks ALL `create_record` calls (not updates or deletes)
- Session is in-memory — lost if the server process restarts
- After rollback, session is cleared (starts fresh)
- Multiple data generation rounds accumulate in the same session until rollback
