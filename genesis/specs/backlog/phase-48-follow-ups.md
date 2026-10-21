# Backlog — Phase 48 follow-ups

> **Status:** 📝 BACKLOG (not scheduled). · **Created:** 2026-10-21 · **Repo:** genesis (`web/`)
> Source: 48-03 As built (lesson candidate from genesis-dev), call sites re-verified by genesis-spec 2026-10-21.

1. **Shared `Select` drops `aria-label` → unnamed dropdowns (a11y bug, pre-existing).** `web/src/shared/ui/select.tsx:15-40`
   takes `ariaLabel` (camelCase) and forwards it to the trigger button. Callers that pass the hyphenated `aria-label`
   compile cleanly (TypeScript does not check hyphenated JSX attributes against a component's props) and the prop is
   silently dropped, so the trigger has **no accessible name**. Call sites found (2026-10-21, 9 in 4 files):
   - `features/features/StoriesTab.tsx:155,158` (type, epic filters)
   - `features/features/StoryForm.tsx:27,32,37` (Type, Category, Parent epic)
   - `features/workbench/BoardPage.tsx:199,202,204` (type, epic, label filters)
   - `features/runs/RunsPage.tsx:91` (workflow filter)

   Suggested remedy: make `Select` accept a typed `"aria-label"?: string` as well (preferred name; `ariaLabel` kept as an
   alias) so both spellings work and future callers are type-checked; fix the call sites; add a jest-axe test on one
   filter bar (e.g. `BoardPage`) that fails without the fix. Then record the lesson (hyphenated props escape type
   checking on custom components) via `genesis-ctx add lesson`.
