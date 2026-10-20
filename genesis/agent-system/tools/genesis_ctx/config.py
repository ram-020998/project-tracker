"""Paths, budgets and the error type shared by every command."""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

DEFAULT_REPOS = Path("/Users/ramaswamy.u/repo-gitlab/ramaswamy.u")
INSTALL_JSON = Path.home() / ".kiro" / "genesis" / "install.json"

# The five Genesis code repos under {{REPOS}} (47-02 §3).
REPO_NAMES = ("genesis", "genesis-core", "genesis-workflows", "kiro-agent-sdk", "genesis-appian-parser")

# Budgets (umbrella Q2), in estimated tokens (chars / 4).
PACK_WARN = 40_000
PACK_FAIL = 80_000
L0_BUDGET = 15_000
STATE_BUDGET = 4_000
RULE_MAX_CHARS = 220

# The baseline mandatory corpus (47-01 §2.1), relative to project-tracker/genesis/.
MANDATORY_CORPUS = (
    "tracker.md",
    "reference/decision-log.md",
    "bible/08-roadmap-and-backlog.md",
    "bible/06-hard-won-lessons.md",
    "bible/03-codebase-map.md",
    "bible/04-adrs-and-constraints.md",
    "bible/01-current-state.md",
    "AGENT_ONBOARDING.md",
    "bible/00-onboarding-and-overview.md",
    "reference/coding-standards.md",
    "bible/05-dev-loop-and-release.md",
    "bible/02-architecture.md",
    "bible/07-working-on-tasks-and-agreements.md",
)

# L0 composition (47-02 §6), in load order.
L0_FILES = (
    "context/L0-core.md",
    "bible/02-architecture.md",
    "bible/07-working-on-tasks-and-agreements.md",
    "context/_generated/adr-digest.md",
    "context/_generated/lesson-digest.md",
    "context/_generated/area-catalog.md",
    "context/state/current.md",
)


class CtxError(Exception):
    """A usage or configuration error (exit code 2)."""


def tokens(text: str) -> int:
    """Token estimate used for every budget: characters / 4, rounded up."""
    return (len(text) + 3) // 4


def default_tracker() -> Path:
    # .../genesis/agent-system/tools/genesis_ctx/config.py -> .../genesis
    return Path(__file__).resolve().parents[3]


def default_repos() -> Path:
    try:
        data = json.loads(INSTALL_JSON.read_text(encoding="utf-8"))
        if isinstance(data, dict) and data.get("repos"):
            return Path(data["repos"]).expanduser()
    except (OSError, ValueError):
        pass
    return DEFAULT_REPOS


@dataclass(frozen=True)
class Ctx:
    tracker: Path
    repos: Path

    def t(self, rel: str) -> Path:
        """A path relative to project-tracker/genesis/."""
        return self.tracker / rel

    @property
    def decision_log(self) -> Path:
        return self.t("reference/decision-log.md")

    @property
    def bible03(self) -> Path:
        return self.t("bible/03-codebase-map.md")

    @property
    def bible04(self) -> Path:
        return self.t("bible/04-adrs-and-constraints.md")

    @property
    def bible06(self) -> Path:
        return self.t("bible/06-hard-won-lessons.md")

    @property
    def context(self) -> Path:
        return self.t("context")

    @property
    def areas_file(self) -> Path:
        return self.t("context/areas.toml")

    @property
    def tags_dir(self) -> Path:
        return self.t("context/tags")

    @property
    def generated_dir(self) -> Path:
        return self.t("context/_generated")

    @property
    def packs_dir(self) -> Path:
        return self.t("context/.packs")

    @property
    def state_file(self) -> Path:
        return self.t("context/state/current.md")

    @property
    def specs_dir(self) -> Path:
        return self.t("specs")

    @property
    def archive_dir(self) -> Path:
        return self.t("archive")

    def rel(self, p: Path) -> str:
        """Display a path relative to the tracker (or the repos root) when possible."""
        p = Path(p)
        for base, prefix in ((self.tracker, ""), (self.repos, "")):
            try:
                return prefix + str(p.resolve().relative_to(base.resolve()))
            except ValueError:
                continue
        return str(p)

    def inside_tracker(self, p: Path) -> bool:
        try:
            Path(p).resolve().relative_to(self.tracker.resolve())
            return True
        except ValueError:
            return False


def read(p: Path) -> str:
    try:
        return Path(p).read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""
