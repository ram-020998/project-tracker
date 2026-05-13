"""Alternative schema extraction using simple-ddl-parser.

Uses a proper lexer/parser (PLY) for DDL parsing instead of regex.
Still uses our own StatementParser for DELIMITER block extraction
and custom INSERT/UPDATE handling for reference data.
"""

from __future__ import annotations

import json
import logging
import re
import sys
import tempfile
import zipfile
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

logging.disable(logging.CRITICAL)  # Suppress PLY debug output
from simple_ddl_parser import DDLParser


# ─── Models ──────────────────────────────────────────────────────────────────


@dataclass
class Column:
    name: str
    data_type: str
    size: int | None = None
    nullable: bool = True
    default: str | None = None
    auto_increment: bool = False
    comment: str | None = None


@dataclass
class ForeignKey:
    name: str | None
    column: str
    ref_table: str
    ref_column: str


@dataclass
class Table:
    name: str
    columns: dict[str, Column] = field(default_factory=dict)
    primary_key: list[str] = field(default_factory=list)
    foreign_keys: list[ForeignKey] = field(default_factory=list)


@dataclass
class SchemaResult:
    tables: dict[str, Table]
    relationships: list[dict[str, Any]]
    reference_data: dict[str, list[dict[str, Any]]]
    insertion_order: list[str]
    table_classification: dict[str, str]
    summary: dict[str, Any]

    def tables_as_dict(self) -> dict[str, Any]:
        result = {}
        for name, table in self.tables.items():
            result[name] = {
                "columns": {
                    col.name: {
                        "type": f"{col.data_type}({col.size})" if col.size else col.data_type,
                        "nullable": col.nullable,
                        **({"default": col.default} if col.default and col.default != "NULL" else {}),
                        **({"auto_increment": True} if col.auto_increment else {}),
                        **({"comment": col.comment} if col.comment else {}),
                    }
                    for col in table.columns.values()
                },
                "primary_key": table.primary_key,
            }
        return result


# ─── Statement Extractor (from DELIMITER blocks) ─────────────────────────────


class StatementExtractor:
    """Extracts SQL statements from GAM Script Execution Framework scripts."""

    _START_MARKER = "-- START SCRIPT CONTENT ---"
    _END_MARKER = "-- END SCRIPT CONTENT ---"

    def extract(self, sql_content: str) -> list[str]:
        """Extract individual SQL statements from the script."""
        lines = sql_content.split("\n")
        chunks: list[str] = []
        in_delimiter = False
        in_script_content = False

        for line in lines:
            stripped = line.strip()
            stripped_upper = stripped.upper()

            if not in_delimiter and "DELIMITER" in stripped_upper and "$$" in stripped:
                in_delimiter = True
                continue
            if in_delimiter and "DELIMITER" in stripped_upper and ";" in stripped and "$$" not in stripped:
                in_delimiter = False
                in_script_content = False
                continue
            if in_delimiter:
                if self._START_MARKER in line:
                    in_script_content = True
                    continue
                if self._END_MARKER in line:
                    in_script_content = False
                    continue
                if in_script_content:
                    chunks.append(line)
            else:
                if stripped and not stripped.startswith("--"):
                    chunks.append(line)

        # Split on lines ending with semicolons
        raw = "\n".join(chunks)
        return self._split_on_semicolons(raw)

    def _split_on_semicolons(self, text: str) -> list[str]:
        """Split into statements at line-ending semicolons."""
        stmts: list[str] = []
        current: list[str] = []

        for line in text.split("\n"):
            stripped = line.rstrip()
            current.append(line)
            if stripped.endswith(";"):
                stmt = "\n".join(current).strip()
                # Strip leading comments/empty lines
                lines = stmt.split("\n")
                while lines and (not lines[0].strip() or lines[0].strip().startswith("--")):
                    lines.pop(0)
                stmt = "\n".join(lines).strip()
                if stmt:
                    stmts.append(stmt)
                current = []

        # Trailing content
        if current:
            stmt = "\n".join(current).strip()
            lines = stmt.split("\n")
            while lines and (not lines[0].strip() or lines[0].strip().startswith("--")):
                lines.pop(0)
            stmt = "\n".join(lines).strip()
            if stmt:
                stmts.append(stmt)
        return stmts


# ─── DDL Parser (using simple-ddl-parser) ────────────────────────────────────


