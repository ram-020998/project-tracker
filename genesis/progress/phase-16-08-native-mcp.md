# Phase 16-08 — Native MCP integration & connectivity foundation — PROGRESS

> **Spec:** `specs/phase-16-appian-knowledge-base/16-08-native-mcp-integration.md`
> **Status:** §2.0 (dev-environment toggle) ✅ **SHIPPED** (genesis v0.30.0); Stage B (managed-native MCP installer) ✅
> **SHIPPED** (genesis-core v0.9.1 + genesis v0.31.1 + genesis-workflows v0.8.4). Phase 16-08 **COMPLETE**.

## ✅ Shipped — §2.0 Dev-environment toggle (genesis v0.30.0, CI green #6502611)

The "build FIRST" connectivity foundation. The Environments registry may hold many envs; exactly **one** is tagged
**dev**, and that env's URL + credentials feed **all** Phase-16 auth (REST export, Dev/DevOps MCP, changed-objects).

- **Model** (`genesis/config/environments.py`): `Environment.is_dev: bool` (additive, back-compatible — records without
  it resolve to `False`). `is_dev` added to `_ALLOWED`.
- **Single-select invariant:** `EnvironmentRegistry.upsert(..., is_dev=True)` clears `is_dev` on every other env in one
  write; `set_dev_environment(label | None)` does the clear-others+set atomically. Never two dev envs.
- **Resolvers:** `dev_environment() -> Environment | None`, `dev_environment_label() -> str | None` — the single source
  every Phase-16 caller uses (fail fast with an actionable message when none is tagged).
- **ConfigService:** `set_dev_environment` / `dev_environment_label` passthroughs + `dev_connection_check()` — a readiness
  report `{ok, dev_env, url, secrets:{server:{VAR:present}}, missing[]}` (checks the dev env is tagged + the native-MCP
  secret keys are present, by key name — values never read/echoed).
- **API** (`genesis/api/app.py`): `is_dev` on `POST /config/environments`; `POST /config/environments/{label}/dev`
  (single-select tag/untag); `GET /config/environments/dev/check` (readiness).
- **Web** (`web/src/features/settings/components/EnvironmentsSection.tsx` + `hooks.ts` + `lib/api/config.ts` +
  `types/config.ts`): add/edit **dev toggle** (single-select `Switch`), a **dev** badge on the list, a per-row **Set as
  dev**, and a **Test connection** action that surfaces the readiness result inline.
- **Tests:** `test_config.py::test_dev_environment_single_select`, `test_api.py::test_api_dev_environment_toggle`, a
  `settings.test.tsx` case (badge + set-as-dev + test-connection). **242 python + 120 web passed; ruff/eslint/tsc clean;
  CI green** (#6502611 — `genesis` + `frontend` jobs; the stale-bundle guard passed on the rebuilt `web/static`).

## Scope decision (2026-08-05) — NO auto-update source for the native MCPs

The user will integrate a new Dev/DevOps MCP release **manually**. So Stage B **drops** the auto-fetch update sources
that the spec/ADR originally described (Dev = connected-site `lcp-mcp-bundle` servlet; DevOps = configured mirror). The
installer becomes **install-from-local-bundle + versioning + rollback only** — no network fetch. When Appian ships a new
version, the operator drops the new bundle in (under `artifacts/mcp-servers/` or a chosen path) and installs it; Genesis
records the new version + sha, keeps the prior for **rollback**, and swaps the `current` pointer. "Updatable without
forking" still holds via the manual drop-in; the bundle is never modified. (Spec §2.4, ADR-038 item 4, and the umbrella
updated to match.)

## ✅ Stage B — SHIPPED (managed-native MCP installer)

**Release chain:** genesis-core **v0.9.1** → genesis **v0.31.1** → genesis-workflows **v0.8.4** — all latest-tag
pipelines green (see the CI note at the end for the one caveat). Built strictly to the no-auto-update-source decision:
**install-from-local-bundle + versioning + rollback only**.

