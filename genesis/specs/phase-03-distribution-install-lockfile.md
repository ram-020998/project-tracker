# Phase 3 — Distribution: GitLab Pull, Selective Install & Lockfile

> **Goal:** Let the local app discover the workflow catalog from the shared
> `genesis-workflows` GitLab repo, **selectively install** the workflows a user
> needs (individually or via role bundles), pin them by ref in a **lockfile**,
> detect updates, and remove workflows — reusing solutions-copilot's proven
> distribution model, reimplemented for Genesis.

Prereq: `specs/00-architecture-overview.md`, Phase 2 (contract + registries).

---

## 1. Objective & success statement

A user can: connect (GitLab token) → browse the catalog (filtered by role, with
bundles) → install selected workflows (fetched + pinned) → see "update available"
when a newer tag exists → update or remove. Installed workflows live under
`~/.genesis/library/` and are loadable by the engine. All state tracked in
`installed.lock.json`.

---

## 2. Scope

**In scope:** GitLab REST client; catalog fetch/parse; selective install/update/
remove; lockfile; role-filtered + bundle install; prerequisite checks (which
`required_mcp`/`required_cli` are configured/available). Backend services only
(UI wiring is Phase 4/7; but expose clean APIs).
**Out of scope:** secrets/env config (Phase 4); run/HITL (Phase 5); custom UI (Phase 7).

---

## 3. Decisions applied

Q1 (shared GitLab library pulled locally), Q4 (selective install + lockfile), Q5
(role filter + bundles + cross-role picking), Q10 (pinned refs; in-process load).

---

## 4. Detailed design

### 4.1 GitLab client (`genesis/dist/gitlab.py`) — reuse concept
Minimal REST v4 client (std-lib HTTP), `PRIVATE-TOKEN` header:
- `get_raw_file(path, ref)` — fetch a file at a ref/tag.
- `list_tree(path, ref)` — recursive, paginated (to fetch a workflow folder).
- `get_latest_tag()` / `list_tags()` — update detection.
- Friendly 401/403/404 messages. Token from SecretProvider (Phase 4) — in Phase 3, read from env/config for backend tests.

### 4.2 Catalog service (`genesis/dist/catalog.py`)
- `fetch_catalog(ref) -> Catalog`: pull `registry.json` + `bundles.json` at a ref.
- `Catalog` = `{version, workflows:[{id,name,version,roles,summary,path,required_mcp,required_cli}], bundles}`.
- `filter(role=None, query=None)` for the UI.
- `prerequisites(workflow) -> {mcp:[{name,configured}], cli:[{name,present}]}` — cross-check against MCP registry config (Phase 4) + CLI registry (`ensure`).

### 4.3 Install service (`genesis/dist/install.py`)
- `resolve(selection) -> InstallPlan`: expand bundles → workflow ids; add the
  shared `common/`, `mcp-registry.json`, `cli-registry.json`, `registry.json`
  slice; determine ref (latest tag by default, or a pinned ref).
- `install(plan)`:
  1. `list_tree` + `get_raw_file` each selected `workflows/<id>/**` + shared files at the chosen ref.
  2. Write under `~/.genesis/library/` preserving structure.
  3. Ensure `genesis-common` present/compatible.
  4. Update `installed.lock.json`.
- `update(id)` / `update_all()` — re-fetch at latest tag; bump lockfile.
- `remove(id)` — delete files; update lockfile; keep shared files if still needed.

### 4.4 Lockfile (`~/.genesis/installed.lock.json`)
```json
{
  "version": 1,
  "libraryRef": "v3.4.0",
  "installedAt": "2026-07-08T…",
  "workflows": {
    "erd-generation": {"version":"1.2.0","ref":"v3.4.0","files":[…],"installedAt":"…"},
    "code-review":    {"version":"0.9.0","ref":"v3.4.0","files":[…]}
  },
  "common": {"version":"1.0.0","ref":"v3.4.0"}
}
```
Update detection: compare per-workflow `ref`/`version` in the lockfile vs latest
catalog; surface `updatable: true`. (Coarse ref-level like solutions-copilot;
optional per-file blob-sha later.)

### 4.5 Loader (`genesis/dist/loader.py`)
- `installed() -> list[InstalledWorkflow]` from filesystem + lockfile.
- `load(id) -> LoadedWorkflow`: import `~/.genesis/library/workflows/<id>/graph.py`,
  read `META`, return `{meta, build}`. In-process import (Q10). Sanity: `META.id==id`.
- Import isolation: add the library root to `sys.path`; catch import errors and
  surface them (don't crash the app).

### 4.6 Backend API surface (consumed by UI later)
`GET /catalog?role=`, `GET /installed`, `POST /install {ids|bundle}`,
`POST /update {id|all}`, `POST /remove {id}`, `GET /workflow/{id}/prereqs`.
(Served by the same local app process; Phase 4/7 build the UI on these.)

---

## 5. Task breakdown

1. `dist/gitlab.py` — REST client + tests (mock HTTP).
2. `dist/catalog.py` — fetch/parse/filter/prereqs + tests.
3. `dist/install.py` — resolve/install/update/remove + lockfile writes + tests (mock GitLab tree/raw).
4. `dist/loader.py` — in-process import of an installed workflow + `META` read + tests.
5. Lockfile model + update detection + tests.
6. Bundle expansion + role filtering + cross-role selection + tests.
7. Prerequisite checks (MCP configured? CLI present?) — stub MCP-config source until Phase 4, then wire.
8. Backend API endpoints (thin) over the services.
9. Integration test: against a **fixture GitLab** (local git repo served, or recorded fixtures) install `hello-appian`, load it, run it via the Phase 1 harness.

---

## 6. Acceptance criteria

- [ ] Browse catalog filtered by role; bundles expand to the right workflow sets.
- [ ] Install a selection → files under `~/.genesis/library/`, lockfile updated with pinned ref.
- [ ] Loader imports an installed workflow and returns a runnable `build` + valid `META`.
- [ ] Newer tag in the (fixture) repo → `updatable: true`; `update` bumps files + lockfile.
- [ ] `remove` deletes a workflow, retains shared files still in use.
- [ ] Prereq check reports which required MCP/CLI are missing before a run is attempted.
- [ ] A user can pick workflows across multiple roles in one install (Q5).

---

## 7. Risks

- **Fetching many small files via REST** is slow. Mitigation: fetch by folder
  tree in batches; consider a tarball endpoint or shallow `git archive` if slow.
- **`common` version skew** between library ref and platform. Mitigation:
  lockfile records `common` version; loader checks compatibility; warn/refuse on mismatch.
- **In-process import safety** (Q10 accepted): keep import failures contained;
  never let a bad workflow crash the app; log + mark the workflow unloadable.

---

## 8. Deliverables

- `genesis/dist/` (gitlab, catalog, install, loader) + lockfile model + backend APIs + tests.
- Verified install→load→run of `hello-appian` from a fixture library.
