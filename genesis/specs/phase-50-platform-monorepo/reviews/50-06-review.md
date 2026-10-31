# Review 50-06 (CI): base 4ce99c9 (genesis-review, 2026-10-31)

Repo: `genesis`, local branch `phase-50-monorepo` (not pushed, not tagged; the 50-03 hold stands), range
`4ce99c9..012b59c`, one commit `012b59c` ci(50-06). `git log --oneline 4ce99c9..012b59c` resolves it. Files changed:
`.gitlab-ci.yml` and `scripts/install-packages.sh` (header comment only; mode stays `100755` per `git ls-tree`).
The main checkout's working tree is clean; the `/tmp/g5006/wt` worktree is at `012b59c` with an empty `git status`
before and after my runs. I did not touch the fleet (:8760/:8761) or the shared dev venv.

## What I verified myself

All runs in the author's clean worktree `/tmp/g5006/wt` (HEAD `012b59c`) with `/tmp/g5006/ve/bin` first on PATH, so
`python`, `ruff` and `pytest` resolve to the fresh venv, as `python` does in the `python:3.13` image. I typed each
job's commands directly rather than through the author's `job.sh`.

| Check | Result |
|---|---|
| `python -m pip list --editable` in `/tmp/g5006/ve` | genesis 0.79.0 → `/private/tmp/g5006/wt`; core 0.9.8, SDK 0.7.1, parser 0.3.0 → `wt/packages/<name>` (what `tests/test_platform_packages.py` needs) |
| `ruff --version` | `ruff 0.15.20` |
| `genesis` job: `ruff check genesis`; `pytest -q -rs` | All checks passed; **1385 passed, 4 skipped** in 237 s; all 4 skips are `tests/test_test_design_stage.py:176: sibling genesis-workflows checkout not present`; exit 0. 1385 + 4 = 1389 = the 50-05 total |
| `genesis-core` job: `cd packages/genesis-core; ruff check genesis_core; pytest -q -p no:warnings` | All checks passed; **96 passed** |
| `kiro-agent-sdk` job: `cd packages/kiro-agent-sdk; ruff check src tests; pytest -q` | All checks passed; **79 passed** (= 50-03 count) |
| `genesis-appian-parser` job: `cd packages/genesis-appian-parser; ruff check .; pytest -q -rs` | All checks passed; 51 passed, **1 skipped** (`tests/test_diff_hash.py:39`, as at 50-03) |
| `yaml.safe_load(.gitlab-ci.yml)` | parses; `genesis`, `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser` all `extends: .python-packages` with no `rules`; `frontend` and `clean-install` keep `rules` |
| `git grep -nE 'insteadOf\|GITLAB_PUSH_TOKEN' -- . ':!*.md'` at `012b59c` | no matches |
| `/tmp/g5006/vc/bin/python -m pip list --editable` (the author's clean-install venv) | empty: the non-editable install has no editable packages |
| pytest rootdir per library job | each `packages/<name>/pyproject.toml` has its own `[tool.pytest.ini_options]` (core :25, SDK :22, parser :21), so `cd` + `pytest` does not climb to the root `testpaths=["tests"]` |
| Dev-tool coverage for the library jobs | the shared install is `-e .[dev]` only (`install-packages.sh`, `APP=".[dev]"`); root dev = `pytest, pytest-asyncio, ruff==0.15.20, jsonschema, httpx` covers core dev (`pytest, pytest-asyncio, ruff==0.15.20, jsonschema`), SDK dev (`pytest, ruff==0.15.20`) and parser dev (`pytest, ruff==0.15.20`). See Minor 1 |

Not re-run: the `clean-install` script (`genesis up` + curl). My shell does not start long-running servers. I accept the
author's run on :8791 (install exit 0, no editable installs, which I confirmed above, db 1–25 + memory 1, `GET /` 200
with the SPA shell, `genesis down` "Stopped.", shellcheck clean, `install.sh --help` ok). In CI the job uses :8760,
which is free on a runner. `glab ci lint` is unavailable (read_api token, 403); the real pipeline is 50-08's gate.

## Checklist

### ADRs
- [N/A] ADR-011: reliability trio on agent nodes. No agent node or the lint gate changed; `genesis/lint/reliability.py` is still exercised by the `genesis` job's `pytest -q` (1385 passed).
- [N/A] ADR-026: loopback-only bind, no auth. Not touched; `clean-install` still boots with plain `genesis up --no-open` (loopback default).
- [N/A] ADR-063: local-first collaboration. Not touched.
- [N/A] ADR-065: collaboration gates. Not touched.
- [N/A] ADR-074: incremental KB sync. Not touched.
- [OK] ADR-077: no agent bulk-doc reads or `--trust-all-tools` introduced; the change is CI config only.
- [OK] ADR-024 (manifest): Python 3.13 pinned. Every Python job uses `image: python:3.13` (`.python-packages` and `clean-install`).

