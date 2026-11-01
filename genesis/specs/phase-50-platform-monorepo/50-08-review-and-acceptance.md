# 50-08 — Review and acceptance

> **Status:** ✅ DONE 2026-11-01 — verdict **SHIP** (`reviews/50-08-review.md`); row 6 deferred (D22). Agent: **genesis-review** (never edits code); **genesis-release** pushes the
> scratch branches for CI, asking first. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-50-platform-monorepo.md`. Reads every As built 50-02..50-07.

## 1. Code review

- `genesis-ctx check --since master --repo genesis` on `phase-50-monorepo`, and on genesis-workflows and
  project-tracker; answer each rule OK / VIOLATION / N/A.
- Specific checks: no internal dependency entry anywhere (D6); one file lists the four package paths (L-052); updater
  scope by path diff (F3); `KB_FORMAT_VERSION` fallback (F4); SDK lint fixes change no behaviour; the three subtree
  merges are not squashed; no secret or `.env` imported (D11 removed `.env.example`).
- Agent system: the recall check of 50-04 §3 is identical; `genesis-ctx lint` (full) green.

## 2. CI on the scratch branch (D7)

genesis-release pushes `phase-50-monorepo` of genesis to `origin` (ask first; a new branch, not `master`). The
pipeline must be green: `genesis`, `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`, `frontend` (if web
changed), `clean-install`. Record the pipeline id. genesis-workflows CI cannot pass before the v0.80.0 tag exists
(50-07 §4); it runs in 50-09.

## 3. Live acceptance

| # | Check | Pass |
|---|---|---|
| 1 | Fresh clone of the pushed branch into a temp dir → `scripts/install.sh --dir <tmp> --branch phase-50-monorepo` with a temp state dir and a free port | Installs, migrates, `genesis up` serves the SPA (200) and `/api/config/health` |
| 2 | Missing library on that install | Uninstall `genesis-appian-parser` → `genesis status` exits 1 with one line naming `genesis_appian_parser` and the fix command (D15); reinstall with the script → works |
| 3 | `pip install --dry-run --report` of the install command | No index lookup for an internal name (D6) |
| 4 | Dev venv | `genesis_core.__file__`, `kiro_agent_sdk.__file__`, `genesis_appian_parser.__file__` are under `genesis/packages/`; the three parser-fixture tests **ran** (not skipped) in the pytest output |
| 5 | Fleet (main + userb) on the dev venv, after checking no run is active and backing up both instances' `genesis.db` + `memory.db` (D19) | Both healthy after a `gsm` restart on the branch code; a **`hello-appian`** run (one agent step) completes (proves the worker imports the libraries) |
| 6 | Incremental sync of a tracked app on main with `sync-application` 0.3.1 (installed on both instances before 50-08, D18; check `GET /api/workflows/sync-application` = 0.3.1) | Runs **incremental** (no forced full sync); `details.kb_format_version` = 1. A scheduled weekday sync on either instance since D18 counts as evidence: read its `kb_syncs` row instead of starting a new sync (D19: wait for the first one, Monday 2026-11-02, after the row 5 restart). **D22: DEFERRED past the release** — the dev environment is down on 2026-11-01; the final verdict marks this row DEFERRED and 50-09 §5 carries the check |
| 7 | genesis-workflows local gates against the dev venv | validate_library, validate_skills, workflow tests green |
| 8 | Updater unit tests + a manual `genesis update --check` style read on a managed temp install | scope computed by path diff; no crash |
| 9 | `genesis-ctx status`, `pack 50-07`, `check --files genesis/packages/genesis-core/genesis_core/nodes/agent.py` | New repo set; core-engine rules load |

Headless limits: item 5's agent step needs a live Kiro login; if unavailable, give the manual check.

## 4. Output

`specs/phase-50-platform-monorepo/reviews/50-08-review.md` with SHIP / NEEDS_CHANGES, the checklist, the pipeline id
and the acceptance table. NEEDS_CHANGES items go back to genesis-dev as numbered hardening items in this file (§5).

## 5. Hardening items

### H1 — Guard against internal names in dependency lists (review M1; D19)

**Agent:** genesis-dev, on `phase-50-monorepo` in genesis and genesis-workflows. Then a focused re-review.
**Order:** H1 is built after the scratch-branch push (§2) and row 5; commit it on the same branch, and genesis-release
pushes the branch again so the H1 commit gets its own green pipeline before the final verdict.

- **genesis:** `tests/test_no_internal_dependencies.py` reads `pyproject.toml` and the three
  `packages/*/pyproject.toml` (`tomllib`). It fails, naming file and entry, if `[project].dependencies` or any
  `[project.optional-dependencies]` list names `genesis`, `genesis-core`, `kiro-agent-sdk` or
  `genesis-appian-parser` in any form: bare, version-pinned or direct reference. Compare PEP 503-normalized names
  (lower case, runs of `-_.` → `-`), and parse each requirement's name with the stdlib only (no new dependency).
- **genesis-workflows:** the same four names may appear **only** as direct `@ git+ssh://…/genesis.git@<tag>` references
  (with `#subdirectory=` for the libraries), all on the same tag (L-057). Add the check to `ci/validate_library.py`
  so the `library-validate` CI job enforces it.
- Evidence in the As built: each check passes, then fails once on a deliberate bad line (e.g. adding
  `"genesis-core>=0.79"` to the app's dependencies; a bare `genesis-core` in genesis-workflows), then is reverted.
- Gates: app `pytest -q` + `ruff check genesis`; genesis-workflows `ci/validate_library.py` + workflow tests.

#### H1 — As built (genesis-dev, 2026-11-01)

**Commits** (local, on `phase-50-monorepo`; not pushed):
- genesis `77ea311` (base `34d6dab`): `test(50-08 H1): tests/test_no_internal_dependencies.py …`
- genesis-workflows `6968bb8` (base `7e42fc9`): `ci(50-08 H1): validate_library gate 9 …`

**Changed**
- genesis `tests/test_no_internal_dependencies.py` (new, 133 lines). `pyproject_paths()` = root + `packages/*/pyproject.toml`
  (a test pins the exact four paths, so a lost glob fails). `internal_entries()` reads each with `tomllib` and checks
  `[project].dependencies` and every `[project.optional-dependencies]` list. `requirement_name()` takes the PEP 508 name
  with one stdlib regex and PEP 503-normalizes it, so bare, pinned, extras, marker and `name @ url` forms are all
  caught. The failure lists `file [list]: 'entry'`. Also: 10 parse cases, 5 deliberate entries on a `tmp_path` copy
  (root deps, root deps by direct reference, root `embeddings` extra, genesis-core deps, parser `dev` extra; each must
  give exactly one hit), and `genesis-workflows` / `genesis-coreutils` must not be flagged.
- genesis-workflows `ci/validate_library.py`: gate 9 (docstring item 9). `check_internal_pins(project)` allows the four
  names only as `name @ git+ssh://…/genesis.git@vX.Y.Z`, with `#subdirectory=packages/<name>` for the libraries and none
  for the app, all on one repo and one tag. It is stdlib only (`re`, `tomllib`). `main()` runs it on `pyproject.toml`,
  then proves it rejects 9 known-bad `[project]` tables and accepts 1 good one. The output line is "OK: internal-pin
  check correctly rejects 9 known-bad tables and accepts a good one". The `library-validate` CI job already runs this
  script, so CI needed no change.

