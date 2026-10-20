"""The Corpus: every source document, the area registry and the tag files, parsed once per run."""
from __future__ import annotations

import re
from collections import defaultdict
from functools import cached_property
from pathlib import Path

from . import globs, md, sources, tomlio
from .config import CtxError, Ctx, read

AREA_KEYS = {"title", "paths", "keywords", "skills", "docs", "gates", "always"}
AREA_NAME = re.compile(r"^[a-z0-9-]+$")


class Corpus:
    def __init__(self, ctx: Ctx):
        self.ctx = ctx
        self._expand_cache: dict[str, list[str]] = {}

    # ── raw texts ──
    @cached_property
    def decision_log_text(self) -> str:
        return read(self.ctx.decision_log)

    @cached_property
    def bible04_text(self) -> str:
        return read(self.ctx.bible04)

    @cached_property
    def bible06_text(self) -> str:
        return read(self.ctx.bible06)

    @cached_property
    def bible03_text(self) -> str:
        return read(self.ctx.bible03)

    # ── parsed sources ──
    @cached_property
    def anchors(self) -> list[sources.Anchor]:
        return sources.parse_decision_log(self.decision_log_text)

    @cached_property
    def b04(self) -> list[sources.Bullet]:
        return sources.parse_bible04(self.bible04_text)

    @cached_property
    def lessons(self) -> list[sources.Lesson]:
        return sources.parse_lessons(self.bible06_text)

    @cached_property
    def sections(self) -> list[sources.Section]:
        return sources.parse_codemap(self.bible03_text)

    # ── registry + tags ──
    @cached_property
    def areas(self) -> dict[str, dict]:
        data = tomlio.load(self.ctx.areas_file).get("area", {})
        if not isinstance(data, dict):
            raise CtxError("areas.toml: `area` must be a table of tables")
        return data

    @cached_property
    def adr_tags(self) -> dict[str, dict]:
        return tomlio.load(self.ctx.tags_dir / "adr.toml")

    @cached_property
    def lesson_tags(self) -> dict[str, dict]:
        return tomlio.load(self.ctx.tags_dir / "lesson.toml")

    @cached_property
    def codemap_tags(self) -> dict[str, dict]:
        return tomlio.load(self.ctx.tags_dir / "codemap.toml")

    def always_areas(self) -> list[str]:
        return sorted(n for n, a in self.areas.items() if a.get("always") is True)

    # ── ADRs ──
    def anchors_for(self, adr_id: str) -> list[sources.Anchor]:
        n = md.num(adr_id)
        return [a for a in self.anchors if n in a.ids]

    def primary_anchor(self, adr_id: str) -> sources.Anchor | None:
        return next((a for a in self.anchors_for(adr_id) if a.kind == "primary"), None)

    def b04_for(self, adr_id: str) -> list[sources.Bullet]:
        n = md.num(adr_id)
        return [b for b in self.b04 if n in b.ids]

    @cached_property
    def primary_ids(self) -> list[str]:
        return sorted({md.fmt_adr(i) for a in self.anchors if a.kind == "primary" for i in a.ids})

    @cached_property
    def adr_ids(self) -> list[str]:
        ids = {md.fmt_adr(i) for a in self.anchors if a.kind != "boundary" for i in a.ids}
        ids |= {md.fmt_adr(i) for b in self.b04 for i in b.ids}
        ids |= {k for k in self.adr_tags if md.ADR_ID_RE.match(k)}
        return sorted(ids)

    def adr_known(self, adr_id: str) -> bool:
        return bool(self.anchors_for(adr_id) or self.b04_for(adr_id))

    def adr_full_text(self, adr_id: str) -> str:
        parts = [a.text for a in self.anchors_for(adr_id)] + [b.text for b in self.b04_for(adr_id)]
        return "\n\n".join(parts)

    def adr_fp(self, adr_id: str) -> str:
        return md.fingerprint(self.adr_full_text(adr_id))

    def adr_title(self, adr_id: str) -> str:
        tag = self.adr_tags.get(adr_id, {})
        if tag.get("title"):
            return tag["title"]
        a = self.primary_anchor(adr_id)
        if a and a.form == "bullet":
            head = md.collapse(a.text[2:].replace("**", ""))     # the whole bullet: its lead wraps lines
        elif a:
            head = md.collapse(a.head.replace("**", ""))
        else:
            b = self.b04_for(adr_id)
            head = md.collapse((b[0].lead or "") if b else "")
        head = re.sub(r"^ADR-\d{3}(?:/\d{3})*\s*", "", head.replace("**", ""))
        head = re.sub(r"^\([^()]*\)\s*", "", head)                       # (Q1) / (2026-07-11) / (ACCEPTED — …)
        head = re.sub(r"\s+—\s+(Accepted|Proposed|Superseded|Amended)\b.*$", "", head, flags=re.I)
        head = head.lstrip("—:- ").strip()
        if a and a.form == "bullet":
            head = re.split(r"(?<=\w)[:.]\s", head, maxsplit=1)[0]
        return head[:140] + ("…" if len(head) > 140 else "")

    def adr_rule(self, adr_id: str) -> str:
        return (self.adr_tags.get(adr_id, {}).get("rule") or "").strip()

    def chain(self, ids, enabled: bool = True) -> dict[str, str]:
        """Amendment closure (amends ∪ amended_by ∪ superseded_by, both directions).

        Returns id -> reason ("" for the seeds, "chain via ADR-NNN" for the rest).
        """
        out = {i: "" for i in ids}
        if not enabled:
            return out
        reverse: dict[str, set[str]] = defaultdict(set)
        for k, t in self.adr_tags.items():
            for rel in self._edges(t):
                reverse[rel].add(k)
        queue = list(ids)
        while queue:
            cur = queue.pop(0)
            nxt = set(self._edges(self.adr_tags.get(cur, {}))) | reverse.get(cur, set())
            for n in sorted(nxt):
                if n not in out:
                    out[n] = f"chain via {cur}"
                    queue.append(n)
        return out

    def pack_chain(self, seeds) -> dict[str, str]:
        """Closure used by `pack` and `check` (47-03 §4, 47-01 §5 round 5).

        From the seeds, follow `amended_by` and `superseded_by` TRANSITIVELY (everything that changes a
        loaded rule), and `amends` ONE hop from the seeds only (never from chain-added ADRs).
        Returns id -> reason ("" for the seeds).
        """
        out = {i: "" for i in seeds}
        reverse_amends: dict[str, set[str]] = defaultdict(set)     # X -> ADRs that list X in `amends`
        reverse_super: dict[str, set[str]] = defaultdict(set)      # X -> ADRs that X supersedes
        for k, t in self.adr_tags.items():
            for a in t.get("amends", []) or []:
                reverse_amends[a].add(k)
            if t.get("superseded_by"):
                reverse_super[k].add(t["superseded_by"])

        def changers(i: str) -> set[str]:
            t = self.adr_tags.get(i, {})
            got = {x for x in (t.get("amended_by", []) or []) if isinstance(x, str)}
            return got | reverse_amends.get(i, set()) | reverse_super.get(i, set())

        for s in list(seeds):
            for a in sorted(self.adr_tags.get(s, {}).get("amends", []) or []):
                if a not in out:
                    out[a] = f"chain via {s}"
        queue = list(out)
        while queue:
            cur = queue.pop(0)
            for n in sorted(changers(cur)):
                if n not in out:
                    out[n] = f"chain via {cur}"
                    queue.append(n)
        return out

    @staticmethod
    def _edges(tag: dict) -> list[str]:
        edges = list(tag.get("amends", []) or []) + list(tag.get("amended_by", []) or [])
        if tag.get("superseded_by"):
            edges.append(tag["superseded_by"])
        return [e for e in edges if isinstance(e, str)]

    # ── lessons ──
    def lesson(self, lesson_id: str) -> sources.Lesson | None:
        return next((l for l in self.lessons if l.marker == lesson_id), None)

    def lesson_fp(self, lesson_id: str) -> str:
        l = self.lesson(lesson_id)
        return md.fingerprint(l.text) if l else ""

    def lesson_rule(self, lesson_id: str) -> str:
        rule = (self.lesson_tags.get(lesson_id, {}).get("rule") or "").strip()
        if rule:
            return rule
        l = self.lesson(lesson_id)
        return (l.lead or "").strip() if l else ""

    # ── code map ──
    def section(self, key: str) -> sources.Section | None:
        return next((s for s in self.sections if s.key == key), None)

    # ── areas ↔ paths ──
    def area_globs(self, name: str) -> list[str]:
        return list(self.areas.get(name, {}).get("paths", []) or [])

    def expand(self, pat: str) -> list[str]:
        if pat not in self._expand_cache:
            if pat.startswith("tracker:"):
                self._expand_cache[pat] = ["tracker:" + p for p in globs.expand(self.ctx.tracker, pat[8:])]
            else:
                self._expand_cache[pat] = globs.expand(self.ctx.repos, pat)
        return self._expand_cache[pat]

    def areas_for_path(self, path: str) -> list[str]:
        return sorted(n for n in self.areas if any(globs.match(g, path) for g in self.area_globs(n)))

    def areas_for_code(self, entry: str) -> list[str]:
        """Areas for a manifest `code` entry: the entry string itself, plus every file it expands to."""
        found = set(self.areas_for_path(entry))
        if globs.WILD.search(entry):
            for f in self.expand(entry):
                found.update(self.areas_for_path(f))
        return sorted(found)

    def globs_touch(self, pats: list[str], paths: list[str]) -> str | None:
        """First path (or expanded file) matched by any glob in pats, else None."""
        for p in paths:
            cands = [p] + (self.expand(p) if globs.WILD.search(p) else [])
            for c in cands:
                if any(globs.match(g, c) for g in pats):
                    return p
        return None

    # ── selection helpers shared by pack/check ──
    def adrs_for_areas(self, areas: set[str]) -> dict[str, str]:
        out = {}
        for k, t in sorted(self.adr_tags.items()):
            hit = sorted(set(t.get("areas", []) or []) & areas)
            if hit:
                out[k] = f"area {hit[0]}"
        return out

    def lessons_for_areas(self, areas: set[str]) -> dict[str, str]:
        out = {}
        for k, t in sorted(self.lesson_tags.items()):
            hit = sorted(set(t.get("areas", []) or []) & areas)
            if hit:
                out[k] = f"area {hit[0]}"
        return out

    def sections_for_areas(self, areas: set[str]) -> dict[str, str]:
        out = {}
        for s in self.sections:
            hit = sorted(set(self.codemap_tags.get(s.key, {}).get("areas", []) or []) & areas)
            if hit:
                out[s.key] = f"area {hit[0]}"
        return out

    def untagged_counts(self) -> dict[str, int]:
        return {
            "adrs": sum(1 for i in self.adr_ids if i not in self.adr_tags),
            "lessons": sum(1 for l in self.lessons if not l.marker or l.marker not in self.lesson_tags),
            "sections": sum(1 for s in self.sections if s.key not in self.codemap_tags),
        }


