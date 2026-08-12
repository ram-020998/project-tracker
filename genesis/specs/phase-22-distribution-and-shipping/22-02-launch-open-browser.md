# 22-02 — Launch + open browser (`genesis up`)

> **Status:** ✅ CODE-COMPLETE (2026-08-12; genesis code **held for the v0.47.0 release** at 22-06/07) · **Phase:** 22 ·
> **Repo:** genesis · **Depends on:** 22-01
>
> **As built:** `genesis/runtime/launcher.py` is the single source of truth (`up`/`down`/`status`/`logs` + health-wait +
> browser-open + PID/log under `~/.genesis/run`, loopback-mapped for 0.0.0.0/::). CLI `up [--host --port --no-open]` / `down` /
> `status` / `logs [-f]` added to `cli/main.py` (delegate to the module). `scripts/genesisctl.sh` **rewritten as a thin wrapper**
> (start→up, stop→down, restart, status, logs, open→up) so there's one implementation. `install.sh` next-steps updated to
> `genesis up`. **Verified:** ruff + shellcheck clean; **isolated end-to-end run** (temp state dir + port 8799, no browser):
> stopped → up (health passed) → running+healthy → down → stopped; **6 launcher unit tests** (pid/alive/loopback/healthy/
> status/down, mocked — no spawn); full backend suite **417** green.

## Goal
One command that boots the server in the background and opens the workbench in the user's default browser — the "run Genesis"
experience. Both a first-class `genesis` CLI subcommand and the `scripts/genesisctl.sh` script expose the same logic (§10.2).

## Behavior
- `genesis up [--host 127.0.0.1] [--port 8760] [--no-open]`
  1. If already running (live PID at `~/.genesis/run/genesis.pid`), just open the browser and exit 0.
  2. Else start `genesis serve` **detached** (nohup/setsid), writing PID + log under `~/.genesis/run/`.
  3. Poll `GET /api/config/health` until ready (bounded timeout) — report failure with the log tail if it never comes up.
  4. Unless `--no-open`, open the default browser at `http://<host>:<port>` (`open` on macOS, `xdg-open` on Linux).
- `genesis down` — stop the recorded PID (graceful, then force); clear the PID file.
- `genesis status` — running/stopped + PID + URL + health.
- `genesis logs [-f]` — tail the server log.

## Implementation
- Extract the process-control logic (start/stop/status/logs/open/health-wait) into a small module reused by BOTH the `genesis`
  CLI (`cli/main.py` subcommands) and `scripts/genesisctl.sh` (which already implements most of this) — one source of truth.
- Bind **127.0.0.1 by default** (never 0.0.0.0) — localhost-only per ADR-026/031.

## Acceptance
- `genesis up` on a fresh install opens the browser to a working workbench; re-running focuses/opens without a second server.
- `genesis down` stops it; `status` reflects reality; `logs -f` streams.

## Tests
- Unit: health-wait + PID lifecycle (mocked process/HTTP). `shellcheck` on the script.
- Covered end-to-end by the 22-06 clean-install boot check.
