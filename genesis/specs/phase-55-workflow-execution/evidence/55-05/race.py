"""55-05 spike: is a node's file written before the consumer sees its `tasks` start chunk?"""
import asyncio
import os
import tempfile
import time
from typing import TypedDict

from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import END, START, StateGraph

ROOT = tempfile.mkdtemp(prefix="race-")


class S(TypedDict, total=False):
    i: int


async def async_writer(s):              # writes before its first await
    open(os.path.join(ROOT, "a.txt"), "w").write("a")
    await asyncio.sleep(0.05)
    return {"i": 1}


def sync_writer(s):                     # a sync node (LangGraph runs it in an executor)
    open(os.path.join(ROOT, "b.txt"), "w").write("b")
    time.sleep(0.05)
    return {"i": 2}


async def to_thread_writer(s):          # the 54-12 B1 program-node shape: work on a thread at once
    def work():
        open(os.path.join(ROOT, "c.txt"), "w").write("c")
    await asyncio.to_thread(work)
    await asyncio.sleep(0.05)
    return {"i": 3}


async def main():
    g = StateGraph(S)
    g.add_node("a", async_writer)
    g.add_node("b", sync_writer)
    g.add_node("c", to_thread_writer)
    g.add_edge(START, "a"); g.add_edge("a", "b"); g.add_edge("b", "c"); g.add_edge("c", END)
    app = g.compile(checkpointer=InMemorySaver())
    names = {"a": "a.txt", "b": "b.txt", "c": "c.txt"}
    async for mode, chunk in app.astream({"i": 0}, {"configurable": {"thread_id": "t"}},
                                         stream_mode=["updates", "tasks"]):
        if mode == "tasks" and "triggers" in chunk:
            n = chunk["name"]
            print(f"start {n}: file already there = {os.path.exists(os.path.join(ROOT, names[n]))}")
        elif mode == "tasks":
            print(f"finish {chunk['name']}")
        else:
            print(f"updates {list(chunk)}")


asyncio.run(main())
# Result (LangGraph 1.2.8, 3 runs): every "start <n>: file already there = False" — the consumer sees each start
# before the node writes, for an async node that writes before its first await, a sync node and a to_thread node.
