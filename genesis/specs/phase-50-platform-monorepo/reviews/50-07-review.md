# Review 50-07: genesis base 012b59c, genesis-workflows base 04c242e (genesis-review, 2026-11-01)

Code review only (the brief says no live acceptance; I did not touch the fleet on :8760/:8761 or the shared dev venv).

Ranges, both resolved with `git log --oneline` and both working trees clean (`genesis-ctx status`: dirty 0):

- `genesis` branch `phase-50-monorepo`, `012b59c..34d6dab`: `fb4a160` (shared version 0.79.0, `test_version_sync.py`,
  `KB_FORMAT_VERSION = 1` + parser test, `CORE_MAJOR` comment) and `34d6dab` (`install-packages.sh --dev` gives every
  path its own `[dev]` extra, tests, CI comment). HEAD = `34d6dab`.
- `genesis-workflows` branch `phase-50-monorepo`, `04c242e..bc1124c`: one commit `bc1124c` (sync-application 0.3.1
  KB-format check, pins to `genesis.git@v0.80.0` by `#subdirectory`, `registry.json` `genesis_core_version` 0.80.0, CI
  comment). HEAD = `bc1124c`.

## What I verified myself

| Check | Result |
|---|---|
| Fresh venv `/tmp/g5007/ve`: `pip install --dry-run --ignore-installed --report` of `-e ./packages/genesis-core[dev] -e ./packages/kiro-agent-sdk[dev] -e ./packages/genesis-appian-parser[dev] -e .[dev]` | each of the four is requested with `requested_extras ['dev']` from its own `file://…/genesis[/packages/<name>]`, version 0.79.0; ruff 0.15.20, pytest 9.2.0, pytest-asyncio 1.4.1 resolved |
| `/tmp/g5007/ve/bin/python -m pip check` | No broken requirements found |
| `pip list` in `/tmp/g5007/ve` | genesis, genesis-core, kiro-agent-sdk, genesis-appian-parser all 0.79.0; ruff 0.15.20 |
| app: `pytest -q -p no:warnings -x` (fresh venv) | **1400 passed** in 190 s |
| `ruff check genesis packages/genesis-core/genesis_core packages/genesis-appian-parser packages/kiro-agent-sdk/src packages/kiro-agent-sdk/tests tests/test_version_sync.py tests/test_install_packages_script.py` | All checks passed |
| genesis-core: `pytest -q -p no:warnings` | **96 passed** |
| kiro-agent-sdk: `pytest -q -p no:warnings` | **79 passed** (no async tests, so its dev extra not carrying pytest-asyncio is correct) |
| genesis-appian-parser: `pytest -q` | 53 passed, 1 skipped (the known `test_diff_hash.py` skip) |
| genesis-workflows with `../genesis/.venv`: `ci/validate_library.py` / `ci/validate_skills.py` | LIBRARY VALIDATION PASSED (14) / SKILLS VALIDATION PASSED (3) |
| genesis-workflows: `pytest -q workflows --ignore=workflows/_fixtures -p no:warnings` | **317 passed** (305 + 12 new) |
| What `../genesis/.venv` imports | parser `genesis/packages/genesis-appian-parser/…`, `__version__` 0.79.0, `KB_FORMAT_VERSION` 1; core and SDK also from `genesis/packages/` (editable) |
| `ruff 0.15.20 check --no-cache --statistics .` in genesis-workflows | 20 findings (9 E702, 8 F401, 2 E701, 1 F841). `ruff check workflows/sync-application`: 7, all in the unchanged `tests/test_workflow.py:324-364`; `graph.py` and `test_incremental_sync.py` are clean |
| Installed library on the fleet: `~/.genesis/library/workflows/sync-application/workflow.yaml` | `version: 0.3.0` (see Minor 1) |

Not re-run: the author's one-off manual mismatch on the real checkout (`web/src/version.ts` → 0.79.1). The
parametrized `test_a_deliberate_mismatch_is_reported` covers the same thing on a copy, for four of the seven sources,
and it passes in the 1400. I did not re-run the "new tests against the old graph.py fail" check (it needs a `git stash`).
Reading the diff confirms it: `KB_FORMAT`, `_recorded_kb_format` and `details.kb_format_version` don't exist at
`04c242e`.

## Deliberate decisions (the author's deviations)

