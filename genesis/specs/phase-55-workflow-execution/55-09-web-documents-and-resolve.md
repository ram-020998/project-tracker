# 55-09 — Web: the Documents tab revamp and the Resolve tab

> **Status:** BUILT 2026-11-24 (review SHIP at re-run 1, conditional on the D12 n3 deferral; As built below).
> SPEC-DRAFTED 2026-11-22. Repo: genesis (`web/src/features/run-detail/`, `web/src/features/chat/`,
> `web/src/features/notifications/`). Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**.
> Decisions: D7, D8, D9, D12–D15 (`55-01-findings.md`). The 55-02 mockups are **approved** (D12, at genesis `d0aa1b2`):
> build what `/dev/phase-55` shows, with D13–D15.

## 1. Documents tab (`components/docs/`)

- Replace the flat rail (`DocumentsTab.tsx:74-165`) and the filename "Result" regex (`doc-utils.ts:20`) with the
  approved layout, fed only by `GET /runs/{id}/documents` (55-05/55-08): search; **By step** (default) / **By type**
  toggle (persisted pref); groups Output (pinned, auto-selected) · Inputs · Steps in graph order (files, check pass/fail,
  "Prompts (n)") · Tool outputs (metadata; "files removed at the end of the run" once gone, D9) · System (collapsed).
- Row: label, file name, step, relative written time (exact on hover), size, "written N times · latest" only when
  `writes > 0` (0 = unknown on old runs: show nothing; tooltip: earlier writes are not kept, D12); "being written"
  for a zero-byte file during its node (`writing`, true only while the run is running, 55-08). The memory brief sits under
  Inputs with the step "Run start (before the first step)"; System is kept, collapsed, in By type too (D12).
- Pseudo-steps from 55-05/55-06: `_launch` files (uploads, a test checkout) under Inputs as "Run start"; `_memory`
  (the brief); `_resolve` as "Fixed in Resolve"; `_parallel` rows named with their nodes and no step. Prompt labels
  "Turn k · <item>" as built. A list-form workflow (no roles declared) still shows each file's step.
- **System files are listed but neither previewed nor downloadable** (`_kiro/`, `.kiro/`, `.pids/`, `checkout/`):
  `_kiro/` holds the run's Kiro home (settings, sessions, logs), not yet confirmed free of secrets (55-05 review).
- A validator step whose check failed reads "OK · check failed N times" (D12 n3).
- Viewer header: category, step · pass · attempt, written time, size, write count, **Open in step** (selects the node
  in the graph inspector), Download; the existing previews (`DocumentViewer.tsx`, `DocumentPreview`) unchanged; agent
  HTML keeps its sandboxed frame / CSP (54-10 §1 9b).
