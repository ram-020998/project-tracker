# Spike (2026-08-11) — `gws` OAuth + export feasibility (Phase 19, sub-phase 19-01)

> **Verdict: PASS — the primary design is viable.** Genesis can drive the Google Workspace CLI's **standard** OAuth by
> spawning `gws auth login` as a **non-interactive subprocess**, scraping the printed sign-in URL, and letting `gws`'s own
> `localhost` listener complete the callback. No TTY required; read-only scoping is native; the Drive sync fingerprint and
> Google-native export both exist. The `auth export` fallback is available but **not needed as the primary path**.
> Throwaway probe; findings are durable. Environment: **`gws 0.22.5`**, macOS 26.5.2 arm64, installed via
> `brew install googleworkspace-cli`. Probed with a scratch config dir + dummy client (no real credentials).

## Results by spike question

| # | Question | Result | Evidence |
|---|---|---|---|
| Q1 | Config isolation via `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` + `KEYRING_BACKEND=file` | **PASS** | `gws auth status` reported it uses `<dir>/client_secret.json`, `<dir>/credentials.enc`, `<dir>/credentials.json`; **no `~/.config/gws` was created**. |
| Q2 | Login prints a **parseable URL** under a spawned process | **PASS** | With stdin closed + no TTY, `gws auth login` printed to **stderr**: `Open this URL in your browser to authenticate:` + `https://accounts.google.com/o/oauth2/auth?...redirect_uri=http://localhost:64924&...`. |
| Q3 | Callback completes under a **spawned** process | **PASS (mechanism) / manual (full)** | `gws` starts a `localhost:<ephemeral>` listener and **blocks** on it (5s timeout → exit 124) with no TTY prompt. Full completion (callback → creds written → exit 0) needs a real client + a human browser approval → **manual acceptance step**. |
| Q4 | Drive list + Docs/Sheets **export** work | **manual (needs creds)** — but the surface exists | `gws drive files export` exports a Google doc to a requested MIME type (`-o` output, `--dry-run` available); `gws drive files list/get` exist. Real calls need credentials. |
| Q5 | Missing/expired creds → **exit code 2** | **PASS** | `gws drive files list` (no creds) → `{ "error": { "code": 401, "reason": "authError" } }` and **exit 2**. |
| Q6 | Read-only scopes | **PASS** | `gws auth login --readonly -s drive,docs,sheets,slides` requested exactly `drive.readonly`, `spreadsheets.readonly`, `documents.readonly`, `presentations.readonly` (+ openid/email/profile). |
| Q7 | `auth export` fallback | **PASS (exists)** | `gws auth export --unmasked` prints decrypted creds to stdout; pairs with `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` / `GOOGLE_WORKSPACE_CLI_TOKEN` (both documented env vars). Full round-trip needs real creds. |

**Exit-code table (confirmed):** `0` success · `1` API error · `2` auth error · `3` validation · `4` discovery · `5` internal.

## The connector recipe (for 19-02)

**Fixed env on every `gws` invocation** (Genesis-owned, self-contained under `~/.genesis`):
```
GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.genesis/cli-tools/gws/config
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file
GOOGLE_WORKSPACE_CLI_CLIENT_ID=<shared org client id>       # from Genesis SecretProvider
GOOGLE_WORKSPACE_CLI_CLIENT_SECRET=<shared org client secret> # from Genesis SecretProvider
```

**Connect flow:**
1. Spawn: `gws auth login --readonly -s drive,docs,sheets,slides` (subprocess; stdin may be closed).
2. **Capture the URL from stderr** — match `https://accounts.google.com/o/oauth2/auth?...` (note: it's on **stderr**, not
   stdout). Surface it in Settings → CLI for the user to open. `gws` also attempts to auto-open the browser via macOS `open`;
   surfacing the URL covers the headless/attended case regardless.
3. The user approves → Google redirects to `gws`'s `http://localhost:<ephemeral>` listener (same machine) → the subprocess
   writes `credentials.enc` and exits `0`. No reverse-proxy needed (Genesis on :8760, gws's callback on its own port).
4. **Verify connected:** `gws auth status` → parse JSON (`auth_method`/`storage`/`credential_source` ≠ `"none"`), then a cheap
   `gws drive files list --params '{"pageSize":1}'`.
5. **Reconnect detection:** any `gws` call returning **exit 2** ⇒ creds missing/expired ⇒ prompt reconnect. (`gws auth status`
   itself returns exit 0 even when unauthenticated — it *reports* `auth_method:"none"`; use it for the status badge, use exit 2
   from a real call for the failure signal.)

**Sync fingerprint (for 19-05):** `gws drive files get --params '{"fileId":"<id>","fields":"id,name,mimeType,modifiedTime,version,md5Checksum"}'` — all six fields are in the Drive `File` schema (verified via `gws schema drive.files.get`). Change detection = compare stored `modifiedTime`/`version`/`md5Checksum`.

**Export (for 19-04):** `gws drive files export --params '{"fileId":"<id>","mimeType":"<target>"}' -o <path>` for Google-native
docs (Docs→`text/markdown` or `text/plain`, Sheets→`text/csv` per sheet, Slides→`text/plain`). Binary uploads (PDF/DOCX/XLSX)
are downloaded via `drive files get` (alt=media) and parsed server-side (19-04).

## What still needs manual acceptance (cannot be driven headlessly)
- Full login completion + real Drive list / Docs export / Sheets export — needs the **shared org OAuth client** + a human
  browser approval. Recipe above is exact; run once in 19-02/19-08 acceptance.
- **Dependency to obtain:** the shared org OAuth **client id/secret** (Desktop-app type; the `localhost` ephemeral redirect is
  what `gws` uses, so a Desktop-app client is correct — confirm the client allows loopback redirects). Provision into Genesis
  secrets.

## Conclusion
Proceed with **19-02 as specced** — the primary browser-OAuth-under-subprocess mechanism works; the `auth export` handoff
stays documented as a fallback but is **not** the primary path. No spec changes required.

## Live end-to-end verification (2026-08-11, after dotfiles setup on the real machine)
The manual-acceptance items are now **confirmed on real infrastructure**:
- `dotfiles` provisioned **`~/.config/gws/client_secret.json`** (mode 0600) — a Desktop-app `installed` client (`client_id`
  ending `apps.googleusercontent.com`, `client_secret` present, `redirect_uris:["http://localhost"]`); `gws auth status`
  reports `client_config_exists:true`, `credential_source:"client_secret.json"`. **Q3/Q4 = confirmed.**
- After `gws auth login`, **`gws drive files list` returned exit 0** with real files carrying `modifiedTime` + `version` (the
  19-05 sync fingerprint) — read-only Drive access proven against live data.
- **Decision (locked):** Genesis reads the OAuth client from `~/.config/gws/client_secret.json` (dotfiles = documented
  prerequisite), ships **no** token, and drives `gws auth login` under its own config dir. See ADR-040 + 19-02.
