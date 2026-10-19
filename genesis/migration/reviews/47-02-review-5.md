# 47-02 — Review 5 (genesis-migration-reviewer)

**Unit:** 47-02 — `gk` tooling and the migration agents
**Work under review:** project-tracker `5a6b474` (parent `2cad737` = report-only review-4 commit; prior fix `d263eca`; base tag `knowledge-migration-base` = `5b6201a`)
**Reviewer:** genesis-migration-reviewer · **Date:** 2026-10-20 · **Review #:** 5 (re-review after the review-4 fixes M1/P1/P2; closing review)
**Scratch:** `/tmp/genesis-migration-review/` (`adv.py`, `inv.csv`); `/tmp/gkold.el6m/` = gk tree with `2cad737:core.py` for test-first; `/tmp/kstore.*/` = fixture-store copies for end-to-end `gk validate`.
**Repo status start / end:** `git status --porcelain` **empty at start and end**; HEAD `5a6b474` throughout; no git writes; no `__pycache__`/`*.pyc` left (`python3 -B`, `PYTHONDONTWRITEBYTECODE=1`). Only new file is this report.

---

## 1. Verdict

**PASS.** 0 BLOCKER, 0 MAJOR, 0 MINOR, 1 PROCESS (carried, informational). The three review-4 findings are
genuinely fixed and confirmed test-first against the parent `2cad737`:

- **M1 (was MAJOR) — fixed.** The repo-version ERROR form now accepts the pin separators via
  `_PIN_SEP = (?:\s+|\s*(?:==|[@/:-])\s*)` and matches repo names **longest-first**. All six task-named pin forms
  plus the table/bold cases ERROR; end-to-end `gk validate` exits **1** on a doc that pins `genesis@v0.77.0`.
- **P1 (was PROCESS/latent) — fixed.** Pure integers are excluded from the exact tier in **both**
  `load_state_values` and `state_fact_scan`, so an integer state value (e.g. `1105`) no longer blocks prose
  (`port 1105`, `line 1234`).
- **P2 (was PROCESS/doc) — fixed.** The `core.py` catalogue docstring and the handoff §catalogue now state the
  exact tier runs after code/URL stripping and exempts them.

The `core.py` change is confined entirely to the state-fact tier; no other check (fates, batches, copycheck,
coverage, ledger validate, build) was touched or weakened. Suite is **98/98 OK** with **no earlier test removed or
weakened**. Scope is clean (only `gk` + `migration`); the four agents are byte-identical to `~/.kiro/agents` and
carry 0 files in this commit. The whole 47-02 Definition of Done is met — **the unit can close**. `F1` remains
correctly deferred to 47-05 (rules store / decision-log do not exist yet) and is not a finding against this unit.

## 2. Scope — expected vs produced

`git show --name-only 5a6b474` touches **only**: `genesis/tools/gk/{core.py,tests/test_core.py}` and
`genesis/migration/{PROGRESS.md,handoffs/47-02.md}`. No `genesis/agents/**`, nothing outside `genesis/`. Scope
requirement #4 satisfied. The four `genesis/agents/genesis-migration-*.json` are **byte-identical** (`diff -q`
IDENTICAL for extractor/writer/examiner/reviewer) to the installed `~/.kiro/agents/` copies and carry 0 files in
this commit.

## 3. Checks re-run (independently)

```
$ python3 -B -m unittest discover -s genesis/tools/gk/tests     → Ran 98 tests … OK
$ gk batches check            → OK: tiling exact-once, within cap (28 batches, 473 covered, max 199,721)
$ check_batches.py            → OK: every extract file covered exactly once; no overlaps/gaps; within limit
$ validate_schemas.py         → 5/5 schemas OK (each invalid example correctly rejected)
$ check_areas.py (GENESIS_CODE_ROOT=…/repo-gitlab/ramaswamy.u) → UNMATCHED 0 ; OK
$ gk inventory --out /tmp/.../inv.csv → 485 rows (473 extract, 12 archive-only); extract chars 4,861,472 lines 57,423
      diff vs committed genesis/migration/inventory.csv → IDENTICAL
$ gk validate (fixture + injected 'genesis@v0.77.0' pin) → "FAIL … repo version 'genesis@v0.77.0' outside state" exit 1
$ gk validate (clean fixture store)                      → exit 0
```
All numbers match the handoff review-4 block (98; 485/473/12 byte-identical inventory; 5/5 schemas; 0 unmatched).
No `__pycache__`/`*.pyc` left in `genesis/` after the runs.

