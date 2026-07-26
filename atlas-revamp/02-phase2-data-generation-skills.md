# Phase 2 — Data Generation Skills

**Goal (one session):** Create the five data-generation skills derived from `atlas-demo-driver`
and `atlas-sql-forge`. All consume the shared `atlas-data-workflow` skill from Phase 1.

**Depends on:** Phase 1 (`atlas-data-workflow` + agent with both MCPs).
**Excludes:** ERD (`action-erd`) — not created.

> **Retention note:** `atlas-demo-driver` is a records-only subset of `atlas-sql-forge`. Its
> `action-generate-data` == the records path of sql-forge. So `atlas-generate-records` covers
> both powers' records mode; nothing from demo-driver is lost.

---

## Skill 2.1 — `atlas-generate-records`
**Source:** `action-generate-data` (records mode) + `step-6-execute` (demo-driver & sql-forge).
**MCP:** Atlas (schema/workflow) + Data Generator (writes).

```
.kiro/skills/atlas-generate-records/
├── SKILL.md
└── references/
    └── step-6-execute.md      # copied verbatim
```

**Frontmatter draft:**
```yaml
---
name: atlas-generate-records
description: "Create realistic, workflow-aware Appian test/demo data directly in a live environment via the Data Generator MCP. Use for 'create records', 'generate test data', 'set up demo data', 'create an evaluation in status X', or any request to create ≤~50 records live. Runs the shared atlas-data-workflow analysis (Steps 0–5) then executes creates and verifies them. Do NOT use for bulk SQL scripts (that's atlas-generate-sql) or read-only queries (atlas-query-records)."
---
```

**Body outline:**
1. Restate the CRITICAL RULES (from POWER.md) — Atlas/live only, `get_record_type_map` first,
   `get_field_map`, live ref data, `list_users` once, insertion order, never supply PKs,
   never write custom/computed fields, maximize field population, no `selected_fields`, never
   skip milestones, every milestone writes its file.
2. "Load the shared method first": read
   `.kiro/skills/atlas-data-workflow/SKILL.md` and run Steps 0–5 (point to its references).
3. **Step 6 (this skill):** follow `references/step-6-execute.md` — create via `create_record`
   (parents then children, or atomic `related_records`), capture returned IDs, verify with
   `query_records`, write `execution-log.md`.
4. Keep the execution tracker/milestone table visible in responses.

---

## Skill 2.2 — `atlas-generate-sql`
**Source:** `action-generate-data` (sql mode) + `step-6-generate-sql` + `action-bulk-sql`.
**MCP:** Atlas (schema/workflow); Data Generator only for reading an exemplar during Steps 1–5.

```
.kiro/skills/atlas-generate-sql/
├── SKILL.md
└── references/
    └── step-6-generate-sql.md   # copied verbatim
```

**Frontmatter draft:**
```yaml
---
name: atlas-generate-sql
description: "Generate bulk INSERT SQL scripts for Appian test/performance data (100+ rows) using the shared atlas-data-workflow analysis. Use for 'bulk data', 'generate SQL', 'SQL script for…', 'performance test data', or quantities > ~50. Produces bulk-data.sql with FK handling via LAST_INSERT_ID()/@variables — it does NOT write to the environment. Do NOT use to create live records (atlas-generate-records) or to generate SAIL UI code (atlas-generate-sail-interface)."
---
```

**Body outline:**
1. Same CRITICAL RULES + "run shared Steps 0–5 first" as 2.1.
2. **Step 6 (this skill):** follow `references/step-6-generate-sql.md` — emit INSERT statements
   in insertion order, resolve FKs with `LAST_INSERT_ID()` + `@vars`, write `bulk-data.sql`.
3. `action-bulk-sql` in the source power is just a redirect into sql mode — fold its intent
   into this skill's description; no separate skill.
4. Note: no live writes occur here; DG MCP is used read-only (exemplar discovery) during the
   shared steps.

---

## Skill 2.3 — `atlas-query-records`
**Source:** `action-query-and-validate`. **MCP:** Data Generator (+Atlas `get_field_map`).

```
.kiro/skills/atlas-query-records/
└── SKILL.md
```

**Frontmatter draft:**
```yaml
---
name: atlas-query-records
description: "Query and verify records in a live Appian environment via the Data Generator MCP. Use for 'query records', 'find records with…', 'verify the data', 'check what was created', or confirming generated data. Resolves field names via Atlas get_field_map, then query_records with filters/paging (never selected_fields by default). Read-only — does NOT create data (atlas-generate-records) or delete (atlas-rollback-session)."
---
```

**Body outline:** field-name resolution via `get_field_map`; `query_records` with
`filters`/`paging_info` (operators list; 1-based paging; no `selected_fields` by default);
present results as a table; offer verification against an expected set.

---

## Skill 2.4 — `atlas-rollback-session`
**Source:** `action-rollback`. **MCP:** Data Generator.

```
.kiro/skills/atlas-rollback-session/
└── SKILL.md
```

**Frontmatter draft:**
```yaml
---
name: atlas-rollback-session
description: "Undo data created in the current Data Generator session — preview with get_session, then rollback_session for reverse-order soft delete. Use for 'rollback', 'undo', 'clean up', 'delete what we created', or 'show session'. Only affects records created this session. Does NOT delete arbitrary records or query them (atlas-query-records)."
---
```

**Body outline:** `get_session` to preview; confirm with the user; `rollback_session(confirm:true)`;
report what was soft-deleted. Include the "children before parents / reverse order" note.

---

## Skill 2.5 — `atlas-explore-schema`
**Source:** `action-explore-schema`. **MCP:** Atlas (read-only).

```
.kiro/skills/atlas-explore-schema/
└── SKILL.md
```

**Frontmatter draft:**
```yaml
---
name: atlas-explore-schema
description: "Explore an Appian application's database schema from the Atlas KB — tables, columns, PKs, FK relationships, reference tables, valid status values, and insertion order. Use for 'what tables exist', 'show me the schema', 'what are the valid statuses', 'what fields does X have'. Read-only schema understanding; does NOT create data (atlas-generate-records) or run the full generation workflow."
---
```

**Body outline:** `get_record_type_map` → `get_field_map` → `get_app_schema` /
`get_schema_relationships` / `get_reference_data` / `get_insertion_order` / `get_schema_summary`;
for actual ref values, query live via DG `query_records(ref_uuid)`; present as tables.

---

## Step 2.6 — Validate every skill
```bash
for s in atlas-generate-records atlas-generate-sql atlas-query-records atlas-rollback-session atlas-explore-schema; do
  python3 .kiro/skills/skill-creator/scripts/quick_validate.py .kiro/skills/$s
done
```

---

## Phase 2 exit criteria
- [ ] 5 skill folders exist with valid SKILL.md (+ copied `step-6-*` references where noted).
- [ ] `atlas-generate-records` and `atlas-generate-sql` explicitly load `atlas-data-workflow`
      before their Step 6.
- [ ] ERD is absent (confirming exclusion).
- [ ] All five pass `quick_validate.py`.
- [ ] Descriptions disambiguate records vs sql vs query vs rollback vs schema (no overlap;
      and `atlas-generate-sql` vs `atlas-generate-sail-interface` cross-reference each other).
