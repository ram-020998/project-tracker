"""One-shot migration commands (47-04): mark, archive, propose-tags, verify-lossless."""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import re
import subprocess
import tomllib
from collections import defaultdict
from pathlib import Path

from . import config, globs, md, tomlio
from .config import CtxError, Ctx, read
from .model import Corpus

POINTER_PREFIX = "> 📦 Moved verbatim to "


def esc(s: str) -> str:
    """Escape a table cell."""
    return s.replace("|", "\\|")


def today() -> str:
    return _dt.date.today().isoformat()


# ───────────────────────────── mark ─────────────────────────────

def cmd_mark(ctx: Ctx, dry_run: bool = False) -> int:
    c = Corpus(ctx)
    if not c.lessons:
        raise CtxError("no lessons found under `## 7.` in bible/06")
    used = {md.num(l.marker) for l in c.lessons if l.marker}
    used |= {md.num(k) for k in c.lesson_tags if md.LESSON_ID_RE.match(k)}
    nxt = max(used, default=0) + 1
    lines = c.bible06_text.split("\n")
    added = []
    for l in c.lessons:
        if l.marker:
            continue
        lid = md.fmt_lesson(nxt)
        lines[l.start] = re.sub(r"^- ", f"- <!-- {lid} --> ", lines[l.start], count=1)
        added.append((lid, l.lineno))
        nxt += 1
    if added and not dry_run:
        ctx.bible06.write_text("\n".join(lines), encoding="utf-8")
    verb = "would mark" if dry_run else "marked"
    print(f"mark: {verb} {len(added)} lesson(s)" + (f": {added[0][0]}..{added[-1][0]}" if added else
                                                     " — every lesson already has a marker"))
    return 0


# ───────────────────────────── archive ─────────────────────────────

PLAN_TOP = {"date", "baseline", "step"}
STEP_KEYS = {"n", "name", "source", "dest", "start", "include_start", "end", "heading", "contains", "stop",
             "pointer", "note"}


def load_plan(path: Path) -> tuple[str, list[dict]]:
    try:
        data = tomllib.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError as e:
        raise CtxError(f"plan not found: {path}") from e
    except tomllib.TOMLDecodeError as e:
        raise CtxError(f"plan {path}: invalid TOML: {e}") from e
    bad = set(data) - PLAN_TOP
    if bad:
        raise CtxError(f"plan: unknown top-level key(s): {', '.join(sorted(bad))}")
    steps = data.get("step", [])
    if not isinstance(steps, list) or not steps:
        raise CtxError("plan: needs at least one [[step]]")
    for k, s in enumerate(steps, 1):
        where = f"plan step #{k}"
        bad = set(s) - STEP_KEYS
        if bad:
            raise CtxError(f"{where}: unknown key(s): {', '.join(sorted(bad))}")
        for req in ("n", "name", "source", "dest"):
            if req not in s:
                raise CtxError(f"{where}: missing `{req}`")
        a, b = "start" in s, "heading" in s
        if a == b:
            raise CtxError(f"{where}: exactly one selector — `start` (A) or `heading` + `contains` + `stop` (B)")
        if b and (not s.get("contains") or not s.get("stop")):
            raise CtxError(f"{where}: selector B needs `contains` and `stop`")
        if s.get("pointer", "each") not in ("each", "first", "none"):
            raise CtxError(f"{where}: pointer must be each | first | none")
        for key in ("start", "end", "heading") + tuple(f"stop[{i}]" for i in range(len(s.get("stop", [])))):
            rx = s["stop"][int(key[5:-1])] if key.startswith("stop[") else s.get(key)
            if rx and rx != "EOF":
                try:
                    re.compile(rx)
                except re.error as e:
                    raise CtxError(f"{where}: bad regex in `{key}`: {e}") from e
    return str(data.get("date") or today()), steps


def _blank(s: str) -> bool:
    return s.strip() == ""


