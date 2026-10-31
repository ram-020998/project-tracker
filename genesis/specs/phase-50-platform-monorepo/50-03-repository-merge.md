# 50-03 — Repository merge

> **Status:** SPEC-DRAFTED 2026-10-31. Agent: **genesis-dev**. Repo: **genesis**, branch `phase-50-monorepo` (local;
> never pushed by this agent). Parent: `specs/phase-50-platform-monorepo.md`. Decisions: D5, D6, D7, D11
> (`50-01-findings.md` §6). Read 50-02 As built first; do not start on a no-go.

## 1. History import (D7)

From an up-to-date genesis `master` (re-check: ahead 0, dirty 0):

```
git switch -c phase-50-monorepo
git subtree add --prefix=packages/kiro-agent-sdk        ../kiro-agent-sdk        main
git subtree add --prefix=packages/genesis-core          ../genesis-core          master
git subtree add --prefix=packages/genesis-appian-parser ../genesis-appian-parser main
```

No `--squash`. Old tags are not imported. Record the three merge commit SHAs and the tip SHA of each library that was
imported. Run these one at a time (L-089).

## 2. Package files (D5, D6, D11, F6)

- Each `packages/<name>/` keeps its `README.md`, `.gitignore`, package dir and `tests/`. Delete
  `packages/genesis-core/.gitlab-ci.yml` and `packages/genesis-appian-parser/.gitlab-ci.yml` (50-06 replaces them).
- **Dependencies (D6):** remove `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser` from
  `genesis/pyproject.toml` `[project].dependencies` (with their comments); remove `kiro-agent-sdk` from
  `packages/genesis-core/pyproject.toml`. Third-party dependencies stay where they are. Drop
  `allow-direct-references` where nothing needs it any more.
- **kiro-agent-sdk (D11):** hatchling backend, `[tool.hatch.build.targets.wheel] packages = ["src/kiro_agent_sdk"]`
  (or the form 50-02 Q5 proved), `requires-python = ">=3.13"`, dev extra `pytest>=8`, `ruff==0.15.20`,
  `[tool.ruff] line-length = 100`. Delete `workflows/erd_workflow.py`, `tests/test_erd_workflow.py`,
  `examples/quickstart.py`, `.env.example` in one commit; update its README to drop the POC sections.
- Versions stay as they are in this sub-spec; 50-07 unifies them.

## 3. Repoint repo-external paths

- The three tests that read the parser fixture by absolute path (`tests/test_kb_server.py:196-203`,
  `tests/test_kb_incremental.py:22-24`, `tests/test_kb_store.py:12-14`) use a path relative to the repo root:
  `Path(__file__).resolve().parents[1] / "packages/genesis-appian-parser/tests/fixtures/AiDocumentCenterv4.3.1.zip"`.
  Keep the skip-if-missing guard.
- `grep -rn "repo-gitlab/ramaswamy.u/\(genesis-core\|kiro-agent-sdk\|genesis-appian-parser\)\|\.\./\(genesis-core\|kiro-agent-sdk\|genesis-appian-parser\)"`
  over the genesis repo (excluding `.venv`, `node_modules`, `web/static`) must return nothing except docs that 50-05
  rewrites.

## 4. Missing-library check (D6, F2)

- `genesis/runtime/preflight.py`: a **required** item `platform-packages` that checks
  `importlib.util.find_spec` for `genesis_core`, `kiro_agent_sdk`, `genesis_appian_parser`, with the hint
  "run scripts/install-packages.sh" (the script lands in 50-05; the hint text can name it now).
- At app startup (`create_app` or `serve`): log one `error` naming each missing module; do not crash so the
  preflight page can show it.
- Tests for both (missing module simulated with a patched `find_spec`).

## 5. Rebuild the dev venv

The shared `genesis/.venv` holds editable installs of the old checkouts, and the fleet runs it
(`50-01-findings.md` §2.8). Check no run is active on the fleet first (`GET /api/runs?status=running` on :8760 and
:8761; never restart during a run, L-061). Then, sequentially:

```
.venv/bin/pip uninstall -y genesis-core kiro-agent-sdk genesis-appian-parser genesis
.venv/bin/pip install -e packages/kiro-agent-sdk -e packages/genesis-core -e packages/genesis-appian-parser -e ".[dev]"
```

Add a test `tests/test_platform_packages.py`: each of `genesis_core`, `kiro_agent_sdk`, `genesis_appian_parser`
imports from a path inside this repo's `packages/`. In CI it guards against a non-editable install too (the path is
then in site-packages — so the test asserts only when an env var `GENESIS_DEV_CHECKOUT=1` is set, or checks
`importlib.metadata` direct_url; pick one and record why).

## 6. Gates

`ruff check genesis`, `pytest -q` (app), plus each library's own tests from its folder:
`cd packages/genesis-core && ../../.venv/bin/python -m pytest -q`, same for the SDK and the parser
(`../../.venv/bin/ruff check .` for the parser and core). Record counts; they must equal the pre-merge counts
(core 91, SDK 93 minus the removed ERD test, parser as recorded in 50-02 Q8, app per `context/state/current.md`
after Phase 49).

## 7. Acceptance

- [ ] Three subtree merges; `git log -- packages/genesis-core` shows the original SHAs.
- [ ] No internal dependency entry in any `pyproject.toml`.
- [ ] SDK aligned; POC files gone.
- [ ] Parser-fixture tests run (not skipped).
- [ ] Preflight item + startup log + tests.
- [ ] Dev venv rebuilt; library imports resolve into `packages/`.
- [ ] All gates green; counts recorded.

## 8. As built

*(filled by genesis-dev)*

## Context manifest

```toml
areas    = ["distribution", "core-engine", "sdk-acp", "parser", "kb-sync", "runs-worker"]
adrs     = ["ADR-002", "ADR-012", "ADR-016", "ADR-019", "ADR-024", "ADR-036", "ADR-037", "ADR-046"]
lessons  = ["L-025", "L-027", "L-056", "L-061", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md"]
code     = ["genesis/pyproject.toml", "genesis/packages/**", "genesis/genesis/runtime/preflight.py",
            "genesis/genesis/api/app.py", "genesis/tests/test_kb_server.py", "genesis/tests/test_kb_store.py",
            "genesis/tests/test_kb_incremental.py"]
upstream = ["50-02"]
```
