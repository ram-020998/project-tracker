# Review 54-07 — base a6cc287, head fb6982f (genesis-review, 2026-11-19)

What this change does: it fixes three backend follow-ups from the 54-06 review. n8 moves the options merge and the D35
model check into `ScheduleStore.update` under `BEGIN IMMEDIATE`. n7 refuses a schedule that runs on no day. D40 allows
one regression schedule per app (409 with `existing`). It builds the Schedules page (list, detail, full-page wizard),
Catalog → Agents and the notification bell, and moves the regression schedule and app-sync settings onto Schedules.
Last, it removes the old routes, components and types (F7, n3).

Repo genesis, branch master, 9 local commits `b94a976..fb6982f` (all resolve; not pushed, not tagged).

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `pytest -q -p no:warnings` (full, at fb6982f, 17:45–17:56 IST, outside 00:00–02:00, nothing deselected) | **2079 passed** in 656 s; tree clean afterwards |
| `ruff check genesis` | All checks passed |
| `npm run lint` | 0 errors, 20 warnings (react-refresh / one unused directive; none blocking) |
| `npm run typecheck` | clean |
| `npm test` | **843 passed**, 76 files |
| stale bundle: `vite build --outDir /tmp/54-07-static` + `diff -r … web/static` | identical |
| removal grep (every removed name, `git grep`, excl. `web/static`, `*.md`) | only a docstring (`schedule_routes.py:70`), the unrelated `TestSettingsService.update_settings`, a migration-test docstring and tests asserting 404 |
| cross-repo grep (`genesis-workflows`, `playwright-appian`, `genesis-fleet/bin`) for `/system/sync-settings`, `/system/schedules`, `testing/schedule` | no hits |
| real-browser evidence `evidence/54-07/result.json` | 96 entries, 0 with overflow / page h-scroll; `tailwind_ok` true; spot-checked `schedule-wizard-2b-agent-1280-dark.jpg` |
| playwright-appian / genesis-workflows gates | N/A: neither repo changed |

## Checklist

ADRs:
- [OK] ADR-010/018/022: no bulk in state. The pointer is `{id, summary, next_run}` (`regression_service.py` `regression_pointer`).
- [OK] ADR-021: the agent-prompt UI says the agent's tools are auto-approved (`ScheduleWizardPage.tsx`, the warning under Model); no new write path.
- [OK] ADR-026: no new network surface; the browser probe ran on loopback `:8790` with a throwaway state dir.
- [OK] ADR-027: shared primitives are reused (`SectionCard`, `DefinitionList`, `StatusHeader`, `MultiSelect`, `Dialog`). The new `RowMenu` uses the existing `@radix-ui/react-dropdown-menu`. No new dependency.
- [OK] ADR-028: all calls go through `schedulesApi`/`customAgentsApi`/`notificationsApi`; no `fetch(` or `/api` literal in a component (checked the new files).
- [OK] ADR-029/031/034/086: server picks stay `pickable` + `needs_read_only_mark`, gated by the confirm checkbox (`logic.ts serverOptions`, `wizard-model.ts serverPicks`). The store's `check_picks` is unchanged.
- [OK] ADR-032: history shows credits per row and a total with `provenance` (`ScheduleDetailPage.tsx HistoryTable`). Nothing is estimated.
- [OK] ADR-049: Schedules was added to `PRIMARY_NAV` after Runs (`nav.ts`); Settings → General lost the sync card (`SettingsPage.tsx`).
- [OK] ADR-055: light/dark tokens. No opacity modifier on token colours in the new files (`*-subtle`, `grad-brand-soft`); `opacity-50` is a plain utility.
- [OK] ADR-082: a regression target runs on QA; the copy says so. No new execution path.
- [OK] ADR-085: untouched.
- [N/A] ADR-001–009, 011–013, 019, 020, 023–025, 030, 033, 035–048, 050, 054, 056–069, 071–081, 083, 084: the diff touches no graph, worker, KB, feature-stage, Hub, test-execution, parser or packaging code. These lines were mapped only because the changed globs (`api/`, `features/**`) are broad.

