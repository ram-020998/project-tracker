# Feature 4 — Two Generation Modes (Manual Analysis vs Exemplar-Based): Implementation Plan

**Status:** ✅ IMPLEMENTED (steering-only, in the agent structure — 2026-07-01). Both modes are authored as
skills/references in the migrated `sql-forge` agent (F5). **Decision update:** the `get_record_footprint`
DG MCP tool (Work Item A below) is **NOT built** — exemplar footprint discovery reuses existing tools
(`query_records` + the Atlas FK graph, the same machinery as Manual Step 2), so F4 requires **zero code**.
Work Item A is retained below as an **optional future optimization** (deterministic/token-saving), to build
only if agent-driven traversal proves unreliable or too token-heavy.
**Spec:** extends `changes_V1/spec.md` (new feature; not yet folded into the spec's §5 table). Decisions D14–D18 below.
**Goal:** Give the user an explicit choice at request time between two **distinct, self-contained workflows** for creating a record in a target state:

1. **Manual Analysis** (Track A) — the existing 6-step workflow: trace the app's process models/rules, compute the deterministic write-set, build payloads from first principles. Thorough, works with **no precedent**, token-heavy.
2. **Exemplar-Based** (Track B) — the user points at a **reference record**; we read its complete footprint from the live environment (guided by the Atlas FK graph) and **clone-and-scale** it into new data. Fast, cheap, works whenever a suitable reference exists.

Both modes are available for **single** and **bulk** generation, and both converge on the **same payload artifacts + execution back-end** (records-mode `create_record`, or bulk `to_record_csv` → `insertRecordData`).

> The design principle: **two analysis front-ends, one execution back-end.** Only the "how do we decide what to write" phase differs; the "how do we write it" phase is shared and already built (Step 6 + F3).

---

## 0. Motivation

A single "create one evaluation in Awardee Selected status" request runs the full 6-step analysis every time (~45 min, heavy tokens), even though the *writes* at the end are a handful of tool calls. When a real record already exists in (or near) the target state, that record **is** the ground truth for which tables to populate and in what shape — so re-deriving it from workflow analysis is wasted work. Exemplar mode turns that record into the plan directly.

This is a deliberately **simple** first step. A richer "compiled recipe" approach (persisted, hash-validated, replayable) was considered and **shelved** — see §11. A saved exemplar-clone plan is a natural precursor to recipes if we revisit that later.

---

## 1. Current state (grounded — what we reuse)

| Asset | Where | Reused for |
|-------|-------|-----------|
| 6-step workflow (Steps 0–6 + 4b) | power `steering/step-*.md` | **Track A verbatim** (now an explicitly-selected mode) |
| Step 2 Exemplar Discovery | `step-2-exemplar-discovery.md` | Basis for Track B's footprint discovery (promoted from cross-check to primary source) |
| FK graph | Atlas KB `relationships.json`; `get_record_type_map` (relationships), `get_insertion_order` | Track B footprint traversal + insertion order |
| Business/reference classification | `table_classification.json` | Track B: clone business rows, preserve reference FKs |
| Field names/types | `get_field_map`, `get_record_properties` | Track B clone payload construction |
| Payload format | `payloads/00-metadata.json` + numbered per-table files (`fields`, `output_ref`, `$alias` FK placeholders) | **Shared artifact** both tracks emit |
| Execution (single) | `step-6-execute.md` (`create_record`, FK chaining, verify, rollback) | **Shared back-end** |
| Execution (bulk) | `step-6-bulk-csv.md` (`to_record_csv` → `insertRecordData`, PK capture) — F3 | **Shared back-end** |
| Query rows | DG `query_records` | Track B footprint reads |

**Implication:** Track A already exists. The genuinely new build is (a) one footprint-traversal tool, (b) the Track B steering (reference intake → footprint → clone/scale plan → light validation), and (c) a mode-selection router. Execution is untouched.

---

## 2. Resolved decisions (D14–D18)

| # | Topic | Decision |
|---|-------|----------|
| **D14** | Mode selection | Explicit user choice at intake: **Manual Analysis** vs **Exemplar-Based**. Agent may **auto-suggest** (reference named/available → exemplar; novel status with no precedent → manual) but the user confirms. |
| **D15** | Manual = fallback | Exemplar mode requires a suitable reference in/near the target status. If none exists (new status, empty env, unprecedented state) → **fall back to Manual**. The two are complementary, not exclusive. |
| **D16** | Footprint = coverage | In exemplar mode the reference's **actual FK-closed footprint is the coverage guarantee** — it replaces the write-set coverage gate (step-4b). Completeness = FK-graph closure from the root, not declared relationships only (see D17). |
| **D17** | Traversal completeness | Footprint traversal must walk the **full FK graph** (forward + reverse edges) from the root, not just declared record-type relationships — otherwise a raw-FK child table is silently dropped (the exact failure F1 fixed). Source of truth: `relationships.json`. |
| **D18** | Shared execution | Both tracks emit **identical `payloads/` artifacts**; execution reuses `step-6-execute` (single) and `step-6-bulk-csv` (bulk). No mode-specific execution code. Reference-table FKs are preserved (not cloned); business rows get new PKs; internal FKs re-chained via `$alias`. |

---

## 3. The two workflows (distinct and clear)

### TRACK A — Manual Analysis (unchanged 6-step)

```
Step 0  Initialize            → request folder + tracker (mode = manual)
Step 1  Workflow Analysis      → trace PMs/rules, get_entry_point_write_graph / resolve_write_set
Step 2  Exemplar Discovery     → cross-check against a real record (validation oracle)
Step 3  Data Architecture      → field maps, live ref data, coverage checklist
Step 4  Data Payloads          → build payloads/ from first principles (≥80% field coverage)
Step 4b Coverage Gate          → HARD BLOCK: resolve_write_set vs payloads (deterministic)
Step 5  Validation             → 4 automated checks
Step 6  Execution              → create_record (single) OR to_record_csv→insertRecordData (bulk)
```
- **When:** no reference exists, a novel/unprecedented target state, or the user wants a full first-principles derivation.
- **Cost:** high (full analysis). **Strength:** works with zero precedent; deterministic write-set coverage.
- **Build:** none — this is today's workflow, now reached via explicit mode = manual.

### TRACK B — Exemplar-Based (new, shorter)

```
Step 0   Initialize            → request folder + tracker (mode = exemplar)   [shared with A]
Step E1  Reference Intake       → user supplies a reference (record ID, or "find one in status X");
                                  resolve root record type UUID + PK; confirm it is in/near the
                                  target status; capture requested scale (e.g. 3 vendors, 4 factors)
                                  and any status/field delta vs the reference.
Step E2  Footprint Discovery    → get FK adjacency (get_record_type_map + relationships.json);
                                  call get_record_footprint(root) → ALL business rows across the
                                  FK-closed subgraph (root + descendants + reverse-FK children);
                                  classify business vs reference; write footprint.md.
Step E3  Clone & Scale Plan     → emit payloads/ from the footprint:
                                    • strip PKs (auto-generated)
                                    • rewrite INTERNAL FKs to $alias placeholders in insertion order
                                    • PRESERVE reference-table FKs as-is (status/method/decision ids)
                                    • replicate child-row groups to hit requested counts (3 vendors/4 factors)
                                    • apply field mutations for uniqueness (names/titles/dates)
                                    • apply requested target-state deltas (e.g. status, 1-of-N awardee flag)
                                  Write payloads/ + 00-metadata.json (SAME format as Track A).
Step E4  Validation (light)     → FK integrity of the clone plan; reference IDs still resolve LIVE;
                                  uniqueness/constraint check; footprint completeness (all FK children
                                  captured). NO workflow coverage gate (footprint IS coverage — D16).
Step 6   Execution              → create_record (single) OR to_record_csv→insertRecordData (bulk)  [shared with A]
```
- **When:** a real record exists in/near the target status ("make me another like #158").
- **Cost:** low (one footprint read + clone). **Strength:** empirically correct table set + shapes; no workflow tracing.
- **Build:** `get_record_footprint` tool + 4 Track-B steering files + router.

### Side-by-side

| | Track A — Manual | Track B — Exemplar |
|---|---|---|
| Source of truth | app process models/rules (KB) | a real record's live footprint |
| "Which tables?" | `resolve_write_set` (deterministic) | FK-closed footprint of the reference |
| Coverage guarantee | step-4b hard-block gate | footprint completeness (FK closure) |
| Reference data | queried live, chosen by reasoning | inherited from the exemplar (preserved) |
| Needs a precedent? | No | Yes (else fall back to A) |
| Relative cost | High | Low |
| Emits | `payloads/` | `payloads/` (identical format) |
| Executes via | Step 6 / step-6-bulk-csv | Step 6 / step-6-bulk-csv |

---

## 4. Work item A — DG MCP `get_record_footprint` (OPTIONAL / DEFERRED)

> **Not built for V1.** Exemplar E2 reads the footprint with existing tools (`query_records` +
> `get_schema_relationships`/`get_record_type_map`), exactly as Manual Step 2 does. This section is a
> spec for a **future optimization** — a single deterministic BFS call that would reduce tokens and
> guarantee traversal completeness. Build only if the steering-driven traversal proves insufficient.

The one genuinely new tool. Deterministic FK-graph traversal from a root record, returning every related **business** row so the clone plan is complete (D17).

- **New tool class** `FootprintTools` in `data_generator/tools/footprint.py`.
- **Signature:** `get_record_footprint(root_record_type_uuid, root_pk, adjacency, max_depth=..., include_reference=false)`
  - `adjacency`: FK graph the agent passes in (from Atlas `get_record_type_map` / `relationships.json`) — `{record_type_uuid: [{fk_field, target_uuid, direction}]}`. Keeps DG env-only (no KB dependency).
  - BFS/DFS from the root: follow reverse edges (tables whose FK points at the root/descendants) to collect children, and forward edges for parent context. Query each table via existing `query_records` filtered by the linking key.
  - `include_reference=false` → do NOT descend into reference tables (they're preserved, not cloned); still record the reference FK values.
- **Returns:** `{ root: {...}, tables: [{table, record_type_uuid, classification, rows:[...]}], edges:[...] }` — grouped rows + the edge map (so E3 knows which FK columns to re-chain).
- **Read-only.** No session impact. Register in `models.py` + `server.py` + `tools/__init__.py`.
- **Tests:** mock `query_records`; assert full closure (reverse-FK child discovered), reference tables not descended, depth guard, cycle guard.

> Optional companion (defer unless needed): `find_status_exemplar(record_type_uuid, status_field, status_value)` to auto-locate a candidate reference for D14 auto-suggest. Track B works without it (user supplies the reference).

---

## 5. Work item B — Track B steering (new, distinct track)

New files under `steering/` (both power copies), clearly separated from the Track A `step-*` files:

- `exemplar-step-1-reference-intake.md` — resolve root record type + PK; confirm status proximity; capture scale + deltas; **fall back to Manual if no suitable reference (D15)**.
- `exemplar-step-2-footprint-discovery.md` — fetch adjacency (Atlas), call `get_record_footprint`, classify, write `footprint.md`. Enforce **FK-closure completeness (D17)**.
- `exemplar-step-3-clone-scale-plan.md` — build `payloads/` from the footprint: PK strip, internal-FK → `$alias`, **reference-FK preserve**, group replication for scale, field mutation for uniqueness, target-state deltas. Same payload format as Track A.
- `exemplar-step-4-validation.md` — light checks (FK integrity, live ref-ID resolution, uniqueness, footprint completeness). No coverage gate.

Then **both tracks hand off to the existing** `step-6-execute.md` (single) / `step-6-bulk-csv.md` (bulk).

Supporting doc edits:
- `step-0-initialize.md` — record `mode` (manual | exemplar) and, for exemplar, the reference id + requested scale in the tracker template.
- `tool-reference-data-generator.md` — document `get_record_footprint`.

---

## 6. Work item C — Mode selection / router

- **`action-generate-data.md`:** add a **mode-selection gate** at intake:
  - If the user names/points to a reference record → **Exemplar** track.
  - If the user requests a novel status with no precedent → **Manual** track.
  - Otherwise **ask**: "Analyze the workflow from scratch (Manual), or clone an existing reference record (Exemplar)?" (D14)
  - After selection, route to Track A (`step-1…`) or Track B (`exemplar-step-1…`); both rejoin at Step 6.
- **`POWER.md`:** document the two modes, the side-by-side table, and that both feed the same execution back-end. Update the action router.
- **`.kiro/steering.md`** (prod): add the two-track structure + the `get_record_footprint` tool.
- Apply to **both** power copies; verify parity (`diff -rq`).

---

## 7. Sequencing

```
A (get_record_footprint tool)  ──►  B (exemplar-step-* steering)  ──►  C (router + POWER + parity)
Track A steering: no change (already built).
Execution back-end (Step 6 / bulk-csv): no change (shared).
```
- A first (steering references it). B + C are doc work. Independent of F1–F3 code (reuses their outputs).

## 8. Testing

| Layer | Test |
|-------|------|
| DG unit | `get_record_footprint`: full FK closure incl. reverse edges; reference tables not descended; depth/cycle guards; grouped output shape. |
| Steering (manual) | Run an exemplar-less request end-to-end → Track A unchanged, still passes step-4b. |
| Steering (exemplar, single) | "Clone eval #158 as another Awardee-Selected eval" → footprint discovered, clone payloads emitted, `create_record` chain succeeds, verify matches the reference shape. |
| Steering (exemplar, scale) | "…with 3 vendors and 4 factors" → child groups replicated correctly, uniqueness mutations applied, FK chaining intact. |
| Steering (exemplar, bulk) | Same footprint → `to_record_csv` → `insertRecordData`, PKs chained across tables. |
| Fallback | Request a status no record has reached → agent falls back to Manual (D15). |

## 9. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Incomplete footprint silently drops a table (reintroduces F1 bug) | Traverse the **full FK graph** (D17), not declared relationships; footprint-completeness check in E4; post-exec `verify_write_coverage` backstop. |
| Cloning reference rows by mistake | `include_reference=false` + `table_classification`: preserve reference FKs, never clone reference tables. |
| Unique-constraint collisions on clone | Field-mutation step in E3 (names/titles/dates); E4 uniqueness check. |
| Exemplar status ≠ target status | E1 confirms proximity; E3 applies explicit status/field deltas; if the gap is large, recommend Manual. |
| Scaling fan-out (3 vendors × 4 factors → 12 consensus rows) wrong | E3 replication is group-based and explicit; E4 FK-integrity check validates the expanded graph. |
| Big footprint / query volume | `max_depth` guard; batch queries; bulk path for large clones. |

## 10. Acceptance criteria
- [ ] User is offered **Manual** vs **Exemplar** at intake; agent auto-suggests but user confirms (D14); Manual reachable as fallback (D15).
- [ ] `get_record_footprint` returns an FK-closed business-row footprint from a root record (reverse edges included), preserving reference FKs; unit-tested.
- [ ] Track B (`exemplar-step-1..4`) produces `payloads/` in the **same format** as Track A and hands off to the shared Step 6 / bulk-csv execution.
- [ ] Exemplar single-clone recreates the reference's footprint (verified against the source); exemplar scale (3 vendors/4 factors) replicates child groups with unique values and intact FK chaining.
- [ ] Exemplar bulk path clones via `to_record_csv` → `insertRecordData` with PK chaining.
- [ ] Both power copies updated + parity verified; POWER.md documents the two modes and the shared back-end.

## 11. Out of scope / future

- **Compiled/persisted recipes** (hash-validated, replayable `ADG_Recipe` store) — explicitly **deferred**. Exemplar mode delivers most of the token savings with far less work; a saved clone plan is a natural precursor if recipes are revisited.
- `find_status_exemplar` auto-locator — optional; build only if manual reference-picking proves clunky.
- Cross-application footprints — single-app only for V1.
