# Review 50-03 (repository merge): base 908e5d4 (genesis-review, 2026-10-31)

Repo: `genesis`, local branch `phase-50-monorepo` (not pushed), range `908e5d4..7cb9f1c`. `908e5d4` = `master` =
`v0.79.0` (`git rev-parse master 908e5d4 v0.79.0^{commit}` all print `908e5d47…`). Working tree clean
(`git status --short --untracked-files=all` empty, before and after my gate runs).

## How the subtree merges were checked

The merge commits were not reviewed file by file. For each one I checked its parents, its second parent, the imported
tree and the history.

| Merge | Parents (`git log --first-parent --format='%h %p'`) | `^2` = library tip = release tag | Tree under prefix = library tree |
|---|---|---|---|
| `c8c6982` SDK | `908e5d4 b68438c` | `b68438c` = `kiro-agent-sdk` `main` = `v0.7.1` | `56342ad…` = `56342ad…` |
| `40c4a8e` core | `c8c6982 e5c99ca` | `e5c99ca` = `genesis-core` `master` = `v0.9.8` | `6b65aad…` = `6b65aad…` |
| `1cada22` parser | `40c4a8e 10e412a` | `10e412a` = parser `main` = `v0.3.0` | `897f398…` = `897f398…` |

- Each is an unsquashed two-parent merge. `git diff --stat` outside each prefix is empty, so the merges changed only
  their own `packages/<name>/` folder.
- History is still reachable. `git rev-list --count c8c6982^2 40c4a8e^2 1cada22^2` = 60, which is 12 + 37 + 11.
  `git blame -s packages/genesis-core/genesis_core/state.py` shows `e602c8b`, `a0b64bf`, `d80c6d5`, `94041e2`, `1c653c3`
  (the same as 50-02 §7.5). The SDK `handoff.py` blames to `2f63529`. `git log --oneline 1cada22^2 --
  genesis_appian_parser/diff_hash.py` shows `10e412a` and `822b683`.
- I could not count tags. `git tag --list` is denied to genesis-review by the shell guard. The library tags are not
  reachable as refs by any import path `git subtree add` uses, and the author reports 127 refs, all genesis's own. I
  accept this, unverified.
- Deviation 4 (the three `subtree add` commands were batched in one tool call): the result checks out. The chain is
  linear, each merge's first parent is the previous merge, and each tree is exact.

## Checklist

### ADRs (from `genesis-ctx check --since 908e5d4 --repo genesis`, plus the 50-03 manifest)
- [N/A] ADR-011 reliability trio. No workflow or agent node changed. The moved `genesis_core/nodes/reliability.py` is byte-identical (tree equality above).
- [N/A] ADR-026 localhost guardrail. No bind or serve change. `tests/test_bind_guard.py`, which calls `genesis.cli.main.main`, passes inside the 1374.
- [N/A] ADR-063 / ADR-065 / ADR-074. No collaboration or KB-sync change.
- [OK] ADR-077. This review loaded rules through `genesis-ctx`. Nothing ran with `--trust-all-tools`.
- [N/A] ADR-002 / ADR-004. The ACP and MCP injection code moved byte-identically.
- [OK] ADR-012. The app process still never imports workflow Python. `cli/main.py` only defers its own `create_workflow`/`test_workflow` imports (`genesis/cli/main.py:32-33`).
- [OK] ADR-016. Package and distribution names are unchanged (`genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`).
- [OK] ADR-019. `CORE_MAJOR = 1` is unchanged (`packages/genesis-core/genesis_core/types.py:11`). genesis-core stays at 0.9.8. The loader gate is untouched.
- [OK] ADR-024. The SDK now has `requires-python = ">=3.13"` (`packages/kiro-agent-sdk/pyproject.toml:10`), in line with the Python 3.13 pin.
- [N/A] ADR-036 / ADR-037. Parser code is byte-identical. The KB fixture tests now run from the repo-relative fixture (36 tests, none skipped).
- [OK, with a sequencing note] ADR-046 (clone + `pip install .` + tag self-update). At this HEAD, `pip install .`, `scripts/install.sh:30` and `genesis/runtime/updater.py` no longer install the three libraries, because the pins are gone. This is planned: 50-05 §2–§4 moves them to `scripts/install-packages.sh`. The branch is local and unreleased. It must not be pushed, tagged or released before 50-05 and 50-06 land (see Minor m2).

