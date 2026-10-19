# 47-02 — Review 4 (genesis-migration-reviewer)

**Unit:** 47-02 — `gk` tooling and the migration agents
**Work under review:** project-tracker `d263eca` (parent `ec2b7c3` = report-only; prior code `6560e32`; earlier fixes `9d8494b`; original `83103e1`; base tag `knowledge-migration-base` = `5b6201a`)
**Reviewer:** genesis-migration-reviewer · **Date:** 2026-10-20 · **Review #:** 4 (re-review after the two-tier redesign of the state-fact check ordered by the orchestrator)
**Scratch:** `/tmp/genesis-migration-review/` (`adv.py`; `oldcore/oldcore.py` = `6560e32:core.py` for test-first confirmation; `kstore.XXXX/` copies of the fixture store)
**Repo status start / end:** `git status --porcelain` **empty at start and end**; HEAD `d263eca` throughout; no git writes; no `__pycache__`/`*.pyc` left (ran `python3 -B`, `PYTHONDONTWRITEBYTECODE=1`). The only new file is this report.

---

## 1. Verdict

**FAIL.** 0 BLOCKER, **1 MAJOR**, 0 MINOR, 2 PROCESS. The redesign is otherwise faithful and strong: the two
review-3 MAJORs are genuinely fixed (both inputs flagged on the prior code `6560e32`, both allowed now); the
two-tier split matches the ordered design; warnings are printed by `gk validate` and are non-blocking (exit 0);
all real-file checks pass and the inventory regenerates byte-identical; scope is clean (only `gk` + `migration`);
the four agents are byte-identical to the installed copies and untouched by this commit; the suite is 92/92 OK and
**no earlier regression test was deleted or weakened** (the 92→92 count is explained below). **But** the ERROR-tier
"known repo + semver" strict form only matches a **whitespace** separator, so the dependency-**pin** forms
`genesis@v0.77.0` / `genesis==0.77.0` / `genesis-v0.77.0` — one of which (`genesis@v0.77.0`) the task names
explicitly as a leak that *must error* — are **not blocked**; they fall through to a non-blocking WARNING, so
`gk validate` exits 0 on a doc that pins a repo version (**M1, MAJOR**). Because `gk validate` is a core DoD
deliverable and the ordered strict form ("known repo name + semver") naturally covers `@`/`==` pins, the unit
cannot close until the strict form accepts the common pin separators.

---

## 2. Scope — expected vs produced

`git show --name-only d263eca` touches **only**: `genesis/tools/gk/{core.py,gk.py,tests/test_core.py}` and
`genesis/migration/{PROGRESS.md,handoffs/47-02.md}`. No `genesis/agents/**`, nothing outside `genesis/`. Scope
requirement #4 satisfied. The four `genesis/agents/genesis-migration-*.json` are **byte-identical** (`diff -q`
IDENTICAL for extractor/writer/examiner/reviewer) to the installed `~/.kiro/agents/` copies and carry **0** files
in this commit.

## 3. The 92 → 92 question (test-count audit)

`grep -c "def test_"`: **92 at `6560e32`, 92 at `d263eca`.** The count is unchanged because the **entire
`StateFactTests` class was rewritten**: `comm` shows **23 state-fact tests removed** and **23 added** (net 0); every
other test class is byte-for-byte present (`comm -23` lists *only* state-fact names). I confirmed each review-1/2
regression test for the *other* checks still exists and still asserts its failure direction: `test_negative_merge_cycle`,
`test_negative_merge_self_cycle`, `test_negative_merge_chain_ends_at_{wrong,history}` (B1); `test_negative_{overlap,
gap,over_cap,archive_in_batch}` (batches M1); `test_negative_empty_verbatim_reason_is_error_and_copy_caught`,
`test_negative_nested_verbatim_reason_is_error` (copycheck M3/F3); `test_{valid,negative_invalid}_manifest` (context
m1); `test_live_globs_ok`/`test_negative_dead_glob` (applies_to P3). **None deleted, none weakened.**

The removed state-fact negatives (`test_negative_bare_semver`, `_prose_version_number`, `_gitlab_ci_id`,
`_migration_in_prose`) are **not** silent deletions: they were **demoted to WARNINGs by the ordered design**, and
each has a replacement (`test_warning_bare_semver`, `_version_number`, `_gitlab_id`, `_migration_in_prose`) that
asserts both `errs == []` **and** `warns != []` — i.e. the value is still surfaced, just non-blocking. The strict
negatives that stay ERRORs are re-expressed as `test_error_*` (repo semver, DB v, db_current_version, `#`/pipeline/
ci/job ≥6 digits, runner counts, link-text semver) plus a new `test_error_exact_state_value`. Not a finding.

