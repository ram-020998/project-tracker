#!/usr/bin/env bash
# shell-guard.sh — PreToolUse hook on the `shell` tool (Phase 47, 47-09 fix B1/M1; quote-aware since 47-09 M5).
#
# A hard backstop that holds EVEN under --trust-all-tools (a PreToolUse exit 2 blocks the tool no matter
# what the permission rules say). It refuses, with a clear stderr message:
#   (a) any git invocation whose subcommand is `push` or `tag` — regardless of an absolute path
#       (`/usr/bin/git`, `$G` set earlier in the line), an `env`/`command`/`exec`/`sudo`/`timeout`/`VAR=…`
#       prefix, a `-C <dir>`, a chain (`&& ; |`), `if`/`while`, a `$(…)`/backtick/`<(…)` body, a
#       `sh -c "…"`/`eval`/shell-heredoc wrapper, or a `git -c alias.x=…` alias. genesis-release is exempt
#       (it passes --allow-push-tag; its push/tag are gated to "ask" in the profile).
#   (b) a shell WRITE — output redirection (`>`/`>>`/`>|`/`N>`/`&>`/`>&file`), `tee`, `cp`, `mv`, `rm`,
#       `sed -i`, `dd of=` — whose target resolves OUTSIDE the agent's write roots (passed per agent at
#       install as --write-root <dir>…), or cannot be resolved statically (an unknown `$VAR`, `$(…)`).
#
# The command is lexed like a shell (M5): quotes, escapes and comments are honoured, so a `>` inside a quoted
# string (`grep '2>/dev/null'`, a Python f-string `{v:>7}`, a commit message) is NOT a redirect; fd
# duplications (`2>&1`, `>&2`, `N>&M`, `N>&-`) are not file writes; `/dev/null`, `/dev/stdout`, `/dev/stderr`,
# `/dev/tty`, `/dev/fd/N` are always allowed redirect/tee/cp/dd targets. Variables assigned earlier in the
# line (`D=/tmp/x; … > $D/f`, `for s in a b; do … > /tmp/$s; done`) are resolved; `cd` and `( … )` subshells
# are tracked for relative targets.
#
# Usage (rendered into each profile's hook command): shell-guard.sh [--allow-push-tag] --write-root R …
# Kiro CLI 3 feeds the hook event JSON on stdin (tool_input.command). Fails OPEN (exit 0) only when the
# payload cannot be read — the removed allow rules and the no-trust "ask" gate are the other backstops.
# Not a sandbox: a script FILE run by an interpreter (`bash x.sh`, `python3 x.py`) is not inspected.
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

SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
GITSUB = {"push", "tag"}
GIT_OPT_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env"}
KEYWORDS = {"if", "then", "elif", "else", "do", "while", "until", "!", "{", "}", "-"}
# wrapper -> its options that take a separate value (so `sudo -u root tee /etc/x` still finds `tee`)
WRAPPERS = {
    "env": {"-u", "--unset", "-C", "--chdir", "-S", "--split-string", "-P"},
    "sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-U", "-r", "-t", "-T"},
    "nice": {"-n"}, "nohup": set(), "time": set(), "command": set(), "builtin": set(),
    "exec": {"-a"}, "timeout": {"-s", "--signal", "-k", "--kill-after"}, "stdbuf": {"-i", "-o", "-e"},
}
DEV_SINKS = {"/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"}
READ_REDIRS = {"<", "<&", "<<", "<<-", "<<<"}


def block(msg):
    sys.stderr.write("genesis shell-guard: " + msg + "\n")
    sys.exit(2)


# ── lexer ────────────────────────────────────────────────────────────────────────────────────────────────
class Word:
    """A shell word as parts: lit (quoted/escaped, no expansion) · raw (unquoted) · dq (double-quoted) ·
    dyn (a $(…)/backtick/$((…))/<(…) substitution — its value is unknown)."""
    __slots__ = ("parts",)

    def __init__(self):
        self.parts = []

    def add(self, kind, text):
        if self.parts and self.parts[-1][0] == kind and kind != "dyn":
            self.parts[-1] = (kind, self.parts[-1][1] + text)
        else:
            self.parts.append((kind, text))

    def text(self):
        return "".join(t for _, t in self.parts)

    def is_fd(self):
        if len(self.parts) != 1 or self.parts[0][0] != "raw":
            return False
        t = self.parts[0][1]
        return t.isdigit() or bool(re.fullmatch(r"\{[A-Za-z_]\w*\}", t))


