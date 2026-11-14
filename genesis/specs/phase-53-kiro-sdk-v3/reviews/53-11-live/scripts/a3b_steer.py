"""A3b steering, through the real serve: (1) a steer while a tool call runs; (2) a late steer, queued as the answer
streams (the engine's second turn inside one prompt, F18); (3) a steer after the answer (409 expected: no turn);
(4) an unread steer: queued, then Stop (unread_steers on the cancelled result). Usage: a3b_steer.py <out.json>"""
import asyncio
import json
import sys
from pathlib import Path

import chatlib as cl


async def main():
    out = {}
    async with cl.client() as c:
        sid = await cl.new_session(c, "53-11 A3b steer")
        out["session"] = sid
        warm = await cl.send(c, sid, "Reply with the single word READY.")
        out["warm"] = cl.brief(warm)

        def steer(text):
            async def _steer():
                r = await c.post(f"/chat/sessions/{sid}/steer", json={"text": text})
                return {"status": r.status_code, "body": r.json()}
            _steer.__name__ = f"steer:{text[:30]}"
            return _steer

        def saw(kind):
            return lambda t, ev: any(e.get("type") == kind for e in ev)

        # (1) a steer while a tool runs
        r1 = await cl.send(c, sid, "Using the genesis-kb tools, find the applications in the knowledge base and tell me "
                                   "how many objects the first one has. Keep the answer to two sentences.",
                           actions=[(saw("agent.tool_call"), steer("Also end your reply with the word KIWI."))])
        out["during_tool"] = cl.brief(r1)

        # (2) a late steer: queued as soon as the answer starts streaming
        r2 = await cl.send(c, sid, "Write one sentence about the sea.",
                           actions=[(saw("agent.message"),
                                     steer("Now also write one sentence about mountains, starting with MOUNTAIN:"))])
        out["late"] = cl.brief(r2)

        # (3) after the answer: no turn is running
        r3 = await c.post(f"/chat/sessions/{sid}/steer", json={"text": "too late"})
        out["after_answer"] = {"status": r3.status_code, "body": r3.json()}

        # (4) unread: queue a steer, then Stop 0.3 s later
        async def cancel():
            return (await c.post(f"/chat/sessions/{sid}/cancel")).status_code
        state = {"steered_at": None}

        def steered(t, ev):
            return state["steered_at"] is not None and t >= state["steered_at"] + 0.3

        st = steer("Make it about green tea only.")

        async def steer_and_mark():
            res = await st()
            state["steered_at"] = state.get("now", 0)
            return res
        steer_and_mark.__name__ = "steer:Make it about green tea only."

        def at(sec):
            def p(t, ev):
                state["now"] = t
                return t >= sec
            return p

        def after_steer(t, ev):
            state["now"] = t
            return state["steered_at"] is not None and t >= state["steered_at"] + 0.3

        r4 = await cl.send(c, sid, "Write a 400-word essay about the history of tea.",
                           actions=[(at(1.5), steer_and_mark), (after_steer, cancel)])
        out["unread"] = cl.brief(r4)
        msgs = await cl.messages(c, sid)
        out["stored"] = [{"seq": m["seq"], "role": m["role"], "content": m["content"][:160], "meta": m["meta"],
                          "credits": (m["usage"] or {}).get("credits"),
                          "provenance": (m["usage"] or {}).get("provenance")} for m in msgs]
    Path(sys.argv[1]).write_text(json.dumps(out, indent=1))
    print("session", out["session"])


asyncio.run(main())
