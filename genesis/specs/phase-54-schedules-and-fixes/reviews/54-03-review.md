# Review 54-03 — base eed5da0, head cf5f3f6 (genesis-review, 2026-11-18)

What this change does: adds a dev-only route `/dev/phase-54` (a lazy chunk) with stub-data mockups of the 11 Phase 54
surfaces: Schedules list, wizard (dialog A and full page B), schedule detail, Catalog → Agents, bell, chat with a custom
agent, story Design/Implementation (A tabs, B stacked)/Verification, feature Overview/Activity. It adds four shared
primitives (`SectionCard`, `DefinitionList`, `StatusHeader`, `Timeline` + `timeline-groups`), 9 icons and a Playwright
width/theme probe. Commits `414735f` (source) and `cf5f3f6` (web/static). Both shas resolve. Nothing is pushed or tagged.

## Gates (run by the reviewer at cf5f3f6)

- `npm run lint`: 0 errors, 20 warnings. All warnings are in files this diff doesn't own. The two in `router.tsx` (46:10,
  52:10, `StoryRedirect`/`WikiRedirect`) come from code that existed at base.
- `npm run typecheck`: clean.
- `npm test`: 68 files, 802 passed. `phase54.test.tsx` has 24 tests and `section-blocks.test.tsx` has 6.
- Stale bundle: `npx --no-install vite build --outDir /tmp/54-03-review-static` then `diff -rq` against `web/static` gives
  **IDENTICAL**. `git status --short --untracked-files=all` is empty.
- `git show --stat cf5f3f6 -- web/static` lists 66 files (L-089). Main chunk: 4 126 526 → 4 127 531 bytes (+1 KB). The
  mockups are a separate 109 KB chunk `Phase54Mockups-tgUYSkHW.js`.
- Probe evidence: `evidence/54-03/` holds 126 jpgs plus `result.json`. 126 entries, 0 with issues, both themes present,
  `tailwind_ok` true throughout. I viewed `schedules-list-1280-light`, `schedule-detail-1280-dark` and
  `schedule-wizard-3-hourly-1280-light`.
- Python and playwright-appian gates: N/A. No Python, workflow or apwt file changed. The probe is a dev script under
  `scripts/probes/`.

## Checklist

### User rules for this sub-spec
- [OK] Stub data only, no API calls. No `fetch(`, `/api`, `useQuery` or `useMutation` in `dev/mockups/phase54` or the new
  shared files (grep). Imports are only `shared/ui`, `shared/layout/Page`, `shared/feedback/states` and `MarkdownView`,
  and none of them fetches. In-app `<Link>`s and the Edit / chat new tab do go to real routes, which is expected.
- [OK] Real value shapes (L-083). Run ids are `r-<12hex>`, keys are `GNS_000418`, `TE-000041/42` and `TC-0001xx`. Job
  keys match 54-01 §2.2. Outcome enums `fired|skipped|missed|ok|failed|cancelled` and `pause_reason
  user|failing|completed` match F1. Run statuses `done|failed|awaiting_input:gate|running|skipped` exist in `STATUS`
  (`badge.tsx:42-56`). Credits carry `metered|partial|unavailable`. D3's servers and allowlist sizes match 54-01 D3. The
  app uuids use the `_a-…_NNNNN` form. Gap: the per-app sync status is never shown (M1).
- [OK] Tokens and shared primitives only (ADR-027/055). A grep for raw palette classes, hex and `rgb(` in the new files
  finds nothing. `accent-[var(--primary)]` is a token. No `/NN` opacity modifier is used: the only hit is the comment at
  `timeline.tsx:27`.
- [OK] No `Button asChild` (L-069). The only `asChild` uses are Radix `PopoverTrigger` (`bell-chat.tsx:93`) and
  `DropdownMenu.Trigger` (`frame.tsx:65`), each over a native `<button>`. That is the pattern L-069 allows.
- [OK] Heavy libs lazy (L-015). `router.tsx` uses `lazy(() => import(...Phase54Mockups))`, and `main.tsx:20` wraps
  `RouterProvider` in `Suspense`. The main chunk grows by 1 KB.
- [OK] D3. `pickers.tsx:24-40` gives a blocked server `disabled` plus `aria-describedby` pointing at "Can't be picked:
  <reason>". The custom server is disabled until "This server only reads" is ticked. Tested in `phase54.test.tsx` ("step
  2b shows non-pickable servers…").
