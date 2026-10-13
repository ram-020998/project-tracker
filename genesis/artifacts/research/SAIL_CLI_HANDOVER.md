# SAIL CLI — Handover Document

**Purpose of this document:** Provide complete context to an agent tasked with building a
Python library ("SDK") that wraps the Appian **SAIL CLI** so Appian application testing can be
automated in Python scripts (the way Playwright scripts are written), without an AI agent in the
loop.

**Status of the tool:** Internal preview (Appian employees). Ships bundled with the DevMCP
AppMarket plugin. Version verified in this environment: **`sail version 26.6.95`**.

**Verified on:** macOS (Apple Silicon / arm64), against Appian host
`merge-assist-dev.appianpreview.com`, on 2026-09-24. Every command and behavior in this document
was executed and observed, not assumed. Where something is a documented claim I could not directly
verify, it is marked as such.

---

## 1. What the SAIL CLI is

`sail` is a **standalone, single-file binary** (written in Go) that drives Appian **SAIL end-user
interfaces** from the command line. It lets an automated caller "click around" an Appian site —
load pages, fill and submit forms, follow record links / record actions / process start forms — and
reports back what changed on screen.

It is positioned as a **faster, lower-token alternative to Playwright** for exercising Appian UI
logic. Instead of a real browser + DOM + CSS/XPath selectors, it speaks Appian's SAIL protocol
directly and addresses components by their **label** (or internal id). No browser, no webdriver, no
runtime to install.

Two intended use cases (from the official preview docs):
1. **Agentic testing** — an AI agent (e.g., via DevMCP) uses it to verify an app it just built.
2. **Regression tests** — deterministic scripts drive interfaces and assert on output. **This is
   the use case the Python library targets.**

**Critical framing for the library author:** There is **no `import sail` Python package and no
in-process API.** "Scripting SAIL" means **invoking the `sail` binary as a subprocess** and parsing
its output. The Python library being built is therefore a **subprocess wrapper / SDK** around the
CLI — analogous to how some tools wrap `ffmpeg` or `git`. This was explicitly confirmed by writing
and running a working Python test (see §9).

### Relationship to DevMCP
The SAIL CLI is **technically independent** of the DevMCP plugin and its MCP server — it does not
require them to run. It is *distributed* inside the DevMCP MCP-server bundle for convenience. The
one point of integration: on an SSO-only site, `sail` can **import a browser session that DevMCP
captured** (see §6, `--from-devmcp`).

---

## 2. Where the SAIL CLI lives (access / install locations)

In this environment the tool is already installed and on PATH.

- **Binary (this machine, macOS arm64):**
  `/Users/ramaswamy.u/appian-dev-mcp-server/bin/sail-darwin-arm64`
- **Symlink on PATH (what `sail` resolves to):** `/usr/local/bin/sail` → the arm64 binary above.
  Verified: `command -v sail` → `/usr/local/bin/sail`.
- **The bundle's `bin/` directory** also ships the other platforms and the setup scripts:
  ```
  /Users/ramaswamy.u/appian-dev-mcp-server/bin/
    sail-darwin-arm64          # macOS Apple Silicon
    sail-linux-amd64           # Linux x86-64
    sail-windows-amd64.exe     # Windows x86-64
    setup-mac.sh
    setup-linux.sh
    setup-windows.bat
    ../BUILD-INFO.txt           # build commit/timestamp metadata
    ../INSTALL.txt              # install notes
  ```
- **Original download / preview materials** (instructions + PDF + raw bundle):
  - `/Users/ramaswamy.u/Documents/sail-cli/SAIL CLI Internal Preview Instructions.md`
  - `/Users/ramaswamy.u/Documents/sail-cli/SAIL CLI.pdf`
  - `/Users/ramaswamy.u/Documents/sail-cli/mcp-bundle.tar.gz` (~11 MB, the raw preview bundle)
  - Duplicated in `/Users/ramaswamy.u/Downloads/`.
- **Official docs (per AppMarket listing):** https://docs.appian.com/suite/help/latest/devmcp.html
  and the AppMarket page: https://appmarket.appian.com/listings/appian-dev-mcp

