"""pack (47-03 §4) and check (47-03 §3): program-selected rules for a task or a diff."""
from __future__ import annotations

import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path

from . import config, globs, md
from .config import REPO_NAMES, CtxError, Ctx, tokens
from .model import Corpus, find_spec, resolve_doc, spec_id, umbrella_for, untagged_note
from .query import render_adr, render_lesson
from .sources import parse_manifest


def _add(d: dict, k: str, why: str) -> None:
    if why not in d[k]:
        d[k].append(why)


def select(c: Corpus, manifest: dict, extra_areas: list[str]) -> dict:
    """The pack algorithm. Returns the areas / adrs / lessons / sections chosen, each with reasons."""
    areas: dict[str, list[str]] = defaultdict(list)
    for a in manifest.get("areas", []):
        _add(areas, a, "manifest")
    for a in extra_areas:
        _add(areas, a, "--areas")
    code = manifest.get("code", [])
    for entry in code:
        for a in c.areas_for_code(entry):
            _add(areas, a, f"path `{entry}`")
    for a in c.always_areas():
        _add(areas, a, "always-on")
    unknown = sorted(a for a in areas if a not in c.areas)
    if unknown:
        raise CtxError("unknown area(s): " + ", ".join(unknown) + f" (known: {', '.join(sorted(c.areas))})")
    names = set(areas)

    adrs: dict[str, list[str]] = defaultdict(list)
    for raw in manifest.get("adrs", []):
        i = md.parse_adr_id(raw)
        if not i or not (c.adr_known(i) or i in c.adr_tags):
            raise CtxError(f"manifest names unknown ADR `{raw}`")
        _add(adrs, i, "manifest")
    for i, why in c.adrs_for_areas(names).items():
        _add(adrs, i, why)
    for i, t in sorted(c.adr_tags.items()):
        hit = c.globs_touch(list(t.get("paths", []) or []), code) if code else None
        if hit:
            _add(adrs, i, f"path `{hit}`")
    for i, why in c.pack_chain(list(adrs)).items():
        if why:
            _add(adrs, i, why)

    lessons: dict[str, list[str]] = defaultdict(list)
    for raw in manifest.get("lessons", []):
        i = md.parse_lesson_id(raw)
        if not i or not c.lesson(i):
            raise CtxError(f"manifest names unknown lesson `{raw}`")
        _add(lessons, i, "manifest")
    for i, why in c.lessons_for_areas(names).items():
        _add(lessons, i, why)

    sections: dict[str, list[str]] = defaultdict(list)
    for k, why in c.sections_for_areas(names).items():
        _add(sections, k, why)
    return {"areas": dict(areas), "adrs": dict(adrs), "lessons": dict(lessons), "sections": dict(sections)}


def _table(rows: list[tuple[str, str]], head=("item", "why")) -> list[str]:
    out = [f"| {head[0]} | {head[1]} |", "|---|---|"]
    out += [f"| {a} | {b} |" for a, b in rows]
    return out


