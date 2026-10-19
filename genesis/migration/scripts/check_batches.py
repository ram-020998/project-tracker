#!/usr/bin/env python3
"""Phase 47-01 — batch plan check (47-01 DoD).

Verifies ``migration/batches.yaml`` against ``migration/inventory.csv``:

* the union of batch line ranges == **all** ``extract`` lines — every extract
  file is present and each of its lines is covered **exactly once** (no gap, no
  overlap);
* **no** ``archive-only`` file appears in any batch;
* every batch's total chars <= the declared ``char_limit`` (<= 200,000, lowered
  from 250,000 at the 47-01 gate, 2026-10-19);
* recorded per-entry chars are self-consistent (split chunks of a file sum to
  the file's inventory char count);
* batch ids are unique; P-batches and a contiguous B01..Bnn series exist;
* **boundary safety (47-01 review P1):** every internal split boundary of a
  multi-entry source lands on a safe point (a blank line, a heading start, or
  between two sibling list items) and never inside a fenced code block — read
  from the source blob at the base tag, so a later hand-edit to batches.yaml
  that smuggles a mid-paragraph/table/list-item/code-block split is rejected.

Exit status is non-zero on any violation.

Run:  python3 genesis/migration/scripts/check_batches.py
"""
from __future__ import annotations

import csv
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
MIG = REPO_ROOT / "genesis" / "migration"
INVENTORY = MIG / "inventory.csv"
BATCHES = MIG / "batches.yaml"
BASE_TAG = "knowledge-migration-base"


