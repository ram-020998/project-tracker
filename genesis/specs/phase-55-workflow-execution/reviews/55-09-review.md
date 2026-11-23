# Review 55-09 — base 1f8fd8b5, head 9f7f0688 (genesis-review, 2026-11-24)

What this change does: the Run Detail Documents tab is rebuilt on `GET /runs/{id}/documents` (search, By step / By
type, Output pinned, Inputs, steps in graph order, tool outputs as records, System listed but never fetched), with a
richer viewer header and Open in step. A Resolve tab (`/runs/:runId/resolve`) is added: the escalation strip, the six
manual actions, the Resolve chat composed from the chat's own bubbles, composer and turn hook, proposal cards following
the live `allowed`, the action dialogs, result cards and "This chat" credits. Two small backend additions: `nodes` on a
`_parallel` document, and nested-path session-output read/download routes.

Commits resolved: f9f126c2, b023e73e, 8620f7fc, 9f7f0688 all exist (`git log 1f8fd8b5..HEAD`).

## Gates (run by the reviewer)

- `npm run lint` → 0 errors, 20 warnings (baseline). `npm run typecheck` → clean.
- `npx vitest run` → **85 files, 1010 passed** (matches the author).
- Stale bundle: `npx vite build --outDir /tmp/rv-55-09/static` then `diff -r /tmp/rv-55-09/static web/static` →
  identical. `git status --short --untracked-files=all` empty. `git show --stat` of b023e73e (69 files) and 9f7f0688
  (66 files) touch only `web/static`.
- `GENESIS_STATE_DIR=/tmp/rv-55-09/state .venv/bin/python -m pytest -q -p no:warnings` → **2379 passed, 1 failed,
  4 skipped** (810 s). The failure is `test_run_liveness.py::test_live_reconnect_that_missed_a_hint_gets_one_resync_and_no_replay`
  (`assert [] == ['run.final']`), a timing test this diff does not touch; it passed alone twice and in
  `pytest tests/test_run_liveness.py tests/test_chat_api.py tests/test_document_records.py` (99 passed). The 55-07
  review saw the same test fail under load. Counted as a pre-existing flake (n2), not this change.
- `.venv/bin/ruff check genesis` → All checks passed.
- playwright-appian, genesis-workflows, kiro-agent-sdk gates: N/A (nothing under those trees changed; the
  `browser-testing` area was matched only by `scripts/probes/phase55-09-*`).

## Checklist

`genesis-ctx check --since 1f8fd8b5 --repo genesis` mapped 103 files (incl. `web/static`) to 10 areas; most ADR and
lesson lines come from broad area tags and do not touch this diff. Each is answered.

