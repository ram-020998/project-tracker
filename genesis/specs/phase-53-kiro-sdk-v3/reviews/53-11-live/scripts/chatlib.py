"""Chat helpers for the 53-11 live rows: drive the 53-11 instance's /api/chat over HTTP + SSE, the way the web does.
Every event is kept with its time offset from the send. Nothing here prints a secret (chat payloads only)."""
from __future__ import annotations

import asyncio
import json
import time
from typing import Any, Callable, Optional

import httpx

BASE = "http://127.0.0.1:8770/api"


def client() -> httpx.AsyncClient:
    return httpx.AsyncClient(base_url=BASE, timeout=httpx.Timeout(60, read=400))


async def new_session(c: httpx.AsyncClient, title: str, mode: Optional[str] = None) -> str:
    sid = (await c.post("/chat/sessions", json={"title": title})).json()["id"]
    if mode:
        r = await c.post(f"/chat/sessions/{sid}/mode", json={"mode": mode})
        r.raise_for_status()
    return sid


async def send(c: httpx.AsyncClient, sid: str, text: str,
               actions: Optional[list[tuple[Callable[[float, list], bool], Callable[[], Any]]]] = None) -> dict:
    """POST a message and read its SSE to the end. ``actions``: (predicate(t, events), coroutine-factory) pairs;
    each fires once, the first time its predicate is true (checked on every event and every 0.1 s)."""
    t0 = time.monotonic()
    events: list[dict] = []
    fired: list[dict] = []
    pending = list(actions or [])
    done = asyncio.Event()

    async def watcher():
        while not done.is_set():
            await check()
            await asyncio.sleep(0.1)

    async def check():
        t = time.monotonic() - t0
        for pair in list(pending):
            pred, act = pair
            if pred(t, events):
                pending.remove(pair)
                res = await act()
                fired.append({"t": round(time.monotonic() - t0, 2), "action": getattr(act, "__name__", "act"),
                              "result": res})

    w = asyncio.create_task(watcher())
    try:
        async with c.stream("POST", f"/chat/sessions/{sid}/messages", json={"text": text}) as r:
            if r.status_code != 200:
                body = (await r.aread()).decode()
                return {"status": r.status_code, "body": body, "events": [], "fired": fired}
            ev_name, data = None, []
            async for line in r.aiter_lines():
                line = line.rstrip("\r")
                if line.startswith("event:"):
                    ev_name = line[6:].strip()
                elif line.startswith("data:"):
                    data.append(line[5:].strip())
                elif line == "" and data:
                    try:
                        ev = json.loads("\n".join(data))
                    except ValueError:
                        ev = {"type": ev_name, "raw": "\n".join(data)}
                    ev["_t"] = round(time.monotonic() - t0, 2)
                    events.append(ev)
                    ev_name, data = None, []
                    await check()
    finally:
        done.set()
        await w
    return {"status": 200, "events": events, "fired": fired}


def answer(res: dict) -> str:
    return "".join(e.get("text", "") for e in res["events"] if e.get("type") == "agent.message")


def result(res: dict) -> dict:
    for e in reversed(res["events"]):
        if e.get("type") == "agent.result":
            return e
    return {}


def tools(res: dict) -> list[dict]:
    return [{"t": e["_t"], "name": e.get("tool_name") or e.get("name"), "title": e.get("title"),
             "input": e.get("input") or e.get("raw_input")}
            for e in res["events"] if e.get("type") == "agent.tool_call"]


def brief(res: dict) -> dict:
    r = result(res)
    return {"status": res.get("status"), "answer": answer(res)[:600], "tools": tools(res),
            "result": {k: r.get(k) for k in ("ok", "stop_reason", "credits", "provenance", "error", "code",
                                              "tool_calls", "unread_steers", "model", "fallback_from")},
            "other_events": [{k: v for k, v in e.items() if k in ("type", "_t", "status", "text", "message_seq",
                                                                    "kind", "detail", "servers", "message")}
                             for e in res["events"]
                             if e.get("type") not in ("agent.message", "agent.thought", "agent.tool_update",
                                                      "agent.tool_call", "agent.result")],
            "fired": res.get("fired"), "events_n": len(res["events"])}


async def messages(c: httpx.AsyncClient, sid: str) -> list[dict]:
    return (await c.get(f"/chat/sessions/{sid}")).json()["messages"]
