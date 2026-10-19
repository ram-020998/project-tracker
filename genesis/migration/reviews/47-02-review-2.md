# 47-02 — Review 2 (genesis-migration-reviewer)

**Unit:** 47-02 — `gk` tooling and the migration agents
**Work under review:** project-tracker `9d8494b` (parent `20444e4`; original 47-02 work `83103e1`; base tag `knowledge-migration-base` = `5b6201a`)
**Reviewer:** genesis-migration-reviewer · **Date:** 2026-10-20 · **Review #:** 2 (re-review after the review-1 FAIL)
**Scratch:** `/tmp/genesis-migration-review/r2/` (adversarial harnesses `adv.py`, `batchmut.py`; old-code probe under `oldcode/`)
**Repo status start / end:** `git status --porcelain` empty at start **and** end (unchanged); HEAD `9d8494b` throughout; no git writes; no `__pycache__`/`*.pyc` left in the repo (ran `python3 -B`, `PYTHONDONTWRITEBYTECODE=1`).

---

## 1. Verdict

**FAIL.** 0 BLOCKER, **1 MAJOR**, 1 MINOR, 4 PROCESS. All six review-1 findings (B1, M1, M2, M3, m1, P3/P1/P2) are
genuinely and durably closed: each has a reproducing test that **fails on the old code** (I ran the new tests against
`83103e1:core.py` and probed the old functions directly) and passes now; the 77-test suite is green; every `gk`
command runs clean on the real migration files; the inventory still regenerates **byte-identical** to the committed
CSV; batch mutations (overlap/gap/over-cap/archive) are all caught; boundary safety still catches mid-paragraph and
mid-fence splits; the agents are untouched by the fix and remain byte-identical to the installed copies. The single
new defect is a **false positive** in the state-fact guard: a semver that appears **inside a URL** (markdown link or
bare) is flagged as a per-release state fact and fails `gk validate`, which would block legitimate knowledge prose
that links to a versioned URL. The task brief explicitly names "a semver inside a code span **or URL**" as a
false-positive case and grades a false positive that blocks legitimate rule text as MAJOR; the code exempts the code
span but not the URL. The fix is one line (strip URLs before the state-fact scan, mirroring the existing code-span
strip). Everything else is PROCESS/MINOR.

---

## 2. Scope — expected vs produced

`git show --name-only 9d8494b` touches **only** `genesis/tools/gk/**` (core.py, gk.py, tests/test_core.py) and
`genesis/migration/**` (PROGRESS.md, handoffs/47-02.md, schemas/coverage.schema.json, scripts/check_batches.py).
Nothing in `genesis/agents/**` or outside `genesis/`. Scope requirement #5 satisfied. `git diff --stat 83103e1
9d8494b -- genesis/agents/` is empty (agents unchanged since the original work).

| Review-1 finding | Fix present | Reproducing test fails on old code | Now |
|---|---|---|---|
| **B1** fate cycle/strand | `check_fates` walks each merge/supersede chain, reports cycles + non-surviving terminals | `FateGraphTests` → 4 **FAIL** on `83103e1` | caught |
| **M1** `gk batches` no tiling/cap | single `check_batches_all`; `gk` + `check_batches.py` both call it | old `core.check_batches_all` **ABSENT** | caught |
| **M2** narrow state-fact guard | `STATE_FACT_PATTERNS` extended; code stripped first | old: `pipeline #45678`, `gl-9931`, `db_current_version`, bare `0.69.0` all **leak** | broadened (see MAJOR below) |
| **M3** empty-reason verbatim hides copy | empty reason → error, not exempt; exemptions listed | old `copycheck` returns a bare list, copy **hidden**, no error | caught |
| **m1** context never validated | `if False` removed; schema-validates `{context: …}` | old gk.py still has `if False` dead branch | caught |
| **P3** dead `applies_to` glob | `validate_store(repo_files=…)` lint | old `validate_store` sig `(knowledge)` — no param | caught |

---

## 3. Checks re-run (independently)

