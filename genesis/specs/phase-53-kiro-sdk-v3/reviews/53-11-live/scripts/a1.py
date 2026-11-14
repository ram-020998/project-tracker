"""A1 driver: start one workflow on the 53-11 instance (:8770), wait for a terminal or gate status, then summarize
its events: per agent turn the node, credits and provenance; the tool ids called; the event kinds.
Usage: a1.py <workflow_id> '<inputs json>'   (or a1.py --summary <run_id>)"""
import json
import sys
import time

import httpx

BASE = "http://127.0.0.1:8770/api"
c = httpx.Client(base_url=BASE, timeout=60)


def summarize(run_id: str) -> dict:
    rec = c.get(f"/runs/{run_id}").json()
    evs = c.get(f"/runs/{run_id}/events", params={"limit": 20000}).json()
    evs = evs.get("events", evs) if isinstance(evs, dict) else evs
    kinds: dict[str, int] = {}
    turns, tools = [], []
    for e in evs:
        k = e.get("kind")
        kinds[k] = kinds.get(k, 0) + 1
        p = e.get("payload") or {}
        if k == "agent.result":
            u = p.get("usage") or p
            turns.append({"node": e.get("node"), "credits": u.get("credits", p.get("credits")),
                          "provenance": u.get("provenance", p.get("provenance")),
                          "stop_reason": p.get("stop_reason"), "error": p.get("error")})
        if k == "agent.tool_call":
            tools.append({"node": e.get("node"), "tool": p.get("tool_name") or p.get("name"),
                          "tool_id": p.get("tool_id") or p.get("toolId"), "title": p.get("title")})
    prov = c.get(f"/runs/{run_id}/provenance").json()
    return {"run_id": run_id, "workflow": rec.get("workflow_id"), "status": rec.get("status"),
            "cursor": rec.get("cursor"), "kinds": kinds, "agent_turns": turns, "tool_calls": tools,
            "run_credits": prov.get("credits"), "credits_provenance": prov.get("credits_provenance"),
            "event_count": prov.get("event_count")}


if sys.argv[1] == "--summary":
    print(json.dumps(summarize(sys.argv[2]), indent=1))
    sys.exit(0)

wf, inputs = sys.argv[1], json.loads(sys.argv[2] if len(sys.argv) > 2 else "{}")
r = c.post("/runs", json={"workflow_id": wf, "inputs": inputs})
r.raise_for_status()
run_id = r.json()["run_id"]
print("run_id", run_id, flush=True)
t0 = time.time()
while True:
    rec = c.get(f"/runs/{run_id}").json()
    st = rec.get("status", "")
    if st in ("done", "failed", "cancelled") or st.startswith("awaiting_input"):
        break
    if time.time() - t0 > 3000:
        print("timeout waiting", st)
        break
    time.sleep(5)
print("elapsed_s", round(time.time() - t0, 1), flush=True)
print(json.dumps(summarize(run_id), indent=1))
