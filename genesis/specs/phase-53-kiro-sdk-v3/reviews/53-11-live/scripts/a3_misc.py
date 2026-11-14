"""A3: model at start, Compact, Clear (new Kiro session, transcript kept), typed /clear, and a `/`-palette typed
non-command text. Usage: a3_misc.py <out.json>"""
import asyncio
import json
import sys
from pathlib import Path

import chatlib as cl


async def main():
    out = {}
    async with cl.client() as c:
        sid = (await c.post("/chat/sessions", json={"title": "53-11 A3 misc", "model": "claude-haiku-5.5"})).json()["id"]
        out["session"] = sid
        r = await cl.send(c, sid, "Remember the number 314. Reply OK.")
        out["t1"] = cl.brief(r)
        out["kiro_session_before_clear"] = (await c.get(f"/chat/sessions/{sid}")).json()["session"]
        out["compact"] = (await c.post(f"/chat/sessions/{sid}/compact")).json()
        r = await cl.send(c, sid, "What number did I ask you to remember? Reply with the number only.")
        out["t2_after_compact"] = cl.brief(r)
        out["clear"] = (await c.post(f"/chat/sessions/{sid}/clear")).json()
        out["kiro_session_after_clear"] = (await c.get(f"/chat/sessions/{sid}")).json()["session"]
        r = await cl.send(c, sid, "Did I ask you to remember a number earlier in this conversation? If so which; if "
                                  "you have no record, reply NONE.")
        out["t3_after_clear"] = cl.brief(r)
        r = await cl.send(c, sid, "/clear")
        out["typed_clear"] = cl.brief(r)
        r = await cl.send(c, sid, "/usage please")
        out["typed_unknown_slash"] = cl.brief(r)
        msgs = await cl.messages(c, sid)
        out["stored"] = [{"seq": m["seq"], "role": m["role"], "content": m["content"][:160], "meta": m["meta"],
                          "credits": (m["usage"] or {}).get("credits"), "model": (m["usage"] or {}).get("model"),
                          "provenance": (m["usage"] or {}).get("provenance")} for m in msgs]
    Path(sys.argv[1]).write_text(json.dumps(out, indent=1))
    print("session", out["session"])


asyncio.run(main())
