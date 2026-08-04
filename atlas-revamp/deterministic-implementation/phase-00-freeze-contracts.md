# Phase 0 — Freeze the Contracts (schemas + fixtures)

| | |
|---|---|
| **Depends on** | — (first phase) |
| **Outcome** | Five JSON Schemas + three captured MCP fixtures; every Appendix-A defect resolved on paper |
| **Retires** | No prose yet (this phase writes **no executable logic**) |
| **Ships code?** | No — schemas + fixtures + recorded decisions only |
| **Proposal refs** | §7 (contracts), §8 Phase 0, Appendix A (defects) |

> **Why this is first, and why it ships no logic.** Getting the contracts wrong is *the only failure mode
> that forces a rewrite*. Every defect in Appendix A is a symptom of one contract being undefined. Freeze
> them, prove them against real captured data, and every later phase becomes a safe, testable increment.

---

## 1. Objective

Produce the immutable interfaces the whole `dg` CLI will read and write:
1. **Five JSON Schemas** under `<dg-root>/scripts/schemas/` (DEC-1 decides `<dg-root>`).
2. **Three fixture trees** under `<dg-root>/tests/fixtures/` — one each for **manual**, **exemplar**, **bulk**
   — each a real, captured end-to-end run (verbatim MCP responses in `raw/` + the expected downstream artifacts).
3. **A recorded resolution for every Appendix-A defect (D-1 … D-15)**, written inline into the schema
   `description` fields and logged in `tracker.md` §4.

## 2. Prerequisites (hard)

- **DEC-2 must be resolved: a working MCP capture environment.** You need Atlas MCP + Data Generator MCP
  authenticated against a real application (the proposal uses **SourceSelection**) to capture `raw/`. Without
  it, fixtures cannot be created and Phase 0 cannot complete. Confirm before starting.
- **DEC-1 (`<dg-root>`)** should be decided now so paths in schemas/fixtures are final. Recommended:
  `.kiro/resources/data-generator/` (shared by all four skills). Proposal default: `.kiro/skills/data-gen/`.
- Python 3 with `jsonschema` available (`python3 -m jsonschema`).

## 3. The five contracts (author them exactly)

Author each schema as **JSON Schema draft 2020-12**. Encode the Appendix-A resolution in each field's
`description`. Below is the required shape (from proposal §7) — expand every field with type, enum, and
`description`.

### 3.1 `payload-metadata.schema.json` (resolves D-1)
Backs `payloads/00-metadata.json`. Required keys and intent:
```jsonc
{
  "schema": 1,
  "status": "PASS",                       // enum: PENDING|IN_PROGRESS|PASS|BLOCKED  (D-5)
  "application": "SourceSelection",
  "mode": "manual",                        // enum: manual|exemplar
  "volume_mode": "single",                 // enum: single|bulk
  "seed": 20260729,                        // int; default YYYYMMDD (D-10)
  "date_anchor": "2026-07-29",             // ISO date; default today (D-11)
  "fk_placeholder_convention": "at-alias-v1",   // pins the ONE FK grammar (D-2)
  "file_sequence": ["01-evaluation.json", "02-vendor.json"],
  "total_records": 18,
  "field_completeness": {
    "AS_GSS_EVALUATION": { "writable": 20, "populated": 18, "coverage_pct": 90 }
  }
}
```
**D-1 resolution to encode:** there is exactly ONE payload representation — the split `payloads/` directory.
The monolithic `payloads.json` does not exist in any contract. State this in the schema `description`.

### 3.2 `payload-file.schema.json` (single mode) + `payload-spec.schema.json` (bulk)
`payloads/NN-{table}.json` (single):
```jsonc
{
  "table": "AS_GSS_EVALUATION",
  "mechanism": "RECORD",                   // enum: RECORD|CDT
  "record_type_uuid": "e6bc8561-...",      // RECORD only (else null)
  "constant_name": null,                   // CDT only
  "cdt_type": null,                        // CDT only
  "alias": "evaluation",                   // declares this table's output alias
  "records": [
    { "description": "Root evaluation record",
      "output_ref": "evaluation",
      "fields": { "evaluationTitle": "HD260519Q0001", "evaluationStatusId": 3 },
      "field_reasoning": { "evaluationTitle": "…", "evaluationStatusId": "…" } }  // Phase 7 enforces presence
  ]
}
```
`payload-spec.schema.json` (bulk): keep the shape already specified in `E3` (it is sound). Encode the
distinction that **bulk `fk_binding` + `{"gen":"cycle"|"pick","from_alias":...}` are BINDINGS, not the
`@alias` placeholder** (D-2) — never conflate the two.

### 3.3 FK placeholder grammar (resolves D-2) — encode as a schema `pattern` + validator rule
```
fk_ref  ::= "@" alias ( "[" index "]" )? ( "." field )?
alias   ::= [a-z][a-z0-9_]*
index   ::= [0-9]+ | "$i"        // $i = current row index during fan-out
```
Rules to document (enforced later at `dg validate`, Phase 4): `alias` MUST match an `output_ref` declared by
a payload file **earlier** in `file_sequence`; omitted `.field` → target PK; `dg validate` **rejects**
`__FK_FROM_STEP_N__`, `$alias`, and any free-text placeholder.