### Lessons
- [N/A] L-017: chat trust. Not touched.
- [OK] L-025: ruff pinned. Every job's ruff comes from `ruff==0.15.20` (root dev extra); I ran 0.15.20 and all four lint commands pass.
- [OK] L-027: pin ruff in every repo/package that runs `ruff check`. Root and all three `packages/*/pyproject.toml` dev extras pin `ruff==0.15.20` (core :20, SDK :17, parser :16).
- [OK] L-030: `frontend` is unchanged (still `changes: [web/**/*]`, diff touches no line of it). The four package jobs drop path rules entirely (D10), which removes the "stale path list skips tests" failure mode for Python. 50-08's first push is a new branch, so `changes` is true and `frontend` runs too.
- [N/A] L-045: chat CLI surface. Not touched.
- [OK] L-048 (manifest): `clean-install` still does a non-editable install and still asserts `/` serves the SPA shell (`.gitlab-ci.yml` step 3a unchanged).
- [OK] L-051: clone + tag distribution. `clean-install` now installs exactly as `scripts/install.sh` and the updater do (`scripts/install-packages.sh --python python`), so the gate tests the shipped path.
- [OK] L-056: the commit holds both changed files (`git diff --stat 4ce99c9 012b59c`: `.gitlab-ci.yml`, `scripts/install-packages.sh`); no implementation is missing. No tag is made in this sub-spec.
- [N/A] L-057: no tag or pin bump; the three libraries are now in-repo, so no transitive git pin remains in the genesis pipeline (no `insteadOf`, no git+ssh clone).
- [N/A] L-087: no doc-corpus migration.
- [N/A] L-088: no agent-shell guard.
- [OK] L-089: the author ran each step in its own call in a clean worktree; I re-ran each gate separately and checked `git status` in its own call.
- [OK] L-092: no `tests/__init__.py` or `test_*` non-test names added; each library job collects only its own `tests/` (rootdir per package, see table).

### Gates
- [OK] Spec §4: each job's script from a clean worktree at `012b59c`: all green (table above).
- [OK] Spec §4: `yaml.safe_load(open('.gitlab-ci.yml'))` parses.

### Spec §5 acceptance
- [OK] Four package jobs with no path rules; `frontend` unchanged; `clean-install` covers `packages/**` (`.gitlab-ci.yml`, `- packages/**/*`).
- [OK] No `insteadOf` rewrite left (grep above).
- [OK] SDK lint clean (`ruff check src tests`: All checks passed); tests unchanged in count (79).
- [OK] Every job's script passes locally (clean-install on the author's evidence, see "Not re-run").

## The author's decisions

1. `extends` + hidden `.python-packages` instead of a YAML anchor. **Agree.** Same effect (shared `stage`, `image`, `before_script`), and `extends` merges hashes the way GitLab documents, which an anchor with `<<:` does less clearly. Record it as a deviation in the As built.
2. No separate `version-sync` job. **Agree.** §1 allows folding it in, and the root `testpaths=["tests"]` means a `tests/test_version_sync.py` from 50-07 is collected by the `genesis` job's `pytest -q`. 50-07's review should confirm it is in `tests/`.
3. `scripts/install-packages.sh` covered by `scripts/**/*`. **Agree**; the inline comment says so.
4. `--python python`. **Agree.** The script leaves a bare name as a PATH lookup (`case "$PYTHON"` only rewrites paths with `/`), and its default `<repo>/.venv/bin/python` would `die` on a runner.
5. SDK first lint with its own config, default rule set, no widening. **Agree.** §2 asks for a clean lint under the package's own config, not new rules. Widening (for example `I` for import order) would be a separate decision.
6. Shallow clone and `rules: changes`. **Agree.** For branch and tag push pipelines GitLab compares the push's changed files server-side (new branch or tag: always true), independent of the runner's clone depth; no job uses `compare_to`, and there are no MR pipelines (no `workflow:` rules), so the target-branch comparison does not apply.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **Minor 1: the library jobs get their test tools only from the app's dev extra.** `install-packages.sh --dev` installs `-e .[dev]` and the libraries without their own `[dev]` extras, so `genesis-core`, `kiro-agent-sdk` and `genesis-appian-parser` pass today only because the root dev list is a superset of each library's (checked above). If a library later adds a test dependency to its own `dev` extra only, its CI job fails with an import error while the package README's local setup works. Fix (either, small): have `--dev` install `-e ./packages/<name>[dev]` for each library too, or add an assertion (e.g. in 50-07's version-sync test) that each `packages/*/pyproject.toml` dev extra is a subset of the root dev extra. Not blocking: correct today and caught loudly, not silently, if it drifts.

### Nits
- **Nit 1: no pip cache.** Four parallel jobs each install the full app plus its dev extra from scratch. A `variables: PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"` + `cache: {key: pip, paths: [.cache/pip]}` on `.python-packages` would cut runner time. Optional.
- **Nit 2 (pre-existing, out of scope):** the author saw `genesis status` print `http://127.0.0.1:8760` while the server ran on :8791. CI uses :8760, so the gate is unaffected; worth a backlog note for the launcher.

## Verdict: SHIP

No blockers or majors, and every gate I re-ran is green: ruff clean in all four jobs, genesis 1385 passed / 4 skipped,
core 96, SDK 79, parser 51 + 1 skipped, YAML parses, no `insteadOf` left. Minor 1 can be taken in 50-07 or as a
follow-up. The real pipeline check is still 50-08's, when the branch is pushed.
