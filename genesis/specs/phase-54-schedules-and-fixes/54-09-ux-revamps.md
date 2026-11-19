# 54-09 — UX revamps: story Design and Implementation, feature Overview and Activity

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis (`web/src/features/workbench/`, `web/src/features/features/`,
> `web/src/shared/`, `genesis/api/features.py`). Parent: `specs/phase-54-schedules-and-fixes.md`. Built by
> **genesis-dev** after 54-03's approval; **the approved mockup is the layout** (`web/src/dev/mockups/phase54/story.tsx`
> and `feature.tsx` at genesis `b09b08e`; D27, D28). Current state: `54-01-findings.md` §4. Decisions: D17, D18, D27,
> D28.

## 0. Carry-over from 54-07 (built first, with its own commit)

**D42, current zone names in the schedule zone picker** (`web/src/features/schedules/`, the zone helper 54-07 added):
add a map of legacy IANA alias → current name (`Asia/Calcutta` → `Asia/Kolkata` and the other legacy aliases browsers
list, from tzdata's `backward` links; keep it small and documented), apply it to the picker's options and the default
machine zone so new schedules store the current name, and show a stored alias under its current name. Nothing is
migrated; comparisons stay canonical. Tests: with the browser zone `Asia/Calcutta`, a new schedule stores
`Asia/Kolkata`; a stored `Asia/Calcutta` row shows `Asia/Kolkata` and saves unchanged unless edited; the list has no
duplicate entry for one zone.

## 0b. Decided during the build (D45, `54-01-findings.md` §8)

Data sources and layout points the spec and mockup left open, all ten settled by D45: CR items from the CR store only;
bound runs plus Test Design's top-ups (no matching by inputs); finalization label without an actor; `summary` and
`run_status` on `GET /features/{id}` (every stage-row read carries `run_status`, L-039; add both to 54-06's contract
table); no rolled-up badge or progress bar on the feature page; omit detail rows with no recorded data; Re-run design
gated and confirmed; code-review state from the lane ("Moved past code review", never "Passed"); the Verification
report kept as a "Report" card; no "Open report in new tab" on Implementation. Where §2–§4 differ, D45 wins.

## 1. Shared pieces

`SectionCard`, `DefinitionList`, `StatusHeader` and `Timeline` already exist in `web/src/shared/ui/` (built in 54-03,
exported from `shared/ui/index.ts`). Replace the page-local duplicates with them: `InfoCard` and `Row` in
`StoryWorkspacePage.tsx`, `Shell` in `StoryTraceCards.tsx:29`, the heading markup in `VerificationSection.tsx`. For
the Implementation counts and Verification totals, promote the mockup's compact `StatGrid` (local to
`web/src/dev/mockups/phase54/story.tsx`) to `shared/ui`, or give `MetricCard` a compact size; do not add a third grid
(54-03 decision 3). Tokens only (ADR-027, ADR-055), and no opacity modifiers on token colours (`bg-primary/10` and the
like generate no CSS, 54-03 As built); no `Button asChild` (L-069): link-styled actions use a link with button classes.
`RowMenu` and `TimeInput` are also in `shared/ui` now (54-07); use `RowMenu` for any row actions. Do not touch the
pre-existing opacity-modifier files 54-07 listed unless the page you revamp contains one (then replace it in that file
only and say so in As built).

## 2. Story page (`StoryWorkspacePage.tsx`, ADR-071: still the one canonical page)

- **Overview** keeps its content; it adopts the shared pieces and a StatusHeader (lane, design and implementation
  stage status) so all tabs share one header. Type and epic shown once (sidebar).
- **Design:** as approved (54-03 §2 item 7). The design frame follows the theme live (no reload) and has a surface that
  matches dark mode; run states, empty state and the re-run action use SectionCard + EmptyState; "Edit / chat" and
  "Re-run design" are real buttons; the stage status (draft, in review, completed) is shown.
- **Implementation:** as approved (item 8): stat tiles and the **Objects changed** table from `report.objects[]`
  (`useImplementationReport`), the report and the rollback document as **tabs inside one card** (D27), run and
  code-review state in the header.
  Size the table's columns from a real-browser probe (L-090).
- **Verification:** its own tab (item 9), shown when a verification exists; `defaultStoryTab` (`story-view.ts:21`)
  opens it for the verification lane.
- No API change for the story page: everything comes from `GET …/stories/:id/workspace` and the existing report call.

## 3. Feature page (`FeaturePage.tsx`)

- Shared `Tabs` instead of the hand-rolled tablist (`:94-106`).
- **Overview** as approved (item 10). **Needs attention** aggregates across stages from data the page already loads
  (`useFeature`: stages, spec, CR state) plus story and test counts; if a count needs a new field, add it to
  `GET /features/{id}` (54-06 contract table, additive). Remove the stale texts ("arriving in later phases",
  "status derived from stages", "no stage gates another"); show a stage's prerequisite as text (ADR-058, L-063).
