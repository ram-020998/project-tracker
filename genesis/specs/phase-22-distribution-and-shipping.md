# Phase 22 — Distribution & Browser-Based Shipping (clone + git-tag) (umbrella)

> **Status:** ✅ **SHIPPED — COMPLETE (22-01..22-07)** — genesis **v0.47.0** (`3f542c5`), CI green (genesis + frontend +
> clean-install); ADR-046 Accepted. genesis-only, no schema. · **Author:** Genesis agent · **Date:** 2026-08-12
> **Goal:** Give Genesis a **working, standard way to ship to internal users** as a **local, browser-based** app — install
> once, launch with one command that opens the workbench in the user's default browser, and **update in place from release
> tags**. Explicitly **not** a native desktop (Mac `.app`) build, **not** Docker, **not** a hosted service. Modeled on
> `appian/prod/friday`'s clone + git-tag self-update installer, adapted to Genesis's **single-port** (`genesis serve` = API +
> committed SPA) and **single-user/localhost** design (ADR-026), and dropping Friday's native launcher in favor of "open the
> browser."
> **Repos:** **genesis only** (installer scripts under `scripts/`, a small read-only `api/system` surface, a web update banner
> + Kiro-login/preflight panels, and CLI subcommands). genesis-core / kiro-agent-sdk / genesis-appian-parser / genesis-workflows:
> **unchanged**. **No schema change** (no new migration).
> **Non-negotiable framing:** stays **local single-user, localhost-only, no auth** (ADR-026/031) — shipping must not expose a
> network service. The install/update transport is **clone + `git+ssh` + tag checkout** (users already have GitLab SSH); a
> **wheel + package-index** transport is explicitly **deferred** (see §8 / ADR-046 and §9).

---

## 0. TL;DR

Genesis already runs in the browser (`genesis serve` → SPA + API on one localhost port, `web/static` committed so users never
build the frontend). What's missing is the **distribution wrapper**: how a user gets it installed, launches it, keeps it
current, and authenticates Kiro. This phase adds that wrapper — no product features, no schema, genesis-only.

1. **Install once (`scripts/install.sh`)** — preflight prerequisites + **SSH access to all four repos**, clone `genesis`,
   create the venv, `pip install .` (the three internal deps resolve automatically from their `git+ssh` tag pins — the user
   clones only `genesis`), run `genesis db upgrade`, scaffold `~/.genesis`. Idempotent; safe to re-run.
