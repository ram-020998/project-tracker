# 55-12 — Release and onboarding

> **Status:** DONE 2026-11-24 — §1–§2 (As run, genesis-release): genesis v0.84.0 and genesis-workflows v0.28.0 released
> and deployed; §3 write-back done by genesis-docs 2026-11-24 (`progress/phase-55-workflow-execution.md`).
> **Phase 55's live acceptance (55-11 §3, A1–A14) is open**. Was: §1–§2 DONE 2026-11-24 (As run, genesis-release): genesis v0.84.0 and genesis-workflows v0.28.0 released
> and deployed; **Phase 55's live acceptance (55-11 §3, A1–A14) is open**. §3 is genesis-docs'. Spec-drafted
> 2026-11-22. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-55-workflow-execution.md`. After 55-11 = SHIP on its review and gates (D37: the user's live acceptance
> follows the release). **genesis-release** asks before every tag and push; then **genesis-docs** does the write-back.

## 1. Release order (one release)

1. **genesis v0.84.0** (or the next minor if a v0.83.x patch moved it): the version in the `pyproject.toml` files of
   the app and the three packages (one shared version, ADR-080), `create_app`, `web/src/version.ts`; a migration only
   if 55-08 recorded one (none expected: 55-07 needed none, D24; DB stays v30); fastembed as a core dependency and the pinned model checksum; `npm run build` + commit
   `web/static/` as separate steps (L-089); verify the release commit holds every changed file (L-056), fixtures and
   migration included; one CI run before the release commit (L-112); tag; push on the user's go-ahead; CI green
   (packages, genesis, frontend, clean-install). If no web file changed in a follow-up tag, force the frontend job with
   a real `web/**` touch (L-030).
2. **genesis-workflows v0.28.0:** every adopted workflow's bump (55-10); the pins **and** `registry.json`
   `genesis_core_version` move to `genesis.git@v0.84.0` together (`#subdirectory=packages/<name>`, L-057); a CI-image
   run before the release commit (L-112); CI green. Release note: the adopted workflows need genesis ≥ 0.84.0 (the
   major-only gate, ADR-019, does not stop an older app from loading them, where the escalation gate fails).
   **From 55-13 (review m1/m3):** in the same library commit as the pin move, `ci/validate_library.py` step 3 calls
   `genesis.lint.check_node_models(compiled, meta)` beside `check_required_mcp` (every `META.models` key is an agent
   node of the compiled graph); it exists only from the 55-13 genesis commits, so not before the pins name v0.84.0.
3. Never read CI variables through the API (L-100).
3b. **Known CI risks at the tag (55-10 CI-image run):** the two arm64-only `test_sail_cli` failures (as at 54-11);
   `test_document_records` failed once in the full genesis suite in the python:3.13 image and passed alone, with no
   failure message captured — **run the full genesis suite in the CI image at the release commit and capture its
   assertion**; if it fails, stop and ask the user (do not re-tag or skip it). The library's last commit after
   `1d3b9ea` ran only locally, so the library also gets an image run at its release commit against the v0.84.0 pins
   (L-112).
4. State in the release notes, README row and state that **Phase 55's live acceptance (55-11 §3, A1–A14) is open**
   and run by the user after the release, findings as v0.84.x patches (D36, D37, L-111); the umbrella status reads
   `SHIPPED (live acceptance open)`. Also state that the Phase 51 / 53 / 54 live acceptance is still open (D11, L-111).

## 2. Deploy

Never restart while a run is active. Before deploying, note the fleet's state (D34): main (:8760) already runs the
unreleased Phase 55 build, userb (:8761) the v0.83.0 server with the new web bundle (its Run Detail graph and Documents
are broken until this deploy); both come to v0.84.0 here. Fleet: `gsm stop --all`; then, because `gsm provision`
installs only the workflow library and does **not** run the install script (corrected at the write-back from the As
run), `scripts/install-packages.sh --editable --dev` in the dev venv (installs `fastembed`, fetches the embedder model
and back-fills memories for the default state dir, main) and `gsm exec userb -- memory fetch-model` / `memory reembed`
for userb; then `gsm provision --all --no-mcp --no-env --force` and `gsm start --all`; update every workflow from Catalog on each instance (L-033); **turn the `memory-consolidation` and
`memory-maintenance` schedules back on on both instances** once the library release with `memory_brief: false` is
installed (they were turned off for the build, D18); check `/openapi.json` `info.version`, the DB version and the embedder state. User
checklist in the release notes:
- Each run with an agent step now starts with a memory brief (`_memory/brief.md`, listed under Inputs); your personal
  memories are included for your own runs and never published to the Hub.
- The install and the in-app updater now download the embedding model once (~67 MB, `qdrant/bge-small-en-v1.5-onnx-q`
  from huggingface.co, checksums pinned in `genesis/memory/model.py`); a failed download only warns and briefs fall
  back to keyword and entity matching; `genesis memory reembed` back-fills, `genesis memory status` shows the state.
- The memory MCP server now opens `memory.db` read-only (chat too).
- Escalations: open the **Resolve** tab on the run; the agent explains and proposes, you confirm. Rerun and Restart
  from a step move the feature stage (or story) to the new run and end the old run Cancelled; they are offered only
  for workflows marked relaunchable (story-implementation is not: re-run it from the Implementation lane). Reject at an old
  gate now ends the run **failed**, not done. **Known limitation (D35):** a run started on a workflow version from
  before this release escalates through its old gate; answer it from the Flow tab's gate panel, not Resolve's buttons,
  and update your workflows from Catalog.
- The Documents tab is reorganized by step and type; tool-output files are still removed at the end of a run, and
  their group then disappears; System files are no longer listed.
- Workflow authors can set a model per agent step (`META.models`, `META.default_model` in `workflow.yaml`); a model
  your Kiro account lacks falls back to the next one, with a note on the turn.
- The run graph shows the node that is really running; **Live / Reconnecting / Polling** shows the connection.

## 3. Write-back (genesis-docs)

Gather the lesson candidates and code-map changes from every As built (55-03's: spike the real stream before
designing on it, the `__interrupt__` chunk swallowed on every gate; an unread stderr PIPE blocks the child; a count
on a node and its incoming edge share one rule; from D19: evidence of a memory feature carries the user's memories —
redact before committing, since deleting later leaves the text in history; 55-06's: a fork copies the state that made
the run fail, a path built from an id is a path, a loop variable shadowing a binding). Update the reliability
standard / `docs/architecture` text that names `hitl_gate` as the escalation target, and L-106 (every answer routed,
now by the standard gate). Document the new workflow `META` keys for authors (the library steering and the
`genesis-workflow-authoring` skill): `artifacts` map form, `relaunchable` / `relaunch_hint`, `memory_brief`, `models` /
`default_model` (D29).

File ADR-088, ADR-089 and ADR-090 from `adr-drafts.md` into `reference/decision-log.md` (amendment links on ADR-011,
ADR-031, ADR-033, ADR-053, ADR-054); update L-005 (`node.started` canonical) and add the phase's lesson candidates from
the As builts; areas (`context/areas.toml`: new paths such as `genesis/genesis/runs/snapshot.py`,
`genesis/genesis/runs/documents.py`, `genesis/genesis/memory/brief.py`, `genesis/genesis/mcp/resolve_server.py`,
`packages/genesis-core/genesis_core/nodes/escalation.py`); code map; `context/state/current.md`; progress
`progress/phase-55-workflow-execution.md`; changelog; README row; tracker §6; backlog
`specs/backlog/phase-55-follow-ups.md` (55 umbrella §9 deferred items). `genesis-ctx lint` green.

## As run (2026-11-24, genesis-release)

**§1 and §2 are done; §3 is genesis-docs'.** 55-11 was SHIP on its review and gates at genesis `e8096f71`. Phase 55's
live acceptance (55-11 §3, A1–A14) is open: the user runs it on the released fleet afterwards, and findings ship as
v0.84.x patches (D36, D37, L-111). The user confirmed every push and every tag below, one at a time, and the deploy.
All CI ran between 10:30 and 17:30 UTC, outside the D27 window (18:30–20:30 UTC).

### Versions

| Repo | Version | Tag | Tagged commit |
|---|---|---|---|
| genesis | 0.84.0 (the app and the three packages; `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged; no migration, DB v30; `fastembed==0.7.4` core dependency, model checksums pinned in `genesis/memory/model.py`) | `v0.84.0` | `d6cea8db` (release commit `3e1effaf` + the 55-14 fixes `ad8f7eda`, `9cd33d52`, `d6cea8db`) |
| genesis-workflows | 0.28.0 (the 55-10 adoption `60c12f3`, `1d3b9ea`, `4bc7168`, `3c29e73`; pins and `genesis_core_version` on v0.84.0; `check_node_models` in `validate_library`) | `v0.28.0` | `2017afb` |
| playwright-appian | not released (unchanged at 0.3.1) | — | — |

### CI pipelines

| Repo | Pipeline | Ref / sha | Result |
|---|---|---|---|
| genesis | #7556336 | `master` `3e1effaf` | **red**: `genesis` 2 failed, 2336 passed, 72 skipped (`test_document_records` and an apwt reap test, below); the other five jobs green |
| genesis | #7559966 | `master` `d6cea8db` | green: the four package jobs (`genesis` 2346 passed, 72 skipped); `frontend` and `clean-install` not triggered (no web or script change since #7556336, where both were green on the same bundle) |
| genesis | #7560648 | tag `v0.84.0` (`d6cea8db`) | green, all six jobs; `genesis` 2346 passed, 72 skipped |
| genesis-workflows | #7561555 | `master` `2017afb` | green: library-validate (gate 9; pip installed genesis, genesis-core, kiro-agent-sdk, genesis-appian-parser 0.84.0 and genesis-workflows 0.28.0 from the real pins; LIBRARY VALIDATION PASSED, 19), skills-validate, workflow-tests (678 passed) |
| genesis-workflows | #7561788 | tag `v0.28.0` (`2017afb`) | green, all three jobs |

### What happened, in order

1. **genesis release commit `3e1effaf`.**
   - Bump: 0.84.0 in the root and the three `packages/*/pyproject.toml`, the parser `__version__`, `create_app` and
     `web/src/version.ts` (`test_version_sync` 6 passed; no other `0.83.0` outside docs). The README status now names
     Phase 55, says its live acceptance is open and states the D35 old-gate limitation.
   - `npm run build`, then the commit, each in its own message (L-089). The commit holds 8 source files and 66
     `web/static` files (`git show --stat -- web/static`). A fresh build afterwards left `git status --short
     --untracked-files=all` empty (own message).
   - Local gates on the bumped tree: web lint 0 errors (the 20 old warnings), typecheck clean, vitest **1051 passed (86
     files)**; ruff clean on CI's targets for all four packages. (`ruff check .` in `packages/genesis-core` reports 5
     pre-existing findings in its `tests/`; CI lints only `genesis_core`.)
   - **CI-image run at `3e1effaf`** (colima arm64 `python:3.13`, `git archive`, `install-packages.sh --editable --dev
     --no-model`, no `--init`): genesis ruff clean, **2336 passed, 72 skipped, 2 failed** (the two known arm64-only
     `test_sail_cli` tests); **`test_document_records` passed** (all 46 of its tests); genesis-core 173, kiro-agent-sdk
     302; the parser failed `test_parse_returns_populated_result` (179 bundles where 174 are expected; the known
     filesystem-order bug, `phase-54-follow-ups.md` §2, parser unchanged since v0.83.0). The parser passed on the amd64
     runner in all three genesis pipelines.
2. **`master` pushed (`bd99ee7c..3e1effaf`, 52 commits) → #7556336 red.** The `genesis` job failed two tests:
   - `tests/test_document_records.py:325`
     `test_a_run_records_every_write_with_its_step_execution_and_attempt`:
     `assert [('tick', 1)] == [('tick', 1), ('tick', 2)]` ("Right contains one more item: ('tick', 2)"). The fixture's
     `tick` node writes `round.json` twice, `"1"` then `"2"` (1 byte each). The worker's change snapshot keyed only on
     `(st_size, st_mtime_ns)` (`genesis/runs/writes.py:87`), and Linux file timestamps are coarse, so the second write
     was not seen: the same-size, same-tick case the 55-10 review suspected (m5). A real recording gap, hidden on
     macOS by nanosecond timestamps.
   - `tests/test_apwt_client.py::test_open_records_the_daemon_and_reap_stops_it[open_host_not_allowed]`:
     `assert reap(client.pid_dir) == [daemon.pid]` → `assert [] == [410]`.
   - No tag existed, so nothing was re-tagged. The user chose to fix before tagging (D39, option A); sub-spec 55-14.
3. **55-14 fixes (genesis-dev, review SHIP at `d6cea8db`; detail in `55-14-release-blockers.md` and
   `reviews/55-14-review.md`):** `ad8f7eda` (files up to 1 MiB also carry a 64-bit blake2b content key; over 1 MiB,
   ctime and inode are compared; a per-tracker hash memo), `9cd33d52` (reap re-reads a live group with no marker once,
   after 0.25 s: right after `Popen`, Linux can show an empty `/proc/<pid>/cmdline`), `d6cea8db` (the over-the-bound
   tests wait for the next ctime tick). The reviewer's condition, a full suite in the CI image under `docker run
   --init`, was met by the dev's run at `d6cea8db`: 2 failed (the two `test_sail_cli`), 2344 passed, 72 skipped
   (`evidence/55-14/reap-probes-and-gates.txt`). The reap fix rests on a probe of the race; the test itself could not
   be made to fail on the old code. No test was changed, skipped or marked to pass.
4. **`master` pushed (`3e1effaf..d6cea8db`) → #7559966 green**; tag `v0.84.0` (annotated) created on `d6cea8db`
   (`rev-list` checked in its own message), pushed → **#7560648 green**, all six jobs.
5. **genesis-workflows release commit `2017afb`:** `pyproject.toml` 0.28.0; all four pins on `genesis.git@v0.84.0`
   (`genesis-core`, `kiro-agent-sdk`, dev `genesis-appian-parser` with `#subdirectory=packages/<name>`, dev `genesis`
   without; L-057); `registry.json` `genesis_core_version` 0.84.0, `genesis_core_major` stays 1;
   `ci/validate_library.py` step 3 calls `genesis.lint.check_node_models(compiled, meta)` beside
   `check_required_mcp` (55-13 m1/m3). The library's CI does not run `genesis test-workflow`, so `validate_library` is
   where the models-key check runs in CI. Negative control: on hello-appian's compiled graph a `models` key naming a
   non-agent node is reported ("… which is not an agent node of the graph (agent nodes: make_result)").
   Local gates (dev venv): `validate_library` PASSED (19), `check_internal_pins` PASSED, `validate_skills` PASSED (5),
   pytest **678 passed**. The workflow content was in 55-10's commits, reviewed in 55-10 and 55-11.
   - **L-112 image run not completed.** Two runs in colima `python:3.13` (genesis from `git archive v0.84.0`, library
     `--no-deps`) passed gate 9 and then stalled in `pip install`: PyPI from inside colima ran at about 41 kB/s, and
     one run failed on read timeouts while building genesis-core's build dependencies. The user waived the image run
     and asked to verify in CI: #7561555 installed the real pins from the tag and passed every job, so the library's
     first Linux run was its master pipeline.
   - `master` pushed (`9066541..2017afb`) → **#7561555 green**; tag `v0.28.0` (annotated) on `2017afb`, pushed →
     **#7561788 green**.
