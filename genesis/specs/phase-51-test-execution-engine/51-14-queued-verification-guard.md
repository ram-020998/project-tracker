# 51-14 — Queued verification guard and the board's verification state

> **Status:** **DONE 2026-11-04** (§1–§4; genesis `9b258bb`…`a1f7f3e`, review SHIP). **§5 follow-up DONE 2026-11-04**
> (D25 amended, Q25; genesis `209297a`, `cca8ff8`, review SHIP). Repo: **genesis** (backend + web). Parent:
> `specs/phase-51-test-execution-engine.md`. Decision: 51-01 **D25**. Built **after 51-11 and before 51-12** (numbered
> 14 so the review and release sub-specs keep their numbers). Takes backlog §16 into the release.

## 1. Goal

A verification that waits in the one-at-a-time queue (F7) must never start once its card has left Verification, and
the board must show a queued verification as **Queued** (locked) instead of the neutral "Not started" 51-11 had to use.

**Why (found folding 51-11):** `StoryVerificationService._launch` (`genesis/genesis/testexec/verification_service.py:198`)
checks the workspace and readiness but not the card's lane. 51-11 leaves a queued card movable (backlog §16: the board
read cannot tell queued from never launched). Moving the card out and letting the queue start the run later writes QA
data and spends agent credits that the user withdrew by moving the card (D8: the Verification confirm is the
approval); the finalizer then ignores the result because the card is no longer in Verification.

## 2. Backend

1. **Moving a card out cancels its queued verification.** `BoardStore.move_card` and the bulk move
   (`genesis/genesis/kb/boards.py:261`, `:296`) are lane-free (any lane in `LANE_VALUES`). In the API layer that calls
   them (`genesis/genesis/api/workbench.py:172` and the bulk route), after a successful move of a card **out of**
   `verification`, cancel that story's **queued** verification execution through `ExecutionService.cancel`
   (`execution_service.py:195`) with the reason "the card left Verification before the run started". A running
   verification is unchanged (its card is already locked; out of scope). The move succeeds whether or not a queued
   execution existed; a cancel failure is logged loudly and does not undo the move.
2. **The launch re-checks the lane.** At the start of `_launch`, before readiness: if the story's card is not in
   `verification` on its board, mark the execution `cancelled` with the same reason and let the pump try the next one
   (as for a readiness refusal). This covers moves from any other path (a collaboration pull of board data, a move
   made while the server was down, the startup reconcile).
3. **Board read field.** Each card on a board read gains `verification_active: "queued" | "running" | null`, from
   `StoryVerificationService.active` semantics, computed for the whole board in one query (no per-card call). Add it
   to every board read the web uses (list and single board), one DTO builder (L-039).

## 3. Contract and web

- 51-10 contract table: the board card row gains `verification_active`; regenerate the board fixtures from real
  responses (L-011, L-083) and add the field to `web/src/types/workbench.ts`.
- Card states (51-11 §4): `verification_active == "queued"` → **Queued**, locked; `"running"` → **Verifying…**, locked
  (as today); `null` with a stage and no run → **Not started**, movable (a launch that never ran). Replace the
  `isVerificationNotStarted` heuristic with the field.
- The story page's Verification section shows a cancelled-before-start execution with its reason.

## 4. Tests

Move out of Verification cancels a queued verification (single and bulk move) and leaves a running one alone; a move
with nothing queued is unchanged; `_launch` cancels when the card is elsewhere and the pump starts the next queued
execution; the board field on list and single reads, one query; fixture parity; web card states (Queued locked,
Verifying locked, Not started movable) with jest-axe. Gates: pytest + ruff; lint, tsc, vitest; `npm run build` and the
`web/static` commit as separate steps, then a rebuild and an empty `git status` in its own call (L-089).

## 5. Follow-up: a Queued card stays movable, and dragging it out asks first (D25 amended, Q25, 2026-11-04)

§3 locked a Queued card, so the only way to withdraw a queued verification was Cancel on the execution page. The user
chose: **Queued is not locked.** Web only; the §2 backend is unchanged.
- `StoryCard` / the board's drag guard (`web/src/features/workbench/StoryCard.tsx` and the board's drop handler): a
  card with `verification_active == "queued"` shows **Queued** and is **draggable**. Only `"running"` (Verifying…)
  locks.
