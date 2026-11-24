# 55-05 — Document records: who wrote each file, its role, and one categorized list

> **Status:** BUILT 2026-11-23 (genesis `5bbae6d3`, `7d67c548`, `3c3e38ae`; review SHIP; D20; shipped in v0.84.0). SPEC-DRAFTED 2026-11-22. Repo: genesis (`genesis/runs/`, `genesis/lint/contract.py`,
> `packages/genesis-core/genesis_core/workspace.py`, `genesis/api/run_routes.py`). Parent:
> `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**. Decisions: D8, D9, F10–F12 (`55-01-findings.md`).
> The library's roles and labels are 55-10; the web is 55-09.

## 1. Write records (`file.written`)

- **Where:** in the worker, using 55-03's task stream (see 55-03 As built §0 for the real payloads). At a task start,
  take a stat snapshot (path, size, mtime) of the run folder; at the task's **finish** event (the `tasks` finish
  `{id, name, error, result, interrupts}`, which 55-03's worker receives but does not forward yet — forward it, e.g.
  `task_finish`; it also comes for an erroring node, which has no `updates` chunk), diff and emit one canonical
  **`file.written`** `{path, node, execution, iteration?, attempt?, bytes, mtime}` per new or changed file,
  attributed to that node (F10). This catches every writer — program code, validators, `kiro_node` output docs,
  agent fs writes — with no change to each node type.
- **Same task id again:** a gate task, and a task resumed after a kill, **starts again with the same task id**
  (55-03 spike): take a fresh snapshot at each start and diff against it, so a resumed task does not re-report files
  written before the kill, and a file written before the kill and not touched again keeps its first record. Never
  forward the task's `input` (the whole state, ADR-010).
- **Fan-out:** in a `Send`/parallel fan-out both branch starts come before either finishes (55-03 spike), so the diff
  cannot tell the branches apart; no workflow fans out today — attribute such writes to `"_parallel"` with both node
  names and record the limit.
- Excluded from the diff: `_kiro/`, `.kiro/`, `_toolcalls/` (tool outputs have `tool_output.recorded`), `_prompts/`
  (`agent.prompt`), `.DS_Store`. Files written before the graph starts (uploads, ADR-035; the memory brief, 55-04) get a
  `file.written` with `node: "_launch"` / `"_memory"`. The brief is written once at run start, before any node,
  atomically via `brief.md.part` (55-04): never report a `*.part` file; a fork's copied `_memory/brief.md` has no
  `memory.brief` event in the new run, so attribute it from the file itself (step "Run start (before the first step)",
  D12 item 5).
- `execution` = the node's nth completion; `iteration` / `attempt` from the node's last `agent.prompt` when it is an
  agent node.
- A zero-byte file at a node's start that is filled later shows as "being written" until a `file.written` arrives.
- Limits (record in As built): a write by a background thread after its node finished is attributed to the next
  node.
- Add `file.written` to `CANONICAL_KINDS`, the web list and fixtures (L-122). Stat cost: a run folder holds tens of
  files outside the excluded trees; measure on the largest real run and record it.

## 2. Artifact roles in `META` (F11)

- `META.artifacts` (and the mirrored `workflow.yaml` key) accepts today's list form **or** a map:
  `{name: {role: "output"|"input"|"intermediate"|"check", label: "Technical design document"}}`. Paths may be
  relative paths or simple globs (`report/*`).
- `genesis/lint/contract.py`: the parity lint compares both forms; a role outside the four values or a missing label
  in the map form is an error; the list form still passes (additive, ADR-019).
- One reader: a single parser (`genesis/runs/artifact_roles.py` or alongside the loader) used by the categorizer, the
  Resolve agent (55-07) and the lint (L-109, a parity test).

## 3. Categorization (`genesis/runs/documents.py`, new)

`categorize(run) -> RunDocuments` from: the manifest (now with `mtime`), the `file.written` events, `tool_output.recorded`
events (both stored forms, the legacy `custom` rows included, as `runs/steps.py:98-148` does), `agent.prompt` events,
the workflow's roles, `inputs_schema` (`format: "file"`), and the graph topology for step order.

| Category | Rule (first match wins) |
|---|---|
| system | prefix `_kiro/`, `.kiro/`, `checkout/`, or `.DS_Store` |
| prompt | `_prompts/*` (node, pass, attempt from its `agent.prompt` event) |
| tool_output | each `tool_output.recorded` event (tool, node, bytes, time); `file_available` only while `_toolcalls/<ref>.out` exists (D9) |
| input | `uploads/*`; a role `input`; `_memory/brief.md` (label "Memory brief") |
| output | a role `output` |
| check | a role `check` |
| intermediate | a role `intermediate`, or any other file a node wrote |
| unknown-step | old runs: no `file.written` → name rules (55-01 §4.2 patterns) with `node: null` (F12) |

Each document: `{path, label, category, node, execution, iteration, attempt, bytes, written_at, writes (count of
file.written for the path, D9), latest: true, preview_kind, media_type, passed?}` — `passed` for a check from its
node's `validator.result`. Plus `steps: [{node, label (GraphNode.description), documents, prompts}]` in graph order,
and `tool_outputs: [...]`. Bounded work per call (no whole-log fold on every poll; reuse the 55-03 incremental fold or
an `after_seq` cursor, L-066; 55-03's `SnapshotCache` reads only its `FOLD_KINDS` after the last folded seq — add
`file.written` and `tool_output.recorded` to a fold the same way rather than re-reading the log).

## 4. Endpoint (added here; 55-08 owns the contract table)

`GET /api/runs/{id}/documents` → `RunDocuments`. The old `GET /runs/{id}/artifacts` stays (its other readers: the
inspector panels, `NodeIterationsDialog`; list them, L-094); file read and download routes are unchanged.

## 5. Tests

- `file.written` from a fixture graph with a program node, a validator, an agent node (stubbed provider), a retry
  (writes = 2), a loop.
- Categorizer: one fixture per real run in 55-01 §4.2 (shapes from the real folders and events, L-083), legacy `custom`
  tool rows, old runs (`node: null`), a live run with a zero-byte file.
- Lint: list form, map form, bad role, missing label, yaml/META mismatch.

## 6. Gates

genesis-core pytest + ruff; genesis pytest + ruff.

## Context manifest

```toml
areas    = ["runs-worker", "core-engine", "workflows-library"]
adrs     = ["ADR-010", "ADR-018", "ADR-019", "ADR-022", "ADR-035", "ADR-066"]
lessons  = ["L-013", "L-021", "L-066", "L-083", "L-094", "L-109", "L-122"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md"]
code     = ["genesis/genesis/runs/**", "genesis/genesis/lint/contract.py", "genesis/packages/genesis-core/genesis_core/workspace.py", "genesis/genesis/api/run_routes.py"]
upstream = ["55-03", "55-04"]
```

## As built

**Status:** BUILT 2026-11-23, review **SHIP** (re-run 1). Repo genesis, branch master, base `419d8363`, head
`3c3e38ae`, 3 local commits (not pushed, not tagged). No genesis.db migration, no genesis-core change (`CORE_MAJOR` 1),
no `web/static` change (the web change is test fixtures only).

**Baseline run first (as asked):** the full genesis suite at `419d8363` (55-04's review-fix commit, never run in full
before) on the dev venv: **2221 passed, 4 skipped** (12 min 04 s; `/tmp/55-05-baseline-pytest.txt`).

### Commits (genesis)

| sha | what |
|---|---|
| `5bbae6d3` | source, tests, the ten real-run fixtures `tests/fixtures/documents/*.json`, web fixtures |
| `7d67c548` | review round 1: M1 test, m1, m2, m3, N1, N2, the limits in `writes.py` |
| `3c3e38ae` | test docstring: the real run of the legacy `artifact.saved` row (comment only, after the SHIP) |

### Spike (before building on the start snapshot)

`evidence/55-05/race.py` (LangGraph 1.2.8, run 3 times): the `astream` consumer sees each `tasks` start **before** the
node writes, for an async node that writes before its first await, a sync node and a `to_thread` node. So the
snapshot is taken synchronously in the stream loop at the start chunk; the node cannot run until the loop yields.
Not covered: the order inside a real fan-out (the fan-out worker test writes after a 0.2 s sleep).

### Changed

- `genesis/runs/writes.py` (new): `scan(root, excluded_dirs=, excluded_names=)` (`os.scandir`, no symlinks followed or
  listed, any `*.part` skipped), `WriteTracker` (`snapshot`, `since`, `report`, `start`, `finish`), `Stamps`,
  `FILE_WRITTEN`, `LAUNCH`/`MEMORY`/`PARALLEL`, `PSEUDO_NODES`, `EXCLUDED_DIRS` (`_kiro .kiro _toolcalls _prompts .pids`),
  `record`, `iso`.
- `genesis/runs/worker.py`: `_task_finish` forwards the `tasks` finish as `{kind: task_finish, node, task_id, error,
  files[, parallel]}` (never `result` or `input`, ADR-010; `error` trimmed to 500); the tracker starts at each
  `_task_start`; `op == "run"` emits `{kind: files_written, node: "_launch"}` for the files there before the graph
  (uploads, the `prepare` checkout, anything `build(ctx)` wrote) and `{node: "_memory"}` for the diff around the brief
  prefetch.
- `genesis/runs/manager.py`: `FILE_WRITTEN` in `CANONICAL_KINDS`; `_log_writes` (one `file.written` per file:
  `{path, node, execution?, iteration?, attempt?, bytes, mtime, task_id?, nodes?}`; a graph node is also the `node`
  column, a pseudo node is payload only); `_stamps` (per run, bounded 256, dropped at `run.final`); `documents(run_id)`;
  `_documents = FoldCache(eventlog, DocFold, DOC_KINDS)`.
- `genesis/runs/snapshot.py`: `FoldCache` extracted from `SnapshotCache` (which subclasses it, unchanged behaviour).
- `genesis/runs/artifact_roles.py` (new): `parse_artifacts`, `roles_of`, `declares_roles`, `role_for`,
  `ArtifactRole.matches` (`PurePosixPath.full_match`: `*` within one folder, `**` across), `ROLES`.
- `genesis/runs/documents.py` (new): `DocFold`, `categorize`, `name_category`, `DOC_KINDS`, `BRIEF`.
- `genesis/lint/contract.py`: `check_artifacts` in `check_meta_yaml_parity`.
- `genesis/api/run_routes.py`: `GET /api/runs/{id}/documents` (adds `media_type`/`preview_kind` as `/artifacts` does).
- Web (fixtures only): `file.written` in `CANONICAL_EVENT_KINDS` + one golden event (`events.ts`),
  `events/canonical-kinds.json` regenerated, `runs/documents-done.json` recorded from the real route (55-08/55-09).

**The `RunDocuments` shape** (55-08 owns the contract table): `{run_id, workflow_id, status, version, legacy,
roles_declared, documents: [{path, label, category, node, execution, iteration, attempt, bytes, written_at, writes,
latest, writing, passed?, media_type, preview_kind}], steps: [{node, label, description, kind, documents: [path],
prompts: [path]}], tool_outputs: [{ref, tool, node, bytes, recorded_at, file_available, path}]}`. Categories:
`output input intermediate check prompt system` (tool outputs are their own list).

### Tests

- `tests/test_document_records.py` (46):
  - worker unit: the spike's finish payloads (normal, error, gate) forwarded without `result`/`input`; exclusions,
    `*.part` and symlinks; the same task id started again (no re-report); overlap by task (two nodes, and two tasks of
    one node) → `_parallel`, reported once; `Stamps` windows.
  - REAL subprocess workers: program node, agent node (real `kiro_node`, a provider stub that writes its output doc) with
    the real reliability trio and a retry (`draft.html` writes = 2, executions 1/2, attempts 1/2), a loop (2), a check,
    an upload and a `prepare` checkout (`_launch`, no node column), a node that raises (its write is logged before
    `error`), a real fan-out (`_parallel` with both nodes), pause → resume (only the post-resume write, execution 1,
    nothing written while paused), the memory brief (`_memory`, before the first `node.started`, no `.part`).
  - categorizer: the ten real runs of 55-01 §4.2 (file counts 23/31/22/15/89/17/33/36/37/1 match; the deliverables'
    categories by the name rules; `node` null; listed once; System only under the system prefixes); TD's 19 prompts with
    node, pass, attempt and "Turn k · item" labels; its 125 legacy `custom` tool rows with their steps and no file; the
    upload labelled by its input title ("Mockup (PDF)", the real 111,438 bytes); `file_available` only while
    `_toolcalls/<ref>.out` exists; a fork's copied brief; a live zero-byte file ("being written" until its record);
    engine zero-byte files never "being written"; `legacy` only when finished; a check's `passed`; roles and records over
    name rules; the list form; `artifact.saved` in both stored forms; the fold reads only `DOC_KINDS` after its seq.
  - route: `/documents` 200 + 404, the same `media_type`/`preview_kind`/`bytes` as `/artifacts`, `/artifacts` unchanged.
  - lint: list form, map form, bad role, missing label, yaml/META drift, map only in META; parser parity (L-109).
- Fail-first: m1, m2 and m3's tests fail on `5bbae6d3`'s `writes.py`/`documents.py` (dev and reviewer); the M1 test
  kills a branch-deletion mutant (reviewer).
- L-122 both ways: dropping `file.written` from the web list fails `contract.test.ts` (negative control, then restored).
- **Gates.** genesis full pytest **2267 passed, 4 skipped** at `7d67c548` (dev venv; the reviewer reproduced it with a
  scratch `GENESIS_STATE_DIR`); `ruff check genesis` clean. genesis-core (untouched) **130 passed**, ruff clean.
  genesis-workflows `validate_library` passed (19 workflows) with the new lint. Web: typecheck clean, lint 0 errors /
  20 warnings (baseline), vitest 83 files / **963 passed**.

### Stat cost (55-05 §1)

`writes.scan` on the largest real run folders (dev Mac, 50 runs each): test-execution `r-93aab6c223e2` **300 files,
2.31 ms median / 2.57 ms max** (271 in `report/`, 29 in `checkout/`); action-capture `r-0ac738fb746d` 141 files,
2.49 ms; technical-design-analysis `r-4567cd05bcca` 18 files outside the excluded trees, 0.10 ms. Reviewer: 3.31 ms mean
for the 300-file folder. Two scans per task.

### Review

`reviews/55-05-review.md`. Round 1 **NEEDS_CHANGES**: M1 (the `artifact.saved` attribution untested and against
F12), m1 (two tasks of one node not `_parallel`), m2 (System files "being written"), m3 (every new run `legacy` until
its first write), m4 (pre-kill writes have no record), N1–N3. Fixed in `7d67c548` (m4, N3 documented). **Re-run 1:
SHIP**, with two non-blocking findings carried to 55-08 below (m5, N4).

### Decisions / deviations

No ADR deviation. Choices the spec did not cover, or where the build differs from it:
1. **No `mtime` on `RunWorkspace.manifest`** (spec: "the manifest (now with mtime)"). The documents view lists the
   folder with the same `scan` the worker diffs with, which also lists `_kiro/` for System; the manifest keeps leaving
   `_kiro/` out (53-06) and `/artifacts` is unchanged. genesis-core is untouched.
2. **Forwarding the finish:** the worker forwards it as `task_finish` carrying its diff; the manager turns it into
   `file.written`. No other new canonical kind.
3. **Stamps in the manager**, not at read time: `execution` = the node's nth **distinct task id** (spec: "nth
   completion"); it also counts an errored or gate-waiting task, and a gate resumed with the same id stays one
   execution. `iteration`/`attempt` come from the node's last `agent.prompt` between that task's start and the node's
   next task's start. It can differ from `fold_steps.executions` for such a node.
4. **`.pids/`** (a test run's process bookkeeping, 51-05) is excluded from the diff and listed as System.
5. **A list-form workflow** (no roles declared) gets the name rules for the category and keeps the record's step;
   with roles declared, an undeclared file a step wrote is `intermediate` (spec rule).
6. **`_launch` files** with no role are `input`; `_parallel` writes are documents with `node: "_parallel"` and no step.
7. **Deviation from F12's `node: null`:** an old run's file the agent saved by reference takes its step from its
   `artifact.saved` (both stored forms). Real fixtures hold such a row (TD `r-d5ed99071d49`), but the file was deleted by
   the workflow's cleanup, so no real case shows it; the test is synthetic in the real shape.
8. **`_toolcalls/*` are not documents**: each call is in `tool_outputs` (D9).
9. **`writes`** = the number of `file.written` for the path: 0 with none (old runs), 1 for a prompt with its
   `agent.prompt`. 55-09 renders 0 as unknown.
10. **Labels:** the declared label; an upload's `format: "file"` input title (else field name); a prompt "Turn k" +
    " · <item_label>" (per node, in order); otherwise the relative path.
11. **`written_at`** = the file's current mtime (also for old runs, not null).
12. Only files that exist are documents (a write record for a deleted file is not listed).
13. **Steps** list only steps with documents or prompts, in graph order, then any writer the graph does not name;
    each carries `label`, `description` and `kind` (spec said "label (GraphNode.description)": both are given).
14. **`passed`** for a check = the latest `validator.result` whose `node` (the agent) or `validator` names the doc's step.
15. **Extra fields:** `writing`, `legacy` (= no write record and the run finished), `roles_declared`, `status`, `version`.
16. **`FoldCache`** extracted from `SnapshotCache` so the documents fold reuses the read-after-seq pattern (L-066).
17. Role names: an exact name wins over a glob; globs use `PurePosixPath.full_match`.
18. The documents folder is `artifacts_dir/<workflow>/<run>`, the same as the file routes.

**Limits** (also in the `writes.py` docstring):
- A write by a background thread after its node finished: in the next task's start snapshot, so not reported until the
  file changes again; one landing while the next node runs is attributed to that node.
- **A task killed before its finish (pause, crash) leaves no record** of what it wrote; the resumed task reports a file
  only if it writes it again, else the file reads "step unknown" (the spec's "keeps its first record" holds for a gate,
  whose finish does come, not for a kill).
- Any `*.part` file, at any depth, is never listed; a workflow must not name a deliverable `*.part`.
- A fan-out cannot be split per branch: `_parallel` with the node names, no execution or attempt.
- The fan-out start order is not spiked (see Spike).

### Live effect before the release (the fleet runs from the editable dev venv)

The fleet servers (:8760/:8761, v0.83.0 in memory, not restarted) spawn workers that import HEAD: every new fleet run
now scans its folder at each task start and finish (≈ 2–3 ms for 300 files) and emits `task_finish` / `files_written`
lines, which the v0.83.0 `on_event` ignores (no catch-all branch). So **no `file.written` row reaches the real DB and
`/documents` does not exist on the fleet until a server restart**; after one, the rows are additive and the old bundle
never renders them. The parity lint change reaches genesis-workflows CI only through its pinned genesis tag (55-12).
Nothing was restarted; no live check was run (the real subprocess worker tests cover the path).

### Lesson candidates

1. **A spec sentence about a restart can assume a record that never exists**: "a file written before the kill keeps
   its first record" holds for a gate (its finish comes) but not a kill (no finish). Trace each restart path to the
   event that would carry the record.
2. **Overlap is between tasks, not node names**: a `Send` map runs one node as several tasks; keying "parallel" on the
   name attributed both branches' files to the first task (review m1).
3. **A state that drives a UI flag ("being written", "legacy") must be computed only for the categories and statuses
   it can be true for**: engine lock files and paused runs read "being written" (m2, m5).

### Code-map changes (for genesis-docs, bible/03)

- `genesis/runs/writes.py` (new), `genesis/runs/documents.py` (new), `genesis/runs/artifact_roles.py` (new): as listed.
- `genesis/runs/worker.py` `_task_finish`, the `WriteTracker` in `_run_job`; worker lines `task_finish`, `files_written`.
- `genesis/runs/manager.py` `_log_writes`, `_stamps`, `_STAMPS_MAX`, `documents()`, `_documents`; `file.written`
  canonical.
- `genesis/runs/snapshot.py` `FoldCache` (`SnapshotCache` subclasses it).
- `genesis/lint/contract.py` `check_artifacts`.
- `genesis/api/run_routes.py` `GET /runs/{id}/documents`.
- Fixtures: `tests/fixtures/documents/*.json` (ten real runs, recorder `evidence/55-05/record_fixtures.py`),
  `web/src/test/fixtures/runs/documents-done.json`.

### For 55-06+

- **55-06**: a file the app copies into a run while it waits at a gate (Fix the output, then accept) is in the resumed
  gate task's start snapshot, so it gets **no** `file.written`; log one from the action (e.g. node `"_resolve"`; add it
  to `PSEUDO_NODES` and the categorizer) or the copy reads as the step that wrote it before.
- **55-07**: read roles with `genesis.runs.artifact_roles.roles_of` (L-109); `manager.documents(run_id)` gives the
  categorized list (System excluded from the sandbox copy, F7).
- **55-08** (contract table): add `/documents` with the shape above; define `legacy` as "finished with no write
  records" (review N4: an old paused run reads false, a new run that failed before any write reads true); **fix review
  m5**: `writing` is true for a zero-byte, record-less file while the run is paused or at a gate, so compute it only
  for `pending`/`running`; name which `execution` the UI shows (distinct task ids here vs `fold_steps` completions);
  decide whether `file.written` is a `/live` hint (not in `LIVE_KINDS` today).
- **55-09**: `writes == 0` = unknown ("written N times" only when > 0); System hidden by default; do not offer a preview
  of `_kiro/` files until they are confirmed free of secrets (review "Not checked"); `_parallel` and `_launch` rows.
- **55-10**: `workflow.schema.json` (`artifacts: array of string`) must accept the map; the cleanup nodes'
  `set(META["artifacts"])` work with a map (keys) but bypass the parser and ignore globs — route them through the same
  rule or keep exact names; check `validate_library` with the map form.
- **55-11**: live check of a real agent run's `file.written` stream and of `/documents` during a run; the fan-out start
  order under the real runner.
- D19: the fixtures hold paths, sizes, mtimes and reduced event payloads only; a scan against all 68 memory texts
  (30-character windows) found one hit, an Appian object name (`AS_GSS_Evaluation_SYNCEDRECORD…`, an `artifact.saved`
  document name in TD's events) that a memory also names — no memory text.
- Cleanup for the user: `/tmp/gd-55-05/` (a backup copy of your `genesis.db` and `memory.db`), `/tmp/spike-55-05/`.
