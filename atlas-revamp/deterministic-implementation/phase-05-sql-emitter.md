# Phase 5 — SQL Emitter

| | |
|---|---|
| **Depends on** | Phase 4 |
| **Outcome** | `sql_emit.py` + `dg gen-sql`: deterministic, seed-stable bulk `INSERT` SQL |
| **Retires** | `generate-sql.md` — **382 → ~50 ln** (330 of its 382 lines are bucket A) |
| **Proposal refs** | §8 Phase 5; §4.1 (`generate-sql §6b–6g`) |

> **Independently valuable and low-risk** — isolated from the pipeline (no MCP interaction beyond
> `raw/field_map.json`), and the highest bucket-A density in the family. A good candidate to land early to
> demonstrate the pattern.

---

## 1. Objective
Turn validated bulk payloads/specs into a deterministic `out/bulk-data.sql` where **two runs with the same
seed produce byte-identical output.**

## 2. What to build — `sql_emit.py`
- **Column mapping** — camelCase field → `UPPER_SNAKE` column via `raw/field_map.json`.
- **Type formatting** — integers, decimals, booleans, NULL vs empty string, dates, datetimes.
- **String escaping** — embedded single quotes, backslashes, newlines.
- **FK chaining** — `LAST_INSERT_ID()` / `@variable` chaining in **insertion order** so child rows reference
  the parent's generated key.
- **Batching** — per `config/thresholds.json` (`max_records_per_payload_file` and any batch-size setting).
- **Traceability header** — emit a leading comment recording `seed`, `date_anchor`, and the source request,
  so a `.sql` file is traceable to the run that produced it.

### Subcommand
```
dg gen-sql        # reads payloads/ + raw/field_map.json -> out/bulk-data.sql
```

## 3. Step-by-step
1. Implement column mapping + per-type formatters + the string escaper.
2. Implement insertion-order FK chaining with `LAST_INSERT_ID()`/`@var`.
3. Implement batching from config.
4. Emit the traceability header comment.
5. Rewrite `generate-sql.md` to ~50 lines (keep only the bucket-B guidance: the ~20 judgment lines).
6. Add `tests/test_sql_emit.py` + a byte-identical golden diff against the bulk fixture.

## 4. Defects resolved
- Removes the ambiguity around string/type formatting being described in prose; encodes it as tested code.
- Consumes `seed`/`date_anchor` (D-10/D-11 support) so output is reproducible.

## 5. Retirements
- `generate-sql.md` **382 → ~50 ln**.

## 6. Done when
```shell
dg gen-sql                                   # against the bulk fixture
diff out/bulk-data.sql tests/fixtures/expected-bulk-data.sql   # byte-identical
python3 -m pytest tests/test_sql_emit.py -v
```
Tests MUST cover: **string escaping** (embedded quotes, backslashes, newlines), **NULL vs empty string**,
**date and datetime formatting**, **multi-level FK chaining**, **batch splitting at the boundary**, and —
the property that matters most — **two runs with the same seed produce byte-identical SQL.**

## 7. Risks & notes
- Byte-equality is unforgiving: pin row ordering, whitespace, quoting style, and newline handling.
- Dialect: match whatever the existing `generate-sql.md` targets (MySQL-style `LAST_INSERT_ID()` per the
  proposal). If multiple dialects are ever needed, mirror `data-model-workflow`'s `postgres_sql_gen.py` /
  `oracle_sql_gen.py` split — out of scope here unless required.

## 8. Handoff
Independent output; no downstream phase depends on the SQL emitter. CI (Phase 10) will run its tests.
