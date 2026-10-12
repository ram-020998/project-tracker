# Phase 45 — Incremental Delta Sync (package-scoped KB refresh + configurable schedule)

> **Status:** 🟡 **DRAFTED — specs only; awaiting build go-ahead.** · **Author:** Genesis agent · Created 2026-10-12.
> Sub-specs: `phase-45-incremental-delta-sync/45-01..45-10`. Findings: `45-01-findings.md`. New ADRs (Proposed):
> **ADR-073** (environment package management) + **ADR-074** (incremental, package-scoped KB sync).
> Backlog spin-off: `backlog/implementation-packages.md`.

## 1. Why this phase exists

Since Phase 16 the only way to refresh an application's knowledge base is a **full re-export**: export the whole
application (~8 MB / ~2,900 objects for AS GSS), parse everything, then diff against the KB (`sync-application`
`mode=delta`, 16-07 Option A). A *true* incremental sync was deferred because Appian offered no way to find and
export only the changed objects (`specs/backlog/phase-16-deferred.md` §1.3). Because full syncs are expensive, the
scheduled `application-sync` job has been **disabled** since v0.48.3.

**Appian Dev MCP 26.6.105+ makes incremental sync possible.** Two new tool families:
- **`listObjects`** — lists design objects filtered by application, type, last-modified date and user.
- **Package management** — `createPackage`, `addPackageObjects`, `getPackage`, `deletePackage`, …

So a sync can list only the objects modified since the last sync, put them in a temporary package, export just that
package via the existing Deployment REST path, parse it, and merge it into the KB. This phase builds that, re-enables
scheduled syncing with a user-configurable schedule, and keeps the Hub KB current after every run.

## 2. Goal

- **Delta (incremental) sync:** list → temporary package → export → KB-aware parse → incremental merge. Seconds
  instead of minutes, KB-accurate (edges + bundles), deletions ignored.
- **Weekly full sync**, automatic: a delta upgrades itself to a full re-export when the last full sync is ≥ N days
  old (default 7) or the change set is too large.
- **Configurable global schedule** in Settings → General (every N hours in a window, or fixed times).
- **Refresh** runs a delta (auto rules); a separate **Full sync** action forces a full re-export.
- **Hub always current:** after every successful sync, a full KB snapshot built **from the KB** is published; teammates'
  auto-pull hydrates it.
- **Adopt Dev MCP 26.6.110** (matches the dev-env plugin; required by the new version gate).

## 3. Constraints & decisions (locked with the user, 2026-10-12)

| # | Decision |
|---|---|
| D1 | **Environment writes:** a new ADR (ADR-073) sanctions **package management** as the only non-design-object write. It goes through one **Genesis package client called by workflow code only — never by an agent**. The client allows only package tools and refuses to delete any package not named `genesis-delta-*`. |
| D2 | Delta sync uses a **temporary `genesis-delta-<utc-timestamp>` package**, deleted at the end of every run (success or failure), plus a **leftover sweep** at the start of each run. |
| D3 | **Implementation packages are deferred** (backlog `implementation-packages.md`): one package per story, named `GNS_000123 – <story title>`, sharing the same client + ADR. |
| D4 | **Deletions are ignored by delta syncs**; only a full sync removes deleted objects. |
| D5 | The delta package contains **the changed objects + all current entry-point roots**, so **bundles are rebuilt on every delta**; the parser resolves references against the **objects the KB already knows**. |
| D6 | **Fall back to a full sync** when changed objects > **500** or > **25%** of the app (both configurable), or the **last successful full sync is ≥ 7 days old** (configurable). Partial `addPackageObjects` failures / export-with-errors are **warnings, not fallbacks**. |
| D7 | **Look-back:** from the last successful sync's covered-until point (any kind), minus one day for the date filter, then an exact timestamp filter. The point only moves forward on success. |
| D8 | **One global schedule** for all tracked apps (serialized). Two modes: **every N hours within a window** and **fixed times**. Defaults: **enabled, every 4 h from 08:00 to 20:00, weekdays only, Asia/Kolkata (IST), full sync every 7 days.** |
| D9 | **Refresh = delta with the auto rules**; a separate **Full sync** action forces a full re-export. Runs show delta/full and why. |
| D10 | **After every successful sync** (scheduled or manual) publish the **full snapshot built from the KB** to the Hub (same blob format, no Hub change). Teammates' always-on auto-pull also pulls the KB. |
| D11 | **Collaboration:** a per-machine **"Run scheduled syncs on this machine"** setting, hidden when collaboration is off; **defaults off when collaboration is on**. Manual syncs on any machine still publish. |
| D12 | **Upgrade Genesis's Dev MCP bundle to 26.6.110**; a plugin/bundle mismatch is reported clearly in Settings and in failed runs. |

