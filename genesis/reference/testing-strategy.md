# Genesis — Testing Strategy

How the platform and the workflow library are tested, and the CI gates that keep
the library trustworthy (workflows run in a subprocess worker, but quality is still enforced at
publish time — ADR-012).

---

## 1. Test layers

### 1.1 Platform (`genesis` repo)
- **Unit tests** — pure logic: state reducers, `RunWorkspace`, MCP registry
  resolution (offline), CLI registry, catalog/install/lockfile logic (mock GitLab),
  loader, config/secrets, reliability lint, run lifecycle state machine.
- **Node factory tests** — `program_node`, `cli_node`, `validator_node`,
  `attach_reliability` routing (pass/retry/escalate). `kiro_node` with a **stubbed
  ACP transport** (no real Kiro) to assert prompt/artifact plumbing.
- **Integration tests** — engine + SQLite checkpointer: run a smoke graph, kill +
  resume, assert exact resumption; HITL gate → respond → continue; pause → resume;
  state edit → resume; fork.
- **Fixture-GitLab integration** — install `hello-appian` from a local fixture
  repo, load it, run it via the harness.
- **Live/opt-in** — a marked test that drives a real `kiro-cli acp` session
  (needs local Kiro) for one trivial agent turn.

### 1.2 Workflow library (`genesis-workflows` repo)
Per workflow (required):
- **Unit tests** — every program node + validator (pure functions).
- **Stubbed-graph test** — inject canned agent outputs (no real Kiro/MCP); assert
  the graph reaches the right artifacts/state, hits its gates, and **escalates on
  a forced validator failure**.
- **Optional live/integration test** — marked; needs real creds (e.g., ERD dry-run
  against `SourceSelection`).

---

## 2. The `kiro_node` testing pattern (stubbing)

Because agent output is non-deterministic and costly, workflow graph tests stub
agent nodes:
- Provide a fake that writes a canned artifact to the node's `output_doc` and
  returns a normal `TurnResult`.
- This exercises the *deterministic* parts (validators, program nodes, routing,
  gates, assembly) fully and reliably — which is most of the workflow.
- The reliability trio is tested by having the stub write a **bad** artifact and
  asserting retry→escalation.

(This mirrors how the ERD POC was validated: stub the two agent steps, assert the
program assembles the correct `erd-input.json`.)

---

## 3. Library CI gates (publish-time — Phase 2, ADR-011/012)

A workflow cannot be tagged/released unless **all** pass:
1. **Schema** — every `workflow.yaml` valid; `registry.json` matches; ids unique.
2. **Contract** — `graph.py` imports; `META` importable w/o side effects; `META` ≡ `workflow.yaml`.
3. **Reliability lint** — every agent node has validator + retry + escalation (`check_reliability`).
4. **Registry refs** — every `required_mcp`/`required_cli` exists.
5. **State-size guard** — no bulk pushed into state.
6. **Tests** — each workflow's `tests/` pass.
7. **Migration** — `MIGRATION.md` row present/updated (Phase 8).

A deliberately **non-compliant fixture** workflow is kept to prove gate #3 fails.

---

## 4. Platform CI

- Lint (ruff) + type-check + unit/integration tests.
- `genesis-core` version compatibility check (platform ↔ library).
- Build the web bundle (Phase 7) if present.

---

## 5. Local developer loops

- `genesis test-workflow <path>` — runs a workflow's tests + structural lint locally before MR (fast feedback; same checks as CI gates 1–5).
- `genesis create-workflow` — scaffold already includes a passing example test.
- Platform: standard `pytest`.

---

## 6. What we explicitly test for (lessons encoded)

- **Resumability** — kill mid-run, resume from last checkpoint, no re-execution of completed nodes.
- **Worker isolation** — a workflow that `sys.exit()`s / hangs / OOMs fails only its run; the app + UI survive; the run resumes from the last checkpoint (ADR-012).
- **genesis-core compat gate** — a library ref targeting a different `genesis_core` major is refused at load with a clear message (ADR-019).
- **No bulk in state / chat** — state-size guard + agent-writes-to-file pattern.
- **Reliability trio** — forced validator failure retries `retry_max` then escalates.
- **MCP fail-fast** — unresolved `${VAR}` errors before Kiro spawns.
- **HITL correctness** — gate resume, pause/resume across restart, state edit + fork.
- **ERD parity** (Phase 6) — dry-run reproduces the known-good result (~37 tables, 174 rels).

---

## 7. Coverage expectations
- Platform: high coverage on `dist`, `config`, `runs`, `common/nodes`, `lint`.
- Workflows: every program node + validator unit-tested; one stubbed-graph test minimum; live tests optional but encouraged for flagship workflows.
