# 19-01 — `gws` OAuth spike (load-bearing feasibility)

> **Status:** DRAFT — spec only. **Type:** time-boxed spike (throwaway code, durable findings — write up under `spike/`).
> **Gates:** 19-02 (the whole auth approach). Do this FIRST.

## Why a spike
The entire Google-Workspace auth design (umbrella §5) rests on one unverified assumption: that Genesis can drive `gws`'s
**standard interactive OAuth** by **spawning it as a non-interactive subprocess**, capturing the printed sign-in URL, and
letting `gws`'s localhost callback complete while the user approves in a browser. If `gws auth login` requires a real TTY or
its callback can't complete under a spawned process, the UI design changes. Same discipline as the 13-01 kiro-permission
spike — prove the load-bearing ACP/CLI behavior before building on it.

## Questions to answer (pass/fail)
1. **Config isolation works.** With `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=<tmp>` + `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file` +
   `GOOGLE_WORKSPACE_CLI_CLIENT_ID/SECRET` set, `gws` reads/writes creds entirely under that dir (nothing in `~/.config/gws`
   or the OS keyring).
2. **URL is captured.** Spawning `gws auth login -s drive.readonly,documents.readonly,spreadsheets.readonly,
   presentations.readonly` as a subprocess (no TTY) prints a parseable Google OAuth URL on stdout/stderr that we can extract.
3. **Callback completes under a spawned process.** Approving that URL in a browser drives `gws`'s localhost callback to
   completion, the subprocess writes encrypted creds and exits `0`, with **no** interactive TTY prompt required.
4. **Subsequent calls just work.** `gws drive files list --params '{"pageSize":1}'` succeeds afterward using only the config
   dir; a Google Doc **export** to Markdown and a Sheet read to CSV/JSON succeed (proves the parsing inputs in 19-04).
5. **Auth-failure signalling.** A missing/expired cred surfaces as **exit code 2** (so Genesis can detect "reconnect").
6. **Read-only scopes are honored.** A write attempt (e.g. create) is denied by Google under the read-only scopes.
7. **Fallback confirmed.** `gws auth export --unmasked` → `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` works headlessly (the
   fallback if (2)/(3) need a TTY).

## Method
- Obtain the shared OAuth client id/secret (Desktop-app type; confirm the localhost redirect is registered — otherwise
  `redirect_uri_mismatch`).
- Install the `gws` binary locally (brew/npm/release) into a scratch dir; drive it purely via `subprocess` with the env above,
  capturing stdout/stderr; simulate how Genesis's connector will invoke it.
- Record exact stdout framing of the URL, callback port behavior, exit codes, the export MIME options for Docs/Sheets/Slides,
  and the `drive files get` fields that carry the sync fingerprint (`modifiedTime`/`version`/`md5Checksum`).

## Deliverable
- `spike/2026-08-<dd>-gws-oauth-and-export.md`: findings + the exact invocation/env, the URL-capture + completion-detection
  mechanism (or the export-handoff fallback), the export MIME map, and the fingerprint fields — enough that 19-02/19-04/19-05
  can be built without re-discovery. **No production code in this sub-phase.**

## Exit criteria
All seven questions answered; a documented, working invocation recipe for (a) login, (b) verify, (c) export, (d) fingerprint
`get`, plus the chosen completion-detection strategy and the fallback. If (2)/(3) fail, 19-02's connector uses the
`auth export`/credentials-file handoff and the UI reflects that.
