"""A3b: (1) a mode change that resumes under a different agent and moves the working folder (read_only: state_dir ->
feature_spec: the sandbox -> back); (2) a Feature Spec turn that names a managed skill, typed as `/gam …` (D25 rewrite,
D23 load through disclose_context); (3) a skill authored while the session is open, found after the reload's
session/load. Usage: a3b_mode_skill.py <out.json>"""
import asyncio
import json
import sys
from pathlib import Path

import chatlib as cl

CANARY_MD = """---
name: canary-5311
description: A 53-11 live-acceptance canary skill. Use it when the user asks for the 53-11 canary word.
---

# canary-5311

When this skill is used, reply with the canary word PLUM-5311 and nothing else.
"""


async def main():
    out = {}
    async with cl.client() as c:
        sid = await cl.new_session(c, "53-11 A3b mode change")
        out["session"] = sid
        r = await cl.send(c, sid, "Remember the code word PEAR. Also tell me the absolute path of your current working "
                                  "directory. Reply in one line.")
        out["t1_read_only"] = cl.brief(r)
        out["mode_to_spec"] = (await c.post(f"/chat/sessions/{sid}/mode", json={"mode": "feature_spec"})).json()
        r = await cl.send(c, sid, "What was the code word? Also tell me the absolute path of your current working "
                                  "directory (use a file tool to check it). Reply in one line.")
        out["t2_feature_spec"] = cl.brief(r)
        r = await cl.send(c, sid, "/gam In one sentence, what does GAM stand for according to the skill?")
        out["t3_spec_skill"] = cl.brief(r)
        # a skill authored meanwhile: the API reloads the idle client; the next turn loads the session again
        a = await c.post("/skills", json={"skill_md": CANARY_MD})
        out["author_canary"] = {"status": a.status_code, "body": a.json()}
        r = await cl.send(c, sid, "Use the canary-5311 skill.")
        out["t4_new_skill"] = cl.brief(r)
        out["mode_to_ro"] = (await c.post(f"/chat/sessions/{sid}/mode", json={"mode": "read_only"})).json()
        r = await cl.send(c, sid, "What was the code word from the start of this chat? Reply in one word.")
        out["t5_read_only"] = cl.brief(r)
        out["commands"] = (await c.get("/chat/commands")).json()
        msgs = await cl.messages(c, sid)
        out["stored"] = [{"seq": m["seq"], "role": m["role"], "content": m["content"][:200], "meta": m["meta"],
                          "credits": (m["usage"] or {}).get("credits"),
                          "provenance": (m["usage"] or {}).get("provenance")} for m in msgs]
    Path(sys.argv[1]).write_text(json.dumps(out, indent=1))
    print("session", out["session"])


asyncio.run(main())
