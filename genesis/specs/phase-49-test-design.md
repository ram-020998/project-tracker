# Phase 49 — Test Design: test suites, scenarios, cases and test impact analysis

> **Status:** SPEC-DRAFTED 2026-10-26 · **Author:** genesis-spec agent.
> Sub-specs: `phase-49-test-design/49-01..49-09`. Findings (code facts, research, every decision): `49-01-findings.md`.
> Repos: **genesis** (backend + web, migration **m0025**) and **genesis-workflows** (new `test-design-analysis`).
> Proposed ADRs: **ADR-078** (Test Design stage + test model) and **ADR-079** (test↔object traceability + impact
> analysis). Part 1 of the testing framework; part 2 (test scripts + execution engine) is a later phase.

## 1. Why this phase exists

Genesis takes a feature from Spec to finalized stories and implements stories in the dev environment, increasingly by
agentic workflows that change many objects quickly. Nothing records **how the feature is tested**, and nothing can say
**which tests a change to an object puts at risk**. This phase adds the test design half of a testing framework: the
tests themselves (as structured, identified records) and the traceability that drives regression test selection. The
test execution engine (part 2) will attach scripts to these records.

## 2. Goal

1. A fifth feature stage, **Test Design**, that turns a feature's finalized stories (+ Spec, UX, Technical Design, the
   KB) into a **Test Suite** of ordered **Test Scenarios** that reference reusable **Test Cases**.
2. Every case (`TC-000001`) and scenario (`TS-000001`) is a first-class, editable, lifecycle-managed record.
3. Each case traces to the **stories** it verifies and to the **Appian objects** it exercises; the links stay current
   through implementation, KB syncs and edits.
4. **Test Impact Analysis:** for a set of changed objects (picked, from a story, or from a KB sync) show the affected
   suites → scenarios → cases, direct and indirect through the dependency graph.
5. The foundation part 2 needs: stable ids, an expected result per case, an automation status, retire-not-delete.

## 3. Decisions (locked with the user, 2026-10-26 — detail and rationale in `49-01-findings.md` §5–§7)

| # | Decision |
|---|---|
| D1 | The stage starts after the Feature Breakdown is completed **and** stories are finalized; it links to `GNS_` stories. |
| D2 | Cases are owned by the feature's suite; a scenario is an **ordered list of case references** (reuse within the suite). |
| D3 | Case fields: id, title, Given/When/Then, type, priority, automation status. |
| D4 | Ids `TC-000001` / `TS-000001` from `kb_sequences`; never reused or renumbered; the suite has no own id. |
| D5 | Object links store `(app_uuid, object_uuid)` + name/type; join to `kb_objects` and to the wiki page when one exists; NEW objects start unresolved. |
| D6 | Only cases store object links; scenario and suite object sets are computed. |
| D7 | On implementation, every case linked to the story gets every object the story changed (program, safe selection). |
| D8 | Impact walks the dependency graph inbound; direct + indirect (N hops) labelled; default 2 hops, 1–5. |
| D9 | Impact screen is application-scoped, computed on demand; inputs: picked objects, a story, a KB sync. |
| D10 | A changed story flags its cases **Needs review**; never auto-rewritten; uncovered stories visible. |
| D11 | Finalize once; afterwards a **top-up** run proposes additions for chosen stories, accepted one by one. |
| D12 | Local only; Hub-ready columns; machine-unique ids are a prerequisite of the later Hub phase. |
| D13 | Seven screens (stage, Tests tab, case page, scenario page, story Tests section, wiki Tests section, Test Impact tab). |
| D14 | Workflow: cases per epic first, then scenarios over the whole pool, program assemble, coverage critic. |
| D15 | Cases and scenarios: Draft → Ready → Retired; retire instead of delete after Finalize. |
| D16 | Generic CSV export of the suite; tool-specific layouts later. |

Defaults F1–F13 (confirmed) and refinements R1–R7: `49-01-findings.md` §6–§7.

## 4. Current state (code-grounded — full detail in `49-01-findings.md` §2)

