# Phase 37 — Hub Wire-up: the Appian provider, KB sharing & live identity/teams

> **Status:** ✅ **SHIPPED (2026-09-06) — genesis v0.64.0** (42e610e, tag v0.64.0). Umbrella + `phase-37-hub-wireup/37-01..37-06`. · **Author:** Genesis agent
> **Type:** single-repo — **genesis** (a new `AppianHubProvider` implementing the Phase-36 contract; KB publish/pull; identity/teams wired live; the sync-UX foundation). No migration (Phase 35's m0019 stands). genesis-core / SDK / workflows / parser **unchanged**. · **Depends on:** **Phase 35** (the `SyncProvider` seam + `CollaborationService` + identity/teams model + `sync_uuid`/provenance/`collab_*` tables + the opt-in gate; ADR-063) **and Phase 36** (the deployed Genesis Hub Appian app + its **frozen API contract + fixtures**; ADR-064), ADR-048 (per-env Appian creds → the Hub service-account key), ADR-047 (the scheduler that can run periodic pulls), the KB `KbStore.apply` baseline path + the `sync-application` refresh flow.
>
> **Third of four phases** (35 → 36 → **37 Hub wire-up** → 38 Collaborative SDLC). This phase takes the whole
> mechanism **live** for the **first entities: the application KB + identity/teams** — end-to-end against a real
> Appian Hub — and lays the **sync-UX foundation** (check-for-updates / auto-pull / notify-then-apply / offline)
> that Phase 38 reuses for features/stories/boards.

---

## 1. Why this phase exists

Phase 35 built the collaboration substrate against a **local/mock** provider; Phase 36 delivered the **real
Appian Hub** app + a frozen contract. This phase **connects them**: a Genesis-side **`AppianHubProvider`** that
implements the `SyncProvider` Protocol against the Phase-36 Web APIs, so the `CollaborationService` — unchanged —
now talks to real Appian. It then makes the **two foundational shared surfaces live**:

- **The application KB** — the highest-value, lowest-risk shared entity (parse once, everyone pulls). Implements
  the locked **pull-first** model: a sync **pulls + hydrates** the latest published KB blob when it's newer;
  a full **export → parse → publish** happens only on a deliberate **refresh-from-Appian**, with content-hash
  dedup + a per-app already-running lock.
- **Identity + teams** — the onboarding + Settings page (Phase 35, mock) repointed at the **real** Appian Hub
  Teams/Membership, so a team actually forms and attribution flows.

It also builds the **sync-UX foundation** — the change-manifest poll, the "Sync now" control, the
notify-then-apply scaffolding, and offline-first behavior — the shared machinery Phase 38 plugs
features/stories/boards into.

---

## 2. Goal

1. **`genesis/collab/providers/appian.py::AppianHubProvider`** — implements every `SyncProvider` method against
   the Phase-36 frozen contract (records upsert/list/get with base-version CAS → `HubConflict`; blobs up/down/
   versions with content-hash dedup; `changes_since`; activity; teams/memberships). Authenticated by the Hub
   **service-account** credential via the ADR-048 per-env store. `is_available()` reflects reachability
   (offline-first). Registered in `build_sync_provider()` as the `appian` provider; validated against the
   **shared Phase-36 contract fixtures** (the same fixtures the Appian side passed).
2. **KB sharing (pull-first).** `hydrate_from_blob()` on the KB path (close current state → baseline apply from
   the pulled blob — the "replace current state" method the umbrella §… of Phase 35 flagged); the **sync action
   becomes pull-first** (newer Hub blob → pull + hydrate, no export/parse); **refresh-from-Appian** (deliberate)
   does export → parse → local write → **publish** the gzipped blob (content-hash dedup → no-op if unchanged);
   a **per-app already-running lock** (extend the existing 409 guard) so two refreshes can't both export; the
   ADR-047 scheduler can run the periodic refresh on a machine; **the Hub app is excluded** from tracked subject
   apps.
3. **Live identity/teams.** Repoint onboarding + the Settings identity/team page (Phase 35) at the
   `AppianHubProvider` — real team create/join/list + membership; attribution (`published_by`/`actor`) now
   recorded to the Hub. Onboarding required before the **first publish**.
4. **The sync-UX foundation.** A background **change-manifest poll** (foreground while relevant views are open;
   ADR-047 scheduler for periodic baseline) + a **"Sync now / Check for updates"** control; the **notify-then-
   apply** scaffolding (a local draft with a newer upstream shows "newer version available — review" rather than
   auto-overwriting); **offline-first** (Hub unreachable ⇒ local work continues, sync resumes when back). This is
   the reusable UX Phase 38 extends per entity.

**Success = a team deploys the Phase-36 Hub app, each member configures the Hub in Settings + onboards
(identity + team) against real Appian; one member refreshes an application from Appian → Genesis parses locally
+ publishes the KB blob; every other member's "sync" pulls that blob + hydrates their local KB with no
re-parse; and the sync-UX foundation (poll / Sync-now / offline) works end-to-end — the "parse once, everyone
benefits" outcome, live.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-05)

1. **Pull-first KB sync.** Sync = pull + hydrate the latest blob when newer; **export+parse+publish only on a
   deliberate refresh-from-Appian**; **anyone can refresh on demand**, everyone else auto-pulls; content-hash
   dedup absorbs no-op refreshes; a **per-app already-running lock** prevents double export.
2. **The Hub = the dev environment**, service-account writes, payload-carried attribution (Phases 35/36).
3. **The Hub app is isolated** — never added as a tracked subject app; the KB refresh/publish/exclusion honors
   this by `app_uuid`.
4. **Offline-first** — the Hub being unreachable never blocks local work; sync resumes when reachable.
5. **Opt-in** — with no Hub configured, none of this activates (Phase 35 gate).
6. **KB stays a blob** (materialized local read cache; the Appian side stores/serves the blob) — no KB records.

---

## 4. Current state (what we build on) — code-grounded

- **Phase 35** delivered `genesis/collab/` (the `SyncProvider` Protocol + `CollaborationService` + the
  `LocalHubProvider` + `build_sync_provider()` + identity/teams + `collab_*` tables + the opt-in gate). **This
  phase adds one more provider** (`AppianHubProvider`) and the KB/identity wiring — `CollaborationService` is
  unchanged.
- **Phase 36** delivered the **frozen contract + fixtures** (checked into genesis) the provider implements +
  tests against.
- **The KB write path** (`genesis/kb/store.py::KbStore.apply(sync_id, result, mode='baseline'|'delta')`) consumes
  a `KbParseResult`-shaped object — so a **blob = the serialized code-free parse result**, and `hydrate_from_blob`
  = deserialize → `apply('baseline')` after closing current state. The `sync-application` workflow /
  `api/applications.py` refresh flow is where publish/pull-first hooks in (a `_resolve_mode`-style branch:
  pull-if-newer vs export+parse+publish). The existing **per-app already-running 409 guard** extends to the Hub
  refresh.
- **Credentials:** ADR-048's per-env store holds the Hub service-account API key + base URL (Settings →
  Collaboration, Phase 35 UI — the field goes live here).
