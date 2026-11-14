"""A4 (chat part): a server in ~/.kiro/settings/mcp.json and a skill only in ~/.kiro/skills reach no chat session.
Asks a read-only and a feature_spec session to list every tool server and skill it has, then counts canary-name hits in
the answers and in the whole chat Kiro home (Genesis's own KIRO_HOME). The canary names are read from a 0600 file
outside the evidence and are never printed: only hit counts per canary index.
Usage: a4_isolation.py <out.json>"""
import asyncio
import json
import sys
from pathlib import Path

import chatlib as cl

CAN = json.loads(Path("/tmp/genesis-53-11/.a4-canaries.json").read_text())
NAMES = [("mcp", n) for n in CAN["mcp"]] + [("skill", n) for n in CAN["skills"]]
Q = ("List the name of every MCP server or tool group you can use, and the name of every skill you can load. Answer "
     "with two comma-separated lists only, no other text.")


def hits(text: str) -> list[dict]:
    low = text.lower()
    return [{"canary": f"{kind}#{i}", "hits": low.count(n.lower())} for i, (kind, n) in enumerate(NAMES)]


async def main():
    out = {"canaries": [f"{k}#{i}" for i, (k, _) in enumerate(NAMES)]}
    async with cl.client() as c:
        for mode in ("read_only", "feature_spec"):
            sid = await cl.new_session(c, f"53-11 A4 {mode}", mode=None if mode == "read_only" else mode)
            r = await cl.send(c, sid, Q)
            b = cl.brief(r)
            out[mode] = {"session": sid, "answer": b["answer"], "result": b["result"], "tools": b["tools"],
                         "canary_hits_in_answer": hits(b["answer"])}
    home = Path("/tmp/genesis-53-11/state/kiro-home")
    blob = []
    n_files = 0
    for p in home.rglob("*"):
        if p.is_file():
            n_files += 1
            try:
                blob.append(p.read_text(errors="ignore"))
            except OSError:
                pass
    out["kiro_home_files_scanned"] = n_files
    out["canary_hits_in_genesis_kiro_home"] = hits("\n".join(blob))
    Path(sys.argv[1]).write_text(json.dumps(out, indent=1))
    print(json.dumps({k: v for k, v in out.items()}, indent=1)[:4000])


asyncio.run(main())
