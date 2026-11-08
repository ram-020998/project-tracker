# Review 51-13 reap fix — base 8e5bacc, change 2e92fca (genesis-review, 2026-11-08)

Scope: one local commit `2e92fca` on genesis master (`genesis/testexec/procs.py`, `tests/test_testexec_procs.py`),
the fix for the Linux-only process-group reap failures in CI pipeline #7335323 (10 failures). The tag `v0.81.0` points
at `8e5bacc` and is local only. This review did not touch it.

## What changed

- `_group_commands(pgid)` now reads `/proc` on Linux (`_cmdlines_from_proc`) and falls back to
  `ps -A -ww -o pgid=,command=` elsewhere (`_cmdlines_from_ps`).
- A `ps` that cannot run (OSError, SubprocessError) or that exits non-zero now logs a WARNING. Before, the failure
  was swallowed into `[]`.
- `reap()` itself is unchanged (`procs.py:300-318`).

## Evidence (reproduced by the reviewer)

| Check | Result |
|---|---|
| Linux `python:3.13`, procps-ng 4.0.4, `COLUMNS=80`, `run.sh base` | **14 failed, 5 passed**: the 10 CI failures, plus the 4 new tests |
| same, `run.sh fixed` | **19 passed** |
| `run.sh fixed` without `COLUMNS` | **19 passed** |
| Probe P1 (Linux): executable named `a) b (c`, so stat reads `15 (a) b (c) S 14 15 15 …`; group of 2 (leader + `sleep` child); 200-char padding before the marker | `_cmdlines_from_proc` finds both processes and the marker; `reap` returns `[pgid]`; group empty afterwards |
| Probe P2 (Linux): as user `nobody`, read a root-owned process's cmdline | marker seen (cmdline is world-readable; no PermissionError path hit) |
| Probe P3: a pgid that matches nothing (999999), and pgid 0 (kernel threads) | `[]` and `[]` |
| Probe P4 (mutation, container copy only): drop `-ww` from the ps argv | `test_the_ps_fallback_also_reads_a_marker_past_column_80` **fails**, so the test pins `-ww` on Linux |
| Probe P5: `tests/test_testexec_procs.py` ×10 under `COLUMNS=80` on Linux | 10/10 runs `10 passed` (no flake) |
| macOS: the same 19 tests with `COLUMNS=80` | 19 passed |
| macOS: full `pytest` (`--deselect tests/test_config.py::test_server_readiness_probe`, the known hang, 51-18 O1) | **1836 passed, 1 deselected** |
| macOS: `ruff check genesis tests/test_testexec_procs.py` | All checks passed |
| macOS: `ps -A -ww -o pgid=,command=` | exit 0, empty stderr, longest line 8460 chars (no warning on the normal path) |

The probe script is `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/.reap-review/probe.sh`. It is throwaway and
untracked, sits outside the repos, and only mutates a copy inside the container.

**Not verified:** I did not run the full suite on Linux (only the 19 reap tests and the procs file), and CI has not
re-run on `2e92fca`. Release must confirm a green genesis pipeline on this commit.

## Answers to the questions in the brief

- **comm with spaces or parens.** `stat.rpartition(")")[2].split()` takes the fields after the last `)`, and
  `fields[2]` is pgrp (`procs.py:259-261`). This is correct for any comm, because the kernel always ends comm with
  the final `)`. Decoding with `errors="replace"` cannot add a `)`. Probe P1 confirms it.
- **Races.**
  - A process that exits between `iterdir` and the reads raises OSError, which is skipped (`procs.py:263-264`).
  - A zombie has an empty cmdline and is skipped.
  - A pid can be recycled between the `stat` read and the `cmdline` read. A false match then needs the new process
    to name one of our markers, so the result is never a wrong kill.
  - The check-then-kill window in `reap` (match, then `killpg`) existed before this change and is unchanged.
- **Kernel threads.** Their pgrp is 0 and their cmdline is empty, so they never match. `reap` also refuses
  `pgid <= 1`.
- **Permission errors.** `/proc/<pid>/stat` and `/proc/<pid>/cmdline` are world-readable (probe P2). Under
  `hidepid=1|2`, other users' entries are invisible or raise OSError. Both are skipped, and neither can be one of
  our groups anyway.
- **"Only our own processes".** Still holds. `reap` signals only when `pgid > 1` and a process in the group names a
  recorded marker (`procs.py:313`). Full lines widen matches only to lines that really contain the marker. The old
  truncation was the bug, not a safety margin.
- **Other code that depends on the old ps output.** No production code does.
  - All callers go through `reap()`: `runs/manager.py:174`, `testexec/jobs.py:196`, `testexec/recording.py:294,348,450,456`,
    `integrations/apwt/factory.py:115` and `testexec/library_service.py:1090`.
  - `scripts/spikes/51-06/live_report.py:255` calls `procs._group_commands`, whose signature (`int -> list[str]`) is
    unchanged.
  - Spikes 51-03 and 51-07 run their own `ps` for evidence. They are out of scope.
- **Logging.** Nothing is logged on the normal path. The `/proc` path never logs, and `ps` logs only on OSError,
  SubprocessError or a non-zero exit.

## Checklist (`genesis-ctx check --since 8e5bacc --repo genesis`; the files map to no area, so only always-on release-ci + security)

