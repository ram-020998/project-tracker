# 52-18 — Windows EnvironmentProvider (spike and build)

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`packages/genesis-launcher/`). Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D3, D4, D13, D17, D22, D23, D31. Needs a **real Windows 11
> machine** (x64). Upstream: 52-05, 52-16.

## 1. Goal

Genesis installs and runs on Windows inside a Genesis-owned WSL2 distribution with Docker Engine, separated from the
user's Windows files and other WSL distributions as far as WSL2 allows.

## 2. Spike first (W1–W8)

| # | Question | PASS when |
|---|---|---|
| W1 | `wsl --install` prerequisites (admin once; Hyper-V/VM Platform allowed by IT policy); importing a Genesis distribution from a pinned rootfs (`wsl --import genesis …`) | Distribution runs; the user's other distributions untouched |
| W2 | `/etc/wsl.conf`: `[automount] enabled=false`, `[interop] enabled=false appendWindowsPath=false` | No `/mnt/c`; Windows programs cannot be started from the distribution |
| W3 | Docker Engine inside the distribution with systemd; user namespaces and the default seccomp profile work (KiroCrew found Docker CE in WSL2 can lack `CONFIG_USER_NS`, findings §18.6) | The D5 flags run a sandbox |
| W4 | Networking: WSL's NAT or mirrored mode; reaching the Windows host's `127.0.0.1` services from a sandbox is refused (the VM firewall plus WSL settings); port 8760 and the report origin reachable from the Windows browser on loopback only | As described |
| W5 | The `amd64` images from Release 1 unchanged | Self-test and a probe turn pass |
| W6 | Windows Credential Manager for the backup key (D31), from the Python launcher | Key stored and read back |
| W7 | The launcher under `uv` on Windows (PowerShell), driving `wsl.exe` and the distribution's Docker | Commands work |
| W8 | The full D22/D23 corpora | All pass; the shared-kernel limit across WSL distributions recorded (umbrella §6) |

## 3. Build

`Wsl2Provider` (create from the pinned rootfs, configure, start/stop, `docker_endpoint` through the distribution, the
network baseline, upgrade, destroy); the Credential Manager adapter; launcher Windows paths and messages; docs.

## 4. Tests

Unit tests with a fake `wsl.exe`; the corpora on the Windows machine.

## Context manifest

```toml
areas    = ["distribution", "security"]
adrs     = ["ADR-017", "ADR-026", "ADR-046", "ADR-080"]
lessons  = ["L-044", "L-051", "L-088", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-05-environment-provider-macos.md", "tracker:specs/phase-52-agent-runtime-isolation/.research/kirocrew-runtime.md"]
code     = ["genesis/packages/genesis-launcher/**"]
upstream = ["52-05", "52-16"]
```
