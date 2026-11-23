"""55-05: record the 10 real runs of 55-01 §4.2 as categorizer fixtures (paths, sizes, mtimes, the DOC_KINDS rows
with their payloads reduced to the fields the categorizer reads, the workflow's yaml artifacts/inputs_schema/graph
nodes). No file contents, no prompt text, no validator messages (D19: no memory text in any commit)."""
import json
import os
import sqlite3
import sys
from pathlib import Path

import yaml

DB = "/tmp/gd-55-05/genesis.db"          # an online .backup copy of ~/.genesis/genesis.db (L-125)
RUNS = Path.home() / "Genesis/runs"
LIB = Path.home() / ".genesis/library/workflows"
OUT = Path(sys.argv[1])
IDS = ["ux-design-analysis/r-d945d439d221", "technical-design-analysis/r-d5ed99071d49",
       "feature-breakdown-analysis/r-f9a818a124cb", "story-design-analysis/r-0aa082031405",
       "story-implementation/r-fb5a9cd14f72", "agent-prompt/r-87781054aa00", "memory-consolidation/r-ea0fcbed1c4c",
       "test-design-analysis/r-cbf4ee22a3da", "test-execution/r-6f190dcfbac4", "sync-application/r-ea9479eee17e"]
KEEP = {
    "agent.prompt": ("prompt_ref", "iteration", "attempt"),
    "validator.result": ("validator", "ok"),
    "tool_output.recorded": ("ref", "tool", "bytes"),
    "artifact.saved": ("document", "ref"),
}

con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
OUT.mkdir(parents=True, exist_ok=True)
for rid in IDS:
    wid, run_id = rid.split("/")
    root = RUNS / rid
    files = []
    for dp, dns, fns in os.walk(root):
        for fn in fns:
            p = Path(dp) / fn
            if p.is_symlink():
                continue
            st = p.stat()
            files.append([p.relative_to(root).as_posix(), st.st_size, st.st_mtime_ns])
    files.sort()
    events = []
    for r in con.execute("SELECT seq, node, kind, payload, ts FROM run_events WHERE run_id=? AND kind IN "
                         "('agent.prompt','validator.result','tool_output.recorded','artifact.saved','custom') "
                         "ORDER BY seq", (run_id,)):
        p = json.loads(r["payload"] or "{}")
        kind = r["kind"]
        if kind == "custom":
            d = p.get("data") if isinstance(p.get("data"), dict) else {}
            if d.get("type") not in ("tool_output.recorded", "artifact.saved"):
                continue
            keep = {k: d[k] for k in ("type", "node", *KEEP[d["type"]]) if k in d}
            p = {"data": keep}
        else:
            p = {k: p[k] for k in KEEP[kind] if k in p}
        events.append({"seq": r["seq"], "node": r["node"], "kind": kind, "payload": p, "ts": r["ts"]})
    run = con.execute("SELECT run_id, workflow_id, status, inputs, created_at FROM runs WHERE run_id=?",
                      (run_id,)).fetchone()
    meta = yaml.safe_load((LIB / wid / "workflow.yaml").read_text(encoding="utf-8"))
    graph = meta.get("graph") or {}
    inputs = json.loads(run["inputs"] or "{}")
    props = ((meta.get("inputs_schema") or {}).get("properties") or {})
    file_inputs = {k: inputs.get(k) for k, v in props.items() if isinstance(v, dict) and v.get("format") == "file"}
    fixture = {
        "source": f"~/Genesis/runs/{rid} + run_events of a .backup copy of genesis.db (55-05, 2026-11-23)",
        "run": {"run_id": run_id, "workflow_id": wid, "status": run["status"],
                "input_keys": sorted(inputs), "file_inputs": file_inputs},
        "meta": {"artifacts": meta.get("artifacts"), "inputs_schema": meta.get("inputs_schema")},
        "graph": {"nodes": [{k: n.get(k) for k in ("id", "label", "kind")} for n in graph.get("nodes") or []]},
        "files": files,
        "events": events,
    }
    (OUT / f"{wid}.json").write_text(json.dumps(fixture, indent=1) + "\n", encoding="utf-8")
    print(rid, len(files), "files", len(events), "events")
