# Phase 32 — Finalize Stories (Feature Breakdown → first-class, editable Story records)

> **Status:** 🟡 **SPECS DRAFTED (2026-09-04)** — awaiting user sign-off to build. ADR-060 **Proposed**. Umbrella + `phase-32-finalize-stories/32-01..32-05`. · **Author:** Genesis agent
> **Type:** single-repo — **genesis** (backend + web) + **one migration (m0016)**. genesis-core / kiro-agent-sdk / genesis-workflows / genesis-appian-parser **unchanged**. · **Depends on:** Phase 31 (the Feature Breakdown stage — its canonical `backlog.json` embedded in `breakdown.html` is this phase's input; `_parse_embedded_backlog`; ADR-059), Phase 28 (the Feature Workspace framework + the **reserved Stories tab slot**; ADR-056), Phase 25-01 (`LifecycleService`/`domain/` — the reserved `Story`/`Stage` entities + `STORY_STAGE_TRANSITIONS`; ADR-050 + m0013 audit) + 25-08 (`row_version` optimistic-lock CAS; m0014), Phase 20/21 (Features & the `FeatureStore`/feature-detail surface; ADR-042/044).

---

## 1. Why this phase exists

Phases 29–31 made the four feature **stages** live (Spec → UX Design → Technical Design → Feature Breakdown).
When Feature Breakdown completes, the feature's **entire backlog** — every epic + story + task, with types,
descriptions, Gherkin acceptance criteria, dev-note pointers — exists, but **only inside a file** (the
`backlog.json` embedded in `breakdown.html`). It is *reviewable* and *exportable to Jira*, but it is **not
first-class data inside Genesis**: you cannot browse it as records, edit a single story, or build the next
SDLC steps (per-story execution, deploy, git) on top of it.

**This phase turns that file into first-class, editable records.** Once Feature Breakdown is marked
**completed**, the lead performs a one-time **Finalize Stories** action that lifts every epic + story/task out
of the breakdown artifact and into real application tables. Stories then appear in the feature's (until-now
reserved) **Stories tab** as a formatted grid, each openable and **fully editable** (title, description, type,
parent, category, AC, dev note, questions, labels), with **add / delete**. This is the hand-off from *analysis*
to *managed backlog* — the data every upcoming phase (per-story execution — 25-11, and beyond) will build on.

ADR-056 explicitly **reserved the Stories tab slot** and ADR-050/25-11 defined the `Story`/`Stage` domain
entities "defined now; persisted by the backlog per-story work" and named **"Breakdown→Stories"** as the gate.
**This phase realizes exactly that reservation** — the persistence + CRUD + UI, without the per-story
*execution* lifecycle (that is the next phase; we only lay its forward-compatible `status` seam).

---

## 2. Goal

Make a finalized feature's stories first-class:

1. **Finalize Stories action.** When the **Feature Breakdown stage is `completed`**, a **"Finalize Stories"**
   button appears near the feature name (replacing the "Back to application" link in the feature header).
   Clicking it shows a **warning confirm dialog** ("All stories from the Feature Breakdown will be moved into
   the application. This is a **one-time** activity and **cannot be reverted**. Are you sure?"). On confirm,
   Genesis parses the canonical backlog from the finalized `breakdown.html` and **persists every epic + story/
   task** into new tables, stamps the feature as finalized, and lands the user on the **Stories tab**.
2. **Stories tab = a formatted grid.** Replaces the reserved placeholder with a real, well-formatted grid of
   all stories/tasks — columns for **Title, Type (Story/Task), Epic (parent), Category, Appian part** — that a
   lead can scan at a glance. Clicking a row opens the story's **detail page**.
3. **Story detail + full CRUD (story-level).** A routed detail page (`…/features/:id/stories/:storyId`)
   showing every field, with an **Edit** mode to change any aspect — **name, description, type, category, AC,
   dev note, labels, and parent** (removing/reassigning the parent presents a **dropdown of the feature's
   epics**). Plus **Add story** and **Delete story**. Optimistic-lock (`row_version`) protected.

**Success = a lead finalizes a completed breakdown once, then works the feature's backlog directly in Genesis
— browsing the grid, opening + editing stories, fixing a parent from the epic dropdown, adding/removing
stories — with all of it durably stored and ready to feed the next phases.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-04)

Firm inputs, not open questions.

1. **Action name = "Finalize Stories."** Placed in the feature header (right of the feature name), **replacing
   the "Back to application" link** (breadcrumbs remain the navigation). Shown **only** when the Feature
   Breakdown stage is `completed` and stories are **not yet finalized**; disabled with a tooltip until then;
   after finalize it becomes a subtle **"Stories finalized ✓"** indicator.