def build_pack(ctx: Ctx, ref: str | None, extra_areas: list[str]) -> tuple[str, str, dict]:
    c = Corpus(ctx)
    manifest: dict = {}
    notes: list[str] = []
    spec: Path | None = None
    if ref:
        spec = find_spec(ctx, ref)
        m = parse_manifest(spec.read_text(encoding="utf-8"))
        if m.error:
            notes.append(f"⚠ {ctx.rel(spec)}: {m.error} — using --areas and always-on areas only.")
        manifest = m.data if not m.error else {}
        task = spec_id(spec)
    else:
        if not extra_areas:
            raise CtxError("pack needs a sub-spec id/path or --areas")
        task = "areas-" + "-".join(sorted(extra_areas))
    sel = select(c, manifest, extra_areas)

    docs: dict[str, list[str]] = defaultdict(list)
    for d in manifest.get("docs", []):
        _add(docs, d, "manifest")
    for a in sorted(sel["areas"]):
        for d in c.areas[a].get("docs", []) or []:
            _add(docs, d, f"area {a}")
    for up in manifest.get("upstream", []):
        try:
            p = find_spec(ctx, up)
            _add(docs, "tracker:" + ctx.rel(p), f"upstream {up} (read its As-built)")
        except CtxError as e:
            notes.append(f"⚠ upstream `{up}`: {e}")
    if spec:
        umb = umbrella_for(ctx, spec)
        if umb:
            _add(docs, "tracker:" + ctx.rel(umb), "umbrella spec")
    code_rows = [(f"`{x}`", "manifest code") for x in manifest.get("code", [])]

    adr_ids = sorted(sel["adrs"])
    lesson_ids = sorted(sel["lessons"])
    sec_keys = [s.key for s in c.sections if s.key in sel["sections"]]

    # Full text only for DIRECT hits: manifest `adrs`, path-glob hits, and their amendment chains.
    # Rules that reached the pack only through an area become a one-line "Also applies" pointer the
    # agent loads on demand (one-hop progressive disclosure, 47-09 M3b). `check` keeps the full
    # area-wide checklist; recall (§3) counts full ∪ listed.
    direct_seeds = [i for i, w in sel["adrs"].items()
                    if any(r == "manifest" or r.startswith("path ") for r in w)]
    direct = set(c.pack_chain(direct_seeds))
    full_adr_ids = [i for i in adr_ids if i in direct]
    also_adr_ids = [i for i in adr_ids if i not in direct]
    full_lesson_ids = [i for i in lesson_ids if "manifest" in sel["lessons"][i]]
    also_lesson_ids = [i for i in lesson_ids if i not in full_lesson_ids]
    b04_own, b04_refs = c.b04_assignment(full_adr_ids, honor_skip=True)   # dedupe + honour `b04 = "skip"`

    def _adr(i: str) -> str:
        return render_adr(c, i, level=3, b04_bullets=b04_own[i], b04_refs=b04_refs[i])

    body: list[str] = []
    body += ["## Areas", ""] + _table([(a, "; ".join(w)) for a, w in sorted(sel["areas"].items())], ("area", "why"))
    inc = [(i, "; ".join(sel["adrs"][i])) for i in adr_ids] + \
          [(i, "; ".join(sel["lessons"][i])) for i in lesson_ids] + \
          [(f"`{k}`", "; ".join(sel["sections"][k])) for k in sec_keys]
    body += ["", "## Included", ""] + (_table(inc) if inc else ["_(nothing routed — see the untagged note)_"])
    note = untagged_note(c)
    if note:
        body += ["", note]
    body += ["", "## ADRs — full text", ""]
    body += [_adr(i) for i in full_adr_ids] or ["_(none — manifest `adrs`, path hits and their chains only; see Also applies)_"]
    body += ["", "## Lessons — full text", ""]
    body += [render_lesson(c, i, level=3) for i in full_lesson_ids] or ["_(none — manifest `lessons` only; see Also applies)_"]
    also_rows = [(i, c.adr_rule(i) or "(no rule yet)") for i in also_adr_ids] + \
                [(i, c.lesson_rule(i)) for i in also_lesson_ids]
    body += ["", "## Also applies — load with `genesis-ctx adr|lesson <id>` before changing related code", ""]
    body += _table(also_rows, ("id", "rule")) if also_rows else ["_(none)_"]
    body += ["", "## Code map", ""]
    for k in sec_keys:
        s = c.section(k)
        body += [f"### `{k}` (bible/03 L{s.lineno})", "", "````text", s.display, "````", ""]
    if not sec_keys:
        body += ["_(none)_"]
    body += ["", "## Read next", "", "Open these yourself, in ranges.", ""]
    rows = [(f"`{d}`" + ("" if resolve_doc(ctx, d).exists() or globs.WILD.search(d) else " (missing)"),
             "; ".join(w)) for d, w in docs.items()] + code_rows
    body += _table(rows, ("path", "why")) if rows else ["_(none)_"]
    body_text = "\n".join(body) + "\n"

    est = tokens(body_text)
    verdict = "FAIL" if est > config.PACK_FAIL else "WARN" if est > config.PACK_WARN else "OK"
    head = [f"# Context pack — {task}", ""]
    if spec:
        head.append(f"Spec: `{ctx.rel(spec)}`")
    head.append(f"~{est:,} tokens · budget **{verdict}** (warn {config.PACK_WARN:,} / fail {config.PACK_FAIL:,})")
    if verdict == "FAIL":
        head.append("Too big: narrow `areas` in the manifest (excluded rules stay visible in the L0 digests).")
    head += [f"- {n}" for n in notes]
    text = "\n".join(head) + "\n\n" + body_text
    summary = {
        "task": task, "tokens": est, "verdict": verdict,
        "counts": {"areas": len(sel["areas"]), "adrs": len(full_adr_ids), "adrs_also": len(also_adr_ids),
                   "lessons": len(full_lesson_ids), "lessons_also": len(also_lesson_ids),
                   "sections": len(sec_keys), "read_next": len(rows)},
        "parts": {
            "adrs": sum(tokens(_adr(i)) for i in full_adr_ids),
            "lessons": sum(tokens(render_lesson(c, i, level=3)) for i in full_lesson_ids),
            "sections": sum(tokens(c.section(k).display) for k in sec_keys),
        },
    }
    return task, text, summary


