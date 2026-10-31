# Review 49-08 H4 — Story coverage as a donut chart (49-01 D20) — base d138078 (genesis-review, 2026-10-31)

Scope: H4 only (49-08 §1.1, the H4 bullet). One genesis commit `5da9916` (resolved, = HEAD, clean tree). Web only:
`git diff --stat d138078 5da9916 -- . ':!web/static'` lists 5 files, all under `web/src/features/test-design/`; no
`package.json`, API, type or fixture change. Static review + gates + width probe. Live acceptance is out of scope for H4.

## Spec conformance (49-08 §1.1 H4)

| Requirement | Result | Evidence |
|---|---|---|
| Plain SVG, no chart library (L-015) | OK | `CoveragePanel.tsx` `Donut`: `<circle pathLength=100 strokeDasharray…>`; no dependency change |
| Colours from tokens, light + dark (ADR-027/055) | OK | `STROKE`/`SWATCH` maps use `stroke-success|warning|danger` / `bg-*`; compiled CSS `.stroke-success{stroke:var(--success)}` etc.; probe computed strokes light `rgb(21,128,61) / rgb(161,98,7) / rgb(185,28,28)`, dark `rgb(63,185,80) / rgb(210,153,34) / rgb(248,81,73)` |
| Story-type only, 3 exclusive slices; covered + needs_review>0 → Needs review only | OK | `logic.ts` `coverageSliceOf`; `logic.test.ts` "splits Story-type stories into three exclusive slices…"; `testDesign.test.tsx` "slices are mutually exclusive…" (GNS_000123 counted only under needs_review) |
| Zero-count slice not drawn | OK | `drawn = slices.filter(n>0)`; test "a pointer click on a slice… zero-count slice is not drawn" |
| Pointer click on a slice opens its dialog | OK | `onClick={() => onPick(s.key)}`; RTL test above; real hit-test in the probe (`sliceClick: "Not covered (2)"` at every width/theme) |
| Centre: covered % (Covered + Needs review) + "n of m stories"; Tasks excluded | OK | test asserts `67%` and `2 of 3 stories` with 2 Tasks present |
| Legend `<button>` per slice (swatch, label, count, %), Tasks line button, 0 → disabled, SVG `aria-hidden` | OK | `LegendButton disabled={count===0}`; tests assert names like `Covered: 1 story, 33%`, `Not covered: 0 stories, 0%` disabled, `aria-hidden="true"` on the svg |
| Dialog (existing primitive) "<Category> (n)": key, title, case count (not Tasks), Needs review badge, story-page links (ADR-071); no generate/top-up (D20) | OK | `CategoryDialog` uses `@/shared/ui` `Dialog`, `storyPath(...)`; test "each legend button opens a dialog with exactly its stories…" checks titles, exact hrefs `/applications/:app/stories/:id?from=feature&feature=1`, case counts, no `generate|top.?up` button, and navigation to the story page |
| Empty states | OK | test "Tasks only: no donut, only the Tasks line; no stories: the empty text" |
| Layout: 2xl stacked in 16rem column; below 2xl side by side; height not story-bound | OK | layout-pin test (`flex flex-wrap 2xl:flex-col`); probe: panel height 215 px (side by side) / 395 px (stacked) regardless of 14 Tasks + 6 Stories |
| jest-axe clean with the dialog open | OK | `axe(document.body)` with the Needs review dialog open, in the dialog test |

Decisions checked:
- **Colours** Covered=success, Needs review=warning, Not covered=danger. Spec names none; warning for Needs review matches
  the existing `NeedsReviewBadge` tone (visible in the dialog screenshot), so the existing warning-toned "Uncovered" badge
  would have collided. Accepted.
- **"Not covered"** follows the spec text; the badge elsewhere still says "Uncovered" (see nit n2).
- **Below 2xl** donut left-aligned beside a `sm:max-w-sm` legend; at 2xl donut centred above the legend. Matches spec §2.

## Checklist (`genesis-ctx check --since d138078 --repo genesis`)

Note: the check mapped every changed file to **no area** (`web/src/features/test-design/**` is not in
`context/areas.toml`), so only the always-on release-ci/security rules plus path-matched ADR-027/055 were listed. I added
the rules the H4 spec cites (L-015, L-083, L-089, L-090, ADR-071) by hand.

### ADRs
- [N/A] ADR-011 — reliability trio — no agent node or workflow touched.
- [OK] ADR-026 — local single-user, no auth — no server/bind/auth change (web-only diff).
- [OK] ADR-027 — established stack, existing primitives, tokens not raw palette — `Card`, `Dialog*` from `@/shared/ui`; only token classes (`stroke-success`, `bg-warning`, `text-fg-subtle`, `border-border`, `ring-focus`, `hover:bg-surface-2`); no `green-500`-style palette class in the diff.
- [OK] ADR-055 — evolve tokens + Tailwind, no `@mui/material` — no new dependency; both themes follow tokens (probe strokes differ per theme).
- [N/A] ADR-063 / ADR-065 / ADR-074 — collaboration / KB sync untouched.
- [OK] ADR-071 — one canonical story page — every dialog link is `storyPath(appUuid, story_id, featureId)`; test asserts the href and the navigation.
- [OK] ADR-077 — review run without bulk docs, no `--trust-all-tools`.