### ADRs
- [N/A] ADR-001 — no control-flow change; Resolve agent only proposes, program code applies (`hooks.ts` `useResolveAction` routes).
- [N/A] ADR-002 — no ACP/turn code changed.
- [OK] ADR-003 — local web app; no new external surface.
- [N/A] ADR-004 — no MCP injection change.
- [N/A] ADR-005 — no registry change.
- [N/A] ADR-007 — no role gating.
- [OK] ADR-008 — product UI only; mockup route keeps re-exporting `ACTIONS` (`fixtures.ts:318`).
- [OK] ADR-009 — the three HITL modes stay: GatePanel kept for approval/pre_mutation/review and legacy escalations (`HitlBar.tsx:191-196`, test `run-detail-hitl.test.tsx:184`); pause/fork/edit-state untouched.
- [OK] ADR-010 — no bulk in state; the fix diff is read from files (`useFixTexts`).
- [N/A] ADR-011 — no agent node added.
- [OK] ADR-012 — the app imports no workflow Python; `documents.py` change is a view field.
- [N/A] ADR-013 — no config UI.
- [OK] ADR-018 — `nodes` is a pointer list on a document record (`documents.py:199-201`).
- [N/A] ADR-019 — no core-major change.
- [N/A] ADR-020 — no Kiro config.
- [OK] ADR-021 — no gate auto-answered; a standard escalation is answered only by a confirmed action.
- [OK] ADR-022 — files stay under the artifacts root; session outputs confined by `_session_output_path` (`run_routes.py:385-390`), escapes tested (`test_chat_api.py:105-122`).
- [N/A] ADR-023 — no server change of kind.
- [N/A] ADR-024 — no engine change.
- [OK] ADR-025 — restart-from goes through `runsApi.restartFrom` (fork, new run); original untouched.
- [N/A] ADR-026 — no bind change.
- [OK] ADR-027 — Radix Tabs/Dialog, TanStack Query, shared primitives (`Button`, `RowMenu`, `SegmentedControl`, `SearchInput`), token colours.
- [OK] ADR-028 — all calls via `runsApi`/`resolveApi`/`chatApi`; no `/api` or `fetch` in components (grep clean).
- [N/A] ADR-029 — no trust change.
- [N/A] ADR-030 — no persistence change.
- [OK] ADR-031 — Resolve chat writes only drafts in its sandbox; the page reads them through the session-output routes.
- [OK] ADR-032 — "This chat" from `/resolve` `credits` with provenance; header total adds it and turns partial when the chat is not metered (`RunDetailPage.tsx:129-133`). Screenshot `resolve-first-turn-1440-light.jpg` shows 0.75 metered.
- [OK] ADR-033 — every action needs a dialog Confirm (`ActionDialog.tsx`); landing on `/resolve` never POSTs `/resolve` (test `resolve.test.tsx:375`, bell test).
- [OK] ADR-034 — the draft is in `resolve-<run_id>` sandbox (`drafts/`).
- [N/A] ADR-035 — no upload change.
- [N/A] ADR-037, ADR-040, ADR-041, ADR-042, ADR-043, ADR-044 — not touched.
- [OK] ADR-045 — the reused chat pieces are the Chat page's own (`ChatThread.tsx` exports, `Composer`, `useChatTurn`); see M1 for a gap in that reuse.
- [N/A] ADR-046, ADR-047 — not touched.
- [OK] ADR-049 — no nav change.
- [N/A] ADR-050 — no lifecycle transition in this diff (relaunch/restart rebinding is 55-08 backend).
- [N/A] ADR-051, ADR-052, ADR-053, ADR-054 — not touched.
- [OK] ADR-055 — tokens + Tailwind + shadcn-style primitives; no MUI.
- [N/A] ADR-056 … ADR-065 — feature/Hub/workbench rules not touched.
- [OK] ADR-066 — prompts listed per step with "Turn k · item" labels from the server (`documents.test.tsx:170`).
- [N/A] ADR-067, ADR-068 — no healing or design-object write.
- [N/A] ADR-069 — no skill provisioning.
- [N/A] ADR-071, ADR-072 — no story surface.
- [N/A] ADR-073, ADR-074, ADR-075, ADR-076 — not touched.
- [OK] ADR-077 — reviewer used `genesis-ctx`; no bulk docs read.
- [N/A] ADR-078, ADR-079, ADR-080, ADR-081, ADR-082, ADR-083, ADR-084 — not touched.
- [N/A] ADR-085 — no report serving change.
- [N/A] ADR-086, ADR-087 — not touched.

### Lessons
- [N/A] L-001, L-004, L-008, L-009, L-012, L-013, L-019, L-020, L-021, L-022, L-023, L-024, L-025, L-026, L-027, L-031,
  L-033, L-040, L-041, L-042, L-043, L-044, L-045, L-046, L-047, L-048, L-050, L-051, L-054, L-057, L-058, L-059, L-061,
  L-062, L-063, L-064, L-065, L-067, L-071, L-072, L-073, L-075, L-076, L-081, L-082, L-084, L-085, L-086, L-087, L-088,
  L-091, L-092, L-093, L-095, L-097, L-098, L-099, L-100, L-101, L-103, L-104, L-105, L-107, L-108, L-112, L-113,
  L-114, L-115, L-116, L-117, L-118, L-119, L-121, L-124, L-125 — none of their code paths changed (diff is the web
  feature, one view field, two route signatures). Probe scripts use no `npx` (L-101: `phase55-09-pages.mjs` imports
  only `node:*`); seed refuses an unset `GENESIS_STATE_DIR` (`phase55-09-seed.py:28-30`).
