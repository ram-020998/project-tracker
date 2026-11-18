# Phase 52 — ADR drafts

> **Status:** **DRAFTED** 2026-11-18 by the genesis-spec agent from `52-01-findings.md` §14. **Proposed**, not yet in
> `reference/decision-log.md`. 52-03 reviews these against the then-current code; numbers are fixed at write-back
> (52-16, with `genesis-ctx add adr`). Placeholders: **ADR-A**, **ADR-B**, **ADR-C**.

## ADR-A — Genesis Agent Runtime: every agent turn runs in a policy-built sandbox

- **Areas:** security, runs-worker, sdk-acp, core-engine, chat, config-secrets.
- **Amends:** ADR-012 (workers run in the app container; agent turns run in sandboxes), ADR-029 (the cap is also
  enforced server-side at the MCP gateway), ADR-031 (chat runs in its own sandbox), ADR-051 (a sandboxed
  `AgentProvider`), ADR-083 (risks a–c close), ADR-086 (`--auth-method client`; a clean sandbox environment; the per-run
  `KIRO_HOME` inside the sandbox mount).
- **Rule (one-liner draft):** Run every agent turn and chat session in a disposable sandbox the Sandbox Controller
  builds from an immutable AgentSecurityPolicy: only the run folder mounted, no secrets or engine access, egress only
  via the proxy, MCP only via the gateway relay.
- **Decision.** (1) Three layers: EnvironmentProvider (the Genesis-owned VM), SandboxRuntime (Docker `runc` first;
  gVisor or microVM later, per policy), AgentProvider (Kiro first) (D21). (2) One sandbox per agent turn, one per chat
  session (D6). (3) The Sandbox Controller, in its own container, is the only component with engine access; agents
  never reach it (D24). (4) Program code compiles one immutable, hashed `AgentSecurityPolicy` per turn (profiles
  `workflow-agent`, `chat`, `test-execution`, `recording`); the controller is its only enforcer; nothing in agent
  instructions enforces policy (D25). (5) Hardening: non-root, no capabilities, `no-new-privileges`, default seccomp,
  read-only root, no host mounts but the run subfolder, limits (D5). (6) Network: internal sandbox network, VM firewall
  allowing only the proxy and gateway ports, no IPv6/UDP/ICMP, no usable DNS, a host-name allow-list proxy that refuses
  IP literals and private results and pins the address it checked, every decision audited (D10, D23). (7) MCP: servers
  and credentials in the app container behind a gateway; a stdio relay in the sandbox with a turn-scoped token;
  allowlist enforced at the gateway and in the engine (D7, D18). (8) Kiro: `--auth-method client`; Genesis owns the
  sign-in and refresh; the broker answers only for live turns (D8, D19, D26). (9) Built-ins auto-approved inside the
  sandbox; chat stays read-only and fail-closed (D9). (10) Host isolation and network-security corpora are release
  gates; a fail-closed self-test runs at every start (D22).
- **Limits (stated in the ADR):** the umbrella §6 list (shared kernel, engine root in the VM, WSL2 shared kernel, Kiro
  access token scope, QA saved-login cookie, allowed hosts as upload paths, script-internal commands unlogged).
- **Alternatives rejected:** fail-closed nodes without a shell; Kiro's Seatbelt sandbox (always allows loopback);
  MCP-only tool access; Docker-in-Docker; a mounted Docker socket in the app container; gVisor/microVM now (D5).
- **Evidence:** findings §3–§5, §18, §19; the 52-02 spike.

## ADR-B — Genesis ships as signed images in a Genesis-owned VM

- **Areas:** distribution, release-ci, config-secrets.
- **Amends:** ADR-046 (clone + venv + git-tag self-update), ADR-080 (one version = the tag = the image tag; the
  launcher has its own version), ADR-022 (the artifacts root is a VM volume).
- **Rule (one-liner draft):** Ship Genesis as CI-built, digest-pinned, signed images run in a Genesis-owned VM by the
  uv-installed launcher; keep data in VM volumes with encrypted, verified backups; update = backup, pull, recreate.
- **Decision.** (1) Environment providers: Colima on macOS and Linux, a WSL2 distribution on Windows, each Genesis-owned
  and configured without host-home or `C:\` mounts (D2, D4). (2) Images `app`, `sandbox`, `controller`, `egress` per
  tag, `arm64` + `amd64`, from the genesis project's registry; pinned bases and tools; SBOM; vulnerability-scan gate;
  signatures verified before start (D12, D29). (3) `genesis-launcher` (Python, `uv tool install`) installs prerequisites
  with consent and drives the stack (D13). (4) Data in volumes; encrypted backups with the key in the OS keychain plus a
  recovery key; consistent snapshots; restore validation; retention; weekly restore-verify; automatic pre-update
  backup (D11, D31). (5) Development: a `genesis-dev` VM built from the working tree (D16).
- **Alternatives rejected:** local image builds on users' machines; Docker Desktop/OrbStack (licences); Apple
  `container` (a VM per container on the host breaks the controller model); a Go launcher; host-folder data.

## ADR-C — The local API requires a per-launch token

- **Areas:** api, security, web-shell.
- **Amends:** ADR-026 (still single-user, no login screen), ADR-028 (the client adds the token centrally), ADR-085
  (the report origin is token- and Origin-checked too).
- **Rule (one-liner draft):** Refuse every /api request and report-origin request without the per-launch token, and
  check Origin and Host on both; the SPA adds the token centrally; the CLI and test drivers get it from the launcher.
- **Decision.** Token generated per launch inside the VM; delivered to the browser in the URL fragment by the launcher;
  kept by the SPA for the session; exceptions: the health check and static SPA files; the copilot control header moves
  onto the same mechanism (D14).
- **Alternatives rejected:** relying on sandbox network isolation alone (any host program or web page could still
  call the API: classic local CSRF).