**Test-count audit (92 → 98).** `grep -c "def test_"`: 92 at `2cad737`, 98 at `5a6b474` (+6). `comm -23`
(parent-minus-head test defs) is **empty** — **no test removed**. The six additions are all in `StateFactTests`
(M1: `test_error_repo_semver_separators`, `test_error_repo_longest_name_wins`, `test_positive_repo_name_alone_or_path`;
P1: `test_load_state_values_excludes_integers`, `test_exact_tier_ignores_pure_integers`,
`test_integration_integer_state_value_not_blocked`). The only edits to existing tests tighten them:
`test_error_exact_state_value` dropped its now-invalid integer assertion and uses a string state value, and
`test_integration_state_fact_error` switched its injected line from `genesis v0.69.0` (a strict-form hit) to the
exact value `v0.69.0` so it exercises the exact tier specifically. Neither weakens a check. `git diff` on `core.py`
shows the change is confined to the state-fact tier (`_REPOS_RE` sort, `_PIN_SEP`, the repo-version pattern, and
the two integer exclusions) plus docstring — no other check altered.

**Test-first (real, vs `2cad737:core.py` loaded in `/tmp/gkold.el6m`):**
- `test_error_repo_semver_separators` → **FAIL** on parent (`genesis@v0.77.0` → `[]`, not caught). Confirms M1.
- `test_load_state_values_excludes_integers` → **FAIL** (`1105` present in values). Confirms P1.
- `test_exact_tier_ignores_pure_integers` → **FAIL** (`state value '1105'`, `'1234'` emitted). Confirms P1.
  (`test_integration_integer_state_value_not_blocked` errored on the temp copy purely from the relocated
  `REPO_ROOT` schema path, not a result; the pure-tier assertion above already proves P1.)

## 4. Check audit

The two-tier mechanism is unchanged except for the three targeted fixes. The exact tier's integer exclusion is now
belt-and-braces (filtered at load **and** at scan), so a bare integer cannot reach the exact matcher by any path.
The ERROR repo form's longest-first ordering prevents `genesis-core`/`genesis-workflows` being mis-split on the new
`-`/`/` separators (verified: `genesis-core` → no error, `genesis-workflows v0.22.0` reported as genesis-workflows).
No way found to make `gk validate` exit 0 on a repo-version leak.

## 5. Adversarial runs (`/tmp/genesis-migration-review/adv.py`, real `core.state_fact_scan`)

**Must ERROR — all ERROR:** `genesis@v0.77.0`, `genesis==0.77.0`, `genesis @ v0.77.0`, `genesis-workflows==0.22.0`,
`kiro-agent-sdk/0.7.1`, `genesis-appian-parser:0.3.0`, pin in a table cell `| … genesis@v0.77.0 … |`, in bold
`**genesis@v0.77.0**`, and `genesis-core v0.9.8 is unchanged` (a state fact → correctly ERROR). ✔

**Must PASS (no error) — all PASS:** `genesis-core`, `genesis-core-v2`, `genesis/genesis/collab/service.py`,
`genesis-workflows/workflows/x`, `the genesis-2 branch`, `genesis - the platform`, `genesis: the platform`,
`genesis/web/src/version.ts`, the date `genesis 2026-10-15`. ✔ (Judge calls: `genesis-core-v2` has no three-part
semver so it is a name, not a pin — correct PASS; `genesis-2` is a one-part number after `-`, not semver — correct
PASS. `genesis - the platform` / `genesis: the platform` have no version token after the separator — correct PASS.)

