"""50-04 (Phase 50, D12/D16): the monorepo routing.

The libraries moved into genesis/packages/; the REAL context/areas.toml must route their files to the same areas as
before, an area glob that matches nothing must fail lint, and the repo lists must be the monorepo set.
"""
from __future__ import annotations

import contextlib
import io
import json
import subprocess
import sys
from pathlib import Path

import pytest

from genesis_ctx import config
from genesis_ctx.config import Ctx
from genesis_ctx.model import Corpus

REAL_TRACKER = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "installer"))

import genesis_installer as gi  # noqa: E402


@pytest.fixture
def real(tmp_path):
    """The real area registry; routing is pure glob matching, so the repos root can be empty."""
    return Corpus(Ctx(REAL_TRACKER, tmp_path))


@pytest.mark.parametrize("path, areas", [
    ("genesis/packages/genesis-core/genesis_core/nodes/agent.py", ["core-engine"]),
    ("genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py", ["chat", "sdk-acp"]),
    ("genesis/packages/genesis-appian-parser/genesis_appian_parser/api.py", ["parser"]),
    ("genesis/genesis/cli/main.py", ["distribution"]),                       # D16
    ("genesis/genesis/cli/create_workflow.py", ["workflows-library"]),       # D16
    ("genesis/genesis/cli/test_workflow.py", ["workflows-library"]),         # D16
])
def test_real_areas_route_the_moved_libraries_and_cli(real, path, areas):
    assert real.areas_for_path(path) == areas


@pytest.mark.parametrize("path", [
    "genesis-core/genesis_core/nodes/agent.py",          # the old checkouts route nowhere now
    "kiro-agent-sdk/src/kiro_agent_sdk/client.py",
    "genesis-appian-parser/genesis_appian_parser/api.py",
    "genesis/tests/test_cli_missing_packages.py",        # app tests stay unmapped (D16)
    "genesis/packages/genesis-core/tests/test_core_units.py",
])
def test_real_areas_leave_old_paths_and_tests_unmapped(real, path):
    assert real.areas_for_path(path) == []


def test_real_library_gates_run_from_the_package_dir(real):
    gates = {n: real.areas[n].get("gates", []) for n in ("core-engine", "sdk-acp", "parser")}
    for name, cmds in gates.items():
        assert cmds and all(c.startswith("cd genesis/packages/") and "../../.venv/bin/" in c for c in cmds), name


def test_check_routes_a_moved_library_file(env):
    code, out, _ = env.run("check", "--files", "genesis/packages/genesis-core/genesis_core/nodes/agent.py",
                           "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py", "--json")
    assert code == 0
    d = json.loads(out)
    assert [f["areas"] for f in d["files"]] == [["core-engine"], ["chat"]]


def test_empty_area_glob_fails_lint(env):
    env.edit("context/areas.toml", 'paths    = ["genesis/genesis/kb/store.py"]',
             'paths    = ["genesis/genesis/kb/store.py", "genesis-core/genesis_core/**"]')
    code, out, _ = env.run("lint", "--json")
    findings = json.loads(out)["findings"]
    assert code == 1
    assert [(f["code"], f["level"]) for f in findings if "genesis-core/genesis_core/**" in f["message"]] == \
        [("area-glob-empty", "error")]


def test_status_lists_the_monorepo_repo_set(env):
    code, out, _ = env.run("status", "--json")
    assert code == 0
    assert list(json.loads(out)["repos"]) == ["genesis", "genesis-workflows", "playwright-appian", "project-tracker"]
    _, brief, _ = env.run("status", "--brief")
    rows = [line.split()[0] for line in brief.strip().split("\n")[1:-1]]
    assert rows == ["genesis", "genesis-workflows", "playwright-appian", "project-tracker"]


def test_installer_and_genesis_ctx_share_the_repo_list():
    assert gi.REPO_NAMES == config.REPO_NAMES == ("genesis", "genesis-workflows", "playwright-appian")


# ── 51-02 (D19): playwright-appian joins the agent system ───────────────────────────────────────────────────────

def _git(cwd: Path, *args: str) -> str:
    r = subprocess.run(["git", "-C", str(cwd), "-c", "user.name=t", "-c", "user.email=t@t", *args],
                       capture_output=True, text=True, check=True)
    return r.stdout.strip()


