# Phase 52 — Genesis Agent Runtime: isolated agent execution and a containerized Genesis

> **Status:** **SPEC-DRAFTED** 2026-11-18 by the genesis-spec agent. **Build deferred (D33):** starts only after the
> application's core functionality is finished, including Phase 53's open live acceptance (53-11 §5) and Phase 51's
> postponed live acceptance (51-12 steps 1–27). Before the build starts, re-base the spec set on the then-current code
> (`52-01-findings.md` §19 and the "keeping the spec set current" rule).
> Sub-specs: `phase-52-agent-runtime-isolation/52-01..52-20`. Findings (problem, run-history evidence, reference repos,
> industry research, every decision D1–D33, the v0.82.0 baseline): `52-01-findings.md`; KiroCrew re-read:
> `phase-52-agent-runtime-isolation/.research/`. ADR drafts: `phase-52-agent-runtime-isolation/adr-drafts.md`.
> Repos: **genesis** (images, the agent runtime, the launcher package, API, web, CI), **genesis-workflows** (`egress`
> declarations, a library gate), **playwright-appian** (none expected; saved-login options already exist),
> **genesis-fleet** (two stacks in the dev VM), **project-tracker** (areas, ADRs).
> Baseline when drafted: genesis v0.82.0, genesis-workflows v0.26.0, playwright-appian v0.3.1, DB v29, kiro-cli 2.37.1.

## 1. Why this phase exists

