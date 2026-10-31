# 50-03 — Repository merge

> **Status:** ✅ DONE 2026-10-31 — review SHIP (`reviews/50-03-review.md`); branch `phase-50-monorepo` at `7cb9f1c`,
> local, held until 50-05/50-06 (§8 Resume note). Agent: **genesis-dev**. Repo: **genesis**, branch `phase-50-monorepo` (local;
> never pushed by this agent). Parent: `specs/phase-50-platform-monorepo.md`. Decisions: D5, D6, D7, D11
> (`50-01-findings.md` §6). Read 50-02 As built first; do not start on a no-go.

## 1. History import (D7)

From an up-to-date genesis `master` (re-check: ahead 0, dirty 0):

```
git switch -c phase-50-monorepo
git subtree add --prefix=packages/kiro-agent-sdk        ../kiro-agent-sdk        main
git subtree add --prefix=packages/genesis-core          ../genesis-core          master
git subtree add --prefix=packages/genesis-appian-parser ../genesis-appian-parser main
```

No `--squash`. Old tags are not imported. Record the three merge commit SHAs and the tip SHA of each library that was
imported. Run these one at a time (L-089).

## 2. Package files (D5, D6, D11, F6)

- Each `packages/<name>/` keeps its `README.md`, `.gitignore`, package dir and `tests/`. Delete
  `packages/genesis-core/.gitlab-ci.yml` and `packages/genesis-appian-parser/.gitlab-ci.yml` (50-06 replaces them).
- **Dependencies (D6):** remove `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser` from
  `genesis/pyproject.toml` `[project].dependencies` (with their comments); remove `kiro-agent-sdk` from
  `packages/genesis-core/pyproject.toml`. Third-party dependencies stay where they are. Drop
  `allow-direct-references` where nothing needs it any more.
- **kiro-agent-sdk (D11):** hatchling backend, `[tool.hatch.build.targets.wheel] packages = ["src/kiro_agent_sdk"]`
  (or the form 50-02 Q5 proved), `requires-python = ">=3.13"`, dev extra `pytest>=8`, `ruff==0.15.20`,
  `[tool.ruff] line-length = 100`. Delete `workflows/erd_workflow.py`, `tests/test_erd_workflow.py`,
  `examples/quickstart.py`, `.env.example` in one commit; update its README to drop the POC sections.
- Versions stay as they are in this sub-spec; 50-07 unifies them.

## 3. Repoint repo-external paths

- The three tests that read the parser fixture by absolute path (`tests/test_kb_server.py:196-203`,
  `tests/test_kb_incremental.py:22-24`, `tests/test_kb_store.py:12-14`) use a path relative to the repo root:
  `Path(__file__).resolve().parents[1] / "packages/genesis-appian-parser/tests/fixtures/AiDocumentCenterv4.3.1.zip"`.
  Keep the skip-if-missing guard.
- `grep -rn "repo-gitlab/ramaswamy.u/\(genesis-core\|kiro-agent-sdk\|genesis-appian-parser\)\|\.\./\(genesis-core\|kiro-agent-sdk\|genesis-appian-parser\)"`
  over the genesis repo (excluding `.venv`, `node_modules`, `web/static`) must return nothing except docs that 50-05
  rewrites.

## 4. Missing-library check (D6, D15)

- `genesis/cli/main.py`: before any import that reaches an internal library (today `from .create_workflow …` /
  `from .test_workflow …`, `cli/main.py:7-8`), check `importlib.util.find_spec` for `genesis_core`,
  `kiro_agent_sdk`, `genesis_appian_parser`. If any is missing, print one line to stderr — "Missing Genesis packages:
  <names>. Run scripts/install-packages.sh from the genesis repo." — and exit with status 1. Keep it stdlib-only and
  above every other `genesis.*` import; a comment says why (50-02 Q4: the CLI otherwise dies with a bare
  `ModuleNotFoundError` at `cli/main.py:8` → `cli/test_workflow.py:16` → `runtime/context.py:6`).
- No preflight item and no startup log: without the libraries Genesis cannot start (D15).
- Tests: a patched `find_spec` returning `None` for one library → `main()` exits 1 and the message names it; all
  present → normal argparse behaviour.

## 5. Rebuild the dev venv

The shared `genesis/.venv` holds editable installs of the old checkouts, and the fleet runs it
(`50-01-findings.md` §2.8). Check no run is active on the fleet first (`GET /api/runs?status=running` on :8760 and
:8761; never restart during a run, L-061). Then, sequentially:

