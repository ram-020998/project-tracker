# 53-12 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-11-03. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-53-kiro-sdk-v3.md`. After 53-11 = SHIP. **genesis-release** asks before every tag and push; then
> **genesis-docs** does the write-back.

## 1. Release order (after Phase 51's release, D11)

1. **genesis** next minor after Phase 51's (expected **v0.82.0**; 53-03's migration, DB +1): version in
   `pyproject.toml` files of the app and the three packages (one shared version, ADR-080), `create_app`,
   `web/src/version.ts`; `npm run build` + commit `web/static/` as separate steps (L-089); verify the release commit has
   every changed file, including `tool_ids.json` and the v3 fixtures as package/test data (L-056, L-048); tag; push on
   the user's go-ahead; CI green (packages, genesis, frontend, clean-install).
2. **genesis-workflows** next minor: the `appian` skill (53-06) + its `skills-registry.json` entry; pins on the new genesis tag
   (`#subdirectory=packages/<name>`, gate 9, L-057); CI green.
3. Never read CI variables through the API (L-100).

## 2. Deploy

Never restart while a run is active. Fleet: `gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`;
install the `appian` skill from Settings → Catalog → Skills on each instance; verify `/openapi.json` `info.version` and
the DB version; `GET /api/system/kiro` shows a verified kiro-cli. User checklist in the release notes:

- kiro-cli at least the verified minimum (`kiro-cli update`).
- Global Kiro MCP servers (`~/.kiro/settings/mcp.json`) and personal skills (`~/.kiro/skills`) no longer appear in
  Genesis: add a server as a custom MCP server in Settings (the custom MCP tier, ADR-029); install skills from Settings → Catalog →
  Skills.
- Existing chats continue (first resume falls back to the preamble replay once; 53-07 §2).

## 3. Docs write-back (genesis-docs)

- **ADR-085** from `adr-drafts.md` (53-03 §2) via `genesis-ctx add adr --amends ADR-031,ADR-032,ADR-034,ADR-045,ADR-069`
  with areas `sdk-acp, chat, core-engine, config-secrets, security`.
- **Lessons** (candidates from As built sections; at least): v3 rejects the v2 trust flags over ACP; v3 MCP calls nest
  arguments under `rawInput.arguments` and arrive through `tool_load`; a custom agent's `tools` absent = no tools;
  verify `set_mode` activation; credits moved to `turn_completion`. Update **L-024** (sanctioned Genesis `KIRO_HOME`),
  **L-044 / L-046** (v3 methods), **L-016** (capture source) as amendments, not rewrites.
- **Areas:** map `genesis/genesis/runtime/preflight.py`, `runtime/kiro_auth.py`, `runtime/context.py` (no area today)
  and `genesis/packages/kiro-agent-sdk/tests/fixtures/**` to `sdk-acp`/`config-secrets` so `check` routes them.
- `context/state/current.md` (versions, DB version, test counts, "what works": v3 engine, Genesis Kiro homes, steering,
  resume, managed skills only), code map, `progress/phase-53-kiro-sdk-v3.md`, `changelog.md`, README row 53 →
  SHIPPED, tracker §6, and `specs/backlog/phase-53-follow-ups.md` (umbrella §9 Deferred list + build findings).
  `genesis-ctx index && lint` green.

## As built

_To be filled by genesis-release (As run) and genesis-docs._

## Context manifest

```toml
areas    = ["release-ci", "distribution", "workflows-library"]
adrs     = ["ADR-019", "ADR-046", "ADR-077", "ADR-080"]
lessons  = ["L-030", "L-048", "L-056", "L-057", "L-089", "L-098", "L-099", "L-100"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3.md", "tracker:agent-system/skills/genesis-release/SKILL.md", "tracker:agent-system/skills/genesis-doc-writeback/SKILL.md"]
code     = ["genesis/pyproject.toml", "genesis/packages/kiro-agent-sdk/pyproject.toml", "genesis-workflows/registry.json", "genesis-workflows/skills-registry.json", "genesis-workflows/skills/**"]
upstream = ["53-11"]
```
