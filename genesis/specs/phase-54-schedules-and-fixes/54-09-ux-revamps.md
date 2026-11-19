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

**Status:** BUILT 2026-11-19; review **SHIP** (re-run 1). Repo genesis, branch master, base `8f8b1a1`, head `2ad1c50`,
7 local commits (not pushed, not tagged). No migration; DB stays v30.

### Commits (genesis)

| sha | what |
|---|---|
| `85fb749` | §0 D42: `ZONE_RENAMES` and `zoneName` in `features/schedules/zones.ts`, applied to the picker options, the default machine zone and every zone shown (list, detail, wizard, preview) |
| `1368d8c` | §4 the activity merge (`genesis/services/feature_activity.py`), `summary` and `run_status` (D45 4), §3 the feature page (shared Tabs, Overview, Activity), `StatGrid` promoted to `shared/ui`, `lib/api/metrics` `ActivityItem`/`FeatureActivity` and `cr-flow.activityText` retired, golden fixtures |
| `a2b6c9d` | §1/§2 the story page: StatusHeader on every tab; SectionCard/DefinitionList/StatGrid/EmptyState; Design, Implementation, Verification tabs; `useRunProvenance`; `story-view` helpers |
| `6521608` | from the real-browser probe: the design frame's theme sheet (`frame-theme.ts`), Objects changed column floors and word-boundary wrapping, `awaiting_input:paused` is "paused"; the probe seed and page probe |
| `b932136` | `web/static` for `6521608` (67 files) |
| `0298731` | review round 1: M1 (CSP + nosniff on the read-only design artifact), M2 (gate-only decision card), m1, m2 |
| `2ad1c50` | `web/static` for `0298731` (64 files) |

Bundle proof (L-089): each bundle commit was checked with `git show --stat <sha> -- web/static` in its own call after
the build had exited. A rebuild in a later call left `git status --short --untracked-files=all` empty each time. The
reviewer's out-of-tree build matched `web/static` at `b932136` and `2ad1c50`. `85fb749`, `1368d8c` and `a2b6c9d` have
no bundle of their own; `2ad1c50` is the bundle of the final tree.

### Loaded before writing code

Full texts: L-014, L-039, L-063, L-069, L-073, L-083, L-089, L-090, L-094 and ADR-055, ADR-056, ADR-057, ADR-058,
ADR-071, ADR-076 (pack); L-010, L-011, L-015, L-091, L-096, L-109 and ADR-028, ADR-030, ADR-060 (`genesis-ctx`).

### Changed

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

- **Story page (`a2b6c9d`, `6521608`, `0298731`):**
  - every tab opens with a `StatusHeader`. Overview shows the lane, Design and Implementation with Edit; type and epic
    are shown only in the Details card;
  - `InfoCard`, `Row` (StoryWorkspacePage) and `Shell` (StoryTraceCards) are retired for `SectionCard` and
    `DefinitionList`;
  - Design:
    - "Edit / chat" is an `<a>` with `buttonVariants` (L-069);
    - "Re-run design" follows `designRerunBlock` (D45 7): on a board, in Design or Design Review, no run active.
      Otherwise the button is disabled and the reason is shown, linked by `aria-describedby`. It asks first
      (`ConfirmDialog`, "replaces the current design document"), and the 46-08 CR banner goes through the same
      confirm and shows the same reason;
    - the running, failed and none-yet states are SectionCard + EmptyState;
    - the frame's `src` follows `useTheme` live, on `bg-surface-1`;
    - `frame-theme.ts` writes one `<style>` from the current `:root` token values into the same-origin, scriptless
      frame on load. The generated document hard-codes light colours, and the read-only route adds no theme;
    - Details come from `GET /runs/{id}/provenance`;
  - Implementation:
    - `StatGrid` counts for Created/Updated/Deprecated and OK/Healed/Error;
    - the Objects changed table, with px floors from the probe (Type 9.5rem, Action 7.5rem, New version 6.75rem,
      Status 6.5rem). `ObjectName` adds a `<wbr>` after each underscore and at each camelCase hump;
    - "Documents" as shared Tabs in one card (D27): the report in `sandbox=""` and the rollback as Markdown. There is
      no open-in-new-tab (D45 10);
    - code review comes from the lane (D45 8);
    - Details show Duration and Credits from provenance, and no Environment (D45 6);
  - Verification:
    - `VerificationSection` is its own tab, no longer under every tab. `defaultStoryTab(ws, hasVerification)` opens it
      in the verification lane;
    - StatusHeader (stage, run, execution, last activity, "Open test report");
    - a "Waiting for your decision" card at a gate only (`waitsAtGate`, review M2);
    - Results with `StatGrid` totals under readable labels, the result and the defects;
    - the "Report" card under Results (D45 9);
    - Proposals;
    - Details (workflow, environment `env_label · env_url`, started, credits; no Test users, D45 6);
  - **opacity modifiers replaced** in files I revamped: `VerificationSection.tsx` gate panel
    (`border-warning/40 bg-warning/10`, now the card's `border-warning`), `StoryTraceCards.tsx` (`border-warning/40`,
    `border-info/40`, `decoration-fg-subtle/60`), and `FeaturePage.tsx` (`bg-surface-1/60`).
