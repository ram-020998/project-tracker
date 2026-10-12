# 45-01 — Findings: Dev MCP 26.6.110 + delta-sync feasibility

> **Status:** ✅ DONE (analysis, 2026-10-12). Parent: `specs/phase-45-incremental-delta-sync.md`. Probe scripts
> (throwaway, not product code): `/tmp/devmcp-probe/{probe,delta_sim,gap_a,gap_a2,trial}.py`.

## 1. The bundle (26.6.110)

- `appian-dev-mcp-server-bundle.tar.gz`, build `20261008-132401`, `mcp_src_sha e84174719e61709c`, requires
  Python ≥ 3.13. Same layout as 26.6.90 (`src/lcp_mcp_server`, `sdk/`, `lib/`, `bin/sail-*`, `skills/appian`).
- **200 tools** vs 157 in the installed 26.6.90 (`0.1.0+528e6bbb`): **+43, none removed**. New relevant tools:
  - `listObjects(types?, query?, lastModifiedBy?, lastModifiedFrom?, lastModifiedTo?, appUuid?, limit=25 ≤50,
    offset)` → `{items:[{uuid,name,description,type,lastModifiedBy,lastModifiedOn,url}], total, limit, offset}`,
    most recently modified first. Date filters are ISO **dates** (`yyyy-MM-dd`).
  - Package tools: `listPackages(appUuid)`, `getPackage(uuid)`, `createPackage(name, appUuid, description?, …)`,
    `updatePackage`, `deletePackage(uuid)`, `addPackageObjects(uuid, objects[{uuid,type}])`,
    `removePackageObjects`, + DB-script tools. `addPackageObjects` returns
    `{success, added, failed, packageUuid, message}` — partial failure is reported in `failed`, not by status.
  - Release tools (`create/get/list/update/deleteRelease`) — not needed here.
- **Version gate (new in 26.6.105):** `VersionGateMiddleware` refuses **every** tool call (except
  `getDevMcpVersionInfo`/`logout`) unless the site plugin's `/meta` `mcp_src_sha` equals the server's own
  BUILD-INFO sha. A match is cached for 300 s; a mismatch is never cached.

## 2. The environment

- merge-assist-dev plugin: **26.6.110**, `mcpSrcSha e84174719e61709c` → matches the new bundle. AppMarket status
  `UP_TO_DATE`.
- Genesis still runs 26.6.90 against it; it works only because 26.6.90 predates the gate. `getDevMcpVersionInfo`
  already recommends updating the server.
- Deployment REST API key valid (bogus deployment id → 404 `APNX-1-4552-007`).
- The dev-env password had expired (401 `APNX-1-4187-005`); reset by the user 2026-10-12.

## 3. Live trial — AS GSS Full Application (passed)

| Step | Result |
|---|---|
| `listObjects(appUuid, lastModifiedFrom=2026-09-06)` | 22 objects in 5.6 s: 9 RECORD_TYPE, 8 EXPRESSION_RULE, 3 CONSTANT, 2 GROUP. 20 by `kiroDeveloper` (Phase-42 implementation) |
| `createPackage("genesis-delta-trial-…")` | 3.5 s |
| `addPackageObjects` (22 changed + 8 roots) | 30/30 added, `failed` empty |
| `getPackage` | `objectCount` 30 |
| Deployment REST export (`exportType=package`) | `COMPLETED` in 8.9 s, **0.11 MB** |
| `parse()` | 30 objects, 58 edges, 17 bundles, 0 errors |
| vs KB | 19 new, 1 modified, 10 unchanged |
| `deletePackage` | ok; `listPackages` → 0 |

The exported package zip has **no `application/` XML** (top level: `META-INF`, `content`, `group`, `patches.xml`,
`processModel`, `recordType`).

## 4. Data facts

- `lastModifiedOn` = `YYYY-MM-DD HH:MM:SS.mmm`, **UTC**: kiroDeveloper edits at 09:06 fall inside implementation
  run `r-552a26759251` (09:01–09:09 UTC).
- `listObjects(appUuid)` type vocabulary (2,767 objects): EXPRESSION_RULE, CONSTANT, INTERFACE, PROCESS_MODEL,
  DATA_TYPE, GROUP, DOCUMENT, RECORD_TYPE, FOLDER, INTEGRATION, DATA_STORE, CONNECTED_SYSTEM, WEB_API, SITE, DECISION
  — **every one is a valid `addPackageObjects` type**, same spelling.
- KB objects `listObjects(appUuid)` **never returns**: AI Skill (9), Knowledge-Center root Folders (5), Application (1).
- Full inventory listing: 2,767 objects, 56 calls, **270 s** — too slow for every delta.
- Entry-point roots: **205** (139 Process Model, 58 Record Type, 5 Web API, 3 Site). A roots-only package is
  **1.89 MB** compressed (full export 8.05 MB); parse 1.2 s vs 4.6 s.

## 5. Offline simulations (real export `r-dec40e4aebd3`, 2,929 objects / 19,009 edges)

**Today's code on a 40-object sub-package:**
- Parser: **196/196 (100%)** of the changed objects' outgoing edges lost — lookups only see the zip.
- `KbStore.apply(mode='delta')` on a KB copy: objects **2,763 → 41**, edges **18,044 → 40**, bundles **222 → 3**,
  `objects_removed` 2,727.
- `diff_hash` identical full-vs-partial for 40/40 → change detection works on a sub-package.

**KB-aware parse (stubs = the same snapshot's code-free KB metadata):**
- Edges for all 260 package objects (60 changed + 205 roots): **2,605/2,605**, recall **1.000**, 0 extra.
- Bundles from package-full objects + KB stubs + the full edge set: **202/202** identical membership, flow and entry
  point; **0** member-field diffs.
- Stub needs: `uuid, name, type, metadata` (CDT `namespace` present 107/107) + `description` — all already stored.
- Against the *live* KB (an older snapshot), recall was 194/196; the 2 misses are drift (targets not yet in the KB).
  The weekly full sync bounds this.

## 6. Platform gaps found

1. `KbStore.apply(mode='delta')` is whole-app semantics → needs `mode='incremental'` (45-04).
2. Parser lookups are package-scoped → needs `known_objects`/`known_edges` (45-03).
3. `KbBundle.root_uuid` never set (0/222) — fix in 45-03.
4. `ScheduleStore.ensure_defaults` rewrites `schedule_json` on every boot → user edits would be lost (45-07).
5. `due_slot` only supports fixed daily times (45-07).
6. Hub publish sends the run's `result.json` → a partial result would wipe teammates' KBs on hydrate (45-08).
7. The 10 s auto-pull loop doesn't pull the KB; KB blob puts already append a `blob` change row
   (`genesis-hub-api.md`) → the loop can detect them cheaply (45-08).
8. `kb/dev_mcp._call_tool` spawns one process per call → needs a session client for ~10–60 calls per run (45-05).
9. `kb_syncs` has no details column (45-04, m0023).
10. genesis-workflows dev-pins genesis@v0.73.0 (stale) — fix at release.

## 7. ADRs drafted

- **ADR-073 (Proposed)** — Environment package management (the only non-design-object write).
- **ADR-074 (Proposed)** — Incremental, package-scoped KB sync.