- Dropping a Queued card on any lane other than Verification opens a confirm dialog, reusing the board's existing
  confirm-dialog primitive (the Design/Implementation pattern, ADR-062/068): title "Cancel the queued verification?",
  body "Moving this story out of Verification cancels its queued verification. Nothing has run yet.", buttons
  **Move and cancel** / **Keep in Verification**. Confirm → the normal move route (the §2 backend cancels the queued
  execution); Keep → no request, the card snaps back. The same dialog for a bulk move that includes a Queued card
  (one dialog naming the count). Starting Design or Implementation and Remove from board, which already cancel (As
  built), get the same sentence added to their existing confirm.
- Tests: Queued is draggable and Verifying is not; the dialog on drop out, Confirm sends one move, Keep sends none;
  the bulk-move variant; jest-axe on the dialog. Gates as §4, with the `web/static` commit proven by a rebuild and an
  empty `git status` **after the build output has settled** (the 51-14 As built found the bundle can land on disk
  after the build command returns).

## Context manifest

```toml
areas    = ["stories-workbench", "runs-worker"]
adrs     = ["ADR-050", "ADR-061", "ADR-062", "ADR-068"]
lessons  = ["L-011", "L-039", "L-058", "L-061", "L-069", "L-083", "L-089", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/backlog/phase-51-follow-ups.md"]
code     = ["genesis/genesis/testexec/verification_service.py", "genesis/genesis/testexec/execution_service.py", "genesis/genesis/kb/boards.py", "genesis/genesis/api/workbench.py", "genesis/web/src/features/workbench/**", "genesis/web/src/types/workbench.ts"]
upstream = ["51-09", "51-10", "51-11"]
```

## As built (2026-11-04, genesis-dev)

**Task restated.** A verification waiting in the one-at-a-time queue (F7) must never start once its card has left
Verification (D25: moving the card out withdraws the D8 approval, so no QA data writes and no credits). Moving a card
out through the single and bulk move routes cancels that story's queued verification execution with the reason "the
card left Verification before the run started" and leaves a running one alone; `_launch` re-checks the lane and
cancels when the card is elsewhere, then the pump tries the next one. Board cards gain `verification_active: "queued" |
"running" | null`, read for the whole board in one query in the one card DTO; the board contract fixtures are
regenerated from real responses and `web/src/types/workbench.ts` updated; the card shows Queued (locked), Verifying…
(locked) or Not started (movable) from the field instead of the 51-11 heuristic; the story page shows a
cancelled-before-start execution with its reason.

**Applicable rules.** ADR-050 / ADR-061 (a board move stays a free lane assignment; cancelling an execution is not an
SDLC transition, so no `LifecycleService` call), ADR-062 / ADR-068 (the Design and Implementation confirm paths are
unchanged apart from the cancel after their move), ADR-028 (no `/api` in components), ADR-027/055 (existing primitives,
the curated `Clock` icon, tokens only). Lessons L-011 / L-083 (fixtures from real responses, real value shapes), L-039
(one DTO for list and single), L-058 (a level-triggered guard, not only the live path; failures loud), L-061 (the guard
checks the card still points at Verification before acting), L-069 (no `<Button asChild>`), L-089 (build, commit,
rebuild and status as separate calls), L-093 (tests end runs through the real `RunManager._finalize`), L-094
(consumers of the changed helpers grepped: `isVerificationNotStarted` / `isVerifying` are read only by `StoryCard`).

### Commits

- **genesis** (base `0170834`, local, not pushed or tagged): `9b258bb` feat(testexec,web,51-14) — backend, tests,
  fixtures, web source and the rebuilt `web/static` in one commit (79 files, +975 / −260); `b23337c` fix(web,51-14) —
  the story page does not repeat "before it started" for a cancel from the execution page (+ a test);
  `c74cbed` build(web,51-14) — the bundle for `b23337c`; `45e9827` fix(testexec,web,51-14) — review m1, m2, n5, n6;
  `a1f7f3e` build(web,51-14) — the bundle for `45e9827`. **L-089 recurred twice:** `b23337c` and `45e9827` were
  staged after a build that had printed "built", but their `web/static` had not yet reached the disk, so each holds
  source only (its message says "web/static rebuilt"); a `git status` right after the next rebuild read empty, and one
  read a minute later showed the 115-file bundle change. An out-of-tree build checked straight after its command
  returned also found no output folder, which was there a few seconds later. Proof for HEAD `a1f7f3e`: two out-of-tree
  builds identical to each other and to `git archive HEAD web/static`, compared after a wait; then `npm run build` and,
  60 s later in a separate call, `git status --short --untracked-files=all`: empty, with the on-disk `index-*.js` =
  the tracked one.