- **Backend, read-only design artifact (review M1, `0298731`):** `GET …/cards/{id}/design/artifact?annotate=0` now
  returns `Content-Security-Policy: script-src 'none'; object-src 'none'` and `X-Content-Type-Options: nosniff`, the
  same headers as the verification report. The annotate=1 chat view is unchanged. These are response headers only;
  the story API's shape is unchanged.
- **Paused vs gate:** `awaiting_input:paused` is "is paused" in Activity, not a gate. It is not a gate in Needs
  attention or the Verification tab either.
- **Probe scripts:** `scripts/probes/phase54-ux-seed.py` seeds a throwaway home through the stores (it refuses
  `~/.genesis`), and `scripts/probes/phase54-ux-pages.mjs` takes the screenshots and measurements below.

### Tests

- Backend (`tests/test_feature_activity.py`, 7):
  - order across all four sources (with the tie rule), labels, links, no CR audit rows, the 54-06 item keys;
  - paging (three pages equal the full list), the stage filter, the 400s and the 404;
  - paused vs gate; a source with no timestamp, or a missing run row, is left out;
  - `summary` and `run_status` on the detail, stage and spec reads; the summary of a new feature;
  - the read-only design artifact's CSP and nosniff (fails on the old route), with the annotate=1 view keeping its
    SDK;
  - it records `web/src/test/fixtures/features/feature-activity.json` and `feature-detail.json` from the real routes.
  Moved to the new shape, with the CR labels unchanged: `test_change_requests.py` (2), `test_cr_apply.py`,
  `test_cr_web_reads.py` and `test_metrics_api.py` (2). `run_status` is now asserted on the CR discard payload and on
  the Test Design start/rerun responses (review m1).
- Web:
  - `features/contract.test.ts` (2): `Exact<T>` key lists over the recorded fixtures, through `featuresApi`;
  - `features/overview.test.ts` (4) and `observability.test.tsx` ActivityFeed (5): labels, links, order, stage filter,
    Load more, empty state, jest-axe;
  - `features.test.tsx`: 3 new Overview tests (Needs attention order and links, no card for a new feature, shared
    Tabs; jest-axe). The stage-grid test now checks the prerequisite texts and that the stale texts are gone;
  - `StoryWorkspacePage.test.tsx` (14). Overview: StatusHeader, epic once, jest-axe. Design: header, run link,
    provenance, the frame following a live theme change on a token surface; Re-run confirm with jest-axe; three
    disabled-with-reason cases and the banner reason; running, failed and none states with jest-axe. Implementation:
    counts, table rows, the Documents tabs, sandbox, no new-tab link, no Environment, jest-axe. Code review never
    "Passed". Verification as its own default tab, not under Overview. Change history and banner tests updated;
  - `verification.test.tsx`: the tab layout (StatusHeader, labelled totals, Report after Results, Details, jest-axe),
    the gate card, and a paused run showing no decision card (fails on the old code). The existing section tests
    pass on the new layout;
  - `story-view.test.ts` (+4) and `frame-theme.test.ts` (2);
  - D42: `zones.test.ts` (+4) and `schedules.test.tsx` (+2). Both page tests failed on the pre-fix code.
  - `testDesign.test.tsx`: its card query was scoped, because the stage name is now also in the summary row.
- Gates:
  - full pytest: **2093 passed**, 20:49–21:00 IST (outside 00:00–02:00). The reviewer's re-run at `2ad1c50` gave
    **2095 passed**, finishing 21:57 IST;
  - `ruff check genesis` clean;
  - web `npm run lint` 0 errors (the 20 old warnings), `npm run typecheck` clean, `npm test` **81 files / 897 passed**;
  - `npm run build` + bundle proof as above.

### Screenshots (real browser, L-090)

