# Phase 16-08 — Native Appian MCP server integration & updatability

> **Status:** §2.0 (dev-environment toggle) **SHIPPED** (genesis v0.30.0, CI green) · Stage B (managed-native installer)
> **NOT STARTED** · **Iteration:** 1 (prerequisite for 16-04/16-05) · **Repos:** genesis (+ genesis-core + genesis-workflows registry)
> **Update model (2026-08-05 decision):** **no auto-fetch update source** — new Dev/DevOps MCP releases are integrated
> **manually** (operator drops in a new bundle → Genesis installs it as a new version + swaps `current`; prior kept for
> rollback). §2.4 below is revised accordingly.
> **Depends on:** 16-04 uses it (list apps via Dev MCP), 16-05 uses it (`get_object_code` via Dev MCP); the sync
> pipeline (16-03) also uses the DevOps MCP for agent-facing deploy-ops (its own export path is deterministic REST).
> **Goal:** Establish the Appian **connectivity foundation** for Phase 16 and integrate the two **native Appian MCP
> servers**. First, a **dev-environment toggle** (§2.0): the Environments registry may hold many envs, but **exactly one**
> is tagged **dev** and supplies the URL + credentials for all Phase-16 auth (REST export, Dev MCP, DevOps MCP,
> changed-objects API). Then integrate the **Dev MCP** (`lcp-mcp-server`) and the **DevOps MCP**
> (`appian-deployment-mcp`) into Genesis as **managed, versioned, updatable** local MCP servers, so every *environment*
> call (per the tool-contracts doc §3) routes through them, and so a new Appian release of either server can be **taken
> and applied without forking**. Governing rule: **vendor them as opaque, replaceable artifacts — never modify the
> bundle source** (modification would break updatability). All Genesis-specific wiring lives *outside* the bundle.

---

## 1. Current state (grounded — the two bundles)

The user placed both bundles at `project-tracker/genesis/artifacts/mcp-servers/`:

| | **Dev MCP** | **DevOps MCP** |
|---|---|---|
| Package | `lcp-mcp-server` (bundle) | `appian-deployment-mcp` (artifact `1.0.0`; pyproject `0.1.0`) |
| Python | **≥ 3.13** (matches Genesis) | ≥ 3.11 |
| Deps | fastapi, fastmcp, httpx, pydantic(-settings), uvicorn, **playwright**, + **vendored local** `lib/{composer_logging,shared_mcp_utils,shared_auth_events}` + `sdk/{lcp-api-plugin-client,lcp-api-client,composer-api-plugin-client}` (editable path deps) | `mcp[cli]`, `httpx` (PyPI only); ships `uv.lock` |
| Install | `uv sync` (resolves at install; no root `uv.lock`) | `uv sync` (locked) or pip venv; `setup.sh` |
| Launch (stdio) | `python -m lcp_mcp_server` (also `sse_server.py`) | console script `appian-deployment` / `python -m appian_deployment_mcp` |
| Config (env) | `LCP_URL`, `LCP_API_PATH` (default `/suite/rest/a/lcp-api/latest`), **`LCP_AUTH_METHOD` = `basic` (default)** or `browser`; basic → `LCP_USERNAME`/`LCP_PASSWORD`; browser → playwright + `LCP_SIGNIN_PATH`/cookie/profile | `APPIAN_DOMAIN` + `APPIAN_API_KEY` (or `APPIAN_OAUTH_TOKEN`); multi-env `APPIAN_<ENV>_*`; keychain source option |
| **Update source** | **manual drop-in** — operator places a newer `lcp-mcp-server` bundle; Genesis re-installs + versions it (no auto-fetch) | **manual drop-in** — operator places a newer `appian-deployment-mcp-<v>.gz`; Genesis re-installs + versions it (no auto-fetch) |
| Tools | read+write design objects, list apps, eval SAIL, SQL, env info (+ write/deploy) | export/inspect/deploy/download + pipelines |

**Headless feasibility:** Dev MCP **Basic auth is the default** (username/password) → runnable headlessly by Genesis;
the **browser/playwright SSO path is optional** (SSO-only sites) and is **out of scope for the automated integration**
(documented manual step: `uv run playwright install chromium` + interactive login). DevOps MCP uses an API key →
headless-friendly.

