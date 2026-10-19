# 47-06 — Write, per area

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agent:
> `genesis-migration-writer` (write mode). Review after every area. The pilot's collaboration draft is rewritten
> here with all its units.

## Unit of work = one area (a large area may be split: rules first, then pack + reference)
### Context manifest — read only this
Umbrella §4, §5.3, §6, §7 · `migration/reconciled/<area>.jsonl` (`fate: keep` and merge targets) ·
`rule.frontmatter.schema.json` · `areas.yaml` · the code, to describe structure and behaviour accurately.
**Never the old documents** — if a unit is unclear, open its cited lines only and say so in the handoff.

### Work
1. **Rule files** `knowledge/rules/<ID>.md` for the area's DECISION, RULE, LESSON, standard and agreement units.
   ADR ids are kept; new ids from `gk next-id`. Imperative `MUST` / `MUST NOT` / `SHOULD`, scope and exceptions
   explicit, `applies_to` globs checked to match real files, `verify` where a test or command proves compliance,
   the rationale rewritten under `Why:`. One rule = one file, whatever its number of areas.
2. **Area pack** `knowledge/areas/<area>/pack.md`: scope; the module map for this area (from the code, checked);
   what the shipped features do (BEHAVIOUR); contract summaries; the list of the area's rules (the build inlines
   their text); pointers to its reference docs. Organized by topic, never by phase.
3. **Reference docs** `knowledge/areas/<area>/reference/*.md` for contracts and detailed behaviour.
4. A `<!-- src: KU-… -->` comment on every paragraph, list item group and table.
5. Run `gk validate`, `copycheck`, `exact`, `budget`, `build`; fix until green; handoff; progress; commit + push.

### Definition of Done (per area)
Every `keep` unit of the area is cited by at least one paragraph (`gk fates --usage`) · all checks green · budgets
met · handoff lists what was hard to place.

### Verification (reviewer — umbrella §6 plus)
**All** high-stakes units of the area traced to the new text at full force; 30 random new statements traced back to
units and code; the copy check re-run and 10 paragraphs spot-compared with their sources; read the pack once as a
newcomer and list gaps.