1. **`>= (0, 3)` instead of "minor 3": safe; I agree with it.** `_recorded_kb_format`
   (`graph.py:201-210`) maps a full sync that recorded no `kb_format_version` to format 1 only when its
   `parser_version` is ≥ 0.3. It can over-claim only if some parser ≥ 0.3 wrote output older than format 1, and
   none did. 0.3.x is format 1 by definition (`__init__.py:23-26`). No parser 0.4–0.78 exists: the version goes from
   0.3.0 straight to the shared 0.79.0, and 0.79.0/0.80.0 contain the same parse code. After a future format bump,
   the same rule errs in the safe direction. Say an old 0.3.0 workflow runs on a format-2 parser and records only
   `parser_version` "0.9x". That record reads as format 1, so the next run does one extra full sync and never skips
   one it needed. The spec's literal "minor 3" rule would treat a `parser_version` "0.79.0" record from the skew window
   as "older parser" and force a second full sync. The `["0.3.0", "0.3.7", "0.79.0"]` parametrization and
   `test_a_kb_from_a_parser_before_0_3_without_a_format_goes_full` (0.2.4) pin both sides.
2. **genesis-workflows ruff stays `>=0.6`: acceptable.** L-027 binds repos whose CI runs `ruff check`. This repo's
   `.gitlab-ci.yml` runs only `validate_library`, `validate_skills` and pytest (no `ruff`). The 20 findings are
   pre-existing and none are in changed lines. Spec §4 allows a follow-up here. Record it as a follow-up in the As built
   (fix the 20 findings, then pin `ruff==0.15.20`); the `pyproject.toml:30` comment already says so.
3. **`pyyaml>=6` and `jsonschema>=4` kept in the dev extra: correct.** They were already there at `04c242e`, and the CI
   validators use them. Dropping them to match the spec snippet would have been a regression.
4. **Shared venv not reinstalled: acceptable for the gates, but it has a live effect.** The code is current because
   the installs are editable, so the parser now reports 0.79.0 to every fleet worker. See Minor 1. 50-09's fleet update
   must reinstall the venv so the metadata matches.
5. **Tag + `#subdirectory=` and the HTTPS `insteadOf` partial clone not proven: deferred correctly.** Spec §6 allows
   "proven here or in 50-09", and `v0.80.0` does not exist. That acceptance box stays open until 50-09 §1.

## Checklist: genesis (`012b59c..34d6dab`)

### ADRs
- [N/A] ADR-001: LangGraph owns control flow. No graph or node code changed in genesis.
- [N/A] ADR-002: narrow Kiro turns over ACP. kiro-agent-sdk got a version string only (`packages/kiro-agent-sdk/pyproject.toml:7`).
- [N/A] ADR-004: per-node MCP injection. Not touched.
- [N/A] ADR-009: three HITL modes. Not touched.
- [N/A] ADR-010: small state / blackboard. Not touched.
- [N/A] ADR-011: reliability trio. No agent node changed; the lint runs inside the 1400 app tests.
- [N/A] ADR-012: subprocess worker. Not touched.
- [N/A] ADR-017: Python only. No new language; `install-packages.sh` was already bash.
- [N/A] ADR-018: blackboard hand-off. Not touched.
- [OK] ADR-019: `CORE_MAJOR = 1` is unchanged (`genesis_core/types.py:12`). The new comment (`types.py:7-11`) and `packages/genesis-core/pyproject.toml:18-19` say it is independent of the now-shared pip version. The additive-only rule is restated.
- [N/A] ADR-020: no global Kiro config. Not touched.
- [N/A] ADR-021: gates before mutation. Not touched.
- [N/A] ADR-022: artifacts root. Not touched.
- [N/A] ADR-023: FastAPI embeds LangGraph. Only `create_app`'s version literal is *read* by the new test (`tests/test_version_sync.py:33`).
- [N/A] ADR-024: async-first, Py 3.13. `requires-python >=3.13` is unchanged in all four pyprojects.
- [N/A] ADR-025: fork semantics. Not touched.
- [N/A] ADR-026: loopback-only bind. Not touched.
- [N/A] ADR-029: two-tier registry. Not touched.
- [N/A] ADR-030: SQLite persistence. Not touched.
- [OK] ADR-036: Genesis-native parser. The parser stays stdlib-only; the change adds an int constant and changes the version string (`genesis_appian_parser/__init__.py:21-26`).
- [OK] ADR-037: code-free KB. `KB_FORMAT_VERSION` describes the parse output and adds nothing to it.
- [N/A] ADR-038: managed MCP installs. Not touched.
- [N/A] ADR-039: business understanding. Not touched.
- [N/A] ADR-041: documents store. Not touched.
- [N/A] ADR-042: features & specs. Not touched.
- [N/A] ADR-047: scheduled syncs. Not touched in genesis (the operational effect is Minor 1).
- [N/A] ADR-050: LifecycleService. Not touched.
- [N/A] ADR-051: AgentProvider. Not touched.
- [N/A] ADR-053: memory layer. Not touched.
- [N/A] ADR-054: memory.db. Not touched.
- [N/A] ADR-061: Workbench. Not touched.
- [N/A] ADR-062: design lane. Not touched.
- [N/A] ADR-063: local-first collab. Not touched.
- [N/A] ADR-065: collab gates. Not touched.
- [N/A] ADR-066: per-iteration capture. Not touched.
- [N/A] ADR-067: healing. Not touched.
- [N/A] ADR-068: implementation lane. Not touched.
- [N/A] ADR-069: node skills. Not touched.
- [N/A] ADR-073: package tools. Not touched.
- [OK] ADR-074: incremental, package-scoped sync. The constant exists so `sync-application` stops forcing full syncs on version bumps that don't change the format (the purpose of D8/F4). The parser's incremental API is unchanged.
- [N/A] ADR-075: data-cid. Not touched.
- [N/A] ADR-076: change requests. Not touched.
- [OK] ADR-077: no bulk docs read; I did not run this review with `--trust-all-tools`.

