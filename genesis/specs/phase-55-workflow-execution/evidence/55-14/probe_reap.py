"""55-14 probe: the real procs.start_long_lived + procs.reap, reap called right after the start (as the tests do).
Counts reaps that return [] for a live child that names its marker, and how long /proc/<pid>/cmdline stays empty
after Popen returns. Run in the python:3.13 CI image."""
import multiprocessing as mp
import sys
import tempfile
import time
from pathlib import Path

from genesis.testexec import procs


def burn():
    while True:
        pass


def run(n, load, gap_s):
    hogs = [mp.Process(target=burn, daemon=True) for _ in range(load)]
    for h in hogs:
        h.start()
    missed = 0
    empty_reads = 0
    longest_empty = 0.0
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        orig = procs.kill_group
        procs.kill_group = lambda pgid, grace=0: orig(pgid, grace=0.2)   # the probe kills afterwards itself
        for i in range(n):
            marker = str(d / f"ws{i}")
            ll = procs.start_long_lived([sys.executable, "-c", "import time; time.sleep(30)", marker], cwd=d,
                                        env=procs.minimal_env(), pid_dir=d / ".pids", markers=[marker])
            # how long does the cmdline read empty? (a second read path, not the reap's)
            t0 = time.monotonic()
            while not open(f"/proc/{ll.pgid}/cmdline", "rb").read():
                empty_reads += 1
                if time.monotonic() - t0 > 2:
                    break
            longest_empty = max(longest_empty, time.monotonic() - t0) if empty_reads else longest_empty
            ll.proc.kill()
            ll.proc.wait()
            for f in (d / ".pids").glob("*.json"):
                f.unlink()
            # the race itself: reap straight after the start
            ll = procs.start_long_lived([sys.executable, "-c", "import time; time.sleep(30)", marker], cwd=d,
                                        env=procs.minimal_env(), pid_dir=d / ".pids", markers=[marker])
            if gap_s:
                time.sleep(gap_s)
            if procs.reap(d / ".pids") != [ll.pgid]:
                missed += 1
            ll.proc.kill()
            ll.proc.wait()
        procs.kill_group = orig
    for h in hogs:
        h.terminate()
    print(f"n={n} load={load} gap={gap_s}s reap_missed={missed} empty_reads={empty_reads} "
          f"longest_empty={longest_empty * 1000:.2f}ms", flush=True)


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    for load in (sys.argv[2:] or ["0", "6"]):
        run(n, int(load), 0)
