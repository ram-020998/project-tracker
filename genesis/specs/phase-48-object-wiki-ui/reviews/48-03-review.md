# Review 48-03 — base 148c064, change 01288c9 (genesis-review, 2026-10-21)

Scope: genesis `web/` only (`git diff --name-only 148c064 01288c9` lists nothing outside `web/`). Spec:
`48-03-web-experience.md`. Upstream: the 48-02 As built JSON samples and the 48-01 decisions D1–D7.
Live acceptance is out of scope (it belongs to 48-04).

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `npm run typecheck` | clean |
| `npm run lint` | 0 errors, 20 warnings (the one new warning is react-refresh on `WikiRedirect`, `router.tsx:42`, the same as the existing `StoryRedirect`) |
| `npm test` | 46 files, **364 passed** |
| Stale bundle: `npx vite build --outDir /tmp/gx-48-03-static` then `diff -r /tmp/gx-48-03-static static` | **identical** (the committed `web/static/` equals a fresh build) |
| `.venv/bin/ruff check genesis` | All checks passed (no Python changed) |
| `pytest` | N/A: no Python file changed |
| Working tree after the commit | clean (L-056: implementation, tests and bundle are all in 01288c9) |

## Checklist

ADRs
- [N/A] ADR-001, 011, 030, 031, 033, 034, 035, 041–045, 050, 056–060, 062, 064–068, 072–076: these were pulled in by area/chain. The change is read-only web UI with no workflow, chat, stage, lifecycle, DB or collaboration code.
- [OK] ADR-003/008/013: the change adds UI inside the local app; nothing else.
- [N/A] ADR-007: no roles or gating involved.
- [OK] ADR-026: no new network surface; the UI uses the existing `/api` reads only.
- [OK] ADR-027/055: uses existing primitives (`Tabs`, `Select`, `Input`, `Badge`, `Card`, `SegmentedControl`, `Tooltip`, `Page`, `EmptyState`/`ErrorState`/`LoadingState`, `RelativeTime`, `toast`). Colours are design tokens only (`bg-surface-*`, `text-fg-*`, `bg-success|info|warning|danger`, `ring-focus`, `shadow-e1`; tokens confirmed in `tailwind.config`). No new dependency (`package.json` is untouched). Icons go through `shared/ui/icons.ts`.
- [OK] ADR-028 / L-010: `lib/api/objectWiki.ts:6-10` paths have no `/api` prefix and use `encodeURIComponent` on both ids. A grep of the diff finds no `fetch(` and no `"/api` outside the msw handlers.
- [OK] ADR-037: only descriptions and summaries are shown; no SAIL or object code.
- [OK] ADR-049: no navigation change; the wiki is a tab of the application page.
- [OK] ADR-061/063/070: read-only views over the local wiki; no write paths.
- [OK] ADR-071: the resolved story links to `/applications/<app>/stories/<story.id>` (`HistoryTimeline.tsx:33-41`; test "a resolved story links to the canonical story page").
- [OK] ADR-077: process only; nothing in the diff touches it.

Lessons
- [OK] L-011: `types/objectWiki.ts` mirrors 48-02 §2.1/§2.2 field for field (13 row fields, 11 entry fields, `story` as `{id,key,title} | null`). The fixtures are typed against the interfaces, so a field drift fails `tsc`.
- [OK] L-083: `fixtures.ts` matches both 48-02 As-built samples verbatim (compared value by value: mixed `Z`/`+00:00` timestamps, string versions, `_a-…` uuids, `GNS_000130` with `story: null`).
- [OK] L-084: timestamps are compared by their parsed instant (`wiki-logic.ts:73-77`); tests "mixed Z / +00:00 timestamps compare by instant" and "unparseable last_changed_at sorts last in both directions".
- [OK] L-014: jest-axe runs on both the tab and the page through the existing global setup ("has no a11y violations" ×2).
- [OK] L-015: no heavy library added.
- [OK] L-030: `web/**` changed and `web/static` was rebuilt; the bundle is identical to a fresh build.
- [OK] L-048/L-068: no serving change.
- [OK] L-056: the commit is complete (the tree is clean, and tests, implementation and bundle are in one commit).
- [OK] L-069: no `<Button asChild>`. The only `asChild` is the existing `Tooltip` → `TooltipTrigger asChild` (Radix, not Button).
- [N/A] L-012, 017, 025, 027, 034, 041–043, 045, 051, 055, 057, 058, 061–064, 071–073, 075, 076, 082, 085–088: not touched by a read-only web view.

