# 03 — DevMCP Local Architecture (the branch model)

This describes how `appian-dev` works as a system. For *our* client we mostly care about
the export pipeline (doc 04) and the API (docs 06/07), but the branch model explains *why*
the data looks the way it does on disk and what the extra `.devmcp/` metadata is for.

## The core concept

A **branch** is a local copy of an Appian application, **checked out** from an
**environment** onto the filesystem as YAML, edited by an agent, reviewed by a human, and
**merged** back. The vocabulary deliberately mirrors Git.

| Appian today | appian-dev term | Meaning |
|---|---|---|
| project | **branch** | a named line of work over objects |
| remote | **environment** | an Appian env (dev/test/prod) |
| download | **checkout** | copies state to a working dir AND establishes a merge base |
| save | **merge** | reconciles two lines of work (not just a file write) |
| baseline | **merge base** | common ancestor every comparison attributes against |
| — | **origin** | the branch's default compare/merge target |
| — | **rebase** | advance the merge base to origin's current state |

Guiding principle (from the design doc): *"the dev server is never a git remote"* and
*"DevMCP Local is git-agnostic."* The local YAML files are the source of truth for
in-progress work; the local server is a warm coordinator that can crash without losing
state; the Appian environment is a deploy/observe target, not a VCS.

## On-disk layout of a branch

```
myapp/
  record-types/ZZ_Case.yaml          expression-rules/ZZ_Fmt.yaml
  constants/…   process-models/…   sites/…   groups/…   folders/…
  translation-sets/…   applications/…   data/default/rows/<uuid>.csv
  security.yaml
  .devmcp/                      ← branch identity + merge machinery
    branch.yaml                 ← name, description, origin{env, appUuid}, upstream, createdAt
    enumeration.json            ← the application's full object list (manifest snapshot)
    sync.json                   ← per-object merge-base tokens: versionId, versionUuid, diffHash, sha256
    merge-base/<same tree>      ← byte-for-byte copy of every object as checked out
    drafts.json  references.json  functions.txt  security-defaults.yaml
  .gitignore                    ← written by checkout; gitignores merge-base/, commits sync.json
```

- **One object = one YAML file**, grouped by collection folder.
- Identity (`name`, `description`, `origin`) lives in `.devmcp/branch.yaml` *in the folder*,
  so a `cp`-copied branch is self-describing. The central config (`~/.appian/appian-dev.json`)
  is only an index of known branch folders + registered environments.

## Two transforms between server JSON and the YAML file

1. **Stripped identities** (`appian-expr/branchfile`): server-minted UUIDs (an object's own
   `uuid`, a record field/relationship/action UUID, a process-node id) are omitted from the
   file so an agent editing it can't turn a rename into delete+create. On read, `branchfile.Read`
   restores them from the `merge-base/` copy by matching on the name key.
2. **Display-form references** (`roundtrip`): references are written by name
   (`recordType!TACPN Assessment.fields.cycleId`) instead of braced UUID
   (`recordType!{eb15…}…{512f…}cycleId`). Measured impact: braced UUIDs were ~12.6% of object
   text across 24 real branches.

Serialization is **deterministic and byte-stable**: yaml.v3 sorts keys, no volatile fields
(timestamps/version ids), multi-line expressions as literal block scalars, and a caveat
comment header for kinds that can't be fully represented (document bytes, connected-system
secrets).

## Comparison targets — one grammar, four resolutions

```
diff --against base          offline, exact   → what changed since checkout (merge-base on disk)
diff --against origin        network          → what origin holds NOW (the default)
diff --against env:<name>    network          → same app on another environment
diff --against branch:<name> offline, exact   → another local branch
```

`base` ("I changed this") vs `origin` ("we changed this") must never be conflated; the UI
shows the cheap on-disk `base` reading instantly, then upgrades to the live `origin` reading
when the drift check completes, always stating which freshness is on screen.

## The merge (three-way, partial)

- Three-way: local vs target vs ancestor (`internal/branch/merge*.go`), attributing each
  field via a four-rung ladder: `versionUuid` → `diffHash` → export lineage → conflict.
- Fields only one side moved resolve silently; the contested subset is handed over as
  **git-style `diff3` conflict markers** written into the YAML.
- Granularity: **field-scoped first, then parse-tree-scoped** (splice AST spans from
  `appian-expr`, never line-merge). A conflict record + pre-merge bytes are saved in `.devmcp/`
  so a merge can be aborted.
- Directions: `merge -to origin|env:<name>|branch:<name>`, `merge -from branch:<name>|env:<name>`,
  and `rebase` (advance the merge base).
- **Drift detection** (`drift.go`) makes the live comparison affordable (~4 requests / ~7.8s
  over a 354-object app).

## Runtime isolation

- **Local expression runtime** (`appian-expr` + `internal/localexpr`): `appian-dev eval`,
  `test`, `lint`, `check` run offline against the branch's own rules/constants/rows/user/clock.
  `eval.Chain` prefers local and falls back to remote only on `ErrUnsupported`.
- **Live render / interface sandbox** (`internal/render`): serves a real, interactive Appian
  page inside the local server's own origin via a reverse proxy that holds the session — the
  "visual confirmation mirroring a full environment" for human review.

## Authentication & guardrails (`appian-session`)

Two credentials, never both, neither written to disk:
- **Password** held in memory for the process lifetime (Basic auth to the plugin; also signs
  into the render side).
- **Adopted browser session**: cookies captured by `lcp-login` / `sail login` / the Python
  MCP server's `LCP_AUTH_METHOD=browser`, cached under `~/.appian-devmcp`. One cookie set
  authenticates both the plugin servlet and the render routes; it is the only way in on
  SSO-only sites. POSTs then also need `X-APPIAN-CSRF-TOKEN`.

Environments can be `read-only`; `merges: human` vs `agent` gates whether an agent's merge is
even registered — relaxable only by a human clicking in the web form.

## `appian-dev` CLI verbs (reference)

`checkout`, `new`, `check`, `diff`, `merge`, `rebase`, `lint`, `test`, `eval`, `fmt`,
`branch [show|list|describe|adopt|connect]`, `env`, `login`, `serve`, `restart`, `stop`,
`mcp`, `itest`, `status`. Most contact no server and need no password (safe to run in a loop);
`login`, `merge -to env:`, `test -on remote`, and `diff --against origin|env:` are the ones
that need the running server/session.
