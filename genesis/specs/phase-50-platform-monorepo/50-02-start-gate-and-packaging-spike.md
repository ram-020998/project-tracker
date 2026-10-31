# 50-02 — Start gate and packaging spike

> **Status:** ✅ DONE 2026-10-31 — start gate passed; spike GO for D6 (§7). Agent: **genesis-dev**. Repos: none committed — all work in throwaway copies
> under `/tmp/phase-50-spike/`. Parent: `specs/phase-50-platform-monorepo.md`. Decisions: D6, D7, D9, D11
> (`50-01-findings.md` §6).

## 1. Start gate (D9) — do this first, stop on any failure

Record each result in the As built:

1. `genesis-ctx status` shows `genesis` and `genesis-workflows` with **ahead 0** and **dirty 0**.
2. `specs/phase-49-test-design.md` status line says `SHIPPED`.
3. The Phase 49 tags exist on the remote: `git ls-remote --tags origin v0.79.0` in genesis and `v0.23.0` in
   genesis-workflows (or whatever 49-09 As run records).

If any check fails: write the failure in the As built, do nothing else, and report to the user.

## 2. Why a spike

D6 relies on pip behaving a certain way that we have not run here: no relative path dependencies, one command
installing local folders, subdirectory pins from genesis-workflows. L-051 / L-087: probe the real tools before
building on their docs. The spike changes no real repo.

## 3. Setup

1. `git clone` local copies of genesis, genesis-core, kiro-agent-sdk, genesis-appian-parser, genesis-workflows into
   `/tmp/phase-50-spike/` (from the local checkouts; no network needed).
2. In the genesis copy: `git subtree add --prefix=packages/genesis-core ../genesis-core master` (and `main` for
   kiro-agent-sdk and the parser). Record the merge commits and confirm `git log --oneline -- packages/genesis-core`
   shows the original SHAs (D7).
3. Hand-edit the copy as 50-03 will: remove the internal dependency entries (D6), switch the SDK to hatchling +
   `>=3.13` (D11). Python 3.13 venvs only.

## 4. Questions to answer (each with the exact command and output in the As built)

| # | Question | Pass when |
|---|---|---|
| Q1 | Does one command `pip install ./packages/kiro-agent-sdk ./packages/genesis-core ./packages/genesis-appian-parser .` install all four non-editable in a fresh venv? | `pip check` clean; `python -c "import genesis_core, kiro_agent_sdk, genesis_appian_parser, genesis"` works; the wheel still contains `genesis/web_static` (L-048) |
| Q2 | Same with `-e` for each path plus `-e ".[dev]"`? | Imports resolve to the copy's `packages/` paths |
| Q3 | Does pip ever ask an index for an internal name? | `pip install --dry-run --report r.json …` (and the real install with `-v`) shows no index lookup for `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`, `genesis` |
| Q4 | What does plain `pip install .` do now? | Installs only the app; startup import fails clearly (input for F2); nothing fetched for internal names |
| Q5 | Does hatchling build the SDK's `src/` layout? | Wheel contains `kiro_agent_sdk/` at top level |
| Q6 | genesis-workflows with `#subdirectory=` pins against the copy (tag it locally `v0.80.0-spike`, use a `git+file://` URL) | `pip install -e ".[dev]"` succeeds; record time and how many clones pip makes; check whether pip uses a partial clone (`--filter=blob:none`) |
| Q7 | Re-running the one command over an existing install (the updater path) | Upgrades in place; time it |
| Q8 | The genesis test suite on the copy's venv | Same pass count as master (record it); the three parser-fixture tests run once their paths point into `packages/` |

## 5. Output

The As built: the answers, the commands, timings, pip version, any surprise, and a go / no-go for D6. A **no-go**
stops the phase and goes back to the user with the evidence. Delete `/tmp/phase-50-spike/` at the end.

## 6. Acceptance

- [x] Start gate recorded and passed.
- [x] Q1–Q8 answered with evidence.
- [x] No commit, tag or push in any real repo.

## 7. As built

**Verdict: GO for D6.** Every question passed. Surprises are listed under Decisions/deviations; none blocks D6, and
two of them are inputs for 50-03 (F2) and 50-07 (clone count).

