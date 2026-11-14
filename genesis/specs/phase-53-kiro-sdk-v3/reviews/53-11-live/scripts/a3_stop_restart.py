"""A3 Stop across a `genesis serve` restart (D15). Phase `stop`: in a warm session send the write request, POST
/cancel ~1 s in. Phase `next` (after the restart): send the unrelated question; the D15 note must come from the
stored transcript. Usage: a3_stop_restart.py stop|next <session_id> <out.json>"""
import asyncio
import json
import sys
from pathlib import Path

import chatlib as cl

phase, sid, out = sys.argv[1], sys.argv[2], sys.argv[3]
f = Path("/tmp/genesis-53-11/state/skill-output") / sid / "carry-restart.txt"


async def main():
    async with cl.client() as c:
        if phase == "stop":
            async def cancel():
                return (await c.post(f"/chat/sessions/{sid}/cancel")).status_code
            res = await cl.send(c, sid, "Create a file named carry-restart.txt in your working directory containing "
                                        "exactly CARRY-RESTART. Then reply with the single word WROTE.",
                                actions=[(lambda t, ev: t >= 1.0, cancel)])
            rec = {"phase": "stop", "file_after_stop": f.exists(), "stopped": cl.brief(res)}
        else:
            res = await cl.send(c, sid, "Unrelated question: what is the capital of France? Reply with one word.")
            await asyncio.sleep(3)
            msgs = await cl.messages(c, sid)
            rec = {"phase": "next", "file_after_next": f.exists(), "next": cl.brief(res),
                   "stored_tail": [{"seq": m["seq"], "role": m["role"], "content": m["content"][:200],
                                    "meta": m["meta"], "credits": (m["usage"] or {}).get("credits"),
                                    "provenance": (m["usage"] or {}).get("provenance")} for m in msgs[-4:]]}
    Path(out).write_text(json.dumps(rec, indent=1))
    print(json.dumps(rec, indent=1)[:3000])


asyncio.run(main())
