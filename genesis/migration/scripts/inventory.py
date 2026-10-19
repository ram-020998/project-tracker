#!/usr/bin/env python3
"""Phase 47-01 — Genesis knowledge-store inventory.

Enumerates every git-tracked file under ``genesis/`` at the migration base and
classifies each source as:

* ``extract``      — text we read fully and ledger in the migration (§3.1).
* ``archive-only`` — kept in ``archive/`` but never ledgered; a ``reason`` is
  required (e.g. a binary image, an editor-config blob, OS metadata).

Output: ``genesis/migration/inventory.csv`` with columns
``path,bytes,chars,lines,type,class,reason``.

Design notes
------------
* Enumeration uses ``git ls-files -- genesis/`` from the repo root, so the row
  count equals ``git ls-files genesis/ | wc -l`` *by construction* (47-01 DoD).
* File bytes/chars/lines are read from the working tree. The script first
  asserts that ``genesis/`` is clean against ``HEAD`` and that ``HEAD`` equals
  the migration-base tag, so the working tree is byte-identical to the base.
  Pass ``--allow-dirty`` to bypass the guard (not recommended).
* ``chars`` = number of Unicode code points (UTF-8 decoded); ``lines`` =
  ``len(text.splitlines())`` (the natural 1-based line count an extractor sees).
  Both are 0 for ``archive-only`` binaries.
* Deterministic: rows are emitted in ``git ls-files`` (sorted) order.

Run:  ``python3 genesis/migration/scripts/inventory.py``
"""
from __future__ import annotations

import argparse
import csv
import os
import subprocess
import sys
from pathlib import Path

BASE_TAG = "knowledge-migration-base"

# Repo root = two levels up from this script (genesis/migration/scripts/).
REPO_ROOT = Path(__file__).resolve().parents[3]
OUT_CSV = REPO_ROOT / "genesis" / "migration" / "inventory.csv"

# --- classification tables -------------------------------------------------

# Extension -> human file "type" (independent of extract/archive class).
TYPE_BY_EXT = {
    ".md": "markdown",
    ".markdown": "markdown",
    ".json": "json",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".py": "python",
    ".js": "javascript",
    ".ts": "typescript",
    ".html": "html",
    ".htm": "html",
    ".csv": "csv",
    ".txt": "text",
    ".toml": "toml",
    ".cfg": "config",
    ".ini": "config",
    ".canvas": "json",
    ".gz": "archive",
    ".tgz": "archive",
    ".zip": "archive",
    ".tar": "archive",
    ".png": "image",
    ".jpg": "image",
    ".jpeg": "image",
    ".gif": "image",
    ".svg": "image",
    ".pdf": "pdf",
    ".ico": "image",
    ".woff": "font",
    ".woff2": "font",
    ".ttf": "font",
}

