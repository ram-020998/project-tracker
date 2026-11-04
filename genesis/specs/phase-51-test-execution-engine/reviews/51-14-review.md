# Review 51-14 — base 0170834 (genesis-review, 2026-11-04)

Range `0170834..HEAD` in `genesis` (HEAD = `c74cbed`; commits `9b258bb`, `b23337c`, `c74cbed`, local, not pushed).
Sub-spec: `specs/phase-51-test-execution-engine/51-14-queued-verification-guard.md` (§1–§4 + As built).
`genesis-ctx check --since 0170834 --repo genesis`: 79 files (16 source/test/fixture + 63 `web/static`), areas api,
stories-workbench (+ always-on release-ci, security).

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis tests/test_story_verification.py` | All checks passed |
| `pytest -q tests/test_story_verification.py` | 26 passed (the 10 new 51-14 tests included) |
| `pytest -q -p no:warnings -x` (full) | **1679 passed** in 612 s (matches As built) |
| `npm run lint` | 0 errors, 20 warnings (pre-existing count, as claimed) |
| `npm run typecheck` | clean |
| `npx vitest run` | **654 passed, 61 files** (As built says 653 + 1 test in `b23337c` = 654) |
| `npx vite build --outDir /tmp/51-14-static` then `diff -r /tmp/51-14-static web/static` | IDENTICAL |
| in-tree `npm run build` (own call) → 60 s wait (own call) → `git status --short --untracked-files=all` (own call) | empty |

## Focus questions from the brief

1. **A running verification is never cancelled by a move — OK.** `withdraw_queued`
   (`testexec/verification_service.py:111-129`) only walks `by_status("queued", kind="verification")` and calls
   `cancel(..., queued_only=True)`. `cancel` (`execution_service.py:200-213`): status read `running` → `queued_only`
   raises `ExecutionError` (caught, skipped); status read `queued` but `set_running` commits before the cancel's
   `finish(expected_status="queued")` → `_cas_status` (`kb/testexec_store.py:1148-1155`) raises `StaleWriteError`
   (caught, skipped). The `rm.cancel(run_id)` branch is unreachable with `queued_only`. The opposite order (the route's
   cancel commits between the launch's second lane check and `set_running`) makes `set_running`'s CAS fail; the launch
   re-reads, sees `cancelled` and raises `ExecutionCancelled` (`verification_service.py:279-286`). Tests:
   `test_moving_a_running_verification_card_out_leaves_it_alone` (single + bulk, run still `running`),
   `test_withdraw_queued_never_cancels_a_running_execution`, `test_a_route_cancel_that_wins_the_race_to_set_running_starts_nothing`.
   The "status read queued, CAS lost to set_running" interleaving is correct by inspection but has no test (finding 2).
2. **The launch guard leaves no run record and the pump moves on — OK.** `_withdraw_if_moved` runs before readiness
   (`:244`, before `RunManager.start`, so nothing is created) and inside `prepare` (`:275`); `RunManager.start`
   (`runs/manager.py:285-293`) removes a fresh run folder and re-raises before `store.create`. The pump catches
   `ExecutionCancelled` before the generic branch (`execution_service.py:231-234`), logs INFO, never calls `_fail`, and
   continues the loop. Tests: `test_launch_cancels_when_the_card_is_elsewhere_and_the_pump_starts_the_next` (next
   execution `running`, its run is the last job, stage unbound, removal case too),
   `test_a_move_during_the_launch_export_still_withdraws_it` (`rm.count(workflow_id="story-verification") == 0`).
3. **`verification_active` in one statement, same on `get_board` and `get_card` — OK.** `_VERIFICATION_ACTIVE`
   (`kb/boards.py:32-42`) is a correlated subquery appended to both card SELECTs (`:163-164`, `:358-359`); no per-card
   call. `test_the_board_reads_verification_active_for_every_card_in_one_query` traces the SQLite connection: one
   statement touching `kb_test_executions` for three cards; `set(get_card) == set(board card)`. The web
   `contract.test.ts` `board-card` check pins list keys = single keys = the start's card keys (L-039).
   Order (queued first, then `te.id`) matches `StoryVerificationService.active` (`:103-109`).
4. **Fixtures from real responses, types match — OK.** `board.json`, `board-card.json`, `verification-cancelled.json`
   are written by `record()` (`tests/contract_fixtures.py:33-41`) from `client.get/patch` responses in the new tests;
   the backend test asserts shape equality on every run. Values are real shapes (L-083): `verification_status:
   "draft"`, real `r-…` run ids, the real reason string. `types/workbench.ts:9-10, 47-49` and `types/testing.ts`
   `ExecutionEndNote` match; `Exact<Pick<BoardCard, …>>` and `Exact<BoardDetail>` pin them. Only the verification
   fields of `BoardCard` are pinned (its `Story` columns are not), stated in decision 9; acceptable for this scope.
5. **Web card states and the story page line, with jest-axe — OK.** `verification.test.tsx`: Queued (from the real
   `board.json` card) shows the tooltip, no drag handle, no View run link, axe clean; Verifying… locked; Not started for
   `draft` and `in-progress` movable, axe clean; a queued execution outside Verification does not lock; the cancelled
   line "Cancelled before it started: the card left Verification before the run started." axe clean; the plain
   execution-page cancel reads "Cancelled before it started.". The `isVerificationNotStarted` heuristic is gone
   (`types/workbench.ts:93-96`); its only consumer is `StoryCard.tsx` (grep, L-094).
6. **`web/static` at HEAD equals a fresh build — OK.** Out-of-tree build diff IDENTICAL; in-tree `npm run build`, a
   separate 60 s wait, then a separate `git status --short --untracked-files=all`: empty.

## Checklist

### ADRs
- [N/A] ADR-011 — no agent node changed.
- [OK] ADR-012 — the app still only starts a run via `RunManager.start`; no workflow Python imported.
- [N/A] ADR-019 — no core API change.
- [OK] ADR-021 / ADR-068 — Design/Implementation confirm paths unchanged except the post-move `_withdraw_queued`
  (`api/workbench.py:273`, `:389`); no new mutation of Appian.
- [OK] ADR-023 — FastAPI routes only.
- [N/A] ADR-026 — no bind/auth change.
- [OK] ADR-027 / ADR-055 — existing `Badge`/`Clock` from `@/shared/ui`, tokens (`text-fg-muted`, `text-primary`) only.
- [OK] ADR-028 / L-010 — no URL or `/api` in components; routes unchanged.
- [N/A] ADR-031 / 033 / 034 / 045 — no chat change.
- [N/A] ADR-035 — no file inputs.
- [N/A] ADR-042 / 043 / 046 / 047 / 049 / 056 / 057 / 058 / 059 / 060 / 063 / 064 / 065 / 070 / 072 / 074 / 075 / 076
  / 078 / 079 / 080 — not touched.
- [OK] ADR-050 — the board move remains a lane assignment; an execution cancel is not an SDLC transition (no story or
  stage status written by the cancel/guard).
- [OK] ADR-061 — eight lanes, explicit membership unchanged; `card_lane` is read-only.
- [OK] ADR-062 — the Design confirm still launches the design workflow; only an extra withdraw after the move.
- [OK] ADR-071 — the cancelled line is in the canonical story page's `VerificationSection`.
- [OK] ADR-077 — reviewer used `genesis-ctx`; no `--trust-all-tools`.

### Lessons
- [N/A] L-003, L-018 — no SSE change.
- [OK] L-004 — state in SQLite (`kb_test_executions`).
- [OK] L-011 — fixtures recorded from real responses, contract tests on both sides.
- [N/A] L-017, L-019, L-031, L-045, L-048, L-068, L-072, L-074, L-085, L-087, L-088, L-090, L-095, L-096, L-098, L-099,
  L-100.
- [OK] L-025 / L-027 — pinned ruff clean.
- [OK] L-030 — this release touches `web/**`, so the frontend job runs.
- [OK] L-039 — one subquery shared by both card reads; test asserts key parity.
- [OK] L-056 — HEAD contains every changed file (the gap in `b23337c` was closed by `c74cbed`; empty status at HEAD).
- [N/A] L-057 — no tag yet (51-13 release).
- [OK] L-058 / L-061 — the guard is level-triggered at launch and re-checks the current lane; failures logged at ERROR
  (`api/workbench.py:133-137`, `test_a_cancel_failure_is_logged_and_the_move_stands`).
- [OK] L-069 — no `<Button asChild>`.
- [OK] L-083 — real value shapes in the fixtures and the Queued test uses the real `board.json` card.
- [VIOLATION, process, fixed] L-089 — `b23337c` was committed without its bundle and its message says "web/static
  rebuilt"; corrected by `c74cbed`; HEAD proven by rebuild + separate status (finding 4).
- [OK] L-091 — every status change is a CAS (`_cas_status` `WHERE id=? AND status=?`); no SELECT-then-write.
- [N/A] L-092 — no new test module names.
- [OK] L-093 — tests end runs through the real `RunManager._finalize` (`_end_adhoc`).
- [OK] L-094 — consumers of the changed web helpers grepped: only `StoryCard.tsx`.

### Gates
- [OK] `pytest -q -p no:warnings` — 1679 passed.
- [OK] `ruff check genesis` — clean.
- [OK] `npm run lint && npm run typecheck && npm test` — 0 errors / clean / 654 passed.
- [OK] `npm run build` + `web/static` committed — identical to a fresh build; empty status.

## Findings

### Blockers
None.

### Majors
None.

### Minors
1. **The Implementation-start withdraw has no test.** `api/workbench.py:389` adds `_withdraw_queued` after the
   Implementation confirm's move, but `test_removing_the_card_or_starting_design_cancels_a_queued_verification` covers
   only Remove from board and the Design start (its docstring names Implementation too). Add an Implementation-start
   case (queued verification → `POST …/implementation/start` → execution `cancelled` with `LEFT_VERIFICATION`, response
   card `verification_active: null`), or narrow the docstring. The launch guard would still catch a miss, so this is
   not a correctness gap today.
2. **The "cancel read queued, then lost the CAS to `set_running`" interleaving is untested.** This is the exact
   race in focus question 1. The code is correct by inspection (`finish` → `StaleWriteError` → skipped in
   `withdraw_queued`), but the existing tests hit only the `ExecutionError` branch (status already `running`) and the
   opposite order. A test that monkeypatches `store.finish` (or `cancel`'s `_get`) to run `set_running` first would
   pin that `withdraw_queued` returns `[]` and the run stays `running`.

### Nits
3. **Residual window, by design.** A move by a non-route path (collaboration pull) between the second lane check and
   `set_running` still starts the run (decision 3 accepts it; the spec says a running verification is unchanged).
   Folding the lane condition into the `set_running` UPDATE would close it entirely; worth one line in 51-12's notes,
   not a change now.
4. **L-089 process recurrence.** `b23337c`'s message claims "web/static rebuilt" but the commit holds source only; HEAD
   is correct. For genesis-docs: the recurrence shows an immediate post-build `git status` can read empty before the
   bundle is on disk; the lesson's proof step should say "after the build process has exited and its output settled".
5. **The web matches the backend's default reason by string** (`VerificationSection.tsx:197`,
   `cancelled === "before it started"`). If `cancel`'s default text changes, the page would read
   "Cancelled before it started: before it started.". A shared constant or a reason code would be sturdier.
6. The user-facing line "Cancelled before it started: the card left Verification before the run started." says
   "before … started" twice; a shorter reason ("the card left Verification") would read better. Wording only.
7. `_VERIFICATION_ACTIVE` filters on `json_extract(trigger_json, '$.story_id')` per card with no index on that
   expression; fine at today's execution counts, noted in case `kb_test_executions` grows large.

## Verdict: SHIP

No blockers or majors; every gate green and re-run by the reviewer; the four decisions that go beyond the spec's text
(cancel on Design/Implementation start and removal, "target lane ≠ verification", the second lane check, Queued locks
only in Verification) are consistent with D25 and the spec's intent. Minors 1–2 are test additions that should land
before or with 51-13; decision 8 (a Queued card cannot be dragged out) stays for 51-12 to confirm with the user.

---

## Re-review — range `c74cbed..a1f7f3e` (genesis-review, 2026-11-04)

Commits: `45e9827` (fixes for m1, m2, n5, n6) and `a1f7f3e` (the bundle for `45e9827`). HEAD resolves to `a1f7f3e`;
the working tree is clean. Outside `web/static`, the range changes `tests/test_story_verification.py` (+36),
`web/src/features/workbench/VerificationSection.tsx` and `verification.test.tsx`. `genesis-ctx check --since c74cbed
--repo genesis`: 66 files, areas stories-workbench (+ always-on release-ci, security). Nits 3 and 7 are deliberately
not changed. Both stay nits, and neither blocks.

### Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings tests/test_story_verification.py` | **27 passed** (26 + the new m2 test) |
| `.venv/bin/ruff check genesis tests/test_story_verification.py` | All checks passed |
| `npm run typecheck` | clean |
| `npm run lint` | 0 errors, 20 warnings (same pre-existing count) |
| `npx vitest run src/features/workbench src/features/testing` | **206 passed, 16 files** |
| `npx vite build --outDir /tmp/51-14-rr-static --emptyOutDir` (own call) → `sleep 65` (own call) → `diff -r /tmp/51-14-rr-static web/static` (own call) | IDENTICAL |
| `git status --short --untracked-files=all` (own call) | empty |

The full backend suite was not re-run. The range changes only one test module and no backend source.

### Prior findings

1. **m1 (Implementation-start withdraw untested): FIXED.** The renamed test
   `test_removing_the_card_or_starting_design_or_implementation_cancels_a_queued_verification`
   (`tests/test_story_verification.py:657-696`) now moves the card back to Deployment and queues a fresh verification.
   It gives the story a reviewed design (`set_html` + `in-review`), then calls `POST …/implementation/start` and
   asserts the following: 200, the response card has `lane == "implementation"` and `verification_active is None`, and
   the execution is `cancelled` with `totals.cancelled == LEFT_VERIFICATION`. The asserts read the response right after
   the route returns, so the cancel comes from the route's `_withdraw_queued` (`api/workbench.py:389`) and not from
   the launch guard.
2. **m2 ("cancel read queued, then lost the CAS to `set_running`" untested): FIXED.**
   `test_withdraw_skips_an_execution_whose_launch_wins_the_cas` (`:699-713`) patches `env.svc.store.finish`, which
   is the store that `TestExecutionService.cancel` writes through (`execution_service.py:205-207`). The patch commits
   `set_running(…, run_id="r-raced")` before the cancel's `finish(expected_status="queued")`. The test asserts that
   `withdraw_queued` returns `[]` and that the execution stays `running` with `run_id == "r-raced"`. This is the exact
   interleaving from the first review. The test can tell the outcomes apart: if the CAS did not reject the cancel, the
   row would read `cancelled` and the status assert would fail. It also reaches the `StaleWriteError` branch of
   `withdraw_queued`'s `except (ExecutionError, StaleWriteError)` (`verification_service.py:124`), which the existing
   tests never hit.
3. **n5 (string match on the backend default) and n6 (repeated wording): FIXED.** `VerificationSection.tsx:194-196` now
   renders `Cancelled: {cancelled}.` and no longer branches on the reason text. The page reads "Cancelled: the card
   left Verification before the run started." or "Cancelled: before it started.". Both reasons are program-owned.
   `executions.cancel(app_uuid, key)` in `api/testing.py:286` takes no user reason, so the trailing period cannot
   double up. Tests: `verification.test.tsx:255-271` checks both texts, and the first test stays axe clean.
4. **n4 (L-089 recurrence): RECURRED, process only, corrected.** `git show --stat 45e9827 -- web/static` is empty, yet
   the message says "web/static rebuilt". `a1f7f3e` adds the bundle, and HEAD is proven fresh by the delayed
   out-of-tree diff and the empty status above. This is the second time in 51-14 (after `b23337c`) that a commit
   message claims a bundle the commit does not hold. For genesis-docs, this supports the lesson change already proposed
   in n4: wait for the build output to settle before staging, and check `git show --stat <sha> -- web/static` after the
   commit instead of trusting the message.
5. **Nits 3 and 7:** unchanged by design, as the brief states. They remain nits.

### Checklist (re-review range)

- [OK] ADR-027 / ADR-055: the change only removes a branch in `VerificationSection.tsx`. It keeps the existing token
  class `text-fg-muted` and adds no primitive or dependency.
- [OK] ADR-050: no status write added. The tests drive stage status through the existing stores as fixtures only.
- [OK] ADR-061 / ADR-062 / ADR-068: the Design and Implementation confirm routes are unchanged in this range. The new
  test exercises the existing Implementation route.
- [OK] ADR-071: the cancelled line stays on the canonical story page's `VerificationSection`.
- [OK] ADR-077: the reviewer used `genesis-ctx`, without `--trust-all-tools`.
- [N/A] ADR-011, 019, 021, 026, 031, 033, 034, 042, 045, 046, 049, 056–060, 063–065, 070, 072, 074–076, 078–080: not
  touched by this range (one test module plus one web component and its test).
- [OK] L-025 / L-027: the pinned ruff is clean.
- [OK] L-030: the range touches `web/**`, so the frontend CI job runs.
- [OK] L-056: HEAD holds every changed file (empty status, bundle identical).
- [VIOLATION, process, corrected] L-089: `45e9827` was committed without its bundle. `a1f7f3e` corrects it, and HEAD
  is proven by a rebuild plus a separate status check after a 65 s wait.
- [OK] L-083: the m2 test uses a real `r-…` run id shape. The web tests use the real `verification-cancelled.json`
  fixture and the real default reason.
- [OK] L-091: the m2 test pins the CAS semantics of `finish(expected_status=…)`.
- [OK] L-092: the new test is a test function in an existing module. No new module, and no non-test `test_*` symbol.
- [OK] L-069: no `<Button asChild>`.
- [N/A] L-017, L-045, L-051, L-057 (no tag), L-072, L-074, L-085, L-087, L-088, L-090, L-093, L-095, L-098–L-100: not
  touched.
- [OK] Gates: the story-verification pytest, ruff, typecheck, lint, the scoped vitest and the bundle check are all
  green (table above).

### Findings (re-review)

- **Blockers:** none.
- **Majors:** none.
- **Minors:** none.
- **Nits:** a. The L-089 process recurrence in `45e9827` (prior n4). It is corrected at HEAD and needs no code change.
  The lesson-wording follow-up for genesis-docs stands. Prior nits 3 and 7 carry over unchanged.

### Re-review verdict: SHIP

Minors 1–2 now have tests that would fail on a regression. Nits 5–6 are resolved without a string match. Every gate the
brief asked for is green at `a1f7f3e`, and `web/static` equals a fresh build.

---

## §5 follow-up review — range `a1f7f3e..cca8ff8` (genesis-review, 2026-11-04)

Commits: `209297a` (web source + tests, no `web/static`: `git show --stat 209297a -- web/static` is empty, and its
message says the bundle is in the next commit) and `cca8ff8` (63 `web/static` files only; `git show --stat cca8ff8 --
. ':!web/static'` is empty). HEAD = `cca8ff8`, working tree clean. Outside `web/static` the range changes
`BoardPage.tsx` (+51), `QueuedVerificationDialog.tsx` (new, 38), `StoryCard.tsx`, `types/workbench.ts` and
`verification.test.tsx` (+141). No backend change. `genesis-ctx check --since a1f7f3e --repo genesis`: 68 files, areas
stories-workbench (+ always-on release-ci, security).

### Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `npm run lint` | 0 errors, 20 warnings (same pre-existing count) |
| `npx eslint` on the five changed source/test files | clean (no warning on the new file's exported constant) |
| `npm run typecheck` | clean |
| `npx vitest run` | **665 passed, 61 files** (matches the claim: 654 + 11) |
| `npx vite build --outDir /tmp/51-14-s5-static --emptyOutDir` (own call) → `sleep 65` (own call) → `diff -r /tmp/51-14-s5-static web/static` (own call) | IDENTICAL |
| `grep -c "Keep in Verification" web/static/assets/index-Zg3bwXYu.js` | 1 |
| `git status --short --untracked-files=all` (own call, after the out-of-tree build and the wait) | empty |

Not re-verified: the claim that 8 of the new/changed tests fail with the change stashed (stashing writes the tree).
By reading, the drag-handle assert (`verification.test.tsx:224`) and every test in the new describe block depend on
the `StoryCard` lock change and `move()`, so they cannot pass on `a1f7f3e`.

### Spec §5 against the diff

1. **Queued draggable, only Verifying locks — OK.** `StoryCard.tsx:161` drops `isVerificationQueued` from `locked`;
   `isVerifying` stays. Tests: `verification.test.tsx:216-227` (Queued from the real `board.json` card: the "Drag
   Score" handle is present, no View run link, axe clean) and `:229` (Verifying… locked, unchanged).
2. **Dialog on drop out of Verification — OK.** `onDragEnd` (`BoardPage.tsx:173-175`) now calls `move()`, which
   counts `queuedLeavingVerification` over the payload's `story_ids` (`:180-187`). That is the exact list the backend
   withdraws for (`api/workbench.py:211`, `lane != "verification" and _withdraw_queued(app_uuid, body.story_ids)`), so
   the dialog opens exactly when the route would cancel something. A move within Verification never asks
   (`types/workbench.ts:93-95`). Title, description (via `DialogDescription`, checked with
   `toHaveAccessibleDescription`) and both button labels match the spec text (`QueuedVerificationDialog.tsx:10-11,
   24-34`). The dialog reuses the shared `Dialog` primitive like the Design/Implementation confirms.
3. **Confirm sends one move, Keep / close sends none and snaps back — OK.** `resolveQueued` (`BoardPage.tsx:190-201`)
   sends `reorder.mutate(p.move)` on confirm and `setItems(byLaneIds)` otherwise; `onOpenChange(false)` maps to Keep
   (`QueuedVerificationDialog.tsx:21`). Tests `verification.test.tsx:276-284` (one PATCH to `…/lanes/deployment` with `story_ids: [1]`) and
   `:286-296` (both "Keep in Verification" and "Close": zero lane PATCHes, card back in the Verification column). The
   tests drive `onDragOver` then `onDragEnd` (`dragAcross`, `verification.test.tsx:119-125`), the real cross-lane sequence, so the payload is
   the target lane's list as in a browser.
4. **Extra guard (a verification that started while the dialog was open) — OK.** Re-reads `cardById` from the
   refetched board and refuses to send when a listed card is `isVerifying` in Verification. Test `verification.test.tsx:298-310`. It sends
   nothing and the card shows Verifying…, which is the safe side: the backend would leave a running verification alone
   anyway, but the move would take a running card out of a locked state.
5. **Design / Implementation confirms carry the sentence — OK.** `leavesQueued` (`:226-230`) and the two `<p>` lines
   (`:309-311`, `:335-337`). Both their buttons already cancel server-side ("Yes" via the start routes, "Just move" via
   the lane route; 51-14 As built decision 2). Tests `verification.test.tsx:321-336` (both lanes, sentence present, axe clean, Just move sends
   one lane PATCH and no second dialog) and `:338-346` (no sentence for a card that is not Queued). Routing Design /
   Implementation drops straight to their own confirm, not through `move()`, means no double dialog; correct.
6. **Bulk-move variant (dev interpretation 1) — accepted.** The board's lane reorder route *is* the §2 "bulk route"
   (it acts on every listed story). A single drag can make the count > 1 only if two listed cards both read
   `lane == "verification"` on the server while the target lane is elsewhere, which a drag cannot produce: the other
   listed cards are already in the target lane. The count reaches the dialog unchanged (`:182-185`, `:297`), the plural
   copy is tested by rendering the dialog with `count=2` (`verification.test.tsx:348-361`, axe clean), and the helper is unit-tested
   (`:363-368`). This meets the spec's wording ("one dialog naming the count") as far as the web can reach it.
7. **Remove from board (dev interpretation 2) — accepted.** `grep useRemoveCard|removeCard\(|Remove from` over
   `web/src/**/*.tsx` finds nothing; `useRemoveCard` (`hooks.ts:218`) has no caller. There is no confirm to add the
   sentence to. The spec's premise ("which already cancel… get the same sentence added to their existing confirm") is
   true only for the backend route; worth a line in the §5 As built so 51-12 does not look for it.
8. **Bundle — OK.** Delayed out-of-tree build identical to `web/static`; the source/bundle split across two commits
   is stated honestly in `209297a`'s message (no L-089 false claim this time).

### Checklist (this range)

- [OK] ADR-027 / ADR-055 — shared `Dialog`, `DialogContent`, `DialogDescription`, `DialogTitle`, `Button` from
  `@/shared/ui`; tokens only (`text-fg`, `text-fg-muted`); no new dependency.
- [OK] ADR-028 / L-010 — no URL or `/api` in components; the move uses the existing `useReorderLane` hook.
- [OK] ADR-050 — no status write; a lane move remains a lane assignment, and the cancel stays server-side.
- [OK] ADR-061 — eight lanes and explicit membership unchanged; no new movement rule except the confirm.
- [OK] ADR-062 / ADR-068 — the Design and Implementation confirms keep their buttons and behaviour; only an
  informational sentence is added. The Implementation confirm stays the single blanket approval.
- [OK] ADR-071 — no story surface added.
- [OK] ADR-077 — reviewer used `genesis-ctx`; no `--trust-all-tools`.
- [N/A] ADR-011, 019, 021, 026, 031, 033, 034, 042, 045, 046, 049, 056–060, 063–065, 070, 072, 074–076, 078–080 —
  web-only change in the workbench board; none touched.
- [OK] L-011 / L-083 — the tests use the real `board.json` Queued card; the lane PATCH handler returns the real board
  shape.
- [OK] L-069 — no `<Button asChild>`.
- [OK] L-030 — the range touches `web/**`, so the frontend CI job runs.
- [OK] L-056 — HEAD holds every changed file (empty status; bundle identical).
- [OK] L-089 — source and bundle in separate commits with an honest message; HEAD proven by a delayed out-of-tree
  build, a separate diff and a separate status.
- [OK] L-094 — `isVerificationQueued` consumers: `StoryCard.tsx` (face only now), `BoardPage.tsx` (`leavesQueued`),
  `queuedLeavingVerification`; none rely on it meaning "locked" any more.
- [N/A] L-017, L-025, L-027 (no Python change), L-045, L-051, L-057 (no tag), L-072, L-074, L-085, L-087, L-088,
  L-090, L-091, L-092, L-093, L-095, L-098–L-100.
- [OK] Gates — lint, typecheck, full vitest and the bundle check green (table above). pytest / ruff not re-run: no
  Python file in the range.

### Findings (§5)

- **Blockers:** none.
- **Majors:** none.
- **Minors:** none.
- **Nits:**
  - **s5-n1. A refused confirm is silent.** `BoardPage.tsx:197-200`: when "Move and cancel" finds a listed card now
    Verifying, the card snaps back with no message. The card's own "Verifying…" state explains it in most cases; a
    `toast.info("The verification started; the card stays in Verification")` would make it explicit. Optional.
  - **s5-n2. The board resync can snap the card back while the dialog is open.** `BoardPage.tsx:120-123`: with no drag
    and no pending mutation, a background refetch resets `items` to the server lanes, so the card can jump back to
    Verification behind the open dialog; Confirm still sends the stored move. Same pre-existing behaviour as the
    Design / Implementation confirms, so no change asked; mention it if 51-12 sees it live.
  - **s5-n3. The tracker needs a §5 As built.** The spec header still reads "§5 follow-up SPEC-DRAFTED" and As built
    decision 8 ("A Queued card is locked…; 51-12: confirm with the user") is now superseded by D25 amended / Q25. The
    dev's project-tracker commit should add the §5 As built (commits `209297a`, `cca8ff8`; interpretations 1 and 2;
    test counts) and mark decision 8 superseded, and update the 51-12 live-acceptance note ("cannot be dragged" →
    "drag out asks first; Move and cancel → the story page reads 'Cancelled: the card left Verification before the
    run started.'").

### §5 verdict: SHIP

Every §5 requirement the web can reach is built and tested against the route's real payload; the two scope
interpretations are correct readings of the code (the lane route is the bulk route; no Remove-from-board UI exists).
All gates are green at `cca8ff8`, and `web/static` equals a fresh build compared after a 65 s wait.
