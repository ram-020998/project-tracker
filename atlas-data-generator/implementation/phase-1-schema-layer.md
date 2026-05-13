# Phase 1: Schema Layer — Implementation Complete

## Status: ✅ IMPLEMENTED AND VALIDATED

---

## Objective

Integrate the DDL replay engine into the `solutions-atlas-parser` pipeline so that every application parse automatically produces a structured `schema/` output section in the Atlas KB.

---

## Implementation Summary

### Module Location
```
appian_parser/schema/
├── __init__.py              # Exports SchemaBuilder
├── models.py                # Column, ForeignKey, Table, SchemaResult dataclasses
├── script_finder.py         # Locates SQL scripts in extracted packages
├── statement_parser.py      # Extracts SQL from GAM framework DELIMITER blocks
├── ddl_replay_engine.py     # Replays DDL statements to build final schema state
└── schema_builder.py        # Orchestrates pipeline with topological sort + classification
```

### Test Location
```
tests/schema/
├── __init__.py
└── test_schema.py           # 38 tests covering all components + integration
```

### CLI Integration
- Schema parsing is integrated into `appian_parser/cli.py` → `dump_package()` function
- Runs automatically after the enrichment phase
- Output goes to `<output_dir>/schema/` (legacy mode) or `<data_dir>/current/schema/` (versioned mode)
- No CLI flag needed — adds <0.1s to parse time for most packages

---

## Architecture

```
ZIP Package
    │
    ▼
ScriptFinder
    │  Locates scripts/ folder (root or one level deep)
    │  Returns sorted .sql files (01.*.sql, 02.*.sql, ...)
    │  Ignores oracle-scripts/ and postgres-scripts/
    ▼
StatementParser
    │  Extracts content from DELIMITER $$ blocks
    │  Uses START/END SCRIPT CONTENT markers
    │  Preserves top-level statements outside blocks
    │  Splits on line-ending semicolons
    │  Strips leading comments and empty lines
    ▼
DDLReplayEngine
    │  Replays statements in order to build final state:
    │  • CREATE TABLE (with IF NOT EXISTS dedup)
    │  • ALTER TABLE ADD/MODIFY/DROP COLUMN
    │  • ALTER TABLE ADD CONSTRAINT FOREIGN KEY (with dedup)
    │  • ALTER TABLE DROP FOREIGN KEY
    │  • ALTER TABLE RENAME TO (table)
    │  • ALTER TABLE RENAME COLUMN
    │  • DROP TABLE
    │  • INSERT INTO (any table → reference data)
    │  • UPDATE (on tables with existing INSERT data)
    │  • Multi-clause ALTER TABLE (comma-separated)
    ▼
SchemaBuilder
    │  Orchestrates the full pipeline:
    │  • Builds FK relationship list
    │  • Computes topological insertion order (Kahn's algorithm)
    │  • Classifies tables (framework/audit/reference/task_mgmt/business)
    │  • Generates summary statistics
    ▼
JSON Output (6 files)
```

---

## Key Design Decisions

### 1. Statement Extraction: Line-Based Splitting

The scripts use the GAM Script Execution Framework which wraps every DDL operation in a stored procedure:

```sql
DELIMITER $$
CREATE PROCEDURE AS_GAM_RunFrameworkScript()
BEGIN
CALL AS_GAM_Initial_Execution("N", ...);
IF @cont > 0 THEN
-- START SCRIPT CONTENT ---
<actual DDL here>
-- END SCRIPT CONTENT ---
CALL AS_GAM_Update_Execution(...);
END IF;
END $$
DELIMITER ;
```

The `StatementParser` extracts content between the markers and splits on **line-ending semicolons** (not character-by-character). This avoids quote-tracking bugs with escaped apostrophes in data values (e.g., `"People's Republic"`).

### 2. Reference Data Detection: INSERT-Based Heuristic

Instead of relying on naming conventions (`_R_` pattern), any table that has INSERT statements in the DDL script is treated as reference/config data. Rationale: transactional tables never have INSERT scripts in DDL files — only reference/lookup tables do.

This correctly handles all naming patterns across applications:
- GAM apps: `AS_GSS_R_DATA`, `AS_GAM_R_COUNTRY`
- CaseManagement: `CMGT_CFG_COUNTRY`, `CMGT_CFG_STATUS`
- AiDocumentCenter: `AIA_AI_SKILL_TYPE`, `AIA_REF_INSTANCE_STATUS`

### 3. Table Classification

Tables are classified using a combination of naming convention and data presence:

| Classification | Rule |
|---------------|------|
| `framework` | Name contains "ScriptExecution" |
| `audit` | Name contains `_A_R_` or `_AUDIT` |
| `reference` | Name contains `_R_` OR table has INSERT data |
| `task_management` | Name contains `_TMG_` |
| `business` | Everything else |

### 4. FK Deduplication

Multi-file packages (e.g., CaseManagement with 10 script files) repeat FK constraints across files. The engine deduplicates by `(constraint_name, columns, ref_table)` tuple, preventing inflated FK counts.

