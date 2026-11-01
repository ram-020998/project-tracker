# Review 50-08 H2 — genesis-workflows pin check before install (genesis-review, 2026-11-01)

Scope: hardening item H2 (50-08 §5; D20 in `50-01-findings.md`). Code review only: no fleet, no live acceptance, no
push. Remote CI proof is deferred to 50-09 §1 by the spec.

- **genesis-workflows** `phase-50-monorepo`, base `6968bb8` (= HEAD, the H1 commit). Change is uncommitted:
  `M .gitlab-ci.yml`, `M ci/validate_library.py`, `?? ci/check_internal_pins.py` (`git status --short`, nothing else).
- **genesis**: unchanged (`git -C genesis status --short` empty).
- Checklist source: `genesis-ctx check --since 6968bb8 --repo genesis-workflows` (3 files; areas release-ci,
  security, workflows-library).

## Spec requirements (50-08 §5 H2, D20 (b))

| Requirement | Result | Evidence |
|---|---|---|
| Gate 9 moved out of `validate_library.py` (`INTERNAL_SUBDIRS`, regexes, `_normalize`, `check_internal_pins`, `_BAD_PINS`/`_GOOD_PINS`, self-proof) | OK | diff removes all of them (old lines 47–118 and the main() block); a `difflib` compare of the old block (`git show 6968bb8:ci/validate_library.py`, `# 9. internal pins` → `def _build_compiled`) against the new file (`# The four platform` → `def run_gate`) shows **only comment changes**: the `9. internal pins.` prefix dropped and the `[project] tables…` comment moved from above `_pin` to below it. Every code line is identical. |
| Self-proof body identical | OK | `run_gate` (check_internal_pins.py:99–117) is the old main() gate-9 body line for line; the only change is that the OK line is returned instead of printed, and both callers print it at the same point |
| New module is stdlib only, no `genesis` import | OK | imports are `re`, `sys`, `tomllib`, `pathlib` (lines 17–20). `python3.13 -I -S ci/check_internal_pins.py` (no site-packages) → OK line + `INTERNAL-PIN CHECK PASSED`, exit 0. `runpy.run_path` under `-I -S` loaded non-stdlib modules: `[]` |
| `main()` reads `pyproject.toml`, exits 0/1 with the same messages | OK | my probe on temp copies (`ROOT` redirected, real repo untouched): bare `"genesis-core",` first in dependencies → `[pins] pyproject.toml [project].dependencies: 'genesis-core' — genesis-core must be a direct reference …`, exit 1; unparseable TOML → `[pins] pyproject.toml failed to parse: …`, exit 1; the real pyproject → exit 0 |
| `validate_library.py` still reports gate 9; local run unchanged | OK | `../genesis/.venv/bin/python ci/validate_library.py` → `OK: reliability lint…`, `OK: internal-pin check correctly rejects 9 known-bad tables and accepts a good one`, `LIBRARY VALIDATION PASSED (14 workflow(s) validated)` — same lines, same order as at H1. Failure lines keep the `[pins] ` prefix and still go into `failures` (validate_library.py:136–139) |
| CI: run it before the `insteadOf` line and before `pip install` | OK | parsed `.gitlab-ci.yml`: `.setup.before_script` = `[python -I ci/check_internal_pins.py, git config … insteadOf …, pip install -e ".[dev]"]`; all three jobs (`library-validate`, `skills-validate`, `workflow-tests`) inherit it via `<<: *setup` and none overrides `before_script` |
| `-I` safe in CI | OK | the module imports no sibling and computes `ROOT` from `__file__`, so dropping the script dir and cwd from `sys.path` changes nothing |
| Workflow tests unchanged (317) | OK | `pytest -q workflows --ignore=workflows/_fixtures` → `317 passed in 4.99s` |

## Checklist

### ADRs
- [N/A] ADR-001, 003, 005, 006, 007, 010, 012, 015, 018, 020, 021, 022, 026, 029, 030, 031, 033, 034, 035, 036, 037, 038,
  039, 041, 045, 048, 056, 057, 058, 059, 061, 062, 063, 065, 067, 068, 069, 073, 074, 075, 076, 078 — the diff touches
  only CI scripts and CI YAML; no workflow, graph, registry, state, chat, KB, stage, UI or run code.