- [OK] L-003 — no SSE client lifecycle change; the session stream is aborted on unmount (`resolve/hooks.ts` `return () => ac.abort()`).
- [OK] L-005 — no new event kinds.
- [OK] L-006 — Documents labels steps from `/documents` steps then the topology (`run-docs.ts` `stepLabeller`).
- [OK] L-007 — the conversation uses `AssistantBlock`/`LiveAssistant` (buildTranscript); no new renderer.
- [OK] L-010 — client prepends `/api`.
- [OK] L-011 — `RunDocument.nodes?` added to the type and the Exact contract test (`phase55-contract.test.ts:84,206`); backend test asserts it (`test_document_records.py:374-375`).
- [OK] L-014 — jest-axe on documents (`documents.test.tsx:209,321`) and resolve (`resolve.test.tsx:160,185,280`); no new ambient decls.
- [OK] L-015 — no heavy lib added; LCS diff is in-house, capped at 2000 lines (`actions.ts` `DIFF_MAX_LINES`).
- [OK] L-016 — credits real (ADR-032 line).
- [N/A] L-017 — no trust set.
- [N/A] L-018 — no SSE parser change.
- [OK] L-030 — web files changed; frontend job will run.
- [OK] L-034 — graph unchanged.
- [OK] L-039 — `nodes` added in the one fold that serves the list (`DocFold`), no single-get variant.
- [OK] L-055 — big-doc handling unchanged (`DocumentPreview` reused, truncation kept).
- [OK] L-056 — every source file is in f9f126c2/8620f7fc; tree clean.
- [OK] L-060 — Documents is not event-derived; read from `/documents`.
- [OK] L-066 — Documents is a server fold; client groups only (`groupByStep`), no event-log replay.
- [OK] L-068 — not touched.
- [OK] L-069 — no `Button asChild` (grep clean in `resolve/`, `docs/`, `RunDetailPage.tsx`; links use `buttonVariants`).
- [OK] L-074 — not touched.
- [OK] L-083 — fixtures use the real shapes (golden fixtures from 55-08).
- [OK] L-089 — bundle commits separate and verified (`git show --stat`), rebuild identical.
- [OK] L-090 — real-browser probe at 1280/1440/1920 × light/dark, 71 entries, evidence in `evidence/55-09/` (reviewer looked at `resolve-first-turn-1440-light.jpg`, `docs-by-step-1440-dark.jpg`).
- [OK] L-094 — `runPillStatus` reaches all three pill sites (RunDetailPage, RunsTable, WorkflowDetail; grep `StatusPill status={r.status}` finds no other run pill); removed `useRunArtifacts`/`qk.runs.artifacts`/`showToolOutputs` have no remaining readers (grep). Gap: the reuse of `useChatTurn` did not cover the Genesis-authored turn (M1).
- [OK] L-096 — `.../outputs/{name:path}/download` before `.../outputs/{name:path}` (`run_routes.py:394-400`), proven by behaviour (`test_chat_api.py` download of `drafts/fix.html`); SPA `runs/:runId/resolve` before node/docs (`router.tsx:77`, test `resolve.test.tsx:369`).
- [OK] L-106 — disabled actions show the server's `allowed` reason as is (`actions.ts` `blockedReason`; test `resolve.test.tsx:165,329`); a 409 shows the server's words (`:248`).
- [OK] L-109 — `ACTIONS` has one home (`resolve/actions.ts`), the mockup re-exports it.
- [OK] L-110 — counts above are from runs at head 9f7f0688.
- [OK] L-111 — live acceptance done only on a scratch server (one agent turn, one Confirm); wider live checks listed under Not checked.
- [OK] L-120 — results follow `new_run_id` / `run_id` (`useResolveAction`; tests `resolve.test.tsx:216,231,301`).
- [OK] L-122 — no new event kind.
- [OK] L-123 — no opacity modifier on a var() token in new code (grep). The pre-existing `bg-surface-2/40` on `HitlBar.tsx:190` is untouched.

### Gates
- [OK] genesis pytest — 2379 passed + 1 pre-existing flake (see Gates).
- [OK] genesis ruff — clean.
- [OK] web lint / typecheck / vitest — 0 errors / clean / 1010 passed.
- [OK] web build — fresh build identical to committed `web/static`.
- [N/A] playwright-appian lint/typecheck/test/build; genesis-workflows validate/pytest; kiro-agent-sdk pytest — trees unchanged.

## Findings

### Blockers
none

### Majors

