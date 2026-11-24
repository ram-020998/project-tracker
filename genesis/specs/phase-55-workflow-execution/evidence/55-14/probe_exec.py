"""55-14 probe: right after Popen(start_new_session=True) returns, what does /proc/<pid>/cmdline hold?
Counts reads that are empty or lack the marker (the reap would skip the group), with and without CPU load."""
import multiprocessing as mp
import os
import subprocess
import sys
import time


def burn():
    while True:
        pass


def main(n=300, load=0):
    hogs = [mp.Process(target=burn, daemon=True) for _ in range(load)]
    for h in hogs:
        h.start()
    marker = "/tmp/marker-55-14-xyz"
    empty = other = ok = 0
    for _ in range(n):
        p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(5)", "--root", marker],
                             start_new_session=True)
        raw = open(f"/proc/{p.pid}/cmdline", "rb").read()
        if not raw:
            empty += 1
        elif marker.encode() in raw:
            ok += 1
        else:
            other += 1
        p.kill()
        p.wait()
    for h in hogs:
        h.terminate()
    print(f"load={load} n={n} ok={ok} empty={empty} other={other}", flush=True)


if __name__ == "__main__":
    main(load=0)
    main(load=int(sys.argv[1]) if len(sys.argv) > 1 else 6)