### Lessons
- [N/A] L-017. Trust and allowlists are untouched.
- [OK] L-025 / L-027. All three package `pyproject.toml` files pin `ruff==0.15.20` (core `:21`, parser `:16`, SDK `:17`, new). `ruff check genesis` passes ("All checks passed!").
- [N/A] L-030. No `web/**` change. 50-06 should keep this in mind for the new jobs.
- [N/A] L-045 / L-051 / L-087 / L-088. Out of scope.
- [OK] L-056. Each commit holds a change together with its test: `7cb9f1c` has `cli/main.py` and `tests/test_cli_missing_packages.py`; `aa17d27` has the fixture repoint and its test. `git status` is clean.
- [N/A] L-057. No tag bumped. genesis-workflows' `genesis@v0.79.0` dev pin moves in 50-07.
- [OK] L-061. I confirmed no runs are active: `GET /api/runs?status=running` returns `{"runs":[],"total":0,…}` on both :8760 and :8761. The fleet was not restarted.
- [VIOLATION, process only] L-089. Spec §1 says "Run these one at a time (L-089)". The three dependent `git subtree add` calls went out in one batch (deviation 4). The output is verified correct above, so nothing defective shipped (Minor m1).
- [OK] L-092. The app has `testpaths = ["tests"]`, and each library suite runs from its own folder under its own `pyproject.toml` rootdir. No `tests/__init__.py` collision was added.

### Spec acceptance (§7)
- [OK] Three subtree merges, not squashed; history reachable. Evidence in the table above.
- [OK] No internal dependency entry in any `pyproject.toml`. `git grep` for `genesis-core.git|kiro-agent-sdk.git|genesis-appian-parser.git|allow-direct-references` finds only `docs/INSTALL.md:105`, which 50-05 rewrites. The parser and SDK have `dependencies = []`.
- [OK] SDK aligned: hatchling backend, `packages = ["src/kiro_agent_sdk"]`, `>=3.13`, `pytest>=8`, `ruff==0.15.20`, `line-length = 100`. POC files gone: `git grep "erd_workflow|quickstart|.env.example|workflows/" -- packages/kiro-agent-sdk` is empty. I rebuilt the wheel to `/tmp/50-03-review-wheel` (outside the tree). Its contents are `kiro_agent_sdk/{__init__,client,handoff,messages}.py` and `kiro_agent_sdk-0.7.1.dist-info/*`.
- [OK] Parser-fixture tests run. `tests/test_kb_store.py tests/test_kb_incremental.py tests/test_kb_server.py::test_real_package_via_server tests/test_cli_missing_packages.py tests/test_platform_packages.py` gives 44 passed (36 + 5 + 3). The skip guards are kept (`test_kb_incremental.py:255`, `test_kb_store.py:226`, `test_kb_server.py` `skipif`).
- [OK] CLI missing-library check and tests (D15). See the notes below.
- [OK] Dev venv rebuilt. `pip list --editable` shows all three under `genesis/packages/`. `test_platform_packages` passes (3 tests).
- [OK] All gates green, and the counts match 50-02 §7.3:

| Gate (rebuilt venv, run by me) | Result | Expected |
|---|---|---|
| `ruff check genesis` | All checks passed | clean |
| app `pytest -q -rs` | **1374 passed**, 0 skipped, 215 s | 1366 + 5 CLI + 3 platform |
| `packages/genesis-core` `python -m pytest -q` | **96 passed** | 96 |
| `packages/genesis-core` `ruff check genesis_core` | All checks passed | clean |
| `packages/kiro-agent-sdk` `python -m pytest -q` / `ruff check .` | **79 passed** / clean | 93 − 14 ERD |
| `packages/genesis-appian-parser` `pytest -q -rs` / `ruff check .` | **51 passed, 1 skipped** (`test_diff_hash.py:39`) / clean | same as before |
| CLI smoke `.venv/bin/genesis db status` | schema 25, memory.db 1, nothing pending | v25 / v1 |

### Deviation 1: `ruff check .` vs `ruff check genesis_core` for genesis-core
I accept this. `ruff check . --statistics` in `packages/genesis-core` reports 5 errors (4 F401, 1 F841). The same command
on the untouched `../genesis-core` master checkout reports the same 5. So the errors predate this branch and are only in
test files. Fixing them here would break "pure move". 50-06 §1 already plans `ruff check genesis_core` as the core job's
lint scope. The spec §6 wording is the outlier (Nit n1).