- M1 **The Resolve composer loses what the person types while the agent's first turn runs, and its Stop does
  nothing** (`ResolveTab.tsx` composer block, `streaming={live.streaming || stream.length > 0}` with
  `onSteer={(t) => void live.steer(t)}` and `onStop={live.stop}`; `chat/hooks.ts:224-226, 259`).
  What: during the Genesis-authored first turn the Composer is in streaming mode because `stream.length > 0`, but
  `useChatTurn` did not open that turn, so its `busyRef` is false. Problem: the person opens Resolve; the first turn
  runs (the live one took long enough to cost 0.75 credits). They type "check section 4 too" and press Enter →
  `steer` sees `!busyRef.current` and calls `send` → `POST /chat/sessions/resolve-<id>/turn` → 409 "a turn is already
  in progress for this session" (`api/chat.py:264-265`). `send`'s `finally` then clears the live events and the
  pending bubble, so the error flashes and the text is gone (not handed back to the composer). Pressing Stop returns at
  `if (!busyRef.current …) return` and the turn keeps running. No test types during a Genesis turn.
  Fix (smallest): while `stream.length > 0`, call `chatApi.steer(sessionId, t)` for onSteer and
  `chatApi.cancel(sessionId)` for onStop (both are session-level routes), or keep the composer disabled with "The
  agent is reading this run…" until the first answer is stored. Add a test: a Genesis-turn event on the session stream,
  type + Enter, assert no `POST …/turn` and (for the first option) one `POST …/steer`.
  If skipped: a person's first message in Resolve is often silently dropped, and the visible Stop button is a no-op
  on the one turn that is started for them and metered.

### Minors

- m1 **The tab body goes blank after leaving `/resolve` when the Resolve tab is no longer offered**
  (`RunDetailPage.tsx`: `showResolve = atEscalation || resolveOpened || onResolveRoute`; the `[onResolveRoute]` effect
  only sets "resolve", never resets). Case: the bell's needs_you link → `/runs/X/resolve`; the person resolves with a
  manual Accept without opening the agent; the run moves on. They click the breadcrumb "esc" → `/runs/X`. The same
  RunDetailPage instance keeps `tab === "resolve"`, `showResolve` is now false, so no TabsTrigger/TabsContent matches
  and the page shows an empty body under Flow / Documents (neither selected). Fix: include `tab === "resolve"` in
  `showResolve`, or in the route effect `else if (tab === "resolve" && !showResolve) setTab("flow")`.
- m2 **A result card from an earlier escalation shows under a new one** (`ResolveTab.tsx` `lastConfirmed` and the
  local `outcome` state are not keyed by gate occurrence). Case: confirm a retry proposal at `gate_seq` 1; the step
  fails again and escalates (`gate_seq` 2). The tab shows the new findings and cards, and still "Retrying Draft with
  your guidance · … if it escalates again, Resolve shows the new findings here". Fix: when `esc` exists, take
  `lastConfirmed` only from proposals with `p.gate_seq === esc.gate_seq`, and clear `outcome` when `esc?.gate_seq`
  changes.
- m3 **The viewer can show an older write under a header that says "latest"** (`DocumentViewer.tsx` →
  `useArtifactContent`, key `(run, name, mode)`, global `staleTime: 30_000`, never invalidated by the documents
  re-read). Case: a live run with a verify→revise loop; the person views `draft.md`; the step writes it again. The
  header updates ("Writes 2 times (latest shown)", Written "just now") but the body keeps the first write until a
  remount. The caching predates 55-09; the new header makes it a wrong statement. Fix: add `doc.written_at` to the
  content query key (pass it in from `DocumentsTab`), or invalidate `["run", id, "artifact"]` in `useRunLive`'s flush.
- m4 **D12 n3 "OK · check failed N times" is not built** (author's choice 5). It is a user-approved item (D12, 55-09
  §1). The author's reason holds for the current contract, but the data is close: the snapshot fold already reads
  `validator.result` (`runs/snapshot.py:41`) and could count `ok=false` per node. This needs the user's explicit
  acceptance of the deferral, recorded in As built and in `specs/backlog/` (or the small snapshot count added).
- m5 **The fix diff treats an unreadable run file as empty** (`ActionDialog.tsx` `FixDiff`: `before.data?.content ?? ""`).
  Case: the output is over the `full` limit (413) or binary (415); `before` errors and the dialog shows the whole draft
  as added lines, which reads as "the file was empty". Fix: when `before.isError` and its status is not 404, show
  "the current file cannot be compared here" instead of a diff.

### Nits

- n1 For a standard escalation `HitlBar` still renders its wrapper (`border-b … px-4 py-3`) with nothing inside, an
  empty band in the inspector (`HitlBar.tsx:189-196`). Return `null` for the whole bar in that case.
- n2 `test_run_liveness.py::test_live_reconnect_that_missed_a_hint_gets_one_resync_and_no_replay` fails under full-suite
  load (seen here and in the 55-07 review), passes alone. Not this change; worth a backlog line so it stops costing
  reviews.
- n3 Manual Fix lists drafts from every `fix_accept` proposal, including dismissed, stale and superseded ones
  (`ResolveTab.tsx` `fixes`). Show the proposal status in the picker label, or offer only the newest per `path`.

