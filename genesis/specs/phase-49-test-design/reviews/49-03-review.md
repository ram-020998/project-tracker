# Review 49-03 — base a19153a (genesis-review, 2026-10-26)

Scope: genesis-workflows working tree vs `a19153a` (HEAD, resolved with `git rev-parse --short HEAD` → `a19153a`).
The change is uncommitted: modified `registry.json` (+17 lines) and the untracked `workflows/test-design-analysis/{__init__.py,
graph.py (1692 lines), workflow.yaml, tests/test_workflow.py (716 lines)}`. `git status --untracked-files=all` lists exactly
those 5 paths (`__pycache__/` is gitignored). No other repo changed. Live acceptance is N/A (genesis launches the workflow
from 49-04 on). Spec: `specs/phase-49-test-design/49-03-workflow.md`, decisions 49-01 D11/D14.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures` | **314 passed** in 6.16 s |
| `../genesis/.venv/bin/python -m pytest -q workflows/test-design-analysis` | **58 passed** |
| `../genesis/.venv/bin/python ci/validate_library.py` | **LIBRARY VALIDATION PASSED (14 workflow(s))**; the reliability lint fails the non-compliant fixture, as it should |
| `ruff check workflows/test-design-analysis` (ruff 0.15.20) | All checks passed |

## Checklist

### ADRs
- [OK] ADR-001 — control flow is LangGraph. The epic loop, routing and healing ladder are program nodes or conditional edges (`graph.py` `build()`, `_route_epics`); agents only write JSON artifacts.
- [N/A] ADR-003 — a library workflow; no change to the app or distribution model.
- [OK] ADR-005 — no new MCP server. It uses the curated `genesis-kb` and `appian-dev` entries in `mcp-registry.json`.
- [OK] ADR-006 — a self-contained folder (`workflow.yaml` + `graph.py`) plus a `registry.json` entry; `test_registry_entry_matches_meta` pins the entry to META.
- [OK] ADR-007 — roles `[developer, tester, product-owner]` are tags only. `tester` already exists in the catalog.
- [OK] ADR-010 — state adds only `epics`, `epic_queue` and `current_epic`, which are small epic descriptors (`TDState`). Cases, scenarios and the suite live in blackboard docs.
- [OK] ADR-011 — every agent node wears the trio. `design_cases` and `compose_scenarios` use `attach_reliability` with `on_exhaust_gate="escalate"`; `verify` and `heal` are wrapped inside `attach_healing`. `validate_library` (reliability lint) passes.
- [OK] ADR-012 — `graph.py` imports only stdlib, langgraph and genesis_core, so the loader can import it standalone. The tests load it via `importlib.util.spec_from_file_location`.
- [OK] ADR-014 — cloned from the feature-breakdown-analysis shape as §1 instructs.
- [N/A] ADR-015 — no build-order impact.
- [OK] ADR-017 — Python only.
- [OK] ADR-018 — bulk passes by pointer. The agents get file paths (`_context_files`) and the program reads and writes blackboard docs.
- [OK] ADR-019 — imports only existing genesis-core 0.9.8 exports (`read_guidance`, `healing_bounds`, `attach_healing`). The `genesis_core_major` of 1 is unchanged.
- [OK] ADR-020 — MCP is injected per node via `kiro_node(mcp=…)`; there is no global config.
- [OK] ADR-021 — `auto_approve: true` and `hitl_points: [escalate]`. The workflow is read-only (allowlists hold only get/list/search tools: `KB_RO`, `DEV_RO`), so no `pre_mutation` gate is needed.
- [OK] ADR-022 — all outputs are written to `ctx.workspace`, and `_cleanup` keeps the declared artifacts.
- [N/A] ADR-026 — no network surface.
- [OK] ADR-029 — namespaced `@server/tool` allowlists. Every name in `KB_RO` and `DEV_RO` is in the curated server's `tool_allowlist`: checked against `mcp-registry.json`, and `search_bundles` / `get_bundle` exist in `genesis/mcp/kb_server.py:86,92`.
- [N/A] ADR-030 — no persistence change.
- [N/A] ADR-031/033/034/045 — not chat.
- [OK] ADR-035 — `doc1..doc3` have `format: file`. They are read from the blackboard (`_read_upload`), and genesis provisions them under `uploads/` (`genesis/runs/manager.py:46`), which `_cleanup` never touches (it deletes root-level files only).
- [N/A] ADR-036/038/041/048/056/061/063/065/074/076 — chain-only, not touched.
- [OK] ADR-037 — the KB tools exclude `get_object_code`. The only code reads are the critic's live `@appian-dev` get* tools.
- [OK] ADR-039 — n/a in substance (the workflow does not touch the business map). Grounding comes from the local KB + live Dev MCP only.
- [OK] ADR-057/058/059 — consumes the UX/TD/breakdown outputs and does not change those stages. The HTML is Lavish-safe in the same way as the breakdown (CSS checkbox toggle, `<details>`, no JS).
- [N/A] ADR-062 — not a Workbench lane.
- [OK] ADR-067 — `attach_healing(..., restart_target="plan_epics", max_heal/max_restart` from `META.healing`). `test_healing_bounds_come_from_meta` passes. The granular blocks (cases/scenarios) make the patch tier meaningful. See minor m1 for the patch-tier validation gap.
- [OK] ADR-068 — no `delete*` tool and no mutation.
- [N/A] ADR-069 — no skills declared.
- [OK] ADR-073 — no package tools.
- [N/A] ADR-075 — the workflow consumes stories; no clause ids are produced.
- [OK] ADR-077 — review run without trust-all; context via genesis-ctx.

### Lessons
- [OK] L-006 — the `graph:` block's ids equal the compiled node names, and the declared edges equal the real edges. `test_topology_ids_match_graph_and_every_node_is_reachable` asserts both plus reachability.
- [OK] L-009 — async nodes via the genesis_core factories; compiled with `ctx.checkpointer`.
- [OK] L-013 — `graph:` is the only YAML-only key; `test_meta_matches_workflow_yaml` passes and `validate_library` parity is green.
- [OK] L-017 — namespaced allowlists only (`KB_RO`, `DEV_RO`).
- [OK] L-020 — `recursion_limit: 300`. Retries reset per iteration: `_next_epic` and `_advance_epic` send `retries.design_cases=0`, and `_plan_epics` resets `design_cases` and `compose_scenarios` (absolute values; the `_inc_merge` reducer is last-writer, `genesis_core/state.py:20`). See nit n1 on the budget comment.
- [OK] L-021 — the `design_cases` prompt says "save large tool output BY REFERENCE, never paste it". The `heal` prompt does not repeat it (nit n6).
- [OK] L-022 — no `from __future__ import annotations` (docstring note + file header).
- [OK] L-023 — `_coerce_json` tolerates a preamble, and every reader normalizes defensively (`_norm_stories`, `_norm_existing`, `_norm_case`, `_as_lines`).
- [N/A] L-024 — no skills.
- [N/A] L-025/L-027 — genesis-workflows CI does not run ruff (`.gitlab-ci.yml` has only validate + `pytest`); `ruff>=0.6` in `pyproject.toml` is pre-existing.
- [OK] L-026 — no `genesis.db` writes, only blackboard files.
- [N/A] L-029/L-049/L-053 — no credential resolution.
- [N/A] L-030 — no web change.
- [N/A] L-033 — install/release is 49-04/49-09.
- [OK] L-042 — spec/UX/TD/notes/stories go to the agents as blackboard files by absolute path (`_context_files`, `_doc_path`). The agents run with `cwd=ctx.workspace.root` (`genesis_core/nodes/agent.py:291`) and the SDK's default `permission_mode="auto_approve"` (`kiro_agent_sdk/client.py:53`), so file reads are not blocked. This is the first workflow to rely on file reads instead of inlining (the breakdown inlines), so the first live run (49-08) should confirm that agents actually open the files. Check the turn explorer for `fs_read` calls.
- [N/A] L-045, L-051, L-087, L-088, L-089 — not touched.
- [N/A] L-056/L-057 — no release. Reminder for 49-09: the entire folder is **untracked**, so `git add workflows/test-design-analysis` must be in the release commit.
- [OK] L-064 — the scenario turn emits refs only. The document and JSON are assembled by program (`_render`, `_build_document`).
- [OK] L-075 — in-place patch tier over stable `case-N`/`scn-N`/`add-N` refs.
- [OK] L-076 — per-epic fan-out for cases (independent per story AC), with ONE scenario turn over the whole pool for the cross-epic flows. This matches D14 and its stated rationale.
- [OK] L-083 — fixtures use real shapes: `GNS_000123` keys, multi-line Gherkin AC strings, `TC-`/`TS-` keys, a null-uuid NEW object.

### Gates
- [OK] `validate_library.py`: PASSED (14).
- [OK] `pytest -q workflows --ignore=workflows/_fixtures`: 314 passed. See the pre-existing finding P1: 11 of the library's tests never run in this command.

## The author's deliberate decisions

1. **Task-only epics skipped in `plan_epics`; `v_cases` accepts zero cases for them.** Agree; this matches D14 and §6. `test_plan_epics_groups_by_epic_and_skips_task_only` and `test_check_cases_task_only_epic_may_produce_zero_cases` pass. The `v_cases` branch is unreachable in-graph (such epics are never queued), but it is harmless and spec-required.
2. **Program-owned `suite.json` aggregate with run-local refs; heal adds via `new-case-N` and removes via `remove: true`; reassemble drops dangling refs.** Agree with the design. It does leave a validation gap on the heal path; see **m1**.
3. **proposals.json: `case.ref` = `p-N`; dependants name `p-N`; extra keys `metadata`/`openQuestions`/`storySuggestions`.** Agree. This is additive to §4.3, and `test_topup_produces_only_proposals_and_never_re_emits_existing_cases` pins it exactly. Record it in As built so 49-04 reads (or ignores) the extra keys deliberately.
4. **`singleStepReason` folded into `description` as "Single step: …".** Agree. It keeps the §4.2 scenario shape exact, and the test asserts both the shape and the folded text.
5. **Escape every `<` as `\u003c` in the embedded JSON.** Agree. It is strictly safer than the breakdown's `</` → `<\/` (which leaves an opening `<script` from agent text). `json.loads` reads it unchanged, and `test_html_escapes_agent_text_and_script_breakouts` proves there is one `<script` and a lossless title. See n4 for the 49-04 parser handoff.
6. **Bulk context as files, epic stories/AC + pool index + suite + report inline.** Agree (L-042). See the live-check note under L-042.
7. **`heal` gets genesis-kb only; appian-dev only on `verify`.** Agree; this matches §2 ("`@appian-dev/` read tools only for the critic's spot-checks").
8. **`mode` is a string enum with default `design`; `target_story_keys` accepts an array or a JSON-array string.** Agree. `test_inputs_schema_accepts_the_genesis_launch_shapes` and `test_resolve_inputs_topup_needs_existing_and_targets` (string form) pass.
9. **No `tests/__init__.py`.** Agree, and the author's diagnosis is confirmed (see **P1**).
10. **No run-label mechanism; registry name "Test Design Analysis".** Confirmed: `grep -rn "Preparation\|run_label\|RUN_LABEL"` over `genesis/genesis` and `web/src` finds nothing. The spec text is stale; see n2.

## Findings

### Blockers
None.

### Majors
None.

### Minors

- **m1 — The heal patch tier bypasses the case and scenario invariants that `v_cases`/`v_scenarios` enforce, and silently drops unrecognized patch ids.**
  `_apply_patches` (`graph.py` §"Case / scenario normalization") merges the healer's bodies and `_tidy_suite` re-normalizes them. However, `check_suite` checks only ref uniqueness, step resolution and "≥1 case", and the generic `check_heal_decision` (`genesis_core/contracts.py:138`) checks only `mode` and the presence of `id`. A reviewer probe (scratch script against `graph.py`, no code touched) showed:
  - `{"id": "case-1", "gherkin": {"given": [], "when": [], "then": []}}` produces a case with empty when/then, and `check_suite(...).ok == True`. That case would be rendered into `test-design.json`.
  - `{"id": "case-1", "stories": ["GNS_999"]}` produces a case with `stories: []`.
  - `{"id": "case-2", "remove": true}` leaves `scn-1` with a single step and no `singleStepReason`.
  - `{"id": "GNS_000123", …}` (the healer echoing the verify `target_id`, a plausible LLM mistake) returns `applied == 0`. Nothing fails: the unchanged suite is re-verified and the heal budget is spent for nothing.

  Re-verify partly backstops this, but the program-owned contract (§3 `v_cases`: ≥1 when, ≥1 then, ≥1 story) should not depend on an LLM noticing a violation. **Fix:**
  - (a) Pass a workflow `heal_check=` to `attach_healing`; the hook already exists at `genesis_core/nodes/healing.py:85`. It should call `check_heal_decision` and then reject patch ids that don't match `^(new-)?(case|scn|add)-\d+$`. It should also run `_case_problems` on new case bodies and on replacement bodies that carry `gherkin`/`stories`, so the healer self-corrects under the trio.
  - (b) Extend `check_suite` so every case has ≥1 `when`, ≥1 `then` and ≥1 known story, and every scenario has ≥2 steps or a `singleStepReason`. A violation should fail loudly as `assemble` already does. Alternatively, `_tidy_suite` could drop a now-single-step scenario's reason requirement explicitly.
  - (c) Add regression tests for the four probes above.
- **m2 — There is no on-disk golden contract fixture for genesis to share (L-011; 49-04 §8 expects "`stories.json` in the 49-03 §4.1 shape (golden fixture shared with the workflow tests)").** The real-shape fixtures are inline Python (`_stories_doc()`, `_existing_doc()` in `tests/test_workflow.py:71,97`), and the output contracts are asserted only in-test. **Fix:** move the input fixtures and the produced `test-design.json` / `proposals.json` into `tests/fixtures/*.json`. The tests should assert the workflow reads the inputs and reproduces the outputs exactly. 49-04 then vendors the same files, so drift on either side fails a test.

### Nits

- **n1 — The `MAX_EPICS = 25` comment ("2 passes x 25 epics x 4 supersteps stays inside recursion_limit 300") ignores retries and the heal path.**
  - Happy path with one restart at 25 epics ≈ 230 supersteps.
  - Each failed attempt adds 2. Worst case is ≈ 465, and exceeding the limit fails the run with `GraphRecursionError` instead of reaching the escalation gate.
  - In practice the breakdown caps epics at 15 (`feature-breakdown-analysis/graph.py:61,543`), so there are at most 16 groups, which leaves comfortable headroom.

  Either align `MAX_EPICS` to 16 or raise `recursion_limit` (every loop is bounded, so it costs nothing), and correct the comment.
- **n2 — Spec drift: 49-03 §7 says 'run label "Test Design Preparation"', but no run-label mechanism exists (decision 10, confirmed).** The docs agent should amend §7.
- **n3 — `metadata.sources` may gain `"uploaded-docs"` (`_metadata`), which §4.2 does not list.** It is additive; record it in As built so 49-04 doesn't assert an exact list.
- **n4 — Handoff to 49-04.**
  - The block is `<script id="genesis-test-design" type="application/json">` (`id` first, spec-literal). The breakdown parser regex in genesis is `type`-first (`genesis/api/features.py:72`), so the 49-04 regex must match this order or be order-agnostic.
  - `add_step.position` is clamped to ≥1 but has no upper bound, so `apply_topup` should clamp it to `len(steps)+1`.
- **n5 — Binary supporting docs (pdf/png) reach the agents only as a placeholder line with no path (`_read_upload`).** This is the same as the breakdown. Given decision 6, the placeholder could name the blackboard path so an agent can open it.
- **n6 — The `heal` and `compose_scenarios` prompts don't carry the L-021 "save large tool output by reference" line that `design_cases` has.**
- **n7 — No test covers a top-up heal patch on an `add-N` ref, or the `new-add-N` append path.** Only design-mode case/scenario patches are tested.

### Pre-existing / out of scope (not counted against this sub-spec)

- **P1 — `generate-business-map`'s 11 tests never run in the CI full-library command.** This would be a major in its own right. Both `workflows/feature-breakdown-analysis/tests/__init__.py` and `workflows/generate-business-map/tests/__init__.py` exist. Under `--import-mode=importlib` (`pyproject.toml`), both resolve to module `tests.test_workflow`, and the first one collected wins.
  - Evidence: `pytest --collect-only workflows --ignore=workflows/_fixtures` lists 37 ids under `generate-business-map/tests/test_workflow.py`. Their names are **identical** to feature-breakdown's 37 tests, and 0 of gbm's own 11 test names appear.
  - `pytest -q workflows/generate-business-map` alone runs its real 11 tests (11 passed).
  - Net effect: of the 314 collected, 37 are duplicates and 11 real tests are skipped.
  - **Fix (separate item):** delete both `tests/__init__.py` files, as test-design-analysis already does, and add a CI guard that fails on a duplicate test module name. File it as a bd issue.
- **P2 — `attach_healing` (genesis-core) never resets the `verify`/`heal` retry counters across re-verify or restart, so the pass-2 retry budget is what pass 1 left.** Also, after a patch followed by a restart, a pass-2 verify failure still runs a `heal` turn whose decision `heal_route` can only escalate, so that turn's credits are wasted. This affects every `attach_healing` workflow; it is a genesis-core follow-up, not 49-03.

## Verdict: SHIP

No blockers or majors; all gates are green (314 pytest / validate_library 14 / ruff clean). The contracts in §4.2/§4.3 are pinned by exact-shape tests, and the topology, parity, top-up and HTML-safety requirements of §6 are all covered. m1 is cheap and closes the only real hole (the heal path can emit a case the program would otherwise reject), so I recommend landing it with this commit. m2 should land before 49-04 starts. P1 should be filed as its own issue.

---

## Re-review — fixes for m1, m2, n1, n4–n7 (genesis-review, 2026-10-26)

Scope: only the fixes made in response to the findings above. Base is still `a19153a` and the change is still uncommitted.
`registry.json` is modified, and `workflows/test-design-analysis/` is untracked: `graph.py` is now 1774 lines, `tests/test_workflow.py`
795 lines, and `tests/fixtures/` holds 8 JSON files.

### Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `pytest -q workflows/test-design-analysis` | **72 passed** (was 58) |
| `pytest -q workflows --ignore=workflows/_fixtures` | **328 passed**. This matches the author's figure. P1 still applies, so the count still includes the duplicate collection. |
| `ci/validate_library.py` | **LIBRARY VALIDATION PASSED (14 workflow(s) validated)** |
| `ruff check workflows/test-design-analysis` | All checks passed |

### Fix verification

- **m1 — FIXED.**
  - `check_heal` (`graph.py:1661`) runs `check_heal_decision` first. It then rejects ids that fail `_PATCH_ID.fullmatch` (`(new-)?(case|scn|add)-\d+`, line 1658), and existing-style ids that name no current suite item. It runs `_case_problems` on `new-case-*` bodies.
  - It then simulates the patches on a deep copy: `_apply_patches` followed by `_tidy_suite`. It rejects the patch if tidy would drop any case, scenario or add-step, and finally runs `check_suite`.
  - `check_suite` (`graph.py:667`) now enforces: every case has a title, a `when`, a `then` and a known story; every scenario has ≥2 steps or a `singleStepReason`; every case is used by a scenario or an add-step. `_assemble` still raises on a violation (`graph.py:1175-1177`).
  - The wiring is real. `attach_healing(..., heal_check=check_heal)` (`graph.py:1768-1770`) feeds `validator_node(name="v_heal", check_fn=heal_check)` in genesis-core. `heal_check` is present in the pinned **v0.9.8** tag (`git show v0.9.8:genesis_core/nodes/healing.py` lines 85 and 118), so the workflow needs no core bump.
  - All four of my original probes are now parametrized cases in `test_check_heal_rejects_patches_the_validators_would_reject`: empty when/then, the unknown story, the remove leaving one step with no reason, and the `GNS_000123` id. Four more cases cover `case-99`, a bad `type`, an unused new case and a scenario with all steps dangling. `test_check_heal_accepts_a_good_patch_and_a_restart` covers the positive path, the restart and the core shape check. `test_check_suite_enforces_the_case_and_scenario_rules` passes.
- **m2 — FIXED.**
  - The 8 fixture files exist on disk.
  - `_stories_doc()` and `_existing_doc()` now load them, so every existing test shares them.
  - `test_golden_design_output` and `test_golden_topup_output` (`tests/test_workflow.py:418,429`) drive `_resolve_inputs` + `_load_inputs` over the fixture paths (`_launch`). They then assemble from the pool and scenario fixtures and assert exact equality with `test-design.json` and `proposals.json`. The design test also checks that the JSON embedded in the HTML equals the same fixture.
  - 49-04 should vendor `stories.json`, `test-design.json`, `existing.json` and `proposals.json` byte-for-byte.
- **n1 — FIXED.** `MAX_EPICS = 16` (`graph.py:59`), and the comment now matches the breakdown cap (15 epics plus 1 orphan group). `test_resolve_inputs_caps_epics` still passes. See r1 for a small residual.
- **n4 — FIXED.** `_tidy_suite` now applies `pos = min(pos, scn_len.get(scn, 0) + 1)` (`graph.py:544`). Because tidy runs on both the assemble path and the heal path, both are clamped. `test_topup_heal_patches_add_steps` asserts that position 99 becomes 3.
- **n5 — FIXED.** The binary-upload placeholder now reads `attached at {fp}` with the absolute blackboard path (`graph.py:239`). No test was added; that is acceptable for a one-line message change.
- **n6 — FIXED.** The "save large tool output BY REFERENCE, never paste it" line now appears in the design_cases (`graph.py:1350`), compose (1399-1400), verify (1434) and heal (1490) prompts.
- **n7 — FIXED.** `test_topup_heal_patches_add_steps` covers a top-up heal: it moves `add-1`, appends `new-add-1`, removes `add-2`, checks that 3 patches are applied, checks the clamped positions in `proposals.json`, and checks that an add-step pointing at an unknown `TS-` is rejected as "would be dropped".
- **Not fixed, as agreed:** n2 and n3 (spec and As-built notes), P1 and P2. These remain open for the docs agent and as separate issues.

### Residual notes (none blocking)

- **r1 (nit) — the recursion budget at the absolute worst case is about the limit, not comfortably inside it.**
  - My estimate assumes each superstep counts once and `retry_max=2`, i.e. 3 attempts per agent before escalating.
  - One pass where every epic takes all 3 attempts costs about 16 × 8 + 8 = 136 supersteps.
  - Two passes, plus the preamble and the full heal ladder, come to about 300–320.
  - Realistic runs stay well under the limit. Raising `recursion_limit` to 400 costs nothing because every loop is bounded, and it would make the comment's "every validator retry" claim strictly true. This is optional.
- **r2 (nit) — some patches are still sanitized silently instead of rejected.**
  - A replacement patch on an existing `case-N` with `stories: ["GNS_000123", "GNS_999"]` silently loses the unknown key. Only `new-case-*` bodies get `_case_problems`.
  - A scenario patch whose steps are partly dangling (for example `["case-1", "case-404", "case-3"]`) is pruned to its resolvable steps and accepted.
  - In both cases the result is valid, so the program contract holds. However, the healer is not told that part of its patch was discarded.
  - Optional fix: run `_case_problems` on replacement bodies that carry `stories`/`gherkin`, and reject unresolved step refs in `check_heal`.
- **r3 (nit) — `test_build_wires_the_workflow_heal_check` checks the wiring by matching the string `heal_check=check_heal` in `inspect.getsource(td.build)`.**
  - That is brittle to formatting, and it proves the text is present rather than proving the check runs.
  - A sturdier test would invoke the compiled `v_heal` node with a bad `heal.json` and assert that it fails.

### Re-review verdict: **SHIP**

m1 and m2 are closed with regression tests that would have caught the original gaps, and n1 and n4–n7 are addressed. All gates are green: 72 tests for the workflow, 328 for the library, validate_library 14, ruff clean. r1–r3 are optional polish. Reminder for 49-09 (L-056): the whole `workflows/test-design-analysis/` folder, including `tests/fixtures/`, is untracked and must be `git add`-ed in the release commit.
