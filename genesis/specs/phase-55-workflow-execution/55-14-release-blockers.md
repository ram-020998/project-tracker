# 55-14 — Release blockers: same-size rewrites lost on Linux, and the apwt reap test

> **Status:** BUILT 2026-11-24 (genesis `d6cea8db`, local, review SHIP; see As built). SPEC-DRAFTED 2026-11-24. Repo: genesis (`genesis/runs/writes.py`, `genesis/testexec/procs.py`, tests).
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

## As built

**Status:** BUILT 2026-11-24, review **SHIP** (`reviews/55-14-review.md`; its one condition, the full suite in the CI
image under `--init`, is met below). Repo genesis, branch master, base `3e1effaf` (pushed, no tag), head `d6cea8db`,
3 local commits, **not pushed, not tagged** (genesis-release pushes for 55-12). No migration, no genesis-core change
(`CORE_MAJOR` 1), no web change (no bundle rebuild). Fleet not restarted.

### Commits (genesis)

| sha | what |
|---|---|
| `ad8f7eda` | §1 `writes.py` change key + hash memo, `documents.py` asks for no key; 6 tests in `test_document_records.py` |
| `9cd33d52` | §2 `procs.reap` re-reads a live, unmatched group once; 2 tests in `test_testexec_procs.py` |
| `d6cea8db` | test only: the over-the-bound in-place test and the memo test wait for the next ctime tick (Linux) |

### Changed

- `genesis/runs/writes.py`: `Stat` is now `(bytes, mtime_ns, change key)`. The key is a 64-bit `blake2b`
  (`hashlib.file_digest`) of the bytes for a file ≤ `FINGERPRINT_MAX_BYTES` (**1 MiB**), else `(st_ctime_ns, st_ino)`;
  `None` with `fingerprint_max=None`. A file is written when size, mtime **or** key differs (plain tuple equality, so
  `report`, the fan-out dedupe and `record()` are unchanged; `record()` still sends only path, bytes, mtime).
  `WriteTracker` keeps a `Memo` (path → (size, mtime, ctime, inode), hash, `time.time_ns()` taken before the read) and
  reuses a hash only while that 4-tuple is unchanged **and** `ctime < hashed_at − SETTLED_NS` (3 s; git's racy-clean
  rule); a file changed in the last 3 s is read at every scan. The memo is pruned to the listed files. New
  `scan(..., fingerprint_max=, memo=)`; `WriteTracker(scanner=None)` builds `partial(scan, memo=self._memo)`.
  `FINGERPRINT_MAX_BYTES`, `SETTLED_NS`, `Memo`, `Stat` exported. Docstring "Change detection" holds the limits.
- `genesis/runs/documents.py`: the view scans with `fingerprint_max=None` (it lists `_kiro/` too and reads only size and
  mtime, so the app process never reads a file for it); `_document` takes `Stat`.
- `genesis/testexec/procs.py`: `_names_a_marker(pgid, markers)`: read the group's command lines; if none names a
  marker and `_group_alive(pgid)`, sleep `_REREAD_S` (0.25 s) and read once more. `reap` uses it; it still never raises
  and still unlinks every record.

### The bound and the cost (§1)

`evidence/55-14/measure_scan.py` (warm cache, 50 runs, median; outputs `measure_scan-macos.txt`,
`measure_scan-ci-image.txt`). The tracker's view (excluded trees out), 587 real run folders under `~/Genesis/runs`
(spike-*/probe-* left out); largest file 28.4 MiB, 32 runs hold a file over 4 MiB.

| run folder | files | stat only (55-05) | hash every file ≤ 1 MiB | ≤ 4 MiB | tracker, 1st scan | tracker, memo warm |
|---|---:|---:|---:|---:|---:|---:|
| test-execution `r-93aab6c223e2` (macOS) | 300 | 2.07 ms | 27.64 ms | 27.40 ms | 26.95 ms | **1.91 ms** |
| same, python:3.13 image (container fs) | 300 | 0.78 ms | 13.68 ms | 13.48 ms | 13.87 ms | **0.93 ms** |
| library-replays `_a-0000e5bc…_930416` | 304 | 9.02 ms | 35.39 ms | 53.31 ms | 38.12 ms | 10.96 ms |
| test-execution `r-6a8202248ef9` | 64 | 1.34 ms | 7.11 ms | 24.34 ms | 7.29 ms | 1.40 ms |
| ux-design-analysis `r-569e05145bad` | 22 | 0.18 ms | 10.02 ms | 13.38 ms | 10.04 ms | 0.28 ms |