- **The scheduler** (ADR-047, `runtime/scheduler.py`) can run a periodic Hub pull / KB refresh job.

**Takeaway:** this phase = one new provider (`AppianHubProvider`, validated vs the Phase-36 fixtures) +
`hydrate_from_blob` + the pull-first KB refresh/publish wiring (+ the per-app lock + Hub-app exclusion) +
repointing identity/teams at Appian + the sync-UX foundation (poll / Sync-now / notify-then-apply / offline).
**No migration; genesis-only.**

---

## 5. The Appian provider — finalized in 37-01

`AppianHubProvider(SyncProvider)` over the Phase-36 contract: an HTTP client (reuse the platform's request stack)
to the Hub base URL, service-account API-key auth (ADR-048); maps each Protocol method → an endpoint; maps
**409 → `HubConflict`**, blob **200/201 → dedup/new**, `changes_since` → the manifest; `is_available()` pings
`/meta` (also checks `contract_version` compatibility, warning on mismatch). **Tested against the shared 36-01
fixtures** so the Genesis side and the Appian side are provably contract-identical (the "stub mirrors the real
contract" §7 rule).

## 6. KB sharing — finalized in 37-02

- `KbStore.hydrate_from_blob(app_uuid, result)` — close current-state rows (a `mode='baseline'` replace over an
  existing app) + baseline-apply the pulled parse result + recompute bundles; off the event loop
  (`asyncio.to_thread`, the §7 deadlock lesson).
- **Pull-first sync:** the app "sync"/"refresh" action checks the Hub for the latest KB blob version vs local;
  **newer ⇒ pull + hydrate** (no export/parse); otherwise a **deliberate refresh-from-Appian** does export →
  parse → local write → **publish** the gzipped blob (content-hash dedup → no-op if unchanged), stamping
  `published_by`/version.
- **Per-app already-running lock** (extend the 409 guard to cover Hub refresh); **Hub-app exclusion** (never
  refresh/track the Hub `app_uuid`); the **ADR-047 scheduler** may own a periodic pull/refresh.

## 7. Identity/teams live + the sync-UX foundation — finalized in 37-03/37-04

- Repoint onboarding + the Settings identity/team page at the `AppianHubProvider` (real team create/join/list +
  membership); attribution recorded to the Hub; onboarding required before the first publish.
- **Sync-UX foundation:** a change-manifest poll (foreground while a relevant view is open; scheduler for
  periodic baseline) + a **"Sync now / Check for updates"** control + notify-then-apply scaffolding (compare
  `published_version`) + offline-first (degrade gracefully when `is_available()` is false). Reusable by Phase 38.

## 8. ADR

No new ADR — this phase **implements** ADR-063 (the seam) against ADR-064 (the Hub app). If the pull-first KB
refresh model needs a recorded nuance beyond ADR-063, note it as an ADR-063 addendum; otherwise the umbrella +
sub-specs suffice.

## 9. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **37-01** | The Appian `SyncProvider` | `AppianHubProvider` implementing the Phase-36 contract (records/blobs/changes/activity/teams; 409→`HubConflict`; dedup; auth via ADR-048; `is_available`/`contract_version`); registered in `build_sync_provider('appian')`; tested against the **shared 36-01 fixtures**. | independent review = SHIP |
| **37-02** | KB sharing (pull-first) | `hydrate_from_blob`; the pull-first sync + deliberate refresh-from-Appian publish (gzip + content-hash dedup); per-app already-running lock; Hub-app exclusion; scheduler pull job; tests. | independent review = SHIP |
| **37-03** | Identity/teams live | Repoint onboarding + Settings identity/team at `AppianHubProvider`; attribution to the Hub; onboarding-before-first-publish enforcement; tests. | independent review = SHIP |
| **37-04** | Sync-UX foundation | Change-manifest poll (foreground + scheduler) + "Sync now/Check for updates" control + notify-then-apply scaffolding + offline-first; the reusable web hooks/components; jest-axe; `web/static`. | independent review = SHIP |
| **37-05** | Code review & hardening | Independent review (provider contract-conformance vs fixtures; pull-first correctness + no double-export; hydrate replace-current correct; offline degradation; opt-in no-op when disabled; attribution to Hub; a11y). | review clean |
| **37-06** | Release | genesis vX.Y.0 (suggest **v0.64.0**); tag; CI green (clean-install still v19); docs (bible §2/§3/§4/§8 + tracker + progress); **live-acceptance script** (deploy the Hub → onboard → refresh-from-Appian on one instance → pull KB on another). | CI green |

**Suggested order:** 37-01 → 37-02 → 37-03 → 37-04 → 37-05 → 37-06 (linear; 37-01 gates on Phase 36's contract).

## 10. Release plan

Single-repo genesis (suggest **v0.64.0**); no migration (m0019 stands); no core/SDK/workflows pin moves.
Per-sub-phase gates (pytest+ruff; web tsc/eslint/vitest/build + `web/static`); local commits; **no tag/push
until 37-06 on the user's go-ahead.** Live acceptance (a real deployed Hub + two instances) is user-driven /
headless-undrivable — provide the manual script. Requires the **Phase-36 Hub app deployed** + its service-
account key configured (Settings → Collaboration).

## 11. Scope

**In scope:** the `AppianHubProvider` (contract-conformant, fixture-tested); `hydrate_from_blob` + pull-first KB
sync + deliberate refresh-publish (gzip/dedup/lock/exclusion) + scheduler pull; live identity/teams (Settings +
onboarding repointed at Appian) + attribution to the Hub; the sync-UX foundation (poll / Sync-now / notify-then-
apply / offline). All opt-in.

**Out of scope:** features/artifacts/stories/boards publish-pull + their per-entity UX + adoption bulk-publish
(Phase 38); shared-memory sync (deferred); per-team visibility enforcement; identity verification.

## 12. Open questions

- **37-02:** the exact pull-first trigger surface (does the app-detail "Refresh" become "Sync" that pulls-first,
  with a separate explicit "Refresh from Appian (re-export)" action? — lean yes) and where the KB-blob
  version marker lives (`collab_sync_state` `kind='kb:<app_uuid>'`).
- **37-04:** poll interval + backoff defaults (foreground vs scheduler cadence).
