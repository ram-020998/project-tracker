# Phase 35 — Collaboration Foundations & Identity (the local-first → shared-Hub substrate)

> **Status:** 🟡 **SPECS DRAFTED (2026-09-05)** — awaiting user sign-off to build. **ADR-063 Proposed.** Umbrella + `phase-35-collaboration-foundations/35-01..35-07`. · **Author:** Genesis agent
> **Type:** single-repo — **genesis** (one migration for `sync_uuid`/`row_version` backfill; a new `genesis/collab/` package; identity/settings; onboarding + a Settings identity/team page; a **local/mock Hub provider** so the whole mechanism ships + is testable **without Appian**). genesis-core / kiro-agent-sdk / genesis-workflows / genesis-appian-parser **unchanged**. · **Depends on:** ADR-026 (local single-user — **this phase amends it**), ADR-030 (DB-agnostic repositories — the seam that makes a shared store cheap), ADR-051/052 (the `AgentProvider`/`DocumentProvider` interface precedent this mirrors), ADR-048 (per-environment Appian credentials — reused by the future Appian provider), ADR-053 (memory `scope=personal|shared` — the shared scope becomes literally shared in a later phase), ADR-050/25-08 (`LifecycleService` + m0013 audit `actor` + `row_version` CAS), ADR-060/061 (finalized `kb_epics`/`kb_stories` + the Workbench board — the entities that will sync).
>
> **This is the FIRST of four phases** delivering team collaboration (35 Foundations & Identity → 36 the Genesis Hub Appian application → 37 Hub wire-up: the Appian provider + KB sharing + live identity/teams → 38 Collaborative SDLC: features/artifacts + stories + boards + the collaboration UX). Shared-memory sync is a deferred future phase. **Read `bible/08` §9's collaboration block + ADR-063 before touching this area.**

---

## 1. Why this phase exists

Genesis today is a **local, single-user** app (ADR-026): every user runs their own copy, and every piece of
data — the parsed application KB, features, specs, stories, boards, memory, chat, runs — lives only in that
user's `~/.genesis/genesis.db`. That is exactly right for a solo engineer, but a **team** (a PO, UX designers,
and developers working the same Appian application) cannot collaborate: three developers each re-export and
re-parse the *same* application; a PO's finished spec is invisible to the UX designer who needs it; a board's
status is private to one machine.

We want to keep Genesis **local-first** (it must stay fully functional solo and offline) but let a team
**selectively centralize** a defined subset of data to a shared **Collaboration Hub**, so work done on one
machine — once **published** — becomes available to teammates, who **pull** it into their own local Genesis.
The **shared** entities are: the **application KB** (parse once, everyone pulls), **features + their published
stage artifacts** (Spec / UX / Technical Design / Breakdown), **stories/epics**, and **board status**. The
**local-only** entities are: **chat, runs, the installed workflow catalog, documents, and personal memory**.
(Shared memory is deferred.)

Collaboration is impossible without **identity**: you cannot record "who published this" / "last updated by",
attribute a lifecycle transition, or scope a team without a per-user identity — and Genesis has none today
(`LifecycleEvent.actor` is always `None`; `memory_owner_username` is an unused config string).

**This phase builds the substrate** the other three phases plug into: the pluggable **`SyncProvider` seam**
(so the transport — Appian, and later git or a service — is swappable), **global identifiers** on every entity
that will sync (today they use collision-prone local autoincrement PKs), a **user + team identity model** with
onboarding + a Settings management page, and a **publish/pull service** with a **local/mock provider** so the
entire mechanism is buildable, testable, and shippable **before** the Appian Hub exists (Phase 36). Everything
is **opt-in and off by default** — a user who never configures a Hub sees a Genesis identical to today.

---

## 2. Goal