### Deviation 2: the CLI check
OK.
- `genesis/cli/main.py` imports only stdlib at module level (`argparse`, `importlib.util`, `sys`).
- The check runs first in `main()` (`:26-30`), before `create_workflow`/`test_workflow` (`:32-33`) and
  `runtime.logging` (`:36`). A comment states why (`:8-12`).
- The message matches the spec text exactly. It names folder names, which is reasonable since they are what the user
  types for `packages/<name>`.
- Returning 1 matches the other error paths, and the `genesis = "genesis.cli.main:main"` console script exits 1 with it.
- The tests cover the spec's two cases: one library missing gives exit 1 with that library named; all present gives
  argparse's own exit 2 with usage. They also add two stronger checks:
  - `test_check_runs_before_any_library_import` poisons `sys.modules["genesis.cli.test_workflow"]`.
  - `test_cli_module_imports_without_the_libraries` uses a fresh interpreter with `sys.modules['genesis_core']=None`,
    which proves `genesis/__init__.py` and `genesis/cli/__init__.py` reach no library either.
- Side effect: with a library missing, `genesis --help` also prints the missing-packages line instead of help. That is
  acceptable under D15.

### Deviation 3: PEP 610 `direct_url.json` in `test_platform_packages`
OK. The spec asked the author to choose between an env var and `direct_url` and record why; the module docstring records
the reason (`tests/test_platform_packages.py:1-9`). The test needs no setup, covers editable and non-editable
local-folder installs, and also checks `__file__` when the install is editable. The author reports that it failed on the
old venv, so it catches the real failure mode (a stale sibling install). One caveat for 50-06: any job that installs the
libraries from a VCS URL or a wheel, rather than from the checkout's folders, will fail this test by design.

### Deviation 5: remaining sibling paths
OK as sequenced. The §3 grep (rg, excluding `.venv`, `node_modules` and `web/static`) finds only `README.md:51` and a
docstring in `tests/test_platform_packages.py:4` that describes the old layout. The rest is owned by later sub-specs:
`docs/INSTALL.md:105` (GitLab URL of `genesis-core.git`), `scripts/install.sh:30` (`REPOS=(… genesis-core
kiro-agent-sdk genesis-appian-parser)`), `genesis/runtime/updater.py:6,246` and `.gitlab-ci.yml:8`. 50-05 covers
README, INSTALL, install.sh and updater. 50-06 covers CI.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m1. L-089 process slip (deviation 4).** The three dependent `git subtree add` calls were issued in one tool batch,
  even though spec §1 says one at a time. I verified the outcome independently: correct parents, trees and order. No
  fix to the code is possible or needed, and rewriting history to redo it would be destructive and pointless. Fix:
  record it in the 50-03 As built under Decisions/deviations, with this review's evidence, so the docs agent can count
  it as another L-089 recurrence.
- **m2. The branch is not installable or updatable by the shipped path until 50-05.** At HEAD, `pip install .`,
  `scripts/install.sh` and the in-app updater (`genesis/runtime/updater.py`) install the app without the three
  libraries, and the CLI points at `scripts/install-packages.sh`, which does not exist yet. Root CI (`.gitlab-ci.yml`
  `pip install -e ".[dev]"`) would also fail. This is planned and harmless while the branch stays local. Fix: none in
  50-03. Keep the hold (no push, tag or release of `phase-50-monorepo` until 50-05 and 50-06 are done), and state the
  hold in the As built Resume note.

### Nits
- **n1.** Spec §6 says `ruff check .` for genesis-core, which conflicts with 50-02 §7.3 and 50-06 §1 (`ruff check
  genesis_core`). The docs agent should align the 50-03 §6 wording, or 50-06 should decide whether to lint core tests.
- **n2.** `genesis-ctx check` routed no changed file to any area, not even `genesis/genesis/cli/main.py` or
  `genesis/tests/*.py`. The checklist therefore loaded only the always-on `release-ci`/`security` rules. The
  `packages/**` gap is known (50-04 repoints `areas.toml`). That `genesis/cli/**` maps to no area may be a separate
  existing gap, so it is worth a look in 50-04.
- **n3.** The `genesis` checkout the fleet runs from (editable install) is now on the unpushed branch, and the shared
  venv has the libraries installed from `packages/`. The code is identical to v0.9.8, v0.7.1 and v0.3.0, so behaviour
  does not change. But any fleet restart before 50-09 runs branch code. Note it in the Resume note.

## Verdict: SHIP

No blockers or majors. All gates are green, and I re-ran them myself with the counts above. The two minors need only an
As built record and the existing no-push hold, with no code change.
