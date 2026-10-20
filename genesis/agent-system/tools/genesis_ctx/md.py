"""Markdown primitives: fences, top-level bullets, bold leads, ADR id lists, fingerprints."""
from __future__ import annotations

import hashlib
import re

FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
BULLET_START = re.compile(r"^[-*+] ")
MARKER_RE = re.compile(r"<!--\s*(L-\d{3})\s*-->")
LESSON_MARKER_AT_START = re.compile(r"^- <!--\s*(L-\d{3})\s*-->\s?")

# One ADR id group: ADR-NNN, slash continuations (/NNN), an optional range end (–NNN or ..NNN).
ID_GROUP = re.compile(r"ADR-(\d{3})((?:/\d{3})*)(?:(?:–|\.\.)(\d{3}))?")
ADR_ID_RE = re.compile(r"^ADR-\d{3}$")
LESSON_ID_RE = re.compile(r"^L-\d{3}$")


def collapse(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


def fingerprint(text: str) -> str:
    """sha256[:16] of the marker-stripped, whitespace-collapsed text."""
    return hashlib.sha256(collapse(MARKER_RE.sub("", text)).encode("utf-8")).hexdigest()[:16]


def fence_mask(lines: list[str]) -> list[bool]:
    """True for every line that is a fence line or inside a fenced block (nesting by length)."""
    mask = [False] * len(lines)
    i = 0
    while i < len(lines):
        m = FENCE_RE.match(lines[i])
        if not m:
            i += 1
            continue
        char, size = m.group(1)[0], len(m.group(1))
        mask[i] = True
        j = i + 1
        while j < len(lines):
            mask[j] = True
            c = FENCE_RE.match(lines[j])
            if c and c.group(1)[0] == char and len(c.group(1)) >= size and lines[j].strip() == c.group(1):
                break
            j += 1
        i = j + 1
    return mask


def _expand(m: re.Match) -> list[int]:
    ids = [int(m.group(1))] + [int(x) for x in m.group(2).split("/") if x]
    if m.group(3):
        last, end = ids[-1], int(m.group(3))
        ids += list(range(last + 1, end + 1))
    return ids


def expand_ids(text: str) -> list[int]:
    """Every ADR id named in text, with slash and range expansion; order kept, no duplicates."""
    out: list[int] = []
    for m in ID_GROUP.finditer(text):
        for n in _expand(m):
            if n not in out:
                out.append(n)
    return out


def leading_ids(text: str) -> list[int]:
    """The ids of an id group at the very start of text (after whitespace/bold markers)."""
    m = ID_GROUP.match(text.strip().lstrip("*").strip())
    return _expand(m) if m else []


def fmt_adr(n: int) -> str:
    return f"ADR-{n:03d}"


def fmt_lesson(n: int) -> str:
    return f"L-{n:03d}"


def parse_adr_id(s: str) -> str | None:
    m = re.fullmatch(r"(?:ADR-?)?0*(\d{1,3})", s.strip(), re.I)
    return fmt_adr(int(m.group(1))) if m else None


def parse_lesson_id(s: str) -> str | None:
    m = re.fullmatch(r"(?:L-?)?0*(\d{1,3})", s.strip(), re.I)
    return fmt_lesson(int(m.group(1))) if m else None


def num(id_: str) -> int:
    return int(id_.split("-")[1])


def bold_lead(text: str) -> str | None:
    """The bold lead of a bullet: the first **…** right after the dash (and an optional lesson marker)."""
    t = collapse(text)
    m = re.match(r"^[-*+] (?:<!--\s*L-\d{3}\s*-->\s*)?\*\*(.+?)\*\*", t)
    return m.group(1).strip() if m else None


def _is_block_break(line: str) -> bool:
    return bool(
        BULLET_START.match(line)
        or line.startswith("#")
        or re.match(r"^-{3,}\s*$", line)
        or FENCE_RE.match(line) and not line.startswith(" ")
        or line.startswith("|")
    )


def top_level_bullets(lines: list[str], lo: int = 0, hi: int | None = None,
                      mask: list[bool] | None = None) -> list[tuple[int, int]]:
    """Column-0 bullets in lines[lo:hi] as (start, end) ranges, end exclusive, trailing blanks excluded.

    A bullet continues through indented lines, lazy (unindented, non-structural) continuation lines,
    and blank lines that are followed by an indented line.
    """
    hi = len(lines) if hi is None else hi
    out: list[tuple[int, int]] = []
    i = lo
    while i < hi:
        if (mask is None or not mask[i]) and BULLET_START.match(lines[i]):
            s = i
            i += 1
            while i < hi:
                line = lines[i]
                if line.strip() == "":
                    j = i
                    while j < hi and lines[j].strip() == "":
                        j += 1
                    if j < hi and lines[j][:1] in (" ", "\t"):
                        i = j
                        continue
                    break
                if _is_block_break(line):
                    break
                i += 1
            e = i
            while e > s + 1 and lines[e - 1].strip() == "":
                e -= 1
            out.append((s, e))
        else:
            i += 1
    return out


def section_range(lines: list[str], heading_re: str) -> tuple[int, int] | None:
    """(start, end) of the `## ` section whose heading matches heading_re, end = next `## ` or EOF."""
    mask = fence_mask(lines)
    start = None
    for i, line in enumerate(lines):
        if mask[i]:
            continue
        if start is None and re.match(heading_re, line):
            start = i
        elif start is not None and line.startswith("## "):
            return start, i
    return (start, len(lines)) if start is not None else None


LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def strip_code(text: str) -> str:
    """Remove fenced blocks and inline code spans (for link scanning)."""
    lines = text.split("\n")
    mask = fence_mask(lines)
    kept = ["" if mask[i] else line for i, line in enumerate(lines)]
    return re.sub(r"`[^`\n]*`", "", "\n".join(kept))
