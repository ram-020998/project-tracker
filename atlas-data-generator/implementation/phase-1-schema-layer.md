# Phase 1: Schema Layer — Integration into Atlas Parser

## Objective

Integrate the DDL replay engine into the `solutions-atlas-parser` pipeline so that every application parse automatically produces a structured `schema/` output section in the Atlas KB. This gives AI agents complete understanding of the database structure, relationships, and reference data without any runtime API calls.

---

## What Already Exists

- **DDL Replay Engine prototype** (`ddl_replay.py`) — validated against Source Selection v2.9.0, produces correct output
- **Atlas Parser** (`solutions-atlas-parser`) — already extracts and processes the application ZIP
- **Script files in ZIP** — located in the `scripts/` folder inside every Appian application package
- **Atlas KB output structure** — `data/<AppName>/current/` with bundles, objects, search_index, etc.

---

## Deliverables

1. `appian_parser/schema/` — new module in the parser containing the DDL replay engine
2. Schema output files written to `data/<AppName>/current/schema/` in the KB
3. Schema-related MCP tools added to `solutions-atlas-mcp-server`
4. CLI flag to enable/disable schema parsing

---

## Implementation Steps

### Step 1: Locate Script Files in the ZIP

The parser's `PackageReader` already extracts the ZIP to a temp directory. We need to find the SQL script file(s) in the `scripts/` folder.

**Location in ZIP structure:**
```
AppName.zip/
├── appian/                    ← application objects (already parsed)
│   ├── interfaces/
│   ├── processModels/
│   ├── recordTypes/
│   └── ...
└── scripts/                   ← DDL scripts (NEW — parse these)
    └── 01.SourceSelectionv2.9.0.sql
```

**Implementation:**

```python
# In appian_parser/schema/script_finder.py

from pathlib import Path


def find_ddl_scripts(package_root: Path) -> list[Path]:
    """Find SQL DDL scripts in the package's scripts/ folder.
    
    Returns scripts sorted by filename (01.*.sql, 02.*.sql, etc.)
    for sequential execution order.
    """
    scripts_dir = package_root / "scripts"
    if not scripts_dir.exists():
        return []
    
    scripts = sorted(
        scripts_dir.glob("*.sql"),
        key=lambda p: p.name
    )
    return scripts
```

**Edge cases:**
- No `scripts/` folder → return empty schema (some older packages may not have scripts)
- Multiple `.sql` files → process sequentially by filename sort order
- Non-DDL scripts (data migration scripts, one-off fixes) → the replay engine handles these gracefully since it only processes CREATE TABLE, ALTER TABLE, INSERT, UPDATE

---

### Step 2: Integrate DDL Replay Engine into Parser Module

Move the prototype `ddl_replay.py` into the parser as a proper module.

**File structure:**
```
appian_parser/
├── schema/
│   ├── __init__.py
│   ├── script_finder.py      ← locates scripts in ZIP
│   ├── ddl_replay.py         ← the replay engine (from prototype)
│   ├── schema_builder.py     ← orchestrates parsing and builds output
│   └── models.py             ← dataclasses for Table, Column, ForeignKey, etc.
```

**Key changes from prototype to production:**

1. **Extract models to separate file** — `Table`, `Column`, `ForeignKey` dataclasses move to `models.py`
2. **Add error handling** — malformed SQL should log warnings, not crash the parse
3. **Add progress logging** — report tables found, relationships extracted, etc.
4. **Handle encoding issues** — some scripts may have non-UTF8 characters
5. **Performance** — the 11,500-line script parses in <1 second, so no optimization needed

---

### Step 3: Schema Builder — Orchestration Layer

The schema builder coordinates script finding, DDL replay, and output generation.

```python
# In appian_parser/schema/schema_builder.py

from pathlib import Path
from .script_finder import find_ddl_scripts
from .ddl_replay import DDLReplayEngine


class SchemaBuilder:
    """Orchestrates DDL script parsing and schema output generation."""

    def build(self, package_root: Path) -> dict | None:
        """Parse DDL scripts and return structured schema data.
        
        Returns None if no scripts found.
        """
        scripts = find_ddl_scripts(package_root)
        if not scripts:
            return None

        engine = DDLReplayEngine()
        
        # Process scripts sequentially
        for script_path in scripts:
            engine.replay(str(script_path))

        return engine.get_output()
```

---

### Step 4: Wire into the CLI Pipeline

The parser's main orchestration is in `appian_parser/cli.py` → `dump_package()`. Add schema parsing after the main object parsing phase.

**Integration point in `cli.py`:**

