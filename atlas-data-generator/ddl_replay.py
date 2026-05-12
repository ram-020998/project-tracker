"""DDL Replay Engine — parses an incremental Appian DDL script and outputs the final schema state."""

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Column:
    name: str
    data_type: str
    nullable: bool = True
    default: str | None = None
    auto_increment: bool = False
    comment: str | None = None


@dataclass
class ForeignKey:
    name: str | None
    columns: list[str]
    ref_table: str
    ref_columns: list[str]


@dataclass
class Table:
    name: str
    columns: dict[str, Column] = field(default_factory=dict)
    primary_key: list[str] = field(default_factory=list)
    foreign_keys: list[ForeignKey] = field(default_factory=list)
    comment: str | None = None


@dataclass
class RefDataRow:
    table: str
    values: dict[str, str]


class DDLReplayEngine:
    def __init__(self):
        self.tables: dict[str, Table] = {}
        self.reference_data: dict[str, list[dict]] = {}
        self._rename_map: dict[str, str] = {}  # old_name -> new_name

    def replay(self, sql_path: str) -> dict:
        """Replay the DDL script and return the final schema state."""
        content = Path(sql_path).read_text(encoding="utf-8", errors="replace")
        # Normalize: collapse multi-line statements
        # Remove DELIMITER blocks (stored procedures) — we don't need them for schema
        content = self._strip_delimiter_blocks(content)
        statements = self._split_statements(content)

        for stmt in statements:
            # Strip leading SQL comments
            clean = re.sub(r"^(\s*--[^\n]*\n)+", "", stmt).strip()
            clean_upper = clean.upper()
            if clean_upper.startswith("CREATE TABLE"):
                self._handle_create_table(clean)
            elif clean_upper.startswith("ALTER TABLE"):
                self._handle_alter_table(clean)
            elif clean_upper.startswith("DROP TABLE"):
                self._handle_drop_table(clean)
            elif clean_upper.startswith("INSERT INTO"):
                self._handle_insert(clean)
            elif clean_upper.startswith("UPDATE"):
                self._handle_update(clean)

        return self._build_output()

    def _strip_delimiter_blocks(self, content: str) -> str:
        """Extract SQL from script content blocks and top-level statements.
        
        The GAM framework wraps DDL in stored procedures with markers:
          -- START SCRIPT CONTENT ---
          <actual SQL>
          -- END SCRIPT CONTENT ---
        
        We extract those blocks plus any top-level statements outside DELIMITER blocks.
        """
        result = []
        in_delimiter_block = False
        in_script_content = False

        for line in content.split("\n"):
            stripped = line.strip()
            stripped_upper = stripped.upper()

            # Track DELIMITER blocks
            if stripped_upper.startswith("DELIMITER $$") or stripped_upper == "DELIMITER $$":
                in_delimiter_block = True
                continue
            if in_delimiter_block and (stripped_upper.startswith("DELIMITER ;") or stripped_upper == "DELIMITER ;"):
                in_delimiter_block = False
                in_script_content = False
                continue

            if in_delimiter_block:
                # Look for script content markers
                if "START SCRIPT CONTENT" in stripped:
                    in_script_content = True
                    continue
                if "END SCRIPT CONTENT" in stripped:
                    in_script_content = False
                    continue
                if in_script_content:
                    result.append(line)
            else:
                # Top-level statements (framework tables, CALL statements)
                result.append(line)

        return "\n".join(result)

    def _split_statements(self, content: str) -> list[str]:
        """Split SQL into individual statements on semicolons, respecting strings."""
        statements = []
        current = []
        in_string = False
        escape_next = False
        for char in content:
            if escape_next:
                current.append(char)
                escape_next = False
                continue
            if char == "\\":
                current.append(char)
                escape_next = True
                continue
            if char in ("'", '"') and not in_string:
                in_string = char
                current.append(char)
                continue
            if char == in_string:
                in_string = False
                current.append(char)
                continue
            if char == ";" and not in_string:
                stmt = "".join(current).strip()
                if stmt:
                    statements.append(stmt)
                current = []
                continue
            current.append(char)
        return statements

    def _handle_create_table(self, stmt: str):
        m = re.match(
            r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(\w+)`?",
            stmt, re.IGNORECASE
        )
        if not m:
            return
        table_name = m.group(1)
        # Skip if already exists (IF NOT EXISTS semantics)
        if table_name in self.tables:
            return

        table = Table(name=table_name)

        # Extract table comment
        tc = re.search(r"\)\s*COMMENT\s+[\"'](.+?)[\"']\s*$", stmt, re.IGNORECASE)
        if tc:
            table.comment = tc.group(1)

        # Extract column definitions from between ( ... )
        body_match = re.search(r"\((.*)\)", stmt, re.DOTALL)
        if not body_match:
            self.tables[table_name] = table
            return

        body = body_match.group(1)
        # Split on commas that are not inside parentheses
        parts = self._split_column_defs(body)

        for part in parts:
            part = part.strip()
            part_upper = part.upper()

            if part_upper.startswith("PRIMARY KEY"):
                cols = re.findall(r"`(\w+)`", part)
                table.primary_key = cols
            elif part_upper.startswith("FOREIGN KEY") or part_upper.startswith("CONSTRAINT"):
                fk = self._parse_fk_inline(part)
                if fk:
                    table.foreign_keys.append(fk)
            elif part_upper.startswith("KEY ") or part_upper.startswith("INDEX ") or part_upper.startswith("UNIQUE"):
                continue  # skip index definitions
            else:
                col = self._parse_column_def(part)
                if col:
                    table.columns[col.name] = col
                    # Check inline PRIMARY KEY
                    if "PRIMARY KEY" in part.upper():
                        table.primary_key = [col.name]

        self.tables[table_name] = table

    def _split_column_defs(self, body: str) -> list[str]:
        """Split column definitions by comma, respecting parentheses depth."""
        parts = []
        current = []
        depth = 0
        for char in body:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            elif char == "," and depth == 0:
                parts.append("".join(current))
                current = []
                continue
            current.append(char)
        if current:
            parts.append("".join(current))
        return parts

    def _parse_column_def(self, part: str) -> Column | None:
        m = re.match(r"`?(\w+)`?\s+(.+)", part.strip(), re.IGNORECASE | re.DOTALL)
        if not m:
            return None
        name = m.group(1)
        rest = m.group(2)

        # Skip SQL keywords that aren't column names
        if name.upper() in ("PRIMARY", "KEY", "INDEX", "UNIQUE", "CONSTRAINT", "FOREIGN", "CHECK"):
            return None

        # Extract data type
        type_match = re.match(r"([\w]+(?:\([^)]*\))?)", rest, re.IGNORECASE)
        data_type = type_match.group(1) if type_match else "UNKNOWN"

        rest_upper = rest.upper()
        nullable = "NOT NULL" not in rest_upper
        auto_increment = "AUTO_INCREMENT" in rest_upper

        default = None
        def_match = re.search(r"DEFAULT\s+(.+?)(?:\s+COMMENT|\s+AUTO_INCREMENT|\s+ON\s|$)", rest, re.IGNORECASE)
        if def_match:
            default = def_match.group(1).strip().strip("'\"")

        comment = None
        cmt_match = re.search(r"COMMENT\s+[\"'](.+?)[\"']", rest, re.IGNORECASE)
        if cmt_match:
            comment = cmt_match.group(1)

        return Column(name=name, data_type=data_type, nullable=nullable,
                      default=default, auto_increment=auto_increment, comment=comment)

    def _parse_fk_inline(self, part: str) -> ForeignKey | None:
        # CONSTRAINT `name` FOREIGN KEY (`col`) REFERENCES `table`(`col`)
        # or FOREIGN KEY (`col`) REFERENCES `table`(`col`)
        name_match = re.search(r"CONSTRAINT\s+`?(\w+)`?", part, re.IGNORECASE)
        fk_name = name_match.group(1) if name_match else None

        cols_match = re.search(r"FOREIGN\s+KEY\s*(?:IF\s+NOT\s+EXISTS\s*)?\(([^)]+)\)", part, re.IGNORECASE)
        ref_match = re.search(r"REFERENCES\s+`?(\w+)`?\s*\(([^)]+)\)", part, re.IGNORECASE)

        if not cols_match or not ref_match:
            return None

        columns = [c.strip().strip("`") for c in cols_match.group(1).split(",")]
        ref_table = ref_match.group(1)
        ref_columns = [c.strip().strip("`") for c in ref_match.group(2).split(",")]

        return ForeignKey(name=fk_name, columns=columns, ref_table=ref_table, ref_columns=ref_columns)

    def _split_alter_clauses(self, rest: str) -> list[str]:
        """Split multi-clause ALTER TABLE body by top-level commas.
        
        E.g.: ADD KEY `x` (`col`), ADD CONSTRAINT `y` FOREIGN KEY (`col`) REFERENCES `t`(`c`)
        """
        clauses = []
        current = []
        depth = 0
        for char in rest:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            elif char == "," and depth == 0:
                clauses.append("".join(current).strip())
                current = []
                continue
            current.append(char)
        if current:
            clauses.append("".join(current).strip())
        return clauses

    def _apply_alter_clause(self, table: Table, clause: str):
        """Apply a single ALTER TABLE clause."""
        clause_upper = clause.upper()

        # ADD COLUMN
        add_col = re.match(r"ADD\s+COLUMN\s+`?(\w+)`?\s+(.+)", clause, re.IGNORECASE | re.DOTALL)
        if add_col:
            col_name = add_col.group(1)
            col_rest = add_col.group(2)
            col_rest = re.sub(r"\s+AFTER\s+`?\w+`?", "", col_rest, flags=re.IGNORECASE)
            col = self._parse_column_def(f"`{col_name}` {col_rest}")
            if col:
                table.columns[col.name] = col
            return

        # MODIFY COLUMN
        mod_col = re.match(r"MODIFY\s+(?:COLUMN\s+)?`?(\w+)`?\s+(.+)", clause, re.IGNORECASE | re.DOTALL)
        if mod_col:
            col_name = mod_col.group(1)
            col_rest = mod_col.group(2)
            col_rest = re.sub(r"\s+AFTER\s+`?\w+`?", "", col_rest, flags=re.IGNORECASE)
            col = self._parse_column_def(f"`{col_name}` {col_rest}")
            if col:
                table.columns[col_name] = col
            return

        # DROP COLUMN
        drop_col = re.match(r"DROP\s+COLUMN\s+`?(\w+)`?", clause, re.IGNORECASE)
        if drop_col:
            table.columns.pop(drop_col.group(1), None)
            return

        # ADD CONSTRAINT / FOREIGN KEY
        if "FOREIGN KEY" in clause_upper:
            fk = self._parse_fk_inline(clause)
            if fk:
                table.foreign_keys.append(fk)
            return

        # DROP FOREIGN KEY / DROP CONSTRAINT
        drop_fk = re.match(r"DROP\s+(?:FOREIGN\s+KEY|CONSTRAINT)\s+`?(\w+)`?", clause, re.IGNORECASE)
        if drop_fk:
            fk_name = drop_fk.group(1)
            table.foreign_keys = [fk for fk in table.foreign_keys if fk.name != fk_name]
            return

        # ADD KEY / ADD INDEX / ADD UNIQUE — skip
        # DROP INDEX — skip

    def _handle_alter_table(self, stmt: str):
        m = re.match(r"ALTER\s+TABLE\s+`?(\w+)`?", stmt, re.IGNORECASE)
        if not m:
            return
        table_name = m.group(1)
        # Resolve renames
        table_name = self._resolve_name(table_name)

        rest = stmt[m.end():].strip()
        rest_upper = rest.upper()

        # RENAME TABLE (not COLUMN, not INDEX)
        rename_match = re.match(r"RENAME\s+(?:TO\s+)?`?(\w+)`?", rest, re.IGNORECASE)
        if rename_match and "COLUMN" not in rest_upper.split("RENAME", 1)[1][:10] and "INDEX" not in rest_upper.split("RENAME", 1)[1][:10]:
            new_name = rename_match.group(1)
            if table_name in self.tables:
                table = self.tables.pop(table_name)
                table.name = new_name
                self.tables[new_name] = table
            self._rename_map[table_name] = new_name
            return

        # RENAME COLUMN
        col_rename = re.match(r"RENAME\s+COLUMN\s+`?(\w+)`?\s+TO\s+`?(\w+)`?", rest, re.IGNORECASE)
        if col_rename:
            old_col, new_col = col_rename.group(1), col_rename.group(2)
            table = self.tables.get(table_name)
            if table and old_col in table.columns:
                col = table.columns.pop(old_col)
                col.name = new_col
                table.columns[new_col] = col
            return

        # RENAME INDEX — skip (doesn't affect schema)
        if re.match(r"RENAME\s+INDEX", rest, re.IGNORECASE):
            return

        table = self.tables.get(table_name)
        if not table:
            table = Table(name=table_name)
            self.tables[table_name] = table

        # Handle multi-clause ALTER TABLE (clauses separated by commas at top level)
        clauses = self._split_alter_clauses(rest)
        for clause in clauses:
            self._apply_alter_clause(table, clause)

    def _handle_drop_table(self, stmt: str):
        m = re.match(r"DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?`?(\w+)`?", stmt, re.IGNORECASE)
        if m:
            name = self._resolve_name(m.group(1))
            self.tables.pop(name, None)

    def _handle_insert(self, stmt: str):
        """Track INSERT INTO reference tables."""
        m = re.match(r"INSERT\s+INTO\s+`?(\w+)`?\s*\(([^)]+)\)\s*VALUES\s*(.+)", stmt, re.IGNORECASE | re.DOTALL)
        if not m:
            return
        raw_table_name = m.group(1)
        table_name = self._resolve_name(raw_table_name)
        columns = [c.strip().strip("`") for c in m.group(2).split(",")]
        values_str = m.group(3)

        # Only track reference tables (R_ pattern) and skip script execution tables
        if "_R_" not in table_name and "_R_" not in raw_table_name:
            return
        if "ScriptExecution" in table_name:
            return

        if table_name not in self.reference_data:
            self.reference_data[table_name] = []

        # Parse value tuples
        for val_match in re.finditer(r"\(([^)]+)\)", values_str):
            vals = self._parse_value_tuple(val_match.group(1))
            if len(vals) == len(columns):
                row = dict(zip(columns, vals))
                self.reference_data[table_name].append(row)

    def _handle_update(self, stmt: str):
        """Track UPDATE on reference tables."""
        m = re.match(r"UPDATE\s+`?(\w+)`?\s+SET\s+(.+?)\s+WHERE\s+(.+)", stmt, re.IGNORECASE | re.DOTALL)
        if not m:
            return
        raw_table_name = m.group(1)
        table_name = self._resolve_name(raw_table_name)
        if "_R_" not in table_name and "_R_" not in raw_table_name:
            return
        if table_name not in self.reference_data:
            return

        set_clause = m.group(2)
        where_clause = m.group(3)

        # Parse SET assignments
        updates = {}
        for assign in re.finditer(r"`?(\w+)`?\s*=\s*([^,]+)", set_clause):
            updates[assign.group(1)] = assign.group(2).strip().strip("'\"")

        # Parse WHERE (simple equality only)
        conditions = {}
        for cond in re.finditer(r"`?(\w+)`?\.?`?(\w+)?`?\s*=\s*([^AND]+)", where_clause, re.IGNORECASE):
            col = cond.group(2) or cond.group(1)
            val = cond.group(3).strip().strip("'\"")
            conditions[col] = val

        # Apply updates to matching rows
        for row in self.reference_data[table_name]:
            match = all(row.get(k) == v for k, v in conditions.items())
            if match:
                row.update(updates)

    def _parse_value_tuple(self, val_str: str) -> list[str]:
        """Parse a VALUES tuple, handling quoted strings with commas."""
        values = []
        current = []
        in_string = False
        for char in val_str:
            if char in ("'", '"') and not in_string:
                in_string = char
                continue
            if char == in_string:
                in_string = False
                continue
            if char == "," and not in_string:
                values.append("".join(current).strip())
                current = []
                continue
            current.append(char)
        if current:
            values.append("".join(current).strip())
        return values

    def _resolve_name(self, name: str) -> str:
        """Follow rename chain to get current table name."""
        while name in self._rename_map:
            name = self._rename_map[name]
        return name

    def _build_output(self) -> dict:
        """Build the final output structure."""
        # Consolidate reference data under final table names
        consolidated_ref: dict[str, list[dict]] = {}
        for raw_name, rows in self.reference_data.items():
            final_name = self._resolve_name(raw_name)
            if final_name not in consolidated_ref:
                consolidated_ref[final_name] = []
            consolidated_ref[final_name].extend(rows)
        self.reference_data = consolidated_ref

        # Build FK graph for topological sort
        tables_json = {}
        relationships = []

        for name, table in sorted(self.tables.items()):
            tables_json[name] = {
                "columns": {
                    col.name: {
                        "type": col.data_type,
                        "nullable": col.nullable,
                        "auto_increment": col.auto_increment,
                        **({"default": col.default} if col.default else {}),
                        **({"comment": col.comment} if col.comment else {}),
                    }
                    for col in table.columns.values()
                },
                "primary_key": table.primary_key,
                **({"comment": table.comment} if table.comment else {}),
            }

            for fk in table.foreign_keys:
                ref_table = self._resolve_name(fk.ref_table)
                relationships.append({
                    "from_table": name,
                    "from_columns": fk.columns,
                    "to_table": ref_table,
                    "to_columns": fk.ref_columns,
                    **({"name": fk.name} if fk.name else {}),
                })

        # Topological sort
        insertion_order = self._topological_sort(tables_json, relationships)

        # Classify tables
        classification = {}
        for name in tables_json:
            if "ScriptExecution" in name:
                classification[name] = "framework"
            elif "_A_R_" in name or "_AUDIT" in name:
                classification[name] = "audit"
            elif "_R_" in name:
                classification[name] = "reference"
            elif "_TMG_" in name:
                classification[name] = "task_management"
            else:
                classification[name] = "business"

        return {
            "tables": tables_json,
            "relationships": relationships,
            "reference_data": self.reference_data,
            "insertion_order": insertion_order,
            "table_classification": classification,
            "summary": {
                "total_tables": len(tables_json),
                "business_tables": sum(1 for v in classification.values() if v == "business"),
                "reference_tables": sum(1 for v in classification.values() if v == "reference"),
                "audit_tables": sum(1 for v in classification.values() if v == "audit"),
                "task_management_tables": sum(1 for v in classification.values() if v == "task_management"),
                "framework_tables": sum(1 for v in classification.values() if v == "framework"),
                "total_relationships": len(relationships),
                "total_reference_data_rows": sum(len(v) for v in self.reference_data.values()),
            },
        }

    def _topological_sort(self, tables: dict, relationships: list) -> list[str]:
        """Topological sort based on FK dependencies."""
        # Build adjacency: child depends on parent
        deps: dict[str, set[str]] = {name: set() for name in tables}
        for rel in relationships:
            if rel["from_table"] in deps and rel["to_table"] in tables:
                deps[rel["from_table"]].add(rel["to_table"])

        # Kahn's algorithm
        in_degree = {name: 0 for name in tables}
        for name, parents in deps.items():
            in_degree[name] = len(parents)

        queue = [n for n, d in in_degree.items() if d == 0]
        result = []

        while queue:
            queue.sort()  # deterministic
            node = queue.pop(0)
            result.append(node)
            for name, parents in deps.items():
                if node in parents:
                    parents.discard(node)
                    in_degree[name] -= 1
                    if in_degree[name] == 0:
                        queue.append(name)

        # Add any remaining (circular deps)
        remaining = [n for n in tables if n not in result]
        result.extend(sorted(remaining))
        return result


def main():
    if len(sys.argv) < 2:
        print("Usage: python ddl_replay.py <sql_file> [output_dir]")
        sys.exit(1)

    sql_path = sys.argv[1]
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("schema_output")
    output_dir.mkdir(parents=True, exist_ok=True)

    engine = DDLReplayEngine()
    result = engine.replay(sql_path)

    # Write individual files
    for key in ("tables", "relationships", "reference_data", "insertion_order", "table_classification", "summary"):
        out_path = output_dir / f"{key}.json"
        with open(out_path, "w") as f:
            json.dump(result[key], f, indent=2)
        print(f"  {out_path} ({len(json.dumps(result[key]))} bytes)")

    print(f"\nSummary:")
    for k, v in result["summary"].items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
