"""Second v3 probe: approval-needed MCP tool, deny path, write outside cwd, compaction, set_model,
tool visibility, and whether a private KIRO_HOME keeps the user's global mcp.json/skills out."""
import asyncio
import json
import os
import sys

sys.path.insert(0, "/tmp/v3probe")
import probe as P  # noqa: E402  (reuses the Probe class; probe.main() is guarded below)

DENY_TITLES = set()


class Probe2(P.Probe):
    def __init__(self, env=None, frames="frames2.jsonl"):
        super().__init__()
        self.frames = open(f"{P.BASE}/{frames}", "w")
        self.env = env
        self.deny_next = False

    async def start(self):
        self.proc = await asyncio.create_subprocess_exec(
            "kiro-cli", "acp", "--agent-engine", "v3",
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
            cwd=P.WORK, limit=64 * 1024 * 1024, env=self.env)
        asyncio.create_task(self.reader())
        asyncio.create_task(self.stderr())

    async def on_server_request(self, msg):
        if msg["method"] == "session/request_permission" and self.deny_next:
            self.events.append((0, "request", msg))
            opts = msg["params"].get("options", [])
            rej = next((o for o in opts if o.get("kind") == "reject_once"), None)
            await self.send({"jsonrpc": "2.0", "id": msg["id"],
                             "result": {"outcome": {"outcome": "selected", "optionId": rej["optionId"]}}})
            return
        if msg["method"] == "fs/write_text_file":
            self.events.append((0, "request", msg))
            # Mimic Genesis fs_write_root: refuse writes outside WORK.
            path = os.path.realpath(msg["params"].get("path", ""))
            if not path.startswith(os.path.realpath(P.WORK) + os.sep):
                await self.send({"jsonrpc": "2.0", "id": msg["id"],
                                 "error": {"code": -32000, "message": "write outside sandbox refused"}})
                return
        await super().on_server_request(msg)


async def session(p, agent):
    init = await p.request("initialize", {
        "protocolVersion": 1,
        "clientCapabilities": {"fs": {"readTextFile": True, "writeTextFile": True}, "terminal": False},
        "clientInfo": {"name": "genesis-v3-probe", "version": "0.0.2"}}, timeout=60)
    if "error" in init:
        print("initialize failed:", init)
        return None
    mcp = [{"name": "probe", "command": sys.executable, "args": [f"{P.BASE}/probe_mcp.py"], "env": []}]
    p.events = []
    new = await p.request("session/new", {"cwd": P.WORK, "mcpServers": mcp,
                                          "_meta": {"kiro": {"customAgents": [agent]}}}, timeout=120)
    res = new.get("result", new)
    sid = res.get("sessionId")
    if not sid:
        print("session/new failed:", json.dumps(new)[:1500])
        return None
    sm = await p.request("session/set_mode", {"sessionId": sid, "modeId": agent["id"]}, timeout=30)
    print("set_mode:", sm.get("result", sm.get("error")))
    await asyncio.sleep(3)
    servers = set()
    ctx_files = set()
    for _, kind, m in p.events:
        if kind == "note" and m.get("method") == "_kiro/mcp/status":
            servers |= {s["name"] for s in m["params"].get("servers", [])}
        if kind == "note" and m.get("method") == "session/update":
            cf = (((m["params"].get("update") or {}).get("_meta") or {}).get("kiro") or {}).get("breakdown", {})
            for it in (cf.get("contextFiles") or {}).get("items", []):
                ctx_files.add(it.get("name"))
    print("MCP servers the session started:", sorted(servers))
    print("context files loaded:", sorted(ctx_files))
    return sid, res


AGENT = {
    "id": "genesis-probe2",
    "prompt": "You are a test agent. Follow instructions literally. Keep replies short.",
    "tools": ["@probe", "read_file", "list_directory", "fs_write"],
    "permissions": {"rules": [{"capability": "mcp", "match": ["probe/echo"], "effect": "allow"}]},
}


async def main_default_home():
    print("\n######## RUN A: default HOME (user's ~/.kiro visible) ########")
    p = Probe2()
    await p.start()
    out = await session(p, AGENT)
    if not out:
        return
    sid, res = out
    print("configOptions ids:", [o.get("id") for o in res.get("configOptions", [])])

    await P.turn(p, sid, "A1 list visible tools",
                 "List the exact names of every tool you can call, one per line, nothing else.")
    await P.turn(p, sid, "A2 MCP tool in tools, no allow rule (probe/secret) -> approve",
                 "Call the 'secret' tool of the probe MCP server and report its output.")
    p.deny_next = True
    await P.turn(p, sid, "A3 same tool, permission DENIED",
                 "Call the 'secret' tool of the probe MCP server again and report what happened.")
    p.deny_next = False
    await P.turn(p, sid, "A4 write OUTSIDE cwd (client refuses fs/write_text_file)",
                 "Create the file /tmp/v3probe/outside.txt containing exactly: x")
    print("outside.txt exists:", os.path.exists("/tmp/v3probe/outside.txt"))

    p.events = []
    c = await p.request("_kiro/session/compact", {"sessionId": sid}, timeout=120)
    await asyncio.sleep(2)
    print("\n===== A5 _kiro/session/compact =====\n", json.dumps(c)[:800])
    print("notes:", P.summarize(p.events)["other_notes"])

    sm = await p.request("session/set_model", {"sessionId": sid, "modelId": "claude-sonnet-5.5"}, timeout=30)
    print("\n===== A6 session/set_model =====\n", json.dumps(sm)[:600])
    so = await p.request("session/set_config_option",
                         {"sessionId": sid, "configId": "model", "value": "claude-sonnet-5.5"}, timeout=30)
    print("===== A6b session/set_config_option model =====\n", json.dumps(so)[:600])
    p.proc.terminate()
    await asyncio.sleep(1)


async def main_private_home():
    print("\n######## RUN B: private KIRO_HOME (empty) ########")
    kh = f"{P.BASE}/kirohome"
    os.makedirs(kh, exist_ok=True)
    env = dict(os.environ, KIRO_HOME=kh)
    p = Probe2(env=env, frames="frames3.jsonl")
    await p.start()
    out = await session(p, AGENT)
    if not out:
        try:
            print(open(f"{P.BASE}/stderr.log").read()[-1500:])
        except OSError:
            pass
        return
    sid, _ = out
    await P.turn(p, sid, "B1 does auth still work + allowed tool",
                 "Call the echo tool of the probe MCP server with text 'home'. Report its output.")
    p.proc.terminate()
    await asyncio.sleep(1)


async def main():
    for f in ("outside.txt",):
        try:
            os.remove(f"/tmp/v3probe/{f}")
        except FileNotFoundError:
            pass
    await main_default_home()
    await main_private_home()


if __name__ == "__main__":
    asyncio.run(main())
