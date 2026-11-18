# 52-14 — Web experience

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`web/`). Parent: `specs/phase-52-agent-runtime-isolation.md`.
> Decisions: D10, D14, D15, D22, D28, D31. Upstream: 52-13.

## 1. Goal

Show the agent runtime and its decisions where the user already looks, with the existing design system (ADR-027,
ADR-055).

## 2. Surfaces

- **Token bootstrap:** the central API client reads the token from the URL fragment once, stores it in session
  storage, strips the fragment; a 401 shows "Open Genesis from the launcher" with the `genesis-launcher open` command.
- **Settings → Agent runtime** (new card): VM and versions, controller state (`ready` / `refusing` with the reason
  and the fix), image digests, last self-test (time, result, Run now), live sandboxes and queue.
- **Settings → Egress:** base hosts (read-only, with their source), user additions (add/remove with a warning dialog).
- **Settings → Backups:** list with status and verify result, Back up now, schedule and retention, the weekly
  restore-verify result; restore points to the launcher command.
- **Settings → Kiro sign-in:** unchanged flow (device code, open URL), now Genesis-owned (52-08).
- **Run Detail:** the turn explorer (ADR-066) shows per turn `runtime`, sandbox id, image digest, policy hash, limits,
  peak resources, termination reason; an **Egress** tab lists allowed and denied hosts with reasons and the drop
  counts; MCP calls show refused calls.
- **Testing → Record workflow:** the noVNC view embedded in the recording panel, with the Stop bar (51-01 D13).
- Tables sized from a real-browser width probe (L-090); `<Button asChild>` never used (L-069); new interactive UI has
  jest-axe tests; heavy viewers (noVNC) lazy-loaded (L-015).

## 3. Tests

Vitest for each surface with the 52-13 fixtures; jest-axe; the token bootstrap and 401 paths; `npm run build` and the
committed `web/static/` (stale-bundle guard, L-030, L-089).

## Context manifest

```toml
areas    = ["web-shell", "web-runs", "browser-testing", "security"]
adrs     = ["ADR-027", "ADR-028", "ADR-055", "ADR-066"]
lessons  = ["L-010", "L-011", "L-014", "L-015", "L-030", "L-069", "L-089", "L-090"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-13-api.md"]
code     = ["genesis/web/src/**", "genesis/web/static/**"]
upstream = ["52-13"]
```