6. **Deploy (§2, the user's go-ahead), 22:51–23:10 IST (17:21–17:40 UTC).**
   - **Before:** main (pid 29495, the unreleased Phase 55 build) and userb (pid 24429, the v0.83.0 server with the new
     bundle, D34) both healthy and reporting 0.83.0; 0 running and 0 non-terminal runs on each; `memory-consolidation`
     and `memory-maintenance` off on both (D18).
   - **Deviation from §2: `gsm provision` does not run the install script.** It runs only `genesis install --from
     <genesis-workflows checkout>` (`genesis_fleet/manager.py:131-146`). The dev venv had no `fastembed`, and neither
     instance had a `models/` folder. So the deploy ran the install script itself and fetched userb's model by hand
     (steps below, confirmed by the user).
   - **Backup** `/tmp/genesis-release-55-12/backup/20261124-225106/` (mode 700; `/tmp/genesis-release-55-12/backup.py`,
     SQLite online backup from a read-only source, L-125): main `genesis.db` integrity ok, v30, 510 runs, `memory.db`
     ok; userb ok, v30, 157 runs, `memory.db` ok; each `installed.lock.json`.
   - `gsm stop --all` (ports 8760/8761 free, both pids gone, checked in its own message).
   - `scripts/install-packages.sh --editable --dev` in the dev venv: installed `fastembed-0.7.4` (onnxruntime 1.32.0,
     tokenizers 0.23.3, numpy 2.5.5, …) and the four packages at 0.84.0; fetched the model into
     `~/.genesis/models/bge-small-en-v1.5` ("fetched 5, already present 0", checksums checked); "embedded 66 memories
     with BAAI/bge-small-en-v1.5" (main). Log: `/tmp/genesis-release-55-12/install-packages.txt`.
   - userb: `gsm exec userb -- memory fetch-model` ("fetched 5") and `memory reembed` ("embedded 0": userb has no
     memories).
   - `gsm provision --all --no-mcp --no-env --force`: 19 workflows on each instance from the checkout at `v0.28.0`
     (clean; ref `local`), e.g. hello-appian 0.2.0, erd-generation 1.2.0, memory-consolidation/maintenance 0.2.0,
     agent-prompt 0.2.0, story-implementation 0.2.0. This replaces the Catalog update (same library, same versions, as
     at 54-11). The installed memory jobs carry `memory_brief: false` on both instances.
   - `gsm start --all`: main pid **6318**, userb **6321**.
   - **After, on both instances:**
     - `/openapi.json` `info.version` **0.84.0**;
     - `gsm exec <name> -- db status`: schema **v30**, nothing pending, `memory.db` v1;
     - `memory status`: embedder `fastembed BAAI/bge-small-en-v1.5 (384-d)` in the instance's `models/`; main
       `{'embedded': 66}`, userb no memories;
     - `/api/catalog`: 19 workflows at the v0.28.0 versions;
     - Run Detail through its routes (the latest run: main `r-99d90fe763dd` story-design-analysis, userb
       `r-c6d5883b97fd`): `/api/runs/{id}`, `/snapshot`, `/documents`, `/steps`, `/resolve/escalation`, `/resolve`
       all 200; the SPA at `/runs/{id}/resolve` serves the released bundle (`assets/index-x-n-cyBl.js`, the same as
       the committed `web/static/index.html`). This is API and bundle only; nobody looked at the page in a browser.
     - **Memory schedules back on** (D18), after the `memory_brief: false` workflows were installed: `PUT
       /api/schedules/{id} {"enabled": true}` → 200 for main 3, 4 and userb 4, 5; each reads enabled, state active;
       next consolidation 2026-11-25 02:00 IST, next maintenance 2026-11-29 03:00 IST (consolidation catches up from
       its cursor);
     - 0 `Traceback` / `ERROR` / `WARNING` / "database is locked" lines in either log since this start; 0 running runs
       afterwards.

### Release notes (the user checklist)

- **Versions:** genesis **v0.84.0** (no migration, DB v30), genesis-workflows **v0.28.0**. The adopted workflows need
  genesis ≥ 0.84.0. The major-only gate (ADR-019) does not stop an older app from loading them, and there the
  escalation gate fails.
- **Live acceptance is open.** Phase 55's live acceptance (55-11 §3, A1–A14) has not been run; the user runs it after
  the release, and findings ship as v0.84.x patches (L-111). The candidate at `/tmp/gr-55-11/` was built from
  `76b27a57`: rebuild it from `v0.84.0` before using it. Phase 51 (51-12 steps 1–27), Phase 53 (53-11 §5) and the
  Phase 54 rows not run (54-10 round 2) stay open as before.
- **Memory brief:** each run with an agent step now starts with a memory brief (`_memory/brief.md`, listed under
  Inputs). Your personal memories are included for your own runs and never published to the Hub. The memory jobs opt
  out (`memory_brief: false`).
- **Embedding model:** the install and the in-app updater now download the model once (~67 MB,
  `qdrant/bge-small-en-v1.5-onnx-q` from huggingface.co, checksums pinned in `genesis/memory/model.py`). A failed
  download only warns, and briefs fall back to keyword and entity matching. `genesis memory reembed` back-fills, and
  `genesis memory status` shows the state. On the fleet, each instance has its own copy in `<state dir>/models/`.
- The memory MCP server now opens `memory.db` read-only (chat too).
- **Escalations:** open the **Resolve** tab on the run. The agent explains and proposes, and you confirm.
  - Rerun and Restart from a step move the feature stage (or story) to the new run and end the old run Cancelled.
    They are offered only for workflows marked relaunchable: agent-prompt, code-review, feature-breakdown-analysis,
    generate-business-map, hello-appian, story-design-analysis, technical-design-analysis, test-design-analysis,
    ux-design-analysis. The others (action-capture, erd-generation (D32), the memory jobs, setup-composer,
    story-implementation, story-verification, sync-application, sync-documents, test-execution) show them disabled
    with a hint; re-run story-implementation from the Implementation lane.
  - Reject at an old gate now ends the run **failed**, not done. story-implementation's bare reject (and stop) ends
    `failed` with no Dev write; `PROCEED_ANYWAY` / `SEND_BACK` appear only after a reverify with gaps.
    story-verification's stop goes through cleanup (QA sessions closed, passwords scrubbed) and the card stays in
    Verification. The memory jobs offer a credit-free **Skip** when the failed step wrote nothing usable.
  - **Known limitation (D35):** a run started on a workflow version from before this release escalates through its
    old gate. Answer it from the Flow tab's gate panel, not Resolve's buttons, and update your workflows from Catalog.
- **Documents tab:** reorganized by step and type. Tool-output files are still removed at the end of a run, and their
  group then disappears; System files are no longer listed. A file rewritten with the same size is now counted
  (55-14); over 1 MiB, a same-size rewrite in place within one ctime tick can still be missed, and a chmod counts as a
  write.
- **Models per step:** workflow authors can set a model per agent step (`META.models`, `META.default_model` in
  `workflow.yaml`). A model your Kiro account lacks falls back to the next one, with a note on the turn. The library's
  CI checks that every `models` key names an agent node.
- **Run graph:** it shows the node that is really running; **Live / Reconnecting / Polling** shows the connection.

### Deferred / follow-ups

- **project-tracker is not pushed.** It holds the whole phase's local commits plus this As run; it waits for the
  user's go-ahead.
- **The fleet deploy step in this spec and the genesis-release skill is wrong:** `gsm provision` installs only the
  workflow library; it does not run `install-packages.sh`, so it neither installs new Python dependencies nor fetches
  the model, and the script fetches the model only for the default state dir. For the skill (genesis-docs): a release
  that adds a Python dependency or a state-dir asset runs `scripts/install-packages.sh --editable --dev` while the
  fleet is stopped, then `gsm exec <other> -- memory fetch-model` / `reembed` for every non-default instance; or
  `gsm provision` grows that step (genesis-fleet backlog).
- **The dev venv ran without fastembed** from 55-04 until this deploy: main's briefs used keyword and entity matching
  only, and its memories had no vectors. Lesson candidate: after a dependency change, re-run the install script in the
  venv the fleet uses (L-099: the editable venv makes code live at commit, not dependencies).
- **L-112 for the library:** the colima image run could not install from PyPI (41 kB/s, read timeouts); the user
  waived it for the master pipeline. Lesson candidate: keep a pip cache (or a pre-built image) under `/tmp/colima` for
  image runs, so a slow network does not block the release.
- **Lesson candidate:** the shell guard reads a container path in a `docker run … bash -c "… > /out/x"` redirect as a
  host path and refuses it; use `docker logs` or redirect inside the script.
- Pre-existing, unchanged: the parser bundle-order bug (`phase-54-follow-ups.md` §2; red in colima, green on amd64);
  the two arm64-only `test_sail_cli` tests; 5 ruff findings in `packages/genesis-core/tests/` (CI lints only
  `genesis_core`); D38's m5, m6, n3, n4 in `phase-55-follow-ups.md` §4; Phase 54 backlog §5 closed by 55-14.
- **Scratch for the user to delete:** `/tmp/colima/gr-55-12/` (release-tree copies, image logs and the CI trace
  `ci-7556336-genesis.txt`; no secrets) and its `pipcache/`; `/tmp/genesis-release-55-12/install-packages.txt`. The
  backup in `/tmp/genesis-release-55-12/backup/` holds your databases: keep it until you are happy with v0.84.0, then
  delete it. Three containers that are not this release's (`intelligent_mendel`, `priceless_beaver`,
  `peaceful_colden`) were running in colima throughout and were left alone.
