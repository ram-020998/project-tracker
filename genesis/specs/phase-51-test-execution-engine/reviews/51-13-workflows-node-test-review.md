# Review 51-13 (genesis-workflows node test fix) — base b295394 (genesis-review, 2026-11-02)

Scope: genesis-workflows, one local commit `60dde75` on top of the pushed v0.25.0 release commit `b295394`
(`git diff b295394 60dde75`). Working tree clean, HEAD = `60dde75`. Not tagged, not pushed (I did neither).

Problem being fixed: master pipeline #7336032, job `workflow-tests`, 1 failed / 427 passed.
`test_scan_refs_reports_why_it_cannot_run` expected `no lib/scan-refs.mjs` and got `node is not installed`, because the
CI image `python:3.13` has no Node and `scan_refs` (`workflows/action-capture/graph.py:463-484`) checks node first via
`shutil.which("node", path=_child_env().get("PATH"))` (`_child_env`, graph.py:431-433, copies `os.environ["PATH"]`).

## The change

`git diff --stat`: `workflows/action-capture/tests/test_action_capture_workflow.py | 18 ++++++++++++++----`, nothing
else. `graph.py`, `workflow.yaml`, `registry.json` and versions are untouched (user requirement: test only, no bump).

New order in the test (lines 653-675):
1. Build the fake `bin/node` (`#!/bin/sh` + `echo not json`, +x) and an empty folder `empty-path`.
2. `PATH=<empty-path>` → `scan_refs` raises `node is not installed`.
3. `PATH=<bin>:<os.environ PATH>`, and that inner PATH is now `<empty-path>` (set in step 2), so PATH is exactly
   `bin:empty-path` and the host's own node can never be picked up → `no lib/scan-refs.mjs`.
4. Write `lib/scan-refs.mjs` → the fake node runs, exits 0, prints `not json` → `scan-refs printed no JSON document`.

### Is each reason reached for the right cause?

Traced against `graph.py:466-482`:
- Step 2: `shutil.which` over a PATH holding only an empty folder returns None on any host → the first `raise`
  (graph.py:467-468). `lib/` does not exist yet either, so if the node check were dropped or moved after the file
  check, the message would be the missing-file one and the assertion would fail. The two branches are told apart.
- Step 3: node resolves to the fake (the only `node` on `bin:empty-path`), `lib/scan-refs.mjs` is absent → graph.py:469-470.
  Without the fake on PATH this is the exact CI failure, which the BASE_TEST run below reproduces.
- Step 4: the fake node runs via an absolute `/bin/sh` shebang (`echo` is a shell builtin, so the minimal PATH does not
  matter), return code 0 skips the `scan-refs failed` branch (graph.py:476-477), and `json.loads("not json\n")` raises
  → graph.py:478-481. Right cause.

## Verification (my own runs)

| Check | Command | Result |
|---|---|---|
| Full suite, macOS, node on PATH (`/opt/homebrew/opt/node@20/bin/node`) | `../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures -p no:cacheprovider` | **428 passed** |
| Full suite, macOS, no node (`env PATH=/usr/bin:/bin`, venv python by absolute path) | same | **428 passed** |
| action-capture file, macOS, no node | `env PATH=/usr/bin:/bin … pytest -q workflows/action-capture/tests/test_action_capture_workflow.py` | **54 passed** |
| ruff | `../genesis/.venv/bin/ruff check workflows/action-capture` | All checks passed |
| CI repro, fixed, `python:3.13` (no node, no npm) | dev's `docker run … python:3.13 bash /repro/ci-wf.sh` | internal pins PASSED; library-validate PASSED (18); skills-validate PASSED (4); workflow-tests **428 passed**, exit 0 |
| CI repro, base test file | same + `-e BASE_TEST=1` | **1 failed, 427 passed**: `Expected regex: 'no lib/scan-refs.mjs'` / `Actual message: 'node is not installed'` at line 654, the pipeline's failure exactly |
| Image tools | `docker run --rm python:3.13 bash -c 'command -v git ps node npm npx; …'` | `git` and `ps` present; node/npm/npx absent; Linux `/proc` present |

I read `ci-wf.sh` (`.reap-repro/`, outside the repos): it copies the working tree (clean, = `60dde75`), runs
`ci/check_internal_pins.py` like the CI `before_script`, installs the four internal pins exactly as `pyproject.toml`
lists them (`genesis.git@v0.81.0`, rewritten to the local checkout) with `--no-deps`, then this repo editable, then
the three CI job commands. It does not perform CI's fresh `pip install -e ".[dev]"` resolve; third-party versions come
from the genesis dev venv's freeze (pytest 9.1.1, pytest-asyncio 1.4.0 shown). That is a residual difference from CI,
not a defect of this change; the changed test uses only `pytest.raises`, `monkeypatch.setenv` and `tmp_path`, which do
not depend on those versions.

## Other hidden PATH / host-tool assumptions (independent check)

- Tests (`workflows/**/tests/**/*.py`), grep for `shutil.which|subprocess|Popen|os.system|"node"|npx|"git"|ps`:
  every `npx` is a fake bin prepended to PATH (action-capture :247-252, test-execution :171-176, setup-composer
  :332-337 which also fakes `node`, story-verification :304-309). No test runs `git`, `ps` or a real node directly.
