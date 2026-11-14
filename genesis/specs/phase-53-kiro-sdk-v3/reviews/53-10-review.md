# Review 53-10 — base 330905b (genesis-review, 2026-11-xx)

What this change does: the web side of the v3 move. During a chat turn the composer stays enabled: Send and Enter
steer the running turn (`POST /steer`) and Stop posts `/cancel` and waits for the turn to end on its own stream.
Refused (409) steers and `unread_steers` are re-sent as one message after the stream ends. User bubbles get the "sent
during / after the turn" and "Stopped" labels, the live answer drops the `[STEERING steer-…]` acknowledgements, and
"answered by <model>" appears in chat and run detail. There is an MCP notice card, a skills Update button (the
`shadows_personal` field is gone), the kiro-cli version and items in Settings and the preflight checklist, the 53-09
types, and one contract test over the 16 fixtures. The one backend change (W2b, F18) joins two engine turns' answer
text in one prompt with `"\n\n"`, both live and stored.

Reviewed: `git diff 330905b` (HEAD = 330905b, verified) plus the 8 untracked files; `web/static` checked by a
separate build only.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings --deselect tests/test_config.py::test_server_readiness_probe` (with `GIT_CONFIG_COUNT=1 … commit.gpgsign=false`) | **1933 passed, 1 deselected** in 597 s |
| `.venv/bin/ruff check genesis` (+ the two changed test files) | All checks passed |
| `web: npm run lint` | 0 errors, 20 warnings (pre-existing `react-refresh`) |
| `web: npm run typecheck` | clean |
| `web: npm test` | **757 passed (66 files)** |
| Stale bundle: `npx vite build --outDir /tmp/rv5310-static` then `diff -r /tmp/rv5310-static web/static` | **identical** |
| L-090 probe `/tmp/genesis-probes/5310-run3/result.json` | chat-turn and skills at 1280/1440/1920 in light and dark: no page h-scroll, `buttons_inside` and `text_clear_of_buttons` true, no bubble or card overflow. I looked at the 1280-dark chat and 1280-light skills screenshots and both are correct. |
| playwright-appian / genesis-workflows / kiro-agent-sdk gates | N/A: no file changed in those repos or packages (the check lists them only through area mapping) |

## Checklist

ADRs
- [OK] ADR-027 / ADR-055 — existing primitives and tokens. `McpNoticeCard` uses `border-warning/40 bg-warning-subtle`
  and `TriangleAlert` from `@/shared/ui`, the same pattern as `features/chat/cards.tsx`. `AnsweredBy` uses
  `text-fg-subtle`. The Update button is the shared `Button` with `loading`. No raw palette colours in the diff.
- [OK] ADR-028 / L-010 — new calls go through `api.post/get` in `lib/api/{chat,skills,system}.ts` (`/chat/sessions/:id/steer`,
  `/skills/update`, `/system/preflight`). `PreflightChecklist` no longer calls `api.get` inline; it uses `usePreflight`.
  No `/api` literal in components (the existing `exportMdHref` is unchanged).
- [OK] ADR-031 / ADR-033 / ADR-045 — a steer only adds user text to the read-only chat's own turn. The model select,
  attach, Clear and Compact stay disabled during a turn (`steer.test.tsx` "keeps the textarea enabled…"). The web adds
  no new tool or trust.
- [OK] ADR-032 / L-016 — credits are still read from `agent.result` / `usage`. `AnsweredBy` sits beside `CreditBadge`
  and computes nothing. A stopped turn keeps its metered credits because Stop no longer aborts first
  (`turn-cancelled.json` path).
- [OK] ADR-034 — skills Update calls the backend's install path. The web does not touch the filesystem.
- [OK] ADR-066 — run detail gains the model on the result chip and the per-execution chip (`Inspector.tsx:106-116,178-191`),
  read from the node's existing `agent.result`.
- [OK] ADR-026 / ADR-003 / ADR-008 — no bind or auth change. The probe's mock server listens only on loopback through
  Vite.
- [OK] ADR-077 — the review used `genesis-ctx check`/digests and opened no bulk docs.
- [OK] ADR-080 — no version, pin or package-metadata change in this sub-spec.
- [N/A] ADR-001, 002, 004, 005, 007, 009, 010, 011, 013, 019–022, 025, 029, 030, 035–044, 046–054, 056–065, 067–076,
  078, 079, 081–085 — the diff touches no graph, MCP injection, registry, run/HITL, KB, feature-stage, Hub, test
  execution or reports code. The `features-stages`, `config-secrets` and `browser-testing` areas are pulled in only by
  path globs on `catalog/skills/*`, `settings/KiroSection.tsx` and `scripts/probes/*`.

Lessons
- [OK] L-007 — the live answer still goes through `buildTranscript(liveEventsToRunEvents)`. The ack strip is applied to
  the folded message items (`ChatThread.tsx` `LiveAssistant`). No new Markdown dependency.
- [OK] L-011 — `web/src/test/fixtures/phase53-contract.test.ts` checks all 16 fixtures against `Exact<T>` key lists, so
  tsc fails on a type drift and the test fails on a fixture drift. `turn-steered.json` / `session-steered.json` were
  re-recorded by the backend test (`record(...)` in `test_phase53_api_contract.py`), not edited by hand.
- [OK] L-014 — jest-axe is used in the new tests (`steer.test.tsx` ×3, system, kiro, skills a11y). No new ambient types.
- [OK] L-015 — no new dependency.
- [OK] L-018 — the test stream frames events with CRLF (`steer.test.tsx` `controlledStream`).
- [OK] L-030 — this change touches `web/**`, so the frontend job runs. The bundle is fresh (identical diff above).
- [OK] L-069 — no `<Button asChild>` in the diff (`grep asChild` on the changed files: none).
- [OK] L-083 — the tests feed the recorded fixtures (`turn-steered.json` with the ack split over 16 chunks,
  `turn-cancelled.json`, `session-stopped.json`), not hand-made shapes.
- [OK] L-089 — the bundle was verified after the build had exited (separate step; identical).
- [OK] L-090 — a real-browser geometry probe at three widths in both themes found and fixed the textarea padding
  (`pr-36`). Run 3 is clean (see Gates).
- [OK] L-094 — callers of the changed functions: `useChatTurn` is used only by `ChatThread` (grep). `Composer`'s new
  props are optional, and the other Composer host gets the old behaviour (`disabled={streaming && !onSteer}`).
  `buildTranscript`'s new fields are additive, and its tool-name change affects only the no-tool_call fallback.
  `KiroStatus` moved to `types/system.ts` and is re-exported from `lib/api/system.ts`; its only consumer is
  `KiroSection`. The return type of `kiroLogout` narrowed to what `kiro_auth.logout()` returns; its result is used only
  to invalidate.
- [OK] L-101 — the probe imports Vite from `web/node_modules` and Playwright from `$GENESIS_PLAYWRIGHT`, the sibling
  checkout or `import("playwright")`. It uses no `npx`.
- [OK] L-110 / L-111 — the gates ran at base 330905b over the working tree. Live acceptance against real kiro-cli is not
  part of this review (see Not checked).
- [N/A] L-001–L-006, L-008, L-012, L-013, L-017, L-019, L-022–L-029, L-031, L-034, L-041–L-049, L-051, L-053–L-064,
  L-066–L-068, L-070–L-076, L-081, L-082, L-084–L-088, L-091–L-093, L-095–L-100, L-103–L-105, L-107, L-109, L-112 — no
  code in their areas changed (no DB, registry, MCP env, SSE bus lifetime, run-graph layout, Hub, KB or release
  change). L-003 note: the chat SSE close is unchanged, and the client still ends on the stream's own close.

## Findings

### Blockers
None.

### Majors
- M1 **An unread steer is never re-sent when its `POST /steer` answer arrives after the turn's stream has ended**
  (`web/src/features/chat/hooks.ts` `send` finally → `textsAfterTurn(steersRef.current, unreadSeqs)`;
  `steering.ts:textsAfterTurn`).
  - What the code does: `textsAfterTurn` matches the `unread_steers` message seqs only against `LiveSteer.messageSeq`,
    and only the `/steer` HTTP answer sets that field. The finally block computes `after` as soon as the stream closes,
    then clears `steersRef`.
  - Problem: the backend stores the steer and puts `user.steer {message_seq, text}` on the SSE stream before it
    answers the POST (`chat/manager.py` `steer()`). The POST answer and the stream's end travel on two independent
    connections. If the stream closes first, which is exactly the "steered at the very end, engine did not read it"
    case that `unread_steers` exists for, the steer still has `messageSeq: null`, so `after` is empty. When the POST
    answer lands, `updateSteers` maps over an already-cleared list.
  - Result: the person's message is stored as a steer the model never read, nothing re-sends it, and after a reload it
    reads "sent during the turn".
  - Reproduced with a scratch test outside the repo (`/tmp/rv5310web/src/features/chat/zz-review-probe.test.tsx`,
    the `steer.test.tsx` harness). The `/steer` handler is held, the stream emits `user.steer {message_seq: 2}` then
    `agent.result {unread_steers: [2]}` and closes, then the handler is released. Result:
    `SENT messages: ["Reply with one"]`. The expected result is a second message, "late steer".
  - Fix (small): resolve unread texts from the stream itself. `user.steer` carries `message_seq` and `text`, and the
    stream is the source the backend's `unread_steers` refers to. In the finally block, before `textsAfterTurn`, fill a
    missing `messageSeq` on each `LiveSteer` from the turn's `user.steer` events: the first `queued` event with the same
    text whose seq is not taken yet. Alternatively, have `textsAfterTurn` take the events and map unread seqs → text
    from `user.steer` events, keeping typed order through the local list. Add the probe above as a regression test.
  - If skipped: a steer typed in the last moment of an answer can vanish without any sign.

### Minors
- m1 **Two error paths of `steer()` have no test** (`hooks.ts` `steer` catch).
  - Problem: these paths have no test: (a) the "late 409 after the stream ended → delivered directly" path
    (`inTurn === false` → `deliverAfterTurn([t])`), which the brief claims, and (b) a non-409 error, which puts the
    text back in the composer and shows a toast. Each is a branch whose break would lose or duplicate a message. The
    mutation checks listed in the brief cover neither.
  - Fix: two cases in `steer.test.tsx`. (a) Hold `/steer`, close the stream, release it with 409, and expect
    `sent == [first, text]`. (b) Answer 500 and expect the composer value to equal the text and no second `/messages`.
- m2 **After a reload an unread steer row reads "sent during the turn"** (`ChatThread.tsx` stored-row label;
  `unread` is page state).
  - Problem: the label is wrong exactly for the steers that were not read, and the re-sent text then shows as a
    second, unlabelled message.
  - Ruling: acceptable for this sub-spec, because the backend stores no unread marker. It must be a backlog item
    (store `meta.steer_status = "unread"` on the steer row at `agent.result`, then read it in `steerLabel`) so that it
    is not forgotten. See Rulings.

### Nits
- n1 **A slash command typed during a turn goes to the model as plain text** (`Composer.tsx` `submit`, streaming branch).
  - Case: typing `/compact` and pressing Enter while the agent answers steers the literal text "/compact" into the
    turn. The palette is closed, and the L-046 command path is not used.
  - Fix: in the streaming branch, ignore Enter on text starting with `/` (keep the text, so it sends after the turn),
    or show the footer hint "commands wait for the turn to end".
- n2 `AnsweredBy` builds its class with `"text-fg-subtle " + (className ?? "")` (`shared/ui/format.tsx`). Use `cn(…)`
  like the rest of `shared/ui`.

## Rulings on the author's decisions
- **`binary` on `KiroStatus`:** agree to omit it. `GET /system/kiro` does not return it (the `kiro-status.json`
  fixture and the 53-09 table), and `binary` is internal to `check_kiro()` / `preflight.kiro_cli_status()`. L-011 means
  the type follows the wire, so spec W8's mention of `binary` is a spec slip. The docs agent should correct the spec
  line.
- **One joined re-send message:** OK. W2 says "sends those texts as the next message, in order". Joining them with a
  blank line, in typed order, matches that and costs one turn instead of N.
- **Stop no longer aborts first:** OK, and better than before. It matches the 53-07/53-09 contract (`turn-cancelled.json`:
  `agent.result.code = "cancelled"` with metered credits) and keeps the Stopped label and the credits live.
  `STOP_FALLBACK_MS` = 10 s is longer than the backend's `_STOP_WAIT_S` of 8 s, and a failed `/cancel` aborts at once.
- **Leftovers after Stop go back to the composer:** OK. A Stop should never start a turn by itself, and the spec does
  not cover this case.
- **Unread steer label after reload / re-sent text as a normal message:** accepted as m2, with a backlog item.
- **MCP card only in the page session:** OK. The backend does not store the notice (53-07). The probe confirmed that
  the card stays as one card across a second turn (scratch test: 1 card after turn 1, during turn 2 and after turn 2).
  The local component, instead of a `shared/feedback` primitive, is justified because `shared/feedback/states.tsx`
  holds only page-level states. It reuses the inline warning pattern of `chat/cards.tsx`.
- **Palette closed during a turn:** OK, since a steer is text only (F16). See n1 for the typed-command edge.
- **Tool Load:** labelling it by `p.name` meets "hide or label". Chat already hides tools.

## Backend W2b
`_engine_turn_id` reads `_meta.kiro.turnId`, else `executionId`. The break is added only when the id changes after
non-blank answer text, and the stored answer is `"".join(t.answer)` through `strip_steering_acks`, so live and stored
text agree. `_finish_abandoned` drains through `_absorb` too, so a stopped second turn gets the break as well. Tests
cover the break once, its absence inside one engine turn, after a text-less first turn and with no turn id
(`test_two_engine_turns_in_one_prompt_are_joined_with_a_paragraph_break`), plus the recorded steer-at-turn-end
contract (`"\n\none KIW"`, stored `"one\n\none KIWI"`). No finding.

## Not checked
- Live behaviour against a real kiro-cli 2.37.1 (steer, unread, Stop, model fallback, MCP notice) on the fleet: this
  is out of scope (no fleet changes) and belongs to 53-12 live acceptance.
- That the new backend assertions failed before the fix: I accepted the author's report ('one KIW' != '\n\none KIW').
  The logic confirms it, but I did not revert the fix.
- The run-detail "answered by" with a real workflow `agent.result` carrying `model`/`fallback_from`: only fixtures
  and unit tests were used.
- Screenshots other than chat-turn 1280-dark and skills 1280-light (the other widths and themes were checked through
  `result.json` only).

Scratch files of this review are outside the repo: `/tmp/rv5310web/` (a copy of `web/src` plus the probe test) and
`/tmp/rv5310-static`. The genesis working tree was not modified.

## Verdict: NEEDS_CHANGES
Fix M1 (resolve unread steers from the stream's `user.steer` events) with its regression test, and add the m1 tests.
All gates are green; m2 goes to the backlog, and the nits are optional.

---

# Round 2 — base 330905b, working tree (genesis-review)

Scope: the web fixes for M1, m1, n1 and n2 (`web/src/features/chat/{steering.ts,hooks.ts,Composer.tsx}`,
`shared/ui/format.tsx`, `steer.test.tsx`, `steering.test.ts`) and the rebuilt `web/static`. The author reports the
backend as unchanged since round 1. `git status` shows the same backend files as in round 1 (`genesis/chat/manager.py`
and two test files), so the round-1 pytest result (1933 passed) stands. I did not re-run pytest.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `web: npm run lint` | 0 errors, 20 warnings (the same pre-existing `react-refresh` warnings) |
| `web: npm run typecheck` | clean |
| `web: npm test` | **762 passed (66 files)** |
| Stale bundle: `npx --no-install vite build --outDir /tmp/rv5310r2-static --emptyOutDir`, then `diff -r /tmp/rv5310r2-static web/static` (a separate step after the build exited, L-089) | **identical** |
| Mutations, in a scratch copy `/tmp/rv5310r2web` (`web/` without `node_modules`/`static`, `node_modules` symlinked), `vitest run src/features/chat/steer.test.tsx` | see below |

Mutation results:
- `hooks.ts`: `textsAfterTurn(steersRef.current, unreadSeqs)` (events dropped). Only "re-sends an unread steer whose
  POST answer arrives after the stream ended" fails (1 failed, 12 passed).
- After restoring that, three mutations together: drop `deliverAfterTurn([t])` in the late-409 branch, drop `toDraft([t])`
  in the non-409 branch, and drop `|| commandWaits` from the streaming `submit` guard in `Composer.tsx`. Exactly the
  three matching tests fail ("sends a steer refused with 409 after the stream ended…", "puts a steer that failed for
  another reason back in the composer…", "does not steer a typed slash command…"), and the other 10 pass.

## Findings from round 1

- **M1: fixed.** `steering.ts:textsAfterTurn(steers, unread, events)` gives each steer that has no `messageSeq` and was
  not refused the `message_seq` of the first `user.steer {status: "queued"}` event with the same text whose seq is not
  yet taken. It then filters on `unread`. `hooks.ts` `send` finally passes the turn's own `events`, the local array
  built in the stream callback, so the values are not stale. The match on text is sound: the route trims the text
  (`api/chat.py:279`), `ChatLive.steer` stores and streams that same text (`chat/manager.py:658-660`), and the web
  sends `text.trim()`. The `user.steer` event is queued before the POST returns, so it is on the stream whenever the
  steer was stored. Two late cases are harmless. If the POST answer lands after the list was cleared, `updateSteers`
  maps an empty list. If it lands after a re-send started, it maps the new list by a unique key and changes nothing.
  The duplicate-text case is covered (`steering.test.ts` "matches a steer still waiting for its POST answer…": seq 2
  is taken, so the pending one gets 3, and without events it gets nothing). My round-1 probe is now the component
  regression test, and the mutation above shows the test depends on the fix.
- **m1: fixed.** Both error paths have a test (late 409 → `sent == ["Reply with one", "too late"]`; 500 → composer value
  `"keep this"`, no steered bubble, one `/messages`), and each test catches its own mutation.
- **m2: accepted as backlog**, as ruled in round 1. It must appear in the As built and in the backlog file (store
  `meta.steer_status = "unread"` on the steer row at `agent.result`, read it in `steerLabel`).
- **n1: fixed.** `Composer.tsx` `commandWaits = canSteer && text.trimStart().startsWith("/")`. Enter returns early,
  Send is disabled, the text stays and the footer reads "Commands wait until the turn ends · Stop ends it". The palette
  stays closed during the turn (`paletteOpen = !streaming && …`).
- **n2: fixed.** `AnsweredBy` uses `cn("text-fg-subtle", className)` (`shared/ui/format.tsx`).

## New findings

### Blockers / Majors / Minors
None.

### Nits
- n3 The 500 test does not assert the `toast.error("Could not send: …")` (`steer.test.tsx` "puts a steer that failed
  for another reason back in the composer"). If the toast is dropped, the text still returns to the composer with no
  word of why. To fix, add `expect(await screen.findByText(/Could not send/)).toBeInTheDocument()` if the test
  harness renders the toaster. This is optional.

## Checklist delta
The round-1 checklist stands. The lines touched again:
- [OK] L-011 / L-083: the new tests use the real `user.steer` shape (`type`, `seq`, `message_seq`, `text`,
  `status: "queued"`), which matches the `UserSteerEvent` type (`types/chat.ts:143-149`) and the backend event
  (`manager.py:660`).
- [OK] L-046: a slash command is no longer steered as text. It waits for the normal prompt path.
- [OK] L-089: the bundle was compared after the build had exited, in its own step.
- [OK] L-090: the n1 change alters only the footer text and the `disabled` state (no layout or padding class changed),
  so the round-1 width probe still applies. I did not re-run it.
- [OK] L-094: `textsAfterTurn` has one production caller (`hooks.ts`), and the new `events` parameter defaults to `[]`.
  `steering.test.ts` is its only other caller.

## Not checked (round 2)
- I did not re-run pytest or ruff, because the backend is unchanged (see the scope note at the top of this section).
- I did not re-run the L-090 probe (see the checklist delta).
- The author says the `act()` warning in `chat.test.tsx` "has no a11y violations" also exists at the base. I accepted
  that without a base checkout of my own. It does not fail the suite.
- A backend race outside this sub-spec: a steer whose `client.steer` call is still running when the turn ends. I
  assumed the engine then answers `queued: false` (→ 409 → the web sends it directly, which is now tested). Live
  confirmation belongs to 53-12.
- Live behaviour against kiro-cli 2.37.1 belongs to 53-12, as in round 1.

The round-2 scratch files are outside the repo: `/tmp/rv5310r2web` (the mutated copy) and `/tmp/rv5310r2-static`. The
genesis working tree was not modified.

## Verdict (round 2): SHIP
M1, m1, n1 and n2 are fixed, and each fix has a test that fails under mutation. m2 is accepted as a backlog item that
the As built must list. All web gates are green and `web/static` matches a fresh build. n3 is optional.