def cmd_pack(ctx: Ctx, ref: str | None, areas_csv: str | None, out: str | None) -> int:
    extra = [a.strip() for a in (areas_csv or "").split(",") if a.strip()]
    task, text, s = build_pack(ctx, ref, extra)
    path = Path(out) if out else ctx.packs_dir / (re.sub(r"[^A-Za-z0-9_.-]+", "_", task) + ".md")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"Pack written: {path}\n")
    print("| part | items | ~tokens |\n|---|---:|---:|")
    print(f"| areas | {s['counts']['areas']} | |")
    print(f"| ADRs — full text | {s['counts']['adrs']} | {s['parts']['adrs']:,} |")
    print(f"| lessons — full text | {s['counts']['lessons']} | {s['parts']['lessons']:,} |")
    print(f"| also applies (one-line pointers) | {s['counts']['adrs_also'] + s['counts']['lessons_also']} | |")
    print(f"| code-map sections | {s['counts']['sections']} | {s['parts']['sections']:,} |")
    print(f"| read next | {s['counts']['read_next']} | |")
    print(f"| **total** | | **{s['tokens']:,}** — {s['verdict']} |")
    if s["verdict"] == "FAIL":
        print("\nBudget exceeded: narrow the areas (excluded rules remain in the L0 digests).")
        return 1
    return 0


# ───────────────────────────── check ─────────────────────────────

def _git_lines(repo: Path, *args: str) -> list[str] | None:
    try:
        r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    return [l for l in r.stdout.split("\n") if l.strip()]


def changed_files(ctx: Ctx, since: str | None, files: list[str] | None, staged: bool,
                  repo: str | None) -> tuple[list[str], list[str]]:
    notes: list[str] = []
    if files:
        out = []
        for f in files:
            p = Path(f)
            if p.is_absolute():
                rel = ctx.rel(p)
                if ctx.inside_tracker(p):
                    rel = "tracker:" + rel
                out.append(rel)
            else:
                out.append(f"{repo}/{f}" if repo else f)
        return out, notes
    names = [repo] if repo else list(REPO_NAMES)
    out: list[str] = []
    scanned = resolved = 0
    for name in names:
        root = ctx.repos / name
        if not root.is_dir():
            if repo:
                raise CtxError(f"repo not found: {root}")
            continue
        scanned += 1
        if since:
            if _git_lines(root, "rev-parse", "--verify", "--quiet", since + "^{commit}") is None:
                if repo:
                    raise CtxError(f"{name}: unknown revision `{since}`")
                notes.append(f"{name}: `{since}` does not resolve — skipped")
                continue
            resolved += 1
            lines = (_git_lines(root, "diff", "--name-only", since) or []) + \
                    (_git_lines(root, "ls-files", "--others", "--exclude-standard") or [])
        else:
            lines = _git_lines(root, "diff", "--cached", "--name-only") or []
        out += [f"{name}/{l}" for l in lines]
    # project-tracker itself (m2): emit `tracker:` paths relative to genesis/ (not scanned under --repo).
    if not repo and _git_lines(ctx.tracker, "rev-parse", "--show-toplevel") is not None:
        scanned += 1
        tr_lines: list[str] | None = []
        if since:
            if _git_lines(ctx.tracker, "rev-parse", "--verify", "--quiet", since + "^{commit}") is None:
                notes.append(f"project-tracker: `{since}` does not resolve — skipped")
                tr_lines = None
            else:
                resolved += 1
                tr_lines = (_git_lines(ctx.tracker, "diff", "--name-only", "--relative", since) or []) + \
                           (_git_lines(ctx.tracker, "ls-files", "--others", "--exclude-standard") or [])
        else:
            tr_lines = _git_lines(ctx.tracker, "diff", "--cached", "--name-only", "--relative") or []
        if tr_lines:
            out += [f"tracker:{l}" for l in tr_lines]
    if since and scanned and resolved == 0:
        raise CtxError(f"`{since}` does not resolve in any repo (code repos or project-tracker)")
    return sorted(set(out)), notes


