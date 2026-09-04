# Phase 33 — The Workbench (a per-application Kanban execution board)

> **Status:** ✅ **SHIPPED — PHASE 33 COMPLETE (2026-09-04)** · genesis v0.61.0, CI green. ADR-061 **Accepted**. As-built: `progress/phase-33-workbench.md`. Umbrella + `phase-33-workbench/33-01..33-05`. · **Author:** Genesis agent
> **Type:** single-repo — **genesis** (backend + web) + **one migration (m0017)** + **one new web dep (`@dnd-kit`)**. genesis-core / kiro-agent-sdk / genesis-workflows / genesis-appian-parser **unchanged**. · **Depends on:** Phase 32 (finalized stories — `kb_stories`/`kb_epics` + `StoryStore` + the forward-compat `status` column; ADR-060), Phase 28 (the Feature Workspace framework + the reserved story-execution plug-point; ADR-056), Phase 25-01 (`LifecycleService` + `STORY_STAGE_TRANSITIONS` + the `Story`/`Stage` domain; ADR-050 + m0013 audit) + 25-08 (`row_version` CAS; m0014), Phase 24-02/27 (the primary-nav / app-shell; ADR-049), Phase 16/20 (applications + features; the app→feature→story linkage).

---

## 1. Why this phase exists

Phase 32 turned a finished Feature Breakdown into first-class, editable **stories** — but they sit in a
per-feature list with a `status` column that is **not surfaced anywhere**. There is nowhere the **actual work
happens**: no place to pull groomed stories into an execution pipeline and move them through design → review →
build → code-review → verification → deployment → done.

**This phase builds that place: the Workbench.** A new top-level surface holding one **Jira-style Kanban board
per application**, where a lead **imports** stories (in batches, on demand) and **drags** them across fixed
lanes as the work progresses. The lanes are the story `status`; a drag persists it. This is the surface every
upcoming SDLC-automation phase plugs into — dragging a card into **Design** will (in a *future* phase) kick off
the design workflow, **Implementation** the build, and so on. **This phase ships the board UI/UX + import +
drag-persists-lane; the per-lane automation is explicitly out of scope (future phases).**

ADR-056 reserved the story-**execution** plug-point and ADR-050/25-11 defined the `Story`/`Stage` machine
"defined now; persisted by the backlog per-story work." Phase 32 (ADR-060) laid the `status` seam. **This phase
surfaces that seam as a working board** — the execution home the whole program has been building toward.

---

## 2. Goal

1. **A Workbench nav item + landing.** A new primary-nav destination (**Workbench**). Its landing lists the
   application boards the user has added, as **sub-tabs** (one per application). An **empty** Workbench shows an
   **"Add applications"** action → a picker of **any** Genesis application → each selected app is **added to the
   Workbench** and gets its own board.
2. **A per-application Kanban board.** Selecting an app's sub-tab (`/workbench/:appUuid`) shows a Jira-like board
   with **eight lanes in order: To Do · Design · Design Review · Implementation · Code Review · Verification ·
   Deployment · Done**, each with a **count badge**. Cards show a **type icon (Story/Task) + key + title + a
   colored epic chip + labels/category** (no assignees/points/sprints — single-user). A board toolbar offers
   **search + Epic/Type/Label filters** (reusing the Phase-32 `Select` primitive).
3. **Import (batched, on demand).** An **Import stories** action lists the app's **finalized** stories **not yet
   on the board**, grouped by feature/epic, with **multi-select**; "Add N to board" creates the cards in **To
   Do**. Stories are never auto-added.
4. **Drag to move + persist.** Dragging a card to another lane **persists the new lane** (`kb_stories.status`)
   with `row_version` CAS. **Free movement** (any lane → any lane) this phase.
5. **Card drawer.** Clicking a card opens a **drawer** over the board reusing the Phase-32 story detail
   (read-only + a link to the full editable detail page).
6. **Remove from board / remove board.** A card can be **removed from the board** (membership only; the story
   stays in the Stories tab). An application can be **removed from the Workbench** (its board detaches;
   stories/features untouched).

