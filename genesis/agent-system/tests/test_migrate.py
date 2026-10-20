"""mark, archive, verify-lossless, propose-tags."""
from __future__ import annotations

import json
import re
import tomllib

from conftest import git

PLAN = '''date = "2026-10-21"

[[step]]
n = 1
name = "Status log"
source = "tracker.md"
dest = "archive/tracker-status-log.md"
start = '^## 6\\. Status log'
include_start = false
end = "EOF"
note = "From Phase 47 on: ≤ 5 lines per phase; detail lives in `progress/`."

[[step]]
n = 2
name = "Shipped phases"
source = "bible/08-roadmap-and-backlog.md"
dest = "archive/bible-08-shipped-phases.md"
heading = '^### '
contains = ["SHIPPED", "CLOSED"]
stop = ['^### ', '^## ', '^Do not start backlog']
'''


def _strip_markers(env):
    env.write("bible/06-hard-won-lessons.md", re.sub(r"<!-- L-\d{3} --> ", "", env.read("bible/06-hard-won-lessons.md")))


def test_mark_inserts_in_document_order_and_is_idempotent(env):
    _strip_markers(env)
    env.write("context/tags/lesson.toml", "")
    code, out, _ = env.run("mark")
    assert code == 0 and "marked 5 lesson(s): L-001..L-005" in out
    text = env.read("bible/06-hard-won-lessons.md")
    assert text.count("<!-- L-") == 5 and "- <!-- L-001 --> **ACP MCP env" in text
    code, out, _ = env.run("mark")
    assert "already has a marker" in out and env.read("bible/06-hard-won-lessons.md") == text


def test_mark_continues_ids_never_reuses(env):
    env.edit("bible/06-hard-won-lessons.md", "- <!-- L-003 --> **SSE", "- **SSE")
    env.run("mark")
    assert "- <!-- L-006 --> **SSE" in env.read("bible/06-hard-won-lessons.md")  # L-003 stays retired


def test_mark_dry_run_writes_nothing(env):
    _strip_markers(env)
    before = env.read("bible/06-hard-won-lessons.md")
    code, out, _ = env.run("mark", "--dry-run")
    assert "would mark 5" in out and env.read("bible/06-hard-won-lessons.md") == before


def test_archive_dry_run_then_apply_with_pointers(env):
    plan = env.root / "plan.toml"
    plan.write_text(PLAN)
    before = env.read("tracker.md")
    code, out, _ = env.run("archive", "--plan", str(plan))
    assert code == 0 and "dry run" in out and "| 1 | `tracker.md` | L9–L15 |" in out
    assert "| 2 | `bible/08-roadmap-and-backlog.md` |" in out and out.count("| 2 |") == 2
    assert env.read("tracker.md") == before and not (env.tracker / "archive/tracker-status-log.md").exists()

    code, out, _ = env.run("archive", "--plan", str(plan), "--apply")
    assert code == 0
    tr = env.read("tracker.md")
    assert "## 6. Status log" in tr and "STATUS-ENTRY-45" not in tr
    assert "> 📦 Moved verbatim to [archive/tracker-status-log.md](archive/tracker-status-log.md) " \
           "(Phase 47-04, 2026-10-21)." in tr
    assert "From Phase 47 on" in tr
    arch = env.read("archive/tracker-status-log.md")
    assert "STATUS-ENTRY-45" in arch and "STATUS-ENTRY-46" in arch
    assert "<!-- archived from tracker.md L9–L15, step 1, 2026-10-21 -->" in arch
    b08 = env.read("bible/08-roadmap-and-backlog.md")
    assert "SHIPPED-46" not in b08 and "CLOSED-44" not in b08 and "DRAFT-47" in b08 and "BACKLOG-ITEM" in b08
    assert b08.count("(../archive/bible-08-shipped-phases.md)") == 2
    assert "Do not start backlog" in b08


def test_archive_reapply_is_noop(env):
    plan = env.root / "plan.toml"
    plan.write_text(PLAN)
    env.run("archive", "--plan", str(plan), "--apply")
    snap = (env.read("tracker.md"), env.read("archive/tracker-status-log.md"), env.read("bible/08-roadmap-and-backlog.md"))
    code, out, _ = env.run("archive", "--plan", str(plan), "--apply")
    assert code == 0 and out.count("(already applied)") == 2
    assert snap == (env.read("tracker.md"), env.read("archive/tracker-status-log.md"),
                    env.read("bible/08-roadmap-and-backlog.md"))


def test_archive_step_filter_and_invalid_plans(env):
    plan = env.root / "plan.toml"
    plan.write_text(PLAN)
    code, out, _ = env.run("archive", "--plan", str(plan), "--step", "2")
    assert "| 1 |" not in out and "| 2 |" in out
    for bad in ('[[step]]\nn = 1\nname = "x"\nsource = "tracker.md"\ndest = "archive/x.md"\n',          # no selector
                '[[step]]\nn = 1\nname = "x"\nsource = "tracker.md"\ndest = "archive/x.md"\nstart = "^## 9"\n',
                '[[step]]\nn = 1\nname = "x"\nsource = "tracker.md"\ndest = "../x.md"\nstart = "^## 6"\n',
                'colour = "red"\n'):
        plan.write_text(bad)
        assert env.run("archive", "--plan", str(plan))[0] == 2, bad


