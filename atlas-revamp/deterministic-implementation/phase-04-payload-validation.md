# Phase 4 — Payload Validation

| | |
|---|---|
| **Depends on** | Phase 3 |
| **Outcome** | `validate.py` + `dg validate`: real, multi-dimensional validation of the payloads |
| **Retires** | `step-5-validation.md` **306 → ~60 ln**; `exemplar-4-validation.md` → a `dg validate --mode exemplar` call |
| **Proposal refs** | §8 Phase 4; §7.2 (FK grammar); Appendix D-8 (the no-op) |

> Today the only "mechanical" check in `step-4` §4e is a **no-op that always passes**: "read the file; if it
> reads successfully the JSON is valid." A read returns text regardless of parseability (D-8). Phase 4
> replaces this with checks that can actually fail.

---

## 1. Objective
Validate every payload file against schema **and** cross-artifact invariants (FK topology, reference-ID
membership, user membership, document validity, forbidden fields, date coherence), producing a real pass/fail.

## 2. What to build — `validate.py`
Each check reads on-disk artifacts only; writes `reports/validation-report.md`; sets `state.json`.

1. **Schema** — every `payloads/NN-*.json` against `payload-file.schema.json` (and `*.spec.json` against
   `payload-spec.schema.json`). Replaces the D-8 no-op with a real JSON-Schema parse+validate.
2. **FK topology** — every `@alias` (per the frozen §7.2 grammar) resolves to an `output_ref` declared by a
   payload file appearing **earlier** in `file_sequence`; **detect cycles**; reject forward references and
   any non-`@alias` placeholder (`__FK_FROM_STEP_N__`, `$alias`, free text).
3. **Ref-ID membership** — every reference FK value exists in `raw/reference_data.json`.
4. **User membership** — every user value exists in `raw/users.json`; when `D4` resolved a gating group, the
   initiator is a member of it.
5. **Document validity** — every `documentId` exists in `raw/documents.json`.
6. **Forbidden fields** — no primary key set; no `isCustomRecordField=true` field populated.
7. **Date coherence** — offsets from `date_anchor` satisfy the ordering asserted in `D6`.

### Subcommand
```
dg validate [--mode manual|exemplar]
```

## 3. Step-by-step
1. Implement each check as an independent function returning structured findings.
2. Aggregate into `reports/validation-report.md`; set `state.json` step `5` (and exemplar `E4`).
3. Wire the §7.2 FK grammar reject-list into the FK-topology check.
4. Rewrite `step-5-validation.md` to ~60 lines (keep only the `D8` delta/null-explanation judgment prose);
   replace `exemplar-4-validation.md` with a `dg validate --mode exemplar` invocation.
5. Add `tests/test_validate.py`.

## 4. Defects resolved
- **D-8** — the no-op is gone; a malformed JSON file now fails.
- Enforces the **D-2** FK grammar frozen in Phase 0.

## 5. Retirements
- `step-5-validation.md` **306 → ~60 ln**.
- `exemplar-4-validation.md` collapses to a single `dg validate --mode exemplar` call.

## 6. Done when
```shell
python3 -m pytest tests/test_validate.py -v
```
covering **each check's pass and fail path**, and specifically:
- a **deliberately malformed JSON** file that now **fails** (proving the no-op is gone);
- a **forward-referencing `@alias`** (declared later in `file_sequence`) that is **rejected**;
- a **cycle** in the FK graph that is detected;
- a reference FK value **absent** from `raw/reference_data.json` → fail;
- a `documentId` **absent** from `raw/documents.json` → fail;
- a **PK-set** or `isCustomRecordField=true` payload → fail;
- a date offset **violating** the `D6` ordering → fail.

## 7. Risks & notes
- Cross-artifact checks depend on `raw/` being faithful — `dg` should fail loudly if a required `raw/*.json`
  is missing or shape-invalid (Phase 0 schemas make this detectable).
- Keep the FK grammar in ONE place (a shared parser in `artifacts.py`) so Phases 4, 5, 6 agree.

## 8. Handoff to Phases 5–7
Phases 5 (SQL emit), 6 (footprint), and 7 (field coverage) all depend on validated payloads; they may
proceed in parallel after Phase 4.
