# Genesis — Phase 4 Implementation Record

> As-built record of Phase 4 (Configuration & Secrets). Companion to
> `specs/phase-04-configuration-and-secrets.md`.

**Date:** 2026-07-09 · **Milestone:** M4 (Config & secrets) · **Status:** ✅ COMPLETE — 26 platform + 15 core + 2 workflow tests green, ruff clean, pushed.

---

## 1. Summary

Genesis now owns its **configuration surface** (solutions-copilot is retired):
a local secret store, MCP-registry-derived config cards, a credential-free Appian
environment registry, artifacts retention policy, health checks (incl. the MCP
literal-env probe), and a `ConfigService` facade for the Phase-5 API. `${VAR}`
resolution for per-node MCP injection is now **server-scoped** and fails fast
before Kiro spawns.

---

## 2. What was built (`genesis/config/`)
```
secrets.py       # SecretProvider (Protocol) + PlaintextProvider: JSON @ ~/.genesis/secrets.json,
                 #   mode 0600, key grammar scope/VAR, resolve(server→global), collisions()
fields.py        # secret/public field derivation from mcp-registry.json + installed set;
                 #   McpCard (UI cards), secret_fields, missing_secrets; GLOBAL_KEYS={GITLAB_TOKEN}
environments.py  # EnvironmentRegistry: ~/.genesis/environments.json; CRUD; credential-free validator
                 #   (rejects /(token|key|secret|password|credential)/i; requires url+api_endpoint);
                 #   resolve(label); set_active/resolve_var hook for run-time MCP var mapping
retention.py     # disk_usage(); plan_prune(keep_last / max_age_days) over TERMINAL runs only; apply_prune
health.py        # check_gitlab_token / check_server_secrets / check_docker / check_clis /
                 #   mcp_literal_env_probe (stubbable) / run_all / all_ok
service.py       # ConfigService facade: gitlab token, installed_servers (lockfile∩registry required_mcp),
                 #   mcp_cards, set_secret (key-name only), missing_secrets, environments CRUD, health, is_ready
__init__.py      # public exports (21)
```
- **Settings** extended: `secrets_path`, `environments_path`, `retention_keep_last`
  (`GENESIS_RETENTION_KEEP_LAST`), `retention_max_age_days`
  (`GENESIS_RETENTION_MAX_AGE_DAYS`), `artifacts_writable()`.

## 3. genesis-core change (additive, MAJOR stays 1 — ADR-019)
`McpRegistry._resolve_var(name, server)` is now **server-scoped**:
SecretProvider `resolve(var, server)` (server/VAR → global/VAR) → EnvironmentRegistry
`resolve_var` (active-env connection values) → `os.environ`. `acp_servers` passes
the server name through. **Backward-compatible**: `secrets=None` still falls back to
`os.environ` (the Phase-1 `test_kiro_node_injects_per_node_mcp` still passes).
`build_context` now default-wires `PlaintextProvider` + `EnvironmentRegistry`.

---

## 4. Verification (evidence — every §6 acceptance criterion)

| Acceptance criterion | Result | Test |
|---|---|---|
| `secrets.json` written `0600`; values never in key listings | ✓ | `test_secret_crud_mode_and_resolution` (asserts `0o600`), `test_secret_values_never_in_keys` |
| Secret resolution server→global; collisions reported | ✓ | `test_secret_crud_mode_and_resolution`, `test_secret_collisions_and_invalid_key` |
| MCP cards derived automatically from `mcp-registry.json` for installed servers | ✓ | `test_mcp_cards_and_missing`, `test_config_service_end_to_end` |
| Env registry rejects secret-looking fields; requires url + api_endpoint | ✓ | `test_environment_registry` |
| `${VAR}` resolves from the store (server-scoped); **missing required secret fails fast before Kiro** | ✓ | `test_mcp_resolution_server_scoped` (raises `McpResolutionError`), `test_mcp_resolution_env_fallback_no_secrets` |
| Health checks incl. literal-env docker MCP probe (stubbable) | ✓ | `test_health_checks_offline` (probe skipped w/o fn; green with stubs) |
| Retention: keep-last-N / max-age over terminal runs; disk usage | ✓ | `test_retention_plan_and_usage` |
| Fresh-machine service flow zero→ready | ✓ | `test_config_service_end_to_end` (set token → missing empty → `is_ready`) |
| Full regression | **26 genesis + 15 core + 2 workflow** green; ruff clean; library validation passing | — |

The setup **wizard UI** (§4.7 step 8) is deferred to the Phase-5 FastAPI/UI work
per the spec's "minimal now, restyle in Phase 7" note; the **service layer it wraps
is complete and tested here** (`ConfigService`).

---

## 5. Decisions / notes
- **Server-scoped resolution** required threading the server name into
  `McpRegistry` — done additively (see §3); triggered the version-bump chain.
- **Environment→MCP-var** resolution needs the run's chosen env *label*, which only
  exists at run time. The hook (`EnvironmentRegistry.set_active` / `resolve_var`) is
  built and unit-tested; the engine will select the active label in **Phase 5**.
- **No global Kiro `mcp.json`** (ADR-020) — Genesis injects per ACP session, so it
  sidesteps solutions-copilot's BL-4 overwrite problem (called out as an advantage).

---

## 6. Repos & tags after Phase 4
| Repo | Tag | Change |
|---|---|---|
| `genesis-core` | **v0.3.0** | additive server-scoped `${VAR}` resolution |
| `genesis` | **v0.4.0** | +`genesis/config/`; Settings retention; build_context wiring; pin core v0.3.0 |
| `genesis-workflows` | **v0.1.2** | pins bumped (core v0.3.0 / genesis v0.4.0) |

---

## 7. Next: Phase 5 — Run Orchestration & HITL
Subprocess-worker execution (ADR-012), FastAPI run-control API, all three HITL
modes (gate/pause-resume/state-edit), and wiring `ConfigService` +
active-environment selection into runs. See `specs/phase-05-run-orchestration-and-hitl.md`.