2. **Launch that opens the browser (`genesis up`)** — start `genesis serve` in the background (PID + log under
   `~/.genesis/run`, promoting today's `scripts/genesisctl.sh`), wait for `/api/config/health`, then open the default browser
   at `http://127.0.0.1:8760`. Plus `genesis down` / `genesis status` / `genesis logs`.
3. **In-app updates from release tags** — a read-only check compares the highest `vX.Y.Z` tag on the tracked remote against the
   deployed version; the SPA shows an **"Update available → vX.Y.Z"** banner. Applying runs `genesis update`: fetch tags →
   (guard: on the tracked branch) → checkout the tag → `pip install .` → **`genesis db upgrade`** → restart → record the
   deployed version.
4. **In-app Kiro auth** — a first-run / Settings panel that drives `kiro-cli login` (device/SSO), shows login status, and
   supports logout. `kiro-cli` present + authenticated is a hard prerequisite (it is the execution engine).
5. **First-run preflight** — a screen backed by the existing `/api/config/health` + dev-env check that verifies `kiro-cli`
   present+authed and the DB migrated (and, for Appian features, an optional dev-tagged environment / `uv` / `gws` dotfiles),
   guiding the user into the existing Settings UI to fill gaps.
6. **CI clean-install verification + release** — a CI job that proves a **clean clone installs, migrates, and boots**; the
   existing tag protocol (bump + tag + push) becomes the shippable release.
7. **Docs** — a one-page "Install & Run Genesis" guide (prereqs, install, launch, update, security note).

**No LangGraph, no new MCP, no schema.** The only genuinely new runtime code is a tiny **read-only `api/system`** surface
(update-check, Kiro status/login, preflight) + a small web banner/panel + the installer/updater shell scripts + `genesis` CLI
subcommands. Everything else already exists.

---

## 1. Motivation & context

The user wants to ship Genesis to internal users **in a browser** (no Mac app), with a **standard, working** install/update
story. Today Genesis has only a **developer** setup (editable sibling-repo installs) + a **release protocol** (bump version +
tag + push to internal GitLab) + CI that **only tests** — there is **no ship-to-users path**.

`appian/prod/friday` (same architecture: LangGraph + Kiro CLI + FastAPI + a built frontend) solves the identical problem with a
**clone + venv + git-tag self-update** installer, wrapped in a native macOS `.app`. We adopt Friday's **transport and update
model** and **drop the native launcher** — Genesis serves the SPA + API on **one** port, so "open the browser" is simpler and
matches the requirement. We also reuse Friday's good ideas: a **deployed-version state file**, **update-scope** detection, an
**on-tracked-branch guard**, and **in-app Kiro login/status**.

**What already exists (so scope is small):** `genesis serve` (single-port, browser-based); committed `web/static` (no Node for
users); `scripts/genesisctl.sh` (start/stop/status/logs/**open**); `genesis db upgrade`; `/api/config/health` + the dev-env
readiness check; the Settings UI. **New work:** `install.sh`, a first-class `genesis up` (start + open browser), the
update-check API + banner + `genesis update`, the in-app Kiro-login panel, the preflight screen, a CI clean-install verify, and
the install doc.

---

## 2. The distribution model (decided shape)

**Clone the `genesis` repo → venv → `pip install .` → `genesis up`.** Concretely:

- **One clone.** The user clones only `genesis`. The three internal dependencies (`genesis-core`, `kiro-agent-sdk`,
  `genesis-appian-parser`) are `git+ssh` **tag pins** in `pyproject.toml`, so `pip install .` fetches them automatically. The
  requirement is **SSH read access** to all four repos, not four clones. `genesis-workflows` is **not** a pip dependency — it's
  pulled at runtime by `genesis install` into `~/.genesis/library`.
- **No frontend build for users.** `web/static` is committed and served by the backend; users never run Node/npm.
- **Update = re-point the single clone.** `git fetch --tags` → checkout the target tag → `pip install .` (re-resolves any
  bumped dependency tags) → `genesis db upgrade` → restart. Only the one clone is ever touched.
- **Browser, not a window.** No native launcher. `genesis up` backgrounds the server and calls the OS "open URL" (`open` on
  macOS, `xdg-open` on Linux) at `http://127.0.0.1:8760`.
- **Platforms:** macOS + Linux via bash (the scripts). Windows via WSL (documented, not a native path).

**Why clone+tag over wheel+index (the alternative):** clone+tag reuses the SSH access users already have (no per-user package
index token), needs no publishing pipeline, and reuses `genesisctl.sh` + `genesis db upgrade` that already exist — ~0.5–1 day
of net-new work. **wheel + package-index** (~2.5–4 days: 4 wheels incl. bundling `web/static`, converting `git+ssh` pins →
version specifiers, standing up a GitLab/Artifactory PyPI index, publish CI in 4 repos, per-user index auth) is "more standard
packaging" but front-loaded and adds recurring token friction. It is captured as a **deferred phase-2 transport** (§9) — the
launcher/updater/preflight/Kiro-login work is shared, only the transport swaps.

---

## 3. Sub-phases & build order

| # | Sub-phase | What ships |
|---|---|---|
| **22-01** | **Installer / bootstrap** | `scripts/install.sh` (or `genesis setup`): prereq + SSH-access preflight → clone/locate → venv → `pip install .` → `genesis db upgrade` → scaffold `~/.genesis` → print next steps. Idempotent. |
| **22-02** | **Launch + open browser** | Promote `genesisctl.sh` to first-class `genesis up` / `down` / `status` / `logs`: background `genesis serve`, wait for health, open the default browser. |
| **22-03** | **Update check + apply** | Read-only `GET /api/system/update`; web **update banner**; `genesis update` (tag-based, on-branch guard, `db upgrade`, restart, deployed-version state file). |
| **22-04** | **In-app Kiro auth** | `api/system` Kiro status/login/logout (device/SSO flow) + a Settings → Kiro panel showing login + status. |
| **22-05** | **First-run preflight** | A first-run screen over `/api/config/health` + dev-env check (kiro-cli authed, DB migrated, optional Appian env/uv/gws) that routes the user into Settings. |
| **22-06** | **CI clean-install verify + release** | A CI job that clones fresh, installs, migrates, and boots the app (assert `/api/config/health`); the tag becomes the shippable release. |
| **22-07** | **Docs + ship** | One-page "Install & Run Genesis" guide (prereqs, install, launch, update, security note); release + bible refresh. |

**Suggested order:** 22-01 → 22-02 (a user can install + launch) → 22-05 preflight → 22-04 Kiro auth → 22-03 updates →
22-06 CI verify → 22-07 docs. (22-04/05 can swap; 22-03 depends on 22-02's control scripts.)

---

## 4. Command & API contracts (to finalize in the sub-specs)

**Shell / CLI**
- `scripts/install.sh [--dir <path>] [--branch main]` — bootstrap; **preflights `git ls-remote` against each dependency repo**
  and fails with a clear "your SSH key lacks access to `<repo>`" message rather than an opaque pip error. Re-runnable.
- `genesis up [--host H] [--port P] [--no-open]` — start (background, PID/log under `~/.genesis/run`), wait for
  `/api/config/health`, open the browser. `genesis down` / `genesis status` / `genesis logs`. (Thin CLI wrappers over the
  hardened `genesisctl.sh` logic, so both a script and a `genesis` subcommand work.)
- `genesis update [--check-only]` — `git fetch --tags` → resolve highest `vX.Y.Z` → **guard: must be on the tracked branch**
  (else instruct `git checkout main`) → checkout tag → `pip install .` → `genesis db upgrade` → restart → write
  `~/.genesis/deployed_version`.

**Read-only `api/system` (new, unauthenticated-localhost, no mutations to project state)**
- `GET /api/system/update` → `{ current, latest, update_available, on_tracked_branch, scope }` where `scope ∈ {code, deps}`
  (deps = a dependency pin moved → `pip install` needed; code = pure app code). The SPA polls this (e.g. on load + every N min)
  and renders the banner.
- `POST /api/system/update` → triggers `genesis update` server-side, streams progress, then **detached-restarts** the server;
  the SPA reloads when health returns (resolved §10.1 — one-click).
- `GET /api/system/kiro` → `{ authenticated, email?, mode }`; `POST /api/system/kiro/login` (device/SSO), `POST …/logout`.
- `GET /api/system/preflight` → aggregates `/api/config/health` + dev-env check into a first-run checklist.

**State**
- Deployed version resolved from: `~/.genesis/deployed_version` → the installed package version → `0.0.0` (forces first-run
  update visibility). Tracked branch + remote configured in a small `genesis`-side config (analogue of Friday's `friday.config`).

---

## 5. Prerequisites (documented + preflighted)

- **Required:** Python **3.13**, **git** + **SSH access** to the four GitLab repos, **`kiro-cli`** installed + authenticated.
- **Optional (feature-gated):** a dev-tagged Appian **environment** + **`uv`** + the managed-native MCP bundles (Appian KB /
  Business Map / Documents features); **`gws`** dotfiles (`~/.config/gws/client_secret.json`) for the Document Library.
- **Not required:** Node/npm (frontend ships prebuilt), Docker, an internet-facing host.

---

## 6. Security posture (unchanged, stated explicitly for shipping)

Local single-user, **localhost bind only**, **no authentication** (ADR-026/031). The install doc must state plainly: **do not
expose Genesis on a network / public interface.** The new `api/system` endpoints are **read-only introspection + local process
control**; `POST /api/system/update` (if built) mutates only the local install and is a local-only action (consistent with the
ADR-045 posture — safe/local actions are fine; nothing here touches shared systems).

---

## 7. Non-goals / deferred

- **Native desktop app** (Friday's Swift `.app` / dock launcher) — explicitly out; browser-based only.
- **Docker / container image** — poor fit (the app drives the host's `kiro-cli`, native-MCP `uv` installs, `gws` dotfiles + the
  user's credentials). Out.
- **Wheel + package-index transport** — deferred phase-2 (see §8). The launcher/updater/preflight/Kiro-login work is transport-
  agnostic and would carry over.
- **Windows-native** install — WSL only, documented.
- **Multi-user / hosted / auth** — remains the separate future track (ADR-026); not opened here.
- **Auto-apply updates** — updates are user-initiated (banner/button), never silent.

---

## 8. Decision record (ADR-046 — to be added to the decision log on approval)

- **ADR-046 (PROPOSED) — Genesis ships as a local, browser-based app via clone + git-tag self-update.** Distribution =
  clone the `genesis` repo + venv + `pip install .` (internal deps resolve via their `git+ssh` tag pins; one clone), launched
  by `genesis up` which opens the default browser at the localhost server, and updated in place by checking out release tags
  (`git fetch --tags` → checkout → `pip install .` → `genesis db upgrade` → restart). **Not** a native app, **not** Docker,
  **not** hosted. Rationale: matches the local single-user/localhost design (ADR-026), reuses existing pieces (`genesisctl.sh`,
  `genesis db upgrade`, committed `web/static`, `/api/config/health`), and reuses the SSH access users already have — no package
  index or per-user token. **A wheel + package-index transport is a deferred alternative** (adopted only if we later need to
  remove the git-clone requirement); the launcher/updater/preflight are transport-agnostic. Refines ADR-026's "how it runs" with
  a concrete "how it ships." Preserves ADR-031/045 (read-only + human-confirmed; the new `api/system` surface is local
  introspection + local process control only).

---

## 9. Wheel + index (deferred transport — recorded, not built)

If/when a package-index transport is wanted: build 4 wheels (bundle `web/static` into the genesis wheel — verify hatchling
`force-include`), convert `git+ssh` pins → version specifiers, publish to the GitLab PyPI Package Registry (or Appian
Artifactory) via a `publish` CI job in each repo (needs a package-registry-write token), and install/upgrade via
`uv tool install genesis` / `pipx`. ~2.5–4 days one-time + per-user index auth. Everything else in this phase (launch, update
UX, Kiro login, preflight, docs) is reused unchanged.

---

## 10. Decisions (resolved 2026-08-12)

1. **Update apply → server-side one-click.** Build `POST /api/system/update`: the banner's **"Update to vX.Y.Z"** button runs
   the update server-side (fetch → on-branch guard → checkout tag → `pip install .` → `genesis db upgrade` → **detached
   restart**) and the SPA reloads when the server comes back. (A small detached-restart helper re-execs `genesis up` so the
   request-serving process can exit cleanly.)
2. **`genesis up` → both.** A first-class `genesis up` / `down` / `status` / `logs` / `update` CLI subcommand set, wrapping the
   shared logic that `scripts/genesisctl.sh` also exposes (so a script-only environment still works).
3. **Version → genesis v0.47.0** (minor; additive, no schema).
4. **Docs home → the `genesis` repo** (README quickstart + `docs/INSTALL.md`); project-tracker keeps the spec/progress record.

---

## 11. Release & test plan

- **Repos:** genesis only. genesis-core / kiro-agent-sdk / genesis-appian-parser / genesis-workflows unchanged. **No migration.**
- **Version:** genesis **v0.47.0** (pending §10.4).
- **Tests:** unit-test the update-version comparison (semver tag vs deployed) + the `api/system` endpoints (mocked git/kiro);
  the **CI clean-install job** is the integration gate (fresh clone → install → `db upgrade` → boot → assert
  `/api/config/health`). Shell scripts get a lint pass (`shellcheck`) + a smoke run. Web: a test for the update banner states
  (none / available / on-wrong-branch) + jest-axe on the new panels. Full existing suites stay green; `web/static` rebuilt +
  committed for the banner/panels.
- **Acceptance (user-driven):** on a clean machine, `install.sh` → `genesis up` opens the browser → authenticate Kiro in-app →
  preflight all-green → tag a new release → the banner appears → `genesis update` lands it and restarts.
