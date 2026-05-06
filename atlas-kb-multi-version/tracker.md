# Atlas KB Multi-Version Release Parsing — Project Tracker

## Overview
Add support for configuring which historical releases should be maintained in the Atlas KB per application. The pipeline ensures all configured versions are parsed and available, while continuing to auto-sync the latest version daily.

## Design

### Approach: Option B — Separate "configured history" from "latest"

- `releases.json` = declarative config: "make sure at least these versions exist in the KB"
- Pipeline daily sync = "always check for and parse the latest, whatever it is"
- `release_index.json` = source of truth for what's actually been parsed (includes versions not in `releases.json`)

### Schema Change: `releases.json`

Add a `releases` field per app:

```json
{
  "name": "SourceSelection",
  "releaseVersion": "SourceSelection",
  "version_constant": "AS_GSS_TXT_APPLICATION_VERSION",
  "releases": ["26.02.06.00.00", "26.02.07.00.00", "26.02.08.00.00", "26.02.09.00.00", "26.03.00.00.00"]
}
```

- `releases` — minimum set of versions to maintain in the KB
- If omitted, behaves as today (just syncs latest)
- Versions must use the exact format from the version constant

### Packager API Version Retrieval

The `releaseVersion` parameter supports version-specific retrieval:
- `SourceSelection` → latest overall
- `SourceSelection-26.03.00.00.00` → specific version

Download call for a specific version:
```python
params = {"packageType": "FULL", "releaseVersion": f"{release_version}-{version}"}
```

### Pipeline Logic (single-job approach, as today)

For each app:

1. Read configured `releases` list from `releases.json`
2. Read `release_index.json` to get already-parsed versions
3. Determine action:
   - **No `releases` configured** → normal daily sync (delta/full for latest)
   - **All configured releases already parsed** → normal daily sync
   - **A configured release is OLDER than the oldest parsed version** → FULL REBUILD
   - **A configured release is NEWER than latest parsed but not yet parsed** → parse it (forward-only)
4. Execute action
5. After historical versions are handled, run normal daily sync for latest

### Rebuild Logic

When a full rebuild is triggered:
1. Delete the app's `data/<AppName>/` directory entirely
2. Sort configured `releases` by `sort_key` (chronological order)
3. Download and full-parse each version sequentially from oldest to newest
4. After all configured versions are parsed, run normal latest sync

### Pruning Respect

The `max_retained_releases` pruning logic must respect the `releases` list — never prune a version that's explicitly configured. Configured versions are "pinned."

### Error Handling

- **Packager API 404 (version unavailable):** Log warning, skip that version, continue. Don't fail the entire rebuild. Document that only "released" or "prioritized" packages are retained long-term by the packager.
- **Download failure (transient):** Retry with backoff (3 attempts).
- **Job timeout:** Set generous timeout (30 min) for sync jobs to accommodate rebuilds.

### Version Comparison

Use the parser's `sort_key` (tuple of integers) for version comparison, not raw strings. This handles format differences correctly.

## Status
Design complete — ready for implementation.

## Remaining Items
- [ ] Update `releases.json` schema with `releases` field for each app
- [ ] Implement rebuild detection logic in `sync_packages.py`
- [ ] Implement sequential multi-version parsing for rebuilds
- [ ] Implement version-specific download (`releaseVersion=AppName-Version`)
- [ ] Update pruning logic to respect configured versions
- [ ] Add retry logic for downloads
- [ ] Test with a real app (add an older version, verify rebuild works)
- [ ] Document the feature for users (how to add versions, what triggers a rebuild)

## Key Decisions
- Single-job approach (no matrix/parallel jobs) — keeps pipeline simple, rebuilds are rare
- Option B (configured history separate from latest) — `releases.json` is stable config, not auto-modified
- Full rebuild when older version added — cleanest approach, avoids inserting into middle of history
- Configured versions are pinned (never pruned)

## Session Log

### May 6, 2026 — Design discussion

- Identified the need: configure which releases to parse per solution, check if already parsed, rebuild if needed
- Investigated packager API: `releaseVersion` parameter supports version-specific retrieval (format: `SolutionName-M.m.f`)
- Identified risk: adding older versions disrupts release history (parser appends, doesn't insert)
- Solution: full rebuild when older version is added (delete + re-parse all in order)
- Considered matrix jobs for parallelism, decided against (artifact size, git conflicts, maintenance overhead)
- Chose single-job approach (existing pattern) with rebuild logic added
- Chose Option B (configured history separate from latest) over Option A (auto-append)
- Packager API doesn't have a "list all versions" endpoint — manual config in `releases.json` is the approach

---