```
.venv/bin/pip uninstall -y genesis-core kiro-agent-sdk genesis-appian-parser genesis
.venv/bin/pip install -e packages/kiro-agent-sdk -e packages/genesis-core -e packages/genesis-appian-parser -e ".[dev]"
```

Add a test `tests/test_platform_packages.py`: each of `genesis_core`, `kiro_agent_sdk`, `genesis_appian_parser`
imports from a path inside this repo's `packages/`. In CI it guards against a non-editable install too (the path is
then in site-packages — so the test asserts only when an env var `GENESIS_DEV_CHECKOUT=1` is set, or checks
`importlib.metadata` direct_url; pick one and record why).

## 6. Gates

`ruff check genesis`, `pytest -q` (app), plus each library's own tests from its folder:
`cd packages/genesis-core && ../../.venv/bin/python -m pytest -q`, same for the SDK and the parser
(`../../.venv/bin/ruff check .` for the parser and core). Record counts; they must equal the pre-merge counts
(the per-package counts recorded in the 50-02 As built — genesis-core runs **96**, not the 91 in
`context/state/current.md`; the SDK minus the removed ERD test; the app 1366 as in 50-02 Q8).

## 7. Acceptance

- [x] Three subtree merges, not squashed. History check (50-02 As built: a path-limited `git log -- packages/…` shows
      only the merge, because the original commits touched root paths): `git blame packages/genesis-core/genesis_core/state.py`
      and `git log --oneline <merge>^2 -- genesis_core/` show the original SHAs; same for the SDK and the parser.
- [x] No internal dependency entry in any `pyproject.toml`.
- [x] SDK aligned; POC files gone.
- [x] Parser-fixture tests run (not skipped).
- [x] CLI missing-library check + tests (D15).
- [x] Dev venv rebuilt; library imports resolve into `packages/`.
- [x] All gates green; counts recorded.

## 8. As built

**Verdict: SHIP** (`reviews/50-03-review.md`, base `908e5d4`, range `908e5d4..7cb9f1c`). Branch `phase-50-monorepo` in
genesis, local only. Start: genesis `master` = `origin/master` = `908e5d4` (v0.79.0), dirty 0, ahead 0
(`git ls-remote origin master` matched for all four repos).

### Commits (genesis, branch `phase-50-monorepo`)

| SHA | What |
|---|---|
| `c8c6982` | `git subtree add --prefix=packages/kiro-agent-sdk ../kiro-agent-sdk main`, library tip **`b68438c`** (= v0.7.1) |
| `40c4a8e` | `git subtree add --prefix=packages/genesis-core ../genesis-core master`, library tip **`e5c99ca`** (= v0.9.8) |
| `1cada22` | `git subtree add --prefix=packages/genesis-appian-parser ../genesis-appian-parser main`, library tip **`10e412a`** (= v0.3.0) |
| `8706a50` | SDK POC removal: `workflows/erd_workflow.py`, `tests/test_erd_workflow.py`, `examples/quickstart.py`, `.env.example`; README drops "Run the example", "Status: proof of concept" and "Workflows" sections, Python 3.13+, tests run with the shared venv |
| `06ace89` | Packaging (D6, D11): internal deps out of genesis and genesis-core `pyproject.toml` (+ a comment saying why), `allow-direct-references` dropped in both (nothing needs it); SDK on hatchling, `packages = ["src/kiro_agent_sdk"]`, `>=3.13`, dev `pytest>=8` + `ruff==0.15.20`, `line-length = 100`; `packages/genesis-core/.gitlab-ci.yml` and `packages/genesis-appian-parser/.gitlab-ci.yml` deleted |
| `aa17d27` | Fixture tests repointed to `parents[1] / "packages/genesis-appian-parser/tests/fixtures/…"` (skip guards kept); new `tests/test_platform_packages.py` |
| `7cb9f1c` | CLI missing-library check (D15) + `tests/test_cli_missing_packages.py` |

History check (D7, the 50-02 form): all three merges are unsquashed two-parent merges in a linear first-parent chain;
each `^2` is the library tip and each prefix tree equals the library tree (reviewer). `git rev-list --count <merge>^2`
= 12 (SDK) + 37 (core) + 11 (parser). `git blame packages/genesis-core/genesis_core/state.py` → `1c653c3 94041e2
a0b64bf d80c6d5 e602c8b`; SDK `client.py` → `0ae45ef 2f63529 b07e9fd …`; parser `__init__.py` → `2835ff4 822b683`.
`git log --oneline <merge>^2 -- <old path>`: 22 commits on `genesis_core/`, 10 on `src/`, 8 on `genesis_appian_parser/`.
127 tag refs, all genesis's own (`git for-each-ref refs/tags | wc -l`); no library tag imported.