**Evidence: each check passes, fails once on a deliberate bad line, then is reverted.** Every edit, run and revert was
its own tool call. The working tree was verified clean in a separate call after each revert (L-089).

| Check | Pass | Deliberate bad line → failure | Reverted |
|---|---|---|---|
| genesis test | `18 passed` | root `pyproject.toml` + `"genesis-core>=0.79",` after `pypdf` → `test_no_pyproject_lists_an_internal_package` FAILED: `an internal package is listed as a dependency (D6) … pyproject.toml [project].dependencies: 'genesis-core>=0.79'`. The copy-based cases failed too, because they copy the dirty checkout | `git status` shows only the new test file; `18 passed` |
| genesis-workflows gate 9 (bare name) | `LIBRARY VALIDATION PASSED (14 workflow(s) validated)`, exit 0 | `"genesis-core",` first in `dependencies` → exit 1: `[pins] pyproject.toml [project].dependencies: 'genesis-core' — genesis-core must be a direct reference 'genesis-core @ git+ssh://…/genesis.git@vX.Y.Z#subdirectory=packages/genesis-core'` | only `ci/validate_library.py` modified; PASSED, exit 0 |
| gate 9 (L-057 tag split) | as above | parser pin `@v0.80.0` → `@v0.79.0` → exit 1: `the internal pins name different repos or tags — move them together (L-057): …@v0.79.0: genesis-appian-parser; …@v0.80.0: genesis-core, kiro-agent-sdk, genesis` | PASSED, exit 0 |
| gate 9 self-proof (review finding 1) | `rejects 9 known-bad tables and accepts a good one` | checker weakened `len(pins) > 1` → `> 2` → exit 1: `[pins] the internal-pin check unexpectedly ACCEPTED [{… v0.80.0 … v0.79.0 …}]` | `grep` shows `> 1`; PASSED, exit 0 |

