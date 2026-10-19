# 47-01 — Review 1 (genesis-migration-reviewer)

**Unit:** 47-01 — Inventory, area taxonomy, schemas, templates, batch plan
**Work under review:** project-tracker `5e8e148` (base tag `knowledge-migration-base` = `5b6201a`)
**Reviewer:** genesis-migration-reviewer · **Date:** 2026-10-19 · **Review #:** 1
**Scratch:** `/tmp/genesis-migration-review/r1/` (independent scripts) and `/adv2/` (altered-copy tests)
**Repo status at start / end:** `git status --porcelain` empty (unchanged) · HEAD `efeff6e`

---

## 1. Verdict

**PASS WITH FINDINGS.** No BLOCKER, no MAJOR. The inventory, area coverage, schemas and batch plan all
reproduce exactly under fully independent recomputation (own scripts reading blobs **at the base tag**, not the
implementer's CSV); the five check scripts all reject wrong input (overlap, gap, over-cap, archive-in-batch,
unmatched code file) when run on altered copies; the pilot P1/P2 composition is faithful to the 2026-10-19 gate
decision (changes 1–3); no batch boundary splits a paragraph/table/list-item/code block; the 14 areas' globs
match real files coherently; the schema expresses all 12 KU types; and the session budget holds. Findings are 4
MINOR and 4 PROCESS — none block.

This unit produces no knowledge units, so source→ledger / ledger→source / new-doc sampling does not apply (per
the task); the review centres on the mechanical artifacts, the checkers, and gate conformance.

---

## 2. Scope — expected vs produced

| Expected (sub-spec Outputs/DoD) | Produced | Result |
|---|---|---|
| base tag set + pushed | `knowledge-migration-base`=5b6201a, present on `origin` (`git ls-remote`) | OK |
| `inventory.csv` + `scripts/inventory.py` | 486-line CSV (485 rows+header) | OK |
| `areas.yaml` + `scripts/check_areas.py` | 14 areas + 2 pseudo + exceptions | OK |
| 5 schemas + examples + `scripts/validate_schemas.py` | 5 schemas, 5 valid + 5 invalid examples | OK |
| 3 templates | handoff-note / review-request / conflict-entry | OK (present; not deeply reviewed) |
| `batches.yaml` + `plan_batches.py` + `check_batches.py` | 28 batches (P1,P2,B01..B26) | OK |
| `PROGRESS.md`, `handoffs/47-01.md` | present, gate recorded | OK |
| user approval of areas+batches recorded with date | handoff: "2026-10-19 — approved with changes 1–3" | OK |

Nothing missing, nothing out of scope. `git show --stat 5e8e148` = 28 files, all under `genesis/migration/`.

---

## 3. Checks re-run (independently; not taken from the handoff)

**Source corpus unchanged base→HEAD.** `git diff --name-only knowledge-migration-base efeff6e -- genesis/`
minus `migration/` and `phase-47` specs = **1** file (the reviewer-prompt). So working-tree reads equal the base
blob for every source; where it mattered I read blobs at the tag anyway.

**Inventory (own recount, blobs at base tag — `r1/indep_inventory.py`):**
```
my files: 485   their rows: 485
my extract/archive: 473/12   their: 473/12
my extract chars: 4,861,472   their: 4,861,472
my extract lines: 57,423   their: 57,423
only in mine: 0  only in theirs: 0
```
Matches the handoff (485 / 473 / 12 / 4,861,472 / 57,423). `git ls-tree -r knowledge-migration-base -- genesis/`
= **485** (migration/ did not exist at base → DoD equality holds). All 12 archive-only rows carry a reason
(5× .DS_Store, 5× .obsidian config, 2× .gz bundles); 0 extract rows carry a spurious reason.

**Batch coverage (own recompute, chars from base blobs via `splitlines(keepends=True)` — `r1/indep_batches.py`):**
```
char_limit=200000  batches=28
distinct sources covered: 473  inventory extract: 473
max batch chars: 199,721
total chars: 4,861,472
ERRORS: 0
```
Every extract file tiled exactly once (no gap/overlap); every recorded per-entry char count equals the real
base-tag blob content; every batch ≤ 200,000; declared batch `chars`/`files` self-consistent. Matches handoff
(max 199,721, 28 batches).

