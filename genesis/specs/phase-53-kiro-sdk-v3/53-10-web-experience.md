# 53-10 — Web experience

> **Status:** BUILT 2026-11-14 (genesis b9ba5d9; review SHIP, round 2). SPEC-DRAFTED 2026-11-03. Repo: **genesis** (`web/`). Parent: `specs/phase-53-kiro-sdk-v3.md`.
> Decisions: 53-01 D7, D10; F3, F5, F6. Contract: 53-09.

## 1. Goal

The small set of visible changes the v3 move brings; everything else in chat and run detail looks and behaves as today
(the API shapes are kept, 53-09).

## 2. Changes

| # | Where | Change |
|---|---|---|
| W1 | `features/chat/Composer.tsx`, `hooks.ts` (`useChatTurn`) | **Steering (D10).** Today the composer shows Stop *instead of* Send while `streaming` (`Composer.tsx:313-322`) and disables the textarea (`:303`), the model select (`:180`) and attach (`:309`); the submit guard is at `:121`. New: while `streaming`, the textarea stays enabled and **Send and Stop are both shown**. Send calls `chatApi.steer` (new, `lib/api/chat.ts`) and Enter does the same. The model select and attach stay disabled during a turn, so a steer is text only (F16, 53-01 §9.5; the steering method takes text only, 53-02 W7). |
| W2 | `features/chat/ChatThread.tsx` | A steered message renders as a user bubble with a small "sent during the turn" label (from `user.steer` live, `meta.kind = "steer"` after reload). On `agent.result.unread_steers`, the client sends those texts as the next message, in order, automatically (no user action), and the label changes to "sent after the turn". A steer refused with 409 is re-sent as a normal message **only after that turn's `agent.result` arrives** (until then `/messages` also answers 409, 53-09). |
| W2b | backend `chat/manager.py` `stream_turn` (the one backend touch in this sub-spec) | **Two engine turns in one prompt (F18):** when a second `turn_start` arrives inside one `session/prompt` (a steer at turn end, 53-02 W7b), insert a paragraph break (`"\n\n"`) between the two turns' answer text, both as a live `agent.message` chunk and in the stored answer. Today the stored answer runs them together (53-09 live: `oneone KIWI`). Test with the `steer-at-turn-end` fixture. |
| W3 | `hooks.ts` `stop` | Unchanged call (`/cancel`); the next turn is fast (no cold start). The stopped user message shows a muted "Stopped" label (live from the cancelled turn, and after reload from the stored turn status; reuse the existing cancelled-turn display if there is one). The D15 note is backend-only and never shown. |
| W4 | `ChatThread.tsx` (`AssistantBlock`, `LiveAssistant`), `features/run-detail/components/Inspector.tsx`, `conversation.ts` | **Model fallback (F6):** when `usage.fallback_from` / `agent.result.fallback_from` is set, show "answered by <model>" next to the credit badge (muted text, a tooltip "the requested model <x> was unavailable"). |
| W5 | `ChatThread.tsx` | **MCP notice (F3):** a `session.notice` `mcp_failed` renders an inline warning card on the turn: "<server> did not start: <detail>. Its tools are not available in this chat." using the existing feedback primitives (`shared/feedback`), not a new component. |
| W6 | `features/catalog/skills/SkillCard.tsx`, `hooks.ts` | **Update button (D7):** on an installed library skill, an "Update" action calling `POST /api/skills/update` (`useUpdateSkill`); toast on success/failure; the list refreshes. Remove the "Shadows a same-named skill in your personal ~/.kiro/skills" line (`SkillCard.tsx:61-65`) and the `shadowsPersonal` field. |
| W7 | Settings → General Kiro card (`features/settings/components/KiroSection.tsx`); first-run preflight checklist (`features/system/PreflightChecklist.tsx`) | Show the kiro-cli version and the `kiro-cli` / `kiro-cli-verified` items (53-08) with their remedies. |
| W8 | `types/chat.ts`, `types/skill.ts` (`:15-16` loses `shadows_personal`), `types/` for system | The types follow the 53-09 contract table and its 16 fixtures (`web/src/test/fixtures/{chat,system,skills}/`, written by the backend tests): `ChatEvent` gains `user.steer {seq, message_seq, text, status}`, `session.notice`, and on `agent.result` `model`, `fallback_from`, `code`, `unread_steers`; `ChatMessage.usage` gains `model?`, `fallback_from?`; messages carry `meta.turn_status`; skill type loses `shadows_personal`; Kiro status gains `version, minimum, verified, engine_v3, binary`. One contract test parses every 53-09 fixture through the web types (L-011). |

