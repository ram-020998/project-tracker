# 33-04 — Code review & hardening

> **Status:** ✅ SHIPPED (genesis v0.61.0). · Part of Phase 33. Repo: **genesis**. · Gate: review clean.

## Purpose

An independent review of 33-02 + 33-03 against the ADR-061 contract + the coding standards + the §7 lessons,
then apply the MUST/SHOULD-FIX items. No new scope.

## Review checklist

**Correctness / data**
- [ ] m0017 is idempotent + forward-only; `current_version`→17; **every `==16` test bumped**; `test_db` asserts
      the two new tables + a 17→18 synthetic next-migration.
- [ ] `UNIQUE(board_id, story_id)` holds; import is **idempotent** (re-importing an on-board story is a no-op
      skip, not a dup or error); `add_board` is **409** on a dup app.
- [ ] **Cascade on untrack** verified — untracking an app deletes its board **and** cards (FK or explicit
      cleanup, per 33-01/02); no orphan `kb_board_cards`.
- [ ] **Lane = status** invariant: no lane column on `kb_board_cards`; the board reads lane from
      `kb_stories.status`; move writes only `status` (+ `board_position`).
- [ ] Move uses **`row_version` CAS** → 409 on mismatch; bad lane → 400; lane values validated ∈ `STORY_LANES`.
- [ ] Import sets `status='to-do'`; un-imported stories keep `design`; app-ownership (story→feature→app)
      enforced on import + move + remove (no cross-app leakage).
- [ ] The **ADR-050 free-move relaxation** is recorded (a comment + ADR-061) — moves are lane assignments, not
      gated transitions this phase; `STORY_STAGE_TRANSITIONS` reconciled but **not called** by the board.

**Web / UX / a11y**
- [ ] `@dnd-kit` **keyboard** drag works (lift/move/drop) with SR announcements; a visible drag handle;
      `aria-roledescription`. jest-axe clean on landing/board/import/add-apps/drawer.
- [ ] Optimistic move **rolls back** on 409 + toasts; `row_version` refreshed from the response.
- [ ] Lane **order comes from the API** (no client/server drift); count badges match card counts.
- [ ] Empty states: no boards (Add applications), empty board (Import prompt), nothing importable (finalize
      prompt).
- [ ] No hardcoded brand hex (tokens/`color-mix` only); **dark parity** verified on board + dialogs + drawer.
- [ ] Contract fixtures / types mirror the API (a drift fails a test); the only shell edit is the `PRIMARY_NAV`
      row (+ icon) — no other AppShell changes.
- [ ] Large-board sanity: a board with 100+ cards renders + drags acceptably (note virtualization as a future
      option if needed — not required this phase).
- [ ] Reuse honored: themed `Select`, epic-tone/badges, `Drawer`/`Dialog`, the extracted `StoryDetailView`
      (drawer ≡ Stories-tab detail content).

**Gates**
- [ ] genesis pytest + ruff clean; web tsc/eslint(0)/vitest/build; `web/static` committed.

## Deliverable

Review notes + applied fixes; a short live-acceptance script (add app → import batch → drag across all 8 lanes
→ reload persists → remove card → remove board).

## Gate

Review clean → 33-05.