def base_blob_lines(path: str) -> list[str] | None:
    """The source's lines at the migration base tag (``splitlines``), or None."""
    try:
        out = subprocess.run(["git", "-C", str(REPO_ROOT), "show", f"{BASE_TAG}:{path}"],
                             check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError:
        return None
    return out.splitlines()


def _is_heading(ln: str) -> bool:
    return bool(re.match(r"\s{0,3}#{1,6}\s", ln))


def _is_list_item(ln: str) -> bool:
    return bool(re.match(r"\s*(?:[-*+]|\d+[.)])\s", ln))


def _is_table_row(ln: str) -> bool:
    return ln.strip().startswith("|")


def unsafe_boundaries(lines: list[str], ranges: list[tuple[int, int]]) -> list[int]:
    """Return the start-lines of any chunk whose cut point is unsafe.

    A cut after line L (next chunk starts at L+1) is SAFE iff it is not inside a
    fenced code block and one of: L or L+1 is blank; L+1 is a heading; or L and
    L+1 are sibling list items. Otherwise the cut falls inside a paragraph,
    table, list item or code block — unsafe.
    """
    n = len(lines)
    # fence state after each 1-based line (odd => inside a code fence).
    fence_open = [False] * (n + 2)
    inside = False
    for i in range(1, n + 1):
        if lines[i - 1].lstrip().startswith("```"):
            inside = not inside
        fence_open[i] = inside

    def blank(i: int) -> bool:
        return 1 <= i <= n and lines[i - 1].strip() == ""

    bad = []
    starts = sorted(a for (a, _) in ranges)
    for s in starts:
        if s == 1:
            continue  # file start, not an internal boundary
        L = s - 1  # previous chunk ended here
        if not (1 <= L < n):
            continue
        if fence_open[L]:
            bad.append(s); continue
        line_L, line_N = lines[L - 1], lines[s - 1]
        if blank(L) or blank(s):
            continue
        if _is_heading(line_N):
            continue
        if _is_list_item(line_L) and _is_list_item(line_N) \
                and not _is_table_row(line_L) and not _is_table_row(line_N):
            continue
        bad.append(s)
    return bad



def load_inventory():
    extract = {}
    archive = set()
    with INVENTORY.open() as fh:
        for row in csv.DictReader(fh):
            if row["class"] == "extract":
                extract[row["path"]] = {"chars": int(row["chars"]),
                                        "lines": max(int(row["lines"]), 1)}
            else:
                archive.add(row["path"])
    return extract, archive


def load_batches():
    """Parse the generated batches.yaml (fixed shape — a tiny hand-parser)."""
    char_limit = 200_000
    batches = []  # [{id, chars, entries:[(src,a,b,chars)]}]
    cur = None
    entry_re = re.compile(
        r'^\s*-\s*\{src:\s*"(?P<src>[^"]+)",\s*lines:\s*\[(?P<a>\d+),\s*(?P<b>\d+)\],\s*chars:\s*(?P<ch>\d+)\}\s*$')
    for raw in BATCHES.read_text().splitlines():
        m = re.match(r"^char_limit:\s*(\d+)", raw)
        if m:
            char_limit = int(m.group(1)); continue
        m = re.match(r"^\s{2}-\s*id:\s*(\S+)", raw)
        if m:
            if cur:
                batches.append(cur)
            cur = {"id": m.group(1), "chars": None, "entries": []}
            continue
        m = re.match(r"^\s{4}chars:\s*(\d+)", raw)
        if m and cur:
            cur["chars"] = int(m.group(1)); continue
        m = entry_re.match(raw)
        if m and cur:
            cur["entries"].append((m["src"], int(m["a"]), int(m["b"]), int(m["ch"])))
    if cur:
        batches.append(cur)
    return batches, char_limit


def main() -> int:
    extract, archive = load_inventory()
    batches, char_limit = load_batches()
    errs: list[str] = []

    # Per-file covered line set (detect gaps/overlaps precisely).
    covered: dict[str, list[tuple[int, int]]] = {}
    recorded_chars: dict[str, int] = {}
    ids = []
    for b in batches:
        ids.append(b["id"])
        tot = 0
        for (src, a, bb, ch) in b["entries"]:
            tot += ch
            if src in archive:
                errs.append(f"{b['id']}: archive-only file in batch: {src}")
            covered.setdefault(src, []).append((a, bb))
            recorded_chars[src] = recorded_chars.get(src, 0) + ch
        if b["chars"] is not None and tot != b["chars"]:
            errs.append(f"{b['id']}: declared chars {b['chars']} != sum of entries {tot}")
        if tot > char_limit:
            errs.append(f"{b['id']}: {tot} chars exceeds limit {char_limit}")

    # Coverage: every extract file tiled exactly once.
    for path, info in extract.items():
        ranges = sorted(covered.get(path, []))
        if not ranges:
            errs.append(f"MISSING from batches: {path}")
            continue
        # must tile [1, lines]
        expect = 1
        for (a, b) in ranges:
            if a != expect:
                errs.append(f"{path}: gap/overlap — range starts at {a}, expected {expect}")
                break
            expect = b + 1
        else:
            if expect - 1 != info["lines"]:
                errs.append(f"{path}: covered to line {expect-1}, file has {info['lines']} lines")
        # recorded chars consistency (for split files especially)
        if recorded_chars.get(path) != info["chars"]:
            errs.append(f"{path}: batch chars {recorded_chars.get(path)} != inventory chars {info['chars']}")

    # Files in batches not in extract inventory.
    for path in covered:
        if path not in extract:
            errs.append(f"not an extract source (or unknown): {path}")

    # Boundary safety (47-01 review P1): every internal split of a multi-entry
    # source must cut at a safe point, checked against the base-tag blob.
    boundary_checked = 0
    for path, ranges in covered.items():
        if path not in extract or len(ranges) < 2:
            continue
        lines = base_blob_lines(path)
        if lines is None:
            errs.append(f"{path}: cannot read blob at {BASE_TAG} for boundary check")
            continue
        boundary_checked += 1
        for s in unsafe_boundaries(lines, ranges):
            errs.append(f"{path}: unsafe split boundary before line {s} "
                        f"(cuts inside a paragraph/table/list-item/code block)")

    # Id sanity.
    if len(ids) != len(set(ids)):
        errs.append("duplicate batch ids")
    p_ids = [i for i in ids if re.fullmatch(r"P\d+", i)]
    b_ids = [i for i in ids if re.fullmatch(r"B\d+", i)]
    if not p_ids:
        errs.append("no pilot (P) batches")
    exp = [f"B{i:02d}" for i in range(1, len(b_ids) + 1)]
    if b_ids != exp:
        errs.append(f"B-series not contiguous: {b_ids[:3]}..{b_ids[-3:]} vs {exp[:3]}..{exp[-3:]}")

    # Report.
    nfiles = sum(len(b["entries"]) for b in batches)
    tot_chars = sum(sum(e[3] for e in b["entries"]) for b in batches)
    print(f"batches: {len(batches)}  (pilot {len(p_ids)}, B {len(b_ids)})")
    print(f"extract files in inventory: {len(extract)}")
    print(f"distinct sources covered  : {len(covered)}")
    print(f"total entries (incl. splits): {nfiles}")
    print(f"total chars               : {tot_chars:,}  (inventory extract: {sum(v['chars'] for v in extract.values()):,})")
    print(f"max batch chars           : {max(sum(e[3] for e in b['entries']) for b in batches):,}  (limit {char_limit:,})")
    print(f"multi-entry sources boundary-checked: {boundary_checked}")
    if errs:
        print(f"\nFAIL — {len(errs)} problem(s):")
        for e in errs[:50]:
            print("  - " + e)
        return 1
    print("\nOK: every extract file covered exactly once; no overlaps/gaps; all batches within limit.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
