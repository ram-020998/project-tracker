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


# ── 47-09 M5: quote-aware lexing — the round-2 false positives must pass ────────────────────────────────────
# cwd /home/user is OUTSIDE the write roots, so any mis-read redirect target would be blocked.
@pytest.mark.parametrize("cmd", [
    # the four false positives from the 47-09 round-2 review session
    "ls /nonexistent 2>/dev/null",
    "rm -rf /tmp/x 2>&1",
    "python3 -c \"v=3; print(f'{v:>7}')\"",
    "grep -n '2>/dev/null' /work/hooks/shell-guard.sh",
    # the same idioms in other spellings
    'grep -rn "2>/dev/null" /work/hooks',
    "genesis-ctx lint 2>&1 | tail -3",
    "echo oops >&2",
    "echo oops 1>&2",
    "cmd 3>&1 1>&2 2>&3 3>&-",
    "pytest -q > /dev/null 2>&1",
    "npm run build &>/dev/null",
    "make 2>/dev/stderr",
    "ls >/dev/fd/1",
    "echo x | tee /dev/null",
    'git commit -m "fix: a > b and c >> d"',
    "awk '$3 > 100 { print }' /work/data.txt",
    'echo "a > /etc/x"',
    "echo a \\> /etc/x",                                # escaped: a literal '>' argument
    "[[ $a > $b ]] && echo bigger",
    "(( n > 2 )) && echo many",
    "echo hi # > /etc/x is only a comment",
    "python3 - <<'PY'\nprint(1 > 0)\nopen('/tmp/x.txt', 'w').write('>')\nPY",
    "D=/tmp/out; mkdir -p $D; echo hi > $D/a.txt",
    "for s in a b c; do echo $s > /tmp/$s.txt; done",
    "cat x > ~/../../tmp/y.txt",
])
def test_m5_false_positives_allowed(cmd):
    rc, err = guard(cmd, *WR)
    assert rc == 0, err


# Real out-of-scope writes and push/tag must still block after the lexer change (plus a few M5-adjacent holes).
@pytest.mark.parametrize("cmd", [
    "echo x 2> /etc/err.log",
    "echo x 2>>/etc/err.log",
    "echo x &> /etc/x",
    "echo x &>> /etc/x",
    "echo x >& /etc/x",                                 # `>&word` (not a number) is a file redirect
    "echo x >| /etc/x",
    "echo x >/dev/../etc/x",                            # normalised before the /dev sink allowance
    'echo "quoted text" > /etc/x',
    'echo x > "/etc/x"',
    "echo x>'/etc/x'",
    "echo x > ~/.bashrc",
    "D=/etc; echo x > $D/f",
    "echo x > $GENESIS_UNSET_VAR_FOR_TEST/f",           # unresolvable → fail closed
    "echo x > /tmp/$(date +%s)/../../etc/x",            # substitution in a target → fail closed
    "(cd /tmp); echo x > rel.txt",                      # the subshell cd does not leak out
    "tee >(cat > /etc/x) < /tmp/in",                    # process substitution body
    "echo x | sudo -u root tee /etc/x",
    "rm /dev/null",                                     # sinks are allowed for redirects, not for rm
    "sed -i -e 's/a/b/' -e 's/c/d/' /etc/hosts",
    "cp -t /etc /tmp/a",
])
def test_m5_real_writes_still_blocked(cmd):
    assert guard(cmd, *WR)[0] == 2


@pytest.mark.parametrize("cmd", [
    "echo $(git push origin HEAD)",
    "echo `git push`",
    "if git push; then :; fi",
    "while git push; do :; done",
    "G=/usr/bin/git; $G -C /work push",
    'G=/usr/bin/git; "$G" tag v1',
    "git -c alias.p=push p",
    "timeout 5 git push",
    "sudo -u root git push",
    "env -i git push",
    "bash <<'EOF'\ngit push origin main\nEOF",
    'eval "git push"',
    'bash -lc "git push"',
    "for c in status push; do git $c; done",
])
def test_m5_push_tag_hardening(cmd):
    assert guard(cmd, *WR)[0] == 2


def test_m5_allowed_forms_for_release_and_genesis_ctx():
    assert guard("git push origin HEAD 2>&1 | tail -2", "--allow-push-tag", *WR)[0] == 0
    # the documented one-call retrieval form (m9) passes the guard
    assert guard("/home/u/.kiro/genesis/bin/genesis-ctx adr ADR-021 ADR-032 ADR-035", *WR)[0] == 0


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
