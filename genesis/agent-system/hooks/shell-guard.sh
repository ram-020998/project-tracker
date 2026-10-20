#!/usr/bin/env bash
# shell-guard.sh — PreToolUse hook on the `shell` tool (Phase 47, 47-09 fix B1/M1).
#
# A hard backstop that holds EVEN under --trust-all-tools (a PreToolUse exit 2 blocks the tool no matter
# what the permission rules say). It refuses, with a clear stderr message:
#   (a) any git invocation whose subcommand is `push` or `tag` — regardless of an absolute path
#       (`/usr/bin/git`), an `env`/`command`/`exec`/`sudo` or `VAR=…` prefix, a `-C <dir>`, a chain
#       (`&& ; |`) or an `sh -c "…"` wrapper. genesis-release is exempt (it passes --allow-push-tag;
#       its push/tag are gated to "ask" in the profile).
#   (b) a shell WRITE — output redirection (`>`/`>>`/`2>`/`&>`), `tee`, `cp`, `mv`, `rm`, `sed -i`,
#       `dd of=` — whose target resolves OUTSIDE the agent's write roots (passed per agent at install
#       as --write-root <dir>…). This closes the `cat x > /any/path` hole left when the broad
#       `cat */grep */ls */find *` allow rules were removed.
#
# Usage (rendered into each profile's hook command): shell-guard.sh [--allow-push-tag] --write-root R …
# Kiro CLI 3 feeds the hook event JSON on stdin (tool_input.command). Fails OPEN (exit 0) only when the
# payload cannot be read — the removed allow rules and the no-trust "ask" gate are the other backstops.
set -uo pipefail

py="${GENESIS_CTX_PYTHON:-}"
if [[ -z "$py" ]]; then
  for c in python3 python3.14 python3.13 python3.12 python3.11; do
    command -v "$c" >/dev/null 2>&1 && { py="$c"; break; }
  done
fi
[[ -z "$py" ]] && exit 0

payload="$(cat 2>/dev/null || true)"
GENESIS_HOOK_PAYLOAD="$payload" GENESIS_GUARD_ARGS="$*" exec "$py" - <<'PY'
import json, os, re, shlex, sys

argv = shlex.split(os.environ.get("GENESIS_GUARD_ARGS", ""))
allow_push_tag = "--allow-push-tag" in argv
roots = []
for i, a in enumerate(argv):
    if a == "--write-root" and i + 1 < len(argv):
        r = re.sub(r"/\*+$", "", argv[i + 1]).rstrip("/")
        roots.append(r or "/")

try:
    e = json.loads(os.environ.get("GENESIS_HOOK_PAYLOAD", "") or "{}")
except Exception:
    sys.exit(0)
ti = e.get("tool_input") or {}
raw = ti.get("command")
if isinstance(raw, list):
    raw = " ".join(str(x) for x in raw)
raw = str(raw if raw is not None else (ti.get("cmd") or ""))
if not raw.strip():
    sys.exit(0)
start_cwd = str(ti.get("cwd") or e.get("cwd") or "")

PREFIX = ("env", "command", "exec", "nice", "nohup", "time", "sudo", "builtin", "-", "then", "do", "!", "{")
SHELLS = ("sh", "bash", "zsh", "dash")
GITSUB = {"push", "tag"}


def block(msg):
    sys.stderr.write("genesis shell-guard: " + msg + "\n")
    sys.exit(2)


def segments(text):
    return re.split(r"&&|\|\||[;\n|]", text)


def tokenize(seg):
    try:
        return shlex.split(seg)
    except ValueError:
        return seg.split()


def strip_prefixes(toks):
    i = 0
    while i < len(toks) and (toks[i] in PREFIX or re.match(r"^[A-Za-z_]\w*=", toks[i])):
        i += 1
    return toks[i:]


def all_commands(text, depth=0):
    """`text` plus any `sh -c '…'` bodies, so a wrapped git push is still seen."""
    cmds = [text]
    if depth > 3:
        return cmds
    for seg in segments(text):
        toks = tokenize(seg)
        for j, t in enumerate(toks):
            if os.path.basename(t) in SHELLS:
                for k in range(j + 1, len(toks) - 1):
                    if toks[k] == "-c":
                        cmds += all_commands(toks[k + 1], depth + 1)
                        break
    return cmds


commands = all_commands(raw)

# (a) git push / tag
if not allow_push_tag:
    for text in commands:
        for seg in segments(text):
            toks = strip_prefixes(tokenize(seg))
            if not toks or os.path.basename(toks[0]) != "git":
                continue
            rest, k = toks[1:], 0
            while k < len(rest):
                tk = rest[k]
                if tk in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
                    k += 2
                    continue
                if tk.startswith("-"):
                    k += 1
                    continue
                if tk in GITSUB:
                    block(f"refusing `git {tk}` — only genesis-release may push or tag "
                          f"(blocked even under --trust-all-tools). Segment: {seg.strip()[:160]}")
                break


# (b) shell writes outside the write roots
def inside(target, cwd):
    if not target:
        return True
    t = target.strip("\"'")
    if not t:
        return True
    if not t.startswith("/"):
        if not cwd:
            return False          # a relative target we cannot resolve → treat as outside (fail closed)
        t = cwd.rstrip("/") + "/" + t
    t = os.path.normpath(t)
    return any(t == r or t.startswith(r.rstrip("/") + "/") for r in roots)


REDIR = re.compile(r"(\d*&?>>?)\s*(\"[^\"]*\"|'[^']*'|[^\s;|&><]+)")

for text in commands:
    cwd = start_cwd
    for seg in segments(text):
        toks = strip_prefixes(tokenize(seg))
        prog = os.path.basename(toks[0]) if toks else ""
        rest = toks[1:]
        if prog == "cd" and rest:
            d = rest[0]
            cwd = d if d.startswith("/") else (os.path.normpath(cwd.rstrip("/") + "/" + d) if cwd else "")
            cwd = cwd if cwd.startswith("/") else ""
            continue
        targets = []
        for m in REDIR.finditer(seg):
            if ">" in m.group(1):
                targets.append(m.group(2))
        if prog == "tee":
            targets += [a for a in rest if not a.startswith("-")]
        elif prog in ("cp", "mv"):
            pos = [a for a in rest if not a.startswith("-")]
            if pos:
                targets.append(pos[-1])
        elif prog == "rm":
            targets += [a for a in rest if not a.startswith("-")]
        elif prog == "dd":
            targets += [a[3:] for a in rest if a.startswith("of=")]
        elif prog == "sed" and any(a == "-i" or a.startswith("-i") for a in rest):
            nonflag = [a for a in rest if not a.startswith("-")]
            targets += nonflag[1:]          # nonflag[0] is the sed script; the rest are files
        for tgt in targets:
            if not inside(tgt, cwd):
                block(f"refusing a shell write to `{tgt}` outside the write roots "
                      f"({', '.join(roots) or 'none'}). Use the write tool or a path under a write root. "
                      f"Segment: {seg.strip()[:160]}")
sys.exit(0)
PY
