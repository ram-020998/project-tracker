# 52-16 — Release 1 (macOS) and onboarding

> **Status:** SPEC-DRAFTED 2026-11-18. Agents: **genesis-release** (asks before every tag and push), then
> **genesis-docs**. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D12, D13, D17, D29, D32. Upstream: 52-15 (SHIP).

## 1. Release order

1. **genesis** next minor: version bump (one shared version, ADR-080); verify the release commit contains every changed
   file (L-056); tag; CI builds, scans, signs and publishes the four images and the signed release manifest (52-04);
   confirm the pipeline green with `glab` (never reading CI variables, L-100).
2. **genesis-launcher**: its own version, published where the user installs it from (`uv tool install` source decided
   in 52-11, e.g. the project's package registry or a git+ssh reference); the minimum launcher version in the manifest.
3. **genesis-workflows** next minor: `egress` declarations and the gate; pins on the new genesis tag (L-057).
4. **Deploy (the user's cutover, D32):** `genesis-launcher install` → `import` (52-12) → self-test → a probe turn; the
   old host install retired by hand afterwards. The fleet moves to two stacks in the dev VM (52-11).

## 2. Release notes (the user checklist)

What changed (agents in sandboxes, egress default-deny with how to add a host, the API token and the launcher's `open`,
Genesis-owned Kiro sign-in, backups and the recovery key to save), what stopped working by design (findings §8.4),
prerequisites, and that Linux and Windows follow in Release 2.

## 3. Docs write-back (genesis-docs, `agent-system/skills/genesis-doc-writeback/SKILL.md`)

File ADR-A, ADR-B, ADR-C with `genesis-ctx add adr` (amendment chains: ADR-012, 022, 026, 028, 029, 031, 046, 051,
080, 083, 085, 086); lessons from the sub-specs' candidates (including the findings' `GET /projects/:id` runner-token
lesson); `context/areas.toml` gains an **agent-runtime** area (paths `genesis/genesis/agent_runtime/**`,
`genesis/docker/**`, `genesis/packages/genesis-launcher/**`) and routes the changed paths; L0-core §2–§3 and bible/02
updated for the containerized architecture; code map; `context/state/current.md`; `progress/phase-52-…md`;
changelog; README row; tracker; backlog (`specs/backlog/phase-52-follow-ups.md`: D20 items, gVisor, warm pool, script
process accounting); `genesis-ctx lint` green.

## Context manifest

```toml
areas    = ["release-ci", "distribution", "security", "workflows-library"]
adrs     = ["ADR-019", "ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-051", "L-056", "L-057", "L-089", "L-100", "L-111", "L-112", "L-119"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-53-kiro-sdk-v3/53-12-release-and-onboarding.md"]
code     = ["genesis/pyproject.toml", "genesis/.gitlab-ci.yml", "genesis/docker/**", "genesis/packages/genesis-launcher/**", "genesis-workflows/pyproject.toml"]
upstream = ["52-15"]
```
