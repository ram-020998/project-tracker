<!-- Phase 47 review-request template. The orchestrating session fills this and
     launches genesis-migration-reviewer on the unit (read-only; §8). The reviewer
     writes its verdict to migration/reviews/<unit>-review[-N].md. -->

# Review request — <unit>

- **Unit:** <sub-spec / batch / area>
- **Handoff:** migration/handoffs/<unit>.md
- **Commit under review:** <git sha>
- **Base tag:** knowledge-migration-base
- **Pass:** <extract | reconcile | write | examine | setup>
- **Attempt:** <1 | review-2 | …>

## Scope of this review
<Which artifacts are in scope (paths), and which sources/areas they cover.>

## Verification to apply (umbrella §6 + the sub-spec's own)
- [ ] Re-run every mechanical check independently (do NOT take numbers from the handoff): schema validation, line coverage = 100% of non-blank lines, unit fates (after reconcile), the 12-word copy check, `exact` items vs source and code, links resolve, `_build/` fresh, budgets.
- [ ] Seeded random sampling, ≥ 30 per direction: source → ledger; ledger → source; new doc → units/sources/code.
- [ ] ALL high-stakes units in scope checked for survival at full force (same strength, scope, exceptions).
- [ ] <any sub-spec-specific checks — e.g. for 47-01: re-count inventory + batch coverage; 20 random code files vs area globs; map 10 random paragraphs onto the KU schema; batch boundaries don't split a paragraph/table/code block.>

## Known open points (from the handoff)
- <copy the handoff's open points so the reviewer can confirm or escalate them>

## Verdict (reviewer fills)
- **Verdict:** <PASS | PASS WITH FINDINGS | FAIL>
- **Findings:** <BLOCKER / MAJOR / MINOR / PROCESS, each with evidence>
- **PROCESS findings → method change:** <recorded in migration/PROGRESS.md §Method changes before the next unit>