**Tests / gates** (final tree): genesis `.venv/bin/python -m pytest -q` → **1418 passed** (1400 before, +18).
`ruff check genesis tests/test_no_internal_dependencies.py` → clean. genesis-workflows, run with the genesis venv:
`ci/validate_library.py` PASSED (14), `ci/validate_skills.py` PASSED (3), `pytest -q workflows --ignore=workflows/_fixtures`
→ 317 passed. `ruff check ci/validate_library.py` → clean, with the same finding count as at HEAD (0).

**Review:** `reviews/50-08-H1-review.md`, verdict **SHIP** (no blockers or majors).
- Minor 1 (the self-proof never exercised the L-057 split or the subdirectory paths) is **fixed** before commit.
  `_BAD_PINS` now holds whole tables, including a tag split, a repo split, a library under another library's subdir and
  the app with a subdir, plus `_GOOD_PINS`. The weakened-checker row above proves the fix. The reviewer's terms needed
  only a validator re-run, not a re-review.
- Nit 4 is **done**: the test docstring says a self-referential extra such as `genesis[embeddings]` is flagged on
  purpose (fail closed).
- Minor 2 and nit 3 are **not done** (optional; see Lesson candidates / follow-ups).

**Decisions / deviations** (no ADR deviation):
- The tag must be `vX.Y.Z`, not a branch or sha. The subdirectory must equal `packages/<name>`. All pins must share the
  repo URL as well as the tag. Each of these is stricter than the spec's wording; the reviewer agreed.
- The ~5-line PEP 508 name regex is duplicated in both repos instead of shared. Sharing it would make genesis-workflows
  CI depend on a genesis release that contains the helper.
- genesis-workflows has no pytest file for gate 9. It proves itself in-process, like gate 6's non-compliant fixture.

**Follow-ups (not built):**
- Review minor 2: in CI, gate 9 runs only after `pip install -e ".[dev]"`, because the validator imports `genesis.lint`
  at module top. A name-only pin is therefore still fetched from public PyPI on the runner before the job goes red. The
  merge is still blocked. A fix is a stdlib-only pin step before the install.
- Review nit 3: the host is not pinned. Any `…/genesis.git` host passes, as long as all four pins agree.

**Lesson candidates:** a self-proof for a checker must cover every rule the checker exists for, including the
cross-entry ones. The first version proved only the per-entry paths, and a broken L-057 grouping would have passed CI.

**Code-map changes:** genesis `tests/test_no_internal_dependencies.py` (D6 guard). genesis-workflows
`ci/validate_library.py` gains gate 9 (internal pins).

**Next (not this item):** genesis-release pushes `phase-50-monorepo` of genesis again, after asking, so `77ea311` gets
its own green pipeline. Then comes the focused re-review entry in `50-08-review.md` and row 6. genesis-workflows CI
still waits for the v0.80.0 tag (50-07 §4 / 50-09). The fleet was not touched.

### H2 — Run the genesis-workflows pin check before anything is installed (H1 review Minor 2; D20)

**Agent:** genesis-dev, on `phase-50-monorepo` in **genesis-workflows** only. Then a short re-review.