- [OK] D5. Both `agents.tsx` (In Chat note) and `bell-chat.tsx` `ReadOnlyNote` say chat keeps read-only tools. Tested.
- [OK] D8/D12. The list shows "Waiting at a gate" with "Cancelled in … if not answered · Answer", and a "Paused (failing)"
  row (`schedules.tsx:29-38`, `:96-101`). Tested.
- [VIOLATION] D9. All five forms are shown, with the time zone and the next 5 runs, and the dates check out: Mon/Thu, day
  31 → 30 Nov / 28 Feb 2027. But the "Every N hours" form has no weekdays control, although its own summary says
  "weekdays" (M2).
- [OK] D10. `missed` and `skipped` rows show their reasons in both histories (`fixtures.ts:196-210`). Tested.
- [VIOLATION] D15. Every field of `ApplicationSyncSection` is present except the per-app last status (M1).
- [OK] jest-axe per section (L-014). `expectAccessible` runs axe on every `[data-mock-frame]` with all rules, then on the
  section with `landmark-unique` off. That covers all 11 sections, the 6 wizard steps, the 5 frequency forms and both
  details. The jest-axe typing files are unchanged.
- [OK] Both options built where §2 asks for two. The wizard has dialog A and full page B, plus a real `Dialog`. The
  Implementation documents have tabs A and stacked B. Both are tested.

### ADRs
- [OK] ADR-027, ADR-055: see above. Radix dropdown is an ADR-027 stack lib that was already declared in `package.json:23`.
- [OK] ADR-028, L-010: no URL or `/api` in components.
- [OK] ADR-071: story mockups use the canonical `/applications/:appUuid/stories/:storyId` (`story.tsx:22`). The existing
  `…/design-chat` route is `router.tsx:92`.
- [OK] ADR-032: the credits total in `totalCredits` (`schedules.tsx:424-430`) sums only reported figures. Its provenance
  is metered, partial or unavailable, and nothing is estimated.
- [OK] ADR-031/033/034/045/086 (as UI text): the chat mockup shows read-only and disables Copilot. No trust code changed.
- [OK] ADR-049: only a `/dev` route was added. Nav is unchanged.
- [OK] ADR-058: prerequisites show as "Needs …" (`fixtures.ts:330-334`), not dimmed.
- [OK] ADR-068/082/084: the mockups only describe Implementation and Verification. The text says Verification runs on QA.
- [N/A] ADR-003, 007, 008, 011, 013, 019, 021, 026, 029, 043, 046, 047, 060, 061, 062, 063, 065, 069, 074, 075, 076, 078,
  080, 081, 083, 085: these cover backend, engine, distribution or collaboration. The diff touches none of it.
- [OK] ADR-077: this review used genesis-ctx retrieval only.

### Lessons
- [OK] L-014, L-015, L-069, L-083: see above.
- [OK] L-089: the build commit is separate and complete (66 files), and the out-of-tree rebuild is identical.
- [OK] L-090, with a gap: the probe runs Vite from `web/` and checks that a Tailwind class resolves. It uses 3 widths × 2
  themes, writes its own output directory, and the screenshots were taken. Gap: it never opens the portalled surfaces
  (m2).
- [OK] L-101: the probe loads Playwright from a local checkout or `$GENESIS_PLAYWRIGHT` and imports Vite from
  `web/node_modules`. It never runs a bare `npx`.
- [OK] L-011: the mockup types are local (`fixtures.ts`), and no `web/src/types` contract changed.
- [OK] L-109: D15's rule that the app-sync options have one home is shown. Only one `Weekdays only` control exists per
  form (but see M2).
- [N/A] L-012, 017, 025, 027, 030, 034, 043, 044, 045, 048, 051, 055, 056, 057, 061, 068, 081, 087, 088, 091, 092, 094,
  096, 098, 099, 100, 103, 104, 105, 107, 110, 112, 113, 115, 116, 117, 119: these cover backend, release, trust or
  testexec. The diff touches none of it.
- [OK] L-111: live acceptance is the user's D17 browser review. This report doesn't replace it.

## Findings

### Blockers
None.

