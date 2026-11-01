# Review 50-08 H1 — internal-dependency guards (genesis-review, 2026-10-31)

Scope: hardening item H1 (50-08 §5), the fix for M1 in `50-08-review.md`. Code review only: no fleet, no live
acceptance, no push. The verdict of `50-08-review.md` is not changed here.

- **genesis** `phase-50-monorepo`, base `34d6dab` (= HEAD). Change: untracked `tests/test_no_internal_dependencies.py`.
- **genesis-workflows** `phase-50-monorepo`, base `7e42fc9` (= HEAD). Change: uncommitted `ci/validate_library.py`
  (+ gate 9: `INTERNAL_SUBDIRS`, `_DIRECT_REF`, `_GENESIS_URL`, `_BAD_PINS`, `check_internal_pins`, main() lines 191–201).
- Checklist source: `genesis-ctx check --files genesis/tests/test_no_internal_dependencies.py genesis-workflows/ci/validate_library.py`
  (areas release-ci, security, workflows-library).

## Spec requirements (50-08 §5 H1)

| Requirement | Result | Evidence |
|---|---|---|
| genesis: reads root + the three `packages/*/pyproject.toml` with `tomllib` | OK | `pyproject_paths`, `internal_entries` use `tomllib.loads`; `test_the_app_and_three_packages_are_all_checked` pins the exact 4-path list, so a lost glob fails |
| genesis: `[project].dependencies` and every `[project.optional-dependencies]` list | OK | `internal_entries` builds both; deliberate cases hit `embeddings` and `dev` extras |
| genesis: fails naming file and entry | OK | message `"{rel} {where}: {req!r}"`; `test_a_deliberate_internal_entry_is_reported` asserts the `rel where:` prefix |
| genesis: any form (bare, pinned, direct reference), PEP 503 normalized | OK | 10 parse cases incl. `Genesis_Core>=0.79`, `genesis.core ==0.79.0`, `kiro_agent_sdk[dev]~=0.79`, marker, `name @ url`, `name@url`; my probe also: `genesis-core (>=0.79)`, `genesis-core;marker`, leading space → all named correctly |
| genesis: stdlib-only, no new dependency | OK | imports `re`, `shutil`, `tomllib`, `pathlib`, `pytest` (already a dev dep); no pyproject change |
| genesis: deliberate-mismatch on a copy (M1 fix text) | OK | `_copy_pyprojects(tmp_path)` + 5 parametrized edits, each asserting exactly one hit; `test_a_similar_external_name_is_not_reported` covers `genesis-workflows`, `genesis-coreutils` |
| workflows: four names only as `@ git+ssh://…/genesis.git@<tag>` | OK | `_GENESIS_URL`; probe: `git+https` and a sha ref are rejected; bare/pinned rejected by self-proof |
| workflows: `#subdirectory=` for the libraries | OK | probe: lib with wrong subdir → "subdirectory must be packages/genesis-core"; app with subdir → "(none, the app is the root)" |
| workflows: all on the same tag (L-057) | OK | probe: core@v0.80.0 + sdk@v0.79.0 → L-057 message; also across `dependencies` vs `optional-dependencies.dev` |
| workflows: enforced by `ci/validate_library.py` in `library-validate` | OK | `.gitlab-ci.yml:19` runs `python ci/validate_library.py`; gate failures append to `failures` → non-zero exit |

## Dev decisions

- **Tag must be `vX.Y.Z`, not a branch** — agreed. A branch pin makes CI non-reproducible and defeats L-057. Side
  effect: a pre-release tag (`v0.80.0rc1`) is rejected; Genesis has never tagged one, so fine.
- **Subdirectory exactly `packages/<name>`, none for the app; same repo URL as well as tag** — agreed; stricter than the
  spec's "same tag" and catches a split across two repos (probe: two hosts on v0.80.0 → rejected). See finding 2 for
  the one thing it does not pin.