### Installation / setup (how it got onto PATH)
The binary is unsigned and was downloaded, so macOS Gatekeeper **quarantined it**. Symptom
observed: running it produced **`Killed: 9` (exit 137)** with **zero stdout/stderr** — easy to
mistake for a silent/no-op binary. (A `| head` pipe hides this because the pipeline reports
`head`'s exit code, not the binary's.)

Fix = run the bundled setup script once. It is idempotent and refuses to clobber files it did not
create:
```bash
/Users/ramaswamy.u/appian-dev-mcp-server/bin/setup-mac.sh
```
It does three things:
1. Clears the `com.apple.quarantine` xattr on the binary (`xattr -d com.apple.quarantine <bin>`).
2. Symlinks it as `sail` into a directory already on PATH (`/usr/local/bin`, falling back to
   `~/.local/bin`). It deliberately does **not** edit `.zshrc`/`.bash_profile`.
3. Runs `sail --help` to prove it actually executes.

Observed successful output:
```
[*] cleared the quarantine flag Gatekeeper set on sail-darwin-arm64
[*] linked /usr/local/bin/sail -> /Users/ramaswamy.u/appian-dev-mcp-server/bin/sail-darwin-arm64
[*] /usr/local/bin/sail runs
Ready. Run: sail --help
```
Manual equivalent if needed: `xattr -d com.apple.quarantine <bin> && chmod +x <bin> && ln -s <bin> /usr/local/bin/sail`.

> **Library implication:** The wrapper should not assume `sail` is on PATH. Allow the binary path to
> be configured (constructor arg / env var, e.g. `SAIL_BIN`), defaulting to `sail`. On macOS,
> consider detecting the `Killed: 9`/exit-137-with-empty-output case and surfacing a clear
> "binary is quarantined, run setup" error.

---

## 3. Command surface (complete)

Global form: `sail [command] [args] [flags]`

**Global flags (apply to every subcommand):**
- `--data-dir <path>` — session/UI state directory. Defaults to `$SAIL_HOME` or `~/.sail`.
  **Set this per run to isolate concurrent tests.** (Central to the library — see §5.)
- `--json` — emit machine-readable JSON instead of human/agent text. **Always use this from code.**
- `-h, --help` — every command self-documents here.
- `-v, --version` — prints e.g. `sail version 26.6.95`.

**Subcommands:**