Environment: macOS, `/opt/homebrew/bin/python3.13` (3.13.3), git 2.49.0. pip: the venv's bundled **25.1.1** and the
upgraded **26.2.2** (the installer upgrades pip, `scripts/install.sh:139`; CI uses the `python:3.13` image's pip
without upgrading). Copies: `/tmp/phase-50-spike/` cloned from the local checkouts at genesis `908e5d4`, genesis-core
`e5c99ca`, kiro-agent-sdk `b68438c`, genesis-appian-parser `10e412a`, genesis-workflows `04c242e`.

### 7.1 Start gate (D9) — passed

| # | Check | Result |
|---|---|---|
| 1 | `genesis-ctx status` | genesis master v0.79.0 dirty 0 ahead 0; genesis-workflows master v0.23.0 dirty 0 ahead 0 (all six repos dirty 0 / ahead 0) |
| 2 | `specs/phase-49-test-design.md` line 3 | `**Status:** ✅ SHIPPED 2026-10-31 — genesis v0.79.0 (908e5d4) → genesis-workflows v0.23.0 (04c242e)` |
| 3 | `git ls-remote --tags origin v0.79.0` (genesis) / `v0.23.0` (genesis-workflows) | `53631f7b… refs/tags/v0.79.0` / `f35870d7… refs/tags/v0.23.0` (annotated tag objects; v0.79.0 peels to `908e5d4` in the copy) |

### 7.2 Setup