Genesis MCP mechanics (from recon): the registry launches a server as `{command, args, env:[{name,value}]}`
(`genesis-core/mcp/registry.py`), env a **LIST**, `${VAR}` resolved SecretProvider → EnvironmentRegistry → os.environ.
Internal servers (introspection/control) launch via `sys.executable -m …`. These native servers instead launch from a
**per-server venv** created by `uv sync`.

## 2. Design

### 2.0 Dev-environment tagging (the connectivity foundation — build FIRST)
Genesis's Environments registry may hold **many** environments; Phase 16 needs to know **which one** is the Appian
environment to authenticate against. Add a single **`is_dev` toggle** to the environment record; **exactly one**
environment may be tagged dev (single-select), and that env supplies the URL + credentials for **all** Phase-16 auth
(the REST export, the Dev MCP, the DevOps MCP, and the changed-objects API). This is the **first** deliverable — nothing
downstream (available-apps enumeration, sync, KB) can reach the environment without it.
- **Model:** add `is_dev: bool` to the environment in `genesis/config/environments.py` (persisted in
  `~/.genesis/environments.json`; the record stays credential-free — secrets live in the SecretProvider). Additive +
  back-compatible (`_from_row`/loader tolerates its absence → `False`).
- **Single-select invariant:** enforced at write time in `EnvironmentRegistry`/`ConfigService` — setting `is_dev=true`
  on one env **clears it on all others** in the same transaction (never two dev envs). `POST/PUT /api/config/environments`
  carries the flag; a `set_dev_environment(label)` helper does the clear-others+set atomically.
- **Resolver:** `EnvironmentRegistry.dev_environment() -> Environment | None` — the single source used by the DevOps REST
  export (16-03), the Dev/DevOps MCP launch-spec env wiring (§2.5), the available-apps enumeration (16-04), and the
  changed-objects client (16-07). If none is tagged, these paths **fail fast** with "tag a dev environment in Settings".
- **Settings UX:** the Environments section (`web/src/features/settings/EnvironmentsSection`) gains an **"Is dev
  environment"** toggle in the add/edit dialog (single-select: toggling one visibly untags the others) + a **dev** badge
  on the list, and surfaces the Dev/DevOps credential fields for the dev-tagged env in one place (values → SecretProvider,
  referenced by key). A **"Test connection"** action verifies the dev env + both MCPs can reach it (calls the health
  check in §2.7).
- Credentials themselves are unchanged in mechanism (SecretProvider, server-scoped `appian-dev`/`appian-devops`); the
  toggle only decides **which env's URL + which secret scope** every Phase-16 caller resolves.

### 2.1 Managed install location + lockfile
- Install root: `~/.genesis/mcp-servers/<id>/versions/<version>/` (`id` ∈ `appian-dev`, `appian-devops`), each holding
  the **unpacked bundle + its `.venv`** (from `uv sync`). A per-server `current` pointer selects the active version;
  **keep the previous version** for rollback (reversible updates).
- Lockfile `~/.genesis/mcp-servers/lockfile.json` (own store, table-scoped to this concern — NOT `genesis.db`) records
  per server: `{id, active_version, versions:[{version, source, source_ref, sha256, installed_at, entry, python}], }`.
- Add `Settings.mcp_servers_dir = ~/.genesis/mcp-servers`.
- **Prereqs (flag):** **`uv` on PATH** (install-time; run-time uses the created venv), Python 3.13 (lcp) / 3.11+
  (devops). Install pulls a sizeable dep set for lcp (fastapi/uvicorn/playwright/etc.) → note disk/time; playwright
  browser download is **skipped** unless SSO/browser auth is explicitly enabled.

### 2.2 Installer / updater (`genesis/mcp/native/installer.py` — `NativeMcpInstaller`)
- `install(id, source) -> version` — obtain the bundle (per source, §2.4) → **verify sha256** → unpack into
  `versions/<version>/` → `uv sync` (in that dir) → assert the entry point exists (`.venv/bin/appian-deployment` or
  `python -m lcp_mcp_server` importable) → optional stdio smoke (`initialize`+`tools/list`) → record lockfile → set
  `current`. `version` from the bundle (`pyproject`/artifact name; lcp = site plugin version).
