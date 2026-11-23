# Review 55-05 — base 419d8363, head 5bbae6d3 (genesis-review, 2026-11-23)

What this change does: the worker now forwards LangGraph's `tasks` finish as `task_finish` with the files the task
wrote (a stat snapshot at each task start, diffed at its finish), plus `files_written` for `_launch` and `_memory`
before the graph runs. The manager turns these into one canonical `file.written` per file, stamped with execution,
iteration and attempt. A new `GET /api/runs/{id}/documents` returns one categorized list built from an incremental
fold (`FoldCache`, extracted from `SnapshotCache`) and the folder as it is now. `META.artifacts` gains a
`{name: {role, label}}` map form with one parser shared by the parity lint and the categorizer.

Scope: code review only, no live acceptance (as briefed). Commit resolved: `git rev-parse --short HEAD` = `5bbae6d3`,
one commit on top of `419d8363`, working tree clean. Nothing was run against the fleet. Full pytest ran with
`GENESIS_STATE_DIR=/tmp/rev-55-05/state`, and the tests themselves use `tmp_path`.

## Gates (re-run by the reviewer)

- `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **2263 passed, 4 skipped** in 744.95 s (exit 0).
  This matches the dev's 2255 + 8 failures, now fixed, and confirms the final state that the dev had not re-run in full.
- `.venv/bin/ruff check genesis tests/test_document_records.py` → All checks passed.
- Web: `npx --no-install tsc --noEmit -p .` → exit 0; `npx --no-install vitest run src/test/fixtures/contract.test.ts` →
  12/12 passed. Only `web/src/test/**` changed (`git diff --stat`), so there is no bundle input and `web/static/` is
  correctly untouched. I did not re-run the full web vitest or lint (dev: 963 passed, 0 errors).
- genesis-core: no file under `packages/` changed, so its gate is N/A for this diff.
- Stat cost, measured by the reviewer with `writes.scan` on the largest real folders (20-run mean):
  test-execution `r-93aab6c223e2` takes 3.31 ms for 300 files (271 `report/`, 29 `checkout/`);
  technical-design-analysis `r-4567cd05bcca` takes 0.17 ms with the exclusions (18 files) and 0.87 ms without (295).

## Checklist

### ADRs
- [OK] ADR-001 — the graph is unchanged; only observation was added (`worker.py` tasks branch).
- [OK] ADR-008 — no change to the app/UI bundling.
- [OK] ADR-009 — HITL is untouched. A gate's interrupt finish is forwarded with `files: []` (`test_a_tasks_finish_is_forwarded…`), and pause/resume is covered (`test_a_paused_and_resumed_task…`).
- [OK] ADR-010 — `_task_finish` forwards only `{kind,node,task_id,error,files[,parallel]}`. It never sends `result` or `input`, and `error` is trimmed to 500 characters (`worker.py` `_task_finish`). The test asserts the exact key set (`test_a_tasks_finish_is_forwarded_with_its_files_and_never_its_result_or_input`). The state is unchanged, and each record is pointer-sized: path, bytes, mtime.
- [N/A] ADR-011 — no agent node was added. The reliability lint is unaffected (full pytest green).
- [OK] ADR-012 — the app reads roles and graph from `workflow.yaml` via `loader.meta_of/graph_of` (`manager.documents`). It never imports workflow Python, and the scan runs in the worker.
- [OK] ADR-018 — bulk stays on the blackboard. The events carry stat records only.
- [OK] ADR-019 — the map form is additive and the list form still passes (`test_the_parity_lint_checks_artifact_roles[…list…]`). The dev reports `validate_library` passed; I did not re-run it.
- [N/A] ADR-021 — no gate posture change.
- [OK] ADR-022 — the documents fold reads `artifacts_dir/<workflow>/<run>`, the same root as the file routes (`_artifact_path`).
- [OK] ADR-023, ADR-024 — the async engine is unchanged. The scan is a short synchronous stat walk (about 3 ms for 300 files).
- [OK] ADR-025 — a fork copies only `_memory/` (55-04). The copied brief is categorized from its path (`test_a_forks_copied_brief_is_the_memory_brief_without_an_event`).
- [N/A] ADR-026, ADR-027, ADR-055 — no bind or UI change (test fixtures only).
- [OK] ADR-028 — the new route is `/api/runs/{id}/documents` (`run_routes.py:244`).
- [N/A] ADR-029, ADR-031, ADR-033, ADR-034, ADR-045, ADR-069, ADR-083, ADR-086 — trust and Kiro launch are untouched (`_kiro/`, `.kiro/` excluded from the diff, listed as System only).
- [OK] ADR-030 — no schema change; reuses `run_events`.
- [N/A] ADR-032 — no credit change.
- [OK] ADR-035 — uploads are reported as `_launch` (payload only) and labelled by the input's title (`test_a_run_records_every_write…`, `test_an_upload_is_labelled_by_its_input…`).
- [N/A] ADR-037, 041, 043, 046, 047, 049, 050, 054, 061–065, 068, 071, 073, 074, 076, 081, 082, 084, 085, 087 — areas not touched.
- [OK] ADR-066 — adds per-file who/when beside the existing per-iteration capture, and changes nothing there.
- [N/A] ADR-077 — no agent-system change.
- [OK] ADR-080 — one repo, one commit, no version bump (release is 55-12).

### Lessons
- [OK] L-003, L-018, L-118 — SSE code is untouched. `file.written` goes on the canonical bus via `_log` but is not in `LIVE_KINDS` (`run_routes.py:42`), so the hint stream is unchanged. 55-08/55-09 must decide whether the documents view needs a hint.
- [OK] L-004 — SQLite.
- [OK] L-005 — the kind is canonical, and no `node.started` or `node.failed` semantics were invented.
- [OK] L-008 — the error path is unchanged. A raising node's writes are logged before `error` (`test_a_node_that_raises_still_reports_what_it_wrote`).
- [OK] L-009 — async `astream` with the checkpointer, unchanged.
- [OK] L-010 — `/api` prefix.
- [N/A] L-016, L-017, L-019, L-021 (tool outputs remain by reference; `_toolcalls/` is excluded from the diff), L-023, L-031, L-033, L-044, L-045, L-048, L-050.
- [OK] L-025, L-027 — ruff passes with the pinned version.
- [OK] L-026 — the manager-side stamp read runs on the pump thread, not in an async node. The worker performs no DB write.
- [N/A] L-030, L-051, L-056, L-057, L-087, L-088, L-098–L-101, L-104, L-105, L-112, L-119 — release-time items; nothing is released here.
- [OK] L-039 — `/documents` and `/artifacts` agree on `media_type`/`preview_kind`/`bytes` (`test_the_documents_route_…` compares them).
- [N/A] L-058, L-061, L-062, L-065, L-093, L-097, L-106, L-107, L-108, L-120, L-121 (side ops do not stream tasks, so they emit no `task_finish`), L-124.
- [OK] L-059, L-060 — `/events?node=` is capped at 2000 on the web (`lib/api/runs.ts:39`). The worst real node, test-execution's report step, adds about 271 `file.written` rows, which fits.
- [OK] L-066 — `FoldCache.read` reads only `DOC_KINDS` after the fold's last seq (`test_the_documents_fold_reads_only_its_kinds_after_its_last_seq` with 3000 filler rows). `Stamps` reads `node.started`/`agent.prompt` after its `last_seq` (`manager._log_writes`). Each documents call also re-parses `workflow.yaml` twice and walks the folder; that work does not grow with the log (see nit N2).
- [OK] L-068 — not touched.
- [OK] L-081 — new event rows only. Old consumers ignore them: the v0.83.0 manager's `on_event` has no catch-all branch, and `task_finish`/`files_written` are dropped (`git show v0.83.0:genesis/runs/manager.py`).
- [OK] L-083 — the ten categorizer fixtures come from real folders plus a `.backup` copy of the DB (`evidence/55-05/record_fixtures.py`), and `validator.result` keeps the real `node = agent node` shape. The real fixtures contain no `artifact.saved` rows, so that branch has no real-shape case (M1).
- [OK] L-089 — reviewer's check: `git show --stat` shows no `web/static` in the commit, and none is expected.
- [OK] L-091, L-102, L-103, L-125 — no migration or table rebuild. The fixtures were taken from a `.backup` copy.
- [OK] L-092 — no `tests/__init__.py`. No non-test module or symbol is named `test*`.
- [OK] L-094 — consumers of the new `node`-column rows: `fold_steps` (`steps.py:17`) only sets `started_at` from the first node event (`node.started` precedes any write) and changes status only on specific kinds. `fold_iterations` (`steps.py:111`) only extends a running turn's `seq_end`, and so does a message. `fold_transitions` and `provenance` are kind-filtered. `topologyFromSteps` (web) uses steps first, and its event fallback can only name a node that also has other events. `conversation.ts` has no default case. `home.py` and `schedule_routes.py` aggregate by kind. Pseudo nodes are kept out of the column, so `fold_steps` never shows `_launch`. `/artifacts` is unchanged for `DocumentsTab`/inspector (`test_the_documents_route_…` asserts its shape). Library readers of `META["artifacts"]` (`story-implementation/graph.py:501`, `test-design-analysis/graph.py:1247`, `set(META["artifacts"])`) work with the map form (dict keys) but bypass the parser and ignore globs; this is carried to 55-10, not a defect here.
- [OK] L-096 — `/runs/{run_id}/documents` collides with no generic route. Behaviour is proven by the 200 and the 404 in `test_the_documents_route_…`.
- [OK] L-109 — `artifact_roles.parse_artifacts` is the only parser, used by `lint/contract.py:check_artifacts` and `documents.py` (`roles_of`). The parity test is `test_the_lint_and_the_categorizer_read_roles_with_one_parser`.
- [OK] L-110, L-111 — a code review only. Live acceptance is 55-11 and is still open.
- [N/A] L-113, L-114, L-115, L-116, L-117 — Kiro trust/engine untouched.
- [OK] L-122 — `FILE_WRITTEN` is in `CANONICAL_KINDS` (`manager.py`), the web list and one golden event (`events.ts`), and `canonical-kinds.json`. Both directions are tested: `tests/test_schedules_api.py:715` writes and compares the JSON from the backend set, and `contract.test.ts:68` compares the web list, the fixtures and the JSON. The dev's negative control is reported. `test_a_run_records_every_write…` asserts no `custom` row carries `file.written`.
- [OK] L-123 — no web class change.

### Gates
- [OK] `pytest` — 2263 passed, 4 skipped.
- [OK] `ruff check genesis` — clean.

## Findings

### Blockers
None.

### Majors
- M1 **`artifact.saved` attribution of an old run's file has no test and departs from the spec** (`documents.py`: `DocFold.apply` `elif kind == "artifact.saved"` and `_document` `if w is None: doc["node"] = self.saved.get(path)`).
  What: for a file with no `file.written`, the step comes from the agent's `save_tool_output` `artifact.saved` event, in either stored form (canonical or a pre-54-02 `custom` row).
  Problem: spec §3 and F12 say an old run's files get `node: null`. This branch changes that API value, and nothing exercises it. None of the ten real fixtures has an `artifact.saved` row, and `test_every_real_run_folder_…` asserts `node is None` for every non-prompt file, so the branch could break or be deleted with every test green. One concrete break the suite would not catch: a canonical `artifact.saved` row whose node is only in the payload. `_legacy` falls back to `p.get("node")`, which is right, but no test pins it.
  Fix: add one categorizer case with two old-run rows, a canonical `artifact.saved` with a node column and a legacy `custom` `{data:{type:"artifact.saved",node,document}}` with none. Assert each file's `node` and that `writes == 0`. Record the deviation from F12 in As built. Deleting the branch, so the code matches the spec, is the alternative fix.
  If skipped: an untested API value that 55-09 will render ("Step: draft" against "step unknown").

### Minors
- m1 **A same-node fan-out is not `_parallel` and stamps the wrong execution** (`writes.py` `WriteTracker.start`: `if t.node != node` and `others = {… t.node != node}`).
  Case (reproduced): `start("t1","work"); start("t2","work")`, then both branches write. `finish("t1")` returns `('work', ['work'], [item1.json, item2.json])` and `finish("t2")` returns `[]`. Both files get t1's execution, iteration and attempt from `Stamps`. A `Send` map to one node is the usual fan-out shape. The spec's rule is that overlapping tasks are `_parallel`.
  Fix: mark overlap by task id rather than node: `if tid != task_id: t.overlap.add(node)` and `others = {t.node for tid, t in self._open.items() if tid != task_id}`. The result is then `_parallel` with `nodes == ["work"]` and no stamps. Extend `test_overlapping_tasks_are_parallel…` with the same-node case.
  If skipped, record the limit in As built.
- m2 **System files read `writing: true` for a whole live run** (`documents.py` `_document`: `writing` is computed before the category).
  Case (reproduced): a running run with `_kiro/sessions/x/.index/.lock` (0 bytes) gives `('…/.lock', 'system', True)`. Real agent runs carry such files: 197 zero-byte files under `_kiro/` in `~/Genesis/runs`, e.g. `.index/.lock`, `powers.log` and `.sync.lock`. They have no write record because `_kiro/` is excluded from the diff, so they read "being written" until the run ends.
  Fix: set `writing` only for non-system, non-prompt documents (e.g. `doc["writing"] = False` in the system branch).
- m3 **`legacy: true` for every new run until its first write** (`documents.py` `view`: `"legacy": not self.writes`).
  Case: a new run whose first step is a long agent turn returns `legacy: true` for minutes, then flips to `false`. A 55-09 "steps unknown for this old run" note would show and disappear on every run.
  Fix: report legacy only when the run cannot have records, for example `not self.writes and rec.status in _TERMINAL`. Alternatively, define the field in 55-08's contract table as "no write records yet" and name it so.
- m4 **Pre-kill writes are never recorded, and the spec sentence assumes they are.** Spec §1 says "a file written before the kill and not touched again keeps its first record". In reality a killed task has no finish, so no record exists. The resumed start's snapshot already contains the file, so it is never reported (`test_a_paused_and_resumed_task…` comment: "no finish: no record"). Such a file then falls to the name and role rules with `node: null`.
  This is not a code change. Record it in As built's Limits beside the background-thread limit, and let 55-08/55-09 render it as "step unknown".

### Nits
- N1 `test_the_stat_cost_of_the_largest_real_run_folder_is_small` writes 300 files with `tempfile.mkdtemp()` and never removes them, and it asserts a wall-clock bound (coding standards §4: no real clocks). Use `tmp_path`, and keep the bound generous or drop it, since the As built records the measurement.
- N2 `manager.documents` parses `workflow.yaml` twice (`meta_of`, and `graph_of` calls `meta_of`) and walks the folder inside `FoldCache`'s single lock. Every documents request is serialized behind that work. It is cheap today (under 4 ms), but the yaml read could be done once, outside the lock.
- N3 `scan` drops any `*.part` file at any depth (`writes.py`), not only the brief's temp file. That is fine today; name the rule in As built so a workflow does not call a deliverable `*.part`.

## Deviations the dev asked me to judge
- No `RunWorkspace.manifest` mtime; the documents view uses the same `scan` as the worker: **agreed**. One walker serves both, and the manifest's `_kiro/` exclusion (53-06) stays true for `/artifacts`.
- `.pids/` excluded and listed as System: **agreed**. It is process bookkeeping (51-05).
- A list-form workflow keeps the record's step and gets the name rules for its category: **agreed**, and it is tested (`test_declared_roles_and_write_records_win…`).
- `_toolcalls/*` are not documents, only `tool_outputs`: **agreed**. D9 says the store is purged at run end, and `file_available` is tested.
- writes = count of `file.written` (0 with none; prompts 1): **agreed**.
- Stamping in the manager rather than at read time: **agreed**. It is incremental, and it is thread-safe in practice for these reasons:
  - Each run has one pump. A paused worker's tail is dropped by `seen["stop"]`, and side-op workers emit no `task_finish`.
  - Each `OrderedDict` operation on `_stamps` is atomic under the GIL.
  - A race with `_finalize`'s pop at most re-inserts one entry, bounded by `_STAMPS_MAX`.
- `execution` = nth distinct task id, not the spec's "nth completion": **agreed**. It also counts an errored or gate-waiting task, and a gate resumed with the same id stays one execution. It can differ from `fold_steps.executions` for such a node, so 55-08 should name which one the UI shows.
- `artifact.saved` attribution: see M1.
- `writing` / `legacy` / `roles_declared` fields: `roles_declared` is fine. For `writing` and `legacy`, see m2 and m3.
- Steps list only steps with documents or prompts: **agreed** (`_steps`).
- Spike `race.py`: it covers sequential async, sync and to_thread nodes. It does not cover the fan-out order (whether both starts are consumed before either branch writes). The fan-out worker test writes after a 0.2 s sleep, so it does not probe that race. Record this in As built.

## What reaches the fleet before the release (editable dev venv)
The fleet servers (pids 24383/24429, started Nov 20) run v0.83.0 code in memory, but every worker they spawn imports
`genesis.runs.worker` from the editable tree at HEAD. Those workers now scan the run folder at each task start and
finish (about 3 ms for 300 files) and emit `task_finish`/`files_written`. The v0.83.0 `on_event` has no catch-all
branch, so it ignores both, and no `file.written` row reaches the real DB until a server restart. There is no
migration and `web/static` is unchanged. After a restart, the feature goes live with additive canonical rows that
the old bundle never renders. This is benign; the release itself remains 55-12.

## Not checked
- Live behaviour on the real environment: a real agent run's `file.written` stream, the documents list during a live run, and the fan-out ordering under LangGraph's real runner (out of scope; 55-11).
- Full web vitest and eslint: only the contract test and `tsc` were re-run.
- `genesis-workflows validate_library` re-run (dev-reported pass).
- Whether `_kiro/logs/*.log` can hold secret values. The `/artifacts/{name}` read route already served `_kiro/` before this diff, and `/documents` now lists those files as System. Carry this to 55-08/55-09 so System files are not offered for preview unless they are confirmed clean.

## Verdict: NEEDS_CHANGES
Fix M1: add the `artifact.saved` categorizer test (both stored forms) and record the F12 deviation, or delete the
branch. Fixing m1–m3 in the same pass is recommended; each is a few lines. Record m4, the same-node fan-out (if not
fixed), the background-thread limit, the fan-out spike gap and the stat measurements in As built. With M1 fixed and
pytest and ruff still green, this is a SHIP.

---

# Re-run 1 — head 7d67c548 (one fix commit on 5bbae6d3; genesis-review, 2026-11-23)

Scope: `git diff 5bbae6d3..7d67c548`, which touches `genesis/runs/{documents,manager,writes}.py` and
`tests/test_document_records.py` (96+/32−). This is a code review only, and nothing ran against the fleet. HEAD is
`7d67c548` and the working tree is clean. Everything I ran used `GENESIS_STATE_DIR=/tmp/rev-55-05-r1/state`.

## Gates (re-run by the reviewer at 7d67c548)

- `.venv/bin/python -m pytest -q -p no:warnings` → **2267 passed, 4 skipped** in 714.23 s. That is 2263 plus the 4 new tests, and matches the dev.
- `.venv/bin/ruff check genesis tests/test_document_records.py` → All checks passed.
- Web and `packages/` are unchanged by this commit, so their gates are N/A.
- **Fail-first (reviewer's own run).** I extracted `genesis/` at `5bbae6d3` with `git archive` and put its `runs/` first on
  `genesis.runs.__path__`, so the new test file loaded the old `writes.py`/`documents.py` (I printed both `__file__` paths
  to confirm). The m1, m2 and m3 tests **failed**, and the M1 test **passed** (`3 failed, 1 passed`). This matches the dev's claim.
- **Mutation for M1 (reviewer's own run).** I took a copy of the 7d67c548 `documents.py` and replaced
  `self.saved[doc] = node` with `pass`. The M1 test then fails with `assert None == 'analyze_section'`. The branch is now pinned.

## Round-1 findings

- **M1: fixed.** `test_an_old_runs_saved_document_takes_its_step_from_artifact_saved_in_both_stored_forms` covers
  three cases:
  - a legacy `custom` row with `data.type = artifact.saved` and no node column;
  - a canonical row with a node column;
  - a canonical row whose node is only in the payload, which exercises the `_legacy` `p.get("node")` fallback I named in round 1.

  The test asserts each file's `node` and `writes == 0`. The `documents.py` docstring table now states the exception to
  F12. The As built entry for the F12 deviation is still to be written (the dev says it will be); check it at write-back.
- **m1: fixed.** `WriteTracker.start` marks overlap by task id (`writes.py` `start`: `if tid != task_id`). A re-start
  with the same id still excludes itself, so the gate-resume case is unchanged. `test_two_tasks_of_one_node_are_a_fan_out_too`
  asserts `("_parallel", ["work"], [item1, item2])` and an empty second finish. Under `_parallel`, `Stamps` gives no
  stamps, so there is no wrong execution.
- **m2: fixed.** The system branch sets `writing=False` (`documents.py` `_document`).
  `test_the_engines_zero_byte_files_never_read_being_written` covers `_kiro/…/.lock`, `_kiro/logs/powers.log` and `.kiro/.sync.lock`.
- **m3: fixed as specified.** The rule is now `legacy = not self.writes and not active`, and
  `test_only_a_finished_run_without_write_records_is_legacy` covers live, finished, and finished with a record. The
  residual cases are in N4 below.
- **m4, N3: done in code docs.** The `writes.py` module docstring "Limits" paragraph names the pre-kill gap (it reads
  "step unknown") and the any-depth `*.part` rule. As built is still to come.
- **N1: fixed.** The test uses `tmp_path`, asserts only `len(scan(tmp_path)) == 300`, and the `time` import is gone.
- **N2: fixed.** `manager.documents` reads the record, `meta_of`/`graph_of` and the root before `self._documents.read`,
  so the yaml parse is outside the `FoldCache` lock. The status is still read inside `view`, after the fold, which keeps
  the "terminal stored before run.final" order (L-093). `root` uses `rec0.workflow_id`, which is fine because a run's
  workflow id never changes. The folder walk still runs inside the lock. That costs about 3 ms and I accept it.

## New findings (in code already present at 5bbae6d3; I missed them in round 1)

- m5 **A paused run's empty file reads "being written" for as long as the run stays paused** (`documents.py` `view`:
  `active = rec.status not in _TERMINAL`, which also counts `awaiting_input:paused` and `awaiting_input:gate`).
  Case (reproduced with `categorize([], rec, root=…)` on a folder holding a 0-byte `draft.md` and no record): `running` → `writing True`;
  `awaiting_input:paused` → `True`; `awaiting_input:gate` → `True`; `done` → `False`. Per m4, a file written before a pause kill never
  gets a record, so a paused run shows a spinner on it until it is resumed or ends. A gate-waiting run has the same
  effect for a record-less empty file, such as one written from a background thread.
  Fix: compute `writing` only for `rec.status in {pending, running}`. Alternatively, record it as a known limit for 55-09 to render.
  This does not block.
- N4 **`legacy` still cannot tell an old run from a new run that wrote nothing.** Two cases:
  - A pre-55-05 run that is still paused or gate-waiting reads `legacy: false`. It has no records and is not terminal.
  - A new run that fails in its first agent turn, before any `file.written`, reads `legacy: true`. Prompts are not write records.

  Both cases are rare, and the documents in them have `node: null` either way, so the field does no harm.
  55-08's contract table should define `legacy` as "finished with no write records", not as "predates 55-05".

## Checklist delta

The diff changes no contract, route, event kind, schema or bundle, so the round-1 ADR and lesson answers stand. The
answers this diff touches:

- [OK] L-066: the documents fold read path is unchanged, and the per-call yaml parse is now outside the lock (N2).
- [OK] L-083: the M1 fixture follows the real stored forms. For the legacy row, the dev cites `r-0aa082031405`. I could
  not open `~/.genesis/genesis.db` read-only from this sandbox (`unable to open database file`), so I did not confirm
  that row myself (see Not checked).
- [OK] L-093: the terminal status is still read after the fold (`manager.documents` `view`).
- [OK] L-094: `WriteTracker.start` has one caller, the worker's tasks branch (`worker._task_start`). `_parallel`
  attribution was already handled downstream (`Stamps` gives no stamps; `fold_steps` keeps pseudo nodes out of the
  node column). No consumer reads `legacy` or `writing` yet (55-08/55-09).
- [OK] Coding standards §4 (no real clocks in unit tests): the wall-clock bound was removed (N1).

## Not checked

- The real stored shape of a legacy `custom` `artifact.saved` row in the DB. I could not read the DB from this sandbox;
  the dev cites `r-0aa082031405`.
- The As built entries (F12 deviation, m4, N3, the background-thread limit, the fan-out spike gap, stat measurements).
  They are not written yet. Check them at the docs write-back.
- Live behaviour, as in round 1 (55-11).

## Verdict: SHIP

M1 and m1–m3 are fixed. Each has a test, and I ran the fail-first myself: three tests fail on the old code, and the M1
test now kills a branch-deletion mutant. The N items are done, and pytest (2267/4 skipped) and ruff are green at
7d67c548. The new m5 and N4 do not block. Fix m5 (`writing` only while pending or running) in 55-08, or list it in As
built Limits with m4. Define `legacy` in 55-08's contract. As built must still record the F12 deviation and the limits
listed above.
