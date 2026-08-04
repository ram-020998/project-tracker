# Deterministic Implementation — Data-Gen Prose → Code

**What this is:** the implementation program for converting the Appian **data-generation skill family**
(`.kiro/skills/data-gen*` + `.kiro/resources/data-generator/`) from **4,194 lines of markdown imperatives**
into a tested, deterministic **`dg` Python CLI** that an agent orchestrates — reducing the prose to the
~19% that genuinely needs a model and deleting the ~21% that is redundant or exists only to coerce compliance.

**Source of truth:** [`proposal-source.md`](./proposal-source.md) (author: walid.elsayed, 2026-07-29,
"Option 4 — full pipeline, agent-driven"). This folder operationalizes that proposal into an executable,
phase-by-phase plan with a progress tracker.

**Target branch:** [`feature/atlas-data-generator`](https://gitlab.appian-stratus.com/appian/dev/solutions-os/-/tree/feature/atlas-data-generator)
(the clean, data-gen-only branch, already in line with `prod/main`). This determinism work is a
**follow-up MR** — MR !101 merges first once its own (part-1) blockers are resolved; this program does **not**
get bolted onto !101.

---

## 1. The problem (verified)

The family expresses its workflow as prose and tries to guarantee correctness through emphasis: 5 `🛑 STOP!`
banners, 40+ `⚠️` markers, `MANDATORY COMPLIANCE` headers, seven `COMMON FAILURES TO AVOID` tables. Only
**three** operations are actually deterministic — and only because they were pushed into MCP tools
(`resolve_write_set`, `verify_write_coverage`, `expand_record_csv`).

**Cross-verified against the branch (2026-07-31):**
- **Line counts are exact** — 4,194 total across the 17 procedural files (every file matches the proposal).
- **The in-repo precedent is real and larger than cited** — `data-model-workflow` on `prod/main` ships
  **18 scripts + a full pytest suite (45 .py) + `ruff.toml`** (proposal said "14"). a11y's
  `check_rule_refs.py` / `query_rules.py` also exist. This is a **port to an established in-house pattern.**
- **The defects are real** — spot-checked D-1 (dual payload contract: `step-4` line 27 "payloads.json IS THE
  SOURCE OF TRUTH" vs line 184 "Do NOT write one giant payloads.json"), D-2 (multiple FK notations),
  D-7 (`step-0` says both "ALL 7 FILES" and "All 6 files. No exceptions.").
- **D-12 is already resolved by us** — the undefined `D9/D15/D16/D17/D18` codes are gone (removed in
  commit `7095239373` as part of the MR !101 part-1 fixes). One Appendix-A row is pre-closed.

## 2. The triage (proposal §4)

| Bucket | Meaning | Share | Disposition |
|---|---|---|---|
| **A — Codeable** | output fully determined by inputs (set arithmetic, topological order, schema validation, string formatting, scaffolding) | ~60% (2,510 ln) | → `dg` CLI |
| **B — Judgment** | interpret a request, read SAIL, recognize a pattern, generate content | ~19% (795 ln) | → stays prose; captured as `decisions.json` (D1–D14) |
| **C — Delete** | duplicates another section or exists only to coerce compliance | ~21% (889 ln) | → deleted |

> The 60/19/21 split is directional (line boundaries are approximate by the author's own note) — treat it as
> rationale, not a precise metric.

## 3. The architecture — the one hard constraint that dictates everything

**Python scripts cannot call MCP tools** (MCP is agent-side transport; a script has no path to
`resolve_write_set` / `query_records` without re-implementing Appian + Atlas-KB auth). Therefore:

> **The agent performs all I/O. The `dg` CLI is a set of pure functions over on-disk artifacts.**

The agent calls an MCP tool → writes the response **verbatim** to `raw/` → invokes a `dg` subcommand that
reads `raw/` and produces the next artifact. **No script ever touches the network.** Two payoffs:
1. **Offline replay** — `raw/` makes any run reproducible with no environment/credentials → enables
   **golden-file testing**.
2. **Trivial unit tests** — every subcommand is `f(json) → json` → the port is safe to do incrementally.

**Division of labour (illustrated — coverage gate):** agent runs `dg plan-writes` (prints exact
`resolve_write_set` args) → agent calls the MCP tool, saves `raw/write_set.json` → CLI `dg coverage-gate`
does the set arithmetic, writes the report, sets `state.json`, exits 0/1 → on exit 1 the agent reads
`missing[]` and returns to payload construction. **The agent never computes the diff; the CLI never calls the network.**

### Request directory layout (per run)
```
data-requests/{YYYY-MM-DD}_{slug}[-{NN}]/
├── state.json          # single source of workflow state (written by dg, read by `dg gate`)
├── decisions.json      # the model's answers to D1–D14, schema-validated
├── raw/                # verbatim MCP responses — never hand-edited
├── payloads/           # 00-metadata.json + NN-{table}.json (single) / NN-{table}.spec.json (bulk)
├── reports/            # human-readable md — nothing downstream parses these
└── out/bulk-data.sql   # bulk mode only
```

### The `dg` CLI surface (full list in `proposal-source.md` §6.3)
`init · state · gate · plan-writes · record-writes · plan-footprint · build-footprint · build-arch ·
build-payloads · check-fields · coverage-gate · validate · exec-plan · exec-record · verify-input ·
gen-sql · report · erd-input` — each reads artifacts, writes artifacts, exits 0 on pass / non-zero with a
machine-readable reason.

## 4. The five contracts to freeze first (Phase 0 — proposal §7)

Every defect in Appendix A is a symptom of one of these being undefined. **No logic is written until these
are frozen as JSON Schemas** validated against three captured fixtures:
1. **Payload contract** — `payloads/` only; kill the monolithic `payloads.json` (D-1).
2. **FK placeholder grammar** — one notation `@alias([index])?(.field)?`; reject the other five (D-2).
3. **Status enum** — `PENDING | IN_PROGRESS | PASS | BLOCKED`, everywhere; no emoji in `state.json` (D-5).
4. **`state.json`** — includes `gate_mode` so a degraded run can never render as an unqualified `PASS` (D-4).
5. **`config/thresholds.json`** — extracts the magic numbers (coverage %, rounding, batch size,
   `live_record_limit`, `bulk_min_rows`) currently asserted in prose and enforced nowhere (D-6, D-14).

## 5. The decision points (D1–D14) — the model/code seam

`decisions.json` is the schema-validated record of the ~14 places a model must actually decide something
(parse the request, choose entry points, **choose the gateway branch (D3 — load-bearing)**, resolve gating
groups, identify form-created records, recognize exemplar patterns, generate/explain values, classify
reference proximity, choose uniqueness/fan-out/document/generator, route a manage request). Full table in
`proposal-source.md` §5. Everything downstream of D3 is arithmetic.

## 6. The phases at a glance

> **Status (2026-08-03): Phases 0–9 DONE ✅ · Phase 10 remaining ⬜.** 89 tests, ruff clean; prose 480 ln;
> all 15 Appendix-A defects closed. See `tracker.md` for details.

| Phase | Doc | Status | Outcome | Depends on |
|---|---|---|---|---|
| 0 | `phase-00-freeze-contracts.md` | ✅ | 5 JSON Schemas + 3 fixtures; every Appendix-A defect resolved | — |
| 1 | `phase-01-state-and-gate.md` | ✅ | `state.py` + `gate.py` | 0 |
| 2 | `phase-02-scaffold.md` | ✅ | `scaffold.py` (`dg init`); fixes 6-vs-7 (D-7) | 1 |
| 3 | `phase-03-coverage-gate.md` | ✅ | `coverage.py`; fixes D-3, D-4 | 2 |
| 4 | `phase-04-payload-validation.md` | ✅ | `validate.py`; kills the no-op (D-8) | 3 |
| 5 | `phase-05-sql-emitter.md` | ✅ | `sql_emit.py`; deterministic bulk SQL | 4 |
| 6 | `phase-06-exemplar-footprint.md` | ✅ | `footprint.py`; BFS + clone mechanics | 4 |
| 7 | `phase-07-field-coverage.md` | ✅ | `fields.py`; enforced `field_reasoning` | 4 |
| 8 | `phase-08-decisions-and-prose-rewrite.md` | ✅ | decisions schema + prose 480 ln / `⚠️` 2 | 2–7 |
| 9 | `phase-09-manage-and-erd.md` | ✅ | `dg erd-input` + config; manage refs | 8 (parallel-ok) |
| 10 | `phase-10-ci.md` | ⬜ | pytest + ruff + schema-lint + reference-integrity CI jobs | 1+ (incremental) |

Each phase is **independently mergeable** with its own tests and its own prose deletions. Reviewer's
"Option 3" stopping point = Phases 0–4 + 7.

## 7. What stays irreducible (proposal §10)

Form-created records (D5), field-value generation (D7/D10 — determinism = **seeded + recorded**, not
removing the model), semantic document matching (D12), and stale-KB repair (code detects + refuses; can't
repair). **Honest target: *reproducible given ~14 recorded decisions, mechanically verifiable everywhere else.***

## 8. Prerequisites & open decisions (must-resolve before committing)

1. **Fixture-capture environment (the linchpin).** Phase 0 requires capturing real end-to-end MCP responses
   for **manual, exemplar, and bulk** modes against a real app (SourceSelection) via Atlas + DG MCP. If that
   environment isn't available, Phase 0 stalls. **Confirm access before starting.**
2. **Script placement — decision needed.** The proposal targets `.kiro/skills/data-gen/scripts/` (mirroring
   `data-model-workflow`). But our consolidated structure has **4 skills sharing**
   `.kiro/resources/data-generator/`. A single `dg` CLI serving all four fits more naturally under
   **`.kiro/resources/data-generator/scripts/`**. → Recorded as decision **DEC-1** in the tracker; the phase
   docs use `<dg-root>/` as a placeholder until resolved.
3. **ERD personal-repo (#19) is NOT solved by this program.** Phase 9 converts ERD *input* to code + config
   and kills the hardcoded GSS taxonomy, but the `erd-gen` renderer (personal repo, `curl|bash` + Lucid
   token) still needs a separate home. Track it independently.
4. **Prose rewrite cadence.** The proposal batches the rewrite at Phase 8. Recommendation: update each step
   file's prose **as its phase lands** to avoid a confusing middle state where prose references `dg`
   subcommands that only partially exist.
5. **Ownership/capacity.** This is a real multi-week build (~19 script modules, 3 fixtures, schemas, CI) — a
   dedicated agent (with the required MCP tools) will implement it. Confirm capacity before Option-4-in-full.

## 9. How to use this folder

- **`proposal-source.md`** — the authoritative proposal; phase docs cite its sections/appendix.
- **`phase-NN-*.md`** — the elaborated, do-this implementation guide for each phase (objective, deps, files,
  step-by-step, code/schema sketches, retirements, "Done when" tests).
- **`tracker.md`** — live progress: phase status, per-phase checklists, the defect (D-1…D-15) resolution log,
  and the decision log (DEC-*). **Update it as work lands.**

## 10. Definition of done (whole program)

Total procedural prose < **1,700 lines** (from 4,194); every `dg` subcommand referenced by exactly one step
file; `grep -c '⚠️'` across the family < **15**; all three fixtures replay byte-identical through the pipeline;
CI fails on contract drift or a prose/subcommand mismatch.