class Cmd:
    __slots__ = ("words", "redirs", "heredocs", "herestrings", "nested")

    def __init__(self):
        self.words, self.redirs, self.heredocs, self.herestrings, self.nested = [], [], [], [], []

    def text(self):
        s = " ".join(w.text() for w in self.words)
        s += "".join(f" {op}{w.text()}" for op, w in self.redirs)
        return s.strip()


def lex(s):
    """Split shell text into a flat list of Cmd objects and '(' / ')' subshell markers."""
    n = len(s)
    out, heredoc_q = [], []
    st = {"cmd": Cmd(), "word": None, "pending": None}

    def w():
        if st["word"] is None:
            st["word"] = Word()
        return st["word"]

    def flush():
        word = st["word"]
        if word is None:
            return
        st["word"] = None
        op, st["pending"] = st["pending"], None
        cmd = st["cmd"]
        if op is None:
            cmd.words.append(word)
        elif op in ("<<", "<<-"):
            heredoc_q.append((cmd, word.text(), op == "<<-"))
        elif op == "<<<":
            cmd.herestrings.append(word)
        else:
            cmd.redirs.append((op, word))

    def end_cmd():
        flush()
        st["pending"] = None
        c = st["cmd"]
        if c.words or c.redirs or c.heredocs or c.herestrings or c.nested:
            out.append(c)
        st["cmd"] = Cmd()

    def match_paren(k):              # s[k] == '(' → index after its matching ')'
        depth, i = 0, k
        while i < n:
            c = s[i]
            if c == "\\":
                i += 2
                continue
            if c == "'":
                j = s.find("'", i + 1)
                i = n if j < 0 else j + 1
                continue
            if c == '"':
                i += 1
                while i < n and s[i] != '"':
                    i += 2 if s[i] == "\\" else 1
                i += 1
                continue
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
        return n

    def backtick_end(k):
        i = k
        while i < n:
            if s[i] == "\\":
                i += 2
                continue
            if s[i] == "`":
                return i
            i += 1
        return n

    def substitution(i):             # at '$(' / '$((' / '`' → (handled, new index)
        if s.startswith("$((", i):
            j = match_paren(i + 1)
            w().add("dyn", s[i:j])
            return j
        if s.startswith("$(", i):
            j = match_paren(i + 1)
            st["cmd"].nested.append(s[i + 2:j - 1])
            w().add("dyn", s[i:j])
            return j
        j = backtick_end(i + 1)      # backtick
        st["cmd"].nested.append(s[i + 1:j])
        w().add("dyn", s[i:j + 1])
        return j + 1

    def double_quoted(i):            # i just after the opening '"'
        w()
        while i < n:
            c = s[i]
            if c == '"':
                return i + 1
            if c == "\\" and i + 1 < n:
                nx = s[i + 1]
                if nx == "\n":
                    i += 2
                    continue
                w().add("lit", nx if nx in '$`"\\' else "\\" + nx)
                i += 2
                continue
            if (c == "$" and s.startswith("$(", i)) or c == "`":
                i = substitution(i)
                continue
            w().add("dq", c)
            i += 1
        return n

    def read_heredocs(i):
        for cmd, delim, strip in heredoc_q:
            lines = []
            while i < n:
                j = s.find("\n", i)
                line, nxt = (s[i:], n) if j < 0 else (s[i:j], j + 1)
                i = nxt
                if (line.lstrip("\t") if strip else line) == delim:
                    break
                lines.append(line)
            cmd.heredocs.append("\n".join(lines))
        heredoc_q.clear()
        return i

    i = 0
    while i < n:
        c = s[i]
        if c in " \t\r":
            flush()
            i += 1
        elif c == "\\":
            if s.startswith("\\\n", i):
                i += 2
            else:
                w().add("lit", s[i + 1:i + 2] or "\\")
                i += 2
        elif c == "'":
            j = s.find("'", i + 1)
            j = n if j < 0 else j
            w().add("lit", s[i + 1:j])
            i = j + 1
        elif c == "$" and s.startswith("$'", i):     # ANSI-C quoting (escapes not decoded: literal enough)
            j = i + 2
            while j < n and s[j] != "'":
                j += 2 if s[j] == "\\" else 1
            w().add("lit", s[i + 2:j])
            i = j + 1
        elif c == '"' or s.startswith('$"', i):
            i = double_quoted(i + (2 if c == "$" else 1))
        elif (c == "$" and s.startswith("$(", i)) or c == "`":
            i = substitution(i)
        elif c in "<>" and s.startswith("(", i + 1) and st["word"] is None:   # process substitution
            j = match_paren(i + 1)
            st["cmd"].nested.append(s[i + 2:j - 1])
            w().add("dyn", s[i:j])
            i = j
        elif c == "#" and st["word"] is None:
            j = s.find("\n", i)
            i = n if j < 0 else j
        elif c == "(" and st["word"] is None:
            if s.startswith("((", i):                   # arithmetic (( … )) — no redirects inside
                end_cmd()
                i = match_paren(i)
            else:
                end_cmd()
                out.append("(")
                i += 1
        elif c == ")":
            end_cmd()
            out.append(")")
            i += 1
        elif c == "&" and s.startswith(">", i + 1):  # &> / &>>
            flush()
            op = "&>>" if s.startswith("&>>", i) else "&>"
            st["pending"] = op
            i += len(op)
        elif c in "<>":
            if st["word"] is not None and st["word"].is_fd():
                st["word"] = None                       # `2>`, `{fd}>`: the digits name the fd, not an argument
            else:
                flush()
            ops = (">>", ">|", ">&", ">") if c == ">" else ("<<<", "<<-", "<<", "<>", "<&", "<")
            op = next(o for o in ops if s.startswith(o, i))
            st["pending"] = op
            i += len(op)
        elif c in ";&|\n":
            two = s[i:i + 2]
            op = two if two in ("&&", "||", "|&", ";;", ";&") else c
            end_cmd()
            i += len(op)
            if op == "\n" and heredoc_q:
                i = read_heredocs(i)
        else:
            w().add("raw", c)
            i += 1
    end_cmd()
    return out


