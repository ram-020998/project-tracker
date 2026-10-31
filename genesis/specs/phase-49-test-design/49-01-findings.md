# 49-01 — Findings: the Test Design stage (test suites, scenarios, cases and test↔object traceability)

> **Status:** SPEC-DRAFTED — Q&A with the user 2026-10-26; decisions D1–D16 (§5), defaults F1–F13 (§6, confirmed),
> spec-writing refinements R1–R7 (§7).
> Parent: `specs/phase-49-test-design.md`.
>
> This document records what was researched and decided before the spec set is written: the problem as the user
> stated it, how Genesis works today (code-grounded), how the standards and other products handle it, the options
> considered, and every decision.

---

## 1. The problem (as stated by the user, 2026-10-26)

Genesis needs a testing framework for the SDLC. It has two parts:

1. **Test design (this phase):** prepare the tests for a feature: a test suite, made of flows, made of individual
   test cases. Each test case is a sentence saying what must be checked; there is no script or code yet.
2. **Test execution engine (a later phase):** write the test scripts and run them. Out of scope here, but this phase
   must lay the foundation the scripts attach to.

What the user asked for:

- A **fifth feature stage**, "Test Design", beside Spec, UX Design, Technical Design and Feature Breakdown. A workflow
  reads the Technical Design, the existing app knowledge and the breakdown, and writes the complete test suite for the
  feature. A feature with several flows gets several test flows in its suite.
- Every test case has a **unique identifier**, like the `GNS_` story ids.
- The stage shows the flows and, inside each flow, its test cases, the way the Feature Breakdown shows its backlog.
- Each test case is **mapped to the stories** it tests.
- The suite, the flows and the cases have a **relationship with the application objects** they depend on (the user
  called it "test case to object relationship" and proposed linking to the Object Wiki table). Given a set of changed
  objects, Genesis must show the affected suites, flows and cases, so that later the matching test scripts can be
  re-run. Purpose: keep existing behaviour intact while agentic workflows change objects quickly.
- **Separate screens** to see this data.
- Use **standard industry terminology and practice**; the user's terms ("test flow", "test suite") are placeholders.
- The framework must be modular, rigid in its contracts and resilient.

## 2. How Genesis works today (verified in the code, 2026-10-26)

