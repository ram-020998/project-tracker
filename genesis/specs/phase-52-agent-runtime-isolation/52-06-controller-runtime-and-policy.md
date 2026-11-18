# 52-06 — Sandbox Controller, SandboxRuntime and AgentSecurityPolicy

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (`genesis/agent_runtime/`, the `controller` image). Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D5, D6, D21, D22, D24, D25, D28. Upstream: 52-02 (S2, S8,
> S12, S13), 52-03, 52-04, 52-05.

## 1. Goal

The single trusted owner of sandboxes and the one policy it enforces, built before any workflow uses them (D30).

## 2. `AgentSecurityPolicy` (`genesis/agent_runtime/policy.py`)

- The frozen schema from 52-03 §4. **Compiler** `compile_policy(profile, run, node, settings) -> AgentSecurityPolicy`:
  platform defaults per profile, then the workflow's `META` and node declarations (MCP servers and tools, `egress`,
  skills), then user settings; **tightest wins** (a setting can remove a host or lower a limit, never widen past the
  platform maximum unless the user added it in Settings → Egress, D10 layer 3). Pure function, unit-tested.
- Profiles: `workflow-agent` (Kiro broker, relay, run subfolder rw, egress = base + declared), `chat` (Kiro broker,
  relay to read-only servers, the session sandbox folder rw, egress = base), `test-execution` (D27: no broker, no relay,
  workspace export + output, QA host only), `recording` (as `test-execution` plus the virtual display).
- Recorded as `policy_hash` in `sandbox.started`; a changed setting applies from the next turn (KiroCrew `14c6b6c948`).

## 3. `SandboxRuntime` (`genesis/agent_runtime/runtime/`)

Interface: `create(policy, labels) -> handle` · `attach_stdio(handle)` · `wait(handle)` · `stats(handle)` ·
`kill(handle, reason)` · `remove(handle)` · `list(labels)`. First implementation **`DockerRuncRuntime`**: maps the
policy to `docker create` options — `--user agent`, `--cap-drop ALL`, `--security-opt no-new-privileges`, default
seccomp, `--read-only`, `--tmpfs /tmp` (size-capped), the run subfolder volume mount at the same absolute path,
`--network <sandbox net>`, `--cpus`, `--memory`, `--pids-limit`, `--log-opt max-size`, `--init`, no `--privileged`, no
devices, no host mounts, the env allow-list only, labels. A **test-only `LocalRuntime`** (a subprocess on the host)
lets unit tests run without containers and is refused by the product configuration (D16). gVisor (`--runtime runsc`)
is a later `runtime` value, not built here (D21).

## 4. The controller (`genesis/agent_runtime/controller/`, the `controller` image)

- **API** on a unix socket in a volume shared only with the app container (or a control network the sandboxes are not
  on, per 52-02), authenticated with a token generated at stack start; requests: `run_turn(policy, labels)` (returns a
  stdio stream for ACP), `cancel(turn_id, reason)`, `status()`, `self_test()`, `stats(turn_id)`.
- **Queue:** at most the concurrency cap of live sandboxes; further turns wait FIFO, with their position reported.
- **Lifecycle:** create → start → stream → on end, timeout (`lifecycle.turn_timeout` + margin), cancel or pause: kill
  and remove; emit `sandbox.started` / `sandbox.ended` with the reason and peak stats (S13). Pause/cancel keep ADR-012
  and L-108 semantics: the worker records the intended stop before the kill; only the worker writes the run's terminal
  state.
- **Orphan sweep** at controller start and every few minutes: any sandbox whose `genesis.run_id` is not an active run
  (asked of the app) is killed and removed; run under the run-owner lock rule (L-097).
- **Memory reservation:** the app container's reservation is set by the stack; under pressure the kernel kills a
  sandbox first (`--oom-score-adj` on sandboxes).
- **Self-test (D22):** at every stack start and after every VM or image update, start a `self-test` sandbox and run the
  short corpora subset (no host mounts visible, the Mac's loopback and VM services refused, the socket absent, a
  non-allowed host refused, an allowed probe host reachable); a failure sets the controller to **refusing** (every
  `run_turn` fails closed with the reason) until a passing re-run.
- The controller never compiles policy and never reads secrets.

## 5. Tests

Policy compiler tables (tightest-wins cases, profile defaults, hash stability); `DockerRuncRuntime` argv/options
golden tests for each profile; controller unit tests with a fake runtime (queue, cancel, timeout, sweep, refusing
state); an integration suite (marked, on the dev VM) running the full D22 bypass and positive corpora from 52-02 S12 as
scripts (`genesis/agent_runtime/corpora/`), each with its negative control (L-088, L-117).

## Context manifest

```toml
areas    = ["security", "runs-worker", "core-engine", "observability-credits"]
adrs     = ["ADR-009", "ADR-010", "ADR-012", "ADR-022", "ADR-024", "ADR-051", "ADR-066", "ADR-083", "ADR-086"]
lessons  = ["L-026", "L-088", "L-093", "L-097", "L-104", "L-107", "L-108", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/genesis/agent_runtime/**", "genesis/docker/controller/**", "genesis/genesis/runs/supervisor.py", "genesis/genesis/runs/manager.py"]
upstream = ["52-02", "52-03", "52-04", "52-05"]
```
