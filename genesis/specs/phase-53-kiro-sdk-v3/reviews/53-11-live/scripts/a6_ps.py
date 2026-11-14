"""A6: kiro-cli, kiro-cli-chat, the v3 engine (node) and MCP server processes, split into those under the 53-11 serve
(pid from :8770, or none) and everything else that points at the 53-11 state dir or has PPID 1 (orphans). ps -ww,
full command lines (L-104). Prints command names and the args that identify them, never env.
Usage: a6_ps.py <label>"""
import json
import subprocess
import sys

out = subprocess.run(["ps", "-A", "-ww", "-o", "pid=,ppid=,pgid=,command="], capture_output=True, text=True).stdout
procs = {}
for line in out.splitlines():
    parts = line.split(None, 3)
    if len(parts) == 4:
        pid, ppid, pgid, cmd = parts
        procs[int(pid)] = {"pid": int(pid), "ppid": int(ppid), "pgid": int(pgid), "cmd": cmd}
serve = subprocess.run(["lsof", "-nP", "-t", "-iTCP:8770", "-sTCP:LISTEN"], capture_output=True, text=True).stdout.split()
serve_pid = int(serve[0]) if serve else None


def is_kiro_like(cmd: str) -> bool:
    return any(k in cmd for k in ("kiro-cli", "kiro_cli", "kiro-agent", "genesis.mcp.", "lcp_mcp_server",
                                  "/tmp/genesis-53-11", "a5-fake"))


def under(pid: int, root: int) -> bool:
    seen = set()
    while pid and pid not in seen:
        if pid == root:
            return True
        seen.add(pid)
        pid = procs.get(pid, {}).get("ppid", 0)
    return False


ours, other = [], []
for p in procs.values():
    c = p["cmd"]
    if "a6_ps.py" in c or not is_kiro_like(c):
        continue
    short = c if len(c) < 160 else c[:160] + "…"
    rec = {**p, "cmd": short}
    if serve_pid and under(p["pid"], serve_pid) and p["pid"] != serve_pid:
        ours.append(rec)
    elif "/tmp/genesis-53-11" in c or p["ppid"] == 1:
        other.append(rec)
# the engine (node) runs in its own process group under kiro-cli-chat: include node children of our kiro processes
print(json.dumps({"label": sys.argv[1], "serve_pid": serve_pid, "under_serve": ours,
                  "not_under_serve_but_test_or_orphan": other}, indent=1))
