"""47-07 installer tests: a temp HOME, a miniature agent-system source, a fake kiro-cli."""
from __future__ import annotations

import json
import os
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

import pytest

INSTALLER = Path(__file__).resolve().parents[1] / "tools" / "installer"
REAL_SOURCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(INSTALLER))

import genesis_installer as gi  # noqa: E402

PROFILE = {
    "name": "genesis-alpha",
    "description": "test agent",
    "model": "claude-test",
    "tools": ["read", "write", "shell"],
    "resources": ["file://{{TRACKER}}/context/L0-core.md", "skill://{{GENESIS_HOME}}/skills/genesis-one/SKILL.md"],
    "permissions": {"rules": [
        {"capability": "fs_write", "match": ["{{REPOS}}/**"], "effect": "allow"},
        {"capability": "shell", "match": ["{{GENESIS_HOME}}/bin/genesis-ctx *"], "effect": "allow"},
        {"capability": "shell", "match": ["git push*"], "effect": "deny"},
    ]},
    "toolsSettings": {"subagent": {"availableAgents": ["genesis-beta"], "trustedAgents": []}},
    "hooks": [
        {"name": "status", "trigger": "SessionStart",
         "action": {"type": "command", "command": "{{GENESIS_HOME}}/bin/genesis-ctx status --brief"}},
        {"name": "guard", "trigger": "PreToolUse", "matcher": "read",
         "action": {"type": "command", "command": "{{GENESIS_HOME}}/hooks/guard.sh"}},
    ],
    "prompt": "Run `{{GENESIS_HOME}}/bin/genesis-ctx pack <id>`. Skills: `{{GENESIS_HOME}}/skills/genesis-one/SKILL.md`.",
}

FAKE_KIRO = """#!/usr/bin/env bash
case "$1" in
  --version) echo "kiro-cli 2.32.0" ;;
  --help-all) echo "      --v3   Launch the next generation Kiro agent" ;;
  settings) echo "error: No value associated with chat.agentEngine" >&2; exit 1 ;;
esac
"""


@dataclass
class Inst:
    root: Path
    home: Path
    tracker: Path
    source: Path
    repos: Path

    @property
    def ghome(self) -> Path:
        return self.home / ".kiro" / "genesis"

    @property
    def agents(self) -> Path:
        return self.home / ".kiro" / "agents"

    def run(self, *args: str, capsys=None) -> tuple[int, str]:
        rc = gi.main(["--source", str(self.source), *args])
        out = ""
        if capsys is not None:
            c = capsys.readouterr()
            out = c.out + c.err
        return rc, out

    def write(self, rel: str, text: str, mode: int | None = None) -> Path:
        p = self.source / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        if mode is not None:
            os.chmod(p, mode)
        return p

    def profile(self, name: str, **over) -> Path:
        prof = json.loads(json.dumps(PROFILE))
        prof["name"] = name
        prof.update(over)
        return self.write(f"agents/{name}.json", json.dumps(prof, indent=2) + "\n")

    def manifest(self) -> dict:
        return json.loads((self.ghome / "install.json").read_text())

    def backups(self) -> list[Path]:
        b = self.ghome / "backups"
        return sorted(p for p in b.rglob("*") if p.is_file()) if b.is_dir() else []


@pytest.fixture
def inst(tmp_path: Path, monkeypatch) -> Inst:
    home = tmp_path / "home"
    (home / ".kiro" / "agents").mkdir(parents=True)
    monkeypatch.setenv("HOME", str(home))
    tracker = tmp_path / "tracker"
    source = tracker / "agent-system"
    (source / "tools").mkdir(parents=True)
    (source / "tools" / "genesis-ctx").write_text("#!/usr/bin/env bash\n")
    (tracker / "context").mkdir()
    (tracker / "context" / "L0-core.md").write_text("# L0\n")
    repos = tmp_path / "repos"
    for n in gi.REPO_NAMES:
        (repos / n).mkdir(parents=True)
    kiro = tmp_path / "bin" / "kiro-cli"
    kiro.parent.mkdir()
    kiro.write_text(FAKE_KIRO)
    os.chmod(kiro, 0o755)
    monkeypatch.setenv("GENESIS_KIRO_CLI", str(kiro))
    i = Inst(tmp_path, home, tracker, source, repos)
    i.write("install.conf", f"TRACKER={tracker}   # comment\nREPOS={repos}\nMODEL=\n")
    i.profile("genesis-alpha")
    i.profile("genesis-beta", toolsSettings={})
    i.write("skills/genesis-one/SKILL.md", "---\nname: genesis-one\ndescription: does one thing\n---\n"
            "Use `{{GENESIS_HOME}}/bin/genesis-ctx area x`; docs in {{TRACKER}}/bible.\n")
    i.write("skills/genesis-one/references/template.md", "template for {{REPOS}}\n")
    i.write("hooks/guard.sh", "#!/usr/bin/env bash\nexit 0\n", 0o644)
    return i


