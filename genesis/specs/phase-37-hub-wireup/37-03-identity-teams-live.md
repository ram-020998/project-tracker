# 37-03 — Identity/teams live

> **Status:** 🟡 DRAFTED. · Part of Phase 37. Repo: **genesis**. · **Depends on:** 37-01 (Appian provider), Phase 35 (identity/teams model + onboarding + Settings page against the mock).

## Purpose

Repoint the Phase-35 identity/team surfaces at the **real** Appian Hub, so a team actually forms and attribution
flows to the Hub.

## Build

1. Onboarding + the Settings identity/team page now use the `AppianHubProvider`: **create/join/list teams** +
   **membership** against real Appian Team/Membership records; local `collab_teams`/`collab_memberships` become
   a cache of the Hub.
2. **Attribution live:** `published_by`/`modified_by`/`owner_username` on published records + `LifecycleEvent.
   actor` carry the canonical username to the Hub.
3. **Onboarding-before-first-publish** enforced: a publish attempt without a configured identity/team → a clear
   "complete onboarding first" (never a silent unattributed write).
4. Offline: identity is cached locally (Phase 35), so attribution + local work continue when the Hub is down;
   team membership re-syncs on reconnect.

## Tests

- Team create/join/list + membership round-trip against a fake Appian provider; attribution recorded on
   publishes; onboarding-gate blocks an un-onboarded publish; offline uses the cached identity. ruff clean.

## Deliverable

Live identity/teams (onboarding + Settings repointed at Appian) + attribution to the Hub + the onboarding-gate.

## Gate

Independent review = SHIP: real teams form; attribution flows; onboarding-gate correct; offline-safe.