Spec conformance (48-03)
- [OK] §1 tabs: `ApplicationDetail.tsx:30-53` uses a controlled `Tabs`; absent or unknown `?tab` → `business-map`. Changing tab uses a functional `setSearchParams` with `replace: true`, so other params are kept (the test checks `?x=1&tab=…`). "Object Wiki" sits right after Overview (tested). The shared `Tabs` has no `forceMount`, so the wiki fetches only when its tab is open.
- [OK] §1 router and breadcrumbs: `router.tsx:41-45, 74-75`; `breadcrumbs.ts:70-73`; the new breadcrumb test checks the Home › Application › Object Wiki trail, with the crumb pointing to `/wiki` (which redirects to the tab).
- [OK] §2 data layer: `qk.objectWiki.list/detail`; hooks set `refetchOnWindowFocus: true` explicitly, because the app default is `false` (`lib/query/client.ts:9`) and D7 requires focus refetch. Choice 1 is justified. `refetchOnMount: true` is already the TanStack default; it is harmless.
- [OK] §2 detail retry: `retry: (count, e) => !isNotFound(e) && count < 1` behaves like the app default `retry: 1` but skips a 404. Choice 2 is fine.
- [OK] §3 type map: all 17 canonical keys (tested against the list); `other` or an unknown key shows `type_raw` as the label, falling back to "Other" when it is blank.
- [OK] §4 tab: toolbar, count ("N objects" / "N of M objects", `aria-live`), columns, `aria-sort`, default Last change desc, states (loading, error with Retry, empty, no match with Clear filters), and row click plus Enter on the name button. All are covered by tests.
- [OK] Choice 3 (Type filter by label) is consistent with how the column displays the type. It is untested; see m2.
- [OK] Choice 4 (new column starts desc for dates and counts; unparseable values last both ways) is tested in `nextSort` and the sort tests.
- [OK] §5 page: header with type and Deprecated badges, Back to `?tab=object-wiki` (explicit target, tested), metadata chips, "Not in the KB yet", summary card, `SegmentedControl` Both/Business/Technical, `<ol aria-label="Change history">`, plain-text descriptions (test "descriptions are plain text, never HTML"; no `dangerouslySetInnerHTML`), "Not recorded.", the 404 empty state with Back, and other errors → `ErrorState`.
- [OK] Choice 5 (reason only when `is_bugfix`) matches locked decision 48-01 D3 ("`Bug fix` badge + reason (when `is_bugfix`)"). It has a product consequence; see m1.
- [OK] Choice 6: the unresolved key is a `tabIndex=0` span inside the shared `Tooltip`; axe passes. It is keyboard-reachable, so the tooltip is discoverable.
- [OK] Choice 7: the one new lint warning is the same pattern as `StoryRedirect`.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m1 — Non-bug-fix entries never show their `change_reason`, but the writer fills it for every entry.** In `genesis-workflows/workflows/story-implementation/graph.py:668`, the documentation agent's prompt asks for `"change_reason": <one line: why this changed, ref the ticket>` on every entry, whatever `is_bugfix` is, and `graph.py:395` stores it. `HistoryTimeline.tsx:77` renders the reason only when `is_bugfix`, so for ordinary created/updated entries the "why" is fetched but never shown. This is what D3 says and what the spec says, so it is not a defect in 01288c9. The decision was made without knowing the writer behaves this way. **Fix:** raise it with the user before 48-04. One option: show the reason as muted text whenever it is present, and keep the Bug fix badge only for `is_bugfix`. If the user keeps D3, no change.
- **m2 — Three of the deliberate behaviours have no test.** (a) Spec §6.1 says "clicking a tab updates `?tab` (replace)". The test checks the URL but not that no history entry is added. For example, after two tab clicks, `navigate(-1)` should leave the app page, or you can assert the history length with a `createMemoryRouter`. (b) Choice 3: two `other` rows with different `type_raw` values should produce two Type options and filter separately. A small pure test with `typeOptions`/`filterObjects` would cover it. (c) Choice 2: a 404 is not retried. The test `QueryClient` sets `retry: false`, which shadows the hook's `retry` only if the hook doesn't set one. The hook does set one, so a msw handler that counts calls would show 1 call on a 404 and 2 on a 500. None of these blocks shipping, but each is a stated design choice, and the project rule is that a choice which matters gets a test.

