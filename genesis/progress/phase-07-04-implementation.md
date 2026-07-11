# Genesis — Phase 7.4 (Web Revamp: Settings & Configuration) Implementation Record

> As-built record of `specs/phase-07-04-settings-configuration.md`. First real screen
> of the web revamp — establishes the data-access layer (lib/api + lib/query +
> TanStack Query) that all later screens build on. Part of milestone M7.1.

**Date:** 2026-07-11 · **Status:** ✅ COMPLETE — backend released (**genesis v0.8.0**,
51 pytest + ruff, CI green); frontend committed `9655fb0` (18 web tests, tsc strict,
**frontend + genesis CI green**). Built **alongside** the interim app (served `static/`
untouched — cutover is 07-10).

---

## 1. Summary

The `/settings` screen now renders live integration status and lets the user configure
everything the platform needs to run — MCP servers (master-detail with write-only
secrets + readiness test), CLI availability, the global GitLab token, credential-free
environments (full CRUD), and storage usage — composing the 07-03 design system over
the 07-02 data plane plus two new backend endpoints added this phase.

This phase also stands up the **frontend data-access layer** (`lib/api`, `lib/query`,
TanStack Query, react-hook-form + zod) per `phase-07-01 §4`, which every subsequent
screen (07-05..09) reuses.

---

## 2. Backend (genesis) — the contract gap closed

The 07-04 spec assumed two endpoints that **07-02 had deferred**; they were implemented
here (approved as "Option A"):

- **`GET /config/cli-cards`** — one card per installed workflow's `required_cli`, resolved
  from `cli-registry.json`, with a PATH-availability probe (`shutil.which`). Status
  `available | missing`. (`fields.CliCard` + `fields.cli_cards()`,
  `ConfigService.cli_registry/installed_clis/cli_cards`.)
- **`POST /config/mcp-cards/{server}/test`** — a **lightweight readiness probe**, not a
  live container handshake: verifies (a) the server is known, (b) all required secrets
  are set, (c) if the server launches via docker, that docker is on PATH. Returns
  `{server, ok, reason, checked_at}`; never returns a secret value.
  (`ConfigService.test_server`.) The true ACP/container connection test (needs local
  Kiro + docker, not CI-verifiable) remains a deferred item.

`ConfigService.installed_servers` was refactored to share a generic
`_installed_requirements(attr)` with the new `installed_clis`. App title synced to 0.8.0.

**Tests:** `tests/test_config.py` +3 (`test_cli_cards_availability`,
`test_server_readiness_probe`, `test_config_endpoints_via_api`) → **51 passed**, ruff clean.
Released **genesis v0.8.0** (additive minor; genesis-core pin unchanged at v0.4.0). CI green.

---

## 3. Frontend (`genesis/web`)

**Data-access layer (new, reused by all later screens):**
- `types/config.ts` — backend-contract types (McpCard, ConfigField, CliCard, TestResult,
  EnvironmentsMap/Input, GitlabTokenStatus, HealthCheck, ArtifactsUsage). Secrets are
  represented by key + set/unset only, never by value.
- `lib/api/{client,config,index}.ts` — typed `fetch` wrapper with `ApiError` (unwraps
  FastAPI `{detail}`), plus the `configApi` resource module. Presentation never calls
  `fetch`; hooks never hard-code URLs.
- `lib/query/{client,keys,index}.ts` — shared `QueryClient` + centralized `qk` key
  factory. `providers.tsx` now wraps the app in `QueryClientProvider`.

**Feature (`features/settings/`):**
- `hooks.ts` — `useMcpCards/useCliCards/useHealth/useGitlabTokenStatus/useEnvironments/
  useArtifactsUsage` + mutations `useSetSecret/useSetGitlabToken/useTestServer/
  useUpsertEnvironment/useRemoveEnvironment`, each invalidating the right keys + toasting.
