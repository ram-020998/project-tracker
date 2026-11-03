"""Throwaway probe: drive `kiro-cli acp --agent-engine v3` over raw JSON-RPC and record what it does.

Writes every frame to /tmp/v3probe/frames.jsonl and prints a per-test summary.
"""
import asyncio
import json
import os
import sys
import time

BASE = "/tmp/v3probe"
WORK = f"{BASE}/work"
FRAMES = f"{BASE}/frames.jsonl"
AGENT_ID = "genesis-probe"


class Probe:
    def __init__(self):
        self.proc = None
        self.next_id = 1
        self.pending = {}
        self.events = []          # (t, kind, payload) for the current test
        self.frames = open(FRAMES, "w")

    def log(self, direction, msg):
        self.frames.write(json.dumps({"t": round(time.time(), 3), "dir": direction, "msg": msg}) + "\n")
        self.frames.flush()

    async def start(self):
        self.proc = await asyncio.create_subprocess_exec(
            "kiro-cli", "acp", "--agent-engine", "v3",
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
            cwd=WORK, limit=64 * 1024 * 1024)
        asyncio.create_task(self.reader())
        asyncio.create_task(self.stderr())

    async def stderr(self):
        with open(f"{BASE}/stderr.log", "wb") as f:
            while True:
                line = await self.proc.stderr.readline()
                if not line:
                    break
                f.write(line)
                f.flush()

    async def send(self, msg):
        self.log("out", msg)
        self.proc.stdin.write((json.dumps(msg) + "\n").encode())
        await self.proc.stdin.drain()

    async def request(self, method, params, timeout=180):
        rid = self.next_id
        self.next_id += 1
        fut = asyncio.get_event_loop().create_future()
        self.pending[rid] = fut
        await self.send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
        try:
            return await asyncio.wait_for(fut, timeout)
        except asyncio.TimeoutError:
            return {"error": {"message": f"probe timeout after {timeout}s"}}

    async def notify(self, method, params):
        await self.send({"jsonrpc": "2.0", "method": method, "params": params})

    async def reader(self):
        while True:
            line = await self.proc.stdout.readline()
            if not line:
                self.events.append((time.time(), "eof", None))
                for fut in self.pending.values():
                    if not fut.done():
                        fut.set_result({"error": {"message": "process exited"}})
                break
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            self.log("in", msg)
            if "id" in msg and "method" not in msg:
                fut = self.pending.pop(msg["id"], None)
                if fut and not fut.done():
                    fut.set_result(msg)
            elif "method" in msg and "id" in msg:
                await self.on_server_request(msg)
            else:
                self.events.append((time.time(), "note", msg))

    async def on_server_request(self, msg):
        method, params, rid = msg["method"], msg.get("params", {}), msg["id"]
        self.events.append((time.time(), "request", msg))
        if method == "session/request_permission":
            opts = params.get("options", [])
            allow = next((o for o in opts if o.get("kind") == "allow_once"), None) or (opts[0] if opts else None)
            oid = allow.get("optionId") or allow.get("id") if allow else None
            result = {"outcome": {"outcome": "selected", "optionId": oid}} if oid else {"outcome": {"outcome": "cancelled"}}
            await self.send({"jsonrpc": "2.0", "id": rid, "result": result})
        elif method == "fs/write_text_file":
            path = params.get("path")
            with open(path, "w") as f:
                f.write(params.get("content", ""))
            await self.send({"jsonrpc": "2.0", "id": rid, "result": None})
        elif method == "fs/read_text_file":
            try:
                with open(params.get("path")) as f:
                    content = f.read()
                await self.send({"jsonrpc": "2.0", "id": rid, "result": {"content": content}})
            except OSError as e:
                await self.send({"jsonrpc": "2.0", "id": rid, "error": {"code": -32000, "message": str(e)}})
        else:
            await self.send({"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": "Method not found"}})


def summarize(events):
    """Compact view of one test: tool calls, permission requests, client fs requests, metadata, text."""
    out = {"tool_calls": [], "permission_requests": [], "client_requests": [], "metadata": [],
           "other_notes": set(), "text": ""}
    for _, kind, msg in events:
        if kind == "request":
            if msg["method"] == "session/request_permission":
                p = msg["params"]
                out["permission_requests"].append({
                    "toolCall_title": (p.get("toolCall") or {}).get("title"),
                    "toolCall_kind": (p.get("toolCall") or {}).get("kind"),
                    "_meta": p.get("_meta"),
                    "options": [o.get("optionId") or o.get("id") for o in p.get("options", [])]})
            else:
                out["client_requests"].append({"method": msg["method"],
                                               "path": msg.get("params", {}).get("path")})
        elif kind == "note":
            method = msg.get("method")
            params = msg.get("params", {})
            if method == "session/update":
                upd = params.get("update", {})
                su = upd.get("sessionUpdate")
                if su == "agent_message_chunk":
                    c = upd.get("content", {})
                    out["text"] += c.get("text", "") if isinstance(c, dict) else ""
                elif su == "tool_call":
                    out["tool_calls"].append({"title": upd.get("title"), "kind": upd.get("kind"),
                                              "_meta": upd.get("_meta")})
                else:
                    out["other_notes"].add(f"session/update:{su}")
            elif method == "_kiro.dev/metadata":
                out["metadata"].append(params)
            else:
                out["other_notes"].add(method)
    out["other_notes"] = sorted(out["other_notes"])
    out["text"] = out["text"][:400]
    return out


