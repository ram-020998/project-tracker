# 35-05 — Web: onboarding + the Settings identity/team page + Hub-config

> **Status:** ✅ SHIPPED (genesis v0.63.0). · Part of Phase 35. Repo: **genesis/web**. · **Depends on:** 35-03 (identity/team + onboarding endpoints), 35-04 (the opt-in gate + provider). ADR-027 (design language), ADR-028 (`/api` client), ADR-049 (Settings IA).

## Purpose

Give the user a UI to **complete onboarding** and to **manage their identity + team** (per the user's explicit
request), plus the **Hub configuration + opt-in** control. All against the mock provider this phase; the same
UI repoints at the Appian provider in Phase 37.

## Build

1. **Onboarding flow** (`web/src/features/collab/OnboardingDialog.tsx` or a first-run route) — shown only when
   collaboration is **enabled** but identity isn't set: step 1 confirm identity (name / Appian username /
   email); step 2 pick an existing team or create one (title); done → active team set. Deferrable/skippable for
   a solo user who hasn't enabled the Hub (never blocks core use).
2. **Settings → "Collaboration" (identity + team) page** — a new Settings tab (`web/src/features/settings/…`,
   registered in the `SettingsPage` tabs shell): view/edit the local profile; show the **active team + its
   members**; switch team / join / create; and the **Hub configuration + opt-in toggle** (provider = local now;
   the dev-env Hub target field is wired live in Phase 37). Read-only "who am I to the team" summary
   (canonical username).
3. **Client plumbing:** `web/src/lib/api/collab.ts` (identity/teams endpoints) + `features/collab/hooks.ts`
   (TanStack Query) + `types/collab.ts` + query keys. No hard-coded `/api` (ADR-028); primitives from
   `shared/ui` (ADR-027).
4. **jest-axe** on the onboarding dialog + the Settings page; both themes; commit `web/static`.

## Tests

- vitest: identity form validation; team create/switch; the opt-in toggle gates the collaboration UI; onboarding
  appears only when enabled + identity unset. jest-axe green. tsc/eslint clean; build + `web/static` committed.

## Deliverable

Onboarding UI + the Settings identity/team + Hub-config page + client hooks/types + tests; `web/static` rebuilt.

## Gate

Independent review = SHIP: identity/team manageable; opt-in gating correct (no collaboration UI when disabled);
a11y/dark-parity/no-hardcoded-hex; gates green.