- **Parser duplicated in each repo** — agreed. The two regexes are identical (`_NAME` / `_REQ_NAME`), ~5 lines; sharing
  would make genesis-workflows CI depend on a genesis release that contains the helper (chicken-and-egg on this very
  branch). Drift risk is small and both sides have positive/negative coverage.
- **No pytest file in genesis-workflows; in-process self-proof on 5 known-bad entries** — acceptable pattern (gate 6
  does the same), but the self-proof only covers the single-entry paths. See finding 1.

## Checklist

### ADRs
- [N/A] ADR-001, 003, 005, 006, 007, 010, 012, 014, 015, 017, 018, 020, 021, 022, 029, 030, 031, 033, 034, 035, 036,
  037, 038, 039, 041, 045, 048, 056, 057, 058, 059, 061, 062, 063, 065, 067, 068, 069, 073, 074, 075, 076, 078 — the
  change touches no workflow, graph, node, state, registry, chat, KB, stage or runtime code; only a genesis test file
  and a library CI validator gate reading `pyproject.toml`.
- [OK] ADR-011 — the reliability trio gate (gate 3) and its fixture self-proof are untouched and still run:
  `OK: reliability lint correctly fails the non-compliant fixture` in this run.
- [OK] ADR-019 — the compat gate is `genesis_core_major` in registry.json vs `CORE_MAJOR`; gate 9 checks pins only and
  does not replace or weaken it (validate_library still "PASSED (14 workflow(s) validated)").
- [N/A] ADR-026 — no network surface, bind or auth change.
- [OK] ADR-077 — this review used `genesis-ctx check` for rule selection; no bulk doc was read; no `--trust-all-tools`.

### Lessons
- [N/A] L-006, 009, 013, 017, 020, 021, 022, 023, 024, 026, 029, 033, 042, 045, 049, 053, 064, 075, 076 — no
  workflow/graph/chat/MCP code touched.
- [OK] L-025 / L-027 — no linter pin changed; genesis `ruff check genesis tests/test_no_internal_dependencies.py`
  → "All checks passed!". (genesis-workflows' unpinned `ruff>=0.6` is pre-existing and already tracked as a 50-07
  follow-up in its pyproject comment; CI runs no ruff there.)
- [N/A] L-030 — no `web/**` change.
- [OK] L-051 — git-tag shipping model is what gate 9 enforces (tag pins only, no branch).
- [OK] L-056 — not yet applicable (nothing committed); reminder for the commit: genesis must include the untracked
  `tests/test_no_internal_dependencies.py` (`git status` shows `??`), genesis-workflows the modified
  `ci/validate_library.py`. Verify with `git show --stat` before the push.
- [OK] L-057 — gate 9 makes "all internal pins on one repo + tag" a CI failure with an explicit L-057 message
  (probe evidence above). Current pyproject: all four on `genesis.git@v0.80.0` → accepted.
- [N/A] L-087, L-088 — no doc migration or shell guard.
- [OK] L-089 — the dev's deliberate-bad-line edits were each reverted in separate steps; working trees are as
  described (`?? tests/test_no_internal_dependencies.py`; ` M ci/validate_library.py`), and I left them unchanged.
- [OK] L-092 — the new genesis module is a real test file; its helpers are named `normalize`, `requirement_name`,
  `pyproject_paths`, `internal_entries`, `_copy_pyprojects` (none `test_*`); 18 tests collected, each once
  (1400 → 1418).

### Gates (re-run by the reviewer)
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **1418 passed** in 284.98s (new file alone: 18 passed).
- [OK] `cd genesis && .venv/bin/ruff check genesis tests/test_no_internal_dependencies.py` → All checks passed!
- [OK] `cd genesis-workflows && ../genesis/.venv/bin/python ci/validate_library.py` → "OK: internal-pin check correctly
  rejects 5 known-bad entries", "LIBRARY VALIDATION PASSED (14 workflow(s) validated)", exit 0.