- **Activity** (D18) as approved (item 11), over the extended endpoint below.

## 4. Feature activity endpoint (`genesis/api/features.py:667`)

`GET /features/{id}/activity?stage=&limit=50&offset=` returns `{items: ActivityItem[], total}` newest first (54-06
shape), merged from:
1. lifecycle transitions of **every** stage of the feature (`audit.list_for("stage", <stage id>)` for each row of
   `kb_feature_stages`), with today's CR labelling kept (`:675-690`);
2. stage runs: each stage's bound run(s) (`kb_feature_stages.run_id`, m0015, plus any run history the stage keeps) as
   `run` items with status and link to `/runs/<id>`;
3. change requests opened, applied, discarded (from the CR store);
4. story finalization (from the stories store / its audit).
Labels are human text built by program code (no raw state names in the web). List every source and writer of these
events before building (L-094); a source with no timestamp is left out and recorded in As built. A list method returns
the same derived fields as any single-item read (L-039).

## 5. Tests

Web tests for each tab with fixtures in the real shapes (L-083); jest-axe for every changed view (L-014); backend tests
for the activity merge (ordering, paging, stage filter, CR labels unchanged).

## 6. Gates

genesis pytest + ruff; web lint, typecheck, test; build + commit `web/static/` separately (L-089).

## As built

**Status:** IN PROGRESS. Stopped at a clean boundary (context about 60%). §0, §3 and §4 are built and committed,
plus the shared `StatGrid` from §1. §2 (the story page) and the rest of §1 are not started. No web/static build,
browser probe, full gate run or review yet. Repo genesis, branch master, base `8f8b1a1`, 2 local commits (not pushed,
not tagged).

### Commits (genesis)

| sha | what |
|---|---|
| `85fb749` | §0 D42: `ZONE_RENAMES` and `zoneName` in `features/schedules/zones.ts`, applied to the picker options, the default machine zone and every zone shown (list, detail, wizard, preview) |
| `1368d8c` | §4 the activity merge (`genesis/services/feature_activity.py`), `summary` and `run_status` (D45 4), §3 the feature page (shared Tabs, Overview, Activity), `StatGrid` promoted to `shared/ui`, `lib/api/metrics` `ActivityItem`/`FeatureActivity` and `cr-flow.activityText` retired, golden fixtures |

### Loaded before writing code

Full texts: L-014, L-039, L-063, L-069, L-073, L-083, L-089, L-090, L-094 and ADR-055, ADR-056, ADR-057, ADR-058,
ADR-071, ADR-076 (pack); L-010, L-011, L-015, L-091, L-096, L-109 and ADR-028, ADR-030, ADR-060 (`genesis-ctx`).

### Changed so far

- **D42** (`85fb749`). `ZONE_RENAMES` holds 18 renames from tzdata's `backward` file (eggert/tz main, fetched
  2026-11-19), only names present in Node's ICU 78 list: the 1995 two-part → three-part renames (Buenos_Aires,
  Catamarca, Cordoba, Indianapolis, Jujuy, Louisville, Mendoza) and the "alternate names" section (Asmera → Asmara
  via its `#= TARGET1`, Godthab → Nuuk, Calcutta → Kolkata, Katmandu → Kathmandu, Rangoon → Yangon, Saigon →
  Ho_Chi_Minh, Faeroe → Faroe, Kiev → Kyiv, Ponape → Pohnpei, Truk → Chuuk) plus Enderbury → Kanton. Links for merged
  zones (Europe/Amsterdam → Europe/Brussels and about 90 more) are left out: they are place names, not old spellings.
  A rename applies only when `Intl` accepts the current name. `zoneOptions` lists current names, sorted, one per
  zone; a stored alias replaces its zone's entry so it saves unchanged, labelled with `zoneName`.
