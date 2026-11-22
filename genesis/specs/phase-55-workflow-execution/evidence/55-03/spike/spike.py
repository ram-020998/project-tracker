"""55-03 §0 spike: the real LangGraph `tasks` stream payloads (straight, loop, gate+resume, kill+resume)."""
import asyncio
import json
import os
import sys
from typing import TypedDict

from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import Command, interrupt

DB = sys.argv[2] if len(sys.argv) > 2 else "/tmp/spike-55-03/spike.db"


class S(TypedDict, total=False):
    i: int
    out: str


def straight(g):
    g.add_node("a", lambda s: {"i": 1})
    g.add_node("b", lambda s: {"i": s["i"] + 1})
    g.add_edge(START, "a"); g.add_edge("a", "b"); g.add_edge("b", END)


def loop(g):
    g.add_node("work", lambda s: {"i": s.get("i", 0) + 1})
    g.add_node("check", lambda s: {})
    g.add_node("fin", lambda s: {"out": "ok"})
    g.add_edge(START, "work"); g.add_edge("work", "check")
    g.add_conditional_edges("check", lambda s: "work" if s["i"] < 3 else "fin", {"work": "work", "fin": "fin"})
    g.add_edge("fin", END)


def gate(g):
    g.add_node("seed", lambda s: {"i": 1})

    def ask(s):
        ans = interrupt({"prompt": "approve?", "node": "ask"})
        return {"out": str(ans)}
    g.add_node("ask", ask)
    g.add_node("finish", lambda s: {"i": 9})
    g.add_edge(START, "seed"); g.add_edge("seed", "ask"); g.add_edge("ask", "finish"); g.add_edge("finish", END)


async def slow_node(s):
    open("/tmp/spike-55-03/slow.started", "w").write("1")
    await asyncio.sleep(30)
    return {"out": "slow done"}


def killable(g):
    g.add_node("first", lambda s: {"i": 1})
    g.add_node("slow", slow_node)
    g.add_node("last", lambda s: {"i": 2})
    g.add_edge(START, "first"); g.add_edge("first", "slow"); g.add_edge("slow", "last"); g.add_edge("last", END)


CASES = {"straight": straight, "loop": loop, "gate": gate, "killable": killable}


def dump(mode, chunk):
    print(json.dumps({"mode": mode, "chunk": chunk}, default=repr), flush=True)


async def main():
    case = sys.argv[1]
    name = case.split(":")[0]
    g = StateGraph(S)
    CASES[name](g)
    async with AsyncSqliteSaver.from_conn_string(DB) as saver:
        app = g.compile(checkpointer=saver)
        cfg = {"configurable": {"thread_id": name}}
        if case.endswith(":resume"):
            inp = Command(resume="approve") if name == "gate" else None
        else:
            inp = {"i": 0}
        async for mode, chunk in app.astream(inp, cfg, stream_mode=["updates", "custom", "tasks"]):
            dump(mode, chunk)
        st = await app.aget_state(cfg)
        print(json.dumps({"final_next": list(st.next), "interrupts": [repr(i) for t in st.tasks for i in t.interrupts]}))


asyncio.run(main())