```python
def dump_package(zip_path: str, output_dir: str, options: DumpOptions) -> DumpResult:
    # ... existing phases (ACQUIRE, PARSE, RESOLVE, ENRICH, OUTPUT) ...

    # === NEW PHASE: SCHEMA ===
    from appian_parser.schema.schema_builder import SchemaBuilder
    
    schema_builder = SchemaBuilder()
    schema_data = schema_builder.build(contents.root_path)
    
    if schema_data:
        schema_dir = Path(output_dir) / "schema"
        schema_dir.mkdir(parents=True, exist_ok=True)
        
        for key, data in schema_data.items():
            out_path = schema_dir / f"{key}.json"
            with open(out_path, "w") as f:
                json.dump(data, f, indent=2)
```

**CLI flag:**
```
appian-parser dump package.zip --output ./out --include-schema
```

Default: schema parsing enabled (since it adds <1 second to parse time).

---

### Step 5: Output File Structure

The schema output goes into the KB at `data/<AppName>/current/schema/`:

```
data/SourceSelection/current/
├── app_overview.json          ← existing
├── search_index.json          ← existing
├── bundles/                   ← existing
├── objects/                   ← existing
├── orphans/                   ← existing
├── enrichment/                ← existing
└── schema/                    ← NEW
    ├── tables.json            ← all table definitions (final state after replay)
    ├── relationships.json     ← all FK relationships
    ├── reference_data.json    ← all reference/lookup table data
    ├── insertion_order.json   ← topologically sorted table list
    ├── table_classification.json  ← tables categorized by type
    └── summary.json           ← stats (table counts, relationship counts, etc.)
```

**File specifications:**

#### `tables.json`
```json
{
  "AS_GSS_EVALUATION": {
    "columns": {
      "EVALUATION_ID": {
        "type": "int(11)",
        "nullable": false,
        "auto_increment": true,
        "comment": "Primary key"
      },
      "EVALUATION_TITLE": {
        "type": "varchar(255)",
        "nullable": true
      },
      "EVALUATION_STATUS_ID": {
        "type": "int(11)",
        "nullable": true
      }
    },
    "primary_key": ["EVALUATION_ID"]
  }
}
```

#### `relationships.json`
```json
[
  {
    "from_table": "AS_GSS_EVALUATION",
    "from_columns": ["EVALUATION_STATUS_ID"],
    "to_table": "AS_GSS_R_DATA",
    "to_columns": ["REF_DATA_ID"],
    "name": "asgssevalatin_evalatinstats"
  }
]
```

#### `reference_data.json`
```json
{
  "AS_GSS_R_DATA": [
    {
      "REF_DATA_ID": "1",
      "REF_LABEL": "Setting up",
      "REF_TYPE": "Evaluation Status",
      "IS_ACTIVE": "1"
    },
    {
      "REF_DATA_ID": "4",
      "REF_LABEL": "Least Price Technically Acceptable",
      "REF_TYPE": "Evaluation Method",
      "IS_ACTIVE": "1"
    }
  ]
}
```

#### `insertion_order.json`
```json
[
  "AS_GSS_USER",
  "AS_GSS_R_DATA",
  "AS_GSS_R_RATING",
  "AS_GSS_EVALUATION",
  "AS_GSS_CRITERIA",
  "AS_GSS_EVALUATION_PHASE",
  "AS_GSS_EVALUATION_VENDOR",
  "AS_GSS_EVALUATOR_TEAM",
  "AS_GSS_TEAM_MEMBERSHIP",
  "AS_GSS_CRITERIA_ASSIGNMENTS"
]
```

#### `table_classification.json`
```json
{
  "AS_GSS_EVALUATION": "business",
  "AS_GSS_R_DATA": "reference",
  "AS_GSS_A_R_EVALUATION": "audit",
  "AS_GSS_TMG_TASK": "task_management",
  "AS_GSS_ScriptExecutionHistory": "framework"
}
```

#### `summary.json`
```json
{
  "total_tables": 84,
  "business_tables": 18,
  "reference_tables": 17,
  "audit_tables": 37,
  "task_management_tables": 10,
  "framework_tables": 2,
  "total_relationships": 153,
  "total_reference_data_rows": 216,
  "script_files_processed": ["01.SourceSelectionv2.9.0.sql"],
  "parse_timestamp": "2026-05-12T18:00:00Z"
}
```

---

### Step 6: Add Schema Tools to Atlas MCP Server

Add new tools to `solutions-atlas-mcp-server` that expose the schema data.

**New tools:**

| Tool | Description |
|------|-------------|
| `get_app_schema` | Returns table definitions, optionally filtered by classification |
| `get_table_details` | Returns full column definitions and FKs for a specific table |
| `get_relationships` | Returns FK relationships, optionally filtered by table |
| `get_reference_data` | Returns reference data for a specific table or all tables |
| `get_insertion_order` | Returns the topologically sorted table list |

