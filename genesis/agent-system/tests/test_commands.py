"""status, adr, lesson, area, search, pack, check, index, add."""
from __future__ import annotations

import json
import tomllib

from conftest import git, git_init


def test_help_lists_every_command(env):
    code, out, _ = env.run("--help")
    assert code == 0
    for cmd in ("status", "pack", "check", "adr", "lesson", "area", "search", "index", "lint", "add", "mark",
                "archive", "propose-tags", "propose-b04", "verify-lossless"):
        assert cmd in out


def test_usage_error_exit_2(env):
    assert env.run("adr", "ADR-999")[0] == 2
    assert env.run("pack", "--areas", "nope")[0] == 2
    assert env.run("bogus")[0] == 2


def test_status_on_temp_git_repo_with_tag(env):
    repo = env.repos / "genesis"
    git_init(repo)
    git(repo, "tag", "v0.1.0")
    (repo / "dirty.txt").write_text("x")
    code, out, _ = env.run("status", "--json")
    assert code == 0
    data = json.loads(out)
    g = data["repos"]["genesis"]
    assert g["present"] and g["tag"] == "v0.1.0" and g["dirty"] == 1 and g["branch"] == "main"
    assert g["ahead"] is None  # no upstream
    assert data["repos"]["genesis-workflows"]["present"] is False
    assert data["active_phase"].startswith("48 — Demo phase")
    _, out, _ = env.run("status", "--brief")
    assert "Active phase: 48 — Demo phase" in out and "Active phase: Active phase" not in out
    code, brief, _ = env.run("status", "--brief")
    assert code == 0 and len(brief.strip().split("\n")) <= 25 and "v0.1.0" in brief


def test_adr_prints_decision_log_bible04_and_chain_both_directions(env):
    code, out, _ = env.run("adr", "31")
    assert code == 0
    assert "## ADR-031" in out and "read-only `@server/tool` allowlist" in out  # decision-log
    assert "bible/04 L" in out and "It never orchestrates" in out              # bible/04 bullet
    assert "## ADR-033" in out and "chain via ADR-031" in out                   # amended_by → 033
    code, out, _ = env.run("adr", "ADR-033")
    assert "## ADR-031" in out                                                    # amends → 031
    code, out, _ = env.run("adr", "ADR-033", "--no-chain")
    assert "## ADR-031" not in out


def test_adr_loads_amendments_and_bullet_form(env):
    _, out, _ = env.run("adr", "ADR-040")
    assert "AMEND-038-040-TEXT" in out
    _, out, _ = env.run("adr", "ADR-053")
    assert "ADR-053-BODY" in out and "bullet" in out and "One MCP injection path" in out


def test_lesson_and_area(env):
    code, out, _ = env.run("lesson", "L-3", "1")
    assert code == 0 and "SSE frames" in out and "ACP MCP env" in out
    assert env.run("lesson", "L-099")[0] == 2
    code, out, _ = env.run("area", "chat")
    assert code == 0 and "ADR-031" in out and "L-002" in out and "`genesis/genesis/  chat/`" in out
    assert "1 files" in out  # chat/** expands to manager.py only (cache skipped)


def test_search_active_vs_archive(env):
    code, out, _ = env.run("search", "OLD-SPEC-TEXT")
    assert code == 1 and "no matches" in out
    code, out, _ = env.run("search", "old-spec-text", "--archive")
    assert code == 0 and "specs/phase-47-old/47-01-old.md:3:" in out
    assert env.run("search", "(", "--archive")[0] == 2


def test_pack_sub_spec(env):
    code, out, _ = env.run("pack", "48-01")
    assert code == 0, out
    text = (env.tracker / "context/.packs/48-01.md").read_text()
    assert "| chat | manifest |" in text
    assert "| api | path `genesis/genesis/api/app.py` |" in text                # path-derived area
    assert "| security | always-on |" in text and "| release-ci | always-on |" in text
    assert "ADR-076 | manifest" in text                                          # manifest ADR
    assert "ADR-028 | area api; path `genesis/genesis/api/app.py`" in text       # tag paths
    assert "ADR-033 | area chat" in text and "### ADR-031" in text
    assert "L-003 | manifest; area api" in text
    assert "`genesis/genesis/  chat/`" in text and "````text" in text
    assert "`tracker:reference/hitl-design.md` | area chat" in text               # area docs
    assert "`tracker:specs/phase-48-demo.md` | umbrella spec" in text
    assert "ADR-001" not in text.split("## ADRs")[0].split("## Included")[1]       # core-engine not selected
    assert "budget **OK**" in text