class DDLSchemaParser:
    """Parses DDL statements using simple-ddl-parser and builds schema state."""

    def __init__(self):
        self._tables: dict[str, Table] = {}
        self._rename_map: dict[str, str] = {}

    def parse_ddl(self, statements: list[str]) -> None:
        """Parse DDL statements using simple-ddl-parser.
        
        Groups CREATE TABLE + ALTER TABLE by table name and feeds them
        together, since simple-ddl-parser requires the table to exist
        in the same input as its ALTER statements.
        """
        # First pass: group statements by table
        creates: dict[str, str] = {}  # table_name -> CREATE statement
        alters: dict[str, list[str]] = defaultdict(list)  # table_name -> ALTER statements

        for stmt in statements:
            upper = stmt.upper().lstrip()

            # Handle renames ourselves
            if upper.startswith("ALTER TABLE") and "RENAME" in upper and "COLUMN" not in upper and "INDEX" not in upper:
                self._handle_rename(stmt)
                continue

            if upper.startswith("CREATE TABLE"):
                m = re.match(r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(\w+)`?", stmt, re.IGNORECASE)
                if m:
                    name = m.group(1)
                    if name not in creates:  # IF NOT EXISTS
                        creates[name] = stmt
            elif upper.startswith("ALTER TABLE"):
                m = re.match(r"ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?`?(\w+)`?", stmt, re.IGNORECASE)
                if m:
                    name = self.resolve_name(m.group(1))
                    for sub in self._split_multi_alter(stmt):
                        alters[name].append(sub)
            elif upper.startswith("DROP TABLE"):
                m = re.match(r"DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?`?(\w+)`?", stmt, re.IGNORECASE)
                if m:
                    name = self.resolve_name(m.group(1))
                    creates.pop(name, None)
                    alters.pop(name, None)
                    self._tables.pop(name, None)

        # Second pass: parse each table's DDL together
        for name, create_stmt in creates.items():
            combined = create_stmt + "\n"
            for alter_stmt in alters.get(name, []):
                combined += alter_stmt + "\n"

            try:
                parsed = DDLParser(combined).run(output_mode="mysql")
                for table_data in parsed:
                    self._process_parsed_table(table_data)
            except Exception:
                # Fallback: just parse the CREATE TABLE
                try:
                    parsed = DDLParser(create_stmt).run(output_mode="mysql")
                    for table_data in parsed:
                        self._process_parsed_table(table_data)
                except Exception:
                    continue

    def _split_multi_alter(self, stmt: str) -> list[str]:
        """Split multi-clause ALTER TABLE into individual statements.
        
        ALTER TABLE t ADD CONSTRAINT fk1 ..., ADD CONSTRAINT fk2 ...;
        becomes:
        ALTER TABLE t ADD CONSTRAINT fk1 ...;
        ALTER TABLE t ADD CONSTRAINT fk2 ...;
        """
        # Extract table name
        m = re.match(r"(ALTER\s+TABLE\s+`?\w+`?)\s+(.*)", stmt, re.IGNORECASE | re.DOTALL)
        if not m:
            return [stmt]
        
        prefix = m.group(1)  # "ALTER TABLE `name`"
        rest = m.group(2)
        
        # Split on commas at top level (not inside parentheses)
        clauses = []
        current: list[str] = []
        depth = 0
        in_quote = False
        for ch in rest:
            if in_quote:
                current.append(ch)
                if ch == "'":
                    in_quote = False
            elif ch == "'":
                current.append(ch)
                in_quote = True
            elif ch == "(":
                depth += 1
                current.append(ch)
            elif ch == ")":
                depth -= 1
                current.append(ch)
            elif ch == "," and depth == 0:
                clauses.append("".join(current).strip())
                current = []
            else:
                current.append(ch)
        if current:
            clauses.append("".join(current).strip().rstrip(";"))

        # Filter to only ADD COLUMN, ADD CONSTRAINT, MODIFY, DROP — skip ADD KEY/INDEX
        result = []
        for clause in clauses:
            clause_upper = clause.upper().strip()
            if clause_upper.startswith(("ADD KEY", "ADD INDEX", "ADD UNIQUE KEY", "DROP INDEX", "RENAME INDEX")):
                continue
            result.append(f"{prefix} {clause};")
        
        return result if result else [stmt]

    def _process_parsed_table(self, data: dict) -> None:
        """Process a single parsed table dict into our Table model."""
        raw_name = data.get("table_name", "")
        if not raw_name:
            return
        name = raw_name.strip("`\"")

        # Handle DROP TABLE
        if data.get("dropped"):
            self._tables.pop(name, None)
            return

        table = self._tables.get(name, Table(name=name))

        # Process columns
        for col_data in data.get("columns", []):
            col_name = col_data.get("name", "").strip("`\"")
            if not col_name:
                continue
            col = Column(
                name=col_name,
                data_type=col_data.get("type", "unknown"),
                size=col_data.get("size"),
                nullable=col_data.get("nullable", True),
                default=col_data.get("default"),
                auto_increment=col_data.get("autoincrement", False),
                comment=col_data.get("comment"),
            )
            table.columns[col_name] = col

            # FK from column references
            refs = col_data.get("references")
            if refs:
                fk = ForeignKey(
                    name=refs.get("constraint_name"),
                    column=col_name,
                    ref_table=refs.get("table", "").strip("`\""),
                    ref_column=refs.get("column", "").strip("`\""),
                )
                if fk.ref_table:
                    table.foreign_keys.append(fk)

        # Primary key
        pk = data.get("primary_key", [])
        if pk:
            table.primary_key = [k.strip("`\"") for k in pk]

        # ALTER section — additional FKs
        alter = data.get("alter", {})
        for alt_col in alter.get("columns", []):
            refs = alt_col.get("references")
            if refs:
                col_name = alt_col.get("name", "").strip("`\"")
                constraint = alt_col.get("constraint_name", "").strip("`\"")
                fk = ForeignKey(
                    name=constraint or None,
                    column=col_name,
                    ref_table=refs.get("table", "").strip("`\""),
                    ref_column=refs.get("column", "").strip("`\""),
                )
                if fk.ref_table:
                    table.foreign_keys.append(fk)

        # Dropped columns from alter
        for dropped in alter.get("dropped_columns", []):
            col_name = dropped.get("name", "").strip("`\"") if isinstance(dropped, dict) else str(dropped).strip("`\"")
            table.columns.pop(col_name, None)

        self._tables[name] = table

    def _handle_rename(self, stmt: str) -> None:
        """Handle ALTER TABLE RENAME TO."""
        m = re.match(r"ALTER\s+TABLE\s+`?(\w+)`?\s+RENAME\s+(?:TO\s+)?`?(\w+)`?", stmt, re.IGNORECASE)
        if m:
            old_name = m.group(1)
            new_name = m.group(2)
            if old_name in self._tables:
                table = self._tables.pop(old_name)
                table.name = new_name
                self._tables[new_name] = table
            self._rename_map[old_name] = new_name

    def get_tables(self) -> dict[str, Table]:
        return dict(self._tables)

    def resolve_name(self, name: str) -> str:
        seen: set[str] = set()
        while name in self._rename_map and name not in seen:
            seen.add(name)
            name = self._rename_map[name]
        return name


