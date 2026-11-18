# 52-07 — Egress proxy, network enforcement and `META.egress`

> **Status:** SPEC-DRAFTED 2026-11-18. Repos: **genesis** (`genesis/agent_runtime/egress/`, the `egress` image,
> `genesis-core` META validation), **genesis-workflows** (the library gate). Parent:
> `specs/phase-52-agent-runtime-isolation.md`. Decisions: D10, D23, D25, D28. Upstream: 52-02 (S6, S7, S12), 52-05, 52-06.

## 1. Goal

Make "default deny" true at the network layer and make every allowed connection a policy decision that is logged.

## 2. Layers

1. **VM baseline** (52-05): internal sandbox network, IPv6 off, everything but the proxy and gateway ports dropped
   with counters.
2. **Per-sandbox rules** (controller): when a sandbox starts, its address is registered with the proxy together with
   its policy's egress list; rules are removed with the sandbox. The firewall drop counters for that address are read
   at turn end into `egress.dropped`.
3. **DNS:** sandboxes get no usable resolver: if 52-02 S6 showed Docker's embedded resolver forwards outside names, a
   stub resolver answers only the proxy's and gateway's names and refuses the rest; the proxy resolves everything else.
4. **Proxy** (the `egress` image; own asyncio proxy unless 52-02 S7 chose Squid): HTTP forward and `CONNECT`; the
   sandbox env sets `HTTPS_PROXY`/`HTTP_PROXY`/`NO_PROXY` (gateway name only). Per request: identify the sandbox by
   source address; take the host from `CONNECT` target or `Host`, cross-checked with TLS SNI on `CONNECT`; **refuse IP
   literals** unless the policy lists that address; resolve the name itself; refuse if any result is loopback, private,
   link-local, CGNAT, ULA, multicast or the VM's own ranges; connect to the address it checked (no second lookup, no
   rebinding window); ports 443 and 80 unless the policy declares another; no upstream-proxy chaining from sandboxes
   (the proxy itself may follow the VM's configured upstream proxy for its own outbound traffic, Docker Sandboxes'
   pattern); redirects are the client's business (each new connection is checked afresh).
5. **Gateway:** speaks only the relay protocol (52-08); a request in proxy form is refused and logged.
6. **Audit:** every decision is an `egress.decision` event (52-03 §3), coalesced per (host, decision, reason) per turn.

## 3. Allow-list layers (D10)

- **Base:** Kiro's model and auth hosts from 52-02 S7, in one constant with its source and the kiro-cli version it was
  measured on; re-measured on each kiro-cli upgrade (L-044).
- **Workflow:** `META.egress` — optional list of host names (exact or a single leading `*.` wildcard), optionally per
  node via `kiro_node(egress=[...])`; additive, `CORE_MAJOR` unchanged (ADR-019); `workflow.yaml` mirrors it (parity
  lint). genesis-workflows **gate**: entries are syntactically valid host names, no IPs, no bare `*`, no well-known
  upload/code hosts (GitHub, GitLab, PyPI, npm registries) without a justification field reviewed in the MR.
- **User:** Settings → Egress additions (52-13/52-14), each shown with a warning and logged as a setting change.
- Not by default: the Appian Dev host (MCP only), registries, code hosts.

## 4. Tests

Proxy unit tests (host extraction, SNI mismatch, IP-literal refusal, private-result refusal, pinning, ports, chaining
refusal, coalescing); policy-to-proxy registration tests; META/`workflow.yaml` parity and the library gate tests; the
D23 network corpus from 52-02 S12 as an integration suite on the dev VM (direct IP, other DNS, DoH to an IP, IPv6,
UDP, ICMP, chaining, the gateway as a proxy, rebinding), each with a negative control.

## Context manifest

```toml
areas    = ["security", "workflows-library", "core-engine", "observability-credits"]
adrs     = ["ADR-006", "ADR-011", "ADR-014", "ADR-019", "ADR-029", "ADR-083", "ADR-086"]
lessons  = ["L-013", "L-044", "L-088", "L-092", "L-094", "L-117"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/.research/kirocrew-trust.md", "tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md"]
code     = ["genesis/genesis/agent_runtime/egress/**", "genesis/docker/egress/**", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/lint/**", "genesis-workflows/ci/**"]
upstream = ["52-02", "52-05", "52-06"]
```
