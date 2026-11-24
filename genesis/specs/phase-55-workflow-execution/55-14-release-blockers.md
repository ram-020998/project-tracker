# 55-14 — Release blockers: same-size rewrites lost on Linux, and the apwt reap test

> **Status:** SPEC-DRAFTED 2026-11-24. Repo: genesis (`genesis/runs/writes.py`, `genesis/testexec/procs.py`, tests).
> Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev** while 55-12 is paused (D39); genesis-release
> resumes 55-12 from the new head. Decision: D39 (`55-01-findings.md` §23). No tag `v0.84.0` exists yet, so the fixes
> go on top of genesis master `3e1effaf` (pushed) with no re-tag.

## 1. Same-size rewrites inside one timestamp tick are not recorded (pipeline #7556336, failure 1)

- **Failure:** `tests/test_document_records.py:325`
  `test_a_run_records_every_write_with_its_step_execution_and_attempt`:
  `assert [('tick', 1)] == [('tick', 1), ('tick', 2)]`. The fixture's `tick` node runs twice and rewrites `round.json`
  ("1", then "2", both 1 byte).
- **Cause (55-05's design, a real product gap):** the worker's diff (`genesis/runs/writes.py`, `scan` keeps
  `(st_size, st_mtime_ns)`, `:87`) treats a file as unchanged when size and mtime match. Linux filesystems update mtime
  at a coarse tick (a few ms), so two same-size writes within one tick look identical and the second is never
  recorded; macOS (APFS) has nanosecond mtimes, which is why it passed locally and in the colima runs. Effect in real
  runs: a step that rewrites a file with the same size within one tick loses that record ("written N times" too low,
  the later execution's attribution missing); the file is still listed. 55-10's CI-image failure was this.
- **Fix direction:** make change detection independent of mtime resolution. Keep `(size, mtime_ns)` as the fast path,
  and add a content fingerprint for files up to a size bound (e.g. a 64-bit `blake2b` of the bytes for files ≤ 4 MB;
  measure and record the bound and the cost on the largest real run folder, 55-05's 300-file run: today 2.31 ms median
  per scan, twice per node). A file is written when its size, mtime **or** fingerprint differs from the task-start
  snapshot; over the bound, also compare `st_ctime_ns` and `st_ino` and record the remaining limit in the `writes.py`
  docstring and the As built. The excluded trees (55-05 §1) stay excluded, so the hashing never touches `_kiro/`,
  `.kiro/`, `_toolcalls/`, `_prompts/`, `checkout/`.
- **Test that fails first on macOS too:** force two writes with the same size **and** the same mtime (write, then
  `os.utime(path, ns=(atime, the first mtime))`) inside one node execution pair, and assert two records; keep the
  existing test. Run the file in the CI image (python:3.13, colima) and on macOS.

## 2. `test_open_records_the_daemon_and_reap_stops_it[open_host_not_allowed]` (failure 2)

- **Failure:** `tests/test_apwt_client.py` (`def` at `:204`): `assert reap(client.pid_dir) == [daemon.pid]` gave
  `[] == [410]` on master CI; it passed in the colima run.
- **Reading:** the same shape as Phase 54's Linux reap flake (`specs/backlog/phase-54-follow-ups.md` §5,
  `test_reap_kills_a_recorded_group_that_is_still_ours`, #7429033): `reap` (`genesis/testexec/procs.py:308`) reads
  `ps` before the child shows its marker, so the group is not recognised as ours. Phase 55 changed only 3 lines each in
  `testexec/recording.py` and `testexec/verification_service.py`; check whether either touches this path.
- **Fix direction:** reproduce under load in the CI image first (L-112). If the race is in the test, make it wait
  until `ps -ww` shows the child's marker before calling `reap`; if `reap` itself can miss a live child, have it re-read
  once before deciding (L-104: match on full command lines). Fix both apwt reap tests the same way if they share the
  cause, and close Phase 54 backlog §5 in the As built if so. Never skip or mark the test.

## 3. Gates

genesis pytest + ruff on macOS; the two test files 20× each in the CI image under load (`pytest -p no:randomly -x`
repeated, or `pytest-repeat` if present), then the full genesis suite once in the CI image (L-112). Record each count.
genesis-review reviews the fix; then genesis-release pushes master, waits for the master pipeline, and only then
asks for the tag (55-12 §1).

## Context manifest

```toml
areas    = ["runs-worker", "browser-testing"]
adrs     = ["ADR-010", "ADR-022", "ADR-083"]
lessons  = ["L-066", "L-083", "L-104", "L-107", "L-110", "L-112"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-05-document-records.md", "tracker:specs/backlog/phase-54-follow-ups.md"]
code     = ["genesis/genesis/runs/writes.py", "genesis/genesis/testexec/procs.py", "genesis/tests/test_document_records.py", "genesis/tests/test_apwt_client.py"]
upstream = ["55-05", "55-11"]
```
