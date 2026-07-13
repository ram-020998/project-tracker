# 10-07 — ADR-031, system prompt, integration, release & docs

**Repos:** all · **Depends on:** 10-01…10-06 · **Blocks:** — (phase close)

## 1. Objective

Land the decision record, the chat persona/steering, the end-to-end wiring + live acceptance, the
release chain, and the tracker/progress docs.

## 2. ADR-031 — record it

Append **ADR-031 (Chat is a read-only conversational assistant)** to
`reference/decision-log.md`, using the text drafted in the umbrella spec §3. Cross-reference it from:
- `specs/00-architecture-overview.md` (a Chat surface paragraph),
- `reference/security-and-secrets.md` (the read-only enforcement + introspection redaction),
- the ADR-001 entry (a "see ADR-031: read-only assistant preserves this" note).

## 3. Chat system prompt / steering

Author the chat persona (a constant in `genesis/chat/` or a steering doc) — a *secondary*
reinforcement of the enforced boundary, not the control:

- Identity: "You are Genesis Chat, a **read-only** assistant for a Solutions engineer."
- Capabilities: answer general questions; use **Atlas** read tools for Appian docs/data; use the
  **genesis** introspection tools to report on runs/failures/progress/workflows/health.
- Hard rules: never claim to have changed anything; if asked to start/stop/fix/deploy/edit, explain
  that Chat is read-only and point to the relevant page (Runs / Catalog / Settings).
- Grounding: prefer tool results over guessing; cite run ids / workflow ids; keep bulk out of the
  reply (summarize; the user can open the run/artifact).

## 4. Integration + live acceptance (manual; cannot be driven headlessly)

Wire-up already lands in 10-05 (`create_app`). Do a real end-to-end pass with `genesis serve` +
real kiro-cli + configured Atlas, and record results in the progress doc:

1. **Doc Q&A:** ask an Appian-doc question → Atlas read tool runs → grounded answer.
2. **Genesis Q&A:** "What runs failed recently and why?" / "What's the progress of run `r-…`?" →
   introspection tools return the failure detail / step fold → correct answer.
3. **Read-only refusals:** "Cancel run `r-…`", "install workflow X", "write a file", "delete the
   Atlas server" → each is refused (no state change); verify via the Runs/Settings pages that nothing
   changed and no `session/request_permission` was auto-approved.
4. **Persistence:** create a session, chat, reload the page → transcript restored; restart `genesis
   serve` → session still listed, next message works (context-preamble replay); **delete** → gone.
5. **Cancel:** start a long turn, hit Stop → turn ends promptly.

## 5. Release chain

Order (so tags exist for pins):

1. **kiro-agent-sdk v0.3.0** — the permission policy (10-01). Tag + push; CI green.
2. **genesis-core v0.7.0** — bump the sdk pin to `v0.3.0` (no code change unless a re-export is
   desired). Tag + push; CI green. (`CORE_MAJOR` stays 1 — additive.)
3. **genesis v0.19.0** — add a **direct** git+ssh dep on `kiro-agent-sdk@v0.3.0` (genesis now uses
   `KiroACPClient`/`KiroAgentOptions` directly), bump the genesis-core pin to `v0.7.0`, ship the
   introspection server + m0002 + ChatManager + chat API + web bundle; FastAPI version `0.19.0`.
   Rebuild + commit `web/static`. Tag + push; CI green (python + frontend jobs, incl. the
   stale-bundle guard).

Verify each via `glab ci list -R ramaswamy.u/<repo>`. Commit as
`git -c user.name=Genesis -c user.email=genesis@local`.

## 6. Docs / tracker

- `progress/phase-10-chat-assistant.md` (new) — the as-built record: what shipped per sub-phase,
  commits/tags/pipeline ids, the spike findings (10-01), and the §4 live-acceptance results.
- `tracker.md` — flip Phase 10 in the §3 index to ✅/shipped with the version chain; add a §6
  status-log entry.
- `specs/phase-10-chat-assistant.md` + this dir — flip statuses to shipped; note any descoped item
  (e.g. idle reaper, title-LLM) into `specs/backlog/` if deferred.
- Push project-tracker (`git pull --rebase` then push).

## 7. DoD

All sub-phase DoDs met; ADR-031 recorded + cross-referenced; steering authored; the §4 manual
checklist passed and recorded; the three releases shipped with CI green; tracker/progress updated and
pushed. Then tell the user: restart `genesis serve` for the new bundle; Atlas must be configured for
doc Q&A; Chat is read-only by design.

## 8. Post-ship follow-ups (candidate backlog)

Idle-reaper tuning; LLM-generated titles; transcript summarization for very long sessions; opening
the MCP set beyond Atlas (needs the read/write classification story); chat export.
