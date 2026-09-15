# Spec — Dev MCP 26.6.90 upgrade + SAIL CLI installation

> **Status:** 📝 DRAFT — awaiting user review (no build until approved). · **Created:** 2026-09-15
> · **Candidate phase:** Phase 41 (number to confirm). · **Repos:** genesis + genesis-workflows
> (genesis-core / kiro-agent-sdk / genesis-appian-parser **unchanged**).
> **ADRs touched:** ADR-038 (managed-native MCP), ADR-040 (managed-native CLI), ADR-048 (env-scoped
> Appian creds), ADR-036/037 (read-only Dev MCP / code-free KB). **Deferred:** browser-based SSO auth →
> `specs/backlog/devmcp-browser-sso-auth.md`.

## 1. Goal
Adopt the new **Appian Dev MCP `26.6.90`** bundle in Genesis using **HTTP basic auth only**, and — from
the **same uploaded bundle**, in a **single install action** — install the bundled **SAIL CLI** as a
fully-wired managed-native CLI that any future program/agent can invoke. **No** browser/SSO auth, **no**
Playwright/Chromium, **no** repo-vendored binaries, **no** pre-install on fresh Genesis installs.

## 2. Why (the two breakages the new bundle introduces)
Verified against the bundle source (`src/lcp_mcp_server/config.py`, `server.py`):
1. **Auth default flipped to `browser`.** With our current `appian-dev` env (injects `USERNAME`/`PASSWORD`,
   no `LCP_AUTH_METHOD`), the new server (a) never builds `httpx.BasicAuth` → 401, and (b) its
   `ConfigValidationMiddleware` errors when a password is set without `LCP_AUTH_METHOD`. → every
   `@appian-dev` call breaks (chat + the 4 analysis workflows' grounding, KB live-code fetch,
   `listApplications`). **Fix:** inject a static `LCP_AUTH_METHOD=basic`.
2. **`LCP_API_PATH` obsolete + our default is stale.** New bundle defaults the plugin base to
   `/suite/plugins/servlet/stateless/lcp-api`; our `resolve_var` default is the old
   `/suite/rest/a/lcp-api/latest`, injected unconditionally → wrong endpoint. **Fix:** stop injecting
   `LCP_API_PATH` (rely on the bundle default).

Everything else is safe: all **67** allowlisted tools still exist (0 renamed/removed → read-only posture
intact; the 90 write tools are simply not in the allowlist); launch entry `-m lcp_mcp_server` unchanged;
`truststore` auto-trusts corporate CAs (free win); the **DevOps MCP** (`appian-devops`) is a *separate*
bundle, **not** in this zip → untouched, and `sync-application`'s Deployment-REST export is unaffected.

## 3. Scope

### 3.1 genesis-workflows — `mcp-registry.json` `appian-dev` env (the essential fix)
Change the `appian-dev` `env` block to:
```jsonc
"env": {
  "LCP_URL": "${LCP_URL}",
  "LCP_AUTH_METHOD": "basic",          // static literal — not user-configurable (browser auth is backlog)
  "LCP_USERNAME": "${LCP_USERNAME}",
  "LCP_PASSWORD": "${LCP_PASSWORD}",
  "USERNAME": "${LCP_USERNAME}",
  "PASSWORD": "${LCP_PASSWORD}"
}
```
- **Remove** the `"LCP_API_PATH": "${LCP_API_PATH}"` line (bundle default is now correct).
- Allowlist: **keep as-is** (all 67 valid). *Optional follow-up (not this change):* add the new read
  tools `getPortal`, `listPortals`, `listObjectVersions`, `listMyTasks`, `getDevMcpVersionInfo`.
- Update the entry `note` to record basic-auth default + the dropped `LCP_API_PATH`.
- Bump `genesis-workflows` version + re-pin nothing (registry-only; no dep change).

### 3.2 genesis — drop the dead `LCP_API_PATH` wiring (cleanup)
- `genesis/config/environments.py`: remove the `LCP_API_PATH` branch from `resolve_var` and drop
  `lcp_api_path` from `_ALLOWED` + the `Environment` dataclass; keep a one-line back-compat tolerance so
  an existing `environments.json` carrying `lcp_api_path` still loads (filter it out on `resolve`, don't
  reject on `upsert`).
- `web`: remove the `lcp_api_path` field from the Settings → Environments form + its type.
- No `LCP_AUTH_METHOD` config surface (deferred to backlog — it ships as the static registry literal).

### 3.3 genesis — install the Dev MCP bundle + the SAIL CLI in ONE action
The existing install entry point is path-based: `POST /config/native-mcp/appian-dev/install {bundle_path}`
→ `NativeMcpInstaller.install("appian-dev", bundle_path)` (web `NativeMcpSection`). We extend the
**appian-dev** install so the *same* action also installs the SAIL CLI from the *same* tarball.

