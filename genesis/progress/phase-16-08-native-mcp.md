# Phase 16-08 — Native MCP integration & connectivity foundation — PROGRESS

> **Spec:** `specs/phase-16-appian-knowledge-base/16-08-native-mcp-integration.md`
> **Status:** §2.0 (dev-environment toggle) ✅ **SHIPPED**; Stage B (managed-native MCP installer) ⏳ **NOT STARTED**.

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

## ⏳ Stage B — remaining (managed-native MCP installer)

See `AGENT_ONBOARDING.md` §9 "▶ NEXT — 16-08 Stage B" for the concrete, ordered start steps. In brief:
1. `Settings.mcp_servers_dir = ~/.genesis/mcp-servers`.
2. `genesis/mcp/native/{__init__,lockfile,installer}.py` — `NativeMcpInstaller`: `install(id, bundle_path) -> version`
   (unpack → `uv sync` → verify entry → sha + lockfile → set `current`), `rollback(id)`, `active_launch_spec(id)`
   (launch from the per-server venv, NOT `uv`), `status(id)`. `uv`-guarded; **no `update`-from-network**.
3. genesis-core `McpRegistry.acp_servers` — resolve a **managed reference** (`"managed": "appian-dev"`) via an injected
   `active_launch_spec` provider; release genesis-core; repoint the genesis pin.
4. Curated `appian-dev` (read-only) + `appian-devops` (export-only) **managed-ref** entries with introspected allowlists,
   replacing the `<managed-native:…>` placeholders in `mcp-registry.json`.
5. `genesis/api/native_mcp.py` (status/install/rollback) + a Settings→Integrations panel + a `genesis mcp install-native`
   CLI; tests (fixture bundle, mocked/guarded `uv`).
6. Release chain genesis-core → genesis → genesis-workflows; live acceptance (manual) recorded here.

**Prereq:** `uv` on PATH at install time. Dev-MCP **Basic auth** is the headless default (browser/SSO = documented
opt-in). Bundles are at `project-tracker/genesis/artifacts/mcp-servers/`.
