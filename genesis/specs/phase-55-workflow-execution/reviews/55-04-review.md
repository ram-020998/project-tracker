# Review 55-04 — base 29775149, head d1ab6d13 (genesis-review, 2026-11-23)

What this change does: at the start of every fresh run whose graph has an agent node, the worker builds a run
description from `META` and the inputs (ids resolved to names through a read-only `genesis.db`), retrieves up to 12
shared and 6 personal memories from a read-only `memory.db` within 5 s, and writes `_memory/brief.md` plus one canonical
`memory.brief` event. `kiro_node` then appends one pointer line to each prompt and adds the internal read-only
`genesis-memory` MCP with exactly its six tools trusted. fastembed `BAAI/bge-small-en-v1.5` becomes the default
embedder: a core dependency, its model files fetched by `scripts/install-packages.sh` against pinned SHA-256s, loaded
only from `<state>/models/` with `local_files_only`, and existing memories back-filled by `genesis memory reembed`.

Commit checked: `d1ab6d13` exists and is HEAD of `genesis` master, working tree clean. One commit over `29775149`,
26 files.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis-core `pytest` (dev venv) | **130 passed** |
| genesis-core `ruff check genesis_core` | clean |
| genesis `ruff check genesis` | clean |
| genesis full `pytest`, clean scratch venv `/tmp/gv-55-04/venv` (fastembed 0.7.4 + model), `GENESIS_STATE_DIR=/tmp/gr-55-04/state` | **2218 passed, 3 skipped** in 746 s (the 3 skips are the opt-in real-brief tests) |
| New tests on the dev venv (no fastembed, the CI shape): `test_memory_brief.py`, `test_memory_brief_worker.py`, `test_install_packages_script.py`, `test_memory_brief_real.py` | 70 passed, 4 skipped (offline-load: no fastembed; real: opt-in) |
| Offline load under `sandbox-exec` network deny + negative control; web process imports no embedder (scratch venv) | passed |
| Real briefs (`GENESIS_REAL_MEMORY=1`, frozen `mode=ro` backup copies, `immutable=1`) | 3 passed; TD feature-4 event reproduced exactly: shared `[26,28,35,30,34,31,33,49,6,47,32,83]`, personal `[87,43,44]`, 7,795 chars, bge, 96 ms |
| genesis-workflows `pytest workflows` against this core (dev venv) | **463 passed**; `ci/validate_library.py` PASSED (19 workflows) — ADR-019 "existing workflows unchanged" holds |
| web `npm run lint` | 0 errors, 20 warnings (baseline) |
| web `npm run typecheck` | clean |
| web `vitest` | 83 files, **963 passed** |
| Stale bundle: `npx vite build --outDir /tmp/gr-55-04/static` then `diff -r` against `web/static` | identical |
| `scripts/install-packages.sh --editable --dev` on a clean venv | not re-run by me (the dev's `/tmp/gv-55-04/venv` built by it is what the full suite ran in; its `install.log` is in `/tmp/gv-55-04/`) |

## Checklist

ADRs
- [OK] ADR-001 — the brief is program code before `astream`; no agent decides control flow (`genesis/runs/worker.py` `_run_job`, `_memory_brief`).
- [OK] ADR-002 — agent steps stay narrow kiro turns; the memory MCP is injected per node (`agent.py` `servers.append(dict(msrv))`), no global `mcp.json`.
- [OK] ADR-003 — local only; the model comes from a pinned HF revision at install, nothing at run time.
- [OK] ADR-004 — per-node injection, and `memory=False` opts a node out (`test_a_run_gets_its_brief…` asserts `quiet` has no server).
- [N/A] ADR-005 — the memory server is internal and not in the library registry (F5).
- [N/A] ADR-006 — no workflow package change.
- [N/A] ADR-007 — no roles/bundles.
- [N/A] ADR-008 — no UI shell change.
- [OK] ADR-009 — gates, pause/resume, fork still work: the worker test pauses at `approve`, resumes, forks; the brief is not rebuilt on resume.
- [OK] ADR-010 — the brief is a blackboard file; only its path goes through `ctx.extras`, nothing in graph state.
- [OK] ADR-011 — no new agent node; the reliability lint is unchanged (`validate_library.py` passed).
- [OK] ADR-012 — the prefetch and the embedder run only in the worker; the app never imports workflow Python (`graph_has_agent_node` runs in the worker on the compiled graph).
- [N/A] ADR-013 — no config UI.
- [N/A] ADR-016 — no naming change.
- [OK] ADR-017 — Python only.
- [OK] ADR-018 — bulk memory text handed by file pointer, not state or chat.
- [OK] ADR-019 — `kiro_node(memory=True)` is additive, `CORE_MAJOR` unchanged; 463 library tests pass on this core.
- [OK] ADR-020 — no user Kiro config touched; servers go over ACP.
- [OK] ADR-021 — the six memory tools are read-only and the server opens `mode=ro` (`ReadOnlyDatabase`, `tx()` refused), so no `pre_mutation` gate is needed.
- [OK] ADR-022 — the brief lives under the run's artifacts folder; the model under `Settings.models_dir` in the state dir, not in artifacts.
- [N/A] ADR-023 — no server topology change.
- [OK] ADR-024 — blocking SQLite reads and the model load run on daemon threads awaited with `asyncio.wait_for` (`brief.py` `_off_loop`), never on the loop.
- [OK] ADR-025 — fork copies `_memory/` into the new run's folder; the original is untouched (`test_a_fork_copies_the_brief_and_leaves_the_original_untouched`).
- [OK] ADR-026 — no new listener; the model fetch is install-time HTTPS to a pinned revision.
- [N/A] ADR-027 — web change is a test fixture only.
- [N/A] ADR-028 — no endpoint added.
- [OK] ADR-029 — trust is exactly `@genesis-memory/<six tools>`, never `genesis-memory/*`, proven on the real projection (`KiroACPClient(opts)._agent`) in core `test_the_projected_agent_trusts_exactly_the_six_memory_tools` and in the worker test, which also starts the recorded launch and compares `tools/list`. The server is platform-internal, so it sits outside `node.tools ∩ allowlist` by F5 design; ADR-088 records it.
- [OK] ADR-030 — SQLite only; store signatures stay DB-agnostic (`phrases=`, `statuses=` keyword args).
- [OK] ADR-031 — chat's memory server became stricter: the read-only vector index replaces a writable handle that could `CREATE` the vec table (`memory_server.py` `retriever`).
- [OK] ADR-032 — no credit figures; the dev's one live run reports 0.463 metered credits.
- [N/A] ADR-033 — no copilot tools.
- [N/A] ADR-034 — no skill change.
- [N/A] ADR-035 — file inputs appear by file name only (`describe_run`, `_file_keys`).
- [N/A] ADR-036, ADR-037 — KB names read only; no KB writes and no SAIL.
- [N/A] ADR-038, ADR-040 — no managed-native change.
- [N/A] ADR-039, ADR-041, ADR-042 — not touched.
- [N/A] ADR-045 — chat surface unchanged.
- [OK] ADR-046 — still one install command; the model fetch is a step of `install-packages.sh` that only warns on failure.
- [N/A] ADR-047, ADR-087 — no schedule change.
- [N/A] ADR-048 — no Appian credentials.
- [N/A] ADR-049, ADR-061, ADR-062, ADR-084 — no UI/workbench change.
- [N/A] ADR-050 — no lifecycle status.
- [OK] ADR-051 — agent turns still go through the `AgentProvider` seam (the worker test installs a recording provider via `set_agent_provider`).
- [OK] ADR-053 — personal memories go only into the local brief's "Your preferences" section for `canonical_username`; nothing in the repo copies a run folder out (grep for `copytree`/`make_archive`: only the new fork copy). Amended by the ADR-088 draft.
- [OK] ADR-054 — `memory.db` separate, embedder loaded only in worker/MCP subprocesses (`test_the_web_process_never_imports_an_embedder` passed in the scratch venv, where fastembed is installed). Default model amended by ADR-088 D3.
- [N/A] ADR-055 — no styling.
- [N/A] ADR-063, ADR-065 — nothing published.
- [OK] ADR-066 — the memory line is added before the prompt capture, so the captured prompt is the sent one (`test_with_a_brief_the_prompt_gets_the_line_and_the_capture_is_the_sent_prompt`).
- [N/A] ADR-067 — healing untouched.
- [N/A] ADR-068, ADR-073, ADR-082 — no Appian writes.
- [OK] ADR-069 — skills provisioning untouched; cwd is still `ctx.workspace.root` (`agent.py:441`), so the relative brief path resolves.
- [N/A] ADR-074, ADR-075, ADR-076, ADR-081 — not touched.
- [OK] ADR-077 — reviewer used `genesis-ctx`; no bulk docs read.
- [OK] ADR-080 — one shared version; `fastembed==0.7.4` is a third-party pin; no internal package lists another.
- [N/A] ADR-083, ADR-085 — not touched.
- [OK] ADR-086 — trust is the projected agent with explicit tool names; the live run shows no permission request (`evidence/55-04/live-r-ea61596cd428/mcp-log-genesis-memory.jsonl`: connect, listTools and callTool all ok).

Lessons
- [OK] L-001 — memory server `env` is `[]`, a list (worker test asserts `srv["env"] == []`).
- [OK] L-002 — real `KiroAgentOptions` built in both new test files.
- [N/A] L-003, L-018, L-060, L-066 — no SSE or client change.
- [OK] L-004 — SQLite.
- [OK] L-005 / L-122 — `memory.brief` is in `_CANONICAL_CUSTOM`, the web `CANONICAL_EVENT_KINDS`, a fixture event and `canonical-kinds.json`; the both-ways parity tests (`tests/test_schedules_api.py`, `web/src/test/fixtures/contract.test.ts`) pass.
- [N/A] L-006, L-059, L-065 — topology untouched (node descriptions are only read).
- [OK] L-008 — skips and errors carry a reason; see n2 for one empty-message case.
- [OK] L-009 — async path unchanged.
- [N/A] L-012, L-019, L-028, L-029, L-031, L-048, L-049, L-053, L-054, L-070 — not touched.
- [OK] L-016 — no estimated credits.
- [OK] L-017 — namespaced `@server/tool` form, fail closed: no brief means no server and no trust.
- [N/A] L-020 — no loop.
- [OK] L-021 — the brief is ≤ 12,000 chars of whole entries with an omission line pointing at `search_memory`.
- [N/A] L-022 — no workflow graph.py.
- [OK] L-023 — `KbNames` returns None on a missing table/row; unknown ids stay ids (`test_unknown_ids_stay_as_ids…`).
- [OK] L-025, L-027 — ruff pin unchanged (0.15.20).
- [OK] L-026 — DB reads off the event loop (`_off_loop`).
- [N/A] L-030 — web change is test-only; CI frontend job still triggers on `web/**`.
- [N/A] L-033, L-050, L-051, L-052, L-058, L-061, L-062, L-064, L-068, L-076, L-087, L-088, L-097, L-104, L-105, L-106, L-107 (no background job), L-119, L-120, L-124 — not touched.
- [OK] L-041 — the agent only reads the brief; the cwd is the run root.
- [OK] L-042 — context given as a file in the workspace.
- [N/A] L-044, L-045 — no ACP extension surface.
- [N/A] L-056, L-057, L-099 (release), L-100, L-101, L-111, L-112 — release-phase items; see Not checked for L-112.
- [N/A] L-075 — no verify loop.
- [OK] L-081 — the default flips to fastembed, but an explicit `GENESIS_MEMORY_EMBEDDER=model2vec|none` still wins; the old installer never installed the `embeddings` extra (`git show 29775149:scripts/install-packages.sh`), so no user loses working vectors.
- [OK] L-089 — the reviewer ran builds and diffs as separate steps.
- [OK] L-091 — no validate-then-write in shared state; the prefetch only reads.
- [OK] L-092 — no `tests/__init__.py` added; no non-test `test*` symbol.
- [OK] L-093 — the event is emitted after the file is written (`prefetch` writes, then returns the event).
- [OK] L-094 — `build_embedder` callers: `context.py:178`, `memory_server.py:162`, `cli/main.py:346`, all updated; doc consumers still say `model2vec` (hand-off below).
- [OK] L-098 — a missing fastembed is detected (`find_spec` in health; `ImportError` → `NullEmbedder`).
- [OK] L-108 — no terminal write added.
- [OK] L-113, L-116, L-117 — trust checked on the product's own projection with negative controls (no brief, `memory=False`, a tool the server lacks, a node already listing the server) and one live run.
- [N/A] L-114, L-115 — no event parsing or skills change.
- [OK] L-121 — the brief runs only for `op == "run"`; side ops only get `ctx.extras` when the file exists and write no status.
- [OK] L-125 — the real-brief test copies with SQLite online backup from a `mode=ro` connection.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **`python -m genesis.cli.main memory …` crashes with `NameError`** (`genesis/cli/main.py`, `_memory_cmd` is defined
  after `if __name__ == "__main__": raise SystemExit(main())`). What: under `-m` the module runs top to bottom, so
  `main()` runs before `_memory_cmd` exists. Problem: reproduced: `cd / && GENESIS_STATE_DIR=/tmp/gv-55-04/state
  /tmp/gv-55-04/venv/bin/python -m genesis.cli.main memory status` → `NameError: name '_memory_cmd' is not defined`.
  The `genesis` console script and the install script's `python -c 'from genesis.cli.main import main…'` work (both
  import the whole module first), and nothing in the repo uses the `-m` form today. No test exercises `_memory_cmd`
  itself either: `test_install_packages_script.py` drives a fake interpreter, so the exit codes the script relies on
  (fetch failure → 1, reembed on `NullEmbedder` → 1) are untested. Fix: move `_memory_cmd` above the `__main__` guard,
  and add one CLI test calling `main(["memory", "fetch-model"])` with a failing `fetch_model` (expect 1) and
  `main(["memory", "reembed"])` with no model (expect 1). If skipped: anyone running the documented `__main__` form
  gets a traceback, and a regression in those exit codes goes unseen.
