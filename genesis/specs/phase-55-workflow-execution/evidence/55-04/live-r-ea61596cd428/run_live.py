"""55-04 live check: ONE agent-prompt run (scratch state, frozen copy of the real memory.db, the bge model)."""
import json, os, sys
os.environ["GENESIS_STATE_DIR"] = "/tmp/gv-55-04/live/state"
os.environ["GENESIS_ARTIFACTS_DIR"] = "/tmp/gv-55-04/live/arts"
os.environ["GENESIS_MEMORY_OWNER"] = "admin.user"
from genesis.runs.manager import RunManager
mgr = RunManager()
prompt = ("What does Genesis remember about the Document Builder feature's templates? First read the memory brief "
          "named in this prompt, then call the search_memory tool once with the query 'Document Builder templates'. "
          "Write to output.md: (1) the first [M<id>] id listed in the brief, (2) the ids search_memory returned, "
          "(3) the exact names of the genesis-memory tools you have. Keep it short.")
run_id = mgr.start("agent-prompt", {"prompt": prompt, "skills": [], "mcp_servers": []})
print("run", run_id, flush=True)
rec = mgr.wait(run_id, timeout=900)
print("status", rec.status, rec.detail)
ev = [e for e in mgr.log_events(run_id, limit=10000)]
json.dump(ev, open(f"/tmp/gv-55-04/live/{run_id}.events.json", "w"), indent=1, default=str)
for e in ev:
    if e["kind"] in ("memory.brief", "agent.prompt", "agent.tool_call", "agent.result", "error", "run.final"):
        print(e["kind"], e["node"], json.dumps(e["payload"], default=str)[:600])
