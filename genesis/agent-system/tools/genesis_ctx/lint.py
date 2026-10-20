"""lint (47-03 §5). Errors fail (exit 1); warnings are printed only."""
from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass

from . import config, globs, md
from .config import Ctx, read, tokens
from .index import stale_generated
from .model import AREA_KEYS, AREA_NAME, Corpus, find_spec, resolve_doc, spec_files, spec_phase
from .sources import parse_manifest

ADR_STATUSES = {"proposed", "accepted", "superseded", "amended"}
ADR_FIELDS = {"title", "status", "areas", "paths", "amends", "amended_by", "superseded_by", "rule", "reviewed_fp"}
LESSON_FIELDS = {"areas", "phase", "rule", "reviewed_fp"}
CODEMAP_FIELDS = {"areas"}


@dataclass
class Finding:
    code: str
    msg: str
    where: str = ""
    level: str = "error"

    def as_dict(self) -> dict:
        return {"code": self.code, "level": self.level, "message": self.msg, "where": self.where}


class Lint:
    def __init__(self, ctx: Ctx):
        self.ctx, self.c = ctx, Corpus(ctx)
        self.out: list[Finding] = []

    def err(self, code, msg, where=""):
        self.out.append(Finding(code, msg, where))

    def warn(self, code, msg, where=""):
        self.out.append(Finding(code, msg, where, "warning"))

    # ── areas ──
    def areas(self):
        for name, a in sorted(self.c.areas.items()):
            w = f"context/areas.toml [area.{name}]"
            if not AREA_NAME.match(name):
                self.err("area-invalid", f"area name `{name}` must match [a-z0-9-]+", w)
            if not isinstance(a, dict):
                self.err("area-invalid", f"area `{name}` is not a table", w)
                continue
            for k in sorted(set(a) - AREA_KEYS):
                self.err("area-invalid", f"area `{name}`: unknown key `{k}`", w)
            if not a.get("title"):
                self.err("area-invalid", f"area `{name}` has no title", w)
            if a.get("always") is not True and not a.get("paths"):
                self.err("area-invalid", f"area `{name}` has no paths (and is not always = true)", w)
            for k in ("paths", "keywords", "skills", "docs", "gates"):
                v = a.get(k, [])
                if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
                    self.err("area-invalid", f"area `{name}`: `{k}` must be an array of strings", w)
            for g in a.get("paths", []) or []:
                if isinstance(g, str) and not self.c.expand(g):
                    self.warn("area-glob-empty", f"area `{name}`: glob `{g}` matches no file", w)

    def _areas_known(self, names, where, owner):
        if not isinstance(names, list):
            self.err("tag-invalid", f"{owner}: `areas` must be an array", where)
            return
        for a in names:
            if a not in self.c.areas:
                self.err("unknown-area", f"{owner}: unknown area `{a}`", where)

    # ── ADRs ──
    def adrs(self):
        c = self.c
        prim = Counter(md.fmt_adr(i) for a in c.anchors if a.kind == "primary" for i in a.ids)
        for i, n in sorted(prim.items()):
            if n > 1:
                lines = [a.lineno for a in c.anchors_for(i) if a.kind == "primary"]
                self.err("adr-duplicate-anchor", f"{i} has {n} primary anchors (lines {lines})", "decision-log.md")
        for i in c.primary_ids:
            if i not in c.adr_tags:
                self.err("adr-untagged", f"{i} has no tags/adr.toml entry", "decision-log.md")
        for i in c.adr_ids:
            if c.b04_for(i) and not c.anchors_for(i):
                self.warn("adr-no-decision-log", f"{i} has bible/04 bullets but no decision-log anchor", "bible/04")
        for i, t in sorted(c.adr_tags.items()):
            w = f"tags/adr.toml [{i}]"
            if not md.ADR_ID_RE.match(i):
                self.err("tag-invalid", f"`{i}` is not an ADR id (ADR-NNN)", w)
                continue
            if not isinstance(t, dict):
                self.err("tag-invalid", f"{i} is not a table", w)
                continue
            if not c.adr_known(i):
                self.err("adr-unknown", f"{i} has neither a decision-log anchor nor a bible/04 bullet", w)
            for k in sorted(set(t) - ADR_FIELDS):
                self.err("tag-invalid", f"{i}: unknown field `{k}`", w)
            if not t.get("areas") or not (t.get("rule") or "").strip():
                self.err("adr-tag-incomplete", f"{i} needs non-empty `areas` and `rule`", w)
            self._areas_known(t.get("areas", []), w, i)
            if len(t.get("rule", "") or "") > config.RULE_MAX_CHARS:
                self.err("rule-too-long", f"{i}: rule is {len(t['rule'])} chars (max {config.RULE_MAX_CHARS})", w)
            st = t.get("status", "accepted")
            if st not in ADR_STATUSES:
                self.err("tag-invalid", f"{i}: status `{st}` not in {sorted(ADR_STATUSES)}", w)
            if st == "superseded" and not t.get("superseded_by"):
                self.err("superseded-missing", f"{i} is superseded but has no superseded_by", w)
            for rel in list(t.get("amends", []) or []) + list(t.get("amended_by", []) or []) + \
                    ([t["superseded_by"]] if t.get("superseded_by") else []):
                if rel not in c.adr_tags and not c.adr_known(rel):
                    self.err("adr-unknown", f"{i} references unknown {rel}", w)
            for other in t.get("amends", []) or []:
                if i not in (c.adr_tags.get(other, {}).get("amended_by", []) or []):
                    self.err("amends-asymmetric", f"{i} amends {other}, but {other}.amended_by lacks {i}", w)
            for other in t.get("amended_by", []) or []:
                if i not in (c.adr_tags.get(other, {}).get("amends", []) or []):
                    self.err("amends-asymmetric", f"{i}.amended_by has {other}, but {other}.amends lacks {i}", w)
            self._fp(i, t, c.adr_fp(i) if c.adr_known(i) else None, w)

    def _fp(self, i, t, cur, where):
        if cur is None:
            return
        old = (t.get("reviewed_fp") or "").strip()
        if not old:
            self.err("fp-missing", f"{i}: reviewed_fp is empty (run `genesis-ctx index`)", where)
        elif old != cur:
            self.err("fp-drift", f"{i}: text changed since its rule was reviewed — review the rule, then "
                     f"`genesis-ctx index --reviewed {i}`", where)

    # ── lessons ──
    def lessons(self):
        c = self.c
        markers = Counter(l.marker for l in c.lessons if l.marker)
        for n, l in enumerate(c.lessons, 1):
            if not l.marker:
                self.err("lesson-unmarked", f"lesson #{n} at bible/06 L{l.lineno} has no <!-- L-NNN --> marker",
                         "bible/06")
            elif l.marker not in c.lesson_tags:
                self.err("lesson-untagged", f"{l.marker} has no tags/lesson.toml entry", f"bible/06 L{l.lineno}")
        for m, n in sorted(markers.items()):
            if n > 1:
                self.err("lesson-duplicate-marker", f"{m} appears on {n} lessons", "bible/06")
        for i, t in sorted(c.lesson_tags.items()):
            w = f"tags/lesson.toml [{i}]"
            if not md.LESSON_ID_RE.match(i) or not isinstance(t, dict):
                self.err("tag-invalid", f"`{i}` is not a lesson id (L-NNN) table", w)
                continue
            if i not in markers:
                self.err("lesson-unknown", f"{i} has a tag entry but no marker in bible/06 §7", w)
            for k in sorted(set(t) - LESSON_FIELDS):
                self.err("tag-invalid", f"{i}: unknown field `{k}`", w)
            if not t.get("areas"):
                self.err("lesson-tag-incomplete", f"{i} needs non-empty `areas`", w)
            self._areas_known(t.get("areas", []), w, i)
            if len(t.get("rule", "") or "") > config.RULE_MAX_CHARS:
                self.err("rule-too-long", f"{i}: rule is {len(t['rule'])} chars (max {config.RULE_MAX_CHARS})", w)
            self._fp(i, t, c.lesson_fp(i) if i in markers else None, w)

    # ── code map ──
    def codemap(self):
        c = self.c
        keys = {s.key for s in c.sections}
        for s in c.sections:
            if s.key not in c.codemap_tags:
                self.err("codemap-untagged", f"section `{s.key}` has no tags/codemap.toml entry",
                         f"bible/03 L{s.lineno}")
        for k, t in sorted(c.codemap_tags.items()):
            w = f"tags/codemap.toml [{k!r}]"
            if k not in keys:
                self.err("codemap-unknown", f"entry `{k}` matches no bible/03 section", w)
            if not isinstance(t, dict) or not t.get("areas"):
                self.err("codemap-tag-incomplete", f"entry `{k}` needs non-empty `areas`", w)
                continue
            for f in sorted(set(t) - CODEMAP_FIELDS):
                self.err("tag-invalid", f"`{k}`: unknown field `{f}`", w)
            self._areas_known(t.get("areas", []), w, k)

    # ── generated, budgets, links ──
    def generated(self):
        for name in stale_generated(self.ctx, self.c):
            self.err("generated-stale", f"context/_generated/{name} is out of date — run `genesis-ctx index`")

    def budgets(self):
        total = 0
        for rel in config.L0_FILES:
            p = self.ctx.t(rel)
            if not p.is_file():
                self.warn("l0-missing", f"L0 file missing: {rel}")
            total += tokens(read(p))
        if total > config.L0_BUDGET:
            self.err("l0-budget", f"L0 is ~{total:,} tokens (budget {config.L0_BUDGET:,})")
        st = tokens(read(self.ctx.state_file))
        if st > config.STATE_BUDGET:
            self.err("state-budget", f"state/current.md is ~{st:,} tokens (budget {config.STATE_BUDGET:,})")
        self.l0_tokens = total

    def links(self):
        files = [self.ctx.t("AGENT_ONBOARDING.md")]
        for d in ("context", "agent-system"):
            base = self.ctx.t(d)
            if base.is_dir():
                files += sorted(p for p in base.rglob("*.md") if ".packs" not in p.parts)
        for f in files:
            if not f.is_file():
                continue
            for target in md.LINK_RE.findall(md.strip_code(read(f))):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#") or "{{" in target:
                    continue
                path = target.split("#")[0]
                if not path:
                    continue
                if not (f.parent / path).exists():
                    self.err("broken-link", f"link to `{target}` does not resolve", self.ctx.rel(f))

    # ── specs ──
    def specs(self):
        c = self.c
        for p in spec_files(self.ctx):
            ph = spec_phase(p)
            if ph is None or ph < 48:
                continue
            w = self.ctx.rel(p)
            m = parse_manifest(read(p))
            if not m.present:
                self.err("manifest-missing", "no `## Context manifest` (required from phase 48 on)", w)
                continue
            if m.error:
                self.err("manifest-invalid", m.error, w)
                continue
            d = m.data
            for a in d.get("areas", []):
                if a not in c.areas:
                    self.err("manifest-unknown-ref", f"unknown area `{a}`", w)
            for raw in d.get("adrs", []):
                i = md.parse_adr_id(raw)
                if not i or not (c.adr_known(i) or i in c.adr_tags):
                    self.err("manifest-unknown-ref", f"unknown ADR `{raw}`", w)
            for raw in d.get("lessons", []):
                i = md.parse_lesson_id(raw)
                if not i or not c.lesson(i):
                    self.err("manifest-unknown-ref", f"unknown lesson `{raw}`", w)
            for up in d.get("upstream", []):
                try:
                    find_spec(self.ctx, up)
                except config.CtxError:
                    self.err("manifest-unknown-ref", f"unknown upstream sub-spec `{up}`", w)
            for doc in d.get("docs", []):
                if not resolve_doc(self.ctx, doc).exists() and not globs.WILD.search(doc):
                    self.warn("manifest-missing-doc", f"doc `{doc}` does not exist (yet)", w)

    def run(self, specs_only: bool = False) -> list[Finding]:
        if not specs_only:
            self.areas()
            self.adrs()
            self.lessons()
            self.codemap()
            self.generated()
            self.budgets()
            self.links()
        self.specs()
        return self.out