**Implementation in `atlas_mcp/tools/schema.py`:**

```python
class SchemaTools:

    @staticmethod
    async def get_app_schema(arguments: dict) -> list:
        """Get table definitions for an application."""
        app_name = arguments["app_name"]
        classification = arguments.get("classification")  # optional filter
        
        ds = _datasource()
        tables = ds.read_json(app_name, "current/schema/tables.json")
        classification_map = ds.read_json(app_name, "current/schema/table_classification.json")
        
        if classification:
            tables = {k: v for k, v in tables.items() 
                     if classification_map.get(k) == classification}
        
        return format_json_response(tables)

    @staticmethod
    async def get_reference_data(arguments: dict) -> list:
        """Get reference data values for lookup tables."""
        app_name = arguments["app_name"]
        table_name = arguments.get("table_name")
        ref_type = arguments.get("ref_type")  # filter by REF_TYPE value
        
        ds = _datasource()
        ref_data = ds.read_json(app_name, "current/schema/reference_data.json")
        
        if table_name:
            ref_data = {table_name: ref_data.get(table_name, [])}
        
        if ref_type:
            for table, rows in ref_data.items():
                ref_data[table] = [r for r in rows if r.get("REF_TYPE") == ref_type]
        
        return format_json_response(ref_data)

    @staticmethod
    async def get_insertion_order(arguments: dict) -> list:
        """Get topologically sorted table insertion order."""
        app_name = arguments["app_name"]
        ds = _datasource()
        order = ds.read_json(app_name, "current/schema/insertion_order.json")
        return format_json_response(order)
```

**Register in `atlas_mcp/server.py`:**
```python
from .tools.schema import SchemaTools

# Add to tool_handlers dict:
"get_app_schema": SchemaTools.get_app_schema,
"get_table_details": SchemaTools.get_table_details,
"get_relationships": SchemaTools.get_relationships,
"get_reference_data": SchemaTools.get_reference_data,
"get_insertion_order": SchemaTools.get_insertion_order,
```

---

### Step 7: Update the Sync Pipeline

The CI sync pipeline (`sync_packages.py`) already downloads packages and runs the parser. Since schema parsing is integrated into the parser's `dump_package()` function, no pipeline changes are needed — the schema output will be generated automatically on the next sync.

**Verification:** After the next sync run, confirm that `data/SourceSelection/current/schema/` exists in the KB with all expected files.

---

## Testing Strategy

### Unit Tests

```
tests/schema/
├── __init__.py
├── test_script_finder.py      ← finds scripts in mock ZIP structures
├── test_ddl_replay.py         ← tests each DDL statement type
├── test_schema_builder.py     ← integration test with real script
└── conftest.py                ← fixtures with sample SQL snippets
```

**Key test cases for DDL replay:**
- CREATE TABLE with all column types
- ALTER TABLE ADD COLUMN
- ALTER TABLE MODIFY COLUMN
- ALTER TABLE DROP COLUMN
- ALTER TABLE RENAME (table, column, index)
- ALTER TABLE ADD CONSTRAINT FOREIGN KEY
- ALTER TABLE DROP FOREIGN KEY
- Multi-clause ALTER TABLE (comma-separated)
- INSERT INTO reference tables
- UPDATE reference tables
- Table rename followed by INSERT using old name
- GAM Script Execution Framework wrapper extraction
- IF NOT EXISTS / IF EXISTS handling
- Empty scripts folder
- Multiple script files processed sequentially

### Integration Test

Run the full parser against the Source Selection test package and verify:
- `schema/tables.json` has 84 tables
- `schema/relationships.json` has 153 relationships
- `schema/reference_data.json` has 216 rows across 10 tables
- `schema/insertion_order.json` has 0 topological violations
- All business tables have correct column counts

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Move prototype to parser module structure | 2 hours |
| Add script finder + integration into CLI | 1 hour |
| Add error handling and logging | 1 hour |
| Write unit tests | 3 hours |
| Add MCP tools to atlas-mcp-server | 2 hours |
| Integration testing with real package | 1 hour |
| **Total** | **~10 hours (1.5 days)** |

---

## Dependencies

- None — this phase has no external dependencies
- Can be developed and tested entirely with the existing Source Selection test package

## Risks

- **Script format variations across applications** — Other applications may have slightly different script patterns. Mitigated by testing against multiple app packages (CaseManagementStudio, AwardManagement, etc.)
- **Very large scripts** — Some applications may have much larger scripts. The prototype handles 11,500 lines in <1 second, so this is unlikely to be an issue.
