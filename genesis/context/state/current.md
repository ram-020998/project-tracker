Active phase: none in build — Phase 55 (workflow execution) SHIPPED 2026-11-24, live acceptance open (55-11 §3 A1–A14); Phase 51/53/54 acceptance still open

<!-- context/state/current.md — the current-state snapshot (47-05 §4). OVERWRITTEN every phase by genesis-docs:
     current values only, no history, no CI ids. History lives in progress/ and archive/. Keep ≤ 4K tokens. -->

# Genesis — current state

## Shipped versions (Phase 55 release, 2026-11-24)

| Repo | Tag | Branch |
|---|---|---|
| `playwright-appian` | v0.3.1 — `apwt` (npm, project 13864), vendored in genesis `testexec/vendor/` | main |
| `genesis` | v0.84.0 — app + `packages/` genesis-core (`CORE_MAJOR=1`), kiro-agent-sdk, genesis-appian-parser (`KB_FORMAT_VERSION=1`), all 0.84.0; `fastembed==0.7.4` | master |
| `genesis-workflows` | v0.28.0 — pins on `genesis.git@v0.84.0`; its agent workflows need genesis ≥ 0.84.0; skill `appian` 1.0.0 | master |

kiro-cli: only verified version **2.37.1** (newer warns and runs); 3.x unverified (`specs/backlog/kiro-cli-3x-reverify.md`).

## Databases

`~/.genesis/genesis.db` (WAL) m0001–m0030, `current_version` = **30**; `~/.genesis/memory.db` `mm0001` (v1); the
embedding model in `<state>/models/bge-small-en-v1.5/`.

## Test counts at the last release

genesis app CI **2346** passed + 72 skipped; web vitest **1051** (86 files); genesis-core **173** · kiro-agent-sdk
**302** · parser all passed + 1 skipped; genesis-workflows pytest **678**, `validate_library` **19**,
`validate_skills` **5**; playwright-appian **1402**; agent-system **399**.

## What works today

- **Platform:** `genesis serve` → `/api` + SPA on :8760 (version = `/openapi.json` `info.version`); reports on port +
  100 (ADR-085); nav per ADR-087. Kiro v3 only, Genesis-owned `KIRO_HOME`, projected trust, fail closed (ADR-086);
  a model per agent node (`META.models` / `default_model`, `model.fallback` on an unlisted id).
- **Memory brief (ADR-088):** every run with an agent node starts with `_memory/brief.md` (shared + the owner's
  personal memories, never published) and the read-only `genesis-memory` MCP on its agent nodes; bge-small embedder.
- **Escalation (ADR-089):** one standard `escalation_gate` in every library agent workflow; Run Detail's **Resolve**
  tab (the agent proposes; the user confirms retry, accept, fix then accept, rerun with instructions, restart from a
  step or stop; program code applies); a bell notice per escalation; rerun/restart only for `relaunchable` workflows.
- **Run Detail (ADR-090):** graph from the versioned snapshot, live hints + 3 s poll, status-tinted cards, Live /
  Reconnecting / Polling badge; **Documents** by step or type from `file.written` records; 3 HITL modes; credits.
- Schedules + bell, custom agents, managed skills, read-only chat, Applications (KB, five feature stages, stories),
  Testing on QA, Workbench lanes, spec CRs, opt-in Hub, MCP/CLI tiers (ADR-081..087).
- **Fleet:** main (:8760) + userb (:8761), v0.84.0 / DB v30 from the editable dev venv, fastembed and the model in
  each state dir, 19 workflows (v0.28.0), memory schedules on; `gsm` = `<repos>/genesis-fleet/bin/gsm`.

## Known open items

- **Phase 55 live acceptance open** (55-11 §3, A1–A14; the user runs it; findings as v0.84.x patches). Phase 51
  (51-12), 53 (53-11 §5) and 54 (54-10 not-run rows) acceptance still open: each progress doc's "Live acceptance".
- **D35:** a run started on a workflow from before v0.28.0 escalates through its old gate: answer it from the Flow
  tab's gate panel, not Resolve. Known issue m7 (Phase 54 backlog §1).
- **For the user:** delete `/tmp/genesis-release-55-12/` (database backups) once happy with v0.84.0, then
  `/tmp/colima/gr-55-12/`; also `/tmp/genesis-release-54-11/`. Unconfirmed from Phase 50: `details.kb_format_version`
  = 1 on each instance; old library checkouts to `_archived/`.
- Agent isolation is Phase 52 (ADR-083 a–c). Backlog: `specs/backlog/phase-5{0,1,3,4,5}-follow-ups.md`.
