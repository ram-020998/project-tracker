"""Shared fixtures: a miniature tracker (copied from fixtures/tracker) + a miniature repos tree, per test."""
from __future__ import annotations

import contextlib
import io
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))

from genesis_ctx.cli import main  # noqa: E402

FIXTURES = Path(__file__).parent / "fixtures"

# Files of the baseline mandatory corpus that the fixture tracker does not ship as static files.
EXTRA_CORPUS = {
    "bible/00-onboarding-and-overview.md": "# Overview (fixture)\n\nGenesis is a local workflow platform. OVERVIEW.\n",
    "bible/01-current-state.md": "# Current state (fixture)\n\n- genesis v0.77.0 shipped. CURRENT-01.\n",
    "bible/05-dev-loop-and-release.md": "# Dev loop (fixture)\n\nRun the tests before you commit. DEVLOOP.\n",
    "reference/coding-standards.md": "# Coding standards (fixture)\n\nType hints everywhere. STANDARDS.\n",
}

REPO_FILES = [
    "genesis/genesis/chat/manager.py",
    "genesis/genesis/chat/__pycache__/manager.cpython-313.pyc",
    "genesis/genesis/api/app.py",
    "genesis/genesis/db/runner.py",
    "genesis/genesis/db/migrations/m0001_baseline.py",
    "genesis/genesis/kb/features.py",
    "genesis/genesis/kb/stories.py",
    "genesis/genesis/kb/store.py",
    "genesis/genesis/kb/boards.py",
    "genesis-core/genesis_core/types.py",
    "genesis-core/genesis_core/nodes/agent.py",
    "kiro-agent-sdk/src/kiro_agent_sdk/client.py",
]


def git(cwd: Path, *args: str) -> str:
    r = subprocess.run(["git", "-C", str(cwd), "-c", "user.name=t", "-c", "user.email=t@t", *args],
                       capture_output=True, text=True, check=True)
    return r.stdout.strip()


def git_init(path: Path) -> None:
    git(path, "init", "-q", "-b", "main")
    git(path, "add", "-A")
    git(path, "commit", "-q", "-m", "baseline")


@dataclass
class Env:
    root: Path
    tracker: Path
    repos: Path

    def run(self, *args: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(["--tracker", str(self.tracker), "--repos", str(self.repos), *args])
        return code, out.getvalue(), err.getvalue()

    def read(self, rel: str) -> str:
        return (self.tracker / rel).read_text(encoding="utf-8")

    def write(self, rel: str, text: str) -> None:
        p = self.tracker / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")

    def edit(self, rel: str, old: str, new: str) -> None:
        text = self.read(rel)
        assert old in text, f"{old!r} not in {rel}"
        self.write(rel, text.replace(old, new, 1))

    def corpus(self):
        from genesis_ctx.config import Ctx
        from genesis_ctx.model import Corpus
        return Corpus(Ctx(self.tracker, self.repos))


@pytest.fixture
def env(tmp_path: Path) -> Env:
    tracker = tmp_path / "pt" / "genesis"
    shutil.copytree(FIXTURES / "tracker", tracker)
    for rel, text in EXTRA_CORPUS.items():
        (tracker / rel).write_text(text, encoding="utf-8")
    repos = tmp_path / "repos"
    for rel in REPO_FILES:
        p = repos / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(f"# {rel}\n", encoding="utf-8")
    e = Env(tmp_path, tracker, repos)
    code, out, err = e.run("index")
    assert code == 0, err
    return e


@pytest.fixture
def git_env(env: Env) -> Env:
    """env with project-tracker (the parent of genesis/) committed as a git repo — the baseline."""
    git_init(env.tracker.parent)
    return env
