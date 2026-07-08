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
(role filter + bundles + cross-role picking), Q10 (pinned refs; subprocess-worker execution + genesis-core major-compat gate).

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
  3. Ensure `genesis-core` present and **major-compatible** with the platform (ADR-019); refuse the install if the library ref targets a different `genesis_core` major.
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
  "genesis_core": {"version":"1.0.0","major":1,"ref":"v3.4.0"}
}
```
Update detection: compare per-workflow `ref`/`version` in the lockfile vs latest
catalog; surface `updatable: true`. (Coarse ref-level like solutions-copilot;
optional per-file blob-sha later.)

### 4.5 Loader + compat gate (`genesis/dist/loader.py`)
- `installed() -> list[InstalledWorkflow]` from filesystem + lockfile.
- **genesis-core major-compat gate (ADR-019):** before loading, compare the
  installed library's declared `genesis_core` **major** (from the lockfile) with
  the platform's pinned `genesis_core` major. On mismatch, **refuse to load** with
  a clear, actionable message (upgrade platform or install a compatible library
  ref) — never load a skewed workflow.
- `meta_of(id) -> META`: read a workflow's static `META` **without executing the
  graph** — parse `workflow.yaml` (the side-effect-free twin) for the catalog +
  prereq checks. `META` in `graph.py` is only imported inside the worker.
- `spawn(id) -> Worker`: the loader does **not** import/run `build()` in the app
  process. It hands the workflow id + resolved `PlatformContext` inputs to a
  **subprocess worker** (ADR-012) which imports `graph.py`, calls `build(ctx)`,
  and runs the graph against the shared `genesis.db`. Sanity: `META.id==id`.
- **Containment (honest):** because execution is out-of-process, a workflow's
  `sys.exit()`, segfault, hang, leak, or global mutation kills only the worker,
  not the app/UI. `meta_of` (yaml parse) is safe in-process; anything that
  imports workflow Python happens in the worker.

### 4.6 Backend API surface (consumed by UI later)
`GET /catalog?role=`, `GET /installed`, `POST /install {ids|bundle}`,
`POST /update {id|all}`, `POST /remove {id}`, `GET /workflow/{id}/prereqs`.
(Served by the same local app process; Phase 4/7 build the UI on these.)

---

## 5. Task breakdown

1. `dist/gitlab.py` — REST client + tests (mock HTTP).
2. `dist/catalog.py` — fetch/parse/filter/prereqs + tests.
3. `dist/install.py` — resolve/install/update/remove + lockfile writes + tests (mock GitLab tree/raw).
4. `dist/loader.py` — `meta_of` (side-effect-free `workflow.yaml` read), the **genesis-core major-compat gate**, and `spawn` (hand off to a subprocess worker; no graph import in the app process) + tests incl. a refused-load-on-major-mismatch test.
5. Lockfile model + update detection + tests.
6. Bundle expansion + role filtering + cross-role selection + tests.
7. Prerequisite checks (MCP configured? CLI present?) — stub MCP-config source until Phase 4, then wire.
8. Backend API endpoints (thin) over the services.
9. Integration test: against a **fixture GitLab** (local git repo served, or recorded fixtures) install `hello-appian`, load it, run it via the Phase 1 harness.

---

## 6. Acceptance criteria

- [ ] Browse catalog filtered by role; bundles expand to the right workflow sets.
- [ ] Install a selection → files under `~/.genesis/library/`, lockfile updated with pinned ref.
- [ ] Loader reads a workflow's `META` (from `workflow.yaml`) **without executing graph code**; graph build/run happens only in a subprocess worker.
- [ ] **Compat gate:** installing/loading a library ref that targets a different `genesis_core` major is **refused** with a clear message (never silently loaded).
- [ ] Newer tag in the (fixture) repo → `updatable: true`; `update` bumps files + lockfile.
- [ ] `remove` deletes a workflow, retains shared files still in use.
- [ ] Prereq check reports which required MCP/CLI are missing before a run is attempted.
- [ ] A user can pick workflows across multiple roles in one install (Q5).

---

## 7. Risks

- **Fetching many small files via REST** is slow. Mitigation: fetch by folder
  tree in batches; consider a tarball endpoint or shallow `git archive` if slow.
- **`genesis-core` version skew** between library ref and platform. Mitigation:
  semver + additive-within-major; lockfile records `genesis_core` version + major;
  loader **refuses to load** on major mismatch (ADR-019) — detection-only is not enough.
- **Execution safety:** graph code runs in a **subprocess worker** (ADR-012), not
  in-process — so `sys.exit()`, segfaults, hangs, leaks, and global mutation kill
  only the worker, not the app. (In-process `except ImportError` would contain
  only Python exceptions; that was the flaw in the original plan.) The app only
  parses `workflow.yaml` for `META`; it never imports workflow Python.

---

## 8. Deliverables

- `genesis/dist/` (gitlab, catalog, install, loader) + lockfile model + backend APIs + tests.
- Verified install→load→run of `hello-appian` from a fixture library.