- m2 **`reembed` drops the old vector table before setting its rows back to `pending`** (`genesis/memory/vector.py`,
  `reembed`: the `DROP TABLE` loop runs, then `store.mark_vectors_stale()`). Problem: if the process dies between the
  drop and the update (Ctrl-C in the install script, a crash), the memories stay `embedded` with no vector. The next
  `reembed` takes only `pending`/`skipped` rows and finds no table of another dimension to drop, so those memories are
  never embedded again and semantic retrieval silently misses them. Fix: call `store.mark_vectors_stale()` before the
  drops when `dropped` is non-empty. That order is safe to repeat: a crash after the update only leaves extra
  `pending` rows, which the next run re-embeds.

### Nits
- n1 `reembed`'s `while True` loop has no progress guard (`vector.py`). An embedder returning fewer vectors than rows
  (`zip` truncates) leaves rows `pending` and loops forever inside the install script. Fix: `break` when a batch marks
  nothing.
- n2 A `_describe` that times out reports `error: "TimeoutError: "` (an empty message; `brief.py` `prefetch`, the
  outer `except`). The two later deadline paths say "the 5 s deadline passed". Fix: catch `asyncio.TimeoutError`
  around the `_describe` await with the same message (L-008 spirit).
- n3 `path.write_text(text)` for the brief is not atomic. A pause (kill) during that write leaves a truncated
  `brief.md`, and resume reuses it because it never rebuilds. The window is tiny (≤ 12 KB, once per run). Fix: write
  `brief.md.part`, then `os.replace`.
