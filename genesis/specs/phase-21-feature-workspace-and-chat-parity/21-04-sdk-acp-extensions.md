# 21-04 — `kiro-agent-sdk` ACP extensions

> **Status:** 📝 DRAFT · **Phase:** 21 · **Repo:** kiro-agent-sdk · **Depends on:** 21-01 (spike findings) · **Blocks:** 21-05

## Goal

Add the ACP methods the chat-parity work needs to `kiro-agent-sdk`, exposed on the client API that the genesis in-process
`ChatManager` uses. **Exact shapes come from the 21-01 spike** — this spec fixes the *surface*, the spike fixes the *wire*.

## Scope (guided by the spike; drop any the CLI doesn't support)

1. **Model selection**
   - Read the **available models** advertised at `initialize` (or the documented list call) → `client.available_models()`.
   - **`session/set_model`** support, usable **at session creation** (set the model when the session/new is issued) — the v1
     need. (Mid-session `set_model` may be implemented but is not required by 21-05.)
   - `KiroAgentOptions.model` already exists; ensure the chosen model is applied at spawn.
2. **Slash commands** (the `_kiro.dev/commands/*` extension)
   - `client.list_commands(session)` ← the `_kiro.dev/commands/available` **notification** captured after `session/new`
     (surface it as data on the session + an on-update callback).
   - `client.command_options(session, partial)` → `_kiro.dev/commands/options` (autocomplete).
   - `client.execute_command(session, text)` → `_kiro.dev/commands/execute`, streaming the resulting session updates back
     through the **same event surface** as a normal turn (so the UI renders command output like any turn).
3. **Session-management notifications** — surface **`_kiro.dev/compaction/status`** and **`_kiro.dev/clear/status`** as
   callbacks/events (progress + terminal), and a `client.clear_session(...)` / `client.compact_session(...)` trigger if the CLI
   exposes them as commands (else these are just `/clear` / `/compact` via `execute_command`).
4. **Image prompt content** — extend the prompt-content builder to accept an **image content part** (per the spike's shape:
   base64+mime or path), gated on the advertised `promptCapabilities.image`.

## Design notes

- **Additive + backward-compatible.** No breaking changes to `collect`/`collect_streaming`/`permission_mode`/`fs_write_root`.
  New methods degrade gracefully (no-op / empty list) when the peer doesn't advertise the capability, so genesis-core and older
  callers are unaffected.
- **Experimental extensions** — isolate the `_kiro.dev/*` calls behind clearly-named methods with a comment that they're
  experimental + the CLI version verified in 21-01; keep a fixture of the observed frames so a CLI bump is diagnosable.
- Reuse the existing JSON-RPC transport + notification dispatch; commands stream via the existing session-update path.

## Testing

- Unit tests against a **fake ACP peer** (in-process JSON-RPC double) asserting: model list parsing, set-model-at-creation,
  `commands/available` capture, `commands/options` round-trip, `execute` streaming, compaction/clear status dispatch, image
  content-part serialization. Follow the SDK's existing test style (`tests/test_permission_policy.py` idiom).

## Definition of done

- New client methods land, all additive, SDK unit suite green.
- **Version bump + tag + push** `kiro-agent-sdk` (next minor). Record the new tag for the 21-05/21-07 pin bumps
  (genesis-core + genesis both pin the SDK directly).
- The SDK surface matches what 21-05 consumes (method names finalized here).