## 4. Checks re-run (independently)

```
$ PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s genesis/tools/gk/tests   → Ran 92 tests … OK
$ gk batches check            → OK: tiling exact-once, within cap, boundaries safe
$ check_batches.py            → OK: every extract file covered exactly once; no overlaps/gaps; within limit
$ validate_schemas.py         → 5/5 schemas OK
$ check_areas.py (GENESIS_CODE_ROOT=…/repo-gitlab/ramaswamy.u) → OK: every tracked file maps to an area/exception
$ gk inventory --out /tmp/.../inv.csv → extract chars 4,861,472 lines 57,423 ; diff vs committed → IDENTICAL
$ gk validate (fixture store + injected WARN line)  → "WARN … bare version '1.2.3' (state-fact warning)" / "OK (1 warning(s))" exit 0
$ gk validate (fixture store + injected repo semver) → "FAIL … repo version 'genesis v0.77.0' outside state/current.yaml" exit 1
```
All numbers match the handoff (92; 485/473/12 inventory byte-identical; 5/5; 0 unmatched). Warnings are **printed
and visible** in `gk validate` output and do **not** change the exit code — the ordered WARNING behaviour is real.

**Test-first confirmation (real).** Loaded `6560e32:core.py` as `oldcore`:
- M2: `oldcore._strip_urls("See [docs](https://e.com/p_(v2)/v1.2.3/g) now.")` → `'See docs/v1.2.3/g) now.'`
  (leaks `v1.2.3`); HEAD allows it. 
- M1: `oldcore` `STATE_FACT_PATTERNS` flags `run 2 of the pilot` as `CI id`; HEAD allows it.
Both review-3 MAJORs genuinely reproduced on the prior code and are fixed now.

## 5. Design faithfulness vs the ordered two-tier spec

| Ordered element | Implementation (`core.py`) | OK? |
|---|---|---|
| ERROR = exact literal state value (len≥3, not plain int<1000) outside `state/` | `load_state_values` filters len<3 and `\d+`<1000; `state_fact_scan` matches `(?<!\w)value(?!\w)` | **yes** |
| strict: known repo + opt `v` + semver | `\b(?:genesis|genesis-core|genesis-workflows|kiro-agent-sdk|genesis-appian-parser)\s+v?\d+\.\d+\.\d+\b` | **separator gap → M1** |
| strict: `DB v<N>` | `\bDB\s+v\d+\b` (I) | yes |
| strict: `db_current_version` | `\bdb_current_version\b` | yes |
| strict: CI id ≥6 digits `#N`/`pipeline\|ci\|job #?N` | `#\d{6,}\b` + `\b(?:pipeline\|ci\|job)\s+#?\d{6,}\b` | yes (note: `run` correctly excluded per order) |
| strict: test-runner + count (not path/flag) | `\b(?:pytest\|vitest\|jest\|unittest)\s+\d+(?![\w./-])` | yes |
| WARNING = bare semver / version N / migration id / hyphenated CI id / bare count | 5 `STATE_WARN_PATTERNS` | yes |
| URLs stripped first (balanced parens), then md-link/ref-def/autolink; link text still scanned | `_strip_urls` tokenizer consumes balanced `()`, then collapses `[t](…)`; link text retained | yes |

**Exact-tier is genuinely exact (word-boundary verified):** with state value `0.77.0`, `10.77.01` and `x0.77.0y`
do **not** match; standalone `0.77.0` matches; `v0.77.0` does **not** (different literal → warning only). Correct.

**Code-span / URL exemption applies to the exact tier too** (the scan strips both before all tiers): a literal
state value inside `` `…` `` or a URL is allowed and not even warned. Defensible per the catalogue (code/URLs are
the two legitimate homes of a version-looking token) but worth documenting — see P2.

## 6. Adversarial runs (`/tmp/genesis-migration-review/adv.py`, real `core.state_fact_scan`, fixture `state_values={v0.69.0, 1234}`)

**Review-3 failing inputs — all now ALLOWED (0 errors):** `run 2 of the pilot`, `job 3`, `job 1`, `a job 7…`,
`run 5 of the rollout`, `Perform run 12…`, `ci 3 of the matrix`, `gl 4 lane`, `pipeline 2 stages`, `We run 2 jobs…`,
`Each run 3 times…`, md-link URL with `()` + semver, bare URL with `()` + semver, reference-style link. ✔