# ── expansion (best effort; anything unknown is marked dynamic) ─────────────────────────────────────────────
VAR_RE = re.compile(r"\$(?:\{([A-Za-z_]\w*)\}|([A-Za-z_]\w*)|\{[^}]*\}|[0-9@*#?$!-])")
ASSIGN_RE = re.compile(r"^([A-Za-z_]\w*)\+?=")
MAX_CANDS = 64


def expand(word, env):
    """-> (candidate values, dynamic). `env` maps a name to its candidate values, or None (unknown)."""
    cands, dyn = [""], False
    for idx, (kind, text) in enumerate(word.parts):
        if kind == "lit":
            cands = [c + text for c in cands]
            continue
        if kind == "dyn":
            dyn = True
            cands = [c + text for c in cands]
            continue
        if kind == "raw" and idx == 0 and (text == "~" or text.startswith("~/")):
            text = os.path.expanduser("~") + text[1:]
        pos = 0
        for m in VAR_RE.finditer(text):
            alts = None
            name = m.group(1) or m.group(2)
            if name and name in env:
                alts = env[name]
            elif name and name in os.environ:
                alts = [os.environ[name]]
            if alts is None:
                dyn, alts = True, [m.group(0)]
            cands = [c + text[pos:m.start()] + a for c in cands for a in alts]
            pos = m.end()
            if len(cands) > MAX_CANDS:
                return cands[:MAX_CANDS], True
        cands = [c + text[pos:] for c in cands]
    return cands, dyn


def value(word, env):
    """Single static value of a word, or None if it is dynamic / has several candidates."""
    cands, dyn = expand(word, env)
    return cands[0] if not dyn and len(cands) == 1 else None


def is_assign(word):
    return bool(word.parts) and word.parts[0][0] == "raw" and ASSIGN_RE.match(word.parts[0][1]) is not None


def assign(word, env):
    head = word.parts[0][1]
    m = ASSIGN_RE.match(head)
    rest = Word()
    rest.parts = ([("raw", head[m.end():])] if head[m.end():] else []) + list(word.parts[1:])
    cands, dyn = expand(rest, env)
    env[m.group(1)] = None if dyn else cands


