# Phase 49 — Test Design: test suites, scenarios, cases and test impact analysis — as built

> **Status:** ✅ SHIPPED 2026-10-31 · genesis **v0.79.0** (`908e5d4`) → genesis-workflows **v0.23.0** (`04c242e`;
> `test-design-analysis` 0.1.0; genesis dev pin → v0.79.0, genesis-core pin stays v0.9.8) · migration **m0025**
> (DB 24 → **25**; memory.db v1) · **ADR-078** + **ADR-079** Accepted (ADR-078 amends ADR-056). Unchanged: genesis-core
> v0.9.8 (`CORE_MAJOR=1`), kiro-agent-sdk v0.7.1, genesis-appian-parser v0.3.0; no Hub change.
> Spec: `specs/phase-49-test-design.md` + `49-01..49-09` (each has its As built / As run; H1–H4 in 49-08 §1.1).
> Reviews: `specs/phase-49-test-design/reviews/`. Follow-ups: `specs/backlog/phase-49-follow-ups.md` (items 1–16).
> CI: genesis master 7256473 + tag 7256474; genesis-workflows master 7256701 + tag 7256702 (all green). Deployed to
> the fleet (main :8760, userb :8761) on 2026-10-31.

## What changed for the user

- A fifth feature stage, **Test Design**, unlocks once the Feature Breakdown is complete and the stories are finalized.
  Start (notes + up to 3 docs) runs `test-design-analysis`; the completion chat edits the test-design document;
  **Finalize tests** turns it into records: ordered **test scenarios** (`TS-000001`) that reference reusable **test
  cases** (`TC-000001`) with Given/When/Then, type, priority and automation status. Re-run and Reopen are refused after
  Finalize; **Generate tests** (top-up) proposes additions for chosen stories, accepted one by one.
- Feature → **Tests** tab: suite summary, scenarios, a filterable/sortable cases table, the Story coverage donut
  (Covered / Needs review / Not covered, plus a Tasks line, each opening a story list), top-up review, CSV export.
- One page per case and per scenario: edit, link stories and objects (planned objects by name), Draft → Ready → Retired
  (retire refused while a scenario uses the case), reorder steps.
- Story page and Object Wiki page gain a **Tests** section; "Check test impact" from a wiki page.
- Application → **Test Impact** tab: pick objects, a story or a KB sync → affected suites → scenarios → cases, direct
  and indirect (hops 1–5, default 2), with the dependency path.
- Platform fixes that affect every stage and story run: a finalizer now completes the stage on the live `run.final`
  (no reload or restart, H1); a run orphaned by a server restart is failed at startup instead of staying `running`
  forever (H3 M3); running stage pages poll themselves (H3 m3); the feature roll-up shows In progress for partial
  progress (H2).

## Delivered (by sub-spec)

| Sub-spec | Result | Commits |
|---|---|---|
| 49-01 | Findings, decisions D1–D20, defaults F1–F13, refinements R1–R8 | — |
| 49-02 | m0025 (7 tables + 2 sequences), `TestDesignStore`, `TC-`/`TS-` allocation, test lifecycle, fingerprints; 35 tests; review NEEDS_CHANGES → SHIP | genesis `b9e9487` |
| 49-03 | `test-design-analysis` 0.1.0 (per-epic cases, one scenario turn, program assemble, coverage critic + `heal_check`; design + top-up modes); 75 tests + golden fixtures; review SHIP ×2. Follow-up: duplicate test-module fix | workflows `325cc23`, `9cb061f` |
| 49-05 | Object resolution, D7 linker, sync resolver, startup reconcile, impact engine (3 hops over 2 500 objects: 21 ms); 44 tests; SHIP ×2 | genesis `454db1f` |
| 49-04 | Stage wiring, `_Binding`, `test_design` chat mode, Finalize, top-up, CSV, `LOCAL_ONLY_STAGES`; 44 tests; SHIP ×2 | genesis `a8ba5b8` |
| 49-06 | `api/testdesign.py` (every route), 9 contract fixtures; 35 tests; SHIP ×2 | genesis `73b3bd3` |
| 49-08 H1 | Store the run status before `run.final`; chat-supervisor reconcile keyed on a matching durable `run.final`; 9 tests; SHIP ×2 | genesis `d62ae03` |
| 49-07 | The seven screens, types, client, hooks; web 49 files / 445 tests (was 46 / 380); SHIP ×2 | genesis `8a7ca96`, `5d69eb7`, `66d7dce`, `45be579` |
| 49-08 H2 | Feature roll-up: Draft only when nothing started | genesis `f0df126` |
| 49-08 review | Gates green, static items OK; live rows 15 + 16 FAIL → **NEEDS_CHANGES** | — |
| 49-08 H3 | Orphaned-run startup sweep behind a run-owner `flock`; Cases table + stage grid widths from a browser probe; local-only Publish hidden; stage-run poll; Reopen reason; Task-link refusal; H3 review NEEDS_CHANGES (MJ1) → SHIP; re-acceptance of rows 6, 15, 16, 18 → **SHIP** | genesis `9324a76`, `b4a9f09`, `3dacbf5`, `d138078` |
| 49-08 H4 | Story coverage as an SVG donut (design tokens, no chart lib) + per-category dialog; SHIP | genesis `5da9916` |
| 49-09 | Release genesis v0.79.0 → genesis-workflows v0.23.0, CI green, backup branches deleted, fleet deployed (DB v25 on both), this write-back | genesis `908e5d4`, workflows `04c242e` |