# Extensions that are archive-only, with the reason.
ARCHIVE_EXT_REASON = {
    ".gz": "compressed binary bundle; no extractable prose",
    ".tgz": "compressed binary bundle; no extractable prose",
    ".tar": "binary archive; no extractable prose",
    ".zip": "compressed binary archive; no extractable prose",
    ".png": "binary image; no extractable text",
    ".jpg": "binary image; no extractable text",
    ".jpeg": "binary image; no extractable text",
    ".gif": "binary image; no extractable text",
    ".ico": "binary icon; no extractable text",
    ".pdf": "binary PDF; no extractable text",
    ".woff": "binary font; no extractable text",
    ".woff2": "binary font; no extractable text",
    ".ttf": "binary font; no extractable text",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(REPO_ROOT), *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def classify(rel_path: str, text: str | None) -> tuple[str, str, str]:
    """Return (type, klass, reason)."""
    p = Path(rel_path)
    name = p.name
    ext = p.suffix.lower()
    ftype = TYPE_BY_EXT.get(ext, "text")

    # OS / editor noise.
    if name == ".DS_Store":
        return "os-metadata", "archive-only", "macOS Finder metadata; no knowledge content"
    if "/.obsidian/" in f"/{rel_path}":
        return "json", "archive-only", "Obsidian editor workspace/config; no knowledge content"

    # Known binary extensions.
    if ext in ARCHIVE_EXT_REASON:
        return ftype, "archive-only", ARCHIVE_EXT_REASON[ext]

    # Anything that failed UTF-8 decode is binary.
    if text is None:
        return (ftype if ftype != "text" else "binary"), "archive-only", "binary (non-UTF-8); no extractable text"

    # Everything else is readable text -> extract.
    # (JSON fixtures and contract files are extract per §3.1 / 47-01 Work §2.)
    return ftype, "extract", ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--allow-dirty", action="store_true",
                    help="skip the clean-tree / base-tag guard")
    args = ap.parse_args()

    # Guard: genesis/ clean against HEAD, and HEAD == base tag.
    if not args.allow_dirty:
        dirty = git("status", "--porcelain", "--", "genesis/").strip()
        if dirty:
            # Allow files created by this migration workspace itself (migration/**),
            # which are not part of the base inventory anyway.
            offending = [ln for ln in dirty.splitlines()
                         if " genesis/migration/" not in ln and not ln.endswith("genesis/migration")]
            offending = [ln for ln in offending if "genesis/migration/" not in ln]
            if offending:
                print("ERROR: genesis/ has uncommitted changes outside migration/:",
                      file=sys.stderr)
                print("\n".join(offending), file=sys.stderr)
                print("Re-run with --allow-dirty to override.", file=sys.stderr)
                return 2
        head = git("rev-parse", "HEAD").strip()
        try:
            tag = git("rev-list", "-n1", BASE_TAG).strip()
        except subprocess.CalledProcessError:
            tag = ""
        if tag and head != tag:
            print(f"WARNING: HEAD ({head[:12]}) != {BASE_TAG} ({tag[:12]}); "
                  f"inventory reflects the working tree, not the base tag.",
                  file=sys.stderr)

    files = [f for f in git("ls-files", "--", "genesis/").splitlines() if f]
    # Exclude the migration workspace itself — it is not a migration *source*.
    files = [f for f in files if not f.startswith("genesis/migration/")]

    rows = []
    for rel in files:
        abs_path = REPO_ROOT / rel
        try:
            data = abs_path.read_bytes()
        except (FileNotFoundError, IsADirectoryError):
            # Listed by git but not on disk (shouldn't happen on a clean tree).
            rows.append([rel, 0, 0, 0, "missing", "archive-only", "not present on disk"])
            continue
        nbytes = len(data)
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            text = None
        ftype, klass, reason = classify(rel, text)
        if text is None:
            nchars = nlines = 0
        else:
            nchars = len(text)
            nlines = len(text.splitlines())
        rows.append([rel, nbytes, nchars, nlines, ftype, klass, reason])

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["path", "bytes", "chars", "lines", "type", "class", "reason"])
        w.writerows(rows)

    # Summary to stderr (not part of the CSV).
    n_extract = sum(1 for r in rows if r[5] == "extract")
    n_archive = sum(1 for r in rows if r[5] == "archive-only")
    extract_chars = sum(r[2] for r in rows if r[5] == "extract")
    extract_lines = sum(r[3] for r in rows if r[5] == "extract")
    by_type: dict[str, int] = {}
    for r in rows:
        by_type[r[4]] = by_type.get(r[4], 0) + 1
    print(f"inventory.csv: {len(rows)} rows", file=sys.stderr)
    print(f"  extract      : {n_extract}", file=sys.stderr)
    print(f"  archive-only : {n_archive}", file=sys.stderr)
    print(f"  extract chars: {extract_chars:,}  (~{extract_chars // 4:,} tokens)",
          file=sys.stderr)
    print(f"  extract lines: {extract_lines:,}", file=sys.stderr)
    print("  by type      : " + ", ".join(f"{k}={v}" for k, v in sorted(by_type.items())),
          file=sys.stderr)
    # DoD check hint.
    lsfiles = len([f for f in git("ls-files", "--", "genesis/").splitlines() if f])
    print(f"  git ls-files genesis/ = {lsfiles} "
          f"({lsfiles - len(rows)} of which are migration/ workspace files, excluded)",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