## 4. Current state (what we build on) — code-grounded

| Area | Today | File(s) |
|---|---|---|
| Sync workflow | `sync-application` v0.2.3: `resolve_inputs → export_package → v_export → parse_package → v_parse → write_kb → v_kb → present`. Already supports `package_uuid` (Deployment REST `exportType=package`). | `genesis-workflows/workflows/sync-application/graph.py` |
| KB merge | `KbStore.apply(mode='delta')` treats the parse as the **whole app**: removed = current − parsed; closes every edge not in the parse; replaces the whole bundle set. | `genesis/kb/store.py` |
| Parser | Reference lookups are built **only from objects inside the zip** → an edge exists only if its target is in the same package. Bundles, orphans, hub and inbound/outbound are whole-package computations. `KbBundle.root_uuid` is never populated (0/222 rows). | `genesis-appian-parser/.../api.py`, `dependencies/analyzer.py`, `output/bundle_coordinator.py` |
| Scheduler | `due_slot` supports only `kind:"daily_times"`. `ScheduleStore.ensure_defaults` **rewrites `schedule_json` on every boot** (user edits would be lost). `GET /system/schedules` is read-only. `application-sync` ships `enabled:false`. | `genesis/runtime/{scheduler,schedule_store,sync_jobs}.py`, `genesis/api/schedules.py` |
| Sync service | `ApplicationSyncService.resolve_mode` (auto/refresh/baseline/delta) + one-at-a-time guard. | `genesis/services/application_sync.py` |
| Hub KB | Publish is manual (`POST /applications/{uuid}/publish`) and sends the **latest run's `result.json`**; teammates' `hydrate_from_blob` **replaces** their KB with it. KB pulls only via the off-by-default `kb-hub-pull` job; the 10 s auto-pull loop doesn't pull the KB. | `genesis/api/applications.py`, `genesis/collab/service.py`, `genesis/kb/blob.py` |
| Dev MCP | Installed 26.6.90 (157 tools, `mcp_src_sha a037e2a2…`). Dev env plugin is **26.6.110** (`e8417471…`). `appian-dev` read-only allowlist = 72 tools, no `listObjects`. Fleet instances symlink the host `~/.genesis/mcp-servers`. | `genesis-workflows/mcp-registry.json`, `genesis/mcp/native/` |
| Direct Dev MCP calls | `kb/dev_mcp._call_tool` spawns one server process **per call**. | `genesis/kb/dev_mcp.py` |

## 5. Evidence (detail in `45-01-findings.md`)

- **Live trial on merge-assist-dev (AS GSS, 2026-10-12) — PASSED end to end:** `listObjects` since 2026-09-06 →
  22 objects in 5.6 s · `createPackage` 3.5 s · `addPackageObjects` 30/30 · Deployment REST export **8.9 s, 0.11 MB** ·
  parse 30 objects / 58 edges / 0 errors · vs KB: 19 new, 1 modified · `deletePackage` → 0 packages left.
- **Today's code would destroy the KB:** feeding a 40-object package to the current `apply(mode='delta')` on a KB copy
  → objects **2,763 → 41**, edges **18,044 → 40**, bundles **222 → 3**. A new incremental merge is mandatory.