Paths: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis`, `workflows/` =
`/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-workflows/workflows`.

### 2.1 The stage framework (adding a stage is thin)

- Backend stage vocabulary: `StageStore.VALID_STAGES = ("spec","ux_design","technical_design","breakdown")`
  (`genesis/kb/stages.py:34`); `ArtifactKind` (`genesis/domain/enums.py:51`). Stage rows live in `kb_feature_stages`
  (m0015), one per `(feature_id, stage)`; every stage shares `SPEC_TRANSITIONS` (`genesis/domain/transitions.py:26`).
- Prerequisites are hand-written helpers that 409 the start: `_td_prereqs_ready`, `_fb_prereqs_ready`
  (`genesis/api/features.py:923, 969`). Launchers snapshot upstream HTML to files and call `run_manager.start`
  (`_launch_breakdown`, `features.py:981`).
- Run → stage artifact: one `_Binding` per workflow in `StageFinalizer._BINDINGS`
  (`genesis/chat/stage_finalizer.py:139-172`), plus a `_seed_*` first-turn text.
- Completion chat: one `ChatModeProfile` + `_STEERING_*` per stage (`genesis/chat/mode_profile.py:213-250`).
- Web: one `STAGE_DEFS` row with `requires` (`web/src/features/features/stages.ts:47`) and one `STAGE_REGISTRY`
  entry (`stage-registry.tsx:32`). No shell edits (ADR-056).
- The breakdown pattern this phase can mirror: HTML artifact + canonical JSON embedded in
  `<script id="genesis-backlog">` (`features.py:75-88`), refined in the completion chat, then the one-time **Finalize
  Stories** persists records (`features.py:1218`, ADR-060).
- A new stage needs **no migration**; the new test records will (next = **m0025**; DB is at v24).

### 2.2 Stories and their ids

- `kb_epics` / `kb_stories` (m0016; m0024 adds `spec_refs`, `answers`, `change_log`). Stories get `GNS_<6>` from
  `kb_sequences` inside the finalize/create transaction (`genesis/kb/stories.py:48-60`, ADR-072). The table is keyed by
  counter name, so a second counter (e.g. test cases) needs only a seed row + an allocator.
- Backlog story ids (`story-1-2`) are reassigned on every breakdown run (`feature-breakdown-analysis/graph.py:348`);
  only finalized stories have stable ids.
- Story `story_type`: a **Story** is front-end testable and carries Gherkin acceptance criteria; a **Task** is a
  backend change a tester cannot validate from the UI (ADR-059).
- Story ↔ spec clause links: `spec_refs = [{clause_id, fingerprint, origin, linked_at}]`; a link is **suspect** when
  the clause's fingerprint changed since linking (`genesis/kb/spec_changes.py:52-116`, ADR-075). A test ↔ object link
  can use the same shape with the object's `diff_hash`.

### 2.3 Objects, the dependency graph and the Object Wiki

- `kb_objects` (m0007, SCD-2) holds **every** object of a tracked app: `app_uuid`, `object_uuid`, `name`, `type`,
  `diff_hash`, … (current row = `valid_to_sync IS NULL`). `kb_dependencies` holds the edges.
- Reverse closure exists: `get_transitive_dependencies(direction="inbound")` (`genesis/kb/_graph_reads_mixin.py:109`),
  capped at 5 hops and 200 objects; exposed read-only through the `genesis-kb` MCP (`genesis/mcp/kb_server.py`).
- `diff_hash` changes when an object changes at a KB sync (random export values excluded, L-079), so each sync can
  detect changed objects without user input.
- **The Object Wiki is sparse.** `wiki_object_pages` (m0021, `UNIQUE(app_uuid, object_uuid)`) gets a row only when the
  story-implementation workflow changes an object (`workflows/story-implementation/graph.py:385` →
  `ObjectWikiStore.upsert_page`, `genesis/kb/object_wiki.py:45`) or when a teammate's page is pulled. It is not a
  catalog of all objects. Linking tests only to wiki rows would leave most objects unlinkable.

### 2.4 Upstream documents name objects, not UUIDs

- Technical Design: each "What changes" item names a real object or marks it **NEW**, as HTML prose; no UUIDs, no
  structured sidecar (`workflows/technical-design-analysis/graph.py:546-550`).
- Backlog: `appianPart`, `devNoteRef`, `clauseRefs`; no object references (`feature-breakdown-analysis/graph.py:356`).
- Only story-implementation records touched objects with a UUID (optional, "if known") in `implementation.json` /
  `wiki.json`, and the wiki entry carries `story_key` (`story-implementation/graph.py:598-604, 365-402`).
- Consequence: a test workflow must resolve existing objects to UUIDs itself (`genesis-kb` `search_objects`). Objects
  marked NEW have no UUID until they are implemented, so their links start **unresolved**.

### 2.5 Collaboration

- Synced kinds are listed in `collab/service.py:_BINDINGS` and mirror the **frozen** Hub contract (ADR-064). Sharing
  test records with teammates needs new Hub record types (an additive contract change, like the Object Wiki's).

## 3. Standards and other products (research, 2026-10-26)

| User's term | Standard term | Source |
|---|---|---|
| Test suite | **Test Suite** — a group of test cases | Azure Test Plans (Plan → Suite → Case); TestRail suites; Xray Test Set |
| Test flow | **Test Scenario** — a sequence of actions for executing a test; one scenario can yield several test cases | ISTQB glossary (`test scenario` = test procedure specification) |
| Test case | **Test Case** — inputs, preconditions, expected results, postconditions for one objective | ISTQB glossary |
| (future) script | **Test Script** — the automated form of a test procedure | ISTQB glossary |
| Spec / acceptance criteria | **Test basis** | ISO/IEC/IEEE 29119 |
| Case ↔ story link | **Requirements traceability** ("Tests / Tested By") | Azure Test Plans; Xray Test Coverage |
| Changed objects → tests to re-run | **Test Impact Analysis** / regression test selection | Azure Pipelines TIA; ISTQB Advanced Test Analyst |

- "Test Plan" is **not** a container: in ISO/IEC/IEEE 29119-3 it is the document describing scope, approach and
  schedule.
- Azure Test Plans lets several suites refer to one test case without copying it.
- Xray separates design entities (Test, Precondition), organisation (Test Set) and planning/execution (Test Plan,
  Test Execution).

Sources: [ISTQB glossary — test scenario](https://istqb-glossary.page/test-scenario/) (an unofficial plain-language
mirror of the ISTQB glossary); [IEEE 29119-3](https://standards.ieee.org/ieee/29119-3/7499/);
[Azure Test Plans objects](https://learn.microsoft.com/en-us/azure/devops/test/test-objects-overview?view=azure-devops);
[Azure requirement-based suites](https://learn.microsoft.com/en-us/azure/devops/test/create-test-suites?view=azure-devops);
[Xray Test Sets vs Test Plans](https://getxraydocs.atlassian.net/wiki/spaces/XRAY/pages/301474179);
[TestRail references](https://support.testrail.com/hc/en-us/articles/7747333895700-Introduction-to-reference-and-defect-integrations);
[Azure Test Impact Analysis](https://docs.microsoft.com/en-us/azure/devops/pipelines/test/test-impact-analysis).

## 4. Options considered

### 4.1 Where the stage sits (presented 2026-10-26)

| Option | Shape | For | Against |
|---|---|---|---|
| A | After Technical Design, before Breakdown; the breakdown assigns cases to stories | Tests shape stories early (shift-left) | Breakdown gains a 4th prerequisite; the shipped breakdown workflow + Finalize change; backlog ids are reassigned per run, so pre-finalize links don't last |
| **B** | After Feature Breakdown is completed and stories are finalized | Links to stable `GNS_` ids; Gherkin acceptance criteria are the test basis; scenarios span finished stories; no shipped workflow changes | Test design starts later |
| C | Parallel with Breakdown after Technical Design, plus a linking step at Finalize | Some of both | Story↔test mapping becomes another agent step and another place for links to go stale |

## 5. Decisions (locked with the user)

| # | Decision | Reason |
|---|---|---|
| D1 | **Option B.** The Test Design stage starts only after the Feature Breakdown stage is completed **and** the feature's stories are finalized. It links test cases to finalized `GNS_` stories. The breakdown workflow and Finalize Stories are unchanged. Untestable acceptance criteria found during test design are reported as Open Questions / suggested story edits (keeps part of the shift-left benefit). | User accepted the recommendation (2026-10-26): stable story ids, acceptance criteria as test basis, no change to shipped stages. |
| D2 | **Reusable test cases.** A test case is owned by its feature's test suite; a test scenario is an **ordered list of references** to that suite's cases, so one case can appear in several scenarios (no copies). Reuse is limited to cases of the same suite; cross-feature sharing is deferred to the later regression-suite work. A case still used by a scenario cannot be deleted. | User chose option B (2026-10-26): matches ISTQB "test procedure = test cases in execution order" and Azure Test Plans case reuse; lets part 2 write one script per case and compose scenario scripts; impact analysis finds one case and lists every scenario using it. |
| — | Default (assistant, not yet confirmed): **one test suite per feature**; app-wide regression suites are later work. | Stated to the user 2026-10-26 with an invitation to object. |
| D3 | **Test case fields:** ID · **title** (the one-sentence check) · **Given / When / Then** (preconditions, action, expected result — Gherkin, the same style as story acceptance criteria) · **type** ∈ positive, negative, boundary, end-to-end · **priority** ∈ high, medium, low · **automation status** (only `not-automated` this phase; part 2 updates it). No test steps, test data or scripts this phase. | User accepted the recommendation (2026-10-26): ISTQB / ISO 29119 define a test case with preconditions and an expected result; the expected result is the oracle a part-2 script generator needs; Gherkin is directly scriptable by BDD tools; type shows coverage mix; priority orders re-runs. |
| D4 | **IDs:** test case `TC-000001`, test scenario `TS-000001` (6 digits, hyphen). Each is a global, monotonic counter in `kb_sequences` (new rows, no new table), allocated inside the write transaction at test-design finalize and at manual create; never reused after delete; never renumbered on reorder. The test suite has no ID of its own (1:1 with the feature; added later with app-wide regression suites). | User chose `TC-` / `TS-` over `GNTC_` / `GNTS_` (2026-10-26) — avoids the `GNTS_` vs `GNS_` look-alike; same allocation pattern as ADR-072. |
| D5 | **Test ↔ object links point at object identity, not the wiki table.** A link stores `(app_uuid, object_uuid)` (the Object Wiki's own key) + the object's name and type at link time. It joins to `kb_objects` (every object: catalog, dependency graph, `diff_hash` change detection) and to `wiki_object_pages` when a page exists, so an object's wiki page can list the tests covering it. A link to a planned (**NEW**) object stores name + type with no UUID (**unresolved**) until implementation or a KB sync supplies it. No FK to `wiki_object_pages`; no stub wiki pages are created. | User chose option A (2026-10-26): the wiki is sparse (only implemented/pulled objects, §2.3); a wiki FK would leave most objects unlinkable or flood the wiki (and the Hub) with empty pages. Keeps ADR-070's append-only, implementation-authored wiki intact. |
| D6 | **Only test cases store object links.** A scenario's object set = the union of its cases' links; the suite's = the union of all its cases' links — computed on read, never stored. Impact analysis selects cases and rolls up to scenarios and the suite (TC → TS → suite). Objects that matter to a whole flow (e.g. the process model handing off between steps) are covered by that scenario's end-to-end test case. | User chose option A (2026-10-26): one home per fact; a scenario's list can't drift from its cases; impact has one kind of hit. |
| D7 | **Implementation updates links deterministically (safe selection).** When a story's implementation records its changed objects (Object Wiki entries carrying the story's `GNS_` key + UUIDs), a **program** step gives **every** test case linked to that story **every** object the story created/updated: matching unresolved links (name + type) are resolved; the rest are added with origin `implementation`. No agent, no credits. | User chose option A (2026-10-26): a *safe* regression selection — may re-run a few extra cases but never misses one touching a changed object; deterministic and free. Rejected: resolve-only (misses objects the design didn't predict); per-case agent judgement (credits per implementation, silent errors). |
| — | Proposed link lifecycle (assistant, shown to the user 2026-10-26; rows other than D7 not yet confirmed): origins `design` (workflow resolves existing objects via genesis-kb, keeps NEW as unresolved) · `implementation` (D7) · `sync` (KB sync resolves unresolved name+type matches; flags a link **suspect** when the object's `diff_hash` differs from the hash at link time) · `manual` (user edits). | To confirm in the spec defaults. |
| D8 | **Impact analysis follows the dependency graph.** From each changed object, a program walks `kb_dependencies` **inbound** (callers, their callers, …) over current edges; every test case linked to a reached object is **affected**, labelled **direct** (0 hops) or **indirect, N hops**; results order direct first, then by priority. Default depth **2 hops**, adjustable 1–5 on the screen. Reuses the KB reverse-closure logic in program code, **without** the MCP tool's 200-object cap. | User chose option A (2026-10-26; 2-hop default not objected to): catches the "rule X changed, interface Y calls X, cases test Y" regression that direct-only misses; hop labels + depth control keep wide fan-out (e.g. record types) readable. |
| D9 | **Impact screen: application-scoped, computed on demand, three inputs.** Searches every feature's test suite in the app; groups results suite (feature) → scenario → case; nothing stored. Changed objects come from: (1) **picking objects** (KB object search); (2) **a story** (its implemented objects from its Object Wiki entries); (3) **a KB sync** (every object whose `diff_hash` changed in that sync vs the previous one — catches changes made outside Genesis). All three ship this phase. | User chose option A (2026-10-26): source 3 makes the framework guard every change to the app, not only Genesis-made ones. |
| D10 | **Story changes flag linked test cases; they are never auto-rewritten.** Each case↔story link stores a fingerprint of the story's title + acceptance criteria at link time (the ADR-075 suspect pattern). When the story changes, its linked cases show **Needs review** on the case page, the story page and the feature's test view; the user edits the case or marks it reviewed (refreshing the fingerprint). A story with no linked cases (e.g. one created by a change request) shows as **not covered by tests**; the user re-runs Test Design or adds cases by hand. Test cases link to **stories only**; spec coverage is derived case → story → clause (no stored case↔clause link). | User chose option A (2026-10-26): no credits per story edit, no silent test changes, one home per link. Rejected: agent auto-rewrite; no tracking. |
| D11 | **Finalize once + a top-up run.** The stage follows the breakdown pattern: workflow → test-design document (canonical JSON embedded) → completion chat → **Finalize** into `TC-`/`TS-` records. Before Finalize, re-runs replace the draft freely. Finalize is **one-time**: records are never replaced or renumbered afterwards. After Finalize, **Generate tests for uncovered stories** runs the workflow only for stories with no cases and stories the user marked as needing new tests; it receives the existing cases + scenarios (so it can reuse cases, D2, and avoid duplicates) and returns **proposed additions** (new cases, new scenarios, existing cases inserted into scenarios) that the user accepts or rejects one by one. Accepted items get new ids; existing records are never overwritten. | User chose option A (2026-10-26): stable ids for part-2 scripts; uncovered stories (D10) have a guided path. Rejected: manual-only after finalize; re-finalize that replaces everything (breaks ids/scripts). |
| D12 | **Local only this phase; Hub-ready schema.** No Hub contract change, no `collab/service.py` binding. The new tables carry the collab columns the synced tables use (`sync_uuid`, `row_version`, `owner_username`/`team_uuid`, `published_by/at/version`) so Hub sync is a later additive phase with no data migration. Known prerequisite for that phase: `TC-`/`TS-` (like `GNS_`) are per-machine counters and can collide across teammates — the Hub phase must make ids machine-unique (or resolve collisions) before syncing. | User chose option A (2026-10-26): keeps this phase to genesis + genesis-workflows; avoids a frozen-contract change, the Appian build and a two-machine acceptance (L-071, L-085). |
| D13 | **Screens in scope:** (1) the Test Design stage card + workspace (locked until stories are finalized; Start; document review + completion chat; Finalize; the post-finalize top-up with accept/reject); (2) Feature → **Tests** tab (suite tree: ordered scenarios → cases; filters type/priority/needs-review/story; coverage summary: stories with no cases, cases needing review); (3) **test case page**, one canonical page per `TC-` reached from every link (fields + edit, linked stories with Needs review, linked objects with resolved/unresolved/suspect, scenarios using it); (4) **test scenario page** per `TS-` (ordered cases add/remove/reorder, derived object set); (5) story page → Tests section; (6) Object Wiki page → Tests section; (7) Application → **Test Impact** tab (D8/D9). Tables in (2) and (7) get a real-browser width probe (L-090). **Deferred:** the full spec clause ↔ story ↔ test case matrix — to a backlog spec (`specs/backlog/phase-49-follow-ups.md`) together with every other deferred item of this phase. | User accepted (2026-10-26) and asked that the deferred items get a backlog spec. |
| D14 | **Workflow order: cases first, then scenarios.** `test-design-analysis`: (1) a per-epic MAP loop — one agent turn per epic writes the test cases for that epic's stories from their Gherkin acceptance criteria and names each case's objects, resolved via `genesis-kb`; (2) one agent turn over the whole case pool builds the scenarios as ordered case references (+ a few new end-to-end cases where a flow needs them) — mostly ids, so a small emission (L-064); (3) a **program** assemble builds the document + canonical JSON; a grounded critic checks coverage (every Story ≥ 1 case, every acceptance criterion covered, every scenario reference valid); heal in place (ADR-067). Every agent node wears the ADR-011 trio. **Tasks** need no own cases (not front-end testable, ADR-059); coverage shows them as "covered through objects or scenarios", not uncovered. | User chose option A (2026-10-26): one shared case pool makes reuse (D2) natural and avoids the cross-item duplication of per-scenario turns (L-076). |
| D15 | **Test cases and scenarios have a lifecycle; retire instead of delete.** Statuses **Draft → Ready → Retired** (typed, every change through `LifecycleService.transition`, ADR-050). Finalize and accepted top-up additions create **Ready** records; manually added ones start **Draft**. After Finalize, removal = **Retire**: the record stays readable with its links, drops out of impact results and coverage, its id is never reused. Hard delete only for a Draft record no scenario references. Same machine for scenarios. | User chose option A (2026-10-26): part-2 scripts and run history keep their parent; mirrors Azure Test Plans' Design/Ready/Closed and Genesis's never-delete posture (ADR-068 deprecate-not-delete). |
| D16 | **Generic CSV export now; tool-specific layouts later.** `GET …/test-suite/export.csv`: one file per feature, one row per test case — `TC-` id, title, Given/When/Then, type, priority, status, linked `GNS_` stories, the `TS-` scenarios using it with its position in each, linked objects. Built by a program from the records (stdlib `csv`, no new dependency), like the Jira export. Xray / Zephyr Scale / TestRail column mappings → backlog. | User chose option A (2026-10-26). |
| D17 | (after the 49-04 build) **Fix the RunManager terminal-event ordering inside Phase 49** as hardening item **H1** (49-08 §1.1): record the run's status **before** announcing `run.final` to observers, so every finalizer's live path works. Its own genesis commit, built before the 49-08 review, shipped in v0.79.0. | User said yes (2026-10-26). Pre-existing bug (`genesis/genesis/runs/manager.py:137-139`) confirmed by the 49-04 review; the Test Design stage uses the same `StageFinalizer`, so its live finalize is affected too. |
| D18 | (after the 49-07 build) **Feature roll-up status: Draft only when no stage has started.** Completed when every available stage is completed; Draft when no stage has started (all not-started/draft); otherwise In progress. Built as hardening item **H2** (49-08 §1.1) before the 49-08 review. | User chose option A (2026-10-26): with five stages, a feature whose four existing stages are completed showed **Draft** (`web/src/features/features/stages.ts:139-145`); the usual roll-up treats partial completion as in progress. |
| D19 | (after the 49-08 live acceptance, NEEDS_CHANGES) **One fix item H3** covers every 49-08 finding (M1–M3, m1–m4, n1–n4), then a focused re-review + re-acceptance of rows 6, 15, 16 and 18. M3's fix is generic: at app startup, a run left `running` with no durable `run.final` and no worker in this process is finalized **failed** ("worker lost across a server restart") through `RunManager._finalize`, so every reconcile that keys on `run.final` settles. Failed, not paused: a lost run can still be forked from its last checkpoint (ADR-025). | Assistant's recommendation (2026-10-30), consistent with D17/L-058 and the reviewer's suggested fix; the user asked for the next steps. |

## 6. Defaults — ✅ confirmed by the user 2026-10-26 ("accept all")

| # | Default |
|---|---|
| F1 | **Start** like Breakdown: optional notes + up to 3 supporting documents (ADR-035 allowlist), multipart. |
| F2 | **Prerequisite:** the Feature Breakdown is completed **and** the feature's stories are finalized (`kb_features.stories_finalized_at` set — Finalize already requires a completed breakdown). Enforced frontend (locked card) **and** backend (409) (L-063). |
| F3 | **Read-only against Appian:** the workflow uses the `genesis-kb` + `appian-dev` read allowlists; the completion chat writes only inside its sandbox (ADR-031/045). |
| F4 | **Link origins:** `design` · `implementation` (D7) · `sync` · `manual`. |
| F5 | The D7 implementation update is **genesis program code**, run when an implementation run completes **and** once at test-design Finalize (stories implemented earlier); blocking DB work off the event loop (L-026). |
| F6 | After every successful KB sync, unresolved links are resolved by name + type; suspect links are visible from then on. |
| F7 | **Mark reviewed** on a case clears its Needs-review and suspect flags by refreshing the stored story and object fingerprints; in part 2 a passing run may also clear them. |
| F8 | An object with no current `kb_objects` row shows *object removed* on its links and is excluded from impact. |
| F9 | A deleted story removes its case↔story links; a case left with none shows *no linked story*. Test records cascade-delete with their feature (ADR-042). |
| F10 | Ids allocated in document order at Finalize: scenarios, then cases by epic and story. |
| F11 | Names: stage "Test Design", backend key `test_design`; workflow `test-design-analysis`; chat mode `test_design`. |
| F12 | Release: genesis + genesis-workflows only; one migration **m0025** (DB 24 → 25); no genesis-core, SDK or Hub change. |
| F13 | Two new ADRs for genesis-docs: **ADR-078** (Test Design stage + test model: D1–D4, D11, D14–D16) and **ADR-079** (test↔object traceability + impact analysis: D5–D10). |

## 7. Refinements made while writing the spec (assistant; consistent with §5–§6, reported to the user 2026-10-26)

| # | Refinement | Why |
|---|---|---|
| R1 | In the **KB-sync** impact source (D9 source 3), cases linked to an object **removed in that sync** are listed as **direct** hits labelled *object removed* (the general F8 exclusion applies to the other sources). | Removing an object is exactly the change whose tests you want to see; it has no current edges to walk. |
| R2 | *Needs review* (D10), *suspect* (§5 lifecycle) and *object removed* (F8) are **computed on read** from stored fingerprints vs the current story / `kb_objects` row — no stored flag. "Mark reviewed" (F7) rewrites the stored fingerprints. | One home per fact; a flag can't go stale. |
| R3 | **Object resolution is genesis program code at Finalize / top-up apply / KB sync:** the agent proposes `{uuid?, name, type}`; genesis keeps a UUID only if it has a current `kb_objects` row in the app, else tries an exact name + type match, else stores the link **unresolved**. | Workflows can't read genesis.db; deterministic and testable; F6 reuses the same function. |
| R4 | D11's "stories the user marked as needing new tests" = a **story picker in the top-up dialog** (uncovered stories pre-checked; stories with Needs-review cases listed unchecked). No stored marker. | Same user intent without a new table or flag. |
| R5 | After test-design Finalize the stage document is history: **Re-run** returns 409 and **Reopen** is blocked through the existing `downstream_locked` precondition (`transitions.py`). | Records are authoritative after Finalize (as for stories, ADR-060). |
| R6 | New Python modules must **not** be named `test_*.py` / `*_test.py` (pytest would collect them): use `kb/testdesign.py`, `services/testimpact.py`, `api/testdesign.py`. | Avoids accidental test collection. |
| R7 | The D7 / F6 updates are **idempotent** and also run in a **startup reconcile** sweep (level-triggered, L-058). | A missed terminal event must not leave links stale. |
| R8 | (after the 49-05 build) The suite, case and impact reads also call `resolve_unresolved(app_uuid)` on demand. KB rows pulled from the Hub get resolved by these reads; no separate pull trigger. | Recovery shouldn't depend on a restart (49-05 review m3); one idempotent call covers both the restart gap and Hub pulls (m2). |

## Context manifest

```toml
areas    = ["features-stages", "stories-workbench", "kb-sync", "workflows-library"]
adrs     = ["ADR-056", "ADR-058", "ADR-059", "ADR-060", "ADR-064", "ADR-070", "ADR-072", "ADR-075"]
lessons  = ["L-076"]
code     = ["genesis/genesis/kb/stages.py", "genesis/genesis/kb/stories.py", "genesis/genesis/kb/object_wiki.py", "genesis/genesis/kb/_graph_reads_mixin.py", "genesis/genesis/api/features.py", "genesis/genesis/chat/stage_finalizer.py"]
docs     = ["tracker:specs/phase-31-feature-breakdown-stage.md", "tracker:specs/phase-46-spec-change-requests/46-01-findings.md"]
```