**Catastrophic-backtracking:** 100K-char lines — whitespace run after `genesis` **0.017s**; 50K `"a "` words +
`genesis@` **0.021s**; `genesis` + 100K digits **0.014s**; `genesis-workflows ` + 20K×`v0.0.` **0.021s**. No
blow-up; `_strip_urls` is a linear tokenizer and the regex has no nested unbounded quantifiers.

## 6. High-stakes items

This unit writes **no knowledge units**, so source→ledger / ledger→source / new-doc sampling and MUST/ADR/LESSON
survival do not apply (as in reviews 1–4). The high-stakes surface is the checks themselves; the leak direction —
every repo/version/CI/runner/exact form, including the previously-leaking pin separators — is now caught, and
ordinary prose (ports, line numbers, dates, branch names, paths) is not mis-blocked. 27 adversarial cases checked,
27 OK.

## 7. Findings

| id | sev | evidence | problem | fix |
|---|---|---|---|---|
| **F1** | PROCESS | PROGRESS §Deferred checks records supersede-target existence for 47-05. | Correctly deferred (rules store / decision-log do not exist yet). No action this unit. | Re-resolve supersede rule-id targets once 47-05 inputs exist (already scheduled). |

No BLOCKER, MAJOR, MINOR. M1/P1/P2 from review-4 are closed (evidence in §3/§5).

## 8. Process improvements

- The review-4 process notes (pin separators belong in the ERROR tier; the exact tier is unsafe for bare integers)
  are now encoded in both the regex and the catalogue docstring — the method self-corrected. No new process gap.

## 9. Not verified / assumptions

- **No production store.** `genesis/knowledge/` does not exist until a later unit; `gk validate`/`build`/`budget`
  exercised on fixture-store copies only (M1 confirmed end-to-end on a fixture copy with an injected pin).
- **Agents:** unchanged by `5a6b474`; repo copies byte-identical to the four installed `~/.kiro/agents/` configs. I
  did **not** re-run the live `kiro-cli agent validate` / guardrail smoke tests (recorded in the handoff at
  review-1/2; configs are byte-identical and untouched since).
- **Earlier checks** (fates, batches, copycheck, context, applies_to, coverage, ledger validate, build) not
  re-exercised line-by-line beyond the green suite; `core.py` diff proves they are untouched by this commit.
- **Test-first** used `2cad737:core.py` in a relocated tree; the one integration test that errored did so from the
  moved `REPO_ROOT` schema path, not from a logic result.

## 10. Overall 47-02 Definition of Done (closing-review judgement)

| DoD item | Status | Evidence |
|---|---|---|
| All 47-01 review findings closed | **Met** | closed in reviews 1–3; suite green; no regression test removed/weakened (§3) |
| All unit tests pass incl. every negative | **Met** | 98/98 OK; `comm -23` shows 0 test defs removed; existing-test edits tighten, not weaken (§3) |
| `gk` commands behave (incl. `validate`) | **Met** | review-3/4 false positives gone; warnings printed & non-blocking; `validate` now exits **1** on repo-pin leaks `genesis@v0.77.0`/`==`/`/`/`:` (M1 fixed, §5); no way to pass a leak |
| Every agent passes `kiro-cli agent validate` + guardrail smoke | **Met** | recorded in handoff (reviews 1–2); four agents byte-identical to installed copies & unchanged by this commit |
| `install.sh` idempotent | **Met** | verified earlier; unchanged this commit |
| Scope: each commit changes only agent-writable paths | **Met** | `5a6b474` touches only `gk` + `migration` |

**Judgement:** All review-4 findings are fixed and confirmed test-first; no knowledge is lost or distorted; no
earlier regression test was removed or weakened; the ERROR tier now catches every realistic repo-pin separator
without over-blocking ordinary prose, with no backtracking risk; scope and agents are clean; every DoD item is met.
**Unit 47-02 can close.** The only open item is `F1`, correctly scheduled for 47-05.
