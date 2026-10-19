# 47-02 — Review 1 (genesis-migration-reviewer)

**Unit:** 47-02 — `gk` tooling and the migration agents
**Work under review:** project-tracker `83103e1` (parent `543bc23`; base tag `knowledge-migration-base` = `5b6201a`)
**Reviewer:** genesis-migration-reviewer · **Date:** 2026-10-20 · **Review #:** 1
**Scratch:** `/tmp/genesis-migration-review/r1/` (adversarial harnesses, batches copies, install scratch)
**Repo status at start / end:** `git status --porcelain` empty (unchanged) · HEAD `83103e1` at start and end · no `__pycache__`/`*.pyc` leaked into the repo (ran with `python3 -B`)

---

## 1. Verdict

**FAIL.** 1 BLOCKER, 3 MAJOR. The unit is otherwise strong — all six carried 47-01 findings (M1–M4, P1, P3) are
genuinely closed, the 50 unit tests pass (a negative test per check), the inventory regenerates **byte-identical**
to the committed CSV from base-tag blobs, `batches check` boundary safety catches mid-paragraph **and**
mid-code-fence splits, `copycheck` is robust against line-break / markdown-emphasis / case / punctuation / table-cell
evasion, the three agent configs match the 47-02 write table exactly with `write` out of `allowedTools`, and
`install.sh` is idempotent. But the sub-spec's Verification section told me to try to make `coverage`, `ledger
validate`, `copycheck`, `fates`, `validate` and `build --check` pass on deliberately wrong input, and I succeeded on
**`fates`** (a cycle of merges), **`validate`** (CI ids and the real `db_current_version` key leak outside
`state/`), and **`copycheck`** (an empty-reason verbatim block hides a copy silently); separately `gk batches check`
passes overlap / gap / 5× over-cap because it never implements the tiling and cap checks its own docstring and the P1
spec claim. These are check-robustness defects, not knowledge defects (this unit writes no knowledge), and every fix
is small and local.

---

## 2. Scope — expected vs produced

`git show --name-only 83103e1` touches **only** `genesis/agents/**`, `genesis/tools/gk/**`, and
`genesis/migration/**` (PROGRESS, handoff, schemas + example, scripts, inventory.csv). Nothing out of scope.

| Expected (sub-spec Work A/B + DoD) | Produced | Result |
|---|---|---|
| `gk` CLI, stdlib only, `gk.py`+`core.py` | present; 16 subcommands | OK |
| tests, ≥1 negative per check | `tests/test_core.py` (50 tests) + fixtures | OK |
| 3 agents + prompts + installer | extractor/writer/examiner `.json`+`.md`, `install.sh` | OK |
| M1 docstring 250K→200K | `check_batches.py` now "200,000, lowered from 250,000" | OK |
| M2 conditional `duplicate_of` + neg test | schema `x-required-if` + `coverage.invalid.json` + 2 tests | OK |
| M3 record `ADR-025-03` source fault | PROGRESS §Known source issues (L84–95) | OK |
| M4 archive-only chars/lines convention | every archive-only row = 0/0 (verified over all 12) | OK |
| P1 mechanical boundary safety + neg tests | in `check_batches.py` **and** `gk`; catches mid-para/mid-fence | OK |
| P3 inventory reads blobs at base tag | `core.base_blob` = `git show <tag>:<path>`; CSV reproduces exactly | OK |

---

## 3. Checks re-run (independently)

```
$ python3 -B -m unittest discover -s genesis/tools/gk/tests      # run from /tmp
Ran 50 tests in 0.110s — OK                                      # no pycache in repo
$ python3 -B genesis/tools/gk/gk.py batches check                → OK: all multi-entry boundaries are safe (28 batches)
$ python3 -B genesis/tools/gk/gk.py inventory --out /tmp/.../inventory.csv
  485 rows (473 extract, 12 archive-only); extract chars 4,861,472 lines 57,423
  diff vs committed genesis/migration/inventory.csv → IDENTICAL
$ python3 -B genesis/migration/scripts/check_batches.py          → OK; max batch 199,721 ≤ 200,000; boundary-checked 4
$ python3 -B genesis/migration/scripts/validate_schemas.py       → 5/5 schemas OK (coverage.invalid rejected via x-required-if)
```
All match the handoff's reported numbers (50 tests, 485/473/12, 4,861,472 / 57,423, 199,721, 5/5).

Agents: `kiro-cli agent validate` → clean for extractor/writer/examiner/reviewer (a malformed-JSON control prints
`Error:`). Installed `~/.kiro/agents/genesis-migration-*.{json,md}` are **byte-identical** to the repo copies (all 4).

---

## 4. Check audit — adversarial (the core). Harnesses: `r1/adversarial.py`, `r1/adv2.py`, `r1/b_*.yaml`

Legend: **caught** = check reported the error; **PASSES** = wrong input accepted (a hole).

| Check | Wrong input | Result |
|---|---|---|
| coverage | prose marked `formatting` / `blank` / `heading-only` | caught |
| coverage | `duplicate` → unit not in batch | caught |
| coverage | gap at end of file (line 16 omitted) | caught (pct 90.91, gap `s:16-16`) |
| coverage | overlapping ranges / a line covered twice | **PASSES** → P1 (by-design for multi-unit lines; see finding) |
| ledger validate | `exact` item elsewhere in file but not in cited lines | caught |
| ledger validate | lines out of range / duplicate ids | caught |
| fates | merge → missing target / `wrong` without conflict | caught |
| fates | **cycle of merges A→B→A** | **PASSES** → **B1 (BLOCKER)** |
| copycheck | 12-word copy across a line break / emphasis / case / punctuation / table cell | caught (all five) |
| copycheck | 11-word copy | passes (correct: §6.2 threshold is 12) |
| copycheck | copy in **empty-reason** `<!-- verbatim: -->` | **PASSES** → **M3 (MAJOR)** |
| validate | superseded rule in active pack / archive link / dangling link / missing provenance | caught |
| validate | `v1.2.3`, `current_version`, `m0123`, `99 tests` outside `state/` | caught |
| validate | **CI id** (`pipeline #45678`, `gl-9931`), **`db_current_version`** key, bare `0.69.0`, prose "version 20" | **PASSES** → **M2 (MAJOR)** |
| build --check | edit a **rule** body, don't rebuild | caught (`areas/collaboration-hub/SKILL.md` stale) |
| exact | nonexistent path / glob matching nothing | caught (both reported) |
| batches check (`gk`) | **overlap + 5× over-cap (999999)** | **PASSES** → M1 |
| batches check (`gk`) | **gap** (safe boundaries) | **PASSES** → M1 |
| batches check (`gk`) | mid-paragraph split / mid-code-fence split | caught |
| batches check (`check_batches.py`) | overlap / gap / over-cap / archive / bad boundary | caught (authoritative; verified on real data + 47-01 review) |
| rules | rule whose `applies_to` glob matches nothing | not validated → P3 |

By the sub-spec's literal Verification wording ("try to make … `fates`, `validate` … pass on deliberately wrong
input; each success is a BLOCKER") the `validate` (M2) and `copycheck` (M3) successes are also BLOCKER-class; I graded
them MAJOR on judgment (CI-id detection is inherently heuristic; verbatim exemptions have a human-review backstop in
§6.2). The `fates` cycle has no such mitigation and strands knowledge, so it stays a BLOCKER.

---

## 5. Agents

- **Write paths** match the 47-02 table exactly (+ a `/tmp/genesis-migration/**` scratch root, needed for the smoke
  tests): extractor = ledger/questions/handoffs/PROGRESS.md; writer = reconciled/conflicts.md/knowledge/handoffs/
  PROGRESS.md; examiner = exams. `write` is in `tools` but **not** in `allowedTools` for all three. Run without
  `--trust-all-tools`.
- **Deny lists:** extractor/writer deny the mutating git verbs (tag/checkout/reset/…/rm/mv) but allow
  `add`/`commit`/`pull`/`push`; examiner (and the pre-existing reviewer) additionally deny `add`/`commit`/`push`
  (no git writes). `rm`/`mv`/`sudo`/`sed -i`/`gsm`/`curl -X POST|PUT|…` denied (incl. after `;`/`&&`/`|`). The
  anchored git pattern does not trip on those verbs appearing inside a path or commit message.
- **Prompts** carry the full session discipline (≤300K / ≤200K budgets, read-only-the-manifest, search-safety list,
  `PYTHONDONTWRITEBYTECODE`, never run a repo-writing script in place, explicit-paths commit + pull --rebase/push
  procedure) and the role limits (extractor writes no new docs; writer works from reconciled units + code, not old
  prose; examiner answers only from `knowledge/_build/` and cites).
- **Guardrail smoke tests I re-ran myself** (`kiro-cli chat --agent <name> --no-interactive` from `/tmp`, no
  `--trust-all-tools`):

| Agent | in-scope write `/tmp/genesis-migration/…` | out-of-scope `/tmp/genesis-migration-OUT/…` | `rm` |
|---|---|---|---|
| examiner | succeeded | refused | refused |
| extractor | succeeded | refused | refused |
| writer | succeeded (via `write` tool) | refused | refused |

  Note: the in-scope write by extractor/examiner used a shell redirect (shell is **not** path-limited — the
  documented limitation), and out-of-scope/`rm` were refused at the **discipline** (prompt) level. The enforcing
  *mechanism* for `rm`/`mv`/git-writes is the shell deny list (my own reviewer shell, which carries the same
  pattern, blocked a command merely containing `rm`), and for the `write` tool it is `allowedPaths`.
- **`install.sh` idempotency:** against a scratch `KIRO_AGENTS_DIR`, run 1 then run 2 are byte-identical; exactly 4
  agents + their prompts installed; a seeded unrelated `kirocrew-conductor.json` was untouched.

---

## 6. High-stakes items

This unit produces **no knowledge units**, so source→ledger / ledger→source / new-doc sampling and the MUST/ADR/
LESSON survival checks do not apply (per the task and the 47-01 precedent). The "high-stakes" surface here is the
set of mechanical checks themselves; audited adversarially in §4. Checks that correctly reject wrong input: coverage
(skip-reason + gap), ledger validate (all), fates (target existence + wrong/conflict), copycheck (all evasions up to
the exemptions), validate (all except the state-fact narrowness), build --check, exact, `check_batches.py` (full).
Checks with holes: see Findings.

---

## 7. Findings

| id | sev | evidence | problem | fix |
|---|---|---|---|---|
| **B1** | **BLOCKER** | `core.check_fates` (core.py ~L300) — `r1/adversarial.py` "cycle of merges A<->B" → 0 err | `fates` only checks that merge/supersede targets **exist**, not that the fate graph is acyclic. A `merge` cycle (A→B, B→A) passes, yet neither unit survives into a document — the knowledge is stranded. The sub-spec Verification lists `fates` as a check that must fail on wrong input. | In `check_fates`, after target-existence, topologically resolve `merge`/`superseded` edges and report any cycle (and any chain that does not terminate at a surviving `keep`). Add a negative test. |
| **M1** | MAJOR | `gk.py:cmd_batches` calls only `core.check_batches_boundaries`; docstring (gk.py L24, "tiling + cap + boundary-safety") + sub-spec P1 ("besides tiling and the cap …"). `r1/b_overlap_overcap.yaml`, `r1/b_gap.yaml` both → "OK" | `gk batches check` verifies only boundary safety; it silently passes overlap, gap, and a 5× over-cap (999999) — none of the tiling/cap checks it and the spec claim. A gap means source lines never get extracted (knowledge loss) yet the command says OK. Mitigated only because `check_batches.py` (authoritative, run by the extractor/reviewer) does catch all of these. | Either implement tiling + cap in `cmd_batches`/`check_batches_boundaries` (with negative tests), or delete the false "tiling + cap" claim from the docstring and have `gk batches check` call/defer to `check_batches.py`. |
| **M2** | MAJOR | `core.STATE_FACT_PATTERNS` (core.py ~L54) — `r1/adv2.py` + the `db_current_version`/CI test | `validate`'s state-fact guard is too narrow for a check whose job is to keep per-release facts out of non-`state/` docs. It misses **CI ids entirely** (a spec-named category: pipeline numbers, `gl-9931`), the **actual `db_current_version` key** (the `\bcurrent_version\b` pattern can't cross the `_`), bare semver (`0.69.0`, no `v`), and prose "version 20". | Add patterns for the CI-id formats actually used in `state/current.yaml` and for bare/prose version + the real `db_current_version` key; or document in the spec which state-fact forms are out of mechanical scope. Add negative tests for each. |
| **M3** | MAJOR | `core._strip_noncopy` + `VERBATIM_RE` (core.py ~L30/230) — `r1/adversarial.py` "EMPTY verbatim" → 0 hits | `copycheck` drops **any** paragraph containing `<!-- verbatim: … -->`, including an **empty** reason (`<!-- verbatim: -->`), and never reports which paragraphs it exempted. So copied prose can pass the §6.2 copy gate unseen (§6.2 says the exemption "needs … reason" and "is reviewed", but a reviewer running `copycheck` sees "0 overlaps" with no pointer to the exempted block). | Require a non-empty reason (fail the check on an empty/blank verbatim reason), and **print every exempted verbatim/code block** so the §6.2 human review can inspect it. Add a negative test. |
| m1 | MINOR | `gk.py:cmd_context` L225: `errs = core.schema_validate(schema, {"context": man}) if False else []` | `gk context` parses the manifest but **never validates it** against `context-manifest.schema.json` — the branch is dead-coded `if False`. A malformed manifest passes silently. | Remove `if False` (validate the manifest) or drop the unused schema load; add a negative test. |

---

## 8. Process improvements

- **P1** — `coverage` accepts overlapping / duplicated line ranges. This is probably *intended* (a line may feed two
  units), and it cannot hide a gap (the exactly-once tiling guarantee lives in `batches.yaml`/`check_batches.py`), but
  it is undocumented. State in the coverage schema/§5.1 that ranges may overlap and that exact-once tiling is a
  batches-level invariant, so a future reviewer doesn't read an overlap as a defect.
- **P2** — `copycheck` should emit a one-line summary of every exemption it applied (verbatim blocks, code fences,
  `exact` items) so the mechanical run is auditable; today a clean run tells the reviewer nothing about what was
  skipped. (Pairs with M3.)
- **P3** — neither `validate` nor `rules` warns when a rule's `applies_to` glob matches **no** file in the repos (a
  dead glob that can never fire). Add a `validate` lint that resolves each `applies_to` glob against the code root.
- **P4** — `kiro-cli agent validate` is lenient: it accepts a config with unknown `tools`/`allowedTools` and exits 0
  (only malformed JSON prints `Error:`). It is a JSON-sanity gate, not a semantic one — the DoD should not lean on it
  for write-path / deny-list correctness; the static config review (done here) is the real check.
- **P5** — the handoff presents `gk batches check` and `check_batches.py` as if interchangeable; they are not (M1).
  Make PROGRESS/handoff state that `check_batches.py` is the authoritative tiling+cap+boundary check and `gk batches
  check` is boundary-only until M1 is fixed.

---

## 9. Not verified / assumptions

- **`gk validate`/`build`/`budget` on the real store:** exercised only on the fixture store under `tests/fixtures/`
  — the production `genesis/knowledge/` does not exist until 47-06 (as the handoff states). The store-validator logic
  is audited by reading + the fixture adversarial tests, not against real content.
- **`check_batches.py` boundary catch on a bad boundary** was not re-run through that script directly (it reads fixed
  repo paths and cross-checks the full inventory); I verified the identical `unsafe_boundaries` logic via `gk batches
  check` on a crafted mid-paragraph / mid-code-fence split (both caught) and via the committed negative unit test,
  plus its `boundary-checked: 4` on the real plan and the 47-01 review's altered-copy results.
- **Smoke-test mechanism vs discipline:** out-of-scope writes and `rm` were refused by the agents at the prompt
  (discipline) level; I did not observe a tool-layer denial string (the agents refuse before invoking the tool). The
  enforcing mechanism was confirmed statically (deny patterns present; my own shell with the same pattern blocks
  `rm`) rather than by forcing the tool layer.
- I did **not** run `install.sh` against `~/.kiro/agents` (used a scratch `KIRO_AGENTS_DIR`), and made no git writes;
  repo `git status --porcelain` was empty at start and end.