**Fresh legit prose — all ALLOWED:** `the second run`, `job 3 of 5`, `CI must be green`, `see pipeline docs`,
`pytest -k test_x`, `unittest discover`, `a 6-digit OTP 123456` (bare 6-digit, no `#`/runner → correctly allowed),
`retry 3 times`, `section 3.2`, `Python 3.11`, `HTTP 409 error`, `issue 12345`, `step 7`, `we ran 5 of 10 cases`. ✔

**Leaks — correctly ERROR:** `genesis v0.77.0`, `genesis-workflows v0.22.0`, `kiro-agent-sdk v0.77.0`, `DB v24`
(incl. line start), `db_current_version`, `#7087827` (incl. in a `## heading`), `pipeline/CI/job 7087827`,
`pytest 1105`/`vitest 332`/`jest 332`/`unittest 50`, `[genesis v0.77.0](url)` (link **text**), state value in a
table cell `| … v0.69.0 |`, in bold `**v0.69.0**`, exact `1234`. ✔

**Demoted to WARNING (per order) — surfaced, non-blocking:** `gl-9931`, `0.69.0`, `version 20`, `m0024`, `99 tests`. ✔

**Below the ordered ≥6-digit floor — ALLOWED (faithful to order):** `run #45678`, `pipeline #45678` (5 digits;
`run` is intentionally not in the CI-id word list). Correct per the ordered spec.

**FAILURES:**
- `genesis@v0.77.0`, `genesis==0.77.0`, `genesis-v0.77.0`, `genesis/0.77.0`, `genesis:v0.77.0`,
  `kiro-agent-sdk@0.77.0` → **warning only, no error** → **M1**.
- integer exact collisions `port 1234`, `line 1234`, `issue 1234`, `1234 widgets` → **ERROR** `state value '1234'`
  (false positive on ordinary prose that happens to cite an int state value ≥1000) → **P1** (latent; see below).

## 7. High-stakes items

This unit writes **no knowledge units** (no `ledger/reconciled/knowledge`), so source→ledger / ledger→source /
new-doc sampling and MUST/ADR/LESSON survival checks do not apply (as in reviews 1–3). The high-stakes surface is
the checks themselves; the leak direction (every repo/version/CI/runner leak probed) is caught **except** the
repo-pin separator forms (M1). No real leak of the *space* form or exact value was missed.

## 8. Findings

| id | sev | evidence | problem | fix |
|---|---|---|---|---|
| **M1** | **MAJOR** | `core.py` L84 `STATE_ERROR_PATTERNS[0]`: `rf"\b(?:{_REPOS_RE})\s+v?\d+\.\d+\.\d+\b"`. `adv.py`: `genesis@v0.77.0`→`errs=[]`, warns only; same for `genesis==0.77.0`, `genesis-v0.77.0`, `genesis/0.77.0`, `genesis:v0.77.0`, `kiro-agent-sdk@0.77.0`. End-to-end `gk validate` exits **0** on a pack line `genesis@v0.77.0`. | The ERROR-tier "known repo + semver" form matches a **whitespace** separator only, so the common dependency-pin separators (`@`, `==`, `-`, `/`, `:`) drop the leak to a non-blocking WARNING. The task names `genesis@v0.77.0` explicitly as a leak that must error; it does not. The ERROR tier is trivially bypassable (write `@` instead of space) for exactly the unambiguous repo-pin form the strict set is meant to catch. | Broaden the separator: `rf"\b(?:{_REPOS_RE})\s*(?:[@=:/ -]|==)\s*v?\d+\.\d+\.\d+\b"` (or `(?:\s+|@|==|[-/:])`). Add positive-direction error tests `genesis@v0.77.0` / `genesis==0.77.0` **must error**; keep `genesis` + prose number (non-semver) allowed. |
| **P1** | PROCESS | `load_state_values` keeps bare integers with `abs(int)>=1000`; `state_fact_scan` exact-matches them. `adv.py`: `port 1234`, `line 1234`, `issue 1234` → ERROR `state value '1234'`. | The ordered threshold ("not a plain int <1000") makes integer state values ≥1000 exact-matched, which **re-introduces false positives that block legit prose** — the very class the redesign removed — whenever a doc coincidentally cites that number (port, line, issue id, count). Latent today (no real `knowledge/state/current.yaml` exists); becomes a MAJOR-class false positive the moment `current.yaml` holds an integer scalar ≥1000. Implementer followed the order faithfully; the weakness is in the **ordered spec**. | Exclude pure integers from the exact tier entirely (match only values containing a non-digit, e.g. a `.`/`v`/`-`), or require a key-context (`<key>: <int>`) rather than a bare number, or raise the int floor well above typical ports/line numbers. Add a positive test `port <int-state-value>` must not error. |
| **P2** | PROCESS | `state_fact_scan` runs `_strip_urls(_strip_code_only(text))` before **all** tiers, incl. exact. A literal state value in a `` `code` `` span or URL is allowed and not warned. | Acceptable (code/URLs are legitimate homes of a version token) but the exact tier silently inherits the code/URL escape hatch — a reviewer may assume "exact value anywhere outside state/ errors". | One line in the catalogue/docstring: the exact tier also exempts code spans and URL targets; the human §6.2 review is the backstop. |
| **F1** | PROCESS | PROGRESS §Deferred checks records the supersede-target existence check for 47-05. | Correctly deferred (rules store / decision-log do not exist yet). No action this unit. | Re-resolve supersede rule-id targets once 47-05 inputs exist (already scheduled). |