### 3.4 `state.schema.json` (resolves D-4, D-5)
```jsonc
{
  "schema": 1,
  "mode": "manual", "volume_mode": "single",
  "application": "SourceSelection", "seed": 20260729, "date_anchor": "2026-07-29",
  "gate_mode": "resolve_write_set",        // enum: resolve_write_set|degraded_manual|kb_stale  (D-4)
  "steps": {
    "0":  { "status": "PASS", "artifacts": ["reports/analysis.md"] },
    "1":  { "status": "PASS", "entry_points": ["AS_GSS_Award_Vendor"],
            "branch_decisions": { "Approved?": "yes" } },
    "4b": { "status": "PASS", "required": 12, "covered": 12,
            "missing": [], "excluded": [{ "table": "AS_GSS_REJECTION", "cite": "Approved?=yes" }] }
  }
}
```
**D-5:** `status` enum is exactly `PENDING|IN_PROGRESS|PASS|BLOCKED`. **`state.json` never contains emoji.**
**D-4:** `gate_mode` makes a degraded run permanently distinguishable and forbids rendering it as unqualified `PASS`.

### 3.5 `decisions.schema.json` (stub now; finalized in Phase 8)
Author top-level keys `D1`…`D14` with the output schemas from proposal §5 (e.g. `D1 →
{app, entity, target_status, conditions[], volume, mode}`). Phase 8 finalizes; Phase 0 fixes the shape so
fixtures can carry a real `decisions.json`.

### 3.6 `config/thresholds.json` (resolves D-6, D-14) — committed config, not a schema
```jsonc
{ "min_field_coverage_pct": 80,
  "coverage_rounding": "floor",            // resolves 5/8 = 62 vs 62.5 (D-14)
  "max_records_per_payload_file": 6,
  "live_record_limit": 50,                 // data-gen vs data-gen-bulk routing boundary (D-6)
  "bulk_min_rows": 100 }
```

## 4. The three fixtures (the single most valuable artifact of the project)

For each mode, capture ONE real run and store it under `<dg-root>/tests/fixtures/<name>/`:
- `sourceselection-manual/`
- `sourceselection-exemplar/`
- `sourceselection-bulk/`

Each fixture contains:
- `raw/` — **verbatim** MCP responses (never hand-edited): `record_type_map.json`, `field_map.json`,
  `insertion_order.json`, `write_graph.json` (`get_entry_point_write_graph`), `write_set.json`
  (`resolve_write_set`), `schema_relationships.json`, `reference_data.json`, `users.json`, `documents.json`,
  `record_properties/{uuid}.json`, and (exemplar) `exemplar/{table}.json`.
- `decisions.json` — the recorded model decisions for that run.
- The **expected** downstream artifacts (`payloads/`, `reports/`, `state.json`, and for bulk `out/bulk-data.sql`)
  that later phases will regenerate and diff against **byte-for-byte**.

Also write **`tests/fixtures/README.md`** documenting the exact capture procedure (which MCP tool produced
which `raw/*.json`, in what order) so a fixture can be re-captured when an MCP server version bumps.

## 5. Step-by-step

1. Resolve **DEC-1** (`<dg-root>`) and **DEC-2** (capture env). Record both in `tracker.md` §5.
2. Create `<dg-root>/scripts/schemas/` and author the five schemas above (draft 2020-12), embedding each
   Appendix-A resolution in `description` text.
3. Create `<dg-root>/scripts/config/thresholds.json`.
4. Capture the **manual** fixture end-to-end; save verbatim `raw/`, then author the expected `payloads/`,
   `reports/`, `state.json`, `decisions.json` by hand from that run.
5. Repeat for **exemplar** and **bulk** (bulk adds `out/bulk-data.sql` and uses `*.spec.json` payloads).
6. Write `tests/fixtures/README.md`.
7. Walk **every** Appendix-A row (D-1…D-15); write its resolution into the relevant schema description and
   flip its row in `tracker.md` §4 to CLOSED with a one-line note. (D-12 is already CLOSED.)
8. Validate all three fixtures against the schemas (see Done when).

## 6. Defects resolved in Phase 0
D-1 (§3.1), D-2 (§3.3), D-5 (§3.4), D-6/D-14 (§3.6), and the **paper resolution of all remaining defects**
recorded inline. D-12 is already CLOSED (commit `7095239373`).

## 7. Retirements
None yet — Phase 0 deletes no prose. (Deletions begin in Phase 1.)

## 8. Done when

```shell
# every artifact in every fixture validates against its schema:
python3 -m jsonschema -i tests/fixtures/sourceselection-manual/payloads/00-metadata.json \
  scripts/schemas/payload-metadata.schema.json
#   … repeat for state.json, decisions.json, each payload file/spec, in all three fixtures
```
- ✅ All three fixture trees validate against the frozen schemas with no errors.
- ✅ `tests/fixtures/README.md` documents the capture procedure.
- ✅ Every Appendix-A row has a recorded resolution (tracker §4 has zero OPEN rows that Phase 0 owns:
  D-1, D-2, D-5, D-6, D-14, plus paper notes for the rest).

## 9. Risks & notes
- **Fixture drift** is the top risk — mitigated by the Phase 10 schema-lint job and the documented capture
  procedure. Re-capture on MCP version bumps.
- **Do not write any logic.** If you feel the urge to "just validate in code," stop — that's Phase 1+.
- Keep `raw/` **verbatim**. Hand-editing a captured response invalidates the golden-file guarantee.

## 10. Handoff to Phase 1
Phase 1 (`state.py` + `gate.py`) consumes `state.schema.json` and the status enum frozen here, and tests
against the captured fixtures. Do not start Phase 1 until all three fixtures validate.