## The author's open choices

1. Composing Resolve from the chat's exported bubbles, `Composer` and `useChatTurn`: acceptable and within "no second
   chat UI"; it is the cause of M1, which needs the gap closed.
2. `nodes` on `_parallel` and `{name:path}` routes: acceptable; both tested, traversal still refused, route order proven.
3. Manual Fix offers only agent-proposed drafts: acceptable (spec: "Manual Fix needs the Resolve chat"); see n3.
4. Manual results are page state: acceptable as built, since the run record carries the outcome; m1 is the visible
   edge of it.
5. n3 not built: see m4, needs the user.
6. Facts sidebar without Feature/Stage: acceptable for now (no binding in the client contract); note it in As built.
7. Steps groups open when ≤ 3 or holding the selection: acceptable.
8. Live first turn on a standard gate only: acceptable for cost; the legacy-gate path stays unchecked live (below).

## Not checked

- A live Resolve on a legacy escalation gate (an agent-prompt run): only the unit test of the computed action map.
- A reload during the first turn: whether the notification stream replays the in-flight Genesis turn's events (unit
  tests only cover the stream after mount).
- Relaunch / restart rebinding of a real feature stage or story (no bound run on the scratch server).
- The reviewer did not drive the scratch server on :8790; visual check limited to two of the 71 screenshots
  (`resolve-first-turn-1440-light.jpg`, `docs-by-step-1440-dark.jpg`), both consistent with the mockup.
- m1 was found by reading (React Router keeps the same element instance across sibling routes); not reproduced in a
  browser.

## Verdict: NEEDS_CHANGES

Fix M1 with its test. m1–m3 and m5 are small and worth doing in the same round; m4 needs the user's decision.

---

## Re-run 1 — base 9f7f0688, head 69faabb1 (genesis-review, 2026-11-24)

Commits: b5c4e6f0 (7 web source/test files: `RunDetailPage.tsx`, `DocumentViewer.tsx`, `ActionDialog.tsx`,
`ResolveTab.tsx`, `resolve/hooks.ts`, `documents.test.tsx`, `resolve.test.tsx`; no backend file) and 69faabb1
(66 files, all under `web/static`). `git log 9f7f0688..HEAD` lists only these two.

### Gates (run by the reviewer at 69faabb1)

- `npm run lint` → 0 errors, 20 warnings (baseline). `npm run typecheck` → clean.
- `npx vitest run` → **85 files, 1017 passed** (1010 + 7 new; matches the author).
- Stale bundle: `npx vite build --outDir /tmp/rv-55-09-r1b/static`, `diff -r` against `web/static` → identical;
  `git status --short --untracked-files=all` empty.
