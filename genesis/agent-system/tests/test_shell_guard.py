"""shell-guard.sh PreToolUse hook (47-09 fix B1/M1). Exit 2 = blocked, 0 = allowed."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

HOOK = Path(__file__).resolve().parents[1] / "hooks" / "shell-guard.sh"
WR = ["--write-root", "/tmp", "--write-root", "/work"]


def guard(cmd, *args, cwd="/home/user"):
    payload = json.dumps({"tool_input": {"command": cmd, "cwd": cwd}})
    r = subprocess.run(["bash", str(HOOK), *args], input=payload, capture_output=True, text=True)
    return r.returncode, r.stderr


@pytest.mark.parametrize("cmd", [
    "cd /work && git push origin HEAD:p",          # chained
    "git -C /work push origin HEAD:p",             # -C <dir>
    "git -C /work tag probe",                      # tag
    "/usr/bin/git -C /work push origin HEAD:p",    # absolute path (M1 bypass)
    "env git -C /work push origin HEAD:p",         # env prefix (M1 bypass)
    "VAR=1 git push",                              # VAR= prefix
    'sh -c "git push origin HEAD"',                # nested shell
    "git push --help",                             # over-block, harmless
])
def test_git_push_tag_blocked_for_non_release(cmd):
    assert guard(cmd, *WR)[0] == 2


@pytest.mark.parametrize("cmd", [
    "git status",
    "git log --oneline",
    "git diff HEAD~1",
    'git commit -m "add a push button and tag input"',   # push/tag only in the message, not a subcommand
    "git log > /tmp/out.txt",                             # redirect target named tag/push is not the subcommand
    "git -C /work log --oneline v1..v2",                  # read-only git against a code repo (m8 follow-up)
    "git -C /work describe --tags",
])
def test_benign_git_allowed(cmd):
    assert guard(cmd, *WR)[0] == 0


def test_git_push_allowed_for_release():
    assert guard("git push origin HEAD", "--allow-push-tag", *WR)[0] == 0
    assert guard("/usr/bin/git -C /work tag v1", "--allow-push-tag", *WR)[0] == 0


@pytest.mark.parametrize("cmd", [
    "cat /etc/hosts > /home/user/pwned.txt",       # the B1 hole
    "cat x >> /etc/evil",
    "cp /tmp/a /etc/passwd",
    "mv /tmp/a /usr/local/bin/x",
    "tee /etc/cron.d/x",
    "rm /home/user/.bashrc",
    "sed -i 's/a/b/' /etc/hosts",
    "dd of=/dev/sda",
])
def test_shell_write_outside_roots_blocked(cmd):
    assert guard(cmd, *WR)[0] == 2


@pytest.mark.parametrize("cmd", [
    "cat x > /tmp/ok.txt",
    "cp /etc/hosts /tmp/hosts",
    "rm /work/build/app.js",
    "cd /work && echo hi > out.txt",               # relative, resolved against a write-root cwd
    "sed -i 's/a/b/' /work/src/app.py",
    "pytest -q",
    "npm run build",
    "cat /etc/hosts",                               # a plain read is not a write → not blocked
])
def test_shell_write_inside_roots_allowed(cmd):
    assert guard(cmd, *WR)[0] == 0


def test_relative_write_without_cwd_is_blocked():
    # no cwd and a relative target cannot be verified → fail closed
    payload = json.dumps({"tool_input": {"command": "echo x > out.txt"}})
    r = subprocess.run(["bash", str(HOOK), *WR], input=payload, capture_output=True, text=True)
    assert r.returncode == 2


def test_unreadable_payload_fails_open():
    r = subprocess.run(["bash", str(HOOK), *WR], input="not json", capture_output=True, text=True)
    assert r.returncode == 0
    r = subprocess.run(["bash", str(HOOK), *WR], input="", capture_output=True, text=True)
    assert r.returncode == 0
