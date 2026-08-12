#!/usr/bin/env python3
"""21-01 ACP parity spike harness (THROWAWAY).

Spawns `kiro-cli acp`, does the initialize/session/new handshake, then probes the
ACP-extension methods Phase-21 needs (model selection, slash commands, compaction/
clear status, image prompts). Records every JSON-RPC frame to a log and prints a
verdict table distinguishing:

  -32601 method-not-found  -> capability ABSENT in this CLI
  -32602 invalid-params    -> method EXISTS, our param shape is wrong (retry shapes)
  result                   -> SUPPORTED (shape captured)

Cheap by design: initialize + session/new + metadata-style probes only. It does NOT
send a real `session/prompt` turn (no credits burned) unless --turn is passed.

Usage:  python3 harness.py [--turn]
Env:    KIRO_ACP_DEBUG=1 for extra stderr.  Verified against: kiro-cli <version> (see findings).
"""
from __future__ import annotations

import asyncio
import json
import os
import shutil
import sys
import time
from pathlib import Path

LOG = Path(__file__).with_name("acp-frames.log")
PROTOCOL_VERSION = 1


def _resolve_binary() -> str:
    path = shutil.which("kiro-cli")
    if path:
        return path
    cand = Path.home() / ".local" / "bin" / "kiro-cli"
    if cand.exists():
        return str(cand)
    raise FileNotFoundError("kiro-cli not found")


class Probe:
    def __init__(self) -> None:
        self.proc: asyncio.subprocess.Process | None = None
        self.next_id = 0
        self.pending: dict[int, asyncio.Future] = {}
        self.notes: list[tuple[float, str, dict]] = []  # (t, method, params)
        self.session_id: str | None = None
        self._log = LOG.open("w")

    def log(self, direction: str, obj) -> None:
        text = obj if isinstance(obj, str) else json.dumps(obj)
        self._log.write(f"{time.time():.3f} {direction} {text}\n")
        self._log.flush()

    def send(self, payload: dict) -> None:
        assert self.proc and self.proc.stdin
        self.log("send", payload)
        self.proc.stdin.write((json.dumps(payload) + "\n").encode())

    async def request(self, method: str, params: dict, timeout: float = 15.0):
        self.next_id += 1
        rid = self.next_id
        fut = asyncio.get_event_loop().create_future()
        self.pending[rid] = fut
        self.send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
        try:
            return {"ok": True, "result": await asyncio.wait_for(fut, timeout)}
        except asyncio.TimeoutError:
            return {"ok": False, "error": {"timeout": timeout}}
        except RuntimeError as e:
            # carries the JSON-RPC error dict as str
            return {"ok": False, "error": str(e)}
        finally:
            self.pending.pop(rid, None)

    async def read_loop(self) -> None:
        assert self.proc and self.proc.stdout
        while True:
            line = await self.proc.stdout.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
            self.log("recv", line.decode("utf-8", "replace"))
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            self.dispatch(msg)

    async def drain_stderr(self) -> None:
        assert self.proc and self.proc.stderr
        while True:
            line = await self.proc.stderr.readline()
            if not line:
                break
            self.log("stderr", line.decode("utf-8", "replace").rstrip())

    def dispatch(self, msg: dict) -> None:
        if "id" in msg and ("result" in msg or "error" in msg) and "method" not in msg:
            fut = self.pending.get(msg["id"])
            if fut and not fut.done():
                if "error" in msg:
                    fut.set_exception(RuntimeError(json.dumps(msg["error"])))
                else:
                    fut.set_result(msg.get("result", {}))
            return
        method = msg.get("method", "")
        if "id" in msg and "method" in msg:
            # agent -> client request: answer minimally so nothing hangs
            if method == "fs/read_text_file":
                try:
                    txt = Path(msg["params"]["path"]).read_text()
                    self.send({"jsonrpc": "2.0", "id": msg["id"], "result": {"content": txt}})
                except Exception as e:
                    self.send({"jsonrpc": "2.0", "id": msg["id"],
                               "error": {"code": -32000, "message": str(e)}})
            elif method == "session/request_permission":
                opts = msg["params"].get("options", [])
                deny = next((o["optionId"] for o in opts
                             if str(o.get("kind", "")).startswith(("reject", "deny"))), None)
                out = ({"outcome": "selected", "optionId": deny} if deny
                       else {"outcome": "cancelled"})
                self.send({"jsonrpc": "2.0", "id": msg["id"], "result": {"outcome": out}})
            else:
                self.send({"jsonrpc": "2.0", "id": msg["id"], "result": {}})
            return
        # notification
        self.notes.append((time.time(), method, msg.get("params", {})))

    async def start(self):
        binary = _resolve_binary()
        self.proc = await asyncio.create_subprocess_exec(
            binary, "acp",
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE, env=os.environ.copy(),
            limit=16 * 1024 * 1024,
        )
        asyncio.create_task(self.read_loop())
        asyncio.create_task(self.drain_stderr())
        init = await self.request("initialize", {
            "protocolVersion": PROTOCOL_VERSION,
            "clientCapabilities": {"fs": {"readTextFile": True, "writeTextFile": True},
                                   "terminal": False},
            "clientInfo": {"name": "acp-parity-spike", "version": "0.0.1"},
        })
        newr = await self.request("session/new",
                                  {"cwd": os.getcwd(), "mcpServers": []})
        if newr["ok"]:
            self.session_id = newr["result"].get("sessionId") or newr["result"].get("session_id")
        return init, newr