### 5. Table Rename Tracking

Scripts rename tables later in the file (shortening names for MySQL identifier limits). The engine:
- Tracks all renames in a map
- Resolves old names when processing FK references
- Consolidates reference data under final table names
- Resolves names when processing INSERT/UPDATE statements

### 6. Inline PRIMARY KEY Detection

Many tables define PK inline on the column (`EVALUATION_ID int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY`) rather than as a separate `PRIMARY KEY (col)` clause. The engine detects both patterns.

---

## Output Files

### `schema/tables.json`
All table definitions with final column state after all ALTER TABLE operations applied.

```json
{
  "AS_GSS_EVALUATION": {
    "columns": {
      "EVALUATION_ID": {"type": "int(11)", "nullable": false, "auto_increment": true},
      "EVALUATION_TITLE": {"type": "varchar(255)", "nullable": true},
      "EVALUATION_STATUS_ID": {"type": "int(11)", "nullable": true},
      "IS_WEIGHTED_FACTORS_REQ": {"type": "TINYINT(1)", "nullable": true, "comment": "Indicates whether..."}
    },
    "primary_key": ["EVALUATION_ID"]
  }
}
```

### `schema/relationships.json`
All FK relationships extracted from CREATE TABLE inline FKs and ALTER TABLE ADD CONSTRAINT.

```json
[
  {
    "from_table": "AS_GSS_EVALUATION",
    "to_table": "AS_GSS_R_DATA",
    "constraint": "asgssevalatin_evalatinstats",
    "columns": ["EVALUATION_STATUS_ID"],
    "ref_columns": ["REF_DATA_ID"]
  }
]
```

### `schema/reference_data.json`
All INSERT data from reference/config tables, consolidated under final table names.

```json
{
  "AS_GSS_R_DATA": [
    {"REF_DATA_ID": "1", "REF_LABEL": "Setting up", "REF_TYPE": "Evaluation Status", "IS_ACTIVE": "1"},
    {"REF_DATA_ID": "4", "REF_LABEL": "Least Price Technically Acceptable", "REF_TYPE": "Evaluation Method", "IS_ACTIVE": "1"}
  ]
}
```

### `schema/insertion_order.json`
Topologically sorted table list (parents before children). Circular dependencies placed at end.

### `schema/table_classification.json`
Each table mapped to its category.

### `schema/summary.json`
Statistics: table counts by category, total columns, total FKs, reference data counts.

---

## Validation Results

### All 15 Packages

| Package | Tables | Columns | FKs | Ref Tables | Ref Rows | Time |
|---------|--------|---------|-----|-----------|----------|------|
| SourceSelection | 105 | 940 | 173 | 11 | 302 | 0.03s |
| ClauseAutomation | 114 | 927 | 181 | 11 | 351 | 0.03s |
| VendorManagement | 157 | 1,230 | 203 | 15 | 486 | 0.03s |
| AwardManagement | 100 | 827 | 129 | 18 | 360 | 0.02s |
| RequirementsManagement | 178 | 1,365 | 235 | 26 | 2,834 | 0.04s |
| ContractWriting | 183 | 1,674 | 310 | 17 | 1,093 | 0.08s |
| GamSuiteModule | 92 | 678 | 114 | 5 | 847 | 0.02s |
| AiDocumentCenter | 41 | 402 | 24 | 7 | 25 | 0.01s |
| UserAccessManagement | 36 | 246 | 25 | 1 | 6 | 0.00s |
| ProcureSightEnterprise | 23 | 196 | 15 | 1 | 8 | 0.00s |
| ProcureSightPlus | 26 | 271 | 18 | 4 | 340 | 0.01s |
| CaseManagementStudio | 115 | 1,067 | 121 | 18 | 3,544 | 0.15s |
| ConnectedClaimsManagement | 210 | 2,056 | 220 | 86 | 14,892 | 1.66s |
| ConnectedUnderwriting | — | — | — | — | — | NO SCRIPTS |
| AiDocumentBuilder | 18 | 143 | 17 | 6 | 199 | 0.00s |

**Total: 2.44 seconds for all 14 packages. Zero errors.**

### Spot Check: AS_GSS_EVALUATION (Source Selection)

- **32 columns** — matches the Appian record type properties (30 non-custom fields + 2 additional)
- **Primary key**: `['EVALUATION_ID']` ✅
- **9 foreign keys** including:
  - `EVALUATION_STATUS_ID → AS_GSS_R_DATA.REF_DATA_ID`
  - `EVALUATION_METHOD_ID → AS_GSS_R_DATA.REF_DATA_ID`
  - `EVALUATION_CHIEF → AS_GSS_USER.USERNAME`
  - `IDV_AWARD_TYPE_ID → AS_GSS_R_DATA.REF_DATA_ID`
  - `INSTRUMENT_TYPE_ID → AS_GSS_R_DATA.REF_DATA_ID`
- All ALTER TABLE ADD COLUMN operations captured (IS_WEIGHTED_FACTORS_REQ, IS_EVALUATOR_MASKED, IDV_AWARD_TYPE_ID, etc.)

