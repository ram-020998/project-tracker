#!/usr/bin/env python3
"""Phase 47-01 — area coverage check.

Verifies the 47-01 DoD: every git-tracked file in the five code repos matches
>= 1 area glob in ``areas.yaml`` OR a declared ``exceptions`` glob (with a
reason). Prints per-area file counts, lists any UNMATCHED files (a failure), and
lists any file that matched only via an exception.

Usage:
    python3 genesis/migration/scripts/check_areas.py [--code-root DIR]

The code root is the directory holding the five repos as siblings. Resolution
order: --code-root, $GENESIS_CODE_ROOT, then a short list of known candidates.
Exit status is non-zero if any file is unmatched (coverage incomplete).

Glob semantics (gitignore-like):
    *   matches within one path segment (does not cross '/')
    **  matches zero or more whole segments (crosses '/')
    trailing '/**' also matches the directory's own files
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
AREAS_YAML = REPO_ROOT / "genesis" / "migration" / "areas.yaml"

CANDIDATE_ROOTS = [
    os.environ.get("GENESIS_CODE_ROOT", ""),
    str(Path.home() / "repo-gitlab" / "ramaswamy.u"),
    str(Path.home() / "genesis-repos"),
    str(REPO_ROOT.parent),
    str(Path.home()),
]


def glob_to_regex(glob: str) -> re.Pattern:
    """Translate a gitignore-like glob into an anchored regex."""
    # Normalise a trailing '/**' so it also matches the dir's own files.
    segs = glob.split("/")
    out = ["^"]
    for i, seg in enumerate(segs):
        if seg == "**":
            # match zero or more whole segments
            out.append("(?:[^/]+/)*")
            # a '**' at the very end should also allow matching files directly
            if i == len(segs) - 1:
                out.append("[^/]*")
            continue
        # within-segment translation
        part = []
        for ch in seg:
            if ch == "*":
                part.append("[^/]*")
            elif ch == "?":
                part.append("[^/]")
            else:
                part.append(re.escape(ch))
        out.append("".join(part))
        if i != len(segs) - 1:
            out.append("/")
    # Allow 'a/**' to match 'a' itself collapsing the trailing (?:..)*[^/]*
    pattern = "".join(out)
    pattern = pattern.replace("/(?:[^/]+/)*[^/]*$", "(?:/.*)?$")
    if not pattern.endswith("$"):
        pattern += "$"
    return re.compile(pattern)


def load_areas() -> tuple[list[dict], list[dict], list[str]]:
    """Return (areas, exceptions, repos). Minimal YAML reader (no pyyaml dep)."""
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(AREAS_YAML.read_text())
        return data["areas"], data.get("exceptions", []), data["repos"]
    except Exception:
        pass
    # Fallback hand-parser for the subset of YAML this file uses.
    areas: list[dict] = []
    exceptions: list[dict] = []
    repos: list[str] = []
    section = None
    cur_area: dict | None = None
    cur_exc: dict | None = None
    in_code = False
    in_repos = False
    for raw in AREAS_YAML.read_text().splitlines():
        line = raw.rstrip("\n")
        if re.match(r"^repos:\s*$", line):
            section, in_repos = "repos", True
            continue
        if re.match(r"^areas:\s*$", line):
            section, in_repos = "areas", False
            continue
        if re.match(r"^pseudo_areas:\s*$", line):
            section = "pseudo"
            if cur_area:
                areas.append(cur_area); cur_area = None
            in_code = False
            continue
        if re.match(r"^exceptions:\s*$", line):
            section = "exceptions"
            if cur_area:
                areas.append(cur_area); cur_area = None
            in_code = False
            continue
        if section == "repos" and in_repos:
            m = re.match(r"^\s*-\s*([A-Za-z0-9_.-]+)", line)
            if m:
                repos.append(m.group(1))
            continue
        if section == "areas":
            m = re.match(r"^\s{2}-\s*id:\s*(\S+)", line)
            if m:
                if cur_area:
                    areas.append(cur_area)
                cur_area = {"id": m.group(1), "code": []}
                in_code = False
                continue
            if re.match(r"^\s{4}code:\s*$", line):
                in_code = True
                continue
            if in_code:
                m2 = re.match(r"^\s{6}-\s*(\S+)", line)
                if m2:
                    cur_area["code"].append(m2.group(1))
                    continue
                if re.match(r"^\s{4}\w", line):
                    in_code = False
        if section == "exceptions":
            m = re.match(r"^\s{2}-\s*glob:\s*(\S+)", line)
            if m:
                if cur_exc:
                    exceptions.append(cur_exc)
                cur_exc = {"glob": m.group(1), "reason": ""}
                continue
    if cur_area and section == "areas":
        areas.append(cur_area)
    if cur_exc:
        exceptions.append(cur_exc)
    return areas, exceptions, repos


def resolve_code_root(cli_root: str | None, repos: list[str]) -> Path:
    cands = ([cli_root] if cli_root else []) + CANDIDATE_ROOTS
    for c in cands:
        if not c:
            continue
        p = Path(c).expanduser()
        if all((p / r / ".git").exists() for r in repos):
            return p
    print("ERROR: could not locate a code root containing all repos: "
          + ", ".join(repos), file=sys.stderr)
    print("Tried: " + ", ".join(x for x in cands if x), file=sys.stderr)
    sys.exit(2)


def git_files(repo_dir: Path) -> list[str]:
    out = subprocess.run(["git", "-C", str(repo_dir), "ls-files"],
                         check=True, capture_output=True, text=True).stdout
    return [ln for ln in out.splitlines() if ln]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--code-root", default=None)
    args = ap.parse_args()

    areas, exceptions, repos = load_areas()
    code_root = resolve_code_root(args.code_root, repos)
    print(f"code root: {code_root}", file=sys.stderr)

    area_pats = {a["id"]: [glob_to_regex(g) for g in a.get("code", [])] for a in areas}
    exc_pats = [(e["glob"], glob_to_regex(e["glob"])) for e in exceptions]

    all_files: list[str] = []
    for r in repos:
        for f in git_files(code_root / r):
            all_files.append(f"{r}/{f}")

    counts = {a["id"]: 0 for a in areas}
    multi = 0
    unmatched: list[str] = []
    exc_only: list[str] = []
    exc_counts: dict[str, int] = {g: 0 for g, _ in exc_pats}

    for f in all_files:
        hits = [aid for aid, pats in area_pats.items() if any(p.match(f) for p in pats)]
        for aid in hits:
            counts[aid] += 1
        if len(hits) > 1:
            multi += 1
        if not hits:
            exc_hit = next((g for g, p in exc_pats if p.match(f)), None)
            if exc_hit:
                exc_counts[exc_hit] += 1
                exc_only.append(f)
            else:
                unmatched.append(f)

    print(f"\ntotal tracked files across {len(repos)} repos: {len(all_files)}")
    print("per-area file counts (overlaps counted in each area):")
    for a in areas:
        print(f"  {a['id']:<20} {counts[a['id']]}")
    print(f"files in >1 area (overlap): {multi}")
    print("\nexception matches:")
    for g, _ in exc_pats:
        print(f"  {g:<45} {exc_counts[g]}")
    matched = len(all_files) - len(unmatched) - len(exc_only)
    print(f"\nmatched to >=1 area : {matched}")
    print(f"exception-only      : {len(exc_only)}")
    print(f"UNMATCHED           : {len(unmatched)}")
    if unmatched:
        print("\n--- UNMATCHED (coverage incomplete) ---")
        for f in unmatched:
            print("  " + f)
        return 1
    print("\nOK: every tracked code file maps to an area or a declared exception.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