`scripts/probes/phase54-ux-pages.mjs --base http://127.0.0.1:8791` ran against a separate `genesis serve` on :8791,
with a throwaway home `/tmp/p549c` seeded by `phase54-ux-seed.py` (never the fleet, never `~/.genesis`). The serve was
launched through a small `/tmp/p549c/serve.sh` wrapper, because the agent shell refuses a command line containing a
port; only that process was stopped and restarted (pid 7080), never the fleet's :8760/:8761.

The probe:
- covers 1280 / 1440 / 1920 px × light / dark;
- checks that Tailwind resolves, the theme class, page sideways scroll and element overflow;
- per table: header wrap, sideways scroll, cell spill and column widths;
- checks that the design frame's `theme=` and its body background equal the page's `--surface-1`.

Final run (after `0298731`): **54 views, all clean**. Every design frame background equals the surface: light
`rgb(255,255,255)`, dark `rgb(18,21,28)`. Earlier runs found:
- object names breaking mid-word at 1280 (seen in the screenshots, not by the checks; L-090);
- the white frame in dark mode.
Both are fixed in `6521608`.

The Objects changed columns at 1280 / 1440 / 1920 px are Object 163 / 270 / 409 px, then Type 152, Action 120, New
version 108 and Status 104 at every width.

Folder: `specs/phase-54-schedules-and-fixes/evidence/54-09/` (4 MB, JPEG q70) + `result.json`. Names are
`<name>-<width>-<theme>.jpg`:

| surface | names |
|---|---|
| Story Design | `story-design`, `portal-rerun-confirm` |
| Story Overview | `story-overview` |
| Story Implementation | `story-implementation`, `story-implementation-rollback` |
| Story Verification | `story-verification` (a run at a gate, a failed execution, defects, the report) |
| Feature Overview | `feature-overview` (every Needs-attention kind) |
| Feature Activity | `feature-activity`, `feature-activity-filter` (Test Design) |

### Review

`specs/phase-54-schedules-and-fixes/reviews/54-09-review.md`.
- **Round 1: NEEDS_CHANGES.**
  - M1: "Open in new tab" served agent-written design HTML as a top-level page on the app origin with no CSP.
  - M2: a paused verification run showed an empty "Waiting for your decision" card.
  - m1: `run_status` on the CR and Test Design responses was untested.
  - m2: the re-run banner gave the wrong instruction.
  - N1: the commit count; N2: offset paging.
- Fixed in `0298731`/`2ad1c50`.
- **Re-run 1: SHIP.** The reviewer re-ran every gate and saw each new test fail on the old code. The reviewer also
  checked the CSP live on :8791.
- N1 is corrected here (7 commits). N2 is recorded below as a known limit.

### Decisions / deviations

