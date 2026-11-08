# Backlog — Phase 50 follow-ups (platform monorepo)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-10-31 (Phase 50, 50-01 D17). · Depends on Phase 50.

## 1. Retire the updater's `scope` label

**Context.** `runtime/updater.py` `_scope()` labels an available update `deps` or `code`. Since 50-05 it is `deps`
when the path diff between the deployed version and the target tag touches the root `pyproject.toml`, `packages/**` or
`scripts/install-packages.sh`. Since 50-07 every release bumps the version line in every `pyproject.toml`, so the
label is always `deps` (50-05 review m1). It was already loose before Phase 50: a managed install is non-editable, so
even an app-only change needs a reinstall.

**Who reads it.** Only `genesis update --check-only` prints it (`genesis/genesis/cli/main.py:183`); `/api/system`
returns it in `UpdateStatus`, typed in `web/src/lib/api/system.ts`, but no screen shows it (only
`features/system/system.test.tsx` fixtures). `apply()` always reinstalls. No behaviour depends on it.

**When picked up.** Remove `scope` from `UpdateStatus`, the CLI line, the web type and fixtures and the updater tests,
as one API contract change (L-011: mirror the contract in `web/src/types` + fixtures). Or give it a real meaning if a
use appears (e.g. "needs a DB migration").

## 2. `genesis status` does not report the port the server actually runs on

**Context (50-06 As built).** After `genesis up --port 8791`, a bare `genesis status` printed port 8760. The
`status` sub-command takes `--port` with a default of 8760 (`genesis/genesis/cli/main.py:66-67`) and passes it to
`runtime/launcher.status`, so it reports the default port unless told otherwise. Predates Phase 50.

**When picked up.** Have `up` record the host/port it started on next to its pid file and let `status` (and `down`,
`logs` if they share the assumption) read it when `--port` is not given. Small; distribution area (L-052: keep it in
the one launcher module).

## 3. Pin ruff in genesis-workflows

**Context (50-07 As built).** genesis-workflows' dev extra floats `ruff>=0.6`, against L-025/L-027. Pinning
`ruff==0.15.20` (the platform's pin) finds 20 existing problems, and the repo's CI does not run ruff at all, so 50-07
left the float in place rather than churn workflow code inside the monorepo phase.

**When picked up.** Fix the 20 findings (no behaviour change), pin `ruff==0.15.20`, and add `ruff check` to the
`library-validate` CI job so the pin is enforced.

## 4. Protect genesis-workflows' release refs and its CI token

**Context (50-08 H2, D21).** Since D20 the only project holding `GITLAB_PUSH_TOKEN` is **genesis-workflows**, whose CI
uses it to clone the genesis repo for its `#subdirectory=` pins. The variable is masked but **not protected**, so every
pipeline gets it — including a branch or merge-request pipeline, and an MR can edit `.gitlab-ci.yml` itself.
genesis-workflows accepts contributions from anyone (ADR-014). H2 stops a bad internal pin from being downloaded, but
`pip install` still fetches hatchling and third-party packages while the token is present. No branch or tag in any
Genesis project is protected today (`50-01-findings.md` §2.6).

**What to do (user, in the GitLab UI — agents must not call the CI-variables API, D20).**

1. genesis-workflows → Settings → Repository → **Protected branches**: `master`, push and merge = Maintainers.
2. Same page → **Protected tags**: `v*`, allowed to create = Maintainers.
3. Settings → CI/CD → Variables → `GITLAB_PUSH_TOKEN`: tick **Protected** (keep **Masked**).
4. Push a no-op or wait for the next `master` pipeline: `library-validate`, `skills-validate`, `workflow-tests` green.
5. Optional, same pattern for genesis (`master`, `v*`) — it holds no CI secret now, so this only guards history.

**Effect to know about.** Pipelines on any **other** branch no longer get the token, so their `pip install` of the
genesis pins fails. Library changes are validated on `master` (and locally), so this is accepted; a contributor branch
must be merged to run the full CI.

**When.** Any time after Phase 50's release (genesis-workflows v0.24.0); doing it before 50-09 is also safe, because 50-09
pushes only `master` and the `v0.24.0` tag.

## 5. Stop agents from batching dependent steps (L-089 kept recurring)

> **Narrowed and carried into `phase-51-follow-ups.md` §27** (the user's decision, 2026-11-08): serialize only step
> calls (git add/commit/push/tag, builds) and refuse git status/diff/show while one runs or a vite build is alive; plain
> parallel reads stay allowed. Kept here for the context.

**Context.** L-089 forbids sending dependent steps (edit → run → commit, stop → check, push → check) in one parallel
tool batch. In Phase 50 it recurred in almost every session despite being in the agents' rules: the 50-03 subtree
merges, the 50-04 and spec-agent check+commit batches, the 50-08 push+check, and about a dozen times in the 50-09
release (incl. an active-run check sent with the fleet stop; it ran first and found 0 runs). Every result was
re-checked and correct, but the rule alone does not hold. The 50-09 As run lists the cases.

**Open question first.** A `PreToolUse` hook (L-088) sees one command at a time, not the batch it arrived in, so it
cannot tell "parallel" from "sequential" directly. Spike what the Kiro CLI exposes (a batch id, timestamps, a
`PostToolUse` ordering) before designing a guard; probe the installed CLI, not its docs (L-044, L-087).

**Possible shapes.** (a) A hook that refuses `git commit`, `git push`, `gsm stop|restart` and `genesis down` when
another tool call of the same turn is still in flight; (b) a lighter rule in the role prompts and skills: mutating
commands are always sent alone, and a check is always a separate later turn; (c) both. Any guard needs a bypass
corpus and a positive corpus (L-088). Owner: genesis-docs (agent system).

## 6. Refuse the CI-variables API in `shell-guard.sh` (L-100)

**Context (D20, 50-09 §4).** A spec-agent `glab api projects/<id>/variables` call printed `GITLAB_PUSH_TOKEN` in clear
on 2026-11-01; the token was revoked and rotated. L-100 forbids the call, but like L-089 a rule alone may not hold.

**When picked up.** Add a `shell-guard.sh` rule that refuses any `glab api` call whose path contains `/variables`
(project, group and instance level, any HTTP method, with or without `-X`, quoted or not, through `env`/absolute paths)
and `glab variable …`. Test it with a bypass corpus and a positive corpus (`glab ci list`, `glab ci trace`, `glab api
projects/<id>/pipelines`) per L-088, then `agent-system/update.sh`. Owner: genesis-docs (agent system).
