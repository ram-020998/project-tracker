# KiroCrew agent runtime isolation: research for Genesis Phase 52

Source: `/Users/ramaswamy.u/repo/KiroCrew` at `fb81cec80f` (2026-11-17), read-only. Paths are relative to it. **V** = verified in the cited text or code. **I** = inferred. (`work_brief` answered "not bound", so the task text was the only brief.)

## 1. Agent execution boundary

**No container or VM boundary for agents (V).** The boundary is a per-spawn OS sandbox around the `kiro-cli` process tree. Layers 1 to 4 (path gate, command gate, validation, redaction) are always on, and the docs say that is why the sandbox can be optional (`docs/architecture/security-deep-dive.md:68,88-90`).

- **Linux (V).** The launcher unshares user and mount namespaces only (`src/kiro_crew/sandbox_launcher_program.py:57-58,261,279`). It bind-mounts empty dirs over credential paths, drops all capabilities, sets `NO_NEW_PRIVS` (`sandbox_launcher_parts/exec_lockdown.py:217-249`), then installs a seccomp filter denying only `mount`, `umount2`, `unshare`, `setns`, `pivot_root` and `kill(-1)` (`:327-352`). There is no PID or network namespace, by choice (`:360`; `security-deep-dive.md:849-867`). An arch with no syscall table is refused (`:381-395`). The agent runs as the gateway uid on the host filesystem minus the masks (I).
- **macOS (V).** Seatbelt profile is `(allow default)` plus deny rules, a denylist (`sandbox_seatbelt.py:23-26`), plus denies on named host unix sockets (`:231-240`).
- **Windows (V).** No first-party wrapper. An official `kiro-cli` spawn delegates to the CLI's own sandbox (`security-deep-dive.md:92-95,137-139`).
- **Tiers (V).** `auto` (default, resolves to `standard`), `strict`, `off` (`security-deep-dive.md:83-100`; `docs/system-specs/modules/security.md:1806-1815`). `standard` leaves `.aws`, `.ssh`, `.kube` readable on purpose, so `cat ~/.aws/credentials` works under the default (`security-deep-dive.md:182-191`). A governance `sandbox.min_level` floor clamps up, even over `off` (`:94-97`).
- **Fail-closed (V).** With no backend, `wrap_argv` raises (`security-deep-dive.md:118-121`; `security.md:1860`). Unconfined execution needs `agent.sandbox_allow_unsandboxed_exec=true`, or the platform default (allow on Windows, refuse elsewhere, `security-deep-dive.md:107-122`). Every unconfined spawn is SEL-audited. A sandbox that refuses to initialize is never retried or downgraded (`security.md:1955`).

**Recent commits (V, commit bodies).**
- `14c6b6c948` (11-17): a stricter tier reaches running sessions. A session restarts under the new tier at its next turn and keeps its conversation.
- `bdff21a134`: error wording only. The refuse/allow decision is unchanged.
- `c0f79fe156`: a mask-planning fix (`pinned_mounts.py`).
- `20858437d0`: a test fix for `run_sandboxed_async` cleanup.
- `f89e02dba8`: a test change. That `bubblewrap` is Codex's own preflight, not KiroCrew's boundary. KiroCrew's only `bwrap` use is connected computers (section 4).

## 2. Containers and VMs

- **A containerized gateway is a supported shape (V).** `docker/Dockerfile` (non-root uid 1000, `:185,249`), `docker/compose.yaml` (port published on `127.0.0.1:5476`, one named volume, `:15-28`), `docs/guides/docker.md:23,177-235`.
- **The agent is still sandboxed inside the container by the same user and mount namespace launcher (V).**
  - `docker/entrypoint.sh:18-31,137-170` probes on first run whether `unshare(NEWUSER)`, `unshare(NEWNS)` and `mount(MS_REC|MS_PRIVATE)` work. If so it seeds `agent.sandbox=auto`. If not, agent command execution stays disabled until the operator sets `KIROCREW_ALLOW_UNSANDBOXED=1` (`:143-151`).
  - The workaround is a custom seccomp profile: Docker default plus unconditional `unshare`, `clone`, `mount`, `umount2` (`docker/seccomp/gen_profile.py:1-20`; `docker.md:298-355`). The generator says the allows are not filtered by namespace type (`gen_profile.py:11-15`). AppArmor hosts also need `apparmor=unconfined` (`docker.md:337-355`). Kubernetes needs more (`:356-408`). `--privileged` is "not recommended" (`:429-434`). Docker CE in WSL2 can fail without `CONFIG_USER_NS` (`:436-453`).
  - The container itself is only non-root plus the Docker default. No `cap_drop`, `read_only` or `no-new-privileges` appear in `docker/` (V, grep).