### Test Suite
- **302 total tests passing** (38 schema + 264 existing)
- **Zero regressions** in existing parser functionality

---

## Challenges Encountered & Resolved

### 1. DELIMITER Block Detection
**Problem**: Initial implementation looked for `$$` in the end marker, but actual end is `DELIMITER ;`.
**Fix**: Check for `DELIMITER` + `;` without `$$` for block end detection.

### 2. Leading Comments Merged with Statements
**Problem**: Comment lines (`-- Table structure for...`) between statements got merged because they don't end with semicolons.
**Fix**: `_clean_statement()` strips leading empty lines AND comment lines before returning.

### 3. Escaped Quotes in Data Values
**Problem**: Character-by-character semicolon splitting broke on `People\'s Republic` inside INSERT VALUES — the escaped quote corrupted the quote-tracking state for all subsequent statements.
**Fix**: Switched to **line-based splitting** (split on lines ending with `;`). This is robust because these scripts always have statement-ending semicolons at end of line.

### 4. Multi-Clause ALTER TABLE
**Problem**: `ALTER TABLE X ADD KEY ..., ADD CONSTRAINT ... FOREIGN KEY ...` — commas separate multiple clauses that must be processed independently.
**Fix**: `_split_top_level()` splits on commas at parenthesis depth 0, then each clause is processed by `_process_alter_clause()`.

### 5. Duplicate FKs from Multi-File Packages
**Problem**: CaseManagement has 10 script files, each containing the full FK constraint history. This produced 940 FKs instead of 121.
**Fix**: Deduplicate FKs by `(name, columns, ref_table)` tuple before appending.

### 6. Reference Data Detection Across Naming Conventions
**Problem**: Only tables with `_R_` in the name were captured. CaseManagement uses `CMGT_CFG_*`, AiDocumentCenter uses `AIA_*`.
**Fix**: Changed heuristic — any table with INSERT statements in the DDL script is reference data (transactional tables never have INSERTs in DDL scripts).

### 7. Inline PRIMARY KEY Not Detected
**Problem**: `EVALUATION_ID int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY` — PK defined inline on column, not as separate clause.
**Fix**: After parsing each column definition, check if `PRIMARY KEY` appears in the column's definition text.

---

## Alternatives Evaluated

### simple-ddl-parser (PLY-based library)
- **Tested**: Built complete alternative implementation in `schema-alt/`
- **Result**: 16x slower (0.48s vs 0.03s), fewer tables (103 vs 105), fewer columns (863 vs 940), far fewer FKs (87 vs 173)
- **Root cause**: Library can't process ALTER TABLE standalone — requires CREATE TABLE in same input. Multi-clause ALTER TABLE not supported. Required extensive workarounds that negated the simplicity benefit.
- **Decision**: Rejected. Our regex approach is faster, more complete, and handles the specific patterns in these scripts better.

### SQLite/MariaDB Execution
- **Evaluated**: Run scripts against a real DB engine and introspect INFORMATION_SCHEMA
- **Result**: Not viable — scripts are MySQL/MariaDB syntax (not SQLite compatible), and MariaDB can't be embedded in Python (requires external server)
- **Decision**: Rejected. Would add Docker dependency and lose column comments/type precision.

---

## Remaining Known Limitations

1. **Reference data duplication** — Later INSERT statements with same PK values append rather than replace. The data is all present but may have duplicates for the same ID. For the AI agent's use case (knowing valid values), this is acceptable.

2. **Topological sort violations** — Real schemas have circular FK dependencies (audit tables referencing each other). The sort places cycles at the end. ~20-40 violations per app out of 100-300 relationships is normal.

3. **ConnectedUnderwriting** — Uses nested ZIP format without a `scripts/` folder. Returns `None` (no schema). This application would need a different approach if schema extraction is needed.

---

## Files Modified

| File | Change |
|------|--------|
| `appian_parser/schema/__init__.py` | New — exports SchemaBuilder |
| `appian_parser/schema/models.py` | New — dataclasses + tables_as_dict() |
| `appian_parser/schema/script_finder.py` | New — locates scripts in package |
| `appian_parser/schema/statement_parser.py` | New — DELIMITER extraction + line-based splitting |
| `appian_parser/schema/ddl_replay_engine.py` | New — DDL replay with all ALTER TABLE variants |
| `appian_parser/schema/schema_builder.py` | New — orchestration + topo sort + classification |
| `appian_parser/cli.py` | Modified — added schema extraction after enrichment phase |
| `tests/schema/__init__.py` | New — test package |
| `tests/schema/test_schema.py` | New — 38 tests |

---

## What's Next (Phase 2 Prerequisites)

The schema output is ready for consumption by:
1. **Atlas MCP Server** — add tools to query schema data (`get_app_schema`, `get_reference_data`, `get_insertion_order`)
2. **Data Generator MCP** — uses schema for understanding table relationships and valid reference values
3. **CI Sync Pipeline** — schema will be generated automatically on next sync run (no pipeline changes needed)
