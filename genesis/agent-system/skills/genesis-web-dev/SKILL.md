---
name: genesis-web-dev
description: Use when changing the Genesis React+TypeScript SPA (genesis/web) — the web gates, building and committing web/static, design tokens (not raw hex), jest-axe accessibility, both themes, and the component reuse rules. For the genesis-dev agent.
---

# Web development (React + TypeScript SPA)

Full rules: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-027` and `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-055` (Overcut visual language, design tokens),
plus `{{GENESIS_HOME}}/bin/genesis-ctx area web-shell`. Conventions live in `{{TRACKER}}/bible/05-dev-loop-and-release.md` (web section).

## Rules
- Reuse existing primitives (shadcn/Radix, the Overcut components); don't re-implement a button/dialog/card.
- Use **design tokens**, never raw palette hex (`#4f46e5` etc.). Colors come from the token layer; support **both
  themes** (light + dark).
- Accessibility is a gate: components pass **jest-axe**; label controls; keyboard reachable; honour roles/aria.
- Do not use `<Button asChild>` (banned pattern — compose explicitly).

## Build + commit web/static (do not skip)
When you change the SPA, rebuild and commit the built assets the backend serves:
`cd {{REPOS}}/genesis/web && npm run build`, then commit the regenerated `web/static` (or the repo's built-assets
path) in the SAME commit as the source. A release that ships stale `web/static` is a known regression.

## Gates
- `cd {{REPOS}}/genesis/web && npx tsc --noEmit` (types), `npx eslint .` (lint), `npx vitest run` (unit + jest-axe).

## Regression rule
New UI behaviour gets an RTL/vitest test; a fixed bug gets a failing-then-passing test; a11y-sensitive components get a
jest-axe assertion.