- `git subtree add --prefix=packages/genesis-core ../genesis-core master` (then `kiro-agent-sdk main`,
  `genesis-appian-parser main`) → merge commits `337254c`, `24394db`, `005b13b` ("Add 'packages/<name>/' from commit
  '<original head>'"). Original heads `e5c99ca`, `b68438c`, `10e412a` are ancestors of HEAD; the second parents carry
  37 + 12 + 11 = 60 original commits with their SHAs; `git show 1c653c3` (a genesis-core commit) works in the copy.
- No library tag was imported (127 tag refs in the copy = genesis's own). `v0.3.0` in the copy resolves to genesis's
  own `ba90171`, which is the collision D7 predicted.
- Pack size 168.86 MiB (real genesis) → 173.50 MiB (copy), about +4.6 MiB, most of it the parser's 4.9 MB fixture zip.
- Hand edits as 50-03 will make them, committed only in the copy (`33d41ae`): genesis `pyproject.toml` drops the three
  internal deps; genesis-core drops `kiro-agent-sdk`; the SDK moves to hatchling (`packages = ["src/kiro_agent_sdk"]`),
  `requires-python = ">=3.13"`, dev `pytest>=8`, `ruff==0.15.20`, line length 100; `git rm` of
  `workflows/erd_workflow.py`, `tests/test_erd_workflow.py`, `examples/quickstart.py`, `.env.example`.

### 7.3 Answers

| # | Command (cwd = the genesis copy unless stated) | Result |
|---|---|---|
| Q1 | fresh venv; `pip install ./packages/kiro-agent-sdk ./packages/genesis-core ./packages/genesis-appian-parser .` | **Pass.** exit 0 in 18.1 s (pip 26.2.2, warm cache); also exit 0 with pip 25.1.1. `pip check`: "No broken requirements found." All four import from `site-packages/`; `direct_url.json` = `file:///…/packages/genesis-core`, `dir_info: {}` (non-editable). `site-packages/genesis/web_static/index.html` present, 70 files = the 70 tracked files of `web/static` (L-048). `import genesis.api.app` works; `CORE_MAJOR` 1. |
| Q2 | fresh venv; `pip install -e ./packages/kiro-agent-sdk -e ./packages/genesis-core -e ./packages/genesis-appian-parser -e ".[dev]"` | **Pass.** exit 0 in 12.8 s; `pip check` clean. `__file__`: `…/genesis/packages/genesis-core/genesis_core/__init__.py`, `…/packages/kiro-agent-sdk/src/kiro_agent_sdk/__init__.py`, `…/packages/genesis-appian-parser/genesis_appian_parser/__init__.py`, `…/genesis/genesis/__init__.py`. `pip list --editable` lists all four at those paths. |
| Q3 | `pip install --dry-run --ignore-installed --report r.json … -v`, then the real install `--no-cache-dir -vv` in a fresh venv | **Pass.** Report: the four internal items have `download_info.url` = their `file://` folder, `requested`. In the `-vv` log, pip requested 70 index pages (`https://pypi.org/simple/<name>`); compared with the 69 installed packages, the names never requested are exactly `genesis genesis-appian-parser genesis-core kiro-agent-sdk`, and the extra requested names are build deps only (`hatchling pathspec pluggy tomlkit trove-classifiers`). Same result with pip 25.1.1 (no `/simple/genesis*` or `/simple/kiro*` request). |
| Q4 | fresh venv; `pip install --no-cache-dir -vv .` | **As expected.** exit 0; installs `genesis 0.79.0` only, no index request for an internal name. `pip check` is **clean** (it cannot see undeclared libraries). `import genesis` works; `import genesis.api.app` and the `genesis` console script both fail with `ModuleNotFoundError: No module named 'genesis_core'` — the CLI fails at import (`cli/main.py:8` → `cli/test_workflow.py:16` → `runtime/context.py:6`), before any command runs. See F2 input below. |
| Q5 | `python -m build --wheel packages/kiro-agent-sdk` | **Pass.** `kiro_agent_sdk-0.7.1-py3-none-any.whl`; top level `['kiro_agent_sdk', 'kiro_agent_sdk-0.7.1.dist-info']`; contains `__init__.py client.py handoff.py messages.py`. |
| Q6 | genesis-workflows copy: `pyproject.toml` pins `genesis-core`, `kiro-agent-sdk` (runtime) and `genesis`, `genesis-appian-parser` (dev) as `@ git+file:///tmp/phase-50-spike/genesis@spike-v0.80.0[#subdirectory=packages/<name>]`; fresh venv `pip install --no-cache-dir -vv -e ".[dev]"` | **Pass.** exit 0 in 73.5 s / 77.1 s (two runs); `pip check` clean; the four libraries import from `site-packages`. **pip makes 4 clones** (one per requirement, same URL and ref), each `git clone --filter=blob:none`. The local `file://` server ignores the filter ("filtering not recognized by server"); GitLab honours it: `git clone --filter=blob:none --no-checkout git@gitlab…/genesis.git` 5.2 s / 1.2 MB + `checkout v0.79.0` 2.4 s (5.1 MB) vs a full clone 32.6 s / 225 MB. pip's own GitLab clone of `genesis@v0.79.0` used `--filter=blob:none` and built + installed in 9.8 s. No internal name requested from the index (`-vv` comparison as in Q3). On the copy's venv: library pytest **305 passed**, `ci/validate_library.py` "LIBRARY VALIDATION PASSED (14 workflow(s) validated)", `ci/validate_skills.py` "SKILLS VALIDATION PASSED (3 skill(s) validated)". |
| Q7 | re-run Q1's command over the Q1 venv after changing `packages/genesis-core/genesis_core/util/__init__.py` **without** a version bump | **Pass.** exit 0 in 4.0 s; "Attempting uninstall" for all four, then "Successfully installed …"; the installed module carries the change. pip always rebuilds and reinstalls local folders, so the updater does not depend on a version bump. |
| Q8 | `pytest -q -rs` on the Q2 venv (copy, fixture paths repointed) vs master's `.venv` in the real checkout | **Pass.** Copy: **1366 passed**, 0 skipped, 214 s. Master: **1366 passed**, 0 skipped, 266 s. The three fixture tests (`test_kb_server.py::test_real_package_via_server`, `test_kb_store.py`, `test_kb_incremental.py`; 36 tests) pass with `Path(__file__).resolve().parents[1] / "packages/genesis-appian-parser/tests/fixtures/AiDocumentCenterv4.3.1.zip"` (the zip is tracked in the parser repo, so it comes in with the subtree). No other absolute sibling path in `genesis/` or `tests/`. |

Library suites from their new folders (Q2 venv): genesis-core **96 passed** (same as the real checkout), kiro-agent-sdk
**79 passed** (93 before − the 14 `test_erd_workflow.py` tests D11 removes), genesis-appian-parser **51 passed, 1
skipped** (same as the real checkout; the skip is `test_diff_hash.py:39`, "two real exports … not provided").
Ruff 0.15.20 with each repo's CI scope: `ruff check genesis` (app), `ruff check genesis_core`, parser `ruff check .`,
SDK `ruff check .` (new config) all pass. `ruff check tests` fails in genesis (26 errors) and genesis-core (5) on
master too; CI does not lint tests, so nothing changes.

### 7.4 Commits / Changed / Tests / Review

- **Commits:** none in any code repo; `genesis-ctx status` after the spike: all six repos dirty 0 / ahead 0. The only
  commit is this As built in project-tracker (local, not pushed). The copy's `33d41ae` and branch `spike-v0.80.0`
  exist only under `/tmp/phase-50-spike/`.
- **Changed:** nothing outside `/tmp/phase-50-spike/` except this section.
- **Tests:** the runs in §7.3 (no new tests; a spike).
- **Review:** not run. There is no diff to review; the evidence is the commands and outputs above.

### 7.5 Decisions / deviations

- **Q6 used a branch, not a tag.** `git tag` is denied to genesis-dev by the shell guard (even listing), so the copy
  carries branch `spike-v0.80.0` instead of tag `v0.80.0-spike`. pip resolved it the same way (`git show-ref` →
  checkout). Tag resolution with `--filter=blob:none` was exercised separately against GitLab (`genesis@v0.79.0`).
  `#subdirectory=` with a tag is the one combination not run together; low risk, 50-07 exercises it on the real tag.
- **D7 history check differs from the spec's wording.** `git log --oneline -- packages/genesis-core` shows only the
  merge commit, not the original SHAs, because the original commits touched root paths (`genesis_core/…`). The
  history is kept and reachable: `git blame packages/genesis-core/genesis_core/state.py` shows the original SHAs
  (`e602c8b`, `d80c6d5`, `a0b64bf`, `94041e2`, `1c653c3`); `git log 337254c^2 -- genesis_core/state.py` and
  `git log --full-history -- genesis_core/state.py` list them; `git log --follow` on the new path does not. 50-03
  should check D7 with `blame` and `git log <merge>^2`, and the release/docs notes should say how to search old
  history. Not a reason to change D7.
- **Not tested:** HTTPS partial clone through CI's `insteadOf` token rewrite (only SSH was run). 50-06/50-07 see it in
  the first pipeline.
- **`rm -rf` is denied** to genesis-dev, so §5's "Delete `/tmp/phase-50-spike/`" is left to the user (about 2.6 GB:
  copies, GitLab clones, ten venvs).

### 7.6 Inputs for later sub-specs

- **50-03 / F2:** without the libraries, `pip check` stays clean and the `genesis` console script itself dies at
  import (`cli/main.py:8` → `cli/test_workflow.py:16` → `runtime/context.py:6` → `genesis_core`). For F2's "`genesis
  serve` still starts" and the startup log error, the check must run before those imports (for example a guarded
  import at the top of `cli/main.py`), or F2 should be relaxed to "the CLI exits with one clear message naming the
  missing modules". Decide in 50-03.
- **50-03:** the three fixture tests switch to the `parents[1] / "packages/…"` form above (verified).
- **50-07:** pip clones the genesis repo once per requirement (4 in genesis-workflows' dev install). With GitLab's
  partial clone each is about 7–8 s, about 30 s per CI job; the full-clone cost (about 33 s each) does not apply.
  Consolidating requirements is optional, not needed for speed.
- **Docs mismatch (for genesis-docs):** `context/state/current.md` records genesis-core at **91** tests; the real
  checkout at v0.9.8 runs **96**.

### 7.7 Lesson candidates

- A subtree import keeps every SHA but path-limited `git log` on the new prefix shows only the merge; use `git blame`
  or `git log <merge>^2 -- <old path>` to reach the old history.
- With no internal dependency entries, `pip check` cannot report a missing internal library; the app needs its own
  check, placed before the first internal import.

### 7.8 Code-map changes

None (no code changed).

## Context manifest

```toml
areas    = ["distribution", "release-ci", "core-engine", "sdk-acp", "parser", "workflows-library"]
adrs     = ["ADR-017", "ADR-019", "ADR-024", "ADR-046"]
lessons  = ["L-048", "L-051", "L-057", "L-087"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:specs/phase-49-test-design.md"]
code     = ["genesis/pyproject.toml", "genesis-core/pyproject.toml", "kiro-agent-sdk/pyproject.toml",
            "genesis-appian-parser/pyproject.toml", "genesis-workflows/pyproject.toml"]
upstream = []
```
