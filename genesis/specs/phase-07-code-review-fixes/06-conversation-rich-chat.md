# 06 — P1: Conversation Tab — Rich Agent Chat

**Priority:** P1 (high-visibility UX) · **Layer:** `web` only · **Depends on:** 07-08
(Conversation exists), 07-09 (document renderers exist). **No backend/data-model change.**

> Goal: upgrade the Run-Detail **Conversation** tab to the polished agent-chat UX studied in the
> `ai-sre` reference — a unified, auto-expanding/collapsing **Thinking** timeline, **markdown**
> answers, and streaming affordances — **while keeping our stronger durable event-fold engine and
> reliability semantics.** This is a richer *renderer* over data we already have.

---

## 1. Reference study (`ai-sre`, verified) vs ours (verified)

**Reference** (`gitlab.appian-stratus.com/appian/prod/ai-sre`, `frontend/src/components/ChatMessage.tsx`,
`hooks/useChat.ts`, `types/index.ts`, `ws/chat-handler.ts`):
- Model: `Message { role, content, steps: StreamStep[], isStreaming }`; `StreamStep =
  {type:'reasoning'|'tool', content?, name?, status?}`. Events `text|reasoning|tool_start|tool_end`
  folded onto the message (`applyEvent`).
- Assistant render: (1) one **collapsible "Thinking" panel** (`StepsTimeline`) interleaving
  reasoning (italic) + tool calls (spinner → green dot) on a left-border rail; **auto-expands while
  streaming, auto-collapses on completion**; pulsing header dot while live. (2) **markdown** answer
  (`react-markdown`+`remark-gfm`) with fenced-code chrome (language label + copy) + inline-code
  chips + safe external links; a **typing cursor** + pre-first-token **loading dots**. (3) footer:
  timestamp • agent label • copy • regenerate.
- Transport/persistence: **WebSocket** (to dodge Teleport buffering) + **localStorage** per agent.

**Ours** (`web/src/features/run-detail/components/inspector/Conversation.tsx` + `../../conversation.ts`):
- Model: `TranscriptItem` union `message | thought | tool | result | note(validator|retry)`, built
  by a **pure fold** `buildTranscript(events)` over durable `agent.*` events — coalesces
  message/thought chunks; tool cards keyed by `tool_call_id`, updated in place by `agent.tool_update`.
- Render: `MessageBubble` (plain `whitespace-pre-wrap`, **no markdown**), `ThoughtBlock` (**each
  thought its own** separate collapsed block), `ToolCard` (collapsible result preview + status
  icon), `ResultChip` (turn complete/failed + duration + tool calls), `NoteRow` (validator/retry).
  Auto-scroll + jump-to-latest.
- Transport/persistence: **durable SQLite event log** + **SSE** replay/tail.

### 1.1 Verdict
**Our architecture is stronger; their presentation is nicer in three spots.** Keep ours; adopt
theirs:

| Aspect | Keep (ours) | Adopt (theirs) |
|--------|-------------|----------------|
| Persistence | ✅ durable SQLite event fold (survives restart, multi-run) | — (they use localStorage) |
| Transport | ✅ SSE over durable log (replayable) | — (they use WebSocket) |
| Domain semantics | ✅ validator/retry/turn-result | — (pure chat has none) |
| Purity/testability | ✅ pure `buildTranscript` fold | — |
| **Markdown answers** | — (plain text today) | ✅ rich markdown + code chrome |
| **Unified Thinking timeline** | — (scattered thoughts) | ✅ one auto-expand/collapse panel per turn |
| **Streaming affordances** | partial (jump-to-latest) | ✅ typing cursor + loading dots + live dot |

**Do NOT copy** their WebSocket transport or localStorage persistence — ours are superior for our
use case. This is purely a rendering upgrade.

---

## 2. Goals / Non-goals
**Goals**
1. Group the existing `TranscriptItem[]` into **turns**; render each turn as: a unified **Thinking**
   panel (reasoning + our richer tool cards) → the **markdown** answer → a footer (result/meta).
2. Thinking panel **auto-expands while its turn is live, auto-collapses when the turn's result
   arrives**; pulsing dot while active (mirrors their `StepsTimeline`).
3. **Markdown** answers via our existing 07-09 renderers; **typing cursor** on the streaming answer;
   **loading dots** before the first token.
4. Keep validator/retry notes + turn-result chips (our advantage), surfaced in the turn footer.

**Non-goals**
- No transport/persistence/event-model change (no WS, no localStorage).
- No "regenerate" chat button; the equivalent is our **fork/retry HITL** (07-08) — link to it, don't
  reinvent (see §5).
- No change to `buildTranscript`'s item semantics — turn-grouping is an additive layer.

---

## 3. Design