- **§4 sources and writers (L-094)**, in `services/feature_activity.py`'s docstring:
  1. lifecycle: `lifecycle_transitions` kind `stage`, for every `kb_feature_stages` row. Writers: the spec actions
     route and the stage actions route (`api/features.py`), `StageFinalizer`, `TestDesignStageService`,
     `SpecChangeService` (CR transitions, not shown, D45 1).
  2. run: `kb_feature_stages.run_id` (written by `set_source` in the UX, Technical Design, Breakdown and Test Design
     launches) and `kb_test_topups.run_id`.
  3. change_request: `kb_spec_change_requests` (`SpecChangeStore.create`, the CR service's close, the collab pull).
  4. finalization: `kb_features.stories_finalized_at` (`StoryStore.finalize`).
- **Gaps (recorded, D45 2 and §4):**
  - A re-run overwrites `kb_feature_stages.run_id`, so older runs of a re-run stage are not shown.
  - Stage status writes outside `LifecycleService` leave no audit row, so they are not shown. These are
    `api/features.py` `set_status` in the deprecated `PATCH …/spec/status` (`:671`) and in the stage re-run/re-upload
    resets to in-progress (`:1105`, `:1145`, `:1407`), and `StageFinalizer`'s fallback `set_status(…, "in-review")`
    (`chat/stage_finalizer.py:168`).
  - A source row with no timestamp, or a bound run whose row is gone, is left out (tested).
  - Finalization has no actor.
- **`run_status` (D45 4):** one helper, `with_run_status`, used by `_with_badges` (`GET /features/{id}`, the single
  stage read, mark-reviewed) and `_out` (every other `features.py` response returning a stage row: create spec, get
  spec, spec actions, deprecated status, stage start/rerun/upload/actions). It is also used by `change_requests.py`
  `_spec_payload` (through `stage_out=`) and by the Test Design start/rerun routes.
- **`summary`** on `GET /features/{id}`: `FeatureActivity.summary` (stories, epics, `TestDesignStore.live_case_count`,
  stories with open questions, finalized stories not on a board, the newest activity time).
- **Web, feature page:**
  - shared `Tabs`;
  - Overview: `SummaryRow` (a `StatusHeader` with `StageProgress` and counts), `NeedsAttention` (pure
    `overview.ts needsAttention`, hidden when empty), stage cards showing `prerequisiteText` (with a lock icon) or
    "Last run <status>" instead of the blurb;
  - the rolled-up badge, the progress meter, `FeatureHealthCard`, `NeedsAttentionCard` and the three stale texts are
    removed;
  - `ActivityFeed` uses `Timeline`, `CategoryChips` (stage filter on the server) and `useInfiniteQuery` (50 per
    page, Load more).
- **Opacity modifier replaced** in a file I revamped: `FeaturePage.tsx` `bg-surface-1/60` on a locked stage card
  (the card is no longer dimmed, per the mockup).

### Tests so far

- Backend: `tests/test_feature_activity.py` (5 new): order across all four sources with a tie rule, labels, links,
  no CR audit rows, paging (3 pages equal the full list), stage filter, the 400s and the 404, a source with no
  timestamp, `summary` and `run_status` on the detail, stage and spec reads. It records
  `web/src/test/fixtures/features/feature-activity.json` and `feature-detail.json`. Four older tests were moved to the
  new shape, with the CR labels unchanged: `test_change_requests.py` (2), `test_cr_apply.py`, `test_cr_web_reads.py`
  (`test_activity_labels_the_cr_transitions`) and `test_metrics_api.py` (2).
- Web:
  - `features/contract.test.ts` (2, `Exact<T>` key lists over the fixtures);
  - `overview.test.ts` (4);
  - `observability.test.tsx` ActivityFeed (5: labels, links, order, stage filter, Load more, empty, jest-axe);
  - `features.test.tsx`: 3 new Overview tests (Needs attention order and links, no card for a new feature, the
    shared Tabs; jest-axe), and the stage-grid test now checks the prerequisite texts and that the stale texts are
    gone;
  - D42: `zones.test.ts` (+4), `schedules.test.tsx` (+2). Both page tests failed on the pre-fix code.
- Runs at `1368d8c`, 20:34 IST (outside 00:00–02:00):
  - pytest on the touched suites: 49 + 5 + 171 passed;
  - web: `src/features/features` 91 passed, `src/features/schedules` 36 passed;
  - `tsc` clean; eslint has 0 errors, and its warnings are the old ones in files I did not touch;
  - `ruff check genesis` clean.
- **Not run yet:** the full pytest, the full web suite, `npm run build`.

### Decisions / deviations

- D45 (1–10, the user, 2026-11-19), as recorded in §0b.
- Mine:
  1. Ties in the activity order: the later source row comes first (runs before lifecycle at the same instant).
  2. A stage card's "Last run" shows the status only, not a time. The stage row has no run time, and its
     `updated_at` would mislabel it. D45 did not add a run time.
  3. The CR link of an activity item and of Needs attention opens the spec stage workspace (`…/features/<id>/spec`).
  4. `ActivityItem.stage` values are the backend's stage keys (`breakdown`, not 54-06's comment
     `feature_breakdown`). The type now names `stage` as `ArtifactKind` and adds optional `cr_label`, `run_id` and
     `run_status`.
  5. The mockup's local `StatGrid` was replaced by the shared one (so there is still one grid).

### Resume note

**Done:** §0 (D42), §3, §4 and §1's `StatGrid`, in commits `85fb749` and `1368d8c`.