### Changed

- `pyproject.toml`, `packages/genesis-core/pyproject.toml`, `packages/kiro-agent-sdk/pyproject.toml`,
  `packages/kiro-agent-sdk/README.md`.
- `genesis/cli/main.py`: module level imports only `argparse`, `importlib.util`, `sys`. `_INTERNAL_PACKAGES` maps
  import name → `packages/` folder name; `missing_packages()` uses `importlib.util.find_spec`. `main()` checks first and
  returns 1 with one stderr line `Missing Genesis packages: <folders>. Run scripts/install-packages.sh from the genesis
  repo.`; the `create_workflow`/`test_workflow` imports moved from module level into `main()` after the check.
- `tests/test_kb_server.py`, `tests/test_kb_store.py`, `tests/test_kb_incremental.py`: repo-relative fixture path.
- §3 grep (excluding `.venv`, `node_modules`, `web/static`): only `README.md:51` (dev setup, 50-05). Other leftovers
  outside the grep pattern, all owned later: `docs/INSTALL.md:105`, `scripts/install.sh:30`,
  `genesis/runtime/updater.py:6,246` (50-05), `.gitlab-ci.yml:8` (50-06).
- **Dev venv rebuilt** (`genesis/.venv`, shared with the fleet). `GET /api/runs?status=running` on :8760 and :8761 →
  `{"runs":[],"total":0,…}` (checked twice, the second time just before the uninstall). Then `pip uninstall -y
  genesis-core kiro-agent-sdk genesis-appian-parser genesis` (removed editable 0.9.3 / 0.7.0 / 0.2.0 / 0.48.0 metadata
  pointing at the sibling checkouts), then `pip install -e packages/kiro-agent-sdk -e packages/genesis-core -e
  packages/genesis-appian-parser -e ".[dev]"` (exit 0). `pip list --editable`: genesis 0.79.0 at the repo,
  genesis-core 0.9.8 / kiro-agent-sdk 0.7.1 / genesis-appian-parser 0.3.0 under `genesis/packages/`; `pip check` "No
  broken requirements found."; each library's `__file__` is under `packages/`. The fleet was **not** restarted.

### Tests

| Gate (rebuilt venv) | Result | Pre-merge |
|---|---|---|
| `ruff check genesis` | All checks passed | clean |
| app `pytest -q -rs` | **1374 passed**, 0 skipped (196 s) | 1366 + 5 CLI + 3 platform |
| parser-fixture tests (`test_kb_store.py`, `test_kb_incremental.py`, `test_kb_server.py::test_real_package_via_server`) | 36 passed, none skipped | 36 |
| `packages/genesis-core`: `python -m pytest -q` / `ruff check genesis_core` | **96 passed** / clean | 96 |
| `packages/kiro-agent-sdk`: `python -m pytest -q` / `ruff check .` | **79 passed** / clean | 93 − 14 ERD tests |
| `packages/genesis-appian-parser`: `python -m pytest` / `ruff check .` | **51 passed, 1 skipped** (`test_diff_hash.py:39`) / clean | same |
| SDK wheel (`pip wheel --no-deps packages/kiro-agent-sdk`) | top level `kiro_agent_sdk/`, `kiro_agent_sdk-0.7.1.dist-info` | — |
| CLI smoke `.venv/bin/genesis db status` | schema 25, memory.db 1, nothing pending | — |

New tests: `tests/test_cli_missing_packages.py` (5): one library missing → returns 1, exact one-line message, empty
stdout; all three missing → all named in order; the check runs before any library-reaching import
(`sys.modules["genesis.cli.test_workflow"] = None`); all present → argparse's own exit 2 + usage; a fresh interpreter
with `sys.modules['genesis_core'] = None` imports `genesis.cli.main` and exits 1 (proves `genesis/__init__.py` and
`genesis/cli/__init__.py` reach no library). `tests/test_platform_packages.py` (3, parametrized): **failed 3/3 on the
old venv** (`installed from file:///…/ramaswamy.u/genesis-appian-parser, not from …/genesis/packages/…`) and passes
after the rebuild.

### Review

