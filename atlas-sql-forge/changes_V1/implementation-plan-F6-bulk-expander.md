# Feature 6 — Streamlined Bulk Generation (compact spec + deterministic expander + loader sub-agent)

**Status:** ✅ BUILT (2026-07-02) — Work Items A (DG tool, committed by user), B (spec authoring), C (loader flow) all done. Remaining: a live end-to-end bulk run to validate the full spec → expand → insert loop.
**Spec basis:** extends F3 (bulk CSV) and F4 (exemplar mode). New decisions D19–D22 below.
**Goal:** Stop the agent from hallucinating / hand-writing Python to build bulk CSV. Separate **authoring**
(LLM emits a small per-table spec) from **expand + format + write** (deterministic tool + isolated loader
sub-agent). The LLM never expands to scale or invents rows in-flight, and never hand-builds CSV.

> Root cause (from two bulk test sessions): bulk execution made the LLM invent values, expand to scale,
> format CSV, and chain FKs all at once, per table, in the main context → drift, ad-hoc `execute_bash`
> Python, context blowup, premature SQL bail-out. Single mode doesn't hallucinate because Step 4
> **materializes** the rows first. Bulk needs the same separation, but the artifact must be a **compact
> spec** (template × scale), not thousands of raw rows.

---

## Decisions (D19–D22)

| # | Topic | Decision |
|---|-------|----------|
| **D19** | Bulk artifact | Materialize a **compact per-table generation spec** (`payloads/NN-<table>.spec.json`): template row + count/FK-fan-out + generators. NOT thousands of raw rows. Gated like single-mode payloads. For small/irregular tables the spec may carry literal rows. |
| **D20** | Expansion | A **deterministic DG MCP tool** `expand_record_csv` expands the spec (+ resolved parent PKs) into contract-correct CSV, reusing `to_record_csv`'s formatter. **No LLM row emission, no Python.** Chunked to ≤~1000 rows/batch. |
| **D21** | Execution isolation | A **`bulk-loader`** execution flow driven by a **loader sub-agent** (one per run; per-table only if a single table is huge). It calls `expand_record_csv` → `insertRecordData` per table in insertion order and returns only **assigned PK ranges** to the orchestrator. Big CSV never enters the orchestrator context. |
| **D22** | FK chaining | Orchestrator holds a small **PK map** (`alias → [pk range]`). Each table's spec declares `fk_binding {field, parent_alias, children_per_parent}`; the loader resolves `parent_alias` → parent PKs before expanding. |

---

## The spec format (`payloads/NN-<table>.spec.json`)

```jsonc
{
  "table": "AS_GSS_TEAM_MEMBERSHIP",
  "record_type_uuid": "7ac70e31-...",
  "alias": "membership",                 // for downstream FK references
  "fk_binding": {                         // drives row count when present
    "field": "teamId",
    "parent_alias": "team",               // resolved to parent PKs at load time
    "children_per_parent": 4
  },
  "row_count": null,                       // used only when no fk_binding
  "seed": 42,
  "template": {                            // field -> literal OR {gen:...}
    "member":   { "gen": "cycle", "values": ["emily.cm","frank.factorAdvisor","mike.evalChair","eric.evaluationChair"] },
    "createdBy": "admin.user",
    "isActive": 1
  }
}
```

### Generator vocabulary (deterministic, seeded)
| gen | fields | output |
|-----|--------|--------|
| literal (no `gen`) | — | constant value |
| `const` | `value` | constant |
| `seq` | `prefix`,`suffix`,`start`,`pad` | `BLK-0001`, `BLK-0002`… (global row index) |
| `cycle` | `values[]` | cycles by row index |
| `pick` | `values[]` | seeded pseudo-random pick |
| `int` | `start`,`step` **or** `min`,`max` | sequential or random int |
| `date` | `base`,`step_days` **or** `random_within_days` | `YYYY-MM-DD` offset/base |
| `str` | `format` (`{i}` global,`{p}` parent,`{c}` child) | templated string |
| `row_index` | — | 1-based global index |

Row expansion: with `fk_binding`, generate `children_per_parent` rows per parent PK (fan-out), set the FK
field to that PK; else generate `row_count` rows. Then `build_record_csv` formats to the CSV contract.

---

## Work items

### A — DG MCP `expand_record_csv` tool  (`data_generator/tools/csv_format.py`)  ✅ DONE (2026-07-02)
- `SpecError`, `_eval_generator(spec, gi, p_idx, c_idx, rng)`, `expand_rows(template, row_count, fk_binding, seed)`.
- `CsvTools.expand_record_csv(arguments)` → validate → `expand_rows` → per-batch `build_record_csv` →
  return `{success, row_count, batch_count, columns, skipped_fields?, csv_batches:[...]}`. Reuses `build_record_csv`.
- Registered: `models.py` (`get_csv_tools`, full inputSchema) + `server.py` (`tool_handlers`).
- Tests: `tests/test_csv_format.py` (TestExpandRows + TestExpandRecordCsvTool) + `test_server.py` count/name updated to 16 tools.
- **Verified:** `pytest` 77 passed; `flake8 --max-line-length=120 --ignore=E501,W503` clean. Branch `feature/f1-cdt-dse-tools` (not committed).

### B — Spec authoring in steering (agent repo, `data-pipeline/references`)  ✅ DONE (2026-07-02)
- **Exemplar bulk (E3):** `exemplar-step-3-clone-scale-plan.md` now mode-aware — single → literal `payloads/`;
  **bulk → compact `payloads/NN-<table>.spec.json`** (template + fk_binding/row_count + generators). Cloning
  rules mapped onto generators; secondary FKs via `from_alias` tokens; scale via `children_per_parent`. QC updated.
- **Manual bulk (Step 4):** same spec format applies (documented via the shared spec shape + generator vocab).
- `expand_record_csv` documented in `tool-reference-data-generator.md`.

### C — Loader flow / sub-agent (agent repo)  ✅ DONE (2026-07-02)
- `step-6-bulk-csv.md` rewritten: spec-driven flow in a **loader sub-agent** — resolve FK parent PKs from a
  **PK map** (primary via `fk_binding.parent_alias`, secondary via `from_alias`) → `expand_record_csv` →
  `insertRecordData` per `csv_batches` element → capture PKs. Literal-row path retained (6c-legacy). Critical
  rules + QC + intro updated: no hand-built CSV / no `execute_bash` Python; keep CSV out of orchestrator context.
- `bulk-data-generation/SKILL.md` Step 3 + hard rules point at the spec/expand loader flow.

---

## Sequencing
A (tool + tests, DG MCP) → B (spec authoring steering) → C (loader flow + sub-agent). A is independent code;
B/C are steering. Ship A first (unblocks everything), then B+C together (they're co-dependent).

## Acceptance
- [ ] `expand_record_csv` deterministically expands a spec into contract-correct, batched CSV; unit-tested; flake8 clean.
- [ ] Exemplar bulk emits per-table `*.spec.json` from the footprint (no thousands of raw rows in context).
- [ ] `step-6-bulk-csv` runs spec → `expand_record_csv` → `insertRecordData` with FK chaining via the PK map, inside a loader sub-agent; **zero `execute_bash` Python for CSV**.
- [ ] A 100-eval Awardee-Selected bulk run completes via CSV with all child tables, correct fan-out, unique keys — no hallucinated/hand-built CSV, no SQL bail-out.

## Out of scope (later)
- Data-realism vocabulary depth (value pools / faker / seed-then-distribute) — noted, deferred by user.
- Manual-mode large-volume authoring polish beyond the shared spec format.
