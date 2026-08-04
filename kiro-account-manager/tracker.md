# Project Tracker: Kiro CLI Multi-Account Manager

**Status:** ✅ Working, validated, documented
**Owner:** ramaswamy.u (macOS)
**Last updated:** 2026-07-27
**Deliverable location:** `~/.kiro-accounts/` (NOT in this tracker repo)

---

## 1. Goal

Let the user maintain **multiple Kiro CLI logins on one macOS user account** and
switch between them with one command. All target accounts use the **same auth
type: AWS IAM Identity Center**.

Origin: user asked "is there a way to maintain multiple Kiro CLI logins on my
laptop?" → investigation showed no native support → built a custom switcher.

---

## 2. TL;DR of what was built

A single Bash tool `kiro-account` that snapshots the CLI's auth records per named
account and swaps them into the live credential stores on demand.

Files (all under `~/.kiro-accounts/`, dir perms `700`):

| File | Purpose |
|---|---|
| `kiro-account` | The tool (executable bash). `chmod 755`. |
| `README.md` | Full user/technical documentation (`644`). |
| `main.json` | Snapshot of the user's current corporate login (`600`). |
| `_autobackup.json` | Auto-saved previous login, written on every `switch`. |
| `nivi.json` | (Not yet created — user will add the 2nd account.) |

Alias added to `~/.bashrc`:
```bash
# BEGIN KIRO-ACCOUNT MANAGER
alias kiro-account="$HOME/.kiro-accounts/kiro-account"
# END KIRO-ACCOUNT MANAGER
```

---

## 3. Key technical findings (the important part)

Environment verified: **Kiro CLI v2.14.2**, macOS, shell = **Homebrew bash**
(`/opt/homebrew/bin/bash`), `kiro-cli` at `~/.local/bin/kiro-cli` →
`/Applications/Kiro CLI.app/Contents/MacOS/kiro-cli`.

### 3.1 `KIRO_HOME` does NOT isolate login
- Docs claim `KIRO_HOME` redirects `~/.kiro` and that "sessions" resolve against
  it. Reality on macOS: it isolates **agents, prompts, skills, steering,
  settings, chat history** — but **NOT credentials**.
- Proof: `KIRO_HOME=~/.kiro-nivi kiro-cli whoami` reported the SAME account
  (`ramaswamy.u@appian.com`, IAM Identity Center, start URL
  `https://stratus.awsapps.com/start`). A fresh empty dir was already "logged in".

### 3.2 Where the CLI actually stores the login
Two credential records, kept **in sync across two stores**:

| Record key | Contents | Size (bytes) |
|---|---|---|
| `kirocli:odic:token` | access token + **refresh token** + expiry + region | ~726 |
| `kirocli:odic:device-registration` | OIDC client registration | ~4103 |

Stores (both hold identical values — verified same `expires_at`):
1. **macOS Keychain** — generic-password items keyed by **service name** (above).
   Lookup is **by service name; the account attribute is ignored** (verified —
   see 3.4).
2. **SQLite** — `~/Library/Application Support/kiro-cli/data.sqlite3`, table:
   ```sql
   CREATE TABLE auth_kv (key TEXT PRIMARY KEY, value TEXT);
   ```
   Current keys present:
   ```
   codewhisperer:odic:device-registration   (legacy, from Amazon Q migration)
   codewhisperer:odic:token                  (legacy)
   kirocli:odic:token                        (ACTIVE - what we swap)
   kirocli:odic:device-registration          (ACTIVE - what we swap)
   ```

Other keychain slots exist for other auth types (NOT used here):
`kirocli:social:token`, `kirocli:external-idp:token`.

### 3.3 Token refresh behavior (why swapping works)
- Access token `expires_at` can already be in the past and `whoami` still works —
  the CLI **auto-refreshes from the refresh token at launch**. So each fresh
  `kiro-cli` invocation re-reads the stored records → swap-on-disk is picked up.
