"""55-03 browser probe: a program-only workflow held at each step by files in the run folder (go-<node>-<round>)."""
import asyncio
from pathlib import Path

from langchain_core.runnables import RunnableConfig
from langgraph.graph import END, START, StateGraph

from genesis_core import PlatformState, hitl_gate, program_node
from genesis_core.types import ctx_from_config

META = {"id": "liveness-probe", "name": "Liveness probe", "version": "0.1.0",
        "inputs_schema": {"type": "object", "properties": {"fail": {"type": "boolean", "default": False}}},
        "editable": ["inputs", "decisions"]}


def _holder(name):
    async def hold(state, config: RunnableConfig):
        root = Path(ctx_from_config(config).workspace.root)
        rnd = int((state.get("decisions") or {}).get(f"{name}_rounds", 0)) + 1
        (root / f"at-{name}-{rnd}").write_text("1")
        for _ in range(6000):
            if (root / f"go-{name}-{rnd}").exists():
                break
            await asyncio.sleep(0.1)
        if name == "work" and (state.get("inputs") or {}).get("fail") and rnd == 2:
            raise RuntimeError("probe: work failed on round 2")
        return {"decisions": {f"{name}_rounds": rnd}}
    return hold


def build(ctx):
    g = StateGraph(PlatformState)
    g.add_node("prepare", _holder("prepare"))
    g.add_node("work", _holder("work"))
    g.add_node("check", program_node(name="check", fn=lambda s, c: {}).fn)
    g.add_node("approve", hitl_gate(name="approve", kind="approval", prompt_fn=lambda s, c: "Approve the probe?").fn)
    g.add_node("finish", program_node(name="finish", fn=lambda s, c: {"status": "done"}).fn)
    g.add_edge(START, "prepare")
    g.add_edge("prepare", "work")
    g.add_edge("work", "check")
    g.add_conditional_edges("check", lambda s: "work" if int(s["decisions"].get("work_rounds", 0)) < 2 else "approve",
                            {"work": "work", "approve": "approve"})
    g.add_edge("approve", "finish")
    g.add_edge("finish", END)
    return g.compile(checkpointer=ctx.checkpointer)
