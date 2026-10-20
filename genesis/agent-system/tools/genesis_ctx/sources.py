"""Parsers for the source documents (anchor rules: 47-02 §4.1 / §4.2 / §4.3, locked 2026-10-20)."""
from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass, field

from . import md


# ───────────────────────────── decision-log.md ─────────────────────────────

HEAD_RE = re.compile(r"^(#{2,3})\s+(.*\S)\s*$")
BULLET_ADR_RE = re.compile(r"^- \*\*\s*(ADR-\d{3}.*)$")
AMENDS_RE = re.compile(r"\bamends\s+(.*)", re.I)
AMEND_WORD = re.compile(r"\b(amendment|addendum)\b", re.I)


@dataclass
class Anchor:
    start: int          # 0-based line of the heading / bullet
    end: int            # exclusive, trailing blank lines dropped
    form: str           # "heading" | "bullet"
    level: int          # 2 / 3 for headings, 0 for bullets
    head: str           # heading text or the bullet's first line after "- **"
    ids: list[int]
    kind: str           # "primary" | "amendment" | "boundary"
    text: str

    @property
    def lineno(self) -> int:
        return self.start + 1


def classify(head: str) -> tuple[list[int], str]:
    t = head.replace("**", "").strip()
    ids = md.leading_ids(t)
    if ids:
        lead = t.split(" — ")[0]
        return ids, ("amendment" if AMEND_WORD.search(lead) else "primary")
    m = AMENDS_RE.search(t)
    if m:
        ids = md.expand_ids(m.group(1).split(")")[0])
        if ids:
            return ids, "amendment"
    return [], "boundary"


def parse_decision_log(text: str) -> list[Anchor]:
    lines = text.split("\n")
    mask = md.fence_mask(lines)
    starts: list[tuple[int, str, int, str]] = []
    for i, line in enumerate(lines):
        if mask[i]:
            continue
        m = HEAD_RE.match(line)
        if m:
            starts.append((i, "heading", len(m.group(1)), m.group(2).strip()))
            continue
        m = BULLET_ADR_RE.match(line)
        if m:
            starts.append((i, "bullet", 0, m.group(1)))
    anchors: list[Anchor] = []
    for k, (i, form, level, head) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        while end > i + 1 and lines[end - 1].strip() == "":
            end -= 1
        ids, kind = classify(head)
        anchors.append(Anchor(i, end, form, level, head, ids, kind, "\n".join(lines[i:end])))
    return anchors


# ───────────────────────────── bible/04 ─────────────────────────────

@dataclass
class Bullet:
    start: int
    end: int
    lead: str | None
    ids: list[int]
    text: str

    @property
    def lineno(self) -> int:
        return self.start + 1


def parse_bullets(text: str) -> list[Bullet]:
    lines = text.split("\n")
    mask = md.fence_mask(lines)
    out = []
    for s, e in md.top_level_bullets(lines, mask=mask):
        body = "\n".join(lines[s:e])
        lead = md.bold_lead(body)
        out.append(Bullet(s, e, lead, md.expand_ids(lead) if lead else [], body))
    return out


def parse_bible04(text: str) -> list[Bullet]:
    """Column-0 bullets whose bold lead names at least one ADR id (id-list expansion)."""
    return [b for b in parse_bullets(text) if b.ids]


# ───────────────────────────── bible/06 ─────────────────────────────

@dataclass
class Lesson:
    start: int
    end: int
    marker: str | None
    lead: str | None
    text: str

    @property
    def lineno(self) -> int:
        return self.start + 1


LESSON_SECTION = r"^## 7\b"


def lesson_range(lines: list[str]) -> tuple[int, int] | None:
    return md.section_range(lines, LESSON_SECTION)


def parse_lessons(text: str) -> list[Lesson]:
    lines = text.split("\n")
    rng = lesson_range(lines)
    if not rng:
        return []
    mask = md.fence_mask(lines)
    out = []
    for s, e in md.top_level_bullets(lines, rng[0] + 1, rng[1], mask):
        body = "\n".join(lines[s:e])
        markers = md.MARKER_RE.findall(lines[s])
        m = md.LESSON_MARKER_AT_START.match(lines[s])
        out.append(Lesson(s, e, m.group(1) if m else (markers[0] if markers else None), md.bold_lead(body), body))
    return out


# ───────────────────────────── bible/03 ─────────────────────────────

SEC_B = re.compile(r"^# ──")
SEC_C = re.compile(r"^\*\*([^*].*?)\*\*\s*:?\s*$")
RULE_LINE = re.compile(r"^-{3,}\s*$")
REPO_HDR = re.compile(r"^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*/\s*$")
ENTRY = re.compile(r"^  (?! )(\S+)")


