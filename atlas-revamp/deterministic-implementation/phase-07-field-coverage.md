# Phase 7 — Field Coverage Enforcement

| | |
|---|---|
| **Depends on** | Phase 4 |
| **Outcome** | `fields.py` + `dg check-fields`: writable-field coverage %, deterministic rounding, enforced `field_reasoning` |
| **Retires** | `step-4` §4d (coverage math) |
| **Proposal refs** | §8 Phase 7; Appendix D-10 (random/non-reproducible), D-11 (dates), D-14 (rounding) |

> Completes the reviewer's "Option 3" milestone (Phases 0–4 + 7). It also makes real the two things `step-4`
> has been *asking for with no means of enforcement*: "Every field MUST have an entry in field_reasoning. No
> exceptions." and a defined rounding rule.

---

## 1. Objective
Compute field coverage per table deterministically and **hard-fail** on missing reasoning or sub-threshold
coverage.

## 2. What to build — `fields.py`
- **Writable-field count** from `raw/record_properties/{uuid}.json`, **excluding** the PK and any field with
  `isCustomRecordField=true`.
- **Coverage %** = populated / writable, using `coverage_rounding` from `config/thresholds.json` (resolves
  **D-14**: 5/8 → 62 under `floor`, not 62.5). Threshold = `min_field_coverage_pct`.
- **`field_reasoning` enforcement** — require an entry for **every populated field** and **every deliberate
  null**. Missing reasoning is a **hard fail** (this is what `step-4`'s "⚠️ … No exceptions." wanted).
- Write findings into `reports/` and `state.json`.

### Subcommand
```
dg check-fields
```

## 3. Determinism support (D-10, D-11)
- Field-value *generation* stays a model decision (`D7`, `D10`) — but determinism means **seeded + recorded**:
  same `seed` + same `date_anchor` → byte-identical payloads. Phase 7 enforces that `seed` and `date_anchor`
  (recorded at `dg init`, Phase 2) are present and used; it replaces `step-4` §4a's "pick **randomly**" and
  its self-contradiction with the "first available" worked example.
- Dates are computed as offsets from `date_anchor`, never hardcoded literals (D-11).

## 4. Step-by-step
1. Implement writable-field counting with the PK / `isCustomRecordField` exclusions.
2. Implement coverage % with configurable rounding; enforce threshold.
3. Implement `field_reasoning` completeness as a hard fail.
4. Wire `seed`/`date_anchor` presence checks.
5. Reduce `step-4` §4d to a `dg check-fields` invocation + the judgment prose (D7/D8 explanations).
6. Add `tests/test_fields.py`.

## 5. Defects resolved
- **D-10** — non-reproducible "random" selection replaced by seeded+recorded generation.
- **D-11** — dates anchored, not hardcoded.
- **D-14** — rounding rule defined and applied.

## 6. Retirements
- `step-4` §4d coverage math → `dg check-fields`.

## 7. Done when
```shell
python3 -m pytest tests/test_fields.py -v
```
covering:
- a table **exactly at** the threshold → pass;
- a table **just below** → fail, shortfall reported;
- a table whose only shortfall is **documented nulls** → pass;
- a **missing-reasoning** field → hard fail;
- the **5/8 = 62 vs 62.5** case asserted explicitly against the configured `coverage_rounding` mode.

## 8. Risks & notes
- The writable-field denominator must exactly match how `record_properties` marks writable vs read-only /
  custom fields — verify against a real fixture, not an assumption.
- Rounding mode is a frozen config value; changing it changes results — treat as a contract, test both modes.

## 9. Handoff
With Phases 0–4 + 7 done, the reviewer's "Option 3" stopping point is reached — reassess appetite for
Phases 5, 6, 8, 9 (DEC-5).