- Refreshed tokens are held **in memory** during a running session and written
  back on exit (see Kiro GitHub issue #4847). → **Must quit running kiro-cli
  sessions before switching**, else an exiting session overwrites the swap.

### 3.4 Keychain manipulation semantics (verified on dummy service)
- `security add-generic-password` **requires `-a` (account)**; the CLI's own
  items have `acct=NULL` (created via Security framework API, not the CLI tool).
- `security find-generic-password -s <svc>` returns ONE match (first).
- `security delete-generic-password -s <svc>` deletes ONE item at a time.
- Multiple items with same service can coexist.
- **Critical validation:** deleted the real `kirocli:odic:token` keychain item
  and recreated it with `acct="kiro-account"` (was NULL) using the SAME value →
  `kiro-cli whoami` STILL resolved the login. **Conclusion: CLI finds token by
  service name regardless of account attribute.** So delete+recreate under a
  fixed account label is safe.

### 3.5 Why third-party tools don't work for the CLI
- `kiro-switcher` (PyPI) and GitHub "Kiro-account-manager" repos operate on the
  Kiro **IDE** token file `~/.aws/sso/cache/kiro-auth-token.json`.
- The **CLI** uses the keychain + `data.sqlite3` — different store. So those
  tools switch the IDE, not the CLI.
- Note: `~/.aws/sso/cache/` on this machine has both `kiro-auth-token.json`
  (IDE, fresh) and `kiro-auth-token-cli.json` (stale, June — CLI no longer uses
  it as source of truth; keychain is authoritative).
- Some repos (otieno988/...) were already 404/deleted — ephemeral, avoid.

### 3.6 Auth types / login methods (why "same auth type" matters)
`kiro-cli login` offers three authentication methods, and **each stores its token
in a different keychain slot / auth_kv key**:

| Auth type | What it is | Keychain service (auth_kv key) |
|---|---|---|
| **IAM Identity Center** (`odic`) | Org/corporate SSO via start URL (user's: `stratus.awsapps.com/start`) | `kirocli:odic:token` |
| **Builder ID / Social** | Personal AWS Builder ID, or Google/GitHub | `kirocli:social:token` |
| **External IdP** | External identity provider | `kirocli:external-idp:token` |

- This tool only reads/writes the **`odic`** slot (the two `kirocli:odic:*`
  records). It does NOT touch the social/external-idp slots.
- **Therefore every managed account must be logged in with IAM Identity Center.**
  When adding `nivi`, choose **IAM Identity Center** at the login prompt — NOT
  Google/GitHub/Builder ID. A different method lands in a slot the tool ignores,
  so it wouldn't switch correctly.
- Extending to mixed types is possible but out of scope: it would require
  snapshotting/swapping all three slots and clearing the inactive ones so the CLI
  doesn't get confused about which login is active. User confirmed all accounts
  are the same type (Identity Center), so this simpler single-slot design is used.

---

## 4. How the tool works (implementation)

`kiro-account` commands:
```
login <name>    run 'kiro-cli login', then snapshot as <name>
save <name>     snapshot CURRENT live login (reads sqlite auth_kv) -> <name>.json
switch <name>   write snapshot's 2 records into BOTH keychain + sqlite
delete <name>   remove snapshot json (does NOT log out live session)
list            list snapshots; marks active (exact token match)
current         kiro-cli whoami
```

Mechanics:
- **save**: reads `kirocli:odic:token` + `kirocli:odic:device-registration` from
  `data.sqlite3` (opened `immutable=1`, read-only) via python3/sqlite3, writes
  `{name, saved_at, auth_kv:{...}}` to `<name>.json` (chmod 600).
- **switch**:
  1. `save _autobackup` (snapshot current login first).
  2. `INSERT ... ON CONFLICT(key) DO UPDATE` both rows into `data.sqlite3`.
  3. Keychain: for each service, loop `delete-generic-password -s` until gone,
     then `add-generic-password -U -s <svc> -a kiro-account -w <value>`.
- **running guard**: refuses to switch if `pgrep -x kiro-cli` matches, unless
  `KIRO_ACCOUNT_FORCE=1`. (Note: running from inside a kiro-cli chat session
  triggers this guard — must use a separate terminal, or force.)
- **name validation**: rejects empty, `/`, or `..`.

Dependencies (all present): `bash`, `python3`, `sqlite3`, macOS `security`.

---

## 5. What was tested / validated

| Test | Result |
|---|---|
| `KIRO_HOME` isolation of login | ❌ shares login (documented finding) |
| sqlite vs keychain token values identical | ✅ same `expires_at` |
| keychain add/update/delete semantics | ✅ on dummy service |
| Round-trip `switch main` (write identical data back) | ✅ whoami still logged in; keychain acct changed NULL→kiro-account; auth_kv intact |
| `save` / `list` / `delete` / help / name guard | ✅ all pass |
| `bash -n` syntax check | ✅ OK |
| **Real switch between two different accounts** | ⏳ NOT YET — user has only 1 account so far; validated write-path only |

---

## 6. Remaining / next steps

1. **User to add 2nd account** in a fresh terminal:
   ```bash
   source ~/.bashrc
   kiro-account login nivi
   kiro-account switch main   # verify: kiro-account current
   kiro-account switch nivi   # verify: kiro-account current
   ```
2. **First real cross-account switch is the final unproven step.** Expected to
   work based on validated write-path + service-name lookup, but confirm that
   `whoami` reports the correct distinct account after each switch (with no
   kiro-cli sessions running).
3. Optional future enhancements (not requested): auto-refresh a snapshot's token
   on switch; a `rename` command; encrypt snapshots at rest.

---

## 7. Caveats / risks (carry forward)

- **One active account at a time** — swaps a single shared slot; not concurrent.
- **Quit running sessions before switch** (in-memory token writeback, issue #4847).
- **Same auth type only** (Identity Center / `odic`).
- **Refresh tokens stored plaintext** in `~/.kiro-accounts/*.json` (0600). One is
  a corporate Appian credential — **do not sync this folder to git/cloud/backups.**
- **"active" marker is exact-match** and may not highlight after a background
  token refresh — cosmetic only.
- **Global install untouched**: `~/.kiro` and the CLI binary are never modified;
  only the shared auth store is written at switch time (unavoidable for switching).

---

## 8. Design decision: share the global ~/.kiro (auth-only isolation)

**Decision (2026-07-27):** Only the **auth/login** is per-account. Everything
else (sessions, agents, settings, skills, steering, chat history, knowledge
bases) is intentionally **SHARED via the native global `~/.kiro/`** and the
shared app-data DB. This is exactly what the `kiro-account` tool does — it swaps
only the login token and never sets `KIRO_HOME`.

Where things live (verified):
- Relocatable via `KIRO_HOME` (in `~/.kiro/`): `agents`, `settings`, `skills`,
  `steering`, `powers`, `extensions`, `logs`, `workspace-roots`, `sessions/`
  (verified: `~/.kiro/sessions` had ~60 entries).
- Fixed on macOS (in `~/Library/Application Support/kiro-cli/`): `data.sqlite3`
  (`auth_kv` = login; `conversations` (23 rows), `conversations_v2` (316 rows),
  `history` (2849 rows) = chat transcripts; `state`), and `knowledge_bases/`.

What is per-account vs shared (with the auth-only design):

| Data | With `kiro-account` (auth swap, no KIRO_HOME) |
|---|---|
| Login identity | **Per-account** ✅ (only thing that changes) |
| Sessions (`~/.kiro/sessions`) | shared (global `~/.kiro`) |
| Agents / settings / skills / steering | shared |
| Chat transcript history (`data.sqlite3`) | shared |
| Knowledge bases | shared |

Because the account manager does NOT set `KIRO_HOME`, all of the above resolve to
the shared global locations for every account. Login identity is the only thing
that changes on `switch`.

**Cleanup done:** the earlier `~/.kiro-nivi` `KIRO_HOME` experiment (isolated
profile) was **removed** — directory deleted and the `kiro-nivi` alias removed
from `~/.bashrc` — since it conflicts with the "shared global repo" decision.
Only the `kiro-account` alias remains in `~/.bashrc` (line ~48). Kiro-managed
shell-integration blocks were left untouched; `bash -n` passes.

---

## 9. Quick reference — system locations

```
Tool + snapshots:  ~/.kiro-accounts/
CLI config (KIRO_HOME target): ~/.kiro/  (shared global — auth-only isolation, see §8)
CLI auth DB:       ~/Library/Application Support/kiro-cli/data.sqlite3  (table auth_kv)
CLI keychain:      login keychain, services:
                     kirocli:odic:token
                     kirocli:odic:device-registration
IDE token (diff!): ~/.aws/sso/cache/kiro-auth-token.json
Shell rc:          ~/.bashrc (sourced by ~/.bash_profile)
kiro-cli binary:   ~/.local/bin/kiro-cli -> /Applications/Kiro CLI.app/Contents/MacOS/kiro-cli
```

---

## 10. Full documentation

The end-user + technical docs live with the tool:
**`~/.kiro-accounts/README.md`** (257 lines) — covers storage internals, install,
every command, add-second-account walkthrough, security, troubleshooting,
uninstall, and KIRO_HOME background.