`reviews/50-03-review.md` — **SHIP**, no blockers or majors; the reviewer re-ran every gate with the same counts.
Minors m1 (recorded below) and m2 (hold, see Resume note); nits n1–n3 for the docs agent / 50-04.

### Decisions / deviations

- **§5 test design: PEP 610 `direct_url.json`, not an env var.** A local-folder install, editable or not, records a
  `file://` URL of the folder; the test asserts it equals `<repo>/packages/<name>` and, when `dir_info.editable`, that
  the module imports from inside the folder. Works the same in the dev venv and a CI job that installs the folders, needs
  no setup. For 50-06: a job installing the libraries from a VCS URL or a wheel fails it by design.
- **CLI message names the `packages/` folder names** (`genesis-core`, …), not the import names, since they match the
  folders and the install script. `main()` returns 1 (the console script exits 1), like its other error paths. With a
  library missing, `genesis --help` also prints the error line; accepted under D15.
- **genesis-core lint scope `ruff check genesis_core`, not §6's `ruff check .`.** `ruff check .` reports 5 errors, all
  in tests (`test_core_units.py`, `test_integrations.py`, `test_tool_store.py`: 4 F401, 1 F841), identical on the
  untouched genesis-core master; its CI linted only `genesis_core`, and 50-06 §1 plans the same. Left untouched to keep
  this a pure move (review n1: align the §6 wording).
- **L-089 recurrence (review m1).** The three dependent `git subtree add` calls went out in one tool batch, though §1
  says one at a time. The result was verified independently (linear chain, correct parents, exact trees); no history
  rewrite.
- No ADR deviation. ADR-046's install wording is broken *on this branch* until 50-05, as planned (ADR-080 amends it).

### Lesson candidates

- A stale editable install of an old sibling checkout imports silently; check each distribution's PEP 610
  `direct_url.json` against the expected folder in a test — it covers editable and non-editable local installs without
  an env var.
- To prove a check runs before an import, put `None` in `sys.modules` for the module (import raises, `find_spec`
  returns `None`), in process for the order and in a fresh interpreter for the package `__init__` chain.
- L-089 again: a spec line saying "one at a time" did not stop a batched issue; dependent git commands need one call each.

### Code-map changes (for 50-04 / genesis-docs)

- All `genesis-core/genesis_core/…` keys (and the SDK/parser sections) now live at
  `genesis/packages/genesis-core/genesis_core/…`, `genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/…`,
  `genesis/packages/genesis-appian-parser/genesis_appian_parser/…` (50-04 repoints keys + `bible/03` headers).
- `genesis/cli/main.py`: `missing_packages()` / `_INTERNAL_PACKAGES` — the D15 missing-library check, first in `main()`.
- New tests: `tests/test_cli_missing_packages.py`, `tests/test_platform_packages.py`.
- kiro-agent-sdk no longer has `workflows/`, `examples/`, `.env.example`.

### Resume note (handoff, not an unfinished session)

50-03 is complete. **Hold: do not push, tag or release `phase-50-monorepo` until 50-05 and 50-06 land** (review m2): at
this HEAD `pip install .`, `scripts/install.sh`, the updater and root CI install the app without the libraries, and
`scripts/install-packages.sh` (named by the CLI message) does not exist yet. The fleet runs its editable install from
this checkout, now on the branch (code identical to v0.9.8 / v0.7.1 / v0.3.0); any fleet restart before 50-09 runs
branch code (review n3). Next: **50-04** (genesis-docs) repoints `areas.toml`, the code map and the repo lists; the
reviewer also saw `genesis/genesis/cli/**` and `genesis/tests/*.py` route to no area in `genesis-ctx check` (n2), worth a
look there. `/tmp/genesis-50-03-wheel/` (one wheel) can be deleted.

## Context manifest

```toml
areas    = ["distribution", "core-engine", "sdk-acp", "parser", "kb-sync", "runs-worker"]
adrs     = ["ADR-002", "ADR-012", "ADR-016", "ADR-019", "ADR-024", "ADR-036", "ADR-037", "ADR-046"]
lessons  = ["L-025", "L-027", "L-056", "L-061", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md"]
code     = ["genesis/pyproject.toml", "genesis/packages/**", "genesis/genesis/cli/main.py",
            "genesis/genesis/api/app.py", "genesis/tests/test_kb_server.py", "genesis/tests/test_kb_store.py",
            "genesis/tests/test_kb_incremental.py"]
upstream = ["50-02"]
```