```
$ PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s genesis/tools/gk/tests   → Ran 77 tests … OK
$ gk batches check            → 28 batches (P2, B26); 473/473 covered; max 199,721 ≤ 200,000; boundary-checked 4; OK
$ check_batches.py            → same core.check_batches_all → OK
$ gk inventory --out /tmp/.../inventory.csv  → 485 rows (473 extract, 12 archive-only); 4,861,472 chars / 57,423 lines
     diff vs committed genesis/migration/inventory.csv → IDENTICAL
$ validate_schemas.py         → 5/5 schemas OK
$ gk rules --paths genesis/genesis/collab/service.py → areas: collaboration-hub, all; rules: (none)
$ gk validate --knowledge <fixture store>  → OK
```
All numbers match the handoff (77 tests, 485/473/12, 4,861,472/57,423, 199,721, 5/5). `ledger`, `reconciled`,
`knowledge` do not exist yet (later units) — `gk fates`/`validate`/`build`/`budget` exercised on fixtures only, as
in review-1.

## 4. Check audit — adversarial (fresh inputs). Harnesses `r2/adv.py`, `r2/batchmut.py`

| Check | Fresh wrong/edge input | Result |
|---|---|---|
| fates | 3-unit merge cycle A→B→C→A | **caught** (`merge chain forms a cycle: … -> KU-A-0001`) |
| fates | long merge chain (7 hops) ending in `keep` | **passes correctly** (no error) |
| fates | supersede → missing KU `KU-ZZ-9999` | **caught** |
| fates | supersede → nonexistent rule id `ADR-999` | **PASSES** → **F1 (PROCESS)** — unverifiable at reconcile |
| fates | merge whose target has a different primary area | passes — not a spec requirement (no finding) |
| state | `Python 3.11`, `section 3.2`, `step 13`, `HTTP 409`, `version control`, `ADR-063`, date `2026-10-15`, semver in code span | **all correctly allowed** (no false flag) |
| state | **semver inside a URL** (md-link + bare) | **FLAGGED** → **MAJOR S1** (false positive blocks legit text) |
| state | `pipeline 7087827`, `genesis v0.77.0` in a table cell | **caught** |
| state | `#7087827`, `CI 7087827` (space), `vitest 332` | **leak (pass)** → **F2 (PROCESS)** — heuristic gaps |
| copycheck | verbatim reason of only whitespace | **caught** (error + copy still reported, hits=2, errors=1) |
| copycheck | verbatim marker + large copy in later paragraphs | **copy caught** (only the marked paragraph exempted; exemption listed) |
| copycheck | unterminated `<!-- verbatim: …` (no `-->`) | **copy caught** (not exempted) |
| copycheck | nested `<!-- verbatim: a <!-- verbatim: b --> -->` | exempts with reason `"a <!-- verbatim: b"` → **F3 (MINOR)** (visible exemption, not silent) |
| batches | real plan | **OK** |
| batches | overlap / gap / over-cap / archive-only-in-batch | **all 4 FAIL** (good) |
| applies_to | glob matching only a deleted/ignored (untracked) file | **caught** (`matches no file in the code repos`) |

## 5. Samples

This unit writes **no knowledge units** (ledger/reconciled/knowledge do not exist until later units), so
source→ledger / ledger→source / new-doc sampling and MUST/ADR/LESSON survival checks do not apply (as in review-1).
The reviewed surface is the set of mechanical checks, audited adversarially above. Seeds: fate/state/copy/batch
inputs are deterministic constructions in `r2/adv.py` and `r2/batchmut.py` (no RNG).

## 6. High-stakes items

The high-stakes surface here is the checks themselves. Checks that correctly reject wrong input: fates (cycle +
chain-terminal + target existence), batches (tiling/cap/archive/boundary), copycheck (empty/whitespace reason,
unterminated marker, section-span), ledger validate, coverage, build --check, exact, applies_to lint. Residual
holes: S1 (MAJOR, false positive), F1/F2 (PROCESS, unverifiable / heuristic), F3 (MINOR). None lose or distort
knowledge.

## 7. Findings

