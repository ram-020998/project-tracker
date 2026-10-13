# Phase 45 — Incremental Delta Sync — progress (as-built)

> Spec: `specs/phase-45-incremental-delta-sync.md` (+ `45-01..45-10`). ADR-073/074 **Proposed**.
> Build started 2026-10-13 on the user's go-ahead. All code commits are **local only** (no push/tag until the 45-10
> release go-ahead).

## Ledger

| Sub-phase | Status | Commits (local) | Review |
|---|---|---|---|
| 45-01 findings | ✅ done (2026-10-12) | docs only | — |
| 45-02 Dev MCP 26.6.110 | ✅ built + host bundle installed; live acceptance ✅ 2026-10-13 | genesis `22c0988` · genesis-workflows `4e6f1ef` | SHIP |
| 45-03 parser v0.3.0 | ✅ built | genesis-appian-parser `2835ff4`, `dfb316c` | SHIP |
| 45-04 KB merge + m0023 | ✅ built; fleet DBs at v23 | genesis `d93420e`, `9d4beb3` | SHIP |
| 45-05 package client | ✅ built + live-verified | genesis `61b048b`, `eac555d` | SHIP |
| 45-06 sync workflow | ✅ built | genesis-workflows `f05ea97`, `c591a5b` · genesis `3714215` | SHIP |
| 45-07 scheduler + settings | ✅ built (not yet live) | genesis `dad4433`, `9a2afa8` | SHIP |
| 45-08 collaboration | ✅ built (not yet live) | genesis `2b686fc`, `1a1b275` · genesis-workflows `ca7ece8` | SHIP |
| 45-09 review + acceptance | ✅ review SHIP + live acceptance 1–8 passed | genesis-workflows `80f84f1` · genesis `0867f49` (F1) | SHIP |
| 45-10 release | pending (needs go-ahead) | | |

## 45-02 — Adopt Dev MCP 26.6.110 (2026-10-13)

**genesis-workflows `4e6f1ef`**
- `mcp-registry.json`: `listObjects` added to the read-only `appian-dev` allowlist (72 → **73**).
- New **`appian-dev-packages`** entry: managed reuse of the `appian-dev` binary + identical env, `read-write`,
  allowlist `listPackages, getPackage, createPackage, updatePackage, addPackageObjects, removePackageObjects`.
  **No `deletePackage`, no DB-script tools.** Not injected by any workflow node or chat.
- `workflows/sync-application/tests/test_package_registry.py` (6 guards): `listObjects` on `appian-dev`; the new entry
  is a managed reuse with the dev env; its allowlist is exactly the agent-safe set; package tools appear only there;
  no entry exposes `deletePackage`/DB-script tools; no `graph.py` references `appian-dev-packages`.

**genesis `22c0988`**
- `kb/dev_mcp.py`: `classify_tool_error(text)` → `version_mismatch | auth | unreachable | other` (matches the real
  `Refused:` gate texts); `parse_version_info(payload, site_url)` over the real `getDevMcpVersionInfo` shape
  (plugin camelCase `version/buildTimestamp/mcpSrcSha`, server snake_case `mcp_src_sha/build_timestamp`);
  `version_info(config)` (live, never raises); `mismatch_message(...)`; `DEV_MCP_BUNDLE_PATH`.
- `ConfigService.dev_connection_check(live=False)`: the default stays headless; `live=True` adds a `devmcp` block and
  flags "Dev MCP plugin/bundle version mismatch".
- API: `GET /config/environments/dev/check?live=true` (the Test-connection button) + `GET /config/devmcp/version`.
- `_INTERNAL_MCP` += `appian-dev-packages` (hidden from catalog prerequisites — the Phase-44 lesson).
- Web: `DevMcpVersionBanner` (role alert on mismatch, status on match) in the `appian-dev` managed-bundle panel and
  in Environments → Test connection; `useDevMcpVersion` (5-min cache, no retry), invalidated after an install.
