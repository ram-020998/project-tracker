# 47-02 — Review 3 (genesis-migration-reviewer)

**Unit:** 47-02 — `gk` tooling and the migration agents
**Work under review:** project-tracker `6560e32` (parent `374d56a`; previous fix `9d8494b`; original `83103e1`; base tag `knowledge-migration-base` = `5b6201a`)
**Reviewer:** genesis-migration-reviewer · **Date:** 2026-10-20 · **Review #:** 3 (re-review after the review-2 FAIL)
**Scratch:** `/tmp/genesis-migration-review/r3/` (`adv.py`, `adv2.py`; old-code copy under `gk_old/` with `REPO_ROOT` repointed at the real repo so schema-dependent tests run instead of erroring)
**Repo status start / end:** `git status --porcelain` **empty at start and end** (unchanged); HEAD `6560e32` throughout; no git writes; no `__pycache__`/`*.pyc` left in the repo (ran `python3 -B`, `PYTHONDONTWRITEBYTECODE=1`).

---

## 1. Verdict

**FAIL.** 0 BLOCKER, **2 MAJOR**, 0 MINOR, 2 PROCESS. S1, F2 and F3 from review-2 are each genuinely fixed and
test-first (every new test **fails on the parent `374d56a` code** and passes now); F1 is correctly recorded under
PROGRESS §Deferred checks for 47-05 (not a finding); the 92-test suite is green; all real-file checks pass; the
inventory regenerates **byte-identical**; the commit touches only `genesis/tools/gk/**` and `genesis/migration/**`
and the four agents are untouched and byte-identical to the installed copies. **But the F2 broadening of the CI-id
pattern introduced a serious regression:** `(?:gl|ci|job|run|pipeline)[-\s]#?\d+` now matches ordinary prose —
"run 2 of the pilot", "job 3", "run 5 of the rollout", "ci 3 of the matrix", "pipeline 2 stages" are all flagged as
CI ids and fail `gk validate`. These are exactly the imperative/procedural phrasings the knowledge store will
contain, so legitimate rule text is blocked (**M1, MAJOR**). Separately, the new `_strip_urls` (the S1 fix) is
incomplete: its markdown-link regex stops at the first `)`, so a link whose URL contains a parenthesis leaks the
tail of the URL back into the scan and a semver after the paren is flagged — i.e. the S1 class of false positive
still fires for URLs with parentheses (**M2, MAJOR**). Both are false positives that block legitimate prose, which
the task grades as MAJOR.

---

## 2. Scope — expected vs produced

`git show --name-only 6560e32` touches **only** `genesis/tools/gk/{core.py,tests/test_core.py}` and
`genesis/migration/{PROGRESS.md,handoffs/47-02.md}`. No `genesis/agents/**`, nothing outside `genesis/`. Scope
requirement #4 satisfied. The four `genesis/agents/genesis-migration-*.json` are **byte-identical** to the installed
`~/.kiro/agents/` copies (`diff -q` all IDENTICAL) and unchanged by this commit.

| Review-2 finding | Disposition | Reproducing test fails on parent `374d56a`? | Now |
|---|---|---|---|
| **S1** (MAJOR) semver in a URL | `_strip_urls` strips md-link targets/autolinks/bare URLs before the scan | `test_positive_semver_in_{md_link,bare_url,autolink}_allowed` → **FAIL on parent** (old flags it) | fixed for the common forms; **incomplete for URLs with parens → M2** |
| **F2** CI-id / test-count near-misses | `#\d{6,}`, `(?:gl\|ci\|job\|run\|pipeline)[-\s]#?\d+`, runner-word test counts | `test_negative_{hash_big_number,ci_space_number,job_space_number,vitest_count,jest_count}` → **FAIL on parent** | caught; **over-broad → M1** |
| **F3** (MINOR) nested/garbled verbatim reason | reason containing `<!--`/`verbatim:` → error, not exempt | `test_negative_nested_verbatim_reason_is_error` → **FAIL on parent** (old exempts it, no error) | fixed |
| **F1** supersede → nonexistent rule id | **deferred** to 47-05 | n/a | PROGRESS §Deferred checks (correct) |