def strip_wrappers(words, env):
    i = 0
    while i < len(words):
        if is_assign(words[i]):
            i += 1
            continue
        v = value(words[i], env)
        if v in KEYWORDS:
            i += 1
            continue
        b = os.path.basename(v) if v else None
        if b not in WRAPPERS:
            break
        i += 1
        while i < len(words):
            v2 = value(words[i], env)
            if b == "env" and is_assign(words[i]):
                i += 1
            elif v2 and v2.startswith("-") and v2 != "-":
                i += 2 if v2 in WRAPPERS[b] else 1
            else:
                break
        if b == "timeout" and i < len(words):
            i += 1                                       # the DURATION
    return words[i:]


# ── checks ───────────────────────────────────────────────────────────────────────────────────────────────
def check_git(cmd, env):
    words = cmd.words
    vals = [expand(wd, env) for wd in words]
    for j, (cands, dyn) in enumerate(vals):
        if dyn:
            # an unresolvable program word (`$X push`) followed by push/tag: fail closed
            if j == 0 and len(vals) > 1 and set(vals[1][0]) & GITSUB:
                block(f"refusing `{cmd.text()[:160]}` — cannot resolve the program; only genesis-release may "
                      "push or tag (blocked even under --trust-all-tools)")
            continue
        if not any(os.path.basename(c) == "git" for c in cands):
            continue
        k = j + 1
        while k < len(vals):
            sub, sdyn = vals[k]
            if sdyn:
                block(f"refusing `{cmd.text()[:160]}` — cannot resolve the git subcommand statically "
                      "(only genesis-release may push or tag)")
            if sub[0] in GIT_OPT_WITH_VALUE:
                if sub[0] == "-c" and k + 1 < len(vals) and any(
                        x.lower().startswith("alias.") for x in vals[k + 1][0]):
                    block(f"refusing `{cmd.text()[:160]}` — `git -c alias.…` can hide a push/tag")
                k += 2
                continue
            if sub[0].startswith("-"):
                k += 1
                continue
            hit = set(sub) & GITSUB
            if hit:
                block(f"refusing `git {sorted(hit)[0]}` — only genesis-release may push or tag "
                      f"(blocked even under --trust-all-tools). Command: {cmd.text()[:160]}")
            break


def normalize(t, cwd):
    if not t.startswith("/"):
        if not cwd:
            return None              # a relative target we cannot resolve → treat as outside (fail closed)
        t = cwd.rstrip("/") + "/" + t
    return os.path.normpath(t)


def inside(path):
    return any(path == r or path.startswith(r.rstrip("/") + "/") for r in roots)


def is_sink(path):
    return path in DEV_SINKS or re.fullmatch(r"/dev/fd/\d+", path) is not None


def check_target(cands, dyn, shown, cwd, allow_sink, cmd):
    if dyn:
        block(f"refusing a shell write to `{shown}` — the target cannot be resolved statically (an unknown "
              f"variable or a substitution). Use a literal path under a write root "
              f"({', '.join(roots) or 'none'}). Command: {cmd.text()[:160]}")
    for c in cands:
        if c == "":
            continue
        p = normalize(c, cwd)
        if p is not None and (inside(p) or (allow_sink and is_sink(p))):
            continue
        block(f"refusing a shell write to `{c}` outside the write roots "
              f"({', '.join(roots) or 'none'}). Use the write tool or a path under a write root. "
              f"Command: {cmd.text()[:160]}")


