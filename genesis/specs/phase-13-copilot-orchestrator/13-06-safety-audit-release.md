# Phase 13-06 — Safety, Audit, Advanced-Gate Patterns & Release

> **Status:** ✅ SHIPPED (Phase 13 complete — 13-01..06; see `progress/phase-13-copilot-orchestrator.md`) · **Repo:** genesis · **Depends on:** 13-01..13-05
> **Goal:** Harden the copilot for real use — an audit trail of agent-initiated actions, scope/rate limits,
> a kill-switch, the researched advanced-gate patterns (conditional/batch/timeout), then end-to-end + live
> acceptance, ADR-033 finalization, and the release.

---

## 1. Audit trail (accountability for a write-capable agent)

Every agent-initiated mutation is recorded (a small `copilot_actions` table or reuse `run_events` +
`chat_notification`): `{session_id, run_id?, tool, args_digest, proposed_at, confirmed_by_user (bool),
confirmed_at, outcome, error}`. Each row ties the **agent's proposal** to the **human confirmation** (the
permission decision) and the **result**. Surfaced read-only in Settings → (a new) "Copilot activity" or the
session detail. This is the ADR-033 auditability requirement and the answer to "what did the agent do on my
behalf?".

## 2. Scope & rate limits (blast-radius control)

- **Per-session concurrency cap** — max N concurrent linked runs a copilot session may start (config
  `copilot_max_active_runs`, default small); further `start_run` is refused with a clear message.
- **Rate limit** — max start_run/respond per minute (guards a runaway loop).
- **Workflow allow/deny** — optional config to restrict which workflows the copilot may launch (e.g. exclude
  destructive ones); enforced in the control server + surfaced in the palette.
- **Kill-switch** — a global `copilot_enabled` setting (Settings → General). Off ⇒ chat is read-only
  everywhere (mode toggle hidden, control tools not wired). Instant, reversible.

## 3. Advanced-gate patterns (from the research; opt-in)

- **Conditional confirmation** — low-risk gates (e.g. an approval on a dry-run) can be configured to a
  lighter confirm; high-risk (`pre_mutation` before a write/deploy node) always require the full confirm
  card with the mutation described. Never auto-approve `pre_mutation`.
- **Batch review** — if several linked runs await decisions, the supervised strip + a single "review N
  pending decisions" nudge consolidate them (the copilot walks them one by one, each individually confirmed).
- **Timeout handling** — the 13-04 SLA re-nudge; plus an optional "auto-cancel a run left awaiting > T" is
  **explicitly rejected** (the copilot never decides) — timeout only escalates attention.

## 4. Integration & live acceptance

- **E2E (stubbed Kiro)** — a copilot session: slash-launch a program-only test workflow with a gate →
  confirm card → run starts + links → supervisor nudges on the gate → user "approve" → confirm card →
  `respond_to_gate` → run resumes → terminal notification. Assert the audit rows + notifications.
- **Live acceptance (manual, real kiro-cli)** — the 13-01 spike must hold (untrusted control tools fire
  permission requests); then a real copilot session launches `erd-generation` (or `hello-appian`), the
  confirm card gates the start, the approve-domains gate is surfaced + answered from chat, and the run
  completes. Record run ids + a transcript in `progress/`.
- **Read-only regression** — Phase-10 read-only chat + all existing suites stay green.

## 5. ADR-033 finalized; docs

- Move ADR-033 from "drafted" (13-02) to accepted in `reference/decision-log.md`.
- Refresh `AGENT_ONBOARDING.md` (§2 state, §4 map — control server + supervisor + copilot mode, §5 add
  ADR-033, §7 a copilot lesson) and `tracker.md` §3/§6 + `progress/phase-13-copilot-orchestrator.md`.

## 6. Release chain (ADR-019)
`kiro-agent-sdk` (13-01) → `genesis` (13-02..13-06: control server, copilot mode, supervisor, api, web,
m0004/m0005; sdk pin bump). `genesis-core` unchanged. Rebuild + commit `web/static`; verify CI on each repo
via `glab`; frontend-only changes still ship a genesis release.

## 7. Files & tests
- `genesis/chat/audit.py` (or store extension) + Settings fields (`copilot_enabled`, `copilot_max_active_runs`,
  `copilot_gate_sla_minutes`, rate limits, workflow allow/deny).
- `genesis/mcp/control_server.py` — enforce concurrency/rate/allow-deny before proxying.
- `tests/test_copilot_safety.py` — concurrency cap refuses; rate limit; kill-switch removes control tools;
  audit row per confirmed action; `pre_mutation` always full-confirm.
- `web` — Copilot-activity view; kill-switch toggle; batch-review strip.

## 8. Acceptance criteria
1. Every confirmed mutation has an audit row linking proposal → confirmation → outcome.
2. Kill-switch off ⇒ chat is fully read-only (control tools gone); concurrency/rate/allow-deny enforced.
3. `pre_mutation` gates are never auto-approved; timeouts only re-nudge.
4. E2E + live acceptance recorded; all suites + CI green; ADR-033 accepted; docs refreshed.

## 9. Out of scope
- Autonomous (no-confirmation) operation — permanently out of scope for the copilot (ADR-033).
