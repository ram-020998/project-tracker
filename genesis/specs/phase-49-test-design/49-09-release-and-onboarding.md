# 49-09 — Release and onboarding

> **Status:** ✅ DONE 2026-10-31 — released + deployed (§4 As run, genesis-release); docs write-back done (genesis-docs,
> `progress/phase-49-test-design.md`). Spec-drafted 2026-10-26. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-49-test-design.md`. After 49-08 = SHIP. **genesis-release** asks before every tag and push; then
> **genesis-docs** does the write-back.

## 1. Release order

What ships (49-08 = SHIP 2026-10-30, `reviews/49-08-review.md`; H4 = SHIP, `reviews/49-08-H4-review.md`): **genesis**
`b9e9487..5da9916` — **15** commits ahead of `origin/master` (49-02, 49-05, 49-04, 49-06, H1, 49-07 ×4, H2, H3 ×4,
H4 `5da9916`); **genesis-workflows** `325cc23` + `9cb061f` — 2
commits (49-03 and the duplicate-test-module fix, `specs/bugs/workflows-duplicate-test-module-names.md`). All are
local only; GitLab has a backup copy on `backup/phase-49-wip` (genesis at `d62ae03`, genesis-workflows at `9cb061f`).

1. **genesis v0.79.0** (minor; m0025, DB 24 → 25). Bump `pyproject.toml` `[project].version`, the `create_app`
   version, `web/src/version.ts`; `npm run build` + commit `web/static/` (separate sequential steps, L-089). Pins
   unchanged: genesis-core v0.9.8, kiro-agent-sdk v0.7.1, genesis-appian-parser v0.3.0. Without the new workflow the
   stage start returns the friendly "not installed" 409 (L-033).
2. **genesis-workflows v0.23.0**: new `test-design-analysis` v0.1.0 + `registry.json` entry (already committed in
   `325cc23`); move its genesis **dev pin** to v0.79.0 and keep `genesis-core@v0.9.8` (L-057).
3. For each: verify the release commit contains every changed file (L-056); tag; push on the user's go-ahead; CI green
   (genesis: genesis, frontend, clean-install; workflows: validate + pytest — its full-library count is now **305**, down
   from 331, because the duplicate-module fix stopped double-running 37 tests and started 11 that never ran).
4. After both `master` pushes and green CI, delete the backup branches (`git push origin --delete
   backup/phase-49-wip` + `git branch -D backup/phase-49-wip` in each repo) — ask first.

## 2. Deploy

State before deploy: **main** already runs the `d138078` checkout with its DB at **v25** (migrated during 49-08; v24
backup at `/tmp/genesis-review/backup/genesis-v24.db`); **userb** still runs v0.78.0 on DB v24 and migrates on its
first v0.79.0 start. Main holds 49-08 acceptance data on features 4 and 6 (the user decides whether to keep it).

Never restart while a run is active (`GET /api/runs?status=running` per instance). Fleet update as usual
(`gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`), then `genesis install` of
`test-design-analysis` on each instance (from the released library, replacing main's `--from ../genesis-workflows`
local install); verify `/openapi.json` `info.version` = 0.79.0, DB v25, and `GET /api/features/<id>/test-suite` answers.

## 3. Docs write-back (genesis-docs)

- **ADRs:** add **ADR-078** (Test Design stage + test model; amends ADR-056) and **ADR-079** (test traceability +
  test impact analysis) from the umbrella §12 via `genesis-ctx add adr`; tag areas `features-stages,
  stories-workbench, workflows-library` / `stories-workbench, kb-sync, features-stages`.
- **Areas:** add the new code paths to `context/areas.toml` so path routing finds them
  (`genesis/genesis/kb/testdesign.py`, `services/testdesign_stage.py`, `services/testimpact.py`, `api/testdesign.py`
  → features-stages + stories-workbench; **`genesis/genesis/domain/**`** — unmapped today, so `genesis-ctx check` misses
  ADR-050 on lifecycle changes (49-02 As built) → features-stages + stories-workbench; `services/testimpact.py` and the
  already-unmapped `kb/_graph_reads_mixin.py` → **kb-sync** too (49-05 As built: `check` missed the kb-sync rules);
  `web/src/features/test-design/**` → features-stages (still unmapped after H4 — H4 review n1);
  `genesis-workflows/workflows/test-design-analysis/**` is already under workflows-library). Consider a new
  `testing` area if Part 2 is next.
- `context/state/current.md` (versions, DB v25, test counts, "what works": Test Design stage, Tests tab, case/scenario
  pages, Test Impact tab); code map; `progress/phase-49-test-design.md`; `changelog.md`; README row 49 → SHIPPED;
  tracker §6; `bible/08` §9 pointer to `specs/backlog/phase-49-follow-ups.md`; lessons from the build via
  `genesis-ctx add lesson`. `genesis-ctx index && lint` green.

## 4. As run

### As run (2026-10-31, genesis-release) — §1 release + §2 deploy

- **Versions:** genesis **v0.79.0** (m0025, DB v25), genesis-workflows **v0.23.0** (`test-design-analysis` 0.1.0). Not
  released (pins unchanged): genesis-core v0.9.8 (`CORE_MAJOR=1`), kiro-agent-sdk v0.7.1, genesis-appian-parser v0.3.0.
- **genesis release commit `908e5d4`** (on `5da9916`; pushed `df9011d..908e5d4`, 16 commits). Bumped all four version
  locations: `pyproject.toml` `[project].version`, the `create_app` version (`genesis/api/app.py`), `web/src/version.ts`,
  `README.md` status line (as the v0.78.0 release did). `npm run build` then a separate commit of `web/static/` (65 files).
  L-056: `git diff 5da9916 908e5d4` outside `web/static` = exactly those 4 files; `git status` empty after commit.
  L-089: a fresh `npm run build` afterwards left `git status --short --untracked-files=all` empty. Local gates on the
  release commit: pytest **1366 passed**, `ruff check genesis` clean.
- **genesis-workflows release commit `04c242e`** (on `325cc23` + `9cb061f`; pushed `a19153a..04c242e`, 3 commits).
  `pyproject.toml` only: version 0.22.0 → 0.23.0; genesis dev pin v0.77.0 → **v0.79.0**; genesis-core runtime pin stays
  **v0.9.8** = genesis v0.79.0's own core pin (L-057, chain consistent). Local gates: `validate_library` 14 workflows,
  `validate_skills` 3 skills, pytest **305 passed** (matches §1.3).
- **Tags** (annotated, each asked + confirmed; pushes asked + confirmed): genesis `v0.79.0` → `908e5d4`;
  genesis-workflows `v0.23.0` → `04c242e`. The first workflows `master` push hit an SSH connect timeout (nothing
  transferred); the retry succeeded. No force-push, no tag moved.
- **CI (all green):**
  - genesis master pipeline **7256473**, tag `v0.79.0` pipeline **7256474**: genesis, frontend, clean-install all success
    (the frontend job ran; the release touched `web/**`, L-030).
  - genesis-workflows master pipeline **7256701**, tag `v0.23.0` pipeline **7256702**: library-validate,
    skills-validate, workflow-tests success; workflow-tests job 81430762 reports **305 passed**.
- **§1 step 4 (asked + confirmed):** `backup/phase-49-wip` deleted on origin and locally in both repos (genesis local
  was at `f0df126`, workflows at `9cb061f`; both verified ancestors of the pushed `master` first).
- **§2 deploy (user go-ahead):**
  - Pre-checks: `GET /api/runs?status=running` → `total: 0` on :8760 and :8761.
  - Backups (SQLite online backup, source opened read-only; `integrity_check` ok):
    `/tmp/genesis-release-49/main-genesis-v25.db` (v25) and `/tmp/genesis-release-49/userb-genesis-v24.db` (v24).
    The older v24 copy of main remains at `/tmp/genesis-review/backup/genesis-v24.db`.
  - `gsm provision --all --no-mcp --no-env --force` (14 workflows from the checkout at `v0.23.0`) → `gsm restart --all`
    (main pid 87926, userb pid 87938) → both healthy.
  - `genesis install test-design-analysis --ref v0.23.0` on each instance via `gsm exec` (GitLab, the released
    library; replaces main's earlier `--from ../genesis-workflows` install). Both lockfiles: `test-design-analysis`
    0.1.0 `ref v0.23.0`, `genesis_core` 0.9.8 major 1. userb's GitLab token was present, so no `--from` fallback needed.
  - Verified: `/openapi.json` `info.version` = **0.79.0** on both; `schema_migrations` max = **25** on both (userb
    migrated 24 → 25 on start); `GET /api/features/6/test-suite` and `/4/test-suite` on main → 200 with suites 1 and 2
    (49-08 acceptance data **kept**, per the user); `GET /api/features/1/test-suite` on userb → 200 (`suite: null`,
    31 uncovered stories — no test design yet, as expected).
- **Process notes:** in a few tool batches I issued a read-only check next to the mutating step it verified (tag
  create + `rev-list`; mkdir + backup; provision next to the run check; restart + status). Each check was re-run or its
  result proves ordering (new PIDs, tag resolved, backup file written); no order-dependent mutation ran out of order.
  The rule (L-089) still applies — one mutating step per call, verification after.
- **Deferred / follow-ups:** §3 docs write-back (genesis-docs): ADR-078/079, `areas.toml` routes, `current.md`
  (genesis v0.79.0, genesis-workflows v0.23.0 with dev pin genesis@v0.79.0, DB v25, genesis pytest 1366, workflows
  pytest 305 + `validate_library` 14), code map, progress, changelog, README row 49, tracker §6, `bible/08` §9 pointer.
  Web vitest count was not re-run in this session (CI frontend job green). The `/tmp` backups can be removed once the
  user is satisfied.

### As run (2026-10-31, genesis-docs) — §3 write-back

- ADR-078 (amends ADR-056) and ADR-079 added as **Accepted**; `areas.toml` maps the §3 paths (incl. `domain/**`,
  `kb/_graph_reads_mixin.py`, `web/src/features/test-design/**`); no `testing` area (Phase 50 is next, not part 2).
- Lessons L-091–L-097 added; L-011, L-058, L-075, L-089 (rule now covers verifying reads), L-090 extended; decisions
  in `progress/phase-49-test-design.md` §Lessons. Backlog items 14–16 added. The 49-04 As built's pre-H1 note is marked
  superseded. Skills `genesis-release`, `genesis-web-dev`, `genesis-doc-writeback` updated (run `agent-system/update.sh`).
- `state/current.md`, code map (`bible/03` Phase 49 block + `tags/codemap.toml`), changelog, README row 49, tracker
  status + §6, `bible/08` §9 pointer. `genesis-ctx index && lint` green.

## Context manifest

```toml
areas    = ["release-ci", "distribution", "db"]
adrs     = ["ADR-019", "ADR-046", "ADR-077"]
lessons  = ["L-030", "L-033", "L-056", "L-057", "L-089"]
code     = ["genesis/pyproject.toml", "genesis/web/src/version.ts", "genesis-workflows/pyproject.toml", "genesis-workflows/registry.json"]
docs     = ["tracker:specs/phase-49-test-design.md", "tracker:specs/backlog/phase-49-follow-ups.md"]
upstream = ["49-08"]
```