async def turn(p, sid, label, text, cancel_after=None):
    p.events = []
    print(f"\n===== {label} =====", flush=True)
    task = asyncio.create_task(p.request("session/prompt",
                                         {"sessionId": sid, "prompt": [{"type": "text", "text": text}]}))
    if cancel_after is not None:
        await asyncio.sleep(cancel_after)
        await p.notify("session/cancel", {"sessionId": sid})
        print(f"(sent session/cancel after {cancel_after}s)", flush=True)
    resp = await task
    await asyncio.sleep(1.5)  # let trailing notifications (metadata) arrive
    s = summarize(p.events)
    s["prompt_response"] = resp.get("result", resp.get("error"))
    print(json.dumps(s, indent=1, default=str), flush=True)
    return s


async def main():
    os.makedirs(WORK, exist_ok=True)
    for f in ("out.txt",):
        try:
            os.remove(os.path.join(WORK, f))
        except FileNotFoundError:
            pass
    p = Probe()
    await p.start()

    init = await p.request("initialize", {
        "protocolVersion": 1,
        "clientCapabilities": {"fs": {"readTextFile": True, "writeTextFile": True}, "terminal": False},
        "clientInfo": {"name": "genesis-v3-probe", "version": "0.0.1"}}, timeout=60)
    print("===== initialize =====\n" + json.dumps(init.get("result", init), indent=1)[:3000], flush=True)

    mcp = [{"name": "probe", "command": sys.executable, "args": [f"{BASE}/probe_mcp.py"], "env": []}]
    agent = {
        "id": AGENT_ID,
        "prompt": "You are a test agent. Follow instructions literally. If a tool you are asked to use is "
                  "not available to you, say exactly NOT_AVAILABLE and name the tool. Keep replies short.",
        "tools": ["@probe/echo", "read_file", "list_directory", "fs_write", "str_replace", "fs_append"],
        "permissions": {"rules": [{"capability": "mcp", "match": ["probe/echo"], "effect": "allow"}]},
    }
    new = await p.request("session/new", {"cwd": WORK, "mcpServers": mcp,
                                          "_meta": {"kiro": {"customAgents": [agent]}}}, timeout=120)
    res = new.get("result", new)
    sid = res.get("sessionId")
    print("===== session/new =====\n" + json.dumps({"sessionId": sid, "modes": res.get("modes"),
          "models": (res.get("models") or {}).get("currentModelId"), "keys": sorted(res)}, indent=1), flush=True)
    if not sid:
        print(json.dumps(new, indent=1))
        return

    sm = await p.request("session/set_mode", {"sessionId": sid, "modeId": AGENT_ID}, timeout=30)
    print("===== session/set_mode =====\n" + json.dumps(sm, indent=1)[:1500], flush=True)
    await asyncio.sleep(1)

    await turn(p, sid, "T1 allowed MCP tool (rule allow probe/echo)",
               "Call the echo tool of the probe MCP server with text 'hello'. Report its output.")
    await turn(p, sid, "T2 MCP tool declared on server but not in agent tools",
               "Call the 'secret' tool of the probe MCP server. If you have no such tool, say NOT_AVAILABLE.")
    await turn(p, sid, "T3 file write in cwd (fs_write in tools, no allow rule)",
               f"Create the file {WORK}/out.txt containing exactly: hi")
    print("out.txt exists:", os.path.exists(os.path.join(WORK, "out.txt")), flush=True)
    await turn(p, sid, "T4 delete (delete_file NOT in tools)",
               f"Delete the file {WORK}/out.txt using a file deletion tool (not the shell). "
               "If you have no deletion tool, say NOT_AVAILABLE.")
    print("out.txt exists after T4:", os.path.exists(os.path.join(WORK, "out.txt")), flush=True)
    await turn(p, sid, "T5 shell (execute_bash NOT in tools)",
               "Run the shell command `echo shell-ran`. If you have no shell tool, say NOT_AVAILABLE.")
    await turn(p, sid, "T6 '/compact' sent as a normal prompt", "/compact")

    p.events = []
    ex = await p.request("_kiro.dev/commands/execute", {"sessionId": sid, "command": "/compact"}, timeout=60)
    print("\n===== T7 _kiro.dev/commands/execute /compact =====\n" + json.dumps(ex, indent=1)[:1500], flush=True)
    await asyncio.sleep(1)
    print("notes during T7:", summarize(p.events)["other_notes"], flush=True)

    await turn(p, sid, "T8 session/cancel mid-turn",
               "Write a 600-word essay about rivers. Do not use any tools.", cancel_after=6)
    await turn(p, sid, "T9 session still usable after cancel", "Reply with the single word: alive")

    p.proc.terminate()
    await asyncio.sleep(1)


if __name__ == "__main__":
    asyncio.run(main())
