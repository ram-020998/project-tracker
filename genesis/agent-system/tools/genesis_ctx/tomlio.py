"""TOML I/O: tomllib for reading; a tiny emitter (tables of strings / bools / ints / string arrays);
an in-place single-field editor that keeps comments and order."""
from __future__ import annotations

import re
import tomllib
from pathlib import Path

from .config import CtxError

BARE_KEY = re.compile(r"^[A-Za-z0-9_-]+$")


def load(path: Path) -> dict:
    try:
        text = Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        return {}
    try:
        return tomllib.loads(text)
    except tomllib.TOMLDecodeError as e:
        raise CtxError(f"{path}: invalid TOML: {e}") from e


def quote(s: str) -> str:
    out = ['"']
    for ch in s:
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20 or ord(ch) == 0x7F:
            out.append(f"\\u{ord(ch):04x}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def key(k: str) -> str:
    return k if BARE_KEY.match(k) else quote(k)


def value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return quote(v)
    if isinstance(v, (list, tuple)):
        if not all(isinstance(x, (str, bool, int)) for x in v):
            raise TypeError("only arrays of scalars are supported")
        return "[" + ", ".join(value(x) for x in v) + "]"
    raise TypeError(f"unsupported TOML value: {type(v).__name__}")


def dump_table(name_parts: list[str], body: dict) -> str:
    lines = ["[" + ".".join(key(p) for p in name_parts) + "]"]
    for k, v in body.items():
        if not isinstance(v, dict):
            lines.append(f"{key(k)} = {value(v)}")
    return "\n".join(lines) + "\n"


def dumps(data: dict, _prefix: list[str] | None = None) -> str:
    """Emit flat top-level keys, then each table (dicts nest as dotted tables)."""
    prefix = _prefix or []
    chunks: list[str] = []
    scalars = {k: v for k, v in data.items() if not isinstance(v, dict)}
    if scalars and not prefix:
        chunks.append("\n".join(f"{key(k)} = {value(v)}" for k, v in scalars.items()) + "\n")
    for k, v in data.items():
        if not isinstance(v, dict):
            continue
        parts = prefix + [k]
        if any(not isinstance(x, dict) for x in v.values()) or not v:
            chunks.append(dump_table(parts, v))
        sub = {kk: vv for kk, vv in v.items() if isinstance(vv, dict)}
        if sub:
            chunks.append(dumps(sub, parts))
    return "\n".join(c for c in chunks if c)


HEADER_RE = re.compile(r"^\s*\[(?!\[)\s*(.+?)\s*\]\s*(?:#.*)?$")


def _header_key(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith('"'):
        return tomllib.loads(f"k = {raw}")["k"]
    return raw


def set_field(text: str, table: str, field: str, val) -> str:
    """Set `field = val` inside `[table]`, in place (replace the line, or insert after the last key line).

    Raises CtxError if the table is absent. Comments, blank lines and ordering are preserved.
    """
    lines = text.split("\n")
    start = None
    for i, line in enumerate(lines):
        m = HEADER_RE.match(line)
        if m and _header_key(m.group(1)) == table:
            start = i
            break
    if start is None:
        raise CtxError(f"table [{table}] not found")
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if HEADER_RE.match(lines[j]) or lines[j].lstrip().startswith("[["):
            end = j
            break
    new_line = f"{key(field)} = {value(val)}"
    field_re = re.compile(r"^\s*" + re.escape(key(field)) + r"\s*=")
    last_key = start
    for j in range(start + 1, end):
        if field_re.match(lines[j]):
            # keep a trailing comment if the old line had one after a simple value
            lines[j] = new_line
            return "\n".join(lines)
        if re.match(r"^\s*[A-Za-z0-9_\"-]", lines[j]) and "=" in lines[j]:
            last_key = j
    lines.insert(last_key + 1, new_line)
    return "\n".join(lines)
