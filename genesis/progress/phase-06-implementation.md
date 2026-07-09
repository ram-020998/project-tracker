# Genesis — Phase 6 Implementation Record

> As-built record of Phase 6 (ERD Reference Workflow). Companion to
> `specs/phase-06-erd-reference-workflow.md`.

**Date:** 2026-07-09 · **Milestone:** M6 (Reference workflow) · **Status:** ✅ COMPLETE — 9 workflow tests green, library validation passing, pushed, CI green. Live Atlas/Lucid dry-run parity is an opt-in step (needs creds — see §5).

---

## 1. Summary

`erd-generation` is the **canonical reference workflow** — the template every other
workflow copies. It ports the validated imperative ERD pipeline onto Genesis
primitives and exercises the whole stack: per-node MCP injection, the program/agent
split, the blackboard, **two reliability trios**, an **approval gate with feedback
loop**, a **cli node** with a dry-run branch, and durable/resumable state.

---

## 2. What was built (`genesis-workflows/workflows/erd-generation/`)
```
graph.py        # self-contained (loader imports it standalone): META + build(ctx)
                #   + ported pure fns (normalize_atlas_schema, build_erd_document + DOMAIN_PALETTE,
                #     merge_relationships, build_erdgen_command, parse_erdgen_output)
                #   + prompt builders (fetch_prompt verbatim-dump, assign_prompt decisions-to-file)
                #   + custom cross-artifact validators (check_fetch, check_enriched)
workflow.yaml   # mirrors META (parity gate)
tests/          # 5 unit (pure fns + check_enriched) + 2 stubbed-graph (gate resume, escalation)
```
Registry: added `erd-generation` to `registry.json` (bumped `genesis_core_version`
to 0.3.0); `appian-atlas` (MCP) and `erd-gen` (CLI) were already registered.
Steering: `01-authoring-overview.md` now points to it as the reference; `MIGRATION.md`
records the row.

## 3. Graph (as built)
```
START → preflight(program) → fetch_schema(agent, mcp=appian-atlas)
      → [v_fetch → normalize | retry | escalate]                      # trio 1
      → normalize(program) → assign_domains(agent, no MCP)
      → [v_enriched → approve-domains | retry | escalate]             # trio 2
approve-domains(gate): approve→assemble | feedback→assign_domains | reject→report
assemble(program) → [dry_run? report : run_erdgen(cli) → report] → END
escalate(gate) → END                                                  # shared escalation
```
- **Verbatim-dump pattern:** `fetch_schema` writes `raw_schema.json` +
  `raw_relationships.json` to the blackboard (the ACP-buffer lesson); `normalize`
  (program) turns them into unified `schema.json`.
- **Decisions-to-file:** `assign_domains` writes compact per-table domain + field
  choices to `enriched.json`; the program assembles + owns the colour palette.
- **Custom validators:** `check_enriched` enforces table coverage vs `schema.json`,
  domain ∈ palette, PK-first, and audit-column exclusion — actionable messages fed
  back into the agent prompt on retry.
- **Feedback loop:** gate `feedback` re-runs `assign_domains` (consumes
  `decisions["approve-domains.feedback"]`).

---

## 4. Verification (evidence — acceptance criteria §6)

| Criterion | Result | Test / artifact |
|---|---|---|
| Passes library CI (contract + reliability lint + tests) | ✓ | `validate_library.py` → "LIBRARY VALIDATION PASSED (2 workflows)"; both trios pass the lint |
| Installable; prereq flags missing appian-atlas/erd-gen | ✓ (mechanism) | Phase-3 catalog `prerequisites()` + `preflight` `ctx.clis.ensure("erd-gen")` |
| Dry-run reproduces the ERD (≈37 tables/174 rels) | ⚠️ needs live Atlas+Kiro | stubbed-graph proves assembly correctness end-to-end; live parity is opt-in (§5) |
| approve-domains gate pauses; feedback re-runs; approve proceeds | ✓ | `test_full_dryrun_through_gate` (interrupt → resume approve → done); feedback edge wired + covered by routing |
| Forced validator failure retries retry_max then escalates | ✓ | `test_forced_validator_failure_escalates` (retries==max+1, v_enriched ok=False, escalation interrupt) |
| Kill + resume mid-run continues from checkpoint | ✓ | resume path (`engine.resume` from the gate checkpoint) in `test_full_dryrun_through_gate`; Phase-5 worker resume proven in `test_runs.py` |
| Live Lucid publish (if configured) | ⚠️ opt-in | `run_erdgen` cli node + `build_erdgen_command`/`parse_erdgen_output` unit-tested; live needs Lucid token |
| Pure functions | ✓ | `test_normalize_atlas_schema`, `test_build_erd_document_palette`, `test_build_erdgen_command_*`, `test_parse_erdgen_output_*` |

**9 workflow tests green** (7 erd + 2 hello-appian), library validation passing.

---

## 5. Honest gaps / notes
- **Live dry-run parity (≈37 tables / 174 rels)** requires a real `appian-atlas`
  MCP (GITLAB_TOKEN) + local Kiro against `SourceSelection`, and live publish needs
  a Lucid token — neither is available in this headless env. The **stubbed-graph
  test** proves the deterministic pipeline (normalize → validate → assemble →
  erd-input.json with palette + relationships) end-to-end; the agent steps are the
  only live-only piece. Run the live check with real creds via the harness or the
  Phase-5 RunManager (`dry_run: false`).
- **Self-contained `graph.py`:** the loader imports `graph.py` standalone (no
  sibling-package import), so pure functions live in `graph.py` (matching
  hello-appian) rather than a separate `nodes.py`. Documented for authors.

---

## 6. Repos & tags after Phase 6
| Repo | Tag | Change |
|---|---|---|
| `genesis-workflows` | **v0.2.0** | +`erd-generation` reference workflow; registry/steering/MIGRATION; dev pin → genesis v0.5.0 |
| `genesis` | v0.5.0 | unchanged |
| `genesis-core` | v0.3.0 | unchanged |

---

## 7. Next: Phase 7 — Custom Web Workbench
Build the bespoke local UI (Preact/React) on the Phase-5 FastAPI APIs (catalog,
install, run control, live stream, the three HITL modes), superseding LangGraph
Studio. See `specs/phase-07-custom-web-workbench.md`.