- **project-tracker:** this As built and `reviews/51-14-review.md`.
- genesis-workflows: no change.

### Changed (genesis)

- `testexec/execution_service.py` — `ExecutionCancelled(ExecutionError)`: a queued execution its launcher withdrew
  (already recorded `cancelled`); `pump` logs it at INFO and tries the next queued one (it is not an `error`).
  `cancel(app_uuid, key, *, reason=None, queued_only=False)` (additive): `reason` goes to `totals.cancelled` (default
  "before it started", as before); `queued_only` raises `ExecutionError` instead of cancelling the run of an execution
  that has launched meanwhile.
- `testexec/verification_service.py` — `LEFT_VERIFICATION` (the reason); `withdraw_queued(app_uuid, story_ids)` (the
  queued `verification` executions of those stories → `cancel(reason=LEFT_VERIFICATION, queued_only=True)`; one that
  launched first is skipped); `_withdraw_if_moved(ex)` (the card's lane via `BoardStore.card_lane`; not `verification`
  or not on the board → `finish(cancelled, expected_status=queued)` + `ExecutionCancelled`). `_launch` calls it first
  (before readiness) and again inside `prepare` just before `set_running`; a `StaleWriteError` from `set_running`
  because the move route cancelled in between → `ExecutionCancelled`. Raising inside `prepare` leaves no run record
  (`RunManager.start` removes the folder it created) and the stage is never bound.
- `kb/boards.py` — `_VERIFICATION_ACTIVE`: a correlated subquery in the ONE card SELECT of both `get_board` and
  `get_card` (L-039): the status of the story's `verification` execution in `queued`/`running` (matched on
  `json_extract(trigger_json, '$.story_id')`), queued first like `StoryVerificationService.active`, else NULL.
  `card_lane(app_uuid, story_id)` — a light lane read (None when not on the board).
- `api/workbench.py` — `_withdraw_queued(app_uuid, story_ids)`: after a move that leaves the cards outside Verification
  (`PATCH …/cards/{story}` with `lane != verification`; `PATCH …/lanes/{lane}` with `lane != verification`, every listed
  story), and after the Design start, the Implementation start and Remove from board. The move has already committed
  and stands; a failure is logged at ERROR with the traceback and never undoes it. When something was cancelled the
  route re-reads the card / board so the response carries `verification_active: null`. `log` added.
- Web: `types/workbench.ts` — `VerificationActive`, `BoardCard.verification_active?`, `isVerificationQueued` (Verification
  lane only), `isVerificationNotStarted` now = stage, no run, nothing active (the `draft`/`in-progress` heuristic is
  gone), `isVerifying` also true when the execution is `running`. `StoryCard` — the Queued state (`Clock`, tooltip
  "Waiting for another test execution to finish — it starts on its own"), locked; Not started's tooltip says it never
  ran. `types/testing.ts` — `ExecutionEndNote {cancelled?, error?, problems?}` added to `ExecutionRow.totals`.
  `testing/logic.ts` — `cancelledReason(ex)`. `VerificationSection` — "Cancelled: <reason>." (any reason; no match on
  its text, review n5/n6).
- Contract fixtures (`web/src/test/fixtures/testing/`, written by `tests/contract_fixtures.record` from real
  responses): new `board.json` (GET board with a queued card), `board-card.json` (PATCH move response, running),
  `verification-cancelled.json` (the story read after a move-out cancel); `verification-start.json` regenerated (its
  card gained the field). `verification.json` was rewritten with new values only (no shape change) and restored.
  `contract.test.ts`: checks for the three new fixtures; the card's verification fields pinned by an
  `Exact<Pick<BoardCard, …>>`; list card keys = single card keys = the start's card keys.

### Tests

