# 22-04 — In-app Kiro authentication

> **Status:** 📝 DRAFT · **Phase:** 22 · **Repo:** genesis · **Depends on:** 22-02

## Goal
Let a fresh user authenticate `kiro-cli` from inside the browser app — it is the execution engine, so "logged into Kiro" is a
hard prerequisite. Friday drives the device/SSO flow from its launcher; we do the equivalent via `api/system`.

## API (`api/system`, localhost-only)
- `GET /api/system/kiro` → `{ authenticated: bool, email?: str, mode: "sso"|"builder"|... }` (derive from `kiro-cli`'s status
  output; never surface tokens).
- `POST /api/system/kiro/login` → start `kiro-cli login` (device/SSO). Return the **verification URL + user code** for the SPA
  to display; poll to completion (or stream status). Fail-closed on timeout.
- `POST /api/system/kiro/logout` → `kiro-cli logout`.

## Web
- A **Settings → Kiro** panel (and a first-run prompt from 22-05) showing: authenticated status + email, a **Sign in** button
  that opens the verification URL + shows the code, and **Sign out**. Poll status until connected.

## Security / safety
- Read-only status + a bounded login/logout flow — no token ever leaves the server; reference by presence/email only.
- Consistent with ADR-045: local, user-initiated auth action; nothing touches shared systems.

## Acceptance
- From a fresh, unauthenticated state: the panel shows "not signed in" → Sign in → completing the device flow flips it to
  signed-in with the email; Sign out reverses it. Chat/workflows then work.

## Tests
- API tests with the `kiro-cli` invocation mocked (status parse, login-URL surfacing, logout). Web: panel states + jest-axe.
- The real device-flow round-trip is a manual acceptance step (headless-undrivable) — document it.

## Notes
- Reuse `kiro-cli`'s own login state (do NOT relocate `KIRO_HOME` — that also moves the user's agents/sessions/settings; see the
  Phase-14 skills lesson).
