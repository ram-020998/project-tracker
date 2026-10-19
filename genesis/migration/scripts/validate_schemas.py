#!/usr/bin/env python3
"""Phase 47-01 — schema self-check.

For every ``migration/schemas/*.schema.json`` this script:
  1. confirms the schema is valid JSON (so is ``python3 -m json.tool``);
  2. loads ``examples/<base>.valid.json`` and ``examples/<base>.invalid.json``;
  3. hand-validates both against the schema and asserts the valid one PASSES and
     the invalid one FAILS (47-01 DoD).

No third-party dependency: a small recursive checker covers the JSON-Schema
subset these schemas use — type, enum, const, pattern, required, properties,
items, minItems/maxItems, nullable, and the custom ``x-exactly-one-of``
(exactly one of a group of keys must be present).

Run:  python3 genesis/migration/scripts/validate_schemas.py
Exit status is non-zero if any schema/example check fails.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SCHEMA_DIR = Path(__file__).resolve().parents[1] / "schemas"
EX_DIR = SCHEMA_DIR / "examples"

TYPE_PY = {
    "object": dict,
    "array": list,
    "string": str,
    "integer": int,
    "number": (int, float),
    "boolean": bool,
    "null": type(None),
}


def check(schema: dict, value, path: str, errs: list[str]) -> None:
    # nullable: allow explicit null regardless of declared type.
    if value is None and schema.get("nullable"):
        return

    t = schema.get("type")
    if t:
        py = TYPE_PY[t]
        # bool is a subclass of int — guard integer/number against bool.
        if t in ("integer", "number") and isinstance(value, bool):
            errs.append(f"{path}: expected {t}, got boolean")
            return
        if not isinstance(value, py):
            errs.append(f"{path}: expected {t}, got {type(value).__name__}")
            return

    if "const" in schema and value != schema["const"]:
        errs.append(f"{path}: expected const {schema['const']!r}, got {value!r}")
    if "enum" in schema and value not in schema["enum"]:
        errs.append(f"{path}: {value!r} not in enum {schema['enum']}")
    if "pattern" in schema and isinstance(value, str):
        if not re.fullmatch(schema["pattern"], value):
            errs.append(f"{path}: {value!r} does not match /{schema['pattern']}/")

    if t == "object" and isinstance(value, dict):
        for req in schema.get("required", []):
            if req not in value:
                errs.append(f"{path}: missing required key '{req}'")
        for group in schema.get("x-exactly-one-of", []):
            present = [k for k in group if k in value]
            if len(present) != 1:
                errs.append(f"{path}: exactly one of {group} required, found {present}")
        props = schema.get("properties", {})
        for k, sub in props.items():
            if k in value:
                check(sub, value[k], f"{path}.{k}", errs)

    if t == "array" and isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            errs.append(f"{path}: needs >= {schema['minItems']} items, got {len(value)}")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errs.append(f"{path}: needs <= {schema['maxItems']} items, got {len(value)}")
        item_schema = schema.get("items")
        if item_schema:
            for i, item in enumerate(value):
                check(item_schema, item, f"{path}[{i}]", errs)


def validate(schema: dict, value) -> list[str]:
    errs: list[str] = []
    check(schema, value, "$", errs)
    return errs


def main() -> int:
    schemas = sorted(SCHEMA_DIR.glob("*.schema.json"))
    if not schemas:
        print("no schemas found", file=sys.stderr)
        return 2
    failures = 0
    for sp in schemas:
        base = sp.name[: -len(".schema.json")]
        try:
            schema = json.loads(sp.read_text())
        except json.JSONDecodeError as e:
            print(f"FAIL {sp.name}: not valid JSON: {e}")
            failures += 1
            continue
        valid_p = EX_DIR / f"{base}.valid.json"
        invalid_p = EX_DIR / f"{base}.invalid.json"
        if not valid_p.exists() or not invalid_p.exists():
            print(f"FAIL {sp.name}: missing example(s) "
                  f"({valid_p.name}={valid_p.exists()}, {invalid_p.name}={invalid_p.exists()})")
            failures += 1
            continue
        valid_errs = validate(schema, json.loads(valid_p.read_text()))
        invalid_errs = validate(schema, json.loads(invalid_p.read_text()))
        ok_valid = not valid_errs
        ok_invalid = bool(invalid_errs)
        status = "OK  " if (ok_valid and ok_invalid) else "FAIL"
        if not (ok_valid and ok_invalid):
            failures += 1
        print(f"{status} {sp.name}")
        if not ok_valid:
            print("     valid example unexpectedly FAILED:")
            for e in valid_errs:
                print("       - " + e)
        if not ok_invalid:
            print("     invalid example unexpectedly PASSED (should have errors)")
        else:
            print(f"     (invalid example correctly rejected: {invalid_errs[0]})")
    print(f"\n{len(schemas) - failures}/{len(schemas)} schemas OK")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
