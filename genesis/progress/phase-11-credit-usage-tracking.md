# Phase 11 — Credit & Usage Tracking (as-built)

**Shipped 2026-07-14.** kiro-agent-sdk **v0.4.0** → genesis-core **v0.8.0** → genesis **v0.20.0**.
Spec: `specs/phase-11-credit-usage-tracking.md`. Decision: **ADR-032**.

## What shipped
Real, metered per-turn Kiro credits surfaced across the app: per agent node + run-total on Run
Detail, the Overview KPI (**Credits Used** replacing Tool-Calls), and per assistant message + session
total in Chat. **No estimation** — the values are what Kiro bills.

## The spike (the pivotal finding)
A raw JSON-RPC ACP driver against **kiro-cli 2.12.1** showed Kiro emits a `_kiro.dev/metadata`
notification; the final one per turn carries:
```json
{ "sessionId": "…", "contextUsagePercentage": 2.90,
  "meteringUsage": [ { "value": 0.18439677, "unit": "credit", "unitPlural": "credits" } ],
  "turnDurationMs": 2510 }
```
Verified **per-turn, not cumulative** (turn1 0.1844, turn2 0.1115 in one session). This flipped the
plan from "estimate credits" to "surface real metered credits".

## Implementation (by layer)
- **kiro-agent-sdk v0.4.0** — `client.py::prompt` accumulates `_kiro.dev/metadata` per turn
  (`_accumulate_meta`/`_finalize_usage`); attaches `usage = {credits, context_pct, turn_duration_ms,
  provenance}` to the terminal `ResultMessage`; `collect_streaming` copies it to `TurnResult.usage`.
  `provenance` = `metered` (credits present) or `unavailable`. 7 new tests (real spike shape).
- **genesis-core v0.8.0** — `nodes/agent.py` reads `turn.usage` → per-node telemetry
  (credits/credit_provenance/context_pct) + `_run` aggregate credits + fields on the `agent.result`
  event. `state.py::_telemetry_merge` hardened: a `None` credits value never clobbers an accumulated
  sum while preserving the schema key. `CORE_MAJOR` stays 1 (additive).
- **genesis v0.20.0**
  - `runs/eventlog.py`: `aggregate_credits` / `run_credits` / `credits_provenance`
    (`SUM(json_extract(payload,'$.credits'))` over `agent.result`; non-null filter).
  - `runs/steps.py::fold_steps`: per-node credits (summed across attempts) + context_pct.
  - `api/home.py`: metrics gain `total_credits` + `credits_provenance`.
  - **Chat:** `m0003_chat_usage` adds `chat_messages.usage`; store persists/decodes + `session_usage_total`;
    `manager.stream_turn` persists usage on the assistant message + emits credits on the terminal
    `agent.result`; `api/chat.py` returns per-message `usage` + session `usage_total`.
  - **Web:** `formatCredits` + `CreditBadge` + `Coins` icon; Overview KPI **Credits Used** (replaces
    Tool-Calls); run-detail `TelemetryStrip` Credits stat (grid + stacked) + per-node credits +
    header run-total (`sum(steps[].credits)`); chat per-message credit footer. `web/static` rebuilt.

## Why it "just worked" through the stack
The agent already emits `agent.result` and `manager._CANONICAL_CUSTOM` persists it into `run_events`
with `node` + full payload — so adding `credits` to the emit flowed automatically to aggregation,
the per-node fold, and the live SSE with no extra plumbing. Verified by reading `manager.py` before
implementing.

## Verification
- kiro-agent-sdk: 62 pytest (7 new), ruff clean.
- genesis-core: 57 pytest (credits sum/no-clobber + agent metered/unavailable), ruff clean.
- genesis: 116 pytest (aggregate_credits/provenance, fold credits, home value-path, chat metered +
  unavailable, m0003 migration + usage round-trip), ruff clean.
- web: 78 vitest (Overview Credits KPI, TelemetryStrip credits grid/stacked/na, chat footer),
  tsc clean, 0 eslint errors; `npm run build` + committed `web/static`.
- CI: genesis-core #6340868 ✅, genesis #6340870 ✅ (frontend job + stale-bundle guard). The SDK repo
  has no CI of its own; core + genesis install from the `v0.4.0` tag and passed, validating it.

## Provenance / honesty
Every credit figure carries `provenance`; when a turn lacks metering (older kiro-cli) the value is
`null`/`unavailable` and the UI shows **n/a**, never a fabricated number. `partial` marks an
aggregate where some turns were metered and some were not.

## Follow-ups (not done)
- Live end-to-end check against a real workflow run + chat turn (the SDK spike already proved the
  metering source; the plumbing is unit-tested end to end with the real shape).
- Optional: Runs-list credits column; a usage trend / cost-over-time view (out of scope for v1).
- The onboarding "bible" (`AGENT_ONBOARDING.md`) §2 tag table is stale (still v0.16.0) — separate refresh.
