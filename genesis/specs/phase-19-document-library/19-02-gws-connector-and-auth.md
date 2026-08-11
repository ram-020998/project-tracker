# 19-02 — Managed-native `gws` CLI connector + standard OAuth

> **Status:** DRAFT — spec only. **Depends on:** 19-01 (spike). **Repos:** genesis-core (CliRegistry managed resolution) +
> genesis (NativeCliInstaller, gws connector, api, Settings→CLI UI) + genesis-workflows (`gws` `cli-registry.json` entry).

## Goal
Install, version, and authenticate the **Google Workspace CLI (`gws`)** as a **managed-native CLI connector** inside Genesis —
the CLI analog of the managed-native Appian MCP servers (ADR-038) — configured from **Settings → CLI**, using `gws`'s
**standard OAuth** browser login. This is **ADR-040**.

## A. genesis-core — `CliRegistry` managed-native resolution (additive; `CORE_MAJOR` stays 1)
Mirror the 16-08 `McpRegistry` managed-reference change for CLIs:
- A `cli-registry.json` entry may carry `{"managed": "<id>"}` instead of relying on PATH. `CliRegistry.ensure()`/`run()`
  resolve the binary via an injected **`launch_provider`** (a callable `id → resolved binary path`), falling back to the
  existing `shutil.which` behavior for unmanaged CLIs.
- Env `${VAR}` on the entry continue to resolve via the existing chain (SecretProvider → EnvironmentRegistry → os.environ).
  The installer never touches secrets. Additive only — unmanaged/curated/custom CLIs are unchanged.

## B. genesis — `NativeCliInstaller` (`genesis/cli_tools/native/` or `genesis/mcp/native/` sibling)
A lighter cousin of `NativeMcpInstaller` — **`gws` is a single static binary, so no `uv`/venv**:
- `install(id, bundle_path)`: place the binary under `~/.genesis/cli-tools/<id>/versions/<version>/`, `chmod +x`, **sha256** +
  lockfile (`NativeCliLockfile` — own atomic JSON store, like `NativeMcpLockfile`), atomic-switch `current`; keep prior for
  **rollback**. Version = `gws --version`. **No auto-fetch** (manual drop-in, per ADR-038's rule).
- `active_launch_spec(id)`: returns the binary path from the `current` version (the value `CliRegistry.launch_provider` uses).
- `rollback(id)`, `status(id)`.

## C. genesis — the `gws` connector + auth (`genesis/integrations/gws/`)
- **One access seam** `gws_client.py`: the only module that shells out to `gws` (via `CliRegistry.run`). Enforces the
  **read-only allowlist** (only `drive`/`docs`/`sheets`/`slides` read + export subcommands; reject anything else) and parses
  `gws`'s structured JSON + exit codes (0 ok / 2 auth → "reconnect" / others → error).
- **Config env** injected on every call: `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.genesis/cli-tools/gws/config`,
  `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file`, `GOOGLE_WORKSPACE_CLI_CLIENT_ID/SECRET` (from SecretProvider).
- **OAuth flow** (per the spike outcome): `begin_login()` spawns `gws auth login -s drive.readonly,documents.readonly,
  spreadsheets.readonly,presentations.readonly`, returns the captured sign-in URL; the localhost callback completes on approval;
  `status()` reports connected/disconnected (cheap verify read); `logout()`/reconnect. Fallback = `auth export` handoff if the
  spike showed a TTY requirement.
- **Secrets:** only the shared **client id/secret** live in Genesis's SecretProvider (atomic writes, referenced by key name,
  never echoed). The user's Google tokens stay in `gws`'s encrypted config dir — Genesis never stores/logs them.

## D. genesis — API (`api/native_cli.py` or extend the native-MCP surface)
- `GET /api/config/native-cli` (status: installed version, connected?), `POST /api/config/native-cli/{id}/install|rollback`.
- `GET /api/config/gws/auth` (status), `POST /api/config/gws/auth/login` (returns the sign-in URL), `POST …/logout`.
- All under `/api` (ADR-028).

## E. genesis-workflows — registry entry
- `cli-registry.json` gains a `gws` entry as a **managed reference** (`{"managed":"gws", …, "install_hint": …}`) with the
  read-only allowlist documented, resolved at runtime from the install (never a PATH assumption).

## F. genesis — Settings → CLI UI (web; more in 19-07)
- A **Google Workspace** connector card: install/version/rollback (managed-native), **Connect / Reconnect** (opens the sign-in
  URL), connection status, configured read-only scopes.

## CLI
- `genesis cli install-native <id> <bundle>` / `status` / `rollback-native` (parallel to `genesis mcp …`).

## Tests / gates
- Unit: installer (install→version→sha→current→rollback; atomic lockfile), `CliRegistry` managed resolution + fallback,
  `gws_client` allowlist rejection + JSON/exit-code parsing (stub `gws` mirroring real shapes — the "stub hid the contract"
  lesson). API tests for status/install/auth-URL. Web: jest-axe on the connector card.
- Security: read-only scopes only; secrets by key name; no token logging.

## Exit criteria
`gws` installs as a managed-native CLI, the Settings→CLI connector completes the standard OAuth login, `gws_client` can list
Drive files + export a Doc read-only, and reconnect works after an induced auth error. **ADR-040 → Accepted** on ship.