Per-file opens dominate (≈ 75 µs/file on macOS), so hashing on every scan cost about 10× the stat walk whatever the
bound; with the memo a scan costs the stat walk plus the files written in the last 3 s, and the full read happens once
per worker process (its first scan, the `_launch` snapshot). 1 MiB over 4 MiB: no dearer on the 300-file run and
cheaper on the others (35 vs 53 ms, 7 vs 24 ms first scan); files over 1 MiB in real runs are report zips, traces and
PDFs, written once, by replace or with a new size.

**Remaining limits** (also in the docstring): over 1 MiB, a same-size **in-place** rewrite inside one ctime tick is
missed (a replace gets a new inode and is seen; the python:3.13 image showed a rewrite straight after the first write
keeps the same coarse ctime) and a chmod reads as a write; up to 1 MiB, a rewrite with identical bytes reads unchanged
and a chmod is not a write; a filesystem stamping from a clock more than 3 s behind this machine's (a network share)
can let the memo reuse a stale hash for a same-tick rewrite; an unreadable file falls back to the stat key.

### The reap cause (§2)

Right after `Popen` returns, Linux can still show an **empty `/proc/<pid>/cmdline`**: `Popen` returns when its
CLOEXEC error pipe closes, which happens inside `execve` before the new image's arguments are set up, and
`_cmdlines_from_proc` drops empty lines, so a reap in that window reads `[]`, signals nothing and unlinks the record.
Both failing tests call `reap` a few ms after `Popen`. Evidence (`evidence/55-14/reap-probes-and-gates.txt`, scripts
beside it): `probe_exec.py` 2/300 empty reads at no load (reviewer 7/300 and 4/300; with `--init` 0/300 and 1/300 at
6 burners); `probe_reap.py` an empty window up to 6.18 ms with 6 CPU burners and **41.89 ms** with 60. **The
test-level failure did not reproduce** in the CI image (old reap: 600 runs at 6 burners, 180 at 60, all passed): the
reap's own walk of `/proc` usually outlasts the window. The fix is in `reap`, not the tests, because production reaps
right after a start too (cancel paths, `jobs.py:196`, `library_service.py:1090`). Phase 55's changes to
`testexec/recording.py` and `verification_service.py` only add binding refusals, off this path. Both tests share the
cause: **Phase 54 backlog §5 (`test_reap_kills_a_recorded_group_that_is_still_ours`, #7429033) is closed** by
`9cd33d52`. Neither test was changed, skipped or marked.

### Tests

- `test_document_records.py` (+6, 52): a real-worker workflow `same` whose 2nd execution rewrites `round.json` with the
  same size and `os.utime` back to the first mtime (two records); same size + mtime and chmod; over the bound in place
  and replaced; the bound and `fingerprint_max=None`; the memo (reads counted, `time.time_ns` shifted, prune).
- `test_testexec_procs.py` (+2, 14): a first read inside the exec window → the re-read stops the group; an unmatched
  live group is read twice and left alone, a gone group once.
- **Fail-first:** on the old code all 6 new docs tests and both reap tests fail, the worker test with the CI shape
  `[('tick', 1)] == [('tick', 1), ('tick', 2)]` and the reap tests `[] == [pgid]` (dev on macOS with
  `PYTHONDONTWRITEBYTECODE=1`; reviewer on a fresh `git archive` of `3e1effaf`).
- **Gates:**
  - macOS: `ruff check genesis` clean; full pytest **2414 passed, 4 skipped** at `9cd33d52` (dev); reviewer at `d6cea8db`
    2413 passed, 4 skipped, 1 deselected (`test_server_readiness_probe`, hangs while colima's docker is up).
  - python:3.13 image (colima aarch64, 6 CPU burners, a fresh pytest per run, `-x -p no:randomly`) at `d6cea8db`:
    `test_document_records.py` **20/20** (52 passed each), `test_apwt_client.py` **20/20** (20), `test_testexec_procs.py`
    **20/20** (14), both without and with `--init`. Before `d6cea8db` the docs file was 0/20 there (the in-place test).
  - python:3.13 image, full suite once, `--init`: ruff clean; **2 failed, 2344 passed, 72 skipped** (599 s). The 2 are
    `test_sail_cli.py::test_extract_sail_binary_for_host` and `::test_install_appian_dev_bundle_installs_both`
    (aarch64 host; failed in 55-12's colima run too, passed on CI in #7556336). 2344 + 2 = CI's 2336 + 2 failed + the 8
    new tests. A first full run in a container whose PID 1 was `sleep infinity` failed 3 more testexec tests (killed
    grandchildren stayed zombies; the same 3 failed there with `3e1effaf`'s `procs.py`): not a valid run.

### Review

`reviews/55-14-review.md`: **SHIP**, no blockers or majors, conditional on the `--init` full run (met above). m1 (save
the probes and their outputs) done: `evidence/55-14/`. n1 (a group whose leader is an unwaited zombie costs one 0.25 s
pause) left as is.

### Decisions / deviations

No ADR deviation.
1. **Bound 1 MiB**, not the spec's "e.g. 4 MB": measured (table above).
2. **The hash memo** is not in the spec: without it every scan read every small file (≈ 10× the stat walk).
3. **`checkout/` is hashed.** The spec says the hashing never touches `checkout/`, but `checkout/` was never an
   excluded tree (55-05 diffs it: `_launch` records `checkout/package.json`); only `_kiro/ .kiro/ _toolcalls/ _prompts/
   .pids/` are excluded, and they stay so. The real checkout is small (29 files in the 300-file run, `node_modules` a
   symlink the scan does not follow). The spec sentence is wrong, not the code.
4. **Fix in `reap`** (one 0.25 s re-read, only for a live, unmatched group) rather than in the tests.
5. Gates ran in a long-lived container; the CI image's own job shell reaps orphans, so the valid full run is the
   `--init` one.

### Lesson candidates

1. **A same-size rewrite can keep its mtime on Linux**: size + mtime is not a change detector at task granularity
   (coarse kernel tick; macOS APFS hides it with ns stamps). Force the case in a test with `os.utime`, and to keep the
   cost, hash only files that were not settled when last hashed (git's racy-clean rule).
2. **`Popen` returning does not mean `/proc/<pid>/cmdline` is set**: the child can still be inside `execve`, where it
   reads empty; a check right after a spawn that keys on the command line must read again before it decides (extends
   L-104).
3. **A long-lived scratch container needs `--init`**: with `sleep infinity` as PID 1 orphans stay zombies, and tests
   that check a killed grandchild is gone fail for reasons CI never has (extends L-112).
4. **A Linux-only test failure can come from the test's own forced case**: the in-place over-the-bound test passed on
   macOS and failed 20/20 in the image, because there a rewrite straight after a write keeps the same ctime, the
   documented limit; run new tests in the CI image before the release commit (L-112).

### Code-map changes (for genesis-docs, bible/03)

- `genesis/runs/writes.py`: `FINGERPRINT_MAX_BYTES`, `SETTLED_NS`, `Memo`, `_change_key`; `scan(fingerprint_max=,
  memo=)` returns `(bytes, mtime_ns, key)`; `WriteTracker._memo`.
- `genesis/runs/documents.py`: the view scans with `fingerprint_max=None`.
- `genesis/testexec/procs.py`: `_names_a_marker`, `_REREAD_S`.
- Backlog: Phase 54 follow-ups §5 closed by `9cd33d52`.

### For 55-12 (genesis-release)

Push genesis master from `d6cea8db` (3 commits on `3e1effaf`), wait for the master pipeline, then ask for the tag. The
x86_64 master pipeline is the first run of these commits on CI's own runner.