1. **A pluggable Collaboration Hub seam (`genesis/collab/`).** A `SyncProvider` Protocol (mirroring ADR-051's
   `AgentProvider` / ADR-052's `DocumentProvider`) with the operations publish/pull needs — `put_record` /
   `list_records` / `get_record`, `put_blob` / `get_blob` / `list_blob_versions`, `changes_since(cursor)`
   (the change manifest), and the advisory-lock markers — plus a `build_sync_provider()` registry keyed by
   provider type. A **`CollaborationService`** owns the transport-agnostic publish/pull logic (entity↔record
   mapping, versioning, provenance, conflict handling). **No Appian code in this phase** — a **local/mock
   provider** (an in-process/file-backed Hub emulator) is the first implementation, so the seam is exercised
   end-to-end by tests and dev use.
2. **Global identifiers + concurrency columns.** A migration adds a stable **`sync_uuid`** (client-generated
   UUID) to every entity that will sync — `kb_features`, `kb_feature_stages`, `kb_epics`, `kb_stories`,
   `workbench_boards`, `kb_board_cards` — and **backfills** one for every existing row, and adds **`row_version`**
   to the synced tables that lack it (`kb_features`, `kb_epics`, `kb_board_cards`, `workbench_boards`). This is
   the prerequisite that lets a feature/story/board created on one machine be referenced unambiguously on
   another (local int PKs collide across machines).
3. **A user + team identity model.** Onboarding captures the user's **name, Appian username, and email**
   (self-asserted — Appian is not an identity provider here) and their **team** (join an existing team or
   create one). The **Appian username is the single canonical user id** used everywhere — `published_by` /
   `modified_by`, `LifecycleEvent.actor`, and the personal-memory `owner` (unifying `memory_owner_username`).
   Teams + membership are **Hub entities** (Genesis-owned records, **UUID-keyed**) that, once the Appian
   provider lands (Phase 37), live in the Hub; in this phase they live in the mock provider. Identity is
   **captured + cached locally** so attribution works offline; team membership syncs when the Hub is reachable.
4. **A Settings page to manage identity + team** (per the user's request) + the first-run onboarding UI + the
   Hub-configuration / opt-in UI.
5. **Provenance, versioning & the advisory-lock model** (the plumbing the sync UX in Phases 37/38 renders):
   every shared entity carries a **version** + **`published_by`/`published_at`**; a stage records **which
   upstream artifact versions it consumed** (for the cross-stage staleness badge, decided notify-only); an
   **advisory "in-progress by X"** marker (heartbeat/TTL) rides the provider — backed by the existing
   `row_version` CAS as the correctness safety net.
6. **Opt-in / off-by-default.** The entire collaboration layer is gated behind a feature flag + Hub
   configuration. With no Hub configured, Genesis behaves **exactly as today** (solo, offline, no identity
   requirement). The migration (global ids) is additive and harmless for solo users.

**Success = with the collaboration layer enabled against the local/mock provider, a developer completes
onboarding (identity + team), the app stamps their canonical username on lifecycle transitions and edits, every
syncable entity has a stable `sync_uuid`, and the `CollaborationService` can publish an entity/blob to the mock
Hub and pull it back on a second (simulated) instance — the whole mechanism proven end-to-end with no Appian,
and a solo user with no Hub configured sees zero change.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-05)

Firm inputs, not open questions — the outcome of the design conversation.

1. **Local-first is preserved.** Genesis stays a local single-user app that works fully offline/solo; the Hub
   is **opt-in** and only for a **defined subset** of data. (ADR-063 **amends** ADR-026 — it does not reverse it.)
2. **Shared:** application KB, features + published stage artifacts, stories/epics, boards. **Local-only:**
   chat, runs, catalog, documents, personal memory. **Shared memory is deferred** to a later phase.
3. **The Hub is the team's Appian dev environment.** Teams have one dev environment (the thing Genesis already
   syncs); it doubles as the Hub — **no separate Hub environment.** (The Appian side is Phase 36.)
