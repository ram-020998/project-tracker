# Phase 44 — Workbench, SDLC & Workspace Fixes (12-issue bundle)

> **Status:** 🟡 **DRAFTED — spec only; awaiting build go-ahead.** · **Author:** Genesis agent · Created 2026-09-25.
> **Scope:** **genesis-only** (web + backend). **One migration** (`m0022`, `current_version` 21 → 22) for the
> story-identifier sequence (fix 3); every other fix is code-only. genesis-core / kiro-agent-sdk /
> genesis-workflows / genesis-appian-parser **unchanged**. **No Genesis Hub (Appian) change** (fix 3's story
> `key` is already a synced column; fixes 4/5 reuse the existing `board_move` publish contract).
> **New ADR:** **ADR-072** (global human-readable story identifier) — **Proposed** (see §5).

---

## 1. Overview

Twelve user-reported issues from live use of the shipped app (through genesis v0.74.0), bundled into one
genesis-only fix phase. They span the Applications/Feature surfaces, the Workbench collaboration flow, the run
inspector, the chat list, the runs list, the catalog, the document library, and Settings. Each fix below is
**grounded in the current code** (file + the exact cause), and the proposed fix is the **smallest correct,
standards-compliant change** (bible §8 loop; `reference/coding-standards.md`) — no refactors beyond the fix,
existing primitives/patterns reused, a regression test per fix, all gates green.

**Goals**
- Fix every reported defect with a **standard** implementation (no lint suppression, no bundle drift, jest-axe
  clean on touched UI, `web/static` rebuilt+committed).
- Keep the two collaboration-sensitive fixes (4/5) faithful to the existing publish/pull contract — the
  backend finalizers publish system-driven lane moves exactly the way the frontend publishes manual moves.
- One migration only; bump every `current_version == 21` head assertion to 22.

## 2. Locked decisions (from the 2026-09-25 Q&A)

