---
name: genesis-api-dev
description: Use when adding or changing a Genesis HTTP endpoint or its web client call — the /api router rules, client /api prefixing, contract fixtures and web/src/types parity, and 409/CAS conventions. For the genesis-dev agent.
---

# API development

Full rules: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-028` (namespaced /api + SPA fallback) and the API lessons for your change
(`{{GENESIS_HOME}}/bin/genesis-ctx area api` lists them; read the full text with `{{GENESIS_HOME}}/bin/genesis-ctx lesson <id>`).

## Rules
- EVERY backend route lives under `/api` via an `APIRouter` in `{{REPOS}}/genesis/genesis/api/app.py`; keep the SPA
  history fallback intact.
- The web client prepends `/api` **centrally** — never hard-code `/api` in a component. The Vite dev proxy is a single
  `/api` → the backend port.
- Keep the request/response contract and `{{REPOS}}/genesis/web/src/types` in parity; update the contract fixtures when
  you change a shape, and regenerate/adjust the TS types in the same change.
- Concurrency: use the project's CAS / `409 Conflict` convention for optimistic updates (don't invent a new one —
  `{{GENESIS_HOME}}/bin/genesis-ctx search "409" --archive` for precedent).

## Gates
- Backend: `{{REPOS}}/genesis/.venv/bin/python -m pytest -q` (API tests + contract fixtures).
- Web: `cd {{REPOS}}/genesis/web && npx tsc --noEmit` and `npx vitest run` for the touched client code.

## Regression rule
A changed contract gets a contract-fixture update and a test; a new endpoint gets request/response tests including the
error/conflict path.
