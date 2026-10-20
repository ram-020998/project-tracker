"""Primitives: id lists, bullets, fences, globs, the TOML emitter and in-place editor."""
from __future__ import annotations

import tomllib

import pytest

from genesis_ctx import globs, md, tomlio
from genesis_ctx.config import CtxError


@pytest.mark.parametrize("text,ids", [
    ("ADR-031", [31]),
    ("ADR-002/004/020", [2, 4, 20]),
    ("ADR-005 (+ ADR-029)", [5, 29]),
    ("The Q1–Q14 product decisions (ADR-003, ADR-006–009, ADR-013–017)", [3, 6, 7, 8, 9, 13, 14, 15, 16, 17]),
    ("amends ADR-061 + ADR-063", [61, 63]),
    ("amends ADR-061/063/064", [61, 63, 64]),
    ("ADR-001..003", [1, 2, 3]),
    ("no ids here", []),
])
def test_expand_ids(text, ids):
    assert md.expand_ids(text) == ids


def test_leading_ids_only_at_start():
    assert md.leading_ids("ADR-038/040 amendment — Phase 41") == [38, 40]
    assert md.leading_ids("Amendment (amends ADR-061)") == []


def test_parse_ids_normalize():
    assert md.parse_adr_id("31") == md.parse_adr_id("adr-31") == md.parse_adr_id("ADR-031") == "ADR-031"
    assert md.parse_lesson_id("L-7") == md.parse_lesson_id("7") == "L-007"
    assert md.parse_adr_id("ADR-x") is None


def test_top_level_bullets_with_continuations_and_lazy_lines():
    lines = ["- **A** one", "   cont", "", "   still A after blank", "- **B** two", "lazy B", "", "para", "- C"]
    assert md.top_level_bullets(lines) == [(0, 4), (4, 6), (8, 9)]


def test_bold_lead_wrapped_and_marker():
    assert md.bold_lead("- <!-- L-005 --> **wraps\n   across** rest") == "wraps across"
    assert md.bold_lead("- plain") is None


def test_bold_lead_ignores_stars_inside_backticks():
    # `**` inside an inline code span is not the closing delimiter (L-030 digest fix, 47-09).
    lead = md.bold_lead("- <!-- L-030 --> **Only runs on `changes: [web/**/*]` (16-08).** rest of body")
    assert lead == "Only runs on `changes: [web/**/*]` (16-08)."


def test_fence_mask_nested_lengths():
    lines = ["````md", "```toml", "x = 1", "```", "````", "out"]
    assert md.fence_mask(lines) == [True, True, True, True, True, False]


def test_fingerprint_ignores_markers_and_whitespace():
    assert md.fingerprint("- <!-- L-001 --> **a**  b\n c") == md.fingerprint("- **a** b c")


@pytest.mark.parametrize("pat,path,ok", [
    ("genesis/genesis/chat/**", "genesis/genesis/chat/manager.py", True),
    ("genesis/genesis/chat/**", "genesis/genesis/chat/sub/x.py", True),
    ("genesis/genesis/chat/**", "genesis/genesis/chatter.py", False),
    ("genesis/**/store.py", "genesis/store.py", True),
    ("genesis/**/store.py", "genesis/genesis/kb/store.py", True),
    ("genesis/genesis/kb/*.py", "genesis/genesis/kb/store.py", True),
    ("genesis/genesis/kb/*.py", "genesis/genesis/kb/sub/store.py", False),
    ("genesis/genesis/kb/st?re.py", "genesis/genesis/kb/store.py", True),
    ("genesis/web/src/features/features/**", "genesis/web/src/features/features/**", True),
])
def test_glob_semantics(pat, path, ok):
    assert globs.match(pat, path) is ok


def test_glob_expand_skips_caches(env):
    files = globs.expand(env.repos, "genesis/genesis/chat/**")
    assert files == ["genesis/genesis/chat/manager.py"]
    assert globs.expand(env.repos, "genesis/genesis/api/app.py") == ["genesis/genesis/api/app.py"]
    assert globs.expand(env.repos, "nope/**") == []


def test_toml_emitter_round_trip():
    data = {
        "ADR-031": {"title": 'Chat "read-only" \\ path', "areas": ["chat", "security"], "rule": "x\ny",
                    "superseded_by": "", "n": 3, "ok": True},
        "genesis/genesis/  db/": {"areas": ["db"]},
        "── Phase 34 — Design Lane": {"areas": []},
        "area": {"chat": {"title": "Chat", "paths": ["a/**"]}, "db": {"title": "DB", "always": False}},
    }
    assert tomllib.loads(tomlio.dumps(data)) == data


def test_set_field_in_place_keeps_comments():
    text = '# header\n\n[ADR-001]\nareas = ["a"]  # note\nrule = "r"\n\n[ADR-002]\nrule = "s"\n'
    out = tomlio.set_field(text, "ADR-001", "reviewed_fp", "abc")
    assert out.startswith("# header") and "# note" in out
    assert tomllib.loads(out)["ADR-001"]["reviewed_fp"] == "abc"
    assert "reviewed_fp" not in tomllib.loads(out)["ADR-002"]
    out2 = tomlio.set_field(out, "ADR-001", "reviewed_fp", "def")
    assert out2.count("reviewed_fp") == 1 and tomllib.loads(out2)["ADR-001"]["reviewed_fp"] == "def"
    with pytest.raises(CtxError):
        tomlio.set_field(text, "ADR-009", "rule", "x")