**Schemas (`validate_schemas.py` from the isolated copy):** `5/5 schemas OK` — each valid example passes, each
invalid example is rejected (KU: missing `scope`; coverage: `whitespace` not in enum; rule: missing `status`;
etc.). PyYAML is absent in this env, so the hand-parsers (the path the implementer's env uses) are the ones
exercised.

**Areas (`check_areas.py` from the copy, real repos):**
```
total tracked files across 5 repos: 950
matched to >=1 area : 876 ; exception-only : 74 ; UNMATCHED : 0
```
Matches handoff (876 / 74 / 0). 74 exceptions = 70 `web/static/**` + 4 vendored Lavish.

---

## 4. Check audit — can a checker pass wrong work?

Tested each checker on **altered copies** under `/tmp/genesis-migration-review/adv2/` (never in place):

| Perturbation | File | Result |
|---|---|---|
| Overlap (tracker [1,1082] duplicated) | batches.yaml | `check_batches` → FAIL, exit 1 (gap/overlap + char mismatch) |
| Gap (delete tracker [1083,2204]) | batches.yaml | FAIL, exit 1 ("covered to line 1082, file has 2204 lines") |
| Over-cap (chars→999999) | batches.yaml | FAIL, exit 1 ("999999 exceeds limit 200000") |
| Archive-only in a batch (`.DS_Store`) | batches.yaml | FAIL, exit 1 ("archive-only file in batch" + "not an extract source") |
| Remove `exceptions:` | areas.yaml | `check_areas` → UNMATCHED web/static, exit 1 |
| Remove `appian-parser` globs | areas.yaml | UNMATCHED parser files, exit 1 |

All six are caught. The checkers do not pass wrong input. **One gap (PROCESS P1):** `check_batches` verifies line
tiling + char caps but does **not** verify that a partial-file boundary lands on a safe split point — the
planner guarantees it by construction (verified below), but a later hand-edit to `batches.yaml` could introduce
a mid-paragraph split that the checker would accept.

---

## 5. Samples (seed = 4701)

**Partial-file boundary safety — 100% of partial boundaries inspected** (`r1/indep_boundaries.py`). Only four
sources are split: `bible/04`, `bible/06`, `reference/decision-log.md`, `tracker.md`. Every boundary lands on a
heading, a blank line, or between two complete single-line list items — none splits a paragraph/table/list-item/
code block:
- `decision-log` carve **[1323,1353]**: starts at `## ADR-063` (L1323), B16 resumes at `## ADR-066` (L1354);
  L1352–1353 blank. ADR-063/064/065 are wholly inside the carve. Clean.
- `bible/04` carves L70/72/73 are each a complete one-line ADR index bullet; L71/74 blank. Clean.
- `bible/06` carves (334/336/341/347/349/351/353–354) are each a complete one-line lesson bullet; separators are
  blank lines or adjacent whole bullets. Clean.
- `tracker.md` size split at L1082 (blank) between dated entries; L1083 starts a new dated bullet. Clean.

**Area assignment — 25 random code files** (`r1/sample_areas.py`): every file maps to exactly the coherent area
(genesis-workflows→workflow-library; runs/worker→runs-config; applications/*→appian-kb; chat/*→chat-copilot;
collab/*→collaboration-hub; kiro-agent-sdk→agent-sdk; shared/ui + lib + library→web-ui; web/static→exception;
etc.). No surprises. The 4 declared overlaps are sensible: `config/copilot.py` (runs-config+chat-copilot),
`test_kb_collab_sync.py` (appian-kb+collaboration-hub), `StoriesTab/StoryForm.tsx` (feature-sdlc+stories-
workbench). The broad-looking `genesis/tests/fixtures/**` (collaboration-hub) matches only 14 files, all
hub/collab fixtures — not over-broad in practice.

**Schema expressibility — 10 paragraphs across bible/04, bible/06, decision-log, progress/phase-35, Hub
contract.** All 12 KU types map onto the schema: DECISION (ADR-063 index + decision-log body), RATIONALE (ADR
"Context"), LESSON (bible/06 L341 board-membership), CONTRACT (Hub base-URL/auth + "lossless invariant", via
`exact[]` for `/suite/webapi`, `appian-api-key`, `401`), RULE (MUST invariants, `strength`), STRUCTURE/STATE/
BEHAVIOUR (m0019 columns, `current_version 18→19`, Settings page shipped), TERM (`canonical_username`), PLAN
(backlog), HISTORY (dated as-builts), PROCEDURE (`strength=MUST` steps). `statement`+`exact`+`strength`+`scope`+
`refs`+`type`+`areas` suffice. The shipped **valid KU example** (KU-P1-0001) is a real corpus citation —
decision-log L728 is exactly `## ADR-037 …`, the statement faithfully restates the Decision, and every `exact`
identifier (`kb_objects`, `valid_from_sync`, `kb_releases`, `get_object_code(object_uuid, version?)`, …) appears
in L728–751.

---

## 6. High-stakes items (gate conformance)

The 47-01 high-stakes item is **the pilot composition = the gate decision**, checked at 100%:

- **P1 (39 entries, 180,487 chars):** whole files of phases **35** (9), **37** (8), **38** (10) +
  `progress/collab-settings-toggle-adr-065.md` + `decision-log[1323,1353]` + `bible/04[70],[72],[73]` +
  `bible/06` lessons `[334],[336],[341],[347],[349],[351],[353,354]`. No phase-36 file present. ✔ matches gate.
- **P2 (30 entries, 199,128 chars):** exactly the 30 phase-36 files (specs + contract + 16 fixtures + progress).
  No 35/37/38 file present. ✔ matches gate "P2 = all of phase 36".
- **bible/06 = all collaboration lessons?** I scanned all 355 lines. The only Hub/collab/sync/pull/publish
  lessons are L334, 336, 341, 347, 349, 351, 353, 354 — **exactly** the selected set. L309 (Appian-credential
  env-seam) and L323 (Phase-30 gated-stage) match keywords but are not collaboration lessons; L181 matched only
  on `is_hub` (an Atlas graph-builder attribute) and is correctly rejected. No collaboration lesson omitted, none
  spurious. ✔
- **Carves removed from B exactly?** Independent tiling proves the B complements carry precisely the non-carved
  lines (bible/04 → B18 [1-69],[71],[74-89]; bible/06 → B19; decision-log → B16 [1-1322],[1354-1466]) with
  0 overlap/gap. ✔
- **Batch cap 200K:** max 199,721 ≤ 200,000. ✔  **Areas 14 + split:** engine/runs-config and
  appian-parser/appian-kb both present. ✔

Checked: 6 / OK: 6 / failures: 0.

---

## 7. Findings

| id | sev | evidence | problem | fix |
|---|---|---|---|---|
| M1 | MINOR | `scripts/check_batches.py` docstring + the `char_limit <= 250,000` comment | Stale 250K in the docstring; code correctly enforces 200K read from `batches.yaml`. | Update the docstring/comment to 200,000. |
| M2 | MINOR | `schemas/coverage.schema.json` `duplicate_of` + the hand-validator | Schema says `duplicate_of` is "Required when skip=duplicate" but the validator has no conditional-required, so `skip:"duplicate"` without `duplicate_of` still validates. The spec's unit is `duplicate:<KU>`. | Add an `x-required-if` (skip=duplicate ⇒ duplicate_of) and teach `validate_schemas.py` to honour it. |
| M3 | MINOR | `rule.frontmatter`/`context-manifest` `id` pattern `^(ADR\|LSN\|STD\|WA)-[0-9]{3}$` | Cannot express sub-numbered ADRs present in the corpus (`ADR-025-03`, `ADR-25-08`). A rule that amends/supersedes/references one would be rejected. | Widen the pattern (e.g. `-[0-9]{2,3}(-[0-9]{2})?`) before 47-06 writes rules. |
| M4 | MINOR | inventory rows for `.obsidian/*.json` | archive-only text files record real `chars`/`lines` while archive-only *binaries* record 0 — a harmless inconsistency in the archive-only convention (does not affect extract totals or any DoD count). | Optional: zero chars/lines for all archive-only rows, or document the convention. |
| P1 | PROCESS | §4 above | `check_batches.py` does not verify partial-file boundaries fall on safe split points; the guarantee rests entirely on `plan_batches.py`. A later hand-edit could smuggle a mid-paragraph split past the checker. | Add a boundary-safety assertion to `check_batches.py` (re-derive safe set like the planner; assert every internal split start is safe). |
| P2 | PROCESS | this session | Read-only `git` batches were twice blocked by the command filter — once because an `echo` string contained the word "commit", once for `rm -rf` in scratch cleanup. Neither was a mutating git op. | Reviewers: avoid the denied words (incl. in echoes/paths); the orchestrator may want a read-only git allowlist. Noted per task instruction. |
| P3 | PROCESS | `inventory.py` reads the **working tree** (guarded by a HEAD==base check that only *warns*) | Future passes run at HEAD≠base; inventory then silently reflects the working tree. It happened to be byte-identical here, but the guard is a warning, not a failure. | Have `inventory.py` read blobs at `knowledge-migration-base` directly (as this review did), or make the HEAD≠base guard fatal without `--allow-dirty`. |
| P4 | PROCESS | leftover `/tmp/genesis-migration-review/{47-01-task.txt,47-01-run1.log,bible06.md,fake/}` from an **earlier aborted** review (its task.txt cites an older HEAD `bc92cb9`) | Stale scratch from a prior run can confuse a reviewer. | Orchestrator should give each review a clean, unique scratch dir (this review used a `r1/` subdir to isolate). |

---

## 8. Process improvements
See P1–P4 above. In particular P1 (boundary check should be mechanical, not only planner-guaranteed) and P3
(inventory should pin to the base tag) would harden the method before 47-04 extraction fans out over 26 batches.

---

## 9. Not verified / assumptions
- **Templates' content** (handoff-note/review-request/conflict-entry) only confirmed to exist, not audited for
  completeness — they are process scaffolding, exercised in 47-03.
- **47-04 context-manifest size** is not yet fixed (47-04 sub-spec is a future unit). Budget checked by
  arithmetic: largest batch 199,721 + the extractor's spec/schema reading (`47-01` sub-spec 4,660 + KU schema
  3,141 + coverage schema 1,683 = 9,484) ≈ 209,205 chars, leaving ~90K headroom under the 300K cap; a per-batch
  context manifest (an areas list) is a few hundred chars. Budget holds.
- Did not re-run `inventory.py` / `plan_batches.py` in place (they rewrite tracked files); re-derived their
  outputs with independent scripts instead.
