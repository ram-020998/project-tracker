# Review 55-14 — base 3e1effaf, head d6cea8db (genesis-review, 2026-11-24)

What this change does: the worker's write diff (`genesis/runs/writes.py`) adds a change key to each file's
`(size, mtime_ns)`: a 64-bit blake2b of the bytes up to 1 MiB, else `(st_ctime_ns, st_ino)`. A same-size rewrite
inside one coarse Linux mtime tick is now recorded, and a per-tracker memo keeps a warm scan at the cost of the stat
walk. `procs.reap` reads a live group a second time (after 0.25 s) when the first read names no marker, because Linux
can show an empty `/proc/<pid>/cmdline` right after `Popen` returns. The documents view asks for no change key.

Commits reviewed: `ad8f7eda` (writes change key), `9cd33d52` (reap re-read), `d6cea8db` (Linux-safe test waits);
`git rev-parse --short HEAD` = `d6cea8db`; tree clean. 5 files, +276 / −22.

## Checklist

ADRs (areas runs-worker, browser-testing, release-ci, security):
- [N/A] ADR-001, 008, 009, 011, 019, 021, 023, 024, 025, 026, 028, 029, 030, 031, 032, 033, 034, 035, 037, 041, 045,
  046, 047, 049, 054, 061, 062, 063, 065, 066, 068, 069, 073, 074, 076, 078, 080, 081, 084, 085, 086, 087 — no graph,
  gate, HITL, API, chat, trust, Kiro launch, persistence, schema, schedule, IA or version change. The diff touches
  only the worker's file diff (`writes.py`), the documents view's call to it (`documents.py:161`) and the reap
  predicate (`procs.py:310-337`).
- [OK] ADR-010 / ADR-018 — state stays small: the change key lives only in the worker's in-memory snapshot and memo
  (`writes.py:82-84`, `:169`); `record()` still forwards only `path`, `bytes`, `mtime` (`writes.py` `record`), so no
  digest reaches an event, state or chat.
- [OK] ADR-012 — the hashing runs in the worker process (`worker.py:305` builds the tracker); the app process's
  documents view never reads a file (`documents.py:161`, `fingerprint_max=None`; asserted in
  `test_the_scan_fingerprints_only_up_to_the_bound`).
- [OK] ADR-022 — reads only under the run root; no new writes.
- [OK] ADR-082 / ADR-083 — the reap still signals only a group in which a process names a recorded marker; the second
  read keeps that rule (`procs.py:316-321`); a recycled, unmatched pgid is left alone
  (`test_reap_reads_an_unmatched_group_twice_and_a_gone_group_once`, asserts `_alive(ll.pgid)` after the reap).
- [OK] ADR-077 — review run with the projected agent; no `--trust-all-tools`.

Lessons:
- [OK] L-066 — no per-tick fold added; the scan runs at task start/finish only. Cost measured on real run folders
  (`evidence/55-14/measure_scan-macos.txt`): 300-file test-execution run stat-only 2.07 ms, tracker first scan
  26.95 ms, warm 1.91 ms; the 304-file library replay 9.02 / 38.12 / 10.96 ms (not quoted in the brief, still small);
  CI image 0.78 / 13.87 / 0.93 ms.
- [OK] L-083 — the fixtures use the real shapes: the worker test runs a real worker and a real 1-byte `round.json`
  rewrite; the unit tests read real `os.stat` values (`test_the_scan_fingerprints_only_up_to_the_bound` compares
  against `os.stat(...).st_ctime_ns, st_ino`).
- [OK] L-104 — matching is still on full command lines (`_group_commands` unchanged); the `ps` failure logging is
  unchanged; the fix sits in `reap`, the shared code, not in a test.
- [OK] L-107 — `reap` still never raises and still unlinks every record (`procs.py:337-343`); cancel/terminal reaps
  of a just-started child no longer drop it (the exact L-107 "keep cancel reaping late children" case).
- [OK] L-110 — fail-first checked independently: I extracted `3e1effaf` with `git archive` into a fresh
  `/tmp/r5514-base2` (no stale `.pyc`), overlaid the head test files, ran with `PYTHONPATH` on that tree (worker
  subprocess included; `writes.__file__` printed the base path). `test_document_records.py`: 6 new tests fail, the
  worker test with the CI shape `[('tick', 1)] == [('tick', 1), ('tick', 2)]`. `test_testexec_procs.py`: the 2 new
  tests fail (`[] == [34044]`), 12 pass.
