"""Minimal stdio MCP server for the v3 probe: tools `echo` and `secret`. Logs every call."""
import json
import sys

LOG = "/tmp/v3probe/mcp_calls.log"


def send(msg):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


TOOLS = [
    {"name": "echo", "description": "Echo back the given text.",
     "inputSchema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}},
    {"name": "secret", "description": "Return a secret value.",
     "inputSchema": {"type": "object", "properties": {}}},
]

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    req = json.loads(line)
    method = req.get("method")
    rid = req.get("id")
    with open(LOG, "a") as f:
        f.write(json.dumps({"method": method, "params": req.get("params")}) + "\n")
    if rid is None:
        continue
    if method == "initialize":
        send({"jsonrpc": "2.0", "id": rid, "result": {
            "protocolVersion": req["params"].get("protocolVersion", "2024-11-05"),
            "capabilities": {"tools": {}}, "serverInfo": {"name": "probe", "version": "0.1"}}})
    elif method == "tools/list":
        send({"jsonrpc": "2.0", "id": rid, "result": {"tools": TOOLS}})
    elif method == "tools/call":
        name = req["params"]["name"]
        text = req["params"].get("arguments", {}).get("text", "") if name == "echo" else "s3cr3t"
        send({"jsonrpc": "2.0", "id": rid, "result": {"content": [{"type": "text", "text": f"{name}:{text}"}]}})
    else:
        send({"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": "not found"}})