**Success = a lead adds an application to the Workbench, imports a batch of its finalized stories into To Do,
and drags them across the eight lanes — every move durably persisted — with the board reading exactly like a
lightweight Jira, ready for the per-lane automation of the next phases.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-04)

Firm inputs, not open questions.

1. **Eight lanes, this order:** **To Do → Design → Design Review → Implementation → Code Review → Verification →
   Deployment → Done.** (Deployment is **after** Verification — a deliberate reorder of the current domain
   table.)
2. **Lane = `kb_stories.status`** (single source of truth). Imported cards start in **To Do** (`status='to-do'`).
3. **Free drag movement** this phase (any lane → any lane; persist the status). Gating/automation is future.
4. **One board per application.** Boards are **curated** — an app is explicitly **added** to the Workbench (from
   any Genesis application) and can be **removed**.
5. **Import is explicit + batched** — never auto-populate; the picker lists finalized stories not yet on the
   board.
6. **Remove-from-board** keeps the story (it stays in the feature's Stories tab, the CRUD/authoring surface).
7. **`@dnd-kit`** is the drag-and-drop library (accessible; one new web dep).
8. **Card click → a drawer** over the board (reuses the Phase-32 detail); the routed `StoryDetailPage` stays for
   the Stories tab.
9. **Flat lanes** (no swimlanes; epic shown as a card chip).
10. **Genesis-only + one migration (m0017)** (`current_version` 16 → **17**). No genesis-core / SDK /
    genesis-workflows change.

---

## 4. Current state (what we build on) — code-grounded

- **Stories + the `status` seam exist.** `genesis/kb/stories.py::StoryStore` over `kb_stories`/`kb_epics`
  (Phase 32/ADR-060, m0016). `kb_stories.status TEXT NOT NULL DEFAULT 'design'` + `row_version` CAS →
  `StaleWriteError` → 409. Stories are per-feature (`feature_id`); a feature belongs to an application
  (`kb_features` FK→`kb_applications`, Phase 20), so an app's board pool = all finalized stories across its
  features. `kb_features.stories_finalized_at` marks a finalized feature.
- **The domain has a story machine (reserved).** `domain/enums.py::LifecycleState` has `DESIGN ·
  IMPLEMENTATION · CODE_REVIEW · DEPLOYMENT · VERIFICATION · DONE`; `domain/transitions.py::
  STORY_STAGE_TRANSITIONS` wires `design → implementation → code-review → deployment → verification → done`.
  **This phase adds `TO_DO`/`DESIGN_REVIEW` and reorders to the 8-lane sequence** (deployment after
  verification) — forward-compat, **not enforced on drag** this phase.
- **Primary nav is a single source (`web/src/shared/layout/nav.ts::PRIMARY_NAV`)** consumed by the Sidebar + ⌘K
  palette (ADR-049 as amended). Adding **Workbench** = one row here + an icon in `shared/ui/icons.ts` + routes
  in `app/router.tsx` + breadcrumb patterns in `shared/layout/breadcrumbs.ts`.
- **Applications API exists.** `api/applications.py` + `KbStore` list tracked apps (uuid + name). The
  "Add applications" picker + board headers reuse these.
- **Storage + concurrency patterns are established.** Forward-only migrations (`genesis/db/migrations/`,
  `current_version=16`, m0016 the latest); per-entity stores; `row_version` CAS (m0014); `/api`-prefixed
  routers (ADR-028); the feature-detail surface. `kb_applications`/`kb_features` cascades (ADR-042).
- **The themed `Select` + Stories grid primitives** (Phase 32) — `shared/ui/select.tsx`, the colored epic-tone
  palette, the Story/Task + category badges — are reused for the board toolbar filters + card chips.

**Takeaway:** this phase = one migration (2 tables) + a `BoardStore` + Workbench/board/import/move API + a web
`features/workbench` folder (nav item, landing, board with `@dnd-kit`, import + add-apps dialogs, card drawer)
+ the two new `LifecycleState` members. **No workflow / core / SDK change; no per-lane automation.**

---

## 5. Data model (m0017) — finalized in 33-01

- **`workbench_boards`** — the curated registry of apps added to the Workbench (one board per app):
  `id PK · app_uuid TEXT NOT NULL UNIQUE (FK→ the applications table's uuid ON DELETE CASCADE) · created_at ·
  updated_at`.
- **`kb_board_cards`** — which stories are on a board + their per-lane order: `id PK · board_id FK→
  workbench_boards(id) ON DELETE CASCADE · story_id FK→kb_stories(id) ON DELETE CASCADE · board_position INTEGER
  NOT NULL DEFAULT 0 · added_at TEXT NOT NULL · UNIQUE(board_id, story_id)`. **No lane column — lane = the
  story's `status`.**
- **Domain:** `LifecycleState` gains `TO_DO="to-do"` + `DESIGN_REVIEW="design-review"`; a canonical **`LANES`**
  ordering (to-do → … → done) lives as a shared constant (backend + a mirrored web constant); the
  `STORY_STAGE_TRANSITIONS` table is reconciled to the order (forward-compat; not wired to drag).
- `current_version` → **17**. Every `current_version == 16` test bumps with the migration (the §7 lesson).

---

## 6. Backend — finalized in 33-02

A `BoardStore` (mirrors `StoryStore`) + a `/api/workbench` router:

| Method & path | Purpose |
|---|---|
| `GET /workbench/boards` | the added boards (app_uuid, name, per-lane counts) — powers the sub-tabs |
| `GET /workbench/applications/available` | tracked apps **not** yet on the Workbench — the Add-applications picker |
| `POST /workbench/boards` `{app_uuid}` | add a board (409 if already added; validate the app is tracked) |
| `DELETE /workbench/boards/{app_uuid}` | remove the board (cascade removes its cards; stories untouched) |
| `GET /workbench/boards/{app_uuid}` | the board: lanes + cards (each = story fields + epic + feature provenance; lane = status), ordered by `board_position` |
| `GET /workbench/boards/{app_uuid}/importable` | finalized stories across the app's features **not on the board**, grouped by feature/epic |
| `POST /workbench/boards/{app_uuid}/cards` `{story_ids:[]}` | import a batch → create cards + set `status='to-do'` (one tx; skip already-on-board; validate the stories belong to the app) |
| `PATCH /workbench/boards/{app_uuid}/cards/{story_id}` `{lane, position?, row_version}` | **move** → set `kb_stories.status=lane` (+ `board_position`); `row_version` CAS → 409 |
| `DELETE /workbench/boards/{app_uuid}/cards/{story_id}` | remove the card (membership only; story stays) |

Lane values validated against `LANES`. Reuses `StoryStore` for story fields + the applications API for names.

---

## 7. Web — finalized in 33-03

- **Nav + routes:** add **Workbench** to `PRIMARY_NAV` (a `SquareKanban`/Kanban icon; placed after Home) + a
  breadcrumb pattern; routes `/workbench` (landing) + `/workbench/:appUuid` (board). No other shell edits.
- **`features/workbench/`:** `WorkbenchPage` (landing — sub-tabs of added boards; **empty state** with "Add
  applications"; `AddApplicationsDialog`) · `BoardPage` (the Kanban: 8 `BoardColumn`s with count badges +
  toolbar search/Epic/Type/Label filters) · `StoryCard` (type icon + key + title + epic chip + labels) ·
  `ImportStoriesDialog` (grouped multi-select + "Add N") · `BoardCardDrawer` (reuses the Phase-32 story detail
  content; link to the full editable page) · `hooks.ts`/`lib/api/workbench.ts`/`types` + query keys.
- **Drag-and-drop (`@dnd-kit`):** `DndContext` + droppable columns + sortable cards; on drag-end → optimistic
  move + `PATCH …/cards/{id}` (`row_version`); rollback + toast on 409. Keyboard sensor + ARIA (a11y).
- **Reuse:** the themed `Select` (filters), the epic-tone palette + Story/Task/category badges (cards), the
  `Drawer` primitive (card drawer). jest-axe on the board + dialogs + drawer.

---

## 8. ADR

- **ADR-061 (PROPOSED — this phase): The Genesis Workbench — a per-application Kanban execution board.** A new
  primary-nav **Workbench** holds a curated set of **per-application** Kanban boards over the app's finalized
  stories, with eight fixed lanes (To Do → Design → Design Review → Implementation → Code Review → Verification
  → Deployment → Done); lane = `kb_stories.status`; explicit **batched import** into To Do; **free drag** that
  persists the lane (`row_version` CAS); remove-from-board (membership only). Persistence = **m0017**
  (`workbench_boards` + `kb_board_cards`; `current_version` → 17); `LifecycleState` gains `to-do`/`design-review`
  and the `STORY_STAGE` table is reconciled (forward-compat, not enforced on drag). Realizes the ADR-056
  story-execution plug-point + surfaces the ADR-060 `status` seam; **amends ADR-049** (nav); adds **`@dnd-kit`**.
  **Per-lane automation is out of scope** (future phases). Mirror in `reference/decision-log.md` + (on Accept)
  `bible/04`.

---

## 9. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **33-01** | Data model & ADR | Lock the `workbench_boards`/`kb_board_cards` schema + the `LANES` constant + the `LifecycleState`/`STORY_STAGE` reconciliation + the full API contract + the story/card DTO shapes; **draft ADR-061.** **Docs only.** | ⭐ user sign-off → build |
| **33-02** | Backend: board store + API | m0017 (2 tables; `current_version`→17); `BoardStore`; the `/api/workbench` routes (boards CRUD, importable, import batch, move w/ `row_version` CAS → 409, remove card); the two `LifecycleState` members + reconciled table; tests (+ bump `current_version` tests). | independent review = SHIP |
| **33-03** | Web: Workbench + board + import | `PRIMARY_NAV` Workbench + routes + breadcrumbs; `features/workbench` (landing + add-apps + board + `@dnd-kit` drag + import dialog + card drawer + filters/counts); types + api + hooks; jest-axe. Gates green; `web/static` committed. | independent review = SHIP |
| **33-04** | Code review & hardening | Independent review (dnd keyboard-a11y, `row_version` CAS on move, import/add idempotency, cascade on untrack-app, lane-value validation, the ADR-050 free-move relaxation recorded, empty/large-board states, a11y/dark-parity/no-hardcoded-hex/contract fixtures, only-nav shell edit); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **33-05** | Release | genesis vX.Y.0 (single repo); tag; CI green (incl. clean-install DB upgrade to **v17**); docs (bible §2/§3/§4/§8 + tracker + progress + ADR-061 → Accepted) updated; report. | CI green |

**Suggested order:** 33-01 → 33-02 → 33-03 → 33-04 → 33-05 (linear; each gated on the prior).

---

## 10. Release plan

**Single-repo** (genesis only) + **m0017** + the `@dnd-kit` dep. Per ADR-019 no dependent pins move. Per
sub-phase: build → gates (pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`) → local commit →
independent review → docs; **no tag/push until 33-05 on the user's go-ahead**. The `clean-install` CI job must
migrate a fresh DB to **v17** and serve. A schema bump breaks every hardcoded `current_version==16` test — bump
them with the migration (the §7 lesson). Pin `@dnd-kit` to an exact version.

---

## 11. Scope

**In scope:** m0017 (`workbench_boards` + `kb_board_cards`); the `BoardStore` + `/api/workbench` API; the
Workbench nav item + landing (add/remove applications) + the per-application Kanban board (8 lanes, count
badges, toolbar filters); explicit batched **import** into To Do; **free drag** that persists the lane
(`row_version` CAS); remove-from-board; the card drawer; the two new `LifecycleState` members + the reconciled
(unwired) `STORY_STAGE` table.

**Out of scope (future phases):** the **per-lane automation** (dragging into a lane triggering the design /
implementation / code-review / verification / deployment workflow — the whole point of the later phases);
**gated** transitions + m0013 audit on moves; WIP limits; swimlanes; card reordering beyond a single
`board_position`; multiple boards per app; assignees / story points / sprints (single-user, ADR-026);
push-to-Jira; real-time multi-tab board sync.

---

## 12. Open questions

None blocking — all resolved with the user (2026-09-04): eight lanes with Deployment after Verification; lane =
status; imported cards start in To Do; free drag; one curated board per app (add/remove applications);
remove-from-board keeps the story; `@dnd-kit`; card-click drawer; flat lanes; genesis-only + m0017.