def cmd_check(ctx: Ctx, since: str | None, files: list[str] | None, staged: bool, repo: str | None,
              as_json: bool = False) -> int:
    if sum(bool(x) for x in (since, files, staged)) != 1:
        raise CtxError("check needs exactly one of --since REV, --files F…, --staged")
    c = Corpus(ctx)
    paths, notes = changed_files(ctx, since, files, staged, repo)
    per_file = {p: c.areas_for_code(p) for p in paths}
    area_why: dict[str, list[str]] = defaultdict(list)
    for al in per_file.values():
        for a in al:
            _add(area_why, a, "files")
    for a in c.always_areas():
        _add(area_why, a, "always-on")
    names = set(area_why)
    adrs: dict[str, list[str]] = defaultdict(list)
    for i, why in c.adrs_for_areas(names).items():
        _add(adrs, i, why)
    for i, t in sorted(c.adr_tags.items()):
        pats = list(t.get("paths", []) or [])
        hit = c.globs_touch(pats, paths) if pats else None
        if hit:
            _add(adrs, i, f"path `{hit}`")
    for i, why in c.pack_chain(list(adrs)).items():
        if why:
            _add(adrs, i, why)
    lessons = c.lessons_for_areas(names)
    gates = [(g, a) for a in sorted(names) for g in (c.areas[a].get("gates", []) or [])]
    if as_json:
        print(json.dumps({
            "files": [{"path": p, "areas": al} for p, al in per_file.items()],
            "areas": sorted(names),
            "adrs": [{"id": i, "rule": c.adr_rule(i), "why": adrs[i]} for i in sorted(adrs)],
            "lessons": [{"id": i, "rule": c.lesson_rule(i), "why": w} for i, w in lessons.items()],
            "gates": [{"command": g, "area": a} for g, a in gates],
            "untagged": c.untagged_counts(), "notes": notes,
        }, indent=2))
        return 0
    out = [f"# genesis-ctx check — {len(paths)} changed files", ""]
    out += [f"- {n}" for n in notes]
    out += ["## Files → areas", "", "| file | areas |", "|---|---|"]
    out += [f"| `{p}` | {', '.join(al) or '—'} |" for p, al in per_file.items()] or ["| (none) | |"]
    out += ["", "Areas: " + ", ".join(sorted(names)), ""]
    out += ["## Checklist — answer every line OK / VIOLATION / N/A with evidence", "", "### ADRs"]
    out += [f"- [ ] {i} — {c.adr_rule(i) or '(no rule yet)'}  _({'; '.join(adrs[i])})_" for i in sorted(adrs)] \
        or ["_(none routed)_"]
    out += ["", "### Lessons"]
    out += [f"- [ ] {i} — {c.lesson_rule(i)}  _({w})_" for i, w in lessons.items()] or ["_(none routed)_"]
    out += ["", "### Gates"]
    out += [f"- [ ] `{g}`  _(area {a})_" for g, a in gates] or ["_(no gates defined for these areas)_"]
    note = untagged_note(c)
    if note:
        out += ["", note]
    print("\n".join(out))
    return 0