def test_pack_glob_code_upstream_and_areas_only(env):
    code, _, _ = env.run("pack", "48-02")
    assert code == 0
    text = (env.tracker / "context/.packs/48-02.md").read_text()
    assert "path `genesis/genesis/kb/*.py`" in text  # expanded: features/stories/boards/store
    for area in ("features-stages", "stories-workbench", "kb-sync"):
        assert f"| {area} | path" in text
    assert "upstream 48-01" in text
    code, out, _ = env.run("pack", "--areas", "db")
    assert code == 0 and "ADR-054" in (env.tracker / "context/.packs/areas-db.md").read_text()


def test_pack_chain_pulls_amended_adr_from_other_area(env):
    env.edit("context/tags/adr.toml", 'areas = ["chat", "security"]\namended_by', 'areas = ["core-engine"]\namended_by')
    env.run("index", "--reviewed-all")
    env.run("pack", "--areas", "chat", "--out", str(env.root / "p.md"))
    text = (env.root / "p.md").read_text()
    assert "ADR-031 | chain via ADR-033" in text


def test_pack_closure_changers_transitive_amends_one_hop_from_seeds(env):
    # 47-01 §5 round 5: amended_by / superseded_by are followed transitively; amends only one hop from seeds.
    env.write("context/tags/adr.toml", "\n".join([
        '[ADR-031]', 'areas = ["chat"]', 'amended_by = ["ADR-033"]', '',
        '[ADR-033]', 'areas = ["api"]', 'amends = ["ADR-031"]', 'amended_by = ["ADR-076"]', '',
        '[ADR-076]', 'areas = ["api"]', 'amends = ["ADR-033"]', '',
        '[ADR-026]', 'areas = ["db"]', 'amended_by = ["ADR-063"]', '',
        '[ADR-063]', 'areas = ["api"]', 'amends = ["ADR-026"]', 'amended_by = ["ADR-064"]', '',
        '[ADR-064]', 'areas = ["api"]', 'amends = ["ADR-063", "ADR-061"]', '',
        '[ADR-061]', 'areas = ["api"]', 'amended_by = ["ADR-064"]', '',
        '[ADR-053]', 'areas = ["core-engine"]', 'superseded_by = "ADR-054"', '',
        '[ADR-054]', 'areas = ["api"]', '']))
    env.run("pack", "--areas", "chat", "--out", str(env.root / "chat.md"))
    chat = (env.root / "chat.md").read_text()
    assert "ADR-033 | chain via ADR-031" in chat and "ADR-076 | chain via ADR-033" in chat   # transitive changers
    env.run("pack", "--areas", "db", "--out", str(env.root / "db.md"))
    db = (env.root / "db.md").read_text()
    assert "ADR-063 | chain via ADR-026" in db and "ADR-064 | chain via ADR-063" in db
    assert "ADR-061 |" not in db                  # 064 is chain-added: its `amends` are not followed
    env.edit("context/tags/adr.toml", '[ADR-064]\nareas = ["api"]', '[ADR-064]\nareas = ["stories-workbench"]')
    env.run("pack", "--areas", "stories-workbench", "--out", str(env.root / "sw.md"))
    sw = (env.root / "sw.md").read_text()
    assert "ADR-061 | chain via ADR-064" in sw and "ADR-063 | chain via ADR-064" in sw  # seed: amends one hop
    assert "ADR-026 |" not in sw                  # 063 was added by amends, so its own `amends` are not followed
    env.run("pack", "--areas", "core-engine", "--out", str(env.root / "ce.md"))
    assert "ADR-054 | chain via ADR-053" in (env.root / "ce.md").read_text()               # superseded_by
    _, out, _ = env.run("adr", "ADR-026")
    assert "ADR-061" in out                       # `adr` keeps the full chain