def analyze(text, cwd, env, depth=0):
    if depth > 5:
        return
    stack = []
    for item in lex(text):
        if item == "(":
            stack.append((cwd, dict(env)))
            continue
        if item == ")":
            if stack:
                cwd, env = stack.pop()
            continue
        cmd = item
        for body in cmd.nested:
            analyze(body, cwd, dict(env), depth + 1)
        words = cmd.words

        # assignments: a command of only NAME=… sets shell variables
        if words and all(is_assign(wd) for wd in words):
            for wd in words:
                assign(wd, env)

        if not allow_push_tag:
            check_git(cmd, env)

        args = strip_wrappers(words, env)
        prog = os.path.basename(value(args[0], env) or "") if args else ""
        rest = args[1:]
        vals = [expand(wd, env) for wd in rest]
        single = [c[0] if (not d and len(c) == 1) else None for c, d in vals]

        if prog in ("export", "declare", "local", "readonly", "typeset"):
            for wd in rest:
                if is_assign(wd):
                    assign(wd, env)
        elif prog == "for" and len(rest) >= 2 and single[1] == "in" and re.fullmatch(r"[A-Za-z_]\w*", single[0] or ""):
            loop, ldyn = [], False
            for cands, d in vals[2:]:
                loop += cands
                ldyn = ldyn or d
            env[single[0]] = None if (ldyn or len(loop) > MAX_CANDS) else loop

        # wrapped shell code: sh -c BODY (any position, e.g. `xargs sh -c`), eval, shell heredoc / here-string
        for j, wd in enumerate(words):
            v = value(wd, env)
            if not v or os.path.basename(v) not in SHELLS:
                continue
            for k in range(j + 1, len(words) - 1):
                f = value(words[k], env) or ""
                if f.startswith("-") and not f.startswith("--") and "c" in f[1:]:
                    analyze(value(words[k + 1], env) or words[k + 1].text(), cwd, dict(env), depth + 1)
                    break
        if prog in SHELLS:
            for body in cmd.heredocs:
                analyze(body, cwd, dict(env), depth + 1)
            for hs in cmd.herestrings:
                analyze(value(hs, env) or hs.text(), cwd, dict(env), depth + 1)
        if prog == "eval":
            analyze(" ".join(s if s is not None else wd.text() for s, wd in zip(single, rest)),
                    cwd, dict(env), depth + 1)

        # (b) writes — redirections first ([[ a > b ]] is a string comparison, not a redirect)
        if prog != "[[":
            for op, wd in cmd.redirs:
                if op in READ_REDIRS:
                    continue
                cands, dyn = expand(wd, env)
                if op == ">&" and not dyn and all(re.fullmatch(r"\d+-?|-", c) for c in cands):
                    continue                              # fd duplication / close: 2>&1, >&2, 3>&-
                check_target(cands, dyn, wd.text(), cwd, True, cmd)

        pos = [(c, d, wd) for (c, d), s, wd in zip(vals, single, rest) if not (s and s.startswith("-"))]
        if prog == "tee":
            for c, d, wd in pos:
                check_target(c, d, wd.text(), cwd, True, cmd)
        elif prog in ("cp", "mv"):
            tdir = None
            for k, s in enumerate(single):
                if s in ("-t", "--target-directory") and k + 1 < len(vals):
                    tdir = (vals[k + 1][0], vals[k + 1][1], rest[k + 1])
                elif s and s.startswith("--target-directory="):
                    tdir = ([s.split("=", 1)[1]], False, rest[k])
            tgt = tdir or (pos[-1] if pos else None)
            if tgt:
                check_target(tgt[0], tgt[1], tgt[2].text(), cwd, prog == "cp", cmd)
        elif prog == "rm":
            for c, d, wd in pos:
                check_target(c, d, wd.text(), cwd, False, cmd)
        elif prog == "dd":
            for (c, d), wd in zip(vals, rest):
                outs = [x[3:] for x in c if x.startswith("of=")]
                if outs:
                    check_target(outs, d, wd.text(), cwd, True, cmd)
        elif prog == "sed" and any(s and (s == "-i" or s.startswith("-i") or s.startswith("--in-place"))
                                   for s in single):
            has_script_opt = any(s in ("-e", "-f", "--expression", "--file") for s in single)
            files, skip = [], False
            for k, ((c, d), s, wd) in enumerate(zip(vals, single, rest)):
                if skip:
                    skip = False
                    continue
                if s in ("-e", "-f", "--expression", "--file"):
                    skip = True
                    continue
                if s == "" and k > 0 and single[k - 1] == "-i":
                    continue                              # BSD `sed -i '' …`: the empty backup suffix
                if s and s.startswith("-"):
                    continue
                files.append((c, d, wd))
            for c, d, wd in (files if has_script_opt else files[1:]):
                check_target(c, d, wd.text(), cwd, False, cmd)

        # cd / pushd / popd move the cwd used for relative targets
        if prog in ("cd", "pushd"):
            dest = [s for s in single if not (s and s.startswith("-") and s != "-")]
            if not dest:
                cwd = os.path.expanduser("~") if not rest else ""
            else:
                d = dest[0]
                if d is None or d == "-":
                    cwd = ""
                elif d.startswith("/"):
                    cwd = os.path.normpath(d)
                else:
                    cwd = os.path.normpath(cwd.rstrip("/") + "/" + d) if cwd else ""
        elif prog == "popd":
            cwd = ""


analyze(raw, start_cwd, {})
sys.exit(0)
PY