def _all_installed(i: Inst) -> list[Path]:
    return [Path(p) for p in i.manifest()["files"]]


# ── fresh install / render ─────────────────────────────────────────────────────────────────────────────────────


def test_fresh_install_writes_everything_with_manifest_and_modes(inst, capsys):
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 0, out
    assert "6 added" in out and "export PATH=" in out
    files = _all_installed(inst)
    assert inst.agents / "genesis-alpha.json" in files
    assert inst.ghome / "skills" / "genesis-one" / "references" / "template.md" in files
    assert not (inst.home / ".kiro" / "skills").exists()  # outside the default skill path
    for p in files:
        meta = inst.manifest()["files"][str(p)]
        assert gi.sha256(p.read_bytes()) == meta["sha256"]
    assert os.stat(inst.ghome / "hooks" / "guard.sh").st_mode & 0o777 == 0o755
    assert os.stat(inst.ghome / "bin" / "genesis-ctx").st_mode & 0o777 == 0o755
    m = inst.manifest()
    assert m["repos"] == str(inst.repos) and m["values"]["TRACKER"] == str(inst.tracker)


def test_render_leaves_no_placeholders_and_uses_absolute_paths(inst, capsys):
    assert inst.run("install", capsys=capsys)[0] == 0
    for p in _all_installed(inst):
        text = p.read_text()
        assert not gi.PLACEHOLDER.search(text), p
    prof = json.loads((inst.agents / "genesis-alpha.json").read_text())
    assert prof["resources"][1] == f"skill://{inst.ghome}/skills/genesis-one/SKILL.md"
    assert prof["model"] == "claude-test"  # MODEL empty → the profile's own value is kept
    assert f'exec "{inst.tracker}/agent-system/tools/genesis-ctx"' in (inst.ghome / "bin" / "genesis-ctx").read_text()
    assert str(inst.repos) in (inst.ghome / "skills/genesis-one/references/template.md").read_text()


def test_model_in_conf_overrides_profile_model(inst, capsys):
    inst.write("install.conf", f"TRACKER={inst.tracker}\nREPOS={inst.repos}\nMODEL=other-model\n")
    assert inst.run("install", capsys=capsys)[0] == 0
    assert json.loads((inst.agents / "genesis-beta.json").read_text())["model"] == "other-model"


def test_dry_run_writes_nothing(inst, capsys):
    rc, out = inst.run("install", "--dry-run", capsys=capsys)
    assert rc == 0 and "Dry run — nothing written." in out and "+ ~/.kiro/agents/genesis-alpha.json" in out
    assert not inst.ghome.exists()
    assert list(inst.agents.iterdir()) == []


def test_reinstall_is_idempotent(inst, capsys):
    assert inst.run("install", capsys=capsys)[0] == 0
    before = (inst.ghome / "install.json").read_text()
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 0 and "up to date" in out and "6 unchanged" in out
    assert (inst.ghome / "install.json").read_text() == before
    assert inst.backups() == []


# ── update ─────────────────────────────────────────────────────────────────────────────────────────────────────


def test_update_edited_agent_is_one_changed_file_with_backup_and_diff(inst, capsys):
    assert inst.run("install", capsys=capsys)[0] == 0
    old = (inst.agents / "genesis-alpha.json").read_text()
    inst.profile("genesis-alpha", prompt="A new role prompt. `{{GENESIS_HOME}}/skills/genesis-one/SKILL.md`")
    rc, out = inst.run("update", "--dry-run", capsys=capsys)
    assert rc == 0 and "0 added · 1 changed · 0 removed · 5 unchanged" in out
    assert '+  "prompt": "A new role prompt.' in out  # unified diff in the dry run
    assert (inst.agents / "genesis-alpha.json").read_text() == old
    rc, out = inst.run("update", capsys=capsys)
    assert rc == 0
    assert "A new role prompt." in (inst.agents / "genesis-alpha.json").read_text()
    [b] = inst.backups()
    assert b.name == "genesis-alpha.json" and b.read_text() == old


def test_update_new_skill_is_added(inst, capsys):
    assert inst.run("install", capsys=capsys)[0] == 0
    inst.write("skills/genesis-two/SKILL.md", "---\nname: genesis-two\ndescription: two\n---\nbody\n")
    rc, out = inst.run("update", capsys=capsys)
    assert rc == 0 and "1 added · 0 changed · 0 removed" in out
    assert (inst.ghome / "skills/genesis-two/SKILL.md").is_file()
    assert inst.backups() == []


