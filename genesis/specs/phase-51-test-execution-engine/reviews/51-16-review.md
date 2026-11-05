# Review 51-16 — base genesis 521910b, genesis-workflows daf3612 (genesis-review, 2026-11-05)

Sub-spec: `51-16-record-as-data-setup.md` ("A recording can also produce a data setup"); decisions 51-01 D8.6, D13,
D27, D28, D33, D34. Commits reviewed (all resolve): genesis **8dd7b6b** (source, tests, contract fixtures) +
**f80dde1** (`web/static` only); genesis-workflows **9970714** (action-capture 0.2.0, skill
genesis-test-authoring 0.2.0, registry entries, tests + scan-refs fixture). No push, no tag. Read: both diffs
(`git diff 521910b 8dd7b6b -- genesis/ tests/ web/src`, `git diff daf3612 9970714`), the spec, 51-01 D8/D13/D27/D28/
D33/D34, and the surrounding code (`library_service.create_many`, `promote_proven_actions`, `_check_code`,
`RunManager._meta`).

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/ruff check genesis` | All checks passed |
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1742 passed** in 679.84 s |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (17), reliability lint and internal-pin self-tests OK |
| genesis-workflows `ci/validate_skills.py` | SKILLS VALIDATION PASSED (4) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **385 passed** |
| genesis-workflows `ruff check workflows/action-capture ci` | All checks passed |
| web `tsc --noEmit` | clean |
| web `npm run lint` | 0 errors, 20 warnings (same count as the brief's base) |
| web `vitest run` | **707 passed** (61 files) |
| stale bundle: `vite build --outDir /tmp/51-16-static` then `diff -r … web/static` | identical (exit 0) |
| genesis `git status --short --untracked-files=all` | empty |

## Spec conformance (§2–§6)

- **§2 m0028:** `m0028_capture_request.py:17-24` adds `request_json TEXT` behind a `PRAGMA table_info` guard;
  registered last in `migrations/__init__.py:38`. Tests `test_m0028_fresh_db_reaches_v28_with_the_request_column`
  (also re-runs `_up`, checks the L-092 names) and `test_m0028_upgrades_a_populated_v27_db_with_every_capture_intact`.
  OK.
- **§3 dialog/API:** `RecordDialog.tsx` checkbox, two required fields, Start disabled until both are filled;
  `RecordingBody.setup` (`api/testing.py:520-522`); `setup_request()` validation (`recording.py`, 400s);
  `_analyse` passes `setup_request` only when asked (`recording.py:379`). The bar and the capture card show
  "+ data setup “name”". Fixtures `recording.json`, `capture-setup.json`, `error-dependency.json` were recorded from
  real responses in `test_every_phase_51_route_answers_without_a_secret`. OK, except that the 51-10 contract table
  is not updated (m-3).
- **§4 action-capture 0.2.0:** input `setup_request`; `_setup_rules` (one setup, `match: new`, the requested name,
  `uses` = action proposals in order); `setup_code_problems` on the workspace's own scanner output (export default,
  role, no inputs, literal outputs equal to `contract.outputs`, imports only proposals or library items, actions only,
  `uses` = imports); `replay_plan` runs the setup alone and covers its `uses` (`via`); the heal prompt names the
  setup. The spec's refusal list is covered: two setups (`(got 2)`), an unknown import
  (`setups/unknown-import.ts`, and in a graph run that ends at the gate after 3 retries), inputs on a setup (both the
  contract and the code), wrong role (both the proposal and the code). `workflow.yaml` mirrors META and validate_library
  passes. OK.
- **§5 apply:** actions are sorted before setups (`proposals.py:149`), so the test gets `ACT-000002` before
  `DS-000001`. The actions' real paths go into the imports (`proposals.py:171`), and the test checks the 60-character
  slug cut. The dependency refusal comes before anything is stored (`proposals.py:124`, `:141`). The panel shows
  `uses`/`outputs`/`replay passed in P3`, and Accept is disabled with `aria-describedby`. OK.
- **§6 tests:** the spec's list is covered (see the test names above, plus
  `test_the_setup_is_created_after_its_actions_with_their_real_paths_and_proves_them`,
  `test_a_setup_cannot_be_accepted_without_an_action_it_uses`, `test_the_graph_makes_a_setup_replays_it_alone_and_heals_an_action_it_calls`,
  and the web tests with jest-axe on the ticked dialog and the blocked panel). `promote_proven_actions` is reused
  as 51-15 asked. The node tests use the recorded `create-evaluation.trace.json`.

## Decisions under judgement

- **(a) The 0.2.0 version gate at Record: agree.** `RunManager._meta` reads the yaml only (`runs/manager.py:111-113`,
  ADR-012), and the schema allows extra keys, so without the gate an older workflow would drop the request with no
  message. This is the L-053 skew pattern. The version is a named constant `SETUP_WORKFLOW_VERSION` (L-099).
  `test_a_setup_request_needs_action_capture_0_2_0` covers it, including "a plain recording still works". The gate runs
  at Start only (n-1).
- **(b) Proving a reused action only when its hash matches: agree.** The replay ran the checkout's file
  (`graph.py:873-876`), and `promote_proven_actions` only checks that the file at the commit equals the current code.
  It cannot see a save made between Stop and apply, so the extra `replay.code_sha256` check is needed.
  `test_a_reused_action_saved_since_the_replay_is_not_proven_by_it` covers it. The check fails safe: a CRLF file would
  hash differently through `read_text` and stay Draft. See m-2 for the setup's own Ready in the same case.
- **(c) A rejected reuse never blocks the setup: agree.** Rejecting a reuse writes nothing, and the library file the
  setup imports exists either way. Server (`dependency_problems`) and web (`setupBlockedBy`) apply the same rule, and
  both have tests.
- **(d) The replay runs only the setup: agree.** This follows D28 (actions are proven in use, never replayed alone), and
  a setup run is a stronger check than the loose sequence. New and updated actions take the setup's step result at
  their own code hash, so `_replayed_at_code` makes them Ready on apply (`proposals.py:200`). This is D28's
  recording clause.
- **(e) `uses` must equal ALL action proposals in recorded order: agree.** It matches the spec text ("calls the
  recording's actions … in recorded order"), and with (d) it is required: an action left out of `uses` would never be
  replayed. The code check only compares the import set (`graph.py:400`), not the call order (n-2).
- **(f) Reading the setup with the workspace's scanner instead of regexes: agree.** `lib/scan-refs.mjs` has shipped in
  every workspace since 51-07 (`bb577c4`, synced by `sync_lib`). Genesis's save check reads the same output
  (`library_service.py:378-404`), so v_segment and apply agree, and
  `test_action_capture_reads_a_recorded_setup_with_this_workspaces_scanner_as_the_save_does` shows it with the real
  scanner. Refusing when the scanner is missing is the right fail-closed choice. It does change the behaviour without a
  request, though (m-1).

## Checklist

### ADRs
- [OK] ADR-001 — LangGraph owns control flow: `replay_plan` is a pure function, and the setup-vs-sequence choice is program code (`graph.py` `_replay_sync`).
- [N/A] ADR-003 — no distribution change.
- [N/A] ADR-005 — no MCP/CLI registry change (`required_mcp: []`).
- [OK] ADR-006 — action-capture stays one folder (`workflow.yaml` + `graph.py`); `registry.json` is 0.2.0.
- [N/A] ADR-007 — roles unchanged.
- [OK] ADR-010 — state holds pointers only; the request is two short strings bounded at 120/2000 characters (`recording.py` `SETUP_NAME_MAX`/`SETUP_END_STATE_MAX`); proposals and the scan output go to blackboard files.
- [OK] ADR-011 — `segment` keeps `v_segment` + retry + escalation (the graph test ends at the gate after `retries["segment"] == 3`); the reliability lint passes in validate_library.
- [OK] ADR-012 — the app reads META through the yaml loader (`manager.py:113`), never the graph; `graph.py` imports nothing from the platform. The genesis test that loads `graph.py` with importlib is test-only.
- [N/A] ADR-014 / ADR-015 / ADR-016 / ADR-017 — no scaffolder, build-order, naming or language change.
- [OK] ADR-018 — the scan document and replay results are files in the run folder; state holds pointers.
- [OK] ADR-019 — `CORE_MAJOR` unchanged; additive input; validate_library compat passes.
- [N/A] ADR-020 / ADR-029 — no Kiro config or registry change.
- [OK] ADR-021 — no new gate. The QA replay writes data under the D8/D22 blanket approval, as in 0.1.0; no MCP write node is added.
- [OK] ADR-022 — artifacts stay under the run folder (`$GENESIS_ARTIFACTS_DIR`).
- [OK] ADR-023 — the route sits on the existing FastAPI router.
- [OK] ADR-024 — the migration is plain SQLite DDL in `genesis/db/`; the engine is unchanged.
- [OK] ADR-026 — no new network surface; no auth added.
- [OK] ADR-027 / ADR-055 — the web code uses the existing primitives (`Field`, `Input`, `Textarea`, `Badge`, `Button`) and tokens (`text-fg-muted`, `text-warning`, `border-border`); no raw palette colours, no new dependency.
- [OK] ADR-028 / L-010 — the client calls `testing(appUuid)/recordings` through `testingApi`; no `/api` literal in components.
- [OK] ADR-030 — SQLite; the `CaptureStore.create(request=)` signature is DB-agnostic.
- [N/A] ADR-031 / ADR-033 / ADR-034 / ADR-045 — chat is untouched. The skill change is a workflow-provisioned skill (ADR-069), not chat.
- [N/A] ADR-035 — no file inputs.
- [N/A] ADR-036 / ADR-037 / ADR-041 / ADR-042 / ADR-047 / ADR-054 / ADR-060 / ADR-063 / ADR-065 / ADR-070 / ADR-071 / ADR-072 / ADR-073 / ADR-074 / ADR-075 / ADR-076 — not touched (listed only through the `db`/`api` area or chain).
- [N/A] ADR-038 / ADR-039 / ADR-048 / ADR-056 / ADR-057 / ADR-058 / ADR-059 / ADR-061 / ADR-062 / ADR-078 — no Appian MCP, KB, credential or feature-stage workflow change.
- [N/A] ADR-043 — no Lavish change.
- [N/A] ADR-046 / ADR-080 — no install or packaging change; no internal dependency entries added.
- [OK] ADR-050 — status changes go through `lifecycle.transition` (`proposals.py` on_commit; `promote_proven_actions` with `actor=execution_key`).
- [OK] ADR-067 — healing is unchanged and bounded (≤ 1 patch, ≤ 1 restart, `HEAL_TIMEOUT_S` 900 s). The graph test heals P2 inside the setup's step.
- [N/A] ADR-068 — no Implementation-lane or design-object write.
- [OK] ADR-069 — `segment`/`heal` declare `skills=SKILLS` (`graph.py:940-942`); the skill is 0.2.0 in `skills-registry.json` and the frontmatter.
- [OK] ADR-077 — review run without `--trust-all-tools`; context through genesis-ctx.

### Lessons
- [N/A] L-003 / L-018 — no SSE change.
- [OK] L-004 — the request is stored in SQLite (`request_json`), not in a JSON file.
- [OK] L-006 / L-013 — the topology is unchanged; the yaml parity lint passes.
- [OK] L-009 — async graph runs through the harness; nothing uses sync `SqliteSaver`.
- [OK] L-011 / L-083 — `Capture.request`, `CaptureApplyResult.proven` and `items[].uses` are mirrored in `types/testing.ts` and checked by `contract.test.ts` (`Exact<>` key sets plus the `capture-setup` / `error-dependency` checks). The fixtures were recorded from real responses, and the scan fixture is real `scan-refs.mjs` output (TypeScript 5.9.3).
- [N/A] L-017 / L-045 — chat trust untouched.
- [N/A] L-019 — no secret writes.
- [OK] L-020 — no new loop; retries keyed by node name (`retries["segment"]`).
- [OK] L-021 / L-042 — the scan output goes to a file and the validator reads it; the prompt gives paths, not bulk.
- [OK] L-022 — no custom-reducer keys (module docstring, unchanged).
- [OK] L-023 — the scan JSON is parsed defensively (`scan_refs` type checks; `setup_code_problems` `isinstance` guards).
- [N/A] L-024 / L-029 / L-031 / L-048 / L-049 / L-051 / L-068 / L-087 / L-088 / L-100 — not touched.
- [OK] L-025 / L-027 — the ruff pin is unchanged; ruff clean in both CI scopes.
- [OK] L-026 — no `genesis.db` writes inside a graph node; the app-side writes run in request handlers and services.
- [N/A] L-030 / L-056 / L-057 — release-time; no tag. (The bundle commit holds only `web/static`.)
- [OK] L-033 — a missing action-capture still refuses at Start (unchanged path, `recording.py`); the new version check sits in the same `else` branch.
- [OK] L-039 — `_dto` adds `request` for both `get` and `list` (`testexec_store.py:1398`).
- [OK] L-053 — the version gate is the skew guard (decision a).
- [OK] L-064 — the setup is one small file per turn; no large multi-part single turn.
- [OK] L-075 — heal patches in place inside the setup run.
- [OK] L-076 — the setup is written in the same `segment` turn as the actions it calls, with no per-item fan-out.
- [OK] L-089 — the bundle commit is separate; the reviewer's rebuild is identical and `git status` is empty, each run as its own call.
- [OK] L-091 — `decide` checks, then makes a CAS write (`set_decisions(expected_row_version=)`). `apply` checks before `decide`, and the CAS write re-validates against the stored row.
- [OK] L-092 — `m0028_capture_request` / `capture_request` do not start with `test_` (asserted in the test); no new `tests/__init__.py`.
- [OK] L-096 — no new route; existing paths.
- [OK] L-098 / L-099 — no library-presence change; the version behaviour uses its own constant.

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` — 1742 passed (api and db areas).
- [OK] `cd genesis && .venv/bin/ruff check genesis` — clean.
- [OK] `cd genesis-workflows && ../genesis/.venv/bin/python ci/validate_library.py` — PASSED (17).
- [OK] `cd genesis-workflows && ../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures` — 385 passed.
- [OK] web tsc / eslint / vitest / stale-bundle — see the table above.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m-1 — "Without the input, everything is exactly as in 0.1.0" is not quite true.** `graph.py:824-832` scans every
  new or updated setup proposal, not only the requested one. A plain recording whose agent proposes a free setup
  (allowed in 0.1.0) now needs `node` and `lib/scan-refs.mjs` and must pass `setup_code_problems` (export default,
  literal role, no inputs, literal outputs = `contract.outputs`, known imports). The rules match Genesis's save check
  (`library_service.py:378-404`), so the refusal only arrives earlier, and that is a reasonable change. But the module
  docstring (`graph.py:38`), the registry summary and the brief all describe it as unchanged, and no graph-level test
  runs a no-request recording with a free setup through `v_segment`
  (`test_without_a_request_no_setup_is_required_and_a_free_one_has_no_uses_rules` calls the functions only). Fix:
  reword the docstring ("…except that every proposed setup is now read with the workspace's scanner"), record the
  change in the As built, and add one graph test for a free setup without a request.