- Tests: `tests/test_devmcp_version_gate.py` (17) + 3 web tests (mismatch alert + jest-axe, match all-clear,
  Test connection sends `live=true`).

**Gates:** genesis pytest **869** + ruff clean · web tsc clean, eslint 0 errors, vitest **291**, build committed
(stale-bundle clean) · genesis-workflows validate_library 13 + pytest **219**. Independent review: **SHIP** (3 NITs,
none blocking).

**Host install (2026-10-13):** `genesis mcp install-native appian-dev --bundle …/26.6.110/…tar.gz` →
appian-dev **`0.1.0+665da294`** (active; BUILD-INFO `mcp_src_sha e84174719e61709c`, build `20261008-132401`) + sail
**`20261008-132401`**. Prior `0.1.0+528e6bbb` (26.6.90) kept for rollback. No runs were active on either fleet
instance. Local `tools/list` = **200 tools**, incl. `listObjects` and all 11 package tools; every tool on the
`appian-dev`, `appian-dev-write` and `appian-dev-packages` allowlists exists on the server.

**Live acceptance ✅ (2026-10-13, after the dev env came back from maintenance):** `dev_mcp.version_info` →
match=True, plugin 26.6.110, plugin_sha == server_sha == `e84174719e61709c`; `GET /api/config/devmcp/version` → match
true on **both** main :8760 and userb :8761; `GET /config/environments/dev/check?live=true` ok on both; `listObjects`
(AS GSS, `lastModifiedFrom=2026-10-01`) returned 1 item (a GROUP, `lastModifiedOn "2026-10-12 09:25:45.027"`) from the
host state and from userb's state dir. Note: userb first returned 401 on `/meta` + `listApplications` — a stale userb
dev-env password, fixed by the user in userb's Settings; not a code issue. History of the block:
**Not yet verified (blocked):** the live plugin comparison. `merge-assist-dev.appianpreview.com` does not resolve
from this machine right now (DNS `Errno 8`; same symptom as run `r-d58d41ce124c`), so `getDevMcpVersionInfo` reports
the plugin as unreachable (`match = null`). The server half is confirmed (`e8417471…`, which equals the plugin sha
recorded on 2026-10-12). Re-check once the network is back: Settings → MCP → appian-dev shows "Matches…", and
`listObjects` works from both fleet instances (after `gsm restart --all` picks up the working tree).

## 45-03 — Parser: KB-aware incremental parse (2026-10-13)

**genesis-appian-parser `2835ff4` + `dfb316c` → v0.3.0 (local; not tagged).**
- `parse(zip, known_objects=[KnownObject], known_edges=[KnownEdge])`: package objects + their outgoing edges only
  (references resolve against package + KB stubs); whole-app bundles, orphans and derived fields;
  `stats.derived` (every object) + `stats.incremental` (`package_objects`, `known_objects`,
  `edges_resolved_external`, `skipped_entry_points`, `incomplete_flow_bundles`).
- `delta_roots(known_objects)` — what every delta package must contain besides the changed objects: entry points,
  all Process Models / Sites / Web APIs / Control Panels, Record Types with actions or views, label-bundle Documents.
- `KbBundle.root_uuid` now set (was always None).
- New code-free metadata: Document `filename`, CDT `table`, Data Store `entities`, Constant `data_store_entity_uuid`.
- `DependencyAnalyzer.analyze(lookup_objects=)`, `BundleCoordinator.build_all_v3(entry_filter=)` (additive).
- `ruff==0.15.20` pinned; `__version__` fixed (was a stale "0.1.0").

**Evidence:** the equivalence oracle (`tests/test_incremental.py`, 13 tests incl. brand-new objects) passes on the
vendored fixture **and** on the real AS GSS export: edges recall = precision = 1.0; **230/230 bundles identical**
(flows + key objects included); `stats.derived` identical for all 2,929 objects. Full mode is identical to v0.2.0
(fixed `PYTHONeac555dSEED`) except `root_uuid` and the new metadata keys — confirmed independently by the reviewer.
Parser pytest **48**; genesis pytest **869** and genesis-workflows sync-application **20** unaffected.