## 3. Checks re-run (independently)

```
$ PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s genesis/tools/gk/tests   → Ran 92 tests … OK
$ gk batches check            → multi-entry boundary-checked 4; OK: tiling exact-once, within cap, boundaries safe
$ check_batches.py            → OK: every extract file covered exactly once; no overlaps/gaps; within limit
$ validate_schemas.py         → 5/5 schemas OK (invalid example rejected)
$ check_areas.py --code-root …/repo-gitlab/ramaswamy.u → UNMATCHED 0; exception-only 74; OK
$ gk inventory --out /tmp/.../inventory.csv → 485 rows (473 extract, 12 archive-only); chars 4,861,472 lines 57,423
      diff vs committed genesis/migration/inventory.csv → IDENTICAL
```
All numbers match the handoff (92 tests, 485/473/12, 4,861,472/57,423, 5/5, 0 unmatched, byte-identical inventory).

**Parent-code confirmation (test-first).** `git show 374d56a:genesis/tools/gk/core.py` has **no `_strip_urls`**.
Running the eight new S1/F2 `StateFactTests` + the F3 `CopycheckTests` test against the parent core (schema paths
repointed): **all fail on parent, all pass on HEAD.** The F3 test fails cleanly even schema-free
(`exemptions:[{…reason:'a <!-- verbatim: b'}], errors:[]` on parent).

## 4. Check audit — adversarial (fresh inputs; `r3/adv.py`, `r3/adv2.py`, real `core.validate_store`)

| Input (prose outside `state/`) | Expected | Result |
|---|---|---|
| `run 2 of the pilot` | allow | **FLAGGED `CI id 'run 2'`** → **M1** |
| `job 3` / `job 1` / `a job 7 in the queue` | allow | **FLAGGED `CI id 'job …'`** → **M1** |
| `run 5 of the rollout` / `Perform run 12 of the benchmark` | allow | **FLAGGED** → **M1** |
| `ci 3 of the matrix` / `gl 4 lane` / `pipeline 2 stages` | allow | **FLAGGED** → **M1** |
| `We run 2 jobs in parallel` / `Each run 3 times per the policy` | allow | **FLAGGED** → **M1** |
| `step 13`, `retry 3 times`, `a 2-run pilot` | allow | **allowed** (ok) |
| `GH Story id 120`, `port 8760`, `Phase 46`, `ADR-076` | allow | **allowed** (ok) |
| `` `m0024` `` (code span) | allow | **allowed** (ok) |
| md-link whose URL has a paren, semver **after** paren: `[docs](https://e.com/p_(v2)/v1.2.3/g)` | allow | **FLAGGED `version string 'v1.2.3'`** → **M2** |
| bare URL with paren + semver: `https://e.com/p_(v2)/v1.2.3/g` | allow | **allowed** (ok — greedy `\S+`) |
| md-link, semver **before** paren: `[docs](https://e.com/v1.2.3/p_(v2)/g)` | allow | **allowed** (ok) |
| reference-style link `notes[1]` + `[1]: https://e.com/v1.2.3/notes` | allow | **allowed** (ok) |
| `commit #1234567`, `issue #123456` | (decide) | **flagged** by `#\d{6,}` — **acceptable** (see note) |
| `migrations m0001-m0024` | (decide) | **flagged `migration id 'm0001'`** — **acceptable** (catalogue: migration ids in prose are state facts) |
| `pytest -q`, `pytest tests/test_x.py`, `go test ./...` | allow | **allowed** (ok — test-count needs `runner <digits>`) |
| CI leaks: `run #45678`, `pipeline 7087827`, URL-then-prose `… v0.77.0 shipped`, `go test 332`, `unittest 50` | flag | **all caught** (no missed leak) |

**No leak of a common real-world CI/version form was found** (BLOCKER threshold not reached). The two failures are
false *positives*, not false passes.

**`commit #1234567` / `issue #123456` — is flagging acceptable?** Yes. A commit id is not a CI id, but a bare
`#` + 6-plus digits is mechanically indistinguishable between CI run / issue / PR / commit-abbrev, and all of them
are volatile per-change references that should not be restated as timeless knowledge prose; the catalogue already
documents that short `#12` refs are allowed and long ones are caught. Flagging nudges the author to drop a
point-in-time ref or move it to a code span / link. Not a finding.

