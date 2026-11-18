# 52-05 — EnvironmentProvider and the macOS Colima provider

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`packages/genesis-launcher/` provider code; the VM firewall
> baseline). Parent: `specs/phase-52-agent-runtime-isolation.md`. Decisions: D1, D2, D3, D6, D11, D12, D21, D23.
> Upstream: 52-02 (S1, S6, S8), 52-04.

## 1. Goal

The first layer of the Genesis Agent Runtime: an interface that owns the Genesis VM and its container engine, and the
macOS implementation on Colima, so everything above it talks only to a Docker API endpoint.

## 2. Interface (`genesis_launcher/environment/base.py`)

`EnvironmentProvider` — `detect() -> Prereqs` (what is installed, versions, what is missing, the fix) ·
`install(consent) ` · `create(spec: VmSpec)` · `start()` · `stop()` · `status() -> VmStatus` · `docker_endpoint() ->
str` · `apply_network_baseline()` · `upgrade(pinned_versions)` · `destroy(confirm)`. `VmSpec`: name, CPUs, memory,
disk (umbrella §11 defaults), mounts (none for users; the repo only for the dev profile, D16), port forwards
(`127.0.0.1:8760` and the report origin only). Implementations: `ColimaProvider` (this sub-spec; macOS, reused by
Linux in 52-17), `Wsl2Provider` (52-18). A `FakeProvider` for unit tests.

## 3. Colima provider (macOS)

- Pinned Colima and Lima versions (from 52-02 S1); installed through Homebrew with the user's consent, or checked if
  present; the user's own profiles (e.g. `default`) are never started, stopped or changed.
- Profile `genesis`: `vmType: vz`, `mountType` irrelevant (`mounts: []`), `networkOpts.hostLoopback: false` when the
  pinned Lima supports it, else the firewall rule from 52-02's fallback; fixed CPU/memory/disk; Docker runtime; port
  forwards bound to `127.0.0.1` only.
- **Network baseline in the VM** (applied at every start, idempotent, checked by the self-test): the sandbox network
  is created `--internal` with IPv6 off; nftables / `DOCKER-USER` rules allow the sandbox subnet to reach only the
  proxy's and gateway's ports and drop everything else with counters, including the VM's own addresses (Lima's
  `sshd`, guest agent), the host-loopback address and `169.254.0.0/16`. Per-sandbox rules are added by the controller
  (52-06/52-07) on top of this baseline.
- Volumes created here: `genesis-state`, `genesis-artifacts`, `genesis-kiro-login`, `genesis-backups` (layout in 52-12).
- Registry sign-in for the VM's Docker (D12): a GitLab personal access token with `read_registry` scope, entered by
  the user in the launcher, stored only in the VM's Docker credential store; never printed or logged.
- Kernel/VM image updates come only with a pinned-version upgrade (`upgrade()`), after which the D22 self-test runs.

## 4. Tests

Unit tests with `FakeProvider` and a fake `colima`/`limactl` on `PATH` (argv and config assertions); an integration
test (marked, run on a Mac) that creates a throwaway profile, applies the baseline, checks the user's `default` profile
is untouched and destroys it; the S12 network-baseline subset re-run against the real VM.

## Context manifest

```toml
areas    = ["distribution", "security"]
adrs     = ["ADR-017", "ADR-026", "ADR-046", "ADR-080"]
lessons  = ["L-051", "L-052", "L-088", "L-100"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md"]
code     = ["genesis/packages/genesis-launcher/**", "genesis/genesis/runtime/launcher.py"]
upstream = ["52-02", "52-04"]
```
