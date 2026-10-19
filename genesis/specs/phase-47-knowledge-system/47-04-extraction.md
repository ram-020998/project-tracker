# 47-04 — Extraction of every remaining batch

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agent:
> `genesis-migration-extractor`. Review: after **every** batch. Starts only after the 47-03 GO.

## Unit of work = one batch (`B01 … Bnn` in `migration/batches.yaml`)
### Context manifest — read only this
Umbrella §3.2 (units), §5.1, §6, §7 · `migration/schemas/knowledge-unit.schema.json` + `coverage.schema.json` ·
`migration/areas.yaml` · `migration/PROGRESS.md` §Method changes · **the batch's sources, fully and in order.**
Nothing else — not other batches, not the code.

### Work
1. Read each source of the batch in full. For every piece of knowledge write one unit in your own words
   (`statement`), with `exact` holding identifiers, paths, commands, numbers and UI strings verbatim, the true
   `strength` (a MUST stays a MUST; an exception goes in `scope`), `type`, `areas` (first = primary), `refs`.
2. Atomic: one rule, fact or step per unit. A paragraph with three rules is three units. A table row is usually
   one unit. A rationale is its own RATIONALE unit linked to its decision.
3. History is still extracted (type HISTORY) — reconcile decides what survives. Do not judge relevance now.
4. Write the coverage map. Skip reasons only for lines with no knowledge; a duplicate inside the batch points to
   the unit that holds it.
5. **Question mode** in the same session if the budget allows (otherwise a follow-up session): one question per
   high-stakes unit (`migration/questions/<batch>.jsonl`).
6. Run `gk ledger validate`, `gk coverage`; fix until green; write the handoff (counts by type and area,
   outputs of both checks, anything ambiguous); update `PROGRESS.md`; commit + push project-tracker.

### Definition of Done (per batch)
`ledger validate` green · coverage 100% of non-blank lines · every high-stakes unit has a question · handoff and
progress row written · committed and pushed.

### Verification (reviewer — umbrella §6 plus)
Seeded samples of 30 source ranges and 30 units; every high-stakes unit compared with its source lines for full
force; check that no unit merges two facts, that `strength` was not softened, and that the skip reasons are true.
