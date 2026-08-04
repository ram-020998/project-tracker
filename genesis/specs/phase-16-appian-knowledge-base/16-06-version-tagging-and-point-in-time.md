# Phase 16-06 — Version tagging + point-in-time

> **Status:** 📋 BACKLOG — **NOT in iteration 1** (per scope decision 2026-08-04). Multi-release/version support is
> wanted but is deferred until the Appian **Dev MCP** ships versioned object retrieval (**AP-62096**, 26.8 GA); this
> sub-phase is implemented in a later iteration once that lands. · **Repos:** genesis (+ web) · **Depends on:** 16-02
> (KbStore/`kb_releases` — schema kept version-ready), 16-05 (KB MCP + live code), **AP-62096** (external)
> **External dependency (dated):** the *historical* code slice depends on Appian **Dev MCP** exposing versioned object
> retrieval — tracked as **[AP-62096](https://appian-eng.atlassian.net/browse/AP-62096)** "Object version viewing and
> comparison tools (list versions · read a prior version · compare · revert)", child of **AP-54865** ("Distributable
> plugin for Dev MCP"), Fix Version **26.8 GA (2026-08-28)**. As of 2026-08-04 it is in **Code Review** (not yet Done).
> The underlying version-UUID plumbing it builds on — **[AP-51279](https://appian-eng.atlassian.net/browse/AP-51279)**
> "Add Version UUID Support to Plugin Endpoints & Tools" (+ subtask AP-52939) — is already **Done**.
> **Goal:** Let the user **tag releases** in Genesis ("Mark released → v1.0"), snapshot the metadata state at that
> point, and reconstruct/query the KB **as of any release** — with **point-in-time code** fetched live via the Dev MCP
> using the release's version handle. This realizes the "what did object X look like at v1.0?" capability.

---

## 1. Current state (grounded / from earlier sub-phases)
- 16-02 added `kb_releases(app_uuid, version_label, tagged_at, sync_id, env_version_ref, notes)` + `KbStore.tag_release`
  / `list_releases` and the point-in-time read predicate (validity range keyed to the release's `sync_id`).
- 16-04 declared `POST /api/applications/{app_uuid}/releases` (implemented here) + the app-detail **Releases** tab
  placeholder.
- 16-05's `genesis-kb` reads accept an `at_release`/`version?` parameter; `get_object_code(uuid, version?)` is
  version-parameterized (historical fetch pending Dev MCP versioning; current works).
- The user model: metadata history accrues continuously via syncs (SCD-2); a release is a **named pointer** to a sync;
  code at a release comes from the env via the Dev MCP keyed by `env_version_ref`.
- **Dev MCP versioned-retrieval status (verified 2026-08-04 via Jira):** **AP-62096** (list versions · read a prior
  version · compare · revert) is in **Code Review**, targeted for **26.8 GA (2026-08-28)** — the tools this sub-phase's
  historical-code path calls. The version-UUID plumbing (**AP-51279** + AP-52939) is **Done**. So the metadata history
  + current-code paths in this sub-phase have **no external blocker**; only the *historical-code read* is gated on
  AP-62096 shipping in 26.8 GA. Re-check the ticket's status before starting the historical-code path.

## 2. Design

### 2.1 Tagging a release
- `POST /api/applications/{app_uuid}/releases` `{version_label, env_version_ref?, notes?}` → `KbStore.tag_release`:
  insert a `kb_releases` row at the latest **succeeded** `sync_id`; **snapshot the current bundle set** into a
  `release_label`-stamped copy (so point-in-time bundles are cheap); set `kb_applications.current_release`.
- **`env_version_ref`** is the handle the environment/Dev MCP uses to fetch code at that release. **Source of the
  handle (decide with the Appian side):** (a) user enters/confirms the app version string at tag time; (b) Genesis reads
  it from the env at tag time (a Dev MCP/API "current app version" call); (c) derived from a configured
  `version_constant` object's value in the KB. Default: **(b) read from env at tag time**, fall back to (a) manual.
- Guard: unique `(app_uuid, version_label)`; re-tagging the same label is an explicit replace.

### 2.2 Point-in-time queries (metadata)
- Every `genesis-kb` + Applications read accepts `at_release=<label>` → `KbStore` resolves it to `sync_id` and applies
  the validity predicate. `at_release=None` = current.
- `get_changelog(app, from_release, to_release)` diffs the two releases' states (added/modified/removed objects +
  affected bundles) from SCD-2 ranges.

### 2.3 Point-in-time code (live)
- `get_object_code(app, object_uuid, version=<label>)` → resolve `version` → `kb_releases.env_version_ref` → Dev MCP
  versioned read (the **AP-62096** tools). **Sequencing:** works fully once AP-62096 ships in **26.8 GA (2026-08-28)**;
  until then it returns current code with a clear "historical code pending Dev MCP AP-62096 (26.8 GA)" note (never
  fabricated).

### 2.4 Web — Applications **Releases** tab + affordances
- **Releases** tab in `ApplicationDetail`: list releases (label, tagged_at, sync, object/bundle counts at that release)
  + a **"Mark released"** action (version label + optional notes + env-version confirm).
- A **release selector** on the Overview/Objects/Bundles tabs ("As of: current ▾ / v2.0 / v1.0") that re-queries with
  `at_release`; a **changelog** view between two releases (reuse the diff/markdown renderers).
- Object detail gains a **version picker** on "View code" (current / a release) → `get_object_code(version)`.
- Rebuild + commit `web/static/`.

## 3. Files & tests
- Backend: implement `POST /api/applications/{id}/releases` + `at_release`/`from`/`to` params on the KB browse
  endpoints (16-04) + the changelog endpoint; `KbStore.tag_release`/`list_releases` already exist (16-02) — add the
  env-version read helper.
- Web: Releases tab + release selector + changelog view + version-picker on code view; `applicationsApi.releases/tagRelease`.
- Tests:
  - `KbStore` point-in-time already covered in 16-02; add API-level tests: tag v1.0 → mutate (a delta/baseline resync)
    → tag v2.0 → `get_app_overview?at_release=1.0` reflects v1; changelog(1.0→2.0) correct; re-tag guard.
  - web (Vitest + MSW + jest-axe): Releases tab renders + "Mark released" flow; release selector re-queries; version
    picker on code view calls `get_object_code` with the version; changelog renders.
- backend + web suites + build green; `web/static` committed.

## 4. Acceptance criteria
1. A user can **tag a release** for an app; the release names a point in time and records an `env_version_ref`.
2. Metadata queries (overview/objects/bundles/dependencies) can be run **as of a release** and reconstruct that state
   from SCD-2 history; changelog between releases is correct.
3. **Point-in-time code** fetch is wired (version-parameterized via Dev MCP); current works today, historical lights up
   when **AP-62096** ships in 26.8 GA; degradation is honest (names the pending ticket, never fabricated).
4. Releases tab + release selector + version-picker shipped; suites + build green; `web/static` committed.

## 5. Out of scope
- Delta sync + scheduling (16-07).
- Automatic release detection from a version constant (optional future; manual tagging is v1 — umbrella Q4).
- Retention/pruning of old release snapshots (umbrella Q5 — optional, post-16-07).
