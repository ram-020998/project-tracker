# 51-14 — Queued verification guard and the board's verification state

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (backend + web). Parent:
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

## Context manifest

```toml
areas    = ["stories-workbench", "runs-worker"]
adrs     = ["ADR-050", "ADR-061", "ADR-062", "ADR-068"]
lessons  = ["L-011", "L-039", "L-058", "L-061", "L-069", "L-083", "L-089", "L-093", "L-094"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/backlog/phase-51-follow-ups.md"]
code     = ["genesis/genesis/testexec/verification_service.py", "genesis/genesis/testexec/execution_service.py", "genesis/genesis/kb/boards.py", "genesis/genesis/api/workbench.py", "genesis/web/src/features/workbench/**", "genesis/web/src/types/workbench.ts"]
upstream = ["51-09", "51-10", "51-11"]
```
