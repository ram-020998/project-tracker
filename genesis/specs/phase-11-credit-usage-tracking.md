# Phase 11 — Credit & Usage Tracking

> **Status:** DRAFT (spec / analysis — not started)
> **Author:** Genesis agent · **Date:** 2026-07-14 · **Spike-verified:** 2026-07-14 (kiro-cli 2.12.1)
> **Scope:** Surface **real, metered credit usage** to the user everywhere it is meaningful — per
> agent invocation, per complete run, on the Overview dashboard (replacing the Tool-Calls KPI),
> and per message in Chat. **A live ACP spike confirmed Kiro reports actual per-turn credits**, so
> this is a *plumb-real-data-through* feature (not an estimation model — see §2).
> **Repos touched:** `kiro-agent-sdk` (usage capture) → `genesis-core` (telemetry) →
> `genesis` (persistence, aggregation, API, chat, web). `genesis-workflows` unaffected.
> **Proposed releases:** kiro-agent-sdk **v0.4.0** → genesis-core **v0.8.0** → genesis **v0.20.0**.

---

## 1. Why (motivation)

Solutions engineers run agentic workflows and a Chat assistant that consume **Kiro credits**
(Kiro's usage/billing unit). Today Genesis shows *tool-call* counts as a proxy for "activity"
but gives the user **no visibility into cost**. The user cannot answer basic questions:
"How much did this run cost?", "Which step is expensive?", "How much has this chat consumed?",
"What's my total usage?". This phase makes credit usage a first-class, always-visible metric
across the application.

**Explicit asks (from the request):**
1. Show credit usage **whenever an agent is invoked** (per agent node / per turn).
2. Show **total credit usage for a complete run**.
3. On the **Overview** page, **remove the Tool-Calls KPI and replace it with Total Credit Usage**.
4. In **Chat**, show the credits used **per assistant message**.
5. A clear, consistent view of credit usage **across the whole application**.

---

## 2. The data source — VERIFIED BY LIVE SPIKE

The original draft of this spec assumed (from ACP/Kiro docs and GitHub issues) that per-turn credit
data was **not** available and that Genesis would have to *estimate*. **A live ACP spike disproved
that assumption for the installed Kiro (2.12.1).** Kiro reports **real, metered, per-turn credits.**

### 2.1 What the spike did
A raw JSON-RPC driver (`acp_credit_spike.py`) spawned `kiro-cli acp --trust-all-tools`, ran
`initialize` → `session/new` → two `session/prompt` turns, and dumped every message, recursively
flagging any key matching `usage|token|credit|cost|context|meta|price|billing`.

### 2.2 What Kiro emits (ground truth)
During a turn, Kiro sends a custom notification **`_kiro.dev/metadata`** (a `session/update`-style
message). Intermediate ones carry `contextUsagePercentage`; the **final one of each turn** carries
the actual credit cost:
```json
// method: "_kiro.dev/metadata"
{
  "sessionId": "8f038be5-...",
  "contextUsagePercentage": 2.8958,
  "meteringUsage": [ { "value": 0.18439677, "unit": "credit", "unitPlural": "credits" } ],
  "turnDurationMs": 2510
}
```
- `meteringUsage[]` — a list of `{value, unit, unitPlural}`; the `unit: "credit"` entry is the
  **real credits consumed by that turn** (a small fractional number).
- `contextUsagePercentage` — % of the model context window used (informational; not credits).
- `turnDurationMs` — Kiro's own measure of turn wall-time.

### 2.3 Per-turn, not cumulative (verified)
Two turns in the **same** persistent session reported **independent** values:
`turn 1 = 0.18439677 credits`, `turn 2 = 0.11153860 credits` (not the ~0.296 a cumulative counter
would show). Therefore `meteringUsage` is the **cost of that single turn** — correct for both
models we care about:
- **workflow node** — a fresh short-lived session per node → one turn → one metering value = node credits.
- **chat message** — a persistent session, but each turn reports only its own credits → per-message credits.

### 2.4 Consequences
- This is **`provenance = "metered"`** — real data, no estimation. We keep the `provenance` tag only
  so the UI can gracefully mark the rare fallback case (older kiro-cli that omits `_kiro.dev/metadata`
  → `provenance = "unavailable"`, value `null`). No pricing table, no heuristic estimator needed.
- **The codebase already reserved the slot.** `genesis_core/nodes/agent.py` writes
  `"credits": None  # pending SDK usage exposure`; `state.py::_telemetry_merge` already sums a
  per-node `credits`. Phase 11 fills the slot with the metered value from the SDK.
- The unit is a **fractional credit** (e.g. 0.18). Store the raw float; format for display
  (e.g. 2 decimals, or sum then round). Do **not** truncate to int.

---

## 3. The usage capture model (no estimation)

Because Kiro provides real credits, there is **no `CreditModel`/pricing engine** (the earlier draft's
`genesis_core/pricing.py` and `credit-pricing.json` are **dropped**). The design is a thin,
graceful-degrading **capture + carry** of the metered value.

### 3.1 The captured usage shape (SDK → core → API)
```
Usage = {
  credits: float | None,          # meteringUsage[unit=credit].value; None if kiro omitted it
  context_pct: float | None,      # contextUsagePercentage (last seen)
  turn_duration_ms: int | None,   # turnDurationMs (Kiro's own; distinct from our measured wall-time)
  provenance: "metered" | "unavailable",
}
```
- `credits` is the sum of `meteringUsage` entries whose `unit == "credit"` from the **last**
  `_kiro.dev/metadata` of the turn (there is one credit entry today; summing is future-proof).
- If no `_kiro.dev/metadata` with `meteringUsage` arrived, `credits = None`,
  `provenance = "unavailable"` → the UI shows "n/a" (not a fake number).

### 3.2 Aggregation semantics
- **Run total** = Σ per-node `credits` (across all turns incl. retries — each attempt is a real
  billed turn, so it counts).
- **Provenance of an aggregate** = `"metered"` if every contributing turn was metered, else
  `"partial"` (some turns lacked data) — surfaced so a run total with a gap is marked.
- Fractional credits sum exactly (floats); round only at display.

---

## 4. Full surface inventory (every place credits appear)

| # | Surface | File(s) | Change |
|---|---|---|---|
| S1 | Agent turn (node) telemetry | `genesis_core/nodes/agent.py` | fill `credits` + `tokens_*`; add to `_run` aggregate; emit on `agent.result` |
| S2 | Telemetry reducer | `genesis_core/state.py` | sum `tokens_in`/`tokens_out` (credits already summed) |
| S3 | Durable event payload | `run_events` (auto — payload is JSON) | `agent.result` carries `credits`,`tokens`,`provenance` |
| S4 | Run-total + per-node fold | `genesis/runs/steps.py::fold_steps` | fold credits/tokens per node from `agent.result` |
| S5 | Cross-run aggregate | `genesis/runs/eventlog.py` | new `aggregate_credits(run_ids)` via `json_extract` |
| S6 | Overview KPI | `genesis/api/home.py`, `web/.../overview/OverviewPage.tsx`, `web/src/types/home.ts` | **replace Tool-Calls KPI with Credits KPI** |
| S7 | Run Detail metrics strip | `web/.../run-detail/components/Timeline.tsx`, `hooks.ts` (`StepSummary`) | add Credits stat (grid + stacked variants) + per-node credits |
| S8 | Run Detail header/run-total | `web/.../run-detail/RunDetailPage.tsx` | run-total credits near status (client-side sum of `/steps`) |
| S9 | Chat per-message | `genesis/chat/manager.py`, `store.py`, `api/chat.py`, `web/.../chat/ChatThread.tsx`, `web/src/types/chat.ts` | per-message credit footer + per-session total |
| S10 | Chat persistence | `genesis/db/migrations/m0003_chat_usage.py`, `chat_messages` | new `usage` column |
| S11 | Shared formatting | `web/src/shared/ui/format.tsx` + `icons.ts` | `formatCredits` + a `CreditBadge`/coin icon |
| S12 | Runs list column (optional) | `web/.../runs/**` | per-run credits column |

---

## 5. Architecture & data flow

```
kiro-cli (ACP)  ──_kiro.dev/metadata{ meteringUsage[credit], contextUsagePercentage, turnDurationMs }──▶
  kiro-agent-sdk: capture last metadata → ResultMessage.usage / TurnResult.usage   (11-01, additive)
        │
        ▼
genesis-core: kiro_node / chat turn
  telemetry[node].credits = turn.usage.credits (metered) ; add credits to _run aggregate   (11-02)
  emit agent.result{ credits, context_pct, turn_duration_ms, provenance }
        │                                            │
   (workflow run)                               (chat turn)
        ▼                                            ▼
run_events (durable JSON payload)            chat_messages.usage (11-04, m0003)
        │                                            │
  fold_steps (per-node)  ·  aggregate_credits (per/all runs)   (11-03)
        │                                            │
  GET /api/runs/{id}/steps (+credits)          GET /api/chat/sessions/{id} (+usage)
  GET /api/home (total_credits, replaces tool_calls)          SSE agent.result{credits}
        │                                            │
        ▼                                            ▼
  Overview KPI · Run-Detail strip/nodes · Runs col   Chat per-message footer + session total   (11-05)
```

**No new authoritative store for run credits** (ADR-030 — stay lean): run credits derive from the
existing `run_events` `agent.result` payloads via `json_extract`, exactly as tool-calls do today.
Chat needs a small additive column because chat messages are the unit of display and are queried
directly (not folded from an event log).

---

## 6. Implementation plan (sub-phases)

### 11-01 — SDK usage capture (`kiro-agent-sdk`, additive → v0.4.0)
This is the heart of the phase: capture Kiro's real metered credits.
- `messages.py`: add `usage: Optional[dict]` to `ResultMessage` and to `TurnResult`.
- `client.py::prompt` (the capture seam — this is where the terminal `ResultMessage` is assembled):
  recognize the **`_kiro.dev/metadata`** notification (method match on `_kiro.dev/metadata`; also
  tolerate a future `session/update` variant carrying `meteringUsage`). `_translate` stays a pure
  per-message mapper; the metering accumulation lives in the `prompt()` turn loop. Keep a per-turn
  running `meta` = the most recent metadata params: update `context_pct` from
  `contextUsagePercentage`; when `meteringUsage` is present, sum entries with `unit == "credit"`
  into `credits` and capture `turnDurationMs`.
- `client.py::prompt`: attach `usage` to the terminal `ResultMessage`:
  `{ "credits": <sum or None>, "context_pct": <last>, "turn_duration_ms": <last>,
  "provenance": "metered" if credits is not None else "unavailable" }`. Reset the running `meta`
  at the start of each turn so persistent (chat) sessions report per-turn values (verified per-turn
  in §2.3).
- `collect_streaming`: copy `ResultMessage.usage` → `TurnResult.usage`.
- **Graceful degradation:** if `_kiro.dev/metadata`/`meteringUsage` never arrives (older kiro-cli),
  `credits = None`, `provenance = "unavailable"` — downstream shows "n/a", never a fake number.
- Tests: feed fixtures mirroring the spike's real `_kiro.dev/metadata` shape — (a) metering present
  (assert `usage.credits == 0.1844`, provenance metered), (b) metadata absent (usage.credits None,
  unavailable), (c) multiple metadata notifications (last credit value wins, context_pct updates).
  No live Kiro needed (fixtures capture the verified shape).

### 11-02 — Core telemetry (`genesis-core`, additive → v0.8.0)
No pricing engine — just carry the metered value.
- `nodes/agent.py`: read `u = getattr(turn, "usage", None) or {}`; set
  `telemetry[name]["credits"] = u.get("credits")`,
  `telemetry[name]["credit_provenance"] = u.get("provenance", "unavailable")`,
  `telemetry[name]["context_pct"] = u.get("context_pct")`; **add `credits` to the `_run` aggregate**
  (currently absent). Emit `credits`/`context_pct`/`turn_duration_ms`/`provenance` on the
  **`agent.result`** event. (The existing `"credits": None` line becomes the metered value.)
- `state.py::_telemetry_merge`: `credits` is already summed when non-None (verified in source);
  add `context_pct` as last-writer. No reducer change needed for credits — confirm with a test.
- No `PlatformContext`/pricing.json/settings changes (dropped from the earlier draft).
- Tests: `agent.py` telemetry credits + `_run` aggregate via a stubbed `collect` returning a
  `TurnResult` with/without `usage` (extend the existing `set_collect_impl` stubs); reducer sum test.

### 11-03 — Persistence, aggregation & run API (`genesis`)
- `runs/eventlog.py`: add `aggregate_credits(run_ids) -> {run_id: float}` using
  `SUM(json_extract(payload,'$.credits'))` over `kind='agent.result'` (single indexed GROUP BY,
  mirrors `aggregate_tool_calls`); a per-run `run_credits(run_id)`; and a
  `credits_provenance(run_id)` (metered if all metered, else `partial`).
- `runs/steps.py::fold_steps`: on `agent.result`, add `credits` (+ `context_pct`) to the per-node
  summary (defaults `None`/0); feeds the Run-Detail strip + per-node display.
- `api` (runs): `/runs/{id}/steps` includes per-node credits (automatic via fold). **Run-total
  credits needs no new API field** — the run-detail page already fetches `/steps` (`useRunSteps`)
  and folds it in `TelemetryStrip`, so the run total is a client-side `sum(step.credits)`. (Verified:
  `manager.steps()` returns `fold_steps(...)` verbatim.) A run-total field on the run composite is
  therefore optional; skip it to avoid a redundant endpoint change.
- Tests: `aggregate_credits` (with `json_extract`); `fold_steps` credits; run-detail summary in
  `test_api.py`.

### 11-04 — Chat usage (`genesis`)
- `db/migrations/m0003_chat_usage.py`: `ALTER TABLE chat_messages ADD COLUMN usage TEXT` (JSON,
  nullable; forward-only; register in `db/migrations/__init__.py`). Update the synthetic/contiguity
  migration tests (as done for m0002).
- `chat/store.py`: `ChatMessageRecord.usage`; `append(..., usage=None)` persists it; `_from_row`
  decodes; `session_usage_total(session_id)` sum helper.
- `chat/manager.py::stream_turn`: read `usage = getattr(result, "usage", None)`; include
  `credits`/`context_pct`/`provenance` in the terminal **`agent.result`** chat event **and** pass
  `usage=usage` to `msgs.append(... "assistant" ...)`. (Chat runs in-process — a direct read of the
  `ResultMessage.usage` the SDK now attaches.)
- `api/chat.py`: `_message_dict` includes `usage`; `get_session` returns a `usage_total`.
- Tests: `test_chat_manager.py` — per-turn credits on the terminal event + persisted on the row
  (fake client yields a `ResultMessage` with `usage`); m0003 migration test.

### 11-05 — Web display
- `shared/ui/format.tsx`: `formatCredits(n: number | null)` → e.g. `"1.85"` / `"n/a"`; add a
  `Coins` icon to `icons.ts` (lucide) and a small `CreditBadge` (value + a tooltip
  "Credits metered by Kiro for this turn/run"; shows "n/a" when unavailable).
- **Overview (S6):** `types/home.ts` `HomeMetrics` — add `total_credits: number | null` +
  `credits_provenance`. In `OverviewPage.tsx` `MetricsGrid`, **replace** the `Tool Calls`
  `MetricCard` (`icon={Zap} label="Tool Calls" value={String(metrics.tool_calls)}`) with
  `icon={Coins} label="Credits Used" value={formatCredits(metrics.total_credits)}` and a `sub` such
  as `"across all runs"` (or `"partial data"` when provenance is `partial`). `home.py`: compute
  `total_credits` via `eventlog.aggregate_credits(all_run_ids)`; drop the always-null `tokens` in
  favor of `total_credits` (keep `tool_calls` field for other uses; it just leaves the KPI grid).
- **Run Detail (S7/S8):** `hooks.ts` `StepSummary` — add `credits: number | null`, `context_pct`.
  `Timeline.tsx` `TelemetryStrip` — add a **Credits** stat to BOTH variants (grid → `md:grid-cols-5`
  keeping Tool-Calls and adding Credits; the stacked list gains a row). Show per-node credits on
  each node in the `Timeline`/`Inspector`. Show **run-total credits** next to the status pill in
  `RunDetailPage.tsx` header, computed as `sum(steps[].credits)` (steps already fetched).
- **Chat (S9):** `types/chat.ts` — `ChatMessage.usage?: {credits: number|null, context_pct?: number,
  provenance: string}`; `ChatEvent` — add `credits`/`context_pct`/`provenance`. `ChatThread.tsx`
  `AssistantBlock` — render a subtle footer under the assistant answer: `1.85 credits` (via
  `CreditBadge`). Live turn: read the terminal `agent.result` event's credits and show the footer
  once the turn closes. Session header/list: per-session total from `usage_total`.
- Tests (Vitest): overview KPI renders credits (update `overview.test.tsx` + fixtures);
  `TelemetryStrip` credits; chat per-message footer; update golden fixtures (`test/fixtures/data.ts`,
  `events.ts`) + `contract.test.ts` for the new `agent.result` fields.
- Build: `npm run build` + commit `web/static/` (stale-bundle guard).

### 11-06 — (Optional) Runs-list credits column + Usage rollup
Low-cost adds for "clear usage across the app": a `credits` column in the Runs list (from
`aggregate_credits` over the listed runs) and an optional small "usage this period" line on
Overview. Ship only if cheap; not required for the four core asks.

---

## 7. API contract changes (additive)

- `GET /api/home` → `metrics.total_credits: number|null`, `metrics.credits_provenance: string`
  (Tool-Calls leaves the KPI grid but the `tool_calls` field remains).
- `GET /api/runs/{id}/steps` → each step gains `credits`, `context_pct` (run-total = client-side
  sum of these; no new run-composite field needed).
- `GET /api/chat/sessions/{id}` → each message gains `usage`; session gains `usage_total`.
- SSE `agent.result` (runs **and** chat) → gains `credits`, `context_pct`, `turn_duration_ms`,
  `provenance`.

All additive → no breaking changes; older clients ignore new fields.

## 8. DB migrations
- **m0003_chat_usage** — `chat_messages.usage TEXT` (JSON, nullable). Forward-only; registered in
  `db/migrations/__init__.py`; update the contiguity/synthetic-migration tests (as done for m0002).
- **Runs:** no migration — run credits derive from `run_events` payloads via `json_extract`.

## 9. Testing strategy (per §8 of the onboarding loop)
- **kiro-agent-sdk:** `_kiro.dev/metadata` capture fixtures (the verified spike shape) — metering
  present / absent / multiple notifications; `TurnResult.usage` propagation.
- **genesis-core:** `agent.py` telemetry credits + `_run` aggregate via stubbed `collect` returning
  usage-bearing / usage-absent `TurnResult`s; `_telemetry_merge` credit-sum test.
- **genesis:** `eventlog.aggregate_credits` (json_extract); `fold_steps` credits; `home.build_home`
  credits KPI + provenance; chat per-turn credits + persistence; m0003 migration.
- **web:** overview credits KPI; TelemetryStrip credits; chat per-message footer; golden fixtures +
  contract drift test updated; jest-axe on any new interactive bit.
- **Live (manual, already partially done via the spike):** the spike proved Kiro emits metered
  credits (0.18 / 0.11 per turn). A full live check: run `erd-generation` + a Chat turn, confirm
  per-node/per-run/per-message credits populate with `provenance="metered"`. Documented in the
  progress doc.

## 10. Versioning & release
Release order **sdk → core → genesis** so tags exist for the pins:
1. `kiro-agent-sdk` **v0.4.0** (`_kiro.dev/metadata` usage capture) — bump + tag + push.
2. `genesis-core` **v0.8.0** (telemetry credits + `_run` aggregate) — pin kiro-agent-sdk@v0.4.0;
   `CORE_MAJOR` stays **1** (additive-only, ADR-019). Tag + push.
3. `genesis` **v0.20.0** (persistence + API + chat + web + m0003) — pin genesis-core@v0.8.0 +
   kiro-agent-sdk@v0.4.0; run all gates; `npm run build` + commit `web/static/`; bump
   `pyproject.toml` + `api/app.py` FastAPI `version`; tag + push; verify CI (frontend job +
   stale-bundle guard). `genesis-workflows` unaffected. Update `tracker.md` §6 + a
   `progress/phase-11-credit-usage-tracking.md`.

## 11. Proposed ADR — ADR-032: Metered credit accounting from Kiro ACP
> Genesis surfaces **real, metered per-turn credit usage** captured from Kiro's ACP
> `_kiro.dev/metadata` notification (`meteringUsage[].value`, `unit: "credit"`), verified by live
> spike against kiro-cli 2.12.1 (per-turn, not cumulative: 0.184 then 0.113 credits in one session).
> There is **no estimation/pricing engine** — the SDK captures the metered value into
> `ResultMessage.usage`/`TurnResult.usage`, core writes it to telemetry + the `agent.result` event,
> and runs/chat aggregate it. Every figure carries a `provenance` (`metered`, or `unavailable`/
> `partial` when an older kiro-cli omits metering) so the UI shows real numbers and honest "n/a"
> gaps — never a fabricated value. Persistence stays SQLite (ADR-030): run credits derive from
> `run_events` via `json_extract`; chat adds one additive `usage` column (m0003).

## 12. Risks & open questions
- **R1 — metering shape could change across kiro-cli versions.** The capture is tolerant (matches
  `_kiro.dev/metadata` + sums `unit=="credit"` entries) and degrades to `unavailable` rather than
  crashing. Mitigation: pin the observed shape in an SDK fixture test; revisit on kiro-cli upgrades.
- **R2 — a turn with no metering (older kiro / error).** `credits=None`, provenance `unavailable`;
  aggregates mark `partial`. Honest, non-blocking.
- **R3 — retries double-count?** Each reliability-trio retry is a real billed turn and SHOULD count;
  `_telemetry_merge` sums across attempts (correct). Verify `_run` aggregate accumulates once per
  emitted turn (separate accumulator, as today) — covered by a test.
- **R4 — `json_extract` availability.** Requires SQLite JSON1 (bundled in Python 3.13 sqlite3 —
  verify at runtime; fallback: Python-side sum over `agent.result` payloads).
- **R5 — fractional credits.** Values are small floats (0.18); store raw float, round only at
  display; sum before rounding to avoid drift.
- **Q1 — Overview: replace or add?** Request says *replace* Tool-Calls on Overview → replace on the
  KPI grid; keep Tool-Calls in the Run-Detail strip and ADD Credits alongside.
- **Q2 — tokens?** Kiro exposes `contextUsagePercentage`, not raw token counts. We surface credits
  (the real cost signal) + optionally context% ; we do **not** claim token counts we don't have.

## 13. Out of scope (future)
- A usage **trend chart / cost-over-time** dashboard and per-workflow cost breakdown.
- Budgets / alerts / hard caps on spend.
- Surfacing raw token counts (Kiro gives context% + credits, not token counts).

## 14. Acceptance criteria
1. Each agent node/turn records the **metered** `credits` + `provenance` in telemetry and on its
   `agent.result` event; the `_run` aggregate includes total run credits.
2. Run Detail shows **per-node credits** and a **run-total** credit figure (with an honest "n/a"
   when a turn lacked metering).
3. Overview's KPI grid shows **Credits Used** (real, summed across runs) in place of Tool Calls.
4. Chat shows **per-message credits** under each assistant answer, and a per-session total.
5. Every figure carries provenance; unavailable data shows "n/a", never a fabricated number.
6. All gates green (pytest/ruff/vitest/tsc/lint/build); `web/static` committed; releases tagged and
   CI green; tracker + progress doc updated.