| Command | Signature | What it does | Server call? |
|---|---|---|---|
| `login` | `sail login <host> [site] [--from-devmcp] [--user <id>]` | Authenticate; store session (cookies + CSRF). | Yes |
| `logout` | `sail logout` | Invalidate session **on the server**, delete local session + all page state. Teardown. | Yes |
| `pages` | `sail pages <site>` | List a site's pages in tab order; marks default + currently-loaded. | Yes |
| `load` | `sail load <site> [page] [--fresh]` | Fetch a page fresh (also how you **switch tabs/pages**). Discards entered values. | Yes |
| `show` | `sail show <site>` | Reprint the currently-loaded page from local state. **Free, no server call, changes nothing.** | No |
| `interact` | `sail interact <site> <labelOrId> [value] [<labelOrId> [value] ...] [--confirm]` | Drive one or more components; merge server response; print what changed. | Yes |
| `navigate` (alias `nav`) | `sail navigate <site> <target>` | Follow a record link / record view / related action / process start link by its handle. | Yes |
| `back` (aliases `close`, `dismiss`) | `sail back <site>` | Restore the UI you navigated away from / dismiss a dialog (the dialog's ✕). | No (local) |
| `completion` | `sail completion <shell>` | Generate shell autocompletion. | No |
| `help` | `sail help [command]` | Help about any command. | No |

Notes that matter for automation:
- **`load` refuses to run over a page that has been interacted with** (won't silently discard entered
  data). Use `--fresh` to force it. Observed error:
  `error: source-selection is loaded with 2 interactions already made ...; loading would fetch a new page and discard that.`
- **`back` is not a Cancel button.** In Appian a Cancel *button* is an ordinary submit; drive it with
  `interact`. `back` is the dialog-✕ / leave-start-form equivalent.
- **`navigate`**: a record view / related action is a GET (undoable with `back`); a **process launch
  is a POST and is NOT undoable**. A record action's open mode (DIALOG/SAME_TAB/NEW_TAB) is cosmetic
  — same request underneath.

---

## 4. Addressing components (the "selector" model)

Playwright uses CSS/XPath. SAIL CLI uses **the component's on-screen label** (case-insensitive), or
its internal `_cId`. Rules gathered from `sail interact --help` and observed output:

- **Label matching:** case- and punctuation-insensitive; may be **shortened to any unambiguous
  prefix** (Appian labels are often full sentences). An ambiguous shortening is refused and the error
  names the candidates.
- **`_cId` is per-render and MUST NOT be persisted in scripts.** The server mints new ids each
  render. Use labels (or the stable synthetic refs below) in stored tests.
- **Synthetic refs `⌗ ...`** — SAIL CLI invents these for components the app left unnamed or named
  ambiguously (e.g., `⌗ Full Name 1`, `⌗ Full Name 2` for `a!forEach` rows). **These are stable
  across reloads** and safe to write into scripts.
- **Composite components** (grids, charts, tabs, hierarchy/org charts) are listed once with a
  `handle:` line per addressable target (columns, sort handles, pagination, chart points, tree
  nodes). Pass the handle **exactly as printed**. On pages with two grids, handles are name-qualified
  (e.g., `⇅ Parts / Amount`); an unqualified handle matching two grids is refused.

**Values by component type** (from `interact --help`):
| Component | Value to pass |
|---|---|
| button / link | *nothing* — omit the value (the target is the whole instruction) |
| text / paragraph / integer / decimal | the literal text |
| dropdown / radio / checkbox | **1-based index** into the listed options. Multi-select/checkbox: `"1,3"`; `""` selects none; a dropdown with a placeholder empties by selecting index 1 |
| date / datetime | `YYYY-MM-DD` or `M/D/YYYY` |
| file upload / signature | a path to a local file |
| grid / chart / tabs / hierarchy | a `handle:` from the component; no value |
| picker / record-grid search | a handle **plus** the search text |

Two subtleties:
- A no-value target (button) may stand **only at the END** of a batch — mid-batch, a lone target
  can't be distinguished from the previous target's value.
- An option printed as a **range** like `"4-468=SelfTest User"` is one shared label; pass a single
  index from that range.

---

## 5. State & session model (essential for the library)

`sail` is **stateful on disk**. Each `--data-dir` (default `~/.sail`) holds:
```
<data-dir>/
  session.json                              # auth session
  <site>-ui.json                            # full UI tree of the loaded page (large; ~97 KB observed)
  <site>-ui-concise.yaml                    # the human/agent-readable concise view (~32 KB observed)
```
`session.json` top-level keys (values not shown — secrets):
`hostname`, `cookies` (list), `csrfToken` (string), `timestamp` (string), `username` (string).

Consequences the library MUST handle:
1. **Session persists across process invocations.** `login` once, then many `load`/`interact`/`show`
   calls reuse it. No need to re-auth per command.
2. **One loaded page per data-dir at a time.** To drive two pages "simultaneously" (two-browser-tab
   scenarios), give **each its own `--data-dir`**.
3. **Concurrency / isolation:** parallel tests **must** use separate `--data-dir` values or they
   corrupt each other's state. The docs explicitly recommend per-run data-dirs. Recommended pattern:
   a temp dir per test/worker (e.g., pytest `tmp_path`), cleaned up via `logout` in teardown.
4. **A data-dir with no session** → commands fail with `error: no session found; run "sail login <hostname>" first`.
   **This was observed and is a real gotcha:** if you isolate with a fresh `--data-dir`, you must
   `login` into *that* data-dir first. (Discovered when the first Python test run failed — see §9.)
5. **`show` reads local state only** (free), but can therefore be **stale** after a submit or while a
   started process is still running; when known, the headline says so and names the reload.
6. **`logout` is destructive teardown:** it invalidates the session server-side (not just locally),
   deletes `session.json`, and deletes all page-state files (which contain whatever was typed —
   names, emails, codes). To keep page state, copy it out of the data-dir first.

---

## 6. Authentication (all paths)

`login` uses **environment variables** for credentials (kept out of argv):
- `SAIL_USERNAME`
- `SAIL_PASSWORD`

**Paths:**
- **Local Appian account (basic auth)** — the normal case, and what works in this environment. On a
  site that also has SSO, this must be the **local test account**, not an SSO identity.
  ```bash
  export SAIL_USERNAME='...'; export SAIL_PASSWORD='...'
  sail login <host>
  ```
- **SSO-only site** — there is no password to send. `sail` **cannot do the SSO/MFA browser flow
  itself.** Instead: authenticate via **DevMCP with `LCP_AUTH_METHOD=browser`** (it opens a browser,
  captures the session), then import it — **no browser, no credentials in `sail`**:
  ```bash
  sail login mycompany.appiancloud.com --from-devmcp
  # add --user <id> if several identities are cached for the host
  ```
- **Custom base URL** (drive a SAIL UI served somewhere other than `/suite`) — `<host>` may be a full
  base URL, e.g. `sail login http://127.0.0.1:8801/api/remotes/MyRemote/live`. Such a base holds its
  own session, so no credentials are sent.

`<host>` is normally a bare hostname (e.g. `mycompany.appian-sites.net`).

**`login --json`** returns a small object: `{"hostname": "...", "status": "ok"}` (verified).

### The exact working config in THIS environment
Reused from the DevMCP MCP config at
`/Users/ramaswamy.u/appian-dev/.kiro/settings/mcp.json` (server key `appian`):
- Host / `LCP_URL`: **`merge-assist-dev.appianpreview.com`**
- Auth method: **basic**
- `LCP_USERNAME` → `SAIL_USERNAME`: **`kiroDeveloper`**
- `LCP_PASSWORD` → `SAIL_PASSWORD`: **`appian26`**  *(dev-only preview credential; treat as a secret,
  inject via env/CI secret — do not hardcode in committed code)*

Verified login:
```bash
SAIL_USERNAME='kiroDeveloper' SAIL_PASSWORD='appian26' \
  sail login merge-assist-dev.appianpreview.com
# → ✓ Logged in to merge-assist-dev.appianpreview.com
```

> **Auth constraints to encode in the library:** SSO is not directly supported (needs the DevMCP
> import bridge); credentials come only from env vars, never argv; in CI, inject them as secrets.

---

## 7. Output model (parsing contract)

Two output modes:
- **Default (human/agent text):** an "On screen" section listing every addressable ref quoted
  exactly as it must be passed, plus read-only `<display>` values, grid handles, etc. Good for
  humans/agents; **not ideal for scripts.**
- **`--json`:** structured. **Use exclusively from the library.**

Structure observed from `sail interact ... --json`:
```json
{
  "changed": [
    {
      "#t": "MultipleDropdownWidget",   // SAIL component type
      "_cId": "d09ce149...",            // per-render id — DO NOT persist
      "inlineLabel": "Task Type",
      "choices": ["Address Review Comment", "Attach Document", "Complete Evaluation", ...],
      "value": [3],
      "testLabel": "My Tasks-userFilterDropdown_1",
      ...
    },
    { "#t": "MenuItem", "primaryText": "Clear filters", "link": { "#t": "DynamicLink", ... }, ... }
  ],
  "changedFields": [
    { "changes": [ { "key": "value", "new": "3 (Complete Evaluation)", ... } ] }
  ]
}
```
Key fields for assertions: component `#t` (type), `inlineLabel` / `testLabel` / `primaryText`
(labels), `value`, `choices`, and the `changedFields` **diff** (`key` / `new` / old). Note the
Appian `#t`/`#v` tagged-value convention appears throughout the tree.

**Semantics of a result (from `interact --help`):**
- `✓ Interacted` = the server changed something.
- If the server accepted the interaction but **no value moved**, the headline says so — **treat that
  as a failure to drive the component, not a completed step.** (The library should detect this and
  raise, not pass silently.)
- **Cascades:** the server often changes MORE than you set (e.g., selecting a Division clears its
  dependent Department and refilters it). That cascade is usually the behavior worth asserting on.
- **Structural re-render:** some interactions reprint the whole page ("the whole page re-rendered (a
  structural change)"). Observed when clicking "Clear filters".

**Confirmations:** a target whose line carries `confirm:` is **refused by default** (the confirm
dialog is browser-drawn; sending blind would perform the action outright). Pass **`--confirm`** to
proceed; in a batch it covers every pair in that command.

**Batching:** multiple `label value` pairs in one `interact` go out as **one request / one
round-trip**. Only batch fields the CURRENT UI already contains (Appian forms are progressively
disclosed; a field may not exist until an earlier save returns). Targets are resolved **before**
sending; **one unresolvable target fails the whole command** (no partial execution).

**Exit codes:** `0` on success; non-zero on error with a message on stderr (and sometimes stdout).
The library's subprocess wrapper should treat non-zero as an exception and surface stderr.
`--json` on a `load`-refused error still returned a plain-text error (not JSON) in one observed case,
so **do not assume every error is JSON** — guard the `json.loads`.

---

## 8. What is / isn't supported (scope limits to encode)

From the preview instructions:
- **Interfaces — IN:** all **end-user** SAIL interfaces. `sail` always **starts from Site pages**,
  then navigates via record actions, record views, start-process links, form submission, etc.
- **Interfaces — OUT:** `/design` interfaces, **Portals**.
- **Components — IN:** nearly all SAIL components.
- **Components — OUT:** component plugins, hierarchy components *(note: the interact help does
  describe driving hierarchy/org-chart nodes — treat hierarchy support as partial/evolving)*,
  non-SAIL interfaces.
- **Auth — IN:** Appian (local) authentication. **OUT:** SSO (use the DevMCP import bridge).
- **Appian versions — IN:** 26.5+ confirmed, likely older. **OUT:** very old versions where component
  structure differed (rare).
- **Preview caveat:** the **command signature may change** between preview builds; stored
  invocations may need updating. The library should centralize command construction so a signature
  change is a one-place fix, and record the `sail --version` it was validated against.

---

## 9. Proof it works from Python (the reference we built)

A self-contained Python script was written and **run successfully with no agent involved**. It
demonstrates the whole wrapper pattern the library will formalize: subprocess + `--json` +
per-run `--data-dir` + `login` into that dir + `--fresh` load + assert on the JSON diff.

```python
import json
import subprocess

SITE = "source-selection"
PAGE = "my-activities"
DATA_DIR = "/tmp/sail-test-run-1"   # isolate this run's session/state

def sail(*args):
    """Run a sail command with --json and return parsed output (or raise)."""
    cmd = ["sail", *args, "--json", "--data-dir", DATA_DIR]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)}\n{proc.stderr or proc.stdout}")
    return json.loads(proc.stdout) if proc.stdout.strip() else {}

def test_task_type_filter_enables_clear():
    sail("login", "merge-assist-dev.appianpreview.com")  # reads SAIL_USERNAME/PASSWORD from env
    sail("load", SITE, PAGE, "--fresh")
    result = sail("interact", SITE, "Task Type", "3")

    dropdown = next(c for c in result["changed"] if c.get("inlineLabel") == "Task Type")
    assert dropdown["value"] == [3], f"expected [3], got {dropdown['value']}"
    labels = [c.get("primaryText") for c in result["changed"]]
    assert "Clear filters" in labels, f"Clear filters not in {labels}"
    print("PASS: Task Type filter bound to [3] and Clear filters became available")

if __name__ == "__main__":
    test_task_type_filter_enables_clear()
```
Run:
```bash
SAIL_USERNAME='kiroDeveloper' SAIL_PASSWORD='appian26' python3 sail_test_example.py
# → PASS: Task Type filter bound to [3] and Clear filters became available   (exit 0)
```
**Lesson encoded above:** the first run FAILED with `no session found` because the isolated
`--data-dir` had no session — hence the explicit `login` step. This is the #1 gotcha for the
library's session lifecycle.

### End-to-end behaviors actually observed on `source-selection` / `my-activities`
- `sail pages source-selection` → 3 pages: `my-activities` (My Workspace, default), `evaluations`,
  `vendors`. **Site is addressed by its web-address stub `source-selection`** — not `sourceselection`
  / `sourceSelection` (those 500 with "Site does not exist"). The library should treat the site
  identifier as the exact URL stub.
- `interact ... "Task Type" 3` → dropdown value `[] → 3 (Complete Evaluation)`; a dependent
  `MenuItem` flipped `disabled: true → false` (conditional logic fired).
- `interact ... "My Tasks-Clear Filters Option"` → full-page structural re-render; `Task Type` reset
  to empty (reset path works).

---

## 10. Recommended design for the Python library

A thin, well-typed wrapper over the binary. Suggested shape:

- **`SailClient` / `SailSession`** object holding: binary path (default `sail`, overridable via arg or
  `SAIL_BIN`), `host`, `data_dir`, and default `--json`.
- **Lifecycle:** `login()` (reads env creds, or accepts explicit creds and sets env for the child
  process only), `logout()` (teardown). Support **context-manager** usage so `logout` always runs.
- **Per-instance isolation:** each `SailClient` owns a unique `data_dir` (default: a temp dir) so
  multiple clients = multiple "browser tabs" and parallel-safe tests.
- **Navigation/interaction methods:** `pages(site)`, `load(site, page=None, fresh=False)`,
  `show(site)`, `interact(site, *pairs, confirm=False)`, `navigate(site, target)`, `back(site)`.
- **Return types:** parse `--json` into dataclasses/typed dicts. Expose the `changed` list and a
  convenient **diff/`changedFields`** view for assertions. Provide helpers like
  `find_component(label=..., type=...)`.
- **Error handling:** raise a `SailError` on non-zero exit (include the command + stderr). Detect the
  **"accepted but nothing moved"** headline and raise a distinct `SailNoChangeError`. Guard
  `json.loads` because some errors come back as plain text even with `--json`.
- **Robustness:** detect macOS quarantine/exit-137-empty-output and raise an actionable
  "run setup-mac.sh" error. Record and optionally assert the `sail --version` the suite was validated
  against.
- **Credentials:** never place secrets in argv; pass via the child process `env`. In CI, read from
  secret store.
- **pytest ergonomics:** ship a fixture that creates an isolated `SailClient` on `tmp_path`, logs in,
  yields it, and logs out in teardown.

### Known gotchas checklist (all observed/derived here)
- [ ] macOS quarantine → silent `Killed: 9` / exit 137, empty output. Run `setup-mac.sh`.
- [ ] `| head` masks the real exit code — capture exit status directly.
- [ ] Isolated `--data-dir` needs its own `login` (session is per data-dir).
- [ ] `load` refuses over an interacted page → use `--fresh`.
- [ ] `_cId` is per-render; persist labels or `⌗`-refs instead.
- [ ] "Interacted but no value moved" = failure, not success.
- [ ] One unresolvable target fails the whole `interact` batch (no partial apply).
- [ ] `confirm:` targets need `--confirm` or they're refused.
- [ ] `show` can be stale after submit / during a running process.
- [ ] `logout` is destructive and server-side; copy out page state first if needed.
- [ ] SSO not directly supported → DevMCP `--from-devmcp` bridge.
- [ ] Preview build: signature may change; pin/record `sail --version` (`26.6.95` here).
- [ ] Only end-user SAIL interfaces; no `/design`, no Portals.
- [ ] Site is addressed by exact URL stub (`source-selection`, not casing variants).

---

## 11. Quick reference (copy/paste)

```bash
# one-time (macOS) install onto PATH
/Users/ramaswamy.u/appian-dev-mcp-server/bin/setup-mac.sh

# auth (basic/local account)
export SAIL_USERNAME='kiroDeveloper' SAIL_PASSWORD='appian26'
sail login merge-assist-dev.appianpreview.com

# discover & drive
sail pages   source-selection
sail load    source-selection my-activities
sail show    source-selection
sail interact source-selection "Task Type" 3
sail interact source-selection "Name" "Ada" "Start Date" "2026-10-15" "Division" 2   # batch
sail navigate source-selection "<handle>"
sail back    source-selection
sail logout

# always add for scripting / isolation:
#   --json                    machine-readable output
#   --data-dir /path/to/run   isolate concurrent runs (login per data-dir!)
#   --version                 -> sail version 26.6.95
```

**Authoritative references:**
- Preview instructions: `/Users/ramaswamy.u/Documents/sail-cli/SAIL CLI Internal Preview Instructions.md`
- Bundle install notes: `/Users/ramaswamy.u/appian-dev-mcp-server/INSTALL.txt`
- Official docs: https://docs.appian.com/suite/help/latest/devmcp.html
- AppMarket listing: https://appmarket.appian.com/listings/appian-dev-mcp
- Every subcommand: `sail <command> --help` (they are unusually thorough).
