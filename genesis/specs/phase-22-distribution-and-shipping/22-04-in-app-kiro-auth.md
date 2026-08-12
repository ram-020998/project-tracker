# 22-04 — In-app Kiro authentication

> **Status:** ✅ CODE-COMPLETE (2026-08-12; genesis code **held for the v0.47.0 release** at 22-06/07) · **Phase:** 22 ·
> **Repo:** genesis · **Depends on:** 22-02 (uses 22-04 for the Kiro row)
>
> **As built:** `genesis/runtime/kiro_auth.py` — `status()` (parse `kiro-cli whoami --format json`),
> `logout()` (`kiro-cli logout`), and a device-flow `start_login()` driven over a **stdlib `pty`** (no `expect` dep) in a
> background thread + a pollable `login_status()` state machine (pending→connected/failed; scrapes the `Code:` + URL). Routes on
> `api/system`: `GET /system/kiro`, `POST /system/kiro/login`, `GET /system/kiro/login`, `POST /system/kiro/logout`. Web:
> `lib/api/system.ts` kiro fns + a **Settings → General "Kiro sign-in" section** (`KiroSection`: status + Start-URL/Region
> sign-in form surfacing the device code + verification link + Sign out). **Real-CLI finding:** this kiro-cli's logged-in
> `whoami` JSON has **no `account` key** (it has `accountType`/`email`/`startUrl`) and trailing non-JSON `Profile:` lines — the
> parser now reads the first JSON line and detects identity claims (a naive `account is None` check falsely reported logged-out;
> caught against the real binary). **Verified:** 8 kiro_auth tests + 4 KiroSection tests (mocked/jest-axe); real `status()` on
> this machine → authenticated + email; full backend **433** + web **158** green; ruff/eslint/tsc clean. Device-flow round-trip
> is manual-verify (headless-undrivable). Tokens never leave the server.

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
