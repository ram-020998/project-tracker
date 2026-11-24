"""55-14 §1: the cost of the write tracker's scan with a content fingerprint, on the real run folders.

Run with the genesis dev venv: ``python measure_scan.py [runs root] [repeats]`` (default ``~/Genesis/runs``, 50).
It lists every run folder (``<workflow>/<run>``), ranks them by files outside the excluded trees and by bytes a
fingerprint would read, and times ``writes.scan`` (warm cache, the median and max of ``repeats``) with no key
(the 55-05 stat-only cost), at 256 KiB, 1, 4 and 16 MiB bounds, and with the stat key only (``fingerprint_max=-1``);
then the worker's ``WriteTracker`` (the shipped bound): its first scan (empty memo) and a second one (memo warm).
"""
from __future__ import annotations

import statistics
import sys
import time
from pathlib import Path

from genesis.runs.writes import WriteTracker, scan

MIB = 1024 * 1024


def timed(root: Path, repeats: int, **kw) -> tuple[float, float]:
    out = []
    for _ in range(repeats):
        t0 = time.perf_counter()
        scan(root, **kw)
        out.append((time.perf_counter() - t0) * 1000)
    return statistics.median(out), max(out)


def main() -> None:
    runs = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else Path("~/Genesis/runs").expanduser()
    repeats = int(sys.argv[2]) if len(sys.argv) > 2 else 50
    rows = []
    for wf in sorted(p for p in runs.iterdir() if p.is_dir() and not p.name.startswith(("spike-", "probe-"))):
        for run in sorted(p for p in wf.iterdir() if p.is_dir()):
            files = scan(run, fingerprint_max=None)
            sizes = [st[0] for st in files.values()]
            rows.append((run, len(sizes), sum(sizes), sum(s for s in sizes if s <= 4 * MIB),
                         max(sizes, default=0), sum(1 for s in sizes if s > 4 * MIB)))
    print(f"{len(rows)} run folders under {runs} (spike-* and probe-* left out: not workflow runs)")
    by_count = sorted(rows, key=lambda r: -r[1])[:3]
    by_bytes = sorted(rows, key=lambda r: -r[3])[:3]
    print("largest file over all runs: %.1f MiB; runs with a file over 4 MiB: %d"
          % (max(r[4] for r in rows) / MIB, sum(1 for r in rows if r[5])))
    seen = set()
    for run, n, total, hashed, biggest, over in [*by_count, *by_bytes]:
        if run in seen:
            continue
        seen.add(run)
        print(f"\n{run.parent.name}/{run.name}: {n} files, {total / MIB:.2f} MiB, {hashed / MIB:.2f} MiB <= 4 MiB, "
              f"largest {biggest / MIB:.2f} MiB, {over} over 4 MiB")
        for label, kw in [("stat only (55-05)", {"fingerprint_max": None}),
                          ("stat key, no read", {"fingerprint_max": -1}),
                          ("fingerprint <= 256 KiB", {"fingerprint_max": MIB // 4}),
                          ("fingerprint <= 1 MiB", {"fingerprint_max": MIB}),
                          ("fingerprint <= 4 MiB", {"fingerprint_max": 4 * MIB}),
                          ("fingerprint <= 16 MiB", {"fingerprint_max": 16 * MIB})]:
            med, mx = timed(run, repeats, **kw)
            print(f"  {label:24s} median {med:7.2f} ms   max {mx:7.2f} ms")
        # the worker's tracker (1 MiB bound): its first scan reads every small file; later scans reuse the memo
        first, warm = [], []
        for _ in range(repeats):
            t = WriteTracker(run)
            t0 = time.perf_counter()
            t.snapshot()
            first.append((time.perf_counter() - t0) * 1000)
            t0 = time.perf_counter()
            t.snapshot()
            warm.append((time.perf_counter() - t0) * 1000)
        for label, xs in [("tracker, first scan", first), ("tracker, memo warm", warm)]:
            print(f"  {label:24s} median {statistics.median(xs):7.2f} ms   max {max(xs):7.2f} ms")


if __name__ == "__main__":
    main()
