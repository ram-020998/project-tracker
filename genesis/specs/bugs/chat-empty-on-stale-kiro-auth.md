# Bug — Chat silently returns empty replies when the server's Kiro session goes stale

> **Status:** 🐞 OPEN (workaround: restart `genesis serve`). · **Filed:** 2026-08-18 · **Severity:** medium (confusing, not data-losing) · **Area:** `genesis/chat/` (ChatManager / ACP turn) + Phase-22 `runtime/kiro_auth.py`

## Symptom
Chat turns return a **blank assistant message** with no error. The turn "succeeds" (HTTP 200) but the stored assistant
message has `content: ""`, `usage.provenance: "unavailable"`, `credits: null`, `turn_duration_ms ≈ 1000`, and `events: []`.
The user just sees empty replies and assumes "chat is broken." Re-sending the same prompt reproduces the empty reply.
(Observed on session `c-b1a97f7daea8`, 2026-08-18.)

## Root cause
The **long-running `genesis serve` process's kiro-cli auth/ACP session had gone stale** (Kiro SSO tokens expire after a few
hours). kiro-cli then **aborts the ACP turn without invoking the LLM** — hence the ~1s duration, no metering
(`provenance: unavailable`), and no `agent.message`. It is **not** session-specific and **not** a code bug.

## Evidence
- kiro-cli was authenticated per `kiro_auth.status()` (email present) — but that ran in an interactive shell with a fresh token.
- A **fresh out-of-process `ChatManager`** ran a real, metered turn fine (`agent.message "Hello!"`, `provenance: metered`).
- On the **running server**, **every** session returned empty — a brand-new session AND the reloaded poisoned session.
- **Restarting `genesis serve` fixed it** (verified: `assistant: 'Hello!' | provenance: metered`). → the long-running process's
  Kiro session was the culprit; a fresh process re-establishes a valid session.

## Workaround
Restart the server (`genesis down && genesis up`) or re-run the in-app Kiro sign-in (Settings → Kiro) to re-establish the
session. Recurs whenever the server's Kiro session expires (long uptime).

## Proposed fix
Detect the aborted-turn signature and surface it instead of storing a blank reply:
- In `ChatManager.stream_turn`, when a turn ends with **empty content + `provenance == "unavailable"` + 0 tool calls + no
  `agent.message`**, treat it as an **engine/auth failure**: emit a clear error event + assistant note like *"Kiro session
  expired — re-authenticate in Settings → Kiro"* (reuse Phase-22 `kiro_auth.status()` to confirm), and **do not persist an
  empty assistant message** (or persist it flagged as an error).
- Optionally **auto-close/reload the session's live ACP client** on this signature so the next turn re-establishes a fresh
  kiro-cli connection (there's already a `/reload` endpoint).
- Consider a lightweight **periodic Kiro-auth health check** (or check on turn start) that warns proactively when the session
  is about to expire.

## Notes
- Relates to Phase-22 `runtime/kiro_auth.py` (status) + the preflight checklist; and ADR-031/033 (chat engine).
- Distinct from the v0.46.1 slash-command hang (that was `execute_command` timing out; this is a stale-auth empty turn).