Every Genesis workflow agent has a full shell on the user's machine as the user. ADR-083 records the open risks and
ADR-086 item 7 leaves them "until Phase 52": (a) the shell and built-in read tools reach `~/.genesis/secrets.json`,
`genesis.db`, `~/.ssh`, the user's repos and the unauthenticated local API on `127.0.0.1:8760`; (b) the shell inherits
the worker's whole environment; (c) test-user passwords sit in the `apwt open --login` and Playwright replay
subprocess environments. Agents read untrusted content (KB data, documents, web pages, live QA page text), and the
network is open: the "lethal trifecta" in full. The run history shows 153 shell commands by workflow agents, including
an environment dump, `curl --resolve` to the Dev host, `sudo -n true` and a writability check on `/etc/hosts`
(findings §4). Genesis is an agentic SDLC platform, so agents keep the shell (findings §1, the user's direction); the
fix is a boundary they cannot cross. The user also wants Genesis itself in a clean, reproducible environment instead
of prerequisites installed on the machine, on macOS, Linux and Windows.

## 2. Goal

1. **Genesis runs entirely in containers** inside a Genesis-owned Linux VM, set up by a small launcher (D1–D4, D13).
2. **Every agent turn and chat session runs in its own disposable, hardened sandbox** that holds only its run folder,
   no secrets, no Docker access and no route to the host (D5, D6, D22).
3. **Network egress is default-deny**, enforced at the network layer, with a host-name allow-list proxy and an audit
   of every decision (D10, D23).
4. **Credentials never enter a sandbox:** MCP tools through a gateway and an in-sandbox relay, Kiro tokens from a
   broker answering from Genesis's own Kiro sign-in, all turn-scoped and audited (D7, D8, D18, D19, D26).
5. **One trusted owner and one policy:** a Sandbox Controller is the only component with engine access and enforces an
   immutable per-turn `AgentSecurityPolicy` (D24, D25).
6. **A generic Genesis Agent Runtime** in three layers (EnvironmentProvider → SandboxRuntime → AgentProvider), Kiro
   first, Docker `runc` first, gVisor or microVMs adoptable later without application changes (D21).
7. **The API requires a per-launch token** with Origin and Host checks (D14).
8. **Phase 51 testing in the boxed world:** sign-in on the trusted side, saved logins only, a restricted
   `test-execution` profile, recording through noVNC (D15, D27).
9. **Data in VM volumes** with encrypted, verified backups and a one-time import of today's data (D11, D31, D32).
10. **A supply chain the user can trust:** CI-built, digest-pinned, scanned, signed images with SBOMs (D12, D29).
11. **Existing workflows run unchanged** in graph, prompt and output; only what isolation forbids by design stops
    working (findings §8.4), and declared hosts keep working (D10).

## 3. Decisions (locked with the user — detail and reasons in `52-01-findings.md` §14)

| # | Decision |
|---|---|
| D1 | Everything in containers: an app container (Genesis, workers, DB, secrets, MCP servers, prerequisites) in a Genesis-owned VM; agent sandboxes as sibling containers, never Docker-in-Docker, never a Docker socket. |
| D2 | macOS: a Genesis-owned Colima profile, pinned, `vz`, no home mount, host-loopback blocked; Docker API only. |
| D3 | macOS, Linux and Windows supported; everything inside the VM identical; `arm64` + `amd64` images. Amends ADR-046. |
| D4 | Linux: a Genesis-owned Colima VM (QEMU/KVM). Windows: a Genesis-owned WSL2 distribution with `C:\` automount and interop off. |
| D5 | Sandboxes are hardened `runc` containers for now (non-root, no capabilities, `no-new-privileges`, default seccomp, read-only root, limits); shared-kernel risk accepted; runtime is a policy field. |
| D6 | One sandbox per agent turn, one per chat session; VM size, per-sandbox limits, a concurrency cap, reserved app memory, log caps, startup sweep. |
| D7 | All MCP servers behind a gateway in the app container that holds credentials, enforces `node.tools ∩ allowlist`, logs every call. Transport amended by D18. |
| D8 | Kiro auth through a token broker; sandboxes run Kiro with `--auth-method client`; no refresh token or `KIRO_API_KEY` inside. Source amended by D19. |
| D9 | Built-in tools auto-approved inside the sandbox (as ADR-086 ships); node trust lists govern MCP tools; chat stays read-only and fail-closed. |
| D10 | Egress default-deny by host name, three layers: Kiro endpoints, `META.egress` per workflow/node, user additions; Dev host, registries and code hosts not allowed by default. Amended by D23. |
| D11 | Data in Docker volumes; backup/restore, artifact export, one-time import; each sandbox mounts only its run subfolder at the same absolute path. |
| D12 | Images built by CI per tag (`app`, `sandbox`, …) in the genesis project's registry; update = pull + recreate; automatic pre-update backup. Amends ADR-046. |
| D13 | The host launcher is a Python package installed with `uv` (`genesis-launcher`); it installs prerequisites with consent and drives the stack. |
| D14 | Per-launch API token, Origin and Host checks, for the app and the report origin (ADR-085). Amends ADR-026. |
| D15 | Phase 51 browsers: sign-in in the app container, saved-login files only; agent sessions, test execution and recording in sandboxes; recording via Xvfb + noVNC. Test execution amended by D27. |
| D16 | Development: a `genesis-dev` VM running the same stack from the working tree; unit tests on the host venv; the fleet as two stacks in the dev VM; role agents stay on the host. |
| D17 | One phase, two releases: macOS first (Release 1), then Linux and Windows (Release 2). |
| D18 | MCP reaches sandboxes through a stdio relay inside the sandbox (V3 refuses plain HTTP MCP to non-loopback hosts); mount check; engine-side filter kept as a second layer. |
| D19 | Genesis owns the Kiro sign-in and refresh; the broker answers `_kiro/auth/getAccessToken` from it, with KiroCrew's rules. |
| D20 | Out of scope (backlog): a git credential proxy; mediated secret use. |
| D21 | The subsystem is the generic **Genesis Agent Runtime** in three layers; a "Threat model and limits" section states the shared-kernel limits. |
| D22 | Host isolation is a hard acceptance criterion: bypass and positive corpora as release gates per OS; a fail-closed self-test at every start. |
| D23 | Egress enforced at the network layer: internal network, VM firewall, no IPv6/UDP/ICMP, no usable DNS, IP-literal and private-address refusal, no rebinding, gateway not a proxy, audit. |
| D24 | A Sandbox Controller in its own container is the only component with engine access; agents never reach it. |
| D25 | An immutable, hashed `AgentSecurityPolicy` per turn, compiled by program code, enforced only by the controller; profiles `workflow-agent`, `chat`, `test-execution`, `recording`. |
| D26 | Credentials turn-scoped, revocable, audited; a Kiro access token is bounded only by its life and turn-bound issuance. |
| D27 | `test-execution` profile: no Kiro, no broker, no MCP; QA host only. |
| D28 | Per-turn sandbox telemetry (lifecycle, image digest, policy hash, resources, commands, MCP, network, credentials, termination reason). |
| D29 | Digest-pinned, checksummed, scanned, signed images with SBOMs; pull and start by verified digest. |
| D30 | Build order: spike → environment + runtime + controller + policy → proxy + gateway + broker → integration → test profiles → launcher, backup, migration → release; corpora are release gates. |
| D31 | Encrypted backups (key in the OS keychain plus a one-time recovery key), consistent snapshots, restore validation, retention, weekly restore-verify. |
| D32 | Migration is a one-time cutover by the only user; no bridge release, banner or sunset. |
| D33 | Specs now; build after the core functionality and the open live acceptances. |

## 4. Current state (v0.82.0 — detail in `52-01-findings.md` §2–§3 and §19)

| Area | Today | File(s) |
|---|---|---|
| Kiro launch | `kiro-cli acp --agent-engine v3`, own process group, env = the worker's (Phase 51 needs `PATH`, `PLAYWRIGHT_BROWSERS_PATH`), `KIRO_HOME` required | `genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/launch.py`, `client.py` |
| Trust | Projected custom agent, activation verified, permission ladder with an allowlist backstop; workflow built-ins auto-approved | `kiro_agent_sdk/agent_spec.py`, `permissions.py`; `genesis_core/nodes/agent.py` |
| Agent seam | `AgentProvider` Protocol, `KiroAcpProvider` default (ADR-051); chat builds its options itself | `genesis_core/agents/provider.py`, `kiro.py`; `genesis/chat/manager.py` |
| Workers | Subprocess worker on the host, env = the server's (ADR-012) | `genesis/runs/supervisor.py`, `worker.py` |
| MCP | stdio servers with secrets in `env`, launched by Kiro; blackboard MCP | `genesis_core/mcp/registry.py`, `genesis_core/mcp/blackboard_server.py` |
| Kiro sign-in | `kiro-cli login --use-device-flow` over a pty; the login in kiro-cli's store | `genesis/runtime/kiro_auth.py` |
| Testing | Program nodes open `apwt` sessions with `--login` (password in env); agents run `npx --no-install apwt`; `TE-` executions run Playwright with credentials | `genesis/testexec/**` |
| API | ≈154 mutating routes, no auth; report origin on port + 100 | `genesis/api/**`, `genesis/testexec/reports_origin.py` |
| Install / update | `scripts/install.sh`, `genesis up`, git-tag self-update | `scripts/install.sh`, `genesis/runtime/launcher.py`, `updater.py` |

## 5. Design overview

```
 user's machine ── genesis-launcher (uv) ── Keychain (backup key) ── browser → 127.0.0.1:8760 (+ report origin)
                       │ EnvironmentProvider: Colima (macOS/Linux) · WSL2 distro (Windows)
 ┌─ Genesis VM ────────▼────────────────────────────────────────────────────────────────────────────────────┐
 │  VM firewall (nftables / DOCKER-USER): sandbox subnet → proxy:port, gateway:port only; drops counted     │
 │                                                                                                          │
 │  control network ──────────────────────────────────────┐                                                 │
 │  ┌ app container (trusted) ──────────────────────┐     │   ┌ controller container ────────────────────┐  │
 │  │ genesis serve · RunManager · workers          │ API │   │ only engine access (Docker socket)       │  │
 │  │ genesis.db · memory.db · secrets · Kiro login │────►│──►│ SandboxRuntime: docker-runc (gVisor later)│  │
 │  │ policy compiler → AgentSecurityPolicy (hash)  │     │   │ provision · limits · queue · cancel ·    │  │
 │  │ MCP gateway (servers + creds, allowlist, log) │     │   │ cleanup · health · orphan sweep · stats  │  │
 │  │ Kiro credential broker (Genesis sign-in)      │     │   └──────────────────────────────────────────┘  │
 │  │ AgentProvider: Kiro over ACP via stdio attach │     │                                                 │
 │  └───────▲───────────────────────▲───────────────┘     │   ┌ egress proxy ──────────────────────────────┐│
 │          │ relay (per-turn token)│ ACP stdio + token   │   │ host-name allow-list per policy; resolve,  ││
 │  sandbox network (internal) ─────┼─────────────────────┴──►│ refuse private/IP-literal, pin; audit      ││
 │  ┌ sandbox (one per turn / chat session; policy-built) ──┐ └───────────────────────────────▲────────────┘│
 │  │ kiro-cli-chat acp --agent-engine v3 --auth-method client                              │ internet     │
 │  │ shell · file tools · skills · relay → gateway · HTTP(S) → proxy only                 ─┘             │
 │  │ mounts: the run's subfolder (rw, same path) · /tmp ; no secrets, no socket            │              │
 │  └───────────────────────────────────────────────────────────────────────────────────────┘              │
 │  volumes: state · artifacts · kiro-login · backups                                                       │
 └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

| Building block | Sub-spec |
|---|---|
| Findings + decisions | 52-01 |
| Spike: the remaining unknowns, with corpora drafts (gate) | 52-02 |
| ADR drafts; event kinds; no `genesis.db` migration expected | 52-03 |
| Images and supply chain (`app`, `sandbox`, `controller`, `egress`; SBOM, scan, signing) | 52-04 |
| EnvironmentProvider interface + macOS Colima; VM firewall baseline; volumes; registry sign-in | 52-05 |
| Sandbox Controller, SandboxRuntime (`runc`), `AgentSecurityPolicy`, self-test | 52-06 |
| Egress proxy, network enforcement, `META.egress` | 52-07 |
| MCP gateway + relay; Kiro sign-in + credential broker | 52-08 |
| Genesis integration: sandboxed `AgentProvider` for workflow nodes and chat | 52-09 |
| Testing in the boxed world: saved logins, `test-execution` and `recording` profiles, noVNC | 52-10 |
| Launcher, dev stack and fleet | 52-11 |
| Data volumes, encrypted backup/restore, import, cutover | 52-12 |
| HTTP API (token middleware, Origin/Host, new routes) | 52-13 |
| Web experience | 52-14 |
| Review, hardening, live acceptance — macOS (Release 1 gates) | 52-15 |
| Release 1 (macOS) + docs write-back | 52-16 |
| Linux EnvironmentProvider (spike + build) | 52-17 |
| Windows EnvironmentProvider (spike + build) | 52-18 |
| Review and live acceptance — Linux and Windows (Release 2 gates) | 52-19 |
| Release 2 (Linux, Windows) + docs write-back | 52-20 |

## 6. Threat model and limits (D21; carried into the ADR)

- **Attacker:** content the agent reads (prompt injection), the model itself, and agent-written code (tests). The user
  and Genesis's own program code are trusted.
- **Protected:** secrets, Kiro login, `genesis.db`/`memory.db`, the user's files and machine, the VM's services, the
  local API, other runs, the network beyond declared hosts.
- **Boundary:** a container per turn on a private network, policy enforced by the controller and the VM firewall,
  credentials only on the trusted side.
- **Limits stated plainly:** (1) sandboxes share the VM's Linux kernel with the app and controller containers and with
  each other, so a kernel exploit crosses every container boundary; mitigations: hardening (D5), patched pinned VM
  images, the runtime upgrade path (D21); (2) the container engine (and so the controller) is root inside the VM;
  (3) WSL2 distributions share one kernel; (4) a Kiro access token, while it lives, acts as the user's Kiro account
  (D26); (5) the QA saved-login cookie is readable by the agent, bounded to the QA host (D15); (6) an allowed host is
  an upload path (D10); (7) commands inside an agent's scripts are not individually logged (D28).

## 7. Session plan

Build only after D33's conditions. S1 = 52-02 spike (genesis-dev; **gate**: a FAIL on a must-pass item stops the
phase for a re-spec of the sub-specs it affects) → S2 = 52-03 → S3 = 52-04 → S4 = 52-05 → S5 = 52-06 → S6 = 52-07 →
S7 = 52-08 → S8 = 52-09 (genesis + genesis-workflows) → S9 = 52-10 → S10 = 52-11 → S11 = 52-12 → S12 = 52-13 (each
backend sub-spec adds its routes; 52-13 owns the contract table, fixtures and the token middleware) → S13 = 52-14 →
S14 = 52-15 (genesis-review) → S15 = 52-16 (genesis-release, then genesis-docs). Release 2: S16 = 52-17 and S17 =
52-18 (either order; each needs its real machine) → S18 = 52-19 → S19 = 52-20. One sub-spec at a time: they share
the genesis checkout. Until 52-09 switches the default, the host path keeps working so every intermediate commit
keeps the gates green; the host path is removed in 52-12 (cutover).

## 8. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 52-01 | project-tracker | Findings, research, decisions D1–D33, baseline §19 |
| 52-02 | genesis (`scripts/spikes/52-02/`) | Colima/Lima pin and `hostLoopback`; sandbox start latency; kiro-cli Linux in a sandbox over attached stdio; `--auth-method client` with a Genesis-owned login; relay MCP; VM firewall, Docker embedded DNS, IPv6; `volume-subpath`; Chromium + Xvfb + noVNC; resource numbers; first corpora |
| 52-03 | project-tracker, genesis | ADR drafts (agent runtime, containerized distribution, API token); new event kinds; data-model check |
| 52-04 | genesis (`docker/`, CI) | Four images, multi-arch, pinned, SBOM, scan gate, signing, release manifest |
| 52-05 | genesis (`genesis/agent_runtime/environment/`) | `EnvironmentProvider`; Colima provider; VM config; firewall baseline; volumes; registry sign-in |
| 52-06 | genesis (`genesis/agent_runtime/`) | Controller service + client; `SandboxRuntime` + `runc` implementation; policy model + compiler; queue; sweep; stats; self-test |
| 52-07 | genesis, genesis-workflows | Egress proxy; per-sandbox firewall rules; DNS stub if needed; audit; `META.egress` + library gate |
| 52-08 | genesis | MCP gateway + relay; Kiro OIDC sign-in, store, refresh; access-token responder; credential audit |
| 52-09 | genesis, genesis-workflows | Sandboxed `AgentProvider`; `kiro_node` and chat through it; clean env; egress declarations for workflows that need hosts |
| 52-10 | genesis | Saved-login sign-in in the app container; `apwt open --storage-state`; `loginAs` → saved login; `test-execution` and `recording` profiles; noVNC |
| 52-11 | genesis (`packages/genesis-launcher/`), genesis-fleet | Launcher commands; prerequisites; dev stack; fleet as two stacks |
| 52-12 | genesis | Volumes layout; encrypted backup/restore; restore-verify; retention; import of v29 data; cutover; host path removed |
| 52-13 | genesis | Token middleware, Origin/Host, token bootstrap; new routes; contract table; fixtures |
| 52-14 | genesis (`web/`) | Settings → Agent runtime; Backups; Egress additions; Run Detail sandbox telemetry; recording view; token bootstrap |
| 52-15 | all | Review, gates, corpora on macOS, live acceptance of every agent-node workflow and chat mode sandboxed |
| 52-16 | genesis, genesis-workflows, project-tracker | Release 1 + docs write-back |
| 52-17 | genesis | Linux provider: spike + build on a real Linux machine |
| 52-18 | genesis | Windows provider: spike + build on a real Windows machine |
| 52-19 | all | Review + corpora + live acceptance on Linux and Windows |
| 52-20 | genesis, project-tracker | Release 2 + docs write-back |

API sub-spec: 52-13. Review & acceptance: 52-15 (Release 1), 52-19 (Release 2). Release & onboarding: 52-16, 52-20.

## 9. Release plan

**Release 1 (macOS):** genesis next minor after the then-current release (images `app`, `sandbox`, `controller`,
`egress` at the same tag, ADR-080), the `genesis-launcher` package at its own version (D13), then genesis-workflows
next minor (`egress` declarations, the library gate; pins on the new genesis tag, L-057). Gates: 52-15's corpora and
live acceptance. The user's cutover follows 52-12 (D32). **Release 2 (Linux, Windows):** genesis patch or minor with
the two providers and any image changes, launcher minor; gates: 52-19. A release before live acceptance only by an
explicit decision, said plainly everywhere (L-111).

## 10. Scope

**In:** §2. **Out:** multi-user or hosted Genesis (ADR-026); boxing the five role agents (ADR-077, D16); a second
AgentProvider or SandboxRuntime (D21: interfaces only); gVisor/microVM implementations (D5); TLS interception in the
proxy (D10); process accounting inside sandboxes (D28). **Deferred to the backlog** (created at write-back): a git
credential proxy and mediated secret use (D20); gVisor `runsc` as a policy option; a warm pool (D6); a
Keychain-backed `SecretProvider` for the app container (findings §9.5) if the volume model proves insufficient.

## 11. Defaults (each a setting; numbers from 52-02's measurements)

VM size; per-sandbox CPU / memory / process limits; concurrency cap; app-container memory reservation; container log
cap; backup retention N; restore-verify weekday; proxy allowed ports (443, 80); turn wall-clock margin over
`turn_timeout`; self-test timeout. Initial values are proposed by 52-02 and confirmed with the user before 52-06.

## 12. Risks

| Risk | Mitigation |
|---|---|
| A must-pass spike item fails (Linux kiro-cli over attached stdio, client auth with Genesis's sign-in, the relay, firewall/DNS) | 52-02 is a gate; fallbacks named per item there |
| Per-turn start latency hurts loop-heavy workflows | Measured in 52-02; warm pool later (D6) |
| A workflow silently relied on host files or hosts | Findings §8.4 list; 52-02 replays the recorded commands; `META.egress`; 52-15 live runs |
| Kernel escape from a sandbox | Accepted limit (§6); hardening; patched VM; runtime upgrade path |
| Colima/Lima, Docker or kiro-cli behaviour changes | Pinned versions; probe on upgrade (L-044, L-117); corpora re-run on every VM/image update (D22) |
| The baseline moves before the build | D33 re-base; §19 table re-checked |
| Losing data in the VM | Encrypted, verified backups; pre-update backups (D31) |
| Linux/Windows test machines unavailable | Release 2 waits; Release 1 unaffected (D17) |
| Signing-key or registry-token handling leaks a secret | Designed in 52-04/52-16; never read CI variables from an agent (L-100) |

## 13. ADR summaries (drafts in `adr-drafts.md`; numbers fixed at write-back)

- **Genesis Agent Runtime (proposed).** Every agent turn and chat session runs in a disposable sandbox created by the
  Sandbox Controller from an immutable `AgentSecurityPolicy`, inside a Genesis-owned VM: only its run folder mounted,
  no secrets, no engine access, egress only through the proxy under network-layer rules, MCP only through the gateway
  relay, Kiro tokens only from the broker. Amends ADR-012, ADR-029, ADR-031, ADR-051, ADR-083, ADR-086.
- **Containerized distribution (proposed).** Genesis ships as signed, digest-pinned images run in a Genesis-owned VM
  by a `uv`-installed launcher; data in VM volumes with encrypted, verified backups; update = pull + recreate after a
  backup. Amends ADR-046, ADR-080, ADR-022.
- **Local API token (proposed).** Every `/api` request and the report origin need the per-launch token, with Origin and
  Host checks. Amends ADR-026, ADR-028, ADR-085.

## Context manifest

```toml
areas    = ["security", "distribution", "runs-worker", "sdk-acp"]
adrs     = ["ADR-012", "ADR-026", "ADR-029", "ADR-046", "ADR-051", "ADR-080", "ADR-083", "ADR-086"]
lessons  = ["L-088", "L-100", "L-111", "L-113", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md"]
code     = ["genesis/packages/genesis-core/genesis_core/agents/**", "genesis/genesis/runs/supervisor.py"]
upstream = []
```