| Area | Today | File(s) |
|---|---|---|
| Stage framework | 4 stages; per-stage prereq helper + launcher; `StageFinalizer._BINDINGS`; `ChatModeProfile` per stage; web `STAGE_DEFS` + `STAGE_REGISTRY` | `genesis/genesis/kb/stages.py:34`, `api/features.py:923-1199`, `chat/stage_finalizer.py:139`, `chat/mode_profile.py:213`, `web/src/features/features/stages.ts:47`, `stage-registry.tsx:32` |
| Stories | `kb_epics`/`kb_stories`, `GNS_` from `kb_sequences`, `spec_refs` with fingerprint "suspect" | `kb/stories.py:48`, `kb/spec_changes.py:52-116`, m0016/m0022/m0024 |
| Objects + graph | `kb_objects` (every object, `diff_hash`, SCD-2), `kb_dependencies`, inbound closure | m0007, `kb/_graph_reads_mixin.py:109` |
| Object Wiki | sparse pages (implemented / pulled objects), entries carry `story_key` | m0021, `kb/object_wiki.py:45`, `workflows/story-implementation/graph.py:365-402` |
| Implementation finalizer | observes the implementation run → story lane move | `chat/story_implementation_finalizer.py` |
| KB sync | `kb_syncs` (`objects_added/modified/removed`), run via the sync workflow | m0007, `services/application_sync.py` |
| Tests | **none** | — |

## 5. Design overview

```
Feature: Spec · UX · Technical Design · Feature Breakdown ──Finalize Stories──► GNS_ stories
                                                                         │ (D1, F2 gate)
                                                                         ▼
Test Design stage ── test-design-analysis run (49-03) ──► test-design.html (+ embedded JSON)
   └ completion chat (test_design) ── Finalize (49-04) ──► kb_test_suites / kb_test_scenarios / kb_test_cases
                                                            kb_test_scenario_steps (ordered refs, D2)
                                                            kb_test_case_stories   (fingerprint, D10)
                                                            kb_test_case_objects   (diff_hash, origin, D5)
   └ top-up run (D11) ──► proposals ──accept/reject──► new records

Link maintenance (49-05): story implemented ─► D7 · KB sync ─► resolve (F6) · edits ─► manual · startup reconcile
Impact engine (49-05): changed objects ─► inbound walk over kb_dependencies (D8) ─► cases ─► scenarios ─► suites
API (49-06) ─► web (49-07): stage · Tests tab · case/scenario pages · story + wiki sections · Test Impact tab
```

| Building block | Sub-spec |
|---|---|
| Findings + decisions | 49-01 |
| Data model (m0025), stores, ids, lifecycle | 49-02 |
| `test-design-analysis` workflow (design + top-up modes) | 49-03 |
| Stage integration: start/re-run, finalizer binding, chat mode, Finalize, top-up, CSV | 49-04 |
| Link maintenance + impact engine | 49-05 |
| HTTP API | 49-06 |
| Web experience | 49-07 |
| Review, hardening, live acceptance | 49-08 |
| Release + docs write-back | 49-09 |

## 6. Session plan