### Lessons
- [N/A] L-001, L-002, L-004, L-005, L-006, L-009, L-016, L-020, L-021, L-023, L-026, L-041, L-042, L-059, L-064, L-065, L-075, L-076: core-engine runtime lessons. No runtime code in genesis-core changed; the only diff in `genesis_core/` is the comment above `CORE_MAJOR`.
- [N/A] L-017, L-045: chat trust. Not touched.
- [N/A] L-022: genesis has no workflow graph.py. Answered for genesis-workflows below.
- [OK] L-025: ruff pinned. Every package's dev extra has `ruff==0.15.20` (core `pyproject.toml:21`, SDK `:17`, parser `:16`). `test_every_package_declares_a_dev_extra_with_its_test_tools` (`tests/test_install_packages_script.py`) enforces it for `.` and all three libraries.
- [OK] L-027: each genesis CI job that runs `ruff check` now installs its own package's `[dev]` extra, so it gets the pinned ruff from its own pyproject. Dry-run report: 4 × `requested_extras ['dev']`, ruff 0.15.20.
- [OK] L-030: the four python jobs keep no `rules:` (`.gitlab-ci.yml:17-43`). The version-sync test runs in `genesis` on every pipeline (comment at `.gitlab-ci.yml:20`). No web file changed, so the frontend guard isn't needed.
- [N/A] L-031, L-032, L-035, L-036, L-037, L-038, L-077, L-079: parser behaviour. No parse logic changed; the parser suite passes (53 passed, 1 skipped).
- [OK] L-050: delta = full re-export + local diff. Not altered; the format constant only gates *when* a full sync is forced.
- [N/A] L-051: shipping model. Unchanged.
- [OK] L-056: each commit contains its implementation and its tests. `fb4a160` has `__init__.py` with `test_kb_format_version.py`, and the pyprojects with `test_version_sync.py`. `34d6dab` has `install-packages.sh` with `test_install_packages_script.py`. Both trees are clean.
- [OK] L-057: all four genesis-repo packages state one version, 0.79.0, and `test_every_package_and_surface_states_the_same_version` enforces it across 7 sources. The downstream pins are covered below.
- [N/A] L-087: no doc migration.
- [N/A] L-088: no agent guard hook.
- [OK] L-089: no bundle or build step here. The author ran gates in a separate fresh venv rather than batching them with commits.
- [OK] L-092: the new files are `tests/test_version_sync.py` and `packages/genesis-appian-parser/tests/test_kb_format_version.py`, which have unique module names. The helpers are `collect_versions`, `mismatches`, `_copy_sources`; none is named `test_*`.

### Gates
- [OK] `genesis-core`: `pytest -q -p no:warnings` 96 passed; `ruff check genesis_core` clean (fresh venv).
- [OK] `genesis-core` with `../../.venv` (the listed gate): code identical (editable), same sources. I ran the fresh venv on purpose so the new metadata is in play.
- [OK] `genesis-appian-parser`: `pytest -q` 53 passed, 1 skipped; `ruff check .` clean.
- [OK] app `pytest -q` 1400 passed; `ruff check genesis` clean. kiro-agent-sdk 79 passed; `ruff check src tests` clean.

## Checklist: genesis-workflows (`04c242e..bc1124c`)

