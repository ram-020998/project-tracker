"""50-04 (Phase 50, D12/D16): the monorepo routing.

The libraries moved into genesis/packages/; the REAL context/areas.toml must route their files to the same areas as
before, an area glob that matches nothing must fail lint, and the repo lists must be the monorepo set.
"""
from __future__ import annotations

import json
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
    assert list(json.loads(out)["repos"]) == ["genesis", "genesis-workflows", "project-tracker"]
    _, brief, _ = env.run("status", "--brief")
    rows = [line.split()[0] for line in brief.strip().split("\n")[1:-1]]
    assert rows == ["genesis", "genesis-workflows", "project-tracker"]


def test_installer_and_genesis_ctx_share_the_repo_list():
    assert gi.REPO_NAMES == config.REPO_NAMES == ("genesis", "genesis-workflows")
