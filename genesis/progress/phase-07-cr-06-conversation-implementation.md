# Progress: P1 06 — Conversation Tab: Rich Agent Chat

**Spec:** `specs/phase-07-code-review-fixes/06-conversation-rich-chat.md`
**Delivered in:** genesis v0.15.0 (commit `61418bb`, tag `v0.15.0`)
**CI:** pipelines #6331854 (master) + #6331855 (tag) — both SUCCESS
**Date:** 2026-07-13 · **Layer:** `web` only

---

## Summary

Upgraded the Run-Detail **Conversation** tab to the polished agent-chat UX from the
`ai-sre` reference — a unified auto-expand/collapse **Thinking** timeline, **markdown**
answers, and streaming affordances — **while keeping our stronger durable event-fold
engine + reliability semantics.** This is a pure *rendering* upgrade: no transport,
persistence, or event-model change (still SSE over the durable log; no WebSocket, no
localStorage). "Regenerate" maps to the existing fork/retry HITL, not a new chat control.

---

## Deliverables (all `web/src/features/run-detail`)

### 1. Pure turn grouping — `conversation.ts`
Added `Turn` + **`groupTurns(items, live)`** as an additive layer; `buildTranscript` is
untouched. Rule: iterate items by `seq`; `thought`/`tool` → `thinking`, `message` →
`answer`, `note` → `notes`; an `agent.result` **closes** the turn. **Validator/retry
notes that arrive after a result stay attached to that just-closed turn** — a new turn
only opens on the next thought/tool/message, so a retry attempt's fail-notes belong to
the attempt they describe. The trailing open turn (no result) is marked `live` when
`live` is true.

### 2. Components (`components/inspector/`)
| File | Role |
|------|------|
| `conversationParts.tsx` | **new** — extracted `ToolCard`/`ResultChip`/`NoteRow`/`CopyButton`/`ToolStatusIcon` so the turn components reuse them without a circular import |
| `ThinkingTimeline.tsx` | **new** — one collapsible left-rail panel (replaces scattered `ThoughtBlock`s): coalesced reasoning (italic) + nested reused `ToolCard`s. **Auto-expands while `live`, auto-collapses when the turn gains a result** (effect follows the `live` signal); pulsing dot while live; manual toggle overrides; `aria-expanded` on the header button |
| `AssistantAnswer.tsx` | **new** — renders answer text as **markdown** via the reused 07-09 `MarkdownView` (react-markdown + remark-gfm + fenced-code chrome + safe external links — **no new dependency**); **typing cursor** while live + pre-first-token **loading dots** |
| `TurnView.tsx` | **new** — composes Thinking → markdown answer → footer (result chip + validator/retry notes) |
| `Conversation.tsx` | rewired: `useMemo(() => groupTurns(items, live))` → `turns.map(TurnView)`; auto-scroll / jump-to-latest / empty + non-agent states kept verbatim; finished turns' Thinking panels start collapsed, the live turn's is open |

---

## Tests (`run-detail-hitl.test.tsx`)

- **`groupTurns` unit:** single-attempt fixture → one turn with `thinking=[thought,tool]`,
  1 answer, `notes=[validator,retry]`, `result.ok`; two-turn split across a result where
  the retry note attaches to the just-closed first turn and the trailing open turn is `live`.
- **Render (RTL):** finished turn → Thinking collapsed (thought + tool hidden) then expand
  reveals both; footer chips/notes + markdown answer visible without expanding. Live turn →
  Thinking auto-expanded with `aria-expanded="true"`.
- **Regression:** the existing `buildTranscript` tests + the contract-fixture drift test +
  the HITL-bar tests stay green (the fold contract is unchanged).

---

## Evidence

```
$ npm run typecheck  → clean
$ npm run lint       → 0 errors, 9 warnings (pre-existing react-refresh)
$ npm test           → 9 files, 64 tests passed (+4)
$ npm run build      → ✓ built; web/static/ rebuilt + committed

# backend unaffected (only the app version string changed)
$ pytest -q          → 83 passed     $ ruff check genesis → clean

# CI
Pipeline #6331854 (master): SUCCESS   Pipeline #6331855 (v0.15.0): SUCCESS
```

---

## Decisions / Deviations

- **Note attachment on retries:** the spec left "which turn owns a note" implicit; I
  attached validator/retry notes that follow a result to the *just-closed* turn (matching
  reliability-trio semantics), rather than orphaning them into a new turn. Covered by a
  dedicated unit test.
- **Extracted `conversationParts.tsx`** rather than re-exporting primitives from
  `Conversation.tsx` — avoids a `Conversation → TurnView → Conversation` import cycle.
- **`copy()` kept file-local** (not exported) so `conversationParts.tsx` exports only
  components (no extra react-refresh lint warning).
- **Build rule:** followed the post-07-10-cutover rule (rebuild + **commit** `web/static/`);
  the spec's "static untouched" DoD line predates the cutover, per the onboarding note.

## What's NOT verified (honest disclosure)

- **Live browser QA:** not performed headlessly. The turn fold + auto-expand/collapse +
  markdown/cursor/dots are covered by vitest + jsdom, but a manual `genesis serve` on a
  real run would confirm the live streaming visuals (auto-expand → auto-collapse on
  completion; typing cursor; code-fence rendering parity with the Documents tab).

---

## Next

**The Code-Review Fix Program is complete** (01–06). Remaining backlog (onboarding §8):
full ERD dry-run parity check; rotate the shared `GITLAB_PUSH_TOKEN` + refresh the
Artifactory npm token; the `lcp` MCP image placeholder — then **Phase 8 (skill
migration)**, not to be started unless asked.
