"""Every lint rule (47-03 §5): the clean fixture passes; one failing fixture per rule."""
from __future__ import annotations

import json

import pytest


def codes(env, *args):
    code, out, _ = env.run("lint", "--json", *args)
    d = json.loads(out)
    return code, {f["code"] for f in d["findings"] if f["level"] == "error"}, \
        {f["code"] for f in d["findings"] if f["level"] == "warning"}, d


def test_clean_fixture_passes(env):
    code, errors, warnings, d = codes(env)
    assert code == 0 and errors == set(), d["findings"]
    assert warnings == {"adr-no-decision-log"}  # ADR-002/004/005/020/006–009/013–017: bible/04 only
    code, out, _ = env.run("lint")
    assert code == 0 and "lint: OK" in out and "L0 ~" in out


def _fail(env, expected, *args):
    code, errors, _, d = codes(env, *args)
    assert code == 1 and expected in errors, d["findings"]


def test_adr_untagged(env):
    env.edit("context/tags/adr.toml", "[ADR-076]", "[ADR-075]")
    _fail(env, "adr-untagged")


def test_adr_unknown_tag(env):
    env.edit("context/tags/adr.toml", "[ADR-076]", "[ADR-076]\nstatus = \"accepted\"\n\n[ADR-099]")
    code, errors, _, _ = codes(env)
    assert "adr-unknown" in errors


def test_adr_tag_incomplete_and_rule_too_long(env):
    env.edit("context/tags/adr.toml", 'rule = "Genesis is a local web app on 127.0.0.1."', f'rule = "{"x" * 230}"')
    env.edit("context/tags/adr.toml", 'areas = ["core-engine"]\nrule = "LangGraph', 'areas = []\nrule = "LangGraph')
    code, errors, _, _ = codes(env)
    assert {"adr-tag-incomplete", "rule-too-long"} <= errors


def test_adr_invalid_b04(env):
    env.edit("context/tags/adr.toml", '[ADR-031]\ntitle', '[ADR-031]\nb04 = "maybe"\ntitle')
    code, errors, _, d = codes(env)
    assert code == 1 and "tag-invalid" in errors
    assert any("b04" in f["message"] for f in d["findings"])


def test_adr_duplicate_primary_anchor(env):
    env.edit("reference/decision-log.md", "## ADR-064 —", "## ADR-063 — again\n\nDup.\n\n## ADR-064 —")
    _fail(env, "adr-duplicate-anchor")


def test_lesson_unmarked(env):
    env.edit("bible/06-hard-won-lessons.md", "- <!-- L-003 --> **SSE", "- **SSE")
    code, errors, _, _ = codes(env)
    assert {"lesson-unmarked", "lesson-unknown"} <= errors


def test_lesson_untagged_and_duplicate_marker(env):
    env.edit("bible/06-hard-won-lessons.md", "<!-- L-004 -->", "<!-- L-003 -->")
    code, errors, _, _ = codes(env)
    assert {"lesson-duplicate-marker", "lesson-unknown"} <= errors
    env.edit("bible/06-hard-won-lessons.md", "- <!-- L-003 --> **Board", "- <!-- L-009 --> **Board")
    _fail(env, "lesson-untagged")


def test_codemap_untagged_and_unknown(env):
    env.edit("context/tags/codemap.toml", '["genesis/genesis/  db/"]', '["genesis/genesis/  dbx/"]')
    code, errors, _, _ = codes(env)
    assert {"codemap-untagged", "codemap-unknown"} <= errors


def test_unknown_area(env):
    env.edit("context/tags/lesson.toml", 'areas = ["api"]', 'areas = ["apix"]')
    _fail(env, "unknown-area")


def test_area_invalid_and_glob_warning(env):
    env.write("context/areas.toml", env.read("context/areas.toml")
              + '\n[area.Bad_Name]\ntitle = "x"\npaths = ["nothing/**"]\ncolour = "red"\n\n[area.nopaths]\ntitle = "y"\n')
    code, errors, warnings, d = codes(env)
    msgs = [f["message"] for f in d["findings"] if f["code"] == "area-invalid"]
    assert any("[a-z0-9-]+" in m for m in msgs) and any("unknown key `colour`" in m for m in msgs)
    assert any("no paths" in m for m in msgs)
    assert "area-glob-empty" in warnings


def test_amends_asymmetric(env):
    env.edit("context/tags/adr.toml", 'amended_by = ["ADR-033"]\n', "")
    _fail(env, "amends-asymmetric")


def test_superseded_without_superseded_by(env):
    env.edit("context/tags/adr.toml", 'title = "Two-tier registry"\nstatus = "accepted"',
             'title = "Two-tier registry"\nstatus = "superseded"')
    _fail(env, "superseded-missing")


def test_fp_missing(env):
    text = env.read("context/tags/lesson.toml")
    import re
    env.write("context/tags/lesson.toml", re.sub(r'reviewed_fp = "[0-9a-f]+"\n', "", text, count=1))
    _fail(env, "fp-missing")


def test_generated_stale(env):
    env.edit("context/_generated/adr-digest.md", "ADR-031", "ADR-31x")
    _fail(env, "generated-stale")


def test_l0_and_state_budgets(env, monkeypatch):
    env.write("context/state/current.md", "x" * 20_000)
    code, errors, _, _ = codes(env)
    assert "state-budget" in errors and "l0-budget" not in errors
    from genesis_ctx import config
    monkeypatch.setattr(config, "L0_BUDGET", 100)
    _fail(env, "l0-budget")


def test_broken_link(env):
    env.edit("context/L0-core.md", "../bible/02-architecture.md", "../bible/99-missing.md")
    _fail(env, "broken-link")


@pytest.mark.parametrize("text,expected", [
    ("# 48-04 — no manifest\n", "manifest-missing"),
    ("## Context manifest\n\n```toml\nareas = 3\n```\n", "manifest-invalid"),
    ("## Context manifest\n\n```toml\nareas = [\"nope\"]\nadrs = [\"ADR-999\"]\nlessons = [\"L-099\"]\n"
     "upstream = [\"48-77\"]\n```\n", "manifest-unknown-ref"),
])
def test_manifest_rules(env, text, expected):
    env.write("specs/phase-48-demo/48-04-x.md", text)
    _fail(env, expected)
    code, errors, _, _ = codes(env, "--specs-only")
    assert code == 1 and errors == {expected}


def test_old_phase_specs_need_no_manifest(env):
    code, errors, _, _ = codes(env, "--specs-only")
    assert code == 0 and errors == set()


def test_quiet_output(env):
    code, out, _ = env.run("lint", "--quiet")
    assert code == 0 and out == ""
    env.edit("context/tags/adr.toml", "[ADR-076]", "[ADR-075]")
    code, out, _ = env.run("lint", "--quiet")
    assert code == 1 and "adr-untagged 1" in out