- **For genesis-docs (§3):**
  - `context/state/current.md`: genesis v0.84.0, genesis-workflows v0.28.0, playwright-appian v0.3.1 (unchanged); DB
    v30 (m0001–m0030), `memory.db` v1.
  - Fleet: main + userb on v0.84.0 / DB v30 from the editable dev venv, with fastembed and the model in each state dir;
    19 workflows (v0.28.0); memory schedules on; skill `appian` 1.0.0 unchanged.
  - Test counts: genesis app CI **2346 passed + 72 skipped** (#7560648), local 2414 passed + 4 skipped (55-14, at
    `9cd33d52`); genesis-core **173**; kiro-agent-sdk **302**; parser all passed + 1 skipped on CI; web vitest
    **1051 (86 files)**; workflows pytest **678**, `validate_library` **19**, `validate_skills` **5**.
  - The umbrella status reads `SHIPPED (live acceptance open)`; the README row and state say the Phase 55 live
    acceptance is open (L-111).
- **Process:** no L-089 batching of dependent steps: bump, build, commit, rebuild and status, push and pipeline,
  tag and `rev-list`, backup and listing, stop and port check, install, fetch, provision, start and checks each went
  in their own message.

## Context manifest

```toml
areas    = ["release-ci", "distribution"]
adrs     = ["ADR-019", "ADR-046", "ADR-080"]
lessons  = ["L-030", "L-033", "L-056", "L-057", "L-089", "L-100", "L-111", "L-112"]
docs     = ["tracker:specs/phase-55-workflow-execution/adr-drafts.md", "tracker:specs/phase-54-schedules-and-fixes/54-11-release-and-onboarding.md"]
code     = ["genesis/pyproject.toml", "genesis/scripts/install-packages.sh", "genesis-workflows/registry.json"]
upstream = ["55-11", "55-13", "55-14"]
```