**New orchestration (ConfigService):** `install_appian_dev_bundle(bundle_path) -> {mcp: {...}, sail: {...}}`
1. `NativeMcpInstaller.install("appian-dev", bundle_path)` (unchanged — `uv sync`, verify `-m lcp_mcp_server`).
2. **Extract the host-platform SAIL binary** from the same tar.gz and install it via `NativeCliInstaller`:
   - Map host → bundle binary: `Darwin/arm64→bin/sail-darwin-arm64`, `Linux/x86_64→bin/sail-linux-amd64`,
     `Windows/AMD64→bin/sail-windows-amd64.exe`. **No match (e.g. linux-arm64, mac-x86_64) → skip SAIL
     with a clear warning; the Dev MCP still installs.**
   - Extract to a temp file, then `NativeCliInstaller.install("sail", tmp_binary, version=<bundle_version>)`.
3. Return both statuses; the web install handler refetches native-mcp **and** native-cli status.

**`NativeMcpInstaller` change:** none required for the MCP itself (root `pyproject.toml`, module unchanged).
Note: the bundle `pyproject.toml [project].version` is a generic `0.1.0`; the real version lives in
`BUILD-INFO.txt`. The orchestrator reads `BUILD-INFO.txt` (e.g. `build_timestamp`) to derive a meaningful
version label to pass to the SAIL installer and to annotate the MCP install (cosmetic).

**`NativeCliInstaller` changes (`genesis/cli_tools/native/installer.py`):**
- Add `"sail"` to `_TOOLS` with a version strategy. SAIL is a Go/Cobra binary; its self-reported version
  may not be semver, so:
  - accept an **optional explicit `version`** arg on `install(cli_id, binary_path, *, version=None)`
    (used for SAIL, derived from `BUILD-INFO.txt`), falling back to `sail version`/`--version` parsing.
- **macOS Gatekeeper:** after copying the binary, on Darwin clear the quarantine attribute
  (`xattr -d com.apple.quarantine`, tolerate absence) in addition to the existing `chmod +x` — otherwise a
  freshly-extracted unsigned binary is killed on first run (observed: `Killed: 9`). Mirrors the bundle's
  `bin/setup-mac.sh`.
- `status()` already enumerates all `_TOOLS` → SAIL appears in `GET /config/native-cli` automatically.

### 3.4 genesis — SAIL as a fully-callable managed CLI (the "consumer plumbing")
So any program node / agent path can invoke SAIL with zero further config:
- **`cli-registry.json` (genesis-workflows)** — add a `sail` entry (managed):
  ```jsonc
  "sail": {
    "managed": "sail",
    "version_check": ["sail", "version"],
    "install_hint": "Install the Appian Dev MCP bundle (Settings → MCP); the SAIL CLI installs with it.",
    "allowlist": ["login","logout","load","pages","show","navigate","interact","back","open","whoami","version"],
    "note": "Appian SAIL interface driver (ships in the Dev MCP bundle). Basic auth via SAIL_USERNAME/SAIL_PASSWORD from the dev-tagged env; isolated SAIL_HOME. Used to drive/verify built SAIL interfaces."
  }
  ```
  `CliRegistry` already resolves `"managed"` entries via the `NativeCliInstaller` launch provider — no
  genesis-core change.
- **`genesis/integrations/sail/`** (mirrors `integrations/gws/`) — a `SailClient` + `build_sail_client(settings, *, environments, secrets)` factory:
  - resolves the binary via the managed CliRegistry launch provider;
  - runs subcommands with an **isolated `SAIL_HOME`** (`settings.sail_home_dir` = `~/.genesis/cli-tools/sail/home`)
    and `SAIL_USERNAME`/`SAIL_PASSWORD` resolved from the **dev-tagged env** (the same per-env
    `LCP_USERNAME`/`LCP_PASSWORD` via `EnvironmentRegistry.resolve_var`/SecretProvider — ADR-048 seam);
  - `host` for `sail login <host>` = the dev env URL (host only);
  - enforces the allowlist before spawn; parses `--json` output; classifies exit codes; never logs creds.
- **`runtime/settings.py`** — add `sail_home_dir`.
- **`runtime/context.py`** — inject `ctx.extras['sail'] = build_sail_client(...)` (like `document_sync`) so a
  future workflow program node gets a ready SAIL client. **No workflow consumer is added now** — only the
  capability.
- **`ConfigService`** — expose `sail()` (client) + surface SAIL under `native_cli` status for the UI.

### 3.5 genesis — web (Settings)
- The Dev MCP install button (MCP tab) triggers the **combined** install and, on success, invalidates both
  `native-mcp` and `native-cli` queries.