- **KB-aware parsing is lossless:** with KB stubs as lookup context, edges for 260 package objects = **2,605/2,605
  (recall 1.000, 0 extra)**; bundles rebuilt from package-full roots + KB stubs = **202/202 identical** (membership,
  flow, entry point; 0 member-field diffs).
- **Sizes:** all 205 entry-point roots ≈ **1.9 MB** compressed (vs 8.05 MB full); parse 1.2 s vs 4.6 s.
- **Version gate:** 26.6.105+ servers refuse every call unless the site plugin's build matches.
- `lastModifiedOn` is **UTC**, millisecond precision. `listObjects(appUuid)` never returns AI Skills, Knowledge-Center
  root folders, or the Application object; every type it does return is a valid package type.
- **Full inventory listing is slow** (2,767 objects, 56 calls, 270 s) — reinforcing D4.

## 6. Design overview

```
resolve_inputs ─► plan_sync ──(full)──────────────────────────► export_app ─┐
   (mode, window,   │                                                         ├─► parse ─► write_kb ─► publish_hub ─► present
    due-for-full)   └─(incremental)─► build_delta_package ─► export_package ─┘   (KB-aware   (incremental   (best-effort,
                    └─(no changes)───► record_empty_sync ─► present               for delta)  merge)         snapshot from KB)
                     build_delta_package always ends with delete_package (finally) + leftover sweep at start
```

- **Mode resolution** (45-06, `ApplicationSyncService`): `baseline` if no baseline; `full` if forced or the last full
  is ≥ N days old; otherwise `incremental`. Inside the run, `plan_sync` upgrades `incremental → full` on size limits
  and records `fallback_reason`.
- **Package client** (45-05): one Dev MCP **session** (one handshake, many calls) exposed to workflows via
  `ctx.extras['devmcp_packages']`; hard-coded allowlist; delete guard on the `genesis-delta-` prefix.
- **KB-aware parse** (45-03): `parse(zip, known_objects=…, known_edges=…)` returns package objects + their edges,
  plus whole-app bundles, orphans and derived graph fields.
- **Incremental merge** (45-04): `KbStore.apply(mode='incremental')` touches only package objects and their
  outgoing edges, never removes objects, replaces bundles for covered roots, and updates derived fields in place.
- **Snapshot + publish** (45-04/45-08): `KbStore.export_snapshot(app_uuid)` → the existing blob format, sorted
  deterministically → `publish_kb` via `ctx.extras['kb_publish']`.
- **Scheduler + settings** (45-07): an `interval_window` schedule kind, a write API, a Settings → General
  **Application sync** card, and **Refresh / Full sync** actions.

## 7. Data model — migration m0023 (`current_version` 22 → 23)

Additive, idempotent (guarded `ADD COLUMN`):
- `scheduled_jobs.options_json TEXT` — job options (fallback limits, full-sync interval, run-on-this-machine).
- `scheduled_jobs.user_modified INTEGER NOT NULL DEFAULT 0` — `ensure_defaults` leaves `schedule_json` and
  `options_json` alone when set.
- `kb_syncs.details_json TEXT` — `{changed_count, fallback_reason, skipped_objects, export_warnings, package_name,
  covered_until}`.
- **Data step:** replace the `application-sync` row with the new default (enabled, every 4 h 08:00–20:00, weekdays,
  IST) **unless `user_modified`**. See open question Q2.
- New `kb_syncs.kind` values: `full` (the old `delta` full re-export; legacy rows keep `delta` and count as full) and
  `incremental`.

## 8. Sub-phase ledger