Lessons:
- [OK] L-011: the pointer type has an `Exact<>` contract check against the recorded `testing/schedule-pointer.json` (`contract.test.ts`). `setup.json`/`regression.json` are asserted `null`, so a drift fails.
- [OK] L-014: jest-axe on the list, detail, wizard (three states), Agents tab and editor, bell, RowMenu and TimeInput (test list in `schedules.test.tsx`, `agents.test.tsx`, `bell.test.tsx`, `row-menu-time-input.test.tsx`).
- [OK] L-039: the setup GET and PUT return the same pointer (`test_the_old_schedule_route_is_gone_and_the_setup_read_points_to_the_row`).
- [OK] L-069: no `Button asChild`; `RowMenu` and the bell put a native button under Radix `asChild`.
- [OK] L-089: each build commit holds only `web/static`, and the bundle is fresh (diff above).
- [OK] L-090: the real-browser probe ran at 1280/1440/1920 × light/dark; its findings were fixed in `63e88f6`.
- [OK] L-091: the options merge, D35 and D40 now run after `BEGIN IMMEDIATE` (`schedule_store.py` `_locked`, `create_user`, `update`). The race tests `*_n8` ×2 inject the concurrent save between the route's read and its write.
- [OK] L-094: every consumer of the removed names was grepped, in both backend and web and in the other repos (above). `test_sync_jobs.py` moved to `/schedules?kind=system`.
- [OK] L-096: `schedules/new` comes before `schedules/:id`, and `catalog/agents` before `catalog/:workflowId` (`router.tsx`). The breadcrumb comment covers static vs param.
- [OK] L-109: frequency words and next runs come from the backend (`useSchedulePreview`, `s.summary`, `s.cadence`). `syncSchedule.ts`'s `windowSlots` is gone. `validate_sync_options` is the one options validator, and `regression_pointer` is the one pointer reader for the setup GET and the regression GET.
- [OK] L-110: gates re-run by the reviewer at the recorded head, from a clean tree.
- [OK] L-111: live fleet acceptance is not claimed. The "waiting at a gate" state was not seen live; the author says so.
- [N/A] L-001–010, 012, 013, 015–023, 025–031, 033, 034, 041–045, 048–051, 053–068, 070–076, 081–088, 092, 093, 095, 097–108, 112, 113, 115–119: no ACP/SDK, workflow, KB, Hub, packaging, CI, SSE, worker or browser-testing runtime code changed. L-112 (CI image) applies at the release, not here.

Gates: all OK (table above); the playwright-appian and genesis-workflows lines are N/A.

## The author's decisions

1. D40 refuses Duplicate of a regression row, and the 409 carries `existing {id, name}`. **Agree.** A copy would be a second schedule for the app. The wizard links to the existing row (`ScheduleWizardPage.tsx` `general`).
2. On the n8 model race, the save is refused rather than accepted unchecked. **Agree.** This fails closed, and a retry passes because the route then pre-reads the new model. Covered by `test_a_model_changed_by_another_save_is_checked_against_the_stored_one_n8`.
3. The Run dialog shows "Open run" instead of navigating. **Acceptable.** The approved mockup is the layout, and the link opens the run. §3's "Run opens the new run" is met by one click. Record it as a deviation in As built.
4. The regression step lists every tracked app, and an app that already has a schedule is disabled with a link. **Agree.** The backend refuses an untracked app either way.
5. The "Schedules › New" subtitle is dropped. **Agree.**
6. Agent skills come from `pickable.skills`, the same managed list. **Agree.**
7. One `regression_pointer` serves both GETs. **Agree** (L-109).
8. `LaunchFields` extraction. **Agree.** It behaves the same: `fs.slice(-1)` kept, ids `in-<name>` kept, and the LaunchForm tests pass.
9. `end_at` is stored as local `YYYY-MM-DDTHH:MM`. **Agree.** `scheduler.py:298` `parse_instant(end_at, tz)` treats a naive value as local to `tz` (`schedule_model.py:196-209`).

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **The wizard loses frequency fields it does not show** (`wizard-model.ts` `freqOf`/`toSpec`).
  - What: `freqOf` keeps `days` for an `interval_window`, but `toSpec` for the hourly form never writes `days`. `freqOf` also maps `daily_times` with `days` to the weekly form, and that form drops `weekdays_only`.
  - Problem: `updateBody` sends `schedule` on every user-row save. A schedule created through the API as `interval_window` with `days: [0,2,4]` (54-06 accepts it) loses its days when only its name is edited and saved, so it then runs every day. Likewise `days: [0,5]` + `weekdays_only` comes back as `[0,5]` and starts running on Saturdays. The wizard cannot create these shapes, so only API-made rows are hit.
  - Fix: pass `days` (when set) through `toSpec` for the hourly form, and keep `weekdays_only` on the weekly form. Add one `wizard-model` unit test that round-trips both shapes through `freqOf`→`toSpec`.
  - If skipped: an edit silently widens such a schedule.
