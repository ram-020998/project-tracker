# 52-11 — Launcher, dev stack and fleet

> **Status:** SPEC-DRAFTED 2026-11-18. Repos: **genesis** (`packages/genesis-launcher/`, `docker/compose*.yaml`),
> **genesis-fleet**. Parent: `specs/phase-52-agent-runtime-isolation.md`. Decisions: D12, D13, D14, D16, D22, D29.
> Upstream: 52-04, 52-05, 52-06.

## 1. Goal

The one Genesis component on the user's machine, and a development stack that runs the same isolation paths.

## 2. `genesis-launcher` (installed with `uv tool install genesis-launcher`)

- Own version (D13); not an internal dependency of any other package (ADR-080); Python 3.13 from `uv`.
- Commands: `install` (prerequisites with consent through the EnvironmentProvider, registry sign-in, pull and verify
  the release manifest and images by digest and signature, D29) · `start` (VM, stack, wait for health and the D22
  self-test, open the browser with the API token in the URL fragment, D14) · `stop` · `status` · `logs [service]` ·
  `open` · `token` (prints the current API token for the CLI and acceptance drivers; never logged) · `update` (backup,
  pull and verify the new tag's manifest, recreate, migrate on start, self-test; rollback = previous tag + that backup,
  52-12) · `backup` / `restore` (52-12) · `uninstall` (stops and removes the stack; keeps volumes and backups unless the
  user confirms deletion twice) · `self-update`.
- The stack is a Compose project (`docker/compose.yaml`): `app`, `controller`, `egress` (and the DNS stub if 52-07 needs
  it), the networks (control, sandbox internal, outbound) and volumes; images by digest from the manifest.
- Replaces `scripts/install.sh` and `genesis up` for users; `genesis/runtime/launcher.py` and `updater.py` keep only what
  runs inside the app container (or are removed at 52-12).

## 3. Dev stack (D16)

- `genesis-launcher dev up`: a separate Colima profile `genesis-dev` with **only the repo folder** mounted; images built
  locally from the working tree (`docker/compose.dev.yaml` override: code mounted into the app container, auto-reload,
  sandboxes and their image built from the tree); the same controller, proxy, gateway, broker and API token.
- Unit tests and linters stay on the host venv (pytest, vitest, ruff, tsc); the `LocalRuntime` (52-06) serves unit
  tests only.
- **Fleet:** `genesis-fleet` runs two stacks in the dev VM (8760 and 8761, separate volumes and API tokens, one
  controller each or a shared one with per-stack labels, decided in this sub-spec); `gsm` changes accordingly.
- Live acceptance and the review agents use `genesis-launcher token` to call the API (D14).

## 4. Tests

Launcher command tests with fake providers and a fake registry (manifest signature failure refuses to start; digest
mismatch refuses; update rollback path); a dev-stack smoke test on the Mac (stack up, self-test passes, one sandboxed
probe turn); fleet two-stack smoke test.

## Context manifest

```toml
areas    = ["distribution", "release-ci", "security"]
adrs     = ["ADR-017", "ADR-026", "ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-051", "L-052", "L-068", "L-089", "L-098", "L-099", "L-100", "L-112"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-22-distribution-and-shipping.md"]
code     = ["genesis/packages/genesis-launcher/**", "genesis/docker/**", "genesis/genesis/runtime/launcher.py", "genesis/genesis/runtime/updater.py", "genesis/scripts/install.sh", "genesis-fleet/**"]
upstream = ["52-04", "52-05", "52-06"]
```
