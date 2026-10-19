#!/usr/bin/env python3
"""Phase 47-01 — batch planner (gate-approved composition, 2026-10-19).

Produces ``migration/batches.yaml`` from ``migration/inventory.csv``.

Pilot (47-03) — Collaboration & Hub, approved composition:
* **P1** = specs + progress of phases 35, 37, 38
         + progress/collab-settings-toggle-adr-065.md
         + reference/decision-log.md lines 1323–1353 (ADR-063..065 + the on_board amendment)
         + bible/04-adrs-and-constraints.md lines 70, 72, 73 (ADR-063/064/065 index rows)
         + bible/06-hard-won-lessons.md the collaboration/Hub lessons
           (lines 334, 336, 341, 347, 349, 351, 353–354).
* **P2** = all of phase 36 (specs, contract docs, fixtures, progress).

The carved line ranges are **removed** from the B batches — every ``extract``
file is still covered **exactly once** across all batches (pilot + B), so the
B batches carry each partial file's *complement* ranges.

B01..Bnn (47-04) — the rest, packed group-by-group (a phase's spec + sub-specs +
progress sit together). A range larger than the cap is split only at safe
boundaries (a blank line outside a code fence, or a heading), so no paragraph,
table or code block is cut.

Per-batch cap: **200,000 chars** (change 2). Verify with ``check_batches.py``.

Run:  python3 genesis/migration/scripts/plan_batches.py
"""
from __future__ import annotations

import csv
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
MIG = REPO_ROOT / "genesis" / "migration"
INVENTORY = MIG / "inventory.csv"
OUT = MIG / "batches.yaml"

LIMIT = 200_000

P1_GROUPS = {"phase-35", "phase-37", "phase-38"}
P1_EXTRA = {"genesis/progress/collab-settings-toggle-adr-065.md"}
P2_GROUPS = {"phase-36"}
# Partial carves into P1 (src -> list of inclusive 1-based line ranges).
PILOT_PARTIAL: dict[str, list[tuple[int, int]]] = {
    "genesis/reference/decision-log.md": [(1323, 1353)],
    "genesis/bible/04-adrs-and-constraints.md": [(70, 70), (72, 72), (73, 73)],
    "genesis/bible/06-hard-won-lessons.md": [(334, 334), (336, 336), (341, 341),
                                             (347, 347), (349, 349), (351, 351), (353, 354)],
}


def group_key(path: str) -> str:
    rel = path[len("genesis/"):] if path.startswith("genesis/") else path
    m = re.match(r"(?:specs|progress)/phase-(\d\d)", rel)
    if m:
        return f"phase-{m.group(1)}"
    if rel == "tracker.md":
        return "tracker"
    if rel.startswith("bible/"):
        return "bible"
    if rel.startswith("reference/"):
        return "reference"
    if rel.startswith("specs/backlog/"):
        return "specs-backlog"
    if rel.startswith("specs/appian-env/"):
        return "specs-appian-env"
    if rel.startswith("specs/bugs/"):
        return "specs-bugs"
    if rel.startswith("specs/"):
        return "specs-misc"
    if rel.startswith("progress/"):
        return "progress-misc"
    if rel.startswith("design/"):
        return "design"
    if rel.startswith("spike/"):
        return "spike"
    if rel.startswith("code-review/"):
        return "code-review"
    if rel.startswith("artifacts/"):
        return "artifacts"
    if rel.startswith("agents/"):
        return "agents"
    return "root-docs"


def phase_num(group: str) -> int:
    m = re.match(r"phase-(\d\d)", group)
    return int(m.group(1)) if m else 999


class Sizer:
    """Per-line char counts + safe split boundaries for a text file."""
    def __init__(self, path: str):
        text = (REPO_ROOT / path).read_text(encoding="utf-8")
        self.kept = text.splitlines(keepends=True)
        self.n = len(self.kept)
        self.prefix = [0] * (self.n + 1)
        for i in range(1, self.n + 1):
            self.prefix[i] = self.prefix[i - 1] + len(self.kept[i - 1])
        in_fence = False
        self.safe: set[int] = set()
        for i in range(1, self.n + 1):
            ln = self.kept[i - 1]
            if ln.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if ln.strip() == "" and not in_fence:
                self.safe.add(i)
            if re.match(r"\s{0,3}#{1,6}\s", ln) and not in_fence and i > 1:
                self.safe.add(i - 1)

    def chars(self, a: int, b: int) -> int:
        return self.prefix[b] - self.prefix[a - 1]


def complement(ranges: list[tuple[int, int]], n: int) -> list[tuple[int, int]]:
    """Gaps in [1, n] not covered by the (sorted, disjoint) ranges."""
    out, cur = [], 1
    for (a, b) in sorted(ranges):
        if a > cur:
            out.append((cur, a - 1))
        cur = b + 1
    if cur <= n:
        out.append((cur, n))
    return out


