# 51-03 — Spike: a sandboxed Kiro shell driving `apwt` (the D3 gate)

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: **genesis** (spike harness under `genesis/scripts/spikes/` + notes in
> the As built; no product code), **playwright-appian** (only if a gap needs a change, D19). Built by genesis-dev; a
> genesis-review pass checks the evidence. Parent: `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D3,
> D4, D5, D8, D13.

## 1. Goal

Prove, on the user's macOS machine with the installed `kiro-cli` (2.37.1 at spec time), that a Genesis workflow agent
can drive `apwt` through Kiro's shell inside Kiro's local command sandbox with no way to reach secrets, other hosts or
files outside its run folder — or show that it cannot, so the D3 fallback (an `appian-browser` MCP server) replaces it
before 51-07/51-09 are built. Also settle the signed-in recording mechanism (D13) and the Chromium choice (D4).

## 2. Questions the spike must answer (each with evidence: commands, outputs, files)

| # | Question | Pass criterion |
|---|---|---|
| S1 | Does `kiro-cli acp --agent-engine v3` honour a `<cwd>/.kiro/settings/sandbox.json` (`enabled`, `networkAccess`, `mcpSandboxing:false`) and permission rules (`fs_write`, `fs_read`, `sandbox_network` allow for one host)? Where must the files live for an ACP session (cwd vs `KIRO_HOME`)? | A shell command in an ACP session (driven through `kiro_agent_sdk` with `agent_engine="v3"`, `trust_tools=[<shell tool name>]`) cannot write outside cwd + temp and cannot reach a non-allowed host |
| S2 | Does Playwright's Chromium (`PLAYWRIGHT_BROWSERS_PATH` under `~/.genesis/testing/browsers`) launch headless **inside** the Seatbelt sandbox (nested sandbox), started by `apwt -s x open` from the agent's shell? If not, which documented flag combination works (e.g. Chromium's own sandbox off **only** inside Kiro's sandbox) and what does that cost? | `apwt open` + `snapshot` succeed in the sandbox |
| S3 | Does the browser reach the QA host through Kiro's network proxy? Playwright's Chromium does not read `HTTP(S)_PROXY` by itself; does `apwt` (or a `playwright-appian` change) pass a `proxy` launch option, or is a session opened **outside** the sandbox by a program node and only **attached** to from inside? | The agent completes `open`/`snapshot`/`do`/`expect` against the QA site |
| S4 | Program-owned sessions: a program node opens and logs in `apwt -s <name> open --login` with the role's credentials in **that command's** environment only; the agent's shell then runs `apwt -s <name> snapshot/do/...` and sees no credential. Which `apwt` control files (`$PLAYWRIGHT_APPIAN_HOME/browsers/<name>/token`, `daemon.sock`, saved states) must the sandbox let the agent read, and which must it deny? | Agent commands work; `env`, `cat` of state/credential files and `ps -E` show no password |
| S5 | Clean environment: start Kiro with a minimal allow-listed environment instead of `os.environ.copy()` (`kiro_agent_sdk/client.py:182-190`). What must stay (`HOME`, `PATH`, `TMPDIR`, Kiro auth)? | Kiro authenticates; the shell's `env` holds no `GENESIS_*` secret, no `APPIAN_*`, no LCP vars |
| S6 | Bypass corpus (L-088): write outside the run folder; read `~/.genesis/secrets.json`, `~/.ssh`, `~/.aws`, `~/.genesis/genesis.db`; reach the Dev host and a public host; spawn a background process that outlives the turn; read another session's control files | Every item denied or harmless; documented |
| S7 | Positive corpus: the full `playwright-appian` skill loop (`open` by program, then agent `snapshot`, `find`, `fill`, `select`, `click`, `wait`, `expect`, `record-start`, `record-stop`, `spec`, `log`) plus `npx playwright test <spec>` from the workspace | All succeed; the spec replays green |
| S8 | Recording signed in as a role (D13): can Genesis open a **headed** Chromium logged in as the role and have `apwt record start` record into it (`--cdp`), or does `playwright-appian` need an additive option (e.g. `record start --state <saved login>` / `--login`)? | A recording started this way produces a trace whose spec replays |
| S9 | Chromium everywhere (D4): can `record start`, agent `open` and generated specs all use Playwright Chromium (`--browser chromium`, config `channel`)? | One browser for all three, or the change list for `playwright-appian` |
| S10 | Timing: explore-turn duration for a typical story screen (to size `turn_timeout`, F10) | Measured numbers |

## 3. Outcome rules

- **All of S1–S7 pass** → D3 stands. The As built records the exact sandbox files, the shell tool name to trust, the
  clean-environment allow list, the session-ownership recipe and any `playwright-appian` change made (with its D-row in
  `playwright-appian/planning/DECISIONS.md`). 51-05/51-09 build on it.
- **Any of S1–S6 fails without a safe fix** → stop. Report to the user; the spec agent re-specs the agent-access parts
  of 51-05 §5, 51-07 §5 and 51-09 §3 on the fallback (`appian-browser` MCP server, managed entry like `genesis-kb`,
  per-node allowlist; 51-01 D3).
- S8/S9 gaps are fixed in `playwright-appian` (additive; minor version bump; its own tests) during this spike or listed
  for 51-05.

## 4. Constraints

Read-only against Dev (no Dev MCP writes). Use a QA environment and a test user the user provides; never the Dev-MCP
service account. Spike code is throwaway (kept under `genesis/scripts/spikes/` for the record, not imported by product
code). Never run Genesis agents with `--trust-all-tools`.

## Context manifest

```toml
areas    = ["sdk-acp", "security", "runs-worker", "core-engine"]
adrs     = ["ADR-002", "ADR-004", "ADR-012", "ADR-020", "ADR-029", "ADR-031", "ADR-069", "ADR-077"]
lessons  = ["L-001", "L-017", "L-041", "L-044", "L-088", "L-100"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md"]
code     = ["genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "playwright-appian/src/agent/**", "playwright-appian/src/cli/**", "playwright-appian/src/recorder/**"]
upstream = ["51-02"]
```
