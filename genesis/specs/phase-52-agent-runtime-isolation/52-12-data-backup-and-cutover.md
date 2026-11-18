# 52-12 — Data volumes, encrypted backup and restore, import, cutover

> **Status:** SPEC-DRAFTED 2026-11-18. Repos: **genesis** (`genesis/agent_runtime/backup/` or `genesis/backup/`,
> launcher commands, settings paths). Parent: `specs/phase-52-agent-runtime-isolation.md`. Decisions: D11, D12, D31,
> D32. Upstream: 52-05, 52-09, 52-10, 52-11.

## 1. Goal

Genesis's data lives safely in VM volumes, survives updates and VM loss through encrypted, verified backups, and the
user's current host data moves in once.

## 2. Volumes

| Volume | Holds | Mounted into |
|---|---|---|
| `genesis-state` | `genesis.db`, `memory.db` (WAL), secrets, settings, managed MCP/CLI installs, skills, chat Kiro homes, run lock | app (rw) |
| `genesis-artifacts` | run folders (`$GENESIS_ARTIFACTS_DIR`), testing workspaces | app (rw); each sandbox: its run subfolder only (D11) |
| `genesis-kiro-login` | Genesis's Kiro login (D19) | app (rw), never a sandbox |
| `genesis-backups` | encrypted backup archives and their manifest | app (rw) for writing; the launcher reads through `docker cp` / a helper container |

`GENESIS_STATE_DIR` and `GENESIS_ARTIFACTS_DIR` point at fixed in-container paths; absolute paths in state and prompts
use the artifacts path that is identical in the app and the sandboxes (ADR-010).

## 3. Backup (D31)

- **What:** consistent copies of `genesis.db` and `memory.db` with SQLite's online backup API (off the event loop,
  L-026), secrets, settings, the Kiro login, the artifacts volume, a manifest with SHA-256 per file and the Genesis
  version and DB version.
- **Encryption:** one archive per backup, encrypted with a key the launcher generates on first use and stores in the
  host keychain (macOS Keychain; Windows Credential Manager and Linux Secret Service in Release 2); a **recovery key**
  shown once at creation for the user to save; the archive format and cipher chosen here (an authenticated cipher,
  e.g. age or AES-256-GCM with a per-archive key wrapped by the master key).
- **When:** on demand (launcher, Settings), daily if enabled, and automatically before every update (D12).
- **Restore validation:** each new backup is restored into scratch volumes and checked (`PRAGMA integrity_check`,
  manifest checksums, a migration dry-run on a copy) before it is marked good; a failed check keeps the previous good
  backup and warns in Settings.
- **Retention:** keep N daily (setting) plus every pre-update backup; never delete the newest good backup.
- **Weekly restore-verify:** the newest good backup is verified again on the configured weekday; result in Settings.
- **Restore:** `genesis-launcher restore <archive>` stops the stack, restores into fresh volumes, keeps the replaced
  volumes until the user confirms, starts and self-tests; a restore on another machine asks for the recovery key.

## 4. Import and cutover (D32)

- `genesis-launcher import`: reads the user's existing `~/.genesis/` and `~/Genesis/runs/` (DB at v29 or later, per-run
  `_kiro/` homes, the testing workspaces, managed installs re-installed from their bundles rather than copied when they
  are macOS binaries), copies them into the volumes, runs migrations on start, runs the self-test and one probe turn;
  the originals are left untouched.
- Then the host path is removed from the product: the host `KiroAcpProvider` default, `scripts/install.sh`, `genesis
  up` and the git-tag updater (52-11); the README and release notes say how to retire the old install by hand.

## 5. Tests

Backup round trip on small fixtures (encryption, manifest, integrity, migration dry-run); tampered archive refused;
wrong key refused; recovery-key path; retention rules; the import on a copy of a v29 fixture tree; restore leaving the
replaced volumes until confirmation.

## Context manifest

```toml
areas    = ["db", "distribution", "config-secrets", "memory", "security"]
adrs     = ["ADR-010", "ADR-013", "ADR-022", "ADR-024", "ADR-030", "ADR-046", "ADR-054", "ADR-080"]
lessons  = ["L-004", "L-019", "L-026", "L-091", "L-097", "L-102"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/genesis/db/**", "genesis/genesis/runtime/settings.py", "genesis/genesis/config/**", "genesis/packages/genesis-launcher/**"]
upstream = ["52-05", "52-09", "52-10", "52-11"]
```
