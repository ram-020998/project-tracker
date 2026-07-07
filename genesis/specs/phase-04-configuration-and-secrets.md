# Phase 4 — Configuration & Secrets

> **Goal:** Give Genesis its **own** configuration surface (solutions-copilot is
> retired): capture the GitLab token, MCP secrets, and the Appian environment
> registry, store secrets safely on the machine, and resolve `${VAR}` at run
> time for MCP injection. Reuse solutions-copilot's *concepts* (SecretProvider,
> credential-free env registry) as fresh implementations.

Prereq: `specs/00-architecture-overview.md`, Phase 2 (`mcp-registry.json`
classification), Phase 3 (GitLab client consumes the token).

---

## 1. Objective & success statement

A first-time user completes a setup flow that: stores a GitLab token; enters the
secrets each installed MCP server needs (derived from `mcp-registry.json`
`secretKeys`); registers Appian environments (label → url/api_endpoint, no
secrets); and passes health checks. Thereafter, MCP injection resolves all
`${VAR}` from the secret store + environment registry with no prompts.

---

## 2. Scope

**In scope:** SecretProvider (plaintext v1, keychain-ready interface); secret
field derivation from the MCP registry; environment registry (CRUD, credential-
free); GitLab token capture; `${VAR}` resolution service; health checks; the
**config API** + a **setup/settings UI** in the app.
**Out of scope:** run/HITL (Phase 5); the full workbench (Phase 7 — but the
settings UI here can be minimal/functional and later restyled).

---

## 3. Decisions applied

Q1 (local, user creds), Q3 (MCP registry drives secrets), Q11 (Genesis owns
config; reuse concepts), Q2/Q8 (secrets resolved at run time for per-node MCP
injection).

---

## 4. Detailed design

### 4.1 SecretProvider (`genesis/config/secrets.py`)
Interface (reused concept): `get/set/delete/has/keys`, vault key grammar
`scope/VAR` where scope ∈ {`global`, `<server-name>`}.
- **v1 `PlaintextProvider`** — JSON at `~/.genesis/secrets.json`, mode `0600`,
  shape `{version, values:{"scope/VAR": "…"}}`. Never logged/echoed.
- **Roadmap `KeychainProvider`** — macOS Keychain behind the same interface.
- `resolve(var, server) -> value`: server-scoped value first, then `global`
  fallback; report collisions.

### 4.2 Secret field derivation (`genesis/config/fields.py`)
From `mcp-registry.json` + the installed set (Phase 3):
- `secret_fields(installed) -> [{server, key, scope, label}]` using `secretKeys`
  (secret) vs `publicKeys` (public, may be prefilled defaults).
- `is_global(key)` (e.g., `GITLAB_TOKEN` shared across servers) vs server-scoped.
- Produces the "MCP cards" the UI renders (one card per server needing secrets).

### 4.3 Environment registry (`genesis/config/environments.py`)
- File `~/.genesis/environments.json`: `{version, environments:{ <label>: {url, api_endpoint, products, type, notes} }}`.
- **Credential-free (enforced):** validator rejects any field name matching
  `/(token|key|secret|password|credential)/i` (reused rule). Requires `url` + `api_endpoint`.
- `upsert/remove/list`; `resolve(label) -> env` used by workflows/`PlatformContext`.
- Optionally materialize an env summary the agent can read (label table), like
  solutions-copilot's environments steering — but as a `PlatformContext` value,
  not global steering.

### 4.4 `${VAR}` resolution for MCP injection (ties Phase 1 §4.7)
`McpRegistry.acp_servers(names)` (Phase 1) now backed by:
`resolve_var(var, server)` → SecretProvider (`server/VAR` then `global/VAR`) →
environment values → literal defaults from the registry (`publicKeys`). Unresolved
required var ⇒ raise before spawning Kiro.

### 4.5 GitLab token
Stored as `global/GITLAB_TOKEN` in SecretProvider; consumed by the Phase 3
GitLab client and by the `appian-atlas` MCP server (shared global secret).

### 4.6 Health checks (`genesis/config/health.py`)
- GitLab token valid (auth probe).
- For each installed server: required secrets present; docker/binary available.
- **MCP literal-env probe** (critical, from solutions-copilot doc 14): prove Kiro
  passes literal env values into a docker MCP (spawn a tiny ACP session with one
  server, confirm it initializes). Prevents silent MCP-auth failures at run time.
- Each Appian environment reachable (optional ping).

### 4.7 Config API + Settings UI
- API: `GET/POST /config/gitlab-token`, `GET /config/mcp-cards`,
  `POST /config/secrets`, `GET/POST/DELETE /config/environments`, `GET /config/health`.
- **Setup wizard** (functional, minimal styling now; restyle in Phase 7):
  Connect (GitLab) → (install workflows, Phase 3) → MCP secrets (cards) →
  Environments → Review → Verify (health). Mirrors solutions-copilot's 7-step
  wizard, retargeted.

---

## 5. Task breakdown

1. `config/secrets.py` — `SecretProvider` interface + `PlaintextProvider` (0600) + `scope/VAR` + collision report + tests.
2. `config/fields.py` — secret-field derivation from MCP registry + installed set + tests.
3. `config/environments.py` — registry CRUD + credential-free validator + resolve + tests.
4. Wire `${VAR}` resolution into `McpRegistry.acp_servers` (Phase 1) + tests (resolved + unresolved fail-fast).
5. GitLab token storage + consumption by Phase 3 client.
6. `config/health.py` — checks incl. the **MCP literal-env probe** via a real ACP session.
7. Config API endpoints.
8. Setup/settings UI (functional): connect, MCP cards, environments, review, verify.
9. End-to-end: fresh machine → wizard → install a workflow → resolve its MCP secrets → health green.

---

## 6. Acceptance criteria

- [ ] `secrets.json` written `0600`; secrets never appear in logs/responses (only key names).
- [ ] MCP cards are derived automatically from `mcp-registry.json` for the installed servers.
- [ ] Environment registry rejects secret-looking fields; requires url + api_endpoint.
- [ ] `${VAR}` for an installed MCP resolves from the store; a missing required secret fails fast with a clear message *before* Kiro spawns.
- [ ] Health checks pass, including the literal-env docker MCP probe (proves run-time MCP auth works).
- [ ] Setup wizard takes a fresh user from zero to a runnable state.

---

## 7. Risks

- **Plaintext secrets v1.** Documented tradeoff; `0600`; keychain on roadmap
  behind the same interface. Never commit; `~/.genesis` gitignored by nature.
- **Global mcp.json overwrite** (solutions-copilot BL-4): Genesis does NOT write
  a global Kiro `mcp.json` — it injects MCP per ACP session (Q2), sidestepping the
  merge-on-write problem entirely. (Call this out as a Genesis advantage.)
- **Secret/collision ambiguity** (server vs global scope): report collisions in UI.

---

## 8. Deliverables

- `genesis/config/` (secrets, fields, environments, health) + `${VAR}` resolution + config API + functional setup UI + tests.
- A fresh-machine setup path validated end-to-end.
