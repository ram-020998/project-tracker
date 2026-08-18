# Backlog — Multi-repo update version check

> **Status:** 📝 BACKLOG (not scheduled). · **Created:** 2026-08-18 · **Repo:** genesis (+ `runtime/updater.py`, `api/system`, `web/features/system`)

## Problem
The one-click **Update** (v0.48.4) already *applies* a whole-stack upgrade — `pip install .` re-pulls the pinned
`genesis-core` / `kiro-agent-sdk` / `genesis-appian-parser`, and `apply()` also runs `genesis install` to refresh
`genesis-workflows`. But the update **banner/check** (`updater.check()`) only compares the **genesis** deployed version against
the highest `genesis` release tag. So an update is only *surfaced* when a new **genesis** tag exists.

Gap: if a related repo is tagged **without** a corresponding genesis release — most plausibly **genesis-workflows** (released
independently; not a pip dep), or a bare `genesis-core`/`kiro-agent-sdk`/`genesis-appian-parser` tag — the banner won't appear,
so the user isn't prompted even though a newer version exists in git.

## Goal
Surface an "update available" signal when **any** related repo is behind its latest tag, not just genesis — while respecting
the compatibility contract (don't offer an upgrade that would break `CORE_MAJOR` / an untested combination).

## Sketch (to refine when picked up)
- **Per-repo deployed vs latest:** for each related repo (`genesis`, `genesis-core`, `kiro-agent-sdk`,
  `genesis-appian-parser`, `genesis-workflows`), determine the installed version (importlib metadata / lockfile / dist config)
  and the highest `vX.Y.Z` tag on its remote (`git ls-remote --tags`, ssh access already exists).
- **`check()` returns a per-repo breakdown** + an aggregate `update_available`; the banner shows "updates available" if any repo
  is behind. Keep the existing genesis-tag path as the primary trigger.
- **Compatibility guard (important):** do **not** advertise pulling a `genesis-core`/`sdk`/`parser` tag *newer than what the
  latest `genesis` release pins* — that would violate ADR-019 (the genesis release's pins are the tested contract, enforced by
  the `CORE_MAJOR` gate). Practical stance: treat **genesis** + its pins as one coordinated unit (advertise when a newer genesis
  tag exists → apply pulls the matching set), and treat **genesis-workflows** as the one repo that can independently advance
  (advertise when its latest tag > the installed library version). Revisit whether independent core/sdk/parser checks are ever
  desirable (probably only when the pin was deliberately not bumped).
- **`apply()` already handles the upgrade** (v0.48.4) — this item is mostly about the **detection/surfacing** side + a clearer
  multi-repo status in the banner / `GET /api/system/update` / `GET /api/system/schedules`-style read.
- **Dev/editable guard** stays: suppress in a non-managed checkout (no `~/.genesis/dist.json`, per v0.48.1).

## Notes / open questions
- Where to read each repo's **installed** version: genesis + the three pinned deps via `importlib.metadata`; genesis-workflows
  via the library lockfile in `~/.genesis/library`.
- `git ls-remote --tags` per repo adds a few network calls to the (polled) check — cache / rate-limit (the banner polls ~5 min).
- Decide the UX: a single "updates available" banner vs a per-repo list. Likely keep it simple (one banner → one-click apply).
- Relates to: `updater.py` (`check`/`apply`, `is_managed_install`, `deployed_version`, `highest_tag`), ADR-019 (compat pins),
  ADR-046 (clone+tag distribution).
