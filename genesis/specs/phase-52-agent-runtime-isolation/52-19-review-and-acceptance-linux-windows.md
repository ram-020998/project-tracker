# 52-19 — Review and live acceptance on Linux and Windows (Release 2 gates)

> **Status:** SPEC-DRAFTED 2026-11-18. Agent: **genesis-review**. Repos: genesis. Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D3, D4, D17, D22, D23, D31. Upstream: 52-17, 52-18.

## 1. Review

`genesis-ctx check --since <Release 1 tag>`; the two providers, the keychain adapters and the launcher changes; the
threat model's per-OS limits checked against what was built.

## 2. Release gates, on each OS (real machines, release candidate images by digest)

52-15 §3 G1–G7 on Linux and on Windows, plus: the host's own loopback services refused; on Windows, no `/mnt/c` and no
Windows program launch from a sandbox or the distribution; port forwards on loopback only.

## 3. Live acceptance (one machine per OS)

Install from scratch with the launcher; a backup and a restore with the recovery key on another machine (macOS →
Linux or Windows); three representative agent-node workflows, one chat mode, one `TE-` execution and one recording;
pause/cancel with no leftovers; an update with rollback. Verdict in `reviews/52-19-review.md`.

## Context manifest

```toml
areas    = ["security", "release-ci", "distribution"]
adrs     = ["ADR-026", "ADR-046", "ADR-080", "ADR-086"]
lessons  = ["L-088", "L-097", "L-108", "L-110", "L-111", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-15-review-and-acceptance-macos.md"]
code     = ["genesis/packages/genesis-launcher/**"]
upstream = ["52-17", "52-18"]
```
