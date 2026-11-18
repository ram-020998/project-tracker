# 52-20 — Release 2 (Linux, Windows) and onboarding

> **Status:** SPEC-DRAFTED 2026-11-18. Agents: **genesis-release**, then **genesis-docs**. Repos: genesis,
> project-tracker. Parent: `specs/phase-52-agent-runtime-isolation.md`. Decisions: D3, D17. Upstream: 52-19 (SHIP).

## 1. Release

genesis patch or minor (images only if changed), `genesis-launcher` minor with the two providers; the same steps and
checks as 52-16 §1 (L-056, L-057, L-100); release notes per OS with prerequisites (KVM; WSL2 and IT policy) and the
known limits (umbrella §6, WSL2's shared kernel).

## 2. Docs write-back

ADR-B amended for the Linux and Windows providers; lessons; areas; state; progress; changelog; README row (Phase 52
SHIPPED once both releases are out); backlog; `genesis-ctx lint` green.

## Context manifest

```toml
areas    = ["release-ci", "distribution"]
adrs     = ["ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-056", "L-057", "L-100", "L-111"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-16-release-1-and-onboarding.md"]
code     = ["genesis/packages/genesis-launcher/**", "genesis/pyproject.toml"]
upstream = ["52-19"]
```