- Genesis helpers the tests reach through the real `ctx.extras['apwt']` (`genesis/testexec/*`):
  - `workspace.py:130-141` `_git` → real `git` (workspace repository, `library_drift`). Present on macOS and in
    `python:3.13`; the Docker run exercises it. A CI image without git would fail, but CI's own `before_script` runs
    `git config`, so git is a precondition of the job already.
  - `procs.py:283` `ps` is the non-Linux fallback; on Linux `/proc` is read first (`_cmdlines_from_proc`, present per
    the repro's `hasattr` print). `ps` is in the image anyway.
  - `runner.py:97`, `workspace.py:340`, `runtime.py:162` resolve `npx` on PATH → satisfied by the fake npx in every
    whole-graph test.
  - `workspace.py:462` (`TestWorkspace.scan_refs`) and `roles.py:118` (`scan_texts`) need real node. Workflow tests
    reach roles only in story-verification, which replaces `roles._scan` with `genesis.testing.scan_recording.
    use_recorded_scanner` (test :268-272; helper :109-112). The recording calls `real_node_modules()` (which needs
    node, npm, git) only when `GENESIS_WRITE_SCAN_FIXTURES=1` (scan_recording.py:89); otherwise a missing text is an
    `AssertionError`, not a host-dependent skip.
- No `skipif` / `importorskip` in any workflow test, so no test silently changes behaviour with the host's tools.
- The macOS run with `PATH=/usr/bin:/bin` (no node, git and ps present) passing all 428 confirms the same thing from a
  second host.

## Checklist

`genesis-ctx check --since b295394 --repo genesis-workflows`: one file → area workflows-library (+ always-on
release-ci, security).

### ADRs
- [N/A] ADR-001, 003, 005, 006, 007, 010, 012, 014, 015, 017, 018, 020, 021, 022, 026, 029, 030, 031, 033, 034, 035,
  036, 037, 038, 039, 041, 045, 046, 048, 056, 057, 058, 059, 061, 062, 063, 065, 067, 068, 069, 073, 074, 075, 076,
  078 — the diff touches one test function's setup and assertions; no graph, state, registry, skill, gate, MCP,
  credential, KB or UI code changes.
- [OK] ADR-011 — reliability trio CI-enforced: `validate_library.py` PASSED (18) in the Docker repro; no node changed.
- [OK] ADR-019 — `CORE_MAJOR` / `genesis_core_major` untouched; library-validate PASSED.
- [OK] ADR-077 — review run without `--trust-all-tools`; rules retrieved by `genesis-ctx check`.
- [OK] ADR-080 — internal pins unchanged (`genesis.git@v0.81.0`), `check_internal_pins.py` PASSED in the repro.

### Lessons
- [N/A] L-006, 009, 013, 017, 020, 021, 022, 023, 024, 026, 029, 033, 042, 045, 049, 053, 064, 075, 076, 087, 088,
  098, 099 — no workflow topology, LangGraph, MCP, skill, credential or packaging code in the diff.
- [OK] L-025 / L-027 — ruff pinned via the dev venv; `ruff check workflows/action-capture` clean.
- [N/A] L-030 — no web files in this repo.
- [OK] L-051 — verified against the real CI image (`python:3.13`), not only macOS.
- [OK] L-056 — `git diff --stat` shows only the test file; the fix needs no implementation change (graph.py is the
  code the test describes, unchanged). Relevant for the release agent: the next tag must contain `60dde75`.
- [OK] L-057 — no version bump and no pin change, as the user required.
- [OK] L-089 — the evidence is separate runs (macOS ×2, Docker fixed, Docker base), not one batched command.
- [OK] L-092 — no new test module or `tests/__init__.py`; the count stays 428 (427 + the fixed one), each test once.
- [OK] L-100 — no CI-variables API used; the repro uses no CI secret (pins rewritten to the local checkout).
- Coding standards §4 "a regression test that would have caught it": [OK] — the fixed test is itself the regression
  test, and it now pins the no-node reason too; it fails on the base file in `python:3.13` and passes after.

### Gates
- [OK] `ci/validate_library.py` — PASSED (18), Docker repro (dev also reports macOS PASSED).
- [OK] `pytest -q workflows --ignore=workflows/_fixtures` — 428 passed (macOS with node, macOS without node, Docker).
- [N/A] `cd genesis && pytest` / `ruff check genesis` — the genesis repo is unchanged by this commit.

## Findings

### Blockers
None.

### Majors
None.

### Minors
None.

### Nits
1. `test_action_capture_workflow.py:666` — `f"{bindir}{os.pathsep}{os.environ.get('PATH', '')}"` reads PATH after it
   was set to the empty folder on line 662, so PATH is `bin:empty-path`. That is what makes steps 3–4 independent of
   the host's node (good), but it reads as "prepend to the host PATH". Optional: write
   `monkeypatch.setenv("PATH", f"{bindir}{os.pathsep}{no_node}")` or add a short comment. No behaviour change.
2. `match="no lib/scan-refs.mjs"` has an unescaped `.` (pre-existing). Harmless; `re.escape` or `scan-refs\.mjs` would be
   exact.

## Verdict: SHIP

The change is test-only and scoped as the user required. Each of the three reasons is reached for its own cause, the
test passes with and without node on the host, the base file reproduces pipeline #7336032's failure exactly in
`python:3.13`, and I found no other host-tool assumption the CI image lacks (git and ps are present; node is only
reached through fakes or the scan recording). The release agent still has to push `60dde75`, and decide whether it
needs a tag; this review did neither.