- [OK] L-112 — the two test files ran 20× each in the python:3.13 image (`/tmp/colima/gr-55-14/out/g-docs-*`,
  `g-procs-*`, `g-apwt-*`: 52 / 14 / 20 passed in every run I sampled, no file contains a failure). The full suite in
  the CI image under `--init` is **not yet run** (see Not checked); the first full run (no init) failed 5, see below.
- [OK] L-094 — every caller of the changed functions read: `scan` (`documents.py:161`, `WriteTracker` default),
  `WriteTracker(...)` (`worker.py:305`, tests), `Stat` consumers (`documents.py:197-199` read `st[0]`, `st[1]` only;
  `record()`); `reap` callers (`recording.py:299,357,477,483`, `jobs.py:196,202`, `library_service.py:1090,1153`,
  `apwt/factory.py:115`, `manager.py:341`) all get the same signature and a pause of at most 0.25 s per live,
  unmatched record.
- [N/A] L-003, 004, 005, 008, 009, 016, 017, 018, 020, 021, 023, 025, 026, 027, 030, 033, 044, 045, 050, 051, 056,
  057, 058, 059, 060, 061, 062, 065, 081, 087, 088, 089, 090, 091, 092, 093, 096, 097, 098, 099, 100, 101, 103, 105,
  106, 108, 109, 111, 113, 115, 116, 117, 119, 120, 121, 122, 124, 125 — no SSE, event kind, DB write, migration,
  web, trust, release, pin or loop-decision change. (L-056/057/030 apply at 55-12's release, not here: no web file
  changed, so no bundle rebuild.)