def test_pack_budget_warn_and_fail(env, monkeypatch):
    from genesis_ctx import config
    monkeypatch.setattr(config, "PACK_WARN", 50)
    code, out, _ = env.run("pack", "--areas", "chat")
    assert code == 0 and "WARN" in out
    monkeypatch.setattr(config, "PACK_FAIL", 100)
    code, out, _ = env.run("pack", "--areas", "chat")
    assert code == 1 and "FAIL" in out and "narrow" in out


def test_pack_without_manifest_warns(env):
    env.write("specs/phase-48-demo/48-03-none.md", "# 48-03 — no manifest\n")
    code, _, _ = env.run("pack", "48-03")
    assert code == 0
    assert "no `## Context manifest`" in (env.tracker / "context/.packs/48-03.md").read_text()


def test_check_files_maps_areas_rules_gates(env):
    code, out, _ = env.run("check", "--files", "genesis/genesis/db/runner.py", "--json")
    assert code == 0
    d = json.loads(out)
    assert d["files"] == [{"path": "genesis/genesis/db/runner.py", "areas": ["db"]}]
    assert set(d["areas"]) == {"db", "security", "release-ci"}
    ids = [a["id"] for a in d["adrs"]]
    assert "ADR-054" in ids and "ADR-031" in ids and "ADR-033" in ids  # security area + chain
    assert {"command": "glab ci list", "area": "release-ci"} in d["gates"]
    assert any(g["area"] == "db" for g in d["gates"])
    code, out, _ = env.run("check", "--files", "genesis/genesis/db/runner.py")
    assert "- [ ] ADR-054" in out and "OK / VIOLATION / N/A" in out


def test_check_since_in_temp_repo(env):
    repo = env.repos / "genesis"
    git_init(repo)
    git(repo, "tag", "base")
    (repo / "genesis/chat/manager.py").write_text("changed\n")
    (repo / "genesis/chat/new.py").write_text("new\n")
    code, out, _ = env.run("check", "--since", "base", "--json")
    assert code == 0
    d = json.loads(out)
    assert [f["path"] for f in d["files"]] == ["genesis/genesis/chat/manager.py", "genesis/genesis/chat/new.py"]
    assert "chat" in d["areas"]
    assert env.run("check", "--since", "nope", "--repo", "genesis")[0] == 2


def test_index_is_deterministic(env):
    before = {p.name: p.read_text() for p in (env.tracker / "context/_generated").iterdir()}
    code, out, _ = env.run("index")
    assert code == 0 and "0 generated file(s) rewritten" in out
    after = {p.name: p.read_text() for p in (env.tracker / "context/_generated").iterdir()}
    assert before == after and set(after) == {"adr-digest.md", "lesson-digest.md", "area-catalog.md"}
    digest = after["adr-digest.md"]
    assert "- ADR-031 [chat,security] (amended by 033) — Chat never orchestrates" in digest
    assert "- ADR-002 [untagged] — " in digest
    assert "- L-001 [chat,core-engine] — ACP MCP env MUST be a list of `{name,value}`" in after["lesson-digest.md"]


def test_index_fills_empty_fp_but_only_reviewed_refreshes(env):
    tags = tomllib.loads(env.read("context/tags/adr.toml"))
    fp = tags["ADR-031"]["reviewed_fp"]
    assert len(fp) == 16  # filled by the setup `index`
    env.edit("reference/decision-log.md", "Chat never mutates;", "Chat never mutates anything;")
    env.run("index")
    assert tomllib.loads(env.read("context/tags/adr.toml"))["ADR-031"]["reviewed_fp"] == fp  # not silenced
    code, out, _ = env.run("lint", "--json")
    assert any(f["code"] == "fp-drift" and "ADR-031" in f["message"] for f in json.loads(out)["findings"])
    env.run("index", "--reviewed", "ADR-031")
    assert tomllib.loads(env.read("context/tags/adr.toml"))["ADR-031"]["reviewed_fp"] != fp
    assert env.run("lint")[0] == 0
    assert env.read("context/tags/adr.toml").startswith("# Fixture ADR tags")  # header comment kept
    assert env.run("index", "--reviewed", "ADR-002")[0] == 2  # no tag entry


