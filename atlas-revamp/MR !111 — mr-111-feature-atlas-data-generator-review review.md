# MR \!111 Review Feedback — `feature/atlas-data-generator` → `main`

**MR:** [appian/prod/solutions-os/-/merge\_requests/111](https://gitlab.appian-stratus.com/appian/prod/solutions-os/-/merge_requests/111) **Author:** ramaswamy.u (Ramaswamy Ulaganathan) **Reviewer:** walid.elsayed **Scope:** 100 files · \+4,915 / −0 **Verdict:** Request changes

## TL;DR — Implementation Order

1. **P0 (blocking, \~20 min)** — README documents four skills that don't exist (`data-gen`/`data-gen-bulk`/`data-gen-manage`/`data-gen-erd`); the MR actually ships three (`data-generate-records`/`data-generate-sql`/`data-generate-erd`).  
2. **P0 (blocking, \~30 min)** — `jsonschema` is a silent optional dependency: 2 `pytest` tests fail out of the box and both `check_schema` / `check_decisions` return `SKIP` in any environment without it, quietly hiding failed validation.  
3. **P1 (strongly recommended, \~2–3 h)** — Fix agent `prompt` URI style (Thread 1); make workflow-doc runtime dependency explicit or move it into a shared skill (Threads 2 and 3); refuse or implement CDT paths in `sql_emit.py`; enable or delete `check_users`; expand `test_cli.py` (Thread 4); make `dglib/` a proper package to avoid `import coverage`/`state` name collisions; wire pytest \+ ruff into `.gitlab-ci.yml`; record MCP-image versions per fixture; deduplicate the CRITICAL RULES lists.  
4. **P2 (nice-to-have, \~30 min)** — Skill-naming audit, split the 700-char README paragraph, prune the `@@FK:` dead branch in `sql_literal`, add spec-schema notes about seed/field-name determinism and `pick` vs `cycle` behavior.

Total: \~4–5 hours of focused work to ship-ready.

## What the MR Does

Introduces a new `data-generator` Kiro agent (`.kiro/agents/data-generator.json`) that composes three new skills — `data-generate-records` (live records via the `appian-data-generator` MCP), `data-generate-sql` (bulk INSERT SQL emission), and `data-generate-erd` (Lucidchart ERD via the DG MCP's ERD tool family). All three skills route through a shared analysis workflow — Step 0 → Manual (Steps 1–5 with a hard coverage gate) or Auto-Analysis (E1–E4) — before their respective execution phases.

The mechanical parts of the workflow (folder scaffolding, gate enforcement, payload validation, coverage reconciliation, SQL emission) are handled by a self-contained Python CLI, `dg`. It sits under `.kiro/resources/data-generator/scripts/` as `dg.py` \+ `dglib/` (9 modules, 5 JSON schemas, 1 thresholds config), and reads/writes only local on-disk artifacts — never calling the MCP or network. The skills' hard rule is that gate reports and validation runs come from `dg`, not the agent.

The MR also adds a 12-file `pytest` suite plus three golden-fixture request folders (`sourceselection-manual`, `sourceselection-auto-analysis`, `sourceselection-bulk`), 14 workflow/tool markdown docs under `.kiro/resources/data-generator/`, one `ruff.toml`, updates `.gitignore` to exclude `data-requests/`, and adds a "Data Generation Skill Suite" section to `README.md`.

Verification (sandbox worktree at `/tmp/solutions-os-mr111`, HEAD `b1cce658`): pytest reports **87 passed / 2 failed** with the default system Python and **89 passed** in a venv with `jsonschema` installed. `ruff check .` inside the scripts folder reports 2 `I001` import-order violations that ship in this MR. Fixture spot-check: every `field_reasoning` entry is populated in the `sourceselection-manual` payloads. The 4 unresolved threads on this MR (all authored by walid.elsayed) are addressed inline under P0-1, P1-1, P1-2, and P1-5 respectively.

## 🔴 P0 — Blocking (fix before merge)

### P0-1. README documents skills that don't exist and mislabels the ones that do

- **File:** `README.md:183-195`  
- **Impact:** The README is the single largest onboarding surface for the suite. A first-time reader will search for skills that do not exist and cannot cross-reference the "Featured Tools" section to anything in `.kiro/skills/`. This is a direct code/document contradiction.  
- **Evidence:** The new "Data Generation Skill Suite" section lists **four** skills — `data-gen`, `data-gen-bulk`, `data-gen-manage`, `data-gen-erd` — and states "The `data-generator` agent composes all four skills." None of those names exist in the repo. The MR ships **three** skills (`data-generate-records`, `data-generate-sql`, `data-generate-erd`) and no `data-gen-manage` at all. The agent JSON confirms three resources:

```json
// .kiro/agents/data-generator.json:26-30
"resources": [
    "skill://.kiro/skills/data-generate-records/SKILL.md",
    "skill://.kiro/skills/data-generate-sql/SKILL.md",
    "skill://.kiro/skills/data-generate-erd/SKILL.md"
]
```

- **Concrete fix:** Replace the README table and adjust the surrounding paragraph:

```
| Skill | Role |
|-------|------|
| `data-generate-records` | Generate **live records** (up to ~50) directly in an environment via the `appian-data-generator` MCP. Runs the shared analysis workflow (Manual or Auto-Analysis), then creates parents → children (mechanism-aware: `create_record` or `write_data_store_entity`), verifies coverage, and reports results. |
| `data-generate-sql`     | Generate a **bulk INSERT SQL script** (100+ rows) with FK handling via `LAST_INSERT_ID()` / `@variables`. Produces a `.sql` file; does **not** write to the environment. |
| `data-generate-erd`     | Generate an **entity-relationship diagram** (Lucidchart) of an application's tables from the Atlas schema, via the `appian-data-generator` MCP's `build_erd_input` + `generate_erd` tools. |

The `data-generator` agent composes all three skills. …
```

  Drop the `data-gen-manage` line entirely, or open a separate MR to ship the skill it describes.

### P0-2. `jsonschema` is a silent optional dependency; validation and decision-schema checks skip in its absence, and 2 tests fail out of the box

- **File:** `.kiro/resources/data-generator/scripts/dglib/validate.py:52-56, 216-224`; `.kiro/resources/data-generator/scripts/tests/test_validate.py:133-141`  
- **Impact:** Two integrity gates (`check_schema`, `check_decisions`) silently return `SKIP` when `jsonschema` isn't importable — so an artifact with an out-of-schema `decisions.json` gates through, and `dg validate` reports PASS. Combined with the MR's own "a step opens only when its `dg` gate/validator passes" hard rule (`prompt.md:59-63`), this defeats a load-bearing check. The MR's docs advertise "no third-party dependencies" (`prompt.md:38-45`, `tools/README.md:23-33`), which is false the moment schema validation matters.  
- **Evidence:**

```py
# dglib/validate.py
def check_schema(request_dir: str) -> list[dict]:
    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        return [_finding("schema", "SKIP", "jsonschema not installed")]
    ...

def check_decisions(request_dir: str) -> list[dict]:
    ...
    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        return [_finding("decisions", "SKIP", "jsonschema not installed")]
```

  Reproducer:

```shell
$ cd /tmp/solutions-os-mr111/.kiro/resources/data-generator/scripts
$ python3 -m pytest tests/ -q
...............FF   [100%]
FAILED tests/test_validate.py::test_decisions_valid_fixture
FAILED tests/test_validate.py::test_decisions_out_of_schema_fails
2 failed, 87 passed in 0.30s
```

  Installing `jsonschema` into a venv → **89 passed**.


- **Concrete fix (preferred — declare the dependency):**

```
# .kiro/resources/data-generator/scripts/requirements.txt
jsonschema>=4.0
```

  Update `prompt.md` / `tools/README.md` to drop the "no third-party dependencies" phrasing and mention `pip install -r .kiro/resources/data-generator/scripts/requirements.txt`. In `validate.py`, change both `except ImportError` branches from `SKIP` to a hard-fail with the install command:

```py
except ImportError as e:
    raise RuntimeError(
        "jsonschema is required to run schema/decision validation. Install it with "
        "`pip install -r .kiro/resources/data-generator/scripts/requirements.txt`."
    ) from e
```

  If a truly optional path is preferred, convert the two failing tests to `pytest.importorskip("jsonschema")` **and** add a loud line in every `dg validate` report when the check is `SKIP`ped, so a `SKIP` never renders as a PASS verdict.

## 🟡 P1 — Strongly Recommended

### P1-1. Agent JSON `prompt` URI is inconsistent with the resource URIs in the same file (Thread 1\)

- **File:** `.kiro/agents/data-generator.json:75`  
- **Impact:** All three `resources` entries use `skill://` with a repo-root-relative path. Only `prompt` uses `file://../resources/…`, a parent-relative URI. Functionally correct today (it resolves to the right file) but style-asymmetric and brittle if the agent JSON is ever moved.  
- **Evidence:**

```json
"resources": [
    "skill://.kiro/skills/data-generate-records/SKILL.md",
    "skill://.kiro/skills/data-generate-sql/SKILL.md",
    "skill://.kiro/skills/data-generate-erd/SKILL.md"
],
...
"prompt": "file://../resources/data-generator/prompt.md"
```

- **Concrete fix:**

```json
"prompt": "file://.kiro/resources/data-generator/prompt.md"
```

### P1-2. `SKILL.md` files reference workflow docs living outside the skill folder — not part of the skill's auto-loaded context (Threads 2 and 3\)

- **File:** `.kiro/skills/data-generate-records/SKILL.md:22-56`; `.kiro/skills/data-generate-sql/SKILL.md:26-59`  
- **Impact:** By Kiro convention, a skill auto-loads its own `SKILL.md` \+ `references/` folder; anything outside is not part of its inherent context. The workflow docs (`workflow/**.md`) are only reached via a runtime `read` tool call. If the agent were ever instantiated without `read`, or `read` fails at runtime, both skills silently lose \~10 workflow docs with no warning in the skill definition.  
- **Evidence:** Both SKILL.md files direct the agent to "read each doc from `.kiro/resources/data-generator/workflow/`." — a path outside `.kiro/skills/data-generate-records/references/` and `.kiro/skills/data-generate-sql/references/` respectively.  
- **Concrete fix — pick one:**  
  1. Make the runtime dependency explicit. Add to the top of each SKILL.md:

```
> **Runtime files:** this skill invokes docs under `.kiro/resources/data-generator/workflow/`.
> They are NOT auto-loaded by Kiro; the agent must have the `read` tool. If `read` fails, the
> workflow cannot proceed.
```

  2. Move the shared workflow into a shared knowledge skill (e.g., `data-generate-shared`) that both skills list as a resource. Kiro will then auto-load its `references/` for both. This mirrors the a11y suite pattern from [ADR 0001](https://gitlab.appian-stratus.com/appian/prod/solutions-os/-/blob/main/@DOCS/adr/0001-a11y-consolidation.md) and is the more durable answer.

### P1-3. `sql_emit.py` doesn't handle CDT-backed tables — `mechanism: "CDT"` payloads produce SQL that will likely be wrong

- **File:** `.kiro/resources/data-generator/scripts/dglib/sql_emit.py:97-146`  
- **Impact:** `payload-spec.schema.json` accepts `mechanism ∈ {RECORD, CDT}` and `state.schema.json` explicitly carries CDT entries in `mechanism_map`. `emit_sql` uses the `table` value verbatim in `INSERT INTO <table>` with no branch for CDT-backed tables. CDT-backed rows go through Data Store Entities: their physical table may not match the camelCase→UPPER\_SNAKE derivation, and the FK columns may differ, so a mixed manual-mode fixture with a CDT table will emit syntactically valid SQL that references the wrong (or non-existent) physical table.  
- **Evidence:**

```py
# dglib/sql_emit.py
lines.append(f"-- {table}: {len(rows)} rows")
...
lines.append(f"INSERT INTO {col_table} ({cols}) VALUES ({vals});")
# No `if mechanism == "CDT": ...` branch anywhere in emit_sql.
```

- **Concrete fix (safer landing — refuse CDT specs upfront):**

```py
# in emit_sql, after loading each spec doc:
if doc.get("mechanism") == "CDT":
    raise ValueError(
        f"{table}: gen-sql cannot emit CDT-backed inserts — CDT writes go through Data Store Entities. "
        f"Use data-generate-records for CDT rows, or split bulk into a RECORD-only batch."
    )
```

  Add a companion `test_sql_emit.py::test_cdt_spec_rejected` that asserts the raise. A follow-up MR can implement CDT-aware emission via the mapped DB table if the deployment ever needs it.

### P1-4. `check_users` is fully implemented and unit-tested but excluded from `run_validate` — user-membership violations ship silently

- **File:** `.kiro/resources/data-generator/scripts/dglib/validate.py:227-239`  
- **Impact:** The function exists and has dedicated tests (`tests/test_validate.py:78-88`), but no runtime path invokes it. A payload with a bogus username passes `dg validate` with no warning. The stated reason ("false positives on scoped raw") is sound in principle but the current outcome — silent skip with no signal at all — is worse than either enabling it with a guard or removing it.  
- **Evidence:**

```py
# dglib/validate.py
def run_validate(request_dir: str) -> dict:
    findings = []
    findings += check_schema(request_dir)
    findings += check_decisions(request_dir)
    findings += check_fk_topology(request_dir)
    findings += check_forbidden_fields(request_dir)
    findings += check_dates(request_dir)
    # NOTE: check_users() is intentionally NOT in the default aggregate — reliable user validation needs
    # type info (record_properties) for every table AND a current users.json; on scoped/historical fixtures
    # it produces false positives/negatives. It is implemented + unit-tested; enable in CI when full raw/ is captured.
    findings += reconcile_coverage(request_dir)
```

- **Concrete fix — pick one:**  
  1. Wire it in with a guard: `check_users` returns `SKIP` when `raw/users.json` is absent (it already does), and `run_validate` includes it; when it skips, mark the aggregate result as `INCOMPLETE`, not `PASS`.  
  2. Add `--strict` / `--with-users` to `dg validate` that opts users in when captures are complete.  
  3. If there is no near-term plan to enable this check, delete `check_users` \+ its tests. Dead code invites future rot.

### P1-5. `test_cli.py` covers 3 subcommands out of \~11 — the CLI wiring is largely un-tested (Thread 4\)

- **File:** `.kiro/resources/data-generator/scripts/tests/test_cli.py:1-32`  
- **Impact:** The three tests exercise parser construction and one end-to-end `plan-writes` on a fixture. The write-side subcommands (`init`, `state set`, `gate`, `coverage-gate`, `validate`, `gen-sql`, `verify-input`, `plan-footprint`, `build-footprint`, `check-fields`) are only tested at the library level, so CLI-layer contracts — argparse mutex, exit codes, `--state` / `$DG_STATE` resolution, file side effects, stderr routing — go unchecked.  
- **Evidence:** `tests/test_cli.py` contains: `test_build_parser_ok`, `test_help_does_not_crash`, `test_plan_writes_manual_fixture`. Nothing else.  
- **Concrete fix — add CLI-level smoke tests for at least the write commands:**

```py
def test_init_creates_folder(tmp_path):
    d1 = tmp_path / "d1.json"
    d1.write_text(json.dumps({"D1": {"app": "X", "entity": "T", "mode": "manual"}}))
    rc = dg.main(["init", "--request-json", str(d1), "--mode", "manual",
                  "--root", str(tmp_path), "--date-anchor", "2026-01-01", "--slug", "smoke"])
    assert rc == 0
    assert (tmp_path / "data-requests" / "2026-01-01_smoke" / "state.json").exists()

def test_gate_blocks_missing_state(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("DG_STATE", str(tmp_path / "no-such.json"))
    rc = dg.main(["gate", "--require", "0", "--then", "1"])
    assert rc == 2  # missing state -> exit 2, gate does NOT open

def test_gen_sql_writes_output(tmp_path):
    # arrange minimal bulk fixture; run gen-sql via CLI; assert out/bulk-data.sql exists and is non-empty
    ...

def test_state_set_persists(tmp_path):
    ...

def test_verify_input_prints_json_for_cdt(tmp_path):
    ...
```

  Minimum: a smoke test per `cmd_*` function in `dg.py`.

### P1-6. `dglib/` is on `sys.path` but not a package — bare `import coverage`/`state`/`validate` clash with common stdlib and third-party names

- **File:** `.kiro/resources/data-generator/scripts/dg.py:16-25`; `.kiro/resources/data-generator/scripts/tests/conftest.py:1-9`  
- **Impact:** `import coverage` collides with the popular `coverage.py` package; `import state`, `import validate` are similarly generic. If `dg.py` is ever imported into a shared interpreter that already has one of those installed, it silently picks up the wrong module.  
- **Evidence:**

```py
# dg.py:16-25
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "dglib"))
import coverage as coveragelib
import fields as fieldslib
...
from state import State, StateError
```

- **Concrete fix:** Make `dglib/` a real package:  
  1. Add an empty `.kiro/resources/data-generator/scripts/dglib/__init__.py`.  
  2. In `dg.py`, replace the `sys.path.insert` \+ bare imports with:

```py
from dglib import coverage as coveragelib
from dglib import fields as fieldslib
from dglib import footprint as footprintlib
from dglib import gate as gatelib
from dglib import scaffold as scaffoldlib
from dglib import sql_emit as sqlemitlib
from dglib import validate as validatelib
from dglib.state import State, StateError
```

  3. Simplify `tests/conftest.py` to `sys.path.insert(0, _SCRIPTS)` only; drop the `dglib/` entry.  
  4. Update intra-package imports in `dglib/*.py` (e.g., `from state import State` → `from .state import State`) to relative form.

### P1-7. `ruff.toml` ships but isn't enforced; `pytest` isn't wired to CI; 2 pre-existing `I001` violations already land in this MR

- **File:** `.kiro/resources/data-generator/scripts/ruff.toml:1-6`  
- **Impact:** The lint config is aspirational: nothing runs it. `ruff check .` from the scripts folder reports two import-order violations that are in this MR. Test results (the 87/89) are invisible to anyone who doesn't run them locally.  
- **Evidence:**

```
$ /tmp/mr111-venv/bin/ruff check .
tests/test_state.py:1:1: I001 [*] Import block is un-sorted or un-formatted
Found 2 errors.
```

- **Concrete fix — add a job to `.gitlab-ci.yml`:**

```
dg-tests:
  stage: test
  image: python:3.12-slim
  before_script:
    - pip install --quiet ruff pytest jsonschema
  script:
    - cd .kiro/resources/data-generator/scripts
    - ruff check .
    - python -m pytest tests/ -q
  rules:
    - changes:
        - .kiro/resources/data-generator/**/*
        - .kiro/skills/data-generate-*/**/*
        - .kiro/agents/data-generator.json
```

  Fold this with P0-2's `requirements.txt` and both blockers close in one commit.

### P1-8. Fixtures don't record the MCP-server version they were captured against

- **File:** `.kiro/resources/data-generator/scripts/tests/fixtures/README.md:44-48`  
- **Impact:** The fixtures README says "Re-capture whenever an MCP server version bumps" but nothing in the fixture actually records which MCP-server version produced the raw files. A future maintainer looking at `raw/record_type_map.json` cannot tell whether it's stale, and there's no signal for a CI job to compare against a pinned tag.  
- **Evidence:** Every `raw/*.json` in the three fixtures is bare data with no capture metadata; the fixture-level `state.json`/`decisions.json` carry app-level fields but no MCP image tag.  
- **Concrete fix:** Add `raw/_capture.json` per fixture:

```json
{
  "captured_at": "2026-07-21T14:03:00Z",
  "captured_by": "walid.elsayed",
  "atlas_mcp_image": "solutions-atlas-mcp-server:v<TAG>",
  "data_generator_mcp_image": "solutions-atlas-dg-mcp-server:v<TAG>",
  "app": "SourceSelection",
  "notes": "scoped to evaluation subtree"
}
```

  Then a follow-up `dg validate-fixtures` command (or a CI job) can flag captures older than N days or older than a pinned MCP tag.

### P1-9. `prompt.md` and both SKILL.md files duplicate the same 12-item CRITICAL RULES list nearly verbatim

- **File:** `.kiro/resources/data-generator/prompt.md:38-52`; `.kiro/skills/data-generate-records/SKILL.md:11-16`; `.kiro/skills/data-generate-sql/SKILL.md:14-20`  
- **Impact:** Three copies drift over time. Already SQL's SKILL.md formats rule 12 inline while the records SKILL.md formats it differently — small drift, but the pattern guarantees larger drift ahead.  
- **Evidence:** All three files contain "1. ALL application data comes from the Atlas KB and the live environment ONLY …" through "12. EVERY step writes its file on disk." with slight reformatting.  
- **Concrete fix:** Keep the canonical list in `prompt.md` (agent-level). Have each SKILL.md say "Follow the CRITICAL RULES from the `data-generator` agent prompt" and drop the duplicated list. Or promote the rules into `.kiro/resources/data-generator/references/critical-rules.md` and reference-load it from both skills.

## 🟢 P2 — Nice-to-Have Polish

### P2-1. Skill-naming convention audit

- **File:** `README.md:189-193` (post-P0-1 fix); `prompt.md:26-32`; `.kiro/skills/data-generate-*/`  
- **Impact:** Even after P0-1 removes the ghost skills, decide whether the canonical name is `data-generate-*` (skill folder \+ agent prompt) or `data-gen-*` (proposed README rename) and grep to make sure nothing lags.  
- **Evidence:** Skill folders and `prompt.md` use `data-generate-*`; the pre-fix README used `data-gen-*`.  
- **Concrete fix:** Pick one and run:

```shell
git grep -n "data-gen\b"
git grep -n "data-generate-"
```

  and align.

### P2-2. README paragraph is a single 700-character sentence

- **File:** `README.md:191-195`  
- **Impact:** The "The `data-generator` agent composes…" paragraph packs four concepts (skill composition, shared workflow, disk gates, MCP env requirements) into one sentence. Hard to skim.  
- **Evidence:** One `.` in \~700 characters.  
- **Concrete fix:** Split into three short paragraphs. Move the MCP env requirements into a bulleted list.

### P2-3. `sql_emit.sql_literal` handles a `@@FK:` prefix that `emit_sql` never produces

- **File:** `.kiro/resources/data-generator/scripts/dglib/sql_emit.py:82-83`  
- **Impact:** Dead code (or unfinished scaffolding). `emit_sql` sets FK columns via a direct dict update — `sql_literal` never sees a `@@FK:` value.  
- **Evidence:**

```py
if isinstance(v, str) and v.startswith("@@FK:"):
    return v[5:]  # already a raw SQL expression (a @var reference)
```

  `emit_sql` writes `colvals[column_for(fk["field"], field_map)] = pvar`; there's no code path that produces `@@FK:` inputs to `sql_literal`.


- **Concrete fix:** Remove the branch, or document the intended use case (e.g., "reserved for future template-level FK expression injection") and add a test.

### P2-4. `_gen_value` seeds its RNG from `f"{seed}:{field}:{i}"` — a field rename changes generated values

- **File:** `.kiro/resources/data-generator/scripts/dglib/sql_emit.py:57-72`  
- **Impact:** Deliberate design (different fields → different value streams), but silent when a "cosmetic" rename shifts fixture bytes.  
- **Evidence:**

```py
if g == "int":
    if "min" in spec and "max" in spec:
        rng = random.Random(f"{seed}:{field}:{i}")
```

- **Concrete fix:** Add a note under `payload-spec.schema.json`'s `template.additionalProperties.gen` block: "Determinism is seeded by `(run seed, field name, row index)`. Renaming a field produces a different value stream even with the same run seed."

### P2-5. `pick` vs `cycle` determinism note in the spec schema

- **File:** `.kiro/resources/data-generator/scripts/dglib/schemas/payload-spec.schema.json:37`  
- **Impact:** Both generators return the same value for the same `(seed, field, i)` today (correct), but users may miss that `pick` is seeded RNG and `cycle` is index arithmetic — swapping them changes both value distribution and stability characteristics.  
- **Evidence:** The spec description groups them as siblings without noting the mechanism difference.  
- **Concrete fix:** One sentence in the schema description: "`cycle` picks values by `i % len(values)`; `pick` uses a seeded RNG. Both are deterministic given the same seed but produce different sequences."

## Files Touched by the MR

| File | Delta | What changed |
| :---- | ----: | :---- |
| `.gitignore` | \+3 / −0 | Adds `data-requests/` to ignore runtime request folders. |
| `README.md` | \+13 / −0 | Adds "Data Generation Skill Suite" section — inaccurate; see P0-1. |
| `.kiro/agents/data-generator.json` | \+76 / −0 | New agent definition, three skill resources, two MCP servers, `prompt` URI needs style fix (Thread 1 / P1-1). |
| `.kiro/skills/data-generate-records/SKILL.md` \+ `references/create-records.md` | \+2 files (new) | Live-records skill; workflow-path concern (Thread 2 / P1-2). |
| `.kiro/skills/data-generate-sql/SKILL.md` \+ `references/generate-sql.md` | \+2 files (new) | Bulk SQL skill; same workflow-path concern (Thread 3 / P1-2). |
| `.kiro/skills/data-generate-erd/SKILL.md` \+ `references/generate-erd.md` | \+2 files (new) | ERD skill; delegates to DG MCP tools. |
| `.kiro/resources/data-generator/prompt.md` | \+132 / −0 | Agent-level prompt; rules duplicated with SKILL.md (P1-9). |
| `.kiro/resources/data-generator/scripts/dg.py` | \+337 / −0 | CLI dispatcher; bare-import concern (P1-6); CLI-test gap (P1-5). |
| `.kiro/resources/data-generator/scripts/dglib/*.py` | 9 files (new, \~1,150 lines) | Deterministic engine: `state`, `gate`, `scaffold`, `coverage`, `fields`, `footprint`, `validate`, `sql_emit`. See P0-2 (jsonschema), P1-3 (CDT), P1-4 (users). |
| `.kiro/resources/data-generator/scripts/dglib/schemas/*.json` | 5 files (new) | JSON schemas for decisions, payload files, payload specs, metadata, state. |
| `.kiro/resources/data-generator/scripts/dglib/config/thresholds.json` | \+7 / −0 | Coverage %, rounding, per-file record cap, live-record limit, bulk-min-rows. |
| `.kiro/resources/data-generator/scripts/tests/*.py` | 10 files (new, \~700 lines) | pytest suite; CLI coverage sparse (P1-5); default fails without jsonschema (P0-2). |
| `.kiro/resources/data-generator/scripts/tests/fixtures/**` | \~47 files (new) | Three golden request-folder fixtures; missing MCP-image metadata (P1-8). |
| `.kiro/resources/data-generator/scripts/ruff.toml` | \+6 / −0 | Lint config, unenforced (P1-7). |
| `.kiro/resources/data-generator/scripts/.gitignore` | \+5 / −0 | Ignores `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `.venv/`. |
| `.kiro/resources/data-generator/tools/*.md` | 3 files (new) | MCP \+ `dg` CLI tool-reference catalogs. |
| `.kiro/resources/data-generator/workflow/**.md` | 10 files (new) | Manual (`step-0`, `step-1..5`, `step-4b`) and auto-analysis (`auto-1..4`) workflow docs. |

## Verification Checklist for the Author

- `pip install -r .kiro/resources/data-generator/scripts/requirements.txt && python3 -m pytest .kiro/resources/data-generator/scripts/tests/ -q` → **89 passed** (once P0-2 is applied and `jsonschema` is declared)  
- `python3 .kiro/resources/data-generator/scripts/dg.py --help` → prints help for all 11 subcommands with no argparse crash  
- `python3 .kiro/resources/data-generator/scripts/dg.py init --request-json <path> --mode manual --root /tmp/dg-smoke --slug smoke --date-anchor 2026-01-01` → creates `/tmp/dg-smoke/data-requests/2026-01-01_smoke/{state.json,decisions.json,payloads/,raw/,reports/}`  
- `python3 .kiro/resources/data-generator/scripts/dg.py gen-sql --dir .kiro/resources/data-generator/scripts/tests/fixtures/sourceselection-bulk` → writes `out/bulk-data.sql` byte-identical to the committed golden  
- `ruff check .kiro/resources/data-generator/scripts/` → 0 findings (after P1-7 pass fixes the 2 `I001` issues)  
- README's Featured Tools table entries (post P0-1) resolve to real skill folders: `for name in data-generate-records data-generate-sql data-generate-erd; do ls .kiro/skills/$name/SKILL.md; done` → all three files exist  
- Agent JSON validates: `python3 -c 'import json; json.load(open(".kiro/agents/data-generator.json"))'` → no exception, and `resources` array length equals the number of skills advertised in the README (3)

