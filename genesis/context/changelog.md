# Genesis changelog — one line per phase / release (newest first)

<!-- Appended by genesis-docs at each phase write-back (47-08 §2). History before Phase 47: archive/tracker-status-log.md. -->

- 2026-11-20 — Phase 54 Schedules, custom agents, fixes and UX revamps — genesis v0.83.0 → genesis-workflows v0.27.0 (m0030, DB v30; `agent-prompt` 0.1.0) — ADR-087 — Schedules page, bell, Catalog → Agents, chat with a custom agent, story/feature revamps, B1–O4 fixes, `program_node` off the loop; L-120–L-125; live-accepted (54-10 round 2) with named not-run rows; known issue m7

- 2026-11-15 — Phase 53 Kiro SDK v3 (kiro-agent-sdk rebuilt for kiro-cli's v3 engine) — playwright-appian v0.3.1 → genesis v0.82.0 → genesis-workflows v0.26.0 (m0029, DB v29; skill `appian` 1.0.0) — ADR-086 — v3 only, Genesis-owned `KIRO_HOME`, projected trust, managed skills, steering, Stop keeps the session, `session/load` resume; verified on kiro-cli 2.37.1; L-113–L-119; **live acceptance partly open (4 of 15 workflows; 53-11 §5 and Phase 51's 51-12 after the release, D24/D26/D20)**

- 2026-11-08 — Phase 51 Test execution engine (action library, regression suite, story verification) — playwright-appian v0.3.0 → genesis v0.81.0 → genesis-workflows v0.25.0 (m0026–m0028, DB v28) — ADR-081..085 — Testing tab, QA environment type, Record / Compose with AI, program-only executions, regression schedule, Verification lane, reports origin; L-101–L-112; **live acceptance still open (51-12 steps 1–27 on QA, D38; findings → v0.81.x)**

- 2026-11-01 — Phase 50 Platform monorepo — genesis v0.80.0 → genesis-workflows v0.24.0 (no migration, DB v25; genesis-core, kiro-agent-sdk, genesis-appian-parser now `genesis/packages/*` at 0.80.0) — ADR-080 — one repo, one install command, one shared version, `KB_FORMAT_VERSION`; reinstall installs ≤ v0.79.0 (do not use the update banner); L-098–L-100
- 2026-10-31 — Phase 49 Test Design (suites, scenarios, cases, test impact) — genesis v0.79.0 → genesis-workflows v0.23.0 (m0025, DB v25; other repos unchanged) — ADR-078/079 — fifth feature stage + TC-/TS- records, Tests tab, Test Impact tab; run-status ordering + orphaned-run sweep; L-091–L-097
- 2026-10-21 — Phase 48 The Object Wiki in the application page — genesis v0.78.0 (no migration; other repos unchanged) — no new ADR — Object Wiki tab + object page, URL app tabs; first phase on the five agents; L-089/L-090
- 2026-10-20 — Phase 47 Agent Context System — project-tracker only (no Genesis release) — ADR-077 — tiered context + five CLI-3 role agents; lossless migration
- 2026-10-15 — Phase 46 Spec Change Requests & Story Traceability — genesis v0.77.0 → genesis-workflows v0.22.0 — ADR-075/076