**Design refinements found while building** (recorded in `45-03` §6; they change 45-04/45-06):
- Delta packages use `delta_roots` (AS GSS: 224 roots ≈ 2.0 MB with 60 changed objects; full export 8.05 MB).
- A KB built by parser < 0.3.0 lacks the new stub metadata → **the first sync after the upgrade must be full**;
  45-04 must refresh `metadata_json` in place for unchanged objects on full syncs.
- `known_objects` must be passed in KB row order (cross-type name collisions are order-sensitive).
- Bundle member order varies with `PYTHONeac555dSEED` (pre-existing) → `export_snapshot` must sort.

## 45-04 — KB: m0023, incremental merge, snapshot (2026-10-13)

**genesis `d93420e` + `9d4beb3` (local).**
- **m0023** (schema only; DB → v23): `kb_syncs.details_json`, `scheduled_jobs.options_json`,
  `scheduled_jobs.user_modified`. The schedule-default adoption moved to `ensure_defaults` (45-07) — see 45-04 §7.
- `KbStore.apply(mode='incremental')` → `_apply_incremental`: package objects (open / close+open / refresh in place),
  their outgoing edges only, **never closes an object**, bundles replaced (kept when the package was incomplete),
  whole-app derived fields in place, business map stale only on a real change.
- Guards: `full`/`delta`/`baseline` refuse a partial (`stats.incremental`) result; `incremental` requires one.
  `delta` = alias of `full`; full mode now refreshes unchanged objects' derived metadata in place.
- `known_context(app)` (parser `KnownObject`/`KnownEdge`, KB row order), `export_snapshot(app)` (deterministic
  `serialize_result` dict; byte-identical across calls and after a hydrate on another DB — reviewer-verified),
  `last_successful_sync(app, kinds=)`, `finish_sync(details=)`, `update_sync_details`, `list_syncs[].details`.

**Evidence:** `tests/test_kb_incremental.py` (10) incl. a real-parser end-to-end regression; on a backup copy of
the live KB, an incremental merge of a 262-object AS GSS delta package left **2,929 objects / 19,009 edges /
230 bundles** unchanged (apply 0.5 s). genesis pytest **879** + ruff; workflows **219**; fresh DB → v23.
Review: **SHIP** (SHOULD: the genesis → parser pin must move to v0.3.0 at 45-10 — `known_context` imports
0.3.0 symbols; works locally via the editable install).

**Fleet:** both instances restarted (no running runs; one gated run, which resumes from its checkpoint) → both DBs
migrated to **v23** (schema-only, backward compatible). Done to remove the hazard of the running servers' workers
(which load the working tree) writing `details_json` into a v22 DB.

## 45-05 — Dev MCP session + package client (2026-10-13)

**genesis `61b048b` + `eac555d` (local).**
- `kb/dev_mcp.py`: `DevMcpToolError(kind)`, `tool_result_data`, **`DevMcpSession`** — one stdio process + one
  handshake for many `tools/call`; private event loop in a daemon thread (safe from `asyncio.to_thread`); stderr
  drained; 8 MiB lines; timeouts → `kind="unreachable"`; env values never in messages.
- `kb/dev_packages.py` (new): **`DevMcpPackages`** — hard-coded `ALLOWED_TOOLS`, `DELTA_PREFIX`, `list_changed`
  (day-before date window + exact `lastModifiedOn > after`, dedupe), `create_delta_package` → `{uuid, name}`,
  `add_objects` (batches of 50; **bisects a poisoned batch**; `skipped` for non-package types), `get_package`,
  `delete_delta_package` (always re-reads the name), `sweep_leftovers`, `package_type` (listObjects/package/KB types).
- `ctx.extras["devmcp_packages"]` = `lambda: open_packages(mcp)`; spec = `appian-dev-packages`, else `appian-dev`.