Tests at release: genesis pytest **1366** (1187 at v0.78.0); web vitest **467** in 50 files (380 in 46; counted at the
H4 head — the release changed only `web/src/version.ts` and was not re-run locally; CI frontend green);
genesis-workflows `validate_library` **14** workflows, `validate_skills` 3, pytest **305** (the duplicate-module fix
took the full-library count 331 → 305: 37 double-run tests gone, 11 never-run tests now run).

## Live acceptance (49-08 §3, main :8760, feature 6 "Evaluation Instructions")

Rows 1–3, 5–8, 10–14, 17, 18 PASS; 4 skipped (operator finalized before the chat edit); 9 skipped (no implemented
story in the app; covered by tests). Rows 15 (width probe) and 16 (restart mid top-up) failed in the first pass and
passed after H3. The first live design run (`r-d02d990d3331`): 65 nodes against `recursion_limit` 300, agents opened
the input files (first workflow to get all bulk inputs only as files), 32 cases + 6 scenarios, the full healing ladder
then escalation on a real conflict in the source documents (2000 vs 4000 characters). Completion chat 4–5 ms after
`run.final` on two runs: H1 works live. Data left on main: feature 6's suite (34 cases, 7 scenarios, top-ups 1–4),
feature 4's completed, unfinalized Test Design stage (kept by the user).

## Decisions and deviations (all in the sub-specs; no ADR deviation)

- Test states live on `LifecycleState`; preconditions come from the store so no caller skips them; no test
  precondition filters `allowed()`, so refusals carry the reason (49-02).
- A UUID is stored only when the KB confirms it; NEW objects stay unresolved by name + type until a sync (49-05).
- Impact ordering: direct before indirect, then priority, then key; a sync's removed object is a direct hit (R1).
- Embedded JSON block `<script id="genesis-test-design" type="application/json">`, every `<` written as `\u003c`;
  Finalize matches the block by id in any attribute order (49-03/49-04).
- Test records are local only: `LOCAL_ONLY_STAGES` on publish/adoption/pull, and no "Publish to team" (49-04, H3 m1).
- Suite/case/scenario/object/impact reads resolve pending links on demand, taking no write lock when nothing is pending
  (R8, 49-06).
- 49-04's "observers run before the status is written" is superseded by H1 (the 49-04 As built carries the note).
- H3: the orphaned-run sweep fails, not pauses, a lost run (it can still be forked, ADR-025); the coverage column at
  2xl is a fixed 16rem (the 2/3 split could not meet the spec's own acceptance); a pre-existing Task link survives
  edits so it can be removed.
- H4: slice colours success / warning / danger; centre text in HTML over an `aria-hidden` SVG.
- Release: genesis README status line bumped with the three version files; backups of both fleet DBs taken before the
  deploy; `test-design-analysis` installed from GitLab at `v0.23.0` on both instances.

## Lessons (write-back decisions)

| Candidate (source) | Decision |
|---|---|
| sqlite3 opens the tx at the first DML; SELECT-validate-write isn't atomic (49-02) | **Added L-091** |
| A `test_*` module/symbol can be collected (49-02) + two `tests/__init__.py` shadow each other (49-03 P1) | **Added L-092** (one rule: pytest collection) |
| Observer must not re-read the store on the event (49-04) + "announce only after storing" and its reconcile corollary (H1) | **Added L-093** (merged; the 49-04 form is superseded by H1's) |
| Adding a value to a generic registry opts it into every consumer (49-04) | **Added L-094** |
| Don't store a UUID the KB doesn't confirm (49-05) + route every write through the store's helpers (49-05 m4) | **Added L-095** (merged; same review, same table) |
| Route-order tests on FastAPI 0.139+ (49-06) | **Added L-096**, with the register-specific-before-generic rule from the 49-04 hand-off |
| A startup "orphaned" sweep must hold an exclusive owner lock (H3) | **Added L-097** |
| Level-triggered recovery on every read: read-only check first (49-06) | **Extended L-058** (plus pointers to L-093/L-097) |
| Mirror each server flag one-to-one in the web (49-07) | **Extended L-011** |
| A heal patch must pass the same invariants as the turn it corrects (49-03) | **Extended L-075** |
| Build not finished before the commit (49-07); verifying reads batched with the step they prove (H2, H3, H4, 49-09 As run) | **Extended L-089**; its rule now also says a verifying read runs in its own call |
| Dev-server probe needs cwd `web/` (H3); probe outputs per run, wait out animations (H4) | **Extended L-090** |
| `attach_healing` never resets its counters across a restart (49-03 P2) | **Backlog** item 14 (a genesis-core defect, not a rule) |

## Agent-system notes

1. L-089 recurred in four sessions (49-07, H2, H4, the release) and in this write-back: the docs agent batched two
   `genesis-ctx add lesson` calls and once a verifying `grep` with the call it checked. Both outcomes were verified
   alone before relying on them. The release and web-dev skills now say a verifying read runs in its own call.
2. Hand-offs between sub-specs worked through the As built files (e.g. 49-05 → 49-04 `resolver()`, 49-06 → 49-07
   contract fixtures). The build order 49-04/49-05 had to be swapped after the first two builds.
3. Area-map gaps made `genesis-ctx check` miss rules three times (49-02 `domain/**`, 49-05 `testimpact.py` and
   `_graph_reads_mixin.py`, H4 `web/src/features/test-design/**`). All are mapped now (features-stages,
   stories-workbench, kb-sync). No separate `testing` area: Phase 50 (the platform monorepo) is next, not test
   execution; reconsider when part 2 is specced.
