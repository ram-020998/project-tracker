---
inclusion: auto
---

# Action: Bulk SQL Generation

## ⚠️ THIS ACTION IS NOW PART OF THE MAIN WORKFLOW

Bulk SQL generation uses the **same 6-step workflow** as record generation, with the mode set to **sql**.

**When this action is triggered:**
1. Follow `action-generate-data` with mode = **sql**
2. Steps 0-5 are identical to records mode
3. Step 6 follows `step-6-generate-sql` instead of `step-6-execute`

**Do NOT use this file directly. Route to `action-generate-data` with sql mode.**

---

## Quick Reference: Records vs SQL Mode

| Aspect | Records Mode | SQL Mode |
|--------|-------------|----------|
| Best for | 1-50 records, verification needed | 100+ records, performance testing |
| Output | Records in live Appian environment | `.sql` file with INSERT statements |
| FK handling | Appian auto-links via related_records | LAST_INSERT_ID() + @variables |
| Verification | Query after create | Manual execution + sync |
| Rollback | `rollback_session()` | DELETE statements or restore backup |
| Step 6 file | `step-6-execute` | `step-6-generate-sql` |

---

## Triggers for SQL Mode

- User mentions quantities > 50
- User says "bulk", "SQL", "script", "performance"
- User says "SQL file" or "INSERT statements"
- User needs data for a fresh environment setup
- User needs performance testing data
