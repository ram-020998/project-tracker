"""A4 skill part. The one skill in ~/.kiro/skills is a byte-identical copy of a library skill installed here, so it
cannot tell the two folders apart. Instead: remove that skill from this instance only (DELETE /api/skills/<id>), ask a
read-only and a feature_spec session for their skills, and count whole-word hits of the id. With ~/.kiro/skills still
holding it, 0 hits means chat does not read ~/.kiro/skills. The id is never printed (canary skill#2).
Usage: a4_skill.py <out.json>   (reinstall the skill afterwards with install_skills.py)"""
import asyncio
import json
import re
import sys
from pathlib import Path

import chatlib as cl

NAME = json.loads(Path("/tmp/genesis-53-11/.a4-canaries.json").read_text())["skills"][0]
Q = ("List the name of every skill you can load. Answer with one comma-separated list only, no other text.")


def whole(text: str) -> int:
    return len(re.findall(rf"(?<![\w-]){re.escape(NAME)}(?![\w-])", text, re.IGNORECASE))


async def main():
    out = {}
    async with cl.client() as c:
        d = await c.delete(f"/skills/{NAME}")
        out["delete_status"] = d.status_code
        listed = [s["id"] for s in (await c.get("/skills")).json()]
        out["instance_skills_after_delete"] = [s if s != NAME else "skill#2" for s in listed]
        out["skill2_in_instance"] = NAME in listed
        for mode in ("read_only", "feature_spec"):
            sid = await cl.new_session(c, f"53-11 A4 skill {mode}", mode=None if mode == "read_only" else mode)
            r = await cl.send(c, sid, Q)
            b = cl.brief(r)
            ans = b["answer"]
            out[mode] = {"session": sid, "answer_whole_word_hits_skill2": whole(ans),
                         "answer_redacted": re.sub(rf"(?<![\w-]){re.escape(NAME)}(?![\w-])", "skill#2", ans,
                                                   flags=re.IGNORECASE),
                         "credits": b["result"]["credits"], "provenance": b["result"]["provenance"]}
        cmds = (await c.get("/chat/commands")).json()
        out["commands"] = [x["name"] for x in cmds["commands"]]
    Path(sys.argv[1]).write_text(json.dumps(out, indent=1))
    print(json.dumps(out, indent=1))


asyncio.run(main())
