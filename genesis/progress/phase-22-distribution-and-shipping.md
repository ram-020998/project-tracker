# Phase 22 — Distribution & Browser-Based Shipping (clone + git-tag) — as-built

> **Status:** ✅ SHIPPED + COMPLETE (22-01..22-07). **genesis v0.47.0** (`3f542c5`), CI green — pipeline **#6558223**
> (genesis + frontend + the new **clean-install**). **ADR-046** Accepted. genesis-only, no schema; genesis-core /
> kiro-agent-sdk / genesis-appian-parser / genesis-workflows unchanged.

## What shipped
Ship Genesis to internal users as a **local, browser-based** app — modeled on `appian/prod/friday`'s clone + venv + git-tag
self-update installer, but browser-based (no Mac `.app`), leveraging Genesis's single-port `genesis serve`. The user clones
only `genesis`; the three internal deps resolve from their `git+ssh` tag pins; `genesis-workflows` is pulled at runtime.

- **22-01 installer** — `scripts/install.sh`: prereq check (python3.13/git/kiro-cli) + **SSH-access preflight** (per-repo
  `git ls-remote`, clear per-repo error) → locate/clone → venv → `pip install .` → `genesis db upgrade` → scaffold
  `~/.genesis` + write `~/.genesis/dist.json` (repo_dir/branch/remote). Idempotent, shellcheck-clean.
- **22-02 launcher** — `genesis/runtime/launcher.py` is the single source of truth for **`genesis up/down/status/logs`**
  (background `serve` + health-wait + open browser; PID/log under `~/.genesis/run`; loopback-mapped for 0.0.0.0/::).
  `scripts/genesisctl.sh` rewritten as a thin wrapper.
- **22-03 updates** — `genesis/runtime/updater.py` (dist config, semver `highest_tag`, `check()`, `apply()` with on-branch
  guard + detached restart) + `api/system` `GET/POST /system/update` + **`genesis update`** CLI + a web **UpdateBanner** in
  `AppShell` (states: none / available→button / on-wrong-branch→blocked; apply → poll health → reload). **Tracked branch =
  `master`** (genesis's actual default — a `main` default would have broken clone + update-check).
- **22-04 Kiro auth** — `genesis/runtime/kiro_auth.py` (`whoami --format json` status / **pty** device-flow login [no `expect`
  dep] / logout) + `api/system/kiro*` + a **Settings → General "Kiro sign-in"** section. Real-CLI finding: logged-in `whoami`
  has no `account` key (`accountType`/`email`/`startUrl`) + trailing `Profile:` lines → parse the first JSON line + detect
  identity claims. Tokens never leave the server.
- **22-05 preflight** — `genesis/runtime/preflight.py` (`{items, ready}`: required kiro/db/health + optional dev-env/uv/gws) +
  `GET /system/preflight` + a dismissible **PreflightChecklist** modal in `AppShell` with per-item Fix→ links.
- **22-06 CI + release** — a **`clean-install`** CI job (fresh non-editable `pip install .` → `db upgrade` → boot via
  `genesis up --no-open` → status → down → shellcheck), and the **v0.47.0** release of the whole tree.
- **22-07 docs** — README quickstart + `docs/INSTALL.md` (shipped in v0.47.0) + the bible/decision-log/tracker refresh.

## Verification
- **Gate:** backend **437** pytest + ruff; web **160** Vitest + eslint + tsc + build; shellcheck — all green.
- CI pipeline **#6558223** green across genesis + frontend + clean-install.
- Verified live against the installed tooling where possible: `genesis up/status/down` end-to-end (isolated temp state dir +
  port); `genesis update --check-only` against the real remote (on master = tracked, update available); `kiro_auth.status()`
  → authenticated + email; `preflight.check()` → all-ok `ready:true`.

## Manual / deferred
- **Live acceptance is user-driven** (headless-undrivable): a clean-machine `install.sh` → `genesis up` → in-app Kiro
  device-flow sign-in → tag a release → the UpdateBanner appears → one-click apply → detached restart + reload.
- **Deferred:** the **wheel + package-index** transport (phase-2 alternative — recorded in the umbrella §9 / ADR-046);
  Windows-native beyond WSL; auto-apply updates; a Settings "re-open the setup checklist" entry.