- Move gate 9 (`INTERNAL_SUBDIRS`, the regexes, `_normalize`, `check_internal_pins`, `_BAD_PINS` / `_GOOD_PINS` and
  the self-proof) out of `ci/validate_library.py` into a new **stdlib-only** `ci/check_internal_pins.py` with a
  `main()` that reads `pyproject.toml`, runs the self-proof and exits 0/1 with the same messages. No import of
  `genesis` or any third-party module.
- `ci/validate_library.py` imports and calls it (gate 9 still reported there, so local runs are unchanged).
- `.gitlab-ci.yml`: in the shared `.setup` `before_script`, run `python ci/check_internal_pins.py` **before** the
  `git config … insteadOf` line and before `pip install -e ".[dev]"`, so a bad pin fails with nothing downloaded and
  before the token is used.
- Evidence in the As built: `python -I ci/check_internal_pins.py` passes in a bare Python 3.13 with no venv
  (proves stdlib-only); fails once on a bare `genesis-core` line (then reverted); `validate_library.py` still PASSED
  (14) with the gate-9 line; workflow tests unchanged (317). Separate steps for edit, run and revert (L-089).
- Remote proof comes with genesis-workflows' first CI run in 50-09 §1.

#### H2 — As built (genesis-dev, 2026-11-01)

**Commit** (local, on `phase-50-monorepo`; not pushed): genesis-workflows `e4af068` (base `6968bb8`):
`ci(50-08 H2): run the internal-pin check (gate 9) before anything is installed (D20) …`. `git show --stat` lists all
three files (L-056). genesis is unchanged.