### Majors
- M1 **The D15 app-sync detail drops the per-app last-sync status** (`schedules.tsx:578-592`, `fixtures.ts:212-216`).
  What: the "Last sync per application" table shows the kind, the time and the published Hub version. Problem: today's
  card also shows `a.last_status` when it isn't `succeeded` (`ApplicationSyncSection.tsx:246`), so a failed per-app sync
  is visible there. The mockup has no such field, and every fixture app has `status: "succeeded"`. A user approving this
  page would approve a detail page where a failed app sync is invisible, and 54-07 builds from the approved mockup. The
  user's rule says "all current ApplicationSyncSection fields". Fix: render `{a.status !== "succeeded" && <> ·
  {a.status}</>}` (or a danger `Badge`), set one fixture app to `status: "failed"`, and assert it in the "3. Schedule
  detail (app-sync)" test.
  If skipped: the field is lost at the approval gate.
- M2 **The "Every N hours" form can't express weekdays** (`schedules.tsx:282-291`). What: the hourly form has Every,
  From and Until only. Its summary reads "Every 2 hours, 08:00–18:00, weekdays" (`:255`; visible in
  `schedule-wizard-3-hourly-1280-light.jpg`). Problem: the app-sync default is exactly this form (`interval_window` every
  4 h, 08:00–20:00, `weekdays_only`, 54-01 §2.2). D9 says system schedules map onto these forms unchanged, and today's
  card has "Weekdays only" for both kinds (`ApplicationSyncSection.tsx:159`). Pressing Edit on the app-sync detail would
  open a form that can't show or change its own setting. Fix: render the same "Weekdays only" switch for `hourly` as for
  `daily` (move `:338-342` outside the `form === "daily"` guard, or add it to the hourly branch). Then assert
  `getAllByRole("switch", { name: "Weekdays only" })` in the hourly frequency test.
  If skipped: 54-07 inherits a form that can't round-trip the default system schedule.

### Minors
- m1 **"Edit / chat" is a button that calls `window.open`, not a link** (`story.tsx:89-91`). Problem: it navigates, but
  screen readers announce it as a button, and middle-click or "open in new tab" don't work. Today's page uses an `<a
  target="_blank">` (`StoryWorkspacePage.tsx:209`). The codebase's L-069-safe pattern for a link that looks like a
  button is `className={buttonVariants(...)}` on the `<a>`/`Link` (`ExecutionPage.tsx:269`, `LibraryItemPage.tsx:192`).
  54-09 will copy what the user approves. Fix: `<a href=… target="_blank" rel="noopener noreferrer"
  className={buttonVariants({ variant: "outline", size: "sm" })}>`.
- m2 **The probe never opens the portalled surfaces** (`scripts/probes/phase54-mockups.mjs:29-40`). Problem: the theme
  toggle drives the app theme store precisely so that dialogs and popovers portalled to `<body>` follow it. The probe
  only screenshots `[data-mock-section]` elements. So the real wizard dialog ("Open option A as a real dialog"), the
  New-agent dialog, the bell popover and the row menu were never measured or seen in either theme (L-090 Phase 51
  corollary: check the probe opens every screen it claims). Fix: add four variants that click those triggers, wait out
  the open animation, and screenshot the page/viewport.
- m3 **Two hand-rolled compact stat grids in one diff** (`story.tsx:240-257` `StatGroup` and `story.tsx:381-388`
  Verification "Results"). On deviation 2: a compact tile is a fair call for six counts, but the same diff then builds a
  second, different tile grid for the eight verification totals. That grid also labels tiles with raw keys (`not-run`,
  `flaky`), the raw-name problem 54-01 §4 lists for Activity. Fix: render the totals through `StatGroup` with labelled
  entries. Note in As built that 54-09 should give `MetricCard` a compact size (or promote `StatGroup`) rather than add a
  third grid.
- m4 **One on/off switch over two stored states** (deviation 5; `schedules.tsx:38`, `:120-121`). Problem: "KB Hub pull"
  (`enabled: false`) and "Hello Appian check" (`pause_reason: "user"`) look identical in the On column, and both offer
  "Resume" in the row menu. F1 keeps `enabled` and `pause_reason` apart, so the build must say which one the switch
  writes. This is not a code defect. Ask the user at the D17 review, and record the answer as a decision for 54-04/54-07:
  either the switch writes `enabled` only and Pause/Resume stay in the menu, or user pause is dropped in favour of
  `enabled`.

### Nits
- n1 `Timeline` uses the injected `now` for day labels (`timeline.tsx:51`), but `RelativeTime` (`:75`) always reads the
  real clock (`format.tsx:7`, which takes no `now`). With a fixed `now`, a group can read "Today" over items that say
  "3 days ago". Harmless in production, where `now` is undefined. Document it on the prop, or drop the prop and inject
  the date through `vi.setSystemTime` in the test.
- n2 `NEXT_RUNS` uses fixed 20 Nov 2026 dates (`fixtures.ts:181-187`) while every other time is relative to page load.
  If the user reviews after 20 Nov, the preview lists past runs as "next". The "Once" fixture schedule (`at(3D+2H)`)
  also doesn't match "28 Nov 2026 17:30".
- n3 `{s.failure_count} failure in a row` isn't pluralised (`schedules.tsx:75`).
- n4 The native `type="time"` inputs render "08:00 AM / 06:00 PM" in the screenshot, next to 24-hour words and previews.
  This is browser-locale behaviour. Mention it to the user, since the real form will do the same.
- n5 The "running" EmptyState uses a static `Loader2` (`story.tsx:146`). Pass `className="animate-spin"` if EmptyState
  forwards it, or use the running `StatusPill` alone.

### On the author's noted deviations
1. jest-axe with `landmark-unique` off only at section level: **accepted**. Every frame still gets the full rule set, so
   a duplicate inside one surface is still caught.
2. Local `StatGroup` instead of `MetricCard`: **accepted for the mockup**, but see m3.
3. Radix DropdownMenu directly in `frame.tsx`: **accepted**. It is an existing direct dependency (`package.json:23`,
   also used by `select.tsx`) in dev-only code. 54-07 should add a shared menu primitive in `shared/ui` rather than copy
   `RowMenu`.
4. App-sync options read-only with Edit: **accepted as an option for the user to judge**. D15 requires the content, not
   inline inputs. It only works once M2 is fixed, because Edit leads to the frequency form.
5. Switch shown as "fires or not": see m4. It needs the user's decision.
- Pre-existing finding (opacity modifiers on `var()` colours generate no CSS): **confirmed**. `bg-primary\/10` has 0
  matches in `web/static/assets/*.css`, 8 source files use `bg-primary/10`, and `tailwind.config.ts:24` defines `primary`
  as a bare `var(--primary)` with no `<alpha-value>`. The new code avoids it. It belongs in the backlog, not this
  sub-spec.

## Not checked
- The portalled dialogs, popover and row menu in either theme (m2). I did not drive them by hand either.
- Screenshots other than the three listed above. I relied on `result.json` (0 issues) for the remaining 123.
- Keyboard flow through the mockups (tab order, Escape on the real dialog). jsdom/axe doesn't cover it.
- The user's D17 browser review, which is the live acceptance for this sub-spec and still open.

## Verdict: NEEDS_CHANGES
Fix M1 and M2, each with its test assertion, rebuild and commit `web/static`. Then this can ship for the user's D17
review. m1–m3 are small and best done in the same pass, and m4 is a question for the user at that review.

---

## Re-run 1 — previous head cf5f3f6, new head 4b4046d (genesis-review, 2026-11-18)

Delta: `git diff cf5f3f6..4b4046d`. `93444a2` changes source (6 files, +150/−56: `fixtures.ts`, `schedules.tsx`,
`story.tsx`, `phase54.test.tsx`, `shared/ui/timeline.tsx`, `scripts/probes/phase54-mockups.mjs`). `4b4046d` is the
`web/static` build. `HEAD` resolves to `4b4046d44a04…`. Nothing is pushed or tagged.

### Gates (run by the reviewer at 4b4046d)
- `npm run lint`: 0 errors, 20 warnings, the same count as round 1.
- `npm run typecheck`: clean.
- `npx --no-install vitest run`: 68 files, 802 passed.
- Stale bundle: `npx --no-install vite build --outDir /tmp/54-03-rr1-static --emptyOutDir`, then `diff -rq` against
  `web/static`, gives no output (identical).
- `git show --stat 4b4046d -- web/static`: 66 files, +112/−112. The mockup chunk is renamed
  `Phase54Mockups-tgUYSkHW.js → -shl85QWY.js`. `git status --short --untracked-files=all` is empty (L-089).
- A grep for `asChild|fetch(|"/api|window.open` in `web/src/dev/mockups/phase54/` finds nothing.
- Fail-first: I did not re-run it, because stashing would write to the code tree. The diff confirms it would have failed:
  - the old hourly branch had no switch;
  - every old `APP_SYNC_PER_APP` row was `succeeded`;
  - the old Edit / chat was a `Button`, so `getByRole("link")` could not match.

  All three match the author's stated failures.

### Round-1 findings
- **M1: fixed.** `fixtures.ts:222` sets Vendor Onboarding to `status: "failed"`. `schedules.tsx:644` renders
  `{a.status !== "succeeded" && <> · <Badge tone="danger">{a.status}</Badge></>}`, which matches what today's
  `ApplicationSyncSection.tsx:246` shows. The test "3. Schedule detail (app-sync)" asserts
  `within(table "Last sync per application").getByText("failed")`.
- **M2: fixed.** The hourly branch (`schedules.tsx:299-309`) now renders `<WeekdaysOnly id={id} checked />`. Daily
  uses the same `WeekdaysOnly` component (`:350`, `:355-363`), so one control serves both forms (L-109). The frequency
  test asserts two `switch "Weekdays only"` for `hourly` and for `daily`, one per layout option. The hourly default is
  now checked, which matches its summary "…, weekdays" and the app-sync default.
- **m1: fixed.** Edit / chat (`story.tsx:79-83`) is an
  `<a target="_blank" rel="noopener noreferrer" className={buttonVariants(...)}>` with an sr-only "(opens in a new tab)".
  This is the L-069-safe pattern and matches `StoryWorkspacePage.tsx:209`. The test asserts the role `link`,
  `target=_blank` and the href `…/stories/418/design-chat`. Open in new tab (`:99-102`) uses the same pattern, but see
  n7.
- **m2: fixed.** `PORTALS` (`phase54-mockups.mjs:44-49`) opens four surfaces, each with its real trigger: the real
  wizard dialog, New agent, the bell (`/^Notifications, \d+ unread$/`) and the Memory maintenance row menu. For each one
  the probe:
  - waits for `[role=dialog], [role=menu], [data-radix-popper-content-wrapper]`, then 400 ms more;
  - measures the box against the viewport;
  - takes a screenshot and presses Escape.

  A portal outside the viewport counts as an issue (`:171`). No mockup frame renders an inline `role=dialog|menu`
  (`frame.tsx` uses `role="group"`), so the selector finds the portal. `evidence/54-03/` now has 150 jpgs. Its
  `result.json` has 150 entries, and all 24 `portal-*` entries are `portal_in_viewport: true`, with `theme_class`
  `theme-light`/`theme-dark` as expected. The boxes are plausible, for example the bell popover at
  `[1009,345,386,475]` at 1440. I viewed `portal-wizard-dialog-1280-dark` (the real dialog in dark, step 4 of 4),
  `portal-bell-popover-1440-dark` (the popover anchored under the bell) and `portal-row-menu-1280-light` (Run now
  disabled, Pause, Edit, Reset to default). All three render correctly in their theme.
- **m3: fixed.** One `StatGrid` (`story.tsx:201-217`) serves `StatGroup` (Implementation) and the Verification
  "Results" (`:354-356`). `TOTAL_LABELS` (`:311-314`) gives readable labels and is typed as `keyof typeof
  VERIFY_TOTALS`. It covers all 8 keys of `fixtures.ts:300`, so no total is dropped. The doc comment records that 54-09
  should promote it or give `MetricCard` a compact size. The change has one side effect: a value with a `cls` is now
  coloured when it is non-zero (`:212`), so the Implementation counts also take their tone. That is consistent and fine.
- **m4: open, by design.** It goes to the user at D17. The author says he will ask which field the switch writes. That
  answer must be recorded as a decision for 54-04/54-07.
- **n1: fixed.** `timeline.tsx:44` documents the prop. **n2: fixed, with a new nit (n6).** Previews and the once
  schedule are relative to page load in IST, and the once date is shared. The list ("Once on 21 Nov 2026 at 17:30 · in
  3 days") and the wizard review now agree in the screenshots. **n3: fixed** (`schedules.tsx:75-77`). **n4:** goes to
  the user. **n5: fixed.** A static `Clock` icon sits next to the running `StatusPill` (`story.tsx:126`).

### New findings (round 1 delta)

#### Blockers / Majors / Minors
None.

#### Nits
- n6 **The monthly preview skips this month's run** (`fixtures.ts:28-36`, `monthEnds`, "from next month"). On
  18 Nov the "day 31" form lists 31 Dec, 31 Jan, 28 Feb, 31 Mar and 30 Apr. The next real run is 30 Nov, and it is
  missing. The daily and weekly previews also start tomorrow (`nextDays` from `i = 1`, `daily` from day 1), so they skip
  today's later slots. The short-month rule still shows (28 Feb, 30 Apr), so the D9 check holds. The concrete case: a
  user at D17 reads "Next 5 runs" as the rule's real output. Fix: start from offset 0 and drop times `<= NOW`, for
  example `monthEnds` from `i = 0` with `.filter((t) => Date.parse(t) > NOW).slice(0, 5)` over 6 candidates.
- n7 **"Open in new tab" points at a route that doesn't exist** (`story.tsx:99`, `${STORY_URL}/design-artifact`). The
  router has `…/stories/:storyId` and `…/design-chat` (`router.tsx:91-92`) but no `design-artifact`. Clicking it during
  the D17 review opens the app's not-found page in a new tab. The link also lacks the sr-only "(opens in a new tab)"
  that Edit / chat has. Fix: add the sr-only text, and either point at an existing URL or note in the mockup copy that
  the real link is the document URL. 54-09 would build it as an `/api` document URL through a `lib/api` helper, like
  `featuresApi.crDocumentUrl` (`StoryTraceCards.tsx:21`).

### Checklist delta
Every round-1 checklist line stays as it was, except these:
- D9: **OK**. The hourly form now has Weekdays only, and both forms are tested.
- D15: **OK**. The per-app last status is shown and tested.
- L-090: **OK**. The probe opens every portalled surface it claims, and the gap is closed.
- L-069: **OK**. No `asChild` on Button, and links use `buttonVariants`.
- ADR-071: **OK**. Edit / chat targets the canonical `…/stories/:storyId/design-chat`. The `design-artifact` route is
  invented (n7), but it is a stub link in a dev mockup and creates no parallel story surface.

### Not checked (re-run 1)
- The probe run itself. I did not re-run the probe. `result.json` is timestamped 16:41 and `93444a2` was committed at
  16:42:45, so the evidence came from the working tree just before that commit. I relied on the clean tree and the
  identical bundle to treat it as the same source.
- The other 147 screenshots of the 150. I viewed only the three portal screenshots listed above.
- The keyboard flow (tab order, focus return after Escape). The probe presses Escape but asserts nothing about focus.
- The user's D17 browser review, which is still the live acceptance for this sub-spec, and the m4 decision it must
  produce.

### Verdict: SHIP
M1 and M2 are fixed, each with an assertion that fails on the old source. m1–m3 and n1–n3, n5 are fixed too. All gates
are green at `4b4046d`, and the bundle is identical to a fresh build. n6 and n7 are nits: fix them in passing or note
them for the user. They don't block the D17 review. m4 and n4 must be raised with the user at that review.

---

## Re-run 2 — previous head 4b4046d, new head 0342a12 (genesis-review, 2026-11-18)

What this round does: it applies the user's D17 browser-review answers to the `/dev/phase-54` mockups. The schedules
grid loses its Target column and gets a weekday strip, a tag-only last result with a tooltip, and a lock icon on system
rows. The wizard keeps only the full-page layout, the Implementation tab keeps only the tabs-in-one-card layout, and
the custom-agent chat has no Copilot toggle. Skills and servers are now picked through a new shared
`web/src/shared/ui/multi-select.tsx`, in both the wizard (with the custom agent's picks locked) and the agent editor.
The commits are `631fef6` + `33853ba` (re-run 1's n6, n7) and `f1a4b57` + `0342a12`. Delta reviewed:
`git diff 4b4046d..0342a12` (13 source files, +513/−242, plus 66 `web/static` files).

### Gates (run by the reviewer at 0342a12)
- `git rev-parse --short HEAD` = `0342a12`. `git status --short --untracked-files=all` is empty.
- `npm run lint`: 0 errors, 20 warnings, the same count as before.
- `npm run typecheck`: clean.
- `npx vitest run`: 69 files, 805 tests passed.
- Stale bundle: `npx vite build --outDir /tmp/54-03-r2-static` then `diff -r /tmp/54-03-r2-static web/static` gives no
  output, so the committed bundle is fresh. `git show --stat 0342a12 -- web/static` shows 66 files.
- Probe evidence: `evidence/54-03/result.json` has 162 entries (written 17:30), including the 6 portal kinds × 3 widths
  × 2 themes. I scanned it for `page_hscroll`, `overflow`, `tailwind_ok: false`, table `scrolls` and wrapped headers,
  and found 0 flagged entries. I viewed `schedules-list-1440-light`, `portal-server-multiselect-1440-dark` and
  `portal-last-result-tooltip-1440-light`, and each matches the D17 description.
- The Python and playwright-appian gates are N/A: no Python, workflow or apwt file changed. `scripts/probes/*.mjs` is a
  dev probe that no test runs.

### Re-run 1 nits
- n6: **fixed** (`fixtures.ts:23-45`). The `upcoming()` helper builds candidates from day offset 0, drops times
  `<= NOW` and keeps 5. `monthEnds` now starts with this month.
- n7: **fixed** (`story.tsx:99-103`). The stub link points at `#story-design`, has a `title`, and has sr-only text
  saying it is a stub. It no longer opens a missing route.

### The D17 requests, each checked
- The on/off switch writes `enabled` only: **OK**. `schedules.tsx` has `<Switch checked={s.enabled}>`. Pause and
  Resume are row-menu items, and both are disabled when the schedule is off. The test asserts that "Hello Appian
  check: on" is checked (a user-paused schedule) and that "KB Hub pull: off" is not. This closes round 1's m4.
- Application-sync options: **OK**, unchanged (not in the diff).
- No Copilot toggle in a custom-agent chat: **OK**. `bell-chat.tsx` drops the Switch, and the test asserts there is no
  `switch "Copilot"`.
- Step 2b shows the custom agent's skills and servers as locked picks: **OK**. `options.ts` `fromAgent` builds the
  locked map, and `schedules.tsx` passes it to both pickers, keyed by agent so a switch of agent resets them. The test
  finds 3 "· from KB explorer" chips and no Remove button on them. The screenshot shows locked rows checked and
  disabled, with "from KB explorer" beside them.
- Time inputs (native AM/PM in en-US): no code change. Confirming this with the user is still open (author's note).
- Schedules grid: **OK** on every point. The test asserts the column headers
  `Name, Frequency, Next run, Last result, On, Actions`, no "System" text, 5 `img "System schedule"`, the weekday
  strip's names, and the line above the grid. The screenshots show the remaining points:
  - The strip with monthly and once rows using an icon instead.
  - The zone shown only on the Europe/London row.
  - A tag-only last result whose tooltip reads "about 5 hours ago · Waiting at a gate: cancelled in about 19 hours if
    not answered".
  - The tag is a `Link` to `/runs/<id>`, or to the execution for a regression schedule.
  - `CADENCE` covers every `SCHEDULES` id (1–5, 11–15), and each short line matches that row's `frequency` text.
- Option B (full page) only: **OK**. The test asserts the `navigation "Wizard steps"` and no "Option A".
- Multi-select dropdowns in the wizard and the agent editor: **OK**. Both mockups use `pickers.tsx` on `MultiSelect`.
  Closed, it shows chips. Open, it has a search box and grouped checkbox lists ("Read-only servers" and "Can't be
  picked"), with the reason as the accessible description. The custom server counts only after "This server only
  reads" is ticked. Locked picks read "from <agent>". The unit tests and the 2b mockup test cover these, with jest-axe
  on the open popover.
- Implementation option A only: **OK**. The test asserts one `table "Objects changed"` and a `tab "Rollback
  document"`.

### MultiSelect keyboard path (real browser)
I ran a read-only Playwright probe of my own: `/tmp/54-03-kbd/kbd.mjs`, Chromium 1440×1000 against Vite from the
current source, on the agent editor's skills picker. The results:

| Step | Result |
|---|---|
| Tab from the "Remove gam" chip | focus lands on `button "Choose skills"` (the Add trigger) |
| Enter on Add | the popover opens, focus moves to `input[search] "Search skills"` |
| Tab ×9 | search, then the 5 skill checkboxes, then back to search. Focus loops inside the popover and it stays open |
| Shift+Tab from search | focus goes to the last checkbox and the popover stays open (it loops backwards too) |
| Escape from a checkbox | the popover closes and focus returns to `button "Choose skills"` |
| Space on a checkbox | it toggles: `appian` was removed and its chip disappeared. Escape returns focus to Add |
| Enter on a chip's Remove button | **focus drops to `<body>`** (m5). The next Tab reaches Add only because Chromium keeps the focus starting point |

Disabled options ("Can't be picked") are skipped by Tab, as native disabled checkboxes are. Their reason is exposed as
`aria-describedby`, which the tests assert. Opening, moving through, and closing with focus returned all work.

### New findings (this round's delta)

#### Blockers / Majors
None.

#### Minors
- m5 **Removing a chip by keyboard loses focus** (`multi-select.tsx`, the chip `<button aria-label="Remove …">` →
  `toggle(v)`).
  - What: the button removes its own chip, so the focused element unmounts.
  - Problem: the probe's last step shows that Enter on "Remove gam" leaves `document.activeElement === <body>`. A
    screen-reader user loses their place. A browser without a sequential-focus starting point sends the next Tab to the
    top of the page. This is now a shared primitive that 54-07 and 54-05 will reuse, so the issue spreads with it.
  - Fix: hold a ref on the trigger and call `triggerRef.current?.focus()` after `toggle(v)` in the two Remove handlers.
    Focusing the next chip's Remove button also works. Add a userEvent test asserting that focus is on "Choose …"
    after the removal (see n8).
  - If skipped: 54-07 ships the focus loss in the wizard and the agent editor.
- m6 **The Add trigger's accessible name doesn't contain its visible label** (`multi-select.tsx`, trigger
  `aria-label={\`Choose ${label}\`}` while the visible text is "Add").
  - Problem: this fails WCAG 2.5.3 Label in Name (level A). A voice-control user who says "click Add" gets no match.
    jest-axe does not check this rule, so the green axe runs don't cover it.
  - Fix: name it `Add ${label}` (for example "Add skills"), either through the aria-label or by dropping the aria-label
    and adding `<span className="sr-only"> {label}</span>`. Update the names in the tests and in the probe's `PORTALS`.
  - If skipped: the mismatch becomes the shared default.

#### Nits
- n8 **No keyboard test for the MultiSelect** (`multi-select.test.tsx`). The three tests use clicks only. A small
  userEvent test would pin the keyboard path the probe saw, so a later Radix bump or a switch to `modal` can't change
  it unseen: Tab to Add, Enter, focus on the search box, Escape, focus back on Add, plus the m5 assertion.
- n9 **Carry the zone-alias finding into 54-07** (author's own note, confirmed by reading `schedules.tsx`
  `canonicalZone`). On this host, `Intl` reports "Asia/Calcutta" for the machine. Comparing both sides after
  canonicalising handles that. 54-07's "default to the machine's zone" also has to map the machine's zone onto the
  picker's option values (`TIMEZONES` lists "Asia/Kolkata"), or the default matches no option. An unknown zone id
  makes `Intl.DateTimeFormat` throw `RangeError`, so 54-07 must validate stored ids before formatting them.

### Checklist delta
Every round-1 and re-run-1 line stays as it was, except these:
- ADR-027 / ADR-055: **OK**. `MultiSelect` uses the existing `@radix-ui/react-popover` 1.1.2 (`package.json:25`),
  `cn`, the curated `icons`, and design tokens only (`bg-warning-subtle`, `border-warning` and `shadow-e3` are already
  used elsewhere, for example in `EnvironmentsSection.tsx`). It adds no dependency.
- L-069: **OK**. The trigger is `PopoverPrimitive.Trigger asChild` on a native `<button>`, and `Anchor asChild` is on
  a `<div>`. There is no `Button asChild`.
- L-014: **OK**. The new tests import `axe` from `jest-axe` through the existing ambient types, and no new `.d.ts` was
  added.
- L-090: **OK**. The probe adds the two multi-select portals and the tooltip, and its `tailwind_ok` guard holds on all
  162 entries.
- L-089: **OK**. The bundle commit `0342a12` has 66 `web/static` files and matches a fresh build.
- ADR-028 / L-010: **OK**. The mockups make no fetch, and the links are SPA routes.
- Coding standards §3 (shared primitives, accessibility): **OK**, apart from m5 and m6. The primitive lives in
  `src/shared/ui`, is exported from `index.ts`, and has its own tests with jest-axe.

### Not checked (re-run 2)
- The keyboard path in Firefox and Safari, and with a real screen reader. My probe ran in Chromium only.
- 159 of the 162 screenshots. I viewed only the three listed above.
- The time-input AM/PM decision, which the author will confirm with the user.
- The probe's own run at 0342a12. `result.json` is from 17:30. I relied on the clean tree and the identical bundle.

### Verdict: SHIP
Every D17 request is implemented and pinned by a test or a screenshot. Re-run 1's n6 and n7 are fixed. All gates are
green at `0342a12`, and the bundle is identical to a fresh build. The MultiSelect's keyboard path works in Chromium:
Add can be reached by Tab, opening puts focus in the search box, Tab moves through the enabled checkboxes inside the
popover, and Escape closes it and returns focus to Add. m5 (focus lost after removing a chip) and m6 (the trigger's name
doesn't match "Add") are minors in a dev mockup's new primitive. Fix them before 54-05 and 54-07 reuse it, ideally with
n8's keyboard test, and carry n9 into 54-07.