**Grounding (real bundle layouts, confirmed by inspection):**
- Dev `lcp-mcp-server-bundle.tar.gz` → **root layout** (`pyproject.toml` + `lib/` + `sdk/` + `src/` at top);
  `requires-python >= 3.13`; editable path deps via `[tool.uv.sources]`; launch `python -m lcp_mcp_server`.
- DevOps `appian-deployment-mcp-1.0.0.gz` → **wrapped** in `appian-deployment-mcp/` (`pyproject.toml` + `uv.lock` +
  `src/`); `requires-python >= 3.11`; `[project.scripts] appian-deployment = appian_deployment_mcp.server:main`.
- ⇒ the installer finds the **project root** = the extract dir if it has `pyproject.toml`, else its single wrapping child.

**genesis-core v0.9.1** (`genesis_core/mcp/registry.py`, `mcp/introspect.py`):
- `McpRegistry` gains a `launch_provider` kwarg (threaded through `load`/`from_dict`/`from_layers`). In `acp_servers`, an
  entry marked `"managed": "<id>"` resolves its **command/args** from `launch_provider(id)`; **env (`${VAR}` list) stays
  on the entry** and resolves as usual (secret resolution stays in one place). `is_managed(name)` accessor added. A
  managed entry with no provider / not-installed fails fast with an actionable `McpResolutionError`. Additive —
  **`CORE_MAJOR` unchanged (=1)**.
- **Introspect stream-limit fix:** `list_tools` now spawns with an 8 MiB `StreamReader` limit — the Dev MCP returns a
  single **very large `tools/list` line** (145 tools) that blew past asyncio's default 64 KiB limit
  (`ValueError: Separator is not found, and chunk exceed the limit`). This also unblocks the Settings "Test connection".
- CI went red first on **44 pre-existing UP037 findings** from an unpinned `ruff>=0.6` (the Phase-16-02 lesson, never
  applied to genesis-core) → pinned `ruff==0.15.20`; v0.9.1 is the green tag.

**genesis v0.31.1:**
- `Settings.mcp_servers_dir = ~/.genesis/mcp-servers`.
- **`genesis/mcp/native/{__init__,lockfile,installer}.py`:**
  - `NativeMcpLockfile` — own JSON store at `mcp-servers/lockfile.json` (NOT `genesis.db`); atomic temp+`os.replace`
    under a per-path lock (the hard-won secrets pattern); records per id `{active_version, versions:[{version, source,
    sha256, installed_at, entry, python}]}`.
  - `NativeMcpInstaller` — `install(id, bundle_path, *, run_uv=True) -> version`: sha256 → **idempotent** if the sha is
    already installed → safe tar extract (`filter="data"`) → find project root → move into `versions/<version>/` →
    `uv sync` (guarded on `shutil.which("uv")`) → verify entry (DevOps: `.venv/bin/appian-deployment` exists; Dev:
    `.venv/bin/python` + `find_spec('lcp_mcp_server')`) → lockfile row → set `current`. Version = pyproject
    `[project].version`; a same-version-but-different-sha drop-in disambiguates to `<version>+<sha[:8]>`. `rollback(id)`
    flips `current` to the prior installed version. `active_launch_spec(id) -> {command,args,env:[]}` launches from the
    **per-server venv, never `uv`** (Dev: `python -m lcp_mcp_server`; DevOps: `.venv/bin/appian-deployment`).
    `launch_spec_for(id)` (returns `None` if not installed) is the provider handed to `McpRegistry`. `status`/`statuses`.
    **No network `update`.**
- **Wiring:** `ConfigService` builds `self.native = NativeMcpInstaller(settings)` and injects `native.launch_spec_for`
  into `merged_mcp_registry()`; `worker._load_registries` injects it too (so a workflow agent node injecting
  `@appian-dev`/`@appian-devops` launches the local venv build). `introspect_mcp_server` resolves a managed server's
  launch via the installer. `environments.resolve_var` now maps **`LCP_URL`/`APPIAN_DOMAIN` from the dev-tagged env**
  (§2.5) in addition to the active-env `APPIAN_*` mapping. `dev_connection_check` gained a `native:{server:{installed,
  active_version,healthy}}` block (+ "not installed" in `missing`).