- genesis `tests/test_story_verification.py` (+10, all FAIL on the pre-fix code, run as a temporary copy against the
  stashed source): single move and bulk move cancel a queued verification with the reason, the responses carry
  `verification_active: null`, the story read shows it cancelled with the reason, and the queue starts no verification
  afterwards; Remove from board and the Design start cancel it; moving a running verification card (single and bulk)
  leaves the execution and its run running; a move with nothing queued is unchanged (and a stale move is still 409); a
  cancel failure is logged at ERROR and the move stands; the launch cancels when the card was moved by another path
  (and when it was removed from the board) and the pump starts the next queued execution, with the stage unbound; a move
  during the launch's export still withdraws it with no run record; a route cancel that wins the race to `set_running`
  starts nothing; `withdraw_queued` never cancels a running execution; the board reads `verification_active` for three
  cards with ONE statement touching `kb_test_executions` (SQLite trace callback), and `get_card` returns the same keys.
- Web `verification.test.tsx`: Queued (locked, no View run link, jest-axe), Verifying… (locked), Not started for
  stage `draft` and `in-progress` (movable, jest-axe), a queued execution of a card outside Verification does not lock
  it, the story page's cancelled-before-start line for both reasons (jest-axe); the 51-11 state table now sets
  `verification_active` per
  case. The four new behaviours fail against the old `StoryCard` / types / section (checked by stashing them).
  `contract.test.ts`: the three new fixture checks.
- Gates (after the change, before the commit): `ruff check genesis tests/test_story_verification.py` clean; pytest
  **1679 passed**; web `tsc --noEmit` clean, `npm run lint` 0 errors (the 20 existing warnings), vitest **653 passed,
  61 files** (647 at 51-11 + 6); `npm run build` OK. After the review fixes (`45e9827`): `test_story_verification.py`
  **27 passed** (+1: `test_withdraw_skips_an_execution_whose_launch_wins_the_cas`, the cancel losing the CAS to
  `set_running`; the remove/Design test now also covers the Implementation start), ruff clean, tsc clean, lint 0
  errors, vitest **654 passed, 61 files**. No backend source changed after `9b258bb`, so the full pytest (1679) was
  not re-run.
- **Not run:** a real browser, a real queue on QA, a real server restart while queued (51-12).

### Review