- **No network `update`** (2026-08-05 decision). New releases are a **manual drop-in**: the operator places a newer
  bundle and calls `install(id, bundle_path)` again — it versions the new bundle alongside, **atomic-switches** `current`
  (rename/symlink swap), and keeps the prior version for rollback. Genesis never fetches from a source; idempotent
  (installing the same version/sha is a no-op).
- `rollback(id)` — flip `current` back to the previous version (reversibility requirement).
- `active_launch_spec(id) -> {command,args,env}` — **launch via the venv, not `uv`** (so `uv` isn't needed at run time):
  - Dev: `command=<dir>/.venv/bin/python`, `args=["-m","lcp_mcp_server"]`.
  - DevOps: `command=<dir>/.venv/bin/appian-deployment`, `args=[]`.
  - `env` = the server's `${VAR}` set resolved from Secrets/Env (§2.5).
- `status(id)` — active version, installed versions, last install, health.
- **Never edits bundle files** — the bundle is opaque; Genesis glue is only the launch spec + env + lockfile.

### 2.3 Registration — a "managed native" MCP tier (ADR-029 reconciliation, ADR-038)
These servers are **third-party but locally installed at a dynamic path**, so they are neither the static curated image
tier nor the user-custom tier. Model them as a **managed-native tier**: a curated `mcp-registry.json` entry provides the
**identity + read-only `tool_allowlist`** (governance preserved), but its launch spec is a **managed reference**
(`"managed": "appian-dev"`) that `McpRegistry.acp_servers()` resolves at launch by calling
`NativeMcpInstaller.active_launch_spec(id)` (command/args from the active install; env `${VAR}` resolved as usual).
Updating the binary = a new install version + `current` swap; **no registry edit**, so it stays updatable.

### 2.4 Versioning & manual updates (no auto-fetch — 2026-08-05 decision)
- **No update source.** Genesis does **not** fetch bundles from anywhere (no connected-site `lcp-mcp-bundle` servlet, no
  configured DevOps mirror). When Appian ships a new Dev/DevOps MCP release, the **operator integrates it manually**:
  place the new bundle (under `artifacts/mcp-servers/` or any chosen path) and run `install(id, bundle_path)` (API/CLI).
- **Versioned + reversible.** `install` unpacks + `uv sync`s into a new `versions/<v>/`, records `{version, source_path,
  sha256, installed_at, entry}` in the lockfile, and atomic-switches `current`; the prior version is retained so
  `rollback(id)` restores it. "Updatable without forking" is preserved via this drop-in path; the bundle is never modified.
- **Bootstrap (first install)** seeds from the artifact under `artifacts/mcp-servers/` (or a configured path); the
  lockfile `source` is the local bundle path the operator supplied.

### 2.5 Secrets / env wiring (uses the existing registry, §umbrella 12)
- `appian-dev`: `LCP_URL` ← `EnvironmentRegistry.dev_environment()` url (§2.0); `LCP_USERNAME`/`LCP_PASSWORD` ←
  SecretProvider (scoped `appian-dev/…`); `LCP_AUTH_METHOD=basic` default; `LCP_API_PATH` default. (Browser/SSO vars only
  if an operator opts in — documented, not automated.)
- `appian-devops`: `APPIAN_DOMAIN` ← Env url; `APPIAN_API_KEY` ← SecretProvider (`appian-devops/APPIAN_API_KEY`). Its
  own keychain option is bypassed in favor of the Genesis SecretProvider for one source of truth.
- Secrets referenced by key name only; never echoed into events/logs.

### 2.6 Read-only allowlists (posture)
- After install, **introspect the server** (`tools/list`, via `mcp/introspect.py`) and set a **read/export-only
  `tool_allowlist`** in the curated entry: Dev MCP → read-object/list/eval/SQL/env-info tools only; DevOps MCP →
  export/inspect/status/download only. **Write/deploy tools excluded** (Section E out of scope). Effective agent trust =
  `node.tools ∩ allowlist` (ADR-029) — a hard cap independent of the bundle.

### 2.7 Genesis surface (Settings → Integrations)
- API (`genesis/api/…`, under `/api`): `GET /api/config/native-mcp` (per-server status: active version, installed
  versions, last install, health); `POST /api/config/native-mcp/{id}/install|rollback` (install takes the drop-in bundle
  path; **no `update`** endpoint).
- Web: a **"Appian MCP servers"** panel in Settings → Integrations — per server: installed version, **Install/replace**
  (from a drop-in bundle), **Rollback**, health/test. Reuses the ResourceManager/confirm patterns.
- Bootstrap: on first setup (or a CLI `genesis mcp install-native`), install both from the seeded artifacts.

## 3. Files & tests
- New: **`is_dev` on the environment model** (`genesis/config/environments.py`) + single-select invariant +
  `dev_environment()`/`set_dev_environment()` in `EnvironmentRegistry`/`ConfigService`, and the **Environments-section
  toggle + dev badge + "Test connection"** in `web/src/features/settings/EnvironmentsSection` (§2.0); `Settings.mcp_servers_dir`; `genesis/mcp/native/{__init__,installer,lockfile}.py` (`NativeMcpInstaller`);
  managed-reference resolution in `genesis-core McpRegistry.acp_servers` (+ genesis wiring); curated `appian-dev` /
  `appian-devops` entries (managed refs + read-only allowlists) resolving the `lcp` `<lcp-image>` placeholder;
  `api/native_mcp.py` + web panel; a CLI `genesis mcp install-native`.
- Tests: **dev-env tagging** — `set_dev_environment` clears any prior dev env (single-select invariant); `dev_environment()`
  returns the tagged one / `None`; the Dev/DevOps launch spec + REST export resolve URL from it; a no-dev-env sync/enumeration
  fails fast with the actionable error; web test for the toggle single-select + dev badge + "Test connection". installer unit tests (unpack + `uv sync` against a **fixture bundle**; version/sha recorded; `current` switch;
  rollback; idempotent re-install) — install from a local fixture bundle (no network); `active_launch_spec` shape; managed-reference resolution in the
  registry; allowlist introspection (stub `tools/list`); API tests (status/install/rollback via TestClient);
  web (Vitest+MSW) for the panel. `uv`-dependent steps guarded/skipped where `uv` absent in CI (document the manual
  live install).
- **Live acceptance (manual, recorded):** install both from the artifacts; a chat/`get_object_code` call reads live SAIL
  via `@appian-dev`; a sync export path reaches the env via the Deployment API; installing a newer drop-in bundle
  versions it + swaps `current`, and `rollback` restores the prior.

## 4. Acceptance criteria
1. **Dev-environment tagging works and is the single connectivity source (§2.0):** an `is_dev` toggle exists on the
   environment; **exactly one** env can be tagged dev (single-select enforced); `EnvironmentRegistry.dev_environment()`
   feeds the REST export + Dev/DevOps MCP + available-apps enumeration; with no dev env tagged those paths fail fast with
   an actionable message; a "Test connection" verifies the dev env + both MCPs.
2. Both native MCP servers **install into `~/.genesis/mcp-servers/<id>/versions/<v>/`** via `uv sync`, launch from the
   per-server venv, and are injectable as `@appian-dev/*` / `@appian-devops/*` with **read-only allowlists**.
3. **Updatable without forking (manual drop-in):** there is **no auto-fetch update source** — the operator installs a
   newer bundle via `install(id, bundle_path)` (API/CLI), which versions it + atomic-switches `current`; `rollback`
   restores the prior version; the bundle source is never modified.
4. Env/secrets resolved via the existing registry (Dev = Basic auth default, headless; browser/SSO documented as an
   opt-in manual step); secrets referenced by key name only.
5. Registration is a **managed reference** — updating the binary needs no registry edit.
6. Settings surface shows installed version + Install/replace (drop-in) + Rollback; genesis + web suites green
   (uv-dependent steps guarded); live acceptance recorded.

## 5. Out of scope
- **Modifying / forking** either bundle (breaks updatability).
- **Browser/SSO (playwright) auth** automation for the Dev MCP — documented manual opt-in for SSO-only sites; Basic auth
  is the supported headless default.
- **Write/deploy tools** in the allowlists (Section E — later, behind `pre_mutation`).
- Multi-environment fan-out — the registry may hold **many** environments, but Phase 16 authenticates only against the
  **dev-tagged** one (§2.0); the DevOps MCP's multi-env `APPIAN_<ENV>_*` vars collapse to that single env.
- Auto-update on a schedule (v1 = manual/among setup; a scheduled check can follow).