### 3.1 Turn grouping (pure, in `conversation.ts`)
Add a pure function over the existing items (keeps `buildTranscript` untouched):
```ts
export interface Turn {
  id: string;              // `turn-${startSeq}`
  thinking: TranscriptItem[];  // thought + tool items, in order
  answer: Extract<TranscriptItem,{kind:'message'}>[]; // coalesced message bubbles (usually 1)
  result?: Extract<TranscriptItem,{kind:'result'}>;   // the agent.result that closed the turn
  notes: Extract<TranscriptItem,{kind:'note'}>[];      // validator/retry attached to the turn
  live: boolean;           // true if this is the last turn and no result yet (streaming)
}
export function groupTurns(items: TranscriptItem[], live: boolean): Turn[];
```
Rule: iterate items in `seq` order; accumulate `thought`/`tool` into `thinking`, `message` into
`answer`, `note` into `notes`; a `result` **closes** the current turn (push, reset). A trailing open
group (no result) is the **live** turn when `live` is true. This is a deterministic, unit-testable
fold — the DoD test drives it with a scripted fixture (mirrors the "stub hid the contract" lesson).

### 3.2 Components (`components/inspector/`)
- **`TurnView.tsx`** — renders one `Turn`: `<ThinkingTimeline .../>` (if `thinking.length`), then
  the markdown answer(s), then `<TurnFooter/>` (result chip + validator/retry notes + copy).
- **`ThinkingTimeline.tsx`** — replaces the scattered `ThoughtBlock`s: one collapsible panel, a
  left-border vertical rail, entries = reasoning (italic, coalesced) + our existing **`ToolCard`**
  nested. `open` state = `live` (auto-expand while streaming); an effect collapses it when the turn
  gains a `result` (auto-collapse on completion); pulsing dot in the header while `live`. Manual
  toggle overrides. (Directly mirrors their `StepsTimeline` behavior.)
- **`AssistantAnswer.tsx`** — renders message text as **markdown** via the 07-09
  `MarkdownView`/`CodeBlock` renderers (`features/documents/renderers/`), with a **typing cursor**
  when its turn is `live`. Empty live answer with no thinking yet → **loading dots**.
- Reuse existing `ToolCard`, `ResultChip`, `NoteRow`, `CopyButton` (already in `Conversation.tsx`).

### 3.3 `Conversation.tsx` (rewire)
- Compute `turns = useMemo(() => groupTurns(items, live), [items, live])`.
- Render `turns.map(t => <TurnView key={t.id} turn={t} live={t.live} />)`.
- Keep the existing auto-scroll + jump-to-latest and the non-agent-node / empty states verbatim.
- Default collapse policy: finished turns' Thinking panels start **collapsed** (scannable history);
  the live turn's panel is **open**.

### 3.4 Reuse & deps
- **No new dependency.** `react-markdown` + `remark-gfm` + `shiki` are already in the stack
  (ADR-027) and wrapped by the 07-09 renderers — reuse them (don't re-add). This also keeps code-block
  styling consistent with the Documents tab.

---

## 4. Files touched (web only)

| File | Change |
|------|--------|
| `features/run-detail/conversation.ts` | add `Turn` + pure `groupTurns()` (buildTranscript unchanged) |
| `features/run-detail/components/inspector/Conversation.tsx` | render turns; keep scroll/empty states |
| `.../inspector/TurnView.tsx` | **new** |
| `.../inspector/ThinkingTimeline.tsx` | **new** (replaces inline `ThoughtBlock`) |
| `.../inspector/AssistantAnswer.tsx` | **new** (markdown + cursor/dots, reuses 07-09 renderers) |
| `features/run-detail/conversation.test.tsx` (or extend existing) | `groupTurns` unit tests + render tests |

---

## 5. "Regenerate" mapping
Their footer has a chat **regenerate**. Ours isn't a re-askable prompt — a node re-runs via the
**reliability trio** or an operator action. Map the affordance to the existing **HITL** controls
(07-08): on a completed/failed turn, offer "Re-run from here" → the existing **fork**/retry flow
(`hitl/ForkDialog`), not a new chat regenerate. Keeps one control surface for time-travel.

---

## 6. Testing / DoD
**Unit (`groupTurns`, pure):** a scripted `TranscriptItem[]` (thought, tool, tool_update, message
chunks, result, then a second turn with a retry note + validator) groups into the expected turns;
the trailing open turn is `live` when `live=true`; a validator/retry note attaches to its turn.
**Render (RTL):** a live turn shows an expanded Thinking panel + typing cursor; a finished turn shows
a collapsed panel + markdown answer (assert a fenced code block renders via the reused CodeBlock);
loading dots appear for a live turn with no answer yet. jest-axe on the panel (button `aria-expanded`).
**Regression:** existing Conversation tests (07-08) updated to the turn structure stay green.
**DoD:** `tsc`+`vitest`+`build` green; `web/static/` untouched; visual check on a real run (live
auto-expand → auto-collapse on completion; markdown/code render; cursor/dots while streaming).

---

## 7. Risks & deviations
- **Auto-collapse timing:** collapse triggers on the turn's `result` item, not a timer — robust to
  slow streams. Manual toggle always wins.
- **Markdown safety:** reuse the 07-09 renderer config (no raw HTML; external links `rel=noopener`),
  so no new XSS surface.
- **Deviation:** we intentionally diverge from the reference on transport/persistence/regenerate —
  documented above; the visual language is what we adopt.

## 8. Estimate
~0.5–1 day: `groupTurns` + tests (2h); TurnView/ThinkingTimeline/AssistantAnswer + markdown reuse
(3–4h); render tests + visual polish (2h). One frontend commit series.