- **API** `genesis/api/native_mcp.py`: `GET /api/config/native-mcp` (per-server status) + `POST
  /api/config/native-mcp/{id}/install|rollback` (**no `update`**). Registered in `create_app`; FastAPI version `0.31.1`.
- **CLI:** `genesis mcp install-native <id> --bundle <path>` | `genesis mcp status` | `genesis mcp rollback-native <id>`.
- **Web:** `web/src/features/settings/components/mcp/NativeMcpPanel.tsx` — an "Appian MCP servers (managed-native)"
  panel at the top of Settings → MCP: per server the active version + health badge, a bundle-path **Install / replace**,
  and **Rollback** (disabled with < 2 versions). New `useNativeMcp`/`useInstallNativeMcp`/`useRollbackNativeMcp` hooks,
  `configApi.nativeMcp/installNativeMcp/rollbackNativeMcp`, `NativeMcpStatus`/`NativeMcpReadiness` types, and
  `qk.config.nativeMcp`.

**genesis-workflows v0.8.4** (`mcp-registry.json`): `appian-dev` + `appian-devops` are now **managed refs** (`"managed":
"<id>"`, docker `<managed-native:…>` placeholder dropped) with correct per-bundle env — `appian-dev`: `LCP_URL` (dev
env) + `LCP_AUTH_METHOD=basic` + `LCP_API_PATH` + `LCP_USERNAME`/`LCP_PASSWORD` (secrets); `appian-devops`:
`APPIAN_DOMAIN` (dev env) + `APPIAN_API_KEY`. **Read-only allowlists set from the REAL installed `tools/list`** (I
installed both bundles into a throwaway state dir and introspected them): **Dev = 67** of 145 tools (all `get*`/`list*` +
`test*`/`validate*`/`run*TestCase*`; every `create/update/delete/add/remove/insert/reorder/replace/upload` **excluded**);
**DevOps = 13** of 26 (export/inspect/status/download; `deploy_package`/`export_and_deploy`/pipeline-mutation excluded).

**Design decision (spec §2.2/§2.3 reconciliation):** `active_launch_spec` returns the **binary location only**
(`command`/`args`); the `${VAR}` env template stays on the registry entry and is resolved by `McpRegistry` (SecretProvider
→ EnvironmentRegistry → os.environ) — the installer never touches secrets (defense in depth + DRY).

**Tests (all green locally):** genesis **266** pytest (+24 native: `tests/test_native_mcp.py` — pure helpers + lockfile +
version disambiguation + rollback + `active_launch_spec` shape + idempotency; **3 uv-guarded integration tests run a real
`uv sync` install** of tiny fixture bundles for both ids and **pass locally**, skip where `uv` is absent; + a native-MCP
API test in `test_api.py`); genesis-core **61** (+4 managed-native resolution tests); web **121** Vitest (+1 panel
install/rollback test); ruff/eslint/tsc clean.

**Live acceptance (manual, done):** installed **both** real bundles via the installer and introspected them — DevOps
listed 26 tools, Dev listed 145 — confirming `uv sync` + venv launch + `active_launch_spec` + `tools/list` work
end-to-end against the actual bundles. (A live *tool call* against a real Appian env still needs dev creds + network and
is out of headless scope.)

**CI status:** genesis-core v0.9.1 ✅, genesis v0.31.1 (`genesis` job) ✅, genesis-workflows v0.8.4 (all 3 jobs) ✅.
**Caveat — the `frontend` stale-bundle guard was not exercised in CI for this release:** the `frontend` job runs only on
`changes: [web/**/*]`; the web changes landed in **v0.31.0**, whose `frontend` job died on a **transient Gitaly HTTP-500
at the git-fetch step** (before any script ran), and the follow-up **v0.31.1** touched no `web/**` so `frontend` was
skipped. `glab` can't retry it (token is read-only for the API). The `web/static` bundle **was** rebuilt (`npm run
build`) and committed and is locally verified (lint+tsc+121 tests+build all green), but a fresh-node:20-build guard has
not run server-side. **To close:** push a small `web/**`-touching commit (rebuild + commit static) as v0.31.2 to
re-trigger the `frontend` job.