- `SettingsPage.tsx` — anchored sections (Integrations MCP, CLIs, GitLab, Environments,
  Storage). `/settings/:server` deep-links a selected server; `/settings/environments`
  scrolls to that section.
- `components/McpSection.tsx` — **master-detail** (03a): searchable list panel with
  StatusDot rows (attention-first sort) + selected-server detail. Empty state → Catalog.
- `components/McpServerDetail.tsx` — header (name + status + Test/Save), read-only
  Configuration, and a **write-only** secret/field form (react-hook-form + zod). Set
  secrets show `•••• set` and are never pre-filled; per-field `POST /config/secrets`
  (only changed fields); inline readiness-test result.
- `components/CliSection.tsx` — CLI availability cards.
- `components/GitlabSection.tsx` — global token set/replace (write-only) + unset warning.
- `components/EnvironmentsSection.tsx` — list + add/edit dialog (rhf+zod) + delete
  confirm; the server-side **credential-free 400** is surfaced inline in the dialog.
- `components/StorageSection.tsx` — artifacts usage MetricCard + retention note (purge
  deferred, disabled affordance).
- `settings.test.tsx` — **MSW**-backed: card status/attention-order, write-only secret
  save (asserts global scope + no value leak), readiness test result, env delete-confirm.

Icons added to the curated set: GitBranch, Globe, HardDrive, KeyRound, Pencil, Save,
Server, Trash2. Router wires `/settings`, `/settings/environments`, `/settings/:server`.

**New deps (public npm, per the expired-Artifactory workaround):** @tanstack/react-query,
react-hook-form, zod, @hookform/resolvers; msw (dev).

---

## 4. Verification

- Backend: `pytest` 51 passed, `ruff` clean; genesis **v0.8.0** tag CI green.
- Frontend: `tsc --noEmit` strict clean; `vitest run` **18 passed** (14 design-system +
  4 settings); temp `vite build` OK (Recharts chunk-size warning only); `git status`
  confirms **`static/` unchanged**. Frontend + genesis CI jobs **success** (commit `9655fb0`).

---

## 5. Decisions & honest deviations from the spec

- **Backend scope (approved Option A):** added the two missing endpoints rather than
  stubbing them in the UI, so the DoD is genuinely met.
- **"Test" = readiness probe, not live handshake.** A real ACP/container connection test
  needs local Kiro + docker and can't run in CI; explicitly deferred. The UI copy says
  "live connection not tested".
- **Secret "Clear"/unset omitted.** The backend has no delete-secret endpoint (only
  set/overwrite), so the drawer offers set/replace only. Filing unset as a follow-up.
- **"Allowed Tools" toggles omitted.** `trust_tools` are per-agent-node config, not
  server-level registry data — there's nothing to toggle at the server card. Documented
  as a non-applicable part of the 03a Overcut analogy.
- **Reachable/unreachable ring on cards** is not shown: mcp-card status is only
  `configured|missing_secret` (no persisted probe result); reachability surfaces
  transiently via the Test action instead.

---

## 6. Definition of done (07-04) — status

1. MCP + CLI cards with accurate live status and field chips — ✅.
2. Configure master-detail sets secrets/fields write-only, per-field save, deep-linkable
   (`/settings/:server`) — ✅ (Clear/unset deferred — no endpoint).
3. Connection Test works and reflects the result — ✅ (readiness probe; live handshake deferred).
4. GitLab token + environments (add/edit/delete, credential-free enforced) + storage
   display — ✅.
5. Loading/empty/error/success states + a11y (labels, dialog focus via Radix) + no secret
   value rendered/logged — ✅ (automated a11y intent; manual visual QA at `/settings` pending).
6. Component + MSW tests for card status, drawer save, and test action — ✅ (+ env CRUD).

---

## 7. Next

07-05 (Workflow Catalog & Install Management) — category chips + card grid, install/
update/remove, schema-driven launch — reusing this phase's `lib/api` + `lib/query`.
