# Phase 24-01 — Environment-scoped credentials for the two core Appian MCPs

> **Status:** 📝 DRAFT (approved direction, 2026-08-18) · **Area:** genesis `config/` + `api/` + web Environments +
> genesis-workflows `mcp-registry.json` · **Type:** functionality + small UX. **Related ADR:** new ADR-048 (below).

## 1. Problem
Credentials for the two **core** Appian MCPs are configured in a different place from the environment they belong to:
- `appian-dev` creds (`LCP_USERNAME`, `LCP_PASSWORD`, `LCP_API_PATH`) and `appian-devops` (`APPIAN_API_KEY`) are entered
  **in each MCP's card** and stored **server-scoped** in the SecretProvider (`appian-dev/LCP_USERNAME`, …).
- The **environment** (URL, api_endpoint, dev tag) is configured on a separate **Environments** tab.
So the information for one logical target is split across two screens. Users want to enter everything **when creating the
environment**.

## 2. Goal
When adding/editing an environment, the user can (optionally) provide the core-MCP credentials on that **single** form.
Saved creds flow to the Dev/DevOps MCPs. This applies **only** to `appian-dev`/`appian-devops`; every other MCP keeps
configuring secrets in its own card, unchanged. Existing users' configuration must keep working (no re-entry).

## 3. Decisions (confirmed 2026-08-18)
1. **Per-environment credentials.** Each environment can carry its own creds; the **dev-tagged** env's creds feed the MCPs.
2. **`LCP_API_PATH` is a public env field** (stored in `environments.json` like `url`/`api_endpoint`), not a secret.
3. **`LCP_URL` / `APPIAN_DOMAIN`**: the servers need a base URL/domain, but it is **auto-derived from the env's `url`** —
   so we **hide these as fields** and keep the auto-derivation in `resolve_var`. Deeper removal only after verifying the
   installed `lcp-mcp-server` / `appian-deployment-mcp` bundles don't read them.
4. **Hide the cred fields on the two MCP cards**, replaced by a note pointing to Settings → Environments.
5. **Creds are sourced ONLY from the environment scope** for these two servers (no server-scope lookup at resolution).
   Back-compat via a one-time, non-destructive **migration** (§6), not via a resolution fallback.

## 4. Credential model
True secrets stay in the **SecretProvider** (0600, atomic) — never in `environments.json` (plaintext, surfaced in
`summary()`/logs). Introduce a **per-environment secret scope**: `env:<label>`.

| Value | Kind | Storage | Key |
|---|---|---|---|
| LCP Username | secret | SecretProvider | `env:<label>/LCP_USERNAME` |
| LCP Password | secret | SecretProvider | `env:<label>/LCP_PASSWORD` |
| Appian DevOps API Key | secret | SecretProvider | `env:<label>/APPIAN_API_KEY` |
| LCP API Path | public | `environments.json` | `lcp_api_path` field (optional; default `/suite/rest/a/lcp-api/latest`) |
| LCP URL / Appian Domain | derived | — | auto from the env's `url` (not a field) |

All optional — an environment can be saved with no creds.

## 5. Resolution (environment-only for the two core servers)
`McpRegistry._resolve_var` chain is unchanged for other servers. For `appian-dev`/`appian-devops`, resolution is:
```
env:<dev-label>/VAR   →   resolve_var (LCP_URL/APPIAN_DOMAIN ← dev.url; LCP_API_PATH ← dev.lcp_api_path|default)   →   os.environ
```
No `appian-dev/…` / global server-scope lookup for these two.

**Localization (keep genesis-core untouched):** genesis-core `McpRegistry` already accepts an injected `secrets`. In
`ConfigService`, pass a thin adapter for these two servers whose `resolve(name, server)` maps `server ∈
{appian-dev, appian-devops}` to the dev env's `env:<label>` scope (returns None if no dev env / unset). Other servers pass
through to the real SecretProvider unchanged. This confines the change to genesis.

## 6. Back-compat / migration (non-destructive)
On upgrade / first read: for the dev-tagged env, if `env:<label>/{LCP_USERNAME,LCP_PASSWORD,APPIAN_API_KEY}` are unset but
the legacy server-scoped `appian-dev/…` / `appian-devops/…` values exist, **copy them into `env:<label>`** (originals left
in place as a safety net but no longer consulted). Idempotent, one-time. Net: existing users re-enter nothing; creds are
sourced only from the env scope.

## 7. Affected code
- `genesis-workflows/mcp-registry.json` — drop `LCP_URL`/`APPIAN_DOMAIN` from `publicKeys`; keep env-map entries (auto-derived). **→ genesis-workflows release.**
- `genesis/config/environments.py` — add `lcp_api_path` to `_ALLOWED`; `resolve_var("LCP_API_PATH")` = `dev.lcp_api_path or default`. Creds NOT stored here.
- `genesis/config/service.py` — the per-server SecretProvider adapter (env-scope mapping) + migration + dev-connection preflight sources from `env:<label>`.
- `genesis/config/fields.py` — suppress `appian-dev`/`appian-devops` card fields.
- `genesis/api/*` (environments routes) — accept optional creds on upsert → write to `env:<label>` scope; **never echo secret values back** (return only `is_set` booleans).
- `web/features/settings/components/EnvironmentsSection.tsx` — optional cred fields + per-field "set" indicators; update the "secrets never here" copy; MCP detail note for the two servers.
- Tests: `test_config.py`, `test_api.py`, `test_dev_mcp_and_api_path.py`, `settings.test.tsx`; new tests — env-scope resolution, migration copy, no-cred save, secrets-not-echoed. **→ genesis release + `web/static` rebuild.**

## 8. Security notes
- Secrets stay in the SecretProvider (0600 + atomic write per the v0.20.1 lesson); `environments.json` stays credential-free
  except the non-secret `lcp_api_path`.
- The `env:<label>` scope uses the existing `scope/KEY` key format; labels may contain spaces (fine) — reject `/` in a label.
- API responses expose only `is_set` booleans for cred fields, never values.

## 9. Out of scope
Per-env creds for non-core MCPs (they keep their own cards); write/deploy scopes (unchanged); the nav/IA revamp (24-02).