def untagged_note(c: Corpus) -> str | None:
    u = c.untagged_counts()
    if not any(u.values()):
        return None
    return (f"**Untagged:** {u['adrs']} ADRs, {u['lessons']} lessons, {u['sections']} code-map sections have no tag "
            "entry yet, so no area routes them here. Their one-line rules are still in the L0 digests "
            "(`genesis-ctx adr|lesson <id>` for the full text); tagging is 47-05.")


def resolve_doc(ctx: Ctx, ref: str) -> Path:
    return ctx.tracker / ref[8:] if ref.startswith("tracker:") else ctx.repos / ref


def spec_files(ctx: Ctx) -> list[Path]:
    """Umbrella specs (specs/phase-NN-*.md) and sub-specs (specs/phase-NN-*/NN-MM-*.md)."""
    out = []
    if not ctx.specs_dir.is_dir():
        return out
    for p in sorted(ctx.specs_dir.iterdir()):
        if p.is_file() and re.match(r"^phase-\d+-.*\.md$", p.name):
            out.append(p)
        elif p.is_dir() and re.match(r"^phase-\d+-", p.name):
            out += sorted(q for q in p.iterdir() if q.is_file() and re.match(r"^\d+-\d+.*\.md$", q.name))
    return out


def spec_phase(p: Path) -> int | None:
    m = re.match(r"^phase-(\d+)-", p.name) or re.match(r"^(\d+)-\d+", p.name)
    return int(m.group(1)) if m else None


