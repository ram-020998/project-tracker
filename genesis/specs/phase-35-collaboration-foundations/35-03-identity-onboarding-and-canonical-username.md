# 35-03 — Identity, onboarding & the canonical username

> **Status:** 🟡 DRAFTED. · Part of Phase 35. Repo: **genesis** (backend). · **Depends on:** 35-02 (`collab_*` tables), 35-04 (the `SyncProvider` seam — for team CRUD; may land in parallel, both gate on 35-01). ADR-050 (`LifecycleService.actor`), ADR-053 (`memory_owner_username`).

## Purpose

Introduce a real per-user **identity** + **team** model, make the **Appian username the single canonical user
id** across the app, and add the **onboarding** backend — so attribution ("who published / last updated / the
lifecycle actor") is finally populated and teams exist. Against the provider abstraction (mock this phase).

## Build

1. **`genesis/collab/identity.py`**
   - `Identity` dataclass (`name`, `appian_username`, `email`, `active_team_uuid`) over `collab_identity`.
   - `current_user() -> Identity | None` (cached read); `set_identity(...)`; `set_active_team(team_uuid)`.
   - `canonical_username() -> str` = `current_user().appian_username` if set, else the legacy
     `settings.memory_owner_username` or `"local"` (so solo/unconfigured is unchanged).
2. **Canonical-username unification**
   - Thread `actor=canonical_username()` into **every** `LifecycleService.transition(...)` call site
     (`api/features.py:467/987`, `chat/stage_finalizer.py`, `chat/story_design_finalizer.py`) → the m0013 audit
     rows become attributed.
   - `memory_owner_username` usage (chat/mcp.py, memory_jobs.py, api/memory.py, api/system.py) reads
     `canonical_username()` (back-compat: unchanged when no identity is set).
3. **Teams** (via the provider — mock this phase): `create_team(title)` (client-generates a `team_uuid`,
   `upsert_team`, add the current user as a member, cache locally), `list_teams()`, `join_team(team_uuid)`,
   `set_active_team(team_uuid)`. Local cache in `collab_teams`/`collab_memberships`.
4. **Onboarding (backend)**
   - Extend `runtime/preflight.py` with a (collaboration-only) "identity configured" item.
   - Endpoints (register in `api/app.py`): `GET/PUT /api/collab/identity`; `GET /api/collab/teams` +
     `POST /api/collab/teams` (create) + `POST /api/collab/teams/{uuid}/join` + `PUT /api/collab/active-team`.
   - Required before the **first publish** (Phases 37/38 enforce at publish); not before using Genesis.

## Tests

- `current_user()`/`canonical_username()` fallbacks (identity set / unset / legacy owner set).
- `transition(actor=...)` now records the username in m0013 (a lifecycle-audit test asserts a non-null actor).
- Team create/join/list against the mock provider; active-team switching.
- Solo/unconfigured path unchanged (no identity → today's behavior). ruff clean.

## Deliverable

`genesis/collab/identity.py` + canonical-username unification + team CRUD + onboarding endpoints + preflight
item + tests.

## Gate

Independent review = SHIP: identity threaded without breaking solo; attribution populated; teams round-trip via
the provider; gates green.
