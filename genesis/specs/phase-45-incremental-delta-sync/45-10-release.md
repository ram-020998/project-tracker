# 45-10 — Release

> **Status:** ✅ SHIPPED 2026-10-13 (see the as-built section). Repos: genesis-appian-parser, genesis, genesis-workflows. Parent:
> `specs/phase-45-incremental-delta-sync.md`. Release only on the user's explicit go-ahead.

## 1. Order (ADR-019)

1. **genesis-appian-parser v0.3.0** — tag, push, CI green.
2. **genesis v0.76.0** — re-pin the parser to v0.3.0; bump `pyproject` + FastAPI version + `web/src/version.ts`;
   rebuild + commit `web/static`; tag, push, CI green (genesis + frontend + clean-install → fresh DB **v23**).
3. **genesis-workflows v0.21.0** — `sync-application` v0.3.0 + `listObjects` allowlist; re-pin **genesis v0.76.0**
   (fixes the stale v0.73.0 dev pin) + genesis-core v0.9.8; `validate_library` + pytest; tag, push, CI green.

genesis-core, kiro-agent-sdk and the Genesis Hub are unchanged.

## 2. Deploy

- Host: install the 26.6.110 bundle (Settings → MCP or `genesis mcp install-native appian-dev <bundle>`).
- `gsm provision --all --no-mcp --no-env --force` (new workflows library), `gsm restart --all`.
- Designate **`main`** for scheduled syncs (umbrella Q2): Settings → General → Application sync → "Run scheduled
  syncs on this machine" on `main` only; `userb` stays off and auto-pulls.

## 3. Docs

ADR-073/074 → Accepted (decision-log + bible/04; ADR-038/047 amendments noted); bible/01 (state + tags + DB v23),
bible/03 (new modules), bible/08 §9 SHIPPED, bible/06 any new lessons, bible/00 + AGENT_ONBOARDING banner, tracker §6,
README row, spec status SHIPPED, `progress/phase-45-incremental-delta-sync.md`. Update
`backlog/phase-16-deferred.md` §1.3 (true incremental delta → delivered) and `backlog/kb-resync-after-implementation.md`
(now cheap).

## 4. As run (2026-10-13)

1. **genesis-appian-parser v0.3.0** — `10e412a` (incl. the 45-09 F2 Decision-hash fix), tag `v0.3.0`; CI #7059369 green.
2. **genesis v0.76.0** — `a19b7cf` (parser re-pinned to v0.3.0; pyproject + FastAPI + `web/src/version.ts`; `web/static`
   rebuilt); tag `v0.76.0`; CI #7059384 (master) + #7059385 (tag: genesis + frontend + clean-install) green.
3. **genesis-workflows v0.21.0** — `e98b39c` (re-pins genesis v0.76.0 + core v0.9.8; `registry.json`
   `genesis_core_version` 0.9.7 → 0.9.8 to match the pin); tag `v0.21.0`; CI #7059427 + #7059428 green.
4. **Deploy:** host Dev MCP 26.6.110 (already installed in 45-02); `gsm provision --all --no-mcp --no-env --force` +
   `gsm restart --all` → both instances genesis **0.76.0**, sync-application **0.3.0**; **`main` designated**
   (run_on_this_machine on, every 4 h); userb off (auto-pulls). RU Sandbox untracked on main (gone from the env, F3).