### ADRs
- [OK] ADR-001: `full_sync_reason` stays a pure program function in `plan_sync` (`graph.py:540`); no agent decides the mode.
- [N/A] ADR-003: local app model. Unchanged.
- [N/A] ADR-005: MCP/CLI registry. `mcp-registry.json`/`cli-registry.json` untouched.
- [OK] ADR-006: the workflow version bump is consistent across all three places: `workflow.yaml:3`, `META` `graph.py:65` and `registry.json` sync-application `0.3.1`. `validate_library` (contract parity) passed.
- [N/A] ADR-007: roles unchanged (`[developer]`).
- [OK] ADR-010: `kb_format_version` is one small int in `kb_syncs.details_json` and the present summary (`graph.py:733,856`); no bulk.
- [N/A] ADR-011: sync-application has no agent node; `validate_library` reliability lint passed.
- [OK] ADR-012: `graph.py` still imports only stdlib + `genesis_core` + `genesis_appian_parser` (`graph.py:50-56`); no platform import added.
- [N/A] ADR-014: no new workflow.
- [N/A] ADR-015: build order. Not relevant.
- [OK] ADR-017: Python.
- [OK] ADR-018: no data inlined in state; only the format int.
- [OK] ADR-019: `registry.json` `genesis_core_major` stays 1; `genesis_core_version` "0.80.0" matches the genesis-core pin tag. In the app, `genesis_core_version` is only copied into the lockfile (`genesis/dist/install.py:72,81`), and the compat gate is still the major.
- [N/A] ADR-020: no Kiro config.
- [N/A] ADR-021: no new mutating node (the sync still writes only the local KB + the temp `genesis-delta-*` package, unchanged).
- [N/A] ADR-022: artifacts root unchanged.
- [N/A] ADR-026: not touched.
- [N/A] ADR-029: not touched.
- [N/A] ADR-030: no schema change (`details_json` is free-form, m0023).
- [N/A] ADR-031, ADR-033, ADR-034, ADR-045: chat. Not touched.
- [N/A] ADR-035: no file inputs changed.
- [OK] ADR-036: the KB is still fed only via the dev-tagged env; no source change.
- [OK] ADR-037: nothing new stored in the KB beyond a format number.
- [N/A] ADR-038: managed MCP. Not touched.
- [N/A] ADR-039: not touched.
- [N/A] ADR-041: not touched.
- [N/A] ADR-048: credential resolution unchanged.
- [N/A] ADR-056, ADR-057, ADR-058, ADR-059, ADR-061, ADR-062, ADR-063, ADR-065, ADR-067, ADR-068, ADR-069, ADR-075, ADR-076, ADR-078: stage, board, collaboration and healing workflows. None of their files changed.
- [N/A] ADR-073: package tools are still used only by program code (unchanged code path).
- [OK] ADR-074: incremental remains the default. A full sync is forced only on a lower or unknown recorded format, a missing full sync or age, or the `max_changed` limits (`graph.py:213-243`). `test_a_baseline_recorded_by_parser_0_3_without_a_format_stays_incremental` proves end to end that today's KBs stay incremental.
- [OK] ADR-077: as above.

### Lessons
- [N/A] L-006, L-013: `graph:` topology changed only in a description string (`workflow.yaml:43`); node ids unchanged; parity passed.
- [N/A] L-009: no engine change.
- [N/A] L-017, L-045: chat. Not touched.
- [N/A] L-020: no loop change.
- [N/A] L-021, L-023, L-042, L-064, L-075, L-076: no MCP output parsing or agent change.
- [OK] L-022: `graph.py:36` keeps `from __future__ import annotations`, which is safe because the module declares no custom-reducer state keys (docstring `graph.py:33-34`, unchanged). The diff adds none.
- [N/A] L-024: not touched.
- [OK] L-025: the linter is still unpinned in genesis-workflows. Accepted as a recorded follow-up per spec §4 (deviation 2), because CI there runs no ruff.
- [OK] L-026: no new DB write; `finish_sync(details=…)` path unchanged.
- [OK] L-027: genesis-workflows CI runs no `ruff check` (`.gitlab-ci.yml` jobs: library-validate, skills-validate, pytest), so the lesson's condition doesn't apply. Follow-up recorded.
- [N/A] L-029, L-049, L-053: managed-native and credentials. Not touched.
- [N/A] L-030: genesis-only.
- [N/A] L-033: install of a new library version is a 50-09 step (but see Minor 1).
- [N/A] L-051: unchanged.
- [OK] L-056: `bc1124c` contains graph.py, its tests, workflow.yaml, README, registry.json, pyproject.toml and the CI comment together.
- [OK] L-057: all four pins name the same tag, `genesis.git@v0.80.0` (`pyproject.toml:17-18,24-25`). Nothing references `genesis-core.git`, `kiro-agent-sdk.git` or `genesis-appian-parser.git` any more (grep over ci/, workflows/, pyproject.toml, registry.json). The genesis app itself names no internal package, so no hidden transitive pin can drift.
- [N/A] L-087, L-088, L-089: not relevant.
- [OK] L-092: no new test module or `tests/__init__.py`; new tests are added to the existing `test_incremental_sync.py`; helpers are `_last_full`, `_reason`.

