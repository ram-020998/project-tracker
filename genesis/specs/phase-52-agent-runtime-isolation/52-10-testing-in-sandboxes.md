# 52-10 — Testing in the boxed world: saved logins, `test-execution` and `recording`

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`genesis/testexec/**`, the per-app workspace helper
> `lib/`). Parent: `specs/phase-52-agent-runtime-isolation.md`. Decisions: D15, D25, D27. Upstream: 52-02 (S11), 52-06,
> 52-07, 52-09.

## 1. Goal

Close ADR-083 risk (c) and bring Phase 51's three browser uses into sandboxes: passwords never enter any sandbox, test
code runs under its own restricted profile, recording runs headed on a virtual display shown in the Genesis UI.

## 2. Design

- **Sign-in on the trusted side:** a program step in the app container signs each needed role in to the QA site with
  headless Chromium and the role's password from the SecretProvider, and writes a Playwright saved-login file
  (`storageState`) per role into the run folder (`<run>/auth/<role>.json`). Program steps that today run `apwt open
  --login` with the password in the environment switch to `apwt open --storage-state <role file>` (the option exists:
  `playwright-appian/src/cli/agent/commands.ts:690-691`). A saved login that has expired is re-created by the program
  step, never by the agent.
- **Agent browser sessions** (the Phase 51 agent nodes): run inside the agent's own `workflow-agent` sandbox, headless,
  egress = the QA host; `npx --no-install apwt` from the run's workspace export (L-101), unchanged.
- **`TE-` executions** (`execution_service.py`, `runner.py`, `replay.py`): run `npx playwright test` in a
  `test-execution` sandbox (D27: no Kiro, no broker, no relay, QA host only, mounts = the workspace export and the
  output folder, saved-login files only). The workspace helper `loginAs` (`lib/`) loads the saved-login file for the
  role instead of filling a password; generated specs keep working.
- **Recording** (`recording.py`, the Record workflow): a `recording` sandbox starts Xvfb, Chromium headed and
  `apwt record start --state <role file>` (`src/cli/index.ts:126`); noVNC serves the display on a port reachable only
  from the app container; the app proxies it to the UI (52-13, 52-14) behind the API token. Stop ends the recording and
  the sandbox.
- **Process reaping** (`procs.py`, L-104): inside a sandbox, removing the container is the reap; the host-side `apwt`
  daemon tracking stays only for the trusted sign-in step.
- Reports: still served on the report origin (ADR-085), from the output folder.

## 3. Tests

Sign-in step against a fake QA site (storage state written, password never in any child env, L-105's scrubbing still
applied to reports); `loginAs` with a saved login; a `TE-` execution in a `test-execution` sandbox on the dev VM
(egress only to the fake QA host; a request elsewhere denied and logged); recording start/stop with noVNC reachable
from the app container and refused from the host; the existing testexec suites green.

## Context manifest

```toml
areas    = ["browser-testing", "security"]
adrs     = ["ADR-081", "ADR-082", "ADR-083", "ADR-085", "ADR-086"]
lessons  = ["L-101", "L-104", "L-105", "L-107", "L-108", "L-111", "L-119"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md"]
code     = ["genesis/genesis/testexec/execution_service.py", "genesis/genesis/testexec/runner.py", "genesis/genesis/testexec/replay.py", "genesis/genesis/testexec/recording.py", "genesis/genesis/testexec/procs.py", "genesis/genesis/testexec/roles.py", "genesis/genesis/testexec/templates/**"]
upstream = ["52-02", "52-06", "52-07", "52-09"]
```
