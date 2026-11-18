# 52-04 — Images and supply chain

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`docker/`, `.gitlab-ci.yml`). Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D1, D3, D5, D12, D27, D29. Upstream: 52-02 (S2, S14), 52-03.

## 1. Goal

Four images, built by CI for every tag on `arm64` and `amd64`, with pinned inputs, an SBOM, a vulnerability gate and a
signature, published with a release manifest the launcher and controller trust.

## 2. Images (Dockerfiles under `genesis/docker/<name>/`)

| Image | Contents | User | Notes |
|---|---|---|---|
| `app` | Python 3.13; the genesis app and its three packages from the tag (ADR-080, offline install as `scripts/install-packages.sh` does); `uv`; `gws`, `sail` (managed CLIs move from `~/.genesis/cli-tools` into the image or stay managed in the state volume, decided here with the user); kiro-cli (for the Genesis-owned sign-in helpers only, not for agent turns); headless Chromium for the trusted sign-in (D15) | non-root | The prebuilt SPA is package data (L-048); no Docker client |
| `sandbox` | Debian slim (glibc ≥ 2.34 for kiro-cli); kiro-cli (pinned, checksum); Python 3.13 with the stdlib; `jq`, `git` (no credentials), `curl`, `ripgrep`; Node 20 + npm; Playwright Chromium for the vendored apwt version and its OS deps; Xvfb + noVNC (only started by the `recording` profile); the MCP relay (52-08) | `agent` (fixed uid), `HOME=/home/agent` | Read-only root at run time; nothing secret; no Genesis app code beyond the relay. Whether `test-execution` uses this image or a smaller `testrunner` image is settled by 52-02 (D27) |
| `controller` | Python 3.13; the controller service (52-06); the Docker SDK or CLI | non-root in the `docker` group of the VM socket | The only image that gets the engine socket (D24) |
| `egress` | Python 3.13 and the proxy (52-07), or Squid if 52-02 S7 chose it | non-root | Two networks: sandbox and outbound |

## 3. Pinning and provenance (D29)

- Every `FROM` by digest (`image@sha256:…`), refreshed deliberately by a script that rewrites the digests and the
  checksums together.
- Every downloaded tool pinned by version **and** checksum in one file per image (`docker/<name>/versions.lock`):
  kiro-cli (KiroCrew pins the same way, findings §18.6), Node, Playwright and its browser build, gws, sail, uv, noVNC.
  A mismatch fails the build.
- `apt`/`pip`/`npm` installs from lock files with hashes where the tool supports them.
- The vendored playwright-appian tarball stays byte for byte (`genesis/testexec/vendor/`, L-119).

## 4. CI (genesis `.gitlab-ci.yml`)

- On a tag: `buildx` multi-arch builds of the four images (cache from the previous tag), pushed as
  `registry.gitlab.appian-stratus.com/ramaswamy.u/genesis/<name>:<tag>`.
- **SBOM** per image (SPDX or CycloneDX, e.g. `syft`), attached to the release.
- **Vulnerability scan** per image (GitLab container scanning or `trivy`); the release gate fails on any finding at or
  above the threshold agreed with the user in this sub-spec (proposed: Critical, and High with a fix available);
  accepted exceptions live in a reviewed allow-list file with an expiry date.
- **Signing**: each image digest signed (e.g. `cosign`); the key-handling design is written here and reviewed with the
  user: no agent reads CI variables (L-100), the private key never leaves CI's protected variables, the public key
  ships in the launcher.
- **Release manifest** (`release-manifest.json`, signed): tag, the four image digests per architecture, the SBOM and
  scan report digests, the minimum launcher version.
- On merge requests: build `amd64` only, run the image unit tests (§5), no push.

## 5. Tests

Per image: a container test (`docker run` the image with the D5 flags) that checks the user, the read-only root, the
absence of credentials and sockets, and the presence and versions of every pinned tool; a test that `versions.lock`
and the Dockerfiles agree; a manifest-signature round trip in CI.

## Context manifest

```toml
areas    = ["distribution", "release-ci", "security", "browser-testing"]
adrs     = ["ADR-017", "ADR-024", "ADR-040", "ADR-046", "ADR-080", "ADR-081"]
lessons  = ["L-025", "L-027", "L-048", "L-056", "L-057", "L-098", "L-100", "L-112", "L-119"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/docker/**", "genesis/.gitlab-ci.yml", "genesis/scripts/install-packages.sh", "genesis/genesis/testexec/vendor/**"]
upstream = ["52-02", "52-03"]
```
