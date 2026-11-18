# 52-17 — Linux EnvironmentProvider (spike and build)

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`packages/genesis-launcher/`). Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D3, D4, D17, D22, D23, D31. Needs a **real Linux machine**
> (x86_64; ARM64 if available). Upstream: 52-05, 52-16.

## 1. Goal

Genesis installs and runs on Linux with the same boundary as macOS: a Genesis-owned Colima VM on QEMU/KVM, never
Docker directly on the host.

## 2. Spike first (L1–L6, PASS/FAIL with evidence, as 52-02)

| # | Question | PASS when |
|---|---|---|
| L1 | Colima (pinned) on the target distributions (Ubuntu LTS, Fedora) with QEMU/KVM; KVM access (`/dev/kvm`, group); nested virtualization when the host is itself a VM | VM up; prerequisites listed with the one-time `sudo` steps |
| L2 | Host-loopback blocking on QEMU (Lima's `hostLoopback` is `vz`-only): the VM firewall rule from 52-05's fallback | The Linux host's `127.0.0.1` services refused from a sandbox |
| L3 | The `amd64` images from Release 1 run unchanged (and `arm64` on an ARM host) | The self-test and one probe turn pass |
| L4 | Port forwarding of 8760 and the report origin to the host's `127.0.0.1` only | Reachable on loopback, not on the LAN |
| L5 | Secret Service for the backup key (D31); a headless fallback (a 0700 file, KiroCrew/Docker Sandboxes behaviour, said plainly) | Key stored and read back |
| L6 | The full D22/D23 corpora | All pass |

## 3. Build

`ColimaProvider` gains the Linux branch (QEMU, KVM checks, prerequisite install through the distribution's package
manager with consent); the keychain adapter for Secret Service; launcher detection and messages; docs for the
supported distributions.

## 4. Tests

Unit tests with fake `colima`/`qemu`/package-manager binaries; the corpora on the Linux machine.

## Context manifest

```toml
areas    = ["distribution", "security"]
adrs     = ["ADR-017", "ADR-026", "ADR-046", "ADR-080"]
lessons  = ["L-044", "L-051", "L-088", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-05-environment-provider-macos.md", "tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md"]
code     = ["genesis/packages/genesis-launcher/**"]
upstream = ["52-05", "52-16"]
```