- m2 **Not every MultiSelect use has a keyboard test** (spec §6).
  - What: the server pickers open by Enter and close by Escape (and the agent editor checks that focus returns), but the pick itself is a `user.click`. The two skill pickers (wizard and agent editor) have no keyboard test at all.
  - Fix: in the two existing tests, pick one server and one skill with `{ArrowDown}`/`{Space}` and check focus after Escape. That is about four lines each.
  - If skipped: the focus loss or name mismatch that jest-axe cannot see (54-03 m5/m6) stays unguarded for the skill pickers.
- m3 **Dead option `errorFor` on `LaunchFields`** (`LaunchFields.tsx:11,19,25`). It has no caller; the wizard shows `target.inputs` through its own `FieldMessage`. Fix: delete the prop (coding-standards §5).

### Nits
- n1 Sync options: a cleared number field is sent as `0` (`ScheduleWizardPage.tsx` `SyncOptions.setN`), so "Full sync every (days)" blank → 400 ("≥ 1") shown as the general message on the Review step rather than on the field. Optional: keep `""` in the draft and validate on the frequency step.
- n2 The regression wizard opened from Testing → Setup leaves Name empty. D14 names these rows "Regression: <app name>", so pre-filling it from the app would save typing.
- n3 `RunDetailPage.tsx:1`: the new import sits above the `react` imports, against the file's order.

## Not checked
- The live fleet (:8760/:8761) was not restarted or used. D36's condition (no fleet restart on the build in progress) still holds.
- The "waiting at a gate" detail and row in a real browser with a live gated run (fixture-tested only).
- The Radix DropdownMenu → ConfirmDialog hand-off in a real browser after the dialog closes (pointer events and focus). jsdom shows the dialog opening and Cancel working; the probe did not open Delete or Reset.
- Kiro's real model list (D38 e was exercised with `models: null` in fixtures only).

## Verdict: SHIP

No blockers or majors. Every gate is green, and the reviewer re-ran them all. m1–m3 are worth fixing before the release, in this sub-spec or as a listed follow-up. Write them into As built either way.

---

# Re-run 1 — base fb6982f, head d9c68b0 (genesis-review, 2026-11-19)

What changed: `efba8db` fixes round 1's m1–m3 and n1–n3, all in `web/src`. `d9c68b0` holds only the rebuilt `web/static`.
The backend is unchanged (`git diff --stat fb6982f..d9c68b0` lists no file outside `web/`), so round 1's backend gates
still stand (pytest 2079 passed at fb6982f).

## Gates (run by the reviewer at d9c68b0, tree clean)

| Gate | Result |
|---|---|
| `npm run typecheck` | clean |
| `npm run lint` | 0 errors, 20 warnings (the same 20 as round 1) |
| `npm test` | **854 passed**, 77 files |
| stale bundle: `vite build --outDir /tmp/54-07-r1-static` + `diff -r … web/static` | identical |
| `git show --name-only d9c68b0` | 64 files, all under `web/static/` (L-089) |
| fail-first, in a scratch export (`git archive efba8db web` into `/tmp/54-07-r1-ff`, repo untouched) | old `wizard-model.ts`: 3 of 9 `wizard-model.test.ts` cases fail (the two m1 shapes and `stepOfField("options")`). Old `ScheduleWizardPage.tsx`: the n1 and n2 tests in `schedules.test.tsx` fail (2 of 12). Each new test catches its bug. |
| backend pytest / ruff | not re-run: no backend file changed since fb6982f |

## Round 1 findings

- m1 **Fixed, and the fix opens a new case (M1 below).** The hourly form now keeps a stored `days` in
  `Freq.window_days` (`wizard-model.ts` `freqOf`/`toSpec`). The weekly form keeps a stored `weekdays_only`. The 7-shape
  round trip passes.
- m2 **Fixed.** `schedules.test.tsx` picks `team-confluence` with Enter, typing, Tab and Space, and checks that focus
  returns to Add after Escape. `agents.test.tsx` does the same for one server and for the `appian` skill, and the
  saved body asserts `skills: ["appian"]`.
- m3 **Fixed.** `git grep errorFor d9c68b0 -- web/src` finds no match.
- n1 **Fixed.** `SyncOptions.setN` keeps `""`, and `validate("frequency")` refuses it with "Fill in every sync option."
  inside the Sync options fieldset. The test checks that no PUT was sent.
- n2 **Fixed** (see n5 for an edge case).
- n3 **Fixed** (`RunDetailPage.tsx:5`).

