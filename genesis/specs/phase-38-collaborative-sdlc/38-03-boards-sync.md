# 38-03 — Boards sync

> **Status:** ✅ SHIPPED (genesis v0.65.0). · Part of Phase 38. Repo: **genesis**. · **Depends on:** 38-02 (stories the board is over), `BoardStore`, Phase 36 (BoardState record).

## Purpose

Share the board so **everyone sees the same lanes/status** for an app — while keeping **in-lane ordering** and
**which boards you've pinned to your sidebar** local (the locked board decisions).

## Build

1. **Lane = shared story `status`.** A card move (`move_card`/`reorder_lane`) that changes a story's `status`
   **publishes the Story record's status** + a **BoardState** record (`app_uuid`, `story_sync_uuid`, `status`);
   others **auto-pull** it (boards are a read-only shared view — auto-apply). Uses the Phase-37 board poll.
2. **Membership = automatic/shared.** A board shows the app's **shared finalized stories** (pulled), not a
   per-user manual import — so everyone opening app X's board sees the same cards without re-importing. (Import
   as a per-user curation step is retired for shared boards; a shared "add to board" may be a shared action or
   simply "all finalized stories appear" — finalize the exact rule here, lean: all shared finalized stories.)
3. **In-lane `board_position` stays LOCAL** — never published (high-churn, cosmetic; the locked decision).
4. **Sidebar board curation stays LOCAL** — `workbench_boards` (which apps you added to *your* Workbench) is
   personal; the board's *content* is shared.
5. Conflict: two lane moves of the same story → base-version CAS on the Story; last-write-wins with a version;
   the mover sees the current lane on the next poll.

## Tests

- A lane move publishes status + BoardState; a second instance auto-pulls the new lane; in-lane ordering does
  **not** sync; sidebar curation stays local; membership shows the app's shared finalized stories; CAS on
  concurrent moves. ruff clean.

## Deliverable

Board lane/status + membership sync (ordering + sidebar local) + tests.

## Gate

Independent review = SHIP: lanes shared, ordering/curation local, membership automatic, CAS correct; gates green.