- **SAIL shows in the CLI tab, not the MCP tab** — the CLI section renders `native_cli.status()["sail"]`
  (version, installed, binary path, rollback), alongside `gws`. Add a `sail` card to the CLI section
  component (it currently renders the `gws` connector card).

## 4. Auth model (basic only)
- **Dev MCP:** `LCP_URL` (dev env url) + `LCP_AUTH_METHOD=basic` (static) + `USERNAME`/`PASSWORD`
  (= dev env `LCP_USERNAME`/`LCP_PASSWORD`, ADR-048 per-env secret scope). Read-only enforced by our
  allowlist (unchanged). Site prereq: the DevMCP plug-in must be installed on the Appian site (admin).
- **SAIL CLI:** `SAIL_USERNAME`/`SAIL_PASSWORD` = the same dev env creds; isolated `SAIL_HOME`; basic login
  to the dev env host. No `--from-devmcp`, no browser.

## 5. Non-goals (explicit)
Browser/SSO auth (→ backlog); Playwright/Chromium; a `LCP_AUTH_METHOD` UI toggle; shipping/pre-installing
SAIL with Genesis; vendoring binaries in-repo; a SAIL workflow/skill consumer; DevOps-MCP changes;
adopting the new write tools (read-only posture stands).

## 6. Security / ADR notes
- Read-only Dev MCP posture preserved (ADR-036/037): allowlist is the enforcement; `LCP_TOOL_MODE=readonly`
  is documented by Appian but **not implemented** in 26.6.90 — revisit if a later bundle adds it.
- SAIL runs under the dev user's own creds, drives SAIL interfaces (read/navigate/interact) — it *can*
  submit forms/record actions by design. Since we add **no consumer** now, this is latent; when wired,
  the consuming workflow node must treat form submission as a mutation (ADR-021 `pre_mutation` posture)
  — flag in the future consumer's spec.
- Creds: SAIL_USERNAME/PASSWORD sourced via the ADR-048 SecretProvider seam; never logged; referenced by
  key name. Isolated `SAIL_HOME` (never the user's `~/.sail`).
- ADR updates: amend **ADR-038** (the appian-dev bundle now also carries the SAIL CLI; basic-auth default;
  `LCP_API_PATH` dropped) and **ADR-040** (SAIL is a second managed-native CLI, installed from the Dev MCP
  bundle rather than a standalone drop-in). Mirror in `reference/decision-log.md`.

## 7. Testing
- **genesis pytest:** combined-install orchestration (MCP + SAIL from one tarball; host-platform pick;
  unsupported-arch → MCP-only + warning; `BUILD-INFO` version parse); `NativeCliInstaller` sail entry
  (install/version-override/rollback/status; macOS quarantine clear mocked); `SailClient` (env resolution
  from a fake dev env + SecretProvider, allowlist enforcement, `--json` parse, cred redaction) — all
  offline with a fake `sail` binary (no live Appian). Registry guard test: `appian-dev` env has
  `LCP_AUTH_METHOD=basic` and no `LCP_API_PATH`.
- **genesis-workflows:** `validate_library` stays green with the edited registry.
- **web vitest:** the combined install refetches both statuses; SAIL renders in the CLI tab; jest-axe.
- **Manual (can't be headless):** on the user's Mac, install the real `26.6.90` bundle → verify Dev MCP
  authenticates (basic) via `listApplications` + a KB code fetch, and `sail version` runs post-install.

## 8. Release / rollout (precedence)
1. genesis-workflows: registry edit → bump + tag + push (the essential auth fix; must be installed for the
   upgraded bundle to authenticate).
2. genesis: config cleanup + installer/orchestration + `SailClient` + ctx/settings + web → bump + tag +
   push; CI green (incl. stale-bundle guard).
3. Operator: install the `26.6.90` bundle via Settings → MCP (installs Dev MCP + SAIL); reinstall the
   workflows library (`genesis install`); `gsm provision --all --force` for the fleet (re-links the new
   Dev MCP; SAIL install per-instance is optional until a consumer exists).
4. Docs: ADR-038/040 amendments + decision-log mirror; bible (§1 tags/tests, §3 map, §4 ADRs, §5 loop if
   needed) + tracker §6 + a `progress/` note.

## 9. Open items for review
- **Phase number** (41?) + whether this is tracked as a phase or a named change.
- **Allowlist:** add the 5 new read tools now, or leave for a follow-up? (Spec currently: leave.)
- **`lcp_api_path` field removal** vs keep-but-ignore (spec: remove end-to-end with back-compat load tolerance).
- **SAIL version label** source: `BUILD-INFO.txt` timestamp/commit vs the bundle folder name (`26.6.90`).
  (Spec: BUILD-INFO; confirm preference.)