### Nits
- n1 — `ObjectWikiPage.tsx:24-27`: `void navigator.clipboard?.writeText(...)` shows the success toast even if the write rejects, and the rejection goes unhandled. `RunsTable.tsx:9-16` already has the safer `try { await …; toast } catch {}` form; consider reusing it. (`RunDetailPage.tsx:173` has the same issue, so this is not a regression.)
- n2 — `HistoryTimeline.tsx:69`: the rail-dot offset `-left-[30.5px]` is a magic number tied to `pl-6` + `border-l`. A short comment would help, or position the dot relative to the rail.
- n3 — `hooks.ts:8`: the comment says "on mount once stale", which is accurate, but `refetchOnMount: true` is the TanStack default. You could drop it, or say it is there to be explicit.
- n4 — On the object page, an untracked app (the API's 404 `Application … not tracked`) shows "This object has no wiki page". This is acceptable, but the description could be more general ("…or the application is not tracked on this machine").

## Verdict: **SHIP**

There are no blockers or majors. All web gates are green, and the committed bundle matches a fresh build. The UI conforms to the spec and to D1–D7, and the fixtures are the 48-02 samples verbatim. m1 is a product question for the user, best answered before 48-04 live acceptance. m2 (the three missing tests) can be added in a small follow-up commit before the 48-05 release.

## Delta review (5789f88) — base 01288c9 (genesis-review, 2026-10-21)

Scope: `git diff --stat 01288c9..5789f88` lists 4 source files under `web/src/features/object-wiki/` and the rebuilt
`web/static/`. The rebuilt mermaid chunks get new hashes only because the `index-*` chunk they import changed. The
change addresses m2 and n1–n4. m1 is deliberately unchanged because it is a D3 product question for the user.

Gates (run by the reviewer): `npm run typecheck` clean · `npm run lint` 0 errors, 20 warnings (unchanged) ·
`npx vitest run` 46 files, **367 passed** (+3) · stale bundle: `npx vite build --outDir /tmp/…` then `diff -r … static`
**identical** · working tree clean after the commit (L-056).

| Item | Result | Evidence |
|---|---|---|
| m2(a) tab `replace` | OK | "tab clicks replace the history entry…" starts with `/start` in history, clicks two tabs, goes `navigate(-1)` and expects `/start`. The author mutation-checked it against `replace:false`. |
| m2(b) 'other' types | OK | The pure test gives `typeOptions` → `["AI Skill","Constant","Control Panel","Record Type"]`, and `filterObjects` on "Control Panel" returns only `VM_CP`. |
| m2(c) 404 vs 500 retry | OK | Reviewer mutation check on a `/tmp` copy: with `retry: false` the test fails with `expected 1 to be 2`; with `retry: (c) => c < 1` (404 retried) the test fails. The unmodified code passes. See n5. |
| n1 safe copy | OK | `ObjectWikiPage.tsx:24-31`: `await` inside `try`, with the success toast after the write and `toast.error` in `catch`. A missing `navigator.clipboard` throws inside the `try`, so it is caught too. It matches the `RunsTable.tsx` form. |
| n2 rail-dot comment | OK | `HistoryTimeline.tsx:67-68`. The arithmetic is right: −(1+24) − 6 + 0.5 = −30.5px. |
| n3 refetchOnMount | OK | `hooks.ts:6-8` now says it is the default and is stated only to make the contract explicit. |
| n4 404 copy | OK | `ObjectWikiPage.tsx:79` adds "…or the application isn't tracked here." |
| m1 | Open (by design) | Unchanged. It goes to the user as a D3 product question before 48-04. |

New nit
- **n5** — In the 404 half of the retry test, `calls === 1` after a 50 ms sleep is effectively vacuous. TanStack's
  default `retryDelay` is 1000 ms, so a wrongly retried 404 would still show only 1 call at 50 ms. The test catches
  that regression only because the error state then appears after ~1 s, past `findByText`'s 1000 ms default timeout,
  which is a timing race. Making it deterministic is optional: set `retryDelay: 0` in the test `QueryClient` defaults
  (the hook does not set one), so the call count does the asserting. That also speeds up the 500 half.
  This does not block shipping.

### Delta verdict: **SHIP**

m2 and n1–n4 are resolved, every gate is green, and the bundle is fresh. m1 is still open for the user (D3), and n5
is an optional hardening.
