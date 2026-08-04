# Phase 3 — Coverage Gate

| | |
|---|---|
| **Depends on** | Phase 2 |
| **Outcome** | `coverage.py` + `dg coverage-gate` + `dg verify-input`; the required-table set becomes deterministic |
| **Retires** | `step-4b-coverage-gate.md` **234 → ~30 ln**; `step-5` §5a (**~96 ln**) entirely; `create-records` §6e |
| **Proposal refs** | §8 Phase 3; §6.3; Appendix D-3, D-4; Appendix B (worked example) |

> **Highest-value phase.** It is the most code-ready file *and* where the current defects actually break
> runs: three conflicting coverage implementations (D-3, two of which can deadlock) and a gate that silently
> substitutes human judgment yet still reports `✅ PASS` (D-4). See Appendix B for the 234-line → 30-line
> before/after.

---

## 1. Objective
Make **`resolve_write_set`** the single authority for the required table set, do the set arithmetic in code,
and make every other coverage check consume this result instead of recomputing it.

## 2. What to build — `coverage.py`
Pure functions over `raw/write_set.json` and `payloads/`:
- `required_set(raw/write_set.json) -> {table: {classification, mechanism, reason}}`
- `payload_set(payloads/) -> {table}`
- `diff() -> {missing, extra, covered}`
- `mechanism_map() -> {table: RECORD|CDT}` — **emitted as JSON in `state.json`**, not only as a markdown
  table, so `create-records` (Phase 8) and `verify_write_coverage` consume structured data.
- `render_report() -> reports/coverage-gate.md`

### 2.1 Fix the three-way conflict (D-3)
`step-4b` (uses `resolve_write_set`, allows *branch-not-taken* exclusions), `step-5` §5a (recomputes from
`get_app_schema`, permits only `REFERENCE/AUDIT/NOT API-WRITABLE`, else FAIL), and `create-records` §6e
(post-execution) are three checks with conflicting authorities — a table legitimately excluded at 4b is a
mandatory FAIL at 5a with no resolution path. **Resolution:** `dg validate` (Phase 4) reconciles against
`state.json.steps["4b"]`; it must **not** call `get_app_schema` and must **not** apply a second exclusion
taxonomy. There is one required set and one exclusion policy.

### 2.2 Refuse to silently degrade (D-4)
```py
if not required and write_graph_empty:
    state.set("4b", "BLOCKED", gate_mode="kb_stale")
    die("KB write graph is empty — likely a stale parse. "
        "Re-parse the KB, or re-run with --allow-degraded to proceed using the manual "
        "Table Inventory. A degraded run is never reported as PASS.")
```
`--allow-degraded` proceeds but sets `gate_mode=degraded_manual`; the report is **permanently tainted** and
must never render an unqualified `PASS`.

### 2.3 Exclusions
Only tables in `write_set.json`'s `excluded_tables`, or carrying a **cited** `branch_decision`, may be
excluded:
```
dg coverage-gate --exclude AS_GSS_REJECTION --cite "Approved?=yes"
```
An **uncited** exclusion is rejected (`BLOCKED`).

### 2.4 `dg verify-input`
Builds `verify_write_coverage` arguments from the mechanism map: `record_type_uuid` for RECORD,
`constant_name` for CDT — so the mismatch `create-records` §6e warns about becomes impossible.

## 3. Step-by-step
1. Implement the four pure functions + report renderer.
2. Emit `mechanism_map` into `state.json.steps["4b"]`.
3. Implement the empty-required-set refusal + `--allow-degraded` taint.
4. Implement cited-exclusion handling.
5. Implement `dg verify-input`.
6. Rewrite `step-4b-coverage-gate.md` to the ~30-line Appendix-B form; delete `step-5` §5a; delete
   `create-records` §6e hand-construction.
7. Add `tests/test_coverage.py` + a golden-file replay.

## 4. Defects resolved
- **D-3** — one authoritative required set; Step 5 consumes, never recomputes.
- **D-4** — `gate_mode` + refusal; degraded runs can never masquerade as `PASS`.

## 5. Retirements
- `step-4b-coverage-gate.md` **234 → ~30 ln** (Appendix B).
- `step-5` §5a **(~96 ln)** deleted entirely.
- `create-records` §6e hand-construction removed.

## 6. Done when
```shell
python3 -m pytest tests/test_coverage.py -v
```
covering **at minimum**:

| Test | Expected |
|---|---|
| all required tables present | `PASS`, exit 0 |
| one required table missing | `BLOCKED`, exit 1, missing table named in stdout |
| missing table with a cited branch exclusion | `PASS`, exclusion recorded with citation |
| missing table with an uncited exclusion | `BLOCKED` |
| extra table in payloads | `PASS` with a note — never a failure |
| empty `required_tables` + empty write graph | `BLOCKED`, `gate_mode=kb_stale`, non-zero exit |
| same input, `--allow-degraded` | proceeds, `gate_mode=degraded_manual`, report never says unqualified `PASS` |
| CDT table present | mechanism map emits `constant_name`, not `record_type_uuid` |

**Plus a golden-file replay:** `dg coverage-gate` against the Phase 0 fixture reproduces the committed
`coverage-gate.md` **byte for byte**.

## 7. Risks & notes
- The golden `coverage-gate.md` must be rendered by the same code path the test asserts — pin the renderer
  (ordering, whitespace) so byte-equality holds.
- Do not let `dg validate` (Phase 4) re-open the exclusion question; it only *reconciles* against 4b state.

## 8. Handoff to Phase 4
Phase 4 (`validate.py`) consumes the mechanism map + exclusion decisions recorded here and adds the
schema/FK/ref/user/document/date checks.
