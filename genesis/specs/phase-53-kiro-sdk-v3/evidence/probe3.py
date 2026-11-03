"""Third v3 probe: can the engine's tool_load / tool_call meta-tools reach an MCP server that is
running in the session but NOT listed in the agent's `tools`? (Default HOME, so the user's global
`jira` server from ~/.kiro/settings/mcp.json is started by the engine.)"""
import asyncio
import sys

sys.path.insert(0, "/tmp/v3probe")
import probe as P  # noqa: E402
import probe2 as P2  # noqa: E402,F401  (module runs nothing at import? guarded below)


async def main():
    p = P2.Probe2(frames="frames4.jsonl")
    await p.start()
    agent = dict(P2.AGENT, id="genesis-probe3", tools=["@probe/echo", "read_file"])
    out = await P2.session(p, agent)
    if not out:
        return
    sid, _ = out
    await P.turn(p, sid, "C1 try to reach the jira server through tool_load",
                 "Use your tool_load tool to load the tools of the MCP server named 'jira', then list the "
                 "jira tool names you can now call. If you cannot, say NOT_AVAILABLE and quote the error.")
    await P.turn(p, sid, "C2 try to reach probe/secret (server listed only as probe/echo)",
                 "Use tool_load then tool_call to call the 'secret' tool of the 'probe' MCP server. "
                 "If you cannot, say NOT_AVAILABLE and quote the error.")
    p.proc.terminate()
    await asyncio.sleep(1)


asyncio.run(main())
