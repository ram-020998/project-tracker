# 47-10 — Whole-program review and acceptance

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Mandatory review sub-spec.
> **Gate:** the user accepts.

## Work
1. **Delta batch** — sources changed after `knowledge-migration-base` (`git diff --stat
   knowledge-migration-base -- genesis/`): extract the changed ranges, reconcile, write, examine — reviewed like
   any batch. Expected to be empty if the freeze held.
2. **Whole-program review** — the orchestrator runs `genesis-migration-reviewer` stages in parallel, one per area
   plus one for core/state/procedures and one for the agents, each with umbrella §6 at full sample sizes.
3. **Measure S1–S7** (umbrella §2), each with the command and output:
   S1 `/context` at start-up for each role agent with a real manifest · S2 `gk coverage` over every batch ·
   S3 `gk fates` over every area · S4 `gk copycheck knowledge/` · S5 the exam results · S6 the **recall test**:
   for every lesson, the files of the bug it records → `gk rules --paths` must return that lesson (and its
   ADRs) · S7 `gk validate` green + no agent config referencing `archive/`.
4. **Real-task trial** — replay a past sub-spec with the new agents on a scratch branch of the code repo (proposal:
   46-08, story answers — medium size, touches backend + web + workflows). `genesis-spec` writes its sub-spec with a
   manifest from the phase's umbrella; `genesis-build` implements it; `genesis-review` reviews it. Compare with
   what actually shipped: gates, rules respected, findings, context used. The scratch branch is deleted
   afterwards (with the user's OK).
5. **Acceptance report** → `migration/reports/47-10-acceptance.md`: S1–S7 table, review verdicts, trial results,
   open items, recommendation.

## Definition of Done
S1–S7 met (or a user-accepted exception for each miss) · every review PASS / PASS WITH FINDINGS · the report ·
the user's acceptance recorded.

## Verification
This sub-spec is the review. The orchestrator checks every reviewer report was read and every finding closed.