@dataclass
class Section:
    key: str
    kind: str           # "base" | "block" | "bold"
    start: int
    end: int
    text: str
    repo: str = ""      # base entries: the repo header line

    @property
    def lineno(self) -> int:
        return self.start + 1

    @property
    def display(self) -> str:
        return f"{self.repo}\n{self.text}" if self.kind == "base" else self.text


def _trim(lines: list[str], s: int, e: int) -> int:
    while e > s + 1 and lines[e - 1].strip() == "":
        e -= 1
    return e


def block_key(line: str) -> str:
    return re.sub(r"\s*─+\s*$", "", line[2:]).strip()


def bold_key(line: str) -> str | None:
    m = SEC_C.match(line)
    return m.group(1).strip().rstrip(":").strip() if m else None


def parse_codemap(text: str) -> list[Section]:
    lines = text.split("\n")
    raw: list[Section] = []
    open_i = next((i for i, l in enumerate(lines) if md.FENCE_RE.match(l)), None)
    scan_from = 0
    if open_i is not None:
        opener = md.FENCE_RE.match(lines[open_i]).group(1)
        close_i = next((j for j in range(open_i + 1, len(lines))
                        if lines[j].strip().startswith(opener[0] * len(opener))
                        and set(lines[j].strip()) == {opener[0]}), len(lines))
        first_b = next((j for j in range(open_i + 1, len(lines)) if SEC_B.match(lines[j])), len(lines))
        base_end = min(close_i, first_b)
        repo, cur = None, None
        for i in range(open_i + 1, base_end):
            line = lines[i]
            if REPO_HDR.match(line):
                if cur:
                    raw.append(_close(lines, cur, i))
                repo, cur = line.strip(), None
                continue
            m = ENTRY.match(line)
            if m and repo:
                if cur:
                    raw.append(_close(lines, cur, i))
                cur = (f"{repo}  {m.group(1)}", i, repo)
        if cur:
            raw.append(_close(lines, cur, base_end))
        scan_from = base_end
    starts = []
    for i in range(scan_from, len(lines)):
        if SEC_B.match(lines[i]):
            starts.append((i, "block", block_key(lines[i])))
        elif bold_key(lines[i]):
            starts.append((i, "bold", bold_key(lines[i])))
    for k, (i, kind, key) in enumerate(starts):
        nxt = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        end = next((j for j in range(i + 1, nxt) if RULE_LINE.match(lines[j])), nxt)
        end = _trim(lines, i, end)
        raw.append(Section(key, kind, i, end, "\n".join(lines[i:end])))
    seen: Counter = Counter()
    for s in raw:
        seen[s.key] += 1
        if seen[s.key] > 1:
            s.key = f"{s.key} #{seen[s.key]}"
    return raw


def _close(lines, cur, end) -> Section:
    key, s, repo = cur
    e = _trim(lines, s, end)
    return Section(key, "base", s, e, "\n".join(lines[s:e]), repo)


# ───────────────────────────── spec manifests ─────────────────────────────

MANIFEST_KEYS = ("areas", "adrs", "lessons", "code", "docs", "upstream")


@dataclass
class Manifest:
    data: dict = field(default_factory=dict)
    error: str | None = None
    present: bool = False


def parse_manifest(text: str) -> Manifest:
    import tomllib

    lines = text.split("\n")
    mask = md.fence_mask(lines)
    head = next((i for i, l in enumerate(lines) if not mask[i] and re.match(r"^## Context manifest\s*$", l)), None)
    if head is None:
        return Manifest(error="no `## Context manifest` section")
    end = next((j for j in range(head + 1, len(lines)) if not mask[j] and lines[j].startswith("## ")), len(lines))
    body_start = next((j for j in range(head + 1, end) if re.match(r"^```toml\s*$", lines[j])), None)
    if body_start is None:
        return Manifest(present=True, error="`## Context manifest` has no ```toml block")
    body_end = next((j for j in range(body_start + 1, end) if lines[j].strip() == "```"), None)
    if body_end is None:
        return Manifest(present=True, error="unclosed ```toml block in the manifest")
    try:
        data = tomllib.loads("\n".join(lines[body_start + 1:body_end]))
    except tomllib.TOMLDecodeError as e:
        return Manifest(present=True, error=f"invalid TOML in the manifest: {e}")
    for k, v in data.items():
        if k not in MANIFEST_KEYS:
            return Manifest(data, f"unknown manifest key `{k}`", True)
        if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
            return Manifest(data, f"manifest key `{k}` must be an array of strings", True)
    return Manifest(data, None, True)