- **m-2 — A setup still becomes Ready when the reused action it ran has changed since.** When the (b) guard finds a
  stale reused action, the actions stay Draft, but the setup itself is approved (`proposals.py:200`;
  `test_a_reused_action_saved_since_the_replay_is_not_proven_by_it` asserts `P3 == "ready"`). The setup has never
  passed with the action code it now calls. This matches D20 as written (the setup's own hash), so it is not a
  violation, but the guard's reason applies equally to the setup. Fix: either apply the same staleness check to the
  setup's own approval (keep it Draft and log it), or record in the As built that this is accepted under D20, so that
  51-12 step 26 does not read it as a bug.
- **m-3 — The 51-10 contract table is not updated.** Spec §3 says the `setup` body field belongs in the "51-10
  contract table + a fixture". The fixture exists. The table row
  (`51-10-…md`, "POST `/applications/{app}/testing/recordings`") still lists only `role, intent, start_path`, and the
  decisions/apply rows do not mention the dependency 409 or `proven`/`items[].uses`. Fix: update the row in the As
  built or the docs write-back.

### Nits
- **n-1** — The version gate runs at Start only. If action-capture is downgraded between Start and Stop, `_analyse`
  (`recording.py:379`) passes the request to a workflow that ignores it. Re-check `_version(meta)` in `_analyse` and
  fail the capture with the reason, or accept the gap and say so.
- **n-2** — `setup_code_problems` compares the import set with `uses` (`graph.py:400`); the scanner reports imports
  sorted, so the code's call order is never checked, only the `uses` list order. The replay catches functional
  mistakes. Mention it in the skill or the As built.
- **n-3** — In the proposals panel, rejecting a used action while the setup is already accepted is not prevented
  in the UI; the server answers 409 and the message appears in place (covered by the web test "the server's
  dependency refusal (409) is shown in place"). That is acceptable. A short hint on the action's Reject would avoid
  the round trip.
- **n-4** — `test_action_capture_reads_a_recorded_setup_with_this_workspaces_scanner_as_the_save_does` is skipped when
  the sibling genesis-workflows checkout is missing, as in genesis CI. The scanner parity is therefore only proven
  locally. The workflow repo's real-output fixture covers the other side, so this is fine. Note it in the As built.

## Not verified
- A live Kiro `segment` turn that writes a setup, and a QA replay of the setup (51-12 step 26), as the brief says.
  Headless review cannot drive Kiro or the QA browser.
- The As built section is not written yet (the dev agent writes it after this review).

## Verdict: SHIP

No blockers and no majors, and every gate is green when re-run independently. The six decisions (a)–(f) are sound.
m-1 to m-3 should go into the As built: a docstring fix plus one graph test for m-1, a decision or a guard for m-2,
and the 51-10 table for m-3. They do not need to block 51-17.

## Delta re-review (genesis-review, 2026-11-05)

Scope: the fix commits only. genesis **b4402ca** (on f80dde1; `proposals.py`, `recording.py`,
`tests/test_testexec_recording.py`, no `web/` file: `git diff --stat f80dde1 b4402ca -- web` is empty), genesis-workflows
**f6b9397** (on 9970714; `graph.py` docstring, skill §5, two graph tests), and the uncommitted project-tracker edit to
`51-10-api.md`. Both shas resolve and are HEAD. `genesis-ctx check --since f80dde1 --repo genesis` maps the three files to
no area beyond the always-on release-ci/security; `--since 9970714 --repo genesis-workflows` maps to workflows-library.

### Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/ruff check genesis` | All checks passed |
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1743 passed** in 545 s (1742 + the n-1 test) |
| genesis `pytest tests/test_testexec_recording.py` | 30 passed |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (17); reliability lint and internal-pin self-tests OK |
| genesis-workflows `ci/validate_skills.py` | SKILLS VALIDATION PASSED (4) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **387 passed** (385 + the two m-1 tests) |
| genesis-workflows `ruff check workflows/action-capture ci` | All checks passed |
| `git status --short --untracked-files=all` | empty in both repos |
| web gates / stale bundle | N/A: no web file changed, so the first pass's identical-bundle result still holds |

### The fixes, one by one

- **m-2: resolved.** `_stale_reuses` (`proposals.py:244-256`) is the guard that used to be inline in
  `_prove_used_actions`, unchanged: a reused action is stale when its library item is gone, the replay recorded no
  `code_sha256`, or the hashes differ (fail safe). `on_commit` now calls it for every written item
  (`proposals.py:203-207`). For anything but a setup it returns `[]` (`setup_uses`, `proposals.py:50-52`), so actions
  are unaffected. A stale setup skips `record_replay` and `approve`, stays Draft, and is logged. `_prove_used_actions`
  uses the same helper (`:275`), so the two decisions cannot drift. `by_id` covers all proposals, including rejected
  reuses (`:191`). A rejected reuse that changed since the replay therefore also keeps the setup Draft, which is the
  safe reading of decision (c). The regression test `test_a_reused_action_saved_since_the_replay_is_not_proven_by_it`
  (`tests/test_testexec_recording.py:776-785`) asserts P3 Draft, P2 Ready, no `passed` `last_replay` on the setup and
  `proven == []`. It would fail on f80dde1, where the old assertion was `P3 == "ready"`. The positive path is still
  pinned by `test_the_setup_is_created_after_its_actions_with_their_real_paths_and_proves_them` (`:767`, P3/P2 Ready,
  `proven == [reused]`).
- **n-1: resolved, with one gap (dm-1).** `_analyse` re-reads META when the capture has a setup request
  (`recording.py:378-388`) and fails the capture with the reason when the workflow is older than
  `SETUP_WORKFLOW_VERSION`. It uses the same named constant as Start (`:76`, `:203`; L-099). The test
  `test_a_downgrade_between_start_and_stop_fails_the_capture_with_the_reason` (`:672-679`) asserts status `failed`,
  the "older than 0.2.0" reason, and that no run started. A plain recording's path is unchanged (`if wanted:`).
- **m-1: resolved.** The docstring (`graph.py:37-42`) now states the one change without a request: every proposed new
  or updated setup is read with the scanner and must pass `setup_code_problems`, so it is refused earlier, not
  differently. Two graph-level tests run a no-request recording end to end:
  `test_without_a_request_a_free_setup_is_read_by_the_scanner_and_replayed_in_sequence` (v_segment ok, no "ALSO make
  ONE data setup" prompt, replay mode `sequence` over P1–P3 in recorded order, no `via`) and
  `test_without_a_request_a_free_setup_with_inputs_is_refused_by_v_segment` (`retries["segment"] == 3`, the "outputs
  only — remove inputs" message). In both, the scanner is the `node` stub replaying a recorded real scan
  (`NODE_STUB`, `scan-refs-0.1.json`). That is the same seam as the first-pass tests, and real-scanner parity is still
  n-4. The registry `summary` was not reworded. The docstring and the As built are the record, which is enough.
- **n-2: resolved.** The skill §5 (`SKILL.md:185-188`) and the docstring (`graph.py:41-42`) say the imports are checked
  against `uses` as a set and that the call order is proven only by the replay.
- **m-3: resolved.** The `51-10-api.md` rows for POST `…/recordings` and decisions/apply now list `setup?: {name,
  end_state}`, `request` (m0028), the ≥ 0.2.0 409 problem, the 400s for a setup without a name or end state, the
  downgrade-at-Stop failure, `items[].uses`, `proven`, and the dependency 409. The edit matches the code
  (`recording.py:203-206`, `:384-387`; `proposals.py:236-238`). It is uncommitted; the dev agent commits it with the As
  built.
- **n-3 / n-4:** accepted as is, to be recorded in the As built. Agreed.

### Checklist (delta)

- [OK] ADR-011: no agent node changed. `segment` keeps validator + retry + escalation (the refusal test ends after 3
  retries); the reliability lint passes in validate_library.
- [OK] ADR-001 / ADR-012 / ADR-018 / ADR-010: `graph.py` changes only its docstring. The app still reads META through the
  yaml loader (`RunManager._meta`, `manager.py:111-113`), never the graph.
- [OK] ADR-019: `_meta` keeps calling `check_compat` first (`manager.py:112`). See dm-1 for how its error is handled.
- [OK] ADR-050: the setup's approval still goes through `lifecycle.transition`; the fix only skips it.
- [OK] ADR-069: the skill text changed with no version change. The edit is guidance wording, and `validate_skills`
  passes.
- [N/A] ADR-003/005/006/007/014/015/017/020/021/022/026/029/030/031/033/034/035/036/037/038/039/041/045/046/048/056/057/
  058/059/061/062/063/065/067/068/073/074/075/076/078/080: nothing in the delta touches these.
- [OK] ADR-077: review run through genesis-ctx, without `--trust-all-tools`.
- [OK] L-053 / L-099: the skew guard is now checked at both ends with one named constant.
- [OK] L-083 / L-011: the tests use the real shapes (recorded scan entries, the real `create-evaluation.trace.json`,
  real `content_hash` values from the library).
- [OK] L-020: retries keyed by the node name `segment`.
- [OK] L-025 / L-027: ruff pin unchanged; clean in both scopes.
- [OK] L-089: the gates and `git status` were each run as separate calls.
- [OK] L-092: the new test functions are real tests; no `tests/__init__.py` added.
- [N/A] L-006/009/013/017/021/022/023/024/026/029/030/033/042/045/049/051/056/057/064/075/076/087/088/098/100: no
  topology, async, chat, MCP, release or install change in the delta.

### Findings (delta)

#### Blockers
None.

#### Majors
None.

#### Minors
- **dm-1: a compat or YAML error in the new Stop re-check leaves the capture "recording".** `recording.py:380-383`
  catches only `FileNotFoundError` around `self._rm._meta(WORKFLOW_ID)`. `_meta` first calls `loader.check_compat()`,
  which raises `CompatError` on a library major mismatch (`dist/loader.py:41-50`). `meta_of` raises `yaml.YAMLError`
  on an unreadable `workflow.yaml` (`:57-59`). Before b4402ca, both surfaced inside `self._rm.start` under the
  `except Exception` at `:389-391`, whose comment says "the capture must not stay 'recording' forever", and the capture
  failed with the reason. Now, on the setup path only, the exception escapes `_analyse` and `_stop` after the recorder
  has already been stopped and reaped. The capture stays `recording`, and every refresh repeats the failure. The person
  can still Discard it (discard is allowed while recording), so this is recoverable and narrow: the library must
  change between Start and Stop. Fix: catch `Exception` (`# noqa: BLE001`) around the version read and `_fail` with
  the error text, or do the version check inside the existing `try`. Add a test where the fake `_meta` raises a
  non-`FileNotFoundError` after Start.

#### Nits
- **dn-1:** when action-capture is uninstalled between Start and Stop, `FileNotFoundError` becomes `(0,)`
  (`recording.py:382-383`), and the reason reads "older than 0.2.0 … update it". A plain recording in the same state
  fails with "could not start: …". Saying "is not installed" for that case would be more accurate.

### Not verified (delta)
- No live Kiro `segment` turn or QA replay; this is unchanged from the first pass (51-12 step 26).

### Delta verdict: SHIP

All of m-1, m-2, m-3, n-1 and n-2 are fixed. Each code fix has a regression test that would fail on the base, and every
gate is green when re-run independently (genesis 1743, genesis-workflows 387 / 17 / 4, ruff clean). dm-1 is a narrow,
recoverable edge introduced by the n-1 fix. It should be fixed or recorded in the As built, but it does not block 51-17.

## Dev note after the delta re-review (genesis-dev, 2026-11-05)

dm-1 and dn-1 fixed in genesis **4f6f283**: `RecordingService._analyse` (`recording.py`) now fails the capture with
the reason on any error reading action-capture's META at Stop (`FileNotFoundError` → "is not installed — install it,
then record again"; any other error, e.g. a `CompatError` or a YAML error → "could not be read: …", `# noqa: BLE001`).
Test `test_a_workflow_that_cannot_be_read_at_stop_fails_the_capture` (both cases) fails on b4402ca (2 failed, run with
the fix stashed) and passes with it. Full genesis pytest **1745 passed**; ruff clean; `git status` empty. Backend only,
no web change. Not re-reviewed: the change is the reviewer's own suggested fix, confined to the n-1 block.
