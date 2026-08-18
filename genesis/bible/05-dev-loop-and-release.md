<!-- GENESIS BIBLE — CHUNK 05. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **This file is one chunk of the Genesis bible.** The bible is split across `bible/` and indexed by
> [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md). **When asked to "read the bible", read the index AND every
> chunk it lists, then follow all of it religiously.** This chunk holds: **§6 Environment, dev loop, release, CI.**
> Section numbers (§0–§10) are the ORIGINAL bible sections and are preserved here; the §→chunk map lives in the index.

---

## 6. Environment, dev loop, release, CI

- **OS** macOS; **Python** 3.13; **node** 20 + npm + vite. Use non-interactive shell flags (`rm -f`, etc.).
- **Dev venv (use for all Python):** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv` — editable installs of kiro-agent-sdk, genesis-core, genesis (+ pytest, pytest-asyncio, ruff, pyyaml, requests, jsonschema, aiosqlite, fastapi, sse-starlette, uvicorn, httpx). Python edits are live for the CLI and freshly-spawned workers — **but restart a running `genesis serve`** to pick up server-process changes (it has already imported `api/app.py` + `manager.py`).
- **Run tests:**
  - genesis: `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` (+ `ruff check genesis`)
  - genesis-core: `cd genesis-core && ../genesis/.venv/bin/python -m pytest -q -p no:warnings` (+ `ruff check genesis_core`)
  - genesis-workflows: `../genesis/.venv/bin/python ci/validate_library.py` and `../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures`
  - web: `cd genesis/web && npm run lint && npm run typecheck && npm test`
- **Frontend build (the current, post-cutover rule):** the new app IS the served app; `web/static/` is the **committed** production bundle. `npm run build` (= `tsc --noEmit && vite build`) writes `web/static/`. **After ANY `web/src` change, run `npm run build` and COMMIT the updated `web/static/`.** CI's `frontend` job runs lint → typecheck → test → build → a **stale-bundle guard** (`git diff --quiet -- static`) that fails if the committed bundle differs from a fresh build. (If an older spec's DoD says "web/static/ untouched", treat it as "rebuild + commit" — those specs predate the cutover.)
- **NPM registry:** local `~/.npmrc` points at Appian Artifactory with an EXPIRED token (E401 on new installs). Use `--registry=https://registry.npmjs.org/` for local installs (do NOT edit global `~/.npmrc`). CI's node:20 resolves the lockfile's public-npm URLs fine.
- **Run the app:** `.venv/bin/genesis serve` (→ http://127.0.0.1:8760, `/docs`). Install workflows: `genesis install --from ../genesis-workflows` (or `genesis install` for GitLab pull). `genesis list`. `genesis db status|upgrade`.
- **Distribution/versioning:** pyproject deps are git+ssh. When you change a repo: bump `[project].version`, commit + tag `vX.Y.Z` + push, and bump dependent pins (genesis pins genesis-core; genesis-workflows pins both). Release order core → genesis → genesis-workflows so tags exist. **Frontend-only changes still ship a genesis release** because `static/` is committed. Commits: `git -c user.name=Genesis -c user.email=genesis@local commit -m "..."` (do NOT change git config).
- **CI:** each `.gitlab-ci.yml` rewrites ssh→https via the `GITLAB_PUSH_TOKEN` CI/CD var (set on all 3 code repos — should be rotated; it was shared in chat). `glab` is authed for READS (`glab ci list/trace`) but its token lacks `api` scope → cannot `glab ci run`/`variable set`; **trigger pipelines by pushing.** Verify: `glab ci list -R ramaswamy.u/<repo>`.
- **Gitignore lesson:** build-artifact ignores are anchored (`/dist/`, `/build/`, `web/node_modules/`) so they don't swallow tracked source/served dirs (`genesis/web/static/` IS tracked). After adding a source dir, verify `git check-ignore <path>` says NOT ignored and `git ls-files` lists it.
- **project-tracker repo** (github, branch `main`) is SEPARATE from the code repos; after meaningful work, update `tracker.md` §6 + a `progress/` doc and push it (`git pull --rebase` then push).

---