- [OK] `cd genesis-workflows && ../genesis/.venv/bin/python ci/validate_skills.py` → PASSED (3).
- [OK] `cd genesis-workflows && ../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures` → **317 passed**.

Edge-case probe: an out-of-tree script in `/tmp` (deleted afterwards) imported `ci/validate_library.py` and the genesis
test module and fed them the cases quoted in the tables above. No repo file was written.

## Findings

### Blockers
None.

### Majors
None.

### Minors
1. **Gate 9's self-proof does not cover the L-057 rule it was added for.** `_BAD_PINS`
   (`ci/validate_library.py:61`) holds 5 single entries and main() checks each alone
   (`check_internal_pins({"dependencies": [bad]})`, line 197). The cross-entry rules (pins on different tags or repos)
   and the wrong-subdirectory paths (library under another library's subdir, app with a subdir) have no automated
   proof; I confirmed by probe that they work today, but a regression in the `pins` grouping (lines ~96–101) would pass
   CI silently. These rules are an explicit H1 requirement ("all on the same tag (L-057)"). Fix: make the self-proof
   take whole `[project]` tables, e.g. add
   `{"dependencies": [core@v0.80.0#subdirectory=packages/genesis-core, kiro-agent-sdk@v0.79.0#subdirectory=packages/kiro-agent-sdk]}`
   and `{"dependencies": [genesis-core@v0.80.0#subdirectory=packages/kiro-agent-sdk]}`, and assert each yields at
   least one problem. About 5 lines.
2. **Gate 9 runs after the CI install, so a name-only pin is still resolved from PyPI on the runner before the gate
   can fail it.** `.gitlab-ci.yml` `.setup.before_script` runs `pip install -e ".[dev]"` first, and
   `validate_library.py` needs that install (it imports `genesis.lint` at module top, line 31). A `"genesis-core>=0.79"`
   entry would make pip fetch (and build) the unrelated public package on the CI runner, then gate 9 reds the job.
   The merge is still blocked, which meets the spec's "the library-validate CI job enforces it"; the runner exposure
   remains. Also a tag mismatch usually fails earlier in pip with `ResolutionImpossible`, so the readable L-057 message
   shows mainly in local runs. Optional fix, now or as a follow-up: since gate 9 is stdlib-only, run it in a step
   before `pip install` (e.g. a tiny `ci/check_pins.py`, or a `--pins-only` mode with the genesis imports moved into
   `main()`).

### Nits
3. **Host is not pinned.** `_GENESIS_URL` accepts any `\S+/genesis.git` host: all pins on
   `git+ssh://git@evil.example/genesis.git@v0.80.0` pass (probe: a lone foreign-host pin → `[]`). The spec only names
   `…/genesis.git`, and the same-repo rule stops a split, so this is optional. If wanted, anchor the repo to
   `git@gitlab.appian-stratus.com/ramaswamy.u/genesis.git` (the CI `insteadOf` rewrite already assumes that host).
4. **A self-referential extra would be flagged by the genesis test.** `requirement_name("genesis[embeddings]")` →
   `genesis`, so a future root extra like `all = ["genesis[embeddings]"]` (a common pip pattern, resolved locally, no
   PyPI risk) would fail `test_no_pyproject_lists_an_internal_package`. None exists today, and failing closed is the
   right default; worth a one-line comment in the module docstring so the next person knows it's deliberate.

## Verdict: SHIP

No blockers or majors; every gate re-run green. H1 closes M1: the genesis test fails on any internal name in any
dependency list (normalized, every form, naming file and entry), and gate 9 limits genesis-workflows to tagged
`git+ssh` direct references into one genesis repo on one tag. Finding 1 is a small self-proof gap I recommend fixing
before the H1 commit (≈5 lines, no re-review needed beyond re-running `ci/validate_library.py`); findings 2–4 are
optional. Commit both files (L-056), then genesis-release pushes the branch for H1's own pipeline per 50-08 §5.