Stack rules: existing tokens and primitives only (ADR-027/055); never `<Button asChild>` (L-069); no new heavy
dependency (L-015); `/api` prefix only through the central client (ADR-028).

**Also from 53-07** (its As built, "Changes for 53-08..53-12", 53-10 item; the field names are in the 53-09 table):
strip `[STEERING steer-<id>: …]` markers in the live stream view, including an unclosed trailing fragment; hide or
label the engine's "Tool Load" step (an `agent.tool_update` with no `agent.tool_call`); the "Stopped" label reads
`agent.result.code == "cancelled"` live and `meta.turn_status == "cancelled"` after reload; re-send `unread_steers`
in order; on a 409 from `/steer`, send the text as a normal message.

## 3. Tests

Vitest + jest-axe (L-014): composer sends a steer while streaming, with Send and Stop both visible and the model select
and attach disabled; the steered bubble label; unread steers re-sent in
order after `agent.result`; "answered by" on chat and run detail; the MCP notice card; Skills Update calls the endpoint
and refreshes; no `shadowsPersonal` text; preflight items render. `npm run lint && npm run typecheck && npm test`, then
`npm run build` and commit `web/static/` as separate steps (L-089, L-030).

## As built (2026-11-14, genesis-dev) — review SHIP (round 2)

**Task restated.** Make the chat and run-detail web follow the v3 contract of 53-09: during a turn the composer
steers (Send and Stop both shown, text only, F16); steered messages, unread and refused steers re-sent after the turn,
the "Stopped" label, "answered by <model>", the MCP notice card, the Skills Update button (and `shadowsPersonal`
gone), the kiro-cli version and readiness items, and web types with one contract test over the 16 fixtures; strip the
live `[STEERING steer-…]` acknowledgement and label the engine's "Tool Load" step; and the one backend touch, W2b
(F18): a paragraph break between two engine turns in one prompt. Rules applied: ADR-027/055 (existing primitives and
tokens), ADR-028 (all calls through `lib/api`), ADR-031/033/045 (a steer is the user's own text in the user's own
turn; model, attach, Clear, Compact stay disabled), ADR-032 (credits read, never computed; a stopped turn keeps its
metered credits), ADR-066; L-007, L-011, L-014, L-015, L-018, L-030, L-046, L-069, L-083, L-089, L-090, L-094, L-110.
KiroCrew (read only) used for: the marker grammar and the unclosed-tail strip (`src/kiro_crew/discord/renderer_text.py`
`_STEER_MARKER_RE`, `_strip_steering`; `website/src/app-sdk/protocol/steering.ts`), the steer as a text-only channel
whose refusal hands the text back (`website/src/chat-core/composer/outgoingTurn.ts`), and "no evidence of injection =
unread, requeue it" (`src/kiro_crew/dashboard/steer_settle.py`). Genesis differs where our contract does: one joined
re-send, after the stream ends (53-09: `/messages` is 409 until then), and never after a Stop. No ADR deviation.

### Commits (local, not pushed)

- genesis `b9ba5d9` feat(web,chat,53-10) on base `330905b`: everything under Changed (source, tests, fixtures, the
  probe, `web/static`). `git show --stat b9ba5d9 -- web/static`: 65 files; a fresh `npm run build` afterwards left
  `git status --short --untracked-files=all` empty (L-089).
- project-tracker: this As built, the status line and `reviews/53-10-review.md` (one commit).

### Changed

genesis — backend (W2b):
- `genesis/chat/manager.py`: `ENGINE_TURN_BREAK = "\n\n"`, `_engine_turn_id(m)` (the chunk's `_meta.kiro.turnId`, else
  `executionId`), `_Turn.answer_turn`; `_absorb` prefixes the first answer chunk of a new engine turn with the break
  when earlier answer text exists, so the live `agent.message` and the stored answer agree (the stopped-turn drain goes
  through `_absorb` too). Module docstring.

