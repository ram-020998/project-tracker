# Spike — ACP parity (Phase 21-01)

> **Date:** 2026-08-12 · **Verified against:** `kiro-cli 2.16.2` (agentInfo `Kiro CLI Agent` v2.16.2), ACP `protocolVersion 1`.
> **Harness:** `spike/2026-08-12-acp-parity/harness.py` (throwaway, stdlib-only; frame log `acp-frames.log`). Drives
> `kiro-cli acp` over stdio JSON-RPC, isolates each probe on a fresh session.
> **Verdict:** ✅ **GO for 21-04/21-05.** Everything Phase 21 needs is present in the *installed* 2.16.2 — richer than the
> public 3.x docs implied. Model list + agents come free on `session/new`; the full slash-command catalog + tool list arrive
> as a `commands/available` notification; `set_model`/`set_mode` are plain requests; images are supported.

## Verdicts

| Capability | Method / source | 2.16.2 | Notes |
|---|---|---|---|
| **Model list** | `session/new` **result `.models`** | ✅ | `{currentModelId, availableModels:[{modelId,name,description}]}`. No separate call, **no Settings fallback needed.** Observed: `auto`, `claude-opus-5`, `claude-sonnet-5`, `claude-opus-4.8` (current), `gpt-5.6-{sol,terra,luna}`, `claude-opus-4.{7,6,5}`, `claude-sonnet-4.{6,5}`, `claude-sonnet-4`, `claude-haiku-4.5`. |
| **Set model** | `session/set_model` request | ✅ | Params `{sessionId, modelId}` → `result {}`. Works post-`session/new`; use it to set the chosen model right after creation. (`--model <id>` CLI arg also works — SDK already passes `KiroAgentOptions.model`.) |
| **Agents (personas)** | `session/new` **result `.modes`** + `session/set_mode` | ✅ | `.modes = {currentModeId, availableModes:[{id,name,description,_meta}]}` (project-tracker, tao-architect, kiro_default, kiro_planner, kiro_guide). `session/set_mode {sessionId, modeId}` → `result {}`. **"mode" == agent persona, NOT the LLM** — keep distinct from model. |
| **Slash-command catalog** | `_kiro.dev/commands/available` **notification** (post `session/new`) | ✅ | Pushed (often repeated). Payload `{sessionId, commands:[…], prompts:[…], tools:[…]}`. Each command: `{name, description, meta:{inputType(selection\|panel), hint, subcommands, subcommandHints, subcommandDescriptions, optionsMethod?, local?, hidden?}}`. **Consume the notification; do NOT call it as a request** (→ -32601). |
| — full command set | | ✅ | `/agent /chat /clear /code /compact /context /effort /feedback /goal /guide /help /hooks /knowledge /mcp /model /paste /plan /prompts /quit /reply /rewind /stats /tools /usage`. |
| **Command autocomplete** | per-command `meta.optionsMethod` (e.g. `_kiro.dev/commands/model/options`, `/agent/options`, `/prompts/options`) | ⚠️ | Advertised on `/model`,`/agent`,`/prompts`, but calling `_kiro.dev/commands/model/options` / `/agent/options` as a request → **-32601** in 2.16.2 (advertised, not wired). **Do our own client-side autocomplete** off the `commands/available` catalog (name + subcommands + hints) instead of a server round-trip. |
| **Execute a slash command** | `_kiro.dev/commands/execute` | ⚠️ | Method **exists** (never -32601), but a headless request **times out** for `command`/`name`/`input` param shapes on `panel`-type commands — it almost certainly **streams output via `session/update` and/or awaits interactive panel dismissal** rather than returning a prompt-style result. **Handle as a streaming call, and verify the terminal signal in 21-04 with the live UI.** For the important state-changers prefer the **typed** methods where they exist (`set_model`, `set_mode`); `/clear`,`/compact`,`/context`,`/usage`,`/tools` go through execute. |
| **Context usage** | `_kiro.dev/metadata` notification | ✅ | `{sessionId, contextUsagePercentage}` (e.g. `0.8595`). Already consumed by the SDK's metering accumulator (`context_pct`). Surface it as the context meter directly. |
| **Compaction / clear status** | `_kiro.dev/compaction/status` · `_kiro.dev/clear/status` | ❓ | Not observed at idle (need to trigger `/compact` / `/clear`). Treated as best-effort progress notifications; wire the handlers, don't hard-depend on payload shape. `/clear` + `/compact` exist as commands. |
| **Image prompts** | `initialize` `promptCapabilities.image` | ✅ | `true` (audio/embeddedContext false). Send an image content-part in `session/prompt`; `/paste` command also exists. Confirm the exact content-part shape (base64+mime) when wiring 21-05. |
| **Other observed extensions** | | — | `_kiro.dev/mcp/server_initialized {sessionId, serverName}`; `_kiro.dev/subagent/list_update`. `agentCapabilities` also advertised `mcpCapabilities:{http:true,sse:false}`. |

## Recommended `kiro-agent-sdk` surface (21-04)

- **`SystemInit`**: expose `models` (from `session/new.result.models` → `current_model_id` + `available_models`) and `modes`
  (agents) + the `commands`/`tools` catalog captured from the first `_kiro.dev/commands/available` notification.
- **`set_model(model_id)`** → `session/set_model {sessionId, modelId}` (also settable at creation via existing `--model`).
- **`set_mode(mode_id)`** → `session/set_mode {sessionId, modeId}` (agent persona).
- **`available_commands`/`available_tools`**: parsed from the `commands/available` notification; also surface an
  `on_commands` update callback (it can be re-emitted).
- **Autocomplete**: **client-side** off the catalog (do not call `optionsMethod` — not wired in 2.16.2).
- **`execute_command(text)`**: send via `_kiro.dev/commands/execute` and **stream** the resulting `session/update`s through
  the normal turn surface; do not block on a request/response result. Reconcile the terminal signal in 21-04.
- **`context_pct`** already captured — reuse. Wire optional `on_compaction_status` / `on_clear_status` callbacks (best-effort).
- **Image content part** in the prompt builder, gated on `promptCapabilities.image`.

## Impact on the sub-specs

- **21-05 model selection**: source the list from `session/new.models` (drop the "Settings fallback" as the primary path;
  keep only as a defensive default). Model chosen at creation → apply via `--model` and/or `set_model` immediately after
  `session/new`. **A `chat_sessions.model` column (`m0011`) is worth adding** to remember/restore the choice.
- **21-05 slash commands**: palette + **client-side autocomplete** from the catalog; execution streams via `execute`.
- **21-05 context/compaction**: context meter is free (`contextUsagePercentage`); compaction/clear are best-effort.
- **21-04**: proceed with the surface above; the only genuinely uncertain piece is `execute`'s terminal/stream semantics —
  nail it there with the live UI, with sending slash text through the normal prompt path as the fallback.

## Reproduce

```
python3 spike/2026-08-12-acp-parity/harness.py    # dumps caps, models, modes, full command catalog + isolated probes
# frames: spike/2026-08-12-acp-parity/acp-frames.log
```
