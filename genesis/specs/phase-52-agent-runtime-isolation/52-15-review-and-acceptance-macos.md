# 52-15 — Review, hardening and live acceptance on macOS (Release 1 gates)

> **Status:** SPEC-DRAFTED 2026-11-18. Agent: **genesis-review** (fixes by genesis-dev). Repos: all. Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D17, D22, D23, D29, D30; all of §14 for the checklist.
> Upstream: 52-02..52-14.

## 1. Independent review

`genesis-ctx check --since <phase base>` per repo; every applicable ADR and lesson answered OK / VIOLATION / N/A with
file:line evidence; the ADR drafts checked against the code; the threat model and limits (umbrella §6) checked
against what was built. Specific checks: no code path starts `kiro-cli` on the host in the product (R1); no secret,
token or registry credential in any image layer, sandbox env, event payload or log (scan with a canary secret, R5);
the controller is the only container with the engine socket; the app container has none; the policy compiler is the
only producer of policies and the controller the only enforcer.

## 2. Gates

Backend `pytest` + `ruff`; packages; web `lint` + `tsc` + `vitest` + `npm run build` with `web/static/` committed;
genesis-workflows `validate_library` (with the new egress gate) + pytest; image tests (52-04 §5); CI on a branch
pipeline in the CI image (L-112).

## 3. Mandatory release gates (D22, D23, D30) — on the real macOS stack, release candidate images by digest

| # | Gate | Pass |
|---|---|---|
| G1 | **Host-isolation corpus** (52-06): host files, the Mac's loopback, VM services (Lima `sshd`, guest agent), Docker socket/TCP, the app container's API and ports, the controller API, another sandbox, metadata and private/link-local/LAN addresses, escalation, a process outliving the turn | Every item blocked; each negative control fails as expected |
| G2 | **Network-security corpus** (52-07): direct IP, other DNS, DoH to an IP, IPv6, UDP, ICMP, proxy chaining, the gateway as a proxy, DNS rebinding, a non-listed host, a listed host | Blocked items blocked and logged (`egress.decision` / `egress.dropped`); the listed host works |
| G3 | **Positive corpus:** the findings §4 benign commands, skills, blackboard, MCP through the relay, credits per turn | All pass |
| G4 | **Credentials:** canary secrets in every secret store; scan sandbox env, files, `/proc`, MCP traffic, event payloads | No canary found; no refresh token in any sandbox |
| G5 | **Supply chain:** release manifest signature, image digests and signatures verified by the launcher; SBOMs present; scan threshold met | All verified |
| G6 | **Self-test fail-closed:** break one rule deliberately (a dev-only switch); the controller refuses turns with the reason; restore; turns resume | As described |
| G7 | **API token:** no-token, wrong-token, other-Origin, wrong-Host requests refused on the app and report origins; the SPA works | As described |

## 4. Live acceptance (the user's real environments; one case per session)

- Every agent-node workflow in the library runs sandboxed end to end (Dev up; `story-implementation` only with the
  user's go-ahead), outputs equal in kind to host runs (R10); every chat mode; copilot run control.
- Phase 51: `story-verification`, `action-capture`, `setup-composer`, a `TE-` execution and the regression job on QA;
  a recording through noVNC as a test role.
- Pause, resume, fork, cancel and a server restart mid-turn: no sandbox left (`docker ps` empty of `genesis.*` labels),
  run states correct (L-108, L-097).
- Backup, restore-verify, a restore into fresh volumes, an update to a second release candidate with rollback.
- The import of the user's real v29 data (on a copy first), then the cutover (52-12).
- Turn start overhead within the agreed budget (R11); resource defaults hold under the concurrency cap.

Findings go to genesis-dev as one fix pass per round; the verdict SHIP / NEEDS_CHANGES in
`reviews/52-15-review.md`.

## Context manifest

```toml
areas    = ["security", "runs-worker", "distribution"]
adrs     = ["ADR-012", "ADR-026", "ADR-029", "ADR-031", "ADR-032", "ADR-083", "ADR-085", "ADR-086"]
lessons  = ["L-088", "L-089", "L-090", "L-097", "L-100", "L-108", "L-110", "L-111", "L-112", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/genesis/agent_runtime/**", "genesis/docker/**", "genesis/packages/genesis-launcher/**"]
upstream = ["52-02", "52-06", "52-07", "52-08", "52-09", "52-10", "52-11", "52-12", "52-13", "52-14"]
```
