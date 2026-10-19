<!-- Phase 47 conflict-entry template. Append one filled block per conflict to
     migration/conflicts.md. A conflict is recorded whenever sources disagree, or a
     source disagrees with the code at HEAD (umbrella §3.4). BOTH sides must be
     cited. A conflict that changes a RULE, DECISION or CONTRACT is decided by the
     USER; others follow the authority order with the record kept. -->

## CONF-<nnnn> — <short title>

- **Area(s):** <area id(s)>
- **Affects:** <RULE | DECISION | CONTRACT | other>  <!-- RULE/DECISION/CONTRACT => user-decided -->
- **Found in:** <pass / unit>  ·  **Date:** <YYYY-MM-DD>
- **Units:** <KU id(s) involved>

### Side A
> <claim, quoted/paraphrased>

- **Source:** <repo-relative path> : lines <first–last>  (or: code at HEAD <repo/path:symbol>)

### Side B
> <the conflicting claim>

- **Source:** <repo-relative path> : lines <first–last>  (or: code at HEAD <repo/path:symbol>)

### Authority order applied
Default: **code at HEAD > as-built `progress/` > tracker §6 > bible > specs (plans)**;
for ADRs: `reference/decision-log.md` > `bible/04`.

- **Analysis:** <which side the authority order favours and why; cite the deciding source>

### Resolution
- **Decision:** <kept Side A / kept Side B / merged as … / superseded by …>
- **Decided by:** <user (required for RULE/DECISION/CONTRACT) | authority order>
- **User decision recorded:** <date + verbatim instruction, if user-decided; else n/a>
- **Resulting fate:** <KU id(s) → keep / merge:<KU> / superseded:<KU|ADR> / wrong>
- **Status:** <open | resolved>