def find_blocks(lines: list[str], step: dict) -> list[tuple[int, int]] | str:
    """Line ranges [a, b) to move, or "applied" / "none"."""
    if "start" in step:
        rx = re.compile(step["start"])
        s = next((i for i, l in enumerate(lines) if rx.search(l)), None)
        if s is None:
            return "none"
        a = s if step.get("include_start", True) else s + 1
        end = step.get("end", "EOF")
        if end == "EOF":
            b = len(lines)
        else:
            erx = re.compile(end)
            b = next((j for j in range(a + (1 if step.get("include_start", True) else 0), len(lines))
                      if erx.search(lines[j])), len(lines))
        while a < b and _blank(lines[a]):
            a += 1
        while b > a and _blank(lines[b - 1]):
            b -= 1
        if a >= b:
            return "applied"
        if lines[a].startswith(POINTER_PREFIX):
            return "applied"
        return [(a, b)]
    hrx = re.compile(step["heading"])
    stops = [re.compile(x) for x in step["stop"]]
    out: list[tuple[int, int]] = []
    i = 0
    while i < len(lines):
        if hrx.search(lines[i]) and any(c in lines[i] for c in step["contains"]):
            j = next((k for k in range(i + 1, len(lines)) if any(s.search(lines[k]) for s in stops)), len(lines))
            b = j
            while b > i + 1 and _blank(lines[b - 1]):
                b -= 1
            out.append((i, b))
            i = j
        else:
            i += 1
    return out or "none"


def pointer_line(source: str, dest: str, date: str) -> str:
    link = os.path.relpath(dest, os.path.dirname(source) or ".").replace(os.sep, "/")
    return (f"{POINTER_PREFIX}[{dest}]({link}) (Phase 47-04, {date}). "
            "Search with `genesis-ctx search <term> --archive`.")


def cmd_archive(ctx: Ctx, plan: str, step_n: int | None, apply: bool) -> int:
    date, steps = load_plan(Path(plan))
    chosen = [s for s in steps if step_n is None or int(s["n"]) == step_n]
    if not chosen:
        raise CtxError(f"plan has no step n = {step_n}")
    rows = []
    for s in chosen:
        src, dst = ctx.t(s["source"]), ctx.t(s["dest"])
        for p in (src, dst):
            if not ctx.inside_tracker(p):
                raise CtxError(f"step {s['n']}: {p} is outside project-tracker/genesis/")
        if not src.is_file():
            raise CtxError(f"step {s['n']}: source not found: {s['source']}")
        lines = read(src).split("\n")
        blocks = find_blocks(lines, s)
        if blocks == "none":
            if s["dest"] in read(src) and POINTER_PREFIX in read(src):
                blocks = "applied"
            else:
                raise CtxError(f"step {s['n']} ({s['name']}): selector matches nothing in {s['source']}")
        if blocks == "applied":
            rows.append((s["n"], s["source"], "—", 0, "(already applied)", s["dest"]))
            continue
        for a, b in blocks:
            text = "\n".join(lines[a:b])
            rows.append((s["n"], s["source"], f"L{a + 1}–L{b}", len(text.encode()), lines[a][:60], s["dest"]))
        if not apply:
            continue
        chunks = []
        if not dst.exists():
            chunks.append(f"# {s['name']} — archived verbatim\n\n> Moved verbatim from `{s['source']}` in Phase "
                          f"47-04. Never mandatory: search with `genesis-ctx search <term> --archive`; don't read "
                          f"whole.\n\n")
        for a, b in blocks:
            chunks.append(f"<!-- archived from {s['source']} L{a + 1}–L{b}, step {s['n']}, {date} -->\n\n"
                          + "\n".join(lines[a:b]) + "\n\n")
        dst.parent.mkdir(parents=True, exist_ok=True)
        with dst.open("a", encoding="utf-8") as fh:
            fh.write("".join(chunks))
        mode = s.get("pointer", "each")
        ptr = pointer_line(s["source"], s["dest"], date)
        for idx in range(len(blocks) - 1, -1, -1):
            a, b = blocks[idx]
            rep: list[str] = []
            if mode == "each" or (mode == "first" and idx == 0):
                rep = [ptr]
            if idx == 0 and s.get("note"):
                rep += ["", s["note"]] if rep else [s["note"]]
            if rep:
                # Keep the pointer its own block: a pointer glued to a kept bullet would change that unit.
                if a > 0 and not _blank(lines[a - 1]):
                    rep = [""] + rep
                if b < len(lines) and not _blank(lines[b]):
                    rep = rep + [""]
            lines[a:b] = rep
            if not rep and 0 < a < len(lines) and _blank(lines[a - 1]) and _blank(lines[a]):
                del lines[a]
        src.write_text("\n".join(lines), encoding="utf-8")
    head = "applied" if apply else "dry run — nothing written; add --apply to write"
    print(f"# archive {plan} — {head}\n")
    print("| step | source | lines | bytes | first line | dest |\n|---|---|---|---:|---|---|")
    for n, src, rng, size, first, dst in rows:
        print(f"| {n} | `{src}` | {rng} | {size:,} | {esc(first)} | `{dst}` |")
    print(f"\n{sum(r[3] for r in rows):,} bytes in {sum(1 for r in rows if r[2] != '—')} block(s)")
    return 0


