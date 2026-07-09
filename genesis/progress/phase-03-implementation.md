# Genesis — Phase 3 Implementation Record

> As-built record of Phase 3 (Distribution: GitLab pull, selective install,
> lockfile, loader). Companion to `specs/phase-03-distribution-install-lockfile.md`.

**Date:** 2026-07-09 · **Milestone:** M3 (Distribution works) · **Status:** ✅ COMPLETE — 24 platform tests green, ruff clean, pushed.

---

## 1. Summary

Phase 3 delivered the **distribution layer**: pull the workflow library from
GitLab at a pinned ref, selectively install workflows (with bundle expansion +
cross-role selection), track them in a lockfile, and load an installed workflow —
gated by the **genesis-core major-compat gate** (ADR-019). Proven end-to-end:
install `hello` from a fake GitLab → load it → run it to completion via the harness.

---

## 2. What was built (`genesis/dist/`)
```
gitlab.py    # GitLabClient (REST v4): list_tree (paginated), get_raw_file, list_tags, latest_tag
catalog.py   # Catalog: load/filter registry.json + bundles; expand bundles; cross-role
             #   selection (resolve_selection); prerequisites (missing MCP/CLI)
lockfile.py  # Lockfile model: load/save; InstalledWorkflow; GenesisCorePin; updatable()
install.py   # Installer: resolve(selection)->InstallPlan; install/install_selection/
             #   update_all/remove; writes files under ~/.genesis/library; maintains lockfile;
             #   records genesis_core major from registry.json (compat-gate key)
loader.py    # Loader: installed(); meta_of() (yaml, side-effect-free);
             #   check_compat() (REFUSES on major skew, ADR-019); load_build()
```
- **Runtime layout:** files land under `~/.genesis/library/` (`Settings.library_dir`);
  lockfile at `~/.genesis/installed.lock.json` (`Settings.lockfile_path`).
- **Compat gate:** the library declares `genesis_core_major` in `registry.json`;
  the installer records it in the lockfile; `Loader.check_compat()` compares it to
  the platform's `genesis_core.CORE_MAJOR` and raises `CompatError` on mismatch —
  detection alone is insufficient, so load is refused.
- **Loader vs worker (ADR-012):** `meta_of()` (yaml) is always safe in-process;
  `load_build()` imports `graph.py` — in production that import runs inside the
  Phase-5 subprocess worker; for the harness/tests it runs in-process.

## 3. Library change
`genesis-workflows/registry.json` now declares `genesis_core_major: 1` and
`genesis_core_version: "0.2.0"` (the compat-gate source). Tag **v0.1.1**.

---

## 4. Verification (evidence)

| Check | Result | Test |
|---|---|---|
| Catalog filter / bundle expand / cross-role selection | ✓ | `test_catalog_filter_bundles_crossrole` |
| Prerequisites (missing MCP/CLI) | ✓ | `test_catalog_prereqs` |
| Lockfile round-trip + update detection | ✓ | `test_lockfile_roundtrip_and_updatable` |
| GitLab client tree + raw fetch (fake session) | ✓ | `test_gitlab_client_tree_and_raw` |
| Install writes files + lockfile (records core major) | ✓ | `test_install_writes_files_and_lockfile` |
| Loader lists + reads META; **compat gate refuses on major skew** | ✓ | `test_loader_meta_and_compat_gate` |
| Remove deletes workflow files, retains shared | ✓ | `test_remove` |
| **End-to-end install → load → run to completion** | ✓ | `test_end_to_end_install_load_run` |
| Full platform suite | **24 passed** | 8 smoke + 3 lint + 5 (contract via lint) + 8 dist |
| ruff | clean | — |

Tests use a self-contained **fake GitLab** serving a scaffolded library from a temp
dir (dogfoods `create_workflow`), so they pass in CI without the sibling checkout.

---

## 5. Decisions / notes
- **`CORE_MAJOR` (API major = 1) is distinct from the pip package version (0.2.0).**
  The compat gate keys on `CORE_MAJOR`; the library declares the major it targets.
- **`requests`** added as a genesis runtime dependency (GitLab client). HTTP is
  isolated behind `GitLabClient._get` for easy mocking.
- Backend HTTP API endpoints (Phase 3 §4.6) are intentionally deferred to Phase 5
  (FastAPI); the service functions they will wrap are complete and tested here.

---

## 6. Repos & tags after Phase 3
| Repo | Tag | Change |
|---|---|---|
| `genesis` | **v0.3.0** | +`genesis/dist/` (client, catalog, lockfile, installer, loader + compat gate); +`requests` |
| `genesis-workflows` | **v0.1.1** | registry declares `genesis_core_major` |
| `genesis-core` | v0.2.0 | unchanged |

---

## 7. Next: Phase 4 — Configuration & Secrets
`genesis/config/`: SecretProvider (plaintext 0600 → keychain-ready), secret-field
derivation from `mcp-registry.json`, credential-free environment registry, health
checks (incl. the MCP literal-env probe). See `specs/phase-04-configuration-and-secrets.md`.
