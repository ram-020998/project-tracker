"""A3 Stop before the answer (D15), 3 tries in one warm Feature Spec session (fs_write in its sandbox, so the stopped
request has a visible side effect: a file). Each try: send a write request, POST /cancel about 1 s later (the web's
order: cancel first, keep reading the stream), then an unrelated question. Records whether the file exists after the
stop and after the next turn, the tool calls of both turns and the stored turn status.
Usage: a3_stop.py <out.json> [session_id]  (an existing warm session for the restart variant)"""
import asyncio
import json
import sys
from pathlib import Path

import chatlib as cl

SANDBOX = Path("/tmp/genesis-53-11/state/skill-output")


async def stop_try(c, sid, n, delay=1.0):
    f = SANDBOX / sid / f"carry-{n}.txt"

    async def cancel():
        r = await c.post(f"/chat/sessions/{sid}/cancel")
        return r.status_code

    stopped = await cl.send(c, sid, f"Create a file named carry-{n}.txt in your working directory containing exactly "
                                    f"CARRY-{n}. Then reply with the single word WROTE.",
                            actions=[(lambda t, ev: t >= delay, cancel)])
    after_stop = f.exists()
    await asyncio.sleep(2)
    nxt = await cl.send(c, sid, "Unrelated question: what is 7 times 6? Reply with only the number.")
    await asyncio.sleep(3)
    return {"try": n, "file_after_stop": after_stop, "file_after_next": f.exists(),
            "stopped": cl.brief(stopped), "next": cl.brief(nxt)}


async def main():
    out, existing = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else None)
    async with cl.client() as c:
        if existing:
            sid = existing
            rows = []
        else:
            sid = await cl.new_session(c, "53-11 A3 stop", mode="feature_spec")
            warm = await cl.send(c, sid, "Say hello in three words.")
            rows = [{"warm": cl.brief(warm)}]
        tries = [1, 2, 3] if not existing else [4]
        for n in tries:
            rows.append(await stop_try(c, sid, n))
        msgs = await cl.messages(c, sid)
        rows.append({"session": sid, "stored": [{"seq": m["seq"], "role": m["role"], "content": m["content"][:200],
                                                 "meta": m["meta"], "credits": (m["usage"] or {}).get("credits"),
                                                 "provenance": (m["usage"] or {}).get("provenance")}
                                                for m in msgs]})
    Path(out).write_text(json.dumps(rows, indent=1))
    print("session", sid)


asyncio.run(main())