## Checklist (re-run scope)

- [OK] ADR-027/055: no new primitive or colour; `FieldMessage` is reused in `SyncOptions`.
- [OK] ADR-028: no `fetch(` or `/api` in the diff.
- [OK] L-014: jest-axe still runs in both changed MultiSelect tests after the keyboard picks.
- [OK] L-089: the bundle commit is web/static only, and the bundle is fresh (above).
- [OK] L-109: the frequency words and next runs still come from the backend preview.
- [OK] L-110: the reviewer re-ran the gates at the recorded head and ran each new test against the old code.
- [VIOLATION] coding-standards §4 (test the change): the m1 fix has its round-trip test, but no test switches forms,
  which is how M1 is reached. The fix for M1 covers this.
- [N/A] Every other ADR and lesson from round 1: the diff touches only the wizard model, two wizard components, two
  tests and one import line.

## Findings

### Blockers
None.

### Majors
- M1 **"Weekdays only" now leaks from the Daily or Hourly form into Weekly, where it is hidden**
  (`wizard-model.ts` `toSpec`, the weekly branch: `...(f.weekdays_only ? { weekdays_only: true } : {})`).
  - What: `Freq.weekdays_only` is one field shared by the Daily, Hourly and Weekly forms. The Weekly form does not
    show the checkbox (`ScheduleWizardPage.tsx:457,490`, only Hourly and Daily render `WeekdaysOnly`). Before
    `efba8db`, Weekly never sent it. Now it sends it whenever the flag is set, whoever set it.
  - Problem: open New, choose Daily, tick "Weekdays only", switch to Weekly, and tick Mon and Sat. The wizard sends
    `{"kind":"daily_times","times":["09:00"],"days":[0,5],"weekdays_only":true,…}`. The reviewer reproduced this with a
    scratch test in `/tmp/54-07-r1-ff` (`defaultFreq` → `weekdays_only: true` → `form: "weekly"`, `days: [0,5]`). The
    schedule runs on Mondays only, although the Sat chip is ticked. With Sat + Sun it is refused (n7) and the Weekly
    form has no control to clear the flag. The user must go back to Daily, untick, and return. The preview shows the
    real next runs, so this is not silent, but it is a wrong result from ordinary clicks, and this diff introduced it.
  - Fix: handle it like `window_days`. Keep the stored value in its own field that only `freqOf` sets (for example
    `weekly_weekdays_only: boolean`, set from `spec.weekdays_only` in the weekly branch of `freqOf`), and have the weekly
    branch of `toSpec` read that field instead of `weekdays_only`. Add one `wizard-model.test.ts` case: `defaultFreq`
    with `weekdays_only: true` switched to `form: "weekly"` gives a spec with no `weekdays_only`. The 7-shape round trip
    must still pass.
  - If skipped: a weekly schedule made after touching the Daily checkbox runs on fewer days than its chips show.

### Minors
None.

### Nits
- n4 `stepOfField("options") → "frequency"` has no producer. The backend never refuses with `field: "options"`.
  `validate_sync_options` raises a `ValueError`, which `ScheduleStore.update` turns into a field-less `ScheduleError`
  (`schedule_store.py:376,405`). A range refusal, such as 150 typed into the "%" field, still shows as the general
  message on Review. Optional: tag that refusal `field="options"` in `_options_check`, so the mapping works, or drop the
  mapping.
- n5 n2 fills the name only when it is empty. Pick app A, go to Review (the name becomes "Regression: A"), go Back,
  pick app B, and return: the name is still "Regression: A". Optional: also refill when the name still equals the
  auto-name of the previous app.

## Not checked
- The wizard in a real browser after `efba8db` (form switching, the Sync options error placement). jsdom and the
  scratch probe only.
- The live fleet: not restarted or used (D36).
- Backend gates: not re-run, because no backend file changed.

## Verdict: NEEDS_CHANGES

M1 is a regression introduced by the m1 fix and is reachable by ordinary use. The fix is a few lines in
`wizard-model.ts` plus one test case. Everything else from round 1 is fixed, each fix's test fails against the old code,
and every gate is green. n4 and n5 are optional.

# Re-run 2 — base d9c68b0, head 41971a0 (genesis-review, 2026-11-19)

What changed: `5672ad1` fixes re-run 1's M1, n4 and n5 in four `web/src/features/schedules/` files (36 insertions,
8 deletions). `41971a0` holds only the rebuilt `web/static`. No backend file changed since fb6982f
(`git diff --name-only fb6982f..41971a0 -- genesis packages` is empty), so round 1's backend gates still stand.