S1 = 49-02 (genesis-dev) and S2 = 49-03 (genesis-dev, genesis-workflows) in parallel → S3 = 49-05 (reads 49-02 As
built; provides `resolve_object` + the D7 linker that 49-04 calls) → S4 = 49-04 (reads 49-02, 49-03 and 49-05 As
built) → S5 = 49-06 (reads 49-02/04/05) → S5b = 49-08 §1.1 **H1** (genesis-dev; the RunManager ordering fix, D17) →
S6 = 49-07 (reads 49-06) → S6b = 49-08 §1.1 **H2** (genesis-dev; feature roll-up status, D18) → S7 = 49-08
(genesis-review) → S8 = 49-09 (genesis-release, then genesis-docs). S3 onwards
run **one at a time**: they share the genesis checkout. *(Order of
49-04/49-05 swapped 2026-10-26 after the 49-02/49-03 builds: 49-04 depends on 49-05's functions.)*

## 7. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 49-01 | project-tracker | Findings, decisions D1–D16, defaults F1–F13, refinements R1–R7 |
| 49-02 | genesis | m0025 (7 tables + 2 sequences), `TestDesignStore`, `TC-`/`TS-` allocators, test lifecycle machine, fingerprints |
| 49-03 | genesis-workflows | `test-design-analysis` v0.1.0: per-epic case loop, scenario composition, program assemble (HTML + JSON), coverage critic + heal; top-up mode |
| 49-04 | genesis | `test_design` stage wiring (prereq, start/re-run, `_Binding`, `ChatModeProfile`), Finalize service, top-up service, CSV builder |
| 49-05 | genesis | Object resolution, D7 implementation linker, sync resolver, startup reconcile, derived flags, impact engine |
| 49-06 | genesis | All new `/api` routes + request/response contracts + tests |
| 49-07 | genesis (web) | Stage card + workspace, Tests tab, case + scenario pages, story + wiki sections, Test Impact tab, `web/static` |
| 49-08 | genesis, genesis-workflows | Independent review + gates + live acceptance (incl. real-browser width probe, L-090) |
| 49-09 | genesis, genesis-workflows, project-tracker | Release genesis v0.79.0 → genesis-workflows v0.23.0, deploy, docs write-back (ADR-078/079) |

## 8. Release plan

genesis **v0.79.0** (minor; m0025, DB 24 → 25) first — without the workflow installed the stage start returns the
friendly "not installed" 409 (L-033). Then genesis-workflows **v0.23.0** (new `test-design-analysis` v0.1.0) with its
genesis dev pin moved to v0.79.0 (L-057). genesis-core v0.9.8, kiro-agent-sdk v0.7.1, genesis-appian-parser v0.3.0
unchanged. No Hub change. Detail: 49-09.

## 9. Scope

- **In:** everything in §2 and the seven screens of D13; generic CSV export; tests (pytest, workflow tests, Vitest +
  jest-axe); the two ADRs.
- **Out:** test scripts, test data, test steps, execution, results, defects (part 2); Hub sync; any Appian write.
- **Deferred** (backlog `specs/backlog/phase-49-follow-ups.md`): the clause ↔ story ↔ test matrix; Hub sync of test
  records + machine-unique ids; app-wide regression suites + cross-feature case reuse; Xray / Zephyr Scale / TestRail
  export layouts; shared preconditions / shared steps; a stored impact report.

## 10. Defaults

F1–F13 in `49-01-findings.md` §6. Key ones: start = notes + ≤ 3 docs; gate = stories finalized; read-only against
Appian; default impact depth 2 hops; Finalize creates **Ready** records, manual adds start **Draft**.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Large features (100+ stories) → one giant emission | Per-epic case loop + a scenario turn that emits mostly ids; program assemble (L-064, L-076) |
| Wide fan-out (a record type used everywhere) floods impact | Hop labels, direct-first ordering, depth control (D8); performance test on a 2 500-object KB (49-05 §6) |
| Most links start unresolved for NEW objects | D7 at implementation + F6 at sync + startup reconcile (R7); the case page shows unresolved state |
| Agent proposes wrong/hallucinated UUIDs | Genesis keeps a UUID only if a current `kb_objects` row exists (R3) |
| Embedded JSON drifts from the visible HTML in the completion chat | `_STEERING_TEST` keeps both in sync (as `_STEERING_FB`); Finalize parses the JSON only and 422s when missing/garbled |
| New module names collected by pytest | R6 naming rule; reviewer checks |
| Version skew (genesis released before the workflow) | Friendly 409 when not installed (L-033); `_workflow_declares` for optional inputs |

## 12. ADR summaries (proposed — genesis-docs records them on Accept)

- **ADR-078 — The Test Design stage and the test model.** A fifth feature stage (after finalized stories) produces a
  Test Suite of ordered Test Scenarios referencing reusable Test Cases (ISTQB / ISO 29119 terms); Finalize once into
  `TC-`/`TS-` records with Given/When/Then, type, priority, automation status and a Draft → Ready → Retired lifecycle
  (retire, never delete after Finalize); a top-up run proposes additions; generic CSV export. Amends ADR-056 (one more
  stage + a "stories finalized" gate).
- **ADR-079 — Test traceability and test impact analysis.** Cases link to stories (fingerprinted → Needs review) and to
  objects by `(app_uuid, object_uuid)` (not the wiki table), with origins design / implementation / sync / manual;
  implementation links every changed object to the story's cases (safe selection); scenario/suite object sets are
  computed; impact analysis walks `kb_dependencies` inbound (direct + N-hop indirect, default 2) from picked objects, a
  story or a KB sync. Complements ADR-070 (wiki) and ADR-075 (fingerprinted trace links).

## Context manifest

```toml
areas    = ["features-stages", "stories-workbench", "kb-sync", "workflows-library", "web-shell", "db", "api"]
adrs     = ["ADR-042", "ADR-050", "ADR-056", "ADR-058", "ADR-059", "ADR-060", "ADR-063", "ADR-064", "ADR-070", "ADR-071", "ADR-072", "ADR-075"]
lessons  = ["L-058", "L-063", "L-064", "L-076", "L-090"]
docs     = ["tracker:specs/phase-49-test-design/49-01-findings.md"]
code     = ["genesis/genesis/kb/stages.py", "genesis/genesis/api/features.py", "genesis/genesis/chat/stage_finalizer.py",
            "genesis-workflows/workflows/feature-breakdown-analysis/**"]
upstream = []
```