- n4 (no code change; for the user) The fleet runs from the editable dev venv, so `d1ab6d13` is live for every new
  fleet worker now (L-099). Two effects until the next restart and 55-10: (a) the running servers imported `manager.py`
  before this commit, so their `_CANONICAL_CUSTOM` lacks `memory.brief`, and those events are stored as `custom`
  (L-122); (b) `memory-consolidation` and `memory-maintenance` get a brief and the memory MCP against D4 until 55-10
  adds `META.memory_brief: false`. The dev venv has no fastembed, so fleet briefs are keyword + entity only. I did not
  restart anything.

### Judged choices (dev's list)
1. Hints from the most specific level only: accepted. Evidence: the TD feature-4 brief has 11 of 12 shared entries
   about Document Builder, with #26 first.
2. **#27 missing from the TD feature-4 brief** is a deviation from the §5 wording ("#26, #27"). It is reasoned
   (#27 is anchored only to two concepts, and more than 12 Document Builder memories compete), and the test asserts #26
   first plus ≥ 10 feature memories. Record it in As built for the user's 55-11 look. It is a relevance outcome, not a
   code defect.
3. No similarity floor (the agent-prompt "hello world" brief holds 12 loosely related memories): accepted for now. It
   costs credits only if the agent reads the file, and D2 names option A as the upgrade path.
4. Server handed through `ctx.extras`, not `mcp-registry.json`: matches F5.
5. Personal entries budgeted first, steps placed last in the description, daemon threads for the deadline, read-only
   memory MCP, health never making `is_ready` false, `--no-model` in CI test jobs: all accepted. Each is justified in
   code comments and covered by a test.
6. Memory workflows get a brief until 55-10: see n4.

### Hand-offs (not findings)
- genesis-docs: `docs/architecture/modules/memory.md` (lines 35, 57, 178, 544) and `configuration-and-secrets.md:732`
  still name `model2vec` as the default. `04-container-view.md:109` lists `genesis-memory` as used by Chat only; it is
  now also used by workflow agent nodes.
- 55-10: check that the library's META/workflow.yaml schema and the parity lint accept the new `memory_brief` key.

## Not checked
- A CI run (L-112). fastembed 0.7.4 pulls onnxruntime, tokenizers and numpy into every CI test job. I did not confirm
  that the CI image resolves them for Python 3.13. The clean-install job now also needs huggingface.co, though a failed
  fetch only warns.
- `scripts/install-packages.sh --editable --dev` on a fresh venv, re-run by me (I relied on the dev's scratch venv
  built by it).
- A second live agent run. Per your rules I did not spend credits. The dev's one live run is the evidence.
- Linux behaviour of the offline-load guarantee. The sandbox test is macOS-only; on Linux the `local_files_only` path
  is unproven by a network-denied test.
- Fleet state after the commit (n4). I did not read the fleet DB.

## Verdict: SHIP

No blockers or majors, and every gate I re-ran is green. m1 and m2 are small fixes I recommend before the release
commit. They do not block 55-04.