def test_update_deleted_hook_is_removed_and_backed_up(inst, capsys):
    inst.write("hooks/extra.sh", "#!/usr/bin/env bash\necho extra\n")
    assert inst.run("install", capsys=capsys)[0] == 0
    (inst.source / "hooks" / "extra.sh").unlink()
    rc, out = inst.run("update", capsys=capsys)
    assert rc == 0 and "0 added · 0 changed · 1 removed" in out
    assert not (inst.ghome / "hooks" / "extra.sh").exists()
    assert [b.name for b in inst.backups()] == ["extra.sh"]
    assert str(inst.ghome / "hooks" / "extra.sh") not in inst.manifest()["files"]


def test_update_without_install_refuses(inst, capsys):
    rc, out = inst.run("update", capsys=capsys)
    assert rc == 1 and "run install.sh first" in out


def test_local_edit_of_installed_file_is_backed_up_on_update(inst, capsys):
    assert inst.run("install", capsys=capsys)[0] == 0
    hook = inst.ghome / "hooks" / "guard.sh"
    hook.write_text("#!/usr/bin/env bash\n# my local hack\n")
    rc, out = inst.run("update", capsys=capsys)
    assert rc == 0 and "edited after the last install" in out
    assert "my local hack" not in hook.read_text()
    assert "my local hack" in inst.backups()[0].read_text()


# ── ownership ──────────────────────────────────────────────────────────────────────────────────────────────────


def test_foreign_file_at_a_destination_is_refused(inst, capsys):
    mine = inst.agents / "genesis-alpha.json"
    mine.write_text('{"name": "genesis-alpha", "mine": true}\n')
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "Refusing" in out and "FOREIGN" in out
    assert json.loads(mine.read_text())["mine"] is True
    assert not inst.ghome.exists()


def test_foreign_same_name_agent_in_other_format_is_refused(inst, capsys):
    (inst.agents / "genesis-beta.md").write_text("---\nname: genesis-beta\n---\nmine\n")
    (inst.agents / "genesis-mine.json").write_text("{}\n")  # different name: left alone, warned
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "genesis-beta.md" in out and "genesis-mine.json is a genesis-* agent" in out


def test_force_backs_up_foreign_files_then_installs(inst, capsys):
    (inst.agents / "genesis-alpha.json").write_text('{"mine": true}\n')
    (inst.agents / "genesis-beta.md").write_text("mine\n")
    rc, out = inst.run("install", "--force", capsys=capsys)
    assert rc == 0, out
    assert json.loads((inst.agents / "genesis-alpha.json").read_text())["name"] == "genesis-alpha"
    assert not (inst.agents / "genesis-beta.md").exists()
    assert sorted(b.name for b in inst.backups()) == ["genesis-alpha.json", "genesis-beta.md"]


def test_identical_foreign_file_is_adopted(inst, capsys):
    assert inst.run("install", capsys=capsys)[0] == 0
    (inst.ghome / "install.json").unlink()  # manifest lost; files still identical
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 0 and "adopted" in out and (inst.ghome / "install.json").is_file()


def test_uninstall_removes_only_manifest_files(inst, capsys):
    assert inst.run("install", capsys=capsys)[0] == 0
    other = inst.agents / "someone-else.json"
    other.write_text("{}\n")
    note = inst.ghome / "skills" / "genesis-one" / "my-notes.txt"
    note.write_text("keep me\n")
    rc, out = inst.run("uninstall", "--dry-run", capsys=capsys)
    assert rc == 0 and (inst.agents / "genesis-alpha.json").exists()
    rc, out = inst.run("uninstall", capsys=capsys)
    assert rc == 0
    assert other.exists() and note.read_text() == "keep me\n"
    assert not (inst.agents / "genesis-alpha.json").exists()
    assert not (inst.ghome / "install.json").exists() and not (inst.ghome / "hooks").exists()
    assert (inst.ghome / "backups").is_dir()


# ── validation + preflight ─────────────────────────────────────────────────────────────────────────────────────


def _assert_invalid(inst, capsys, needle: str):
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "Validation: FAILED" in out and needle in out, out
    assert not inst.ghome.exists() and list(inst.agents.iterdir()) == []


def test_validation_catches_missing_resource_path(inst, capsys):
    inst.profile("genesis-beta", toolsSettings={}, resources=["file://{{TRACKER}}/context/nope.md"])
    _assert_invalid(inst, capsys, "does not exist")


def test_validation_catches_unrendered_placeholder_and_unknown_skill(inst, capsys):
    inst.write("skills/genesis-one/references/template.md", "{{NOT_A_KEY}}\n")
    inst.profile("genesis-beta", toolsSettings={},
                 resources=["skill://{{GENESIS_HOME}}/skills/genesis-missing/SKILL.md"])
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "{{NOT_A_KEY}}" in out and "not part of this installation" in out


