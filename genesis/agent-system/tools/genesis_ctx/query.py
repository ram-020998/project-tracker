"""Read-only commands: status, adr, lesson, area, search."""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

from . import globs, md
from .config import REPO_NAMES, CtxError, Ctx, read
from .model import Corpus, resolve_doc


# ───────────────────────────── status ─────────────────────────────

def git(repo: Path, *args: str, timeout: float = 5.0) -> str | None:
    try:
        r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout.rstrip("\n") if r.returncode == 0 else None


def repo_status(path: Path) -> dict:
    if not path.is_dir() or git(path, "rev-parse", "--git-dir") is None:
        return {"present": False}
    porcelain = git(path, "status", "--porcelain") or ""
    ahead = git(path, "rev-list", "--count", "@{u}..HEAD")
    return {
        "present": True,
        "branch": git(path, "rev-parse", "--abbrev-ref", "HEAD") or "-",
        "tag": git(path, "describe", "--tags", "--abbrev=0") or "-",
        "dirty": len([l for l in porcelain.split("\n") if l.strip()]),
        "ahead": int(ahead) if ahead and ahead.isdigit() else None,
    }


def active_phase(ctx: Ctx) -> str | None:
    for line in read(ctx.state_file).split("\n"):
        if re.search(r"(?i)\bactive phase\b", line):
            text = md.collapse(re.sub(r"[*_>`]|^\s*[-#]+\s*", "", line))
            return re.sub(r"(?i)^active phase\s*:?\s*", "", text) or None
    return None


def cmd_status(ctx: Ctx, brief: bool = False, as_json: bool = False) -> int:
    rows = {name: repo_status(ctx.repos / name) for name in REPO_NAMES}
    tracker_root = git(ctx.tracker, "rev-parse", "--show-toplevel")
    rows["project-tracker"] = repo_status(Path(tracker_root)) if tracker_root else {"present": False}
    phase = active_phase(ctx)
    if as_json:
        print(json.dumps({"repos": rows, "active_phase": phase, "tracker": str(ctx.tracker),
                          "repos_root": str(ctx.repos)}, indent=2))
        return 0
    fmt_ahead = lambda r: "-" if r.get("ahead") is None else str(r["ahead"])  # noqa: E731
    if brief:
        print("genesis-ctx status (local refs only, no fetch)")
        for name, r in rows.items():
            if not r["present"]:
                print(f"{name:<22} (missing)")
            else:
                print(f"{name:<22} {r['branch']:<10} {r['tag']:<12} dirty {r['dirty']:<3} ahead {fmt_ahead(r)}")
        print(f"Active phase: {phase or '(context/state/current.md not written yet — 47-05)'}")
        return 0
    print("# genesis-ctx status\n")
    print(f"Tracker: `{ctx.tracker}` · repos: `{ctx.repos}` · local refs only (no fetch)\n")
    print("| repo | branch | latest tag | dirty files | ahead of upstream |")
    print("|---|---|---|---:|---:|")
    for name, r in rows.items():
        if not r["present"]:
            print(f"| {name} | (missing) | | | |")
        else:
            print(f"| {name} | {r['branch']} | {r['tag']} | {r['dirty']} | {fmt_ahead(r)} |")
    print(f"\n**Active phase:** {phase or '(context/state/current.md not written yet — 47-05)'}")
    return 0


# ───────────────────────────── adr / lesson / area ─────────────────────────────

def _ids(raw: list[str], parser, kind: str) -> list[str]:
    out = []
    for r in raw:
        for part in re.split(r"[,\s]+", r.strip()):
            if not part:
                continue
            i = parser(part)
            if not i:
                raise CtxError(f"not a valid {kind} id: {part}")
            if i not in out:
                out.append(i)
    return out


def render_adr(c: Corpus, adr_id: str, reason: str = "", level: int = 2) -> str:
    h, h2 = "#" * level, "#" * (level + 1)
    tag = c.adr_tags.get(adr_id)
    head = f"{h} {adr_id} — {c.adr_title(adr_id)}"
    meta = []
    if tag:
        meta.append("[" + ",".join(tag.get("areas", []) or []) + "]")
        if tag.get("status"):
            meta.append(tag["status"])
        if tag.get("amends"):
            meta.append("amends " + ", ".join(tag["amends"]))
        if tag.get("amended_by"):
            meta.append("amended by " + ", ".join(tag["amended_by"]))
        if tag.get("superseded_by"):
            meta.append("superseded by " + tag["superseded_by"])
    else:
        meta.append("[untagged]")
    if reason:
        meta.append(reason)
    out = [head, "", " · ".join(meta)]
    rule = c.adr_rule(adr_id)
    if rule:
        out += ["", f"**Rule:** {rule}"]
    for a in c.anchors_for(adr_id):
        out += ["", f"{h2} decision-log.md L{a.lineno}–L{a.end} ({a.kind}, {a.form})", "", a.text]
    for b in c.b04_for(adr_id):
        out += ["", f"{h2} bible/04 L{b.lineno}", "", b.text]
    if not c.anchors_for(adr_id) and not c.b04_for(adr_id):
        out += ["", "_(no text found in decision-log.md or bible/04)_"]
    return "\n".join(out)