`reviews/51-14-review.md`. First pass at `c74cbed`: **SHIP**, with minors m1 (the Implementation-start cancel had no
test) and m2 (no test for the cancel reading the execution as queued and then losing the CAS to the launch's
`set_running`), and nits n3 (a move by a non-route path between the second lane check and `set_running` still starts
the run; folding the lane into the `set_running` UPDATE would close it), n4 (the L-089 recurrence), n5 (the web matched
the backend's default reason text), n6 (repeated "before … started" wording) and n7 (no index on the `json_extract`).
Fixed in `45e9827`: m1 and m2 with tests, n5 and n6 by rendering "Cancelled: <reason>." Not changed: n3 (decision 3;
the spec leaves a running verification alone; **51-12: note it**), n7 (fine at today's execution counts). Re-review of
`c74cbed..a1f7f3e`: **SHIP** (the reviewer re-ran the story-verification tests 27, ruff, tsc, lint, the workbench +
testing vitest 206 and a delayed out-of-tree bundle diff; identical).

### Decisions / deviations

No ADR deviation. **Bold = for 51-12.**
1. **"Out of Verification" = the move's target lane is not `verification`** (not "the old lane was"): no extra read
   before the move and no race on it; it also clears any stray queued verification of a card that was already
   elsewhere. A queued verification only exists for a card that `start` moved into Verification.
2. **Beyond the two move routes, the Design start, the Implementation start and Remove from board cancel too.** The
   board's Yes on the Design / Implementation confirm moves the card through `BoardStore.move_card` directly (not the
   move route), and removing a card takes it out of Verification. Each is one call to the same helper; the launch guard
   would catch them later anyway, but the story page now shows the cancel at once.
3. **A second lane check just before `set_running`.** The export between `_launch`'s first check and `set_running` can
   take seconds; a move in that window would otherwise start the run. The remaining window is the
   check→`set_running` CAS; a move route's cancel that lands there makes `set_running` fail (handled), and one that
   lands after it finds the execution running and leaves it alone (spec: a running verification is unchanged).
4. `ExecutionCancelled` is a subclass of `ExecutionError`; the pump treats it as "withdrawn, try the next" and logs
   INFO (a readiness or git failure stays `error`, loudly).
5. **`verification_active` = queued first, then running** (the `active()` order); `check()`'s `busy` refusal means a
   story never has both.
6. **"List and single board"**: `GET /workbench/boards` (`list_boards`) carries counts, no cards, so the field is on
   `get_board`'s cards and on `get_card` (returned by the move, start and import routes). `importable` is unchanged
   (its rows are not cards).
7. **Queued locks the card only in the Verification lane.** A queued execution of a card elsewhere (a collaboration
   pull moved it) is cancelled when the queue reaches it; locking that card would trap it behind a long execution.
   No on-read cancel was added for that case.
8. ~~**A Queued card is locked, so the board drag cannot take it out;** the way to withdraw it is Cancel on the
   execution page (51-11), after which the card reads Not started and moves. The move-out cancel covers another tab or a
   stale board, the confirm dialogs and Remove from board. **51-12: confirm with the user that this is the intended
   experience.**~~ **Superseded by D25 amended (Q25, 2026-11-04) and §5:** a Queued card is draggable; dragging it out
   of Verification asks first (As built — §5).
9. `ExecutionRow.totals` gained `ExecutionEndNote` (the server already sent `{cancelled}` and `{error, problems}`
   there; the type said empty). `BoardCard` extends `Story`, whose columns the contract test does not pin; only the
   verification fields and list = single parity are pinned.
10. The source and the bundle were meant to go in one commit (the web skill's rule), with the build, the commit, the
    rebuild and the status as separate calls. That held for `9b258bb`; for both follow-ups the bundle was not on disk
    yet when the commit was staged, so a separate build commit (`c74cbed`, `a1f7f3e`) carries it (see Commits).

**For 51-12 live acceptance (real browser, real QA):** queue a verification behind a long execution (e.g. Run impacted
tests): the card shows Queued with the tooltip and can be dragged (§5; see "For 51-12" in As built — §5 for the
drag-out confirm); Cancel it on the execution page → the card reads
Not started and moves; the story page reads "Cancelled: before it started." — and for a move-out cancel "Cancelled: the
card left Verification before the run started." (from a second tab: drag the
card out while the first tab shows it Queued); restart the server while a verification is queued, move the card out by
another tab or a collaboration pull, and check the queue skips it and starts the next execution; the queued card in both
themes; decision 8; review n3 (a move by a non-route path in the instant between the last lane check and
`set_running` still starts the run: decide whether that is acceptable; Q26 accepted it as a known limit).

### Lesson candidates

- **A guard that runs once at the start of a slow launch leaves a window as long as the launch.** The lane check at
  the top of `_launch` alone would miss a move made during the export; the check belongs right before the CAS that
  commits the launch, with the CAS's own failure handled as the same outcome.
- **"Moved out" has more paths than the move route.** Two confirm dialogs and the removal take a card out of a lane
  through the store directly; list every caller of the store's write before hooking only the route.
- **(L-089 amendment, for genesis-docs) A build's output can reach the disk after the build command has returned.**
  Twice in 51-14 a `git add -A web/static` right after `npm run build` printed "built" staged nothing, and a
  `git status` right after a rebuild read empty; a read a minute later showed the change. Wait for the output to settle
  before staging, and after a bundle commit check `git show --stat <sha> -- web/static` (or compare a delayed
  out-of-tree build with `git archive HEAD web/static`) instead of trusting the message (review n4).

### Code-map changes

For bible/03 in the "Phase 51" block (genesis-docs): `TestExecutionService.cancel(reason=, queued_only=)`,
`execution_service.ExecutionCancelled` (pump: withdrawn → next); `StoryVerificationService.withdraw_queued`,
`_withdraw_if_moved` (the launch guard, twice), `verification_service.LEFT_VERIFICATION`; `kb/boards`
`_VERIFICATION_ACTIVE` (board card `verification_active`, one subquery in both card queries) and
`BoardStore.card_lane`; `api/workbench._withdraw_queued` (move, lane reorder, Design/Implementation start, remove);
web `isVerificationQueued`, `VerificationActive`, `ExecutionEndNote`, `testing/logic.cancelledReason`; fixtures
`board`, `board-card`, `verification-cancelled`.

## As built — §5 (2026-11-04, genesis-dev)

**Task restated.** Web only (D25 amended, Q25): a Queued card (`verification_active == "queued"` in the Verification
lane) stays draggable and only Verifying locks. A move that takes a Queued card out of Verification asks first
("Cancel the queued verification?", Move and cancel / Keep in Verification) through the board's shared `Dialog`
primitive. Confirm sends the normal lane move, and the §2 route cancels the queued execution. Keep, or closing the
dialog, sends nothing and the card snaps back. A move that lists several Queued cards gets one dialog naming the count.
The Design and Implementation confirms add the same sentence for a Queued card. The §2 backend is unchanged.

**Applicable rules.** ADR-027 / ADR-055 (shared `Dialog`/`DialogDescription`/`Button`, tokens only), ADR-028 (the move
goes through the existing `useReorderLane` hook), ADR-050 / ADR-061 (a move stays a lane assignment; the cancel stays
server-side), ADR-062 / ADR-068 (the Design and Implementation confirms keep their buttons and behaviour; only a
sentence is added). Lessons L-011 / L-083 (the tests use the real `board.json` Queued card and return the real board
shape), L-069 (no `<Button asChild>`), L-089 (build, commit and proof as separate calls, with the output left to
settle), L-094 (the `isVerificationQueued` consumers were grepped; none rely on it meaning "locked" now).

### Commits

- **genesis** (base `a1f7f3e`, local, not pushed or tagged): `209297a` feat(web,51-14) §5, source and tests only (its
  message says the bundle is in the next commit); `cca8ff8` build(web,51-14), `web/static` only (63 files).
  **Bundle proof (L-089).** `npm run build`, then a 60 s wait, then a status read in its own call showed the 115-file
  bundle change on disk, and the new `index-Zg3bwXYu.js` contained "Keep in Verification". After both commits: a
  rebuild, then in its own call, after a 60 s wait, `git status --short --untracked-files=all` was empty. `git grep
  "Keep in Verification" HEAD -- web/static/assets` → `index-Zg3bwXYu.js`. The reviewer separately ran an out-of-tree
  build, waited 65 s and diffed it against `web/static`: identical. No L-089 recurrence this time.
- **project-tracker:** this As built (plus decision 8 marked superseded and the 51-12 note updated) and the
  "§5 follow-up review" section of `reviews/51-14-review.md`.

### Changed (genesis web)

- `types/workbench.ts`: `isVerificationQueued`'s doc says the card is not locked. New `queuedLeavingVerification(cards,
  lane)` returns the Queued cards a move to `lane` takes out of Verification, and none for a move within Verification.
- `StoryCard.tsx`: `locked` no longer includes `isVerificationQueued`. Verifying (and a running design or
  implementation) still locks.
- New `QueuedVerificationDialog.tsx` (shared `Dialog`). Its title, its `DialogDescription` (`QUEUED_CANCEL_SENTENCE`,
  the §5 sentence) and the buttons Keep in Verification (outline) / Move and cancel follow §5. `count > 1` gives
  "Cancel the queued verifications?" and "Moving these N stories out of Verification cancels their queued
  verifications. Nothing has run yet." Closing the dialog counts as Keep.
- `BoardPage.tsx`: `onDragEnd`'s plain lane move now goes through `move()`. `move()` counts
  `queuedLeavingVerification` over the payload's `story_ids`, which is the list the lane route withdraws for
  (`api/workbench.py:211`). A count above zero sets `pendingQueued` and opens the dialog; otherwise `move()` calls
  `reorder.mutate`. `resolveQueued`: Confirm → `reorder.mutate(move)`; Keep → `setItems(byLaneIds)`, with no request.
  Drops into Design and Implementation still open their own confirms (no second dialog). `leavesQueued(storyId)` adds
  `QUEUED_CANCEL_SENTENCE` to each when the dragged card is Queued. "Just move" and "Start …" both cancel server-side
  (As built decision 2).

### Tests

- `verification.test.tsx` (+11; 36 in the file). Changed: the Queued card has its drag handle (it was asserted
  locked). New tests drive the real cross-lane sequence (`onDragOver`, then `onDragEnd`), so the payload is the target
  lane's list:
  - a drop on Deployment opens the dialog, with the title, the accessible description and both buttons, sends no
    request and is axe clean;
  - Move and cancel sends one PATCH to `…/lanes/deployment` with `story_ids: [1]`;
  - Keep in Verification and Close send nothing, and the card is back in the Verification column;
  - a verification that started while the dialog was open (board refetched to running) is not moved;
  - a Not started card moves out with no confirm;
  - the Design and Implementation confirms show the sentence (axe clean), Just move sends one PATCH, and no second
    dialog opens;
  - the Design confirm has no sentence for a card that is not Queued;
  - the count variant: the dialog rendered with `count=2` (plural title and description, axe clean, both callbacks);
  - `queuedLeavingVerification` returns `[1, 2]` from a mixed list and `[]` for the Verification lane.
  With `BoardPage.tsx` and `StoryCard.tsx` stashed, 8 of the new or changed tests fail. The not-Queued, no-sentence,
  count-dialog and helper tests pass on the old code too: they pin behaviour that stays the same or new standalone
  code.
- Gates (one call each): `npm run lint` 0 errors (the 20 existing warnings, none new), `npx tsc --noEmit` clean,
  `npx vitest run` **665 passed, 61 files** (654 + 11), `npm run build` OK. pytest and ruff were not run, because no
  Python changed.
- **Not run:** a real browser drag (jsdom cannot drive a dnd-kit pointer drag; the tests call its handlers), and a
  real queue.

### Review

`reviews/51-14-review.md` § "§5 follow-up review", range `a1f7f3e..cca8ff8`: **SHIP**, with no blockers, majors or
minors. The reviewer re-ran lint, typecheck, the full vitest (665) and a delayed out-of-tree bundle diff (identical).
It accepted both scope interpretations below. Nits (not changed):
- s5-n1: a confirm refused because the verification started meanwhile snaps the card back with no message; the card's
  "Verifying…" explains it, and a toast is optional.
- s5-n2: a background refetch can snap the card back behind the open dialog; Confirm still sends the stored move.
  The Design and Implementation confirms already behave this way.
- s5-n3: the tracker updates, done in this As built.

### Decisions / deviations

No ADR deviation. **Bold = for 51-12.**
1. **The "bulk move" is the lane reorder route.** The web board has no multi-card selection; every drag persists
   through `PATCH …/lanes/{lane}`, the §2 bulk route, which withdraws for every listed story. So the guard counts over
   that payload, and one dialog names the count. A single-card drag cannot list two Queued cards (the other listed
   cards are already in the target lane), so the plural copy is reachable only through the shared guard. It is tested
   on the dialog and the helper directly. No multi-select UI was built (not in §5).
2. **Remove from board has no web confirm.** `useRemoveCard` has had no caller since Phase 43 (ADR-071: the story page
   has no remove control), so there was no existing confirm to extend. The backend route still cancels (§2). **51-12:
   do not look for it in the UI.**
3. **The Design and Implementation drops keep their own confirm, with the sentence, and no Queued dialog first.** Both
   of their buttons move the card out of Verification and cancel server-side, so one dialog says so. The sentence
   shows only when the dragged card is Queued.
4. **Confirm re-checks the card.** If the board refetched while the dialog was open and a listed card now reads
   Verifying, Move and cancel sends nothing and the card snaps back (Verifying locks, §5). The move route would leave
   a running verification alone anyway, but the card would leave a locked state.

**For 51-12 live acceptance:** with a Queued card, drag it to Deployment. The confirm appears. Keep in Verification
returns the card; Move and cancel moves it, and the story page reads "Cancelled: the card left Verification before the
run started." Drag a Queued card into Design and into Implementation: the confirm carries the sentence. Check the
dialog in both themes and watch for nits s5-n1 and s5-n2.

### Lesson candidates

- **A spec sentence about an "existing confirm" needs a grep for its caller first.** §5 named a Remove-from-board
  confirm and a bulk move that the web does not have (the backend routes exist, the UI does not). Grepping the hook's
  callers before building showed it, and the guard was put on the request payload the route acts on, not on a UI
  gesture.

### Code-map changes

For bible/03 in the "Phase 51" block (genesis-docs): web `QueuedVerificationDialog` (+ `QUEUED_CANCEL_SENTENCE`),
`types/workbench.queuedLeavingVerification`, `BoardPage.move()` / `resolveQueued` (the guard over the lane-move payload);
a Queued card is no longer locked (`StoryCard`).