genesis — web:
- `features/chat/steering.ts` (new, pure): `stripSteeringAcks(text, live)` (complete marker; an unclosed
  `[STEERING steer-…` tail always; while live also a trailing prefix of `[STEERING steer-`), `stoppedUserSeqs`,
  `steerLabel`, `unreadSteers`, `textsAfterTurn(steers, unread, events)` (fills a missing `messageSeq` from the
  stream's `user.steer`, review M1), `LiveSteer`, `SENT_DURING` / `SENT_AFTER`.
- `features/chat/hooks.ts` `useChatTurn`: `steer()`, local steers, `unread` (page session), `draft`, `stopping`,
  `pendingLabel`; refs for the open stream and a turn token; re-send after the stream ends (`deliverAfterTurn`: back to
  the composer after a Stop, into a running turn, else as the next message); Stop = `/cancel` then wait for the turn's
  own end, abort only on a failed cancel or after `STOP_FALLBACK_MS` (10 s).
- `features/chat/Composer.tsx`: `onSteer`, `stopping`, `draft`; textarea enabled during a turn (`pr-36` from the probe),
  Send and Stop both shown, palette closed, a typed `/command` waits (n1), footer text for the turn.
- `features/chat/ChatThread.tsx`: bubble labels, live steer bubbles, `McpNoticeCard` (inline, the app's warning
  tokens + `TriangleAlert`; `shared/feedback` has only page-level states), notices anchored before their turn's answer,
  live ack strip, `AnsweredBy` beside the credits.
- `shared/ui/format.tsx`: `AnsweredBy` (muted, `title` tooltip, sr-only reason).
- Run detail: `run-detail/conversation.ts` (result `model`, `fallbackFrom`; an update with no tool call is named by its
  `name`, i.e. "Tool Load"), `components/inspector/conversationParts.tsx` (`ResultChip` shows `AnsweredBy`),
  `components/Inspector.tsx` (per-execution chip from the node's `agent.result` at `seq_end`).
- Skills: `lib/api/skills.ts` `update`, `types/skill.ts` (`SkillInstallResult`; `shadows_personal` removed),
  `features/catalog/skills/{hooks.ts (useUpdateSkill), SkillCard.tsx (Update on installed library skills; the
  shadowing line and field removed), SkillsTab.tsx}`.
- System: `types/system.ts` (new: `KiroStatus` + `version, minimum, verified, engine_v3`; `Preflight`, `PreflightItem`
  with `status: "ok" | "missing"`), `lib/api/system.ts` (types re-exported, `preflight()`, `kiroLogout` typed as the
  sign-in part), `lib/api/index.ts`, `features/system/hooks.ts` (new: `usePreflight`, `KIRO_CLI_ITEMS`),
  `PreflightChecklist.tsx` (shared hook and types, `PreflightRow`, `HintText` links a hint's URL, header "Optional"),
  `features/settings/components/KiroSection.tsx` (version · minimum, the two kiro-cli items with remedies; no
  "isn't installed" while loading).
- Types: `types/chat.ts` (`ChatUsage`, meta `turn_status` / `command` / `ok`, `usage_total`, `SteerResponse`,
  `ClearCompactResponse`, the exact per-event interfaces, new optional `ChatEvent` fields); `lib/api/chat.ts` `steer`.
- Fixtures re-recorded by the backend test (`GENESIS_WRITE_CONTRACT_FIXTURES=1`): `chat/turn-steered.json` (the
  `"\n\none KIW"` chunk), `chat/session-steered.json` (`"one\n\none KIWI"`; new timestamps and id).
- `scripts/probes/chat-steer-widths.mjs` (new, L-090): Vite from `web/` with `/api` proxied to an in-process mock
  that serves the fixtures and holds the turn's SSE open; measures the composer, the steered bubble, the MCP card and
  the Skills card footer.
- `web/static` rebuilt.

### Tests

- Backend: `test_phase53_api_contract.py::test_steer_answers_queued_and_the_stream_reports_delivery` asserts the live
  chunks `["one", "\n\none KIW", …]` and the stored `"one\n\none KIWI"` on the `steer-at-turn-end` recording (failed
  before the fix: `'one KIW' != '\n\none KIW'`); new `test_chat_manager.py::
  test_two_engine_turns_in_one_prompt_are_joined_with_a_paragraph_break` (once; not inside one engine turn; not after a
  text-less first turn; never without a turn id).
- Web, new: `test/fixtures/phase53-contract.test.ts` (5: all 16 fixtures against `Exact<T>` key lists, value domains,
  the turns through the real fold); `features/chat/steering.test.ts` (7: the recorded steered stream never shows any
  part of the ack, the unclosed tail, prose kept, Stopped seqs, labels, re-send order, the M1 match);
  `features/chat/steer.test.tsx` (13, a controllable CRLF SSE stream: composer during a turn + jest-axe, Enter/Send
  steer, the recorded steered turn with the notice card + jest-axe and the card after reload, unread re-sent in order
  after the stream ends, 409 re-sent after it, the late-POST unread (M1), a late 409, a 500 back to the composer, a
  typed `/command` waits, Stop → `/cancel` + Stopped live and after reload, leftovers after Stop back to the composer,
  stored steer label + answered-by + jest-axe, no answered-by without a fallback);
  `features/run-detail/model-fallback.test.tsx` (4: Tool Load label, result fields, ResultChip, Inspector chip +
  jest-axe). Extended: `skills.test.tsx` (+2: Update calls the endpoint and refreshes; no Update on an authored skill,
  no shadowing text), `system.test.tsx` (+3: kiro-cli items first with the link, the unverified remedy, jest-axe),
  `settings/kiro.test.tsx` (rewritten on the fixtures, 6: + version, the two items, a remedy, jest-axe).
- Mutation checks (each reverted): web — no after-turn delivery (3 fail), textarea disabled in a turn (5), no ack strip
  (3), no live Stopped (1), no draft after Stop (1), no events to `textsAfterTurn` (1), no late-409 delivery (1), no
  draft on a 500 (1), no command guard (1); the reviewer repeated the M1 and m1/n1 mutations.
- Gates: genesis `pytest -q --deselect tests/test_config.py::test_server_readiness_probe` **1933 passed, 1 deselected**
  (with `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false`, the 53-09 signing issue);
  `ruff check genesis` clean. Web: `npm run lint` 0 errors (the 20 pre-existing warnings), `npm run typecheck` clean,
  `npm test` **762 passed (66 files)**, `npm run build` ok, bundle committed and proved clean after a rebuild.
- Geometry probe (L-090), `node scripts/probes/chat-steer-widths.mjs`, 1280/1440/1920 × light/dark: run 2 found the
  textarea's right padding (112 px) narrower than the Send + Stop + attach group (130 px) → `pr-36`; run 3
  (`/tmp/genesis-probes/5310-run3/`) all 12 entries clean (no page h-scroll, buttons inside the textarea and clear of
  the text, bubble and label inside the column and right-aligned, MCP card without overflow, Skills footer on one row
  without spill); screenshots read at 1280 light and 1920 dark (chat) and 1280 light (skills).
- **Not run:** live kiro-cli or the fleet (no credits; D20) — a live steer, unread steer, Stop through `genesis serve`,
  a model fallback and the MCP notice belong to 53-11; the `python:3.13` CI image (L-112).

### Review

`reviews/53-10-review.md`: round 1 **NEEDS_CHANGES** — M1 (an unread steer whose `POST /steer` answer arrives after
the stream closed was never re-sent: reproduced by the reviewer), m1 (two `steer()` error paths untested), m2 (after
a reload an unread steer row reads "sent during the turn"), n1 (a typed `/compact` during a turn was steered as text),
n2 (`cn` in `AnsweredBy`). M1, m1, n1, n2 fixed with tests that fail under mutation; m2 accepted as backlog. Round 2
**SHIP** (reviewer re-ran lint, typecheck, 762 tests, a fresh build identical to `web/static`, the mutations). Left:
n3 (optional: the 500 test does not assert the toast; the test harness renders no toaster).

### Decisions / deviations

No ADR deviation. Each ruled OK in the review:

1. **No `binary` on `KiroStatus`:** `GET /system/kiro` does not return it (53-09 table, `kiro-status.json`); it is
   internal to `check_kiro()`. The type follows the wire (L-011). The W8 line naming `binary` is a spec slip
   (docs agent: correct it).
2. **One joined re-send:** refused and unread steers go as one next message, texts joined by a blank line in typed
   order (W2 "the next message, in order"; one turn instead of N).
3. **Re-send after the stream ends**, not on the `agent.result` event: the server releases the session only when the
   stream closes, so `/messages` would answer 409 between the two.
4. **Stop no longer aborts the stream first:** it posts `/cancel` and the stopped turn ends on its own stream
   (`turn-cancelled.json`: `code: "cancelled"`, metered credits, the stored record written before the result), so the
   live "Stopped" label and the credits show; the stream is aborted only if `/cancel` fails or after 10 s (the
   backend's stop wait is 8 s). Previously the web aborted, then posted `/cancel` (53-07 handled both orders).
5. **After a Stop, leftover steers go back to the composer** instead of starting a turn; a non-409 steer error does
   the same with a toast.
6. **Live steer bubbles sit after the turn's user bubble**, before the answer, as the stored order has them.
7. **The MCP card lives in the page session** (the backend does not store the notice) and is anchored before its
   turn's answer; a local component reusing the app's inline-warning tokens, since `shared/feedback` holds only
   page-level states.
8. **The palette is closed during a turn and a typed `/command` waits** for the turn to end (a steer is text, L-046).
9. **"Tool Load" is labelled by its name** in the shared fold (chat already hides tools; run detail now reads
   "Tool Load", not "tool").

### Lesson candidates

- **A client that joins two streams must not depend on which one answers first:** the steer's POST answer and the
  turn's SSE end travel on separate connections, so the after-turn logic keyed on the POST's `message_seq` lost a steer
  when the stream closed first. Key such matching on the stream's own events (here `user.steer`), which the server
  sends before it answers (review M1).
- **A geometry probe needs no live backend:** Vite from `web/` with `server.proxy` pointed at an in-process mock that
  serves the recorded fixtures and holds an SSE stream open measures a "turn running" screen deterministically, with
  no fleet and no credits; it found a 112 px padding against a 130 px button group that jsdom could not see.

### Code-map changes

- `genesis/genesis/chat/manager.py`: `ENGINE_TURN_BREAK`, `_engine_turn_id`, `_Turn.answer_turn` (F18).
- `genesis/web/src/features/chat/steering.ts` (steer and ack helpers); `useChatTurn` gains `steer`, `stopping`,
  `steers`, `unread`, `draft`, `pendingLabel`, `STOP_FALLBACK_MS`; `Composer` gains `onSteer`, `stopping`, `draft`.
- `genesis/web/src/shared/ui/format.tsx`: `AnsweredBy`.
- `genesis/web/src/types/system.ts` (new); `features/system/hooks.ts` (`usePreflight`); `PreflightRow`, `HintText`
  exported from `PreflightChecklist.tsx`; `systemApi.preflight`, `skillsApi.update`, `chatApi.steer`,
  `useUpdateSkill`.
- `genesis/web/src/test/fixtures/phase53-contract.test.ts` (the Phase 53 web contract test).
- `genesis/scripts/probes/chat-steer-widths.mjs` (the chat/skills width probe).

### Changes for 53-11..53-12

- **53-11 (acceptance), live on kiro-cli 2.37.1 through `genesis serve` and the browser:**
  - A steer typed mid-answer: bubble "sent during the turn", `user.steer` queued → delivered, one answer with the
    paragraph break when the steer lands at the turn's end (F18), no `[STEERING …]` text at any moment.
  - Stop during a tool call: the Stop spinner, then "Stopped" on the user message with the turn's metered credits, the
    next turn fast; a steer left over by the Stop is back in the composer and no turn starts.
  - A 409 steer (send just as the turn ends) re-sent as the next message labelled "sent after the turn"; an unread
    steer if the engine ever reports one.
  - The MCP notice card on a chat whose MCP server cannot start; "answered by <model>" if a fallback frame is ever
    seen; Settings → General shows the kiro-cli version and the two items; the preflight hint links the install page;
    Skills → Update on an installed library skill (toast, list refreshed, the next chat turn sees the new version).
  - Re-run `scripts/probes/chat-steer-widths.mjs` on the release tree if the composer or the cards change again.
- **53-12 (release):** release notes: Stop now waits for the stopped turn's end on its stream (up to 10 s) instead of
  closing it at once; steering from the composer; Skills Update; the personal-skill shadowing line is gone. The
  frontend job runs (web changed, L-030).
- **Backlog** (for `specs/backlog/phase-53-follow-ups.md`):
  - Review m2: after a page reload an unread steer row reads "sent during the turn" and its re-sent text shows as a
    second, unlabelled message: store `meta.steer_status = "unread"` on the steer row at `agent.result` (backend) and
    read it in `steerLabel`; optionally mark the re-sent message.
  - The MCP notice is not stored, so the card is gone after a reload (store it on the turn if users miss it).
  - Review n3: assert the "Could not send" toast in the 500 test (render the toaster in the harness).
  - The `act()` warning in `chat.test.tsx` "has no a11y violations" (pre-existing at 330905b).
- **Docs agent:** correct W8's "Kiro status gains … `binary`" (decision 1).

## Context manifest

```toml
areas    = ["chat", "web-runs", "web-shell", "features-stages"]
adrs     = ["ADR-027", "ADR-028", "ADR-031", "ADR-032", "ADR-055"]
lessons  = ["L-007", "L-011", "L-014", "L-015", "L-030", "L-069", "L-089", "L-090"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-09-api.md"]
code     = ["genesis/web/src/features/chat/**", "genesis/web/src/features/run-detail/**", "genesis/web/src/features/catalog/skills/**", "genesis/web/src/features/settings/**", "genesis/web/src/features/system/**", "genesis/web/src/lib/api/chat.ts", "genesis/web/src/types/**", "genesis/web/src/test/fixtures/**"]
upstream = ["53-09"]
```
