# Phase 1 — State and Gate

| | |
|---|---|
| **Depends on** | Phase 0 (frozen `state.schema.json` + status enum + fixtures) |
| **Outcome** | `state.py` + `gate.py` + `dg state` / `dg gate`; workflow state and preconditions owned by code |
| **Retires** | All **9 `BLOCKING CHECK`** blocks and all **9 `EXECUTION TRACKER UPDATE`** blocks |
| **Ships code?** | Yes — first executable phase |
| **Proposal refs** | §8 Phase 1; §7.3 (enum), §7.4 (`state.json`); Appendix D-5 |

> This is the reviewer's "Option 2" increment and the spine everything else hangs on: **`dg gate` is the only
> thing that sets `PASS`.** A step whose artifact exists but whose state was never set by `dg` does **not**
> open the next gate — this is the structural defense against the agent doing the work in-context and skipping
> the pipeline.

---

## 1. Objective

Replace two pervasive prose mechanisms with tested code:
- The **`BLOCKING CHECK`** block that opens ~9 files ("do not proceed unless step N is COMPLETE").
- The **`EXECUTION TRACKER UPDATE`** block that closes ~9 files (mechanical status transition).

Both become `dg state` / `dg gate` operating on a single `state.json` — the one source of workflow state.

## 2. What to build

### 2.1 `state.py`
- Read/write `state.json` conforming to `state.schema.json`.
- Enforce the **four-value enum** `PENDING | IN_PROGRESS | PASS | BLOCKED`. Reject anything else (this is
  the D-5 fix — the tracker previously wrote `COMPLETED` while a grep looked for `COMPLETE`).
- **Atomic writes**: write to a temp file then `os.replace()` so a crashed run never leaves half-written state.
- Never store emoji; reports may render emoji for humans, `state.json` never does.
- API sketch:
  ```py
  class State:
      def load(path) -> "State"
      def get(step) -> dict
      def set(step, status, **fields) -> None      # validates enum; atomic write
      def gate_mode() -> str                        # resolve_write_set|degraded_manual|kb_stale
  ```

### 2.2 `gate.py` — preconditions **as data, not code branches**
```py
PRECONDITIONS = {
    "1":  ["0"], "2": ["1"], "3": ["2"], "4": ["3"],
    "4b": ["4"], "5": ["4b"], "gen": ["5"],
    "E1": ["0"], "E2": ["E1"], "E3": ["E2"], "E4": ["E3"],
}
```
`gate(require: list[str], then: str)` → exit 0 if every required step is `PASS`; else exit non-zero and print
the exact blocker (`"4b is PENDING; required PASS"`). Keeping the graph as data keeps it inspectable and
lets both mode graphs (manual `0→…→gen`, exemplar `E1→…→E4`) live side by side.

### 2.3 Subcommands
```
dg state get --step <id>
dg state set --step <id> --status <PENDING|IN_PROGRESS|PASS|BLOCKED> [--<field> <val> ...]
dg gate  --require <id>[,<id>...] --then <id>
```

## 3. Step-by-step
1. Implement `state.py` with the enum guard + atomic write; unit-test the guard and the crash-safety path.
2. Implement `gate.py` with `PRECONDITIONS` as data; implement `gate()`.
3. Wire `dg state` / `dg gate` into `dg.py` subcommand dispatch.
4. Point every retired `BLOCKING CHECK` / `TRACKER UPDATE` in the prose at the new commands (full prose
   rewrite is Phase 8, but per DEC-4 update each block as this phase lands).
5. Add `tests/test_gate.py` and `tests/test_state.py`.

## 4. Defects resolved
- **D-5** — single status enum enforced in code; the `COMPLETE`/`COMPLETED` grep mismatch becomes impossible.

## 5. Retirements
- **9 `BLOCKING CHECK` blocks** (one atop each procedural file) → `dg gate --require ... --then ...`.
- **9 `EXECUTION TRACKER UPDATE` blocks** → `dg state set --step ... --status PASS`.
- Net: removes a large, duplicated, emoji-laden apparatus and replaces it with two commands.

## 6. Done when
```shell
dg gate --require 4b --then 5      # exit 1, prints: "4b is PENDING; required PASS"
dg state set --step 4b --status PASS
dg gate --require 4b --then 5      # exit 0
python3 -m pytest tests/test_gate.py tests/test_state.py -v
```
Tests MUST cover: **missing step**, **wrong status**, **out-of-order transition**, **both mode graphs**
(manual and exemplar), and a **corrupted `state.json` failing loudly** rather than defaulting to permissive.

## 7. Risks & notes
- **Permissive-on-error is the dangerous default.** A corrupt/missing `state.json` must FAIL the gate, never
  pass it. Assert this explicitly in a test.
- Keep `state.py` free of any domain knowledge (no coverage/FK logic) — it is pure state plumbing.
- `gen` (generation) and the exemplar chain share one state file; keep step IDs namespaced exactly as in
  `PRECONDITIONS`.

## 8. Handoff to Phase 2
Phase 2 (`scaffold.py` / `dg init`) creates the folder and writes the **initial** `state.json` and
`decisions.json`; it depends on the enum + `state.py` API frozen here.