def _repo(path: Path, branch: str, files: dict[str, str]) -> str:
    for rel, text in files.items():
        p = path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    _git(path, "init", "-q", "-b", branch)
    _git(path, "add", "-A")
    _git(path, "commit", "-q", "-m", "baseline")
    return _git(path, "rev-parse", "HEAD")


def test_status_reads_each_repos_own_branch(env):
    _repo(env.repos / "genesis", "master", {"README.md": "g\n"})
    _repo(env.repos / "playwright-appian", "main", {"package.json": "{}\n"})
    _git(env.repos / "playwright-appian", "tag", "v0.2.0")
    code, out, _ = env.run("status", "--json")
    assert code == 0
    repos = json.loads(out)["repos"]
    assert repos["genesis"]["branch"] == "master"
    assert repos["playwright-appian"] == {"present": True, "branch": "main", "tag": "v0.2.0", "dirty": 0,
                                          "ahead": None}
    _, brief, _ = env.run("status", "--brief")
    row = next(line for line in brief.split("\n") if line.startswith("playwright-appian"))
    assert row.split()[1:3] == ["main", "v0.2.0"]


@pytest.mark.parametrize("path", [
    "playwright-appian/src/core/taxonomy.ts",
    "playwright-appian/src/agent/spec-writer.ts",
    "playwright-appian/skills/playwright-appian/SKILL.md",
    "playwright-appian/tests/invariants/taxonomy-only.test.ts",
    "playwright-appian/package.json",
])
def test_real_areas_route_playwright_appian_to_browser_testing(real, path):
    assert real.areas_for_path(path) == ["browser-testing"]


@pytest.mark.parametrize("path", [
    "playwright-appian/planning/DECISIONS.md",     # its design record is a doc, not routed code
    "playwright-appian/node_modules/playwright/index.js",
    "playwright-appian/dist/cli/index.js",
])
def test_real_areas_leave_playwright_appian_non_source_unmapped(real, path):
    assert real.areas_for_path(path) == []


def test_real_browser_testing_gates_and_docs(real):
    a = real.areas["browser-testing"]
    assert a["gates"][0].startswith("cd playwright-appian && npm run lint && npm run typecheck && npm test")
    assert "genesis-playwright-appian-dev" in a["skills"]
    assert "playwright-appian/planning/DECISIONS.md" in a["docs"]


def test_check_repo_playwright_appian_since_routes_taxonomy(tmp_path):
    repos = tmp_path / "repos"
    base = _repo(repos / "playwright-appian", "main", {"src/core/taxonomy.ts": "export const T = {};\n"})
    (repos / "playwright-appian" / "src/core/taxonomy.ts").write_text("export const T = { a: 1 };\n")
    from genesis_ctx.cli import main
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = main(["--tracker", str(REAL_TRACKER), "--repos", str(repos),
                     "check", "--repo", "playwright-appian", "--since", base, "--json"])
    assert code == 0
    d = json.loads(out.getvalue())
    assert d["files"] == [{"path": "playwright-appian/src/core/taxonomy.ts", "areas": ["browser-testing"]}]
    assert any(g["area"] == "browser-testing" and "npm test" in g["command"] for g in d["gates"])


@pytest.mark.parametrize("profile", ["genesis-dev", "genesis-review"])
def test_dev_and_review_may_run_apwt_but_not_bare_npx_apwt(profile):
    prof = json.loads((REAL_TRACKER / "agent-system" / "agents" / f"{profile}.json").read_text(encoding="utf-8"))
    allow = [p for r in prof["permissions"]["rules"] if r["capability"] == "shell" and r["effect"] == "allow"
             for p in r["match"]]
    for pat in ("npx playwright test*", "npx playwright install chromium*", "npx --no-install apwt *",
                "node dist/cli/index.js *"):
        assert pat in allow, pat
    # a bare `npx apwt` installs a missing package from the registry in a non-TTY shell (npm exec assumes --yes)
    assert not any(p.startswith("npx apwt") or p in ("npx *", "node *") for p in allow)
    assert "{{GENESIS_HOME}}/skills/genesis-playwright-appian-dev/SKILL.md" in prof["prompt"]
    assert "skill://{{GENESIS_HOME}}/skills/genesis-playwright-appian-dev/SKILL.md" in prof["resources"]