- [OK] ADR-011 — reliability lint still runs and its self-proof passes (`OK: reliability lint correctly fails the
  non-compliant fixture`); validate_library.py gates 1–8 untouched by the diff.
- [OK] ADR-014 — open contribution is the reason for H2 (D20 rationale); a bad pin in an MR now fails before any
  download or token use.
- [OK] ADR-017 — Python only; new module targets 3.13 (`tomllib`, `str | None`).
- [OK] ADR-019 — no change to `CORE_MAJOR` handling or `registry.json`.
- [OK] ADR-077 — review used `genesis-ctx check`/L0 only; no `--trust-all-tools`.

### Lessons
- [N/A] L-006, 009, 013, 017, 020, 021, 022, 023, 024, 026, 029, 033, 042, 045, 049, 053, 064, 075, 076 — no workflow,
  chat, MCP or graph code touched.
- [OK] L-025 / L-027 — ruff not unpinned or changed; `ruff check ci/check_internal_pins.py ci/validate_library.py` →
  `All checks passed!` (`re`/`tomllib` imports dropped cleanly, no F401).
- [N/A] L-030 — genesis frontend job; not touched.
- [OK] L-051 — no shipping model change.
- [OK] L-056 — reminder for the commit: the change includes an **untracked** new file; `validate_library.py` now
  imports it, so a commit without `ci/check_internal_pins.py` breaks every CI job. `git add` all three files and
  verify with `git show --stat` before tagging.
- [OK] L-057 — the same-repo/same-tag rule is carried over verbatim (`len(pins) > 1` branch).
- [OK] L-087 — the gate was moved, not rewritten (code lines identical, see table).
- [N/A] L-088 — no agent-shell guard touched.
- [OK] L-089 — author's evidence was gathered as separate edit / run / revert calls; I verified the bad-pin case on a
  temp copy rather than editing the tree, and `git status` shows only the 3 intended files.
- [OK] L-092 — new module is not named `test_*`, and `ci/` has no `__init__.py`.

### Gates
- [OK] `../genesis/.venv/bin/python ci/validate_library.py` → `LIBRARY VALIDATION PASSED (14 workflow(s) validated)`
- [OK] `../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures` → `317 passed`
- [OK] (extra) `ci/validate_skills.py` → `SKILLS VALIDATION PASSED (3 skill(s) validated)`
- [OK] (extra) `python3.13 -I -S ci/check_internal_pins.py` → exit 0
- [N/A] `cd genesis && pytest` / `ruff check genesis` — genesis is unchanged (empty `git status`); not re-run.

## Findings

### Blockers
None.

### Majors
None. No bug was fixed, so no regression test is owed; the gate's built-in self-proof (9 bad tables + 1 good) moved
with it and still runs on every invocation.

### Minors
- **m1 (residual, outside H2's scope; for the user, not the dev).** H2 protects against a bad *internal pin*. With the
  token rewrite active, `pip install -e ".[dev]"` still fetches `[build-system].requires` (`hatchling`) and the
  third-party deps from public PyPI, and an MR author can edit `.gitlab-ci.yml` or `ci/check_internal_pins.py`
  itself. Protection against a hostile MR therefore still rests on GitLab settings (fork-MR pipelines do not get the
  parent project's variables; the variable can be marked Protected). Suggested manual check by the user in the GitLab
  UI (agents must not call the CI-variables API, per D20): confirm `GITLAB_PUSH_TOKEN` in genesis-workflows is
  Protected and Masked. No code change asked for in this item.

### Nits
- **n1.** The moved comments are reworded slightly (`# 9. internal pins.` prefix dropped; the `[project]` tables
  comment now sits under `_pin` instead of over it, check_internal_pins.py:43–44, which reads better). Code is
  identical; no action.
- **n2.** `python -I ci/validate_library.py` would fail with `ModuleNotFoundError: check_internal_pins`, because `-I`
  drops the script directory from `sys.path`. CI and the area gate do not use `-I` for this script, and the comment at
  validate_library.py:31 states the assumption. No action unless someone wants `-I` there later.

## Verdict: SHIP

All H2 requirements are met: gate 9 moved verbatim into a stdlib-only module, CI runs it first in the shared
`before_script` (before the token `insteadOf` line and before `pip install`), and the local `validate_library.py`
output is unchanged. Commit all three files together (L-056). Remote CI proof remains with 50-09 §1.
