"""Anchor rules against the real shapes (47-02 §4.1 / §4.3, 47-01 §5.5)."""
from __future__ import annotations


def _texts(c, adr):
    return [a.text for a in c.anchors_for(adr)]


def test_q_heading_is_a_primary_section(env):
    c = env.corpus()
    a = c.primary_anchor("ADR-003")
    assert a.head.startswith("ADR-003 (Q1)") and "shared GitLab workflow library" in a.text


def test_non_adr_heading_is_a_boundary(env):
    c = env.corpus()
    assert "Technical ADRs" not in c.primary_anchor("ADR-003").text
    assert any(a.kind == "boundary" and a.head.startswith("Technical ADRs") for a in c.anchors)


def test_h3_adr_under_h2_and_addendum(env):
    c = env.corpus()
    p27 = c.primary_anchor("ADR-027")
    assert "ADDENDUM-027-TEXT" not in p27.text and "Backend API" not in p27.text
    kinds = [(a.kind, a.level) for a in c.anchors_for("ADR-027")]
    assert kinds == [("primary", 2), ("amendment", 3)]
    p28 = c.primary_anchor("ADR-028")
    assert p28.level == 3 and "/api" in p28.text and "Two-Tier" not in p28.text
    assert c.primary_anchor("ADR-029").level == 3


def test_slash_combined_amendment_loads_with_both(env):
    c = env.corpus()
    for adr in ("ADR-038", "ADR-040"):
        assert any("AMEND-038-040-TEXT" in t for t in _texts(c, adr))
    assert c.primary_anchor("ADR-038").kind == "primary"


def test_amends_list_heading_loads_with_every_named_adr(env):
    c = env.corpus()
    for adr in ("ADR-061", "ADR-063", "ADR-064"):
        texts = _texts(c, adr)
        assert any("AMEND-061-TEXT" in t for t in texts), adr
    a = next(a for a in c.anchors if "AMEND-061-TEXT" in a.text)
    assert a.kind == "amendment" and a.ids == [61, 63, 64]


def test_amendment_heading_is_not_a_duplicate_primary(env):
    c = env.corpus()
    kinds = [a.kind for a in c.anchors_for("ADR-026")]
    assert kinds == ["primary", "amendment"]
    assert "ADR-026" in c.primary_ids


def test_bullet_form_adr_inside_another_section(env):
    c = env.corpus()
    a51 = c.primary_anchor("ADR-051")
    assert "ADR-051-BODY" in a51.text and "ADR-053" not in a51.text
    a53, a54 = c.primary_anchor("ADR-053"), c.primary_anchor("ADR-054")
    assert a53.form == a54.form == "bullet"
    assert "ADR-053-BODY" in a53.text and "ADR-054" not in a53.text
    assert a54.text.rstrip().endswith("ADR-054-BODY.")  # runs to the next heading, blanks trimmed


def test_last_section_and_all_ids_have_text(env):
    c = env.corpus()
    assert "LAST-SECTION-TEXT" in c.primary_anchor("ADR-076").text
    assert all(c.adr_known(i) for i in c.adr_ids)


def test_bible04_combined_range_plus_and_amendment_bullets(env):
    c = env.corpus()
    assert [b.lineno for b in c.b04_for("ADR-004")] == [c.b04_for("ADR-002")[0].lineno]
    assert any("PLUS-BULLET" in b.text for b in c.b04_for("ADR-029"))
    assert any("RANGE-BULLET" in b.text for b in c.b04_for("ADR-008"))
    assert any("RANGE-BULLET" in b.text for b in c.b04_for("ADR-016"))
    for adr in ("ADR-061", "ADR-063"):
        assert any("AMEND-BULLET" in b.text for b in c.b04_for(adr))
    assert not any("RunnableConfig" in b.text for b in c.b04)  # contracts bullets name no ADR


def test_lessons_markers_and_wrapped_lead(env):
    c = env.corpus()
    assert [l.marker for l in c.lessons] == ["L-001", "L-002", "L-003", "L-004", "L-005"]
    assert c.lesson("L-005").lead == "A bold lead that wraps across two lines is still one bold lead."
    assert "env in kiro-cli acp." in c.lesson("L-001").text


def test_codemap_sections_all_kinds(env):
    c = env.corpus()
    keys = [s.key for s in c.sections]
    assert keys == [
        "genesis-core/genesis_core/  types.py",
        "genesis-core/genesis_core/  state.py",
        "genesis-core/genesis_core/  nodes/",
        "genesis-core/genesis_core/  state.py #2",
        "genesis/genesis/  db/",
        "genesis/genesis/  chat/",
        "── Phase 25 — Architectural Foundation Hardening (genesis v0.49.0)",
        "── Phase 29 — UX Design stage (grounded mockup→implementation analysis; ADR-057)",
        "── Phase 31 — Feature Breakdown stage (ADR-059)",
        "Phase 45 — Incremental Delta Sync (genesis v0.76.0)",
    ]


def test_codemap_base_ends_at_first_block_inside_fence(env):
    c = env.corpus()
    chat = c.section("genesis/genesis/  chat/")
    assert "Phase 25" not in chat.text and chat.display.startswith("genesis/genesis/\n  chat/")
    p29 = c.section("── Phase 29 — UX Design stage (grounded mockup→implementation analysis; ADR-057)")
    assert p29.text.rstrip().endswith("```")  # runs past the fence close, stops at ---
    p31 = c.section("── Phase 31 — Feature Breakdown stage (ADR-059)")
    assert "Phase 45" not in p31.text  # stops at the bold line
    p45 = c.section("Phase 45 — Incremental Delta Sync (genesis v0.76.0)")
    assert p45.kind == "bold" and "apply(mode='incremental')" in p45.text
    assert "CORE_MAJOR=1." in c.section("genesis-core/genesis_core/  types.py").text


def test_untagged_titles_drop_id_paren_and_status(env):
    env.write("context/tags/adr.toml", "")
    c = env.corpus()
    assert c.adr_title("ADR-003") == "Local web app; shared GitLab library; internal Solutions users"
    assert c.adr_title("ADR-028") == "Backend API namespaced under `/api` + SPA history fallback"
    assert c.adr_title("ADR-076") == "Spec change requests: a chat-driven CR, a program-applied plan (Phase 46)"
    assert c.adr_title("ADR-053") == "Memory Layer"
    assert c.adr_title("ADR-054").startswith("memory store/infra + local embedder in")


def test_manifest_ignores_fenced_example(env):
    from genesis_ctx.sources import parse_manifest
    m = parse_manifest(env.read("specs/phase-48-demo/48-01-first.md"))
    assert m.error is None and m.data["areas"] == ["chat"]
    bad = parse_manifest("## Context manifest\n\n```toml\nareas = [\"x\"]\nbogus = [\"y\"]\n```\n")
    assert "unknown manifest key" in bad.error
    assert parse_manifest("# no manifest\n").present is False
