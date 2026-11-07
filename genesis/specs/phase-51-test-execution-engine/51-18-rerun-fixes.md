# 51-18 — Fixes from the 51-12 re-run

> **Status:** SPEC-DRAFTED 2026-11-05. Repos: **genesis** (backend + web), **genesis-workflows** (`action-capture`,
> `setup-composer`: shared checks only), **playwright-appian** (one test). Parent:
> `specs/phase-51-test-execution-engine.md`. Decision: 51-01 **D37**. Evidence for every item (file:line, repro, the
> reviewer's fix): `reviews/51-12-review.md` → **Re-run** section — read it first. Built after 51-17; then the
> reviewer re-reviews and runs live steps 1–27.

## 1. Goal

Close the re-run's major, minors, nits and the playwright-appian timeout, so 51-12 can SHIP once the live steps pass.

## 2. R-MJ1 — one reader for roles

- The generator reads a **setup's extra roles** and a **case's role** from `lib/scan-refs.mjs`'s output for the
  committed files (the scanner already reports `roles`; `RecordingService.library_snapshot` reads it that way). Remove
  `setup_extra_roles` and the regex `case_script_role` / `_CALLBACK_RE` path; every consumer (generator, Replay,
  readiness, verification scope, compose's m-3 check) goes through the one reader. A file the scanner cannot read keeps
  today's rule: its scenarios are not automated, with the reason.
- If the scanner does not yet report a case's role, extend it (the template's `scan-refs.mjs`, synced by `lib/`).
- Tests: setup names containing `async`, `function`, `=>`; a comment inside the roles array; a case with options in any
  order; a **parity test**: the generator's reading equals the scanner's on every setup and case fixture of both repos
  (cross-repo, run locally as in 51-16).

## 3. Minors

- **R-m1** — `RunManager.reconcile_status` leaves a `paused` record unchanged (as `fail_orphaned_runs` does). Tests: the
  reviewer's repro (`/tmp/genesis-review/51-12-rerun/probe_paused_reconcile.py`) as a regression test; pause → restart
  (fresh `RunManager`) → resume continues from the checkpoint.
- **R-m2** — before `replay` in `action-capture` and `setup-composer`, compare every library file (`actions/`,
  `setups/`, `cases/`, `lib/`) in the run's checkout with the export commit; any difference outside the proposals'
  own `proposed/` overlay fails the replay with the paths named (healing cannot override it). Test: an agent-modified
  transitive action leaves the setup Draft and the run reports why.
- **R-m3** — (a) the workspace template's `tsconfig.json` gains `noUnusedLocals: true` (an existing workspace gets it
  through "Update testing runtime"; the save typecheck then refuses an unused import). (b) `defineAction` wraps each
  call in `test.step('<ACT-key> <name>', …)`; the results parser records each action step's status; every proof
  (`promote_proven_actions`, the capture replay's per-proposal results, compose apply) promotes **only** the actions
  whose step ran and passed in that run, at the same code. Tests: an imported-but-uncalled action and an action in a
  branch not taken stay Draft; a called one is promoted.
- **R-m4** — `LIBRARY_TRANSITIONS` gains `(RETIRED, "restore") → DRAFT` for **actions** (audited, no precondition
  beyond the retire rules); setups keep restore → Ready with a passing Replay at the current hash. The item page's
  Restore says "Restored to Draft — Run dependents to make it Ready". Tests for both kinds.
- **R-m5** — `DELETE …/test-cases/{case_key}/script` (51-10 table + fixture) and **Remove script** on the case page
  (confirm dialog): one commit removing `cases/<TC>.ts`, `TestScriptStore.delete`, the refs for that file removed, the
  case `not-automated`; refused (409, naming them) while the case's own scenarios are mid-execution. Tests: route,
  page, jest-axe.

## 4. Nits and the playwright-appian test

- **R-n1** — `on_event` drops the killed worker's late events for any intended stop (pause or cancel), not only
  cancel. Test.
- **R-n2** — the finalizer runs `_promote_actions` through `self._defer` (off the run reader thread). Test.
- **R-O1** — playwright-appian `tests/cli/agent-act.test.ts` ("a ref without an address acts on the element…"):
  find why it slows under a full parallel run; if the cause is not quick to fix, give that test an explicit timeout
  with a comment naming the measured times. Its gates green in **three** consecutive full `npm test` runs. Recorded in
  its `DECISIONS.md` only if behaviour changes (D19). No version bump here: 51-13 releases 0.3.0 with it.

## 5. Gates

genesis pytest + ruff; the cross-repo tests locally; genesis-workflows `validate_library`, `validate_skills`, pytest;
web lint, tsc, vitest + jest-axe; `npm run build`, wait for the output to settle, commit `web/static` separately, then a
rebuild and an empty `git status` in its own call (L-089); playwright-appian lint, typecheck, `npm test` × 3.

## Context manifest

```toml
areas    = ["runs-worker", "workflows-library", "stories-workbench", "browser-testing"]
adrs     = ["ADR-009", "ADR-011", "ADR-050", "ADR-067"]
lessons  = ["L-011", "L-039", "L-058", "L-083", "L-089", "L-091", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/reviews/51-12-review.md", "tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-17-setup-composer.md", "tracker:specs/phase-51-test-execution-engine/adr-drafts.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/runs/manager.py", "genesis/genesis/domain/transitions.py", "genesis/genesis/api/testing.py", "genesis/genesis/kb/testexec_store.py", "genesis/web/src/features/testing/**", "genesis/web/src/features/test-design/**", "genesis-workflows/workflows/action-capture/**", "genesis-workflows/workflows/setup-composer/**", "playwright-appian/tests/cli/**"]
upstream = ["51-15", "51-16", "51-17"]
```