2. **Epics are first-class rows; stories are the CRUD unit.** The hierarchy is **Epic → Story/Task**. Epics
   (= the backlog's epics = the TD workstreams) are created **at finalize** and are otherwise **fixed** — this
   phase ships **story-only CRUD** (add/edit/delete stories); **no epic add/rename/delete**. A story's
   **parent** is its epic; editing the parent picks from the feature's epics (a dropdown).
3. **One-time, irreversible.** Finalize is a **one-time** activity, guarded by an explicit
   `kb_features.stories_finalized_at` marker (independent of story count, so deleting all stories later cannot
   re-open finalize). **No re-sync** — after finalize, the **stories become the source of truth**; later edits
   to `breakdown.html` do NOT flow back into the stories, and re-finalize is blocked (409) forever.
4. **Story `status` seam.** Each story carries a `status` column **defaulting to `design`** (the first
   `STORY_STAGE_TRANSITIONS` state) for forward-compatibility with the next per-story-execution phase, but the
   **status is NOT surfaced/edited** in this phase's UI.
5. **Routed detail page.** Story detail is a **routed page** (`…/features/:id/stories/:storyId`,
   deep-linkable) with an Edit mode — not a slide-over drawer.
6. **Genesis-only + one migration.** Backend + web + **m0016** (`current_version` 15 → **16**). No
   genesis-core / SDK / genesis-workflows change.

---

## 4. Current state (what we build on) — code-grounded

- **The canonical backlog already exists + already has a parser.** Feature Breakdown (ADR-059) embeds a
  canonical `backlog.json` in `breakdown.html` (`<script type="application/json" id="genesis-backlog">`), kept
  in sync by the completion-chat steering. `genesis/api/features.py::_parse_embedded_backlog(html_text)`
  extracts it (the CSV export uses it), and `_current_stage_html(row)` reads the finalized (chat-edited)
  sandbox `breakdown.html`. **Finalize reuses these exact helpers** — same lossless source as the Jira export.
  Backlog shape (per `_backlog_to_jira_rows`): `epics[]` each `{id, title, description, workstream?, stories[]}`,
  each story `{id, title, storyType("Story"|"Task"), category("core"|"nice-to-have"), appianPart, description,
  acceptanceCriteria[], devNoteRef, questions[], labels[]}`.
- **The domain already reserves this.** `genesis/domain/entities.py` has `Story`/`Stage` dataclasses,
  `enums.py` has `EntityKind.STORY` + the `STORY_STAGE_TRANSITIONS` machine (`design → implementation →
  code-review → deployment → verification → done`), all "defined now; persisted by the backlog per-story work
  (25-11)." This phase promotes `Story`/`Epic` to LIVE and persists them; the story-stage *execution* machine
  stays reserved (only the `design` default status is written).
- **The Stories tab slot is reserved.** `web/src/features/features/FeaturePage.tsx` renders a `StoriesReserved`
  placeholder in the `stories` tab and a **"Back to application"** `<Link>` in the `Page` `actions` slot — the
  two exact spots this phase changes. The tab framework (`overview·artifacts·activity·stories`) already exists.
- **Storage + concurrency patterns are established.** Forward-only migrations (`genesis/db/migrations/`,
  `current_version=15`, m0015 the latest — `CREATE TABLE IF NOT EXISTS` + a `Migration(version, name, up)`);
  per-entity stores (`FeatureStore`/`StageStore`); **`row_version` CAS** (m0014) → `StaleWriteError` → 409;
  `LifecycleService`/m0013 audit; the feature detail API (`GET /features/{id}` → `{feature, spec, stages, …}`).
- **`kb_features` cascades.** `kb_epics`/`kb_stories` FK→`kb_features(id) ON DELETE CASCADE` (like specs/stages)
  so untracking an app cascade-deletes its stories (ADR-042 intrinsic-to-app).

**Takeaway:** this phase = one migration (2 tables + 1 column) + a `StoryStore` + a finalize endpoint + story
CRUD endpoints + a web layer (header Finalize button/dialog, the Stories grid, the routed detail/edit page,
add/delete). **No workflow / core / SDK change.**

---

## 5. Data model (m0016) — finalized in 32-01

- **`kb_epics`** — `id PK · feature_id FK→kb_features(id) ON DELETE CASCADE · key TEXT (backlog epic id, e.g.
  "epic-1") · title · description · workstream TEXT (the TD workstream, nullable) · position INTEGER ·
  created_at · updated_at`. Created at finalize; fixed thereafter (no CRUD this phase).
- **`kb_stories`** — `id PK · feature_id FK→kb_features(id) ON DELETE CASCADE · epic_id FK→kb_epics(id) ON
  DELETE SET NULL (nullable — a parentless story is allowed but the UI encourages a parent) · key TEXT
  (backlog story id) · title · story_type TEXT ("Story"|"Task") · category TEXT ("core"|"nice-to-have") ·
  appian_part TEXT · description TEXT · acceptance_criteria TEXT (JSON array) · dev_note_ref TEXT · questions
  TEXT (JSON array) · labels TEXT (JSON array) · status TEXT NOT NULL DEFAULT 'design' (forward-compat, not
  surfaced) · position INTEGER · row_version INTEGER NOT NULL DEFAULT 0 · created_at · updated_at`. Indexes on
  `feature_id` + `epic_id`.
- **`kb_features` +`stories_finalized_at TEXT`** — the one-time-finalize marker (NULL until finalized).
- `current_version` → **16**. Every `current_version == 15` test bumps to 16 with the migration (the §7 lesson).

---

## 6. Finalize (backend) — finalized in 32-02

- **`POST /features/{id}/stages/breakdown/finalize`** (or `/features/{id}/stories/finalize` — 32-01 picks the
  route). Preconditions (**409** otherwise, with a specific reason): the **breakdown stage exists and is
  `completed`**; `stories_finalized_at` is **unset**. Then: read the finalized `breakdown.html`
  (`_current_stage_html`) → `_parse_embedded_backlog` → in **one transaction** insert all `kb_epics` +
  `kb_stories` (preserving order via `position`; `status='design'`), then stamp
  `kb_features.stories_finalized_at = now`. Return a summary (epic/story/task counts) or the created rows.
  Records a `LifecycleEvent`/activity entry (m0013) for the finalize.
- **Idempotent + safe:** a garbled/missing embedded JSON → 422 with a clear message (don't finalize an empty
  backlog). Re-finalize → 409. `_seed`/parse tolerant of extra keys.

---

## 7. Story CRUD (backend) — finalized in 32-02

A `StoryStore` (mirrors `FeatureStore`/`StageStore`) over `kb_epics`/`kb_stories`:
- `GET /features/{id}/stories` → `{ finalized_at, epics: [...], stories: [...] }` (stories carry their
  `epic` title for the grid; epics power the parent dropdown).
- `POST /features/{id}/stories` → add a story (title, story_type, epic_id, category, description, AC, dev note,
  labels, questions; `status` defaults `design`; appended `position`).
- `GET /features/{id}/stories/{story_id}` → full detail.
- `PATCH /features/{id}/stories/{story_id}` → edit any field incl. reassigning `epic_id`; **`row_version` CAS**
  → **409** `StaleWriteError` on a concurrent edit.
- `DELETE /features/{id}/stories/{story_id}`.
- Epics are **read-only** this phase (returned for the grid + dropdown; no epic write routes).
- Feature detail (`GET /features/{id}`) gains `stories_finalized_at` so the UI knows the state without a
  second call.

---

## 8. Web — finalized in 32-03

- **Feature header (`FeaturePage.tsx`):** replace the "Back to application" `<Link>` in the `Page` `actions`
  slot with a **"Finalize Stories"** control:
  - Breakdown not `completed` → **disabled** button + tooltip ("Complete Feature Breakdown to finalize
    stories").
  - Eligible → enabled button → **warning confirm Dialog** (the one-time/irreversible copy) → confirm →
    `useFinalizeStories` → invalidate feature + stories → switch to the **Stories** tab → success toast.
  - Already finalized → a subtle **"Stories finalized ✓"** badge (no button).
- **Stories tab:** replace `StoriesReserved` with `StoriesTab`:
  - Not finalized → an empty state ("Finalize the Feature Breakdown to populate stories" + the Finalize button
    when eligible).
  - Finalized → a **formatted grid** (a `Card` table like the Artifacts tab): columns **Title · Type
    (Story/Task badge) · Epic · Category · Appian part** (+ a row action / click → detail). Sortable/filterable
    as a nice-to-have; an **Add story** button.
- **Story detail (routed `…/features/:id/stories/:storyId`):** all fields read-only by default; an **Edit**
  mode with a form (title, description, `type` select, `category` select, **parent = an epic `<select>`**
  listing the feature's epics, AC list editor, dev note, labels, questions); **Save** (PATCH, row_version) +
  **Delete** (confirm). A route + a `StoryDetailPage`.
- **Types + api + hooks:** `types/features.ts` gains `Epic`/`Story`; `lib/api/features.ts` gains
  `finalizeStories`, `listStories`, `getStory`, `createStory`, `updateStory`, `deleteStory`; TanStack Query
  hooks + keys; jest-axe on the new grid + detail/edit. No shell edits (the ADR-056 plug-in invariant holds —
  Stories is an existing reserved tab).

---

## 9. ADR

- **ADR-060 (PROPOSED — this phase): Finalized Stories — the Feature Breakdown backlog becomes first-class,
  editable Story records under the feature.** When the Feature Breakdown stage is `completed`, a one-time,
  irreversible **Finalize Stories** action parses the canonical backlog embedded in the finalized
  `breakdown.html` and persists every epic + story/task into new **`kb_epics`/`kb_stories`** tables (m0016;
  `kb_features.stories_finalized_at` marks the one-time transition). Stories become **first-class, editable
  records** surfaced in the feature's (previously reserved) **Stories tab** as a grid, with a routed detail
  page and **story-level CRUD** (add/edit/delete; parent reassignment via an epic dropdown; `row_version`
  optimistic locking). Epics are created at finalize and are otherwise fixed (no epic CRUD this phase). Each
  story carries a forward-compatible `status` (default `design`) for the future per-story-execution phase, not
  surfaced now. **No re-sync**: after finalize the stories are the source of truth. **Realizes the ADR-056
  reserved Stories slot + the ADR-050/25-11 `Story` domain**; genesis-only + m0016; reuses `_parse_embedded_
  backlog`, `row_version` CAS (m0014), the `LifecycleService`/m0013 audit, and the feature-detail surface.

Mirror in `reference/decision-log.md` + (on Accept) `bible/04`.

---

## 10. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **32-01** | Data model & ADR | Lock the `kb_epics`/`kb_stories` schema + the `stories_finalized_at` marker + the backlog→rows mapping + the finalize/CRUD API contract + the `Story`/`Epic` domain entities + the routes; **draft ADR-060.** **Docs only.** | ⭐ user sign-off → build |
| **32-02** | Backend: store + finalize + CRUD | m0016 (`kb_epics`/`kb_stories` + `kb_features.stories_finalized_at`; `current_version`→16); `StoryStore`; the finalize endpoint (parse embedded backlog → persist → stamp; 409 guards; 422 on empty); story CRUD endpoints (`row_version` CAS → 409); feature detail exposes `stories_finalized_at`; promote `Story`/`Epic` domain to live; tests (+ bump `current_version` tests). | independent review = SHIP |
| **32-03** | Web: Finalize + Stories tab + detail/edit | Header **Finalize Stories** button + warning dialog (replacing Back-to-application); the **Stories grid**; the routed **story detail + Edit** page (parent epic dropdown); **Add/Delete**; types + api + hooks; jest-axe. Gates green; `web/static` committed. | independent review = SHIP |
| **32-04** | Code review & hardening | Independent review (one-time/irreversible correctness, 409/422 guards, `row_version` CAS, parse-from-canonical-JSON fidelity, cascade on untrack, a11y/dark-parity/no-hardcoded-hex/contract fixtures, no shell edits); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **32-05** | Release | genesis vX.Y.0 (single repo); tag; CI green (incl. clean-install DB upgrade to v16); docs (bible §2/§3/§4/§8 + tracker + progress + ADR-060 → Accepted) updated; report. | CI green |

**Suggested order:** 32-01 → 32-02 → 32-03 → 32-04 → 32-05 (linear; each gated on the prior).

---

## 11. Release plan

**Single-repo** (genesis only) + **m0016**. Per ADR-019 no dependent pins move (genesis-core/SDK/workflows
unchanged). Per-sub-phase: build → gates (pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`) →
local commit → independent review → docs; **no tag/push until 32-05 on the user's go-ahead**. The `clean-install`
CI job must migrate a fresh DB to **v16** and serve. A schema bump breaks every hardcoded `current_version==15`
test — bump them with the migration (the §7 lesson).

---

## 12. Scope

**In scope:** the m0016 tables + finalize marker; `StoryStore`; the one-time Finalize Stories action (parse the
canonical backlog → persist); the Stories grid; the routed story detail + Edit; **story-level** add/edit/delete;
parent (epic) reassignment; the forward-compat `status` seam.

**Out of scope (future):** per-story **execution** (the `STORY_STAGE_TRANSITIONS` workflow/stages — 25-11 and
beyond); **epic** add/rename/delete; re-sync from a re-edited breakdown; bulk edit/import; push-to-Jira;
multi-user/assignment/roles; story points; drag-reorder across epics (position is stored; a reorder UI is a
nice-to-have, not required).

---

## 13. Open questions

None blocking — all resolved with the user (2026-09-04): name = "Finalize Stories"; epics first-class but
story-only CRUD; one-time + irreversible + no re-sync; a forward-compat `status` defaulting to `design` (not
surfaced); a routed story detail page.
