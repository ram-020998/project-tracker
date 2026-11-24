"""55-13 §2 spike: how the SDK reports the models advertised at session start, and what an id that is not in that
list does, on the installed kiro-cli (v3 engine, ADR-086), with the product's own session shape (L-044, L-117).

The session is built the way ``genesis_core.nodes.agent.kiro_node`` builds a workflow turn: cwd = a scratch run folder,
``KIRO_HOME`` = ``<run>/_kiro``, the projected ``genesis-node`` agent with ``NODE_AGENT_PROMPT``, the D9 trust policy
(the built-ins + ``@blackboard``), and the blackboard MCP server. One case per session (L-117 (6)).

  S1  no model                 -> the advertised list (ids, names, current) and the start time
  S2  a listed non-current id  -> positive control: the session's current model becomes that id
  S3  an id not in the list    -> negative control: what the SDK does with ``options.model``
  S4  the same id, SDK check bypassed (raw ``session/set_config_option``), then one tiny prompt -> the engine's own
      behaviour (error, silent default, or a fallback frame) and the credits it charged
  S5  start + close with no MCP server and no model, three times -> the cost of reading the list alone

Run: ``<genesis>/.venv/bin/python spike_models.py <out.json>``. Writes no secret; the prompt is a fixed "Reply OK".
"""
from __future__ import annotations

import asyncio
import json
import sys
import time
from pathlib import Path

from genesis_core.nodes.agent import NODE_AGENT_ID, NODE_AGENT_PROMPT, _node_mcp_trust, _trust_policy
from kiro_agent_sdk import KiroACPClient, KiroAgentOptions, KiroError, collect_streaming

BAD = "genesis-no-such-model-55-13"
ROOT = Path("/tmp/spike-55-13")


class _NoRegistry:
    def allowlist(self, _name):
        return None


def _opts(case: str, *, model: str | None = None, blackboard: bool = True) -> KiroAgentOptions:
    run = ROOT / case
    (run / "_kiro").mkdir(parents=True, exist_ok=True)
    servers = []
    if blackboard:
        servers.append({"name": "blackboard", "command": sys.executable,
                        "args": ["-m", "genesis_core.mcp.blackboard_server", "--root", str(run)], "env": []})
    tools = _node_mcp_trust(None, [], _NoRegistry(), blackboard=blackboard)
    return KiroAgentOptions(cwd=str(run), kiro_home=str(run / "_kiro"), mcp_servers=servers, model=model,
                            turn_timeout=120, startup_timeout=60, trust=_trust_policy(tools),
                            agent_id=NODE_AGENT_ID, agent_prompt=NODE_AGENT_PROMPT)


async def _start(case: str, **kw) -> dict:
    client = KiroACPClient(_opts(case, **kw))
    t0 = time.monotonic()
    out: dict = {"case": case}
    try:
        init = await client.start()
        out["start_s"] = round(time.monotonic() - t0, 2)
        out["kiro_version"] = client.kiro_version
        out["models"] = init.models
        out["current_after_start"] = client.current_model_id
    except KiroError as e:
        out["start_s"] = round(time.monotonic() - t0, 2)
        out["error"] = {"type": type(e).__name__, "code": e.code, "message": e.message, "detail": e.detail}
    finally:
        await client.close()
    return out


async def s4() -> dict:
    """The SDK check bypassed: the raw engine request, then the next prompt."""
    client = KiroACPClient(_opts("s4"))
    out: dict = {"case": "s4"}
    try:
        await client.start()
        session = client._session
        res = await session._req("session/set_config_option",
                                 {"sessionId": session.session_id, "configId": "model", "value": BAD})
        out["set_answer_current"] = ((res or {}).get("configOptions") and
                                     [o.get("currentValue") for o in res["configOptions"] if o.get("id") == "model"])
        kinds: list[str] = []
        last = None
        async for m in client.prompt("Reply with the single word OK."):
            kinds.append(type(m).__name__)
            last = m
        out["messages"] = kinds
        out["result"] = {"stop_reason": getattr(last, "stop_reason", None), "error": getattr(last, "error", None),
                         "error_code": getattr(last, "error_code", None), "usage": getattr(last, "usage", None)}
    except KiroError as e:
        out["error"] = {"type": type(e).__name__, "code": e.code, "message": e.message, "detail": e.detail}
    finally:
        await client.close()
    return out


async def s3_turn() -> dict:
    """S3 through the product's call (``collect_streaming``): does the error escape before any message?"""
    seen: list[str] = []
    try:
        turn = await collect_streaming("Reply with the single word OK.", _opts("s3b", model=BAD),
                                       on_message=lambda m: seen.append(type(m).__name__))
        return {"case": "s3b", "returned": True, "error": turn.error, "messages": seen}
    except KiroError as e:
        return {"case": "s3b", "raised": {"code": e.code, "message": e.message, "detail": e.detail},
                "messages_before_raise": seen}


def _ids(r: dict) -> list:
    return [m.get("modelId") for m in (r.get("models") or {}).get("availableModels") or []]


async def only_s5(out_path: str) -> None:
    """S5 again with the lists kept: is the list read with no MCP server the one the product session gets?"""
    s1 = await _start("s1-again")
    runs = [await _start(f"s5-{i}", blackboard=False) for i in range(3)]
    out = {"s1_ids": _ids(s1), "s1_current": s1.get("current_after_start"),
           "s5": [{"start_s": r.get("start_s"), "same_ids_as_s1": _ids(r) == _ids(s1),
                   "current": r.get("current_after_start")} for r in runs]}
    Path(out_path).write_text(json.dumps(out, indent=1))
    print(json.dumps(out, indent=1))


async def main(out_path: str) -> None:
    results: dict = {}
    results["s1"] = await _start("s1")
    listed = [m.get("modelId") for m in (results["s1"].get("models") or {}).get("availableModels") or []]
    current = (results["s1"].get("models") or {}).get("currentModelId")
    other = next((m for m in listed if m and m != current), None)
    results["s2"] = await _start("s2", model=other)
    results["s2"]["requested"] = other
    results["s3"] = await _start("s3", model=BAD)
    results["s3b"] = await s3_turn()
    results["s4"] = await s4()
    results["s5"] = [await _start(f"s5-{i}", blackboard=False) for i in range(3)]
    for r in results["s5"]:
        r.pop("models", None)
    Path(out_path).write_text(json.dumps(results, indent=1, default=str))
    print(json.dumps({k: (v if k != "s1" else {**v, "models": {"current": current, "ids": listed}})
                      for k, v in results.items()}, indent=1, default=str))


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[2] == "s5":
        asyncio.run(only_s5(sys.argv[1]))
    else:
        asyncio.run(main(sys.argv[1]))