### ADRs
- [N/A] ADR-011: no agent node touched.
- [N/A] ADR-019: no genesis-core or `CORE_MAJOR` change.
- [OK] ADR-026: no network surface or bind change. A local subprocess helper only.
- [N/A] ADR-046: install and update flow untouched.
- [N/A] ADR-063, ADR-065, ADR-074: no collaboration or KB sync code.
- [OK] ADR-077: this review used `genesis-ctx check` and the diff, no bulk docs, no `--trust-all-tools`.
- [OK] ADR-080: no package metadata or internal dependency change (diff touches only the two files).

### Lessons
- [N/A] L-017: no chat trust.
- [OK] L-025, L-027: ruff is unchanged in `pyproject.toml` (not in the diff), and `ruff check` is clean.
- [N/A] L-030: no `web/**` change. The frontend job is not needed for this fix.
- [N/A] L-045: no chat CLI surface.
- [OK] L-051: the fix was verified against the real CLI. procps-ng 4.0.4 in `python:3.13` and BSD ps on macOS were
  both probed, not assumed.
- [OK] L-056: `git show --stat 2e92fca` lists both the implementation and the test file. The working tree is clean.
- [N/A] L-057: no pin moves in this commit. See the release note below.
- [N/A] L-087, L-088: not a doc migration, not a guard hook.
- [OK] L-089: the fix is one commit. I verified it with separate runs (base, fixed, mutation).
- [OK] L-092: no `tests/__init__.py` was added. The new `test_*` names are real tests.
- [N/A] L-098, L-099: no library presence or version-string behaviour touched.
- [N/A] L-100: no CI-variables API was used. I read only the failure list from the brief.

### Gates (no area gates are listed; the coding-standards §1 Python gates apply)
- [OK] ruff: clean.
- [OK] pytest (macOS): 1836 passed, 1 deselected.
- [OK] pytest (Linux, the reap set): 19 passed with and without `COLUMNS=80`.

## Findings

### Blockers
None.

### Majors
None. The fix comes with regression tests. `test_reap_matches_a_marker_past_column_80` fails on the base in Linux
with `COLUMNS=80` for the real reason (the marker is truncated away). The mutation probe P4 shows that
`test_the_ps_fallback_also_reads_a_marker_past_column_80` pins `-ww`.

### Minors
1. **The `/proc` parser has no direct unit test, and its tricky branch is exercised only on Linux.**
   - `_cmdlines_from_proc` (`procs.py:239-266`) hard-codes `Path("/proc")` and `sys.platform`. On macOS, where the dev
     ran the full suite, it returns `None` at line 247, so none of its parsing runs.
   - On Linux CI the tests cover it only with plain `python` comm values. The comm-with-`)` handling, the malformed
     stat line (`len(fields) < 3`, ValueError) and the empty-cmdline skip are covered only by this review's probe.
   - Fix: make the root a module constant (`_PROC_ROOT = Path("/proc")`) or a parameter. Add a platform-independent
     test over a fake procfs in `tmp_path` that covers:
     - stat `"42 (a) b (c) S 1 42 …"` with a matching cmdline;
     - an empty cmdline (a kernel thread or zombie);
     - a truncated or garbage stat;
     - an entry that vanishes (a missing `cmdline`).
2. **A Linux host with an empty or unmounted `/proc` silently skips the reap.**
   - `iterdir()` on an empty `/proc` succeeds with no entries, so the function returns `[]`, not `None`
     (`procs.py:249-252`). There is then no ps fallback and no warning.
   - `reap` reads that `[]` as "not ours" and drops the record. This is the same silent failure mode the commit
     message says it removes.
   - Practical impact is close to nil, because procps `ps` needs `/proc` too.
   - Fix: return `None` when `entries` is empty (a live procfs always lists at least our own pid). The `ps` path then
     runs and logs its failure.

### Nits
3. **The log assertion in `test_a_ps_failure_is_logged_not_swallowed` is weak**
   (`tests/test_testexec_procs.py:126-127`).
   - `"ps" in r.getMessage()` is true of any message containing "process groups", because "groups" contains "ps".
   - The test also fails on the base only through an AttributeError: its monkeypatch target `_cmdlines_from_proc`
     does not exist there, so the base failure is not behavioural. On the base the same failure path was a silent
     `return []`, so the test's intent is right.
   - Fix: assert the specific text, e.g. `"could not run ps"` / `"ps exited 1"`, or check `r.name == procs.__name__`
     plus the `exc_info` / returncode.
4. **A persistent ps failure would repeat its warning.**
   - It would log once per record per `reap`, and every 0.5 s in `TestingJobs._reap_until_done` (`jobs.py:179-181`)
     while a cancelled job drains.
   - This happens only off Linux and only when ps is broken, so it is acceptable. Rate-limiting can wait.
5. **The `test_reap_matches_a_marker_past_column_80` docstring overstates its reach.** It says "this FAILS on the old
   reader under procps". That is true, but it can catch the regression only on Linux. Saying "Linux-only signal; on
   macOS it passes either way" would set the right expectation for a future reader.

## Note for genesis-release (not a code finding)
`v0.81.0` points at `8e5bacc`, which lacks this fix. The release agent must ask the user whether to move the
unpushed local tag to the fixed commit or to cut `v0.81.1`, and must confirm a green genesis CI pipeline on the
tagged commit before any push.

## Verdict: **SHIP**

There are no blockers or majors, and every gate I ran is green. The fix is correct on Linux (real procps, `COLUMNS=80`)
and on macOS, and the "only our own processes" rule is intact. Minors 1–2 should be done in a follow-up, or in this
commit if the release is being redone anyway. Both are small. A green CI pipeline on the shipped commit is still
required (release's job).
