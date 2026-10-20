"""Path globs (47-02 §3): `**` = any number of segments (incl. none), `*` / `?` within one segment."""
from __future__ import annotations

import os
import re
from functools import lru_cache
from pathlib import Path

SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv", ".pytest_cache", ".ruff_cache",
             ".mypy_cache", ".DS_Store"}
SKIP_FILES = {".DS_Store"}
WILD = re.compile(r"[*?\[]")


@lru_cache(maxsize=4096)
def compile_glob(pat: str) -> re.Pattern:
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pat.startswith("**", i):
            out += ".*"
            i += 2
        elif pat[i] == "*":
            out += "[^/]*"
            i += 1
        elif pat[i] == "?":
            out += "[^/]"
            i += 1
        elif pat[i] == "[":
            j = pat.find("]", i + 1)
            if j == -1:
                out += re.escape("[")
                i += 1
            else:
                body = pat[i + 1:j]
                if body.startswith("!"):
                    body = "^" + body[1:]
                out += "[" + body.replace("\\", "\\\\") + "]"
                i = j + 1
        else:
            out += re.escape(pat[i])
            i += 1
    return re.compile(out + r"\Z")


def match(pat: str, path: str) -> bool:
    return bool(compile_glob(pat).match(path))


def literal_prefix(pat: str) -> str:
    parts = []
    for seg in pat.split("/"):
        if WILD.search(seg):
            break
        parts.append(seg)
    return "/".join(parts)


def _skip_dir(name: str) -> bool:
    return name in SKIP_DIRS or name.endswith(".egg-info")


def expand(root: Path, pat: str) -> list[str]:
    """Files under root matching pat (relative POSIX paths), sorted. Walks only the literal prefix."""
    if not WILD.search(pat):
        p = root / pat
        return [pat] if p.is_file() else []
    prefix = literal_prefix(pat)
    base = root / prefix if prefix else root
    if not base.is_dir():
        return []
    rx = compile_glob(pat)
    out: list[str] = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(d for d in dirnames if not _skip_dir(d))
        rel_dir = os.path.relpath(dirpath, root).replace(os.sep, "/")
        for f in filenames:
            if f in SKIP_FILES or f.endswith(".pyc"):
                continue
            rel = f if rel_dir == "." else f"{rel_dir}/{f}"
            if rx.match(rel):
                out.append(rel)
    return sorted(out)
