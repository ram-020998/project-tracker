"""add adr | add lesson (47-03 §3, used by genesis-docs in 47-08). Scaffold source text + a tag entry, then index."""
from __future__ import annotations

import datetime as _dt
from pathlib import Path

from . import config, md, tomlio
from .config import CtxError, Ctx, read
from .index import cmd_index
from .model import Corpus
from .sources import lesson_range


def _areas(c: Corpus, csv: str) -> list[str]:
    areas = [a.strip() for a in csv.split(",") if a.strip()]
    if not areas:
        raise CtxError("--areas needs at least one area")
    unknown = [a for a in areas if a not in c.areas]
    if unknown:
        raise CtxError("unknown area(s): " + ", ".join(unknown))
    return areas


def _rule(rule: str) -> str:
    rule = md.collapse(rule)
    if not rule:
        raise CtxError("--rule must not be empty")
    if len(rule) > config.RULE_MAX_CHARS:
        raise CtxError(f"--rule is {len(rule)} chars (max {config.RULE_MAX_CHARS})")
    return rule


def _append(path: Path, block: str) -> None:
    text = read(path)
    sep = "" if not text or text.endswith("\n\n") else ("\n" if text.endswith("\n") else "\n\n")
    path.write_text(text + sep + block, encoding="utf-8")


def _with_phase(text: str, phase: str) -> str:
    """House format: '<text> (Phase NN)' — appended once; a text that already names its phase is left alone."""
    phase = phase.strip()
    if not phase or "(Phase " in text:
        return text
    return f"{text} (Phase {phase})"


def cmd_add_adr(ctx: Ctx, adr_id: str, title: str, areas_csv: str, rule: str, body_file: str | None,
                amends: list[str] | None, status: str = "proposed", phase: str = "") -> int:
    c = Corpus(ctx)
    i = md.parse_adr_id(adr_id)
    if not i:
        raise CtxError(f"not an ADR id: {adr_id}")
    if c.adr_known(i) or i in c.adr_tags:
        raise CtxError(f"{i} already exists")
    areas, rule = _areas(c, areas_csv), _rule(rule)
    amended = []
    for a in amends or []:
        o = md.parse_adr_id(a)
        if not o or o not in c.adr_tags:
            raise CtxError(f"--amends {a}: no tag entry for that ADR")
        amended.append(o)
    title = _with_phase(md.collapse(title), phase)
    date = _dt.date.today().isoformat()
    # 47-08 §5: `## ADR-0NN — <title> (Phase NN) — **Accepted**` + Status, Context, Decision, Alternatives rejected,
    # Consequences (the house order); an amending ADR says "Amends ADR-0NN: …" (47-08 §2).
    lines = [f"## {i} — {title} — **{status.capitalize()}**", "",
             f"- **Status:** **{status.capitalize()}** — {date}."]
    if body_file:
        body = Path(body_file).read_text(encoding="utf-8").rstrip("\n")
        lines += [body]
        for o in amended:
            if f"Amends {o}" not in body:
                print(f"add adr: warning — the body does not say 'Amends {o}: …'; add it to Consequences (47-08 §2)")
    else:
        lines += ["- **Context.** _(to write)_", f"- **Decision.** {rule}", "- **Alternatives rejected.** _(to write)_",
                  "- **Consequences.** " + " ".join([f"Amends {o}: _(what changes and why)_." for o in amended]
                                                     + ["_(to write)_"])]
    _append(ctx.decision_log, "\n".join(lines) + "\n")
    c = Corpus(ctx)
    tag = {i: {"title": title, "status": status, "areas": areas, "paths": [], "amends": amended,
               "amended_by": [], "superseded_by": "", "rule": rule, "reviewed_fp": c.adr_fp(i)}}
    _append(ctx.tags_dir / "adr.toml", tomlio.dumps(tag))
    text = read(ctx.tags_dir / "adr.toml")
    for o in amended:
        cur = list(c.adr_tags.get(o, {}).get("amended_by", []) or [])
        if i not in cur:
            text = tomlio.set_field(text, o, "amended_by", sorted(cur + [i]))
    (ctx.tags_dir / "adr.toml").write_text(text, encoding="utf-8")
    print(f"add adr: {i} appended to reference/decision-log.md and tags/adr.toml"
          + (f"; amended_by updated on {', '.join(amended)}" if amended else ""))
    return cmd_index(ctx)


def cmd_add_lesson(ctx: Ctx, areas_csv: str, rule: str, body_file: str | None, phase: str = "") -> int:
    c = Corpus(ctx)
    areas, rule = _areas(c, areas_csv), _rule(rule)
    lines = c.bible06_text.split("\n")
    rng = lesson_range(lines)
    if not rng:
        raise CtxError("bible/06 has no `## 7.` section")
    used = {md.num(l.marker) for l in c.lessons if l.marker} | \
           {md.num(k) for k in c.lesson_tags if md.LESSON_ID_RE.match(k)}
    if c.lessons and any(not l.marker for l in c.lessons):
        raise CtxError("bible/06 has unmarked lessons — run `genesis-ctx mark` first")
    lid = md.fmt_lesson(max(used, default=0) + 1)
    # 47-08 §5: `- <!-- L-0NN --> **<rule sentence> (Phase NN).** <body>` — the bold lead is the digest one-liner.
    lead = _with_phase(rule.rstrip(". "), phase) + "."
    if len(lead) > config.RULE_MAX_CHARS:
        raise CtxError(f"the lesson's bold lead is {len(lead)} chars with its phase (max {config.RULE_MAX_CHARS})")
    body = Path(body_file).read_text(encoding="utf-8").strip().split("\n") if body_file else []
    bullet = [f"- <!-- {lid} --> **{lead}**" + (f" {body[0].strip()}" if body else "")]
    bullet += ["   " + b.strip() if b.strip() else "" for b in body[1:]]
    end = rng[1]
    while end > rng[0] + 1 and lines[end - 1].strip() == "":
        end -= 1
    lines[end:end] = bullet
    ctx.bible06.write_text("\n".join(lines), encoding="utf-8")
    c = Corpus(ctx)
    tag = {lid: {"areas": areas, "phase": phase, "rule": "", "reviewed_fp": c.lesson_fp(lid)}}
    _append(ctx.tags_dir / "lesson.toml", tomlio.dumps(tag))
    print(f"add lesson: {lid} appended to bible/06 §7 and tags/lesson.toml")
    return cmd_index(ctx)