def test_verify_lossless_ignores_moved_detects_deleted(git_env):
    env = git_env
    plan = env.root / "plan.toml"
    plan.write_text(PLAN)
    env.run("archive", "--plan", str(plan), "--apply")
    env.run("mark")
    code, out, _ = env.run("verify-lossless", "--baseline", "HEAD")
    assert code == 0 and "missing: **0** → PASS" in out, out
    env.edit("bible/05-dev-loop-and-release.md", "Run the tests before you commit. DEVLOOP.\n", "")
    code, out, _ = env.run("verify-lossless", "--baseline", "HEAD", "--write")
    assert code == 1 and "missing: **1** → FAIL" in out and "DEVLOOP" in out
    data = json.loads(env.read("archive/LOSSLESS.json"))
    assert data["result"] == "FAIL" and data["missing"] == 1 and data["baseline_commit"]
    assert env.run("verify-lossless", "--baseline", "nope")[0] == 2


def test_archive_keeps_first_bullet_and_pointer_is_its_own_block(git_env):
    # Real tracker §6 shape: bullets without blank lines; the newest one stays, the rest move.
    env = git_env
    env.write("tracker.md", "# T\n\n## 6. Status log\n\n- **2026-10-20 — Phase 47** KEEP-47.\n"
                            "- **2026-10-15 — Phase 46** MOVE-46.\n- **2026-10-13 — Phase 45** MOVE-45.\n")
    git(env.tracker.parent, "commit", "-qam", "bullet log")
    plan = env.root / "plan.toml"
    plan.write_text(PLAN.replace("start = '^## 6\\. Status log'", "start = '^- \\*\\*2026-10-20 — Phase 47'"))
    code, out, _ = env.run("archive", "--plan", str(plan), "--step", "1", "--apply")
    assert code == 0 and "| 1 | `tracker.md` | L6–L7 |" in out, out
    tr = env.read("tracker.md")
    assert "KEEP-47.\n\n> 📦 Moved verbatim to " in tr and "MOVE-4" not in tr and tr.endswith("`progress/`.\n")
    assert "(already applied)" in env.run("archive", "--plan", str(plan), "--step", "1")[1]
    code, out, _ = env.run("verify-lossless", "--baseline", "HEAD")
    assert code == 0 and "missing: **0** → PASS" in out, out


def test_verify_lossless_marker_insertion_is_lossless(git_env):
    env = git_env
    _strip_markers(env)
    root = env.tracker.parent
    git(root, "commit", "-qam", "unmarked baseline")
    env.write("context/tags/lesson.toml", "")
    env.run("mark")
    code, out, _ = env.run("verify-lossless", "--baseline", "HEAD")
    assert code == 0 and "PASS" in out


def test_verify_lossless_reports_active_duplicates(git_env):
    env = git_env
    env.write("context/dup.md", "# x\n\nRun the tests before you commit. DEVLOOP.\n")
    code, out, _ = env.run("verify-lossless", "--baseline", "HEAD")
    assert code == 0 and "| 2 | bible/05-dev-loop-and-release.md:3, context/dup.md:3 |" in out


def test_propose_tags_writes_candidates(env):
    out_dir = env.root / "proposals"
    code, out, err = env.run("propose-tags", "--out-dir", str(out_dir))
    assert code == 0, err
    adr = tomllib.loads((out_dir / "adr.proposed.toml").read_text())
    assert set(adr) == set(env.corpus().adr_ids)
    assert "chat" in adr["ADR-031"]["areas"]
    assert adr["ADR-031"]["rule"].startswith("Chat is read-only.")
    assert adr["ADR-033"]["amends"] == ["ADR-031"] and adr["ADR-031"]["amended_by"] == ["ADR-033"]
    assert adr["ADR-031"]["confidence"] in {"high", "medium", "low"} and adr["ADR-031"]["evidence"]
    assert adr["ADR-031"]["reviewed_fp"] == env.corpus().adr_fp("ADR-031")
    les = tomllib.loads((out_dir / "lesson.proposed.toml").read_text())
    assert set(les) == {"L-001", "L-002", "L-003", "L-004", "L-005"} and les["L-004"]["phase"] == "36"
    cm = tomllib.loads((out_dir / "codemap.proposed.toml").read_text())
    assert cm["genesis/genesis/  db/"]["areas"][0] == "db"
    assert "kb-sync" in cm["Phase 45 — Incremental Delta Sync (genesis v0.76.0)"]["areas"]
    assert f"| adr.proposed.toml | {len(adr)} |" in out
    assert not (env.tracker / "context/tags/adr.proposed.toml").exists()