1. **Fix 5** reproduces **only when collaboration is enabled** → confirmed same root cause as fix 4 (system
   lane moves are never published, so the always-on auto-pull re-mirrors the Hub's stale status). The fix is to
   **publish system moves** from the finalizers.
2. **Fix 3 story IDs:** prefix **`GNS_`**, **6-digit** zero-pad (`GNS_000001`), a **single GLOBAL** sequence
   across all stories; **manually-added** stories also get the next id; **existing** stories are **left as-is**
   (no backfill).
3. **Fix 8 runs:** the **standard** approach — **server-side pagination + server-side filtering** (20/page).
4. **Fix 6 node view:** **true SSE streaming** (as chat and other live surfaces do), not just faster polling.
5. **Fix 9 catalog prereqs:** filter the internal/managed MCPs in the **backend** `/catalog` response.
6. **Fix 1/12 defaults:** the app-detail default tab stays **Business Map** (Features just moves next to
   Overview); Settings **General** becomes **first AND the default** tab.
7. **Packaging:** all 12 fixes ship in **one** phase (this one).

---

## 3. The fixes

Each fix: **Symptom → Root cause (evidence) → Fix (files/functions) → Tests → Notes**. "FE" = frontend
(`genesis/web`), "BE" = backend (`genesis/genesis`).

### Fix 1 — Move the Features tab next to Overview (FE)

- **Symptom.** On `/applications/:uuid`, the **Features** tab is last; it should sit next to **Overview**.
- **Root cause.** `web/src/features/applications/ApplicationDetail.tsx` renders
  `<Tabs defaultValue="business-map">` with the `TabsList` order *Business Map · Overview · Syncs · Releases ·
  Business Artifacts · Features*.
- **Fix.** Reorder the `TabsTrigger` **and** `TabsContent` to *Business Map · **Overview · Features** · Syncs ·
  Releases · Business Artifacts*. Keep `defaultValue="business-map"` (decision 6). Pure presentation.
- **Tests.** `applications.test.tsx`: assert the tab triggers render in the new order (Features immediately
  after Overview).
- **Notes.** No API/behaviour change.

### Fix 2 — Delete a feature (FE only; backend already exists)

- **Symptom.** Inside a feature there is no way to delete it.
- **Root cause.** `web/src/features/features/FeaturePage.tsx` renders only `FinalizeStoriesControl` in the
  `Page` `actions`. The backend `DELETE /api/features/{id}` **and** the hook `useDeleteFeature(appUuid)`
  (`features/hooks.ts` → `featuresApi.remove`) **already exist** (the feature FK-cascades its spec/stages/
  epics/stories, ADR-042). Only the UI trigger is missing.
- **Fix.** Add a `Trash2` icon button (`variant="ghost"`, `aria-label="Delete feature"`) to the `Page`
  `actions` beside `FinalizeStoriesControl`, opening a confirm `Dialog` (mirroring `ApplicationDetail`'s
  untrack pattern). On confirm → `useDeleteFeature(appUuid).mutate(feature.id, { onSuccess: () =>
  navigate('/applications/${appUuid}') })`. Confirm copy states it removes the feature and all its
  spec/stages/stories (cannot be undone; the Appian app is unaffected).
- **Tests.** `features.test.tsx`: the delete button opens the confirm; confirming calls `featuresApi.remove`
  and navigates. jest-axe on the feature page with the new control.
- **Notes.** No new backend. Keep the button disabled while the mutation is pending (`loading`).

### Fix 3 — Meaningful story identifiers `GNS_000001` (BE + FE + migration)

- **Symptom.** Finalized stories have no meaningful identifier; they need a running, human-readable id
  (`GNS_000001`) that is stable and syncs to teammates.
- **Root cause.** `genesis/kb/stories.py::finalize()` inserts each story with
  `key = str(st.get("id") or "") or None` (the raw backlog id, usually blank). `create_story()` uses
  `data.get("key")` (usually None). There is **no sequence**. (`kb_stories.key` is a plain shared column — it
  is **not** in `collab/service.py::_LOCAL_ONLY`, and the `story` binding publishes it — so once populated it
  propagates to the Hub's `GH Story` record automatically; **no Hub change**, verified.)
- **Fix.**
  - **Migration `m0022_story_sequence`** (`current_version` 21 → 22): a tiny durable counter table
    `kb_sequences (name TEXT PRIMARY KEY, next_val INTEGER NOT NULL)`, seeded with a single row
    `('story', <start>)`. `<start>` = `1` (existing stories are left as-is per decision 2; a global sequence
    that simply counts newly-keyed stories from 1 upward is acceptable — collisions with existing blank/backlog
    keys are impossible because those aren't `GNS_` formatted). Additive + idempotent (guarded `CREATE TABLE
    IF NOT EXISTS` + insert-or-ignore).
  - **`kb/stories.py`:** a private `_next_story_key(conn) -> str` allocated **inside the existing write
    transaction** (serialized writes — the bible's WAL/tx model): `UPDATE kb_sequences SET
    next_val = next_val + 1 WHERE name='story' RETURNING next_val` (SQLite ≥3.35 `RETURNING`, bundled in
    Python 3.13) → format `f"GNS_{n:06d}"`. Use it in **`finalize()`** (per story, replacing the backlog-id
    key) and in **`create_story()`** (always allocate, ignoring any inbound `key`). **Epics keep** their
    existing workstream-derived `key` (the request is about stories).
  - **Display (FE):** surface `story.key` as a monospace id where a story is shown but the key isn't yet:
    the Stories grid row (`features/StoriesTab.tsx`), the story detail/workspace header
    (`workbench/StoryWorkspacePage.tsx`), and the board card (`workbench/StoryCard.tsx` — show the id above/
    beside the title). Render nothing (or `—`) when `key` is null (existing pre-Phase-44 stories).
- **Tests.** `tests/test_story_finalize.py` / `test_story_crud`: finalize assigns sequential `GNS_000001`,
  `GNS_000002`, … globally across features; a subsequent `create_story` gets the next id; the counter persists
  across store instances; concurrent finalize/create don't collide (serialized tx). A web test asserts the id
  renders in the grid/card. Bump the migration head assertion to `current_version == 22`.
- **Notes.** Global monotonic — the id is unique across the whole install and rides the story sync payload
  unchanged. ADR-072 records the scheme.

### Fix 4 — System (finalizer) card moves are not published to the Hub (BE)

- **Symptom.** Manual card drags reach the Hub, but system moves (e.g. Implementation → Code Review on a
  completed implementation) are not posted.
- **Root cause.** Manual moves publish from the **frontend** — every workbench mutation
  (`web/src/features/workbench/hooks.ts` `useMoveCard`/`useReorderLane`/`useStartDesign`/
  `useStartImplementation`) calls `collabApi.publishBoardMove(appUuid, storyId)` on success. The **system**
  moves happen in the backend finalizers (`chat/story_design_finalizer.py`,
  `chat/story_implementation_finalizer.py`): they change the lane via `LifecycleService.transition(...)`
  (writes `kb_stories.status` + the m0013 audit) and **never call the collaboration service** — so the move
  never reaches the Hub. (`collab.publish_board_move(app_uuid, story_id)` exists and publishes the Story record
  [status rides it] + a `BoardState` record.)
- **Fix.** Give both finalizers the already-constructed `CollaborationService`:
  - `api/app.py`: pass `collab=collab_service` into `StoryDesignFinalizer(...)` and
    `StoryImplementationFinalizer(...)` (`collab_service` is constructed **before** the workbench/finalizer
    block, so it is available).
  - Both finalizers: add a `collab=None` constructor param + a `_publish_move(story_id)` helper that resolves
    `app_uuid` via `self.stories.get_by_id(story_id)` and, **only if** `self.collab and
    self.collab.is_enabled()`, calls `self.collab.publish_board_move(app_uuid, story_id)` under a **broad
    guard** (`log.warning(..., exc_info=True)` — finalization must never crash; §7 honest-failure rule). Call
    `_publish_move` after each successful lane change (design → design-review; implementation → code-review;
    implementation → design-review send-back).
- **Tests.** Finalizer tests with a fake collab (enabled): assert `publish_board_move` is called after each
  system transition; with collab disabled/None: assert **no** call and no error. Reuse the existing finalizer
  test harness.
- **Notes.** Best-effort + opt-in-gated, exactly mirroring the frontend. The audited `LifecycleService`
  transition stays the source of truth.

### Fix 5 — Design card not advancing to Design Review (BE — same root cause as fix 4)

- **Symptom.** Dragging a ticket into Design and running the design workflow: on completion the card is **not**
  moved to Design Review (collaboration-enabled instances only — decision 1).
- **Root cause.** `StoryDesignFinalizer._advance_lane` **does** move the lane `design → design-review` via the
  audited `LifecycleService.transition(STORY, id, "submit")` (edge exists in `domain/transitions.py`:
  `(DESIGN, "submit") → DESIGN_REVIEW`, with a `set_status` fallback). But because that move is **not published
  to the Hub** (fix 4), the always-on backend auto-pull (`runtime/collab_autopull.py::CollabAutoPuller` →
  `collab/service.py::pull_all`) re-mirrors the **Hub's stale Story `status`** back onto the local row via
  `_upsert_local` (status is a shared, non-`_LOCAL_ONLY` column) — reverting `design-review` → `design`. Net
  effect: the card appears not to advance. Solo (collab disabled) it works, which matches decision 1.
- **Fix.** **Fix 4 fixes this** — once `StoryDesignFinalizer` publishes the `design → design-review` move, the
  Hub is consistent and the auto-pull no longer reverts it. No additional change beyond fix 4's design-finalizer
  publish.
- **Tests.** An integration-style finalizer test: after finalize, the lane is `design-review` **and**
  `publish_board_move` was called (so a subsequent pull would not revert). Optionally a regression test that a
  pull of a stale Hub status does **not** override a locally-newer published move (covered by the existing CAS
  cursor once the move is published).
- **Notes.** No transition-table or workflow change; purely the missing publish.

### Fix 6 — Real-time streaming in the run node "View Details" (BE fold + FE SSE)

- **Symptom.** In a run, opening an agent node's **View Details** shows the Conversation as "waiting for an
  agent" while the agent is actually running; it only fills in after the turn completes. It should stream live.
- **Root cause (two parts).**
  1. `genesis/runs/steps.py::fold_iterations` delimits a turn by `agent.prompt → agent.result`. For a
     **running** turn (prompt seen, no result yet) it leaves `seq_end` frozen at the **prompt's** seq. The
     dialog (`web/src/features/run-detail/components/NodeIterationsDialog.tsx`) builds the Conversation from
     `nodeEvents` sliced to `seq_start..seq_end`, so it **excludes** every streamed `agent.message/thought`
     that follows → empty ("waiting for an agent") until `agent.result`.
  2. The dialog is **poll-based** (2.5 s via `useNodeIterations`/`useRunNodeEvents` while the run is active)
     and `TurnDetail` hardcodes `Conversation live={false}` — so even refreshed events don't render as a live,
     animating turn.
- **Fix.**
  - **BE:** in `fold_iterations`, advance a running turn's `seq_end` to the latest event seq belonging to it
    (update `cur["seq_end"] = e.seq` on each in-turn event, and/or set the trailing open turn's `seq_end` to
    the last event seq at fold end). This makes the running turn's slice include its in-progress events. Pure
    fold change; framework-free (reused by the introspection MCP).
  - **FE:** while the dialog is open **and** the run/node is active, **tail the run SSE** (reuse the existing
    `/api/runs/{id}/events/stream` EventSource pattern from `run-detail/hooks.ts::useRunStream`, but scoped:
    accumulate the **selected node's** `agent.*` events into local state and feed them to the running turn's
    `Conversation` with `live={true}`). Scope the stream to the open dialog + one node so the perf lesson (§7:
    don't fold the whole event log per tick) is respected — this is one node's deltas, only while the modal is
    open. Default-select the running/last turn when opening. Fall back to the existing poll when `EventSource`
    is unavailable (jsdom/tests).
  - Add a small `useRunNodeStream(runId, node, active)` hook beside `useRunStream` (single responsibility;
    closes the EventSource on unmount/terminal).
- **Tests.** `steps` test: a running turn's `seq_end` extends to include post-prompt events (the slice now
  contains the streamed messages). Dialog test: given a running turn + streamed node events, the Conversation
  renders them `live` (EventSource stubbed/guarded under jsdom). node-states/fold tests updated.
- **Notes.** True streaming per decision 4; matches the chat live-conversation UX.

### Fix 7 — Chat page shows feature/story stage chats (BE)

- **Symptom.** `/chat` lists chats created inside feature/story stages (UX Design, Technical Design, Feature
  Breakdown, Story Design). It should show only chats created from the chat page.
- **Root cause.** `genesis/api/chat.py::list_sessions` calls
  `chat.list_sessions(exclude_modes=("feature_spec",))` — it hides only `feature_spec`, so `ux_design`,
  `technical_design`, `feature_breakdown`, and `story_design` completion chats still appear. (`ChatStore.list`
  already supports `exclude_modes`.)
- **Fix.** Define a module-level constant of **non-conversational stage modes** in `genesis/chat` (e.g.
  `STAGE_CHAT_MODES = ("feature_spec", "ux_design", "technical_design", "feature_breakdown", "story_design")`)
  and pass it as `exclude_modes` in `list_sessions`, so `/chat` shows only `read_only` + `copilot` (the modes
  created from the chat page). Reuse the constant wherever the stage-mode set is needed to avoid drift.
- **Tests.** `chat` API test: sessions of each stage mode are excluded; `read_only`/`copilot` are included.
- **Notes.** One-line behaviour change + a shared constant; no schema/UI change.

### Fix 8 — Runs page count + pagination (BE + FE)

- **Symptom.** `/runs` shows the count as **100** while there are more, with no pagination. Add pagination of
  **20/page** without hurting performance.
- **Root cause.** `genesis/runs/store.py::RunStore.list(limit=100)` hard-caps at 100; `RunManager.list`
  passes it through; `genesis/api/run_routes.py::list_runs` returns the whole (capped) list and reconciles
  every non-terminal run each call; `web/src/features/runs/RunsPage.tsx` shows `runs.length` (=100) as the
  subtitle and does **client-side** filter/sort/split with no pagination.
- **Fix (standard server-side pagination — decision 3).**
  - **BE `RunStore`:** `list(*, status, workflow_id, limit, offset)` (add `offset`, keep `ORDER BY created_at
    DESC`) + `count(*, status, workflow_id) -> int` (cheap `COUNT(*)` with the same WHERE) + an optional `q`
    text filter (run_id/workflow substring) so search is server-side.
  - **BE `RunManager`:** passthrough `list(..., limit, offset, q)` + `count(...)`.
  - **BE `run_routes.list_runs`:** accept `status`, `workflow`, `q`, `limit` (default **20**), `offset`
    (default 0); return `{ "runs": [...], "total": N, "limit": L, "offset": O }`. Scope the orphan-reconcile to
    **only non-terminal runs** (a bounded set) rather than the whole page (keep the existing
    `reconcile_status` for active runs — few at a time — so performance is unaffected).
  - **FE `runs/hooks.ts` + `RunsPage.tsx` + `components/RunsTable.tsx`:** server-side pagination — page state
    (20/page), Prev/Next + "showing X–Y of TOTAL", status/workflow filters + search sent as server params (the
    "Active" status option maps to the active set server-side). Replace the client Active/History split with a
    single paginated table + the status filter (Active is already a status option). Poll the current page only
    while it contains an active run.
- **Tests.** `RunStore` test: `count` + `offset` paging + `q` filter. `run_routes` test: `{runs,total}`
  shape, limit/offset honored. Web test: pagination controls + total render; page changes refetch.
- **Notes.** The response shape changes (`[]` → `{runs,total,…}`); update the typed client + `RunsFilter`
  accordingly. `runs(created_at)` ordering is already indexed-friendly; `COUNT(*)` on the filtered set is cheap
  at these volumes.

### Fix 9 — Catalog shows internal MCPs as unmet prerequisites (BE)

- **Symptom.** Workflows like **Technical Design Analysis** / **Feature Breakdown Analysis** show
  `genesis-kb` + `appian-dev` as prerequisites marked "not available", disabling **Launch**. These are
  internal/managed components injected by the worker, not user-configured.
- **Root cause.** `genesis/api/catalog_routes.py` (`/catalog` + `/catalog/available`) returns
  `required_mcp` verbatim. The FE (`catalog/hooks.ts::useConfiguredSets` + `prereqFor`) marks any required MCP
  not present as `status:"configured"` in `/config/mcp-cards` as missing; the internal/managed servers never
  appear there → `prereq.met=false` → `WorkflowCard` disables Launch + `PrereqBadges` shows red chips.
- **Fix (backend — decision 5).** Define an authoritative internal/managed MCP set in the backend and strip it
  from `required_mcp` in **both** catalog responses, so the FE never sees or validates them:
  `_INTERNAL_MCP = {"genesis-kb", "genesis-memory", "genesis-introspection", "genesis-control", "appian-dev",
  "appian-devops"}`. A workflow requiring only internal MCPs then shows "No prerequisites" and Launch is
  enabled. (A run that genuinely needs a dev-tagged env still fails fast at start — e.g. the workbench
  design/implementation start 409s — so hiding these from the catalog gate is safe.)
- **Tests.** `catalog_routes` test: internal MCPs are stripped from `required_mcp` in `/catalog` (and
  `/catalog/available`); a non-internal required MCP (e.g. `jira`) is retained.
- **Notes.** Single source of truth in the backend; the FE prereq logic is unchanged.

### Fix 10 — Remove the "Linked apps" column from the Documents grid (FE)

- **Symptom.** `/documents` shows a "Linked apps" column that should be removed.
- **Root cause.** `web/src/features/library/DocumentTable.tsx` renders the "Linked apps" `<th>` and `<td>`
  gated on the `onRemove` prop (present on the global library page).
- **Fix.** Remove that `<th>`/`<td>` (decoupling the column from the Remove **action**, which is also gated on
  `onRemove` and stays). The per-app Business Artifacts tab is unaffected (it uses `onUnlink`).
- **Tests.** `library.test.tsx`: the "Linked apps" header is no longer rendered; the Remove action still is.
- **Notes.** Pure presentation; the `linked_apps` field on the row type is left intact (unused by the grid).

### Fix 11 — Move the CLI connector banners into each CLI's detail (FE)

- **Symptom.** Settings → CLI shows two banners (Google Workspace + SAIL CLI) at the top always; they should
  appear only on their own CLI's page (when that CLI is selected).
- **Root cause.** `web/src/features/settings/components/cli/CliTab.tsx` renders `<GwsConnectorCard/>` +
  `<SailConnectorCard/>` in a banner block above the `ResourceManager`.
- **Fix.** Remove the top banner block; render each connector card inside the per-CLI **detail**
  (`cli/CliDetail.tsx`) keyed on the selected resource name — `gws` → `<GwsConnectorCard/>`, `sail` →
  `<SailConnectorCard/>` (above the generic spec/status detail). Both are curated `cli-registry.json` entries
  (`gws`, `sail`), so they appear as selectable CLI cards — verified.
- **Tests.** `settings.test.tsx`: the gws card renders only when the `gws` CLI is selected; the sail card only
  when `sail` is selected; neither renders as a top banner.
- **Notes.** No behaviour change to the connectors themselves.

### Fix 12 — Settings: make General the first (and default) tab (FE)

- **Symptom.** General should be the first tab; today it is last and MCP is the default.
- **Root cause.** `web/src/features/settings/SettingsPage.tsx`:
  `TABS = ["mcp","cli","gitlab","environments","collaboration","general"]` and the fallback default is `"mcp"`.
- **Fix.** Reorder to `["general","mcp","cli","gitlab","environments","collaboration"]` and set the default
  `active` fallback to `"general"` (decision 6).
- **Tests.** `settings.test.tsx`: with no `:tab` param, General is active; General renders first in the tab
  list.
- **Notes.** Deep links to other tabs still work (URL is the source of truth).

---

## 4. Data model & migration

- **`m0022_story_sequence`** — the only schema change. Adds `kb_sequences (name TEXT PRIMARY KEY, next_val
  INTEGER NOT NULL)`, seeds `('story', 1)` (insert-or-ignore). `current_version` 21 → **22**. Additive +
  idempotent. Every `current_version == 21` head assertion in the test suite bumps to 22 (the §7 "a schema bump
  breaks the hardcoded head assertions" lesson).
- No other table changes. Fixes 4/5/8/9 are code-only; the story `key` column already exists.

## 5. ADR-072 (Proposed) — Global human-readable story identifier

- **Decision.** Finalized (and manually-added) stories receive a **globally unique, monotonic, human-readable
  identifier** `GNS_<6-digit>` (`GNS_000001`), allocated at write time from a durable counter
  (`kb_sequences`), stored in the existing `kb_stories.key` column. The id is **assigned locally** (at Finalize
  / story create) and **rides the existing story sync payload** to the Genesis Hub (`key` is a shared column —
  no Hub/contract change). Epics keep their workstream-derived key. Existing stories are not backfilled.
- **Why.** Stories need a stable, meaningful, shareable identifier across features and across teammates; a
  global running number is the simplest scheme that is unique install-wide and syncs without a Hub change.
- **Alternatives rejected.** Deriving from `MAX(key)` (gaps/races); per-feature/per-app scoping (not globally
  unique — decision 2 chose global); a Hub-side sequence (needs a Hub change — decision says none).
- **Consequences.** A new `kb_sequences` counter table (m0022); allocation inside the finalize/create tx
  (serialized). Mirror into `reference/decision-log.md` + `bible/04` on Accept.

## 6. Build order (sub-phases)

Each sub-phase is independently reviewable; group commits to keep the diff legible. **No build until the user
says go.**

- **44-01 — UI-layout fixes (FE):** fixes 1, 2, 10, 11, 12 (Applications tab order, feature delete,
  documents column, CLI banners, Settings tab order). One web commit + `web/static` rebuild.
- **44-02 — Chat list filter (BE):** fix 7.
- **44-03 — Catalog internal-MCP filter (BE):** fix 9.
- **44-04 — Story identifiers (BE + FE + m0022):** fix 3.
- **44-05 — Workbench system-move publish (BE):** fixes 4 + 5 (one change; 5 is fixed by 4).
- **44-06 — Runs server-side pagination (BE + FE):** fix 8.
- **44-07 — Real-time node view (BE fold + FE SSE):** fix 6.
- **44-08 — Review & release.** Independent review, all gates green, version bump + tag + push, docs, fleet
  restart.

(Order is a suggestion; 44-01/02/03 are trivial and independent; 44-04 carries the migration; 44-05/06/07 are
the substantive ones.)

## 7. Testing & gates (bible §6 / coding-standards §1)

- **Backend:** `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` + `ruff check genesis`; a
  regression test per BE fix (3,4,5,6,7,8,9); bump `current_version` head assertions to 22.
- **Web:** `cd genesis/web && npx tsc --noEmit && npx eslint . && npx vitest run && npm run build`; a test per
  FE fix; **jest-axe** on touched interactive screens (feature page delete, runs pagination); **rebuild +
  commit `web/static`** (stale-bundle guard).
- **Fresh DB → v22** (clean-install migrates); no data loss.
- No lint suppressions; no `<Button asChild>` (§7 lesson); reuse existing primitives/hooks; keep prop APIs
  stable.

## 8. Release plan

- **genesis-only** minor release (e.g. **v0.75.0**): bump `pyproject.toml` + `genesis/api/app.py` FastAPI
  version + `web/src/version.ts`; pins unchanged. Tag `vX.Y.0`, push master, verify CI green
  (`genesis` pytest, `frontend` stale-bundle guard, `clean-install` fresh DB → v22 + serves `/`).
- Docs: flip ADR-072 → Accepted (decision-log + bible/04); bible/01 state + tag; bible/08 §9 + tracker §6 →
  SHIPPED; `progress/phase-44-fixes-bundle.md` as-built; README row. Restart the fleet on the new version.

## 9. Out of scope / non-goals

- Backfilling `GNS_` ids onto **existing** stories (decision 2 — left as-is).
- Any Genesis Hub (Appian) contract change (fixes 3/4/5 need none).
- Reworking the runs Active/History UX beyond adding server-side pagination + the status filter.
- Epic identifiers (only stories get `GNS_`).
- Changing the design/implementation workflows themselves (fixes 4/5 are the missing publish only).
