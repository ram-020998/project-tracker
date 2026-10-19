<!-- Phase 47 handoff note template. Copy to migration/handoffs/<unit>.md and fill
     every section. <unit> = a sub-spec id (47-03) or a batch/area id (B04, area:memory).
     Keep it factual: the reviewer re-runs every check and does NOT trust these numbers. -->

# Handoff — <unit>

- **Unit:** <sub-spec / batch / area>
- **Role agent:** <genesis-migration-extractor | -writer | -examiner | kiro_default>
- **Date:** <YYYY-MM-DD>
- **Base tag:** knowledge-migration-base
- **Commit:** <git sha pushed to origin/main>
- **Pass:** <extract | reconcile | write | examine | setup>

## What was done
<2–6 sentences: the scope actually covered, in order; what you read; what you produced.>

## Outputs (paths)
- <migration/… or knowledge/… path>  — <one line>
- <…>

## Counts
| Metric | Value |
|---|---|
| Sources read (files) | <n> |
| Source lines in scope | <n> |
| Units written / reconciled | <n> |
| Line coverage (non-blank) | <100% / n of m> |
| High-stakes units in scope | <n> |
| Conflicts recorded | <n> |

## Check outputs (commands run + result)
```
$ <command>
<trimmed output showing PASS/FAIL>
```
<Repeat for each mechanical check: schema validation, coverage check, copy check,
 exact-item vs source/code, links resolve, budgets. Paste the real tail.>

## Open points / risks
- <anything unresolved, any assumption made, any budget pressure, any TODO for a later pass>

## What the reviewer should look at
- <the highest-risk units or ranges; where a decision's strength/scope could have softened>
- <specific sources to spot-check source→ledger and ledger→source>
- <any conflict that needs a user decision>
