# Phase 55 — Workflow execution: memory brief, agent-assisted escalation, Documents and a reliable run graph — as built

> **Status:** 🚢 SHIPPED (live acceptance open) 2026-11-24 · genesis **v0.84.0** (tag on `d6cea8db` = release commit
> `3e1effaf` + the 55-14 fixes; the app and the three packages at 0.84.0, `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1
> unchanged; `fastembed==0.7.4` a core dependency) → genesis-workflows **v0.28.0** (`2017afb`; every workflow bumped a
> minor; all internal pins on `genesis.git@v0.84.0`) · playwright-appian unchanged at v0.3.1 · no migration (DB v30;
> memory.db v1) · **ADR-088** (amends ADR-053, ADR-054), **ADR-089** (amends ADR-011, ADR-031, ADR-033) and
> **ADR-090** Accepted. **Live acceptance is open** (55-11 §3, A1–A14; the user runs it after the release, D36, D37;
> findings as v0.84.x patches); the Phase 51/53/54 acceptance is still open too.
> Spec: `specs/phase-55-workflow-execution.md` + `55-01..55-14` (each with its As built; 55-12 has the As run).
> Reviews: `specs/phase-55-workflow-execution/reviews/`. Follow-ups: `specs/backlog/phase-55-follow-ups.md`.
> CI: genesis master #7556336 (red, below), master #7559966 and tag #7560648 (all six jobs green, 2346 passed + 72
> skipped); genesis-workflows master #7561555 and tag #7561788 (green; library-validate installed the real pins).

## What changed

- **For a user:**
  - Every run with an agent step starts with a **memory brief** (`_memory/brief.md`, listed under Inputs): shared
    memories and your personal ones, never published to the Hub. Agent steps also get the read-only memory tools.
  - The install and the in-app updater download the embedding model once (about 67 MB, checksums pinned). A failed
    download only warns; `genesis memory reembed` back-fills and `genesis memory status` shows the state.
  - **Escalations** open a **Resolve** tab in Run Detail (the bell links to it). A run-bound agent explains the failure
    and proposes actions; you confirm retry with guidance, accept, fix then accept, rerun from the start with
    additional instructions, restart from a step, or stop. Rerun and restart move the stage or story to the new run
    and end the old one Cancelled, and are offered only for workflows marked relaunchable. Reject at an old gate now
    ends the run **failed**, not done.
  - The **Documents** tab is grouped by step or by type, with each file's step, time, size and write count; System
    files are hidden and spent tool outputs disappear after the run.
  - The **run graph** shows the node that is really running, with status-tinted cards and a Live / Reconnecting /
    Polling badge; authors can set a model per agent step and an unavailable one falls back with a note on the turn.
- **For a developer:** `node.started` from LangGraph's `tasks` stream; `runs/snapshot.py` (the fold) with
  `GET /runs/{id}/snapshot` and the hint stream `GET /runs/{id}/live`; `runs/writes.py` (`file.written` from a
  per-task diff, content-keyed up to 1 MiB), `runs/documents.py`, `runs/artifact_roles.py` with
  `GET /runs/{id}/documents`; genesis-core `nodes/escalation.py` (`escalation_gate`), lint rule F8; run actions
  `relaunch`, `restart_from(from_step=)`, `fix_and_accept`, `runs/bindings.py`, `runs/relaunch_policy.py`,
  `RunStore.claim_transition`; the `run_resolve` chat mode, `chat/resolve.py`, `mcp/resolve_server.py`,
  `api/resolve_routes.py`, the `EscalationNotifier`; `memory/brief.py`, `memory/model.py`, `kiro_node(memory=)`;
  genesis-core `agents/models.py` with `runs/node_models.py`; `genesis/testing/escalation.py` (the gate route-test
  harness). New canonical events: `node.started`, `file.written`, `memory.brief`, `run.relaunched`, `model.fallback`.
  Code map: `bible/03` "Phase 55" block. Architecture docs: genesis `14721760` (local).
- **For a workflow author:** `META.artifacts` as a role map, `relaunchable` / `relaunch_hint`, `memory_brief`,
  `models` / `default_model` (`reference/workflow-authoring-standard.md` §2.1, the `genesis-workflow-authoring`
  skill); one `escalation_gate("escalate", …)` per workflow (`reference/reliability-standard.md` §5).

## Delivered (by sub-spec)

| Sub-spec | Result | Commits |
|---|---|---|
| 55-01 | Findings; decisions D1–D40 (Q&A and build rulings); defaults F1–F15 | — |
| 55-02 | `/dev/phase-55` mockups of six surfaces from real run data; probe 186 entries clean; user review D12–D15 (Resolve as a tab, Rerun with instructions, restart rebinds); review SHIP (re-run 1) | genesis `7f32ac0..d0aa1b2` (12) |
| 55-03 | `tasks` stream → `node.started`; snapshot fold + `/snapshot`; hint SSE `/live`; bounded bus; pump logging; stderr drain; graph web on the snapshot; the `__interrupt__` bug found by the spike; review SHIP (re-run 1); D16 | genesis `793c04b6..29775149` (5) |
| 55-04 | Run description, prefetch, `memory.brief`, the prompt line, the memory MCP on agent nodes, the pinned bge-small model, install step and back-fill, read-only memory server, fork copy; review SHIP; D17 | genesis `d1ab6d13`, `419d8363` |
| 55-05 | `file.written` from the worker's task start/finish diff; `META.artifacts` map + parity lint; the categorizer and `/documents`; review SHIP (re-run 1); D20 | genesis `5bbae6d3`, `7d67c548`, `3c3e38ae` |
| 55-06 | `escalation_gate`, the enriched payload, legacy answers mapped, relaunch with instructions, restart from a step, fix then accept, bindings, the audit; review SHIP (re-run 1); D21–D23 | genesis `6c6f93a5`, `a9a1cce8`, `88b57a52` |
| 55-07 | `run_resolve` mode, the genesis-resolve server, proposals, sandbox copy, the Genesis first turn, escalation notices, `restart_from(from_step=)` in the worker; review SHIP (re-run 1); D24, D25 | genesis `70f7c383`, `0a4acd0c` |
| 55-08 | The contract table for every Phase 55 route, the D23 reader and write guard, the D22 audit fields, `legacy`/`writing` fixes, System paths 403, recorded fixtures; no migration; review SHIP; D26 | genesis `bd9873c6`, `be3097b3`, `1f8fd8b5` |
| 55-09 | Documents tab rewrite; Resolve tab (chat, proposal cards, manual menu, dialogs, results), `/runs/:runId/resolve`, the "Needs you" pill; probe 71 entries clean; review SHIP (re-run 1; m4 deferred, D27) | genesis `f9f126c2..a09c5fbe` (8) |
| 55-10 | Library adoption: one standard gate in all 16 agent workflows (extras, `stop_to`), role maps, relaunch flags, `memory_brief: false` on the memory jobs, the schema, `validate_library` schema/D26/catalog checks; the gate harness; review SHIP (re-run 2); D31, D32 | genesis `014ef888`, `6185c905`, `4b54b737`, `75d89b00`, `361c99a6`; workflows `60c12f3`, `1d3b9ea`, `4bc7168`, `3c29e73` |
| 55-13 | Status-tinted 84 px graph cards with lucide status icons (D28); `META.models` / `default_model` with the fallback and `model.fallback` (D29, D33); Documents hides System and spent tool outputs (D30); review SHIP (re-run 1) | genesis `7cf01475..76b27a57` (5) |
| 55-11 | Whole-phase review + gates: round 1 NEEDS_CHANGES (M1, m1–m4); fix pass m1 (rebind before cancel), m3 (gate-answer compare-and-set), m4 (tests); **SHIP** on the review and gates; M1 not fixed (D35); m5/m6/n3/n4 to the backlog (D38); §3 A1–A14 open (D36, D37) | genesis `3f391a61`, `e8096f71` |
| 55-14 | Release blockers from master #7556336 (D39): content-keyed write detection (blake2b ≤ 1 MiB + memo), `procs.reap` re-read; review SHIP | genesis `ad8f7eda`, `9cd33d52`, `d6cea8db` |
| 55-12 | Release (As run) and this write-back | genesis `3e1effaf` (+ 55-14), tag `v0.84.0` on `d6cea8db`; workflows `2017afb`, tag `v0.28.0` |

Test counts at the release: genesis app CI 2346 passed + 72 skipped (local 2414 + 4 at `9cd33d52`); web vitest 1051
(86 files); genesis-core 173; kiro-agent-sdk 302; parser all passed + 1 skipped on CI; genesis-workflows pytest 678,
`validate_library` 19, `validate_skills` 5.

## Release and deploy (55-12 As run, 2026-11-24)

- **Master pipeline #7556336 was red** at `3e1effaf`: `test_document_records` lost a same-size rewrite on Linux's
  coarse mtime (a real recording gap, hidden on macOS by nanosecond stamps), and an apwt reap test read an empty
  `/proc/<pid>/cmdline` right after `Popen`. No tag existed; the user chose to fix before tagging (D39, sub-spec
  55-14). Then #7559966 and the tag pipeline #7560648 went green.
- The genesis-workflows CI-image run (L-112) stalled on PyPI from inside colima; the user waived it for the master
  pipeline, which installed the real v0.84.0 pins and passed.
- **Deploy deviation:** `gsm provision` does not run `scripts/install-packages.sh`, so the dev venv the fleet runs from
  had no `fastembed` since 55-04 (main's briefs were keyword + entity only). With the fleet stopped and the user's
  go-ahead, the release agent ran the install script (fastembed installed, model fetched, 66 memories embedded on
  main) and `gsm exec userb -- memory fetch-model` / `reembed`. Corrected in the genesis-release skill and 55-12 §2.
- After: both instances report 0.84.0, schema v30, the embedder in their own `models/`, 19 workflows at the v0.28.0
  versions; the memory schedules are back on (D18 closed); Run Detail routes answer 200 (API and bundle only, not
  looked at in a browser). Backups in `/tmp/genesis-release-55-12/backup/` for the user to delete when happy.

## Live acceptance (55-11 §3, D36, D37)

**Open.** The user runs A1–A14 on the released fleet or on a copy rebuilt from `v0.84.0` (the `/tmp/gr-55-11/`
candidate was built from `76b27a57`, before the fix pass). Legacy-gate checks (A12, A14's legacy escalation) are
observations, not pass/fail rows (D35). Findings ship as v0.84.x patches. Phase 51 (51-12 steps 1–27), Phase 53
(53-11 §5) and the Phase 54 not-run rows (54-10 round 2) stay open.

## Decisions and deviations

- **ADRs filed** from `adr-drafts.md` (now marked FILED), brought up to date with what was built: ADR-088 with D17
  (the quantized model, `genesis memory status` / `reembed`, specific-level hints, no floor, read-only memory server)
  and D25 (consolidation skips Resolve chats); ADR-089 with D13, D15, D21–D26, D31, D35 and the 55-11 fix pass
  (rebind before cancel, gate-answer compare-and-set); ADR-090 with D16. ADR-089 states that the `relaunchable` Dev-write
  guard (D23) honours ADR-068 and does not amend it. Status-line notes on ADR-031, ADR-033, ADR-053 and ADR-054;
  ADR-011's one-liner now names the standard gate.
- D19 / D40: no memory text in any commit. The 55-04 evidence and a live `output.md` were redacted and the unpushed
  project-tracker history rewritten twice before its first push. This write-back's files and the 34 architecture
  documents were scanned against all 68 memories (30-character windows, ids only): no hit.
- D35: M1 not fixed (old-gate runs answered from the Flow tab). D37: the release before the user's live checks.
  D38: the re-review's m5, m6, n3, n4 to the backlog. D39: fix before the tag.
- No ADR deviation in any sub-spec.

## Lessons (write-back decisions)

| Candidate (source) | Decision |
|---|---|
| Spike the real stream: the `__interrupt__` chunk raised and was swallowed on every gate (55-03 §0) + an unread stderr PIPE blocks the child (55-03) | **Added L-126** (merged: both are the worker ↔ supervisor pipe) |
| A fork copies the state that made the run fail (55-06 M1) + a seed into an empty thread is the whole state (55-07 B1) | **Added L-127** (merged) |
| A path built from an id is a path (55-06 M2) | **Added L-128** |
| Evidence of a memory feature carries the user's memories; redact before committing (D19, D40) | **Added L-129** |
| Linux mtime ticks hide same-size rewrites; key on content, force with `os.utime`; capture the assertion before calling it a flake (55-14, 55-10 m5) | **Added L-130** |
| A "read-only" server must be read-only by its handle (55-04) + a list guard must not accept a string (55-08 m1) | **Added L-131** (merged: a safety claim true by mechanism) |
| `node.started`, `file.written`, `memory.brief`, `run.relaunched`, `model.fallback` canonical (55-03..55-13) | **Updated L-005** (one-liner and body) |
| Every gate answer routed by the standard gate (55-06/55-10) + route tests by seeding the checkpoint (55-10) + a result keyed by gate occurrence (55-09 m2) | **Updated L-106** |
| Move the binding first when replacing a bound run (55-11 m1) + name the successor before the cancel (55-08) | **Extended L-061** |
| A gate answer is check-then-write: claim by CAS; refuse an action on a non-waiting run; a barrier makes the race testable (55-11 m3, 55-08) | **Extended L-091** |
| The editable venv makes code live, not dependencies; fastembed missing for a phase; `gsm provision` does not run the install script (55-04, 55-12) | **Extended L-099** |
| `Popen` returning does not mean `/proc/<pid>/cmdline` is set (55-14) | **Extended L-104** (closes Phase 54 backlog §5) |
| Full suite in the CI image (case-insensitive APFS, 55-10) + `--init` containers + a Linux-only forced case + a pip cache for colima (55-14, 55-12) | **Extended L-112** |
| Two observers of one event decide from the durable log; store a note under the lock that decides it (55-07 m1, m3) | **Extended L-124** |
| A Radix tab panel's display class beats `hidden` (55-09) + mark the element a probe measures (55-13) + line rects for wrap checks (55-02) | **Extended L-090** |
| A tint colour that passes light fails dark (55-13) | **Extended L-123** |
| A derived UI flag only where it can be true (55-05 m2/m3, 55-08 m5) | **Extended L-094** |
| A count on a node and its edge share one rule (55-03 M1) + a catalog check comparing only ids (55-10) | **Extended L-109** |
| "Real data" in a fixture is a claim; mockup step labels from the run's own workflow (55-02 M1, M2) | **Extended L-083** |
| `wait_for(to_thread(…))` is not an abandonable deadline (55-04) | **Extended L-026** |
| The shell guard reads a container redirect as a host path (55-12) | **Extended L-088** |
| A hint that matches everything is no signal (55-04) | **Dropped** as a lesson: its home is ADR-088 decision 1 and `memory.md` (specific-level hints) |
| A spec sentence about a restart can assume a record that never exists; overlap is between tasks, not node names (55-05) | **Dropped**: recorded as limits in `writes.py` and `runs-and-workers.md` §5.12 |
| A loop variable shadowing a binding (55-06) | **Dropped**: a general coding slip caught by the ordering spy test; no rule to keep |
| Reusing a chat turn hook for a turn it did not start (55-09 M1) | **Dropped**: specific to the Resolve tab, recorded in 55-09's As built |
| An advisory per-turn read needs a lock and a cached failure (55-13 m2) | **Dropped**: general concurrency practice, in the code (`advertised_models`) |

## Architecture documents (genesis `14721760`, local)

All 34 documents reviewed and moved to **Describes** genesis v0.84.0 (Phase 55), **Last reviewed** 2026-11-24.
Rewritten or extended: `modules/runs-and-workers.md` (the escalation gate and run actions, write records and the
documents view, the snapshot and hint stream, what agent nodes get), `api.md` (the Phase 55 routes, the Resolve token,
`resolve_routes.py`), `scheduler-and-jobs.md` (escalation notices, following a replacement), `chat-and-skills.md`
(the Resolve chat), `web-app.md` (Run Detail on the snapshot, the Documents and Resolve tabs, the cards), `memory.md`
(the brief, fastembed default; the stale model2vec-default text fixed), `core-engine.md` (the standard gate, prompt
lines, model choice), `workflow-library.md` (the adoption table and the new META keys), `distribution.md` (the model
step; `gsm provision` does not run the script), `configuration-and-secrets.md`, `data-and-migrations.md`,
`observability-and-credits.md`, `testing.md`, `features-and-stages.md`, `stories-and-workbench.md`,
`custom-agents.md`, `knowledge-base.md`, `collaboration-hub.md`; the numbered documents (`04` no longer says
genesis-memory is chat-only; `07` gains the escalation scenario 7.9; `08` names the standard gate; `10` lists
ADR-088..090), the glossary and the README. Header only: `documents.md`, `kiro-agent-sdk.md`, `appian-parser.md`. No
document names `hitl_gate` as the escalation target. No module document is "planned". The edits were drafted by four
genesis-docs sub-agents with disjoint files and checked here.

## Agent-system notes

1. **Areas** (`context/areas.toml`): `runs-worker` gains `memory/brief.py`, `chat/resolve.py`, `mcp/resolve_server.py`,
   `api/resolve_routes.py` and genesis-core `nodes/escalation.py` (`genesis/runs/**` already holds the new runs
   modules); `web-runs` gains `runs/snapshot.py`, `runs/documents.py` and the web types `snapshot`, `runDocuments`,
   `escalation`, `resolve` and `lib/api/resolve.ts`; `chat` gains the Resolve server, routes, web tab and types;
   `workflows-library` gains `genesis/lint/**`, `testing/escalation.py`, `runs/{artifact_roles,relaunch_policy,
   node_models}.py` and `nodes/escalation.py`; `features-stages` and `stories-workbench` gain `runs/bindings.py`;
   `appian-integration` gains `runs/relaunch_policy.py` (the ADR-068 guard); `distribution` gains
   `scripts/install-packages.sh` and `memory/model.py`; `sdk-acp` gains genesis-core `agents/models.py`.
2. **Skills changed** — run `agent-system/update.sh`: `genesis-workflow-authoring` (the standard gate, the Phase 55
   META keys, ADR-089 in its rules list) and `genesis-release` (the fleet refresh: `gsm provision` does not run the
   install script; what to run for a new dependency or state-dir asset).
3. **Reference docs** (project-tracker): `reliability-standard.md`, `hitl-design.md`, `node-taxonomy-reference.md`
   and `glossary.md` now name the standard `escalation_gate`; `workflow-authoring-standard.md` §2.1 documents the
   new META keys. **The genesis-workflows steering was not changed** (genesis-docs cannot write that repo): backlog
   §6 asks genesis-dev to carry the same text into `steering/02`, `05` and `07`.
4. **L0 budget: ~23,996 / 24,000 tokens.** Three ADRs and six lessons (digest lines) plus the Phase 55 state were
   absorbed by tightening the state snapshot (no rule dropped; the other candidates extended 13 existing lessons rather
   than taking new ids). The next phase will not fit. **Proposed compression, not applied** (for the user to choose):
   (a) merge the two superseded ADRs' digest lines into their successors' (ADR-044 into ADR-056, ADR-062 into
   ADR-068), about 160 tokens; (b) group the lesson digest by area (one heading per area, the area name not repeated
   per line), size to be measured; (c) raise the L0 budget to 26K, since the digests grow by about 600 tokens a phase.
5. ADR bodies and lesson bodies were written from scratch files in `context/.packs/` (git-ignored); every
   `genesis-ctx add` ran alone. The memory-text scan script is `context/.packs/scan_memory_text.py` (ids only).