**Next, in order:**
1. **§2 story page** (`StoryWorkspacePage.tsx`, `StoryTraceCards.tsx`, `VerificationSection.tsx`, `story-view.ts`),
   following `dev/mockups/phase54/story.tsx`:
   - StatusHeader on every tab (lane, design and implementation stage status); type and epic only in the sidebar.
   - `InfoCard`, `Row` and `Shell` replaced by `SectionCard` and `DefinitionList`.
   - Design:
     - the frame's theme comes from `useTheme()` (live), on a `bg-surface-1` surface;
     - "Edit / chat" is a link styled with `buttonVariants`;
     - Re-run design is enabled only when the story is on a board, in Design or Design Review, with no run active;
       it asks first (`ConfirmDialog`, "replaces the current design document"); otherwise it is disabled with the
       reason (D45 7);
     - running, failed and empty states as SectionCard + EmptyState;
     - details (run, workflow, updated, lane, credits) from `metricsApi.runProvenance`.
   - Implementation:
     - `StatGrid` for created/updated/deprecated and ok/healed/error;
     - the Objects changed table;
     - Tabs inside one "Documents" card (report iframe sandbox="", rollback Markdown), with no "Open report in new
       tab" (D45 10);
     - code review from the lane: "Not started", "Waiting for review", "Moved past code review", never "Passed"
       (D45 8);
     - details without Environment (D45 6).
   - Verification:
     - its own tab when `useVerification` has something to show; `StoryTab` gains `"verification"` and
       `defaultStoryTab` opens it in the verification lane;
     - the gate panel, Results (`StatGrid` totals + defects), a "Report" card under Results (D45 9) and Proposals;
     - details: workflow, environment `env_label · env_url`, started, credits; no Test users.
   - Replace the opacity modifiers in `VerificationSection.tsx` (`border-warning/40 bg-warning/10`) and
     `StoryTraceCards.tsx` (`border-warning/40`, `border-info/40`, `decoration-fg-subtle/60`), and say so here.
   - No story API change.
   - Tests per tab with real-shape fixtures and jest-axe. Extend `StoryWorkspacePage.test.tsx`,
     `verification.test.tsx` and `story-view.test.ts`. A Re-run test should cover the confirm and the disabled
     reason.
2. Full gates: full pytest (note the time against 00:00–02:00 IST), `npm run lint && npm run typecheck && npm test`.
3. `npm run build`, then commit `web/static` in its own step, checked with `git show --stat <sha> -- web/static`
   after the build has settled; rebuild later and confirm `git status` is clean (L-089).
4. Real-browser probe (L-090):
   - a throwaway server on another port with a throwaway `GENESIS_STATE_DIR`, seeded (extend
     `scripts/probes/phase54-seed.py`);
   - the story Design, Implementation and Verification tabs and the feature Overview and Activity tabs at 1280,
     1440 and 1920 px, light and dark;
   - size the Objects changed columns from the probe;
   - screenshots under `evidence/54-09/`.
   - Never touch `~/.genesis/genesis.db`, and do not restart the fleet.
5. Spawn genesis-review on `8f8b1a1..HEAD`; fix findings until SHIP.
6. Fill in the rest of this As built: review, screenshots, lesson candidates, code-map changes, "For 54-10".

**Open problems:** none. 54-06's contract table already has the `summary`/`run_status` row (D45). Add a line there
for the `ActivityItem` additions (`cr_label`, `run_id`, `run_status`) and the stage-key correction.

**Code-map changes so far (for genesis-docs):**
- `genesis/services/feature_activity.py` (new): `FeatureActivity.items/page/summary`, `with_run_status`,
  `STAGE_NAMES`.
- `genesis/kb/testdesign.py`: `TestDesignStore.live_case_count`.
- `api/change_requests.py`: `register_change_request_routes(..., stage_out=)`.
- web: `shared/ui/stat-grid.tsx` `StatGrid`; `features/features/overview.ts` (`needsAttention`, `prerequisiteText`,
  `stageRowOf`, `waitsAtGate`); `featuresApi.activity`; `useFeatureActivity(id, stage)` is now paged; `zones.ts`
  `ZONE_RENAMES`/`zoneName`.
- Removed: `metricsApi.featureActivity`, `lib/api/metrics` `ActivityItem`/`FeatureActivity`, `cr-flow.activityText`.


## Context manifest

```toml
areas    = ["stories-workbench", "features-stages", "web-shell", "api"]
adrs     = ["ADR-027", "ADR-050", "ADR-055", "ADR-056", "ADR-058", "ADR-068", "ADR-071", "ADR-076", "ADR-084"]
lessons  = ["L-014", "L-039", "L-063", "L-069", "L-073", "L-083", "L-089", "L-090", "L-094"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-43-unified-story-workspace.md"]
code     = ["genesis/web/src/features/workbench/**", "genesis/web/src/features/features/**", "genesis/web/src/shared/**", "genesis/genesis/api/features.py", "genesis/web/src/features/schedules/**"]
upstream = ["54-03", "54-06", "54-07"]
```
