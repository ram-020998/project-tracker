# 22-06 — CI clean-install verify + release

> **Status:** ✅ SHIPPED (2026-08-12) — **genesis v0.47.0** (`3f542c5`), CI green (pipeline #6558223: **genesis** +
> **frontend** + the new **clean-install** all success). · **Phase:** 22 · **Repo:** genesis · **Depends on:** 22-01..22-05
>
> **As built:** a `clean-install` CI job (`.gitlab-ci.yml`) — on changes to the distribution surface (scripts, pyproject,
> `api/system.py`, the `runtime/{launcher,updater,kiro_auth,preflight}.py`, migrations, CI) it does a **fresh non-editable
> `pip install .`** (git+ssh deps via the ssh→https rewrite), `genesis db upgrade` into a throwaway `GENESIS_STATE_DIR`, boots
> via **`genesis up --no-open`** (waits for health, exits non-zero if unhealthy), `status`, `down`, then `shellcheck scripts/*.sh`
> + `install.sh --help`. **Released** the whole Phase-22 tree as **v0.47.0** (bumped `pyproject` + `api/app.py`; committed
> installer/launcher/updater/kiro-auth/preflight + `api/system` + web banner/panels + rebuilt `web/static` + the CI job + docs).
> **Pre-release gate:** backend **437** pytest + ruff; web **160** vitest + eslint + tsc + build; shellcheck — all green.
> genesis-core / kiro-agent-sdk / genesis-appian-parser / genesis-workflows unchanged (no coordinated release).

## Goal
Guarantee that "a fresh clone installs, migrates, and boots" — the real integration gate for shipping — and make a tag the
shippable release. Friday verifies "a clean install byte-compiles, boots the app, and collects the tests"; we do the analogue.

## CI job (`clean-install`, in `.gitlab-ci.yml`)
On the existing runner image:
1. Fresh checkout (CI already clones); create a venv with python3.13.
2. `pip install .` (resolves the `git+ssh` deps — CI rewrites ssh→https via `GITLAB_PUSH_TOKEN`, as today).
3. `genesis db upgrade` against a temp `GENESIS_STATE_DIR`.
4. Boot `genesis serve` headless (temp state dir), poll `GET /api/config/health` until ok, assert 200, shut down.
5. `shellcheck scripts/*.sh` (installer/launcher/updater) + a smoke run of `install.sh --no-migrate` against the checkout.

This runs alongside the existing `genesis` (pytest+ruff) and `frontend` (build + stale-bundle guard) jobs; it only needs to run
on changes to `scripts/**`, `pyproject.toml`, `genesis/api/system/**`, or migrations (keep it cheap otherwise).

## Release
- Existing protocol: bump `genesis` version → **v0.47.0** → tag → push → CI green. The tag is the release the updater (22-03)
  discovers. `web/static` rebuilt + committed for the banner/panels (the `frontend` stale-bundle guard enforces this).
- No dependency-pin changes (genesis-core/sdk/parser/workflows unchanged) → no coordinated multi-repo release.

## Acceptance
- The `clean-install` job passes on the release commit; the tag pipeline is green; a manual clean-machine run matches CI.

## Tests
- The job *is* the test. Additionally assert the update-version comparison + `api/system` unit tests (from 22-03/04/05) run in
  the normal `genesis` pytest job.