| id | sev | evidence | problem | fix |
|---|---|---|---|---|
| **S1** | **MAJOR** | `core.validate_store` state-fact scan uses `_strip_code_only(text)` (core.py ~L560) which strips code spans/fences but **not** URLs. `r2/adv.py` + direct probe: `See [docs](https://example.com/v1.2.3/guide).` and the bare URL both → `version string 'v1.2.3' outside state/current.yaml`; identical to a plain-prose semver. | A semver that is part of a **URL** (versioned doc/schema/release link) is a false positive and fails `gk validate`, blocking legitimate knowledge prose. The task brief lists "a semver inside a code span **or URL**" as a false-positive case; the code span is exempt, the URL is not. | Before the state-fact scan, strip URL tokens (and/or markdown-link targets) the same way code spans are stripped — e.g. remove `https?://\S+` and the `(…)` target of `MD_LINK_RE` from the text passed to `STATE_FACT_PATTERNS`. Add a positive test (semver-in-URL allowed) and keep the plain-prose-semver negative test. |
| **F1** | PROCESS | `check_fates` (core.py ~L430): `superseded`→`ADR-999` passes because any `(ADR\|LSN\|STD\|WA)-\d{3}` is accepted as a terminal. | A supersede pointing at a **nonexistent** rule id is unverifiable at reconcile time (no decision-log / rules store yet), so a typo'd ADR silently "survives". Correct given current inputs, but the knowledge is stranded if the rule never materialises. | Once `knowledge/rules/` + the decision-log exist, add a cross-check that every supersede rule-id target resolves; or feed `check_fates` a known-rule-id set when available. Note the limitation in the handoff/PROGRESS. |
| **F2** | PROCESS | `STATE_FACT_PATTERNS` (core.py ~L54): `#7087827`, `CI 7087827` (space, not hyphen), `vitest 332` (reversed test-count) all leak. | State-fact detection remains heuristic; the review-1 forms are now caught, but near-miss variants slip. Inherent to the approach (a bare `#number` is ambiguous with issue/PR ids). | Consider adding `\b(?:gl\|ci\|job\|run\|pipeline)\s+#?\d+\b` (space variant) and `\b(?:vitest\|jest\|pytest\|go test)\s+\d+\b`; document in the spec which state-fact forms are out of mechanical scope and rely on the §6.2 human backstop. |
| **F3** | MINOR | `_scan_doc` / `VERBATIM_RE` (core.py ~L255): `<!-- verbatim: a <!-- verbatim: b --> -->` is accepted with reason `"a <!-- verbatim: b"`. | A nested/garbage verbatim reason is accepted as a valid exemption. It is **listed** (P2) so it is not a silent copy-hiding hole, but the reason is malformed. | Flag a verbatim reason that itself contains `<!--` or `verbatim:` as an error (malformed/nested marker). |

## 8. Process improvements

- **P-A (= S1 root)** — the state-fact guard strips code but not URLs; the `validate` check conflates "a per-release
  fact asserted in prose" with "a version that happens to sit in a link target". Normalising away URLs (and
  markdown-link targets) before the scan removes a whole class of false positives.
- **P-B (= F1)** — `fates` cannot verify supersede targets that are rule ids until the rules store exists; the method
  needs a later gate that re-resolves those ids, otherwise a mistyped ADR supersede is never caught.
- **P-C (= F2)** — state-fact detection is heuristic by nature; the spec should state the catalogue of forms the
  mechanical check guarantees and defer the rest to §6.2 review, so a future reviewer isn't surprised by a leak.
- **P-D** — carried from review-1 P1: `coverage` ranges may overlap at the unit level (documented now in
  `coverage.schema.json`); exact-once tiling is enforced at the batch level by `check_batches_all` — verified (overlap
  mutation fails). Good.

## 9. Not verified / assumptions

- **Old-code test run:** relocating `83103e1:core.py` to `/tmp` makes `REPO_ROOT`/`SCHEMA_DIR` misresolve, so the
  schema-dependent new tests *error* rather than *fail* there (an artifact, not evidence). B1's `FateGraphTests`
  are schema-free and **FAIL** cleanly on old code; for M1/M2/M3/m1/P3 I confirmed the old behaviour by importing
  old `core.py` with the real repo paths patched in (`r2/oldcode/probe_old.py`) — old `check_batches_all` absent,
  old `validate_store` has no `repo_files` param and leaks every M2 form, old `copycheck` returns a bare list and
  hides the empty-verbatim copy, old gk.py keeps the `if False` branch.
- **`gk validate`/`build`/`budget` on the real store:** exercised on the fixture store only; `genesis/knowledge/`
  does not exist until a later unit. S1 is therefore a **latent** defect (no production docs exist to be blocked
  today) but it is a reproducible defect in the shipped check.
- **Agents:** unchanged by `9d8494b` (empty `git diff` for `genesis/agents/`); repo copies byte-identical to the four
  installed `~/.kiro/agents/genesis-migration-*.json`. I did not re-run the live `kiro-cli` guardrail smoke tests
  (review-1 did; the configs are unchanged).
- No git writes; repo `git status --porcelain` empty at start and end; no bytecode left in the repo.
