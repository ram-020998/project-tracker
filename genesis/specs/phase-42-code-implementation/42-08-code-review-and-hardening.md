# 42-08 — Code review & hardening

> **Status:** 🟡 DRAFTED. Independent review of the built 42-02..42-07 before release. Parent: `specs/phase-42-code-implementation.md`.

## 1. Review checklist (write-safety is the headline — this is Genesis's first env-mutating capability)

- **No-delete guarantee (hard):** no node in `story-implementation` has any `delete*` tool in its effective set (`node.tools ∩ appian-dev-write.allowlist`); the allowlist contains zero `delete*`; a retire → an `update` setting the description "deprecated by Genesis". A guard test asserts this.
- **Write isolation:** only `implement` + `heal` inject `appian-dev-write`; `appian-dev` (chat/KB/design) remains read-only; the write entry is never wired elsewhere. Auth resolves from the dev-tagged env only (ADR-048) — no other target reachable.
- **Single blanket approval:** the run is only launched by the drag-confirm endpoint; there is no per-object gate; the reverify escalation is the only mid-run HITL (proceed / send-back).
- **Fail-fast prereqs:** the start endpoint 409s on no dev env / app not synced / no completed design / no Technical Design / workflow not installed (never a bare 500).
- **Finalizer correctness:** bound-run guard + idempotency + on-read recovery (the §7 orphaned-worker lesson); done → code-review audited (m0013); send-back → design-review; a failed/escalated run leaves the card in Implementation (light-red) from the durable `runs` status.
- **Reliability:** every agent node wears the trio; `attach_healing` bounded {1,1} → escalate; `implement`'s validator requires every design-plan object to be attempted (a write error → retry → escalate, never a silent skip).
- **Wiki:** append-only entries; local write always succeeds; publish/pull best-effort + conflict-free; the two `_BINDINGS` kinds match the frozen Hub contract (the "permissive local emulator hid the contract" §7 guard); business/technical descriptions authored, no code stored.
- **Skills:** the implement/verify/heal nodes actually load the `appian` skill (+ `appian-object-generation` on implement) from the run's `.kiro/skills/`; a missing skill fails fast; `KIRO_HOME` untouched.
- **KB honesty:** the KB is NOT updated by the run (it stays read-only/code-free) — the review surface says the KB reflects the changes only after a Refresh (auto-resync is backlog); no fabricated post-state.
- **Web:** a11y (jest-axe) on the dialog + review surface; dark parity; no hardcoded brand hex; `web/static` rebuilt + committed.
- **Migration:** m0021 clean-upgrades a fresh DB to v21; every `current_version == 20` test bumped.

## 2. Live-acceptance notes (headless-undrivable — user-driven)

A real run against the dev env: drag a design-reviewed ticket → confirm → the run reverifies, writes a rollback doc, creates/updates the objects (verify in Appian that they exist + open), verifies + heals, writes the Object Wiki (check the entries locally + on the Hub), and the card lands in Code Review; open the read-only review surface. **Because this WRITES to the environment, the first live acceptance must be on a throwaway/sandbox app + story**, reviewed object-by-object, with the rollback doc validated by hand before trusting it at scale.

## 3. Gate

Apply MUST-FIX before release; SHOULD-FIX tracked. Review clean → 42-09.