def test_validation_rejects_bare_write_capable_shell_allow(inst, capsys):
    # 47-09 B1: re-introducing a `cat */node *` shell allow (a blanket for a write-capable command) is refused.
    prof = json.loads(json.dumps(PROFILE))
    prof["permissions"]["rules"].append({"capability": "shell", "match": ["cat *"], "effect": "allow"})
    inst.profile("genesis-beta", toolsSettings={}, permissions=prof["permissions"])
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "blanket for a write-capable command" in out and "cat *" in out


def test_validation_catches_bad_permissions_and_tools(inst, capsys):
    prof = json.loads(json.dumps(PROFILE))
    prof["permissions"]["rules"].append({"capability": "execute_bash", "match": ["x"], "effect": "permit"})
    inst.profile("genesis-beta", toolsSettings={}, permissions=prof["permissions"], tools=["read", "telepathy"])
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1
    assert "unknown capability 'execute_bash'" in out and "'permit'" in out and "unknown tool 'telepathy'" in out


def test_validation_catches_missing_hook_and_bad_skill_frontmatter(inst, capsys):
    (inst.source / "hooks" / "guard.sh").unlink()  # still referenced by genesis-alpha
    inst.write("skills/genesis-one/SKILL.md", "---\nname: genesis-one\n---\nno description\n")
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "guard.sh' does not exist" in out and "description missing" in out


def test_validation_requires_each_skill_named_by_path_in_prompt(inst, capsys):
    inst.profile("genesis-beta", toolsSettings={}, prompt="No skill paths here.")
    _assert_invalid(inst, capsys, "skill genesis-one is not named by path in the prompt")


def test_validation_catches_unknown_subagent_and_missing_permissions(inst, capsys):
    inst.profile("genesis-beta", toolsSettings={"subagent": {"availableAgents": ["genesis-ghost"]}}, permissions={})
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "unknown agent 'genesis-ghost'" in out and "permissions.rules is required" in out


def test_preflight_fails_on_missing_repo_and_notes_v3_engine(inst, capsys):
    rc, out = inst.run("install", "--dry-run", capsys=capsys)
    assert "kiro-cli 2.32.0 + V3 engine (launch with `kiro-cli --v3" in out
    shutil.rmtree(inst.repos / "genesis-core")
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 1 and "missing: genesis-core" in out and not inst.ghome.exists()


def test_preflight_warns_without_v3_engine(inst, capsys, monkeypatch):
    kiro = inst.root / "bin" / "kiro-old"
    kiro.write_text('#!/usr/bin/env bash\n[[ "$1" == --version ]] && echo "kiro-cli 2.1.0"\nexit 0\n')
    os.chmod(kiro, 0o755)
    monkeypatch.setenv("GENESIS_KIRO_CLI", str(kiro))
    rc, out = inst.run("install", "--dry-run", capsys=capsys)
    assert rc == 0 and "no V3 engine" in out


def test_conf_rejects_unknown_key_and_relative_path(inst, capsys):
    inst.write("install.conf", "TRAKCER=/x\n")
    assert inst.run("install", capsys=capsys)[0] == 2
    inst.write("install.conf", "REPOS=relative/path\n")
    rc, out = inst.run("install", capsys=capsys)
    assert rc == 2 and "absolute" in out


# ── the shipped sources ────────────────────────────────────────────────────────────────────────────────────────


def test_real_agent_system_renders_and_validates(tmp_path, monkeypatch):
    """The committed agents/skills/hooks pass the installer's validation (resources stubbed in a temp tracker)."""
    home = tmp_path / "home"
    (home / ".kiro" / "agents").mkdir(parents=True)
    monkeypatch.setenv("HOME", str(home))
    tracker = tmp_path / "tracker"
    src = tracker / "agent-system"
    for sub in ("agents", "skills", "hooks"):
        shutil.copytree(REAL_SOURCE / sub, src / sub, ignore=shutil.ignore_patterns("__pycache__", ".DS_Store"))
    cfg = gi.Config(source=src, tracker=tracker, repos=tmp_path / "repos", home=home / ".kiro" / "genesis",
                    agents_dir=home / ".kiro" / "agents", model="")
    desired = gi.build_desired(cfg)
    for item in desired.values():  # stub every file:// resource the profiles reference
        if item.source.startswith("agents/"):
            for r in json.loads(item.data)["resources"]:
                if r.startswith("file://"):
                    p = Path(r[len("file://"):])
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_text("stub\n")
    assert gi.validate(cfg, desired) == []
    names = sorted(p.stem for p in desired if p.parent == cfg.agents_dir)
    assert names == ["genesis-dev", "genesis-docs", "genesis-release", "genesis-review", "genesis-spec"]
    assert len({p.parts[-2] for p in desired if p.name == "SKILL.md"}) == 10
