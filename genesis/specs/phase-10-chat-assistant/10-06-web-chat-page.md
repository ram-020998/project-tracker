# 10-06 — Web Chat page

**Repo:** `genesis/web` · **Ships with:** genesis v0.19.0 · **Depends on:** 10-05 · **Blocks:** 10-07

## 1. Objective

A Chat page in the SPA: session list (new/select/rename/delete), a streaming transcript that reuses
the existing conversation renderer, a composer, and a clear read-only affordance. Follows ADR-026/
027/028 (React+TS, design tokens + existing primitives, `/api` via the central client).

## 2. Current state (verified)

- API client: `src/lib/api/client.ts` prepends `/api`, throws `ApiError`, rejects non-JSON. Resource
  modules per domain (`runs.ts`, `config.ts`, …) + `src/lib/query` keys (`qk.*`). `EventSource` is
  used in `features/run-detail/hooks.ts` `useRunStream` with **named per-kind listeners** + seq
  dedupe + close on `run.final`. **But** chat POSTs a prompt → `EventSource` can't POST, so chat uses
  `fetch` + a `ReadableStream` reader that parses `event:`/`data:` frames (new small util).
- Transcript renderer (**reuse as-is**): `features/run-detail/conversation.ts`
  `buildTranscript(events)` + `groupTurns(items, live)`; components
  `components/inspector/{Conversation,TurnView,ThinkingTimeline,AssistantAnswer}.tsx`. They consume
  the canonical `agent.*` event shape — identical to what chat streams. Extract/share the renderer so
  both features import it (move to `shared/conversation/` or import from run-detail; prefer a small
  move to `src/shared/conversation/` to avoid a feature→feature import).
- Layout/primitives: `shared/layout/{AppShell,Sidebar,SplitPane,Page}`; `shared/ui/*`
  (Button, Input/Textarea/Field, Card, Dialog, Chip, icons barrel `shared/ui/icons.ts`);
  `shared/feedback/{Empty,Error,Loading}`. Settings `ConfirmDialog`
  (`features/settings/components/manager/ConfirmDialog`) for delete confirmation.
- Router: `src/app/router.tsx` (routes) + `RootLayout`/`AppShell`; `Sidebar` nav list (edited this
  session — has the collapse control). Add a `Chat` entry + icon (e.g. `MessagesSquare`).

## 3. Design

### 3.1 Routing + nav

- Routes: `/chat` (empty state / most-recent) and `/chat/:sessionId`.
- Sidebar: a `Chat` nav item (icon + label), placed near the top (below Overview).

### 3.2 API module + query keys

`src/lib/api/chat.ts`:

```ts
export const chatApi = {
  listSessions, createSession(title?), getSession(id), renameSession(id,title), deleteSession(id),
  // streaming turn: POST + SSE-over-fetch reader
  sendMessage(id, text, onEvent: (ev: ChatEvent)=>void, signal?: AbortSignal): Promise<void>,
  cancel(id),
};
```

`sendMessage` POSTs to `/api/chat/sessions/{id}/messages`, then reads `res.body!.getReader()`,
decodes chunks, splits on `\n\n`, parses `event:`/`data:` lines, and calls `onEvent(JSON.parse(data))`
until the stream ends (server closes on `agent.result`/`error`). `qk.chat.sessions()`,
`qk.chat.session(id)` added to `lib/query`.

### 3.3 State + streaming

- `useSessions()` (TanStack Query: list), `useSession(id)` (session + messages).
- `useChatTurn(id)`: a mutation that appends the user bubble optimistically, then calls
  `chatApi.sendMessage` and reconciles streamed `agent.*` events into a local "live turn" buffer
  (dedupe by `seq`); on `agent.result` it invalidates `qk.chat.session(id)` (to pull the persisted
  transcript) and clears the live buffer. Mirror `useRunStream`'s dedupe + terminal-close discipline
  (the "close on terminal or it re-streams forever" lesson).

### 3.4 Components

- `ChatPage` — `SplitPane` (or fixed left rail): left = `SessionList`; right = `ChatThread`.
- `SessionList` — "New chat" button (creates → navigates), list ordered by recency (title +
  relative time), per-row overflow menu → Rename (inline `Input`) / Delete (`ConfirmDialog`).
- `ChatThread` — the transcript: fold persisted `messages` (each assistant message's `events` +
  `content`) **plus** the current live turn through `buildTranscript`/`groupTurns`, render with
  `TurnView` (thoughts collapsible, tool cards, markdown answer via the existing markdown renderer).
  User bubbles render plainly. A small **read-only** banner/badge ("Read-only assistant — I can look
  things up but can't make changes"). Auto-scroll on new content.
- `Composer` — `Textarea` (Enter=send, Shift+Enter=newline), disabled while a turn is live, a Stop
  button (calls `cancel`) while streaming, char counter near `chat_max_prompt_chars`.
- Empty state (`shared/feedback/Empty`) when no session selected.

### 3.5 Reuse note

Prefer moving the transcript fold + turn components to `src/shared/conversation/` and updating
run-detail imports (small, mechanical) so chat and run-detail share one renderer and one contract
fixture. If that move is risky mid-phase, chat may import from `features/run-detail` as an interim
(flag it).

## 4. Files to touch

- `src/lib/api/chat.ts` (new), `src/lib/api/index.ts` (export), `src/lib/query/*` (chat keys).
- `src/types/chat.ts` (new) — `ChatSession`, `ChatMessage`, `ChatEvent` (mirror the backend shapes;
  add to the golden fixtures for a contract test).
- `src/features/chat/**` (new) — `ChatPage`, `SessionList`, `ChatThread`, `Composer`, `hooks.ts`.
- `src/shared/conversation/**` (moved from run-detail) — the shared fold + turn components; update
  run-detail imports.
- `src/app/router.tsx` + `src/shared/layout/Sidebar.tsx` — route + nav entry.
- Tests: `src/features/chat/chat.test.tsx` + fixtures.
- Rebuild: `npm run build` → commit `web/static` (stale-bundle guard).

## 5. Tests / DoD (Vitest + RTL + jest-axe)

- Transcript renders from a scripted `agent.*` fixture through the shared fold (a `ChatEvent`
  contract fixture guards the shape — the "stub hid the contract" lesson).
- Session list: renders, select navigates, "New chat" creates, Delete opens `ConfirmDialog` and calls
  the API, Rename updates.
- Composer disabled while a turn is live; Stop calls `cancel`; oversized input blocked client-side.
- The SSE-over-fetch reader parses multi-frame chunks correctly (unit test with a mocked
  `ReadableStream`).
- jest-axe on the page has no violations; `lint` + `typecheck` + `vitest` green; `web/static` rebuilt
  + committed.

## 6. Risks

- `EventSource` can't POST → the fetch-reader path is mandatory; MSW/jsdom lack streaming bodies, so
  unit-test the reader with a hand-rolled `ReadableStream` and test components with an injected
  `onEvent` driver rather than a real network stream.
- Moving the conversation renderer touches run-detail — keep it mechanical and re-run the run-detail
  tests to prove no regression.