# ───────────────────────────── verify-lossless ─────────────────────────────

HEADING = re.compile(r"^#{1,6}\s")
DUP_SKIP = ("agent-system/tests/fixtures/",)
ORDERED = re.compile(r"^\d+[.)] ")
TABLE_SEP = re.compile(r"^\|[\s:|-]+\|?$")


def units(text: str) -> list[tuple[int, str]]:
    """47-03 §6 units: blank-line blocks, split into top-level bullets; table rows, headings and
    fenced blocks are units of their own. Returns (1-based line, raw text)."""
    lines = text.split("\n")
    out: list[tuple[int, str]] = []
    cur: list[str] = []
    cur_start = 0

    def flush():
        nonlocal cur
        if cur:
            out.append((cur_start + 1, "\n".join(cur)))
            cur = []

    i = 0
    while i < len(lines):
        line = lines[i]
        m = md.FENCE_RE.match(line)
        if m:
            flush()
            ch, size = m.group(1)[0], len(m.group(1))
            j = i + 1
            while j < len(lines):
                cm = md.FENCE_RE.match(lines[j])
                if cm and cm.group(1)[0] == ch and len(cm.group(1)) >= size and lines[j].strip() == cm.group(1):
                    break
                j += 1
            out.append((i + 1, "\n".join(lines[i:j + 1])))
            i = j + 1
            continue
        if _blank(line):
            flush()
        elif line.lstrip().startswith("|") or HEADING.match(line):
            flush()
            out.append((i + 1, line))
        elif md.BULLET_START.match(line) or ORDERED.match(line):
            flush()
            cur_start, cur = i, [line]
        else:
            if not cur:
                cur_start = i
            cur.append(line)
        i += 1
    flush()
    return out


def normalize(raw: str) -> str:
    return md.collapse(md.MARKER_RE.sub("", raw))


def unit_hash(norm: str) -> str:
    return hashlib.sha256(norm.encode("utf-8")).hexdigest()[:16]


def counted(norm: str) -> bool:
    return len(norm) > 3 and not norm.startswith(POINTER_PREFIX.strip())


def md_files(ctx: Ctx) -> list[str]:
    out = []
    for dirpath, dirnames, filenames in os.walk(ctx.tracker):
        rel_dir = os.path.relpath(dirpath, ctx.tracker).replace(os.sep, "/")
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        for f in sorted(filenames):
            if f.endswith(".md"):
                out.append(f if rel_dir == "." else f"{rel_dir}/{f}")
    return out


def _git(root: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)


