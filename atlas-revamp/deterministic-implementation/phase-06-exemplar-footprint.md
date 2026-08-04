# Phase 6 — Exemplar Footprint

| | |
|---|---|
| **Depends on** | Phase 4 |
| **Outcome** | `footprint.py` + `dg plan-footprint` / `dg build-footprint`: FK-closed BFS plan + clone mechanics in code |
| **Retires** | `exemplar-2-footprint-discovery.md` **73 → ~15 ln**; `exemplar-3-clone-scale-plan.md` **106 → ~45 ln** |
| **Proposal refs** | §8 Phase 6; §2.2 (the family already anticipated this); Appendix (E2/E3) |

> The authors already flagged this in prose: *"a future `get_record_footprint(root_uuid, root_pk, adjacency)`
> DG tool could perform this BFS in one deterministic call."* Phase 6 implements that **agent-side** and
> eliminates the failure mode `E2` devotes a whole `🛑` section to — guessing the wrong FK column.

---

## 1. Objective
Derive the complete, FK-closed footprint of an exemplar record from the schema graph (not from agent
guesswork), then perform the deterministic clone/remap/scale mechanics.

## 2. What to build — `footprint.py`

### 2.1 `dg plan-footprint`
From `raw/record_type_map.json` + `raw/schema_relationships.json`, emit the **complete BFS query plan**:
every table with an FK pointing at the root or a descendant, each annotated with **its real FK column** and
the parent PKs to filter by. Because the FK column is *derived from the graph*, the wrong-FK guess `E2`
warns about cannot occur:
> *"Filtering such a table by the root id returns empty OR a 500 — that is NOT evidence the table is empty."*
Include **cycle detection** via a visited set (E2 asks for this in prose).

### 2.2 `dg build-footprint`
From `raw/exemplar/*.json` (the responses the agent captured by running the plan), assemble:
`reports/footprint.md`, the **edge map**, per-table **row counts**, and the **reference-FK values to preserve**.

### 2.3 Clone mechanics (E3 rules 1–3, 6) in code
- **Rule 1/2/3:** strip PKs; remap **internal** FKs to `@alias` (per §7.2 grammar); preserve **reference**
  FKs verbatim.
- **Rule 6:** fan out by `children_per_parent` (`@alias[$i]` indexing).
- **Rules 4 and 5 stay as decisions** `D10` (uniqueness mutation) and `D11` (fan-out count) — the model
  supplies these; code consumes them.

### Subcommands
```
dg plan-footprint    # raw/{record_type_map,schema_relationships}.json -> BFS query plan (for the agent to run)
dg build-footprint   # raw/exemplar/*.json -> reports/footprint.md + edge map + counts + ref-FK values
```

## 3. Step-by-step
1. Build the adjacency model from `schema_relationships.json`; implement BFS with visited-set cycle guard.
2. For each discovered edge, resolve the **actual FK column** (never assume it's the root id).
3. Emit the query plan (table, FK column, parent-PK filter) for the agent to execute via MCP.
4. Implement `build-footprint` assembly from captured `raw/exemplar/*.json`.
5. Implement clone/remap/scale for E3 rules 1–3, 6; leave D10/D11 as decision inputs.
6. Trim `exemplar-2` → ~15 ln and `exemplar-3` → ~45 ln (keep D10/D11/D13 judgment prose only).
7. Add `tests/test_footprint.py`.

## 4. Defects resolved
- Eliminates the wrong-FK-column failure mode structurally (FK derived from the graph).

## 5. Retirements
- `exemplar-2-footprint-discovery.md` **73 → ~15 ln**.
- `exemplar-3-clone-scale-plan.md` **106 → ~45 ln** (D10, D11, D13 only).

## 6. Done when
```shell
python3 -m pytest tests/test_footprint.py -v
```
covering, with the plan asserting the **correct FK column in every case**:
- a **diamond** FK graph;
- a **grandchild** linking by its parent's PK rather than the root's;
- a **self-referencing** table;
- a **cycle** (visited-set prevents infinite traversal);
- a table whose **real FK differs from the root id** (asserts the plan names the correct column, not the root).

## 7. Risks & notes
- The correctness of the whole exemplar mode hinges on reading `schema_relationships.json` faithfully — add a
  shape check and fail loudly on an unexpected structure.
- Keep the `@alias`/`@alias[$i]` emission consistent with the §7.2 grammar and the Phase 4 validator.

## 8. Handoff
Feeds validated exemplar payloads into the same `dg validate` / `dg coverage-gate` path as manual mode.
