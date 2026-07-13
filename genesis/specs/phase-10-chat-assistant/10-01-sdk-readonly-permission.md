# 10-01 — SDK read-only permission policy (+ enforcement spike)

**Repo:** `kiro-agent-sdk` · **Ships:** v0.3.0 · **Depends on:** — · **Blocks:** 10-04, 10-07
**Why first:** read-only enforcement is the load-bearing risk of the whole phase (ADR-031). We
prove it against the real CLI **before** building the ChatManager on top of it.

## 1. Objective

Give the SDK a first-class, backward-compatible way to run a Kiro session **read-only**, and prove
the enforcement works end-to-end against real `kiro-cli` + the `appian-atlas` MCP.

## 2. Current state (verified)

`kiro-agent-sdk/src/kiro_agent_sdk/client.py`:
- `KiroACPClient.start()` sends `initialize` with
  `clientCapabilities.fs = {"readTextFile": True, "writeTextFile": True}` (writes advertised), then
  `session/new` with `mcpServers`. `prompt(text)` streams typed messages; `close()` terminates.
- `_handle_agent_request(msg)` **auto-approves** everything:
  - `fs/read_text_file` → reads and returns the file.
  - `fs/write_text_file` → **writes** the file and returns `{}`.
  - `session/request_permission` → selects the first `allow*` option (auto-approve).
  - unknown → empty result.
- `KiroAgentOptions` (dataclass) has `trust_all_tools=True`, `trust_tools`, `agent`, `model`,
  `agent_engine`, `kiro_cli_path`, `extra_args`, `mcp_servers`, `startup_timeout`, `turn_timeout`,
  `stream_limit_bytes`, `debug`. `_build_args()` emits `--trust-all-tools` when
  `trust_all_tools and not trust_tools`, else `--trust-tools a,b,c`.

So today a caller can restrict *trusted* tools, but anything untrusted is silently auto-approved,
and fs-writes always succeed. Read-only needs the client to be able to **deny**.

## 3. Design

### 3.1 New `KiroAgentOptions` fields (additive, defaults preserve current behavior)

```python
permission_mode: str = "auto_approve"   # "auto_approve" | "auto_deny"
allow_fs_write: bool = True             # False → refuse fs/write + advertise writeTextFile=False
```

- `permission_mode="auto_approve"` (default) → today's behavior, unchanged.
- `permission_mode="auto_deny"` → `session/request_permission` selects a **reject/cancel** option
  (see §3.3) instead of an allow option.
- `allow_fs_write=False` → `fs/write_text_file` requests are answered with a JSON-RPC error
  (`-32000`, "filesystem writes are disabled for this session"), **and** `initialize` advertises
  `clientCapabilities.fs.writeTextFile=false`.

`fs/read_text_file` is always honored (reads are safe; a read-only assistant may read files it is
pointed at). Terminal stays `false` (already).

### 3.2 `initialize` change

```python
"clientCapabilities": {
    "fs": {"readTextFile": True, "writeTextFile": self.options.allow_fs_write},
    "terminal": False,
},
```

### 3.3 `_handle_agent_request` change

```python
elif method == "session/request_permission":
    opts = params.get("options", [])
    if self.options.permission_mode == "auto_deny":
        # Prefer an explicit reject/deny option; else signal cancellation.
        deny = next((o for o in opts if o.get("kind", "").startswith(("reject", "deny"))), None)
        if deny is not None:
            self._respond(req_id, {"outcome": {"outcome": "selected",
                                               "optionId": deny.get("optionId", "reject")}})
        else:
            self._respond(req_id, {"outcome": {"outcome": "cancelled"}})
        return
    # ... existing auto-approve path ...

elif method == "fs/write_text_file":
    if not self.options.allow_fs_write:
        self._send({"jsonrpc": "2.0", "id": req_id,
                    "error": {"code": -32000, "message": "filesystem writes are disabled"}})
        return
    # ... existing write path ...
```

The exact `outcome`/`optionId` shape kiro-cli accepts for a denial is **the key unknown the spike
resolves** (§4). The code above is the intended target; the spike may adjust the precise field
names to match kiro-cli 2.12.x.

### 3.4 No new public surface beyond the two option fields

`KiroACPClient`, `query`, `collect`, `collect_streaming` are unchanged in signature. `__init__.py`
`__all__` unchanged (the options are dataclass fields).

## 4. The spike (do this first, record findings in the progress doc)

Environment: the dev venv + real `kiro-cli` (2.12.x) already used for the Phase-9 spike.

**S1 — trust allowlist limits auto-run.** Launch a persistent `KiroACPClient` with
`trust_all_tools=False, trust_tools=["get_app_schema"]` and the Atlas MCP; prompt it to use an
Atlas *read* tool → runs without a permission prompt. Confirm a non-trusted tool triggers
`session/request_permission`.

**S2 — auto-deny actually denies.** With `permission_mode="auto_deny"`, prompt the agent to do
something requiring a non-trusted tool; confirm the client denies and the **turn completes
gracefully** (the agent reports it can't, no hang to `turn_timeout`). Capture the exact
`session/request_permission` params + the accepted denial response shape (adjust §3.3 to match).

**S3 — fs-write disabled.** With `allow_fs_write=False`, prompt "write a file to /tmp/x"; confirm
the write is refused (error response) and the agent does not create the file.

**S4 — read still works.** Confirm `fs/read_text_file` + Atlas read tools still function with the
read-only options (no regression).

**S5 — multi-turn persistence.** `start()` once, `prompt()` twice; confirm the second turn retains
context from the first (validates the persistent-session model 10-04 relies on).

Spike artifacts go under `/tmp/spike-chat/` and are removed after; findings recorded in
`progress/phase-10-chat-assistant.md`.

## 5. Files to touch

- `kiro-agent-sdk/src/kiro_agent_sdk/client.py` — the two option fields, `initialize` capability,
  `_handle_agent_request` (permission + fs-write branches).
- `kiro-agent-sdk/tests/…` — unit tests with a fake stdio transport (or a direct
  `_handle_agent_request` unit test): auto_deny selects reject/cancel; allow path unchanged;
  fs-write disabled returns an error and unaffected when enabled; `initialize` advertises the right
  capability.
- `kiro-agent-sdk/pyproject.toml` — version → 0.3.0.
- `kiro-agent-sdk/README` / CHANGELOG — document the two options + the read-only recipe.

## 6. Tests / DoD

- New unit tests pass; existing SDK suite + ruff stay green.
- Defaults unchanged (a test asserts `permission_mode="auto_approve"` and `allow_fs_write=True`
  reproduce current auto-approve + write behavior).
- The spike checklist S1–S5 executed against real kiro-cli; findings + the confirmed denial-response
  shape recorded. **If S2 cannot be made to deny gracefully**, stop and escalate — the phase's
  read-only guarantee depends on it (alternative: a stricter agent-config / a wrapper MCP proxy).
- v0.3.0 tagged + pushed; CI green.

## 7. Risks

- kiro-cli's denial contract may differ from §3.3 → the spike adjusts the code to the observed
  shape before release.
- Some Kiro builds may auto-run certain built-ins regardless of trust → the spike must probe fs +
  a write-ish MCP tool, not just assume. If a built-in can't be denied, document it as a residual
  risk and compensate in steering + the introspection-only default.