- Fail-first, reproduced in a scratch copy (`git archive b5c4e6f0 web` into `/tmp/rv-55-09-ff`, the five source files
  replaced by their 9f7f0688 versions, the repo tree untouched): the six new tests fail (M1 ×2, m1, m2 "earlier
  escalation", m3, m5); "m2: the result of this occurrence is shown after a reload" passes on the old code too, as a
  positive control should. 6 failed / 52 passed in the two files.
- Backend: no file changed since 9f7f0688, so the round-1 pytest/ruff results stand.

### Findings, round 1 → now

- **M1 — fixed.** `ResolveTab.tsx` derives `genesisBusy = !live.streaming && (stream.length > 0 || last stored message
  is the resolve.seed)`. While busy, Send and Steer go to `chatApi.steer(sessionId)` and Stop to
  `chatApi.cancel(sessionId)`, both session-level routes, so no second turn is started. A refused steer removes the
  pending bubble and hands the text back through the composer's `draft`. I checked the end condition against the
  backend: `stream_turn` always appends the assistant message in its `finally`, on error and cancel too
  (`chat/manager.py`, the shielded block), and `useResolveStream` clears its events only after the session re-read.
  After the turn ends, the last message is therefore the assistant's and `genesisBusy` drops, including after the new
  Stop. Tests: `resolve.test.tsx` "review M1 …" ×2 (one `/steer`, then `/cancel`, no `/messages`; a 409 steer leaves
  "keep this" in the box). A narrower gap remains (m6 below).
- **m1 — fixed.** The `[tab, showResolve]` effect in `RunDetailPage.tsx` resets to Flow. Route test "review m1".
- **m2 — fixed.** `lastConfirmed` is filtered to `p.gate_seq === esc.gate_seq`, and the in-page outcome carries
  `gateSeq` and hides under another occurrence. When no live gate exists, any occurrence's result shows, which is right
  after the run moved on. Tests "review m2" ×2.
- **m3 — fixed.** `DocumentViewer` refetches the content when `doc.written_at` changes. Test "review m3" uses the same
  QueryClient, so only the new `written_at` can cause the second read. Switching to another document also triggers
  one extra read of that document, which costs one GET and is harmless.
- **m4 — not built; open item, not a blocker.** D12 n3 ("OK · check failed N times") is a user-approved display
  item. Its absence loses no data and breaks no flow: the step's check failures stay visible in the step's events and in
  the escalation findings. It may ship as a recorded open item **only if the user accepts the deferral explicitly**,
  with that acceptance written in 55-09 As built and a line in `specs/backlog/` (the snapshot fold already reads
  `validator.result`, `runs/snapshot.py:41`, so it is a small later change). If the user does not accept, it must be
  built before release, and this verdict does not cover that build.
- **m5 — fixed.** `FixDiff` shows "The current <path> cannot be compared here (<message>)" for any error other than
  404. Test "review m5" (413).
- **n1 — withdrawn.** For a standard escalation the wrapper still holds the Mode-3 row (Edit state, Fork, Cancel run),
  as `evidence/55-09/resolve-flow-strip-1440-dark.jpg` shows. My round-1 reading was wrong.
- **n2 — for the backlog** via As built, as planned.
- **n3 — fixed.** The `fixes` filter now requires `p.status === "proposed"`. There is no test for it, which is acceptable
  for a nit.

### New in this round

- **m6 (minor) — mid-turn the "busy" signal can still be lost, and a steered line can show twice.** `genesisBusy`
  relies on the cached last message being the seed, or on Genesis-turn events having arrived since mount. A steer is
  stored as a `user` message (`meta.kind = "steer"`, `ChatSession.steer`) once the engine queues it. If the session is
  re-read during the first turn, the cached last message becomes that steer. A re-read happens on a `resolve.note`,
  for example after a manual action confirmed during the turn, or on a remount after leaving the Resolve tab for more
  than 30 s. If `stream` is also empty at that moment (just after a remount, before the next event arrives), then
  `genesisBusy` is false and Send takes the old path: `POST /messages` returns 409 and the text is lost (round-1 M1).
  The same re-read shows the stored steer as a `UserBubble` and the local "sent during the turn" bubble at once.
  Smallest fix: treat the first turn as running while no `assistant` message follows the last seed (in the cached
  messages), and drop a local steered line once a stored `kind: "steer"` message with that text appears. Add a test
  with messages `[seed, steer]` and no stream events: assert Send goes to `/steer`. This is narrow (it needs a steer, a
  re-read and a silent stream window together) and does not block SHIP. Record it in As built or fix it in a follow-up.

### Checklist delta

Re-checked only the lines this diff touches; all others stand from round 1.
- [OK] ADR-028: the new calls go through `chatApi.steer`/`chatApi.cancel`, and no component uses `fetch` or `/api`.
- [OK] ADR-033: steer and cancel are chat-turn controls, not run mutations. Every action still needs a dialog Confirm.
- [OK] ADR-045: the composer reuse is now complete for the Genesis-authored turn (Send, Steer and Stop all work).
- [OK] L-011: no contract type changed (`ActionOutcome.gateSeq` is page-local).
- [OK] L-056 / L-089: source in b5c4e6f0 and bundle in 69faabb1. The rebuild is identical and the tree is clean.
- [OK] L-094: the consumers of the changed props were checked. `Composer` `draft` is now fed from local state that
  mirrors `live.draft`, and `Conversation` gained `steered`, which has one caller.
- [OK] L-106: a refused steer leaves the person's text in place. A disabled action still shows the server's reason.
- [OK] L-110: the counts above come from runs at 69faabb1 and from the fail-first copy.

### Not checked (this round)

- No live re-run in a browser: M1's steer and cancel during a real first turn were verified by unit tests only (MSW).
  When live acceptance resumes, type during the first Resolve turn and press Stop on a scratch server.
- The round-1 Not checked items still stand (legacy-gate live Resolve, reload during the first turn, relaunch/restart
  rebinding on a bound stage).

### Verdict: SHIP

This verdict holds on one condition: the user explicitly accepts the m4 deferral, and that acceptance is recorded in
As built and in `specs/backlog/`. If the user declines, m4 is built first and reviewed. Record m6 and n2 as follow-ups.