def cmd_adr(ctx: Ctx, ids: list[str], chain: bool = True) -> int:
    c = Corpus(ctx)
    wanted = _ids(ids, md.parse_adr_id, "ADR")
    unknown = [i for i in wanted if not c.adr_known(i) and i not in c.adr_tags]
    if unknown:
        raise CtxError("unknown ADR id(s): " + ", ".join(unknown))
    closure = c.chain(wanted, chain)
    order = wanted + sorted(k for k in closure if k not in wanted)
    print("\n\n".join(render_adr(c, i, closure[i]) for i in order))
    return 0


def render_lesson(c: Corpus, lesson_id: str, reason: str = "", level: int = 2) -> str:
    h = "#" * level
    l = c.lesson(lesson_id)
    tag = c.lesson_tags.get(lesson_id)
    meta = ["[" + ",".join(tag.get("areas", []) or []) + "]" if tag else "[untagged]"]
    if tag and tag.get("phase"):
        meta.append(f"phase {tag['phase']}")
    if reason:
        meta.append(reason)
    if not l:
        return f"{h} {lesson_id}\n\n" + " · ".join(meta) + "\n\n_(marker not found in bible/06 §7)_"
    return f"{h} {lesson_id} (bible/06 L{l.lineno})\n\n" + " · ".join(meta) + "\n\n" + l.text


def cmd_lesson(ctx: Ctx, ids: list[str]) -> int:
    c = Corpus(ctx)
    wanted = _ids(ids, md.parse_lesson_id, "lesson")
    if c.lessons and not any(l.marker for l in c.lessons):
        raise CtxError("bible/06 lessons carry no <!-- L-NNN --> markers yet — run `genesis-ctx mark` (47-04)")
    unknown = [i for i in wanted if not c.lesson(i)]
    if unknown:
        raise CtxError("unknown lesson id(s): " + ", ".join(unknown))
    print("\n\n".join(render_lesson(c, i) for i in wanted))
    return 0


def area_line(name: str, a: dict) -> str:
    bits = [f"**{name}** — {a.get('title', '(no title)')}"]
    if a.get("always"):
        bits.append("always-on")
    else:
        bits.append(f"{len(a.get('paths', []) or [])} path globs")
    if a.get("skills"):
        bits.append("skills: " + ", ".join(a["skills"]))
    if a.get("gates"):
        bits.append(f"{len(a['gates'])} gates")
    return " · ".join(bits)


def cmd_area(ctx: Ctx, name: str) -> int:
    c = Corpus(ctx)
    if name not in c.areas:
        raise CtxError(f"unknown area `{name}` (known: {', '.join(sorted(c.areas))})")
    a = c.areas[name]
    out = [f"# Area `{name}`", "", "- " + area_line(name, a)]
    for g in a.get("paths", []) or []:
        out.append(f"  - `{g}` — {len(c.expand(g))} files")
    for k in ("keywords", "docs", "gates"):
        if a.get(k):
            out.append(f"- {k}: " + ", ".join(f"`{x}`" for x in a[k]))
    adrs = c.adrs_for_areas({name})
    out += ["", f"## ADRs ({len(adrs)})"]
    out += [f"- {i} — {c.adr_rule(i) or '(no rule yet)'}" for i in adrs]
    lessons = c.lessons_for_areas({name})
    out += ["", f"## Lessons ({len(lessons)})"]
    out += [f"- {i} — {c.lesson_rule(i)}" for i in lessons]
    secs = c.sections_for_areas({name})
    out += ["", f"## Code-map sections ({len(secs)})"]
    out += [f"- `{k}`" for k in secs]
    note = None
    u = c.untagged_counts()
    if any(u.values()):
        note = f"_Untagged so far: {u['adrs']} ADRs, {u['lessons']} lessons, {u['sections']} sections (47-05)._"
    if note:
        out += ["", note]
    print("\n".join(out))
    return 0


# ───────────────────────────── search ─────────────────────────────

ACTIVE = ["AGENT_ONBOARDING.md", "README.md", "tracker.md", "bible/**", "reference/**", "context/**",
          "agent-system/**"]
HISTORY = ["archive/**", "specs/**", "progress/**"]
TEXT_EXT = {".md", ".toml", ".txt"}


def search_files(ctx: Ctx, with_archive: bool) -> list[str]:
    out: list[str] = []
    for pat in ACTIVE + (HISTORY if with_archive else []):
        for f in globs.expand(ctx.tracker, pat):
            if f.startswith("context/.packs/") or Path(f).suffix not in TEXT_EXT:
                continue
            if f not in out:
                out.append(f)
    return out


def cmd_search(ctx: Ctx, pattern: str, with_archive: bool = False, max_hits: int = 50,
               case: bool = False) -> int:
    try:
        rx = re.compile(pattern, 0 if case else re.I)
    except re.error as e:
        raise CtxError(f"invalid regex: {e}") from e
    hits = 0
    for f in search_files(ctx, with_archive):
        lines = read(ctx.tracker / f).split("\n")
        for i, line in enumerate(lines):
            if rx.search(line):
                hits += 1
                print(f"{f}:{i + 1}: {line.strip()[:200]}")
                if i + 1 < len(lines) and lines[i + 1].strip():
                    print(f"    {lines[i + 1].strip()[:200]}")
                if hits >= max_hits:
                    print(f"… stopped at {max_hits} hits (--max)")
                    return 0
    if not hits:
        print("no matches" + ("" if with_archive else " (active layer; add --archive for history)"))
        return 1
    return 0


def doc_exists(ctx: Ctx, ref: str) -> bool:
    p = resolve_doc(ctx, ref)
    return p.exists() or bool(globs.WILD.search(ref))