| Sub-phase | Repo(s) | Content |
|---|---|---|
| **45-01** | docs | Findings (trial + gap analysis) + ADR-073/074 drafted (this set) |
| **45-02** | genesis, genesis-workflows | Adopt Dev MCP **26.6.110**: host install (fleet shares it), `listObjects` on the `appian-dev` read-only allowlist, version-mismatch detection + reporting |
| **45-03** | genesis-appian-parser | KB-aware incremental parse (`known_objects`/`known_edges`), mixed-input bundles, whole-app derived fields, `root_uuid` fix → **v0.3.0** |
| **45-04** | genesis | m0023; `KbStore.apply(mode='incremental')`; derived-field in-place update; `export_snapshot`; `KbStore.known_context` for the parser |
| **45-05** | genesis | Dev MCP **session client** + `DevMcpPackages` (listing, package lifecycle, guards, leftover sweep) via `ctx.extras` |
| **45-06** | genesis-workflows (+ genesis service) | `sync-application` **v0.3.0**: `plan_sync`, `build_delta_package`, KB-aware parse, incremental write, fallback rules, empty-sync path; `ApplicationSyncService` modes `full`/`incremental`/`refresh` |
| **45-07** | genesis | Scheduler `interval_window` kind + `ensure_defaults` fix + sync-settings API + Settings → General **Application sync** card + **Refresh / Full sync** actions + Syncs-tab detail |
| **45-08** | genesis | Collaboration: `publish_hub` node via `ctx.extras['kb_publish']`, manual Publish via the snapshot, KB in the auto-pull loop, designated-machine setting |
| **45-09** | all | Independent review + hardening + **live acceptance** on merge-assist-dev |
| **45-10** | all | Release (parser → genesis → genesis-workflows), ADR-073/074 → Accepted, docs, fleet redeploy |

## 9. Release plan

ADR-019 order: **genesis-appian-parser v0.3.0 → genesis v0.76.0** (re-pins the parser) **→ genesis-workflows v0.21.0**
(re-pins genesis v0.76.0 + genesis-core v0.9.8; fixes the stale genesis@v0.73.0 dev pin). genesis-core,
kiro-agent-sdk and the Hub are unchanged. Host: install the 26.6.110 bundle (shared with the fleet), then
`gsm provision --all --no-mcp --no-env --force` + `gsm restart --all`. Fresh DB → **v23**.

## 10. Scope

**In:** everything in §3/§8. **Out (deferred):** implementation packages (backlog `implementation-packages.md`);
deletion detection on delta (D4 — the full sync handles it); delta-sync of types `listObjects` doesn't return (AI
Skills, KC root folders, the Application — weekly full); per-app schedules; auto re-sync after an implementation run
(backlog `kb-resync-after-implementation.md` — now cheap, a natural next step); browser/SSO Dev MCP auth.

## 11. Risks

| Risk | Mitigation |
|---|---|
| A crash leaves a `genesis-delta-*` package in the app | `finally` delete + start-of-run sweep (prefix-scoped) + run report names it |
| Plugin upgraded on the site without updating the bundle → every call refused | 45-02 mismatch detection: actionable error in runs + a Settings banner |
| Snapshot drift (KB stale vs env) → a missed edge target | Delta is idempotent; weekly full sync re-baselines; KB-aware recall measured 1.000 on a current KB |
| An existing object newly associated with the app but not modified is missed by the date filter | Caught by the weekly full sync (documented) |
| Two machines publish concurrently | Whole-snapshot uploads + content-hash dedup; designated machine (D11) |
| Editing schedules lost on restart | m0023 `user_modified` + `ensure_defaults` fix (45-07) |

## 12. Open questions (to confirm before 45-02)

- **Q1 — package tools have no registry entry.** D1 originally proposed a separate `appian-dev-packages` registry
  entry. Since the tools are called only by Genesis code over a direct session (not injected into any agent), I
  propose **no registry entry at all**: the allowlist lives in the client code, so no agent or chat can ever be granted
  them. `listObjects` still joins the read-only `appian-dev` allowlist. Confirm.
- **Q2 — enabling on existing installs.** Existing installs persist `application-sync` as disabled. m0023 would replace
  it with the new enabled default. But with collaboration on (both fleet instances today), "run on this machine"
  defaults **off**, so **no machine would run the schedule until someone turns it on**. Confirm: auto-enable via
  m0023, and should `main` be the designated machine on our fleet?
- **Q3 — derived graph fields are updated in place** (inbound/outbound counts, hub, orphan, bundled flags on
  unchanged objects) instead of SCD-2 versioning them, so unchanged objects don't get a new version on every delta.
  Confirm.
