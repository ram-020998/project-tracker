# 54-07 — Web: Schedules page, Catalog → Agents, notification bell, moves out of Settings and Testing

> **Status:** SPEC-DRAFTED 2026-11-19. Repo: genesis (`web/`). Parent: `specs/phase-54-schedules-and-fixes.md`. Built
> by **genesis-dev** after the 54-03 mockups are approved; **the approved mockup is the layout** (read 54-03's As built
> and any decisions it added to 54-01 §8 first). Contract: 54-06.

## 1. Navigation and routes

- `PRIMARY_NAV` (`web/src/shared/layout/nav.ts:15-23`): add **Schedules** (`/schedules`, a clock/calendar icon from
  `shared/ui/icons.ts`) after Runs; the command palette picks it up (`CommandPalette.tsx:59`).
- Routes (`web/src/app/router.tsx`): `/schedules`, `/schedules/new`, `/schedules/:id`, `/schedules/:id/edit`,
  `/catalog/agents` (static, registered before `catalog/:workflowId`, as `catalog/skills` is at `:69-70`), and the
  breadcrumbs for each (`shared/layout/breadcrumbs.ts`).

## 2. Schedules page (`web/src/features/schedules/`, new)

The layout is the approved mockup (`web/src/dev/mockups/phase54/schedules.tsx`, genesis `b09b08e`; D22–D25, D28):
build the real page from it and its shared pieces (`SectionCard`, `DefinitionList`, `StatusHeader`, `MultiSelect` in
`shared/ui`), not from 54-03 §2's starting text. In short:
- **List (D22):** no Target column; Frequency = weekday strip + short line from `cadence` (54-06), a calendar icon for
  monthly and once; zone only when it differs from the machine's; Last result = status tag linking to the run or
  `TE-` execution, tooltip with time, reason and a gate's cancel time; lock icon on system rows and the line "System
  schedules can't be deleted. You can change when they run or turn them off."
- **Switch and menu (D23):** the switch writes `enabled` only; Pause / Resume, Run now, Duplicate, Delete or Reset to
  default are in the row menu; Run now and Pause/Resume are disabled while a schedule is off.
- **Row menu:** add a shared menu primitive in `shared/ui` (over `@radix-ui/react-dropdown-menu`, already a
  dependency) and use it here; the mockup's `RowMenu` is dev-only (54-03 decision 4).
- **New / edit (D24):** a full page (`/schedules/new`, `/schedules/:id/edit`) with the step rail and running summary;
  skills and servers through `MultiSelect`; a picked custom agent's skills and servers as locked chips "from <agent>".
- **Application-sync detail (D25):** options shown as text with an Edit button.

Rules:
- the frequency summary and next runs come from the backend (`summary`, `next_runs`, `POST /schedules/preview` while
  editing); the web never computes slots (one home, L-109; `settings/components/syncSchedule.ts` is removed with its
  card);
- the workflow step reuses `buildLaunchForm` (`features/catalog/launch-schema.ts:38`) and `LaunchForm` widgets; file
  widgets are not offered (54-05 §5);
- servers, skills, models and workflows come from `GET /schedules/pickable`; a non-pickable server is shown disabled
  with its reason (D3); a custom server needs the "this server only reads" checkbox;
- system rows show only their editable fields (`editable_fields`), no Delete, a **Reset to default**;
- the `application-sync` detail holds everything today's `ApplicationSyncSection.tsx` shows (D15), then that component
  and its mount in `SettingsPage.tsx:68` are removed;
- history shows outcome pills (including `missed` and `skipped` with the reason), run links, duration, credits with
  provenance (ADR-032) and the total;
- Paused (failing) and waiting-at-gate states are visible on the row and the detail, with Resume / Open run;
- delete asks for confirmation and says the runs stay in Runs (F8);
- **time zones (54-03 decision 11):** browsers may name the machine's zone by an alias ("Asia/Calcutta" for
  "Asia/Kolkata" on this Mac). Compare zone ids only after canonicalising both through `Intl` (`resolvedOptions()`),
  map the machine's zone onto the picker's option values when defaulting to it, and validate a stored id before
  formatting (an unknown id throws `RangeError`); test with the alias;
- **no opacity modifiers on token colours** (`bg-primary/10`, `border-warning/40`, …): with colours mapped to bare
  `var()` they generate no CSS (54-03 As built). Use the `*-subtle` tokens or `grad-brand-soft`.

## 3. Catalog → Agents (`web/src/features/catalog/agents/`, new)

Third tab beside Workflows and Skills (`CatalogPage.tsx:37-52`, URL-driven): list, editor, Run dialog, in-use delete
message, as in the approved mockup (`web/src/dev/mockups/phase54/agents.tsx`); the editor picks skills and servers
with the shared `MultiSelect` (D24). Skills from the installed managed list; servers from
`GET /schedules/pickable`. Run opens the new run in Run Detail.

## 4. Notification bell (`shared/layout/TopBar.tsx:59-65`)

Replace the placeholder with the popover of the approved mockup (`bell-chat.tsx`, D28): `GET /notifications` polled (30 s) or refreshed
on focus; unread badge; mark read / all; each item links to its schedule or run.

## 5. Moves

- **Testing → Setup** (`features/testing/SetupView.tsx:52`): `ScheduleSection.tsx` is replaced by a one-line summary of
  the app's regression schedule (from the setup GET's `schedule` pointer, 54-06 §2) with **Open schedule**, or
  **Schedule regression** (opens `/schedules/new` with target = this app) when none exists (D14).
- **Runs list and Run Detail:** a "Scheduled: <name>" badge for runs with `trigger.source == "schedule"`, linking to the
  schedule; "Scheduled (deleted)" when the schedule is gone (F10).
- **Catalog workflow detail:** a "Schedulable" badge and a **Schedule** action on workflows with `schedulable: true`.

## 6. Tests

Vitest + Testing Library per page with fixtures from 54-06 (L-011); jest-axe on the list, wizard, detail, Agents tab
and bell (L-014); a userEvent keyboard test for each `MultiSelect` use and the row menu (jest-axe sees neither focus
loss nor a label/name mismatch, 54-03 review m5/m6); the removed components' tests deleted with them, and a grep that no import of
`ApplicationSyncSection`, `syncSchedule` or `ScheduleSection` remains (L-094).

## 7. Gates

`cd genesis/web && npm run lint && npm run typecheck && npm test`; `npm run build` then commit `web/static/` in a
separate step and verify the commit with `git show --stat <sha> -- web/static` after the build has settled (L-089).

## As built

_(genesis-dev fills in: commits, changes, tests, review verdict, decisions/deviations, lesson candidates, code-map
changes, Resume note.)_

## Context manifest

```toml
areas    = ["web-shell", "config-secrets", "browser-testing", "web-runs", "features-stages"]
adrs     = ["ADR-027", "ADR-028", "ADR-032", "ADR-049", "ADR-055"]
lessons  = ["L-011", "L-014", "L-069", "L-089", "L-090", "L-094", "L-109"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md", "tracker:specs/phase-54-schedules-and-fixes/54-06-http-api.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md"]
code     = ["genesis/web/src/shared/layout/**", "genesis/web/src/app/router.tsx", "genesis/web/src/features/catalog/**", "genesis/web/src/features/settings/**", "genesis/web/src/features/testing/**", "genesis/web/src/features/runs/**", "genesis/web/src/features/run-detail/**"]
upstream = ["54-03", "54-06"]
```