Gates:
- [OK] `cd genesis && .venv/bin/ruff check genesis` — "All checks passed!" (ruff 0.15.20, at d6cea8db).
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` at d6cea8db (macOS) — **2413 passed, 4 skipped,
  1 deselected** in 829.90 s. Deselected: `tests/test_config.py::test_server_readiness_probe`, which hangs on this
  machine while colima's docker is up (it runs a real `docker` handshake for `appian-atlas`); not touched by this diff
  and it passes on a host without a live docker. 2413 + 1 = the dev's 2414.
- [OK] Targeted, macOS, head: `test_document_records.py test_testexec_procs.py test_apwt_client.py` — 86 passed.
- [N/A] playwright-appian, genesis/web, genesis-workflows gates — no file in those trees changed.

## Judgement on the brief's open questions

- **1 MiB instead of ~4 MB.** Accepted. The spec said "e.g.", and the measurements show 1 MiB costs no more than 4 MiB
  on the 300-file run and less on the 304-file replay (35 vs 53 ms first scan); the files over 1 MiB in real runs are
  report zips and traces, which are written by atomic replace or change size, both seen by `(ctime, ino)` / size.
- **The memo (not in the spec).** Accepted, and correct. Reuse needs the same `(size, mtime, ctime, ino)` and
  `ctime < hashed_at − 3 s`, with `hashed_at` taken before the read (`writes.py:98`). Any write after the hash moves
  ctime to ≥ about `hashed_at` (the kernel's coarse clock lags by at most a tick), so it can never equal a ctime that
  was 3 s older. A write between the stat and the read stores the new digest under the old signature, and the next
  stat no longer matches it, so nothing stale is reused. The only gap is the documented one: a filesystem stamping
  from a clock more than 3 s behind. Without the memo, every scan read every small file (27.6 ms vs 2.07 ms).
- **checkout/ is hashed.** Accepted; the spec's sentence was wrong, not the code. `EXCLUDED_DIRS` (`writes.py:70`)
  has never held `checkout` (55-05 diffs it on purpose). The real checkout is small: the 300-file run has 29 files
  there, no `.git`, and `node_modules` is a symlink, which the scan does not follow. The As built should correct the
  spec text.
- **The documented limits** (over the bound: a same-size in-place rewrite within one ctime tick is missed; a chmod
  reads as a write) are stated in the docstring and are the limits the spec asked to record. d6cea8db's tick wait in
  the in-place test only stops the test from asserting the documented limit away; it does not hide a bug.
- **Is the reap cause shown?** Yes, at the mechanism level. Python's `Popen` returns when the CLOEXEC error pipe
  closes, which happens inside `execve` before the new image's argument area is set, and `/proc/<pid>/cmdline` reads
  empty in that window (`_cmdlines_from_proc` drops empty lines, so the first read is `[]`). I re-ran
  `probe_exec.py 0` in the python:3.13 container: **7/300 and 4/300 empty reads** straight after `Popen`, no load.
  Both failing tests call `reap` within a few ms of `Popen` (`test_apwt_client.py:_fake_daemon` → `open_session` →
  `reap`; `test_testexec_procs.py:75`). The test-level failure did not reproduce in 780 runs, so the link from this
  window to #7556336 / #7429033 rests on the mechanism and on no other reading fitting `[] == [pid]` for a live
  `sleep 60` child. That is enough for me.
- **Fix in reap, not the test.** Right: production reaps right after a start on cancel paths
  (`jobs.py:196`, `library_service.py:1090`), and the fix covers them. One re-read after 0.25 s against a measured
  window of up to 42 ms is a reasonable bound. Phase 54 backlog §5 can be closed by the As built.

## Findings

### Blockers
none

### Majors
none

### Minors
- m1 **The probe numbers behind §2 are not saved as evidence** (`/tmp/colima/gr-55-14/out/`) — What: the 2/300 empty
  reads and the 41.89 ms longest window are quoted in the commit message and the `_names_a_marker` docstring, but
  `probe_exec.py` / `probe_reap.py` printed to the console and no output file holds them; `/tmp` is also scratch.
  Problem: the only evidence for the cause of a fix whose test-level failure never reproduced is not recorded
  anywhere durable. Fix: copy the two probes and their outputs (mine: `load=0 n=300 ok=293 empty=7`,
  `ok=296 empty=4`) into `evidence/55-14/` and cite them in the As built. If skipped: a later reader cannot check why
  the re-read exists.

### Nits
- n1 **A zombie leader costs a pause** (`procs.py:316-320`) — a group whose only process is a not-yet-waited zombie
  reads alive to `killpg(0)` and has an empty cmdline, so `reap` sleeps 0.25 s and then correctly leaves it. No
  production path keeps such a zombie that I found (the apwt daemons are detached and reaped by init); no change
  needed, mention it in the docstring only if you touch it again.

## Not checked
- **The full genesis suite in the CI image under `docker run --init`** (spec §3, L-112). Not run when I looked:
  container `gr5514` (re-created 18:35 IST with `HostConfig.Init=true`) had no pytest running at 19:45 IST, and
  `out/full-pytest.txt` is still the first, no-init run (18:33: 5 failed, 2341 passed, 72 skipped). That run's 3
  testexec failures (`test_runner_kills_its_process_group_on_timeout_and_scrubs_reports`,
  `test_stop_with_actions_...`, `test_refresh_treats_a_closed_window_...`) all fail on `_alive(pid)` staying true
  after a kill, which fits orphaned grandchildren left as zombies under a `sleep infinity` PID 1; I did not verify
  the dev's statement that they fail identically on the old `procs.py`. The 2 `test_sail_cli` failures are the known
  aarch64-host ones (55-12's colima run).
- The real master pipeline on Linux x86_64 (55-12 runs it after the push).
- `test_server_readiness_probe` at head on macOS (deselected; hangs with a live docker, unrelated to this diff).
- The As built (not written yet): it should record the gate counts above, the 1 MiB bound and its cost, the limits,
  the spec correction about `checkout/`, and close Phase 54 backlog §5.

## Verdict: SHIP (code review and macOS gates at `d6cea8db`)

There are no blockers or majors. Both fixes are in the shared code, both regression tests fail on the old code (checked
on a fresh extract of `3e1effaf`), ruff is clean and the macOS suite is green (2413 passed, 1 unrelated deselect).
The ship is conditional on one gate the dev still owes: the full suite in the python:3.13 image under `--init` must
show no failure other than the two known aarch64 `test_sail_cli` ones. If any testexec test still fails there, this
becomes NEEDS_CHANGES. m1 should be done in the As built before 55-12 resumes.
