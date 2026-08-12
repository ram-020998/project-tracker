# 21-01 — ACP parity spike (load-bearing)

> **Status:** ✅ DONE (2026-08-12) — findings: `spike/2026-08-12-acp-parity.md`. **GO.** Verified against `kiro-cli 2.16.2`:
> model list + agents come free on `session/new` (`.models`/`.modes`); `set_model`/`set_mode` are plain requests; the full
> slash-command catalog + tools arrive via the `_kiro.dev/commands/available` notification (autocomplete done client-side —
> `optionsMethod` not wired in 2.16.2); `execute` streams (verify terminal signal in 21-04); `contextUsagePercentage` +
> `promptCapabilities.image` present. · **Phase:** 21 · **Repo:** genesis (throwaway harness) → findings under `spike/`
> **Depends on:** nothing · **Blocks:** 21-04 (SDK surface), 21-05 (parity wiring)

## Goal

Before we add ACP-extension methods to `kiro-agent-sdk` (21-04) and build UI on them (21-05), **prove the installed
`kiro-cli acp` actually implements them** and capture their exact request/response/notification shapes. This mirrors the
Phase-20 20-01 embed spike: throwaway code, durable findings.

## What to verify (from <https://kiro.dev/docs/cli/acp/>)

Drive a real `kiro-cli acp` subprocess over stdio JSON-RPC and confirm each, recording the concrete payloads:

1. **Model selection** — does `initialize` (or a follow-up) advertise an **available-models list**? Does **`session/set_model`**
   succeed, and can it be set **at `session/new`** time (our v1 need) vs only mid-session? Record the model id shape + how the
   list is obtained.
2. **Slash commands**
   - `_kiro.dev/commands/available` — captured as a **notification after `session/new`**? Record the command list schema
     (name, description, args, whether it's introspection vs state-changing).
   - `_kiro.dev/commands/options` — request for **autocomplete** of a partial command; record request + result shape.
   - `_kiro.dev/commands/execute` — execute a `/command`; record how output/updates come back (session updates? result?).
3. **Session management notifications** — observe **`_kiro.dev/compaction/status`** (trigger a compaction / large context) and
   **`_kiro.dev/clear/status`** (clear history); record their payloads + terminal signals.
4. **Context usage** — confirm we still receive `contextUsagePercentage` on turn metadata (we already consume it) and how it
   relates to the compaction signal.
5. **Image prompts** — confirm `promptCapabilities.image: true` and the **content-part shape** for an image in `session/prompt`
   (base64? path? mime?).

## Approach

- A small `spike/2026-08-12-acp-parity/harness.py` that spawns `kiro-cli acp` (path via the same resolution `kiro_node` uses),
  sends `initialize` with our client capabilities, then exercises each method above, dumping every frame to a log. Use
  `KIRO_ACP_DEBUG=1` / `KIRO_LOG_LEVEL=debug`.
- Prefer driving through the **existing `kiro-agent-sdk` client** where it already has a JSON-RPC transport; drop to raw frames
  for methods the SDK doesn't model yet.
- No product code changes. No new deps.

## Deliverables

- `spike/2026-08-12-acp-parity.md` — for each method: **supported? y/n**, exact request/response/notification JSON, quirks, and
  the **recommended SDK API shape** for 21-04 (method names, params, callback/event surface).
- A go/no-go + fallback per feature: e.g. if the CLI does **not** advertise models → model list comes from Settings; if
  `commands/available` isn't emitted → hard-code a curated slash set; if images unsupported → drop image attach from v1.

## Definition of done

- Every §"What to verify" item has a recorded verdict + payload sample in the spike doc.
- 21-04's SDK surface (method list + signatures) is decided and written down.
- Findings committed to project-tracker; harness left under `spike/` (throwaway, not wired into product).

## Notes / risks

- These `_kiro.dev/*` extensions are marked **experimental / subject to change** — pin the observed `kiro-cli` version in the
  findings so a later CLI bump that changes shapes is diagnosable.
- If a capability is missing in the installed CLI, the spike's fallback becomes the 21-05 behavior (don't block the phase on it).
