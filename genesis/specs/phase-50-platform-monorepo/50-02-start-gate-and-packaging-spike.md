# 50-02 — Start gate and packaging spike

> **Status:** SPEC-DRAFTED 2026-10-31. Agent: **genesis-dev**. Repos: none committed — all work in throwaway copies
> under `/tmp/phase-50-spike/`. Parent: `specs/phase-50-platform-monorepo.md`. Decisions: D6, D7, D9, D11
> (`50-01-findings.md` §6).

## 1. Start gate (D9) — do this first, stop on any failure

Record each result in the As built:

1. `genesis-ctx status` shows `genesis` and `genesis-workflows` with **ahead 0** and **dirty 0**.
2. `specs/phase-49-test-design.md` status line says `SHIPPED`.
3. The Phase 49 tags exist on the remote: `git ls-remote --tags origin v0.79.0` in genesis and `v0.23.0` in
   genesis-workflows (or whatever 49-09 As run records).

If any check fails: write the failure in the As built, do nothing else, and report to the user.

## 2. Why a spike

D6 relies on pip behaving a certain way that we have not run here: no relative path dependencies, one command
installing local folders, subdirectory pins from genesis-workflows. L-051 / L-087: probe the real tools before
building on their docs. The spike changes no real repo.

## 3. Setup

1. `git clone` local copies of genesis, genesis-core, kiro-agent-sdk, genesis-appian-parser, genesis-workflows into
   `/tmp/phase-50-spike/` (from the local checkouts; no network needed).
2. In the genesis copy: `git subtree add --prefix=packages/genesis-core ../genesis-core master` (and `main` for
   kiro-agent-sdk and the parser). Record the merge commits and confirm `git log --oneline -- packages/genesis-core`
   shows the original SHAs (D7).
3. Hand-edit the copy as 50-03 will: remove the internal dependency entries (D6), switch the SDK to hatchling +
   `>=3.13` (D11). Python 3.13 venvs only.

## 4. Questions to answer (each with the exact command and output in the As built)

| # | Question | Pass when |
|---|---|---|
| Q1 | Does one command `pip install ./packages/kiro-agent-sdk ./packages/genesis-core ./packages/genesis-appian-parser .` install all four non-editable in a fresh venv? | `pip check` clean; `python -c "import genesis_core, kiro_agent_sdk, genesis_appian_parser, genesis"` works; the wheel still contains `genesis/web_static` (L-048) |
| Q2 | Same with `-e` for each path plus `-e ".[dev]"`? | Imports resolve to the copy's `packages/` paths |
| Q3 | Does pip ever ask an index for an internal name? | `pip install --dry-run --report r.json …` (and the real install with `-v`) shows no index lookup for `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`, `genesis` |
| Q4 | What does plain `pip install .` do now? | Installs only the app; startup import fails clearly (input for F2); nothing fetched for internal names |
| Q5 | Does hatchling build the SDK's `src/` layout? | Wheel contains `kiro_agent_sdk/` at top level |
| Q6 | genesis-workflows with `#subdirectory=` pins against the copy (tag it locally `v0.80.0-spike`, use a `git+file://` URL) | `pip install -e ".[dev]"` succeeds; record time and how many clones pip makes; check whether pip uses a partial clone (`--filter=blob:none`) |
| Q7 | Re-running the one command over an existing install (the updater path) | Upgrades in place; time it |
| Q8 | The genesis test suite on the copy's venv | Same pass count as master (record it); the three parser-fixture tests run once their paths point into `packages/` |

## 5. Output

The As built: the answers, the commands, timings, pip version, any surprise, and a go / no-go for D6. A **no-go**
stops the phase and goes back to the user with the evidence. Delete `/tmp/phase-50-spike/` at the end.

## 6. Acceptance

- [ ] Start gate recorded and passed.
- [ ] Q1–Q8 answered with evidence.
- [ ] No commit, tag or push in any real repo.

## 7. As built

*(filled by genesis-dev)*

## Context manifest

```toml
areas    = ["distribution", "release-ci", "core-engine", "sdk-acp", "parser", "workflows-library"]
adrs     = ["ADR-017", "ADR-019", "ADR-024", "ADR-046"]
lessons  = ["L-048", "L-051", "L-057", "L-087"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:specs/phase-49-test-design.md"]
code     = ["genesis/pyproject.toml", "genesis-core/pyproject.toml", "kiro-agent-sdk/pyproject.toml",
            "genesis-appian-parser/pyproject.toml", "genesis-workflows/pyproject.toml"]
upstream = []
```