## 9. Process improvements

- **P-A (= M1 root).** When a strict ERROR form keys off a named token (a repo), enumerate the **separators** that
  join it to the value (space, `@`, `==`, `-`, `/`, `:`) — a pin with `@`/`==` is *more* clearly a version fact
  than a space-separated mention, yet the narrower whitespace form let it through. Every strict form should ship a
  positive-direction leak test for each realistic separator, not only the whitespace case.
- **P-B (= P1 root).** "Exact literal value" is safe for strings but **not** for bare integers: an int is
  indistinguishable from a coincidental port/line/issue/count in prose. The exact tier should match only values
  that are not pure integers (or require a key/units context). The ordered `<1000` floor only narrows, not removes,
  the collision; the spec should say "exact match applies to non-integer scalars."
- **P-C.** The two-tier catalogue (handoff + `core.py` docstring) is excellent and matches behaviour; add the two
  caveats above (pin separators belong in ERROR; exact tier exempts code/URLs) so the next author/reviewer is not
  surprised.

## 10. Not verified / assumptions

- **No production store.** `genesis/knowledge/` does not exist until a later unit; `gk validate`/`build`/`budget`
  were exercised on the fixture store only. M1 and P1 are therefore **latent** (no real docs or real
  `current.yaml` to block/mis-block yet) but are reproducible defects in the shipped check.
- **Old-code test-first** used `6560e32:core.py` loaded directly (its `REPO_ROOT`/schema paths were not needed for
  `_strip_urls` / `STATE_FACT_PATTERNS`, which are pure).
- **Agents:** unchanged by `d263eca`; repo copies byte-identical to the four installed `~/.kiro/agents/` configs. I
  did **not** re-run the live `kiro-cli` guardrail smoke tests (reviews 1–2 did; configs unchanged).
- **Earlier review-1/2 fixes** (fates, batches, copycheck, context, applies_to) not re-exercised line-by-line; their
  regression tests are all present and the suite is green.

## 11. Overall 47-02 Definition of Done (closing-review judgement)

| DoD item | Status | Evidence |
|---|---|---|
| All 47-01 review findings closed | **Met** | closed earlier; suite green; no regression |
| All unit tests pass incl. every negative | **Met** | 92/92 OK; no earlier regression test deleted or weakened (§3) |
| `gk` commands behave | **Met with defect** | redesign fixes review-3 M1/M2; warnings printed & non-blocking; **but** `validate` exits 0 on repo-pin leaks (`genesis@v0.77.0`) — M1 |
| Every agent passes `kiro-cli agent validate` + guardrail smoke | **Met** | recorded in handoff; agents unchanged & byte-identical |
| `install.sh` idempotent | **Met** | verified earlier; unchanged |
| Scope: each commit changes only agent-writable paths | **Met** | `d263eca` touches only `gk` + `migration` |

**Judgement:** The two-tier redesign is a real improvement and faithful to the ordered design on almost every
axis — the two review-3 false positives are gone (test-first confirmed), the demotions are intentional and still
surface the value as a printed warning, no earlier regression test was lost, and the exact tier is genuinely exact
with correct word boundaries. It **cannot close** only because the ERROR-tier repo-semver strict form is
separator-narrow: the `genesis@v0.77.0` / `genesis==0.77.0` pin forms (one explicitly named by the task as
must-error) slip to a non-blocking warning, so `gk validate` passes a doc that pins a repo version (**M1,
MAJOR**). Fixing the separator (and tightening the integer exact-match per P1) closes the unit. No knowledge is
lost or distorted.
