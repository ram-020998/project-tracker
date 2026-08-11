# 19-02 — Managed-native `gws` CLI connector + standard OAuth

> **Status:** ✅ **CODE-COMPLETE + LIVE SMOKE TEST PASSED (2026-08-11) — UNCOMMITTED** (commit at 19-08 per the user). The
> installer → `CliRegistry` resolution → isolated `gws auth login` → read-only Drive read chain was verified end-to-end on a
> real machine (managed gws at `~/.genesis/cli-tools/gws/`, isolated file-keyring auth, read-only scopes). 32 new tests (genesis
> 343 / core 65 green). Remaining: the Settings→CLI connector **card** (19-07). See `progress/phase-19-document-library.md`.
> **Depends on:** 19-01 (spike — ✅ DONE + **live-verified** end-to-end on a real machine:
> client read from `~/.config/gws/client_secret.json`, standard OAuth login, read-only `gws drive files list` returning the
> `modifiedTime`/`version` fingerprint). **Repos:** genesis-core (CliRegistry managed resolution) + genesis (NativeCliInstaller,
> gws connector, api, Settings→CLI UI) + genesis-workflows (`gws` `cli-registry.json` entry).

## Goal
Install, version, and authenticate the **Google Workspace CLI (`gws`)** as a **managed-native CLI connector** inside Genesis —
the CLI analog of the managed-native Appian MCP servers (ADR-038) — configured from **Settings → CLI**, using `gws`'s
**standard OAuth** browser login. This is **ADR-040**.

## Client bootstrap — read from the dotfiles-provisioned `client_secret.json` (DECIDED 2026-08-11; NO shipped token)
Genesis does **not** ship or store the OAuth client. The **org `dotfiles` setup is a documented prerequisite** — running it
provisions the shared OAuth client (from Secret Manager in `peng-os`) to **`~/.config/gws/client_secret.json`** (a Desktop-app
client: `{"installed":{client_id, client_secret, redirect_uris:["http://localhost"], …}}`; **verified present + working on a
real machine 2026-08-11**). Genesis:
- **Reads the client** from `~/.config/gws/client_secret.json` (path overridable via setting/env; fallback `web` wrapper) →
  `client_id`/`client_secret`. Genesis does **not** run gcloud/Secret-Manager itself (dotfiles owns that); it does **not** ship
  a token.
- Injects them as `GOOGLE_WORKSPACE_CLI_CLIENT_ID`/`CLIENT_SECRET` for `gws` calls made under Genesis's own config dir. (Reading
  the values into memory for the child env is fine; if we ever cache them, use SecretProvider — but the source of truth is the
  dotfiles-owned file.)
- **Fails clearly** if the file is absent (`status: "client-missing"` → UI: "Complete the Google Workspace (dotfiles) setup
  first"), never a shipped default.

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
  `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file`, `GOOGLE_WORKSPACE_CLI_CLIENT_ID/SECRET` (read from
  `~/.config/gws/client_secret.json` — see the client-bootstrap section above).
- **OAuth flow** (per the spike outcome — live-verified): `begin_login()` spawns `gws auth login --readonly -s drive,docs,sheets,slides`,
  captures the sign-in URL **from stderr** (format: `Open this URL in your browser to authenticate:\n\n  https://accounts.google.com/o/oauth2/auth?…redirect_uri=http://localhost:<ephemeral>…`),
  returns it; the localhost callback completes on approval; `status()` reports connected via `gws auth status`
  (`auth_method`/`credential_source` ≠ `none`) + a cheap verify read; **reconnect** is signalled by any call's **exit 2**.
  Fallback = `auth export` handoff (not needed as primary — spike confirmed the subprocess flow works).
- **Secrets:** the OAuth **client** comes from the dotfiles-owned `~/.config/gws/client_secret.json` (never shipped, never
  echoed). The user's Google **tokens** stay in `gws`'s encrypted config dir — Genesis never stores/logs them.

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
