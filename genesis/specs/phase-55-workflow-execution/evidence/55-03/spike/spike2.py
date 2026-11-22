"""55-03 §0 spike part 2: a node that raises, a parallel fan-out, and a compiled subgraph node."""
import asyncio
import json
import sys
from typing import Annotated, TypedDict
import operator

from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
from langgraph.graph import END, START, StateGraph


class S(TypedDict, total=False):
    i: int
    xs: Annotated[list, operator.add]


def boom(s):
    raise RuntimeError("blew up")


def err(g):
    g.add_node("a", lambda s: {"i": 1})
    g.add_node("boom", boom)
    g.add_edge(START, "a"); g.add_edge("a", "boom"); g.add_edge("boom", END)


def par(g):
    g.add_node("a", lambda s: {"i": 1})
    g.add_node("l", lambda s: {"xs": ["l"]})
    g.add_node("r", lambda s: {"xs": ["r"]})
    g.add_node("j", lambda s: {"i": 2})
    g.add_edge(START, "a"); g.add_edge("a", "l"); g.add_edge("a", "r"); g.add_edge(["l", "r"], "j"); g.add_edge("j", END)


def sub(g):
    inner = StateGraph(S)
    inner.add_node("x", lambda s: {"i": 5})
    inner.add_edge(START, "x"); inner.add_edge("x", END)
    g.add_node("outer", inner.compile())
    g.add_edge(START, "outer"); g.add_edge("outer", END)


async def main():
    name = sys.argv[1]
    g = StateGraph(S)
    {"err": err, "par": par, "sub": sub}[name](g)
    async with AsyncSqliteSaver.from_conn_string("/tmp/spike-55-03/spike2.db") as saver:
        app = g.compile(checkpointer=saver)
        cfg = {"configurable": {"thread_id": name}}
        try:
            async for mode, chunk in app.astream({"i": 0}, cfg, stream_mode=["updates", "custom", "tasks"]):
                print(json.dumps({"mode": mode, "chunk": chunk}, default=repr), flush=True)
        except Exception as e:  # noqa: BLE001
            print("RAISED", repr(e))


asyncio.run(main())