### Lessons
- [OK] L-015 — keep heavy libs lazy — no chart library added; plain SVG.
- [N/A] L-017 / L-045 — chat trust untouched.
- [N/A] L-025 / L-027 — no Python/ruff change.
- [OK] L-030 — commit touches `web/**`, so the frontend CI job (stale-bundle guard) will run.
- [N/A] L-051 / L-056 / L-057 — no release/tag/pin in this item (L-056: the commit carries the source, tests and bundle together — `git show --stat 5da9916`).
- [OK] L-083 — real value shapes in fixtures — the added story uses the full `CoverageStory` shape (`story_id, key "GNS_000127", title, story_type "Story", cases, needs_review, state "uncovered"`), mixed with the golden `suite-tree.json`.
- [N/A] L-087 / L-088 — agent-system/doc migration untouched.
- [OK] L-089 — bundle committed, then proven fresh: my out-of-tree `npx vite build --outDir /tmp/h4-review-static` + `diff -r /tmp/h4-review-static web/static` → **IDENTICAL**; `git status --short --untracked-files=all` → 0 lines.
- [OK] L-090 — real-browser geometry probe at several widths — re-run by me (below).

### Gates (run by me at 5da9916)
- [OK] `npm run lint` — 0 errors, 20 warnings (pre-existing; none in `features/test-design/`).
- [OK] `npm run typecheck` — clean.
- [OK] `npx vitest run` — 50 files, **467 passed** (dev claimed 467; base 459 → +8: logic +3, testDesign +5).
- [OK] Bundle freshness — identical (above).
- [Not verified] "With the source stashed, 10 of the new/changed tests fail" — needs a tree mutation I can't make (read-only). By inspection the tests could not pass against the base: they look up `region "Story coverage"`, `data-testid="coverage-donut"` and the legend button names, none of which exist at d138078.

## Width probe (L-090) — re-run by the reviewer

The dev's `/tmp/genesis-h4/out/probe.json` holds only **1280 and 1920** (a later 2-width re-run overwrote the 4-width
file; 1440/1536 survive only as screenshots). I re-ran the same probe unchanged except the output folder:
`node /tmp/genesis-h4-review/with-dev-server.mjs /tmp/genesis-h4-review/coverage-probe.js` (Vite :5199 over the clean
working tree at 5da9916, `/api` → serve v0.78.0 on :8760; read-only — the feature-6 suite GET is rewritten in the browser
to 2 Covered / 2 Needs review / 2 Not covered + 14 Tasks). Results: `/tmp/genesis-h4-review/out/probe.json` + PNGs.

| Width | Layout | Panel (w×h) | Donut | Legend w | Slice rows | Tasks line | Overflow / outside panel / page h-scroll | Dialogs (Tasks 14 · Needs review 2) | Slice click |
|---|---|---|---|---|---|---|---|---|---|
| 1280 | side by side | 984×215 | 144 | 384 | 1 line, not clipped | 1 line | none / 0 / no | 576×666 (list scrolls) · 576×286, in viewport | "Not covered (2)" |
| 1440 | side by side | 1144×215 | 144 | 384 | 1 line | 1 line | none / 0 / no | same | same |
| 1536 | stacked (2xl) | 256×395 | 144 | 214 | 1 line | 2 lines, word wrap | none / 0 / no | same | same |
| 1920 | stacked (2xl) | 256×395 | 144 | 214 | 1 line | 2 lines, word wrap | none / 0 / no | same | same |

Identical numbers in light and dark (`theme-light` / `theme-dark` on `<html>`). Every dialog: `keyWraps 0`, `metaPast 0`;
the only "clipped" element is the dialog close button's `SPAN.sr-only` (by design). Screenshots checked:
`panel-dark-1920.png` (stacked, Tasks line breaks after "through"), `panel-light-1440.png` (side by side), and
`dialog-needs_review-light-1280.png` (long titles wrap inside the row; badge and "8 cases" stay right-aligned on one line).
Slice labels are `whitespace-nowrap`; the Tasks line wraps only at a space. Spec item 4 passes.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **mi1 — probe evidence file doesn't match the claim.** The brief claims 1280/1440/1536/1920 results in
  `/tmp/genesis-h4/out/probe.json`; that file has 1280 and 1920 only. The 4-width data now exists in
  `/tmp/genesis-h4-review/out/probe.json` (all pass). Fix: when writing H4's As built, cite the reviewer's file (or
  re-run to a non-overwritten path) and record the measured sizes from the table above, as spec item 4 asks.
- **mi2 — H4 has no As built yet.** The spec says "As built under this item"; lines 410-436 hold only the plan. Fix:
  genesis-dev adds the H4 As built (commit 5da9916, tests +8, decisions above, this verdict, the probe sizes).

### Nits
- **n1 — area map gap (for genesis-docs).** `genesis-ctx check` maps `web/src/features/test-design/**` to no area, so
  web-shell/features-stages rules and gates (e.g. L-069, L-090) aren't listed automatically. Add the path to
  `context/areas.toml` (features-stages, or a test-design area).
- **n2 — terminology.** The legend says "Not covered" (per spec) while `CoverageBadge` elsewhere still says "Uncovered".
  Two words for one state; worth aligning in a later pass, not in H4 scope.
- **n3 — `!` non-null lookups.** `b.slices.find((s) => s.key === open)!` in `CoveragePanel.tsx` is safe today (keys come
  from the same three slices); `const slice = b.slices.find(...)` computed once would read cleaner. Optional.

## Verdict: **SHIP**

No blockers or majors; every gate green and verified independently; the width probe passes at 1280/1440/1536/1920 in
light and dark. Close mi1/mi2 in the As built (documentation only, no code change).
