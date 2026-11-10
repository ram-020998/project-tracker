# 53-08 — Readiness (kiro-cli version and v3) and skills cleanup

> **Status:** SPEC-DRAFTED 2026-11-03. Repo: **genesis** (`genesis/runtime/preflight.py`, `genesis/runtime/kiro_auth.py`,
> `genesis/skills/**`, `genesis/api/system.py`, `genesis/api/skills.py`). Parent: `specs/phase-53-kiro-sdk-v3.md`.
> Decisions: 53-01 D7, D8; F5.

## 1. Goal

Genesis tells the user, before anything fails, when kiro-cli is missing, too old or lacks the v3 engine; and the skills
code stops knowing about `~/.kiro/skills`.

## 2. Preflight (`runtime/preflight.py`)

- New required item `kiro-cli` (before `kiro` sign-in): from `kiro_agent_sdk.check_kiro()` (53-05 §4). States:
  missing ("Install kiro-cli: <official install link>"), too old ("kiro-cli <x> is older than <min>; run `kiro-cli
  update`"), no v3 engine (same remedy), ok. The minimum is the version 53-02 verifies (expected 2.37.1).
- An **optional** item `kiro-cli-verified`: ok when the installed version is in the verified list; otherwise "kiro-cli
  <x> has not been verified with this Genesis release; it should work — report problems." (warn, F5).
- Chat and runs refuse to start while the required item fails: chat returns the classified error on the first turn
  (`kiro_too_old` / `engine_missing`); a run fails at its first agent node with the same error (53-04 `errors.py`).
- Same `_item` shape and "optional = warning" convention as Phase 51's Node 20+ and Playwright Chromium items
  (`preflight.py:67-78`); the new items go before the `kiro` sign-in item without reordering the others (the web
  fixtures pin the order).
- `check_kiro()` runs `kiro-cli --version` and `kiro-cli acp --help` once and caches by binary path + mtime (no network).

## 3. Settings health

`GET /api/system/kiro` (`api/system.py:60-62`) adds `{version, minimum, verified, engine_v3}` beside
`{installed, authenticated, email?, start_url?}`; Settings → General's Kiro card shows the version and the warning.

## 4. Skills cleanup (D7, D8)

- `skills/store.py:55-63`: remove `personal_dir` (`:56-63`) and the shadowing computation (`:111`);
  `skills/model.py:72-74`, `:86`: remove `shadows_personal` (the API field is dropped; 53-09 records it).
- `api/skills.py`: keep `POST /skills/update` (`:100`) as is; it already reinstalls the latest library ref and closes live
  chat clients (`_reload`).
- Docstrings that say chat also sees `~/.kiro/skills` (`skills/__init__.py`, Phase 14 notes) are corrected.

## 5. Tests

Preflight with fake `kiro-cli` scripts (missing, too old, no v3, ok, newer unverified); `GET /system/kiro` shape;
skills list without `shadows_personal` (`tests/test_skills_store.py:158-161` asserts it today and is rewritten);
`POST /skills/update` happy path and "not in the library" (404).

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["config-secrets", "chat", "api", "distribution"]
adrs     = ["ADR-034", "ADR-046", "ADR-069", "ADR-026"]
lessons  = ["L-044", "L-098", "L-012"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md"]
code     = ["genesis/genesis/runtime/preflight.py", "genesis/genesis/runtime/kiro_auth.py", "genesis/genesis/api/system.py", "genesis/genesis/api/skills.py", "genesis/genesis/skills/**", "genesis/tests/test_skills_store.py"]
upstream = ["53-05"]
```