def test_add_adr_and_lesson(env):
    code, out, err = env.run("add", "adr", "--id", "ADR-077", "--title", "Tiered agent context",
                             "--areas", "chat", "--rule", "Rules are selected by program.", "--amends", "ADR-031")
    assert code == 0, err
    assert "## ADR-077 — Tiered agent context — **Proposed**" in env.read("reference/decision-log.md")
    tags = tomllib.loads(env.read("context/tags/adr.toml"))
    assert tags["ADR-077"]["amends"] == ["ADR-031"] and "ADR-077" in tags["ADR-031"]["amended_by"]
    assert env.run("add", "adr", "--id", "ADR-077", "--title", "x", "--areas", "chat", "--rule", "y")[0] == 2
    body = env.root / "body.txt"
    body.write_text("First line of the body.\nSecond line.\n")
    code, out, err = env.run("add", "lesson", "--areas", "db", "--rule", "Never reuse a lesson id.",
                             "--body-file", str(body), "--phase", "47")
    assert code == 0, err
    c = env.corpus()
    l6 = c.lesson("L-006")
    assert l6.lead == "Never reuse a lesson id (Phase 47)." and "   Second line." in l6.text
    assert "- <!-- L-006 --> **Never reuse a lesson id (Phase 47).** First line of the body." in \
        env.read("bible/06-hard-won-lessons.md")
    assert tomllib.loads(env.read("context/tags/lesson.toml"))["L-006"]["areas"] == ["db"]
    assert env.run("lint")[0] == 0, env.run("lint")[1]
    assert env.run("add", "lesson", "--areas", "db", "--rule", "x" * 300)[0] == 2
    assert env.run("add", "lesson", "--areas", "db", "--rule", "x" * 215, "--phase", "48")[0] == 2  # lead > 220


def test_add_adr_writes_the_house_format(env):
    """47-08 §5: heading with (Phase NN) + Status, Context, Decision, Alternatives rejected, Consequences; amends."""
    code, _, err = env.run("add", "adr", "--id", "ADR-078", "--title", "Probe decision", "--phase", "48",
                           "--areas", "chat", "--rule", "Probe rule.", "--amends", "ADR-031", "--status", "accepted")
    assert code == 0, err
    log = env.read("reference/decision-log.md")
    block = log[log.index("## ADR-078"):]
    assert block.startswith("## ADR-078 — Probe decision (Phase 48) — **Accepted**\n\n- **Status:** **Accepted** — ")
    leads = [ln.split("**")[1] for ln in block.splitlines() if ln.startswith("- **")]
    assert leads == ["Status:", "Context.", "Decision.", "Alternatives rejected.", "Consequences."]
    assert "- **Decision.** Probe rule." in block and "Amends ADR-031: _(what changes and why)_." in block
    tag = tomllib.loads(env.read("context/tags/adr.toml"))["ADR-078"]
    assert tag["title"] == "Probe decision (Phase 48)" and tag["status"] == "accepted"
    assert env.run("lint")[0] == 0, env.run("lint")[1]


def test_pack_and_adr_dedupe_combined_bible04_bullet(env):
    # The amendment bullet names ADR-061 + ADR-063 (both stories-workbench); it must print ONCE.
    code, _, _ = env.run("pack", "--areas", "stories-workbench", "--out", str(env.root / "sw.md"))
    assert code == 0
    text = (env.root / "sw.md").read_text()
    assert text.count("AMEND-BULLET") == 1                                     # deduped across the two ids
    assert "shared bible/04 bullet — shown once under ADR-061" in text          # pointer under ADR-063
    _, out, _ = env.run("adr", "61", "63")
    assert out.count("AMEND-BULLET") == 1                                       # `adr` dedupes too


def test_b04_skip_honoured_in_pack_but_not_adr(env):
    # b04 = "skip" drops ADR-031's bible/04 bullet from packs, but `adr` always prints it.
    env.edit("context/tags/adr.toml", '[ADR-031]\ntitle', '[ADR-031]\nb04 = "skip"\ntitle')
    code, _, _ = env.run("pack", "--areas", "chat", "--out", str(env.root / "c.md"))
    assert code == 0
    text = (env.root / "c.md").read_text()
    assert "### ADR-031" in text                                               # decision-log section stays
    assert "**Chat is read-only.**" not in text                                # the bible/04 bullet is skipped
    _, out, _ = env.run("adr", "31")
    assert "**Chat is read-only.**" in out                                     # `adr` ignores skip
    assert env.run("lint")[0] == 0                                             # b04 is a valid field