## 5. Samples

This unit writes **no knowledge units** (ledger/reconciled/knowledge do not exist until 47-04+), so
source→ledger / ledger→source / new-doc sampling and MUST/ADR/LESSON survival checks do not apply (as in reviews
1–2). The reviewed surface is the mechanical checks, audited adversarially above. Inputs are deterministic
constructions in `r3/adv.py` / `r3/adv2.py` (no RNG).

## 6. High-stakes items

High-stakes surface = the checks themselves. Correctly rejecting wrong input: fates (cycle/terminal/target),
batches (tiling/cap/archive/boundary), copycheck (empty/whitespace/nested-reason, unterminated marker, section
span), ledger validate, coverage, build --check, exact, applies_to lint, and the state-fact **leak** direction
(every CI/version/test-count leak probed was caught). The defects are on the false-positive side of `gk validate`
(M1, M2) — they do not lose or distort knowledge, but they would reject legitimate docs.

## 7. Findings

| id | sev | evidence | problem | fix |
|---|---|---|---|---|
| **M1** | **MAJOR** | `core.py` L75 `STATE_FACT_PATTERNS`: `re.compile(r"\b(?:gl\|ci\|job\|run\|pipeline)[-\s]#?\d+\b", re.I)`. `r3/adv.py`/`adv2.py`: `run 2 of the pilot`→`CI id 'run 2'`; `job 3`,`job 1`,`job 7`; `run 5/12`; `ci 3`; `gl 4`; `pipeline 2`; `We run 2 jobs`; `Each run 3 times` all → `… outside state/current.yaml`, `gk validate` exit 1. | The F2 broadening added a **space** separator and **no digit-length floor** to the ambiguous words `run/job/ci/gl` (and kept `pipeline\s+\d+` from review-2). `run <n>`, `job <n>`, `ci <n>` with a short number are ubiquitous in imperative rule/procedure prose, so `gk validate` blocks legitimate knowledge text. (Review-2's narrower `(gl\|ci\|job\|run)-\d+` hyphen-only form did **not** have this problem; the regression was introduced by `6560e32`.) | Require a disambiguator for the space form: keep `(?:gl\|ci\|job\|run\|pipeline)-\d+` (hyphen) and `(?:pipeline\|run\|job\|ci)\s*#\d+` (explicit `#`), and gate any bare-space form on a long id, e.g. `(?:pipeline\|ci\|job\|run)\s+\d{5,}` — not a 1–3 digit count. Add negative tests `run 2 of the pilot` / `job 3` **allowed** and keep `run #45678` / `pipeline 7087827` flagged. |
| **M2** | **MAJOR** | `core.py` L1082 `_strip_urls`: `re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)`. `r3/adv2.py`: `core._strip_urls("[docs](https://e.com/p_(v2)/v1.2.3/g)")` → `'docs/v1.2.3/g)'`; validate then flags `version string 'v1.2.3'`. Bare URL with the same paren is fine (greedy `\S+`). | The markdown-link target class `[^)]*` stops at the **first** `)`, so a link whose URL contains a parenthesis is only partially stripped and the semver after the paren is scanned — a residual instance of the exact S1 false positive (semver inside a URL) the fix was meant to remove. Trigger is narrow (md-link + `(` in URL + semver after it) but it is a genuine false positive on legitimate linking prose. | Strip the whole URL token first (run the bare-URL/autolink subs **before** the md-link sub, or match the md-link URL to the matching close-paren / to whitespace), e.g. drop `\]\(\s*<?(?:https?\|ftp)://[^)\s]*` greedily then clean the trailing `)`. Add a positive test: md-link whose URL contains `()` and a semver → allowed; keep `[genesis v0.77.0](…)` link-**text** flagged. |
| **F1** | PROCESS | PROGRESS §Deferred checks records the supersede-target existence check for 47-05. | Correctly deferred (rules store / decision-log do not exist yet). No action this unit. | Re-resolve supersede rule-id targets once 47-05 inputs exist (already scheduled). |
| **F2'** | PROCESS | `#\d{6,}` flags `issue #123456` / `commit #1234567`; `m0001-m0024` flags the range start. | Documented heuristic cost (acceptable, §4), but the catalogue in the handoff/core docstring should explicitly list "a bare `#` + 6-plus digits (issue/PR/commit refs) and migration ids in prose are flagged" so authors aren't surprised. | One line in the catalogue; already mostly covered — just name issue/commit refs explicitly. |

## 8. Process improvements

- **P-A (= M1 root)** — broadening a heuristic by adding a **space** separator to ambiguous English words
  (`run`, `job`, `ci`) without a digit-length floor trades a rare leak for a common false positive. The method
  should prefer an explicit disambiguator (`#`/hyphen) or a length gate over matching bare `word <small-number>`,
  and every pattern broadening should ship with a **positive** (allowed-prose) test alongside the negative, not
  only negatives. The review-2 F2 fix added only negative tests (`vitest 332`, `job 7087827`) and three positives
  that happen not to hit the new words — it never tested `run 2` / `job 3`, the forms the task itself named.
- **P-B (= M2 root)** — `_strip_urls` orders the md-link sub **before** the bare-URL sub, so a paren in a URL
  defeats it; stripping the raw URL token first (bare/autolink) and only then collapsing `[text](…)` would avoid
  the whole class. A "URL containing a parenthesis" case belongs in the normalisation test set.

## 9. Not verified / assumptions

- **Old-code run:** `374d56a:core.py` relocated to `/tmp` misresolves `SCHEMA_DIR`; I repointed `REPO_ROOT` at the
  real repo (read-only copy) so the schema-dependent `StateFactTests` run and **fail** rather than error. The F3
  copycheck test is schema-free and fails cleanly regardless.
- **`gk validate`/`build`/`budget`:** exercised on the fixture store only; `genesis/knowledge/` does not exist
  until a later unit, so M1/M2 are **latent** today (no production docs to block) but are reproducible defects in
  the shipped check that will fire as soon as 47-03+ write packs/procedures containing ordinary `run N`/`job N`
  prose or parenthesised doc links.
- **Agents:** unchanged by `6560e32` (no agent file in the commit); repo copies byte-identical to the four
  installed `~/.kiro/agents/genesis-migration-*.json`. I did not re-run the live `kiro-cli` guardrail smoke tests
  (reviews 1–2 did; configs are unchanged).
- **47-01 findings / earlier review-1 & review-2 fixes:** not re-verified line-by-line this round; the suite is
  green and this commit does not touch those code paths (no regression observed).

## 10. Overall 47-02 Definition of Done (closing-review judgement)

| DoD item | Status | Evidence |
|---|---|---|
| All 47-01 review findings (M1–M4, P1, P3) closed | **Met** | closed in `9d8494b`/`83103e1`, confirmed review-1/2; no regression (suite green) |
| All unit tests pass incl. every negative test | **Met** | 92 tests OK; a negative per check |
| `gk` commands behave (A table) | **Met with defect** | all commands run; `validate` is **over-strict** — M1/M2 false positives block legitimate prose |
| Every agent passes `kiro-cli agent validate` + guardrail smoke test recorded in handoff | **Met** | recorded in handoff §DoD; agents unchanged & byte-identical to installed |
| `install.sh` idempotent | **Met** | verified review-2; unchanged |
| Scope: each commit changes only the agent-writable paths | **Met** | `6560e32` touches only gk + migration |

**Judgement:** 47-02 is substantially complete and durable on every axis **except** the correctness of the
`gk validate` state-fact guard, which — after the review-2 fixes — now produces two classes of false positive that
would reject legitimate knowledge docs (M1 common, M2 narrow). Because `gk validate` is a core DoD deliverable and
the task grades false positives that block legitimate rule text as MAJOR, the unit **cannot close** until M1 (and
M2) are fixed with positive allowed-prose tests. No knowledge is lost or distorted and no real leak was missed;
this is purely over-strictness in the newly-broadened guard.