### Gates
- [OK] `../genesis/.venv/bin/python ci/validate_library.py`: PASSED (14).
- [OK] `ci/validate_skills.py`: PASSED (3).
- [OK] `pytest -q workflows --ignore=workflows/_fixtures`: 317 passed.
- [OK] `cd genesis && pytest -q` / `ruff check genesis`: 1400 passed / clean (fresh venv, above).

## Spec §6 acceptance
- [x] Version-sync test passes and reports a deliberate mismatch. `test_a_deliberate_mismatch_is_reported` covers 4 sources and `test_a_source_that_states_no_version_is_reported` covers a missing one. The author showed one real-checkout failure.
- [x] `install-packages.sh --dev` installs every package's own `[dev]`. Covered by the editable and non-editable argv tests and by my dry-run report. The four package jobs pass locally; the real pipeline is 50-08/50-09.
- [x] `KB_FORMAT_VERSION` is exported and pinned: `test_kb_format_version_is_pinned`, `test_kb_format_version_is_exported`.
- [x] sync-application covers the five cases: format equal (`test_kb_format_equal_is_incremental`), 0.3.0 without format (parametrized + end to end), format 1 vs 2 (`test_a_recorded_format_below_the_parsers_goes_full` + `test_kb_from_an_older_format_forces_full`), no details (`test_no_details_goes_full`), `KB_FORMAT` missing (`test_without_kb_format_the_parser_minors_are_compared` + `test_kb_from_an_older_parser_forces_full_without_kb_format`).
- [x] One tag for all pins; `registry.json` updated.
- [ ] Tag + `#subdirectory` and the HTTPS partial clone: open, carried to 50-09 as the spec allows (deviation 5).

## Findings

### Blockers
None.

### Majors
None.

### Minors
1. **The dev fleet is already in the skew window, so its next sync of each app will be a full sync.** The fleet's
   `genesis` binary comes from `genesis/.venv` (`genesis-fleet/genesis_fleet/config.py:25`). That venv imports the
   parser editable from this branch checkout, so it now reports `__version__` 0.79.0. The installed workflow is still
   0.3.0 (`~/.genesis/library/workflows/sync-application/workflow.yaml:3`). Its old rule compares the recorded minor
   0.3 with the current 0.79. Every app's next `sync-application` run on :8760 or :8761, manual or scheduled
   (ADR-047), will therefore fall back to full with "kb built by an older parser (need >= 0.79.0)". The result is
   correct, and the code under review makes it happen at most once: 0.3.1 reads the resulting "0.79.0" record as
   format 1, which is deviation 1's purpose. The cost is still an unplanned whole-app export per app against the dev
   env. The new code can't fix this, and D8 requires the shared version. Fix: say this explicitly in the As built (not
   only "a skew window"). In 50-09, install sync-application 0.3.1 in the same step as the genesis v0.80.0 fleet
   update, and tell the user the fleet is exposed now. Installing 0.3.1 on the fleet early is a fleet mutation, so it
   needs a HITL yes; I did not do it.

### Nits
1. `graph.py:231`: an unknown format produces "kb built by an older parser (kb format None < 1)". Suggest
   "kb format unknown (need 1)" when `recorded_format is None`, which reads better in the Syncs tab's fallback reason.
   The tests match on "older parser", so they'd still pass.
2. `web/src/types/applications.ts:78`: the sync-details type mirrors `parser_version` but not the new optional
   `kb_format_version`. Nothing reads it today; add it when the UI shows it (L-011 contract mirroring).

## Verdict: SHIP

No blockers or majors, and every gate I re-ran is green. The five deviations hold up: (1) is safe and better than the
spec's literal rule, (2), (3) and (5) are within what the spec allows, and (4) is fine for the gates. Before closing
50-07, record Minor 1 and the genesis-workflows ruff follow-up in the As built, and carry both into 50-09.
