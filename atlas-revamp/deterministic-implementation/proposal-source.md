# Proposal — Convert the Appian Data Generation Skill Family from Prose Imperatives to Deterministic Code

**Status:** Proposal — for discussion, not yet approved **Author:** walid.elsayed **Date:** 2026-07-29 **Subject:** `.kiro/skills/data-gen*` \+ `.kiro/resources/data-generator/` as introduced in [MR \!101](https://gitlab.appian-stratus.com/appian/prod/solutions-os/-/merge_requests/101) **Relationship to MR \!101:** **Follow-up MR.** MR \!101 should merge once its own blockers are resolved (see `mr-101-part-1-kiro-and-readme-review.md`). This work is a separate, larger change and must not be bolted onto it. **Chosen approach:** Option 4 — full pipeline, **agent-driven** (the agent orchestrates and calls a CLI; the CLI never calls a model)

---

## 1\. Summary

The data generation family currently expresses its workflow as **4,194 lines of markdown imperatives**. It attempts to guarantee correct behavior through emphasis — 5 `🛑 STOP!` banners, 40+ `⚠️` markers, `MANDATORY COMPLIANCE` headers, and seven `COMMON FAILURES TO AVOID` tables. Only three operations in the entire family are actually deterministic, and all three are deterministic because they were pushed into MCP tools (`resolve_write_set`, `verify_write_coverage`, `expand_record_csv`).

Triage finds that **\~60% of that prose describes work whose output is fully determined by its inputs** — set arithmetic, topological ordering, schema validation, string formatting, file scaffolding. That work belongs in Python, where it can be tested.

This proposal converts that 60% into a `dg` CLI that the agent calls, reduces the prose to the \~19% that genuinely needs a model, and deletes the \~21% that is redundant or exists purely to coerce compliance.

**The outcome is not "remove the LLM."** It is: *reproducible given a small set of recorded decisions, and mechanically verifiable everywhere else.*

---

## 2\. Why this is feasible — three pieces of evidence

### 2.1 The identical problem is already solved in this repository

`data-model-workflow`, a sibling skill on `prod/main`, performs structured-input → validated-plan → generated-SQL using **14 Python scripts and a ruff config**:

```
parse_model_sheet.py      build_creation_plan.py    gen_sql.py
parse_ref_sheet.py        build_ref_targets.py      oracle_sql_gen.py
sheet_parsing_common.py   ref_data_common.py        postgres_sql_gen.py
inspect_manifest.py       generate_descriptions.py  split_csv_batches.py
generate_ref_csv.py       generate_ref_sql.py       ruff.toml
```

Same team, same repository, same domain, same shape of problem. `data-gen` does it with zero scripts. This is a port to an established in-house pattern, not a research project.

Secondary precedent: the a11y family uses `query_rules.py` as the rule authority and `check_rule_refs.py` as a CI gate that fails the build on a dangling rule reference.

### 2.2 The family has already started doing this itself, twice

**Bulk mode already delegates row generation to a deterministic tool.** `exemplar-3-clone-scale-plan.md` instructs:

> ⚠️ **In bulk mode do NOT materialize thousands of raw rows.** Emit ONE compact **generation spec per table** that the `expand_record_csv` DG tool expands deterministically at execution. This is what stops the agent from hand-building CSV or inventing rows in-flight.

That is precisely the pattern this proposal generalizes: **the model emits a spec; code expands it.** It has already been applied to the one sub-problem where non-determinism was most visibly painful.

**And the authors have identified the next one.** `exemplar-2-footprint-discovery.md` contains:

> **Optional optimization (not required):** a future `get_record_footprint(root_uuid, root_pk, adjacency)` DG tool could perform this BFS in one deterministic call… Build it later only if agent-driven traversal proves unreliable or too token-heavy.

The instinct is correct and already present in the codebase. This proposal makes it the default rather than the exception.

### 2.3 4,194 lines of prose exist to shepherd about fourteen decisions

Reading for judgment content rather than page count, the entire family reduces to a small, enumerable set of points where a model must actually decide something. See §5. Everything else is arithmetic, I/O, or formatting.

---

## 3\. Scope — the whole family

| Group | File | Lines | Role |
| :---- | :---- | ----: | :---- |
| **Manual workflow** | `resources/data-generator/workflow/step-0-initialize.md` | 442 | Scaffold folder \+ artifacts |
|  | `workflow/step-1-workflow-analysis.md` | 572 | Write-graph \+ SAIL trace |
|  | `workflow/step-2-exemplar-discovery.md` | 345 | Query a real record \+ children |
|  | `workflow/step-3-data-architecture.md` | 369 | Field maps, ref data, insertion order |
|  | `workflow/step-4-data-payloads.md` | 370 | Build payload files |
|  | `workflow/step-4b-coverage-gate.md` | 234 | Hard coverage block |
|  | `workflow/step-5-validation.md` | 306 | Pre-execution validation |
| **Exemplar workflow** | `resources/data-generator/exemplar/exemplar-1-reference-intake.md` | 58 | Take user's reference record |
|  | `exemplar/exemplar-2-footprint-discovery.md` | 73 | FK-closed footprint BFS |
|  | `exemplar/exemplar-3-clone-scale-plan.md` | 106 | Clone, remap, scale |
|  | `exemplar/exemplar-4-validation.md` | 34 | Light validation |
| **Generation** | `skills/data-gen/references/create-records.md` | 314 | Execute live creates |
|  | `skills/data-gen-bulk/references/generate-sql.md` | 382 | Emit bulk INSERT SQL |
| **Manage** | `skills/data-gen-manage/references/explore-schema.md` | 126 | Read-only schema exploration |
|  | `references/query-validate.md` | 111 | Query \+ verify records |
|  | `references/rollback.md` | 116 | Session rollback |
| **ERD** | `skills/data-gen-erd/SKILL.md` | 236 | Lucidchart ERD via `erd-gen` |
|  | **Total procedural spec** | **4,194** |  |

**Explicitly out of scope** (these stay as prose and are correct as prose):

| File | Lines | Why it stays |
| :---- | ----: | :---- |
| `tools/tool-reference-data-generator.md` | 429 | MCP tool catalog — reference documentation, not procedure |
| `tools/tool-reference-atlas.md` | 194 | Same |
| `tools/README.md` | 20 | Index |
| `resources/data-generator/prompt.md` | 95 | Agent prompt \+ skill router |
| The four `SKILL.md` files | 171 | Routing and trigger phrases |

---

## 4\. Triage — three buckets

Classification rule applied to each section:

- **A — Codeable:** output is fully determined by its inputs. No interpretation of natural language or SAIL required.  
- **B — Judgment:** requires interpreting a user request, reading SAIL semantics, recognizing a pattern, or generating plausible content.  
- **C — Delete:** duplicates work another section already performs, or exists only to coerce compliance.

Line counts are approximate section boundaries, not exact measurements.

| File | Lines | A code | B judgment | C delete |
| :---- | ----: | ----: | ----: | ----: |
| `step-0-initialize` | 442 | 400 | 15 | 27 |
| `step-1-workflow-analysis` | 572 | 60 | 250 | 262 |
| `step-2-exemplar-discovery` | 345 | 230 | 60 | 55 |
| `step-3-data-architecture` | 369 | 200 | 40 | 129 |
| `step-4-data-payloads` | 370 | 180 | 90 | 100 |
| `step-4b-coverage-gate` | 234 | 200 | 10 | 24 |
| `step-5-validation` | 306 | 150 | 60 | 96 |
| `exemplar-1-reference-intake` | 58 | 20 | 30 | 8 |
| `exemplar-2-footprint-discovery` | 73 | 55 | 10 | 8 |
| `exemplar-3-clone-scale-plan` | 106 | 55 | 45 | 6 |
| `exemplar-4-validation` | 34 | 25 | 5 | 4 |
| `create-records` | 314 | 220 | 30 | 64 |
| `generate-sql` | 382 | 330 | 20 | 32 |
| `explore-schema` | 126 | 80 | 40 | 6 |
| `query-validate` | 111 | 70 | 35 | 6 |
| `rollback` | 116 | 85 | 25 | 6 |
| `data-gen-erd/SKILL` | 236 | 150 | 30 | 56 |
| **Total** | **4,194** | **2,510 (60%)** | **795 (19%)** | **889 (21%)** |

### 4.1 What lands in bucket A, concretely

| Pattern | Occurrences | Why it is code |
| :---- | :---- | :---- |
| `BLOCKING CHECK` blocks | 9 files | Identical precondition comparison against prior-step status |
| `EXECUTION TRACKER UPDATE` blocks | 9 files | Mechanical state transition |
| `COMPLETION CRITERIA` / `QUALITY CHECK` lists | 15 files | Most items are mechanically checkable assertions |
| Step 0 scaffolding | 1 file, 442 lines | Folder naming, 7 (or 5\) artifact templates, existence verification |
| Step 4b set arithmetic | 1 file | The file literally specifies `MISSING = required_tables − PAYLOAD TABLES` |
| Step 4 §4d coverage math | 1 file | `fields_in_payload / total_writable_fields × 100` vs a threshold |
| Step 5 §5b FK integrity | 1 file | Is the referenced alias declared by an earlier file in `file_sequence`? |
| Step 5 §5d ref-ID validation | 1 file | Set membership against queried reference data |
| Step 3 §3a–3e | 1 file | Five straight MCP fetches, no judgment |
| Step 2 §2d/2f, E2 | 2 files | Breadth-first walk over an FK adjacency graph |
| `generate-sql` §6b–6g | 1 file, 330 lines | Type formatting, string escaping, `LAST_INSERT_ID()` chaining, batching |
| `create-records` §6b/6e | 1 file | Dispatch by mechanism; build `verify_write_coverage` input from the Mechanism Map |
| All `create`\-then-`insert` file-writing choreography | 6 files | Vanishes entirely once code writes artifacts |

### 4.2 What lands in bucket C, and why deleting it is safe

**`step-1` sections 1a–1h (\~260 lines) duplicate `resolve_write_set`.** Section §1.0 already concedes the machine-computed set is authoritative:

> Use it as the **authoritative spine** of your analysis; manual tracing (1a–1h below) then becomes a thorough *cross-check*, not the primary source of truth.

…and Step 4b hard-blocks against the machine set only. The manual trace's genuinely unique contribution — form-created records and prerequisites that a write-node graph cannot express — is roughly 250 lines of the 572 and stays as bucket B. The rest is re-derivation.

**`step-3` §3f (\~130 lines) is human judgment producing what Step 4b computes.** It includes an anti-rationalization essay:

> **⚠️ INVALID EXCLUSION REASONS (these are NOT acceptable):**  
> 

> - "Auto-generated by the process model" — WE are the data generator…  
> - "Not essential for state representation" — if the workflow writes it, it IS part of the state

That essay exists because the model kept rationalizing exclusions. Code does not rationalize. Once `resolve_write_set` output is the required set, the essay has no addressee.

**`step-5` §5a (\~96 lines) is a third coverage implementation that conflicts with the other two.** See defect D-3 in Appendix A.

**The coercion apparatus (\~200 lines spread across all files)** — banners, `⚠️` markers, `COMMON FAILURES TO AVOID` tables — carries no load once the gates execute. Its present cost is real: by marking a formatting preference (`Do NOT use strReplace`) with the same severity as a destructive rule (`NEVER set PK fields`), it flattens the severity gradient and makes it impossible for the model to tell which rules are load-bearing.

---

## 5\. The decision points — what must remain a model call

This list is the specification for `decisions.json`. Each entry becomes a schema-validated artifact the agent writes and the CLI consumes.

| ID | Decision | Source | Output schema |
| :---- | :---- | :---- | :---- |
| `D1` | Parse the user's request | `step-0` §0a | `{app, entity, target_status, conditions[], volume, mode}` |
| `D2` | Choose entry points | `step-1` §1.0 | `string[]` |
| `D3` | **Choose the branch at each gateway** | `step-1` §1.0 | `{gateway_label: chosen_branch}` |
| `D4` | Resolve the initiator gating group from a `VISIBILITY` expression | `step-1` §1a-ii | `{groups: string[]} | {unresolved: true, reason}` |
| `D5` | Identify form-created records absent from the write graph | `step-1` §1b Part 2a | `[{table, source_form, why}]` |
| `D6` | Recognize exemplar value patterns | `step-2` §2c | `[{kind, assertion}]` — e.g. `weights sum to 100` |
| `D7` | Generate realistic field values | `step-4` §4a | `{table: {field: value}}` |
| `D8` | Explain deltas and nulls | `step-4` §4c, `step-5` §5c | `{table: {field: reason}}` |
| `D9` | Classify reference status proximity | `E1` | `{proximity: exact|near|far, deltas[]}` |
| `D10` | Choose uniqueness mutation strategy per field | `E3` rule 4 | `{table: {field: generator_spec}}` |
| `D11` | Map requested scale to child-group fan-out | `E3` rule 6 | `{alias: children_per_parent}` |
| `D12` | Select a document by description match | `step-4` §4a, `E3` rule 3 | `{field: {documentId, name, why}}` |
| `D13` | Choose a generator per field for bulk specs | `E3` bulk | `{field: const|seq|cycle|pick|int|date|str|row_index}` |
| `D14` | Route a manage request to a mode | `data-gen-manage` | `explore | query | rollback` |

**`D3` is the load-bearing decision.** Once gateway branches are chosen, `resolve_write_set` makes the required table set deterministic and FK-closed, and everything from Step 4b onward is arithmetic.

Two things worth noting:

- **`D15` disappears.** ERD domain assignment is currently a decision only because the GSS taxonomy is hardcoded in `data-gen-erd/SKILL.md`. Moving it to config converts a judgment call into a lookup.  
- **Choosing the reference record is *not* on this list.** `E1` correctly requires the user to supply it: "The reference was **provided by the user** (explicitly asked for and received) — NOT auto-searched or picked by the agent."

Each decision becomes an individually testable, replayable, cacheable artifact. That is the difference between *reproducible given fourteen recorded decisions* and today's *reproducible if the model reads 4,194 lines the same way twice*.

---

## 6\. Architecture

### 6.1 The hard constraint

**Python scripts cannot call MCP tools.** MCP is agent-side transport. A script has no path to `resolve_write_set` or `query_records` without re-implementing authentication against Appian and the Atlas KB — which would duplicate two MCP servers and introduce a second credential surface.

This constraint dictates the whole design:

> **The agent performs all I/O. The CLI is a set of pure functions over on-disk artifacts.**

The agent calls an MCP tool, writes the response verbatim to `raw/`, and invokes a `dg` subcommand that reads `raw/` and produces the next artifact. No script ever touches a network.

Two valuable consequences:

1. **Offline replay.** `raw/` makes any run reproducible with no environment and no credentials — which is what makes golden-file testing possible.  
2. **Trivial unit tests.** Every subcommand is `f(json) → json`. This is what makes the port safe to do incrementally.

### 6.2 Directory layout

```
data-requests/{YYYY-MM-DD}_{slug}[-{NN}]/     # -NN suffix on same-day collision
├── state.json              # written by dg, read by `dg gate`. Single source of workflow state.
├── decisions.json          # the model's answers to D1–D14, schema-validated
├── raw/                    # verbatim MCP responses — never hand-edited
│   ├── record_type_map.json
│   ├── field_map.json
│   ├── insertion_order.json
│   ├── write_graph.json         # get_entry_point_write_graph
│   ├── write_set.json           # resolve_write_set
│   ├── schema_relationships.json
│   ├── reference_data.json
│   ├── users.json
│   ├── documents.json
│   ├── record_properties/{uuid}.json
│   └── exemplar/{table}.json
├── payloads/
│   ├── 00-metadata.json
│   ├── 01-{table}.json          # single mode: literal records
│   └── 01-{table}.spec.json     # bulk mode: generation spec
├── reports/
│   ├── analysis.md
│   ├── exemplar.md              # manual mode
│   ├── reference.md             # exemplar mode
│   ├── footprint.md             # exemplar mode
│   ├── data-architecture.md
│   ├── coverage-gate.md
│   ├── validation-report.md
│   └── execution-log.md
└── out/
    └── bulk-data.sql            # bulk mode only
```

Reports move under `reports/` so that human-readable output is cleanly separated from machine-consumed artifacts. Nothing downstream should ever parse a markdown report.

### 6.3 The `dg` CLI surface

One entry point, subcommands mirroring the workflow. Every subcommand: reads artifacts, writes artifacts, exits `0` on pass and non-zero with a machine-readable reason on fail.

```
dg init          --request-json decisions.json#D1 --mode manual|exemplar --seed N
dg state         get|set --step <id> --status <enum>
dg gate          --require <step-id>[,<step-id>...] --then <step-id>
dg plan-writes   # raw/write_graph.json + D2 + D3 -> resolve_write_set call args
dg record-writes # raw/write_set.json -> state.json required set + reports/analysis.md
dg plan-footprint  # raw/{record_type_map,schema_relationships}.json -> BFS query plan for the agent
dg build-footprint # raw/exemplar/*.json -> reports/footprint.md + edge map
dg build-arch    # raw/{field_map,insertion_order,reference_data,users}.json -> reports/data-architecture.md
dg build-payloads  --from-decisions D7,D8,D10,D11,D12,D13   # -> payloads/
dg check-fields  # raw/record_properties/*.json x payloads/ -> coverage %, threshold enforcement
dg coverage-gate # raw/write_set.json x payloads/ -> reports/coverage-gate.md + mechanism map
dg validate      # JSON Schema + FK topology + ref-ID membership -> reports/validation-report.md
dg exec-plan     # payloads/ + mechanism map -> ordered call list for the agent to execute
dg exec-record   --step N --response-json <file>   # record one MCP response, resolve aliases
dg verify-input  # mechanism map + captured PKs -> verify_write_coverage args
dg gen-sql       # payloads/ + raw/field_map.json -> out/bulk-data.sql
dg report        --kind execution|session
dg erd-input     # raw/{app_schema,schema_relationships}.json + config/domains.json -> <app>-erd.json
```

**Division of labour, illustrated for the coverage gate:**

| Actor | Action |
| :---- | :---- |
| Agent | `dg plan-writes` → prints the exact `resolve_write_set(...)` arguments |
| Agent | Calls `resolve_write_set` via MCP; writes response to `raw/write_set.json` |
| CLI | `dg coverage-gate` → set arithmetic, writes `reports/coverage-gate.md`, sets `state.json`, exits 0/1 |
| Agent | On exit 1, reads the printed `missing[]` and returns to payload construction |

The agent never computes the diff. The CLI never makes a network call.

---

## 7\. Contracts to freeze before any code is written

These five contracts are the actual deliverable of Phase 0\. Every defect in Appendix A is a symptom of one of them being undefined.

### 7.1 Payload contract — one shape, no monolith

Today `payloads.json` (monolithic) and `payloads/` (split) are both mandated across four files. See defect D-1. Resolution: **`payloads/` only.** Delete every reference to a monolithic `payloads.json`, including the trailing example block in `step-4` §4e and the two `CRITICAL RULES` lines in `step-4` and `create-records` that name it as the source of truth.

`payloads/00-metadata.json`:

```
{
  "schema": 1,
  "status": "PASS",
  "application": "SourceSelection",
  "mode": "manual",                    // manual | exemplar
  "volume_mode": "single",             // single | bulk
  "seed": 20260729,
  "date_anchor": "2026-07-29",
  "fk_placeholder_convention": "at-alias-v1",
  "file_sequence": ["01-evaluation.json", "02-vendor.json"],
  "total_records": 18,
  "field_completeness": {
    "AS_GSS_EVALUATION": { "writable": 20, "populated": 18, "coverage_pct": 90 }
  }
}
```

`payloads/NN-{table}.json` (single mode):

```
{
  "table": "AS_GSS_EVALUATION",
  "mechanism": "RECORD",               // RECORD | CDT
  "record_type_uuid": "e6bc8561-...",  // RECORD only
  "constant_name": null,               // CDT only
  "cdt_type": null,                    // CDT only
  "alias": "evaluation",               // declares this table's output alias
  "records": [
    {
      "description": "Root evaluation record",
      "output_ref": "evaluation",
      "fields": { "evaluationTitle": "HD260519Q0001", "evaluationStatusId": 3 },
      "field_reasoning": { "evaluationTitle": "…", "evaluationStatusId": "…" }
    }
  ]
}
```

`payloads/NN-{table}.spec.json` (bulk mode) keeps the shape already specified in `E3`, which is sound as written.

### 7.2 FK placeholder grammar — one notation

The family currently uses **six** notations for one concept (defect D-2). Freeze one and reject the rest at `dg validate`:

```
fk_ref     ::= "@" alias ( "[" index "]" )? ( "." field )?
alias      ::= [a-z][a-z0-9_]*
index      ::= [0-9]+ | "$i"          # $i = current row index during fan-out
```

Rules:

- `alias` MUST match an `output_ref` declared in a payload file appearing **earlier** in `file_sequence`.  
- Omitted `.field` resolves to the target's primary key.  
- Bulk specs continue to use `fk_binding` for the primary parent and `{"gen":"cycle"|"pick","from_alias":"<alias>"}` for secondary FKs — these are *bindings*, not placeholders, and are a distinct concept. Say so explicitly in the contract so the two are never conflated.  
- `dg validate` fails on `__FK_FROM_STEP_N__`, `$alias`, or any free-text placeholder.

### 7.3 Status enum — four values, everywhere

Today: `⏳ PENDING`, `✅ COMPLETE`, `✅ COMPLETED`, `🔄 IN PROGRESS`, `❌ NOT STARTED`, `✅ PASS`, `❌ BLOCKED`, `❌ FAIL`, `✅ ALL CHECKS PASS`, `⛔ UNAVAILABLE`. `step-4`'s blocking check greps for `COMPLETE` while the tracker writes `COMPLETED` (defect D-5).

Freeze: **`PENDING | IN_PROGRESS | PASS | BLOCKED`**. Nothing else. Reports may render emoji for humans; `state.json` never contains one.

### 7.4 `state.json`

```
{
  "schema": 1,
  "mode": "manual",
  "volume_mode": "single",
  "application": "SourceSelection",
  "seed": 20260729,
  "date_anchor": "2026-07-29",
  "gate_mode": "resolve_write_set",   // resolve_write_set | degraded_manual
  "steps": {
    "0":  { "status": "PASS", "artifacts": ["reports/analysis.md", "..."] },
    "1":  { "status": "PASS", "entry_points": ["AS_GSS_Award_Vendor"],
            "branch_decisions": { "Approved?": "yes" } },
    "4b": { "status": "PASS", "required": 12, "covered": 12,
            "missing": [], "excluded": [{"table": "AS_GSS_REJECTION", "cite": "Approved?=yes"}] }
  }
}
```

`gate_mode` is the fix for defect D-4: a run that fell back to manual judgment because the KB was stale must be distinguishable forever, and must never render as an unqualified `PASS`.

### 7.5 `config/thresholds.json`

Extracts the magic numbers currently hardcoded across the prose:

```
{
  "min_field_coverage_pct": 80,
  "coverage_rounding": "floor",        // resolves the 5/8 = 62 vs 62.5 ambiguity
  "max_records_per_payload_file": 6,
  "live_record_limit": 50,             // the data-gen / data-gen-bulk routing boundary
  "bulk_min_rows": 100
}
```

`live_record_limit` also fixes defect D-6: the \~50 boundary is asserted in four places and enforced nowhere.

---

## 8\. Implementation plan — Option 4, agent-driven

Phases are **dependency-ordered**. Each has a **Done when** clause expressed as a test or a command whose output can be checked. No time or size estimates: exit criteria are more useful than sizing, because they make each phase independently verifiable and independently mergeable.

Target location, matching `data-model-workflow`:

```
.kiro/skills/data-gen/
├── scripts/
│   ├── dg.py                 # CLI entry point, subcommand dispatch
│   ├── state.py              # state.json read/write, status enum
│   ├── gate.py               # precondition evaluation
│   ├── scaffold.py           # Phase 2
│   ├── coverage.py           # Phase 3
│   ├── validate.py           # Phase 4
│   ├── sql_emit.py           # Phase 5
│   ├── footprint.py          # Phase 6
│   ├── fields.py             # Phase 7
│   ├── erd_input.py          # Phase 9
│   ├── artifacts.py          # shared: path resolution, atomic writes, report rendering
│   ├── schemas/              # JSON Schema — the frozen contracts from §7
│   │   ├── state.schema.json
│   │   ├── decisions.schema.json
│   │   ├── payload-metadata.schema.json
│   │   ├── payload-file.schema.json
│   │   └── payload-spec.schema.json
│   ├── config/
│   │   └── thresholds.json
│   └── ruff.toml
└── tests/
    ├── fixtures/             # captured raw/ trees for golden-file replay
    └── test_*.py
```

---

### Phase 0 — Freeze the contracts (no executable code)

**Do:**

1. Write the five JSON Schemas in §7 into `scripts/schemas/`.  
2. Capture one real end-to-end run's MCP responses into `tests/fixtures/sourceselection-manual/raw/`. This is the single most valuable artifact of the whole project — every later phase tests against it.  
3. Capture a second fixture for exemplar mode and a third for bulk mode.  
4. Write `tests/fixtures/README.md` documenting how to capture a new fixture.  
5. Resolve every defect in Appendix A **on paper**, recording the decision inline in the schema descriptions.

**Do not:** write any logic yet. Getting the contracts wrong is the only failure mode that forces a rewrite.

**Done when:**

```shell
python3 -m jsonschema -i tests/fixtures/sourceselection-manual/payloads/00-metadata.json \
  scripts/schemas/payload-metadata.schema.json
# and the same for every artifact in all three fixtures
```

All three fixture trees validate against the frozen schemas, and Appendix A has a recorded resolution for every row.

---

### Phase 1 — State and gate

**Depends on:** Phase 0

**Do:**

1. `state.py` — read/write `state.json`, enforce the four-value enum, atomic writes (temp file \+ rename) so a crashed run never leaves a half-written state.  
2. `gate.py` — evaluate preconditions. Replaces all 9 `BLOCKING CHECK` blocks.  
3. `dg state` and `dg gate` subcommands.  
4. Encode the precondition graph **as data**, not as code branches, so it stays inspectable:

```py
PRECONDITIONS = {
    "1":  ["0"], "2": ["1"], "3": ["2"], "4": ["3"],
    "4b": ["4"], "5": ["4b"], "gen": ["5"],
    "E1": ["0"], "E2": ["E1"], "E3": ["E2"], "E4": ["E3"],
}
```

**Retires:** all `BLOCKING CHECK` blocks (9 files) and all `EXECUTION TRACKER UPDATE` blocks (9 files).

**Done when:**

```shell
dg gate --require 4b --then 5     # exit 1, prints: "4b is PENDING; required PASS"
dg state set --step 4b --status PASS
dg gate --require 4b --then 5     # exit 0
python3 -m pytest tests/test_gate.py -v
```

Tests cover: missing step, wrong status, out-of-order transition, both mode graphs, and a corrupted `state.json` failing loudly rather than defaulting to permissive.

---

### Phase 2 — Scaffold (replaces `step-0` and exemplar init)

**Depends on:** Phase 1

**Do:**

1. `scaffold.py` — create the folder, all artifacts, `state.json`, and `decisions.json` from `D1`.  
2. Resolve the mode-dependent artifact set (7 files manual / 5 files exemplar) from **one list in code**, eliminating defect D-7 (the 6-vs-7 contradiction) structurally.  
3. Same-day collision handling: append `-02`, `-03` on an existing slug.  
4. Anchor the folder to the repository root, not `os.getcwd()` — `step-0` §0b currently says "Create the folder in the current working directory", which is undefined for an agent session.  
5. Record `seed` and `date_anchor` at init. Defaults: `seed` \= `YYYYMMDD`, `date_anchor` \= today. Both overridable via flag.

**Retires:** `step-0-initialize.md`, 442 lines → roughly 40 lines of prose describing `D1` and how to invoke `dg init`.

**Done when:**

```shell
dg init --request-json d1.json --mode manual --seed 20260729
diff -r data-requests/2026-07-29_eval-complete/ tests/fixtures/expected-scaffold-manual/
# no differences

dg init --request-json d1.json --mode exemplar --seed 20260729
# produces exactly 5 artifacts; asserts analysis.md / coverage-gate.md absent
python3 -m pytest tests/test_scaffold.py -v
```

Two consecutive `dg init` calls with the same slug produce `…_eval-complete` and `…_eval-complete-02`.

---

### Phase 3 — Coverage gate (replaces `step-4b`, fixes the three-way conflict)

**Depends on:** Phase 2\. **Highest-value phase** — most code-ready file, and where current defects actually break runs.

**Do:**

1. `coverage.py`:  
   - `required_set(raw/write_set.json) -> {table: {classification, mechanism, reason}}`  
   - `payload_set(payloads/) -> {table}`  
   - `diff() -> {missing, extra, covered}`  
   - `mechanism_map() -> {table: RECORD|CDT}` — emitted as **JSON in `state.json`**, not only as a markdown table, so `create-records` and `verify_write_coverage` consume structured data  
   - `render_report() -> reports/coverage-gate.md`  
2. **Make Step 5's coverage check consume this output rather than recompute it** (defect D-3). `dg validate` reconciles against `state.json.steps["4b"]`; it must not call `get_app_schema` and must not apply a second exclusion taxonomy.  
3. **Refuse to silently degrade** (defect D-4). On empty `required_tables`:

```py
if not required and write_graph_empty:
    state.set("4b", "BLOCKED", gate_mode="kb_stale")
    die("KB write graph is empty — likely a stale parse. "
        "Re-parse the KB, or re-run with --allow-degraded to proceed using the "
        "manual Table Inventory. A degraded run is never reported as PASS.")
```

4. `dg verify-input` builds `verify_write_coverage` arguments from the mechanism map, using `record_type_uuid` for RECORD and `constant_name` for CDT — the mismatch `create-records` §6e warns about becomes impossible.

**Retires:** `step-4b-coverage-gate.md` 234 → \~30 lines; `step-5` §5a (\~96 lines) entirely; `create-records` §6e hand-construction.

**Done when:**

```shell
python3 -m pytest tests/test_coverage.py -v
```

covering, at minimum:

| Test | Expected |
| :---- | :---- |
| all required tables present | `PASS`, exit 0 |
| one required table missing | `BLOCKED`, exit 1, missing table named in stdout |
| missing table with a cited branch exclusion | `PASS`, exclusion recorded with citation |
| missing table with an uncited exclusion | `BLOCKED` |
| extra table in payloads | `PASS` with a note — never a failure |
| empty `required_tables` \+ empty write graph | `BLOCKED`, `gate_mode=kb_stale`, non-zero exit |
| same input, `--allow-degraded` | proceeds, `gate_mode=degraded_manual`, report never says `PASS` unqualified |
| CDT table present | mechanism map emits `constant_name`, not `record_type_uuid` |

Plus a golden-file replay: `dg coverage-gate` against the Phase 0 fixture reproduces the committed `coverage-gate.md` byte for byte.

---

### Phase 4 — Payload validation (replaces `step-5` mechanical half and `E4`)

**Depends on:** Phase 3

**Do:**

1. `validate.py`:  
   - **Schema** — every payload file against `payload-file.schema.json`. Replaces `step-4` §4e's "read the file; if it reads successfully the JSON is valid," which is a no-op that always reports success (defect D-8).  
   - **FK topology** — every `@alias` resolves to an `output_ref` declared earlier in `file_sequence`; detect cycles.  
   - **Ref-ID membership** — every reference FK value exists in `raw/reference_data.json`.  
   - **User membership** — every user value exists in `raw/users.json`; the initiator is a member of a `D4` group when `D4` resolved.  
   - **Document validity** — every `documentId` exists in `raw/documents.json`.  
   - **Forbidden fields** — no PK, no `isCustomRecordField=true`.  
   - **Date coherence** — offsets from `date_anchor` satisfy the ordering asserted in `D6`.  
2. `dg validate` writes `reports/validation-report.md` and sets `state.json`.

**Retires:** `step-5-validation.md` 306 → \~60 lines (the `D8` delta-explanation prose only); `exemplar-4-validation.md` becomes a `dg validate --mode exemplar` invocation.

**Done when:** `pytest tests/test_validate.py -v` covers each check's pass and fail path, including a deliberately malformed JSON file that now fails (proving the no-op is gone) and a forward-referencing `@alias` that is rejected.

---

### Phase 5 — SQL emitter (replaces `generate-sql`)

**Depends on:** Phase 4\. **Independently valuable** — isolated, no MCP interaction beyond `raw/field_map.json`, and 330 of its 382 lines are bucket A.

**Do:**

1. `sql_emit.py`: camelCase → UPPER\_SNAKE via `raw/field_map.json`; type formatting; string escaping; `LAST_INSERT_ID()` / `@variable` FK chaining in insertion order; batching per `config/thresholds.json`.  
2. Emit a header comment recording `seed`, `date_anchor`, and the source request, so a `.sql` file is traceable to the run that produced it.  
3. `dg gen-sql` → `out/bulk-data.sql`.

**Done when:**

```shell
dg gen-sql   # against the bulk fixture
diff out/bulk-data.sql tests/fixtures/expected-bulk-data.sql   # byte-identical
python3 -m pytest tests/test_sql_emit.py -v
```

Tests cover: string escaping (embedded quotes, backslashes, newlines), NULL vs empty string, date and datetime formatting, multi-level FK chaining, batch splitting at the boundary, and — the property that matters most — **two runs with the same seed produce byte-identical SQL.**

---

### Phase 6 — Exemplar footprint (replaces `E2` and `E3` mechanics)

**Depends on:** Phase 4

**Do:**

1. `dg plan-footprint` — from `raw/record_type_map.json` \+ `raw/schema_relationships.json`, emit the **complete BFS query plan**: every table with an FK pointing at the root or a descendant, each annotated with its real FK column and the parent PKs to filter by. This is the `get_record_footprint` tool `E2` speculates about, implemented agent-side instead of server-side, and it eliminates the failure mode `E2` devotes a whole `🛑` section to:  
     
   > **Filtering such a table by the root id returns empty OR a 500 — that is NOT evidence the table is empty.**  
     
   Code derives the correct FK column from the graph, so the wrong-FK guess cannot occur.  
     
2. `dg build-footprint` — from `raw/exemplar/*.json`, assemble `reports/footprint.md`, the edge map, per-table row counts, and the reference-FK values to preserve.  
     
3. Clone mechanics from `E3` rules 1–3 and 6 (strip PKs, remap internal FKs to `@alias`, preserve reference FKs verbatim, fan out by `children_per_parent`) move into code. Rules 4 and 5 stay as decisions `D10` and `D11`.  
     
4. Cycle detection via a visited set — `E2` asks for this in prose ("Track visited tables to avoid cycles").

**Retires:** `E2` 73 → \~15 lines; `E3` 106 → \~45 lines (`D10`, `D11`, `D13` only).

**Done when:** `pytest tests/test_footprint.py -v` covers a diamond FK graph, a grandchild linking by its parent's PK rather than the root's, a self-referencing table, a cycle, and a table whose real FK differs from the root id — asserting the plan names the correct column in every case.

---

### Phase 7 — Field coverage enforcement (replaces `step-4` §4d)

**Depends on:** Phase 4

**Do:**

1. `fields.py` — writable-field count from `raw/record_properties/{uuid}.json` (excluding PK and `isCustomRecordField=true`), coverage percentage using `coverage_rounding` from config, threshold enforcement.  
2. Require a `field_reasoning` entry for every populated field and for every deliberate null. Missing reasoning is a hard fail — which is what `step-4`'s "⚠️ Every field MUST have an entry in field\_reasoning. No exceptions." has been asking for without any means of enforcement.  
3. `dg check-fields`.

**Done when:** `pytest tests/test_fields.py -v` covers a table exactly at the threshold, one just below, a table whose only shortfall is documented nulls, and a missing-reasoning failure. The 5/8 \= 62 vs 62.5 case is asserted explicitly against the configured rounding mode.

---

### Phase 8 — Decisions contract and prose rewrite

**Depends on:** Phases 2–7

**Do:**

1. Finalize `decisions.schema.json` for `D1`–`D14`.  
2. `dg` validates `decisions.json` on every read; an out-of-schema decision fails before any work happens.  
3. **Rewrite the prose.** Each remaining step file collapses to four parts:  
   - which decisions it produces  
   - which `dg` subcommand to invoke, with arguments  
   - what to do on non-zero exit  
   - the judgment guidance that only a model can act on  
4. Delete: the manual trace duplication in `step-1` 1a–1h except the form-analysis and prerequisite sections; `step-3` §3f and its anti-rationalization essay; every `create`\-then-`insert` choreography block; every `COMMON FAILURES TO AVOID` table whose rows are now enforced by a test.  
5. Reduce the emphasis apparatus. Reserve `⚠️` for genuinely destructive operations — writes to a live environment and `rollback_session`.

**Done when:** total procedural prose is under 1,700 lines (from 4,194); every `dg` subcommand is referenced by exactly one step file; and `grep -c '⚠️'` across the family is under 15\.

---

### Phase 9 — Manage actions and ERD

**Depends on:** Phase 8\. Independent of the generation pipeline; can proceed in parallel with Phase 8\.

**Do:**

1. **ERD:** extract the hardcoded GSS domain patterns and color map from `data-gen-erd/SKILL.md` into `config/domains.example.json` (committed, GSS mapping as the worked example) plus a gitignored `config/domains.json`. `dg erd-input` builds the `<app>-erd.json` from `raw/` plus config. Unmatched tables fall back to a single `Other` domain.  
2. **Manage:** `dg` subcommands for the mechanical parts of `explore-schema` (schema rendering), `query-validate` (filter construction, result formatting), and `rollback` (session preview rendering, reverse-order plan). `D14` routing stays with the model.  
3. Split `data-gen-erd/SKILL.md` into a short `SKILL.md` plus `references/`, matching the structure of its three sibling skills.

**Done when:** `dg erd-input` against the fixture reproduces a committed `<app>-erd.json`; a second fixture from a **non-GSS** application places tables in real domains rather than all in `Other`, proving the hardcoding is gone.

---

### Phase 10 — CI

**Depends on:** Phase 1 onward; wire incrementally as phases land.

**Do:**

1. Add a job to `.gitlab-ci.yml` running `pytest` and `ruff` over `scripts/`.  
2. Add a schema-lint job validating every committed fixture against the schemas — catches contract drift.  
3. Add a reference-integrity job in the spirit of a11y's `check_rule_refs.py`: fail the build if a step file names a `dg` subcommand that does not exist, or if a subcommand exists that no step file invokes.

**Done when:** an MR that renames a subcommand without updating the prose fails CI.

---

## 9\. Options considered and rejected

| \# | Option | Determinism gained | Why not |
| :---- | :---- | :---- | :---- |
| 1 | Fix the contradictions only; leave prose-driven | None | Insufficient. Leaves three conflicting coverage implementations and the payload ambiguity — correctness bugs, not style. |
| 2 | Gates only — `state.json` \+ `gate.py`, prose still drives | Low–medium | A reasonable first increment, and it is exactly Phase 1\. Not sufficient as an endpoint: the bugs live in the computation, not the sequencing. |
| 3 | Checks \+ scaffolding — code owns the mechanical steps, prose keeps the rest | High | Effectively Phases 0–4 and 7\. A legitimate stopping point if Phases 5, 6, and 9 are deferred. |
| 4 | **Full pipeline, agent-driven** — chosen | Very high | Every mechanical step is code; the model contributes fourteen schema-validated decisions. |
| 4b | Full pipeline, **CLI-driven** — the CLI owns the loop and calls a model API at each decision point | Very high, plus fully replayable decisions | Rejected for now. Needs its own model credentials, diverges from the skills architecture, and turns a skill into a standalone product. The `decisions.json` contract keeps this reachable later without rework. |
| 5 | Push the logic server-side into the Atlas / DG MCP servers | Very high | The right long-term home for anything needing KB access — `resolve_write_set`, `verify_write_coverage`, and `expand_record_csv` prove the Atlas team will host deterministic logic. But it is a cross-team dependency and cannot be the first move. `dg` subcommands are deliberately designed as pure functions so any one of them can migrate into an MCP tool later without changing its contract. |

---

## 10\. What stays irreducible

Full determinism is not achievable here, and pursuing it would be a mistake. Three areas remain genuinely model-dependent:

**Form-created records (`D5`).** Recognizing that a repeating grid on an action's form produces N rows requires reading SAIL and understanding intent. No parser does this reliably. `step-1` §1.0 already states the limit correctly: *"The deterministic set is the floor, not the ceiling."* The write graph provably cannot express form-created rows.

**Field value generation (`D7`, `D10`).** Generating a plausible contract-style identifier that matches an exemplar's pattern is generative by definition. Determinism here means **seeded and recorded** — same `seed` plus same `date_anchor` yields byte-identical payloads — not eliminating the model. This also replaces the current explicit non-reproducibility in `step-4` §4a ("pick **randomly** across the returned union") and resolves its self-contradiction with the worked example three sections later, which documents the same field as "first available".

**Semantic document matching (`D12`).** Choosing a document by reading candidate descriptions is a semantic judgment. Code can validate that the chosen `documentId` exists; it cannot choose.

**Stale KB.** Code can detect an empty write graph and refuse to proceed. It cannot repair the KB. Today the workflow silently substitutes human judgment and still reports `✅ PASS`; after Phase 3 it will refuse, or proceed only under an explicit `--allow-degraded` flag that taints the report permanently.

**Honest target:** *reproducible given fourteen recorded decisions, mechanically verifiable everywhere else.*

---

## 11\. Risks

| Risk | Mitigation |
| :---- | :---- |
| Contracts frozen wrong in Phase 0 force a rewrite | Phase 0 ships no logic. Validate all three fixtures against the schemas before writing any code. |
| Fixtures drift from real MCP responses | Schema-lint job in Phase 10; document the capture procedure in `tests/fixtures/README.md`; re-capture whenever an MCP server version bumps. |
| Agent bypasses the CLI and does the work in-context anyway | `dg gate` is the only path that sets `PASS`. A step whose artifact exists but whose state was never set by `dg` does not open the next gate. |
| Partial adoption leaves two implementations of one check | Phase ordering makes each phase delete the prose it replaces in the same MR. Never leave both live. |
| Scripts cannot call MCP, so the agent must faithfully persist responses to `raw/` | `dg` validates `raw/` shape on read and fails with the exact expected schema. A truncated or hand-edited response is caught immediately. |
| MCP tool signatures change | `raw/` isolates the blast radius to the adapter layer; core logic reads normalized artifacts. |
| Reviewer fatigue on a large change | Ten independently mergeable phases, each with its own test suite and its own prose deletion. |

---

## Appendix A — Defect inventory found during triage

Each of these must have a recorded resolution before Phase 1 begins. All were found by reading the files, not by running the workflow.

| ID | Defect | Evidence | Resolved by |
| :---- | :---- | :---- | :---- |
| **D-1** | Two payload contracts mandated simultaneously | `step-4` §4e says "Do NOT write one giant payloads.json", then its `CRITICAL RULES` says "**payloads.json IS THE SOURCE OF TRUTH**", and its `COMPLETION CRITERIA` requires `payloads.json` status change. `step-5` blocking check requires `payloads.json` then immediately notes payloads are split. `create-records` repeats both. | §7.1, Phase 0 |
| **D-2** | Six FK placeholder notations for one concept | `__FK_FROM_STEP_N__` (×3), `@alias` (×2), `@alias.fieldName`, `"@evaluation_id"`, `$alias` (×5), `$alias[index]`, plus `from_alias` (×4) and `output_ref` (×3) as distinct concepts | §7.2, Phase 0 |
| **D-3** | Three coverage checks with conflicting authorities; two can deadlock | `step-4b` uses `resolve_write_set` and allows *"branch not taken"* exclusions. `step-5` §5a recomputes from `get_app_schema` and permits **only** `REFERENCE`/`AUDIT`/`NOT API-WRITABLE`, declaring anything else `❌ MISSING → FAIL`. A table legitimately excluded at 4b is a mandatory FAIL at 5a with no resolution path. `create-records` §6e adds a third (post-execution) check. | Phase 3 |
| **D-4** | The one deterministic gate silently degrades to human judgment and still reports PASS | `step-4b` §4b.1 and `step-1` §1.0: on a stale KB, "fall back to the Step 1 manual Table Inventory as the required set" | §7.4 `gate_mode`, Phase 3 |
| **D-5** | Ten status vocabularies; `step-4` greps `COMPLETE` while the tracker writes `COMPLETED` | Across all 9 procedural files | §7.3, Phase 1 |
| **D-6** | The \~50-record routing boundary is asserted four times, enforced zero times | `README.md`, `data-gen/SKILL.md`, `data-gen-bulk/SKILL.md`, `prompt.md` | §7.5, Phase 2 |
| **D-7** | `step-0` says both 6 and 7 files | Header: "CREATE ALL 7 FILES"; §0d: "exactly 7 items"; but §0c heading "Create All 6 Files", "**All 6 files. No exceptions.**", "until all 6 files exist", tracker "all 6 files" | Phase 2 (one list in code) |
| **D-8** | The only mechanical check in `step-4` cannot fail | §4e: "read each file using the file read tool — if it reads successfully, the JSON is valid". A read returns text regardless of parseability. | Phase 4 |
| **D-9** | `4b` names two different things | `step-4` has internal sections `4a`–`4e`, so `4b` \= "Structure Each Payload"; `step-4b-coverage-gate.md` is also `4b` | Phase 8 (renumber `4.1`–`4.5`) |
| **D-10** | Value selection is explicitly non-reproducible, and self-contradictory | `step-4` §4a: "pick **randomly** across the returned union"; §4c worked example: "from list\_users(), first available" | §7.4 `seed`, Phase 7 |
| **D-11** | Dates are hardcoded literals with no anchor | `step-3` §3j Date Sequencing Plan and `step-4` §4c examples use fixed 2026 dates; generated data drifts relative to run date | §7.4 `date_anchor`, Phase 7 |
| **D-12** | Undefined external references | `E1`–`E3` cite decision IDs `D9`, `D15`, `D16`, `D17`, `D18` with no decision log anywhere in the MR | Phase 0 (locate or inline) |
| **D-13** | Tool choreography embedded in domain workflow | Six files mandate `create`\-then-`insert` and forbid `strReplace` — brittle coupling to a tool API, unrelated to output correctness | Phase 8 (code writes artifacts) |
| **D-14** | Coverage percentage has no rounding rule | `step-4` §4d shows 5/8 as "62%" (truncated from 62.5); behavior at the 80% boundary is undefined | §7.5, Phase 7 |
| **D-15** | Interactive-only inputs in an agent-driven flow | `step-0` §0b anchors the folder to "the current working directory", undefined for an agent session | Phase 2 |

---

## Appendix B — Worked example: one step, before and after

**Before** — `step-4b-coverage-gate.md`, 234 lines, of which \~200 describe set arithmetic in prose, wrapped in a `🛑 STOP!` banner, six `⚠️ MANDATORY COMPLIANCE` rules, a blocking-check block, a six-item quality checklist, a tracker update block, and a six-row `COMMON FAILURES TO AVOID` table.

**After** — roughly 30 lines:

```
# Step 4b: Coverage Gate

Deterministic. The required table set comes from `resolve_write_set`, never from judgment.

## 1. Get the resolve_write_set arguments

    dg plan-writes

Call `resolve_write_set` with the printed arguments. Save the response verbatim:

    raw/write_set.json

## 2. Run the gate

    dg coverage-gate

- **Exit 0** — `reports/coverage-gate.md` is written, the mechanism map is recorded in
  `state.json`, step 4b is `PASS`. Continue to Step 5.
- **Exit 1** — the command prints the missing tables. Return to Step 4, add a payload
  for each, and re-run. Do not edit `raw/write_set.json`.
- **Exit 2** — the KB write graph is empty (stale parse). Tell the user the KB needs a
  re-parse. Only proceed with `--allow-degraded` if the user explicitly agrees; the run
  will be permanently marked degraded.

## 3. Excluding a table

Only tables listed in `write_set.json`'s `excluded_tables`, or carrying a cited
`branch_decision`, may be excluded. Record the citation:

    dg coverage-gate --exclude AS_GSS_REJECTION --cite "Approved?=yes"

An uncited exclusion is rejected.
```

The eight behaviors the 234 lines were trying to guarantee now live in `tests/test_coverage.py`, where they either pass or fail.  