def main() -> int:
    extract: dict[str, dict] = {}
    with INVENTORY.open() as fh:
        for row in csv.DictReader(fh):
            if row["class"] == "extract":
                extract[row["path"]] = {"chars": int(row["chars"]),
                                        "lines": max(int(row["lines"]), 1)}

    needs_sizing = set(PILOT_PARTIAL) | {p for p, i in extract.items() if i["chars"] > LIMIT}
    sizers = {p: Sizer(p) for p in needs_sizing}

    def split_range(path: str, s: int, e: int) -> list[tuple[int, int, int]]:
        """Split [s,e] into chunks <= LIMIT, cutting only at safe boundaries."""
        if path not in sizers:
            # small, whole-file-only segment
            assert s == 1 and e == extract[path]["lines"]
            return [(s, e, extract[path]["chars"])]
        sz = sizers[path]
        out: list[tuple[int, int, int]] = []
        start = s
        while start <= e:
            if sz.chars(start, e) <= LIMIT:
                out.append((start, e, sz.chars(start, e)))
                break
            best = None
            for b in range(start, e):
                if sz.chars(start, b) > LIMIT:
                    break
                if b in sz.safe:
                    best = b
            if best is None:  # no safe boundary fits -> hard cut
                b = start
                while b < e and sz.chars(start, b + 1) <= LIMIT:
                    b += 1
                best = b
            out.append((start, best, sz.chars(start, best)))
            start = best + 1
        return out

    def chars_of(path: str, a: int, b: int) -> int:
        if path in sizers:
            return sizers[path].chars(a, b)
        return extract[path]["chars"]

    # Classify files -> pilot target + pilot ranges; collect B segments.
    p1_entries: list[tuple] = []
    p2_entries: list[tuple] = []
    b_groups: dict[str, list[tuple]] = {}

    for path in sorted(extract):
        n = extract[path]["lines"]
        g = group_key(path)
        if g in P1_GROUPS or path in P1_EXTRA:
            p1_entries.append((path, 1, n, chars_of(path, 1, n)))
            continue
        if g in P2_GROUPS:
            p2_entries.append((path, 1, n, chars_of(path, 1, n)))
            continue
        if path in PILOT_PARTIAL:
            for (a, b) in PILOT_PARTIAL[path]:
                p1_entries.append((path, a, b, chars_of(path, a, b)))
            segs = complement(PILOT_PARTIAL[path], n)
        else:
            segs = [(1, n)]
        for (s, e) in segs:
            for (a, b, ch) in split_range(path, s, e):
                b_groups.setdefault(g, []).append((path, a, b, ch))

    # Keep partial carves after the whole-file P1 members, for a tidy batch.
    p1_entries.sort(key=lambda e: (e[0] in PILOT_PARTIAL, e[0], e[1]))

    def pack(entries: list[tuple], ids) -> list[dict]:
        batches, cur, cur_chars = [], [], 0
        it = iter(ids)
        def seal():
            nonlocal cur, cur_chars
            if cur:
                batches.append({"id": next(it), "entries": cur, "chars": cur_chars})
                cur, cur_chars = [], 0
        for e in entries:
            if cur and cur_chars + e[3] > LIMIT:
                seal()
            cur.append(e)
            cur_chars += e[3]
        seal()
        return batches

    pilot = pack(p1_entries, ["P1", "P3", "P4", "P5"]) + pack(p2_entries, ["P2", "P6", "P7"])

    named_order = ["reference", "bible", "tracker", "root-docs", "agents",
                   "design", "spike", "code-review", "artifacts",
                   "specs-misc", "progress-misc",
                   "specs-appian-env", "specs-backlog", "specs-bugs"]
    ordered = (sorted([g for g in b_groups if g.startswith("phase-")], key=phase_num)
               + [g for g in named_order if g in b_groups]
               + sorted(g for g in b_groups if g not in named_order and not g.startswith("phase-")))
    rest_entries: list[tuple] = []
    for g in ordered:
        rest_entries += b_groups[g]
    rest = pack(rest_entries, [f"B{i:02d}" for i in range(1, 99)])

    all_batches = pilot + rest

    out: list[str] = []
    out.append("# Phase 47 — extraction batch plan (generated by scripts/plan_batches.py).")
    out.append("# Gate-approved composition (2026-10-19, changes 1-3). Every `extract` file is")
    out.append(f"# covered exactly once; each batch totals <= {LIMIT:,} chars. P1/P2 = the 47-03")
    out.append("# pilot (Collaboration & Hub); B01..Bnn = 47-04. Verify with scripts/check_batches.py.")
    out.append("version: 2")
    out.append("base_tag: knowledge-migration-base")
    out.append(f"char_limit: {LIMIT}")
    out.append(f"total_batches: {len(all_batches)}")
    out.append(f"total_chars: {sum(b['chars'] for b in all_batches)}")
    out.append("batches:")
    for b in all_batches:
        out.append(f"  - id: {b['id']}")
        out.append(f"    chars: {b['chars']}")
        out.append(f"    files: {len(b['entries'])}")
        out.append("    sources:")
        for (path, a, c, ch) in b["entries"]:
            out.append(f'      - {{src: "{path}", lines: [{a}, {c}], chars: {ch}}}')
    OUT.write_text("\n".join(out) + "\n", encoding="utf-8")

    print(f"wrote {OUT.relative_to(REPO_ROOT)}")
    print(f"  pilot batches : {len(pilot)} ({', '.join(b['id'] for b in pilot)})")
    for b in pilot:
        print(f"      {b['id']}: {len(b['entries'])} entries, {b['chars']:,} chars")
    print(f"  rest batches  : {len(rest)} ({rest[0]['id']}..{rest[-1]['id']})")
    print(f"  total batches : {len(all_batches)}")
    print(f"  total chars   : {sum(b['chars'] for b in all_batches):,}")
    print(f"  max batch     : {max(b['chars'] for b in all_batches):,}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
