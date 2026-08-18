# Progress — Phase 24-01: environment-scoped credentials (as-built)

**Shipped:** genesis **v0.48.5** (`0d8c3c9`) + genesis-workflows **v0.9.5** (`ebcce93`), CI green (genesis + frontend +
clean-install; workflows validate). **ADR-048 Accepted.**

## What shipped
The two core Appian MCPs (`appian-dev`/`appian-devops`) take their credentials from the **environment**, not their MCP cards.

- **Storage (`genesis/config/environments.py`):** creds live in the SecretProvider under a grammar-safe per-env scope
  `env-<sha1(label)[:16]>` (`env_scope()`), because the key grammar forbids `:`/spaces. `CORE_CRED_VARS =
  (LCP_USERNAME, LCP_PASSWORD, APPIAN_API_KEY)`. New helpers: `set_credentials`, `credential_status`, `clear_credentials`
  (called on `remove`). `environments.json` stays credential-free; `lcp_api_path` added to `_ALLOWED` (public field) + the
  `Environment` dataclass.
- **Resolution (single seam):** `EnvironmentRegistry.__init__(secrets=…)`; `resolve_var` returns the dev env's creds for the
  three vars (`self._secrets.get(f"{env_scope(devlabel)}/{var}")`), `LCP_API_PATH` from `dev.lcp_api_path` or the default, and
  `LCP_URL`/`APPIAN_DOMAIN` from `dev.url` (auto-derived). Secrets are injected into the registry at **all** construction sites
  — `config/service.py` (merged registry → cards/chat/dev-mcp), `runs/worker.py`, `runtime/context.py` — so every McpRegistry
  caller resolves uniformly (McpRegistry step-1 server-scope finds nothing for these vars after migration → step-2 resolve_var).
- **Migration (`ConfigService._migrate_legacy_core_secrets`, run once in `__init__`):** relocates legacy `appian-dev/…` /
  `appian-devops/APPIAN_API_KEY` into the dev env scope (copy + delete original, so edits take effect) and a legacy
  `appian-dev/LCP_API_PATH` secret into the dev env's public `lcp_api_path`. Idempotent; no-op without a dev env. **Existing
  users re-enter nothing.**
- **Cards suppressed (`genesis/config/fields.py`):** `ENV_MANAGED_SERVERS = {appian-dev, appian-devops}` skipped in `mcp_cards`
  (→ also excluded from `secret_fields`/`missing_secrets`/health). `dev_connection_check` now sources cred presence from the
  dev env scope (`credential_status`).
- **API (`genesis/api/app.py`):** `EnvBody` gains `lcp_api_path` + optional `lcp_username`/`lcp_password`/`appian_api_key`
  (None = unchanged); `upsert_environment` routes creds to the env scope; GET/POST responses include a `credentials` map of
  **is_set booleans only** — secret values are never echoed.
- **Registry (`genesis-workflows/mcp-registry.json`, v0.9.5):** `secretKeys`/`publicKeys` emptied for the two servers (env maps
  unchanged, still injected + resolved).
- **Web:** `EnvironmentsSection` env dialog gains optional LCP API path / LCP username / LCP password / Appian DevOps API key
  fields (password-masked, "Set — leave blank to keep" hints from the `credentials` status; creds sent only when entered);
  header copy updated; `McpDetail` shows a pointer note for the two servers. Types: `EnvironmentFields.lcp_api_path` +
  `credentials`; `EnvironmentInput` write-cred fields.

## Key decision (from the user)
Creds are sourced **only** from the environment (no server-scope fallback at resolution) — hence the migration *moves* (not
copies) the legacy keys. Per-env creds keyed by a hash of the label (grammar-safe).

## Tests
- Backend **482** (+**8** new in `tests/test_env_credentials.py`: env-scope resolution, lcp_api_path public+default, dev-only
  resolution, credential_status + remove-clears, empty-string-clears, mcp-cards exclusion, migration relocate+delete,
  ConfigService upsert + dev-check). ruff clean.
- Web **162** (+1 in `settings.test.tsx`: the env form submits creds + lcp_api_path). typecheck + lint + build clean.
- genesis-workflows `validate_library` green.

## Upgrade note for a running install
`genesis update` (or `git pull` + `pip install .`) picks up the code; `genesis install` refreshes the v0.9.5 library
registry; restart `genesis serve`. The migration runs automatically on first ConfigService init — existing creds relocate to
the dev env, nothing to re-enter.

## Not in 24-01
The nav/IA revamp is **24-02** (frontend, next). ADR-049 stays Proposed until 24-02 ships.