No ADR deviation.
- D45 (1–10, the user, 2026-11-19), as recorded in §0b.
- Mine:
  1. Ties in the activity order: the later source row comes first (runs before lifecycle at the same instant).
  2. A stage card's "Last run" shows the status only, not a time. The stage row has no run time, and its
     `updated_at` would mislabel it. D45 did not add a run time.
  3. The CR link of an activity item and of Needs attention opens the spec stage workspace (`…/features/<id>/spec`).
  4. `ActivityItem.stage` values are the backend's stage keys (`breakdown`, not 54-06's comment
     `feature_breakdown`). The type names `stage` as `ArtifactKind` and adds optional `cr_label`, `run_id` and
     `run_status` (recorded in 54-06's contract shapes).
  5. The mockup's local `StatGrid` was replaced by the shared one, so there is still one grid.
  6. **The design frame is themed client-side** (`frame-theme.ts`): the page writes one `<style>` built from the
     app's own token values into the same-origin, scriptless frame. The other option was a server-side dark sheet
     on the artifact route, a second home for the token values. The reviewer judged it safe (no untrusted content
     is injected).
  7. **CSP and nosniff on the read-only design artifact** (review M1). These are headers only, so the "no story API
     change" rule holds for the shape. A design opened in a new tab is the light document, as the workflow renders
     it.
  8. The design re-run banner (46-08) goes through the same gate and confirm as the header button, and names the
     same reason.
  9. Verification's "Open test report" is in the header (the mockup), and the Report card also has "Open in new tab".
     Both point at `report_url`.
  10. Needs attention counts a failed stage run but not a cancelled one: a cancel is the user's own act.
- **Known limit (review N2):** Activity pages by offset over a newest-first list, so an item that arrives between
  "Load more" clicks repeats one item. If it matters later, page by the oldest `at` already shown.

### Lesson candidates

1. **An iframe's `theme=` reaches only what the route themes.** The read-only design route ignored its `theme`
   parameter, and the agent document hard-codes light colours, so "theme-aware" was only in the URL. Only a probe
   that compares the frame body's computed background with the page surface caught it. A class test passes either
   way.
2. **A new link to an existing HTML route is a new exposure.** The read-only design artifact was safe inside a
   scriptless frame. Linking it with `target="_blank"` made it a top-level page on the app origin. Give every route
   that serves agent-authored HTML `script-src 'none'` and nosniff, not only the frames (review M1).
3. **`awaiting_input` is two states.** `awaiting_input:gate` waits for a decision and `awaiting_input:paused` does
   not. Matching on the prefix showed an empty decision card and would have labelled a paused run "waiting at a
   gate". Compare the full status (review M2; `runs/store.py` names both).
4. **A geometry probe passes text that wraps badly** (L-090 again). Object names broke mid-word with no overflow. A
   `<wbr>` at the identifier's own word boundaries (underscore, camelCase hump) fixed it without widening the column.

### Code-map changes (for genesis-docs, bible/03)

- `genesis/services/feature_activity.py` (new): `FeatureActivity.items/page/summary`, `with_run_status`,
  `STAGE_NAMES`.
- `genesis/api/features.py`: `GET /features/{id}/activity?stage=&limit=&offset=` → `{items, total}`;
  `GET /features/{id}` + `summary`; `_out` / `_with_badges` add `run_status`.
- `genesis/api/change_requests.py`: `register_change_request_routes(..., stage_out=)`.
- `genesis/api/testdesign.py`: the start/rerun responses carry `run_status`.
- `genesis/api/workbench.py`: the read-only design artifact sends CSP + nosniff.
- `genesis/kb/testdesign.py`: `TestDesignStore.live_case_count`.
- Web:
  - `shared/ui/stat-grid.tsx` `StatGrid`;
  - `features/features/overview.ts` (`needsAttention`, `prerequisiteText`, `stageRowOf`, `waitsAtGate`);
  - `featuresApi.activity`; `useFeatureActivity(id, stage)` is now paged;
  - `features/workbench/frame-theme.ts` (`applyFrameTheme`, `frameThemeCss`), `useRunProvenance`;
  - `story-view.ts` (`codeReviewState`, `designRerunBlock`, `storyStageStatus`; `StoryTab` + `verification`);
  - `DesignRerunBanner(block=)`;
  - `zones.ts` `ZONE_RENAMES`/`zoneName`.
- Removed: `metricsApi.featureActivity`, `lib/api/metrics` `ActivityItem`/`FeatureActivity`, `cr-flow.activityText`,
  and the page-local `InfoCard`, `Row`, `Shell`, `RunPanel`, `EmptyPanel`.
- `scripts/probes/phase54-ux-seed.py`, `phase54-ux-pages.mjs` (new).

### For 54-10 (live rows not run here)

- A real `story-design-analysis` re-run from the Design tab: confirm, the run starts, the card moves to Design, and
  the document is replaced.
- A real paused and a real gated `story-verification`: the decision card only at the gate, and the buttons answer
  the gate.
- The Design tab with a real agent-authored design in dark mode: the frame-theme sheet against the real
  `_DOC_STYLE`, `pre` and `.tag-*`, and "Open in new tab" with the CSP (the document stays readable).
- The Implementation tab on a real `story-implementation` run: real `objects[]` (free-text types), the report frame
  in dark mode (not checked here; it is an opaque `srcDoc` frame the theme sheet cannot reach), and provenance
  credits metered.
- The feature Activity tab on a real feature with CRs pulled from a teammate (CR-store items with no local audit),
  and a re-run stage (the older-run gap).
- The Needs attention counts against the fleet's real data after the release (`summary` reaches the fleet only with
  the release; D36).
- `scripts/probes/phase54-ux-pages.mjs` can be re-run against the release candidate's own throwaway server.

## Context manifest

```toml
areas    = ["stories-workbench", "features-stages", "web-shell", "api"]
adrs     = ["ADR-027", "ADR-050", "ADR-055", "ADR-056", "ADR-058", "ADR-068", "ADR-071", "ADR-076", "ADR-084"]
lessons  = ["L-014", "L-039", "L-063", "L-069", "L-073", "L-083", "L-089", "L-090", "L-094"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-43-unified-story-workspace.md"]
code     = ["genesis/web/src/features/workbench/**", "genesis/web/src/features/features/**", "genesis/web/src/shared/**", "genesis/genesis/api/features.py", "genesis/web/src/features/schedules/**"]
upstream = ["54-03", "54-06", "54-07"]
```
