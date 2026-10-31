# Review 50-05 (install, update and developer setup): base 7cb9f1c (genesis-review, 2026-10-31)

Repo: `genesis`, local branch `phase-50-monorepo` (not pushed, not tagged), range `7cb9f1c..25f384e`, two commits:
`9581140` feat(dist,50-05) and `25f384e` docs(50-05). `git rev-parse --short` resolves both. Working tree clean
(`git status --short` empty, before and after my gate runs). Files: `scripts/install-packages.sh` (new, mode `100755`
per `git ls-tree`), `scripts/install.sh`, `genesis/runtime/updater.py`, `tests/test_updater.py`,
`tests/test_install_packages_script.py` (new), `README.md`, `docs/INSTALL.md`, the three `packages/<name>/README.md`.

## What I verified myself

| Check | Result |
|---|---|
| `.venv/bin/ruff check genesis` | All checks passed |
| `.venv/bin/python -m pytest -q -p no:warnings` | **1388 passed** in 410 s (matches the author's 1374 + 14) |
| `shellcheck scripts/install.sh scripts/install-packages.sh scripts/genesisctl.sh` | clean |
| `bash scripts/install.sh --help` | prints the header, step 2/5 text updated |
| `bash <abs>/scripts/install-packages.sh --help` from `/tmp` | prints usage (the script finds its repo from its own path) |
| `install-packages.sh --python` (no value) | `install-packages.sh: --python needs a path`, exit 1 |
| Package gates from the README Develop section, shared dev venv | core: ruff clean, 96 passed; SDK: `ruff check src tests` clean, 79 passed; parser: ruff clean, pytest pass (1 skip) |
| `/bin/bash` 3.2.57 (macOS system bash) running the script with `--editable --dev` against a fake interpreter | correct argv (`-m pip install -e ./packages/kiro-agent-sdk -e ./packages/genesis-core -e ./packages/genesis-appian-parser -e .[dev]`), cwd = repo root |
| Throwaway venv `/tmp/r5005/v` (fresh `python3.13 -m venv`), `install-packages.sh --python /tmp/r5005/v/bin/python` | exit 0; `Processing ./packages/kiro-agent-sdk`, `./packages/genesis-core`, `./packages/genesis-appian-parser`, the repo; `pip check` → No broken requirements |
| Same command a second time (idempotence, and whether pip reuses a stale cached wheel for a same-version local folder) | exit 0; pip rebuilt and reinstalled all four (`Building wheel for kiro-agent-sdk…`, `Uninstalling genesis-core-0.9.8 … Successfully installed`), so a same-version library change between tags is picked up |
| `env GENESIS_STATE_DIR=/tmp/r5005/state genesis db upgrade` | migrations 1–25 + memory.db 1 |
| Throwaway app via `starlette.testclient` on `genesis.api.app.create_app()` | `_resolve_web_static()` = `site-packages/genesis/web_static` (L-048); `GET /` 200 with `Cache-Control: no-cache, must-revalidate` (L-068); `/openapi.json` version 0.79.0; `genesis_core`, `kiro_agent_sdk`, `genesis_appian_parser` import from site-packages of the throwaway venv |
| `updater._scope` against the real tags in this repo (read-only git) | `v0.78.0..v0.79.0` → `deps`, `0.77.0..v0.78.0` → `deps`, `v0.79.0..HEAD` → `deps`, unknown `v9.9.9` → `deps` (see Minor 1) |
| `git grep -n git+ssh 25f384e` | only `.gitlab-ci.yml:7,8,61` and the negative assertion in `tests/test_install_packages_script.py:87` |

Not done: `genesis up --no-open --port …` + curl. My shell refuses to start a long-running server process, so I replaced
it with the TestClient check above. The author reports a real `genesis up` on :8790 → `GET /` 200,
`/api/config/health` 200, `genesis down` stopped. I did not repeat it. The fleet (:8760/:8761) and the shared dev venv
were not touched.

## Checklist

### ADRs
- [N/A] ADR-003: local app pulling workflows from GitLab. Workflow pulling is unchanged; the updater still runs `genesis install` (`updater.py` library-refresh block).
- [N/A] ADR-006: workflow folder packages + lockfile. Not touched.
- [N/A] ADR-007: roles as filter tags. Not touched.
- [N/A] ADR-011: reliability trio. No agent node changed.
- [OK] ADR-016: names `genesis`, `genesis-workflows`, `kiro-agent-sdk` kept; the script installs `./packages/kiro-agent-sdk` (`install-packages.sh:62`).
- [OK] ADR-017: Python only; the new tooling is a bash wrapper around `pip`, the same kind as `install.sh`.
- [OK] ADR-019: `CORE_MAJOR` and genesis-core 0.9.8 unchanged (wheel `genesis_core-0.9.8` in the throwaway install).
- [OK] ADR-020: no global Kiro config is written by the installer or the updater (diff touches no `~/.kiro` path).
- [OK] ADR-023: FastAPI embedding LangGraph unchanged; throwaway `create_app()` serves `/` and `/openapi.json`.
- [OK] ADR-024: Python 3.13 still required (`requires-python = ">=3.13"`, install.sh resolves python3.13; README Develop uses `python3.13 -m venv`).
- [OK] ADR-026: no bind/auth change; README keeps the localhost-only warning (`README.md` "Security" line unchanged).
- [N/A] ADR-029: registries not touched.
- [N/A] ADR-038: managed MCP installs not touched.
- [N/A] ADR-040: `gws` not touched.
- [OK, with the planned amendment] ADR-046: still clone + venv + one install + `genesis up` + git-tag self-update. The literal `pip install .` step becomes `scripts/install-packages.sh` (one `pip install` of four local paths). This is the change the umbrella's planned ADR-080 (D14) records; the author claims no deviation, and I agree it is within the planned amendment. The docs agent must land ADR-080 at 50-09.
- [N/A] ADR-063 / ADR-065 / ADR-073 / ADR-074: collaboration, package tools, KB sync not touched.
- [OK] ADR-077: no agent-system change; review run without `--trust-all-tools`.

### Lessons
- [N/A] L-017: chat trust not touched.
- [OK] L-025 / L-027: ruff stays pinned `ruff==0.15.20` in the `dev` extra, which `--dev` installs.
- [N/A] L-029: managed-native launch not touched.
- [N/A] L-030: no web change; CI is 50-06.
- [OK] L-033: the updater still runs `genesis install` after the package install (order asserted in `test_apply_updates_whole_stack`).
- [N/A] L-045: chat not touched.
- [OK] L-048: the non-editable throwaway install ships `genesis/web_static/{index.html,assets}` and `/` returns 200.
- [N/A] L-049: managed MCP bundles not touched.
- [OK] L-051: clone + tag self-update kept; the updater checks out the tag first and runs **that tag's** script (`updater.py` `apply()`, comment above the call). Branch default `master` unchanged. Verified against real pip and real git, not only stubs.
- [OK] L-052: the four install paths live only in `scripts/install-packages.sh:62,66` (`git grep` for `./packages/kiro-agent-sdk` finds no second list outside tests/docs). `install.sh` and the updater call it; `test_installer_calls_the_script` pins that `install.sh` has no own `install .`.
- [OK, for 50-05's scope] L-056: both commits contain implementation and tests together; tree clean. Re-check at release (50-09).
- [N/A] L-057: no pin bump here (pins are gone since 50-03); genesis-workflows dev pin moves in 50-07.
- [OK] L-068: `GET /` → `Cache-Control: no-cache, must-revalidate` in the throwaway install.
- [N/A] L-087 / L-088: no doc-corpus migration, no agent-shell guard change.
- [OK] L-089: author ran the throwaway checks in separate steps; I re-ran each gate in its own call.
- [OK] L-092: the new test module is `tests/test_install_packages_script.py`, no `tests/__init__.py` added, no non-test `test_*` symbol (the fixture is `fake_python`).

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → 1388 passed.
- [OK] `cd genesis && .venv/bin/ruff check genesis` → All checks passed.
- [OK] Spec §6 extras: `shellcheck scripts/*.sh` clean; `bash scripts/install.sh --help` prints; throwaway install + db upgrade + SPA served (TestClient in place of `genesis up`, see above).

### Spec acceptance (§7)
- [OK] One script holds the four paths; installer, updater and docs use it (`install.sh:140`, `updater.py` `INSTALL_SCRIPT`, README Develop, INSTALL.md step 3).
- [OK, with the 50-06 boundary] No `git+ssh` reference left outside history, except `.gitlab-ci.yml:7-8,61`. The umbrella assigns CI to 50-06 (`phase-50-platform-monorepo.md` "CI | 50-06" and the 50-06 row "`insteadOf` removal"), so the boundary holds. 50-06 must remove those lines and switch CI's `pip install .` / `pip install -e ".[dev]"` (lines 10, 62) to the script.
- [OK] Updater tests cover the path-diff scope (app-only → code, `packages/…` → deps, root `pyproject.toml` → deps, script → deps, diff failure → deps, git error → deps, bare version gets `v`) and the script call (argv, `cwd`, order checkout → script → db upgrade → genesis install → restart; failure stops apply and does not record the version).
- [OK] Throwaway install boots and serves the SPA.

## Answers to the author's questions

1. **Transient "No module named pip" on a fresh macOS venv.** I did not reproduce it (my fresh venv installed on the
   first try). No retry is needed: the failure is loud (`install-packages.sh: pip install failed (exit 1)` then
   install.sh's `die`), nothing is half-recorded, and re-running `install.sh` is idempotent. A blind retry loop in the
   script would also hide real pip failures. If it shows up for users, add one line to INSTALL.md Troubleshooting
   ("`No module named pip` right after the venv is created: re-run `./scripts/install.sh`"). Optional, see Nit 2.
2. **`.gitlab-ci.yml` left to 50-06.** Accepted; the umbrella gives CI to 50-06 explicitly. The script's header already
   says CI calls it (Nit 1), so 50-06 has to make that true.
3. **`apply()` always installs; `scope` is informational.** Correct and the safe choice. It also makes Minor 1 cosmetic
   only.
4. **ADR-046 / ADR-080.** Agreed: no deviation beyond the planned ADR-080 (D14) amendment. The hold from 50-03 still
   applies; I saw no push or tag.

## Findings

### Blockers
None.

### Majors
None.

### Minors
1. **`_scope` can never return `code` on a real release.** `genesis/runtime/updater.py` `_DEPS_FILES` includes the root
   `pyproject.toml`, and every release commit bumps `version = "X.Y.Z"` in it (`git diff v0.78.0 v0.79.0 --
   pyproject.toml` is exactly that one line). On the real tags, `_scope(repo, "v0.78.0", "v0.79.0")` returns `deps`,
   although v0.79.0 changed no dependency ("pins unchanged" in its release commit; the old `_dep_lines` comparison
   would have said `code`). The implementation follows spec §4 literally, so this is a spec gap, and the effect is only
   the label in `genesis update --check-only` (`cli/main.py:183`) and the `UpdateStatus.scope` field, since `apply()`
   always installs. It does make F3's "code" branch dead in practice, and `test_scope_root_pyproject_is_deps` pins the
   behaviour. Fix (either): compare the root `pyproject.toml` at both tags ignoring the `version =` line (e.g. `git
   diff -U0 <cur>..<tag> -- pyproject.toml` and treat only changed lines other than `version =` as deps), with a test
   for a version-only diff → `code`; or drop the root pyproject from the deps list and accept that a dependency change
   in it shows `code`, since the install runs anyway. A note in the As built is acceptable if the author prefers to
   defer it.
2. **A relative `--python` path breaks after the script's `cd`.** `install-packages.sh` checks `command -v "$PYTHON"`
   relative to the caller's cwd, then runs `cd "$ROOT"` (line 78) and calls `"$PYTHON"` from there. From `/tmp/r5005`,
   `install-packages.sh --python ./fakepy` printed `line 80: ./fakepy: No such file or directory` and `pip install
   failed (exit 127)`. Both in-tree callers pass absolute paths (`sys.executable`; `$VENV` from an absolute
   `REPO_ROOT` in the normal run-from-clone path), but `install.sh --dir <relative>` on a fresh clone and a developer
   typing `--python .venv/bin/python` from outside the root would hit it. Fix: resolve `PYTHON` to an absolute path
   before the `cd` (e.g. `case "$PYTHON" in /*) ;; */*) PYTHON="$(cd "$(dirname "$PYTHON")" && pwd)/$(basename "$PYTHON")";; esac`)
   and add a test case with a relative `--python` from another cwd.

### Nits
1. `scripts/install-packages.sh` header says "scripts/install.sh, the in-app updater …, **CI** and the developer setup
   all call it". CI does not yet (50-06). Either soften to "will" or leave it for 50-06 to make true; note it in the As
   built so 50-06 does not miss it.
2. INSTALL.md Troubleshooting could carry the "No module named pip right after venv creation → re-run install.sh" line
   (author question 1).
3. Observation for 50-09, not a 50-05 defect: the only protection against a v0.79.0 install clicking "Update to
   v0.80.0" is the INSTALL.md note. Its old updater runs `pip install .`, which now installs the app without touching
   the git+ssh-installed libraries, and the D15 missing-package check passes because old copies are present. D3 makes
   this acceptable (no production users; reinstall own + fleet), but the 50-09 release checklist should reinstall every
   existing install rather than use the banner.

## Verdict: SHIP

No blockers or majors; every gate I re-ran is green, and the spec's acceptance items are met (the `.gitlab-ci.yml`
git+ssh lines are 50-06's by the umbrella). Minors 1 and 2 should be fixed or recorded in the As built before 50-09.
Nothing pushed or tagged; the 50-03 hold stands.