## Gates (run by the reviewer at 41971a0, tree clean)

| Gate | Result |
|---|---|
| `npm run typecheck` | clean |
| `npm run lint` | 0 errors, 20 warnings (the same 20 as before) |
| `npx vitest run` | **855 passed**, 77 files (`/tmp/54-07-r2-web.log`) |
| stale bundle: `git archive 41971a0 web` → `/tmp/54-07-r2-ff`, `vite build --outDir /tmp/54-07-r2-static`, `diff -r … web/static` | identical |
| `git show --stat 41971a0` | 64 files, all under `web/static/` (L-089); `git status --porcelain` empty |
| fail-first, in `/tmp/54-07-r2-ff` with the d9c68b0 `wizard-model.ts` and `ScheduleWizardPage.tsx` (repo untouched) | 2 of 22 fail: `wizard-model > Weekdays only ticked on Daily does not leak into Weekly…` (old code adds `weekdays_only: true`), and `a regression schedule is named after its app unless a name was typed` at `schedules.test.tsx:308` (expected "Regression: Vendor Portal", got "Regression: Case Management"). Both pass at 41971a0. |
| backend pytest / ruff | not re-run: no backend file changed |

## Re-run 1 findings

- M1 **Fixed.** `Freq.weekly_weekdays_only` is set only in `freqOf`'s weekly branch (`wizard-model.ts:112`) and read
  only in `toSpec`'s weekly branch (`:129`); the Daily and Hourly forms keep using `weekdays_only` (`:121,131`,
  `ScheduleWizardPage.tsx:460,493`). The reproduction from re-run 1 (Daily, tick Weekdays only, switch to Weekly with
  Mon + Sat) now gives `{"kind":"daily_times","times":["09:00"],"days":[0,5],"timezone":…}`, pinned by the new case,
  which also checks that Hourly keeps the flag. The 7-shape round trip still passes, so a stored weekly
  `weekdays_only` survives an edit. `Freq` is built only from `defaultFreq` and spreads of it (grep of `web/src`), so
  the new required field reaches every producer. One behaviour shift, judged correct: editing a stored weekly row
  that has `weekdays_only` and switching it to Daily now shows the checkbox unticked, and the save matches what the
  form shows.
- n4 **Fixed** by dropping the mapping (`wizard-model.ts:201`) and its test line. A sync-option range refusal stays a
  field-less 400 shown as the general message on Review, as before; blank options are refused client-side on the
  frequency step (n1). Acceptable.
- n5 **Fixed.** `ScheduleWizardPage.tsx:164-169` refills "Regression: <app>" when the name is empty or still equals
  the last auto-name, and keeps a typed name. The extended n2 test covers app A → Back → app B → name follows, and a
  typed "Nightly vendors" surviving Back/Next. Editing an existing regression row keeps its stored name, because
  `autoName` starts null and the stored name is not empty.

## Checklist (re-run scope)

- [OK] ADR-027/055: no new primitive, colour or dependency in the diff.
- [OK] ADR-028: no `fetch(` or `/api` in a component; the only `/api` is the MSW handler in `schedules.test.tsx:66`.
- [OK] L-030/L-089: the bundle commit is web/static only, made after the build, and fresh (above).
- [OK] L-110: the reviewer re-ran every gate at the recorded head and ran each new test against the old code.
- [OK] coding-standards §4: each fix has a test that fails without it (fail-first row above).
- [OK] coding-standards §5 (lean): `weekly_weekdays_only` follows the existing `window_days` pattern; the n4 fix deletes
  code.
- [N/A] Every other ADR and lesson the check lists (ADR-011/019/021/026/029/031–034/045/046/063/065/068/069/074/076/
  077/080/082/083/085/086; L-017/025/027/044/045/051/056/057/087/088/092/098–101/104/105/111–113/116/117/119): the diff
  touches only the schedule wizard's model, page and tests, plus the bundle. No agent node, trust, chat, credits,
  release, pin or backend code is involved.

## Findings

### Blockers
None.

### Majors
None.

### Minors
None.

### Nits
None.

## Not checked
- The wizard in a real browser (form switching, the auto-name after Back). jsdom only.
- The live fleet: not restarted or used (D36).
- Backend gates: not re-run, because no backend file changed since fb6982f.

## Verdict: SHIP

M1, n4 and n5 are fixed. Each fix's test fails against d9c68b0 and passes at 41971a0, every gate is green, and the
committed bundle is fresh.