def cmd_verify_lossless(ctx: Ctx, baseline: str, write: bool = False, max_dups: int = 30) -> int:
    root = _git(str(ctx.tracker), "rev-parse", "--show-toplevel")
    if root.returncode != 0:
        raise CtxError("project-tracker is not a git repository")
    prefix = _git(str(ctx.tracker), "rev-parse", "--show-prefix").stdout.strip()
    rev = _git(str(ctx.tracker), "rev-parse", "--verify", "--quiet", baseline + "^{commit}")
    if rev.returncode != 0:
        raise CtxError(f"unknown baseline revision `{baseline}`")
    rev_id = rev.stdout.strip()
    base: dict[str, tuple[str, int, str]] = {}
    for f in config.MANDATORY_CORPUS:
        r = _git(root.stdout.strip(), "show", f"{rev_id}:{prefix}{f}")
        if r.returncode != 0:
            raise CtxError(f"`{f}` does not exist at {baseline}")
        for line, raw in units(r.stdout):
            n = normalize(raw)
            if counted(n):
                base.setdefault(unit_hash(n), (f, line, n))
    present: set[str] = set()
    where: dict[str, list[str]] = defaultdict(list)
    files = md_files(ctx)
    for f in files:
        if f.startswith("context/.packs/"):
            continue
        # Active layer for the duplicate report: not history, and not test fixtures (which copy real headings).
        active = f.split("/")[0] not in ("archive", "specs", "progress") and not f.startswith(DUP_SKIP)
        for line, raw in units(read(ctx.tracker / f)):
            n = normalize(raw)
            if not counted(n):
                continue
            h = unit_hash(n)
            present.add(h)
            if active and not TABLE_SEP.match(n):
                where[h].append(f"{f}:{line}")
    missing = [(h, v) for h, v in base.items() if h not in present]
    dups = sorted(((h, locs) for h, locs in where.items() if len(locs) > 1), key=lambda x: (-len(x[1]), x[1][0]))
    result = "PASS" if not missing else "FAIL"
    print(f"# verify-lossless — baseline `{baseline}` ({rev_id[:12]})\n")
    print(f"baseline units: {len(base):,} ({len(config.MANDATORY_CORPUS)} files) · working tree: {len(present):,} "
          f"distinct units in {len(files)} .md files")
    print(f"missing: **{len(missing)}** → {result}")
    if missing:
        print("\n## Missing units\n\n| file | line | text |\n|---|---:|---|")
        for _, (f, line, n) in sorted(missing, key=lambda x: (x[1][0], x[1][1]))[:200]:
            print(f"| `{f}` | {line} | {esc(n[:100])} |")
    print(f"\n## Duplicates in the active layer ({len(dups)})\n")
    if dups:
        print("| count | first locations | text |\n|---:|---|---|")
        texts = {unit_hash(normalize(raw)): normalize(raw) for f in files
                 if f.split("/")[0] not in ("archive", "specs", "progress")
                 for _, raw in units(read(ctx.tracker / f))}
        for h, locs in dups[:max_dups]:
            print(f"| {len(locs)} | {', '.join(locs[:3])} | {esc(texts.get(h, '')[:80])} |")
        if len(dups) > max_dups:
            print(f"\n… and {len(dups) - max_dups} more (--max-dups)")
    if write:
        ctx.archive_dir.mkdir(parents=True, exist_ok=True)
        (ctx.archive_dir / "LOSSLESS.json").write_text(json.dumps({
            "baseline": baseline, "baseline_commit": rev_id, "files": list(config.MANDATORY_CORPUS),
            "baseline_units": len(base), "missing": len(missing), "result": result,
            "missing_units": [{"file": f, "line": line, "text": n[:200]} for _, (f, line, n) in missing[:200]],
            "active_duplicates": len(dups),
            "timestamp": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat(),
        }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("\nwrote archive/LOSSLESS.json")
    return 0 if not missing else 1


# ───────────────────────────── propose-tags ─────────────────────────────

PATH_TOKEN = re.compile(r"(?<![\w/.-])((?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]*|[A-Za-z0-9_-]+\.(?:py|tsx?|json|ya?ml|toml|css))")
REL_RE = re.compile(r"\b(amends|amended by|refines|refined by|revises|revised by|supersedes|superseded by)\b[:\s]+"
                    r"((?:ADR-\d{3}(?:/\d{3})*(?:(?:–|\.\.)\d{3})?[\s,+&]*(?:and\s+|or\s+)?)+)", re.I)
STATUS_RE = re.compile(r"Status:?\**\s*\**\s*(Accepted|Proposed|Superseded|Amended)", re.I)


class Scorer:
    def __init__(self, c: Corpus):
        self.c = c
        self.files = {n: sorted({f for g in c.area_globs(n) for f in c.expand(g)}) for n in c.areas}
        self.phase_slug = {}
        if c.ctx.specs_dir.is_dir():
            for p in c.ctx.specs_dir.iterdir():
                m = re.match(r"^phase-(\d+)-(.+?)(?:\.md)?$", p.name)
                if m:
                    self.phase_slug.setdefault(int(m.group(1)), m.group(2).replace("-", " "))

    def _kw(self, text: str, name: str) -> list[tuple[str, int]]:
        low = text.lower()
        hits = []
        for k in self.c.areas[name].get("keywords", []) or []:
            n = len(re.findall(r"(?<![a-z0-9])" + re.escape(k.lower()) + r"(?![a-z0-9])", low))
            if n:
                hits.append((k, n))
        return hits

    def path_hit(self, name: str, tok: str) -> bool:
        tok = tok.strip("`").rstrip(".,;:)")
        if len(tok) < 4 or "://" in tok:
            return False
        if any(globs.match(g, tok) for g in self.c.area_globs(name)):
            return True
        stem = tok.rstrip("/")
        for f in self.files[name]:
            if f == stem or f.endswith("/" + stem) or ("/" + stem + "/") in ("/" + f):
                return True
        return False

    def score(self, text: str, paths: list[str] | None = None) -> tuple[list[str], str, str]:
        toks = list(dict.fromkeys(paths if paths is not None else
                                  [m.group(1) for m in PATH_TOKEN.finditer(text) if "{" not in m.group(1)]))[:40]
        phases = sorted({int(x) for x in re.findall(r"Phase[- ](\d+)", text)})
        scores: dict[str, float] = {}
        ev: dict[str, list[str]] = defaultdict(list)
        for name in self.c.areas:
            s = 0.0
            for k, n in self._kw(text, name):
                s += min(n, 3)
                ev[name].append(f"kw '{k}'×{n}")
            for t in toks:
                if self.path_hit(name, t):
                    s += 3
                    ev[name].append(f"path {t}")
            for ph in phases:
                slug = self.phase_slug.get(ph)
                if slug:
                    for k, _ in self._kw(slug, name):
                        s += 2
                        ev[name].append(f"phase {ph} '{k}'")
            if s:
                scores[name] = s
        if not scores:
            return [], "low", "no keyword, path or phase evidence"
        top = max(scores.values())
        chosen = [n for n, s in sorted(scores.items(), key=lambda x: (-x[1], x[0])) if s >= max(2, 0.4 * top)][:4]
        has_path = any(e.startswith("path") for n in chosen for e in ev[n])
        conf = "high" if top >= 6 and has_path else "medium" if top >= 3 else "low"
        evidence = "; ".join(f"{n}={scores[n]:g} ({', '.join(ev[n][:4])})" for n in chosen)
        return chosen, conf, evidence


def first_sentence(text: str) -> str:
    t = md.collapse(text.replace("**", ""))
    m = re.match(r"^(.+?[.!?])(?:\s|$)", t)
    return (m.group(1) if m else t).strip()


def clip(s: str, n: int = config.RULE_MAX_CHARS) -> tuple[str, bool]:
    if len(s) <= n:
        return s, False
    cut = s[: n - 1].rsplit(" ", 1)[0]
    return cut + "…", True


def candidate_rule(c: Corpus, adr_id: str) -> tuple[str, str]:
    n = md.num(adr_id)
    bullets = c.b04_for(adr_id)
    own = [b for b in bullets if md.leading_ids(b.lead or "") and n in md.leading_ids(b.lead or "")]
    src = (own or bullets or [None])[0]
    if src is not None:
        t = md.collapse(src.text.replace("**", ""))
        t = re.sub(r"^[-*+]\s*", "", t)
        t = re.sub(r"^ADR-\d{3}(?:/\d{3})*(?:\s*\(\+?\s*ADR-\d{3}\))?\s*", "", t)
        t = re.sub(r"^\([^)]*\)\s*", "", t)
        t = t.lstrip("—:-– ").strip()
        return first_sentence(t), "bible/04 first sentence"
    a = c.primary_anchor(adr_id)
    if a:
        m = re.search(r"\*\*Decision[.:]?\*\*[:.]?\s*(.+)", a.text, re.S)
        if m:
            return first_sentence(m.group(1)), "decision-log Decision"
        body = a.text.split("\n", 1)[1] if "\n" in a.text else a.text
        return first_sentence(body), "decision-log first sentence"
    return "", "no text"


def adr_edges(c: Corpus) -> tuple[dict[str, set], dict[str, str], dict[str, list[str]]]:
    amends: dict[str, set] = defaultdict(set)
    superseded: dict[str, str] = {}
    ev: dict[str, list[str]] = defaultdict(list)
    known = set(c.adr_ids)
    for i in c.adr_ids:
        n = md.num(i)
        texts = [a.text for a in c.anchors_for(i) if a.kind == "primary"]
        texts += [b.text for b in c.b04_for(i) if n in md.leading_ids(b.lead or "")]
        for t in texts:
            for m in REL_RE.finditer(t):
                verb = m.group(1).lower()
                others = [md.fmt_adr(x) for x in md.expand_ids(m.group(2))]
                for o in others:
                    if o == i or o not in known:
                        continue
                    if verb in ("amends", "refines", "revises"):
                        amends[i].add(o)
                        ev[i].append(f"{verb} {o}")
                    elif verb in ("amended by", "refined by", "revised by"):
                        amends[o].add(i)
                        ev[i].append(f"{verb} {o}")
                    elif verb == "supersedes":
                        superseded[o] = i
                        ev[i].append(f"supersedes {o}")
                    elif verb == "superseded by":
                        superseded[i] = o
                        ev[i].append(f"superseded by {o}")
    return amends, superseded, ev


PROPOSED_HEADER = """# {name}.proposed.toml — written by `genesis-ctx propose-tags` (47-04 step 5), reviewed in 47-05.
# Candidate tags only: every value is a proposal. `confidence` (high | medium | low) and `evidence`
# are review aids and must be removed when an entry is accepted into {name}.toml.
# reviewed_fp is the current fingerprint — accepting an entry means its `rule` has been reviewed.
"""


def cmd_propose_tags(ctx: Ctx, out_dir: str | None = None) -> int:
    c = Corpus(ctx)
    sc = Scorer(c)
    out = Path(out_dir) if out_dir else ctx.tags_dir
    if not out_dir and not ctx.inside_tracker(out):
        raise CtxError("propose-tags writes only inside project-tracker/genesis/")
    out.mkdir(parents=True, exist_ok=True)
    stats: dict[str, dict[str, int]] = {}

    amends, superseded, edge_ev = adr_edges(c)
    adr: dict[str, dict] = {}
    for i in c.adr_ids:
        text = c.adr_full_text(i)
        areas, conf, ev = sc.score(text)
        rule, rule_src = candidate_rule(c, i)
        rule, clipped = clip(rule)
        sm = STATUS_RE.search(text) or re.search(r"\((ACCEPTED|PROPOSED|SUPERSEDED)", text)
        status = sm.group(1).lower() if sm else "accepted"
        if i in superseded:
            status = "superseded"
        if clipped or not rule:
            conf = "low"
        adr[i] = {
            "title": c.adr_title(i), "status": status, "areas": areas, "paths": [],
            "amends": sorted(amends.get(i, set())),
            "amended_by": sorted(k for k, v in amends.items() if i in v),
            "superseded_by": superseded.get(i, ""), "rule": rule,
            "reviewed_fp": c.adr_fp(i), "confidence": conf,
            "evidence": f"areas: {ev} | rule: {rule_src}{' (clipped)' if clipped else ''}"
                        + (f" | edges: {', '.join(edge_ev[i])}" if edge_ev.get(i) else ""),
        }
    stats["adr"] = _count(adr)
    (out / "adr.proposed.toml").write_text(PROPOSED_HEADER.format(name="adr") + "\n" + tomlio.dumps(adr),
                                           encoding="utf-8")

    lesson: dict[str, dict] = {}
    unmarked = sum(1 for l in c.lessons if not l.marker)
    for l in c.lessons:
        if not l.marker:
            continue
        areas, conf, ev = sc.score(l.text)
        ph = re.search(r"Phase\s+(\d+)", l.text)
        lead = l.lead or ""
        if len(lead) > config.RULE_MAX_CHARS:
            conf, ev = "low", ev + " | bold lead > 220 chars: write a `rule`"
        lesson[l.marker] = {"areas": areas, "phase": ph.group(1) if ph else "", "rule": "",
                            "reviewed_fp": md.fingerprint(l.text), "confidence": conf, "evidence": ev}
    stats["lesson"] = _count(lesson)
    (out / "lesson.proposed.toml").write_text(PROPOSED_HEADER.format(name="lesson") + "\n" + tomlio.dumps(lesson),
                                              encoding="utf-8")

    codemap: dict[str, dict] = {}
    for s in c.sections:
        paths = section_paths(s)
        areas, conf, ev = sc.score(s.key if s.kind == "base" else s.text.split("\n")[0], paths)
        codemap[s.key] = {"areas": areas, "confidence": conf, "evidence": ev}
    stats["codemap"] = _count(codemap)
    (out / "codemap.proposed.toml").write_text(PROPOSED_HEADER.format(name="codemap") + "\n" + tomlio.dumps(codemap),
                                               encoding="utf-8")

    print(f"propose-tags → {out}\n")
    print("| file | entries | high | medium | low | no areas |\n|---|---:|---:|---:|---:|---:|")
    for k, v in stats.items():
        print(f"| {k}.proposed.toml | {v['n']} | {v['high']} | {v['medium']} | {v['low']} | {v['empty']} |")
    if unmarked:
        print(f"\n⚠ {unmarked} lesson(s) carry no marker — run `genesis-ctx mark` first; they were skipped.")
    return 0


def section_paths(s) -> list[str]:
    if s.kind == "base":
        tok = s.key.split("  ", 1)[1].rstrip(",);")
        return [s.repo + tok] if tok and tok[0].isalnum() else []
    out, repo = [], None
    for line in s.text.split("\n")[1:]:
        if re.match(r"^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*/\s*$", line):
            repo = line.strip()
            continue
        m = re.match(r"^  (?! )([A-Za-z0-9_.][^\s,;]*)", line)
        if m and repo and "{" not in m.group(1):
            out.append(repo + m.group(1).rstrip(",);:"))
    return out


def _count(d: dict) -> dict[str, int]:
    out = {"n": len(d), "high": 0, "medium": 0, "low": 0, "empty": 0}
    for v in d.values():
        out[v["confidence"]] += 1
        out["empty"] += 0 if v["areas"] else 1
    return out
