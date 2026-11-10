# 53-10 — Web experience

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (`web/`). Parent: `specs/phase-53-kiro-sdk-v3.md`.
> Decisions: 53-01 D7, D10; F3, F5, F6. Contract: 53-09.

## 1. Goal

The small set of visible changes the v3 move brings; everything else in chat and run detail looks and behaves as today
(the API shapes are kept, 53-09).

## 2. Changes

| # | Where | Change |
|---|---|---|
| W1 | `features/chat/Composer.tsx`, `hooks.ts` (`useChatTurn`) | **Steering (D10).** Today the composer shows Stop *instead of* Send while `streaming` (`Composer.tsx:313-322`) and disables the textarea (`:303`), the model select (`:180`) and attach (`:309`); the submit guard is at `:121`. New: while `streaming`, the textarea stays enabled and **Send and Stop are both shown**. Send calls `chatApi.steer` (new, `lib/api/chat.ts`) and Enter does the same. The model select and attach stay disabled during a turn, so a steer is text only (F16, 53-01 §9.5; the steering method takes text only, 53-02 W7). |
| W2 | `features/chat/ChatThread.tsx` | A steered message renders as a user bubble with a small "sent during the turn" label (from `user.steer` live, `meta.kind = "steer"` after reload). On `agent.result.unread_steers`, the client sends those texts as the next message, in order, automatically (no user action), and the label changes to "sent after the turn". |
| W3 | `hooks.ts` `stop` | Unchanged call (`/cancel`); the next turn is fast (no cold start). No UI change beyond that. |
| W4 | `ChatThread.tsx` (`AssistantBlock`, `LiveAssistant`), `features/run-detail/components/Inspector.tsx`, `conversation.ts` | **Model fallback (F6):** when `usage.fallback_from` / `agent.result.fallback_from` is set, show "answered by <model>" next to the credit badge (muted text, a tooltip "the requested model <x> was unavailable"). |
| W5 | `ChatThread.tsx` | **MCP notice (F3):** a `session.notice` `mcp_failed` renders an inline warning card on the turn: "<server> did not start: <detail>. Its tools are not available in this chat." using the existing feedback primitives (`shared/feedback`), not a new component. |
| W6 | `features/catalog/skills/SkillCard.tsx`, `hooks.ts` | **Update button (D7):** on an installed library skill, an "Update" action calling `POST /api/skills/update` (`useUpdateSkill`); toast on success/failure; the list refreshes. Remove the "Shadows a same-named skill in your personal ~/.kiro/skills" line (`SkillCard.tsx:61-65`) and the `shadowsPersonal` field. |
| W7 | Settings → General Kiro card (`features/settings/components/KiroSection.tsx`); first-run preflight checklist (`features/system/PreflightChecklist.tsx`) | Show the kiro-cli version and the `kiro-cli` / `kiro-cli-verified` items (53-08) with their remedies. |
| W8 | `types/chat.ts`, `types/skill.ts` (`:15-16` loses `shadows_personal`), `types/` for system | `ChatEvent` gains `user.steer`, `session.notice`, `unread_steers`, `model`, `fallback_from`; `ChatMessage.usage` gains `model?`, `fallback_from?`; skill type loses `shadows_personal`; Kiro status gains `version, minimum, verified, engine_v3`. |

Stack rules: existing tokens and primitives only (ADR-027/055); never `<Button asChild>` (L-069); no new heavy
dependency (L-015); `/api` prefix only through the central client (ADR-028).

## 3. Tests

Vitest + jest-axe (L-014): composer sends a steer while streaming, with Send and Stop both visible and the model select
and attach disabled; the steered bubble label; unread steers re-sent in
order after `agent.result`; "answered by" on chat and run detail; the MCP notice card; Skills Update calls the endpoint
and refreshes; no `shadowsPersonal` text; preflight items render. `npm run lint && npm run typecheck && npm test`, then
`npm run build` and commit `web/static/` as separate steps (L-089, L-030).

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["chat", "web-runs", "web-shell", "features-stages"]
adrs     = ["ADR-027", "ADR-028", "ADR-031", "ADR-032", "ADR-055"]
lessons  = ["L-007", "L-011", "L-014", "L-015", "L-030", "L-069", "L-089", "L-090"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-09-api.md"]
code     = ["genesis/web/src/features/chat/**", "genesis/web/src/features/run-detail/**", "genesis/web/src/features/catalog/skills/**", "genesis/web/src/features/settings/**", "genesis/web/src/features/system/**", "genesis/web/src/lib/api/chat.ts", "genesis/web/src/types/**", "genesis/web/src/test/fixtures/**"]
upstream = ["53-09"]
```