def spec_id(p: Path) -> str:
    m = re.match(r"^(\d+-\d+)", p.name)
    if m:
        return m.group(1)
    m = re.match(r"^phase-(\d+)-", p.name)
    return f"phase-{m.group(1)}" if m else p.stem


def find_spec(ctx: Ctx, ref: str) -> Path:
    p = Path(ref)
    if p.suffix == ".md":
        for cand in (p, ctx.tracker / p, ctx.specs_dir / p):
            if cand.is_file():
                return cand.resolve()
        raise CtxError(f"spec file not found: {ref}")
    hits: list[Path] = []
    m = re.fullmatch(r"(\d+)-(\d+)", ref)
    if m:
        hits = sorted(ctx.specs_dir.glob(f"phase-{int(m.group(1))}-*/{ref}-*.md")) + \
            sorted(ctx.specs_dir.glob(f"phase-{int(m.group(1))}-*/{ref}.md"))
    m2 = re.fullmatch(r"(?:phase-)?(\d+)", ref)
    if m2:
        hits = sorted(q for q in ctx.specs_dir.glob(f"phase-{int(m2.group(1))}-*.md") if q.is_file())
    if not hits:
        raise CtxError(f"no spec matches `{ref}` under {ctx.rel(ctx.specs_dir)}/")
    if len(hits) > 1:
        raise CtxError(f"`{ref}` is ambiguous: " + ", ".join(ctx.rel(h) for h in hits))
    return hits[0].resolve()


def umbrella_for(ctx: Ctx, spec: Path) -> Path | None:
    parent = spec.parent
    if parent.resolve() == ctx.specs_dir.resolve():
        return None
    cand = parent.parent / (parent.name + ".md")
    return cand if cand.is_file() else None