- Old runs: name-rule categories, "step unknown", the one-line note (F12).
- Polling: refetch while active on the same rhythm as the graph — on each `/live` lifecycle hint (a `node.completed`
  is when a node's files are diffed, 55-05) and the 3 s poll floor — never per keystroke; no new hint kind.

## 2. Resolve tab (D14)

- A **Resolve** tab in Run Detail beside Flow and Documents, with the facts sidebar on the right, as approved in
  `/dev/phase-55` (genesis `d0aa1b2`); reached at the SPA route `/runs/:runId/resolve` (registered before any generic
  run route, L-096). Shown when the run waits at an escalation gate, and kept readable afterwards for the history.
  Key it on `snapshot.run.status`, `snapshot.run.gate` (which carries the 55-06 payload) and `active_nodes` from
  55-03's `useRunSnapshot`; do not add a second poll of the run.
  The run pill of a run waiting at an escalation gate reads "Needs you" (D12 n1): change `statusMeta` for the
  escalation-gate case (55-03 left it unchanged).
- Not opened yet: the summary strip (failed step, one-line reason, **Open Resolve**) → `POST /runs/{id}/resolve`.
- The first turn runs in the background (55-07): read it, the proposals and the notes from the session's
  notification stream; on reload, rebuild from `GET /chat/sessions/{sid}` (system messages with `meta.kind`) and
  `GET /runs/{id}/resolve`. Cards **and the manual menu** follow `GET /runs/{id}/resolve/escalation`'s **live**
  `allowed` — never the snapshot's copy, which is taken when the gate is raised (55-08 n1); Confirm may edit only the
  guidance, the instructions or the reason; a restart card names a step from `steps`; follow `run_id` / `new_run_id`
  (L-120). Clients as built in 55-08 (its As built's contract table is the one home for the shapes): `resolveApi.open`
  → `chatApi.streamNotifications<ResolveStreamEvent>(session_id, …)` and `chatApi` messages; manual actions through
  `runsApi.respond` (action dicts), `fixAndAccept`, `relaunch`, `restartFrom`. **Manual Fix needs the Resolve chat**
  (its draft comes from there): offer it only once Resolve is open, else say so. Show 409 reasons as is (they say where
  to start the run instead, D23).
  An old library gate (no F6 fields) gets a computed action map without Fix then accept (55-07).
- The conversation reuses the chat components (`ChatThread`, composer, the turn stream) bound to the Resolve session;
  no second chat UI.
- **Proposal cards** from `resolve.proposal` events: action, parameters (editable guidance text for retry; an
  **instructions** text box for "Rerun from the start with additional instructions" — no input form, the run's inputs
  are reused, D13; the step picker for restart from a step; the diff for fix-then-accept; the reason for stop),
  rationale, Confirm / Dismiss; stale and superseded states. Labels and hints as the mockup's `ACTIONS`.
- **Manual action menu**: the six actions without the agent, same dialogs, same routes.
- Unavailable actions disabled with their reason from `allowed` (L-106). Stop and fix-then-accept use a confirm
  dialog. The relaunch and restart-from dialogs say that the feature stage (or story) moves to the new run and that
  this run ends Cancelled and links to it (D13, D15).
- After an action: its result shown **inside the Resolve tab** (D14) — the outcome note in the thread and the result
  card as mocked, with a link to the new run for relaunch and restart from a step; the graph and Documents refresh
  through 55-03. The restart dialog lets the user pick **the step to restart from** (D21); when `allowed.relaunch` /
  `allowed.restart_from` carry a reason (a workflow not `relaunchable`, D23 — e.g. story-implementation: "Re-run it
  from the Implementation lane" — or a queue-managed one), Rerun and Restart show disabled with that reason. A stopped run's graph shows the gate's `<gate>_stop` step.
- Credits of the conversation shown in the tab ("This chat") with provenance, and included in the run header's total
  (ADR-032, D12).
- The legacy gate panel (`hitl/HitlBar.tsx` `GatePanel`) stays for approval / pre_mutation / review gates and for a
  legacy escalation payload; Feedback there maps to retry with guidance (55-06).

## 3. Bell

The `needs_you` escalation notification (55-07) links to `/runs/<id>/resolve`; opening it does not start the agent
(opening Resolve does), and it shows as read once the gate is answered (D12 item 8).

## 4. Tests and probes

Vitest per state of 55-02 (documents: live, finished, old run, no output, several outputs; resolve: not opened, first
turn, proposals, each confirm, stale, unavailable, each action's result in the tab); the `/runs/:runId/resolve` route;
jest-axe on each new view (L-014); a real-browser width probe at
1280 / 1440 / 1920 px, light and dark, for the Documents list and the Resolve tab, screenshots in As built (L-090);
token colours only (L-123); no `Button asChild` (L-069).

## 5. Gates

`cd genesis/web && npm run lint && npm run typecheck && npm test`; `npm run build`, then commit `web/static/` as a
separate step, checked with `git show --stat <sha> -- web/static` after the build settled (L-089).

## Context manifest

```toml
areas    = ["web-runs", "web-shell", "chat"]
adrs     = ["ADR-009", "ADR-027", "ADR-028", "ADR-032", "ADR-033", "ADR-055", "ADR-066"]
lessons  = ["L-007", "L-011", "L-014", "L-015", "L-069", "L-089", "L-090", "L-096", "L-106", "L-123"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/55-02-mockups.md"]
code     = ["genesis/web/src/features/run-detail/**", "genesis/web/src/features/chat/**", "genesis/web/src/features/notifications/**"]
upstream = ["55-02", "55-03", "55-05", "55-07", "55-08"]
```

## As built

**Status:** BUILT 2026-11-24, review **SHIP** at re-run 1 (`reviews/55-09-review.md`), **on one condition: the user
accepts the D12 n3 deferral (m4, below)**. Repo genesis, branch master, base `1f8fd8b5`, head `a09c5fbe`, 8 local
commits (not pushed, not tagged). No migration (DB v30), no genesis-core or kiro-agent-sdk change (`CORE_MAJOR` 1).

### Commits (genesis)

| sha | what |
|---|---|
| `f9f126c2` | source, tests, probe seed + page scripts |
| `b023e73e` | `web/static` for f9f126c2 (69 files) |
| `8620f7fc` | fixes found by the real-browser probe (the Flow panel's `flex` overrode Radix `hidden`; tab dot; HitlBar; dialog text) + a test |
| `9f7f0688` | `web/static` for 8620f7fc (66 files) |
| `b5c4e6f0` | review round 1: M1, m1, m2, m3, m5, n3 + tests |
| `69faabb1` | `web/static` for b5c4e6f0 (66 files) |
| `362f8a7a` | review re-run 1 m6 + test |
| `a09c5fbe` | `web/static` for 362f8a7a (66 files) |

Bundle proof (L-089), every bundle commit: `git show --stat <sha> -- web/static` in its own call after the build
exited, then a rebuild in a later call left `git status --short --untracked-files=all` empty. The reviewer's
out-of-tree build was identical at 9f7f0688 and 69faabb1.

### Changed

- **Documents (§1)** `web/src/features/run-detail/components/docs/`:
  - `run-docs.ts` (new, pure): `whereOf` (pseudo-steps `_launch` "Run start", `_memory` "Run start (before the first
    step)", `_resolve` "Fixed in Resolve", `_parallel` "In parallel: A, B", null "Step unknown"), `groupByStep` (Output ·
    Inputs · the server's steps in graph order · Other files · System), `TYPE_ORDER`, `matchDoc`/`matchTool`,
    `stepLabeller` (documents' steps, then topology), `defaultSelection`.
  - `DocumentsTab.tsx` rewritten on `RunDocuments`: search, By step / By type (`stores/prefs.ts` `docsView` in
    localStorage), Output pinned and auto-selected (also once it appears on a live run), step groups with "Prompts (n)"
    and Passed/Failed, tool outputs as records (`TOOL_PAGE` 50 + Show all; a live file opens, a purged one shows its
    record and Open in step), System collapsed, the legacy note. "written N times · latest" only for `writes > 1`;
    "being written" only from `writing`.
  - `DocumentViewer.tsx`: header with the record (category, step · pass · attempt · execution, item, written, size,
    writes), Open in step, Download; a System file is never fetched or downloadable; a `writing` file shows a
    placeholder; a 403 shows "Not shown"; the content is read again when `written_at` changes (m3). Previews unchanged.
  - `doc-utils.ts` deleted (the "Result" regex). Removed with no remaining reader: `useRunArtifacts`,
    `qk.runs.artifacts`, `useUiPrefs.showToolOutputs`.
  - `hooks.ts` `useRunDocuments` (3 s poll while active, newest `version` kept); `useRunLive`'s flush also invalidates
    `qk.runs.documents` and (on gate/final hints) `qk.runs.resolve`.
- **Resolve (§2)** `web/src/features/run-detail/components/resolve/` (new):
  - `actions.ts`: `ACTIONS` (their one home; `dev/mockups/phase55/fixtures.ts` re-exports them), `ACTION_ICON`,
    `iconOf`, `actionMeta`, `liveEscalation`, `blockedReason`, `editableParam`, `extrasOf`, `FIX_NEEDS_RESOLVE`,
    `diffLines` (LCS, folds unchanged runs, null over `DIFF_MAX_LINES` 2,000).
  - `hooks.ts`: `useResolveSummary`, `useResolveEscalation` (live `allowed` and `steps`), `useOpenResolve`,
    `useResolveStream` (session stream: Genesis-turn events kept until stored, `resolve.proposal` merged into the
    summary cache, `resolve.note` re-reads), `useResolveAction` (proposal confirm or the manual route; returns the run to
    follow), `useDismissProposal`, `useFixTexts`.
  - `ActionDialog.tsx`: the six dialogs + extra options; Confirm edits only the action's text; server words on refusal;
    `FixDiff` (an unreadable run file is not diffed as empty, m5).
  - `ResolveTab.tsx`: `ResolveStrip` (also above the Flow graph), the not-opened body (gate facts, F6 history, file
    chips into Documents, the six actions with live reasons), the opened body (the chat's own `UserBubble`,
    `SystemNudge`, `AssistantBlock`, `LiveAssistant` exported from `ChatThread.tsx`, `Composer`, `useChatTurn`; cards
    placed after the turn that made them; "This chat" credits; the manual RowMenu), the facts sidebar, `ResultCard`
    keyed by gate occurrence. While the Genesis first turn runs, Send/Steer go to `/steer` and Stop to `/cancel` (M1, m6).
  - `RunDetailPage.tsx`: Resolve tab (shown at an escalation gate, once opened, or on the route), `useMatch` for
    `/runs/:runId/resolve`, the strip on Flow, the needs-you dot, header credits including the chat (partial when the
    chat is not metered), the pill via `runPillStatus`; the tab returns to Flow when Resolve is no longer offered (m1).
  - `app/router.tsx` `runs/:runId/resolve` before `node`/`docs`; `shared/layout/breadcrumbs.ts` "Resolve".
  - `shared/ui/badge.tsx` status `awaiting_input:escalation` "Needs you"; `features/runs/hooks.ts` `runPillStatus`
    (used by RunDetailPage, RunsTable, WorkflowDetail).
  - `hitl/HitlBar.tsx`: no GatePanel for a standard escalation payload (Resolve answers it); GatePanel kept for
    approval / pre_mutation / review and legacy escalations; Mode-3 row unchanged.
  - `lib/query/keys.ts`: `runs.documents`, `runs.resolve`, `runs.resolveSummary`, `runs.resolveEscalation`,
    `chat.output`.
- **Bell (§3):** no code change needed (55-07 links needs_you notices to `/runs/<id>/resolve`); the route now exists and
  a test proves the link and that no `/resolve` POST happens.
- **Backend (small, additive):** `genesis/runs/documents.py` a `_parallel` document carries `nodes` (the view dropped
  them; the page names them); `genesis/api/run_routes.py` the session-output read and download routes take
  `{name:path}` (a Resolve draft is under `drafts/`), download registered first (L-096). `types/runDocuments.ts`
  `nodes?`; contract test updated.
- **Probe:** `scripts/probes/phase55-09-seed.py` (scratch state only; refuses an unset or fleet state dir),
  `scripts/probes/phase55-09-pages.mjs`.

### Tests

- Web: `documents.test.tsx` (31: folds; finished recorded run; System; live; tool outputs; old run; no output; several
  outputs; pseudo-steps; m3; viewer states; jest-axe By step, By type, old run), `resolve.test.tsx` (28: helpers; not
  opened; unavailable reasons; manual retry/accept/stop/relaunch/restart; 409 as is; not waiting; opened thread rebuilt;
  Confirm with edits; relaunch follows `new_run_id`; stale/superseded/dismiss; live map refuses a card; stream proposal;
  fix diff + manual fix; M1 ×2; m2 ×2; m5; m6; route order; route lands on Resolve without starting the agent; inactive
  panels carry no display class; m1; jest-axe not-opened, dialog, opened), `run-detail-hitl.test.tsx` (+1),
  `bell.test.tsx` (+1). Fail-first: each review test failed on the pre-fix source (reproduced by the reviewer).
- Backend: `tests/test_chat_api.py` (+1: nested draft read, encoded slash, download, escapes 404),
  `tests/test_document_records.py` (fan-out `nodes` on the view).
- **Gates:** web lint 0 errors / 20 warnings (baseline), typecheck clean, vitest **85 files / 1018 passed** (971 at
  55-08). genesis full pytest **2380 passed, 4 skipped** at f9f126c2's backend (scratch state; no backend file changed
  after); reviewer: 2379 + 1 failure in `test_run_liveness::test_live_reconnect_that_missed_a_hint…` (passes alone; the
  55-07 review saw the same flake under load). `ruff check genesis` clean.

### Real-browser check (L-090)

Scratch `genesis serve` on :8790, `GENESIS_STATE_DIR=/tmp/gr-55-09/live/state`, seeded with the program-only `docs` and
`esc` test workflows; all schedules paused; its `memory.db` has 0 memories (D19: no memory text can appear). Fleet
(:8760/:8761) not touched, not restarted. `node scripts/probes/phase55-09-pages.mjs --agent` at 1280/1440/1920 × light
and dark: **71 entries, 0 problems** (page sideways scroll, wrapped buttons/badges, rail spill). The probe found the
Flow-panel bug (an empty Flow panel above Documents/Resolve), fixed in 8620f7fc. With `--agent`, Resolve was opened on
one escalated `esc` run: one real first turn, **0.75 metered credits**; the agent proposed `stop` and `fix_accept`; the
first card with a Confirm (fix_accept) was confirmed, the run ended Done and `draft.json` reads "Fixed in Resolve",
writes 3. Screenshots: `evidence/55-09/` (`docs-by-step`, `docs-by-type`, `docs-prompt`, `docs-gated`,
`resolve-flow-strip`, `resolve-unopened`, `resolve-dialog-{restart,relaunch}`, `resolve-result-{stop,relaunch}`,
`resolve-first-turn` × widths × themes; `resolve-confirm-dialog-1440-light`, `resolve-confirmed-1440-light`;
`result.json`). The screenshots predate b5c4e6f0/362f8a7a; those change no layout seen there.

### Review

`reviews/55-09-review.md`. Round 1 **NEEDS_CHANGES**: M1 (typing during the Genesis first turn sent a second turn,
409, text lost; Stop did nothing), m1–m5, n1–n3. Fixed in b5c4e6f0 except m4 (deferral, below) and n1 (withdrawn by the
reviewer: the bar keeps its Mode-3 row). **Re-run 1: SHIP** with m4 conditional; its new m6 fixed in 362f8a7a (not
re-reviewed; test fail-first checked, full web suite green).

### Decisions / deviations

No ADR deviation. **Needs your decision — m4:** D12 n3 "OK · check failed N times" on a validator step is **not built**:
neither `/documents` nor the snapshot carries a validator's failure count. The reviewer judged it non-blocking (the
failures stay visible in the step's events and the escalation findings) but the SHIP holds only if you accept the
deferral; then it goes to `specs/backlog/` (a small later change: the snapshot fold already reads `validator.result`).
If you decline, I build it (snapshot count + NodeCard line) and it is reviewed.

Choices the spec did not cover (reviewer accepted all):
1. "No second chat UI": Resolve composes the chat's own exported bubbles, Composer and `useChatTurn`, plus the session
   stream for the background first turn; ChatThread itself is bound to the Chat page (copilot banner, launch dialog).
2. The two small backend additions above (`nodes` on `_parallel`; nested session-output paths).
3. Manual Fix offers only drafts the agent still proposes (no listing of `drafts/`); with none, the dialog says to ask
   the agent first.
4. Results of manual actions are page state; after a reload, a Resolve-confirmed result is rebuilt from its confirmed
   proposal of the same gate occurrence.
5. The facts sidebar omits Feature/Stage (no binding in the client contract).
6. Step groups open by default only when there are ≤ 3, or when they hold the selection.
7. The live first turn was seen on the program-only `esc` run (standard gate, `fix_accept` offered) rather than an
   `agent-prompt` run (legacy gate): cheaper, one turn, one Confirm.
8. The Flow tab's strip and the Resolve tab both show the escalation; "Open Resolve" is the only control that starts the
   agent (landing on `/resolve` from the bell never does).
9. While the first turn runs, a message is a steer of that turn (shown "sent during the turn"); a refused steer goes
   back to the composer.

### Lesson candidates

1. **A display class on a Radix tab panel overrides its `hidden`**: `TabsContent className="flex …"` kept the inactive
   Flow panel on screen as an empty block above the active tab. jsdom passed every test; only the browser probe showed
   it. Put display classes on an inner element, and pin it with a class test on the inactive panels.
2. **Reusing a chat turn hook for a turn it did not start leaves its controls dead**: `useChatTurn` only knows turns it
   opened, so a server-started (Genesis) turn made Send start a second turn (409, text lost) and Stop a no-op (review
   M1). Derive "busy" from the stored conversation, not from the hook, and route steer/stop through the session.
3. **A result shown on a page belongs to one occurrence of what it answered**: key it by the gate occurrence
   (`gate_seq`), or the next escalation reads as already handled (m2).

### Code-map changes (for genesis-docs, bible/03)

- `web/src/features/run-detail/components/docs/run-docs.ts` (new); `DocumentsTab.tsx`, `DocumentViewer.tsx` rewritten;
  `doc-utils.ts` removed. `hooks.ts` `useRunDocuments`. `stores/prefs.ts` `docsView`.
- `web/src/features/run-detail/components/resolve/{actions.ts, hooks.ts, ActionDialog.tsx, ResolveTab.tsx}` (new).
- `RunDetailPage.tsx` (Resolve tab, route, strip, credits, pill); `app/router.tsx` `runs/:runId/resolve`;
  `breadcrumbs.ts`; `badge.tsx` `awaiting_input:escalation`; `features/runs/hooks.ts` `runPillStatus`;
  `chat/ChatThread.tsx` exports its bubbles; `hitl/HitlBar.tsx` standard-escalation case; `lib/query/keys.ts` keys
  above; `features/documents/hooks.ts` `useRunArtifacts` removed.
- `genesis/runs/documents.py` `nodes` on `_parallel`; `genesis/api/run_routes.py` `/chat/sessions/{id}/outputs/{name:path}`
  (+ `/download`, registered first).
- `scripts/probes/phase55-09-seed.py`, `scripts/probes/phase55-09-pages.mjs`.

### For 55-10+

- **55-10:** once the library adopts `escalation_gate`, every Resolve tab gets the F6 facts and `fix_accept`; a legacy
  gate keeps its GatePanel in the inspector and the computed map in Resolve.
- **55-11 (live acceptance):** type and press Stop during a real first turn (M1/m6 are unit-tested only); a live Resolve
  on a legacy gate (agent-prompt); a reload during the first turn (does the stream replay in-flight events?);
  relaunch/restart with a real bound feature stage or story (the dialogs' rebinding text); the System 403 from the page.
- **Backlog:** m4 (if you accept the deferral); n2 the `test_run_liveness` reconnect flake under full-suite load.
- Cleanup for you: `/tmp/gr-55-09/` (scratch states, probe runs; the server is stopped) and the reviewer's
  `/tmp/rv-55-09*`.