- **Where a VM is the boundary, the inner sandbox is turned off (V).** The AWS Lambda MicroVM lane runs with `KIROCREW_ALLOW_UNSANDBOXED=1` because of "a Firecracker boundary around the whole machine" (`docs/guides/remote-crew-on-microvm.md:211-213`). Its endpoint is internet-reachable, so every route authenticates (`:197-209`). Fargate has `internal_only` (`remote-crew-on-fargate.md:76-79`); EC2 documents the same opt-out (`remote-crew-on-ec2.md:121-141`).
- **`test/microvm_harness/` is test scaffolding (V).** It runs the crew image under `docker run` against a fake control plane. It says a container proves nothing about the sandbox, cgroups or user namespaces (`test/microvm_harness/__init__.py:1-24`).
- **Not found (V for greps).** `docs/request-for-change/rfc-app-sandbox-isolation.md` covers API-token scoping, not process isolation. Docs and src contain no gVisor, Colima, Lima, Apple container or Kata design. Firecracker appears only in the MicroVM guide. There are no per-agent containers, sibling-container controller or docker-socket use (I, from absence). `fdf7cbc2ec` only names a newer pullable image on About.

## 3. Apps

- **Two kinds (V).** A `backend.entryPoint` app is a sandboxed child process. A `backend.hooks` app runs inside the gateway (`docs/app-kit/api-reference.md:3009-3045`). The manifest doc says: "Not an in-process sandbox" (`docs/app-kit/manifest-reference.md:1964`).
- **Spawn chokepoint (V).** `src/kiro_crew/apps/backend_sdk/spawn.py:1-12,27-30` offers only the `standard` or `strict` tier, with no mask lifting. `run_sandboxed_async` (`:166-205`) runs the child in its own process group with resource limits, and kills group, child and reaps on timeout or cancel. A descendant that calls `setsid()` escapes the group (`:178-186`).
- **Filesystem (V).** Each app has its own data dir (`rfc-app-sandbox-isolation.md:89`). `382e5b5b49` makes the file-tool gate honour installed apps' declared credential masks. Before it, "the OS sandbox mask alone" fenced them. That is a path gate, not a per-app mount namespace (I).
- **Network (V).** `permissions.network` has "no runtime gate" (`rfc-app-sandbox-isolation.md:30-41,143-146`). Backends bind `127.0.0.1:$PORT` on the host network. App API reach is token-scoped and deny-by-default (`security-deep-dive.md:586-588`). Ownership and quotas are not implemented (RFC `:67-120`).
- **Approved sites `a72d85d645` (V).** `permissions.browserSites` lists exact HTTPS origins the owner approves on the app page. The tool gate then lets that app's own sessions navigate there unprompted. The commit says: "The owner accepted the risk ... a stronger sandbox is a follow-up."
- **Nesting (V).** An app backend is already inside a sandbox, so a second `wrap_argv` passes through. The tier is compared via `KIROCREW_SANDBOX_LEVEL` to catch a downgrade (`security.md:1882-1884`).

## 4. Remote dispatch and remote sessions

- **Remote dispatch (V, `docs/request-for-change/rfc-conductor-remote-dispatch.md:19-60`; `39929956c0` body).** A conductor places work on another running crew (a full gateway on another host) via the relay. The peer owns the session and its ledger. Since `39929956c0` placement also uses peer tags and per-tool login status (a word, no token). The boundary is the peer's own boundary (I).
- **Git proxy (V, `src/kiro_crew/remote_session/git_gateway.py:1-31`).** The guest never holds a git credential. Requests go over an authenticated link to the gateway, which accepts only git smart-HTTP on allowed hosts, rebuilds the URL itself, asks governance for `network.egress` (fail-closed, audited), refuses protected-branch pushes, and adds the host's credential to the upstream request only. `strict` lends none (`:22`).
- **Connected computers (preview, V).** Boundary: user consent, one folder, per-command `bwrap --unshare-pid --die-with-parent --new-session` plus seccomp on Linux. macOS and Windows have no fence, so the feature is unavailable there (`security-deep-dive.md:59`; `providers.md:682`). A turn in that chat is not re-checked against its initiator (`security-deep-dive.md:745-751`).

## 5. Lifecycle and resources

- **One process, many sessions (V).** "One agent runtime is one operating-system process, and one process can serve several sessions" (`docs/system-specs/modules/runtime-ownership.md:3-12`). `AcpRuntime` owns one `kiro-cli acp` process with a single reader that demuxes by session id (`src/kiro_crew/acp/runtime_class.py:78-87`). `AcpClient` is the direct per-session client (`acp/client_class.py:109`).
- **Sharing is opt-in (V).** Sub-agents share their parent's process. Dashboard chats share only under the `chat_runtime_sharing` preview, off by default (`acp/chat_runtime_sharing.py:1-30`). `66be1f33c4` and `651f7eaf16` add deepseek and goose, off by default. Cron, hook, incognito and Bot sessions keep their own process.
- **One kill gate (V).** Leases for who may end a runtime, tenancies for who merely uses it, and `authorize_runtime_kill` as the single gate (`runtime-ownership.md:14-25`).
- **cgroup v2 (V).** Each spawn runs in a transient `systemd-run --user --scope` when the user session has delegation. Defaults: `pids.max` 8192, `memory.max` 65% of host RAM per scope, `MemoryHigh` 90% of that, `CPUWeight` 50 (`src/kiro_crew/sandbox_cgroup.py:36-80`). Slice-wide ceilings are in `sandbox_slice.py:1-5`. Per-principal slices are "best effort" (`security.md:1842-1850`).
- **Cleanup (V).** `session_scope_reap` reclaims scopes stranded by a hard kill (`security.md:1862`). `sandbox_mount_sweep` reclaims stale mount sources, but never without a complete `/proc` pin scan, which a `hidepid` procfs prevents (`:1658-1662`). A kernel-versus-registry reconciler handles leaked runtimes (`runtime-ownership.md:504-570`). Detached daemons (Gradle, Bazel) outlive their command, status ACCEPTED (`security-deep-dive.md:849-867`).