def verdict(r: dict) -> str:
    if r["ok"]:
        return "SUPPORTED"
    err = r["error"]
    if isinstance(err, str) and "-32601" in err:
        return "ABSENT (-32601 method not found)"
    if isinstance(err, str) and "-32602" in err:
        return "EXISTS, bad params (-32602)"
    if isinstance(err, dict) and "timeout" in err:
        return "TIMEOUT"
    return f"ERROR {err}"


async def main() -> None:
    # ---- Phase 1: one session, dump capabilities + the full commands/available list ----
    p = Probe()
    init, newr = await p.start()
    print("=== initialize.agentCapabilities ===")
    print(json.dumps(init["result"].get("agentCapabilities", {}), indent=2))
    print("=== session/new.modes (these are AGENTS, not models) ===")
    print(json.dumps(newr["result"].get("modes", {}), indent=2)[:1500])
    await asyncio.sleep(2.0)
    cmds = None
    for _t, m, params in p.notes:
        if m == "_kiro.dev/commands/available":
            cmds = params.get("commands")
    print("\n=== _kiro.dev/commands/available (full) ===")
    print(json.dumps(cmds, indent=2) if cmds else "(none captured)")
    print("\n=== distinct _kiro.dev/* notification methods seen ===")
    for meth in sorted({m for _t, m, _p in p.notes if m.startswith("_kiro.dev/")}):
        print(f"  {meth}")
    if p.proc and p.proc.returncode is None:
        p.proc.terminate()

    # derive the /agent optionsMethod if present
    opt_method = None
    for c in (cmds or []):
        if c.get("name") == "/agent":
            opt_method = (c.get("meta") or {}).get("optionsMethod")

    # ---- Phase 2: isolated single-request probes (fresh session each, no cross-block) ----
    probes = [
        ("_kiro.dev/commands/model/options", {"sessionId": "SID", "query": ""}),
        ("_kiro.dev/commands/model/options", {"sessionId": "SID"}),
        ("_kiro.dev/commands/execute", {"sessionId": "SID", "command": "/context show"}),
        ("_kiro.dev/commands/execute", {"sessionId": "SID", "name": "context", "arguments": "show"}),
        ("_kiro.dev/commands/execute", {"sessionId": "SID", "input": "/context show"}),
    ]
    print("\n=== isolated extension-method probes ===")
    for method, params in probes:
        pp = Probe()
        _i, _n = await pp.start()
        await asyncio.sleep(0.8)
        params = {**params, "sessionId": pp.session_id}
        r = await pp.request(method, params, timeout=8.0)
        print(f"  {method}  {json.dumps({k: v for k, v in params.items() if k != 'sessionId'})}")
        print(f"     -> {verdict(r)}")
        if r["ok"]:
            print(f"        result: {json.dumps(r['result'])[:500]}")
        if pp.proc and pp.proc.returncode is None:
            pp.proc.terminate()
        await asyncio.sleep(0.2)

    print(f"\nfull frame log: {LOG}")


if __name__ == "__main__":
    asyncio.run(main())
