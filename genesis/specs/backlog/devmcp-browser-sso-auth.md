# Backlog — Dev MCP browser-based SSO authentication

> **Status:** 📝 BACKLOG (not scheduled — deferred deliberately). · **Created:** 2026-09-15 ·
> **Repo:** genesis (+ `genesis/config`, `genesis/mcp/native`, `genesis/api`, `web/features/settings`) +
> genesis-workflows (`mcp-registry.json` `appian-dev`).
> **Relates to:** ADR-038 (managed-native MCP), ADR-048 (env-scoped Appian creds), ADR-036/037 (read-only
> Dev MCP / code-free KB), the Dev MCP 26.6.90 upgrade (basic-auth-only integration shipped first).

## Context — why this is deferred
As of the Dev MCP **26.6.90** upgrade, Appian changed the **default auth method to browser-based SSO**
(Playwright + a captured session), keeping **HTTP basic** as an explicit opt-in (`LCP_AUTH_METHOD=basic`).
Genesis integrated **basic auth only** first (see the Dev-MCP-upgrade spec): we inject a **static
`LCP_AUTH_METHOD=basic`** on the `appian-dev` registry entry and drop `LCP_API_PATH` (the new bundle
defaults it). Our development environments do **not** use SSO, so basic is sufficient today, and browser
auth is a large, architecturally awkward piece for a **headless** server (see below). This doc captures
what a later browser-auth implementation must do so it can be picked up cold.

## Problem / goal
Let a Genesis user point the Dev MCP at an **SSO-only Appian site** (no basic auth accepted) by
authenticating **once via a browser** and reusing the captured session — **without** breaking Genesis's
headless, single-user, local posture (ADR-026) or its read-only Dev MCP contract (ADR-036/037).

## What the 26.6.90 bundle provides (verified from the bundle source)
- **Default `LCP_AUTH_METHOD=browser`.** `server.create_lcp_mcp_server` builds a `BrowserSessionAuth`
  (from `browser_auth.py`) instead of `httpx.BasicAuth`. The first tool call opens a real OS browser to
  `LCP_SIGNIN_PATH` (default `/suite/`), the user logs in (SSO/MFA), and the session cookie is captured +
  persisted to **`~/.appian-devmcp/cookies-<id>.json`** (+ a Chromium profile under
  `~/.appian-devmcp/browser-profile-<id>`). Reused across MCP restarts; on expiry the browser **reopens
  automatically mid-call** (up to a 5-minute login window).
- **Env vars (browser):** `LCP_URL` (required), `USERNAME` (optional — disambiguates the cookie store /
  multi-user), `LCP_SIGNIN_PATH` (skip the IdP chooser → e.g. `/suite/?signin=<idp>`),
  `LCP_AUTH_LANDING_PATH` (custom post-login landing page), `LCP_BROWSER_CHANNEL` (`chromium`|`chrome`|
  `msedge` — use a **system** browser to avoid the Chromium download), `LCP_COOKIE_PATH`,
  `LCP_BROWSER_PROFILE_PATH`. `PASSWORD` is **not allowed** under browser auth.
- **Deps:** `playwright>=1.40.0` (already a core dep of the bundle, pulled by `uv sync`) **plus** a
  one-time `uv run playwright install chromium` (~few hundred MB) **unless** `LCP_BROWSER_CHANNEL` points
  at an installed Chrome/Edge. The Dev-MCP-upgrade (basic) integration intentionally does **not** run the
  Chromium download.
- The **SAIL CLI** can consume a DevMCP-captured browser session via `sail login <host> --from-devmcp`
  (SSO), so browser auth also unlocks SAIL against SSO sites (today SAIL uses `SAIL_USERNAME`/`PASSWORD`).

## The hard problem: browser auth vs a headless server
Genesis uses the Dev MCP from **non-interactive** contexts:
- **workflow subprocess workers** (the four analysis workflows' `@appian-dev` grounding) — no user present;
- **`kb/dev_mcp.py`** direct-stdio calls (`listApplications` for the Applications page, live-code fetch for
  the KB) — run from the server process;
- **chat** (`@appian-dev`) — a user is present in the SPA, but the MCP's browser window is a **native OS
  window spawned by the server process**, not embedded in Genesis's UI;
- **scheduler jobs** — headless.

A browser popup that blocks up to 5 minutes (and **reopens on session expiry mid-run**) cannot drive an
automated workflow run. So browser auth needs a **one-time, user-initiated capture** that persists a
session the headless callers then reuse — plus a **re-auth signal** when the session expires (rather than
a silent mid-run browser popup inside a worker).

## Sketch (to refine when picked up)
- **Per-env auth method (config surface).** Add a public per-environment field **`lcp_auth_method`**
  (`basic` | `browser`, default `basic`) to `EnvironmentRegistry` (`_ALLOWED` + `resolve_var` →
  `LCP_AUTH_METHOD`) and surface it on the Settings → Environments form. This **replaces the static
  `basic` default** shipped with the 26.6.90 upgrade (which is registry-hardcoded and not user-editable).
  Add optional public fields `lcp_signin_path` / `lcp_auth_landing_path`. Update the `appian-dev`
  registry env to template `${LCP_AUTH_METHOD}` (+ the browser vars) instead of the static value.
- **One-time capture flow.** A Settings → Environments **"Authenticate (browser)"** action that launches
  the Dev MCP once to trigger the Playwright login and capture the cookie to `~/.appian-devmcp/` (mirrors
  our existing `integrations/gws/login.py` OAuth-capture + `runtime/kiro_auth.py` pty-login precedents).
  Persist to a **stable, per-env cookie path** (`LCP_COOKIE_PATH`) so every headless caller reuses it.
- **Chromium strategy.** Prefer `LCP_BROWSER_CHANNEL=chrome`/`msedge` (use the user's installed browser,
  no download, corporate-network friendly); optionally teach `NativeMcpInstaller` to run
  `uv run playwright install chromium` as an **opt-in** step when a system browser isn't available.
- **Expiry handling.** Detect the "session expired / re-auth needed" signal from the MCP and surface a
  **re-authenticate prompt in the UI** for interactive (chat) use; for workflow/KB use, fail fast with an
  actionable "re-authenticate the dev environment (browser)" message rather than letting a worker hang on
  a silent browser popup. Consider gating browser-auth Dev MCP to **interactive contexts** and keeping a
  basic-auth path for automated grounding + KB sync (a per-context policy).
- **SAIL under SSO.** Wire `sail login <host> --from-devmcp` (+ `--user`) to import the captured DevMCP
  session, as the SSO alternative to `SAIL_USERNAME`/`SAIL_PASSWORD`.
- **ADR.** Amend ADR-048 (or a new ADR) to record the per-env auth-method model + the capture flow +
  the interactive-vs-headless policy.

## Notes / open questions
- **Fleet (`genesis-fleet`/`gsm`)** seeds each instance's dev env + `env-*` creds for basic auth; a
  browser-captured session is per-machine under `~/.appian-devmcp/` — decide whether/how multiple
  instances on one machine share or isolate the cookie (`LCP_COOKIE_PATH` per instance).
- Browser auth reopening the browser **mid-tool-call** is the core UX risk for any automated caller —
  the interactive-vs-headless policy above is the load-bearing decision.
- Security posture unchanged: still read-only (our allowlist), still local single-user (ADR-026); the
  captured cookie is a session secret on disk under `~/.appian-devmcp/` — reference by path, never log it.
- Revisit whether `LCP_TOOL_MODE=readonly` (documented by Appian but **not implemented** in 26.6.90) lands
  in a later bundle — if it does, it complements our allowlist as a second read-only guard.
