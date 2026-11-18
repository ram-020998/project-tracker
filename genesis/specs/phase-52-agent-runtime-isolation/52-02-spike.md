# 52-02 — Spike: the remaining unknowns, with first corpora (gate)

> **Status:** SPEC-DRAFTED 2026-11-18. Repo: **genesis** (harness under `genesis/scripts/spikes/52-02/`, evidence under
> `…/52-02/evidence/`). Parent: `specs/phase-52-agent-runtime-isolation.md`. Decisions: D1, D2, D5, D6, D8, D11, D15,
> D18, D19, D22, D23, D27. Machine: macOS (Apple silicon). Linux and Windows have their own spikes (52-17, 52-18).
> **Gate:** a FAIL on a must-pass item (★) stops the phase for a re-spec of the sub-specs it affects.

## 1. Goal

Prove, on this Mac, every assumption the design rests on before any product code is written, with the product's own
shapes (L-117: the real projection, the real permission ladder, the production folder layout, one case per session, a
negative control that must fail), and record the numbers that set the defaults (umbrella §11).

## 2. Questions (each: method, evidence file, PASS/FAIL line, fallback)

| # | Question | PASS when | Fallback if FAIL |
|---|---|---|---|
| S1 ★ | **VM:** a Genesis-owned Colima profile (`colima start -p genesis-spike`), pinned Colima and Lima; does the pinned Lima support `networkOpts.hostLoopback: false` with `vmType: vz`? No home mount (`mounts: []`) | VM up with no host mount; from a container, `host.lima.internal` and the Mac's `127.0.0.1` services refused; the default profile `default` untouched | Block the host-loopback address in the VM firewall (52-05) and record the Lima version needed |
| S2 | **Latency and size:** cold and warm `docker run --rm` of the sandbox image draft (≈ 52-04 §2) with D5's hardening flags; memory of an idle sandbox, one running `kiro-cli` + Python, one running Chromium | Numbers recorded (p50/p95 of 20 starts) | — (sets D6 defaults; warm pool stays deferred unless p95 > 5 s) |
| S3 ★ | **Kiro in a sandbox:** `kiro-cli` for Linux (arm64) inside the sandbox, `acp --agent-engine v3` attached to the host process over `docker run -i` stdio, driven by today's `kiro_agent_sdk` with the real projected agent (`agent_spec.py`), activation confirmed (L-113) | A turn completes; credits reported (`turn_completion`, ADR-032); the per-run `KIRO_HOME` under the mounted run folder | Run the ACP stream over a socket the controller attaches instead of stdio |
| S4 ★ | **Auth:** `kiro-cli-chat acp --agent-engine v3 --auth-method client` (or `kiro-cli` on ≥ 3.0.0) with no login in the sandbox; the spike answers `_kiro/auth/getAccessToken` from a login made by a throwaway Genesis-owned OIDC device-code sign-in (KiroCrew's contract, findings §18.6) for IAM Identity Center | Turn completes with `{accessToken, expiresAt ≥ now+3 min, profileArn}`; a refresh works; a scan of the sandbox (env, files, `/proc`) finds no refresh token; `KIRO_API_KEY` absent | D19's bridge: read and refresh the `kiro-cli` login stored in the app container; or, only with the user's explicit OK, copy the login (D8) |
| S5 ★ | **MCP relay:** a 50-line stdio relay in the sandbox, launched by Kiro as an ordinary MCP server, forwarding to a gateway stub in a second container over the sandbox network with a per-turn token; `genesis-kb` and the blackboard server behind it | `_kiro/mcp/status` reaches `connected`; a call succeeds; a call outside the allowlist is refused by the gateway stub; a wrong token is refused; v3 MCP shapes as L-114 | HTTPS gateway with a Genesis CA trusted in the sandbox (D18's considered option) |
| S6 ★ | **Network layer:** an internal Docker network; firewall rules in the VM (`DOCKER-USER` / nftables) allowing the sandbox subnet only the proxy and gateway ports; IPv6 disabled; UDP and ICMP dropped; **does Docker's embedded resolver (127.0.0.11) forward outside names on an internal network?** | The S12 network corpus passes; the embedded-DNS answer recorded | A DNS stub that answers only the proxy and gateway names (52-07) |
| S7 | **Proxy shape:** a minimal CONNECT proxy that resolves, refuses IP literals and private/loopback/link-local/CGNAT/ULA/VM-range results, connects to the checked address; compare with Squid `dst` ACLs | Kiro's model and auth hosts work through it (record the exact host list for D10's base layer); `docs.appian.com` allowed when listed, refused otherwise; a rebinding name refused | Squid with ACLs if the own proxy cannot meet a must-pass |
| S8 | **Mounts:** the run's subfolder of an artifacts volume mounted at the same absolute path with `--mount type=volume,volume-subpath=…` (Docker ≥ 26) on the pinned engine; read-only root; writable `/tmp` | Writes land in the run folder; nothing else writable; `/proc/mounts` shows nothing else | A bind mount of the run folder from the VM path of the volume |
| S9 | **Skills and blackboard:** ADR-069/086 provisioning into `<run>/.kiro/skills/` inside the mount; front matter checked (L-115) | Skill appears in the engine's skill list (`_kiro/progressive_context/items_changed`); blackboard save/read via the relay | — |
| S10 | **Recorded commands:** replay the §4 benign commands (JSON checks, `json.tool`, temp-file `rm`, `ls -la` of the run folder) and the §4 notable ones (`env` dump, `curl --resolve`, `sudo -n true`, `/etc/hosts`, repo reads) | Benign: same result; notable: each blocked or empty, as findings §8.4 expects | — |
| S11 | **Browser:** Playwright Chromium (the vendored apwt version) headless in the sandbox with `apwt open --storage-state <file>` against the QA host through the proxy; headed on Xvfb viewed through noVNC from the app container only | `open`/`snapshot`/`expect` pass; a replay of one committed spec passes; noVNC reachable from the app container and not from the Mac | KasmVNC or Chrome screencast (findings §18.4) |
| S12 ★ | **Corpora (first drafts):** the D22 bypass corpus (host files, the Mac's loopback, VM services incl. Lima's `sshd` and guest agent, the Docker socket/TCP, the app container's API and ports, the controller API, another sandbox, `169.254.169.254`, link-local/private/LAN, `sudo`/setuid/capabilities, a process outliving the sandbox) and the D23 network corpus (direct IP, other DNS servers, DoH to an IP, IPv6, UDP, ICMP, proxy chaining, the gateway as a proxy, rebinding); a positive corpus (S9, S10 benign, MCP, an allowed host) | Every bypass item blocked, every positive item passes, each with a negative control that must fail (L-088, L-117) | Re-spec the failing layer |
| S13 | **Lifecycle:** kill a running turn (the controller's `docker rm -f` path); the kiro-cli process tree and any `apwt` daemons inside die with the container; stats (CPU, memory, pids) readable per container | No leftover processes or containers; stats recorded | — |
| S14 | **Images:** a multi-arch build of the sandbox draft in the genesis project's CI (or locally with `buildx`), pushed to the project registry; SBOM generated; a scan runs; a signature made and verified | All four steps work with tools available to the project's CI | Name the missing tool for 52-04 |

## 3. Method

- Throwaway harness under `genesis/scripts/spikes/52-02/` (outside the import gate, like 53-02's). No product code
  changes. One case per session (L-117). Every probe writes JSON evidence with the command, the output and a PASS/FAIL
  line. Never print a secret, a token or a registry credential (L-100); check presence by count.
- The user's `default` Colima VM and `~/.genesis` are never touched; the spike VM is deleted at the end.
- kiro-cli: the then-verified version (2.37.1 when drafted); if 3.x is verified by then (`specs/backlog/kiro-cli-3x-
  reverify.md`), run S3/S4 on both.

## 4. Output

- Evidence files and an **As built** with: each item's result; the defaults proposed for umbrella §11; the exact Kiro
  host list (S7); the Lima/Colima/Docker versions to pin; the corpora as runnable scripts for 52-06 and 52-07 to adopt;
  re-spec notes for 52-04..52-12.

## Context manifest

```toml
areas    = ["security", "sdk-acp", "runs-worker", "distribution", "browser-testing", "core-engine"]
adrs     = ["ADR-012", "ADR-029", "ADR-032", "ADR-051", "ADR-069", "ADR-077", "ADR-083", "ADR-086"]
lessons  = ["L-001", "L-044", "L-087", "L-088", "L-100", "L-104", "L-113", "L-114", "L-115", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/.research/kirocrew-trust.md", "tracker:specs/phase-52-agent-runtime-isolation/.research/kirocrew-runtime.md", "tracker:specs/phase-53-kiro-sdk-v3/53-02-spike-v3-wire.md", "tracker:specs/phase-51-test-execution-engine/51-03-spike-sandboxed-shell.md"]
code     = ["genesis/scripts/spikes/52-02/**", "genesis/packages/kiro-agent-sdk/src/kiro_agent_sdk/**", "genesis/packages/genesis-core/genesis_core/mcp/**"]
upstream = []
```
