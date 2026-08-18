# 25-04 — Network-Exposure Guardrail (localhost-bind / no-auth intent)

- **Status:** ✅ BUILT (2026-08-18) — implemented + tested + committed locally; **NOT released** (ships via 25-14). · **Review items:** D-2 · **Roadmap:** Phase 0 · **Repos:** genesis · **Depends on:** nothing
- **As built:** `runtime/launcher.py` `is_loopback`/`bind_guard_error`/`bind_warning`; `genesis serve`/`up` **refuse** a non-loopback bind unless `--i-understand-no-auth` / `GENESIS_ALLOW_NON_LOOPBACK=1` (override logs a warning). Enforced in the serve + up CLI handlers; `docs/INSTALL.md` Security note updated. Commit `0a8f13f`. Backend **535** pytest (+13) + ruff green. **Deferred to 25-14:** the in-app preflight posture chip (needs bind-host plumbing — low value). Version held 0.48.7.

## 1. Goal
Make the **"local, single-user, no-auth" decision (ADR-026) explicit and enforced at the boundary**, so Genesis cannot be *accidentally* served on a non-loopback interface without a conscious, logged override. This is a **safety guardrail, not an auth implementation** — real AuthN/Z stays deferred (a separate track that re-opens ADR-026).

## 2. Why (review evidence)
- Review D-2: there is no authentication/authorization (deliberate for local use), but "the moment Genesis is exposed beyond localhost, this is a hard blocker." The review recommends an explicit localhost-bind + no-auth guard so it can't be silently served on `0.0.0.0`.
- The distribution launcher (`runtime/launcher.py`, Phase 22) already loopback-maps for `0.0.0.0/::`, but nothing *prevents* a user running `genesis serve --host 0.0.0.0` and exposing an unauthenticated app on their network.

## 3. Current state (cited)
- `genesis serve` / `runtime/launcher.py` bind host/port (default `127.0.0.1:8760`); `--host` is user-suppliable.
- No warning/guard when host is non-loopback; no security banner.

## 4. Design
### 4.1 Bind guard (fail-loud, override-able)
- On `serve`/`up`, if the resolved bind host is **not** loopback (`127.0.0.1`/`::1`/`localhost`):
  - **Refuse to start** with a clear error explaining Genesis ships **without authentication** (ADR-026) and is intended for localhost, **unless** the operator passes an explicit `--i-understand-no-auth` flag (or `GENESIS_ALLOW_NON_LOOPBACK=1`).
  - When overridden, log a prominent `warning` on every start ("serving an UNAUTHENTICATED app on <host>") — ties into 25-02 structured logging.
- Default behavior is unchanged (loopback → starts silently).

### 4.2 Preflight surfacing
- `runtime/preflight.py` (Phase 22) gains a check: "bound to loopback (no auth needed)" ✓ / "non-loopback bind with override" ⚠ so the in-app PreflightChecklist shows the posture.

### 4.3 Docs
- `docs/INSTALL.md` + README gain a short **Security posture** note: local single-user, no auth by design, do not expose beyond localhost; if you must, put it behind your own authenticating reverse proxy.

## 5. Files touched
- **Edit:** `runtime/launcher.py` (bind guard + flag), `cli/main.py` (`serve`/`up` flag + env), `runtime/preflight.py` (posture check), `api/system.py` (surface posture in `/system/preflight`), `docs/INSTALL.md`, `README.md`.
- **New:** `tests/test_bind_guard.py`.

## 6. Tests
- Loopback host → starts, no warning.
- Non-loopback host, no override → refuses with the documented message (exit non-zero).
- Non-loopback + override flag/env → starts, emits the warning log, preflight shows ⚠.

## 7. Risks & mitigations
- **Risk:** breaks a user intentionally binding `0.0.0.0` (e.g. WSL). **Mitigation:** the override flag/env is documented and one step; the guard is a speed-bump, not a wall.

## 8. Out of scope
Actual authentication/authorization, TLS, reverse-proxy config, multi-user (all re-open ADR-026 — a separate future track).

## 9. Definition of Done
Non-loopback bind refuses without an explicit override; override logs a warning + shows in preflight; docs updated; tests green; genesis release CI-green; progress doc. (ADR-026 amended with the guardrail note in `bible/04`.)
