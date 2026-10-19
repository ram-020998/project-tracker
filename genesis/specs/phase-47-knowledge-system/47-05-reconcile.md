# 47-05 — Reconcile, per area

> **Status:** 🟡 DRAFTED 2026-10-19. Umbrella: `../phase-47-knowledge-system.md`. Agent:
> `genesis-migration-writer` (reconcile mode). Review after every area. **Gate:** the user decides every
> RULE/DECISION/CONTRACT conflict.

## Unit of work = one area (large areas split by type: rules+decisions+lessons · contracts+behaviour · the rest)
### Context manifest — read only this
Umbrella §3.3–§3.5, §5.2, §6 · `gk ledger query --area <a>` output (units, not old documents) · the unit schema ·
`areas.yaml` · the code for each `exact` item you check. An old document only to resolve a named, ambiguous unit
(cite which).

### Work
1. Gather the area's units by **primary** area; units whose primary area is another are only referenced.
2. **Duplicates** → `merge:<KU>`; the target takes the strongest wording, the union of scopes and all `refs`.
3. **ADR lifecycle** — apply supersessions and amendments; an amended decision's current form is the target.
4. **Code truth** — check every `exact` item that names code at HEAD of the code repos; a mismatch is a conflict.
5. **Fates** for every unit (`keep`, `merge:`, `superseded:`, `history`, `wrong` only via a decided conflict).
   STATE units: `keep` only the current value (it moves to `state/current.yaml` in 47-07); older values are
   `history`.
6. **Conflicts** → `migration/conflicts.md` (id, both sides cited, the authority-order default, whether it needs
   the user). The orchestrator collects the ones that need the user into one decision list per area.
7. Output `migration/reconciled/<area>.jsonl`; run `gk fates <area>`; handoff; progress; commit + push.

### Definition of Done (per area)
`gk fates` 100% · every code mismatch recorded as a conflict · user decisions recorded with dates · handoff
lists counts per fate and per type.

### Verification (reviewer — umbrella §6 plus)
All `merge:` and `superseded:` fates on high-stakes units checked (nothing weaker survived as the target, no scope
lost); 30 random `history` fates checked (nothing current was discarded); 20 random code checks repeated.
