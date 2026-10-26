# Backlog — Phase 49 follow-ups (Test Design)

> **Status:** 📝 BACKLOG (not scheduled). · **Created:** 2026-10-26 · **Repos:** genesis, genesis-workflows, Genesis Hub
> Source: the Phase 49 Q&A (`specs/phase-49-test-design/49-01-findings.md` §5, D12–D16), items the user asked to keep
> for later. Part 2 of the testing framework (test scripts + execution engine) is its own phase, not listed here.

1. **Traceability matrix (spec clause ↔ story ↔ test case).** Deferred in D13. A per-feature matrix over the spec's
   clauses (ADR-075 `data-cid` labels) → the stories that trace to each clause → the test cases linked to those
   stories, with gaps highlighted (clause with no story; story with no case) and suspect/needs-review markers. Derive
   case → clause through stories (D10: no stored case↔clause link). Likely a view on the spec preview (which already
   shows clause ↔ story coverage) or a Tests-tab sub-view.
2. **Hub sync of test records + machine-unique ids.** Deferred in D12. New Hub record types (suite, scenario, case,
   scenario step, case↔story link, case↔object link) as an additive contract change built by the separate Appian agent,
   `collab/service.py` bindings, publish/pull, a two-machine live acceptance (L-071, L-085). **Prerequisite:** `TC-` /
   `TS-` (and `GNS_`) counters are per machine — make ids machine-unique or resolve collisions before syncing.
3. **App-wide regression suites and cross-feature case reuse.** Deferred with D2 / the one-suite-per-feature default:
   an application-level regression suite that selects cases from many features' suites (static selection and
   query-based, e.g. "all high-priority cases touching record type X"), which needs a suite id (D4).
4. **Tool-specific exports.** Deferred in D16: Xray, Zephyr Scale and TestRail CSV/XML column mappings on top of the
   generic CSV.
5. **Shared preconditions / shared steps.** Xray "Precondition" and Azure "Shared steps": a reusable Given block
   referenced by many cases (would let part 2 share setup scripts).
6. **Stored impact reports.** Impact is computed on demand (D9). Saving a report (inputs + result + timestamp) would
   let a release record "what we re-ran for change X"; pairs naturally with part 2 test runs.
7. **Test data and test steps.** Out of scope in D3 (part 2 boundary): parameterized test data sets and step-level
   detail when manual execution or script generation needs them.