**Live findings (merge-assist-dev, AS GSS):** `addPackageObjects`' `failed` is a count, errors are in `errors[]`;
**one unresolvable uuid fails its whole batch** (→ bisection: 22 changed + 1 bogus → 22 added, 1 error, 7 calls);
`QUERY_RULE` is rejected (alias kept). Session open 1.2 s; `list_changed` 22 objects in 3.0 s. Every temp package was
deleted in `finally`; `listPackages` → **0** `genesis-delta-*` afterwards.

**Evidence:** `tests/test_dev_packages.py` (15; fake stdio server with the real shapes incl. batch poisoning);
genesis pytest **894** + ruff. Review: **SHIP** (SHOULDs fixed in `eac555d`: no double count on uuid-less errors,
paging no-progress guard, timed-out-request follow-up test; NIT: stderr task cancelled).

## 45-06 — sync-application v0.3.0 + ApplicationSyncService modes (2026-10-13)

**genesis-workflows `f05ea97` + `c591a5b`, genesis `3714215` (local).**
- Modes `auto` (default; `refresh`) · `baseline` · `full` (legacy `delta`) · `incremental`; `options`
  `{full_every_days, max_changed, max_changed_pct}`.
- Graph: `resolve_inputs → plan_sync →{export_package | build_delta_package | record_empty_sync}` → v_export →
  parse (KB-aware for incremental) → write_kb → v_kb → present. Every delta package is deleted in `finally`;
  an export retry rebuilds its own package.
- Full instead of incremental when: no full sync / older-parser KB (`details.parser_version`) / last full ≥
  `full_every_days` (auto only) / too many changes / Dev MCP unreachable / platform lacks the package client.
  Dev MCP `version_mismatch` / `auth` → terminal error.
- `details`: `covered_until` (instant before export/listing), `parser_version`, `sync_kind`, `fallback_reason`,
  `changed_count`, `package_name`, `skipped_*`, `export_warnings`.
- genesis `ApplicationSyncService.resolve_mode` → `auto|baseline|full|incremental`, **adapted to the installed
  workflow's mode enum** (library 0.20.0 / sync-application 0.2.3 → `delta`), so the fleet keeps working until
  re-provisioning at 45-10.

**Evidence:** workflows pytest **233** + validate 13; genesis pytest **896** + ruff. Offline real-parser run
(vendored export): baseline 2,620/10,617/174 → incremental of 25 changed (176-object delta package, deleted) →
KB unchanged. Review **SHIP** (SHOULD: document why `covered_until` advances past skipped objects — done in `c591a5b`).

## 45-07 — Scheduler, sync settings, Settings card, Refresh / Full sync (2026-10-13)

**genesis `dad4433` + `9a2afa8` (local; the fleet has not been restarted onto it).**
- Scheduler: `interval_window` (expanded to fixed slots → restart-safe, no double fire), `validate_schedule`,
  `Scheduler.run_now` (does not move `last_fired_slot`).
- `ensure_defaults`: user edits (`user_modified`) are never overwritten; the new `application-sync` default
  (enabled, every 4 h 08:00–20:00 IST weekdays, options) is adopted once by a pre-45 row.
- Handler: collaboration on + not the designated machine → skipped; installed workflow without incremental →
  skipped; else mode auto + the configured thresholds; summary counts kinds.
- API: `GET/PUT /api/system/sync-settings`, `POST /api/system/sync-settings/run-now`.
- Web: Settings → General **Application sync** card (frequency modes, weekdays, time zone, full-sync cadence,
  advanced thresholds, designated-machine switch when collaboration is on, status + per-app table, Run now);
  application page **Refresh** = `auto` + **Full sync** (confirm); Syncs tab kinds / changed / fallback / skipped / Hub version.

**Evidence:** genesis pytest **915** + ruff; web vitest **298**, tsc, eslint 0 errors, build committed. Review **SHIP**.

## 45-08 — Collaboration: snapshot publish, KB auto-pull, designated machine (2026-10-13)