# ─── Reference Data Parser ───────────────────────────────────────────────────


class ReferenceDataParser:
    """Parses INSERT/UPDATE statements for reference tables."""

    def __init__(self, name_resolver):
        self._resolver = name_resolver
        self._data: dict[str, list[dict[str, Any]]] = {}

    def parse(self, statements: list[str]) -> None:
        for stmt in statements:
            upper = stmt.upper().lstrip()
            if upper.startswith("INSERT INTO"):
                self._handle_insert(stmt)
            elif upper.startswith("UPDATE"):
                self._handle_update(stmt)

    def _handle_insert(self, stmt: str) -> None:
        m = re.match(r"INSERT\s+INTO\s+`?(\w+)`?\s*\(([^)]+)\)", stmt, re.IGNORECASE)
        if not m:
            return
        table_name = self._resolver(m.group(1))
        if "_R_" not in table_name.upper():
            return

        cols = [c.strip().strip("`") for c in m.group(2).split(",")]
        values_section = stmt[m.end():]

        self._data.setdefault(table_name, [])
        for tup_match in re.finditer(r"\(([^)]*(?:'[^']*'[^)]*)*)\)", values_section):
            vals = self._parse_values(tup_match.group(1))
            if len(vals) == len(cols):
                self._data[table_name].append(dict(zip(cols, vals)))

    def _handle_update(self, stmt: str) -> None:
        m = re.match(r"UPDATE\s+`?(\w+)`?\s+SET\s+(.+?)\s+WHERE\s+(.+)", stmt, re.IGNORECASE | re.DOTALL)
        if not m:
            return
        table_name = self._resolver(m.group(1))
        if "_R_" not in table_name.upper() or table_name not in self._data:
            return

        updates = {}
        for pair in re.finditer(r"`?(\w+)`?\s*=\s*('(?:[^']*)'|\S+)", m.group(2)):
            updates[pair.group(1)] = pair.group(2).strip("'")

        conditions = {}
        for cond in re.finditer(r"`?(\w+)`?\s*=\s*('(?:[^']*)'|\S+)", m.group(3)):
            conditions[cond.group(1)] = cond.group(2).strip("'")

        for row in self._data[table_name]:
            if all(row.get(k) == v for k, v in conditions.items()):
                row.update(updates)

    def _parse_values(self, text: str) -> list[str]:
        values: list[str] = []
        current: list[str] = []
        in_quote = False
        for ch in text:
            if in_quote:
                if ch == "'":
                    in_quote = False
                else:
                    current.append(ch)
            elif ch == "'":
                in_quote = True
            elif ch == ",":
                values.append("".join(current).strip())
                current = []
            else:
                current.append(ch)
        if current:
            values.append("".join(current).strip())
        return values

    def get_data(self) -> dict[str, list[dict[str, Any]]]:
        return dict(self._data)


