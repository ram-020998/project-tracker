# Phase 45 — Incremental Delta Sync — progress (as-built)

> Spec: `specs/phase-45-incremental-delta-sync.md` (+ `45-01..45-10`). ADR-073/074 **Proposed**.
> Build started 2026-10-13 on the user's go-ahead. All code commits are **local only** (no push/tag until the 45-10
> release go-ahead).

## Ledger

| Sub-phase | Status | Commits (local) | Review |
|---|---|---|---|
| 45-01 findings | ✅ done (2026-10-12) | docs only | — |
| 45-02 Dev MCP 26.6.110 | ✅ built + host bundle installed; live plugin check blocked (DNS) | genesis `22c0988` · genesis-workflows `4e6f1ef` | SHIP |
| 45-03 parser | ⏳ next | | |
| 45-04 … 45-10 | pending | | |

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

**Not yet verified (blocked):** the live plugin comparison. `merge-assist-dev.appianpreview.com` does not resolve
from this machine right now (DNS `Errno 8`; same symptom as run `r-d58d41ce124c`), so `getDevMcpVersionInfo` reports
the plugin as unreachable (`match = null`). The server half is confirmed (`e8417471…`, which equals the plugin sha
recorded on 2026-10-12). Re-check once the network is back: Settings → MCP → appian-dev shows "Matches…", and
`listObjects` works from both fleet instances (after `gsm restart --all` picks up the working tree).
