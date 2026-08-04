# Phase 10 — CI

| | |
|---|---|
| **Depends on** | Phase 1 onward — **wire incrementally as phases land** (do not defer to the end) |
| **Outcome** | CI that runs the test suite, lints, and fails the build on contract drift or prose/subcommand mismatch |
| **Retires** | Nothing — this is the safety net that keeps the retirements honest |
| **Proposal refs** | §8 Phase 10; §2.1 (a11y `check_rule_refs.py` precedent) |

> Model this on the two CI gates already in the repo: `data-model-workflow`'s pytest suite and a11y's
> `check_rule_refs.py` (which fails the build on a dangling rule reference). The reference-integrity job is
> the direct analog for `dg` subcommands.

---

## 1. Objective
Make the guarantees of every prior phase enforceable in CI so they cannot silently regress.

## 2. What to build (add to `.gitlab-ci.yml`)

1. **Test + lint job** — run `pytest` and `ruff` over `<dg-root>/scripts/`. Use the `ruff.toml` pattern from
   `data-model-workflow`.
2. **Schema-lint job** — validate **every committed fixture** artifact against the Phase 0 schemas. This
   catches **contract drift** (a fixture that no longer matches the frozen schema).
3. **Reference-integrity job** (spirit of a11y's `check_rule_refs.py`) — fail the build if:
   - a step file names a `dg` subcommand that **does not exist**, or
   - a `dg` subcommand exists that **no step file invokes**.
   This enforces the Phase-8 "exactly one step references each subcommand" invariant.

## 3. Step-by-step (incremental)
1. As soon as Phase 1 lands, add the pytest+ruff job scoped to `scripts/`.
2. After Phase 0 fixtures exist, add the schema-lint job.
3. After Phase 8's prose rewrite, add the reference-integrity job.
4. Keep each job fast and independent so a failure points at one cause.

## 4. Done when
```shell
# an MR that renames a subcommand without updating the prose FAILS CI:
#   (reference-integrity job goes red)
# an MR that changes a fixture without updating the schema (or vice-versa) FAILS CI:
#   (schema-lint job goes red)
```
- ✅ An MR that renames a `dg` subcommand without updating the prose **fails CI**.
- ✅ A fixture/schema mismatch **fails CI**.
- ✅ `pytest` + `ruff` run on every MR touching `<dg-root>/scripts/`.

## 5. Risks & notes
- Wire CI **incrementally**, not as a big-bang final phase — each phase's tests should be running in CI by
  the time the next phase starts, or regressions slip in between phases.
- The reference-integrity job depends on a stable way to enumerate subcommands (e.g. `dg --list-commands`) and
  to scan the prose dir — build that enumeration into `dg` so the check isn't a brittle grep.

## 6. Program completion
When Phase 10 is green and the **program Definition of Done** (README §10 / tracker §3) holds — prose
< 1,700 lines, every subcommand referenced once, `⚠️` < 15, all three fixtures replay byte-identical, CI
fails on drift — the determinism conversion is complete. Reassess DEC-5 (whether full Option 4 was the
right endpoint or the Option-3 milestone sufficed).
