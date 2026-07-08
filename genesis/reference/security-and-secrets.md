# Genesis — Security & Secrets

Genesis runs locally with the user's own credentials and executes workflow code
pulled from an internal GitLab library. This doc defines the trust model, secret
handling, and safety posture.

---

## 1. Trust model

| Element | Trust basis | Control |
|---|---|---|
| Workflow code (Python, from `genesis-workflows`) | Internal, reviewed via MR, CI-validated, version-pinned | Run in a **subprocess worker** (ADR-012) — crash/hang/leak/exit isolation + kill switch + resource limits; genesis-core **major-compat gate** (ADR-019); pinned refs; app only parses `workflow.yaml` (never imports workflow Python) |
| MCP servers (docker/npx from internal registry) | Internal images | Launched per-node with only the secrets they need |
| CLIs (e.g. `erd-gen`) | Known binaries; install hints from trusted sources | `cli-registry.json`; version/config checks |
| User creds | The user's own GitLab/Appian creds | Local only; never leave the machine except to the intended service |

**Isolation posture (ADR-012):** workflow Python runs in a **subprocess worker**,
giving crash/hang/leak/exit isolation, a kill switch, and resource limits — the
app and UI cannot be taken down by a bad workflow. This is *defense-in-depth*, not
a security sandbox against malice: workflows are internal, MR-reviewed, CI-validated,
and pinned, and they legitimately need filesystem/CLI/MCP access. Stronger
isolation (per-workflow venv, seccomp/containers) is the escape hatch if the
library ever accepts external contributions or divergent `genesis-core` majors.

---

## 2. Secret handling

- **Store:** `SecretProvider` (ADR-013). v1 `PlaintextProvider` → `~/.genesis/secrets.json`, mode **`0600`**, shape `{version, values:{"scope/VAR": "…"}}`. Roadmap: `KeychainProvider` (macOS Keychain) behind the same interface.
- **Vault key grammar:** `scope/VAR` where scope ∈ {`global`, `<server-name>`}. Resolution: `server/VAR` first, then `global/VAR` fallback; collisions reported.
- **Classification:** `mcp-registry.json` `secretKeys`/`publicKeys` decide what the config UI treats as a secret (masked, never displayed) vs a public/default value.
- **Never:** commit secrets; put secrets in state, in the environment registry, in logs, or echo secret *values* in API responses (only key *names*).
- **Resolution timing:** `${VAR}` resolved at run time when building an ACP session's MCP config; a missing required secret **fails fast with a clear message before Kiro spawns** (Phase 4).

---

## 3. Environment registry (credential-free)

- `~/.genesis/environments.json`: label → `{url, api_endpoint, products, type, notes}`. **No secrets.**
- Validator **rejects** any field whose name matches `/(token|key|secret|password|credential)/i` (reused solutions-copilot rule).
- Workflows target an env by **label**; the actual creds for that env come from the SecretProvider, not the registry.

---

## 4. Genesis-specific safety advantages

- **No global Kiro mutation (ADR-020):** Genesis never writes a global `mcp.json`
  or installs global agents — MCP is injected per ACP session. This sidesteps
  solutions-copilot's BL-4 (global `mcp.json` overwrite wiping user servers).
- **Least-privilege per node (ADR-004):** an agent node gets only the MCP
  server(s) it needs — a read-only doc node never carries write/deploy tools.
- **Reads auto-run, mutations gated:** write/deploy/data MCP usage (`jarvis`,
  `lcp`, `appian-data-generator`) is only allowed in nodes preceded by a HITL
  approval gate (reliability-standard.md / hitl-design.md). Never touch prod
  without explicit approval.

---

## 5. Data handling

- **Bulk artifacts** (schemas, generated code, docs) live in the per-run
  blackboard under the dedicated, user-configurable **artifacts root** (default
  `~/Genesis/runs/`, `GENESIS_ARTIFACTS_DIR`) on the user's machine; not
  transmitted anywhere except to the intended MCP/CLI. Runs are inspectable,
  locally purgeable, and subject to a configurable retention policy (terminal
  runs only).
- **State** is small and local (SQLite); contains no secrets.
- **Logs:** structured; redact secret values; safe to share for debugging (verify no PII/secrets before sharing externally).

---

## 6. Threats & mitigations (summary)

| Threat | Mitigation |
|---|---|
| Malicious/broken workflow code | MR review + CI validation + pinned refs; **subprocess-worker isolation** (crash/hang/leak/exit fails only the run, not the app) |
| Secret leakage | `0600` store, key-name-only in UI/logs, no secrets in state/registry/git |
| Accidental prod mutation | HITL approval gates before writes/deploys; least-privilege MCP per node; env chosen by explicit label |
| Global config clobber | No global Kiro mutation (per-session MCP injection) |
| Supply-chain (typosquat CLI/image) | Registry-declared binaries/images from internal sources; version checks |
| Credential misuse | User's own creds, local only; no central execution/service |

---

## 7. Open security items
- **Keychain provider** (replace plaintext) — roadmap.
- **Signed/pinned library tags** — prefer tag pinning; consider signature verification later.
- **`KIRO_API_KEY` for ACP** (OD-2) — only relevant if a non-interactive/CI run mode is added; keep out of scope for local M6.
