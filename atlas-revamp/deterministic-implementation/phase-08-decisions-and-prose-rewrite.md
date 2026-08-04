# Phase 8 — Decisions Contract and Prose Rewrite

| | |
|---|---|
| **Depends on** | Phases 2–7 |
| **Outcome** | `decisions.schema.json` finalized + validated on every read; procedural prose rewritten to < 1,700 lines |
| **Retires** | The bulk of the remaining prose (duplication, anti-rationalization essay, choreography, obsolete FAILURES tables) |
| **Proposal refs** | §8 Phase 8; §5 (D1–D14); §4.2 (bucket C); Appendix D-9, D-13 |

> This is where the 4,194 → <1,700 line reduction is realized and the model/code seam is frozen. Per **DEC-4**
> we recommend doing each file's rewrite *as its phase landed*; Phase 8 then finalizes the decisions schema
> and completes any remaining trims.

---

## 1. Objective
1. Freeze `decisions.json` (D1–D14) as a schema the CLI validates on every read.
2. Reduce each remaining step file to four parts and delete everything bucket-C.

## 2. What to build / do

### 2.1 Finalize `decisions.schema.json`
- Encode all of D1–D14 with the output schemas from proposal §5 (e.g. `D3 -> {gateway_label: chosen_branch}`).
- `dg` **validates `decisions.json` on every read**; an out-of-schema decision fails **before any work
  happens**.

### 2.2 Rewrite each step file to exactly four parts
1. which decisions it produces (D-IDs),
2. which `dg` subcommand to invoke, with arguments,
3. what to do on a non-zero exit,
4. the judgment guidance only a model can act on.

### 2.3 Deletions (bucket C)
- **`step-1` 1a–1h (~260 ln)** manual-trace duplication of `resolve_write_set` — **keep only** the
  form-created-records analysis and prerequisite sections (~250 ln of genuine bucket B); delete the rest.
- **`step-3` §3f (~130 ln)** human-judgment coverage + its **anti-rationalization essay** ("INVALID
  EXCLUSION REASONS …") — obsolete once `resolve_write_set` output is the required set. "Code does not
  rationalize."
- **`step-5` §5a** — already deleted in Phase 3.
- **Every `create`-then-`insert` choreography block (6 files)** — vanishes once code writes artifacts (D-13).
- **Every `COMMON FAILURES TO AVOID` table** whose rows are now enforced by a test.
- **Renumber `step-4` internals `4.1`–`4.5`** to end the `4b` name collision (D-9).

### 2.4 Reduce the emphasis apparatus
Reserve `⚠️` for genuinely destructive operations only — writes to a live environment and `rollback_session`.
Everything else loses the banner. This restores the severity gradient the proposal notes was flattened.

## 3. Step-by-step
1. Finalize and wire `decisions.schema.json`; add read-time validation to `dg`.
2. For each remaining step file, apply the four-part structure.
3. Execute the bucket-C deletions listed above.
4. Renumber step-4 internals.
5. Sweep `⚠️` markers down to < 15 family-wide.
6. Verify the line/marker/reference invariants (Done when).

## 4. Defects resolved
- **D-9** — step-4 internal renumber ends the `4b` ambiguity.
- **D-13** — choreography removed; code writes artifacts.

## 5. Retirements (net)
- `step-1` ~260 ln removed; `step-3` §3f ~130 ln removed; choreography across 6 files; obsolete FAILURES
  tables. Target: **total procedural prose < 1,700 lines (from 4,194).**

## 6. Done when
```shell
# total procedural prose under budget:
wc -l <all 17 procedural files>          # sum < 1700

# every dg subcommand referenced by exactly one step file (spot-check or scripted):
for cmd in init state gate plan-writes coverage-gate validate gen-sql check-fields \
           plan-footprint build-footprint erd-input ...; do
  grep -rl "dg $cmd" <prose dir> | wc -l   # == 1
done

# emphasis apparatus reduced:
grep -rc '⚠️' <prose dir> | awk -F: '{s+=$2} END{print s}'   # < 15
```
- ✅ Total procedural prose **< 1,700 lines**.
- ✅ Every `dg` subcommand referenced by **exactly one** step file.
- ✅ `grep -c '⚠️'` across the family **< 15**.
- ✅ `dg` rejects an out-of-schema `decisions.json` before doing any work.

## 7. Risks & notes
- **Don't delete bucket B by accident.** The form-created-records analysis (D5) and prerequisite reasoning in
  `step-1` are irreducible — keep them. Re-read §10 "What stays irreducible" before cutting `step-1`.
- The "exactly one step references each subcommand" invariant is enforced by the Phase 10 reference-integrity
  CI job — but verify it here too.

## 8. Handoff to Phase 9
Phase 9 (manage + ERD) applies the same four-part prose structure to the manage skills and splits
`data-gen-erd/SKILL.md`.
