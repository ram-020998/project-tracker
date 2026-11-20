# Backlog — Phase 54 follow-ups (Schedules, custom agents, fixes and UX revamps)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-20 by the spec agent with the two items found in 54-10's
> round 2 (D52). At the Phase 54 write-back genesis-docs appends the umbrella §9 Deferred list
> (`specs/phase-54-schedules-and-fixes.md`) and the build and release findings (54-02..54-12 As built, 54-11 As run).

## 1. m7 — a one-time schedule paused during its run gets a false "missed" row on Resume (54-10 round 2)

- **Case:** a `once` schedule fires; while its run is still in flight the user pauses the schedule; after the run ends
  the user resumes it. Resume records a second row, `missed`, for the slot that already ran, and the Schedules list then
  shows the schedule's last result as **Missed**.
- **Repro:** `/tmp/54-10-probe/once_resume2.py` (genesis-review, 2026-11-20; the script is not in a repo, rebuild it
  from this description if it is gone).
- **Cause:** `ScheduleStore.set_pause` (`genesis/runtime/schedule_store.py`) applies 54-12's m1 rule (a past `once`
  resumed → `missed`, completed) without checking whether that slot already fired.
- **Fix direction:** in `set_pause`, record `missed` only when the slot has no `schedule_runs` row that fired;
  otherwise mark the schedule completed with no new row. Regression test from the repro.
- **Why deferred:** the user's choice (D52): shipped as a known issue, named in the 54-11 release notes.

## 2. The parser's bundle count depends on filesystem order (54-10 round 2, python:3.13 run)

- **Symptom:** `test_parse_returns_populated_result` finds 179 bundles instead of 174 when the suite runs in
  `python:3.13` under colima; on macOS and in the amd64 CI it finds 174.
- **Cause (reviewer's reading):** the parser walks the unzipped package with `os.walk` (`packages/genesis-appian-parser`),
  whose order depends on the filesystem; bundle assembly is order-sensitive.
- **Why it matters:** the same package can produce a different KB on different machines (a correctness bug, not only an
  ordering nit). It predates Phase 54; the parser has not changed since v0.82.0.
- **Fix direction:** sort the walk (directories and files) and any set iteration that feeds bundle assembly; add a test
  that parses one package with two different walk orders and expects identical bundles. Check whether `KB_FORMAT_VERSION`
  needs a bump if stored bundles change.