4. **Identity is self-asserted** at onboarding (name + Appian username + email) — **Appian is not an identity
   provider** (no whoami/authentication against it). The **Appian username is the canonical user id** used for
   `published_by`/`modified_by`, `LifecycleEvent.actor`, and the personal-memory owner. (Spoofing/typo hardening
   is **parked** for a later identity pass — noted, not built now. An optional future mitigation: populate the
   username from a read of the env's user list to reduce typos — not in this phase.)
5. **Teams are a Genesis-owned entity** (not Appian groups — the dev environment has user accounts but no group
   structure), **UUID-keyed** (client-generated), stored in the Hub, visible to all.
6. **Visibility is open** for now — everyone can see everyone's applications/features/stories/boards (mirrors
   how a shared Appian dev environment already behaves). We **stamp an owner + `team_uuid`** on shared entities
   anyway, as a **forward-compat seam** for per-team visibility later (tagged now, not enforced).
7. **A shared service account writes to the Hub** (Phase 37); attribution comes from the **payload** Genesis
   sends (`created_by`/`modified_by` = the acting user's canonical username), not from Appian's auth context.
   (This phase models the attribution fields + threads the identity; the actual Appian write is Phase 37.)
8. **Concurrency = soft advisory + optimistic CAS.** A soft **"in-progress by X"** advisory marker
   (heartbeat/TTL, cleared on publish/when stale) prevents accidental double-work; the existing **`row_version`
   CAS → `StaleWriteError`** guarantees no silent overwrite even if the advisory is ignored. **No hard lock.**
9. **Opt-in / off by default.** No Hub configured ⇒ Genesis is unchanged (solo, offline, no identity gate). The
   `sync_uuid` migration is additive and safe for solo installs.
10. **Global identifiers are mandatory groundwork** — synced entities get a stable `sync_uuid`; the migration
    backfills existing rows. Local int PKs stay (the `sync_uuid` is an additional stable key + a local↔global
    map on hydrate).

---

## 4. Current state (what we build on) — code-grounded

- **The entities that will sync all use local `INTEGER AUTOINCREMENT` PKs + local int FKs** (verified against
  the migrations): `kb_features(id)` (FK `app_uuid` → global, good), `kb_feature_stages(id, feature_id)`,
  `kb_epics(id, feature_id)`, `kb_stories(id, feature_id, epic_id)`, `workbench_boards(id, app_uuid UNIQUE)`,
  `kb_board_cards(id, board_id, story_id)`. **These ids collide across machines** → the `sync_uuid` groundwork.
- **`row_version` exists on `kb_feature_stages` / `kb_stories` / `kb_story_stages`** (m0014 pattern → CAS +
  `StaleWriteError`), but **not** on `kb_features` / `kb_epics` / `kb_board_cards` / `workbench_boards` — this
  phase adds it there for safe concurrent publish/pull.
- **The local-only linkages are already FK-free "independent lifecycle" columns** (`kb_feature_stages`/
  `kb_story_stages`: `chat_session_id`, `run_id`, `html_path`, `source_doc_path`). That is exactly what makes
  "artifact bytes move, chat/run stay local" clean — the sync payload publishes the artifact *content* + status
  + hash and leaves the local-only columns null on the puller. (Consumed by Phases 37/38; established here.)
- **The provider-interface precedent is real:** `genesis_core/agents/` (`AgentProvider` + `KiroAcpProvider` +
  `get/set_agent_provider`, ADR-051) and `genesis/integrations/documents/` (`DocumentProvider` +
  `build_document_providers()` registry, ADR-052). **`genesis/collab/SyncProvider` mirrors this shape.**
- **Identity is unwired.** `genesis/domain/events.py::LifecycleEvent.actor` accepts a username but **every**
  `LifecycleService.transition(...)` call site passes no actor (features.py:467/987, the finalizers) → all
  m0013 audit rows are unattributed. `runtime/settings.py::memory_owner_username` (`GENESIS_MEMORY_OWNER`) is a
  config string, not a real identity. This phase introduces the identity + threads it into `transition(actor=)`.
- **Repositories are DB-agnostic (ADR-030)** — stores take a `Database`, never open ad-hoc connections, never
  create tables (schema owned by `genesis/db/migrations/`). The new migration + the `genesis/collab/` package
  follow that; a new store (if any) mirrors the existing pattern.
- **`api/app.py` is a composition root** (`register_*_routes(...)`); the new collab/onboarding/settings routes
  register there. Web is React+TS with a Settings tabs shell (`SettingsPage`), TanStack Query hooks, `/api`
  client prefixing (ADR-028), tokens/primitives (ADR-027).

**Takeaway:** this phase = one additive migration (`sync_uuid` + `row_version` backfill; `current_version`
17→… wait, current is **18** → **19**) + a new `genesis/collab/` package (the `SyncProvider` Protocol +
`CollaborationService` + a local/mock provider + the identity/team model + provenance/advisory-lock plumbing) +
onboarding + a Settings identity/team page + the opt-in feature flag. **No Appian, no other repo.**

---

## 5. Data model — finalized in 35-01/35-02

- **New migration (m0019 `collab_identity_and_sync_ids`; `current_version` 18 → 19):**
  - Add **`sync_uuid TEXT`** (UNIQUE per table) to `kb_features`, `kb_feature_stages`, `kb_epics`, `kb_stories`,
    `workbench_boards`, `kb_board_cards`; **backfill** a UUID for every existing row (a data migration step).
  - Add **`row_version INTEGER NOT NULL DEFAULT 0`** to `kb_features`, `kb_epics`, `kb_board_cards`,
    `workbench_boards` (the tables that lack it).
  - Add **`owner_username TEXT`** + **`team_uuid TEXT`** (forward-compat visibility/attribution tags — stamped,
    not enforced) to the top-level synced entities (`kb_features`, `kb_stories`, `workbench_boards`), plus
    **`published_by TEXT` / `published_at TEXT` / `published_version INTEGER`** provenance columns where a
    shared entity records its last publish.
  - A local **`collab_identity`** singleton table (the current user's `name` / `appian_username` / `email` /
    `active_team_uuid`), and a local **`collab_teams` / `collab_memberships`** mirror (cached from the Hub) so
    team data is readable offline. (Teams/membership are authored to the Hub; the local tables are a read
    cache.)
  - A local **`collab_sync_state`** table (per entity-kind pull cursor + last-published-version markers) for the
    change-manifest / pull-if-newer logic.
- **No change to chat/runs/documents/memory tables** — those stay local-only.
- Exact DDL + the `sync_uuid` backfill + the store read/write changes are locked in **35-01/35-02**.

---

## 6. The `SyncProvider` seam + `CollaborationService` — finalized in 35-01/35-04

- **`genesis/collab/provider.py`** — the `SyncProvider` Protocol (transport-neutral):
  - Records: `put_record(kind, sync_uuid, payload, *, base_version) -> PutResult` (CAS on version → a
    `StaleWriteError`-equivalent conflict), `get_record(kind, sync_uuid)`, `list_records(kind, *, since=None)`.
  - Blobs: `put_blob(kind, key, bytes, *, content_hash, meta) -> BlobRef`, `get_blob(ref)`,
    `list_blob_versions(kind, key)`.
  - Change manifest: `changes_since(cursor) -> (changes[], next_cursor)` (the tiny "what's new" feed).
  - Advisory locks: `set_activity(kind, sync_uuid, username, *, ttl)` / `clear_activity(...)` /
    `list_activity(...)`.
  - Identity/teams: `upsert_team` / `list_teams` / `upsert_membership` / `list_memberships` /
    `resolve_user(username)`.
- **`genesis/collab/service.py::CollaborationService`** — the transport-agnostic publish/pull orchestration:
  entity↔record mapping (per kind), version/provenance stamping, conflict detection (base-version CAS →
  notify-then-apply), the change-manifest → pull decisions, and the advisory-lock heartbeat. Depends only on the
  `SyncProvider` Protocol (never on Appian).
- **`genesis/collab/providers/local.py::LocalHubProvider`** — a file-backed in-process Hub emulator (records +
  blobs + manifest + activity under a local dir) so the seam is fully exercised without Appian. Also the test
  double.
- **`build_sync_provider(settings)`** — the composition-root registry keyed by provider type (`local` now;
  `appian` added in Phase 37). Opt-in: returns `None` (collaboration disabled) when no Hub is configured.

---

## 7. Identity, onboarding & the canonical username — finalized in 35-03

- **`genesis/collab/identity.py`** — the local identity model (`collab_identity`) + `current_user()` accessor;
  `resolve` reads the cached profile. The **Appian username is canonical**; `memory_owner_username` becomes a
  derived read of it (back-compat retained).
- **Threading attribution:** `LifecycleService.transition(...)` call sites pass `actor=current_user().username`
  (features.py, the finalizers); publish payloads carry `created_by`/`modified_by`/`published_by` from the same
  source. (The *audited* transitions become attributed — the m0013 seam finally populated.)
- **Onboarding (backend):** a first-run readiness item (extends `runtime/preflight.py`) + endpoints to
  capture/confirm identity, list/join/create teams (via the provider), and set the active team. Required before
  the **first publish**, not before using Genesis.
- **Teams:** created client-side with a `team_uuid` (UUID) so creation works offline + never collides;
  `upsert_team`/`upsert_membership` to the provider; a local cache (`collab_teams`/`collab_memberships`).

---

## 8. Web — finalized in 35-05

- **Onboarding flow** (first-run, only when collaboration is enabled): confirm identity (name / Appian username
  / email) → pick or create a team → done. Skippable/deferrable for a solo user who hasn't enabled the Hub.
- **A Settings identity/team page** (per the user's request): view/edit the local profile (name / Appian
  username / email), see the active team + members, switch/join/create a team, and the **Hub configuration +
  opt-in toggle** (which provider, the dev-env Hub target — wired to the real Appian provider in Phase 37).
- All against the **mock provider** this phase; the same UI is repointed at the Appian provider in Phase 37.
- Tokens/primitives (ADR-027), `/api` client (ADR-028), TanStack Query hooks, jest-axe on the new pages, commit
  `web/static`.

---

## 9. ADR

- **ADR-063 (PROPOSED — this phase): The Genesis Collaboration Hub — local-first with selective centralization.**
  Genesis stays a **local-first single-user app** (ADR-026) but gains an **opt-in** capability to **selectively
  centralize a defined subset of data** (application KB, features + published stage artifacts, stories/epics,
  boards; **not** chat/runs/catalog/documents/personal-memory) to a shared **Collaboration Hub**, via a
  **pluggable `SyncProvider` seam** (mirroring ADR-051/052) with **publish-on-complete** (explicit push) +
  **pull** (auto for read-only shared views + boards; **notify-then-apply** where a local draft exists; a manual
  "Sync now"). Data is keyed by **stable `sync_uuid`s**; concurrency is **optimistic `row_version` CAS +
  a soft advisory in-progress marker** (no hard lock); cross-stage dependency staleness is **notify-only with
  provenance**. **Identity is self-asserted** (name + Appian **username** [the canonical user id] + email);
  **teams are Genesis-owned, UUID-keyed Hub entities**; **visibility is open** (owner/`team_uuid` stamped for a
  future scoping seam). **Amends ADR-026** (multi-user becomes possible, opt-in, for the shared subset only —
  the local-first posture and offline/solo operation stand). Relates to ADR-030 (the DB-agnostic-repository seam
  that makes the shared store cheap; the Hub is **not** a Postgres swap — it is a separate publish/pull target),
  ADR-048 (per-env Appian creds reused by the Appian provider), ADR-053 (shared memory becomes literally shared
  in a later phase). The concrete **Appian Hub backend + its contract is ADR-064** (Phase 36). Mirror in
  `bible/04` on Accept.

---

## 10. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **35-01** | Data model, sync seam & **ADR-063** | Lock the m0019 schema (`sync_uuid` + `row_version` backfill + owner/team/provenance columns + `collab_*` local tables); the `SyncProvider` Protocol + `CollaborationService` model; the identity/team model + the canonical-username rule; the provenance/version/advisory-lock model; the opt-in/feature-flag model; **draft ADR-063.** **Docs only.** | ⭐ user sign-off → build |
| **35-02** | Global identifiers & concurrency migration | m0019 (`current_version`→19): add + **backfill** `sync_uuid` on the 6 synced tables; add `row_version` where missing; add owner/team/provenance columns; the store create/read changes to generate + expose `sync_uuid`; bump every `current_version == 18` test. | independent review = SHIP |
| **35-03** | Identity, onboarding & canonical username | `genesis/collab/identity.py` + `collab_identity`/`collab_teams`/`collab_memberships` + `current_user()`; thread `actor=` into `LifecycleService.transition` call sites; `memory_owner_username` derives from the identity; onboarding backend (preflight item + endpoints: identity, teams, active-team). | independent review = SHIP |
| **35-04** | The `SyncProvider` seam + `CollaborationService` + local provider | `genesis/collab/{provider,service}.py` + `providers/local.py` (file-backed Hub emulator) + `build_sync_provider()` + the opt-in gate; publish/pull orchestration + version/provenance + change-manifest + advisory-lock plumbing; unit-tested end-to-end against the local provider (publish → pull on a second simulated instance). | independent review = SHIP |
| **35-05** | Web: onboarding + Settings identity/team page + Hub-config | First-run onboarding UI; the Settings identity/team management page; the Hub-config + opt-in toggle (mock provider); types/api/hooks; jest-axe; commit `web/static`. | independent review = SHIP |
| **35-06** | Code review & hardening | Independent review (opt-in truly no-op when disabled; migration additive + backfill correct + idempotent; identity threaded without breaking solo; CAS/advisory model; provider seam clean + Appian-free; a11y/dark-parity/no-hardcoded-hex); apply SHOULD-FIX. | review clean |
| **35-07** | Release | genesis vX.Y.0 (suggest **v0.63.0**); tag; CI green (incl. clean-install DB upgrade to **v19**); docs (bible §2/§3/§4/§8 + tracker + progress + ADR-063 → Accepted); report. | CI green |

**Suggested order:** 35-01 → 35-02 → 35-03 → 35-04 → 35-05 → 35-06 → 35-07 (linear; each gated on the prior).

---

## 11. Release plan

Single-repo (**genesis**). Per ADR-019 no core/SDK/workflows pins move. Per sub-phase: build → gates (genesis
pytest + ruff; web tsc/eslint/vitest/build + commit `web/static`) → local commit → independent review → docs;
**no tag/push until 35-07 on the user's go-ahead.** The `clean-install` CI job must migrate a fresh DB to **v19**
and serve; the `sync_uuid` backfill must run correctly on a populated DB (test with real rows). A schema bump
breaks every hardcoded `current_version == 18` test — bump them with the migration (the §7 lesson). The whole
collaboration layer is **behind the opt-in flag** — the release changes nothing for a user who doesn't enable a
Hub.

---

## 12. Scope

**In scope:** the m0019 migration (global `sync_uuid` + backfill; `row_version` backfill; owner/team/provenance
columns; `collab_*` local tables); the `genesis/collab/` package (`SyncProvider` Protocol + `CollaborationService`
+ a local/mock provider + `build_sync_provider()`); the identity + team model + `current_user()` + canonical
username unification + `actor` threading; onboarding (backend + UI); the Settings identity/team page + Hub-config
opt-in UI; the provenance/version/advisory-lock plumbing; the feature-flag gate. All exercised against the
**local/mock provider** — no Appian.

**Out of scope (later phases):** the Appian Hub application + its Web APIs/record types/blob store (Phase 36);
the real Appian `SyncProvider` + KB sharing + live identity/teams (Phase 37); features/artifacts/stories/boards
publish-pull + the collaboration UX + adoption bulk-publish (Phase 38); shared-memory sync (a deferred future
phase); per-team **visibility enforcement** (tags are stamped now, not enforced); identity **verification** /
anti-spoofing (parked).

---

## 13. Open questions

None blocking — the design forks were resolved with the user (2026-09-05; see §3). Deferred to 35-01: the exact
m0019 column names + the `collab_*` local-table shapes + the `SyncProvider` method signatures (locked in 35-01
before the 35-02/35-04 build).