**genesis `2b686fc` + `1a1b275`, genesis-workflows `ca7ece8` (local; not live — no fleet restart / re-provision).**
- `ctx.extras["kb_publish"](app)` → best-effort snapshot publish (`export_snapshot`, dedup); the workflow's
  `publish_hub` node runs after every successful sync (incl. empty) and records `published_version`.
- Manual **Publish** now sends the snapshot (the partial-result hazard is gone; `_latest_result_json` removed).
- `autopull_tick(kb_store, is_syncing=)`: a Hub `blob` change for a tracked app → `pull_kb_if_newer`; deferred while
  a local sync runs (persisted pending set). The publisher never re-pulls its own version.
- **Found:** the LocalHubProvider emitted blob change rows as kind `kb`/`artifact`; the contract says `blob` — fixed.
- **Added:** repeat hydrates are a full-mode diff (no whole-app SCD-2 copy per pull); `hub-pull` rows are not
  incremental anchors (the listing uses this machine's own last sync).
- Status: `last_published_version` per app; card text for the designated machine.

**Evidence:** genesis pytest **922** (+6 two-instance tests on the LocalHubProvider: an incremental sync on A reaches
B in ONE tick with identical objects/edges/bundles); workflows pytest +3; web 298 + build. Review **SHIP**.

## 45-09 — Whole-phase review (2026-10-13)

Independent whole-phase review of 45-02..45-08 = **SHIP** (no MUST-FIX). Verified across sub-phases: the
environment-write boundary (no agent/chat path to package tools; every workflow path deletes its package), KB
integrity end-to-end, version skew handled in both directions (new genesis + old library; new library + incapable
platform), scheduler + collaboration, error mapping, §7 lessons; all three trees clean.
NIT-1 fixed in genesis-workflows `80f84f1` (an incremental merge that removed objects is never marked succeeded).

Gates: parser pytest + ruff; genesis **922** + ruff + fresh DB v23; web tsc + eslint 0 errors + vitest **298**;
workflows validate 13 + pytest **236**.

**Release checklist (45-10, from the review):** re-pin genesis → parser v0.3.0, bump genesis 0.76.0 (+ version.ts +
static); genesis-workflows 0.21.0 re-pinning genesis v0.76.0 (+ core v0.9.8); order parser → genesis → workflows;
`gsm provision --all --no-mcp --no-env --force` + restart; `main` = designated machine; expect the FIRST sync per app
to be FULL (parser_version rule); ADR-073/074 → Accepted + bible chunks + backlog notes + status rows.

**Live acceptance (45-09 §3): not started — needs the user's go-ahead** (fleet re-provision + restart, live KB writes,
Hub publishes, temp genesis-delta packages; step 5 needs a human edit in Appian).

## 45-09 — Live acceptance (2026-10-13) — all 8 steps passed

Fleet re-provisioned (sync-application 0.3.0) + restarted. AS GSS: first Refresh = **full** (older-parser rule),
2,763 → 2,782 objects; then an **empty** incremental (10 s); Full sync (0 removed); after the user's edit of
`AS_GSS_API_RESPONSE_STATUS_CODE_400`, a Refresh synced **exactly that constant** (incremental, 1 changed, delta
package deleted). Hub KB v1 → v3, each hydrated on userb within ~20–25 s (diff-based). Schedule: main (designated) ran
once per app, userb skipped. Killed worker → leftover package swept (`older_than_minutes=0`). Renamed bundle dir →
clear errors. `listPackages` → 0 after every step. Details + run ids: 45-09 spec §5.

Findings: **F1** live Hub emits no `blob` change rows → fixed (`0867f49`, 60 s KB poll); **F2** a Decision's
`versionKey` changes its hash every export (parser follow-up); **F3** RU Sandbox no longer exists in the env
(untrack pending the user); **F4** incremental build is slower than a full export (addPackageObjects ≈0.3–1.1 s per
object × ~220 roots) — design follow-up.