## 6. Cross-platform

| | Linux | macOS | Windows |
|---|---|---|---|
| Mechanism | user+mount namespaces, escape filter | Seatbelt `allow default` + denies | none of its own; CLI's sandbox |
| Weakest point | shared kernel, PID and network; default tier shows `.aws`/`.ssh`/`.kube` | denylist; may delegate to the CLI sandbox, where crew-home masks do not apply | unsandboxed allowed by default, which "removes a deny-by-default authorization" (`security-deep-dive.md:112-114`) |
| Limits | cgroup v2 | RLIMIT (I) | job ceiling (`sandbox_slice.py` docstring) |

Crew-home masks do not apply on the delegated path, stated as a residual (`security-deep-dive.md:148-169`). WSL has working user namespaces but NAT networking, so jail backends opt it out (`sandbox_probe.py:963-973`).

## 7. Threat model and residuals

- **Threat model (V).** Prompt injection from content the agent reads. Payloads: credential exfiltration and destructive local action. Model untrusted, operator trusted, no single layer assumed to hold (`security-deep-dive.md:22-45`).
- **Egress (V).** "No network egress control by default." Governance `network.egress` can bound hosts. The stated fix is a network namespace or host firewall allowlist (`security-deep-dive.md:727-733`, also `:829-840`).
- **Loopback (I).** No `CLONE_NEWNET` in the launcher, so the agent shares loopback with the gateway. The defence is application-level: HMAC tokens, a Host allowlist on every method that does not trust a loopback peer, a loopback-plus-filesystem-secret rule for bootstrap routes, and a kernel-attested unix socket (V, `security-deep-dive.md:573-602`; `docker.md:177-215`).
- **Kernel sharing (I).** No dedicated kernel-escape item. Nearest: "No in-agent sandbox-escape detection" (`security-deep-dive.md:758`). The Docker profile's unconditional `unshare`/`clone`/`mount` allows widen kernel surface for the container's processes (`gen_profile.py:11-15`).
- **Other (V).** No PID namespace, so a named negative-pid `kill` can signal outside the spawn (`exec_lockdown.py:355-362`). Apps have no quotas.

## Implications for Genesis D1–D6

The task did not number the decisions. I map them as: **D1** Genesis-owned Linux VM (Colima, WSL2 distro). **D2** app in a container inside it. **D3** per-turn hardened sibling containers. **D4** a controller creates them, no docker socket in sandboxes. **D5** one sandbox per turn and per chat session. **D6** private network.

- **D1: supports as a pattern, nothing to copy.** KiroCrew ships no VM. It uses a VM or container as the outer boundary only on cloud lanes, and there it turns the inner sandbox off (`remote-crew-on-microvm.md:211-213`). Its WSL notes (kernel user namespaces, NAT networking) are checks for our WSL2 distro.
- **D2: supports.** KiroCrew ships a container gateway with a loopback-published port and non-root user. Copy its probe-driven, fail-closed startup posture. Ours should be stricter than its container, which sets no `cap_drop`, `read_only` or `no-new-privileges`.
- **D3: contradicts KiroCrew's shape and fixes its weak spots.** KiroCrew keeps one process tree on a shared kernel, PID and network, and in a container it needs a looser seccomp profile with unfiltered `unshare`/`clone`/`mount`. Sibling containers avoid that nesting, and the "userns blocked in a container" failure mode that takes about 200 lines of its docs. Add its rules: refuse to run when hardening cannot be verified, make explicit operator consent the only way to run weaker, and audit every downgrade.
- **D4: no counterpart; consistent with its principle.** Its git proxy keeps credentials on the trusted side and lets the guest ask over an authenticated channel (`git_gateway.py:1-31`). Consider the same brokered path for git and cloud credentials. Do not copy its default of leaving `.aws`/`.ssh`/`.kube` readable.
- **D5: stricter than KiroCrew, and closes its documented gaps.** KiroCrew shares ACP processes (opt-in), cannot bound detached descendants, and needs reapers plus a reconciler for crash cleanup. Container-per-turn makes teardown one removal. Add: per-sandbox cgroup limits (their defaults above), a startup reaper for orphaned sandboxes after a controller crash, and re-applying a changed policy at the next turn (`14c6b6c948`).
- **D6: supports, and fills KiroCrew's largest self-declared gap.** It lists missing egress control as a known gap and names a network namespace as the fix. Its agents also share loopback with the gateway. A private network removes both. Add a deliberate allowlisted path for the model endpoint and for git through a broker, or agents will break.
