# Phase 41 — Dev MCP 26.6.90 upgrade + SAIL CLI install (as-built)

> **✅ SHIPPED 2026-09-15 — genesis v0.72.0 (`e75acaa`) + genesis-workflows v0.19.0 (`4a49b04`).**
> Spec: `specs/phase-41-devmcp-upgrade-and-sail-cli.md`. Deferred: `specs/backlog/devmcp-browser-sso-auth.md`.
> genesis-core / kiro-agent-sdk / genesis-appian-parser unchanged.

## What shipped
Adopt the Appian **Dev MCP `26.6.90`** bundle with **basic auth only** (browser/SSO auth deferred to the
backlog), and install the **SAIL CLI** bundled in the same tarball as a fully-wired managed CLI — in a
**single install action**, no consumer wired yet.

### The two breakage fixes (Dev MCP 26.6.90)
- **Auth default flipped to browser** → the `appian-dev` registry env now pins a static
  **`LCP_AUTH_METHOD=basic`** (else the new server never builds `httpx.BasicAuth` and its config-validation
  middleware errors when a password is set without the method).
- **`LCP_API_PATH` obsolete** (bundle defaults `/suite/plugins/servlet/stateless/lcp-api`) → **removed
  end-to-end**: the registry no longer injects it; `EnvironmentRegistry` dropped the field from `_ALLOWED`
  + the `Environment` dataclass + the `resolve_var` default; `EnvBody`/`config_routes` + the web env form
  no longer send it. Back-compat: an existing `environments.json` carrying `lcp_api_path` still loads
  (filtered out on read). The legacy `_migrate_legacy_core_secrets` LCP_API_PATH branch was removed.
- Allowlist: **+5 read tools** — `getPortal`, `listPortals`, `listObjectVersions`, `listMyTasks`,
  `getDevMcpVersionInfo` (72 tools total). All 67 prior tools still exist in 26.6.90 (0 renamed/removed →
  read-only posture intact; the 90 write tools remain excluded). `truststore` (auto-trust corp CAs) is a
  free win in the new bundle. `LCP_TOOL_MODE=readonly` is documented but **not implemented** in 26.6.90 —
  our allowlist remains the read-only enforcement.

### SAIL CLI — install from the same bundle, one action
- **`ConfigService.install_appian_dev_bundle(bundle_path)`**: installs the Dev MCP (`NativeMcpInstaller`,
  `uv sync`, required) then extracts the **host-platform** SAIL binary from the same tarball and installs
  it via `NativeCliInstaller` (best-effort — unsupported arch → Dev MCP still installs, SAIL skipped with
  a reason). Wired into `POST /config/native-mcp/appian-dev/install` (the response carries a `sail` block).
- **`cli_tools/native/sail_bundle.py`**: `host_binary_name()` (darwin-arm64 / linux-amd64 / windows-amd64),
  `extract_sail_binary()` (bin/<name>, path-safe), `read_bundle_version()` (BUILD-INFO `build_timestamp`).
- **`NativeCliInstaller`**: `+ "sail"` in `_TOOLS`; `install(..., version=…)` override (SAIL is versioned by
  the bundle's BUILD-INFO, not a semver it prints); **macOS quarantine clear** (`xattr -d
  com.apple.quarantine`) after copy — an extracted unsigned Go binary is SIGKILL'd on first run otherwise.
- **`genesis/integrations/sail/`** (`SailClient` + `build_sail_client`): resolves the managed binary; injects
  an isolated **`SAIL_HOME`** (`~/.genesis/cli-tools/sail/home`, never the user's `~/.sail`) + basic
  **`SAIL_USERNAME`/`SAIL_PASSWORD`** from the **dev-tagged env** (the ADR-048 seam — the same
  `LCP_USERNAME`/`LCP_PASSWORD`); subcommand allowlist; `--json`; `version()` uses the `--version` flag;
  creds resolved at call time, never logged.
- **`ctx.extras['sail']`** (runtime/context.py) so a future workflow program node can drive SAIL with zero
  further config. **`cli-registry.json`** gains the managed `sail` entry (`version_check ["sail","--version"]`,
  allowlist, install hint). **No workflow/chat consumer yet** — capability only.
- **Web:** SAIL surfaces in the **Settings → CLI tab** (`SailConnectorCard` reading `GET /config/native-cli`,
  beside the gws card); the appian-dev install refetches native-cli + shows a SAIL toast.

## Verification
- **genesis pytest 803** (13 new in `tests/test_sail_cli.py` — bundle extraction, managed-CLI install w/
  version override, combined-install orchestration + unsupported-arch skip, SailClient env/allowlist/
  not-installed/no-dev-host, LCP_API_PATH removed end-to-end; updated `test_env_credentials` +
  `test_dev_mcp_and_api_path`) · ruff clean.
- **web vitest 271** + tsc/eslint clean + build (committed static); settings tests cover the env-form
  field removal + the native-cli handler.
- **genesis-workflows** validate_library 12 + pytest 184.
- **CI green:** genesis-workflows #6813196 (v0.19.0); genesis (v0.72.0) — genesis + frontend + clean-install.
- **Real end-to-end** (this Mac): extracted SAIL from the actual `26.6.90` bundle, installed via
  `NativeCliInstaller` (label `20260903-195919` from BUILD-INFO), and ran the installed managed binary →
  `sail version 26.6.90` (rc 0) — proving the quarantine-clear makes the unsigned binary runnable.

## Rollout (operator)
Install the `26.6.90` bundle via **Settings → Integrations → MCP** (point at
`.../appian-dev-mcp-server-bundle.tar.gz`) — installs the Dev MCP (basic auth) **and** the SAIL CLI in one
action; reinstall the workflows library (`genesis install`); `gsm provision --all --force` for the fleet.

## Deferred / follow-ups
- Browser-based SSO auth (`specs/backlog/devmcp-browser-sso-auth.md`).
- A SAIL consumer (a testing lane/skill/workflow that drives built SAIL to verify) — capability is ready.
- Optionally adopt more 26.6.90 read tools (impact analysis breadth, diagnostics) as needs arise.