def cmd_lint(ctx: Ctx, quiet: bool = False, specs_only: bool = False, as_json: bool = False,
             max_per_code: int = 10) -> int:
    lint = Lint(ctx)
    found = lint.run(specs_only)
    errors = [f for f in found if f.level == "error"]
    warnings = [f for f in found if f.level == "warning"]
    if as_json:
        print(json.dumps({"errors": len(errors), "warnings": len(warnings),
                          "l0_tokens": getattr(lint, "l0_tokens", None),
                          "findings": [f.as_dict() for f in found]}, indent=2))
        return 1 if errors else 0
    if quiet:
        if errors:
            by = Counter(f.code for f in errors)
            print(f"lint: {len(errors)} errors — " + ", ".join(f"{k} {v}" for k, v in sorted(by.items())))
        return 1 if errors else 0
    l0 = getattr(lint, "l0_tokens", None)
    print(f"# genesis-ctx lint — {len(errors)} errors, {len(warnings)} warnings"
          + (f" · L0 ~{l0:,} / {config.L0_BUDGET:,} tokens" if l0 is not None else ""))
    for title, group in (("Errors", errors), ("Warnings", warnings)):
        if not group:
            continue
        print(f"\n## {title}")
        by: dict[str, list[Finding]] = defaultdict(list)
        for f in group:
            by[f.code].append(f)
        for code in sorted(by):
            items = by[code]
            print(f"\n### {code} ({len(items)})")
            for f in items[:max_per_code]:
                print(f"- {f.msg}" + (f"  _({f.where})_" if f.where else ""))
            if len(items) > max_per_code:
                print(f"- … and {len(items) - max_per_code} more (`--json` for all)")
    if not errors:
        print("\nlint: OK")
    return 1 if errors else 0