# ─── Script Finder ───────────────────────────────────────────────────────────


class ScriptFinder:
    """Finds SQL scripts in an extracted package."""

    def find(self, package_root: Path) -> list[Path]:
        # Look for scripts/ at root or one level deep
        for candidate in [package_root / "scripts", *package_root.glob("*/scripts")]:
            if candidate.is_dir() and "oracle" not in candidate.name and "postgres" not in candidate.name:
                scripts = sorted(candidate.glob("*.sql"), key=lambda p: p.name)
                if scripts:
                    return scripts
        return []


# ─── Schema Builder (orchestrator) ───────────────────────────────────────────


class SchemaBuilder:
    """Orchestrates schema extraction using simple-ddl-parser."""

    def build(self, package_root: Path) -> SchemaResult | None:
        scripts = ScriptFinder().find(package_root)
        if not scripts:
            return None

        extractor = StatementExtractor()
        ddl_parser = DDLSchemaParser()
        ref_parser = ReferenceDataParser(ddl_parser.resolve_name)

        for script in scripts:
            content = script.read_text(encoding="utf-8", errors="replace")
            statements = extractor.extract(content)
            ddl_parser.parse_ddl(statements)
            ref_parser.parse(statements)

        tables = ddl_parser.get_tables()
        ref_data = ref_parser.get_data()
        relationships = self._build_relationships(tables)
        insertion_order = self._topological_sort(tables, relationships)
        classification = {name: self._classify(name) for name in tables}
        summary = self._build_summary(tables, classification, relationships, ref_data)

        return SchemaResult(
            tables=tables,
            relationships=relationships,
            reference_data=ref_data,
            insertion_order=insertion_order,
            table_classification=classification,
            summary=summary,
        )

    def _build_relationships(self, tables: dict[str, Table]) -> list[dict[str, Any]]:
        rels = []
        for table in tables.values():
            for fk in table.foreign_keys:
                rels.append({
                    "from_table": table.name,
                    "from_column": fk.column,
                    "to_table": fk.ref_table,
                    "to_column": fk.ref_column,
                    "constraint": fk.name,
                })
        return rels

    def _topological_sort(self, tables: dict[str, Table], relationships: list) -> list[str]:
        graph: dict[str, set[str]] = defaultdict(set)
        in_degree: dict[str, int] = {name: 0 for name in tables}
        for rel in relationships:
            parent = rel["to_table"]
            child = rel["from_table"]
            if parent in tables and child in tables and parent != child:
                graph[parent].add(child)
                in_degree[child] = in_degree.get(child, 0) + 1

        queue = deque(sorted(n for n, d in in_degree.items() if d == 0))
        result: list[str] = []
        while queue:
            node = queue.popleft()
            result.append(node)
            for neighbor in sorted(graph[node]):
                in_degree[neighbor] -= 1
                if in_degree[neighbor] == 0:
                    queue.append(neighbor)

        result.extend(sorted(set(tables) - set(result)))
        return result

    def _classify(self, name: str) -> str:
        upper = name.upper()
        if "SCRIPTEXECUTION" in upper:
            return "framework"
        if "_A_R_" in upper or "_AUDIT" in upper:
            return "audit"
        if "_R_" in upper:
            return "reference"
        if "_TMG_" in upper:
            return "task_management"
        return "business"

    def _build_summary(self, tables, classification, relationships, ref_data) -> dict:
        counts = defaultdict(int)
        for cat in classification.values():
            counts[cat] += 1
        return {
            "total_tables": len(tables),
            "tables_by_category": dict(counts),
            "total_columns": sum(len(t.columns) for t in tables.values()),
            "total_foreign_keys": len(relationships),
            "reference_data_tables": len(ref_data),
            "reference_data_rows": sum(len(rows) for rows in ref_data.values()),
        }


# ─── CLI ─────────────────────────────────────────────────────────────────────


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python schema_alt.py <package.zip>")
        sys.exit(1)

    pkg_path = sys.argv[1]
    tmp = tempfile.mkdtemp()
    with zipfile.ZipFile(pkg_path) as zf:
        zf.extractall(tmp)

    builder = SchemaBuilder()
    result = builder.build(Path(tmp))

    if result is None:
        print("No scripts found")
    else:
        print(json.dumps(result.summary, indent=2))
        # Spot check
        for name, table in list(result.tables.items())[:3]:
            print(f"\n{name}: {len(table.columns)} cols, PK={table.primary_key}, FKs={len(table.foreign_keys)}")

    import shutil
    shutil.rmtree(tmp)