**Changed**
- `ci/check_internal_pins.py` (new, 131 lines, stdlib only: `re`, `sys`, `tomllib`, `pathlib`). Gate 9 moved verbatim:
  `INTERNAL_SUBDIRS`, `_REQ_NAME` / `_DIRECT_REF` / `_GENESIS_URL`, `_pin`, `_BAD_PINS` / `_GOOD_PINS`, `_normalize`,
  `check_internal_pins`. The old gate-9 body of `main()` (parse + self-proof) is now `run_gate(pyproject)`, which
  returns `([pins] …` failure lines, the OK line or None)`. `main()` prints the OK line, then
  `INTERNAL-PIN CHECK FAILED:` with the failure lines (exit 1) or `INTERNAL-PIN CHECK PASSED` (exit 0).
- `ci/validate_library.py`: the gate-9 code is removed; it imports `run_gate` from the sibling module and adds its
  failures and OK line at the same point as before. The unused `re` / `tomllib` imports are dropped. Docstring item 9
  notes the move.
- `.gitlab-ci.yml`: the shared `.setup` `before_script` runs `python -I ci/check_internal_pins.py` first, then the
  `GITLAB_PUSH_TOKEN` `insteadOf` line, then `pip install -e ".[dev]"`. All three jobs inherit it.

**Evidence** (each edit, run and revert its own call, L-089):

| Step | Result |
|---|---|
| `/opt/homebrew/bin/python3.13 -I ci/check_internal_pins.py` (no venv) | `OK: internal-pin check correctly rejects 9 known-bad tables and accepts a good one` · `INTERNAL-PIN CHECK PASSED`, exit 0 |
| same with `-I -S` (no site-packages); `runpy` import listing non-stdlib modules | passes, exit 0; `[]` |
| bad line `"genesis-core",` first in `[project].dependencies` → check | exit 1: `[pins] pyproject.toml [project].dependencies: 'genesis-core' — genesis-core must be a direct reference 'genesis-core @ git+ssh://…/genesis.git@vX.Y.Z#subdirectory=packages/genesis-core'` |
| same bad line → `validate_library.py` | `LIBRARY VALIDATION FAILED` with the same `[pins]` line, exit 1 |
| revert → `git status --short` | only the three intended files; check passes again |

**Gates** (final tree, genesis venv): `ci/validate_library.py` → gate-9 OK line + `LIBRARY VALIDATION PASSED (14
workflow(s) validated)`, same output as at H1. `ci/validate_skills.py` PASSED (3). `pytest -q workflows
--ignore=workflows/_fixtures` → 317 passed (unchanged). `ruff check ci/check_internal_pins.py ci/validate_library.py` →
clean. Parsed CI YAML: `before_script` = `[pin check, git config … insteadOf, pip install]`.

**Review:** `reviews/50-08-H2-review.md`, verdict **SHIP** (no blockers or majors). The reviewer confirmed the move with
`difflib` (code lines identical, only two comments reworded or moved) and re-ran the bad-pin and broken-TOML cases on
temp copies.
- Minor m1 (outside H2, for the user): `pip install` still fetches `hatchling` and third-party deps from PyPI while the
  token rewrite is active, and an MR can edit the CI YAML or the check itself. Protection against a hostile MR still
  rests on GitLab settings. **Manual check for the user** in the GitLab UI (agents must not call the CI-variables API,
  D20): `GITLAB_PUSH_TOKEN` in genesis-workflows is Protected and Masked.
- Nit n2: `python -I ci/validate_library.py` would not find the sibling module. CI does not use `-I` for that script,
  and a comment at the import says why. No action.

**Decisions / deviations** (no ADR deviation):
- The standalone `main()` wraps the same `[pins]` lines in its own `INTERNAL-PIN CHECK FAILED/PASSED` header, so a CI
  log shows which step failed. The failure lines and the OK line are unchanged.
- `validate_library.py` finds the module through `sys.path[0]` (the script's directory) instead of a `sys.path` edit
  or a `ci/__init__.py`. That keeps the change small and matches how CI and the area gate run it.
- No pytest file was added. The gate still proves itself in-process on every run (9 bad tables + 1 good), as in H1.

**Lesson candidates:** none new. D20's own lesson (do not call `glab api …/variables`; it prints values) is already
recorded for 50-09.

**Code-map changes:** genesis-workflows `ci/check_internal_pins.py` (new: gate 9, stdlib only, CI runs it before any
install); `ci/validate_library.py` gate 9 now delegates to it; `.gitlab-ci.yml` `.setup` runs it first.

**Next (not this item):** remote proof comes with genesis-workflows' first CI run in 50-09 §1 (after the v0.80.0 tag).

## 6. As built

**Verdict: SHIP (FINAL, 2026-11-01).** The full record is `reviews/50-08-review.md` (one home); H1 and H2 have their own
reports, `reviews/50-08-H1-review.md` and `reviews/50-08-H2-review.md` (both SHIP).

- Pipelines on `phase-50-monorepo`: **#7258881** at `34d6dabc` (all six jobs) and **#7259044** at `77ea3117` (H1; the four
  package jobs; `frontend`/`clean-install` correctly not triggered).
- Acceptance: rows 1–5 and 7–9 PASS; **row 6 DEFERRED** (D22) to the user's check of the first weekday scheduled sync,
  carried in 50-09 §5.
- Findings: M1 RESOLVED by H1; H2 closed H1's Minor 2 together with D20; D21 put ref/variable protection in the backlog;
  nits n3 (unpinned git host in the pin check) and n4 (H1 review header date) left open, no action needed.
- Carried to 50-09: row 6; genesis-workflows' first remote CI run (H1 `6968bb8`, H2 `e4af068`); the L-056 check before
  tagging; the genesis-docs write-back; the D21 backlog item.

## Context manifest

```toml
areas    = ["distribution", "release-ci", "core-engine", "sdk-acp", "parser", "kb-sync", "workflows-library", "runs-worker"]
adrs     = ["ADR-012", "ADR-019", "ADR-046", "ADR-074", "ADR-077"]
lessons  = ["L-030", "L-048", "L-051", "L-056", "L-057", "L-061", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo.md", "tracker:specs/phase-50-platform-monorepo/50-01-findings.md"]
code     = ["genesis/packages/**", "genesis/scripts/**", "genesis/genesis/runtime/updater.py", "genesis/.gitlab-ci.yml",
            "genesis-workflows/workflows/sync-application/**", "genesis-workflows/ci/validate_library.py",
            "genesis-workflows/ci/check_internal_pins.py", "genesis-workflows/.gitlab-ci.yml",
            "genesis/tests/test_no_internal_dependencies.py", "tracker:context/areas.toml"]
upstream = ["50-02", "50-03", "50-04", "50-05", "50-06", "50-07"]
```
